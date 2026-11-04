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
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/PTM/ptm_responder_reg.sv#13 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Precision Time Measurement Extended Capability (PTM) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------




`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module ptm_responder_reg
#(
    parameter INST                  = 0,                                // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM              = 0                                 // uniquifying parameter per function  
    ,parameter WF = 16
    ,parameter NPTMRESVSEC          = 19
   )

  (

  input                                   aux_clk,
  input                                   non_sticky_rst_n,
  input                                   sticky_rst_n,
  input [31:0]                            lbc_cdm_data,                 // Write Data 
  input                                   lbc_cdm_dbi,                  // DBI Access
  input                                   dbi_ro_wr_en,                 // used to make RW registers look like RO for compliance
  input [3:0]                             write_pulse,                  // Write Byte Enables
  input [NPTMRESVSEC-1:0]                 reg_id,                       // VSEC Register ID
  input                                   cfg_ptm_enabled,
  input                                   phy_link_up,

  input                                   ptm_state_at_res_d,
  input [63:0]                            local_clk,
  input                                   xdlh_ptm_sot,                //layer 2
  input                                   xdlh_ptm_multi_cycle,        //layer 2represents a message 
  input                                   xdlh_ptm_response,           //layer 2represents a message 
  input                                   rdlh_ptm_sot,                //layer 2
  input                                   rdlh_ptm_multi_cycle,        //layer 2 represents a message
  input                                   rdlh_ptm_request,            //layer 2 represents a message
  input [11:0]                            ptm_eof_latency,             // Distance, in nsec, between flit eof and ptm bit.
  input                                   flit_mode_link,              // Indicates the link has come up in flit mode

  input [2:0]                             ptm_latency_sel,             // latency select

  input [7+WF:0]                          ptm_nom_clock_period,
  input [7+WF:0]                          ptm_clock_period,
  input                                   ptm_clock_period_change,
  input                                   pm_sel_aux_clk,
  input ptm_responder_rdy_to_validate,
  input ptm_external_master_strobe,



  
  output reg [7+WF:0]                     ptm_scaled_clock_period,
  output reg                              ptm_scaled_clock_period_en,

  output                                  ptm_status_context_valid,
  output [63:0]                           ptm_master_time,                  //to msg_gen
  output reg [31:0]                       ptm_prop_delay,                   //to msg_gen
  output reg [31:0]                       ptm_res_reg_data    // VSEC Register Read Data
);

  localparam TP = `TP;
  localparam NUM_PCIE_RATES = 5 +1; // Number of PCIe Rates
  // Supported PCIe data rates: 2.5 GT/s, 5 GT/s, 8 GT/s, 16 GT/s, 32 GT/s
  localparam NUM_ESM_RATES = 2;  // Number of additional CCIX ESM Rates
  // Supported additional CCIX ESM data rates: 20 GT/s, 25 GT/s

  localparam NUM_SPEEDS = `CCIX_ESM_SUPPORT_VALUE ? NUM_PCIE_RATES + NUM_ESM_RATES : NUM_PCIE_RATES;
  localparam NUM_SPEEDS_WD = NUM_SPEEDS > 1 ? $clog2(NUM_SPEEDS) : 1;

  reg [63:0]                            t2_now;               //stamped on recognition of PTM message at layer2 on Rx Path
  reg [63:0]                            t2_previous;          //stamped on recognition of PTM message at layer2 on Rx Path
  reg                                   t2_previous_d;
  reg [63:0]                            t2_pending;           //stamped on SOT on Rx path
  reg [63:0]                            t3_now;               //stamped on recognition of PTM message at layer2 on Tx Path
  reg [63:0]                            t3_previous;          //stamped on recognition of PTM message at layer2 on Tx Path
  reg [63:0]                            t3_pending;           //stamped on SOT on Tx path
  

// Located in cdm_ecfg_reg
//cfg_ptm_res_id;                                     // Capability ID
//cfg_ptm_res_ver;                                    // Capability Version
//cfg_ptm_res_next_ptr;                               // Next Capability Offset
   
  reg     [11:0]        ptm_responder_length;
  reg     [3:0]         ptm_responder_rev;
  reg     [15:0]        ptm_responder_id;

  reg                   ptm_context_valid;
  
  reg                   ptm_res_pdel_byte_rev; // reverse order of bytes in the PTM Propagation Delay message, for compatibility with previous revisions

  wire    [11:0]        tx_latency;
  wire    [11:0]        rx_latency;
  reg     [13:0]        fm_tx_latency;
  reg     [13:0]        fm_rx_latency;
  
  logic   [11:0]        tx_latency_rd;
  logic   [11:0]        rx_latency_rd;
  
  wire    [7:0]         ptm_res_reg_07, ptm_res_reg_06, ptm_res_reg_05, ptm_res_reg_04;         //Vendor Specific header                 0x04
  wire    [7:0]         ptm_res_reg_11, ptm_res_reg_10, ptm_res_reg_09, ptm_res_reg_08;         //Control Register                       0x08
  wire    [7:0]         ptm_res_reg_15, ptm_res_reg_14, ptm_res_reg_13, ptm_res_reg_12;         //Status Register                        0x0C
  wire    [7:0]         ptm_res_reg_19, ptm_res_reg_18, ptm_res_reg_17, ptm_res_reg_16;         //Local Time [31:0]                      0x10   
  wire    [7:0]         ptm_res_reg_23, ptm_res_reg_22, ptm_res_reg_21, ptm_res_reg_20;         //Local Time [63:32]                     0x14
  wire    [7:0]         ptm_res_reg_27, ptm_res_reg_26, ptm_res_reg_25, ptm_res_reg_24;         //T1 TimeStamp [31:0]                    0x18
  wire    [7:0]         ptm_res_reg_31, ptm_res_reg_30, ptm_res_reg_29, ptm_res_reg_28;         //T1 TimeStamp [63:32]                   0x1C
  wire    [7:0]         ptm_res_reg_35, ptm_res_reg_34, ptm_res_reg_33, ptm_res_reg_32;         //T1 previous TimeStamp [31:0]           0x20
  wire    [7:0]         ptm_res_reg_39, ptm_res_reg_38, ptm_res_reg_37, ptm_res_reg_36;         //T1 previous TimeStamp [63:32]          0x24
  wire    [7:0]         ptm_res_reg_43, ptm_res_reg_42, ptm_res_reg_41, ptm_res_reg_40;         //T4 TimeStamp [31:0]                    0x28
  wire    [7:0]         ptm_res_reg_47, ptm_res_reg_46, ptm_res_reg_45, ptm_res_reg_44;         //T4 TimeStamp [63:32]                   0x2C
  wire    [7:0]         ptm_res_reg_51, ptm_res_reg_50, ptm_res_reg_49, ptm_res_reg_48;         //T4 previous TimeStamp [31:0]           0x30
  wire    [7:0]         ptm_res_reg_55, ptm_res_reg_54, ptm_res_reg_53, ptm_res_reg_52;         //T4 previous TimeStamp [63:32]          0x34
  wire    [7:0]         ptm_res_reg_79, ptm_res_reg_78, ptm_res_reg_77, ptm_res_reg_76;         //Tx Latency                             0x38
  wire    [7:0]         ptm_res_reg_83, ptm_res_reg_82, ptm_res_reg_81, ptm_res_reg_80;         //Rx Latency                             0x3C
  // Clock Scaling Registers
  wire    [7:0]         ptm_res_reg_95, ptm_res_reg_94, ptm_res_reg_93, ptm_res_reg_92;         //PTM Nominal Clock Period               0x40
  wire    [7:0]         ptm_res_reg_99, ptm_res_reg_98, ptm_res_reg_97, ptm_res_reg_96;         //PTM Scaled Clock Period                0x44

  wire    [7:0]         ptm_res_reg_103, ptm_res_reg_102, ptm_res_reg_101, ptm_res_reg_100;     //PTM Responder Latency Register Select 0x48

  reg    [3:0]          ptm_res_latency_reg_sel;                                                // Latency Register Select
  reg                   ptm_res_esm_sel;    


  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      t2_pending   <= #TP 0;

    end else if (rdlh_ptm_sot) begin       //latch pending time even if PTM not enabled
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: t2_pending wraps around after 2^64 ns
      t2_pending   <= #TP local_clk + ptm_clock_period[7+WF:WF] - rx_latency;
      // spyglass enable_block W164a

    end
  end


  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      t2_now        <= #TP 0;
      t2_previous   <= #TP 0;

    end else if (rdlh_ptm_request && cfg_ptm_enabled) begin           //sot and ptm msg in same cycle
      t2_previous   <= #TP t2_now;
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: t2_now wraps around after 2^64 ns
      t2_now        <= #TP (rdlh_ptm_sot && !rdlh_ptm_multi_cycle)                   ? local_clk + ptm_clock_period[7+WF:WF] - rx_latency : 
                           (!rdlh_ptm_sot || (rdlh_ptm_sot && rdlh_ptm_multi_cycle)) ? t2_pending                                :
                           t2_now;
      // spyglass enable_block W164a
    
    end
  end


  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      t2_previous_d <= #TP 0;

    end else if (rdlh_ptm_request && cfg_ptm_enabled) begin
      t2_previous_d <= #TP 1;

    end else begin
      t2_previous_d <= #TP 0;

    end
  end
  


  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      t3_pending        <= #TP 0;

    end else if (xdlh_ptm_sot) begin        //latch pending time even if PTM not enabled
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: t3_pending wraps around after 2^64 ns
      t3_pending        <= #TP local_clk + ptm_clock_period[7+WF:WF] + tx_latency;
      // spyglass enable_block W164a

    end
  end


  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      t3_now        <= #TP 0;
      t3_previous   <= #TP 0;     //t3_previous is not directly used in any calculation
      
    end else if (xdlh_ptm_response && cfg_ptm_enabled) begin          //sot and ptm msg in same cycle
      t3_previous <= #TP (((t3_now != t3_pending) && xdlh_ptm_multi_cycle) || !xdlh_ptm_multi_cycle) ? t3_now : t3_previous;

      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: t3_now wraps around after 2^64 ns
      t3_now        <= #TP (xdlh_ptm_sot && !xdlh_ptm_multi_cycle)                   ? local_clk + ptm_clock_period[7+WF:WF] + tx_latency :
                           (!xdlh_ptm_sot || (xdlh_ptm_sot && xdlh_ptm_multi_cycle)) ? t3_pending                                :
                           t3_now;
      // spyglass enable_block W164a

    end
  end

  assign ptm_master_time  = t2_now;

  wire [31:0] t3_now_minus_t2_previous; 
  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ: t3_now always greater than t2_previous
  assign t3_now_minus_t2_previous = t3_now[31:0] - t2_previous[31:0];
  // spyglass enable_block W164a


  always@(posedge aux_clk or negedge sticky_rst_n) 
  begin 
    if(!sticky_rst_n) begin
      ptm_prop_delay  <= #TP 'h0;                     //using t3_now as t3_previous wont change until response is sent, but ptm_prop_delay is required in response D message  
    end else begin
      ptm_prop_delay  <= #TP t2_previous_d ? ptm_res_pdel_byte_rev ? t3_now_minus_t2_previous : {t3_now_minus_t2_previous[7:0],t3_now_minus_t2_previous[15:8],t3_now_minus_t2_previous[23:16],t3_now_minus_t2_previous[31:24]} : ptm_prop_delay;// byte order is incorrect in msg_formation.v, so reverse the byte order here unless compatibility mode is selected using ptm_res_pdel_byte_rev
    end
  end


// -----------------------------------------------------------------------------
// VSEC Ext Capability Header Register
// -----------------------------------------------------------------------------
// reg_id       - 0
// PCIE Offset      - `VSEC_PTR
// length           - 4 byte
// Cfig register    - ptm_res_reg_03, ptm_res_reg_02, ptm_res_reg_01, ptm_res_reg_00
// May be set from DBI side. Read Only from the Wire.
// -----------------------------------------------------------------------------
// Located in cdm.v


