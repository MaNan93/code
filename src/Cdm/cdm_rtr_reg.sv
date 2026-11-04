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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_rtr_reg.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Readiness Time Reporting Extended Capability (RTR) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_rtr_reg
#(
    parameter INST          = 0,                                    // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM      = 0,                                    // uniquifying parameter per function
    parameter VF_IMPL       = 0,                                    // 0: PF impl. 1: VF impl.
    parameter NRTR          = 3,                                    // Max possible number of registers in RTR Extended Capability Structure (3)
    parameter TP            = `TP                                   // Clock to Q delay (simulator insurance)
)

                   (
    // -------------- Inputs ----------------
    input                             core_clk,                    // Core Clock

    input                             sticky_rst_n,                // Sticky Reset (that is, asserted for cold reset only)
    input [3:0]                       device_type,
    input                             cdm_clk_g,                    // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc

    input  [31:0]                     lbc_cdm_data,                // Write Data 
    input                             lbc_cdm_dbi,                 // DBI Access
    input                             lbc_cdm_dbi2,

    input  [3:0]                      rtr_write_pulse,             // Write Byte Enable
    input  [NRTR-1:0]                 rtr_reg_id,                  // RTR Register ID
    input                             dbi_ro_wr_en,                // used to make RW registers look like RO for compliance
    input                             cxl_rcrb_enable,             // Indicates that the CXL 1.1 Link is up for USP supporting RCRB

    // -------------- Outputs --------------

    output reg [31:0]                 rtr_reg_data                 // RTR Register Read Data
);

// for RTR All VF's associated with a PF shall report the same values
// Next Pointer depends on whether this is a physical or virtual function:
localparam INT_RTR_NEXT_PTR = VF_IMPL ? `VF_RTR_NEXT_PTR : `RTR_NEXT_PTR;

// -------------- Internal Signals --------------
reg     [15:0]       cfg_rtr_id;                                     // Capability ID
reg     [3:0]        cfg_rtr_ver;                                    // Capability Version
reg     [11:0]       cfg_rtr_next_ptr;                               // Next Capability Offset

reg                  cfg_rtr_valid;
reg     [11:0]       cfg_dl_up_time;                              
reg     [11:0]       cfg_reset_time;                              
reg     [11:0]       cfg_d3d0_time;                               
reg     [11:0]       cfg_flr_time;

reg                  cfg_rtr_valid2;                         
reg     [11:0]       cfg_reset_time2;                              
reg     [11:0]       cfg_d3d0_time2;                               
reg     [11:0]       cfg_flr_time2;

wire    [7:0]        rtr_reg_03, rtr_reg_02, rtr_reg_01, rtr_reg_00;
wire    [7:0]        rtr_reg_07, rtr_reg_06, rtr_reg_05, rtr_reg_04;
wire    [7:0]        rtr_reg_11, rtr_reg_10, rtr_reg_09, rtr_reg_08;

wire rc_device;
wire pcie_sw_down;
wire    [36:0]                cfg_rtr_req_cap_reg2;

assign cfg_rtr_req_cap_reg2 = {cfg_rtr_valid2, cfg_reset_time2, cfg_d3d0_time2, cfg_flr_time2};  

assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);

// -----------------------------------------------------------------------------
// RTR Extended Capability Header Register
// -----------------------------------------------------------------------------
// rtr_reg_id       - 0
// PCIE Offset      - `RTR_PTR
// length           - 4 byte
// Cfig register    - rtr_reg_03, rtr_reg_02, rtr_reg_01, rtr_reg_00
// Read Only from the Wire.
// -----------------------------------------------------------------------------

reg         rtr_next_ptr_wr_updated;

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_rtr_id[15:0]       <= #TP `PCIE_RTR_ECAP_ID;
        cfg_rtr_ver[3:0]       <= #TP `PCIE_RTR_ECAP_VER;

    end else begin
        // Read-Only registers, but writable through DBI
        cfg_rtr_id[7:0]        <= #TP (rtr_reg_id[0] & rtr_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0]   : cfg_rtr_id[7:0];
        cfg_rtr_id[15:8]       <= #TP (rtr_reg_id[0] & rtr_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8]  : cfg_rtr_id[15:8];
        cfg_rtr_ver[3:0]       <= #TP (rtr_reg_id[0] & rtr_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_rtr_ver[3:0];

    end
end //always cap_hdr_PROC




