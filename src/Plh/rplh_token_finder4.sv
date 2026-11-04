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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_token_finder4.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description: Receive MAC Layer Token Finder for Gen3/Gen4
// ---                     suitable for datapath widths of 128b and above
// -----------------------------------------------------------------------------

// www - Future Enhancements
// 1. x1/x2 link modes with byte/dword token alignment (currently handled by token_finder3)
// 2. support for datapath widths below 128 (currently handled by token_finder3)
// 3. optionally move active_sym logic and active_qdw logic to pkt_finder and share with token_finder3

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rplh_token_finder4
#(
parameter   NL        = `CX_NL,                       // Max number of lanes supported
parameter   NB        = `CX_NB,                       // Number of symbols (bytes) per clock cycle
parameter   AW        = `CX_ANB_WD,                   // Width of the active number of bytes
parameter   TP        = `TP,                          // Clock to Q delay (simulator insurance)
parameter   NW_ORG    = (`CX_PL_NW<4)? 4 : `CX_PL_NW, // Number of 32-bit dwords handled by the datapath each clock. Note: mininum datapath is 128bits. 
parameter   DW_ORG    = (32*NW_ORG),                  // Width of datapath in bits.
parameter   NW        = (NW_ORG>16)? 16 : NW_ORG,     // Number of 32-bit dwords handled by this module. Mininum 4 dwords, maximum 16 dwords.
parameter   DW        = (32*NW),                      // Width of datapath in bits handled by this module. Minimum 128bits, maximum 512bits.
parameter   CXL_TOKEN_SER = 0,                        // if (1) then generate with ifdef CX_RPLH_CXL_TOKEN_SER_ENABLE used for 128/256 CXL data width
                                                      // if (0) then CXL 512 and non-cxl mode (as usual operation)
parameter   PREDICTOR = 0                             // Pipeline predictor mode
)

                          (
// ---- inputs ---------------
input                   core_clk,               // Core Clock
input                   core_rst_n,             // Core Reset
input                   cxl_mode_enable,        // Link is negotiated in CXL mode
input   [5:0]           smlh_link_mode,         // Current Link Mode
input                   search_for_tokens,      // Search for Tokens. Indication from Deskew Block to search for tokens in current rxdata3
input                   accept_eds_cycle,       // Pulse active on last cycle of a block that indicates an EDS token may be accepted.
input                   expect_eds,             // Signal from deskew block to inform token_finder that EDS is expected
input                   rxdata3_dv,             // Incoming Data is Valid, suffix "3" is to remind that this data valid is squelched to 1 when search_for_tokens = 0
input   [DW_ORG-1:0]    rxdata3,                // Incoming Data, suffix "3" is to remind that this data is squelched to all 0's when search_for_tokens = 0

// ---- outputs ---------------
output  [NW_ORG-1:0]    rplh_rdlh_dllp_start,   // Indicates DWord location of SDP
output  [NW_ORG-1:0]    rplh_rdlh_tlp_start,    // Indicates DWord location of STP
output  [NW_ORG-1:0]    rplh_rdlh_pkt_end,      // Indicates Dword location of END or EBD
output  [NW_ORG-1:0]    rplh_rdlh_pkt_edb,      // Indicates DWord location of EDB
output  [DW_ORG-1:0]    rplh_rdlh_pkt_data,     // Packet Data
output                  rplh_rdlh_pkt_dv,       // Packet Data Valid
output  [NW_ORG-1:0]    rplh_rdlh_pkt_err,      // Packet Error
output  [NW_ORG*5-1:0]  rplh_rdlh_pkt_err_ptr,  // Packet Error Pointer
output                  no_pkt_in_progress,     // Indicates that the pipeline can be flushed because there are no incomplete packets in progress
output  [1:0]           rplh_rcvd_idle          // Number of Continuous Received IDL Symbols. Encoded as {Num IDLs != 0, Num IDLs >= 8}
);

localparam  NW_MAX   = 16;                       // Number of 32-bit dwords handled by a max-width datapath each clock.

// Internal Signals
logic   [DW-1:0]        int_rxdata3             [2:0];
logic                   int_rxdata3_dv          [2:0];
logic                   int_search_for_tokens   [2:0];
logic                   int_accept_eds_cycle    [2:0];
logic   [NW-1:0]        int_raw_eds             [2:1]; // SV: "logic" type useful to have one declaration when the elements of the array can be of different type reg/wire
logic   [NW-1:0]        int_raw_sdp             [2:1];
logic   [NW-1:0]        int_raw_stp             [2:1];
logic   [NW*2-1:0]      int_raw_stp_err         [2:1];
logic   [NW*4-1:0]      int_raw_stp_first_t     [2:1];
logic   [NW*9-1:0]      int_raw_stp_first_t_cnt [2:1];
logic   [NW-1:0]        int_raw_idl             [2:1];
logic   [NW-1:0]        int_raw_edb             [2:1];
logic   [NW-1:0]        int_raw_aedb            [2:1]; // edb token decoded one dword earlier
logic   [DW-1:0]        int_rxdata3_next;
logic   [NW_MAX-1:0]    accept_eds;
reg     [NW_MAX-1:0]    accept_stp_sdp;
wire    [4:0]           link_mode;
reg     [4:0]           link_mode_d;
wire    [4:0]           active_sym;
logic   [2:0]           active_qdw;              // 1,2 or 4, number of currently active quad-dwords (128 bits), f(link_mode, active_nb)
reg     [2:0]           qdw_cnt;
reg     [NW/4-1:0]      token_idl;
reg     [AW-1:0]        rcvd_idle_cnt;
wire                    all_lane_rcvd_idle;
reg     [1:0]           eds_rcvd;
reg     [1:0]           eds_exp;
wire                    eds_err;

localparam CWD = 3;                      // Framing error found counter width  
wire                    err_found;       // Framing error was detected. The pipeline must be flushed.
reg     [CWD-1:0]       err_found_cnt;   // Framing error found counter
wire                    err_found_set;   // Framing error found set condition

wire                    deskew_pkt_err;
wire                    pkt_in_progress;
logic   [AW-1:0]        int_active_nb;

// state information for the chain of 128b decoders
logic   [(NW/4)*4-1:0]  int_first_t_state;
logic   [(NW/4)*9-1:0]  int_first_t_cnt_state;
logic   [(NW/4)-1:0]    int_tlp_pending_state;
logic   [(NW/4)-1:0]    int_dllp_pending_state;
logic   [(NW/4)-1:0]    int_edb_pending_state;
logic   [(NW/4)*4-1:0]  int_first_t_next_state;
logic   [(NW/4)*9-1:0]  int_first_t_cnt_next_state;
logic   [(NW/4)-1:0]    int_tlp_pending_next_state;
logic   [(NW/4)-1:0]    int_dllp_pending_next_state;
logic   [(NW/4)-1:0]    int_edb_pending_next_state;
logic   [(NW/4)-1:0]    int_eds_rcvd_next_state;

wire                    pkt_dv;
wire  [NW-1:0]          dllp_start;
wire  [NW-1:0]          tlp_start;
wire  [NW-1:0]          pkt_end;
wire  [NW-1:0]          pkt_edb;
wire  [DW-1:0]          pkt_data;
wire  [NW-1:0]          pkt_err;
wire  [NW/4-1:0]        pkt_idl;
reg   [NW-1:0]          int_pkt_err;
reg                     pkt_dv_r;
reg   [NW-1:0]          dllp_start_r;
reg   [NW-1:0]          tlp_start_r;
reg   [NW-1:0]          pkt_end_r;
reg   [NW-1:0]          pkt_edb_r;
reg   [DW-1:0]          pkt_data_r;
reg   [NW-1:0]          pkt_err_r;
reg   [NW/4-1:0]        pkt_idl_r;
wire  [NW*5-1:0]        pkt_err_ptr;
reg   [NW*5-1:0]        int_pkt_err_ptr;
reg   [NW*5-1:0]        pkt_err_ptr_r;


