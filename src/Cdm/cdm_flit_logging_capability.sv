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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_flit_logging_capability.sv#5 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the main functions for "flit logging extended capability" including the following:
// ---   - Stores correctable and uncorrectable flit errors and their associated information including index of the flit, syndrome & parity check, unrecognized flit and link width in an internal FIFO.
// ---   - Generates the outputs required for Flit Error Log1,2 registers based on the information stored in the FIFO.
// ---   - Counts the number of flit errors based on configurations in "Flit Error Counter Control Register" and generate the outputs required for "Flit Error Counter Status Register"
// ---   - Counts the number of flits, invalid flits & FBER based on the configurations in "FBER Measurement Control Register" and generate the outputs required for "FBER Measurement Status Register"
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Cdm/cdm_pkg.svh"


module cdm_flit_logging_capability
 import cdm_pkg::flit_error_log;

                                   (
  // Inputs                                                
  input  core_clk,                                          
  input  non_sticky_rst_n,                                  
  input  sticky_rst_n,                                      
  input  rplh_valid_flit,                                   // Indication of receiving valid flit
  input  rplh_flit_fec_uncorr_err,                          // Indication of receiving invalid flit due to fec uncorr error
  input  rplh_flit_crc_uncorr_err,                          // Indication of receiving invalid flit due to crc mismatch
  input  rplh_flit_unrecognized_flit,                       // Unrecognized flit flag
  input  [2:0][7:0] rplh_flit_prot_synd_parity,             // Syndrome parity for the three groups
  input  [2:0][7:0] rplh_flit_prot_synd_check,              // Syndrome check for the three groups
  input  rplh_flit_fec_corr_error,                          // Indication of reciving FEC correctable Error
  input  [15:0][3:0] rplh_flit_fec_corr_even_bit_error ,    // Even bit errors corrected by FEC in valid Flits
  input  [15:0][3:0] rplh_flit_fec_corr_odd_bit_error,      // Odd bit errors corrected by FEC in valid Flits
  input  [15:0] rmlh_mismatch_SKP_OS,                       // Mismatches in the Control SKP OS as a single correctable bit error
  input  rmlh_framing_error,                                // Framing error flag
  input  [5:0] rplh_link_rxmode,                              // Link width
  input  [2:0] data_rate,                                   // Data rate
  input  smlh_invalid_ordered_set,                          // Flag for invalid order set
  input  smlh_corr_ordered_set,                             // Flag for Ordered Set that was corrected on any Lane
  input  cfg_fifo_pop_en,                                   // Read new Error from CDM
  input  cfg_flit_err_cnt_en,                               // Enables and starts the Flit Error Counter in the Link
  input  [1:0] cfg_evnt_to_cnt,                             // Configure events to count
  input  [7:0] cfg_trg_evnt_cnt,                            // Configuration for flit error counter interrupt
  input  cfg_fber_measurement_en,                           // Enables and starts the FBER measurement in the Link
  input  cfg_clr_fber_cnt,                                  // Clears the FBER counters
  input  [1:0] cfg_gran_per_lane_err_rpt,                   // Configure FBER type of error reported
  input  cfg_rprt_longest_burst_vs_1st_burst,               // Port (and Retimers) report the longest burst of errors in terms of UI
  input  cfg_timer_scaled,                                  // Scaling for decrement condition timer
  // Outputs                                                
  output  logic [63:0] cfg_flit_log,                        // Flit error Log 1&2 registers
  output  logic [2:0] cfg_link_wd_err_cnt_start,            // Link width when the error counter started or restarted counting
  output  logic cfg_interr_trg_evnt_cnt,                    // Trigger interrupt for Flit error counter
  output  logic cfg_interr_trg_evnt_cnt_clr,                // Clear interrupt for Flit error counter
  output  logic [7:0] cfg_flit_err_cnt,                     // Flit error counter
  output  logic [31:0] cfg_flit_cnt,                        // Flit Counter
  output  logic [15:0] cfg_invalid_flit_cnt,                // Invalid flit counter
  output  logic [15:0] cfg_lane_0_corr_cnt,                 // Lane0 FBER counter
  output  logic [15:0] cfg_lane_1_corr_cnt,                 // Lane1 FBER counter
  output  logic [15:0] cfg_lane_2_corr_cnt,                 // Lane2 FBER counter
  output  logic [15:0] cfg_lane_3_corr_cnt,                 // Lane3 FBER counter
  output  logic [15:0] cfg_lane_4_corr_cnt,                 // Lane4 FBER counter
  output  logic [15:0] cfg_lane_5_corr_cnt,                 // Lane5 FBER counter
  output  logic [15:0] cfg_lane_6_corr_cnt,                 // Lane6 FBER counter
  output  logic [15:0] cfg_lane_7_corr_cnt,                 // Lane7 FBER counter
  output  logic [15:0] cfg_lane_8_corr_cnt,                 // Lane8 FBER counter
  output  logic [15:0] cfg_lane_9_corr_cnt,                 // Lane9 FBER counter
  output  logic [15:0] cfg_lane_10_corr_cnt,                // Lane10 FBER counter
  output  logic [15:0] cfg_lane_11_corr_cnt,                // Lane11 FBER counter
  output  logic [15:0] cfg_lane_12_corr_cnt,                // Lane12 FBER counter
  output  logic [15:0] cfg_lane_13_corr_cnt,                // Lane13 FBER counter
  output  logic [15:0] cfg_lane_14_corr_cnt,                // Lane14 FBER counter
  output  logic [15:0] cfg_lane_15_corr_cnt                 // Lane15 FBER counter
);

