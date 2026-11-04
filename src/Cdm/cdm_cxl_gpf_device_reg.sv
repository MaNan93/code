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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_cxl_gpf_device_reg.sv#2 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the CXL Device GPF DVSEC Extended Capability regsiters.
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_cxl_gpf_device_reg
#(

    parameter INST          = 0 
   ,parameter NCXL_GPF_DEVICE  = `CXL_GPF_DEVICE_DVSEC_SIZE>>2    // Number of registers in CXL Device GPF DVSEC Extended Capability Structure
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
   input   [3:0]              cxl_gpf_device_write_pulse,
   input   [NCXL_GPF_DEVICE-1:0] cxl_gpf_device_reg_id,
   input                      upstream_port,


// -- Outputs --
   output reg [31:0]          cxl_gpf_device_reg_data                      // Data read from the register
);

wire    [7:0]   cxl_gpf_device_reg_03, cxl_gpf_device_reg_02, cxl_gpf_device_reg_01, cxl_gpf_device_reg_00;
wire    [7:0]   cxl_gpf_device_reg_07, cxl_gpf_device_reg_06, cxl_gpf_device_reg_05, cxl_gpf_device_reg_04;
wire    [7:0]   cxl_gpf_device_reg_11, cxl_gpf_device_reg_10, cxl_gpf_device_reg_09, cxl_gpf_device_reg_08;
wire    [7:0]   cxl_gpf_device_reg_15, cxl_gpf_device_reg_14, cxl_gpf_device_reg_13, cxl_gpf_device_reg_12;

wire            int_lbc_cdm_dbi;
assign          int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;


// -----------------------------------------------------------------------------
// CXL Device GPF DVSEC Extended Capability Header Register
// -----------------------------------------------------------------------------
// cxl_gpf_device_reg_id     - 0
// PCIE Offset      - `CXL_GPF_DEVICE_PTR
// length           - 4 byte
// Cfig register    - cxl_gpf_device_reg_03, cxl_gpf_device_reg_02, cxl_gpf_device_reg_01, cxl_gpf_device_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_cxl_gpf_device_id;                 // CXL Device GPF DVSEC Capability ID
reg [3:0]   cfg_cxl_gpf_device_ver;                // CXL Device GPF DVSEC Capability Version
reg [11:0]  cfg_cxl_gpf_device_next_ptr;           // CXL Device GPF DVSEC Next Capability Offset
reg         cxl_gpf_device_next_ptr_wr_updated;

assign cxl_gpf_device_reg_00 = cfg_cxl_gpf_device_id[7:0];
assign cxl_gpf_device_reg_01 = cfg_cxl_gpf_device_id[15:8];
assign cxl_gpf_device_reg_02 = {cfg_cxl_gpf_device_next_ptr[3:0], cfg_cxl_gpf_device_ver};
assign cxl_gpf_device_reg_03 = cfg_cxl_gpf_device_next_ptr[11:4];

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_gpf_device_id[15:0]    <= #TP `PCIE_CXL_GPF_DEVICE_ECAP_ID;      // Capability ID = 16'h0023
        cfg_cxl_gpf_device_ver[3:0]    <= #TP `PCIE_CXL_GPF_DEVICE_ECAP_VER;     // Capability version = 4'h1
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_cxl_gpf_device_id[7:0]     <= #TP (cxl_gpf_device_reg_id[0] & cxl_gpf_device_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_gpf_device_id[7:0];
        cfg_cxl_gpf_device_id[15:8]    <= #TP (cxl_gpf_device_reg_id[0] & cxl_gpf_device_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_gpf_device_id[15:8];
        cfg_cxl_gpf_device_ver[3:0]    <= #TP (cxl_gpf_device_reg_id[0] & cxl_gpf_device_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_cxl_gpf_device_ver[3:0];
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_gpf_device_next_ptr[11:0] <= #TP `CXL_GPF_DEVICE_NEXT_PTR;
    end
    else begin
        if (cxl_gpf_device_reg_id[0] && int_lbc_cdm_dbi) begin
        // Read-Only registers, but writable through DBI
            cfg_cxl_gpf_device_next_ptr[3:0]  <= #TP cxl_gpf_device_write_pulse[2] ? lbc_cdm_data[23:20] : cfg_cxl_gpf_device_next_ptr[3:0];
            cfg_cxl_gpf_device_next_ptr[11:4] <= #TP cxl_gpf_device_write_pulse[3] ? lbc_cdm_data[31:24] : cfg_cxl_gpf_device_next_ptr[11:4];
        end else if (!cxl_gpf_device_next_ptr_wr_updated) begin
            cfg_cxl_gpf_device_next_ptr[11:0] <= #TP upstream_port ? `CXL_GPF_DEVICE_NEXT_PTR : `DM_RP_CXL_GPF_DEVICE_NEXT_PTR;
        end    
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cxl_gpf_device_next_ptr_wr_updated  <= #TP 1'b0;
    end
    else begin
        if (cxl_gpf_device_reg_id[0] && int_lbc_cdm_dbi && |cxl_gpf_device_write_pulse[3:2]) begin
        cxl_gpf_device_next_ptr_wr_updated  <= #TP 1'b1;
        end    
    end
