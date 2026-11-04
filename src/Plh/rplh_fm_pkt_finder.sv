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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_fm_pkt_finder.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC layer Packet Finder in Flit Mode
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/pcie_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module rplh_fm_pkt_finder
import pcie_pkg::PFX_TKN;
import pcie_pkg::HDR_TKN;
import DWC_pcie_core_pkg::fm_raw_tkn_t;
import cx_pl_pkg::tlp_state_t;
#(
parameter NW              = `CX_PL_NW,                                // Number of 32-bit dwords handled by the datapath each clock.
parameter DW              = 32*NW,                                    // Width of datapath in bits
parameter DW_PROT_WD      = `CX_RAS_RPL_DATA_PROT_WD,                 // Datapath Protection bits
parameter RAW_PIPE_EN     = `CX_RPLH_FM_PKT_FINDER_RAW_PIPE,          // Raw decoder Pipeline enabled (0 or 1).
parameter TP              = `TP                                       // Clock to Q delay (simulator insurance)
)
(
// ---- inputs ---------------
input                       core_clk,
input                       core_rst_n,
input                       rplh_flit_dv,         // Valid TLP bytes in this cycle
input [DW-1:0]              rplh_flit_data,       // Serialized Flit Data
input [DW_PROT_WD-1:0]      rplh_flit_data_prot,  // Serialized Flit Data Protection
input                       rplh_flit_nullified,  // marks whether this flit contains a nullified TLP
input                       rplh_flit_poisoned,   // marks whether this flit contains a poisoned TLP
// ---- outputs ---------------
output                      rplh_fmpkt_data_dv,   // Packed Data Valid
output [DW-1:0]             rplh_fmpkt_data,      // Packet Data
output [DW_PROT_WD-1:0]     rplh_fmpkt_data_prot, // Packet Data Protection
output [NW-1:0]             rplh_fmpkt_tlp_pfx,   // Indicates DWord location of prefix
output [NW-1:0]             rplh_fmpkt_tlp_soh,   // Indicates DWord location of the 1st Base Header DW
output [NW-1:0]             rplh_fmpkt_tlp_end,   // Indicates DWord location of a packet END
output                      rplh_fmpkt_tlp_nul,   // The last TLP ending was Nullified by the Flit Marker
output                      rplh_fmpkt_tlp_psn,   // The last TLP ending was Poisoned by the Flit Marker
output [NW-1:0]             rplh_fmpkt_tlp_idl    // Indicates an empty DWord
);

//    +--------------+     r              +--------------+          p             o
//   / 0:1 stages   /|    pipe           / 0 stages     /|         pipe          pipe
//  +--------------+ |    +---+         +--------------+ |         +---+         +---+
//  | Raw Dec      | | => |reg|   =>    | TLP Decoders | |   =>    |reg|    =>   |reg|    =>
//  | Pipeline     | +    |   |   r_    |              | +   t_    |   |    p_   |   |    o_
//  | raw signals  |/     |>  | signals | (t_ signals) |/  signals |>  | signals |>  | signals
//  +--------------+      +---+         +--------------+           +---+         +---+

localparam FW   = 64;             // Number of 32-bit dwords contained in a full Flit (rounded up)
localparam FL   = FW/NW;          // Number of cycles the full flit lasts
localparam TL   = (59+NW-1)/NW;   // Number of cycles required to process TLP Bytes in the full flit (rounded up)
localparam TDEC = (NW+ 8-1)/8;    // Number of 256-bit TLP Decoders (rounded up)

localparam LOH  = (NW==4)? 1 : 5; // OverHead in the last cycle of the flit, reduced payload due to CRC, FEC, DLLP (5 DWords)
localparam LNW  = NW-LOH;         // NW in the last cycle of the flit, reduced payload due to CRC, FEC, DLLP (5 DWords) 
localparam LDW  = DW-LOH*32;      // DW in the last cycle of the flit, reduced payload due to CRC, FEC, DLLP (5 DWords) 

