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
// ---    $DateTime: 2023/06/30 15:54:26 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_ltr_reg.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the LTR extended capability registers.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_ltr_reg (
                   // Inputs
                   core_clk,
                   non_sticky_rst_n,
                   sticky_rst_n,
                   cdm_clk_g,
                   lbc_cdm_data,
                   lbc_cdm_dbi,
                   write_pulse,
                   read_pulse,
                   ltr_reg_id,
                   cx_dbi_ro_wr_en,
                   cxl_rcrb_enable,
                   // Outputs
                  cfg_ltr_max_latency,
                  ltr_reg_data
                  );

// *****************************************************************************
// Declare parameters
// *****************************************************************************
   parameter INST          = 0;                    // The uniquifying parameter for each port logic instance.
   parameter FUNC_NUM      = 0;                    // Physical Function Number
   parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)

// *****************************************************************************
// Declare inputs
// *****************************************************************************
   input                     core_clk;
   input                     non_sticky_rst_n;
   input                     sticky_rst_n;
   input                     cdm_clk_g;
   input [31:0]              lbc_cdm_data;                   // Data for write
   input                     lbc_cdm_dbi;
   input [3:0]               write_pulse;
   input                     read_pulse;
   input [1:0]               ltr_reg_id;
   input                     cx_dbi_ro_wr_en;
   input                     cxl_rcrb_enable;                // Indicates that the CXL 1.1 Link is up for USP supporting RCRB

// *****************************************************************************
// Declare outputs
// *****************************************************************************
   output [31:0]             cfg_ltr_max_latency; // LTR Max Snoop & No-Snoop Latencies 
   output [31:0]             ltr_reg_data;        // LTR register read data bus

// *****************************************************************************
// Internal design
// *****************************************************************************

// -----------------------------------------------------------------------------
// Generate DBI write enable
// -----------------------------------------------------------------------------
   wire cx_dbi_ro_wr_en;                    // Determines whether RO LTR register bits are writable through the DBI.

   wire dbi_ro_wr_en = (lbc_cdm_dbi & cx_dbi_ro_wr_en);

// -----------------------------------------------------------------------------
// LTR Extended Capability Structure
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// LTR Extended CAP Header
// ltr_reg_id       - 0
// PCIE Offset      - `LTR_PTR
// Length           - 4 bytes
// Default value    -
// Byte fields      - cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0
// -----------------------------------------------------------------------------
   reg  [15:0] cfg_ltr_id;
   reg  [3:0]  cfg_ltr_ver;
   reg  [11:0] cfg_ltr_nxt_ptr_r; // Next capability offset

reg ltr_next_ptr_wr_updated;
   always @(posedge core_clk or negedge sticky_rst_n) begin : proc_cxl_seq_ltr_nxt_ptr
      if (!sticky_rst_n) begin
        cfg_ltr_nxt_ptr_r       <= #TP  `LTR_NEXT_PTR;
        ltr_next_ptr_wr_updated <= #TP  1'b0;
      end else begin
        if (ltr_reg_id[0] & |write_pulse[3:2] & dbi_ro_wr_en) begin  
          ltr_next_ptr_wr_updated <= #TP  1'b1;
          // Read-Only register, but writable through DBI
          cfg_ltr_nxt_ptr_r[3:0]  <= #TP (dbi_ro_wr_en & write_pulse[2] & ltr_reg_id[0]) ? lbc_cdm_data[23:20] : cfg_ltr_nxt_ptr_r[3:0];
          cfg_ltr_nxt_ptr_r[11:4] <= #TP (dbi_ro_wr_en & write_pulse[3] & ltr_reg_id[0]) ? lbc_cdm_data[31:24] : cfg_ltr_nxt_ptr_r[11:4];
        end
        else if (!ltr_next_ptr_wr_updated) begin
          cfg_ltr_nxt_ptr_r <= #TP (cxl_rcrb_enable) ? `CXL_LTR_NEXT_PTR :  `LTR_NEXT_PTR;
        end
      end
   end

  always @(posedge cdm_clk_g or negedge sticky_rst_n) begin : proc_seq_ltr_nxt_ptr
      if (!sticky_rst_n) begin
        cfg_ltr_id[15:0]  <= #TP `PCIE_LTR_ECAP_ID;      // Capability ID
        cfg_ltr_ver[3:0]  <= #TP `PCIE_LTR_ECAP_VER;     // Capability version

      end else begin
        // Read-Only register, but writable through DBI
        cfg_ltr_id[7:0]         <= #TP (ltr_reg_id[0] & write_pulse[0] & dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_ltr_id[7:0];
        cfg_ltr_id[15:8]        <= #TP (ltr_reg_id[0] & write_pulse[1] & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_ltr_id[15:8];
        cfg_ltr_ver[3:0]        <= #TP (ltr_reg_id[0] & write_pulse[2] & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_ltr_ver[3:0];
      end
   end

   wire [7:0] cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0; // Byte fields
   assign {cfg_reg_3, cfg_reg_2, cfg_reg_1, cfg_reg_0} = {cfg_ltr_nxt_ptr_r,cfg_ltr_ver,cfg_ltr_id};

