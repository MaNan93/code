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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_spcie_reg.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Secondary PCI Express Extended Capability (SPCIE)
// --- registers. This module is instantiated once and shared across all functions.
// --- A Write to the one of the SPCIE registers for a given function, updates
// --- that register across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_spcie_reg (
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    cdm_clk_g,
    lbc_cdm_data,
    lbc_cdm_dbi,
    spcie_write_pulse,
    spcie_reg_id,
    upstream_port,
    rmlh_lane_err,
    smlh_lec_pset_ltx,
    smlh_lec_pset_lrx,
    smlh_ls2_eq_enter,
    smlh_ls2_g4_eq_enter,
    cfg_pcie_crosslink_supported,
    dbi_ro_wr_en,
    device_type,
    cxl_rcrb_enable,
    
// -- outputs --
    spcie_reg_data,
    cfg_perform_eq,
    cfg_link_eq_req_int_en,
    cfg_lec_pset_ltx,
    cfg_lec_pset_lrx,
    cfg_lec_pset_rtx,
    cfg_lec_pset_rrx
);

parameter INST          = 0;                            // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM      = 0;                            // uniquifying parameter per function
parameter TP            = `TP;                          // Clock to Q delay (simulator insurance)
parameter NL            = `CX_NL;                       // Number of Lanes

localparam NSPCIE       = `SPCIE_SIZE >> 2;             // Number of registers in Secondary PCIe Extended Capability Structure
localparam TX_PSET_WD   = 4;                            // Width of Transmitter Equalization Presets
localparam RX_PSET_WD   = 3;                            // Width of Receiver Equalization Presets
parameter RCRB          = 0;                            // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space

// -------------- Inputs ---------------
input                           core_clk;               // Core Clock
input                           non_sticky_rst_n;       // Non-Sticky Reset
input                           sticky_rst_n;           // Sticky Reset
input                           cdm_clk_g;              // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
input   [31:0]                  lbc_cdm_data;           // Write Data 
input                           lbc_cdm_dbi;            // DBI Access
input   [3:0]                   spcie_write_pulse;      // Write Byte Enables
input   [NSPCIE-1:0]            spcie_reg_id;           // SPCIE Register ID
input                           upstream_port;          // Device is Upstream Port (EP/SW_UP)
input   [NL-1:0]                rmlh_lane_err;          // Receiver Lane Error 
input   [NL*TX_PSET_WD-1:0]     smlh_lec_pset_ltx;      // Latest Transmitter Preset requested from Upstream Component (Not applicable to RC/SW_DW)
input   [NL*RX_PSET_WD-1:0]     smlh_lec_pset_lrx;      // Latest Receiver Preset requested from Upstream Component (Not applicable to RC/SW_DW)
input                           smlh_ls2_eq_enter;      // LTSSM Equalization state entry
input                           smlh_ls2_g4_eq_enter;      // LTSSM Equalization state entry
input                           cfg_pcie_crosslink_supported; // Crosslink Supported bit (bit-8 of Link Capabilities 2 Register (Offset 2Ch))
input                           dbi_ro_wr_en;
input   [3:0]                   device_type;             // used to indicate if device is RP
input                           cxl_rcrb_enable;

// -------------- Outputs --------------
output  [31:0]                  spcie_reg_data;         // SPCIE Register Read Data
output                          cfg_perform_eq;         // Perform Equalization
output                          cfg_link_eq_req_int_en; // Link Equalization Request Interrupt Enable
output  [NL*TX_PSET_WD-1:0]     cfg_lec_pset_ltx;       // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
output  [NL*RX_PSET_WD-1:0]     cfg_lec_pset_lrx;       // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
output  [NL*TX_PSET_WD-1:0]     cfg_lec_pset_rtx;       // Downstream Component Transmitter Preset
output  [NL*RX_PSET_WD-1:0]     cfg_lec_pset_rrx;       // Downstream Component Receiver Preset Hint

// -------------- Internal Signals --------------
wire                            upstream_component;     // Upstream Component ; Downstream Port ; Downstream Lanes
wire                            downstream_component;   // Downstream Component ; Upstream Port ; Upstream Lanes
wire                            dbi_ro_wr_en;           // DBI Read Only Write Enable
wire                            int_lbc_cdm_dbi;        // Internal DBI Access
reg     [31:0]                  spcie_reg_data;         // SPCIE Register Read Data
reg                             cfg_perform_eq;         // Perform Equalization
reg                             cfg_link_eq_req_int_en; // Link Equalization Request Interrupt Enable
reg     [NL-1:0]                cfg_lane_err;           // Lane Error Status Bits
reg     [NL*TX_PSET_WD-1:0]     cfg_lec_pset_ltx;       // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
reg     [NL*RX_PSET_WD-1:0]     cfg_lec_pset_lrx;       // Upstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)
reg     [NL*TX_PSET_WD-1:0]     cfg_lec_pset_rtx;       // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
reg     [NL*RX_PSET_WD-1:0]     cfg_lec_pset_rrx;       // Downstream Component Receiver Preset Hint (Not applicable to EP/SW_UP)

wire    [7:0]   spcie_reg_03, spcie_reg_02, spcie_reg_01, spcie_reg_00;
wire    [7:0]   spcie_reg_07, spcie_reg_06, spcie_reg_05, spcie_reg_04;
wire    [7:0]   spcie_reg_11, spcie_reg_10, spcie_reg_09, spcie_reg_08;
wire    [7:0]   spcie_reg_15, spcie_reg_14, spcie_reg_13, spcie_reg_12;
wire    [7:0]   spcie_reg_19, spcie_reg_18, spcie_reg_17, spcie_reg_16;
wire    [7:0]   spcie_reg_23, spcie_reg_22, spcie_reg_21, spcie_reg_20;
wire    [7:0]   spcie_reg_27, spcie_reg_26, spcie_reg_25, spcie_reg_24;
wire    [7:0]   spcie_reg_31, spcie_reg_30, spcie_reg_29, spcie_reg_28;
wire    [7:0]   spcie_reg_35, spcie_reg_34, spcie_reg_33, spcie_reg_32;
wire    [7:0]   spcie_reg_39, spcie_reg_38, spcie_reg_37, spcie_reg_36;
wire    [7:0]   spcie_reg_43, spcie_reg_42, spcie_reg_41, spcie_reg_40;


wire            rc_device;
wire            pcie_sw_down;

// Determine when Root Port is implemented - relevant for DM product in RP
// mode.
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);

assign upstream_component   = !upstream_port;
assign downstream_component =  upstream_port;

assign int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;

// Extract write_pulse and reg_id for active function

// -----------------------------------------------------------------------------
// Secondary PCI Express Extended Capability Header Register
// -----------------------------------------------------------------------------
// spcie_reg_id     - 0
// PCIE Offset      - `SPCIE_PTR
// length           - 4 byte
// Cfig register    - spcie_reg_03, spcie_reg_02, spcie_reg_01, spcie_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_spcie_id;          // SPCIE Capability ID
reg [3:0]   cfg_spcie_ver;         // SPCIE Capability Version
reg [11:0]  cfg_spcie_next_ptr;    // SPCIE Next Capability Offset
reg         spcie_next_ptr_wr_updated;    // Asserted when SPCIE Capability header has been changed by a DBI write


