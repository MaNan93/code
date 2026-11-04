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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_ptm_reg.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Precision Time Measurement Extended Capability (PTM) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_ptm_reg
#(
    parameter INST          = 0,                                    // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM      = 0                                    // uniquifying parameter per function
)

                   (
    // -------------- Inputs ----------------
    input                             core_clk,                    // Core Clock
    input                             non_sticky_rst_n,            // Non-Sticky Reset 
    input                             sticky_rst_n,                // Sticky Reset (that is, asserted for cold reset only)
    input                             cdm_clk_g,                    // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
    input  [3:0]                      device_type,                 // Device type



    input  [31:0]                     lbc_cdm_data,                // Write Data 
    input                             lbc_cdm_dbi,                 // DBI Access

    input  [3:0]                      ptm_write_pulse,              // Write Byte Enable
    input  [2:0]                      ptm_reg_id,                  // PTM Register ID
    input                             dbi_ro_wr_en,                 // used to make RW registers look like RO for compliance

    // -------------- Outputs --------------
    output reg                        cfg_ptm_enable,
    output                            cfg_ptm_responder_capable,
    output reg                        cfg_ptm_root_select,
    output reg [31:0]                 ptm_reg_data                 // PTM Register Read Data
);

localparam TP = `TP;

// for PTM All VF's associated with a PF shall report the same values
// Next Pointer depends on whether this is a physical or virtual function:
localparam INT_PTM_NEXT_PTR = `PTM_NEXT_PTR;

// -------------- Internal Signals --------------
reg                  cfg_ptm_root_capable_ep;
reg                  cfg_ptm_responder_capable_ep;
reg                  cfg_ptm_requester_capable_ep;
reg                  cfg_ptm_root_capable_rc;
reg                  cfg_ptm_responder_capable_rc;
reg                  cfg_ptm_requester_capable_rc;
wire                 cfg_ptm_requester_capable;                             
wire                 cfg_ptm_root_capable;
reg                  cfg_eptm_capable;                                                          
reg     [7:0]        cfg_ptm_effective_gran;  
reg     [7:0]        cfg_ptm_local_clk_gran;

wire    [7:0]        ptm_reg_07, ptm_reg_06, ptm_reg_05, ptm_reg_04;
wire    [7:0]        ptm_reg_11, ptm_reg_10, ptm_reg_09, ptm_reg_08;    

wire                 end_device;


