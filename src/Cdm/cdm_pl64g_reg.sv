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
// ---    $DateTime: 2023/06/26 08:32:07 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_pl64g_reg.sv#3 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Physical Layer 64.0 GT/s Extended Capability (PL64G)
// --- registers. This module is instantiated once and shared across all functions.
// --- A Write to the one of the PL64G registers for a given function, updates
// --- that register across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_pl64g_reg 
#(
parameter INST          = 0,                                  // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM      = 0,                                  // uniquifying parameter per function
parameter NL            = `CX_NL,                             // Number of Lanes
parameter NPL64G        = `PL64G_SIZE>>2,                     // Number of registers in Physical Layer 64.0 GT/s Extended Capability Structure
parameter TX_PSET_WD    = 4,                                  // Width of Transmitter Equalization Presets
parameter TP            = `TP                                 // Clock to Q delay (simulator insurance)
,parameter RCRB          = 0                                  // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space
)

                     (
// -------------- Inputs ---------------
input                           core_clk,                     // Core Clock
input                           non_sticky_rst_n,             // Non-Sticky Reset
input                           sticky_rst_n,                 // Sticky Reset
input                           cdm_clk_g,                    // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
input   [31:0]                  lbc_cdm_data,                 // Write Data
input                           lbc_cdm_dbi,                  // DBI Access
input   [3:0]                   pl64g_write_pulse,            // Write Byte Enables
input   [NPL64G-1:0]            pl64g_reg_id,                // PL64G Register ID
input                           upstream_port,                // Device is Upstream Port (EP/SW_UP)
input                           cfg_pcie_crosslink_supported, // Crosslink Supported bit (bit-8 of Link Capabilities 2 Register (Offset 1Ch))
input                           dbi_ro_wr_en,
input   [3:0]                   device_type,                  // used to indicate if device is RP

input                           smlh_ltssm_in_detectquiet,
input                           smlh_ls2_g6_eq_req,           // g6 Equalization Request
input  [3:1]                    smlh_ls2_g6_eq_success,       // g6 Equalization Successful {Phase 3, Phase 2, Phase 1}
input                           smlh_ls2_g6_eq_cmpl,          // g6 Equalization Complete
input                           smlh_ls2_g6_eq_enter,         // g6 Equalization Entered
input   [NL*TX_PSET_WD-1:0]     smlh_lec_g6_pset_ltx,         // Latest Transmitter Preset requested from Upstream Component (Not applicable to RC/SW_DW)
input                           smlh_g6_tx_precoding_on,    // g6 Transmitter Precoding On
input                           smlh_noeq_needed_rcvd,        //No EQ Needed Received: connected from 32.0 GT/s Status Register bit 10 (both have the same functionality)
input                           cxl_rcrb_enable,

// -------------- Outputs --------------
output  reg [31:0]              pl64g_reg_data,               // PL64G Register Read Data
output  wire [NL*TX_PSET_WD-1:0] cfg_lec_g6_pset_ltx,         // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
output  wire [NL*TX_PSET_WD-1:0] cfg_lec_g6_pset_rtx,         // Downstream Component Transmitter Preset
output  reg                     cfg_g6_tx_precode_req,      // Gen6 Transmitted Precode Request
output  reg                     cfg_ls2_g6_eq_req             // Gen6 Request Equalization
);

// -------------- Internal Signals --------------
wire                            upstream_component;     // Upstream Component ; Downstream Port ; Downstream Lanes
wire                            downstream_component;   // Downstream Component ; Upstream Port ; Upstream Lanes
wire                            int_lbc_cdm_dbi;        // Internal DBI Access
wire    [3:0]                   int_write_pulse;        // Internal Write Pulse
wire    [NPL64G-1:0]            int_reg_id;             // Internal Register ID

wire    [7:0]   pl64g_reg_03, pl64g_reg_02, pl64g_reg_01, pl64g_reg_00;
wire    [7:0]   pl64g_reg_07, pl64g_reg_06, pl64g_reg_05, pl64g_reg_04;
wire    [7:0]   pl64g_reg_11, pl64g_reg_10, pl64g_reg_09, pl64g_reg_08;
wire    [7:0]   pl64g_reg_15, pl64g_reg_14, pl64g_reg_13, pl64g_reg_12;
wire    [7:0]   pl64g_reg_19, pl64g_reg_18, pl64g_reg_17, pl64g_reg_16;
wire    [7:0]   pl64g_reg_23, pl64g_reg_22, pl64g_reg_21, pl64g_reg_20;

wire            rc_device;
wire            pcie_sw_down;

// Determine when Root Port is implemented - relevant for DM product in RP mode
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);

assign upstream_component   = !upstream_port;
assign downstream_component =  upstream_port;

assign int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;

// Extract write_pulse and reg_id for active function
assign int_write_pulse = pl64g_write_pulse;
assign int_reg_id      = pl64g_reg_id;

// -----------------------------------------------------------------------------
// Physical Layer 64.0 GT/s Extended Capability Header Register
// -----------------------------------------------------------------------------
// pl64g_reg_id     - 0
// PCIE Offset      - `PL64G_PTR
// length           - 4 byte
// Cfig register    - pl64g_reg_03, pl64g_reg_02, pl64g_reg_01, pl64g_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_pl64g_id;          // PL64G Capability ID
reg [3:0]   cfg_pl64g_ver;         // PL64G Capability Version
reg [11:0]  cfg_pl64g_next_ptr;    // PL64G Next Capability Offset
reg         pl64g_next_ptr_wr_updated;    // Asserted when PL64G Capability header has been changed by a DBI write


