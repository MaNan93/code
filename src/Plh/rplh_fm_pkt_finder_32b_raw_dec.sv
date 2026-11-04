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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_fm_pkt_finder_32b_raw_dec.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: decode tokens (ie. Prefix, Header, Suffix or NOP)
// ---                     calculate the length of the TLP in order to figure out where to look for the next
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/pcie_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module rplh_fm_pkt_finder_32b_raw_dec
import pcie_pkg::fm_tkn_t;
import pcie_pkg::decoded_tlp_type_s;
import pcie_pkg::f_decode_ohc_len;
import pcie_pkg::f_decode_tlp_type;
import DWC_pcie_core_pkg::fm_raw_tkn_t;
#(
parameter   DWNUM   = 0,    // Raw decoder instance number
parameter   PIPE_EN = 0     // Optional pipeline
)
(
// ---- inputs ---------------
input                   core_clk,
input                   core_rst_n,
input                   data_dv,
input  [31:0]           data,
input  [$clog2(64)-1:0] dwnum,      // Dword number (i.e. data dword position within the Flit)
// ---- outputs ---------------
output fm_raw_tkn_t     raw         // Raw token structure
);

wire [7:0] f_type; // Header type
wire [4:0] f_ohc;  // OHC type
wire [2:0] f_ts;   // Trailer Size
wire [9:0] f_len;  // Length

assign f_type = data[7:0];
assign f_ohc  = data[12:8];
assign f_ts   = data[23:21];
assign f_len  = {data[17:16], data[31:24]};

wire [2:0]  hdr_ohc_len;
wire [3:0]  hdr_full_len;       // Max header length is 11 DW
wire [10:0] pyld_len;           // Data Length
reg  [2:0]  trlr_len;           // Trailer length
wire [11:0] tmp_tlp_len;        // Temporary tlp Length, 12 bits to avoid spyglass overflow warning
wire [10:0] tlp_len, tlp_len_d; // Length
pcie_pkg::decoded_tlp_type_s dec_type;

