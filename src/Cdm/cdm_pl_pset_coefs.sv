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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_pl_pset_coefs.sv#10 $
//----------------------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Gen3 transmit equalization programmable
// --- preset to coefficient conversion table.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"


module cdm_pl_pset_coefs
 import DWC_pcie_core_pkg::violate_rules_tx_coef;
 import DWC_pcie_core_pkg::violate_rules_tx_coef_g6;
(
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    sticky_rst_n,
    lbc_cdm_data,
    pl_reg_id,
    write_pulse,
    read_pulse,
    rate_shadow_sel,
// -- outputs --
    pl_reg_fs_lf,
    pl_reg_coef,
    pl_reg_pseti,
    pl_reg_violate_rules_prog_coef,
    cfg_gen3_eq_fs_lf,
    cfg_gen4_eq_fs_lf,
    cfg_gen5_eq_fs_lf,
    cfg_gen6_eq_fs_lf,
    cfg_gen3_eq_coef
    ,cfg_gen4_eq_coef
    ,cfg_gen5_eq_coef
    ,cfg_gen6_eq_coef
  );

// parameters
// Default values for Equalization Programmable Presets to Coefficients mapping
localparam PSET_COEF_ID_WD = 4;
localparam FS_LF_WD        = 12;
localparam COEF_WD         = 18;
localparam COEF_WD_GEN6    = 21;         // Gen6 has 3bit precursor2
parameter TP               = `TP;        // Clock to Q delay (simulator insurance)
parameter TX_FS_WD         = 6;
parameter TX_COEF_WD       = 3*TX_FS_WD;

//for debug purpose
localparam LOCAL_FS   = `DEFAULT_GEN3_EQ_LOCAL_FS;
localparam LOCAL_LF   = `DEFAULT_GEN3_EQ_LOCAL_LF;
localparam GEN4_LOCAL_FS = `DEFAULT_GEN4_EQ_LOCAL_FS;
localparam GEN4_LOCAL_LF = `DEFAULT_GEN4_EQ_LOCAL_LF;
localparam GEN5_LOCAL_FS = `DEFAULT_GEN5_EQ_LOCAL_FS;
localparam GEN5_LOCAL_LF = `DEFAULT_GEN5_EQ_LOCAL_LF;
localparam GEN6_LOCAL_FS = `DEFAULT_GEN6_EQ_LOCAL_FS;
localparam GEN6_LOCAL_LF = `DEFAULT_GEN6_EQ_LOCAL_LF;

// ----- Inputs ---------------
input                         core_clk;
input                         non_sticky_rst_n;
input                         sticky_rst_n;
input   [21:0]                lbc_cdm_data;               // Data for write
input   [PSET_COEF_ID_WD-1:0] pl_reg_id;                  // register ID
input    [2:0]                write_pulse;                // write pulses for each byte
input                         read_pulse;                 // Read pulse
input    [1:0]                rate_shadow_sel;
// ----- Outputs ---------------
output  [FS_LF_WD-1:0]        pl_reg_fs_lf;               // programmed FS and LF
output  [31:0]                pl_reg_coef;                // coefficients which are read back
output  [3:0]                 pl_reg_pseti;               // preset index for equalization coefficients table
output                        pl_reg_violate_rules_prog_coef;     // asserted when any one of the Gen3 transmit coeffcients rules are violated.
output  [FS_LF_WD-1:0]        cfg_gen3_eq_fs_lf;          // programmed FS and LF
output  [FS_LF_WD-1:0]        cfg_gen4_eq_fs_lf;          // programmed FS and LF
output  [FS_LF_WD-1:0]        cfg_gen5_eq_fs_lf;          // programmed FS and LF
output  [FS_LF_WD-1:0]        cfg_gen6_eq_fs_lf;          // programmed FS and LF
output  [(11*COEF_WD)-1:0]    cfg_gen3_eq_coef;                   // coefficients to be used by transmitter.
output  [(11*COEF_WD)-1:0]    cfg_gen4_eq_coef;                   // coefficients to be used by transmitter.
output  [(11*COEF_WD)-1:0]    cfg_gen5_eq_coef;                   // coefficients to be used by transmitter.
output  [(11*COEF_WD)-1:0]    cfg_gen6_eq_coef;                   // coefficients to be used by transmitter.

wire   [FS_LF_WD-1:0]         pl_reg_fs_lf;                    // FS and LF registers.
reg    [FS_LF_WD-1:0]         cfg_gen3_eq_fs_lf;               // FS and LF registers.
reg    [FS_LF_WD-1:0]         cfg_gen4_eq_fs_lf;               // FS and LF registers.
reg    [FS_LF_WD-1:0]         cfg_gen5_eq_fs_lf;               // FS and LF registers.
reg    [FS_LF_WD-1:0]         cfg_gen6_eq_fs_lf;               // FS and LF registers.

// Programmable Preset to Coefficients table values:
reg    [COEF_WD-1:0]          pl_reg_gen3_pset_coef0, pl_reg_gen3_pset_coef1, pl_reg_gen3_pset_coef2, pl_reg_gen3_pset_coef3,
                              pl_reg_gen3_pset_coef4, pl_reg_gen3_pset_coef5, pl_reg_gen3_pset_coef6, pl_reg_gen3_pset_coef7,
                              pl_reg_gen3_pset_coef8, pl_reg_gen3_pset_coef9, pl_reg_gen3_pset_coef10;
reg    [COEF_WD-1:0]          pl_reg_gen4_pset_coef0, pl_reg_gen4_pset_coef1, pl_reg_gen4_pset_coef2, pl_reg_gen4_pset_coef3,
                              pl_reg_gen4_pset_coef4, pl_reg_gen4_pset_coef5, pl_reg_gen4_pset_coef6, pl_reg_gen4_pset_coef7,
                              pl_reg_gen4_pset_coef8, pl_reg_gen4_pset_coef9, pl_reg_gen4_pset_coef10;
reg    [COEF_WD-1:0]          pl_reg_gen5_pset_coef0, pl_reg_gen5_pset_coef1, pl_reg_gen5_pset_coef2, pl_reg_gen5_pset_coef3,
                              pl_reg_gen5_pset_coef4, pl_reg_gen5_pset_coef5, pl_reg_gen5_pset_coef6, pl_reg_gen5_pset_coef7,
                              pl_reg_gen5_pset_coef8, pl_reg_gen5_pset_coef9, pl_reg_gen5_pset_coef10;
// Gen6 has different widths for cursors and an additional precursor2, while keeping a total of 18 bits: int = {post 5b, cur 6b, pre 4b, pre2 3b}
wire   [COEF_WD-1:0]          int_reg_gen6_pset_coef0, int_reg_gen6_pset_coef1, int_reg_gen6_pset_coef2, int_reg_gen6_pset_coef3,
                              int_reg_gen6_pset_coef4, int_reg_gen6_pset_coef5, int_reg_gen6_pset_coef6, int_reg_gen6_pset_coef7,
                              int_reg_gen6_pset_coef8, int_reg_gen6_pset_coef9, int_reg_gen6_pset_coef10;
// COEF_WD_GEN6 = COEF_WD+3 for precursor2
reg    [COEF_WD_GEN6-1:0]     pl_reg_gen6_pset_coef0, pl_reg_gen6_pset_coef1, pl_reg_gen6_pset_coef2, pl_reg_gen6_pset_coef3,
                              pl_reg_gen6_pset_coef4, pl_reg_gen6_pset_coef5, pl_reg_gen6_pset_coef6, pl_reg_gen6_pset_coef7,
                              pl_reg_gen6_pset_coef8, pl_reg_gen6_pset_coef9, pl_reg_gen6_pset_coef10;

wire   [COEF_WD_GEN6-1:0]     pl_reg_pset_coef0, pl_reg_pset_coef1, pl_reg_pset_coef2, pl_reg_pset_coef3,
                              pl_reg_pset_coef4, pl_reg_pset_coef5, pl_reg_pset_coef6, pl_reg_pset_coef7,
                              pl_reg_pset_coef8, pl_reg_pset_coef9, pl_reg_pset_coef10;

// Precursor, cursor and postcursor coefficients:
wire    [5:0]                cfg_p0_c_minus_1, cfg_p1_c_minus_1, cfg_p2_c_minus_1, cfg_p3_c_minus_1, cfg_p4_c_minus_1, cfg_p5_c_minus_1, cfg_p6_c_minus_1,
                             cfg_p7_c_minus_1, cfg_p8_c_minus_1, cfg_p9_c_minus_1, cfg_p10_c_minus_1, cfg_p0_c0, cfg_p1_c0, cfg_p2_c0,
                             cfg_p3_c0, cfg_p4_c0, cfg_p5_c0, cfg_p6_c0, cfg_p7_c0, cfg_p8_c0, cfg_p9_c0,
                             cfg_p10_c0, cfg_p0_c_plus_1, cfg_p1_c_plus_1, cfg_p2_c_plus_1, cfg_p3_c_plus_1, cfg_p4_c_plus_1, cfg_p5_c_plus_1,
                             cfg_p6_c_plus_1, cfg_p7_c_plus_1, cfg_p8_c_plus_1, cfg_p9_c_plus_1, cfg_p10_c_plus_1;

wire                         pset_index0, pset_index1, pset_index2, pset_index3, pset_index4, pset_index5,
                             pset_index6, pset_index7, pset_index8, pset_index9, pset_index10;
reg    [31:0]                pl_reg_coef;                // coefficients which are read back
reg    [3:0]                 pl_reg_pseti;               // programmable preset index for equalization coefficients table
wire   [(11*COEF_WD-1):0]    cfg_gen3_eq_coef;                   // coefficients to be used by transmitter.
reg                          pl_reg_violate_rules_prog_coef;     // asserted when any one of the Gen3 transmit coeffcients rules are violated.

wire                         current_violate_tx_rules;           // asserted when any one of the currently written Gen3 transmit coeffcients rules are violated
wire  [TX_FS_WD-1:0]         current_fs;           // current programmed local FS
wire  [TX_FS_WD-1:0]         current_lf;           // current programmed local LF
reg   [TX_COEF_WD-1:0]       current_coef;         // current programmed coefficients for the preset number most recently written to.

//----------------------------------------------------------------------------------------
// PCIe Gen3 Transmit Equalization Programmable local Full Swing (FS) and
// Low Frequency (LF) parameters.
// cpl_reg_id       - 0
// Length           - 4 bytes
// Default value    - FS = 48 and LF = 16 (decimal): 0C10h
// Core registers   - pl_reg_fs_lf
// ---------------------------------------------------------------------------------------

always @(posedge core_clk or negedge sticky_rst_n)
   begin
      if (!sticky_rst_n)
         begin                                    // Default programmable local FS and LF values
            cfg_gen3_eq_fs_lf  <= #TP {LOCAL_FS,LOCAL_LF};
            cfg_gen4_eq_fs_lf  <= #TP {GEN4_LOCAL_FS,GEN4_LOCAL_LF};
            cfg_gen5_eq_fs_lf  <= #TP {GEN5_LOCAL_FS,GEN5_LOCAL_LF};
            cfg_gen6_eq_fs_lf  <= #TP {GEN6_LOCAL_FS,GEN6_LOCAL_LF};
         end
      else
         begin
            cfg_gen3_eq_fs_lf[11:8] <= #TP (write_pulse[1] & pl_reg_id[0] & rate_shadow_sel==2'b00) ? lbc_cdm_data[11:8] : cfg_gen3_eq_fs_lf[11:8];
            cfg_gen3_eq_fs_lf[7:0] <= #TP (write_pulse[0] & pl_reg_id[0] & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0]   : cfg_gen3_eq_fs_lf[7:0];
            cfg_gen4_eq_fs_lf[11:8] <= #TP (write_pulse[1] & pl_reg_id[0] & rate_shadow_sel==2'b01) ? lbc_cdm_data[11:8] : cfg_gen4_eq_fs_lf[11:8];
            cfg_gen4_eq_fs_lf[7:0] <= #TP (write_pulse[0] & pl_reg_id[0] & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0]   : cfg_gen4_eq_fs_lf[7:0];
            cfg_gen5_eq_fs_lf[11:8] <= #TP (write_pulse[1] & pl_reg_id[0] & rate_shadow_sel==2'b10) ? lbc_cdm_data[11:8] : cfg_gen5_eq_fs_lf[11:8];
            cfg_gen5_eq_fs_lf[7:0] <= #TP (write_pulse[0] & pl_reg_id[0] & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0]   : cfg_gen5_eq_fs_lf[7:0];
            cfg_gen6_eq_fs_lf[11:8] <= #TP (write_pulse[1] & pl_reg_id[0] & rate_shadow_sel==2'b11) ? lbc_cdm_data[11:8] : cfg_gen6_eq_fs_lf[11:8];
            cfg_gen6_eq_fs_lf[7:0]  <= #TP (write_pulse[0] & pl_reg_id[0] & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]  : cfg_gen6_eq_fs_lf[7:0];
         end
   end

assign pl_reg_fs_lf = (rate_shadow_sel==2'b00) ? cfg_gen3_eq_fs_lf : (rate_shadow_sel==2'b01) ? cfg_gen4_eq_fs_lf : (rate_shadow_sel==2'b10) ? cfg_gen5_eq_fs_lf : cfg_gen6_eq_fs_lf ;

always @(posedge core_clk or negedge sticky_rst_n)
   begin
      if (!sticky_rst_n)
         begin                                    // Default preset to coefficient mapping values
                                                  // These default values
                                                  // assume default values
                                                  // for FS  48 and LF = 16.
            pl_reg_gen3_pset_coef0  <= #TP `DEFAULT_GEN3_P0;
            pl_reg_gen3_pset_coef1  <= #TP `DEFAULT_GEN3_P1;
            pl_reg_gen3_pset_coef2  <= #TP `DEFAULT_GEN3_P2;
            pl_reg_gen3_pset_coef3  <= #TP `DEFAULT_GEN3_P3;
            pl_reg_gen3_pset_coef4  <= #TP `DEFAULT_GEN3_P4;
            pl_reg_gen3_pset_coef5  <= #TP `DEFAULT_GEN3_P5;
            pl_reg_gen3_pset_coef6  <= #TP `DEFAULT_GEN3_P6;
            pl_reg_gen3_pset_coef7  <= #TP `DEFAULT_GEN3_P7;
            pl_reg_gen3_pset_coef8  <= #TP `DEFAULT_GEN3_P8;
            pl_reg_gen3_pset_coef9  <= #TP `DEFAULT_GEN3_P9;
            pl_reg_gen3_pset_coef10 <= #TP `DEFAULT_GEN3_P10;
            pl_reg_gen4_pset_coef0  <= #TP `DEFAULT_GEN4_P0;
            pl_reg_gen4_pset_coef1  <= #TP `DEFAULT_GEN4_P1;
            pl_reg_gen4_pset_coef2  <= #TP `DEFAULT_GEN4_P2;
            pl_reg_gen4_pset_coef3  <= #TP `DEFAULT_GEN4_P3;
            pl_reg_gen4_pset_coef4  <= #TP `DEFAULT_GEN4_P4;
            pl_reg_gen4_pset_coef5  <= #TP `DEFAULT_GEN4_P5;
            pl_reg_gen4_pset_coef6  <= #TP `DEFAULT_GEN4_P6;
            pl_reg_gen4_pset_coef7  <= #TP `DEFAULT_GEN4_P7;
            pl_reg_gen4_pset_coef8  <= #TP `DEFAULT_GEN4_P8;
            pl_reg_gen4_pset_coef9  <= #TP `DEFAULT_GEN4_P9;
            pl_reg_gen4_pset_coef10 <= #TP `DEFAULT_GEN4_P10;
            pl_reg_gen5_pset_coef0  <= #TP `DEFAULT_GEN5_P0;
            pl_reg_gen5_pset_coef1  <= #TP `DEFAULT_GEN5_P1;
            pl_reg_gen5_pset_coef2  <= #TP `DEFAULT_GEN5_P2;
            pl_reg_gen5_pset_coef3  <= #TP `DEFAULT_GEN5_P3;
            pl_reg_gen5_pset_coef4  <= #TP `DEFAULT_GEN5_P4;
            pl_reg_gen5_pset_coef5  <= #TP `DEFAULT_GEN5_P5;
            pl_reg_gen5_pset_coef6  <= #TP `DEFAULT_GEN5_P6;
            pl_reg_gen5_pset_coef7  <= #TP `DEFAULT_GEN5_P7;
            pl_reg_gen5_pset_coef8  <= #TP `DEFAULT_GEN5_P8;
            pl_reg_gen5_pset_coef9  <= #TP `DEFAULT_GEN5_P9;
            pl_reg_gen5_pset_coef10 <= #TP `DEFAULT_GEN5_P10;
            pl_reg_gen6_pset_coef0  <= #TP `DEFAULT_GEN6_Q0;
            pl_reg_gen6_pset_coef1  <= #TP `DEFAULT_GEN6_Q1;
            pl_reg_gen6_pset_coef2  <= #TP `DEFAULT_GEN6_Q2;
            pl_reg_gen6_pset_coef3  <= #TP `DEFAULT_GEN6_Q3;
            pl_reg_gen6_pset_coef4  <= #TP `DEFAULT_GEN6_Q4;
            pl_reg_gen6_pset_coef5  <= #TP `DEFAULT_GEN6_Q5;
            pl_reg_gen6_pset_coef6  <= #TP `DEFAULT_GEN6_Q6;
            pl_reg_gen6_pset_coef7  <= #TP `DEFAULT_GEN6_Q7;
            pl_reg_gen6_pset_coef8  <= #TP `DEFAULT_GEN6_Q8;
            pl_reg_gen6_pset_coef9  <= #TP `DEFAULT_GEN6_Q9;
            pl_reg_gen6_pset_coef10 <= #TP `DEFAULT_GEN6_Q10;
        end
      else
         begin
            pl_reg_gen3_pset_coef0[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index0 & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0] : pl_reg_gen3_pset_coef0[7:0];
            pl_reg_gen3_pset_coef0[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index0 & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8] : pl_reg_gen3_pset_coef0[15:8];
            pl_reg_gen3_pset_coef0[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index0 & rate_shadow_sel==2'b00) ? lbc_cdm_data[17:16] : pl_reg_gen3_pset_coef0[17:16];

            pl_reg_gen3_pset_coef1[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index1 & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0] : pl_reg_gen3_pset_coef1[7:0];
            pl_reg_gen3_pset_coef1[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index1 & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8] : pl_reg_gen3_pset_coef1[15:8];
            pl_reg_gen3_pset_coef1[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index1 & rate_shadow_sel==2'b00) ? lbc_cdm_data[17:16] : pl_reg_gen3_pset_coef1[17:16];

            pl_reg_gen3_pset_coef2[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index2 & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0] : pl_reg_gen3_pset_coef2[7:0];
            pl_reg_gen3_pset_coef2[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index2 & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8] : pl_reg_gen3_pset_coef2[15:8];
            pl_reg_gen3_pset_coef2[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index2 & rate_shadow_sel==2'b00) ? lbc_cdm_data[17:16] : pl_reg_gen3_pset_coef2[17:16];

            pl_reg_gen3_pset_coef3[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index3 & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0] : pl_reg_gen3_pset_coef3[7:0];
            pl_reg_gen3_pset_coef3[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index3 & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8] : pl_reg_gen3_pset_coef3[15:8];
            pl_reg_gen3_pset_coef3[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index3 & rate_shadow_sel==2'b00) ? lbc_cdm_data[17:16] : pl_reg_gen3_pset_coef3[17:16];

            pl_reg_gen3_pset_coef4[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index4 & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0] : pl_reg_gen3_pset_coef4[7:0];
            pl_reg_gen3_pset_coef4[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index4 & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8] : pl_reg_gen3_pset_coef4[15:8];
            pl_reg_gen3_pset_coef4[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index4 & rate_shadow_sel==2'b00) ? lbc_cdm_data[17:16] : pl_reg_gen3_pset_coef4[17:16];

            pl_reg_gen3_pset_coef5[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index5 & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0] : pl_reg_gen3_pset_coef5[7:0];
            pl_reg_gen3_pset_coef5[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index5 & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8] : pl_reg_gen3_pset_coef5[15:8];
            pl_reg_gen3_pset_coef5[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index5 & rate_shadow_sel==2'b00) ? lbc_cdm_data[17:16] : pl_reg_gen3_pset_coef5[17:16];

            pl_reg_gen3_pset_coef6[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index6 & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0] : pl_reg_gen3_pset_coef6[7:0];
            pl_reg_gen3_pset_coef6[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index6 & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8] : pl_reg_gen3_pset_coef6[15:8];
            pl_reg_gen3_pset_coef6[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index6 & rate_shadow_sel==2'b00) ? lbc_cdm_data[17:16] : pl_reg_gen3_pset_coef6[17:16];

            pl_reg_gen3_pset_coef7[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index7 & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0] : pl_reg_gen3_pset_coef7[7:0];
            pl_reg_gen3_pset_coef7[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index7 & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8] : pl_reg_gen3_pset_coef7[15:8];
            pl_reg_gen3_pset_coef7[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index7 & rate_shadow_sel==2'b00) ? lbc_cdm_data[17:16] : pl_reg_gen3_pset_coef7[17:16];

            pl_reg_gen3_pset_coef8[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index8 & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0] : pl_reg_gen3_pset_coef8[7:0];
            pl_reg_gen3_pset_coef8[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index8 & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8] : pl_reg_gen3_pset_coef8[15:8];
            pl_reg_gen3_pset_coef8[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index8 & rate_shadow_sel==2'b00) ? lbc_cdm_data[17:16] : pl_reg_gen3_pset_coef8[17:16];

            pl_reg_gen3_pset_coef9[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index9 & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0] : pl_reg_gen3_pset_coef9[7:0];
            pl_reg_gen3_pset_coef9[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index9 & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8] : pl_reg_gen3_pset_coef9[15:8];
            pl_reg_gen3_pset_coef9[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index9 & rate_shadow_sel==2'b00) ? lbc_cdm_data[17:16] : pl_reg_gen3_pset_coef9[17:16];

            pl_reg_gen3_pset_coef10[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index10 & rate_shadow_sel==2'b00) ? lbc_cdm_data[7:0] : pl_reg_gen3_pset_coef10[7:0];
            pl_reg_gen3_pset_coef10[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index10 & rate_shadow_sel==2'b00) ? lbc_cdm_data[15:8] : pl_reg_gen3_pset_coef10[15:8];
            pl_reg_gen3_pset_coef10[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index10 & rate_shadow_sel==2'b00) ? lbc_cdm_data[17:16] : pl_reg_gen3_pset_coef10[17:16];

            pl_reg_gen4_pset_coef0[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index0 & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0] : pl_reg_gen4_pset_coef0[7:0];
            pl_reg_gen4_pset_coef0[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index0 & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8] : pl_reg_gen4_pset_coef0[15:8];
            pl_reg_gen4_pset_coef0[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index0 & rate_shadow_sel==2'b01) ? lbc_cdm_data[17:16] : pl_reg_gen4_pset_coef0[17:16];

            pl_reg_gen4_pset_coef1[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index1 & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0] : pl_reg_gen4_pset_coef1[7:0];
            pl_reg_gen4_pset_coef1[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index1 & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8] : pl_reg_gen4_pset_coef1[15:8];
            pl_reg_gen4_pset_coef1[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index1 & rate_shadow_sel==2'b01) ? lbc_cdm_data[17:16] : pl_reg_gen4_pset_coef1[17:16];

            pl_reg_gen4_pset_coef2[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index2 & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0] : pl_reg_gen4_pset_coef2[7:0];
            pl_reg_gen4_pset_coef2[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index2 & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8] : pl_reg_gen4_pset_coef2[15:8];
            pl_reg_gen4_pset_coef2[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index2 & rate_shadow_sel==2'b01) ? lbc_cdm_data[17:16] : pl_reg_gen4_pset_coef2[17:16];

            pl_reg_gen4_pset_coef3[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index3 & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0] : pl_reg_gen4_pset_coef3[7:0];
            pl_reg_gen4_pset_coef3[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index3 & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8] : pl_reg_gen4_pset_coef3[15:8];
            pl_reg_gen4_pset_coef3[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index3 & rate_shadow_sel==2'b01) ? lbc_cdm_data[17:16] : pl_reg_gen4_pset_coef3[17:16];

            pl_reg_gen4_pset_coef4[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index4 & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0] : pl_reg_gen4_pset_coef4[7:0];
            pl_reg_gen4_pset_coef4[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index4 & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8] : pl_reg_gen4_pset_coef4[15:8];
            pl_reg_gen4_pset_coef4[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index4 & rate_shadow_sel==2'b01) ? lbc_cdm_data[17:16] : pl_reg_gen4_pset_coef4[17:16];

            pl_reg_gen4_pset_coef5[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index5 & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0] : pl_reg_gen4_pset_coef5[7:0];
            pl_reg_gen4_pset_coef5[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index5 & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8] : pl_reg_gen4_pset_coef5[15:8];
            pl_reg_gen4_pset_coef5[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index5 & rate_shadow_sel==2'b01) ? lbc_cdm_data[17:16] : pl_reg_gen4_pset_coef5[17:16];

            pl_reg_gen4_pset_coef6[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index6 & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0] : pl_reg_gen4_pset_coef6[7:0];
            pl_reg_gen4_pset_coef6[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index6 & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8] : pl_reg_gen4_pset_coef6[15:8];
            pl_reg_gen4_pset_coef6[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index6 & rate_shadow_sel==2'b01) ? lbc_cdm_data[17:16] : pl_reg_gen4_pset_coef6[17:16];

            pl_reg_gen4_pset_coef7[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index7 & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0] : pl_reg_gen4_pset_coef7[7:0];
            pl_reg_gen4_pset_coef7[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index7 & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8] : pl_reg_gen4_pset_coef7[15:8];
            pl_reg_gen4_pset_coef7[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index7 & rate_shadow_sel==2'b01) ? lbc_cdm_data[17:16] : pl_reg_gen4_pset_coef7[17:16];

            pl_reg_gen4_pset_coef8[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index8 & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0] : pl_reg_gen4_pset_coef8[7:0];
            pl_reg_gen4_pset_coef8[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index8 & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8] : pl_reg_gen4_pset_coef8[15:8];
            pl_reg_gen4_pset_coef8[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index8 & rate_shadow_sel==2'b01) ? lbc_cdm_data[17:16] : pl_reg_gen4_pset_coef8[17:16];

            pl_reg_gen4_pset_coef9[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index9 & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0] : pl_reg_gen4_pset_coef9[7:0];
            pl_reg_gen4_pset_coef9[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index9 & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8] : pl_reg_gen4_pset_coef9[15:8];
            pl_reg_gen4_pset_coef9[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index9 & rate_shadow_sel==2'b01) ? lbc_cdm_data[17:16] : pl_reg_gen4_pset_coef9[17:16];

            pl_reg_gen4_pset_coef10[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index10 & rate_shadow_sel==2'b01) ? lbc_cdm_data[7:0] : pl_reg_gen4_pset_coef10[7:0];
            pl_reg_gen4_pset_coef10[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index10 & rate_shadow_sel==2'b01) ? lbc_cdm_data[15:8] : pl_reg_gen4_pset_coef10[15:8];
            pl_reg_gen4_pset_coef10[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index10 & rate_shadow_sel==2'b01) ? lbc_cdm_data[17:16] : pl_reg_gen4_pset_coef10[17:16];

            pl_reg_gen5_pset_coef0[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index0 & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0] : pl_reg_gen5_pset_coef0[7:0];
            pl_reg_gen5_pset_coef0[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index0 & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8] : pl_reg_gen5_pset_coef0[15:8];
            pl_reg_gen5_pset_coef0[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index0 & rate_shadow_sel==2'b10) ? lbc_cdm_data[17:16] : pl_reg_gen5_pset_coef0[17:16];

            pl_reg_gen5_pset_coef1[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index1 & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0] : pl_reg_gen5_pset_coef1[7:0];
            pl_reg_gen5_pset_coef1[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index1 & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8] : pl_reg_gen5_pset_coef1[15:8];
            pl_reg_gen5_pset_coef1[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index1 & rate_shadow_sel==2'b10) ? lbc_cdm_data[17:16] : pl_reg_gen5_pset_coef1[17:16];

            pl_reg_gen5_pset_coef2[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index2 & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0] : pl_reg_gen5_pset_coef2[7:0];
            pl_reg_gen5_pset_coef2[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index2 & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8] : pl_reg_gen5_pset_coef2[15:8];
            pl_reg_gen5_pset_coef2[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index2 & rate_shadow_sel==2'b10) ? lbc_cdm_data[17:16] : pl_reg_gen5_pset_coef2[17:16];

            pl_reg_gen5_pset_coef3[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index3 & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0] : pl_reg_gen5_pset_coef3[7:0];
            pl_reg_gen5_pset_coef3[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index3 & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8] : pl_reg_gen5_pset_coef3[15:8];
            pl_reg_gen5_pset_coef3[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index3 & rate_shadow_sel==2'b10) ? lbc_cdm_data[17:16] : pl_reg_gen5_pset_coef3[17:16];

            pl_reg_gen5_pset_coef4[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index4 & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0] : pl_reg_gen5_pset_coef4[7:0];
            pl_reg_gen5_pset_coef4[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index4 & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8] : pl_reg_gen5_pset_coef4[15:8];
            pl_reg_gen5_pset_coef4[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index4 & rate_shadow_sel==2'b10) ? lbc_cdm_data[17:16] : pl_reg_gen5_pset_coef4[17:16];

            pl_reg_gen5_pset_coef5[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index5 & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0] : pl_reg_gen5_pset_coef5[7:0];
            pl_reg_gen5_pset_coef5[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index5 & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8] : pl_reg_gen5_pset_coef5[15:8];
            pl_reg_gen5_pset_coef5[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index5 & rate_shadow_sel==2'b10) ? lbc_cdm_data[17:16] : pl_reg_gen5_pset_coef5[17:16];

            pl_reg_gen5_pset_coef6[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index6 & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0] : pl_reg_gen5_pset_coef6[7:0];
            pl_reg_gen5_pset_coef6[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index6 & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8] : pl_reg_gen5_pset_coef6[15:8];
            pl_reg_gen5_pset_coef6[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index6 & rate_shadow_sel==2'b10) ? lbc_cdm_data[17:16] : pl_reg_gen5_pset_coef6[17:16];

            pl_reg_gen5_pset_coef7[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index7 & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0] : pl_reg_gen5_pset_coef7[7:0];
            pl_reg_gen5_pset_coef7[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index7 & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8] : pl_reg_gen5_pset_coef7[15:8];
            pl_reg_gen5_pset_coef7[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index7 & rate_shadow_sel==2'b10) ? lbc_cdm_data[17:16] : pl_reg_gen5_pset_coef7[17:16];

            pl_reg_gen5_pset_coef8[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index8 & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0] : pl_reg_gen5_pset_coef8[7:0];
            pl_reg_gen5_pset_coef8[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index8 & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8] : pl_reg_gen5_pset_coef8[15:8];
            pl_reg_gen5_pset_coef8[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index8 & rate_shadow_sel==2'b10) ? lbc_cdm_data[17:16] : pl_reg_gen5_pset_coef8[17:16];

            pl_reg_gen5_pset_coef9[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index9 & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0] : pl_reg_gen5_pset_coef9[7:0];
            pl_reg_gen5_pset_coef9[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index9 & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8] : pl_reg_gen5_pset_coef9[15:8];
            pl_reg_gen5_pset_coef9[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index9 & rate_shadow_sel==2'b10) ? lbc_cdm_data[17:16] : pl_reg_gen5_pset_coef9[17:16];

            pl_reg_gen5_pset_coef10[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index10 & rate_shadow_sel==2'b10) ? lbc_cdm_data[7:0] : pl_reg_gen5_pset_coef10[7:0];
            pl_reg_gen5_pset_coef10[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index10 & rate_shadow_sel==2'b10) ? lbc_cdm_data[15:8] : pl_reg_gen5_pset_coef10[15:8];
            pl_reg_gen5_pset_coef10[17:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index10 & rate_shadow_sel==2'b10) ? lbc_cdm_data[17:16] : pl_reg_gen5_pset_coef10[17:16];
            pl_reg_gen6_pset_coef0[7:0]   <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index0 & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]   : pl_reg_gen6_pset_coef0[7:0];
            pl_reg_gen6_pset_coef0[15:8]  <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index0 & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_reg_gen6_pset_coef0[15:8];
            pl_reg_gen6_pset_coef0[20:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index0 & rate_shadow_sel==2'b11) ? lbc_cdm_data[20:16] : pl_reg_gen6_pset_coef0[20:16];

            pl_reg_gen6_pset_coef1[7:0]   <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index1 & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]   : pl_reg_gen6_pset_coef1[7:0];
            pl_reg_gen6_pset_coef1[15:8]  <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index1 & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_reg_gen6_pset_coef1[15:8];
            pl_reg_gen6_pset_coef1[20:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index1 & rate_shadow_sel==2'b11) ? lbc_cdm_data[20:16] : pl_reg_gen6_pset_coef1[20:16];

            pl_reg_gen6_pset_coef2[7:0]   <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index2 & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]   : pl_reg_gen6_pset_coef2[7:0];
            pl_reg_gen6_pset_coef2[15:8]  <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index2 & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_reg_gen6_pset_coef2[15:8];
            pl_reg_gen6_pset_coef2[20:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index2 & rate_shadow_sel==2'b11) ? lbc_cdm_data[20:16] : pl_reg_gen6_pset_coef2[20:16];

            pl_reg_gen6_pset_coef3[7:0]   <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index3 & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]   : pl_reg_gen6_pset_coef3[7:0];
            pl_reg_gen6_pset_coef3[15:8]  <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index3 & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_reg_gen6_pset_coef3[15:8];
            pl_reg_gen6_pset_coef3[20:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index3 & rate_shadow_sel==2'b11) ? lbc_cdm_data[20:16] : pl_reg_gen6_pset_coef3[20:16];

            pl_reg_gen6_pset_coef4[7:0]   <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index4 & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]   : pl_reg_gen6_pset_coef4[7:0];
            pl_reg_gen6_pset_coef4[15:8]  <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index4 & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_reg_gen6_pset_coef4[15:8];
            pl_reg_gen6_pset_coef4[20:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index4 & rate_shadow_sel==2'b11) ? lbc_cdm_data[20:16] : pl_reg_gen6_pset_coef4[20:16];

            pl_reg_gen6_pset_coef5[7:0]   <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index5 & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]   : pl_reg_gen6_pset_coef5[7:0];
            pl_reg_gen6_pset_coef5[15:8]  <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index5 & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_reg_gen6_pset_coef5[15:8];
            pl_reg_gen6_pset_coef5[20:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index5 & rate_shadow_sel==2'b11) ? lbc_cdm_data[20:16] : pl_reg_gen6_pset_coef5[20:16];

            pl_reg_gen6_pset_coef6[7:0]   <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index6 & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]   : pl_reg_gen6_pset_coef6[7:0];
            pl_reg_gen6_pset_coef6[15:8]  <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index6 & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_reg_gen6_pset_coef6[15:8];
            pl_reg_gen6_pset_coef6[20:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index6 & rate_shadow_sel==2'b11) ? lbc_cdm_data[20:16] : pl_reg_gen6_pset_coef6[20:16];

            pl_reg_gen6_pset_coef7[7:0]   <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index7 & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]   : pl_reg_gen6_pset_coef7[7:0];
            pl_reg_gen6_pset_coef7[15:8]  <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index7 & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_reg_gen6_pset_coef7[15:8];
            pl_reg_gen6_pset_coef7[20:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index7 & rate_shadow_sel==2'b11) ? lbc_cdm_data[20:16] : pl_reg_gen6_pset_coef7[20:16];

            pl_reg_gen6_pset_coef8[7:0]   <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index8 & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]   : pl_reg_gen6_pset_coef8[7:0];
            pl_reg_gen6_pset_coef8[15:8]  <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index8 & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_reg_gen6_pset_coef8[15:8];
            pl_reg_gen6_pset_coef8[20:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index8 & rate_shadow_sel==2'b11) ? lbc_cdm_data[20:16] : pl_reg_gen6_pset_coef8[20:16];

            pl_reg_gen6_pset_coef9[7:0]   <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index9 & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]   : pl_reg_gen6_pset_coef9[7:0];
            pl_reg_gen6_pset_coef9[15:8]  <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index9 & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_reg_gen6_pset_coef9[15:8];
            pl_reg_gen6_pset_coef9[20:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index9 & rate_shadow_sel==2'b11) ? lbc_cdm_data[20:16] : pl_reg_gen6_pset_coef9[20:16];

            pl_reg_gen6_pset_coef10[7:0]   <= #TP (write_pulse[0] & pl_reg_id[1] & pset_index10 & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0]   : pl_reg_gen6_pset_coef10[7:0];
            pl_reg_gen6_pset_coef10[15:8]  <= #TP (write_pulse[1] & pl_reg_id[1] & pset_index10 & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8]  : pl_reg_gen6_pset_coef10[15:8];
            pl_reg_gen6_pset_coef10[20:16] <= #TP (write_pulse[2] & pl_reg_id[1] & pset_index10 & rate_shadow_sel==2'b11) ? lbc_cdm_data[20:16] : pl_reg_gen6_pset_coef10[20:16];
         end
   end

// What is pl_reg_gen6_pset_coefX? {[20:18] pre2 3b, [17:12] post 5b, [11:6] cur 6b, [5:0] pre 4b}, i.e., 21 bits of info. The square brackets indicate bits allocated for the coef in databook but not all of them are used
// With CX_GEN6_SPEED, pl_reg_pset_coefX is COEF_WD_GEN6==21 bits => Need to bitwidth cast pl_reg_gen3/4/5_pset_coefX as they are COEF_WD==18 bits
assign pl_reg_pset_coef0  = COEF_WD_GEN6'( (rate_shadow_sel==2'b00) ? pl_reg_gen3_pset_coef0  : (rate_shadow_sel==2'b01) ? pl_reg_gen4_pset_coef0  : (rate_shadow_sel==2'b10) ? pl_reg_gen5_pset_coef0  : pl_reg_gen6_pset_coef0 );
assign pl_reg_pset_coef1  = COEF_WD_GEN6'( (rate_shadow_sel==2'b00) ? pl_reg_gen3_pset_coef1  : (rate_shadow_sel==2'b01) ? pl_reg_gen4_pset_coef1  : (rate_shadow_sel==2'b10) ? pl_reg_gen5_pset_coef1  : pl_reg_gen6_pset_coef1 );
assign pl_reg_pset_coef2  = COEF_WD_GEN6'( (rate_shadow_sel==2'b00) ? pl_reg_gen3_pset_coef2  : (rate_shadow_sel==2'b01) ? pl_reg_gen4_pset_coef2  : (rate_shadow_sel==2'b10) ? pl_reg_gen5_pset_coef2  : pl_reg_gen6_pset_coef2 );
assign pl_reg_pset_coef3  = COEF_WD_GEN6'( (rate_shadow_sel==2'b00) ? pl_reg_gen3_pset_coef3  : (rate_shadow_sel==2'b01) ? pl_reg_gen4_pset_coef3  : (rate_shadow_sel==2'b10) ? pl_reg_gen5_pset_coef3  : pl_reg_gen6_pset_coef3 );
assign pl_reg_pset_coef4  = COEF_WD_GEN6'( (rate_shadow_sel==2'b00) ? pl_reg_gen3_pset_coef4  : (rate_shadow_sel==2'b01) ? pl_reg_gen4_pset_coef4  : (rate_shadow_sel==2'b10) ? pl_reg_gen5_pset_coef4  : pl_reg_gen6_pset_coef4 );
assign pl_reg_pset_coef5  = COEF_WD_GEN6'( (rate_shadow_sel==2'b00) ? pl_reg_gen3_pset_coef5  : (rate_shadow_sel==2'b01) ? pl_reg_gen4_pset_coef5  : (rate_shadow_sel==2'b10) ? pl_reg_gen5_pset_coef5  : pl_reg_gen6_pset_coef5 );
assign pl_reg_pset_coef6  = COEF_WD_GEN6'( (rate_shadow_sel==2'b00) ? pl_reg_gen3_pset_coef6  : (rate_shadow_sel==2'b01) ? pl_reg_gen4_pset_coef6  : (rate_shadow_sel==2'b10) ? pl_reg_gen5_pset_coef6  : pl_reg_gen6_pset_coef6 );
assign pl_reg_pset_coef7  = COEF_WD_GEN6'( (rate_shadow_sel==2'b00) ? pl_reg_gen3_pset_coef7  : (rate_shadow_sel==2'b01) ? pl_reg_gen4_pset_coef7  : (rate_shadow_sel==2'b10) ? pl_reg_gen5_pset_coef7  : pl_reg_gen6_pset_coef7 );
assign pl_reg_pset_coef8  = COEF_WD_GEN6'( (rate_shadow_sel==2'b00) ? pl_reg_gen3_pset_coef8  : (rate_shadow_sel==2'b01) ? pl_reg_gen4_pset_coef8  : (rate_shadow_sel==2'b10) ? pl_reg_gen5_pset_coef8  : pl_reg_gen6_pset_coef8 );
assign pl_reg_pset_coef9  = COEF_WD_GEN6'( (rate_shadow_sel==2'b00) ? pl_reg_gen3_pset_coef9  : (rate_shadow_sel==2'b01) ? pl_reg_gen4_pset_coef9  : (rate_shadow_sel==2'b10) ? pl_reg_gen5_pset_coef9  : pl_reg_gen6_pset_coef9 );
assign pl_reg_pset_coef10 = COEF_WD_GEN6'( (rate_shadow_sel==2'b00) ? pl_reg_gen3_pset_coef10 : (rate_shadow_sel==2'b01) ? pl_reg_gen4_pset_coef10 : (rate_shadow_sel==2'b10) ? pl_reg_gen5_pset_coef10 : pl_reg_gen6_pset_coef10);

assign pset_index0 = (pl_reg_pseti[3:0] == 4'h0) ?  1'b1 : 1'b0;
assign pset_index1 = (pl_reg_pseti[3:0] == 4'h1) ?  1'b1 : 1'b0;
assign pset_index2 = (pl_reg_pseti[3:0] == 4'h2) ?  1'b1 : 1'b0;
assign pset_index3 = (pl_reg_pseti[3:0] == 4'h3) ?  1'b1 : 1'b0;
assign pset_index4 = (pl_reg_pseti[3:0] == 4'h4) ?  1'b1 : 1'b0;
assign pset_index5 = (pl_reg_pseti[3:0] == 4'h5) ?  1'b1 : 1'b0;
assign pset_index6 = (pl_reg_pseti[3:0] == 4'h6) ?  1'b1 : 1'b0;
assign pset_index7 = (pl_reg_pseti[3:0] == 4'h7) ?  1'b1 : 1'b0;
assign pset_index8 = (pl_reg_pseti[3:0] == 4'h8) ?  1'b1 : 1'b0;
assign pset_index9 = (pl_reg_pseti[3:0] == 4'h9) ?  1'b1 : 1'b0;
assign pset_index10 = (pl_reg_pseti[3:0] == 4'ha) ?  1'b1 : 1'b0;

assign cfg_gen3_eq_coef = {pl_reg_gen3_pset_coef10, pl_reg_gen3_pset_coef9, pl_reg_gen3_pset_coef8, pl_reg_gen3_pset_coef7, pl_reg_gen3_pset_coef6, pl_reg_gen3_pset_coef5,
                           pl_reg_gen3_pset_coef4, pl_reg_gen3_pset_coef3, pl_reg_gen3_pset_coef2, pl_reg_gen3_pset_coef1, pl_reg_gen3_pset_coef0};

assign cfg_gen4_eq_coef = {pl_reg_gen4_pset_coef10, pl_reg_gen4_pset_coef9, pl_reg_gen4_pset_coef8, pl_reg_gen4_pset_coef7, pl_reg_gen4_pset_coef6, pl_reg_gen4_pset_coef5,
                           pl_reg_gen4_pset_coef4, pl_reg_gen4_pset_coef3, pl_reg_gen4_pset_coef2, pl_reg_gen4_pset_coef1, pl_reg_gen4_pset_coef0};

assign cfg_gen5_eq_coef = {pl_reg_gen5_pset_coef10, pl_reg_gen5_pset_coef9, pl_reg_gen5_pset_coef8, pl_reg_gen5_pset_coef7, pl_reg_gen5_pset_coef6, pl_reg_gen5_pset_coef5,
                           pl_reg_gen5_pset_coef4, pl_reg_gen5_pset_coef3, pl_reg_gen5_pset_coef2, pl_reg_gen5_pset_coef1, pl_reg_gen5_pset_coef0};

// Gen6 has different widths for cursors and an additional precursor2, while keeping a total of 18 (COEF_WD) bits : int = {post 5b, cur 6b, pre 4b, pre2 3b}
assign  int_reg_gen6_pset_coef0 = PackGen6PsetCoef(pl_reg_gen6_pset_coef0);
assign  int_reg_gen6_pset_coef1 = PackGen6PsetCoef(pl_reg_gen6_pset_coef1);
assign  int_reg_gen6_pset_coef2 = PackGen6PsetCoef(pl_reg_gen6_pset_coef2);
assign  int_reg_gen6_pset_coef3 = PackGen6PsetCoef(pl_reg_gen6_pset_coef3);
assign  int_reg_gen6_pset_coef4 = PackGen6PsetCoef(pl_reg_gen6_pset_coef4);
assign  int_reg_gen6_pset_coef5 = PackGen6PsetCoef(pl_reg_gen6_pset_coef5);
assign  int_reg_gen6_pset_coef6 = PackGen6PsetCoef(pl_reg_gen6_pset_coef6);
assign  int_reg_gen6_pset_coef7 = PackGen6PsetCoef(pl_reg_gen6_pset_coef7);
assign  int_reg_gen6_pset_coef8 = PackGen6PsetCoef(pl_reg_gen6_pset_coef8);
assign  int_reg_gen6_pset_coef9 = PackGen6PsetCoef(pl_reg_gen6_pset_coef9);
assign int_reg_gen6_pset_coef10 = PackGen6PsetCoef(pl_reg_gen6_pset_coef10);

assign cfg_gen6_eq_coef = {int_reg_gen6_pset_coef10, int_reg_gen6_pset_coef9, int_reg_gen6_pset_coef8, int_reg_gen6_pset_coef7, int_reg_gen6_pset_coef6, int_reg_gen6_pset_coef5,
                            int_reg_gen6_pset_coef4, int_reg_gen6_pset_coef3, int_reg_gen6_pset_coef2, int_reg_gen6_pset_coef1, int_reg_gen6_pset_coef0};

//----------------------------------------------------------------------------------------
// PCIe Gen3 Transmit Equalization Programmable Preset Index viewport register
// cpl_reg_id       - 2
// Length           - 1 byte
// Default value    - 0
// Core registers   - pl_reg_pseti
// ---------------------------------------------------------------------------------------

always @(posedge core_clk or negedge sticky_rst_n)
   begin
      if (!sticky_rst_n)
         begin                                    // Default programmable local FS and LF values
            pl_reg_pseti  <= #TP 4'h0;
         end
      else
         begin
            pl_reg_pseti <= #TP (write_pulse[0] & pl_reg_id[2]) ? lbc_cdm_data[3:0]   : pl_reg_pseti;
         end
   end


always @(pl_reg_pseti or pl_reg_pset_coef0 or pl_reg_pset_coef1 or pl_reg_pset_coef2 or pl_reg_pset_coef3 or pl_reg_pset_coef4 or
        pl_reg_pset_coef5 or pl_reg_pset_coef6 or pl_reg_pset_coef7 or pl_reg_pset_coef8 or pl_reg_pset_coef9 or pl_reg_pset_coef10)
  begin
   case (pl_reg_pseti)
     // pl_reg_pset_coefX is COEF_WD_GEN6==21 bits when CX_GEN6_SPEED defined, or COEF_WD==18 bits when only up to CX_GEN5_SPEED defined
     // Just bitwidth cast up to 32 bits which autofills with 0b
     4'h0: pl_reg_coef = 32'(pl_reg_pset_coef0);
     4'h1: pl_reg_coef = 32'(pl_reg_pset_coef1);
     4'h2: pl_reg_coef = 32'(pl_reg_pset_coef2);
     4'h3: pl_reg_coef = 32'(pl_reg_pset_coef3);
     4'h4: pl_reg_coef = 32'(pl_reg_pset_coef4);
     4'h5: pl_reg_coef = 32'(pl_reg_pset_coef5);
     4'h6: pl_reg_coef = 32'(pl_reg_pset_coef6);
     4'h7: pl_reg_coef = 32'(pl_reg_pset_coef7);
     4'h8: pl_reg_coef = 32'(pl_reg_pset_coef8);
     4'h9: pl_reg_coef = 32'(pl_reg_pset_coef9);
     4'ha: pl_reg_coef = 32'(pl_reg_pset_coef10);
     default: pl_reg_coef = 32'h00000000;
   endcase //(pl_reg_pseti)
  end


//----------------------------------------------------------------------------------------
// PCIe Gen3 Transmit Equalization Programmable Coefficients Legality Status Register
// cpl_reg_id       - 3
// Length           - 1 bit
// Default value    - 0
// Core registers   - pl_reg_violate_rules_prog_coef
// ---------------------------------------------------------------------------------------


always @(posedge core_clk or negedge sticky_rst_n)
   begin
      if (!sticky_rst_n)
         begin
            pl_reg_violate_rules_prog_coef  <= #TP 1'b0;
         end
      else if (read_pulse & pl_reg_id[3])
         begin
            pl_reg_violate_rules_prog_coef <= #TP 1'b0;    // Read Only Sticky: clear on read
         end
      else
         begin
            pl_reg_violate_rules_prog_coef <= #TP current_violate_tx_rules;
         end
   end

assign current_fs = pl_reg_fs_lf[11:6];
assign current_lf = pl_reg_fs_lf[5:0];

// register the most recently written coefficients for rule checking
always @(posedge core_clk or negedge sticky_rst_n)
   begin
      if (!sticky_rst_n)
         begin
            current_coef  <= #TP 18'h0;
        end
      else
         begin
            current_coef[7:0] <= #TP (write_pulse[0] & pl_reg_id[1]) ? lbc_cdm_data[7:0] : current_coef[7:0];
            current_coef[15:8] <= #TP (write_pulse[1] & pl_reg_id[1]) ? lbc_cdm_data[15:8] : current_coef[15:8];
            current_coef[17:16] <= #TP (write_pulse[2] & pl_reg_id[1]) ? lbc_cdm_data[17:16] : current_coef[17:16];
         end
   end

reg [COEF_WD_GEN6-1:0] current_coef_g6_pl_reg;
wire [COEF_WD-1:0] current_coef_g6;
assign current_coef_g6 = PackGen6PsetCoef(current_coef_g6_pl_reg);
// register the most recently written coefficients for rule checking at gen6
always @(posedge core_clk or negedge sticky_rst_n)
   begin
      if (!sticky_rst_n)
         begin
            current_coef_g6_pl_reg  <= #TP 21'h0;
        end
      else
         begin
            current_coef_g6_pl_reg[7:0] <= #TP (write_pulse[0] & pl_reg_id[1] & rate_shadow_sel==2'b11) ? lbc_cdm_data[7:0] : current_coef_g6_pl_reg[7:0];
            current_coef_g6_pl_reg[15:8] <= #TP (write_pulse[1] & pl_reg_id[1] & rate_shadow_sel==2'b11) ? lbc_cdm_data[15:8] : current_coef_g6_pl_reg[15:8];
            current_coef_g6_pl_reg[20:16] <= #TP (write_pulse[2] & pl_reg_id[1] & rate_shadow_sel==2'b11) ? lbc_cdm_data[20:16] : current_coef_g6_pl_reg[20:16];
         end
   end
// Assign the inputs to the violate_rules_prog_coef function:
assign current_violate_tx_rules  = (rate_shadow_sel==2'b11) ? violate_rules_tx_coef_g6(current_coef_g6, current_fs, current_lf) : violate_rules_tx_coef(current_coef, current_fs, current_lf);


function automatic [COEF_WD-1:0] PackGen6PsetCoef(input logic [COEF_WD_GEN6-1:0] pl_reg_gen6_pset_coef);
begin
  // Gen6 has different widths for cursors and an additional precursor2, while keeping a total of 18 (COEF_WD) bits : return = {post 5b, cur 6b, pre 4b, pre2 3b}
  return {pl_reg_gen6_pset_coef[16:12], pl_reg_gen6_pset_coef[11:6], pl_reg_gen6_pset_coef[3:0], pl_reg_gen6_pset_coef[20:18]};
end
endfunction // PackGen6PsetCoef

endmodule                // cdm_pl_pset_coefs
