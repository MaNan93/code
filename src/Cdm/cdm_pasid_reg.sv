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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_pasid_reg.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the PASID Extended Capability (PASID) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_pasid_reg
#(
    parameter INST          = 0,                                   // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM      = 0,                                   // uniquifying parameter per function
    parameter VF_IMPL       = 0,                                   // 0: PF impl. 1: VF impl.
    parameter TP            = `TP,                                 // Clock to Q delay (simulator insurance)
    parameter NPASID        = 2                                    // Number of registers in PASID Extended Capability Structure
)

                     (
    // -------------- Inputs ---------------
    input                             core_clk,                    // Core Clock
    input                             non_sticky_rst_n,            // Non-Sticky Reset
    input                             sticky_rst_n,                // Sticky Reset (that is, asserted for cold reset only)
    input                             cdm_clk_g,                   // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
    input  [31:0]                     lbc_cdm_data,                // Write Data 
    input                             lbc_cdm_dbi,                 // DBI Access
    input  [3:0]                      pasid_write_pulse,           // Write Byte Enables
    input  [NPASID-1:0]               pasid_reg_id,                // PASID Register ID
    input                             dbi_ro_wr_en,                // used to make RW registers look like RO for compliance
    input                             cxl_rcrb_enable,             // Indicates that the CXL 1.1 Link is up for USP supporting RCRB

    // -------------- Outputs --------------
    output [`CX_PASID_CONTROL_WD-1:0] cfg_pasid_control,           // pasid control signal bus
    output reg [31:0]                 pasid_reg_data               // PASID Register Read Data
);

// Next Pointer depends on whether this is a physical or virtual function:
localparam INT_PASID_NEXT_PTR = VF_IMPL ? `VF_PASID_NEXT_PTR : `PASID_NEXT_PTR;


// -------------- Internal Signals --------------
wire    [3:0]        int_write_pulse;                              // Internal Write Pulse
wire    [NPASID-1:0] int_reg_id;                                   // Internal Register ID

reg     [15:0]       cfg_pasid_id;
reg     [3:0]        cfg_pasid_ver;
reg     [11:0]       cfg_pasid_next_ptr;
reg     [4:0]        cfg_pasid_max_pasid_width;
reg                  cfg_pasid_prvlgd_mode_spprtd;
reg                  cfg_pasid_exct_prmssn_spprtd;
reg                  cfg_pasid_prvlgd_mode_enable;
reg                  cfg_pasid_exct_prmssn_enable;
reg                  cfg_pasid_enable;

wire    [7:0]        pasid_reg_03, pasid_reg_02, pasid_reg_01, pasid_reg_00;
wire    [7:0]        pasid_reg_07, pasid_reg_06, pasid_reg_05, pasid_reg_04;



// Extract write_pulse and reg_id for active function
assign int_write_pulse = pasid_write_pulse;
assign int_reg_id = pasid_reg_id;

// -----------------------------------------------------------------------------
// PASID Extended Capability Header Register
// -----------------------------------------------------------------------------
// pasid_reg_id     - 0
// PCIE Offset      - `PASID_PTR
// length           - 4 byte
// Cfig register    - pasid_reg_03, pasid_reg_02, pasid_reg_01, pasid_reg_00
// Read Only
// -----------------------------------------------------------------------------

reg pasid_next_ptr_wr_updated;
always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_pasid_next_ptr[11:0]  <= #TP INT_PASID_NEXT_PTR;
        pasid_next_ptr_wr_updated <= #TP 1'b0;
    end else begin
        if (int_reg_id[0] & |int_write_pulse[3:2] & lbc_cdm_dbi & dbi_ro_wr_en) begin
        pasid_next_ptr_wr_updated <= #TP 1'b1;
        // Read-Only registers, but writable through DBI
        cfg_pasid_next_ptr[3:0]  <= #TP (int_reg_id[0] & int_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[23:20] 
                                      : cfg_pasid_next_ptr[3:0];
        cfg_pasid_next_ptr[11:4] <= #TP (int_reg_id[0] & int_write_pulse[3] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[31:24] 
                                      : cfg_pasid_next_ptr[11:4];
        end
        else if (!pasid_next_ptr_wr_updated) begin
            cfg_pasid_next_ptr[11:0] <= #TP (cxl_rcrb_enable  && (VF_IMPL == 0)) ? `CXL_PASID_NEXT_PTR : INT_PASID_NEXT_PTR;
        end
    end
end

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_pasid_id[15:0]       <= #TP `PCIE_PASID_ECAP_ID;
        cfg_pasid_ver[3:0]       <= #TP `PCIE_PASID_ECAP_VER;
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_pasid_id[7:0]        <= #TP (int_reg_id[0] & int_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_pasid_id[7:0];
        cfg_pasid_id[15:8]       <= #TP (int_reg_id[0] & int_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_pasid_id[15:8];
        cfg_pasid_ver[3:0]       <= #TP (int_reg_id[0] & int_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_pasid_ver[3:0];
    end
