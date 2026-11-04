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
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_cxl_2_0_ext_reg.sv#4 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the CXL 2.0 Extensions DVSEC Extended Capability regsiters.
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_cxl_2_0_ext_reg
#(

    parameter INST          = 0 
   ,parameter NCXL_2_0_EXT  = `CXL_2_0_EXT_DVSEC_SIZE>>2    // Number of registers in CXL 2.0 Extension DVSEC Extended Capability Structure
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
   input   [3:0]              cxl_2_0_ext_write_pulse,
   input   [NCXL_2_0_EXT-1:0] cxl_2_0_ext_reg_id,
   input                      upstream_port,
   input                      cxl_pm_init_cmpl,
   input                      viral_status,


// -- Outputs --
   output reg [31:0]          cxl_2_0_ext_reg_data,                      // Data read from the register

   output reg                 cfg_cxl_2_0_ext_viral_status,              // Switch Port has entered Viral

   output reg                 cfg_cxl_2_0_ext_unmask_sbr,                // Unmask SBR
   output reg                 cfg_cxl_2_0_ext_unmask_ld,                 // Unmask Link Disable
   output reg                 cfg_cxl_2_0_ext_alt_mse,                   // Alternate Memory Space Enable 
   output reg                 cfg_cxl_2_0_ext_alt_bme,                   // Alternate Bus Master Enable
   output reg                 cfg_cxl_2_0_ext_viral_en,                  // Viral Enable for Switch

   output reg [7:0]           cfg_cxl_2_0_ext_alt_bus_base,              // Alternate Bus Base
   output reg [7:0]           cfg_cxl_2_0_ext_alt_bus_limit,             // Alternate Bus Limit

   output reg [11:0]          cfg_cxl_2_0_ext_alt_mem_base,              // Alternate Memory Base
   output reg [11:0]          cfg_cxl_2_0_ext_alt_mem_limit,             // Alternate Memory Limit

   output reg [11:0]          cfg_cxl_2_0_ext_alt_pref_mem_base,         // Alternate Prefetchable Memory Base
   output reg [11:0]          cfg_cxl_2_0_ext_alt_pref_mem_limit,        // Alternate Memory Limit

   output reg [31:0]          cfg_cxl_2_0_ext_alt_pref_mem_base_high,    // Alternate Prefetchable Memory Base High
   output reg [31:0]          cfg_cxl_2_0_ext_alt_pref_mem_limit_high,   // Alternate Prefetchable Memory Base High
   
   output reg                 cfg_cxl_2_0_ext_rcrb_en,                   // CXL RCRB Enable                           
   output reg [18:0]          cfg_cxl_2_0_ext_rcrb_base_addr_low,        // CXL RCRB Base Address Low
   output reg [31:0]          cfg_cxl_2_0_ext_rcrb_base_addr_high        // RCRB Base Address High

);

wire    [7:0]   cxl_2_0_ext_reg_03, cxl_2_0_ext_reg_02, cxl_2_0_ext_reg_01, cxl_2_0_ext_reg_00;
wire    [7:0]   cxl_2_0_ext_reg_07, cxl_2_0_ext_reg_06, cxl_2_0_ext_reg_05, cxl_2_0_ext_reg_04;
wire    [7:0]   cxl_2_0_ext_reg_11, cxl_2_0_ext_reg_10, cxl_2_0_ext_reg_09, cxl_2_0_ext_reg_08;
wire    [7:0]   cxl_2_0_ext_reg_15, cxl_2_0_ext_reg_14, cxl_2_0_ext_reg_13, cxl_2_0_ext_reg_12;
wire    [7:0]   cxl_2_0_ext_reg_19, cxl_2_0_ext_reg_18, cxl_2_0_ext_reg_17, cxl_2_0_ext_reg_16;
wire    [7:0]   cxl_2_0_ext_reg_23, cxl_2_0_ext_reg_22, cxl_2_0_ext_reg_21, cxl_2_0_ext_reg_20;
wire    [7:0]   cxl_2_0_ext_reg_27, cxl_2_0_ext_reg_26, cxl_2_0_ext_reg_25, cxl_2_0_ext_reg_24;
wire    [7:0]   cxl_2_0_ext_reg_31, cxl_2_0_ext_reg_30, cxl_2_0_ext_reg_29, cxl_2_0_ext_reg_28;
wire    [7:0]   cxl_2_0_ext_reg_35, cxl_2_0_ext_reg_34, cxl_2_0_ext_reg_33, cxl_2_0_ext_reg_32;
wire    [7:0]   cxl_2_0_ext_reg_39, cxl_2_0_ext_reg_38, cxl_2_0_ext_reg_37, cxl_2_0_ext_reg_36;


wire            int_lbc_cdm_dbi;
assign          int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;


// -----------------------------------------------------------------------------
// CXL 2.0 Extension DVSEC Extended Capability Header Register
// -----------------------------------------------------------------------------
// cxl_2_0_ext_reg_id     - 0
// PCIE Offset      - `CXL_2_0_EXT_PTR
// length           - 4 byte
// Cfig register    - cxl_2_0_ext_reg_03, cxl_2_0_ext_reg_02, cxl_2_0_ext_reg_01, cxl_2_0_ext_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_cxl_2_0_ext_id;                 // CXL 2.0 Extension DVSEC Capability ID
reg [3:0]   cfg_cxl_2_0_ext_ver;                // CXL 2.0 Extension DVSEC Capability Version
reg [11:0]  cfg_cxl_2_0_ext_next_ptr;           // CXL 2.0 Extension DVSEC Next Capability Offset
reg         cxl_2_0_ext_next_ptr_wr_updated;