// -----------------------------------------------------------------------------
// PTM Responder Vendor Specific Register
// -----------------------------------------------------------------------------
// reg_id       - 1
// PCIE Offset      - `VSEC_PTR + 04h
// length           - 4 byte
// Cfig register    - ptm_res_reg_07, ptm_res_reg_06, ptm_res_reg_05, ptm_res_reg_04
// Depth is Read Only. Interrupt message num may be set from DBI side
// -----------------------------------------------------------------------------

localparam NVRES = 'd16;                                     //number of double word registers in responder vendor specific capability
localparam PTM_RESPONDER_LENGTH = 'h54;                      //number of bytes in responder vendor specific capability


  always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
      ptm_responder_id[15:0]      <= #TP `PCIE_PTM_RES_ID;
      ptm_responder_rev[3:0]      <= #TP `PCIE_PTM_RES_REV;
      ptm_responder_length[11:0]  <= #TP PTM_RESPONDER_LENGTH;

    end else begin
      ptm_responder_id[7:0]      <= #TP (reg_id[1] & write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0]   : ptm_responder_id[7:0];
      ptm_responder_id[15:8]     <= #TP (reg_id[1] & write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8]  : ptm_responder_id[15:8];
      ptm_responder_rev[3:0]     <= #TP (reg_id[1] & write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : ptm_responder_rev[3:0];
      ptm_responder_length[3:0]  <= #TP (reg_id[1] & write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[23:20] : ptm_responder_length[3:0];
      ptm_responder_length[11:4] <= #TP (reg_id[1] & write_pulse[3] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[31:24] : ptm_responder_length[11:4];
    end
  end