localparam bit PARITY_MODE = `CX_RAS_PARITY_MODE; // the parity mode (if odd, we fill zero data with ones, if even we fill zero data with zeros)

// Internal signals
logic [DW-1:0]         i_data      , raw_data      , r_data;
logic                  i_data_dv   , raw_data_dv   , r_data_dv;
logic                  i_data_first, raw_data_first, r_data_first; // First data cycle of a new Flit
logic                  i_data_last , raw_data_last , r_data_last;  // Last data cycle of the current Flit
logic [$clog2(FL)-1:0] i_data_cntr ;                               // Data cycle counter of the current Flit
logic                  i_nullified , raw_nullified , r_nullified;
logic                  i_poisoned  , raw_poisoned  , r_poisoned;
logic [DW_PROT_WD-1:0] i_data_prot , raw_data_prot , r_data_prot;

// Input signals
assign i_data_dv   = rplh_flit_dv && i_data_cntr<TL;
assign i_data      = rplh_flit_data;
assign i_data_prot = rplh_flit_data_prot;

always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        i_data_cntr     <= #TP '0;
    end else if(rplh_flit_dv) begin
        i_data_cntr   <= #TP i_data_cntr + 'd1;
    end
end
assign i_data_first = rplh_flit_dv && i_data_cntr==0;
assign i_data_last  = rplh_flit_dv && i_data_cntr==TL-1'b1;

assign i_nullified = (i_data_first)? rplh_flit_nullified : raw_nullified;
assign i_poisoned  = (i_data_first)? rplh_flit_poisoned  : raw_poisoned;

reg [NW-1:0][$clog2(64)-1:0] i_dwnum; // Dword number (i.e. data dword position within the Flit)
generate
for (genvar nw=0; nw<NW; nw = nw+1) begin : gen_i_dwnum
    assign i_dwnum[nw] = i_data_cntr*NW+nw;
end
endgenerate // gen_i_dwnum

// -------------------------------------------------------------------------------------
// - Raw Decoders 
// -------------------------------------------------------------------------------------
fm_raw_tkn_t [NW-1:0]  raw_tkn;
// Instantiate the 32b raw decoders.
// Raw tokens for the full flit are calculated in a single cycle.
generate
    for (genvar nw=0; nw<NW; nw = nw+1) begin : gen_u_rplh_fm_pkt_finder_32b_raw_dec
        rplh_fm_pkt_finder_32b_raw_dec
         #(.DWNUM(nw), .PIPE_EN(RAW_PIPE_EN)) u_rplh_fm_pkt_finder_32b_raw_dec
        (
            // ---- inputs ---------------
            .core_clk   (core_clk),
            .core_rst_n (core_rst_n),
            .data_dv    (i_data_dv),
            .data       (i_data[32*nw +: 32]),
            .dwnum      (i_dwnum[nw]),
            // ---- outputs ---------------
            .raw        (raw_tkn[nw])
        );
    end
endgenerate // gen_u_rplh_fm_pkt_finder_32b_raw_dec


// Delay the valid indication from Raw decoders when the optional pipeline is enabled
delay_n

#(RAW_PIPE_EN, 1) u_delay_raw_data_dv (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (i_data_dv),
    .dout  (raw_data_dv)
);

// The following signals needs to be aligned with the Raw Pipeline registers
localparam RAW_PTDATA_WIDTH = 1          + // i_nullified
                              1          + // i_poisoned
                              1          + // i_data_first
                              1          + // i_data_last
                              DW_PROT_WD + // i_data_prot (0 when !CX_RASDP_EN)
                              DW         ; // i_data

delay_n_w_enable

#(RAW_PIPE_EN, RAW_PTDATA_WIDTH) u_delay_w_enable_raw_passthrough_data (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .en    (i_data_dv),
    .din   ({i_nullified,
             i_poisoned,
             i_data_first,
             i_data_last,
 i_data_prot,
             i_data}),
    .dout  ({raw_nullified,
             raw_poisoned,
             raw_data_first,
             raw_data_last,
 raw_data_prot,
             raw_data})
);

// Register raw tokens and data.
// TLP Decoders process partial flits per cycle (1/2 in 1024-b, 1/4 in 512-b, 1/8 in 256-b or 1/15 in 128-b).
fm_raw_tkn_t [NW-1:0] r_raw;
always @(posedge core_clk or negedge core_rst_n) begin : raw_seq_PROC
    if( !core_rst_n ) begin
        r_data_dv     <= #TP '0;
        r_data        <= #TP '0;
        r_data_first  <= #TP '0;
        r_data_last   <= #TP '0;
        r_nullified   <= #TP '0;
        r_poisoned    <= #TP '0;
        r_raw         <= #TP fm_raw_tkn_t'('0);
        r_data_prot   <= #TP {DW_PROT_WD{PARITY_MODE}};
    end else begin
        if(raw_data_dv) begin
            r_data_dv     <= #TP 1'b1;
            r_data        <= #TP raw_data;
            r_data_first  <= #TP raw_data_first;
            r_data_last   <= #TP raw_data_last;
            r_nullified   <= #TP raw_nullified;
            r_poisoned    <= #TP raw_poisoned;
            r_raw         <= #TP raw_tkn;
            r_data_prot <= #TP raw_data_prot;
        end else begin
        r_data_dv     <= #TP '0;
        r_data        <= #TP '0;
        r_data_first  <= #TP '0;
        r_data_last   <= #TP '0;
        r_nullified   <= #TP '0;
        r_poisoned    <= #TP '0;
        r_raw         <= #TP fm_raw_tkn_t'('0);
        r_data_prot   <= #TP {DW_PROT_WD{PARITY_MODE}};
        end
    end
end

// -------------------------------------------------------------------------------------
// - TLP Decoders 
// -------------------------------------------------------------------------------------
// State information for the chain of 256b decoders
tlp_state_t [TDEC-1:0] prev_tlp_state;
tlp_state_t [TDEC-1:0] next_tlp_state;

// Horizontal outputs
wire  [NW-1:0] tlp_pfx;
wire  [NW-1:0] tlp_soh;
wire  [NW-1:0] tlp_end;
wire  [NW-1:0] tlp_idl;

// Instantiate TLP token decoders
wire next_tlp_state_valid;
genvar nqw;
generate for (nqw=0; nqw<TDEC; nqw = nqw+1) begin : gen_rplh_fm_pkt_finder_256b_dec
    rplh_fm_pkt_finder_256b_dec
     u_rplh_fm_pkt_finder_256b_dec
    (
        // ---- inputs ---------------
        .prev_tlp_state         (prev_tlp_state  [nqw]),
        .raw                    (r_raw         [8*nqw +: 8]),
        // ---- outputs ---------------
        .next_tlp_state         (next_tlp_state  [nqw]),
        .tlp_pfx                (tlp_pfx       [8*nqw +: 8]),
        .tlp_soh                (tlp_soh       [8*nqw +: 8]),
        .tlp_end                (tlp_end       [8*nqw +: 8]),
        .tlp_idl                (tlp_idl       [8*nqw +: 8])
    );
end
endgenerate // gen_rplh_fm_pkt_finder_256b_dec
assign next_tlp_state_valid = 1'b1; // always

// Connect the next state outputs to the state inputs of next 256b decoder in the chain
generate for (nqw=1; nqw<TDEC; nqw = nqw+1) begin : gen_state
    assign prev_tlp_state[nqw] = next_tlp_state[nqw-1];
end
endgenerate

// ... and the state register for decoder 0
always @(posedge core_clk or negedge core_rst_n) begin : state_seq_PROC
    if( !core_rst_n ) begin
        prev_tlp_state[0] <= #TP tlp_state_t'(0);
    end else begin
        // state register loaded from the next_state from the last 256b decoder
        if(r_data_dv & next_tlp_state_valid) begin
            prev_tlp_state[0].pending <= #TP next_tlp_state[TDEC-1].pending;
            prev_tlp_state[0].eot_flt <= #TP (r_data_last)? next_tlp_state[TDEC-1].eot_flt - 1'b1 : 
                                                            next_tlp_state[TDEC-1].eot_flt;
            prev_tlp_state[0].eot_dec <= #TP next_tlp_state[TDEC-1].eot_dec;
            prev_tlp_state[0].eot_pos <= #TP next_tlp_state[TDEC-1].eot_pos;
        end
    end
end

// -------------------------------------------------------------------------------------
// - Pipeline Stage for Nullified and Poisoned TLPs
// -------------------------------------------------------------------------------------
reg             p_last;
reg             p_data_dv;
reg [DW-1:0]    p_data;
reg [DW_PROT_WD-1:0] p_data_prot;
reg [NW-1:0]    p_tlp_pfx;
reg [NW-1:0]    p_tlp_soh;
reg [NW-1:0]    p_tlp_end;
reg [NW-1:0]    p_tlp_idl;
reg             p_tlp_raw_nul;
reg             p_tlp_raw_psn;

wire t_empty, tlp_empty; // no TLPs in this cycle (also, nothing in progress).
assign tlp_empty = (r_data_last)? &tlp_idl[LNW-1:0] : &tlp_idl;

wire tlp_raw_last; // At least 1 TLP ending and no further TLPs starting in this cycle
wire tlp_raw_nul;  // This cycle contains a TLP which might be nullified (if no further TLPs until end of Flit)
wire tlp_raw_psn;  // This cycle contains a TLP which might be poisoned  (if no further TLPs until end of Flit)
assign tlp_raw_last = (r_data_last)? tlp_end[LNW-1] | (|tlp_end & tlp_idl[LNW-1]): 
                                     tlp_end[ NW-1] | (|tlp_end & tlp_idl[ NW-1]);
assign tlp_raw_nul = r_nullified & tlp_raw_last;
assign tlp_raw_psn = r_poisoned  & tlp_raw_last;

wire p_enable; // Command for p pipe to lactch
wire o_enable; // Command for o pipe to lactch

// Figure out when to enable p pipeline: some TLP data to be latched.
// Theoretically unless all tlp_idl outputs from TLP decoder are enabled, 
// but that would mean additional logic on the critical path.
// Instead, try to predict when TLPs need to be latched:
//   * when there is already a TLP in progress
//   * when there is no TLP in progress and a raw start (Prefix or Header) arrived.
// Note this predictor would not work on 128b cores, because of the state valid every 2nd cycle.
reg r_raw_start;
always_comb begin
    r_raw_start = 1'b0;
    for (int i=0; i<NW; i=i+4) begin
        if (!r_data_last || i<=LNW) begin
            r_raw_start = r_raw_start | r_raw[i].tkn inside {PFX_TKN, HDR_TKN};
        end
    end
end
wire tlp_predicted; // Partial, one or more TLPs processed on this cycle.
assign tlp_predicted = prev_tlp_state[0].pending | r_raw_start; 
assign t_empty = !tlp_predicted;
assign p_enable = r_data_dv & !t_empty;

always @(posedge core_clk or negedge core_rst_n) begin : pipe_nul_psn_PROC
    if( !core_rst_n ) begin
        p_last       <= #TP '0;
        p_data_dv    <= #TP '0;
        p_data       <= #TP '0;
        p_tlp_pfx    <= #TP '0;
        p_tlp_soh    <= #TP '0;
        p_tlp_end    <= #TP '0;
        p_tlp_idl    <= #TP '0;
        p_tlp_raw_nul<= #TP '0;
        p_tlp_raw_psn<= #TP '0;
        p_data_prot  <= #TP {DW_PROT_WD{PARITY_MODE}};
    end else if (p_enable) begin
        p_last       <= #TP r_data_last;
        p_data_dv    <= #TP 1'b1;
        p_data       <= #TP (r_data_last)? {{LOH{32'd0}}, r_data [LDW-1:0]} : r_data;
        p_tlp_pfx    <= #TP (r_data_last)? {{LOH{ 1'b0}}, tlp_pfx[LNW-1:0]} : tlp_pfx;
        p_tlp_soh    <= #TP (r_data_last)? {{LOH{ 1'b0}}, tlp_soh[LNW-1:0]} : tlp_soh;
        p_tlp_end    <= #TP (r_data_last)? {{LOH{ 1'b0}}, tlp_end[LNW-1:0]} : tlp_end;
        p_tlp_idl    <= #TP (r_data_last)? {{LOH{ 1'b1}}, tlp_idl[LNW-1:0]} : tlp_idl;
        p_tlp_raw_nul<= #TP tlp_raw_nul;
        p_tlp_raw_psn<= #TP tlp_raw_psn;
        p_data_prot  <= #TP (r_data_last)? {{LOH*`CX_RAS_DWORD_PROT_WD{PARITY_MODE}}, r_data_prot[LNW*`CX_RAS_DWORD_PROT_WD-1:0]} : r_data_prot;
    end else if (o_enable) begin
        // Flush - no new data to latch and o_ pipe is reading current values (otherwise hold)
        p_last       <= #TP '0;
        p_data_dv    <= #TP '0;
        p_data       <= #TP '0;
        p_tlp_pfx    <= #TP '0;
        p_tlp_soh    <= #TP '0;
        p_tlp_end    <= #TP '0;
        p_tlp_idl    <= #TP '0;
        p_tlp_raw_nul<= #TP '0;
        p_tlp_raw_psn<= #TP '0;
        p_data_prot  <= #TP {DW_PROT_WD{PARITY_MODE}};
    end
end

// -------------------------------------------------------------------------------------
// - Output Stage
// -------------------------------------------------------------------------------------
reg             o_data_dv;
reg [DW-1:0]    o_data;
reg [DW_PROT_WD-1:0] o_data_prot;
reg [NW-1:0]    o_tlp_pfx;
reg [NW-1:0]    o_tlp_soh;
reg [NW-1:0]    o_tlp_end;
reg [NW-1:0]    o_tlp_idl;
reg             o_tlp_nul;
reg             o_tlp_psn;

assign o_enable = p_data_dv & ((~p_tlp_raw_nul & ~p_tlp_raw_psn) | // No Nullified nor Poisoned: no need to wait
                               (p_last | p_enable | r_data_last)); // Information needed to qualify nul/poisn is available

// Latch processed flit and offload data according to the actual datapath width NW
always @(posedge core_clk or negedge core_rst_n) begin : out_PROC
    if( !core_rst_n ) begin
        o_data_dv    <= #TP '0;
        o_data       <= #TP '0;
        o_tlp_pfx    <= #TP '0;
        o_tlp_soh    <= #TP '0;
        o_tlp_end    <= #TP '0;
        o_tlp_idl    <= #TP '0;
        o_tlp_nul    <= #TP '0;
        o_tlp_psn    <= #TP '0;
        o_data_prot  <= #TP {DW_PROT_WD{PARITY_MODE}};
    end else if (o_enable) begin
        o_data_dv    <= #TP 1'b1;
        o_data       <= #TP p_data   ;
        o_tlp_pfx    <= #TP p_tlp_pfx;
        o_tlp_soh    <= #TP p_tlp_soh;
        o_tlp_end    <= #TP p_tlp_end;
        o_tlp_idl    <= #TP p_tlp_idl;
        o_tlp_nul    <= #TP p_tlp_raw_nul & (p_last | (r_data_last & t_empty));
        o_tlp_psn    <= #TP p_tlp_raw_psn & (p_last | (r_data_last & t_empty));
        o_data_prot  <= #TP p_data_prot;
    end else begin
        o_data_dv    <= #TP '0;
        o_data       <= #TP '0;
        o_tlp_pfx    <= #TP '0;
        o_tlp_soh    <= #TP '0;
        o_tlp_end    <= #TP '0;
        o_tlp_idl    <= #TP '0;
        o_tlp_nul    <= #TP '0;
        o_tlp_psn    <= #TP '0;
        o_data_prot  <= #TP {DW_PROT_WD{PARITY_MODE}};
    end
end

assign rplh_fmpkt_data_dv   = o_data_dv;
assign rplh_fmpkt_data      = o_data   ;
assign rplh_fmpkt_tlp_pfx   = o_tlp_pfx;
assign rplh_fmpkt_tlp_soh   = o_tlp_soh;
assign rplh_fmpkt_tlp_end   = o_tlp_end;
assign rplh_fmpkt_tlp_idl   = o_tlp_idl;
assign rplh_fmpkt_tlp_nul   = o_tlp_nul;
assign rplh_fmpkt_tlp_psn   = o_tlp_psn;
assign rplh_fmpkt_data_prot = o_data_prot;

endmodule // rplh_fm_pkt_finder

