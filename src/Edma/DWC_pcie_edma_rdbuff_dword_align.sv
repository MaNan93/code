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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edma/DWC_pcie_edma_rdbuff_dword_align.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_edma_rdbuff_dword_align (
                                       // Inputs
                                       clk,
                                       reset_n,
                                       rawreg2rdctrl_en,
                                       pdly2dalgn_dv,
                                       pdly2dalgn_hv,
                                       pdly2dalgn_eot,
                                       pdly2dalgn_error,
                                       pdly2dalgn_last,
                                       pdly2dalgn_chan_num,
                                       pdly2dalgn_hdr,
                                       pdly2dalgn_data,
                                       pdly2dalgn_dwen,
                                       pdly2dalgn_func_num,
                                       pdly2dalgn_data_prot,
                                       cmwr2dalgn_halt,
                                       // Outputs
                                       dalgn2cmwr_dv,
                                       dalgn2cmwr_hv,
                                       dalgn2cmwr_eot,
                                       dalgn2cmwr_chan_num,
                                       dalgn2cmwr_last,
                                       dalgn2cmwr_hdr,
                                       dalgn2cmwr_data,
                                       dalgn2cmwr_dwen,
                                       dalgn2cmwr_func_num,
                                       dalgn2cmwr_data_prot,
                                       dalgn2pdly_halt
                                       );