// -----------------------------------------------------------------------------
// LTR Maximum Latency 
// ltr_reg_id       - 1
// PCIE Offset      - `LTR_PTR + 04h
// Length           - 4 bytes
// Default value    - 
// Byte fields      - cfg_reg_7, cfg_reg_6, cfg_reg_5, cfg_reg_4
// -----------------------------------------------------------------------------
   reg  [9:0] max_sn_l_v_r;    // Max No-Snoop Latency Value Register
   reg  [2:0] max_sn_l_s_r;    // Max Snoop Latency Scale Register
   reg  [9:0] max_no_sn_l_v_r; // Max No-Snoop Latency Value Register
   reg  [2:0] max_no_sn_l_s_r; // Max No-Snoop Latency Scale Register

   always @(posedge cdm_clk_g or negedge non_sticky_rst_n) begin : proc_seq_ltr_max_latency
      if (!non_sticky_rst_n) begin
        max_sn_l_v_r    <= #TP 0;
        max_sn_l_s_r    <= #TP 0;
        max_no_sn_l_v_r <= #TP 0;
        max_no_sn_l_s_r <= #TP 0;
      end else begin
        // Snoop latency
        max_sn_l_v_r[7:0]    <= #TP (write_pulse[0] & ltr_reg_id[1]) ? lbc_cdm_data[7:0]   : max_sn_l_v_r[7:0];        
        max_sn_l_v_r[9:8]    <= #TP (write_pulse[1] & ltr_reg_id[1]) ? lbc_cdm_data[9:8]   : max_sn_l_v_r[9:8];        
        max_sn_l_s_r[2:0]    <= #TP (write_pulse[1] & ltr_reg_id[1]) ? lbc_cdm_data[12:10] : max_sn_l_s_r[2:0];        
        // No Snoop latency
        max_no_sn_l_v_r[7:0] <= #TP (write_pulse[2] & ltr_reg_id[1]) ? lbc_cdm_data[23:16] : max_no_sn_l_v_r[7:0];        
        max_no_sn_l_v_r[9:8] <= #TP (write_pulse[3] & ltr_reg_id[1]) ? lbc_cdm_data[25:24] : max_no_sn_l_v_r[9:8];        
        max_no_sn_l_s_r[2:0] <= #TP (write_pulse[3] & ltr_reg_id[1]) ? lbc_cdm_data[28:26] : max_no_sn_l_s_r[2:0];        
      end
   end
        
   // Assign byte fields
   wire [7:0] cfg_reg_7, cfg_reg_6, cfg_reg_5, cfg_reg_4; // Byte fields
   assign {cfg_reg_7, cfg_reg_6, cfg_reg_5, cfg_reg_4} = {3'b0, max_no_sn_l_s_r, max_no_sn_l_v_r, 3'b0, max_sn_l_s_r, max_sn_l_v_r}; 

// -----------------------------------------------------------------------------
// Read data mux
// -----------------------------------------------------------------------------
   reg  [31:0] ltr_reg_data; // LTR register read data

   always @(*) begin : proc_comb_ltr_reg_read_mux
     case (1'b1)
       ltr_reg_id[0] : begin
         if (FUNC_NUM == 0) begin
           ltr_reg_data = {cfg_reg_3,  cfg_reg_2,  cfg_reg_1,  cfg_reg_0};   // LTR Header for Function 0 only
         end else begin
           ltr_reg_data = {cfg_reg_3,  cfg_reg_2,  16'h0};                   // Null Capability for all other functions
         end
       end

       ltr_reg_id[1] : begin
         if (FUNC_NUM == 0) begin
           ltr_reg_data = {cfg_reg_7,  cfg_reg_6,  cfg_reg_5,  cfg_reg_4};
         end else begin
           ltr_reg_data = 32'h0;      // All other registers are 0 in a Null Capability
         end
       end

       default:        ltr_reg_data = `PCIE_UNUSED_RESPONSE;
     endcase
   end

// -----------------------------------------------------------------------------
// Assign outputs
// -----------------------------------------------------------------------------
   wire [31:0] cfg_ltr_max_latency; // LTR Max Snoop & No-Snoop Latencies 
   assign cfg_ltr_max_latency = {cfg_reg_7,  cfg_reg_6,  cfg_reg_5,  cfg_reg_4};


endmodule
