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
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #15 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_ras_reg.sv#15 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains RAS Extended Capability.
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

`include "Cdm/cdm_ras_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module cdm_ras_reg
import cdm_ras_pkg::ras_err_tracer_ctrl_s;
import cdm_ras_pkg::ras_err_tracer_rpt_s;
import cdm_ras_pkg::ras_err_inj_mgr_ctrl_s;
import cdm_ras_pkg::RAS_ERROR_TRACER_FILTER_TAG_WD;
import cdm_ras_pkg::RAS_TRACE_BUFFER_DEPTH;
import cdm_ras_pkg::RAS_ERROR_TRACER_FILTER_NUMBER;
import cdm_ras_pkg::RAS_REG_ERROR_SYNDROME_WD;
import DWC_pcie_ctl_pkg::RAS_ERROR_CHK_ID_WD;
import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
(
// -------------- Inputs ---------------
    core_clk,                    // Core Clock
    sticky_rst_n,                // Reset sticky registers only
    non_sticky_rst_n,            // Non-Sticky Reset
    cdm_clk_g,
    // --- Register Access I/F
    lbc_cdm_data,                // Write Data
    lbc_cdm_dbi,                 // DBI Access
    ecfg_write_pulse,            // Write Byte Enables
    ras_reg_sel,
    ras_reg_id,                  // RAS Cap Register ID
    dbi_ro_wr_en,                // used to make RW registers look like RO for compliance
    // --- Other
    upstream_port,               // Device Type is upstream port
    cxl_rcrb_enable,
    ras_err_tracer_rpt,
    // -------------- Outputs ---------------
    // --- Register Access I/F
    ras_reg_ack,                 // RAS Cap Register acknowledge
    ras_reg_data,                // RAS Cap Register Read Data
    ras_error_mode_en,           // Enable the core to enter RASDP error mode
    cfg_rasdp_linkdown_en,       // allows the core to force link down upon RASDP uncorrecatable error
    ras_error_mode_clear         // take the core out of RASDP error mode
    ,
    ras_err_tracer_ctrl,
    ras_err_inj_mgr_ctrl
) ;

parameter INST          = 0;                            // The uniquifying parameter for each port logic instance.
parameter TP            = `TP;                          // Clock to Q delay (simulator insurance)
parameter NF            = `CX_NFUNC;                    // Number of Functions
  parameter RAS_PROT_TYPE = `CX_RAS_PROT_TYPE;
localparam DATA_DELAY_BCM36_NHS = 3;  // Type of random delay to be added to signal in simulation by bcm36_nhs

localparam NR_REGS     = 25;                            // Number of registers (4 bytes)

parameter RCRB          = 0;                            // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space

// -------------- Inputs ---------------
input                              core_clk;                    // Core Clock
input                              sticky_rst_n;                // Reset sticky registers only
input                              non_sticky_rst_n;            // Non-Sticky Reset
input                              cdm_clk_g;
// --- Register Access I/F
input  [31:0]                      lbc_cdm_data;                // Write Data
input                              lbc_cdm_dbi;                 // DBI Access
input  [4*NF-1:0]                  ecfg_write_pulse;            // Write Byte Enables
input  [NF-1:0]                    ras_reg_sel;                 // Function accessing RAS registers
input  [(NR_REGS*NF)-1:0]          ras_reg_id;                  // RAS Cap Register ID
input                              dbi_ro_wr_en;                // used to make RW registers look like RO for compliance
// --- Other
input                              upstream_port;               // Device Type is upstream port
input                              cxl_rcrb_enable;          // Indicates that the CXL 1.1 Link is up for USP supporting RCRB
input ras_err_tracer_rpt_s ras_err_tracer_rpt;
// -------------- Outputs ---------------
// --- Register Access I/F
output                        ras_reg_ack;                 // RAS Cap Register Read Data Acknowledge
output [31:0]                 ras_reg_data;                // RAS Cap Register Read Data

