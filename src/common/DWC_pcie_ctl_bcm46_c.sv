
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
// Description : DWC_pcie_ctl_bcm46_c.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: f807ca77
//
////////////////////////////////////////////////////////////////////////////////

module DWC_pcie_ctl_bcm46_c(
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

parameter integer WIDTH = 64;

input                   gen;            // Active high check-bit generate control input port
input                   correct_n;      // Active low bit correction control input port
input  [WIDTH-1:0]      datain;         // Data input port (for write, read & scrub)
input  [7:0]            chkin;          // Check bit input port (for read)
output [WIDTH-1:0]      fixdata;        // Data fixed flag port (one-hot)
output                  err_detect;     // Active high error detect output
output                  err_multpl;     // Active high multiple bit error detect output
output [WIDTH-1:0]      dataout;        // Data output port (for read & scrub)
output [7:0]            chkout;         // Check bit output port (for write & scrub)
output [7:0]            syndout;        // Error syndrome output port (for error logging)

wire   [7:0]            chkout_int;
wire   [7:0]            syndout_int;
wire   [7:0]            fixchk;
wire   [120:0]          syndec;
reg    [127:0]          dat_in;
wire   [WIDTH-1:0]      fixdata;

  assign chkout_int[0] = dat_in[1] ^ dat_in[101] ^ dat_in[103] ^ dat_in[105] ^
                          dat_in[107] ^ dat_in[109] ^ dat_in[11] ^ dat_in[112] ^
                          dat_in[114] ^ dat_in[115] ^ dat_in[117] ^ dat_in[119] ^
                          dat_in[14] ^ dat_in[17] ^ dat_in[18] ^ dat_in[19] ^
                          dat_in[2] ^ dat_in[21] ^ dat_in[24] ^ dat_in[25] ^
                          dat_in[27] ^ dat_in[3] ^ dat_in[30] ^ dat_in[32] ^
                          dat_in[36] ^ dat_in[38] ^ dat_in[39] ^ dat_in[42] ^
                          dat_in[44] ^ dat_in[45] ^ dat_in[47] ^ dat_in[48] ^
                          dat_in[5] ^ dat_in[52] ^ dat_in[54] ^ dat_in[55] ^
                          dat_in[58] ^ dat_in[60] ^ dat_in[61] ^ dat_in[63] ^
                          dat_in[65] ^ dat_in[67] ^ dat_in[69] ^ dat_in[70] ^
                          dat_in[71] ^ dat_in[74] ^ dat_in[76] ^ dat_in[78] ^
                          dat_in[8] ^ dat_in[80] ^ dat_in[82] ^ dat_in[84] ^
                          dat_in[85] ^ dat_in[86] ^ dat_in[89] ^ dat_in[9] ^
                          dat_in[91] ^ dat_in[93] ^ dat_in[94] ^ dat_in[95] ^
                          dat_in[96] ^ dat_in[98] ^ dat_in[99];

  assign chkout_int[1] = dat_in[0] ^ dat_in[1] ^ dat_in[10] ^ dat_in[101] ^
                          dat_in[102] ^ dat_in[103] ^ dat_in[105] ^ dat_in[109] ^
                          dat_in[111] ^ dat_in[113] ^ dat_in[115] ^ dat_in[117] ^
                          dat_in[118] ^ dat_in[119] ^ dat_in[12] ^ dat_in[16] ^
                          dat_in[17] ^ dat_in[18] ^ dat_in[2] ^ dat_in[20] ^
                          dat_in[22] ^ dat_in[24] ^ dat_in[26] ^ dat_in[28] ^
                          dat_in[32] ^ dat_in[33] ^ dat_in[34] ^ dat_in[36] ^
                          dat_in[38] ^ dat_in[4] ^ dat_in[40] ^ dat_in[42] ^
                          dat_in[44] ^ dat_in[48] ^ dat_in[49] ^ dat_in[50] ^
                          dat_in[52] ^ dat_in[54] ^ dat_in[56] ^ dat_in[58] ^
                          dat_in[6] ^ dat_in[60] ^ dat_in[64] ^ dat_in[68] ^
                          dat_in[70] ^ dat_in[71] ^ dat_in[73] ^ dat_in[75] ^
                          dat_in[76] ^ dat_in[77] ^ dat_in[79] ^ dat_in[8] ^
                          dat_in[83] ^ dat_in[85] ^ dat_in[86] ^ dat_in[88] ^
                          dat_in[90] ^ dat_in[91] ^ dat_in[92] ^ dat_in[94] ^
                          dat_in[96] ^ dat_in[97] ^ dat_in[99];

  assign chkout_int[2] = ~dat_in[0] ^ dat_in[10] ^ dat_in[101] ^ dat_in[103] ^
                          dat_in[105] ^ dat_in[107] ^ dat_in[109] ^ dat_in[110] ^
                          dat_in[113] ^ dat_in[114] ^ dat_in[117] ^ dat_in[119] ^
                          dat_in[13] ^ dat_in[15] ^ dat_in[16] ^ dat_in[19] ^
                          dat_in[20] ^ dat_in[23] ^ dat_in[25] ^ dat_in[26] ^
                          dat_in[29] ^ dat_in[3] ^ dat_in[31] ^ dat_in[32] ^
                          dat_in[35] ^ dat_in[36] ^ dat_in[39] ^ dat_in[4] ^
                          dat_in[41] ^ dat_in[42] ^ dat_in[45] ^ dat_in[47] ^
                          dat_in[48] ^ dat_in[51] ^ dat_in[52] ^ dat_in[55] ^
                          dat_in[57] ^ dat_in[58] ^ dat_in[61] ^ dat_in[63] ^
                          dat_in[64] ^ dat_in[66] ^ dat_in[68] ^ dat_in[69] ^
                          dat_in[7] ^ dat_in[71] ^ dat_in[72] ^ dat_in[75] ^
                          dat_in[77] ^ dat_in[79] ^ dat_in[81] ^ dat_in[83] ^
                          dat_in[84] ^ dat_in[86] ^ dat_in[87] ^ dat_in[9] ^
                          dat_in[90] ^ dat_in[92] ^ dat_in[94] ^ dat_in[95] ^
                          dat_in[96] ^ dat_in[97] ^ dat_in[98];

  assign chkout_int[3] = ~dat_in[0] ^ dat_in[1] ^ dat_in[100] ^ dat_in[103] ^
                          dat_in[105] ^ dat_in[107] ^ dat_in[108] ^ dat_in[11] ^
                          dat_in[113] ^ dat_in[114] ^ dat_in[115] ^ dat_in[116] ^
                          dat_in[119] ^ dat_in[12] ^ dat_in[13] ^ dat_in[16] ^
                          dat_in[17] ^ dat_in[21] ^ dat_in[22] ^ dat_in[23] ^
                          dat_in[27] ^ dat_in[28] ^ dat_in[29] ^ dat_in[32] ^
                          dat_in[33] ^ dat_in[37] ^ dat_in[38] ^ dat_in[39] ^
                          dat_in[43] ^ dat_in[44] ^ dat_in[45] ^ dat_in[48] ^
                          dat_in[49] ^ dat_in[5] ^ dat_in[53] ^ dat_in[54] ^
                          dat_in[55] ^ dat_in[59] ^ dat_in[6] ^ dat_in[60] ^
                          dat_in[61] ^ dat_in[64] ^ dat_in[66] ^ dat_in[67] ^
                          dat_in[7] ^ dat_in[71] ^ dat_in[72] ^ dat_in[73] ^
                          dat_in[74] ^ dat_in[77] ^ dat_in[79] ^ dat_in[81] ^
                          dat_in[82] ^ dat_in[86] ^ dat_in[87] ^ dat_in[88] ^
                          dat_in[89] ^ dat_in[92] ^ dat_in[94] ^ dat_in[95] ^
                          dat_in[97] ^ dat_in[98] ^ dat_in[99];

  assign chkout_int[4] = dat_in[100] ^ dat_in[101] ^ dat_in[102] ^ dat_in[105] ^
                          dat_in[106] ^ dat_in[113] ^ dat_in[114] ^ dat_in[115] ^
                          dat_in[116] ^ dat_in[117] ^ dat_in[118] ^ dat_in[14] ^
                          dat_in[15] ^ dat_in[18] ^ dat_in[19] ^ dat_in[2] ^
                          dat_in[20] ^ dat_in[21] ^ dat_in[22] ^ dat_in[23] ^
                          dat_in[3] ^ dat_in[30] ^ dat_in[31] ^ dat_in[34] ^
                          dat_in[35] ^ dat_in[36] ^ dat_in[37] ^ dat_in[38] ^
                          dat_in[39] ^ dat_in[4] ^ dat_in[46] ^ dat_in[47] ^
                          dat_in[5] ^ dat_in[50] ^ dat_in[51] ^ dat_in[52] ^
                          dat_in[53] ^ dat_in[54] ^ dat_in[55] ^ dat_in[6] ^
                          dat_in[62] ^ dat_in[63] ^ dat_in[64] ^ dat_in[65] ^
                          dat_in[7] ^ dat_in[71] ^ dat_in[72] ^ dat_in[73] ^
                          dat_in[74] ^ dat_in[75] ^ dat_in[76] ^ dat_in[79] ^
                          dat_in[80] ^ dat_in[86] ^ dat_in[87] ^ dat_in[88] ^
                          dat_in[89] ^ dat_in[90] ^ dat_in[91] ^ dat_in[94] ^
                          dat_in[97] ^ dat_in[98] ^ dat_in[99];

  assign chkout_int[5] = dat_in[10] ^ dat_in[100] ^ dat_in[101] ^ dat_in[102] ^
                          dat_in[103] ^ dat_in[104] ^ dat_in[11] ^ dat_in[113] ^
                          dat_in[114] ^ dat_in[115] ^ dat_in[116] ^ dat_in[117] ^
                          dat_in[118] ^ dat_in[119] ^ dat_in[12] ^ dat_in[13] ^
                          dat_in[14] ^ dat_in[15] ^ dat_in[24] ^ dat_in[25] ^
                          dat_in[26] ^ dat_in[27] ^ dat_in[28] ^ dat_in[29] ^
                          dat_in[30] ^ dat_in[31] ^ dat_in[40] ^ dat_in[41] ^
                          dat_in[42] ^ dat_in[43] ^ dat_in[44] ^ dat_in[45] ^
                          dat_in[46] ^ dat_in[47] ^ dat_in[56] ^ dat_in[57] ^
                          dat_in[58] ^ dat_in[59] ^ dat_in[60] ^ dat_in[61] ^
                          dat_in[62] ^ dat_in[63] ^ dat_in[71] ^ dat_in[72] ^
                          dat_in[73] ^ dat_in[74] ^ dat_in[75] ^ dat_in[76] ^
                          dat_in[77] ^ dat_in[78] ^ dat_in[8] ^ dat_in[86] ^
                          dat_in[87] ^ dat_in[88] ^ dat_in[89] ^ dat_in[9] ^
                          dat_in[90] ^ dat_in[91] ^ dat_in[92] ^ dat_in[93] ^
                          dat_in[97] ^ dat_in[98] ^ dat_in[99];

  assign chkout_int[6] = dat_in[0] ^ dat_in[1] ^ dat_in[100] ^ dat_in[101] ^
                          dat_in[102] ^ dat_in[103] ^ dat_in[104] ^ dat_in[105] ^
                          dat_in[106] ^ dat_in[107] ^ dat_in[108] ^ dat_in[109] ^
                          dat_in[110] ^ dat_in[111] ^ dat_in[112] ^ dat_in[2] ^
                          dat_in[24] ^ dat_in[25] ^ dat_in[26] ^ dat_in[27] ^
                          dat_in[28] ^ dat_in[29] ^ dat_in[3] ^ dat_in[30] ^
                          dat_in[31] ^ dat_in[32] ^ dat_in[33] ^ dat_in[34] ^
                          dat_in[35] ^ dat_in[36] ^ dat_in[37] ^ dat_in[38] ^
                          dat_in[39] ^ dat_in[4] ^ dat_in[5] ^ dat_in[56] ^
                          dat_in[57] ^ dat_in[58] ^ dat_in[59] ^ dat_in[6] ^
                          dat_in[60] ^ dat_in[61] ^ dat_in[62] ^ dat_in[63] ^
                          dat_in[7] ^ dat_in[71] ^ dat_in[72] ^ dat_in[73] ^
                          dat_in[74] ^ dat_in[75] ^ dat_in[76] ^ dat_in[77] ^
                          dat_in[78] ^ dat_in[79] ^ dat_in[80] ^ dat_in[81] ^
                          dat_in[82] ^ dat_in[83] ^ dat_in[84] ^ dat_in[85] ^
                          dat_in[97] ^ dat_in[98] ^ dat_in[99];

  assign chkout_int[7] = dat_in[0] ^ dat_in[1] ^ dat_in[100] ^ dat_in[101] ^
                          dat_in[102] ^ dat_in[103] ^ dat_in[104] ^ dat_in[105] ^
                          dat_in[106] ^ dat_in[107] ^ dat_in[108] ^ dat_in[109] ^
                          dat_in[110] ^ dat_in[111] ^ dat_in[112] ^ dat_in[2] ^
                          dat_in[24] ^ dat_in[25] ^ dat_in[26] ^ dat_in[27] ^
                          dat_in[28] ^ dat_in[29] ^ dat_in[3] ^ dat_in[30] ^
                          dat_in[31] ^ dat_in[4] ^ dat_in[40] ^ dat_in[41] ^
                          dat_in[42] ^ dat_in[43] ^ dat_in[44] ^ dat_in[45] ^
                          dat_in[46] ^ dat_in[47] ^ dat_in[48] ^ dat_in[49] ^
                          dat_in[5] ^ dat_in[50] ^ dat_in[51] ^ dat_in[52] ^
                          dat_in[53] ^ dat_in[54] ^ dat_in[55] ^ dat_in[6] ^
                          dat_in[64] ^ dat_in[65] ^ dat_in[66] ^ dat_in[67] ^
                          dat_in[68] ^ dat_in[69] ^ dat_in[7] ^ dat_in[70] ^
                          dat_in[86] ^ dat_in[87] ^ dat_in[88] ^ dat_in[89] ^
                          dat_in[90] ^ dat_in[91] ^ dat_in[92] ^ dat_in[93] ^
                          dat_in[97] ^ dat_in[98] ^ dat_in[99];

  assign syndec[1] = (syndout_int == 8'b11001011)? 1'b1 : 1'b0;
  assign fixchk[7] = (syndout_int == 8'b10000000)? 1'b1 : 1'b0;
  assign syndec[107] = (syndout_int == 8'b11001101)? 1'b1 : 1'b0;
  assign syndec[76] = (syndout_int == 8'b01110011)? 1'b1 : 1'b0;
  assign syndec[48] = (syndout_int == 8'b10001111)? 1'b1 : 1'b0;
  assign syndec[52] = (syndout_int == 8'b10010111)? 1'b1 : 1'b0;
  assign syndec[96] = (syndout_int == 8'b00000111)? 1'b1 : 1'b0;
  assign syndec[69] = (syndout_int == 8'b10000101)? 1'b1 : 1'b0;
  assign syndec[40] = (syndout_int == 8'b10100010)? 1'b1 : 1'b0;
  assign syndec[56] = (syndout_int == 8'b01100010)? 1'b1 : 1'b0;
  assign syndec[97] = (syndout_int == 8'b11111110)? 1'b1 : 1'b0;
  assign syndec[50] = (syndout_int == 8'b10010010)? 1'b1 : 1'b0;
  assign syndec[70] = (syndout_int == 8'b10000011)? 1'b1 : 1'b0;
  assign syndec[7] = (syndout_int == 8'b11011100)? 1'b1 : 1'b0;
  assign fixchk[6] = (syndout_int == 8'b01000000)? 1'b1 : 1'b0;
  assign syndec[74] = (syndout_int == 8'b01111001)? 1'b1 : 1'b0;
  assign syndec[66] = (syndout_int == 8'b10001100)? 1'b1 : 1'b0;
  assign syndec[104] = (syndout_int == 8'b11100000)? 1'b1 : 1'b0;
  assign syndec[114] = (syndout_int == 8'b00111101)? 1'b1 : 1'b0;
  assign syndec[3] = (syndout_int == 8'b11010101)? 1'b1 : 1'b0;
  assign syndec[39] = (syndout_int == 8'b01011101)? 1'b1 : 1'b0;
  assign syndec[2] = (syndout_int == 8'b11010011)? 1'b1 : 1'b0;
  assign syndec[53] = (syndout_int == 8'b10011000)? 1'b1 : 1'b0;
  assign syndec[27] = (syndout_int == 8'b11101001)? 1'b1 : 1'b0;
  assign syndec[86] = (syndout_int == 8'b10111111)? 1'b1 : 1'b0;
  assign syndec[32] = (syndout_int == 8'b01001111)? 1'b1 : 1'b0;
  assign fixchk[1] = (syndout_int == 8'b00000010)? 1'b1 : 1'b0;
  assign fixchk[3] = (syndout_int == 8'b00001000)? 1'b1 : 1'b0;
  assign syndec[60] = (syndout_int == 8'b01101011)? 1'b1 : 1'b0;
  assign syndec[59] = (syndout_int == 8'b01101000)? 1'b1 : 1'b0;
  assign syndec[20] = (syndout_int == 8'b00010110)? 1'b1 : 1'b0;
  assign fixchk[5] = (syndout_int == 8'b00100000)? 1'b1 : 1'b0;
  assign syndec[94] = (syndout_int == 8'b00011111)? 1'b1 : 1'b0;
  assign syndec[116] = (syndout_int == 8'b00111000)? 1'b1 : 1'b0;
  assign syndec[112] = (syndout_int == 8'b11000001)? 1'b1 : 1'b0;
  assign syndec[21] = (syndout_int == 8'b00011001)? 1'b1 : 1'b0;
  assign syndec[44] = (syndout_int == 8'b10101011)? 1'b1 : 1'b0;
  assign syndec[42] = (syndout_int == 8'b10100111)? 1'b1 : 1'b0;
  assign syndec[117] = (syndout_int == 8'b00110111)? 1'b1 : 1'b0;
  assign syndec[84] = (syndout_int == 8'b01000101)? 1'b1 : 1'b0;
  assign syndec[30] = (syndout_int == 8'b11110001)? 1'b1 : 1'b0;
  assign syndec[4] = (syndout_int == 8'b11010110)? 1'b1 : 1'b0;
  assign syndec[79] = (syndout_int == 8'b01011110)? 1'b1 : 1'b0;
  assign syndec[110] = (syndout_int == 8'b11000100)? 1'b1 : 1'b0;
  assign syndec[80] = (syndout_int == 8'b01010001)? 1'b1 : 1'b0;
  assign syndec[0] = (syndout_int == 8'b11001110)? 1'b1 : 1'b0;
  assign syndec[54] = (syndout_int == 8'b10011011)? 1'b1 : 1'b0;
  assign syndec[67] = (syndout_int == 8'b10001001)? 1'b1 : 1'b0;
  assign syndec[119] = (syndout_int == 8'b00101111)? 1'b1 : 1'b0;
  assign syndec[9] = (syndout_int == 8'b00100101)? 1'b1 : 1'b0;
  assign syndec[81] = (syndout_int == 8'b01001100)? 1'b1 : 1'b0;
  assign syndec[22] = (syndout_int == 8'b00011010)? 1'b1 : 1'b0;
  assign syndec[29] = (syndout_int == 8'b11101100)? 1'b1 : 1'b0;
  assign syndec[102] = (syndout_int == 8'b11110010)? 1'b1 : 1'b0;
  assign syndec[83] = (syndout_int == 8'b01000110)? 1'b1 : 1'b0;
  assign syndec[88] = (syndout_int == 8'b10111010)? 1'b1 : 1'b0;
  assign syndec[90] = (syndout_int == 8'b10110110)? 1'b1 : 1'b0;
  assign syndec[91] = (syndout_int == 8'b10110011)? 1'b1 : 1'b0;
  assign syndec[63] = (syndout_int == 8'b01110101)? 1'b1 : 1'b0;
  assign syndec[41] = (syndout_int == 8'b10100100)? 1'b1 : 1'b0;
  assign syndec[17] = (syndout_int == 8'b00001011)? 1'b1 : 1'b0;
  assign syndec[113] = (syndout_int == 8'b00111110)? 1'b1 : 1'b0;
  assign syndec[25] = (syndout_int == 8'b11100101)? 1'b1 : 1'b0;
  assign syndec[23] = (syndout_int == 8'b00011100)? 1'b1 : 1'b0;
  assign syndec[13] = (syndout_int == 8'b00101100)? 1'b1 : 1'b0;
  assign syndec[14] = (syndout_int == 8'b00110001)? 1'b1 : 1'b0;
  assign syndec[106] = (syndout_int == 8'b11010000)? 1'b1 : 1'b0;
  assign syndec[64] = (syndout_int == 8'b10011110)? 1'b1 : 1'b0;
  assign syndec[72] = (syndout_int == 8'b01111100)? 1'b1 : 1'b0;
  assign syndec[77] = (syndout_int == 8'b01101110)? 1'b1 : 1'b0;
  assign syndec[62] = (syndout_int == 8'b01110000)? 1'b1 : 1'b0;
  assign syndec[46] = (syndout_int == 8'b10110000)? 1'b1 : 1'b0;
  assign syndec[93] = (syndout_int == 8'b10100001)? 1'b1 : 1'b0;
  assign syndec[51] = (syndout_int == 8'b10010100)? 1'b1 : 1'b0;
  assign syndec[34] = (syndout_int == 8'b01010010)? 1'b1 : 1'b0;
  assign syndec[12] = (syndout_int == 8'b00101010)? 1'b1 : 1'b0;
  assign syndec[101] = (syndout_int == 8'b11110111)? 1'b1 : 1'b0;
  assign syndec[98] = (syndout_int == 8'b11111101)? 1'b1 : 1'b0;
  assign syndec[78] = (syndout_int == 8'b01100001)? 1'b1 : 1'b0;
  assign fixchk[4] = (syndout_int == 8'b00010000)? 1'b1 : 1'b0;
  assign syndec[6] = (syndout_int == 8'b11011010)? 1'b1 : 1'b0;
  assign syndec[61] = (syndout_int == 8'b01101101)? 1'b1 : 1'b0;
  assign syndec[11] = (syndout_int == 8'b00101001)? 1'b1 : 1'b0;
  assign syndec[108] = (syndout_int == 8'b11001000)? 1'b1 : 1'b0;
  assign syndec[47] = (syndout_int == 8'b10110101)? 1'b1 : 1'b0;
  assign syndec[73] = (syndout_int == 8'b01111010)? 1'b1 : 1'b0;
  assign syndec[85] = (syndout_int == 8'b01000011)? 1'b1 : 1'b0;
  assign syndec[71] = (syndout_int == 8'b01111111)? 1'b1 : 1'b0;
  assign syndec[115] = (syndout_int == 8'b00111011)? 1'b1 : 1'b0;
  assign syndec[55] = (syndout_int == 8'b10011101)? 1'b1 : 1'b0;
  assign syndec[37] = (syndout_int == 8'b01011000)? 1'b1 : 1'b0;
  assign syndec[33] = (syndout_int == 8'b01001010)? 1'b1 : 1'b0;
  assign syndec[65] = (syndout_int == 8'b10010001)? 1'b1 : 1'b0;
  assign syndec[49] = (syndout_int == 8'b10001010)? 1'b1 : 1'b0;
  assign syndec[43] = (syndout_int == 8'b10101000)? 1'b1 : 1'b0;
  assign syndec[99] = (syndout_int == 8'b11111011)? 1'b1 : 1'b0;
  assign syndec[5] = (syndout_int == 8'b11011001)? 1'b1 : 1'b0;
  assign syndec[89] = (syndout_int == 8'b10111001)? 1'b1 : 1'b0;
  assign syndec[31] = (syndout_int == 8'b11110100)? 1'b1 : 1'b0;
  assign syndec[111] = (syndout_int == 8'b11000010)? 1'b1 : 1'b0;
  assign syndec[36] = (syndout_int == 8'b01010111)? 1'b1 : 1'b0;
  assign syndec[16] = (syndout_int == 8'b00001110)? 1'b1 : 1'b0;
  assign syndec[120] = 1'b0;
  assign syndec[82] = (syndout_int == 8'b01001001)? 1'b1 : 1'b0;
  assign syndec[100] = (syndout_int == 8'b11111000)? 1'b1 : 1'b0;
  assign syndec[28] = (syndout_int == 8'b11101010)? 1'b1 : 1'b0;
  assign syndec[68] = (syndout_int == 8'b10000110)? 1'b1 : 1'b0;
  assign syndec[8] = (syndout_int == 8'b00100011)? 1'b1 : 1'b0;
  assign syndec[58] = (syndout_int == 8'b01100111)? 1'b1 : 1'b0;
  assign syndec[109] = (syndout_int == 8'b11000111)? 1'b1 : 1'b0;
  assign syndec[95] = (syndout_int == 8'b00001101)? 1'b1 : 1'b0;
  assign syndec[103] = (syndout_int == 8'b11101111)? 1'b1 : 1'b0;
  assign syndec[57] = (syndout_int == 8'b01100100)? 1'b1 : 1'b0;
  assign syndec[10] = (syndout_int == 8'b00100110)? 1'b1 : 1'b0;
  assign fixchk[0] = (syndout_int == 8'b00000001)? 1'b1 : 1'b0;
  assign syndec[118] = (syndout_int == 8'b00110010)? 1'b1 : 1'b0;
  assign fixchk[2] = (syndout_int == 8'b00000100)? 1'b1 : 1'b0;
  assign syndec[15] = (syndout_int == 8'b00110100)? 1'b1 : 1'b0;
  assign syndec[18] = (syndout_int == 8'b00010011)? 1'b1 : 1'b0;
  assign syndec[35] = (syndout_int == 8'b01010100)? 1'b1 : 1'b0;
  assign syndec[38] = (syndout_int == 8'b01011011)? 1'b1 : 1'b0;
  assign syndec[92] = (syndout_int == 8'b10101110)? 1'b1 : 1'b0;
  assign syndec[26] = (syndout_int == 8'b11100110)? 1'b1 : 1'b0;
  assign syndec[19] = (syndout_int == 8'b00010101)? 1'b1 : 1'b0;
  assign syndec[87] = (syndout_int == 8'b10111100)? 1'b1 : 1'b0;
  assign syndec[45] = (syndout_int == 8'b10101101)? 1'b1 : 1'b0;
  assign syndec[105] = (syndout_int == 8'b11011111)? 1'b1 : 1'b0;
  assign syndec[24] = (syndout_int == 8'b11100011)? 1'b1 : 1'b0;
  assign syndec[75] = (syndout_int == 8'b01110110)? 1'b1 : 1'b0;

  always @ (datain) begin : td_PROC

    integer i;

    for (i=0 ; i <= 127 ; i=i+1) begin
      if (i < WIDTH)
        dat_in[i] = datain[i];
      else
        dat_in[i] = 1'b0;
    end
  end

  assign syndout_int = chkout_int ^ chkin;

  assign err_detect = ~gen & ( |syndout_int );

  assign err_multpl = err_detect & ( ~(^syndout_int) || (|syndec[120:WIDTH]) );

  assign fixdata = syndec[WIDTH-1:0];

  assign chkout = (gen == 1'b1)? chkout_int : (correct_n == 1'b0)? chkin ^ fixchk : chkin;

  assign dataout = ((gen == 1'b0) && (correct_n == 1'b0))? datain ^ fixdata : datain;

  assign syndout = syndout_int;

// spyglass enable_block W146
endmodule
