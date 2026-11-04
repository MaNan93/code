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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_ats_reg.sv#7 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the TPH capability registers.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_ats_reg (
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    cdm_clk_g,
    lbc_cdm_data,
    lbc_cdm_dbi,
    ats_write_pulse,
    ats_read_pulse,
    ats_reg_id,
    dbi_ro_wr_en,
    cxl_rcrb_enable,

// -- outputs --
    cfg_ats_stu,
    cfg_ats_cache_en,
    ats_reg_data
);

parameter INST          = 0;                    // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM      = 0;                    // Physical Function Number
parameter VF_IMPL       = 0;                    // 0: PF impl. 1: VF impl.
parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)
parameter RCRB          = 0;                                   // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space

localparam ATS_NXT_PTR          = VF_IMPL ? `VF_ATS_NEXT_PTR         : ((FUNC_NUM==0) ? `ATS_NEXT_PTR_0 : `ATS_NEXT_PTR_N);

// -------------- Inputs ---------------
input                               core_clk;
input                               non_sticky_rst_n;
input                               sticky_rst_n;
input                               cdm_clk_g;                      // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
input    [31:0]                     lbc_cdm_data;                   // Data for write
input                               lbc_cdm_dbi;
input    [3:0]                      ats_write_pulse;
input                               ats_read_pulse;
input    [1:0]                      ats_reg_id;
input                               dbi_ro_wr_en;
input                               cxl_rcrb_enable;                // Indicates that the CXL 1.1 Link is up for USP supporting RCRB
//
// -------------- Outputs --------------
output  [4:0]   cfg_ats_stu;                    // ATS Control Register STU
output          cfg_ats_cache_en;               // ATS Cache Enable
output  [31:0]  ats_reg_data;                   // Read Data back from the core

reg     [31:0]  ats_reg_data;                   // Read data back from core

wire    [7:0]   cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0;
wire    [7:0]   cfg_reg_7, cfg_reg_6, cfg_reg_5, cfg_reg_4;

wire            dbi_ro_wr_en;
wire            int_lbc_cdm_dbi = lbc_cdm_dbi & dbi_ro_wr_en;



// =============================================================================
// ATS Capability Structure
// =============================================================================
// ATS Extended CAP Header
// ats_reg_id       - 0
// PCIE Offset      - `ATS_PTR
// Length           - 4 bytes
// Default value    -
// Cfig register    - cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0
// -----------------------------------------------------------------------------
logic  [15:0] cfg_ats_id;
logic   [3:0] cfg_ats_ver;
logic  [11:0] cfg_ats_next_ptr;

assign {cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0} = {cfg_ats_next_ptr,cfg_ats_ver,cfg_ats_id};


reg ats_next_ptr_wr_updated;
always @(posedge core_clk or negedge sticky_rst_n)
begin
  if(!sticky_rst_n) begin
    cfg_ats_next_ptr        <= #TP  ATS_NXT_PTR;
    ats_next_ptr_wr_updated <= #TP  1'b0;
  end else begin
    if(int_lbc_cdm_dbi && |ats_write_pulse[3:2] && ats_reg_id[0]) begin
    ats_next_ptr_wr_updated <= #TP  1'b1;
    // Read-Only register, but writable through DBI
    cfg_ats_next_ptr[3:0]     <= #TP (int_lbc_cdm_dbi && ats_write_pulse[2] && ats_reg_id[0] && (VF_IMPL == 0))  ? lbc_cdm_data[23:20]
                                    : cfg_ats_next_ptr[3:0];
    cfg_ats_next_ptr[11:4]    <= #TP (int_lbc_cdm_dbi && ats_write_pulse[3] && ats_reg_id[0] && (VF_IMPL == 0)) ? lbc_cdm_data[31:24]  
                                    : cfg_ats_next_ptr[11:4];  
    end
    else if (!ats_next_ptr_wr_updated) begin
       cfg_ats_next_ptr        <= #TP (cxl_rcrb_enable && (VF_IMPL == 0)) ? `CXL_ATS_NEXT_PTR : ATS_NXT_PTR;
    end
  end
end



generate
if (VF_IMPL == 0) begin : GEN_VT_IMPOL_EQ_0
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
  if(!sticky_rst_n) begin
    cfg_ats_id[15:0]    <= #TP `PCIE_ATS_ECAP_ID;      // Capability ID
    cfg_ats_ver[3:0]    <= #TP `PCIE_ATS_ECAP_VER;     // Capability version
  end else begin
    // Read-Only register, but writable through DBI
    cfg_ats_id[7:0]        <= #TP (ats_reg_id[0] && (VF_IMPL == 0) && ats_write_pulse[0] && lbc_cdm_dbi && dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_ats_id[7:0];
    cfg_ats_id[15:8]       <= #TP (ats_reg_id[0] && (VF_IMPL == 0) && ats_write_pulse[1] && lbc_cdm_dbi && dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_ats_id[15:8];
    cfg_ats_ver[3:0]       <= #TP (ats_reg_id[0] && (VF_IMPL == 0) && ats_write_pulse[2] && lbc_cdm_dbi && dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_ats_ver[3:0];
  end
