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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_token_finder3.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Packet Layer Token Finder for Gen3
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rplh_token_finder3(
// ---- inputs ---------------
    core_clk,
    core_rst_n,
    smlh_link_mode,
    search_for_tokens,
    accept_eds_cycle,
    expect_eds,
    rxdata3_dv,
    rxdata3,

// ---- outputs ---------------
    rplh_rdlh_dllp_start,
    rplh_rdlh_tlp_start,
    rplh_rdlh_pkt_end,
    rplh_rdlh_pkt_edb,
    rplh_rdlh_pkt_data,
    rplh_rdlh_pkt_dv,
    rplh_rdlh_pkt_err,
    rplh_rdlh_pkt_err_ptr,
    rplh_rcvd_idle
);

parameter   INST    = 0;                        // The uniquifying parameter for each port logic instance.
parameter   NL      = `CX_NL;                   // Max number of lanes supported
parameter   NB      = `CX_NB;                   // Number of symbols (bytes) per clock cycle
parameter   AW      = `CX_ANB_WD;               // Width of the active number of bytes
parameter   NW_ORG  = `CX_PL_NW;                // Number of 32-bit dwords handled by the datapath each clock.
parameter   NW      = (NW_ORG>16)? 16 : NW_ORG; // Number of 32-bit dwords handled by this module (max 16 dwords).
parameter   NW_R    = NW;                       // Number of 32-bit dwords handled by the Reduced datapath (used in MODE4) each clock.
parameter   TP      = `TP;                      // Clock to Q delay (simulator insurance)

localparam DW_ORG   = (32*NW_ORG);              // Width of datapath in bits.
localparam DW       = (32*NW);                  // Width of datapath in bits handled by this module (max 512 bits).
localparam NW_MAX   = 16;                       // Number of 32-bit dwords handled by a max-width datapath each clock.
localparam DW_MAX   = (32*NW_MAX);              // Maximum Width of datapath in bits.
localparam NW_INT   = (NW>NW_R)? NW_R : NW;     // Number of 32-bit dwords really handled by the datapath (dependeing on full and reduced parameters) each clock.

localparam ALIGN_MAX = (NB >= 4) ? (NB/2) : 1;  // Number of Token Processors to enable Alignment Logic
localparam ALIGN_MODE_X1 = 1;                   // 1: support alignment on byte boundaries (i.e. min supported link mode is x1)
localparam ALIGN_MODE_X2 = 2;                   // 2: support alignment on word boundaries (i.e. min supported link mode is x2)
localparam ALIGN_MODE_X4 = 0;                   // 0: support alignment on dword boundaries (i.e. min supported link mode is x4)
localparam ALIGN_MODE = ALIGN_MODE_X1;          // include logic for detecting token alignment on a byte or word boundary
localparam DW_ERR = 4;                          // [3:1] internal framing error pointer [0] framing error flag

input                   core_clk;               // Core Clock
input                   core_rst_n;             // Core Reset
input   [5:0]           smlh_link_mode;         // Current Link Mode
input                   search_for_tokens;      // Search for Tokens. Indication from Deskew Block to search for tokens in current rxdata3
input                   accept_eds_cycle;       // Pulse active on last cycle of a block that indicates an EDS token may be accepted.
input                   expect_eds;             // Signal from deskew block to inform token_finder that EDS is expected
input                   rxdata3_dv;             // Incoming Data is Valid, suffix "3" is to remind that this data valid is squelched to 1 when search_for_tokens = 0
input   [DW_ORG-1:0]    rxdata3;                // Incoming Data, suffix "3" is to remind that this data is squelched to all 0's when search_for_tokens = 0

output  [NW_ORG-1:0]    rplh_rdlh_dllp_start;   // Indicates DWord location of SDP
output  [NW_ORG-1:0]    rplh_rdlh_tlp_start;    // Indicates DWord location of STP
output  [NW_ORG-1:0]    rplh_rdlh_pkt_end;      // Indicates Dword location of END or EBD
output  [NW_ORG-1:0]    rplh_rdlh_pkt_edb;      // Indicates DWord location of EDB
output  [DW_ORG-1:0]    rplh_rdlh_pkt_data;     // Packet Data
output                  rplh_rdlh_pkt_dv;       // Packet Data Valid
output  [NW_ORG-1:0]    rplh_rdlh_pkt_err;      // Packet Error
output  [NW_ORG*5-1:0]  rplh_rdlh_pkt_err_ptr;  // Packet Error Pointer
output  [1:0]           rplh_rcvd_idle;         // Number of Continuous Received IDL Symbols. Encoded as {Num IDLs != 0, Num IDLs >= 8}

// Internal Signals
reg     [DW-1:0]        int_rxdata3[2:0];
reg                     int_rxdata3_dv [2:0];
reg     [2:0]           int_search_for_tokens;
reg     [2:0]           int_accept_eds_cycle;
reg     [1:0]           eds_rcvd;
reg [1:0] eds_exp;
wire eds_err;
reg     [31:0]          token_data [NW-1:0];        // the extra dword is for the data from the next cycle, needed for anticipated EDB detection
reg     [31:0]          next_token_data [NW-1:0]; // data from the next cycle, needed to anticipate one byte the data
reg     [3:0]           raw_stp_token [NW-1:0];
reg     [3:0]           raw_sdp_token [NW-1:0];
reg     [3:0]           raw_idl_token [NW-1:0];
reg     [3:0]           raw_edb_token [NW-1:0];
reg     [3:0]           raw_next_edb_token;
reg     [NW_INT-1:0]    raw_eds_token;
wire    [3:0]           dec_mask;
reg     [3:0]           dec_stp_token [NW-1:0];
reg     [3:0]           dec_sdp_token [NW-1:0];
reg     [3:0]           dec_idl_token [NW-1:0];
reg     [3:0]           dec_edb_token [NW-1:0];
reg     [3:0]           dec_next_edb_token;
reg     [NW_INT-1:0]    dec_eds_token;
reg     [31:0]          data [NW_MAX:0];        // the extra dword is for the data from the next cycle, needed for anticipated EDB detection
reg     [31:0]          next_data [NW_MAX-1:0]; // data from the next cycle, needed to anticipate one byte the data
reg     [3:0]           data_edb[NW_MAX:0];
reg     [4:0]           active_nw;              // 1,2,4,8,16 - number of currently active dword, f(link_mode, active_nb)
reg     [3:0]           max_active_dw;          // 0,1,3,7,15 the highest currently active dword, f(link_mode, active_nb)
reg     [2:0]           align_active_dw;
reg     [8:0]           prev_token;
reg     [10:0]          prev_tlp_cnt;
reg     [10:0]          tlp_cnt_in[NW_MAX-1:0];
reg     [DW_ERR-1:0]    prev_framing_err;
reg     [3:0]           prev_alignment;
reg     [8:0]           token_in[NW_MAX-1:0];
reg     [DW_ERR-1:0]    framing_err_in[NW_MAX-1:0];
reg     [3:0]           dec_aedb_token[NW_MAX-1:0];
reg     [NW_MAX-1:0]    accept_eds;
reg     [NW_MAX-1:0]    accept_stp_sdp;
reg     [3:0]           alignment_in[NW_MAX-1:0];
wire    [8:0]           token_out_i[NW-1:0];
reg     [8:0]           token_out[NW_MAX-1:0];
wire    [10:0]          tlp_cnt_out_i[NW-1:0];
reg     [10:0]          tlp_cnt_out[NW_MAX-1:0];
wire    [DW_ERR-1:0]    framing_err_out_i[NW-1:0];
reg     [DW_ERR-1:0]    framing_err_out[NW_MAX-1:0];
wire    [NW_INT-1:0]    framing_err_stp_out_i;
reg     [NW_MAX-1:0]    framing_err_stp_out;
wire    [3:0]           alignment_out_i[NW-1:0];
reg     [3:0]           alignment_out[NW_MAX-1:0];
reg     [NW_MAX-1:0]    token_idl;
reg     [NW_MAX-1:0]    token_eds;
reg     [AW-1:0]        rcvd_idle_cnt;
wire                    all_lane_rcvd_idle;
reg     [AW-1:0]        dw_cnt;
reg                     pkt_in_progress;
wire                    deskew_pkt_err;
wire    [NW_INT-1:0]    dllp_start_i;
reg     [NW_MAX-1:0]    dllp_start;
wire    [NW_INT-1:0]    tlp_start_i;
reg     [NW_MAX-1:0]    tlp_start;
wire    [NW_INT-1:0]    pkt_end_i;
reg     [NW_MAX-1:0]    pkt_end;
wire    [NW_INT-1:0]    pkt_edb_i;
reg     [NW_MAX-1:0]    pkt_edb;
wire    [31:0]          pkt_data_i[NW-1:0];
reg     [31:0]          pkt_data[NW_MAX-1:0];
wire                    pkt_dv;
wire    [NW_INT-1:0]    pkt_err_i;
wire    [4:0]           pkt_err_ptr_i[NW-1:0];
reg     [NW_MAX-1:0]    pkt_err;
reg     [4:0]           pkt_err_ptr[NW_MAX-1:0];
reg     [NW_MAX-1:0]    int_pkt_err;
reg     [NW_MAX*5-1:0]  int_pkt_err_ptr;
reg     [NW_MAX-1:0]    dllp_start_r;
reg     [NW_MAX-1:0]    tlp_start_r;
reg     [NW_MAX-1:0]    pkt_end_r;
reg     [NW_MAX-1:0]    pkt_edb_r;
reg     [NW_MAX-1:0]    pkt_err_r;
reg     [NW_MAX*5-1:0]  pkt_err_ptr_r;
reg     [DW_MAX-1:0]    pkt_data_r;
reg                     pkt_dv_r;
wire    [4:0]           link_mode;
reg     [4:0]           link_mode_d;
wire    [4:0]           active_sym;
logic   [AW-1:0]        int_active_nb;

localparam CWD = 3;                      // Framing error found counter width  
wire                    err_found;       // Framing error was detected. The pipeline must be flushed.
reg     [CWD-1:0]       err_found_cnt;   // Framing error found counter
wire                    err_found_set;   // Framing error found set condition

assign link_mode       = (NL==16) ?           smlh_link_mode[4:0]  :
                         (NL==8)  ? {1'b0   , smlh_link_mode[3:0]} :
                         (NL==4)  ? {2'b00  , smlh_link_mode[2:0]} :
                         (NL==2)  ? {3'b000 , smlh_link_mode[1:0]} :
                                     5'b00001;

// Note this module is not used in Gen6, so use CX_GEN45_DYNAMIC_WIDTH instead of CX_GEN456_DYNAMIC_WIDTH to figure-out if the s-ness is constant
// And use CX_NB_GEN3 (istead of CX_NB) because CX_NB might be higher than the s-ness at Gen3/Gen4/Gen5
assign int_active_nb = `CX_NB_GEN3;
assign active_sym[AW-1:0] = 
                         (int_active_nb==8) ? `CX_8S :
                         (int_active_nb==4) ? `CX_4S :
                         (int_active_nb==2) ? `CX_2S : `CX_1S;
