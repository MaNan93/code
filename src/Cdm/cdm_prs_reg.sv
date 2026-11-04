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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_prs_reg.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Page Request Services Extended Capability (PRS) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_prs_reg
#(
    parameter INST          = 0,                                   // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM      = 0,                                    // uniquifying parameter per function
    parameter TP            = `TP                                  // Clock to Q delay (simulator insurance)
)

                   (
    // -------------- Inputs ----------------
    input                             core_clk,                    // Core Clock
    input                             non_sticky_rst_n,            // Non-Sticky Reset 
    input                             sticky_rst_n,                // Sticky Reset (that is, asserted for cold reset only)
    input                             cdm_clk_g,                   // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc


    input  [31:0]                     lbc_cdm_data,                // Write Data 
    input                             lbc_cdm_dbi,                 // DBI Access

    input  [3:0]                      prs_write_pulse,             // Write Byte Enable
    input  [3:0]                      prs_reg_id,                  // PRS Register ID
    input                             dbi_ro_wr_en,                // used to make RW registers look like RO for compliance

    input                             prs_res_failure,             // PRS Response Failure from Application
    input                             prs_uprgi,                   // PRS Response with Unexpected PRG Index 
    input                             prs_stopped,                 // Requests for additional pages has stopped 
    input                             cxl_rcrb_enable,             // Indicates that the CXL 1.1 Link is up for USP supporting RCRB

    // -------------- Outputs --------------
    
    output reg [31:0]                 prs_reg_data,                 // PRS Register Read Data
    
    output reg                        cfg_prs_enable,
    output reg                        cfg_prs_reset,
    output reg                        cfg_prs_stopped,
    output reg                        cfg_prs_uprgi,
    output reg                        cfg_prs_response_failure,
    output reg [31:0]                 cfg_prs_outstanding_allocation   // PRS Register Outstanding Allocation
);

// for PRS all VF's associated with a PF shall report the same values
localparam INT_PRS_NEXT_PTR = `PRS_NEXT_PTR;

// -------------- Internal Signals --------------
reg     [31:0]       cfg_prs_outstanding_capacity;                   // Outstanding capacity information

reg     [3:0]        cfg_prs_ver;                                    // Capability Version
reg     [15:0]       cfg_prs_id;                                     // Capability ID
reg     [11:0]       cfg_prs_next_ptr;                               // Next Capability Offset

reg                  prs_reset;                                     // Reset field inforrmation
reg                  prs_reset_d;                                   // Delayed reset field inforrmation

reg                  cfg_prs_pasid;                                 // PASID TLP Prefix Requirement inforrmation

wire    [7:0]        prs_reg_03, prs_reg_02, prs_reg_01, prs_reg_00;
wire    [7:0]        prs_reg_07, prs_reg_06, prs_reg_05, prs_reg_04;
wire    [7:0]        prs_reg_11, prs_reg_10, prs_reg_09, prs_reg_08;    
wire    [7:0]        prs_reg_15, prs_reg_14, prs_reg_13, prs_reg_12;    

// -----------------------------------------------------------------------------
// PRS Extended Capability Header Register
// -----------------------------------------------------------------------------
// PRS_reg_id       - 0
// PCIE Offset      - `PRS_PTR
// length           - 4 byte
// Cfig register    - prs_reg_03, prs_reg_02, prs_reg_01, prs_reg_00
// Read Only from the Wire.
// -----------------------------------------------------------------------------



