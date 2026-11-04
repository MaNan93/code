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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_err_inj.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module injects FEC error in the flit for PCIe Gen6 Protocol
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Plh/xplh_pkg.svh"

module xplh_err_inj
  import DWC_pcie_core_pkg::curr_inj_err_type_e;
  import DWC_pcie_core_pkg::FEC_CORR_OR_UNCORR;
  import DWC_pcie_core_pkg::FEC_CORR_ROTATE_1_GROUP;
  import DWC_pcie_core_pkg::FEC_CORR_3_GROUPS;
  import DWC_pcie_core_pkg::FEC_UNCORR;
  import DWC_pcie_core_pkg::flit_type_inj_e;
  import DWC_pcie_core_pkg::ANY_TYPE;
  import DWC_pcie_core_pkg::ANY_NON_IDLE;
  import DWC_pcie_core_pkg::PAYLOAD_ONLY;
  import DWC_pcie_core_pkg::NOP_ONLY;
  import DWC_pcie_core_pkg::IDLE_ONLY;
  import DWC_pcie_core_pkg::PAYLOAD_THEN_SAME_SEQ_NUM;
  import DWC_pcie_core_pkg::PAYLOAD_THEN_SEQ_NUM_PLUS_1;
  import DWC_pcie_core_pkg::RSV_111;
  import DWC_pcie_core_pkg::inj_sts_e;
  import DWC_pcie_core_pkg::NOT_INJ_ANY_ERR_YET;
  import DWC_pcie_core_pkg::AT_LEAST_1_ERR_INJ;
  import DWC_pcie_core_pkg::ERR_INJ_DONE;
  import DWC_pcie_core_pkg::ERR_INJ_ERR_CASE;
  import cx_pl_pkg::tx_flit_struct;
  import cx_pl_pkg::P_FLIT_WD;
  import cx_pl_pkg::P_FLIT_DW_CNT;
  import cx_pl_pkg::P_FLIT_DW_CNT_WD;
  import cx_pl_pkg::P_TX_SEQNUM_WD;
  import cx_pl_pkg::REPLAY_00;
  import cx_pl_pkg::NOP;
  import cx_pl_pkg::PYLD;
  import xplh_pkg::flit_usage_e;
  import xplh_pkg::PAYLOAD;
  import xplh_pkg::CXL_CM;
  import xplh_pkg::CXL_ALMP;
  import xplh_pkg::seqnum_plus_1;
#(
  parameter TP = `TP,          // Clock to Q delay (simulator insurance)
  parameter NW = `CX_NW,       // Number of 32-bit Data Words supported by the data path
  parameter DW = NW * 32       // Data path width
) 
                     (
  // Inputs
  input                            core_clk,
  input                            core_rst_n,
  input  [2 : 0]                   current_data_rate,     // Current Data Rate
  input  tx_flit_struct            flit_in,               // Flit Input
  input                            halt_in,               // Downstream Halt
  input                            spif_enable,           // SPIF Interface Enable
  input                            cxl_mode_enable,       // CXL Mode Enable
  input                            link_nop_flit_valid,   // Link Layer NOP Flit Indicator
  input                            phy_nop_flit_valid,    // Physical Layer NOP Flit Indicator
  input                            idle_flit_valid,       // IDLE Flit Indicator
  input                            replay_00_valid,       // Replay Command 00 Indicator
  input  [P_TX_SEQNUM_WD - 1 : 0]  tx_seqnum,             // Transmitter Sequence Number
  // Inputs from CDM
  input                            err_inj_en,            // Flit Error Injection Enable
  input                            err_inj_tx_en,         // Inject Errors on Transmitted Flits
  input  [4 : 0]                   err_inj_num,           // Number of Errors Injected
  input  [12 : 0]                  err_inj_data_rate,     // Flit Error Injection Enable Data Rate
  input  flit_type_inj_e           err_inj_flit_type,     // Injection on Flit Type
  input  [2 : 0]                   err_inj_cons_error,    // Consecutive Error Injection
  input  [7 : 0]                   err_inj_spacing,       // Spacing Between Injected Errors
  input  curr_inj_err_type_e       err_inj_error_type,    // Error Type Being Injected
  input  [6 : 0]                   err_inj_error_offst,   // Error Offset within Flit
  input  [7 : 0]                   err_inj_error_mag,     // Error Magnitude
  // Outputs
  output  tx_flit_struct           xplh_err_inj_flit,     // Flit Output with Error Injection
  output                           xplh_err_inj_halt,     // Upstream Halt
  output  inj_sts_e                xplh_err_inj_sts       // Flit Error Injection Status
);
  
// Local Enums
typedef enum logic [2:0] {
    IDLE           = 3'b000,
    FLIT_FINDER    = 3'b001,
    CONS_ERR_INJ   = 3'b010,
    SPACING_COUNT  = 3'b011,
    ERROR          = 3'b100,
    DONE           = 3'b101
} err_inj_state_e;

typedef enum logic [2:0] {
    UNDEFINED_FLIT = 3'b000,
    IDLE_FLIT      = 3'b001,
    NOP_FLIT       = 3'b010,
    PAYLOAD_FLIT   = 3'b011
    ,
    CXL_FLIT       = 3'b100
} flit_in_type_e;

