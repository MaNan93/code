
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
// ---    $DateTime: 2023/09/01 04:30:12 $
// ---    $Revision: #37 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_deser.v#37 $
// -------------------------------------------------------------------------
// --- Module Description: Deserializer
// -------------------------------------------------------------------------

module DWC_pcie_gphy_deser #(
  parameter   TP       = -1,                           // Clock to Q delay (simulator insurance)
  parameter   WIDTH_WD = -1
) (
  input            refclk,                     // reference clock
  input            rst_n,                      // reset
  input            rx_clock_off,               // clock has been turned off in P1
  input            rxpolarity,                 // invert serial data
  input            serdes_arch,
  input  [WIDTH_WD-1:0]   rxwidth,
  
  input            rxp,                        // serial receive data (pos)
  input            rxn,                        // serial receive data (neg)
  input      [2:0] rate,                       // current data rate
  input      [2:0] current_rate,  
  input      [3:0] powerdown,
  input            rxstandby,
  input            rxelecidle_filtered,        // electrical idle detected filtered
  input            rxelecidle_unfiltered,      // electrical idle detected
  input            sris_mode,
  input            cdr_fast_lock,
  output reg       rxbitclk,
`ifdef GPHY_ESM_SUPPORT
  input            esm_enable,
  input [6:0]      esm_data_rate0,
  input [6:0]      esm_data_rate1, 
`endif // GPHY_ESM_SUPPORT
  output reg [9:0] rxdata_10b,                 // parallel 10 bit receive data
  output           beacondetected,             // beacondetected
  output           recvdclk,                   // recovered receiver symbol clock
  output           recvdclk_pipe,
  output           rcvdrst_n,
  output reg       serdes_rx_valid,
  output reg       recvdclk_stopped
); 

timeunit 10fs;
timeprecision 1fs;

// symbol clock reference times
// GEN1_CYCLE       = 400_000;   //  250 MHz
// GEN2_CYCLE       = 200_000;   //  500 MHz
// GEN3_CYCLE       = 100_000;   // 1000 MHz
// GEN4_CYCLE       =  50_000;   // 2000 MHz
// ESM_GEN4_20GT    =  40_000;   // 2500 MHZ
// ESM_GEN4_25GT    =  32_000;   // 3125 MHz
reg pop_enable;
reg  [WIDTH_WD-1:0]   rxwidth_sync, rxwidth_sync_r, rxwidth_sync_rr;

reg int_recvdclk;

wire   cdr_enable;
assign cdr_enable = !rx_clock_off;

wire int_rxpolarity;
assign int_rxpolarity = serdes_arch ? 1'b0 : rxpolarity;

wire pam4_ser;
assign pam4_ser = rate === 5 ? 1'b1 : 1'b0;

reg align_en;

always @(posedge int_recvdclk or negedge rst_n)
begin
   if (!rst_n) begin
      align_en <= #TP 0;
   end else begin
      if (rate != current_rate) 
          align_en <= #TP 0; 
      else if (rxstandby)   
          align_en <= #TP 0;
      else if (powerdown inside { `GPHY_PDOWN_P0, `GPHY_PDOWN_P0S })
         align_en <= #TP 1;
      else  
         align_en <= #TP 0;
   end
   
end

//=============================================================================
// Simlified CDR Model
// Not support for Refclk Deviation
// Minimum unit of UI should be 1fs
//=============================================================================
reg bit_time_lock; initial bit_time_lock = 0;
reg       bit_time_change; initial bit_time_change = 0;
realtime  bit_time;        initial bit_time = 40_000;
realtime  first_bit_time;  initial first_bit_time = 40_000;
realtime  rxp_time1;
realtime  rxp_time2;
realtime  rxn_time1;
realtime  rxn_time2;
realtime  rxbitclk_sample;

// rxbitclk generation
always begin : create_rxclk
    if (!rst_n) begin
        rxbitclk       = 1'b0;
        #0.4ns ;
    end else begin
        if (cdr_enable) begin  
         // move the sampling point at the mid of the bit
         // we do this by having a clock period smaller or bigger then standard
         // this happens from time to time when the sampling point it is shifted
         if (bit_time_change)
         begin              
          rxbitclk       = 1'b0;
          #(first_bit_time) ;
          rxbitclk       = 1'b1;
          #(bit_time) ;        
          bit_time_change = 0;
         end
              
          rxbitclk       = 1'b0;
          #(bit_time) ;
          rxbitclk       = 1'b1;
          #(bit_time) ;        
        end else begin
          rxbitclk       = 1'b0;
          #0.4ns ;
        end
    end
end

reg sample_rxp, sample_rxn;
realtime sample_rxp_time, sample_rxn_time;

