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
// ---    $DateTime: 2023/11/28 03:44:34 $
// ---    $Revision: #15 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_cxl_membar0.sv#15 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the CXL upstream and downstream port subsystem components implemented in MEMBAR0 register.
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
 
module cdm_cxl_membar0
  import DWC_cxl_pkg::*;
 #(
     parameter INST          = 0
    ,parameter NCXL_MEMBAR0_CACHE_MEM  = `CXL_RCRB_MEMBAR0_CACHE_MEM_CAP_SIZE + 'd4  // Number of registers in CXL RCRB MEMBAR0 
    ,parameter NCXL_MEMBAR0_ARB_MUX    = `CXL_RCRB_MEMBAR0_ARB_MUX_SIZE        // Number of registers in CXL RCRB MEMBAR0 
)

                        (
// -- Inputs --
  input                                aux_clk,                // Clock
  input                                non_sticky_rst_n,       // Reset non_sticky register only
  input                                sticky_rst_n,           // Reset sticky register only
  input   [31:0]                       lbc_cdm_data,
  input                                lbc_cdm_dbi,
  input                                dbi_ro_wr_en,
  input   [3:0]                        cxl_mbar0_write_pulse,
  input   [NCXL_MEMBAR0_CACHE_MEM-1:0] cxl_mbar0_cache_mem_reg_id,
  input   [NCXL_MEMBAR0_ARB_MUX-1:0]   cxl_mbar0_arb_mux_reg_id,
  input                                upstream_port,
  input                                cxl2p0_enabled,

  //CXL RAS Capability Structure Registers
  //--Signals for RAS Uncorrectable Error Status Registers
  input mbar0_ras_unc_cache_data_parity,        //Internal Data Parity error on CXL cache        
  input mbar0_ras_unc_cache_addr_parity,        //Internal Address Parity error on CXL cache     
  input mbar0_ras_unc_cache_be_parity,          //Internal Byte Enable Parity error on CXL cache
  input mbar0_ras_unc_cache_data_ecc,           //Internal Data Ecc error on CXL cache 
  input mbar0_ras_unc_mem_data_parity,          //Internal Data Parity error on CXL mem 
  input mbar0_ras_unc_mem_addr_parity,          //Internal Address Parity error on CXL mem 
  input mbar0_ras_unc_mem_be_parity,            //Internal Byte Enable Parity error on CXL mem     
  input mbar0_ras_unc_mem_data_ecc,             //Internal Data Ecc error on CXL mem 
  input mbar0_ras_unc_reinit_threshold,         //REINIT Threshold Hit
  input mbar0_ras_unc_rsvd_encoding_violation,  //Received unrecognized encoding 
  input mbar0_ras_unc_poison_received,          //Received Poison from the peer
  input mbar0_ras_unc_receiver_overflow,        //First 3 bits of Header Log determine which buffer had the overflow 
  input mbar0_ras_unc_internal_error,
  input mbar0_ras_unc_cxl_ide_tx_error,         
  input mbar0_ras_unc_cxl_ide_rx_error,
  //--Signals for RAS Correctable Error Status Register
  input mbar0_ras_corr_cache_data_ecc,          //Internal Data Ecc error on CXL cache 
  input mbar0_ras_corr_mem_data_ecc,            //Internal Data Ecc error on CXL mem   
  input mbar0_ras_corr_crc_threshold,           //CRC Threshold Hit
  input mbar0_ras_corr_retry_threshold,         //Retry Threshold Hit  
  input mbar0_ras_corr_cache_poison_received,   //Received Poison from the peer on CXL cache  
  input mbar0_ras_corr_mem_poison_received,     //Received Poison from the peer on CXL mem  
  input mbar0_ras_corr_physical_layer_error,    //Received error indication from Physical Layer  
  //--Signals for RAS Error Capabilities and Control Register
  //mbar0_ras_mul_header_rec_cap,         //I
  //--Signals for RAS Header Log Register
  input  [31:0] mbar0_ras_header_log_reg0,              //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg1,              //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg2,              //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg3,              //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg4,              //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg5,              //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg6,              //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg7,              //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg8,              //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg9,              //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg10,             //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg11,             //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg12,             //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg13,             //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg14,             //The information loggged here depends on the type of Uncorrectable Error Status bit recorded
  input  [31:0] mbar0_ras_header_log_reg15,             //The information loggged here depends on the type of Uncorrectable Error Status bit recorded

// -- Outputs --
  //--Signals for RAS Error Capabilities and Control Register
  output [16:0] mbar0_ras_uncorr_error_mask,           // Uncorrectable Error Status Mask register  
  output [16:0] mbar0_ras_uncorr_error_severity,       // Uncorrectable Error Status Severity register 
  output [6:0]  mbar0_ras_corr_error_mask,             // correctable Error Status Mask register
  output        mbar0_ras_poison_enabled,              // This indicates if poison is supported   
  //--Signals for CXL Security Policy Register 
  output [1:0] mbar0_security_device_trust_level,      //0 -> Trusted CXL Device. 1-> Trusted for Device Attached Memory Range Only. 2 -> Untrusted CXl Device  
  
  //Signals for ARB/MUX Registers
  output [3:0] mbar0_arb_mux_cxl_io,                //CXL.io Weighted Round Robin Arbitration Weight
  output [3:0] mbar0_arb_mux_cxl_cache_mem,         //CXL.cache and CXL.mem Weighted Round Robin Arbitration Weight. 
  output       mbar0_arb_mux_pmtimeout_en,          //Arb/Mux PM request ALMP timeout enable, by default enabled. 
  output [1:0] mbar0_arb_mux_pmtimeout_val,         //Arb/Mux PM request ALMP timeout value, default value 2'b0. 
  input        mbar0_arb_mux_pmtimeout_err,         //Arb/Mux PM request ALMP timeout error. 
  input        mbar0_arb_mux_l0ptimeout_err,        //Arb/Mux L0p request ALMP timeout error. 
  output       mbar0_arb_mux_uncorr_err,
//CXL Downstream RCRB MEMBAR0 CXL.CACHE CXL.MEM Registers
  output [31:0]mbar0_cap_header_reg,               //CXL Capability Header Register
  output [31:0]mbar0_ras_cap_header_reg,           //CXL RAS Capability Header Register
  output [31:0]mbar0_security_cap_header_reg,      //CXL Security Capability Header Register
  output [31:0]mbar0_link_cap_header_reg,          //CXL Link Capability Header Register
  output [31:0]cxl_mbar0_reg_data,
  output rcrb_ras_uncorr_error,
  output rcrb_ras_corr_error_level,
  output rcrb_ras_corr_error_pulse,
  output reg [6:0] cxl_mbar0_ras_corr_reg,
  output reg [16:0]cxl_mbar0_ras_uncorr_reg
);

