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
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/PTM/ptm_request_reg.sv#14 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Precision Time Measurement Extended Capability (PTM) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------



`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module ptm_request_reg
#(
    parameter INST                  = 0,                                // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM              = 0                                 // uniquifying parameter per function                                 
    ,parameter PTM_REQ_VALUE        = `CX_PTM_REQUESTER_VALUE 
    ,parameter WF = 16
    ,parameter NPTMREQVSEC          = 31
   )

  
                       (

  input                                   aux_clk,
  input                                   sticky_rst_n,
  input                                   non_sticky_rst_n,
  input [31:0]                            lbc_cdm_data,                 // Write Data 
  input                                   lbc_cdm_dbi,                  // DBI Access
  input                                   dbi_ro_wr_en,                 // used to make RW registers look like RO for compliance
  input [3:0]                             write_pulse,             // Write Byte Enables
  input [NPTMREQVSEC-1:0]                 reg_id,                  
  input                                   cfg_ptm_root_select,
  input                                   cfg_ptm_enabled,
  input                                   phy_link_up,

  input [63:0]                            radm_ptm_master_time,          //input from radm
  input [31:0]                            radm_ptm_prop_delay,
  input                                   radm_ptm_res_d_msg,

  input                                   ptm_calc_round_trip,
  input                                   ptm_calc_update,
  input                                   ptm_update_local_clk,
  input                                   ptm_trigger_allowed,
  input                                   ptm_context_valid,
  input                                   ptm_clock_period_change,
  input  [63:0]                           local_clk,

  input                                   xdlh_ptm_sot,                 //layer 2
  input                                   xdlh_ptm_multi_cycle,       //layer 2represents a message 
  input                                   xdlh_ptm_request,           //layer 2represents a message 
  input                                   rdlh_ptm_sot,                 //layer 2
  input                                   rdlh_ptm_multi_cycle,             //layer 2 represents a message
  input                                   rdlh_ptm_response,                //layer 2 represents a message
  input [11:0]                            ptm_eof_latency,             // Distance, in nsec, between flit eof and ptm bit.
  input                                   flit_mode_link,              // Indicates the link has come up in flit mode

  input [2:0]                             ptm_latency_sel,            // latency select

  input [7+WF:0]                          ptm_nom_clock_period,
  input [7+WF:0]                          ptm_clock_period,


  
  output reg [7+WF:0]                     ptm_scaled_clock_period,
  output reg                              ptm_scaled_clock_period_en,

  output reg signed [63:0]                ptm_requester_adjust_value,
  output reg signed [63:0]                ptm_clock_correction,
  output reg                              ptm_auto_update_en_reg,
  output reg                              ptm_manual_update_reg,
  output reg                              ptm_fast_timer,
  output reg [7:0]                        ptm_long_timer,
  output reg [31:0]                       ptm_req_reg_data           // VSEC Register Read Data
);

  localparam TP = `TP;
  localparam NUM_PCIE_RATES = 5 +1; // Number of PCIe Rates
  // Supported PCIe data rates: 2.5 GT/s, 5 GT/s, 8 GT/s, 16 GT/s, 32 GT/s
  localparam NUM_ESM_RATES = 2;  // Number of additional CCIX ESM Rates
  // Supported additional CCIX ESM data rates: 20 GT/s, 25 GT/s

  localparam NUM_SPEEDS = `CCIX_ESM_SUPPORT_VALUE ? NUM_PCIE_RATES + NUM_ESM_RATES : NUM_PCIE_RATES;
  localparam NUM_SPEEDS_WD = NUM_SPEEDS > 1 ? $clog2(NUM_SPEEDS) : 1;
