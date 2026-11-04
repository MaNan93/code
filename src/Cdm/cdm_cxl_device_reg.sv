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
// ---    $DateTime: 2024/01/19 11:41:19 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_cxl_device_reg.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the CXL Flex Bus Device DVSEC Extended Capability regsiters.
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_cxl_device_reg
#(
    parameter INST          = 0 
   ,parameter NCXL_DEVICE   = `CXL_DEVICE_DVSEC_SIZE>>2              // Number of registers in CXL Flex Bus Device DVSEC Extended Capability Structure
   ,parameter NL            = `CX_NL                                 // Number of Lanes
   ,parameter TP            = `TP
   ,parameter FUNC_NUM      = 0
)

                          (
// -- Inputs --
   input                      aux_clk,                               // Clock          
   input                      non_sticky_rst_n,                      // Reset non_sticky register only      
   input                      sticky_rst_n,                          // Reset sticky register only       
  
   input    [31:0]            lbc_cdm_data, 
   input                      lbc_cdm_dbi,
   input                      dbi_ro_wr_en, 
   input    [3:0]             cxl_dev_write_pulse,                   // Write pulse for the Flex Bus Device DVSEC Registers
   input    [NCXL_DEVICE-1:0] cxl_dev_reg_id,                        // Register Selection for the Flex Bus DEvice DVSEC

   input                      upstream_port,

   input                      viral_status,                          // CXL device has entered Viral self-isolation mode
   input                      cxl_rcrb_enable,                       // indicates that the CXL 1.1 Link is up for USP supporting RCRB
   input                      cxl_dev_cache_invalid,                 // CXL device indicate cache invalid state
   input                      cxl_dev_cache_wr_invld_cmpl,           // CXL device indicate cache writeback and invalidation is complete state 
   input                      cxl_volatile_hdm_error,                // CXL device indicate Volatile HDM Preservation Error
   input                      cxl_pm_init_cmpl,                  // CXL device PM initalization completion state


// -- Outputs --
   output reg [31:0]          cxl_dev_reg_data,                      // Read data from the Flex Bus Device DVSEC Register

   output reg                 cfg_cxl_dev_cache_enable,              // Enable CXL.cache protocol operation when in Flex Bus.AL mode
   output reg                 cfg_cxl_dev_io_enable,                 // Enable CXL.io operation when in Flex Bus.AL mode
   output reg                 cfg_cxl_dev_mem_enable,                // Enable CXL.mem protocol operation when in Flex Bus.AL mode
   output reg [4:0]           cfg_cxl_dev_cache_sf_coverage,         // Performance hint to the device
   output reg [2:0]           cfg_cxl_dev_cache_sf_granularity,      // Performance hint to the device
   output reg                 cfg_cxl_dev_cache_clean_eviction,      // Performance hint to the device
   output reg                 cfg_cxl_dev_viral_capable,             // Indicates CXL device supports Viral handling.
   output reg                 cfg_cxl_dev_viral_enable,              // Enable Viral Handling
   output reg                 cfg_cxl_dev_cxl_rst_mem_clr_enable,    // Enable clearing or randomization of Volatile HDM ranges during CXL_Reset
   output reg                 cfg_cxl_dev_post_cold_rst_volatile_hdm_default,    // Default Volatile HDM State After Cold Reset
   output reg                 cfg_cxl_dev_post_warm_rst_volatile_hdm_default,    // Default Volatile HDM State After Warm Reset
   output reg                 cfg_cxl_dev_post_hot_rst_volatile_hdm_default,     // Default Volatile HDM State After Hot Reset
   output reg                 cfg_cxl_dev_post_hot_rst_volatile_hdm_desired,     // Desired Volatile HDM State After Hot Reset

   output reg                 cfg_cxl_dev_viral_status,              // Indicates CXL device  Viral Status

   output reg                 cfg_cxl_dev_disable_caching,           // Indicates CXL device Disable Caching control
   output reg                 cfg_cxl_dev_initiate_cache_wr_invld,   // Indicates CXL device Initiate Cache Write Back and Invalidation control
   output reg                 cfg_cxl_dev_initiate_cxl_rst,          // Indicates CXL device Initiate Enhanced FLR control

   output reg [31:0]          cfg_cxl_dev_range1_mem_size_high,      // Corresponds to bits 63:32 of Flex Bus Range 1 memory size
   output reg                 cfg_cxl_dev_range1_mem_info_valid,     // Indicates that the Flex Bus Range 1 Size high and Size Low registers are valid
   output reg                 cfg_cxl_dev_range1_mem_active,         // Indicates that the Flex Bus Range 1 memory is fully initialized and available for software use
   output reg [4:0]           cfg_cxl_dev_range1_desired_interleave, // Represents the memory interleaving desired by the device
   output reg [2:0]           cfg_cxl_dev_range1_mem_active_timeout, // Indicates maximum time that device is permitted to take to set Memory_active bit in this register after a conventional reset 
   output reg [3:0]           cfg_cxl_dev_range1_mem_size_low,       // Corresponds to bits 31:28 of Flex Bus Range 1 memory size

   output reg [31:0]          cfg_cxl_dev_range1_mem_base_high,      // Corresponds to bits 63:32 of Flex Bus Range 1 base in the host address space
   output reg [3:0]           cfg_cxl_dev_range1_mem_base_low,       // Corresponds to bits 31:28 of Flex Bus Range 1 base in the host address space

   output reg [31:0]          cfg_cxl_dev_range2_mem_size_high,      // Corresponds to bits 63:32 of Flex Bus Range 2 memory size
   output reg                 cfg_cxl_dev_range2_mem_info_valid,     // Indicates that the Flex Bus Range 2 Size high and Size Low registersare valid
   output reg                 cfg_cxl_dev_range2_mem_active,         // Indicates that the Flex Bus Range 2 memory is fully initialized and availablefor software use
   output reg [4:0]           cfg_cxl_dev_range2_desired_interleave, // Represents the memory interleaving desired by the device
   output reg [2:0]           cfg_cxl_dev_range2_mem_active_timeout, // Indicates maximum time that device is permitted to take to set Memory_active bit in this register after a conventional reset 
   
   output reg [3:0]           cfg_cxl_dev_range2_mem_size_low,       // Corresponds to bits 31:28 of Flex Bus Range 2 memory size   

   output reg [31:0]          cfg_cxl_dev_range2_mem_base_high,      // Corresponds to bits 63:32 of Flex Bus Range 2 base in the host address space
   output reg [3:0]           cfg_cxl_dev_range2_mem_base_low        // Corresponds to bits 31:28 of Flex Bus Range 2 base in the host address space

);


wire    [7:0]   cxl_dev_reg_03, cxl_dev_reg_02, cxl_dev_reg_01, cxl_dev_reg_00;
wire    [7:0]   cxl_dev_reg_07, cxl_dev_reg_06, cxl_dev_reg_05, cxl_dev_reg_04;
wire    [7:0]   cxl_dev_reg_11, cxl_dev_reg_10, cxl_dev_reg_09, cxl_dev_reg_08;
wire    [7:0]   cxl_dev_reg_15, cxl_dev_reg_14, cxl_dev_reg_13, cxl_dev_reg_12;
wire    [7:0]   cxl_dev_reg_19, cxl_dev_reg_18, cxl_dev_reg_17, cxl_dev_reg_16;
wire    [7:0]   cxl_dev_reg_23, cxl_dev_reg_22, cxl_dev_reg_21, cxl_dev_reg_20;
wire    [7:0]   cxl_dev_reg_27, cxl_dev_reg_26, cxl_dev_reg_25, cxl_dev_reg_24;
wire    [7:0]   cxl_dev_reg_31, cxl_dev_reg_30, cxl_dev_reg_29, cxl_dev_reg_28;
wire    [7:0]   cxl_dev_reg_35, cxl_dev_reg_34, cxl_dev_reg_33, cxl_dev_reg_32;
wire    [7:0]   cxl_dev_reg_39, cxl_dev_reg_38, cxl_dev_reg_37, cxl_dev_reg_36;
wire    [7:0]   cxl_dev_reg_43, cxl_dev_reg_42, cxl_dev_reg_41, cxl_dev_reg_40;
wire    [7:0]   cxl_dev_reg_47, cxl_dev_reg_46, cxl_dev_reg_45, cxl_dev_reg_44;
wire    [7:0]   cxl_dev_reg_51, cxl_dev_reg_50, cxl_dev_reg_49, cxl_dev_reg_48;
wire    [7:0]   cxl_dev_reg_55, cxl_dev_reg_54, cxl_dev_reg_53, cxl_dev_reg_52;
wire    [7:0]   cxl_dev_reg_59, cxl_dev_reg_58, cxl_dev_reg_57, cxl_dev_reg_56;

wire            int_lbc_cdm_dbi;
assign          int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;

// -----------------------------------------------------------------------------
// CXL Flex Bus Device DVSEC Extended Capability Header Register
// -----------------------------------------------------------------------------
// cxl_dev_reg_id     - 0
// PCIE Offset      - `CXL_DEVICE_PTR
// length           - 4 byte
// Cfig register    - cxl_dev_reg_03, cxl_dev_reg_02, cxl_dev_reg_01, cxl_dev_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_cxl_dev_id;                 // CXL Flex Bus Device DVSEC Capability ID
reg [3:0]   cfg_cxl_dev_ver;                // CXL Flex Bus Device DVSEC Capability Version
reg [11:0]  cfg_cxl_dev_next_ptr;           // CXL Flex Bus Device DVSEC Next Capability Offset
reg         cxl_dev_next_ptr_wr_updated;    // Asserted when CXL Flex Bus Device DVSEC Capability header has been changed by a DBI write