always @(rxp)
begin
    sample_rxp_time <= $realtime;
end

always @(rxn)
begin
   sample_rxn_time <= $realtime;
end

// sample_rxp and sample_rxn is not used at gen1-5 speed. 
always @(posedge rxbitclk or negedge rst_n) begin
   if (!rst_n) begin
      sample_rxp <= 0;  
      sample_rxn <= 0; 
   end else if (rxelecidle_filtered) begin
      sample_rxp <= 0;  
      sample_rxn <= 0;  
   end else if ((rxbitclk_sample - sample_rxp_time) <  31_50 && (rxbitclk_sample - sample_rxp_time) >  31_00)  begin 
      sample_rxp <= 1;  
      sample_rxn <= 0;  
   end else if ((rxbitclk_sample - sample_rxn_time) <  31_50 && (rxbitclk_sample - sample_rxn_time) >  31_00)  begin  
      sample_rxp <= 0;  
      sample_rxn <= 1;         
   end else if (rxbitclk_sample - sample_rxp_time > 40_000_0) begin
      sample_rxp <= 0;  
      sample_rxn <= 1; 
   end else if (rxbitclk_sample - sample_rxn_time > 40_000_0) begin
      sample_rxp <= 1;  
      sample_rxn <= 0; 
   end else begin
      sample_rxp <= sample_rxp;  
      sample_rxn <= sample_rxn;
   end        
end

bit sample_rxp_side;
initial sample_rxp_side = 0;

always @(posedge rxp or posedge rxn or negedge rst_n) begin
  if (!rst_n) begin
    //sample_rxp = 0 at rst_n deasserted 
    sample_rxp_side = 0;
  end
  else if(sample_rxp)
    sample_rxp_side = 1;
  else
    sample_rxp_side = 0;
end

realtime rxp_delta;

assign   rxp_delta = (!pam4_ser) ?  (rxp_time1 - rxp_time2) :
                     (sample_rxp_side)  ? (rxp_time1 - rxp_time2) : (rxn_time1 - rxn_time2);

wire   rate_changing;
assign rate_changing = (rate != current_rate) ? 1 : 0;
reg    rate_changing_r;
reg    rate_changing_rr;


always @(posedge int_recvdclk or negedge rst_n) begin
   if (!rst_n) begin
      rate_changing_r  <= 'd0;
      rate_changing_rr <= 'd0;
   end else begin
      rate_changing_r  <= rate_changing;
      rate_changing_rr <= rate_changing_r;
   end          
end

// sample rxbitclk
always @(rxbitclk or negedge rst_n) begin
      rxbitclk_sample <= $realtime;      
end

// measure rxp width from edge to edge
always @(rxp or negedge rst_n) begin
    if (!rst_n) begin
        rxp_time1    <= 40_000;
        rxp_time2    <= 0;        
    end else begin
        rxp_time1  <= $realtime;
        rxp_time2  <= rxp_time1;    
    end
end

wire rxn_gated;
assign rxn_gated = rxn && pam4_ser;
always @(rxn_gated or negedge rst_n) begin
    if (!rst_n) begin
        rxn_time1    <= 40_000;
        rxn_time2    <= 0;        
    end else begin
        rxn_time1  <= $realtime;
        rxn_time2  <= rxn_time1;    
    end
end

wire rx_sample_line;

assign rx_sample_line = (!pam4_ser)  ? rxp :
                        (sample_rxp_side) ? rxp : rxn;