// -------------- Internal Signals --------------
  
  reg     [63:0]                        t1_previous;           //loaded from _now when message recognised as PTM message
  reg     [63:0]                        t1_pending;            //stamped at SOT
  reg     [63:0]                        t1_now;                //loaded from _pending when message recognised as PTM message
  reg     [63:0]                        t1_now_preserved;    
  reg     [63:0]                        t1_prev_preserved;  
  reg     [63:0]                        t4_now;                //loaded from _pending when message recognised as PTM message
  reg     [63:0]                        t4_previous;           //loaded from _now when message recognised as PTM message  
  reg     [63:0]                        t4_pending;            //stamped at SOT

  reg     [63:0]                        round_trip;            //((t4 - t1) - (t3 - t2))

  reg     [63:0]                        ptm_master_time_reg;
  reg     [31:0]                        ptm_prop_delay_reg;


  reg     [11:0]        ptm_requester_length;
  reg     [3:0]         ptm_requester_rev;
  reg     [15:0]        ptm_requester_id;

  wire   [11:0]         tx_latency;
  wire   [11:0]         rx_latency;
  reg    [13:0]         fm_tx_latency;
  reg    [13:0]         fm_rx_latency;
  
  logic  [11:0]         tx_latency_rd;
  logic  [11:0]         rx_latency_rd;
  
  wire    [7:0]         ptm_req_reg_07, ptm_req_reg_06, ptm_req_reg_05, ptm_req_reg_04;         //Vendor Specific header            0x04       
  wire    [7:0]         ptm_req_reg_11, ptm_req_reg_10, ptm_req_reg_09, ptm_req_reg_08;         //Control Registers                 0x8            
  wire    [7:0]         ptm_req_reg_15, ptm_req_reg_14, ptm_req_reg_13, ptm_req_reg_12;         //Status Register                   0xC
  wire    [7:0]         ptm_req_reg_19, ptm_req_reg_18, ptm_req_reg_17, ptm_req_reg_16;         //Local Time [31:0]                 0x10
  wire    [7:0]         ptm_req_reg_23, ptm_req_reg_22, ptm_req_reg_21, ptm_req_reg_20;         //Local Time [63:32]                0x14
  wire    [7:0]         ptm_req_reg_27, ptm_req_reg_26, ptm_req_reg_25, ptm_req_reg_24;         //T1 TimeStamp [31:0]               0x18           
  wire    [7:0]         ptm_req_reg_31, ptm_req_reg_30, ptm_req_reg_29, ptm_req_reg_28;         //T1 TimeStamp [63:32]              0x1C
  wire    [7:0]         ptm_req_reg_35, ptm_req_reg_34, ptm_req_reg_33, ptm_req_reg_32;         //T1 previous TimeStamp [31:0]      0x20
  wire    [7:0]         ptm_req_reg_39, ptm_req_reg_38, ptm_req_reg_37, ptm_req_reg_36;         //T1 previous TimeStamp [63:32]     0x24
  wire    [7:0]         ptm_req_reg_43, ptm_req_reg_42, ptm_req_reg_41, ptm_req_reg_40;         //T4 TimeStamp [31:0]               0x28
  wire    [7:0]         ptm_req_reg_47, ptm_req_reg_46, ptm_req_reg_45, ptm_req_reg_44;         //T4 TimeStamp [63:32]              0x2C
  wire    [7:0]         ptm_req_reg_51, ptm_req_reg_50, ptm_req_reg_49, ptm_req_reg_48;         //T4 previous TimeStamp [31:0]      0x30
  wire    [7:0]         ptm_req_reg_55, ptm_req_reg_54, ptm_req_reg_53, ptm_req_reg_52;         //T4 previous TimeStamp [63:32]     0x34
  wire    [7:0]         ptm_req_reg_59, ptm_req_reg_58, ptm_req_reg_57, ptm_req_reg_56;         //PTM Master Time [31:0]            0x38
  wire    [7:0]         ptm_req_reg_63, ptm_req_reg_62, ptm_req_reg_61, ptm_req_reg_60;         //PTM Master Time [63:32]           0x3C
  wire    [7:0]         ptm_req_reg_67, ptm_req_reg_66, ptm_req_reg_65, ptm_req_reg_64;         //Propagation Delay [31:0]          0x40
  wire    [7:0]         ptm_req_reg_71, ptm_req_reg_70, ptm_req_reg_69, ptm_req_reg_68;         //PTM Master Time at t1' [31:0]     0x44
  wire    [7:0]         ptm_req_reg_75, ptm_req_reg_74, ptm_req_reg_73, ptm_req_reg_72;         //PTM Master Time at t1' [63:32]    0x48
  wire    [7:0]         ptm_req_reg_79, ptm_req_reg_78, ptm_req_reg_77, ptm_req_reg_76;         //Tx Latency                        0x4C
  wire    [7:0]         ptm_req_reg_83, ptm_req_reg_82, ptm_req_reg_81, ptm_req_reg_80;         //Rx Latency                        0x50
  // Clock Scaling Registers
  wire    [7:0]         ptm_req_reg_87, ptm_req_reg_86, ptm_req_reg_85, ptm_req_reg_84;         //PTM Clock Correction LSB         0x54
  wire    [7:0]         ptm_req_reg_91, ptm_req_reg_90, ptm_req_reg_89, ptm_req_reg_88;         //PTM Clock Correction MSB         0x58
  wire    [7:0]         ptm_req_reg_95, ptm_req_reg_94, ptm_req_reg_93, ptm_req_reg_92;         //PTM Nominal Clock Period         0x5C
  wire    [7:0]         ptm_req_reg_99, ptm_req_reg_98, ptm_req_reg_97, ptm_req_reg_96;         //PTM Scaled Clock Period          0x60

  wire    [7:0]         ptm_req_reg_103, ptm_req_reg_102, ptm_req_reg_101, ptm_req_reg_100;     //PTM Requester Latency Register Select 0x64



  wire    [63:0]        ptm_master_time_t1_tick;
  wire                  ptm_manual_update_reg_clr;

  wire signed [63:0]    ptm_requester_adjust_value_int;
  wire signed [63:0]    ptm_clock_correction_int;
  reg  signed [63:0]    ptm_clock_correction_reg;

  reg                   ptm_req_pdel_byte_rev;

  reg    [3:0]          ptm_req_latency_reg_sel;                                                // Latency Register Select
  reg                   ptm_req_esm_sel;                                                        // ESM Latency Register Select
  
  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ: Differences will not cause overflow

  assign ptm_requester_adjust_value_int = local_clk + ((ptm_master_time_reg - {round_trip[63], round_trip[63:1]}) - t1_now_preserved);
  assign ptm_clock_correction_int = ((ptm_master_time_reg - {round_trip[63], round_trip[63:1]}) - t1_now_preserved);
  assign ptm_master_time_t1_tick = ptm_master_time_reg[63:0] - {round_trip[63], round_trip[63:1]};
  // spyglass enable_block W164a

  // register the PTM requester adjust value for timing purposes and the PTM
  // clock correction output to match
  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      ptm_requester_adjust_value <= #TP 0;
      ptm_clock_correction_reg <= #TP 0;
      ptm_clock_correction <= #TP 0;
    end else begin
      ptm_requester_adjust_value <= #TP ptm_calc_update ? ptm_requester_adjust_value_int : ptm_requester_adjust_value;
      ptm_clock_correction_reg   <= #TP ptm_calc_update ? ptm_clock_correction_int : ptm_clock_correction_reg;
      ptm_clock_correction       <= #TP ptm_update_local_clk ? ptm_clock_correction_reg : ptm_clock_correction;
    end
  end

  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      t1_pending      <= #TP 0;
    end else if (xdlh_ptm_sot) begin        //latch pending time even if PTM not enabled
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: t1_pending wraps around after 2^64 ns
      t1_pending      <= #TP local_clk + ptm_clock_period[7+WF:WF] + tx_latency;
      // spyglass enable_block W164a

    end
  end


  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      t1_previous <= #TP 0;
      t1_now      <= #TP 0;

    end else if (xdlh_ptm_request && cfg_ptm_enabled) begin      
      t1_previous <= #TP (((t1_now != t1_pending) && xdlh_ptm_multi_cycle) || !xdlh_ptm_multi_cycle) ? t1_now : t1_previous;
 
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: t1_now wraps around after 2^64 ns
      t1_now      <= #TP (xdlh_ptm_sot && !xdlh_ptm_multi_cycle)                    ? (local_clk + ptm_clock_period[7+WF:WF] + tx_latency) :
                         (!xdlh_ptm_sot || (xdlh_ptm_sot && xdlh_ptm_multi_cycle))  ? t1_pending                                  :
                          t1_now;
      // spyglass enable_block W164a

    end
  end


  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      t4_pending      <= #TP 0;

    end else if (rdlh_ptm_sot) begin      //latch pending time even if PTM not enabled
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: t4_pending wraps around after 2^64 ns
      t4_pending      <= #TP local_clk + ptm_clock_period[7+WF:WF] - rx_latency;
      // spyglass enable_block W164a

    end
  end


  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      t4_now      <= #TP 0;
      t4_previous <= #TP 0;

      t1_now_preserved <= #TP 0;
      t1_prev_preserved <= #TP 0;

    end else if (rdlh_ptm_response && cfg_ptm_enabled) begin          
      t4_previous       <= #TP t4_now;
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: t4_now wraps around after 2^64 ns
      t4_now            <= #TP (rdlh_ptm_sot && !rdlh_ptm_multi_cycle)                   ? (local_clk + ptm_clock_period[7+WF:WF] - rx_latency)  :
                               (!rdlh_ptm_sot || (rdlh_ptm_sot && rdlh_ptm_multi_cycle)) ? t4_pending                                   :
                               t4_now;
      // spyglass enable_block W164a

      t1_now_preserved  <= #TP t1_now;            //preserve all t1 values once we get the t4 value so the calculation is correct
      t1_prev_preserved <= #TP t1_previous;

    end
  end


  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      ptm_master_time_reg <= #TP 0;

    end else if(radm_ptm_res_d_msg & cfg_ptm_enabled) begin
      ptm_master_time_reg  <= #TP radm_ptm_master_time;

    end
  end


  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      ptm_prop_delay_reg  <= #TP 0;

    end else if(radm_ptm_res_d_msg & cfg_ptm_enabled) begin
      ptm_prop_delay_reg  <= #TP ptm_req_pdel_byte_rev ? radm_ptm_prop_delay : {radm_ptm_prop_delay[7:0],radm_ptm_prop_delay[15:8],radm_ptm_prop_delay[23:16],radm_ptm_prop_delay[31:24]}; // byte order is incorrect in radm_filter_ep.v and radm_filter_sw.v, so reverse the byte order here unless compatibility mode is selected using ptm_res_pdel_byte_rev
    end
  end    

      
  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      round_trip <= #TP 0;
      
    end else if(ptm_calc_round_trip) begin                     
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: round_trip is much less than 2^63 ns so no risk of loss of sign
      round_trip <= #TP (t4_previous[63:0] - t1_prev_preserved[63:0]) - ptm_prop_delay_reg[31:0];     //((t4 - t1) - (t3 - t2))
      // spyglass enable_block W164a

    end
  end