assign cxl_dev_reg_00 = cfg_cxl_dev_id[7:0];
assign cxl_dev_reg_01 = cfg_cxl_dev_id[15:8];
assign cxl_dev_reg_02 = {cfg_cxl_dev_next_ptr[3:0], cfg_cxl_dev_ver};
assign cxl_dev_reg_03 = cfg_cxl_dev_next_ptr[11:4];

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_id[15:0]    <= #TP `PCIE_CXL_DEVICE_ECAP_ID;      
        cfg_cxl_dev_ver[3:0]    <= #TP `PCIE_CXL_DEVICE_ECAP_VER;     
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_cxl_dev_id[7:0]     <= #TP (cxl_dev_reg_id[0] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_dev_id[7:0];
        cfg_cxl_dev_id[15:8]    <= #TP (cxl_dev_reg_id[0] & cxl_dev_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_dev_id[15:8];
        cfg_cxl_dev_ver[3:0]    <= #TP (cxl_dev_reg_id[0] & cxl_dev_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_cxl_dev_ver[3:0];
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_next_ptr[11:0] <= #TP `DEVICE_NEXT_PTR;
    end
    else begin
        if (cxl_dev_reg_id[0] && int_lbc_cdm_dbi) begin
        // Read-Only registers, but writable through DBI
            cfg_cxl_dev_next_ptr[3:0]  <= #TP cxl_dev_write_pulse[2] ? lbc_cdm_data[23:20] : cfg_cxl_dev_next_ptr[3:0];
            cfg_cxl_dev_next_ptr[11:4] <= #TP cxl_dev_write_pulse[3] ? lbc_cdm_data[31:24] : cfg_cxl_dev_next_ptr[11:4];
        end else if (!cxl_dev_next_ptr_wr_updated) begin
            cfg_cxl_dev_next_ptr[11:0] <= #TP (cxl_rcrb_enable) ? `CXL_DEVICE_NEXT_PTR :  `DEVICE_NEXT_PTR;
        end
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_next_ptr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        cxl_dev_next_ptr_wr_updated <= #TP 1'b0;
    end 
    else begin
        if (cxl_dev_reg_id[0] && int_lbc_cdm_dbi && |cxl_dev_write_pulse[3:2]) begin
            cxl_dev_next_ptr_wr_updated <= #TP 1'b1;
        end
    end
end


// -----------------------------------------------------------------------------
// Designated Vendor Specific Header 1 Register
// -----------------------------------------------------------------------------
// cxl_dev_reg_id     - 1
// PCIE Offset      - `CXL_DEVICE_PTR + 04h
// length           - 4 byte
// Cfig register    - cxl_dev_reg_07, cxl_dev_reg_06, cxl_dev_reg_05, cxl_dev_reg_04
// -----------------------------------------------------------------------------
reg [15:0]  cfg_cxl_dev_vid;
reg [3:0]   cfg_cxl_dev_dvsec_ver;
reg [11:0]  cfg_cxl_dev_len0;

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_vendor_specific_hdr1_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_vid       <= #TP `PCIE_CXL_DEVICE_VENDOR_ID;
        cfg_cxl_dev_dvsec_ver <= #TP `PCIE_CXL_DEVICE_VER;
        cfg_cxl_dev_len0      <= #TP `CXL_DEVICE_DVSEC_SIZE;
    end
    else begin
        // Read-Only registers, but writable through DBI
        cfg_cxl_dev_vid[7:0]        <= #TP (cxl_dev_reg_id[1] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0]   : cfg_cxl_dev_vid[7:0];
        cfg_cxl_dev_vid[15:8]       <= #TP (cxl_dev_reg_id[1] & cxl_dev_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8]  : cfg_cxl_dev_vid[15:8];
        cfg_cxl_dev_dvsec_ver[3:0]  <= #TP (cxl_dev_reg_id[1] & cxl_dev_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_cxl_dev_dvsec_ver[3:0];
        cfg_cxl_dev_len0[3:0]       <= #TP (cxl_dev_reg_id[1] & cxl_dev_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:20] : cfg_cxl_dev_len0[3:0];
        cfg_cxl_dev_len0[11:4]      <= #TP (cxl_dev_reg_id[1] & cxl_dev_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_dev_len0[11:4];
    end
end

assign cxl_dev_reg_04 = cfg_cxl_dev_vid[7:0];
assign cxl_dev_reg_05 = cfg_cxl_dev_vid[15:8];
assign cxl_dev_reg_06 = {cfg_cxl_dev_len0[3:0],cfg_cxl_dev_dvsec_ver};
assign cxl_dev_reg_07 = cfg_cxl_dev_len0[11:4];

