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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_margin_reg.sv#9 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Margining Extended Capability (MARGIN)
// --- registers. This module is instantiated once and shared across all functions.
// --- A Write to the one of the MARGIN registers for a given function, updates
// --- that register across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_margin_reg (
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    cdm_clk_g,
    lbc_cdm_data,
    lbc_cdm_dbi,
    margin_write_pulse,
    margin_reg_id,
    upstream_port,
    cfg_pcie_crosslink_supported,
    dbi_ro_wr_en,
    device_type,
    rdlh_link_up,

    smlh_margin_status_valid,
    smlh_margin_status,
    smlh_margin_ready,
    app_margining_ready,
    app_margining_software_ready,
    cxl_rcrb_enable,
// -- outputs --
    margin_reg_data,
    cfg_margin_control
);

parameter INST          = 0;                            // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM      = 0;                            // uniquifying parameter per function
parameter TP            = `TP;                          // Clock to Q delay (simulator insurance)
parameter NL            = `CX_NL;                       // Number of Lanes
parameter RCRB          = 0;                                   // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space

localparam NMARGIN     = `MARGIN_SIZE>>2;               // Number of registers in Margining Extended Capability Structure

// -------------- Inputs ---------------
input                           core_clk;               // Core Clock
input                           non_sticky_rst_n;       // Non-Sticky Reset
input                           sticky_rst_n;           // Sticky Reset
input                           lbc_cdm_dbi;            // DBI Access
input   [31:0]                  lbc_cdm_data;           // Write Data
input                           cdm_clk_g;              // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
input   [3:0]                   margin_write_pulse;     // Write Byte Enables
input   [NMARGIN-1:0]           margin_reg_id;          // MARGIN Register ID
input                           upstream_port;          // Device is Upstream Port (EP/SW_UP)
input                           cfg_pcie_crosslink_supported; // Crosslink Supported bit (bit-8 of Link Capabilities 2 Register (Offset 2Ch))
input                           dbi_ro_wr_en;
input   [3:0]                   device_type;             // used to indicate if device is RP
input                           rdlh_link_up;            // Data Link Layer = DL_Active  

input   [NL-1:0]                smlh_margin_status_valid;       // Margining Status Valid
input   [NL*16-1:0]             smlh_margin_status;             // Margining Status [2:0]Receiver Number[5:3]Margin Type[6]Usage Molde[7]Rsvd[15:8]Margin Payload
input                           smlh_margin_ready;              // indicates when the Margining feature is ready to accept margining commads
input                           app_margining_ready;            // indicates the status of Margining Ready
input                           app_margining_software_ready;   // indicates the status of Margining Software Ready.
input                           cxl_rcrb_enable;

// -------------- Outputs --------------
output  [31:0]                  margin_reg_data;                // MARGIN Register Read Data
output  [NL*16-1:0]             cfg_margin_control;             // Margining Control [2:0] Receiver Number[5:3]Margin Type[6]Usage Molde[7]Rsvd[15:8]Margin Payload

// -------------- Internal Signals --------------
wire                            upstream_component;     // Upstream Component ; Downstream Port ; Downstream Lanes
wire                            downstream_component;   // Downstream Component ; Upstream Port ; Upstream Lanes
wire                            dbi_ro_wr_en;           // DBI Read Only Write Enable
wire                            int_lbc_cdm_dbi;        // Internal DBI Access
reg     [31:0]                  margin_reg_data;        // MARGIN Register Read Data

wire    [7:0]   margin_reg_03, margin_reg_02, margin_reg_01, margin_reg_00;
wire    [7:0]   margin_reg_07, margin_reg_06, margin_reg_05, margin_reg_04;

wire            rc_device;
wire            pcie_sw_down;

//  Add pipeline for timing issues
// ----------- Add Pipeline ---------------
wire                           smlh_margin_ready_int;
wire                           app_margining_ready_int;
wire                           app_margining_software_ready_int;

delay_n
 #(.N(1), .WD(1+1+1))
u_delay_lbc_out(
    .clk(core_clk),
    .rst_n(sticky_rst_n),
    .clear(1'b0),
    .din({
     smlh_margin_ready,
     app_margining_ready,
     app_margining_software_ready
    }),
    .dout({
     smlh_margin_ready_int,
     app_margining_ready_int,
     app_margining_software_ready_int
              })
    );
//----------------------------------------
//


// Determine when Root Port is implemented - relevant for DM product in RP
// mode.
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);

assign upstream_component   = !upstream_port;
assign downstream_component =  upstream_port;

assign int_lbc_cdm_dbi      = lbc_cdm_dbi & dbi_ro_wr_en;

// -----------------------------------------------------------------------------
// Margining Extended Capability Header Register
// -----------------------------------------------------------------------------
// margin_reg_id     - 0
// PCIE Offset      - `MARGIN_PTR
// length           - 4 byte
// Cfig register    - margin_reg_03, margin_reg_02, margin_reg_01, margin_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_margin_id;          // MARGIN Capability ID
reg [3:0]   cfg_margin_ver;         // MARGIN Capability Version
reg [11:0]  cfg_margin_next_ptr;    // MARGIN Next Capability Offset
reg         margin_next_ptr_wr_updated;    // Asserted when MARGIN Capability header has been changed by a DBI write


