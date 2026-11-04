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
// ---  RCS information: // ---    $DateTime: 2021/10/29 02:04:56 $ // ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/PTM/ptm_clock.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Precision Time Measurement Extended Capability (PTM) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------



`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module ptm_clock
#(
    parameter INST                  = 0,                                // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM              = 0,                                // uniquifying parameter per function
    parameter NV                    = 21,                               // Max possible number of registers in VSEC Extended Capability Structure   #
    parameter WF                    = 16                                // Width of fractional part of local clock register
   )

  (

  input                                   aux_clk,
  input                                   non_sticky_rst_n,
  input [31:0]                            lbc_cdm_data,                 // Write Data 
  input                                   lbc_cdm_dbi,                  // DBI Access

  input                                   ptm_external_master_strobe,                                     
  input [63:0]                            ptm_external_master_time,

  input                                   ptm_local_clk_enable, 

  input [3:0]                             ptm_local_clk_write_pulse,             // Write Byte Enables, allows setting the PTM Responder master clock
  input [5:4]                             ptm_local_clk_reg_id,                  // VSEC Register ID
 
  input                                   ptm_update_local_clk,
  input [63:0]                            ptm_local_adjust_value,                // Adjusts the PTM Requester's clock to track the calculated PTM Responder master clock

  input [7+WF:0]                          ptm_clock_period,   // PTM local clock is incremented by this amount on each clock tick
  
  output [63:0]                           local_clk,           // 64 bit clock lasts for nearly 600 years if each clock cycle is 1 ns long.
                                                              // This is also the VSEC Register Read Data.
  output [WF-1:0]                         local_clk_frac       // Fractional part of local_clk, for clock period check
);

  localparam TP = `TP;

  reg     [63+WF:0]                       local_clk_reg;
   

  assign local_clk = local_clk_reg[63+WF:WF];
  assign local_clk_frac = local_clk_reg[WF-1:0];

  always @( posedge aux_clk or negedge non_sticky_rst_n ) 
  begin 
    if ( !non_sticky_rst_n ) begin
      local_clk_reg <= #TP 0;

    end else if (ptm_local_clk_enable && ptm_external_master_strobe) begin                                     
        local_clk_reg[63+WF:WF] <= #TP ptm_external_master_time;                          //adjust the local clock to sync to the external master
        local_clk_reg[WF-1:0] <= #TP 0;                                                   //clear the fractional part of the local clock register
 
    end else if (ptm_local_clk_enable && ptm_update_local_clk) begin                                     
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: local_clk and frac_accu_reg wrap around
      local_clk_reg <= #TP {ptm_local_adjust_value, {WF{1'b0}}} + 2*ptm_clock_period;         //adjust the local clock to sync to the master, 2 cycles after adjust value calculation
      // spyglass enable_block W164a

    end else if (ptm_local_clk_enable && |ptm_local_clk_write_pulse & (ptm_local_clk_reg_id[5] | ptm_local_clk_reg_id[4])) begin       //writable over wire and DBI
      local_clk_reg[63+WF:56+WF] <= #TP (ptm_local_clk_write_pulse[3] & ptm_local_clk_reg_id[5]) ? lbc_cdm_data[31:24] : local_clk_reg[63+WF:56+WF];
      local_clk_reg[55+WF:48+WF] <= #TP (ptm_local_clk_write_pulse[2] & ptm_local_clk_reg_id[5]) ? lbc_cdm_data[23:16] : local_clk_reg[55+WF:48+WF];
      local_clk_reg[47+WF:40+WF] <= #TP (ptm_local_clk_write_pulse[1] & ptm_local_clk_reg_id[5]) ? lbc_cdm_data[15:8 ] : local_clk_reg[47+WF:40+WF];
      local_clk_reg[39+WF:32+WF] <= #TP (ptm_local_clk_write_pulse[0] & ptm_local_clk_reg_id[5]) ? lbc_cdm_data[ 7:0 ] : local_clk_reg[39+WF:32+WF];
    
      local_clk_reg[31+WF:24+WF] <= #TP (ptm_local_clk_write_pulse[3] & ptm_local_clk_reg_id[4]) ? lbc_cdm_data[31:24] : local_clk_reg[31+WF:24+WF];
      local_clk_reg[23+WF:16+WF] <= #TP (ptm_local_clk_write_pulse[2] & ptm_local_clk_reg_id[4]) ? lbc_cdm_data[23:16] : local_clk_reg[23+WF:16+WF];
      local_clk_reg[15+WF:8+WF ] <= #TP (ptm_local_clk_write_pulse[1] & ptm_local_clk_reg_id[4]) ? lbc_cdm_data[15:8 ] : local_clk_reg[15+WF:8+WF ];
      local_clk_reg[ 7+WF:0+WF ] <= #TP (ptm_local_clk_write_pulse[0] & ptm_local_clk_reg_id[4]) ? lbc_cdm_data[ 7:0 ] : local_clk_reg[ 7+WF:0+WF ];
 
      local_clk_reg[WF-1:0] <= #TP 0; //clear the fractional part when writing

    end else if (ptm_local_clk_enable) begin
       // spyglass disable_block W164a
       // SMD: Identifies assignments in which the LHS width is less than the RHS width
       // SJ: local_clk and frac_accu_reg wrap around
       local_clk_reg <= #TP local_clk_reg + ptm_clock_period;
       // spyglass enable_block W164a
    end else
       local_clk_reg <= #TP local_clk_reg; 
  end 

endmodule //ptm_frac_clock