// Logic Declarations
logic                int_data_rate_en;
logic                int_err_inj_cfg_en;
logic                err_inj_en_r;
logic                err_inj_tx_en_r;
logic  [4 : 0]       err_inj_num_r;
logic  [12 : 0]      err_inj_data_rate_r;
flit_type_inj_e      err_inj_flit_type_r;
logic  [2 : 0]       err_inj_cons_error_r;
logic  [7 : 0]       err_inj_spacing_r;
curr_inj_err_type_e  err_inj_error_type_r;
logic  [6 : 0]       err_inj_error_offst_r;
logic  [7 : 0]       err_inj_error_mag_r;
logic                int_err_inj_cfg_upd;
logic                int_initial_rand_gen_en;
logic                int_rand_gen_en;
logic                int_error_type_rand_gen_en;
logic                int_cons_error_rand_gen_en;
logic                int_spacing_rand_gen_en;
logic                int_error_mag_rand_gen_en;
logic                int_error_offst_corr_rand_gen_en;
logic  [1 : 0]       int_error_type_rand_num;
logic  [3 : 0]       int_cons_error_rand_num;
logic  [6 : 0]       int_spacing_rand_num;
logic  [7 : 0]       int_error_mag_rand_num;
logic  [6 : 0]       int_corr_error_offst_rand_num;
logic  [3 : 0]       int_err_inj_cons_error;
logic  [7 : 0]       int_err_inj_spacing;
logic  [7 : 0]       int_err_inj_error_mag;
logic  [6 : 0]       int_err_inj_corr_error_offst;
logic                int_err_inj_ready;
logic                int_err_inj_ready_r;
logic                int_err_inj_start;
logic                int_err_inj_start_r;
logic                int_err_inj_error;
logic                int_err_inj_error_r;
logic                int_err_inj_done;
logic                int_err_inj_eof_valid;
logic                int_spacing_eof_valid;
logic                int_err_inj_state_valid;
err_inj_state_e      int_err_inj_state_r;
err_inj_state_e      int_err_inj_next_state;
inj_sts_e            int_err_inj_sts_r;
logic  [3 : 0]       int_cons_error_cnt;
logic  [3 : 0]       int_cons_error_cnt_r;
logic  [7 : 0]       int_spacing_cnt;
logic  [7 : 0]       int_spacing_cnt_r;
logic  [4 : 0]       int_err_inj_num_cnt;
logic  [4 : 0]       int_err_inj_num_cnt_r;
logic                int_flit_in_replay_00;
logic                int_flit_in_replay_00_r;
logic  [P_TX_SEQNUM_WD-1:0]  int_flit_in_tx_seqnum;
logic  [P_TX_SEQNUM_WD-1:0]  int_flit_in_tx_seqnum_r;
flit_in_type_e       int_flit_in_type;
flit_in_type_e       int_flit_in_type_r;
logic                int_err_inj_valid;
logic                int_err_inj_valid_r;
logic  [P_TX_SEQNUM_WD-1:0]  int_err_inj_seq_num_r;
logic                int_spacing_valid;
logic                int_spacing_valid_r;
curr_inj_err_type_e  int_err_inj_error_type;
logic  [1 : 0]       int_err_inj_fec_grp_cnt;
logic  [1 : 0]       int_err_inj_fec_grp_cnt_r;
logic  [8 : 0]       int_corr_error_offst_fec_grp_0;
logic  [8 : 0]       int_corr_error_offst_fec_grp_1;
logic  [8 : 0]       int_corr_error_offst_fec_grp_2;
logic  [2 : 0]       int_uncorr_error_num_ecc;
logic                int_err_inj_pulse_en;
logic                int_mag_pulse_en;
logic                int_corr_offst_pulse_en;
logic                int_corr_1_grp_pulse_en;
logic                int_corr_3_grp_pulse_en;
logic                int_uncorr_pulse_en;
logic  [P_FLIT_WD-1        : 0]  int_err_mag_loc;
logic  [P_FLIT_WD-1        : 0]  int_err_mag_loc_r;
logic  [P_FLIT_DW_CNT_WD-1 : 0]  int_flit_dw_cnt_r;

// Data rate enable output
always_comb begin : data_rate_en_PROC
  case(current_data_rate)
    `GEN6_RATE: int_data_rate_en = (err_inj_data_rate[5]); // 64.0 GT/s 
    `GEN5_RATE: int_data_rate_en = (err_inj_data_rate[4]); // 32.0 GT/s    
    `GEN4_RATE: int_data_rate_en = (err_inj_data_rate[3]); // 16.0 GT/s
    `GEN3_RATE: int_data_rate_en = (err_inj_data_rate[2]); // 8.0  GT/s
    `GEN2_RATE: int_data_rate_en = (err_inj_data_rate[1]); // 5.0  GT/s
    `GEN1_RATE: int_data_rate_en = (err_inj_data_rate[0]); // 2.5  GT/s
    default   : int_data_rate_en = 1'b0;
  endcase
end : data_rate_en_PROC

