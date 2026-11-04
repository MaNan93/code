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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_cxl_port_reg.sv#13 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the CXL Flex Bus Port DVSEC Extended Capability regsiters.
// --- This capability is only in Function0.
// -----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
 
 module cdm_cxl_port_reg
  import DWC_pcie_ctl_pkg::ltssm_cxl_enable_t;
#(

    parameter INST          = 0 
   ,parameter NCXL_PORT     = `CXL_PORT_DVSEC_SIZE>>2    // Number of registers in CXL Flex Bus Port DVSEC Extended Capability Structure
   ,parameter NL            = `CX_NL                     // Number of Lanes
   ,parameter TP            = `TP
)

                          (

// -- Inputs --
   input                      aux_clk,               // Clock            
   input                      non_sticky_rst_n,      // Reset non_sticky register only 
   input                      sticky_rst_n,          // Reset sticky register only 
  
   input    [31:0]            lbc_cdm_data,
   input                      lbc_cdm_dbi,
   input                      dbi_ro_wr_en,  
   input    [3:0]             cxl_port_write_pulse,
   input   [NCXL_PORT-1:0]    cxl_port_reg_id,
   input                      upstream_port,

   input   ltssm_cxl_enable_t ltssm_cxl_enable,
   input [23:0]               cxl_port_rcvd_mod_ts_data_phase1,   // values received in Symbols 12 through 14 of the Modified TS1 Ordered Set during Phase 1 of CXL alternate protocol negotiation
   input                      correctable_protocol_id_frame_err,  // Correctable frame ID Error has been encountered
   input                      uncorrectable_protocol_id_frame_err,// Uncorrectable Frame ID Error has been encountered
   input                      unexpected_protocol_id_dropped,     // Physical layer dropped a flit with an unexpected protocol ID that is not due to an Uncorrectable Protocol ID Framing Error
   input                      retimers_present_mismatched,        // Indicates that the downstream port Physical Layer detected an inconsistency in the "Retimers Present" or "Two Retimers Present" bits in the received TS2 ordered sets                  
   input                      fb_enable_bits_phase2_mismatch,     // Indicates that the downstream port Physical Layer detected that the upstream port did not reflect prcisely the Dlex Bus enable bits located in symbols 12-14 of the modified TS2 during Phase 2 of the negotiation.
   input   [2:0]              current_data_rate,
   input                      cfg_pcie_slot_clk_config,           // connect to the same reference clock source HwInit status reg
   input                      cxl_rcrb_enable,                    // indicates that the CXL 1.1 Link is up for USP supporting RCRB

// -- Outputs --
   output reg [31:0]          cxl_port_reg_data,                // Data read from the register

   output reg                 cfg_cxl_port_cache_capable,       // Indicates CXL.cache protocol support when operating in Flex Bus.AL mode
   output reg                 cfg_cxl_port_mem_capable,         // Indicates CXL.mem protocol support when operating in Flex Bus.AL mode
   output reg [15:0]          cfg_cxl_port_vid,                 // DVSEC vendor ID
   output reg                 cfg_cxl_port_68B_flit_vh_capable, // Indicates CXL VH functionality support with 68B flits
   output                     cfg_cxl_port_mld_capable,         // Indicates CXL Multi-Logical Device support when operating in Flex Bus.AL mode
   output reg                 cfg_cxl_port_lopt_flit_capable,    //Indicates CXL Latency-optimized flit mode capability
   output reg                 cfg_cxl_port_pbr_flit_capable,     //Indicates CXL Port Based Routing flit mode capability
   output logic               cfg_cxl_port_nop_hint_capable,     //Indicates CXL NOP Insertion Hint Performance Optimization capability
   output                     cfg_cxl_port_cache_enable,            // Enable CXL.Cache
   output reg                 cfg_cxl_port_io_enable,               // Enable CXL.io
   output                     cfg_cxl_port_mem_enable,              // Enable CXL.Mem
   output                     cfg_cxl_port_sync_hdr_bypass_enable,  // Enable bypass of the 2-bit sync header by the Flex Bus physical layer when operating in Flex Bus.AL mode 
   output                     cfg_cxl_port_drift_buffer_enable,     // Enable drift buffer (instead of elastic buffer) if there is a common reference clock
   output                     cfg_cxl_port_68B_flit_vh_enable,      // Enable CXL VH operation with 68B Flit mode
   output                     cfg_cxl_port_mld_enable,              // Enable CXL Multi-Logical Device support
   output                     cfg_cxl_port_disable_cxl1p1_training, // Disable CXL 1.0 training 
   output                     cfg_cxl_port_retimer1_present,        // Retimer1 is present (only valid for downstream port)
   output                     cfg_cxl_port_retimer2_present,        // Retimer2 is present (only valid for downstream port)
   output                     cfg_cxl_port_retimers_pre_mismatched, // Status bit for CXL Retimers Present Mismatched
   output                     cfg_cxl_port_lopt_flit_enable,        // Enable bit for Latency-optimized flit mode
   output                     cfg_cxl_port_pbr_flit_enable,         // Enable bit for PBR flit mode
   output logic               cfg_cxl_port_nop_hint_enable          // Enable NOP Insertion Hint Performance Optimization 

);

wire    [7:0]   cxl_port_reg_03, cxl_port_reg_02, cxl_port_reg_01, cxl_port_reg_00;
wire    [7:0]   cxl_port_reg_07, cxl_port_reg_06, cxl_port_reg_05, cxl_port_reg_04;
wire    [7:0]   cxl_port_reg_11, cxl_port_reg_10, cxl_port_reg_09, cxl_port_reg_08;
wire    [7:0]   cxl_port_reg_15, cxl_port_reg_14, cxl_port_reg_13, cxl_port_reg_12;
wire    [7:0]   cxl_port_reg_19, cxl_port_reg_18, cxl_port_reg_17, cxl_port_reg_16;
wire    [7:0]   cxl_port_reg_23, cxl_port_reg_22, cxl_port_reg_21, cxl_port_reg_20;
wire    [7:0]   cxl_port_reg_27, cxl_port_reg_26, cxl_port_reg_25, cxl_port_reg_24;
wire    [7:0]   cxl_port_reg_31, cxl_port_reg_30, cxl_port_reg_29, cxl_port_reg_28;
wire            int_lbc_cdm_dbi;
assign          int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;


// -----------------------------------------------------------------------------
// CXL Flex Bus Port DVSEC Extended Capability Header Register
// -----------------------------------------------------------------------------
// cxl_port_reg_id     - 0
// PCIE Offset      - `CXL_PORT_PTR
// length           - 4 byte
// Cfig register    - cxl_port_reg_03, cxl_port_reg_02, cxl_port_reg_01, cxl_port_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_cxl_port_id;                 // CXL Flex Bus Port DVSEC Capability ID
reg [3:0]   cfg_cxl_port_ver;                // CXL Flex Bus Port DVSEC Capability Version
reg [11:0]  cfg_cxl_port_next_ptr;           // CXL Flex Bus Port DVSEC Next Capability Offset
reg         cxl_port_next_ptr_wr_updated;    // Asserted when CXL Flex Bus Port DVSEC Capability header has been changed by a DBI write


