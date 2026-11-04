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
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_pl32g_reg.sv#13 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Physical Layer 32.0 GT/s Extended Capability (PL32G)
// --- registers. This module is instantiated once and shared across all functions.
// --- A Write to the one of the PL32G registers for a given function, updates
// --- that register across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_pl32g_reg 
#(
parameter INST          = 0,                                  // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM      = 0,                                  // uniquifying parameter per function
parameter NL            = `CX_NL,                             // Number of Lanes
parameter NPL32G        = `PL32G_SIZE>>2,                     // Number of registers in Physical Layer 32.0 GT/s Extended Capability Structure
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
input   [3:0]                   pl32g_write_pulse,            // Write Byte Enables
input   [NPL32G-1:0]             pl32g_reg_id,                // PL32G Register ID
input                           upstream_port,                // Device is Upstream Port (EP/SW_UP)
input                           cfg_pcie_crosslink_supported, // Crosslink Supported bit (bit-8 of Link Capabilities 2 Register (Offset 2Ch))
input                           dbi_ro_wr_en,
input   [3:0]                   device_type,                  // used to indicate if device is RP

input                           smlh_ltssm_in_detectquiet,
input                           smlh_ls2_g5_eq_req,           // g5 Equalization Request
input  [3:1]                    smlh_ls2_g5_eq_success,       // g5 Equalization Successful {Phase 3, Phase 2, Phase 1}
input                           smlh_ls2_g5_eq_cmpl,          // g5 Equalization Complete
input                           smlh_ls2_g5_eq_enter,         // g5 Equalization Entered
input   [NL*5-1:0]              rmlh_deskew_ctlskp_err,       // CS-SKP-OS error [0]data parity[1]1st retimer[2]2nd retimer[3]margin crc[4]margin parity
input   [NL*TX_PSET_WD-1:0]     smlh_lec_g5_pset_ltx,         // Latest Transmitter Preset requested from Upstream Component (Not applicable to RC/SW_DW)
input                           smlh_mod_ts_rcvd,             // g5 Modified TS Received
input   [55:0]                  mod_ts_data_rcvd,             // mod ts data rcvd, {info2[23:0], vendor_id[15:0], info1[15:5], ap_negotiation[1:0], mod_ts_usage_mode[2:0]}
input   [55:0]                  mod_ts_data_sent,             // mod ts data txed, {info2[23:0], vendor_id[15:0], info1[15:5], ap_negotiation[1:0], mod_ts_usage_mode[2:0]}
input   [1:0]                   smlh_elbc_rcvd,               // g5 Received Enhanced Link Behavior Control
input                           smlh_tx_precoding_on,         // g5 Transmitter Precoding On
input                           smlh_noeq_needed_rcvd,        // g5 No EQ Needed Received
input                           cxl_rcrb_enable,

// -------------- Outputs --------------
output  reg [31:0]              pl32g_reg_data,               // PL32G Register Read Data
output  reg                     cfg_mod_ts_pcie_support,      // support Modified ts usage mode 0(PCIe)
output  wire                    cfg_bypass_eq_enable,         // enable skip lower rate EQs
output  wire                    cfg_alt_protocol_enable,      // enable alternate protocol
output  wire                    cfg_no_eq_needed_enable,      // enable No Equalization Needed
output  reg                     cfg_tx_precode_req,           // Transmitted Precode Request
output  wire [NL*TX_PSET_WD-1:0] cfg_lec_g5_pset_ltx,         // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
output  wire [NL*TX_PSET_WD-1:0] cfg_lec_g5_pset_rtx,         // Downstream Component Transmitter Preset
output  reg                     cfg_ls2_g5_eq_req             // Gen5 Request Equalization

);

// -------------- Internal Signals --------------
wire                            upstream_component;     // Upstream Component ; Downstream Port ; Downstream Lanes
wire                            downstream_component;   // Downstream Component ; Upstream Port ; Upstream Lanes
wire                            int_lbc_cdm_dbi;        // Internal DBI Access
wire    [3:0]                   int_write_pulse;        // Internal Write Pulse
wire    [NPL32G-1:0]            int_reg_id;             // Internal Register ID