assign link_mode       = (NL==16) ?           smlh_link_mode[4:0]  :
                         (NL==8)  ? {1'b0   , smlh_link_mode[3:0]} :
                         (NL==4)  ? {2'b00  , smlh_link_mode[2:0]} :
                         (NL==2)  ? {3'b000 , smlh_link_mode[1:0]} :
                                     5'b00001;

// Note this module is not used in Gen6, so use CX_GEN45_DYNAMIC_WIDTH instead of CX_GEN456_DYNAMIC_WIDTH to figure-out if the s-ness is constant
// And use CX_NB_GEN3 (istead of CX_NB) because CX_NB might be higher than the s-ness at Gen3/Gen4/Gen5
// In CXL mode use CX_NB as we always accumulate the fill datapath
assign int_active_nb = cxl_mode_enable ? ( `CX_NB) :  `CX_NB_GEN3;

assign active_sym[AW-1:0] = 
                         (int_active_nb==8) ? `CX_8S :
                         (int_active_nb==4) ? `CX_4S :
                         (int_active_nb==2) ? `CX_2S : `CX_1S;
assign active_sym[4] = 1'b0;

generate
if (CXL_TOKEN_SER==1) begin : gen_qdw_ser
    // we are expecting 512 datawidth active_qdw is always 3'h4
    assign active_qdw = 3'h4;
end else begin : gen_qdw  //CXL_TOKEN_SER==0
    always @(*) begin : active_qdw_comb_PROC
        case( {active_sym[4:0], link_mode[4:0]}  )

            // 512b 4 qdw (16dw) datapath
            10'b00100_10000 /* 4sx16 */ : active_qdw = 3'h4;
            10'b01000_01000 /* 8sx8  */ : active_qdw = 3'h4;

            // 256b 2 qdw (8dw) datapath
            10'b00010_10000 /* 2sx16 */ : active_qdw = 3'h2;
            10'b00100_01000 /* 4sx8  */ : active_qdw = 3'h2;
            10'b01000_00100 /* 8sx4  */ : active_qdw = 3'h2;

            // 128b 1 qdw (4dw) datapath
            10'b00010_01000 /* 2sx8  */ : active_qdw = 3'h1;
            10'b00100_00100 /* 4sx4  */ : active_qdw = 3'h1;

            default
            /* cases not handled by token_finder4 */ : active_qdw = 3'h0;
        endcase            
    end
end
endgenerate


always @(posedge core_clk or negedge core_rst_n) begin : link_mode_seq_PROC
    if( !core_rst_n ) begin
        link_mode_d     <= #TP 0;
    end else begin
        link_mode_d     <= #TP link_mode;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : qdw_cnt_seq_PROC
    if( !core_rst_n )
        qdw_cnt  <= #TP 0;
    else if (link_mode != link_mode_d )  // Reset count when link_mode changes
        qdw_cnt  <= #TP 0;
    else if (pkt_dv|eds_err)
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        qdw_cnt  <= #TP qdw_cnt + active_qdw[2:0]; // Count q-DWs received
// spyglass enable_block W164a
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


// stage 0
always @(*) begin : rxdata3_comb_PROC
    int_rxdata3[0]           = rxdata3[DW-1:0];
    int_rxdata3_dv[0]        = rxdata3_dv;
    int_search_for_tokens[0] = search_for_tokens;
    int_accept_eds_cycle[0]  = accept_eds_cycle;
end

// register stage 1 and 2
always @(posedge core_clk or negedge core_rst_n) begin : rxdata3_seq_PROC
    integer i;
    if( !core_rst_n ) begin
        for(i=1; i<=2; i=i+1) begin
            int_rxdata3[i]           <= #TP 0;
            int_rxdata3_dv[i]        <= #TP 0;
            int_search_for_tokens[i] <= #TP 0;
            int_accept_eds_cycle[i]  <= #TP 0;
        end
    end else begin
        // Register Stage 1
        if(int_search_for_tokens[2] && !int_search_for_tokens[0]) begin
            int_rxdata3[1]           <= #TP 32'h0;
            int_rxdata3_dv[1]        <= #TP 1'b1;
            int_search_for_tokens[1] <= #TP 1'b0;
            int_accept_eds_cycle[1]  <= #TP 1'b0;
        end else if(int_rxdata3_dv[0]) begin
            int_rxdata3[1]           <= #TP int_rxdata3[0];
            int_rxdata3_dv[1]        <= #TP int_rxdata3_dv[0];
            int_search_for_tokens[1] <= #TP int_search_for_tokens[0];
            int_accept_eds_cycle[1]  <= #TP int_accept_eds_cycle[0];
        end
        // Register Stage 2
        if (int_rxdata3_dv[0] && int_rxdata3_dv[1]) begin
            int_rxdata3[2]           <= #TP int_rxdata3[1];
            int_rxdata3_dv[2]        <= #TP int_rxdata3_dv[1];
            int_search_for_tokens[2] <= #TP int_search_for_tokens[1];
            int_accept_eds_cycle[2]  <= #TP int_accept_eds_cycle[1];
        end else begin
            // If next DW has not been registered but current DW
            // has been processed then discard data
          //int_rxdata3[2]            <= #TP 0; removed for clock gating
            int_rxdata3_dv[2]        <= #TP 0;
            int_search_for_tokens[2] <= #TP int_search_for_tokens[1];
            int_accept_eds_cycle[2]  <= #TP int_accept_eds_cycle[1];
        end
   end
end

// assemble a DW wide data vector shifting in the next 32bits
generate
if (CXL_TOKEN_SER==1) begin : gen_int_rxdata3_ser
    assign int_rxdata3_next = {int_rxdata3[1][31:0], int_rxdata3[2][512-1:32]};
end else begin : gen_int_rxdata3
    always @(*) begin : int_rxdata3_next_PROC
        int_rxdata3_next = 0;
        if( active_qdw == 3'h4) begin
            int_rxdata3_next = {{DW-512{1'b0}}, int_rxdata3[1][31:0], int_rxdata3[2][512-1:32]};
        end else
        if( active_qdw == 3'h2) begin
            int_rxdata3_next = {{DW-256{1'b0}}, int_rxdata3[1][31:0], int_rxdata3[2][256-1:32]};
        end else
            int_rxdata3_next = {{DW-128{1'b0}}, int_rxdata3[1][31:0], int_rxdata3[2][128-1:32]};
    end

end // (CXL_TOKEN_SER==1)
endgenerate


always @(posedge core_clk or negedge core_rst_n) begin : accept_stp_sdp_eds_seq_PROC
    if( !core_rst_n ) begin
        {accept_stp_sdp, accept_eds} <= #TP 0;
    end else begin
        {accept_stp_sdp, accept_eds} <= #TP calc_accept_stp_sdp_eds(active_sym, link_mode);
    end
end

typedef struct packed {
    reg                     raw_eds;
    reg                     raw_sdp;
    reg                     raw_stp;
    reg    [1:0]            raw_stp_err;
    reg    [3:0]            raw_stp_first_t;     // position of the first token after the end of the tlp in the 128b datapath
    reg    [8:0]            raw_stp_first_t_cnt; // how many 128b cycles before reaching the end of tlp to find the first token after
    reg                     raw_idl;
    reg                     raw_edb;
} raw_dec_32b_op_t;

genvar nw;
// instantiate the 32b raw decoders
generate for (nw=0; nw<NW; nw = nw+1)
    begin : gen_rplh_token_finder4_32b_raw_dec
        raw_dec_32b_op_t op;
// spyglass disable_block STARC05-2.1.3.1
// SMD: Bit-width mismatch between function call argument and function input
// SJ: The result of (nw % 4) can be represented over 2 bits
        assign op = rplh_token_finder4_32b_raw_dec( 
            // ---- inputs ---------------
            .dwnum_128b             (nw % 4) ,
            .data                   (int_rxdata3[1][32*nw +: 32])
        );
// spyglass enable_block STARC05-2.1.3.1
            // ---- outputs ---------------
        assign int_raw_eds[1][nw] =                    op.raw_eds;
        assign int_raw_sdp[1][nw] =                    op.raw_sdp;
        assign int_raw_stp[1][nw] =                    op.raw_stp;
        assign int_raw_stp_err[1][2*nw +: 2] =         op.raw_stp_err;
        assign int_raw_stp_first_t[1][4*nw +: 4] =     op.raw_stp_first_t;
        assign int_raw_stp_first_t_cnt[1][9*nw +: 9] = op.raw_stp_first_t_cnt;
        assign int_raw_idl[1][nw] =                    op.raw_idl;
        assign int_raw_edb[1][nw] =                    op.raw_edb;
    end
endgenerate // gen_rplh_token_finder4_32b_raw_dec

// interconnect for aedb
always @(*) begin : int_raw_aedb_interconnect_PROC
    integer i;
    reg   [NW-1:0]        tmp_raw_aedb;// to avoid "Case statement without default clause and not all cases are covered" lint warnings

    // interconnect for aedb 0..NW-2
    for(i=0; i<NW-1; i=i+1) begin
        tmp_raw_aedb[i] = int_raw_edb[1][i+1];
    end

    // ... and logic to generate aedb from previous stage
    tmp_raw_aedb[NW-1] = (int_rxdata3[0][31:0] == `EDB_32B);

    // ... and logic to generate aedb from previous stage
    case ( active_qdw)
        3'h2: tmp_raw_aedb[4*2-1] = (int_rxdata3[0][31:0] == `EDB_32B);
        3'h1: tmp_raw_aedb[4*1-1] = (int_rxdata3[0][31:0] == `EDB_32B);
        default: tmp_raw_aedb[NW-1] = (int_rxdata3[0][31:0] == `EDB_32B);
    endcase

    int_raw_aedb[1] = tmp_raw_aedb;
end

// register stage 2 for raw decodes
always @(posedge core_clk or negedge core_rst_n) begin : raw_seq_PROC
    if( !core_rst_n ) begin
        int_raw_eds[2]             <= #TP 0;
        int_raw_sdp[2]             <= #TP 0;
        int_raw_stp[2]             <= #TP 0;
        int_raw_stp_err[2]         <= #TP 0;
        int_raw_stp_first_t[2]     <= #TP 0;
        int_raw_stp_first_t_cnt[2] <= #TP 0;
        int_raw_idl[2]             <= #TP 0;
        int_raw_edb[2]             <= #TP 0;
        int_raw_aedb[2]            <= #TP 0;
    end else begin
        // Register Stage 2
        int_raw_eds[2]             <= #TP int_raw_eds[1] & accept_eds[NW-1:0] & {NW{int_accept_eds_cycle[1]}};
        int_raw_sdp[2]             <= #TP int_raw_sdp[1];
        int_raw_stp[2]             <= #TP int_raw_stp[1];
        int_raw_stp_err[2]         <= #TP int_raw_stp_err[1];
        int_raw_stp_first_t[2]     <= #TP int_raw_stp_first_t[1];
        int_raw_stp_first_t_cnt[2] <= #TP int_raw_stp_first_t_cnt[1];
        int_raw_idl[2]             <= #TP int_raw_idl[1];
        int_raw_edb[2]             <= #TP int_raw_edb[1];
        int_raw_aedb[2]            <= #TP int_raw_aedb[1];
   end
end

wire [NW-1:0] prd_raw_aedb; // edb token decoded one dword earlier, overwritten in pipeline prediction mode
wire          predict_en;   // Predictor mode enabled
typedef enum logic [1:0] {
  PRD_IDL,
  PRD_PREP, // During this cycle data from stage 1 is processed and raw tokens get stored in stage 2
  PRD_RDY,  // Stage 2 is ready and nothing received. In this cycle is possible to predict the status of the pipeline
  PRD_DONE  // No more prediction until new data enter the pipeline
} prd_t;

generate if (PREDICTOR==1)
    begin : gen_pipeline_predictor_enabled
        // Pipeline predictor mode aims detecting the status of the pipeline.
        // The goal is to figure out if there is an incomplete packet ongoing, if not the pipeline can be flushed.
        // Prediction is possible only on the second contiguous cycle without valid data received in the input.

        prd_t prd_state;
        prd_t prd_prev_state;
        
        always_comb begin : predictor_state_comb_PROC
            prd_state = PRD_IDL;
            case(prd_prev_state)
                PRD_IDL  : if (search_for_tokens && !rxdata3_dv) prd_state = PRD_PREP;
                PRD_PREP : if (search_for_tokens && !rxdata3_dv) prd_state = PRD_RDY;
                PRD_RDY  : if (search_for_tokens && !rxdata3_dv) prd_state = PRD_DONE;
                PRD_DONE : if (search_for_tokens && !rxdata3_dv) prd_state = PRD_DONE;
                default  : prd_state = PRD_DONE;
            endcase
        end

        always @(posedge core_clk or negedge core_rst_n) begin : predictor_prev_state_seq_PROC
            if( !core_rst_n ) begin
                prd_prev_state <= #TP PRD_IDL;
            end else begin
                prd_prev_state <= #TP prd_state;
            end
        end

        assign predict_en = prd_state == PRD_RDY;

        // During predition, emulate aEDB token on DW[NW-1]. 
        // This is to inhibit the flush in case of a TLP ending in DW[NW-1].
        // In this case it is not possible to figure out if the TLP is good (and complete) or nullified (EDB token will follow), we must wait for the next data valid.
        assign prd_raw_aedb = {(int_raw_aedb[2][NW-1] | predict_en), int_raw_aedb[2][NW-2:0]};

        assign no_pkt_in_progress = predict_en && !int_tlp_pending_next_state[(NW/4)-1] && !int_dllp_pending_next_state[(NW/4)-1] && !int_edb_pending_next_state[(NW/4)-1];
    end else begin : gen_pipeline_predictor_disabled
        assign predict_en = 0;
        assign prd_raw_aedb = int_raw_aedb[2][NW-1:0];
        assign no_pkt_in_progress = 0;
    end
endgenerate

typedef enum logic [6:0] {
    idl_idl_idl_idl, // token alignment: 128b
    ddd_ddd_stp_idl, // token alignment: 32b
    idl_end_sdp_idl, // token alignment: 32b
    stp_end_sdp_idl, // token alignment: 32b
    sdp_end_sdp_idl, // token alignment: 32b
    ddd_stp_idl_idl, // token alignment: 64b
    end_sdp_idl_idl, // token alignment: 64b
    stp_idl_idl_idl, // token alignment: 32b
    sdp_idl_idl_idl, // token alignment: 32b
    ddd_ddd_ddd_stp, // token alignment: 128b
    idl_idl_end_sdp, // token alignment: 128b
    stp_idl_end_sdp, // token alignment: 32b
    sdp_idl_end_sdp, // token alignment: 32b
    ddd_stp_end_sdp, // token alignment: 128b
    end_sdp_end_sdp, // token alignment: 128b
    idl_idl_idl_edb, // token alignment: 128b
    ddd_stp_idl_edb, // token alignment: 64b
    end_sdp_idl_edb, // token alignment: 64b
    stp_idl_idl_edb, // token alignment: 32b
    sdp_idl_idl_edb, // token alignment: 32b
    ddd_ddd_stp_edb, // token alignment: 128b
    idl_end_sdp_edb, // token alignment: 128b
    stp_end_sdp_edb, // token alignment: 128b
    sdp_end_sdp_edb, // token alignment: 128b
    ddd_ddd_ddd_ddd, // token alignment: 128b
    end_ddd_ddd_ddd, // token alignment: 128b
    idl_end_ddd_ddd, // token alignment: 128b
    stp_end_ddd_ddd, // token alignment: 128b
    sdp_end_ddd_ddd, // token alignment: 128b
    edb_end_ddd_ddd, // token alignment: 128b
    idl_idl_end_ddd, // token alignment: 128b
    stp_idl_end_ddd, // token alignment: 32b
    sdp_idl_end_ddd, // token alignment: 32b
    ddd_stp_end_ddd, // token alignment: 128b
    end_sdp_end_ddd, // token alignment: 128b
    idl_edb_end_ddd, // token alignment: 128b
    stp_edb_end_ddd, // token alignment: 128b
    sdp_edb_end_ddd, // token alignment: 128b
    idl_idl_idl_end, // token alignment: 128b
    ddd_stp_idl_end, // token alignment: 64b
    end_sdp_idl_end, // token alignment: 64b
    stp_idl_idl_end, // token alignment: 32b
    sdp_idl_idl_end, // token alignment: 32b
    ddd_ddd_stp_end, // token alignment: 128b
    idl_end_sdp_end, // token alignment: 128b
    stp_end_sdp_end, // token alignment: 128b
    sdp_end_sdp_end, // token alignment: 128b
    idl_idl_edb_end, // token alignment: 128b
    stp_idl_edb_end, // token alignment: 32b
    sdp_idl_edb_end, // token alignment: 32b
    ddd_stp_edb_end, // token alignment: 128b
    end_sdp_edb_end, // token alignment: 128b
    xxx_xxx_xxx_idl, // token alignment: 128b
    xxx_xxx_idl_idl, // token alignment: 128b
    xxx_idl_idl_idl, // token alignment: 128b
    xxx_end_sdp_idl, // token alignment: 32b
    xxx_xxx_xxx_edb, // token alignment: 128b
    xxx_xxx_idl_edb, // token alignment: 128b
    xxx_idl_idl_edb, // token alignment: 128b
    xxx_end_sdp_edb, // token alignment: 128b
    xxx_xxx_end_sdp, // token alignment: 128b
    xxx_idl_end_sdp, // token alignment: 128b
    xxx_xxx_xxx_etp, // token alignment: 128b (tlp end)
    xxx_xxx_xxx_edp, // token alignment: 128b (dllp end)
    xxx_xxx_idl_end, // token alignment: 128b
    xxx_idl_idl_end, // token alignment: 128b
    xxx_xxx_edb_end, // token alignment: 128b
    xxx_idl_edb_end, // token alignment: 128b
    xxx_end_sdp_end, // token alignment: 128b
    xxx_xxx_end_ddd, // token alignment: 128b
    xxx_idl_end_ddd, // token alignment: 128b
    xxx_edb_end_ddd, // token alignment: 128b
    xxx_end_ddd_ddd, // token alignment: 128b
    xxx_xxx_xxx_xxx, // token alignment: 128b
    unknown
} dec_128b_case_t;

typedef struct packed {
    reg [3:0]           first_t_state;
    reg [8:0]           first_t_cnt_state;
    reg                 tlp_pending_state;
    reg                 dllp_pending_state;
    reg                 edb_pending_state;
    reg [31:0]          next_data_in;
    reg [4*32-1:0]      data_in;
    reg [3:0]           raw_eds;
    reg [3:0]           raw_sdp;
    reg [3:0]           raw_stp;
    reg [2*4-1:0]       raw_stp_err;
    reg [4*4-1:0]       raw_stp_first_t;
    reg [4*9-1:0]       raw_stp_first_t_cnt;
    reg [3:0]           raw_idl;
    reg [3:0]           raw_edb;
    reg [3:0]           raw_aedb;
    reg [3:0]           accept_stp_sdp;
} dec_128b_ip_t;

typedef struct packed {
    reg [3:0]           first_t_next_state;
    reg [8:0]           first_t_cnt_next_state;
    reg                 tlp_pending_next_state;
    reg                 dllp_pending_next_state;
    reg                 edb_pending_next_state;
    reg                 eds_rcvd_next_state;
    reg [3:0]           framing_err_next_state;
    reg [3:0]           dllp_start;
    reg [3:0]           tlp_start;
    reg [3:0]           pkt_end;
    reg [3:0]           pkt_edb;
    reg [4*32-1:0]      pkt_data;
    reg [3:0]           pkt_err;
    reg [5*4-1:0]       pkt_err_ptr;
    reg                 pkt_idl;
    dec_128b_case_t     dec_case;
} dec_128b_op_t;

// instantiate the 128b token decoders
generate for (nw=0; nw<NW/4; nw = nw+1)
    begin : gen_dec_128b

        dec_128b_ip_t    ip;
        dec_128b_op_t    op;
        dec_128b_case_t  dec_case; // used only for debug

        assign op = rplh_token_finder4_128b_dec (ip);

            // ---- inputs ---------------
            assign ip.first_t_state                      = int_first_t_state[4*nw +: 4];
            assign ip.first_t_cnt_state                  = int_first_t_cnt_state[9*nw +: 9];
            assign ip.tlp_pending_state                  = int_tlp_pending_state[nw];
            assign ip.dllp_pending_state                 = int_dllp_pending_state[nw];
            assign ip.edb_pending_state                  = int_edb_pending_state[nw];
//          assign ip.next_data_in                       = int_rxdata3_next[128*nw +: 32];
            assign ip.next_data_in                       = int_rxdata3_next[128*(nw+1)-1 -: 32];
            assign ip.data_in                            = int_rxdata3[2][128*nw +: 128];
            assign ip.raw_eds                            = int_raw_eds[2][4*nw +: 4];
            assign ip.raw_sdp                            = int_raw_sdp[2][4*nw +: 4];
            assign ip.raw_stp                            = int_raw_stp[2][4*nw +: 4];
            assign ip.raw_stp_err                        = int_raw_stp_err[2][2*4*nw +: 2*4];
            assign ip.raw_stp_first_t                    = int_raw_stp_first_t[2][4*4*nw +: 4*4];
            assign ip.raw_stp_first_t_cnt                = int_raw_stp_first_t_cnt[2][9*4*nw +: 9*4];
            assign ip.raw_idl                            = int_raw_idl[2][4*nw +: 4];
            assign ip.raw_edb                            = int_raw_edb[2][4*nw +: 4];
            assign ip.raw_aedb                           = prd_raw_aedb[4*nw +: 4];
            assign ip.accept_stp_sdp                     = accept_stp_sdp[4*nw +: 4];
            // ---- outputs ---------------
            assign int_first_t_next_state[4*nw +: 4]     = op.first_t_next_state;
            assign int_first_t_cnt_next_state[9*nw +: 9] = op.first_t_cnt_next_state;
            assign int_tlp_pending_next_state[nw]        = op.tlp_pending_next_state;
            assign int_dllp_pending_next_state[nw]       = op.dllp_pending_next_state;
            assign int_edb_pending_next_state[nw]        = op.edb_pending_next_state;
            assign int_eds_rcvd_next_state[nw]           = op.eds_rcvd_next_state;
//          assign                                       = op.framing_err_next_state;
            assign dllp_start[4*nw +: 4]                 = op.dllp_start;
            assign tlp_start[4*nw +: 4]                  = op.tlp_start;
            assign pkt_end[4*nw +: 4]                    = op.pkt_end;
            assign pkt_edb[4*nw +: 4]                    = op.pkt_edb;
            assign pkt_data[128*nw +: 128]               = op.pkt_data;
            assign pkt_err[4*nw +: 4]                    = op.pkt_err;
            assign pkt_err_ptr[4*5*nw +: 4*5]            = op.pkt_err_ptr;
            assign pkt_idl[nw]                           = op.pkt_idl;
            assign dec_case                              = op.dec_case;

    end
endgenerate // gen_dec_128b

// connect the next state outputs to the state inputs of next 128b decoder in the chain
generate for (nw=1; nw<(NW/4); nw = nw+1)
    begin : gen_int_state
        assign int_first_t_state[4*nw +: 4] = int_first_t_next_state[4*(nw-1) +: 4];
        assign int_first_t_cnt_state[9*nw +: 9] = int_first_t_cnt_next_state[9*(nw-1) +: 9];
        assign int_tlp_pending_state[nw]  = int_tlp_pending_next_state[nw-1];
        assign int_dllp_pending_state[nw] = int_dllp_pending_next_state[nw-1];
        assign int_edb_pending_state[nw]  = int_edb_pending_next_state[nw-1];
    end
endgenerate


// ... and the state register loaded from the next_state from the last 128b decoder
generate 
if (CXL_TOKEN_SER==1) begin : gen_state_seq_cxl
    // CX_RPLH_CXL_TOKEN_SER_ENABLE
    // need to separe out to avoid lint/spyglass warnings, e.g. for 128bit cores index outside range when CX_RPLH_CXL_TOKEN_SER_ENABLE set
always @(posedge core_clk or negedge core_rst_n) begin : state_seq_PROC
    if( !core_rst_n ) begin
        int_first_t_state[4*0 +: 4]     <= #TP 4'b0001;
        int_first_t_cnt_state[9*0 +: 9] <= #TP 0;
        int_tlp_pending_state[0]        <= #TP 0;
        int_dllp_pending_state[0]       <= #TP 0;
        int_edb_pending_state[0]        <= #TP 0;
    end else begin
        if( int_search_for_tokens[2] ) begin
            if( pkt_dv ) begin
                int_first_t_state[4*0 +: 4]     <= #TP int_first_t_next_state[4*(4-1) +: 4];
                int_first_t_cnt_state[9*0 +: 9] <= #TP int_first_t_cnt_next_state[9*(4-1) +: 9];
                int_tlp_pending_state[0]        <= #TP int_tlp_pending_next_state[4-1];
                int_dllp_pending_state[0]       <= #TP int_dllp_pending_next_state[4-1];
                int_edb_pending_state[0]        <= #TP int_edb_pending_next_state[4-1];
            end
        end else begin
            int_first_t_state[4*0 +: 4]     <= #TP 4'b0001;
            int_first_t_cnt_state[9*0 +: 9] <= #TP 0;
            int_tlp_pending_state[0]        <= #TP 0;
            int_dllp_pending_state[0]       <= #TP 0;
            int_edb_pending_state[0]        <= #TP 0;
        end
    end
end
     
end else begin: gen_state_seq //(CXL_TOKEN_SER==0)

always @(posedge core_clk or negedge core_rst_n) begin : state_seq_PROC
    if( !core_rst_n ) begin
        int_first_t_state[4*0 +: 4]     <= #TP 4'b0001;
        int_first_t_cnt_state[9*0 +: 9] <= #TP 0;
        int_tlp_pending_state[0]        <= #TP 0;
        int_dllp_pending_state[0]       <= #TP 0;
        int_edb_pending_state[0]        <= #TP 0;
    end else begin
        if( int_search_for_tokens[2] ) begin
            if( pkt_dv ) begin
                if( active_qdw == 3'h4) begin
                    int_first_t_state[4*0 +: 4]     <= #TP int_first_t_next_state[4*(4-1) +: 4];
                    int_first_t_cnt_state[9*0 +: 9] <= #TP int_first_t_cnt_next_state[9*(4-1) +: 9];
                    int_tlp_pending_state[0]        <= #TP int_tlp_pending_next_state[4-1];
                    int_dllp_pending_state[0]       <= #TP int_dllp_pending_next_state[4-1];
                    int_edb_pending_state[0]        <= #TP int_edb_pending_next_state[4-1];
                end else
                if( active_qdw == 3'h2) begin
                    int_first_t_state[4*0 +: 4]     <= #TP int_first_t_next_state[4*(2-1) +: 4];
                    int_first_t_cnt_state[9*0 +: 9] <= #TP int_first_t_cnt_next_state[9*(2-1) +: 9];
                    int_tlp_pending_state[0]        <= #TP int_tlp_pending_next_state[2-1];
                    int_dllp_pending_state[0]       <= #TP int_dllp_pending_next_state[2-1];
                    int_edb_pending_state[0]        <= #TP int_edb_pending_next_state[2-1];
                end else
                begin
                    int_first_t_state[4*0 +: 4]     <= #TP int_first_t_next_state[4*(1-1) +: 4];
                    int_first_t_cnt_state[9*0 +: 9] <= #TP int_first_t_cnt_next_state[9*(1-1) +: 9];
                    int_tlp_pending_state[0]        <= #TP int_tlp_pending_next_state[1-1];
                    int_dllp_pending_state[0]       <= #TP int_dllp_pending_next_state[1-1];
                    int_edb_pending_state[0]        <= #TP int_edb_pending_next_state[1-1];
                end
            end
        end else begin
            int_first_t_state[4*0 +: 4]     <= #TP 4'b0001;
            int_first_t_cnt_state[9*0 +: 9] <= #TP 0;
            int_tlp_pending_state[0]        <= #TP 0;
            int_dllp_pending_state[0]       <= #TP 0;
            int_edb_pending_state[0]        <= #TP 0;
        end
    end
end

end
endgenerate

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// create outputs
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign pkt_dv = int_rxdata3_dv[2];


always @(*) begin : decode_pkt_err
    integer i;
    int_pkt_err = 0;

    // If a one of the rplh_token_finder4_128b_dec units reports pkt_err,
    // set pkt_err for all subsequent rplh_token_finder4_128b_dec units
    for (i=0; i<NW; i=i+1) begin
        if(i==0)
            int_pkt_err[0] = pkt_err[0] | (pkt_err_r[NW-1] & ~pkt_dv_r) | deskew_pkt_err | eds_err;
        else
            int_pkt_err[i] = pkt_err[i] | int_pkt_err[i-1];
    end
end
always @(*) begin : decode_pkt_err_ptr
    integer i;
    reg   [NW*5-1:0]  int_pkt_err_ptr_temp;
    int_pkt_err_ptr_temp = 0;
    int_pkt_err_ptr = 0;

    // If a one of the rplh_token_finder4_128b_dec units reports pkt_err,
    // set pkt_err for all subsequent rplh_token_finder4_128b_dec units
    for (i=0; i<NW; i=i+1) begin
        if(i==0)
            int_pkt_err_ptr_temp[i*5+:5] = pkt_err_ptr[i*5+:5];
        else
            int_pkt_err_ptr_temp[i*5+:5] = (|pkt_err[i-1]) ? int_pkt_err_ptr_temp[(i-1)*5+:5] : pkt_err_ptr[i*5+:5];
    end
    casez({(pkt_err_r[NW-1] & ~pkt_dv_r), deskew_pkt_err, eds_err})
        3'b1??  : int_pkt_err_ptr = {NW{pkt_err_ptr_r[(NW-1)*5+:5]}};
        3'b01?  : int_pkt_err_ptr = {NW{5'b0_0110}};
        3'b001  : int_pkt_err_ptr = {NW{5'b0_0101}};
        default : int_pkt_err_ptr = int_pkt_err_ptr_temp;
    endcase
end

// Drive outputs based on core datapath width, active number of q-DWs
// and the number of q-DWs currently available
always @(posedge core_clk or negedge core_rst_n) begin : rplh_rdlh_seq_PROC
    if(!core_rst_n) begin
        pkt_data_r                          <= #TP 0;
        dllp_start_r                        <= #TP 0;
        tlp_start_r                         <= #TP 0;
        pkt_end_r                           <= #TP 0;
        pkt_edb_r                           <= #TP 0;
        pkt_err_r                           <= #TP 0;
        pkt_err_ptr_r                       <= #TP 0;
        pkt_idl_r                           <= #TP 0;
        pkt_dv_r                            <= #TP 0;
    end else if(pkt_dv|eds_err) begin
                if (active_qdw == NW/4) begin // All Lanes Active
                    pkt_data_r               <= #TP pkt_data;
                    dllp_start_r             <= #TP err_found ? 0 : dllp_start & ~int_pkt_err;
                    tlp_start_r              <= #TP err_found ? 0 : tlp_start  & ~int_pkt_err;
                    pkt_end_r                <= #TP err_found ? 0 :(pkt_end    & ~int_pkt_err) | {NW{deskew_pkt_err|eds_err}};
                    pkt_edb_r                <= #TP err_found ? 0 : pkt_edb    & ~int_pkt_err;
                    pkt_err_r                <= #TP int_pkt_err;
                    pkt_err_ptr_r            <= #TP int_pkt_err_ptr;
                    pkt_idl_r                <= #TP pkt_idl;
                    pkt_dv_r                 <= #TP 1'b1;
                end
                else if (active_qdw == 2) begin
                    pkt_data_r               <= #TP {                    pkt_data[(128*2)-1:0]                           , pkt_data_r[DW-1:128*2]};
                    dllp_start_r             <= #TP { err_found ? 8'b0 : dllp_start[(4*2)-1:0] & ~int_pkt_err[(4*2)-1:0] , dllp_start_r[NW-1:4*2]};
                    tlp_start_r              <= #TP { err_found ? 8'b0 :  tlp_start[(4*2)-1:0] & ~int_pkt_err[(4*2)-1:0] ,  tlp_start_r[NW-1:4*2]};
                    pkt_end_r                <= #TP { err_found ? 8'b0 :(   pkt_end[(4*2)-1:0] & ~int_pkt_err[(4*2)-1:0]) | {4*2{deskew_pkt_err|eds_err}}, pkt_end_r[NW-1:4*2]};
                    pkt_edb_r                <= #TP { err_found ? 8'b0 :    pkt_edb[(4*2)-1:0] & ~int_pkt_err[(4*2)-1:0] ,    pkt_edb_r[NW-1:4*2]};
                    pkt_err_r                <= #TP {int_pkt_err[(4*2)-1:0]                                              ,    pkt_err_r[NW-1:4*2]};
                    pkt_err_ptr_r            <= #TP {int_pkt_err_ptr[(4*2*5)-1:0]                                        ,    pkt_err_ptr_r[NW*5-1:4*2*5]};
                    pkt_idl_r                <= #TP {    pkt_idl[(1*2)-1:0]                                              ,  pkt_idl_r[NW/4-1:1*2]};
                    pkt_dv_r                 <= #TP (qdw_cnt[1]); // x2 (enabled each two data valid)
                end
                else if (active_qdw == 1) begin
                    pkt_data_r               <= #TP {                    pkt_data[(128*1)-1:0]                           , pkt_data_r[DW-1:128*1]};
                    dllp_start_r             <= #TP { err_found ? 4'b0 : dllp_start[(4*1)-1:0] & ~int_pkt_err[(4*1)-1:0] , dllp_start_r[NW-1:4*1]};
                    tlp_start_r              <= #TP { err_found ? 4'b0 :  tlp_start[(4*1)-1:0] & ~int_pkt_err[(4*1)-1:0] ,  tlp_start_r[NW-1:4*1]};
                    pkt_end_r                <= #TP { err_found ? 4'b0 :(   pkt_end[(4*1)-1:0] & ~int_pkt_err[(4*1)-1:0]) | {4*1{deskew_pkt_err|eds_err}}, pkt_end_r[NW-1:4*1]};
                    pkt_edb_r                <= #TP { err_found ? 4'b0 :    pkt_edb[(4*1)-1:0] & ~int_pkt_err[(4*1)-1:0] ,    pkt_edb_r[NW-1:4*1]};
                    pkt_err_r                <= #TP {                   int_pkt_err[(4*1)-1:0]                           ,    pkt_err_r[NW-1:4*1]};
                    pkt_err_ptr_r            <= #TP {               int_pkt_err_ptr[(4*1*5)-1:0]                    , pkt_err_ptr_r[NW*5-1:4*1*5]};
                    pkt_idl_r                <= #TP {                       pkt_idl[(1*1)-1:0]                           ,  pkt_idl_r[NW/4-1:1*1]};
                    pkt_dv_r                 <= #TP (NW/4 == 2) ? qdw_cnt[0] : (qdw_cnt[1:0] == 2'h3); // x2 or x4 (enabled when qdw_cnt is 3 or 7)
                end
    end else begin
                    pkt_dv_r                 <= #TP 0;
    end
end

// If pkt_in_progress is HIGH and int_search_for_tokens goes LOW, this
// indicates that a framing error has been detected in the deskew block
// while a packet has been in progress in token_finder. Used to enable
// int_pkt_err to indicate framing error. pkt_end will be enabled to
// terminate the packet in progress and no more packets will be passed 
// to Layer2
assign  pkt_in_progress = int_tlp_pending_state[0] | int_dllp_pending_state[0] | int_edb_pending_state[0];
assign  deskew_pkt_err  = pkt_in_progress && !int_search_for_tokens[2];

assign  rplh_rdlh_pkt_dv      = pkt_dv_r;
assign  rplh_rdlh_pkt_data    = { {DW_ORG-DW{1'b0}}, pkt_data_r   [DW-1:0]};
assign  rplh_rdlh_dllp_start  = { {NW_ORG-NW{1'b0}}, dllp_start_r [NW-1:0]};
assign  rplh_rdlh_tlp_start   = { {NW_ORG-NW{1'b0}}, tlp_start_r  [NW-1:0]};
assign  rplh_rdlh_pkt_end     = { {NW_ORG-NW{1'b0}}, pkt_end_r    [NW-1:0]};
assign  rplh_rdlh_pkt_edb     = { {NW_ORG-NW{1'b0}}, pkt_edb_r    [NW-1:0]};
assign  rplh_rdlh_pkt_err     = { {NW_ORG-NW{1'b0}}, pkt_err_r    [NW-1:0]};
assign  rplh_rdlh_pkt_err_ptr = { {(NW_ORG-NW)*5{1'b0}}, pkt_err_ptr_r};

// idle cnt
always @(*) begin : token_idl_PROC
    integer i;
    token_idl = {NW/4{1'b1}};
    for(i=0; i<NW/4; i=i+1) begin
        if(i<active_qdw)
            token_idl[i] = pkt_idl[i] && (pkt_err[4*i +: 4] == 0);
    end
end

assign all_lane_rcvd_idle = &token_idl;  // All Lanes detected IDL

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
            rcvd_idle_cnt <= #TP rcvd_idle_cnt + active_sym[AW-1:0];
// spyglass enable_block W164a
        end else begin
            rcvd_idle_cnt <= #TP 0;
        end
    end
end

assign rplh_rcvd_idle[1] = (rcvd_idle_cnt != 0);
assign rplh_rcvd_idle[0] = (rcvd_idle_cnt >= 8);

// The EDS logic used below has been reused from token_finder_3
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
    else begin
        eds_rcvd <= #TP {eds_rcvd[0], ((|int_eds_rcvd_next_state) & pkt_dv)};
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


   function automatic [NW_MAX*2-1:0] calc_accept_stp_sdp_eds(input [4:0] active_sym, input [4:0] link_mode);
        reg [NW_MAX-1:0] i_accept_stp_sdp, i_accept_eds;
        begin
            // Every the bit of i_accept_stp_sdp related with unused decoders (because of partial datapath) is intentionally disabled. 
            // The intent is to support tools detecting unnecessary logic.
            //if (CXL_TOKEN_SER==1) begin : gen_acc_sdp_ser   // leave commented in case we run into problems 
            //        // 512b 16DW 4qDW datapath, implicit CX_RPLH_CXL_TOKEN_SER_ENABLE
            //        i_accept_stp_sdp = 16'b1111_1111_1111_1111; // here we are not doing framing checks by using 1111_1111_1111_1111
            //        i_accept_eds = 16'b0000_0000_0000_0000;     // eds tokens are not used in CXL, flits with implied EDS are used instead
            //end else begin : gen_acc_sdp
                case( {active_sym[4:0], link_mode[4:0]}  )
                    // 512b 16DW 4qDW datapath
                    10'b00100_10000 /* 4sx16*/ : begin i_accept_stp_sdp = 16'b0001_0001_0001_0001; i_accept_eds = 16'b1000_1000_1000_1000; end
                    10'b01000_01000 /* 8sx8 */ : begin i_accept_stp_sdp = 16'b0101_0101_0101_0101; i_accept_eds = 16'b1000_1000_1000_1000; end

                    // 256b 8DW 2qDW datapath
                    10'b00010_10000 /* 2sx16*/ : begin i_accept_stp_sdp = 16'b0000_0000_0001_0001; i_accept_eds = 16'b0000_0000_1000_1000; end
                    10'b00100_01000 /* 4sx8 */ : begin i_accept_stp_sdp = 16'b0000_0000_0101_0101; i_accept_eds = 16'b0000_0000_1000_1000; end
                    10'b01000_00100 /* 8sx4 */ : begin i_accept_stp_sdp = 16'b0000_0000_1111_1111; i_accept_eds = 16'b0000_0000_1000_1000; end

                    // 128b 4DW 1qDW datapath
                    10'b00010_01000 /* 2sx8 */ : begin i_accept_stp_sdp = 16'b0000_0000_0000_0101; i_accept_eds = 16'b0000_0000_0000_1000; end
                    10'b00100_00100 /* 4sx4 */ : begin i_accept_stp_sdp = 16'b0000_0000_0000_1111; i_accept_eds = 16'b0000_0000_0000_1000; end
                                    // 8sx2  Handled by token finder 3

                    default
                    // 64b 2DW datapath
                          /* 1sx8 */
                          /* 2sx4 */
                          /* 4sx2 */
                          /* 8sx1 */

                    // 32b 1DW datapath
                          /* 1sx4 */
                          /* 2sx2 */
                          /* 4sx1 */
                    // 16b 0.5DW datapath
                          /* 1sx2 */
                          /* 2sx1 */
                    // 8b 0.25DW datapath
                          /* 1sx1 */    : begin i_accept_stp_sdp = 16'b0000_0000_0000_0000; i_accept_eds = 16'b0000_0000_0000_0000; end
                endcase
            //end //gen_acc_sdp
            calc_accept_stp_sdp_eds = {i_accept_stp_sdp, i_accept_eds};
        end
    endfunction





// Assert a flag to indicate if the 32b data matches the definition of a token. In case of stp also process
// the tlp length fields to extract the position where to search the first token after the end of the tlp.
function automatic raw_dec_32b_op_t rplh_token_finder4_32b_raw_dec (
// ---- inputs ---------------
input   [1:0]           dwnum_128b, // the dwnum over 128b
input   [31:0]          data
);

begin 

    raw_dec_32b_op_t op;

    reg  [3:0] extracted_first_t_128b;
    reg  [8:0] extracted_first_t_cnt_128b;

    reg  [3:0]  data_stp_4b;
    reg  [10:0] data_stp_tlp_len;
    reg  [11:0] data_stp_seq_num;
    reg  [3:0]  data_stp_fcrc;
    reg         data_stp_fp;

// extract the fields from a possible stp
    data_stp_4b      = data[3:0];
    data_stp_tlp_len = {data[14:8], data[7:4]};
    data_stp_seq_num = {data[19:16], data[31:24]};
    data_stp_fcrc    = data[23:20];
    data_stp_fp      = data[15];

    op.raw_stp                  = match_raw_stp(data_stp_4b, data_stp_tlp_len, data_stp_fcrc, data_stp_fp);
    op.raw_stp_err              = match_raw_stp_err(data_stp_4b, data_stp_tlp_len, data_stp_fcrc, data_stp_fp);
    op.raw_stp_first_t          = extract_first_t(dwnum_128b, data_stp_tlp_len);
    op.raw_stp_first_t_cnt      = extract_first_t_cnt(dwnum_128b, data_stp_tlp_len);
    op.raw_sdp                  = (data[15:0] == `SDP_16B);
    op.raw_edb                  = (data[31:0] == `EDB_32B);
    op.raw_idl                  = (data[31:0] == `IDL_32B);
    op.raw_eds                  = (data[31:0] == `EDS_32B);

    rplh_token_finder4_32b_raw_dec = op;
end
endfunction // rplh_token_finder4_32b_raw_dec

// Function returns a 1 when all the fields (except the seq num) match the definition of STP
function automatic match_raw_stp(input [3:0] stp_4b, input [10:0] stp_tlp_len, input [3:0] stp_fcrc, input stp_fp);
    reg [3:0] calc_fcrc;
    reg       calc_fp;
    begin
        calc_fcrc   = get_frame_crc(stp_tlp_len);     // Calculate Frame CRC based on STP TLP Length
        calc_fp     = get_frame_parity(stp_tlp_len);  // Calculate Frame Parity based on STP TLP Length
        match_raw_stp = (stp_4b == `STP_4B) && (stp_fcrc == calc_fcrc) && (stp_fp == calc_fp) && (stp_tlp_len >=  `CX_GEN3_MIN_TLP_LEN);
    end
endfunction

// Function returns 1(crc err),2(parity err),3(length err) when all the fields (except the seq num) match the definition of STP
function automatic [1:0] match_raw_stp_err(input [3:0] stp_4b, input [10:0] stp_tlp_len, input [3:0] stp_fcrc, input stp_fp);
    reg [3:0] calc_fcrc;
    reg       calc_fp;
    begin
        calc_fcrc   = get_frame_crc(stp_tlp_len);     // Calculate Frame CRC based on STP TLP Length
        calc_fp     = get_frame_parity(stp_tlp_len);  // Calculate Frame Parity based on STP TLP Length
        if(stp_4b == `STP_4B)
          match_raw_stp_err = 
                              (stp_fcrc != calc_fcrc)               ? 2'b01 :
                              (stp_fp   != calc_fp)                 ? 2'b10 :
                              (stp_tlp_len < `CX_GEN3_MIN_TLP_LEN)  ? 2'b11 : 2'b00;
        else
          match_raw_stp_err = 2'b00;
    end
endfunction

// Return a one hot indication to find the first token after the end of this tlp,
// knowing that this tlp started at a given dwnum and it has a given dword length
function automatic [3:0] extract_first_t(input [1:0] dwnum_128b, input [10:0] stp_tlp_len);
    reg [11:0] first_t_dwnum_12b;
    reg [1:0] first_t_dwnum;
    begin
        first_t_dwnum_12b = (stp_tlp_len + {10'b0,dwnum_128b});
        // the lower two bits represent the 128b dw number of the first token after the end of this tlp
        first_t_dwnum = first_t_dwnum_12b[1:0];
        // convert the binary dwnum into one hot
        extract_first_t = 0;
        unique case (1'b1)
            first_t_dwnum == 0 : extract_first_t[0] = 1'b1;
            first_t_dwnum == 1 : extract_first_t[1] = 1'b1;
            first_t_dwnum == 2 : extract_first_t[2] = 1'b1;
            default            : extract_first_t[3] = 1'b1;
        endcase
    end
endfunction

// Return how many 128b datapath cycles are needed to reach the cycle with the first token after this tlp
function automatic [8:0] extract_first_t_cnt(input [1:0] dwnum_128b, input [10:0] stp_tlp_len);
    reg [11:0] first_t_dwnum_12b;
    begin
        first_t_dwnum_12b = (stp_tlp_len + {10'b0,dwnum_128b});
        // calculate the 128b cycles to reach the end of this tlp, minus one to prepare the value for next 128b word
        extract_first_t_cnt = (first_t_dwnum_12b >> 2) - 1;
    end
endfunction

// Function to calculate Frame CRC based on TLP Length
function automatic [3:0] get_frame_crc;
  input [10:0] L;   // TLP Length
  reg   [3:0]  C;   // CRC

  begin
    C[0] = L[10] ^ L[7] ^ L[6] ^ L[4] ^ L[2] ^ L[1] ^ L[0];
    C[1] = L[10] ^ L[9] ^ L[7] ^ L[5] ^ L[4] ^ L[3] ^ L[2];
    C[2] = L[9]  ^ L[8] ^ L[6] ^ L[4] ^ L[3] ^ L[2] ^ L[1];
    C[3] = L[8]  ^ L[7] ^ L[5] ^ L[3] ^ L[2] ^ L[1] ^ L[0];

    get_frame_crc = C;
  end
endfunction

// Function to calculate Frame Parity based on TLP Length and Frame CRC
function automatic       get_frame_parity;
  input [10:0] L;   // TLP Length
  reg          P;   // Parity

  begin
    // P = L[10] ^ L[9] ^ L[8] ^ L[7] ^ L[6] ^ L[5]
    //   ^ L[4]  ^ L[3] ^ L[2] ^ L[1] ^ L[0]
    //   ^ C[3]  ^ C[2] ^ C[1] ^ C[0];
    // This reduces to :
    P = L[10] ^ L[9] ^ L[8] ^ L[6] ^ L[5] ^ L[2] ^ L[0];

    get_frame_parity = P;
  end
endfunction


// As a function of current state and current raw tokens, decode actual tokens for the current 128b cycle and state for next 128b cycle.
function automatic dec_128b_op_t rplh_token_finder4_128b_dec ( dec_128b_ip_t ip);
begin     
reg  [3:0]           first_t_state;
reg  [8:0]           first_t_cnt_state;
reg                  tlp_pending_state;
reg                  dllp_pending_state;
reg                  edb_pending_state;
reg  [31:0]          next_data_in; // needed to shift packets by one byte to format as Gen1/2
reg  [4*32-1:0]      data_in;
reg  [3:0]           raw_eds;
reg  [3:0]           raw_sdp;
reg  [3:0]           raw_stp;
reg  [2*4-1:0]       raw_stp_err;
reg  [4*4-1:0]       raw_stp_first_t;
reg  [4*9-1:0]       raw_stp_first_t_cnt;
reg  [3:0]           raw_idl;
reg  [3:0]           raw_edb;
reg  [3:0]           raw_aedb;
reg  [3:0]           accept_stp_sdp;  // Indication that STP/SDP tokens may be accepted on these lanes following IDL

dec_128b_op_t op;

reg          raw_idl_eds;
reg  [127:0] int_pkt_data;
reg  [3:0]   tlp_end_state;
reg          dllp_end_state;
reg  [3:0]   tlp_dllp_end_state;
reg          no_pkt_pending_state;
reg          tlp_pending_w_no_tlp_end_state;
reg  [3:0]   valid_raw_stp;  // acceptable raw stp
reg  [3:0]   valid_raw_sdp;  // acceptable raw sdp
reg  [3:0]   not_valid_token1;
reg  [3:0]   not_valid_token2;
reg  [3:0]   not_valid_token3;


first_t_state =             ip.first_t_state;
first_t_cnt_state =         ip.first_t_cnt_state;
tlp_pending_state =         ip.tlp_pending_state;
dllp_pending_state =        ip.dllp_pending_state;
edb_pending_state =         ip.edb_pending_state;
next_data_in =              ip.next_data_in;
data_in =                   ip.data_in;
raw_eds =                   ip.raw_eds;
raw_sdp =                   ip.raw_sdp;
raw_stp =                   ip.raw_stp;
raw_stp_err =               ip.raw_stp_err;
raw_stp_first_t =           ip.raw_stp_first_t;
raw_stp_first_t_cnt =       ip.raw_stp_first_t_cnt;
raw_idl =                   ip.raw_idl;
raw_edb =                   ip.raw_edb;
raw_aedb =                  ip.raw_aedb;
accept_stp_sdp =            ip.accept_stp_sdp;

raw_idl_eds = raw_idl[3]||raw_eds[3];

int_pkt_data = {next_data_in[7:0], data_in[4*32-1:8]}; // www: use only 8 bits from next data for now, for future need 32b to support byte/word alignment

tlp_end_state[3] = first_t_state[0] && first_t_cnt_state==1 && tlp_pending_state;
tlp_end_state[2] = first_t_state[3] && first_t_cnt_state==0 && tlp_pending_state;
tlp_end_state[1] = first_t_state[2] && first_t_cnt_state==0 && tlp_pending_state;
tlp_end_state[0] = first_t_state[1] && first_t_cnt_state==0 && tlp_pending_state;
dllp_end_state   = dllp_pending_state;
tlp_dllp_end_state[0] = tlp_end_state[0] || dllp_end_state;
no_pkt_pending_state = !dllp_pending_state && !tlp_pending_state && !edb_pending_state;
tlp_pending_w_no_tlp_end_state =    ((first_t_cnt_state>1)                        // include all cases where the first token is expected in a cycle after the next cycle, obviously current tlp cannot end in current cycle
                                         || (first_t_cnt_state==1 && !first_t_state[0])) // exclude the case where the first token is expected in dw0 next cycle, which implies current tlp ends in current cycle
                                       && tlp_pending_state;
valid_raw_stp = raw_stp & accept_stp_sdp;
valid_raw_sdp = raw_sdp & accept_stp_sdp;

not_valid_token1 = ~({raw_eds[3],3'b0} | valid_raw_sdp | valid_raw_stp | raw_idl ); // after IDLE
not_valid_token2 = ~({raw_eds[3],3'b0} |       raw_sdp |       raw_stp | raw_idl ); // after DLLP or EDB
not_valid_token3 = ~({raw_eds[3],3'b0} |       raw_sdp |       raw_stp | raw_idl | raw_edb); // after TLP


    op.dec_case = xxx_xxx_xxx_xxx;
    op.framing_err_next_state = 4'b0000;
    op.dllp_pending_next_state = 1'b0;
    op.edb_pending_next_state = 1'b0;
    op.pkt_idl = 1'b0;
    op.first_t_next_state = 4'b0001;
    op.first_t_cnt_next_state = 0;
    op.tlp_pending_next_state = 0;
    op.eds_rcvd_next_state = 1'b0;
    op.tlp_start = 4'b0000;
    unique case ( 1'b1 )
        raw_idl_eds && raw_idl[2] && raw_idl[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  idl_idl_idl_idl;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = raw_eds[3];
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0000;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = int_pkt_data;
                                                                                            op.pkt_idl = raw_idl[3];
                                                                                        end
                               valid_raw_stp[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  ddd_ddd_stp_idl;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*1 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*1 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0010;
                                                                                            op.pkt_end = 4'b0000;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                           format_stp_32b(int_pkt_data[32*1 +: 32], data_in[32*1 +: 32]),
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
                raw_idl_eds && valid_raw_sdp[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  idl_end_sdp_idl;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = raw_eds[3];
                                                                                            op.dllp_start = 4'b0010;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0100;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                                                format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
                 raw_stp[3] && valid_raw_sdp[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  stp_end_sdp_idl;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*3 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*3 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0010;
                                                                                            op.tlp_start = 4'b1000;
                                                                                            op.pkt_end = 4'b0100;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {format_stp_32b(int_pkt_data[32*3 +: 32], data_in[32*3 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
                 raw_sdp[3] && valid_raw_sdp[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  sdp_end_sdp_idl;
                                                                                            op.first_t_next_state = 4'b0010;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.dllp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b1010;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0100;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {                     format_sdp_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
                 valid_raw_stp[2] && raw_idl[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  ddd_stp_idl_idl;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*2 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*2 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0100;
                                                                                            op.pkt_end = 4'b0000;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                           format_stp_32b(int_pkt_data[32*2 +: 32], data_in[32*2 +: 32]),
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
                 valid_raw_sdp[2] && raw_idl[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  end_sdp_idl_idl;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0100;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b1000;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {                     format_end_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
   valid_raw_stp[3] && raw_idl[2] && raw_idl[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  stp_idl_idl_idl;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*3 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*3 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b1000;
                                                                                            op.pkt_end = 4'b0000;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {format_stp_32b(int_pkt_data[32*3 +: 32], data_in[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
   valid_raw_sdp[3] && raw_idl[2] && raw_idl[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  sdp_idl_idl_idl;
                                                                                            op.first_t_next_state =  4'b0010;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.dllp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b1000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0000;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {                     format_sdp_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
                                                   raw_stp[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  ddd_ddd_ddd_stp;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*0 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*0 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0001;
                                                                                            op.pkt_end = 4'b0000;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                           format_stp_32b(int_pkt_data[32*0 +: 32], data_in[32*0 +: 32])};
                                                                                        end
        raw_idl_eds && raw_idl[2]               && raw_sdp[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  idl_idl_end_sdp;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = raw_eds[3];
                                                                                            op.dllp_start = 4'b0001;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0010;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
        valid_raw_stp[3] && raw_idl[2]          && raw_sdp[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  stp_idl_end_sdp;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*3 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*3 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0001;
                                                                                            op.tlp_start = 4'b1000;
                                                                                            op.pkt_end = 4'b0010;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {format_stp_32b(int_pkt_data[32*3 +: 32], data_in[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
        valid_raw_sdp[3] && raw_idl[2]          && raw_sdp[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  sdp_idl_end_sdp;
                                                                                            op.first_t_next_state = 4'b0010;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.dllp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b1001;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0010;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {                     format_sdp_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
                       raw_stp[2]               && raw_sdp[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  ddd_stp_end_sdp;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*2 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*2 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0001;
                                                                                            op.tlp_start = 4'b0100;
                                                                                            op.pkt_end = 4'b0010;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                           format_stp_32b(int_pkt_data[32*2 +: 32], data_in[32*2 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
                       raw_sdp[2]               && raw_sdp[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  end_sdp_end_sdp;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0101;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b1010;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {                     format_end_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
        raw_idl_eds && raw_idl[2] && raw_idl[1] && raw_edb[0] && edb_pending_state    : begin
                                                                                            op.dec_case =  idl_idl_idl_edb;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = raw_eds[3];
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0000;
                                                                                            op.pkt_edb = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data = int_pkt_data; // EDB data is passed unaltered, must be don't care for Layer2 logic
                                                                                        end
                 valid_raw_stp[2] && raw_idl[1] && raw_edb[0] && edb_pending_state    : begin
                                                                                            op.dec_case =  ddd_stp_idl_edb;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*2 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*2 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0100;
                                                                                            op.pkt_end = 4'b0000;
                                                                                            op.pkt_edb = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                           format_stp_32b(int_pkt_data[32*2 +: 32], data_in[32*2 +: 32]),
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
                 valid_raw_sdp[2] && raw_idl[1] && raw_edb[0] && edb_pending_state    : begin
                                                                                            op.dec_case =  end_sdp_idl_edb;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0100;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b1000;
                                                                                            op.pkt_edb = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data = {                     format_end_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
   valid_raw_stp[3] && raw_idl[2] && raw_idl[1] && raw_edb[0] && edb_pending_state    : begin
                                                                                            op.dec_case =  stp_idl_idl_edb;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*3 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*3 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b1000;
                                                                                            op.pkt_end = 4'b0000;
                                                                                            op.pkt_edb = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data = {format_stp_32b(int_pkt_data[32*3 +: 32], data_in[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
   valid_raw_sdp[3] && raw_idl[2] && raw_idl[1] && raw_edb[0] && edb_pending_state    : begin
                                                                                            op.dec_case =  sdp_idl_idl_edb;
                                                                                            op.first_t_next_state = 4'b0010;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.dllp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b1000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0000;
                                                                                            op.pkt_edb = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data = {                     format_sdp_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
                                     raw_stp[1] && raw_edb[0] && edb_pending_state    : begin
                                                                                            op.dec_case =  ddd_ddd_stp_edb;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*1 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*1 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0010;
                                                                                            op.pkt_end = 4'b0000;
                                                                                            op.pkt_edb = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                           format_stp_32b(int_pkt_data[32*1 +: 32], data_in[32*1 +: 32]),
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
        raw_idl_eds &&               raw_sdp[1] && raw_edb[0] && edb_pending_state    : begin
                                                                                            op.dec_case =  idl_end_sdp_edb;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = raw_eds[3];
                                                                                            op.dllp_start = 4'b0010;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0100;
                                                                                            op.pkt_edb = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                                                format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
        raw_stp[3]  &&               raw_sdp[1] && raw_edb[0] && edb_pending_state    : begin
                                                                                            op.dec_case =  stp_end_sdp_edb;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*3 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*3 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0010;
                                                                                            op.tlp_start = 4'b1000;
                                                                                            op.pkt_end = 4'b0100;
                                                                                            op.pkt_edb = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data = {format_stp_32b(int_pkt_data[32*3 +: 32], data_in[32*3 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
        raw_sdp[3]  &&               raw_sdp[1] && raw_edb[0] && edb_pending_state    : begin
                                                                                            op.dec_case =  sdp_end_sdp_edb;
                                                                                            op.first_t_next_state = 4'b0010; // recognize dllp is pending when first token is not in dw0 and there is no tlp pending
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.dllp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b1010;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0100;
                                                                                            op.pkt_edb = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data = {format_sdp_32b(int_pkt_data[32*3 +: 32]),
                                                                                                           format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                           format_sdp_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                          int_pkt_data[32*0 +: 32]}; // www: note: 32b EDB data is don't care for Layer2 logic
                                                                                        end
                                                    tlp_pending_w_no_tlp_end_state    : begin
                                                                                            op.dec_case =  ddd_ddd_ddd_ddd;
                                                                                            op.first_t_next_state = first_t_state;
                                                                                            op.first_t_cnt_next_state = first_t_cnt_state - 1;
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0000;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = int_pkt_data;
                                                                                        end
        tlp_end_state[3]                                                              : begin
                                                                                            op.dec_case =  end_ddd_ddd_ddd;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.edb_pending_next_state = raw_aedb[3];// construct edb_pending to indicate that we should decode edb in next dw
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = {~raw_aedb[3], 3'b000}; // end/edb are mutually exclusive in g12
                                                                                            op.pkt_edb = {raw_aedb[3], 3'b000}; // when the packet ends on dw3 use aedb to determine edb one dw earlier
                                                                                            op.pkt_data = {raw_aedb[3] ?        format_edb_32b(int_pkt_data[32*3 +: 32]) : format_end_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
        raw_idl_eds && tlp_end_state[2]                                               : begin
                                                                                            op.dec_case =  idl_end_ddd_ddd;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = raw_eds[3];
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0100;
                                                                                            op.pkt_edb = 4'b0000;
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                                                format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
        raw_stp[3]  && tlp_end_state[2]                                               : begin
                                                                                            op.dec_case =  stp_end_ddd_ddd;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*3 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*3 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b1000;
                                                                                            op.pkt_end = 4'b0100;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {format_stp_32b(int_pkt_data[32*3 +: 32], data_in[32*3 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
        raw_sdp[3]  && tlp_end_state[2]                                               : begin
                                                                                            op.dec_case =  sdp_end_ddd_ddd;
                                                                                            op.first_t_next_state = 4'b0010; // recognize dllp is pending when first token is not in dw0 and there is no tlp pending
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.dllp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b1000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0100;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {                   format_sdp_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                              format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                             int_pkt_data[32*1 +: 32],
                                                                                                                                             int_pkt_data[32*0 +: 32]};
                                                                                        end
        raw_edb[3]  && tlp_end_state[2]                                               : begin
                                                                                            op.dec_case =  edb_end_ddd_ddd;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0000; // end/edb are mutually exclusive in g12
                                                                                            op.pkt_edb = 4'b0100; // g3 edb found after tlp end, assert g12 edb one dw earlier
                                                                                            op.pkt_data = {                                  int_pkt_data[32*3 +: 32],
                                                                                                                              format_edb_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                             int_pkt_data[32*1 +: 32],
                                                                                                                                             int_pkt_data[32*0 +: 32]};
                                                                                        end
        raw_idl_eds && raw_idl[2] && tlp_end_state[1]                                 : begin
                                                                                            op.dec_case =  idl_idl_end_ddd;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = raw_eds[3];
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0010;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {                                  int_pkt_data[32*3 +: 32],
                                                                                                                                             int_pkt_data[32*2 +: 32],
                                                                                                                              format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                             int_pkt_data[32*0 +: 32]};
                                                                                        end
         valid_raw_stp[3] && raw_idl[2] && tlp_end_state[1]                           : begin
                                                                                            op.dec_case =  stp_idl_end_ddd;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*3 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*3 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b1000;
                                                                                            op.pkt_end = 4'b0010;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = { format_stp_32b(int_pkt_data[32*3 +: 32], data_in[32*3 +: 32]),
                                                                                                                                                int_pkt_data[32*2 +: 32],
                                                                                                                                 format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                                int_pkt_data[32*0 +: 32]};
                                                                                        end
       valid_raw_sdp[3] && raw_idl[2] && tlp_end_state[1]                             : begin
                                                                                            op.dec_case =  sdp_idl_end_ddd;
                                                                                            op.first_t_next_state = 4'b0010;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.dllp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b1000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0010;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {                      format_sdp_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                                int_pkt_data[32*2 +: 32],
                                                                                                                                 format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                                int_pkt_data[32*0 +: 32]};
                                                                                        end
                       raw_stp[2] && tlp_end_state[1]                                 : begin
                                                                                            op.dec_case =  ddd_stp_end_ddd;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*2 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*2 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0100;
                                                                                            op.pkt_end = 4'b0010;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                           format_stp_32b(int_pkt_data[32*2 +: 32], data_in[32*2 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
                       raw_sdp[2] && tlp_end_state[1]                                 : begin
                                                                                            op.dec_case =  end_sdp_end_ddd;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0100;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b1010;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {                     format_end_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
        raw_idl_eds && raw_edb[2] && tlp_end_state[1]                                 : begin
                                                                                            op.dec_case =  idl_edb_end_ddd;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = raw_eds[3];
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0000; // end/edb are mutually exclusive in g12
                                                                                            op.pkt_edb = 4'b0010; // g3 edb found after tlp end, assert g12 edb one dw earlier
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                format_edb_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
        raw_stp[3]  && raw_edb[2] && tlp_end_state[1]                                 : begin
                                                                                            op.dec_case =  stp_edb_end_ddd;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*3 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*3 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b1000;
                                                                                            op.pkt_end = 4'b0000; // end/edb are mutually exclusive in g12
                                                                                            op.pkt_edb = 4'b0010; // g3 edb found after tlp end, assert g12 edb one dw earlier
                                                                                            op.pkt_data = {format_stp_32b(int_pkt_data[32*3 +: 32], data_in[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                format_edb_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
        raw_sdp[3]  && raw_edb[2] && tlp_end_state[1]                                 : begin
                                                                                            op.dec_case =  sdp_edb_end_ddd;
                                                                                            op.first_t_next_state = 4'b0010; // recognize dllp is pending when first token is not in dw0 and there is no tlp pending
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.dllp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b1000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0000; // end/edb are mutually exclusive in g12
                                                                                            op.pkt_edb = 4'b0010; // g3 edb found after tlp end, assert g12 edb one dw earlier
                                                                                            op.pkt_data = {                     format_sdp_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                format_edb_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                               int_pkt_data[32*0 +: 32]};
                                                                                        end
        raw_idl_eds && raw_idl[2] && raw_idl[1] && tlp_dllp_end_state[0]              : begin
                                                                                            op.dec_case =  idl_idl_idl_end;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = raw_eds[3];
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0001;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
                 valid_raw_stp[2] && raw_idl[1] && tlp_dllp_end_state[0]              : begin
                                                                                            op.dec_case =  ddd_stp_idl_end;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*2 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*2 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0100;
                                                                                            op.pkt_end = 4'b0001;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                           format_stp_32b(int_pkt_data[32*2 +: 32], data_in[32*2 +: 32]),
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
                 valid_raw_sdp[2] && raw_idl[1] && tlp_dllp_end_state[0]              : begin
                                                                                            op.dec_case =  end_sdp_idl_end;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0100;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b1001;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {                     format_end_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
   valid_raw_stp[3] && raw_idl[2] && raw_idl[1] && tlp_dllp_end_state[0]              : begin
                                                                                            op.dec_case =  stp_idl_idl_end;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*3 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*3 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b1000;
                                                                                            op.pkt_end = 4'b0001;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {format_stp_32b(int_pkt_data[32*3 +: 32], data_in[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
   valid_raw_sdp[3] && raw_idl[2] && raw_idl[1] && tlp_dllp_end_state[0]              : begin
                                                                                            op.dec_case =  sdp_idl_idl_end;
                                                                                            op.first_t_next_state = 4'b0010;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.dllp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b1000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0001;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {                     format_sdp_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
                                     raw_stp[1] && tlp_dllp_end_state[0]              : begin
                                                                                            op.dec_case =  ddd_ddd_stp_end;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*1 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*1 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0010;
                                                                                            op.pkt_end = 4'b0001;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                           format_stp_32b(int_pkt_data[32*1 +: 32], data_in[32*1 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
        raw_idl_eds &&               raw_sdp[1] && tlp_dllp_end_state[0]              : begin
                                                                                            op.dec_case =  idl_end_sdp_end;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = raw_eds[3];
                                                                                            op.dllp_start = 4'b0010;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0101;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                                                format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
        raw_stp[3]  &&               raw_sdp[1] && tlp_dllp_end_state[0]              : begin
                                                                                            op.dec_case =  stp_end_sdp_end;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*3 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*3 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0010;
                                                                                            op.tlp_start = 4'b1000;
                                                                                            op.pkt_end = 4'b0101;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {format_stp_32b(int_pkt_data[32*3 +: 32], data_in[32*3 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
        raw_sdp[3]  &&               raw_sdp[1] && tlp_dllp_end_state[0]              : begin
                                                                                            op.dec_case =  sdp_end_sdp_end;
                                                                                            op.first_t_next_state = 4'b0010; // recognize dllp is pending when first token is not in dw0 and there is no tlp pending
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.dllp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b1010;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0101;
                                                                                            op.pkt_edb = 4'b0000; // no edb found after tlp end
                                                                                            op.pkt_data = {                     format_sdp_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                                format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
        raw_idl_eds && raw_idl[2] && raw_edb[1] && tlp_end_state[0]                   : begin
                                                                                            op.dec_case =  idl_idl_edb_end;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = raw_eds[3];
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0000; // end/edb are mutually exclusive in g12
                                                                                            op.pkt_edb = 4'b0001; // g3 edb found after tlp end, assert g12 edb one dw earlier
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                format_edb_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
   valid_raw_stp[3] && raw_idl[2] && raw_edb[1] && tlp_end_state[0]                   : begin
                                                                                            op.dec_case =  stp_idl_edb_end;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*3 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*3 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b1000;
                                                                                            op.pkt_end = 4'b0000; // end/edb are mutually exclusive in g12
                                                                                            op.pkt_edb = 4'b0001; // g3 edb found after tlp end, assert g12 edb one dw earlier
                                                                                            op.pkt_data = {format_stp_32b(int_pkt_data[32*3 +: 32], data_in[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                format_edb_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
   valid_raw_sdp[3] && raw_idl[2] && raw_edb[1] && tlp_end_state[0]                   : begin
                                                                                            op.dec_case =  sdp_idl_edb_end;
                                                                                            op.first_t_next_state = 4'b0010;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.dllp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b1000;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b0000; // end/edb are mutually exclusive in g12
                                                                                            op.pkt_edb = 4'b0001; // g3 edb found after tlp end, assert g12 edb one dw earlier
                                                                                            op.pkt_data = {                     format_sdp_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                               int_pkt_data[32*2 +: 32],
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                format_edb_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
                       raw_stp[2] && raw_edb[1] && tlp_end_state[0]                   : begin
                                                                                            op.dec_case =  ddd_stp_edb_end;
                                                                                            op.first_t_next_state = raw_stp_first_t[4*2 +: 4];
                                                                                            op.first_t_cnt_next_state = raw_stp_first_t_cnt[9*2 +: 9];
                                                                                            op.tlp_pending_next_state = 1;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.tlp_start = 4'b0100;
                                                                                            op.pkt_end = 4'b0000; // tlp end/edb are mutually exclusive in g12
                                                                                            op.pkt_edb = 4'b0001; // g3 edb found after tlp end, assert g12 edb one dw earlier
                                                                                            op.pkt_data = {                                    int_pkt_data[32*3 +: 32],
                                                                                                           format_stp_32b(int_pkt_data[32*2 +: 32], data_in[32*2 +: 32]),
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                format_edb_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
                       raw_sdp[2] && raw_edb[1] && tlp_end_state[0]                   : begin
                                                                                            op.dec_case =  end_sdp_edb_end;
                                                                                            op.first_t_next_state = 4'b0001;
                                                                                            op.first_t_cnt_next_state = 0;
                                                                                            op.tlp_pending_next_state = 0;
                                                                                            op.eds_rcvd_next_state = 0;
                                                                                            op.dllp_start = 4'b0100;
                                                                                            op.tlp_start = 4'b0000;
                                                                                            op.pkt_end = 4'b1000; // tlp end/edb are mutually exclusive in g12
                                                                                            op.pkt_edb = 4'b0001; // g3 edb found after tlp end, assert g12 edb one dw earlier
                                                                                            op.pkt_data = {                     format_end_32b(int_pkt_data[32*3 +: 32]),
                                                                                                                                format_sdp_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                                               int_pkt_data[32*1 +: 32],
                                                                                                                                format_edb_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end

                                                                                        // Error cases
                            not_valid_token1[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  xxx_xxx_xxx_idl;
                                                                                            op.framing_err_next_state = 4'b0010;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0000;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data   = int_pkt_data;
                                                                                        end
              not_valid_token1[2] && raw_idl[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  xxx_xxx_idl_idl;
                                                                                            op.framing_err_next_state = 4'b0100;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0000;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data   = int_pkt_data;
                                                                                        end
not_valid_token1[3] && raw_idl[2] && raw_idl[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  xxx_idl_idl_idl;
                                                                                            op.framing_err_next_state = 4'b1000;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0000;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data   = int_pkt_data;
                                                                                        end
not_valid_token2[3] &&         valid_raw_sdp[1] && raw_idl[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  xxx_end_sdp_idl;
                                                                                            op.framing_err_next_state = 4'b1000;
                                                                                            op.dllp_start = 4'b0010;
                                                                                            op.pkt_end    = 4'b0100;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                            format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                            format_sdp_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                           int_pkt_data[32*0 +: 32]};
                                                                                        end
                               not_valid_token2[1] && raw_edb[0] && edb_pending_state : begin
                                                                                            op.dec_case =  xxx_xxx_xxx_edb;
                                                                                            op.framing_err_next_state = 4'b0010;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0000;
                                                                                            op.pkt_edb    = 4'b0001;
                                                                                            op.pkt_edb    = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data   = int_pkt_data; // EDB data is passed unaltered, must be don't care for Layer2 logic
                                                                                        end
                 not_valid_token1[2] && raw_idl[1] && raw_edb[0] && edb_pending_state : begin
                                                                                            op.dec_case =  xxx_xxx_idl_edb;
                                                                                            op.framing_err_next_state = 4'b0100;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0000;
                                                                                            op.pkt_edb    = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data   = int_pkt_data; // EDB data is passed unaltered, must be don't care for Layer2 logic
                                                                                        end
   not_valid_token1[3] && raw_idl[2] && raw_idl[1] && raw_edb[0] && edb_pending_state : begin
                                                                                            op.dec_case =  xxx_idl_idl_edb;
                                                                                            op.framing_err_next_state = 4'b1000;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0000;
                                                                                            op.pkt_edb    = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data   = int_pkt_data; // EDB data is passed unaltered, must be don't care for Layer2 logic
                                                                                        end
   not_valid_token2[3] &&               raw_sdp[1] && raw_edb[0] && edb_pending_state : begin
                                                                                            op.dec_case =  xxx_end_sdp_edb;
                                                                                            op.framing_err_next_state = 4'b1000;
                                                                                            op.dllp_start = 4'b0010;
                                                                                            op.pkt_end    = 4'b0100;
                                                                                            op.pkt_edb    = 4'b0000; // op.pkt_edb was asserted on previous dword (where TLP ends) based on aedb
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                            format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                            format_sdp_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                           int_pkt_data[32*0 +: 32]};
                                                                                        end
                 not_valid_token2[2] &&            raw_sdp[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  xxx_xxx_end_sdp;
                                                                                            op.framing_err_next_state = 4'b0100;
                                                                                            op.dllp_start = 4'b0001;
                                                                                            op.pkt_end    = 4'b0010;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                                           int_pkt_data[32*2 +: 32],
                                                                                                            format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                            format_sdp_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
   not_valid_token1[3] && raw_idl[2] &&            raw_sdp[0] && no_pkt_pending_state : begin
                                                                                            op.dec_case =  xxx_idl_end_sdp;
                                                                                            op.framing_err_next_state = 4'b1000;
                                                                                            op.dllp_start = 4'b0001;
                                                                                            op.pkt_end    = 4'b0010;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                                           int_pkt_data[32*2 +: 32],
                                                                                                            format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                            format_sdp_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
                               not_valid_token3[1] &&                tlp_end_state[0] : begin
                                                                                            op.dec_case =  xxx_xxx_xxx_etp; // (tlp end)
                                                                                            op.framing_err_next_state = 4'b0010;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0001;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                                           int_pkt_data[32*2 +: 32],
                                                                                                                           int_pkt_data[32*1 +: 32],
                                                                                                            format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
                               not_valid_token2[1] &&                  dllp_end_state : begin
                                                                                            op.dec_case =  xxx_xxx_xxx_edp; // (dllp end)
                                                                                            op.framing_err_next_state = 4'b0010;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0001;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                                           int_pkt_data[32*2 +: 32],
                                                                                                                           int_pkt_data[32*1 +: 32],
                                                                                                            format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
                 not_valid_token1[2] && raw_idl[1] &&           tlp_dllp_end_state[0] : begin
                                                                                            op.dec_case =  xxx_xxx_idl_end;
                                                                                            op.framing_err_next_state = 4'b0100;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0001;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                                           int_pkt_data[32*2 +: 32],
                                                                                                                           int_pkt_data[32*1 +: 32],
                                                                                                            format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
   not_valid_token1[3] && raw_idl[2] && raw_idl[1] &&           tlp_dllp_end_state[0] : begin
                                                                                            op.dec_case =  xxx_idl_idl_end;
                                                                                            op.framing_err_next_state = 4'b1000;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0001;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                                           int_pkt_data[32*2 +: 32],
                                                                                                                           int_pkt_data[32*1 +: 32],
                                                                                                            format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
                 not_valid_token2[2] && raw_edb[1] &&                tlp_end_state[0] : begin
                                                                                            op.dec_case =  xxx_xxx_edb_end;
                                                                                            op.framing_err_next_state = 4'b0100;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0000;
                                                                                            op.pkt_edb    = 4'b0001;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                                           int_pkt_data[32*2 +: 32],
                                                                                                                           int_pkt_data[32*1 +: 32],
                                                                                                            format_edb_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
   not_valid_token1[3] && raw_idl[2] && raw_edb[1] &&                tlp_end_state[0] : begin
                                                                                            op.dec_case =  xxx_idl_edb_end;
                                                                                            op.framing_err_next_state = 4'b1000;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0000;
                                                                                            op.pkt_edb    = 4'b0001;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                                           int_pkt_data[32*2 +: 32],
                                                                                                                           int_pkt_data[32*1 +: 32],
                                                                                                            format_edb_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
   not_valid_token2[3] &&               raw_sdp[1] &&           tlp_dllp_end_state[0] : begin
                                                                                            op.dec_case =  xxx_end_sdp_end;
                                                                                            op.framing_err_next_state = 4'b1000;
                                                                                            op.dllp_start = 4'b0010;
                                                                                            op.pkt_end    = 4'b0101;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                            format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                            format_sdp_32b(int_pkt_data[32*1 +: 32]),
                                                                                                            format_end_32b(int_pkt_data[32*0 +: 32])};
                                                                                        end
                 not_valid_token3[2] && tlp_end_state[1]                              : begin
                                                                                            op.dec_case =  xxx_xxx_end_ddd;
                                                                                            op.framing_err_next_state = 4'b0100;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0010;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                                           int_pkt_data[32*2 +: 32],
                                                                                                            format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                           int_pkt_data[32*0 +: 32]};
                                                                                        end
   not_valid_token1[3] && raw_idl[2] && tlp_end_state[1]                              : begin
                                                                                            op.dec_case =  xxx_idl_end_ddd;
                                                                                            op.framing_err_next_state = 4'b1000;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0010;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                                           int_pkt_data[32*2 +: 32],
                                                                                                            format_end_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                           int_pkt_data[32*0 +: 32]};
                                                                                        end
   not_valid_token2[3] && raw_edb[2] && tlp_end_state[1]                              : begin
                                                                                            op.dec_case =  xxx_edb_end_ddd;
                                                                                            op.framing_err_next_state = 4'b1000;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0000;
                                                                                            op.pkt_edb    = 4'b0010;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                                           int_pkt_data[32*2 +: 32],
                                                                                                            format_edb_32b(int_pkt_data[32*1 +: 32]),
                                                                                                                           int_pkt_data[32*0 +: 32]};
                                                                                        end
   not_valid_token3[3] && tlp_end_state[2]                                            : begin
                                                                                            op.dec_case =  xxx_end_ddd_ddd;
                                                                                            op.framing_err_next_state = 4'b1000;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = 4'b0100;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data = {                int_pkt_data[32*3 +: 32],
                                                                                                            format_end_32b(int_pkt_data[32*2 +: 32]),
                                                                                                                           int_pkt_data[32*1 +: 32],
                                                                                                                           int_pkt_data[32*0 +: 32]};
                                                                                        end
        default                                                                       : begin
                                                                                            op.dec_case =  xxx_xxx_xxx_xxx;
                                                                                            op.framing_err_next_state = 4'b1111;
                                                                                            op.dllp_start = 4'b0000;
                                                                                            op.pkt_end    = ((|tlp_end_state[2:0]) | dllp_end_state) ? 4'b0001 : 4'b0000;
                                                                                            op.pkt_edb    = 4'b0000;
                                                                                            op.pkt_data   = int_pkt_data;
                                                                                        end
    endcase
    op.pkt_err = op.framing_err_next_state;

   op.pkt_err_ptr = {4{5'b0_0000}};

   if(op.pkt_err[0] && ~raw_idl[0]) begin
       if(|raw_stp_err[2*0 +: 2])                  op.pkt_err_ptr[5*0 +: 5] = {3'b1_00, raw_stp_err[2*0 +: 2]};
       else if(int_pkt_data[32*0 +:  4]==`STP_4B ) op.pkt_err_ptr[5*0 +: 5] =  5'b0_0100;
       else if(int_pkt_data[32*0 +: 16]==`SDP_16B) op.pkt_err_ptr[5*0 +: 5] =  5'b0_0011;
       else if(edb_pending_state)                  op.pkt_err_ptr[5*0 +: 5] =  5'b0_0010;
       else                                        op.pkt_err_ptr[5*0 +: 5] =  5'b0_0001;
   end
   if(op.pkt_err[1] && ~raw_idl[1]) begin
       if(|raw_stp_err[2*1 +: 2])                  op.pkt_err_ptr[5*1 +: 5] = {3'b1_00, raw_stp_err[2*1 +: 2]};
       else if(int_pkt_data[32*1 +:  4]==`STP_4B ) op.pkt_err_ptr[5*1 +: 5] =  5'b0_0100;
       else if(int_pkt_data[32*1 +: 16]==`SDP_16B) op.pkt_err_ptr[5*1 +: 5] =  5'b0_0011;
       else if(tlp_end_state[0])                   op.pkt_err_ptr[5*1 +: 5] =  5'b0_0010;
       else                                        op.pkt_err_ptr[5*1 +: 5] =  5'b0_0001;
   end
   if(op.pkt_err[2] && ~raw_idl[2]) begin
       if(|raw_stp_err[2*2 +: 2])                  op.pkt_err_ptr[5*2 +: 5] = {3'b1_00, raw_stp_err[2*2 +: 2]};
       else if(int_pkt_data[32*2 +:  4]==`STP_4B ) op.pkt_err_ptr[5*2 +: 5] =  5'b0_0100;
       else if(int_pkt_data[32*2 +: 16]==`SDP_16B) op.pkt_err_ptr[5*2 +: 5] =  5'b0_0011;
       else if(tlp_end_state[1])                   op.pkt_err_ptr[5*2 +: 5] =  5'b0_0010;
       else                                        op.pkt_err_ptr[5*2 +: 5] =  5'b0_0001;
   end
   if(op.pkt_err[3] && ~raw_idl[3]) begin
       if(|raw_stp_err[2*3 +: 2])                  op.pkt_err_ptr[5*3 +: 5] = {3'b1_00, raw_stp_err[2*3 +: 2]};
       else if(int_pkt_data[32*3 +:  4]==`STP_4B ) op.pkt_err_ptr[5*3 +: 5] =  5'b0_0100;
       else if(int_pkt_data[32*3 +: 16]==`SDP_16B) op.pkt_err_ptr[5*3 +: 5] =  5'b0_0011;
       else if(tlp_end_state[2])                   op.pkt_err_ptr[5*3 +: 5] =  5'b0_0010;
       else                                        op.pkt_err_ptr[5*3 +: 5] =  5'b0_0001;
   end
   if(&(op.pkt_err & raw_idl)) begin
       op.pkt_err_ptr = {4{5'b0_0001}};
   end


    rplh_token_finder4_128b_dec = op ;

end
endfunction // rplh_token_finder4_128b_dec

// 8b/10b Tokens
localparam SDP_8B = `SDP_8B;                // Start of DLLP
localparam STP_8B = `STP_8B;                // Start of TLP
localparam END_8B = `END_8B;                // End of TLP
localparam EDB_8B = `EDB_8B;                // End of Bad TLP

// create 32b stp in Gen1/Gen2 format using the seq_num field extracted from 32b stp in Gen3 format
function automatic [31:0] format_stp_32b(input [31:0] g12_data, input [31:0] g3_data);
    reg [11:0] seq_num_stp;
    begin
        seq_num_stp = extrct_seq_num(g3_data);
        format_stp_32b = {g12_data[31:24], seq_num_stp[7:0], {4'b0000, seq_num_stp[11:8]}, STP_8B};
    end
endfunction

function automatic [31:0] format_sdp_32b(input [31:0] g12_data);
    begin
        format_sdp_32b = {g12_data[31:8], SDP_8B};
    end
endfunction

function automatic [31:0] format_end_32b(input [31:0] g12_data);
    begin
        format_end_32b = {END_8B, g12_data[23:0]};
    end
endfunction

function automatic [31:0] format_edb_32b(input [31:0] g12_data);
    begin
        format_edb_32b = {EDB_8B, g12_data[23:0]};
    end
endfunction

function automatic [11:0] extrct_seq_num (input [31:0] g3_data);
    begin
        extrct_seq_num = {g3_data[19:16], g3_data[31:24]};
    end
endfunction

endmodule // rplh_token_finder4

