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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/DWC_pcie_amba_cdc_fifo_dff.sv#7 $
// -------------------------------------------------------------------------
// Module Description:
// Independent dual clock crossing FIFO with static programmable
// almost empty and almost full flags
//
// Parameters                        Valid Values
// WIDTH                             [ 1 to 256 ]
// DEPTH                             [ 4 to 256 ]
// ADDR_WIDTH                        [ 2 to 8 ]
// COUNT_WIDTH                       [ 3 to 9 ]
// PUSH_AE_LVL                       [ 1 to DEPTH-1 ]
// PUSH_AF_LVL                       [ 1 to DEPTH-1 ]
// POP_AE_LVL                        [ 1 to DEPTH-1 ]
// POP_AF_LVL                        [ 1 to DEPTH-1 ]
// ERR_MODE                          [ 0 = sticky error flag,
//                                     1 = dynamic error flag ]
// PUSH_SYNC                         [ 1 = single synchronized,
//                                     2 = double synchronized,
//                                     3 = triple synchronized,
//                                     4 = quadruple synchronized ]
// POP_SYNC                          [ 1 = single synchronized,
//                                     2 = double synchronized,
//                                     3 = triple synchronized,
//                                     4 = quadruple synchronized ]
// RST_MODE                          [ 0 = inc. mem in resets
//                                     1 = exclude mem in resets ]
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_amba_cdc_fifo_dff
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter WIDTH                         = 1,
  parameter DEPTH                         = 4,
  parameter ADDR_WIDTH                    = 2,
  parameter COUNT_WIDTH                   = 3,
  parameter PUSH_AE_LVL                   = 1,
  parameter PUSH_AF_LVL                   = 1,
  parameter POP_AE_LVL                    = 1,
  parameter POP_AF_LVL                    = 1,
  parameter ERR_MODE                      = 0,
  parameter PUSH_SYNC                     = 2,
  parameter POP_SYNC                      = 2,
  parameter RST_MODE                      = 1,
  parameter HOLD_RD_ADDR                  = 0,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                            = `TP
 )
 (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  // clk_push: Push I/F Input Clock
  // rst_push_n: Active Low Asynch. Reset for push domain
  // clk_pop: Pop I/F Input Clock
  // rst_pop_n: Active Low Asynch. Reset for pop domain
  input                                              clk_push,
  input                                              rst_push_n,
  input                                              clk_pop,
  input                                              rst_pop_n,
  // -------------------------------------------------------------------------------------
  // Test
  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // Push Interface
  // -------------------------------------------------------------------------------------
  // push_req_n: Active Low Push Request
  // push_data: FIFO push data input
  // push_af: Push Almost Full Flag
  // push_word_count: Words in FIFO (push IF perception)
  input                                              push_req_n,
  input       [WIDTH-1:0]                            push_data,
  output wire                                        push_af,
  output wire                                        push_full,
  output wire [COUNT_WIDTH-1:0]                      push_word_count,
  // -------------------------------------------------------------------------------------
  // Pop Interface
  // -------------------------------------------------------------------------------------
  // pop_req_n: Active Low Pop Request
  // pop_empty: Pop I/F Empty Flag
  // pop_data: FIFO popped data output
  // pop_word_count: Words in FIFO (pop IF perception)
  input                                              pop_req_n,
  input                                              halt,
  output wire                                        pop_empty,
  output wire [WIDTH-1:0]                            pop_data
 );

  // ---------------------------------------------------------------------------
  // Local parameters declaration
  // ---------------------------------------------------------------------------

  localparam integer REG_DELAY_DENOM = 1000;
  localparam integer REG_DELAY_TIME  = `TP * REG_DELAY_DENOM;
  localparam               MEM_MODE  = 0;

  // -------------------------------------------------------------------------------------
  // Internal wires/regs
  // -------------------------------------------------------------------------------------
  wire [ADDR_WIDTH-1 : 0]                            fctl_wr_addr;
  wire [ADDR_WIDTH-1 : 0]                            fctl_rd_addr;
  reg  [ADDR_WIDTH-1 : 0]                            r_fctl_rd_addr;
  wire [ADDR_WIDTH-1 : 0]                            s_rd_addr;
  wire                                               fctl_we_n;
  wire                                               s_mem_rst_n;

  wire                                               s_push_req_n;

  wire                                               s_pop_req_n;

  // Internal sub-block outputs not connected to the top level entity.
  // push_empty_nc: Push I/F Empty Flag
  // push_ae_nc: Push I/F Almost Empty Flag
  // push_hf_nc: Push I/F Half Full Flag
  // push_af_nc: Push I/F Almost Full Flag
  // push_error_nc: Push I/F Error Flag
  // pop_ae_nc: Pop I/F Almost Empty Flag
  // pop_hf_nc: Pop I/F Half Full Flag
  // pop_af_nc: Pop I/F Almost Full Flag
  // pop_full_nc: Pop I/F Full Flag
  // pop_error_nc: Pop I/F Error Flag
  // pop_word_count_nc: Words in FIFO (pop IF perception)
  wire                                               push_empty_nc;
  wire                                               push_ae_nc;
  wire                                               push_hf_nc;
  wire                                               push_error_nc;
  wire                                               pop_ae_nc;
  wire                                               pop_hf_nc;
  wire                                               pop_af_nc;
  wire                                               pop_full_nc;
  wire                                               pop_error_nc;
  wire [COUNT_WIDTH-1:0]                             pop_word_count_nc;
  // -------------------------------------------------------------------------------------
  // Internal design
  // -------------------------------------------------------------------------------------
  // Calculate the physical memory depth:
  // If addressable memory space is equal to 2^DEPTH then the FIFO controller DEPTH
  // parameter and physical memory depth parameter, MEM_DEPTH, are the same.
  // If the DEPTH parameter is odd then MEM_DEPTH = DEPTH+1.
  // If the DEPTH parameter is even then MEM_DEPTH = DEPTH+2.
  localparam MEM_DEPTH  =  (DEPTH == (1<<ADDR_WIDTH)) ?
                               DEPTH :
                               DEPTH + (((DEPTH & 1) == 1) ? 1 : 2);

  // Reset memory or not based on RST_MODE parameter.
  generate
    if (RST_MODE == 0) begin : gen_reset_mem
      assign s_mem_rst_n = rst_push_n;
    end else begin : gen_not_reset_mem
      assign s_mem_rst_n = 1'b1;
    end
  endgenerate

  // -------------------------------------------------------------------------------------
  // Instantiate FIFO controller
  // -------------------------------------------------------------------------------------
  DWC_pcie_ctl_bcm87
  
  #(
  .DEPTH                              (DEPTH)
  ,.ADDR_WIDTH                        (ADDR_WIDTH)
  ,.COUNT_WIDTH                       (COUNT_WIDTH)
  ,.PUSH_AE_LVL                       (PUSH_AE_LVL)
  ,.PUSH_AF_LVL                       (PUSH_AF_LVL)
  ,.POP_AE_LVL                        (POP_AE_LVL)
  ,.POP_AF_LVL                        (POP_AF_LVL)
  ,.ERR_MODE                          (ERR_MODE)
  ,.PUSH_SYNC                         (PUSH_SYNC)
  ,.POP_SYNC                          (POP_SYNC)
  ,.REG_DELAY_TIME                    (REG_DELAY_TIME)
  ,.REG_DELAY_DENOM                   (REG_DELAY_DENOM)
  ,.MEM_MODE                          (MEM_MODE)
  )
  u_fctl
  (
  // Clocks and resets
  .clk_push                          (clk_push)
  ,.rst_push_n                       (rst_push_n)
  ,.init_push_n                      (1'b1)
  ,.clk_pop                          (clk_pop)
  ,.rst_pop_n                        (rst_pop_n)
  ,.init_pop_n                       (1'b1)
  // Push interface
  ,.push_req_n                       (s_push_req_n)
  ,.push_empty                       (push_empty_nc)
  ,.push_ae                          (push_ae_nc)
  ,.push_hf                          (push_hf_nc)
  ,.push_af                          (push_af)
  ,.push_full                        (push_full)
  ,.push_error                       (push_error_nc)
  ,.push_word_count                  (push_word_count)
  // Pop interface
  ,.pop_req_n                        (s_pop_req_n)
  ,.pop_empty                        (pop_empty)
  ,.pop_ae                           (pop_ae_nc)
  ,.pop_hf                           (pop_hf_nc)
  ,.pop_af                           (pop_af_nc)
  ,.pop_full                         (pop_full_nc)
  ,.pop_error                        (pop_error_nc)
  ,.pop_word_count                   (pop_word_count_nc)
  // Memory interface
  ,.we_n                             (fctl_we_n)
  ,.wr_addr                          (fctl_wr_addr)
  ,.rd_addr                          (fctl_rd_addr)
  );

  // -------------------------------------------------------------------------------------
  // Instantiate Flip-flop FIFO memory
  // -------------------------------------------------------------------------------------
  DWC_pcie_mem_dff
  
  #(
  .WIDTH                             (WIDTH)
  ,.DEPTH                            (MEM_DEPTH)
  ,.ADDR_WIDTH                       (ADDR_WIDTH)
  )
  u_fmem
  (
  // Clocks and resets
  .clk                               (clk_push)
  ,.rst_n                            (s_mem_rst_n)
  // Memory interface
  ,.wr_n                             (fctl_we_n)
  ,.wr_data                          (push_data)
  ,.rd_addr                          (s_rd_addr)
  ,.rd_n                             (pop_empty) // gating the output data when empty to ensure a write to an empty FIFO doesn't propagate asynchronously to the output
  ,.wr_addr                          (fctl_wr_addr)
  ,.rd_data                          (pop_data)
  );

  // Stop popping when halt asserted
  assign s_pop_req_n = pop_req_n | halt;

  // -------------------------------------------------------------------------------------
  // Hold RAM read address when pop de-asserted.
  // Holds pop data until next pop.
  generate
    if (HOLD_RD_ADDR) begin : gen_hold_ram_rd_addr

      // Stop pushing when one from full flag asserted to avoid corrupting held mem data
      assign s_push_req_n = push_req_n | push_af;

      // Register read address when pop active
      always @(posedge clk_pop or negedge rst_pop_n) begin : proc_seq_fctl_rd_addr
        if (!rst_pop_n) begin
           r_fctl_rd_addr <= # TP {ADDR_WIDTH{1'b0}};
        end else if (!s_pop_req_n) begin
           r_fctl_rd_addr <= # TP fctl_rd_addr;
        end
      end

      // Hold RAM read address when pop de-asserted.
      assign s_rd_addr = ~s_pop_req_n ? fctl_rd_addr : r_fctl_rd_addr;

    end else begin : gen_not_hold_ram_rd_addr
      assign s_push_req_n = push_req_n | push_full;
      assign s_rd_addr    = fctl_rd_addr;
    end
  endgenerate

  `ifndef SYNTHESIS
  `endif

endmodule