assign active_sym[4] = 1'b0;


// Note: The logic belows takes into account NW_INT in order to allow optimizations in case of reduced instances
always @(*) begin : active_nw_comb_PROC
    if     (NW_INT == NW ) begin
        active_nw       = 
                          link_mode[4] ? active_sym[2] ? 5'h10: active_sym[1] ? 5'h8 : 5'h4 :    // 4sx16,2sx16 , 1sx16
                          link_mode[3] ? active_sym[3] ? 5'h10: active_sym[2] ? 5'h8 : active_sym[1] ? 5'h4 : 5'h2 : // 8sx8, 4sx8, 2sx8 , 1sx8
                          link_mode[2] ? active_sym[3] ? 5'h8 : active_sym[2] ? 5'h4 : active_sym[1] ? 5'h2 : 5'h1 : // 8sx4, 4sx4, 2sx4 , 1sx4
                          link_mode[1] ? active_sym[3] ? 5'h4 : active_sym[2] ? 5'h2 : 5'h1 :    // 8sx2, 4sx2, 2sx2   1sx2
                          link_mode[0] ? active_sym[3] ? 5'h2 : 5'h1 : 5'h1 ;                    // 8sx1, 4sx1, 2sx1   1sx1
    end
    else if (NW_INT == 4 ) begin
        active_nw       = link_mode[2] ?                        active_sym[1] ? 5'h2 : 5'h1 :    //             2sx4, 1sx4
                          link_mode[1] ? active_sym[3] ? 5'h4 : active_sym[2] ? 5'h2 : 5'h1 :    // 8sx2, 4sx2, 2sx2  1sx2
                          link_mode[0] ? active_sym[4] ? 5'h4 : active_sym[3] ? 5'h2 : 5'h1 : 5'h1 ;  // 16sx1, 8sx1, 4sx1, 2sx1  1sx1
    end
    else if (NW_INT == 2) begin
        active_nw       = link_mode[3] ? 5'h2 :                                                  //                   1sx8
                          link_mode[2] ?                        active_sym[1] ? 5'h2 : 5'h1 :    //             2sx4, 1sx4
                          link_mode[1] ?                        active_sym[2] ? 5'h2 : 5'h1 :    //       4sx2, 2sx2  1sx2
                          link_mode[0] ? active_sym[3] ? 5'h2 : 5'h1 : 5'h1 ;                    // 8sx1, 4sx1, 2sx1  1sx1
    end
    else begin
        active_nw       =  5'h0 ;
    end
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// input stage - assume data is already reordered for s-ness
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// register the input data
// two stages needed to compensate for dataskip while needing to look ahead for edb and for shifting ahead one byte
always @(*) begin : rxdata3_comb_PROC
    int_rxdata3[0]            = rxdata3[DW-1:0];
    int_rxdata3_dv[0]         = rxdata3_dv;
    int_search_for_tokens[0] = search_for_tokens;
    int_accept_eds_cycle[0]  = accept_eds_cycle;
