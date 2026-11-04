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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_los_lane.v#6 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:  SerDes Dependent Module (SDM)
// -----------------------------------------------------------------------------
// --- This module generates the rxelectrical 
// --- 
// -----------------------------------------------------------------------------
module DWC_pcie_gphy_los_lane #(
  parameter   TP = 0                       // Clock to Q delay (simulator insurance)
) (
  input        rst_n,                      // reset
  input        rxp,                        // serial receive data (pos)
  input        rxn,                        // serial receive data (neg)
  input  [2:0] rate,                       // current data rate
  input        rx_clock_off,
  input        rxelecidle_disable,         // gate the LoS
  `ifdef GPHY_ESM_SUPPORT
  input            esm_enable,
  input [6:0]      esm_data_rate0,
  input [6:0]      esm_data_rate1, 
  `endif // GPHY_ESM_SUPPORT
 
  output       rxelecidle_unfiltered,      // electrical idle detected
  output       rxelecidle_filtered,        // electrical idle detected filtered
  output       rxelecidle_filtered_with_noise
);

timeunit 1ns;
timeprecision 1fs;

localparam CONSEC_BITS_NR = 4;

// number of symbols too keep RxElecIdle in 0 once it was dropped
int rxelecidle_low_duration;
assign rxelecidle_low_duration = (rate > 1) ? 4*8 : 4*10;

wire pam4_ser;
assign pam4_ser = rate === 5 ? 1'b1 : 1'b0;

wire rxelecidle_noise;

reg local_rxbitclk;
real bit_time;

assign bit_time = `ifdef GPHY_ESM_SUPPORT
                   (esm_enable && rate === 2 && esm_data_rate0 == `GPHY_ESM_RATE0_8GT)  ? 0.125  : 
                   (esm_enable && rate === 2 && esm_data_rate0 == `GPHY_ESM_RATE0_16GT) ? 0.0625   :
                   (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_16GT) ? 0.0625   :
                   (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_20GT) ? 0.05   :
                   (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_25GT) ? 0.04  :
                 `endif// GPHY_ESM_SUPPORT
        
                  ( (rate === 0)) ? 0.4   :      
                  ( (rate === 1)) ? 0.2   :     
                  (`ifdef GPHY_ESM_SUPPORT !esm_enable && `endif (rate === 2)) ? 0.125   :      
                  (`ifdef GPHY_ESM_SUPPORT !esm_enable && `endif (rate === 3))  ? 0.0625   :
                  ( (rate === 4) ) ? 0.03125  : 0.03125;
                  
// rxbitclk generation
always begin : create_rxclk
    if (!rst_n) begin
        local_rxbitclk       = 1'b0;
        #0.4ns ;
    end else begin             
          local_rxbitclk       = 1'b0;
          #(bit_time/2) ;
          local_rxbitclk       = 1'b1;
          #(bit_time/2) ;                
    end 
end
//======================================================================
// LOS - loss of signal
// RxElecidle generation
//======================================================================
wire  rxelecidle_synthesized;
reg   rxelecidle_synthesized_d; initial rxelecidle_synthesized_d = 1'b1;

assign rxelecidle_synthesized = (pam4_ser) ? ((rxp === 1'bZ) || (rxn === 1'bZ)) : ((rxp === rxn ) || (rxp === 1'bZ) || (rxn === 1'bZ))  ;
assign rxelecidle_unfiltered  = rxelecidle_synthesized;

always @(posedge local_rxbitclk or negedge rxelecidle_synthesized)
begin
   if (rxelecidle_synthesized == 1'b0)
      rxelecidle_synthesized_d <= #TP 1'b0;
   else
      rxelecidle_synthesized_d <= #TP rxelecidle_synthesized;
end

// when we stop receiving data on serial lines we start a counter 
// to delay rx_elecidle assertion. This is to filter out rx_elecidle
// pulses when we are transmitting  the load board pattern
reg [4:0] rxelecidle_counter; initial rxelecidle_counter = 4'h0;
always @(posedge local_rxbitclk or negedge rst_n)
begin   
   if (!rst_n )     
      rxelecidle_counter <= #TP 4'b0;   
   else if (rxelecidle_counter > 0)     
   // reset or decrement     
      rxelecidle_counter <= #TP (!rxelecidle_synthesized_d) ? 5'h1A : rxelecidle_counter - 1;   
   else    
   // reset or keep    
      rxelecidle_counter <= #TP (!rxelecidle_synthesized_d) ? 5'h1A : rxelecidle_counter;
end

// @ GEN1 RxElecIdle needs to be stable in 0 during reception
// @ rate > GEN1 we introduce noise on RxElecIdle
assign rxelecidle_filtered = (rxelecidle_disable) ? 1'b1 : (rxelecidle_counter == 0) && rxelecidle_synthesized_d;
                                                    
assign rxelecidle_filtered_with_noise  = (rxelecidle_disable) ? 1'b1 : 
                                         (rate == 0)          ? ((rxelecidle_counter == 0) && rxelecidle_synthesized_d ) :
                                                                ((rxelecidle_counter == 0) && rxelecidle_synthesized_d )  || (rxelecidle_noise && !rx_clock_off);                                                   
    
//-----------------------------------------------------------------
// logic to introduce noise on RxElecIdle
//-----------------------------------------------------------------
reg [4:0]  cnt_consec_equal_bits;
reg [11:0] cnt_to_keep_rxelecidle_low;
reg rxp_r;

// delay rxp line
always @(local_rxbitclk)
begin
   rxp_r <= rxp;
end

// count number of consecutive eqaul bits
always @(local_rxbitclk or posedge rxelecidle_synthesized)
begin
   if (rxelecidle_synthesized) cnt_consec_equal_bits <= #TP 1; 
   else if (rxp == rxp_r)      cnt_consec_equal_bits <= #TP cnt_consec_equal_bits + 1;
   else                        cnt_consec_equal_bits <= #TP 1; 
end

// If we have a specific number of consecutive bits on the serial line we drop RxElecIdle
// We keep RxElecIdle low for 4 consecutive symbols or more if a new serie of consecutive 
// equal bits is found
always @(local_rxbitclk or posedge rxelecidle_synthesized)
begin
   if (rxelecidle_synthesized)                         cnt_to_keep_rxelecidle_low <= #TP rxelecidle_low_duration;
   else if (cnt_consec_equal_bits >= CONSEC_BITS_NR)   cnt_to_keep_rxelecidle_low <= #TP rxelecidle_low_duration;
   else if (cnt_to_keep_rxelecidle_low > 0)            cnt_to_keep_rxelecidle_low <= #TP cnt_to_keep_rxelecidle_low - 1;
   else                                                cnt_to_keep_rxelecidle_low <= #TP cnt_to_keep_rxelecidle_low; 
end

// RxElecIdle signal noise generation
assign rxelecidle_noise = (!rxelecidle_synthesized && cnt_to_keep_rxelecidle_low > 0) ? 1'b0 : 1'b1;

endmodule 
