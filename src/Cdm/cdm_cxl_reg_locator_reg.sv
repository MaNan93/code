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
// ---    $DateTime: 2021/11/04 02:29:06 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_cxl_reg_locator_reg.sv#2 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the CXL Register Locator DVSEC Extended Capability regsiters.
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_cxl_reg_locator_reg
#(

    parameter INST          = 0 
   ,parameter NCXL_REG_LOCATOR  = `CXL_REG_LOCATOR_DVSEC_SIZE>>2    // Number of registers in CXL Register Locator DVSEC Extended Capability Structure
   ,parameter NL            = `CX_NL                     // Number of Lanes
   ,parameter TP            = `TP
)

                               (

// -- Inputs --
   input                      aux_clk,               // Clock            
   input                      non_sticky_rst_n,      // Reset non_sticky register only 
   input                      sticky_rst_n,          // Reset sticky register only   
  
  
   input   [31:0]             lbc_cdm_data,
   input                      lbc_cdm_dbi,
   input                      dbi_ro_wr_en,  
   input   [3:0]              cxl_reg_locator_write_pulse,
   input   [NCXL_REG_LOCATOR-1:0] cxl_reg_locator_reg_id,
   input                      upstream_port,


// -- Outputs --
   output reg [31:0]          cxl_reg_locator_reg_data,                      // Data read from the register
   output     [63:0]          cxl_2_0_comp_reg_offset,                       // CXL 2.0 Comp Specific Register Offset within Func 0, BAR0
   output reg [2:0]           cfg_cxl_reg_locator_reg1_bir,
   output reg [7:0]           cfg_cxl_reg_locator_reg1_blk_identifier,
   output reg [15:0]          cfg_cxl_reg_locator_reg1_blk_offset_low,
   output reg [31:0]          cfg_cxl_reg_locator_reg1_blk_offset_high,
   output reg [2:0]           cfg_cxl_reg_locator_reg2_bir,
   output reg [7:0]           cfg_cxl_reg_locator_reg2_blk_identifier,
   output reg [15:0]          cfg_cxl_reg_locator_reg2_blk_offset_low,
   output reg [31:0]          cfg_cxl_reg_locator_reg2_blk_offset_high,
   output reg [2:0]           cfg_cxl_reg_locator_reg3_bir,
   output reg [7:0]           cfg_cxl_reg_locator_reg3_blk_identifier,
   output reg [15:0]          cfg_cxl_reg_locator_reg3_blk_offset_low,
   output reg [31:0]          cfg_cxl_reg_locator_reg3_blk_offset_high

);

wire    [7:0]   cxl_reg_locator_reg_03, cxl_reg_locator_reg_02, cxl_reg_locator_reg_01, cxl_reg_locator_reg_00;
wire    [7:0]   cxl_reg_locator_reg_07, cxl_reg_locator_reg_06, cxl_reg_locator_reg_05, cxl_reg_locator_reg_04;
wire    [7:0]   cxl_reg_locator_reg_11, cxl_reg_locator_reg_10, cxl_reg_locator_reg_09, cxl_reg_locator_reg_08;
wire    [7:0]   cxl_reg_locator_reg_15, cxl_reg_locator_reg_14, cxl_reg_locator_reg_13, cxl_reg_locator_reg_12;
wire    [7:0]   cxl_reg_locator_reg_19, cxl_reg_locator_reg_18, cxl_reg_locator_reg_17, cxl_reg_locator_reg_16;
wire    [7:0]   cxl_reg_locator_reg_23, cxl_reg_locator_reg_22, cxl_reg_locator_reg_21, cxl_reg_locator_reg_20;
wire    [7:0]   cxl_reg_locator_reg_27, cxl_reg_locator_reg_26, cxl_reg_locator_reg_25, cxl_reg_locator_reg_24;
wire    [7:0]   cxl_reg_locator_reg_31, cxl_reg_locator_reg_30, cxl_reg_locator_reg_29, cxl_reg_locator_reg_28;
wire    [7:0]   cxl_reg_locator_reg_35, cxl_reg_locator_reg_34, cxl_reg_locator_reg_33, cxl_reg_locator_reg_32;


wire            int_lbc_cdm_dbi;
assign          int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;


// -----------------------------------------------------------------------------
// CXL Register Locator DVSEC Extended Capability Header Register
// -----------------------------------------------------------------------------
// cxl_reg_locator_reg_id     - 0
// PCIE Offset      - `CXL_REG_LOCATOR_PTR
// length           - 4 byte
// Cfig register    - cxl_reg_locator_reg_03, cxl_reg_locator_reg_02, cxl_reg_locator_reg_01, cxl_reg_locator_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_cxl_reg_locator_id;                 // CXL Register Locator DVSEC Capability ID
reg [3:0]   cfg_cxl_reg_locator_ver;                // CXL Register Locator DVSEC Capability Version
reg [11:0]  cfg_cxl_reg_locator_next_ptr;           // CXL Register Locator DVSEC Next Capability Offset
reg         cxl_reg_locator_next_ptr_wr_updated;