end

always @(posedge core_clk or negedge core_rst_n) begin : rxdata3_seq_PROC
    integer i;
    if( !core_rst_n ) begin
        for(i=1; i<=2; i=i+1) begin
            int_rxdata3[i]            <= #TP 0;
            int_rxdata3_dv[i]         <= #TP 0;
            int_search_for_tokens[i]  <= #TP 0;
            int_accept_eds_cycle[i]   <= #TP 0;
        end
    end else begin
        // Register Stage 1
        if(int_search_for_tokens[2] && !int_search_for_tokens[0]) begin
            int_rxdata3[1]            <= #TP 32'h0;
            int_rxdata3_dv[1]         <= #TP 1'b1;
            int_search_for_tokens[1]  <= #TP 1'b0;
            int_accept_eds_cycle[1]   <= #TP 1'b0;
        end else if(int_rxdata3_dv[0]) begin
            int_rxdata3[1]            <= #TP int_rxdata3[0];
            int_rxdata3_dv[1]         <= #TP int_rxdata3_dv[0];
            int_search_for_tokens[1]  <= #TP int_search_for_tokens[0];
            int_accept_eds_cycle[1]   <= #TP int_accept_eds_cycle[0];
        end
        // Register Stage 2
        if (int_rxdata3_dv[0] && int_rxdata3_dv[1]) begin
            int_rxdata3[2]            <= #TP int_rxdata3[1];
            int_rxdata3_dv[2]         <= #TP int_rxdata3_dv[1];
            int_search_for_tokens[2]  <= #TP int_search_for_tokens[1];
            int_accept_eds_cycle[2]   <= #TP int_accept_eds_cycle[1];
        end else begin
            // If next DW has not been registered but current DW
            // has been processed then discard data
          //int_rxdata3[2]            <= #TP 0; removed for clock gating
            int_rxdata3_dv[2]         <= #TP 0;
            int_search_for_tokens[2]  <= #TP int_search_for_tokens[1];
            int_accept_eds_cycle[2]   <= #TP int_accept_eds_cycle[1];
        end
   end
end

// Mask Invalid Token Locations based on Current Link Mode
assign dec_mask = (link_mode[0]) ? 4'b1111 : // x1 : Tokens can begin on any byte of received DW
                  (link_mode[1]) ? 4'b0101 : // x2 : Tokens can begin on first and third byte of received DW
                                   4'b0001 ; // x4,x8,x16 : Tokens can only begin on first byte of received DW (all DW-aligned)

always @(posedge core_clk or negedge core_rst_n) begin : accept_stp_sdp_eds_seq_PROC
    if( !core_rst_n ) begin
        {accept_stp_sdp, accept_eds} <= #TP 0;
    end else begin
        {accept_stp_sdp, accept_eds} <= #TP calc_accept_stp_sdp_eds(active_sym, link_mode);
    end
end

// Token Decode
always @(*) begin : raw_token_decode_comb_PROC
    integer i;
    for(i=0;i<NW_INT;i=i+1) begin
        token_data[i] = int_rxdata3[1][32*i +: 32];
        next_token_data[i] = ((i==(active_nw-1)) || (i==(NW-1))) ? int_rxdata3[0][31:0] : int_rxdata3[1][32*(i+1) +: 32];
        raw_stp_token[i] = dec_stp(token_data[i]);
        raw_sdp_token[i] = dec_sdp(token_data[i],next_token_data[i]);
        raw_idl_token[i] = dec_idl(token_data[i]);
        raw_eds_token[i] = (accept_eds[i]) ? dec_eds(token_data[i]) : 1'b0 ;
        raw_edb_token[i] = dec_edb(token_data[i],next_token_data[i]);
    end
        raw_next_edb_token = dec_next_edb(int_rxdata3[0][31:0]);
end

always @(posedge core_clk or negedge core_rst_n) begin : token_decode_seq_PROC
    integer i;
    if( !core_rst_n ) begin
        for(i=0;i<NW_INT;i=i+1) begin
            dec_stp_token[i] <= #TP 4'h0;
            dec_sdp_token[i] <= #TP 4'h0;
            dec_idl_token[i] <= #TP 4'h0;
            dec_edb_token[i] <= #TP 4'h0;
            dec_eds_token[i] <= #TP 1'b0;
        end
            dec_next_edb_token <= #TP 4'h0;
    end else begin
        // Register Decoded Token based on raw decode, link mode and alignment
        for(i=0;i<NW_INT;i=i+1) begin
            dec_stp_token[i] <= #TP (i < ALIGN_MAX) ? (raw_stp_token[i] & dec_mask) : {3'b000,raw_stp_token[i][0]};
            dec_sdp_token[i] <= #TP (i < ALIGN_MAX) ? (raw_sdp_token[i] & dec_mask) : {3'b000,raw_sdp_token[i][0]};
            dec_idl_token[i] <= #TP (i < ALIGN_MAX) ? (raw_idl_token[i])            : {3'b000,raw_idl_token[i][0]};
            dec_edb_token[i] <= #TP (i < ALIGN_MAX) ? (raw_edb_token[i] & dec_mask) : {3'b000,raw_edb_token[i][0]};
            dec_eds_token[i] <= #TP (int_accept_eds_cycle[1]) ? raw_eds_token[i] : 1'b0;
        end
            dec_next_edb_token <= #TP (|link_mode[1:0]) ? (raw_next_edb_token & dec_mask) : {3'b000,raw_next_edb_token[0]}; // Partial Decode only valid for x1/x2
    end
end

// Rearrange the data into an array of 32b words.
// Note the size of the array is fixed to the max possible datapath width.
// This is to facilitate handling all datapath width cases with the same code structure.
// Rely on synthesis, sensitive to link_mode bits hardwired to 0, to blow away unnecessary logic.
always @(*) begin : data_PROC
    integer i;
    for (i=0; i<NW_MAX; i=i+1) begin // preload higher bits in case NW < NW_MAX
        data[i][31:0] = 0;
        data_edb[i][3:0]   = 0;
    end
    for (i=0; i<NW_INT; i=i+1) begin
        data[i][31:0] = int_rxdata3[2][32*i +: 32]; // take from the second register stage - extra latency
        data_edb[i]   = dec_edb_token[i];
    end
    data[NW_MAX][31:0] = int_rxdata3[1][31:0];
    data_edb[NW_MAX]   = dec_next_edb_token;
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// instantiation of token_finder3_slv
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

