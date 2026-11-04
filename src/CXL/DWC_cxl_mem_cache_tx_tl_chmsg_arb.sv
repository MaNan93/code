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
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_tx_tl_chmsg_arb.sv#5 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Transaction Layer Message Channel Arbitration
//
// Description: This module arbitrates between channels driven from 2 unrelated interfaces 
// like D2H Request and H2D Response channels once the message from one channel 
// interface is captured by the flit packet switch to the next interface.
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_cxl_mem_cache_tx_tl_chmsg_arb #(
    parameter TP = `TP,
    parameter CXL_CHMSG_NUM   = 4,
    parameter CXL_CHMSG_WIDTH = 79,
    parameter CXL_CHANNEL_NUM = 2 //represents number of input channels to arbiter
) (
    // Clock and Reset
    input                                                  core_clk,               // Core clock
    input                                                  core_rst_n,             // Core active low asynchronous reset
    input [CXL_CHMSG_NUM-1:0][CXL_CHMSG_WIDTH-1:0]        cxl_arb_chmsg_i [CXL_CHANNEL_NUM],
    input  [CXL_CHMSG_NUM-1:0]                             cxl_arb_chmsg_halt_i,   // LL Flit Packer Halt Outputs
    output logic [CXL_CHMSG_NUM-1:0]                       cxl_arb_chmsg_halt_o [CXL_CHANNEL_NUM],
    output logic [CXL_CHMSG_NUM-1:0][CXL_CHMSG_WIDTH-1:0]  cxl_arb_chmsg_o         // LL Flit Packer Message Inputs
);

// Parameters
localparam CXL_CHMSG_VLD  = 0;
localparam CXL_CHMSG_LOG2 = $clog2(CXL_CHMSG_NUM);
localparam CXL_DIRECT_ARB = 0;
localparam INDEX_WIDTH = $clog2(CXL_CHANNEL_NUM);
localparam MAX_MSGS = $clog2(CXL_CHANNEL_NUM + CXL_CHMSG_NUM); // N channels and M messages givces maximum messages of N x M, to if N is represented in n bits, and M is represented in m bits
                                                               // then the result should be represented in n + m bits.

// Declarations
logic [CXL_CHANNEL_NUM-1:0]           array_of_states_r, array_of_states_nxt; // one hot encoded states that represent a state per channel

logic [CXL_CHANNEL_NUM-1:0][CXL_CHMSG_NUM-1:0]        cxl_arb_chmsg_vld_s;      // 2D array axb, where a is number of channels, and b is number of messages per channel 
                                                                                // each bit represents a valid msg in the current input
logic [CXL_CHANNEL_NUM-1:0][CXL_CHMSG_LOG2:0]         cxl_arb_chmsg_cnt_s;      // how many valid message per channel
logic [CXL_CHANNEL_NUM-1:0][CXL_CHMSG_NUM*2-1:0]      cxl_arb_chmsg_halt_s;     // Temporary variable twice wider than actual halt signal

logic [INDEX_WIDTH-1 : 0] index_channel, k; // the binary representation of the one hot encoded states 
logic [MAX_MSGS :0] valid_msgs_cntr;   // sum of valid messages per loop iteration starting from the channel in turn
logic [CXL_CHMSG_LOG2:0] remaining_valid_places; // how many output messages left for channels other than the one in turn to output their messages
//logic [CXL_CHMSG_LOG2+INDEX_WIDTH :0] total_valid_messages; //the maximum value of total valid messages = all messages are valid in all channels = number of messages x number of channels.
                                                              //hence the width of this variable should be equal to the width of both numbers added together. 

// -------------------------------------------------------------------------------------
// Channel Message Valid Bits
// -------------------------------------------------------------------------------------
always_comb begin
  for (int i = 0; i < CXL_CHANNEL_NUM; i++) begin: CH_CNT_VLD
    cxl_arb_chmsg_cnt_s[i] = 0;
   
    for (int j = 0; j < CXL_CHMSG_NUM; j++) begin: CH_MSG_CNT_VLD
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The design never can overflow the counter, as cxl_arb_chmsg_*_cnt_s is 1 bit wider than log2(CXL_CHMSG_NUM) to accommodate CXL_CHMSG_NUM value.
        
        cxl_arb_chmsg_vld_s[i][j] = cxl_arb_chmsg_i[i][j][CXL_CHMSG_VLD];
        cxl_arb_chmsg_cnt_s[i] = cxl_arb_chmsg_cnt_s[i] + cxl_arb_chmsg_i[i][j][CXL_CHMSG_VLD];
// spyglass enable_block W164a
    end
   end  
end

// -------------------------------------------------------------------------------------
// Implement Generic FSM for Arbitration
// -------------------------------------------------------------------------------------

always_comb begin

  array_of_states_nxt = array_of_states_r;

       for(int i = 0; i < CXL_CHANNEL_NUM; i++) begin
        if (array_of_states_r[i] & cxl_arb_chmsg_vld_s[i][0]  & ~cxl_arb_chmsg_halt_i[0]) begin
            array_of_states_nxt[0] = array_of_states_r[CXL_CHANNEL_NUM-1];
            array_of_states_nxt[CXL_CHANNEL_NUM-1:1] = array_of_states_r[CXL_CHANNEL_NUM-2:0];
        end      
       end    
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
    //initialize states to state S0
        array_of_states_r[0                  ]      <= #TP 1'b1;
        array_of_states_r[CXL_CHANNEL_NUM-1:1]      <= #TP   '0;
    end
    else begin
        array_of_states_r      <= #TP array_of_states_nxt;
    end
end

always_comb begin
  index_channel = '0;
  for (int i = 0; i < CXL_CHANNEL_NUM; i++) begin
    if(array_of_states_r[i] == 1'b1)
      index_channel = INDEX_WIDTH'(i);
  end
end
always_comb begin
 
  if (CXL_DIRECT_ARB) begin
    cxl_arb_chmsg_o = cxl_arb_chmsg_i[index_channel];
    for (int n = 0; n < CXL_CHANNEL_NUM; n++) begin
      cxl_arb_chmsg_halt_o[n] = {CXL_CHMSG_NUM{1'b1}}; //setting all halts to 1 initially
    end
    cxl_arb_chmsg_halt_o[index_channel] = cxl_arb_chmsg_halt_i; // only the channel that has the turn has the input halt 
  end
  else begin // NO DIRECT ARBITRATION
    cxl_arb_chmsg_o = '0;
    valid_msgs_cntr = '0;
    cxl_arb_chmsg_halt_s = '1;
    for (int n = 0; n < CXL_CHANNEL_NUM; n++) begin
      cxl_arb_chmsg_halt_o[n] = {CXL_CHMSG_NUM{1'b1}}; //setting all halts to 1 initially
    end
    k = index_channel;
    // here i represents how many time I should enter the outer loop
    // but it can't be used as the iterator, as it will take values higher than CXL_CHANNEL_NUM
    // hence k starts from index_channel and increment by 1, but it resets when it reaches the most sig channel  
    for (int i = 0; i < CXL_CHANNEL_NUM; i++) begin 
      if (k == index_channel)
        valid_msgs_cntr = 0;   
      for (int j = 0; j < CXL_CHMSG_NUM ; j++) begin
      //The below if condition can be the condition of the loop, but I'm avoiding using variables in the loop condition.
      //The condition represents how many empty places (MSGs) are there in the output signal.
      //assume CH0 has 3 MSGS and CH1 has 1 MSG, according to this condition, the 4th msg of CH0 will be written 
      //to position 4 in the output, however this shouldn't be a problem, because it will be overwritten
      //with the one message from CH1.
      remaining_valid_places = CXL_CHMSG_NUM - valid_msgs_cntr;
        if (/*j < cxl_arb_chmsg_cnt_s[k] &&*/ j < remaining_valid_places) 
          cxl_arb_chmsg_o[j + valid_msgs_cntr] = cxl_arb_chmsg_i[k][j];
      end
    
      if (k == index_channel) 
      cxl_arb_chmsg_halt_o[k] = cxl_arb_chmsg_halt_i;
      else begin
      cxl_arb_chmsg_halt_s[k] = {{CXL_CHMSG_NUM{1'b1}}, cxl_arb_chmsg_halt_i} >> valid_msgs_cntr;
      cxl_arb_chmsg_halt_o[k] = cxl_arb_chmsg_halt_s[k][CXL_CHMSG_NUM-1:0];    
      end
//Increment the counter in a way that it doesn't make it greater than the maximum value CXL_CHMSG_NUM
//if CH0 has 2 valid msgs, CH1 has 3 valid msgs and CXL_CHMSG_NUM is 4, we don't want the counter to be 5.
      if (valid_msgs_cntr + cxl_arb_chmsg_cnt_s[k] > CXL_CHMSG_NUM)
        valid_msgs_cntr = CXL_CHMSG_NUM;
      else
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The design can never overflow the counter, as valid_msgs_cntr is 1 bit larger than its maximum which is CXL_CHANNEL_NUM x CXL_CHMSG_NUM.
        valid_msgs_cntr = valid_msgs_cntr + cxl_arb_chmsg_cnt_s[k];
// spyglass enable_block W164a        
      if (k == CXL_CHANNEL_NUM-1)
        k=0;
      else  
        k = k+1; 
  
    end
  end
end
endmodule : DWC_cxl_mem_cache_tx_tl_chmsg_arb