output                        ras_error_mode_en;           // Enable the core to enter RASDP error mode
output                        cfg_rasdp_linkdown_en;       // When high, allows the core to force link down upon RASDP uncorrecatable error
output                        ras_error_mode_clear;        // take the core out of RASDP error mode
output ras_err_tracer_ctrl_s  ras_err_tracer_ctrl;
output ras_err_inj_mgr_ctrl_s ras_err_inj_mgr_ctrl;
// -------------- Internal Signals --------------
reg  [31:0]                 int_ras_reg_data;            // Internal RAS Cap Register Read Data
reg                         ras_reg_ack;                 // RAS Cap Register Read Data Acknowledge
reg                         ras_reg_ack_done;            // RAS Cap Register Read Data Acknowledge done
reg  [31:0]                 ras_reg_data;                // RAS Cap Register Read Data
reg                         ras_error_mode_en;           // Enable the core to enter RASDP error mode
reg                         cfg_rasdp_linkdown_en;
reg                         ras_error_mode_clear;        // take the core out of RASDP error mode
//
wire [7:0]                  ras_reg_0x00, ras_reg_0x01, ras_reg_0x02, ras_reg_0x03 ;  // Read Data Address 0x00-0x03
wire [7:0]                  ras_reg_0x04, ras_reg_0x05, ras_reg_0x06, ras_reg_0x07 ;  // Read Data Address 0x04-0x07
wire [7:0]                  ras_reg_0x08, ras_reg_0x09, ras_reg_0x0A, ras_reg_0x0B ;  // Read Data Address 0x08-0x0B
wire [7:0]                  ras_reg_0x0C, ras_reg_0x0D, ras_reg_0x0E, ras_reg_0x0F ;  // Read Data Address 0x0C-0x0F
wire [7:0]                  ras_reg_0x10, ras_reg_0x11, ras_reg_0x12, ras_reg_0x13 ;  // Read Data Address 0x10-0x13
wire [7:0]                  ras_reg_0x14, ras_reg_0x15, ras_reg_0x16, ras_reg_0x17 ;  // Read Data Address 0x14-0x17
wire [7:0]                  ras_reg_0x18, ras_reg_0x19, ras_reg_0x1A, ras_reg_0x1B ;  // Read Data Address 0x18-0x1B
wire [7:0]                  ras_reg_0x1C, ras_reg_0x1D, ras_reg_0x1E, ras_reg_0x1F ;  // Read Data Address 0x1C-0x1F
wire [7:0]                  ras_reg_0x20, ras_reg_0x21, ras_reg_0x22, ras_reg_0x23 ;  // Read Data Address 0x20-0x23
wire [7:0]                  ras_reg_0x24, ras_reg_0x25, ras_reg_0x26, ras_reg_0x27 ;  // Read Data Address 0x24-0x27
wire [7:0]                  ras_reg_0x28, ras_reg_0x29, ras_reg_0x2A, ras_reg_0x2B ;  // Read Data Address 0x28-0x2B
wire [7:0]                  ras_reg_0x2C, ras_reg_0x2D, ras_reg_0x2E, ras_reg_0x2F ;  // Read Data Address 0x2C-0x2F
wire [7:0]                  ras_reg_0x30, ras_reg_0x31, ras_reg_0x32, ras_reg_0x33 ;  // Read Data Address 0x30-0x33
wire [7:0]                  ras_reg_0x34, ras_reg_0x35, ras_reg_0x36, ras_reg_0x37 ;  // Read Data Address 0x34-0x37
wire [7:0]                  ras_reg_0x38, ras_reg_0x39, ras_reg_0x3A, ras_reg_0x3B ;  // Read Data Address 0x38-0x3B
wire [7:0]                  ras_reg_0x3C, ras_reg_0x3D, ras_reg_0x3E, ras_reg_0x3F ;  // Read Data Address 0x3C-0x3F
wire [7:0]                  ras_reg_0x40, ras_reg_0x41, ras_reg_0x42, ras_reg_0x43 ;  // Read Data Address 0x40-0x43
wire [7:0]                  ras_reg_0x44, ras_reg_0x45, ras_reg_0x46, ras_reg_0x47 ;  // Read Data Address 0x44-0x47
wire [7:0]                  ras_reg_0x48, ras_reg_0x49, ras_reg_0x4A, ras_reg_0x4B ;  // Read Data Address 0x48-0x4B
wire [7:0]                  ras_reg_0x4C, ras_reg_0x4D, ras_reg_0x4E, ras_reg_0x4F ;  // Read Data Address 0x4C-0x4F
wire [7:0]                  ras_reg_0x50, ras_reg_0x51, ras_reg_0x52, ras_reg_0x53 ;  // Read Data Address 0x50-0x53
wire [7:0]                  ras_reg_0x54, ras_reg_0x55, ras_reg_0x56, ras_reg_0x57 ;  // Read Data Address 0x54-0x57
wire [7:0]                  ras_reg_0x58, ras_reg_0x59, ras_reg_0x5A, ras_reg_0x5B ;  // Read Data Address 0x58-0x5B
wire [7:0]                  ras_reg_0x5C, ras_reg_0x5D, ras_reg_0x5E, ras_reg_0x5F ;  // Read Data Address 0x5C-0x5F
wire [7:0]                  ras_reg_0x60, ras_reg_0x61, ras_reg_0x62, ras_reg_0x63 ;  // Read Data Address 0x60-0x63
wire                        int_lbc_cdm_dbi;                                          // Internal DBI Access
wire                        downstream_port;
wire [3 :0]                 int_write_pulse;        // Internal Write Pulse
wire [NR_REGS-1:0]          int_reg_id;             // Internal Register ID

assign int_lbc_cdm_dbi    = lbc_cdm_dbi & dbi_ro_wr_en;
assign downstream_port    = !upstream_port;

