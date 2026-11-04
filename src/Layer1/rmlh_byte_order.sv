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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh_byte_order.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description: Re-order data per symbol and per lane.
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
module rmlh_byte_order
#(
parameter   INST    = 0,                         // The uniquifying parameter for each port logic instance.
parameter   REGIN   = `CX_RMLH_PKT_FINDER_REGIN,
parameter   NL      = `CX_NL,                    // Max number of lanes supported
parameter   NB      = `CX_NB,                    // Number of symbols (bytes) per clock cycle
parameter   TP      = `TP                        // Clock to Q delay (simulator insurance)
)
(
// ---- inputs ---------------
input                   core_clk,
input                   core_rst_n,
input   [5:0]           smlh_link_mode,
input   [NL-1:0]        deskew_lanes_active,           // Which lanes are actively (begin) configured
input   [3:0]           active_nb,
input                   rxdata_flush_gen12_in,         // Request from deskew to flush the internal buffer. Active high. Gen1/Gen2 only
input                   rxdata_dv_in,                  // data is valid this cycle
input   [(NL*NB*8)-1:0] rxdata_in,                     // Incoming data
input   [(NL*NB)-1:0]   rxdatak_in,                    // Incoming k indication
input   [(NL*NB)-1:0]   rxerror_in,                    // Errors reported by PHY
input   [2:0]           current_data_rate,
input                   search_for_tokens,             // enable token processing while in a data stream
input                   accept_eds_cycle,              // on this cycle the EDS token can be accepted, means we are at the endo of a block
input                   expect_eds,                    // Signal from deskew block to inform token_finder that EDS is expected
input                   os_in_datastream,              // OS detected within data stream
input   [4:0]           rxdata_link_width,             // Currently link width for L0p
input                   smlh_flit_mode_enable,         // Flit mode enabled
// ---- outputs ---------------
output  [(NL*NB*8)-1:0] rmlh_rplh_rxdata,              // Incoming data
output  [(NL*NB)-1:0]   rmlh_rplh_rxdatak,             // Incoming k indication
output  [(NL*NB)-1:0]   rmlh_rplh_rxerror,             // Errors reported by PHY
output                  rmlh_rplh_dv,                  // data is valid this cycle
output                  rmlh_rplh_os_in_datastream,    // OS detected within data stream
output                  rmlh_rplh_search_for_tokens,   // enable token processing while in a data stream
output                  rmlh_rplh_accept_eds_cycle,    // on this cycle the EDS token can be accepted, means we are at the endo of a block
output                  rmlh_rplh_expect_eds,          // Signal from deskew block to inform token_finder that EDS is expected
output  [4:0]           rmlh_rplh_rxdata_link_width,   // Currently link width
output  [1:0]           rmlh_rplh_rcvd_idle_gen12      // Keep track of the number of idle received continously in Gen1/Gen2.
                                                       // Bit 0 indicates 8 continous idle symbol received, bit 1 indicates 1 idle receivd
);

// ============================================================
// Local Parameters
// ============================================================
localparam   GEN1_NB = `CX_NB_GEN1;
localparam   GEN2_NB = `CX_NB_GEN2;


// ============================================================
// (Optional) Registered inputs
// ============================================================
wire                           search_for_tokens_int;
wire                           accept_eds_cycle_int;
wire                           expect_eds_int;
wire                           os_in_datastream_int;
wire   [4:0]                   rxdata_link_width_int;

wire                    rxdata_dv_int;
wire    [(NL*NB*8)-1:0] rxdata_int;
wire    [(NL*NB)-1:0]   rxdatak_int;
wire    [(NL*NB)-1:0]   rxerror_int;
wire                    rxdata_flush_gen12_int;

parameter N_DELAY_CYLES     = REGIN ? 1 : 0;
parameter DATAPATH_WIDTH    = 10 * NB * NL;
delay_n

#(N_DELAY_CYLES, 2) u_delay_ctrl (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   ({rxdata_dv_in,  rxdata_flush_gen12_in}),
    .dout  ({rxdata_dv_int, rxdata_flush_gen12_int})
);

delay_n_w_enable