assign end_device = (device_type == `PCIE_EP);


// -----------------------------------------------------------------------------
// PTM Extended Capability Header Register
// -----------------------------------------------------------------------------
// ptm_reg_id       - 0
// PCIE Offset      - `PTM_PTR
// length           - 4 byte
// Cfig register    - ptm_reg_03, ptm_reg_02, ptm_reg_01, ptm_reg_00
// Read Only from the Wire.
// -----------------------------------------------------------------------------

//register in cdm_ecfg_reg.v


// -----------------------------------------------------------------------------
// PTM Capabilities Register
// -----------------------------------------------------------------------------
// ptm_reg_id       - 1
// PCIE Offset      - `PTM_PTR + 04h
// length           - 4 byte
// Cfig register    - ptm_reg_07, ptm_reg_06, ptm_reg_05, ptm_reg_04
// Read Only from the Wire.
// -----------------------------------------------------------------------------
localparam PTM_TIME_SOURCE = `CX_PTM_ROOT_CAPABLE;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : ptm_reg1_PROC
    if ( !sticky_rst_n ) begin
      cfg_ptm_local_clk_gran[7:0]     <= #TP `CX_PTM_LOCAL_CLK_GRAN;
      cfg_ptm_root_capable_ep         <= #TP 1'b0;
      cfg_ptm_responder_capable_ep    <= #TP 1'b0;  
      cfg_ptm_requester_capable_ep    <= #TP 1'b1;
      cfg_ptm_root_capable_rc         <= #TP 1'b1;
      cfg_ptm_responder_capable_rc    <= #TP 1'b1;  
      cfg_ptm_requester_capable_rc    <= #TP 1'b0;
      cfg_eptm_capable                <= #TP `CX_EPTM_CAPABLE_VALUE;
  
    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      cfg_ptm_local_clk_gran[7:0]     <= #TP cfg_ptm_root_select ? `CX_PTM_LOCAL_CLK_GRAN : 
                                         (ptm_reg_id[1] & ptm_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : 
                                         cfg_ptm_local_clk_gran[7:0];
      cfg_eptm_capable                <= #TP (ptm_reg_id[1] & ptm_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[3] : cfg_eptm_capable;
      cfg_ptm_root_capable_ep         <= #TP (ptm_reg_id[1] & ptm_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[2] : cfg_ptm_root_capable_ep; 
      cfg_ptm_responder_capable_ep    <= #TP (ptm_reg_id[1] & ptm_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? (lbc_cdm_data[2] || lbc_cdm_data[1]) : cfg_ptm_responder_capable_ep;
      cfg_ptm_requester_capable_ep    <= #TP (ptm_reg_id[1] & ptm_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[0] : cfg_ptm_requester_capable_ep;
      cfg_ptm_root_capable_rc         <= #TP (ptm_reg_id[1] & ptm_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[2] : cfg_ptm_root_capable_rc; 
      cfg_ptm_responder_capable_rc    <= #TP (ptm_reg_id[1] & ptm_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? (lbc_cdm_data[2] || lbc_cdm_data[1]) : cfg_ptm_responder_capable_rc;
      cfg_ptm_requester_capable_rc    <= #TP (ptm_reg_id[1] & ptm_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[0] : cfg_ptm_requester_capable_rc;
    end
end  //always ptm_reg1_PROC

assign ptm_reg_07 = 8'b0;
assign ptm_reg_06 = 8'b0;       
assign ptm_reg_05 = PTM_TIME_SOURCE ? cfg_ptm_local_clk_gran[7:0] : 8'b0;

//assign cfg_ptm_responder_capable = `ifndef CX_IS_DM cfg_ptm_responder_capable_int `else end_device ? cfg_ptm_responder_capable_ep : cfg_ptm_responder_capable_rc `endif ;
assign cfg_ptm_responder_capable = end_device ? cfg_ptm_responder_capable_ep : cfg_ptm_responder_capable_rc;
assign cfg_ptm_requester_capable = end_device ? cfg_ptm_requester_capable_ep : cfg_ptm_requester_capable_rc;
assign cfg_ptm_root_capable      = end_device ? cfg_ptm_root_capable_ep : cfg_ptm_root_capable_rc;

assign ptm_reg_04 = {4'b0, 
                     cfg_eptm_capable,
                     cfg_ptm_root_capable, 
                     cfg_ptm_responder_capable, 
                     cfg_ptm_requester_capable                  
                     };



// -----------------------------------------------------------------------------
// PTM Register 2
// -----------------------------------------------------------------------------
// ptm_reg_id       - 2
// PCIE Offset      - `PTM_PTR + 08h
// length           - 4 byte
// Cfig register    - ptm_reg_11, ptm_reg_10, ptm_reg_09, ptm_reg_08
// Read Only from the Wire.
// -----------------------------------------------------------------------------
localparam PTM_ENABLE = 1'b0;
localparam PTM_ROOT_SELECT = 1'b0;
localparam PTM_EFFECTIVE_GRAN = 8'b0;

always @( posedge cdm_clk_g or negedge non_sticky_rst_n ) begin : ptm_reg2_PROC
  if ( !non_sticky_rst_n ) begin
      cfg_ptm_effective_gran[7:0] <= #TP PTM_EFFECTIVE_GRAN;
      cfg_ptm_enable              <= #TP PTM_ENABLE;


    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      cfg_ptm_effective_gran[7:0] <= #TP (ptm_reg_id[2] & ptm_write_pulse[1]) ? lbc_cdm_data[15:8] : cfg_ptm_effective_gran[7:0];

      cfg_ptm_enable              <= #TP (ptm_reg_id[2] & ptm_write_pulse[0]) ? lbc_cdm_data[0]    : cfg_ptm_enable; 
    end
end //always ptm_reg2_PROC

always @( posedge core_clk or negedge non_sticky_rst_n ) begin 
  if ( !non_sticky_rst_n ) begin
      cfg_ptm_root_select         <= #TP PTM_ROOT_SELECT; 


    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      cfg_ptm_root_select         <= #TP !cfg_ptm_root_capable ? 1'b0 : 
                                         (ptm_reg_id[2] & ptm_write_pulse[0]) ? lbc_cdm_data[1]    : cfg_ptm_root_select; 
   
    end
end 


assign ptm_reg_11 = 8'b0;
assign ptm_reg_10 = 8'b0;
assign ptm_reg_09 = cfg_ptm_requester_capable ? cfg_ptm_effective_gran[7:0] : 8'b0;
assign ptm_reg_08 = {6'b0, 
                     cfg_ptm_root_select, 
                     cfg_ptm_enable
                    };



// =============================================================================
// Register Read Operation
// =============================================================================


always @( * ) begin : read_data_PROC   
    ptm_reg_data[31:0] = 0;

  // read Header register in cdm_ecfg_reg.v

    if (ptm_reg_id[1])   begin
        ptm_reg_data = {ptm_reg_07, ptm_reg_06, ptm_reg_05, ptm_reg_04};  // read PTM Capability register
    end else begin
        ptm_reg_data = {ptm_reg_11, ptm_reg_10, ptm_reg_09, ptm_reg_08};  // read PTM Control register
    end
end //always read_data_PROC


endmodule //cdm_ptm_reg 
