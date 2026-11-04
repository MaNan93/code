
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
// Description : DWC_pcie_ctl_bcm46_e.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 1cb2644b
//
////////////////////////////////////////////////////////////////////////////////

module DWC_pcie_ctl_bcm46_e(
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

parameter integer WIDTH = 256;

input                   gen;            // Active high check-bit generate control input port
input                   correct_n;      // Active low bit correction control input port
input  [WIDTH-1:0]      datain;         // Data input port (for write, read & scrub)
input  [9:0]            chkin;          // Check bit input port (for read)
output [WIDTH-1:0]      fixdata;        // Data fixed flag port (one-hot)
output                  err_detect;     // Active high error detect output
output                  err_multpl;     // Active high multiple bit error detect output
output [WIDTH-1:0]      dataout;        // Data output port (for read & scrub)
output [9:0]            chkout;         // Check bit output port (for write & scrub)
output [9:0]            syndout;        // Error syndrome output port (for error logging)

wire   [9:0]            chkout_int;
wire   [9:0]            syndout_int;
wire   [9:0]            fixchk;
wire   [502:0]          syndec;
reg    [511:0]          dat_in;
wire   [WIDTH-1:0]      fixdata;


  assign chkout_int[0] = dat_in[1] ^ dat_in[2] ^ dat_in[3] ^ dat_in[5] ^
            dat_in[8] ^ dat_in[9] ^ dat_in[11] ^ dat_in[14] ^ dat_in[17] ^
            dat_in[18] ^ dat_in[19] ^ dat_in[21] ^ dat_in[24] ^ dat_in[25] ^
            dat_in[27] ^ dat_in[30] ^ dat_in[32] ^ dat_in[36] ^ dat_in[38] ^
            dat_in[39] ^ dat_in[42] ^ dat_in[44] ^ dat_in[45] ^ dat_in[47] ^
            dat_in[48] ^ dat_in[52] ^ dat_in[54] ^ dat_in[55] ^ dat_in[58] ^
            dat_in[60] ^ dat_in[61] ^ dat_in[63] ^ dat_in[64] ^ dat_in[68] ^
            dat_in[70] ^ dat_in[71] ^ dat_in[74] ^ dat_in[76] ^ dat_in[77] ^
            dat_in[79] ^ dat_in[80] ^ dat_in[84] ^ dat_in[86] ^ dat_in[87] ^
            dat_in[90] ^ dat_in[92] ^ dat_in[93] ^ dat_in[95] ^ dat_in[96] ^
            dat_in[100] ^ dat_in[102] ^ dat_in[103] ^ dat_in[106] ^ dat_in[108] ^
            dat_in[109] ^ dat_in[111] ^ dat_in[112] ^ dat_in[116] ^ dat_in[118] ^
            dat_in[119] ^ dat_in[122] ^ dat_in[124] ^ dat_in[125] ^ dat_in[127] ^
            dat_in[128] ^ dat_in[132] ^ dat_in[134] ^ dat_in[135] ^ dat_in[138] ^
            dat_in[140] ^ dat_in[141] ^ dat_in[143] ^ dat_in[144] ^ dat_in[148] ^
            dat_in[150] ^ dat_in[151] ^ dat_in[154] ^ dat_in[156] ^ dat_in[157] ^
            dat_in[159] ^ dat_in[160] ^ dat_in[164] ^ dat_in[166] ^ dat_in[167] ^
            dat_in[170] ^ dat_in[172] ^ dat_in[173] ^ dat_in[175] ^ dat_in[176] ^
            dat_in[180] ^ dat_in[182] ^ dat_in[183] ^ dat_in[186] ^ dat_in[188] ^
            dat_in[189] ^ dat_in[191] ^ dat_in[192] ^ dat_in[196] ^ dat_in[198] ^
            dat_in[199] ^ dat_in[202] ^ dat_in[204] ^ dat_in[205] ^ dat_in[207] ^
            dat_in[208] ^ dat_in[212] ^ dat_in[214] ^ dat_in[215] ^ dat_in[218] ^
            dat_in[220] ^ dat_in[221] ^ dat_in[223] ^ dat_in[224] ^ dat_in[228] ^
            dat_in[230] ^ dat_in[231] ^ dat_in[234] ^ dat_in[236] ^ dat_in[237] ^
            dat_in[239] ^ dat_in[240] ^ dat_in[244] ^ dat_in[246] ^ dat_in[247] ^
            dat_in[250] ^ dat_in[252] ^ dat_in[253] ^ dat_in[255] ^ dat_in[257] ^
            dat_in[259] ^ dat_in[261] ^ dat_in[262] ^ dat_in[263] ^ dat_in[266] ^
            dat_in[268] ^ dat_in[270] ^ dat_in[272] ^ dat_in[274] ^ dat_in[276] ^
            dat_in[277] ^ dat_in[279] ^ dat_in[282] ^ dat_in[284] ^ dat_in[286] ^
            dat_in[288] ^ dat_in[290] ^ dat_in[292] ^ dat_in[293] ^ dat_in[295] ^
            dat_in[298] ^ dat_in[300] ^ dat_in[302] ^ dat_in[304] ^ dat_in[306] ^
            dat_in[308] ^ dat_in[309] ^ dat_in[311] ^ dat_in[314] ^ dat_in[316] ^
            dat_in[318] ^ dat_in[320] ^ dat_in[322] ^ dat_in[324] ^ dat_in[325] ^
            dat_in[327] ^ dat_in[330] ^ dat_in[332] ^ dat_in[334] ^ dat_in[336] ^
            dat_in[338] ^ dat_in[340] ^ dat_in[341] ^ dat_in[343] ^ dat_in[346] ^
            dat_in[348] ^ dat_in[350] ^ dat_in[352] ^ dat_in[354] ^ dat_in[356] ^
            dat_in[357] ^ dat_in[359] ^ dat_in[362] ^ dat_in[364] ^ dat_in[366] ^
            dat_in[368] ^ dat_in[370] ^ dat_in[372] ^ dat_in[373] ^ dat_in[374] ^
            dat_in[377] ^ dat_in[379] ^ dat_in[381] ^ dat_in[383] ^ dat_in[385] ^
            dat_in[387] ^ dat_in[388] ^ dat_in[390] ^ dat_in[393] ^ dat_in[395] ^
            dat_in[397] ^ dat_in[399] ^ dat_in[401] ^ dat_in[403] ^ dat_in[404] ^
            dat_in[406] ^ dat_in[409] ^ dat_in[411] ^ dat_in[413] ^ dat_in[415] ^
            dat_in[417] ^ dat_in[419] ^ dat_in[420] ^ dat_in[422] ^ dat_in[425] ^
            dat_in[427] ^ dat_in[429] ^ dat_in[431] ^ dat_in[433] ^ dat_in[435] ^
            dat_in[436] ^ dat_in[437] ^ dat_in[440] ^ dat_in[442] ^ dat_in[444] ^
            dat_in[446] ^ dat_in[448] ^ dat_in[450] ^ dat_in[451] ^ dat_in[453] ^
            dat_in[456] ^ dat_in[458] ^ dat_in[460] ^ dat_in[462] ^ dat_in[464] ^
            dat_in[466] ^ dat_in[467] ^ dat_in[468] ^ dat_in[471] ^ dat_in[473] ^
            dat_in[475] ^ dat_in[476] ^ dat_in[477] ^ dat_in[478] ^ dat_in[480] ^
            dat_in[481] ^ dat_in[483] ^ dat_in[485] ^ dat_in[487] ^ dat_in[489] ^
            dat_in[491] ^ dat_in[494] ^ dat_in[496] ^ dat_in[497] ^ dat_in[499] ^ dat_in[501];

  assign chkout_int[1] = dat_in[0] ^ dat_in[1] ^ dat_in[2] ^ dat_in[4] ^
            dat_in[6] ^ dat_in[8] ^ dat_in[10] ^ dat_in[12] ^ dat_in[16] ^
            dat_in[17] ^ dat_in[18] ^ dat_in[20] ^ dat_in[22] ^ dat_in[24] ^
            dat_in[26] ^ dat_in[28] ^ dat_in[32] ^ dat_in[33] ^ dat_in[34] ^
            dat_in[36] ^ dat_in[38] ^ dat_in[40] ^ dat_in[42] ^ dat_in[44] ^
            dat_in[48] ^ dat_in[49] ^ dat_in[50] ^ dat_in[52] ^ dat_in[54] ^
            dat_in[56] ^ dat_in[58] ^ dat_in[60] ^ dat_in[64] ^ dat_in[65] ^
            dat_in[66] ^ dat_in[68] ^ dat_in[70] ^ dat_in[72] ^ dat_in[74] ^
            dat_in[76] ^ dat_in[80] ^ dat_in[81] ^ dat_in[82] ^ dat_in[84] ^
            dat_in[86] ^ dat_in[88] ^ dat_in[90] ^ dat_in[92] ^ dat_in[96] ^
            dat_in[97] ^ dat_in[98] ^ dat_in[100] ^ dat_in[102] ^ dat_in[104] ^
            dat_in[106] ^ dat_in[108] ^ dat_in[112] ^ dat_in[113] ^ dat_in[114] ^
            dat_in[116] ^ dat_in[118] ^ dat_in[120] ^ dat_in[122] ^ dat_in[124] ^
            dat_in[128] ^ dat_in[129] ^ dat_in[130] ^ dat_in[132] ^ dat_in[134] ^
            dat_in[136] ^ dat_in[138] ^ dat_in[140] ^ dat_in[144] ^ dat_in[145] ^
            dat_in[146] ^ dat_in[148] ^ dat_in[150] ^ dat_in[152] ^ dat_in[154] ^
            dat_in[156] ^ dat_in[160] ^ dat_in[161] ^ dat_in[162] ^ dat_in[164] ^
            dat_in[166] ^ dat_in[168] ^ dat_in[170] ^ dat_in[172] ^ dat_in[176] ^
            dat_in[177] ^ dat_in[178] ^ dat_in[180] ^ dat_in[182] ^ dat_in[184] ^
            dat_in[186] ^ dat_in[188] ^ dat_in[192] ^ dat_in[193] ^ dat_in[194] ^
            dat_in[196] ^ dat_in[198] ^ dat_in[200] ^ dat_in[202] ^ dat_in[204] ^
            dat_in[208] ^ dat_in[209] ^ dat_in[210] ^ dat_in[212] ^ dat_in[214] ^
            dat_in[216] ^ dat_in[218] ^ dat_in[220] ^ dat_in[224] ^ dat_in[225] ^
            dat_in[226] ^ dat_in[228] ^ dat_in[230] ^ dat_in[232] ^ dat_in[234] ^
            dat_in[236] ^ dat_in[240] ^ dat_in[241] ^ dat_in[242] ^ dat_in[244] ^
            dat_in[246] ^ dat_in[248] ^ dat_in[250] ^ dat_in[252] ^ dat_in[256] ^
            dat_in[260] ^ dat_in[262] ^ dat_in[263] ^ dat_in[265] ^ dat_in[267] ^
            dat_in[268] ^ dat_in[269] ^ dat_in[271] ^ dat_in[275] ^ dat_in[277] ^
            dat_in[279] ^ dat_in[281] ^ dat_in[283] ^ dat_in[284] ^ dat_in[285] ^
            dat_in[287] ^ dat_in[291] ^ dat_in[293] ^ dat_in[295] ^ dat_in[297] ^
            dat_in[299] ^ dat_in[300] ^ dat_in[301] ^ dat_in[303] ^ dat_in[307] ^
            dat_in[309] ^ dat_in[311] ^ dat_in[313] ^ dat_in[315] ^ dat_in[316] ^
            dat_in[317] ^ dat_in[319] ^ dat_in[323] ^ dat_in[325] ^ dat_in[327] ^
            dat_in[329] ^ dat_in[331] ^ dat_in[332] ^ dat_in[333] ^ dat_in[335] ^
            dat_in[339] ^ dat_in[341] ^ dat_in[343] ^ dat_in[345] ^ dat_in[347] ^
            dat_in[348] ^ dat_in[349] ^ dat_in[351] ^ dat_in[355] ^ dat_in[357] ^
            dat_in[359] ^ dat_in[361] ^ dat_in[363] ^ dat_in[364] ^ dat_in[365] ^
            dat_in[367] ^ dat_in[371] ^ dat_in[373] ^ dat_in[374] ^ dat_in[376] ^
            dat_in[378] ^ dat_in[379] ^ dat_in[380] ^ dat_in[382] ^ dat_in[386] ^
            dat_in[388] ^ dat_in[390] ^ dat_in[392] ^ dat_in[394] ^ dat_in[395] ^
            dat_in[396] ^ dat_in[398] ^ dat_in[402] ^ dat_in[404] ^ dat_in[406] ^
            dat_in[408] ^ dat_in[410] ^ dat_in[411] ^ dat_in[412] ^ dat_in[414] ^
            dat_in[418] ^ dat_in[420] ^ dat_in[422] ^ dat_in[424] ^ dat_in[426] ^
            dat_in[427] ^ dat_in[428] ^ dat_in[430] ^ dat_in[434] ^ dat_in[436] ^
            dat_in[437] ^ dat_in[439] ^ dat_in[441] ^ dat_in[442] ^ dat_in[443] ^
            dat_in[445] ^ dat_in[449] ^ dat_in[451] ^ dat_in[453] ^ dat_in[455] ^
            dat_in[457] ^ dat_in[458] ^ dat_in[459] ^ dat_in[461] ^ dat_in[465] ^
            dat_in[467] ^ dat_in[468] ^ dat_in[470] ^ dat_in[472] ^ dat_in[473] ^
            dat_in[474] ^ dat_in[476] ^ dat_in[478] ^ dat_in[479] ^ dat_in[481] ^
            dat_in[483] ^ dat_in[484] ^ dat_in[485] ^ dat_in[487] ^ dat_in[491] ^
            dat_in[493] ^ dat_in[495] ^ dat_in[497] ^ dat_in[499] ^ dat_in[500] ^ dat_in[501];

  assign chkout_int[2] = ~dat_in[0] ^ dat_in[3] ^ dat_in[4] ^ dat_in[7] ^
            dat_in[9] ^ dat_in[10] ^ dat_in[13] ^ dat_in[15] ^ dat_in[16] ^
            dat_in[19] ^ dat_in[20] ^ dat_in[23] ^ dat_in[25] ^ dat_in[26] ^
            dat_in[29] ^ dat_in[31] ^ dat_in[32] ^ dat_in[35] ^ dat_in[36] ^
            dat_in[39] ^ dat_in[41] ^ dat_in[42] ^ dat_in[45] ^ dat_in[47] ^
            dat_in[48] ^ dat_in[51] ^ dat_in[52] ^ dat_in[55] ^ dat_in[57] ^
            dat_in[58] ^ dat_in[61] ^ dat_in[63] ^ dat_in[64] ^ dat_in[67] ^
            dat_in[68] ^ dat_in[71] ^ dat_in[73] ^ dat_in[74] ^ dat_in[77] ^
            dat_in[79] ^ dat_in[80] ^ dat_in[83] ^ dat_in[84] ^ dat_in[87] ^
            dat_in[89] ^ dat_in[90] ^ dat_in[93] ^ dat_in[95] ^ dat_in[96] ^
            dat_in[99] ^ dat_in[100] ^ dat_in[103] ^ dat_in[105] ^ dat_in[106] ^
            dat_in[109] ^ dat_in[111] ^ dat_in[112] ^ dat_in[115] ^ dat_in[116] ^
            dat_in[119] ^ dat_in[121] ^ dat_in[122] ^ dat_in[125] ^ dat_in[127] ^
            dat_in[128] ^ dat_in[131] ^ dat_in[132] ^ dat_in[135] ^ dat_in[137] ^
            dat_in[138] ^ dat_in[141] ^ dat_in[143] ^ dat_in[144] ^ dat_in[147] ^
            dat_in[148] ^ dat_in[151] ^ dat_in[153] ^ dat_in[154] ^ dat_in[157] ^
            dat_in[159] ^ dat_in[160] ^ dat_in[163] ^ dat_in[164] ^ dat_in[167] ^
            dat_in[169] ^ dat_in[170] ^ dat_in[173] ^ dat_in[175] ^ dat_in[176] ^
            dat_in[179] ^ dat_in[180] ^ dat_in[183] ^ dat_in[185] ^ dat_in[186] ^
            dat_in[189] ^ dat_in[191] ^ dat_in[192] ^ dat_in[195] ^ dat_in[196] ^
            dat_in[199] ^ dat_in[201] ^ dat_in[202] ^ dat_in[205] ^ dat_in[207] ^
            dat_in[208] ^ dat_in[211] ^ dat_in[212] ^ dat_in[215] ^ dat_in[217] ^
            dat_in[218] ^ dat_in[221] ^ dat_in[223] ^ dat_in[224] ^ dat_in[227] ^
            dat_in[228] ^ dat_in[231] ^ dat_in[233] ^ dat_in[234] ^ dat_in[237] ^
            dat_in[239] ^ dat_in[240] ^ dat_in[243] ^ dat_in[244] ^ dat_in[247] ^
            dat_in[249] ^ dat_in[250] ^ dat_in[253] ^ dat_in[255] ^ dat_in[256] ^
            dat_in[258] ^ dat_in[260] ^ dat_in[261] ^ dat_in[263] ^ dat_in[264] ^
            dat_in[267] ^ dat_in[269] ^ dat_in[271] ^ dat_in[273] ^ dat_in[275] ^
            dat_in[276] ^ dat_in[279] ^ dat_in[280] ^ dat_in[283] ^ dat_in[285] ^
            dat_in[287] ^ dat_in[289] ^ dat_in[291] ^ dat_in[292] ^ dat_in[295] ^
            dat_in[296] ^ dat_in[299] ^ dat_in[301] ^ dat_in[303] ^ dat_in[305] ^
            dat_in[307] ^ dat_in[308] ^ dat_in[311] ^ dat_in[312] ^ dat_in[315] ^
            dat_in[317] ^ dat_in[319] ^ dat_in[321] ^ dat_in[323] ^ dat_in[324] ^
            dat_in[327] ^ dat_in[328] ^ dat_in[331] ^ dat_in[333] ^ dat_in[335] ^
            dat_in[337] ^ dat_in[339] ^ dat_in[340] ^ dat_in[343] ^ dat_in[344] ^
            dat_in[347] ^ dat_in[349] ^ dat_in[351] ^ dat_in[353] ^ dat_in[355] ^
            dat_in[356] ^ dat_in[359] ^ dat_in[360] ^ dat_in[363] ^ dat_in[365] ^
            dat_in[367] ^ dat_in[369] ^ dat_in[371] ^ dat_in[372] ^ dat_in[374] ^
            dat_in[375] ^ dat_in[378] ^ dat_in[380] ^ dat_in[382] ^ dat_in[384] ^
            dat_in[386] ^ dat_in[387] ^ dat_in[390] ^ dat_in[391] ^ dat_in[394] ^
            dat_in[396] ^ dat_in[398] ^ dat_in[400] ^ dat_in[402] ^ dat_in[403] ^
            dat_in[406] ^ dat_in[407] ^ dat_in[410] ^ dat_in[412] ^ dat_in[414] ^
            dat_in[416] ^ dat_in[418] ^ dat_in[419] ^ dat_in[422] ^ dat_in[423] ^
            dat_in[426] ^ dat_in[428] ^ dat_in[430] ^ dat_in[432] ^ dat_in[434] ^
            dat_in[435] ^ dat_in[437] ^ dat_in[438] ^ dat_in[441] ^ dat_in[443] ^
            dat_in[445] ^ dat_in[447] ^ dat_in[449] ^ dat_in[450] ^ dat_in[453] ^
            dat_in[454] ^ dat_in[457] ^ dat_in[459] ^ dat_in[461] ^ dat_in[463] ^
            dat_in[465] ^ dat_in[466] ^ dat_in[468] ^ dat_in[469] ^ dat_in[472] ^
            dat_in[474] ^ dat_in[476] ^ dat_in[477] ^ dat_in[478] ^ dat_in[479] ^
            dat_in[480] ^ dat_in[483] ^ dat_in[485] ^ dat_in[487] ^ dat_in[489] ^
            dat_in[491] ^ dat_in[492] ^ dat_in[495] ^ dat_in[496] ^ dat_in[499] ^ dat_in[501];

  assign chkout_int[3] = ~dat_in[0] ^ dat_in[1] ^ dat_in[5] ^ dat_in[6] ^
            dat_in[7] ^ dat_in[11] ^ dat_in[12] ^ dat_in[13] ^ dat_in[16] ^
            dat_in[17] ^ dat_in[21] ^ dat_in[22] ^ dat_in[23] ^ dat_in[27] ^
            dat_in[28] ^ dat_in[29] ^ dat_in[32] ^ dat_in[33] ^ dat_in[37] ^
            dat_in[38] ^ dat_in[39] ^ dat_in[43] ^ dat_in[44] ^ dat_in[45] ^
            dat_in[48] ^ dat_in[49] ^ dat_in[53] ^ dat_in[54] ^ dat_in[55] ^
            dat_in[59] ^ dat_in[60] ^ dat_in[61] ^ dat_in[64] ^ dat_in[65] ^
            dat_in[69] ^ dat_in[70] ^ dat_in[71] ^ dat_in[75] ^ dat_in[76] ^
            dat_in[77] ^ dat_in[80] ^ dat_in[81] ^ dat_in[85] ^ dat_in[86] ^
            dat_in[87] ^ dat_in[91] ^ dat_in[92] ^ dat_in[93] ^ dat_in[96] ^
            dat_in[97] ^ dat_in[101] ^ dat_in[102] ^ dat_in[103] ^ dat_in[107] ^
            dat_in[108] ^ dat_in[109] ^ dat_in[112] ^ dat_in[113] ^ dat_in[117] ^
            dat_in[118] ^ dat_in[119] ^ dat_in[123] ^ dat_in[124] ^ dat_in[125] ^
            dat_in[128] ^ dat_in[129] ^ dat_in[133] ^ dat_in[134] ^ dat_in[135] ^
            dat_in[139] ^ dat_in[140] ^ dat_in[141] ^ dat_in[144] ^ dat_in[145] ^
            dat_in[149] ^ dat_in[150] ^ dat_in[151] ^ dat_in[155] ^ dat_in[156] ^
            dat_in[157] ^ dat_in[160] ^ dat_in[161] ^ dat_in[165] ^ dat_in[166] ^
            dat_in[167] ^ dat_in[171] ^ dat_in[172] ^ dat_in[173] ^ dat_in[176] ^
            dat_in[177] ^ dat_in[181] ^ dat_in[182] ^ dat_in[183] ^ dat_in[187] ^
            dat_in[188] ^ dat_in[189] ^ dat_in[192] ^ dat_in[193] ^ dat_in[197] ^
            dat_in[198] ^ dat_in[199] ^ dat_in[203] ^ dat_in[204] ^ dat_in[205] ^
            dat_in[208] ^ dat_in[209] ^ dat_in[213] ^ dat_in[214] ^ dat_in[215] ^
            dat_in[219] ^ dat_in[220] ^ dat_in[221] ^ dat_in[224] ^ dat_in[225] ^
            dat_in[229] ^ dat_in[230] ^ dat_in[231] ^ dat_in[235] ^ dat_in[236] ^
            dat_in[237] ^ dat_in[240] ^ dat_in[241] ^ dat_in[245] ^ dat_in[246] ^
            dat_in[247] ^ dat_in[251] ^ dat_in[252] ^ dat_in[253] ^ dat_in[256] ^
            dat_in[258] ^ dat_in[259] ^ dat_in[263] ^ dat_in[264] ^ dat_in[265] ^
            dat_in[266] ^ dat_in[269] ^ dat_in[271] ^ dat_in[273] ^ dat_in[274] ^
            dat_in[279] ^ dat_in[280] ^ dat_in[281] ^ dat_in[282] ^ dat_in[285] ^
            dat_in[287] ^ dat_in[289] ^ dat_in[290] ^ dat_in[295] ^ dat_in[296] ^
            dat_in[297] ^ dat_in[298] ^ dat_in[301] ^ dat_in[303] ^ dat_in[305] ^
            dat_in[306] ^ dat_in[311] ^ dat_in[312] ^ dat_in[313] ^ dat_in[314] ^
            dat_in[317] ^ dat_in[319] ^ dat_in[321] ^ dat_in[322] ^ dat_in[327] ^
            dat_in[328] ^ dat_in[329] ^ dat_in[330] ^ dat_in[333] ^ dat_in[335] ^
            dat_in[337] ^ dat_in[338] ^ dat_in[343] ^ dat_in[344] ^ dat_in[345] ^
            dat_in[346] ^ dat_in[349] ^ dat_in[351] ^ dat_in[353] ^ dat_in[354] ^
            dat_in[359] ^ dat_in[360] ^ dat_in[361] ^ dat_in[362] ^ dat_in[365] ^
            dat_in[367] ^ dat_in[369] ^ dat_in[370] ^ dat_in[374] ^ dat_in[375] ^
            dat_in[376] ^ dat_in[377] ^ dat_in[380] ^ dat_in[382] ^ dat_in[384] ^
            dat_in[385] ^ dat_in[390] ^ dat_in[391] ^ dat_in[392] ^ dat_in[393] ^
            dat_in[396] ^ dat_in[398] ^ dat_in[400] ^ dat_in[401] ^ dat_in[406] ^
            dat_in[407] ^ dat_in[408] ^ dat_in[409] ^ dat_in[412] ^ dat_in[414] ^
            dat_in[416] ^ dat_in[417] ^ dat_in[422] ^ dat_in[423] ^ dat_in[424] ^
            dat_in[425] ^ dat_in[428] ^ dat_in[430] ^ dat_in[432] ^ dat_in[433] ^
            dat_in[437] ^ dat_in[438] ^ dat_in[439] ^ dat_in[440] ^ dat_in[443] ^
            dat_in[445] ^ dat_in[447] ^ dat_in[448] ^ dat_in[453] ^ dat_in[454] ^
            dat_in[455] ^ dat_in[456] ^ dat_in[459] ^ dat_in[461] ^ dat_in[463] ^
            dat_in[464] ^ dat_in[468] ^ dat_in[469] ^ dat_in[470] ^ dat_in[471] ^
            dat_in[474] ^ dat_in[476] ^ dat_in[477] ^ dat_in[479] ^ dat_in[480] ^
            dat_in[481] ^ dat_in[482] ^ dat_in[485] ^ dat_in[487] ^ dat_in[489] ^
            dat_in[490] ^ dat_in[495] ^ dat_in[496] ^ dat_in[497] ^ dat_in[498] ^ dat_in[501];

  assign chkout_int[4] = dat_in[2] ^ dat_in[3] ^ dat_in[4] ^ dat_in[5] ^
            dat_in[6] ^ dat_in[7] ^ dat_in[14] ^ dat_in[15] ^ dat_in[18] ^
            dat_in[19] ^ dat_in[20] ^ dat_in[21] ^ dat_in[22] ^ dat_in[23] ^
            dat_in[30] ^ dat_in[31] ^ dat_in[34] ^ dat_in[35] ^ dat_in[36] ^
            dat_in[37] ^ dat_in[38] ^ dat_in[39] ^ dat_in[46] ^ dat_in[47] ^
            dat_in[50] ^ dat_in[51] ^ dat_in[52] ^ dat_in[53] ^ dat_in[54] ^
            dat_in[55] ^ dat_in[62] ^ dat_in[63] ^ dat_in[66] ^ dat_in[67] ^
            dat_in[68] ^ dat_in[69] ^ dat_in[70] ^ dat_in[71] ^ dat_in[78] ^
            dat_in[79] ^ dat_in[82] ^ dat_in[83] ^ dat_in[84] ^ dat_in[85] ^
            dat_in[86] ^ dat_in[87] ^ dat_in[94] ^ dat_in[95] ^ dat_in[98] ^
            dat_in[99] ^ dat_in[100] ^ dat_in[101] ^ dat_in[102] ^ dat_in[103] ^
            dat_in[110] ^ dat_in[111] ^ dat_in[114] ^ dat_in[115] ^ dat_in[116] ^
            dat_in[117] ^ dat_in[118] ^ dat_in[119] ^ dat_in[126] ^ dat_in[127] ^
            dat_in[130] ^ dat_in[131] ^ dat_in[132] ^ dat_in[133] ^ dat_in[134] ^
            dat_in[135] ^ dat_in[142] ^ dat_in[143] ^ dat_in[146] ^ dat_in[147] ^
            dat_in[148] ^ dat_in[149] ^ dat_in[150] ^ dat_in[151] ^ dat_in[158] ^
            dat_in[159] ^ dat_in[162] ^ dat_in[163] ^ dat_in[164] ^ dat_in[165] ^
            dat_in[166] ^ dat_in[167] ^ dat_in[174] ^ dat_in[175] ^ dat_in[178] ^
            dat_in[179] ^ dat_in[180] ^ dat_in[181] ^ dat_in[182] ^ dat_in[183] ^
            dat_in[190] ^ dat_in[191] ^ dat_in[194] ^ dat_in[195] ^ dat_in[196] ^
            dat_in[197] ^ dat_in[198] ^ dat_in[199] ^ dat_in[206] ^ dat_in[207] ^
            dat_in[210] ^ dat_in[211] ^ dat_in[212] ^ dat_in[213] ^ dat_in[214] ^
            dat_in[215] ^ dat_in[222] ^ dat_in[223] ^ dat_in[226] ^ dat_in[227] ^
            dat_in[228] ^ dat_in[229] ^ dat_in[230] ^ dat_in[231] ^ dat_in[238] ^
            dat_in[239] ^ dat_in[242] ^ dat_in[243] ^ dat_in[244] ^ dat_in[245] ^
            dat_in[246] ^ dat_in[247] ^ dat_in[254] ^ dat_in[255] ^ dat_in[256] ^
            dat_in[257] ^ dat_in[263] ^ dat_in[264] ^ dat_in[265] ^ dat_in[266] ^
            dat_in[267] ^ dat_in[268] ^ dat_in[271] ^ dat_in[272] ^ dat_in[279] ^
            dat_in[280] ^ dat_in[281] ^ dat_in[282] ^ dat_in[283] ^ dat_in[284] ^
            dat_in[287] ^ dat_in[288] ^ dat_in[295] ^ dat_in[296] ^ dat_in[297] ^
            dat_in[298] ^ dat_in[299] ^ dat_in[300] ^ dat_in[303] ^ dat_in[304] ^
            dat_in[311] ^ dat_in[312] ^ dat_in[313] ^ dat_in[314] ^ dat_in[315] ^
            dat_in[316] ^ dat_in[319] ^ dat_in[320] ^ dat_in[327] ^ dat_in[328] ^
            dat_in[329] ^ dat_in[330] ^ dat_in[331] ^ dat_in[332] ^ dat_in[335] ^
            dat_in[336] ^ dat_in[343] ^ dat_in[344] ^ dat_in[345] ^ dat_in[346] ^
            dat_in[347] ^ dat_in[348] ^ dat_in[351] ^ dat_in[352] ^ dat_in[359] ^
            dat_in[360] ^ dat_in[361] ^ dat_in[362] ^ dat_in[363] ^ dat_in[364] ^
            dat_in[367] ^ dat_in[368] ^ dat_in[374] ^ dat_in[375] ^ dat_in[376] ^
            dat_in[377] ^ dat_in[378] ^ dat_in[379] ^ dat_in[382] ^ dat_in[383] ^
            dat_in[390] ^ dat_in[391] ^ dat_in[392] ^ dat_in[393] ^ dat_in[394] ^
            dat_in[395] ^ dat_in[398] ^ dat_in[399] ^ dat_in[406] ^ dat_in[407] ^
            dat_in[408] ^ dat_in[409] ^ dat_in[410] ^ dat_in[411] ^ dat_in[414] ^
            dat_in[415] ^ dat_in[422] ^ dat_in[423] ^ dat_in[424] ^ dat_in[425] ^
            dat_in[426] ^ dat_in[427] ^ dat_in[430] ^ dat_in[431] ^ dat_in[437] ^
            dat_in[438] ^ dat_in[439] ^ dat_in[440] ^ dat_in[441] ^ dat_in[442] ^
            dat_in[445] ^ dat_in[446] ^ dat_in[453] ^ dat_in[454] ^ dat_in[455] ^
            dat_in[456] ^ dat_in[457] ^ dat_in[458] ^ dat_in[461] ^ dat_in[462] ^
            dat_in[468] ^ dat_in[469] ^ dat_in[470] ^ dat_in[471] ^ dat_in[472] ^
            dat_in[473] ^ dat_in[476] ^ dat_in[479] ^ dat_in[480] ^ dat_in[481] ^
            dat_in[482] ^ dat_in[483] ^ dat_in[484] ^ dat_in[487] ^ dat_in[488] ^
            dat_in[495] ^ dat_in[496] ^ dat_in[497] ^ dat_in[498] ^ dat_in[499] ^ dat_in[500];

  assign chkout_int[5] = dat_in[8] ^ dat_in[9] ^ dat_in[10] ^ dat_in[11] ^
            dat_in[12] ^ dat_in[13] ^ dat_in[14] ^ dat_in[15] ^ dat_in[24] ^
            dat_in[25] ^ dat_in[26] ^ dat_in[27] ^ dat_in[28] ^ dat_in[29] ^
            dat_in[30] ^ dat_in[31] ^ dat_in[40] ^ dat_in[41] ^ dat_in[42] ^
            dat_in[43] ^ dat_in[44] ^ dat_in[45] ^ dat_in[46] ^ dat_in[47] ^
            dat_in[56] ^ dat_in[57] ^ dat_in[58] ^ dat_in[59] ^ dat_in[60] ^
            dat_in[61] ^ dat_in[62] ^ dat_in[63] ^ dat_in[72] ^ dat_in[73] ^
            dat_in[74] ^ dat_in[75] ^ dat_in[76] ^ dat_in[77] ^ dat_in[78] ^
            dat_in[79] ^ dat_in[88] ^ dat_in[89] ^ dat_in[90] ^ dat_in[91] ^
            dat_in[92] ^ dat_in[93] ^ dat_in[94] ^ dat_in[95] ^ dat_in[96] ^
            dat_in[97] ^ dat_in[98] ^ dat_in[99] ^ dat_in[100] ^ dat_in[101] ^
            dat_in[102] ^ dat_in[103] ^ dat_in[112] ^ dat_in[113] ^ dat_in[114] ^
            dat_in[115] ^ dat_in[116] ^ dat_in[117] ^ dat_in[118] ^ dat_in[119] ^
            dat_in[136] ^ dat_in[137] ^ dat_in[138] ^ dat_in[139] ^ dat_in[140] ^
            dat_in[141] ^ dat_in[142] ^ dat_in[143] ^ dat_in[152] ^ dat_in[153] ^
            dat_in[154] ^ dat_in[155] ^ dat_in[156] ^ dat_in[157] ^ dat_in[158] ^
            dat_in[159] ^ dat_in[160] ^ dat_in[161] ^ dat_in[162] ^ dat_in[163] ^
            dat_in[164] ^ dat_in[165] ^ dat_in[166] ^ dat_in[167] ^ dat_in[176] ^
            dat_in[177] ^ dat_in[178] ^ dat_in[179] ^ dat_in[180] ^ dat_in[181] ^
            dat_in[182] ^ dat_in[183] ^ dat_in[192] ^ dat_in[193] ^ dat_in[194] ^
            dat_in[195] ^ dat_in[196] ^ dat_in[197] ^ dat_in[198] ^ dat_in[199] ^
            dat_in[208] ^ dat_in[209] ^ dat_in[210] ^ dat_in[211] ^ dat_in[212] ^
            dat_in[213] ^ dat_in[214] ^ dat_in[215] ^ dat_in[232] ^ dat_in[233] ^
            dat_in[234] ^ dat_in[235] ^ dat_in[236] ^ dat_in[237] ^ dat_in[238] ^
            dat_in[239] ^ dat_in[248] ^ dat_in[249] ^ dat_in[250] ^ dat_in[251] ^
            dat_in[252] ^ dat_in[253] ^ dat_in[254] ^ dat_in[255] ^ dat_in[263] ^
            dat_in[264] ^ dat_in[265] ^ dat_in[266] ^ dat_in[267] ^ dat_in[268] ^
            dat_in[269] ^ dat_in[270] ^ dat_in[279] ^ dat_in[280] ^ dat_in[281] ^
            dat_in[282] ^ dat_in[283] ^ dat_in[284] ^ dat_in[285] ^ dat_in[286] ^
            dat_in[287] ^ dat_in[288] ^ dat_in[289] ^ dat_in[290] ^ dat_in[291] ^
            dat_in[292] ^ dat_in[293] ^ dat_in[294] ^ dat_in[303] ^ dat_in[304] ^
            dat_in[305] ^ dat_in[306] ^ dat_in[307] ^ dat_in[308] ^ dat_in[309] ^
            dat_in[310] ^ dat_in[319] ^ dat_in[320] ^ dat_in[321] ^ dat_in[322] ^
            dat_in[323] ^ dat_in[324] ^ dat_in[325] ^ dat_in[326] ^ dat_in[335] ^
            dat_in[336] ^ dat_in[337] ^ dat_in[338] ^ dat_in[339] ^ dat_in[340] ^
            dat_in[341] ^ dat_in[342] ^ dat_in[359] ^ dat_in[360] ^ dat_in[361] ^
            dat_in[362] ^ dat_in[363] ^ dat_in[364] ^ dat_in[365] ^ dat_in[366] ^
            dat_in[374] ^ dat_in[375] ^ dat_in[376] ^ dat_in[377] ^ dat_in[378] ^
            dat_in[379] ^ dat_in[380] ^ dat_in[381] ^ dat_in[382] ^ dat_in[383] ^
            dat_in[384] ^ dat_in[385] ^ dat_in[386] ^ dat_in[387] ^ dat_in[388] ^
            dat_in[389] ^ dat_in[398] ^ dat_in[399] ^ dat_in[400] ^ dat_in[401] ^
            dat_in[402] ^ dat_in[403] ^ dat_in[404] ^ dat_in[405] ^ dat_in[422] ^
            dat_in[423] ^ dat_in[424] ^ dat_in[425] ^ dat_in[426] ^ dat_in[427] ^
            dat_in[428] ^ dat_in[429] ^ dat_in[437] ^ dat_in[438] ^ dat_in[439] ^
            dat_in[440] ^ dat_in[441] ^ dat_in[442] ^ dat_in[443] ^ dat_in[444] ^
            dat_in[453] ^ dat_in[454] ^ dat_in[455] ^ dat_in[456] ^ dat_in[457] ^
            dat_in[458] ^ dat_in[459] ^ dat_in[460] ^ dat_in[468] ^ dat_in[469] ^
            dat_in[470] ^ dat_in[471] ^ dat_in[472] ^ dat_in[473] ^ dat_in[474] ^
            dat_in[475] ^ dat_in[479] ^ dat_in[480] ^ dat_in[481] ^ dat_in[482] ^
            dat_in[483] ^ dat_in[484] ^ dat_in[485] ^ dat_in[486] ^ dat_in[495] ^
            dat_in[496] ^ dat_in[497] ^ dat_in[498] ^ dat_in[499] ^ dat_in[500] ^ dat_in[501];

  assign chkout_int[6] = dat_in[0] ^ dat_in[1] ^ dat_in[2] ^ dat_in[3] ^
            dat_in[4] ^ dat_in[5] ^ dat_in[6] ^ dat_in[7] ^ dat_in[24] ^
            dat_in[25] ^ dat_in[26] ^ dat_in[27] ^ dat_in[28] ^ dat_in[29] ^
            dat_in[30] ^ dat_in[31] ^ dat_in[32] ^ dat_in[33] ^ dat_in[34] ^
            dat_in[35] ^ dat_in[36] ^ dat_in[37] ^ dat_in[38] ^ dat_in[39] ^
            dat_in[56] ^ dat_in[57] ^ dat_in[58] ^ dat_in[59] ^ dat_in[60] ^
            dat_in[61] ^ dat_in[62] ^ dat_in[63] ^ dat_in[72] ^ dat_in[73] ^
            dat_in[74] ^ dat_in[75] ^ dat_in[76] ^ dat_in[77] ^ dat_in[78] ^
            dat_in[79] ^ dat_in[80] ^ dat_in[81] ^ dat_in[82] ^ dat_in[83] ^
            dat_in[84] ^ dat_in[85] ^ dat_in[86] ^ dat_in[87] ^ dat_in[104] ^
            dat_in[105] ^ dat_in[106] ^ dat_in[107] ^ dat_in[108] ^ dat_in[109] ^
            dat_in[110] ^ dat_in[111] ^ dat_in[112] ^ dat_in[113] ^ dat_in[114] ^
            dat_in[115] ^ dat_in[116] ^ dat_in[117] ^ dat_in[118] ^ dat_in[119] ^
            dat_in[136] ^ dat_in[137] ^ dat_in[138] ^ dat_in[139] ^ dat_in[140] ^
            dat_in[141] ^ dat_in[142] ^ dat_in[143] ^ dat_in[144] ^ dat_in[145] ^
            dat_in[146] ^ dat_in[147] ^ dat_in[148] ^ dat_in[149] ^ dat_in[150] ^
            dat_in[151] ^ dat_in[168] ^ dat_in[169] ^ dat_in[170] ^ dat_in[171] ^
            dat_in[172] ^ dat_in[173] ^ dat_in[174] ^ dat_in[175] ^ dat_in[176] ^
            dat_in[177] ^ dat_in[178] ^ dat_in[179] ^ dat_in[180] ^ dat_in[181] ^
            dat_in[182] ^ dat_in[183] ^ dat_in[192] ^ dat_in[193] ^ dat_in[194] ^
            dat_in[195] ^ dat_in[196] ^ dat_in[197] ^ dat_in[198] ^ dat_in[199] ^
            dat_in[216] ^ dat_in[217] ^ dat_in[218] ^ dat_in[219] ^ dat_in[220] ^
            dat_in[221] ^ dat_in[222] ^ dat_in[223] ^ dat_in[224] ^ dat_in[225] ^
            dat_in[226] ^ dat_in[227] ^ dat_in[228] ^ dat_in[229] ^ dat_in[230] ^
            dat_in[231] ^ dat_in[248] ^ dat_in[249] ^ dat_in[250] ^ dat_in[251] ^
            dat_in[252] ^ dat_in[253] ^ dat_in[254] ^ dat_in[255] ^ dat_in[263] ^
            dat_in[264] ^ dat_in[265] ^ dat_in[266] ^ dat_in[267] ^ dat_in[268] ^
            dat_in[269] ^ dat_in[270] ^ dat_in[271] ^ dat_in[272] ^ dat_in[273] ^
            dat_in[274] ^ dat_in[275] ^ dat_in[276] ^ dat_in[277] ^ dat_in[278] ^
            dat_in[295] ^ dat_in[296] ^ dat_in[297] ^ dat_in[298] ^ dat_in[299] ^
            dat_in[300] ^ dat_in[301] ^ dat_in[302] ^ dat_in[303] ^ dat_in[304] ^
            dat_in[305] ^ dat_in[306] ^ dat_in[307] ^ dat_in[308] ^ dat_in[309] ^
            dat_in[310] ^ dat_in[319] ^ dat_in[320] ^ dat_in[321] ^ dat_in[322] ^
            dat_in[323] ^ dat_in[324] ^ dat_in[325] ^ dat_in[326] ^ dat_in[343] ^
            dat_in[344] ^ dat_in[345] ^ dat_in[346] ^ dat_in[347] ^ dat_in[348] ^
            dat_in[349] ^ dat_in[350] ^ dat_in[351] ^ dat_in[352] ^ dat_in[353] ^
            dat_in[354] ^ dat_in[355] ^ dat_in[356] ^ dat_in[357] ^ dat_in[358] ^
            dat_in[374] ^ dat_in[375] ^ dat_in[376] ^ dat_in[377] ^ dat_in[378] ^
            dat_in[379] ^ dat_in[380] ^ dat_in[381] ^ dat_in[382] ^ dat_in[383] ^
            dat_in[384] ^ dat_in[385] ^ dat_in[386] ^ dat_in[387] ^ dat_in[388] ^
            dat_in[389] ^ dat_in[406] ^ dat_in[407] ^ dat_in[408] ^ dat_in[409] ^
            dat_in[410] ^ dat_in[411] ^ dat_in[412] ^ dat_in[413] ^ dat_in[414] ^
            dat_in[415] ^ dat_in[416] ^ dat_in[417] ^ dat_in[418] ^ dat_in[419] ^
            dat_in[420] ^ dat_in[421] ^ dat_in[437] ^ dat_in[438] ^ dat_in[439] ^
            dat_in[440] ^ dat_in[441] ^ dat_in[442] ^ dat_in[443] ^ dat_in[444] ^
            dat_in[453] ^ dat_in[454] ^ dat_in[455] ^ dat_in[456] ^ dat_in[457] ^
            dat_in[458] ^ dat_in[459] ^ dat_in[460] ^ dat_in[461] ^ dat_in[462] ^
            dat_in[463] ^ dat_in[464] ^ dat_in[465] ^ dat_in[466] ^ dat_in[467] ^
            dat_in[479] ^ dat_in[480] ^ dat_in[481] ^ dat_in[482] ^ dat_in[483] ^
            dat_in[484] ^ dat_in[485] ^ dat_in[486] ^ dat_in[487] ^ dat_in[488] ^
            dat_in[489] ^ dat_in[490] ^ dat_in[491] ^ dat_in[492] ^ dat_in[493] ^ dat_in[494];

  assign chkout_int[7] = dat_in[0] ^ dat_in[1] ^ dat_in[2] ^ dat_in[3] ^
            dat_in[4] ^ dat_in[5] ^ dat_in[6] ^ dat_in[7] ^ dat_in[24] ^
            dat_in[25] ^ dat_in[26] ^ dat_in[27] ^ dat_in[28] ^ dat_in[29] ^
            dat_in[30] ^ dat_in[31] ^ dat_in[40] ^ dat_in[41] ^ dat_in[42] ^
            dat_in[43] ^ dat_in[44] ^ dat_in[45] ^ dat_in[46] ^ dat_in[47] ^
            dat_in[48] ^ dat_in[49] ^ dat_in[50] ^ dat_in[51] ^ dat_in[52] ^
            dat_in[53] ^ dat_in[54] ^ dat_in[55] ^ dat_in[64] ^ dat_in[65] ^
            dat_in[66] ^ dat_in[67] ^ dat_in[68] ^ dat_in[69] ^ dat_in[70] ^
            dat_in[71] ^ dat_in[88] ^ dat_in[89] ^ dat_in[90] ^ dat_in[91] ^
            dat_in[92] ^ dat_in[93] ^ dat_in[94] ^ dat_in[95] ^ dat_in[104] ^
            dat_in[105] ^ dat_in[106] ^ dat_in[107] ^ dat_in[108] ^ dat_in[109] ^
            dat_in[110] ^ dat_in[111] ^ dat_in[112] ^ dat_in[113] ^ dat_in[114] ^
            dat_in[115] ^ dat_in[116] ^ dat_in[117] ^ dat_in[118] ^ dat_in[119] ^
            dat_in[136] ^ dat_in[137] ^ dat_in[138] ^ dat_in[139] ^ dat_in[140] ^
            dat_in[141] ^ dat_in[142] ^ dat_in[143] ^ dat_in[144] ^ dat_in[145] ^
            dat_in[146] ^ dat_in[147] ^ dat_in[148] ^ dat_in[149] ^ dat_in[150] ^
            dat_in[151] ^ dat_in[160] ^ dat_in[161] ^ dat_in[162] ^ dat_in[163] ^
            dat_in[164] ^ dat_in[165] ^ dat_in[166] ^ dat_in[167] ^ dat_in[184] ^
            dat_in[185] ^ dat_in[186] ^ dat_in[187] ^ dat_in[188] ^ dat_in[189] ^
            dat_in[190] ^ dat_in[191] ^ dat_in[200] ^ dat_in[201] ^ dat_in[202] ^
            dat_in[203] ^ dat_in[204] ^ dat_in[205] ^ dat_in[206] ^ dat_in[207] ^
            dat_in[208] ^ dat_in[209] ^ dat_in[210] ^ dat_in[211] ^ dat_in[212] ^
            dat_in[213] ^ dat_in[214] ^ dat_in[215] ^ dat_in[224] ^ dat_in[225] ^
            dat_in[226] ^ dat_in[227] ^ dat_in[228] ^ dat_in[229] ^ dat_in[230] ^
            dat_in[231] ^ dat_in[248] ^ dat_in[249] ^ dat_in[250] ^ dat_in[251] ^
            dat_in[252] ^ dat_in[253] ^ dat_in[254] ^ dat_in[255] ^ dat_in[263] ^
            dat_in[264] ^ dat_in[265] ^ dat_in[266] ^ dat_in[267] ^ dat_in[268] ^
            dat_in[269] ^ dat_in[270] ^ dat_in[271] ^ dat_in[272] ^ dat_in[273] ^
            dat_in[274] ^ dat_in[275] ^ dat_in[276] ^ dat_in[277] ^ dat_in[278] ^
            dat_in[287] ^ dat_in[288] ^ dat_in[289] ^ dat_in[290] ^ dat_in[291] ^
            dat_in[292] ^ dat_in[293] ^ dat_in[294] ^ dat_in[311] ^ dat_in[312] ^
            dat_in[313] ^ dat_in[314] ^ dat_in[315] ^ dat_in[316] ^ dat_in[317] ^
            dat_in[318] ^ dat_in[327] ^ dat_in[328] ^ dat_in[329] ^ dat_in[330] ^
            dat_in[331] ^ dat_in[332] ^ dat_in[333] ^ dat_in[334] ^ dat_in[335] ^
            dat_in[336] ^ dat_in[337] ^ dat_in[338] ^ dat_in[339] ^ dat_in[340] ^
            dat_in[341] ^ dat_in[342] ^ dat_in[351] ^ dat_in[352] ^ dat_in[353] ^
            dat_in[354] ^ dat_in[355] ^ dat_in[356] ^ dat_in[357] ^ dat_in[358] ^
            dat_in[374] ^ dat_in[375] ^ dat_in[376] ^ dat_in[377] ^ dat_in[378] ^
            dat_in[379] ^ dat_in[380] ^ dat_in[381] ^ dat_in[382] ^ dat_in[383] ^
            dat_in[384] ^ dat_in[385] ^ dat_in[386] ^ dat_in[387] ^ dat_in[388] ^
            dat_in[389] ^ dat_in[406] ^ dat_in[407] ^ dat_in[408] ^ dat_in[409] ^
            dat_in[410] ^ dat_in[411] ^ dat_in[412] ^ dat_in[413] ^ dat_in[422] ^
            dat_in[423] ^ dat_in[424] ^ dat_in[425] ^ dat_in[426] ^ dat_in[427] ^
            dat_in[428] ^ dat_in[429] ^ dat_in[430] ^ dat_in[431] ^ dat_in[432] ^
            dat_in[433] ^ dat_in[434] ^ dat_in[435] ^ dat_in[436] ^ dat_in[445] ^
            dat_in[446] ^ dat_in[447] ^ dat_in[448] ^ dat_in[449] ^ dat_in[450] ^
            dat_in[451] ^ dat_in[452] ^ dat_in[468] ^ dat_in[469] ^ dat_in[470] ^
            dat_in[471] ^ dat_in[472] ^ dat_in[473] ^ dat_in[474] ^ dat_in[475] ^
            dat_in[479] ^ dat_in[480] ^ dat_in[481] ^ dat_in[482] ^ dat_in[483] ^
            dat_in[484] ^ dat_in[485] ^ dat_in[486] ^ dat_in[487] ^ dat_in[488] ^
            dat_in[489] ^ dat_in[490] ^ dat_in[491] ^ dat_in[492] ^ dat_in[493] ^ dat_in[494];

  assign chkout_int[8] = dat_in[0] ^ dat_in[1] ^ dat_in[2] ^ dat_in[3] ^
            dat_in[4] ^ dat_in[5] ^ dat_in[6] ^ dat_in[7] ^ dat_in[24] ^
            dat_in[25] ^ dat_in[26] ^ dat_in[27] ^ dat_in[28] ^ dat_in[29] ^
            dat_in[30] ^ dat_in[31] ^ dat_in[40] ^ dat_in[41] ^ dat_in[42] ^
            dat_in[43] ^ dat_in[44] ^ dat_in[45] ^ dat_in[46] ^ dat_in[47] ^
            dat_in[48] ^ dat_in[49] ^ dat_in[50] ^ dat_in[51] ^ dat_in[52] ^
            dat_in[53] ^ dat_in[54] ^ dat_in[55] ^ dat_in[72] ^ dat_in[73] ^
            dat_in[74] ^ dat_in[75] ^ dat_in[76] ^ dat_in[77] ^ dat_in[78] ^
            dat_in[79] ^ dat_in[80] ^ dat_in[81] ^ dat_in[82] ^ dat_in[83] ^
            dat_in[84] ^ dat_in[85] ^ dat_in[86] ^ dat_in[87] ^ dat_in[96] ^
            dat_in[97] ^ dat_in[98] ^ dat_in[99] ^ dat_in[100] ^ dat_in[101] ^
            dat_in[102] ^ dat_in[103] ^ dat_in[120] ^ dat_in[121] ^ dat_in[122] ^
            dat_in[123] ^ dat_in[124] ^ dat_in[125] ^ dat_in[126] ^ dat_in[127] ^
            dat_in[128] ^ dat_in[129] ^ dat_in[130] ^ dat_in[131] ^ dat_in[132] ^
            dat_in[133] ^ dat_in[134] ^ dat_in[135] ^ dat_in[152] ^ dat_in[153] ^
            dat_in[154] ^ dat_in[155] ^ dat_in[156] ^ dat_in[157] ^ dat_in[158] ^
            dat_in[159] ^ dat_in[168] ^ dat_in[169] ^ dat_in[170] ^ dat_in[171] ^
            dat_in[172] ^ dat_in[173] ^ dat_in[174] ^ dat_in[175] ^ dat_in[176] ^
            dat_in[177] ^ dat_in[178] ^ dat_in[179] ^ dat_in[180] ^ dat_in[181] ^
            dat_in[182] ^ dat_in[183] ^ dat_in[200] ^ dat_in[201] ^ dat_in[202] ^
            dat_in[203] ^ dat_in[204] ^ dat_in[205] ^ dat_in[206] ^ dat_in[207] ^
            dat_in[208] ^ dat_in[209] ^ dat_in[210] ^ dat_in[211] ^ dat_in[212] ^
            dat_in[213] ^ dat_in[214] ^ dat_in[215] ^ dat_in[224] ^ dat_in[225] ^
            dat_in[226] ^ dat_in[227] ^ dat_in[228] ^ dat_in[229] ^ dat_in[230] ^
            dat_in[231] ^ dat_in[248] ^ dat_in[249] ^ dat_in[250] ^ dat_in[251] ^
            dat_in[252] ^ dat_in[253] ^ dat_in[254] ^ dat_in[255] ^ dat_in[263] ^
            dat_in[264] ^ dat_in[265] ^ dat_in[266] ^ dat_in[267] ^ dat_in[268] ^
            dat_in[269] ^ dat_in[270] ^ dat_in[271] ^ dat_in[272] ^ dat_in[273] ^
            dat_in[274] ^ dat_in[275] ^ dat_in[276] ^ dat_in[277] ^ dat_in[278] ^
            dat_in[287] ^ dat_in[288] ^ dat_in[289] ^ dat_in[290] ^ dat_in[291] ^
            dat_in[292] ^ dat_in[293] ^ dat_in[294] ^ dat_in[311] ^ dat_in[312] ^
            dat_in[313] ^ dat_in[314] ^ dat_in[315] ^ dat_in[316] ^ dat_in[317] ^
            dat_in[318] ^ dat_in[319] ^ dat_in[320] ^ dat_in[321] ^ dat_in[322] ^
            dat_in[323] ^ dat_in[324] ^ dat_in[325] ^ dat_in[326] ^ dat_in[343] ^
            dat_in[344] ^ dat_in[345] ^ dat_in[346] ^ dat_in[347] ^ dat_in[348] ^
            dat_in[349] ^ dat_in[350] ^ dat_in[359] ^ dat_in[360] ^ dat_in[361] ^
            dat_in[362] ^ dat_in[363] ^ dat_in[364] ^ dat_in[365] ^ dat_in[366] ^
            dat_in[367] ^ dat_in[368] ^ dat_in[369] ^ dat_in[370] ^ dat_in[371] ^
            dat_in[372] ^ dat_in[373] ^ dat_in[390] ^ dat_in[391] ^ dat_in[392] ^
            dat_in[393] ^ dat_in[394] ^ dat_in[395] ^ dat_in[396] ^ dat_in[397] ^
            dat_in[398] ^ dat_in[399] ^ dat_in[400] ^ dat_in[401] ^ dat_in[402] ^
            dat_in[403] ^ dat_in[404] ^ dat_in[405] ^ dat_in[414] ^ dat_in[415] ^
            dat_in[416] ^ dat_in[417] ^ dat_in[418] ^ dat_in[419] ^ dat_in[420] ^
            dat_in[421] ^ dat_in[437] ^ dat_in[438] ^ dat_in[439] ^ dat_in[440] ^
            dat_in[441] ^ dat_in[442] ^ dat_in[443] ^ dat_in[444] ^ dat_in[445] ^
            dat_in[446] ^ dat_in[447] ^ dat_in[448] ^ dat_in[449] ^ dat_in[450] ^
            dat_in[451] ^ dat_in[452] ^ dat_in[468] ^ dat_in[469] ^ dat_in[470] ^
            dat_in[471] ^ dat_in[472] ^ dat_in[473] ^ dat_in[474] ^ dat_in[475] ^
            dat_in[479] ^ dat_in[480] ^ dat_in[481] ^ dat_in[482] ^ dat_in[483] ^
            dat_in[484] ^ dat_in[485] ^ dat_in[486] ^ dat_in[487] ^ dat_in[488] ^
            dat_in[489] ^ dat_in[490] ^ dat_in[491] ^ dat_in[492] ^ dat_in[493] ^ dat_in[494];

  assign chkout_int[9] = dat_in[0] ^ dat_in[1] ^ dat_in[2] ^ dat_in[3] ^
            dat_in[4] ^ dat_in[5] ^ dat_in[6] ^ dat_in[7] ^ dat_in[24] ^
            dat_in[25] ^ dat_in[26] ^ dat_in[27] ^ dat_in[28] ^ dat_in[29] ^
            dat_in[30] ^ dat_in[31] ^ dat_in[40] ^ dat_in[41] ^ dat_in[42] ^
            dat_in[43] ^ dat_in[44] ^ dat_in[45] ^ dat_in[46] ^ dat_in[47] ^
            dat_in[48] ^ dat_in[49] ^ dat_in[50] ^ dat_in[51] ^ dat_in[52] ^
            dat_in[53] ^ dat_in[54] ^ dat_in[55] ^ dat_in[72] ^ dat_in[73] ^
            dat_in[74] ^ dat_in[75] ^ dat_in[76] ^ dat_in[77] ^ dat_in[78] ^
            dat_in[79] ^ dat_in[80] ^ dat_in[81] ^ dat_in[82] ^ dat_in[83] ^
            dat_in[84] ^ dat_in[85] ^ dat_in[86] ^ dat_in[87] ^ dat_in[96] ^
            dat_in[97] ^ dat_in[98] ^ dat_in[99] ^ dat_in[100] ^ dat_in[101] ^
            dat_in[102] ^ dat_in[103] ^ dat_in[120] ^ dat_in[121] ^ dat_in[122] ^
            dat_in[123] ^ dat_in[124] ^ dat_in[125] ^ dat_in[126] ^ dat_in[127] ^
            dat_in[136] ^ dat_in[137] ^ dat_in[138] ^ dat_in[139] ^ dat_in[140] ^
            dat_in[141] ^ dat_in[142] ^ dat_in[143] ^ dat_in[144] ^ dat_in[145] ^
            dat_in[146] ^ dat_in[147] ^ dat_in[148] ^ dat_in[149] ^ dat_in[150] ^
            dat_in[151] ^ dat_in[160] ^ dat_in[161] ^ dat_in[162] ^ dat_in[163] ^
            dat_in[164] ^ dat_in[165] ^ dat_in[166] ^ dat_in[167] ^ dat_in[184] ^
            dat_in[185] ^ dat_in[186] ^ dat_in[187] ^ dat_in[188] ^ dat_in[189] ^
            dat_in[190] ^ dat_in[191] ^ dat_in[192] ^ dat_in[193] ^ dat_in[194] ^
            dat_in[195] ^ dat_in[196] ^ dat_in[197] ^ dat_in[198] ^ dat_in[199] ^
            dat_in[216] ^ dat_in[217] ^ dat_in[218] ^ dat_in[219] ^ dat_in[220] ^
            dat_in[221] ^ dat_in[222] ^ dat_in[223] ^ dat_in[232] ^ dat_in[233] ^
            dat_in[234] ^ dat_in[235] ^ dat_in[236] ^ dat_in[237] ^ dat_in[238] ^
            dat_in[239] ^ dat_in[240] ^ dat_in[241] ^ dat_in[242] ^ dat_in[243] ^
            dat_in[244] ^ dat_in[245] ^ dat_in[246] ^ dat_in[247] ^ dat_in[256] ^
            dat_in[257] ^ dat_in[258] ^ dat_in[259] ^ dat_in[260] ^ dat_in[261] ^
            dat_in[262] ^ dat_in[279] ^ dat_in[280] ^ dat_in[281] ^ dat_in[282] ^
            dat_in[283] ^ dat_in[284] ^ dat_in[285] ^ dat_in[286] ^ dat_in[295] ^
            dat_in[296] ^ dat_in[297] ^ dat_in[298] ^ dat_in[299] ^ dat_in[300] ^
            dat_in[301] ^ dat_in[302] ^ dat_in[303] ^ dat_in[304] ^ dat_in[305] ^
            dat_in[306] ^ dat_in[307] ^ dat_in[308] ^ dat_in[309] ^ dat_in[310] ^
            dat_in[327] ^ dat_in[328] ^ dat_in[329] ^ dat_in[330] ^ dat_in[331] ^
            dat_in[332] ^ dat_in[333] ^ dat_in[334] ^ dat_in[335] ^ dat_in[336] ^
            dat_in[337] ^ dat_in[338] ^ dat_in[339] ^ dat_in[340] ^ dat_in[341] ^
            dat_in[342] ^ dat_in[351] ^ dat_in[352] ^ dat_in[353] ^ dat_in[354] ^
            dat_in[355] ^ dat_in[356] ^ dat_in[357] ^ dat_in[358] ^ dat_in[374] ^
            dat_in[375] ^ dat_in[376] ^ dat_in[377] ^ dat_in[378] ^ dat_in[379] ^
            dat_in[380] ^ dat_in[381] ^ dat_in[390] ^ dat_in[391] ^ dat_in[392] ^
            dat_in[393] ^ dat_in[394] ^ dat_in[395] ^ dat_in[396] ^ dat_in[397] ^
            dat_in[398] ^ dat_in[399] ^ dat_in[400] ^ dat_in[401] ^ dat_in[402] ^
            dat_in[403] ^ dat_in[404] ^ dat_in[405] ^ dat_in[414] ^ dat_in[415] ^
            dat_in[416] ^ dat_in[417] ^ dat_in[418] ^ dat_in[419] ^ dat_in[420] ^
            dat_in[421] ^ dat_in[437] ^ dat_in[438] ^ dat_in[439] ^ dat_in[440] ^
            dat_in[441] ^ dat_in[442] ^ dat_in[443] ^ dat_in[444] ^ dat_in[445] ^
            dat_in[446] ^ dat_in[447] ^ dat_in[448] ^ dat_in[449] ^ dat_in[450] ^
            dat_in[451] ^ dat_in[452] ^ dat_in[468] ^ dat_in[469] ^ dat_in[470] ^
            dat_in[471] ^ dat_in[472] ^ dat_in[473] ^ dat_in[474] ^ dat_in[475] ^
            dat_in[479] ^ dat_in[480] ^ dat_in[481] ^ dat_in[482] ^ dat_in[483] ^
            dat_in[484] ^ dat_in[485] ^ dat_in[486] ^ dat_in[487] ^ dat_in[488] ^
            dat_in[489] ^ dat_in[490] ^ dat_in[491] ^ dat_in[492] ^ dat_in[493] ^ dat_in[494];

  assign syndec[219] = (syndout_int == 10'b1001001000)? 1'b1 : 1'b0;
  assign syndec[17] = (syndout_int == 10'b0000001011)? 1'b1 : 1'b0;
  assign syndec[149] = (syndout_int == 10'b1011011000)? 1'b1 : 1'b0;
  assign syndec[141] = (syndout_int == 10'b1011101101)? 1'b1 : 1'b0;
  assign syndec[40] = (syndout_int == 10'b1110100010)? 1'b1 : 1'b0;
  assign syndec[49] = (syndout_int == 10'b1110001010)? 1'b1 : 1'b0;
  assign syndec[382] = (syndout_int == 10'b0011111110)? 1'b1 : 1'b0;
  assign syndec[270] = (syndout_int == 10'b0111100001)? 1'b1 : 1'b0;
  assign syndec[364] = (syndout_int == 10'b0100110011)? 1'b1 : 1'b0;
  assign syndec[493] = (syndout_int == 10'b1111000010)? 1'b1 : 1'b0;
  assign syndec[37] = (syndout_int == 10'b0001011000)? 1'b1 : 1'b0;
  assign syndec[51] = (syndout_int == 10'b1110010100)? 1'b1 : 1'b0;
  assign syndec[24] = (syndout_int == 10'b1111100011)? 1'b1 : 1'b0;
  assign syndec[328] = (syndout_int == 10'b1010011100)? 1'b1 : 1'b0;
  assign syndec[477] = (syndout_int == 10'b0000001101)? 1'b1 : 1'b0;
  assign syndec[339] = (syndout_int == 10'b1010100110)? 1'b1 : 1'b0;
  assign syndec[218] = (syndout_int == 10'b1001000111)? 1'b1 : 1'b0;
  assign syndec[169] = (syndout_int == 10'b0101000100)? 1'b1 : 1'b0;
  assign syndec[461] = (syndout_int == 10'b0001011110)? 1'b1 : 1'b0;
  assign syndec[114] = (syndout_int == 10'b0011110010)? 1'b1 : 1'b0;
  assign syndec[273] = (syndout_int == 10'b0111001100)? 1'b1 : 1'b0;
  assign syndec[71] = (syndout_int == 10'b0010011101)? 1'b1 : 1'b0;
  assign syndec[174] = (syndout_int == 10'b0101010000)? 1'b1 : 1'b0;
  assign syndec[226] = (syndout_int == 10'b0111010010)? 1'b1 : 1'b0;
  assign syndec[400] = (syndout_int == 10'b1100101100)? 1'b1 : 1'b0;
  assign syndec[4] = (syndout_int == 10'b1111010110)? 1'b1 : 1'b0;
  assign syndec[100] = (syndout_int == 10'b1100110111)? 1'b1 : 1'b0;
  assign syndec[216] = (syndout_int == 10'b1001000010)? 1'b1 : 1'b0;
  assign syndec[130] = (syndout_int == 10'b0100010010)? 1'b1 : 1'b0;
  assign syndec[284] = (syndout_int == 10'b1000110011)? 1'b1 : 1'b0;
  assign syndec[271] = (syndout_int == 10'b0111011110)? 1'b1 : 1'b0;
  assign syndec[55] = (syndout_int == 10'b1110011101)? 1'b1 : 1'b0;
  assign syndec[469] = (syndout_int == 10'b1110111100)? 1'b1 : 1'b0;
  assign syndec[222] = (syndout_int == 10'b1001010000)? 1'b1 : 1'b0;
  assign syndec[121] = (syndout_int == 10'b1100000100)? 1'b1 : 1'b0;
  assign syndec[457] = (syndout_int == 10'b0001110110)? 1'b1 : 1'b0;
  assign syndec[302] = (syndout_int == 10'b1001000001)? 1'b1 : 1'b0;
  assign syndec[385] = (syndout_int == 10'b0011101001)? 1'b1 : 1'b0;
  assign syndec[482] = (syndout_int == 10'b1111111000)? 1'b1 : 1'b0;
  assign syndec[331] = (syndout_int == 10'b1010010110)? 1'b1 : 1'b0;
  assign syndec[353] = (syndout_int == 10'b1011001100)? 1'b1 : 1'b0;
  assign syndec[148] = (syndout_int == 10'b1011010111)? 1'b1 : 1'b0;
  assign syndec[356] = (syndout_int == 10'b1011000101)? 1'b1 : 1'b0;
  assign syndec[136] = (syndout_int == 10'b1011100010)? 1'b1 : 1'b0;
  assign syndec[416] = (syndout_int == 10'b1101001100)? 1'b1 : 1'b0;
  assign syndec[432] = (syndout_int == 10'b0010001100)? 1'b1 : 1'b0;
  assign syndec[501] = (syndout_int == 10'b0000101111)? 1'b1 : 1'b0;
  assign syndec[363] = (syndout_int == 10'b0100110110)? 1'b1 : 1'b0;
  assign syndec[267] = (syndout_int == 10'b0111110110)? 1'b1 : 1'b0;
  assign fixchk[6] = (syndout_int == 10'b0001000000)? 1'b1 : 1'b0;
  assign syndec[279] = (syndout_int == 10'b1000111111)? 1'b1 : 1'b0;
  assign syndec[500] = (syndout_int == 10'b0000110010)? 1'b1 : 1'b0;
  assign fixchk[5] = (syndout_int == 10'b0000100000)? 1'b1 : 1'b0;
  assign syndec[103] = (syndout_int == 10'b1100111101)? 1'b1 : 1'b0;
  assign syndec[282] = (syndout_int == 10'b1000111001)? 1'b1 : 1'b0;
  assign syndec[412] = (syndout_int == 10'b0011001110)? 1'b1 : 1'b0;
  assign syndec[154] = (syndout_int == 10'b0100100111)? 1'b1 : 1'b0;
  assign syndec[277] = (syndout_int == 10'b0111000011)? 1'b1 : 1'b0;
  assign syndec[184] = (syndout_int == 10'b1010000010)? 1'b1 : 1'b0;
  assign syndec[5] = (syndout_int == 10'b1111011001)? 1'b1 : 1'b0;
  assign syndec[345] = (syndout_int == 10'b0101011010)? 1'b1 : 1'b0;
  assign syndec[92] = (syndout_int == 10'b0010101011)? 1'b1 : 1'b0;
  assign syndec[194] = (syndout_int == 10'b1001110010)? 1'b1 : 1'b0;
  assign syndec[446] = (syndout_int == 10'b1110010001)? 1'b1 : 1'b0;
  assign syndec[46] = (syndout_int == 10'b1110110000)? 1'b1 : 1'b0;
  assign syndec[308] = (syndout_int == 10'b1001100101)? 1'b1 : 1'b0;
  assign syndec[215] = (syndout_int == 10'b0110111101)? 1'b1 : 1'b0;
  assign syndec[21] = (syndout_int == 10'b0000011001)? 1'b1 : 1'b0;
  assign syndec[319] = (syndout_int == 10'b0101111110)? 1'b1 : 1'b0;
  assign syndec[198] = (syndout_int == 10'b1001111011)? 1'b1 : 1'b0;
  assign syndec[205] = (syndout_int == 10'b0110001101)? 1'b1 : 1'b0;
  assign syndec[321] = (syndout_int == 10'b0101101100)? 1'b1 : 1'b0;
  assign syndec[278] = (syndout_int == 10'b0111000000)? 1'b1 : 1'b0;
  assign syndec[375] = (syndout_int == 10'b1011111100)? 1'b1 : 1'b0;
  assign syndec[68] = (syndout_int == 10'b0010010111)? 1'b1 : 1'b0;
  assign syndec[418] = (syndout_int == 10'b1101000110)? 1'b1 : 1'b0;
  assign syndec[47] = (syndout_int == 10'b1110110101)? 1'b1 : 1'b0;
  assign syndec[207] = (syndout_int == 10'b0110010101)? 1'b1 : 1'b0;
  assign syndec[89] = (syndout_int == 10'b0010100100)? 1'b1 : 1'b0;
  assign fixchk[8] = (syndout_int == 10'b0100000000)? 1'b1 : 1'b0;
  assign syndec[394] = (syndout_int == 10'b1100010110)? 1'b1 : 1'b0;
  assign syndec[315] = (syndout_int == 10'b0110010110)? 1'b1 : 1'b0;
  assign syndec[60] = (syndout_int == 10'b0001101011)? 1'b1 : 1'b0;
  assign syndec[398] = (syndout_int == 10'b1100111110)? 1'b1 : 1'b0;
  assign syndec[470] = (syndout_int == 10'b1110111010)? 1'b1 : 1'b0;
  assign syndec[206] = (syndout_int == 10'b0110010000)? 1'b1 : 1'b0;
  assign syndec[62] = (syndout_int == 10'b0001110000)? 1'b1 : 1'b0;
  assign syndec[475] = (syndout_int == 10'b1110100001)? 1'b1 : 1'b0;
  assign syndec[164] = (syndout_int == 10'b1010110111)? 1'b1 : 1'b0;
  assign syndec[93] = (syndout_int == 10'b0010101101)? 1'b1 : 1'b0;
  assign syndec[113] = (syndout_int == 10'b0011101010)? 1'b1 : 1'b0;
  assign syndec[393] = (syndout_int == 10'b1100011001)? 1'b1 : 1'b0;
  assign syndec[292] = (syndout_int == 10'b0110100101)? 1'b1 : 1'b0;
  assign syndec[112] = (syndout_int == 10'b0011101111)? 1'b1 : 1'b0;
  assign syndec[386] = (syndout_int == 10'b0011100110)? 1'b1 : 1'b0;
  assign syndec[379] = (syndout_int == 10'b1011110011)? 1'b1 : 1'b0;
  assign syndec[107] = (syndout_int == 10'b0011001000)? 1'b1 : 1'b0;
  assign syndec[75] = (syndout_int == 10'b1101101000)? 1'b1 : 1'b0;
  assign syndec[61] = (syndout_int == 10'b0001101101)? 1'b1 : 1'b0;
  assign syndec[247] = (syndout_int == 10'b1000011101)? 1'b1 : 1'b0;
  assign syndec[87] = (syndout_int == 10'b1101011101)? 1'b1 : 1'b0;
  assign syndec[142] = (syndout_int == 10'b1011110000)? 1'b1 : 1'b0;
  assign syndec[429] = (syndout_int == 10'b0010100001)? 1'b1 : 1'b0;
  assign syndec[56] = (syndout_int == 10'b0001100010)? 1'b1 : 1'b0;
  assign syndec[172] = (syndout_int == 10'b0101001011)? 1'b1 : 1'b0;
  assign syndec[254] = (syndout_int == 10'b0111110000)? 1'b1 : 1'b0;
  assign syndec[316] = (syndout_int == 10'b0110010011)? 1'b1 : 1'b0;
  assign syndec[478] = (syndout_int == 10'b0000000111)? 1'b1 : 1'b0;
  assign syndec[343] = (syndout_int == 10'b0101011111)? 1'b1 : 1'b0;
  assign syndec[283] = (syndout_int == 10'b1000110110)? 1'b1 : 1'b0;
  assign syndec[371] = (syndout_int == 10'b0100000110)? 1'b1 : 1'b0;
  assign syndec[296] = (syndout_int == 10'b1001011100)? 1'b1 : 1'b0;
  assign syndec[153] = (syndout_int == 10'b0100100100)? 1'b1 : 1'b0;
  assign syndec[242] = (syndout_int == 10'b1000010010)? 1'b1 : 1'b0;
  assign syndec[36] = (syndout_int == 10'b0001010111)? 1'b1 : 1'b0;
  assign syndec[30] = (syndout_int == 10'b1111110001)? 1'b1 : 1'b0;
  assign syndec[264] = (syndout_int == 10'b0111111100)? 1'b1 : 1'b0;
  assign syndec[189] = (syndout_int == 10'b1010001101)? 1'b1 : 1'b0;
  assign syndec[263] = (syndout_int == 10'b0111111111)? 1'b1 : 1'b0;
  assign syndec[69] = (syndout_int == 10'b0010011000)? 1'b1 : 1'b0;
  assign fixchk[4] = (syndout_int == 10'b0000010000)? 1'b1 : 1'b0;
  assign syndec[502] = 1'b0;
  assign syndec[496] = (syndout_int == 10'b0000111101)? 1'b1 : 1'b0;
  assign syndec[140] = (syndout_int == 10'b1011101011)? 1'b1 : 1'b0;
  assign syndec[435] = (syndout_int == 10'b0010000101)? 1'b1 : 1'b0;
  assign syndec[118] = (syndout_int == 10'b0011111011)? 1'b1 : 1'b0;
  assign syndec[402] = (syndout_int == 10'b1100100110)? 1'b1 : 1'b0;
  assign syndec[425] = (syndout_int == 10'b0010111001)? 1'b1 : 1'b0;
  assign syndec[407] = (syndout_int == 10'b0011011100)? 1'b1 : 1'b0;
  assign syndec[355] = (syndout_int == 10'b1011000110)? 1'b1 : 1'b0;
  assign syndec[135] = (syndout_int == 10'b0100011101)? 1'b1 : 1'b0;
  assign syndec[427] = (syndout_int == 10'b0010110011)? 1'b1 : 1'b0;
  assign syndec[274] = (syndout_int == 10'b0111001001)? 1'b1 : 1'b0;
  assign syndec[486] = (syndout_int == 10'b1111100000)? 1'b1 : 1'b0;
  assign syndec[499] = (syndout_int == 10'b0000110111)? 1'b1 : 1'b0;
  assign syndec[329] = (syndout_int == 10'b1010011010)? 1'b1 : 1'b0;
  assign syndec[497] = (syndout_int == 10'b0000111011)? 1'b1 : 1'b0;
  assign syndec[232] = (syndout_int == 10'b1000100010)? 1'b1 : 1'b0;
  assign syndec[208] = (syndout_int == 10'b0110101111)? 1'b1 : 1'b0;
  assign syndec[397] = (syndout_int == 10'b1100000001)? 1'b1 : 1'b0;
  assign syndec[96] = (syndout_int == 10'b1100101111)? 1'b1 : 1'b0;
  assign syndec[58] = (syndout_int == 10'b0001100111)? 1'b1 : 1'b0;
  assign syndec[165] = (syndout_int == 10'b1010111000)? 1'b1 : 1'b0;
  assign syndec[378] = (syndout_int == 10'b1011110110)? 1'b1 : 1'b0;
  assign syndec[59] = (syndout_int == 10'b0001101000)? 1'b1 : 1'b0;
  assign syndec[131] = (syndout_int == 10'b0100010100)? 1'b1 : 1'b0;
  assign syndec[161] = (syndout_int == 10'b1010101010)? 1'b1 : 1'b0;
  assign syndec[180] = (syndout_int == 10'b0101110111)? 1'b1 : 1'b0;
  assign syndec[158] = (syndout_int == 10'b0100110000)? 1'b1 : 1'b0;
  assign syndec[80] = (syndout_int == 10'b1101001111)? 1'b1 : 1'b0;
  assign syndec[269] = (syndout_int == 10'b0111101110)? 1'b1 : 1'b0;
  assign syndec[467] = (syndout_int == 10'b0001000011)? 1'b1 : 1'b0;
  assign syndec[420] = (syndout_int == 10'b1101000011)? 1'b1 : 1'b0;
  assign syndec[453] = (syndout_int == 10'b0001111111)? 1'b1 : 1'b0;
  assign syndec[95] = (syndout_int == 10'b0010110101)? 1'b1 : 1'b0;
  assign syndec[181] = (syndout_int == 10'b0101111000)? 1'b1 : 1'b0;
  assign syndec[299] = (syndout_int == 10'b1001010110)? 1'b1 : 1'b0;
  assign syndec[246] = (syndout_int == 10'b1000011011)? 1'b1 : 1'b0;
  assign syndec[298] = (syndout_int == 10'b1001011001)? 1'b1 : 1'b0;
  assign syndec[287] = (syndout_int == 10'b0110111110)? 1'b1 : 1'b0;
  assign syndec[13] = (syndout_int == 10'b0000101100)? 1'b1 : 1'b0;
  assign syndec[455] = (syndout_int == 10'b0001111010)? 1'b1 : 1'b0;
  assign syndec[389] = (syndout_int == 10'b0011100000)? 1'b1 : 1'b0;
  assign syndec[300] = (syndout_int == 10'b1001010011)? 1'b1 : 1'b0;
  assign syndec[83] = (syndout_int == 10'b1101010100)? 1'b1 : 1'b0;
  assign syndec[224] = (syndout_int == 10'b0111001111)? 1'b1 : 1'b0;
  assign syndec[157] = (syndout_int == 10'b0100101101)? 1'b1 : 1'b0;
  assign syndec[173] = (syndout_int == 10'b0101001101)? 1'b1 : 1'b0;
  assign syndec[433] = (syndout_int == 10'b0010001001)? 1'b1 : 1'b0;
  assign syndec[374] = (syndout_int == 10'b1011111111)? 1'b1 : 1'b0;
  assign syndec[436] = (syndout_int == 10'b0010000011)? 1'b1 : 1'b0;
  assign syndec[288] = (syndout_int == 10'b0110110001)? 1'b1 : 1'b0;
  assign fixchk[3] = (syndout_int == 10'b0000001000)? 1'b1 : 1'b0;
  assign syndec[464] = (syndout_int == 10'b0001001001)? 1'b1 : 1'b0;
  assign syndec[64] = (syndout_int == 10'b0010001111)? 1'b1 : 1'b0;
  assign syndec[82] = (syndout_int == 10'b1101010010)? 1'b1 : 1'b0;
  assign syndec[325] = (syndout_int == 10'b0101100011)? 1'b1 : 1'b0;
  assign syndec[358] = (syndout_int == 10'b1011000000)? 1'b1 : 1'b0;
  assign syndec[48] = (syndout_int == 10'b1110001111)? 1'b1 : 1'b0;
  assign syndec[76] = (syndout_int == 10'b1101101011)? 1'b1 : 1'b0;
  assign syndec[126] = (syndout_int == 10'b1100010000)? 1'b1 : 1'b0;
  assign syndec[26] = (syndout_int == 10'b1111100110)? 1'b1 : 1'b0;
  assign syndec[361] = (syndout_int == 10'b0100111010)? 1'b1 : 1'b0;
  assign syndec[124] = (syndout_int == 10'b1100001011)? 1'b1 : 1'b0;
  assign syndec[495] = (syndout_int == 10'b0000111110)? 1'b1 : 1'b0;
  assign syndec[387] = (syndout_int == 10'b0011100101)? 1'b1 : 1'b0;
  assign syndec[119] = (syndout_int == 10'b0011111101)? 1'b1 : 1'b0;
  assign syndec[16] = (syndout_int == 10'b0000001110)? 1'b1 : 1'b0;
  assign syndec[127] = (syndout_int == 10'b1100010101)? 1'b1 : 1'b0;
  assign syndec[431] = (syndout_int == 10'b0010010001)? 1'b1 : 1'b0;
  assign syndec[424] = (syndout_int == 10'b0010111010)? 1'b1 : 1'b0;
  assign syndec[357] = (syndout_int == 10'b1011000011)? 1'b1 : 1'b0;
  assign syndec[311] = (syndout_int == 10'b0110011111)? 1'b1 : 1'b0;
  assign syndec[245] = (syndout_int == 10'b1000011000)? 1'b1 : 1'b0;
  assign syndec[146] = (syndout_int == 10'b1011010010)? 1'b1 : 1'b0;
  assign syndec[77] = (syndout_int == 10'b1101101101)? 1'b1 : 1'b0;
  assign syndec[108] = (syndout_int == 10'b0011001011)? 1'b1 : 1'b0;
  assign syndec[84] = (syndout_int == 10'b1101010111)? 1'b1 : 1'b0;
  assign syndec[177] = (syndout_int == 10'b0101101010)? 1'b1 : 1'b0;
  assign syndec[217] = (syndout_int == 10'b1001000100)? 1'b1 : 1'b0;
  assign syndec[456] = (syndout_int == 10'b0001111001)? 1'b1 : 1'b0;
  assign syndec[280] = (syndout_int == 10'b1000111100)? 1'b1 : 1'b0;
  assign syndec[220] = (syndout_int == 10'b1001001011)? 1'b1 : 1'b0;
  assign syndec[399] = (syndout_int == 10'b1100110001)? 1'b1 : 1'b0;
  assign syndec[241] = (syndout_int == 10'b1000001010)? 1'b1 : 1'b0;
  assign syndec[195] = (syndout_int == 10'b1001110100)? 1'b1 : 1'b0;
  assign syndec[259] = (syndout_int == 10'b1000001001)? 1'b1 : 1'b0;
  assign syndec[41] = (syndout_int == 10'b1110100100)? 1'b1 : 1'b0;
  assign syndec[346] = (syndout_int == 10'b0101011001)? 1'b1 : 1'b0;
  assign syndec[314] = (syndout_int == 10'b0110011001)? 1'b1 : 1'b0;
  assign syndec[102] = (syndout_int == 10'b1100111011)? 1'b1 : 1'b0;
  assign syndec[369] = (syndout_int == 10'b0100001100)? 1'b1 : 1'b0;
  assign syndec[14] = (syndout_int == 10'b0000110001)? 1'b1 : 1'b0;
  assign syndec[403] = (syndout_int == 10'b1100100101)? 1'b1 : 1'b0;
  assign syndec[52] = (syndout_int == 10'b1110010111)? 1'b1 : 1'b0;
  assign syndec[344] = (syndout_int == 10'b0101011100)? 1'b1 : 1'b0;
  assign syndec[381] = (syndout_int == 10'b1011100001)? 1'b1 : 1'b0;
  assign syndec[380] = (syndout_int == 10'b1011101110)? 1'b1 : 1'b0;
  assign syndec[11] = (syndout_int == 10'b0000101001)? 1'b1 : 1'b0;
  assign syndec[78] = (syndout_int == 10'b1101110000)? 1'b1 : 1'b0;
  assign syndec[449] = (syndout_int == 10'b1110000110)? 1'b1 : 1'b0;
  assign syndec[376] = (syndout_int == 10'b1011111010)? 1'b1 : 1'b0;
  assign syndec[419] = (syndout_int == 10'b1101000101)? 1'b1 : 1'b0;
  assign syndec[66] = (syndout_int == 10'b0010010010)? 1'b1 : 1'b0;
  assign syndec[227] = (syndout_int == 10'b0111010100)? 1'b1 : 1'b0;
  assign syndec[167] = (syndout_int == 10'b1010111101)? 1'b1 : 1'b0;
  assign syndec[3] = (syndout_int == 10'b1111010101)? 1'b1 : 1'b0;
  assign syndec[192] = (syndout_int == 10'b1001101111)? 1'b1 : 1'b0;
  assign syndec[414] = (syndout_int == 10'b1101011110)? 1'b1 : 1'b0;
  assign syndec[491] = (syndout_int == 10'b1111000111)? 1'b1 : 1'b0;
  assign syndec[97] = (syndout_int == 10'b1100101010)? 1'b1 : 1'b0;
  assign syndec[39] = (syndout_int == 10'b0001011101)? 1'b1 : 1'b0;
  assign syndec[428] = (syndout_int == 10'b0010101110)? 1'b1 : 1'b0;
  assign syndec[359] = (syndout_int == 10'b0100111111)? 1'b1 : 1'b0;
  assign syndec[7] = (syndout_int == 10'b1111011100)? 1'b1 : 1'b0;
  assign syndec[312] = (syndout_int == 10'b0110011100)? 1'b1 : 1'b0;
  assign syndec[476] = (syndout_int == 10'b0000011111)? 1'b1 : 1'b0;
  assign fixchk[2] = (syndout_int == 10'b0000000100)? 1'b1 : 1'b0;
  assign syndec[19] = (syndout_int == 10'b0000010101)? 1'b1 : 1'b0;
  assign syndec[191] = (syndout_int == 10'b1010010101)? 1'b1 : 1'b0;
  assign syndec[276] = (syndout_int == 10'b0111000101)? 1'b1 : 1'b0;
  assign fixchk[0] = (syndout_int == 10'b0000000001)? 1'b1 : 1'b0;
  assign syndec[18] = (syndout_int == 10'b0000010011)? 1'b1 : 1'b0;
  assign syndec[305] = (syndout_int == 10'b1001101100)? 1'b1 : 1'b0;
  assign syndec[401] = (syndout_int == 10'b1100101001)? 1'b1 : 1'b0;
  assign syndec[214] = (syndout_int == 10'b0110111011)? 1'b1 : 1'b0;
  assign syndec[498] = (syndout_int == 10'b0000111000)? 1'b1 : 1'b0;
  assign syndec[250] = (syndout_int == 10'b0111100111)? 1'b1 : 1'b0;
  assign syndec[116] = (syndout_int == 10'b0011110111)? 1'b1 : 1'b0;
  assign syndec[237] = (syndout_int == 10'b1000101101)? 1'b1 : 1'b0;
  assign syndec[211] = (syndout_int == 10'b0110110100)? 1'b1 : 1'b0;
  assign syndec[261] = (syndout_int == 10'b1000000101)? 1'b1 : 1'b0;
  assign syndec[143] = (syndout_int == 10'b1011110101)? 1'b1 : 1'b0;
  assign syndec[229] = (syndout_int == 10'b0111011000)? 1'b1 : 1'b0;
  assign syndec[323] = (syndout_int == 10'b0101100110)? 1'b1 : 1'b0;
  assign syndec[340] = (syndout_int == 10'b1010100101)? 1'b1 : 1'b0;
  assign syndec[234] = (syndout_int == 10'b1000100111)? 1'b1 : 1'b0;
  assign syndec[171] = (syndout_int == 10'b0101001000)? 1'b1 : 1'b0;
  assign syndec[201] = (syndout_int == 10'b0110000100)? 1'b1 : 1'b0;
  assign syndec[99] = (syndout_int == 10'b1100110100)? 1'b1 : 1'b0;
  assign syndec[275] = (syndout_int == 10'b0111000110)? 1'b1 : 1'b0;
  assign syndec[29] = (syndout_int == 10'b1111101100)? 1'b1 : 1'b0;
  assign syndec[105] = (syndout_int == 10'b0011000100)? 1'b1 : 1'b0;
  assign syndec[163] = (syndout_int == 10'b1010110100)? 1'b1 : 1'b0;
  assign syndec[462] = (syndout_int == 10'b0001010001)? 1'b1 : 1'b0;
  assign syndec[317] = (syndout_int == 10'b0110001110)? 1'b1 : 1'b0;
  assign syndec[79] = (syndout_int == 10'b1101110101)? 1'b1 : 1'b0;
  assign syndec[460] = (syndout_int == 10'b0001100001)? 1'b1 : 1'b0;
  assign syndec[295] = (syndout_int == 10'b1001011111)? 1'b1 : 1'b0;
  assign syndec[6] = (syndout_int == 10'b1111011010)? 1'b1 : 1'b0;
  assign syndec[98] = (syndout_int == 10'b1100110010)? 1'b1 : 1'b0;
  assign syndec[452] = (syndout_int == 10'b1110000000)? 1'b1 : 1'b0;
  assign syndec[450] = (syndout_int == 10'b1110000101)? 1'b1 : 1'b0;
  assign syndec[117] = (syndout_int == 10'b0011111000)? 1'b1 : 1'b0;
  assign syndec[301] = (syndout_int == 10'b1001001110)? 1'b1 : 1'b0;
  assign syndec[45] = (syndout_int == 10'b1110101101)? 1'b1 : 1'b0;
  assign syndec[137] = (syndout_int == 10'b1011100100)? 1'b1 : 1'b0;
  assign syndec[318] = (syndout_int == 10'b0110000001)? 1'b1 : 1'b0;
  assign syndec[111] = (syndout_int == 10'b0011010101)? 1'b1 : 1'b0;
  assign syndec[352] = (syndout_int == 10'b1011010001)? 1'b1 : 1'b0;
  assign syndec[468] = (syndout_int == 10'b1110111111)? 1'b1 : 1'b0;
  assign syndec[443] = (syndout_int == 10'b1101101110)? 1'b1 : 1'b0;
  assign syndec[150] = (syndout_int == 10'b1011011011)? 1'b1 : 1'b0;
  assign syndec[15] = (syndout_int == 10'b0000110100)? 1'b1 : 1'b0;
  assign syndec[202] = (syndout_int == 10'b0110000111)? 1'b1 : 1'b0;
  assign syndec[410] = (syndout_int == 10'b0011010110)? 1'b1 : 1'b0;
  assign syndec[32] = (syndout_int == 10'b0001001111)? 1'b1 : 1'b0;
  assign syndec[293] = (syndout_int == 10'b0110100011)? 1'b1 : 1'b0;
  assign syndec[197] = (syndout_int == 10'b1001111000)? 1'b1 : 1'b0;
  assign syndec[349] = (syndout_int == 10'b0101001110)? 1'b1 : 1'b0;
  assign syndec[441] = (syndout_int == 10'b1101110110)? 1'b1 : 1'b0;
  assign syndec[294] = (syndout_int == 10'b0110100000)? 1'b1 : 1'b0;
  assign syndec[417] = (syndout_int == 10'b1101001001)? 1'b1 : 1'b0;
  assign syndec[411] = (syndout_int == 10'b0011010011)? 1'b1 : 1'b0;
  assign syndec[2] = (syndout_int == 10'b1111010011)? 1'b1 : 1'b0;
  assign syndec[272] = (syndout_int == 10'b0111010001)? 1'b1 : 1'b0;
  assign syndec[390] = (syndout_int == 10'b1100011111)? 1'b1 : 1'b0;
  assign syndec[268] = (syndout_int == 10'b0111110011)? 1'b1 : 1'b0;
  assign syndec[147] = (syndout_int == 10'b1011010100)? 1'b1 : 1'b0;
  assign syndec[395] = (syndout_int == 10'b1100010011)? 1'b1 : 1'b0;
  assign syndec[413] = (syndout_int == 10'b0011000001)? 1'b1 : 1'b0;
  assign fixchk[9] = (syndout_int == 10'b1000000000)? 1'b1 : 1'b0;
  assign syndec[159] = (syndout_int == 10'b0100110101)? 1'b1 : 1'b0;
  assign syndec[23] = (syndout_int == 10'b0000011100)? 1'b1 : 1'b0;
  assign syndec[290] = (syndout_int == 10'b0110101001)? 1'b1 : 1'b0;
  assign syndec[86] = (syndout_int == 10'b1101011011)? 1'b1 : 1'b0;
  assign syndec[120] = (syndout_int == 10'b1100000010)? 1'b1 : 1'b0;
  assign syndec[488] = (syndout_int == 10'b1111010000)? 1'b1 : 1'b0;
  assign syndec[447] = (syndout_int == 10'b1110001100)? 1'b1 : 1'b0;
  assign syndec[320] = (syndout_int == 10'b0101110001)? 1'b1 : 1'b0;
  assign syndec[57] = (syndout_int == 10'b0001100100)? 1'b1 : 1'b0;
  assign syndec[38] = (syndout_int == 10'b0001011011)? 1'b1 : 1'b0;
  assign syndec[139] = (syndout_int == 10'b1011101000)? 1'b1 : 1'b0;
  assign syndec[451] = (syndout_int == 10'b1110000011)? 1'b1 : 1'b0;
  assign syndec[291] = (syndout_int == 10'b0110100110)? 1'b1 : 1'b0;
  assign syndec[372] = (syndout_int == 10'b0100000101)? 1'b1 : 1'b0;
  assign fixchk[1] = (syndout_int == 10'b0000000010)? 1'b1 : 1'b0;
  assign syndec[492] = (syndout_int == 10'b1111000100)? 1'b1 : 1'b0;
  assign syndec[404] = (syndout_int == 10'b1100100011)? 1'b1 : 1'b0;
  assign syndec[156] = (syndout_int == 10'b0100101011)? 1'b1 : 1'b0;
  assign syndec[72] = (syndout_int == 10'b1101100010)? 1'b1 : 1'b0;
  assign syndec[175] = (syndout_int == 10'b0101010101)? 1'b1 : 1'b0;
  assign syndec[326] = (syndout_int == 10'b0101100000)? 1'b1 : 1'b0;
  assign syndec[335] = (syndout_int == 10'b1010111110)? 1'b1 : 1'b0;
  assign syndec[367] = (syndout_int == 10'b0100011110)? 1'b1 : 1'b0;
  assign syndec[454] = (syndout_int == 10'b0001111100)? 1'b1 : 1'b0;
  assign syndec[138] = (syndout_int == 10'b1011100111)? 1'b1 : 1'b0;
  assign syndec[251] = (syndout_int == 10'b0111101000)? 1'b1 : 1'b0;
  assign syndec[333] = (syndout_int == 10'b1010001110)? 1'b1 : 1'b0;
  assign syndec[336] = (syndout_int == 10'b1010110001)? 1'b1 : 1'b0;
  assign syndec[262] = (syndout_int == 10'b1000000011)? 1'b1 : 1'b0;
  assign syndec[373] = (syndout_int == 10'b0100000011)? 1'b1 : 1'b0;
  assign syndec[384] = (syndout_int == 10'b0011101100)? 1'b1 : 1'b0;
  assign syndec[466] = (syndout_int == 10'b0001000101)? 1'b1 : 1'b0;
  assign syndec[20] = (syndout_int == 10'b0000010110)? 1'b1 : 1'b0;
  assign syndec[151] = (syndout_int == 10'b1011011101)? 1'b1 : 1'b0;
  assign syndec[42] = (syndout_int == 10'b1110100111)? 1'b1 : 1'b0;
  assign syndec[409] = (syndout_int == 10'b0011011001)? 1'b1 : 1'b0;
  assign syndec[415] = (syndout_int == 10'b1101010001)? 1'b1 : 1'b0;
  assign syndec[110] = (syndout_int == 10'b0011010000)? 1'b1 : 1'b0;
  assign syndec[35] = (syndout_int == 10'b0001010100)? 1'b1 : 1'b0;
  assign syndec[391] = (syndout_int == 10'b1100011100)? 1'b1 : 1'b0;
  assign syndec[88] = (syndout_int == 10'b0010100010)? 1'b1 : 1'b0;
  assign syndec[388] = (syndout_int == 10'b0011100011)? 1'b1 : 1'b0;
  assign syndec[285] = (syndout_int == 10'b1000101110)? 1'b1 : 1'b0;
  assign syndec[303] = (syndout_int == 10'b1001111110)? 1'b1 : 1'b0;
  assign syndec[473] = (syndout_int == 10'b1110110011)? 1'b1 : 1'b0;
  assign syndec[54] = (syndout_int == 10'b1110011011)? 1'b1 : 1'b0;
  assign syndec[190] = (syndout_int == 10'b1010010000)? 1'b1 : 1'b0;
  assign syndec[430] = (syndout_int == 10'b0010011110)? 1'b1 : 1'b0;
  assign syndec[238] = (syndout_int == 10'b1000110000)? 1'b1 : 1'b0;
  assign syndec[34] = (syndout_int == 10'b0001010010)? 1'b1 : 1'b0;
  assign syndec[480] = (syndout_int == 10'b1111111101)? 1'b1 : 1'b0;
  assign syndec[487] = (syndout_int == 10'b1111011111)? 1'b1 : 1'b0;
  assign syndec[33] = (syndout_int == 10'b0001001010)? 1'b1 : 1'b0;
  assign syndec[341] = (syndout_int == 10'b1010100011)? 1'b1 : 1'b0;
  assign syndec[445] = (syndout_int == 10'b1110011110)? 1'b1 : 1'b0;
  assign syndec[310] = (syndout_int == 10'b1001100000)? 1'b1 : 1'b0;
  assign syndec[437] = (syndout_int == 10'b1101111111)? 1'b1 : 1'b0;
  assign syndec[25] = (syndout_int == 10'b1111100101)? 1'b1 : 1'b0;
  assign syndec[144] = (syndout_int == 10'b1011001111)? 1'b1 : 1'b0;
  assign syndec[348] = (syndout_int == 10'b0101010011)? 1'b1 : 1'b0;
  assign syndec[474] = (syndout_int == 10'b1110101110)? 1'b1 : 1'b0;
  assign syndec[322] = (syndout_int == 10'b0101101001)? 1'b1 : 1'b0;
  assign syndec[1] = (syndout_int == 10'b1111001011)? 1'b1 : 1'b0;
  assign syndec[183] = (syndout_int == 10'b0101111101)? 1'b1 : 1'b0;
  assign syndec[489] = (syndout_int == 10'b1111001101)? 1'b1 : 1'b0;
  assign syndec[334] = (syndout_int == 10'b1010000001)? 1'b1 : 1'b0;
  assign syndec[383] = (syndout_int == 10'b0011110001)? 1'b1 : 1'b0;
  assign syndec[132] = (syndout_int == 10'b0100010111)? 1'b1 : 1'b0;
  assign syndec[490] = (syndout_int == 10'b1111001000)? 1'b1 : 1'b0;
  assign syndec[365] = (syndout_int == 10'b0100101110)? 1'b1 : 1'b0;
  assign syndec[442] = (syndout_int == 10'b1101110011)? 1'b1 : 1'b0;
  assign syndec[337] = (syndout_int == 10'b1010101100)? 1'b1 : 1'b0;
  assign syndec[145] = (syndout_int == 10'b1011001010)? 1'b1 : 1'b0;
  assign syndec[377] = (syndout_int == 10'b1011111001)? 1'b1 : 1'b0;
  assign syndec[63] = (syndout_int == 10'b0001110101)? 1'b1 : 1'b0;
  assign syndec[459] = (syndout_int == 10'b0001101110)? 1'b1 : 1'b0;
  assign syndec[22] = (syndout_int == 10'b0000011010)? 1'b1 : 1'b0;
  assign syndec[166] = (syndout_int == 10'b1010111011)? 1'b1 : 1'b0;
  assign syndec[253] = (syndout_int == 10'b0111101101)? 1'b1 : 1'b0;
  assign syndec[252] = (syndout_int == 10'b0111101011)? 1'b1 : 1'b0;
  assign syndec[225] = (syndout_int == 10'b0111001010)? 1'b1 : 1'b0;
  assign syndec[160] = (syndout_int == 10'b1010101111)? 1'b1 : 1'b0;
  assign syndec[351] = (syndout_int == 10'b1011011110)? 1'b1 : 1'b0;
  assign syndec[260] = (syndout_int == 10'b1000000110)? 1'b1 : 1'b0;
  assign syndec[286] = (syndout_int == 10'b1000100001)? 1'b1 : 1'b0;
  assign syndec[324] = (syndout_int == 10'b0101100101)? 1'b1 : 1'b0;
  assign syndec[101] = (syndout_int == 10'b1100111000)? 1'b1 : 1'b0;
  assign syndec[458] = (syndout_int == 10'b0001110011)? 1'b1 : 1'b0;
  assign syndec[248] = (syndout_int == 10'b0111100010)? 1'b1 : 1'b0;
  assign syndec[31] = (syndout_int == 10'b1111110100)? 1'b1 : 1'b0;
  assign syndec[392] = (syndout_int == 10'b1100011010)? 1'b1 : 1'b0;
  assign syndec[8] = (syndout_int == 10'b0000100011)? 1'b1 : 1'b0;
  assign syndec[289] = (syndout_int == 10'b0110101100)? 1'b1 : 1'b0;
  assign fixchk[7] = (syndout_int == 10'b0010000000)? 1'b1 : 1'b0;
  assign syndec[0] = (syndout_int == 10'b1111001110)? 1'b1 : 1'b0;
  assign syndec[81] = (syndout_int == 10'b1101001010)? 1'b1 : 1'b0;
  assign syndec[231] = (syndout_int == 10'b0111011101)? 1'b1 : 1'b0;
  assign syndec[91] = (syndout_int == 10'b0010101000)? 1'b1 : 1'b0;
  assign syndec[28] = (syndout_int == 10'b1111101010)? 1'b1 : 1'b0;
  assign syndec[162] = (syndout_int == 10'b1010110010)? 1'b1 : 1'b0;
  assign syndec[483] = (syndout_int == 10'b1111110111)? 1'b1 : 1'b0;
  assign syndec[362] = (syndout_int == 10'b0100111001)? 1'b1 : 1'b0;
  assign syndec[421] = (syndout_int == 10'b1101000000)? 1'b1 : 1'b0;
  assign syndec[439] = (syndout_int == 10'b1101111010)? 1'b1 : 1'b0;
  assign syndec[368] = (syndout_int == 10'b0100010001)? 1'b1 : 1'b0;
  assign syndec[10] = (syndout_int == 10'b0000100110)? 1'b1 : 1'b0;
  assign syndec[53] = (syndout_int == 10'b1110011000)? 1'b1 : 1'b0;
  assign syndec[494] = (syndout_int == 10'b1111000001)? 1'b1 : 1'b0;
  assign syndec[239] = (syndout_int == 10'b1000110101)? 1'b1 : 1'b0;
  assign syndec[109] = (syndout_int == 10'b0011001101)? 1'b1 : 1'b0;
  assign syndec[304] = (syndout_int == 10'b1001110001)? 1'b1 : 1'b0;
  assign syndec[129] = (syndout_int == 10'b0100001010)? 1'b1 : 1'b0;
  assign syndec[155] = (syndout_int == 10'b0100101000)? 1'b1 : 1'b0;
  assign syndec[128] = (syndout_int == 10'b0100001111)? 1'b1 : 1'b0;
  assign syndec[50] = (syndout_int == 10'b1110010010)? 1'b1 : 1'b0;
  assign syndec[65] = (syndout_int == 10'b0010001010)? 1'b1 : 1'b0;
  assign syndec[179] = (syndout_int == 10'b0101110100)? 1'b1 : 1'b0;
  assign syndec[258] = (syndout_int == 10'b1000001100)? 1'b1 : 1'b0;
  assign syndec[122] = (syndout_int == 10'b1100000111)? 1'b1 : 1'b0;
  assign syndec[196] = (syndout_int == 10'b1001110111)? 1'b1 : 1'b0;
  assign syndec[123] = (syndout_int == 10'b1100001000)? 1'b1 : 1'b0;
  assign syndec[203] = (syndout_int == 10'b0110001000)? 1'b1 : 1'b0;
  assign syndec[366] = (syndout_int == 10'b0100100001)? 1'b1 : 1'b0;
  assign syndec[178] = (syndout_int == 10'b0101110010)? 1'b1 : 1'b0;
  assign syndec[70] = (syndout_int == 10'b0010011011)? 1'b1 : 1'b0;
  assign syndec[223] = (syndout_int == 10'b1001010101)? 1'b1 : 1'b0;
  assign syndec[188] = (syndout_int == 10'b1010001011)? 1'b1 : 1'b0;
  assign syndec[152] = (syndout_int == 10'b0100100010)? 1'b1 : 1'b0;
  assign syndec[233] = (syndout_int == 10'b1000100100)? 1'b1 : 1'b0;
  assign syndec[338] = (syndout_int == 10'b1010101001)? 1'b1 : 1'b0;
  assign syndec[327] = (syndout_int == 10'b1010011111)? 1'b1 : 1'b0;
  assign syndec[185] = (syndout_int == 10'b1010000100)? 1'b1 : 1'b0;
  assign syndec[134] = (syndout_int == 10'b0100011011)? 1'b1 : 1'b0;
  assign syndec[472] = (syndout_int == 10'b1110110110)? 1'b1 : 1'b0;
  assign syndec[133] = (syndout_int == 10'b0100011000)? 1'b1 : 1'b0;
  assign syndec[74] = (syndout_int == 10'b1101100111)? 1'b1 : 1'b0;
  assign syndec[465] = (syndout_int == 10'b0001000110)? 1'b1 : 1'b0;
  assign syndec[182] = (syndout_int == 10'b0101111011)? 1'b1 : 1'b0;
  assign syndec[106] = (syndout_int == 10'b0011000111)? 1'b1 : 1'b0;
  assign syndec[306] = (syndout_int == 10'b1001101001)? 1'b1 : 1'b0;
  assign syndec[228] = (syndout_int == 10'b0111010111)? 1'b1 : 1'b0;
  assign syndec[309] = (syndout_int == 10'b1001100011)? 1'b1 : 1'b0;
  assign syndec[104] = (syndout_int == 10'b0011000010)? 1'b1 : 1'b0;
  assign syndec[221] = (syndout_int == 10'b1001001101)? 1'b1 : 1'b0;
  assign syndec[484] = (syndout_int == 10'b1111110010)? 1'b1 : 1'b0;
  assign syndec[210] = (syndout_int == 10'b0110110010)? 1'b1 : 1'b0;
  assign syndec[408] = (syndout_int == 10'b0011011010)? 1'b1 : 1'b0;
  assign syndec[350] = (syndout_int == 10'b0101000001)? 1'b1 : 1'b0;
  assign syndec[481] = (syndout_int == 10'b1111111011)? 1'b1 : 1'b0;
  assign syndec[186] = (syndout_int == 10'b1010000111)? 1'b1 : 1'b0;
  assign syndec[12] = (syndout_int == 10'b0000101010)? 1'b1 : 1'b0;
  assign syndec[440] = (syndout_int == 10'b1101111001)? 1'b1 : 1'b0;
  assign syndec[370] = (syndout_int == 10'b0100001001)? 1'b1 : 1'b0;
  assign syndec[330] = (syndout_int == 10'b1010011001)? 1'b1 : 1'b0;
  assign syndec[115] = (syndout_int == 10'b0011110100)? 1'b1 : 1'b0;
  assign syndec[360] = (syndout_int == 10'b0100111100)? 1'b1 : 1'b0;
  assign syndec[235] = (syndout_int == 10'b1000101000)? 1'b1 : 1'b0;
  assign syndec[240] = (syndout_int == 10'b1000001111)? 1'b1 : 1'b0;
  assign syndec[212] = (syndout_int == 10'b0110110111)? 1'b1 : 1'b0;
  assign syndec[209] = (syndout_int == 10'b0110101010)? 1'b1 : 1'b0;
  assign syndec[213] = (syndout_int == 10'b0110111000)? 1'b1 : 1'b0;
  assign syndec[444] = (syndout_int == 10'b1101100001)? 1'b1 : 1'b0;
  assign syndec[479] = (syndout_int == 10'b1111111110)? 1'b1 : 1'b0;
  assign syndec[236] = (syndout_int == 10'b1000101011)? 1'b1 : 1'b0;
  assign syndec[405] = (syndout_int == 10'b1100100000)? 1'b1 : 1'b0;
  assign syndec[423] = (syndout_int == 10'b0010111100)? 1'b1 : 1'b0;
  assign syndec[313] = (syndout_int == 10'b0110011010)? 1'b1 : 1'b0;
  assign syndec[438] = (syndout_int == 10'b1101111100)? 1'b1 : 1'b0;
  assign syndec[168] = (syndout_int == 10'b0101000010)? 1'b1 : 1'b0;
  assign syndec[396] = (syndout_int == 10'b1100001110)? 1'b1 : 1'b0;
  assign syndec[44] = (syndout_int == 10'b1110101011)? 1'b1 : 1'b0;
  assign syndec[354] = (syndout_int == 10'b1011001001)? 1'b1 : 1'b0;
  assign syndec[332] = (syndout_int == 10'b1010010011)? 1'b1 : 1'b0;
  assign syndec[170] = (syndout_int == 10'b0101000111)? 1'b1 : 1'b0;
  assign syndec[265] = (syndout_int == 10'b0111111010)? 1'b1 : 1'b0;
  assign syndec[90] = (syndout_int == 10'b0010100111)? 1'b1 : 1'b0;
  assign syndec[200] = (syndout_int == 10'b0110000010)? 1'b1 : 1'b0;
  assign syndec[406] = (syndout_int == 10'b0011011111)? 1'b1 : 1'b0;
  assign syndec[255] = (syndout_int == 10'b0111110101)? 1'b1 : 1'b0;
  assign syndec[230] = (syndout_int == 10'b0111011011)? 1'b1 : 1'b0;
  assign syndec[266] = (syndout_int == 10'b0111111001)? 1'b1 : 1'b0;
  assign syndec[463] = (syndout_int == 10'b0001001100)? 1'b1 : 1'b0;
  assign syndec[176] = (syndout_int == 10'b0101101111)? 1'b1 : 1'b0;
  assign syndec[256] = (syndout_int == 10'b1000011110)? 1'b1 : 1'b0;
  assign syndec[67] = (syndout_int == 10'b0010010100)? 1'b1 : 1'b0;
  assign syndec[27] = (syndout_int == 10'b1111101001)? 1'b1 : 1'b0;
  assign syndec[422] = (syndout_int == 10'b0010111111)? 1'b1 : 1'b0;
  assign syndec[85] = (syndout_int == 10'b1101011000)? 1'b1 : 1'b0;
  assign syndec[244] = (syndout_int == 10'b1000010111)? 1'b1 : 1'b0;
  assign syndec[243] = (syndout_int == 10'b1000010100)? 1'b1 : 1'b0;
  assign syndec[471] = (syndout_int == 10'b1110111001)? 1'b1 : 1'b0;
  assign syndec[73] = (syndout_int == 10'b1101100100)? 1'b1 : 1'b0;
  assign syndec[193] = (syndout_int == 10'b1001101010)? 1'b1 : 1'b0;
  assign syndec[199] = (syndout_int == 10'b1001111101)? 1'b1 : 1'b0;
  assign syndec[347] = (syndout_int == 10'b0101010110)? 1'b1 : 1'b0;
  assign syndec[94] = (syndout_int == 10'b0010110000)? 1'b1 : 1'b0;
  assign syndec[307] = (syndout_int == 10'b1001100110)? 1'b1 : 1'b0;
  assign syndec[342] = (syndout_int == 10'b1010100000)? 1'b1 : 1'b0;
  assign syndec[426] = (syndout_int == 10'b0010110110)? 1'b1 : 1'b0;
  assign syndec[9] = (syndout_int == 10'b0000100101)? 1'b1 : 1'b0;
  assign syndec[43] = (syndout_int == 10'b1110101000)? 1'b1 : 1'b0;
  assign syndec[434] = (syndout_int == 10'b0010000110)? 1'b1 : 1'b0;
  assign syndec[249] = (syndout_int == 10'b0111100100)? 1'b1 : 1'b0;
  assign syndec[187] = (syndout_int == 10'b1010001000)? 1'b1 : 1'b0;
  assign syndec[204] = (syndout_int == 10'b0110001011)? 1'b1 : 1'b0;
  assign syndec[448] = (syndout_int == 10'b1110001001)? 1'b1 : 1'b0;
  assign syndec[485] = (syndout_int == 10'b1111101111)? 1'b1 : 1'b0;
  assign syndec[297] = (syndout_int == 10'b1001011010)? 1'b1 : 1'b0;
  assign syndec[125] = (syndout_int == 10'b1100001101)? 1'b1 : 1'b0;
  assign syndec[281] = (syndout_int == 10'b1000111010)? 1'b1 : 1'b0;
  assign syndec[257] = (syndout_int == 10'b1000010001)? 1'b1 : 1'b0;

  always @ (datain) begin : td_PROC

    integer i;

    for (i=0 ; i <= 511 ; i=i+1) begin
      if (i < WIDTH)
        dat_in[i] = datain[i];
      else
        dat_in[i] = 1'b0;
    end
  end

  assign syndout_int = chkout_int ^ chkin;

  assign err_detect = ~gen & ( |syndout_int );

  assign err_multpl = err_detect & ( ~(^syndout_int) || (|syndec[502:WIDTH]) );

  assign fixdata = syndec[WIDTH-1:0];

  assign chkout = (gen == 1'b1)? chkout_int : (correct_n == 1'b0)? chkin ^ fixchk : chkin;

  assign dataout = ((gen == 1'b0) && (correct_n == 1'b0))? datain ^ fixdata : datain;

  assign syndout = syndout_int;

// spyglass enable_block W146
endmodule
