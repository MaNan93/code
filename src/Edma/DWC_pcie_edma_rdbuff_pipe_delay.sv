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
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edma/DWC_pcie_edma_rdbuff_pipe_delay.sv#11 $
// -------------------------------------------------------------------------
// --- Module description: Delays CPL TLP information to match RAM RD latency
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"

module DWC_pcie_edma_rdbuff_pipe_delay 
  import DWC_pcie_edmapf_rasdp_pkg::RAS_CHK_ID_RAM_RDBUF;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  // ##########################################################################
  //                             Parameters Declaration
  // ##########################################################################
  parameter                    TP = `TP                                /* Clock to Q delay                                          */
 ,parameter                    NW = 1                                  /* Data bus width expressed in data words                    */
 ,parameter              NFUNC_WD = 3                                  /* Function number width                                     */
 ,parameter             HDR_WIDTH = 36                                 /* Header width                                              */
 ,parameter            DATA_WIDTH = 32                                 /* Data width                                                */
 ,parameter       DATA_WECC_WIDTH = 32                                 /* Data width including ECC bits                             */
 ,parameter       NUM_DMA_RD_CHAN = 1                                  /* Number of read channels                                   */
 ,parameter NUM_DMA_RD_CHAN_WIDTH = 1                                  /* Channel number width                                      */
 ,parameter          ADDR_PROT_WD = `CC_DMA_SEG_BUF_NW_ADDR_WIDTH
 ,parameter          DATA_PROT_WD = `TRGT_DATA_PROT_WD
 ,parameter        RAS_PROT_RANGE = `CX_RAS_PROT_RANGE
 ,parameter       RAS_PARITY_MODE = `CX_RAS_PARITY_MODE
 ,parameter    RAS_RAM_PROT_RANGE = `CX_RAS_RAM_PROT_RANGE
 ,parameter   RAS_PROT_CORRECT_EN = `CX_RAS_CORRECTION_EN
) 
                                        (
  // ##########################################################################
  //                                Ports Declaration
  // ##########################################################################
  input  logic                              clk                        /* Main clock                                                */
 ,input  logic                              reset_n                    /* Asynchronous reset                                        */

 ,input  logic                              header_valid_in            /* Master header valid in                                    */
 ,input  logic                              data_valid_in              /* Master data valid in (i.e. sbc_pop delayed 1 cyc)         */
 ,input  logic                              end_of_transfer_in         /* Master end of transfer in                                 */
 ,input  logic                              data_in_ramValid           /* RAM data is valid                                         */
 ,input  logic             [HDR_WIDTH -1:0] header_in                  /* All master TLP header fields validated by header valid in */
 ,input  logic              [NFUNC_WD -1:0] func_num_in                /* Function number validated by header valid in              */
 ,input  logic [NUM_DMA_RD_CHAN_WIDTH -1:0] chan_num_in                /* Channel number corresponding to read segment              */
 ,input  logic                    [NW -1:0] data_word_enable_in        /* Master data word enable in                                */
 ,input  logic       [DATA_WECC_WIDTH -1:0] data_in                    /* Master data in                                            */
 ,input  logic                              error_in                   /* Master errored transfer in                   (Legacy DMA) */
 ,input  logic                              last_in                    /* Master last transfer in                      (Legacy DMA) */
 ,input  logic                              halt_in                    /* Slave halt in                                             */
 ,output ras_dp_err_log_t                  rdbuff_ras_dp_err_log_core
 ,input ras_dp_err_inj_t                   rdbuff_ras_dp_err_inj_core 
 ,input  logic          [ADDR_PROT_WD -1:0] ras_addr_in                /* RAS Address                                               */

 ,output logic                              header_valid_out           /* Master pipelined header valid out                         */
 ,output logic                              data_valid_out             /* Master pipelined data valid out                           */
 ,output logic                              end_of_transfer_out        /* Master pipelined end of transfer out                      */
 ,output logic             [HDR_WIDTH -1:0] header_out                 /* Master pipelined header out                               */
 ,output logic              [NFUNC_WD -1:0] func_num_out               /* Master pipelined function number out                      */
 ,output logic [NUM_DMA_RD_CHAN_WIDTH -1:0] chan_num_out               /* Master pipelined channel number out                       */
 ,output logic       [NUM_DMA_RD_CHAN -1:0] tlp_in_fligh               /* TLP in flight in TLP delay                   (Legacy DMA) */
 ,output logic                    [NW -1:0] data_word_enable_out       /* Master pipelined data word enable out                     */
 ,output logic            [DATA_WIDTH -1:0] data_out                   /* Master pipelined data out                                 */
 ,output logic                              error_out                  /* Master pipelined error out                   (Legacy DMA) */
 ,output logic                              last_out                   /* Master pipelined last out                    (Legacy DMA) */
 ,output logic                              halt_out                   /* Halt out to master write FSM                              */
 ,output logic          [DATA_PROT_WD -1:0] ras_data_prot_out          /* RAS Parity bits                                           */
 );

  // ##########################################################################
  //                       Type Definitions
  // ##########################################################################
  typedef struct packed {
    logic                              hv      ;
    logic                              dv      ;
    logic                              eot     ;
    logic                              error   ;
    logic                              last    ;
    logic             [HDR_WIDTH -1:0] header  ;
    logic              [NFUNC_WD -1:0] func_num;
    logic [NUM_DMA_RD_CHAN_WIDTH -1:0] chan_num;
    logic                    [NW -1:0] dwen    ;
    logic          [ADDR_PROT_WD -1:0] ras_addr;
  } dly_s;

  // ##########################################################################
  //                       Local Parameters Declaration
  // ##########################################################################

  /* BCM64 transport delay parameters */
  localparam integer REG_DELAY_DENOM = 1000;
  localparam integer REG_DELAY_TIME  = `TP * REG_DELAY_DENOM;

  /* rdbuff RAM Regin/Regout latency */
  localparam LP_RAM_REGDLY       = 0 + 2;
  /* 'halt_out' to 'rdbuf controller idle' latency */
  localparam LP_HALT2RDREQ_LTCY  = 1;   // For CX_DMA_RD_MULTICOMPOSER enabled, one extra delay on sbcw
  /* Latency from SBC pop to RAM data valid */
  localparam LP_RDREQ2RAMDV_LTCY = `CC_DMA_SEG_BUF_RAM_LATENCY + LP_RAM_REGDLY + 1;
  /* Minimum latency from datafifo_push to datafifo_pop */
  localparam LP_RAMDV2OUT_LTCY   = 1;

  /* Full system latency, from 'halt_out' through 'ctrl2sbc_pop' to 'datafifo_push' */
  /* Add 1 extra latency because halt_in is registered                              */
  localparam LP_LTCY    = LP_HALT2RDREQ_LTCY + LP_RDREQ2RAMDV_LTCY + LP_RAMDV2OUT_LTCY;
  localparam LP_LTCY_AW = $clog2(LP_LTCY);

  localparam LP_DLY_WD  = $bits(dly_s);

   localparam DATA_ECC_WD = DATA_WECC_WIDTH - DATA_WIDTH;

  // ##########################################################################
  //                       Internal design
  // ##########################################################################

  logic [DATA_WECC_WIDTH -1:0] data_out_r         ;
  logic [NUM_DMA_RD_CHAN -1:0] tlp_in_fligh_i     ;

  /* FIFO data signals */
  dly_s                        fifohdr_in         ;
  dly_s                        fifohdr_out        ;
  dly_s                        fifohdr_mout       ; /* fifohdr output masked by 'fifos_valid' */

  logic [DATA_WECC_WIDTH -1:0] fifodata_in_data   ;
  logic [DATA_WECC_WIDTH -1:0] fifodata_out_data  ;

  /* FIFO control signals */
  logic                        fifos_valid        ;
  logic                        halt_in_r          ;

  logic                        fifohdr_push_req_n ;
  logic                        fifohdr_pop_req_n  ;
  logic                        fifohdr_empty      ;
  logic                        fifohdr_alm_full   ;
  logic      [LP_LTCY_AW -1:0] fifohdr_af_th      ;

  logic                        fifodata_push_req_n;
  logic                        fifodata_pop_req_n ;
  logic                        fifodata_empty     ;

  assign fifohdr_in.hv       = header_valid_in    ;
  assign fifohdr_in.dv       = data_valid_in      ;
  assign fifohdr_in.eot      = end_of_transfer_in ;
  assign fifohdr_in.error    = error_in           ;
  assign fifohdr_in.last     = last_in            ;
  assign fifohdr_in.header   = header_in          ;
  assign fifohdr_in.func_num = func_num_in        ;
  assign fifohdr_in.chan_num = chan_num_in        ;
  assign fifohdr_in.dwen     = data_word_enable_in;
  assign fifohdr_in.ras_addr = ras_addr_in        ;

  assign fifos_valid         = !(fifohdr_empty || fifodata_empty);

  /* Decrease af threshold by 1 because halt_in is registered */
  assign fifohdr_af_th       = LP_LTCY_AW'(LP_LTCY - LP_HALT2RDREQ_LTCY);
  assign fifohdr_push_req_n  = !(header_valid_in || data_valid_in);
  assign fifohdr_pop_req_n   = !(fifos_valid && !halt_in);

  assign fifodata_in_data    =  data_in         ;
  assign fifodata_push_req_n = !data_in_ramValid;
  assign fifodata_pop_req_n  = fifohdr_pop_req_n;

  assign fifohdr_mout        = fifos_valid ? fifohdr_out       : '0;
  assign data_out_r          = fifos_valid ? fifodata_out_data : '0;

  assign halt_out            = fifohdr_alm_full && halt_in_r;

  DWC_pcie_ctl_bcm64_td
   #(
    .WIDTH           ( LP_DLY_WD           ),
    .DEPTH           ( LP_LTCY             ),
    .ERR_MODE        ( 0                   ),
    .RST_MODE        ( 0                   ),
    .ADDR_WIDTH      ( LP_LTCY_AW          ),
    .REG_DELAY_TIME  ( REG_DELAY_TIME      ),
    .REG_DELAY_DENOM ( REG_DELAY_DENOM     )
  ) u_hdr_fifo       (
    .clk             ( clk                 ),
    .rst_n           ( reset_n             ),
    .init_n          ( 1'b1                ),
    .diag_n          ( 1'b1                ),
    .ae_level        ( '0                  ),
    .af_thresh       ( fifohdr_af_th       ),
    .push_req_n      ( fifohdr_push_req_n  ),
    .pop_req_n       ( fifohdr_pop_req_n   ),
    .data_in         ( fifohdr_in          ),
    .empty           ( fifohdr_empty       ),
    .almost_full     ( fifohdr_alm_full    ),
    .data_out        ( fifohdr_out         ),
// spyglass disable_block W287b
// SMD: An output port of module or gate instance is not connected
// SJ: The following port(s) of this instance are intentionally unconnected.
    .almost_empty    ( /* NC */            ),
    .half_full       ( /* NC */            ),
    .full            ( /* NC */            ),
    .error           ( /* NC */            )
// spyglass enable_block W287b
  );

  DWC_pcie_ctl_bcm64_td
   #(
    .WIDTH           ( DATA_WECC_WIDTH     ),
    .DEPTH           ( LP_LTCY             ),
    .ERR_MODE        ( 0                   ),
    .RST_MODE        ( 0                   ),
    .ADDR_WIDTH      ( LP_LTCY_AW          ),
    .REG_DELAY_TIME  ( REG_DELAY_TIME      ),
    .REG_DELAY_DENOM ( REG_DELAY_DENOM     )
  ) u_data_fifo      (
    .clk             ( clk                 ),
    .rst_n           ( reset_n             ),
    .init_n          ( 1'b1                ),
    .diag_n          ( 1'b1                ),
    .ae_level        ( '0                  ),
    .af_thresh       ( '0                  ),
    .push_req_n      ( fifodata_push_req_n ),
    .pop_req_n       ( fifodata_pop_req_n  ),
    .data_in         ( fifodata_in_data    ),
    .empty           ( fifodata_empty      ),
    .data_out        ( fifodata_out_data   ),
// spyglass disable_block W287b
// SMD: An output port of module or gate instance is not connected
// SJ: The following port(s) of this instance are intentionally unconnected.
    .almost_empty    ( /* NC */            ),
    .full            ( /* NC */            ),
    .half_full       ( /* NC */            ),
    .almost_full     ( /* NC */            ),
    .error           ( /* NC */            )
// spyglass enable_block W287b
  );

  always_ff @(posedge clk, negedge reset_n) begin : TLP_IN_FLIGH_I_PROC
    if(!reset_n)
      tlp_in_fligh_i <= #TP '0;
    else begin
      foreach(tlp_in_fligh_i[i]) begin
        if(     i == chan_num_in  && !fifohdr_push_req_n)
          tlp_in_fligh_i[i] <= #TP 1'b1;
        else if(i == chan_num_out && !fifohdr_pop_req_n )
          tlp_in_fligh_i[i] <= #TP 1'b0;
      end
    end
  end : TLP_IN_FLIGH_I_PROC

  always_ff @(posedge clk, negedge reset_n) begin : HALT_IN_R_PROC
    if(!reset_n)
      halt_in_r <= #TP 1'b0;
    else
      halt_in_r <= #TP halt_in;
  end : HALT_IN_R_PROC

  logic [DATA_WIDTH  -1:0] data_out_i      ;

  logic [DATA_ECC_WD -1:0] data_out_ecc    ;
  logic  [DATA_WIDTH -1:0] data_out_no_prot;

  logic [DATA_WIDTH  -1:0] ras_data_i      ;
  logic [DATA_WIDTH  -1:0] ras_data        ;

  logic ecc_err_detect;
  logic ecc_err_multpl;

  assign {data_out_ecc, data_out_no_prot} = data_out_r;

  // Mask data acording to valid dwords
  function automatic logic [DATA_WIDTH -1:0] data_masked (
    input [DATA_WIDTH -1:0] in_data
   ,input         [NW -1:0] dword_enable
  );
    logic [NW -1:0] [32 -1:0] s_data;

    s_data = in_data;
    foreach(dword_enable[i]) begin
      if(!dword_enable[i]) begin
        s_data[i] = '0;
      end
    end
    data_masked = s_data;

  endfunction


  logic [ADDR_PROT_WD-1:0] rd_addr_fixed;
      // ECC Checker
      ras_dp_pipe
       #(
        .PIPELINE_TYPE              (0                             ), // 0: delay_n
        .RESETVAL                   (0                             ),
        .N_STAGES                   (0                             ),
        .CAN_STALL                  (0                             ),
        .RESET_STALL                (0                             ),
        .BUS_PROTECT_GEN_EN         (0                             ), // 1: Bus Protection Generator is present
        .BUS_PROTECT_CHK_EN         (1                             ), // 0: Bus Protection Checker is not present (ECC/Parity)
        .PROT_TYPE                  (0                             ), // 0=Ecc, 1=Simple Parity
        .PROT_RANGE                 (RAS_RAM_PROT_RANGE            ), // Number of bits to calculate parity/ECC on
        .PROT_WD                    (DATA_ECC_WD                   ), // Selects the width of the din_prot/dout_prot signals
        .PARITY_MODE                (RAS_PARITY_MODE               ), // selects the type of parity: 0=Even, 1=Odd
        .PROT_CORRECT_EN            (RAS_PROT_CORRECT_EN           ), // 0: no correction on single-errors, 1: correction on single-errors
        .TOTAL_WIDTH                (DATA_WIDTH + ADDR_PROT_WD     ), 
        .EXCLUDE_PROT_WIDTH         (0                             ),
        .RAS_DP_PROT_CHK_ID_BASE    (RAS_CHK_ID_RAM_RDBUF          ), // Associates the Bus Protection Checker with a unique identifier
        .ADDR_ECC_PROT_EN           (1                             ),
        .ADDR_LOG_EN                (1                             ),
        .ADDR_INDEX                 (DATA_WIDTH                    ),
        .ADDR_WD                    (ADDR_PROT_WD                  )
      ) u_rdbuff_dt_addr_ecc_chk (
        .clk                        ( clk                                     )
        ,.rst_n                     ( reset_n                                 )
        ,.din                       ( {fifohdr_mout.ras_addr,data_out_no_prot})
        ,.din_prot                  ( data_out_ecc                            )
        ,.dout                      ( {rd_addr_fixed,ras_data_i}              )
        ,.dout_prot                 (  /* Not Connected */                    ) 
        ,.en                        ( 1'b1                                    )
        ,.bypass                    ( 1'b0                                    )
        ,.stall                     ( 1'b0                                    )
        ,.stallout                  ( /* Not Connected */                     )
        ,.valid_in                  ( ~fifodata_pop_req_n                     ) 
        ,.halt_out                  ( /* Not Connected */                     )
        ,.valid_out                 ( /* Not Connected */                     )
        ,.halt_in                   ( 1'b0                                    )
        ,.ras_dp_err_inband_kbd_in  ( 1'b0                                    )
        ,.ras_dp_err_inband_kbd_out ( /* Not Connected */                     )
        ,.ras_dp_err_log            ( rdbuff_ras_dp_err_log_core              )
          ,.ras_dp_err_inj          ( rdbuff_ras_dp_err_inj_core              )
      );
      
      

   // Detect RAS ECC uncorrectable error
   assign ras_data               = data_masked(ras_data_i, fifohdr_mout.dwen)   ;
   assign data_out_i             = ras_data                                     ;

   // Parity generator
   ras_dp_pipe
    #(
     .PIPELINE_TYPE              (0                         ), // 0: delay_n
     .RESETVAL                   (0                         ),
     .N_STAGES                   (0                         ),
     .CAN_STALL                  (0                         ),
     .RESET_STALL                (0                         ),
     .BUS_PROTECT_GEN_EN         (1                         ), // 1: Bus Protection Generator is present
     .BUS_PROTECT_CHK_EN         (0                         ), // 0: Bus Protection Checker is not present (ECC/Parity)
     .PROT_TYPE                  (1                         ), // 0=Ecc, 1=Simple Parity
     .PROT_RANGE                 (RAS_PROT_RANGE            ), // Number of bits to calculate parity/ECC on
     .PROT_WD                    (DATA_PROT_WD              ), // Selects the width of the din_prot/dout_prot signals
     .PARITY_MODE                (RAS_PARITY_MODE           ), // selects the type of parity: 0=Even, 1=Odd
     .PROT_CORRECT_EN            (/* NC */                  ), // 0: no correction on single-errors, 1: correction on single-errors
     .TOTAL_WIDTH                (DATA_WIDTH                ), 
     .EXCLUDE_PROT_WIDTH         (0                         ),
     .RAS_DP_PROT_CHK_ID_BASE    (/* NC */                  ), // Associates the Bus Protection Checker with a unique identifier
     .ADDR_ECC_PROT_EN           (/* NC */                  ),
     .ADDR_LOG_EN                (/* NC */                  ),
     .ADDR_INDEX                 (/* NC */                  ),
     .ADDR_WD                    (/* NC */                  )
   ) u_rdbuff_dt_par_gen (
      .clk                       ( clk                      )
     ,.rst_n                     ( reset_n                  )
     ,.din                       ( ras_data                 )
     ,.din_prot                  ( {DATA_PROT_WD{1'b0}}     )
     ,.dout                      (                          )
     ,.dout_prot                 ( ras_data_prot_out        )
     ,.en                        ( 1'b1                     )
     ,.bypass                    ( 1'b0                     )
     ,.stall                     ( 1'b0                     )
     ,.stallout                  ( /* Not Connected */      )
     ,.valid_in                  (  ~fifodata_pop_req_n     )
     ,.halt_out                  ( /* Not Connected */      )
     ,.valid_out                 ( /* Not Connected */      )
     ,.halt_in                   ( 1'b0                     )
     ,.ras_dp_err_inband_kbd_in  ( 1'b0                     )
     ,.ras_dp_err_inband_kbd_out ( /* Not Connected */      )
     ,.ras_dp_err_log            ( /* Not Connected */      )
       ,.ras_dp_err_inj          ( '0                       )
     );


  // -----------------------------------------------------------------------------
  // Assign outputs
  // -----------------------------------------------------------------------------
  assign header_out           = fifohdr_mout.header        ;
  assign data_word_enable_out = fifohdr_mout.dwen          ;
  assign data_out             =              data_out_i    ;
  assign func_num_out         = fifohdr_mout.func_num      ;
  assign chan_num_out         = fifohdr_mout.chan_num      ;
  assign error_out            = fifohdr_mout.error         ;
  assign last_out             = fifohdr_mout.last          ;
  assign tlp_in_fligh         =              tlp_in_fligh_i;

  // Header valid out asserted for valid composed segments and at end of the transfer for
  // errored composed segments. For errored segments we flush the buffer and assert hv & eot simultaneously on
  // the last read cycle. Flushing required if split completions received and error not detected on the first CplD.
  assign header_valid_out    = ((fifohdr_mout.hv && !fifohdr_mout.error)
                                || (fifohdr_mout.eot && fifohdr_mout.error));

  // Data valid asserted for valid completion TLP's only.
  assign data_valid_out      = (fifohdr_mout.dv && !fifohdr_mout.error);

  // End of transfer qualified with data valid.
  assign end_of_transfer_out = (fifohdr_mout.dv && fifohdr_mout.eot);


endmodule
