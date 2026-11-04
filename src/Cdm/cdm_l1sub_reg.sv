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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_l1sub_reg.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the L1 Substates Extended Capability (L1SUB)
// --- registers. This module is instantiated once and shared across all functions.
// --- A Write to the one of the L1SUB registers for a given function, updates
// --- that register across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_l1sub_reg
#(
    parameter INST          = 0,                                   // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM      = 0,                                   // uniquifying parameter per function
    parameter TP            = `TP,                                 // Clock to Q delay (simulator insurance)
    parameter NL1SUB        = 4                                    // Number of registers in L1 Substates Extended Capability Structure
)

                     (
    // -------------- Inputs ---------------
    input                             core_clk,                    // Core Clock
    input                             non_sticky_rst_n,            // Non-Sticky Reset
    input                             sticky_rst_n,                // Sticky Reset (cold reset only)
    input  [31:0]                     lbc_cdm_data,                // Write Data
    input                             lbc_cdm_dbi,                 // DBI Access
    input  [3:0]                      l1sub_write_pulse,           // Write Byte Enables
    input  [NL1SUB-1:0]               l1sub_reg_id,                // L1SUB Register ID
    input                             upstream_port,               // Device is Upstream Port
    input                             cfg_ltr_m_en,                // LTR mechanism enable bit
    input  [31:0]                     app_ltr_latency,             // LTR reported latency
    input                             dbi_ro_wr_en,                // used to make RW registers look like RO for compliance
    input  [3:0]                      device_type,                 // used to indicate if device is RP
input                                 cxl_rcrb_enable,

    // -------------- Outputs --------------
    output [`CX_L1SUB_CONTROL_WD-1:0] cfg_l1sub_control,           // l1sub control signal bus
    output reg                        cfg_l1sub_en,                // L1 Substates are enabled, used by app to determine when CLKREQ# can be driven
    output reg [31:0]                 l1sub_reg_data               // L1SUB Register Read Data
);

localparam PM_D0_ACT  = 3'b000;
localparam ABS_VALUE_WD = 35; // bit width for the absolute value of for LTR latencies after resolving for scale/value encoding

// -------------- Internal Signals --------------

reg     [15:0]       cfg_l1sub_id;
reg     [3:0]        cfg_l1sub_ver;
reg     [11:0]       cfg_l1sub_next_ptr;
reg                  cfg_l1sub_l1_2_pcipm_supported, cfg_l1sub_l1_1_pcipm_supported;
reg                  cfg_l1sub_l1_2_aspm_supported, cfg_l1sub_l1_1_aspm_supported;
reg                  cfg_l1sub_l1_pmsub_supported;
reg     [7:0]        cfg_l1sub_t_common_mode_supported;
reg     [1:0]        cfg_l1sub_t_power_on_scale_supported;
reg     [4:0]        cfg_l1sub_t_power_on_value_supported;
reg                  cfg_l1sub_l1_2_pcipm_enable, cfg_l1sub_l1_1_pcipm_enable;
reg                  cfg_l1sub_l1_2_aspm_enable, cfg_l1sub_l1_1_aspm_enable;
wire                 int_l1sub_l1_2_aspm_enable;
reg     [1:0]        cfg_l1sub_t_power_on_scale;
reg     [4:0]        cfg_l1sub_t_power_on_value;
reg     [11:0]       cfg_l1sub_t_power_on;
reg     [7:0]        cfg_l1sub_t_common_mode;
reg     [9:0]        cfg_l1sub_ltr_l1_2_th_value;
reg     [2:0]        cfg_l1sub_ltr_l1_2_th_scale;

wire    [7:0]        l1sub_reg_03, l1sub_reg_02, l1sub_reg_01, l1sub_reg_00;
wire    [7:0]        l1sub_reg_07, l1sub_reg_06, l1sub_reg_05, l1sub_reg_04;
wire    [7:0]        l1sub_reg_11, l1sub_reg_10, l1sub_reg_09, l1sub_reg_08;
wire    [7:0]        l1sub_reg_15, l1sub_reg_14, l1sub_reg_13, l1sub_reg_12;

wire                 int_ltr_m_en;
wire    [31:0]       int_app_ltr_latency;