// Next Capability Pointer. Capabilities such as SRIOV should not
// be visible to a DM product in Root Port mode; hence, when either rc_device (or pcie_sw_down in a SW product)
// is true then the next pointer is in a smaller linked list.

assign {margin_reg_01, margin_reg_00}       = cfg_margin_id;
assign margin_reg_02[3:0]                   = cfg_margin_ver;
assign {margin_reg_03, margin_reg_02[7:4]}  = cfg_margin_next_ptr;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : margin_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_margin_id[15:0]       <= #TP `PCIE_MARGIN_ECAP_ID;      // Capability ID = 0x0027
        cfg_margin_ver[3:0]       <= #TP `PCIE_MARGIN_ECAP_VER;     // Capability version = 0x1
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_margin_id[7:0]        <= #TP (margin_reg_id[0] & margin_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0]   : cfg_margin_id[7:0];
        cfg_margin_id[15:8]       <= #TP (margin_reg_id[0] & margin_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8]  : cfg_margin_id[15:8];
        cfg_margin_ver[3:0]       <= #TP (margin_reg_id[0] & margin_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_margin_ver[3:0];
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : margin_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_margin_next_ptr[11:0] <= #TP `MARGIN_NEXT_PTR;
    end else if (margin_reg_id[0] && int_lbc_cdm_dbi) begin
        // Read-Only registers, but writable through DBI
        cfg_margin_next_ptr[3:0]  <= #TP margin_write_pulse[2] ? lbc_cdm_data[23:20] : cfg_margin_next_ptr[3:0];
        cfg_margin_next_ptr[11:4] <= #TP margin_write_pulse[3] ? lbc_cdm_data[31:24] : cfg_margin_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !margin_next_ptr_wr_updated) begin
        cfg_margin_next_ptr[11:0] <= #TP `DM_RP_MARGIN_NEXT_PTR;
    end else if (!margin_next_ptr_wr_updated) begin
        cfg_margin_next_ptr[11:0] <= #TP (cxl_rcrb_enable && upstream_port) ? `RCRB_MARGIN_NEXT_PTR  :  `MARGIN_NEXT_PTR;
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : margin_next_ptr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        margin_next_ptr_wr_updated <= #TP 1'b0;
    end else if (margin_reg_id[0] && int_lbc_cdm_dbi && |margin_write_pulse[3:2]) begin
        margin_next_ptr_wr_updated <= #TP 1'b1;
    end
end

// -----------------------------------------------------------------------------
// Margining Port Capabilities Register
// -----------------------------------------------------------------------------
// margin_reg_id    - 1
// PCIE Offset      - `MARGIN_PTR + 04h
// length           - 2 byte
// Cfig register    - margin_reg_05, margin_reg_04
// -----------------------------------------------------------------------------
reg    cfg_margin_uses_driver_software;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : margin_cap_uses_driver_software
    if ( !sticky_rst_n ) begin
        cfg_margin_uses_driver_software  <= #TP `DEFAULT_MARGINING_USES_DRIVER_SOFTWARE;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // Read-Only registers, but writable through DBI
        cfg_margin_uses_driver_software  <= #TP (margin_reg_id[1] & margin_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[0] : cfg_margin_uses_driver_software;
    end
