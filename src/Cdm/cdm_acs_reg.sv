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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_acs_reg.sv#10 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Access Control Services Extended Capability (PTM) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_acs_reg
#(
    parameter INST          = 0,                                   // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM      = 0,                                   // uniquifying parameter per function
    parameter ACS_CTRL_VEC_WD = `ACS_CTRL_VEC_WD,                  // The width of the egress control vector(largest across all functions)
    parameter TP            = `TP,                                 // Clock to Q delay (simulator insurance)
    parameter VF_IMPL       = 0
    , parameter RCRB          = 0                                   // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space
)

                   (
    // -------------- Inputs ----------------
    input                             core_clk,                    // Core Clock
    input                             non_sticky_rst_n,            // Non-Sticky Reset 
    input                             sticky_rst_n,                // Sticky Reset (that is, asserted for cold reset only)
    input [3:0]                       device_type,


    input  [31:0]                     lbc_cdm_data,                // Write Data 
    input                             lbc_cdm_dbi,                 // DBI Access
    input                             lbc_cdm_dbi2,                // DBI2 Access

    input  [3:0]                      acs_write_pulse,             // Write Byte Enable
    input  [9:0]                      acs_reg_id,                  // ACS Register ID
    input                             dbi_ro_wr_en,                // used to make RW registers look like RO for compliance
    input                             upstream_port,               // used to identify the device type

    input                             pf_cfg_acs_p2p_req_redirect_cap,
    input                             pf_cfg_acs_p2p_compl_redirect_cap,
    input                             pf_cfg_acs_p2p_egress_ctrl_cap,
    input                             pf_cfg_acs_p2p_direct_transl_cap,
    input [7:0]                       pf_cfg_acs_egress_ctrl_vector_size_cap,
    input                             cxl_rcrb_enable,

    // -------------- Outputs --------------
    
    output reg                        cfg_acs_validation_cap,
    output reg                        cfg_acs_at_blocking_cap,
    output reg                        cfg_acs_up_forward_cap,

    output reg                        cfg_acs_p2p_req_redirect_cap,
    output reg                        cfg_acs_p2p_compl_redirect_cap,
    output reg                        cfg_acs_p2p_egress_ctrl_cap,
    output reg                        cfg_acs_p2p_direct_transl_cap,
    output reg  [7:0]                 cfg_acs_egress_ctrl_vector_size_cap,

    output reg                        cfg_acs_validation_en,
    output reg                        cfg_acs_at_blocking_en,
    output reg                        cfg_acs_p2p_req_redirect_en,
    output reg                        cfg_acs_p2p_compl_redirect_en,
    output reg                        cfg_acs_up_forward_en,
    output reg                        cfg_acs_p2p_egress_ctrl_en,
    output reg                        cfg_acs_p2p_direct_transl_en,
    output reg [ACS_CTRL_VEC_WD-1:0]  cfg_acs_egress_ctrl_vec,                 
    output reg [31:0]                 acs_reg_data,              // ACS Register Read Data
    output                            acs_viol_svrity_mask_wr_en    // Indicates that ACS Violation Severity and Mask fields are writable
    
);

// for ACS all VF's associated with a PF shall report the same values
localparam INT_ACS_NEXT_PTR = VF_IMPL? `VF_ACS_NEXT_PTR : `ACS_NEXT_PTR;

// -------------- Internal Signals --------------

wire rc_device;
wire pcie_sw_down;

