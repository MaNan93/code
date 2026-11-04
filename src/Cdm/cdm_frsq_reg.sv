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
// ---    $DateTime: 2023/06/26 08:32:07 $
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_frsq_reg.sv#10 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the FRS Queuing Extended Capability (FRSQ) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------



//`define DEBUGQ


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

 
 module cdm_frsq_reg
 import DWC_pcie_ctl_pkg::MSG_TLP_WD;
#(
    parameter INST              = 0,                                // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM          = 0                                 // uniquifying parameter per function
    ,parameter NFRSQ            = 4                                 // Max possible number of registers in FRSQ Extended Capability Structure (3)
    ,parameter TP               = `TP     
    ,parameter NF               = `CX_NFUNC
    ,parameter FX_TLP           = MSG_TLP_WD                        // Number of TLPs received in a single cycle after formation block
    ,parameter FRS_REASON_SIZE  = 4
    ,parameter FRS_ID_SIZE      = 16 
    ,parameter FRSQ_WIDTH       = (FRS_REASON_SIZE + FRS_ID_SIZE)
    ,parameter FRSQ_MAX_DEPTH   = `CX_RN_FRS_QUEUE_MAX_DEPTH
   )

  
                     (
  input                                   core_clk,
  input                                   non_sticky_rst_n,
  input                                   sticky_rst_n,
  input                                   cdm_clk_g,                   // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
  input [31:0]                            lbc_cdm_data,                // Write Data 
  input                                   lbc_cdm_dbi,                // DBI Access
  input                                   dbi_ro_wr_en,                // used to make RW registers look like RO for compliance
  input [3:0]                             frsq_write_pulse,             // Write Byte Enables
  input [NFRSQ-1:0]                       frsq_reg_id,                  // FRSQ Register ID

  input [2:0]                             cfg_downstream_comp_pres,  
  input [4:0]                             cfg_pbus_dev_num,             // Device number
  input [7:0]                             cfg_pbus_num,                   // Bus number

  input [(FX_TLP*FRS_REASON_SIZE) - 1:0]  radm_frs_msg_reason,
  input [(FX_TLP*FRS_ID_SIZE) - 1:0]      radm_msg_req_id,
  input [FX_TLP-1:0]                      radm_frs_msg,         //signal is a pulse from radm
  input                                   pmstate_d3hot_to_d0,

  input                                   cfg_drs_frs_sig_en,    
  input  [FX_TLP-1:0]                     radm_drs_msg,
  input                                   cfg_msi_en,  
  input                                   cfg_msix_en,  
  input                                   upstream_port,        // Device is Upstream Port (EP/SW_UP)
  input                                   rdlh_link_up,         // Data Link Layer = DL_Active 

  output reg                              frsq_msi,                         // MSI or MSI-X pulse
  output reg [4:0]                        frsq_int_msg_num,                 // FRSQ Interrupt vector

  output reg [31:0]                       frsq_reg_data  // FRSQ Register Read Data
  
  );

  localparam NL                     = `CX_NL;
  localparam FREQ                   = `CX_FREQ;
  localparam DRS_REC_REASON         = 4'b0001;      //reason when DRS message received   
  localparam D3HOT_TO_D0_COMP       = 4'b0010;
  localparam ADDR_WIDTH             = $clog2(`CX_RN_FRS_QUEUE_MAX_DEPTH);           //log base 2 of depth
  localparam FRSQ_MAX_DEPTH_MINUS1  = (`CX_RN_FRS_QUEUE_MAX_DEPTH - 1);



// -------------- Internal Signals --------------
  reg [ADDR_WIDTH - 1:0]                  wr_ptr; 
  reg [ADDR_WIDTH - 1:0]                  rd_ptr; 
  reg                                     frsq_msg_received_reg;
  reg                                     frsq_overflow_reg;
  reg [11:0]                              frsq_depth; 
  reg [2:0]                               msi_state;
  reg                                     frsq_int_enable;
  
  reg [FRSQ_MAX_DEPTH - 1:0][FRSQ_WIDTH-1:0] frsq ;      //the actual frsq registers
  reg [FRSQ_MAX_DEPTH - 1:0][FRSQ_WIDTH-1:0] frsq_s ;    //copied combinational version of array
  reg [ADDR_WIDTH - 1:0]                     frsq_index_sel;
  wire                                    datalink_up;     //downstream component prescence Link Up

  reg     [15:0]        cfg_frsq_id;                                     // Capability ID
  reg     [3:0]         cfg_frsq_ver;                                    // Capability Version
  reg     [11:0]        cfg_frsq_next_ptr;                               // Next Capability Offset
     
  wire    [7:0]         frsq_reg_03, frsq_reg_02, frsq_reg_01, frsq_reg_00;
  wire    [7:0]         frsq_reg_07, frsq_reg_06, frsq_reg_05, frsq_reg_04;
  wire    [7:0]         frsq_reg_11, frsq_reg_10, frsq_reg_09, frsq_reg_08;
  wire    [7:0]         frsq_reg_15, frsq_reg_14, frsq_reg_13, frsq_reg_12;
   

localparam INT_FRSQ_NEXT_PTR  = `DM_RP_FRSQ_NEXT_PTR;   
localparam FRS_INT_MSG_NUM    = `CX_RN_FRS_INT_MSG_NUM;

// finish of internal signals
 

  assign datalink_up = (FUNC_NUM == 0 && (cfg_downstream_comp_pres==3'b100 | cfg_downstream_comp_pres==3'b101));  //link is up only for 3'b100 or 3'b101
    
  wire frsq_pop;
  assign frsq_pop         = (frsq_reg_id[3] & frsq_write_pulse[0] & lbc_cdm_dbi);


  ////////////////////////////////
  //
  //   D3 hot to D0 Completed state machine
  //
  /////////////////////////////////////////

  reg [1:0] d3hot_d0_state;
  wire push_d3hot_to_d0;
  localparam NOT_COMPLETE     = 2'b00;
  localparam WAIT_FOR_ACCESS  = 2'b01;
  localparam WRITE_TO_FRSQ    = 2'b10;

  always@(posedge core_clk or negedge non_sticky_rst_n) 
  begin 
    if(!non_sticky_rst_n) begin
      d3hot_d0_state <= #TP NOT_COMPLETE;         
    end else if(!datalink_up) begin
      d3hot_d0_state <= #TP NOT_COMPLETE;         
    end else begin
      // spyglass disable_block STARC05-2.11.3.1
      // SMD: Combinational and sequential parts of an FSM described in same always block 
      // SJ: Legacy code
      case (d3hot_d0_state[1:0])

        NOT_COMPLETE: 
          if(pmstate_d3hot_to_d0 && radm_frs_msg[FX_TLP-1:0]==0 && radm_drs_msg[FX_TLP-1:0]==0)
            d3hot_d0_state <= #TP WRITE_TO_FRSQ;
          else if(pmstate_d3hot_to_d0)               // transition from D3 hot to D0 complete
            d3hot_d0_state <= #TP WAIT_FOR_ACCESS;        

        WAIT_FOR_ACCESS:                           // wait for no Wire messages recieved
          if(radm_frs_msg[FX_TLP-1:0]==0 && radm_drs_msg[FX_TLP-1:0]==0)    
            d3hot_d0_state <= #TP WRITE_TO_FRSQ;       

        WRITE_TO_FRSQ:     
          if(radm_frs_msg[FX_TLP-1:0]>0 || radm_drs_msg[FX_TLP-1:0]>0)// one pulse,  move to next stage at next cycle
            d3hot_d0_state   <= #TP WAIT_FOR_ACCESS;
          else if (radm_frs_msg[FX_TLP-1:0]==0 && radm_drs_msg[FX_TLP-1:0]==0)
            d3hot_d0_state   <= #TP NOT_COMPLETE;

          default
            d3hot_d0_state <= #TP d3hot_d0_state;
      endcase
      // spyglass enable_block STARC05-2.11.3.1
    end // before case
  end 

  assign push_d3hot_to_d0 = (d3hot_d0_state[1:0] == WRITE_TO_FRSQ) && (radm_frs_msg[FX_TLP-1:0]==0 && radm_drs_msg[FX_TLP-1:0]==0);
  

  //////////////////////////////////////////////////////
  //
  //  MSI Intterupt pulse state machine
  //
  //////////////////////////////////////////////////////
  localparam RESET          = 3'b000;       //Reset
  localparam WAIT_MESSAGE   = 3'b001;       //Waiting for a message
  localparam MESSAGE_REC    = 3'b011;       //Message receieved
  localparam WAIT_OVERFLOW  = 3'b111;       //waiting for an overflow
  localparam OVERFLOW_REC   = 3'b110;       //Overflow received
  localparam WAIT_CLEAR     = 3'b100;       //wait for clearing of either bit


  always@(posedge core_clk or negedge non_sticky_rst_n) 
  begin : ProcState
    if(!non_sticky_rst_n) begin
      msi_state <= #TP RESET;         
    end else if(!datalink_up) begin
      msi_state <= #TP RESET;         
    end else begin
      // spyglass disable_block STARC05-2.11.3.1
      // SMD: Combinational and sequential parts of an FSM described in same always block 
      // SJ: Legacy code
      case (msi_state[2:0])

        RESET:        
          msi_state <= #TP WAIT_MESSAGE;        // move to WAIT_MESSAGE at first cycle

        WAIT_MESSAGE:                           // wait for message to be received
          if(frsq_msg_received_reg && frsq_overflow_reg)    //if we are returning here after clearing message received but with overflow still set
            msi_state <= #TP OVERFLOW_REC;     // create only one pulse  
          else if(frsq_msg_received_reg && !frsq_overflow_reg)
            msi_state <= #TP MESSAGE_REC;
          else
            msi_state <= #TP WAIT_MESSAGE;

        MESSAGE_REC:                          // move to next stage at next cycle
          msi_state <= #TP WAIT_OVERFLOW;

        WAIT_OVERFLOW:                        // wait for overflow condition to be set
          if(frsq_overflow_reg)
            msi_state <= #TP OVERFLOW_REC;
          else if(!frsq_msg_received_reg)
            msi_state <= #TP WAIT_MESSAGE;
          else
            msi_state <= #TP WAIT_OVERFLOW;

        OVERFLOW_REC:                          // move to next stage at next cycle
          msi_state <= #TP WAIT_CLEAR;

        WAIT_CLEAR:                           // both message and overflows received, wait for a clear of either bits
          if(!frsq_msg_received_reg)
            msi_state <= #TP WAIT_MESSAGE;
          else if(!frsq_overflow_reg)
            msi_state <= #TP WAIT_OVERFLOW;
          else
            msi_state <= #TP WAIT_CLEAR;

          default
            msi_state <= #TP RESET;
      endcase
      // spyglass enable_block STARC05-2.11.3.1
    end // before case
  end   // ProcState


  always@(posedge core_clk or negedge non_sticky_rst_n)     // create frsq_msi pulse
  begin
    if(!non_sticky_rst_n)
      frsq_msi <= #TP 1'b0;
    else
      frsq_msi <= #TP ((cfg_msi_en || cfg_msix_en) && frsq_int_enable && (msi_state==OVERFLOW_REC || msi_state==MESSAGE_REC));
  end
 


  //////////////////////////////////////////////////////
  //
  //  Start of Q logic 
  //
  //////////////////////////////////////////////////////
  
  //  Q registers, wires and assignments
  
  wire [(FX_TLP-1):0]               Q_msg;
  wire [((FX_TLP*4)-1):0]           Q_reason;
  wire [((FX_TLP*16)-1):0]          Q_reqID;
  wire [((FX_TLP*FRSQ_WIDTH)-1):0]  Q_msg_payload;


  genvar m;                       //set message received signal, reason signal and payload for each channel 0 to (FX_TLP-1)
  generate
    for(m=0;m<FX_TLP;m=m+1) begin : gen_Q_msg
      assign Q_msg[m]         = (radm_frs_msg[m]) ? 1'b1 : 
                                (radm_drs_msg[m] && cfg_drs_frs_sig_en && (FUNC_NUM==0)) ? 1'b1 : 
                                (push_d3hot_to_d0 && m==0) ? 1'b1 : 1'b0;

      assign Q_reason[m*4+:4] = (radm_frs_msg[m]) ? radm_frs_msg_reason[m*4+:4] : 
                                (radm_drs_msg[m] && cfg_drs_frs_sig_en && (FUNC_NUM==0)) ? DRS_REC_REASON : 
                                (push_d3hot_to_d0 && m==0) ? D3HOT_TO_D0_COMP : 4'h0;

      assign Q_reqID[m*16+:16] = (radm_frs_msg[m]) ? radm_msg_req_id[m*16+:16] :
                                 ((radm_drs_msg[m] && cfg_drs_frs_sig_en && (FUNC_NUM==0)) || (push_d3hot_to_d0 && m==0)) ? 
                                                                                      {cfg_pbus_num[7:0], cfg_pbus_dev_num[4:0], 3'b0} : 16'h0;

      //assign Q_reqID[m*16+:16] = radm_msg_req_id[m*16+:16];   //incorrect to allow for UTB testing
                                


      if(m==0 && FX_TLP>1) begin : gen_Q_msg_payload
        assign Q_msg_payload[19:0] = !Q_msg[0] ? {Q_reason[(m+1)*4+:4], Q_reqID[(m+1)*16+:16]} :  
                                     {Q_reason[m*4+:4], Q_reqID[m*16+:16]};
      end else begin : gen_Q_msg_payload
        assign Q_msg_payload[m*20+:20] = {Q_reason[m*4+:4], Q_reqID[m*16+:16]};
      end
    end
  endgenerate
   


  reg     [ADDR_WIDTH:0]    wr_addr;
  reg     [ADDR_WIDTH:0]    rd_addr;
  reg     [2:0]             frs_msg_count;
  wire    [1:0]             writes_allowed;
  wire    [ADDR_WIDTH:0]    frsq_remaining;
  
  assign Q_empty                  = (wr_addr == rd_addr);
  assign Q_full                   = (wr_addr[ADDR_WIDTH-1:0] == rd_addr[ADDR_WIDTH-1:0]) && (wr_addr[ADDR_WIDTH] != rd_addr[ADDR_WIDTH]);
  
  assign wr_ptr                   = wr_addr[ADDR_WIDTH-1:0];
  assign rd_ptr                   = rd_addr[ADDR_WIDTH-1:0];
  
  if(ADDR_WIDTH<11) begin : gen_frsq_depth_msbs
    assign frsq_depth[11:ADDR_WIDTH+1] = 0;
  end
  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ: The MUX selection (rd_addr > wr_addr) takes care of the sign bit. also the remaining bits of frsq_depth are set to zeroes in the gen_frsq_depth_msbs in case of ADDR_WIDTH<11.
  assign frsq_depth[ADDR_WIDTH:0] = (rd_addr > wr_addr) ? (~rd_addr + wr_addr + 1) : (wr_addr - rd_addr);
  // spyglass enable_block W164a
  
  assign frsq_remaining           = (FRSQ_MAX_DEPTH-frsq_depth);
  
  assign writes_allowed           = ((Q_msg[FX_TLP-1:0]=={FX_TLP{1'b1}} && frsq_remaining>=2 && FX_TLP==2) ||
                                     (Q_msg[FX_TLP-1:0]=={FX_TLP{1'b1}} && frsq_remaining==1 && frsq_pop && FX_TLP==2)) ? 2 :
                                    ((^Q_msg && frsq_remaining>=1) || 
                                     (Q_msg[FX_TLP-1:0]=={FX_TLP{1'b1}} && frsq_remaining==1) ||
                                     (Q_msg[FX_TLP-1:0]=={FX_TLP{1'b1}} && frsq_remaining==0 && frsq_pop) || 
                                     (^Q_msg && frsq_remaining==0 && frsq_pop) ) ? 1 : 0;
  

  always@(*)          // count the number of FRS messages recieved
  begin
  integer c; 
      frs_msg_count = 0; 
  
      for(c=0;c<FX_TLP;c=c+1) begin
        // spyglass disable_block W164a
        // SMD: Identifies assignments in which the LHS width is less than the RHS width
        // SJ: frs_msg_count is 3 bits, Q_msg is 2 bits (FX_TLP), so this is OK for
        // FX_TLP up to a maximum of 2, since 2^FX_TLP-1 * FX_TLP = 3 * 2 < 2^3-1
        frs_msg_count = frs_msg_count + Q_msg[c];
        // spyglass enable_block W164a
      end
  end


  
  always@(posedge core_clk or negedge non_sticky_rst_n)
  begin : WR_ADDR
   
    if(!non_sticky_rst_n) begin
      wr_addr              <= #TP 0;
    end else if(!datalink_up) begin     //FRSQ must empty on datalink down, when depth is zero Q values are undefined
      wr_addr              <= #TP 0;

    end else begin
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: wr_addr wraps around
      wr_addr <= #TP wr_addr + writes_allowed; 
      // spyglass enable_block W164a
    end // end else begin
  end // WR_ADDR


  always@(*)
  begin : FRS_QUEUE_WRITE_DATA
  integer q;
  reg [ADDR_WIDTH-1:0] q_index;
    // Read from the register bank
    frsq_s = frsq; 
    for(q=0;q<FX_TLP;q=q+1) begin
      q_index = q;
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: wr_addr wraps around
      frsq_index_sel = wr_ptr + q_index;
      // spyglass enable_block W164a
      frsq_s[frsq_index_sel] = (writes_allowed>=(q+1)) ? Q_msg_payload[q*FRSQ_WIDTH+:FRSQ_WIDTH] : frsq[frsq_index_sel];
    end // for 

  end // FRS_QUEUE_WRITE_DATA

  always@(posedge core_clk or negedge non_sticky_rst_n)
  begin : FRS_QUEUE_REG
  
    if(!non_sticky_rst_n) begin
        frsq    <= #TP 0;       // clear out the queue data
    end else begin
        frsq <= #TP frsq_s;
    end // FRS_QUEUE_WRITE_DATA
  end


  always@(posedge core_clk or negedge non_sticky_rst_n)
  begin
    if(!non_sticky_rst_n) 
      rd_addr <= #TP 0;

    else if(!datalink_up)      //in root port, FRSQ must empty on datalink down
      rd_addr <= #TP 0;

    else if(frsq_pop && !Q_empty) begin
      if (rd_ptr == (FRSQ_MAX_DEPTH_MINUS1)) begin
          rd_addr[ADDR_WIDTH-1:0] <= #TP 0;
          rd_addr[ADDR_WIDTH]     <= #TP ~rd_addr[ADDR_WIDTH];
      end else begin
          rd_addr                 <= #TP rd_addr + 1;
      end
    end

  end // rd_ptr
 

  
// -------------------------------------
// finish of Queue logic
// -------------------------------------



// -----------------------------------------------------------------------------
// FRSQ Ext Capability Header Register
// -----------------------------------------------------------------------------
// frsq_reg_id       - 0
// PCIE Offset      - `FRSQ_PTR
// length           - 4 byte
// Cfig register    - frsq_reg_03, frsq_reg_02, frsq_reg_01, frsq_reg_00
// May be set from DBI side. Read Only from the Wire.
// -----------------------------------------------------------------------------



always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : frsq_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_frsq_id[15:0]       <= #TP `PCIE_FRSQ_ECAP_ID;    
        cfg_frsq_ver[3:0]       <= #TP `PCIE_FRSQ_ECAP_VER;   
        cfg_frsq_next_ptr[11:0] <= #TP INT_FRSQ_NEXT_PTR;
    end else begin
        // Read-Only registers, but writable through DBI
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_frsq_id[7:0]        <= #TP (frsq_reg_id[0] & frsq_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0]    : cfg_frsq_id[7:0];
        cfg_frsq_id[15:8]       <= #TP (frsq_reg_id[0] & frsq_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8]   : cfg_frsq_id[15:8];
        cfg_frsq_ver[3:0]       <= #TP (frsq_reg_id[0] & frsq_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16]  : cfg_frsq_ver[3:0];
        cfg_frsq_next_ptr[3:0]  <= #TP (frsq_reg_id[0] & frsq_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[23:20]
                                    : cfg_frsq_next_ptr[3:0];
        cfg_frsq_next_ptr[11:4] <= #TP (frsq_reg_id[0] & frsq_write_pulse[3] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[31:24] 
                                    : cfg_frsq_next_ptr[11:4];
    end
end //always frsq_cap_hdr_PROC

assign {frsq_reg_01, frsq_reg_00}      = cfg_frsq_id;
assign frsq_reg_02[3:0]                = cfg_frsq_ver;
assign {frsq_reg_03, frsq_reg_02[7:4]} = cfg_frsq_next_ptr;



// -----------------------------------------------------------------------------
// FRSQ Capabilities Register
// -----------------------------------------------------------------------------
// frsq_reg_id       - 1
// PCIE Offset      - `FRSQ_PTR + 04h
// length           - 4 byte
// Cfig register    - frsq_reg_07, frsq_reg_06, frsq_reg_05, frsq_reg_04
// Depth is Read Only. Interrupt message num may be set from DBI side
// -----------------------------------------------------------------------------

  wire [11:0] cfg_frsq_max_depth;

  assign cfg_frsq_max_depth = FRSQ_MAX_DEPTH;       //depth is RO


always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : frsq_int_msg_num_PROC
    if ( !sticky_rst_n ) begin
      frsq_int_msg_num  <= #TP FRS_INT_MSG_NUM;        
    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      frsq_int_msg_num  <= #TP (frsq_reg_id[1] & frsq_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[20:16] : frsq_int_msg_num;    
    end
end  //always frsq_int_msg_num_PROC


assign frsq_reg_07 = 8'b0;
assign frsq_reg_06 = {3'b0, frsq_int_msg_num};       
assign frsq_reg_05 = {4'b0, cfg_frsq_max_depth[11:8]};      
assign frsq_reg_04 = {cfg_frsq_max_depth[7:0]};


// -----------------------------------------------------------------------------
// FRSQ Register 2
// -----------------------------------------------------------------------------
// frsq_reg_id       - 2
// PCIE Offset      - `FRSQ_PTR + 08h
// length           - 4 byte
// Cfig register    - frsq_reg_11, frsq_reg_10, frsq_reg_09, frsq_reg_08
// DBI Read and Write 1 to clear, Read Only from wire side
// -----------------------------------------------------------------------------


always @( posedge core_clk or negedge non_sticky_rst_n ) begin : frs_overflow_PROC
  if ( !non_sticky_rst_n ) begin
    frsq_overflow_reg      <= #TP 1'b0;      // RW1C
  end else if (!upstream_port && !rdlh_link_up) begin
    frsq_overflow_reg      <= #TP 1'b0; 
  end else if({1'b0,writes_allowed}<frs_msg_count) begin       //for_loop_overflow) begin
    frsq_overflow_reg      <= #TP 1'b1;
  end else begin
    frsq_overflow_reg      <= #TP (!datalink_up || (frsq_reg_id[2] & frsq_write_pulse[0] & lbc_cdm_dbi & lbc_cdm_data[1])) ? 1'b0 : frsq_overflow_reg; //RW1C
  end
end //always frs_overflow_PROC



always @( posedge core_clk or negedge non_sticky_rst_n ) begin : frsq_msg_rec_PROC
  if ( !non_sticky_rst_n ) begin
    frsq_msg_received_reg  <= #TP 1'b0;      // RW1C

  end else if (!upstream_port && !rdlh_link_up) begin
    frsq_msg_received_reg  <= #TP 1'b0; 

  end else if((radm_frs_msg[FX_TLP-1:0] > 0) ||       //received by Q
              ((radm_drs_msg[FX_TLP-1:0] > 0) && cfg_drs_frs_sig_en && (FUNC_NUM==0)) ||      //generated by Q
              (push_d3hot_to_d0)) begin           //generated by Q
    frsq_msg_received_reg  <= #TP 1'b1;

  end else begin
    frsq_msg_received_reg  <= #TP (!datalink_up || (frsq_reg_id[2] & frsq_write_pulse[0] & lbc_cdm_dbi & lbc_cdm_data[0])) ? 1'b0  : frsq_msg_received_reg; //RW1C

  end
end //always frsq_msg_rec_PROC



always @( posedge core_clk or negedge non_sticky_rst_n ) begin : frsq_int_en_PROC
  if ( !non_sticky_rst_n ) begin
    frsq_int_enable        <= #TP 1'b0;
  end else begin
    frsq_int_enable        <= #TP (frsq_reg_id[2] & frsq_write_pulse[2]) ? lbc_cdm_data[16] : frsq_int_enable;    //RW over DBI or Wire
  end
end //always frsq_int_en_PROC


assign frsq_reg_11 = 8'b0;
assign frsq_reg_10 = {7'b0, frsq_int_enable};
assign frsq_reg_09 = 8'b0;
assign frsq_reg_08 = {6'b0, frsq_overflow_reg, frsq_msg_received_reg};



// -----------------------------------------------------------------------------
// FRS Message Queue Register 
// -----------------------------------------------------------------------------
// frsq_reg_id       - 2
// PCIE Offset      - `FRSQ_PTR + 0Ch
// length           - 4 byte
// Cfig register    - frsq_reg_15, frsq_reg_14, frsq_reg_13, frsq_reg_12
// Read Only from Wire and DBI.
// -----------------------------------------------------------------------------


assign frsq_reg_15      = frsq_depth[11:4];
assign frsq_reg_14[7:4] = frsq_depth[3:0];
assign frsq_reg_14[3:0] = (frsq_depth[11:0] > 0) ? frsq[rd_ptr][19:16]            : 4'b0;      // FRS msg reason is bits 19:16
assign frsq_reg_13      = (frsq_depth[11:0] > 0) ? frsq[rd_ptr][FRS_ID_SIZE-1:8]  : 8'b0;               // FRS msg id is bits 15:0
assign frsq_reg_12      = (frsq_depth[11:0] > 0) ? frsq[rd_ptr][7:0]              : 8'b0;

// =============================================================================
// Register Read Operation
// =============================================================================


always @( * ) begin : frsq_read_data_PROC
    frsq_reg_data[31:0] = 0;
    
    if (frsq_reg_id[0])   begin
        frsq_reg_data = {frsq_reg_03, frsq_reg_02, frsq_reg_01, frsq_reg_00};  // read Header register
    end else if (frsq_reg_id[1]) begin
        frsq_reg_data = {frsq_reg_07, frsq_reg_06, frsq_reg_05, frsq_reg_04};  // read FRS Queuing Capbilities register
    end else if (frsq_reg_id[2]) begin
        frsq_reg_data = {frsq_reg_11, frsq_reg_10, frsq_reg_09, frsq_reg_08};  // read FRS Queuing Control and Status Register
    end else begin
        frsq_reg_data = {frsq_reg_15, frsq_reg_14, frsq_reg_13, frsq_reg_12};  // read FRS Message Queue register
    end       
end //always frsq_read_data_PROC



endmodule //cdm_frsq_reg 
