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

// -----------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #4 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_crc.sv#4 $
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- CRC Module
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_cxl_mem_cache_crc (
  input  [511:0] cxl_flit_data_i,
  output [15:0] cxl_crc_data_o
);

// ECC Mask Bits
  parameter [511:0] ECC_MASK_CRC15 = 512'hEF9C_D9F9_C4BB_B83A_3E84_A97C_D7AE_DA13_FAEB_01B8_5B20_4A4C_AE1E_79D9_7753_5D21_DC7F_DD6A_38F0_3E77_F5F5_2A2C_636D_B05C_3978_EA30_CD50_E0D9_9B06_93D4_746B_2431; 
  parameter [511:0] ECC_MASK_CRC14 = 512'h9852_B505_26E6_6427_21C6_FDC2_BC79_B71A_079E_8164_76B0_6F6A_F911_4535_CCFA_F3B1_3240_33DF_2488_214C_0F0F_BF3A_52DB_6872_25C4_9F28_ABF8_90B5_5685_DA3E_4E5E_B629; 
  parameter [511:0] ECC_MASK_CRC13 = 512'h23B5_837B_57C8_8A29_AE67_D79D_8992_019E_F924_410A_6078_7DF9_D296_DB43_912E_24F9_455F_C485_AAB4_2ED1_F272_F5B1_4A00_0465_2B9A_A5A4_98AC_A883_3044_7ECB_5344_7F25; 
  parameter [511:0] ECC_MASK_CRC12 = 512'h7E46_1844_6F5F_FD2E_E9B7_42B2_1367_DADC_8679_213D_6B1C_74B0_4755_1478_BFC4_4F5D_7ED0_3F28_EDAA_291F_0CCC_50F4_C66D_B26E_ACB5_B8E2_8106_B498_0324_ACB1_DDC9_1BA3; 
  parameter [511:0] ECC_MASK_CRC11 = 512'h50BF_D5DB_F314_46AD_4A5F_0825_DE1D_377D_B9D7_9126_EEAE_7014_8DB4_F3E5_28B1_7A8F_6317_C2FE_4E25_2AF8_7393_0256_005B_696B_6F22_3641_8DD3_BA95_9A94_C58C_9A8F_A9E0; 
  parameter [511:0] ECC_MASK_CRC10 = 512'hA85F_EAED_F98A_2356_A52F_8412_EF0E_9BBE_DCEB_C893_7757_380A_46DA_79F2_9458_BD47_B18B_E17F_2712_957C_39C9_812B_002D_B4B5_B791_1B20_C6E9_DD4A_CD4A_62C6_4D47_D4F0; 
  parameter [511:0] ECC_MASK_CRC09 = 512'h542F_F576_FCC5_11AB_5297_C209_7787_4DDF_6E75_E449_BBAB_9C05_236D_3CF9_4A2C_5EA3_D8C5_F0BF_9389_4ABE_1CE4_C095_8016_DA5A_DBC8_8D90_6374_EEA5_66A5_3163_26A3_EA78; 
  parameter [511:0] ECC_MASK_CRC08 = 512'h2A17_FABB_7E62_88D5_A94B_E104_BBC3_A6EF_B73A_F224_DDD5_CE02_91B6_9E7C_A516_2F51_EC62_F85F_C9C4_A55F_0E72_604A_C00B_6D2D_6DE4_46C8_31BA_7752_B352_98B1_9351_F53C; 
  parameter [511:0] ECC_MASK_CRC07 = 512'h150B_FD5D_BF31_446A_D4A5_F082_5DE1_D377_DB9D_7912_6EEA_E701_48DB_4F3E_528B_17A8_F631_7C2F_E4E2_52AF_8739_3025_6005_B696_B6F2_2364_18DD_3BA9_59A9_4C58_C9A8_FA9E; 
  parameter [511:0] ECC_MASK_CRC06 = 512'h8A85_FEAE_DF98_A235_6A52_F841_2EF0_E9BB_EDCE_BC89_3775_7380_A46D_A79F_2945_8BD4_7B18_BE17_F271_2957_C39C_9812_B002_DB4B_5B79_11B2_0C6E_9DD4_ACD4_A62C_64D4_7D4F; 
  parameter [511:0] ECC_MASK_CRC05 = 512'hAADE_26AE_AB77_E920_8BAD_D55C_40D6_AECE_0C0C_5FFC_C09A_F38C_FC28_AA16_E3F1_98CB_E1F3_8261_C1C8_AADC_143B_6625_3B6C_DDF9_94C4_62E9_CB67_AE33_CD6C_C0C2_4601_1A96; 
  parameter [511:0] ECC_MASK_CRC04 = 512'hD56F_1357_55BB_F490_45D6_EAAE_206B_5767_0606_2FFE_604D_79C6_7E14_550B_71F8_CC65_F0F9_C130_E0E4_556E_0A1D_B312_9DB6_6EFC_CA62_3174_E5B3_D719_E6B6_6061_2300_8D4B; 
  parameter [511:0] ECC_MASK_CRC03 = 512'h852B_5052_6E66_4272_1C6F_DC2B_C79B_71A0_79E8_1647_6B06_F6AF_9114_535C_CFAF_3B13_2403_3DF2_4882_14C0_F0FB_F3A5_2DB6_8722_5C49_F28A_BF89_0B55_685D_A3E4_E5EB_6294; 
  parameter [511:0] ECC_MASK_CRC02 = 512'hC295_A829_3733_2139_0E37_EE15_E3CD_B8D0_3CF4_0B23_B583_7B57_C88A_29AE_67D7_9D89_9201_9EF9_2441_0A60_787D_F9D2_96DB_4391_2E24_F945_5FC4_85AA_B42E_D1F2_72F5_B14A; 
  parameter [511:0] ECC_MASK_CRC01 = 512'h614A_D414_9B99_909C_871B_F70A_F1E6_DC68_1E7A_0591_DAC1_BDAB_E445_14D7_33EB_CEC4_C900_CF7C_9220_8530_3C3E_FCE9_4B6D_A1C8_9712_7CA2_AFE2_42D5_5A17_68F9_397A_D8A5; 
  parameter [511:0] ECC_MASK_CRC00 = 512'hDF39_B3F3_8977_7074_7D09_52F9_AF5D_B427_F5D6_0370_B640_9499_5C3C_F3B2_EEA6_BA43_B8FF_BAD4_71E0_7CEF_EBEA_5458_C6DB_60B8_72F1_D461_9AA1_C1B3_360D_27A8_E8D6_4863; 