end
end else begin : GEN_VT_IMPOL_EQ_0
  assign cfg_ats_id[15:0] = `PCIE_ATS_ECAP_ID;      // Capability ID
  assign cfg_ats_ver[3:0] = `PCIE_ATS_ECAP_VER;     // Capability version
end
endgenerate

// -----------------------------------------------------------------------------
// ATS Capability and Control Register
// ats_reg_id       - 1
// PCIE Offset      - `ATS_PTR + 04h
// Length           - 4 bytes
// Default value    - 
// Cfig register    - cfg_reg_7, cfg_reg_6, cfg_reg_5, cfg_reg_4
// -----------------------------------------------------------------------------

reg  [4:0]  ats_inv_q_depth;
reg         ats_pg_algn_req;
reg         cfg_ats_global_inval_spprtd;
reg         ats_cache_en;
reg  [4:0]  ats_stu;
wire [15:0] cfg_ats_cap_reg;
wire [15:0] cfg_ats_ctrl_reg;
wire        pasid_supported;

assign cfg_ats_cap_reg  = {9'h000, cfg_ats_global_inval_spprtd, ats_pg_algn_req,ats_inv_q_depth};
assign cfg_ats_ctrl_reg = {ats_cache_en,10'h000,ats_stu};
assign {cfg_reg_7, cfg_reg_6, cfg_reg_5, cfg_reg_4} = VF_IMPL ? {ats_cache_en,                                // [31]    Enable (E).                  // VF Control reg.
                                                                 10'h000,                                     // [30:21] Reserved
                                                                 5'h00,                                       // [20:16] Smallest Translation Unit (STU). : Convert to PF Data in cdm_reg_decode.v  
                                                                 9'h000,                                      // [15:7]  Reserved                     // VF Capability reg
                                                                 1'b0,                                        // [6]     Global Invalidate Supported : Convert to PF Data in cdm_reg_decode.v
                                                                 ats_pg_algn_req,                             // [5]     Page Aligned Request
                                                                 5'h00}                                       // [4:0]   Invalidate Queue Depth      : Convert to PF Data in cdm_reg_decode.v 
                                                              : {cfg_ats_ctrl_reg,cfg_ats_cap_reg};           // PF Control and Capability regs.
assign cfg_ats_stu      = ats_stu;
assign cfg_ats_cache_en = ats_cache_en;

// Indicate when PASID TLP Prefix is supported:
assign pasid_supported = `CX_PASID_ENABLE_VALUE;

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin
  if(!sticky_rst_n) begin
    ats_inv_q_depth            <= #TP `ATS_INV_Q_DPTH;
    ats_pg_algn_req            <= #TP 1'b1;
  end else begin
    // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
    //ATS Capability register is RO over the wire but has DBI access
    ats_inv_q_depth            <= #TP (int_lbc_cdm_dbi & ats_write_pulse[0] & ats_reg_id[1]) ? lbc_cdm_data[4:0]    : ats_inv_q_depth;
    ats_pg_algn_req            <= #TP (int_lbc_cdm_dbi & ats_write_pulse[0] & ats_reg_id[1]) ? lbc_cdm_data[5]      : ats_pg_algn_req;
  end
end   

always @(posedge core_clk or negedge sticky_rst_n)
begin
  if(!sticky_rst_n) begin
    cfg_ats_global_inval_spprtd <= #TP `DEFAULT_ATS_GLOBAL_INVAL_SPPRT;
  end else begin
    // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
    //ATS Capability register is RO over the wire but has DBI access
    cfg_ats_global_inval_spprtd <= #TP (!pasid_supported) ? 0 : (int_lbc_cdm_dbi & ats_write_pulse[0] & ats_reg_id[1]) ? lbc_cdm_data[6] : cfg_ats_global_inval_spprtd;
  end
end   


always @(posedge cdm_clk_g or negedge non_sticky_rst_n)
begin
  if(!non_sticky_rst_n) begin
    ats_stu                    <= #TP `ATS_STU;
    ats_cache_en               <= #TP 1'b0;
  end else begin
    // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
    //ATS Control register is RW
    ats_stu                    <= #TP (ats_write_pulse[2] & ats_reg_id[1]) ? lbc_cdm_data[20:16]  : ats_stu;        
    ats_cache_en               <= #TP (ats_write_pulse[3] & ats_reg_id[1]) ? lbc_cdm_data[31]     : ats_cache_en;   
  end
end   


// =============================================================================
// CFG Register Read Operation
// =============================================================================
always @(*)
begin
  unique case (1'b1)
    ats_reg_id[0] : ats_reg_data = {cfg_reg_3,  cfg_reg_2,  cfg_reg_1,  cfg_reg_0};
    ats_reg_id[1] : ats_reg_data = {cfg_reg_7,  cfg_reg_6,  cfg_reg_5,  cfg_reg_4};
    default:        ats_reg_data = `PCIE_UNUSED_RESPONSE;
  endcase
end



endmodule // cdm_ats_reg