parameter TP    = `TP;                          // Clock to Q delay (simulator insurance)


wire    [7:0]   cxl_mbar0_cache_mem_reg_03, cxl_mbar0_cache_mem_reg_02, cxl_mbar0_cache_mem_reg_01, cxl_mbar0_cache_mem_reg_00;//CXL_Capability_Header        0                     
wire    [7:0]   cxl_mbar0_cache_mem_reg_07, cxl_mbar0_cache_mem_reg_06, cxl_mbar0_cache_mem_reg_05, cxl_mbar0_cache_mem_reg_04;//CXL_RAS_Capability_Pointer   1
wire    [7:0]   cxl_mbar0_cache_mem_reg_11, cxl_mbar0_cache_mem_reg_10, cxl_mbar0_cache_mem_reg_09, cxl_mbar0_cache_mem_reg_08;//CXL_Security_Capability_Pointer 2
wire    [7:0]   cxl_mbar0_cache_mem_reg_15, cxl_mbar0_cache_mem_reg_14, cxl_mbar0_cache_mem_reg_13, cxl_mbar0_cache_mem_reg_12;//CXL_Link_Capability_Pointer 3
wire    [7:0]   cxl_mbar0_cache_mem_reg_19, cxl_mbar0_cache_mem_reg_18, cxl_mbar0_cache_mem_reg_17, cxl_mbar0_cache_mem_reg_16;//Uncorrectable Error Status Register 4
wire    [7:0]   cxl_mbar0_cache_mem_reg_23, cxl_mbar0_cache_mem_reg_22, cxl_mbar0_cache_mem_reg_21, cxl_mbar0_cache_mem_reg_20;//Uncorrectable Error Mask Register 5 
wire    [7:0]   cxl_mbar0_cache_mem_reg_27, cxl_mbar0_cache_mem_reg_26, cxl_mbar0_cache_mem_reg_25, cxl_mbar0_cache_mem_reg_24;//Uncorrectable Error Severity Register 6
wire    [7:0]   cxl_mbar0_cache_mem_reg_31, cxl_mbar0_cache_mem_reg_30, cxl_mbar0_cache_mem_reg_29, cxl_mbar0_cache_mem_reg_28;//Correctable Error Status Register 7
wire    [7:0]   cxl_mbar0_cache_mem_reg_35, cxl_mbar0_cache_mem_reg_34, cxl_mbar0_cache_mem_reg_33, cxl_mbar0_cache_mem_reg_32;//Correctable Error Mask Register 8
wire    [7:0]   cxl_mbar0_cache_mem_reg_39, cxl_mbar0_cache_mem_reg_38, cxl_mbar0_cache_mem_reg_37, cxl_mbar0_cache_mem_reg_36;//Error Capability and Control Register 9
wire    [7:0]   cxl_mbar0_cache_mem_reg_43, cxl_mbar0_cache_mem_reg_42, cxl_mbar0_cache_mem_reg_41, cxl_mbar0_cache_mem_reg_40;//Header Log Register 0 10
wire    [7:0]   cxl_mbar0_cache_mem_reg_47, cxl_mbar0_cache_mem_reg_46, cxl_mbar0_cache_mem_reg_45, cxl_mbar0_cache_mem_reg_44;//Header Log Register 1 11
wire    [7:0]   cxl_mbar0_cache_mem_reg_51, cxl_mbar0_cache_mem_reg_50, cxl_mbar0_cache_mem_reg_49, cxl_mbar0_cache_mem_reg_48;//Header Log Register 2 12
wire    [7:0]   cxl_mbar0_cache_mem_reg_55, cxl_mbar0_cache_mem_reg_54, cxl_mbar0_cache_mem_reg_53, cxl_mbar0_cache_mem_reg_52;//Header Log Register 3 13
wire    [7:0]   cxl_mbar0_cache_mem_reg_59, cxl_mbar0_cache_mem_reg_58, cxl_mbar0_cache_mem_reg_57, cxl_mbar0_cache_mem_reg_56;//Header Log Register 4 14
wire    [7:0]   cxl_mbar0_cache_mem_reg_63, cxl_mbar0_cache_mem_reg_62, cxl_mbar0_cache_mem_reg_61, cxl_mbar0_cache_mem_reg_60;//Header Log Register 5 15
wire    [7:0]   cxl_mbar0_cache_mem_reg_67, cxl_mbar0_cache_mem_reg_66, cxl_mbar0_cache_mem_reg_65, cxl_mbar0_cache_mem_reg_64;//Header Log Register 6 16
wire    [7:0]   cxl_mbar0_cache_mem_reg_71, cxl_mbar0_cache_mem_reg_70, cxl_mbar0_cache_mem_reg_69, cxl_mbar0_cache_mem_reg_68;//Header Log Register 7 17
wire    [7:0]   cxl_mbar0_cache_mem_reg_75, cxl_mbar0_cache_mem_reg_74, cxl_mbar0_cache_mem_reg_73, cxl_mbar0_cache_mem_reg_72;//Header Log Register 8 18
wire    [7:0]   cxl_mbar0_cache_mem_reg_79, cxl_mbar0_cache_mem_reg_78, cxl_mbar0_cache_mem_reg_77, cxl_mbar0_cache_mem_reg_76;//Header Log Register 9 19
wire    [7:0]   cxl_mbar0_cache_mem_reg_83, cxl_mbar0_cache_mem_reg_82, cxl_mbar0_cache_mem_reg_81, cxl_mbar0_cache_mem_reg_80;//Header Log Register 10 20
wire    [7:0]   cxl_mbar0_cache_mem_reg_87, cxl_mbar0_cache_mem_reg_86, cxl_mbar0_cache_mem_reg_85, cxl_mbar0_cache_mem_reg_84;//Header Log Register 11 21
wire    [7:0]   cxl_mbar0_cache_mem_reg_91, cxl_mbar0_cache_mem_reg_90, cxl_mbar0_cache_mem_reg_89, cxl_mbar0_cache_mem_reg_88;//Header Log Register 12 22
wire    [7:0]   cxl_mbar0_cache_mem_reg_95, cxl_mbar0_cache_mem_reg_94, cxl_mbar0_cache_mem_reg_93, cxl_mbar0_cache_mem_reg_92;//Header Log Register 13 23
wire    [7:0]   cxl_mbar0_cache_mem_reg_99, cxl_mbar0_cache_mem_reg_98, cxl_mbar0_cache_mem_reg_97, cxl_mbar0_cache_mem_reg_96;//Header Log Register 14 24
wire    [7:0]   cxl_mbar0_cache_mem_reg_103, cxl_mbar0_cache_mem_reg_102, cxl_mbar0_cache_mem_reg_101, cxl_mbar0_cache_mem_reg_100;//Header Log Register 15 25
wire    [7:0]   cxl_mbar0_cache_mem_reg_107, cxl_mbar0_cache_mem_reg_106, cxl_mbar0_cache_mem_reg_105, cxl_mbar0_cache_mem_reg_104;//CXL Security Policy Register 26
wire    [7:0]   cxl_mbar0_cache_mem_reg_111, cxl_mbar0_cache_mem_reg_110, cxl_mbar0_cache_mem_reg_109, cxl_mbar0_cache_mem_reg_108;//ARB/MUX Arbitration Control Register for CXL.io 
wire    [7:0]   cxl_mbar0_cache_mem_reg_115, cxl_mbar0_cache_mem_reg_114, cxl_mbar0_cache_mem_reg_113, cxl_mbar0_cache_mem_reg_112;//ARB/MUX Arbitration Control Register for CXL.cache and CXL.mem
wire    [7:0]   cxl_mbar0_cache_mem_reg_119, cxl_mbar0_cache_mem_reg_118, cxl_mbar0_cache_mem_reg_117, cxl_mbar0_cache_mem_reg_116;//ARB/MUX Control Register for PMTimeout En&Val
wire    [7:0]   cxl_mbar0_cache_mem_reg_123, cxl_mbar0_cache_mem_reg_122, cxl_mbar0_cache_mem_reg_121, cxl_mbar0_cache_mem_reg_120;//ARB/MUX Uncorrectable Error Status Register
wire    [7:0]   cxl_mbar0_cache_mem_reg_127, cxl_mbar0_cache_mem_reg_126, cxl_mbar0_cache_mem_reg_125, cxl_mbar0_cache_mem_reg_124;//ARB/MUX Uncorrectable Error Mask Register

wire            int_lbc_cdm_dbi;
assign          int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
//CXL Upstream and Downstream Port Subsystem Component Registers - CXL.cache and CXL.mem
//B = MEMBAR0+4K
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL_Capability_Header Register
// -----------------------------------------------------------------------------
// cxl_mbar0_cache_mem_reg_id     - 0
// PCIE Offset      - `CXL_MEMBAR0_CACHE_MEM_PTR
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_03, cxl_mbar0_cache_mem_reg_02, cxl_mbar0_cache_mem_reg_01, cxl_mbar0_cache_mem_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cxl_mbar0_cap_id;             // CXL MEMBAR0 Cache Mem Capability ID
reg [3:0]   cxl_mbar0_cap_ver;            // CXL version number of the CXL_Capability structure 
reg [3:0]   cxl_mbar0_cache_mem_ver;      // CXL version of Cache Mem 
reg [7:0]   cxl_mbar0_cap_array_size;     // number of elements present in the CXL_Capability array
reg         cap_array_size_wr_ptr_updated;



assign cxl_mbar0_cache_mem_reg_00 = cxl_mbar0_cap_id[7:0];
assign cxl_mbar0_cache_mem_reg_01 = cxl_mbar0_cap_id[15:8];
assign cxl_mbar0_cache_mem_reg_02 = {cxl_mbar0_cache_mem_ver, cxl_mbar0_cap_ver};
assign cxl_mbar0_cache_mem_reg_03 = cxl_mbar0_cap_array_size;
assign mbar0_cap_header_reg = {cxl_mbar0_cache_mem_reg_03, cxl_mbar0_cache_mem_reg_02, cxl_mbar0_cache_mem_reg_01, cxl_mbar0_cache_mem_reg_00};
always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_mbar0_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cxl_mbar0_cap_id         <= #TP `CXL_RCRB_MEMBAR0_CAP_ID;            // CXL Capability ID  
        cxl_mbar0_cap_ver        <= #TP `CXL_RCRB_MEMBAR0_CAP_VER;           // CXL Capability version  
        cxl_mbar0_cache_mem_ver  <= #TP `CXL_RCRB_MEMBAR0_CACHE_MEM_VER;     // CXL Mem Cache version  
    end else begin
        // Read-Only registers, but writable through DBI
        cxl_mbar0_cap_id[7:0]    <= #TP (cxl_mbar0_cache_mem_reg_id[0] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cxl_mbar0_cap_id[7:0];
        cxl_mbar0_cap_id[15:8]   <= #TP (cxl_mbar0_cache_mem_reg_id[0] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cxl_mbar0_cap_id[15:8];
        cxl_mbar0_cap_ver        <= #TP (cxl_mbar0_cache_mem_reg_id[0] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cxl_mbar0_cap_ver;
        cxl_mbar0_cache_mem_ver  <= #TP (cxl_mbar0_cache_mem_reg_id[0] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:20] : cxl_mbar0_cache_mem_ver;
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cxl_mbar0_cap_array_size <= #TP `CX_CXL_MBAR0_CAP_ARRAY_SIZE;// CXL Capability Array Size 
    end else if (cxl_mbar0_cache_mem_reg_id[0] & int_lbc_cdm_dbi) begin
        cxl_mbar0_cap_array_size <= #TP cxl_mbar0_write_pulse[3] ? lbc_cdm_data[31:24] : cxl_mbar0_cap_array_size;
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cap_array_size_wr_ptr_updated <= #TP 1'b0;  
    end else if (cxl_mbar0_cache_mem_reg_id[0] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) begin
        cap_array_size_wr_ptr_updated <= #TP 1'b1;     
    end
end


// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL_RAS_Capability_Header Register
// -----------------------------------------------------------------------------
// cxl_mbar0_cache_mem_reg_id     - 1
// PCIE Offset      - `CXL_MEMBAR0_CACHE_MEM_PTR + 04h
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_07, cxl_mbar0_cache_mem_reg_06, cxl_mbar0_cache_mem_reg_05, cxl_mbar0_cache_mem_reg_04
// -----------------------------------------------------------------------------