wire    [7:0]   pl32g_reg_03, pl32g_reg_02, pl32g_reg_01, pl32g_reg_00;
wire    [7:0]   pl32g_reg_07, pl32g_reg_06, pl32g_reg_05, pl32g_reg_04;
wire    [7:0]   pl32g_reg_11, pl32g_reg_10, pl32g_reg_09, pl32g_reg_08;
wire    [7:0]   pl32g_reg_15, pl32g_reg_14, pl32g_reg_13, pl32g_reg_12;
wire    [7:0]   pl32g_reg_19, pl32g_reg_18, pl32g_reg_17, pl32g_reg_16;
wire    [7:0]   pl32g_reg_23, pl32g_reg_22, pl32g_reg_21, pl32g_reg_20;
wire    [7:0]   pl32g_reg_27, pl32g_reg_26, pl32g_reg_25, pl32g_reg_24;
wire    [7:0]   pl32g_reg_31, pl32g_reg_30, pl32g_reg_29, pl32g_reg_28;
wire    [7:0]   pl32g_reg_35, pl32g_reg_34, pl32g_reg_33, pl32g_reg_32;
wire    [7:0]   pl32g_reg_39, pl32g_reg_38, pl32g_reg_37, pl32g_reg_36;

wire            rc_device;
wire            pcie_sw_down;

// Determine when Root Port is implemented - relevant for DM product in RP mode
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);

assign upstream_component   = !upstream_port;
assign downstream_component =  upstream_port;

assign int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;

// Extract write_pulse and reg_id for active function
assign int_write_pulse = pl32g_write_pulse;
assign int_reg_id      = pl32g_reg_id;

// -----------------------------------------------------------------------------
// Physical Layer 32.0 GT/s Extended Capability Header Register
// -----------------------------------------------------------------------------
// pl32g_reg_id     - 0
// PCIE Offset      - `PL32G_PTR
// length           - 4 byte
// Cfig register    - pl32g_reg_03, pl32g_reg_02, pl32g_reg_01, pl32g_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_pl32g_id;          // PL32G Capability ID
reg [3:0]   cfg_pl32g_ver;         // PL32G Capability Version
reg [11:0]  cfg_pl32g_next_ptr;    // PL32G Next Capability Offset
reg         pl32g_next_ptr_wr_updated;    // Asserted when PL32G Capability header has been changed by a DBI write


// Next Capability Pointer. Capabilities such as SRIOV should not
// be visible to a DM product in Root Port mode; hence, when either rc_device (or pcie_sw_down in a SW product)
// is true then the next pointer is in a smaller linked list.

assign {pl32g_reg_01, pl32g_reg_00}       = cfg_pl32g_id;
assign pl32g_reg_02[3:0]                  = cfg_pl32g_ver;
assign {pl32g_reg_03, pl32g_reg_02[7:4]}  = cfg_pl32g_next_ptr;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : pl32g_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_pl32g_id[15:0]       <= #TP `PCIE_PL32G_ECAP_ID;      // Capability ID = 0x002A
        cfg_pl32g_ver[3:0]       <= #TP `PCIE_PL32G_ECAP_VER;     // Capability version = 0x1
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_pl32g_id[7:0]        <= #TP (int_reg_id[0] & int_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_pl32g_id[7:0];
        cfg_pl32g_id[15:8]       <= #TP (int_reg_id[0] & int_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_pl32g_id[15:8];
        cfg_pl32g_ver[3:0]       <= #TP (int_reg_id[0] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_pl32g_ver[3:0];
    end
end // pl32g_cap_hdr_PROC

always @( posedge core_clk or negedge sticky_rst_n ) begin : pl32g_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_pl32g_next_ptr[11:0] <= #TP  `PL32G_NEXT_PTR;
    end else if (int_reg_id[0] && int_lbc_cdm_dbi) begin
        // Read-Only registers, but writable through DBI
        cfg_pl32g_next_ptr[3:0]  <= #TP int_write_pulse[2] ? lbc_cdm_data[23:20] : cfg_pl32g_next_ptr[3:0];
        cfg_pl32g_next_ptr[11:4] <= #TP int_write_pulse[3] ? lbc_cdm_data[31:24] : cfg_pl32g_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !pl32g_next_ptr_wr_updated) begin
        cfg_pl32g_next_ptr[11:0] <= #TP `DM_RP_PL32G_NEXT_PTR;
    end else if (!pl32g_next_ptr_wr_updated) begin
        cfg_pl32g_next_ptr[11:0] <= #TP (cxl_rcrb_enable) ? `RCRB_PL32G_NEXT_PTR :  `PL32G_NEXT_PTR;
    end
end // pl32g_cap_next_ptr_PROC

always @( posedge core_clk or negedge sticky_rst_n ) begin : pl32g_next_ptr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        pl32g_next_ptr_wr_updated <= #TP 1'b0;
    end else if (int_reg_id[0] && int_lbc_cdm_dbi && |int_write_pulse[3:2]) begin
        pl32g_next_ptr_wr_updated <= #TP 1'b1;
    end
end // pl32g_next_ptr_wr_update_PROC