//  always@(posedge aux_clk or negedge sticky_rst_n)    //preserve the t1_now value for this moment to be used in the calculation
//  begin 
//    if(!sticky_rst_n) begin
//      t1_now_preserved <= #TP 0;
//      
//    end else if(ptm_calc_round_trip) begin                     
//      t1_now_preserved <= #TP t1_now;     
//
//    end
//  end

// -----------------------------------------------------------------------------
// PTM Requester Vendor Specific Register
// -----------------------------------------------------------------------------
// reg_id       - 1
// PCIE Offset      - `VSEC_PTR + 04h
// length           - 4 byte
// Cfig register    - ptm_req_reg_07, ptm_req_reg_06, ptm_req_reg_05, ptm_req_reg_04
// Depth is Read Only. Interrupt message num may be set from DBI side
// -----------------------------------------------------------------------------

localparam PTM_REQUESTER_LENGTH = (21*4);                 //12 bits. number of bytes in responder vendor specific capability


  always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
      ptm_requester_id[15:0]      <= #TP `PCIE_PTM_REQ_ID;
      ptm_requester_rev[3:0]      <= #TP `PCIE_PTM_REQ_REV;
      ptm_requester_length[11:0]  <= #TP PTM_REQUESTER_LENGTH;

    end else begin
      ptm_requester_id[7:0]      <= #TP (reg_id[1] & write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0]   : ptm_requester_id[7:0];
      ptm_requester_id[15:8]     <= #TP (reg_id[1] & write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8]  : ptm_requester_id[15:8];
      ptm_requester_rev[3:0]     <= #TP (reg_id[1] & write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : ptm_requester_rev[3:0];
      ptm_requester_length[3:0]  <= #TP (reg_id[1] & write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[23:20] : ptm_requester_length[3:0];
      ptm_requester_length[11:4] <= #TP (reg_id[1] & write_pulse[3] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[31:24] : ptm_requester_length[11:4];
    end
  end



