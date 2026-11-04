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
// ---   $DateTime: 2023/04/29 12:35:01 $
// ---   $Revision: #1 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/common/pseudo_random_generator.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------
// Pseudo Random Number Generator.
//  This module will generate (2^N)-1 random numbers with equal probability where N is number of bits
//  Random ranges could be from 0 to (2^N -2) OR 1 to (2^N -1) according to MIN parameter
//  It also generates specific random ranges from MIN to MAX.
//  MIN value is 0
//  MAX value is 1022
//
//  ####################
//  ### Special Case ###
//  ####################
//  when range needed from 0 to (2^N)-1 for ex from 0 to 15
//  bit width for rand_num value in instantiation needs to increased by 1 bit
//  for example from 0 to 15 will need 5-bits instead of 4-bits 
//  Parameter RAND_RANGE is 1 in this case and 0 otherwise
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module pseudo_random_generator 

#(
  parameter TP        = `TP ,
  parameter MAX       =  3  ,
  parameter MIN       =  0  , 
  parameter RAND_RANGE=((MIN==0) &&(2 << ($clog2(MAX+1) -1 ) == MAX+1))
) 
                              ( 
  input core_clk,
  input core_rst_n,
  input en,
  output [$clog2(MAX+1+RAND_RANGE)-1:0] rand_num  
                                                // Pseudo-random only generates 2^N-1 values as all 1's is illegal in XNOR-based LFSR 
                                                // As counter will remain locked-up in this state
                                                // MAX+1 is used to cover MAX= 2^N case
);

localparam N=$clog2(MAX+1+RAND_RANGE);            //Number of bit needed for the random generator counter 

logic [N-1:0] rand_num_s,rand_num_r,cnt_r;
logic taps;

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if (~core_rst_n) begin
    rand_num_r <= #TP '0;   //Initial value are all 0's
    cnt_r      <= #TP '0;
  end
  else if (en) begin
    rand_num_r <= #TP rand_num_s;
      if (rand_num_s > MAX || rand_num_s < MIN)
        if (cnt_r == '0 && MIN !=0 )
          cnt_r      <= #TP MIN;
        else if (cnt_r < MAX)
          cnt_r      <= #TP cnt_r+1;
        else
          cnt_r      <= #TP MIN;
      else
        cnt_r      <= #TP cnt_r;
  end
  else begin
    rand_num_r <= #TP rand_num_r;
    cnt_r      <= #TP cnt_r;
  end
end


//Shifting right and insert taps in the last bit
always_comb begin 
   rand_num_s = {taps, rand_num_r[N-1:1]};
end


//IF range start with 0 or 1 and number of random numbers needed is 2^N -1 so random numbers generated with equal probabilty
//Else : random numbers will be generated with almost equal probabilty using counter values in numbers smaller than MIN or larger than MAX
assign rand_num = ( (MIN == 0 || MIN == 1 ) && ((1+MAX-MIN) == ( (2<< (N-1 )) -1 )) ) ? MIN + rand_num_r : (rand_num_r > MAX || rand_num_r < MIN ) ? cnt_r :rand_num_r; 


// Application of polynomial coefficient according to polynomial taps table
// LFSR XNOR-based
generate 
if      ( N ==2 )
  assign taps = ~( rand_num_r[1] ^ rand_num_r[0] );
else if ( N ==3 )
  assign taps = ~( rand_num_r[1] ^ rand_num_r[0] );
else if ( N ==4 )
  assign taps = ~( rand_num_r[1] ^ rand_num_r[0] );
else if ( N ==5 )
  assign taps = ~( rand_num_r[2] ^ rand_num_r[0] );
else if ( N ==6 )
  assign taps = ~( rand_num_r[1] ^ rand_num_r[0] );
else if ( N ==7 )
  assign taps = ~( rand_num_r[1] ^ rand_num_r[0] );
else if ( N ==8 )
  assign taps = ~( rand_num_r[4] ^ rand_num_r[3] ^ rand_num_r[2] ^ rand_num_r[0] );
else if ( N ==9 )
  assign taps = ~( rand_num_r[4] ^ rand_num_r[0] );
else if ( N ==10 )
  assign taps = ~( rand_num_r[3] ^ rand_num_r[0] );
endgenerate

endmodule