genvar nw;
generate
for (nw=0; nw<NW_INT; nw = nw+1) begin : gen_token_finder

    rplh_token_finder3_slv
     #(.INST(INST), .ALIGN_MODE((nw<ALIGN_MAX) ? ALIGN_MODE : ALIGN_MODE_X4))
        u_token_finder3_slv (
            /*inputs*/
            .prev_token             (token_in[nw]),
            .prev_tlp_cnt           (tlp_cnt_in[nw]),
            .prev_framing_err       (framing_err_in[nw]),
            .prev_alignment         (alignment_in[nw]),
            .data_in                (data[nw]),
            .next_data_in           (next_data[nw]),
            .dec_stp_token          (dec_stp_token[nw]),
            .dec_sdp_token          (dec_sdp_token[nw]),
            .dec_idl_token          (dec_idl_token[nw]),
            .dec_eds_token          (dec_eds_token[nw]),
            .dec_edb_token          (dec_edb_token[nw]),
            .dec_aedb_token         (dec_aedb_token[nw]),
            .accept_stp_sdp         (accept_stp_sdp[nw]),
            /*outputs*/
            .token                  (token_out_i[nw]),
            .tlp_cnt                (tlp_cnt_out_i[nw]),
            .framing_err            (framing_err_out_i[nw]),
            .framing_err_stp        (framing_err_stp_out_i[nw]),
            .alignment              (alignment_out_i[nw]),
            .dllp_start             (dllp_start_i[nw]),
            .tlp_start              (tlp_start_i[nw]),
            .pkt_end                (pkt_end_i[nw]),
            .pkt_edb                (pkt_edb_i[nw]),
            .pkt_data               (pkt_data_i[nw]),
            .pkt_err                ({pkt_err_ptr_i[nw],pkt_err_i[nw]})
            );
    end
endgenerate

//drive undriven bits to 0 in case NW < NW_MAX
always @( * ) begin : extend_width_PROC
    integer i;

    for (i=0; i<NW_MAX; i=i+1) begin //preload higher bits in case NW < NW_MAX
        token_out[i][8:0]      = 0;
        tlp_cnt_out[i][10:0]   = 0;
        alignment_out[i][3:0]  = 0;
        pkt_data[i][31:0]      = 0;

        framing_err_out[i]     = 0;
        framing_err_stp_out[i] = 0;
        dllp_start[i]          = 0;
        tlp_start[i]           = 0;
        pkt_end[i]             = 0;
        pkt_edb[i]             = 0;
        pkt_err[i]             = 0;
        pkt_err_ptr[i]         = 0;
    end

    for (i=0; i<NW_INT;     i=i+1) begin //take data with real width
        token_out[i][8:0]      = token_out_i[i][8:0];
        tlp_cnt_out[i][10:0]   = tlp_cnt_out_i[i][10:0];
        alignment_out[i][3:0]  = alignment_out_i[i][3:0];
        pkt_data[i][31:0]      = pkt_data_i[i][31:0];

        framing_err_out[i]     = framing_err_out_i[i];
        framing_err_stp_out[i] = framing_err_stp_out_i[i];
        dllp_start[i]          = dllp_start_i[i];
        tlp_start[i]           = tlp_start_i[i];
        pkt_end[i]             = pkt_end_i[i];
        pkt_edb[i]             = pkt_edb_i[i];
        pkt_err[i]             = pkt_err_i[i];
        pkt_err_ptr[i]         = pkt_err_ptr_i[i];
    end //for ( i=0
end //always @(

assign pkt_dv = int_rxdata3_dv[2];

always @(posedge core_clk or negedge core_rst_n) begin : max_active_dw_seq_PROC
    if( !core_rst_n ) begin
        max_active_dw   <= #TP 0;
        align_active_dw <= #TP 0;
        link_mode_d     <= #TP 0;
    end else begin
        max_active_dw   <= #TP active_nw - 1;
        align_active_dw <= #TP calc_align_dw(active_sym, link_mode);
        link_mode_d     <= #TP link_mode;
    end
end

always @(*) begin : token_finder_interconnect_PROC
    integer i;

    for(i=0; i<NW_INT; i=i+1) begin
        if(i==0) begin
            framing_err_in[0] = prev_framing_err;
            tlp_cnt_in[0]     = prev_tlp_cnt;
            token_in[0]       = prev_token;
            alignment_in[0]   = prev_alignment;
        end else begin
            framing_err_in[i] = framing_err_out[i-1];
            tlp_cnt_in[i]     = tlp_cnt_out[i-1];
            token_in[i]       = token_out[i-1];
            alignment_in[i]   = (i<ALIGN_MAX) ? alignment_out[i-1] : 4'b0001 ; // 4'b0001 is default alignment
        end
    end

    for(i=0; i<NW_MAX; i=i+1) begin
        dec_aedb_token[i] = data_edb[i+1];
        next_data[i] = data[i+1];
    end

    if( active_nw == 8) begin
        dec_aedb_token[7] = data_edb[NW_MAX];
        next_data[7]    = data[NW_MAX];
    end else
    if( active_nw == 4) begin
        dec_aedb_token[3] = data_edb[NW_MAX];
        next_data[3]    = data[NW_MAX];
    end else
    if( active_nw == 2) begin
        dec_aedb_token[1] = data_edb[NW_MAX];
        next_data[1]    = data[NW_MAX];
    end else
    if( active_nw == 1) begin
        dec_aedb_token[0] = data_edb[NW_MAX];
        next_data[0]    = data[NW_MAX];
    end
end

always @(*) begin : decode_pkt_err
    integer i;

    int_pkt_err = 0;
    int_pkt_err_ptr = 0;

    // If a one of the token_finder_slv units reports pkt_err,
    // set pkt_err for all subsequent token_finder_slv units
    for (i=0; i<NW_INT; i=i+1) begin
        if(i==0) begin
            int_pkt_err[0] = pkt_err[0] | (pkt_err_r[NW_MAX-1] & ~pkt_dv_r) | deskew_pkt_err | eds_err;
            int_pkt_err_ptr[5*i +: 5] = (pkt_err_r[NW_MAX-1] & ~pkt_dv_r) ? pkt_err_ptr[NW_MAX-1] :
                                        (deskew_pkt_err) ? 5'b0_0110 : (eds_err) ? 5'b0_0101 : pkt_err_ptr[i];
        end else begin
            int_pkt_err[i] = pkt_err[i] | int_pkt_err[i-1];
            int_pkt_err_ptr[5*i +: 5] = (|int_pkt_err[(i-1)]) ? pkt_err_ptr[(i-1)] : pkt_err_ptr[i];
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// state
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always @(posedge core_clk or negedge core_rst_n) begin : token_seq_PROC
    if( !core_rst_n ) begin
        prev_token               <= #TP `TKF_S_IDL;
        prev_tlp_cnt             <= #TP 0;
        prev_framing_err         <= #TP 0;
        prev_alignment           <= #TP 4'b0001;
        pkt_in_progress          <= #TP 0;
    end else begin
        if( int_search_for_tokens[2] ) begin
            if( pkt_dv ) begin
                prev_token       <= #TP token_out[max_active_dw];
                prev_tlp_cnt     <= #TP tlp_cnt_out[max_active_dw];
                prev_framing_err <= #TP framing_err_out[max_active_dw];
                prev_alignment   <= #TP alignment_out[{1'b0,align_active_dw}]; // 0 padding to avoid "index too short" with NW_MAX=16
                pkt_in_progress  <= #TP ((token_out[max_active_dw] == `TKF_S_STP) || (token_out[max_active_dw] == `TKF_S_SDP) ||
                                         (token_out[max_active_dw] == `TKF_S_DTP) || (token_out[max_active_dw] == `TKF_S_aEDB));
            end
        end else begin
            prev_token           <= #TP `TKF_S_IDL;
            prev_tlp_cnt         <= #TP 0;
            prev_framing_err     <= #TP 0;
            prev_alignment       <= #TP 4'b0001;
            pkt_in_progress      <= #TP 0;
        end
    end