// Next Capability Pointer. Capabilities such as SRIOV should not
// be visible to a DM product in Root Port mode; hence, when either rc_device (or pcie_sw_down in a SW product)
// is true then the next pointer is in a smaller linked list.

assign {pl64g_reg_01, pl64g_reg_00}       = cfg_pl64g_id;
assign pl64g_reg_02[3:0]                  = cfg_pl64g_ver;
assign {pl64g_reg_03, pl64g_reg_02[7:4]}  = cfg_pl64g_next_ptr;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : pl64g_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_pl64g_id[15:0]       <= #TP `PCIE_PL64G_ECAP_ID;      // Capability ID = 0x002A
        cfg_pl64g_ver[3:0]       <= #TP `PCIE_PL64G_ECAP_VER;     // Capability version = 0x1
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_pl64g_id[7:0]        <= #TP (int_reg_id[0] & int_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_pl64g_id[7:0];
        cfg_pl64g_id[15:8]       <= #TP (int_reg_id[0] & int_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_pl64g_id[15:8];
        cfg_pl64g_ver[3:0]       <= #TP (int_reg_id[0] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_pl64g_ver[3:0];
    end
end // pl64g_cap_hdr_PROC

always @( posedge core_clk or negedge sticky_rst_n ) begin : pl64g_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_pl64g_next_ptr[11:0] <= #TP  `PL64G_NEXT_PTR;
    end else if (int_reg_id[0] && int_lbc_cdm_dbi) begin
        // Read-Only registers, but writable through DBI
        cfg_pl64g_next_ptr[3:0]  <= #TP int_write_pulse[2] ? lbc_cdm_data[23:20] : cfg_pl64g_next_ptr[3:0];
        cfg_pl64g_next_ptr[11:4] <= #TP int_write_pulse[3] ? lbc_cdm_data[31:24] : cfg_pl64g_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !pl64g_next_ptr_wr_updated) begin
        cfg_pl64g_next_ptr[11:0] <= #TP `DM_RP_PL64G_NEXT_PTR;
    end else if (!pl64g_next_ptr_wr_updated) begin
        cfg_pl64g_next_ptr[11:0] <= #TP (cxl_rcrb_enable) ? `RCRB_PL64G_NEXT_PTR :  `PL64G_NEXT_PTR;
    end
end // pl64g_cap_next_ptr_PROC