`ifdef GPHY_IMPROVED_DESER
function automatic bit func_adjust_bit_time(int bit_length);

  if(bit_length == 0)
    $fatal("ERROR: bit_length input is 0 in func_adjust_bit_time() in DWC_pcie_gphy_deser.v ");

  if (
  `ifdef GPHY_ESM_SUPPORT
    (esm_enable && rate === 2 && esm_data_rate0 == `GPHY_ESM_RATE0_8GT  && rxp_delta <= 126_00 * bit_length && rxp_delta >= 124_00 * bit_length ) || 
    (esm_enable && rate === 2 && esm_data_rate0 == `GPHY_ESM_RATE0_16GT && rxp_delta <= 63_00 * bit_length  && rxp_delta >= 62_00 * bit_length ) ||
    (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_16GT && rxp_delta <= 63_00 * bit_length  && rxp_delta >= 62_00 * bit_length ) ||
    (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_20GT && rxp_delta <= 51_00 * bit_length  && rxp_delta >= 49_00 * bit_length ) ||  //ESM_GEN4_20GT/8.0 
    (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_25GT && rxp_delta <= 40_50 * bit_length  && rxp_delta >= 39_50 * bit_length ) ||  //ESM_GEN4_25GT/8.0
  `endif// GPHY_ESM_SUPPORT

   ( (rate === 0) && rxp_delta <= 403_00 * bit_length && rxp_delta >= 398_00 * bit_length) ||       
   ( (rate === 1) && rxp_delta <= 202_00 * bit_length && rxp_delta >= 199_00 * bit_length) ||       
   (`ifdef GPHY_ESM_SUPPORT 
      !esm_enable &&
    `endif // GPHY_ESM_SUPPORT
     (rate === 2) && rxp_delta <= 126_00 * bit_length && rxp_delta >= 124_00 * bit_length) ||       
   (`ifdef GPHY_ESM_SUPPORT
      !esm_enable && 
    `endif // GPHY_ESM_SUPPORT
       (rate === 3 ) && rxp_delta <=  63_00 * bit_length && rxp_delta >=  62_00 * bit_length ) ||
     ( (rate === 4 ) && rxp_delta <=  31_50 * bit_length && rxp_delta >=  31_00 * bit_length )||
     ( (rate === 5 ) && rxp_delta <=  31_50 * bit_length && rxp_delta >=  31_00 * bit_length )) begin

    // we calculate the offset between the edge of the rxbitclk and midd of the rxp bit
    // we need to do this to be able to move dinamicaly the sampling point to the midd of the bit
    // this is needded to be able to compensate the jitteri incoming clock
    if ($realtime - rxbitclk_sample < 40_500 )  begin           
       if ($realtime - rxbitclk_sample == rxp_delta/bit_length )
         first_bit_time <= rxp_delta/(2 * bit_length) ;               
       else if ($realtime - rxbitclk_sample > rxp_delta/(2 * bit_length) )
         first_bit_time <= rxp_delta/bit_length + (($realtime - rxbitclk_sample) - rxp_delta/(2 * bit_length));
       else if ($realtime - rxbitclk_sample < rxp_delta/(2 * bit_length) )
         first_bit_time <= rxp_delta/bit_length - (rxp_delta/(2 * bit_length) - ($realtime - rxbitclk_sample) );  
       else if ($realtime - rxbitclk_sample == rxp_delta/(2 * bit_length) )      
         first_bit_time <= rxp_delta/bit_length;
       bit_time_change <= 1;    
    end
    
    bit_time <= rxp_delta/bit_length;
    bit_time_lock <= 1'b1;

    return 1;
  end

  return 0;
endfunction

// compute bit time 
always @(rx_sample_line or rate_changing_r or rate_changing or negedge rst_n) begin
    if (!rst_n) begin
        bit_time     <= 40_000;
        bit_time_lock <= 1'b0;
        
    end else if (rate_changing && !cdr_fast_lock) begin
        bit_time      <= bit_time ;
        bit_time_lock <= 1'b0;
    end else if (rate_changing_rr && !rate_changing_r && cdr_fast_lock) begin   
        bit_time     <= (rate == 0) ?   40_000 :
                        (rate == 1) ?   20_000 :
                        (rate == 2) ?   12_500 :
                        (rate == 3) ?    6_250 :
                        (rate == 4) ?    3_125 :
                        (rate == 5) ?    3_125 : 3_125 ;
        bit_time_lock <= 1'b1;
        
    end else if (rxelecidle_filtered && !pop_enable) begin   
        bit_time     <= bit_time ;
        bit_time_lock <= 1'b0;
    end else begin
            
        if (func_adjust_bit_time(1)) ;      // adjustment for 1 rx ui width
        else if (func_adjust_bit_time(2)) ; // adjustment for 2 rx ui width
        else if (func_adjust_bit_time(3)) ; // adjustment for 3 rx ui width
        else if (func_adjust_bit_time(4)) ; // adjustment for 4 rx ui width
        else if (func_adjust_bit_time(5)) ; // adjustment for 5 rx ui width
        else if (func_adjust_bit_time(6)) ; // adjustment for 6 rx ui width
        else if (func_adjust_bit_time(7)) ; // adjustment for 7 rx ui width
        else if (func_adjust_bit_time(8)) ; // adjustment for 8 rx ui width
        else if (func_adjust_bit_time(16)) ; // adjustment for 16 rx ui width
        else if (func_adjust_bit_time(32)) ; // adjustment for 32 rx ui width
    end
end

`else // !GPHY_IMPROVED_DESER

