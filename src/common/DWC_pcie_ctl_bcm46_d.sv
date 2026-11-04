
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
// Description : DWC_pcie_ctl_bcm46_d.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 4d6bf80a
//
////////////////////////////////////////////////////////////////////////////////

module DWC_pcie_ctl_bcm46_d(
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

parameter integer WIDTH = 128;

input                   gen;            // Active high check-bit generate control input port
input                   correct_n;      // Active low bit correction control input port
input  [WIDTH-1:0]      datain;         // Data input port (for write, read & scrub)
input  [8:0]            chkin;          // Check bit input port (for read)
output [WIDTH-1:0]      fixdata;        // Data fixed flag port (one-hot)
output                  err_detect;     // Active high error detect output
output                  err_multpl;     // Active high multiple bit error detect output
output [WIDTH-1:0]      dataout;        // Data output port (for read & scrub)
output [8:0]            chkout;         // Check bit output port (for write & scrub)
output [8:0]            syndout;        // Error syndrome output port (for error logging)

wire   [8:0]            chkout_int;
wire   [8:0]            syndout_int;
wire   [8:0]            fixchk;
wire   [247:0]          syndec;
reg    [255:0]          dat_in;
wire   [WIDTH-1:0]      fixdata;


  assign chkout_int[0] = dat_in[0] ^ dat_in[101] ^ dat_in[106] ^ dat_in[108] ^
                          dat_in[109] ^ dat_in[11] ^ dat_in[111] ^ dat_in[112] ^
                          dat_in[116] ^ dat_in[118] ^ dat_in[119] ^ dat_in[120] ^
                          dat_in[121] ^ dat_in[123] ^ dat_in[126] ^ dat_in[129] ^
                          dat_in[130] ^ dat_in[132] ^ dat_in[134] ^ dat_in[136] ^
                          dat_in[138] ^ dat_in[14] ^ dat_in[140] ^ dat_in[141] ^
                          dat_in[143] ^ dat_in[146] ^ dat_in[148] ^ dat_in[150] ^
                          dat_in[151] ^ dat_in[153] ^ dat_in[155] ^ dat_in[158] ^
                          dat_in[159] ^ dat_in[162] ^ dat_in[164] ^ dat_in[166] ^
                          dat_in[167] ^ dat_in[169] ^ dat_in[17] ^ dat_in[171] ^
                          dat_in[174] ^ dat_in[176] ^ dat_in[177] ^ dat_in[179] ^
                          dat_in[18] ^ dat_in[181] ^ dat_in[184] ^ dat_in[186] ^
                          dat_in[188] ^ dat_in[189] ^ dat_in[19] ^ dat_in[190] ^
                          dat_in[193] ^ dat_in[195] ^ dat_in[197] ^ dat_in[198] ^
                          dat_in[200] ^ dat_in[202] ^ dat_in[205] ^ dat_in[207] ^
                          dat_in[208] ^ dat_in[21] ^ dat_in[210] ^ dat_in[212] ^
                          dat_in[215] ^ dat_in[217] ^ dat_in[219] ^ dat_in[220] ^
                          dat_in[221] ^ dat_in[224] ^ dat_in[226] ^ dat_in[228] ^
                          dat_in[229] ^ dat_in[230] ^ dat_in[231] ^ dat_in[233] ^
                          dat_in[234] ^ dat_in[236] ^ dat_in[238] ^ dat_in[240] ^
                          dat_in[242] ^ dat_in[244] ^ dat_in[245] ^ dat_in[26] ^
                          dat_in[28] ^ dat_in[29] ^ dat_in[31] ^ dat_in[32] ^
                          dat_in[36] ^ dat_in[38] ^ dat_in[39] ^ dat_in[4] ^
                          dat_in[40] ^ dat_in[41] ^ dat_in[43] ^ dat_in[46] ^
                          dat_in[49] ^ dat_in[50] ^ dat_in[51] ^ dat_in[53] ^
                          dat_in[58] ^ dat_in[6] ^ dat_in[60] ^ dat_in[61] ^
                          dat_in[63] ^ dat_in[64] ^ dat_in[68] ^ dat_in[7] ^
                          dat_in[70] ^ dat_in[71] ^ dat_in[72] ^ dat_in[73] ^
                          dat_in[75] ^ dat_in[78] ^ dat_in[8] ^ dat_in[81] ^
                          dat_in[82] ^ dat_in[83] ^ dat_in[85] ^ dat_in[9] ^
                          dat_in[90] ^ dat_in[92] ^ dat_in[93] ^ dat_in[95] ^
                          dat_in[97] ^ dat_in[98] ^ dat_in[99];

  assign chkout_int[1] = dat_in[0] ^ dat_in[1] ^ dat_in[10] ^ dat_in[100] ^
                          dat_in[102] ^ dat_in[104] ^ dat_in[106] ^ dat_in[108] ^
                          dat_in[112] ^ dat_in[113] ^ dat_in[114] ^ dat_in[116] ^
                          dat_in[118] ^ dat_in[12] ^ dat_in[120] ^ dat_in[122] ^
                          dat_in[124] ^ dat_in[128] ^ dat_in[130] ^ dat_in[132] ^
                          dat_in[133] ^ dat_in[134] ^ dat_in[135] ^ dat_in[139] ^
                          dat_in[141] ^ dat_in[143] ^ dat_in[145] ^ dat_in[147] ^
                          dat_in[148] ^ dat_in[149] ^ dat_in[151] ^ dat_in[155] ^
                          dat_in[157] ^ dat_in[159] ^ dat_in[16] ^ dat_in[161] ^
                          dat_in[163] ^ dat_in[164] ^ dat_in[165] ^ dat_in[167] ^
                          dat_in[17] ^ dat_in[171] ^ dat_in[173] ^ dat_in[175] ^
                          dat_in[177] ^ dat_in[179] ^ dat_in[18] ^ dat_in[180] ^
                          dat_in[181] ^ dat_in[183] ^ dat_in[187] ^ dat_in[189] ^
                          dat_in[190] ^ dat_in[192] ^ dat_in[194] ^ dat_in[195] ^
                          dat_in[196] ^ dat_in[198] ^ dat_in[2] ^ dat_in[20] ^
                          dat_in[202] ^ dat_in[204] ^ dat_in[206] ^ dat_in[208] ^
                          dat_in[210] ^ dat_in[211] ^ dat_in[212] ^ dat_in[214] ^
                          dat_in[218] ^ dat_in[22] ^ dat_in[220] ^ dat_in[221] ^
                          dat_in[223] ^ dat_in[225] ^ dat_in[226] ^ dat_in[227] ^
                          dat_in[229] ^ dat_in[231] ^ dat_in[232] ^ dat_in[234] ^
                          dat_in[236] ^ dat_in[237] ^ dat_in[238] ^ dat_in[239] ^
                          dat_in[24] ^ dat_in[243] ^ dat_in[245] ^ dat_in[26] ^
                          dat_in[28] ^ dat_in[32] ^ dat_in[33] ^ dat_in[34] ^
                          dat_in[36] ^ dat_in[38] ^ dat_in[4] ^ dat_in[40] ^
                          dat_in[42] ^ dat_in[44] ^ dat_in[48] ^ dat_in[49] ^
                          dat_in[50] ^ dat_in[52] ^ dat_in[54] ^ dat_in[56] ^
                          dat_in[58] ^ dat_in[6] ^ dat_in[60] ^ dat_in[64] ^
                          dat_in[65] ^ dat_in[66] ^ dat_in[68] ^ dat_in[70] ^
                          dat_in[72] ^ dat_in[74] ^ dat_in[76] ^ dat_in[8] ^
                          dat_in[80] ^ dat_in[81] ^ dat_in[82] ^ dat_in[84] ^
                          dat_in[86] ^ dat_in[88] ^ dat_in[90] ^ dat_in[92] ^
                          dat_in[96] ^ dat_in[97] ^ dat_in[98];

  assign chkout_int[2] = ~dat_in[0] ^ dat_in[10] ^ dat_in[100] ^ dat_in[103] ^
                          dat_in[105] ^ dat_in[106] ^ dat_in[109] ^ dat_in[111] ^
                          dat_in[112] ^ dat_in[115] ^ dat_in[116] ^ dat_in[119] ^
                          dat_in[121] ^ dat_in[122] ^ dat_in[125] ^ dat_in[127] ^
                          dat_in[128] ^ dat_in[129] ^ dat_in[13] ^ dat_in[132] ^
                          dat_in[134] ^ dat_in[135] ^ dat_in[137] ^ dat_in[139] ^
                          dat_in[140] ^ dat_in[143] ^ dat_in[144] ^ dat_in[147] ^
                          dat_in[149] ^ dat_in[15] ^ dat_in[151] ^ dat_in[153] ^
                          dat_in[155] ^ dat_in[156] ^ dat_in[159] ^ dat_in[16] ^
                          dat_in[160] ^ dat_in[163] ^ dat_in[165] ^ dat_in[167] ^
                          dat_in[169] ^ dat_in[171] ^ dat_in[172] ^ dat_in[175] ^
                          dat_in[176] ^ dat_in[179] ^ dat_in[181] ^ dat_in[183] ^
                          dat_in[185] ^ dat_in[187] ^ dat_in[188] ^ dat_in[19] ^
                          dat_in[190] ^ dat_in[191] ^ dat_in[194] ^ dat_in[196] ^
                          dat_in[198] ^ dat_in[20] ^ dat_in[200] ^ dat_in[202] ^
                          dat_in[203] ^ dat_in[206] ^ dat_in[207] ^ dat_in[210] ^
                          dat_in[212] ^ dat_in[214] ^ dat_in[216] ^ dat_in[218] ^
                          dat_in[219] ^ dat_in[221] ^ dat_in[222] ^ dat_in[225] ^
                          dat_in[227] ^ dat_in[229] ^ dat_in[23] ^ dat_in[230] ^
                          dat_in[231] ^ dat_in[232] ^ dat_in[233] ^ dat_in[236] ^
                          dat_in[238] ^ dat_in[239] ^ dat_in[241] ^ dat_in[243] ^
                          dat_in[244] ^ dat_in[25] ^ dat_in[26] ^ dat_in[29] ^
                          dat_in[3] ^ dat_in[31] ^ dat_in[32] ^ dat_in[35] ^
                          dat_in[36] ^ dat_in[39] ^ dat_in[4] ^ dat_in[41] ^
                          dat_in[42] ^ dat_in[45] ^ dat_in[47] ^ dat_in[48] ^
                          dat_in[51] ^ dat_in[52] ^ dat_in[55] ^ dat_in[57] ^
                          dat_in[58] ^ dat_in[61] ^ dat_in[63] ^ dat_in[64] ^
                          dat_in[67] ^ dat_in[68] ^ dat_in[7] ^ dat_in[71] ^
                          dat_in[73] ^ dat_in[74] ^ dat_in[77] ^ dat_in[79] ^
                          dat_in[80] ^ dat_in[83] ^ dat_in[84] ^ dat_in[87] ^
                          dat_in[89] ^ dat_in[9] ^ dat_in[90] ^ dat_in[93] ^
                          dat_in[95] ^ dat_in[96] ^ dat_in[99];

  assign chkout_int[3] = ~dat_in[0] ^ dat_in[1] ^ dat_in[101] ^ dat_in[102] ^
                          dat_in[103] ^ dat_in[107] ^ dat_in[108] ^ dat_in[109] ^
                          dat_in[11] ^ dat_in[112] ^ dat_in[113] ^ dat_in[117] ^
                          dat_in[118] ^ dat_in[119] ^ dat_in[12] ^ dat_in[123] ^
                          dat_in[124] ^ dat_in[125] ^ dat_in[128] ^ dat_in[129] ^
                          dat_in[13] ^ dat_in[130] ^ dat_in[131] ^ dat_in[134] ^
                          dat_in[135] ^ dat_in[137] ^ dat_in[138] ^ dat_in[143] ^
                          dat_in[144] ^ dat_in[145] ^ dat_in[146] ^ dat_in[149] ^
                          dat_in[151] ^ dat_in[153] ^ dat_in[154] ^ dat_in[159] ^
                          dat_in[16] ^ dat_in[160] ^ dat_in[161] ^ dat_in[162] ^
                          dat_in[165] ^ dat_in[167] ^ dat_in[169] ^ dat_in[17] ^
                          dat_in[170] ^ dat_in[175] ^ dat_in[176] ^ dat_in[177] ^
                          dat_in[178] ^ dat_in[181] ^ dat_in[183] ^ dat_in[185] ^
                          dat_in[186] ^ dat_in[190] ^ dat_in[191] ^ dat_in[192] ^
                          dat_in[193] ^ dat_in[196] ^ dat_in[198] ^ dat_in[200] ^
                          dat_in[201] ^ dat_in[206] ^ dat_in[207] ^ dat_in[208] ^
                          dat_in[209] ^ dat_in[21] ^ dat_in[212] ^ dat_in[214] ^
                          dat_in[216] ^ dat_in[217] ^ dat_in[22] ^ dat_in[221] ^
                          dat_in[222] ^ dat_in[223] ^ dat_in[224] ^ dat_in[227] ^
                          dat_in[229] ^ dat_in[23] ^ dat_in[230] ^ dat_in[232] ^
                          dat_in[233] ^ dat_in[234] ^ dat_in[235] ^ dat_in[238] ^
                          dat_in[239] ^ dat_in[241] ^ dat_in[242] ^ dat_in[27] ^
                          dat_in[28] ^ dat_in[29] ^ dat_in[32] ^ dat_in[33] ^
                          dat_in[37] ^ dat_in[38] ^ dat_in[39] ^ dat_in[43] ^
                          dat_in[44] ^ dat_in[45] ^ dat_in[48] ^ dat_in[49] ^
                          dat_in[5] ^ dat_in[53] ^ dat_in[54] ^ dat_in[55] ^
                          dat_in[59] ^ dat_in[6] ^ dat_in[60] ^ dat_in[61] ^
                          dat_in[64] ^ dat_in[65] ^ dat_in[69] ^ dat_in[7] ^
                          dat_in[70] ^ dat_in[71] ^ dat_in[75] ^ dat_in[76] ^
                          dat_in[77] ^ dat_in[80] ^ dat_in[81] ^ dat_in[85] ^
                          dat_in[86] ^ dat_in[87] ^ dat_in[91] ^ dat_in[92] ^
                          dat_in[93] ^ dat_in[96] ^ dat_in[97];

  assign chkout_int[4] = dat_in[100] ^ dat_in[101] ^ dat_in[102] ^ dat_in[103] ^
                          dat_in[110] ^ dat_in[111] ^ dat_in[114] ^ dat_in[115] ^
                          dat_in[116] ^ dat_in[117] ^ dat_in[118] ^ dat_in[119] ^
                          dat_in[126] ^ dat_in[127] ^ dat_in[128] ^ dat_in[129] ^
                          dat_in[130] ^ dat_in[131] ^ dat_in[132] ^ dat_in[133] ^
                          dat_in[135] ^ dat_in[136] ^ dat_in[14] ^ dat_in[143] ^
                          dat_in[144] ^ dat_in[145] ^ dat_in[146] ^ dat_in[147] ^
                          dat_in[148] ^ dat_in[15] ^ dat_in[151] ^ dat_in[152] ^
                          dat_in[159] ^ dat_in[160] ^ dat_in[161] ^ dat_in[162] ^
                          dat_in[163] ^ dat_in[164] ^ dat_in[167] ^ dat_in[168] ^
                          dat_in[175] ^ dat_in[176] ^ dat_in[177] ^ dat_in[178] ^
                          dat_in[179] ^ dat_in[18] ^ dat_in[180] ^ dat_in[183] ^
                          dat_in[184] ^ dat_in[19] ^ dat_in[190] ^ dat_in[191] ^
                          dat_in[192] ^ dat_in[193] ^ dat_in[194] ^ dat_in[195] ^
                          dat_in[198] ^ dat_in[199] ^ dat_in[2] ^ dat_in[20] ^
                          dat_in[206] ^ dat_in[207] ^ dat_in[208] ^ dat_in[209] ^
                          dat_in[21] ^ dat_in[210] ^ dat_in[211] ^ dat_in[214] ^
                          dat_in[215] ^ dat_in[22] ^ dat_in[221] ^ dat_in[222] ^
                          dat_in[223] ^ dat_in[224] ^ dat_in[225] ^ dat_in[226] ^
                          dat_in[229] ^ dat_in[23] ^ dat_in[232] ^ dat_in[233] ^
                          dat_in[234] ^ dat_in[235] ^ dat_in[236] ^ dat_in[237] ^
                          dat_in[239] ^ dat_in[240] ^ dat_in[3] ^ dat_in[30] ^
                          dat_in[31] ^ dat_in[34] ^ dat_in[35] ^ dat_in[36] ^
                          dat_in[37] ^ dat_in[38] ^ dat_in[39] ^ dat_in[4] ^
                          dat_in[46] ^ dat_in[47] ^ dat_in[5] ^ dat_in[50] ^
                          dat_in[51] ^ dat_in[52] ^ dat_in[53] ^ dat_in[54] ^
                          dat_in[55] ^ dat_in[6] ^ dat_in[62] ^ dat_in[63] ^
                          dat_in[66] ^ dat_in[67] ^ dat_in[68] ^ dat_in[69] ^
                          dat_in[7] ^ dat_in[70] ^ dat_in[71] ^ dat_in[78] ^
                          dat_in[79] ^ dat_in[82] ^ dat_in[83] ^ dat_in[84] ^
                          dat_in[85] ^ dat_in[86] ^ dat_in[87] ^ dat_in[94] ^
                          dat_in[95] ^ dat_in[98] ^ dat_in[99];

  assign chkout_int[5] = dat_in[10] ^ dat_in[100] ^ dat_in[101] ^ dat_in[102] ^
                          dat_in[103] ^ dat_in[11] ^ dat_in[112] ^ dat_in[113] ^
                          dat_in[114] ^ dat_in[115] ^ dat_in[116] ^ dat_in[117] ^
                          dat_in[118] ^ dat_in[119] ^ dat_in[12] ^ dat_in[13] ^
                          dat_in[135] ^ dat_in[136] ^ dat_in[137] ^ dat_in[138] ^
                          dat_in[139] ^ dat_in[14] ^ dat_in[140] ^ dat_in[141] ^
                          dat_in[142] ^ dat_in[15] ^ dat_in[151] ^ dat_in[152] ^
                          dat_in[153] ^ dat_in[154] ^ dat_in[155] ^ dat_in[156] ^
                          dat_in[157] ^ dat_in[158] ^ dat_in[159] ^ dat_in[160] ^
                          dat_in[161] ^ dat_in[162] ^ dat_in[163] ^ dat_in[164] ^
                          dat_in[165] ^ dat_in[166] ^ dat_in[175] ^ dat_in[176] ^
                          dat_in[177] ^ dat_in[178] ^ dat_in[179] ^ dat_in[180] ^
                          dat_in[181] ^ dat_in[182] ^ dat_in[190] ^ dat_in[191] ^
                          dat_in[192] ^ dat_in[193] ^ dat_in[194] ^ dat_in[195] ^
                          dat_in[196] ^ dat_in[197] ^ dat_in[206] ^ dat_in[207] ^
                          dat_in[208] ^ dat_in[209] ^ dat_in[210] ^ dat_in[211] ^
                          dat_in[212] ^ dat_in[213] ^ dat_in[221] ^ dat_in[222] ^
                          dat_in[223] ^ dat_in[224] ^ dat_in[225] ^ dat_in[226] ^
                          dat_in[227] ^ dat_in[228] ^ dat_in[232] ^ dat_in[233] ^
                          dat_in[234] ^ dat_in[235] ^ dat_in[236] ^ dat_in[237] ^
                          dat_in[238] ^ dat_in[24] ^ dat_in[25] ^ dat_in[26] ^
                          dat_in[27] ^ dat_in[28] ^ dat_in[29] ^ dat_in[30] ^
                          dat_in[31] ^ dat_in[40] ^ dat_in[41] ^ dat_in[42] ^
                          dat_in[43] ^ dat_in[44] ^ dat_in[45] ^ dat_in[46] ^
                          dat_in[47] ^ dat_in[56] ^ dat_in[57] ^ dat_in[58] ^
                          dat_in[59] ^ dat_in[60] ^ dat_in[61] ^ dat_in[62] ^
                          dat_in[63] ^ dat_in[72] ^ dat_in[73] ^ dat_in[74] ^
                          dat_in[75] ^ dat_in[76] ^ dat_in[77] ^ dat_in[78] ^
                          dat_in[79] ^ dat_in[8] ^ dat_in[88] ^ dat_in[89] ^
                          dat_in[9] ^ dat_in[90] ^ dat_in[91] ^ dat_in[92] ^
                          dat_in[93] ^ dat_in[94] ^ dat_in[95] ^ dat_in[96] ^
                          dat_in[97] ^ dat_in[98] ^ dat_in[99];

  assign chkout_int[6] = dat_in[0] ^ dat_in[1] ^ dat_in[104] ^ dat_in[105] ^
                          dat_in[106] ^ dat_in[107] ^ dat_in[108] ^ dat_in[109] ^
                          dat_in[110] ^ dat_in[111] ^ dat_in[112] ^ dat_in[113] ^
                          dat_in[114] ^ dat_in[115] ^ dat_in[116] ^ dat_in[117] ^
                          dat_in[118] ^ dat_in[119] ^ dat_in[135] ^ dat_in[136] ^
                          dat_in[137] ^ dat_in[138] ^ dat_in[139] ^ dat_in[140] ^
                          dat_in[141] ^ dat_in[142] ^ dat_in[143] ^ dat_in[144] ^
                          dat_in[145] ^ dat_in[146] ^ dat_in[147] ^ dat_in[148] ^
                          dat_in[149] ^ dat_in[150] ^ dat_in[167] ^ dat_in[168] ^
                          dat_in[169] ^ dat_in[170] ^ dat_in[171] ^ dat_in[172] ^
                          dat_in[173] ^ dat_in[174] ^ dat_in[175] ^ dat_in[176] ^
                          dat_in[177] ^ dat_in[178] ^ dat_in[179] ^ dat_in[180] ^
                          dat_in[181] ^ dat_in[182] ^ dat_in[190] ^ dat_in[191] ^
                          dat_in[192] ^ dat_in[193] ^ dat_in[194] ^ dat_in[195] ^
                          dat_in[196] ^ dat_in[197] ^ dat_in[2] ^ dat_in[214] ^
                          dat_in[215] ^ dat_in[216] ^ dat_in[217] ^ dat_in[218] ^
                          dat_in[219] ^ dat_in[220] ^ dat_in[221] ^ dat_in[222] ^
                          dat_in[223] ^ dat_in[224] ^ dat_in[225] ^ dat_in[226] ^
                          dat_in[227] ^ dat_in[228] ^ dat_in[239] ^ dat_in[24] ^
                          dat_in[240] ^ dat_in[241] ^ dat_in[242] ^ dat_in[243] ^
                          dat_in[244] ^ dat_in[245] ^ dat_in[246] ^ dat_in[25] ^
                          dat_in[26] ^ dat_in[27] ^ dat_in[28] ^ dat_in[29] ^
                          dat_in[3] ^ dat_in[30] ^ dat_in[31] ^ dat_in[32] ^
                          dat_in[33] ^ dat_in[34] ^ dat_in[35] ^ dat_in[36] ^
                          dat_in[37] ^ dat_in[38] ^ dat_in[39] ^ dat_in[4] ^
                          dat_in[5] ^ dat_in[56] ^ dat_in[57] ^ dat_in[58] ^
                          dat_in[59] ^ dat_in[6] ^ dat_in[60] ^ dat_in[61] ^
                          dat_in[62] ^ dat_in[63] ^ dat_in[7] ^ dat_in[72] ^
                          dat_in[73] ^ dat_in[74] ^ dat_in[75] ^ dat_in[76] ^
                          dat_in[77] ^ dat_in[78] ^ dat_in[79] ^ dat_in[80] ^
                          dat_in[81] ^ dat_in[82] ^ dat_in[83] ^ dat_in[84] ^
                          dat_in[85] ^ dat_in[86] ^ dat_in[87];

  assign chkout_int[7] = dat_in[0] ^ dat_in[1] ^ dat_in[104] ^ dat_in[105] ^
                          dat_in[106] ^ dat_in[107] ^ dat_in[108] ^ dat_in[109] ^
                          dat_in[110] ^ dat_in[111] ^ dat_in[112] ^ dat_in[113] ^
                          dat_in[114] ^ dat_in[115] ^ dat_in[116] ^ dat_in[117] ^
                          dat_in[118] ^ dat_in[119] ^ dat_in[135] ^ dat_in[136] ^
                          dat_in[137] ^ dat_in[138] ^ dat_in[139] ^ dat_in[140] ^
                          dat_in[141] ^ dat_in[142] ^ dat_in[143] ^ dat_in[144] ^
                          dat_in[145] ^ dat_in[146] ^ dat_in[147] ^ dat_in[148] ^
                          dat_in[149] ^ dat_in[150] ^ dat_in[159] ^ dat_in[160] ^
                          dat_in[161] ^ dat_in[162] ^ dat_in[163] ^ dat_in[164] ^
                          dat_in[165] ^ dat_in[166] ^ dat_in[183] ^ dat_in[184] ^
                          dat_in[185] ^ dat_in[186] ^ dat_in[187] ^ dat_in[188] ^
                          dat_in[189] ^ dat_in[198] ^ dat_in[199] ^ dat_in[2] ^
                          dat_in[200] ^ dat_in[201] ^ dat_in[202] ^ dat_in[203] ^
                          dat_in[204] ^ dat_in[205] ^ dat_in[206] ^ dat_in[207] ^
                          dat_in[208] ^ dat_in[209] ^ dat_in[210] ^ dat_in[211] ^
                          dat_in[212] ^ dat_in[213] ^ dat_in[221] ^ dat_in[222] ^
                          dat_in[223] ^ dat_in[224] ^ dat_in[225] ^ dat_in[226] ^
                          dat_in[227] ^ dat_in[228] ^ dat_in[239] ^ dat_in[24] ^
                          dat_in[240] ^ dat_in[241] ^ dat_in[242] ^ dat_in[243] ^
                          dat_in[244] ^ dat_in[245] ^ dat_in[246] ^ dat_in[25] ^
                          dat_in[26] ^ dat_in[27] ^ dat_in[28] ^ dat_in[29] ^
                          dat_in[3] ^ dat_in[30] ^ dat_in[31] ^ dat_in[4] ^
                          dat_in[40] ^ dat_in[41] ^ dat_in[42] ^ dat_in[43] ^
                          dat_in[44] ^ dat_in[45] ^ dat_in[46] ^ dat_in[47] ^
                          dat_in[48] ^ dat_in[49] ^ dat_in[5] ^ dat_in[50] ^
                          dat_in[51] ^ dat_in[52] ^ dat_in[53] ^ dat_in[54] ^
                          dat_in[55] ^ dat_in[6] ^ dat_in[64] ^ dat_in[65] ^
                          dat_in[66] ^ dat_in[67] ^ dat_in[68] ^ dat_in[69] ^
                          dat_in[7] ^ dat_in[70] ^ dat_in[71] ^ dat_in[88] ^
                          dat_in[89] ^ dat_in[90] ^ dat_in[91] ^ dat_in[92] ^
                          dat_in[93] ^ dat_in[94] ^ dat_in[95];

  assign chkout_int[8] = dat_in[0] ^ dat_in[1] ^ dat_in[100] ^ dat_in[101] ^
                          dat_in[102] ^ dat_in[103] ^ dat_in[120] ^ dat_in[121] ^
                          dat_in[122] ^ dat_in[123] ^ dat_in[124] ^ dat_in[125] ^
                          dat_in[126] ^ dat_in[127] ^ dat_in[128] ^ dat_in[129] ^
                          dat_in[130] ^ dat_in[131] ^ dat_in[132] ^ dat_in[133] ^
                          dat_in[134] ^ dat_in[151] ^ dat_in[152] ^ dat_in[153] ^
                          dat_in[154] ^ dat_in[155] ^ dat_in[156] ^ dat_in[157] ^
                          dat_in[158] ^ dat_in[167] ^ dat_in[168] ^ dat_in[169] ^
                          dat_in[170] ^ dat_in[171] ^ dat_in[172] ^ dat_in[173] ^
                          dat_in[174] ^ dat_in[175] ^ dat_in[176] ^ dat_in[177] ^
                          dat_in[178] ^ dat_in[179] ^ dat_in[180] ^ dat_in[181] ^
                          dat_in[182] ^ dat_in[198] ^ dat_in[199] ^ dat_in[2] ^
                          dat_in[200] ^ dat_in[201] ^ dat_in[202] ^ dat_in[203] ^
                          dat_in[204] ^ dat_in[205] ^ dat_in[206] ^ dat_in[207] ^
                          dat_in[208] ^ dat_in[209] ^ dat_in[210] ^ dat_in[211] ^
                          dat_in[212] ^ dat_in[213] ^ dat_in[221] ^ dat_in[222] ^
                          dat_in[223] ^ dat_in[224] ^ dat_in[225] ^ dat_in[226] ^
                          dat_in[227] ^ dat_in[228] ^ dat_in[239] ^ dat_in[24] ^
                          dat_in[240] ^ dat_in[241] ^ dat_in[242] ^ dat_in[243] ^
                          dat_in[244] ^ dat_in[245] ^ dat_in[246] ^ dat_in[25] ^
                          dat_in[26] ^ dat_in[27] ^ dat_in[28] ^ dat_in[29] ^
                          dat_in[3] ^ dat_in[30] ^ dat_in[31] ^ dat_in[4] ^
                          dat_in[40] ^ dat_in[41] ^ dat_in[42] ^ dat_in[43] ^
                          dat_in[44] ^ dat_in[45] ^ dat_in[46] ^ dat_in[47] ^
                          dat_in[48] ^ dat_in[49] ^ dat_in[5] ^ dat_in[50] ^
                          dat_in[51] ^ dat_in[52] ^ dat_in[53] ^ dat_in[54] ^
                          dat_in[55] ^ dat_in[6] ^ dat_in[7] ^ dat_in[72] ^
                          dat_in[73] ^ dat_in[74] ^ dat_in[75] ^ dat_in[76] ^
                          dat_in[77] ^ dat_in[78] ^ dat_in[79] ^ dat_in[80] ^
                          dat_in[81] ^ dat_in[82] ^ dat_in[83] ^ dat_in[84] ^
                          dat_in[85] ^ dat_in[86] ^ dat_in[87] ^ dat_in[96] ^
                          dat_in[97] ^ dat_in[98] ^ dat_in[99];

  assign syndec[214] = (syndout_int == 9'b001011110)? 1'b1 : 1'b0;
  assign syndec[95] = (syndout_int == 9'b010110101)? 1'b1 : 1'b0;
  assign syndec[223] = (syndout_int == 9'b111111010)? 1'b1 : 1'b0;
  assign syndec[220] = (syndout_int == 9'b001000011)? 1'b1 : 1'b0;
  assign syndec[37] = (syndout_int == 9'b001011000)? 1'b1 : 1'b0;
  assign syndec[173] = (syndout_int == 9'b101000010)? 1'b1 : 1'b0;
  assign syndec[127] = (syndout_int == 9'b100010100)? 1'b1 : 1'b0;
  assign syndec[239] = (syndout_int == 9'b111011110)? 1'b1 : 1'b0;
  assign syndec[244] = (syndout_int == 9'b111000101)? 1'b1 : 1'b0;
  assign fixchk[4] = (syndout_int == 9'b000010000)? 1'b1 : 1'b0;
  assign syndec[186] = (syndout_int == 9'b010001001)? 1'b1 : 1'b0;
  assign syndec[45] = (syndout_int == 9'b110101100)? 1'b1 : 1'b0;
  assign fixchk[6] = (syndout_int == 9'b001000000)? 1'b1 : 1'b0;
  assign syndec[151] = (syndout_int == 9'b100111111)? 1'b1 : 1'b0;
  assign syndec[41] = (syndout_int == 9'b110100101)? 1'b1 : 1'b0;
  assign syndec[194] = (syndout_int == 9'b001110110)? 1'b1 : 1'b0;
  assign syndec[126] = (syndout_int == 9'b100010001)? 1'b1 : 1'b0;
  assign syndec[32] = (syndout_int == 9'b001001111)? 1'b1 : 1'b0;
  assign syndec[118] = (syndout_int == 9'b011111011)? 1'b1 : 1'b0;
  assign syndec[25] = (syndout_int == 9'b111100100)? 1'b1 : 1'b0;
  assign syndec[191] = (syndout_int == 9'b001111100)? 1'b1 : 1'b0;
  assign syndec[218] = (syndout_int == 9'b001000110)? 1'b1 : 1'b0;
  assign syndec[208] = (syndout_int == 9'b110111011)? 1'b1 : 1'b0;
  assign syndec[182] = (syndout_int == 9'b101100000)? 1'b1 : 1'b0;
  assign syndec[209] = (syndout_int == 9'b110111000)? 1'b1 : 1'b0;
  assign fixchk[5] = (syndout_int == 9'b000100000)? 1'b1 : 1'b0;
  assign syndec[98] = (syndout_int == 9'b100110011)? 1'b1 : 1'b0;
  assign syndec[123] = (syndout_int == 9'b100001001)? 1'b1 : 1'b0;
  assign syndec[56] = (syndout_int == 9'b001100010)? 1'b1 : 1'b0;
  assign syndec[169] = (syndout_int == 9'b101001101)? 1'b1 : 1'b0;
  assign syndec[153] = (syndout_int == 9'b100101101)? 1'b1 : 1'b0;
  assign syndec[152] = (syndout_int == 9'b100110000)? 1'b1 : 1'b0;
  assign syndec[57] = (syndout_int == 9'b001100100)? 1'b1 : 1'b0;
  assign syndec[130] = (syndout_int == 9'b100011011)? 1'b1 : 1'b0;
  assign syndec[121] = (syndout_int == 9'b100000101)? 1'b1 : 1'b0;
  assign syndec[59] = (syndout_int == 9'b001101000)? 1'b1 : 1'b0;
  assign syndec[47] = (syndout_int == 9'b110110100)? 1'b1 : 1'b0;
  assign syndec[97] = (syndout_int == 9'b100101011)? 1'b1 : 1'b0;
  assign syndec[104] = (syndout_int == 9'b011000010)? 1'b1 : 1'b0;
  assign syndec[172] = (syndout_int == 9'b101000100)? 1'b1 : 1'b0;
  assign syndec[40] = (syndout_int == 9'b110100011)? 1'b1 : 1'b0;
  assign syndec[11] = (syndout_int == 9'b000101001)? 1'b1 : 1'b0;
  assign syndec[138] = (syndout_int == 9'b011101001)? 1'b1 : 1'b0;
  assign syndec[180] = (syndout_int == 9'b101110010)? 1'b1 : 1'b0;
  assign syndec[103] = (syndout_int == 9'b100111100)? 1'b1 : 1'b0;
  assign syndec[77] = (syndout_int == 9'b101101100)? 1'b1 : 1'b0;
  assign syndec[6] = (syndout_int == 9'b111011011)? 1'b1 : 1'b0;
  assign syndec[35] = (syndout_int == 9'b001010100)? 1'b1 : 1'b0;
  assign syndec[132] = (syndout_int == 9'b100010111)? 1'b1 : 1'b0;
  assign syndec[4] = (syndout_int == 9'b111010111)? 1'b1 : 1'b0;
  assign syndec[149] = (syndout_int == 9'b011001110)? 1'b1 : 1'b0;
  assign syndec[150] = (syndout_int == 9'b011000001)? 1'b1 : 1'b0;
  assign syndec[85] = (syndout_int == 9'b101011001)? 1'b1 : 1'b0;
  assign syndec[9] = (syndout_int == 9'b000100101)? 1'b1 : 1'b0;
  assign syndec[195] = (syndout_int == 9'b001110011)? 1'b1 : 1'b0;
  assign syndec[155] = (syndout_int == 9'b100100111)? 1'b1 : 1'b0;
  assign syndec[39] = (syndout_int == 9'b001011101)? 1'b1 : 1'b0;
  assign syndec[160] = (syndout_int == 9'b010111100)? 1'b1 : 1'b0;
  assign syndec[110] = (syndout_int == 9'b011010000)? 1'b1 : 1'b0;
  assign syndec[107] = (syndout_int == 9'b011001000)? 1'b1 : 1'b0;
  assign syndec[207] = (syndout_int == 9'b110111101)? 1'b1 : 1'b0;
  assign syndec[12] = (syndout_int == 9'b000101010)? 1'b1 : 1'b0;
  assign syndec[171] = (syndout_int == 9'b101000111)? 1'b1 : 1'b0;
  assign syndec[42] = (syndout_int == 9'b110100110)? 1'b1 : 1'b0;
  assign syndec[227] = (syndout_int == 9'b111101110)? 1'b1 : 1'b0;
  assign syndec[174] = (syndout_int == 9'b101000001)? 1'b1 : 1'b0;
  assign syndec[18] = (syndout_int == 9'b000010011)? 1'b1 : 1'b0;
  assign syndec[188] = (syndout_int == 9'b010000101)? 1'b1 : 1'b0;
  assign syndec[144] = (syndout_int == 9'b011011100)? 1'b1 : 1'b0;
  assign syndec[20] = (syndout_int == 9'b000010110)? 1'b1 : 1'b0;
  assign syndec[100] = (syndout_int == 9'b100110110)? 1'b1 : 1'b0;
  assign syndec[89] = (syndout_int == 9'b010100100)? 1'b1 : 1'b0;
  assign syndec[125] = (syndout_int == 9'b100001100)? 1'b1 : 1'b0;
  assign syndec[114] = (syndout_int == 9'b011110010)? 1'b1 : 1'b0;
  assign syndec[201] = (syndout_int == 9'b110001000)? 1'b1 : 1'b0;
  assign syndec[148] = (syndout_int == 9'b011010011)? 1'b1 : 1'b0;
  assign syndec[224] = (syndout_int == 9'b111111001)? 1'b1 : 1'b0;
  assign syndec[108] = (syndout_int == 9'b011001011)? 1'b1 : 1'b0;
  assign syndec[192] = (syndout_int == 9'b001111010)? 1'b1 : 1'b0;
  assign syndec[129] = (syndout_int == 9'b100011101)? 1'b1 : 1'b0;
  assign syndec[96] = (syndout_int == 9'b100101110)? 1'b1 : 1'b0;
  assign syndec[128] = (syndout_int == 9'b100011110)? 1'b1 : 1'b0;
  assign syndec[238] = (syndout_int == 9'b000101111)? 1'b1 : 1'b0;
  assign syndec[202] = (syndout_int == 9'b110000111)? 1'b1 : 1'b0;
  assign syndec[101] = (syndout_int == 9'b100111001)? 1'b1 : 1'b0;
  assign syndec[216] = (syndout_int == 9'b001001100)? 1'b1 : 1'b0;
  assign syndec[178] = (syndout_int == 9'b101111000)? 1'b1 : 1'b0;
  assign syndec[158] = (syndout_int == 9'b100100001)? 1'b1 : 1'b0;
  assign syndec[27] = (syndout_int == 9'b111101000)? 1'b1 : 1'b0;
  assign syndec[131] = (syndout_int == 9'b100011000)? 1'b1 : 1'b0;
  assign syndec[61] = (syndout_int == 9'b001101101)? 1'b1 : 1'b0;
  assign syndec[210] = (syndout_int == 9'b110110111)? 1'b1 : 1'b0;
  assign syndec[198] = (syndout_int == 9'b110011111)? 1'b1 : 1'b0;
  assign syndec[71] = (syndout_int == 9'b010011101)? 1'b1 : 1'b0;
  assign syndec[146] = (syndout_int == 9'b011011001)? 1'b1 : 1'b0;
  assign syndec[68] = (syndout_int == 9'b010010111)? 1'b1 : 1'b0;
  assign syndec[167] = (syndout_int == 9'b101011111)? 1'b1 : 1'b0;
  assign syndec[124] = (syndout_int == 9'b100001010)? 1'b1 : 1'b0;
  assign syndec[159] = (syndout_int == 9'b010111111)? 1'b1 : 1'b0;
  assign syndec[33] = (syndout_int == 9'b001001010)? 1'b1 : 1'b0;
  assign syndec[135] = (syndout_int == 9'b011111110)? 1'b1 : 1'b0;
  assign syndec[72] = (syndout_int == 9'b101100011)? 1'b1 : 1'b0;
  assign fixchk[7] = (syndout_int == 9'b010000000)? 1'b1 : 1'b0;
  assign syndec[10] = (syndout_int == 9'b000100110)? 1'b1 : 1'b0;
  assign syndec[74] = (syndout_int == 9'b101100110)? 1'b1 : 1'b0;
  assign syndec[65] = (syndout_int == 9'b010001010)? 1'b1 : 1'b0;
  assign syndec[30] = (syndout_int == 9'b111110000)? 1'b1 : 1'b0;
  assign syndec[145] = (syndout_int == 9'b011011010)? 1'b1 : 1'b0;
  assign syndec[215] = (syndout_int == 9'b001010001)? 1'b1 : 1'b0;
  assign syndec[22] = (syndout_int == 9'b000011010)? 1'b1 : 1'b0;
  assign syndec[170] = (syndout_int == 9'b101001000)? 1'b1 : 1'b0;
  assign syndec[67] = (syndout_int == 9'b010010100)? 1'b1 : 1'b0;
  assign syndec[230] = (syndout_int == 9'b000001101)? 1'b1 : 1'b0;
  assign syndec[133] = (syndout_int == 9'b100010010)? 1'b1 : 1'b0;
  assign syndec[102] = (syndout_int == 9'b100111010)? 1'b1 : 1'b0;
  assign syndec[177] = (syndout_int == 9'b101111011)? 1'b1 : 1'b0;
  assign syndec[243] = (syndout_int == 9'b111000110)? 1'b1 : 1'b0;
  assign syndec[46] = (syndout_int == 9'b110110001)? 1'b1 : 1'b0;
  assign syndec[0] = (syndout_int == 9'b111001111)? 1'b1 : 1'b0;
  assign syndec[231] = (syndout_int == 9'b000000111)? 1'b1 : 1'b0;
  assign syndec[225] = (syndout_int == 9'b111110110)? 1'b1 : 1'b0;
  assign syndec[229] = (syndout_int == 9'b000011111)? 1'b1 : 1'b0;
  assign syndec[14] = (syndout_int == 9'b000110001)? 1'b1 : 1'b0;
  assign syndec[88] = (syndout_int == 9'b010100010)? 1'b1 : 1'b0;
  assign syndec[80] = (syndout_int == 9'b101001110)? 1'b1 : 1'b0;
  assign syndec[111] = (syndout_int == 9'b011010101)? 1'b1 : 1'b0;
  assign syndec[62] = (syndout_int == 9'b001110000)? 1'b1 : 1'b0;
  assign syndec[143] = (syndout_int == 9'b011011111)? 1'b1 : 1'b0;
  assign syndec[51] = (syndout_int == 9'b110010101)? 1'b1 : 1'b0;
  assign syndec[162] = (syndout_int == 9'b010111001)? 1'b1 : 1'b0;
  assign syndec[246] = (syndout_int == 9'b111000000)? 1'b1 : 1'b0;
  assign syndec[82] = (syndout_int == 9'b101010011)? 1'b1 : 1'b0;
  assign syndec[113] = (syndout_int == 9'b011101010)? 1'b1 : 1'b0;
  assign syndec[43] = (syndout_int == 9'b110101001)? 1'b1 : 1'b0;
  assign syndec[217] = (syndout_int == 9'b001001001)? 1'b1 : 1'b0;
  assign syndec[199] = (syndout_int == 9'b110010000)? 1'b1 : 1'b0;
  assign syndec[233] = (syndout_int == 9'b000111101)? 1'b1 : 1'b0;
  assign syndec[226] = (syndout_int == 9'b111110011)? 1'b1 : 1'b0;
  assign syndec[235] = (syndout_int == 9'b000111000)? 1'b1 : 1'b0;
  assign syndec[28] = (syndout_int == 9'b111101011)? 1'b1 : 1'b0;
  assign syndec[137] = (syndout_int == 9'b011101100)? 1'b1 : 1'b0;
  assign syndec[55] = (syndout_int == 9'b110011100)? 1'b1 : 1'b0;
  assign syndec[241] = (syndout_int == 9'b111001100)? 1'b1 : 1'b0;
  assign syndec[16] = (syndout_int == 9'b000001110)? 1'b1 : 1'b0;
  assign syndec[7] = (syndout_int == 9'b111011101)? 1'b1 : 1'b0;
  assign syndec[117] = (syndout_int == 9'b011111000)? 1'b1 : 1'b0;
  assign syndec[228] = (syndout_int == 9'b111100001)? 1'b1 : 1'b0;
  assign syndec[139] = (syndout_int == 9'b011100110)? 1'b1 : 1'b0;
  assign fixchk[0] = (syndout_int == 9'b000000001)? 1'b1 : 1'b0;
  assign syndec[75] = (syndout_int == 9'b101101001)? 1'b1 : 1'b0;
  assign syndec[87] = (syndout_int == 9'b101011100)? 1'b1 : 1'b0;
  assign syndec[245] = (syndout_int == 9'b111000011)? 1'b1 : 1'b0;
  assign syndec[204] = (syndout_int == 9'b110000010)? 1'b1 : 1'b0;
  assign syndec[106] = (syndout_int == 9'b011000111)? 1'b1 : 1'b0;
  assign fixchk[8] = (syndout_int == 9'b100000000)? 1'b1 : 1'b0;
  assign syndec[69] = (syndout_int == 9'b010011000)? 1'b1 : 1'b0;
  assign syndec[176] = (syndout_int == 9'b101111101)? 1'b1 : 1'b0;
  assign syndec[63] = (syndout_int == 9'b001110101)? 1'b1 : 1'b0;
  assign syndec[70] = (syndout_int == 9'b010011011)? 1'b1 : 1'b0;
  assign syndec[187] = (syndout_int == 9'b010000110)? 1'b1 : 1'b0;
  assign syndec[190] = (syndout_int == 9'b001111111)? 1'b1 : 1'b0;
  assign syndec[237] = (syndout_int == 9'b000110010)? 1'b1 : 1'b0;
  assign syndec[84] = (syndout_int == 9'b101010110)? 1'b1 : 1'b0;
  assign syndec[21] = (syndout_int == 9'b000011001)? 1'b1 : 1'b0;
  assign syndec[234] = (syndout_int == 9'b000111011)? 1'b1 : 1'b0;
  assign syndec[34] = (syndout_int == 9'b001010010)? 1'b1 : 1'b0;
  assign syndec[168] = (syndout_int == 9'b101010000)? 1'b1 : 1'b0;
  assign syndec[221] = (syndout_int == 9'b111111111)? 1'b1 : 1'b0;
  assign syndec[2] = (syndout_int == 9'b111010010)? 1'b1 : 1'b0;
  assign syndec[213] = (syndout_int == 9'b110100000)? 1'b1 : 1'b0;
  assign syndec[91] = (syndout_int == 9'b010101000)? 1'b1 : 1'b0;
  assign syndec[141] = (syndout_int == 9'b011100011)? 1'b1 : 1'b0;
  assign syndec[200] = (syndout_int == 9'b110001101)? 1'b1 : 1'b0;
  assign syndec[183] = (syndout_int == 9'b010011110)? 1'b1 : 1'b0;
  assign syndec[90] = (syndout_int == 9'b010100111)? 1'b1 : 1'b0;
  assign syndec[1] = (syndout_int == 9'b111001010)? 1'b1 : 1'b0;
  assign syndec[24] = (syndout_int == 9'b111100010)? 1'b1 : 1'b0;
  assign syndec[236] = (syndout_int == 9'b000110111)? 1'b1 : 1'b0;
  assign syndec[240] = (syndout_int == 9'b111010001)? 1'b1 : 1'b0;
  assign fixchk[1] = (syndout_int == 9'b000000010)? 1'b1 : 1'b0;
  assign syndec[189] = (syndout_int == 9'b010000011)? 1'b1 : 1'b0;
  assign syndec[205] = (syndout_int == 9'b110000001)? 1'b1 : 1'b0;
  assign syndec[212] = (syndout_int == 9'b110101111)? 1'b1 : 1'b0;
  assign syndec[120] = (syndout_int == 9'b100000011)? 1'b1 : 1'b0;
  assign syndec[36] = (syndout_int == 9'b001010111)? 1'b1 : 1'b0;
  assign syndec[211] = (syndout_int == 9'b110110010)? 1'b1 : 1'b0;
  assign syndec[48] = (syndout_int == 9'b110001110)? 1'b1 : 1'b0;
  assign syndec[83] = (syndout_int == 9'b101010101)? 1'b1 : 1'b0;
  assign syndec[94] = (syndout_int == 9'b010110000)? 1'b1 : 1'b0;
  assign syndec[64] = (syndout_int == 9'b010001111)? 1'b1 : 1'b0;
  assign syndec[29] = (syndout_int == 9'b111101101)? 1'b1 : 1'b0;
  assign syndec[52] = (syndout_int == 9'b110010110)? 1'b1 : 1'b0;
  assign syndec[122] = (syndout_int == 9'b100000110)? 1'b1 : 1'b0;
  assign syndec[247] = 1'b0;
  assign syndec[157] = (syndout_int == 9'b100100010)? 1'b1 : 1'b0;
  assign syndec[116] = (syndout_int == 9'b011110111)? 1'b1 : 1'b0;
  assign syndec[15] = (syndout_int == 9'b000110100)? 1'b1 : 1'b0;
  assign fixchk[3] = (syndout_int == 9'b000001000)? 1'b1 : 1'b0;
  assign syndec[92] = (syndout_int == 9'b010101011)? 1'b1 : 1'b0;
  assign syndec[179] = (syndout_int == 9'b101110111)? 1'b1 : 1'b0;
  assign syndec[26] = (syndout_int == 9'b111100111)? 1'b1 : 1'b0;
  assign syndec[66] = (syndout_int == 9'b010010010)? 1'b1 : 1'b0;
  assign syndec[156] = (syndout_int == 9'b100100100)? 1'b1 : 1'b0;
  assign syndec[140] = (syndout_int == 9'b011100101)? 1'b1 : 1'b0;
  assign syndec[197] = (syndout_int == 9'b001100001)? 1'b1 : 1'b0;
  assign syndec[142] = (syndout_int == 9'b011100000)? 1'b1 : 1'b0;
  assign syndec[73] = (syndout_int == 9'b101100101)? 1'b1 : 1'b0;
  assign syndec[164] = (syndout_int == 9'b010110011)? 1'b1 : 1'b0;
  assign syndec[81] = (syndout_int == 9'b101001011)? 1'b1 : 1'b0;
  assign syndec[78] = (syndout_int == 9'b101110001)? 1'b1 : 1'b0;
  assign syndec[181] = (syndout_int == 9'b101101111)? 1'b1 : 1'b0;
  assign syndec[93] = (syndout_int == 9'b010101101)? 1'b1 : 1'b0;
  assign fixchk[2] = (syndout_int == 9'b000000100)? 1'b1 : 1'b0;
  assign syndec[166] = (syndout_int == 9'b010100001)? 1'b1 : 1'b0;
  assign syndec[136] = (syndout_int == 9'b011110001)? 1'b1 : 1'b0;
  assign syndec[99] = (syndout_int == 9'b100110101)? 1'b1 : 1'b0;
  assign syndec[17] = (syndout_int == 9'b000001011)? 1'b1 : 1'b0;
  assign syndec[58] = (syndout_int == 9'b001100111)? 1'b1 : 1'b0;
  assign syndec[38] = (syndout_int == 9'b001011011)? 1'b1 : 1'b0;
  assign syndec[112] = (syndout_int == 9'b011101111)? 1'b1 : 1'b0;
  assign syndec[219] = (syndout_int == 9'b001000101)? 1'b1 : 1'b0;
  assign syndec[119] = (syndout_int == 9'b011111101)? 1'b1 : 1'b0;
  assign syndec[8] = (syndout_int == 9'b000100011)? 1'b1 : 1'b0;
  assign syndec[54] = (syndout_int == 9'b110011010)? 1'b1 : 1'b0;
  assign syndec[19] = (syndout_int == 9'b000010101)? 1'b1 : 1'b0;
  assign syndec[154] = (syndout_int == 9'b100101000)? 1'b1 : 1'b0;
  assign syndec[3] = (syndout_int == 9'b111010100)? 1'b1 : 1'b0;
  assign syndec[242] = (syndout_int == 9'b111001001)? 1'b1 : 1'b0;
  assign syndec[109] = (syndout_int == 9'b011001101)? 1'b1 : 1'b0;
  assign syndec[60] = (syndout_int == 9'b001101011)? 1'b1 : 1'b0;
  assign syndec[185] = (syndout_int == 9'b010001100)? 1'b1 : 1'b0;
  assign syndec[175] = (syndout_int == 9'b101111110)? 1'b1 : 1'b0;
  assign syndec[23] = (syndout_int == 9'b000011100)? 1'b1 : 1'b0;
  assign syndec[79] = (syndout_int == 9'b101110100)? 1'b1 : 1'b0;
  assign syndec[134] = (syndout_int == 9'b100001111)? 1'b1 : 1'b0;
  assign syndec[31] = (syndout_int == 9'b111110101)? 1'b1 : 1'b0;
  assign syndec[232] = (syndout_int == 9'b000111110)? 1'b1 : 1'b0;
  assign syndec[196] = (syndout_int == 9'b001101110)? 1'b1 : 1'b0;
  assign syndec[147] = (syndout_int == 9'b011010110)? 1'b1 : 1'b0;
  assign syndec[5] = (syndout_int == 9'b111011000)? 1'b1 : 1'b0;
  assign syndec[49] = (syndout_int == 9'b110001011)? 1'b1 : 1'b0;
  assign syndec[193] = (syndout_int == 9'b001111001)? 1'b1 : 1'b0;
  assign syndec[165] = (syndout_int == 9'b010101110)? 1'b1 : 1'b0;
  assign syndec[44] = (syndout_int == 9'b110101010)? 1'b1 : 1'b0;
  assign syndec[13] = (syndout_int == 9'b000101100)? 1'b1 : 1'b0;
  assign syndec[76] = (syndout_int == 9'b101101010)? 1'b1 : 1'b0;
  assign syndec[105] = (syndout_int == 9'b011000100)? 1'b1 : 1'b0;
  assign syndec[206] = (syndout_int == 9'b110111110)? 1'b1 : 1'b0;
  assign syndec[222] = (syndout_int == 9'b111111100)? 1'b1 : 1'b0;
  assign syndec[50] = (syndout_int == 9'b110010011)? 1'b1 : 1'b0;
  assign syndec[163] = (syndout_int == 9'b010110110)? 1'b1 : 1'b0;
  assign syndec[115] = (syndout_int == 9'b011110100)? 1'b1 : 1'b0;
  assign syndec[184] = (syndout_int == 9'b010010001)? 1'b1 : 1'b0;
  assign syndec[86] = (syndout_int == 9'b101011010)? 1'b1 : 1'b0;
  assign syndec[203] = (syndout_int == 9'b110000100)? 1'b1 : 1'b0;
  assign syndec[161] = (syndout_int == 9'b010111010)? 1'b1 : 1'b0;
  assign syndec[53] = (syndout_int == 9'b110011001)? 1'b1 : 1'b0;

  always @ (datain) begin : td_PROC

    integer i;

    for (i=0 ; i <= 255 ; i=i+1) begin
      if (i < WIDTH)
        dat_in[i] = datain[i];
      else
        dat_in[i] = 1'b0;
    end
  end

  assign syndout_int = chkout_int ^ chkin;

  assign err_detect = ~gen & ( |syndout_int );

  assign err_multpl = err_detect & ( ~(^syndout_int) || (|syndec[247:WIDTH]) );

  assign fixdata = syndec[WIDTH-1:0];

  assign chkout = (gen == 1'b1)? chkout_int : (correct_n == 1'b0)? chkin ^ fixchk : chkin;

  assign dataout = ((gen == 1'b0) && (correct_n == 1'b0))? datain ^ fixdata : datain;

  assign syndout = syndout_int;

// spyglass enable_block W146
endmodule