always @( posedge core_clk or negedge sticky_rst_n ) begin : pl64g_next_ptr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        pl64g_next_ptr_wr_updated <= #TP 1'b0;
    end else if (int_reg_id[0] && int_lbc_cdm_dbi && |int_write_pulse[3:2]) begin
        pl64g_next_ptr_wr_updated <= #TP 1'b1;
    end
end // pl64g_next_ptr_wr_update_PROC

// -----------------------------------------------------------------------------
// 64.0 GT/s Capabilities Register
// -----------------------------------------------------------------------------
// pl64g_reg_id     - 1
// PCIE Offset      - `PL64G_PTR + 04h
// length           - 4 byte
// Cfig register    - pl64g_reg_07, pl64g_reg_06, pl64g_reg_05, pl64g_reg_04
// -----------------------------------------------------------------------------
assign pl64g_reg_07 = 8'h00;  // [31:24] Reserved
assign pl64g_reg_06 = 8'h00;  // [23:16] Reserved
assign pl64g_reg_05 = 8'h00;  // [15: 8] Reserved
assign pl64g_reg_04 = 8'h00;  // [ 7: 0] Reserved

// -----------------------------------------------------------------------------
// 64.0 GT/s Control Register
// -----------------------------------------------------------------------------
// pl64g_reg_id     - 2
// PCIE Offset      - `PL64G_PTR + 08h
// length           - 4 byte
// Cfig register    - pl64g_reg_11, pl64g_reg_10, pl64g_reg_09, pl64g_reg_08
// -----------------------------------------------------------------------------
assign pl64g_reg_11 = 8'h00;  // [31:24] Reserved
assign pl64g_reg_10 = 8'h00;  // [23:16] Reserved
assign pl64g_reg_09 = 8'h00;  // [15: 8] Reserved
assign pl64g_reg_08 = 8'h00;  // [ 7: 0] Reserved


// -----------------------------------------------------------------------------
// 64.0 GT/s Status Register
// -----------------------------------------------------------------------------
// pl64g_reg_id     - 3
// PCIE Offset      - `PL64G_PTR + 0Ch
// length           - 4 byte
// Cfig register    - pl64g_reg_15, pl64g_reg_14, pl64g_reg_13, pl64g_reg_12
// -----------------------------------------------------------------------------
reg [3:1] cfg_ls2_g6_eq_success; // g6 Equalization Phase 3-1 Successful
reg       cfg_ls2_g6_eq_cmpl;    // g6 Equalization Complete

// ROS registers for cmpl, eq_success
// RW1CS register for eq_req.  Write 1 to clear.
assign pl64g_reg_15 = 8'h00;  // [31:24] Reserved
assign pl64g_reg_14 = 8'h00;  // [23:16] Reserved
assign pl64g_reg_13 = 8'h00;  // [15: 8] Reserved
assign pl64g_reg_12 = { smlh_noeq_needed_rcvd,    // [7]  No EQ Needed Received
                        cfg_g6_tx_precode_req,   // [6]   g6 Transmitted Precode Request
                        smlh_g6_tx_precoding_on,   // [5]   g6 Transmitter Precoding On
                        cfg_ls2_g6_eq_req,         // [4]   g6 Link Equalization Request
                        cfg_ls2_g6_eq_success[3],  // [3]   g6 Equalization Phase 3 Successful
                        cfg_ls2_g6_eq_success[2],  // [2]   g6 Equalization Phase 2 Successful
                        cfg_ls2_g6_eq_success[1],  // [1]   g6 Equalization Phase 1 Successful
                        cfg_ls2_g6_eq_cmpl};       // [0]   g6 Equalization Complete