assign ptm_res_reg_07 = ptm_responder_length[11:4];
assign ptm_res_reg_06 = {ptm_responder_length[3:0], 
                         ptm_responder_rev[3:0]};    
assign ptm_res_reg_05 = ptm_responder_id[15:8];      
assign ptm_res_reg_04 = ptm_responder_id[7:0];


// -----------------------------------------------------------------------------
// PTM Responder Control
// -----------------------------------------------------------------------------
// reg_id       - 2
// PCIE Offset      - `VSEC_PTR + 08h
// length           - 8 byte
// Cfig register    - ptm_res_reg_11, ptm_res_reg_10, ptm_res_reg_09, ptm_res_reg_08
// DBI RW, RW from wire side
// -----------------------------------------------------------------------------

localparam CONTEXT_VALID_ON_RESET = 0;

always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        ptm_context_valid     <= #TP CONTEXT_VALID_ON_RESET; 

    end else begin
        // Read-Only registers, but writable through DBI
        ptm_context_valid     <= #TP  (ptm_clock_period_change | pm_sel_aux_clk)                ? 1'b0 : 
                                     (ptm_external_master_strobe & ptm_responder_rdy_to_validate) ? 1'b1 :                                   
                                     (reg_id[2] & write_pulse[0] & lbc_cdm_dbi) ? lbc_cdm_data[0] :
                                     ptm_context_valid;
    end
  end