wire [ABS_VALUE_WD-1:0] ltr_snoop_abs_value; //Snoop absolute value
wire [ABS_VALUE_WD-1:0] ltr_nosnoop_abs_value; //non-snoop absolute value
wire [ABS_VALUE_WD-1:0] l1sub_threshold_abs_value;
wire                 ltr_snoop_no_requirement;
wire                 ltr_nosnoop_no_requirement;
wire                 ltr_check_ok_to_enter_aspm_l1_2;

wire            rc_device;
wire            pcie_sw_down;

// Determine when Root Port is implemented - relevant for DM product in RP
// mode.
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);

// Extract write_pulse and reg_id for active function

// -----------------------------------------------------------------------------
// L1 Substates Extended Capability Header Register
// -----------------------------------------------------------------------------
// l1sub_reg_id     - 0
// PCIE Offset      - `L1SUB_PTR
// length           - 4 byte
// Cfig register    - l1sub_reg_03, l1sub_reg_02, l1sub_reg_01, l1sub_reg_00
// Read Only
// -----------------------------------------------------------------------------
reg         l1sub_next_ptr_wr_updated;    // Asserted when VC Capability header has been changed by a DBI write

always @( posedge core_clk or negedge sticky_rst_n ) begin : cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_l1sub_id[15:0]       <= #TP `PCIE_L1SUB_ECAP_ID;
        cfg_l1sub_ver[3:0]       <= #TP `PCIE_L1SUB_ECAP_VER;
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_l1sub_id[7:0]        <= #TP (l1sub_reg_id[0] & l1sub_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_l1sub_id[7:0];
        cfg_l1sub_id[15:8]       <= #TP (l1sub_reg_id[0] & l1sub_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_l1sub_id[15:8];
        cfg_l1sub_ver[3:0]       <= #TP (l1sub_reg_id[0] & l1sub_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_l1sub_ver[3:0];
    end
end