// -----------------------------------------------------------------------------
// 32.0 GT/s Capabilities Register
// -----------------------------------------------------------------------------
// pl32g_reg_id     - 1
// PCIE Offset      - `PL32G_PTR + 04h
// length           - 4 byte
// Cfig register    - pl32g_reg_07, pl32g_reg_06, pl32g_reg_05, pl32g_reg_04
// -----------------------------------------------------------------------------
reg         cfg_eq_bypass_highest_rate_support;  // [0] Support eq bypass highest rate
reg         cfg_no_eq_needed_support;            // [1] Support no eq needed
reg         cfg_mod_ts_pcie_support_i;           // [8] Support Modified ts usage mode 1 (PCIe)
logic       cfg_mod_ts_training_set_support;     // [9] Support Modified ts usage mode 1 (Training Set)
reg         cfg_mod_ts_alt_protocol_support;     // [10] Support Modified ts usage mode 2 (Alternate Protocol)
logic [4:0] cfg_mod_ts_rsvd_usage_mode;          // [15:11] Modified TS Reserved Usage Modes

assign cfg_mod_ts_training_set_support = 1'b0;
assign cfg_mod_ts_rsvd_usage_mode      = 0;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : cap_reg_PROC
    if ( !sticky_rst_n ) begin
        cfg_eq_bypass_highest_rate_support <= #TP `CX_DEFAULT_EQ_BYPASS_HIGHEST_RATE_SUPPORT;
        cfg_no_eq_needed_support           <= #TP `CX_DEFAULT_NO_EQ_NEEDED_SUPPORT;
        cfg_mod_ts_pcie_support_i          <= #TP `CX_DEFAULT_MOD_TS_PCIE_SUPPORT;
        cfg_mod_ts_alt_protocol_support    <= #TP `DEFAULT_AP_SUPPORT;
    end else begin 
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // Read-Only registers, but writable through DBI
        cfg_eq_bypass_highest_rate_support <= #TP (int_reg_id[1] & int_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[0]  : cfg_eq_bypass_highest_rate_support;
        cfg_no_eq_needed_support           <= #TP (int_reg_id[1] & int_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[1]  : cfg_no_eq_needed_support;
        cfg_mod_ts_pcie_support_i          <= #TP (int_reg_id[1] & int_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[8]  : cfg_mod_ts_pcie_support_i;
        cfg_mod_ts_alt_protocol_support    <= #TP (int_reg_id[1] & int_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[10] : cfg_mod_ts_alt_protocol_support;
    end
end // cap_reg_PROC