always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        ptm_res_pdel_byte_rev   <= #TP 1'b0;       // Default PTM Propagation Delay Byte Reverse Disabled    
    end else begin
        ptm_res_pdel_byte_rev   <= #TP (reg_id[2] & write_pulse[0]) ? lbc_cdm_data[1] : ptm_res_pdel_byte_rev;
    end
end



assign ptm_res_reg_11 = 8'b0;
assign ptm_res_reg_10 = 8'b0;
assign ptm_res_reg_09 = 8'b0;
assign ptm_res_reg_08 = {6'b0,
                         ptm_res_pdel_byte_rev, // reverse order of bytes in the PTM Propagation Delay message, for compatibility with previous revisions
                         ptm_context_valid
                        };



// -----------------------------------------------------------------------------
// PTM Responder Status
// -----------------------------------------------------------------------------
// reg_id       - 3
// PCIE Offset      - `VSEC_PTR + 18h
// length           - 4 byte
// Cfig register    - ptm_res_reg_11, ptm_res_reg_10, ptm_res_reg_09, ptm_res_reg_08
// DBI Read and Write 1 to clear, Read Only from wire side
// -----------------------------------------------------------------------------
assign ptm_status_context_valid = ptm_context_valid;                     //shadow of control register context valid

assign ptm_res_reg_15 = 8'b0;
assign ptm_res_reg_14 = 8'b0;
assign ptm_res_reg_13 = 8'b0;
assign ptm_res_reg_12 = {6'b0,  
                         ptm_state_at_res_d,             //value comes from state machine, indicates that next message sent will be ResponseD
                         ptm_status_context_valid
                        };