reg [15:0]  cxl_mbar0_ras_cap_id;             // CXL MEMBAR0 RAS Capability ID
reg [3:0]   cxl_mbar0_ras_cap_ver;            // CXL version number of the CXL_RAS_Capability structure 
//reg [11:0]  cxl_mbar0_ras_cap_ptr;            // offset of CXL_RAS_Capability relative to beginning of CXL_Capability_Header
wire [11:0] cxl_mbar0_ras_cap_ptr;            // offset of CXL_RAS_Capability relative to beginning of CXL_Capability_Header
assign cxl_mbar0_ras_cap_ptr = `CXL_RCRB_MEMBAR0_RAS_CAP_PTR;

assign cxl_mbar0_cache_mem_reg_04 = cxl_mbar0_ras_cap_id[7:0];
assign cxl_mbar0_cache_mem_reg_05 = cxl_mbar0_ras_cap_id[15:8];
assign cxl_mbar0_cache_mem_reg_06 = {cxl_mbar0_ras_cap_ptr[3:0], cxl_mbar0_ras_cap_ver};
assign cxl_mbar0_cache_mem_reg_07 = cxl_mbar0_ras_cap_ptr[11:4];
assign mbar0_ras_cap_header_reg = {cxl_mbar0_cache_mem_reg_07, cxl_mbar0_cache_mem_reg_06, cxl_mbar0_cache_mem_reg_05, cxl_mbar0_cache_mem_reg_04};

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_mbar0_ras_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cxl_mbar0_ras_cap_id     <= #TP `CXL_RCRB_MEMBAR0_RAS_CAP_ID;      // CXL MEMBAR0 RAS Capability ID  
        cxl_mbar0_ras_cap_ver    <= #TP `CXL_RCRB_MEMBAR0_RAS_CAP_VER;     // CXL RAS Capability version  
//        cxl_mbar0_ras_cap_ptr    <= #TP `CXL_RCRB_MEMBAR0_RAS_CAP_PTR;     // CXL RAS Capability offset  
    end else begin
        // Read-Only registers, but writable through DBI
        cxl_mbar0_ras_cap_id[7:0]    <= #TP (cxl_mbar0_cache_mem_reg_id[1] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cxl_mbar0_ras_cap_id[7:0];
        cxl_mbar0_ras_cap_id[15:8]   <= #TP (cxl_mbar0_cache_mem_reg_id[1] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cxl_mbar0_ras_cap_id[15:8];
        cxl_mbar0_ras_cap_ver        <= #TP (cxl_mbar0_cache_mem_reg_id[1] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cxl_mbar0_ras_cap_ver;
//        cxl_mbar0_ras_cap_ptr[3:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[1] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:20] : cxl_mbar0_ras_cap_ptr[3:0];
//        cxl_mbar0_ras_cap_ptr[11:4]  <= #TP (cxl_mbar0_cache_mem_reg_id[1] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cxl_mbar0_ras_cap_ptr[11:4];
    end
end


// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL_Security_Capability_Header Register
// -----------------------------------------------------------------------------
// cxl_mbar0_cache_mem_reg_id     - 2
// PCIE Offset      - `CXL_MEMBAR0_CACHE_MEM_PTR + 08h
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_11, cxl_mbar0_cache_mem_reg_10, cxl_mbar0_cache_mem_reg_09, cxl_mbar0_cache_mem_reg_08
// -----------------------------------------------------------------------------
reg [15:0]  cxl_mbar0_sec_cap_id;             // CXL MEMBAR0 Security Capability ID
reg [3:0]   cxl_mbar0_sec_cap_ver;            // CXL version number of the CXL_Security_Capability structure 
//reg [11:0]  cxl_mbar0_sec_cap_ptr;            // offset of CXL_Security_Capability relative to beginning of CXL_Capability_Header
wire [11:0] cxl_mbar0_sec_cap_ptr;            // offset of CXL_Security_Capability relative to beginning of CXL_Capability_Header
assign cxl_mbar0_sec_cap_ptr      = `CXL_RCRB_MEMBAR0_SEC_CAP_PTR;

assign cxl_mbar0_cache_mem_reg_08 = cxl_mbar0_sec_cap_id[7:0];
assign cxl_mbar0_cache_mem_reg_09 = cxl_mbar0_sec_cap_id[15:8];
assign cxl_mbar0_cache_mem_reg_10 = {cxl_mbar0_sec_cap_ptr[3:0], cxl_mbar0_sec_cap_ver};
assign cxl_mbar0_cache_mem_reg_11 = cxl_mbar0_sec_cap_ptr[11:4];
assign mbar0_security_cap_header_reg = {cxl_mbar0_cache_mem_reg_11, cxl_mbar0_cache_mem_reg_10, cxl_mbar0_cache_mem_reg_09, cxl_mbar0_cache_mem_reg_08};

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_mbar0_sec_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cxl_mbar0_sec_cap_id     <= #TP `CXL_RCRB_MEMBAR0_SEC_CAP_ID;      // CXL MEMBAR0 Security Capability ID  
        cxl_mbar0_sec_cap_ver    <= #TP `CXL_RCRB_MEMBAR0_SEC_CAP_VER;     // CXL Security Capability version  
        //cxl_mbar0_sec_cap_ptr    <= #TP `CXL_RCRB_MEMBAR0_SEC_CAP_PTR;     // CXL Security Capability offset  
    end else begin
        // Read-Only registers, but writable through DBI
        cxl_mbar0_sec_cap_id[7:0]    <= #TP (cxl_mbar0_cache_mem_reg_id[2] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cxl_mbar0_sec_cap_id[7:0];
        cxl_mbar0_sec_cap_id[15:8]   <= #TP (cxl_mbar0_cache_mem_reg_id[2] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cxl_mbar0_sec_cap_id[15:8];
        cxl_mbar0_sec_cap_ver        <= #TP (cxl_mbar0_cache_mem_reg_id[2] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cxl_mbar0_sec_cap_ver;
        //cxl_mbar0_sec_cap_ptr[3:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[2] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:20] : cxl_mbar0_sec_cap_ptr[3:0];
        //cxl_mbar0_sec_cap_ptr[11:4]  <= #TP (cxl_mbar0_cache_mem_reg_id[2] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cxl_mbar0_sec_cap_ptr[11:4];
    end
end
    
// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL_Link_Capability_Header Register
// -----------------------------------------------------------------------------
// cxl_mbar0_cache_mem_reg_id     - 3
// PCIE Offset      - `CXL_MEMBAR0_CACHE_MEM_PTR + 0Ch
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_15, cxl_mbar0_cache_mem_reg_14, cxl_mbar0_cache_mem_reg_13, cxl_mbar0_cache_mem_reg_12
// -----------------------------------------------------------------------------
reg [15:0]  cxl_mbar0_link_cap_id;             // CXL MEMBAR0 Link Capability ID
reg [3:0]   cxl_mbar0_link_cap_ver;            // CXL version number of the CXL_Link_Capability structure 
//reg [11:0]  cxl_mbar0_link_cap_ptr;            // offset of CXL_Link_Capability relative to beginning of CXL_Capability_Header
wire [11:0]  cxl_mbar0_link_cap_ptr;            // offset of CXL_Link_Capability relative to beginning of CXL_Capability_Header
assign cxl_mbar0_link_cap_ptr = `CXL_RCRB_MEMBAR0_LINK_CAP_PTR;

assign cxl_mbar0_cache_mem_reg_12 = cxl_mbar0_link_cap_id[7:0];
assign cxl_mbar0_cache_mem_reg_13 = cxl_mbar0_link_cap_id[15:8];
assign cxl_mbar0_cache_mem_reg_14 = {cxl_mbar0_link_cap_ptr[3:0], cxl_mbar0_link_cap_ver};
assign cxl_mbar0_cache_mem_reg_15 = cxl_mbar0_link_cap_ptr[11:4];
assign mbar0_link_cap_header_reg = {cxl_mbar0_cache_mem_reg_15, cxl_mbar0_cache_mem_reg_14, cxl_mbar0_cache_mem_reg_13, cxl_mbar0_cache_mem_reg_12};

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_mbar0_link_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cxl_mbar0_link_cap_id     <= #TP `CXL_RCRB_MEMBAR0_LINK_CAP_ID;      // CXL MEMBAR0 Link Capability ID  
        cxl_mbar0_link_cap_ver    <= #TP `CXL_RCRB_MEMBAR0_LINK_CAP_VER;     // CXL Link Capability version  
        //cxl_mbar0_link_cap_ptr    <= #TP `CXL_RCRB_MEMBAR0_LINK_CAP_PTR;     // CXL Link Capability offset  
    end else begin
        // Read-Only registers, but writable through DBI
        cxl_mbar0_link_cap_id[7:0]    <= #TP (cxl_mbar0_cache_mem_reg_id[3] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cxl_mbar0_link_cap_id[7:0];
        cxl_mbar0_link_cap_id[15:8]   <= #TP (cxl_mbar0_cache_mem_reg_id[3] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cxl_mbar0_link_cap_id[15:8];
        cxl_mbar0_link_cap_ver        <= #TP (cxl_mbar0_cache_mem_reg_id[3] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cxl_mbar0_link_cap_ver;
        //cxl_mbar0_link_cap_ptr[3:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[3] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:20] : cxl_mbar0_link_cap_ptr[3:0];
        //cxl_mbar0_link_cap_ptr[11:4]  <= #TP (cxl_mbar0_cache_mem_reg_id[3] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cxl_mbar0_link_cap_ptr[11:4];
    end
end

// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL RAS Capability Structure - Uncorrectable Error Status Register
// -----------------------------------------------------------------------------
// cxl_mbar0_cache_mem_reg_id     - 4
// PCIE Offset      - `CXL_RCRB_MEMBAR0_RAS_CAP_PTR 
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_19, cxl_mbar0_cache_mem_reg_18, cxl_mbar0_cache_mem_reg_17, cxl_mbar0_cache_mem_reg_16
// -----------------------------------------------------------------------------
logic [16:0] cxl_mbar0_ras_uncorr_bus;
logic [16:0] cxl_mbar0_ras_uncorr_ena;