reg prs_next_ptr_updated;
always @( posedge core_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin
        cfg_prs_next_ptr[11:0] <= #TP INT_PRS_NEXT_PTR;
        prs_next_ptr_updated   <= #TP 1'b0;
    end else begin
        if (prs_reg_id[0] & |prs_write_pulse[3:2] & lbc_cdm_dbi & dbi_ro_wr_en) begin
        prs_next_ptr_updated   <= #TP 1'b1;
        // Read-Only registers, but writable through DBI
        cfg_prs_next_ptr[3:0]  <= #TP (prs_reg_id[0] & prs_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[23:20]
                                    : cfg_prs_next_ptr[3:0];
        cfg_prs_next_ptr[11:4] <= #TP (prs_reg_id[0] & prs_write_pulse[3] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[31:24] 
                                    : cfg_prs_next_ptr[11:4];
        end
        else if (!prs_next_ptr_updated) begin
           cfg_prs_next_ptr[11:0] <= #TP (cxl_rcrb_enable) ? `CXL_PRS_NEXT_PTR : INT_PRS_NEXT_PTR;
        end

    end
end 


always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : prs_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_prs_id[15:0]       <= #TP `PCIE_PRS_ECAP_ID;    
        cfg_prs_ver[3:0]       <= #TP `PCIE_PRS_ECAP_VER;  
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_prs_id[7:0]        <= #TP (prs_reg_id[0] & prs_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0]    : cfg_prs_id[7:0];            //RO
        cfg_prs_id[15:8]       <= #TP (prs_reg_id[0] & prs_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8]   : cfg_prs_id[15:8];           //RO
        cfg_prs_ver[3:0]       <= #TP (prs_reg_id[0] & prs_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16]  : cfg_prs_ver[3:0];           //RO
    end
end //always prs_cap_hdr_PROC

assign {prs_reg_01, prs_reg_00}      = cfg_prs_id;
assign  prs_reg_02[3:0]              = cfg_prs_ver;
assign {prs_reg_03, prs_reg_02[7:4]} = cfg_prs_next_ptr;

// -----------------------------------------------------------------------------
// PRS Control Register
// -----------------------------------------------------------------------------
// PRS_reg_id       - 1
// PCIE Offset      - `PRS_PTR + 04h
// length           - 2 byte
// Cfig register    - prs_reg_05, prs_reg_04
// Read Write
// -----------------------------------------------------------------------------

localparam PRS_ENABLE = 1'b0;
localparam PRS_RESET  = 1'b0;

always @( posedge cdm_clk_g or negedge non_sticky_rst_n ) begin : prs_reg1_PROC
  if ( !non_sticky_rst_n ) begin
      prs_reset                   <= #TP PRS_RESET; 
      cfg_prs_enable              <= #TP PRS_ENABLE;


    end else begin
      prs_reset                   <= #TP ((!cfg_prs_enable || !lbc_cdm_data[0]) & prs_reg_id[1] & prs_write_pulse[0]) ? lbc_cdm_data[1]    : cfg_prs_reset;       //RW

      cfg_prs_enable              <= #TP (prs_reg_id[1] & prs_write_pulse[0]) ? lbc_cdm_data[0]  : cfg_prs_enable;                          //RW
    end
end //always prs_reg1_PROC

always @( posedge cdm_clk_g or negedge non_sticky_rst_n ) begin : prs_reset_PROC
  if ( !non_sticky_rst_n ) 
    begin
        prs_reset_d               <= #TP 1'b0;
    end else begin
        prs_reset_d               <= #TP prs_reset;
    end
end //always prs_reset_PROC

assign cfg_prs_reset        = ~prs_reset_d  & prs_reset;

assign prs_reg_05 = 8'b0;
assign prs_reg_04 = {7'b0, 
                     cfg_prs_enable
                    };

//
// Pulse generation for the transition from Not Enabled to Enabled of the PRS feature
//

reg    cfg_prs_enable_d;
wire   cfg_prs_enable_assert;
wire   cfg_prs_enable_deassert;

always @( posedge core_clk or negedge non_sticky_rst_n )
begin
    if (!non_sticky_rst_n) begin
        cfg_prs_enable_d       <= #TP 0;
    end
    else begin
        cfg_prs_enable_d       <= #TP cfg_prs_enable;
    end
end

// Rising edge detection
assign cfg_prs_enable_assert       = ~cfg_prs_enable_d   & cfg_prs_enable;

// Falling edge detection
assign cfg_prs_enable_deassert     = cfg_prs_enable_d    & ~cfg_prs_enable;

// -----------------------------------------------------------------------------
// PRS Status Register
// -----------------------------------------------------------------------------
// prs_reg_id       - 1
// PCIE Offset      - `PRS_PTR + 06h
// length           - 2 byte
// Cfig register    - prs_reg_07, prs_reg_06
// RO; RW1C
// -----------------------------------------------------------------------------

localparam PRS_RESPONSE_FAILURE = 1'b0;
localparam PRS_UPRGI            = 1'b0;
localparam PRS_STOPPED          = 1'b1;

always @( posedge core_clk or negedge non_sticky_rst_n) begin : prs_reg2_PROC
  if ( !non_sticky_rst_n ) begin
      cfg_prs_stopped             <= #TP PRS_STOPPED;
      cfg_prs_uprgi               <= #TP PRS_UPRGI;
      cfg_prs_response_failure    <= #TP PRS_RESPONSE_FAILURE; 


// PRS Spec states that when the Page Request Interface is transitioned from not-Enabled to Enabled, 
// its status flags (Stopped, Response Failure, and Unexpected Response flags) are cleared
    end else if(cfg_prs_enable_assert) begin
      cfg_prs_stopped             <= #TP 1'b0;      // clear value
      cfg_prs_uprgi               <= #TP PRS_UPRGI;
      cfg_prs_response_failure    <= #TP PRS_RESPONSE_FAILURE; 

// prs_stopped behaves as a pulse input. When prs_stopped is asserted, it takes priority. Otherwise a DBI write can be used to set the stopped bit. 
// When the cfg_prs_enable bit is cleared, cfg_prs_stopped is cleared since the Spec states that "When the Enable field is Cleared, after having been
// previously Set, the interface transitions to the stopping state and Clears this field".
    end else begin
      cfg_prs_stopped             <= #TP (prs_stopped) ?  1'b1 : (prs_reg_id[1] & prs_write_pulse[3] & lbc_cdm_dbi ) ? lbc_cdm_data[24] : cfg_prs_enable_deassert ?  1'b0 : cfg_prs_stopped;   //RO
      cfg_prs_uprgi               <= #TP (prs_uprgi) ?  1'b1 : (prs_reg_id[1] & prs_write_pulse[2] &  lbc_cdm_data[17]) ? 1'b0                         : cfg_prs_uprgi;             //RW1C
      cfg_prs_response_failure    <= #TP (prs_res_failure)   ?  1'b1 : (prs_reg_id[1] & prs_write_pulse[2] & lbc_cdm_data[16]) ? 1'b0                  : cfg_prs_response_failure;  //RW1C
    end
end //always prs_reg2_PROC

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : prs_reg2_PASID_PROC
    if ( !sticky_rst_n ) begin
        cfg_prs_pasid             <= #TP `CX_PRG_PASID_REQUIRED;    
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_prs_pasid            <= #TP (prs_reg_id[1] & prs_write_pulse[3] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[31]    : cfg_prs_pasid;            //RO
    end
end  //always prs_reg2_PASID_PROC

assign prs_reg_07 = {cfg_prs_pasid,
                     6'b0, 
                     cfg_prs_stopped
                    };

assign prs_reg_06 = {6'b0, 
                     cfg_prs_uprgi, 
                     cfg_prs_response_failure
                    };


// -----------------------------------------------------------------------------
// PRS Outstanding Page Request Capacity Register
// -----------------------------------------------------------------------------
// prs_reg_id       - 2
// PCIE Offset      - `PRS_PTR + 08h
// length           - 4 byte
// Cfig register    - prs_reg_11, prs_reg_10, prs_reg_09, prs_reg_08
// Read Only.
// -----------------------------------------------------------------------------

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : prs_reg3_PROC
  if ( !sticky_rst_n ) begin
      cfg_prs_outstanding_capacity    <= #TP `CX_PRS_OUTSTANDING_CAPACITY_VALUE; 

    end else begin
    // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      cfg_prs_outstanding_capacity[7:0]       <= #TP (prs_reg_id[2] & prs_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0]      : cfg_prs_outstanding_capacity[7:0];       //RO
      cfg_prs_outstanding_capacity[15:8]      <= #TP (prs_reg_id[2] & prs_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8]     : cfg_prs_outstanding_capacity[15:8];      //RO
      cfg_prs_outstanding_capacity[23:16]     <= #TP (prs_reg_id[2] & prs_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[23:16]    : cfg_prs_outstanding_capacity[23:16];     //RO
      cfg_prs_outstanding_capacity[31:24]     <= #TP (prs_reg_id[2] & prs_write_pulse[3] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[31:24]    : cfg_prs_outstanding_capacity[31:24];     //RO
    end
end //always prs_reg3_PROC

assign {prs_reg_11, prs_reg_10, prs_reg_09, prs_reg_08} = cfg_prs_outstanding_capacity;

// -----------------------------------------------------------------------------
// PRS Outstanding Page Request Allocation Register
// -----------------------------------------------------------------------------
// prs_reg_id       - 3
// PCIE Offset      - `PRS_PTR + 0Ch
// length           - 4 byte
// Cfig register    - prs_reg_15, prs_reg_14, prs_reg_13, prs_reg_12
// Read Write.
// -----------------------------------------------------------------------------

localparam PRS_OUTSTANDING_ALLOCATION = 32'b0;

always @( posedge cdm_clk_g or negedge non_sticky_rst_n ) begin : prs_reg4_PROC
  if ( !non_sticky_rst_n ) begin
      cfg_prs_outstanding_allocation    <= #TP PRS_OUTSTANDING_ALLOCATION; 


    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      cfg_prs_outstanding_allocation[7:0]      <= #TP (prs_reg_id[3] & prs_write_pulse[0]) ? lbc_cdm_data[7:0]      : cfg_prs_outstanding_allocation[7:0];         //RW
      cfg_prs_outstanding_allocation[15:8]     <= #TP (prs_reg_id[3] & prs_write_pulse[1]) ? lbc_cdm_data[15:8]     : cfg_prs_outstanding_allocation[15:8];        //RW 
      cfg_prs_outstanding_allocation[23:16]    <= #TP (prs_reg_id[3] & prs_write_pulse[2]) ? lbc_cdm_data[23:16]    : cfg_prs_outstanding_allocation[23:16];       //RW 
      cfg_prs_outstanding_allocation[31:24]    <= #TP (prs_reg_id[3] & prs_write_pulse[3]) ? lbc_cdm_data[31:24]    : cfg_prs_outstanding_allocation[31:24];       //RW
    end
end //always prs_reg4_PROC

assign {prs_reg_15, prs_reg_14, prs_reg_13, prs_reg_12} = cfg_prs_outstanding_allocation;


// =============================================================================
// Register Read Operation
// =============================================================================


always @( * ) begin : read_data_PROC   
    prs_reg_data[31:0] = 0;

  // read Header register in cdm_ecfg_reg.v

    if (prs_reg_id[0])   begin
        prs_reg_data = {prs_reg_03, prs_reg_02, prs_reg_01, prs_reg_00};  // read PRS Header register
    end else if (prs_reg_id[1]) begin
        prs_reg_data = {prs_reg_07, prs_reg_06, prs_reg_05, prs_reg_04};  // read PRS Status and Control registers
    end else if (prs_reg_id[2]) begin
        prs_reg_data = {prs_reg_11, prs_reg_10, prs_reg_09, prs_reg_08};  // read Outstanding Page Request Capacity register
    end else begin
        prs_reg_data = {prs_reg_15, prs_reg_14, prs_reg_13, prs_reg_12};  // read Outstanding Page Request Allocation register
    end

end //always read_data_PROC


endmodule //cdm_prs_reg 