assign cxl_port_reg_00 = cfg_cxl_port_id[7:0];
assign cxl_port_reg_01 = cfg_cxl_port_id[15:8];
assign cxl_port_reg_02 = {cfg_cxl_port_next_ptr[3:0], cfg_cxl_port_ver};
assign cxl_port_reg_03 = cfg_cxl_port_next_ptr[11:4];

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_port_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_port_id[15:0]    <= #TP `PCIE_CXL_PORT_ECAP_ID;      // Capability ID = 
        cfg_cxl_port_ver[3:0]    <= #TP `PCIE_CXL_PORT_ECAP_VER;     // Capability version = 
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_cxl_port_id[7:0]     <= #TP (cxl_port_reg_id[0] & cxl_port_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_port_id[7:0];
        cfg_cxl_port_id[15:8]    <= #TP (cxl_port_reg_id[0] & cxl_port_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_port_id[15:8];
        cfg_cxl_port_ver[3:0]    <= #TP (cxl_port_reg_id[0] & cxl_port_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_cxl_port_ver[3:0];
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_port_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_port_next_ptr[11:0] <= #TP `CXL_PORT_NEXT_PTR;
    end
    else begin
        if (cxl_port_reg_id[0] && int_lbc_cdm_dbi) begin
        // Read-Only registers, but writable through DBI
            cfg_cxl_port_next_ptr[3:0]  <= #TP cxl_port_write_pulse[2] ? lbc_cdm_data[23:20] : cfg_cxl_port_next_ptr[3:0];
            cfg_cxl_port_next_ptr[11:4] <= #TP cxl_port_write_pulse[3] ? lbc_cdm_data[31:24] : cfg_cxl_port_next_ptr[11:4];
        end else if (!cxl_port_next_ptr_wr_updated) begin
          // In case of CXL 2.0 EP or DM configured as EP, the next pointer points to `CXL_2_0_EXT_NEXT_PTR to ensure that the CXL Extensions DVSEC doesn't show up in the linked list
            cfg_cxl_port_next_ptr[11:0] <= #TP upstream_port ? ( (cxl_rcrb_enable) ? `RCRB_CXL_PORT_NEXT_PTR :  `CXL_2_0_EXT_NEXT_PTR) :  `DM_RP_CXL_PORT_NEXT_PTR;
        end
    end
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_port_next_ptr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        cxl_port_next_ptr_wr_updated <= #TP 1'b0;
    end 
    else begin
        if (cxl_port_reg_id[0] && int_lbc_cdm_dbi && |cxl_port_write_pulse[3:2]) begin
            cxl_port_next_ptr_wr_updated <= #TP 1'b1;
        end
    end