// -----------------------------------------------------------------------------
// Designated Vendor Specific Header 2(0x08) & CXL Flex Bus Device Capability(0x0a)
// -----------------------------------------------------------------------------
// cxl_dev_reg_id     - 2
// PCIE Offset      - `CXL_DEVICE_PTR + 08h
// length           - 4 byte
// Cfig register    - cxl_dev_reg_11, cxl_dev_reg_10, cxl_dev_reg_09, cxl_dev_reg_08
// -----------------------------------------------------------------------------

reg [15:0]  cfg_cxl_dev_dvsec_id0;                // [15:0]

wire        cfg_cxl_dev_io_capable;
assign      cfg_cxl_dev_io_capable = 1'b1;

reg         cfg_cxl_dev_cache_capable;    // Indicates CXL.cache protocol support when operating in Flex Bus.AL mode
reg         cfg_cxl_dev_mem_capable;      // Indicates CXL.mem protocol support when operating in Flex Bus.AL mode
reg         cfg_cxl_dev_mem_hw_init_mode; // If set,indicates this CXL.mem capable device initializes memory with assistance from hardware and firmware located on the device. If clear, indicates memory is initialized by host software such as device driver
reg [1:0]   cfg_cxl_dev_hdm_count;        // Number of HDM ranges implemented by the CXL device and reported through this function
reg         cfg_cxl_dev_cache_wr_invld_capable;// Indicates CXL device supports Cache Writeback and Invalidate Capable:
reg         cfg_cxl_dev_cxl_rst_capable;         // Indicates CXL device supports CXL_Reset Capable
reg [2:0]   cfg_cxl_dev_cxl_rst_timeout;         // Indicates CXL device supports CXL_Reset timeout
reg         cfg_cxl_dev_cxl_rst_mem_clr_capable; // Indicates CXL device supports clearing or randomization of HDM volatile ranges during CXL_Reset
reg         cfg_cxl_logical_device;              // Indicates CXL device is a logical device
reg         cfg_cxl_dev_pm_init_cmpl_rpt_capable;// Indicates CXL device supports Power Management Initialization Completion Reporting Capable:.