always @( posedge core_clk or negedge sticky_rst_n ) begin 
    if ( !sticky_rst_n ) begin

        cfg_rtr_next_ptr[11:0] <= #TP INT_RTR_NEXT_PTR;

    end else if(rtr_reg_id[0] & lbc_cdm_dbi & dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_rtr_next_ptr[3:0]  <= #TP (rtr_write_pulse[2]) ? lbc_cdm_data[23:20] : cfg_rtr_next_ptr[3:0];

        cfg_rtr_next_ptr[11:4] <= #TP (rtr_write_pulse[3]) ? lbc_cdm_data[31:24] : cfg_rtr_next_ptr[11:4];

    end else if ((rc_device || pcie_sw_down) && !rtr_next_ptr_wr_updated) begin
        cfg_rtr_next_ptr[11:0]  <= #TP `DM_RP_RTR_NEXT_PTR ;

    end else if (!rtr_next_ptr_wr_updated) begin
        cfg_rtr_next_ptr[11:0]  <= #TP (cxl_rcrb_enable && (VF_IMPL == 0)) ? `CXL_RTR_NEXT_PTR : INT_RTR_NEXT_PTR ;                // Device type could change      
    end
end 


always @( posedge core_clk or negedge sticky_rst_n ) begin : rtr_cap_hdr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        rtr_next_ptr_wr_updated <= #TP 1'b0;

    end else if (rtr_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |rtr_write_pulse[3:2]) begin
        rtr_next_ptr_wr_updated <= #TP 1'b1;

    end
end

assign {rtr_reg_01, rtr_reg_00}      = cfg_rtr_id;
assign rtr_reg_02[3:0]               = cfg_rtr_ver;
assign {rtr_reg_03, rtr_reg_02[7:4]} = cfg_rtr_next_ptr;



// -----------------------------------------------------------------------------
// RTR Capabilities Register
// -----------------------------------------------------------------------------
// rtr_reg_id       - 1
// PCIE Offset      - `RTR_PTR + 04h
// length           - 4 byte
// Cfig register    - rtr_reg_07, rtr_reg_06, rtr_reg_05, rtr_reg_04
// Read Only from the Wire.
// -----------------------------------------------------------------------------

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : reg1_PROC
    if ( !sticky_rst_n ) begin
      cfg_rtr_valid         <= #TP `CX_RN_RTR_VALID;
      cfg_dl_up_time[11:0]  <= #TP `CX_RN_RTR_DL_UP_VALUE;    //no VF version of DL Up Time
      cfg_reset_time[11:0]  <= #TP `CX_RN_RTR_RESET_VALUE;

      cfg_rtr_valid2        <= #TP `VF_RN_RTR_VALID; 
      cfg_reset_time2[11:0] <= #TP `VF_RN_RTR_RESET_VALUE;
    end else begin
       // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      cfg_rtr_valid         <= #TP (rtr_reg_id[1] & rtr_write_pulse[3] & lbc_cdm_dbi & ~lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[31]      : cfg_rtr_valid; 
      cfg_dl_up_time[11:4]  <= #TP (rtr_reg_id[1] & rtr_write_pulse[2] & lbc_cdm_dbi & ~lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[23:16]   : cfg_dl_up_time[11:4];    
      cfg_dl_up_time[3:0]   <= #TP (rtr_reg_id[1] & rtr_write_pulse[1] & lbc_cdm_dbi & ~lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[15:12]   : cfg_dl_up_time[3:0];     
      cfg_reset_time[11:8]  <= #TP (rtr_reg_id[1] & rtr_write_pulse[1] & lbc_cdm_dbi & ~lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[11:8]    : cfg_reset_time[11:8];
      cfg_reset_time[7:0]   <= #TP (rtr_reg_id[1] & rtr_write_pulse[0] & lbc_cdm_dbi & ~lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[7:0]     : cfg_reset_time[7:0];  

      cfg_rtr_valid2        <= #TP (rtr_reg_id[1] & rtr_write_pulse[3] & lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[31]     : cfg_rtr_valid2; 
      cfg_reset_time2[11:8] <= #TP (rtr_reg_id[1] & rtr_write_pulse[1] & lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[11:8]   : cfg_reset_time2[11:8];
      cfg_reset_time2[7:0]  <= #TP (rtr_reg_id[1] & rtr_write_pulse[0] & lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[7:0]    : cfg_reset_time2[7:0]; 
      end
end  //always reg1_PROC

assign rtr_reg_07 =  VF_IMPL          ? 8'h00 :
                                        {cfg_rtr_valid, 7'b0};

assign rtr_reg_06 =  VF_IMPL          ? 8'h00 :
                                        {cfg_dl_up_time[11:4]};       // dl up reserved in VF

assign rtr_reg_05 =  VF_IMPL          ? 8'h00 :
                                        {cfg_dl_up_time[3:0], cfg_reset_time[11:8]};

assign rtr_reg_04 =  VF_IMPL          ? 8'h00 :
                                        {cfg_reset_time[7:0]};




// -----------------------------------------------------------------------------
// RTR Register 2
// -----------------------------------------------------------------------------
// rtr_reg_id       - 2
// PCIE Offset      - `RTR_PTR + 08h
// length           - 4 byte
// Cfig register    - rtr_reg_11, rtr_reg_10, rtr_reg_09, rtr_reg_08
// Read Only from the Wire.
// -----------------------------------------------------------------------------


always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : reg2_PROC
  if ( !sticky_rst_n ) begin
      cfg_d3d0_time[11:0]   <= #TP `CX_RN_RTR_D3D0_VALUE;
      cfg_flr_time[11:0]    <= #TP `CX_RN_RTR_FLR_VALUE;

      cfg_d3d0_time2[11:0]  <= #TP `VF_RN_RTR_D3D0_VALUE;
      cfg_flr_time2[11:0]   <= #TP `VF_RN_RTR_FLR_VALUE;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
      cfg_d3d0_time[11:4]   <= #TP (rtr_reg_id[2] & rtr_write_pulse[2] & lbc_cdm_dbi & ~lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[23:16]   : cfg_d3d0_time[11:4]; 
      cfg_d3d0_time[3:0]    <= #TP (rtr_reg_id[2] & rtr_write_pulse[1] & lbc_cdm_dbi & ~lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[15:12]   : cfg_d3d0_time[3:0]; 
      cfg_flr_time[11:8]    <= #TP (rtr_reg_id[2] & rtr_write_pulse[1] & lbc_cdm_dbi & ~lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[11:8]    : cfg_flr_time[11:8]; 
      cfg_flr_time[7:0]     <= #TP (rtr_reg_id[2] & rtr_write_pulse[0] & lbc_cdm_dbi & ~lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[7:0]     : cfg_flr_time[7:0]; 

      cfg_d3d0_time2[11:4]  <= #TP (rtr_reg_id[2] & rtr_write_pulse[2] & lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[23:16]   : cfg_d3d0_time2[11:4]; 
      cfg_d3d0_time2[3:0]   <= #TP (rtr_reg_id[2] & rtr_write_pulse[1] & lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[15:12]   : cfg_d3d0_time2[3:0]; 
      cfg_flr_time2[11:8]   <= #TP (rtr_reg_id[2] & rtr_write_pulse[1] & lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[11:8]    : cfg_flr_time2[11:8]; 
      cfg_flr_time2[7:0]    <= #TP (rtr_reg_id[2] & rtr_write_pulse[0] & lbc_cdm_dbi2 & dbi_ro_wr_en) ? lbc_cdm_data[7:0]     : cfg_flr_time2[7:0]; 
     end
end //always reg2_PROC


assign rtr_reg_11 = 8'b0;

assign rtr_reg_10 =  VF_IMPL          ? 8'h00 :
                                        {cfg_d3d0_time[11:4]};

assign rtr_reg_09 =  VF_IMPL          ? 8'h00 :
                                        {cfg_d3d0_time[3:0], cfg_flr_time[11:8]};

assign rtr_reg_08 =  VF_IMPL          ? 8'h00 :
                                        {cfg_flr_time[7:0]};



// =============================================================================
// Register Read Operation
// =============================================================================


always @( * ) begin : read_data_PROC   
    rtr_reg_data[31:0] = 0;

    if (rtr_reg_id[0])   begin
        rtr_reg_data = {rtr_reg_03, rtr_reg_02, rtr_reg_01, rtr_reg_00};  // read Header register
    end else if (rtr_reg_id[1])   begin
        rtr_reg_data = {rtr_reg_07, rtr_reg_06, rtr_reg_05, rtr_reg_04};  // read Readiness Time Reporting 1 register
    end else begin
        rtr_reg_data = {rtr_reg_11, rtr_reg_10, rtr_reg_09, rtr_reg_08};  // read Readiness Time Reporting 2 register
    end
end //always read_data_PROC


endmodule //cdm_rtr_reg 
