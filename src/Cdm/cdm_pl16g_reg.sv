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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_pl16g_reg.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Physical Layer 16.0 GT/s Extended Capability (PL16G)
// --- registers. This module is instantiated once and shared across all functions.
// --- A Write to the one of the PL16G registers for a given function, updates
// --- that register across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_pl16g_reg (
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    cdm_clk_g,
    lbc_cdm_data,
    lbc_cdm_dbi,
    pl16g_write_pulse,
    pl16g_reg_id,
    upstream_port,
    cfg_pcie_crosslink_supported,
    dbi_ro_wr_en,
    device_type,
    smlh_ltssm_in_detectquiet,
    smlh_ls2_g4_eq_req,
    smlh_ls2_g4_eq_success,
    smlh_ls2_g4_eq_cmpl,
    smlh_ls2_g4_eq_enter,
    smlh_lec_g4_pset_ltx,
    rmlh_deskew_ctlskp_err,
    cxl_rcrb_enable,
// -- outputs --
    pl16g_reg_data,
    cfg_ls2_g4_eq_req,
    cfg_lec_g4_pset_ltx,
    cfg_lec_g4_pset_rtx
);

parameter INST          = 0;                            // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM      = 0;                            // uniquifying parameter per function
parameter TP            = `TP;                          // Clock to Q delay (simulator insurance)
parameter NL            = `CX_NL;                       // Number of Lanes

localparam NPL16G       = `PL16G_SIZE>>2;               // Number of registers in Physical Layer 16.0 GT/s Extended Capability Structure
localparam TX_PSET_WD   = 4;                            // Width of Transmitter Equalization Presets
parameter RCRB          = 0;                            // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space

// -------------- Inputs ---------------
input                           core_clk;               // Core Clock
input                           non_sticky_rst_n;       // Non-Sticky Reset
input                           sticky_rst_n;           // Sticky Reset
input                           cdm_clk_g;              // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
input   [31:0]                  lbc_cdm_data;           // Write Data
input                           lbc_cdm_dbi;            // DBI Access
input   [3:0]                   pl16g_write_pulse;      // Write Byte Enables
input   [NPL16G-1:0]            pl16g_reg_id;           // PL16G Register ID
input                           upstream_port;          // Device is Upstream Port (EP/SW_UP)
input                           cfg_pcie_crosslink_supported; // Crosslink Supported bit (bit-8 of Link Capabilities 2 Register (Offset 2Ch))
input                           dbi_ro_wr_en;
input   [3:0]                   device_type;             // used to indicate if device is RP

input                           smlh_ltssm_in_detectquiet;
input                           smlh_ls2_g4_eq_req;             // g4 Equalization Request
input  [3:1]                    smlh_ls2_g4_eq_success;         // g4 Equalization Successful {Phase 3, Phase 2, Phase 1}
input                           smlh_ls2_g4_eq_cmpl;            // g4 Equalization Complete
input                           smlh_ls2_g4_eq_enter;           // g4 Equalization Entered
input   [NL*5-1:0]              rmlh_deskew_ctlskp_err;         // CS-SKP-OS error [0]data parity[1]1st retimer[2]2nd retimer[3]margin crc[4]margin parity
input   [NL*TX_PSET_WD-1:0]     smlh_lec_g4_pset_ltx;     // Latest Transmitter Preset requested from Upstream Component (Not applicable to RC/SW_DW)
input                           cxl_rcrb_enable;

// -------------- Outputs --------------
output  [31:0]                  pl16g_reg_data;         // PL16G Register Read Data
output                          cfg_ls2_g4_eq_req;      // Gen4 Request Equalization
output  [NL*TX_PSET_WD-1:0]     cfg_lec_g4_pset_ltx;    // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
output  [NL*TX_PSET_WD-1:0]     cfg_lec_g4_pset_rtx;    // Downstream Component Transmitter Preset

// -------------- Internal Signals --------------
wire                            upstream_component;     // Upstream Component ; Downstream Port ; Downstream Lanes
wire                            downstream_component;   // Downstream Component ; Upstream Port ; Upstream Lanes
wire                            dbi_ro_wr_en;           // DBI Read Only Write Enable
wire                            int_lbc_cdm_dbi;        // Internal DBI Access
reg     [31:0]                  pl16g_reg_data;         // PL16G Register Read Data

wire    [7:0]   pl16g_reg_03, pl16g_reg_02, pl16g_reg_01, pl16g_reg_00;
wire    [7:0]   pl16g_reg_07, pl16g_reg_06, pl16g_reg_05, pl16g_reg_04;
wire    [7:0]   pl16g_reg_11, pl16g_reg_10, pl16g_reg_09, pl16g_reg_08;
wire    [7:0]   pl16g_reg_15, pl16g_reg_14, pl16g_reg_13, pl16g_reg_12;
wire    [7:0]   pl16g_reg_19, pl16g_reg_18, pl16g_reg_17, pl16g_reg_16;
wire    [7:0]   pl16g_reg_23, pl16g_reg_22, pl16g_reg_21, pl16g_reg_20;
wire    [7:0]   pl16g_reg_27, pl16g_reg_26, pl16g_reg_25, pl16g_reg_24;
wire    [7:0]   pl16g_reg_31, pl16g_reg_30, pl16g_reg_29, pl16g_reg_28;
wire    [7:0]   pl16g_reg_35, pl16g_reg_34, pl16g_reg_33, pl16g_reg_32;
wire    [7:0]   pl16g_reg_39, pl16g_reg_38, pl16g_reg_37, pl16g_reg_36;

wire            rc_device;
wire            pcie_sw_down;

// Determine when Root Port is implemented - relevant for DM product in RP
// mode.
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);

assign upstream_component   = !upstream_port;
assign downstream_component =  upstream_port;

assign int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;

// -----------------------------------------------------------------------------
// Physical Layer 16.0 GT/s Extended Capability Header Register
// -----------------------------------------------------------------------------
// pl16g_reg_id     - 0
// PCIE Offset      - `PL16G_PTR
// length           - 4 byte
// Cfig register    - pl16g_reg_03, pl16g_reg_02, pl16g_reg_01, pl16g_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_pl16g_id;          // PL16G Capability ID
reg [3:0]   cfg_pl16g_ver;         // PL16G Capability Version
reg [11:0]  cfg_pl16g_next_ptr;    // PL16G Next Capability Offset
reg         pl16g_next_ptr_wr_updated;    // Asserted when PL16G Capability header has been changed by a DBI write