end


// -----------------------------------------------------------------------------
// Designated Vendor Specific Header 1 Register
// -----------------------------------------------------------------------------
// cxl_port_reg_id     - 1
// PCIE Offset      - `CXL_PORT_PTR + 04h
// length           - 4 byte
// Cfig register    - cxl_port_reg_07, cxl_port_reg_06, cxl_port_reg_05, cxl_port_reg_04
// -----------------------------------------------------------------------------
reg     [3:0]   cfg_cxl_port_dvsec_ver;
reg     [11:0]  cfg_cxl_port_len0;

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_port_vendor_specific_hdr1_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_port_vid       <= #TP `PCIE_CXL_PORT_VENDOR_ID;
        cfg_cxl_port_dvsec_ver <= #TP `PCIE_CXL_PORT_VER;
        cfg_cxl_port_len0      <= #TP `CXL_PORT_DVSEC_SIZE;
    end
    else begin
        // Read-Only registers, but writable through DBI
        cfg_cxl_port_vid[7:0]        <= #TP (cxl_port_reg_id[1] & cxl_port_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_port_vid[7:0];
        cfg_cxl_port_vid[15:8]       <= #TP (cxl_port_reg_id[1] & cxl_port_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_port_vid[15:8];
        cfg_cxl_port_dvsec_ver[3:0]  <= #TP (cxl_port_reg_id[1] & cxl_port_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_cxl_port_dvsec_ver[3:0];
        cfg_cxl_port_len0[3:0]       <= #TP (cxl_port_reg_id[1] & cxl_port_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:20] : cfg_cxl_port_len0[3:0];
        cfg_cxl_port_len0[11:4]      <= #TP (cxl_port_reg_id[1] & cxl_port_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24] : cfg_cxl_port_len0[11:4];
    end
end

assign cxl_port_reg_04 = cfg_cxl_port_vid[7:0];
assign cxl_port_reg_05 = cfg_cxl_port_vid[15:8];
assign cxl_port_reg_06 = {cfg_cxl_port_len0[3:0],cfg_cxl_port_dvsec_ver};
assign cxl_port_reg_07 = cfg_cxl_port_len0[11:4];

// -----------------------------------------------------------------------------
// Designated Vendor Specific Header 2(0x08) & CXL Flex Bus Port Capability(0x0a)
// -----------------------------------------------------------------------------
// cxl_port_reg_id     - 2
// PCIE Offset      - `CXL_PORT_PTR + 08h
// length           - 4 byte
// Cfig register    - cxl_port_reg_11, cxl_port_reg_10, cxl_port_reg_09, cxl_port_reg_08
// -----------------------------------------------------------------------------

reg     [15:0]  cfg_cxl_port_dvsec_id0;                // [15:0]

wire            cfg_cxl_port_io_capable;
assign          cfg_cxl_port_io_capable = 1'b1;

assign cxl_port_reg_08 = cfg_cxl_port_dvsec_id0[7:0];
assign cxl_port_reg_09 = cfg_cxl_port_dvsec_id0[15:8];
assign cxl_port_reg_10 = {1'h0,cfg_cxl_port_mld_capable,cfg_cxl_port_68B_flit_vh_capable,2'h0,cfg_cxl_port_mem_capable,cfg_cxl_port_io_capable,cfg_cxl_port_cache_capable};
assign cxl_port_reg_11 = {1'b0, cfg_cxl_port_pbr_flit_capable, cfg_cxl_port_lopt_flit_capable, 5'b0};

reg cfg_cxl_port_mld_capable_usp; //MLD capability for Upstream port
reg cfg_cxl_port_mld_capable_dsp; //MLD capability for Downstream port
assign cfg_cxl_port_mld_capable = upstream_port ? cfg_cxl_port_mld_capable_usp : cfg_cxl_port_mld_capable_dsp;

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_port_vendor_specific_hdr2_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_port_dvsec_id0       <= #TP `PCIE_CXL_PORT_DVSEC_ID;               
    end
    else begin
        cfg_cxl_port_dvsec_id0[7:0]  <= #TP (cxl_port_reg_id[2] & cxl_port_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_cxl_port_dvsec_id0[7:0];
        cfg_cxl_port_dvsec_id0[15:8] <= #TP (cxl_port_reg_id[2] & cxl_port_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_cxl_port_dvsec_id0[15:8];
    end