always @(posedge core_clk or negedge sticky_rst_n) begin : status_reg_PROC
    if(!sticky_rst_n) begin
        cfg_ls2_g6_eq_req        <= #TP 0;
        cfg_ls2_g6_eq_success    <= #TP 0;
        cfg_ls2_g6_eq_cmpl       <= #TP 0;
    end else if (upstream_port) begin
        if (FUNC_NUM == 0) begin
            cfg_ls2_g6_eq_cmpl       <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g6_eq_enter) ? 1'b0 : smlh_ls2_g6_eq_cmpl        ? 1'b1 : cfg_ls2_g6_eq_cmpl;
            cfg_ls2_g6_eq_success[1] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g6_eq_enter) ? 1'b0 : smlh_ls2_g6_eq_success[1]  ? 1'b1 : cfg_ls2_g6_eq_success[1];
            cfg_ls2_g6_eq_success[2] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g6_eq_enter) ? 1'b0 : smlh_ls2_g6_eq_success[2]  ? 1'b1 : cfg_ls2_g6_eq_success[2];
            cfg_ls2_g6_eq_success[3] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g6_eq_enter) ? 1'b0 : smlh_ls2_g6_eq_success[3]  ? 1'b1 : cfg_ls2_g6_eq_success[3];
            cfg_ls2_g6_eq_req        <= #TP (smlh_ls2_g6_eq_enter | (int_write_pulse[0] & int_reg_id[3] & lbc_cdm_data[4])) ? 1'b0 : smlh_ls2_g6_eq_req ? 1'b1 : cfg_ls2_g6_eq_req;
        end else begin // reserved for > 0 func
            cfg_ls2_g6_eq_cmpl       <= #TP 0;
            cfg_ls2_g6_eq_success[1] <= #TP 0;
            cfg_ls2_g6_eq_success[2] <= #TP 0;
            cfg_ls2_g6_eq_success[3] <= #TP 0;
            cfg_ls2_g6_eq_req        <= #TP 0;
        end
    end else begin
        cfg_ls2_g6_eq_cmpl           <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g6_eq_enter) ? 1'b0 : smlh_ls2_g6_eq_cmpl       ? 1'b1 : cfg_ls2_g6_eq_cmpl;
        cfg_ls2_g6_eq_success[1]     <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g6_eq_enter) ? 1'b0 : smlh_ls2_g6_eq_success[1] ? 1'b1 : cfg_ls2_g6_eq_success[1];
        cfg_ls2_g6_eq_success[2]     <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g6_eq_enter) ? 1'b0 : smlh_ls2_g6_eq_success[2] ? 1'b1 : cfg_ls2_g6_eq_success[2];
        cfg_ls2_g6_eq_success[3]     <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g6_eq_enter) ? 1'b0 : smlh_ls2_g6_eq_success[3] ? 1'b1 : cfg_ls2_g6_eq_success[3];
        cfg_ls2_g6_eq_req            <= #TP (smlh_ls2_g6_eq_enter | (int_write_pulse[0] & int_reg_id[3] & lbc_cdm_data[4])) ? 1'b0 : smlh_ls2_g6_eq_req ? 1'b1 : cfg_ls2_g6_eq_req;
    end
end // status_reg_PROC

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : gen6_status_precoding_reg_PROC
    if ( !sticky_rst_n ) begin
        cfg_g6_tx_precode_req      <= #TP `CX_GEN6_DEFAULT_TX_PRECODE_REQ;
    end else begin
        // RWS
        cfg_g6_tx_precode_req      <= #TP (int_write_pulse[0] & int_reg_id[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[6] : cfg_g6_tx_precode_req;
    end
end // gen6_status_precoding_reg_PROC



// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// 64.0 GT/s Lane Equalization Control Register (Lane 3, Lane 2, Lane 1, Lane 0)
// -----------------------------------------------------------------------------
// pl64g_reg_id     - 4
// PCIE Offset      - `PL64G_PTR + 10h
// length           - 4 byte
// Cfig register    - pl64g_reg_19, pl64g_reg_18, pl64g_reg_17, pl64g_reg_16
// -----------------------------------------------------------------------------
localparam NL_10H   = (NL>=4) ? 4 : NL;
reg     [NL_10H*TX_PSET_WD-1:0]     cfg_lec_g6_pset_ltx_10h;    // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
reg     [NL_10H*TX_PSET_WD-1:0]     cfg_lec_g6_pset_rtx_10h;    // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
assign cfg_lec_g6_pset_ltx[NL_10H*TX_PSET_WD-1:0] = cfg_lec_g6_pset_ltx_10h;
assign cfg_lec_g6_pset_rtx[NL_10H*TX_PSET_WD-1:0] = cfg_lec_g6_pset_rtx_10h;

