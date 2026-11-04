
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

//
// Description : DWC_pcie_ctl_bcm46_b.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: f8375097
//
////////////////////////////////////////////////////////////////////////////////

module DWC_pcie_ctl_bcm46_b(
                gen,
                correct_n,
                datain,
                chkin,
                fixdata,
                err_detect,
                err_multpl,
                dataout,
                chkout,
                syndout);

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

parameter integer WIDTH = 32;

input                   gen;            // Active high check-bit generate control input port
input                   correct_n;      // Active low bit correction control input port
input  [WIDTH-1:0]      datain;         // Data input port (for write, read & scrub)
input  [6:0]            chkin;          // Check bit input port (for read)
output [WIDTH-1:0]      fixdata;        // Data fixed flag port (one-hot)
output                  err_detect;     // Active high error detect output
output                  err_multpl;     // Active high multiple bit error detect output
output [WIDTH-1:0]      dataout;        // Data output port (for read & scrub)
output [6:0]            chkout;         // Check bit output port (for write & scrub)
output [6:0]            syndout;        // Error syndrome output port (for error logging)

wire   [6:0]            chkout_int;
wire   [6:0]            syndout_int;
wire   [6:0]            fixchk;
wire   [57:0]           syndec;
reg    [63:0]           dat_in;
wire   [WIDTH-1:0]      fixdata;


  assign chkout_int[0] = dat_in[0]  ^ dat_in[4]  ^ dat_in[6]  ^ dat_in[7]  ^
                         dat_in[8]  ^ dat_in[9]  ^ dat_in[11] ^ dat_in[14] ^
                         dat_in[17] ^ dat_in[18] ^ dat_in[19] ^ dat_in[21] ^
                         dat_in[26] ^ dat_in[28] ^ dat_in[29] ^ dat_in[31] ^
                         dat_in[33] ^ dat_in[35] ^ dat_in[37] ^ dat_in[38] ^
                         dat_in[40] ^ dat_in[41] ^ dat_in[43] ^ dat_in[45] ^
                         dat_in[46] ^ dat_in[47] ^ dat_in[48] ^ dat_in[49] ^
                         dat_in[52] ^ dat_in[54] ^ dat_in[56];

  assign chkout_int[1] = dat_in[0]  ^ dat_in[1]  ^ dat_in[2]  ^ dat_in[4]  ^
                         dat_in[6]  ^ dat_in[8]  ^ dat_in[10] ^ dat_in[12] ^
                         dat_in[16] ^ dat_in[17] ^ dat_in[18] ^ dat_in[20] ^
                         dat_in[22] ^ dat_in[24] ^ dat_in[26] ^ dat_in[28] ^
                         dat_in[32] ^ dat_in[36] ^ dat_in[38] ^ dat_in[39] ^
                         dat_in[41] ^ dat_in[43] ^ dat_in[44] ^ dat_in[45] ^
                         dat_in[46] ^ dat_in[48] ^ dat_in[49] ^ dat_in[51] ^
                         dat_in[53] ^ dat_in[54] ^ dat_in[55];

  assign chkout_int[2] =~dat_in[0]  ^ dat_in[3]  ^ dat_in[4]  ^ dat_in[7]  ^
                         dat_in[9]  ^ dat_in[10] ^ dat_in[13] ^ dat_in[15] ^
                         dat_in[16] ^ dat_in[19] ^ dat_in[20] ^ dat_in[23] ^
                         dat_in[25] ^ dat_in[26] ^ dat_in[29] ^ dat_in[31] ^
                         dat_in[32] ^ dat_in[34] ^ dat_in[36] ^ dat_in[37] ^
                         dat_in[39] ^ dat_in[40] ^ dat_in[43] ^ dat_in[45] ^
                         dat_in[46] ^ dat_in[47] ^ dat_in[48] ^ dat_in[49] ^
                         dat_in[50] ^ dat_in[53] ^ dat_in[55];

  assign chkout_int[3] =~dat_in[0]  ^ dat_in[1]  ^ dat_in[5]  ^ dat_in[6]  ^
                         dat_in[7]  ^ dat_in[11] ^ dat_in[12] ^ dat_in[13] ^
                         dat_in[16] ^ dat_in[17] ^ dat_in[21] ^ dat_in[22] ^
                         dat_in[23] ^ dat_in[27] ^ dat_in[28] ^ dat_in[29] ^
                         dat_in[32] ^ dat_in[34] ^ dat_in[35] ^ dat_in[39] ^
                         dat_in[40] ^ dat_in[41] ^ dat_in[42] ^ dat_in[45] ^
                         dat_in[46] ^ dat_in[47] ^ dat_in[49] ^ dat_in[50] ^
                         dat_in[51] ^ dat_in[52] ^ dat_in[55];

  assign chkout_int[4] = dat_in[2]  ^ dat_in[3]  ^ dat_in[4]  ^ dat_in[5]  ^
                         dat_in[6]  ^ dat_in[7]  ^ dat_in[14] ^ dat_in[15] ^
                         dat_in[18] ^ dat_in[19] ^ dat_in[20] ^ dat_in[21] ^
                         dat_in[22] ^ dat_in[23] ^ dat_in[30] ^ dat_in[31] ^
                         dat_in[32] ^ dat_in[33] ^ dat_in[39] ^ dat_in[40] ^
                         dat_in[41] ^ dat_in[42] ^ dat_in[43] ^ dat_in[44] ^
                         dat_in[46] ^ dat_in[49] ^ dat_in[50] ^ dat_in[51] ^
                         dat_in[52] ^ dat_in[53] ^ dat_in[54];

  assign chkout_int[5] = dat_in[8]  ^ dat_in[9]  ^ dat_in[10] ^ dat_in[11] ^
                         dat_in[12] ^ dat_in[13] ^ dat_in[14] ^ dat_in[15] ^
                         dat_in[24] ^ dat_in[25] ^ dat_in[26] ^ dat_in[27] ^
                         dat_in[28] ^ dat_in[29] ^ dat_in[30] ^ dat_in[31] ^
                         dat_in[39] ^ dat_in[40] ^ dat_in[41] ^ dat_in[42] ^
                         dat_in[43] ^ dat_in[44] ^ dat_in[45] ^ dat_in[49] ^
                         dat_in[50] ^ dat_in[51] ^ dat_in[52] ^ dat_in[53] ^
                         dat_in[54] ^ dat_in[55] ^ dat_in[56];

  assign chkout_int[6] = dat_in[0]  ^ dat_in[1]  ^ dat_in[2]  ^ dat_in[3]  ^
                         dat_in[4]  ^ dat_in[5]  ^ dat_in[6]  ^ dat_in[7]  ^
                         dat_in[24] ^ dat_in[25] ^ dat_in[26] ^ dat_in[27] ^
                         dat_in[28] ^ dat_in[29] ^ dat_in[30] ^ dat_in[31] ^
                         dat_in[32] ^ dat_in[33] ^ dat_in[34] ^ dat_in[35] ^
                         dat_in[36] ^ dat_in[37] ^ dat_in[38] ^ dat_in[49] ^
                         dat_in[50] ^ dat_in[51] ^ dat_in[52] ^ dat_in[53] ^
                         dat_in[54] ^ dat_in[55] ^ dat_in[56];

  assign syndec[17] = (syndout_int == 7'b0001011)? 1'b1 : 1'b0;
  assign syndec[1] = (syndout_int == 7'b1001010)? 1'b1 : 1'b0;
  assign syndec[14] = (syndout_int == 7'b0110001)? 1'b1 : 1'b0;
  assign syndec[18] = (syndout_int == 7'b0010011)? 1'b1 : 1'b0;
  assign syndec[37] = (syndout_int == 7'b1000101)? 1'b1 : 1'b0;
  assign syndec[30] = (syndout_int == 7'b1110000)? 1'b1 : 1'b0;
  assign syndec[45] = (syndout_int == 7'b0101111)? 1'b1 : 1'b0;
  assign syndec[32] = (syndout_int == 7'b1011110)? 1'b1 : 1'b0;
  assign syndec[13] = (syndout_int == 7'b0101100)? 1'b1 : 1'b0;
  assign syndec[9] = (syndout_int == 7'b0100101)? 1'b1 : 1'b0;
  assign syndec[55] = (syndout_int == 7'b1101110)? 1'b1 : 1'b0;
  assign syndec[42] = (syndout_int == 7'b0111000)? 1'b1 : 1'b0;
  assign syndec[38] = (syndout_int == 7'b1000011)? 1'b1 : 1'b0;
  assign syndec[56] = (syndout_int == 7'b1100001)? 1'b1 : 1'b0;
  assign syndec[7] = (syndout_int == 7'b1011101)? 1'b1 : 1'b0;
  assign syndec[36] = (syndout_int == 7'b1000110)? 1'b1 : 1'b0;
  assign syndec[47] = (syndout_int == 7'b0001101)? 1'b1 : 1'b0;
  assign fixchk[4] = (syndout_int == 7'b0010000)? 1'b1 : 1'b0;
  assign syndec[8] = (syndout_int == 7'b0100011)? 1'b1 : 1'b0;
  assign syndec[39] = (syndout_int == 7'b0111110)? 1'b1 : 1'b0;
  assign syndec[22] = (syndout_int == 7'b0011010)? 1'b1 : 1'b0;
  assign syndec[44] = (syndout_int == 7'b0110010)? 1'b1 : 1'b0;
  assign syndec[4] = (syndout_int == 7'b1010111)? 1'b1 : 1'b0;
  assign syndec[35] = (syndout_int == 7'b1001001)? 1'b1 : 1'b0;
  assign syndec[40] = (syndout_int == 7'b0111101)? 1'b1 : 1'b0;
  assign syndec[27] = (syndout_int == 7'b1101000)? 1'b1 : 1'b0;
  assign syndec[2] = (syndout_int == 7'b1010010)? 1'b1 : 1'b0;
  assign syndec[48] = (syndout_int == 7'b0000111)? 1'b1 : 1'b0;
  assign syndec[51] = (syndout_int == 7'b1111010)? 1'b1 : 1'b0;
  assign syndec[12] = (syndout_int == 7'b0101010)? 1'b1 : 1'b0;
  assign syndec[33] = (syndout_int == 7'b1010001)? 1'b1 : 1'b0;
  assign fixchk[2] = (syndout_int == 7'b0000100)? 1'b1 : 1'b0;
  assign syndec[23] = (syndout_int == 7'b0011100)? 1'b1 : 1'b0;
  assign syndec[31] = (syndout_int == 7'b1110101)? 1'b1 : 1'b0;
  assign syndec[28] = (syndout_int == 7'b1101011)? 1'b1 : 1'b0;
  assign syndec[0] = (syndout_int == 7'b1001111)? 1'b1 : 1'b0;
  assign syndec[3] = (syndout_int == 7'b1010100)? 1'b1 : 1'b0;
  assign syndec[15] = (syndout_int == 7'b0110100)? 1'b1 : 1'b0;
  assign syndec[43] = (syndout_int == 7'b0110111)? 1'b1 : 1'b0;
  assign syndec[54] = (syndout_int == 7'b1110011)? 1'b1 : 1'b0;
  assign syndec[26] = (syndout_int == 7'b1100111)? 1'b1 : 1'b0;
  assign syndec[29] = (syndout_int == 7'b1101101)? 1'b1 : 1'b0;
  assign syndec[25] = (syndout_int == 7'b1100100)? 1'b1 : 1'b0;
  assign syndec[24] = (syndout_int == 7'b1100010)? 1'b1 : 1'b0;
  assign fixchk[3] = (syndout_int == 7'b0001000)? 1'b1 : 1'b0;
  assign syndec[57] = 1'b0;
  assign syndec[5] = (syndout_int == 7'b1011000)? 1'b1 : 1'b0;
  assign syndec[21] = (syndout_int == 7'b0011001)? 1'b1 : 1'b0;
  assign syndec[52] = (syndout_int == 7'b1111001)? 1'b1 : 1'b0;
  assign syndec[16] = (syndout_int == 7'b0001110)? 1'b1 : 1'b0;
  assign syndec[41] = (syndout_int == 7'b0111011)? 1'b1 : 1'b0;
  assign syndec[19] = (syndout_int == 7'b0010101)? 1'b1 : 1'b0;
  assign syndec[6] = (syndout_int == 7'b1011011)? 1'b1 : 1'b0;
  assign syndec[46] = (syndout_int == 7'b0011111)? 1'b1 : 1'b0;
  assign syndec[34] = (syndout_int == 7'b1001100)? 1'b1 : 1'b0;
  assign syndec[53] = (syndout_int == 7'b1110110)? 1'b1 : 1'b0;
  assign syndec[50] = (syndout_int == 7'b1111100)? 1'b1 : 1'b0;
  assign syndec[49] = (syndout_int == 7'b1111111)? 1'b1 : 1'b0;
  assign fixchk[1] = (syndout_int == 7'b0000010)? 1'b1 : 1'b0;
  assign syndec[11] = (syndout_int == 7'b0101001)? 1'b1 : 1'b0;
  assign fixchk[0] = (syndout_int == 7'b0000001)? 1'b1 : 1'b0;
  assign fixchk[5] = (syndout_int == 7'b0100000)? 1'b1 : 1'b0;
  assign syndec[20] = (syndout_int == 7'b0010110)? 1'b1 : 1'b0;
  assign fixchk[6] = (syndout_int == 7'b1000000)? 1'b1 : 1'b0;
  assign syndec[10] = (syndout_int == 7'b0100110)? 1'b1 : 1'b0;

  always @ (datain) begin : td_PROC

    integer i;

    for (i=0 ; i <= 63 ; i=i+1) begin
      if (i < WIDTH)
        dat_in[i] = datain[i];
      else
        dat_in[i] = 1'b0;
    end
  end

  assign syndout_int = chkout_int ^ chkin;

  assign err_detect = ~gen & ( |syndout_int );

  assign err_multpl = err_detect & ( ~(^syndout_int) || (|syndec[57:WIDTH]) );

  assign fixdata = syndec[WIDTH-1:0];

  assign chkout = (gen == 1'b1)? chkout_int : (correct_n == 1'b0)? chkin ^ fixchk : chkin;

  assign dataout = ((gen == 1'b0) && (correct_n == 1'b0))? datain ^ fixdata : datain;

  assign syndout = syndout_int;

// spyglass enable_block W146
endmodule