// Next Capability Pointer. Capabilities such as SRIOV should not
// be visible to a DM product in Root Port mode; hence, when either rc_device (or pcie_sw_down in a SW product)
// is true then the next pointer is in a smaller linked list.

assign {pl16g_reg_01, pl16g_reg_00}       = cfg_pl16g_id;
assign pl16g_reg_02[3:0]                  = cfg_pl16g_ver;
assign {pl16g_reg_03, pl16g_reg_02[7:4]}  = cfg_pl16g_next_ptr;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : pl16g_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_pl16g_id[15:0]       <= #TP `PCIE_PL16G_ECAP_ID;      // Capability ID = 0x0026
        cfg_pl16g_ver[3:0]       <= #TP `PCIE_PL16G_ECAP_VER;     // Capability version = 0x1
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_pl16g_id[7:0]        <= #TP (pl16g_reg_id[0] & pl16g_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_pl16g_id[7:0];
        cfg_pl16g_id[15:8]       <= #TP (pl16g_reg_id[0] & pl16g_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_pl16g_id[15:8];
        cfg_pl16g_ver[3:0]       <= #TP (pl16g_reg_id[0] & pl16g_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_pl16g_ver[3:0];
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : pl16g_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_pl16g_next_ptr[11:0] <= #TP `PL16G_NEXT_PTR;
    end else if (pl16g_reg_id[0] && int_lbc_cdm_dbi) begin
        // Read-Only registers, but writable through DBI
        cfg_pl16g_next_ptr[3:0]  <= #TP pl16g_write_pulse[2] ? lbc_cdm_data[23:20] : cfg_pl16g_next_ptr[3:0];
        cfg_pl16g_next_ptr[11:4] <= #TP pl16g_write_pulse[3] ? lbc_cdm_data[31:24] : cfg_pl16g_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !pl16g_next_ptr_wr_updated) begin
        cfg_pl16g_next_ptr[11:0] <= #TP `DM_RP_PL16G_NEXT_PTR;
    end else if (!pl16g_next_ptr_wr_updated) begin
        cfg_pl16g_next_ptr[11:0] <= #TP (cxl_rcrb_enable) ? `RCRB_PL16G_NEXT_PTR :  `PL16G_NEXT_PTR;
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : pl16g_next_ptr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        pl16g_next_ptr_wr_updated <= #TP 1'b0;
    end else if (pl16g_reg_id[0] && int_lbc_cdm_dbi && |pl16g_write_pulse[3:2]) begin
        pl16g_next_ptr_wr_updated <= #TP 1'b1;
    end
end

// -----------------------------------------------------------------------------
// 16.0 GT/s Capabilities Register
// -----------------------------------------------------------------------------
// pl16g_reg_id     - 1
// PCIE Offset      - `PL16G_PTR + 04h
// length           - 4 byte
// Cfig register    - pl16g_reg_07, pl16g_reg_06, pl16g_reg_05, pl16g_reg_04
// -----------------------------------------------------------------------------
assign pl16g_reg_07 = 8'h00;  // [31:24] Reserved
assign pl16g_reg_06 = 8'h00;  // [23:16] Reserved
assign pl16g_reg_05 = 8'h00;  // [15: 8] Reserved
assign pl16g_reg_04 = 8'h00;  // [ 7: 0] Reserved