assign cxl_dev_reg_08 = cfg_cxl_dev_dvsec_id0[7:0];
assign cxl_dev_reg_09 = cfg_cxl_dev_dvsec_id0[15:8];
assign cxl_dev_reg_10 = {cfg_cxl_dev_cxl_rst_capable,cfg_cxl_dev_cache_wr_invld_capable,cfg_cxl_dev_hdm_count,cfg_cxl_dev_mem_hw_init_mode,cfg_cxl_dev_mem_capable,cfg_cxl_dev_io_capable,cfg_cxl_dev_cache_capable};
assign cxl_dev_reg_11 = {cfg_cxl_dev_pm_init_cmpl_rpt_capable,cfg_cxl_dev_viral_capable,cfg_cxl_logical_device,1'b0,cfg_cxl_dev_cxl_rst_mem_clr_capable,cfg_cxl_dev_cxl_rst_timeout};


always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_vendor_specific_hdr2_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_dvsec_id0       <= #TP `PCIE_CXL_DEVICE_DVSEC_ID;               
    end
    else begin
        cfg_cxl_dev_dvsec_id0[7:0]  <= #TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_dev_dvsec_id0[7:0];
        cfg_cxl_dev_dvsec_id0[15:8] <= #TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_dev_dvsec_id0[15:8];
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_capability_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_cache_capable     <= #TP 1;
        cfg_cxl_dev_mem_capable       <= #TP 1;
        cfg_cxl_dev_mem_hw_init_mode             <= #TP `CX_CXL_MEM_HWINIT_MODE;
        cfg_cxl_dev_hdm_count                    <= #TP `CX_CXL_HDM_COUNT;
        cfg_cxl_dev_cache_wr_invld_capable       <= #TP `CX_CXL_CACHE_WR_INVLD_EN_VALUE;
        cfg_cxl_dev_cxl_rst_capable                 <= #TP 0;
        cfg_cxl_dev_cxl_rst_timeout                 <= #TP 0;
        cfg_cxl_dev_cxl_rst_mem_clr_capable         <= #TP `CX_CXL_RESET_MEM_CLR_EN;    
        cfg_cxl_logical_device                      <= #TP `CX_CXL_LOGICAL_DEVICE_EN; 
        cfg_cxl_dev_viral_capable                   <= #TP `CX_CXL_VIRAL_CAPABLE;
        cfg_cxl_dev_pm_init_cmpl_rpt_capable     <= #TP `CX_CXL_PM_INIT_CMPL_RPT_EN; 
    end
    else begin
        cfg_cxl_dev_cache_capable          <= #TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[16] : cfg_cxl_dev_cache_capable;
        cfg_cxl_dev_mem_capable            <= #TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[18] : cfg_cxl_dev_mem_capable;
        cfg_cxl_dev_mem_hw_init_mode       <= #TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19] : cfg_cxl_dev_mem_hw_init_mode;
        cfg_cxl_dev_hdm_count              <= #TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[21:20] : cfg_cxl_dev_hdm_count;
        cfg_cxl_dev_cache_wr_invld_capable <= #TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[22] : cfg_cxl_dev_cache_wr_invld_capable;
        cfg_cxl_dev_cxl_rst_capable           <= #TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23] : cfg_cxl_dev_cxl_rst_capable;
        cfg_cxl_dev_cxl_rst_timeout           <= #TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[26:24] : cfg_cxl_dev_cxl_rst_timeout;
        cfg_cxl_dev_cxl_rst_mem_clr_capable   <= #TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[27] : cfg_cxl_dev_cxl_rst_mem_clr_capable;
        cfg_cxl_logical_device                <= #TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[29] : cfg_cxl_logical_device;
        cfg_cxl_dev_viral_capable          <= #TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[30] : cfg_cxl_dev_viral_capable;
        cfg_cxl_dev_pm_init_cmpl_rpt_capable <=#TP (cxl_dev_reg_id[2] & cxl_dev_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31] : cfg_cxl_dev_pm_init_cmpl_rpt_capable ;
    end
end


// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Control (0x0C) & CXL Flex Bus Device Status(0x0E)
// --------------------------------------------------------------------------------------
// cxl_dev_reg_id     - 3
// PCIE Offset      - `CXL_DEVICE_PTR + 0Ch
// length           - 4 byte
// Cfig register    - cxl_dev_reg_15, cxl_dev_reg_14, cxl_dev_reg_13, cxl_dev_reg_12
// --------------------------------------------------------------------------------------


// ---------------------------------------------------------------
// CXL Flex Bus Port Control Register (0x0c)
// ---------------------------------------------------------------


wire   config_lock;

assign cxl_dev_reg_12 = {cfg_cxl_dev_cache_sf_coverage, cfg_cxl_dev_mem_enable, cfg_cxl_dev_io_enable, cfg_cxl_dev_cache_enable};
assign cxl_dev_reg_13 = {1'b0, cfg_cxl_dev_viral_enable,2'b00,cfg_cxl_dev_cache_clean_eviction,cfg_cxl_dev_cache_sf_granularity};


always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_io_control_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_io_enable               <= #TP `DEFAULT_CXL_IO_ENABLE;
    end else begin
        cfg_cxl_dev_io_enable               <= #TP (cxl_dev_reg_id[3] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[1] : cfg_cxl_dev_io_enable;
    end
end 
always @( posedge aux_clk or negedge non_sticky_rst_n ) begin : cxl_dev_control_PROC
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_dev_cache_enable            <= #TP 0;
        cfg_cxl_dev_mem_enable              <= #TP 0;
        cfg_cxl_dev_cache_sf_coverage       <= #TP 0;
        cfg_cxl_dev_cache_sf_granularity    <= #TP 0;
        cfg_cxl_dev_cache_clean_eviction    <= #TP 0;
        cfg_cxl_dev_viral_enable            <= #TP 0;
    end else if (~config_lock) begin 
        cfg_cxl_dev_cache_enable            <= #TP (cxl_dev_reg_id[3] & cxl_dev_write_pulse[0]) ? lbc_cdm_data[0] : cfg_cxl_dev_cache_enable;
        cfg_cxl_dev_mem_enable              <= #TP (cxl_dev_reg_id[3] & cxl_dev_write_pulse[0]) ? lbc_cdm_data[2] : cfg_cxl_dev_mem_enable;
        cfg_cxl_dev_cache_sf_coverage       <= #TP (cxl_dev_reg_id[3] & cxl_dev_write_pulse[0]) ? lbc_cdm_data[7:3] : cfg_cxl_dev_cache_sf_coverage;
        cfg_cxl_dev_cache_sf_granularity    <= #TP (cxl_dev_reg_id[3] & cxl_dev_write_pulse[1]) ? lbc_cdm_data[10:8] : cfg_cxl_dev_cache_sf_granularity;
        cfg_cxl_dev_cache_clean_eviction    <= #TP (cxl_dev_reg_id[3] & cxl_dev_write_pulse[1]) ? lbc_cdm_data[11] : cfg_cxl_dev_cache_clean_eviction;
        cfg_cxl_dev_viral_enable            <= #TP (cxl_dev_reg_id[3] & cxl_dev_write_pulse[1]) ? lbc_cdm_data[14] : cfg_cxl_dev_viral_enable;
    end
end



// ------------------------------------------------------------------
// CXL Flex Bus Device Status Register (0x0e)
// ------------------------------------------------------------------


wire viral_status_clr;
assign viral_status_clr = (cxl_dev_reg_id[3] & cxl_dev_write_pulse[3] & lbc_cdm_data[30]);

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_status_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_viral_status            <= #TP 0;
    end
    else if (viral_status) begin
        cfg_cxl_dev_viral_status            <= #TP 1;
    end
    else if (viral_status_clr) begin
        cfg_cxl_dev_viral_status            <= #TP 0;
    end
end

assign cxl_dev_reg_14 = 8'h00;
assign cxl_dev_reg_15 = {1'b0, cfg_cxl_dev_viral_status, 6'h0};



// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Control 2 (0x10) & CXL Flex Bus Device Status 2 (0x12)
// --------------------------------------------------------------------------------------
// cxl_dev_reg_id     - 4
// PCIE Offset      - `CXL_DEVICE_PTR + 10h
// length           - 4 byte
// Cfig register    - cxl_dev_reg_19, cxl_dev_reg_18, cxl_dev_reg_17, cxl_dev_reg_16
// --------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Control 2 (0x10) 
// --------------------------------------------------------------------------------------
assign cxl_dev_reg_16 = {3'h0,cfg_cxl_dev_post_hot_rst_volatile_hdm_desired,cfg_cxl_dev_cxl_rst_mem_clr_enable,2'h0,cfg_cxl_dev_disable_caching};
assign cxl_dev_reg_17 = 8'h00;
always @( posedge aux_clk or negedge non_sticky_rst_n ) begin
    if ( !non_sticky_rst_n ) begin
      cfg_cxl_dev_disable_caching         <= #TP 1'b0;
    end else begin
      cfg_cxl_dev_disable_caching         <= #TP (cxl_dev_reg_id[4] & cxl_dev_write_pulse[0]) ? lbc_cdm_data[0] : cfg_cxl_dev_disable_caching;
    end
end
wire  cfg_cxl_dev_initiate_cache_wr_invld_set; 
wire  cfg_cxl_dev_initiate_cache_wr_invld_clr; 

assign cfg_cxl_dev_initiate_cache_wr_invld_set = (cxl_dev_reg_id[4] & cxl_dev_write_pulse[0] & lbc_cdm_data[1]);//A write of 0 is ignored
assign cfg_cxl_dev_initiate_cache_wr_invld_clr = cxl_dev_cache_wr_invld_cmpl;

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin
    if ( !non_sticky_rst_n ) begin
      cfg_cxl_dev_initiate_cache_wr_invld <= #TP 1'b0;
    end else if(cfg_cxl_dev_initiate_cache_wr_invld_set) begin
      cfg_cxl_dev_initiate_cache_wr_invld <= #TP 1'b1;
    end else if(cfg_cxl_dev_initiate_cache_wr_invld_clr) begin
      cfg_cxl_dev_initiate_cache_wr_invld <= #TP 1'b0;
    end
end
wire  cfg_cxl_dev_initiate_cxl_rst_set;
wire  cfg_cxl_dev_initiate_cxl_rst_clr;
assign cfg_cxl_dev_initiate_cxl_rst_set = 1'b0;
assign cfg_cxl_dev_initiate_cxl_rst_clr = 1'b0;
always @( posedge aux_clk or negedge non_sticky_rst_n ) begin
    if ( !non_sticky_rst_n ) begin
      cfg_cxl_dev_initiate_cxl_rst           <= #TP 1'b0;
    end else if(cfg_cxl_dev_initiate_cxl_rst_set) begin
      cfg_cxl_dev_initiate_cxl_rst           <= #TP 1'b1;
    end else if(cfg_cxl_dev_initiate_cxl_rst_clr) begin
      cfg_cxl_dev_initiate_cxl_rst           <= #TP 1'b0;
    end
end

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin
    if ( !non_sticky_rst_n ) begin
      cfg_cxl_dev_cxl_rst_mem_clr_enable     <= #TP 1'b0;
    end else begin
      cfg_cxl_dev_cxl_rst_mem_clr_enable     <= #TP (cxl_dev_reg_id[4] & cxl_dev_write_pulse[0]) ? lbc_cdm_data[3] : cfg_cxl_dev_cxl_rst_mem_clr_enable;
    end
end


logic  cfg_cxl_dev_post_hot_rst_volatile_hdm_cap;

always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
      cfg_cxl_dev_post_hot_rst_volatile_hdm_desired     <= #TP 1'b0;
    end else begin
      if (cfg_cxl_dev_post_hot_rst_volatile_hdm_cap)
          cfg_cxl_dev_post_hot_rst_volatile_hdm_desired     <= #TP (cxl_dev_reg_id[4] & cxl_dev_write_pulse[0]) ? lbc_cdm_data[4] : cfg_cxl_dev_post_hot_rst_volatile_hdm_desired;
      else
          cfg_cxl_dev_post_hot_rst_volatile_hdm_desired     <= #TP 1'b0;
    end
end


// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Status 2 (0x12)
// --------------------------------------------------------------------------------------
reg  cfg_cxl_dev_cache_invalid;
reg  cfg_cxl_dev_cxl_rst_cmpl;
reg  cfg_cxl_dev_cxl_rst_error;
reg  cfg_cxl_dev_volatile_hdm_error;
reg  cfg_cxl_dev_pm_init_cmpl;
assign cxl_dev_reg_18 = {4'h0,cfg_cxl_dev_volatile_hdm_error,cfg_cxl_dev_cxl_rst_error,cfg_cxl_dev_cxl_rst_cmpl,cfg_cxl_dev_cache_invalid};
assign cxl_dev_reg_19 = {cfg_cxl_dev_pm_init_cmpl,7'h00};
always @( posedge aux_clk or negedge non_sticky_rst_n ) begin
    if ( !non_sticky_rst_n ) begin
       cfg_cxl_dev_cache_invalid   <= #TP 1'b0;
    end else begin
       cfg_cxl_dev_cache_invalid   <= #TP ( ( cxl_dev_cache_invalid ) & cfg_cxl_dev_disable_caching );
    end
end



always @( posedge aux_clk or negedge non_sticky_rst_n ) begin
    if ( !non_sticky_rst_n ) begin
       cfg_cxl_dev_cxl_rst_cmpl <= #TP 1'b0;
    end else begin
       cfg_cxl_dev_cxl_rst_cmpl <= #TP 1'b0;
    end
end

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin
    if ( !non_sticky_rst_n ) begin
       cfg_cxl_dev_cxl_rst_error <= #TP 1'b0;
    end
    else begin
       cfg_cxl_dev_cxl_rst_error <= #TP 1'b0;    
    end
end

wire  cfg_cxl_dev_volatile_hdm_error_set;
wire  cfg_cxl_dev_volatile_hdm_error_clr;
assign cfg_cxl_dev_volatile_hdm_error_set = (cxl_volatile_hdm_error & cfg_cxl_dev_post_hot_rst_volatile_hdm_desired);
assign cfg_cxl_dev_volatile_hdm_error_clr = (cxl_dev_reg_id[4] & cxl_dev_write_pulse[2] & lbc_cdm_data[19]);
always @( posedge aux_clk or negedge sticky_rst_n ) begin
    if ( !sticky_rst_n ) begin
      cfg_cxl_dev_volatile_hdm_error <= #TP 1'b0;    
    end else begin 
      cfg_cxl_dev_volatile_hdm_error <= #TP (cfg_cxl_dev_volatile_hdm_error_set ? 1'b1 : (cfg_cxl_dev_volatile_hdm_error_clr ? 1'b0 : cfg_cxl_dev_volatile_hdm_error));
    end
end

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin
    if ( !non_sticky_rst_n ) begin
      cfg_cxl_dev_pm_init_cmpl <= #TP 1'b0;
    end else begin 
      cfg_cxl_dev_pm_init_cmpl <= #TP cxl_pm_init_cmpl ;
    end
end

// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Lock (0x14) & CXL Flex Bus Capability 2 (0x16)
// --------------------------------------------------------------------------------------
// cxl_dev_reg_id   - 5
// PCIE Offset      - `CXL_DEVICE_PTR + 14h
// length           - 4 byte
// Cfig register    - cxl_dev_reg_23, cxl_dev_reg_22, cxl_dev_reg_21, cxl_dev_reg_20
// --------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Lock (0x14) 
// --------------------------------------------------------------------------------------
reg    cfg_cxl_dev_config_lock_reg;
assign config_lock =  cfg_cxl_dev_config_lock_reg;
reg    config_lock_reg_write_done;

assign cxl_dev_reg_20 = {7'h00,config_lock};
assign cxl_dev_reg_21 = 8'h00;


always @( posedge aux_clk or negedge non_sticky_rst_n ) begin
    if ( !non_sticky_rst_n ) begin
        config_lock_reg_write_done            <= #TP 0;
    end
    else if(cxl_dev_reg_id[5] & cxl_dev_write_pulse[0] & lbc_cdm_data[0]) begin
        config_lock_reg_write_done            <= #TP 1'b1;
    end
end

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin : cxl_dev_config_lock_PROC
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_dev_config_lock_reg            <= #TP 0;
    end
    else if (~config_lock_reg_write_done) begin
        cfg_cxl_dev_config_lock_reg            <= #TP (cxl_dev_reg_id[5] & cxl_dev_write_pulse[0]) ? lbc_cdm_data[0] : cfg_cxl_dev_config_lock_reg;
    end
end

// --------------------------------------------------------------------------------------
// CXL Flex Bus Capability 2 (0x16)
// --------------------------------------------------------------------------------------

logic  [3:0] cfg_cxl_dev_cache_size_unit;
logic  [7:0] cfg_cxl_dev_cache_size;
assign cxl_dev_reg_22 = {4'h0,cfg_cxl_dev_cache_size_unit};
assign cxl_dev_reg_23 = {cfg_cxl_dev_cache_size};

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_cap_2_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_cache_size_unit   <= #TP `CX_CXL_DEVICE_CACHE_SIZE_UNIT;     
        cfg_cxl_dev_cache_size        <= #TP `CX_CXL_DEVICE_CACHE_SIZE;    
    end else begin//A type 3 CXL device shall return the value of 0.
        cfg_cxl_dev_cache_size_unit   <= #TP (cxl_dev_reg_id[5] & cxl_dev_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_cxl_dev_cache_size_unit;
        cfg_cxl_dev_cache_size        <= #TP (cxl_dev_reg_id[5] & cxl_dev_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_dev_cache_size;
    end
end

// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Range 1 Size High (0x18)
// --------------------------------------------------------------------------------------
// cxl_dev_reg_id     - 6
// PCIE Offset      - `CXL_DEVICE_PTR + 18h
// length           - 4 byte
// Cfig register    - cxl_dev_reg_27, cxl_dev_reg_26, cxl_dev_reg_25, cxl_dev_reg_24
// --------------------------------------------------------------------------------------

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_range1_size_high_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_range1_mem_size_high  <= #TP `CX_CXL_RANGE_1_MEM_SIZE_HIGH;            
    end
    else begin
        cfg_cxl_dev_range1_mem_size_high[7:0]     <= #TP (cxl_dev_reg_id[6] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0]  : cfg_cxl_dev_range1_mem_size_high[7:0];
        cfg_cxl_dev_range1_mem_size_high[15:8]    <= #TP (cxl_dev_reg_id[6] & cxl_dev_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_dev_range1_mem_size_high[15:8];
        cfg_cxl_dev_range1_mem_size_high[23:16]   <= #TP (cxl_dev_reg_id[6] & cxl_dev_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cfg_cxl_dev_range1_mem_size_high[23:16];
        cfg_cxl_dev_range1_mem_size_high[31:24]   <= #TP (cxl_dev_reg_id[6] & cxl_dev_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_dev_range1_mem_size_high[31:24];       
    end   
end

assign cxl_dev_reg_24 = cfg_cxl_dev_range1_mem_size_high[7:0];
assign cxl_dev_reg_25 = cfg_cxl_dev_range1_mem_size_high[15:8];
assign cxl_dev_reg_26 = cfg_cxl_dev_range1_mem_size_high[23:16];
assign cxl_dev_reg_27 = cfg_cxl_dev_range1_mem_size_high[31:24];



// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Range 1 Size Low (0x1C)
// --------------------------------------------------------------------------------------
// cxl_dev_reg_id     - 7
// PCIE Offset      - `CXL_DEVICE_PTR + 1Ch
// length           - 4 byte
// Cfig register    - cxl_dev_reg_31, cxl_dev_reg_30, cxl_dev_reg_29, cxl_dev_reg_28
// --------------------------------------------------------------------------------------

reg [2:0]  cfg_cxl_dev_range1_media_type;     // Indicates the memory media characteristics
reg [2:0]  cfg_cxl_dev_range1_mem_class;      // Indicates the class of memory

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_range1_size_low_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_range1_mem_info_valid      <= #TP `CX_CXL_RANGE_1_MEM_INFO_VALID;   
        cfg_cxl_dev_range1_mem_active          <= #TP `CX_CXL_RANGE_1_MEM_ACTIVE;
        cfg_cxl_dev_range1_media_type          <= #TP `CX_CXL_RANGE_1_MEDIA_TYPE;
        cfg_cxl_dev_range1_mem_class           <= #TP `CX_CXL_RANGE_1_MEM_CLASS;
        cfg_cxl_dev_range1_desired_interleave  <= #TP `CX_CXL_RANGE_1_DESIRED_INTERLEAVE;
        cfg_cxl_dev_range1_mem_active_timeout  <= #TP `CX_CXL_RANGE_1_MEM_ACTIVE_TIMEOUT;        
        cfg_cxl_dev_range1_mem_size_low        <= #TP `CX_CXL_RANGE_1_MEM_SIZE_LOW;

    end
    else begin
        cfg_cxl_dev_range1_mem_info_valid       <= #TP (cxl_dev_reg_id[7] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[0]  : cfg_cxl_dev_range1_mem_info_valid;
        cfg_cxl_dev_range1_mem_active           <= #TP (cxl_dev_reg_id[7] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[1] : cfg_cxl_dev_range1_mem_active;
        cfg_cxl_dev_range1_media_type           <= #TP (cxl_dev_reg_id[7] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[4:2] : cfg_cxl_dev_range1_media_type;
        cfg_cxl_dev_range1_mem_class            <= #TP (cxl_dev_reg_id[7] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:5] : cfg_cxl_dev_range1_mem_class;
        cfg_cxl_dev_range1_desired_interleave   <= #TP (cxl_dev_reg_id[7] & cxl_dev_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[12:8] : cfg_cxl_dev_range1_desired_interleave;
        cfg_cxl_dev_range1_mem_active_timeout   <= #TP (cxl_dev_reg_id[7] & cxl_dev_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:13] : cfg_cxl_dev_range1_mem_active_timeout;
        cfg_cxl_dev_range1_mem_size_low         <= #TP (cxl_dev_reg_id[7] & cxl_dev_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:28] : cfg_cxl_dev_range1_mem_size_low;
    end
end

assign cxl_dev_reg_28 = {cfg_cxl_dev_range1_mem_class, cfg_cxl_dev_range1_media_type, cfg_cxl_dev_range1_mem_active, cfg_cxl_dev_range1_mem_info_valid};
assign cxl_dev_reg_29 = {cfg_cxl_dev_range1_mem_active_timeout, cfg_cxl_dev_range1_desired_interleave};
assign cxl_dev_reg_30 = 8'h00;
assign cxl_dev_reg_31 = {cfg_cxl_dev_range1_mem_size_low, 4'h0};


// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Range 1 Base High (0x20)
// --------------------------------------------------------------------------------------
// cxl_dev_reg_id     - 8
// PCIE Offset      - `CXL_DEVICE_PTR + 20h
// length           - 4 byte
// Cfig register    - cxl_dev_reg_35, cxl_dev_reg_34, cxl_dev_reg_33, cxl_dev_reg_32
// --------------------------------------------------------------------------------------

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin : cxl_dev_range1_base_high_PROC
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_dev_range1_mem_base_high  <= #TP 0;            
    end else if (~cfg_cxl_dev_mem_capable) begin
        cfg_cxl_dev_range1_mem_base_high  <= #TP 0;
    end else if (~config_lock) begin
        cfg_cxl_dev_range1_mem_base_high[7:0]     <= #TP (cxl_dev_reg_id[8] & cxl_dev_write_pulse[0]) ? lbc_cdm_data[7:0]  : cfg_cxl_dev_range1_mem_base_high[7:0];
        cfg_cxl_dev_range1_mem_base_high[15:8]    <= #TP (cxl_dev_reg_id[8] & cxl_dev_write_pulse[1]) ? lbc_cdm_data[15:8] : cfg_cxl_dev_range1_mem_base_high[15:8];
        cfg_cxl_dev_range1_mem_base_high[23:16]   <= #TP (cxl_dev_reg_id[8] & cxl_dev_write_pulse[2]) ? lbc_cdm_data[23:16] : cfg_cxl_dev_range1_mem_base_high[23:16];
        cfg_cxl_dev_range1_mem_base_high[31:24]   <= #TP (cxl_dev_reg_id[8] & cxl_dev_write_pulse[3]) ? lbc_cdm_data[31:24] : cfg_cxl_dev_range1_mem_base_high[31:24];
    end

end

assign cxl_dev_reg_32 = cfg_cxl_dev_range1_mem_base_high[7:0];
assign cxl_dev_reg_33 = cfg_cxl_dev_range1_mem_base_high[15:8];
assign cxl_dev_reg_34 = cfg_cxl_dev_range1_mem_base_high[23:16];
assign cxl_dev_reg_35 = cfg_cxl_dev_range1_mem_base_high[31:24];


// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Range 1 Base Low (0x24)
// --------------------------------------------------------------------------------------
// cxl_dev_reg_id     - 9
// PCIE Offset      - `CXL_DEVICE_PTR + 24h
// length           - 4 byte
// Cfig register    - cxl_dev_reg_39, cxl_dev_reg_38, cxl_dev_reg_37, cxl_dev_reg_36
// --------------------------------------------------------------------------------------

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin : cxl_dev_range1_base_low_PROC
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_dev_range1_mem_base_low  <= #TP 0;            
    end else if (~cfg_cxl_dev_mem_capable) begin
        cfg_cxl_dev_range1_mem_base_low  <= #TP 0;
    end else if (~config_lock) begin
        cfg_cxl_dev_range1_mem_base_low    <= #TP (cxl_dev_reg_id[9] & cxl_dev_write_pulse[3]) ? lbc_cdm_data[31:28] : cfg_cxl_dev_range1_mem_base_low;
    end
end

assign cxl_dev_reg_36 = 8'h00;
assign cxl_dev_reg_37 = 8'h00;
assign cxl_dev_reg_38 = 8'h00;
assign cxl_dev_reg_39 = {cfg_cxl_dev_range1_mem_base_low, 4'h0};


// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Range 2 Size High (0x28)
// --------------------------------------------------------------------------------------
// cxl_dev_reg_id     - 10
// PCIE Offset      - `CXL_DEVICE_PTR + 28h
// length           - 4 byte
// Cfig register    - cxl_dev_reg_43, cxl_dev_reg_42, cxl_dev_reg_41, cxl_dev_reg_40
// --------------------------------------------------------------------------------------

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_range2_size_high_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_range2_mem_size_high  <= #TP `CX_CXL_RANGE_2_MEM_SIZE_HIGH;            
    end
    else begin
        cfg_cxl_dev_range2_mem_size_high[7:0]     <= #TP (cxl_dev_reg_id[10] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0]  : cfg_cxl_dev_range2_mem_size_high[7:0];
        cfg_cxl_dev_range2_mem_size_high[15:8]    <= #TP (cxl_dev_reg_id[10] & cxl_dev_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_dev_range2_mem_size_high[15:8];
        cfg_cxl_dev_range2_mem_size_high[23:16]   <= #TP (cxl_dev_reg_id[10] & cxl_dev_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:16] : cfg_cxl_dev_range2_mem_size_high[23:16];
        cfg_cxl_dev_range2_mem_size_high[31:24]   <= #TP (cxl_dev_reg_id[10] & cxl_dev_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_dev_range2_mem_size_high[31:24];
    end  
end

assign cxl_dev_reg_40 = cfg_cxl_dev_range2_mem_size_high[7:0];
assign cxl_dev_reg_41 = cfg_cxl_dev_range2_mem_size_high[15:8];
assign cxl_dev_reg_42 = cfg_cxl_dev_range2_mem_size_high[23:16];
assign cxl_dev_reg_43 = cfg_cxl_dev_range2_mem_size_high[31:24];


// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Range 2 Size Low (0x2C)
// --------------------------------------------------------------------------------------
// cxl_dev_reg_id     - 11
// PCIE Offset      - `CXL_DEVICE_PTR + 2Ch
// length           - 4 byte
// Cfig register    - cxl_dev_reg_47, cxl_dev_reg_46, cxl_dev_reg_45, cxl_dev_reg_44
// --------------------------------------------------------------------------------------
reg [2:0]  cfg_cxl_dev_range2_media_type;      // Indicates the memory media characteristics
reg [2:0]  cfg_cxl_dev_range2_mem_class;       // Indicates the class of memory

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_range2_size_low_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_range2_mem_info_valid      <= #TP `CX_CXL_RANGE_2_MEM_INFO_VALID;   
        cfg_cxl_dev_range2_mem_active          <= #TP `CX_CXL_RANGE_2_MEM_ACTIVE;
        cfg_cxl_dev_range2_media_type          <= #TP `CX_CXL_RANGE_2_MEDIA_TYPE;
        cfg_cxl_dev_range2_mem_class           <= #TP `CX_CXL_RANGE_2_MEM_CLASS;
        cfg_cxl_dev_range2_desired_interleave  <= #TP `CX_CXL_RANGE_2_DESIRED_INTERLEAVE;
        cfg_cxl_dev_range2_mem_active_timeout  <= #TP `CX_CXL_RANGE_2_MEM_ACTIVE_TIMEOUT;        
        cfg_cxl_dev_range2_mem_size_low        <= #TP `CX_CXL_RANGE_2_MEM_SIZE_LOW;
    end
    else begin
        cfg_cxl_dev_range2_mem_info_valid       <= #TP (cxl_dev_reg_id[11] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[0]  : cfg_cxl_dev_range2_mem_info_valid;
        cfg_cxl_dev_range2_mem_active           <= #TP (cxl_dev_reg_id[11] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[1] : cfg_cxl_dev_range2_mem_active;
        cfg_cxl_dev_range2_media_type           <= #TP (cxl_dev_reg_id[11] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[4:2] : cfg_cxl_dev_range2_media_type;
        cfg_cxl_dev_range2_mem_class            <= #TP (cxl_dev_reg_id[11] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:5] : cfg_cxl_dev_range2_mem_class;
        cfg_cxl_dev_range2_desired_interleave   <= #TP (cxl_dev_reg_id[11] & cxl_dev_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[12:8] : cfg_cxl_dev_range2_desired_interleave;
        cfg_cxl_dev_range2_mem_active_timeout   <= #TP (cxl_dev_reg_id[11] & cxl_dev_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:13] : cfg_cxl_dev_range2_mem_active_timeout;        
        cfg_cxl_dev_range2_mem_size_low         <= #TP (cxl_dev_reg_id[11] & cxl_dev_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:28] : cfg_cxl_dev_range2_mem_size_low;
    end
end

assign cxl_dev_reg_44 = {cfg_cxl_dev_range2_mem_class, cfg_cxl_dev_range2_media_type, cfg_cxl_dev_range2_mem_active, cfg_cxl_dev_range2_mem_info_valid};
assign cxl_dev_reg_45 = {cfg_cxl_dev_range2_mem_active_timeout, cfg_cxl_dev_range2_desired_interleave};
assign cxl_dev_reg_46 = 8'h00;
assign cxl_dev_reg_47 = {cfg_cxl_dev_range2_mem_size_low,4'h0};


// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Range 2 Base High (0x30)
// --------------------------------------------------------------------------------------
// cxl_dev_reg_id     - 12
// PCIE Offset      - `CXL_DEVICE_PTR + 30h
// length           - 4 byte
// Cfig register    - cxl_dev_reg_51, cxl_dev_reg_50, cxl_dev_reg_49, cxl_dev_reg_48
// --------------------------------------------------------------------------------------

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin : cxl_dev_range2_base_high_PROC
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_dev_range2_mem_base_high  <= #TP 0;            
    end else if (~ (cfg_cxl_dev_mem_capable && (cfg_cxl_dev_hdm_count == 2'b10))) begin 
        cfg_cxl_dev_range2_mem_base_high  <= #TP 0;
    end else if (~config_lock) begin
        cfg_cxl_dev_range2_mem_base_high[7:0]     <= #TP (cxl_dev_reg_id[12] & cxl_dev_write_pulse[0]) ? lbc_cdm_data[7:0]  : cfg_cxl_dev_range2_mem_base_high[7:0];
        cfg_cxl_dev_range2_mem_base_high[15:8]    <= #TP (cxl_dev_reg_id[12] & cxl_dev_write_pulse[1]) ? lbc_cdm_data[15:8] : cfg_cxl_dev_range2_mem_base_high[15:8];
        cfg_cxl_dev_range2_mem_base_high[23:16]   <= #TP (cxl_dev_reg_id[12] & cxl_dev_write_pulse[2]) ? lbc_cdm_data[23:16] : cfg_cxl_dev_range2_mem_base_high[23:16];
        cfg_cxl_dev_range2_mem_base_high[31:24]   <= #TP (cxl_dev_reg_id[12] & cxl_dev_write_pulse[3]) ? lbc_cdm_data[31:24] : cfg_cxl_dev_range2_mem_base_high[31:24];
    end
end

assign cxl_dev_reg_48 = cfg_cxl_dev_range2_mem_base_high[7:0];
assign cxl_dev_reg_49 = cfg_cxl_dev_range2_mem_base_high[15:8];
assign cxl_dev_reg_50 = cfg_cxl_dev_range2_mem_base_high[23:16];
assign cxl_dev_reg_51 = cfg_cxl_dev_range2_mem_base_high[31:24];


// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Range 2 Base Low (0x34)
// --------------------------------------------------------------------------------------
// cxl_dev_reg_id     - 13
// PCIE Offset      - `CXL_DEVICE_PTR + 34h
// length           - 4 byte
// Cfig register    - cxl_dev_reg_55, cxl_dev_reg_54, cxl_dev_reg_53, cxl_dev_reg_52
// --------------------------------------------------------------------------------------

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin : cxl_dev_range2_base_low_PROC
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_dev_range2_mem_base_low  <= #TP 0;            
    end else if (~ (cfg_cxl_dev_mem_capable && (cfg_cxl_dev_hdm_count == 2'b10))) begin 
        cfg_cxl_dev_range2_mem_base_low  <= #TP 0;
    end else if (~config_lock) begin
        cfg_cxl_dev_range2_mem_base_low    <= #TP (cxl_dev_reg_id[13] & cxl_dev_write_pulse[3]) ? lbc_cdm_data[31:28] : cfg_cxl_dev_range2_mem_base_low;
    end
end

assign cxl_dev_reg_52 = 8'h00;
assign cxl_dev_reg_53 = 8'h00;
assign cxl_dev_reg_54 = 8'h00;
assign cxl_dev_reg_55 = {cfg_cxl_dev_range2_mem_base_low, 4'h0};


// --------------------------------------------------------------------------------------
// CXL Flex Bus Device Capability 3 (0x38)
// --------------------------------------------------------------------------------------
// cxl_dev_reg_id     - 14
// PCIE Offset      - `CXL_DEVICE_PTR + 38h
// length           - 2 byte
// Cfig register    - cxl_dev_reg_57, cxl_dev_reg_56
// --------------------------------------------------------------------------------------

assign cxl_dev_reg_56 = {4'h0,cfg_cxl_dev_post_hot_rst_volatile_hdm_cap,cfg_cxl_dev_post_hot_rst_volatile_hdm_default,cfg_cxl_dev_post_warm_rst_volatile_hdm_default,cfg_cxl_dev_post_cold_rst_volatile_hdm_default};
assign cxl_dev_reg_57 = 8'h00;
assign cxl_dev_reg_58 = 8'h00;
assign cxl_dev_reg_59 = 8'h00;

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_dev_cap_3_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_dev_post_cold_rst_volatile_hdm_default   <= #TP `CX_CXL_DEVICE_POST_COLD_RST_VOLATILE_HDM_DFLT;     
        cfg_cxl_dev_post_warm_rst_volatile_hdm_default   <= #TP `CX_CXL_DEVICE_POST_WARM_RST_VOLATILE_HDM_DFLT;    
        cfg_cxl_dev_post_hot_rst_volatile_hdm_default    <= #TP `CX_CXL_DEVICE_POST_HOT_RST_VOLATILE_HDM_DFLT;     
        cfg_cxl_dev_post_hot_rst_volatile_hdm_cap        <= #TP `CX_CXL_DEVICE_POST_HOT_RST_VOLATILE_HDM_CAP; 
    end else begin
        cfg_cxl_dev_post_cold_rst_volatile_hdm_default   <= #TP (cxl_dev_reg_id[14] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[0] : cfg_cxl_dev_post_cold_rst_volatile_hdm_default;
        cfg_cxl_dev_post_warm_rst_volatile_hdm_default   <= #TP (cxl_dev_reg_id[14] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[1] : cfg_cxl_dev_post_warm_rst_volatile_hdm_default;
        cfg_cxl_dev_post_hot_rst_volatile_hdm_default    <= #TP (cxl_dev_reg_id[14] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[2] : cfg_cxl_dev_post_hot_rst_volatile_hdm_default;
        cfg_cxl_dev_post_hot_rst_volatile_hdm_cap        <= #TP (cxl_dev_reg_id[14] & cxl_dev_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[3] : cfg_cxl_dev_post_hot_rst_volatile_hdm_cap;
    end
end


// =============================================================================
// Register Read Operation
// =============================================================================

always @(*)
begin : read_data_PROC
    unique case (1'b1)
        cxl_dev_reg_id[0]  : cxl_dev_reg_data = {cxl_dev_reg_03, cxl_dev_reg_02, cxl_dev_reg_01, cxl_dev_reg_00};   // 0x00
        cxl_dev_reg_id[1]  : cxl_dev_reg_data = {cxl_dev_reg_07, cxl_dev_reg_06, cxl_dev_reg_05, cxl_dev_reg_04};   // 0x04
        cxl_dev_reg_id[2]  : cxl_dev_reg_data = {cxl_dev_reg_11, cxl_dev_reg_10, cxl_dev_reg_09, cxl_dev_reg_08};   // 0x08
        cxl_dev_reg_id[3]  : cxl_dev_reg_data = {cxl_dev_reg_15, cxl_dev_reg_14, cxl_dev_reg_13, cxl_dev_reg_12};   // 0x0C
        cxl_dev_reg_id[4]  : cxl_dev_reg_data = {cxl_dev_reg_19, cxl_dev_reg_18, cxl_dev_reg_17, cxl_dev_reg_16};   // 0x10
        cxl_dev_reg_id[5]  : cxl_dev_reg_data = {cxl_dev_reg_23, cxl_dev_reg_22, cxl_dev_reg_21, cxl_dev_reg_20};   // 0x14
        cxl_dev_reg_id[6]  : cxl_dev_reg_data = {cxl_dev_reg_27, cxl_dev_reg_26, cxl_dev_reg_25, cxl_dev_reg_24};   // 0x18
        cxl_dev_reg_id[7]  : cxl_dev_reg_data = {cxl_dev_reg_31, cxl_dev_reg_30, cxl_dev_reg_29, cxl_dev_reg_28};   // 0x1C
        cxl_dev_reg_id[8]  : cxl_dev_reg_data = {cxl_dev_reg_35, cxl_dev_reg_34, cxl_dev_reg_33, cxl_dev_reg_32};   // 0x20
        cxl_dev_reg_id[9]  : cxl_dev_reg_data = {cxl_dev_reg_39, cxl_dev_reg_38, cxl_dev_reg_37, cxl_dev_reg_36};   // 0x24
        cxl_dev_reg_id[10] : cxl_dev_reg_data = {cxl_dev_reg_43, cxl_dev_reg_42, cxl_dev_reg_41, cxl_dev_reg_40};   // 0x28
        cxl_dev_reg_id[11] : cxl_dev_reg_data = {cxl_dev_reg_47, cxl_dev_reg_46, cxl_dev_reg_45, cxl_dev_reg_44};   // 0x2C
        cxl_dev_reg_id[12] : cxl_dev_reg_data = {cxl_dev_reg_51, cxl_dev_reg_50, cxl_dev_reg_49, cxl_dev_reg_48};   // 0x30
        cxl_dev_reg_id[13] : cxl_dev_reg_data = {cxl_dev_reg_55, cxl_dev_reg_54, cxl_dev_reg_53, cxl_dev_reg_52};   // 0x34
        cxl_dev_reg_id[14] : cxl_dev_reg_data = {cxl_dev_reg_59, cxl_dev_reg_58, cxl_dev_reg_57, cxl_dev_reg_56};   // 0x38
        default            : cxl_dev_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end

endmodule // cdm_cxl_device_reg