assign rc_device        = (device_type == `PCIE_RC);
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);

reg     [3:0]        cfg_acs_ver;                                   // Capability Version
reg     [15:0]       cfg_acs_id;                                    // Capability ID
reg     [11:0]       cfg_acs_next_ptr;                              // Next Capability Offset

wire    [7:0]        acs_reg_03, acs_reg_02, acs_reg_01, acs_reg_00;
wire    [7:0]        acs_reg_07, acs_reg_06, acs_reg_05, acs_reg_04;
wire    [7:0]        acs_reg_11, acs_reg_10, acs_reg_09, acs_reg_08;
wire    [7:0]        acs_reg_15, acs_reg_14, acs_reg_13, acs_reg_12;
wire    [7:0]        acs_reg_19, acs_reg_18, acs_reg_17, acs_reg_16;
wire    [7:0]        acs_reg_23, acs_reg_22, acs_reg_21, acs_reg_20;
wire    [7:0]        acs_reg_27, acs_reg_26, acs_reg_25, acs_reg_24;
wire    [7:0]        acs_reg_31, acs_reg_30, acs_reg_29, acs_reg_28;
wire    [7:0]        acs_reg_35, acs_reg_34, acs_reg_33, acs_reg_32;
wire    [7:0]        acs_reg_39, acs_reg_38, acs_reg_37, acs_reg_36;

wire single_func;
assign single_func = 1'b0 | 1'b1 ;

// ACS Violation Status and ACS Violation Mask Write Enable logic (for PFs)
assign acs_viol_svrity_mask_wr_en = (upstream_port & (single_func | !cfg_acs_p2p_egress_ctrl_cap)) // Upstream Port without P2P Egress Control capability
                                   ? 1'b0 : 1'b1;

// -----------------------------------------------------------------------------
// ACS Extended Capability Header Register
// -----------------------------------------------------------------------------
// acs_reg_id       - 0
// PCIE Offset      - ACS_PTR
// length           - 4 byte
// Cfig register    - acs_reg_03, acs_reg_02, acs_reg_01, acs_reg_00
// Read Only from the Wire.
// -----------------------------------------------------------------------------


reg         acs_next_ptr_wr_updated;    // Asserted when VC Capability header has been changed by a DBI write
always @( posedge core_clk or negedge sticky_rst_n ) begin : acs_cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_acs_id[15:0]       <= #TP `PCIE_ACS_ECAP_ID;    
        cfg_acs_ver[3:0]       <= #TP `PCIE_ACS_ECAP_VER;   
    end else begin
        // Read-Only registers, but writable through DBI
        cfg_acs_id[7:0]        <= #TP (acs_reg_id[0] & acs_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0]    : cfg_acs_id[7:0];            //RO
        cfg_acs_id[15:8]       <= #TP (acs_reg_id[0] & acs_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8]   : cfg_acs_id[15:8];           //RO
        cfg_acs_ver[3:0]       <= #TP (acs_reg_id[0] & acs_write_pulse[2] & lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16]  : cfg_acs_ver[3:0];           //RO
    end
end //always acs_cap_hdr_PROC

always @( posedge core_clk or negedge sticky_rst_n ) begin : acs_cap_next_ptr_PROC
    if ( !sticky_rst_n ) begin
        cfg_acs_next_ptr[11:0] <= #TP INT_ACS_NEXT_PTR;
    end else if(acs_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en) begin
        // Read-Only registers, but writable through DBI
        cfg_acs_next_ptr[3:0]  <= #TP (acs_write_pulse[2]) ? lbc_cdm_data[23:20] : cfg_acs_next_ptr[3:0];
        cfg_acs_next_ptr[11:4] <= #TP (acs_write_pulse[3]) ? lbc_cdm_data[31:24] : cfg_acs_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !acs_next_ptr_wr_updated) begin
        cfg_acs_next_ptr[11:0]  <= #TP `DM_RP_ACS_NEXT_PTR ;
    end else if (!acs_next_ptr_wr_updated) begin
        cfg_acs_next_ptr[11:0]  <= #TP (cxl_rcrb_enable && upstream_port) ? |RCRB ? `RCRB_ACS_NEXT_PTR : (VF_IMPL == 0) ? `CXL_ACS_NEXT_PTR : INT_ACS_NEXT_PTR : INT_ACS_NEXT_PTR ;                // Device type could change      
    end
end //always acs_cap_next_ptr_PROC

// If next pointer is modified by a DBI write, then only the Application
// (via another DBI write) is allowed any further update.
always @( posedge core_clk or negedge sticky_rst_n ) begin : acs_next_ptr_wr_update_PROC
    if ( !sticky_rst_n ) begin
        acs_next_ptr_wr_updated <= #TP 1'b0;
    end else if (acs_reg_id[0] && lbc_cdm_dbi && dbi_ro_wr_en && |acs_write_pulse[3:2]) begin
        acs_next_ptr_wr_updated <= #TP 1'b1;
    end
end

assign {acs_reg_01, acs_reg_00}      = cfg_acs_id;
assign  acs_reg_02[3:0]              = cfg_acs_ver;
assign {acs_reg_03, acs_reg_02[7:4]} = cfg_acs_next_ptr;

// ----------------------------------------------------------------------------------
// ACS ACS_CAPABILITIES_CTRL Register, combining ACS Capability and Control Registers
// ----------------------------------------------------------------------------------
// acs_reg_id       - 1
// PCIE Offset      - `ACS_PTR + 04h
// length           - 2 byte
// Cfig register    - acs_reg_05, acs_reg_04
// RO; RW1C
// -----------------------------------------------------------------------------

reg r_cfg_acs_validation_cap;
reg r_cfg_acs_at_blocking_cap;
reg r_cfg_acs_up_forward_cap;

always @( posedge core_clk or negedge sticky_rst_n) begin : acs_reg0_PROC
  if ( !sticky_rst_n ) begin
      r_cfg_acs_validation_cap           <= #TP `CX_ACS_SRC_VALID;
      r_cfg_acs_at_blocking_cap          <= #TP `CX_ACS_AT_BLOCK;
      r_cfg_acs_up_forward_cap           <= #TP `CX_ACS_UP_FORWARD;
      cfg_acs_p2p_req_redirect_cap       <= #TP `CX_ACS_P2P_REQ_REDIRECT;
      cfg_acs_p2p_compl_redirect_cap     <= #TP `CX_ACS_P2P_COMPL_REDIRECT;
      cfg_acs_p2p_egress_ctrl_cap        <= #TP `CX_ACS_P2P_EGRESS_CTRL;
      cfg_acs_p2p_direct_transl_cap      <= #TP `CX_ACS_P2P_DIRECT_TRANSL;
      cfg_acs_egress_ctrl_vector_size_cap      <= #TP `CX_ACS_EGRESS_CTRL_SIZE;
  
    end else begin
      // V, B and U exist only in downstream ports, therefore in function 0 only
      if(FUNC_NUM == 0 && VF_IMPL == 0) begin
        r_cfg_acs_validation_cap         <= #TP (upstream_port)  ? 0 : (acs_reg_id[1] & acs_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en ) ? lbc_cdm_data[0] : r_cfg_acs_validation_cap;         //RO
        r_cfg_acs_at_blocking_cap        <= #TP (upstream_port)  ? 0 : (acs_reg_id[1] & acs_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en ) ? lbc_cdm_data[1] : r_cfg_acs_at_blocking_cap;        //RO
        r_cfg_acs_up_forward_cap         <= #TP (upstream_port)  ? 0 : (acs_reg_id[1] & acs_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en ) ? lbc_cdm_data[4] : r_cfg_acs_up_forward_cap;     //RO
      end else begin
        r_cfg_acs_validation_cap         <= #TP `CX_ACS_SRC_VALID;
        r_cfg_acs_at_blocking_cap        <= #TP `CX_ACS_AT_BLOCK;
        r_cfg_acs_up_forward_cap         <= #TP `CX_ACS_UP_FORWARD;      
      end
      cfg_acs_p2p_req_redirect_cap       <= #TP (acs_reg_id[1] & acs_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en ) ? lbc_cdm_data[2] : cfg_acs_p2p_req_redirect_cap;   //RO
      cfg_acs_p2p_compl_redirect_cap     <= #TP (acs_reg_id[1] & acs_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en ) ? lbc_cdm_data[3] : cfg_acs_p2p_compl_redirect_cap; //RO
      cfg_acs_p2p_egress_ctrl_cap        <= #TP (acs_reg_id[1] & acs_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en ) ? lbc_cdm_data[5] : cfg_acs_p2p_egress_ctrl_cap;    //RO
      cfg_acs_p2p_direct_transl_cap      <= #TP (acs_reg_id[1] & acs_write_pulse[0] & lbc_cdm_dbi & dbi_ro_wr_en ) ? lbc_cdm_data[6] : cfg_acs_p2p_direct_transl_cap;  //RO
      cfg_acs_egress_ctrl_vector_size_cap[7:0]      <= #TP (acs_reg_id[1] & acs_write_pulse[1] & lbc_cdm_dbi & dbi_ro_wr_en ) ? lbc_cdm_data[15:8]  : cfg_acs_egress_ctrl_vector_size_cap[7:0]; //HWINIT
    end
end //always acs_reg1_PROC

always @(*) begin : VBU_OUTPUT
  // V, B and U exist only in downstream ports, therefore in function 0 only
  cfg_acs_validation_cap  = 0;
  cfg_acs_at_blocking_cap = 0;
  cfg_acs_up_forward_cap  = 0;
  if(FUNC_NUM == 0) begin
    cfg_acs_validation_cap  = r_cfg_acs_validation_cap & (!upstream_port);         //RO
    cfg_acs_at_blocking_cap = r_cfg_acs_at_blocking_cap & (!upstream_port);        //RO
    cfg_acs_up_forward_cap  = r_cfg_acs_up_forward_cap & (!upstream_port);     //RO
  end
end

assign acs_reg_05 = {(VF_IMPL ? pf_cfg_acs_egress_ctrl_vector_size_cap : cfg_acs_egress_ctrl_vector_size_cap) 
                    };

assign acs_reg_04 = {1'b0, 
                               (VF_IMPL ? pf_cfg_acs_p2p_direct_transl_cap  : cfg_acs_p2p_direct_transl_cap),
                               (VF_IMPL ? pf_cfg_acs_p2p_egress_ctrl_cap    : cfg_acs_p2p_egress_ctrl_cap),
                               (VF_IMPL ? 1'b0                              : cfg_acs_up_forward_cap),
                               (VF_IMPL ? pf_cfg_acs_p2p_compl_redirect_cap : cfg_acs_p2p_compl_redirect_cap),
                               (VF_IMPL ? pf_cfg_acs_p2p_req_redirect_cap   : cfg_acs_p2p_req_redirect_cap),
                     (VF_IMPL ? 1'b0                              : cfg_acs_at_blocking_cap),
                     (VF_IMPL ? 1'b0                              : cfg_acs_validation_cap)
                    };


// -----------------------------------------------------------------------------
// ACS Control Register
// -----------------------------------------------------------------------------
// acs_reg_id       - 1
// PCIE Offset      - ACS_PTR + 06h
// length           - 2 byte
// Cfig register    - acs_reg_07, acs_reg_06
// Read Write
// -----------------------------------------------------------------------------


always @( posedge core_clk or negedge non_sticky_rst_n ) begin : acs_reg1_PROC
  if ( !non_sticky_rst_n ) begin
      cfg_acs_validation_en           <= #TP 1'b0; 
      cfg_acs_at_blocking_en          <= #TP 1'b0;
      cfg_acs_p2p_req_redirect_en     <= #TP 1'b0;
      cfg_acs_p2p_compl_redirect_en   <= #TP 1'b0;
      cfg_acs_up_forward_en           <= #TP 1'b0;
      cfg_acs_p2p_egress_ctrl_en      <= #TP 1'b0;
      cfg_acs_p2p_direct_transl_en    <= #TP 1'b0;


    end else begin
      // V, B and U exist only in downstream ports, therefore in function 0 only
      if(FUNC_NUM == 0 && VF_IMPL == 0) begin
        cfg_acs_validation_en           <= #TP (cfg_acs_validation_cap) ? (acs_reg_id[1] & acs_write_pulse[2]) ?  lbc_cdm_data[16]  : cfg_acs_validation_en  : 1'b0;                //RW
        cfg_acs_at_blocking_en          <= #TP (cfg_acs_at_blocking_cap) ? (acs_reg_id[1] & acs_write_pulse[2]) ? lbc_cdm_data[17]  : cfg_acs_at_blocking_en : 1'b0;                //RW
        cfg_acs_up_forward_en           <= #TP (cfg_acs_up_forward_cap) ? (acs_reg_id[1] & acs_write_pulse[2]) ? lbc_cdm_data[20]  : cfg_acs_up_forward_en : 1'b0;          //RW
      end else begin
        cfg_acs_validation_en           <= #TP 1'b0; 
        cfg_acs_at_blocking_en          <= #TP 1'b0;
        cfg_acs_up_forward_en           <= #TP 1'b0;      
      end
      cfg_acs_p2p_req_redirect_en     <= #TP (cfg_acs_p2p_req_redirect_cap) ? (acs_reg_id[1] & acs_write_pulse[2]) ? lbc_cdm_data[18]  : cfg_acs_p2p_req_redirect_en : 1'b0;      //RW
      cfg_acs_p2p_compl_redirect_en   <= #TP (cfg_acs_p2p_compl_redirect_cap) ? (acs_reg_id[1] & acs_write_pulse[2]) ? lbc_cdm_data[19]  : cfg_acs_p2p_compl_redirect_en : 1'b0;  //RW
      cfg_acs_p2p_egress_ctrl_en      <= #TP (cfg_acs_p2p_egress_ctrl_cap) ? (acs_reg_id[1] & acs_write_pulse[2]) ? lbc_cdm_data[21]  : cfg_acs_p2p_egress_ctrl_en : 1'b0;        //RW
      cfg_acs_p2p_direct_transl_en    <= #TP (cfg_acs_p2p_direct_transl_cap) ? (acs_reg_id[1] & acs_write_pulse[2]) ? lbc_cdm_data[22]  : cfg_acs_p2p_direct_transl_en : 1'b0;    //RW
    end
end 

assign acs_reg_07 = 8'b0;
assign acs_reg_06 = {1'b0, 
                     cfg_acs_p2p_direct_transl_en,
                     cfg_acs_p2p_egress_ctrl_en,
                     cfg_acs_up_forward_en,
                     cfg_acs_p2p_compl_redirect_en,
                     cfg_acs_p2p_req_redirect_en,
                     cfg_acs_at_blocking_en,
                     cfg_acs_validation_en
                    };
                    
reg [255:0] acs_ctrl_vec_full_data;

// -----------------------------------------------------------------------------
// ACS Egress Control Vector #0
// -----------------------------------------------------------------------------
// cfg_acs_egress_ctrl_vec0 - 2
// PCIE Offset      - `ACS_PTR + 08h
// length           - 4 byte
// Cfig register    - acs_reg_11, acs_reg_10, acs_reg_09, acs_reg_08
// Read Write.
// -----------------------------------------------------------------------------
reg [ACS_CTRL_VEC_WD-1:0] cfg_acs_up_egress_ctrl_mask;
reg [ACS_CTRL_VEC_WD-1:0] cfg_acs_dw_egress_ctrl_mask;

// An expanded write pulse for 8 registers each of which has a byte write
wire [255:0] acs_write_pulse_full; 
assign acs_write_pulse_full = {8
  {
    {8{acs_write_pulse[3]}},
    {8{acs_write_pulse[2]}},
    {8{acs_write_pulse[1]}},
    {8{acs_write_pulse[0]}}
  }
};

// An expanded version of the register select lines, with a bit for each of
// the 8 possible registers
wire [255:0] acs_reg_id_full;
assign acs_reg_id_full = {
  {32{acs_reg_id[9]}},
  {32{acs_reg_id[8]}},
  {32{acs_reg_id[7]}},
  {32{acs_reg_id[6]}},
  {32{acs_reg_id[5]}},
  {32{acs_reg_id[4]}},
  {32{acs_reg_id[3]}},
  {32{acs_reg_id[2]}}
};

// A bit is written to when the reg ID and the write strobe are active
wire [255:0] acs_write_strobe_full;
assign acs_write_strobe_full = acs_write_pulse_full & acs_reg_id_full;

// Shrink the write strobe to the size of the Egress Control Vector
wire [ACS_CTRL_VEC_WD-1:0] acs_write_strobe;
assign acs_write_strobe = acs_write_strobe_full[ACS_CTRL_VEC_WD-1:0];

// An expanded version of the data
wire [255:0] acs_data_full;
assign acs_data_full = {
  {8{lbc_cdm_data}}
};

// Shrink the data to the size of the Egress Control Vector
wire [ACS_CTRL_VEC_WD-1:0] acs_data_vec;
assign acs_data_vec= acs_data_full[ACS_CTRL_VEC_WD-1:0];


// -----------------------------------------------------------------------------
// ACS Up/Dw Egress Control Vector Mask
// -----------------------------------------------------------------------------
// cfg_acs_up/dw_egress_ctrl_mask
// PCIE Offset      - `ACS_PTR + 08 - 28h
// length           - 1-256 bits
// Cfig register    - NA
// DBI2 Read Write.
// -----------------------------------------------------------------------------

localparam CX_ACS_UP_EGRESS_CTRL_MASK = `CX_ACS_UP_EGRESS_CTRL_MASK;
localparam CX_ACS_DW_EGRESS_CTRL_MASK = `CX_ACS_DW_EGRESS_CTRL_MASK;
localparam [ACS_CTRL_VEC_WD-1:0] ACS_UP_EGRESS_CTRL_MASK = CX_ACS_UP_EGRESS_CTRL_MASK[ACS_CTRL_VEC_WD-1:0];
localparam [ACS_CTRL_VEC_WD-1:0] ACS_DW_EGRESS_CTRL_MASK = CX_ACS_DW_EGRESS_CTRL_MASK[ACS_CTRL_VEC_WD-1:0];

// Only written on dbi2
// Which mask gets written to depends on port direction
// bits where acs_write_strobe is set get the value from
// lbc_cdm_data(expanded)
// bits where acs_write_strobe is clear remain unmodified
// Downstream port mask register only exists(is not constant) for function 0
always @( posedge core_clk or negedge sticky_rst_n ) begin : acs_ctrl_mask_PROC
  if ( !sticky_rst_n ) begin
      cfg_acs_up_egress_ctrl_mask    <= #TP ACS_UP_EGRESS_CTRL_MASK; 
      cfg_acs_dw_egress_ctrl_mask    <= #TP ACS_DW_EGRESS_CTRL_MASK; 
  end else begin
    if(lbc_cdm_dbi2 && |acs_write_strobe) begin
      if(upstream_port) begin
        cfg_acs_up_egress_ctrl_mask    <= #TP acs_write_strobe & acs_data_vec | ~acs_write_strobe & cfg_acs_up_egress_ctrl_mask; 
      end else if(FUNC_NUM == 0) begin
        cfg_acs_dw_egress_ctrl_mask    <= #TP acs_write_strobe & acs_data_vec | ~acs_write_strobe & cfg_acs_dw_egress_ctrl_mask; 
      end else begin
        cfg_acs_dw_egress_ctrl_mask    <= #TP 0;       
      end
    end 
  end
end 

// Select the appropriate mask depending on port direction
wire [ACS_CTRL_VEC_WD-1:0] cfg_acs_egress_ctrl_mask;
assign cfg_acs_egress_ctrl_mask = upstream_port ? cfg_acs_up_egress_ctrl_mask : cfg_acs_dw_egress_ctrl_mask;

// -----------------------------------------------------------------------------
// ACS Egress Control Vector
// -----------------------------------------------------------------------------
// cfg_acs_egress_ctrl_vec
// PCIE Offset      - `ACS_PTR + 08 - 28h
// length           - 1-256 bits
// Cfig register    - NA
// DBI2 Read Write.
// -----------------------------------------------------------------------------
// Only written when DBI2 is clear
// Bits which have the acs_write_strobe set and have the mask bit clear may be
// written
// Other bits are preserved (if acs_write_strobe is 0 OR the mask bit is set)
always @( posedge core_clk or negedge non_sticky_rst_n ) begin : acs_reg2_PROC
  if ( !non_sticky_rst_n ) begin
      cfg_acs_egress_ctrl_vec    <= #TP 0; 


    end else if(~lbc_cdm_dbi2 && |acs_write_strobe) begin
      cfg_acs_egress_ctrl_vec       <= #TP acs_write_strobe & ~cfg_acs_egress_ctrl_mask & acs_data_vec | (~acs_write_strobe | cfg_acs_egress_ctrl_mask) & cfg_acs_egress_ctrl_vec;
    end
end 

reg [255:0] cfg_acs_egress_ctrl_full;
always @(*) begin : ACS_EGRESS_VECTOR_EXPAND
  cfg_acs_egress_ctrl_full = 0;
  cfg_acs_egress_ctrl_full[ACS_CTRL_VEC_WD-1:0] = cfg_acs_egress_ctrl_vec;
end

// Extract the read data
wire [255:0] acs_ctrl_vec_data;
assign acs_ctrl_vec_data = acs_reg_id_full & cfg_acs_egress_ctrl_full;

// Expand to full bus width
always @(*) begin : ACS_DATA_EXPAND
  acs_ctrl_vec_full_data = 0;
  acs_ctrl_vec_full_data[ACS_CTRL_VEC_WD-1:0] = acs_ctrl_vec_data[ACS_CTRL_VEC_WD-1:0];
end

// =============================================================================
// Register Read Operation
// =============================================================================

always @(*)
begin
  unique case (1'b1)
    acs_reg_id[0] : acs_reg_data = {acs_reg_03, acs_reg_02, acs_reg_01, acs_reg_00};
    acs_reg_id[1] : acs_reg_data = {acs_reg_07, acs_reg_06, acs_reg_05, acs_reg_04};
    acs_reg_id[2] : acs_reg_data = acs_ctrl_vec_full_data[31:0];
    acs_reg_id[3] : acs_reg_data = acs_ctrl_vec_full_data[63:32];
    acs_reg_id[4] : acs_reg_data = acs_ctrl_vec_full_data[95:64];
    acs_reg_id[5] : acs_reg_data = acs_ctrl_vec_full_data[127:96];
    acs_reg_id[6] : acs_reg_data = acs_ctrl_vec_full_data[159:128];
    acs_reg_id[7] : acs_reg_data = acs_ctrl_vec_full_data[191:160];
    acs_reg_id[8] : acs_reg_data = acs_ctrl_vec_full_data[223:192];
    acs_reg_id[9] : acs_reg_data = acs_ctrl_vec_full_data[255:224];
    default:        acs_reg_data = `PCIE_UNUSED_RESPONSE;
  endcase
end


endmodule //cdm_acs_reg 
