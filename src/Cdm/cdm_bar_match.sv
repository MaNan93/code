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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_bar_match.sv#10 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// ---  This module performs BAR matching for a single Physical Function
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_bar_match (
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    flt_cdm_addr,
    upstream_port,
    type0,
    cfg_io_limit_upper16,
    cfg_io_base_upper16,
    cfg_io_base,
    cfg_io_limit,
    io_is_32bit,
    cfg_io_space_en,
    cfg_mem_space_en,
    cfg_bus_master_en,
    cfg_isa_enable,
    cfg_vga_enable,
    cfg_vga16_decode,
    cfg_bar_is_io,
    cfg_bar_enabled,
    cfg_bar0_start,
    cfg_bar0_limit,
    cfg_bar0_mask,
    cfg_bar1_start,
    cfg_bar1_limit,
    cfg_bar1_mask,
    cfg_bar2_start,
    cfg_bar2_limit,
    cfg_bar2_mask,
    cfg_bar3_start,
    cfg_bar3_limit,
    cfg_bar3_mask,
    cfg_bar4_start,
    cfg_bar4_limit,
    cfg_bar4_mask,
    cfg_bar5_start,
    cfg_bar5_limit,
    cfg_bar5_mask,
    cfg_exp_rom_enable,
    cfg_exp_rom_start,
    cfg_exp_rom_mask,
    cfg_mem_base,
    cfg_mem_limit,
    cfg_pref_mem_base,
    cfg_pref_mem_limit,
    cfg_config_limit,
    cxl_rcrb_enable,
    rcrb_base_addr,
    rcrb_base_addr_valid,
    rcrb_mbar0_addr,
    cxl_2_0_mbar0_offset,
    cxl2p0_enabled,
    cfg_cxl_2_0_ext_alt_mse,                   // Alternate Memory Space Enable 
    cfg_cxl_2_0_ext_alt_bme,                   // Alternate Bus Master Enable
    cfg_cxl_2_0_ext_alt_mem_base,              // Alternate Memory Base
    cfg_cxl_2_0_ext_alt_mem_limit,             // Alternate Memory Limit
    cfg_cxl_2_0_ext_alt_pref_mem_base,         // Alternate Prefetchable Memory Base
    cfg_cxl_2_0_ext_alt_pref_mem_limit,        // Alternate Memory Limit
    cfg_cxl_2_0_ext_alt_pref_mem_base_high,    // Alternate Prefetchable Memory Base High
    cfg_cxl_2_0_ext_alt_pref_mem_limit_high,   // Alternate Prefetchable Memory Base High

// -- outputs --
    cfg_io_match,
    cfg_config_above_match,
    cfg_rom_match,
    cfg_bar_match,
    cfg_mem_match,
    cfg_prefmem_match
    ,
    rcrb_address_reg,
    cfg_rcrb_match,
    cfg_rcrb_mbar0_match,
    cfg_rcrb_mbar0_match_int
    ,cfg_cxl_2_0_mbar0_match
    ,cxl_2_0_mbar0_access_int
    ,cfg_cxl_alt_mem_match
    ,cfg_cxl_alt_prefmem_match

);