// Lane 0 Equalization Control Register
assign pl64g_reg_16 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g6_pset_ltx[1*TX_PSET_WD-1:0*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g6_pset_rtx_10h[1*TX_PSET_WD-1:0*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g6_pset_ltx_10h[1*TX_PSET_WD-1:0*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 1 Equalization Control Register
assign pl64g_reg_17 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g6_pset_ltx[2*TX_PSET_WD-1:1*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g6_pset_rtx_10h[2*TX_PSET_WD-1:1*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g6_pset_ltx_10h[2*TX_PSET_WD-1:1*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset


// Lane 2 Equalization Control Register
assign pl64g_reg_18 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g6_pset_ltx[3*TX_PSET_WD-1:2*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g6_pset_rtx_10h[3*TX_PSET_WD-1:2*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g6_pset_ltx_10h[3*TX_PSET_WD-1:2*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 3 Equalization Control Register
assign pl64g_reg_19 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g6_pset_ltx[4*TX_PSET_WD-1:3*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g6_pset_rtx_10h[4*TX_PSET_WD-1:3*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g6_pset_ltx_10h[4*TX_PSET_WD-1:3*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin 
    if (!sticky_rst_n) begin
        // Lane 0 Presets
        cfg_lec_g6_pset_ltx_10h[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP `DEFAULT_DSP_64G_TX_PRESET0;
        // Lane 1 Presets
        cfg_lec_g6_pset_ltx_10h[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP `DEFAULT_DSP_64G_TX_PRESET1;
        // Lane 2 Presets
        cfg_lec_g6_pset_ltx_10h[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP `DEFAULT_DSP_64G_TX_PRESET2;
        // Lane 3 Presets
        cfg_lec_g6_pset_ltx_10h[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP `DEFAULT_DSP_64G_TX_PRESET3;
    end else begin
        // Lane 0 Presets
        cfg_lec_g6_pset_ltx_10h[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP (int_reg_id[4] & int_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[0*4 +: 4] : cfg_lec_g6_pset_ltx_10h[1*TX_PSET_WD-1:0*TX_PSET_WD];
        // Lane 1 Presets
        cfg_lec_g6_pset_ltx_10h[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP (int_reg_id[4] & int_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[2*4 +: 4] : cfg_lec_g6_pset_ltx_10h[2*TX_PSET_WD-1:1*TX_PSET_WD];
        // Lane 2 Presets
        cfg_lec_g6_pset_ltx_10h[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP (int_reg_id[4] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[4*4 +: 4] : cfg_lec_g6_pset_ltx_10h[3*TX_PSET_WD-1:2*TX_PSET_WD];
        // Lane 3 Presets
        cfg_lec_g6_pset_ltx_10h[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP (int_reg_id[4] & int_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[6*4 +: 4] : cfg_lec_g6_pset_ltx_10h[4*TX_PSET_WD-1:3*TX_PSET_WD];
    end
end 
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin 
    if (!sticky_rst_n) begin
        // Lane 0 Presets
        cfg_lec_g6_pset_rtx_10h[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP `DEFAULT_USP_64G_TX_PRESET0;
        // Lane 1 Presets
        cfg_lec_g6_pset_rtx_10h[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP `DEFAULT_USP_64G_TX_PRESET1;
        // Lane 2 Presets
        cfg_lec_g6_pset_rtx_10h[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP `DEFAULT_USP_64G_TX_PRESET2;
        // Lane 3 Presets
        cfg_lec_g6_pset_rtx_10h[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP `DEFAULT_USP_64G_TX_PRESET3;
    end else begin
        // Lane 0 Presets
        cfg_lec_g6_pset_rtx_10h[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP (int_reg_id[4] & int_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[1*4 +: 4] : cfg_lec_g6_pset_rtx_10h[1*TX_PSET_WD-1:0*TX_PSET_WD];
        // Lane 1 Presets
        cfg_lec_g6_pset_rtx_10h[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP (int_reg_id[4] & int_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[3*4 +: 4] : cfg_lec_g6_pset_rtx_10h[2*TX_PSET_WD-1:1*TX_PSET_WD];
        // Lane 2 Presets
        cfg_lec_g6_pset_rtx_10h[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP (int_reg_id[4] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[5*4 +: 4] : cfg_lec_g6_pset_rtx_10h[3*TX_PSET_WD-1:2*TX_PSET_WD];
        // Lane 3 Presets
        cfg_lec_g6_pset_rtx_10h[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP (int_reg_id[4] & int_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[7*4 +: 4] : cfg_lec_g6_pset_rtx_10h[4*TX_PSET_WD-1:3*TX_PSET_WD];
    end
end 

// -----------------------------------------------------------------------------
// 64.0 GT/s Lane Equalization Control Register (Lane 7, Lane 6, Lane 5, Lane 4)
// -----------------------------------------------------------------------------
// pl64g_reg_id     - 5
// PCIE Offset      - `PL64G_PTR + 14h
// length           - 4 byte
// Cfig register    - pl64g_reg_23, pl64g_reg_22, pl64g_reg_21, pl64g_reg_20
// -----------------------------------------------------------------------------
localparam NL_14H   = 8;
reg     [NL_14H*TX_PSET_WD-1:4*TX_PSET_WD]     cfg_lec_g6_pset_ltx_14h;    // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
reg     [NL_14H*TX_PSET_WD-1:4*TX_PSET_WD]     cfg_lec_g6_pset_rtx_14h;    // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
assign cfg_lec_g6_pset_ltx[NL_14H*TX_PSET_WD-1:4*TX_PSET_WD] = cfg_lec_g6_pset_ltx_14h;
assign cfg_lec_g6_pset_rtx[NL_14H*TX_PSET_WD-1:4*TX_PSET_WD] = cfg_lec_g6_pset_rtx_14h;

// Lane 4 Equalization Control Register
assign pl64g_reg_20 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g6_pset_ltx[5*TX_PSET_WD-1:4*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g6_pset_rtx_14h[5*TX_PSET_WD-1:4*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g6_pset_ltx_14h[5*TX_PSET_WD-1:4*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 5 Equalization Control Register
assign pl64g_reg_21 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g6_pset_ltx[6*TX_PSET_WD-1:5*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g6_pset_rtx_14h[6*TX_PSET_WD-1:5*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g6_pset_ltx_14h[6*TX_PSET_WD-1:5*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 6 Equalization Control Register
assign pl64g_reg_22 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g6_pset_ltx[7*TX_PSET_WD-1:6*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g6_pset_rtx_14h[7*TX_PSET_WD-1:6*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g6_pset_ltx_14h[7*TX_PSET_WD-1:6*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 7 Equalization Control Register
assign pl64g_reg_23 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g6_pset_ltx[8*TX_PSET_WD-1:7*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g6_pset_rtx_14h[8*TX_PSET_WD-1:7*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g6_pset_ltx_14h[8*TX_PSET_WD-1:7*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin 
    if (!sticky_rst_n) begin
        // Lane 4 Presets
        cfg_lec_g6_pset_ltx_14h[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP `DEFAULT_DSP_64G_TX_PRESET4;
        // Lane 5 Presets
        cfg_lec_g6_pset_ltx_14h[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP `DEFAULT_DSP_64G_TX_PRESET5;
        // Lane 6 Presets
        cfg_lec_g6_pset_ltx_14h[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP `DEFAULT_DSP_64G_TX_PRESET6;
        // Lane 7 Presets
        cfg_lec_g6_pset_ltx_14h[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP `DEFAULT_DSP_64G_TX_PRESET7;
    end else begin
        // Lane 4 Presets
        cfg_lec_g6_pset_ltx_14h[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP (int_reg_id[5] & int_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[0*4 +: 4] : cfg_lec_g6_pset_ltx_14h[5*TX_PSET_WD-1:4*TX_PSET_WD];
        // Lane 5 Presets
        cfg_lec_g6_pset_ltx_14h[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP (int_reg_id[5] & int_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[2*4 +: 4] : cfg_lec_g6_pset_ltx_14h[6*TX_PSET_WD-1:5*TX_PSET_WD];
        // Lane 6 Presets
        cfg_lec_g6_pset_ltx_14h[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP (int_reg_id[5] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[4*4 +: 4] : cfg_lec_g6_pset_ltx_14h[7*TX_PSET_WD-1:6*TX_PSET_WD];
        // Lane 7 Presets
        cfg_lec_g6_pset_ltx_14h[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP (int_reg_id[5] & int_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[6*4 +: 4] : cfg_lec_g6_pset_ltx_14h[8*TX_PSET_WD-1:7*TX_PSET_WD];
    end
end 
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin 
    if (!sticky_rst_n) begin
        // Lane 4 Presets
        cfg_lec_g6_pset_rtx_14h[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP `DEFAULT_USP_64G_TX_PRESET4;
        // Lane 5 Presets
        cfg_lec_g6_pset_rtx_14h[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP `DEFAULT_USP_64G_TX_PRESET5;
        // Lane 6 Presets
        cfg_lec_g6_pset_rtx_14h[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP `DEFAULT_USP_64G_TX_PRESET6;
        // Lane 7 Presets
        cfg_lec_g6_pset_rtx_14h[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP `DEFAULT_USP_64G_TX_PRESET7;
    end else begin
        // Lane 4 Presets
        cfg_lec_g6_pset_rtx_14h[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP (int_reg_id[5] & int_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[1*4 +: 4] : cfg_lec_g6_pset_rtx_14h[5*TX_PSET_WD-1:4*TX_PSET_WD];
        // Lane 5 Presets
        cfg_lec_g6_pset_rtx_14h[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP (int_reg_id[5] & int_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[3*4 +: 4] : cfg_lec_g6_pset_rtx_14h[6*TX_PSET_WD-1:5*TX_PSET_WD];
        // Lane 6 Presets
        cfg_lec_g6_pset_rtx_14h[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP (int_reg_id[5] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[5*4 +: 4] : cfg_lec_g6_pset_rtx_14h[7*TX_PSET_WD-1:6*TX_PSET_WD];
        // Lane 7 Presets
        cfg_lec_g6_pset_rtx_14h[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP (int_reg_id[5] & int_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[7*4 +: 4] : cfg_lec_g6_pset_rtx_14h[8*TX_PSET_WD-1:7*TX_PSET_WD];
    end
end 


// =============================================================================
// Register Read Operation
// =============================================================================

// reg_id[6:4] is TBD, read data is undefined. But address space/offset for reg_id[6:4] is taken for Gen6 Extended Capability Register
always @(*) begin : read_data_PROC
    unique case (1'b1)
        int_reg_id[0]  : pl64g_reg_data = {pl64g_reg_03, pl64g_reg_02, pl64g_reg_01, pl64g_reg_00};
        int_reg_id[1]  : pl64g_reg_data = {pl64g_reg_07, pl64g_reg_06, pl64g_reg_05, pl64g_reg_04};
        int_reg_id[2]  : pl64g_reg_data = {pl64g_reg_11, pl64g_reg_10, pl64g_reg_09, pl64g_reg_08};
        int_reg_id[3]  : pl64g_reg_data = {pl64g_reg_15, pl64g_reg_14, pl64g_reg_13, pl64g_reg_12};
        int_reg_id[4]  : pl64g_reg_data = {pl64g_reg_19, pl64g_reg_18, pl64g_reg_17, pl64g_reg_16};
        int_reg_id[5]  : pl64g_reg_data = {pl64g_reg_23, pl64g_reg_22, pl64g_reg_21, pl64g_reg_20};
        default        : pl64g_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end // read_data_PROC

endmodule // cdm_pl64g_reg
