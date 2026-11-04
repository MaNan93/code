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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_dlink_reg.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Data Link Feature Extended Capability
// --- This module is instantiated in function 0 only, upstream/downstream ports
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_dlink_reg
#(
    parameter INST          = 0,                                    // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM      = 0,                                    // uniquifying parameter per function
    parameter NDLINK        = 3,                                    // Max possible number of registers in Dlink extended Capability Structure (3)
    parameter TP            = `TP                                   // Clock to Q delay (simulator insurance)
    , parameter RCRB          = 0                                   // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space
)

                     (
    // -------------- Inputs ----------------
    input                             core_clk,                    // Core Clock
    input                             cdm_clk_g,                   // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
    input                             sticky_rst_n,                // Sticky Reset (that is, asserted for cold reset/PERST# only)
    input                             non_sticky_rst_n,            // Non Sticky Reset (that is, asserted on link down)
    input [3:0]                       device_type,

    input  [31:0]                     lbc_cdm_data,                // Write Data 
    input                             lbc_cdm_dbi,                 // DBI Access
    input                             lbc_cdm_dbi2,
    input                             dbi_ro_wr_en,                // used to make RW registers look like RO for compliance

    input  [3:0]                      dlink_write_pulse,           // Write Byte Enable
    input  [NDLINK-1:0]               dlink_reg_id,                // DLINK Register ID

    input                             rdlh_rcvd_dl_feature,        // Feature DLLP Received
    input  [31:0]                     rcvd_dl_feature_content,     // 32 bits indicates the rcvd special dllp content
    input  [1:0]                      rdlh_dlcntrl_state,
    input                             cxl_rcrb_enable,
    input                             cfg_pcie_cap_flit_mode_sup,  // Flit Mode Supported Bitc
    // -------------- Outputs --------------

    output reg [31:0]                 dlink_reg_data,              // DLINK Register Read Data
    output reg [22:0]                 cfg_local_feature_support,   // Local Feature (Including local scaled flow control) Support
    output reg [22:0]                 cfg_remote_feature_support,  // Remote Feature (Including remote scaled flow control) Support
    output reg                        cfg_dlink_feature_valid,     // The Port has received a Data Link Feature DLLP in state DL_Feature
    output reg                        dl_feature_en,               // Local data link feature supported
    output reg                        cfg_remote_feature_ack,      // Remote Feature Ack bit captured
    output wire                       fc_scaled_en                 // local and remote feature both support FC Scaling
);

localparam INT_DLINK_NEXT_PTR = `DLINK_NEXT_PTR;


// -------------- Internal Signals --------------


wire rc_device;
wire pcie_sw_down;

assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);

// -----------------------------------------------------------------------------
// DLINK Extended Capability Header Register
// -----------------------------------------------------------------------------
// dlink_reg_id       - 0
// PCIE Offset      - `DLINK_PTR
// length           - 4 byte
// Cfig register    - dlink_reg_03, dlink_reg_02, dlink_reg_01, dlink_reg_00
// Read Only from the Wire.
// -----------------------------------------------------------------------------
reg     [15:0]       cfg_dlink_id;                                   // Capability ID
reg     [3:0]        cfg_dlink_ver;                                  // Capability Version
reg     [11:0]       cfg_dlink_next_ptr;                             // Next Capability Offset
wire    [7:0]        dlink_reg_03, dlink_reg_02, dlink_reg_01, dlink_reg_00;


always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_dlink_id[15:0]     <= #TP `PCIE_DLINK_ECAP_ID;
        cfg_dlink_ver[3:0]     <= #TP `PCIE_DLINK_ECAP_VER;
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_dlink_id[7:0]      <= #TP (dlink_reg_id[0] && dlink_write_pulse[0] && lbc_cdm_dbi && dbi_ro_wr_en) ? lbc_cdm_data[7:0]   : cfg_dlink_id[7:0];
        cfg_dlink_id[15:8]     <= #TP (dlink_reg_id[0] && dlink_write_pulse[1] && lbc_cdm_dbi && dbi_ro_wr_en) ? lbc_cdm_data[15:8]  : cfg_dlink_id[15:8];
        cfg_dlink_ver[3:0]     <= #TP (dlink_reg_id[0] && dlink_write_pulse[2] && lbc_cdm_dbi && dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_dlink_ver[3:0];
    end
end //always cap_hdr_PROC

// Remember if the user updates the next pointer
// If they have retain their value otherwise select EP/RP/MPCIE link list
// pointer values
reg         dlink_next_ptr_wr_updated;
always @( posedge core_clk or negedge sticky_rst_n ) begin : dlink_cap_hdr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        dlink_next_ptr_wr_updated <= #TP 1'b0;
    end else if (dlink_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |dlink_write_pulse[3:2]) begin
        dlink_next_ptr_wr_updated <= #TP 1'b1;
    end