end
always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_port_capability_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_port_cache_capable    <= #TP 1;
        cfg_cxl_port_mem_capable      <= #TP 1;
        cfg_cxl_port_68B_flit_vh_capable <= #TP 1;
        cfg_cxl_port_mld_capable_usp  <= #TP 0;
        cfg_cxl_port_mld_capable_dsp  <= #TP 0;
        cfg_cxl_port_lopt_flit_capable  <= #TP 0;
        cfg_cxl_port_pbr_flit_capable  <= #TP 0;
    end
    else begin
        cfg_cxl_port_cache_capable       <= #TP (cxl_port_reg_id[2] & cxl_port_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[16] : cfg_cxl_port_cache_capable;
        cfg_cxl_port_mem_capable         <= #TP (cxl_port_reg_id[2] & cxl_port_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[18] : cfg_cxl_port_mem_capable;
        cfg_cxl_port_68B_flit_vh_capable <= #TP (cxl_port_reg_id[2] & cxl_port_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[21] : cfg_cxl_port_68B_flit_vh_capable;
        cfg_cxl_port_lopt_flit_capable   <= #TP (cxl_port_reg_id[2] & cxl_port_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[29] : cfg_cxl_port_lopt_flit_capable;
        cfg_cxl_port_pbr_flit_capable    <= #TP (cxl_port_reg_id[2] & cxl_port_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[30] : cfg_cxl_port_pbr_flit_capable;

        if(upstream_port) begin
        cfg_cxl_port_mld_capable_usp     <= #TP (cxl_port_reg_id[2] & cxl_port_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[22] : cfg_cxl_port_mld_capable_usp;
        end else begin
        cfg_cxl_port_mld_capable_dsp     <= #TP (cxl_port_reg_id[2] & cxl_port_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[22] : cfg_cxl_port_mld_capable_dsp;
        end
    end
end


// --------------------------------------------------------------------------------------
// CXL Flex Bus Port Control (0x0C) & CXL Flex Bus Port Status(0x0E)
// --------------------------------------------------------------------------------------
// cxl_port_reg_id     - 3
// PCIE Offset      - `CXL_PORT_PTR + 0Ch
// length           - 4 byte
// Cfig register    - cxl_port_reg_15, cxl_port_reg_14, cxl_port_reg_13, cxl_port_reg_12
// --------------------------------------------------------------------------------------


// ---------------------------------------------------------------
// CXL Flex Bus Port Control Register (0x0c)
// ---------------------------------------------------------------
reg  cfg_cxl_port_cache_enable_usp           ;
reg  cfg_cxl_port_mem_enable_usp             ;
reg  cfg_cxl_port_sync_hdr_bypass_enable_usp ;
reg  cfg_cxl_port_drift_buffer_enable_usp    ;
reg  cfg_cxl_port_68B_flit_vh_enable_usp     ;
reg  cfg_cxl_port_mld_enable_usp             ;
reg  cfg_cxl_port_disable_cxl1p1_training_usp; 
wire  cfg_cxl_port_retimer1_present_usp       ;
wire  cfg_cxl_port_retimer2_present_usp       ;
reg  cfg_cxl_port_lopt_flit_enable_usp        ;
reg  cfg_cxl_port_pbr_flit_enable_usp         ;

reg  cfg_cxl_port_cache_enable_dsp           ;
reg  cfg_cxl_port_mem_enable_dsp             ;
reg  cfg_cxl_port_sync_hdr_bypass_enable_dsp ;
reg  cfg_cxl_port_drift_buffer_enable_dsp    ;
reg  cfg_cxl_port_68B_flit_vh_enable_dsp     ;
reg  cfg_cxl_port_mld_enable_dsp             ;
reg  cfg_cxl_port_disable_cxl1p1_training_dsp; 
reg  cfg_cxl_port_retimer1_present_dsp       ;
reg  cfg_cxl_port_retimer2_present_dsp       ;
reg  cfg_cxl_port_lopt_flit_enable_dsp       ;
reg  cfg_cxl_port_pbr_flit_enable_dsp        ;

wire cfg_cxl_port_sync_hdr_bypass_enable_int ;
wire cfg_cxl_port_drift_buffer_enable_int    ;

// no common clock, no bypass. retimer present, no bypass.
assign cfg_cxl_port_sync_hdr_bypass_enable = (~cfg_pcie_slot_clk_config) ? 1'b0 : cfg_cxl_port_sync_hdr_bypass_enable_int;
// no common clock, no drift buffer
assign cfg_cxl_port_drift_buffer_enable    = (~cfg_pcie_slot_clk_config) ? 1'b0 : cfg_cxl_port_drift_buffer_enable_int;