// compute bit time 
always @(rx_sample_line or rate_changing_r or rate_changing or negedge rst_n) begin
    if (!rst_n) begin
        bit_time     <= 40_000;
        bit_time_lock <= 1'b0;
        
    end else if (rate_changing && !cdr_fast_lock) begin
        bit_time      <= bit_time ;
        bit_time_lock <= 1'b0;
    end else if (rate_changing_rr && !rate_changing_r && cdr_fast_lock) begin   
        bit_time     <= (rate == 0) ?   40_000 :
                        (rate == 1) ?   20_000 :
                        (rate == 2) ?   12_500 :
                        (rate == 3) ?    6_250 :
                        (rate == 4) ?    3_125 :
                        (rate == 5) ?    3_125 : 3_125 ;
        bit_time_lock <= 1'b1;
        
    end else if (rxelecidle_filtered && !pop_enable) begin   
        bit_time     <= bit_time ;
        bit_time_lock <= 1'b0;
    end else begin
            
        if (
          `ifdef GPHY_ESM_SUPPORT
            (esm_enable && rate === 2 && esm_data_rate0 == `GPHY_ESM_RATE0_8GT  && rxp_delta < 126_00   && rxp_delta > 124_00 ) || 
            (esm_enable && rate === 2 && esm_data_rate0 == `GPHY_ESM_RATE0_16GT && rxp_delta < 63_00    && rxp_delta > 62_00  ) ||
            (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_16GT && rxp_delta < 63_00    && rxp_delta > 62_00  ) ||
            (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_20GT && rxp_delta < 51_00    && rxp_delta > 49_00  ) ||  //ESM_GEN4_20GT/8.0 
            (esm_enable && rate === 3 && esm_data_rate1 == `GPHY_ESM_RATE1_25GT && rxp_delta < 40_50    && rxp_delta > 39_50  ) ||  //ESM_GEN4_25GT/8.0
          `endif// GPHY_ESM_SUPPORT
        
           ( (rate === 0) && rxp_delta < 403_00 && rxp_delta > 398_00 ) ||       
           ( (rate === 1) && rxp_delta < 202_00 && rxp_delta > 199_00 ) ||       
           (`ifdef GPHY_ESM_SUPPORT 
              !esm_enable &&
            `endif // GPHY_ESM_SUPPORT
             (rate === 2) && rxp_delta < 126_00 && rxp_delta > 124_00 ) ||       
           (`ifdef GPHY_ESM_SUPPORT
              !esm_enable && 
            `endif // GPHY_ESM_SUPPORT
               (rate === 3 ) && rxp_delta <  63_00 && rxp_delta >  62_00 ) ||
             ( (rate === 4 ) && rxp_delta <  31_50 && rxp_delta >  31_00 )||
             ( (rate === 5 ) && rxp_delta <  31_50 && rxp_delta >  31_00 )) begin

            // we calculate the offset between the edge of the rxbitclk and midd of the rxp bit
            // we need to do this to be able to move dinamicaly the sampling point to the midd of the bit
            // this is needded to be able to compensate the jitteri incoming clock
            if ($realtime - rxbitclk_sample < 40_500 )  begin           
               if ($realtime - rxbitclk_sample == rxp_delta )
                 first_bit_time <= rxp_delta/2;               
               else if ($realtime - rxbitclk_sample > rxp_delta/2 )
                 first_bit_time <= rxp_delta + (($realtime - rxbitclk_sample) - rxp_delta/2);
               else if ($realtime - rxbitclk_sample < rxp_delta/2 )
                 first_bit_time <= rxp_delta - (rxp_delta/2 - ($realtime - rxbitclk_sample) );  
               else if ($realtime - rxbitclk_sample == rxp_delta/2 )      
                 first_bit_time <= rxp_delta;
               bit_time_change <= 1;    
            end
            
            bit_time <= rxp_delta;
            bit_time_lock <= 1'b1;
        end
    end
end

`endif // !GPHY_IMPROVED_DESER


//======================================================================
// Beacon detection
// Just using a simple indication when both rx lines are high (strictly
// speaking this would be an electrical idle condition)
//======================================================================
assign beacondetected  = (rxp == 1) & (rxn == 1);