// -----------------------------------------------------------------------------
// PTM Responder Times
// -----------------------------------------------------------------------------
// reg_id       - 4 to 13
// PCIE Offset  - `VSEC_PTR + 10h to `VSEC_PTR + 34h
// length       - 4 byte
// 
// DBI and Wire Read Only
// -----------------------------------------------------------------------------

assign {ptm_res_reg_19, ptm_res_reg_18, ptm_res_reg_17, ptm_res_reg_16} = local_clk[31:0];             // local time[31:0]
assign {ptm_res_reg_23, ptm_res_reg_22, ptm_res_reg_21, ptm_res_reg_20} = local_clk[63:32];              // local time[63:32]

assign {ptm_res_reg_27, ptm_res_reg_26, ptm_res_reg_25, ptm_res_reg_24} = t2_now[31:0];                // T2 Timestamp [31:0]
assign {ptm_res_reg_31, ptm_res_reg_30, ptm_res_reg_29, ptm_res_reg_28} = t2_now[63:32];                 //T2 TimeStamp [63:32]
assign {ptm_res_reg_35, ptm_res_reg_34, ptm_res_reg_33, ptm_res_reg_32} = t2_previous[31:0];           //T2 previous TimeStamp [31:0]
assign {ptm_res_reg_39, ptm_res_reg_38, ptm_res_reg_37, ptm_res_reg_36} = t2_previous[63:32];            //T2 previous TimeStamp [63:32]
assign {ptm_res_reg_43, ptm_res_reg_42, ptm_res_reg_41, ptm_res_reg_40} = t3_now[31:0];                //T3 TimeStamp [31:0]
assign {ptm_res_reg_47, ptm_res_reg_46, ptm_res_reg_45, ptm_res_reg_44} = t3_now[63:32];                 //T3 TimeStamp [63:32]
assign {ptm_res_reg_51, ptm_res_reg_50, ptm_res_reg_49, ptm_res_reg_48} = t3_previous[31:0];           //T3 previous TimeStamp [31:0]
assign {ptm_res_reg_55, ptm_res_reg_54, ptm_res_reg_53, ptm_res_reg_52} = t3_previous[63:32];            //T3 previous TimeStamp [63:32]

// -----------------------------------------------------------------------------
// PTM Responder Tx and RX latency viewport registers
// -----------------------------------------------------------------------------
// reg_id          - 14 to 15
// PCIE Offset     - `VSEC_PTR + 38h to `VSEC_PTR + 3ch
// length          - 4 byte
// Cfig register   - ptm_res_reg_79, ptm_res_reg_78, ptm_res_reg_77, ptm_res_reg_76
//                 - ptm_res_reg_83, ptm_res_reg_82, ptm_res_reg_81, ptm_res_reg_80
// DBI and Wire Read Only
// -----------------------------------------------------------------------------

// Tx and RX latency shadow registers
reg   [11:0] tx_latency_r [(NUM_SPEEDS-1):0], rx_latency_r [(NUM_SPEEDS-1):0];
wire  [4:0] ptm_res_latency_reg_index;