parameter INST = 0; // The uniquifying parameter for each port logic instance
parameter FIFO_DEPTH = 16;  //Error FIFO Depth
parameter TP = `TP;  // Clock to Q delay (simulator insurance)

localparam FIFO_WIDTH = 62;  //Error FIFO width
localparam FIFO_ADDR_WIDTH = `CX_LOGBASE2(FIFO_DEPTH);
localparam AE_LEVEL = 1;  //Almost empty level
localparam AF_LEVEL = FIFO_DEPTH - 2;  //Almost full level
localparam integer REG_DELAY_DENOM = 1000; //Simulation delay parameters for the FIFO
localparam integer REG_DELAY_TIME  = `TP * REG_DELAY_DENOM; //Simulation delay parameters for the FIFO

///
logic [2:0] received_link_width;

always @ (*) begin
    case(rplh_link_rxmode)
     6'b000010 : received_link_width = 3'b001;
     6'b000100 : received_link_width = 3'b010;
     6'b001000 : received_link_width = 3'b011;
     6'b010000 : received_link_width = 3'b100;
    default : received_link_width = 3'b000; 
    endcase 
end
///

logic  rplh_flit_received;
assign rplh_flit_received = rplh_valid_flit;
  
logic new_error;
logic new_error_r;
logic rplh_invalid_flit;
assign rplh_invalid_flit = rplh_flit_fec_uncorr_err | rplh_flit_crc_uncorr_err;
assign new_error = rplh_flit_fec_corr_error | rplh_invalid_flit | rplh_flit_unrecognized_flit;

always @(posedge core_clk or negedge sticky_rst_n) begin : new_error_delayed
  if(!sticky_rst_n) new_error_r <= #TP 1'b0;
  else              new_error_r <= #TP new_error;
end : new_error_delayed
///
logic [3:0] offset_cnt;
logic clear_offset_cnt;
always @(posedge core_clk or negedge sticky_rst_n) begin : offset_count
  if(!sticky_rst_n) offset_cnt <= #TP 'b0;
  else if (clear_offset_cnt) offset_cnt <= #TP 'b1;
  else if (rplh_flit_received && (offset_cnt != 4'hf)) offset_cnt <= #TP offset_cnt + 1'b1;
end : offset_count

logic first_error;
always @(posedge core_clk or negedge sticky_rst_n) begin : first_error_received
  if(!sticky_rst_n) first_error <= #TP 1'b0;
  else if (new_error) first_error <= #TP 1'b1;
end : first_error_received
///

flit_error_log next_flit_error_entry;
logic fifo_full, next_flit_error_full;
logic [2:0] consec_index;

always @(posedge core_clk or negedge sticky_rst_n) begin : flit_error_entry
  if(!sticky_rst_n) begin
    next_flit_error_entry  <= #TP '{default:'0};
    consec_index <= #TP 3'b000;
  end else if (rplh_flit_received) begin
    if (~next_flit_error_full) begin
         if (new_error) begin
           next_flit_error_entry.link_width <= #TP received_link_width;
           next_flit_error_entry.flit_offset <= #TP (first_error == 1'b1) ? offset_cnt : 'b0;
           next_flit_error_entry.unrec_flit <= #TP rplh_flit_unrecognized_flit;
           next_flit_error_entry.fec_uncorrectable_err <= #TP rplh_invalid_flit;
           next_flit_error_entry.synd_par_0 <= #TP rplh_flit_prot_synd_parity[0];
           next_flit_error_entry.synd_chk_0 <= #TP rplh_flit_prot_synd_check[0];
           next_flit_error_entry.synd_par_1 <= #TP rplh_flit_prot_synd_parity[1];
           next_flit_error_entry.synd_chk_1 <= #TP rplh_flit_prot_synd_check[1];
           next_flit_error_entry.synd_par_2 <= #TP rplh_flit_prot_synd_parity[2];
           next_flit_error_entry.synd_chk_2 <= #TP rplh_flit_prot_synd_check[2];
           next_flit_error_entry.cons_error <= #TP 3'b000; 
         end 
         consec_index <= #TP 3'b000;
    end else if (consec_index <= 3'b100) begin
    next_flit_error_entry.cons_error[consec_index] <= #TP new_error;
    consec_index <= #TP consec_index + 1'b1;
    end
  end
end : flit_error_entry

always @(posedge core_clk or negedge sticky_rst_n) begin : clear_offset_count
  if(!sticky_rst_n) clear_offset_cnt <= #TP  1'b0;
  else if (~next_flit_error_full && new_error) clear_offset_cnt <= #TP 1'b1;  
  else clear_offset_cnt <= #TP 1'b0;
end : clear_offset_count


flit_error_log fifo_input;
logic [61:0] fifo_input_data;
logic fifo_write_en, fifo_pop_req_n;
logic fifo_empty, fifo_almost_empty;

always @(posedge core_clk or negedge sticky_rst_n) begin : write_to_fifo
  if(!sticky_rst_n) begin
    fifo_input <= #TP '{default:'0};
    fifo_write_en <= #TP 1'b0;
    next_flit_error_full <= #TP 1'b0;
  end else if (new_error_r || next_flit_error_full) begin
      if (~fifo_full) begin
        fifo_input <= #TP next_flit_error_entry;
        fifo_write_en <= #TP 1'b1;
        next_flit_error_full <= #TP 1'b0; 
      end else begin
        next_flit_error_full <= #TP 1'b1;
        fifo_write_en <= #TP 1'b0; 
      end
  end else begin
  fifo_write_en <= #TP 1'b0;
  end
end : write_to_fifo


assign fifo_input_data = {fifo_input.synd_chk_2, fifo_input.synd_par_2, fifo_input.synd_chk_1, fifo_input.synd_par_1, fifo_input.synd_chk_0, fifo_input.synd_par_0, fifo_input.fec_uncorrectable_err, fifo_input.unrec_flit, fifo_input.cons_error, fifo_input.flit_offset, fifo_input.link_width};

assign fifo_pop_req_n = ~cfg_fifo_pop_en;

DWC_pcie_ctl_bcm65_td
 #(.WIDTH(FIFO_WIDTH), .DEPTH(FIFO_DEPTH), .AE_LEVEL(AE_LEVEL), .AF_LEVEL(AF_LEVEL), .ADDR_WIDTH(FIFO_ADDR_WIDTH), .REG_DELAY_TIME(REG_DELAY_TIME), .REG_DELAY_DENOM(REG_DELAY_DENOM)) error_fifo (
 .clk(core_clk),
 .rst_n(sticky_rst_n),
 .init_n(1'b1),
 .push_req_n(~fifo_write_en),
 .pop_req_n(fifo_pop_req_n),
 .diag_n(1'b1),
 .data_in(fifo_input_data),
 .empty(fifo_empty),
 .almost_empty(fifo_almost_empty),
 .half_full(),
 .almost_full(),
 .full(fifo_full),
 .error(),
 .data_out({cfg_flit_log[63:14],cfg_flit_log[12:1]})
);

assign cfg_flit_log[0] = ~fifo_empty;
assign cfg_flit_log[13] = ~fifo_almost_empty;

// FLIT Error Counter

logic clear_flit_error_counter, flit_error_counter_en_r;
always @(posedge core_clk or negedge sticky_rst_n) begin
  if(!sticky_rst_n) flit_error_counter_en_r <= #TP 1'b0;
  else              flit_error_counter_en_r <= #TP cfg_flit_err_cnt_en;
end

assign clear_flit_error_counter = cfg_flit_err_cnt_en && ~flit_error_counter_en_r;
assign cfg_interr_trg_evnt_cnt_clr = clear_flit_error_counter;
///link width when counter starts
always @(posedge core_clk or negedge sticky_rst_n) begin
  if(!sticky_rst_n) cfg_link_wd_err_cnt_start <= #TP 'b0;
  else if(clear_flit_error_counter) cfg_link_wd_err_cnt_start <= #TP received_link_width;
end
///
///Interrupt generated based on trigger event
logic interr_trg_evnt_cnt, interr_trg_evnt_cnt_r;

assign interr_trg_evnt_cnt = ( cfg_flit_err_cnt_en & ~cfg_interr_trg_evnt_cnt_clr & (|cfg_trg_evnt_cnt) & (cfg_flit_err_cnt > cfg_trg_evnt_cnt)) ? 1'b1 : 1'b0;

always @(posedge core_clk or negedge sticky_rst_n) begin
  if(!sticky_rst_n) interr_trg_evnt_cnt_r <= #TP 1'b0;
  else interr_trg_evnt_cnt_r <= #TP interr_trg_evnt_cnt;
end
assign cfg_interr_trg_evnt_cnt = interr_trg_evnt_cnt & ~interr_trg_evnt_cnt_r;

///
///Flit Error Counter
logic flit_error_counter_inc, flit_error_counter_dec;
logic rplh_flit_fec_corr_error_r, rplh_invalid_flit_r, rmlh_framing_error_r, smlh_invalid_ordered_set_r, smlh_corr_ordered_set_r;

always @(posedge core_clk or negedge sticky_rst_n) begin
  if(!sticky_rst_n) begin
  rplh_flit_fec_corr_error_r <= #TP 1'b0;
  rplh_invalid_flit_r <= #TP 1'b0;
  rmlh_framing_error_r <= #TP 1'b0;
  smlh_invalid_ordered_set_r <= #TP 1'b0;
  smlh_corr_ordered_set_r <= #TP 1'b0;
  end else begin
  rplh_flit_fec_corr_error_r <= #TP rplh_flit_fec_corr_error;
  rplh_invalid_flit_r <= #TP rplh_invalid_flit;
  rmlh_framing_error_r <= #TP rmlh_framing_error;
  smlh_invalid_ordered_set_r <= #TP smlh_invalid_ordered_set;
  smlh_corr_ordered_set_r <= #TP smlh_corr_ordered_set;
  end
end

always @ (*) begin
    case(cfg_evnt_to_cnt)
     2'b01 : flit_error_counter_inc = rplh_flit_fec_corr_error_r;
     2'b10 : flit_error_counter_inc = rplh_invalid_flit_r;
     2'b11 : flit_error_counter_inc = rplh_flit_fec_corr_error_r | rplh_invalid_flit_r | rmlh_framing_error_r | smlh_invalid_ordered_set_r | smlh_corr_ordered_set_r;
     default : flit_error_counter_inc = rplh_flit_fec_corr_error_r | rplh_invalid_flit_r | rmlh_framing_error_r;
    endcase 
end

// -------------------------------------------------------------------------
// Timers for decrement condition
// -------------------------------------------------------------------------
// Decrement timer for gen6 data rates
localparam        BASE_TIMER_WIDTH        = 12;
localparam        BASE_TIMER_RST_VAL      = 12'd0;
localparam [BASE_TIMER_WIDTH - 1 : 0] BASE_TIMER_INCR = `CX_FREQ_MULTIPLIER;
localparam        GEN2_DYNAMIC_FREQ_VALUE             = `CX_GEN2_DYNAMIC_FREQ_VALUE;
localparam        TIMER_TARGET                        = 1'd1;

logic [BASE_TIMER_WIDTH - 1 : 0]  int_base_timer_target;
logic int_ns_timer_en, int_ns_timer_timeout;
assign int_ns_timer_en = (data_rate == 3'b101) ? (cfg_flit_err_cnt_en && (cfg_flit_err_cnt != 'b0)) : 1'b0 ;


always @ (*) begin
    unique case(rplh_link_rxmode)
     6'b000001 : int_base_timer_target = 12'd3908;   // 15625 ns   
     6'b000010 : int_base_timer_target = 12'd1952;   // 7812.5 ns
     6'b000100 : int_base_timer_target = 12'd976;    // 3906.25 ns
     6'b001000 : int_base_timer_target = 12'd488;    // 1953.125 ns
     6'b010000 : int_base_timer_target = 12'd244;    // 976.5625 ns
    default : int_base_timer_target = 12'd0; 
    endcase 
end

DWC_pcie_us_timer
 #(
  .TIMER_WIDTH              (1),
  .GEN2_DYNAMIC_FREQ_VALUE  (GEN2_DYNAMIC_FREQ_VALUE),
  .BASE_TIMER_WIDTH         (BASE_TIMER_WIDTH),
  .BASE_TIMER_RST_VAL       (BASE_TIMER_RST_VAL)
) flit_err_cnt_dec_timer_ns (
  // Inputs
  .clk                (core_clk),
  .rst_n              (sticky_rst_n),
  .clear_timer        (~int_ns_timer_en),
  .hold_timer         (1'b0),
  .enable             (int_ns_timer_en),
  .timer_target       (TIMER_TARGET),
  .current_data_rate  (data_rate),
  .base_timer_target  (int_base_timer_target),
  .base_timer_incr    (BASE_TIMER_INCR),
  .base_timer_clear   (~int_ns_timer_en),
  // Outputs
  .us_timeout_r       (),
  .us_timer           (),
  .us_timeout       (int_ns_timer_timeout)
);
///////////////////////////////////////////
// Decrement timer for gen1:gen5 data rates
localparam        MS_TIMER_WIDTH        = 19;
localparam        MS_BASE_TIMER_WIDTH        = 9;
localparam        MS_BASE_TIMER_TARGET       = 9'd256;
localparam        MS_BASE_TIMER_RST_VAL      = 9'd0;
localparam [MS_BASE_TIMER_WIDTH - 1 : 0] MS_BASE_TIMER_INCR = `CX_FREQ_MULTIPLIER;