// Extract write_pulse and reg_id for active function
assign int_write_pulse    = get_write_pulse(ecfg_write_pulse, ras_reg_sel);
assign int_reg_id         = get_reg_id(ras_reg_id, ras_reg_sel);
// -----------------------------------------------------------------------------
// ras_reg_id       - 0
// PCIE Offset      - `RAS_PTR + 00h
// length           - 4 byte
// Cfig register    - ras_reg_0x03, ras_reg_0x02, ras_reg_0x01, ras_reg_0x00
// register         - PCI Express Extended Capability ID [15:0] : RO
//                  - Capability Version [19:16] : RO
//                  - Next Capability Offset [31:20] : RO(cs)
// -----------------------------------------------------------------------------
    reg    [15:0]                      ras_cap_id ;              // PCI Express Extended Capability ID [15:0]
    reg    [3:0]                       ras_cap_ver ;             // Capability Version [19:16]
    reg    [11:0]                      ras_next_ptr ;            // Next Capability Offset [31:20]

    reg    [NF-1:0]                    rasdp_next_ptr_updated_nf;// Asserted when RASDP VD Cap header has been changed by a DBI write
    reg    [(12*NF)-1:0]               int_reg_next_ptr_nf;

    always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            ras_cap_id     <= #TP `PCIE_VSEC_ECAP_ID ;
            ras_cap_ver    <= #TP `PCIE_VSEC_ECAP_VER ;
        end
        else begin
                ras_cap_id[7:0]   <= #TP (int_reg_id[0] & int_write_pulse[0] & int_lbc_cdm_dbi ) ? lbc_cdm_data[7:0]   : ras_cap_id[7:0] ;
                ras_cap_id[15:8]  <= #TP (int_reg_id[0] & int_write_pulse[1] & int_lbc_cdm_dbi ) ? lbc_cdm_data[15:8]  : ras_cap_id[15:8] ;
                ras_cap_ver       <= #TP (int_reg_id[0] & int_write_pulse[2] & int_lbc_cdm_dbi ) ? lbc_cdm_data[19:16] : ras_cap_ver ;
        end
    end

    // ----------------------------------------------------------------
    // Next pointer for each function
    // ---------------------------------------------------------------
      always @(posedge core_clk or negedge sticky_rst_n) begin
        // spyglass disable_block NonConstReset-ML
        // SMD: Invalid reset condition, RHS should be a static value.
        // SJ: FUNC_NUM is a constant which is used in the definition of VSECRAS_NEXT_PTR.
        if (!sticky_rst_n) begin
          for ( int FUNC_NUM=0 ; FUNC_NUM<NF ; FUNC_NUM=FUNC_NUM+1) begin
            if (FUNC_NUM == 0) begin
              int_reg_next_ptr_nf[12*FUNC_NUM+0 +: 12] <= #TP `VSECRAS_NEXT_PTR_0 ;
            end
            else begin
              int_reg_next_ptr_nf[12*FUNC_NUM+0 +: 12] <= #TP `VSECRAS_NEXT_PTR_N ;
            end
          end
        end
        // spyglass enable_block NonConstReset-ML
        else begin
          for ( int FUNC_NUM=0 ; FUNC_NUM<NF ; FUNC_NUM=FUNC_NUM+1) begin
            if( ras_reg_id[NR_REGS*FUNC_NUM + 0] && int_lbc_cdm_dbi ) begin //ras_reg_id has NR_REGS*NF bit
                int_reg_next_ptr_nf[12*FUNC_NUM + 0 +: 4]    <= #TP ecfg_write_pulse[4*FUNC_NUM+2] ? lbc_cdm_data[23:20] : int_reg_next_ptr_nf[12*FUNC_NUM + 0 +: 4];
                int_reg_next_ptr_nf[12*FUNC_NUM + 4 +: 8]    <= #TP ecfg_write_pulse[4*FUNC_NUM+3] ? lbc_cdm_data[31:24] : int_reg_next_ptr_nf[12*FUNC_NUM + 4 +: 8] ;
            end
            else if( !rasdp_next_ptr_updated_nf[FUNC_NUM] ) begin
              int_reg_next_ptr_nf[12*FUNC_NUM + 0 +: 12] <= #TP upstream_port ? cxl_rcrb_enable ? `CXL_VSECRAS_NEXT_PTR :  `VSECRAS_NEXT_PTR :  `DM_RP_VSECRAS_NEXT_PTR;
            end
          end
        end
      end

     always @(posedge core_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
          for ( int FUNC_NUM=0 ; FUNC_NUM<NF ; FUNC_NUM=FUNC_NUM+1) begin
            rasdp_next_ptr_updated_nf [FUNC_NUM] <= #TP 1'b0;
          end
        end
        else begin
          for ( int FUNC_NUM=0 ; FUNC_NUM<NF ; FUNC_NUM=FUNC_NUM+1) begin
            if( ras_reg_id[NR_REGS*FUNC_NUM+0] && int_lbc_cdm_dbi && |ecfg_write_pulse[4*FUNC_NUM + 2 +: 2] ) begin
              rasdp_next_ptr_updated_nf [FUNC_NUM] <= #TP 1'b1;
            end
          end
        end
     end

    always @(*) begin: for_int_reg_next_ptr
      integer jj;
      ras_next_ptr = {11'b0,int_reg_next_ptr_nf[0]};
      for ( jj=0 ; jj<NF ; jj=jj+1 ) begin
        if (ras_reg_sel[jj] ) begin
          ras_next_ptr = int_reg_next_ptr_nf[12*jj +: 12];
        end
      end
    end



    assign {ras_reg_0x03,ras_reg_0x02,ras_reg_0x01,ras_reg_0x00} = { ras_next_ptr              // [31:20]
                                                                   , ras_cap_ver               // [19:16]
                                                                   , ras_cap_id                // [15:0]
                                                                   } ;

// -----------------------------------------------------------------------------
// ras_reg_id       - 1
// PCIE Offset      - `RAS_PTR + 04h
// length           - 4 byte
// Cfig register    - ras_reg_0x07, ras_reg_0x06, ras_reg_0x05, ras_reg_0x04
// register         - VSED ID [15:0] : RO
//                  - VSEC Rev [19:16] : RO
//                  - VSEC Length [31:20] : RO
// -----------------------------------------------------------------------------

    wire [11:0] ras_vsec_length;
    wire [3:0]  ras_vsec_rev;
    wire [15:0] ras_vsec_id;

    assign ras_vsec_length  = `DEFAULT_VSEC_RASDP_LENGTH;
    assign ras_vsec_rev     = `DEFAULT_VSEC_RASDP_REV;
    assign ras_vsec_id      = `DEFAULT_VSEC_RASDP_ID;

    assign {ras_reg_0x07,ras_reg_0x06,ras_reg_0x05,ras_reg_0x04} = { ras_vsec_length          // [31:20]
                                                                   , ras_vsec_rev             // [19:16]
                                                                   , ras_vsec_id              // [15:00]
                                                                   } ;

assign {ras_reg_0x0B,ras_reg_0x0A,ras_reg_0x09,ras_reg_0x08} = {32'h0};
assign {ras_reg_0x0F,ras_reg_0x0E,ras_reg_0x0D,ras_reg_0x0C} = {32'h0};
assign {ras_reg_0x13,ras_reg_0x12,ras_reg_0x11,ras_reg_0x10} = {32'h0};
assign {ras_reg_0x17,ras_reg_0x16,ras_reg_0x15,ras_reg_0x14} = {32'h0};
assign {ras_reg_0x1B,ras_reg_0x1A,ras_reg_0x19,ras_reg_0x18} = {32'h0};
assign {ras_reg_0x1F,ras_reg_0x1E,ras_reg_0x1D,ras_reg_0x1C} = {32'h0};
assign {ras_reg_0x23,ras_reg_0x22,ras_reg_0x21,ras_reg_0x20} = {32'h0};
assign {ras_reg_0x27,ras_reg_0x26,ras_reg_0x25,ras_reg_0x24} = {32'h0};
// -----------------------------------------------------------------------------
// ras_reg_id       - 10
// PCIE Offset      - `RAS_PTR + 28h
// length           - 4 byte
// Cfig register    - ras_reg_0x28, ras_reg_0x29, ras_reg_0x2A, ras_reg_0x2B
// register         - Reserved [31:2] : RO
//                  - RAS DP - Enable to enter error mode [0] : RW
//                  - RAS DP - Enable auto link down      [1] : RW
// -----------------------------------------------------------------------------
   always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            ras_error_mode_en     <= #TP `RAS_DEFAULT_NULLIFY_EN;
            cfg_rasdp_linkdown_en <= #TP 1'b0;
        end
        else begin
            ras_error_mode_en     <= #TP (int_reg_id[10] & int_write_pulse[0]) ? lbc_cdm_data[0] : ras_error_mode_en;
            cfg_rasdp_linkdown_en <= #TP (int_reg_id[10] & int_write_pulse[0]) ? lbc_cdm_data[1] : cfg_rasdp_linkdown_en;
        end
    end

    assign {ras_reg_0x2B,ras_reg_0x2A,ras_reg_0x29,ras_reg_0x28} = { 30'h0                  //[31:2]
                                                                   , cfg_rasdp_linkdown_en  //[1]
                                                                   , ras_error_mode_en      //[0]
                                                                   };

// -----------------------------------------------------------------------------
// ras_reg_id       - 11
// PCIE Offset      - `RAS_PTR + 2Ch
// length           - 4 byte
// Cfig register    - ras_reg_0x2C, ras_reg_0x2D, ras_reg_0x2E, ras_reg_0x2F
// register         - Reserved [31:1] : RO
//                  - Clear error mode [0] : WO
// -----------------------------------------------------------------------------
   always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            ras_error_mode_clear <= #TP 1'b0;
        end
        else begin
            ras_error_mode_clear <= #TP (int_reg_id[11] & int_write_pulse[0]) ? lbc_cdm_data[0]     : 1'b0;
        end
    end

    assign {ras_reg_0x2F,ras_reg_0x2E,ras_reg_0x2D,ras_reg_0x2C} = 32'h0; // [31:16]

assign {ras_reg_0x33,ras_reg_0x32,ras_reg_0x31,ras_reg_0x30} = {32'h0};
assign {ras_reg_0x37,ras_reg_0x36,ras_reg_0x35,ras_reg_0x34} = {32'h0};

// -----------------------------------------------------------------------------
// ras_reg_id       - 14
// PCIE Offset      - `RAS_PTR + 38h
// length           - 4 byte
// Cfig register    - ras_reg_0x38, ras_reg_0x39, ras_reg_0x3A, ras_reg_0x3B
// register         - Reserved [31: 0] : RO
// -----------------------------------------------------------------------------
assign {ras_reg_0x3B,ras_reg_0x3A,ras_reg_0x39,ras_reg_0x38} = {
                                                                  32'b0000_0000_0000_0000_0000_0000_0000_0000
                                                               };

// -----------------------------------------------------------------------------
// ras_reg_id       - 15
// PCIE Offset      - `RAS_PTR + 3Ch
// length           - 4 byte
// Cfig register    - ras_reg_0x3C, ras_reg_0x3D, ras_reg_0x3E, ras_reg_0x3F
// register         - Reserved [31: 0] : RO
// -----------------------------------------------------------------------------
assign {ras_reg_0x3F,ras_reg_0x3E,ras_reg_0x3D,ras_reg_0x3C} = {
                                                                  32'b0000_0000_0000_0000_0000_0000_0000_0000
                                                               };

// -----------------------------------------------------------------------------
// ras_reg_id       - 16
// PCIE Offset      - `RAS_PTR + 40h
// length           - 4 byte
// Cfig register    - ras_reg_0x40, ras_reg_0x41, ras_reg_0x42, ras_reg_0x43
// register         - RAS_ERROR_TRACER_SIZE          [ 8: 0] : RO
//                  - Reserved                       [15: 9] : RO
//                  - RAS_ERROR_TRACER_FILTER_NUMBER [20:16] : RO
//                  - Reserved                       [31:21] : RO
// -----------------------------------------------------------------------------
assign {ras_reg_0x43,ras_reg_0x42,ras_reg_0x41,ras_reg_0x40} = {
                                                                  11'b0000_0000_000,
                                                                  ras_err_tracer_rpt.ras_error_tracer_capability.filter_number,
                                                                  9'b0000_0000_0,
                                                                  ras_err_tracer_rpt.ras_error_tracer_capability.size
                                                               };

// -----------------------------------------------------------------------------
// ras_reg_id       - 17
// PCIE Offset      - `RAS_PTR + 44h
// length           - 4 byte
// Cfig register    - ras_reg_0x44, ras_reg_0x45, ras_reg_0x46, ras_reg_0x47
// register         - ENABLE                                      [ 0: 0] : RW
//                  - Reserved                                    [ 7: 1] : RO
//                  - RAS_ERROR_TRACER_PENDING_ENABLE             [ 8: 8] : RW
//                  - RAS_ERROR_TRACER_PENDING_ERR_INJ_SUCCESSFUL [ 9: 9] : RO
//                  - RAS_ERROR_TRACER_PENDING_ERR_INJ_FAILURE    [10:10] : RO
//                  - RAS_ERROR_TRACER_PENDING_UNCORRECTABLE      [11:11] : RO
//                  - RAS_ERROR_TRACER_PENDING_CORRECTABLE        [12:12] : RO
//                  - RESERVED                                    [15:13] : RO
//                  - COUNT_AFFINITY                              [17:16] : RW
//                  - Reserved                                    [23:18] : RO
//                  - TIMESTAMP_CTRL_INCR                         [28:24] : RW
//                  - TIMESTAMP_CTRL_CLR                          [29:29] : WO
//                  - Reserved                                    [31:30] : RO
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        ras_err_tracer_ctrl.ras_error_tracer_ctrl <= #TP '0;
    end else begin
        ras_err_tracer_ctrl.ras_error_tracer_ctrl.enable                          <= #TP (int_reg_id[17] & int_write_pulse[0]) ? lbc_cdm_data[0]     : ras_err_tracer_ctrl.ras_error_tracer_ctrl.enable;
        ras_err_tracer_ctrl.ras_error_tracer_ctrl.ras_error_tracer_pending_enable <= #TP (int_reg_id[17] & int_write_pulse[1]) ? lbc_cdm_data[8]     : ras_err_tracer_ctrl.ras_error_tracer_ctrl.ras_error_tracer_pending_enable;
        ras_err_tracer_ctrl.ras_error_tracer_ctrl.count_affinity                  <= #TP (int_reg_id[17] & int_write_pulse[2]) ? lbc_cdm_data[17:16] : ras_err_tracer_ctrl.ras_error_tracer_ctrl.count_affinity;
        ras_err_tracer_ctrl.ras_error_tracer_ctrl.timestamp_ctrl_incr             <= #TP (int_reg_id[17] & int_write_pulse[2]) ? lbc_cdm_data[28:24] : ras_err_tracer_ctrl.ras_error_tracer_ctrl.timestamp_ctrl_incr;
        ras_err_tracer_ctrl.ras_error_tracer_ctrl.timestamp_ctrl_clr              <= #TP (int_reg_id[17] & int_write_pulse[2]) ? lbc_cdm_data[29]    : 1'b0;
    end
end

assign {ras_reg_0x47,ras_reg_0x46,ras_reg_0x45,ras_reg_0x44} =  {
                                                                    2'b00,
                                                                    ras_err_tracer_ctrl.ras_error_tracer_ctrl.timestamp_ctrl_clr,
                                                                    ras_err_tracer_ctrl.ras_error_tracer_ctrl.timestamp_ctrl_incr,
                                                                    6'b0000_00,
                                                                    ras_err_tracer_ctrl.ras_error_tracer_ctrl.count_affinity,
                                                                    3'b000,
                                                                    ras_err_tracer_rpt.ras_error_tracer_pending_correctable,
                                                                    ras_err_tracer_rpt.ras_error_tracer_pending_uncorrectable,
                                                                    ras_err_tracer_rpt.ras_error_tracer_pending_err_inj_failure,
                                                                    ras_err_tracer_rpt.ras_error_tracer_pending_err_inj_successful,
                                                                    ras_err_tracer_ctrl.ras_error_tracer_ctrl.ras_error_tracer_pending_enable,
                                                                    7'b0000_000,
                                                                    ras_err_tracer_ctrl.ras_error_tracer_ctrl.enable
                                                                };
// -----------------------------------------------------------------------------
// ras_reg_id       - 18
// PCIE Offset      - `RAS_PTR + 48h
// length           - 4 byte
// Cfig register    - ras_reg_0x48, ras_reg_0x49, ras_reg_0x4A, ras_reg_0x4B
// register         - FILTER_TAG     [22: 0] : RW
//                  - FILTER_RULE_EN [23:23] : RW
//                  - FILTER_RULE    [24:24] : RW
//                  - Reserved       [27:25] : RO
//                  - FILTER_ID      [31:28] : RW
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl <= #TP '0;
    end else begin
        if (int_reg_id[18] && int_write_pulse[0]) begin
            ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_tag[ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_id][ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_rule][ 7: 0] <= #TP lbc_cdm_data[ 7: 0];
        end
        if (int_reg_id[18] && int_write_pulse[1]) begin
            ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_tag[ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_id][ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_rule][15: 8] <= #TP lbc_cdm_data[15: 8];
        end
        if (int_reg_id[18] && int_write_pulse[2]) begin
            ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_tag[ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_id][ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_rule][22:16] <= #TP lbc_cdm_data[22:16];
            ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_rule_en[ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_id][ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_rule]    <= #TP lbc_cdm_data[23];
        end
        if (int_reg_id[18] && int_write_pulse[3]) begin
            ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_rule                                                                                                                                 <= #TP lbc_cdm_data[27];
            ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_id                                                                                                                                   <= #TP lbc_cdm_data[28 +: $clog2(RAS_ERROR_TRACER_FILTER_NUMBER)];
        end
    end
end
assign {ras_reg_0x4B,ras_reg_0x4A,ras_reg_0x49,ras_reg_0x48} = {
                                                                  {(4-$clog2(RAS_ERROR_TRACER_FILTER_NUMBER)){1'b0}},
                                                                  ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_id,
                                                                  3'b0,
                                                                  ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_rule,
                                                                  ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_rule_en[ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_id][ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_rule],
                                                                  ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_tag[ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_id][ras_err_tracer_ctrl.ras_error_tracer_filter_ctrl.filter_rule]
                                                                };

// -----------------------------------------------------------------------------
// ras_reg_id       - 19
// PCIE Offset      - `RAS_PTR + 4Ch
// length           - 4 byte
// Cfig register    - ras_reg_0x4C, ras_reg_0x4D, ras_reg_0x4E, ras_reg_0x4F
// register         - ENTRY_CLR [ 0: 0] : WO
//                  - Reserved  [23: 1] : RO
//                  - ENTRY_ID  [31:24] : RW
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        ras_err_tracer_ctrl.ras_error_tracer_log_ctrl <= #TP '0;
    end else begin
        ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_clr <= #TP (int_reg_id[19] & int_write_pulse[0]) ? lbc_cdm_data[ 0: 0]                                   : 1'b0;
        ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_id  <= #TP (int_reg_id[19] & int_write_pulse[3]) ? lbc_cdm_data[24 +: $clog2(RAS_TRACE_BUFFER_DEPTH)] : ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_id;
    end
end

assign {ras_reg_0x4F,ras_reg_0x4E,ras_reg_0x4D,ras_reg_0x4C} = {
                                                                    {(8-$clog2(RAS_TRACE_BUFFER_DEPTH)){1'b0}},
                                                                    ras_err_tracer_ctrl.ras_error_tracer_log_ctrl.entry_id,
                                                                    24'b0000_0000_0000_0000_0000_0000
                                                               };

// -----------------------------------------------------------------------------
// ras_reg_id       - 20
// PCIE Offset      - `RAS_PTR + 50h
// length           - 4 byte
// Cfig register    - ras_reg_0x50, ras_reg_0x51, ras_reg_0x52, ras_reg_0x53
// register         - COUNT    [15: 0] : RO
//                  - SYNDROME [31:16] : RO
// -----------------------------------------------------------------------------
assign {ras_reg_0x53,ras_reg_0x52,ras_reg_0x51,ras_reg_0x50} = {
                                                                    ras_err_tracer_rpt.ras_error_tracer_log_report_0.syndrome,
                                                                    ras_err_tracer_rpt.ras_error_tracer_log_report_0.count
                                                               };

// -----------------------------------------------------------------------------
// ras_reg_id       - 21
// PCIE Offset      - `RAS_PTR + 54h
// length           - 4 byte
// Cfig register    - ras_reg_0x54, ras_reg_0x55, ras_reg_0x56, ras_reg_0x57
// register         - ERROR_TYPE               [ 1: 0] : RO
//                  - Reserved                 [ 7: 2] : RO
//                  - RAS_DP_PROT_CHK_SLICE_ID [15: 8] : RO
//                  - RAS_DP_PROT_CHK_ID       [31:16] : RO
// -----------------------------------------------------------------------------
 assign {ras_reg_0x57,ras_reg_0x56,ras_reg_0x55,ras_reg_0x54} = {
                                                                     {(16-RAS_ERROR_CHK_ID_WD){1'b0}},
                                                                     ras_err_tracer_rpt.ras_error_tracer_log_report_1.ras_prot_chk_id,
                                                                     ras_err_tracer_rpt.ras_error_tracer_log_report_1.ras_prot_chk_slice_id,
                                                                     6'b0000_00,
                                                                     ras_err_tracer_rpt.ras_error_tracer_log_report_1.error_type
                                                                };

// -----------------------------------------------------------------------------
// ras_reg_id       - 22
// PCIE Offset      - `RAS_PTR + 58h
// length           - 4 byte
// Cfig register    - ras_reg_0x58, ras_reg_0x59, ras_reg_0x5A, ras_reg_0x5B
// register         - ADDR_LOG [22: 0] : RO
//                  - Reserved [31:23] : RO
// -----------------------------------------------------------------------------
assign {ras_reg_0x5B,ras_reg_0x5A,ras_reg_0x59,ras_reg_0x58} = {
                                                                    {(32-RAS_ERROR_TRACER_FILTER_TAG_WD){1'b0}},
                                                                    ras_err_tracer_rpt.ras_error_tracer_log_report_2.addr_log 
                                                               };

// -----------------------------------------------------------------------------
// ras_reg_id       - 23
// PCIE Offset      - `RAS_PTR + 5Ch
// length           - 4 byte
// Cfig register    - ras_reg_0x5C, ras_reg_0x5D, ras_reg_0x5E, ras_reg_0x5F
// register         - TIMESTAMP [31: 0] : RO
// -----------------------------------------------------------------------------
assign {ras_reg_0x5F,ras_reg_0x5E,ras_reg_0x5D,ras_reg_0x5C} = {
                                                                    ras_err_tracer_rpt.ras_error_tracer_log_report_3.timestamp
                                                               };

// -----------------------------------------------------------------------------
// ras_reg_id       - 24
// PCIE Offset      - `RAS_PTR + 60h
// length           - 4 byte
// Cfig register    - ras_reg_0x60, ras_reg_0x61, ras_reg_0x62, ras_reg_0x63
// register         - START_ERR_INJ                  [ 0: 0] : WO
//                  - STOP_ERR_INJ                   [ 1: 1] : WO
//                  - ERR_INJ_REPEAT                 [ 2: 2] : RW (optional)
//                  - Reserved                       [ 7: 3] : RO
//                  - ERR_INJ_REPEAT_PAUSE_DURATION  [12: 8] : RW (optional)
//                  - Reserved                       [15: 3] : RO
//                  - RAS_DP_PROT_CHK_ID             [31:16] : RW
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        ras_err_inj_mgr_ctrl <= #TP '0;
    end else begin
        ras_err_inj_mgr_ctrl.start_err_inj                                    <= #TP (int_reg_id[24] & int_write_pulse[0]) ? lbc_cdm_data[ 0]    : 1'b0;
        ras_err_inj_mgr_ctrl.ras_prot_chk_id[ 7: 0]                           <= #TP (int_reg_id[24] & int_write_pulse[2]) ? lbc_cdm_data[                                23:16] : ras_err_inj_mgr_ctrl.ras_prot_chk_id[                           7: 0];
        ras_err_inj_mgr_ctrl.ras_prot_chk_id[$clog2(MAX_RAS_PROT_CHK_N)-1: 8] <= #TP (int_reg_id[24] & int_write_pulse[3]) ? lbc_cdm_data[31-(16-$clog2(MAX_RAS_PROT_CHK_N)):24] : ras_err_inj_mgr_ctrl.ras_prot_chk_id[$clog2(MAX_RAS_PROT_CHK_N)-1: 8];
    end
end

assign {ras_reg_0x63,ras_reg_0x62,ras_reg_0x61,ras_reg_0x60} = {
                                                                    {(16-$clog2(MAX_RAS_PROT_CHK_N)){1'b0}},
                                                                    ras_err_inj_mgr_ctrl.ras_prot_chk_id,
                                                                    3'b000,
                                                                    5'b00000,
                                                                    5'b0000_0,
                                                                    1'b0,
                                                                    2'b00
                                                               };


// =============================================================================
// Register Read Operation
// =============================================================================

always @(*) begin : read_data_PROC
     case (int_reg_id)
        25'b0_00000000_00000000_00000001 : int_ras_reg_data = {ras_reg_0x03, ras_reg_0x02, ras_reg_0x01, ras_reg_0x00};
        25'b0_00000000_00000000_00000010 : int_ras_reg_data = {ras_reg_0x07, ras_reg_0x06, ras_reg_0x05, ras_reg_0x04};
        25'b0_00000000_00000000_00000100 : int_ras_reg_data = {ras_reg_0x0B, ras_reg_0x0A, ras_reg_0x09, ras_reg_0x08};
        25'b0_00000000_00000000_00001000 : int_ras_reg_data = {ras_reg_0x0F, ras_reg_0x0E, ras_reg_0x0D, ras_reg_0x0C};
        25'b0_00000000_00000000_00010000 : int_ras_reg_data = {ras_reg_0x13, ras_reg_0x12, ras_reg_0x11, ras_reg_0x10};
        25'b0_00000000_00000000_00100000 : int_ras_reg_data = {ras_reg_0x17, ras_reg_0x16, ras_reg_0x15, ras_reg_0x14};
        25'b0_00000000_00000000_01000000 : int_ras_reg_data = {ras_reg_0x1B, ras_reg_0x1A, ras_reg_0x19, ras_reg_0x18};
        25'b0_00000000_00000000_10000000 : int_ras_reg_data = {ras_reg_0x1F, ras_reg_0x1E, ras_reg_0x1D, ras_reg_0x1C};
        25'b0_00000000_00000001_00000000 : int_ras_reg_data = {ras_reg_0x23, ras_reg_0x22, ras_reg_0x21, ras_reg_0x20};
        25'b0_00000000_00000010_00000000 : int_ras_reg_data = {ras_reg_0x27, ras_reg_0x26, ras_reg_0x25, ras_reg_0x24};
        25'b0_00000000_00000100_00000000 : int_ras_reg_data = {ras_reg_0x2B, ras_reg_0x2A, ras_reg_0x29, ras_reg_0x28};
        25'b0_00000000_00001000_00000000 : int_ras_reg_data = {ras_reg_0x2F, ras_reg_0x2E, ras_reg_0x2D, ras_reg_0x2C};
        25'b0_00000000_00010000_00000000 : int_ras_reg_data = {ras_reg_0x33, ras_reg_0x32, ras_reg_0x31, ras_reg_0x30};
        25'b0_00000000_00100000_00000000 : int_ras_reg_data = {ras_reg_0x37, ras_reg_0x36, ras_reg_0x35, ras_reg_0x34};
        25'b0_00000000_01000000_00000000 : int_ras_reg_data = {ras_reg_0x3B, ras_reg_0x3A, ras_reg_0x39, ras_reg_0x38};
        25'b0_00000000_10000000_00000000 : int_ras_reg_data = {ras_reg_0x3F, ras_reg_0x3E, ras_reg_0x3D, ras_reg_0x3C};
        25'b0_00000001_00000000_00000000 : int_ras_reg_data = {ras_reg_0x43, ras_reg_0x42, ras_reg_0x41, ras_reg_0x40};
        25'b0_00000010_00000000_00000000 : int_ras_reg_data = {ras_reg_0x47, ras_reg_0x46, ras_reg_0x45, ras_reg_0x44};
        25'b0_00000100_00000000_00000000 : int_ras_reg_data = {ras_reg_0x4B, ras_reg_0x4A, ras_reg_0x49, ras_reg_0x48};
        25'b0_00001000_00000000_00000000 : int_ras_reg_data = {ras_reg_0x4F, ras_reg_0x4E, ras_reg_0x4D, ras_reg_0x4C};
        25'b0_00010000_00000000_00000000 : int_ras_reg_data = {ras_reg_0x53, ras_reg_0x52, ras_reg_0x51, ras_reg_0x50};
        25'b0_00100000_00000000_00000000 : int_ras_reg_data = {ras_reg_0x57, ras_reg_0x56, ras_reg_0x55, ras_reg_0x54};
        25'b0_01000000_00000000_00000000 : int_ras_reg_data = {ras_reg_0x5B, ras_reg_0x5A, ras_reg_0x59, ras_reg_0x58};
        25'b0_10000000_00000000_00000000 : int_ras_reg_data = {ras_reg_0x5F, ras_reg_0x5E, ras_reg_0x5D, ras_reg_0x5C};
        25'b1_00000000_00000000_00000000 : int_ras_reg_data = {ras_reg_0x63, ras_reg_0x62, ras_reg_0x61, ras_reg_0x60};
        default                          : int_ras_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end

//----------------------------------------------
// DBI Register interface
//----------------------------------------------

wire                               ras_acc ;
reg                                ras_acc_1d ;
reg                                int_ack ;

assign ras_acc = |ras_reg_id ;

// rising edge detect ras_acc
always @(posedge core_clk or negedge sticky_rst_n) begin
   if (!sticky_rst_n) begin
      ras_acc_1d    <= #TP 1'b0 ;
      int_ack       <= #TP 1'b0 ;
    end
    else begin
       ras_acc_1d    <= #TP ras_acc ;
       int_ack       <= #TP ras_acc && !ras_acc_1d ;
    end
end

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        ras_reg_ack      <= #TP 1'b0 ;
        ras_reg_data     <= #TP 32'h0000_0000 ;
        ras_reg_ack_done <= #TP 1'b0 ;
    end
    else begin
        if ( int_ack ) begin
            ras_reg_ack  <= #TP 1'b1 ;
            ras_reg_data <= #TP int_ras_reg_data ;
        end
        else if ( ras_reg_ack_done ) begin
            ras_reg_ack      <= #TP 1'b0 ;
            ras_reg_ack_done <= #TP 1'b0 ;
        end
        else if ( ras_reg_ack ) begin
            ras_reg_ack_done <= #TP 1'b1 ;
        end
    end
end

// Function to extract write_pulse from active function
function automatic [3:0] get_write_pulse;
    input   [(4*NF)-1:0] data;
    input   [NF-1:0]     func;
    reg     [3:0]        result;
    integer bit_loc;
    integer i;
begin
    result = 4'h0;

    for (bit_loc=0; bit_loc<NF; bit_loc=bit_loc+1)
        if (func[bit_loc])
            for (i=0; i<4; i=i+1)
                result[i] = data[bit_loc*4+i];

    get_write_pulse = result;
end
endfunction

// Function to extract ras_reg_id from active function
function automatic [NR_REGS-1:0] get_reg_id;
    input   [(NR_REGS*NF)-1:0] data;
    input   [NF-1:0]         func;
    reg     [NR_REGS-1:0]    result;
    integer bit_loc;
    integer i;
begin
    result = 0;

    for (bit_loc=0; bit_loc<NF; bit_loc=bit_loc+1)
        if (func[bit_loc])
            for (i=0; i<NR_REGS; i=i+1)
                result[i] = data[bit_loc*NR_REGS+i];

    get_reg_id = result;
end
endfunction


`ifndef SYNTHESIS
`endif // SYNTHESIS

// -----------------------------------------------------------------------------
// Adding bcm for falsepath
// -----------------------------------------------------------------------------

endmodule //rpa_attr_ras_reg