//======================================================================
// Infinite queue used to buffer up serial data and model symbol clock 
// drifting
//======================================================================
//we write the bits into the queue on rxclk as it comes in
reg rx_q[$];
always @(rxbitclk)
begin
   if (!rst_n) begin
     rx_q = {};
   end else if (!align_en) begin
     rx_q = {};
   end else if (!rxelecidle_unfiltered && align_en && bit_time_lock) begin
     if (pam4_ser) begin
     `ifdef GPHY_PAM4_DIFF_PAIR_MSB_IS_DATAP
       rx_q.push_back(rxn);
       rx_q.push_back(rxp);
     `else
       rx_q.push_back(rxp);
       rx_q.push_back(rxn);
     `endif // GPHY_PAM4_DIFF_PAIR_MSB_IS_DATAP
     end else begin
       rx_q.push_back(rxp);
     end
  end 
end


// when we turn off the recvdclk we need to give some rcvd clk cycles
// so that the last symbol read from serials lines reaches the elastic buffer and it is pushed
// into the elastic buffer
// this means 30 rcvdclk before turning off the rcvdclk
reg [3:0] rate_delayed;
always @(posedge int_recvdclk or negedge rst_n)
begin
   if (!rst_n)                            rate_delayed <= 'd0; else
   if (rate_changing && recvdclk_stopped) rate_delayed <= rate; else
   if (rate == current_rate)              rate_delayed <= rate; 
end 


// after the queue is empty we give extrac ckl cycles so that the data reached phy output
// in serdes mode the number of clk needs to be > 50
reg     [8:0]  rcvdclk_counter; initial rcvdclk_counter = 8'h00;
initial recvdclk_stopped = 1'b1;
always @(posedge recvdclk_pipe or negedge rst_n)
begin
   if (!rst_n )                                         rcvdclk_counter <= #TP 8'h00;
   else if (rxelecidle_filtered && rcvdclk_counter > 0) rcvdclk_counter <= #TP rcvdclk_counter - 1;
   else if (!rxelecidle_filtered && serdes_arch)        rcvdclk_counter <= #TP `GPHY_RXVALID_DEASSERT_DELAY;
   else if (!rxelecidle_filtered)                       rcvdclk_counter <= #TP (rate_delayed > 1) ? 8'h37 :8'h06 ;
   
end


// in serdes mode after rx_valid is dropped we need at least 50 clk cycles
reg     [8:0]  serdes_rcvdclk_counter; initial serdes_rcvdclk_counter = 8'h00;
always @(posedge recvdclk_pipe or negedge rst_n)
begin
   if (!rst_n )                                        serdes_rcvdclk_counter <= #TP 8'h00;
   else if (!pop_enable && serdes_rcvdclk_counter > 0) serdes_rcvdclk_counter <= #TP serdes_rcvdclk_counter - 1;
   else if (pop_enable)                                serdes_rcvdclk_counter <= #TP `GPHY_RECVDCLK_OFF_DELAY + `GPHY_LATENCY_SERDES;
   
end

// this is an indication that recvdclk is off
always @(posedge int_recvdclk or negedge rst_n)
begin
  if (!rst_n)                                                     recvdclk_stopped <= #TP 1'b1; else
  if (!serdes_arch && !pop_enable && rcvdclk_counter == 0)        recvdclk_stopped <= #TP 1'b1; else
  if (serdes_arch && !pop_enable && serdes_rcvdclk_counter == 0)  recvdclk_stopped <= #TP 1'b1; else
  if (bit_time_lock)                                              recvdclk_stopped <= #TP 1'b0; else
                                                                  recvdclk_stopped <= #TP recvdclk_stopped;
end

//=============================================================================
// Deserializer
//=============================================================================
int        wordlen;
int        delta;
realtime   half_period;
reg [9:0]  rxdata_10b_int; 
reg recvdclk_div2;
reg recvdclk_div4;
reg recvdclk_div8;
reg recvdclk_div16;
reg recvdclk_div32;


assign     wordlen = (rate > 1) ? 8 : 10;

always @(posedge int_recvdclk or negedge rst_n)
  if (!rst_n)                                   pop_enable <= #TP 1'b0; else
  if (!align_en)                                pop_enable <= #TP 1'b0; else
`ifdef GPHY_IMPROVED_DESER
  if (rx_q.size() > (wordlen * 2) )             pop_enable <= #TP 1'b1; else 
`else
  if (rx_q.size() > wordlen)                    pop_enable <= #TP 1'b1; else 
`endif
  if (rx_q.size() == 0 && rcvdclk_counter == 0) pop_enable <= #TP 1'b0;
  else                                          pop_enable <= #TP pop_enable;
  

initial  half_period = 40_000*4; 

`ifdef GPHY_IMPROVED_DESER
realtime bit_time_sample_log[11];
realtime avg_bit_time_10,avg_bit_time_8,avg_bit_time_4;

bit bit_time_log_lock; 

initial begin 
  bit_time_log_lock = 0;
end

longint debug_half_period;
assign debug_half_period = half_period;

longint debug_avg_bit_time_10,debug_avg_bit_time_8,debug_avg_bit_time_4;
assign debug_avg_bit_time_10 = avg_bit_time_10;
assign debug_avg_bit_time_8  = avg_bit_time_8;
assign debug_avg_bit_time_4  = avg_bit_time_4;