assign ptm_res_latency_reg_index = {1'b0, ptm_res_latency_reg_sel[3:0]};

always @( posedge aux_clk or negedge sticky_rst_n ) begin : proc_latency_regs
  integer i;
  if ( !sticky_rst_n ) begin
    for (i=0; i<(NUM_SPEEDS); i=i+1) begin
      tx_latency_r[i][11:0]     <= #TP `CX_PHY_TX_DELAY_PHY + `CX_PHY_TX_DELAY_MAC;    
      rx_latency_r[i][11:0]     <= #TP `CX_PHY_RX_DELAY_PHY + `CX_PHY_RX_DELAY_MAC;
    end
  end else begin
    for (i=0; i<(NUM_SPEEDS); i=i+1) begin
      tx_latency_r[i][7:0]        <= #TP (reg_id[14] & write_pulse[0] & (ptm_res_latency_reg_index == i)) ? lbc_cdm_data[7:0]    : tx_latency_r[i][7:0];
      tx_latency_r[i][11:8]       <= #TP (reg_id[14] & write_pulse[1] & (ptm_res_latency_reg_index == i)) ? lbc_cdm_data[11:8]   : tx_latency_r[i][11:8];

      rx_latency_r[i][7:0]        <= #TP (reg_id[15] & write_pulse[0] & (ptm_res_latency_reg_index == i)) ? lbc_cdm_data[7:0]    : rx_latency_r[i][7:0];
      rx_latency_r[i][11:8]       <= #TP (reg_id[15] & write_pulse[1] & (ptm_res_latency_reg_index == i)) ? lbc_cdm_data[11:8]   : rx_latency_r[i][11:8];
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
 tx_latency_rd[11:0] = tx_latency_r[ptm_res_latency_reg_index>=NUM_SPEEDS ? 0 : ptm_res_latency_reg_index[NUM_SPEEDS_WD-1:0]][11:0];
 rx_latency_rd[11:0] = rx_latency_r[ptm_res_latency_reg_index>=NUM_SPEEDS ? 0 : ptm_res_latency_reg_index[NUM_SPEEDS_WD-1:0]][11:0];
end

assign {ptm_res_reg_79, ptm_res_reg_78, ptm_res_reg_77, ptm_res_reg_76} = {20'b0, tx_latency_rd};
assign {ptm_res_reg_83, ptm_res_reg_82, ptm_res_reg_81, ptm_res_reg_80} = {20'b0, rx_latency_rd};

// -----------------------------------------------------------------------------
// PTM Responder Nominal and Scaled Clock Registers
// -----------------------------------------------------------------------------
// reg_id       - 16 to 17 
// PCIE Offset  - `VSEC_PTR + 40h to `VSEC_PTR + 44h
// length       - 4 byte
// 
// DBI and Wire Read Only
// -----------------------------------------------------------------------------

assign {ptm_res_reg_95, ptm_res_reg_94, ptm_res_reg_93, ptm_res_reg_92} = {{(32-(8+WF)){1'b0}}, ptm_nom_clock_period};

always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        ptm_scaled_clock_period      <= #TP 0;    
        ptm_scaled_clock_period_en   <= #TP 0;
    end else begin
        ptm_scaled_clock_period[7:0]        <= #TP (reg_id[17] & write_pulse[0]) ? lbc_cdm_data[7:0]        : ptm_scaled_clock_period[7:0];
        ptm_scaled_clock_period[15:8]       <= #TP (reg_id[17] & write_pulse[1]) ? lbc_cdm_data[15:8]       : ptm_scaled_clock_period[15:8];
        ptm_scaled_clock_period[23:16]      <= #TP (reg_id[17] & write_pulse[2]) ? lbc_cdm_data[23:16]      : ptm_scaled_clock_period[23:16];
        ptm_scaled_clock_period_en          <= #TP ptm_clock_period_change ? 0 : ((reg_id[17] & write_pulse[3]) ? lbc_cdm_data[31] : ptm_scaled_clock_period_en);
    end
end

assign {ptm_res_reg_99, ptm_res_reg_98, ptm_res_reg_97, ptm_res_reg_96} = {ptm_scaled_clock_period_en, {(32-(8+WF+1)){1'b0}}, ptm_scaled_clock_period};

// -----------------------------------------------------------------------------
// PTM Responder Latency Register Select Register
// -----------------------------------------------------------------------------
// reg_id       - 18
// PCIE Offset  - `VSEC_PTR + 48h
// length       - 4 byte
// 
// DBI and Wire Read Only
// -----------------------------------------------------------------------------

always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
        ptm_res_latency_reg_sel <= #TP 0;    
     end else begin
        ptm_res_latency_reg_sel[3:0]        <= #TP (reg_id[18] & write_pulse[0]) ? lbc_cdm_data[3:0]        : ptm_res_latency_reg_sel[3:0];
     end
end

  assign {ptm_res_reg_103, ptm_res_reg_102, ptm_res_reg_101, ptm_res_reg_100} = {24'b0, 4'b0, ptm_res_latency_reg_sel};


// =============================================================================
// Register Read Operation
// =============================================================================


always @( * ) begin : ptm_res_read_data_PROC
    ptm_res_reg_data[31:0] = 0;
    
//  (reg_id[0]) // in cdm.v
  
    if (reg_id[1]) begin
        ptm_res_reg_data = {ptm_res_reg_07, ptm_res_reg_06, ptm_res_reg_05, ptm_res_reg_04};       // read Vendor Specific Capbilities register
    end else if (reg_id[2]) begin
        ptm_res_reg_data = {ptm_res_reg_11, ptm_res_reg_10, ptm_res_reg_09, ptm_res_reg_08};       // control
    end else if (reg_id[3]) begin
        ptm_res_reg_data = {ptm_res_reg_15, ptm_res_reg_14, ptm_res_reg_13, ptm_res_reg_12};        // status
    end else if (reg_id[4]) begin
        ptm_res_reg_data = {ptm_res_reg_19, ptm_res_reg_18, ptm_res_reg_17, ptm_res_reg_16};        // local time[31:0]
    end else if (reg_id[5]) begin
        ptm_res_reg_data = {ptm_res_reg_23, ptm_res_reg_22, ptm_res_reg_21, ptm_res_reg_20};        // local time[63:32]
    end else if (reg_id[6]) begin
        ptm_res_reg_data = {ptm_res_reg_27, ptm_res_reg_26, ptm_res_reg_25, ptm_res_reg_24};        // T2 Timestamp [31:0]
    end else if (reg_id[7]) begin
        ptm_res_reg_data = {ptm_res_reg_31, ptm_res_reg_30, ptm_res_reg_29, ptm_res_reg_28};         //T2 TimeStamp [63:32]
    end else if (reg_id[8]) begin
        ptm_res_reg_data = {ptm_res_reg_35, ptm_res_reg_34, ptm_res_reg_33, ptm_res_reg_32};         //T2 previous TimeStamp [31:0]
    end else if (reg_id[9]) begin
        ptm_res_reg_data = {ptm_res_reg_39, ptm_res_reg_38, ptm_res_reg_37, ptm_res_reg_36};         //T2 previous TimeStamp [63:32]
    end else if (reg_id[10]) begin
        ptm_res_reg_data = {ptm_res_reg_43, ptm_res_reg_42, ptm_res_reg_41, ptm_res_reg_40};         //T3 TimeStamp [31:0]
    end else if (reg_id[11]) begin
        ptm_res_reg_data = {ptm_res_reg_47, ptm_res_reg_46, ptm_res_reg_45, ptm_res_reg_44};         //T3 TimeStamp [63:32]
    end else if (reg_id[12]) begin
        ptm_res_reg_data = {ptm_res_reg_51, ptm_res_reg_50, ptm_res_reg_49, ptm_res_reg_48};         //T3 previous TimeStamp [31:0]
    end else if (reg_id[13]) begin
        ptm_res_reg_data = {ptm_res_reg_55, ptm_res_reg_54, ptm_res_reg_53, ptm_res_reg_52};         //T3 previous TimeStamp [63:32]
    end else if (reg_id[14]) begin
        ptm_res_reg_data = {ptm_res_reg_79, ptm_res_reg_78, ptm_res_reg_77, ptm_res_reg_76};         //Tx Latency
    end else if (reg_id[15]) begin
        ptm_res_reg_data = {ptm_res_reg_83, ptm_res_reg_82, ptm_res_reg_81, ptm_res_reg_80};         //Rx Latency
    end else if (reg_id[16]) begin
        ptm_res_reg_data = {ptm_res_reg_95, ptm_res_reg_94, ptm_res_reg_93, ptm_res_reg_92};         //PTM Nominal Clock Period
    end else if (reg_id[17]) begin
        ptm_res_reg_data = {ptm_res_reg_99, ptm_res_reg_98, ptm_res_reg_97, ptm_res_reg_96};         //PTM Scaled Clock Period
    end else if (reg_id[18]) begin
        ptm_res_reg_data = {ptm_res_reg_103, ptm_res_reg_102, ptm_res_reg_101, ptm_res_reg_100};         //PTM Scaled Clock Period
    end
end //always ptm_res_read_data_PROC


endmodule //ptm_responder_reg 
