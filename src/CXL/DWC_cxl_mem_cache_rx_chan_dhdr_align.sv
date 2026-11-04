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
// ---   $DateTime: 2023/10/03 08:20:39 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rx_chan_dhdr_align.sv#3 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// This module queue data headers after it is transmitted from the unpacker. It maps and replaces
// the data header queue mapper in RX_TL. For supporting late Poison feature DWC_cxl_rx_channel_aligner 
// module is added to the RX_LL to set the poison bit in dhr and aligns dhr to its corresponding 
// data then transmits it to RAS module for protection.
// -------------------------------------------------------------------------------------
// CXL DWC_cxl_rx_channel_aligner
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "CXL/svif/DWC_cxl_rxtl_llctrl_if.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_cxl_mem_cache_rx_chan_dhdr_align
  import DWC_cxl_pkg::*;
#(
  parameter TP         = `TP                              ,
  parameter HDR_NUM    = 4                                ,   // Number Of Data Header Channels
  parameter HDR_SIZE   = 28                               ,   // Data Header Size 
  parameter DATA_SIZE  = 28                               ,   // Data Size
  parameter BE_SIZE    = 28                               ,   // Byte Enable Size
  parameter DATA_NUM   = 28                               ,   // Number Of Data Channels
  parameter BE_ENABLE  = 0                                    // Byte Enable
  ,    
  parameter POISON_BIT = 0                                    // Poison Bit Location In Data Header
)(                                                            
    // Inputs                                                 
    input                        clk_i                    ,   // Clock
    input                        rst_n_i                  ,   // Asynchronous Active Low Reset
    input  [HDR_SIZE-1:0]        cxl_hdr_i  [0:HDR_NUM-1] ,   // Input Data Header Channels      
    input  [DATA_SIZE-1:0]       cxl_data_i [0:DATA_NUM-1],   // Input Data Channels
    input  [BE_SIZE-1:0]         cxl_be_i [0:DATA_NUM-1]  ,   // Input Byte Enable Channels
    input  [DATA_NUM-1:0]        cxl_data_valid_i         ,   // Input Data Valid Signal Channels 
    input  [DATA_NUM-1:0]        cxl_be_valid_i           ,   // Input Byte Enable Valid 
    input  [DATA_NUM-1:0]        cxl_poison_bit_i         ,   // late poison bit 
    // Outputs                                            
    output reg [HDR_SIZE-1:0]    cxl_hdr_o [0:DATA_NUM-1] ,   // Output Data Header Channels           
    output reg [DATA_SIZE-1:0]   cxl_data_o[0:DATA_NUM-1] ,   // Output Data Channels
    output reg [BE_SIZE-1:0]     cxl_be_o[0:DATA_NUM-1]   ,   // Output Byte Enable Channels
    output reg [DATA_NUM-1:0]    cxl_data_valid_o         ,   // Output Data Valid Signal Channels
    output reg [DATA_NUM-1:0]    cxl_be_valid_o               // Output Byte Enable Valid Channels
 );
 
// Local Parameters                                      
 localparam  RAM_LENGTH =2**($clog2 (HDR_NUM*2))          ;   // FIFO Size 
 localparam  PTR_WIDTH  = $clog2(RAM_LENGTH)              ;   // FIFO Pointer Width 
 

// Declarations                     
 logic [HDR_SIZE-1:0]  data_header_nxt [0:RAM_LENGTH-1]   ;   // Data  Header Shift Register - Next State
 logic [HDR_SIZE-1:0]  data_header_r   [0:RAM_LENGTH-1]   ;   // Data  Header Shift Register
 logic [DATA_SIZE-1:0] data_nxt                           ;   // Data  Register - Next State
 logic [DATA_SIZE-1:0] data_r                             ;   // Data  Register
 logic [PTR_WIDTH:0]   wr_dhr_addr_nxt                    ;   // Write Pointer Of Data Header In   FIFO - Next State
 logic [PTR_WIDTH:0]   rd_dhr_addr_nxt                    ;   // Read  Pointer Of Data Header From FIFO - Next State
 logic [PTR_WIDTH:0]   wr_dhr_addr_r                      ;   // Write Pointer Of Data Header In   FIFO
 logic [PTR_WIDTH:0]   rd_dhr_addr_r                      ;   // Read  Pointer Of Data Header From FIFO
 logic [3:0]           vld_s                              ;   // Valid Signal  Of Input Data Headers 
 logic [DATA_NUM-1:0]  vld_out_s                          ;   // Axillary Signal For Valid Output Data 
 logic                 dhr_reg_full_s                     ;   // Channel Data Header Register Full Flag
 logic                 dhr_reg_empty_s                    ;   // Channel Data Header Register Empty Flag
 logic                 dhr_packing_err_s                  ;   // Error Packing Data Headers withen Slot
 logic [PTR_WIDTH-1:0] wr_dhr_addr_s                      ;   // Axillary Signal for wr_dhr_addr_r (bits selection)
 logic [PTR_WIDTH-1:0] r_dhr_addr_s                       ;   // Axillary Signal for r_dhr_addr_r  (bits selection)
 logic [DATA_SIZE-1:0] cxl_data_s [0:DATA_NUM-1]          ;   // Axillary Signal for cxl_data_o  
 logic [BE_SIZE-1:0]   cxl_be_s [0:DATA_NUM-1]            ;   // Axillary Signal for cxl_be_o  
 logic [DATA_NUM-1:0]  cxl_data_valid_s                   ;   // Axillary Signal for cxl_data_valid_o  
 logic [DATA_NUM-1:0]  cxl_be_valid_s                     ;   // Axillary Signal for cxl_be_valid_o  
 logic [DATA_NUM-1:0]  cxl_be_align_valid_s               ;   // Align the Late Poison Bit  
 logic [DATA_NUM-1:0]  cxl_poison_bit_s                   ;   // Axillary Signal for cxl_poison_bit_s



// Used to Align the Late Poison Bit(cxl_poison_bit_s) with Data Valid in (S2M&H2D) or with Byte Enable in (M2S&D2H) 
assign cxl_be_align_valid_s = !BE_ENABLE ? cxl_data_valid_i : cxl_be_valid_i;

always_comb begin
    cxl_data_s       = cxl_data_i          ;
    cxl_be_s         = cxl_be_i            ;
    cxl_data_valid_s = cxl_data_valid_i    ;
    cxl_be_valid_s   = cxl_be_align_valid_s;
    cxl_poison_bit_s = cxl_poison_bit_i    ;
end
// -------------------------------------------------------------------------------------



assign vld_out_s           = BE_ENABLE ? cxl_be_valid_s : cxl_data_valid_s                              ;
assign dhr_reg_full_s      = ({!rd_dhr_addr_r[PTR_WIDTH],rd_dhr_addr_r[PTR_WIDTH-1:0]} == wr_dhr_addr_r);
assign dhr_reg_empty_s     = (rd_dhr_addr_r == wr_dhr_addr_r)                                           ;
assign cxl_be_o            = cxl_be_s;


// -------------------------------------------------------------------------------------
// Write Valid Data Headers in FIFO and Assert Late Poison Bit
// -------------------------------------------------------------------------------------
  always_comb begin
   // Preset Data Header Signal
    vld_s           = '0           ;
  // Preset Data Header Register
    data_header_nxt = data_header_r; 
  // Extract Data Headers Valid Bit
    for (int i = 0; i < HDR_NUM; i++) begin
      vld_s[i] = cxl_hdr_i[i][0];
    end
// Write valid data headers     
    //if(cxl_flit_valid_i) begin
      for (int i=0; i < HDR_NUM ;i=i+1) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: wr_dhr_addr_s takes only the least (PTR_WIDTH-1) bits of wr_dhr_addr_r.
        wr_dhr_addr_s = wr_dhr_addr_r[PTR_WIDTH-1:0] + i;
// spyglass enable_block W164a
        data_header_nxt[wr_dhr_addr_s] = vld_s[i] ? cxl_hdr_i[i] : data_header_r[wr_dhr_addr_s];
      end
  end
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// Increment Read & Write Pointers Of Data Header Of FIFO
// -------------------------------------------------------------------------------------
 always_comb begin
// Preset Error Signal
  dhr_packing_err_s = 1'b0 ;
// Preset Data Header Counters (Read & Write)
  wr_dhr_addr_nxt = wr_dhr_addr_r;
  rd_dhr_addr_nxt = rd_dhr_addr_r;
// Increment Read Pointer Of Data Header From FIFO
  for (int i = 0; i < DATA_NUM; i++)      begin
    if(vld_out_s[i]) begin
      rd_dhr_addr_nxt = rd_dhr_addr_nxt + 1;
    end
  end
  
// Increment Write Pointer Of Data Header In FIFO
  casez(vld_s)
    4'b1???:begin 
             wr_dhr_addr_nxt   = wr_dhr_addr_nxt + 4; // Receive four  valid data header in this cycle - Valid Only In Cxl.cache Type 
      end                      
    4'b01??:begin              
             wr_dhr_addr_nxt   = wr_dhr_addr_nxt + 3; // Receive three valid data header in this cycle 
      end                                                          
    4'b001?:begin                                                     
             wr_dhr_addr_nxt   = wr_dhr_addr_nxt + 2; // Receive two   valid data header in this cycle
      end                                                          
    4'b0001:begin                                                     
             wr_dhr_addr_nxt   = wr_dhr_addr_nxt + 1; // Receive one   valid data header in this cycle
      end                           
  endcase
end 
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// Channel Message Outputs - Interface to RX Transaction Layer
// -------------------------------------------------------------------------------------
always_comb begin 

    r_dhr_addr_s               = rd_dhr_addr_r[PTR_WIDTH-1:0];
  // Preset Outputs Messages
    for (int i = 0; i < DATA_NUM; i++)  begin
      cxl_hdr_o        [i] = '0;
    end 

  // Data Header Output
     for (int i = 0; i < DATA_NUM; i++)      begin
       if(vld_out_s[i]) begin
         cxl_hdr_o[i]               =  data_header_r[r_dhr_addr_s];
         r_dhr_addr_s               = r_dhr_addr_s + 'd1;
         cxl_hdr_o[i][POISON_BIT]  |= cxl_poison_bit_s[i];
       end
     end
end


 always_comb begin
// Preset Data Register
    data_nxt = data_r;
// Preset Outputs Messages
  for (int i = 0; i < DATA_NUM; i++)  begin
    cxl_data_o       [i] = '0;
    cxl_data_valid_o [i] = '0;
    cxl_be_valid_o   [i] = '0;
  end 
// ------------
//Data & Data_valid & Be_valid Output Message In M2S and D2H Directions  if(BE_ENABLE == 1)
// ------------
  if(BE_ENABLE) begin 
    for (int i = 0; i < DATA_NUM; i++) begin
      if(cxl_data_valid_s[i] /*& !cxl_be_valid_i[i]*/) begin
        data_nxt = cxl_data_s[i];
      end
    end
  // Channel message outputs 
    for (int i = 0; i < DATA_NUM; i++) begin
      if(!cxl_data_valid_s[i] & cxl_be_valid_s[i]) begin
        cxl_data_o       [i] = data_r;
        cxl_data_valid_o [i] = 1'b1;
        cxl_be_valid_o   [i] = 1'b1;
      end  
      else if(vld_out_s[i]) begin
        cxl_data_o[i]        = cxl_data_s[i];
        cxl_data_valid_o [i] = 1'b1;
        cxl_be_valid_o   [i] = 1'b1;
      end
    end      
  end   
// ------------
//Data & Data_valid Output Message In M2S and D2H Directions if (BE_ENABLE == 0)
// ------------
  else begin
    for (int i = 0; i < DATA_NUM; i++) begin
      if (cxl_data_valid_s[i])begin
         cxl_data_o[i]        = cxl_data_s[i];
         cxl_data_valid_o [i] = 1'b1         ;
         cxl_be_valid_o   [i] = 1'b0         ;
      end
    end 
  end 
// ------------         
end
// ------------
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// Counters & Data & Data_Headers Register
// -------------------------------------------------------------------------------------
 always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      for (int i = 0; i < RAM_LENGTH; i++)
        data_header_r[i]   <= # TP '0;
      wr_dhr_addr_r        <= # TP '0;
      rd_dhr_addr_r        <= # TP '0;
      data_r               <= # TP '0;
    end else begin
      for (int i = 0; i < RAM_LENGTH; i++)
        data_header_r[i]   <= # TP data_header_nxt[i];
      wr_dhr_addr_r        <= # TP wr_dhr_addr_nxt   ;
      rd_dhr_addr_r        <= # TP rd_dhr_addr_nxt   ;
      data_r               <= # TP data_nxt          ;
    end
end
// -------------------------------------------------------------------------------------
endmodule