assign cxl_reg_locator_reg_00 = cfg_cxl_reg_locator_id[7:0];
assign cxl_reg_locator_reg_01 = cfg_cxl_reg_locator_id[15:8];
assign cxl_reg_locator_reg_02 = {cfg_cxl_reg_locator_next_ptr[3:0], cfg_cxl_reg_locator_ver};
assign cxl_reg_locator_reg_03 = cfg_cxl_reg_locator_next_ptr[11:4];

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_reg_locator_id[15:0]    <= #TP `PCIE_CXL_REG_LOCATOR_ECAP_ID;      // Capability ID = 16'h0023
        cfg_cxl_reg_locator_ver[3:0]    <= #TP `PCIE_CXL_REG_LOCATOR_ECAP_VER;     // Capability version = 4'h1
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_cxl_reg_locator_id[7:0]     <= #TP (cxl_reg_locator_reg_id[0] & cxl_reg_locator_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_reg_locator_id[7:0];
        cfg_cxl_reg_locator_id[15:8]    <= #TP (cxl_reg_locator_reg_id[0] & cxl_reg_locator_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_reg_locator_id[15:8];
        cfg_cxl_reg_locator_ver[3:0]    <= #TP (cxl_reg_locator_reg_id[0] & cxl_reg_locator_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_cxl_reg_locator_ver[3:0];
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_reg_locator_next_ptr[11:0] <= #TP `CXL_REG_LOCATOR_NEXT_PTR;
    end
    else begin
        if (cxl_reg_locator_reg_id[0] && int_lbc_cdm_dbi) begin
        // Read-Only registers, but writable through DBI
            cfg_cxl_reg_locator_next_ptr[3:0]  <= #TP cxl_reg_locator_write_pulse[2] ? lbc_cdm_data[23:20] : cfg_cxl_reg_locator_next_ptr[3:0];
            cfg_cxl_reg_locator_next_ptr[11:4] <= #TP cxl_reg_locator_write_pulse[3] ? lbc_cdm_data[31:24] : cfg_cxl_reg_locator_next_ptr[11:4];
        end else if (!cxl_reg_locator_next_ptr_wr_updated) begin
            cfg_cxl_reg_locator_next_ptr[11:0] <= #TP upstream_port ? `CXL_REG_LOCATOR_NEXT_PTR : `DM_RP_CXL_REG_LOCATOR_NEXT_PTR;
        end    
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cxl_reg_locator_next_ptr_wr_updated  <= #TP 1'b0;
    end
    else begin
        if (cxl_reg_locator_reg_id[0] && int_lbc_cdm_dbi && |cxl_reg_locator_write_pulse[3:2]) begin
        cxl_reg_locator_next_ptr_wr_updated  <= #TP 1'b1;
        end    
    end
end