assign cxl_2_0_ext_reg_00 = cfg_cxl_2_0_ext_id[7:0];
assign cxl_2_0_ext_reg_01 = cfg_cxl_2_0_ext_id[15:8];
assign cxl_2_0_ext_reg_02 = {cfg_cxl_2_0_ext_next_ptr[3:0], cfg_cxl_2_0_ext_ver};
assign cxl_2_0_ext_reg_03 = cfg_cxl_2_0_ext_next_ptr[11:4];

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_2_0_ext_id[15:0]    <= #TP `PCIE_CXL_2_0_EXT_ECAP_ID;      // Capability ID = 16'h0023
        cfg_cxl_2_0_ext_ver[3:0]    <= #TP `PCIE_CXL_2_0_EXT_ECAP_VER;     // Capability version = 4'h1
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_cxl_2_0_ext_id[7:0]     <= #TP (cxl_2_0_ext_reg_id[0] & cxl_2_0_ext_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_2_0_ext_id[7:0];
        cfg_cxl_2_0_ext_id[15:8]    <= #TP (cxl_2_0_ext_reg_id[0] & cxl_2_0_ext_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_2_0_ext_id[15:8];
        cfg_cxl_2_0_ext_ver[3:0]    <= #TP (cxl_2_0_ext_reg_id[0] & cxl_2_0_ext_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_cxl_2_0_ext_ver[3:0];
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_2_0_ext_next_ptr[11:0] <= #TP `CXL_2_0_EXT_NEXT_PTR;
    end
    else begin
        if (cxl_2_0_ext_reg_id[0] && int_lbc_cdm_dbi) begin
        // Read-Only registers, but writable through DBI
            cfg_cxl_2_0_ext_next_ptr[3:0]  <= #TP cxl_2_0_ext_write_pulse[2] ? lbc_cdm_data[23:20] : cfg_cxl_2_0_ext_next_ptr[3:0];
            cfg_cxl_2_0_ext_next_ptr[11:4] <= #TP cxl_2_0_ext_write_pulse[3] ? lbc_cdm_data[31:24] : cfg_cxl_2_0_ext_next_ptr[11:4];
        end else if (!cxl_2_0_ext_next_ptr_wr_updated) begin
            cfg_cxl_2_0_ext_next_ptr[11:0] <= #TP upstream_port ? `CXL_2_0_EXT_NEXT_PTR : `DM_RP_CXL_2_0_EXT_NEXT_PTR;
        end    
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cxl_2_0_ext_next_ptr_wr_updated  <= #TP 1'b0;
    end
    else begin
        if (cxl_2_0_ext_reg_id[0] && int_lbc_cdm_dbi && |cxl_2_0_ext_write_pulse[3:2]) begin
        cxl_2_0_ext_next_ptr_wr_updated  <= #TP 1'b1;
        end    
    end
end