//--------------------------------------------------------------------------------
// Parameter declarations
//--------------------------------------------------------------------------------
   parameter TP                         = `TP;
   parameter HDR_WIDTH                  = 36;
   parameter NW                         = 4;
   parameter NFUNC_WD                   = 1;
   parameter NVFUNC_WD                  = `CX_NVFUNC_WD;
   parameter NUM_DMA_RD_CHAN_WIDTH      = 3;

   parameter DBUS_DWORD_WD                 = 32;  // Specifies data word width.

   parameter DMA_SEG_BUF_DATA_WIDTH     = 32;  // Specifies the segment buffer data width (1/2/4 data words)

   parameter RAS_PROT_RANGE    = `CX_RAS_PROT_RANGE;
   parameter RAS_PARITY_MODE   = `CX_RAS_PARITY_MODE;
   parameter HDR_PROT_WD       = `CX_RAS_PCIE_EXTENDED_HDR_PROT_WD; // XADM Common Header ecc/parity protection width
   parameter DATA_PROT_WD      = `TRGT_DATA_PROT_WD;

   parameter DWORD_PROT_BITS   = 4; // Number of protection bits per DWord
   parameter PM                = `CX_RAS_PARITY_MODE;

//--------------------------------------------------------------------------------
// Input declarations
//--------------------------------------------------------------------------------
   input                                clk;                     //
   input                                reset_n;                 //

   input                                rawreg2rdctrl_en;        // eDMA Read enable, active high

   input                                pdly2dalgn_dv;           //
   input                                pdly2dalgn_hv;           //
   input                                pdly2dalgn_eot;          //
   input                                pdly2dalgn_error;        //
   input                                pdly2dalgn_last;         //
   input [NUM_DMA_RD_CHAN_WIDTH-1:0]    pdly2dalgn_chan_num;     //
   input [HDR_WIDTH-1:0]                pdly2dalgn_hdr;          //
   input [DMA_SEG_BUF_DATA_WIDTH-1:0]   pdly2dalgn_data;         //
   input [NW-1:0]                       pdly2dalgn_dwen;         //
   input [NFUNC_WD-1:0]                 pdly2dalgn_func_num;     //
   input [DATA_PROT_WD-1:0]             pdly2dalgn_data_prot;
   input                                cmwr2dalgn_halt;         //

//--------------------------------------------------------------------------------
// Output declarations
//--------------------------------------------------------------------------------
   output                               dalgn2cmwr_dv;           //
   output                               dalgn2cmwr_hv;           //
   output                               dalgn2cmwr_eot;          //
   output [NUM_DMA_RD_CHAN_WIDTH-1:0]   dalgn2cmwr_chan_num;     //
   output                               dalgn2cmwr_last;         //
   output [HDR_WIDTH-1:0]               dalgn2cmwr_hdr;          //
   output [DMA_SEG_BUF_DATA_WIDTH-1 :0] dalgn2cmwr_data;         //
   output [NW -1 :0]                    dalgn2cmwr_dwen;         //
   output [NFUNC_WD-1:0]                dalgn2cmwr_func_num;     //
   output [DATA_PROT_WD-1:0]            dalgn2cmwr_data_prot;

   output                               dalgn2pdly_halt;         //

//--------------------------------------------------------------------------------
// Register declarations
//--------------------------------------------------------------------------------
   reg [1:0]                            current_state;
   reg [1:0]                            next_state;

   reg                                  dalgn2cmwr_hv;
   reg                                  dalgn2cmwr_dv;
   reg                                  dalgn2cmwr_eot;
   reg                                  dalgn2pdly_halt;

   reg [NUM_DMA_RD_CHAN_WIDTH-1:0]      dalgn2cmwr_chan_num_r;
   reg                                  dalgn2cmwr_last_r;
   reg [HDR_WIDTH-1:0]                  dalgn2cmwr_hdr_r;
   reg [NFUNC_WD-1:0]                   dalgn2cmwr_func_num_r;

   reg [DMA_SEG_BUF_DATA_WIDTH-1:0]     left_shift_data;
   reg [NW-1:0]                         left_shift_dwen;

   reg [DMA_SEG_BUF_DATA_WIDTH-1:0]     right_shift_data;
   reg [NW-1:0]                         right_shift_dwen;
   reg [DMA_SEG_BUF_DATA_WIDTH-1:0]     right_shift_data_r;
   reg [NW-1:0]                         right_shift_dwen_r;

   reg [DMA_SEG_BUF_DATA_WIDTH-1:0]     aligned_data;
   reg [NW-1:0]                         aligned_dwen;

   reg [DATA_PROT_WD-1:0]               left_shift_data_prot;
   reg [DATA_PROT_WD-1:0]               right_shift_data_prot;
   reg [DATA_PROT_WD-1:0]               right_shift_data_prot_r;
   reg [DATA_PROT_WD-1:0]               aligned_data_prot;

   wire [NUM_DMA_RD_CHAN_WIDTH-1:0] dalgn2cmwr_chan_num;
   wire                             dalgn2cmwr_last;
   wire [HDR_WIDTH-1:0]             dalgn2cmwr_hdr;
   wire [NFUNC_WD-1:0]              dalgn2cmwr_func_num;

//--------------------------------------------------------------------------------
// Internal design
//--------------------------------------------------------------------------------

  localparam PARITY_BIT = PM ? 1'b1 : 1'b0;


//--------------------------------------------------------------------
// Alignment FSM
//--------------------------------------------------------------------
   // Encoding for state machine

   parameter ST_IDLE = 2'b00;
   parameter ST_XMT_IN_PROG = 2'b01;
   parameter ST_EXTRA = 2'b10;

//--------------------------------------------------------------------
// Include alignment state machine
//--------------------------------------------------------------------
   // Segment buffer data width = 2, 4 or 8 data words
     //--------------------------------------------------------------------
     // Generate internal dalgn2cmr halt signal.
     //--------------------------------------------------------------------
     // Gate the halt input with the header and data valid out signals.
     // The dalgn_halt signal halts the dalgn2cmwr output data,
     // the TLP info (header, channel & func number) and the alignment FSM.
     wire dalgn_halt;
     assign dalgn_halt = (cmwr2dalgn_halt & (dalgn2cmwr_hv | dalgn2cmwr_dv));

     //--------------------------------------------------------------------
     // Alignment FSM sequential process
     //--------------------------------------------------------------------
     always @(posedge clk or negedge reset_n) begin : proc_seq_algn_fsm
      if (!reset_n) begin
        current_state <= # TP ST_IDLE;
      end else if (!rawreg2rdctrl_en) begin
        current_state <= # TP ST_IDLE;
      end else if (!dalgn_halt) begin
        // Hold transfer when the pdly2dalgn interface is halted.
        current_state <= # TP next_state;
      end
     end

     //--------------------------------------------------------------------
     // Alignment FSM combinational process
     //--------------------------------------------------------------------
     always @( * ) begin : proc_comb_algn_fsm
      // If the following case statement does not
      // set a signal to a new value, then hold the old value.
      next_state = current_state;

      case (current_state)
        ST_IDLE      : begin
          // Only exit IDLE state when valid data transfer detected, remain in IDLE state for errored transfers.
          if (pdly2dalgn_dv && !pdly2dalgn_eot) begin
            next_state = ST_XMT_IN_PROG;
          end else if (pdly2dalgn_dv & pdly2dalgn_eot) begin
            next_state = ST_EXTRA;
          end
        end
        ST_XMT_IN_PROG : begin
          if (pdly2dalgn_dv && pdly2dalgn_eot && !(|right_shift_dwen)) begin
            next_state = ST_IDLE;
          end else if (pdly2dalgn_dv && pdly2dalgn_eot && (|right_shift_dwen)) begin
            next_state = ST_EXTRA;
          end
        end
        ST_EXTRA : begin
          if (pdly2dalgn_dv && !pdly2dalgn_eot) begin
            next_state = ST_XMT_IN_PROG;
          end else if (pdly2dalgn_dv & pdly2dalgn_eot) begin
            next_state = ST_EXTRA;
          end else begin
            next_state = ST_IDLE;
          end
        end
        default          : begin
          // Illegal states (X, Z), should never be reached.
          next_state = ST_IDLE;
        end
      endcase
     end

     //--------------------------------------------------------------------
     // Alignment FSM control outputs
     //--------------------------------------------------------------------
     // Generate data valid signal
     always @( * ) begin : proc_comb_dalgn2cmwr_dv
       dalgn2cmwr_dv = 1'b0;

       if ((current_state == ST_XMT_IN_PROG) || (current_state == ST_EXTRA)) begin
         dalgn2cmwr_dv = 1'b1;
       end
     end

     // Generate header valid signal
     reg pdly2dalgn_hv_r; // Registered pipe delay header valid signal

     always @(posedge clk or negedge reset_n) begin : proc_seq_pdly2dalgn_hv_r
       if (!reset_n) begin
         pdly2dalgn_hv_r <= # TP 1'b0;
       end else if (!rawreg2rdctrl_en) begin
         pdly2dalgn_hv_r <= # TP 1'b0;
       end else if (!dalgn_halt) begin
         // Hold header valid when the pdly2dalgn interface is halted.
         pdly2dalgn_hv_r <= # TP pdly2dalgn_hv;
       end
     end

     always @( * ) begin : proc_comb_dalgn2cmwr_hv
       if (pdly2dalgn_hv && pdly2dalgn_error && (current_state == ST_IDLE)) begin
         // If error detected then assert cpld2mwr header valid immediately.
         dalgn2cmwr_hv = (pdly2dalgn_hv );
       end else begin
         // Align header valid with dalgn2cmwr_data in normal operation.
         dalgn2cmwr_hv = (pdly2dalgn_hv_r && (current_state != ST_IDLE));
       end
     end

     // Generate aligned end of transfer signal.
     // End of transfer signal generated when
     //    - transfer in progress and extra cycle not required for dalgn shifted data;
     //    - extra cycle required for dlagn shifted and non shifted data and
     //    - one beat errored transfer detected.
     always @( * ) begin : proc_comb_dalgn2cmwr_eot
       dalgn2cmwr_eot = 1'b0;

       if (((current_state == ST_XMT_IN_PROG) && pdly2dalgn_dv && pdly2dalgn_eot && !(|right_shift_dwen))
           || (current_state == ST_EXTRA)
           || (pdly2dalgn_hv && pdly2dalgn_eot && pdly2dalgn_error && (current_state == ST_IDLE))) begin
         dalgn2cmwr_eot = 1'b1;
       end
     end

     //--------------------------------------------------------------------
     // Generate the halt signal
     //--------------------------------------------------------------------
     always @( * ) begin : proc_comb_dalgn2pdly_halt
        if ((current_state == ST_EXTRA) && pdly2dalgn_hv && pdly2dalgn_error) begin
        // Halt the transmit data path when processing the last beat of a transfer and an error is detected
        // The halt cycle allows the FSM to return to the IDLE state and process the error after.
          dalgn2pdly_halt = 1'b1;
        end else begin
        // Enables the pipe delay block to pipe the first data beat from the master (rdbuff_ctrl)
        // to the slave (cpl2mwr block) before being halted. The pipe delay block detects a rising edge
        // on its halt input and stores one beat of the master request before halting the master.
          dalgn2pdly_halt = dalgn_halt;
        end
     end

     //--------------------------------------------------------------------------------
     // Align TLP header and function number info and DMA channel number with aligned data
     //--------------------------------------------------------------------------------
     always @(posedge clk or negedge reset_n) begin : proc_seq_align_hdr_chan_func_info
       if (!reset_n) begin
         dalgn2cmwr_chan_num_r <= # TP {NUM_DMA_RD_CHAN_WIDTH{1'b0}};
         dalgn2cmwr_last_r <= # TP 1'b0;
         dalgn2cmwr_hdr_r <= # TP {HDR_WIDTH{1'b0}};
         dalgn2cmwr_func_num_r <= # TP {NFUNC_WD{1'b0}};
       end else if (!rawreg2rdctrl_en) begin
         dalgn2cmwr_chan_num_r <= # TP {NUM_DMA_RD_CHAN_WIDTH{1'b0}};
         dalgn2cmwr_last_r <= # TP 1'b0;
         dalgn2cmwr_hdr_r <= # TP {HDR_WIDTH{1'b0}};
         dalgn2cmwr_func_num_r <= # TP {NFUNC_WD{1'b0}};
       end else if (!dalgn_halt) begin
         dalgn2cmwr_chan_num_r <= # TP pdly2dalgn_chan_num;
         dalgn2cmwr_last_r <= # TP pdly2dalgn_last;
         dalgn2cmwr_hdr_r <= # TP pdly2dalgn_hdr;
         dalgn2cmwr_func_num_r <= # TP pdly2dalgn_func_num;
       end
     end

     assign dalgn2cmwr_chan_num =     (pdly2dalgn_error && pdly2dalgn_hv && (current_state == ST_IDLE)) ? pdly2dalgn_chan_num : dalgn2cmwr_chan_num_r;
     assign dalgn2cmwr_hdr =          (pdly2dalgn_error && pdly2dalgn_hv && (current_state == ST_IDLE)) ? pdly2dalgn_hdr : dalgn2cmwr_hdr_r;
     assign dalgn2cmwr_func_num =     (pdly2dalgn_error && pdly2dalgn_hv && (current_state == ST_IDLE)) ? pdly2dalgn_func_num : dalgn2cmwr_func_num_r;
     //If transfering eot data and got an error (for the next transfer) keep the last from previous transaction
     //aligned with the EOT supplied to CPLD2MWR
     assign dalgn2cmwr_last = (pdly2dalgn_error && (current_state != ST_EXTRA)) ? pdly2dalgn_last : dalgn2cmwr_last_r;


//--------------------------------------------------------------------
// Include the data aligment logic depending on the configured
// segment buffer data width.
//--------------------------------------------------------------------

     // Segment buffer data width = 8 data words
     //--------------------------------------------------------------------------------
     // Translate the data word enable to number of data words in the data beat
     // Legal values are "00000001", "00000011", "00000111", "00001111",
     // "00011111", "00111111", "01111111" and "11111111". No data word holes in split completions.
     //--------------------------------------------------------------------------------
     reg [4:0] dw_cnt;

     always @( * ) begin : proc_comb_dw_cnt
        case (pdly2dalgn_dwen)
          16'b0000000000000001   : begin
             dw_cnt = 5'b00001;
          end
          16'b0000000000000011   : begin
             dw_cnt = 5'b00010;
          end
          16'b0000000000000111   : begin
             dw_cnt = 5'b00011;
          end
          16'b0000000000001111   : begin
             dw_cnt = 5'b00100;
          end
          16'b0000000000011111   : begin
             dw_cnt = 5'b00101;
          end
          16'b0000000000111111   : begin
             dw_cnt = 5'b00110;
          end
          16'b0000000001111111   : begin
             dw_cnt = 5'b00111;
          end
          16'b0000000011111111   : begin
             dw_cnt = 5'b01000;
          end
          16'b0000000111111111   : begin
             dw_cnt = 5'b01001;
          end
          16'b0000001111111111   : begin
             dw_cnt = 5'b01010;
          end
          16'b0000011111111111   : begin
             dw_cnt = 5'b01011;
          end
          16'b0000111111111111   : begin
             dw_cnt = 5'b01100;
          end
          16'b0001111111111111   : begin
             dw_cnt = 5'b01101;
          end
          16'b0011111111111111   : begin
             dw_cnt = 5'b01110;
          end
          16'b0111111111111111   : begin
             dw_cnt = 5'b01111;
          end
          16'b1111111111111111   : begin
             dw_cnt = 5'b10000;
          end
          // Illegal decodes
          default : begin
             dw_cnt = 5'b00000;
          end
        endcase
     end

     //--------------------------------------------------------------------------------
     // Search for the first data beat with non-contiguous data words and store the number of
     // valid data words in the beat.
     // The number of data words determines the data word shift factor for the following data beats.
     //--------------------------------------------------------------------------------
     reg [3:0] first_dw_cnt_not_eq_16_r;

     always @(posedge clk or negedge reset_n) begin : proc_seq_dw_cnt_not_eq_16
        if (!reset_n) begin
          first_dw_cnt_not_eq_16_r <= # TP 4'b0000;
        end else if (!rawreg2rdctrl_en) begin
          first_dw_cnt_not_eq_16_r <= # TP 4'b0000;
        end else if (!dalgn_halt) begin
          if (pdly2dalgn_eot) begin
          // Clear shift factor and end of transfer
          first_dw_cnt_not_eq_16_r <= # TP 4'b0000;
          end else if (dw_cnt != 16) begin
          // Capture shift factor
          first_dw_cnt_not_eq_16_r <= # TP dw_cnt[3:0];
          end
        end else begin
          // Hold shift factor when pdly2dalgn interface is halted
          first_dw_cnt_not_eq_16_r <= # TP first_dw_cnt_not_eq_16_r;
        end
     end

     //--------------------------------------------------------------------------------
     // Determine the shift count for subsequent data beats
     //--------------------------------------------------------------------------------
     reg [4:0] left_shift_cnt;
     reg [4:0] right_shift_cnt;

     always @( * ) begin : proc_comb_shift_cnt
         if (current_state == ST_IDLE) begin // no shifting on first data beat, first beat registered internally
           left_shift_cnt = 5'b00000;
           right_shift_cnt = 5'b00000;
         end else begin
           left_shift_cnt = {1'b0, first_dw_cnt_not_eq_16_r[3:0]}; // Shift left by valid number of data words
           right_shift_cnt = (5'b10000 - {1'b0, first_dw_cnt_not_eq_16_r[3:0]}); // Shift right by max number of data words per beat minus left shift count
         end
     end

     //--------------------------------------------------------------------------------
     // Shift data and data word enable to the left.
     //--------------------------------------------------------------------------------
     reg [DMA_SEG_BUF_DATA_WIDTH-1:0] pdly2dalgn_data_int;
     reg [NW-1:0]                     pdly2dalgn_dwen_int;
     reg  [DATA_PROT_WD-1:0]          pdly2dalgn_data_prot_int;
     wire [DATA_PROT_WD-1:0]          right_shift_data_prot_i;
     reg  [DATA_PROT_WD-1:0]          right_shift_data_prot_mask;
     wire [DATA_PROT_WD-1:0]          left_shift_data_prot_i;
     reg  [DATA_PROT_WD-1:0]          left_shift_data_prot_mask;

     always @( * ) begin : proc_comb_pdly2dalgn_data
        if ((current_state == ST_EXTRA) && (!pdly2dalgn_dv)) begin
          pdly2dalgn_data_int = {DMA_SEG_BUF_DATA_WIDTH{1'b0}};
          pdly2dalgn_dwen_int = {NW{1'b0}};
          pdly2dalgn_data_prot_int = {DATA_PROT_WD{PARITY_BIT}};
        end else begin
          pdly2dalgn_data_int = pdly2dalgn_data;
          pdly2dalgn_dwen_int = pdly2dalgn_dwen;
          pdly2dalgn_data_prot_int = pdly2dalgn_data_prot;
        end
     end

     always @( * ) begin : proc_comb_left_shift
        case (left_shift_cnt[3:0])
          4'b0000   : begin
             left_shift_data = pdly2dalgn_data_int;
             left_shift_dwen = pdly2dalgn_dwen_int;
             left_shift_data_prot = (pdly2dalgn_dv) ? pdly2dalgn_data_prot_int : {DATA_PROT_WD{PARITY_BIT}};
             left_shift_data_prot_mask = (pdly2dalgn_dv) ? {16*DWORD_PROT_BITS{1'b0}} : {16*DWORD_PROT_BITS{PARITY_BIT}};
          end
          4'b0001   : begin
             left_shift_data = (pdly2dalgn_data_int << DBUS_DWORD_WD);
             left_shift_dwen = (pdly2dalgn_dwen_int << 1);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 4;
             left_shift_data_prot_mask = {{15*DWORD_PROT_BITS{1'b0}},{1*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b0010   : begin
             left_shift_data = (pdly2dalgn_data_int << (2*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 2);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 8;
             left_shift_data_prot_mask = {{14*DWORD_PROT_BITS{1'b0}},{2*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b0011   : begin
             left_shift_data = (pdly2dalgn_data_int << (3*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 3);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 12;
             left_shift_data_prot_mask = {{13*DWORD_PROT_BITS{1'b0}},{3*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b0100   : begin
             left_shift_data = (pdly2dalgn_data_int << (4*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 4);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 16;
             left_shift_data_prot_mask = {{12*DWORD_PROT_BITS{1'b0}},{4*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b0101   : begin
             left_shift_data = (pdly2dalgn_data_int << (5*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 5);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 20;
             left_shift_data_prot_mask = {{11*DWORD_PROT_BITS{1'b0}},{5*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b0110   : begin
             left_shift_data = (pdly2dalgn_data_int << (6*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 6);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 24;
             left_shift_data_prot_mask = {{10*DWORD_PROT_BITS{1'b0}},{6*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b0111   : begin
             left_shift_data = (pdly2dalgn_data_int << (7*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 7);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 28;
             left_shift_data_prot_mask = {{9*DWORD_PROT_BITS{1'b0}},{7*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b1000   : begin
             left_shift_data = (pdly2dalgn_data_int << (8*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 8);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 32;
             left_shift_data_prot_mask = {{8*DWORD_PROT_BITS{1'b0}},{8*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b1001   : begin
             left_shift_data = (pdly2dalgn_data_int << (9*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 9);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 36;
             left_shift_data_prot_mask = {{7*DWORD_PROT_BITS{1'b0}},{9*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b1010   : begin
             left_shift_data = (pdly2dalgn_data_int << (10*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 10);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 40;
             left_shift_data_prot_mask = {{6*DWORD_PROT_BITS{1'b0}},{10*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b1011   : begin
             left_shift_data = (pdly2dalgn_data_int << (11*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 11);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 44;
             left_shift_data_prot_mask = {{5*DWORD_PROT_BITS{1'b0}},{11*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b1100   : begin
             left_shift_data = (pdly2dalgn_data_int << (12*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 12);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 48;
             left_shift_data_prot_mask = {{4*DWORD_PROT_BITS{1'b0}},{12*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b1101   : begin
             left_shift_data = (pdly2dalgn_data_int << (13*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 13);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 52;
             left_shift_data_prot_mask = {{3*DWORD_PROT_BITS{1'b0}},{13*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b1110   : begin
             left_shift_data = (pdly2dalgn_data_int << (14*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 14);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 56;
             left_shift_data_prot_mask = {{2*DWORD_PROT_BITS{1'b0}},{14*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          4'b1111   : begin
             left_shift_data = (pdly2dalgn_data_int << (15*DBUS_DWORD_WD));
             left_shift_dwen = (pdly2dalgn_dwen_int << 15);
             left_shift_data_prot = pdly2dalgn_data_prot_int << 60;
             left_shift_data_prot_mask = {{1*DWORD_PROT_BITS{1'b0}},{15*DWORD_PROT_BITS{PARITY_BIT}}};
          end
          // Illegal X, Z values
          //default : begin
           //  left_shift_data = {DMA_SEG_BUF_DATA_WIDTH{1'b0}};
            // left_shift_dwen = {NW{1'b0}};
          //end
        endcase
     end

     assign left_shift_data_prot_i = left_shift_data_prot_mask | left_shift_data_prot;

     //--------------------------------------------------------------------------------
     // Shift data and data word enable to the right.
     //--------------------------------------------------------------------------------
     always @( * ) begin : proc_comb_right_shift
        case (right_shift_cnt[3:0])
          4'b0000   : begin
             right_shift_data = pdly2dalgn_data_int;
             right_shift_dwen = pdly2dalgn_dwen_int;
             right_shift_data_prot = (pdly2dalgn_dv) ? pdly2dalgn_data_prot_int : {DATA_PROT_WD{PARITY_BIT}};
             right_shift_data_prot_mask = (pdly2dalgn_dv) ? {16*DWORD_PROT_BITS{1'b0}} : {16*DWORD_PROT_BITS{PARITY_BIT}};
          end
          4'b0001   : begin
             right_shift_data = (pdly2dalgn_data_int >> DBUS_DWORD_WD);
             right_shift_dwen = (pdly2dalgn_dwen_int >> 1);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 4;
             right_shift_data_prot_mask = {{1*DWORD_PROT_BITS{PARITY_BIT}},{15*DWORD_PROT_BITS{1'b0}}};
          end
          4'b0010   : begin
             right_shift_data = (pdly2dalgn_data_int >> (2*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 2);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 8;
             right_shift_data_prot_mask = {{2*DWORD_PROT_BITS{PARITY_BIT}},{14*DWORD_PROT_BITS{1'b0}}};
          end
          4'b0011   : begin
             right_shift_data = (pdly2dalgn_data_int >> (3*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 3);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 12;
             right_shift_data_prot_mask = {{3*DWORD_PROT_BITS{PARITY_BIT}},{13*DWORD_PROT_BITS{1'b0}}};
          end
          4'b0100   : begin
             right_shift_data = (pdly2dalgn_data_int >> (4*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 4);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 16;
             right_shift_data_prot_mask = {{4*DWORD_PROT_BITS{PARITY_BIT}},{12*DWORD_PROT_BITS{1'b0}}};
          end
          4'b0101   : begin
             right_shift_data = (pdly2dalgn_data_int >> (5*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 5);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 20;
             right_shift_data_prot_mask = {{5*DWORD_PROT_BITS{PARITY_BIT}},{11*DWORD_PROT_BITS{1'b0}}};
          end
          4'b0110   : begin
             right_shift_data = (pdly2dalgn_data_int >> (6*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 6);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 24;
             right_shift_data_prot_mask = {{6*DWORD_PROT_BITS{PARITY_BIT}},{10*DWORD_PROT_BITS{1'b0}}};
          end
          4'b0111   : begin
             right_shift_data = (pdly2dalgn_data_int >> (7*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 7);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 28;
             right_shift_data_prot_mask = {{7*DWORD_PROT_BITS{PARITY_BIT}},{9*DWORD_PROT_BITS{1'b0}}};
          end
          4'b1000   : begin
             right_shift_data = (pdly2dalgn_data_int >> (8*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 8);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 32;
             right_shift_data_prot_mask = {{8*DWORD_PROT_BITS{PARITY_BIT}},{8*DWORD_PROT_BITS{1'b0}}};
          end
          4'b1001   : begin
             right_shift_data = (pdly2dalgn_data_int >> (9*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 9);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 36;
             right_shift_data_prot_mask = {{9*DWORD_PROT_BITS{PARITY_BIT}},{7*DWORD_PROT_BITS{1'b0}}};
          end
          4'b1010   : begin
             right_shift_data = (pdly2dalgn_data_int >> (10*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 10);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 40;
             right_shift_data_prot_mask = {{10*DWORD_PROT_BITS{PARITY_BIT}},{6*DWORD_PROT_BITS{1'b0}}};
          end
          4'b1011   : begin
             right_shift_data = (pdly2dalgn_data_int >> (11*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 11);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 44;
             right_shift_data_prot_mask = {{11*DWORD_PROT_BITS{PARITY_BIT}},{5*DWORD_PROT_BITS{1'b0}}};
          end
          4'b1100   : begin
             right_shift_data = (pdly2dalgn_data_int >> (12*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 12);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 48;
             right_shift_data_prot_mask = {{12*DWORD_PROT_BITS{PARITY_BIT}},{4*DWORD_PROT_BITS{1'b0}}};
          end
          4'b1101   : begin
             right_shift_data = (pdly2dalgn_data_int >> (13*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 13);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 52;
             right_shift_data_prot_mask = {{13*DWORD_PROT_BITS{PARITY_BIT}},{3*DWORD_PROT_BITS{1'b0}}};
          end
          4'b1110   : begin
             right_shift_data = (pdly2dalgn_data_int >> (14*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 14);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 56;
             right_shift_data_prot_mask = {{14*DWORD_PROT_BITS{PARITY_BIT}},{2*DWORD_PROT_BITS{1'b0}}};
          end
          4'b1111   : begin
             right_shift_data = (pdly2dalgn_data_int >> (15*DBUS_DWORD_WD));
             right_shift_dwen = (pdly2dalgn_dwen_int >> 15);
             right_shift_data_prot = pdly2dalgn_data_prot_int >> 60;
             right_shift_data_prot_mask = {{15*DWORD_PROT_BITS{PARITY_BIT}},{1*DWORD_PROT_BITS{1'b0}}};
          end
          // Illegal X, Z values
          default : begin
             right_shift_data = {DMA_SEG_BUF_DATA_WIDTH{1'b0}};
             right_shift_dwen = {NW{1'b0}};
             right_shift_data_prot = {DATA_PROT_WD{1'b0}};
             right_shift_data_prot_mask = {DATA_PROT_WD{1'b0}};
          end
        endcase
     end

     assign right_shift_data_prot_i = right_shift_data_prot_mask | right_shift_data_prot;

     //--------------------------------------------------------------------------------
     // Store data and data word enable.
     //--------------------------------------------------------------------------------
     always @(posedge clk or negedge reset_n) begin : proc_seq_right_shift_data
        if (!reset_n) begin
          right_shift_data_r <= # TP {DMA_SEG_BUF_DATA_WIDTH{1'b0}};
          right_shift_dwen_r <= # TP {NW{1'b0}};
          right_shift_data_prot_r <= # TP {DATA_PROT_WD{PARITY_BIT}};
        end else if (!rawreg2rdctrl_en) begin
          right_shift_data_r <= # TP {DMA_SEG_BUF_DATA_WIDTH{1'b0}};
          right_shift_dwen_r <= # TP {NW{1'b0}};
          right_shift_data_prot_r <= # TP {DATA_PROT_WD{PARITY_BIT}};
        end else if (!dalgn_halt) begin
          right_shift_data_r <= # TP right_shift_data;
          right_shift_dwen_r <= # TP right_shift_dwen;
          right_shift_data_prot_r <= # TP right_shift_data_prot_i;
        end else begin
          // Hold data when the pdly2dalgn interface is halted.
          right_shift_data_r <= # TP right_shift_data_r;
          right_shift_dwen_r <= # TP right_shift_dwen_r;
          right_shift_data_prot_r <= # TP right_shift_data_prot_r;
       end
     end

     //--------------------------------------------------------------------------------
     // Generate aligned data and data word enable
     //--------------------------------------------------------------------------------
     always @( * ) begin : proc_comb_dalgn_data
        if ((&right_shift_dwen_r) || (current_state == ST_EXTRA)) begin
          aligned_data = right_shift_data_r;
          aligned_dwen = right_shift_dwen_r;
          aligned_data_prot = right_shift_data_prot_r;
        end else begin
          aligned_data = left_shift_data | right_shift_data_r;
          aligned_dwen = left_shift_dwen | right_shift_dwen_r;
          if (RAS_PARITY_MODE) begin // ODD
          aligned_data_prot = left_shift_data_prot_i & right_shift_data_prot_r;
          end else begin
          aligned_data_prot = left_shift_data_prot | right_shift_data_prot_r;
          end
        end
     end

     //--------------------------------------------------------------------------------
     // Gate aligned data and data word enable with data valid
     //--------------------------------------------------------------------------------
     assign dalgn2cmwr_data = aligned_data & {DMA_SEG_BUF_DATA_WIDTH{dalgn2cmwr_dv}};
     assign dalgn2cmwr_dwen = aligned_dwen & {NW{dalgn2cmwr_dv}};

     if (RAS_PARITY_MODE) begin // ODD
       assign dalgn2cmwr_data_prot = (dalgn2cmwr_dv) ? aligned_data_prot : {DATA_PROT_WD{PARITY_BIT}};
     end else begin
        assign dalgn2cmwr_data_prot = aligned_data_prot & {DATA_PROT_WD{dalgn2cmwr_dv}};
     end




   // Segment buffer data width = 1 data word

//--------------------------------------------------------------------------------
// Block Level Assertions
//--------------------------------------------------------------------------------

`ifndef SYNTHESIS
   wire [14*8:1] CURRENT_STATE;

   assign CURRENT_STATE = (current_state == ST_IDLE       ) ? "ST_IDLE       " :
                          (current_state == ST_XMT_IN_PROG) ? "ST_XMT_IN_PROG" :
                          (current_state == ST_EXTRA      ) ? "ST_EXTRA      " :
                          "UNDEF";
`endif // SYNTHESIS

endmodule
