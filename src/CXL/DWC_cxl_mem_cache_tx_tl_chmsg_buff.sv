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
// ---   $DateTime: 2024/01/12 11:11:14 $
// ---   $Revision: #13 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_tx_tl_chmsg_buff.sv#13 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Interface Layer Message Channel Buffer
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_cxl_mem_cache_tx_tl_chmsg_buff #(
    parameter TP = `TP,
    parameter CXL_CHMSG_CREDITS = 1,
    parameter CXL_CHMSG_NUM   = 4,
    parameter CXL_CHMSG_WIDTH = 79,
    parameter CXL_CHANNEL_NUM =   4,
    parameter CXL_CHMSG_ID_W  =   (CXL_CHANNEL_NUM == 1) ? 1 : $clog2(CXL_CHANNEL_NUM)
) (
    // Clock and Reset
    input                                            cxl_clk,               // CXL clock
    input                                            cxl_rst_n,             // CXL active low asynchronous reset
    input                                            core_clk,              // Core clock
    input                                            core_rst_n,            // Core active low asynchronous reset
    input                                            pos_core_clk,          // Core clock positive edge at cxl_clk domain

    input                                            cxl_chmsg_crd_rst_i,   // Message Channel Credit Reset signal
    input                                            cxl_chmsg_en_i,        // Channel Interface Enable
    input  [CXL_CHMSG_WIDTH-1:0]                     cxl_chmsg_i,           // Channel Interface Input
    input  [CXL_CHMSG_NUM-1:0]                       cxl_chmsg_halt_i,      // Transaction Layer Channel Halts
    input                                            cxl_chdata_af_i,

    output                                           cxl_chmsg_pop_valid,   // A valid message is being written to the offloading queue
    output [CXL_CHMSG_ID_W-1 : 0]                    cxl_chmsg_chid,        // Indication to fifo control of the static channel ID the message written to offloading queue has  
    output                                           cxl_chmsg_ovflw_o,     // Channel Message FIFO Overflow
    output                                           cxl_chmsg_empty_o,     // Channel Data FIFO Empty
    output [CXL_CHMSG_NUM-1:0][CXL_CHMSG_WIDTH-1:0]  cxl_chmsg_o,           // Transaction Layer Channel Interfaces
    output                                           cxl_chmsg_crd_o        // Channel Interface Credit Grant Signal
);

// Parameters
localparam CXL_CHMSG_VLD      = 0;
localparam PTR_SIZE           = (CXL_CHMSG_NUM == 1) ? 1 : $clog2(CXL_CHMSG_NUM*2);
localparam CXL_CHMSG_NUM_X2   = 2**PTR_SIZE;
localparam CXL_CHMSG_BYPASS   = 0; // Enable FIFO Bypass if empty

// Declarations
logic [CXL_CHMSG_NUM_X2-1:0][CXL_CHMSG_WIDTH-1:0] cxl_chmsg_r, cxl_chmsg_nxt;   // Channel message FIFO offload register
logic [   CXL_CHMSG_NUM-1:0][CXL_CHMSG_WIDTH-1:0] cxl_chmsg_output_s;           // Channel Message Interface Output
logic [   CXL_CHMSG_NUM-1:0][CXL_CHMSG_WIDTH-1:0] cxl_chmsg_output_r;           // Pipelined version of offload register, it is used to keep the Channel Message Buffer
                                                                                // output stable over entire core clock period (x2 CXL Clock periods).
logic                                             cxl_chmsg_ovflw_r;            // Channel Buffer Overflow
logic                                             cxl_chmsg_full_s;             // Channel Message Register Full Flag
logic                                             cxl_chmsg_empty_s;            // Channel Message Register Empty Flag
logic                                             cxl_chmsg_empty_r;            // Channel Message Register Empty Flag Register
logic [CXL_CHMSG_NUM-1:0][CXL_CHMSG_WIDTH-1:0]    cxl_chmsg_s;
// -------------------------------------------------------------------------------------
// Channel Buffer Output
// -------------------------------------------------------------------------------------
assign cxl_chmsg_empty_o = cxl_chmsg_empty_r;
assign cxl_chmsg_o = cxl_chmsg_output_s;
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Channel FIFO Overflow Synchronizer to core_clk domain
// -------------------------------------------------------------------------------------
assign cxl_chmsg_ovflw_o = cxl_chmsg_ovflw_r;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Channel Buffer FIFO
// -------------------------------------------------------------------------------------
logic                        cxl_buff_we_s;             // Channel Buffer Write Enable
logic                        cxl_buff_re_s;             // Channel Buffer Read Enable
logic                        cxl_buff_empty_s;          // Channel Buffer Empty
logic                        cxl_buff_full_s;           // Channel Buffer Full
logic                        cxl_buff_dout_vld_s;       // Channel Buffer Data Out Valid
logic [CXL_CHMSG_WIDTH-1:0]  cxl_buff_dout_s;           // Channel Buffer Data Out
logic [CXL_CHMSG_WIDTH-1:0]  cxl_buff_data_s;           // Channel Buffer Data Out
logic                        cxl_buff_bypass_s;         // Channel Buffer Bypass Enabel
logic                        cxl_chmsg_ovflw_s;         // Channel Buffer Overflow

assign cxl_buff_bypass_s   = CXL_CHMSG_BYPASS & (cxl_buff_empty_s & ~cxl_chmsg_full_s);
assign cxl_buff_re_s       = ~cxl_buff_empty_s & ~cxl_chmsg_full_s;
assign cxl_buff_we_s       = cxl_buff_bypass_s ? 1'b0 : cxl_chmsg_i[CXL_CHMSG_VLD];
assign cxl_buff_dout_vld_s = cxl_buff_bypass_s ? cxl_chmsg_i[CXL_CHMSG_VLD] : cxl_buff_re_s;
assign cxl_buff_dout_s     = cxl_buff_bypass_s ? cxl_chmsg_i : cxl_buff_data_s;
assign cxl_chmsg_ovflw_s   = cxl_buff_full_s & cxl_buff_we_s & ~cxl_buff_re_s;

// -------------------------------------------------------------------------------------
// Instantiate FIFO controller
// -------------------------------------------------------------------------------------
localparam FIFO_WIDTH = CXL_CHMSG_WIDTH;
localparam FIFO_DEPTH = CXL_CHMSG_CREDITS;
localparam FIFO_ADDRW = $clog2(CXL_CHMSG_CREDITS);

DWC_pcie_ctl_bcm65_td
 #(
    .WIDTH            ( FIFO_WIDTH         ),
    .DEPTH            ( FIFO_DEPTH         ),
    .ADDR_WIDTH       ( FIFO_ADDRW         ),
    .AE_LEVEL         ( 1                  ),
    .AF_LEVEL         ( 1                  ),
    .ERR_MODE         ( 0                  ),
    .RST_MODE         ( 0                  ),
    .REG_DELAY_TIME   ( 1                  ),
    .REG_DELAY_DENOM  ( 10                 )
) u_fctl (
    .clk              ( cxl_clk            ),
    .rst_n            ( cxl_rst_n          ),
    .init_n           ( 1'b1               ),
    .push_req_n       ( ~cxl_buff_we_s     ),
    .pop_req_n        ( ~cxl_buff_re_s     ),
    .diag_n           ( 1'b1               ),
    .data_in          ( cxl_chmsg_i        ),
    .empty            ( cxl_buff_empty_s   ),
    .almost_empty     (                    ),
    .half_full        (                    ),
    .almost_full      (                    ),
    .full             ( cxl_buff_full_s    ),
    .error            (                    ),
    .data_out         ( cxl_buff_data_s    )
);
// -------------------------------------------------------------------------------------

delay_n
 #(
    .N     ( 1                ),
    .WD    ( CXL_CHMSG_ID_W+1 )
) u_delay_chid (
    .clk   ( cxl_clk                                                                     ),
    .rst_n ( cxl_rst_n                                                                   ),
    .clear ( 1'b0                                                                        ),
    .din   ( {cxl_buff_dout_s[CXL_CHMSG_WIDTH-1 -: CXL_CHMSG_ID_W], cxl_buff_dout_vld_s} ),
    .dout  ( {cxl_chmsg_chid, cxl_chmsg_pop_valid}                                       )
);

// -------------------------------------------------------------------------------------
// Channel Interface Flow Control - Credit Management
// -------------------------------------------------------------------------------------
logic [$clog2(CXL_CHMSG_CREDITS):0] cxl_crd_cntr_r, cxl_crd_cntr_nxt; // Credit Counter Register
logic                               cxl_crd_cntr_inc_s;               // Credit Counter Increment. Asserted every cycle if counter
                                                                      // not reached the maximum available channel credits - CXL_CHMSG_CREDITS.
logic                               cxl_crd_cntr_dec_s;               // Credit Counter Decrement. Asserted every time a new entry is
                                                                      // offloaded from the FIFO.
logic                               cxl_crd_cntr_done_s;              // Credit Counter Done Flag. Asserted when counter is equal to
                                                                      //  the number of channel interface credits - CXL_CHMSG_CREDITS

// Assert Channel Interface Credit Grant when credit counter increment is asserted
delay_n
 #(
    .N     (1)
) u_delay_chmsg_crd (
    .clk   (cxl_clk),
    .rst_n (cxl_rst_n),
    .clear (1'b0),
    .din   (cxl_crd_cntr_inc_s),
    .dout  (cxl_chmsg_crd_o)
);

// Generate Credit Counter Control/Status signals
assign cxl_crd_cntr_inc_s  = cxl_chmsg_en_i & ~cxl_chdata_af_i & (cxl_crd_cntr_done_s ? cxl_crd_cntr_dec_s : 1'b1);
assign cxl_crd_cntr_dec_s  = cxl_buff_dout_vld_s;
assign cxl_crd_cntr_done_s = cxl_crd_cntr_r == CXL_CHMSG_CREDITS;

always_comb begin
    if (cxl_chmsg_crd_rst_i) begin
        cxl_crd_cntr_nxt = '0;
    end
    else if (cxl_crd_cntr_inc_s & ~cxl_crd_cntr_dec_s) begin
        cxl_crd_cntr_nxt = cxl_crd_cntr_r + 1;
    end
    else if (~cxl_crd_cntr_inc_s & cxl_crd_cntr_dec_s) begin
        cxl_crd_cntr_nxt = cxl_crd_cntr_r - 1;
    end
    else begin
        cxl_crd_cntr_nxt = cxl_crd_cntr_r;
    end
end

always_ff @(posedge cxl_clk or negedge cxl_rst_n) begin
    if (!cxl_rst_n) begin
        cxl_crd_cntr_r     <= #TP '0;
    end
    else begin
        cxl_crd_cntr_r     <= #TP cxl_crd_cntr_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Channel Buffer Offload Register
//
// Offloads messages from the Buffer FIFO into this register.
//
// -------------------------------------------------------------------------------------
logic [PTR_SIZE:0] cxl_chmsg_wr_ptr_r, cxl_chmsg_wr_ptr_nxt;
logic [PTR_SIZE:0] cxl_chmsg_rd_ptr_r, cxl_chmsg_rd_ptr_nxt;
logic [PTR_SIZE:0] cxl_chmsg_rd_ptr_p;

logic [CXL_CHMSG_NUM-1:0] cxl_chmsg_vld_r, cxl_chmsg_vld_s;
logic [CXL_CHMSG_NUM-1:0] cxl_chmsg_rd_r, cxl_chmsg_rd_s;

logic [PTR_SIZE-1:0] indx1, indx2;

assign cxl_chmsg_full_s = (cxl_chmsg_wr_ptr_r[PTR_SIZE] ^ cxl_chmsg_rd_ptr_r[PTR_SIZE]) && (cxl_chmsg_wr_ptr_r[PTR_SIZE-1:0] == cxl_chmsg_rd_ptr_r[PTR_SIZE-1:0]);

// Channel Message Register Empty Flag
assign cxl_chmsg_empty_s = (cxl_chmsg_wr_ptr_r == cxl_chmsg_rd_ptr_r) & cxl_buff_empty_s;

// Write Pointer to Channel Message Register in cxl_clk domain
always_comb begin
    if (cxl_buff_dout_vld_s) cxl_chmsg_wr_ptr_nxt = cxl_chmsg_wr_ptr_r + 1;
    else cxl_chmsg_wr_ptr_nxt = cxl_chmsg_wr_ptr_r;
end

// Read Pointer to Channel Message Register in core_clk domain
always_comb begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The design intent is to overflow the counter.
    cxl_chmsg_rd_ptr_nxt = cxl_chmsg_rd_ptr_r + cntZeroBits(cxl_chmsg_rd_s);//$countbits(cxl_chmsg_rd_s, '0);
// spyglass enable_block W164a
end

// Messages which were read from Channel Message Register (must be kept stable for core_clk cycle)
// This signal is used to increment Read Pointer
assign cxl_chmsg_rd_s = cxl_chmsg_halt_i | ~cxl_chmsg_vld_s;

always_comb begin
    for (int i = 0; i < CXL_CHMSG_NUM; i++) begin
        cxl_chmsg_vld_s[i] = cxl_chmsg_o[i][CXL_CHMSG_VLD];
    end
end

// Channel Message Register
always_comb begin
    cxl_chmsg_nxt = cxl_chmsg_r;

    // Clear entries from Channel Message Register which were read out in the last cycle
    for (int i = 0; i < CXL_CHMSG_NUM; i++) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The design intent is to overflow the counter.
        indx1 = cxl_chmsg_rd_ptr_p + i;
// spyglass enable_block W164a
        cxl_chmsg_nxt[indx1] = (pos_core_clk & ~cxl_chmsg_rd_r[i]) ? '0 : cxl_chmsg_r[indx1];
    end

    // If FIFO output is valid then write the message into the Channel Message Register
    if (cxl_buff_dout_vld_s) cxl_chmsg_nxt[cxl_chmsg_wr_ptr_r[PTR_SIZE-1:0]] = cxl_buff_dout_s;
end

// Channel Message Buffer Output
always_comb begin
    for (int i = 0; i < CXL_CHMSG_NUM; i++) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The design intent is to overflow the counter.
        indx2 = cxl_chmsg_rd_ptr_r[PTR_SIZE-1:0] + i;
// spyglass enable_block W164a
        cxl_chmsg_output_s[i] = pos_core_clk ? cxl_chmsg_r[indx2] : cxl_chmsg_output_r[i];
    end
end

always_ff @(posedge cxl_clk or negedge cxl_rst_n) begin
    if (!cxl_rst_n) begin
        cxl_chmsg_r        <= #TP '0;
        cxl_chmsg_ovflw_r  <= #TP 1'b0;
        cxl_chmsg_wr_ptr_r <= #TP '0;
        cxl_chmsg_empty_r  <= #TP 1'b0;
    end
    else begin
        cxl_chmsg_r        <= #TP cxl_chmsg_nxt;
        cxl_chmsg_ovflw_r  <= #TP cxl_chmsg_ovflw_s;
        cxl_chmsg_wr_ptr_r <= #TP cxl_chmsg_wr_ptr_nxt;
        cxl_chmsg_empty_r  <= #TP cxl_chmsg_empty_s;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_chmsg_rd_ptr_r  <= #TP '0;
        cxl_chmsg_rd_ptr_p  <= #TP '0;
        cxl_chmsg_rd_r      <= #TP '0;
        cxl_chmsg_output_r  <= #TP '0;
    end
    else begin
        cxl_chmsg_rd_ptr_r  <= #TP cxl_chmsg_rd_ptr_nxt;
        cxl_chmsg_rd_ptr_p  <= #TP cxl_chmsg_rd_ptr_r;
        cxl_chmsg_rd_r      <= #TP cxl_chmsg_rd_s;
        cxl_chmsg_output_r  <= #TP cxl_chmsg_output_s;
    end
end

function automatic [PTR_SIZE-1:0] cntZeroBits;
    input   [CXL_CHMSG_NUM-1:0] data;
    reg     [PTR_SIZE-1:0]  result;

    integer i;
begin
    result = '0;

    for (i = 0; i < CXL_CHMSG_NUM; i++)
        if (!data[i]) result = result + 1;

    cntZeroBits = result;
end
endfunction
// -------------------------------------------------------------------------------------

endmodule : DWC_cxl_mem_cache_tx_tl_chmsg_buff