assign pl32g_reg_07 = 8'h00;                                                   // [31:24] Reserved
assign pl32g_reg_06 = 8'h00;                                                   // [23:16] Reserved
assign pl32g_reg_05 = {cfg_mod_ts_rsvd_usage_mode,cfg_mod_ts_alt_protocol_support, cfg_mod_ts_training_set_support, cfg_mod_ts_pcie_support_i};
assign pl32g_reg_04 = {6'h00, cfg_no_eq_needed_support, cfg_eq_bypass_highest_rate_support};  // [ 7: 2] Reserved
assign cfg_mod_ts_pcie_support = cfg_alt_protocol_enable ? 1'b1 : cfg_mod_ts_pcie_support_i; // if Alternate Protocols enabled, mod ts must be supported

// -----------------------------------------------------------------------------
// 32.0 GT/s Control Register
// -----------------------------------------------------------------------------
// pl32g_reg_id     - 2
// PCIE Offset      - `PL32G_PTR + 08h
// length           - 4 byte
// Cfig register    - pl32g_reg_11, pl32g_reg_10, pl32g_reg_09, pl32g_reg_08
// -----------------------------------------------------------------------------
reg        cfg_bypass_eq_disable;        // [0] Equalization bypass to highest rate Disable
reg        cfg_no_eq_needed_disable;     // [1] No Equalization Needed Disable
reg [2:0]  cfg_mod_ts_usage_mode_select; // [10:8] Modified TS Usage Mode Selected

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : ctrl_reg_PROC
    if ( !sticky_rst_n ) begin
        cfg_bypass_eq_disable        <= #TP 1'b0;
        cfg_no_eq_needed_disable     <= #TP 1'b0;
    end else begin 
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // RWS
        cfg_bypass_eq_disable        <= #TP (int_reg_id[2] & int_write_pulse[0]) ? lbc_cdm_data[0]    : cfg_bypass_eq_disable;
        cfg_no_eq_needed_disable     <= #TP (int_reg_id[2] & int_write_pulse[0]) ? lbc_cdm_data[1]    : cfg_no_eq_needed_disable;
    end
end // ctrl_reg_PROC


always @( posedge core_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_mod_ts_usage_mode_select <= #TP {1'b0, `DEFAULT_AP_ENABLE, 1'b0}; // 3'b000;
    end else begin 
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // RWS
        cfg_mod_ts_usage_mode_select <= #TP upstream_port ? 3'b000 : (int_reg_id[2] & int_write_pulse[1]) ? lbc_cdm_data[10:8] : cfg_mod_ts_usage_mode_select;
    end
end 


//wire [2:0] cfg_mod_ts_usage_mode_select_i = |cfg_mod_ts_usage_mode_select ? cfg_mod_ts_usage_mode_select : {1'b0, `DEFAULT_AP_ENABLE, 1'b0};
wire [2:0] cfg_mod_ts_usage_mode_select_i = cfg_mod_ts_usage_mode_select;

assign pl32g_reg_11 = 8'h00;                                                 // [31:24] Reserved
assign pl32g_reg_10 = 8'h00;                                                 // [23:16] Reserved
assign pl32g_reg_09 = {5'h00, cfg_mod_ts_usage_mode_select};                 // [15: 11] Reserved
assign pl32g_reg_08 = {6'h00, cfg_no_eq_needed_disable, cfg_bypass_eq_disable}; // [ 7: 2] Reserved

assign cfg_bypass_eq_enable    = ~cfg_bypass_eq_disable & cfg_eq_bypass_highest_rate_support;
assign cfg_no_eq_needed_enable = ~cfg_no_eq_needed_disable & cfg_no_eq_needed_support;
assign cfg_alt_protocol_enable = upstream_port ? cfg_mod_ts_alt_protocol_support : (cfg_mod_ts_usage_mode_select_i == 3'b010);


// -----------------------------------------------------------------------------
// 32.0 GT/s Status Register
// -----------------------------------------------------------------------------
// pl32g_reg_id     - 3
// PCIE Offset      - `PL32G_PTR + 0Ch
// length           - 4 byte
// Cfig register    - pl32g_reg_15, pl32g_reg_14, pl32g_reg_13, pl32g_reg_12
// -----------------------------------------------------------------------------
reg [3:1] cfg_ls2_g5_eq_success; // g5 Equalization Phase 3-1 Successful
reg       cfg_ls2_g5_eq_cmpl;    // g5 Equalization Complete

// ROS registers for cmpl, eq_success
// RW1CS register for eq_req.  Write 1 to clear.
always @(posedge core_clk or negedge sticky_rst_n) begin : status_reg_PROC
    if(!sticky_rst_n) begin
        cfg_ls2_g5_eq_req        <= #TP 0;
        cfg_ls2_g5_eq_success    <= #TP 0;
        cfg_ls2_g5_eq_cmpl       <= #TP 0;
    end else if (upstream_port) begin
        if (FUNC_NUM == 0) begin
            cfg_ls2_g5_eq_cmpl       <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g5_eq_enter) ? 1'b0 : smlh_ls2_g5_eq_cmpl        ? 1'b1 : cfg_ls2_g5_eq_cmpl;
            cfg_ls2_g5_eq_success[1] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g5_eq_enter) ? 1'b0 : smlh_ls2_g5_eq_success[1]  ? 1'b1 : cfg_ls2_g5_eq_success[1];
            cfg_ls2_g5_eq_success[2] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g5_eq_enter) ? 1'b0 : smlh_ls2_g5_eq_success[2]  ? 1'b1 : cfg_ls2_g5_eq_success[2];
            cfg_ls2_g5_eq_success[3] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g5_eq_enter) ? 1'b0 : smlh_ls2_g5_eq_success[3]  ? 1'b1 : cfg_ls2_g5_eq_success[3];
            cfg_ls2_g5_eq_req        <= #TP (smlh_ls2_g5_eq_enter | (int_write_pulse[0] & int_reg_id[3] & lbc_cdm_data[4])) ? 1'b0 : smlh_ls2_g5_eq_req ? 1'b1 : cfg_ls2_g5_eq_req;
        end else begin // reserved for > 0 func
            cfg_ls2_g5_eq_cmpl       <= #TP 0;
            cfg_ls2_g5_eq_success[1] <= #TP 0;
            cfg_ls2_g5_eq_success[2] <= #TP 0;
            cfg_ls2_g5_eq_success[3] <= #TP 0;
            cfg_ls2_g5_eq_req        <= #TP 0;
        end
    end else begin
        cfg_ls2_g5_eq_cmpl           <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g5_eq_enter) ? 1'b0 : smlh_ls2_g5_eq_cmpl       ? 1'b1 : cfg_ls2_g5_eq_cmpl;
        cfg_ls2_g5_eq_success[1]     <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g5_eq_enter) ? 1'b0 : smlh_ls2_g5_eq_success[1] ? 1'b1 : cfg_ls2_g5_eq_success[1];
        cfg_ls2_g5_eq_success[2]     <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g5_eq_enter) ? 1'b0 : smlh_ls2_g5_eq_success[2] ? 1'b1 : cfg_ls2_g5_eq_success[2];
        cfg_ls2_g5_eq_success[3]     <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g5_eq_enter) ? 1'b0 : smlh_ls2_g5_eq_success[3] ? 1'b1 : cfg_ls2_g5_eq_success[3];
        cfg_ls2_g5_eq_req            <= #TP (smlh_ls2_g5_eq_enter | (int_write_pulse[0] & int_reg_id[3] & lbc_cdm_data[4])) ? 1'b0 : smlh_ls2_g5_eq_req ? 1'b1 : cfg_ls2_g5_eq_req;
    end