// -----------------------------------------------------------------------------
// Designated Vendor Specific Header 1 Register
// -----------------------------------------------------------------------------
// cxl_reg_locator_reg_id     - 1
// PCIE Offset      - `CXL_REG_LOCATOR_PTR + 04h
// length           - 4 byte
// Cfig register    - cxl_reg_locator_reg_07, cxl_reg_locator_reg_06, cxl_reg_locator_reg_05, cxl_reg_locator_reg_04
// -----------------------------------------------------------------------------
reg     [15:0]  cfg_cxl_reg_locator_vid;
reg     [3:0]   cfg_cxl_reg_locator_dvsec_ver;
reg     [11:0]  cfg_cxl_reg_locator_len0;

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_reg_locator_vid       <= #TP `PCIE_CXL_REG_LOCATOR_VENDOR_ID;
        cfg_cxl_reg_locator_dvsec_ver <= #TP `PCIE_CXL_REG_LOCATOR_VER;
        cfg_cxl_reg_locator_len0      <= #TP `CXL_REG_LOCATOR_DVSEC_SIZE;
    end
    else begin
        // Read-Only registers, but writable through DBI
        cfg_cxl_reg_locator_vid[7:0]        <= #TP (cxl_reg_locator_reg_id[1] & cxl_reg_locator_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_reg_locator_vid[7:0];
        cfg_cxl_reg_locator_vid[15:8]       <= #TP (cxl_reg_locator_reg_id[1] & cxl_reg_locator_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_reg_locator_vid[15:8];
        cfg_cxl_reg_locator_dvsec_ver[3:0]  <= #TP (cxl_reg_locator_reg_id[1] & cxl_reg_locator_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_cxl_reg_locator_dvsec_ver[3:0];
        cfg_cxl_reg_locator_len0[3:0]       <= #TP (cxl_reg_locator_reg_id[1] & cxl_reg_locator_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:20] : cfg_cxl_reg_locator_len0[3:0];
        cfg_cxl_reg_locator_len0[11:4]      <= #TP (cxl_reg_locator_reg_id[1] & cxl_reg_locator_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_reg_locator_len0[11:4];
    end
end

assign cxl_reg_locator_reg_04 = cfg_cxl_reg_locator_vid[7:0];
assign cxl_reg_locator_reg_05 = cfg_cxl_reg_locator_vid[15:8];
assign cxl_reg_locator_reg_06 = {cfg_cxl_reg_locator_len0[3:0], cfg_cxl_reg_locator_dvsec_ver};
assign cxl_reg_locator_reg_07 = cfg_cxl_reg_locator_len0[11:4];

// -----------------------------------------------------------------------------
// Designated Vendor Specific Header 2(0x08)
// -----------------------------------------------------------------------------
// cxl_reg_locator_reg_id     - 2
// PCIE Offset      - `CXL_REG_LOCATOR_PTR + 08h
// length           - 4 byte
// Cfig register    - cxl_reg_locator_reg_11, cxl_reg_locator_reg_10, cxl_reg_locator_reg_09, cxl_reg_locator_reg_08
// -----------------------------------------------------------------------------

reg     [15:0]  cfg_cxl_reg_locator_dvsec_id0;                // [15:0]

assign cxl_reg_locator_reg_08 = cfg_cxl_reg_locator_dvsec_id0[7:0];
assign cxl_reg_locator_reg_09 = cfg_cxl_reg_locator_dvsec_id0[15:8];
assign cxl_reg_locator_reg_10 = 8'h00;
assign cxl_reg_locator_reg_11 = 8'h00;

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_reg_locator_dvsec_id0       <= #TP `PCIE_CXL_REG_LOCATOR_DVSEC_ID;               
    end
    else begin
        cfg_cxl_reg_locator_dvsec_id0[7:0]  <= #TP (cxl_reg_locator_reg_id[2] & cxl_reg_locator_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_reg_locator_dvsec_id0[7:0];
        cfg_cxl_reg_locator_dvsec_id0[15:8] <= #TP (cxl_reg_locator_reg_id[2] & cxl_reg_locator_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_reg_locator_dvsec_id0[15:8];
    end
end

