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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_dev3_reg.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Device 3 Extended Capability (DEV3) registers.
// --- This module is instantiated once and shared across all functions.
// --- A Write to the one of the DEV3 registers for a given function, updates
// --- that register across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module cdm_dev3_reg
#(
    parameter INST      = 0,                        // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM  = 0,                        // uniquifying parameter per function
    parameter NDEV3     = `DEV3_SIZE >> 2,          // Number of registers in Device 3 Extended Capability structure   (4)
    parameter TP        = `TP                       // Clock to Q delay (simulator insurance)
)

                   (
// -------------- Inputs ----------------
    input               core_clk,                   // Core Clock
    input               cdm_clk_g,                  // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc   
    input               sticky_rst_n,               // Sticky Reset (that is, asserted for cold reset/PERST# only)
    input               non_sticky_rst_n,           // Non Sticky Reset (that is, asserted on link down)
    input [3:0]         device_type,

    input [31:0]        lbc_cdm_data,               // Write Data
    input               lbc_cdm_dbi,                // DBI Access
    input               dbi_ro_wr_en,               // used to make RW registers look like RO for compliance
    
    input [3:0]         dev3_write_pulse,           // Write Byte Enables
    input [NDEV3-1:0]   dev3_reg_id,                // DEV3 Register ID
    input               cxl_rcrb_enable,
    input [5:0]         int_link_width,
    input               flit_mode_enable,
    input               segment_captured,
    input               cfg_pcie_cap_flit_mode_sup,
    input               smlh_l0p_capable,
// -------------- Outputs --------------
    output reg     cfg_dmwr_req_en,           // Deferrable Memory Write (DMWr) Requester Enable
    output reg [2:0]  cfg_target_link_width,        //Target Link Width
    output reg        cfg_l0p_en,                   // L0p Enable
    output reg        cfg_receiver_l0p_supported,   // Receiver L0p Supported
    output reg        remote_l0p_supported,         // Remote L0p Supported


    output reg [31:0]   dev3_reg_data               // Data read from DEV3 registers 
);


// -------------- Internal Signals --------------

wire int_lbc_cdm_dbi; // Internal DBI Access
assign int_lbc_cdm_dbi = lbc_cdm_dbi & dbi_ro_wr_en;

wire    [7:0]   dev3_reg_03, dev3_reg_02, dev3_reg_01, dev3_reg_00;
wire    [7:0]   dev3_reg_07, dev3_reg_06, dev3_reg_05, dev3_reg_04;
wire    [7:0]   dev3_reg_11, dev3_reg_10, dev3_reg_09, dev3_reg_08;
wire    [7:0]   dev3_reg_15, dev3_reg_14, dev3_reg_13, dev3_reg_12;