assign ptm_req_reg_07 = ptm_requester_length[11:4];

assign ptm_req_reg_06 = {ptm_requester_length[3:0], 
                         ptm_requester_rev};   

assign ptm_req_reg_05 = ptm_requester_id[15:8];      
assign ptm_req_reg_04 = ptm_requester_id[7:0];



// -----------------------------------------------------------------------------
// PTM Requester Control
// -----------------------------------------------------------------------------
// reg_id       - 2
// PCIE Offset      - `VSEC_PTR + 08h
// length           - 8 byte
// Cfig register    - ptm_req_reg_11, ptm_req_reg_10, ptm_req_reg_09, ptm_req_reg_08
// DBI and Wire RW
// -----------------------------------------------------------------------------

localparam PTM_FAST_TIMER   = 1'b0;

always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        ptm_auto_update_en_reg       <= #TP 1'b0;    
    end else begin
        ptm_auto_update_en_reg       <= #TP (reg_id[2] & write_pulse[0]) ? lbc_cdm_data[0] : ptm_auto_update_en_reg;

    end
end 

assign ptm_manual_update_reg_clr = ptm_manual_update_reg; // auto clears

always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        ptm_manual_update_reg       <= #TP 0;   
    end else begin
        ptm_manual_update_reg       <= #TP ptm_manual_update_reg_clr ? 0 : (reg_id[2] & write_pulse[0]) ? lbc_cdm_data[1] : ptm_manual_update_reg;
    end
end 


always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        ptm_fast_timer       <= #TP PTM_FAST_TIMER;    
    end else begin
        ptm_fast_timer       <= #TP (reg_id[2] & write_pulse[0]) ? lbc_cdm_data[2] : ptm_fast_timer;
    end
end 