#(N_DELAY_CYLES, DATAPATH_WIDTH) u_delay_w_enable_data (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .en    (rxdata_dv_in),
    .din   ({rxdata_in,  rxdatak_in,  rxerror_in}),
    .dout  ({rxdata_int, rxdatak_int, rxerror_int})
);

parameter SIGNALS_WIDTH =
                          5 + // rxdata_link_width
                          1 + // os_in_datastream
                          1 + // search_for_tokens
                          1 + // accept_eds_cycle
                          1 ; // expect_eds

delay_n

#(N_DELAY_CYLES, SIGNALS_WIDTH) u_delay_signals (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   ({
             ((smlh_flit_mode_enable) ? rxdata_link_width : smlh_link_mode[4:0]),
              os_in_datastream,
              search_for_tokens,
              accept_eds_cycle,
              expect_eds}),
    .dout  ({
              rxdata_link_width_int,
              os_in_datastream_int,
              search_for_tokens_int,
              accept_eds_cycle_int,
              expect_eds_int})
);


// ============================================================
// Gen1/Gen2 Flush internal buffers.
// ============================================================
// Deskew module can request to flush the internal buffer in several scenarios.
// The intent is to forward to Layer 2 whatever was already received and is 
// stored in the internal buffer just waiting for fill the datapath.
// The flush is done by emulating a special k-symbol "00". 
// If there is not packet in progress the special k-symbol will be ignored.
// Instead, if a packet is in progress it will be terminated and flagged
// with pkt_err. Idle counters will be reset as well during the flush.