// CXL Flit ECC Bits
  assign cxl_crc_data_o[15] = ^(cxl_flit_data_i & ECC_MASK_CRC15);
  assign cxl_crc_data_o[14] = ^(cxl_flit_data_i & ECC_MASK_CRC14);
  assign cxl_crc_data_o[13] = ^(cxl_flit_data_i & ECC_MASK_CRC13);
  assign cxl_crc_data_o[12] = ^(cxl_flit_data_i & ECC_MASK_CRC12);
  assign cxl_crc_data_o[11] = ^(cxl_flit_data_i & ECC_MASK_CRC11);
  assign cxl_crc_data_o[10] = ^(cxl_flit_data_i & ECC_MASK_CRC10);
  assign cxl_crc_data_o[ 9] = ^(cxl_flit_data_i & ECC_MASK_CRC09);
  assign cxl_crc_data_o[ 8] = ^(cxl_flit_data_i & ECC_MASK_CRC08);
  assign cxl_crc_data_o[ 7] = ^(cxl_flit_data_i & ECC_MASK_CRC07);
  assign cxl_crc_data_o[ 6] = ^(cxl_flit_data_i & ECC_MASK_CRC06);
  assign cxl_crc_data_o[ 5] = ^(cxl_flit_data_i & ECC_MASK_CRC05);
  assign cxl_crc_data_o[ 4] = ^(cxl_flit_data_i & ECC_MASK_CRC04);
  assign cxl_crc_data_o[ 3] = ^(cxl_flit_data_i & ECC_MASK_CRC03);
  assign cxl_crc_data_o[ 2] = ^(cxl_flit_data_i & ECC_MASK_CRC02);
  assign cxl_crc_data_o[ 1] = ^(cxl_flit_data_i & ECC_MASK_CRC01);
  assign cxl_crc_data_o[ 0] = ^(cxl_flit_data_i & ECC_MASK_CRC00);

endmodule : DWC_cxl_mem_cache_crc 