assign cxl_port_reg_12 = {cfg_cxl_port_disable_cxl1p1_training, cfg_cxl_port_mld_enable, cfg_cxl_port_68B_flit_vh_enable, cfg_cxl_port_drift_buffer_enable_int, cfg_cxl_port_sync_hdr_bypass_enable_int, cfg_cxl_port_mem_enable, cfg_cxl_port_io_enable, cfg_cxl_port_cache_enable};
assign cxl_port_reg_13 = {1'h0, cfg_cxl_port_pbr_flit_enable, cfg_cxl_port_lopt_flit_enable, 3'h0, cfg_cxl_port_retimer2_present, cfg_cxl_port_retimer1_present};

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_port_control_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_port_io_enable                   <= #TP `DEFAULT_CXL_IO_ENABLE;
    end else begin
        cfg_cxl_port_io_enable                   <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[1] : cfg_cxl_port_io_enable;
    end
end

assign {cfg_cxl_port_pbr_flit_enable, cfg_cxl_port_lopt_flit_enable, cfg_cxl_port_disable_cxl1p1_training, cfg_cxl_port_mld_enable, cfg_cxl_port_68B_flit_vh_enable,cfg_cxl_port_drift_buffer_enable_int, cfg_cxl_port_sync_hdr_bypass_enable_int, cfg_cxl_port_mem_enable, cfg_cxl_port_cache_enable} = upstream_port ? {cfg_cxl_port_pbr_flit_enable_usp, cfg_cxl_port_lopt_flit_enable_usp, cfg_cxl_port_disable_cxl1p1_training_usp, cfg_cxl_port_mld_enable_usp, cfg_cxl_port_68B_flit_vh_enable_usp, cfg_cxl_port_drift_buffer_enable_usp, cfg_cxl_port_sync_hdr_bypass_enable_usp, cfg_cxl_port_mem_enable_usp, cfg_cxl_port_cache_enable_usp} : {cfg_cxl_port_pbr_flit_enable_dsp, cfg_cxl_port_lopt_flit_enable_dsp, cfg_cxl_port_disable_cxl1p1_training_dsp, cfg_cxl_port_mld_enable_dsp, cfg_cxl_port_68B_flit_vh_enable_dsp, cfg_cxl_port_drift_buffer_enable_dsp, cfg_cxl_port_sync_hdr_bypass_enable_dsp, cfg_cxl_port_mem_enable_dsp, cfg_cxl_port_cache_enable_dsp};

always @( posedge aux_clk or negedge sticky_rst_n ) begin : cxl_port_control_usp_PROC
    if ( !sticky_rst_n ) begin
        cfg_cxl_port_cache_enable_usp            <= #TP `DEFAULT_CXL_PORT_USP_CACHE_ENABLE;
        cfg_cxl_port_mem_enable_usp              <= #TP `DEFAULT_CXL_PORT_USP_MEM_ENABLE;
        cfg_cxl_port_sync_hdr_bypass_enable_usp  <= #TP `DEFAULT_CXL_PORT_USP_SYNC_HDR_BYPASS_ENABLE;
        cfg_cxl_port_drift_buffer_enable_usp     <= #TP `DEFAULT_CXL_PORT_USP_DRIFT_BUFFER_ENABLE;
        cfg_cxl_port_68B_flit_vh_enable_usp      <= #TP `DEFAULT_CXL_PORT_USP_68B_FLIT_VH_ENABLE;
        cfg_cxl_port_mld_enable_usp              <= #TP `DEFAULT_CXL_PORT_USP_MLD_ENABLE;
        cfg_cxl_port_disable_cxl1p1_training_usp <= #TP 1'b0; 
        cfg_cxl_port_lopt_flit_enable_usp        <= #TP 1'b0; 
        cfg_cxl_port_pbr_flit_enable_usp         <= #TP 1'b0; 
    end else if(upstream_port) begin
        cfg_cxl_port_cache_enable_usp            <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[0] : cfg_cxl_port_cache_enable_usp;
        cfg_cxl_port_mem_enable_usp              <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[2] : cfg_cxl_port_mem_enable_usp;
        cfg_cxl_port_sync_hdr_bypass_enable_usp  <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[3] : cfg_cxl_port_sync_hdr_bypass_enable_usp;
        cfg_cxl_port_drift_buffer_enable_usp     <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[4] : cfg_cxl_port_drift_buffer_enable_usp;
        cfg_cxl_port_68B_flit_vh_enable_usp      <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[5] : cfg_cxl_port_68B_flit_vh_enable_usp;
        cfg_cxl_port_mld_enable_usp              <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[6] : cfg_cxl_port_mld_enable_usp;
        cfg_cxl_port_disable_cxl1p1_training_usp <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7] : cfg_cxl_port_disable_cxl1p1_training_usp ; 
        cfg_cxl_port_lopt_flit_enable_usp        <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[13] : cfg_cxl_port_lopt_flit_enable_usp;
        cfg_cxl_port_pbr_flit_enable_usp         <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[14] : cfg_cxl_port_pbr_flit_enable_usp;
    end
