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
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_tx_tl_fifo_ctrl.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// --- FIFO Controller 
// ----------------------------------------------------------------------------
// CXL Transaction Layer Reciever FIFO Controller 
//Supports:
//Round Robin Pushing from application to different Channel Mesage buffers
//Round Robin Popping from channel message buffers to link layer
//Credit Management of same-type channels with application
//This module is instantiated only if CXL_CHANNEL_NUM > 1
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"


module DWC_cxl_mem_cache_tx_tl_fifo_ctrl #(
    parameter   TP            = `TP,
    parameter CXL_CHMSG_NUM   =   4,
    parameter CXL_CHMSG_WIDTH =   8,
    parameter CXL_CHANNEL_NUM =   4,
    parameter CXL_CHMSG_CREDITS = 4,
    parameter CXL_CHMSG_ID_W  =   (CXL_CHANNEL_NUM == 1) ? 1 : $clog2(CXL_CHANNEL_NUM), //Width of channel ID in bits
    parameter CXL_CHMSG_WIDTH_ADJ = CXL_CHMSG_WIDTH + CXL_CHMSG_ID_W // Message Width + Channel Index
 
  )(
    // -------------------------------------------------------------------------------------
    // Clocks and Resets
    // -------------------------------------------------------------------------------------
    input                               cxl_clk,
    input                               cxl_rst_n,
    input                               core_clk,
    input                               core_rst_n,
    // -------------------------------------------------------------------------------------
    // Application Layer Connections
    // -------------------------------------------------------------------------------------    
    input  [CXL_CHMSG_WIDTH-1 : 0] cxl_fifoctrl_data_i [0 : CXL_CHANNEL_NUM-1], //Input Data from Application Layer
    output logic                   cxl_fifoctrl_crd_o  [0 : CXL_CHANNEL_NUM-1], //Output Credit to Application Layer
    // -------------------------------------------------------------------------------------
    // Credit Control Connections
    // ------------------------------------------------------------------------------------- 
    input cxl_chmsg_en_i,
    input cxl_chmsg_crd_rst_i,
    input cxl_chmsg_pop_valid_i [0 : CXL_CHANNEL_NUM-1], // Indicates if data is written into offloading fifo of the concerned channel message buffer
    input [CXL_CHMSG_ID_W-1 : 0] cxl_chmsg_chid [0 : CXL_CHANNEL_NUM-1], //channel ID of the popped messsge, represents which channel the application intended to push data in,
    //                                                                     and used to return credits to that channel
    // -------------------------------------------------------------------------------------
    // Channel Message Buffers Connections
    // ------------------------------------------------------------------------------------- 
    output logic [CXL_CHMSG_WIDTH_ADJ-1 : 0] cxl_chmsg_data_o [0 : CXL_CHANNEL_NUM-1], //Output data in a RR fashion to channel message buffers
    input  [CXL_CHMSG_NUM-1 : 0][CXL_CHMSG_WIDTH_ADJ-1 : 0] cxl_chmsg_data_i [0 : CXL_CHANNEL_NUM-1], //Input data from channel message buffers 
    output logic [CXL_CHMSG_NUM-1 : 0] cxl_chmsg_halt_o [0 : CXL_CHANNEL_NUM-1], //output halt to different channel message buffers
    // -------------------------------------------------------------------------------------
    // Interface with Link Layer
    // ------------------------------------------------------------------------------------- 
    input  [CXL_CHMSG_NUM -1 : 0] cxl_fifoctrl_halt_i, //input halt from link layer
    output logic [CXL_CHMSG_NUM-1 : 0][CXL_CHMSG_WIDTH-1 : 0] cxl_fifoctrl_data_o //output data to link layer

  ); 
  import DWC_cxl_pkg::*;

localparam CXL_CHMSG_OPT_WD  = ((CXL_CHMSG_NUM/CXL_CHANNEL_NUM) == 1 )? 1 :  $clog2(CXL_CHMSG_NUM/CXL_CHANNEL_NUM) ;
// -------------------------------------------------------------------------------------
// Round Robin Pushing Logic
// ------------------------------------------------------------------------------------- 

logic [CXL_CHMSG_ID_W-1:0] s_queue_idx, r_queue_idx, static_ch_idx;

always_comb begin
    for (int j = 0 ; j < CXL_CHANNEL_NUM; j ++) begin 
        cxl_chmsg_data_o[j] = '0;
    end
    s_queue_idx =  r_queue_idx;
    static_ch_idx = '0;
    for (int i =0 ; i < CXL_CHANNEL_NUM; i++) begin
        if (cxl_fifoctrl_data_i[i][0]) begin
            static_ch_idx = i;
            cxl_chmsg_data_o[s_queue_idx] = {static_ch_idx , cxl_fifoctrl_data_i[i]};
            if (s_queue_idx == CXL_CHMSG_ID_W'(CXL_CHANNEL_NUM-1))
                s_queue_idx = '0;
            else 
                s_queue_idx  = s_queue_idx + 1'b1;
        end
        
    end 
end

always_ff @ (posedge cxl_clk or negedge cxl_rst_n) begin
    if(!cxl_rst_n)
        r_queue_idx <= #TP '0;
    else begin
        r_queue_idx <= #TP s_queue_idx;
    end
end

// -------------------------------------------------------------------------------------
// Credit Management Logic
// ------------------------------------------------------------------------------------- 

// Problem
// Assume N channels and application is writing on channel 0 only, the RR Pushing logic will distribute the data on the N channels, 
// which in turn will cause these channels to return credits to application, where application didn't write in them in the first place.

// Propsed Solution
// The credit logic should be pulled out of the chmsg buffers module and be instantiated per request type.
// The identification number of channel (Channel ID = constant) will be appended to every request to know from which channel did it came.

localparam LOG_CREDITS = $clog2(CXL_CHMSG_CREDITS);
logic [CXL_CHANNEL_NUM-1 : 0] [LOG_CREDITS:0] credit_counter_s, credit_counter_r;




always_ff @ (posedge cxl_clk or negedge cxl_rst_n) begin
     
        if (!cxl_rst_n) begin
            credit_counter_r <= #TP {(CXL_CHANNEL_NUM){(LOG_CREDITS+1)'(CXL_CHMSG_CREDITS)}};
        end
        else begin
            credit_counter_r <= #TP credit_counter_s;
        end
      
end 
    

    always_comb begin
        credit_counter_s = credit_counter_r;
        for (int i = 0 ; i < CXL_CHANNEL_NUM; i ++) begin
            if(cxl_chmsg_crd_rst_i) begin
                credit_counter_s[i] = (LOG_CREDITS+1)'(CXL_CHMSG_CREDITS);
            end
            else begin
                if(cxl_chmsg_pop_valid_i[i]) begin
                    if (credit_counter_s[cxl_chmsg_chid[i]] != (LOG_CREDITS+1)'(CXL_CHMSG_CREDITS)) begin
                    //We increment the counter when any thing is written to the offloading queue, either directly when bypass mode is 1, 
                    //or indirectly through popping from external RAM and writing to the offloading queue. 
                    //The difference here from the original case (implementtd in chmsg buffers) is that we can pop multiple messages in 
                    //different channels with the same channel ID as the example given in problem above. 
                    //Now we need to increment the counter by the amount of these messages.
                    //The if condition to protect incrementing beyond max credits.
                        credit_counter_s[cxl_chmsg_chid[i]] = credit_counter_s[cxl_chmsg_chid[i]] + 1'b1;
                    end
                end
                if((credit_counter_r[i] != 0 ) && cxl_chmsg_en_i)
                    credit_counter_s[i]  = credit_counter_s[i] - 1'b1;                    
            end  
        end   
    end

    always_comb begin
      for (int i = 0 ; i < CXL_CHANNEL_NUM; i ++) begin
        cxl_fifoctrl_crd_o[i] = (credit_counter_s[i] != 0) & cxl_chmsg_en_i;
      end
    end

// -------------------------------------------------------------------------------------
// Round Robin Popping Logic
// ------------------------------------------------------------------------------------- 
//localparam CHANNEL_L = (CXL_CHANNEL_NUM == 1) ? 1 : $clog(CXL_CHANNEL_NUM);
generate if (CXL_CHANNEL_NUM > 1) begin : CHANNELS_GTR_1
logic [CXL_CHMSG_ID_W -1 : 0] s_rr_ptr, r_rr_ptr;
logic [CXL_CHMSG_ID_W-1:0] channel_idx;
logic [CXL_CHMSG_OPT_WD-1:0] message_idx;
logic [CXL_CHMSG_NUM-1:0] valids; //valid messages in output signal.

    always_comb begin : RR_POP_PROC
    //i: simply the loop iterator, we need to fill 'REQNUM msgs every time for the output. Starts from 0 and increments with each loop iteration
    //channel_idx: starts from RR iterator, this points to the channel we should start from to populate the current message. Increments with each loop iteration (take care of overflow, when channel_idx=IFNUM,channel_idx reset to 0)
    //message_idx: which message of the channel interface should we take? Given that the buffers always shift the message in turn at location 0. message_idx starts from 0 every time, message_idx increments each time channel_idx reaches the value of r_rr_ptr again 

        channel_idx =  r_rr_ptr;
        message_idx = '0;
        for (int j = 0 ; j < CXL_CHANNEL_NUM; j ++) begin 
                cxl_chmsg_halt_o[j] = '1;
        end
        cxl_fifoctrl_data_o = '0;
        for (int i =0 ; i < CXL_CHMSG_NUM; i++) begin : RR_POP_LOOP
    // spyglass disable_block W468
    // SMD: Index 'message_idx' cannot cover the full width of vector
    // SJ: This is intended to decrease selector width and hence hardware, the number of messages popped is realteive to number of channels available.
            cxl_fifoctrl_data_o[i] = cxl_chmsg_data_i[channel_idx][message_idx][CXL_CHMSG_WIDTH-1:0];
            cxl_chmsg_halt_o[channel_idx][message_idx] = cxl_fifoctrl_halt_i[i]; 
    // spyglass enable_block W468        
            if (channel_idx == CXL_CHMSG_ID_W'(CXL_CHANNEL_NUM-1))
                channel_idx = '0;
            else 
                channel_idx  = channel_idx + 1'b1;
            if ( channel_idx == r_rr_ptr)
                message_idx  = message_idx + 1'b1;
            valids[i] =  cxl_fifoctrl_data_o[i][0];   
            
        end : RR_POP_LOOP
    end : RR_POP_PROC
            
    logic [7:0] count_valids; //this signal is input to function valid_cnt which is of fixed width 8
    logic [$clog2(8+1)-1  :0] ch_incr ,nxt_rr_ptr; 
    assign count_valids = {{(8-CXL_CHMSG_NUM){1'b0}}, (~cxl_fifoctrl_halt_i & valids)};
    assign ch_incr = valid_cnt_modulo(count_valids);

    always_comb begin: CH_INC_PROC
    //This works fine as long as RHS is <  CXL_CHANNEL_NUM
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ: channel numbers will not overflow counters       
        nxt_rr_ptr = ch_incr + r_rr_ptr;
    // spyglass enable_block W164a
    //in case number of channels is not a power of 2, then a modulus operation should take place.
    //example: 3 channels are implemented and s_rr_ptr points to channel 2 and 6 msgs are valid (ch_incr = 6)
    //then the next channel should still be channel 2 which is (2+6)%3
    //To write this as a code we need to subtract 3 (or CXL_CHANNEL_NUM) from 2+6 (or ch_incr + r_rr_ptr)
    //But subtracting once will not cover the cases where ch_incr + r_rr_ptr > 6 --> where the max will be 8 so subtracting twice is the max we need
    //    for(int i = 0; i < 2 ; i ++) begin
            if (nxt_rr_ptr > CXL_CHANNEL_NUM-1)
                nxt_rr_ptr = nxt_rr_ptr - CXL_CHANNEL_NUM;
    //    end
    //Hold value if no messages were popped
        if (|ch_incr == 1'b0)
            s_rr_ptr = r_rr_ptr;
        else
            s_rr_ptr = CXL_CHMSG_ID_W'(nxt_rr_ptr);

    end

    always_ff @ (posedge core_clk or negedge core_rst_n) begin
        if(!core_rst_n)
            r_rr_ptr <= #TP '0;
        else 
            r_rr_ptr <= #TP s_rr_ptr;
    end

function automatic logic [$clog2(8+1)-1  :0] valid_cnt_modulo (logic [8-1:0] message_vld );
  begin
    casez(message_vld)
      8'b1???_???? : valid_cnt_modulo = 'd8 % CXL_CHANNEL_NUM;
      8'b01??_???? : valid_cnt_modulo = 'd7 % CXL_CHANNEL_NUM;
      8'b001?_???? : valid_cnt_modulo = 'd6 % CXL_CHANNEL_NUM;
      8'b0001_???? : valid_cnt_modulo = 'd5 % CXL_CHANNEL_NUM;
      8'b0000_1??? : valid_cnt_modulo = 'd4 % CXL_CHANNEL_NUM;
      8'b0000_01?? : valid_cnt_modulo = 'd3 % CXL_CHANNEL_NUM;
      8'b0000_001? : valid_cnt_modulo = 'd2 % CXL_CHANNEL_NUM;
      8'b0000_0001 : valid_cnt_modulo = 'd1 % CXL_CHANNEL_NUM;
      default      : valid_cnt_modulo = 'd0;
    endcase

  end
endfunction
end: CHANNELS_GTR_1
else begin: CHANNELS_EQ_1
//The current implementation is that this module is instantiated only when CXL_CHANNEL_NUM > 1, this part will be used when generalizing connection
    assign cxl_fifoctrl_data_o = cxl_chmsg_data_i[0];
    assign cxl_chmsg_halt_o[0] = cxl_fifoctrl_halt_i[0];
end: CHANNELS_EQ_1
endgenerate


endmodule