assign dec_type    = pcie_pkg::f_decode_tlp_type(f_type, 1'b1);
assign hdr_ohc_len = pcie_pkg::f_decode_ohc_len(f_ohc);

always_comb begin : trailer_len_proc
    unique case (f_ts) 
        3'b001  : trlr_len = 1;
        3'b010  : trlr_len = 1;
        3'b011  : trlr_len = 2;
        3'b100  : trlr_len = 2;
        3'b101  : trlr_len = 3;
        3'b110  : trlr_len = 4;
        3'b111  : trlr_len = 5;
        default : trlr_len = 0;
    endcase
end

assign hdr_full_len = {1'b0, dec_type.hdr_base_len} + {1'b0, hdr_ohc_len};
assign pyld_len = (dec_type.payload)? (f_len==10'h0)? 11'd1024 : {1'b0,f_len} : 11'b0;
assign tmp_tlp_len = hdr_full_len + {1'b0, pyld_len} + trlr_len;
assign tlp_len = tmp_tlp_len[10:0];

// tlp len should never be greater than 1024 (pyld_len) + 4 (dec_type.hdr_base_len) + 7 (hdr_ohc_len) +  5 (trlr_len) = 1040. 
// therefore the 12th bit should always be zero

// Optional pipeline
localparam PIPE_WIDTH = $clog2(64)               + // dwnum
                        11                       + // tlp_len
                        $bits(pcie_pkg::fm_tkn_t); // dec_type.tkn

wire [$clog2(64)-1:0] dwnum_d; // Dword number (i.e. data dword position within the Flit)
pcie_pkg::fm_tkn_t raw_tkn_d;

delay_n_w_enable

#(PIPE_EN, PIPE_WIDTH) u_delay_w_enable_tlp_len (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .en    (data_dv),
    .din   ({dwnum,   tlp_len,   dec_type.tkn}),
    .dout  ({dwnum_d, tlp_len_d, raw_tkn_d})
);

fm_raw_tkn_t raw_59; // Raw token structure assuming 59 TLP dwords
assign raw_59.tkn = raw_tkn_d;

// Absolute position of the eot - assuming infinite dwords will be decoded in a single cycle
wire [11:0] eot_pos_dwnum_abs;
assign eot_pos_dwnum_abs = tlp_len_d + dwnum_d - 1;

// dwnum_d over 256b
wire [2:0] dwnum_256b_d = dwnum_d % 8;

// Position of the eot for a Single Flit TLP - assummig the TLP ends in the current Flit
// The TLP starting ends in the same Flit so add only the alignment of the TLP start within the 8DW decoder (dwnum_256b_d)
wire [11:0] eot_pos_dwnum_sf;
assign eot_pos_dwnum_sf =  tlp_len_d + dwnum_256b_d - 1;

// Position of the eot for a Multi Flit TLP
// The TLP starting spans over multiple Flits so add the alignment of the TLP start from the start of the Flit (dwnum_d)
//wire [11:0] eot_pos_dwnum_mf;
//assign eot_pos_dwnum_mf = eot_pos_dwnum_abs % 59;

// How many Flit cycles are needed to reach the cycle with the eot of this tlp
//assign raw_59.eot_flt = eot_pos_dwnum_abs/59;

// The following is a timing optimization to calculate:
// * eot_pos_dwnum = eot_pos_dwnum_abs%59
// * raw_59.eot_flt   = eot_pos_dwnum_abs/59
logic [11:0] eot_pos_dwnum;
always_comb begin : mod59_and_div59_proc
    unique case (1'b1)
                                           eot_pos_dwnum_abs < 12'( 1*59) : begin eot_pos_dwnum = eot_pos_dwnum_sf;               raw_59.eot_flt= 0; end // Single Flit TLP
        eot_pos_dwnum_abs >= 12'( 1*59) && eot_pos_dwnum_abs < 12'( 2*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'( 1*59); raw_59.eot_flt= 1; end
        eot_pos_dwnum_abs >= 12'( 2*59) && eot_pos_dwnum_abs < 12'( 3*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'( 2*59); raw_59.eot_flt= 2; end
        eot_pos_dwnum_abs >= 12'( 3*59) && eot_pos_dwnum_abs < 12'( 4*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'( 3*59); raw_59.eot_flt= 3; end
        eot_pos_dwnum_abs >= 12'( 4*59) && eot_pos_dwnum_abs < 12'( 5*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'( 4*59); raw_59.eot_flt= 4; end
        eot_pos_dwnum_abs >= 12'( 5*59) && eot_pos_dwnum_abs < 12'( 6*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'( 5*59); raw_59.eot_flt= 5; end
        eot_pos_dwnum_abs >= 12'( 6*59) && eot_pos_dwnum_abs < 12'( 7*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'( 6*59); raw_59.eot_flt= 6; end
        eot_pos_dwnum_abs >= 12'( 7*59) && eot_pos_dwnum_abs < 12'( 8*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'( 7*59); raw_59.eot_flt= 7; end
        eot_pos_dwnum_abs >= 12'( 8*59) && eot_pos_dwnum_abs < 12'( 9*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'( 8*59); raw_59.eot_flt= 8; end
        eot_pos_dwnum_abs >= 12'( 9*59) && eot_pos_dwnum_abs < 12'(10*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'( 9*59); raw_59.eot_flt= 9; end
        eot_pos_dwnum_abs >= 12'(10*59) && eot_pos_dwnum_abs < 12'(11*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'(10*59); raw_59.eot_flt=10; end
        eot_pos_dwnum_abs >= 12'(11*59) && eot_pos_dwnum_abs < 12'(12*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'(11*59); raw_59.eot_flt=11; end
        eot_pos_dwnum_abs >= 12'(12*59) && eot_pos_dwnum_abs < 12'(13*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'(12*59); raw_59.eot_flt=12; end
        eot_pos_dwnum_abs >= 12'(13*59) && eot_pos_dwnum_abs < 12'(14*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'(13*59); raw_59.eot_flt=13; end
        eot_pos_dwnum_abs >= 12'(14*59) && eot_pos_dwnum_abs < 12'(15*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'(14*59); raw_59.eot_flt=14; end
        eot_pos_dwnum_abs >= 12'(15*59) && eot_pos_dwnum_abs < 12'(16*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'(15*59); raw_59.eot_flt=15; end
        eot_pos_dwnum_abs >= 12'(16*59) && eot_pos_dwnum_abs < 12'(17*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'(16*59); raw_59.eot_flt=16; end
        eot_pos_dwnum_abs >= 12'(17*59) && eot_pos_dwnum_abs < 12'(18*59) : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'(17*59); raw_59.eot_flt=17; end
     /* eot_pos_dwnum_abs >= 12'(18*59) */                        default : begin eot_pos_dwnum = eot_pos_dwnum_abs - 12'(18*59); raw_59.eot_flt=18; end
    endcase
end

// One hot indication to find the end of this tlp within the 8DW instance
// The lower 3 bits represent the 256b dw number of the first token after the end of this tlp
// convert the binary dwnum into one hot
always_comb begin : eot_pos_proc
    unique case (eot_pos_dwnum[2:0])
        0       : raw_59.eot_pos = 8'b0000_0001;
        1       : raw_59.eot_pos = 8'b0000_0010;
        2       : raw_59.eot_pos = 8'b0000_0100;
        3       : raw_59.eot_pos = 8'b0000_1000;
        4       : raw_59.eot_pos = 8'b0001_0000;
        5       : raw_59.eot_pos = 8'b0010_0000;
        6       : raw_59.eot_pos = 8'b0100_0000;
        default : raw_59.eot_pos = 8'b1000_0000;
    endcase
end

// How many 8DW instances are needed to reach the eot of this tlp
assign raw_59.eot_dec = eot_pos_dwnum[5:3];

// Sinthesize a Prefix-like token on Flit Overhead dwords
localparam fm_raw_tkn_t DEFAULT_FLIT_OVERHEAD = '{tkn:pcie_pkg::PFX_TKN, eot_flt:5'h1, eot_dec:3'h0, eot_pos:8'h10};

assign raw = (dwnum_d<59)? raw_59 : DEFAULT_FLIT_OVERHEAD;

endmodule // rplh_fm_pkt_finder_32b_raw_dec

