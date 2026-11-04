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
// ---    $DateTime: 2023/11/15 02:23:44 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_cpl_lut_timer.sv#4 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
//  1. provide cpl LUT to mananage received cpl, storing with tag.
//  2. provide cpl timeout mechansim.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_cpl_lut_timer
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::TAG_SIZE;
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NVF;
  import DWC_pcie_ctl_pkg::PF_WD;
  import DWC_pcie_ctl_pkg::VFI_WD;
  import DWC_pcie_ctl_pkg::VF_WD;
  import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD;
  import radm_ms_pkg::CPL_LUT_DEPTH_INTERNAL;
  import radm_ms_pkg::CPL_LUT_PTR_WD;
  import radm_ms_pkg::INT_NVF;
  import radm_ms_pkg::FUNC_NUM_INDEX;
  import radm_ms_pkg::BYTECNT_INDEX;
  import radm_ms_pkg::TC_INDEX;
  import radm_ms_pkg::ATTR_INDEX;
  import radm_ms_pkg::CPL_TRGT_INDEX;
  import radm_ms_pkg::NP_REQ_TYPE_INDEX;
  import radm_ms_pkg::E_14BIT_TAG_INDEX;   
  import radm_ms_pkg::E_10BIT_TAG_INDEX;  
  import radm_ms_pkg::CPL_ENTRY_WIDTH;  
 // ## CPL_LUT2 ##
  import radm_ms_pkg::LOW_ADDR_WD2; 
  import radm_ms_pkg::BYTECNT_WD2;      
  import radm_ms_pkg::BYTECNT_INDEX2;   
  import radm_ms_pkg::CPL_ENTRY_WIDTH2;        
  import radm_ms_pkg::TIMEOUT_GRANULARITY;
 // Completion timer value scaled down by dividing the granularity. Min > CPL_LUT_PTR_WD
  import radm_ms_pkg:: CPL_TIMEOUT_VALUE_INT  ; 
  import radm_ms_pkg:: CPL_TIMEOUT_VALUE1     ; 
  import radm_ms_pkg:: CPL_TIMEOUT_VALUE2     ; 
  import radm_ms_pkg:: CPL_TIMEOUT_VALUE3     ; 
  import radm_ms_pkg:: CPL_TIMEOUT_VALUE4     ; 
  import radm_ms_pkg:: CPL_TIMEOUT_VALUE5     ; 
  import radm_ms_pkg:: CPL_TIMEOUT_VALUE6     ; 
  import radm_ms_pkg:: CPL_TIMEOUT_VALUE7     ; 
  import radm_ms_pkg:: CPL_TIMER_TW           ; 
  import radm_ms_pkg:: CPL_BASE_TIMER_VALUE_US; 
  import radm_ms_pkg::N_RADM_CPL_TLP;
  import radm_ms_pkg::N_XADM_RADM_TX_NPR_IF;

                           (
// ---- inputs ---------------
  input                                             core_clk,                   // core clock input
  input                                             radm_clk_ug,                // ungated radm clock
  input                                             core_rst_n,
  input   [(4*NF)-1:0]                              cfg_cpl_timeout_range,      // "static" // Completion timeout ranges
  input   [NF-1:0]                                  cfg_cpl_timeout_disable,    // "static" // Completion timeout disable
  input                                             xtlh_np_tlp_early,          // an early indication from layer3 that a NP TLP has been sent
  input   [2:0]                                     current_data_rate,          // "static" // 0=running at gen1 rate, 1=running at gen2 rate, 2-gen3, 3-gen4
  input   [N_XADM_RADM_TX_NPR_IF-1:0]               int_update_lut_d,           // radm_cpl_pending logic
  input   [N_XADM_RADM_TX_NPR_IF-1:0][FUNC_NUM_INDEX-1:0] lutin_func_num_d,     // radm_cpl_pending logic(at timer)
  input                                             or_valid,                   // radm_cpl_pending logic, = |radm_cpl_lut_valid_int

  output  [NF-1:0]                                  radm_cpl_pending,
  output                                            radm_cpl_lut_busy,          // CPL LUT busy indication
  output  logic                                     radm_cpl_timeout,
  output  logic                                     radm_cpl_timeout_cdm,       // Same information as radm_cpl_timeout but without the timeout tags flr'ed
  output  logic [2:0]                               radm_timeout_cpl_tc,        // not used
  output  logic [2:0]                               radm_timeout_cpl_attr,      // not used
  output  logic [TAG_SIZE-1:0]                      radm_timeout_cpl_tag,
  output  logic [PF_WD-1:0]                         radm_timeout_func_num,
  output  logic [11:0]                              radm_timeout_cpl_len,
  output  logic [6:0]                               radm_timeout_low_addr,
  output  logic [NP_REQ_TX_TYPE_WD-1:0]             radm_timeout_np_req_type,
  output  logic                                     radm_cpl_lut_pending,       // pending flag for the radm cpl lut
  input                                             cpl_lut_empty, 
  input  [N_RADM_CPL_TLP*CPL_LUT_PTR_WD-1:0]        update_lut_addr_pipe,
  input  [N_RADM_CPL_TLP-1:0]                       update_lut_content_pipe,
  input  [N_RADM_CPL_TLP-1:0]                       cpl_last_pipe,
  input  [CPL_ENTRY_WIDTH-1:0]                      cpl_lut_error_vec,
  input  [CPL_ENTRY_WIDTH2-1:0]                     cpl_lut_error_vec2,
  input                                             cpl_lut_error_valid, 
  input  [TIMEOUT_GRANULARITY-1:0]                  cpl_lut_pertag_timer_value,  
  output                                            timer_freq,
  output   [PF_WD-1:0]                              timeout_pf,
  output   [NF-1:0]                                 func_timeout,
  output                                            timer_expired_incr,
  output                                            timeout_error,
  output logic   [CPL_LUT_PTR_WD-1:0]               timeout_addr,
  output         [CPL_LUT_PTR_WD-1:0]               timeout_addr_reg
);