// -----------------------------------------------------------------------------
// 16.0 GT/s Control Register
// -----------------------------------------------------------------------------
// pl16g_reg_id     - 2
// PCIE Offset      - `PL16G_PTR + 08h
// length           - 4 byte
// Cfig register    - pl16g_reg_11, pl16g_reg_10, pl16g_reg_09, pl16g_reg_08
// -----------------------------------------------------------------------------
assign pl16g_reg_11 = 8'h00;  // [31:24] Reserved
assign pl16g_reg_10 = 8'h00;  // [23:16] Reserved
assign pl16g_reg_09 = 8'h00;  // [15: 8] Reserved
assign pl16g_reg_08 = 8'h00;  // [ 7: 0] Reserved

// -----------------------------------------------------------------------------
// 16.0 GT/s Status Register
// -----------------------------------------------------------------------------
// pl16g_reg_id     - 3
// PCIE Offset      - `PL16G_PTR + 0Ch
// length           - 4 byte
// Cfig register    - pl16g_reg_15, pl16g_reg_14, pl16g_reg_13, pl16g_reg_12
// -----------------------------------------------------------------------------
reg       cfg_ls2_g4_eq_req;
reg [3:1] cfg_ls2_g4_eq_success;
reg       cfg_ls2_g4_eq_cmpl;

assign pl16g_reg_15 = 8'h00;  // [31:24] Reserved
assign pl16g_reg_14 = 8'h00;  // [23:16] Reserved
assign pl16g_reg_13 = 8'h00;  // [15: 8] Reserved
assign pl16g_reg_12 = { 3'b000,                    // [7:5] Reserved
                        cfg_ls2_g4_eq_req,         // [4]   g4 Link Equalization Request
                        cfg_ls2_g4_eq_success[3],  // [3]   g4 Equalization Phase 3 Successful
                        cfg_ls2_g4_eq_success[2],  // [2]   g4 Equalization Phase 2 Successful
                        cfg_ls2_g4_eq_success[1],  // [1]   g4 Equalization Phase 1 Successful
                        cfg_ls2_g4_eq_cmpl};       // [0]   g4 Equalization Complete

// RW1C registers.  Write 1 to clear.
always @(posedge core_clk or negedge sticky_rst_n)
begin
    if(!sticky_rst_n) begin
        cfg_ls2_g4_eq_req        <= #TP 0;
        cfg_ls2_g4_eq_success    <= #TP 0;
        cfg_ls2_g4_eq_cmpl       <= #TP 0;
    end else if (upstream_port) begin
        if (FUNC_NUM == 0) begin
            cfg_ls2_g4_eq_cmpl       <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g4_eq_enter) ? 1'b0 : smlh_ls2_g4_eq_cmpl        ? 1'b1 : cfg_ls2_g4_eq_cmpl;
            cfg_ls2_g4_eq_success[1] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g4_eq_enter) ? 1'b0 : smlh_ls2_g4_eq_success[1]  ? 1'b1 : cfg_ls2_g4_eq_success[1];
            cfg_ls2_g4_eq_success[2] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g4_eq_enter) ? 1'b0 : smlh_ls2_g4_eq_success[2]  ? 1'b1 : cfg_ls2_g4_eq_success[2];
            cfg_ls2_g4_eq_success[3] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g4_eq_enter) ? 1'b0 : smlh_ls2_g4_eq_success[3]  ? 1'b1 : cfg_ls2_g4_eq_success[3];
            cfg_ls2_g4_eq_req        <= #TP (smlh_ls2_g4_eq_enter | (pl16g_write_pulse[0] & pl16g_reg_id[3] & lbc_cdm_data[4])) ? 1'b0 : smlh_ls2_g4_eq_req ? 1'b1 : cfg_ls2_g4_eq_req;
        end else begin
            cfg_ls2_g4_eq_cmpl       <= #TP 0;
            cfg_ls2_g4_eq_success[1] <= #TP 0;
            cfg_ls2_g4_eq_success[2] <= #TP 0;
            cfg_ls2_g4_eq_success[3] <= #TP 0;
            cfg_ls2_g4_eq_req        <= #TP 0;
        end
    end else begin
        cfg_ls2_g4_eq_cmpl       <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g4_eq_enter) ? 1'b0 : smlh_ls2_g4_eq_cmpl       ? 1'b1 : cfg_ls2_g4_eq_cmpl;
        cfg_ls2_g4_eq_success[1] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g4_eq_enter) ? 1'b0 : smlh_ls2_g4_eq_success[1] ? 1'b1 : cfg_ls2_g4_eq_success[1];
        cfg_ls2_g4_eq_success[2] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g4_eq_enter) ? 1'b0 : smlh_ls2_g4_eq_success[2] ? 1'b1 : cfg_ls2_g4_eq_success[2];
        cfg_ls2_g4_eq_success[3] <= #TP (smlh_ltssm_in_detectquiet | smlh_ls2_g4_eq_enter) ? 1'b0 : smlh_ls2_g4_eq_success[3] ? 1'b1 : cfg_ls2_g4_eq_success[3];
        cfg_ls2_g4_eq_req        <= #TP (smlh_ls2_g4_eq_enter | (pl16g_write_pulse[0] & pl16g_reg_id[3] & lbc_cdm_data[4])) ? 1'b0 : smlh_ls2_g4_eq_req ? 1'b1 : cfg_ls2_g4_eq_req;
    end
