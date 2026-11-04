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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_rasdes_einj_reg.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains RAS D.E.S Error Injection registers.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/pcie_pkg.svh"
 
 module cdm_rasdes_einj_reg
   import DWC_pcie_ctl_pkg::N_XADM_IF;
   import DWC_pcie_ctl_pkg::N_XALI_IF;
   import DWC_pcie_ctl_pkg::NVC;
   import DWC_pcie_ctl_pkg::NVC_WD;
  import pcie_pkg::fc_type_e;
#(
    parameter INST          = 0,                                   // The uniquifying parameter for each port logic instance.
    parameter TP            = `TP                                  // Clock to Q delay (simulator insurance)

)
(
// -------------- Inputs ---------------
    input                              aux_clk,                             // Clock
    input                              sticky_rst_n,                        // Reset sticky registers only
 // --- Register access signals
    input  [31:0]                      cdm_reg_wdata,                       // Write Data 
    input                              lbc_cdm_dbi,                         // DBI Access
    input  [3:0]                       cdm_reg_write_pulse,                 // Write Byte Enables
    input  [63:0]                      cdm_reg_id,                          // Register access ID
    input wire                         cfg_err_inj_wr_disable,              // used to disable write access to error injection enable bits from the wire
 // --- Error Injection signals
    input  [2:0]                       rdlh_einj0_lcrc_evt,                 // Error injection 0 event flag
    input  [2:0]                       radm_einj0_ecrc_evt,                 // Error injection 0 Rx ECRC TLP event
    input                              xmlh_einj0_oscrc_evt,                // Error injection 0 CRC error event
    input  [1:0]                       xdlh_einj0_lcrc_evt,                 // Error injection 0 LCRC event
    input                              xdlh_einj0_fcrc_evt,                 // Error injection 0 ECRC event
    input  [1:0]                       xdlh_einj0_dllpcrc_evt,              // Error injection 0 DLLP CRC event
    input                              xadm_einj0_ecrc_evt,                 // Error injection 0 Tx ECRC TLP event
    input  [1:0]                       ras_des_einj1_exp_sequm_evt,     
    input                              ras_des_einj1_ack_nak_sequm_evt,
    input                              xdlh_einj2_nak_evt,                  // Error injection 2 NAK event
    input  [1:0]                       xmlh_einj3_osmsk_evt,                // Error injection 3 8b/10b K-code mask event
    input                              rtlh_einj4_fc_evt,                   // Error injection 4 FC event
    input                              xdlh_einj5_nultlp_evt,               // Error injection 5 nullified TLP event
    input                              xdlh_einj5_dup_evt,                  // Error injection 5 Duplicate TLP event
    input [$clog2(N_XALI_IF+2)-1:0]    xaim_einj6_tlp_evt,
// -------------- Outputs ---------------
 // --- Register access signals
    output reg [1:0]                   cdm_ei_ack,                          // Acknowledge from Timebase analysis module
    output reg [31:0]                  cdm_ei_rdata,                        // Read Data 
 // --- Error Injection signals
    output reg                         cdm_ras_des_einj0_enable,            // Error injection 0 enable
    output reg [7:0]                   cdm_ras_des_einj0_count,             // Error injection 0 count
    output reg [3:0]                   cdm_ras_des_einj0_crc_type,          // Error injection 0 CRC type
    output logic [2:0]                 cdm_ras_des_einj0_ecrc_vc_sel,       // Error injection 0 ECRC Virtual Channel Selection
    output fc_type_e                   cdm_ras_des_einj0_ecrc_fc_sel,       // Error injection 0 ECRC Flow Control Selection
    output logic                       cdm_ras_des_einj0_ecrc_intf_sel,     // Error injection 0 ECRC Interface Selection
    output reg                         cdm_ras_des_einj1_enable,            // Error injection 1 enable
    output reg                         cdm_ras_des_einj1_seq_type,          // Error injection 1 seq# type
    output reg [12:0]                  cdm_ras_des_einj1_bad_seq,           // Error injection 1 bad seq# value
    output reg [7:0]                   cdm_ras_des_einj1_count,             // Error injection 1 count
    output reg                         cdm_ras_des_einj2_enable,            // Error injection 2 enable
    output reg [1:0]                   cdm_ras_des_einj2_dllp_type,         // Error injection 2 DLLP type
    output reg                         cdm_ras_des_einj3_enable,            // Error injection 3 8b/10b K-code mask enable
    output reg [7:0]                   cdm_ras_des_einj3_count,             // Error injection 3 8b/10b K-code mask count
    output reg [2:0]                   cdm_ras_des_einj3_smb_type,          // Error injection 3 8b/10b K-code mask type
    output reg                         cdm_ras_des_einj4_enable,            // Error injection 4 enable
    output reg [2:0]                   cdm_ras_des_einj4_updfc_type,        // Error injection 4 UpdateFC type
    output reg [2:0]                   cdm_ras_des_einj4_vcnum,             // Error injection 4 VC number
    output reg [12:0]                  cdm_ras_des_einj4_badfc_value,       // Error injection 4 bad FC value
    output reg                         cdm_ras_des_einj5_enable,            // Error injection 5 enable
    output reg [7:0]                   cdm_ras_des_einj5_count,             // Error injection 5 count
    output reg                         cdm_ras_des_einj5_tlp_type,          // Error injection 5 tlp type (dup/nul)
    output reg                         cdm_ras_des_einj6_enable,            // Error Injection 6 Enable
    output reg [31:0]                  cdm_ras_des_einj6_cmp_point_h0,      // Error Injection 6 header compare point byte0-3
    output reg [31:0]                  cdm_ras_des_einj6_cmp_point_h1,      // Error Injection 6 header compare point byte4-7
    output reg [31:0]                  cdm_ras_des_einj6_cmp_point_h2,      // Error Injection 6 header compare point byte8-11
    output reg [31:0]                  cdm_ras_des_einj6_cmp_point_h3,      // Error Injection 6 header compare point byte12-15
    output reg [31:0]                  cdm_ras_des_einj6_cmp_value_h0,      // Error Injection 6 header compare value byte0-3
    output reg [31:0]                  cdm_ras_des_einj6_cmp_value_h1,      // Error Injection 6 header compare value byte4-7
    output reg [31:0]                  cdm_ras_des_einj6_cmp_value_h2,      // Error Injection 6 header compare value byte8-11
    output reg [31:0]                  cdm_ras_des_einj6_cmp_value_h3,      // Error Injection 6 header compare value byte12-15
    output reg [31:0]                  cdm_ras_des_einj6_chg_point_h0,      // Error Injection 6 header change point byte0-3
    output reg [31:0]                  cdm_ras_des_einj6_chg_point_h1,      // Error Injection 6 header change point byte4-7
    output reg [31:0]                  cdm_ras_des_einj6_chg_point_h2,      // Error Injection 6 header change point byte8-11
    output reg [31:0]                  cdm_ras_des_einj6_chg_point_h3,      // Error Injection 6 header change point byte12-15
    output reg [31:0]                  cdm_ras_des_einj6_chg_value_h0,      // Error Injection 6 header change value byte0-3
    output reg [31:0]                  cdm_ras_des_einj6_chg_value_h1,      // Error Injection 6 header change value byte4-7
    output reg [31:0]                  cdm_ras_des_einj6_chg_value_h2,      // Error Injection 6 header change value byte8-11
    output reg [31:0]                  cdm_ras_des_einj6_chg_value_h3,      // Error Injection 6 header change value byte12-15
    output reg [7:0]                   cdm_ras_des_einj6_count,             // Error Injection 6 count
    output reg                         cdm_ras_des_einj6_invt_cont,         // Error Injection 6 inversion control
    output reg [2:0]                   cdm_ras_des_einj6_pkt_type           // Error Injection 6 packet type
) ;

//---------------------------------------------------
//  Common
//---------------------------------------------------
    wire   [7:0]                       int_reg_0x30, int_reg_0x31, int_reg_0x32, int_reg_0x33 ;  // Read Data Address 0x30-0x33
    wire   [7:0]                       int_reg_0x34, int_reg_0x35, int_reg_0x36, int_reg_0x37 ;  // Read Data Address 0x34-0x37
    wire   [7:0]                       int_reg_0x38, int_reg_0x39, int_reg_0x3A, int_reg_0x3B ;  // Read Data Address 0x38-0x3B
    wire   [7:0]                       int_reg_0x3C, int_reg_0x3D, int_reg_0x3E, int_reg_0x3F ;  // Read Data Address 0x3C-0x3F
    wire   [7:0]                       int_reg_0x40, int_reg_0x41, int_reg_0x42, int_reg_0x43 ;  // Read Data Address 0x40-0x43
    wire   [7:0]                       int_reg_0x44, int_reg_0x45, int_reg_0x46, int_reg_0x47 ;  // Read Data Address 0x44-0x47
    wire   [7:0]                       int_reg_0x48, int_reg_0x49, int_reg_0x4A, int_reg_0x4B ;  // Read Data Address 0x48-0x4B
    wire   [7:0]                       int_reg_0x4C, int_reg_0x4D, int_reg_0x4E, int_reg_0x4F ;  // Read Data Address 0x4C-0x4F
    wire   [7:0]                       int_reg_0x50, int_reg_0x51, int_reg_0x52, int_reg_0x53 ;  // Read Data Address 0x50-0x53
    wire   [7:0]                       int_reg_0x54, int_reg_0x55, int_reg_0x56, int_reg_0x57 ;  // Read Data Address 0x54-0x57
    wire   [7:0]                       int_reg_0x58, int_reg_0x59, int_reg_0x5A, int_reg_0x5B ;  // Read Data Address 0x58-0x5B
    wire   [7:0]                       int_reg_0x5C, int_reg_0x5D, int_reg_0x5E, int_reg_0x5F ;  // Read Data Address 0x5C-0x5F
    wire   [7:0]                       int_reg_0x60, int_reg_0x61, int_reg_0x62, int_reg_0x63 ;  // Read Data Address 0x60-0x63
    wire   [7:0]                       int_reg_0x64, int_reg_0x65, int_reg_0x66, int_reg_0x67 ;  // Read Data Address 0x64-0x67
    wire   [7:0]                       int_reg_0x68, int_reg_0x69, int_reg_0x6A, int_reg_0x6B ;  // Read Data Address 0x68-0x6B
    wire   [7:0]                       int_reg_0x6C, int_reg_0x6D, int_reg_0x6E, int_reg_0x6F ;  // Read Data Address 0x6C-0x6F
    wire   [7:0]                       int_reg_0x70, int_reg_0x71, int_reg_0x72, int_reg_0x73 ;  // Read Data Address 0x70-0x73
    wire   [7:0]                       int_reg_0x74, int_reg_0x75, int_reg_0x76, int_reg_0x77 ;  // Read Data Address 0x74-0x77
    wire   [7:0]                       int_reg_0x78, int_reg_0x79, int_reg_0x7A, int_reg_0x7B ;  // Read Data Address 0x78-0x7B
    wire   [7:0]                       int_reg_0x7C, int_reg_0x7D, int_reg_0x7E, int_reg_0x7F ;  // Read Data Address 0x7C-0x7F
    wire   [7:0]                       int_reg_0x80, int_reg_0x81, int_reg_0x82, int_reg_0x83 ;  // Read Data Address 0x80-0x83
    wire   [7:0]                       int_reg_0x84, int_reg_0x85, int_reg_0x86, int_reg_0x87 ;  // Read Data Address 0x84-0x87
    wire   [7:0]                       int_reg_0x88, int_reg_0x89, int_reg_0x8A, int_reg_0x8B ;  // Read Data Address 0x88-0x8B
    wire   [7:0]                       int_reg_0x8C, int_reg_0x8D, int_reg_0x8E, int_reg_0x8F ;  // Read Data Address 0x8C-0x8F

    reg    [7:0]                       cdm_ras_des_einj2_count;
    reg    [7:0]                       cdm_ras_des_einj4_count;

    wire   [7:0]                       int_einj0_evt ;
    wire   [7:0]                       int_einj1_evt ;
    wire   [7:0]                       int_einj2_evt ;
    wire   [7:0]                       int_einj3_evt ;
    wire   [7:0]                       int_einj4_evt ;
    wire   [7:0]                       int_einj5_evt ;
    wire   [7:0]                       int_einj6_evt ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 12
// PCIE Offset      - `RAS_DES_PTR + 30h
// length           - 4 byte
// Cfig register    - int_reg_0x33, int_reg_0x32, int_reg_0x31, int_reg_0x30
// register         - Error injection 0 enable  [0] : RW
//                  - Error injection 1 enable  [1] : RW
//                  - Error injection 2 enable  [2] : RW
//                  - Error injection 3 enable  [3] : RW
//                  - Error injection 4 enable  [4] : RW
//                  - Error injection 5 enable  [5] : RW
//                  - Error injection 6 enable  [6] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj0_enable <= #TP 1'b0 ;
        end
        else begin
            if ( cdm_reg_id[12] & cdm_reg_write_pulse[0] & ( ~cfg_err_inj_wr_disable | lbc_cdm_dbi ) ) begin
                cdm_ras_des_einj0_enable <= #TP cdm_reg_wdata[0] ;
            end
            else if ( (cdm_ras_des_einj0_count<=int_einj0_evt) && (cdm_ras_des_einj0_count!=8'd0) ) begin
                cdm_ras_des_einj0_enable <= #TP 1'b0 ;
            end
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj1_enable <= #TP 1'b0 ;
        end
        else begin
            if ( cdm_reg_id[12] & cdm_reg_write_pulse[0] & ( ~cfg_err_inj_wr_disable | lbc_cdm_dbi ) ) begin
                cdm_ras_des_einj1_enable <= #TP cdm_reg_wdata[1] ;
            end
            else if ( (cdm_ras_des_einj1_count<=int_einj1_evt) && (cdm_ras_des_einj1_count!=8'd0) ) begin
                cdm_ras_des_einj1_enable <= #TP 1'b0 ;
            end
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj2_enable <= #TP 1'b0 ;
        end
        else begin
            if ( cdm_reg_id[12] & cdm_reg_write_pulse[0] & ( ~cfg_err_inj_wr_disable | lbc_cdm_dbi ) ) begin
                cdm_ras_des_einj2_enable <= #TP cdm_reg_wdata[2] ;
            end
            else if ( (cdm_ras_des_einj2_count<=int_einj2_evt) && (cdm_ras_des_einj2_count!=8'd0) ) begin
                cdm_ras_des_einj2_enable <= #TP 1'b0 ;
            end
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj3_enable <= #TP 1'b0 ;
        end
        else begin
            if ( cdm_reg_id[12] & cdm_reg_write_pulse[0] & ( ~cfg_err_inj_wr_disable | lbc_cdm_dbi ) ) begin
                cdm_ras_des_einj3_enable <= #TP cdm_reg_wdata[3] ;
            end
            else if ( (cdm_ras_des_einj3_count<=int_einj3_evt) && (cdm_ras_des_einj3_count!=8'd0) ) begin
                cdm_ras_des_einj3_enable <= #TP 1'b0 ;
            end
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj4_enable <= #TP 1'b0 ;
        end
        else begin
            if ( cdm_reg_id[12] & cdm_reg_write_pulse[0] & ( ~cfg_err_inj_wr_disable | lbc_cdm_dbi ) ) begin
                cdm_ras_des_einj4_enable <= #TP cdm_reg_wdata[4] ;
            end
            else if ( (cdm_ras_des_einj4_count<=int_einj4_evt) && (cdm_ras_des_einj4_count!=8'd0) ) begin
                cdm_ras_des_einj4_enable <= #TP 1'b0 ;
            end
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj5_enable <= #TP 1'b0 ;
        end
        else begin
            if ( cdm_reg_id[12] & cdm_reg_write_pulse[0] & ( ~cfg_err_inj_wr_disable | lbc_cdm_dbi ) ) begin
                cdm_ras_des_einj5_enable <= #TP cdm_reg_wdata[5] ;
            end
            else if ( (cdm_ras_des_einj5_count<=int_einj5_evt) && (cdm_ras_des_einj5_count!=8'd0) ) begin
                cdm_ras_des_einj5_enable <= #TP 1'b0 ;
            end
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_enable <= #TP 1'b0 ;
        end
        else begin
            if ( cdm_reg_id[12] & cdm_reg_write_pulse[0] & ( ~cfg_err_inj_wr_disable | lbc_cdm_dbi ) ) begin
                cdm_ras_des_einj6_enable <= #TP cdm_reg_wdata[6] ;
            end
            else if ( (cdm_ras_des_einj6_count<=int_einj6_evt) && (cdm_ras_des_einj6_count!=8'd0) ) begin
                cdm_ras_des_einj6_enable <= #TP 1'b0 ;
            end
        end
    end

    assign {int_reg_0x33, int_reg_0x32, int_reg_0x31, int_reg_0x30} = { 25'd0                          // [31:7]
                                                                      , cdm_ras_des_einj6_enable       // [6]
                                                                      , cdm_ras_des_einj5_enable       // [5]
                                                                      , cdm_ras_des_einj4_enable       // [4]
                                                                      , cdm_ras_des_einj3_enable       // [3]
                                                                      , cdm_ras_des_einj2_enable       // [2]
                                                                      , cdm_ras_des_einj1_enable       // [1]
                                                                      , cdm_ras_des_einj0_enable       // [0]
                                                                      } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 13
// PCIE Offset      - `RAS_DES_PTR + 34h
// length           - 4 byte
// Cfig register    - int_reg_0x37, int_reg_0x36, int_reg_0x35, int_reg_0x34
// register         - EINJ0 count [7:0] : RW
//                  - EINJ0 CRC type [11:8] : RW
//                  - ECRC VC SEL [18:16] : RW
//                  - ECRC FC SEL [21:20] : RW
//                  - ECRC INTF SEL [24:24] : RW
// -----------------------------------------------------------------------------
    assign int_einj0_evt = |rdlh_einj0_lcrc_evt    ? {5'd0,rdlh_einj0_lcrc_evt} :
                           |radm_einj0_ecrc_evt    ? {5'd0,radm_einj0_ecrc_evt} :
                           xmlh_einj0_oscrc_evt    ? 8'd1 :
                           |xdlh_einj0_lcrc_evt    ? {6'd0,xdlh_einj0_lcrc_evt} :
                           xdlh_einj0_fcrc_evt     ? 8'd1 :
                           xadm_einj0_ecrc_evt     ? 8'd1 :
                           |xdlh_einj0_dllpcrc_evt ? {6'd0,xdlh_einj0_dllpcrc_evt} :
                                                     8'd0 ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj0_count <= #TP 8'd0 ;
        end
        else begin
            if ( cdm_reg_id[13] & cdm_reg_write_pulse[0]) begin
                cdm_ras_des_einj0_count <= #TP cdm_reg_wdata[7:0] ;
            end
            else if ( cdm_ras_des_einj0_count > 8'd0 ) begin
                if ( cdm_ras_des_einj0_count <= int_einj0_evt ) cdm_ras_des_einj0_count <= #TP 8'd0 ;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The loss is avoided by the underflow control above.
                else                                            cdm_ras_des_einj0_count <= #TP cdm_ras_des_einj0_count - int_einj0_evt ;
// spyglass enable_block W164a
            end
            
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj0_crc_type <= #TP 4'd0 ;
        end
        else begin
            cdm_ras_des_einj0_crc_type <= #TP (cdm_reg_id[13] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[11:8] : cdm_ras_des_einj0_crc_type ;
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj0_ecrc_vc_sel <= #TP '0;
        end else begin
            if (cdm_reg_id[13] & cdm_reg_write_pulse[2]) begin
                cdm_ras_des_einj0_ecrc_vc_sel <= #TP cdm_reg_wdata[18:16];
            end
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj0_ecrc_fc_sel <= #TP fc_type_e'('0);
        end else begin
            if (cdm_reg_id[13] & cdm_reg_write_pulse[2]) begin
                cdm_ras_des_einj0_ecrc_fc_sel <= #TP fc_type_e'(cdm_reg_wdata[21:20]);
            end
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj0_ecrc_intf_sel <= #TP '0;
        end else begin
            if (cdm_reg_id[13] & cdm_reg_write_pulse[3]) begin
                cdm_ras_des_einj0_ecrc_intf_sel <= #TP cdm_reg_wdata[24];
            end
        end
    end

    assign {int_reg_0x37, int_reg_0x36, int_reg_0x35, int_reg_0x34} = {
                                                                        7'b0,                            // [31:25]
                                                                        cdm_ras_des_einj0_ecrc_intf_sel, // [24:24]
                                                                        2'b0,                            // [23:22]
                                                                        cdm_ras_des_einj0_ecrc_fc_sel,   // [21:20]
                                                                        1'b0,                            // [19:19]
                                                                        cdm_ras_des_einj0_ecrc_vc_sel,   // [18:16]
                                                                        4'b0,                            // [15:12]
                                                                        cdm_ras_des_einj0_crc_type,      // [11:8]
                                                                        cdm_ras_des_einj0_count          // [7:0]
                                                                      } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 14
// PCIE Offset      - `RAS_DES_PTR + 38h
// length           - 4 byte
// Cfig register    - int_reg_0x3B, int_reg_0x3A, int_reg_0x39, int_reg_0x38
// register         - EINJ1 count [7:0] : RW
//                  - EINJ1 seqnum type [8] : RW
//                  - EINJ1 bad seqnum [28:16] : RW
// -----------------------------------------------------------------------------
    assign int_einj1_evt = |ras_des_einj1_exp_sequm_evt     ? {6'd0, ras_des_einj1_exp_sequm_evt} :
                            ras_des_einj1_ack_nak_sequm_evt ? 8'd1 
                                                            : 8'd0 ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj1_count <= #TP 8'd0 ;
        end
        else begin
            if ( cdm_reg_id[14] & cdm_reg_write_pulse[0]) begin
                cdm_ras_des_einj1_count <= #TP cdm_reg_wdata[7:0] ;
            end
            else if ( cdm_ras_des_einj1_count > 8'd0 ) begin
                if ( cdm_ras_des_einj1_count <= int_einj1_evt ) cdm_ras_des_einj1_count <= #TP 8'd0 ;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The loss is avoided by the underflow control above.
                else                                            cdm_ras_des_einj1_count <= #TP cdm_ras_des_einj1_count - int_einj1_evt ;
// spyglass enable_block W164a
            end
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj1_seq_type <= #TP 1'b0 ;
            cdm_ras_des_einj1_bad_seq  <= #TP 13'd0 ;
        end
        else begin
            cdm_ras_des_einj1_seq_type      <= #TP (cdm_reg_id[14] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[8]     : cdm_ras_des_einj1_seq_type ;
            cdm_ras_des_einj1_bad_seq[7:0]  <= #TP (cdm_reg_id[14] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj1_bad_seq[7:0] ;
            cdm_ras_des_einj1_bad_seq[12:8] <= #TP (cdm_reg_id[14] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[28:24] : cdm_ras_des_einj1_bad_seq[12:8] ;
        end
    end

    assign {int_reg_0x3B, int_reg_0x3A, int_reg_0x39, int_reg_0x38} = { 3'd0                               // [31:29]
                                                                      , cdm_ras_des_einj1_bad_seq          // [28:16]
                                                                      , 7'd0                               // [15:9]
                                                                      , cdm_ras_des_einj1_seq_type         // [8]
                                                                      , cdm_ras_des_einj1_count            // [7:0]
                                                                      } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 15
// PCIE Offset      - `RAS_DES_PTR + 3Ch
// length           - 4 byte
// Cfig register    - int_reg_0x3F, int_reg_0x3E, int_reg_0x3D, int_reg_0x3C
// register         - EINJ2 count [7:0] : RW
//                  - EINJ2 DLLP type [9:8] : RW
// -----------------------------------------------------------------------------
    assign int_einj2_evt = xdlh_einj2_nak_evt ? 8'd1 : 8'd0 ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj2_count <= #TP 8'd0 ;
        end
        else begin
            if ( cdm_reg_id[15] & cdm_reg_write_pulse[0]) begin
                cdm_ras_des_einj2_count <= #TP cdm_reg_wdata[7:0] ;
            end
            else if ( cdm_ras_des_einj2_count > 8'd0 ) begin
                if ( cdm_ras_des_einj2_count <= int_einj2_evt ) cdm_ras_des_einj2_count <= #TP 8'd0 ;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The loss is avoided by the underflow control above.
                else                                            cdm_ras_des_einj2_count <= #TP cdm_ras_des_einj2_count - int_einj2_evt ;
// spyglass enable_block W164a
            end
            
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj2_dllp_type <= #TP 2'd0 ;
        end
        else begin
            cdm_ras_des_einj2_dllp_type <= #TP (cdm_reg_id[15] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[9:8] : cdm_ras_des_einj2_dllp_type ;
        end
    end

    assign {int_reg_0x3F, int_reg_0x3E, int_reg_0x3D, int_reg_0x3C} = { 22'd0
                                                                      , cdm_ras_des_einj2_dllp_type     // [9:8]
                                                                      , cdm_ras_des_einj2_count         // [7:0]
                                                                      } ;


// -----------------------------------------------------------------------------
// cdm_reg_id       - 16
// PCIE Offset      - `RAS_DES_PTR + 40h
// length           - 4 byte
// Cfig register    - int_reg_0x43, int_reg_0x42, int_reg_0x41, int_reg_0x40
// register         - EINJ3 count [7:0] : RW
//                  - EINJ3 symbol type [10:8] : RW
// -----------------------------------------------------------------------------
    assign int_einj3_evt = {6'd0, xmlh_einj3_osmsk_evt} ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj3_count <= #TP 8'd0 ;
        end
        else begin
            if ( cdm_reg_id[16] & cdm_reg_write_pulse[0]) begin
                cdm_ras_des_einj3_count <= #TP cdm_reg_wdata[7:0] ;
            end
            else if ( cdm_ras_des_einj3_count > 8'd0 ) begin
                if ( cdm_ras_des_einj3_count <= int_einj3_evt ) cdm_ras_des_einj3_count <= #TP 8'd0 ;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The loss is avoided by the underflow control above.
                else                                            cdm_ras_des_einj3_count <= #TP cdm_ras_des_einj3_count - int_einj3_evt ;
// spyglass enable_block W164a
            end
            
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj3_smb_type <= #TP 3'd0 ;
        end
        else begin
            cdm_ras_des_einj3_smb_type <= #TP (cdm_reg_id[16] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[10:8] : cdm_ras_des_einj3_smb_type ;
        end
    end

    assign {int_reg_0x43, int_reg_0x42, int_reg_0x41, int_reg_0x40} = { 21'd0                       // [31:11]
                                                                      , cdm_ras_des_einj3_smb_type  // [10:8]
                                                                      , cdm_ras_des_einj3_count     // [7:0]
                                                                      } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 17
// PCIE Offset      - `RAS_DES_PTR + 44h
// length           - 4 byte
// Cfig register    - int_reg_0x47, int_reg_0x46, int_reg_0x45, int_reg_0x44
// register         - EINJ4 count [7:0] : RW
//                  - EINJ4 updfc type [10:8] : RW
//                  - EINJ4 VC number [14:12] : RW
//                  - EINJ4 bad updfc value [28:16] : RW
// -----------------------------------------------------------------------------
    assign int_einj4_evt = rtlh_einj4_fc_evt ? 8'd1 : 8'd0 ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj4_count <= #TP 8'd0 ;
        end
        else begin
            if ( cdm_reg_id[17] & cdm_reg_write_pulse[0]) begin
                cdm_ras_des_einj4_count <= #TP cdm_reg_wdata[7:0] ;
            end
            else if ( cdm_ras_des_einj4_count > 8'd0 ) begin
                if ( cdm_ras_des_einj4_count <= int_einj4_evt ) cdm_ras_des_einj4_count <= #TP 8'd0 ;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The loss is avoided by the underflow control above.
                else                                            cdm_ras_des_einj4_count <= #TP cdm_ras_des_einj4_count - int_einj4_evt ;
// spyglass enable_block W164a
            end
            
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj4_updfc_type  <= #TP 3'd0 ;
            cdm_ras_des_einj4_vcnum       <= #TP 3'd0 ;
            cdm_ras_des_einj4_badfc_value <= #TP 13'd0 ;
        end
        else begin
            cdm_ras_des_einj4_updfc_type        <= #TP (cdm_reg_id[17] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[10:8]  : cdm_ras_des_einj4_updfc_type ;
            cdm_ras_des_einj4_vcnum             <= #TP (cdm_reg_id[17] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[14:12] : cdm_ras_des_einj4_vcnum ;
            cdm_ras_des_einj4_badfc_value[7:0]  <= #TP (cdm_reg_id[17] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj4_badfc_value[7:0] ;
            cdm_ras_des_einj4_badfc_value[12:8] <= #TP (cdm_reg_id[17] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[28:24] : cdm_ras_des_einj4_badfc_value[12:8] ;
        end
    end

    assign {int_reg_0x47, int_reg_0x46, int_reg_0x45, int_reg_0x44} = { 3'd0                            // [31:29]
                                                                      , cdm_ras_des_einj4_badfc_value   // [28:16]
                                                                      , 1'b0                            // [15]
                                                                      , cdm_ras_des_einj4_vcnum         // [14:12]
                                                                      , 1'b0                            // [11]
                                                                      , cdm_ras_des_einj4_updfc_type    // [10:8]
                                                                      , cdm_ras_des_einj4_count         // [7:0]
                                                                      } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 18
// PCIE Offset      - `RAS_DES_PTR + 48h
// length           - 4 byte
// Cfig register    - int_reg_0x4B, int_reg_0x4A, int_reg_0x49, int_reg_0x48
// register         - EINJ5 count [7:0] : RW
//                  - EINJ5 specified TLP [8] : RW
// -----------------------------------------------------------------------------
    assign int_einj5_evt = xdlh_einj5_nultlp_evt ? 8'd1 :
                           xdlh_einj5_dup_evt    ? 8'd1 :
                                                   8'd0 ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj5_count <= #TP 8'd0 ;
        end
        else begin
            if ( cdm_reg_id[18] & cdm_reg_write_pulse[0]) begin
                cdm_ras_des_einj5_count <= #TP cdm_reg_wdata[7:0] ;
            end
            else if ( cdm_ras_des_einj5_count > 8'd0 ) begin
                if ( cdm_ras_des_einj5_count <= int_einj5_evt ) cdm_ras_des_einj5_count <= #TP 8'd0 ;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The loss is avoided by the underflow control above.
                else                                            cdm_ras_des_einj5_count <= #TP cdm_ras_des_einj5_count - int_einj5_evt ;
// spyglass enable_block W164a
            end
            
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj5_tlp_type <= #TP 1'b0 ;
        end
        else begin
            cdm_ras_des_einj5_tlp_type <= #TP (cdm_reg_id[18] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[8]   : cdm_ras_des_einj5_tlp_type ;
        end
    end

    assign {int_reg_0x4B, int_reg_0x4A, int_reg_0x49, int_reg_0x48} = { 23'd0                         // [31:9]
                                                                      , cdm_ras_des_einj5_tlp_type    // [8]
                                                                      , cdm_ras_des_einj5_count       // [7:0]
                                                                      } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 19
// PCIE Offset      - `RAS_DES_PTR + 4Ch
// length           - 4 byte
// Cfig register    - int_reg_0x4F, int_reg_0x4E, int_reg_0x4D, int_reg_0x4C
// register         - EINJ6 compare point h0 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_cmp_point_h0 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_cmp_point_h0[7:0]   <= #TP (cdm_reg_id[19] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_cmp_point_h0[7:0] ;
            cdm_ras_des_einj6_cmp_point_h0[15:8]  <= #TP (cdm_reg_id[19] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_cmp_point_h0[15:8] ;
            cdm_ras_des_einj6_cmp_point_h0[23:16] <= #TP (cdm_reg_id[19] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_cmp_point_h0[23:16] ;
            cdm_ras_des_einj6_cmp_point_h0[31:24] <= #TP (cdm_reg_id[19] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_cmp_point_h0[31:24] ;
        end
    end

    assign {int_reg_0x4F, int_reg_0x4E, int_reg_0x4D, int_reg_0x4C} = { cdm_ras_des_einj6_cmp_point_h0 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 20
// PCIE Offset      - `RAS_DES_PTR + 50h
// length           - 4 byte
// Cfig register    - int_reg_0x53, int_reg_0x52, int_reg_0x51, int_reg_0x50
// register         - EINJ6 compare point h1 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_cmp_point_h1 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_cmp_point_h1[7:0]   <= #TP (cdm_reg_id[20] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_cmp_point_h1[7:0] ;
            cdm_ras_des_einj6_cmp_point_h1[15:8]  <= #TP (cdm_reg_id[20] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_cmp_point_h1[15:8] ;
            cdm_ras_des_einj6_cmp_point_h1[23:16] <= #TP (cdm_reg_id[20] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_cmp_point_h1[23:16] ;
            cdm_ras_des_einj6_cmp_point_h1[31:24] <= #TP (cdm_reg_id[20] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_cmp_point_h1[31:24] ;
        end
    end

    assign {int_reg_0x53, int_reg_0x52, int_reg_0x51, int_reg_0x50} = { cdm_ras_des_einj6_cmp_point_h1 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 21
// PCIE Offset      - `RAS_DES_PTR + 54h
// length           - 4 byte
// Cfig register    - int_reg_0x57, int_reg_0x56, int_reg_0x55, int_reg_0x54
// register         - EINJ6 compare point h2 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_cmp_point_h2 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_cmp_point_h2[7:0]   <= #TP (cdm_reg_id[21] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_cmp_point_h2[7:0] ;
            cdm_ras_des_einj6_cmp_point_h2[15:8]  <= #TP (cdm_reg_id[21] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_cmp_point_h2[15:8] ;
            cdm_ras_des_einj6_cmp_point_h2[23:16] <= #TP (cdm_reg_id[21] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_cmp_point_h2[23:16] ;
            cdm_ras_des_einj6_cmp_point_h2[31:24] <= #TP (cdm_reg_id[21] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_cmp_point_h2[31:24] ;
        end
    end

    assign {int_reg_0x57, int_reg_0x56, int_reg_0x55, int_reg_0x54} = { cdm_ras_des_einj6_cmp_point_h2 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 22
// PCIE Offset      - `RAS_DES_PTR + 58h
// length           - 4 byte
// Cfig register    - int_reg_0x5B, int_reg_0x5A, int_reg_0x59, int_reg_0x58
// register         - EINJ6 compare point h3 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_cmp_point_h3 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_cmp_point_h3[7:0]   <= #TP (cdm_reg_id[22] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_cmp_point_h3[7:0] ;
            cdm_ras_des_einj6_cmp_point_h3[15:8]  <= #TP (cdm_reg_id[22] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_cmp_point_h3[15:8] ;
            cdm_ras_des_einj6_cmp_point_h3[23:16] <= #TP (cdm_reg_id[22] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_cmp_point_h3[23:16] ;
            cdm_ras_des_einj6_cmp_point_h3[31:24] <= #TP (cdm_reg_id[22] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_cmp_point_h3[31:24] ;
        end
    end

    assign {int_reg_0x5B, int_reg_0x5A, int_reg_0x59, int_reg_0x58} = { cdm_ras_des_einj6_cmp_point_h3 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 23
// PCIE Offset      - `RAS_DES_PTR + 5Ch
// length           - 4 byte
// Cfig register    - int_reg_0x5F, int_reg_0x5E, int_reg_0x5D, int_reg_0x5C
// register         - EINJ6 compare value h0 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_cmp_value_h0 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_cmp_value_h0[7:0]   <= #TP (cdm_reg_id[23] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_cmp_value_h0[7:0] ;
            cdm_ras_des_einj6_cmp_value_h0[15:8]  <= #TP (cdm_reg_id[23] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_cmp_value_h0[15:8] ;
            cdm_ras_des_einj6_cmp_value_h0[23:16] <= #TP (cdm_reg_id[23] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_cmp_value_h0[23:16] ;
            cdm_ras_des_einj6_cmp_value_h0[31:24] <= #TP (cdm_reg_id[23] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_cmp_value_h0[31:24] ;
        end
    end

    assign {int_reg_0x5F, int_reg_0x5E, int_reg_0x5D, int_reg_0x5C} = { cdm_ras_des_einj6_cmp_value_h0 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 24
// PCIE Offset      - `RAS_DES_PTR + 60h
// length           - 4 byte
// Cfig register    - int_reg_0x63, int_reg_0x62, int_reg_0x61, int_reg_0x60
// register         - EINJ6 compare value h1 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_cmp_value_h1 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_cmp_value_h1[7:0]   <= #TP (cdm_reg_id[24] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_cmp_value_h1[7:0] ;
            cdm_ras_des_einj6_cmp_value_h1[15:8]  <= #TP (cdm_reg_id[24] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_cmp_value_h1[15:8] ;
            cdm_ras_des_einj6_cmp_value_h1[23:16] <= #TP (cdm_reg_id[24] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_cmp_value_h1[23:16] ;
            cdm_ras_des_einj6_cmp_value_h1[31:24] <= #TP (cdm_reg_id[24] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_cmp_value_h1[31:24] ;
        end
    end

    assign {int_reg_0x63, int_reg_0x62, int_reg_0x61, int_reg_0x60} = { cdm_ras_des_einj6_cmp_value_h1 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 25
// PCIE Offset      - `RAS_DES_PTR + 64h
// length           - 4 byte
// Cfig register    - int_reg_0x67, int_reg_0x66, int_reg_0x65, int_reg_0x64
// register         - EINJ6 compare value h2 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_cmp_value_h2 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_cmp_value_h2[7:0]   <= #TP (cdm_reg_id[25] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_cmp_value_h2[7:0] ;
            cdm_ras_des_einj6_cmp_value_h2[15:8]  <= #TP (cdm_reg_id[25] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_cmp_value_h2[15:8] ;
            cdm_ras_des_einj6_cmp_value_h2[23:16] <= #TP (cdm_reg_id[25] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_cmp_value_h2[23:16] ;
            cdm_ras_des_einj6_cmp_value_h2[31:24] <= #TP (cdm_reg_id[25] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_cmp_value_h2[31:24] ;
        end
    end

    assign {int_reg_0x67, int_reg_0x66, int_reg_0x65, int_reg_0x64} = { cdm_ras_des_einj6_cmp_value_h2 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 26
// PCIE Offset      - `RAS_DES_PTR + 68h
// length           - 4 byte
// Cfig register    - int_reg_0x6B, int_reg_0x6A, int_reg_0x69, int_reg_0x68
// register         - EINJ6 compare value h3 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_cmp_value_h3 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_cmp_value_h3[7:0]   <= #TP (cdm_reg_id[26] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_cmp_value_h3[7:0] ;
            cdm_ras_des_einj6_cmp_value_h3[15:8]  <= #TP (cdm_reg_id[26] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_cmp_value_h3[15:8] ;
            cdm_ras_des_einj6_cmp_value_h3[23:16] <= #TP (cdm_reg_id[26] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_cmp_value_h3[23:16] ;
            cdm_ras_des_einj6_cmp_value_h3[31:24] <= #TP (cdm_reg_id[26] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_cmp_value_h3[31:24] ;
        end
    end

    assign {int_reg_0x6B, int_reg_0x6A, int_reg_0x69, int_reg_0x68} = { cdm_ras_des_einj6_cmp_value_h3 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 27
// PCIE Offset      - `RAS_DES_PTR + 6Ch
// length           - 4 byte
// Cfig register    - int_reg_0x6F, int_reg_0x6E, int_reg_0x6D, int_reg_0x6C
// register         - EINJ6 change point h0 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_chg_point_h0 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_chg_point_h0[7:0]   <= #TP (cdm_reg_id[27] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_chg_point_h0[7:0] ;
            cdm_ras_des_einj6_chg_point_h0[15:8]  <= #TP (cdm_reg_id[27] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_chg_point_h0[15:8] ;
            cdm_ras_des_einj6_chg_point_h0[23:16] <= #TP (cdm_reg_id[27] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_chg_point_h0[23:16] ;
            cdm_ras_des_einj6_chg_point_h0[31:24] <= #TP (cdm_reg_id[27] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_chg_point_h0[31:24] ;
        end
    end

    assign {int_reg_0x6F, int_reg_0x6E, int_reg_0x6D, int_reg_0x6C} = { cdm_ras_des_einj6_chg_point_h0 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 28
// PCIE Offset      - `RAS_DES_PTR + 70h
// length           - 4 byte
// Cfig register    - int_reg_0x73, int_reg_0x72, int_reg_0x71, int_reg_0x70
// register         - EINJ6 change point h1 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_chg_point_h1 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_chg_point_h1[7:0]   <= #TP (cdm_reg_id[28] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_chg_point_h1[7:0] ;
            cdm_ras_des_einj6_chg_point_h1[15:8]  <= #TP (cdm_reg_id[28] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_chg_point_h1[15:8] ;
            cdm_ras_des_einj6_chg_point_h1[23:16] <= #TP (cdm_reg_id[28] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_chg_point_h1[23:16] ;
            cdm_ras_des_einj6_chg_point_h1[31:24] <= #TP (cdm_reg_id[28] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_chg_point_h1[31:24] ;
        end
    end

    assign {int_reg_0x73, int_reg_0x72, int_reg_0x71, int_reg_0x70} = { cdm_ras_des_einj6_chg_point_h1 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 29
// PCIE Offset      - `RAS_DES_PTR + 74h
// length           - 4 byte
// Cfig register    - int_reg_0x77, int_reg_0x76, int_reg_0x75, int_reg_0x74
// register         - EINJ6 change point h2 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_chg_point_h2 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_chg_point_h2[7:0]   <= #TP (cdm_reg_id[29] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_chg_point_h2[7:0] ;
            cdm_ras_des_einj6_chg_point_h2[15:8]  <= #TP (cdm_reg_id[29] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_chg_point_h2[15:8] ;
            cdm_ras_des_einj6_chg_point_h2[23:16] <= #TP (cdm_reg_id[29] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_chg_point_h2[23:16] ;
            cdm_ras_des_einj6_chg_point_h2[31:24] <= #TP (cdm_reg_id[29] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_chg_point_h2[31:24] ;
        end
    end

    assign {int_reg_0x77, int_reg_0x76, int_reg_0x75, int_reg_0x74} = { cdm_ras_des_einj6_chg_point_h2 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 30
// PCIE Offset      - `RAS_DES_PTR + 78h
// length           - 4 byte
// Cfig register    - int_reg_0x7B, int_reg_0x7A, int_reg_0x79, int_reg_0x78
// register         - EINJ6 change point h3 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_chg_point_h3 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_chg_point_h3[7:0]   <= #TP (cdm_reg_id[30] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_chg_point_h3[7:0] ;
            cdm_ras_des_einj6_chg_point_h3[15:8]  <= #TP (cdm_reg_id[30] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_chg_point_h3[15:8] ;
            cdm_ras_des_einj6_chg_point_h3[23:16] <= #TP (cdm_reg_id[30] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_chg_point_h3[23:16] ;
            cdm_ras_des_einj6_chg_point_h3[31:24] <= #TP (cdm_reg_id[30] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_chg_point_h3[31:24] ;
        end
    end

    assign {int_reg_0x7B, int_reg_0x7A, int_reg_0x79, int_reg_0x78} = { cdm_ras_des_einj6_chg_point_h3 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 31
// PCIE Offset      - `RAS_DES_PTR + 7Ch
// length           - 4 byte
// Cfig register    - int_reg_0x7F, int_reg_0x7E, int_reg_0x7D, int_reg_0x7C
// register         - EINJ6 change value h0 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_chg_value_h0 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_chg_value_h0[7:0]   <= #TP (cdm_reg_id[31] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_chg_value_h0[7:0] ;
            cdm_ras_des_einj6_chg_value_h0[15:8]  <= #TP (cdm_reg_id[31] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_chg_value_h0[15:8] ;
            cdm_ras_des_einj6_chg_value_h0[23:16] <= #TP (cdm_reg_id[31] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_chg_value_h0[23:16] ;
            cdm_ras_des_einj6_chg_value_h0[31:24] <= #TP (cdm_reg_id[31] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_chg_value_h0[31:24] ;
        end
    end

    assign {int_reg_0x7F, int_reg_0x7E, int_reg_0x7D, int_reg_0x7C} = { cdm_ras_des_einj6_chg_value_h0 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 32
// PCIE Offset      - `RAS_DES_PTR + 80h
// length           - 4 byte
// Cfig register    - int_reg_0x83, int_reg_0x82, int_reg_0x81, int_reg_0x80
// register         - EINJ6 change value h1 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_chg_value_h1 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_chg_value_h1[7:0]   <= #TP (cdm_reg_id[32] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_chg_value_h1[7:0] ;
            cdm_ras_des_einj6_chg_value_h1[15:8]  <= #TP (cdm_reg_id[32] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_chg_value_h1[15:8] ;
            cdm_ras_des_einj6_chg_value_h1[23:16] <= #TP (cdm_reg_id[32] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_chg_value_h1[23:16] ;
            cdm_ras_des_einj6_chg_value_h1[31:24] <= #TP (cdm_reg_id[32] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_chg_value_h1[31:24] ;
        end
    end

    assign {int_reg_0x83, int_reg_0x82, int_reg_0x81, int_reg_0x80} = { cdm_ras_des_einj6_chg_value_h1 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 33
// PCIE Offset      - `RAS_DES_PTR + 84h
// length           - 4 byte
// Cfig register    - int_reg_0x87, int_reg_0x86, int_reg_0x85, int_reg_0x84
// register         - EINJ6 change value h2 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_chg_value_h2 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_chg_value_h2[7:0]   <= #TP (cdm_reg_id[33] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_chg_value_h2[7:0] ;
            cdm_ras_des_einj6_chg_value_h2[15:8]  <= #TP (cdm_reg_id[33] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_chg_value_h2[15:8] ;
            cdm_ras_des_einj6_chg_value_h2[23:16] <= #TP (cdm_reg_id[33] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_chg_value_h2[23:16] ;
            cdm_ras_des_einj6_chg_value_h2[31:24] <= #TP (cdm_reg_id[33] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_chg_value_h2[31:24] ;
        end
    end

    assign {int_reg_0x87, int_reg_0x86, int_reg_0x85, int_reg_0x84} = { cdm_ras_des_einj6_chg_value_h2 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 34
// PCIE Offset      - `RAS_DES_PTR + 88h
// length           - 4 byte
// Cfig register    - int_reg_0x8B, int_reg_0x8A, int_reg_0x89, int_reg_0x88
// register         - EINJ6 change value h3 [31:0] : RW
// -----------------------------------------------------------------------------
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_chg_value_h3 <= #TP 32'd0 ;
        end
        else begin
            cdm_ras_des_einj6_chg_value_h3[7:0]   <= #TP (cdm_reg_id[34] & cdm_reg_write_pulse[0] ) ? cdm_reg_wdata[7:0]   : cdm_ras_des_einj6_chg_value_h3[7:0] ;
            cdm_ras_des_einj6_chg_value_h3[15:8]  <= #TP (cdm_reg_id[34] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[15:8]  : cdm_ras_des_einj6_chg_value_h3[15:8] ;
            cdm_ras_des_einj6_chg_value_h3[23:16] <= #TP (cdm_reg_id[34] & cdm_reg_write_pulse[2] ) ? cdm_reg_wdata[23:16] : cdm_ras_des_einj6_chg_value_h3[23:16] ;
            cdm_ras_des_einj6_chg_value_h3[31:24] <= #TP (cdm_reg_id[34] & cdm_reg_write_pulse[3] ) ? cdm_reg_wdata[31:24] : cdm_ras_des_einj6_chg_value_h3[31:24] ;
        end
    end

    assign {int_reg_0x8B, int_reg_0x8A, int_reg_0x89, int_reg_0x88} = { cdm_ras_des_einj6_chg_value_h3 } ;

// -----------------------------------------------------------------------------
// cdm_reg_id       - 35
// PCIE Offset      - `RAS_DES_PTR + 8Ch
// length           - 4 byte
// Cfig register    - int_reg_0x8F, int_reg_0x8E, int_reg_0x8D, int_reg_0x8C
// register         - EINJ6 count [7:0] : RO
//                  - EINJ6 inverted control [8] : RW
//                  - EINJ6 packet type [11:9] : RW
// -----------------------------------------------------------------------------
    assign int_einj6_evt = (8)'(xaim_einj6_tlp_evt);

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_count <= #TP 8'd0 ;
        end
        else begin
            if ( cdm_reg_id[35] & cdm_reg_write_pulse[0]) begin
                cdm_ras_des_einj6_count <= #TP cdm_reg_wdata[7:0] ;
            end
            else if ( cdm_ras_des_einj6_count > 8'd0 ) begin
                if ( cdm_ras_des_einj6_count <= int_einj6_evt ) cdm_ras_des_einj6_count <= #TP 8'd0 ;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The loss is avoided by the underflow control above.
                else                                            cdm_ras_des_einj6_count <= #TP cdm_ras_des_einj6_count - int_einj6_evt ;
// spyglass enable_block W164a
            end
            
        end
    end

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ras_des_einj6_invt_cont <= #TP 1'b0 ;
            cdm_ras_des_einj6_pkt_type  <= #TP 3'd0 ;
        end
        else begin
            cdm_ras_des_einj6_invt_cont  <= #TP (cdm_reg_id[35] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[8]    : cdm_ras_des_einj6_invt_cont ;
            cdm_ras_des_einj6_pkt_type   <= #TP (cdm_reg_id[35] & cdm_reg_write_pulse[1] ) ? cdm_reg_wdata[11:9] : cdm_ras_des_einj6_pkt_type ;
        end
    end

    assign {int_reg_0x8F, int_reg_0x8E, int_reg_0x8D, int_reg_0x8C} = { 20'd0                         // [31:12]
                                                                      , cdm_ras_des_einj6_pkt_type    // [11:9]
                                                                      , cdm_ras_des_einj6_invt_cont   // [8]
                                                                      , cdm_ras_des_einj6_count       // [7:0]
                                                                      } ;

// =============================================================================
// Register Read Operation
// =============================================================================
    wire                               resp_scheduled ;

// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: This signal is not used inside this module. This is the interface signal of this module. The sequential signal is unnecessary.
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            cdm_ei_ack <= #TP 2'b00 ;
        end
        else begin
            case ( cdm_ei_ack )
                2'b00 : begin
                    if ( resp_scheduled ) begin
                        cdm_ei_ack <= #TP 2'b01 ;
                    end
                end
                2'b01 : begin
                    cdm_ei_ack <= #TP 2'b10 ;
                end
                2'b10 : begin
                    cdm_ei_ack <= #TP 2'b00 ;
                end
                default : cdm_ei_ack <= #TP 2'b00 ;
            endcase
        end
    end
// spyglass enable_block STARC05-2.11.3.1

    assign resp_scheduled = |cdm_reg_id[39:12] ;

    always @(*) begin : read_data_PROC
        unique case (1'b1)
            cdm_reg_id[12]  : cdm_ei_rdata = {int_reg_0x33, int_reg_0x32, int_reg_0x31, int_reg_0x30} ;
            cdm_reg_id[13]  : cdm_ei_rdata = {int_reg_0x37, int_reg_0x36, int_reg_0x35, int_reg_0x34} ;
            cdm_reg_id[14]  : cdm_ei_rdata = {int_reg_0x3B, int_reg_0x3A, int_reg_0x39, int_reg_0x38} ;
            cdm_reg_id[15]  : cdm_ei_rdata = {int_reg_0x3F, int_reg_0x3E, int_reg_0x3D, int_reg_0x3C} ;
            cdm_reg_id[16]  : cdm_ei_rdata = {int_reg_0x43, int_reg_0x42, int_reg_0x41, int_reg_0x40} ;
            cdm_reg_id[17]  : cdm_ei_rdata = {int_reg_0x47, int_reg_0x46, int_reg_0x45, int_reg_0x44} ;
            cdm_reg_id[18]  : cdm_ei_rdata = {int_reg_0x4B, int_reg_0x4A, int_reg_0x49, int_reg_0x48} ;
            cdm_reg_id[19]  : cdm_ei_rdata = {int_reg_0x4F, int_reg_0x4E, int_reg_0x4D, int_reg_0x4C} ;
            cdm_reg_id[20]  : cdm_ei_rdata = {int_reg_0x53, int_reg_0x52, int_reg_0x51, int_reg_0x50} ;
            cdm_reg_id[21]  : cdm_ei_rdata = {int_reg_0x57, int_reg_0x56, int_reg_0x55, int_reg_0x54} ;
            cdm_reg_id[22]  : cdm_ei_rdata = {int_reg_0x5B, int_reg_0x5A, int_reg_0x59, int_reg_0x58} ;
            cdm_reg_id[23]  : cdm_ei_rdata = {int_reg_0x5F, int_reg_0x5E, int_reg_0x5D, int_reg_0x5C} ;
            cdm_reg_id[24]  : cdm_ei_rdata = {int_reg_0x63, int_reg_0x62, int_reg_0x61, int_reg_0x60} ;
            cdm_reg_id[25]  : cdm_ei_rdata = {int_reg_0x67, int_reg_0x66, int_reg_0x65, int_reg_0x64} ;
            cdm_reg_id[26]  : cdm_ei_rdata = {int_reg_0x6B, int_reg_0x6A, int_reg_0x69, int_reg_0x68} ;
            cdm_reg_id[27]  : cdm_ei_rdata = {int_reg_0x6F, int_reg_0x6E, int_reg_0x6D, int_reg_0x6C} ;
            cdm_reg_id[28]  : cdm_ei_rdata = {int_reg_0x73, int_reg_0x72, int_reg_0x71, int_reg_0x70} ;
            cdm_reg_id[29]  : cdm_ei_rdata = {int_reg_0x77, int_reg_0x76, int_reg_0x75, int_reg_0x74} ;
            cdm_reg_id[30]  : cdm_ei_rdata = {int_reg_0x7B, int_reg_0x7A, int_reg_0x79, int_reg_0x78} ;
            cdm_reg_id[31]  : cdm_ei_rdata = {int_reg_0x7F, int_reg_0x7E, int_reg_0x7D, int_reg_0x7C} ;
            cdm_reg_id[32]  : cdm_ei_rdata = {int_reg_0x83, int_reg_0x82, int_reg_0x81, int_reg_0x80} ;
            cdm_reg_id[33]  : cdm_ei_rdata = {int_reg_0x87, int_reg_0x86, int_reg_0x85, int_reg_0x84} ;
            cdm_reg_id[34]  : cdm_ei_rdata = {int_reg_0x8B, int_reg_0x8A, int_reg_0x89, int_reg_0x88} ;
            cdm_reg_id[35]  : cdm_ei_rdata = {int_reg_0x8F, int_reg_0x8E, int_reg_0x8D, int_reg_0x8C} ;
            default         : cdm_ei_rdata = `PCIE_UNUSED_RESPONSE;
        endcase
    end


endmodule //cdm_rasdes_einj_reg 
