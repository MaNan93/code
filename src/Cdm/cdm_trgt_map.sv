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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_trgt_map.sv#8 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the programmable target map
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_trgt_map(
// ------------ Inputs ---------------
    core_clk,
    sticky_rst_n,
    cdm_clk_g,
    lbc_cdm_data,
    trgt_map_write_pulse,
    trgt_map_reg_id,
// ------------ Outputs --------------
    trgt_map_reg_data,
    target_mem_map,
    target_rom_map
);

parameter INST  = 0;  // The uniquifying parameter for each port logic instance.
parameter NF    = `CX_NFUNC;                    // number of functions
parameter TP    = `TP;// Clock to Q delay (simulator insurance)
localparam DATA_DELAY_BCM36_NHS = 3;  // Type of random delay to be added to signal in simulation by bcm36_nhs

// ----------- Inputs ---------------
input            core_clk;                       // Core clock
input            sticky_rst_n;                   // Reset for non-sticky registers
input            cdm_clk_g;                   // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
input     [31:0] lbc_cdm_data;                   // Write Data
input     [3:0]  trgt_map_write_pulse;           // Write Data Byte Enables
input     [0:0]  trgt_map_reg_id;                // Target Map Register ID

// ---------- Outputs ----------------
output    [31:0] trgt_map_reg_data;              // target map register read data
output    [(6*NF)-1:0]    target_mem_map;        // Each bit of this vector indicates which target receives memory transactions for that bar #
output    [NF-1:0]        target_rom_map;        // Each bit of this vector indicates which target receives rom    transactions for that bar #

// ---------- Local Parameters --------
localparam NF_WD    = NF > 1 ? $clog2(NF) : 1;

// ---------- Internal Signals --------
reg       [31:0] trgt_map_reg_data;               // register read data
reg       [7:0]  index;                           // Target Map viewport (index)
reg       [(6*NF)-1:0]  target_mem_map;
reg       [NF-1:0][5:0] target_mem_map_packed_arr;
reg       [NF-1:0] target_rom_map;
reg       any_write_pulse;

// -----------------------------------------------------------------------------
// Programmable Targer Map Register
// -----------------------------------------------------------------------------
// trgt_map_reg_id      - 0
// Port Logic Offset    -`CFG_PL_REG + 220h
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// Keeping track of any change occuring to the Target Map Register, 
// for simultaneous update of index and target values
// -----------------------------------------------------------------------------
always @(posedge core_clk or negedge sticky_rst_n)
begin : pulse_proc
    if(!sticky_rst_n) begin    
        any_write_pulse               <= #TP 0;
    end else begin
        any_write_pulse               <= #TP |trgt_map_write_pulse & trgt_map_reg_id[0];
    end
end

// -----------------------------------------------------------------------------
// Registering the index value for a Read operation on the Target Map Register
// -----------------------------------------------------------------------------
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : index_proc
    if(!sticky_rst_n) begin    
        index                         <=  #TP 0;
    end else begin
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        index                         <= #TP (trgt_map_write_pulse[2] & trgt_map_reg_id[0]) ? // Index coding the PF Function number
                                         lbc_cdm_data[23:16] : index;
    end
end

generate
genvar func;
for (func=0; func<NF; func = func+1) begin : gen_trgt_map_reg
localparam FUNC_NUM  = func;              // uniquifying parameter per function
wire index_in;
// Retrieve the index value (lbc_cdm_data[20:16]) active at a time,
// and store the corresponding target values available for this index 
assign index_in = (any_write_pulse && (lbc_cdm_data[20:16] == func));

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : proc_trgt_map_reg 
  if(!sticky_rst_n) begin    
    target_mem_map[6*(1+func)-1:6*func]    <= #TP {`MEM_FUNC_BAR5_TARGET_MAP, `MEM_FUNC_BAR4_TARGET_MAP, `MEM_FUNC_BAR3_TARGET_MAP,
                                               `MEM_FUNC_BAR2_TARGET_MAP, `MEM_FUNC_BAR1_TARGET_MAP, `MEM_FUNC_BAR0_TARGET_MAP};
    target_rom_map[func]                   <= #TP {`ROM_FUNC_TARGET_MAP};
  end 
  else begin
    // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
  if (index_in & any_write_pulse) begin
        target_mem_map[6*(1+func)-1:6*func]      <= #TP lbc_cdm_data[5:0];
        target_rom_map[func]                     <= #TP lbc_cdm_data[6];
   end
  end
end    

end // for loop
endgenerate

// -----------------------------------------------------------------------------
// Read Mux
// -----------------------------------------------------------------------------
always @(*) 
begin : read_data_proc
    trgt_map_reg_data[31:0] = {19'b0, 6'h0, 7'h7F};
    for (int j = 0; j < NF; j = j + 1) begin
      target_mem_map_packed_arr[j] = {6{1'b0}};
    end
    for (int j = 0; j < NF; j = j + 1) begin
      target_mem_map_packed_arr[j] = target_mem_map[j*6 +: 6];
    end
    if (trgt_map_reg_id[0] && !any_write_pulse)   begin
       if (index <= NF) begin
         trgt_map_reg_data[31:0] = {8'b0, index, 3'b0, 6'h0, target_rom_map[index[NF_WD-1:0]], target_mem_map_packed_arr[index[NF_WD-1:0]]};
       end    
    end
end
// leda E267 on

// -----------------------------------------------------------------------------
// Adding bcm for falsepath
// -----------------------------------------------------------------------------

endmodule