localparam TIMEOUT_FETCH_PIPELINE = `CX_RADM_LUT_TO_FETCH_PIPE;
localparam NVF_EXT   = (1 << VFI_WD);
////////////////////////////////////////////////
// Local wires and registers
//
////////////////////////////////////////////////
logic   [FUNC_NUM_INDEX-1:0]                        timeout_func_num;
logic   [NF-1:0]                                    cpl_pending_pf;
logic   [NF-1:0]                                    cpl_pending_pf_reg;
logic   [NF-1:0]                                    cpl_pending_pf_latch;
//If the completion is not the last one, then it should be dw aligned.
//Otherwise, it contains the bytes that is left in byte cnt.
logic   [CPL_TIMER_TW-1:0]                          timer;
logic                                               timeout_error_wo_flr;             // Containts tag timeout information because timer timeout and no because FLR.
logic                                               timer_expired;
logic                                               flr_pf_reset;
logic  [31:0]                                       wCPL_TIMEOUT_VALUE;
logic  [31:0]                                       wCPL_TIMEOUT_VALUE_INT;
logic  [31:0]                                       wCM_CPL_BASE_TIMER_VALUE_RATEA;
logic  [31:0]                                       wCM_CPL_BASE_TIMER_VALUE_RATEB;
logic                                               timeout_valid_reg;
logic                                               timeout_mask_valid;
logic                                               timeout_going_to_clear_valid;
// Pipeline
logic   [CPL_ENTRY_WIDTH-1:0]                       timeout_vec_reg;
logic   [CPL_ENTRY_WIDTH2-1:0]                      timeout_vec2_reg;
logic  [TIMEOUT_GRANULARITY-1:0]                  cpl_lut_pertag_timer_value_int; 

// Needed for cpl_pending* logic
logic    [N_XADM_RADM_TX_NPR_IF-1:0][PF_WD-1:0]     lutin_pf_d;
logic    [NF-1:0]                                   skip_this_cycle_pf;

// ----------------------------------------------------------
// Completion Timeout Control Logic
// ----------------------------------------------------------
assign wCM_CPL_BASE_TIMER_VALUE_RATEA = `CM_CPL_BASE_TIMER_VALUE_RATEA;
assign wCM_CPL_BASE_TIMER_VALUE_RATEB = `CM_CPL_BASE_TIMER_VALUE_RATEB;

assign wCPL_TIMEOUT_VALUE_INT = CPL_TIMEOUT_VALUE_INT;
assign wCPL_TIMEOUT_VALUE     = wCPL_TIMEOUT_VALUE_INT;

always_comb begin
    timeout_going_to_clear_valid = 0;
    for(int i=0;i<N_RADM_CPL_TLP;i=i+1) begin
        if(update_lut_addr_pipe[i*CPL_LUT_PTR_WD +: CPL_LUT_PTR_WD] == timeout_addr_reg && update_lut_content_pipe[i] && cpl_last_pipe[i])begin
            timeout_going_to_clear_valid = 1;
        end
    end
    if (timeout_error
        ) begin
        timeout_going_to_clear_valid = 1;
    end
end // always_comb

always @(posedge core_clk or negedge core_rst_n)begin
    if(!core_rst_n)begin
        timeout_mask_valid <= #TP 0;
    end else begin
        if(TIMEOUT_FETCH_PIPELINE)begin
            timeout_mask_valid <= #TP (timeout_addr == timeout_addr_reg && timeout_going_to_clear_valid ) ? 1 : 0;
        end else begin
            timeout_mask_valid <= #TP 0;
        end
    end
end
// use the lower bits of the base timer to loop through the cpl lut table
logic [CPL_LUT_PTR_WD:0] timeout_addr_mapped;
logic timeout_addr_exceed_lut;
assign timeout_addr_mapped = (timer[CPL_LUT_PTR_WD-1:0] <= (CPL_LUT_DEPTH_INTERNAL-1)) ? {1'b0, timer[CPL_LUT_PTR_WD-1:0]} : CPL_LUT_DEPTH_INTERNAL-1; 
assign timeout_addr        = timeout_addr_mapped[CPL_LUT_PTR_WD-1:0];
assign timeout_addr_exceed_lut = (timer[CPL_LUT_PTR_WD-1:0] > (CPL_LUT_DEPTH_INTERNAL-1));

assign timeout_vec_reg = timeout_addr_exceed_lut ? {CPL_ENTRY_WIDTH{1'b0}} : cpl_lut_error_vec; 
assign timeout_vec2_reg     = timeout_addr_exceed_lut ? {CPL_ENTRY_WIDTH2{1'b0}} : cpl_lut_error_vec2; 
assign timeout_valid_reg    = timeout_addr_exceed_lut ? 1'b0 : cpl_lut_error_valid;    // used as pre-condition for flr_reset
assign cpl_lut_pertag_timer_value_int = timeout_addr_exceed_lut ? {TIMEOUT_GRANULARITY{1'b0}} : cpl_lut_pertag_timer_value;

delay_n

#(TIMEOUT_FETCH_PIPELINE, CPL_LUT_PTR_WD) u_timeout_fetch_pipe(
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (timeout_addr),
    .dout       (timeout_addr_reg)
);

assign timeout_func_num = timeout_vec_reg[FUNC_NUM_INDEX -1 : 0];
logic  timeout_10_or_14_bit_tag;
assign timeout_10_or_14_bit_tag= timeout_vec_reg[E_10BIT_TAG_INDEX -1 : NP_REQ_TYPE_INDEX];

assign  timeout_pf = timeout_func_num;

localparam PF_IDX_WD = (NF == 1) ? 1 : $clog2(NF);
wire[PF_IDX_WD-1:0] timeout_pf_idx = timeout_pf[PF_IDX_WD-1:0];

// ### For timeout_err information is reading the actual version of valid[] to avoid that timeout_error lasts ###
// ### more than 1 cycle if the the timeout_addr increment 1 per 8 cycles...                                  ###
assign  timeout_error           =  (timeout_valid_reg
                                && !timeout_mask_valid                                     // Valid masking as it is going to clean 
                                && (&cpl_lut_pertag_timer_value_int/*pertag_timer[timeout_addr_reg]*/)                       // timeout tag information because timer timeout(No FLR ENABLE)
                                && (~cfg_cpl_timeout_disable[timeout_pf_idx]                   // not disabled
                                   ) )
                                ;

assign  timeout_error_wo_flr    =  (timeout_valid_reg
                                && !timeout_mask_valid
                                && (&cpl_lut_pertag_timer_value_int/*pertag_timer[timeout_addr_reg]*/)                       // tag timeout
                                && (~cfg_cpl_timeout_disable[timeout_pf_idx] ) )               // not disabled
                                ;

// for IOV, the timer is implemented as multiple timers, one for each range.
// for 1s product at 250Mhz, base timer times out at 32us based on current defines in adm_defs.vh
logic   [CPL_TIMER_TW-1:0]      cpl_timeout_value_wire;

DWC_pcie_tim_gen
 #(
    .CLEAR_CNTR_TO_1(0)
) u_gen_timer_freq
(
     .clk               (core_clk)
    ,.rst_n             (core_rst_n)

    ,.current_data_rate (current_data_rate)
    ,.clr_cntr          (1'b0)        // clear cycle counter(not used in this timer)
    
    ,.cnt_up_en         (timer_freq)  // timer count-up
);

assign  cpl_timeout_value_wire = wCPL_TIMEOUT_VALUE -1;
assign  timer_expired           =
                                  (timer >= cpl_timeout_value_wire) & timer_freq;


// free running timer counts ticks of timer freq
// when a np tlp is sent by the XTLH clear the counter
// when the counter rolls over the signal to clear the cpl
// lut busy is toggled
logic [1:0] free_timer_r;
logic     int_cpl_lut_pending_r;

// needs to be clocked on ungated radm clock to ungate the clock when np request is received
always @(posedge radm_clk_ug or negedge core_rst_n) begin : free_timer_PROC
  if (!core_rst_n) begin
    free_timer_r <= #TP 2'b00;
    int_cpl_lut_pending_r <= #TP 1'b0;
  end else begin
    int_cpl_lut_pending_r <= #TP radm_cpl_lut_pending;
    if(xtlh_np_tlp_early)
      free_timer_r <= #TP 2'b00;
    else if(timer_freq)
      free_timer_r <= #TP (free_timer_r + 1'b1);
    else
      free_timer_r <= #TP free_timer_r;
  end
end : free_timer_PROC

logic      int_clear_lut_pending;
assign int_clear_lut_pending = (free_timer_r == 2'b11);

// Generate a cpl lut pending indication
// this will be set when a np tlp is sent from layer3
// it remains set until the free running timer saturates
// this insures that a flag is asserted to indication cpl lut
// busy until the cpl lut pending flags would be updated
always_comb begin : cpl_lut_pending_PROC
  if(xtlh_np_tlp_early)
    radm_cpl_lut_pending = 1'b1;
  else if(int_clear_lut_pending)
    radm_cpl_lut_pending = 1'b0;
  else
    radm_cpl_lut_pending = int_cpl_lut_pending_r;
end : cpl_lut_pending_PROC

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        timer     <= #TP 0;
    end else if (((cpl_lut_empty)
                 ) || timer_expired) begin
        timer     <= #TP 0;
    end else begin
        timer     <= #TP timer + (timer_freq ? 1'b1 : 1'b0);
    end
end

//logic  timer_expired_incr;
logic  timer_expired_window;
// make sure that each cycle of the timer is a full two clocks
assign timer_expired_incr = timer_expired_window & timer_freq;

// use the timer to create a window as wide as the number of entries in the table
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        timer_expired_window     <= #TP 0;
    end else if (timer_expired) begin
        timer_expired_window     <= #TP 1;
    end else if ((&timer[CPL_LUT_PTR_WD-1:0]) & timer_expired_incr) begin
        timer_expired_window     <= #TP 0;
    end
end

// additional timers are used to time the different ranges allowed by the spec
// "timer0" is orignal timer
//
//timer bits value (ns)    min timeout   max timeout  range min    range max
//0     13    32.764E-06    65.528E-06    98.292E-06   50.000E-06  100.000E-06
//1     6      2.064E-03     4.128E-03     6.192E-03    1.000E-03   10.000E-03
//2     3     14.449E-03    28.898E-03    43.347E-03   16.000E-03   55.000E-03
//3     2     43.347E-03    86.694E-03   130.040E-03   65.000E-03  210.000E-03
//4     2    130.040E-03   260.081E-03   390.121E-03  260.000E-03  900.000E-03
//5     3    910.282E-03     1.821E+00     2.731E+00    1.000E+00    3.500E+00
//6     2      2.731E+00     5.462E+00     8.193E+00    4.000E+00   13.000E+00
//7     3     19.116E+00    38.232E+00    57.348E+00   17.000E+00   64.000E+00
logic [6-1:0] timer1;
logic [3-1:0] timer2;
logic [2-1:0] timer3;
logic [2-1:0] timer4;
logic [3-1:0] timer5;
logic [2-1:0] timer6;
logic [3-1:0] timer7;
logic [6-1:0] timer1_timeout_value;
logic [3-1:0] timer2_timeout_value;
logic [2-1:0] timer3_timeout_value;
logic [2-1:0] timer4_timeout_value;
logic [3-1:0] timer5_timeout_value;
logic [2-1:0] timer6_timeout_value;
logic [3-1:0] timer7_timeout_value;
logic [CPL_LUT_PTR_WD-1:0] timer_expired_window1;
logic [CPL_LUT_PTR_WD-1:0] timer_expired_window2;
logic [CPL_LUT_PTR_WD-1:0] timer_expired_window3;
logic [CPL_LUT_PTR_WD-1:0] timer_expired_window4;
logic [CPL_LUT_PTR_WD-1:0] timer_expired_window5;
logic [CPL_LUT_PTR_WD-1:0] timer_expired_window6;
logic [CPL_LUT_PTR_WD-1:0] timer_expired_window7;
logic         timer_expired1;
logic         timer_expired2;
logic         timer_expired3;
logic         timer_expired4;
logic         timer_expired5;
logic         timer_expired6;
logic         timer_expired7;
logic   [7:0] timer_expired_iov;

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        timer1    <= #TP 0;
        timer2    <= #TP 0;
        timer3    <= #TP 0;
        timer4    <= #TP 0;
        timer5    <= #TP 0;
        timer6    <= #TP 0;
        timer7    <= #TP 0;
    end else begin
        timer1    <= #TP (cpl_lut_empty  | timer_expired1) ? 0 : (timer_expired  ? (timer1 + 1'b1) : timer1);
        timer2    <= #TP (cpl_lut_empty  | timer_expired2) ? 0 : (timer_expired1 ? (timer2 + 1'b1) : timer2);
        timer3    <= #TP (cpl_lut_empty  | timer_expired3) ? 0 : (timer_expired2 ? (timer3 + 1'b1) : timer3);
        timer4    <= #TP (cpl_lut_empty  | timer_expired4) ? 0 : (timer_expired3 ? (timer4 + 1'b1) : timer4);
        timer5    <= #TP (cpl_lut_empty  | timer_expired5) ? 0 : (timer_expired4 ? (timer5 + 1'b1) : timer5);
        timer6    <= #TP (cpl_lut_empty  | timer_expired6) ? 0 : (timer_expired5 ? (timer6 + 1'b1) : timer6);
        timer7    <= #TP (cpl_lut_empty  | timer_expired7) ? 0 : (timer_expired6 ? (timer7 + 1'b1) : timer7);
    end
end

assign  timer1_timeout_value  = CPL_TIMEOUT_VALUE1 - 1;
assign  timer2_timeout_value  = CPL_TIMEOUT_VALUE2 - 1;
assign  timer3_timeout_value  = CPL_TIMEOUT_VALUE3 - 1;
assign  timer4_timeout_value  = CPL_TIMEOUT_VALUE4 - 1;
assign  timer5_timeout_value  = CPL_TIMEOUT_VALUE5 - 1;
assign  timer6_timeout_value  = CPL_TIMEOUT_VALUE6 - 1;
assign  timer7_timeout_value  = CPL_TIMEOUT_VALUE7 - 1;

assign  timer_expired1 = (timer1 == timer1_timeout_value) & timer_freq;
assign  timer_expired2 = (timer2 == timer2_timeout_value) & timer_freq;
assign  timer_expired3 = (timer3 == timer3_timeout_value) & timer_freq;
assign  timer_expired4 = (timer4 == timer4_timeout_value) & timer_freq;
assign  timer_expired5 = (timer5 == timer5_timeout_value) & timer_freq;
assign  timer_expired6 = (timer6 == timer6_timeout_value) & timer_freq;
assign  timer_expired7 = (timer7 == timer7_timeout_value) & timer_freq;

// use the timer to create a window as wide as the number of entries in the table
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        timer_expired_window1     <= #TP 0;
        timer_expired_window2     <= #TP 0;
        timer_expired_window3     <= #TP 0;
        timer_expired_window4     <= #TP 0;
        timer_expired_window5     <= #TP 0;
        timer_expired_window6     <= #TP 0;
        timer_expired_window7     <= #TP 0;
    end else begin
        timer_expired_window1     <= #TP (timer_expired1 || ((|timer_expired_window1) & timer_freq)) ? timer_expired_window1 + 1'b1 : timer_expired_window1;
        timer_expired_window2     <= #TP (timer_expired2 || ((|timer_expired_window2) & timer_freq)) ? timer_expired_window2 + 1'b1 : timer_expired_window2;
        timer_expired_window3     <= #TP (timer_expired3 || ((|timer_expired_window3) & timer_freq)) ? timer_expired_window3 + 1'b1 : timer_expired_window3;
        timer_expired_window4     <= #TP (timer_expired4 || ((|timer_expired_window4) & timer_freq)) ? timer_expired_window4 + 1'b1 : timer_expired_window4;
        timer_expired_window5     <= #TP (timer_expired5 || ((|timer_expired_window5) & timer_freq)) ? timer_expired_window5 + 1'b1 : timer_expired_window5;
        timer_expired_window6     <= #TP (timer_expired6 || ((|timer_expired_window6) & timer_freq)) ? timer_expired_window6 + 1'b1 : timer_expired_window6;
        timer_expired_window7     <= #TP (timer_expired7 || ((|timer_expired_window7) & timer_freq)) ? timer_expired_window7 + 1'b1 : timer_expired_window7;
    end
end

// which timers expired
//assign  timer_expired_iov[0] = timer_expired_incr;
assign  timer_expired_iov[0] = timer_expired_window;
assign  timer_expired_iov[1] = (timer_expired1 | (|timer_expired_window1));
assign  timer_expired_iov[2] = (timer_expired2 | (|timer_expired_window2));
assign  timer_expired_iov[3] = (timer_expired3 | (|timer_expired_window3));
assign  timer_expired_iov[4] = (timer_expired4 | (|timer_expired_window4));
assign  timer_expired_iov[5] = (timer_expired5 | (|timer_expired_window5));
assign  timer_expired_iov[6] = (timer_expired6 | (|timer_expired_window6));
assign  timer_expired_iov[7] = (timer_expired7 | (|timer_expired_window7));

// create a per-function mapping of timeout
// flr_pf_active=0 input is not needed because FLR disabled
assign  func_timeout = get_func_timeout(cfg_cpl_timeout_range,timer_expired_iov,0);

// Extracting lutin_func_num_d fields
always_comb begin
    for(int j=0;j<N_XADM_RADM_TX_NPR_IF ;j=j+1) begin
           lutin_pf_d[j]        = lutin_func_num_d[j][PF_WD-1:0];
    end
end

// valid_ind logic to avoid double timer_freq pulse at starting timer. 1st cpl inside LUT
logic  or_valid_reg; // OR[NFRAG*CPL_LUT_FRAG_DEPTH-1:0]
logic valid_ind;
always @(posedge core_clk or negedge core_rst_n)begin
    if(!core_rst_n)begin
        or_valid_reg <= #TP 1'b0;
    end else begin
        or_valid_reg <= #TP or_valid;
    end
end
assign valid_ind = TIMEOUT_FETCH_PIPELINE ? !(or_valid && !or_valid_reg) : 1'b1;

assign  cpl_pending_pf = check_radm_cpl_pending_pf(cpl_pending_pf_reg,timeout_addr_reg,timer_freq,(timeout_valid_reg && !timeout_mask_valid),timeout_vec_reg);
assign radm_cpl_lut_busy = (|cpl_pending_pf_reg) || (|cpl_pending_pf_latch);

// register the combinatorial cpl_pending flags and periodically latch the result to the CDM
always @(posedge core_clk or negedge core_rst_n)
begin : CPL_PENDING_PF_PROCESS
    if (!core_rst_n) begin
        cpl_pending_pf_reg <= #TP 0;
        cpl_pending_pf_latch <= #TP 0;
        skip_this_cycle_pf   <= #TP {NF{1'b0}};
    end else begin
        for (int i=0; i<NF; i=i+1) begin
           cpl_pending_pf_reg[i] <= #TP cpl_pending_pf[i];
           if ((timeout_addr==0) && valid_ind && timer_freq) begin
              skip_this_cycle_pf[i] <= #TP 1'b0; // To avoid set time of cpl_pending* < LUT round trip
              if(!skip_this_cycle_pf[i])
                 cpl_pending_pf_latch[i]  <= #TP cpl_pending_pf_reg[i];
           end
           // High priority for any set from xadm
           for(int xadm=0;xadm<N_XADM_RADM_TX_NPR_IF ;xadm=xadm+1) begin
              if (int_update_lut_d[xadm] && (lutin_pf_d[xadm] == i) ) begin
                 cpl_pending_pf_reg[i]   <= #TP 1'b1;
                 cpl_pending_pf_latch[i] <= #TP 1'b1;
                 skip_this_cycle_pf[i]   <= #TP 1'b1;
              end
           end // for xadm
        end // for ...
    end
end

assign radm_cpl_pending = cpl_pending_pf_latch;

always @(posedge core_clk or negedge core_rst_n)
begin: OUTPUT_CONTROL_DRIVE_PROCESS
    if (!core_rst_n) begin
        radm_cpl_timeout        <= #TP 0;
        radm_cpl_timeout_cdm    <= #TP 0;
        radm_timeout_func_num   <= #TP 0;
        radm_timeout_cpl_tag    <= #TP 0;
        radm_timeout_cpl_attr   <= #TP 0;
        radm_timeout_cpl_tc     <= #TP 0;
        radm_timeout_cpl_len    <= #TP 0;
        radm_timeout_low_addr    <= #TP 0; 
        radm_timeout_np_req_type <= #TP 0;

    end else begin
        radm_cpl_timeout        <= #TP timeout_error ; 
        radm_cpl_timeout_cdm    <= #TP timeout_error_wo_flr ; // timeout errors wo flr(timeouts) is 
                                                              // now connected to the CDM.input instead radm_cpl_timeout to avoid indicate 
                                                              // timeout error in the cdm because the flr information of the tag released
        radm_timeout_cpl_tag  <= #TP {TAG_SIZE{1'b0}};
        radm_timeout_cpl_tag[CPL_LUT_PTR_WD-1:0]    <= #TP timeout_addr_reg;
        if (timeout_10_or_14_bit_tag) // Unmapping
          // tag size is 14bit but we do not enable 14bit requester capability while LUT size is less than 1K. Only 10/8 bit requester capabilities are enabled.
          radm_timeout_cpl_tag    <= #TP 10'b0100000000 + timeout_addr_reg; // timeout_addr is CPL_LUT_PTR_WD=<TAG_SIZE
        radm_timeout_cpl_attr   <= #TP timeout_vec_reg[ATTR_INDEX-1: TC_INDEX];
        radm_timeout_cpl_tc     <= #TP timeout_vec_reg[TC_INDEX-1 : BYTECNT_INDEX];
        radm_timeout_func_num   <= #TP timeout_pf;
        radm_timeout_low_addr    <= #TP timeout_vec2_reg[LOW_ADDR_WD2-1:0];
        radm_timeout_np_req_type <= #TP timeout_vec_reg[NP_REQ_TYPE_INDEX-1:CPL_TRGT_INDEX];

        radm_timeout_cpl_len    <= #TP timeout_vec2_reg[BYTECNT_INDEX2+BYTECNT_WD2-1 : BYTECNT_INDEX2];
    end
end

function automatic [NF-1:0] get_func_timeout;
input   [(4*NF)-1:0] cfg_cpl_timeout_range;
input          [7:0] timer_expired_iov;
input   [NF-1:0]  flr_pf_active;
logic          [3:0] local_range;
begin
  for (int i=0; i<NF; i=i+1) begin
      if (flr_pf_active[i]) // set timeout min=50us max=100us in flr case
         local_range = 4'b0001;
      else
         local_range = cfg_cpl_timeout_range[4*i +: 4];

       case (local_range)
           4'b0001:  get_func_timeout[i] = timer_expired_iov[0];
           4'b0010:  get_func_timeout[i] = timer_expired_iov[1];
           4'b0101:  get_func_timeout[i] = timer_expired_iov[2];
           4'b0110:  get_func_timeout[i] = timer_expired_iov[3];
           4'b1001:  get_func_timeout[i] = timer_expired_iov[4];
           4'b1010:  get_func_timeout[i] = timer_expired_iov[5];
           4'b1101:  get_func_timeout[i] = timer_expired_iov[6];
           4'b1110:  get_func_timeout[i] = timer_expired_iov[7];
           default:  get_func_timeout[i] = timer_expired_iov[2];
       endcase
  end // for (i=0; i<NF; i=i+1) begin
end
endfunction



     function    automatic get_map_onehot_func;
     input [PF_WD-1:0] local_func;
     input [NF-1:0]      onehot_function;
     begin
         get_map_onehot_func = 0;
         for (int i=0;i<NF;i=i+1) begin
             if (local_func==i)
                 get_map_onehot_func = onehot_function[i];
         end
     end
     endfunction



function automatic [NF-1 : 0 ] check_radm_cpl_pending_pf;
input [NF-1:0]             cpl_pending_pf;
input [CPL_LUT_PTR_WD-1:0]  timeout_addr;
input                       timer_freq;
input                       valid;                      // Valid bits (per entry)
input [CPL_ENTRY_WIDTH-1:0] lut_entry;

logic [NF-1:0]              local_cpl_pending_pf;
logic [PF_WD-1:0]           local_func_num_pf;

begin
    if ((timeout_addr==0) && timer_freq) begin
      local_cpl_pending_pf = {NF{1'b0}};
    end else begin
      local_cpl_pending_pf = cpl_pending_pf;
    end

    local_func_num_pf = lut_entry[FUNC_NUM_INDEX-1:0];

    for (int i=0; i<NF; i=i+1) begin
      if (i==local_func_num_pf) local_cpl_pending_pf[i] = local_cpl_pending_pf[i] | valid;
    end

    check_radm_cpl_pending_pf = local_cpl_pending_pf;
end
endfunction


endmodule