// --------------------------------------------------------------------------------------
// Register Block 1 - Register Offset Low (0Ch) 
// --------------------------------------------------------------------------------------
// cxl_reg_locator_reg_id     - 3
// PCIE Offset      - `CXL_REG_LOCATOR_PTR + 0Ch
// length           - 4 byte
// Cfig register    - cxl_reg_locator_reg_15, cxl_reg_locator_reg_14, cxl_reg_locator_reg_13, cxl_reg_locator_reg_12
// --------------------------------------------------------------------------------------

assign cxl_reg_locator_reg_12 = {5'h0, cfg_cxl_reg_locator_reg1_bir};
assign cxl_reg_locator_reg_13 = cfg_cxl_reg_locator_reg1_blk_identifier;
assign cxl_reg_locator_reg_14 = cfg_cxl_reg_locator_reg1_blk_offset_low[7:0];
assign cxl_reg_locator_reg_15 = cfg_cxl_reg_locator_reg1_blk_offset_low[15:8];

assign cxl_2_0_comp_reg_offset = {cfg_cxl_reg_locator_reg1_blk_offset_high, cfg_cxl_reg_locator_reg1_blk_offset_low, 16'd0};


always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_reg_locator_reg1_bir                <= #TP `CX_CXL_2_0_COMP_REG_BAR_NUM;
        cfg_cxl_reg_locator_reg1_blk_identifier     <= #TP 8'h01;
        cfg_cxl_reg_locator_reg1_blk_offset_low     <= #TP `CX_CXL_2_0_COMP_REG_OFFSET_LOW;
    end
    else begin
        cfg_cxl_reg_locator_reg1_bir                   <= #TP (cxl_reg_locator_reg_id[3] & cxl_reg_locator_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[2:0] : cfg_cxl_reg_locator_reg1_bir;
        cfg_cxl_reg_locator_reg1_blk_identifier        <= #TP (cxl_reg_locator_reg_id[3] & cxl_reg_locator_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_reg_locator_reg1_blk_identifier;
        cfg_cxl_reg_locator_reg1_blk_offset_low[7:0]   <= #TP (cxl_reg_locator_reg_id[3] & cxl_reg_locator_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cfg_cxl_reg_locator_reg1_blk_offset_low[7:0];
        cfg_cxl_reg_locator_reg1_blk_offset_low[15:8]  <= #TP (cxl_reg_locator_reg_id[3] & cxl_reg_locator_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_reg_locator_reg1_blk_offset_low[15:8];        
    end
end


// --------------------------------------------------------------------------------------
// Register Block 1 - Register Offset High (10h)
// --------------------------------------------------------------------------------------
// cxl_reg_locator_reg_id  - 4
// PCIE Offset      - `CXL_REG_LOCATOR_PTR + 10h
// length           - 4 byte
// Cfig register    - cxl_reg_locator_reg_19, cxl_reg_locator_reg_18, cxl_reg_locator_reg_17, cxl_reg_locator_reg_16
// --------------------------------------------------------------------------------------

assign cxl_reg_locator_reg_16 = cfg_cxl_reg_locator_reg1_blk_offset_high[7:0]; 
assign cxl_reg_locator_reg_17 = cfg_cxl_reg_locator_reg1_blk_offset_high[15:8]; 
assign cxl_reg_locator_reg_18 = cfg_cxl_reg_locator_reg1_blk_offset_high[23:16]; 
assign cxl_reg_locator_reg_19 = cfg_cxl_reg_locator_reg1_blk_offset_high[31:24];  


always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_reg_locator_reg1_blk_offset_high     <= #TP `CX_CXL_2_0_COMP_REG_OFFSET_HIGH;
    end
    else begin
        cfg_cxl_reg_locator_reg1_blk_offset_high[7:0]   <= #TP (cxl_reg_locator_reg_id[4] & cxl_reg_locator_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_reg_locator_reg1_blk_offset_high[7:0];
        cfg_cxl_reg_locator_reg1_blk_offset_high[15:8]  <= #TP (cxl_reg_locator_reg_id[4] & cxl_reg_locator_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_reg_locator_reg1_blk_offset_high[15:8]; 
        cfg_cxl_reg_locator_reg1_blk_offset_high[23:16] <= #TP (cxl_reg_locator_reg_id[4] & cxl_reg_locator_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cfg_cxl_reg_locator_reg1_blk_offset_high[23:16];
        cfg_cxl_reg_locator_reg1_blk_offset_high[31:24] <= #TP (cxl_reg_locator_reg_id[4] & cxl_reg_locator_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_reg_locator_reg1_blk_offset_high[31:24];          
    end
end


// --------------------------------------------------------------------------------------
// Register Block 2 - Register Offset Low (14h) 
// --------------------------------------------------------------------------------------
// cxl_reg_locator_reg_id     - 5
// PCIE Offset      - `CXL_REG_LOCATOR_PTR + 14h
// length           - 4 byte
// Cfig register    - cxl_reg_locator_reg_23, cxl_reg_locator_reg_22, cxl_reg_locator_reg_21, cxl_reg_locator_reg_20
// --------------------------------------------------------------------------------------

assign cxl_reg_locator_reg_20 = {5'h0, cfg_cxl_reg_locator_reg2_bir};
assign cxl_reg_locator_reg_21 = cfg_cxl_reg_locator_reg2_blk_identifier;
assign cxl_reg_locator_reg_22 = cfg_cxl_reg_locator_reg2_blk_offset_low[7:0];
assign cxl_reg_locator_reg_23 = cfg_cxl_reg_locator_reg2_blk_offset_low[15:8];


always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_reg_locator_reg2_bir                <= #TP `CX_CXL_REG_LOCATOR_REG2_BIR;
        cfg_cxl_reg_locator_reg2_blk_identifier     <= #TP `CX_CXL_REG_LOCATOR_REG2_IDENTIFIER;
        cfg_cxl_reg_locator_reg2_blk_offset_low     <= #TP `CX_CXL_REG_LOCATOR_REG2_OFFSET_LOW;
    end
    else begin
        cfg_cxl_reg_locator_reg2_bir                   <= #TP (cxl_reg_locator_reg_id[5] & cxl_reg_locator_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[2:0] : cfg_cxl_reg_locator_reg2_bir;
        cfg_cxl_reg_locator_reg2_blk_identifier        <= #TP (cxl_reg_locator_reg_id[5] & cxl_reg_locator_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_reg_locator_reg2_blk_identifier;
        cfg_cxl_reg_locator_reg2_blk_offset_low[7:0]   <= #TP (cxl_reg_locator_reg_id[5] & cxl_reg_locator_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cfg_cxl_reg_locator_reg2_blk_offset_low[7:0];
        cfg_cxl_reg_locator_reg2_blk_offset_low[15:8]  <= #TP (cxl_reg_locator_reg_id[5] & cxl_reg_locator_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_reg_locator_reg2_blk_offset_low[15:8];        
    end
end


// --------------------------------------------------------------------------------------
// Register Block 2 - Register Offset High (18h)
// --------------------------------------------------------------------------------------
// cxl_reg_locator_reg_id  - 6
// PCIE Offset      - `CXL_REG_LOCATOR_PTR + 18h
// length           - 4 byte
// Cfig register    - cxl_reg_locator_reg_27, cxl_reg_locator_reg_26, cxl_reg_locator_reg_25, cxl_reg_locator_reg_24
// --------------------------------------------------------------------------------------

assign cxl_reg_locator_reg_24 = cfg_cxl_reg_locator_reg2_blk_offset_high[7:0]; 
assign cxl_reg_locator_reg_25 = cfg_cxl_reg_locator_reg2_blk_offset_high[15:8]; 
assign cxl_reg_locator_reg_26 = cfg_cxl_reg_locator_reg2_blk_offset_high[23:16]; 
assign cxl_reg_locator_reg_27 = cfg_cxl_reg_locator_reg2_blk_offset_high[31:24];  


always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_reg_locator_reg2_blk_offset_high     <= #TP `CX_CXL_REG_LOCATOR_REG2_OFFSET_HIGH;
    end
    else begin
        cfg_cxl_reg_locator_reg2_blk_offset_high[7:0]   <= #TP (cxl_reg_locator_reg_id[6] & cxl_reg_locator_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_reg_locator_reg2_blk_offset_high[7:0];
        cfg_cxl_reg_locator_reg2_blk_offset_high[15:8]  <= #TP (cxl_reg_locator_reg_id[6] & cxl_reg_locator_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_reg_locator_reg2_blk_offset_high[15:8]; 
        cfg_cxl_reg_locator_reg2_blk_offset_high[23:16] <= #TP (cxl_reg_locator_reg_id[6] & cxl_reg_locator_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cfg_cxl_reg_locator_reg2_blk_offset_high[23:16];
        cfg_cxl_reg_locator_reg2_blk_offset_high[31:24] <= #TP (cxl_reg_locator_reg_id[6] & cxl_reg_locator_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_reg_locator_reg2_blk_offset_high[31:24];          
    end
end

// --------------------------------------------------------------------------------------
// Register Block 3 - Register Offset Low (1Ch) 
// --------------------------------------------------------------------------------------
// cxl_reg_locator_reg_id     - 7
// PCIE Offset      - `CXL_REG_LOCATOR_PTR + 1Ch
// length           - 4 byte
// Cfig register    - cxl_reg_locator_reg_31, cxl_reg_locator_reg_30, cxl_reg_locator_reg_29, cxl_reg_locator_reg_28
// --------------------------------------------------------------------------------------

assign cxl_reg_locator_reg_28 = {5'h0, cfg_cxl_reg_locator_reg3_bir};
assign cxl_reg_locator_reg_29 = cfg_cxl_reg_locator_reg3_blk_identifier;
assign cxl_reg_locator_reg_30 = cfg_cxl_reg_locator_reg3_blk_offset_low[7:0];
assign cxl_reg_locator_reg_31 = cfg_cxl_reg_locator_reg3_blk_offset_low[15:8];


always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_reg_locator_reg3_bir                <= #TP `CX_CXL_REG_LOCATOR_REG3_BIR;
        cfg_cxl_reg_locator_reg3_blk_identifier     <= #TP `CX_CXL_REG_LOCATOR_REG3_IDENTIFIER;
        cfg_cxl_reg_locator_reg3_blk_offset_low     <= #TP `CX_CXL_REG_LOCATOR_REG3_OFFSET_LOW;
    end
    else begin
        cfg_cxl_reg_locator_reg3_bir                   <= #TP (cxl_reg_locator_reg_id[7] & cxl_reg_locator_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[2:0] : cfg_cxl_reg_locator_reg3_bir;
        cfg_cxl_reg_locator_reg3_blk_identifier        <= #TP (cxl_reg_locator_reg_id[7] & cxl_reg_locator_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_reg_locator_reg3_blk_identifier;
        cfg_cxl_reg_locator_reg3_blk_offset_low[7:0]   <= #TP (cxl_reg_locator_reg_id[7] & cxl_reg_locator_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cfg_cxl_reg_locator_reg3_blk_offset_low[7:0];
        cfg_cxl_reg_locator_reg3_blk_offset_low[15:8]  <= #TP (cxl_reg_locator_reg_id[7] & cxl_reg_locator_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_reg_locator_reg3_blk_offset_low[15:8];        
    end
end


// --------------------------------------------------------------------------------------
// Register Block 3 - Register Offset High (20h)
// --------------------------------------------------------------------------------------
// cxl_reg_locator_reg_id  - 8
// PCIE Offset      - `CXL_REG_LOCATOR_PTR + 20h
// length           - 4 byte
// Cfig register    - cxl_reg_locator_reg_35, cxl_reg_locator_reg_34, cxl_reg_locator_reg_33, cxl_reg_locator_reg_32
// --------------------------------------------------------------------------------------

assign cxl_reg_locator_reg_32 = cfg_cxl_reg_locator_reg3_blk_offset_high[7:0]; 
assign cxl_reg_locator_reg_33 = cfg_cxl_reg_locator_reg3_blk_offset_high[15:8]; 
assign cxl_reg_locator_reg_34 = cfg_cxl_reg_locator_reg3_blk_offset_high[23:16]; 
assign cxl_reg_locator_reg_35 = cfg_cxl_reg_locator_reg3_blk_offset_high[31:24];  


always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_reg_locator_reg3_blk_offset_high     <= #TP `CX_CXL_REG_LOCATOR_REG3_OFFSET_HIGH;
    end
    else begin
        cfg_cxl_reg_locator_reg3_blk_offset_high[7:0]   <= #TP (cxl_reg_locator_reg_id[8] & cxl_reg_locator_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_reg_locator_reg3_blk_offset_high[7:0];
        cfg_cxl_reg_locator_reg3_blk_offset_high[15:8]  <= #TP (cxl_reg_locator_reg_id[8] & cxl_reg_locator_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_reg_locator_reg3_blk_offset_high[15:8]; 
        cfg_cxl_reg_locator_reg3_blk_offset_high[23:16] <= #TP (cxl_reg_locator_reg_id[8] & cxl_reg_locator_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cfg_cxl_reg_locator_reg3_blk_offset_high[23:16];
        cfg_cxl_reg_locator_reg3_blk_offset_high[31:24] <= #TP (cxl_reg_locator_reg_id[8] & cxl_reg_locator_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_reg_locator_reg3_blk_offset_high[31:24];          
    end
end


// =============================================================================
// Register Read Operation
// =============================================================================

always @(*)
begin : read_data_PROC
    unique case (1'b1)
        cxl_reg_locator_reg_id[0]  : cxl_reg_locator_reg_data = {cxl_reg_locator_reg_03, cxl_reg_locator_reg_02, cxl_reg_locator_reg_01, cxl_reg_locator_reg_00};   // 0x00
        cxl_reg_locator_reg_id[1]  : cxl_reg_locator_reg_data = {cxl_reg_locator_reg_07, cxl_reg_locator_reg_06, cxl_reg_locator_reg_05, cxl_reg_locator_reg_04};   // 0x04
        cxl_reg_locator_reg_id[2]  : cxl_reg_locator_reg_data = {cxl_reg_locator_reg_11, cxl_reg_locator_reg_10, cxl_reg_locator_reg_09, cxl_reg_locator_reg_08};   // 0x08
        cxl_reg_locator_reg_id[3]  : cxl_reg_locator_reg_data = {cxl_reg_locator_reg_15, cxl_reg_locator_reg_14, cxl_reg_locator_reg_13, cxl_reg_locator_reg_12};   // 0x0C
        cxl_reg_locator_reg_id[4]  : cxl_reg_locator_reg_data = {cxl_reg_locator_reg_19, cxl_reg_locator_reg_18, cxl_reg_locator_reg_17, cxl_reg_locator_reg_16};   // 0x10
        cxl_reg_locator_reg_id[5]  : cxl_reg_locator_reg_data = {cxl_reg_locator_reg_23, cxl_reg_locator_reg_22, cxl_reg_locator_reg_21, cxl_reg_locator_reg_20};   // 0x14
        cxl_reg_locator_reg_id[6]  : cxl_reg_locator_reg_data = {cxl_reg_locator_reg_27, cxl_reg_locator_reg_26, cxl_reg_locator_reg_25, cxl_reg_locator_reg_24};   // 0x18
        cxl_reg_locator_reg_id[7]  : cxl_reg_locator_reg_data = {cxl_reg_locator_reg_31, cxl_reg_locator_reg_30, cxl_reg_locator_reg_29, cxl_reg_locator_reg_28};   // 0x1C
        cxl_reg_locator_reg_id[8]  : cxl_reg_locator_reg_data = {cxl_reg_locator_reg_35, cxl_reg_locator_reg_34, cxl_reg_locator_reg_33, cxl_reg_locator_reg_32};   // 0x20
        default                : cxl_reg_locator_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end

endmodule // cdm_cxl_reg_locator_reg