end


// -----------------------------------------------------------------------------
// Designated Vendor Specific Header 1 Register
// -----------------------------------------------------------------------------
// cxl_gpf_device_reg_id     - 1
// PCIE Offset      - `CXL_GPF_DEVICE_PTR + 04h
// length           - 4 byte
// Cfig register    - cxl_gpf_device_reg_07, cxl_gpf_device_reg_06, cxl_gpf_device_reg_05, cxl_gpf_device_reg_04
// -----------------------------------------------------------------------------
reg     [15:0]  cfg_cxl_gpf_device_vid;
reg     [3:0]   cfg_cxl_gpf_device_dvsec_ver;
reg     [11:0]  cfg_cxl_gpf_device_len0;

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_gpf_device_vid       <= #TP `PCIE_CXL_GPF_DEVICE_VENDOR_ID;
        cfg_cxl_gpf_device_dvsec_ver <= #TP `PCIE_CXL_GPF_DEVICE_VER;
        cfg_cxl_gpf_device_len0      <= #TP `CXL_GPF_DEVICE_DVSEC_SIZE;
    end
    else begin
        // Read-Only registers, but writable through DBI
        cfg_cxl_gpf_device_vid[7:0]        <= #TP (cxl_gpf_device_reg_id[1] & cxl_gpf_device_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_gpf_device_vid[7:0];
        cfg_cxl_gpf_device_vid[15:8]       <= #TP (cxl_gpf_device_reg_id[1] & cxl_gpf_device_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_gpf_device_vid[15:8];
        cfg_cxl_gpf_device_dvsec_ver[3:0]  <= #TP (cxl_gpf_device_reg_id[1] & cxl_gpf_device_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_cxl_gpf_device_dvsec_ver[3:0];
        cfg_cxl_gpf_device_len0[3:0]       <= #TP (cxl_gpf_device_reg_id[1] & cxl_gpf_device_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:20] : cfg_cxl_gpf_device_len0[3:0];
        cfg_cxl_gpf_device_len0[11:4]      <= #TP (cxl_gpf_device_reg_id[1] & cxl_gpf_device_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_gpf_device_len0[11:4];
    end
end

assign cxl_gpf_device_reg_04 = cfg_cxl_gpf_device_vid[7:0];
assign cxl_gpf_device_reg_05 = cfg_cxl_gpf_device_vid[15:8];
assign cxl_gpf_device_reg_06 = {cfg_cxl_gpf_device_len0[3:0], cfg_cxl_gpf_device_dvsec_ver};
assign cxl_gpf_device_reg_07 = cfg_cxl_gpf_device_len0[11:4];

// -----------------------------------------------------------------------------
// Designated Vendor Specific Header 2(0x08) & GPF Phase 2 Duration (0x0A)
// -----------------------------------------------------------------------------
// cxl_gpf_device_reg_id     - 2
// PCIE Offset      - `CXL_GPF_DEVICE_PTR + 08h
// length           - 4 byte
// Cfig register    - cxl_gpf_device_reg_11, cxl_gpf_device_reg_10, cxl_gpf_device_reg_09, cxl_gpf_device_reg_08
// -----------------------------------------------------------------------------

reg     [15:0]  cfg_cxl_gpf_device_dvsec_id0;                // [15:0]

assign cxl_gpf_device_reg_08 = cfg_cxl_gpf_device_dvsec_id0[7:0];
assign cxl_gpf_device_reg_09 = cfg_cxl_gpf_device_dvsec_id0[15:8];

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_cxl_gpf_device_dvsec_id0       <= #TP `PCIE_CXL_GPF_DEVICE_DVSEC_ID;               
    end
    else begin
        cfg_cxl_gpf_device_dvsec_id0[7:0]  <= #TP (cxl_gpf_device_reg_id[2] & cxl_gpf_device_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_gpf_device_dvsec_id0[7:0];
        cfg_cxl_gpf_device_dvsec_id0[15:8] <= #TP (cxl_gpf_device_reg_id[2] & cxl_gpf_device_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_gpf_device_dvsec_id0[15:8];
    end