localparam LONG_TIMER_RESET = 9;
always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        ptm_long_timer       <= #TP LONG_TIMER_RESET;       //value in millseconds    
    end else begin
        ptm_long_timer       <= #TP (reg_id[2] & write_pulse[1]) ? lbc_cdm_data[15:8] : ptm_long_timer;
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        ptm_req_pdel_byte_rev   <= #TP 1'b0;       // Default PTM Propagation Delay Byte Reverse Disabled
    end else begin
        ptm_req_pdel_byte_rev   <= #TP (reg_id[2] & write_pulse[2]) ? lbc_cdm_data[16] : ptm_req_pdel_byte_rev;
    end
end

assign ptm_req_reg_11 = 8'b0;
assign ptm_req_reg_10 = {7'b0,
                         ptm_req_pdel_byte_rev                     // reverse order of bytes in the PTM Propagation Delay message, for compatibility with previous revisions         
                        };
assign ptm_req_reg_09 = ptm_long_timer;
assign ptm_req_reg_08 = {5'b0, 
                         ptm_fast_timer,
                         ptm_manual_update_reg,                             //auto clears
                         ptm_auto_update_en_reg
                        };



// -----------------------------------------------------------------------------
// PTM Requester Status
// -----------------------------------------------------------------------------
// reg_id       - 3
// PCIE Offset      - `VSEC_PTR + 0ch
// length           - 4 byte
// Cfig register    - ptm_req_reg_15, ptm_req_reg_14, ptm_req_reg_13, ptm_req_reg_12
// DBI and Wire Read Only from wire side
// -----------------------------------------------------------------------------

assign ptm_req_reg_15 = 8'b0;
assign ptm_req_reg_14 = 8'b0;
assign ptm_req_reg_13 = 8'b0;
assign ptm_req_reg_12 = {6'b0,  
                         ptm_trigger_allowed, 
                         ptm_context_valid
                        };



// -----------------------------------------------------------------------------
// PTM Requester Times
// -----------------------------------------------------------------------------
// reg_id       - 4 to 18
// PCIE Offset  - `VSEC_PTR + 10h to `VSEC_PTR + 48h
// length       - 4 byte
// 
// DBI and Wire Read Only
// -----------------------------------------------------------------------------


assign {ptm_req_reg_19, ptm_req_reg_18, ptm_req_reg_17, ptm_req_reg_16} = local_clk[31:0];            // local time[31:0]
assign {ptm_req_reg_23, ptm_req_reg_22, ptm_req_reg_21, ptm_req_reg_20} = local_clk[63:32];           // local time[63:32]
assign {ptm_req_reg_27, ptm_req_reg_26, ptm_req_reg_25, ptm_req_reg_24} = t1_now[31:0];               // T1 Timestamp [31:0]
assign {ptm_req_reg_31, ptm_req_reg_30, ptm_req_reg_29, ptm_req_reg_28} = t1_now[63:32];              //T1 TimeStamp [63:32]
assign {ptm_req_reg_35, ptm_req_reg_34, ptm_req_reg_33, ptm_req_reg_32} = t1_previous[31:0];          //T1 previous TimeStamp [31:0]
assign {ptm_req_reg_39, ptm_req_reg_38, ptm_req_reg_37, ptm_req_reg_36} = t1_previous[63:32];         //T1 previous TimeStamp [63:32]
assign {ptm_req_reg_43, ptm_req_reg_42, ptm_req_reg_41, ptm_req_reg_40} = t4_now[31:0];               //T4 TimeStamp [31:0]
assign {ptm_req_reg_47, ptm_req_reg_46, ptm_req_reg_45, ptm_req_reg_44} = t4_now[63:32];              //T4 TimeStamp [63:32]
assign {ptm_req_reg_51, ptm_req_reg_50, ptm_req_reg_49, ptm_req_reg_48} = t4_previous[31:0];          //T4 previous TimeStamp [31:0]
assign {ptm_req_reg_55, ptm_req_reg_54, ptm_req_reg_53, ptm_req_reg_52} = t4_previous[63:32];         //T4 previous TimeStamp [63:32]
assign {ptm_req_reg_59, ptm_req_reg_58, ptm_req_reg_57, ptm_req_reg_56} = ptm_master_time_reg[31:0];  //PTM Master Time [31:0]
assign {ptm_req_reg_63, ptm_req_reg_62, ptm_req_reg_61, ptm_req_reg_60} = ptm_master_time_reg[63:32];
assign {ptm_req_reg_67, ptm_req_reg_66, ptm_req_reg_65, ptm_req_reg_64} = ptm_prop_delay_reg[31:0];
assign {ptm_req_reg_71, ptm_req_reg_70, ptm_req_reg_69, ptm_req_reg_68} = ptm_master_time_t1_tick[31:0];
assign {ptm_req_reg_75, ptm_req_reg_74, ptm_req_reg_73, ptm_req_reg_72} = ptm_master_time_t1_tick[63:32];