end

assign margin_reg_04 = {7'b000_0000,cfg_margin_uses_driver_software};  // [ 7: 1] Reserved
assign margin_reg_05 = 8'h00;  // [15: 8] Reserved

// -----------------------------------------------------------------------------
// Margining Port Status Capabilities Register
// -----------------------------------------------------------------------------
// margin_reg_id    - 1
// PCIE Offset      - `MARGIN_PTR + 06h
// length           - 2 byte
// Cfig register    - margin_reg_07, margin_reg_06
// -----------------------------------------------------------------------------
wire   cfg_margin_ready;          //bit[16]
wire   cfg_margin_software_ready; //bit[17]

assign cfg_margin_ready = (smlh_margin_ready_int && app_margining_ready_int);
assign cfg_margin_software_ready = app_margining_software_ready_int;
assign margin_reg_06 = {6'b00_0000,cfg_margin_software_ready,cfg_margin_ready};  // [23:18] Reserved
assign margin_reg_07 = 8'h00;  // [31:24] Reserved

// -----------------------------------------------------------------------------
// Margin Control and Status Register
// -----------------------------------------------------------------------------
// margin_reg_id     - 2 + ln
// PCIE Offset      - `MARGIN_PTR + 08h + (04h*ln)
// length           - 4 byte
// Cfig register    - margin_reg_control_status[ln]
// -----------------------------------------------------------------------------
reg  [NL*3-1:0]     cfg_control_receiver_number;
reg  [NL*3-1:0]     cfg_control_margin_type;
reg  [NL-1:0]       cfg_control_usage_model;
reg  [NL*8-1:0]     cfg_control_margin_payload;
wire [NL*16-1:0]    cfg_margin_control;

reg  [NL*3-1:0]     cfg_status_receiver_number;
reg  [NL*3-1:0]     cfg_status_margin_type;
reg  [NL-1:0]       cfg_status_usage_model;
reg  [NL*8-1:0]     cfg_status_margin_payload;
wire [NL*16-1:0]    cfg_margin_status;

reg [31:0]     margin_reg_control_status[0:NL-1];

    // Control Fileds
    always @(posedge cdm_clk_g or negedge non_sticky_rst_n) begin : proc_margin_reg_control
        integer ln;
        if(!non_sticky_rst_n) begin
          for (ln=0; ln<NL;ln=ln+1) begin
            cfg_control_receiver_number[3*ln  +: 3]  <= #TP 3'b000;
            cfg_control_margin_type[3*ln +: 3]       <= #TP 3'b111;
            cfg_control_usage_model[ln +: 1]         <= #TP 1'b0;
            cfg_control_margin_payload[8*ln +: 8]    <= #TP 8'h9C;
          end //loop
        end else if(!upstream_port && !rdlh_link_up) begin
          for (ln=0; ln<NL;ln=ln+1) begin
            cfg_control_receiver_number[3*ln  +: 3]  <= #TP 3'b000;
            cfg_control_margin_type[3*ln +: 3]       <= #TP 3'b111;
            cfg_control_usage_model[ln +: 1]         <= #TP 1'b0;
            cfg_control_margin_payload[8*ln +: 8]    <= #TP 8'h9C;
          end //loop

        end else begin
          for (ln=0; ln<NL;ln=ln+1) begin
            cfg_control_receiver_number[3*ln  +: 3]  <= #TP (margin_reg_id[2+ln] && margin_write_pulse[0]) ? lbc_cdm_data[2:0]  : cfg_control_receiver_number[3*ln  +: 3];
            cfg_control_margin_type[3*ln +: 3]       <= #TP (margin_reg_id[2+ln] && margin_write_pulse[0]) ? lbc_cdm_data[5:3]  : cfg_control_margin_type[3*ln +: 3]     ;
            cfg_control_usage_model[ln +: 1]         <= #TP (margin_reg_id[2+ln] && margin_write_pulse[0]) ? lbc_cdm_data[6]    : cfg_control_usage_model[ln +: 1]       ;
            cfg_control_margin_payload[8*ln +: 8]    <= #TP (margin_reg_id[2+ln] && margin_write_pulse[1]) ? lbc_cdm_data[15:8] : cfg_control_margin_payload[8*ln +: 8]  ;
          end //loop
        end
    end // proc_margin_reg_control

    // Status Fileds
    always @(posedge core_clk or negedge non_sticky_rst_n) begin : proc_margin_reg_status
        integer ln;
        if(!non_sticky_rst_n) begin
          for (ln=0; ln<NL;ln=ln+1) begin
            cfg_status_receiver_number[3*ln  +: 3]  <= #TP 3'b000;
            cfg_status_margin_type[3*ln +: 3]       <= #TP 3'b000;
            cfg_status_usage_model[ln +: 1]         <= #TP 1'b0;
            cfg_status_margin_payload[8*ln +: 8]    <= #TP 8'h00;
          end //loop
        end else begin
          for (ln=0; ln<NL;ln=ln+1) begin
            cfg_status_receiver_number[3*ln  +: 3]  <= #TP (smlh_margin_status_valid[ln]) ? smlh_margin_status[16*ln+0 +: 3] : cfg_status_receiver_number[3*ln  +: 3];
            cfg_status_margin_type[3*ln +: 3]       <= #TP (smlh_margin_status_valid[ln]) ? smlh_margin_status[16*ln+3 +: 3] : cfg_status_margin_type[3*ln +: 3]     ;
            cfg_status_usage_model[ln +: 1]         <= #TP (smlh_margin_status_valid[ln]) ? smlh_margin_status[16*ln+6 +: 1] : cfg_status_usage_model[ln +: 1]       ;
            cfg_status_margin_payload[8*ln +: 8]    <= #TP (smlh_margin_status_valid[ln]) ? smlh_margin_status[16*ln+8 +: 8] : cfg_status_margin_payload[8*ln +: 8]  ;
          end //loop
        end
    end // proc_margin_reg_status

generate
for (genvar ln=0; ln<NL;ln=ln+1) begin : proc_margin_control_status_lane
    assign margin_reg_control_status[ln] = {cfg_margin_status[16*ln +: 16],cfg_margin_control[16*ln +: 16]};
    
    assign cfg_margin_control[16*ln +: 16] = {
                   cfg_control_margin_payload[8*ln +: 8],   // [15:8] Margin Payload 
                                                    1'b0,   // [7]    Reserved       
                      cfg_control_usage_model[  ln +: 1],   // [6]    Usage Model    
                      cfg_control_margin_type[3*ln +: 3],   // [5:3]  Margin Type    
                  cfg_control_receiver_number[3*ln +: 3]};  // [2:0]  Receiver Number

    assign cfg_margin_status[16*ln +: 16] = (!upstream_port && !rdlh_link_up) ? 16'd0 : 
                   {cfg_status_margin_payload[8*ln +: 8],   // [15:8] Margin Payload 
                                                   1'b0,   // [7]    Reserved       
                      cfg_status_usage_model[  ln +: 1],   // [6]    Usage Model    
                      cfg_status_margin_type[3*ln +: 3],   // [5:3]  Margin Type    
                  cfg_status_receiver_number[3*ln +: 3]};  // [2:0]  Receiver Number

end // margin_control_status_lane
endgenerate

// =============================================================================
// Register Read Operation
// =============================================================================

always @(*)
begin : read_data_PROC
    unique case (1'b1)
        margin_reg_id[0]  : margin_reg_data = {margin_reg_03, margin_reg_02, margin_reg_01, margin_reg_00};
        margin_reg_id[1]  : margin_reg_data = {margin_reg_07, margin_reg_06, margin_reg_05, margin_reg_04};
        margin_reg_id[2]  : margin_reg_data = margin_reg_control_status[0];
        margin_reg_id[3]  : margin_reg_data = margin_reg_control_status[1];
        margin_reg_id[4]  : margin_reg_data = margin_reg_control_status[2];
        margin_reg_id[5]  : margin_reg_data = margin_reg_control_status[3];
        margin_reg_id[6]  : margin_reg_data = margin_reg_control_status[4];
        margin_reg_id[7]  : margin_reg_data = margin_reg_control_status[5];
        margin_reg_id[8]  : margin_reg_data = margin_reg_control_status[6];
        margin_reg_id[9]  : margin_reg_data = margin_reg_control_status[7];
        default        : margin_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end

endmodule // cdm_margin_reg