end
//--------------------------------------------------------------------------------------
// GPF Phase 2 Duration (0x0A)
// -------------------------------------------------------------------------------------

reg [3:0] cxl_gpf_device_p2_time_base;
reg [3:0] cxl_gpf_device_p2_time_scale;

assign cxl_gpf_device_reg_10 = {4'h0, cxl_gpf_device_p2_time_base};
assign cxl_gpf_device_reg_11 = {4'h0, cxl_gpf_device_p2_time_scale};

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cxl_gpf_device_p2_time_base      <= #TP `CX_CXL_DEVICE_GPF_P2_TIME_BASE; 
        cxl_gpf_device_p2_time_scale     <= #TP `CX_CXL_DEVICE_GPF_P2_TIME_SCALE;
    end
    else begin
        cxl_gpf_device_p2_time_base      <= #TP (cxl_gpf_device_reg_id[2] & cxl_gpf_device_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cxl_gpf_device_p2_time_base;
        cxl_gpf_device_p2_time_scale     <= #TP (cxl_gpf_device_reg_id[2] & cxl_gpf_device_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[27:24] : cxl_gpf_device_p2_time_scale;
    end
end

// --------------------------------------------------------------------------------------
// GPF Phase 2 Power (0Ch) 
// --------------------------------------------------------------------------------------
// cxl_gpf_device_reg_id     - 3
// PCIE Offset      - `CXL_GPF_DEVICE_PTR + 0Ch
// length           - 4 byte
// Cfig register    - cxl_gpf_device_reg_15, cxl_gpf_device_reg_14, cxl_gpf_device_reg_13, cxl_gpf_device_reg_12
// --------------------------------------------------------------------------------------

reg [31:0] cxl_gpf_device_p2_actv_pwr;

assign cxl_gpf_device_reg_12 = cxl_gpf_device_p2_actv_pwr[7:0];
assign cxl_gpf_device_reg_13 = cxl_gpf_device_p2_actv_pwr[15:8];
assign cxl_gpf_device_reg_14 = cxl_gpf_device_p2_actv_pwr[23:16];
assign cxl_gpf_device_reg_15 = cxl_gpf_device_p2_actv_pwr[31:24];

always @( posedge aux_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cxl_gpf_device_p2_actv_pwr     <= #TP `CX_CXL_DEVICE_GPF_P2_ACTIVE_POWER;
    end
    else begin
        cxl_gpf_device_p2_actv_pwr[7:0]   <= #TP (cxl_gpf_device_reg_id[3] & cxl_gpf_device_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cxl_gpf_device_p2_actv_pwr[7:0];
        cxl_gpf_device_p2_actv_pwr[15:8]  <= #TP (cxl_gpf_device_reg_id[3] & cxl_gpf_device_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cxl_gpf_device_p2_actv_pwr[15:8]; 
        cxl_gpf_device_p2_actv_pwr[23:16] <= #TP (cxl_gpf_device_reg_id[3] & cxl_gpf_device_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cxl_gpf_device_p2_actv_pwr[23:16];
        cxl_gpf_device_p2_actv_pwr[31:24] <= #TP (cxl_gpf_device_reg_id[3] & cxl_gpf_device_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cxl_gpf_device_p2_actv_pwr[31:24];          
    end
end


// =============================================================================
// Register Read Operation
// =============================================================================

always @(*)
begin : read_data_PROC
    unique case (1'b1)
        cxl_gpf_device_reg_id[0]  : cxl_gpf_device_reg_data = {cxl_gpf_device_reg_03, cxl_gpf_device_reg_02, cxl_gpf_device_reg_01, cxl_gpf_device_reg_00};   // 0x00
        cxl_gpf_device_reg_id[1]  : cxl_gpf_device_reg_data = {cxl_gpf_device_reg_07, cxl_gpf_device_reg_06, cxl_gpf_device_reg_05, cxl_gpf_device_reg_04};   // 0x04
        cxl_gpf_device_reg_id[2]  : cxl_gpf_device_reg_data = {cxl_gpf_device_reg_11, cxl_gpf_device_reg_10, cxl_gpf_device_reg_09, cxl_gpf_device_reg_08};   // 0x08
        cxl_gpf_device_reg_id[3]  : cxl_gpf_device_reg_data = {cxl_gpf_device_reg_15, cxl_gpf_device_reg_14, cxl_gpf_device_reg_13, cxl_gpf_device_reg_12};   // 0x0C
        default                   : cxl_gpf_device_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end

endmodule // cdm_cxl_gpf_device_reg