assign cxl_mbar0_ras_uncorr_bus = { mbar0_ras_unc_cxl_ide_rx_error, 
                                    mbar0_ras_unc_cxl_ide_tx_error, 
                                    mbar0_ras_unc_internal_error, 
                                    2'd0, 
                                    mbar0_ras_unc_receiver_overflow, 
                                    mbar0_ras_unc_poison_received, 
                                    mbar0_ras_unc_rsvd_encoding_violation, 
                                    mbar0_ras_unc_reinit_threshold, 
                                    mbar0_ras_unc_mem_data_ecc, 
                                    mbar0_ras_unc_mem_be_parity, 
                                    mbar0_ras_unc_mem_addr_parity, 
                                    mbar0_ras_unc_mem_data_parity, 
                                    mbar0_ras_unc_cache_data_ecc, 
                                    mbar0_ras_unc_cache_be_parity, 
                                    mbar0_ras_unc_cache_addr_parity,
                                    mbar0_ras_unc_cache_data_parity };

assign cxl_mbar0_ras_uncorr_ena = 17'h1_CF_FF;
                                          
assign {cxl_mbar0_cache_mem_reg_19, cxl_mbar0_cache_mem_reg_18, cxl_mbar0_cache_mem_reg_17, cxl_mbar0_cache_mem_reg_16} = {15'd0, cxl_mbar0_ras_uncorr_reg};

always @(posedge aux_clk or negedge sticky_rst_n)
begin : cxl_mbar0_uncorr_err_status_PROC
    if (!sticky_rst_n) begin
        cxl_mbar0_ras_uncorr_reg <= #TP '0;
    end 
    else begin 
        cxl_mbar0_ras_uncorr_reg <= #TP cxl_mbar0_ras_uncorr_ena & ((cxl_mbar0_ras_uncorr_reg & { //(cxl_mbar0_cache_mem_reg_id[4] & cxl_mbar0_write_pulse[3]) ? ~lbc_cdm_data[31:24] : 8'hFF ,
                                                                                                  (cxl_mbar0_cache_mem_reg_id[4] & cxl_mbar0_write_pulse[2]) ? ~lbc_cdm_data[16:16] : 1'h1 ,
                                                                                                  (cxl_mbar0_cache_mem_reg_id[4] & cxl_mbar0_write_pulse[1]) ? ~lbc_cdm_data[15: 8] : 8'hFF ,
                                                                                                  (cxl_mbar0_cache_mem_reg_id[4] & cxl_mbar0_write_pulse[0]) ? ~lbc_cdm_data[ 7: 0] : 8'hFF }) | cxl_mbar0_ras_uncorr_bus);
    end
end
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL RAS Capability Structure - Uncorrectable Error Mask Register
// -----------------------------------------------------------------------------
// cxl_mbar0_cache_mem_reg_id     - 5
// PCIE Offset      - `CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 04h
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_23, cxl_mbar0_cache_mem_reg_22, cxl_mbar0_cache_mem_reg_21, cxl_mbar0_cache_mem_reg_20
// -----------------------------------------------------------------------------
reg [16:0] cxl_mbar0_ras_uncorr_err_mask_reg;

assign mbar0_ras_uncorr_error_mask = cxl_mbar0_ras_uncorr_err_mask_reg;

assign {cxl_mbar0_cache_mem_reg_23, cxl_mbar0_cache_mem_reg_22, cxl_mbar0_cache_mem_reg_21, cxl_mbar0_cache_mem_reg_20} = {15'd0, cxl_mbar0_ras_uncorr_err_mask_reg};

always @(posedge aux_clk or negedge sticky_rst_n)
begin : cxl_mbar0_uncorr_err_mask_PROC
    if (!sticky_rst_n) begin
        cxl_mbar0_ras_uncorr_err_mask_reg <= #TP 17'h1_CFFF;
    end 
    else begin 
        cxl_mbar0_ras_uncorr_err_mask_reg [7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[5] & cxl_mbar0_write_pulse[0]) ? lbc_cdm_data[7:0] : cxl_mbar0_ras_uncorr_err_mask_reg [7:0];       
        cxl_mbar0_ras_uncorr_err_mask_reg [11:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[5] & cxl_mbar0_write_pulse[1]) ? lbc_cdm_data[11:8] : cxl_mbar0_ras_uncorr_err_mask_reg [11:8];
        cxl_mbar0_ras_uncorr_err_mask_reg [13:12] <= #TP 2'b00;
        cxl_mbar0_ras_uncorr_err_mask_reg [15:14] <= #TP (cxl_mbar0_cache_mem_reg_id[5] & cxl_mbar0_write_pulse[1]) ? lbc_cdm_data[15:14] : cxl_mbar0_ras_uncorr_err_mask_reg [15:14];
        cxl_mbar0_ras_uncorr_err_mask_reg [16]    <= #TP (cxl_mbar0_cache_mem_reg_id[5] & cxl_mbar0_write_pulse[2]) ? lbc_cdm_data[16] : cxl_mbar0_ras_uncorr_err_mask_reg [16];
    end
end

// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL RAS Capability Structure - Uncorrectable Error Severity Register
// -----------------------------------------------------------------------------
// cxl_mbar0_cache_mem_reg_id     - 6
// PCIE Offset      - `CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 08h
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_27, cxl_mbar0_cache_mem_reg_26, cxl_mbar0_cache_mem_reg_25, cxl_mbar0_cache_mem_reg_24
// -----------------------------------------------------------------------------
reg [16:0] cxl_mbar0_ras_uncorr_err_severity_reg;
         
assign mbar0_ras_uncorr_error_severity = cxl_mbar0_ras_uncorr_err_severity_reg;  
                                         
assign {cxl_mbar0_cache_mem_reg_27, cxl_mbar0_cache_mem_reg_26, cxl_mbar0_cache_mem_reg_25, cxl_mbar0_cache_mem_reg_24} = {15'd0, cxl_mbar0_ras_uncorr_err_severity_reg};

always @(posedge aux_clk or negedge sticky_rst_n)
begin : cxl_mbar0_uncorr_err_severity_PROC
    if (!sticky_rst_n) begin
        cxl_mbar0_ras_uncorr_err_severity_reg <= #TP 17'h1_CFFF;  
    end 
    else begin 
        cxl_mbar0_ras_uncorr_err_severity_reg [7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[6] & cxl_mbar0_write_pulse[0]) ? lbc_cdm_data[7:0] : cxl_mbar0_ras_uncorr_err_severity_reg [7:0];
        cxl_mbar0_ras_uncorr_err_severity_reg [11:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[6] & cxl_mbar0_write_pulse[1]) ? lbc_cdm_data[11:8] : cxl_mbar0_ras_uncorr_err_severity_reg [11:8];
        cxl_mbar0_ras_uncorr_err_severity_reg [13:12] <= #TP 2'b00;
        cxl_mbar0_ras_uncorr_err_severity_reg [15:14] <= #TP (cxl_mbar0_cache_mem_reg_id[6] & cxl_mbar0_write_pulse[1]) ? lbc_cdm_data[15:14] : cxl_mbar0_ras_uncorr_err_severity_reg [15:14];
        cxl_mbar0_ras_uncorr_err_severity_reg [16]    <= #TP (cxl_mbar0_cache_mem_reg_id[6] & cxl_mbar0_write_pulse[2]) ? lbc_cdm_data[16] : cxl_mbar0_ras_uncorr_err_severity_reg [16];
    end
end

// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL RAS Capability Structure - Correctable Error Status Register
// -----------------------------------------------------------------------------
// cxl_mbar0_cache_mem_reg_id     - 7
// PCIE Offset      - `CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 0Ch
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_31, cxl_mbar0_cache_mem_reg_30, cxl_mbar0_cache_mem_reg_29, cxl_mbar0_cache_mem_reg_28
// -----------------------------------------------------------------------------
logic [6:0] cxl_mbar0_ras_corr_bus;
logic [6:0] cxl_mbar0_ras_corr_ena;

assign cxl_mbar0_ras_corr_bus = { mbar0_ras_corr_physical_layer_error,
                                  mbar0_ras_corr_mem_poison_received,
                                  mbar0_ras_corr_cache_poison_received,
                                  mbar0_ras_corr_retry_threshold,
                                  mbar0_ras_corr_crc_threshold,
                                  mbar0_ras_corr_mem_data_ecc,
                                  mbar0_ras_corr_cache_data_ecc };

assign cxl_mbar0_ras_corr_ena = 7'h7F;
                                          
assign {cxl_mbar0_cache_mem_reg_31, cxl_mbar0_cache_mem_reg_30, cxl_mbar0_cache_mem_reg_29, cxl_mbar0_cache_mem_reg_28} = {25'h0, cxl_mbar0_ras_corr_reg};

always @(posedge aux_clk or negedge sticky_rst_n)
begin : cxl_mbar0_corr_err_status_PROC
    if (!sticky_rst_n) begin
        cxl_mbar0_ras_corr_reg <= #TP '0;
    end 
    else begin 
        cxl_mbar0_ras_corr_reg <= #TP cxl_mbar0_ras_corr_ena & ((cxl_mbar0_ras_corr_reg & { //(cxl_mbar0_cache_mem_reg_id[7] & cxl_mbar0_write_pulse[3]) ? ~lbc_cdm_data[31:24] : 8'hFF ,
                                                                                            //(cxl_mbar0_cache_mem_reg_id[7] & cxl_mbar0_write_pulse[2]) ? ~lbc_cdm_data[23:16] : 8'hFF ,
                                                                                            //(cxl_mbar0_cache_mem_reg_id[7] & cxl_mbar0_write_pulse[1]) ? ~lbc_cdm_data[15: 8] : 8'hFF ,
                                                                                            (cxl_mbar0_cache_mem_reg_id[7] & cxl_mbar0_write_pulse[0]) ? ~lbc_cdm_data[ 6: 0] : 7'h7F }) | cxl_mbar0_ras_corr_bus);
    end
end

// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL RAS Capability Structure - Correctable Error Mask Register
// -----------------------------------------------------------------------------
// cxl_mbar0_cache_mem_reg_id     - 8
// PCIE Offset      - `CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 10h
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_35, cxl_mbar0_cache_mem_reg_34, cxl_mbar0_cache_mem_reg_33, cxl_mbar0_cache_mem_reg_32
// -----------------------------------------------------------------------------
reg [6:0] cxl_mbar0_ras_corr_err_mask_reg;
assign mbar0_ras_corr_error_mask = cxl_mbar0_ras_corr_err_mask_reg;
assign {cxl_mbar0_cache_mem_reg_35, cxl_mbar0_cache_mem_reg_34, cxl_mbar0_cache_mem_reg_33, cxl_mbar0_cache_mem_reg_32} = {25'h0, cxl_mbar0_ras_corr_err_mask_reg};

always @(posedge aux_clk or negedge sticky_rst_n)
begin : cxl_mbar0_corr_err_mask_PROC
    if (!sticky_rst_n) begin
        cxl_mbar0_ras_corr_err_mask_reg      <= #TP 7'h7F; 
    end 
    else begin 
        cxl_mbar0_ras_corr_err_mask_reg           <= #TP  
                                   (cxl_mbar0_cache_mem_reg_id[8] & cxl_mbar0_write_pulse[0]) ? lbc_cdm_data[6:0] : cxl_mbar0_ras_corr_err_mask_reg;

    end
end


// -----------------------------------------------------------------------------
// RCRB RAS Uncorrectable and Correctable Error Indication
// -----------------------------------------------------------------------------
assign rcrb_ras_uncorr_error = |(cxl_mbar0_ras_uncorr_reg & (~cxl_mbar0_ras_uncorr_err_mask_reg));
assign rcrb_ras_corr_error_level   = |(cxl_mbar0_ras_corr_reg & (~cxl_mbar0_ras_corr_err_mask_reg));
assign rcrb_ras_corr_error_pulse   = |(cxl_mbar0_ras_corr_bus & (~cxl_mbar0_ras_corr_err_mask_reg));
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// CXL RAS Uncorrectable Error - First Error detection logic and pointer generator
// -----------------------------------------------------------------------------
logic [16:0] cxl_mbar0_ras_uncorr_err;
logic        first_error;
logic [5:0]  first_error_ptr;

assign cxl_mbar0_ras_uncorr_err = cxl_mbar0_ras_uncorr_bus;

// Indicate first error if error is detected and no bits are set in cxl_mbar0_ras_uncorr_reg
assign first_error = (|cxl_mbar0_ras_uncorr_err) & ~(|cxl_mbar0_ras_uncorr_reg);

always_comb begin
    casez (cxl_mbar0_ras_uncorr_err)
        17'b?_????_????_????_???1 : first_error_ptr = 6'd0;
        17'b?_????_????_????_??10 : first_error_ptr = 6'd1;
        17'b?_????_????_????_?100 : first_error_ptr = 6'd2;
        17'b?_????_????_????_1000 : first_error_ptr = 6'd3;
        17'b?_????_????_???1_0000 : first_error_ptr = 6'd4;
        17'b?_????_????_??10_0000 : first_error_ptr = 6'd5;
        17'b?_????_????_?100_0000 : first_error_ptr = 6'd6;
        17'b?_????_????_1000_0000 : first_error_ptr = 6'd7;
        17'b?_????_???1_0000_0000 : first_error_ptr = 6'd8;
        17'b?_????_??10_0000_0000 : first_error_ptr = 6'd9;
        17'b?_????_?100_0000_0000 : first_error_ptr = 6'd10;
        17'b?_????_1000_0000_0000 : first_error_ptr = 6'd11;
        17'b?_???1_0000_0000_0000 : first_error_ptr = 6'd12;
        17'b?_??10_0000_0000_0000 : first_error_ptr = 6'd13;
        17'b?_?100_0000_0000_0000 : first_error_ptr = 6'd14;
        17'b?_1000_0000_0000_0000 : first_error_ptr = 6'd15;
        17'b1_0000_0000_0000_0000 : first_error_ptr = 6'd16;
        default: first_error_ptr = 6'd0;
    endcase
end
// -----------------------------------------------------------------------------


// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL RAS Capability Structure - Error Capabilities and Control Register
// -----------------------------------------------------------------------------
// cxl_mbar0_cache_mem_reg_id     - 9 
// PCIE Offset      - `CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 14h
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_39, cxl_mbar0_cache_mem_reg_38, cxl_mbar0_cache_mem_reg_37, cxl_mbar0_cache_mem_reg_36
// -----------------------------------------------------------------------------
reg  [5:0]  fe_ptr;
reg         poison_enabled_reg;
reg         mul_hdr_rec_en_reg;

assign {cxl_mbar0_cache_mem_reg_39, cxl_mbar0_cache_mem_reg_38, cxl_mbar0_cache_mem_reg_37, cxl_mbar0_cache_mem_reg_36} = {18'h0, poison_enabled_reg, 3'h0, `RCRB_MUL_HDR_REC_CAP, 3'h0, fe_ptr};
assign mbar0_ras_poison_enabled = poison_enabled_reg;

always @(posedge aux_clk or negedge sticky_rst_n)
begin : cxl_mbar0_err_cap_ctrl_PROC
    if (!sticky_rst_n) begin
        mul_hdr_rec_en_reg          <= #TP `RCRB_MUL_HDR_REC_CAP; 
        poison_enabled_reg          <= #TP 1'b1; 
        fe_ptr                      <= #TP 6'h00;
    end 
    else begin 
        mul_hdr_rec_en_reg          <= #TP (cxl_mbar0_cache_mem_reg_id[9] & cxl_mbar0_write_pulse[1] &  int_lbc_cdm_dbi)  ? lbc_cdm_data[9] : mul_hdr_rec_en_reg;
        fe_ptr                      <= #TP first_error ? first_error_ptr : ((cxl_mbar0_cache_mem_reg_id[9] & cxl_mbar0_write_pulse[0] &  int_lbc_cdm_dbi) ? lbc_cdm_data[5:0] : fe_ptr);
        poison_enabled_reg          <= #TP upstream_port ? 1'b1 : (cxl_mbar0_cache_mem_reg_id[9] & cxl_mbar0_write_pulse[1])  ? lbc_cdm_data[13] : poison_enabled_reg; 

    end
end


// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL RAS Capability Structure - Header Log Registers
// -----------------------------------------------------------------------------
// cxl_mbar0_cache_mem_reg_id     - 10, 11, 12, 13, 14, 15, 16, 17, 
//                                    18, 19, 20, 21, 22, 23, 24, 25
// PCIE Offset      - `CXL_RCRB_MEMBAR0_RAS_CAP_PTR + 18h
// length           - 64 bytes
// Cfig register    - cxl_mbar0_cache_mem_reg_43, cxl_mbar0_cache_mem_reg_42, cxl_mbar0_cache_mem_reg_41, cxl_mbar0_cache_mem_reg_40
//                  - cxl_mbar0_cache_mem_reg_47, cxl_mbar0_cache_mem_reg_46, cxl_mbar0_cache_mem_reg_45, cxl_mbar0_cache_mem_reg_44
//                  - cxl_mbar0_cache_mem_reg_51, cxl_mbar0_cache_mem_reg_50, cxl_mbar0_cache_mem_reg_49, cxl_mbar0_cache_mem_reg_48
//                  - cxl_mbar0_cache_mem_reg_55, cxl_mbar0_cache_mem_reg_54, cxl_mbar0_cache_mem_reg_53, cxl_mbar0_cache_mem_reg_52
//                  - cxl_mbar0_cache_mem_reg_59, cxl_mbar0_cache_mem_reg_58, cxl_mbar0_cache_mem_reg_57, cxl_mbar0_cache_mem_reg_56
//                  - cxl_mbar0_cache_mem_reg_63, cxl_mbar0_cache_mem_reg_62, cxl_mbar0_cache_mem_reg_61, cxl_mbar0_cache_mem_reg_60
//                  - cxl_mbar0_cache_mem_reg_67, cxl_mbar0_cache_mem_reg_66, cxl_mbar0_cache_mem_reg_65, cxl_mbar0_cache_mem_reg_64
//                  - cxl_mbar0_cache_mem_reg_71, cxl_mbar0_cache_mem_reg_70, cxl_mbar0_cache_mem_reg_69, cxl_mbar0_cache_mem_reg_68
//                  - cxl_mbar0_cache_mem_reg_75, cxl_mbar0_cache_mem_reg_74, cxl_mbar0_cache_mem_reg_73, cxl_mbar0_cache_mem_reg_72
//                  - cxl_mbar0_cache_mem_reg_79, cxl_mbar0_cache_mem_reg_78, cxl_mbar0_cache_mem_reg_77, cxl_mbar0_cache_mem_reg_76
//                  - cxl_mbar0_cache_mem_reg_83, cxl_mbar0_cache_mem_reg_82, cxl_mbar0_cache_mem_reg_81, cxl_mbar0_cache_mem_reg_80
//                  - cxl_mbar0_cache_mem_reg_87, cxl_mbar0_cache_mem_reg_86, cxl_mbar0_cache_mem_reg_85, cxl_mbar0_cache_mem_reg_84
//                  - cxl_mbar0_cache_mem_reg_91, cxl_mbar0_cache_mem_reg_90, cxl_mbar0_cache_mem_reg_89, cxl_mbar0_cache_mem_reg_88
//                  - cxl_mbar0_cache_mem_reg_95, cxl_mbar0_cache_mem_reg_94, cxl_mbar0_cache_mem_reg_93, cxl_mbar0_cache_mem_reg_92
//                  - cxl_mbar0_cache_mem_reg_99, cxl_mbar0_cache_mem_reg_98, cxl_mbar0_cache_mem_reg_97, cxl_mbar0_cache_mem_reg_96
//                  - cxl_mbar0_cache_mem_reg_107, cxl_mbar0_cache_mem_reg_102, cxl_mbar0_cache_mem_reg_101, cxl_mbar0_cache_mem_reg_100
// -----------------------------------------------------------------------------

reg  [31:0] header_log_reg0 ;  
reg  [31:0] header_log_reg1 ;  
reg  [31:0] header_log_reg2 ;  
reg  [31:0] header_log_reg3 ;  
reg  [31:0] header_log_reg4 ;  
reg  [31:0] header_log_reg5 ;  
reg  [31:0] header_log_reg6 ;  
reg  [31:0] header_log_reg7 ;  
reg  [31:0] header_log_reg8 ;  
reg  [31:0] header_log_reg9 ;  
reg  [31:0] header_log_reg10;  
reg  [31:0] header_log_reg11;  
reg  [31:0] header_log_reg12;  
reg  [31:0] header_log_reg13;  
reg  [31:0] header_log_reg14;  
reg  [31:0] header_log_reg15; 
assign {cxl_mbar0_cache_mem_reg_43, cxl_mbar0_cache_mem_reg_42, cxl_mbar0_cache_mem_reg_41, cxl_mbar0_cache_mem_reg_40,
        cxl_mbar0_cache_mem_reg_47, cxl_mbar0_cache_mem_reg_46, cxl_mbar0_cache_mem_reg_45, cxl_mbar0_cache_mem_reg_44,
        cxl_mbar0_cache_mem_reg_51, cxl_mbar0_cache_mem_reg_50, cxl_mbar0_cache_mem_reg_49, cxl_mbar0_cache_mem_reg_48,
        cxl_mbar0_cache_mem_reg_55, cxl_mbar0_cache_mem_reg_54, cxl_mbar0_cache_mem_reg_53, cxl_mbar0_cache_mem_reg_52,
        cxl_mbar0_cache_mem_reg_59, cxl_mbar0_cache_mem_reg_58, cxl_mbar0_cache_mem_reg_57, cxl_mbar0_cache_mem_reg_56,
        cxl_mbar0_cache_mem_reg_63, cxl_mbar0_cache_mem_reg_62, cxl_mbar0_cache_mem_reg_61, cxl_mbar0_cache_mem_reg_60,
        cxl_mbar0_cache_mem_reg_67, cxl_mbar0_cache_mem_reg_66, cxl_mbar0_cache_mem_reg_65, cxl_mbar0_cache_mem_reg_64,
        cxl_mbar0_cache_mem_reg_71, cxl_mbar0_cache_mem_reg_70, cxl_mbar0_cache_mem_reg_69, cxl_mbar0_cache_mem_reg_68,
        cxl_mbar0_cache_mem_reg_75, cxl_mbar0_cache_mem_reg_74, cxl_mbar0_cache_mem_reg_73, cxl_mbar0_cache_mem_reg_72,
        cxl_mbar0_cache_mem_reg_79, cxl_mbar0_cache_mem_reg_78, cxl_mbar0_cache_mem_reg_77, cxl_mbar0_cache_mem_reg_76,
        cxl_mbar0_cache_mem_reg_83, cxl_mbar0_cache_mem_reg_82, cxl_mbar0_cache_mem_reg_81, cxl_mbar0_cache_mem_reg_80,
        cxl_mbar0_cache_mem_reg_87, cxl_mbar0_cache_mem_reg_86, cxl_mbar0_cache_mem_reg_85, cxl_mbar0_cache_mem_reg_84,
        cxl_mbar0_cache_mem_reg_91, cxl_mbar0_cache_mem_reg_90, cxl_mbar0_cache_mem_reg_89, cxl_mbar0_cache_mem_reg_88,
        cxl_mbar0_cache_mem_reg_95, cxl_mbar0_cache_mem_reg_94, cxl_mbar0_cache_mem_reg_93, cxl_mbar0_cache_mem_reg_92,
        cxl_mbar0_cache_mem_reg_99, cxl_mbar0_cache_mem_reg_98, cxl_mbar0_cache_mem_reg_97, cxl_mbar0_cache_mem_reg_96,
        cxl_mbar0_cache_mem_reg_103, cxl_mbar0_cache_mem_reg_102, cxl_mbar0_cache_mem_reg_101, cxl_mbar0_cache_mem_reg_100} =
       {header_log_reg0, header_log_reg1, header_log_reg2, header_log_reg3, header_log_reg4, header_log_reg5, header_log_reg6, header_log_reg7,
        header_log_reg8, header_log_reg9, header_log_reg10, header_log_reg11, header_log_reg12, header_log_reg13, header_log_reg14, header_log_reg15};

always @(posedge aux_clk or negedge sticky_rst_n)
begin : cxl_mbar0_header_log_regs_PROC
    if (!sticky_rst_n) begin
        header_log_reg0                  <= #TP 0; 
        header_log_reg1                  <= #TP 0; 
        header_log_reg2                  <= #TP 0; 
        header_log_reg3                  <= #TP 0; 
        header_log_reg4                  <= #TP 0; 
        header_log_reg5                  <= #TP 0; 
        header_log_reg6                  <= #TP 0; 
        header_log_reg7                  <= #TP 0; 
        header_log_reg8                  <= #TP 0; 
        header_log_reg9                  <= #TP 0; 
        header_log_reg10                 <= #TP 0; 
        header_log_reg11                 <= #TP 0; 
        header_log_reg12                 <= #TP 0; 
        header_log_reg13                 <= #TP 0; 
        header_log_reg14                 <= #TP 0; 
        header_log_reg15                 <= #TP 0; 
    end 
    else begin 
        header_log_reg0[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[10] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg0[7:0] : header_log_reg0[7:0];
        header_log_reg0[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[10] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg0[15:8] : header_log_reg0[15:8];
        header_log_reg0[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[10] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg0[23:16] : header_log_reg0[23:16];
        header_log_reg0[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[10] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg0[31:24] : header_log_reg0[31:24];
        header_log_reg1[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[11] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg1[7:0] : header_log_reg1[7:0];
        header_log_reg1[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[11] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg1[15:8] : header_log_reg1[15:8];
        header_log_reg1[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[11] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg1[23:16] : header_log_reg1[23:16];
        header_log_reg1[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[11] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg1[31:24] : header_log_reg1[31:24];
        header_log_reg2[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[12] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg2[7:0] : header_log_reg2[7:0];
        header_log_reg2[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[12] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg2[15:8] : header_log_reg2[15:8];
        header_log_reg2[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[12] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg2[23:16] : header_log_reg2[23:16];
        header_log_reg2[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[12] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg2[31:24] : header_log_reg2[31:24];
        header_log_reg3[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[13] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg3[7:0] : header_log_reg3[7:0];
        header_log_reg3[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[13] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg3[15:8] : header_log_reg3[15:8];
        header_log_reg3[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[13] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg3[23:16] : header_log_reg3[23:16];
        header_log_reg3[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[13] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg3[31:24] : header_log_reg3[31:24];
        header_log_reg4[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[14] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg4[7:0] : header_log_reg4[7:0];
        header_log_reg4[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[14] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg4[15:8] : header_log_reg4[15:8];
        header_log_reg4[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[14] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg4[23:16] : header_log_reg4[23:16];
        header_log_reg4[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[14] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg4[31:24] : header_log_reg4[31:24];
        header_log_reg5[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[15] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg5[7:0] : header_log_reg5[7:0];
        header_log_reg5[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[15] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg5[15:8] : header_log_reg5[15:8];
        header_log_reg5[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[15] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg5[23:16] : header_log_reg5[23:16];
        header_log_reg5[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[15] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg5[31:24] : header_log_reg5[31:24];
        header_log_reg6[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[16] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg6[7:0] : header_log_reg6[7:0];
        header_log_reg6[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[16] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg6[15:8] : header_log_reg6[15:8];
        header_log_reg6[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[16] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg6[23:16] : header_log_reg6[23:16];
        header_log_reg6[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[16] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg6[31:24] : header_log_reg6[31:24];
        header_log_reg7[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[17] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg7[7:0] : header_log_reg7[7:0];
        header_log_reg7[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[17] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg7[15:8] : header_log_reg7[15:8];
        header_log_reg7[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[17] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg7[23:16] : header_log_reg7[23:16];
        header_log_reg7[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[17] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg7[31:24] : header_log_reg7[31:24];
        header_log_reg8[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[18] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg8[7:0] : header_log_reg8[7:0];
        header_log_reg8[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[18] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg8[15:8] : header_log_reg8[15:8];
        header_log_reg8[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[18] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg8[23:16] : header_log_reg8[23:16];
        header_log_reg8[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[18] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg8[31:24] : header_log_reg8[31:24];
        header_log_reg9[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[19] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg9[7:0] : header_log_reg9[7:0];
        header_log_reg9[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[19] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg9[15:8] : header_log_reg9[15:8];
        header_log_reg9[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[19] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg9[23:16] : header_log_reg9[23:16];
        header_log_reg9[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[19] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg9[31:24] : header_log_reg9[31:24];
        header_log_reg10[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[20] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error? mbar0_ras_header_log_reg10[7:0] : header_log_reg10[7:0];
        header_log_reg10[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[20] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg10[15:8] : header_log_reg10[15:8];
        header_log_reg10[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[20] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg10[23:16] : header_log_reg10[23:16];
        header_log_reg10[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[20] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg10[31:24] : header_log_reg10[31:24];
        header_log_reg11[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[21] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg11[7:0] : header_log_reg11[7:0];
        header_log_reg11[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[21] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg11[15:8] : header_log_reg11[15:8];
        header_log_reg11[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[21] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg11[23:16] : header_log_reg11[23:16];
        header_log_reg11[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[21] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg11[31:24] : header_log_reg11[31:24];
        header_log_reg12[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[22] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg12[7:0] : header_log_reg12[7:0];
        header_log_reg12[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[22] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg12[15:8] : header_log_reg12[15:8];
        header_log_reg12[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[22] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg12[23:16] : header_log_reg12[23:16];
        header_log_reg12[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[22] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg12[31:24] : header_log_reg12[31:24];
        header_log_reg13[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[23] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg13[7:0] : header_log_reg13[7:0];
        header_log_reg13[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[23] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg13[15:8] : header_log_reg13[15:8];
        header_log_reg13[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[23] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg13[23:16] : header_log_reg13[23:16];
        header_log_reg13[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[23] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg13[31:24] : header_log_reg13[31:24];
        header_log_reg14[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[24] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg14[7:0] : header_log_reg14[7:0];
        header_log_reg14[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[24] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg14[15:8] : header_log_reg14[15:8];
        header_log_reg14[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[24] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg14[23:16] : header_log_reg14[23:16];
        header_log_reg14[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[24] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg14[31:24] : header_log_reg14[31:24];
        header_log_reg15[7:0]   <= #TP (cxl_mbar0_cache_mem_reg_id[25] & cxl_mbar0_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : 
                                      first_error ? mbar0_ras_header_log_reg15[7:0] : header_log_reg15[7:0];
        header_log_reg15[15:8]  <= #TP (cxl_mbar0_cache_mem_reg_id[25] & cxl_mbar0_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : 
                                      first_error ? mbar0_ras_header_log_reg15[15:8] : header_log_reg15[15:8];
        header_log_reg15[23:16] <= #TP (cxl_mbar0_cache_mem_reg_id[25] & cxl_mbar0_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : 
                                      first_error ? mbar0_ras_header_log_reg15[23:16] : header_log_reg15[23:16];
        header_log_reg15[31:24] <= #TP (cxl_mbar0_cache_mem_reg_id[25] & cxl_mbar0_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : 
                                      first_error ? mbar0_ras_header_log_reg15[31:24] : header_log_reg15[31:24];
    end
end

// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL Security Capability Structure - Security Policy Register
// -----------------------------------------------------------------------------
// cxl_mbar0_cache_mem_reg_id     - 26 
// PCIE Offset      - `CXL_RCRB_MEMBAR0_SEC_CAP_PTR
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_107, cxl_mbar0_cache_mem_reg_106, cxl_mbar0_cache_mem_reg_105, cxl_mbar0_cache_mem_reg_104
// -----------------------------------------------------------------------------
//this register only applies for CXL 1.1 Downstream Port
reg  [1:0] device_trust_level;
assign mbar0_security_device_trust_level = device_trust_level;
assign {cxl_mbar0_cache_mem_reg_107, cxl_mbar0_cache_mem_reg_106, cxl_mbar0_cache_mem_reg_105, cxl_mbar0_cache_mem_reg_104} = {30'h0, device_trust_level};
always @(posedge aux_clk or negedge non_sticky_rst_n) begin : cxl_mbar0_security_policy_reg_PROC
    if (!non_sticky_rst_n) 
       device_trust_level <= #TP 2'h2;
    else
        device_trust_level <= #TP (cxl_mbar0_cache_mem_reg_id[26] & cxl_mbar0_write_pulse[0]) ? lbc_cdm_data[1:0] : device_trust_level;
end


// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL ARB/MUX - ARB/MUX PM Timeout Control Register
// -----------------------------------------------------------------------------
// cxl_mbar0_arb_mux_reg_id     - 2 
// PCIE Offset      - `CXL_MEMBAR0_ARB_MUX_PTR + 000h
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_119, cxl_mbar0_cache_mem_reg_118, cxl_mbar0_cache_mem_reg_117, cxl_mbar0_cache_mem_reg_116
// -----------------------------------------------------------------------------
reg   arb_mux_pmtimeout_en;
reg [1:0] arb_mux_pmtimeout_val;
assign mbar0_arb_mux_pmtimeout_en = arb_mux_pmtimeout_en;
assign mbar0_arb_mux_pmtimeout_val = arb_mux_pmtimeout_val;
always @(posedge aux_clk or negedge non_sticky_rst_n) begin : cxl_mbar0_arb_mux_pmtime_non_sticky_PROC
    if (!non_sticky_rst_n) begin
       arb_mux_pmtimeout_en  <= #TP 1'b1;
       arb_mux_pmtimeout_val  <= #TP '0;
    end else begin
       arb_mux_pmtimeout_en  <= #TP (cxl_mbar0_arb_mux_reg_id[2] & cxl_mbar0_write_pulse[0]) ? lbc_cdm_data[0] : arb_mux_pmtimeout_en;
       arb_mux_pmtimeout_val  <= #TP (cxl_mbar0_arb_mux_reg_id[2] & cxl_mbar0_write_pulse[0]) ? lbc_cdm_data[2:1] : arb_mux_pmtimeout_val;
    end
end


assign {cxl_mbar0_cache_mem_reg_119, cxl_mbar0_cache_mem_reg_118, cxl_mbar0_cache_mem_reg_117, cxl_mbar0_cache_mem_reg_116} = {29'b0, arb_mux_pmtimeout_val, arb_mux_pmtimeout_en};


// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL ARB/MUX - ARB/MUX Uncorrectable Error Status Register
// -----------------------------------------------------------------------------
// cxl_mbar0_arb_mux_reg_id     - 3 
// PCIE Offset      - `CXL_MEMBAR0_ARB_MUX_PTR + 004h
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_123, cxl_mbar0_cache_mem_reg_122, cxl_mbar0_cache_mem_reg_121, cxl_mbar0_cache_mem_reg_120
// -----------------------------------------------------------------------------
reg    arb_mux_pmtimeout_err_reg;
reg    arb_mux_l0ptimeout_err_reg;
wire   arb_mux_pmtimeout_err_clr;
wire   arb_mux_l0ptimeout_err_clr;
assign arb_mux_pmtimeout_err_clr   = (cxl_mbar0_arb_mux_reg_id[3] & cxl_mbar0_write_pulse[0] & lbc_cdm_data[0]);
assign arb_mux_l0ptimeout_err_clr  = (cxl_mbar0_arb_mux_reg_id[3] & cxl_mbar0_write_pulse[0] & lbc_cdm_data[1]);

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_mbar0_arb_mux_pmtimeout_err_PROC
    if ( !sticky_rst_n ) 
        arb_mux_pmtimeout_err_reg   <= #TP 1'b0;     
    else if (mbar0_arb_mux_pmtimeout_err)
        arb_mux_pmtimeout_err_reg   <= #TP 1'b1;
    else if (arb_mux_pmtimeout_err_clr)  
        arb_mux_pmtimeout_err_reg   <= #TP 1'b0;
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_mbar0_arb_mux_l0ptimeout_err_PROC
    if ( !sticky_rst_n ) 
        arb_mux_l0ptimeout_err_reg   <= #TP 1'b0;     
    else if (mbar0_arb_mux_l0ptimeout_err)
        arb_mux_l0ptimeout_err_reg   <= #TP 1'b1;
    else if (arb_mux_l0ptimeout_err_clr)  
        arb_mux_l0ptimeout_err_reg   <= #TP 1'b0;
end

assign {cxl_mbar0_cache_mem_reg_123, cxl_mbar0_cache_mem_reg_122, cxl_mbar0_cache_mem_reg_121, cxl_mbar0_cache_mem_reg_120} = {30'b0, arb_mux_l0ptimeout_err_reg, arb_mux_pmtimeout_err_reg};


// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL ARB/MUX - ARB/MUX Uncorrectable Error Mask Register
// -----------------------------------------------------------------------------
// cxl_mbar0_arb_mux_reg_id     - 4
// PCIE Offset      - `CXL_MEMBAR0_ARB_MUX_PTR + 008h
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_127, cxl_mbar0_cache_mem_reg_126, cxl_mbar0_cache_mem_reg_125, cxl_mbar0_cache_mem_reg_124
// -----------------------------------------------------------------------------
reg   arb_mux_pmtimeout_err_msk;
reg   arb_mux_l0ptimeout_err_msk;

always @(posedge aux_clk or negedge sticky_rst_n) begin : cxl_mbar0_arb_mux_err_msk_PROC
    if (!sticky_rst_n) begin
       arb_mux_pmtimeout_err_msk  <= #TP 1'b1;
       arb_mux_l0ptimeout_err_msk  <= #TP 1'b1; 
    end else begin
       arb_mux_pmtimeout_err_msk  <= #TP (cxl_mbar0_arb_mux_reg_id[4] & cxl_mbar0_write_pulse[0]) ? lbc_cdm_data[0] : arb_mux_pmtimeout_err_msk;
       arb_mux_l0ptimeout_err_msk  <= #TP (cxl_mbar0_arb_mux_reg_id[4] & cxl_mbar0_write_pulse[0]) ? lbc_cdm_data[1] : arb_mux_l0ptimeout_err_msk;
    end
end


assign {cxl_mbar0_cache_mem_reg_127, cxl_mbar0_cache_mem_reg_126, cxl_mbar0_cache_mem_reg_125, cxl_mbar0_cache_mem_reg_124} = {30'b0, arb_mux_l0ptimeout_err_msk, arb_mux_pmtimeout_err_msk};


assign mbar0_arb_mux_uncorr_err = |({cxl_mbar0_cache_mem_reg_123, cxl_mbar0_cache_mem_reg_122, cxl_mbar0_cache_mem_reg_121, cxl_mbar0_cache_mem_reg_120} & ~({cxl_mbar0_cache_mem_reg_127, cxl_mbar0_cache_mem_reg_126, cxl_mbar0_cache_mem_reg_125, cxl_mbar0_cache_mem_reg_124}));



// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL ARB/MUX - ARB/MUX Arbitration Control Register for CXL.io
// -----------------------------------------------------------------------------
// cxl_mbar0_arb_mux_reg_id     - 0 
// PCIE Offset      - `CXL_MEMBAR0_ARB_MUX_PTR + 180h
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_111, cxl_mbar0_cache_mem_reg_110, cxl_mbar0_cache_mem_reg_109, cxl_mbar0_cache_mem_reg_108
// -----------------------------------------------------------------------------
reg [3:0] arb_mux_cxl_io;
assign mbar0_arb_mux_cxl_io = arb_mux_cxl_io;
always @(posedge aux_clk or negedge non_sticky_rst_n) begin : cxl_mbar0_arb_mux_io_non_sticky_PROC
    if (!non_sticky_rst_n) begin
       arb_mux_cxl_io  <= #TP 0;
    end else begin
       arb_mux_cxl_io  <= #TP (cxl_mbar0_arb_mux_reg_id[0] & cxl_mbar0_write_pulse[0]) ? lbc_cdm_data[7:4] : arb_mux_cxl_io;
    end
end

assign {cxl_mbar0_cache_mem_reg_111, cxl_mbar0_cache_mem_reg_110, cxl_mbar0_cache_mem_reg_109, cxl_mbar0_cache_mem_reg_108} = {24'h0, arb_mux_cxl_io, 4'h0};


// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL ARB/MUX - ARB/MUX Arbitration Control Register for CXL.cache and CXL.mem
// -----------------------------------------------------------------------------
// cxl_mbar0_arb_mux_reg_id     - 1 
// PCIE Offset      - `CXL_MEMBAR0_ARB_MUX_PTR + 1C0h
// length           - 4 byte
// Cfig register    - cxl_mbar0_cache_mem_reg_115, cxl_mbar0_cache_mem_reg_114, cxl_mbar0_cache_mem_reg_113, cxl_mbar0_cache_mem_reg_112
// -----------------------------------------------------------------------------
reg [3:0] arb_mux_cxl_cache_mem;
assign mbar0_arb_mux_cxl_cache_mem = arb_mux_cxl_cache_mem;
always @(posedge aux_clk or negedge non_sticky_rst_n) begin : cxl_mbar0_arb_mux_cache_mem_non_sticky_PROC
    if (!non_sticky_rst_n) begin
       arb_mux_cxl_cache_mem  <= #TP 0;
    end else begin
       arb_mux_cxl_cache_mem  <= #TP (cxl_mbar0_arb_mux_reg_id[1] & cxl_mbar0_write_pulse[0]) ? lbc_cdm_data[7:4] : arb_mux_cxl_cache_mem;
    end
end

assign {cxl_mbar0_cache_mem_reg_115, cxl_mbar0_cache_mem_reg_114, cxl_mbar0_cache_mem_reg_113, cxl_mbar0_cache_mem_reg_112} = {24'h0, arb_mux_cxl_cache_mem, 4'h0};


// =============================================================================
// Register Read Operation
// =============================================================================
reg  [31:0]         cxl_mbar0_reg_data_int;       
assign cxl_mbar0_reg_data = cxl_mbar0_reg_data_int;
always @(*)
begin : read_data_PROC
    unique case (1'b1)
        cxl_mbar0_cache_mem_reg_id[0]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_03, cxl_mbar0_cache_mem_reg_02, cxl_mbar0_cache_mem_reg_01, cxl_mbar0_cache_mem_reg_00};  
        cxl_mbar0_cache_mem_reg_id[1]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_07, cxl_mbar0_cache_mem_reg_06, cxl_mbar0_cache_mem_reg_05, cxl_mbar0_cache_mem_reg_04}; 
        cxl_mbar0_cache_mem_reg_id[2]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_11, cxl_mbar0_cache_mem_reg_10, cxl_mbar0_cache_mem_reg_09, cxl_mbar0_cache_mem_reg_08}; 
        cxl_mbar0_cache_mem_reg_id[3]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_15, cxl_mbar0_cache_mem_reg_14, cxl_mbar0_cache_mem_reg_13, cxl_mbar0_cache_mem_reg_12};
        cxl_mbar0_cache_mem_reg_id[4]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_19, cxl_mbar0_cache_mem_reg_18, cxl_mbar0_cache_mem_reg_17, cxl_mbar0_cache_mem_reg_16};
        cxl_mbar0_cache_mem_reg_id[5]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_23, cxl_mbar0_cache_mem_reg_22, cxl_mbar0_cache_mem_reg_21, cxl_mbar0_cache_mem_reg_20};
        cxl_mbar0_cache_mem_reg_id[6]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_27, cxl_mbar0_cache_mem_reg_26, cxl_mbar0_cache_mem_reg_25, cxl_mbar0_cache_mem_reg_24};
        cxl_mbar0_cache_mem_reg_id[7]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_31, cxl_mbar0_cache_mem_reg_30, cxl_mbar0_cache_mem_reg_29, cxl_mbar0_cache_mem_reg_28};
        cxl_mbar0_cache_mem_reg_id[8]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_35, cxl_mbar0_cache_mem_reg_34, cxl_mbar0_cache_mem_reg_33, cxl_mbar0_cache_mem_reg_32};
        cxl_mbar0_cache_mem_reg_id[9]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_39, cxl_mbar0_cache_mem_reg_38, cxl_mbar0_cache_mem_reg_37, cxl_mbar0_cache_mem_reg_36}; 
        cxl_mbar0_cache_mem_reg_id[10]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_43, cxl_mbar0_cache_mem_reg_42, cxl_mbar0_cache_mem_reg_41, cxl_mbar0_cache_mem_reg_40};  
        cxl_mbar0_cache_mem_reg_id[11]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_47, cxl_mbar0_cache_mem_reg_46, cxl_mbar0_cache_mem_reg_45, cxl_mbar0_cache_mem_reg_44};  
        cxl_mbar0_cache_mem_reg_id[12]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_51, cxl_mbar0_cache_mem_reg_50, cxl_mbar0_cache_mem_reg_49, cxl_mbar0_cache_mem_reg_48};  
        cxl_mbar0_cache_mem_reg_id[13]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_55, cxl_mbar0_cache_mem_reg_54, cxl_mbar0_cache_mem_reg_53, cxl_mbar0_cache_mem_reg_52}; 
        cxl_mbar0_cache_mem_reg_id[14]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_59, cxl_mbar0_cache_mem_reg_58, cxl_mbar0_cache_mem_reg_57, cxl_mbar0_cache_mem_reg_56};   
        cxl_mbar0_cache_mem_reg_id[15]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_63, cxl_mbar0_cache_mem_reg_62, cxl_mbar0_cache_mem_reg_61, cxl_mbar0_cache_mem_reg_60};  
        cxl_mbar0_cache_mem_reg_id[16]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_67, cxl_mbar0_cache_mem_reg_66, cxl_mbar0_cache_mem_reg_65, cxl_mbar0_cache_mem_reg_64};  
        cxl_mbar0_cache_mem_reg_id[17]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_71, cxl_mbar0_cache_mem_reg_70, cxl_mbar0_cache_mem_reg_69, cxl_mbar0_cache_mem_reg_68};  
        cxl_mbar0_cache_mem_reg_id[18]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_75, cxl_mbar0_cache_mem_reg_74, cxl_mbar0_cache_mem_reg_73, cxl_mbar0_cache_mem_reg_72};  
        cxl_mbar0_cache_mem_reg_id[19]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_79, cxl_mbar0_cache_mem_reg_78, cxl_mbar0_cache_mem_reg_77, cxl_mbar0_cache_mem_reg_76};  
        cxl_mbar0_cache_mem_reg_id[20]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_83, cxl_mbar0_cache_mem_reg_82, cxl_mbar0_cache_mem_reg_81, cxl_mbar0_cache_mem_reg_80};   
        cxl_mbar0_cache_mem_reg_id[21]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_87, cxl_mbar0_cache_mem_reg_86, cxl_mbar0_cache_mem_reg_85, cxl_mbar0_cache_mem_reg_84};  
        cxl_mbar0_cache_mem_reg_id[22]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_91, cxl_mbar0_cache_mem_reg_90, cxl_mbar0_cache_mem_reg_89, cxl_mbar0_cache_mem_reg_88}; 
        cxl_mbar0_cache_mem_reg_id[23]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_95, cxl_mbar0_cache_mem_reg_94, cxl_mbar0_cache_mem_reg_93, cxl_mbar0_cache_mem_reg_92};
        cxl_mbar0_cache_mem_reg_id[24]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_99, cxl_mbar0_cache_mem_reg_98, cxl_mbar0_cache_mem_reg_97, cxl_mbar0_cache_mem_reg_96};
        cxl_mbar0_cache_mem_reg_id[25]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_103, cxl_mbar0_cache_mem_reg_102, cxl_mbar0_cache_mem_reg_101, cxl_mbar0_cache_mem_reg_100};
        cxl_mbar0_cache_mem_reg_id[26]  : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_107, cxl_mbar0_cache_mem_reg_106, cxl_mbar0_cache_mem_reg_105, cxl_mbar0_cache_mem_reg_104};   
        cxl_mbar0_arb_mux_reg_id[0]     : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_111, cxl_mbar0_cache_mem_reg_110, cxl_mbar0_cache_mem_reg_109, cxl_mbar0_cache_mem_reg_108};
        cxl_mbar0_arb_mux_reg_id[1]     : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_115, cxl_mbar0_cache_mem_reg_114, cxl_mbar0_cache_mem_reg_113, cxl_mbar0_cache_mem_reg_112};
        cxl_mbar0_arb_mux_reg_id[2]     : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_119, cxl_mbar0_cache_mem_reg_118, cxl_mbar0_cache_mem_reg_117, cxl_mbar0_cache_mem_reg_116};
        cxl_mbar0_arb_mux_reg_id[3]     : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_123, cxl_mbar0_cache_mem_reg_122, cxl_mbar0_cache_mem_reg_121, cxl_mbar0_cache_mem_reg_120};
        cxl_mbar0_arb_mux_reg_id[4]     : cxl_mbar0_reg_data_int = {cxl_mbar0_cache_mem_reg_127, cxl_mbar0_cache_mem_reg_126, cxl_mbar0_cache_mem_reg_125, cxl_mbar0_cache_mem_reg_124};
        default             : cxl_mbar0_reg_data_int = `PCIE_UNUSED_RESPONSE;
    endcase
end

endmodule // cdm_cxl_membar0