// Device Types
wire    end_device;
wire    rc_device;
wire    pcie_sw_up;
wire    pcie_sw_down;
wire    switch_device;
wire    pcie_br_up;
wire    pcie_br_down;
wire    bridge_device;
wire    upstream_port;
assign end_device       = (device_type == `PCIE_EP) | (device_type == `PCIE_EP_LEGACY);
assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_up       = (device_type == `PCIE_SW_UP);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);
assign switch_device    = pcie_sw_up | pcie_sw_down;
assign pcie_br_up       = (device_type == `PCIE_PCIX);
assign pcie_br_down     = (device_type == `PCIX_PCIE);
assign bridge_device    = pcie_br_up | pcie_br_down;
assign upstream_port    = end_device | pcie_br_up | pcie_sw_up;

// -----------------------------------------------------------------------------
// Device 3 Extended Capability Header Register
// -----------------------------------------------------------------------------
// dev3_reg_id      - 0
// PCIE Offset      - `DEV3_PTR
// length           - 4 byte
// Cfig register    - dev3_reg_03, dev3_reg_02, dev3_reg_01, dev3_reg_00
// -----------------------------------------------------------------------------

reg [15:0]  cfg_dev3_id;               // DEV3 Capability ID
reg [3:0]   cfg_dev3_ver;              // DEV3 Capability Version
reg [11:0]  cfg_dev3_next_ptr;         // DEV3 Next Capability Offset

assign {dev3_reg_01, dev3_reg_00}       = cfg_dev3_id;
assign dev3_reg_02[3:0]                 = cfg_dev3_ver;
assign {dev3_reg_03, dev3_reg_02[7:4]}  = cfg_dev3_next_ptr;

// If next pointer is modified by a DBI write, then only the Application
// (via another DBI write) is allowed any further update.
reg cfg_dev3_next_ptr_wr_updated;
always @( posedge core_clk or negedge sticky_rst_n ) begin : cxl_cfg_dev3_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_dev3_next_ptr_wr_updated <= #TP 1'b0;
    end else if (dev3_reg_id[0] & |dev3_write_pulse[3:2] & int_lbc_cdm_dbi) begin
        cfg_dev3_next_ptr_wr_updated <= #TP 1'b1;
    end
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : dev3_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_dev3_id[15:0]       <= #TP `PCIE_DEV3_ECAP_ID;      // Capability ID = 0x002F
        cfg_dev3_ver[3:0]       <= #TP `PCIE_DEV3_ECAP_VER;     // Capability version = 0x1
        cfg_dev3_next_ptr[11:0] <= #TP `DEV3_NEXT_PTR;          // Next Capability Pointer.
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_dev3_id[7:0]        <= #TP (dev3_reg_id[0] & dev3_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7:0] : cfg_dev3_id[7:0];
        cfg_dev3_id[15:8]       <= #TP (dev3_reg_id[0] & dev3_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[15:8] : cfg_dev3_id[15:8];
        cfg_dev3_ver[3:0]       <= #TP (dev3_reg_id[0] & dev3_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19:16] : cfg_dev3_ver[3:0];
        if (dev3_reg_id[0] & |dev3_write_pulse[3:2] & int_lbc_cdm_dbi) begin
          cfg_dev3_next_ptr[3:0]  <= #TP (dev3_reg_id[0] & dev3_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23:20]
                                    : cfg_dev3_next_ptr[3:0];
          cfg_dev3_next_ptr[11:4] <= #TP (dev3_reg_id[0] & dev3_write_pulse[3] & int_lbc_cdm_dbi) ? lbc_cdm_data[31:24]
                                    : cfg_dev3_next_ptr[11:4];
        end else if ((rc_device || pcie_sw_down) && !cfg_dev3_next_ptr_wr_updated) begin
          cfg_dev3_next_ptr[11:0] <= #TP `DM_RP_DEV3_NEXT_PTR;          // Next Capability Pointer.
        end else if (!cfg_dev3_next_ptr_wr_updated) begin
          cfg_dev3_next_ptr[11:0]  <= #TP cxl_rcrb_enable ? `CXL_DEV3_NEXT_PTR :  `DEV3_NEXT_PTR;
        end
    end
end


// -----------------------------------------------------------------------------
// Device Capabilities 3 Register
// -----------------------------------------------------------------------------
// dev3_reg_id     - 1
// PCIE Offset      - `DEV3_PTR + 04h
// length           - 4 byte
// Cfig register    - dev3_reg_07, dev3_reg_06, dev3_reg_05, dev3_reg_04
// -----------------------------------------------------------------------------
wire cfg_dmwr_req_routing_sup;
wire cfg_14bits_tag_comp_support;
wire cfg_14bits_tag_req_support;
reg [2:0] cfg_port_l0p_exit_latency;
reg [2:0] cfg_retimer_l0p_exit_latency;

wire  [2:0] int_retimer_l0p_exit_latency;
assign int_retimer_l0p_exit_latency = cfg_retimer_l0p_exit_latency;



assign {dev3_reg_07, dev3_reg_06, dev3_reg_05} = {22'h0, int_retimer_l0p_exit_latency[2:1]};

assign dev3_reg_04 = {
                      int_retimer_l0p_exit_latency[0],
                      cfg_port_l0p_exit_latency,        // [6:4]  Port L0p Exit Latency
                      cfg_receiver_l0p_supported,       // [3]    Receiver L0p Supported
                      cfg_14bits_tag_req_support,       // [2]    14-Bit Tag Requester Supported
                      cfg_14bits_tag_comp_support,      // [1]    14-Bit Tag Completer Supported 
                      cfg_dmwr_req_routing_sup};        // [0]    DMWr Request Routing Supported

assign cfg_dmwr_req_routing_sup = (rc_device || switch_device) ? `CX_DEF_MEM_WR_ROUTING_EN : 1'b0;
assign cfg_14bits_tag_comp_support = (`CX_14BITS_TAG_VALUE == 1) ? 1'b1 : 1'b0; //ifdef CX_14BITS_TAG was added only for formality flow, as formality doesnot recalculate the cc parameters,for using quick flow. if these changes are moved to dev, this ifdef could have been removed
assign cfg_14bits_tag_req_support  = (`CX_14BITS_TAG_VALUE == 1 && `CX_14BITS_TAG_REQ_VALUE == 1) ? 1'b1 : 1'b0;

always @(posedge core_clk or negedge non_sticky_rst_n) begin
  if(!non_sticky_rst_n)begin
    cfg_receiver_l0p_supported        <= #TP `CX_RECEIVER_L0P_SUPPORTED;
    cfg_port_l0p_exit_latency         <= #TP `CX_PORT_L0P_EXIT_LATENCY;
    cfg_retimer_l0p_exit_latency      <= #TP `CX_RETIMER_L0P_EXIT_LATENCY;
  end
  else begin 
    // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
    // If Flit mode is not supported L0P Support field must be cleared
    if(cfg_pcie_cap_flit_mode_sup && dev3_reg_id[1]) begin
      cfg_receiver_l0p_supported        <= #TP (dev3_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[3] : cfg_receiver_l0p_supported;
    end else if(!cfg_pcie_cap_flit_mode_sup) begin
      cfg_receiver_l0p_supported        <= #TP '0;
    end

    // If L0P is not supported exit latency fields must be cleared
    if(cfg_receiver_l0p_supported && dev3_reg_id[1]) begin
      cfg_port_l0p_exit_latency         <= #TP (dev3_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[6:4] : cfg_port_l0p_exit_latency;
      cfg_retimer_l0p_exit_latency[0]   <= #TP (dev3_write_pulse[0] & int_lbc_cdm_dbi) ? lbc_cdm_data[7] : cfg_retimer_l0p_exit_latency[0];
      cfg_retimer_l0p_exit_latency[2:1] <= #TP (dev3_write_pulse[1] & int_lbc_cdm_dbi) ? lbc_cdm_data[9:8] : cfg_retimer_l0p_exit_latency[2:1];
    end else if(!cfg_receiver_l0p_supported) begin
      cfg_port_l0p_exit_latency         <= #TP '0;
      cfg_retimer_l0p_exit_latency[0]   <= #TP '0;
      cfg_retimer_l0p_exit_latency[2:1] <= #TP '0;
    end
  end
end

// -----------------------------------------------------------------------------
// Device Control 3 Register
// -----------------------------------------------------------------------------
// dev3_reg_id     - 2
// PCIE Offset      - `DEV3_PTR + 08h
// length           - 4 byte
// Cfig register    - dev3_reg_11, dev3_reg_10, dev3_reg_09, dev3_reg_08 
// -----------------------------------------------------------------------------
reg cfg_dmwr_req_egress_block;
logic [2:0] init_link_width_3bit;
logic [2:0] init_link_width_3bit_int;
assign init_link_width_3bit = init_link_width_3bit_int;

always_comb 
begin
    init_link_width_3bit_int = 3'h0;
    casez(int_link_width)
        6'b00_0001 :
    init_link_width_3bit_int = 3'h0;
        6'b00_0010 :
    init_link_width_3bit_int = 3'h1;
        6'b00_0100 :
    init_link_width_3bit_int = 3'h2;
        6'b00_1000 :
    init_link_width_3bit_int = 3'h3;
        6'b01_0000 :
    init_link_width_3bit_int = 3'h4;
        6'b10_0000 :
    init_link_width_3bit_int = 3'h5;
    endcase
end
assign {dev3_reg_11, dev3_reg_10} = 16'h0; // [31:16] Reserved

assign dev3_reg_09 = 8'h0;  

assign dev3_reg_08 = {
                      1'b0,
                      cfg_target_link_width,            // [6:4] Target Link Width
                      cfg_l0p_en,                       // [3]    L0p Enable
                       1'b0,
                       cfg_dmwr_req_egress_block,       // [1]    DMWr Egress Blocking
                       cfg_dmwr_req_en};                // [0]    DMWr Requester Enable

always @(posedge core_clk or negedge non_sticky_rst_n) begin : dev_ctrl3_proc
    if (!non_sticky_rst_n) begin
        cfg_dmwr_req_en             <= #TP 0;
        cfg_dmwr_req_egress_block   <= #TP 0;
        cfg_target_link_width       <= #TP 3'b111;
        cfg_l0p_en                  <= #TP 1'b1;
        cfg_target_link_width       <= #TP 3'b111;
        cfg_l0p_en                  <= #TP 1'b1;
    end else begin 
         // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_dmwr_req_en             <= #TP (dev3_reg_id[2] & dev3_write_pulse[0] & (end_device | rc_device) & (`CX_DEF_MEM_WR_REQ_EN==1)) ? lbc_cdm_data[0] : cfg_dmwr_req_en;
        cfg_dmwr_req_egress_block   <= #TP (dev3_reg_id[2] & dev3_write_pulse[0] & cfg_dmwr_req_routing_sup) ? lbc_cdm_data[1] : cfg_dmwr_req_egress_block;
          cfg_l0p_en                   <= #TP (dev3_reg_id[2] & dev3_write_pulse[0])? lbc_cdm_data[3] : cfg_l0p_en;
          cfg_target_link_width        <= #TP (!cfg_pcie_cap_flit_mode_sup)? 3'b000 : (dev3_reg_id[2] & dev3_write_pulse[0])? lbc_cdm_data[6:4] : cfg_target_link_width;
    end
end

// -----------------------------------------------------------------------------
// Device Status 3 Register
// -----------------------------------------------------------------------------
// dev3_reg_id     - 3
// PCIE Offset      - `DEV3_PTR + 0Ch
// length           - 4 byte
// Cfig register    - dev3_reg_15, dev3_reg_14, dev3_reg_13, dev3_reg_12
// -----------------------------------------------------------------------------
logic segment_captured_int;
assign segment_captured_int = segment_captured;



always@(posedge core_clk or negedge non_sticky_rst_n) begin
  if(!non_sticky_rst_n)begin
    remote_l0p_supported <= #TP 1'b0;
  end
  else begin
    remote_l0p_supported <= #TP smlh_l0p_capable;
  end
end

assign {dev3_reg_15, dev3_reg_14, dev3_reg_13} = 24'h0; // [31:8] Reserved
assign dev3_reg_12 = {3'h0, remote_l0p_supported, segment_captured_int, init_link_width_3bit};

// =============================================================================
// Register Read Operation
// =============================================================================

always @(*)
begin : read_data_PROC
    unique case (1'b1)
        dev3_reg_id[0]  : dev3_reg_data = {dev3_reg_03, dev3_reg_02, dev3_reg_01, dev3_reg_00};
        dev3_reg_id[1]  : dev3_reg_data = {dev3_reg_07, dev3_reg_06, dev3_reg_05, dev3_reg_04};
        dev3_reg_id[2]  : dev3_reg_data = {dev3_reg_11, dev3_reg_10, dev3_reg_09, dev3_reg_08};
        dev3_reg_id[3]  : dev3_reg_data = {dev3_reg_15, dev3_reg_14, dev3_reg_13, dev3_reg_12};
        default         : dev3_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end

endmodule // cdm_dev3_reg 