end

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin : cxl_port_control_dsp_PROC
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_port_cache_enable_dsp            <= #TP 1'b0;
        cfg_cxl_port_mem_enable_dsp              <= #TP 1'b0;
        cfg_cxl_port_sync_hdr_bypass_enable_dsp  <= #TP 1'b0;
        cfg_cxl_port_drift_buffer_enable_dsp     <= #TP 1'b0;
        cfg_cxl_port_68B_flit_vh_enable_dsp      <= #TP 1'b0;
        cfg_cxl_port_mld_enable_dsp              <= #TP 1'b0;
        cfg_cxl_port_disable_cxl1p1_training_dsp <= #TP 1'b0;
        cfg_cxl_port_lopt_flit_enable_dsp        <= #TP 1'b0; 
        cfg_cxl_port_pbr_flit_enable_dsp         <= #TP 1'b0;
    end else if(!upstream_port) begin
        cfg_cxl_port_cache_enable_dsp            <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0]) ? lbc_cdm_data[0] : cfg_cxl_port_cache_enable_dsp;
        cfg_cxl_port_mem_enable_dsp              <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0]) ? lbc_cdm_data[2] : cfg_cxl_port_mem_enable_dsp;
        cfg_cxl_port_sync_hdr_bypass_enable_dsp  <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0]) ? lbc_cdm_data[3] : cfg_cxl_port_sync_hdr_bypass_enable_dsp;
        cfg_cxl_port_drift_buffer_enable_dsp     <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0]) ? lbc_cdm_data[4] : cfg_cxl_port_drift_buffer_enable_dsp;
        cfg_cxl_port_68B_flit_vh_enable_dsp      <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0]) ? lbc_cdm_data[5] : cfg_cxl_port_68B_flit_vh_enable_dsp;
        cfg_cxl_port_mld_enable_dsp              <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0]) ? lbc_cdm_data[6] : cfg_cxl_port_mld_enable_dsp;
        cfg_cxl_port_disable_cxl1p1_training_dsp <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[0]) ? lbc_cdm_data[7] : cfg_cxl_port_disable_cxl1p1_training_dsp;
        cfg_cxl_port_lopt_flit_enable_dsp        <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[1]) ? lbc_cdm_data[13] : cfg_cxl_port_lopt_flit_enable_dsp;
        cfg_cxl_port_pbr_flit_enable_dsp         <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[1]) ? lbc_cdm_data[14] : cfg_cxl_port_pbr_flit_enable_dsp;
    end
end

assign {cfg_cxl_port_retimer2_present, cfg_cxl_port_retimer1_present} = upstream_port ? {cfg_cxl_port_retimer2_present_usp, cfg_cxl_port_retimer1_present_usp} : {cfg_cxl_port_retimer2_present_dsp, cfg_cxl_port_retimer1_present_dsp};

assign cfg_cxl_port_retimer1_present_usp   =  1'b0;
assign cfg_cxl_port_retimer2_present_usp   =  1'b0;

always @( posedge aux_clk or negedge non_sticky_rst_n ) begin : retimer_present_dsp_PROC
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_port_retimer1_present_dsp   <= #TP 1'b0;
        cfg_cxl_port_retimer2_present_dsp   <= #TP 1'b0;
    end
    else if(!upstream_port) begin
        cfg_cxl_port_retimer1_present_dsp   <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[1]) ? lbc_cdm_data[8] : cfg_cxl_port_retimer1_present_dsp;
        cfg_cxl_port_retimer2_present_dsp   <= #TP (cxl_port_reg_id[3] & cxl_port_write_pulse[1]) ? lbc_cdm_data[9] : cfg_cxl_port_retimer2_present_dsp;
    end
end


// ------------------------------------------------------------------
// CXL Flex Bus Port Status Register (0x0e)
// ------------------------------------------------------------------

wire   cfg_cxl_port_io_enabled;
assign cfg_cxl_port_io_enabled = 1'b1;

reg    correctable_protocol_id_frame_err_reg;
reg    uncorrectable_protocol_id_frame_err_reg;
reg    unexpected_protocol_id_dropped_reg;
reg    retimers_present_mismatched_reg;
reg    fb_enable_bits_phase2_mismatch_reg;

assign cfg_cxl_port_retimers_pre_mismatched = retimers_present_mismatched_reg;

wire   correctable_protocol_id_frame_err_clr;
wire   uncorrectable_protocol_id_frame_err_clr;
wire   unexpected_protocol_id_dropped_clr;
wire   retimers_present_mismatched_clr;
wire   fb_enable_bits_phase2_mismatch_clr;