end

// 4.2.2.3.4. Recovery from Framing Errors
// If a receiver detects a Framing Error while processing the Data Stream, it must [...] Stop processing the Data Stream. 
// Processing of a new Data Stream is initiated when the next SDS Ordered Set is received.
// Implementation details:
// When a framing error is detected, the deskew module is in change of disabling search_for_token until the next SDS is received.
// By disabling search_for_tokens the deskew inhibits data processing.
// Nevertheless, the deskew module reacts with 1 clk cycle delay, the internal pipelines need to be invalidated (3 stages)
// and 1 additinal clock cycle need to be accounted to consider the delay of the eds_err logic.
// The following logic aims disabling data processing during this window (minimum 5 clock cycles).
assign err_found_set = |rplh_rdlh_pkt_err;

always @(posedge core_clk or negedge core_rst_n) begin : err_found_cnt_seq_PROC
    if( !core_rst_n)
        err_found_cnt   <= #TP 0;
    else if ((err_found_set && err_found_cnt == 0) || (err_found_cnt>0 && err_found_cnt < {CWD{1'b1}}))
        err_found_cnt   <= #TP err_found_cnt + 1;
    else if (!int_search_for_tokens[2])
        err_found_cnt   <= #TP 0;
end

assign err_found = err_found_set | err_found_cnt>0;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// create outputs
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge core_clk or negedge core_rst_n) begin : dw_cnt_seq_PROC
    if( !core_rst_n )
        dw_cnt  <= #TP 0;
    else if (link_mode != link_mode_d )  // Reset count when link_mode changes
        dw_cnt  <= #TP 0;
    else if (pkt_dv|eds_err)
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        dw_cnt  <= #TP dw_cnt + active_nw[AW-1:0]; // Count DWs received
// spyglass enable_block W164a
end

// Assemble data according to number of active DWs
always @(posedge core_clk or negedge core_rst_n) begin : rplh_rdlh_seq_PROC
    if(!core_rst_n) begin
        pkt_data_r                          <= #TP 0;
        dllp_start_r                        <= #TP 0;
        tlp_start_r                         <= #TP 0;
        pkt_end_r                           <= #TP 0;
        pkt_edb_r                           <= #TP 0;
        pkt_err_r                           <= #TP 0;
        pkt_err_ptr_r                       <= #TP 0;
    end else if(pkt_dv|eds_err) begin
                if (active_nw == 16) begin
                    pkt_data_r               <= #TP {pkt_data[15], pkt_data[14], pkt_data[13], pkt_data[12],
                                                     pkt_data[11], pkt_data[10], pkt_data[9] , pkt_data[8] ,
                                                     pkt_data[7],  pkt_data[6] , pkt_data[5] , pkt_data[4] ,
                                                     pkt_data[3],  pkt_data[2] , pkt_data[1] , pkt_data[0] };
                    dllp_start_r             <= #TP err_found ? 0 : dllp_start & ~int_pkt_err;
                    tlp_start_r              <= #TP err_found ? 0 : tlp_start  & ~int_pkt_err;
                    pkt_end_r                <= #TP err_found ? 0 :(pkt_end    & ~int_pkt_err) | {16{deskew_pkt_err|eds_err}};
                    pkt_edb_r                <= #TP err_found ? 0 : pkt_edb    & ~int_pkt_err;
                    pkt_err_r                <= #TP int_pkt_err;
                    pkt_err_ptr_r            <= #TP int_pkt_err_ptr;
                end
                else if (active_nw == 8) begin
                    pkt_data_r               <= #TP {pkt_data[7], pkt_data[6], pkt_data[5], pkt_data[4],
                                                     pkt_data[3], pkt_data[2], pkt_data[1], pkt_data[0], pkt_data_r[DW_MAX-1:256]};
                    dllp_start_r             <= #TP { err_found ? 8'b0 : dllp_start[7:0] & ~int_pkt_err[7:0], dllp_start_r[NW_MAX-1:8]};
                    tlp_start_r              <= #TP { err_found ? 8'b0 : tlp_start[7:0]  & ~int_pkt_err[7:0], tlp_start_r[NW_MAX-1:8]};
                    pkt_end_r                <= #TP { err_found ? 8'b0 :(pkt_end[7:0]    & ~int_pkt_err[7:0]) | {8{deskew_pkt_err|eds_err}}, pkt_end_r[NW_MAX-1:8]};
                    pkt_edb_r                <= #TP { err_found ? 8'b0 : pkt_edb[7:0]    & ~int_pkt_err[7:0], pkt_edb_r[NW_MAX-1:8]};
                    pkt_err_r                <= #TP {int_pkt_err[7:0],pkt_err_r[NW_MAX-1:8]};
                    pkt_err_ptr_r            <= #TP {int_pkt_err_ptr[8*5-1:0],pkt_err_ptr_r[NW_MAX*5-1:8*5]};
                end
                else if (active_nw == 4) begin
                    pkt_data_r               <= #TP {pkt_data[3], pkt_data[2], pkt_data[1], pkt_data[0], pkt_data_r[DW_MAX-1:128]};
                    dllp_start_r             <= #TP { err_found ? 4'b0 : dllp_start[3:0] & ~int_pkt_err[3:0], dllp_start_r[NW_MAX-1:4]};
                    tlp_start_r              <= #TP { err_found ? 4'b0 : tlp_start[3:0]  & ~int_pkt_err[3:0], tlp_start_r[NW_MAX-1:4]};
                    pkt_end_r                <= #TP { err_found ? 4'b0 :(pkt_end[3:0]    & ~int_pkt_err[3:0]) | {4{deskew_pkt_err|eds_err}}, pkt_end_r[NW_MAX-1:4]};
                    pkt_edb_r                <= #TP { err_found ? 4'b0 : pkt_edb[3:0]    & ~int_pkt_err[3:0], pkt_edb_r[NW_MAX-1:4]};
                    pkt_err_r                <= #TP {int_pkt_err[3:0],pkt_err_r[NW_MAX-1:4]};
                    pkt_err_ptr_r            <= #TP {int_pkt_err_ptr[4*5-1:0],pkt_err_ptr_r[NW_MAX*5-1:4*5]};
                end
                else if (active_nw == 2) begin
                    pkt_data_r               <= #TP {pkt_data[1], pkt_data[0], pkt_data_r[DW_MAX-1:64]};
                    dllp_start_r             <= #TP { err_found ? 2'b0 : dllp_start[1:0] & ~int_pkt_err[1:0], dllp_start_r[NW_MAX-1:2]};
                    tlp_start_r              <= #TP { err_found ? 2'b0 : tlp_start[1:0]  & ~int_pkt_err[1:0], tlp_start_r[NW_MAX-1:2]};
                    pkt_end_r                <= #TP { err_found ? 2'b0 :(pkt_end[1:0]    & ~int_pkt_err[1:0]) | {2{deskew_pkt_err|eds_err}}, pkt_end_r[NW_MAX-1:2]};
                    pkt_edb_r                <= #TP { err_found ? 2'b0 : pkt_edb[1:0]    & ~int_pkt_err[1:0], pkt_edb_r[NW_MAX-1:2]};
                    pkt_err_r                <= #TP {int_pkt_err[1:0], pkt_err_r[NW_MAX-1:2]};
                    pkt_err_ptr_r            <= #TP {int_pkt_err_ptr[2*5-1:0], pkt_err_ptr_r[NW_MAX*5-1:2*5]};
                end
                else begin // active_nw == 1
                    pkt_data_r               <= #TP {pkt_data[0], pkt_data_r[DW_MAX-1:32]};
                    dllp_start_r             <= #TP { err_found ? 1'b0 : dllp_start[0] & ~int_pkt_err[0], dllp_start_r[NW_MAX-1:1]};
                    tlp_start_r              <= #TP { err_found ? 1'b0 : tlp_start[0]  & ~int_pkt_err[0], tlp_start_r[NW_MAX-1:1]};
                    pkt_end_r                <= #TP { err_found ? 1'b0 :(pkt_end[0]    & ~int_pkt_err[0]) | deskew_pkt_err | eds_err, pkt_end_r[NW_MAX-1:1]};
                    pkt_edb_r                <= #TP { err_found ? 1'b0 : pkt_edb[0]    & ~int_pkt_err[0], pkt_edb_r[NW_MAX-1:1]};
                    pkt_err_r                <= #TP {int_pkt_err[0], pkt_err_r[NW_MAX-1:1]};
                    pkt_err_ptr_r            <= #TP {int_pkt_err_ptr[4:0], pkt_err_ptr_r[NW_MAX*5-1:1*5]};
                end
            end
end

// Drive pkt_dv_r based on core datapath width, active number of DWs
// and the number of DWs currently available
always @(posedge core_clk or negedge core_rst_n) begin : pkt_dv_PROC
    if( !core_rst_n ) begin
        pkt_dv_r <= #TP 0;
    end
    else if (pkt_dv|eds_err) begin
        if ( active_nw == NW) // All Lanes Active
            pkt_dv_r <= #TP 1'b1;
        else if ( active_nw == 8)
            pkt_dv_r <= #TP (dw_cnt[3:0] == NW-8);
        else if ( active_nw == 4)
            pkt_dv_r <= #TP (NW == 16) ? (dw_cnt[3:0] == NW-4) : (dw_cnt[2:0] == NW-4);
        else if ( active_nw == 2)
            pkt_dv_r <= #TP (NW == 16) ? (dw_cnt[3:0] == NW-2) : (NW == 8) ? (dw_cnt[2:0] == NW-2) : (dw_cnt[1:0] == NW-2);
        else if ( active_nw == 1 )
            pkt_dv_r <= #TP (NW == 16) ? (dw_cnt[3:0] == NW-1) : (NW == 8) ? (dw_cnt[2:0] == NW-1) : (NW == 4) ? (dw_cnt[1:0] == NW-1) : (dw_cnt[0] == NW-1);
    end
    else begin
        pkt_dv_r <= #TP 0;
    end
end

// If pkt_in_progress is HIGH and int_search_for_tokens goes LOW, this
// indicates that a framing error has been detected in the deskew block
// while a packet has been in progress in token_finder. Used to enable
// int_pkt_err to indicate framing error. pkt_end will be enabled to
// terminate the packet in progress and no more packets will be passed 
// to Layer2
assign  deskew_pkt_err        = pkt_in_progress && !int_search_for_tokens[2];

assign  rplh_rdlh_pkt_dv      = pkt_dv_r;
assign  rplh_rdlh_dllp_start  = { {NW_ORG-NW{1'b0}}, dllp_start_r[NW_MAX-1:NW_MAX-NW]};
assign  rplh_rdlh_tlp_start   = { {NW_ORG-NW{1'b0}}, tlp_start_r [NW_MAX-1:NW_MAX-NW]};
assign  rplh_rdlh_pkt_edb     = { {NW_ORG-NW{1'b0}}, pkt_edb_r   [NW_MAX-1:NW_MAX-NW]};
assign  rplh_rdlh_pkt_end     = { {NW_ORG-NW{1'b0}}, pkt_end_r   [NW_MAX-1:NW_MAX-NW]};
assign  rplh_rdlh_pkt_data    = { {DW_ORG-DW{1'b0}}, pkt_data_r  [DW_MAX-1:DW_MAX-DW]};
assign  rplh_rdlh_pkt_err     = { {NW_ORG-NW{1'b0}}, pkt_err_r   [NW_MAX-1:NW_MAX-NW]};
assign  rplh_rdlh_pkt_err_ptr = { {(NW_ORG-NW)*5{1'b0}}, pkt_err_ptr_r[NW_MAX*5-1:(NW_MAX-NW)*5]};

// idle cnt
always @(*) begin : token_idl_PROC
    integer i;
    token_idl = {NW_MAX{1'b1}};
    token_eds = 0;
    for(i=0; i<NW_MAX; i=i+1) begin
        if(i<=max_active_dw) begin
            token_idl[i] = (token_out[i] == `TKF_S_IDL) && (framing_err_out[i][0] == 0);
            token_eds[i] = (token_out[i] == `TKF_S_EDS) && (framing_err_out[i][0] == 0);
        end
    end
end

assign all_lane_rcvd_idle = &token_idl;  // All Lanes detected IDL

wire [AW-1:0] idle_incr; // Number of Symbol Times to increment rcvd_idle_cnt
assign idle_incr = ((link_mode[0]) && (active_sym[AW-1:0] == `CX_1S)) ?  4 : // in 1sx1 mode every pkt_dv cycle correspond to 4 symbol times
                   ((link_mode[0]) && (active_sym[AW-1:0] == `CX_2S)) ?  4 : // in 2sx1 mode every pkt_dv cycle correspond to 4 symbol times
                   ((link_mode[1]) && (active_sym[AW-1:0] == `CX_1S)) ?  2 : // in 1sx2 mode every pkt_dv cycle correspond to 2 symbol times
                                                         active_sym[AW-1:0];

always @(posedge core_clk or negedge core_rst_n) begin : rcvd_idle_cnt_seq_PROC
    if( !core_rst_n ) begin
        rcvd_idle_cnt <= #TP 0;
    end else if (!int_search_for_tokens[2]) begin
        rcvd_idle_cnt <= #TP 0;
    end else if (pkt_dv) begin
        if(all_lane_rcvd_idle) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
            rcvd_idle_cnt <= #TP rcvd_idle_cnt + idle_incr;
// spyglass enable_block W164a
        end else begin
            rcvd_idle_cnt <= #TP 0;
        end
    end
end

assign rplh_rcvd_idle[1] = (rcvd_idle_cnt != 0);
assign rplh_rcvd_idle[0] = (rcvd_idle_cnt >= 8);

////////////////////////////////////////////////////////////////////////////////
// EDS Reception and Error Checking
////////////////////////////////////////////////////////////////////////////////
//
// Scenario 1: EDS followed by SKP/EIOS/EIOS
//               _   _   _   _   _   _   _
// core_clk    _| |_| |_| |_| |_| |_| |_| |
//              ______________________
// rxdata3       |EDS|SKP
//               ___
// accept_eds  _|   |_________________
//                       ___
// expect_eds  _________|   |_________
//
// Scenario 2: EDS followed by rxdata3Skip followed by SKP/EIOS/EIEOS
//               _   _   _   _   _   _   _
// core_clk    _| |_| |_| |_| |_| |_| |_|
//              ______________________
// rxdata3       |EDS|XXX|SKP
//               ___
// accept_eds  _|   |________________
//                           ___
// expect_eds  _____________|   |_____
//
// Scenario 3: EDS followed by 2 x rxdata3Skip followed by SKP/EIOS/EIEOS
//               _   _   _   _   _   _   _
// core_clk    _| |_| |_| |_| |_| |_| |_|
//              ______________________
// rxdata3       |EDS|XXX|XXX|SKP
//               ___
// accept_eds  _|   |________________
//                               ___
// expect_eds  _________________|   |_____
//
// There are 2 scenarios for EDS reception. The first is where the EDS token is
// immediately followed by a SKP/EIOS/EIEOS OS block. In this case, there is
// a 1 clock cycle delay between accept_eds being pulsed and expect_eds being
// pulsed. In the second scenario, a rxdata3Skip cycle occurs between the EDS
// token and the SKP/EIOS/EIEOS OS block. This causes an additional cycle of
// delay between accept_eds and expect_eds.
//
// A registered version of accept_eds is used to account for this variable
// delay and control how the eds_exp register is loaded.
//
// An EDS error occurs whenever an EDS token is expected but not received or
// whenever an EDS token is received but not expected.
//
// |----------------------------------------------------------|
// |eds_exp |eds_rcvd|eds_err | Comment                       |
// |----------------------------------------------------------|
// |   0    |   0    |   0    | EDS not received nor expected |
// |   0    |   1    |   1    | EDS received but not expected |
// |   1    |   0    |   1    | EDS expected but not received |
// |   1    |   1    |   0    | EDS received and expected     |
// |----------------------------------------------------------|
//
// Note after the modifications to support two cycle rxdata3Skip:
// Accept_eds is generated at the end of a block. Expect_eds is generated at the
// start of the next block, with a variable delay of 2,3,4 cycles, depending on how
// many rxdata3Skips are inserted in between the end of one block and the start of the
// next. Eds_rcvd is generated with a fixed delay of two cycle with respect to accept_eds
// plus a variable component of zero one or two cycles, depending on the behaviour of
// rxdata3_dv, which in turns depends on search_for_tokens. When search_for_tokens is
// low on the cycle following accept_eds then rxdata3_dv=1 regardless of rxdata3Skips.
// When search_for_tokens is high on the cycle following accept_eds then rxdata3_dv can
// be 0 on that cycle, which adds one cycle delay to eds_rcvd.
//
////////////////////////////////////////////////////////////////////////////////

always @(posedge core_clk or negedge core_rst_n) begin : eds_rcvd_PROC
    if( !core_rst_n ) begin
        eds_rcvd  <= #TP 0;
    end
    //STAR 9000496460:
    //OLD:
    //else if (pkt_dv) begin
    //    eds_rcvd <= {eds_rcvd[0], |token_eds};
    //end
    //NEW:
    else begin
        eds_rcvd <= #TP {eds_rcvd[0], ((|token_eds) & pkt_dv)};
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : eds_exp_PROC
    if( !core_rst_n )
        eds_exp <= #TP 0;
    else if(expect_eds) begin
        if(int_accept_eds_cycle[2])
            eds_exp <= #TP 2'b01;
        else
            eds_exp <= #TP 2'b10;
    end
    else
        eds_exp <= #TP {eds_exp[0],1'b0};
end

assign eds_err = eds_exp[1]^eds_rcvd[1];

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// coverage assertions for EDS scenarios involving 0,1,2 rxdatavalid=0 cycles in between blocks (IT#2227)
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// internal functions
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function automatic [NW_MAX*2-1:0] calc_accept_stp_sdp_eds(input [4:0] active_sym, input [4:0] link_mode);
    reg [NW_MAX-1:0] i_accept_stp_sdp, i_accept_eds;
    begin
        // Each bit in i_accept_stp_sdp informs the respective token_finder3_slv whether to decode or not a framing error if a start token is preceeded by IDL. 
        // The logic is enabled (i.e. framing error is detected) when the bit is unset (0) and disabled when is set (1).
        // The first vector below contains the real information about where to apply the framing rule. The second vector in OR is a simple mask 
        // that sets (1) every bit referring a dw not used in the respective datpath width. This mask aims the automatic detection of unnecessary logic.

        case( {active_sym[4:0], link_mode[4:0]}  )
            // 512b 16DW datapath
            10'b00100_10000 /* 4sx16*/ : begin i_accept_stp_sdp = (16'b0001_0001_0001_0001 | 16'b0000_0000_0000_0000); i_accept_eds = 16'b1000_1000_1000_1000; end
            10'b01000_01000 /* 8sx8 */ : begin i_accept_stp_sdp = (16'b0101_0101_0101_0101 | 16'b0000_0000_0000_0000); i_accept_eds = 16'b1000_1000_1000_1000; end

            // 256b 8DW datapath
            10'b00010_10000 /* 2sx16*/ : begin i_accept_stp_sdp = (16'b0000_0000_0001_0001 | 16'b1111_1111_0000_0000); i_accept_eds = 16'b0000_0000_1000_1000; end
            10'b00100_01000 /* 4sx8 */ : begin i_accept_stp_sdp = (16'b0000_0000_0101_0101 | 16'b1111_1111_0000_0000); i_accept_eds = 16'b0000_0000_1000_1000; end
            10'b01000_00100 /* 8sx4 */ : begin i_accept_stp_sdp = (16'b0000_0000_1111_1111 | 16'b1111_1111_0000_0000); i_accept_eds = 16'b0000_0000_1000_1000; end

            // 128b 4DW datapath
            10'b00010_01000 /* 2sx8 */ : begin i_accept_stp_sdp = (16'b0000_0000_0000_0101 | 16'b1111_1111_1111_0000); i_accept_eds = 16'b0000_0000_0000_1000; end
            10'b00100_00100 /* 4sx4 */ : begin i_accept_stp_sdp = (16'b0000_0000_0000_1111 | 16'b1111_1111_1111_0000); i_accept_eds = 16'b0000_0000_0000_1000; end
            10'b01000_00010 /* 8sx2 */ : begin i_accept_stp_sdp = (16'b0000_0000_0000_1111 | 16'b1111_1111_1111_0000); i_accept_eds = 16'b0000_0000_0000_1000; end
            10'b10000_00001 /*16sx1 */ : begin i_accept_stp_sdp = (16'b0000_0000_0000_1111 | 16'b1111_1111_1111_0000); i_accept_eds = 16'b0000_0000_0000_1000; end

            // 64b 2DW datapath
            10'b00001_01000 /* 1sx8 */ : begin i_accept_stp_sdp = (16'b0000_0000_0000_0001 | 16'b1111_1111_1111_1100); i_accept_eds = 16'b0000_0000_0000_0010; end
            10'b00010_00100,/* 2sx4 */
            10'b00100_00010 /* 4sx2 */ : begin i_accept_stp_sdp = (16'b0000_0000_0000_0011 | 16'b1111_1111_1111_1100); i_accept_eds = 16'b0000_0000_0000_0010; end
            10'b01000_00001 /* 8sx1 */ : begin i_accept_stp_sdp = (16'b0000_0000_0000_0011 | 16'b1111_1111_1111_1100); i_accept_eds = 16'b0000_0000_0000_0010; end
            // 32b 1DW datapath
            default    /* 1sx4 */
                       /* 2sx2 */
                       /* 4sx1 */
            // 16b 0.5DW datapath
                       /* 1sx2 */
                       /* 2sx1 */
            // 8b 0.25DW datapath
                       /* 1sx1 */      : begin i_accept_stp_sdp = (16'b0000_0000_0000_0001 | 16'b1111_1111_1111_1110); i_accept_eds = 16'b0000_0000_0000_0001; end
        endcase
        calc_accept_stp_sdp_eds = {i_accept_stp_sdp, i_accept_eds};
    end
endfunction

// return the number of token processor to take the prev_alignment from, 0,1 or 3
// when the link mode is such that the first 4 token processors are used. When the 
// link mode uses greater than 4 token processors the alignment logic is not needed 
// so always return 0
function automatic [2:0] calc_align_dw(input [4:0] active_sym, input [4:0] link_mode);
    begin
        case( {active_sym[4:0], link_mode[4:0]}  )
            10'b01000_00010 /*  8sx2 */ : calc_align_dw = 3'b011;
            10'b01000_00001 /*  8sx1 */ : calc_align_dw = 3'b001;
            10'b00100_00010 /*  4sx2 */ : calc_align_dw = 3'b001;
            default      /* 2sx1 */
                         /* 2sx2 */
                         /* 4sx1 */ : calc_align_dw = 3'b000;
        endcase
    end
endfunction

function automatic [3:0] dec_stp (input [31:0] data_in);
    begin
       dec_stp[0] = (data_in[3:0]   == `STP_4B);
       dec_stp[1] = (data_in[11:8]  == `STP_4B);
       dec_stp[2] = (data_in[19:16] == `STP_4B);
       dec_stp[3] = (data_in[27:24] == `STP_4B);
    end
endfunction

function automatic [3:0] dec_sdp (input [31:0] data_in, input [31:0] next_data_in);
    begin
       dec_sdp[0] = (                    data_in[15:0]   == `SDP_16B);
       dec_sdp[1] = (                    data_in[23:8]   == `SDP_16B);
       dec_sdp[2] = (                    data_in[31:16]  == `SDP_16B);
       dec_sdp[3] = ({next_data_in[7:0], data_in[31:24]} == `SDP_16B);
    end
endfunction

function automatic dec_eds (input [31:0] data_in); // EDS always DW aligned
    begin
       dec_eds = (data_in[31:0] == `EDS_32B);
    end
endfunction

function automatic [3:0] dec_edb (input [31:0] data_in, input [31:0] next_data_in);
    begin
       dec_edb[0] = (                     data_in[31:0]   == `EDB_32B);
       dec_edb[1] = ({next_data_in[7:0],  data_in[31:8]}  == `EDB_32B);
       dec_edb[2] = ({next_data_in[15:0], data_in[31:16]} == `EDB_32B);
       dec_edb[3] = ({next_data_in[23:0], data_in[31:24]} == `EDB_32B);
    end
endfunction

function automatic [3:0] dec_next_edb (input [31:0] data_in);
    reg [31:0] edb_token;
    begin
       // EDB Token = `EDB_32B = 32'hC0C0C0C0
       edb_token = `EDB_32B;
       dec_next_edb[0] = (data_in[31:0]  == edb_token[31:0]);
       dec_next_edb[1] = (data_in[31:8]  == edb_token[23:0]);
       dec_next_edb[2] = (data_in[31:16] == edb_token[15:0]);
       dec_next_edb[3] = (data_in[31:24] == edb_token[7:0]);
    end
endfunction

function automatic [3:0] dec_idl (input [31:0] data_in);
    reg [31:0] idl_token;
    begin
       // IDL Token = `IDL_32B = 32'h00000000
       idl_token = `IDL_32B;
       dec_idl[0] = (data_in[31:0]  == idl_token[31:0]);
       dec_idl[1] = (data_in[31:8]  == idl_token[23:0]);
       dec_idl[2] = (data_in[31:16] == idl_token[15:0]);
       dec_idl[3] = (data_in[31:24] == idl_token[7:0]);
    end
endfunction

`ifndef SYNTHESIS
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// debug signals
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [31:0] data_0 = data[0];
wire [31:0] data_1 = data[1];
wire [31:0] data_2 = data[2];
wire [31:0] data_3 = data[3];
wire [31:0] pkt_data_0 = pkt_data[0];
wire [31:0] pkt_data_1 = pkt_data[1];
wire [31:0] pkt_data_2 = pkt_data[2];
wire [31:0] pkt_data_3 = pkt_data[3];

struct {
    reg [2:0] int_rxdata3_dv; // int_rxdata3_dv converted from vector into array to prevent tool from detecting a FSM
} debug_s;
assign debug_s.int_rxdata3_dv = {int_rxdata3_dv[2], int_rxdata3_dv[1], int_rxdata3_dv[0]};
`endif // SYNTHESIS

endmodule // rplh_token_finder3