// -----------------------------------------------------------------------------
// PTM Requester Tx and RX latency viewport registers
// -----------------------------------------------------------------------------
// reg_id          - 19 to 20
// PCIE Offset     - `VSEC_PTR + 4ch to `VSEC_PTR + 50h
// length          - 4 byte
// Cfig register   - ptm_req_reg_79, ptm_req_reg_78, ptm_req_reg_77, ptm_req_reg_76
//                 - ptm_req_reg_83, ptm_req_reg_82, ptm_req_reg_81, ptm_req_reg_80
// DBI and Wire Read Only
// -----------------------------------------------------------------------------
reg   [11:0] tx_latency_r [(NUM_SPEEDS-1):0], rx_latency_r [(NUM_SPEEDS-1):0];
wire  [4:0] ptm_req_latency_reg_index;

assign ptm_req_latency_reg_index = {1'b0, ptm_req_latency_reg_sel[3:0]};

always @( posedge aux_clk or negedge sticky_rst_n ) begin : proc_latency_regs
  integer i;
  if ( !sticky_rst_n ) begin
    for (i=0; i<(NUM_SPEEDS); i=i+1) begin
      tx_latency_r[i][11:0]     <= #TP `CX_PHY_TX_DELAY_PHY + `CX_PHY_TX_DELAY_MAC;    
      rx_latency_r[i][11:0]     <= #TP `CX_PHY_RX_DELAY_PHY + `CX_PHY_RX_DELAY_MAC;
    end
  end else begin
    for (i=0; i<(NUM_SPEEDS); i=i+1) begin
      // Select latency viewport register for write
      tx_latency_r[i][7:0]        <= #TP (reg_id[19] & write_pulse[0] & (ptm_req_latency_reg_index == i)) ? lbc_cdm_data[7:0]    : tx_latency_r[i][7:0];
      tx_latency_r[i][11:8]       <= #TP (reg_id[19] & write_pulse[1] & (ptm_req_latency_reg_index == i)) ? lbc_cdm_data[11:8]   : tx_latency_r[i][11:8];

      rx_latency_r[i][7:0]        <= #TP (reg_id[20] & write_pulse[0] & (ptm_req_latency_reg_index == i)) ? lbc_cdm_data[7:0]    : rx_latency_r[i][7:0];
      rx_latency_r[i][11:8]       <= #TP (reg_id[20] & write_pulse[1] & (ptm_req_latency_reg_index == i)) ? lbc_cdm_data[11:8]   : rx_latency_r[i][11:8];
    end
  end
end

// Select latency viewport register for timestamp adjust
// Concat operators in proc below to resolve spyglass W146 wanring.
always @( posedge aux_clk or negedge sticky_rst_n ) begin : proc_fm_latency
  if ( !sticky_rst_n ) begin
    fm_tx_latency <= #TP 'd0;
    fm_rx_latency <= #TP 'd0;
  end else begin
    if(flit_mode_link) begin
      if(({1'b0, ptm_eof_latency} + ptm_clock_period[7+WF:WF]) > {1'b0, tx_latency_r[ptm_latency_sel][11:0]})
        fm_tx_latency <= #TP 'd0;
      else
        fm_tx_latency <= #TP {2'b0, tx_latency_r[ptm_latency_sel][11:0]} - ptm_eof_latency - ptm_clock_period[7+WF:WF];
      fm_rx_latency <= #TP {2'b0, rx_latency_r[ptm_latency_sel][11:0]} + ptm_eof_latency;
    end else begin
      fm_tx_latency <= #TP {2'b0, tx_latency_r[ptm_latency_sel][11:0]};
      fm_rx_latency <= #TP {2'b0, rx_latency_r[ptm_latency_sel][11:0]};
    end
  end
end
assign tx_latency[11:0] = fm_tx_latency[11:0];
assign rx_latency[11:0] = fm_rx_latency[11:0];
// TODO - add assertion for underflow condition.

// Select latency viewport register for read
always_comb begin
 tx_latency_rd[11:0] = tx_latency_r[ptm_req_latency_reg_index>=NUM_SPEEDS ? 0 : ptm_req_latency_reg_index[NUM_SPEEDS_WD-1:0]][11:0];
 rx_latency_rd[11:0] = rx_latency_r[ptm_req_latency_reg_index>=NUM_SPEEDS ? 0 : ptm_req_latency_reg_index[NUM_SPEEDS_WD-1:0]][11:0];
end
assign {ptm_req_reg_79, ptm_req_reg_78, ptm_req_reg_77, ptm_req_reg_76} = {20'b0, tx_latency_rd};
assign {ptm_req_reg_83, ptm_req_reg_82, ptm_req_reg_81, ptm_req_reg_80} = {20'b0, rx_latency_rd};

// -----------------------------------------------------------------------------
// PTM Requester Clock Correction Register
// -----------------------------------------------------------------------------
// reg_id       - 21 to 22
// PCIE Offset  - `VSEC_PTR + 54h to `VSEC_PTR + 58h
// length       - 4 byte
// 
// DBI and Wire Read Only
// -----------------------------------------------------------------------------

assign {ptm_req_reg_87, ptm_req_reg_86, ptm_req_reg_85, ptm_req_reg_84} = ptm_clock_correction[31:0];
assign {ptm_req_reg_91, ptm_req_reg_90, ptm_req_reg_89, ptm_req_reg_88} = ptm_clock_correction[63:32];

// -----------------------------------------------------------------------------
// PTM Requester Nominal and Scaled Clock Registers
// -----------------------------------------------------------------------------
// reg_id       - 23 to 24
// PCIE Offset  - `VSEC_PTR + 5ch to `VSEC_PTR + 60h
// length       - 4 byte
// 
// DBI and Wire Read Only
// -----------------------------------------------------------------------------

assign {ptm_req_reg_95, ptm_req_reg_94, ptm_req_reg_93, ptm_req_reg_92} = {{(32-(8+WF)){1'b0}}, ptm_nom_clock_period};

always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        ptm_scaled_clock_period      <= #TP 0;    
        ptm_scaled_clock_period_en   <= #TP 0;
    end else begin
        ptm_scaled_clock_period[7:0]        <= #TP (reg_id[24] & write_pulse[0]) ? lbc_cdm_data[7:0]        : ptm_scaled_clock_period[7:0];
        ptm_scaled_clock_period[15:8]       <= #TP (reg_id[24] & write_pulse[1]) ? lbc_cdm_data[15:8]       : ptm_scaled_clock_period[15:8];
        ptm_scaled_clock_period[23:16]      <= #TP (reg_id[24] & write_pulse[2]) ? lbc_cdm_data[23:16]      : ptm_scaled_clock_period[23:16];
        ptm_scaled_clock_period_en          <= #TP ptm_clock_period_change ? 0 : ((reg_id[24] & write_pulse[3]) ? lbc_cdm_data[31] : ptm_scaled_clock_period_en);
    end
end

assign {ptm_req_reg_99, ptm_req_reg_98, ptm_req_reg_97, ptm_req_reg_96} = {ptm_scaled_clock_period_en, {(32-(8+WF+1)){1'b0}}, ptm_scaled_clock_period};

// -----------------------------------------------------------------------------
// PTM Requester Latency Register Select Register
// -----------------------------------------------------------------------------
// reg_id       - 25
// PCIE Offset  - `VSEC_PTR + 64h
// length       - 4 byte
// 
// DBI and Wire Read Only
// -----------------------------------------------------------------------------

always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        ptm_req_latency_reg_sel <= #TP 0;    
    end else begin
        ptm_req_latency_reg_sel[3:0]        <= #TP (reg_id[25] & write_pulse[0]) ? lbc_cdm_data[3:0]        : ptm_req_latency_reg_sel[3:0];
    end
end

  assign {ptm_req_reg_103, ptm_req_reg_102, ptm_req_reg_101, ptm_req_reg_100} = {24'b0, 4'b0, ptm_req_latency_reg_sel};





// =============================================================================
// Register Read Operation
// =============================================================================


always @( * ) begin : ptm_req_read_data_PROC
    ptm_req_reg_data[31:0] = 0;
    
    if (reg_id[1]) begin
        ptm_req_reg_data = {ptm_req_reg_07, ptm_req_reg_06, ptm_req_reg_05, ptm_req_reg_04};  // read Vendor Specific Capbilities register
    end else if (reg_id[2]) begin
        ptm_req_reg_data = {ptm_req_reg_11, ptm_req_reg_10, ptm_req_reg_09, ptm_req_reg_08};  // control
    end else if (reg_id[3]) begin
        ptm_req_reg_data = {ptm_req_reg_15, ptm_req_reg_14, ptm_req_reg_13, ptm_req_reg_12};  // status
    end else if (reg_id[4]) begin
        ptm_req_reg_data = {ptm_req_reg_19, ptm_req_reg_18, ptm_req_reg_17, ptm_req_reg_16};  // local time[31:0]
    end else if (reg_id[5]) begin
        ptm_req_reg_data = {ptm_req_reg_23, ptm_req_reg_22, ptm_req_reg_21, ptm_req_reg_20};  // local time[63:32]
    end else if (reg_id[6]) begin
        ptm_req_reg_data = {ptm_req_reg_27, ptm_req_reg_26, ptm_req_reg_25, ptm_req_reg_24};  // T1 Timestamp [31:0]
    end else if (reg_id[7]) begin
        ptm_req_reg_data = {ptm_req_reg_31, ptm_req_reg_30, ptm_req_reg_29, ptm_req_reg_28};         //T1 TimeStamp [63:32]
    end else if (reg_id[8]) begin
        ptm_req_reg_data = {ptm_req_reg_35, ptm_req_reg_34, ptm_req_reg_33, ptm_req_reg_32};         //T1 previous TimeStamp [31:0]
    end else if (reg_id[9]) begin
        ptm_req_reg_data = {ptm_req_reg_39, ptm_req_reg_38, ptm_req_reg_37, ptm_req_reg_36};         //T1 previous TimeStamp [63:32]
    end else if (reg_id[10]) begin
        ptm_req_reg_data = {ptm_req_reg_43, ptm_req_reg_42, ptm_req_reg_41, ptm_req_reg_40};         //T4 TimeStamp [31:0]
    end else if (reg_id[11]) begin
        ptm_req_reg_data = {ptm_req_reg_47, ptm_req_reg_46, ptm_req_reg_45, ptm_req_reg_44};         //T4 TimeStamp [63:32]
    end else if (reg_id[12]) begin
        ptm_req_reg_data = {ptm_req_reg_51, ptm_req_reg_50, ptm_req_reg_49, ptm_req_reg_48};         //T4 previous TimeStamp [31:0]
    end else if (reg_id[13]) begin
        ptm_req_reg_data = {ptm_req_reg_55, ptm_req_reg_54, ptm_req_reg_53, ptm_req_reg_52};         //T4 previous TimeStamp [63:32]
    end else if (reg_id[14]) begin
        ptm_req_reg_data = {ptm_req_reg_59, ptm_req_reg_58, ptm_req_reg_57, ptm_req_reg_56};         //PTM Master Time [31:0] or TMU_PTM_B[31:0]
    end else if (reg_id[15]) begin
        ptm_req_reg_data = {ptm_req_reg_63, ptm_req_reg_62, ptm_req_reg_61, ptm_req_reg_60};         //PTM Master Time [63:32] or TMU_PTM_B[63:32]
    end else if (reg_id[16]) begin
        ptm_req_reg_data = {ptm_req_reg_67, ptm_req_reg_66, ptm_req_reg_65, ptm_req_reg_64};         //Propagation Delay [31:0] or TMU_PTM_A[31:0]
    end else if (reg_id[17]) begin
        ptm_req_reg_data = {ptm_req_reg_71, ptm_req_reg_70, ptm_req_reg_69, ptm_req_reg_68};         //PTM Master Time at t1' [31:0] or PTM TMU Derived Master Time
    end else if (reg_id[18])begin
        ptm_req_reg_data = {ptm_req_reg_75, ptm_req_reg_74, ptm_req_reg_73, ptm_req_reg_72};         //PTM Master Time at t1' [63:32] or PTM TMU Derived Master Time
    end else if (reg_id[19]) begin
        ptm_req_reg_data = {ptm_req_reg_79, ptm_req_reg_78, ptm_req_reg_77, ptm_req_reg_76};         //Tx Latency
    end else if (reg_id[20]) begin
        ptm_req_reg_data = {ptm_req_reg_83, ptm_req_reg_82, ptm_req_reg_81, ptm_req_reg_80};         //Rx Latency
    end else if (reg_id[21]) begin
        ptm_req_reg_data = {ptm_req_reg_87, ptm_req_reg_86, ptm_req_reg_85, ptm_req_reg_84};         //PTM Clock Correction LSB
    end else if (reg_id[22]) begin
        ptm_req_reg_data = {ptm_req_reg_91, ptm_req_reg_90, ptm_req_reg_89, ptm_req_reg_88};         //PTM Clock Correction MSB
    end else if (reg_id[23]) begin
        ptm_req_reg_data = {ptm_req_reg_95, ptm_req_reg_94, ptm_req_reg_93, ptm_req_reg_92};         //PTM Nominal Clock Period
    end else if (reg_id[24]) begin
        ptm_req_reg_data = {ptm_req_reg_99, ptm_req_reg_98, ptm_req_reg_97, ptm_req_reg_96};         //PTM Scaled Clock Period
    end else if (reg_id[25]) begin
        ptm_req_reg_data = {ptm_req_reg_103, ptm_req_reg_102, ptm_req_reg_101, ptm_req_reg_100};     //PTM Latency Register Select
    end 
end //always ptm_req_read_data_PROC



endmodule //ptm_request_reg 