always @(rxbitclk or negedge rst_n or negedge cdr_enable) begin
  if (!rst_n ) begin

    for(int i = 0; i < 11; i++) begin
      bit_time_sample_log[i] = 0;
    end

    bit_time_log_lock = 0;
  end else if (cdr_enable === 0) begin
    
    for(int i = 0; i < 11; i++) begin
      bit_time_sample_log[i] = 0;
    end

    bit_time_log_lock = 0;

  end else begin
    bit_time_sample_log[10] = bit_time_sample_log[9];
    bit_time_sample_log[9]  = bit_time_sample_log[8];
    bit_time_sample_log[8]  = bit_time_sample_log[7];
    bit_time_sample_log[7]  = bit_time_sample_log[6];
    bit_time_sample_log[6]  = bit_time_sample_log[5];
    bit_time_sample_log[5]  = bit_time_sample_log[4];
    bit_time_sample_log[4]  = bit_time_sample_log[3];
    bit_time_sample_log[3]  = bit_time_sample_log[2];
    bit_time_sample_log[2]  = bit_time_sample_log[1];
    bit_time_sample_log[1]  = bit_time_sample_log[0];
    bit_time_sample_log[0]  = $realtime;

    if(bit_time_sample_log[10] != 0) begin

      avg_bit_time_10 = bit_time_sample_log[0] - bit_time_sample_log[10];
      avg_bit_time_8  = bit_time_sample_log[0] - bit_time_sample_log[8];
      avg_bit_time_4  = bit_time_sample_log[0] - bit_time_sample_log[4];

      bit_time_log_lock = 1;

    end

  end
end

always @(posedge int_recvdclk or negedge rst_n)
begin
  if (!rst_n) begin
      half_period <= #TP 40_000*4;
  end else if ( cdr_enable === 0 ) begin
    if (current_rate > 4)                      half_period <= #TP bit_time*2; else  // this is pam4 ser gen6
    if (current_rate > 1 && current_rate <= 4) half_period <= #TP bit_time*4; else  // gen3,4,5
                                               half_period <= #TP bit_time*5;       // gen1,2
  end else begin
     if (bit_time_log_lock) begin     
        if (current_rate > 4)                      half_period <= #TP avg_bit_time_4/2; else  // this is pam4 ser gen6
        if (current_rate > 1 && current_rate <= 4) half_period <= #TP avg_bit_time_8/2; else  // gen3,4,5
                                                   half_period <= #TP avg_bit_time_10/2;       // gen1,2
     end else begin
        half_period <= #TP half_period;
     end   
  end    
end  

`else // !GPHY_IMPROVED_DESER

always @(posedge int_recvdclk or negedge rst_n)
begin
  if (!rst_n) begin
      half_period <= #TP 40_000*4;
  end else begin
     if (bit_time_lock) begin     
        if (current_rate > 4)                      half_period <= #TP bit_time*2; else  // this is pam4 ser gen6
        if (current_rate > 1 && current_rate <= 4) half_period <= #TP bit_time*4; else  // gen3,4,5
                                                   half_period <= #TP bit_time*5;       // gen1,2
     end else begin
        half_period <= #TP half_period;
     end   
  end    
end  
`endif // GPHY_IMPROVED_DESER

initial int_recvdclk = 1'b1; 

//
// Debug for signals
//
bit debug_disable_rx_queue_less_warning;

bit debug_timing_at_capture_serial_queue;
int debug_queue_size;
longint debug_bit_time;
longint debug_rxp_delta;
longint debug_first_bit_time;
longint debug_sub_realtime_rxbitclk_at_rx_sample_line_change;
longint debug_sub_rxbitclk_rxp_time;
longint debug_sub_rxbitclk_rxn_time;


assign debug_bit_time = bit_time;
assign debug_rxp_delta = rxp_delta;
assign debug_first_bit_time = first_bit_time;
assign debug_sub_rxbitclk_rxp_time = rxbitclk_sample - sample_rxp_time;
assign debug_sub_rxbitclk_rxn_time = rxbitclk_sample - sample_rxn_time;

always @(rx_sample_line) begin
  debug_sub_realtime_rxbitclk_at_rx_sample_line_change = $realtime - rxbitclk_sample;
end

initial begin
  debug_timing_at_capture_serial_queue = 0;
  debug_queue_size = 0;
  debug_disable_rx_queue_less_warning = 0;
end