end

// Next Pointer logic
always @( posedge core_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_dlink_next_ptr[11:0] <= #TP INT_DLINK_NEXT_PTR;
    end else if(dlink_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_dlink_next_ptr[3:0]  <= #TP (dlink_write_pulse[2]) ? lbc_cdm_data[23:20] : cfg_dlink_next_ptr[3:0];
        cfg_dlink_next_ptr[11:4] <= #TP (dlink_write_pulse[3]) ? lbc_cdm_data[31:24] : cfg_dlink_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !dlink_next_ptr_wr_updated) begin
        cfg_dlink_next_ptr[11:0]  <= #TP `DM_RP_DLINK_NEXT_PTR ;
    end else if (!dlink_next_ptr_wr_updated) begin
        cfg_dlink_next_ptr[11:0]  <= #TP cxl_rcrb_enable ? |RCRB ? `RCRB_DLINK_NEXT_PTR : `CXL_DLINK_NEXT_PTR : INT_DLINK_NEXT_PTR ;                // Device type could change      
    end
end 

assign {dlink_reg_01, dlink_reg_00}       = cfg_dlink_id;
assign dlink_reg_02[3:0]                  = cfg_dlink_ver;
assign {dlink_reg_03, dlink_reg_02[7:4]}  = cfg_dlink_next_ptr;

// -----------------------------------------------------------------------------
// Data Link Feature Capabilities Register
// -----------------------------------------------------------------------------
// dlink_reg_id       - 1
// PCIE Offset      - `DLINK_PTR + 04h
// length           - 4 byte
// Cfig register    - dlink_reg_07, dlink_reg_06, dlink_reg_05, dlink_reg_04
// Read Only from the Wire.
// -----------------------------------------------------------------------------

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : LOCAL_FEATURE
    if ( !sticky_rst_n ) begin
// Bits 22:0 - Local Data Link Feature Supported: Bits 22:8 - RsvdP, 
// Bit 7:5 - Local L0p Exit Latency
// Bit 4:2 - Local Extended VC Count
// Bit 1 - Local Immediate Readiness
// Bit 0 - Local Scaled Flow Control Supported

      cfg_local_feature_support[0]      <= #TP `SCALED_FC_SUPPORTED;
      cfg_local_feature_support[1]      <= #TP 1'b0; 
      cfg_local_feature_support[4:2]    <= #TP `CX_LOCAL_EXT_VC_CNT;
      cfg_local_feature_support[7:5]    <= #TP `CX_LOCAL_L0P_EXIT_LATENCY;
      cfg_local_feature_support[22:8]   <= #TP 15'b0;
// Bit 31 - Data Link Feature Exchange Enable
      dl_feature_en                     <= #TP `DL_FEATURE_EXCHANGE_ENABLE;
    end else begin 
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      cfg_local_feature_support[4:0]    <= #TP (dlink_reg_id[1] && dlink_write_pulse[0] && lbc_cdm_dbi && ~lbc_cdm_dbi2 && dbi_ro_wr_en) ? lbc_cdm_data[4:0] : cfg_local_feature_support[4:0];
      cfg_local_feature_support[7:5]    <= #TP (!cfg_pcie_cap_flit_mode_sup)? 3'b000: (dlink_reg_id[1] && dlink_write_pulse[0] && lbc_cdm_dbi && ~lbc_cdm_dbi2 && dbi_ro_wr_en) ? lbc_cdm_data[7:5] : cfg_local_feature_support[7:5];

      cfg_local_feature_support[15:8]   <= #TP (dlink_reg_id[1] && dlink_write_pulse[1] && lbc_cdm_dbi && ~lbc_cdm_dbi2 && dbi_ro_wr_en) ? lbc_cdm_data[15:8]   : cfg_local_feature_support[15:8];
      cfg_local_feature_support[22:16]  <= #TP (dlink_reg_id[1] && dlink_write_pulse[2] && lbc_cdm_dbi && ~lbc_cdm_dbi2 && dbi_ro_wr_en) ? lbc_cdm_data[22:16]  : cfg_local_feature_support[22:16];
      dl_feature_en                     <= #TP (dlink_reg_id[1] && dlink_write_pulse[3] && lbc_cdm_dbi && ~lbc_cdm_dbi2 && dbi_ro_wr_en) ? lbc_cdm_data[31]  : dl_feature_en;
      end
end : LOCAL_FEATURE

wire    [7:0]        dlink_reg_07, dlink_reg_06, dlink_reg_05, dlink_reg_04;
assign {dlink_reg_07,dlink_reg_06,dlink_reg_05,dlink_reg_04} = { dl_feature_en, 7'h00, 1'b0, cfg_local_feature_support};

// -----------------------------------------------------------------------------
// Data Link Feature Status Register
// -----------------------------------------------------------------------------
// dlink_reg_id       - 2
// PCIE Offset      - `DLINK_PTR + 08h
// length           - 4 byte
// Cfig register    - dlink_reg_11, dlink_reg_10, dlink_reg_09, dlink_reg_08
// Read Only from the Wire.
// -----------------------------------------------------------------------------

wire    [7:0]        dlink_reg_11, dlink_reg_10, dlink_reg_09, dlink_reg_08;

always @( posedge core_clk or negedge non_sticky_rst_n ) begin : REMOTE_FEATURE
    if ( !non_sticky_rst_n ) begin
// Bit 31 - Remote Data Link Feature Supported Valid
      cfg_dlink_feature_valid    <= #TP 1'b0;
// Remote port Feature Ack bit - was Bit 23 in Gen4.04 spec. Removed in Gen4.07 spec. 
      cfg_remote_feature_ack     <= #TP 1'b0;
// Bits 22:0 - Remote Data Link Feature Supported: Bits 22:1 - <Undefined>, Bit 0 Remote Scaled Flow Control Supported
      cfg_remote_feature_support <= #TP 23'b0;
    end else begin
// Port has received a DL Feature DLLP in state DL_Feature. This bit is cleared in state DL_Inactive
      cfg_dlink_feature_valid  <= #TP rdlh_rcvd_dl_feature && (rdlh_dlcntrl_state == 2'b10) ? 1'b1 : (rdlh_dlcntrl_state == 2'b00) ? 1'b0 : cfg_dlink_feature_valid;
// Is used to change state from DL_Feature to DL_Init
      cfg_remote_feature_ack   <= #TP rdlh_rcvd_dl_feature && (rdlh_dlcntrl_state == 2'b10) && (rcvd_dl_feature_content[15] == 1'b1) ? 1'b1 : (rdlh_dlcntrl_state == 2'b00) ? 1'b0 : cfg_remote_feature_ack;
// Latch the feature data
      cfg_remote_feature_support[22:16] <= #TP (!cfg_dlink_feature_valid && rdlh_rcvd_dl_feature && (rdlh_dlcntrl_state == 2'b10)) ? rcvd_dl_feature_content[14:8]  : (rdlh_dlcntrl_state == 2'b00) ? 7'b0 : cfg_remote_feature_support[22:16]; 
      cfg_remote_feature_support[15:8]  <= #TP (!cfg_dlink_feature_valid && rdlh_rcvd_dl_feature && (rdlh_dlcntrl_state == 2'b10)) ? rcvd_dl_feature_content[23:16] : (rdlh_dlcntrl_state == 2'b00) ? 8'b0 : cfg_remote_feature_support[15:8]; 
      cfg_remote_feature_support[7:0]  <= #TP  (!cfg_dlink_feature_valid && rdlh_rcvd_dl_feature && (rdlh_dlcntrl_state == 2'b10)) ? rcvd_dl_feature_content[31:24] : (rdlh_dlcntrl_state == 2'b00) ? 8'b0 : cfg_remote_feature_support[7:0]; 
    end
end : REMOTE_FEATURE

assign {dlink_reg_11, dlink_reg_10, dlink_reg_09, dlink_reg_08} = {cfg_dlink_feature_valid, 8'b0, cfg_remote_feature_support};

// =============================================================================
// Register Read Operation
// =============================================================================
always @(*) begin : read_data_PROC   
    dlink_reg_data[31:0] = 0;
    if (dlink_reg_id[0])   begin
        dlink_reg_data = {dlink_reg_03, dlink_reg_02, dlink_reg_01, dlink_reg_00};  // read Header register
    end else if (dlink_reg_id[1])   begin
        dlink_reg_data = {dlink_reg_07, dlink_reg_06, dlink_reg_05, dlink_reg_04};  // read Feature Capabilities
    end else begin
        dlink_reg_data = {dlink_reg_11, dlink_reg_10, dlink_reg_09, dlink_reg_08};  // read Feature Status
    end
end //always read_data_PROC

// Check local and remote feature both support FC Scaling and DL Feature is enabled
assign fc_scaled_en = (cfg_remote_feature_support[0] && cfg_local_feature_support[0] && dl_feature_en);

endmodule //cdm_dlink_reg 