end

// -----------------------------------------------------------------------------
// 16.0 GT/s Local Data Parity Mismatch Status Register
// -----------------------------------------------------------------------------
// pl16g_reg_id     - 4
// PCIE Offset      - `PL16G_PTR + 10h
// length           - 4 byte
// Cfig register    - pl16g_reg_19, pl16g_reg_18, pl16g_reg_17, pl16g_reg_16
// -----------------------------------------------------------------------------
reg [NL-1:0] cfg_local_dpms;

assign {pl16g_reg_19, pl16g_reg_18, pl16g_reg_17, pl16g_reg_16} =  { {(32-NL){1'b0}},  // [31-NL:NL] Reserved
                                                                     cfg_local_dpms};  // [NL-1:]    Local Data Parity Mismatch Status

always @(posedge core_clk or negedge sticky_rst_n)
begin : local_dpm_status_PROC
    if (!sticky_rst_n)
        cfg_local_dpms        <= #TP 0;
    else begin
        // Lane 0 Error Status (RW1C)
        cfg_local_dpms[0]     <= #TP (rmlh_deskew_ctlskp_err[5*0])                           ? 1'b1 :
                                     (pl16g_reg_id[4] & pl16g_write_pulse[0] & lbc_cdm_data[0])  ? 1'b0 : cfg_local_dpms[0];

        // Lane 1 Error Status (RW1C)
        cfg_local_dpms[1]     <= #TP (rmlh_deskew_ctlskp_err[5*1])                           ? 1'b1 :
                                     (pl16g_reg_id[4] & pl16g_write_pulse[0] & lbc_cdm_data[1])  ? 1'b0 : cfg_local_dpms[1];
        // Lane 2 Error Status (RW1C)
        cfg_local_dpms[2]     <= #TP (rmlh_deskew_ctlskp_err[5*2])                           ? 1'b1 :
                                     (pl16g_reg_id[4] & pl16g_write_pulse[0] & lbc_cdm_data[2])  ? 1'b0 : cfg_local_dpms[2];

        // Lane 3 Error Status (RW1C)
        cfg_local_dpms[3]     <= #TP (rmlh_deskew_ctlskp_err[5*3])                           ? 1'b1 :
                                     (pl16g_reg_id[4] & pl16g_write_pulse[0] & lbc_cdm_data[3])  ? 1'b0 : cfg_local_dpms[3];
        // Lane 4 Error Status (RW1C)
        cfg_local_dpms[4]     <= #TP (rmlh_deskew_ctlskp_err[5*4])                           ? 1'b1 :
                                     (pl16g_reg_id[4] & pl16g_write_pulse[0] & lbc_cdm_data[4])  ? 1'b0 : cfg_local_dpms[4];

        // Lane 5 Error Status (RW1C)
        cfg_local_dpms[5]     <= #TP (rmlh_deskew_ctlskp_err[5*5])                           ? 1'b1 :
                                     (pl16g_reg_id[4] & pl16g_write_pulse[0] & lbc_cdm_data[5])  ? 1'b0 : cfg_local_dpms[5];

        // Lane 6 Error Status (RW1C)
        cfg_local_dpms[6]     <= #TP (rmlh_deskew_ctlskp_err[5*6])                           ? 1'b1 :
                                     (pl16g_reg_id[4] & pl16g_write_pulse[0] & lbc_cdm_data[6])  ? 1'b0 : cfg_local_dpms[6];

        // Lane 7 Error Status (RW1C)
        cfg_local_dpms[7]     <= #TP (rmlh_deskew_ctlskp_err[5*7])                           ? 1'b1 :
                                     (pl16g_reg_id[4] & pl16g_write_pulse[0] & lbc_cdm_data[7])  ? 1'b0 : cfg_local_dpms[7];

    end
end


// -----------------------------------------------------------------------------
// 16.0 GT/s First Retimer Data Parity Mismatch Status Register
// -----------------------------------------------------------------------------
// pl16g_reg_id     - 5
// PCIE Offset      - `PL16G_PTR + 14h
// length           - 4 byte
// Cfig register    - pl16g_reg_23, pl16g_reg_22, pl16g_reg_21, pl16g_reg_20
// -----------------------------------------------------------------------------
reg [NL-1:0] cfg_1strt_dpms;

assign {pl16g_reg_23, pl16g_reg_22, pl16g_reg_21, pl16g_reg_20} =  { {(32-NL){1'b0}},  // [31-NL:NL] Reserved
                                                                     cfg_1strt_dpms};  // [NL-1:]    First Retimer Data Parity Mismatch Status

always @(posedge core_clk or negedge sticky_rst_n)
begin : first_ret_dpm_status_PROC
    if (!sticky_rst_n)
        cfg_1strt_dpms        <= #TP 0;
    else begin
        // Lane 0 Error Status (RW1C)
        cfg_1strt_dpms[0]     <= #TP (rmlh_deskew_ctlskp_err[5*0+1])                         ? 1'b1 :
                                     (pl16g_reg_id[5] & pl16g_write_pulse[0] & lbc_cdm_data[0])  ? 1'b0 : cfg_1strt_dpms[0];

        // Lane 1 Error Status (RW1C)
        cfg_1strt_dpms[1]     <= #TP (rmlh_deskew_ctlskp_err[5*1+1])                         ? 1'b1 :
                                     (pl16g_reg_id[5] & pl16g_write_pulse[0] & lbc_cdm_data[1])  ? 1'b0 : cfg_1strt_dpms[1];
        // Lane 2 Error Status (RW1C)
        cfg_1strt_dpms[2]     <= #TP (rmlh_deskew_ctlskp_err[5*2+1])                         ? 1'b1 :
                                     (pl16g_reg_id[5] & pl16g_write_pulse[0] & lbc_cdm_data[2])  ? 1'b0 : cfg_1strt_dpms[2];

        // Lane 3 Error Status (RW1C)
        cfg_1strt_dpms[3]     <= #TP (rmlh_deskew_ctlskp_err[5*3+1])                         ? 1'b1 :
                                     (pl16g_reg_id[5] & pl16g_write_pulse[0] & lbc_cdm_data[3])  ? 1'b0 : cfg_1strt_dpms[3];
        // Lane 4 Error Status (RW1C)
        cfg_1strt_dpms[4]     <= #TP (rmlh_deskew_ctlskp_err[5*4+1])                         ? 1'b1 :
                                     (pl16g_reg_id[5] & pl16g_write_pulse[0] & lbc_cdm_data[4])  ? 1'b0 : cfg_1strt_dpms[4];

        // Lane 5 Error Status (RW1C)
        cfg_1strt_dpms[5]     <= #TP (rmlh_deskew_ctlskp_err[5*5+1])                         ? 1'b1 :
                                     (pl16g_reg_id[5] & pl16g_write_pulse[0] & lbc_cdm_data[5])  ? 1'b0 : cfg_1strt_dpms[5];

        // Lane 6 Error Status (RW1C)
        cfg_1strt_dpms[6]     <= #TP (rmlh_deskew_ctlskp_err[5*6+1])                         ? 1'b1 :
                                     (pl16g_reg_id[5] & pl16g_write_pulse[0] & lbc_cdm_data[6])  ? 1'b0 : cfg_1strt_dpms[6];

        // Lane 7 Error Status (RW1C)
        cfg_1strt_dpms[7]     <= #TP (rmlh_deskew_ctlskp_err[5*7+1])                         ? 1'b1 :
                                     (pl16g_reg_id[5] & pl16g_write_pulse[0] & lbc_cdm_data[7])  ? 1'b0 : cfg_1strt_dpms[7];

    end
end

// -----------------------------------------------------------------------------
// 16.0 GT/s Two Retimer Data Parity Mismatch Status Register
// -----------------------------------------------------------------------------
// pl16g_reg_id     - 6
// PCIE Offset      - `PL16G_PTR + 18h
// length           - 4 byte
// Cfig register    - pl16g_reg_27, pl16g_reg_26, pl16g_reg_25, pl16g_reg_24
// -----------------------------------------------------------------------------
reg [NL-1:0] cfg_2ndrt_dpms;

assign {pl16g_reg_27, pl16g_reg_26, pl16g_reg_25, pl16g_reg_24} =  { {(32-NL){1'b0}},  // [31-NL:NL] Reserved
                                                                     cfg_2ndrt_dpms};  // [NL-1:]    First Retimer Data Parity Mismatch Status

always @(posedge core_clk or negedge sticky_rst_n)
begin : second_ret_dpm_status_PROC
    if (!sticky_rst_n)
        cfg_2ndrt_dpms        <= #TP 0;
    else begin
        // Lane 0 Error Status (RW1C)
        cfg_2ndrt_dpms[0]     <= #TP (rmlh_deskew_ctlskp_err[5*0+2])                         ? 1'b1 :
                                     (pl16g_reg_id[6] & pl16g_write_pulse[0] & lbc_cdm_data[0])  ? 1'b0 : cfg_2ndrt_dpms[0];

        // Lane 1 Error Status (RW1C)
        cfg_2ndrt_dpms[1]     <= #TP (rmlh_deskew_ctlskp_err[5*1+2])                         ? 1'b1 :
                                     (pl16g_reg_id[6] & pl16g_write_pulse[0] & lbc_cdm_data[1])  ? 1'b0 : cfg_2ndrt_dpms[1];
        // Lane 2 Error Status (RW1C)
        cfg_2ndrt_dpms[2]     <= #TP (rmlh_deskew_ctlskp_err[5*2+2])                         ? 1'b1 :
                                     (pl16g_reg_id[6] & pl16g_write_pulse[0] & lbc_cdm_data[2])  ? 1'b0 : cfg_2ndrt_dpms[2];

        // Lane 3 Error Status (RW1C)
        cfg_2ndrt_dpms[3]     <= #TP (rmlh_deskew_ctlskp_err[5*3+2])                         ? 1'b1 :
                                     (pl16g_reg_id[6] & pl16g_write_pulse[0] & lbc_cdm_data[3])  ? 1'b0 : cfg_2ndrt_dpms[3];
        // Lane 4 Error Status (RW1C)
        cfg_2ndrt_dpms[4]     <= #TP (rmlh_deskew_ctlskp_err[5*4+2])                         ? 1'b1 :
                                     (pl16g_reg_id[6] & pl16g_write_pulse[0] & lbc_cdm_data[4])  ? 1'b0 : cfg_2ndrt_dpms[4];

        // Lane 5 Error Status (RW1C)
        cfg_2ndrt_dpms[5]     <= #TP (rmlh_deskew_ctlskp_err[5*5+2])                         ? 1'b1 :
                                     (pl16g_reg_id[6] & pl16g_write_pulse[0] & lbc_cdm_data[5])  ? 1'b0 : cfg_2ndrt_dpms[5];

        // Lane 6 Error Status (RW1C)
        cfg_2ndrt_dpms[6]     <= #TP (rmlh_deskew_ctlskp_err[5*6+2])                         ? 1'b1 :
                                     (pl16g_reg_id[6] & pl16g_write_pulse[0] & lbc_cdm_data[6])  ? 1'b0 : cfg_2ndrt_dpms[6];

        // Lane 7 Error Status (RW1C)
        cfg_2ndrt_dpms[7]     <= #TP (rmlh_deskew_ctlskp_err[5*7+2])                         ? 1'b1 :
                                     (pl16g_reg_id[6] & pl16g_write_pulse[0] & lbc_cdm_data[7])  ? 1'b0 : cfg_2ndrt_dpms[7];

    end
end

// -----------------------------------------------------------------------------
// 16.0 GT/s Reserved Register
// -----------------------------------------------------------------------------
// pl16g_reg_id     - 7
// PCIE Offset      - `PL16G_PTR + 1Ch
// length           - 4 byte
// Cfig register    - pl16g_reg_31, pl16g_reg_30, pl16g_reg_29, pl16g_reg_28
// -----------------------------------------------------------------------------
assign pl16g_reg_31 = 8'h00;  // [31:24] Reserved
assign pl16g_reg_30 = 8'h00;  // [23:16] Reserved
assign pl16g_reg_29 = 8'h00;  // [15: 8] Reserved
assign pl16g_reg_28 = 8'h00;  // [ 7: 0] Reserved

// -----------------------------------------------------------------------------
// 16.0 GT/s Lane Equalization Control Register (Lane 3, Lane 2, Lane 1, Lane 0)
// -----------------------------------------------------------------------------
// pl16g_reg_id     - 8
// PCIE Offset      - `PL16G_PTR + 20h
// length           - 4 byte
// Cfig register    - pl16g_reg_35, pl16g_reg_34, pl16g_reg_33, pl16g_reg_32
// -----------------------------------------------------------------------------
localparam NL_20H   = (NL>=4) ? 4 : NL;
reg     [NL_20H*TX_PSET_WD-1:0]     cfg_lec_g4_pset_ltx_20h;    // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
reg     [NL_20H*TX_PSET_WD-1:0]     cfg_lec_g4_pset_rtx_20h;    // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
assign cfg_lec_g4_pset_ltx[NL_20H*TX_PSET_WD-1:0] = cfg_lec_g4_pset_ltx_20h;
assign cfg_lec_g4_pset_rtx[NL_20H*TX_PSET_WD-1:0] = cfg_lec_g4_pset_rtx_20h;

// Lane 0 Equalization Control Register
assign pl16g_reg_32 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g4_pset_ltx[1*TX_PSET_WD-1:0*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g4_pset_rtx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g4_pset_ltx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 1 Equalization Control Register
assign pl16g_reg_33 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g4_pset_ltx[2*TX_PSET_WD-1:1*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g4_pset_rtx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g4_pset_ltx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset


// Lane 2 Equalization Control Register
assign pl16g_reg_34 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g4_pset_ltx[3*TX_PSET_WD-1:2*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g4_pset_rtx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g4_pset_ltx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 3 Equalization Control Register
assign pl16g_reg_35 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g4_pset_ltx[4*TX_PSET_WD-1:3*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g4_pset_rtx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g4_pset_ltx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
    if (!sticky_rst_n) begin
        // Lane 0 Presets
        cfg_lec_g4_pset_ltx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP `DEFAULT_DSP_16G_TX_PRESET0;
        // Lane 1 Presets
        cfg_lec_g4_pset_ltx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP `DEFAULT_DSP_16G_TX_PRESET1;
        // Lane 2 Presets
        cfg_lec_g4_pset_ltx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP `DEFAULT_DSP_16G_TX_PRESET2;
        // Lane 3 Presets
        cfg_lec_g4_pset_ltx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP `DEFAULT_DSP_16G_TX_PRESET3;
    end else begin
        // Lane 0 Presets
        cfg_lec_g4_pset_ltx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP (pl16g_reg_id[8] & pl16g_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[0*4 +: 4] : cfg_lec_g4_pset_ltx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD];
        // Lane 1 Presets
        cfg_lec_g4_pset_ltx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP (pl16g_reg_id[8] & pl16g_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[2*4 +: 4] : cfg_lec_g4_pset_ltx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD];
        // Lane 2 Presets
        cfg_lec_g4_pset_ltx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP (pl16g_reg_id[8] & pl16g_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[4*4 +: 4] : cfg_lec_g4_pset_ltx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD];
        // Lane 3 Presets
        cfg_lec_g4_pset_ltx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP (pl16g_reg_id[8] & pl16g_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[6*4 +: 4] : cfg_lec_g4_pset_ltx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD];
    end
end
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : lane_g4_eq_ctrl_reg0_PROC
    if (!sticky_rst_n) begin
        // Lane 0 Presets
        cfg_lec_g4_pset_rtx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP `DEFAULT_USP_16G_TX_PRESET0;
        // Lane 1 Presets
        cfg_lec_g4_pset_rtx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP `DEFAULT_USP_16G_TX_PRESET1;
        // Lane 2 Presets
        cfg_lec_g4_pset_rtx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP `DEFAULT_USP_16G_TX_PRESET2;
        // Lane 3 Presets
        cfg_lec_g4_pset_rtx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP `DEFAULT_USP_16G_TX_PRESET3;
    end else begin
        // Lane 0 Presets
        cfg_lec_g4_pset_rtx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD]    <= #TP (pl16g_reg_id[8] & pl16g_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[1*4 +: 4] : cfg_lec_g4_pset_rtx_20h[1*TX_PSET_WD-1:0*TX_PSET_WD];
        // Lane 1 Presets
        cfg_lec_g4_pset_rtx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD]    <= #TP (pl16g_reg_id[8] & pl16g_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[3*4 +: 4] : cfg_lec_g4_pset_rtx_20h[2*TX_PSET_WD-1:1*TX_PSET_WD];
        // Lane 2 Presets
        cfg_lec_g4_pset_rtx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD]    <= #TP (pl16g_reg_id[8] & pl16g_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[5*4 +: 4] : cfg_lec_g4_pset_rtx_20h[3*TX_PSET_WD-1:2*TX_PSET_WD];
        // Lane 3 Presets
        cfg_lec_g4_pset_rtx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD]    <= #TP (pl16g_reg_id[8] & pl16g_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[7*4 +: 4] : cfg_lec_g4_pset_rtx_20h[4*TX_PSET_WD-1:3*TX_PSET_WD];
    end
end

// -----------------------------------------------------------------------------
// 16.0 GT/s Lane Equalization Control Register (Lane 7, Lane 6, Lane 5, Lane 4)
// -----------------------------------------------------------------------------
// pl16g_reg_id     - 9
// PCIE Offset      - `PL16G_PTR + 24h
// length           - 4 byte
// Cfig register    - pl16g_reg_39, pl16g_reg_38, pl16g_reg_37, pl16g_reg_36
// -----------------------------------------------------------------------------
localparam NL_24H   = 8;
reg     [NL_24H*TX_PSET_WD-1:4*TX_PSET_WD]     cfg_lec_g4_pset_ltx_24h;    // Upstream Component Transmitter Preset (Not applicable to EP/SW_UP)
reg     [NL_24H*TX_PSET_WD-1:4*TX_PSET_WD]     cfg_lec_g4_pset_rtx_24h;    // Downstream Component Transmitter Preset (Not applicable to EP/SW_UP)
assign cfg_lec_g4_pset_ltx[NL_24H*TX_PSET_WD-1:4*TX_PSET_WD] = cfg_lec_g4_pset_ltx_24h;
assign cfg_lec_g4_pset_rtx[NL_24H*TX_PSET_WD-1:4*TX_PSET_WD] = cfg_lec_g4_pset_rtx_24h;

// Lane 4 Equalization Control Register
assign pl16g_reg_36 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g4_pset_ltx[5*TX_PSET_WD-1:4*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g4_pset_rtx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g4_pset_ltx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 5 Equalization Control Register
assign pl16g_reg_37 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g4_pset_ltx[6*TX_PSET_WD-1:5*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g4_pset_rtx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g4_pset_ltx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 6 Equalization Control Register
assign pl16g_reg_38 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g4_pset_ltx[7*TX_PSET_WD-1:6*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g4_pset_rtx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g4_pset_ltx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

// Lane 7 Equalization Control Register
assign pl16g_reg_39 = (upstream_port && !cfg_pcie_crosslink_supported) ?         // Upstream Port && !crosslink_supported (Read Only)
                      {smlh_lec_g4_pset_ltx[8*TX_PSET_WD-1:7*TX_PSET_WD]         // [7:4]  Upstream Port Transmitter Preset
                      ,4'h0} :
                      {cfg_lec_g4_pset_rtx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD]      // [7:4]  Upstream Port Transmitter Preset
                      ,cfg_lec_g4_pset_ltx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD]};    // [3:0]  Downstream Port Transmitter Preset

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
    if (!sticky_rst_n) begin
        // Lane 4 Presets
        cfg_lec_g4_pset_ltx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP `DEFAULT_DSP_16G_TX_PRESET4;
        // Lane 5 Presets
        cfg_lec_g4_pset_ltx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP `DEFAULT_DSP_16G_TX_PRESET5;
        // Lane 6 Presets
        cfg_lec_g4_pset_ltx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP `DEFAULT_DSP_16G_TX_PRESET6;
        // Lane 7 Presets
        cfg_lec_g4_pset_ltx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP `DEFAULT_DSP_16G_TX_PRESET7;
    end else begin
        // Lane 4 Presets
        cfg_lec_g4_pset_ltx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP (pl16g_reg_id[9] & pl16g_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[0*4 +: 4] : cfg_lec_g4_pset_ltx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD];
        // Lane 5 Presets
        cfg_lec_g4_pset_ltx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP (pl16g_reg_id[9] & pl16g_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[2*4 +: 4] : cfg_lec_g4_pset_ltx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD];
        // Lane 6 Presets
        cfg_lec_g4_pset_ltx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP (pl16g_reg_id[9] & pl16g_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[4*4 +: 4] : cfg_lec_g4_pset_ltx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD];
        // Lane 7 Presets
        cfg_lec_g4_pset_ltx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP (pl16g_reg_id[9] & pl16g_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[6*4 +: 4] : cfg_lec_g4_pset_ltx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD];
    end
end
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
    if (!sticky_rst_n) begin
        // Lane 4 Presets
        cfg_lec_g4_pset_rtx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP `DEFAULT_USP_16G_TX_PRESET4;
        // Lane 5 Presets
        cfg_lec_g4_pset_rtx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP `DEFAULT_USP_16G_TX_PRESET5;
        // Lane 6 Presets
        cfg_lec_g4_pset_rtx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP `DEFAULT_USP_16G_TX_PRESET6;
        // Lane 7 Presets
        cfg_lec_g4_pset_rtx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP `DEFAULT_USP_16G_TX_PRESET7;
    end else begin
        // Lane 4 Presets
        cfg_lec_g4_pset_rtx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD]    <= #TP (pl16g_reg_id[9] & pl16g_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[1*4 +: 4] : cfg_lec_g4_pset_rtx_24h[5*TX_PSET_WD-1:4*TX_PSET_WD];
        // Lane 5 Presets
        cfg_lec_g4_pset_rtx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD]    <= #TP (pl16g_reg_id[9] & pl16g_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[3*4 +: 4] : cfg_lec_g4_pset_rtx_24h[6*TX_PSET_WD-1:5*TX_PSET_WD];
        // Lane 6 Presets
        cfg_lec_g4_pset_rtx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD]    <= #TP (pl16g_reg_id[9] & pl16g_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[5*4 +: 4] : cfg_lec_g4_pset_rtx_24h[7*TX_PSET_WD-1:6*TX_PSET_WD];
        // Lane 7 Presets
        cfg_lec_g4_pset_rtx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD]    <= #TP (pl16g_reg_id[9] & pl16g_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[7*4 +: 4] : cfg_lec_g4_pset_rtx_24h[8*TX_PSET_WD-1:7*TX_PSET_WD];
    end
end


// =============================================================================
// Register Read Operation
// =============================================================================

always @(*)
begin : read_data_PROC
    unique case (1'b1)
        pl16g_reg_id[0]  : pl16g_reg_data = {pl16g_reg_03, pl16g_reg_02, pl16g_reg_01, pl16g_reg_00};
        pl16g_reg_id[1]  : pl16g_reg_data = {pl16g_reg_07, pl16g_reg_06, pl16g_reg_05, pl16g_reg_04};
        pl16g_reg_id[2]  : pl16g_reg_data = {pl16g_reg_11, pl16g_reg_10, pl16g_reg_09, pl16g_reg_08};
        pl16g_reg_id[3]  : pl16g_reg_data = {pl16g_reg_15, pl16g_reg_14, pl16g_reg_13, pl16g_reg_12};
        pl16g_reg_id[4]  : pl16g_reg_data = {pl16g_reg_19, pl16g_reg_18, pl16g_reg_17, pl16g_reg_16};
        pl16g_reg_id[5]  : pl16g_reg_data = {pl16g_reg_23, pl16g_reg_22, pl16g_reg_21, pl16g_reg_20};
        pl16g_reg_id[6]  : pl16g_reg_data = {pl16g_reg_27, pl16g_reg_26, pl16g_reg_25, pl16g_reg_24};
        pl16g_reg_id[7]  : pl16g_reg_data = {pl16g_reg_31, pl16g_reg_30, pl16g_reg_29, pl16g_reg_28};
        pl16g_reg_id[8]  : pl16g_reg_data = {pl16g_reg_35, pl16g_reg_34, pl16g_reg_33, pl16g_reg_32};
        pl16g_reg_id[9] : pl16g_reg_data = {pl16g_reg_39, pl16g_reg_38, pl16g_reg_37, pl16g_reg_36};
        default        : pl16g_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end


endmodule // cdm_pl16g_reg