// Debug checker for rx queue.
always @(posedge debug_timing_at_capture_serial_queue)
begin
  if(rst_n === 0 || rate_changing) begin
    debug_timing_at_capture_serial_queue = 0;
    debug_queue_size = 0;
  end
  else if(debug_disable_rx_queue_less_warning == 0 && rxn !== 1'bz && rxp !== 1'bz && pop_enable && align_en && debug_queue_size < wordlen) begin
    $warning("%0t: warning rx serial queue: debug_queue_size(%0d) is less than wordlen(%0d). This warning is disabled once this warning happened. This warning is enabled after reset or rate change.",$time,debug_queue_size,wordlen);
    debug_disable_rx_queue_less_warning = 1;
  end
end

always begin : create_symbol_recvdclk
   if (rst_n === 0) begin
     int_recvdclk = 1'b1;
     rxdata_10b_int = 10'b0;
     #1ns ;
   end else if (rst_n === 1)
   begin
      int_recvdclk = 1'b1;
      #(half_period);
      debug_queue_size = rx_q.size();
      debug_timing_at_capture_serial_queue = 1;

      for (int i=0; i< wordlen ; i=i+1) 
          rxdata_10b_int[i] = (pop_enable && rx_q.size() > 0) ? rx_q.pop_front()^int_rxpolarity : 1'b0;
      
      int_recvdclk = 1'b0;
      #(half_period);  

      debug_timing_at_capture_serial_queue = 0;

    end else begin
      int_recvdclk = 1'b1;
      rxdata_10b_int = 10'b0;
      #1ns ;
    end  
end

assign recvdclk = int_recvdclk && !recvdclk_stopped;