// -----------------------------------------------------------------------------
// Designated Vendor Specific Header 1 Register
// -----------------------------------------------------------------------------
// cxl_2_0_ext_reg_id     - 1
// PCIE Offset      - `CXL_2_0_EXT_PTR + 04h
// length           - 4 byte
// Cfig register    - cxl_2_0_ext_reg_07, cxl_2_0_ext_reg_06, cxl_2_0_ext_reg_05, cxl_2_0_ext_reg_04
// -----------------------------------------------------------------------------
reg     [15:0]  cfg_cxl_2_0_ext_vid;
reg     [3:0]   cfg_cxl_2_0_ext_dvsec_ver;
reg     [11:0]  cfg_cxl_2_0_ext_len0;

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_2_0_ext_vid       <= #TP `PCIE_CXL_2_0_EXT_VENDOR_ID;
        cfg_cxl_2_0_ext_dvsec_ver <= #TP `PCIE_CXL_2_0_EXT_VER;
        cfg_cxl_2_0_ext_len0      <= #TP `CXL_2_0_EXT_DVSEC_SIZE;
    end
    else begin
        // Read-Only registers, but writable through DBI
        cfg_cxl_2_0_ext_vid[7:0]        <= #TP (cxl_2_0_ext_reg_id[1] & cxl_2_0_ext_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_2_0_ext_vid[7:0];
        cfg_cxl_2_0_ext_vid[15:8]       <= #TP (cxl_2_0_ext_reg_id[1] & cxl_2_0_ext_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_2_0_ext_vid[15:8];
        cfg_cxl_2_0_ext_dvsec_ver[3:0]  <= #TP (cxl_2_0_ext_reg_id[1] & cxl_2_0_ext_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_cxl_2_0_ext_dvsec_ver[3:0];
        cfg_cxl_2_0_ext_len0[3:0]       <= #TP (cxl_2_0_ext_reg_id[1] & cxl_2_0_ext_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:20] : cfg_cxl_2_0_ext_len0[3:0];
        cfg_cxl_2_0_ext_len0[11:4]      <= #TP (cxl_2_0_ext_reg_id[1] & cxl_2_0_ext_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_2_0_ext_len0[11:4];
    end
end

assign cxl_2_0_ext_reg_04 = cfg_cxl_2_0_ext_vid[7:0];
assign cxl_2_0_ext_reg_05 = cfg_cxl_2_0_ext_vid[15:8];
assign cxl_2_0_ext_reg_06 = {cfg_cxl_2_0_ext_len0[3:0],cfg_cxl_2_0_ext_dvsec_ver};
assign cxl_2_0_ext_reg_07 = cfg_cxl_2_0_ext_len0[11:4];

// -----------------------------------------------------------------------------
// Designated Vendor Specific Header 2(0x08) and CXL Port Extension Status(0x0Ah)
// -----------------------------------------------------------------------------
// cxl_2_0_ext_reg_id     - 2
// PCIE Offset      - `CXL_2_0_EXT_PTR + 08h
// length           - 4 byte
// Cfig register    - cxl_2_0_ext_reg_11, cxl_2_0_ext_reg_10, cxl_2_0_ext_reg_09, cxl_2_0_ext_reg_08
// -----------------------------------------------------------------------------

reg     [15:0]  cfg_cxl_2_0_ext_dvsec_id0;                // [15:0]
reg             cfg_cxl_2_0_ext_pm_init_cmpl;