end // status_reg_PROC

always @( posedge core_clk or negedge sticky_rst_n ) begin : status_precoding_reg_PROC
    if ( !sticky_rst_n ) begin
        cfg_tx_precode_req      <= #TP `CX_DEFAULT_TX_PRECODE_REQ;
    end else begin
        // RWS
        cfg_tx_precode_req      <= #TP (int_write_pulse[1] & int_reg_id[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[9] : cfg_tx_precode_req;
    end
end // status_precoding_reg_PROC

assign pl32g_reg_15 = 8'h00;                                                                        // [31:24] Reserved
assign pl32g_reg_14 = 8'h00;                                                                        // [23:16] Reserved
assign pl32g_reg_13 = {5'h00, smlh_noeq_needed_rcvd, cfg_tx_precode_req, smlh_tx_precoding_on};     // [15:11] Reserved
assign pl32g_reg_12 = {smlh_elbc_rcvd, smlh_mod_ts_rcvd, cfg_ls2_g5_eq_req, cfg_ls2_g5_eq_success[3:1], cfg_ls2_g5_eq_cmpl};

// -----------------------------------------------------------------------------
// Received Modified TS Data 1 Register
// -----------------------------------------------------------------------------
// pl32g_reg_id     - 4
// PCIE Offset      - `PL32G_PTR + 10h
// length           - 4 byte
// Cfig register    - pl32g_reg_19, pl32g_reg_18, pl32g_reg_17, pl32g_reg_16
// -----------------------------------------------------------------------------
// If PCI Express (Usage Mode 0) is the only one supported by a Port, this register is permitted to be hardwired to 0000 0000h.
wire [2:0]  cfg_rcvd__mod_ts_usage_mode = mod_ts_data_rcvd[2:0]; // [ 2: 0] Received Modified TS Usage Mode
wire [12:0] cfg_rcvd_mod_ts_info1 = mod_ts_data_rcvd[15:3];      // [15: 3] Received Modified TS Information 1
wire [15:0] cfg_rcvd_mod_ts_vender_id = mod_ts_data_rcvd[31:16]; // [31:16] Received Modified TS Vendor ID
assign pl32g_reg_19 = cfg_rcvd_mod_ts_vender_id[15:8];
assign pl32g_reg_18 = cfg_rcvd_mod_ts_vender_id[7:0];
assign pl32g_reg_17 = cfg_rcvd_mod_ts_info1[12:5];
assign pl32g_reg_16 = {cfg_rcvd_mod_ts_info1[4:0],cfg_rcvd__mod_ts_usage_mode};

// -----------------------------------------------------------------------------
// Received Modified TS Data 2 Register
// -----------------------------------------------------------------------------
// pl32g_reg_id     - 5
// PCIE Offset      - `PL32G_PTR + 14h
// length           - 4 byte
// Cfig register    - pl32g_reg_23, pl32g_reg_22, pl32g_reg_21, pl32g_reg_20
// -----------------------------------------------------------------------------
// If PCI Express (Usage Mode 0) is the only one supported by a Port, this register is permitted to be hardwired to 0000 0000h.
wire [23:0] cfg_rcvd_mod_ts_info2 = mod_ts_data_rcvd[55:32]; // [23: 0] Received Modified TS Information 2
wire [1:0]  cfg_rcvd_alt_protocol_nego_status = (cfg_alt_protocol_enable && mod_ts_data_rcvd[2:0] == 3'b010) ? 2'b11 : 2'b00; // [25:24] Alternate Protocol Negotation Status
assign pl32g_reg_23 = {6'h00, cfg_rcvd_alt_protocol_nego_status};
assign pl32g_reg_22 = cfg_rcvd_mod_ts_info2[23:16];
assign pl32g_reg_21 = cfg_rcvd_mod_ts_info2[15:8];
assign pl32g_reg_20 = cfg_rcvd_mod_ts_info2[7:0];

// -----------------------------------------------------------------------------
// Transmitted Modified TS Data 1 Register
// -----------------------------------------------------------------------------
// pl32g_reg_id     - 6
// PCIE Offset      - `PL32G_PTR + 18h
// length           - 4 byte
// Cfig register    - pl32g_reg_27, pl32g_reg_26, pl32g_reg_25, pl32g_reg_24
// -----------------------------------------------------------------------------
// If PCI Express (Usage Mode 0) is the only one supported by a Port, this register is permitted to be hardwired to 0000 0000h.
wire [2:0]  cfg_tx_mod_ts_usage_mode = mod_ts_data_sent[2:0];   // [ 2: 0] Transmitted Modified TS Usage Mode
wire [12:0] cfg_tx_mod_ts_info1 =      mod_ts_data_sent[15:3];  // [15: 3] Transmitted Modified TS Information 1
wire [15:0] cfg_tx_mod_ts_vender_id =  mod_ts_data_sent[31:16]; // [31:16] Transmitted Modified TS Vendor ID
assign pl32g_reg_27 = cfg_tx_mod_ts_vender_id[15:8];
assign pl32g_reg_26 = cfg_tx_mod_ts_vender_id[7:0];
assign pl32g_reg_25 = cfg_tx_mod_ts_info1[12:5];
assign pl32g_reg_24 = {cfg_tx_mod_ts_info1[4:0], cfg_tx_mod_ts_usage_mode};

// -----------------------------------------------------------------------------
// Transmitted Modified TS Data 2 Register
// -----------------------------------------------------------------------------
// pl32g_reg_id     - 7
// PCIE Offset      - `PL32G_PTR + 1Ch
// length           - 4 byte
// Cfig register    - pl32g_reg_31, pl32g_reg_30, pl32g_reg_29, pl32g_reg_28
// -----------------------------------------------------------------------------
// If PCI Express (Usage Mode 0) is the only one supported by a Port, this register is permitted to be hardwired to 0000 0000h.
wire [23:0] cfg_tx_mod_ts_info2 = mod_ts_data_sent[55:32]; // [23: 0] Received Modified TS Information 2
wire [1:0]  cfg_tx_alt_protocol_nego_status = (cfg_alt_protocol_enable && mod_ts_data_rcvd[2:0] == 3'b010) ? 2'b11 : 2'b00; // [25:24] Alternate Protocol Negotation Status
assign pl32g_reg_31 = {6'h00,cfg_tx_alt_protocol_nego_status};
assign pl32g_reg_30 = cfg_tx_mod_ts_info2[23:16];
assign pl32g_reg_29 = cfg_tx_mod_ts_info2[15:8];
assign pl32g_reg_28 = cfg_tx_mod_ts_info2[7:0];

// -----------------------------------------------------------------------------
// 32.0 GT/s Lane Equalization Control Register (Lane 3, Lane 2, Lane 1, Lane 0)
// -----------------------------------------------------------------------------
// pl32g_reg_id     - 8
// PCIE Offset      - `PL32G_PTR + 20h
// length           - 4 byte
// Cfig register    - pl32g_reg_35, pl32g_reg_34, pl32g_reg_33, pl32g_reg_32
// -----------------------------------------------------------------------------
localparam NL_20H   = (NL>=4) ? 4 : NL;
reg     [NL_20H*TX_PSET_WD-1:0]     cfg_lec_g5_pset_ltx_20h;    // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
reg     [NL_20H*TX_PSET_WD-1:0]     cfg_lec_g5_pset_rtx_20h;    // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
assign cfg_lec_g5_pset_ltx[NL_20H*TX_PSET_WD-1:0] = cfg_lec_g5_pset_ltx_20h;
assign cfg_lec_g5_pset_rtx[NL_20H*TX_PSET_WD-1:0] = cfg_lec_g5_pset_rtx_20h;

// Lane 0 Equalization Control Register
assign pl32g_reg_32 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g5_pset_ltx[1*TX_PSET_WD-1:0*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g5_pset_rtx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g5_pset_ltx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 1 Equalization Control Register
assign pl32g_reg_33 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g5_pset_ltx[2*TX_PSET_WD-1:1*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g5_pset_rtx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g5_pset_ltx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset


// Lane 2 Equalization Control Register
assign pl32g_reg_34 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g5_pset_ltx[3*TX_PSET_WD-1:2*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g5_pset_rtx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g5_pset_ltx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 3 Equalization Control Register
assign pl32g_reg_35 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g5_pset_ltx[4*TX_PSET_WD-1:3*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g5_pset_rtx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g5_pset_ltx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        // Lane 0 Presets
        cfg_lec_g5_pset_ltx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP `DEFAULT_DSP_32G_TX_PRESET0;
        // Lane 1 Presets
        cfg_lec_g5_pset_ltx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP `DEFAULT_DSP_32G_TX_PRESET1;
        // Lane 2 Presets
        cfg_lec_g5_pset_ltx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP `DEFAULT_DSP_32G_TX_PRESET2;
        // Lane 3 Presets
        cfg_lec_g5_pset_ltx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP `DEFAULT_DSP_32G_TX_PRESET3;
    end else begin
        // Lane 0 Presets
        cfg_lec_g5_pset_ltx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP (int_reg_id[8] & int_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[0*4 +: 4] : cfg_lec_g5_pset_ltx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD];
        // Lane 1 Presets
        cfg_lec_g5_pset_ltx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP (int_reg_id[8] & int_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[2*4 +: 4] : cfg_lec_g5_pset_ltx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD];
        // Lane 2 Presets
        cfg_lec_g5_pset_ltx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP (int_reg_id[8] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[4*4 +: 4] : cfg_lec_g5_pset_ltx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD];
        // Lane 3 Presets
        cfg_lec_g5_pset_ltx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP (int_reg_id[8] & int_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[6*4 +: 4] : cfg_lec_g5_pset_ltx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD];
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin 
    if (!sticky_rst_n) begin
        // Lane 0 Presets
        cfg_lec_g5_pset_rtx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP `DEFAULT_USP_32G_TX_PRESET0;
        // Lane 1 Presets
        cfg_lec_g5_pset_rtx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP `DEFAULT_USP_32G_TX_PRESET1;
        // Lane 2 Presets
        cfg_lec_g5_pset_rtx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP `DEFAULT_USP_32G_TX_PRESET2;
        // Lane 3 Presets
        cfg_lec_g5_pset_rtx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP `DEFAULT_USP_32G_TX_PRESET3;
    end else begin
        // Lane 0 Presets
        cfg_lec_g5_pset_rtx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP (int_reg_id[8] & int_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[1*4 +: 4] : cfg_lec_g5_pset_rtx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD];
        // Lane 1 Presets
        cfg_lec_g5_pset_rtx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP (int_reg_id[8] & int_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[3*4 +: 4] : cfg_lec_g5_pset_rtx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD];
        // Lane 2 Presets
        cfg_lec_g5_pset_rtx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP (int_reg_id[8] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[5*4 +: 4] : cfg_lec_g5_pset_rtx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD];
        // Lane 3 Presets
        cfg_lec_g5_pset_rtx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP (int_reg_id[8] & int_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[7*4 +: 4] : cfg_lec_g5_pset_rtx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD];
    end
end 

// -----------------------------------------------------------------------------
// 32.0 GT/s Lane Equalization Control Register (Lane 7, Lane 6, Lane 5, Lane 4)
// -----------------------------------------------------------------------------
// pl32g_reg_id     - 9
// PCIE Offset      - `PL32G_PTR + 24h
// length           - 4 byte
// Cfig register    - pl32g_reg_39, pl32g_reg_38, pl32g_reg_37, pl32g_reg_36
// -----------------------------------------------------------------------------
localparam NL_24H   = 8;
reg     [NL_24H*TX_PSET_WD-1:4*TX_PSET_WD]     cfg_lec_g5_pset_ltx_24h;    // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
reg     [NL_24H*TX_PSET_WD-1:4*TX_PSET_WD]     cfg_lec_g5_pset_rtx_24h;    // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
assign cfg_lec_g5_pset_ltx[NL_24H*TX_PSET_WD-1:4*TX_PSET_WD] = cfg_lec_g5_pset_ltx_24h;
assign cfg_lec_g5_pset_rtx[NL_24H*TX_PSET_WD-1:4*TX_PSET_WD] = cfg_lec_g5_pset_rtx_24h;

// Lane 4 Equalization Control Register
assign pl32g_reg_36 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g5_pset_ltx[5*TX_PSET_WD-1:4*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g5_pset_rtx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g5_pset_ltx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 5 Equalization Control Register
assign pl32g_reg_37 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g5_pset_ltx[6*TX_PSET_WD-1:5*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g5_pset_rtx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g5_pset_ltx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 6 Equalization Control Register
assign pl32g_reg_38 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g5_pset_ltx[7*TX_PSET_WD-1:6*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g5_pset_rtx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g5_pset_ltx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 7 Equalization Control Register
assign pl32g_reg_39 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g5_pset_ltx[8*TX_PSET_WD-1:7*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g5_pset_rtx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g5_pset_ltx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        // Lane 4 Presets
        cfg_lec_g5_pset_ltx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP `DEFAULT_DSP_32G_TX_PRESET4;
        // Lane 5 Presets
        cfg_lec_g5_pset_ltx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP `DEFAULT_DSP_32G_TX_PRESET5;
        // Lane 6 Presets
        cfg_lec_g5_pset_ltx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP `DEFAULT_DSP_32G_TX_PRESET6;
        // Lane 7 Presets
        cfg_lec_g5_pset_ltx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP `DEFAULT_DSP_32G_TX_PRESET7;
    end else begin
        // Lane 4 Presets
        cfg_lec_g5_pset_ltx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP (int_reg_id[9] & int_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[0*4 +: 4] : cfg_lec_g5_pset_ltx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD];
        // Lane 5 Presets
        cfg_lec_g5_pset_ltx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP (int_reg_id[9] & int_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[2*4 +: 4] : cfg_lec_g5_pset_ltx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD];
        // Lane 6 Presets
        cfg_lec_g5_pset_ltx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP (int_reg_id[9] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[4*4 +: 4] : cfg_lec_g5_pset_ltx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD];
        // Lane 7 Presets
        cfg_lec_g5_pset_ltx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP (int_reg_id[9] & int_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[6*4 +: 4] : cfg_lec_g5_pset_ltx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD];
    end
end 

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin 
    if (!sticky_rst_n) begin
        // Lane 4 Presets
        cfg_lec_g5_pset_rtx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP `DEFAULT_USP_32G_TX_PRESET4;
        // Lane 5 Presets
        cfg_lec_g5_pset_rtx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP `DEFAULT_USP_32G_TX_PRESET5;
        // Lane 6 Presets
        cfg_lec_g5_pset_rtx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP `DEFAULT_USP_32G_TX_PRESET6;
        // Lane 7 Presets
        cfg_lec_g5_pset_rtx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP `DEFAULT_USP_32G_TX_PRESET7;
    end else begin
        // Lane 4 Presets
        cfg_lec_g5_pset_rtx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP (int_reg_id[9] & int_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[1*4 +: 4] : cfg_lec_g5_pset_rtx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD];
        // Lane 5 Presets
        cfg_lec_g5_pset_rtx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP (int_reg_id[9] & int_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[3*4 +: 4] : cfg_lec_g5_pset_rtx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD];
        // Lane 6 Presets
        cfg_lec_g5_pset_rtx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP (int_reg_id[9] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[5*4 +: 4] : cfg_lec_g5_pset_rtx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD];
        // Lane 7 Presets
        cfg_lec_g5_pset_rtx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP (int_reg_id[9] & int_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[7*4 +: 4] : cfg_lec_g5_pset_rtx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD];
    end
end 


// =============================================================================
// Register Read Operation
// =============================================================================

// reg_id[6:4] is TBD, read data is undefined. But address space/offset for reg_id[6:4] is taken for Gen5 Extended Capability Register
always @(*) begin : read_data_PROC
    unique case (1'b1)
        int_reg_id[0]  : pl32g_reg_data = {pl32g_reg_03, pl32g_reg_02, pl32g_reg_01, pl32g_reg_00};
        int_reg_id[1]  : pl32g_reg_data = {pl32g_reg_07, pl32g_reg_06, pl32g_reg_05, pl32g_reg_04};
        int_reg_id[2]  : pl32g_reg_data = {pl32g_reg_11, pl32g_reg_10, pl32g_reg_09, pl32g_reg_08};
        int_reg_id[3]  : pl32g_reg_data = {pl32g_reg_15, pl32g_reg_14, pl32g_reg_13, pl32g_reg_12};
        int_reg_id[4]  : pl32g_reg_data = {pl32g_reg_19, pl32g_reg_18, pl32g_reg_17, pl32g_reg_16};
        int_reg_id[5]  : pl32g_reg_data = {pl32g_reg_23, pl32g_reg_22, pl32g_reg_21, pl32g_reg_20};
        int_reg_id[6]  : pl32g_reg_data = {pl32g_reg_27, pl32g_reg_26, pl32g_reg_25, pl32g_reg_24};
        int_reg_id[7]  : pl32g_reg_data = {pl32g_reg_31, pl32g_reg_30, pl32g_reg_29, pl32g_reg_28};
        int_reg_id[8]  : pl32g_reg_data = {pl32g_reg_35, pl32g_reg_34, pl32g_reg_33, pl32g_reg_32};
        int_reg_id[9]  : pl32g_reg_data = {pl32g_reg_39, pl32g_reg_38, pl32g_reg_37, pl32g_reg_36};
        default        : pl32g_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end // read_data_PROC

endmodule // cdm_pl32g_reg