// Configuration inputs enable output
always_comb begin : err_inj_cfg_en_PROC
  int_err_inj_cfg_en = 1'b0;
  if(err_inj_flit_type != RSV_111) begin
    if(err_inj_flit_type inside {PAYLOAD_THEN_SAME_SEQ_NUM, PAYLOAD_THEN_SEQ_NUM_PLUS_1}) begin
      if(err_inj_error_type == FEC_UNCORR) begin
        int_err_inj_cfg_en = 1'b1;
      end
    end else begin
      int_err_inj_cfg_en = 1'b1;
    end
  end
end : err_inj_cfg_en_PROC

// Register all the error injection CDM configured signals
always_ff @(posedge core_clk or negedge core_rst_n) begin : err_inj_regs_PROC
  if(!core_rst_n) begin
    err_inj_en_r          <= #TP 'b0;
    err_inj_tx_en_r       <= #TP 'b0;
    err_inj_num_r         <= #TP 'b0;
    err_inj_data_rate_r   <= #TP 'b0;
    err_inj_flit_type_r   <= #TP flit_type_inj_e'('b0);
    err_inj_cons_error_r  <= #TP 'b0;
    err_inj_spacing_r     <= #TP 'b0;
    err_inj_error_type_r  <= #TP curr_inj_err_type_e'('b0);
    err_inj_error_mag_r   <= #TP 'b0;
    err_inj_error_offst_r <= #TP 'b0;
  end else begin
    err_inj_en_r          <= #TP err_inj_en;
    err_inj_tx_en_r       <= #TP err_inj_tx_en;
    err_inj_num_r         <= #TP err_inj_num;
    err_inj_data_rate_r   <= #TP err_inj_data_rate;
    err_inj_flit_type_r   <= #TP err_inj_flit_type;
    err_inj_cons_error_r  <= #TP err_inj_cons_error;
    err_inj_spacing_r     <= #TP err_inj_spacing;
    err_inj_error_type_r  <= #TP err_inj_error_type;
    err_inj_error_mag_r   <= #TP err_inj_error_mag;
    err_inj_error_offst_r <= #TP err_inj_error_offst;
  end
end : err_inj_regs_PROC

// Check if any of the configured signals is changed or not
always_comb begin : err_inj_cfg_upd_PROC
  int_err_inj_cfg_upd = 1'b0;
  if(err_inj_tx_en       != err_inj_tx_en_r
  || err_inj_num         != err_inj_num_r
  || err_inj_data_rate   != err_inj_data_rate_r
  || err_inj_flit_type   != err_inj_flit_type_r
  || err_inj_cons_error  != err_inj_cons_error_r
  || err_inj_spacing     != err_inj_spacing_r
  || err_inj_error_type  != err_inj_error_type_r
  || err_inj_error_mag   != err_inj_error_mag_r
  || err_inj_error_offst != err_inj_error_offst_r) begin
    int_err_inj_cfg_upd = 1'b1;
  end
end : err_inj_cfg_upd_PROC

// Pesudo-random generator error type, consecutive error, spacing, magnitude, and offset enables
assign int_initial_rand_gen_en          = (int_err_inj_ready && int_err_inj_ready_r == 'b0); 
assign int_rand_gen_en                  = (int_err_inj_state_r != FLIT_FINDER && int_err_inj_next_state == FLIT_FINDER);
assign int_error_type_rand_gen_en       = ((int_initial_rand_gen_en || int_rand_gen_en) && err_inj_error_type == FEC_CORR_OR_UNCORR);
assign int_cons_error_rand_gen_en       = ((int_initial_rand_gen_en || int_rand_gen_en) && err_inj_cons_error == 3'b111);
assign int_spacing_rand_gen_en          = ((int_initial_rand_gen_en || int_rand_gen_en) && err_inj_spacing == 'b0);
assign int_error_mag_rand_gen_en        = ((int_initial_rand_gen_en || int_rand_gen_en) && err_inj_error_mag == 'b0);
assign int_error_offst_corr_rand_gen_en = ((int_initial_rand_gen_en || int_rand_gen_en) && err_inj_error_offst > 7'd82);

// Pesudo-random generator for " Error Type Being Injected " for case 00b
pseudo_random_generator
 #(
  .MAX            (2),
  .MIN            (0)
) u_error_type_rand_gen (
  // Inputs
  .core_clk       (core_clk),
  .core_rst_n     (core_rst_n),
  .en             (int_error_type_rand_gen_en),
  // Outputs
  .rand_num       (int_error_type_rand_num)
);

// Pesudo-random generator for " Consecutive Error Injection "
pseudo_random_generator
 #(
  .MAX            (15),
  .MIN            (7)
) u_cons_error_rand_gen (
  // Inputs
  .core_clk       (core_clk),
  .core_rst_n     (core_rst_n),
  .en             (int_cons_error_rand_gen_en),
  // Outputs
  .rand_num       (int_cons_error_rand_num)
);

// Pesudo-random generator for " Spacing Between Injected Errors "
pseudo_random_generator
 #(
  .MAX            (127),
  .MIN            (1)
) u_spacing_rand_gen (
  // Inputs
  .core_clk       (core_clk),
  .core_rst_n     (core_rst_n),
  .en             (int_spacing_rand_gen_en),
  // Outputs
  .rand_num       (int_spacing_rand_num)
);

// Pesudo-random generator for " Error Magnitude "
pseudo_random_generator
 #(
  .MAX            (255),
  .MIN            (1)
) u_error_mag_rand_gen (
  // Inputs
  .core_clk       (core_clk),
  .core_rst_n     (core_rst_n),
  .en             (int_error_mag_rand_gen_en),
  // Outputs
  .rand_num       (int_error_mag_rand_num)
);

// Pesudo-random generator for " Error Offset within Flit " for FEC correctable error case
pseudo_random_generator
 #(
  .MAX            (82),
  .MIN            (0)
) u_error_offst_corr_rand_gen (
  // Inputs
  .core_clk       (core_clk),
  .core_rst_n     (core_rst_n),
  .en             (int_error_offst_corr_rand_gen_en),
  // Outputs
  .rand_num       (int_corr_error_offst_rand_num)
);