end

assign {pasid_reg_01, pasid_reg_00}      = cfg_pasid_id;
assign pasid_reg_02[3:0]                 = cfg_pasid_ver;
assign {pasid_reg_03, pasid_reg_02[7:4]} = cfg_pasid_next_ptr;

// -----------------------------------------------------------------------------
// PASID Capabilities Register
// -----------------------------------------------------------------------------
// pasid_reg_id     - 1
// PCIE Offset      - `PASID_PTR + 04h
// length           - 2 byte
// Cfig register    - pasid_reg_05, pasid_reg_04
// -----------------------------------------------------------------------------

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : capabilities_PROC
    if ( !sticky_rst_n ) begin
        cfg_pasid_max_pasid_width            <= #TP `DEFAULT_MAX_PASID_WDTH;
        cfg_pasid_prvlgd_mode_spprtd         <= #TP `DEFAULT_PRVLGD_MODE_SPPRT;
        cfg_pasid_exct_prmssn_spprtd         <= #TP `DEFAULT_EXCT_PRMSSN_SPPRT;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_pasid_max_pasid_width            <= #TP (int_reg_id[1] & int_write_pulse[1] & lbc_cdm_dbi) ? lbc_cdm_data[12:8]  : cfg_pasid_max_pasid_width;        //HwInit
        cfg_pasid_prvlgd_mode_spprtd         <= #TP (int_reg_id[1] & int_write_pulse[0] & lbc_cdm_dbi) ? lbc_cdm_data[2]     : cfg_pasid_prvlgd_mode_spprtd;        //HwInit
        cfg_pasid_exct_prmssn_spprtd         <= #TP (int_reg_id[1] & int_write_pulse[0] & lbc_cdm_dbi) ? lbc_cdm_data[1]     : cfg_pasid_exct_prmssn_spprtd;         //HwInit;
    end
end //always

assign pasid_reg_04 = {5'h0, cfg_pasid_prvlgd_mode_spprtd, cfg_pasid_exct_prmssn_spprtd, 1'b0};
assign pasid_reg_05 = {3'h0, cfg_pasid_max_pasid_width};

// -----------------------------------------------------------------------------
// PASID Control Register
// -----------------------------------------------------------------------------
// pasid_reg_id     - 2
// PCIE Offset      - `PASID_PTR + 06h
// length           - 2 byte
// Cfig register    - pasid_reg_07, pasid_reg_06 
// -----------------------------------------------------------------------------

always @( posedge cdm_clk_g or negedge non_sticky_rst_n ) begin : control_PROC
    if ( !non_sticky_rst_n ) begin
        cfg_pasid_prvlgd_mode_enable      <= #TP 1'b0;
        cfg_pasid_exct_prmssn_enable      <= #TP 1'b0;
        cfg_pasid_enable                  <= #TP 1'b0;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_pasid_prvlgd_mode_enable      <= #TP (!cfg_pasid_prvlgd_mode_spprtd) ? 0 : (int_reg_id[1] & int_write_pulse[2]) ? lbc_cdm_data[18] : cfg_pasid_prvlgd_mode_enable; //RsvdP or RW
        cfg_pasid_exct_prmssn_enable      <= #TP (!cfg_pasid_exct_prmssn_spprtd) ? 0 : (int_reg_id[1] & int_write_pulse[2]) ? lbc_cdm_data[17] : cfg_pasid_exct_prmssn_enable; //RsvdP or RW
        cfg_pasid_enable                  <= #TP (int_reg_id[1] & int_write_pulse[2]) ? lbc_cdm_data[16] : cfg_pasid_enable; //RW
    end
end //always

assign {pasid_reg_07, pasid_reg_06} = {13'h0, cfg_pasid_prvlgd_mode_enable, cfg_pasid_exct_prmssn_enable, cfg_pasid_enable};

assign cfg_pasid_control = {cfg_pasid_prvlgd_mode_enable, cfg_pasid_exct_prmssn_enable, cfg_pasid_enable};

// =============================================================================
// Register Read Operation
// =============================================================================

always @( * ) begin : read_data_PROC
    unique case ( 1'b1 )
        int_reg_id[0]  : pasid_reg_data = {pasid_reg_03, pasid_reg_02, pasid_reg_01, pasid_reg_00};
        int_reg_id[1]  : pasid_reg_data = {pasid_reg_07, pasid_reg_06, pasid_reg_05, pasid_reg_04};
        default        : pasid_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end //always


endmodule //cdm_pasid_reg 