parameter INST              = 0;                    // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM          = 0;                    // uniquifying parameter per function
parameter TP                = `TP;                  // Clock to Q delay (simulator insurance)
parameter LBC_DW               = 32;
parameter RCRB  = 0;                                              // This parameter is used to distinguish between the RCIEP cfg space and the RCRB cfg space

// -------------- Inputs ---------------
input                           core_clk;                       // Core Clock
input                           non_sticky_rst_n;               // Non-Sticky Reset
input   [63:0]                  flt_cdm_addr;                   // 64-bit address to be compared with BAR
input                           upstream_port;                  // upstream port when set
input                           type0;                          // Maybe make this a bus??
input   [15:0]                  cfg_io_base_upper16;            // Upper 16 bit IO base address
input   [15:0]                  cfg_io_limit_upper16;           // Upper 16 bit IO limit address
input   [7:0]                   cfg_io_base;                    // IO base address
input   [7:0]                   cfg_io_limit;                   // IO limit address
input                           io_is_32bit;
input                           cfg_io_space_en;                // IO Space enable
input                           cfg_mem_space_en;               // Memory space enable
input                           cfg_bus_master_en;              // Bus master enable
input                           cfg_isa_enable;                 // For bridge: ISA enable
input                           cfg_vga_enable;                 // For bridge: VGA enable (optional)
input                           cfg_vga16_decode;               // For bridge: VGA 16-bit decode (optional)
input   [5:0]                   cfg_bar_is_io;                  // Indicates whether the BAR is set as IO or memory
input   [5:0]                   cfg_bar_enabled;                // Indicates whether the BAR is enabled or not
input   [63:0]                  cfg_bar0_start;                 // BAR0 start address
input   [63:0]                  cfg_bar0_limit;                 // BAR0 limit address
input   [63:0]                  cfg_bar0_mask;                  // BAR0 mask register
input   [31:0]                  cfg_bar1_start;                 // BAR1 start address
input   [31:0]                  cfg_bar1_limit;                 // BAR1 limit address
input   [31:0]                  cfg_bar1_mask;                  // BAR1 mask register
input   [63:0]                  cfg_bar2_start;                 // BAR2 start address
input   [63:0]                  cfg_bar2_limit;                 // BAR2 limit address
input   [63:0]                  cfg_bar2_mask;                  // BAR2 mask register
input   [31:0]                  cfg_bar3_start;                 // BAR3 start address
input   [31:0]                  cfg_bar3_limit;                 // BAR3 limit address
input   [31:0]                  cfg_bar3_mask;                  // BAR3 mask register
input   [63:0]                  cfg_bar4_start;                 // BAR4 start address
input   [63:0]                  cfg_bar4_limit;                 // BAR4 limit address
input   [63:0]                  cfg_bar4_mask;                  // BAR4 mask register
input   [31:0]                  cfg_bar5_start;                 // BAR5 start address
input   [31:0]                  cfg_bar5_limit;                 // BAR5 limit address
input   [31:0]                  cfg_bar5_mask;                  // BAR5 mask register
input                           cfg_exp_rom_enable;             // Indicates whether the ROM BAR is enabled or not
input   [31:0]                  cfg_exp_rom_start;              // Expansion ROM start address
input   [31:0]                  cfg_exp_rom_mask;               // ROM BAR Mask
input   [15:0]                  cfg_mem_base;                   // Memory start address
input   [15:0]                  cfg_mem_limit;                  // Memory limit address
input   [63:0]                  cfg_pref_mem_base;              // Prefetchable memory start address
input   [63:0]                  cfg_pref_mem_limit;             // Prefetchable memory limit address
input   [9:0]                   cfg_config_limit;               // CONFIG_LIMIT_REG
input                           cxl_rcrb_enable;              // Indicates that the CXL 1.1 link is up
input   [63:12]                 rcrb_base_addr;
input                           rcrb_base_addr_valid;
input   [63:16]                 rcrb_mbar0_addr;
input  [63:0]                   cxl_2_0_mbar0_offset;                      // Offset of CXL 2.0 MEMBAR0 in Func0, BAR0
input                           cxl2p0_enabled;                            // Indicates link is up in CXL 2.0 mode
input                           cfg_cxl_2_0_ext_alt_mse;                   // Alternate Memory Space Enable 
input                           cfg_cxl_2_0_ext_alt_bme;                   // Alternate Bus Master Enable
input  [11:0]                   cfg_cxl_2_0_ext_alt_mem_base;              // Alternate Memory Base
input  [11:0]                   cfg_cxl_2_0_ext_alt_mem_limit;             // Alternate Memory Limit
input  [11:0]                   cfg_cxl_2_0_ext_alt_pref_mem_base;         // Alternate Prefetchable Memory Base
input  [11:0]                   cfg_cxl_2_0_ext_alt_pref_mem_limit;        // Alternate Memory Limit
input  [31:0]                   cfg_cxl_2_0_ext_alt_pref_mem_base_high;    // Alternate Prefetchable Memory Base High
input  [31:0]                   cfg_cxl_2_0_ext_alt_pref_mem_limit_high;   // Alternate Prefetchable Memory Base High

// -------------- Outputs --    ------------
output                          cfg_io_match;                   // Within IO address range
output                          cfg_config_above_match;         // Adress is above certain user configuration limit
output                          cfg_rom_match;                  // Within expansion ROM address range
output  [5:0]                   cfg_bar_match;                  // Within BAR range
output                          cfg_mem_match;                  // Within Memory range (Type 1 only)
output                          cfg_prefmem_match;              // Within Prefetchable Memorey range (Type 1 only)
output                          cfg_rcrb_match;                 //The upper address bits[63:12] of the first memory access received after link initialization is the RCRB base address
output                          cfg_rcrb_mbar0_match;           //RCRB MEMBAR0 for configuring the CXL subsystem components 
output                          cfg_rcrb_mbar0_match_int;       //RCRB MEMBAR0 for configuring the CXL subsystem components in CDM
output [63:12]                  rcrb_address_reg;               //registering the input RADM Snoop RCRB Base Address in cdm_bar_match 
output                          cfg_cxl_2_0_mbar0_match;
output                          cxl_2_0_mbar0_access_int;
output                          cfg_cxl_alt_mem_match;
output                          cfg_cxl_alt_prefmem_match;
reg                             cfg_io_match;
reg                             cfg_config_above_match;
reg                             cfg_rom_match;
reg                             cfg_mem_match;
reg                             cfg_prefmem_match;
reg     [5:0]                   cfg_bar_match;
wire    [5:0]                   cfg_bar_match_int;
wire                            io16_range;
wire                            io32_range;
wire                            isa_io_match;
wire                            vga_io_match;
wire                            vga_mem_match;

reg                             cfg_rcrb_match;
reg                             cfg_rcrb_mbar0_match;
reg                             cfg_rcrb_mbar0_match_int;
reg [63:12]                     rcrb_address_reg;             //registering the input RADM Snoop RCRB Base Address in cdm_bar_match 
reg                             cfg_cxl_2_0_mbar0_match;
reg                             cxl_2_0_mbar0_access_int;
reg                             cfg_cxl_alt_mem_match;
reg                             cfg_cxl_alt_prefmem_match;
wire [LBC_DW-1:0]               cxl_2_0_mbar0_addr;             // Offset of the register being accessed relative to the MEMBAR0 offset in BAR0

wire [63:0] unroll_bar_mask;



// =============================================================================
// =============================================================================
// Address matching with available BARs
// =============================================================================
// =============================================================================

assign io16_range =  type0 ? 1'b1 :
                    ((flt_cdm_addr[15:0] <= {cfg_io_limit[7:4], 12'hFFF}) &
                    (flt_cdm_addr[15:0] >= {cfg_io_base[7:4], 12'h0}) & (flt_cdm_addr[63:16] == 48'h0) &
                    cfg_io_space_en);

assign io32_range =  type0 ? 1'b1 :
                    ((flt_cdm_addr[31:0] <= {cfg_io_limit_upper16, cfg_io_limit[7:4], 12'hFFF}) &
                    (flt_cdm_addr[31:0] >= {cfg_io_base_upper16, cfg_io_base[7:4], 12'h0}) &
                    (flt_cdm_addr[63:32] == 32'h0) & cfg_io_space_en);


assign isa_io_match     = 0;


assign vga_io_match  = 0;
assign vga_mem_match = 0;

assign cfg_bar_match_int[0]= cfg_bar_enabled[0] & ((flt_cdm_addr & ~cfg_bar0_mask) == (cfg_bar0_start & ~cfg_bar0_mask))
                  & ((~cfg_bar_is_io[0] & (cfg_mem_space_en||!upstream_port)) | (cfg_bar_is_io[0] & (cfg_io_space_en||!upstream_port)));
assign cfg_bar_match_int[1]= cfg_bar_enabled[1] & ((flt_cdm_addr[31:0] & ~cfg_bar1_mask) == (cfg_bar1_start[31:0] & ~cfg_bar1_mask)) & (flt_cdm_addr[63:32] == 32'b0)
                  & ((~cfg_bar_is_io[1] & (cfg_mem_space_en||!upstream_port)) | (cfg_bar_is_io[1] & (cfg_io_space_en||!upstream_port)));
assign cfg_bar_match_int[2]= cfg_bar_enabled[2] & ((flt_cdm_addr & ~cfg_bar2_mask) == (cfg_bar2_start & ~cfg_bar2_mask))
                  & ((~cfg_bar_is_io[2] & cfg_mem_space_en) | (cfg_bar_is_io[2] & cfg_io_space_en));
assign cfg_bar_match_int[3]= cfg_bar_enabled[3] & ((flt_cdm_addr[31:0] & ~cfg_bar3_mask) == (cfg_bar3_start[31:0] & ~cfg_bar3_mask)) & (flt_cdm_addr[63:32] == 32'b0)
                  & ((~cfg_bar_is_io[3] & cfg_mem_space_en) | (cfg_bar_is_io[3] & cfg_io_space_en));
assign cfg_bar_match_int[4]= cfg_bar_enabled[4] & ((flt_cdm_addr & ~cfg_bar4_mask) == (cfg_bar4_start & ~cfg_bar4_mask))
                  & ((~cfg_bar_is_io[4] & cfg_mem_space_en) | (cfg_bar_is_io[4] & cfg_io_space_en));
assign cfg_bar_match_int[5]= cfg_bar_enabled[5] & ((flt_cdm_addr[31:0] & ~cfg_bar5_mask) == (cfg_bar5_start[31:0] & ~cfg_bar5_mask)) & (flt_cdm_addr[63:32] == 32'b0)
                         & ((~cfg_bar_is_io[5] & cfg_mem_space_en) | (cfg_bar_is_io[5] & cfg_io_space_en));

//UNROLL BAR MASK      
case (`UNROLL_BAR_NUM)
  0: begin: UNROLL_BAR_NUM_0 assign unroll_bar_mask = cfg_bar0_mask; end
  1: begin: UNROLL_BAR_NUM_1 assign unroll_bar_mask = {{32{1'b0}},cfg_bar1_mask}; end
  2: begin: UNROLL_BAR_NUM_2 assign unroll_bar_mask = cfg_bar2_mask; end
  3: begin: UNROLL_BAR_NUM_3 assign unroll_bar_mask = {{32{1'b0}},cfg_bar3_mask}; end
  4: begin: UNROLL_BAR_NUM_4 assign unroll_bar_mask = cfg_bar4_mask; end
  5: begin: UNROLL_BAR_NUM_5 assign unroll_bar_mask = {{32{1'b0}},cfg_bar5_mask}; end
  default:begin: UNROLL_BAR_NUM_dflt assign unroll_bar_mask = cfg_bar0_mask; end
endcase







assign cxl_2_0_mbar0_addr           = (flt_cdm_addr[LBC_DW-1:0] & cfg_bar0_mask[LBC_DW-1:0]);



always @(posedge core_clk or negedge non_sticky_rst_n)
begin : bar_match_PROC
    if (!non_sticky_rst_n) begin
        cfg_config_above_match  <= #TP 0;
        cfg_io_match            <= #TP 0;
        cfg_rom_match           <= #TP 0;
        cfg_mem_match           <= #TP 0;
        cfg_prefmem_match       <= #TP 0;
        cfg_bar_match           <= #TP 0;
        cfg_rcrb_match          <= #TP 0;
        cfg_rcrb_mbar0_match    <= #TP 0;
        cfg_rcrb_mbar0_match_int    <= #TP 0;
        rcrb_address_reg        <= #TP 0;
        cfg_cxl_2_0_mbar0_match     <= #TP 0;
        cxl_2_0_mbar0_access_int    <= #TP 0;
        cfg_cxl_alt_mem_match       <= #TP 0;
        cfg_cxl_alt_prefmem_match   <= #TP 0;
    end
    else begin
        // This signal is to allow certain configuration accesses (above
        // CONFIG_LIMIT_REG) to be routed to TRGT1 interface
        cfg_config_above_match  <= #TP (flt_cdm_addr[11:2] > cfg_config_limit || ~|flt_cdm_addr[11:8] && flt_cdm_addr[7:2] > `PCI_CONFIG_LIMIT);
        cfg_io_match            <= #TP ((io_is_32bit ? io32_range : io16_range) || vga_io_match || isa_io_match);
        cfg_rom_match           <= #TP cfg_exp_rom_enable & ((flt_cdm_addr[31:0] & ~cfg_exp_rom_mask) == (cfg_exp_rom_start & ~cfg_exp_rom_mask)) & (flt_cdm_addr[63:32] == 32'b0);
        cfg_bar_match           <= #TP cfg_bar_match_int;
  
        // In RC & SW downstream device, since we accept transactions that are
        // outside the range,
        // if the bus master is not enabled, we have to say that it's
        // a match so the filter will reject it
        // Also, an upstream port should treat transactions inside the range
        // as UR when mem space enable is clear 
        if (~upstream_port & !cfg_bus_master_en) begin
            cfg_mem_match       <= #TP 1'b1;
            cfg_prefmem_match   <= #TP 1'b1;
        end
        else if (upstream_port & !cfg_mem_space_en) begin
            cfg_mem_match       <= #TP 1'b0;
            cfg_prefmem_match   <= #TP 1'b0;
        end
        else begin
            cfg_mem_match       <= #TP ((flt_cdm_addr >= {32'b0, cfg_mem_base, 16'b0}) & (flt_cdm_addr <= {32'b0, cfg_mem_limit, 16'hFFFF}))
                                       || vga_mem_match;
            cfg_prefmem_match   <= #TP (flt_cdm_addr >= cfg_pref_mem_base) & (flt_cdm_addr <= cfg_pref_mem_limit);
        end
        if (!(|RCRB)) begin
           cfg_rcrb_mbar0_match <= #TP 0;
           cfg_rcrb_mbar0_match_int <= #TP 0;
           if (FUNC_NUM==0) begin
              cfg_rcrb_match       <= #TP ((flt_cdm_addr >= {rcrb_address_reg, 12'b0}) & (flt_cdm_addr <= {rcrb_address_reg, 12'hFFF}) & cxl_rcrb_enable);
              if (rcrb_base_addr_valid)
                 rcrb_address_reg  <= #TP rcrb_base_addr;
           end
           else begin
              cfg_rcrb_match          <= #TP 0;
              rcrb_address_reg        <= #TP 0;
           end
        end
        else begin
           cfg_rcrb_match          <= #TP 0;
           cfg_rcrb_mbar0_match    <= #TP ((flt_cdm_addr >= {rcrb_mbar0_addr, 16'b0}) & (flt_cdm_addr <= {rcrb_mbar0_addr, 16'hFFFF}) & cxl_rcrb_enable);
           cfg_rcrb_mbar0_match_int <= #TP ((flt_cdm_addr >= {rcrb_mbar0_addr, 16'b0}) & (flt_cdm_addr <= {rcrb_mbar0_addr, 16'hFFFF}) & cxl_rcrb_enable) 
                                           & ((flt_cdm_addr[15:0] >= 16'h1000 && flt_cdm_addr[15:0] <= 16'h100F) 
                                           || (flt_cdm_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_RAS_CAP_PTR) && flt_cdm_addr[15:0] < (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR)) 
                                           || (flt_cdm_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 16'h0038) && flt_cdm_addr[15:0] <= 16'h11FF) 
                                           || (flt_cdm_addr[15:0] >= 16'hE000 && flt_cdm_addr[15:0] <= 16'hE3FF));  
           rcrb_address_reg        <= #TP 0;
        end        
        cfg_cxl_2_0_mbar0_match        <= #TP (cxl2p0_enabled) & ((flt_cdm_addr[63:16] & cfg_bar0_mask[63:16]) == cxl_2_0_mbar0_offset[63:16])
                                              & (cfg_bar_enabled[0] & ((flt_cdm_addr & ~cfg_bar0_mask) == (cfg_bar0_start & ~cfg_bar0_mask))
                                                 & ((~cfg_bar_is_io[0] & (cfg_mem_space_en||!upstream_port)) | (cfg_bar_is_io[0] & (cfg_io_space_en||!upstream_port))));

        cxl_2_0_mbar0_access_int  <= #TP ( ((flt_cdm_addr[63:16] & cfg_bar0_mask[63:16]) == cxl_2_0_mbar0_offset[63:16])
                                         && (get_bar_num(cfg_bar_match_int[0 +: 6]) == `CX_CXL_2_0_COMP_REG_BAR_NUM)
                                         & ((cxl_2_0_mbar0_addr[15:0] >= 16'h1000 && cxl_2_0_mbar0_addr[15:0] <= 16'h100F) 
                                         || (cxl_2_0_mbar0_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_RAS_CAP_PTR) && cxl_2_0_mbar0_addr[15:0] < (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR)) 
                                         || (cxl_2_0_mbar0_addr[15:0] >= (16'h1000 + `CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 16'h0038) && cxl_2_0_mbar0_addr[15:0] <= 16'h11FF) 
                                         || (cxl_2_0_mbar0_addr[15:0] >= 16'hE000 && cxl_2_0_mbar0_addr[15:0] <= 16'hE3FF)) ); 
        if (~upstream_port & !cfg_cxl_2_0_ext_alt_bme) begin
           cfg_cxl_alt_mem_match       <= #TP 1;
           cfg_cxl_alt_prefmem_match   <= #TP 1;   
        end else if (upstream_port & !cfg_cxl_2_0_ext_alt_mse) begin
           cfg_cxl_alt_mem_match       <= #TP 0;
           cfg_cxl_alt_prefmem_match   <= #TP 0;
        end else begin
           cfg_cxl_alt_mem_match       <= #TP (flt_cdm_addr >= {32'b0, cfg_cxl_2_0_ext_alt_mem_base, 20'b0}) & (flt_cdm_addr <= {32'b0, cfg_cxl_2_0_ext_alt_mem_limit, 20'hFFFFF});
           cfg_cxl_alt_prefmem_match   <= #TP (flt_cdm_addr >= {cfg_cxl_2_0_ext_alt_pref_mem_base_high, cfg_cxl_2_0_ext_alt_pref_mem_base, 20'b0}) & (flt_cdm_addr <= {cfg_cxl_2_0_ext_alt_pref_mem_limit_high, cfg_cxl_2_0_ext_alt_pref_mem_limit, 20'hFFFFF});
        end   
     end
end





// Get a bar number from the one hot bar match
function automatic [2:0] get_bar_num;
input [5:0] bar;
begin
    casez  (bar)
        6'b000000 : get_bar_num = `RADM_OUTSIDE_MEMBAR;
        6'b?????1 : get_bar_num = 3'd0;
        6'b????10 : get_bar_num = 3'd1;
        6'b???100 : get_bar_num = 3'd2;
        6'b??1000 : get_bar_num = 3'd3;
        6'b?10000 : get_bar_num = 3'd4;
        6'b100000 : get_bar_num = 3'd5;
    endcase
end
endfunction

endmodule // cdm_bar_match