// Add a pesudo-random number if needed for " Consecutive Error Injection ", " Spacing Between Injected Errors ", " Error Magnitude "
// and " Error Offset within Flit " if it exceeds the bytes within FEC group in case of FEC correctable
assign int_err_inj_cons_error       = (err_inj_cons_error_r == 3'b111) ? int_cons_error_rand_num       : {1'b0, err_inj_cons_error_r};
assign int_err_inj_spacing          = (err_inj_spacing_r == 'b0      ) ? {1'b0, int_spacing_rand_num}  : err_inj_spacing_r;
assign int_err_inj_error_mag        = (err_inj_error_mag_r == 'b0    ) ? int_error_mag_rand_num        : err_inj_error_mag_r;
assign int_err_inj_corr_error_offst = (err_inj_error_offst_r > 7'd82 ) ? int_corr_error_offst_rand_num : err_inj_error_offst_r;

// Auxiliary wires to be used in the following blocks
assign int_err_inj_ready       = (err_inj_en && err_inj_tx_en && int_data_rate_en && int_err_inj_cfg_en);
assign int_err_inj_start       = ( spif_enable || flit_in.flit_type_s.err_inj_en);
assign int_err_inj_error       = (!err_inj_en || int_err_inj_cfg_upd || (!int_err_inj_start && int_err_inj_start_r)) ? 1'b1 : int_err_inj_error_r;
assign int_err_inj_done        = (err_inj_num_r != 'b0 && int_err_inj_num_cnt == err_inj_num_r);
assign int_err_inj_eof_valid   = (int_err_inj_valid && flit_in.eof[1]);
assign int_spacing_eof_valid   = (int_spacing_valid && flit_in.eof[1]);
assign int_err_inj_state_valid = (int_err_inj_state_r inside {FLIT_FINDER, CONS_ERR_INJ, SPACING_COUNT});

always_ff @(posedge core_clk or negedge core_rst_n) begin : err_inj_aux_regs_PROC
  if(!core_rst_n) begin
    int_err_inj_ready_r <= #TP 1'b0;
    int_err_inj_start_r <= #TP 1'b0;
    int_err_inj_error_r <= #TP 1'b0;
  end else begin
    int_err_inj_ready_r <= #TP int_err_inj_ready;
    if(int_err_inj_state_r == IDLE) begin
      int_err_inj_start_r <= #TP 1'b0;
      int_err_inj_error_r <= #TP 1'b0;
    end else begin
      int_err_inj_start_r <= #TP int_err_inj_start;
      int_err_inj_error_r <= #TP int_err_inj_error;
    end
  end
end : err_inj_aux_regs_PROC

// Error injection state machine
always_comb begin : err_inj_fsm_PROC
  int_err_inj_next_state = int_err_inj_state_r;
  case (int_err_inj_state_r)
    // IDLE
    IDLE : begin
      if(int_err_inj_ready_r) begin
        int_err_inj_next_state = FLIT_FINDER;
      end
    end
    // Searching for a flit of the same type of " Injection on Flit Type " configured signal to start a new error injection 
    // count towards " Number of Errors Injected " configured signal
    FLIT_FINDER : begin
      if(!halt_in && int_err_inj_error) begin
        int_err_inj_next_state = ERROR;
      end else if(int_err_inj_cons_error == 'b0) begin
        if(int_err_inj_done) begin
          int_err_inj_next_state = DONE;
        end else if(!halt_in && int_err_inj_eof_valid) begin
          int_err_inj_next_state = SPACING_COUNT;
        end
      end else if(!halt_in && int_err_inj_eof_valid) begin
        int_err_inj_next_state = CONS_ERR_INJ;
      end
    end
    // Continuo the error injection process till reach the number of " Consecutive Error Injection " configured signal
    CONS_ERR_INJ : begin
      if(!halt_in && int_err_inj_error) begin
        int_err_inj_next_state = ERROR;
      end else if(int_err_inj_done) begin
        int_err_inj_next_state = DONE;
      end else if(int_cons_error_cnt == int_err_inj_cons_error) begin
        int_err_inj_next_state = SPACING_COUNT;
      end
    end
    // Halt the error injection process for a number of " Spacing Between Injected Errors " configured signal
    SPACING_COUNT : begin
      if(!halt_in && int_err_inj_error) begin
        int_err_inj_next_state = ERROR;
      end else if(int_spacing_cnt == int_err_inj_spacing) begin
        int_err_inj_next_state = FLIT_FINDER;
      end
    end
    // Abort the error injection process because " Flit Error Injection Enable " configured signal is de-asserted or any of 
    // the configured signals is changed before the injection process is completed
    ERROR : begin
      if(!err_inj_en) begin
        int_err_inj_next_state = IDLE;
      end
    end
    // The error injection process is completed
    DONE : begin
      if(!err_inj_en) begin
        int_err_inj_next_state = IDLE;
      end
    end
    // IDLE
    default : begin 
      int_err_inj_next_state = IDLE;
    end
  endcase
end : err_inj_fsm_PROC

// Error injection state machine register
always_ff @(posedge core_clk or negedge core_rst_n) begin : err_inj_fsm_reg_PROC
  if(!core_rst_n) begin
    int_err_inj_state_r <= #TP IDLE;
  end else begin
    int_err_inj_state_r <= #TP int_err_inj_next_state;
  end
end : err_inj_fsm_reg_PROC

// Error injection status output
always_comb begin : err_inj_sts_PROC
  case (int_err_inj_state_r)
    IDLE         : xplh_err_inj_sts = (err_inj_en_r                ) ? NOT_INJ_ANY_ERR_YET : int_err_inj_sts_r;
    FLIT_FINDER  : xplh_err_inj_sts = (int_err_inj_num_cnt_r == 'b0) ? NOT_INJ_ANY_ERR_YET : AT_LEAST_1_ERR_INJ;
    CONS_ERR_INJ : xplh_err_inj_sts = (int_err_inj_num_cnt_r == 'b0) ? NOT_INJ_ANY_ERR_YET : AT_LEAST_1_ERR_INJ;
    SPACING_COUNT: xplh_err_inj_sts = AT_LEAST_1_ERR_INJ;
    ERROR        : xplh_err_inj_sts = ERR_INJ_ERR_CASE;
    DONE         : xplh_err_inj_sts = ERR_INJ_DONE;
    default      : xplh_err_inj_sts = NOT_INJ_ANY_ERR_YET;
  endcase
end : err_inj_sts_PROC

// Error injection status register
always_ff @(posedge core_clk or negedge core_rst_n) begin : err_inj_sts_reg_PROC
  if(!core_rst_n) begin
    int_err_inj_sts_r <= #TP NOT_INJ_ANY_ERR_YET;
  end else begin
    int_err_inj_sts_r <= #TP xplh_err_inj_sts;
  end
end : err_inj_sts_reg_PROC

// Consecutive error number counter
always_comb begin : cons_error_cnt_PROC
  int_cons_error_cnt = int_cons_error_cnt_r;
  if(!halt_in) begin
    if(int_err_inj_state_r == CONS_ERR_INJ) begin
      if(int_err_inj_eof_valid) begin
        int_cons_error_cnt = int_cons_error_cnt + 1'b1;
      end
    end else begin
      int_cons_error_cnt = 'b0;
    end
  end  
end : cons_error_cnt_PROC

// Spacing number counter
always_comb begin : spacing_cnt_PROC
  int_spacing_cnt = int_spacing_cnt_r;
  if(!halt_in) begin
    if(int_err_inj_state_r == SPACING_COUNT) begin
      if(int_spacing_eof_valid) begin
        int_spacing_cnt = int_spacing_cnt + 1'b1;
      end
    end else begin
      int_spacing_cnt = 'b0;
    end
  end  
end : spacing_cnt_PROC

// Error injection number counter
always_comb begin : err_inj_num_cnt_PROC
  int_err_inj_num_cnt = int_err_inj_num_cnt_r;
  if(!halt_in) begin
    if(int_err_inj_state_r == IDLE) begin
      int_err_inj_num_cnt = 'b0;
    end else if(int_err_inj_state_r == FLIT_FINDER) begin
      if(int_err_inj_cons_error == 'b0 && err_inj_num_r != 'b0 && int_err_inj_eof_valid) begin
        int_err_inj_num_cnt = int_err_inj_num_cnt + 1'b1;
      end
    end else if(int_err_inj_state_r == CONS_ERR_INJ) begin
      if((int_cons_error_cnt_r == int_err_inj_cons_error - 1'b1) && int_err_inj_eof_valid) begin
        int_err_inj_num_cnt = int_err_inj_num_cnt + 1'b1;
      end
    end
  end
end : err_inj_num_cnt_PROC

// Consecutive error, spacing, error injection number counters registers
always_ff @(posedge core_clk or negedge core_rst_n) begin : err_inj_cnts_regs_PROC
  if(!core_rst_n) begin
    int_cons_error_cnt_r  <= #TP 'b0;
    int_spacing_cnt_r     <= #TP 'b0;
    int_err_inj_num_cnt_r <= #TP 'b0;
  end else begin
    int_cons_error_cnt_r  <= #TP int_cons_error_cnt;
    int_spacing_cnt_r     <= #TP int_spacing_cnt;
    int_err_inj_num_cnt_r <= #TP int_err_inj_num_cnt;
  end
end : err_inj_cnts_regs_PROC

// Flit replay 00 output
always_comb begin : flit_rply_00_PROC
  int_flit_in_replay_00 = 1'b0;
  if(flit_in.sof) begin
    if(int_err_inj_state_valid) begin
      if(!idle_flit_valid && replay_00_valid) begin
        int_flit_in_replay_00 = 1'b1;
      end
    end
  end else begin
    int_flit_in_replay_00 = int_flit_in_replay_00_r;
  end
end : flit_rply_00_PROC

// Flit tx sequence number output
always_comb begin : flit_tx_seqnum_PROC
  int_flit_in_tx_seqnum = 'b0;
  if(flit_in.sof) begin
    if(int_err_inj_state_valid) begin
      int_flit_in_tx_seqnum = tx_seqnum;
    end
  end else begin
    int_flit_in_tx_seqnum = int_flit_in_tx_seqnum_r;
  end
end : flit_tx_seqnum_PROC

// Flit type output
always_comb begin : flit_type_PROC
  int_flit_in_type = UNDEFINED_FLIT;
  if(flit_in.sof) begin
    if(int_err_inj_state_valid) begin
      if(idle_flit_valid) begin
        int_flit_in_type = IDLE_FLIT;
      end else if(spif_enable) begin
        if((link_nop_flit_valid && !(flit_in.retry_flit || flit_in.tlp_dv)) || phy_nop_flit_valid) begin
          int_flit_in_type = NOP_FLIT;
        end else if(cxl_mode_enable) begin
          if(flit_in.data[7:6] == PAYLOAD) begin
            int_flit_in_type = PAYLOAD_FLIT;
          end else if(flit_in.data[7:6] inside {CXL_CM, CXL_ALMP}) begin
            int_flit_in_type = CXL_FLIT;
          end
        end else begin
          int_flit_in_type = PAYLOAD_FLIT;
        end
      end else if(flit_in.flit_type_s.err_inj_en) begin
        if(flit_in.flit_type_s.flit_type == NOP) begin
          int_flit_in_type = NOP_FLIT;
        end else if(flit_in.flit_type_s.flit_type == PYLD) begin
          int_flit_in_type = PAYLOAD_FLIT;
        end
      end
    end
  end else begin
    int_flit_in_type = int_flit_in_type_r;
  end
end : flit_type_PROC

// Flit replay 00, and type registers
always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_rply_00_type_regs_PROC
  if(!core_rst_n) begin
    int_flit_in_replay_00_r <= #TP 'b0;
    int_flit_in_tx_seqnum_r <= #TP 'b0;
    int_flit_in_type_r      <= #TP UNDEFINED_FLIT;
  end else begin
    int_flit_in_replay_00_r <= #TP int_flit_in_replay_00;
    int_flit_in_tx_seqnum_r <= #TP int_flit_in_tx_seqnum;
    int_flit_in_type_r      <= #TP int_flit_in_type;
  end
end : flit_rply_00_type_regs_PROC

// Error injection valid output
always_comb begin : err_inj_valid_PROC
  int_err_inj_valid = 1'b0;
  if(flit_in.sof) begin
    if(int_err_inj_state_r == FLIT_FINDER) begin
      if(int_err_inj_start) begin
        case(err_inj_flit_type_r)
          ANY_TYPE                   : int_err_inj_valid = 1'b1;
          ANY_NON_IDLE               : int_err_inj_valid = (int_flit_in_type != IDLE_FLIT);
          PAYLOAD_ONLY               : int_err_inj_valid = (int_flit_in_type == PAYLOAD_FLIT || int_flit_in_type == CXL_FLIT);
          NOP_ONLY                   : int_err_inj_valid = (int_flit_in_type == NOP_FLIT);
          IDLE_ONLY                  : int_err_inj_valid = (int_flit_in_type == IDLE_FLIT);
          PAYLOAD_THEN_SAME_SEQ_NUM  : int_err_inj_valid = (int_flit_in_type == PAYLOAD_FLIT || int_flit_in_type == CXL_FLIT);
          PAYLOAD_THEN_SEQ_NUM_PLUS_1: int_err_inj_valid = (int_flit_in_type == PAYLOAD_FLIT || int_flit_in_type == CXL_FLIT);
          default                    : int_err_inj_valid = 1'b0;
        endcase
      end
    end else if(int_err_inj_state_r == CONS_ERR_INJ) begin
      if(err_inj_flit_type_r inside {PAYLOAD_THEN_SAME_SEQ_NUM, PAYLOAD_THEN_SEQ_NUM_PLUS_1}) begin
        if(int_flit_in_replay_00 && int_flit_in_type == PAYLOAD_FLIT) begin
          if(int_flit_in_tx_seqnum == int_err_inj_seq_num_r) begin
            int_err_inj_valid = 1'b1;
          end
        end
      end else begin
        int_err_inj_valid = 1'b1;
      end
    end
  end else begin
    int_err_inj_valid = int_err_inj_valid_r;
  end
end : err_inj_valid_PROC

// Error injection valid register
always_ff @(posedge core_clk or negedge core_rst_n) begin : err_inj_valid_reg_PROC
  if(!core_rst_n) begin
    int_err_inj_valid_r <= #TP 1'b0;
  end else begin
    int_err_inj_valid_r <= #TP int_err_inj_valid;
  end
end : err_inj_valid_reg_PROC

// Calculate the sequence number for the next flit to be injected
always_ff @(posedge core_clk or negedge core_rst_n) begin : err_inj_seq_num_PROC
  if(!core_rst_n) begin
    int_err_inj_seq_num_r <= #TP 'b0;
  end else begin
    if(!halt_in) begin
      if(int_err_inj_state_r == FLIT_FINDER) begin
        if(int_err_inj_eof_valid) begin
          if(err_inj_flit_type_r == PAYLOAD_THEN_SAME_SEQ_NUM) begin
            int_err_inj_seq_num_r <= #TP int_flit_in_tx_seqnum;
          end else if(err_inj_flit_type_r == PAYLOAD_THEN_SEQ_NUM_PLUS_1) begin
            int_err_inj_seq_num_r <= #TP seqnum_plus_1(int_flit_in_tx_seqnum);
          end
        end
      end else if(int_err_inj_state_r == CONS_ERR_INJ) begin
        if(int_err_inj_eof_valid) begin
          if(err_inj_flit_type_r == PAYLOAD_THEN_SEQ_NUM_PLUS_1) begin
            int_err_inj_seq_num_r <= #TP seqnum_plus_1(int_err_inj_seq_num_r);
          end
        end
      end else begin
        int_err_inj_seq_num_r <= #TP 'b0;
      end
    end
  end
end : err_inj_seq_num_PROC

// Error injection spacing valid output
always_comb begin : spacing_valid_PROC
  int_spacing_valid = 1'b0;
  if(flit_in.sof) begin
    if(int_err_inj_state_r == SPACING_COUNT) begin
      case(err_inj_flit_type_r)
        ANY_TYPE                   : int_spacing_valid = 1'b1;
        ANY_NON_IDLE               : int_spacing_valid = (int_flit_in_type != IDLE_FLIT);
        PAYLOAD_ONLY               : int_spacing_valid = (int_flit_in_type == PAYLOAD_FLIT || int_flit_in_type == CXL_FLIT);
        NOP_ONLY                   : int_spacing_valid = (int_flit_in_type == NOP_FLIT);
        IDLE_ONLY                  : int_spacing_valid = (int_flit_in_type == IDLE_FLIT);
        PAYLOAD_THEN_SAME_SEQ_NUM  : int_spacing_valid = (int_flit_in_type == PAYLOAD_FLIT || int_flit_in_type == CXL_FLIT);
        PAYLOAD_THEN_SEQ_NUM_PLUS_1: int_spacing_valid = (int_flit_in_type == PAYLOAD_FLIT || int_flit_in_type == CXL_FLIT);
        default                    : int_spacing_valid = 1'b0;
      endcase
    end
  end else begin
    int_spacing_valid = int_spacing_valid_r;
  end
end : spacing_valid_PROC

// Error injection spacing valid register
always_ff @(posedge core_clk or negedge core_rst_n) begin : spacing_valid_reg_PROC
  if(!core_rst_n) begin
    int_spacing_valid_r <= #TP 1'b0;
  end else begin
    int_spacing_valid_r <= #TP int_spacing_valid;
  end
end : spacing_valid_reg_PROC

// Error injection error type calculation
always_comb begin : err_inj_error_type_PROC
  case(err_inj_error_type_r)
    FEC_CORR_OR_UNCORR: begin
      case(int_error_type_rand_num)
        2'b00  : int_err_inj_error_type = FEC_CORR_ROTATE_1_GROUP;
        2'b01  : int_err_inj_error_type = FEC_CORR_3_GROUPS;
        default: int_err_inj_error_type = FEC_UNCORR;
      endcase
    end
    FEC_CORR_ROTATE_1_GROUP: int_err_inj_error_type = FEC_CORR_ROTATE_1_GROUP;
    FEC_CORR_3_GROUPS      : int_err_inj_error_type = FEC_CORR_3_GROUPS;
    default                : int_err_inj_error_type = FEC_UNCORR;
  endcase
end : err_inj_error_type_PROC

// FEC group calculation for the error type case of FEC correctable error and rotate for the 3 FEC groups
assign int_err_inj_fec_grp_cnt = (int_err_inj_fec_grp_cnt_r < 2'b11) ? int_err_inj_fec_grp_cnt_r : 1'b0;

// FEC group counter
always_ff @(posedge core_clk or negedge core_rst_n) begin : fec_grp_cnt_reg_PROC
  if(!core_rst_n) begin
    int_err_inj_fec_grp_cnt_r <= #TP 'b0;
  end else begin
    if(!halt_in) begin
      if(int_err_inj_state_r == IDLE) begin
        int_err_inj_fec_grp_cnt_r <= #TP 'b0;
      end else if(int_err_inj_error_type == FEC_CORR_ROTATE_1_GROUP) begin
        if(int_err_inj_eof_valid) begin
          int_err_inj_fec_grp_cnt_r <= #TP int_err_inj_fec_grp_cnt + 1'b1;
        end
      end
    end
  end
end : fec_grp_cnt_reg_PROC

// Error injection correctable error offset FEC group calculation
assign int_corr_error_offst_fec_grp_0 = ('d3*int_err_inj_corr_error_offst);
assign int_corr_error_offst_fec_grp_1 = ('d3*int_err_inj_corr_error_offst + 'd1);
assign int_corr_error_offst_fec_grp_2 = ('d3*int_err_inj_corr_error_offst + 'd2);

// Calculate the remaining number of errors needed to be injected in ECC bytes to complete 8 errors in case of FEC uncorrectable error
assign int_uncorr_error_num_ecc = (err_inj_error_offst_r != 'b0) ? ('d7 - ('d249 / err_inj_error_offst_r)) : 'b0;

// Error injection feature, magnitude, offset, correctable error, and uncorrectable error pulse enables
assign int_err_inj_pulse_en    = (int_err_inj_state_r == IDLE && int_err_inj_next_state == FLIT_FINDER);
assign int_mag_pulse_en        = (int_rand_gen_en && err_inj_error_mag_r == 'b0);
assign int_corr_offst_pulse_en = (int_rand_gen_en && err_inj_error_offst_r > 7'd82);
assign int_corr_1_grp_pulse_en = (int_err_inj_pulse_en || int_mag_pulse_en || int_corr_offst_pulse_en || (!halt_in && int_err_inj_eof_valid));
assign int_corr_3_grp_pulse_en = (int_err_inj_pulse_en || int_mag_pulse_en || int_corr_offst_pulse_en);
assign int_uncorr_pulse_en     = (int_err_inj_pulse_en || int_mag_pulse_en);

// Determine the byte location of the error to be injected in the flit
always_comb begin : err_mag_loc_PROC
  int_err_mag_loc = int_err_mag_loc_r;
  case(int_err_inj_error_type)
    FEC_CORR_ROTATE_1_GROUP: begin
      if(int_corr_1_grp_pulse_en) begin
        int_err_mag_loc = 'b0;
        case(int_err_inj_fec_grp_cnt)
          2'b00  : int_err_mag_loc[8*int_corr_error_offst_fec_grp_0[7 : 0] +: 8] = int_err_inj_error_mag;
          2'b01  : int_err_mag_loc[8*int_corr_error_offst_fec_grp_1[7 : 0] +: 8] = int_err_inj_error_mag;
          2'b10  : int_err_mag_loc[8*int_corr_error_offst_fec_grp_2[7 : 0] +: 8] = int_err_inj_error_mag;
          default: int_err_mag_loc = 'b0;
        endcase
      end
    end
    FEC_CORR_3_GROUPS: begin
      if(int_corr_3_grp_pulse_en) begin
        int_err_mag_loc = 'b0;
        int_err_mag_loc[8*int_corr_error_offst_fec_grp_0[7 : 0] +: 8] = int_err_inj_error_mag;
        int_err_mag_loc[8*int_corr_error_offst_fec_grp_1[7 : 0] +: 8] = int_err_inj_error_mag;
        int_err_mag_loc[8*int_corr_error_offst_fec_grp_2[7 : 0] +: 8] = int_err_inj_error_mag;
      end
    end
    FEC_UNCORR: begin
      if(int_uncorr_pulse_en) begin
        for (int i = 0; i <= 255; i = i + 1) begin
          if(i <= 249) begin
            int_err_mag_loc[8*i +: 8] = (i % (err_inj_error_offst_r + 1'b1) == 'b0) ? int_err_inj_error_mag : 'b0;
          end else begin
            int_err_mag_loc[8*i +: 8] = (i < (int_uncorr_error_num_ecc + 'd250)) ? int_err_inj_error_mag : 'b0;
          end
        end
      end
    end
    default : int_err_mag_loc = int_err_mag_loc_r;
  endcase
end : err_mag_loc_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : err_mag_loc_reg_PROC
  if(!core_rst_n) begin
    int_err_mag_loc_r <= #TP 'b0;
  end else begin
    int_err_mag_loc_r <= #TP int_err_mag_loc;
  end
end : err_mag_loc_reg_PROC

// Flit data width counter
always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_dw_cnt_reg_PROC
  if(!core_rst_n) begin
    int_flit_dw_cnt_r <= #TP 'b0;
  end else begin
    if(!halt_in) begin
      if(int_flit_dw_cnt_r == P_FLIT_DW_CNT - 1) begin
        int_flit_dw_cnt_r <= #TP 'b0;
      end else if(int_err_inj_valid) begin
        int_flit_dw_cnt_r <= #TP int_flit_dw_cnt_r + 1'b1;
      end else begin
        int_flit_dw_cnt_r <= #TP int_flit_dw_cnt_r;
      end
    end
  end
end : flit_dw_cnt_reg_PROC

// Error injection data output
assign xplh_err_inj_flit.sof         = flit_in.sof;
assign xplh_err_inj_flit.eof         = flit_in.eof;
assign xplh_err_inj_flit.enf         = flit_in.enf;
assign xplh_err_inj_flit.data        = (int_err_inj_valid) ? (int_err_mag_loc_r[DW*int_flit_dw_cnt_r +: DW] ^ flit_in.data) : flit_in.data;
assign xplh_err_inj_flit.data_valid  = flit_in.data_valid;
assign xplh_err_inj_flit.retry_flit  = flit_in.retry_flit;
assign xplh_err_inj_flit.expl_flit   = flit_in.expl_flit;
assign xplh_err_inj_flit.tlp_dv      = flit_in.tlp_dv;
assign xplh_err_inj_flit.flit_type_s = flit_in.flit_type_s;
assign xplh_err_inj_flit.flit_prot   = flit_in.flit_prot;
assign xplh_err_inj_flit.ras_dp_err_inband_kbd = flit_in.ras_dp_err_inband_kbd;
assign xplh_err_inj_halt = halt_in;


endmodule
