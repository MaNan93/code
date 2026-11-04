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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #18 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_fm_shift_ms.sv#18 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XTLH_FM_SHIFT
//
// Description: Implements the shift register for accumulating and shift data to Layer2.
//
// -------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_fm_shift_ms
  import  cx_pl_pkg::tx_flit_struct;
  import  cx_pl_pkg::P_DW;
  import  cx_pl_pkg::P_NW;
  import  cx_pl_pkg::P_DLP2_END;
  import  cx_pl_pkg::P_TYPE_OF_DLP;
  import  cx_pl_pkg::tx_cmd_struct;
  import  cx_pl_pkg::CMD_RESET;
  import  xtlh_ms_pkg::flit_marker_struct;
  import  xtlh_ms_pkg::P_NW_CNT_WD;
  import  xtlh_ms_pkg::count_dw;
  import  cx_pl_pkg::flit_type_struct;
  import  xtlh_ms_pkg::E_POISON;
  import  xtlh_ms_pkg::E_NULLIFIED;
  import  xtlh_ms_pkg::E_NONE;
  import  xtlh_ms_pkg::find_first_over;
  import  xtlh_ms_pkg::count_sots;
  import  xtlh_ms_pkg::flit_shift_struct;
  import  xtlh_ms_pkg::P_DW_CNT_WD;
  import  xtlh_ms_pkg::P_DW_LAST;
  import  xtlh_ms_pkg::P_ACCUM_DW_WD;
  import  xtlh_ms_pkg::P_OVER_CNT_WD;
  import  xtlh_ms_pkg::calculate_overflow;
  import  xtlh_ms_pkg::load_data;
  import  xtlh_ms_pkg::load_accum_1dw;
  import  xtlh_ms_pkg::load_accum_2dw;
  import  xtlh_ms_pkg::load_accum_3dw;
  import  xtlh_ms_pkg::load_accum_4dw;
  import  xtlh_ms_pkg::load_accum_5dw;
  import  xtlh_ms_pkg::load_accum_6dw;
  import  xtlh_ms_pkg::load_accum_7dw;
  import  xtlh_ms_pkg::load_accum_8dw;
  import  xtlh_ms_pkg::load_accum_9dw;
  import  xtlh_ms_pkg::load_accum_10dw;
  import  xtlh_ms_pkg::load_accum_11dw;
  import  xtlh_ms_pkg::load_accum_12dw;
  import  xtlh_ms_pkg::load_accum_13dw;
  import  xtlh_ms_pkg::load_accum_14dw;
  import  xtlh_ms_pkg::load_accum_15dw;
  import  xtlh_ms_pkg::load_accum_16dw;
  import  xtlh_ms_pkg::shift_data_only;
  import  xtlh_ms_pkg::P_XTLH_MAX_TLP_CNT_WD;
  import  xtlh_ms_pkg::P_DW_HALF;
  import  xtlh_ms_pkg::P_SHIFT_NW;
      import cx_pl_pkg::DATA_PAR_WD;
      import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter TP = `TP
) 
                         (
  input                                     core_clk,
  input                                     core_rst_n,
  input   tx_cmd_struct                     xdlh_xtlh_cmd,              // Command Interface
  input   [P_DW - 1 : 0]                    data,                       // Data input to the shift
  input                                     dv,                         // Data Valid
  input   [P_NW - 1 : 0]                    sot,                        // Start of TLP
  input   [P_NW - 1 : 0]                    eot,                        // End of TLP
  input                                     flit_mode_en,               // Enable Flit Mode
  input   [P_NW_CNT_WD - 1 : 0]             next_sot_cnt,
  input                                     spif_enable,                // Enable CXL Mode
  input   flit_type_struct                  flit_type,                  // Flit Type
  input                                     flit_gen_en,                // Enable Flit Generator
  input                                     halt_in,                    // Downstream halt
  input   flit_marker_struct  [P_NW-1:0]    flit_marker,                // Flit Marker
  output  logic                             xtlh_fm_shift_tlp_pending,  // TLP Pending
  output  tx_flit_struct                    xtlh_fm_shift_flit,         // Shift register output
  output  logic                             xtlh_fm_shift_marker_sent,  // Flit Marker Sent indication
  output  logic                             xtlh_fm_shift_halt,         // Halt Out
  output  logic [P_NW - 1 : 0]              xtlh_fm_shift_eot,          // EOT
  output  logic [P_XTLH_MAX_TLP_CNT_WD-1:0] xtlh_fm_shift_eot_cnt,    // EOT Counter
  output  logic [P_XTLH_MAX_TLP_CNT_WD-1:0] xtlh_fm_shift_over_cnt    // Overflow SOT counter  
    ,
    input logic                             ras_dp_err_inband_kbd
      ,
      input  ras_dp_err_inj_t               ras_dp_err_inj
);
// For 128-bit config extend the EOT count width to 4-bits
localparam  P_EOT_CNT_WD = $clog2(P_NW) ;
localparam  P_ONE = {{P_EOT_CNT_WD{1'b0}}, 1'b1};
localparam  P_ZERO = {{P_EOT_CNT_WD{1'b0}}, 1'b0};
localparam  P_DW_CNT_RST = {P_DW_CNT_WD{1'b0}};
localparam  P_DW_CNT_MAX = {P_DW_CNT_WD{1'b1}};
 // DW Containing the Flit Marker
localparam  P_FM_DW_POS = P_NW - 4 - 1;
localparam  P_DLP0_START_POS = 0;
localparam  P_TYPE_OF_DLP_BIT = P_DLP0_START_POS + 4;
localparam  P_DLP2_END_BIT = P_DLP0_START_POS + (3*8) - 1;
localparam  P_FLIT_STATUS_END = P_DLP2_END_BIT - 1;
localparam  P_MARKER_PTM = P_DLP2_END_BIT - 3;

flit_shift_struct                 int_shift_reg_s;
flit_shift_struct                 int_next_data_s;
flit_shift_struct                 int_shift_pipe_s;
flit_shift_struct                 int_shift_reg_r;
logic                             int_max_tlp_halt_r;
logic                             int_merge_tlp_halt;
logic [P_NW_CNT_WD : 0]           int_sot_in_cnt;
logic [P_NW_CNT_WD - 1 : 0]       int_sot_overflow_cnt;
logic [P_NW_CNT_WD - 1 : 0]       int_sot_overflow_cnt_r;
logic                             int_flit_dv_s;
logic                             int_flit_dv_r;
logic [P_ACCUM_DW_WD - 1 : 0]     int_accum_dw_r;
logic [P_ACCUM_DW_WD - 1 : 0]     int_next_accum_dw_s;
logic [P_DW_CNT_WD - 1 : 0]       int_flit_dw_cnt_r;
logic                             int_insert_fm;
logic [P_DW_CNT_WD - 1 : 0]       int_nop_dw_cnt_r;
logic                             int_fm_sof_s;
logic [1 : 0]                     int_fm_eof_s;
logic                             int_fm_enf_s;
logic [P_DW - 1 : 0]              int_fm_data_s;
logic [P_NW - 1 : 0]              int_fm_sot_s;
logic                             int_flit_gen_en_r;
logic [P_XTLH_MAX_TLP_CNT_WD-1:0] int_eot_cnt [P_NW - 1 : 0];
logic [P_XTLH_MAX_TLP_CNT_WD-1:0] int_tot_eot_cnt_r; 
logic                             int_sample_eot_cnt;
logic [P_XTLH_MAX_TLP_CNT_WD-1:0] int_fm_shift_eot_cnt_r;
logic                             int_marker_pending_r;
logic                             int_any_flit_marker_s;
logic                             int_end_flit_marker_s;
flit_marker_struct                int_latch_flit_marker_s;
flit_marker_struct                int_latch_flit_marker_r;
flit_marker_struct                int_flit_marker_r;
flit_marker_struct                int_flit_marker;
logic                             int_data_valid_r;
logic                             int_data_valid_s;
logic [P_XTLH_MAX_TLP_CNT_WD-1:0] int_shift_over_cnt_s;
logic [P_XTLH_MAX_TLP_CNT_WD-1:0] int_sot_over_cnt_s;
logic [P_NW + 5 - 1 : 0]          int_first_sot_over_s;
logic [P_NW + 5 - 1 : 0]          int_first_eot_over_s;
logic                             int_tlp_dv_r;
logic int_preload;

assign int_preload = 1'b0;

// 8 TLP's starting in the shift register halt the incoming data
assign int_sot_in_cnt = count_dw(int_shift_reg_s.sot[P_NW-1:0]);

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_max_tlp_halt_r  <= #TP 1'b0;
  else begin
    if(!halt_in)
      int_max_tlp_halt_r  <= #TP 1'b0;
    else if((int_sot_in_cnt > 7) && ((int_shift_reg_s.eot[P_NW-1:0]) > (int_shift_reg_s.sot[P_NW-1:0])))
      int_max_tlp_halt_r  <= #TP 1'b1;
  end
end

// The number of TLP's in the overflow portion of the shift
assign int_sot_overflow_cnt = count_dw(int_shift_reg_s.sot[P_SHIFT_NW-5-1:P_NW]);

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_sot_overflow_cnt_r  <= #TP 1'b0;
  else begin
    if(!halt_in)
      int_sot_overflow_cnt_r <= #TP int_sot_overflow_cnt;
  end
end

// Prevent merging new data when there is data accumulated
assign int_merge_tlp_halt = ((int_accum_dw_r <= P_NW) && (int_accum_dw_r > 0)) && (next_sot_cnt != 0) && ((int_sot_overflow_cnt_r + next_sot_cnt) >= 7);

typedef enum {
  IDLE,
  PTM,
  POISONED,
  NULLIFIED,
  PTM_POISONED,
  PTM_NULLIFIED

} state_e;

state_e state_r,  next_state;

assign int_insert_fm = (int_flit_dw_cnt_r == P_DW_LAST - 1) ? 1'b1 : 1'b0;

always_comb begin : flit_marker_state_PROC
  next_state = state_r;
  case(state_r)
    //PTM FLIT MARKER
    PTM : begin
     if(int_insert_fm)
        next_state = IDLE;
     else if(int_flit_dw_cnt_r <= P_DW_LAST - 1 && int_latch_flit_marker_s.flit_status == E_POISON)
        next_state = PTM_POISONED;
     else if(int_flit_dw_cnt_r <= P_DW_LAST - 1 && int_latch_flit_marker_s.flit_status == E_NULLIFIED)
        next_state = PTM_NULLIFIED;
     else 
        next_state = PTM;
     end 
    //Poisoned Flit Marker
    POISONED : begin
     if(int_insert_fm)
        next_state = IDLE;
      else 
        next_state = POISONED;
     end
    //NULLIFIED Flit Marker
    NULLIFIED : begin
     if(int_insert_fm)
        next_state = IDLE;
     else 
        next_state = NULLIFIED;
     end
    //PTM POISONED Flit Marker
    PTM_POISONED : begin
     if(int_insert_fm)
        next_state = IDLE;
     else 
        next_state = PTM_POISONED;
     end
    //PTM Nullified Flit Marker
    PTM_NULLIFIED : begin
     if(int_insert_fm)
        next_state = IDLE;
     else 
        next_state = PTM_NULLIFIED;
     end
   //IDLE
   default : begin
    if(!int_end_flit_marker_s && int_latch_flit_marker_s.flit_status == E_POISON)
       next_state = POISONED;
    else if (!int_end_flit_marker_s && int_latch_flit_marker_s.flit_status == E_NULLIFIED)
       next_state = NULLIFIED;
    else if (!int_end_flit_marker_s && int_latch_flit_marker_s.ptm_in_flit)
       next_state = PTM;
   end
  endcase
end : flit_marker_state_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : fsm_out_sync_PROC
  if(!core_rst_n) begin
    state_r                 <= #TP IDLE;
    int_flit_marker_r       <= #TP '0;
    int_latch_flit_marker_r <= #TP '0;
  end else begin
    state_r                 <= #TP (halt_in) ? state_r : next_state;
    int_flit_marker_r       <= #TP (halt_in) ? int_flit_marker_r : int_flit_marker;
    int_latch_flit_marker_r <= #TP int_latch_flit_marker_s;
    end
end : fsm_out_sync_PROC

always_comb begin : fsm_out_PROC 
  int_flit_marker = int_flit_marker_r;
 unique case(state_r)
 //PTM Flit marker 
  PTM : begin
   int_flit_marker.flit_marker_indication =1'b1;
   int_flit_marker.flit_status = E_NONE;
   int_flit_marker.ptm_in_flit = 1'b1;
  end
 //Poisoned Flit marker 
  POISONED : begin
   int_flit_marker.flit_marker_indication =1'b1;
   int_flit_marker.flit_status = E_POISON;
   int_flit_marker.ptm_in_flit = 1'b0;
  end
  //NULLIFIED Flit Marker
  NULLIFIED : begin
   int_flit_marker.flit_marker_indication =1'b1;
   int_flit_marker.flit_status = E_NULLIFIED;
   int_flit_marker.ptm_in_flit = 1'b0;
  end
  //PTM POISONED Flit Marker
  PTM_POISONED : begin
   int_flit_marker.flit_marker_indication =1'b1;
   int_flit_marker.flit_status = E_POISON;
   int_flit_marker.ptm_in_flit = 1'b1;
   end
  //PTM Nullified Flit Marker
  PTM_NULLIFIED : begin
   int_flit_marker.flit_marker_indication =1'b1;
   int_flit_marker.flit_status = E_NULLIFIED;
   int_flit_marker.ptm_in_flit = 1'b1;
  end
  //IDLE
  default : begin
   int_flit_marker = '0;
  end
 endcase
end : fsm_out_PROC

// Enable Flit Generator when valid data is presented
always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_gen_en_PROC
  if(!core_rst_n)
    int_flit_gen_en_r     <= #TP '0;
  else begin
    if(xdlh_xtlh_cmd.tx_cmd == CMD_RESET)
        int_flit_gen_en_r <= #TP '0;
    else begin
      // TODO: Consider to remove macro. There is still transition in command interface
      // from PYLD to NOP state during a recovery where flit_gen_en is de-asserted and NOP generator is enabled instead.
      // CXL Mode Enable + (xtlh_fm_shift_tlp_pending reset condition) + not (int_flit_gen_en_r set condition)
      if(spif_enable && (!halt_in && xtlh_fm_shift_tlp_pending && xtlh_fm_shift_flit.eof[1] && !int_data_valid_s) && !(flit_gen_en && dv))
        int_flit_gen_en_r <= #TP '0;
      else
      if(!halt_in && flit_gen_en && dv) 
        int_flit_gen_en_r <= #TP '1;
    end
  end
end : flit_gen_en_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_frame_PROC
  if(!core_rst_n) begin
    int_flit_dw_cnt_r <= #TP '0;
  end else begin
    if(!int_flit_gen_en_r)
      int_flit_dw_cnt_r <= #TP '0;
    else if(int_flit_dv_r && !halt_in)
      int_flit_dw_cnt_r <= #TP int_flit_dw_cnt_r + 1'b1;
  end
end : flit_frame_PROC

// NOP Counter
always_ff @(posedge core_clk or negedge core_rst_n) begin : nop_cnt_PROC
  if(!core_rst_n)
    int_nop_dw_cnt_r <= #TP P_DW_CNT_RST;
  else begin
    if(!int_flit_gen_en_r)
      int_nop_dw_cnt_r <= #TP P_DW_CNT_RST;
    else begin
      if(int_flit_dv_r && !halt_in) begin
        if(int_data_valid_r || int_fm_eof_s[1])
          int_nop_dw_cnt_r  <= #TP P_DW_CNT_RST;
        else
          int_nop_dw_cnt_r  <= #TP int_nop_dw_cnt_r + 1'b1;
      end
    end
  end
end : nop_cnt_PROC

// If accumulated DW exceeds the data path width the input will be halted and int_next_accum_dw_s is set to 0 so this counter cannot overflow.
always_ff @(posedge core_clk or negedge core_rst_n) begin : accum_dw_PROC
  if(!core_rst_n)
    int_accum_dw_r  <= #TP '0;
  else begin
    if(!int_flit_gen_en_r)
      int_accum_dw_r  <= #TP '0;
    else begin
      if(!halt_in) begin
        // Shift out P_NW but dont accept new data
        if(xtlh_fm_shift_halt && !int_merge_tlp_halt) begin
            int_accum_dw_r  <= #TP (int_accum_dw_r < P_NW) ? '0 : int_accum_dw_r - P_NW;
        end
        // Accumulate new data
        else
          int_accum_dw_r  <= #TP int_next_accum_dw_s;
      end
    end
  end
end : accum_dw_PROC

assign int_fm_sof_s = int_flit_gen_en_r && int_flit_dv_r && (int_flit_dw_cnt_r == P_DW_CNT_RST);
assign int_fm_enf_s = !((|int_fm_data_s) || (|int_fm_sot_s) || (|xtlh_fm_shift_eot)) && (int_nop_dw_cnt_r == P_DW_CNT_MAX);

assign int_fm_eof_s = (int_flit_gen_en_r && int_flit_dv_r && (int_flit_dw_cnt_r == P_DW_CNT_MAX)) ? 2'b11 : 2'b00;

// Halt when too much data is accumulated or when valid data is presented before nop transmission completes or when back-pressure comes from Layer2
assign xtlh_fm_shift_halt = (int_accum_dw_r > P_NW) || (dv && !int_flit_gen_en_r) || halt_in || int_max_tlp_halt_r || int_merge_tlp_halt;

logic int_en_overflow_calc;

assign int_en_overflow_calc = (int_flit_gen_en_r && (!xtlh_fm_shift_halt || (xtlh_fm_shift_halt && int_merge_tlp_halt)) && !halt_in && !int_preload);

// Calculate the overflow of data to the next cycle
always_comb begin
  int_next_accum_dw_s = '0;
  // If more than P_NW DW accumulated we halt and shift the upper half of the shift register so clear the accumulation
  if(int_flit_gen_en_r && (xtlh_fm_shift_halt && !int_merge_tlp_halt) && !halt_in) begin
    if(int_accum_dw_r > P_NW)
      int_next_accum_dw_s = int_accum_dw_r - P_NW;
    else
      int_next_accum_dw_s = '0;
  end
  // Calculate the overflow based on the packed data
  else if(int_en_overflow_calc)
    int_next_accum_dw_s = calculate_overflow(dv, int_accum_dw_r, int_flit_dw_cnt_r, int_shift_reg_s.sot, int_shift_reg_s.eot);
  else
    int_next_accum_dw_s = '0;
end

// Shift register accumulate data and shift
always_comb begin : shift_reg_PROC
  int_shift_reg_s = int_shift_reg_r;
  int_flit_dv_s = int_flit_dv_r;
  int_shift_reg_s.ras_dp_err_inband_kbd = ras_dp_err_inband_kbd;
  // Enable Flit Generation
  if(int_flit_gen_en_r) begin
    // Shift out only
    if(xtlh_fm_shift_halt && !halt_in) begin
      int_flit_dv_s = '1;
      int_shift_reg_s = shift_data_only(int_shift_reg_r, int_flit_dw_cnt_r);
    // Load data into the shift register
    end else if(!xtlh_fm_shift_halt && !halt_in) begin
      int_flit_dv_s = '1;
      case(int_accum_dw_r[P_ACCUM_DW_WD - 2:0])
      5'd0 : begin
        // Insert Data
        int_shift_reg_s = load_data(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd1 : begin
        // Insert Data
        int_shift_reg_s = load_accum_1dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd2 : begin
        // Insert Data
        int_shift_reg_s = load_accum_2dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd3 : begin
        // Insert Data
        int_shift_reg_s = load_accum_3dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd4 : begin
        // Insert Data
        int_shift_reg_s = load_accum_4dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd5 : begin
        // Insert Data
        int_shift_reg_s = load_accum_5dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd6 : begin
        // Insert Data
        int_shift_reg_s = load_accum_6dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd7 : begin
        // Insert Data
        int_shift_reg_s = load_accum_7dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd8 : begin
        // Insert Data
        int_shift_reg_s = load_accum_8dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd9 : begin
        // Insert Data
        int_shift_reg_s = load_accum_9dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd10 : begin
        // Insert Data
        int_shift_reg_s = load_accum_10dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd11 : begin
        // Insert Data
        int_shift_reg_s = load_accum_11dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd12 : begin
        // Insert Data
        int_shift_reg_s = load_accum_12dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd13 : begin
        // Insert Data
        int_shift_reg_s = load_accum_13dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd14 : begin
        // Insert Data
        int_shift_reg_s = load_accum_14dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd15 : begin
        // Insert Data
        int_shift_reg_s = load_accum_15dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      5'd16 : begin
        // Insert Data
        int_shift_reg_s = load_accum_16dw(int_shift_reg_r, dv, data, sot, eot, flit_marker, int_flit_dw_cnt_r);
      end
      default : begin
        int_shift_reg_s = int_shift_reg_r;
        int_flit_dv_s = int_flit_dv_r;
      end
      endcase
    end else begin
      int_shift_reg_s = int_shift_reg_r;
      int_flit_dv_s = int_flit_dv_r;
    end
  end else begin
    int_shift_reg_s = '0;
    int_flit_dv_s = '0;
  end
end : shift_reg_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    int_flit_dv_r       <= #TP '0;
    int_data_valid_r    <= #TP '0;
    int_tlp_dv_r        <= #TP '0;
  end else begin
    if(xdlh_xtlh_cmd.tx_cmd == CMD_RESET) begin
      int_flit_dv_r     <= #TP '0;
      int_data_valid_r  <= #TP '0;
      int_tlp_dv_r      <= #TP '0;
    // Load new data into the shift register
    end else if(!halt_in) begin
      int_data_valid_r  <= #TP int_data_valid_s;
      int_flit_dv_r     <= #TP int_flit_dv_s;
      int_tlp_dv_r      <= #TP |int_shift_reg_s.data_valid[P_NW-1:0];
    end
  end  
end

// Enable the pipeline stage either to capture TLP data or to capture a Flit Marker
assign int_data_valid_s = |int_shift_reg_s.data_valid || int_end_flit_marker_s || (state_r inside {PTM, POISONED, NULLIFIED, PTM_POISONED, PTM_NULLIFIED});

localparam P_FM_VALID_NW = P_NW - 5;

// Flit Marker in Last Flit Cycle can be sent if it occurs before the overhead FEC+CRC+DLP
always_comb begin : fm_end_PROC
  int_end_flit_marker_s = '0;
  for(int i = 0; i < P_FM_VALID_NW; i = i + 1) begin
    if((int_flit_dw_cnt_r == P_DW_LAST - 1) && (int_flit_dv_r && !int_end_flit_marker_s && int_shift_reg_s.flit_marker[i].flit_marker_indication))
      int_end_flit_marker_s = 1'b1;
  end
end : fm_end_PROC

// Flit Marker occured in any of the P_NW being shifted out next
always_comb begin
  int_any_flit_marker_s = '0;
  int_latch_flit_marker_s = '0;
  for(int i = 0; i < P_NW; i = i + 1) begin
    if(!int_any_flit_marker_s && int_shift_reg_s.flit_marker[i].flit_marker_indication) begin
      int_latch_flit_marker_s = int_shift_reg_s.flit_marker[i];
      int_any_flit_marker_s = 1'b1;
    end
  end
end

// Insert the Flit Marker into the data path on the EOF
always_comb begin : flit_marker_PROC
  int_next_data_s = int_shift_reg_s;
  if(int_end_flit_marker_s) begin
    // Set the Type of DLP Payload
    int_next_data_s.data[P_FM_DW_POS][P_TYPE_OF_DLP_BIT] = 1'b1;
    // Flit Marker Indication
    int_next_data_s.data[P_FM_DW_POS][P_DLP2_END_BIT] = 1'b1;
    // Flit Status
    int_next_data_s.data[P_FM_DW_POS][P_FLIT_STATUS_END : P_FLIT_STATUS_END - 1] = int_latch_flit_marker_s.flit_status;
    // PTM
    int_next_data_s.data[P_FM_DW_POS][P_MARKER_PTM] = (state_r == PTM) ? int_flit_marker.ptm_in_flit :  int_latch_flit_marker_s.ptm_in_flit;
  end else if(int_insert_fm && state_r inside {PTM, POISONED, NULLIFIED, PTM_POISONED, PTM_NULLIFIED}) begin
      // Set the Type of DLP Payload
      int_next_data_s.data[P_FM_DW_POS][P_TYPE_OF_DLP_BIT] = 1'b1;
      // Flit Marker Indication
      int_next_data_s.data[P_FM_DW_POS][P_DLP2_END_BIT] = 1'b1;
      // Flit Status
      int_next_data_s.data[P_FM_DW_POS][P_FLIT_STATUS_END : P_FLIT_STATUS_END - 1] = int_flit_marker.flit_status;
      // PTM
      int_next_data_s.data[P_FM_DW_POS][P_MARKER_PTM] = int_flit_marker.ptm_in_flit;
  end
end : flit_marker_PROC

// RASDP generator insertion in output of fm_shift_ms
xtlh_shift_pipe_ms
 #(
  .N                  (1),
  .PIPE               (1),               // Number of stages of the delay module
  .CAN_STALL          (0)
    ,
    .BUS_PROTECT_CHK_EN (0),
    .BUS_PROTECT_GEN_EN (1),
    .RAS_DP_PROT_CHK_ID_BASE ('0)
  ) u_xtlh_shift_pipe_gen_ms (
  .clk                       (core_clk),
  .rst_n                     (core_rst_n),
  .en                        (!halt_in && int_data_valid_s),
  .in_pkt                    (int_next_data_s),
  .out_halt                  (),
  .out_pkt                   (int_shift_pipe_s),
  .in_halt                   (1'b0)
    ,.ras_dp_err_log         ()
      ,.ras_dp_err_inj       ('0)
);

// dummy instance of ras_dp_pipe just to generate flit protection signal depending on RAS DP configuration
logic [DATA_PAR_WD-1:0] flit_prot; 
ras_dp_pipe
 #(
  .PIPELINE_TYPE           (6                  ), 
  .N_STAGES                (0                  ), 
  .CAN_STALL               (0                  ), 
  .BUS_PROTECT_GEN_EN      (1                  ), 
  .BUS_PROTECT_CHK_EN      (0                  ), 
  .PROT_TYPE               (`CX_RAS_PROT_TYPE  ), 
  .PROT_RANGE              (`CX_RAS_PROT_RANGE ), 
  .PROT_WD                 (DATA_PAR_WD        ), 
  .PARITY_MODE             (`CX_RAS_PARITY_MODE), 
  .TOTAL_WIDTH             (P_DW               ),
  .EXCLUDE_PROT_WIDTH      (0                  )
) u_calc_zero_flit_prot (
  .clk                      ('0       ),
  .rst_n                    ('0       ),
  .en                       ('0       ),
  .din                      ('0       ),
  .din_prot                 ('0       ),
  .dout                     (         ),
  .dout_prot                (flit_prot),
  .bypass                   ('0       ),
  .stall                    ('0       ),
  .stallout                 (         ),
  .valid_in                 ('0       ),
  .halt_in                  ('0       ),
  .valid_out                (         ),
  .halt_out                 (         ),
  .ras_dp_err_inband_kbd_in ('0       ),
  .ras_dp_err_inband_kbd_out(         ),
  .ras_dp_err_log           (         ),
  .ras_dp_err_inj           ('0       )
);

// FM Shift TLP Pending
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    xtlh_fm_shift_tlp_pending <= #TP '0;
  else begin
    if(!halt_in && xtlh_fm_shift_tlp_pending && xtlh_fm_shift_flit.eof[1] && !int_data_valid_s)
      xtlh_fm_shift_tlp_pending <= #TP '0;
    else if(int_data_valid_s)
      xtlh_fm_shift_tlp_pending <= #TP '1;
  end
end

// If pipe line is disabled 0 the data
always_comb begin : data_valid_mux_PROC
  int_shift_reg_r = int_shift_pipe_s;
  if(!int_data_valid_r) begin
    int_shift_reg_r = '0;
    int_shift_reg_r.flit_prot = flit_prot;
  end
end : data_valid_mux_PROC

// Flit Interface Signals
assign int_fm_data_s = int_shift_reg_r.data[P_NW - 1 : 0];
assign xtlh_fm_shift_eot = int_shift_reg_r.eot[P_NW - 1 : 0];
assign int_fm_sot_s = int_shift_reg_r.sot[P_NW - 1 : 0];

// Flit Output EOT Counter
always_comb begin : eot_cnt_PROC
  for(int i = 0; i < P_NW; i = i + 1)
    int_eot_cnt[i] = '0;
  for(int i = 0; i < P_NW; i = i + 1) begin
    if(i == 0)
      int_eot_cnt[i] = (!halt_in && xtlh_fm_shift_eot[0]) ? P_ONE : P_ZERO;
    else
      int_eot_cnt[i] = (!halt_in && xtlh_fm_shift_eot[i]) ? int_eot_cnt[i-1] + P_ONE : int_eot_cnt[i-1];
  end
end : eot_cnt_PROC

assign int_sample_eot_cnt = int_flit_dv_s && ((int_flit_dw_cnt_r == P_DW_HALF) || (int_flit_dw_cnt_r == P_DW_CNT_MAX)) && !halt_in;

// The transmitted will be halted when 8 SOT's have been accepted and it will remain halted until the EOT counter reaches 8 to clear the TLP counter. 
// spyglass disable_block W164a W164b
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
always_ff @(posedge core_clk or negedge core_rst_n) begin : sample_eot_cnt_PROC
  if(!core_rst_n) begin
    int_fm_shift_eot_cnt_r  <= #TP '0;
    int_tot_eot_cnt_r       <= #TP '0;
  end else begin
    if(int_sample_eot_cnt) begin
      int_tot_eot_cnt_r       <= #TP '0;
      int_fm_shift_eot_cnt_r  <= #TP int_tot_eot_cnt_r + int_eot_cnt[P_NW-1];
    end else begin
      int_tot_eot_cnt_r       <= #TP int_tot_eot_cnt_r + int_eot_cnt[P_NW-1];
      int_fm_shift_eot_cnt_r  <= #TP '0;
    end
  end
end : sample_eot_cnt_PROC
// spyglass enable_block W164a W164b

assign xtlh_fm_shift_eot_cnt = int_fm_shift_eot_cnt_r;

always_comb begin : flit_if_PROC
  if(!flit_mode_en) begin
    xtlh_fm_shift_flit            = '0;
  end else begin
    xtlh_fm_shift_flit.tlp_dv     = int_tlp_dv_r;
    xtlh_fm_shift_flit.sof        = int_fm_sof_s;
    xtlh_fm_shift_flit.eof        = int_fm_eof_s;
    xtlh_fm_shift_flit.enf        = int_fm_enf_s;
    xtlh_fm_shift_flit.data       = int_fm_data_s;
    xtlh_fm_shift_flit.data_valid = int_flit_dv_r && int_flit_gen_en_r;
    xtlh_fm_shift_flit.retry_flit = '0;
    xtlh_fm_shift_flit.expl_flit  = '0;
     xtlh_fm_shift_flit.flit_type_s  = flit_type;
     xtlh_fm_shift_flit.ras_dp_err_inband_kbd = int_shift_reg_r.ras_dp_err_inband_kbd;
     xtlh_fm_shift_flit.flit_prot = int_shift_reg_r.flit_prot;
  end
end : flit_if_PROC

// Detect Flit Marker Indication
always_ff @(posedge core_clk or negedge core_rst_n) begin : fm_sent_PROC
  if(!core_rst_n)
    xtlh_fm_shift_marker_sent <= #TP '0;
  else begin
    if(!halt_in && xtlh_fm_shift_flit.eof[0] && (int_flit_marker_r.flit_status == E_NULLIFIED || int_flit_marker_r.flit_status == E_POISON || int_latch_flit_marker_r.flit_status == E_NULLIFIED || int_latch_flit_marker_r.flit_status == E_POISON))
      xtlh_fm_shift_marker_sent <= #TP xtlh_fm_shift_flit.data[P_DLP2_END] && xtlh_fm_shift_flit.data[P_TYPE_OF_DLP];
    else
      xtlh_fm_shift_marker_sent <= #TP '0;
  end
end : fm_sent_PROC

// Calculate the number of TLP's that will overflow into the next cycle
always_comb begin : overflow_cnt_PROC
  int_shift_over_cnt_s = '0;
  int_first_sot_over_s = find_first_over(int_shift_reg_r.sot[P_SHIFT_NW - 1 : P_NW]);
  int_first_eot_over_s = find_first_over(int_shift_reg_r.eot[P_SHIFT_NW - 1 : P_NW]);
  int_sot_over_cnt_s = count_sots(int_shift_reg_r.sot[P_SHIFT_NW - 1 : P_NW]);
  if(((int_flit_dw_cnt_r == P_DW_HALF) || (int_flit_dw_cnt_r == P_DW_CNT_MAX)) && !halt_in) begin
    // SOT in overflow comes before eot
    if((int_first_sot_over_s < int_first_eot_over_s) && (int_first_sot_over_s > 0))
      int_shift_over_cnt_s = int_sot_over_cnt_s;
    // SOT without EOT
    else if((int_first_sot_over_s > 0) && (int_first_eot_over_s == 0))
      int_shift_over_cnt_s = int_sot_over_cnt_s;
    // EOT in overflow comes before sot
    else if((int_first_eot_over_s < int_first_sot_over_s) && (int_first_eot_over_s > 0))
      int_shift_over_cnt_s = 'b1 +  int_sot_over_cnt_s;
    // EOT without SOT
    else if((int_first_eot_over_s > 0) && (int_first_sot_over_s == 0))
      int_shift_over_cnt_s = 'b1;
    // Nothing in overflow portion of shift check if TLP ongoing in this cycle
    else begin
      if(|int_shift_reg_r.data_valid)
        int_shift_over_cnt_s = 1;
      else
        int_shift_over_cnt_s = 0;
    end
  end
end : overflow_cnt_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : overflow_sync_PROC
  if(!core_rst_n)
    xtlh_fm_shift_over_cnt  <= #TP '0;
  else begin
    if(((int_flit_dw_cnt_r == P_DW_HALF) || (int_flit_dw_cnt_r == P_DW_CNT_MAX)) && !halt_in)
      xtlh_fm_shift_over_cnt  <= #TP int_shift_over_cnt_s;
  end
end : overflow_sync_PROC


endmodule