// Capabilities such as RBAR should not
// be visible to a DM product in Root Port mode; hence, when rc_device
// is true then the next pointer is in a smaller linked list.
always @( posedge core_clk or negedge sticky_rst_n ) begin : cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_l1sub_next_ptr[11:0] <= #TP `L1SUB_NEXT_PTR;                  // Assume EP linked list at reset.
    end else if (l1sub_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_l1sub_next_ptr[3:0]  <= #TP l1sub_write_pulse[2] ? lbc_cdm_data[23:20] : cfg_l1sub_next_ptr[3:0];
        cfg_l1sub_next_ptr[11:4] <= #TP l1sub_write_pulse[3] ? lbc_cdm_data[31:24] : cfg_l1sub_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !l1sub_next_ptr_wr_updated) begin
        cfg_l1sub_next_ptr[11:0] <= #TP `DM_RP_L1SUB_NEXT_PTR;            // If RP or downstream port of SW, then use smaller linked list.
    end else if (!l1sub_next_ptr_wr_updated) begin
        cfg_l1sub_next_ptr[11:0] <= #TP cxl_rcrb_enable ? `RCRB_L1SUB_NEXT_PTR :  `L1SUB_NEXT_PTR;                  // If RP or upstream port of SW, then use full linked list. Device type could change if crosslink enable is true.
    end
end

// If next pointer is modified by a DBI write, then only the Application
// (via another DBI write) is allowed any further update.
always @( posedge core_clk or negedge sticky_rst_n ) begin : l1sub_next_ptr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        l1sub_next_ptr_wr_updated <= #TP 1'b0;
    end else if (l1sub_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |l1sub_write_pulse[3:2]) begin
        l1sub_next_ptr_wr_updated <= #TP 1'b1;
    end
end

assign {l1sub_reg_01, l1sub_reg_00}      = cfg_l1sub_id;
assign l1sub_reg_02[3:0]                 = cfg_l1sub_ver;
assign {l1sub_reg_03, l1sub_reg_02[7:4]} = cfg_l1sub_next_ptr;

// -----------------------------------------------------------------------------
// L1 Substates Capabilities Register
// -----------------------------------------------------------------------------
// l1sub_reg_id     - 1
// PCIE Offset      - `L1SUB_PTR + 04h
// length           - 4 byte
// Cfig register    - l1sub_reg_07, l1sub_reg_06, l1sub_reg_05, l1sub_reg_04
// -----------------------------------------------------------------------------
wire s_l12_supported;
assign s_l12_supported = (cfg_l1sub_l1_2_pcipm_supported || cfg_l1sub_l1_2_aspm_supported);

always @( posedge core_clk or negedge sticky_rst_n ) begin : capabilities_PROC
    if ( !sticky_rst_n ) begin
        cfg_l1sub_l1_2_pcipm_supported       <= #TP `DEFAULT_L1_SUBSTATES_SUPPORT_VALUE;
        cfg_l1sub_l1_1_pcipm_supported       <= #TP `DEFAULT_L1_SUBSTATES_SUPPORT_VALUE;
        cfg_l1sub_l1_2_aspm_supported        <= #TP `CX_LTR_M_ENABLE_VALUE && `DEFAULT_L1_SUBSTATES_SUPPORT_VALUE;
        cfg_l1sub_l1_1_aspm_supported        <= #TP `DEFAULT_L1_SUBSTATES_SUPPORT_VALUE;
        cfg_l1sub_l1_pmsub_supported         <= #TP `DEFAULT_L1_SUBSTATES_SUPPORT_VALUE;
        cfg_l1sub_t_common_mode_supported    <= #TP `DEFAULT_L1_SUBSTATES_SUPPORT_VALUE ? `DEFAULT_L1SUB_PORT_T_COMM_MODE : 8'h0;
        cfg_l1sub_t_power_on_scale_supported <= #TP `DEFAULT_L1_SUBSTATES_SUPPORT_VALUE ? `DEFAULT_L1SUB_PORT_T_POWER_ON_SCALE : 2'h0;
        cfg_l1sub_t_power_on_value_supported <= #TP `DEFAULT_L1_SUBSTATES_SUPPORT_VALUE ? `DEFAULT_L1SUB_PORT_T_POWER_ON_VALUE : 5'h0;
    end else begin
        cfg_l1sub_l1_2_pcipm_supported       <= #TP (l1sub_reg_id[1] & l1sub_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[0]     : cfg_l1sub_l1_2_pcipm_supported;        //HwInit
        cfg_l1sub_l1_1_pcipm_supported       <= #TP (l1sub_reg_id[1] & l1sub_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[1]     : cfg_l1sub_l1_1_pcipm_supported;        //HwInit
        cfg_l1sub_l1_2_aspm_supported        <= #TP (l1sub_reg_id[1] & l1sub_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[2]     : cfg_l1sub_l1_2_aspm_supported;         //HwInit;
        cfg_l1sub_l1_1_aspm_supported        <= #TP (l1sub_reg_id[1] & l1sub_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[3]     : cfg_l1sub_l1_1_aspm_supported;         //HwInit;
        cfg_l1sub_l1_pmsub_supported         <= #TP (l1sub_reg_id[1] & l1sub_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[4]     : cfg_l1sub_l1_pmsub_supported;                //HwInit
        if(!s_l12_supported) begin
          cfg_l1sub_t_common_mode_supported    <= #TP 8'h00;
          cfg_l1sub_t_power_on_scale_supported <= #TP 2'b00;
          cfg_l1sub_t_power_on_value_supported <= #TP 5'h00;
        end else begin
          cfg_l1sub_t_common_mode_supported    <= #TP (l1sub_reg_id[1] & l1sub_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8]  : cfg_l1sub_t_common_mode_supported;     //HwInit;
          cfg_l1sub_t_power_on_scale_supported <= #TP (l1sub_reg_id[1] & l1sub_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[17:16] : cfg_l1sub_t_power_on_scale_supported;  //HwInit;
          cfg_l1sub_t_power_on_value_supported <= #TP (l1sub_reg_id[1] & l1sub_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[23:19] : cfg_l1sub_t_power_on_value_supported;  //HwInit;
        end
    end
end //always

assign l1sub_reg_04 = {3'h0, cfg_l1sub_l1_pmsub_supported, cfg_l1sub_l1_1_aspm_supported, cfg_l1sub_l1_2_aspm_supported, cfg_l1sub_l1_1_pcipm_supported, cfg_l1sub_l1_2_pcipm_supported};
assign l1sub_reg_05 = cfg_l1sub_t_common_mode_supported;
assign l1sub_reg_06 = {cfg_l1sub_t_power_on_value_supported, 1'b0, cfg_l1sub_t_power_on_scale_supported};
assign l1sub_reg_07 = 8'h0;

// -----------------------------------------------------------------------------
// L1 Substates Control 1 Register
// -----------------------------------------------------------------------------
// l1sub_reg_id     - 2
// PCIE Offset      - `L1SUB_PTR + 08h
// length           - 4 byte
// Cfig register    - l1sub_reg_11, l1sub_reg_10, l1sub_reg_09, l1sub_reg_08
// -----------------------------------------------------------------------------

`define L1_2_TH_VAL  10'h0
`define L1_2_TH_SCA  3'h0

always @( posedge core_clk or negedge non_sticky_rst_n ) begin : control_1_PROC
    if ( !non_sticky_rst_n ) begin
        cfg_l1sub_l1_2_pcipm_enable      <= #TP 1'b0;
        cfg_l1sub_l1_1_pcipm_enable      <= #TP 1'b0;
        cfg_l1sub_l1_2_aspm_enable       <= #TP 1'b0;
        cfg_l1sub_l1_1_aspm_enable       <= #TP 1'b0;
        cfg_l1sub_t_common_mode          <= #TP `DEFAULT_L1_SUBSTATES_SUPPORT_VALUE ? `DEFAULT_L1SUB_PORT_T_COMM_MODE : 'h0;
        cfg_l1sub_ltr_l1_2_th_value      <= #TP `L1_2_TH_VAL;
        cfg_l1sub_ltr_l1_2_th_scale      <= #TP `L1_2_TH_SCA;
        cfg_l1sub_en                     <= #TP 1'b0;
    end else begin
        cfg_l1sub_l1_2_pcipm_enable      <= #TP (l1sub_reg_id[2] & l1sub_write_pulse[0]) ? lbc_cdm_data[0] : cfg_l1sub_l1_2_pcipm_enable; //RW
        cfg_l1sub_l1_1_pcipm_enable      <= #TP (l1sub_reg_id[2] & l1sub_write_pulse[0]) ? lbc_cdm_data[1] : cfg_l1sub_l1_1_pcipm_enable; //RW
        cfg_l1sub_l1_2_aspm_enable       <= #TP (l1sub_reg_id[2] & l1sub_write_pulse[0]) ? lbc_cdm_data[2] : cfg_l1sub_l1_2_aspm_enable; //RW
        cfg_l1sub_l1_1_aspm_enable       <= #TP (l1sub_reg_id[2] & l1sub_write_pulse[0]) ? lbc_cdm_data[3] : cfg_l1sub_l1_1_aspm_enable;  //RW

        // This field is RsvDp for Upstream port configurations or when L1.2 is not supported for ASPM or PCI-PM
        if(!s_l12_supported || upstream_port) begin
          cfg_l1sub_t_common_mode          <= #TP 8'h00; 
        end else begin
          cfg_l1sub_t_common_mode          <= #TP (l1sub_reg_id[2] & l1sub_write_pulse[1] & lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_l1sub_t_common_mode; //HwInit for DSP, RsvdP for USP
        end

        // These fields are RsvDp when L1.2 is not supported for ASPM
        if(!cfg_l1sub_l1_2_aspm_supported) begin
          cfg_l1sub_ltr_l1_2_th_value      <= #TP 10'h00; 
          cfg_l1sub_ltr_l1_2_th_scale      <= #TP 3'b000;
        end else begin
          cfg_l1sub_ltr_l1_2_th_value[7:0] <= #TP (l1sub_reg_id[2] & l1sub_write_pulse[2]) ? lbc_cdm_data[23:16] : cfg_l1sub_ltr_l1_2_th_value[7:0]; //RW
          cfg_l1sub_ltr_l1_2_th_value[9:8] <= #TP (l1sub_reg_id[2] & l1sub_write_pulse[3]) ? lbc_cdm_data[25:24] : cfg_l1sub_ltr_l1_2_th_value[9:8]; //RW
          cfg_l1sub_ltr_l1_2_th_scale      <= #TP (l1sub_reg_id[2] & l1sub_write_pulse[3]) ? lbc_cdm_data[31:29] : cfg_l1sub_ltr_l1_2_th_scale; //RW
        end

        cfg_l1sub_en                     <= #TP cfg_l1sub_l1_2_pcipm_enable | cfg_l1sub_l1_1_pcipm_enable |  cfg_l1sub_l1_2_aspm_enable | cfg_l1sub_l1_1_aspm_enable;
    end
end //always

assign {l1sub_reg_09, l1sub_reg_08} = {cfg_l1sub_t_common_mode, 4'h0, cfg_l1sub_l1_1_aspm_enable, cfg_l1sub_l1_2_aspm_enable, cfg_l1sub_l1_1_pcipm_enable, cfg_l1sub_l1_2_pcipm_enable};
assign {l1sub_reg_11, l1sub_reg_10} = {cfg_l1sub_ltr_l1_2_th_scale, 3'h0, cfg_l1sub_ltr_l1_2_th_value};

// -----------------------------------------------------------------------------
// L1 Substates Control 2 Register
// -----------------------------------------------------------------------------
// l1sub_reg_id     - 2
// PCIE Offset      - `L1SUB_PTR + 0Ch
// length           - 4 byte
// Cfig register    - l1sub_reg_15, l1sub_reg_14, l1sub_reg_13, l1sub_reg_12
// -----------------------------------------------------------------------------

`define T_POWER_ON_SCALE 2'h0
`define T_POWER_ON_VALUE 5'h5

always @( posedge core_clk or negedge non_sticky_rst_n ) begin : control_2_PROC
    if ( !non_sticky_rst_n ) begin
        cfg_l1sub_t_power_on_scale <= #TP `T_POWER_ON_SCALE;
        cfg_l1sub_t_power_on_value <= #TP `DEFAULT_L1_SUBSTATES_SUPPORT_VALUE ? `T_POWER_ON_VALUE : 5'h0;
    end else begin
      // These fields are RsvDp when L1.2 is not supported for ASPM or PCI-PM
      if(!s_l12_supported) begin
        cfg_l1sub_t_power_on_scale <= #TP 2'b00;
        cfg_l1sub_t_power_on_value <= #TP 5'h00;
      end else begin
        cfg_l1sub_t_power_on_scale <= #TP (l1sub_reg_id[3] & l1sub_write_pulse[0]) ? lbc_cdm_data[1:0] : cfg_l1sub_t_power_on_scale; //RW
        cfg_l1sub_t_power_on_value <= #TP (l1sub_reg_id[3] & l1sub_write_pulse[0]) ? lbc_cdm_data[7:3] : cfg_l1sub_t_power_on_value; //RW
      end
    end
end //always

assign {l1sub_reg_13, l1sub_reg_12} = {8'h0, cfg_l1sub_t_power_on_value, 1'b0, cfg_l1sub_t_power_on_scale};
assign {l1sub_reg_15, l1sub_reg_14} = 16'h0;

// =============================================================================
// Register Read Operation
// =============================================================================

always @( * ) begin : read_data_PROC
    unique case (1'b1)
        l1sub_reg_id[0]  : l1sub_reg_data = {l1sub_reg_03, l1sub_reg_02, l1sub_reg_01, l1sub_reg_00};
        l1sub_reg_id[1]  : l1sub_reg_data = {l1sub_reg_07, l1sub_reg_06, l1sub_reg_05, l1sub_reg_04};
        l1sub_reg_id[2]  : l1sub_reg_data = {l1sub_reg_11, l1sub_reg_10, l1sub_reg_09, l1sub_reg_08};
        l1sub_reg_id[3]  : l1sub_reg_data = {l1sub_reg_15, l1sub_reg_14, l1sub_reg_13, l1sub_reg_12};
        default        : l1sub_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end //always

// =============================================================================
// yield absolute value of T_POWER_ON
// =============================================================================

/*
t_power_on_value      v           v              v
t_power_on_scale    2'b00       2'b01          2'b10
t_power_on          v * 2       v * 10         v * 100
*/

always @( * ) begin
cfg_l1sub_t_power_on = 0;
    case ( cfg_l1sub_t_power_on_scale )
        2'b00   : cfg_l1sub_t_power_on = {6'b0, cfg_l1sub_t_power_on_value, 1'b0};
        2'b01   : cfg_l1sub_t_power_on = {3'b0, cfg_l1sub_t_power_on_value, 3'h0} + {6'b0, cfg_l1sub_t_power_on_value, 1'b0}; //8 + 2 = 10
        2'b10   : cfg_l1sub_t_power_on = {1'b0, cfg_l1sub_t_power_on_value, 6'h0} + {2'b0, cfg_l1sub_t_power_on_value, 5'h0} + {5'b0, cfg_l1sub_t_power_on_value, 2'h0}; //64 + 32 + 4 = 100
        default : cfg_l1sub_t_power_on = 12'b0;
    endcase
end //always


// =============================================================================
// target_l1sub generation
// =============================================================================

assign int_ltr_m_en = cfg_ltr_m_en;
assign int_app_ltr_latency = app_ltr_latency;

assign ltr_snoop_abs_value = calc_abs_value(int_app_ltr_latency[12:10], int_app_ltr_latency[9:0]);
assign ltr_nosnoop_abs_value = calc_abs_value(int_app_ltr_latency[28:26], int_app_ltr_latency[25:16]);
assign l1sub_threshold_abs_value = calc_abs_value(cfg_l1sub_ltr_l1_2_th_scale[2:0], cfg_l1sub_ltr_l1_2_th_value[9:0]);
// Force no latency requirement when LTR is disabled
assign ltr_snoop_no_requirement = (int_app_ltr_latency[15]==0) || ~int_ltr_m_en; 
assign ltr_nosnoop_no_requirement = (int_app_ltr_latency[31]==0) || ~int_ltr_m_en ; 

// LTR conditions for ASPM L1 2
// 1) Snooped LTR is >= LTR L12 Threshold Scale, OR there is no snoop latency service requirement AND
// 2) Non-snooped LTR is >= LTR L12 Threshold Scale, OR there is no nosnoop latency service requirement
// Note: snoop/nosnoop latency requirements only exist when the LTR Mechanism Enable bit is set in the Device Control 2 Register, when CX_LTR_M_ENABLE = 1
assign ltr_check_ok_to_enter_aspm_l1_2 =  ((ltr_snoop_abs_value >= l1sub_threshold_abs_value)   || ltr_snoop_no_requirement) &&
                                          ((ltr_nosnoop_abs_value >= l1sub_threshold_abs_value) || ltr_nosnoop_no_requirement);

// Enable ASPM L1.2 below if:
// 1) ASPM L1.2 enable bit is set
// 2) LTR conditions above are met
assign int_l1sub_l1_2_aspm_enable = cfg_l1sub_l1_2_aspm_enable && ltr_check_ok_to_enter_aspm_l1_2;
assign cfg_l1sub_control = {cfg_l1sub_t_common_mode[7:0], cfg_l1sub_l1_2_pcipm_enable, cfg_l1sub_l1_1_pcipm_enable, int_l1sub_l1_2_aspm_enable, cfg_l1sub_l1_1_aspm_enable, cfg_l1sub_t_power_on[11:0]};

// Function to convert LTR scale/value encoding into one single value which we can then use for making comparisons
function automatic [ABS_VALUE_WD-1:0] calc_abs_value(input [2:0] scale, input [9:0] value);
    begin
        // LMD: This code will infer a latch. Need to have a default for a case statement and a completely specified if statement
        // LJ: This case have a default case
        // leda C_3C_R off
        // LMD: Use non-blocking assignments in sequential
        // LJ: This is a combinational block
        // leda B_3417 off
        case ( scale )
            3'b000  : calc_abs_value = {{(ABS_VALUE_WD-10){1'b0}}    ,value        };
            3'b001  : calc_abs_value = {{(ABS_VALUE_WD-10-5){1'b0}}  ,value, 5'd0  };
            3'b010  : calc_abs_value = {{(ABS_VALUE_WD-10-10){1'b0}} ,value, 10'd0 };
            3'b011  : calc_abs_value = {{(ABS_VALUE_WD-10-15){1'b0}} ,value, 15'd0 };
            3'b100  : calc_abs_value = {{(ABS_VALUE_WD-10-20){1'b0}} ,value, 20'd0 };
            3'b101  : calc_abs_value = {                              value, 25'd0 };
            default : calc_abs_value = 'd0;
        endcase
        // leda B_3417 on
        // leda C_3C_R on
    end
endfunction

endmodule //cdm_l1sub_reg