assign correctable_protocol_id_frame_err_clr    = (cxl_port_reg_id[3] & cxl_port_write_pulse[3] & lbc_cdm_data[24]);
assign uncorrectable_protocol_id_frame_err_clr  = (cxl_port_reg_id[3] & cxl_port_write_pulse[3] & lbc_cdm_data[25]);
assign unexpected_protocol_id_dropped_clr       = (cxl_port_reg_id[3] & cxl_port_write_pulse[3] & lbc_cdm_data[26]);
assign retimers_present_mismatched_clr          = (cxl_port_reg_id[3] & cxl_port_write_pulse[3] & lbc_cdm_data[27]);
assign fb_enable_bits_phase2_mismatch_clr       = (cxl_port_reg_id[3] & cxl_port_write_pulse[3] & lbc_cdm_data[28]);


assign cxl_port_reg_14 = {1'h0, ltssm_cxl_enable.cxl_mld_enabled, ltssm_cxl_enable.cxl_68B_flit_vh_enabled, ltssm_cxl_enable.drift_buffer_enabled, ltssm_cxl_enable.sync_hdr_bypass_enabled, ltssm_cxl_enable.mem_enabled, ltssm_cxl_enable.io_enabled, ltssm_cxl_enable.cache_enabled}; // updated by jding on 15Aug2019
assign cxl_port_reg_15 = {ltssm_cxl_enable.cxl_throttle_required, ltssm_cxl_enable.cxl_pbr_flit_enabled, ltssm_cxl_enable.cxl_lopt_flit_enabled, fb_enable_bits_phase2_mismatch_reg, retimers_present_mismatched_reg, unexpected_protocol_id_dropped_reg, uncorrectable_protocol_id_frame_err_reg, correctable_protocol_id_frame_err_reg}; 


always @( posedge aux_clk or negedge sticky_rst_n ) begin : correctable_protocol_id_frame_err_PROC
    if ( !sticky_rst_n ) 
        correctable_protocol_id_frame_err_reg   <= #TP 1'b0;        
    else if (correctable_protocol_id_frame_err)
        correctable_protocol_id_frame_err_reg   <= #TP 1'b1;
    else if (correctable_protocol_id_frame_err_clr)  
        correctable_protocol_id_frame_err_reg   <= #TP 1'b0;    
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin : uncorrectable_protocol_id_frame_err_PROC
    if ( !sticky_rst_n ) 
        uncorrectable_protocol_id_frame_err_reg   <= #TP 1'b0;       
    else if (uncorrectable_protocol_id_frame_err)
        uncorrectable_protocol_id_frame_err_reg   <= #TP 1'b1;
    else if (uncorrectable_protocol_id_frame_err_clr)  
        uncorrectable_protocol_id_frame_err_reg   <= #TP 1'b0;    
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin : unexpected_protocol_id_dropped_PROC
    if ( !sticky_rst_n ) 
        unexpected_protocol_id_dropped_reg   <= #TP 1'b0;      
    else if (unexpected_protocol_id_dropped)
        unexpected_protocol_id_dropped_reg   <= #TP 1'b1;
    else if (unexpected_protocol_id_dropped_clr)  
        unexpected_protocol_id_dropped_reg   <= #TP 1'b0;    
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin : retimers_present_mismatched_PROC
    if ( !sticky_rst_n ) 
        retimers_present_mismatched_reg   <= #TP 1'b0;      
    else if (retimers_present_mismatched)
        retimers_present_mismatched_reg   <= #TP 1'b1;
    else if (retimers_present_mismatched_clr)  
        retimers_present_mismatched_reg   <= #TP 1'b0;    
end

always @( posedge aux_clk or negedge sticky_rst_n ) begin : fb_enable_bits_phase2_mismatch_PROC
    if ( !sticky_rst_n ) 
        fb_enable_bits_phase2_mismatch_reg   <= #TP 1'b0;      
    else if (fb_enable_bits_phase2_mismatch)
        fb_enable_bits_phase2_mismatch_reg   <= #TP 1'b1;
    else if (fb_enable_bits_phase2_mismatch_clr)  
        fb_enable_bits_phase2_mismatch_reg   <= #TP 1'b0;    
end


// --------------------------------------------------------------------------------------
// CXL Flex Bus Port Received Modified TS Data Phase 1 (0x10)
// --------------------------------------------------------------------------------------
// cxl_port_reg_id  - 4
// PCIE Offset      - `CXL_PORT_PTR + 10h
// length           - 4 byte
// Cfig register    - cxl_port_reg_19, cxl_port_reg_18, cxl_port_reg_17, cxl_port_reg_16
// --------------------------------------------------------------------------------------
reg [23:0] cfg_cxl_port_rcvd_mod_ts_data_phase1;

assign cxl_port_reg_16 = cfg_cxl_port_rcvd_mod_ts_data_phase1[7:0]  ;
assign cxl_port_reg_17 = cfg_cxl_port_rcvd_mod_ts_data_phase1[15:8] ;
assign cxl_port_reg_18 = cfg_cxl_port_rcvd_mod_ts_data_phase1[23:16];
assign cxl_port_reg_19 = 8'h0;
// ---------------------------------------------------------------
// CXL Flex Bus Port Received Modified TS Data Phase 1 (0x10)
// ---------------------------------------------------------------
always @( posedge aux_clk or negedge non_sticky_rst_n ) begin : _PROC
    if ( !non_sticky_rst_n ) begin
        cfg_cxl_port_rcvd_mod_ts_data_phase1   <= #TP 24'h0;
    end else begin
        cfg_cxl_port_rcvd_mod_ts_data_phase1   <= #TP cxl_port_rcvd_mod_ts_data_phase1;
    end
end


// -----------------------------------------------------------------------------
// CXL Flex Bus Port Capability 2 (0x14)
// -----------------------------------------------------------------------------
// cxl_port_reg_id     - 5
// PCIE Offset      - `CXL_PORT_PTR + 14h
// length           - 4 byte
// Cfig register    - cxl_port_reg_23, cxl_port_reg_22, cxl_port_reg_21, cxl_port_reg_20
// -----------------------------------------------------------------------------
assign cxl_port_reg_20 = {7'h0, cfg_cxl_port_nop_hint_capable};
assign cxl_port_reg_21 = 8'h0;
assign cxl_port_reg_22 = 8'h0;
assign cxl_port_reg_23 = 8'h0;

assign cfg_cxl_port_nop_hint_capable = 1'h0;

// --------------------------------------------------------------------------------------
// CXL Flex Bus Port Control 2 (0x18)
// --------------------------------------------------------------------------------------
// cxl_port_reg_id     - 6
// PCIE Offset      - `CXL_PORT_PTR + 18h
// length           - 4 byte
// Cfig register    - cxl_port_reg_27, cxl_port_reg_26, cxl_port_reg_25, cxl_port_reg_24
// --------------------------------------------------------------------------------------
assign cxl_port_reg_24 = {7'h0, cfg_cxl_port_nop_hint_enable};
assign cxl_port_reg_25 = 8'h0;
assign cxl_port_reg_26 = 8'h0;
assign cxl_port_reg_27 = 8'h0;

assign cfg_cxl_port_nop_hint_enable = 1'h0;

// --------------------------------------------------------------------------------------
// CXL Flex Bus Port Status 2 (0x1C)
// --------------------------------------------------------------------------------------
// cxl_port_reg_id     - 7
// PCIE Offset      - `CXL_PORT_PTR + 1Ch
// length           - 4 byte
// Cfig register    - cxl_port_reg_31, cxl_port_reg_30, cxl_port_reg_29, cxl_port_reg_28
// --------------------------------------------------------------------------------------
assign cxl_port_reg_28 = 8'h0;
assign cxl_port_reg_29 = 8'h0;
assign cxl_port_reg_30 = 8'h0;
assign cxl_port_reg_31 = 8'h0;


// =============================================================================
// Register Read Operation
// =============================================================================

always @(*)
begin : read_data_PROC
    unique case (1'b1)
        cxl_port_reg_id[0]  : cxl_port_reg_data = {cxl_port_reg_03, cxl_port_reg_02, cxl_port_reg_01, cxl_port_reg_00};   // 0x00
        cxl_port_reg_id[1]  : cxl_port_reg_data = {cxl_port_reg_07, cxl_port_reg_06, cxl_port_reg_05, cxl_port_reg_04};   // 0x04
        cxl_port_reg_id[2]  : cxl_port_reg_data = {cxl_port_reg_11, cxl_port_reg_10, cxl_port_reg_09, cxl_port_reg_08};   // 0x08
        cxl_port_reg_id[3]  : cxl_port_reg_data = {cxl_port_reg_15, cxl_port_reg_14, cxl_port_reg_13, cxl_port_reg_12};   // 0x0C
        cxl_port_reg_id[4]  : cxl_port_reg_data = {cxl_port_reg_19, cxl_port_reg_18, cxl_port_reg_17, cxl_port_reg_16};   // 0x10
        cxl_port_reg_id[5]  : cxl_port_reg_data = {cxl_port_reg_23, cxl_port_reg_22, cxl_port_reg_21, cxl_port_reg_20};   // 0x14
        cxl_port_reg_id[6]  : cxl_port_reg_data = {cxl_port_reg_27, cxl_port_reg_26, cxl_port_reg_25, cxl_port_reg_24};   // 0x18
        cxl_port_reg_id[7]  : cxl_port_reg_data = {cxl_port_reg_31, cxl_port_reg_30, cxl_port_reg_29, cxl_port_reg_28};   // 0x1C
        default             : cxl_port_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end



endmodule // cdm_cxl_port_reg