// Next Capability Pointer. Capabilities such as SRIOV should not 
// be visible to a DM product in Root Port mode; hence, when either rc_device (or pcie_sw_down in a SW product)
// is true then the next pointer is in a smaller linked list.

assign {spcie_reg_01, spcie_reg_00}       = cfg_spcie_id;
assign spcie_reg_02[3:0]                  = cfg_spcie_ver;
assign {spcie_reg_03, spcie_reg_02[7:4]}  = cfg_spcie_next_ptr;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : spcie_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_spcie_id[15:0]       <= #TP `PCIE_SPCIE_ECAP_ID;      // Capability ID = 0x0019
        cfg_spcie_ver[3:0]       <= #TP `PCIE_SPCIE_ECAP_VER;     // Capability version = 0x1
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_spcie_id[7:0]        <= #TP (spcie_reg_id[0] & spcie_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_spcie_id[7:0];
        cfg_spcie_id[15:8]       <= #TP (spcie_reg_id[0] & spcie_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_spcie_id[15:8];
        cfg_spcie_ver[3:0]       <= #TP (spcie_reg_id[0] & spcie_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_spcie_ver[3:0];
    end
end
                                                                                          
always @( posedge core_clk or negedge sticky_rst_n ) begin : spcie_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_spcie_next_ptr[11:0] <= #TP `SPCIE_NEXT_PTR;
    end else if (spcie_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_spcie_next_ptr[3:0]  <= #TP spcie_write_pulse[2] ? lbc_cdm_data[23:20] : cfg_spcie_next_ptr[3:0];
        cfg_spcie_next_ptr[11:4] <= #TP spcie_write_pulse[3] ? lbc_cdm_data[31:24] : cfg_spcie_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !spcie_next_ptr_wr_updated) begin
        cfg_spcie_next_ptr[11:0] <= #TP  `DM_RP_SPCIE_NEXT_PTR;
    end else if (!spcie_next_ptr_wr_updated) begin
        cfg_spcie_next_ptr[11:0] <= #TP (cxl_rcrb_enable) ? `RCRB_SPCIE_NEXT_PTR :  `SPCIE_NEXT_PTR;
    end
end
                                                                                          
always @( posedge core_clk or negedge sticky_rst_n ) begin : spcie_next_ptr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        spcie_next_ptr_wr_updated <= #TP 1'b0;
    end else if (spcie_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |spcie_write_pulse[3:2]) begin
        spcie_next_ptr_wr_updated <= #TP 1'b1;
    end
end

// -----------------------------------------------------------------------------
// Link Control 3 Register
// -----------------------------------------------------------------------------
// spcie_reg_id     - 1
// PCIE Offset      - `SPCIE_PTR + 04h
// length           - 4 byte
// Cfig register    - spcie_reg_07, spcie_reg_06, spcie_reg_05, spcie_reg_04
// -----------------------------------------------------------------------------
assign {spcie_reg_07, spcie_reg_06} =  16'h0;                     // [31:16] Reserved
assign {spcie_reg_05, spcie_reg_04} = {14'h0,                     // [15:2]  Reserved
                                       cfg_link_eq_req_int_en,    // [1]     Link Equalization Request Interrupt Enable
                                       cfg_perform_eq};           // [0]     Perform Equalization

always @(posedge core_clk or negedge non_sticky_rst_n)
begin : link_ctrl3_proc
    if (!non_sticky_rst_n) begin
        cfg_perform_eq            <= #TP 0;
        
    end else begin
        cfg_perform_eq            <= #TP (upstream_port & !cfg_pcie_crosslink_supported) ? 1'b0 :                         // Reserved for Upstream Port && !crosslink_supported
                                         (smlh_ls2_eq_enter
                                         | smlh_ls2_g4_eq_enter
                                         ) ? 1'b0 :                                                       // set to 0 upon entry to Equalization state for downstream port
                                         (spcie_reg_id[1] & spcie_write_pulse[0]) ? lbc_cdm_data[0] : cfg_perform_eq;         // R/W for Downstream Port and Upstream Port && crosslink_supported
        
    end
end

always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin 
    if (!non_sticky_rst_n) begin
  
        cfg_link_eq_req_int_en    <= #TP 0;
    end else begin
        
        cfg_link_eq_req_int_en    <= #TP (upstream_port & !cfg_pcie_crosslink_supported) ? 1'b0 :                        // Reserved for Upstream Port && !crosslink_supported
                                         (spcie_reg_id[1] & spcie_write_pulse[0]) ? lbc_cdm_data[1] : cfg_link_eq_req_int_en; // R/W for Downstream Port and Upstream Port && crosslink_supported
    end
end


// -----------------------------------------------------------------------------
// Lane Error Status Register
// -----------------------------------------------------------------------------
// spcie_reg_id     - 2
// PCIE Offset      - `SPCIE_PTR + 08h
// length           - 4 byte
// Cfig register    - spcie_reg_11, spcie_reg_10, spcie_reg_09, spcie_reg_08 
// -----------------------------------------------------------------------------
assign {spcie_reg_11, spcie_reg_10, spcie_reg_09, spcie_reg_08} =  { {(32-NL){1'b0}},  // [31-NL:NL] Reserved
                                                                     cfg_lane_err};    // [NL-1:]    Lane Error Status
always @(posedge core_clk or negedge sticky_rst_n)
begin : lane_err_status_PROC
    if (!sticky_rst_n)
        cfg_lane_err        <= #TP 0; 
    else begin 
        // Lane 0 Error Status (RW1C)
        cfg_lane_err[0]     <= #TP (rmlh_lane_err[0])                                      ? 1'b1 : 
                                   (spcie_reg_id[2] & spcie_write_pulse[0] & lbc_cdm_data[0])  ? 1'b0 : cfg_lane_err[0];

        // Lane 1 Error Status (RW1C)
        cfg_lane_err[1]     <= #TP (rmlh_lane_err[1])                                      ? 1'b1 : 
                                   (spcie_reg_id[2] & spcie_write_pulse[0] & lbc_cdm_data[1])  ? 1'b0 : cfg_lane_err[1];
        // Lane 2 Error Status (RW1C)
        cfg_lane_err[2]     <= #TP (rmlh_lane_err[2])                                      ? 1'b1 : 
                                   (spcie_reg_id[2] & spcie_write_pulse[0] & lbc_cdm_data[2])  ? 1'b0 : cfg_lane_err[2];

        // Lane 3 Error Status (RW1C)
        cfg_lane_err[3]     <= #TP (rmlh_lane_err[3])                                      ? 1'b1 : 
                                   (spcie_reg_id[2] & spcie_write_pulse[0] & lbc_cdm_data[3])  ? 1'b0 : cfg_lane_err[3];
        // Lane 4 Error Status (RW1C)
        cfg_lane_err[4]     <= #TP (rmlh_lane_err[4])                                      ? 1'b1 : 
                                   (spcie_reg_id[2] & spcie_write_pulse[0] & lbc_cdm_data[4])  ? 1'b0 : cfg_lane_err[4];

        // Lane 5 Error Status (RW1C)
        cfg_lane_err[5]     <= #TP (rmlh_lane_err[5])                                      ? 1'b1 : 
                                   (spcie_reg_id[2] & spcie_write_pulse[0] & lbc_cdm_data[5])  ? 1'b0 : cfg_lane_err[5];

        // Lane 6 Error Status (RW1C)
        cfg_lane_err[6]     <= #TP (rmlh_lane_err[6])                                      ? 1'b1 : 
                                   (spcie_reg_id[2] & spcie_write_pulse[0] & lbc_cdm_data[6])  ? 1'b0 : cfg_lane_err[6];

        // Lane 7 Error Status (RW1C)
        cfg_lane_err[7]     <= #TP (rmlh_lane_err[7])                                      ? 1'b1 : 
                                   (spcie_reg_id[2] & spcie_write_pulse[0] & lbc_cdm_data[7])  ? 1'b0 : cfg_lane_err[7];

    end
end

// -----------------------------------------------------------------------------
// Lane Equalization Control Register (Lane 1, Lane 0)
// -----------------------------------------------------------------------------
// spcie_reg_id     - 3
// PCIE Offset      - `SPCIE_PTR + 0Ch
// length           - 4 byte
// Cfig register    - spcie_reg_15, spcie_reg_14, spcie_reg_13, spcie_reg_12
// -----------------------------------------------------------------------------

// Lane 0 Equalization Control Register
assign spcie_reg_13 = (upstream_port && !cfg_pcie_crosslink_supported) ? // Upstream Port && !crosslink_supported (Read Only)
                      {1'b0,                                             // [15]    Reserved
                       smlh_lec_pset_lrx[1*RX_PSET_WD-1:0*RX_PSET_WD],   // [14:12] Upstream Port Receiver Preset Hint
                       smlh_lec_pset_ltx[1*TX_PSET_WD-1:0*TX_PSET_WD]}   // [11:8]  Upstream Port Transmitter Preset
                      :                                                  // Otherwise, HwInit
                      {1'b0,                                             // [15]    Reserved
                       cfg_lec_pset_rrx[1*RX_PSET_WD-1:0*RX_PSET_WD],    // [14:12] Upstream Port Receiver Preset Hint
                       cfg_lec_pset_rtx[1*TX_PSET_WD-1:0*TX_PSET_WD]};   // [11:8]  Upstream Port Transmitter Preset

assign spcie_reg_12 = (upstream_port && !cfg_pcie_crosslink_supported) ? 8'h0 //Reserved for upstream_port && !crosslink_supported
                      :                                                       // Otherwise, HwInit
                      {1'b0,                                                  // [7]     Reserved
                       cfg_lec_pset_lrx[1*RX_PSET_WD-1:0*RX_PSET_WD],         // [6:4]   Downstream Port Receiver Preset Hint
                       cfg_lec_pset_ltx[1*TX_PSET_WD-1:0*TX_PSET_WD]};        // [3:0]   Downstream Port Transmitter Preset

// Lane 1 Equalization Control Register
assign spcie_reg_15 = (upstream_port && !cfg_pcie_crosslink_supported) ? // Upstream Port && !crosslink_supported (Read Only)
                      {1'b0,                                             // [15]    Reserved
                       smlh_lec_pset_lrx[2*RX_PSET_WD-1:1*RX_PSET_WD],   // [14:12] Upstream Port Receiver Preset Hint
                       smlh_lec_pset_ltx[2*TX_PSET_WD-1:1*TX_PSET_WD]}   // [11:8]  Upstream Port Transmitter Preset
                      :                                                  // Otherwise, HwInit
                      {1'b0,                                             // [15]    Reserved
                       cfg_lec_pset_rrx[2*RX_PSET_WD-1:1*RX_PSET_WD],    // [14:12] Upstream Port Receiver Preset Hint
                       cfg_lec_pset_rtx[2*TX_PSET_WD-1:1*TX_PSET_WD]};   // [11:8]  Upstream Port Transmitter Preset

assign spcie_reg_14 = (upstream_port && !cfg_pcie_crosslink_supported) ? 8'h0 //Reserved for upstream_port && !crosslink_supported
                      :                                                       // Otherwise, HwInit
                      {1'b0,                                                  // [7]     Reserved
                       cfg_lec_pset_lrx[2*RX_PSET_WD-1:1*RX_PSET_WD],         // [6:4]   Downstream Port Receiver Preset Hint
                       cfg_lec_pset_ltx[2*TX_PSET_WD-1:1*TX_PSET_WD]};        // [3:0]   Downstream Port Transmitter Preset


// spyglass disable_block W552
// SMD: Busses 'cfg_lec_pset_ltx','cfg_lec_pset_lrx', 'cfg_lec_pset_rtx' and 'cfg_lec_pset_rrx' are driven inside more than one sequential block.
// SJ: Fully functional code, flagging spyglass error due to multiple assignments of the same bus in multiple always blocks.
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
    if (!sticky_rst_n) begin
        cfg_lec_pset_ltx[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP `DEFAULT_DSP_TX_PRESET0;
        cfg_lec_pset_lrx[1*RX_PSET_WD-1:0*RX_PSET_WD]    <= #TP `DEFAULT_DSP_RX_PRESET_HINT0;
        
        cfg_lec_pset_ltx[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP `DEFAULT_DSP_TX_PRESET1;
        cfg_lec_pset_lrx[2*RX_PSET_WD-1:1*RX_PSET_WD]    <= #TP `DEFAULT_DSP_RX_PRESET_HINT1;
    
     end else begin 
        // Lane 0 Presets
        cfg_lec_pset_ltx[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP (spcie_reg_id[3] & spcie_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[3:0]   : cfg_lec_pset_ltx[1*TX_PSET_WD-1:0*TX_PSET_WD];
        cfg_lec_pset_lrx[1*RX_PSET_WD-1:0*RX_PSET_WD]    <= #TP (spcie_reg_id[3] & spcie_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[6:4]   : cfg_lec_pset_lrx[1*RX_PSET_WD-1:0*RX_PSET_WD];
        
        // Lane 1 Presets 
        cfg_lec_pset_ltx[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP (spcie_reg_id[3] & spcie_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_lec_pset_ltx[2*TX_PSET_WD-1:1*TX_PSET_WD];
        cfg_lec_pset_lrx[2*RX_PSET_WD-1:1*RX_PSET_WD]    <= #TP (spcie_reg_id[3] & spcie_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[22:20] : cfg_lec_pset_lrx[2*RX_PSET_WD-1:1*RX_PSET_WD];
        
    end
end
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
    if (!sticky_rst_n) begin
        cfg_lec_pset_rtx[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP `DEFAULT_USP_TX_PRESET0;
        cfg_lec_pset_rrx[1*RX_PSET_WD-1:0*RX_PSET_WD]    <= #TP `DEFAULT_USP_RX_PRESET_HINT0;
        cfg_lec_pset_rtx[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP `DEFAULT_USP_TX_PRESET1;
        cfg_lec_pset_rrx[2*RX_PSET_WD-1:1*RX_PSET_WD]    <= #TP `DEFAULT_USP_RX_PRESET_HINT1;
     end else begin 
        // Lane 0 Presets
        cfg_lec_pset_rtx[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP (spcie_reg_id[3] & spcie_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[11:8]  : cfg_lec_pset_rtx[1*TX_PSET_WD-1:0*TX_PSET_WD];
        cfg_lec_pset_rrx[1*RX_PSET_WD-1:0*RX_PSET_WD]    <= #TP (spcie_reg_id[3] & spcie_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[14:12] : cfg_lec_pset_rrx[1*RX_PSET_WD-1:0*RX_PSET_WD];
        // Lane 1 Presets 
        cfg_lec_pset_rtx[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP (spcie_reg_id[3] & spcie_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[27:24] : cfg_lec_pset_rtx[2*TX_PSET_WD-1:1*TX_PSET_WD];
        cfg_lec_pset_rrx[2*RX_PSET_WD-1:1*RX_PSET_WD]    <= #TP (spcie_reg_id[3] & spcie_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[30:28] : cfg_lec_pset_rrx[2*RX_PSET_WD-1:1*RX_PSET_WD];
    end
end
// spyglass enable_block W552

// -----------------------------------------------------------------------------
// Lane Equalization Control Register (Lane 3, Lane 2)
// -----------------------------------------------------------------------------
// spcie_reg_id     - 4
// PCIE Offset      - `SPCIE_PTR + 10h
// length           - 4 byte
// Cfig register    - spcie_reg_19, spcie_reg_18, spcie_reg_17, spcie_reg_16
// -----------------------------------------------------------------------------

// Lane 2 Equalization Control Register
assign spcie_reg_17 = (upstream_port && !cfg_pcie_crosslink_supported) ? // Upstream Port && !crosslink_supported (Read Only)
                      {1'b0,                                             // [15]    Reserved
                       smlh_lec_pset_lrx[3*RX_PSET_WD-1:2*RX_PSET_WD],   // [14:12] Upstream Port Receiver Preset Hint
                       smlh_lec_pset_ltx[3*TX_PSET_WD-1:2*TX_PSET_WD]}   // [11:8]  Upstream Port Transmitter Preset
                      :                                                  // Otherwise, HwInit
                      {1'b0,                                             // [15]    Reserved
                       cfg_lec_pset_rrx[3*RX_PSET_WD-1:2*RX_PSET_WD],    // [14:12] Upstream Port Receiver Preset Hint
                       cfg_lec_pset_rtx[3*TX_PSET_WD-1:2*TX_PSET_WD]};   // [11:8]  Upstream Port Transmitter Preset

assign spcie_reg_16 = (upstream_port && !cfg_pcie_crosslink_supported) ? 8'h0 //Reserved for upstream_port && !crosslink_supported
                      :                                                       // Otherwise, HwInit
                      {1'b0,                                                  // [7]     Reserved
                       cfg_lec_pset_lrx[3*RX_PSET_WD-1:2*RX_PSET_WD],         // [6:4]   Downstream Port Receiver Preset Hint
                       cfg_lec_pset_ltx[3*TX_PSET_WD-1:2*TX_PSET_WD]};        // [3:0]   Downstream Port Transmitter Preset

// Lane 3 Equalization Control Register
assign spcie_reg_19 = (upstream_port && !cfg_pcie_crosslink_supported) ? // Upstream Port && !crosslink_supported (Read Only)
                      {1'b0,                                             // [15]    Reserved
                       smlh_lec_pset_lrx[4*RX_PSET_WD-1:3*RX_PSET_WD],   // [14:12] Upstream Port Receiver Preset Hint
                       smlh_lec_pset_ltx[4*TX_PSET_WD-1:3*TX_PSET_WD]}   // [11:8]  Upstream Port Transmitter Preset
                      :                                                  // Otherwise, HwInit
                      {1'b0,                                             // [15]    Reserved
                       cfg_lec_pset_rrx[4*RX_PSET_WD-1:3*RX_PSET_WD],    // [14:12] Upstream Port Receiver Preset Hint
                       cfg_lec_pset_rtx[4*TX_PSET_WD-1:3*TX_PSET_WD]};   // [11:8]  Upstream Port Transmitter Preset

assign spcie_reg_18 = (upstream_port && !cfg_pcie_crosslink_supported) ? 8'h0 //Reserved for upstream_port && !crosslink_supported
                      :                                                       // Otherwise, HwInit
                      {1'b0,                                                  // [7]     Reserved
                       cfg_lec_pset_lrx[4*RX_PSET_WD-1:3*RX_PSET_WD],         // [6:4]   Downstream Port Receiver Preset Hint
                       cfg_lec_pset_ltx[4*TX_PSET_WD-1:3*TX_PSET_WD]};        // [3:0]   Downstream Port Transmitter Preset

// spyglass disable_block W552
// SMD: Busses 'cfg_lec_pset_ltx','cfg_lec_pset_lrx', 'cfg_lec_pset_rtx' and 'cfg_lec_pset_rrx' are driven inside more than one sequential block.
// SJ: Fully functional code, flagging spyglass error due to multiple assignments of the same bus in multiple always blocks.
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
    if (!sticky_rst_n) begin
        // Lane 2 Presets
        cfg_lec_pset_ltx[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP `DEFAULT_DSP_TX_PRESET2;
        cfg_lec_pset_lrx[3*RX_PSET_WD-1:2*RX_PSET_WD]    <= #TP `DEFAULT_DSP_RX_PRESET_HINT2;
        // Lane 3 Presets 
        cfg_lec_pset_ltx[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP `DEFAULT_DSP_TX_PRESET3;
        cfg_lec_pset_lrx[4*RX_PSET_WD-1:3*RX_PSET_WD]    <= #TP `DEFAULT_DSP_RX_PRESET_HINT3;
     end else begin 
        // Lane 2 Presets
        cfg_lec_pset_ltx[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP (spcie_reg_id[4] & spcie_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[3:0]   : cfg_lec_pset_ltx[3*TX_PSET_WD-1:2*TX_PSET_WD];
        cfg_lec_pset_lrx[3*RX_PSET_WD-1:2*RX_PSET_WD]    <= #TP (spcie_reg_id[4] & spcie_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[6:4]   : cfg_lec_pset_lrx[3*RX_PSET_WD-1:2*RX_PSET_WD];
        // Lane 3 Presets 
        cfg_lec_pset_ltx[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP (spcie_reg_id[4] & spcie_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_lec_pset_ltx[4*TX_PSET_WD-1:3*TX_PSET_WD];
        cfg_lec_pset_lrx[4*RX_PSET_WD-1:3*RX_PSET_WD]    <= #TP (spcie_reg_id[4] & spcie_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[22:20] : cfg_lec_pset_lrx[4*RX_PSET_WD-1:3*RX_PSET_WD];
    end
end
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
    if (!sticky_rst_n) begin
        // Lane 2 Presets
        cfg_lec_pset_rtx[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP `DEFAULT_USP_TX_PRESET2;
        cfg_lec_pset_rrx[3*RX_PSET_WD-1:2*RX_PSET_WD]    <= #TP `DEFAULT_USP_RX_PRESET_HINT2;
        // Lane 3 Presets 
        cfg_lec_pset_rtx[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP `DEFAULT_USP_TX_PRESET3;
        cfg_lec_pset_rrx[4*RX_PSET_WD-1:3*RX_PSET_WD]    <= #TP `DEFAULT_USP_RX_PRESET_HINT3;
     end else begin 
        // Lane 2 Presets
        cfg_lec_pset_rtx[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP (spcie_reg_id[4] & spcie_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[11:8]  : cfg_lec_pset_rtx[3*TX_PSET_WD-1:2*TX_PSET_WD];
        cfg_lec_pset_rrx[3*RX_PSET_WD-1:2*RX_PSET_WD]    <= #TP (spcie_reg_id[4] & spcie_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[14:12] : cfg_lec_pset_rrx[3*RX_PSET_WD-1:2*RX_PSET_WD];
        // Lane 3 Presets 
        cfg_lec_pset_rtx[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP (spcie_reg_id[4] & spcie_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[27:24] : cfg_lec_pset_rtx[4*TX_PSET_WD-1:3*TX_PSET_WD];
        cfg_lec_pset_rrx[4*RX_PSET_WD-1:3*RX_PSET_WD]    <= #TP (spcie_reg_id[4] & spcie_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[30:28] : cfg_lec_pset_rrx[4*RX_PSET_WD-1:3*RX_PSET_WD];
    end
end
// spyglass enable_block W552

// -----------------------------------------------------------------------------
// Lane Equalization Control Register (Lane 5, Lane 4)
// -----------------------------------------------------------------------------
// spcie_reg_id     - 5
// PCIE Offset      - `SPCIE_PTR + 14h
// length           - 4 byte
// Cfig register    - spcie_reg_23, spcie_reg_22, spcie_reg_21, spcie_reg_20
// -----------------------------------------------------------------------------

// Lane 4 Equalization Control Register
assign spcie_reg_21 = (upstream_port && !cfg_pcie_crosslink_supported) ? // Upstream Port && !crosslink_supported (Read Only)
                      {1'b0,                                             // [15]    Reserved
                       smlh_lec_pset_lrx[5*RX_PSET_WD-1:4*RX_PSET_WD],   // [14:12] Upstream Port Receiver Preset Hint
                       smlh_lec_pset_ltx[5*TX_PSET_WD-1:4*TX_PSET_WD]}   // [11:8]  Upstream Port Transmitter Preset
                      :                                                  // Otherwise, HwInit
                      {1'b0,                                             // [15]    Reserved
                       cfg_lec_pset_rrx[5*RX_PSET_WD-1:4*RX_PSET_WD],    // [14:12] Upstream Port Receiver Preset Hint
                       cfg_lec_pset_rtx[5*TX_PSET_WD-1:4*TX_PSET_WD]};   // [11:8]  Upstream Port Transmitter Preset

assign spcie_reg_20 = (upstream_port && !cfg_pcie_crosslink_supported) ? 8'h0 //Reserved for upstream_port && !crosslink_supported
                      :                                                       // Otherwise, HwInit
                      {1'b0,                                                  // [7]     Reserved
                       cfg_lec_pset_lrx[5*RX_PSET_WD-1:4*RX_PSET_WD],         // [6:4]   Downstream Port Receiver Preset Hint
                       cfg_lec_pset_ltx[5*TX_PSET_WD-1:4*TX_PSET_WD]};        // [3:0]   Downstream Port Transmitter Preset

// Lane 5 Equalization Control Register
assign spcie_reg_23 = (upstream_port && !cfg_pcie_crosslink_supported) ? // Upstream Port && !crosslink_supported (Read Only)
                      {1'b0,                                             // [15]    Reserved
                       smlh_lec_pset_lrx[6*RX_PSET_WD-1:5*RX_PSET_WD],   // [14:12] Upstream Port Receiver Preset Hint
                       smlh_lec_pset_ltx[6*TX_PSET_WD-1:5*TX_PSET_WD]}   // [11:8]  Upstream Port Transmitter Preset
                      :                                                  // Otherwise, HwInit
                      {1'b0,                                             // [15]    Reserved
                       cfg_lec_pset_rrx[6*RX_PSET_WD-1:5*RX_PSET_WD],    // [14:12] Upstream Port Receiver Preset Hint
                       cfg_lec_pset_rtx[6*TX_PSET_WD-1:5*TX_PSET_WD]};   // [11:8]  Upstream Port Transmitter Preset

assign spcie_reg_22 = (upstream_port && !cfg_pcie_crosslink_supported) ? 8'h0 //Reserved for upstream_port && !crosslink_supported
                      :                                                       // Otherwise, HwInit
                      {1'b0,                                                  // [7]     Reserved
                       cfg_lec_pset_lrx[6*RX_PSET_WD-1:5*RX_PSET_WD],         // [6:4]   Downstream Port Receiver Preset Hint
                       cfg_lec_pset_ltx[6*TX_PSET_WD-1:5*TX_PSET_WD]};        // [3:0]   Downstream Port Transmitter Preset

// spyglass disable_block W552
// SMD: Busses 'cfg_lec_pset_ltx','cfg_lec_pset_lrx', 'cfg_lec_pset_rtx' and 'cfg_lec_pset_rrx' are driven inside more than one sequential block.
// SJ: Fully functional code, flagging spyglass error due to multiple assignments of the same bus in multiple always blocks.
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
    if (!sticky_rst_n) begin
        // Lane 4 Presets
        cfg_lec_pset_ltx[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP `DEFAULT_DSP_TX_PRESET4;
        cfg_lec_pset_lrx[5*RX_PSET_WD-1:4*RX_PSET_WD]    <= #TP `DEFAULT_DSP_RX_PRESET_HINT4;
        // Lane 5 Presets 
        cfg_lec_pset_ltx[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP `DEFAULT_DSP_TX_PRESET5;
        cfg_lec_pset_lrx[6*RX_PSET_WD-1:5*RX_PSET_WD]    <= #TP `DEFAULT_DSP_RX_PRESET_HINT5;
     end else begin 
        // Lane 4 Presets
        cfg_lec_pset_ltx[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP (spcie_reg_id[5] & spcie_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[3:0]   : cfg_lec_pset_ltx[5*TX_PSET_WD-1:4*TX_PSET_WD];
        cfg_lec_pset_lrx[5*RX_PSET_WD-1:4*RX_PSET_WD]    <= #TP (spcie_reg_id[5] & spcie_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[6:4]   : cfg_lec_pset_lrx[5*RX_PSET_WD-1:4*RX_PSET_WD];
        // Lane 5 Presets 
        cfg_lec_pset_ltx[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP (spcie_reg_id[5] & spcie_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_lec_pset_ltx[6*TX_PSET_WD-1:5*TX_PSET_WD];
        cfg_lec_pset_lrx[6*RX_PSET_WD-1:5*RX_PSET_WD]    <= #TP (spcie_reg_id[5] & spcie_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[22:20] : cfg_lec_pset_lrx[6*RX_PSET_WD-1:5*RX_PSET_WD];
    end
end
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
    if (!sticky_rst_n) begin
        // Lane 4 Presets
        cfg_lec_pset_rtx[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP `DEFAULT_USP_TX_PRESET4;
        cfg_lec_pset_rrx[5*RX_PSET_WD-1:4*RX_PSET_WD]    <= #TP `DEFAULT_USP_RX_PRESET_HINT4;
        // Lane 5 Presets 
        cfg_lec_pset_rtx[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP `DEFAULT_USP_TX_PRESET5;
        cfg_lec_pset_rrx[6*RX_PSET_WD-1:5*RX_PSET_WD]    <= #TP `DEFAULT_USP_RX_PRESET_HINT5;
     end else begin 
        // Lane 4 Presets
        cfg_lec_pset_rtx[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP (spcie_reg_id[5] & spcie_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[11:8]  : cfg_lec_pset_rtx[5*TX_PSET_WD-1:4*TX_PSET_WD];
        cfg_lec_pset_rrx[5*RX_PSET_WD-1:4*RX_PSET_WD]    <= #TP (spcie_reg_id[5] & spcie_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[14:12] : cfg_lec_pset_rrx[5*RX_PSET_WD-1:4*RX_PSET_WD];
        // Lane 5 Presets 
        cfg_lec_pset_rtx[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP (spcie_reg_id[5] & spcie_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[27:24] : cfg_lec_pset_rtx[6*TX_PSET_WD-1:5*TX_PSET_WD];
        cfg_lec_pset_rrx[6*RX_PSET_WD-1:5*RX_PSET_WD]    <= #TP (spcie_reg_id[5] & spcie_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[30:28] : cfg_lec_pset_rrx[6*RX_PSET_WD-1:5*RX_PSET_WD];
    end
end
// spyglass enable_block W552

// -----------------------------------------------------------------------------
// Lane Equalization Control Register (Lane 7, Lane 6)
// -----------------------------------------------------------------------------
// spcie_reg_id     - 6
// PCIE Offset      - `SPCIE_PTR + 18h
// length           - 4 byte
// Cfig register    - spcie_reg_27, spcie_reg_26, spcie_reg_25, spcie_reg_24
// -----------------------------------------------------------------------------

// Lane 6 Equalization Control Register
assign spcie_reg_25 = (upstream_port && !cfg_pcie_crosslink_supported) ? // Upstream Port && !crosslink_supported (Read Only)
                      {1'b0,                                             // [15]    Reserved
                       smlh_lec_pset_lrx[7*RX_PSET_WD-1:6*RX_PSET_WD],   // [14:12] Upstream Port Receiver Preset Hint
                       smlh_lec_pset_ltx[7*TX_PSET_WD-1:6*TX_PSET_WD]}   // [11:8]  Upstream Port Transmitter Preset
                      :                                                  // Otherwise, HwInit
                      {1'b0,                                             // [15]    Reserved
                       cfg_lec_pset_rrx[7*RX_PSET_WD-1:6*RX_PSET_WD],    // [14:12] Upstream Port Receiver Preset Hint
                       cfg_lec_pset_rtx[7*TX_PSET_WD-1:6*TX_PSET_WD]};   // [11:8]  Upstream Port Transmitter Preset

assign spcie_reg_24 = (upstream_port && !cfg_pcie_crosslink_supported) ? 8'h0 //Reserved for upstream_port && !crosslink_supported
                      :                                                       // Otherwise, HwInit
                      {1'b0,                                                  // [7]     Reserved
                       cfg_lec_pset_lrx[7*RX_PSET_WD-1:6*RX_PSET_WD],         // [6:4]   Downstream Port Receiver Preset Hint
                       cfg_lec_pset_ltx[7*TX_PSET_WD-1:6*TX_PSET_WD]};        // [3:0]   Downstream Port Transmitter Preset

// Lane 7 Equalization Control Register
assign spcie_reg_27 = (upstream_port && !cfg_pcie_crosslink_supported) ? // Upstream Port && !crosslink_supported (Read Only)
                      {1'b0,                                             // [15]    Reserved
                       smlh_lec_pset_lrx[8*RX_PSET_WD-1:7*RX_PSET_WD],   // [14:12] Upstream Port Receiver Preset Hint
                       smlh_lec_pset_ltx[8*TX_PSET_WD-1:7*TX_PSET_WD]}   // [11:8]  Upstream Port Transmitter Preset
                      :                                                  // Otherwise, HwInit
                      {1'b0,                                             // [15]    Reserved
                       cfg_lec_pset_rrx[8*RX_PSET_WD-1:7*RX_PSET_WD],    // [14:12] Upstream Port Receiver Preset Hint
                       cfg_lec_pset_rtx[8*TX_PSET_WD-1:7*TX_PSET_WD]};   // [11:8]  Upstream Port Transmitter Preset

assign spcie_reg_26 = (upstream_port && !cfg_pcie_crosslink_supported) ? 8'h0 //Reserved for upstream_port && !crosslink_supported
                      :                                                       // Otherwise, HwInit
                      {1'b0,                                                  // [7]     Reserved
                       cfg_lec_pset_lrx[8*RX_PSET_WD-1:7*RX_PSET_WD],         // [6:4]   Downstream Port Receiver Preset Hint
                       cfg_lec_pset_ltx[8*TX_PSET_WD-1:7*TX_PSET_WD]};        // [3:0]   Downstream Port Transmitter Preset

// spyglass disable_block W552
// SMD: Busses 'cfg_lec_pset_ltx','cfg_lec_pset_lrx', 'cfg_lec_pset_rtx' and 'cfg_lec_pset_rrx' are driven inside more than one sequential block.
// SJ: Fully functional code, flagging spyglass error due to multiple assignments of the same bus in multiple always blocks.
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
    if (!sticky_rst_n) begin
        // Lane 6 Presets
        cfg_lec_pset_ltx[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP `DEFAULT_DSP_TX_PRESET6;  
        cfg_lec_pset_lrx[7*RX_PSET_WD-1:6*RX_PSET_WD]    <= #TP `DEFAULT_DSP_RX_PRESET_HINT6;
        // Lane 7 Presets 
        cfg_lec_pset_ltx[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP `DEFAULT_DSP_TX_PRESET7;
        cfg_lec_pset_lrx[8*RX_PSET_WD-1:7*RX_PSET_WD]    <= #TP `DEFAULT_DSP_RX_PRESET_HINT7;
     end else begin 
        // Lane 6 Presets
        cfg_lec_pset_ltx[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP (spcie_reg_id[6] & spcie_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[3:0]   : cfg_lec_pset_ltx[7*TX_PSET_WD-1:6*TX_PSET_WD];
        cfg_lec_pset_lrx[7*RX_PSET_WD-1:6*RX_PSET_WD]    <= #TP (spcie_reg_id[6] & spcie_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[6:4]   : cfg_lec_pset_lrx[7*RX_PSET_WD-1:6*RX_PSET_WD];
        // Lane 7 Presets 
        cfg_lec_pset_ltx[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP (spcie_reg_id[6] & spcie_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_lec_pset_ltx[8*TX_PSET_WD-1:7*TX_PSET_WD];
        cfg_lec_pset_lrx[8*RX_PSET_WD-1:7*RX_PSET_WD]    <= #TP (spcie_reg_id[6] & spcie_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[22:20] : cfg_lec_pset_lrx[8*RX_PSET_WD-1:7*RX_PSET_WD];
    end
end
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
    if (!sticky_rst_n) begin
        // Lane 6 Presets
        cfg_lec_pset_rtx[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP `DEFAULT_USP_TX_PRESET6;
        cfg_lec_pset_rrx[7*RX_PSET_WD-1:6*RX_PSET_WD]    <= #TP `DEFAULT_USP_RX_PRESET_HINT6;
        // Lane 7 Presets 
        cfg_lec_pset_rtx[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP `DEFAULT_USP_TX_PRESET7;
        cfg_lec_pset_rrx[8*RX_PSET_WD-1:7*RX_PSET_WD]    <= #TP `DEFAULT_USP_RX_PRESET_HINT7;
     end else begin 
        // Lane 6 Presets
        cfg_lec_pset_rtx[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP (spcie_reg_id[6] & spcie_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[11:8]  : cfg_lec_pset_rtx[7*TX_PSET_WD-1:6*TX_PSET_WD];
        cfg_lec_pset_rrx[7*RX_PSET_WD-1:6*RX_PSET_WD]    <= #TP (spcie_reg_id[6] & spcie_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[14:12] : cfg_lec_pset_rrx[7*RX_PSET_WD-1:6*RX_PSET_WD];
        // Lane 7 Presets 
        cfg_lec_pset_rtx[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP (spcie_reg_id[6] & spcie_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[27:24] : cfg_lec_pset_rtx[8*TX_PSET_WD-1:7*TX_PSET_WD];
        cfg_lec_pset_rrx[8*RX_PSET_WD-1:7*RX_PSET_WD]    <= #TP (spcie_reg_id[6] & spcie_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[30:28] : cfg_lec_pset_rrx[8*RX_PSET_WD-1:7*RX_PSET_WD];
    end
end
// spyglass enable_block W552



// =============================================================================
// Register Read Operation
// =============================================================================

always @(*)
begin : read_data_PROC
    unique case (1'b1)
        spcie_reg_id[0]  : spcie_reg_data = {spcie_reg_03, spcie_reg_02, spcie_reg_01, spcie_reg_00};
        spcie_reg_id[1]  : spcie_reg_data = {spcie_reg_07, spcie_reg_06, spcie_reg_05, spcie_reg_04};
        spcie_reg_id[2]  : spcie_reg_data = {spcie_reg_11, spcie_reg_10, spcie_reg_09, spcie_reg_08};
        spcie_reg_id[3]  : spcie_reg_data = {spcie_reg_15, spcie_reg_14, spcie_reg_13, spcie_reg_12};
        spcie_reg_id[4]  : spcie_reg_data = {spcie_reg_19, spcie_reg_18, spcie_reg_17, spcie_reg_16};
        spcie_reg_id[5]  : spcie_reg_data = {spcie_reg_23, spcie_reg_22, spcie_reg_21, spcie_reg_20};
        spcie_reg_id[6]  : spcie_reg_data = {spcie_reg_27, spcie_reg_26, spcie_reg_25, spcie_reg_24};
        default        : spcie_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end

endmodule // cdm_spcie_reg 