wire gen12_rate;
assign gen12_rate = (current_data_rate < `GEN3_RATE)? 1'b1 : 1'b0;

wire data_flush;
wire                    rxdata_dv;
wire    [(NL*NB*8)-1:0] rxdata;
wire    [(NL*NB)-1:0]   rxdatak;
wire    [(NL*NB)-1:0]   rxerror;

assign data_flush = gen12_rate & rxdata_flush_gen12_int & ~rxdata_dv_int;
assign rxdata_dv = (data_flush)?          1'b1   : rxdata_dv_int;
assign rxdata    = (data_flush)? {NL*NB*8{1'b0}} : rxdata_int;
assign rxdatak   = (data_flush)? {NL*NB  {1'b1}} : rxdatak_int;
assign rxerror   = (data_flush)? {NL*NB  {1'b0}} : rxerror_int;


// ============================================================
// Re-order data received
// ============================================================
wire    [4:0]           link_mode;
wire    [4:0]           smlh_link_mode_i;
assign smlh_link_mode_i = (smlh_flit_mode_enable) ? rxdata_link_width_int : smlh_link_mode[4:0];
assign link_mode       = (NL==16) ?           smlh_link_mode_i[4:0]  :
                         (NL==8)  ? {1'b0   , smlh_link_mode_i[3:0]} :
                         (NL==4)  ? {2'b00  , smlh_link_mode_i[2:0]} :
                         (NL==2)  ? {3'b000 , smlh_link_mode_i[1:0]} :
                                    {4'b0000, smlh_link_mode_i[0]  };

// Re-order input per symbol
wire    [(NL*NB*8)-1:0] rx_data_tmp;
wire    [(NL*NB)-1:0]   rx_datak_tmp;
wire    [(NL*NB)-1:0]   rx_error_tmp;

assign rx_data_tmp = sym_order_byte(rxdata);
assign rx_datak_tmp = sym_order_bit(rxdatak);
assign rx_error_tmp = sym_order_bit(rxerror);

function automatic [(NL*NB)-1:0] sym_order_bit;
    input [(NL*NB)-1:0] data_in;
begin
    for (int sym=0; sym<NB; sym=sym+1) begin
        for (int lane=0; lane<NL; lane=lane+1) begin
            sym_order_bit[sym*NL+lane] = data_in[lane*NB+sym];
        end
    end
end
endfunction

function automatic [(NL*NB*8)-1:0] sym_order_byte;
    input [(NL*NB*8)-1:0] data_in;
begin
    for (int sym=0; sym<NB; sym=sym+1) begin
        for (int lane=0; lane<NL; lane=lane+1) begin
            sym_order_byte[(sym*NL+lane)*8+:8] = data_in[(lane*NB+sym)*8+:8];
        end
    end
end
endfunction

// Re-order input per lane
reg [(NL*NB*8)-1:0] rx_data;
reg [(NL*NB)-1:0]   rx_datak;
reg [(NL*NB)-1:0]   rx_error;

assign rx_data  = lane_order_byte(rx_data_tmp, link_mode);
assign rx_datak = lane_order_bit(rx_datak_tmp, link_mode);
assign rx_error = lane_order_bit(rx_error_tmp, link_mode);

parameter LINK_LOOP = (NL==16) ? 4 :
                      (NL==8)  ? 3 :
                      (NL==4)  ? 2 :
                      (NL==2)  ? 1 : 0;

function automatic [(NL*NB)-1:0] lane_order_bit;
    input [(NL*NB)-1:0] data_in;
    input [4:0]         link_mode;
    integer byte_loc, link_loc;
begin
    lane_order_bit = {(NL*NB){1'b0}};
    for (link_loc=LINK_LOOP; link_loc>=0; link_loc=link_loc-1) begin
        if (link_mode[link_loc]==1'b1) begin
            for (byte_loc=0; byte_loc<(NB<<LINK_LOOP); byte_loc=byte_loc+1) begin
                if (byte_loc<(NB<<link_loc)) begin
                    lane_order_bit[byte_loc] = data_in[(byte_loc/(1<<link_loc))*NL+(byte_loc%(1<<link_loc))];
                end
            end
        end
    end
end
endfunction

function automatic [(NL*NB*8)-1:0] lane_order_byte;
    input [(NL*NB*8)-1:0] data_in;
    input [4:0]           link_mode;
begin
    lane_order_byte = {(NL*NB*8-1){1'b0}};
    for (int link_loc=LINK_LOOP; link_loc>=0; link_loc=link_loc-1) begin
        if (link_mode[link_loc]==1'b1) begin
            for (int byte_loc=0; byte_loc<(NB<<LINK_LOOP); byte_loc=byte_loc+1) begin
                if (byte_loc<(NB<<link_loc)) begin
                    lane_order_byte[byte_loc*8+:8] = data_in[((byte_loc/(1<<link_loc))*NL+(byte_loc%(1<<link_loc)))*8+:8];
                end
            end
        end
    end
end
endfunction


//===================================================================================
// Gen1/Gen2 Logic idle detection circuitry to assist LTSSM transition
//===================================================================================
localparam TMP_NB = (`CX_NB>=16) ? 8 : NB;
wire    [(NL*NB)-1:0]   idles;
assign idles = compare_bytes(rx_data_tmp, ~rx_datak_tmp, 8'b0);
reg     [7:0]     skips_lane0;

always @(*) begin : skips_lane0_PROC
    skips_lane0 = 8'h0;
    for (int i=0; i<TMP_NB; i=i+1) begin
        skips_lane0[i]    = ( rxdata[i*8+:8] == `SKIP_8B || rxdata[i*8+:8] == `COMMA_8B ) & rxdatak[i];
    end
end

reg [8:0] all_lane_rcvd_idle;
always @(*) begin : all_lane_rcvd_idle_PROC
    all_lane_rcvd_idle = 8'h0;
    for (int i=0; i<TMP_NB; i=i+1) begin
        all_lane_rcvd_idle[i] = &((~deskew_lanes_active) | (idles[i*NL+:NL] & (~rx_error_tmp[NL-1:0])));
    end
end

wire [3:0] active_sym_gen12;
// Suppress the most significant bits for lower speeds
     /// for Dynamic Frequency/Width mixed config
assign active_sym_gen12 = {1'b0,
                          (((GEN1_NB==4) || (GEN2_NB==4)) ? active_nb[2] : 1'b0),  // 4s @gen2, 4s @gen1
                          (((GEN1_NB==2) || (GEN2_NB==2)) ? active_nb[1] : 1'b0),  // 2s @gen2, 2s @gen1
                          (((GEN1_NB==1) || (GEN2_NB==1)) ? active_nb[0] : 1'b0)   // 1s @gen2, 1s @gen1
                          };

wire  [3:0]          rx_sym_valid;
assign  rx_sym_valid = (active_sym_gen12 == 4'b0001) ? 4'b0001 :
                       (active_sym_gen12 == 4'b0010) ? 4'b0011 :
                       (active_sym_gen12 == 4'b0100) ? 4'b1111 : 4'b0000;

wire [3:0] rcvd_idle_cnt_a;
wire [3:0] rcvd_idle_cnt_b;
wire [3:0] rcvd_idle_cnt_c;
wire [3:0] rcvd_idle_cnt_d;
reg  [3:0] rcvd_idle_cnt;
assign rcvd_idle_cnt_a = (rxdata_dv & rx_sym_valid[0]) ? (all_lane_rcvd_idle[0] ? rcvd_idle_cnt + 1 :
                                                          skips_lane0[0]        ? rcvd_idle_cnt : 0) :
                                                                                  rcvd_idle_cnt;
assign rcvd_idle_cnt_b = (rxdata_dv & rx_sym_valid[1]) ? (all_lane_rcvd_idle[1] ? rcvd_idle_cnt_a + 1 :
                                                          skips_lane0[1]        ? rcvd_idle_cnt_a : 0) :
                                                                                  rcvd_idle_cnt_a;
assign rcvd_idle_cnt_c = (rxdata_dv & rx_sym_valid[2]) ? (all_lane_rcvd_idle[2] ? rcvd_idle_cnt_b + 1 :
                                                          skips_lane0[2]        ? rcvd_idle_cnt_b : 0) :
                                                                                  rcvd_idle_cnt_b;
assign rcvd_idle_cnt_d = (rxdata_dv & rx_sym_valid[3]) ? (all_lane_rcvd_idle[3] ? rcvd_idle_cnt_c + 1 :
                                                          skips_lane0[3]        ? rcvd_idle_cnt_c : 0) :
                                                                                  rcvd_idle_cnt_c;

reg [1:0] rcvd_idle12;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        rcvd_idle_cnt     <= #TP 0;
        rcvd_idle12       <= #TP 0;
    end else begin
        rcvd_idle_cnt     <= #TP (NB>=4) ? rcvd_idle_cnt_d[3] ? 4'b1000 : rcvd_idle_cnt_d :
                                 (NB==2) ? rcvd_idle_cnt_b[3] ? 4'b1000 : rcvd_idle_cnt_b :
                                           rcvd_idle_cnt_a[3] ? 4'b1000 : rcvd_idle_cnt_a;
        rcvd_idle12[0]    <= #TP (NB>=4) ? rcvd_idle_cnt_a[3] | rcvd_idle_cnt_b[3] | rcvd_idle_cnt_c[3] | rcvd_idle_cnt_d[3] :
                                 (NB==2) ? rcvd_idle_cnt_a[3] | rcvd_idle_cnt_b[3] :
                                           rcvd_idle_cnt_a[3];
        rcvd_idle12[1]    <= #TP (NB>=4) ? |{rcvd_idle_cnt_a, rcvd_idle_cnt_b, rcvd_idle_cnt_c, rcvd_idle_cnt_d} :
                                 (NB==2) ? |{rcvd_idle_cnt_a, rcvd_idle_cnt_b} :
                                           |{rcvd_idle_cnt_a};
    end


// ==================
//   Drive outputs
// ==================
assign rmlh_rplh_rxdata  = rx_data;
assign rmlh_rplh_rxdatak = rx_datak;
assign rmlh_rplh_rxerror = rx_error;
assign rmlh_rplh_dv      = rxdata_dv;

assign rmlh_rplh_rxdata_link_width = rxdata_link_width_int;
assign rmlh_rplh_os_in_datastream  = os_in_datastream_int;
assign rmlh_rplh_search_for_tokens = search_for_tokens_int;
assign rmlh_rplh_accept_eds_cycle  = accept_eds_cycle_int;
assign rmlh_rplh_expect_eds        = expect_eds_int;

assign rmlh_rplh_rcvd_idle_gen12   = rcvd_idle12;

//==============================================================================
//
//==============================================================================
function automatic [(NL*NB)-1:0] compare_bytes;
    input   [(NL*NB)*8-1:0] din;
    input   [(NL*NB)-1:0]   kchar;
    input   [7:0]           byteval;
begin
    for (int j=0; j<(NB*NL); j=j+1) begin
        compare_bytes[j] = (din[8*j+:8] == byteval) & kchar[j];
    end
end
endfunction

endmodule