logic [MS_TIMER_WIDTH - 1 : 0]  int_ms_timer_target;
logic int_ms_timer_en, int_ms_timer_timeout;

assign int_ms_timer_en = (data_rate != 3'b101) ? (cfg_flit_err_cnt_en && (cfg_flit_err_cnt != 'b0)) : 1'b0 ;


always @ (*) begin
    int_ms_timer_target = 19'd0;
    unique case (data_rate)
    3'b000: begin
      if (rplh_link_rxmode == 6'b000001)       int_ms_timer_target = 19'd390625;   // 400 s
      else if (rplh_link_rxmode == 6'b000010)  int_ms_timer_target = 19'd195312;   // 200 s
      else if (rplh_link_rxmode == 6'b000100)  int_ms_timer_target = 19'd97656;    // 100 s
      else if (rplh_link_rxmode == 6'b001000)  int_ms_timer_target = 19'd48828;    // 50 s
      else if (rplh_link_rxmode == 6'b010000)  int_ms_timer_target = 19'd24414;    // 25 s
    end
    3'b001: begin
      if (rplh_link_rxmode == 6'b000001)       int_ms_timer_target = 19'd195312;   // 200 s
      else if (rplh_link_rxmode == 6'b000010)  int_ms_timer_target = 19'd97656;    // 100 s
      else if (rplh_link_rxmode == 6'b000100)  int_ms_timer_target = 19'd48828;    // 50 s
      else if (rplh_link_rxmode == 6'b001000)  int_ms_timer_target = 19'd24414;    // 25 s
      else if (rplh_link_rxmode == 6'b010000)  int_ms_timer_target = 19'd12207;    // 12.5 s
    end
    3'b010: begin
      if (rplh_link_rxmode == 6'b000001)       int_ms_timer_target = 19'd122070;   // 125 s
      else if (rplh_link_rxmode == 6'b000010)  int_ms_timer_target = 19'd61035;    // 62.5 s
      else if (rplh_link_rxmode == 6'b000100)  int_ms_timer_target = 19'd30517;    // 31.25 s
      else if (rplh_link_rxmode == 6'b001000)  int_ms_timer_target = 19'd15259;    // 15.625 s
      else if (rplh_link_rxmode == 6'b010000)  int_ms_timer_target = 19'd7629;    // 7.8125 s
    end
    3'b011: begin
      if (rplh_link_rxmode == 6'b000001)       int_ms_timer_target = 19'd61035;    // 62.5 s
      else if (rplh_link_rxmode == 6'b000010)  int_ms_timer_target = 19'd30517;    // 31.25 s
      else if (rplh_link_rxmode == 6'b000100)  int_ms_timer_target = 19'd15259;    // 15.625 s
      else if (rplh_link_rxmode == 6'b001000)  int_ms_timer_target = 19'd7629;    // 7.8125 s
      else if (rplh_link_rxmode == 6'b010000)  int_ms_timer_target = 19'd3815;    // 3.90625 s
    end
    3'b100: begin
      if (rplh_link_rxmode == 6'b000001)       int_ms_timer_target = 19'd30517;    // 31.25 s
      else if (rplh_link_rxmode == 6'b000010)  int_ms_timer_target = 19'd15259;    // 15.625 s
      else if (rplh_link_rxmode == 6'b000100)  int_ms_timer_target = 19'd7629;    // 7.8125 s
      else if (rplh_link_rxmode == 6'b001000)  int_ms_timer_target = 19'd3815;    // 3.90625 s
      else if (rplh_link_rxmode == 6'b010000)  int_ms_timer_target = 19'd1907;    // 1.953125 s
    end
    default : int_ms_timer_target = 19'd0; 
    endcase 
end

DWC_pcie_ms_timer

 #(
 .TIMER_WIDTH (MS_TIMER_WIDTH),
  .GEN2_DYNAMIC_FREQ_VALUE  (GEN2_DYNAMIC_FREQ_VALUE),
  .BASE_TIMER_WIDTH         (MS_BASE_TIMER_WIDTH),
  .BASE_TIMER_RST_VAL       (MS_BASE_TIMER_RST_VAL)
 ) flit_err_cnt_dec_timer_ms (
 .clk (core_clk),
 .rst_n (sticky_rst_n),
 .clear_timer (~int_ms_timer_en),
 .hold_timer (1'b0),
 .enable (int_ms_timer_en),
 .timer_target (int_ms_timer_target),
 .current_data_rate (data_rate),
 .scale_timer (cfg_timer_scaled),
 .base_timer_target (MS_BASE_TIMER_TARGET),
 .base_timer_incr (MS_BASE_TIMER_INCR),
 .base_timer_clear (~int_ms_timer_en),
 .ms_timeout_r (int_ms_timer_timeout),
 .ms_timeout   (),
 .ms_timer     (),
 .us_timeout   ()
);
///////////////////////////////////////////
assign flit_error_counter_dec = (data_rate == 3'b101) ? int_ns_timer_timeout : int_ms_timer_timeout ;
////////////////////////////////////////////////////////////

always @(posedge core_clk or negedge sticky_rst_n) begin
  if(!sticky_rst_n) cfg_flit_err_cnt <= #TP 'b0;
  else if(clear_flit_error_counter) cfg_flit_err_cnt <= #TP 'b0;
  else if(cfg_flit_err_cnt_en) begin
   if (flit_error_counter_inc && !flit_error_counter_dec && (cfg_flit_err_cnt != 8'hff)) cfg_flit_err_cnt <= #TP cfg_flit_err_cnt + 1'b1;
   else if (flit_error_counter_dec && !flit_error_counter_inc) cfg_flit_err_cnt <= #TP cfg_flit_err_cnt - 1'b1;
  end
end

// FLIT FBER Counter
logic [15:0] cfg_lane_corr_cnt [15:0];
logic [15:0] cfg_lane_corr_cnt_s [15:0];
logic [15:0] cntr_overflow;
logic clr_fber_cnt, cfg_fber_measurement_en_r;

always @(posedge core_clk or negedge sticky_rst_n) begin
  if(!sticky_rst_n) cfg_fber_measurement_en_r <= #TP 1'b0;
  else          cfg_fber_measurement_en_r <= #TP cfg_fber_measurement_en;
end

assign clr_fber_cnt = cfg_clr_fber_cnt || (cfg_fber_measurement_en && ~cfg_fber_measurement_en_r);

always @(posedge core_clk or negedge sticky_rst_n) begin
  if(!sticky_rst_n) cfg_flit_cnt <= #TP 'b0;
  else if(clr_fber_cnt) cfg_flit_cnt <= #TP 'b0;
  else if(cfg_fber_measurement_en && rplh_flit_received && (cfg_flit_cnt != 32'hffffffff)) cfg_flit_cnt <= #TP cfg_flit_cnt + 1'b1;
end

always @(posedge core_clk or negedge sticky_rst_n) begin
  if(!sticky_rst_n) cfg_invalid_flit_cnt <= #TP 'b0;
  else if(clr_fber_cnt) cfg_invalid_flit_cnt <= #TP 'b0;
  else if(cfg_fber_measurement_en && rplh_invalid_flit && (cfg_invalid_flit_cnt != 16'hffff)) cfg_invalid_flit_cnt <= #TP cfg_invalid_flit_cnt + 1'b1;
end


logic  [4:0] fber_inc_value [15:0];
logic  [15:0] rmlh_mismatch_SKP_OS_r;

genvar i;
generate
for (i=0; i<16 ; i=i+1) begin
always @ (*) begin
    case(cfg_gran_per_lane_err_rpt)
     2'b00 : fber_inc_value[i] = {1'b0,rplh_flit_fec_corr_even_bit_error[i]} + {1'b0,rplh_flit_fec_corr_odd_bit_error[i]}; 
     2'b01 : fber_inc_value[i] = {1'b0,rplh_flit_fec_corr_even_bit_error[i]};
     2'b10 : fber_inc_value[i] = {1'b0,rplh_flit_fec_corr_odd_bit_error[i]};
     default : fber_inc_value[i] = 'b0;
    endcase 
end
always @(posedge core_clk or negedge non_sticky_rst_n) begin
  if(!non_sticky_rst_n) rmlh_mismatch_SKP_OS_r[i] <= #TP 'b0;
  else rmlh_mismatch_SKP_OS_r[i] <= #TP rmlh_mismatch_SKP_OS[i];
end
always @(posedge core_clk or negedge non_sticky_rst_n) begin
  if(!non_sticky_rst_n) {cntr_overflow[i],cfg_lane_corr_cnt_s[i]} <= #TP 'b0;
  else if(clr_fber_cnt) {cntr_overflow[i],cfg_lane_corr_cnt_s[i]} <= #TP 'b0;
  else if(cfg_fber_measurement_en) begin 
    if (~cntr_overflow[i]) begin
       if ((cfg_gran_per_lane_err_rpt == 2'b11) && rmlh_mismatch_SKP_OS_r[i]) {cntr_overflow[i],cfg_lane_corr_cnt_s[i]} <= #TP {1'b0,cfg_lane_corr_cnt_s[i]} + {17'd1};
       else if (rplh_flit_received) {cntr_overflow[i],cfg_lane_corr_cnt_s[i]} <= #TP {1'b0,cfg_lane_corr_cnt_s[i]} + {12'd0,fber_inc_value[i]};
    end
  end
end
always @(posedge core_clk or negedge non_sticky_rst_n) begin
  if(!non_sticky_rst_n) cfg_lane_corr_cnt[i] <= #TP 'b0;
  else if(clr_fber_cnt) cfg_lane_corr_cnt[i] <= #TP 'b0;
  else if(cfg_fber_measurement_en) begin
    if (cntr_overflow[i]) cfg_lane_corr_cnt[i] <= #TP 16'hffff;
    else cfg_lane_corr_cnt[i] <= #TP cfg_lane_corr_cnt_s[i];
  end
end
end
endgenerate

assign cfg_lane_0_corr_cnt  = cfg_lane_corr_cnt[0];
assign cfg_lane_1_corr_cnt  = cfg_lane_corr_cnt[1];
assign cfg_lane_2_corr_cnt  = cfg_lane_corr_cnt[2];
assign cfg_lane_3_corr_cnt  = cfg_lane_corr_cnt[3];
assign cfg_lane_4_corr_cnt  = cfg_lane_corr_cnt[4];
assign cfg_lane_5_corr_cnt  = cfg_lane_corr_cnt[5];
assign cfg_lane_6_corr_cnt  = cfg_lane_corr_cnt[6];
assign cfg_lane_7_corr_cnt  = cfg_lane_corr_cnt[7];
assign cfg_lane_8_corr_cnt  = cfg_lane_corr_cnt[8];
assign cfg_lane_9_corr_cnt  = cfg_lane_corr_cnt[9];
assign cfg_lane_10_corr_cnt = cfg_lane_corr_cnt[10];
assign cfg_lane_11_corr_cnt = cfg_lane_corr_cnt[11];
assign cfg_lane_12_corr_cnt = cfg_lane_corr_cnt[12];
assign cfg_lane_13_corr_cnt = cfg_lane_corr_cnt[13];
assign cfg_lane_14_corr_cnt = cfg_lane_corr_cnt[14];
assign cfg_lane_15_corr_cnt = cfg_lane_corr_cnt[15];
  
endmodule