`ifdef TO_DEBUG_RX_SERIAL_DATA
// This code can use to debug rx serial data when the controller uses serdes mode at PHY IOP.
// To use this code, the following should be prepared.
//   1. To add TO_DEBUG_RX_SERIAL_DATA macro in compile.f. 
//   2. To set PCS_DATA_WD data below. PCS_DATA_WD is pipe_tx_data bit width on DUT. As default, PCS_DATA_WD is set to 80. 
// This code is able to compare the pipe_tx_data on DUT and the rx serial data(any debug_seri_para_rx_serial signals) on GPHY.
// The pipe_tx_data on DUT should match any debug_seri_para_rx_serial because the signals sample rx serials.
// The debug_seri_para_rx_serial signal is composed of two-dimensional array.First item in aray indicates bit shift on debug_master_rx_serial_debug_queue the rx serial data is stored.
// For instance, debug_seri_para_rx_serial[0] is 0 right bit  data on debug_master_rx_serial_debug_queue. debug_seri_para_rx_serial[1] is 1 bit old data on debug_master_rx_serial_debug_queue.

localparam PCS_DATA_WD   = 80;

reg [PCS_DATA_WD * 2 - 1:0] debug_master_rx_serial_debug_queue;
reg [PCS_DATA_WD - 1:0][PCS_DATA_WD - 1:0] debug_seri_para_rx_serial;
int debug_seri_para_count_update_timing;
int data_width;

always @(rxbitclk)
begin
  if (!rst_n) begin
    debug_master_rx_serial_debug_queue = 0;
    debug_seri_para_rx_serial = 0;
    debug_seri_para_count_update_timing = 0;
  end else if (!align_en) begin
    debug_master_rx_serial_debug_queue = 0;
    debug_seri_para_rx_serial = 0;
    debug_seri_para_count_update_timing = 0;
  end else if (!rxelecidle_unfiltered && align_en && bit_time_lock) begin
    data_width = (1 << rxwidth) * wordlen;

    if (pam4_ser) begin
    `ifdef GPHY_PAM4_DIFF_PAIR_MSB_IS_DATAP
      debug_master_rx_serial_debug_queue = {rxp,rxn,debug_master_rx_serial_debug_queue[PCS_DATA_WD * 2 - 1:2]};
    `else
      debug_master_rx_serial_debug_queue = {rxn,rxp,debug_master_rx_serial_debug_queue[PCS_DATA_WD * 2 - 1:2]}; 
    `endif // GPHY_PAM4_DIFF_PAIR_MSB_IS_DATAP
    end else begin
      debug_master_rx_serial_debug_queue = {rxp,debug_master_rx_serial_debug_queue[PCS_DATA_WD * 2 - 1:1]}; 
    end

    debug_seri_para_count_update_timing++;

    if(debug_seri_para_count_update_timing == data_width || (pam4_ser && debug_seri_para_count_update_timing * 2 == data_width)) begin
      debug_seri_para_count_update_timing = 0;

      debug_seri_para_rx_serial = 0;

      if(wordlen == 10) begin
        // Gen1/Gen2
        for(int i = 0; i < data_width; i++) begin
          for(int t = 0; t < data_width; t++) begin
            debug_seri_para_rx_serial[i][data_width - 1 - t] = debug_master_rx_serial_debug_queue[ PCS_DATA_WD * 2 - 1 - i - t];
          end
        end
      end
      else begin
        // Gen3/ later
        for(int i = 0; i < data_width; i++) begin
          for(int x = 0; x < data_width/wordlen; x++) begin
            debug_seri_para_rx_serial[i][ (data_width/wordlen) * 10 - 1 - (10 * x) -:10] = { 2'b00, debug_master_rx_serial_debug_queue[ PCS_DATA_WD * 2 - 1 - (8 * x) - i -: 8] };
          end
        end
      end
    end // if(debug_seri_para_count_update_timing == data_width || (pam4_ser && debug_seri_para_count_update_timing * 2 == data_width)) begin
  end 
end



`endif // TO_DEBUG_RX_SERIAL_DATA


// divide recvdclk by 2
always @(posedge recvdclk or negedge rst_n)
begin
   if (!rst_n) begin
      recvdclk_div2 = 1'b1;
      #1ns ;
   end else begin
      recvdclk_div2 = !recvdclk_div2;
   end
end

// divide recvdclk by 4
always @(posedge recvdclk_div2 or negedge rst_n)
begin
   if (!rst_n) begin
      recvdclk_div4 = 1'b1;
      #1ns ;
   end else begin
      recvdclk_div4 = !recvdclk_div4;
   end
end

// divide recvdclk by 8
always @(posedge recvdclk_div4 or negedge rst_n)
begin
   if (!rst_n) begin
      recvdclk_div8 = 1'b1;
      #1ns ;
   end else begin
      recvdclk_div8 = !recvdclk_div8;
   end
end

// divide recvdclk by 16
always @(posedge recvdclk_div8 or negedge rst_n)
begin
   if (!rst_n) begin
      recvdclk_div16 = 1'b1;
      #1ns ;
   end else begin
      recvdclk_div16 = !recvdclk_div16;
   end
end

// divide recvdclk by 32
always @(posedge recvdclk_div16 or negedge rst_n)
begin
   if (!rst_n) begin
      recvdclk_div32 = 1'b1;
      #1ns ;
   end else begin
      recvdclk_div32 = !recvdclk_div32;
   end
end

// sync the selection for clk on the negedge of fastest clk and all other clks are in 0
always @(posedge int_recvdclk or negedge rst_n or rxwidth)
begin
   if (!rst_n)                                                                              rxwidth_sync <= #TP rxwidth; else
   if (recvdclk_stopped)                                                                    rxwidth_sync <= #TP rxwidth; else
                                                                                            rxwidth_sync <= #TP rxwidth_sync;
        
end  


assign recvdclk_pipe = !serdes_arch  ? recvdclk :
                          (rxwidth_sync == 0 ? recvdclk       :
                           rxwidth_sync == 1 ? recvdclk_div2  :
                           rxwidth_sync == 2 ? recvdclk_div4  :
                           rxwidth_sync == 3 ? recvdclk_div8  : 
                           rxwidth_sync == 4 ? recvdclk_div16 : recvdclk_div32
                          ); 

//=============================================================================
// Register aligned RX data -- swizzle at this point for proper ordering from
// the wire.
//=============================================================================
 
always @(posedge recvdclk or negedge rst_n)
begin
  if (!rst_n)  begin
     rxdata_10b       <= #TP '0;
     serdes_rx_valid  <= #TP 0; 
  end else if (!align_en)   begin
     rxdata_10b       <= #TP '0;
     serdes_rx_valid  <= #TP 0;
  end else if (bit_time_lock && pop_enable)   begin 
     rxdata_10b       <= #TP rxdata_10b_int;
     serdes_rx_valid  <= #TP 1'b1;   
  end else  begin
     rxdata_10b       <= #TP rxdata_10b;
     serdes_rx_valid  <= #TP 1'b0;
  end
end

// ========================================================================
// Synchronize the pma reset signal into the receive clock domain.
// ========================================================================   
reg    sync_rcvdrst_n_r1;          // needed to retime reset to RX domain
reg    sync_rcvdrst_n_r2;          // needed to retime reset to RX domain

assign rcvdrst_n = (sync_rcvdrst_n_r2 & rst_n); // async assert; synch deassert

always @(posedge recvdclk or negedge rst_n)
    if (!rst_n) begin
        sync_rcvdrst_n_r1   <= #TP 1'b0;          // reset when "reset"
        sync_rcvdrst_n_r2   <= #TP 1'b0;          // reset when "reset"
    end else begin
        sync_rcvdrst_n_r1   <= #TP rst_n;
        sync_rcvdrst_n_r2   <= #TP sync_rcvdrst_n_r1;
    end   
   
endmodule: DWC_pcie_gphy_deser

