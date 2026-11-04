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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2024/01/19 09:25:58 $
// ---   $Revision: #17 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_tx_tl_chdata_buff.sv#17 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Interface Layer Message Channel Buffer
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_cxl_mem_cache_tx_tl_chdata_buff #(
  parameter TP = `TP,
  parameter CXL_CHDATA_CREDITS    = 1,
  parameter CXL_CHDATA_MSGNUM     = 1,
  parameter CXL_CHDATA_PATH       = 1, //1 = 512b, 2 =1024b
  parameter CXL_CHDATA_WIDTH      = 512,
  parameter CXL_CHRAM_DATAW       = 512,
  parameter CXL_CHRAM_ADDRW       = 3,
  parameter CXL_CHRAM_DEPTH       = 8,
  parameter CXL_CHDATA_OUTNUM     = CXL_CHDATA_PATH + (CXL_CHDATA_MSGNUM - CXL_CHDATA_PATH)
) (
    // Clock and Reset
    input                          cxl_clk,               // CXL clock
    input                          cxl_rst_n,             // CXL active low asynchronous reset
    input                          core_clk,              // Core clock
    input                          core_rst_n,            // Core active low asynchronous reset
    input                          pos_core_clk,          // Core clock positive edge at cxl_clk domain

    input                          cxl_chdata_vld_i,      // Channel Interface Data Input Valid
    input  [CXL_CHDATA_WIDTH-1:0]  cxl_chdata_i,          // Channel Interface Data Input
    input  [CXL_CHDATA_PATH-1:0]   cxl_chdata_halt_i,     // Transaction Layer Channel Halts
    input  [CXL_CHRAM_DATAW-1:0]   cxl_ram_rdata,         // Channel RAM Read Data
    output                         cxl_ram_re,            // Channel RAM Read Enable
    output [CXL_CHRAM_ADDRW-1:0]   cxl_ram_raddr,         // Channel RAM Read Address
    output                         cxl_ram_we,            // Channel RAM Write Enable
    output [CXL_CHRAM_ADDRW-1:0]   cxl_ram_waddr,         // Channel RAM Write Address
    output [CXL_CHRAM_DATAW-1:0]   cxl_ram_wdata,         // Channel RAM Write Data
    output                         cxl_chdata_ovflw_o,    // Channel Data FIFO Overflow
    output                         cxl_chdata_af_o,       // Channel Data FIFO Almost Full
    output                         cxl_chdata_empty_o,    // Channel Data FIFO Empty
    output logic [CXL_CHDATA_PATH-1:0]   cxl_chdata_vld_o,      // Channel Data Valid
    output logic [CXL_CHDATA_OUTNUM-1:0][CXL_CHDATA_WIDTH-1:0]  cxl_chdata_o  // Transaction Layer Channel Interfaces
);

// Parameters
localparam CHDATA_MSGNUM_X2    = 2**((CXL_CHDATA_MSGNUM == 1) ? 1 : $clog2(CXL_CHDATA_MSGNUM*2));
localparam CHDATA_FIFO_DEPTH   = CXL_CHDATA_CREDITS + CHDATA_MSGNUM_X2; // 2*CXL_CHDATA_MSGNUM
localparam CHDATA_FIFO_BYPASS  = 0; // Enable FIFO Bypass if empty
localparam PTR_SIZE            = 3;
localparam CHDATA_REG_DEPTH    = 2**PTR_SIZE;

logic                        cxl_fifo_push_n_s;        // Channel FIFO Push Enable
logic                        cxl_fifo_pop_n_s;         // Channel FIFO Pop Enable
logic                        cxl_fifo_empty_s;         // Channel FIFO Empty flag
logic                        cxl_fifo_full_s;          // Channel FIFO Full flag
logic                        cxl_fifo_af_s;            // Channel FIFO Almost Full flag
logic                        cxl_fifo_ovflw_s;         // Channel FIFO Overflow flag
logic                        cxl_fifo_ovflw_r;         // Channel FIFO Overflow flag
logic                        cxl_fifo_dout_vld_s;      // Channel FIFO Data Out Valid
logic [CXL_CHDATA_WIDTH-1:0] cxl_fifo_dout_s;          // Channel FIFO Data Out
logic                        cxl_fifo_bypass_s;        // Channel FIFO Bypass Enabel
logic                        cxl_ram_we_n;             // Channel FIFO RAM Write Enable
logic                        cxl_ram_re_r;             // Channel FIFO RAM Data Output valid

logic [CHDATA_REG_DEPTH-1:0][CXL_CHDATA_WIDTH-1:0]   cxl_chdata_r, cxl_chdata_nxt;   // Channel Data FIFO offload register
logic [CXL_CHDATA_OUTNUM-1:0][CXL_CHDATA_WIDTH-1:0]  cxl_chdata_output_s ;           // Channel Data Interface Output
logic [CXL_CHDATA_OUTNUM-1:0][CXL_CHDATA_WIDTH-1:0]  cxl_chdata_output_r;            // Pipelined version of offload register, it is used to keep the Channel Data Buffer
                                                                                     // output stable over entire core clock period (x2 CXL Clock periods).
logic                                                cxl_chdata_full_s;              // Channel Data Register Full Flag
logic                                                cxl_chdata_empty_s;             // Channel Data Register Empty Flag
logic                                                cxl_chdata_empty_r;             // Channel Data Register Empty Flag Register

logic [CXL_CHDATA_OUTNUM-1:0][CXL_CHDATA_WIDTH-1:0]  cxl_chdata_s;
logic [CXL_CHDATA_PATH-1:0]                          cxl_chdata_halt_s;
logic [CXL_CHDATA_PATH-1:0]                          cxl_chdata_vld_s, cxl_chdata_vld_r;
// -------------------------------------------------------------------------------------
// Channel Buffer Output
// -------------------------------------------------------------------------------------
assign cxl_chdata_o       = cxl_chdata_output_s;
assign cxl_chdata_vld_o   = cxl_chdata_vld_s;
assign cxl_chdata_af_o    = cxl_fifo_af_s;
assign cxl_chdata_empty_o = cxl_chdata_empty_r;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Channel FIFO Overflow Synchronizer to core_clk domain
// -------------------------------------------------------------------------------------
assign cxl_chdata_halt_s  = cxl_chdata_halt_i ;
assign cxl_chdata_ovflw_o = cxl_fifo_ovflw_r;
// -------------------------------------------------------------------------------------


assign cxl_fifo_bypass_s   = CHDATA_FIFO_BYPASS & (cxl_fifo_empty_s & ~cxl_ram_re_r & ~cxl_chdata_full_s);
assign cxl_fifo_push_n_s   = cxl_fifo_bypass_s ? 1'b1 : !cxl_chdata_vld_i;
assign cxl_fifo_pop_n_s    = cxl_fifo_empty_s | cxl_chdata_full_s;
assign cxl_fifo_dout_vld_s = cxl_fifo_bypass_s ? cxl_chdata_vld_i : cxl_ram_re_r;
assign cxl_fifo_dout_s     = cxl_fifo_bypass_s ? cxl_chdata_i : cxl_ram_rdata;
assign cxl_fifo_ovflw_s    = cxl_fifo_full_s & ~cxl_fifo_push_n_s & cxl_fifo_pop_n_s;

assign cxl_ram_wdata = cxl_chdata_i;
assign cxl_ram_we    = !cxl_ram_we_n;
assign cxl_ram_re    = !cxl_fifo_pop_n_s;

assign cxl_ram_re_r = cxl_ram_re;

always_ff @(posedge cxl_clk or negedge cxl_rst_n) begin
    if (!cxl_rst_n) begin
        cxl_fifo_ovflw_r  <= #TP 1'b0;
    end
    else begin
        cxl_fifo_ovflw_r  <= #TP cxl_fifo_ovflw_s;
    end
end


// -------------------------------------------------------------------------------------
// Instantiate RAM-based Synchronous FIFO controller
// -------------------------------------------------------------------------------------
localparam logic [CXL_CHRAM_ADDRW-1:0] PUSH_AE_LVL  = 1;
localparam logic [CXL_CHRAM_ADDRW-1:0] PUSH_AF_LVL  = CXL_CHDATA_CREDITS;
localparam logic                       ERR_MODE     = 0;
localparam logic                       TMR_EN       = 0;

DWC_pcie_ctl_bcmmod06_atv
 #(
    .DEPTH         ( CHDATA_FIFO_DEPTH     ),
    .ERR_MODE      ( ERR_MODE              ), 
    .ADDR_WIDTH    ( CXL_CHRAM_ADDRW       ),
    .TMR           ( TMR_EN                )
) u_fctl_sync (
    .clk           ( cxl_clk               ),
    .rst_n         ( cxl_rst_n             ),
    .init_n        ( 1'b1                  ),
    .push_req_n    ( cxl_fifo_push_n_s     ),
    .pop_req_n     ( cxl_fifo_pop_n_s      ),
    .diag_n        ( 1'b1                  ),
    .ae_level      ( PUSH_AE_LVL           ),
    .af_thresh     ( PUSH_AF_LVL           ),
    .we_n          ( cxl_ram_we_n          ),
    .empty         ( cxl_fifo_empty_s      ),
    .almost_empty  (                       ),
    .half_full     (                       ),
    .almost_full   ( cxl_fifo_af_s         ),
    .full          ( cxl_fifo_full_s       ),
    .error         (                       ),
    .wr_addr       ( cxl_ram_waddr         ),
    .rd_addr       ( cxl_ram_raddr         ),
    .wrd_count     (                       ),
    .nxt_empty_n   (                       ),
    .nxt_full      (                       ),
    .nxt_error     (                       )
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Channel Buffer Offload Register
//
// Offloads messages from the Buffer FIFO into this register.
//
// -------------------------------------------------------------------------------------
logic [PTR_SIZE:0] cxl_chdata_wr_ptr_r, cxl_chdata_wr_ptr_nxt;
logic [PTR_SIZE:0] cxl_chdata_wr_ptr_s; // Write Pointer + 1
logic [PTR_SIZE:0] cxl_chdata_rd_ptr_r, cxl_chdata_rd_ptr_nxt;
logic [PTR_SIZE:0] cxl_chdata_rd_ptr_plus1_s; //cxl_chdata_rd_ptr_r + 1
logic [CXL_CHDATA_PATH-1:0] cxl_chdata_halt_r;             // Channel Data Halt input register

// Channel Data Register Full Flag
assign cxl_chdata_full_s =  (cxl_chdata_wr_ptr_r[PTR_SIZE] ^ cxl_chdata_rd_ptr_r[PTR_SIZE]) && (cxl_chdata_wr_ptr_r[PTR_SIZE-1:0] == cxl_chdata_rd_ptr_r[PTR_SIZE-1:0])
;

// Channel Data Register Empty Flag
assign cxl_chdata_empty_s = (cxl_chdata_wr_ptr_r == cxl_chdata_rd_ptr_r) & cxl_fifo_empty_s;

// Write Pointer to Channel Data Register in cxl_clk domain
assign cxl_chdata_wr_ptr_s = cxl_chdata_wr_ptr_r + 1;

always_comb begin
    if (cxl_fifo_dout_vld_s) cxl_chdata_wr_ptr_nxt = cxl_chdata_wr_ptr_s;
    else cxl_chdata_wr_ptr_nxt = cxl_chdata_wr_ptr_r;
end

/* Halt behavior in 1024 data path
+-----------+-----------+--------------+
| halt_i[1] | halt_i[0] | increment by |
+-----------+-----------+--------------+
| 0         | X         | 2            |
+-----------+-----------+--------------+
| 1         | 0         | 1            |
+-----------+-----------+--------------+
| 1         | 1         | 0            |
+-----------+-----------+--------------+
*/

// Read Pointer to Channel Data Register in core_clk domain
//Increment the counter based on the number of halts coming from LL

always_comb begin 
  cxl_chdata_rd_ptr_nxt = cxl_chdata_rd_ptr_r +  ( ((cxl_chdata_vld_o[0] & ~cxl_chdata_halt_s[0]) ? 1 : 0));
end

// Channel Data Register
always_comb begin

    cxl_chdata_nxt = cxl_chdata_r;
    // If FIFO output is valid then write the message into the Channel Data Register
    if (cxl_fifo_dout_vld_s) cxl_chdata_nxt[cxl_chdata_wr_ptr_r[PTR_SIZE-1:0]] = cxl_fifo_dout_s;
end

// If the buffer output regsiter (CX_CXL_TX_TL_REG_AFTER_MUX) is:
// - defined     ==> Use cxl_chdata_rd_ptr_r to indicate number of read entries
// - not defined ==> Use cxl_chdata_rd_ptr_nxt to indicate number of read entries
// In the second case, pos_core_clk is used to align cxl_chdata_vld_s with cxl_chdata_output_s
always_comb begin
    cxl_chdata_vld_s[0] = (cxl_chdata_rd_ptr_r != cxl_chdata_wr_ptr_r);
end 

// Channel Data Buffer Output
logic [PTR_SIZE-1:0] indx1;

always_comb begin
    for (int i = 0; i < CXL_CHDATA_OUTNUM; i++) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The design intent is to overflow the counter.
        indx1 = cxl_chdata_rd_ptr_r[PTR_SIZE-1:0] + i;
// spyglass enable_block W164a
        cxl_chdata_output_s[i] = pos_core_clk ? cxl_chdata_r[indx1] : cxl_chdata_output_r[i];
    end
end

always_ff @(posedge cxl_clk or negedge cxl_rst_n) begin
    if (!cxl_rst_n) begin
    for (int i = 0; i < CHDATA_REG_DEPTH; i++) begin
        cxl_chdata_r[i]        <= #TP (CXL_CHDATA_WIDTH > 576) ? {{72{8'h0c}}, 576'b0}:{{64{8'h0c}}, 512'b0};
    end
      cxl_chdata_wr_ptr_r <= #TP '0;
      cxl_chdata_empty_r  <= #TP 1'b0;
    end
    else begin
        cxl_chdata_r        <= #TP cxl_chdata_nxt;
        cxl_chdata_wr_ptr_r <= #TP cxl_chdata_wr_ptr_nxt;
        cxl_chdata_empty_r  <= #TP cxl_chdata_empty_s;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_chdata_rd_ptr_r      <= #TP '0;
        cxl_chdata_halt_r        <= #TP '0;
        cxl_chdata_vld_r         <= #TP '0;
    for (int i = 0; i < CXL_CHDATA_OUTNUM; i++) begin
        cxl_chdata_output_r[i]        <= #TP (CXL_CHDATA_WIDTH > 576) ? {{72{8'h0c}}, 576'b0}:{{64{8'h0c}}, 512'b0};
    end
    end
    else begin
        cxl_chdata_rd_ptr_r <= #TP cxl_chdata_rd_ptr_nxt;
        cxl_chdata_halt_r   <= #TP cxl_chdata_halt_s;
        cxl_chdata_output_r <= #TP cxl_chdata_output_s;
        cxl_chdata_vld_r    <= #TP cxl_chdata_vld_s;
    end
end
// -------------------------------------------------------------------------------------

endmodule : DWC_cxl_mem_cache_tx_tl_chdata_buff