assign cxl_2_0_ext_reg_08 = cfg_cxl_2_0_ext_dvsec_id0[7:0];
assign cxl_2_0_ext_reg_09 = cfg_cxl_2_0_ext_dvsec_id0[15:8];
assign cxl_2_0_ext_reg_10 = {7'h00, cfg_cxl_2_0_ext_pm_init_cmpl};
assign cxl_2_0_ext_reg_11 = {1'b0, cfg_cxl_2_0_ext_viral_status, 6'h00};

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_2_0_ext_dvsec_id0       <= #TP `PCIE_CXL_2_0_EXT_DVSEC_ID;               
    end
    else begin
        cfg_cxl_2_0_ext_dvsec_id0[7:0]  <= #TP (cxl_2_0_ext_reg_id[2] & cxl_2_0_ext_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_2_0_ext_dvsec_id0[7:0];
        cfg_cxl_2_0_ext_dvsec_id0[15:8] <= #TP (cxl_2_0_ext_reg_id[2] & cxl_2_0_ext_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_2_0_ext_dvsec_id0[15:8];
    end
end

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin 
    if ( !non_sticky_rst_n ) begin
      cfg_cxl_2_0_ext_pm_init_cmpl    <= #TP 1'b0;               
    end
    else begin
      cfg_cxl_2_0_ext_pm_init_cmpl    <= #TP cxl_pm_init_cmpl ;
    end
end

wire viral_status_clr;
assign viral_status_clr = cxl_2_0_ext_reg_id[2] & cxl_2_0_ext_write_pulse[3] & lbc_cdm_data[30];

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
      cfg_cxl_2_0_ext_viral_status    <= #TP 1'b0;               
    end
    else begin
      cfg_cxl_2_0_ext_viral_status    <= #TP 1'b0;                     
    end
end


// --------------------------------------------------------------------------------------
// Port Control Override Register (0Ch) and Alternate Bus Base/ Alternate Bus Limit Register (0Eh)
// --------------------------------------------------------------------------------------
// cxl_2_0_ext_reg_id     - 3
// PCIE Offset      - `CXL_2_0_EXT_PTR + 0Ch
// length           - 4 byte
// Cfig register    - cxl_2_0_ext_reg_15, cxl_2_0_ext_reg_14, cxl_2_0_ext_reg_13, cxl_2_0_ext_reg_12
// --------------------------------------------------------------------------------------


// ---------------------------------------------------------------
// Port Control Override Register (0x0c)
// ---------------------------------------------------------------

assign cxl_2_0_ext_reg_12 = {4'h0, cfg_cxl_2_0_ext_alt_bme, cfg_cxl_2_0_ext_alt_mse, cfg_cxl_2_0_ext_unmask_ld, cfg_cxl_2_0_ext_unmask_sbr};
assign cxl_2_0_ext_reg_13 = {1'b0, cfg_cxl_2_0_ext_viral_en, 6'h00};

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin 
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_2_0_ext_unmask_sbr   <= #TP 0;
        cfg_cxl_2_0_ext_unmask_ld    <= #TP 0;
        cfg_cxl_2_0_ext_alt_mse      <= #TP 0;
        cfg_cxl_2_0_ext_alt_bme      <= #TP 0;
        cfg_cxl_2_0_ext_viral_en <= #TP 0;        
    end
    else begin
        cfg_cxl_2_0_ext_unmask_sbr    <= #TP (cxl_2_0_ext_reg_id[3] & cxl_2_0_ext_write_pulse[0]) ? lbc_cdm_data[0] : cfg_cxl_2_0_ext_unmask_sbr;
        cfg_cxl_2_0_ext_unmask_ld     <= #TP (cxl_2_0_ext_reg_id[3] & cxl_2_0_ext_write_pulse[0]) ? lbc_cdm_data[1] : cfg_cxl_2_0_ext_unmask_ld;
        cfg_cxl_2_0_ext_alt_mse       <= #TP (cxl_2_0_ext_reg_id[3] & cxl_2_0_ext_write_pulse[0]) ? lbc_cdm_data[2] : cfg_cxl_2_0_ext_alt_mse;
        cfg_cxl_2_0_ext_alt_bme       <= #TP (cxl_2_0_ext_reg_id[3] & cxl_2_0_ext_write_pulse[0]) ? lbc_cdm_data[3] : cfg_cxl_2_0_ext_alt_bme; 
        cfg_cxl_2_0_ext_viral_en <= #TP 1'b0;        
    end
end

// ------------------------------------------------------------------
// Alternate Bus Base/ Alternate Bus Limit Register (0x0e)
// ------------------------------------------------------------------

assign cxl_2_0_ext_reg_14 = cfg_cxl_2_0_ext_alt_bus_base; 
assign cxl_2_0_ext_reg_15 = cfg_cxl_2_0_ext_alt_bus_limit; 

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin 
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_2_0_ext_alt_bus_base    <= #TP 0;
        cfg_cxl_2_0_ext_alt_bus_limit   <= #TP 0;
    end
    else begin
        cfg_cxl_2_0_ext_alt_bus_base   <= #TP (cxl_2_0_ext_reg_id[3] & cxl_2_0_ext_write_pulse[2]) ? lbc_cdm_data[23:16] : cfg_cxl_2_0_ext_alt_bus_base;
        cfg_cxl_2_0_ext_alt_bus_limit  <= #TP (cxl_2_0_ext_reg_id[3] & cxl_2_0_ext_write_pulse[3]) ? lbc_cdm_data[31:24] : cfg_cxl_2_0_ext_alt_bus_limit;
    end
end


// --------------------------------------------------------------------------------------
// Alternate Memory Base (0x10) and Alternate Memory Limit (0x12)
// --------------------------------------------------------------------------------------
// cxl_2_0_ext_reg_id  - 4
// PCIE Offset      - `CXL_2_0_EXT_PTR + 10h
// length           - 4 byte
// Cfig register    - cxl_2_0_ext_reg_19, cxl_2_0_ext_reg_18, cxl_2_0_ext_reg_17, cxl_2_0_ext_reg_16
// --------------------------------------------------------------------------------------

// ------------------------------------------------------------------
// Alternate Memory Base Register (0x10)
// ------------------------------------------------------------------

assign cxl_2_0_ext_reg_16 = {cfg_cxl_2_0_ext_alt_mem_base[3:0], 4'h0}; 
assign cxl_2_0_ext_reg_17 = cfg_cxl_2_0_ext_alt_mem_base[11:4]; 

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin 
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_2_0_ext_alt_mem_base    <= #TP 0;
    end
    else begin
        cfg_cxl_2_0_ext_alt_mem_base[3:0]   <= #TP (cxl_2_0_ext_reg_id[4] & cxl_2_0_ext_write_pulse[0]) ? lbc_cdm_data[7:4] : cfg_cxl_2_0_ext_alt_mem_base[3:0];
        cfg_cxl_2_0_ext_alt_mem_base[11:4]  <= #TP (cxl_2_0_ext_reg_id[4] & cxl_2_0_ext_write_pulse[1]) ? lbc_cdm_data[15:8] : cfg_cxl_2_0_ext_alt_mem_base[11:4];
    end
end

// ------------------------------------------------------------------
// Alternate Memory Base Limit (0x12)
// ------------------------------------------------------------------

assign cxl_2_0_ext_reg_18 = {cfg_cxl_2_0_ext_alt_mem_limit[3:0], 4'h0}; 
assign cxl_2_0_ext_reg_19 = cfg_cxl_2_0_ext_alt_mem_limit[11:4]; 

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin 
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_2_0_ext_alt_mem_limit    <= #TP 0;
    end
    else begin
        cfg_cxl_2_0_ext_alt_mem_limit[3:0]   <= #TP (cxl_2_0_ext_reg_id[4] & cxl_2_0_ext_write_pulse[2]) ? lbc_cdm_data[23:20] : cfg_cxl_2_0_ext_alt_mem_limit[3:0];
        cfg_cxl_2_0_ext_alt_mem_limit[11:4]  <= #TP (cxl_2_0_ext_reg_id[4] & cxl_2_0_ext_write_pulse[3]) ? lbc_cdm_data[31:24] : cfg_cxl_2_0_ext_alt_mem_limit[11:4];
    end
end


// --------------------------------------------------------------------------------------
// Alternate Preftechable Memory Base (0x14) and Alternate Prefetchable Memory Limit (0x16)
// --------------------------------------------------------------------------------------
// cxl_2_0_ext_reg_id  - 5
// PCIE Offset      - `CXL_2_0_EXT_PTR + 14h
// length           - 4 byte
// Cfig register    - cxl_2_0_ext_reg_23, cxl_2_0_ext_reg_22, cxl_2_0_ext_reg_21, cxl_2_0_ext_reg_20
// --------------------------------------------------------------------------------------

// ------------------------------------------------------------------
// Alternate Prefetchable Memory Base Register (0x14)
// ------------------------------------------------------------------

assign cxl_2_0_ext_reg_20 = {cfg_cxl_2_0_ext_alt_pref_mem_base[3:0], 4'h0}; 
assign cxl_2_0_ext_reg_21 = cfg_cxl_2_0_ext_alt_pref_mem_base[11:4]; 

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin 
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_2_0_ext_alt_pref_mem_base    <= #TP 0;
    end
    else begin
        cfg_cxl_2_0_ext_alt_pref_mem_base[3:0]   <= #TP (cxl_2_0_ext_reg_id[5] & cxl_2_0_ext_write_pulse[0]) ? lbc_cdm_data[7:4] : cfg_cxl_2_0_ext_alt_pref_mem_base[3:0];
        cfg_cxl_2_0_ext_alt_pref_mem_base[11:4]  <= #TP (cxl_2_0_ext_reg_id[5] & cxl_2_0_ext_write_pulse[1]) ? lbc_cdm_data[15:8] : cfg_cxl_2_0_ext_alt_pref_mem_base[11:4];
    end
end


// ------------------------------------------------------------------
// Alternate Prefetchable Memory Base Limit (0x16)
// ------------------------------------------------------------------

assign cxl_2_0_ext_reg_22 = {cfg_cxl_2_0_ext_alt_pref_mem_limit[3:0], 4'h0}; 
assign cxl_2_0_ext_reg_23 = cfg_cxl_2_0_ext_alt_pref_mem_limit[11:4]; 

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin 
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_2_0_ext_alt_pref_mem_limit    <= #TP 0;
    end
    else begin
        cfg_cxl_2_0_ext_alt_pref_mem_limit[3:0]   <= #TP (cxl_2_0_ext_reg_id[5] & cxl_2_0_ext_write_pulse[2]) ? lbc_cdm_data[23:20] : cfg_cxl_2_0_ext_alt_pref_mem_limit[3:0];
        cfg_cxl_2_0_ext_alt_pref_mem_limit[11:4]  <= #TP (cxl_2_0_ext_reg_id[5] & cxl_2_0_ext_write_pulse[3]) ? lbc_cdm_data[31:24] : cfg_cxl_2_0_ext_alt_pref_mem_limit[11:4];
    end
end

// --------------------------------------------------------------------------------------
// Alternate Preftechable Memory Base High (0x18) 
// --------------------------------------------------------------------------------------
// cxl_2_0_ext_reg_id  - 6
// PCIE Offset      - `CXL_2_0_EXT_PTR + 18h
// length           - 4 byte
// Cfig register    - cxl_2_0_ext_reg_27, cxl_2_0_ext_reg_26, cxl_2_0_ext_reg_25, cxl_2_0_ext_reg_24
// --------------------------------------------------------------------------------------

assign cxl_2_0_ext_reg_24 = cfg_cxl_2_0_ext_alt_pref_mem_base_high[7:0]; 
assign cxl_2_0_ext_reg_25 = cfg_cxl_2_0_ext_alt_pref_mem_base_high[15:8];
assign cxl_2_0_ext_reg_26 = cfg_cxl_2_0_ext_alt_pref_mem_base_high[23:16]; 
assign cxl_2_0_ext_reg_27 = cfg_cxl_2_0_ext_alt_pref_mem_base_high[31:24]; 

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin 
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_2_0_ext_alt_pref_mem_base_high    <= #TP 0;
    end
    else begin
        cfg_cxl_2_0_ext_alt_pref_mem_base_high[7:0]    <= #TP (cxl_2_0_ext_reg_id[6] & cxl_2_0_ext_write_pulse[0]) ? lbc_cdm_data[7:0] : cfg_cxl_2_0_ext_alt_pref_mem_base_high[7:0];
        cfg_cxl_2_0_ext_alt_pref_mem_base_high[15:8]   <= #TP (cxl_2_0_ext_reg_id[6] & cxl_2_0_ext_write_pulse[1]) ? lbc_cdm_data[15:8] : cfg_cxl_2_0_ext_alt_pref_mem_base_high[15:8];
        cfg_cxl_2_0_ext_alt_pref_mem_base_high[23:16]  <= #TP (cxl_2_0_ext_reg_id[6] & cxl_2_0_ext_write_pulse[2]) ? lbc_cdm_data[23:16] : cfg_cxl_2_0_ext_alt_pref_mem_base_high[23:16];
        cfg_cxl_2_0_ext_alt_pref_mem_base_high[31:24]  <= #TP (cxl_2_0_ext_reg_id[6] & cxl_2_0_ext_write_pulse[3]) ? lbc_cdm_data[31:24] : cfg_cxl_2_0_ext_alt_pref_mem_base_high[31:24];        
    end
end

// --------------------------------------------------------------------------------------
// Alternate Preftechable Memory Limit High (0x1C) 
// --------------------------------------------------------------------------------------
// cxl_2_0_ext_reg_id  - 7
// PCIE Offset      - `CXL_2_0_EXT_PTR + 1Ch
// length           - 4 byte
// Cfig register    - cxl_2_0_ext_reg_31, cxl_2_0_ext_reg_30, cxl_2_0_ext_reg_29, cxl_2_0_ext_reg_28
// --------------------------------------------------------------------------------------

assign cxl_2_0_ext_reg_28 = cfg_cxl_2_0_ext_alt_pref_mem_limit_high[7:0];
assign cxl_2_0_ext_reg_29 = cfg_cxl_2_0_ext_alt_pref_mem_limit_high[15:8];
assign cxl_2_0_ext_reg_30 = cfg_cxl_2_0_ext_alt_pref_mem_limit_high[23:16];
assign cxl_2_0_ext_reg_31 = cfg_cxl_2_0_ext_alt_pref_mem_limit_high[31:24]; 

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin 
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_2_0_ext_alt_pref_mem_limit_high    <= #TP 0;
    end
    else begin
        cfg_cxl_2_0_ext_alt_pref_mem_limit_high[7:0]    <= #TP (cxl_2_0_ext_reg_id[7] & cxl_2_0_ext_write_pulse[0]) ? lbc_cdm_data[7:0] : cfg_cxl_2_0_ext_alt_pref_mem_limit_high[7:0];
        cfg_cxl_2_0_ext_alt_pref_mem_limit_high[15:8]   <= #TP (cxl_2_0_ext_reg_id[7] & cxl_2_0_ext_write_pulse[1]) ? lbc_cdm_data[15:8] : cfg_cxl_2_0_ext_alt_pref_mem_limit_high[15:8];
        cfg_cxl_2_0_ext_alt_pref_mem_limit_high[23:16]  <= #TP (cxl_2_0_ext_reg_id[7] & cxl_2_0_ext_write_pulse[2]) ? lbc_cdm_data[23:16] : cfg_cxl_2_0_ext_alt_pref_mem_limit_high[23:16];
        cfg_cxl_2_0_ext_alt_pref_mem_limit_high[31:24]  <= #TP (cxl_2_0_ext_reg_id[7] & cxl_2_0_ext_write_pulse[3]) ? lbc_cdm_data[31:24] : cfg_cxl_2_0_ext_alt_pref_mem_limit_high[31:24];        
    end
end

// --------------------------------------------------------------------------------------
// CXL RCRB Base (0x20) 
// --------------------------------------------------------------------------------------
// cxl_2_0_ext_reg_id  - 8
// PCIE Offset      - `CXL_2_0_EXT_PTR + 20h
// length           - 4 byte
// Cfig register    - cxl_2_0_ext_reg_35, cxl_2_0_ext_reg_34, cxl_2_0_ext_reg_33, cxl_2_0_ext_reg_32
// --------------------------------------------------------------------------------------

assign cxl_2_0_ext_reg_32 = {7'd0, cfg_cxl_2_0_ext_rcrb_en};
assign cxl_2_0_ext_reg_33 = {cfg_cxl_2_0_ext_rcrb_base_addr_low[2:0], 5'd0};
assign cxl_2_0_ext_reg_34 = cfg_cxl_2_0_ext_rcrb_base_addr_low[10:3];
assign cxl_2_0_ext_reg_35 = cfg_cxl_2_0_ext_rcrb_base_addr_low[18:11];


always @( posedge aux_clk or negedge non_sticky_rst_n ) begin 
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_2_0_ext_rcrb_en             <= #TP 0;
        cfg_cxl_2_0_ext_rcrb_base_addr_low  <= #TP 0;
    end
    else if (~upstream_port) begin
        cfg_cxl_2_0_ext_rcrb_en                    <= #TP (cxl_2_0_ext_reg_id[8] & cxl_2_0_ext_write_pulse[0]) ? lbc_cdm_data[0] : cfg_cxl_2_0_ext_rcrb_en;    
        cfg_cxl_2_0_ext_rcrb_base_addr_low[2:0]    <= #TP (cxl_2_0_ext_reg_id[8] & cxl_2_0_ext_write_pulse[1]) ? lbc_cdm_data[15:13] : cfg_cxl_2_0_ext_rcrb_base_addr_low[2:0];
        cfg_cxl_2_0_ext_rcrb_base_addr_low[10:3]   <= #TP (cxl_2_0_ext_reg_id[8] & cxl_2_0_ext_write_pulse[2]) ? lbc_cdm_data[23:16] : cfg_cxl_2_0_ext_rcrb_base_addr_low[10:3];
        cfg_cxl_2_0_ext_rcrb_base_addr_low[18:11]  <= #TP (cxl_2_0_ext_reg_id[8] & cxl_2_0_ext_write_pulse[3]) ? lbc_cdm_data[31:24] : cfg_cxl_2_0_ext_rcrb_base_addr_low[18:11];
    end
end


// --------------------------------------------------------------------------------------
// CXL RCRB Base High (0x24) 
// --------------------------------------------------------------------------------------
// cxl_2_0_ext_reg_id  - 9
// PCIE Offset      - `CXL_2_0_EXT_PTR + 24h
// length           - 4 byte
// Cfig register    - cxl_2_0_ext_reg_39, cxl_2_0_ext_reg_38, cxl_2_0_ext_reg_37, cxl_2_0_ext_reg_36
// --------------------------------------------------------------------------------------

assign cxl_2_0_ext_reg_36 = cfg_cxl_2_0_ext_rcrb_base_addr_high[7:0];
assign cxl_2_0_ext_reg_37 = cfg_cxl_2_0_ext_rcrb_base_addr_high[15:8];
assign cxl_2_0_ext_reg_38 = cfg_cxl_2_0_ext_rcrb_base_addr_high[23:16];
assign cxl_2_0_ext_reg_39 = cfg_cxl_2_0_ext_rcrb_base_addr_high[31:24]; 

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin 
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_2_0_ext_rcrb_base_addr_high    <= #TP 0;
    end
    else if (~upstream_port) begin
        cfg_cxl_2_0_ext_rcrb_base_addr_high[7:0]    <= #TP (cxl_2_0_ext_reg_id[9] & cxl_2_0_ext_write_pulse[0]) ? lbc_cdm_data[7:0] : cfg_cxl_2_0_ext_rcrb_base_addr_high[7:0];
        cfg_cxl_2_0_ext_rcrb_base_addr_high[15:8]   <= #TP (cxl_2_0_ext_reg_id[9] & cxl_2_0_ext_write_pulse[1]) ? lbc_cdm_data[15:8] : cfg_cxl_2_0_ext_rcrb_base_addr_high[15:8];
        cfg_cxl_2_0_ext_rcrb_base_addr_high[23:16]  <= #TP (cxl_2_0_ext_reg_id[9] & cxl_2_0_ext_write_pulse[2]) ? lbc_cdm_data[23:16] : cfg_cxl_2_0_ext_rcrb_base_addr_high[23:16];
        cfg_cxl_2_0_ext_rcrb_base_addr_high[31:24]  <= #TP (cxl_2_0_ext_reg_id[9] & cxl_2_0_ext_write_pulse[3]) ? lbc_cdm_data[31:24] : cfg_cxl_2_0_ext_rcrb_base_addr_high[31:24];        
    end
end


// =============================================================================
// Register Read Operation
// =============================================================================

always @(*)
begin : read_data_PROC
    unique case (1'b1)
        cxl_2_0_ext_reg_id[0]  : cxl_2_0_ext_reg_data = {cxl_2_0_ext_reg_03, cxl_2_0_ext_reg_02, cxl_2_0_ext_reg_01, cxl_2_0_ext_reg_00};   // 0x00
        cxl_2_0_ext_reg_id[1]  : cxl_2_0_ext_reg_data = {cxl_2_0_ext_reg_07, cxl_2_0_ext_reg_06, cxl_2_0_ext_reg_05, cxl_2_0_ext_reg_04};   // 0x04
        cxl_2_0_ext_reg_id[2]  : cxl_2_0_ext_reg_data = {cxl_2_0_ext_reg_11, cxl_2_0_ext_reg_10, cxl_2_0_ext_reg_09, cxl_2_0_ext_reg_08};   // 0x08
        cxl_2_0_ext_reg_id[3]  : cxl_2_0_ext_reg_data = {cxl_2_0_ext_reg_15, cxl_2_0_ext_reg_14, cxl_2_0_ext_reg_13, cxl_2_0_ext_reg_12};   // 0x0C
        cxl_2_0_ext_reg_id[4]  : cxl_2_0_ext_reg_data = {cxl_2_0_ext_reg_19, cxl_2_0_ext_reg_18, cxl_2_0_ext_reg_17, cxl_2_0_ext_reg_16};   // 0x10
        cxl_2_0_ext_reg_id[5]  : cxl_2_0_ext_reg_data = {cxl_2_0_ext_reg_23, cxl_2_0_ext_reg_22, cxl_2_0_ext_reg_21, cxl_2_0_ext_reg_20};   // 0x14
        cxl_2_0_ext_reg_id[6]  : cxl_2_0_ext_reg_data = {cxl_2_0_ext_reg_27, cxl_2_0_ext_reg_26, cxl_2_0_ext_reg_25, cxl_2_0_ext_reg_24};   // 0x18
        cxl_2_0_ext_reg_id[7]  : cxl_2_0_ext_reg_data = {cxl_2_0_ext_reg_31, cxl_2_0_ext_reg_30, cxl_2_0_ext_reg_29, cxl_2_0_ext_reg_28};   // 0x1C
        cxl_2_0_ext_reg_id[8]  : cxl_2_0_ext_reg_data = {cxl_2_0_ext_reg_35, cxl_2_0_ext_reg_34, cxl_2_0_ext_reg_33, cxl_2_0_ext_reg_32};   // 0x20
        cxl_2_0_ext_reg_id[9]  : cxl_2_0_ext_reg_data = {cxl_2_0_ext_reg_39, cxl_2_0_ext_reg_38, cxl_2_0_ext_reg_37, cxl_2_0_ext_reg_36};   // 0x24
        default                : cxl_2_0_ext_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end

endmodule // cdm_cxl_2_0_ext_reg
