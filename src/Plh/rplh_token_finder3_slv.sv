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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_token_finder3_slv.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description: Process current 32b of data and recognise a token 
// --- depending on the token that was recognized in the previous 32b of data.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rplh_token_finder3_slv 
#(parameter INST = 0,
  parameter ALIGN_MODE = 2)                 // include/exclude logic for detecting token alignment on a byte or word boundary
                                            // 0: support alignment on dword boundaries (i.e. min supported link mode is x4)
                                            // 1: support alignment on byte boundaries (i.e. min supported link mode is x1)
                                            // 2: support alignment on word boundaries (i.e. min supported link mode is x2)
(
input wire   [8:0]  prev_token,             // Previous Token Decoder State. One-Hot Encoded: IDL, EDS, EDB, SDP, DDP (data-DLLP), STP, DTP (data-TLP), END, aEDB (Anticipated EDB)
input wire   [10:0] prev_tlp_cnt,           // Previous TLP Count. Indicates remaining number of DWs in current TLP
input wire   [3:0]  prev_framing_err,       // Previous Framing Error including pointer
input wire   [3:0]  prev_alignment,         // Previous Byte Alignment of Input Data
input wire   [31:0] data_in,                // Token Data In
input wire   [31:0] next_data_in,           // Next Token Data In
input wire   [3:0]  dec_stp_token,          // Decoded STP Token
input wire   [3:0]  dec_sdp_token,          // Decoded SDP Token
input wire   [3:0]  dec_idl_token,          // Decoded IDL Token
input wire   [3:0]  dec_edb_token,          // Decoded EDB Token
input wire   [3:0]  dec_aedb_token,         // Next Token is EDB (Anticipated EDB)
input wire          dec_eds_token,          // Decoded EDS Token
input wire          accept_stp_sdp,         // Indication that STP/SDP tokens may be accepted on these lanes following IDL, driven as a function of link_mode and the dword number, for example in a 2sx8 it is active for DW_NUM=0,2

output reg   [8:0]  token,                  // Current Token Decoder State
output reg   [10:0] tlp_cnt,                // TLP Count. Indicates length of current TLP
output reg   [3:0]  framing_err,            // Framing Error including pointer
output wire         framing_err_stp,        // STP Token Framing Error
output reg   [3:0]  alignment,              // Byte Alignment of Input Data. Denotes which Byte corresponds to Lane 0
output reg          dllp_start,             // DLLP Start
output reg          tlp_start,              // TLP Start
output reg          pkt_end,                // End of Packet
output reg          pkt_edb,                // End of Bad Packet
output reg   [31:0] pkt_data,               // Packet Data
output reg   [5:0]  pkt_err                 // Packet Error including pointer
);

// 128b/130b Token Decode States
localparam S_IDL  = `TKF_S_IDL;             // Idle
localparam S_EDS  = `TKF_S_EDS;             // End of Data Stream
localparam S_EDB  = `TKF_S_EDB;             // End of Bad TLP
localparam S_SDP  = `TKF_S_SDP;             // Start DLLP
localparam S_DDP  = `TKF_S_DDP;             // Data DLLP
localparam S_STP  = `TKF_S_STP;             // Start TLP
localparam S_DTP  = `TKF_S_DTP;             // Data TLP
localparam S_END  = `TKF_S_END;             // End of TLP
localparam S_aEDB = `TKF_S_aEDB;            // Anticipated End of TLP
localparam S_NDV  = `TKF_S_NDV;             // No data valid
// 8b/10b Tokens
localparam SDP_8B = `SDP_8B;                // Start of DLLP
localparam STP_8B = `STP_8B;                // Start of TLP
localparam END_8B = `END_8B;                // End of TLP
localparam EDB_8B = `EDB_8B;                // End of Bad TLP

// Internal Signals
wire         [3:0]  stps;                   // STP Token Found
wire         [3:0]  sdps;                   // SDP Token Found
wire         [3:0]  dec_stp;                // STP Token Decoded
wire         [3:0]  dec_sdp;                // SDP Token Decoded
wire         [3:0]  dec_idl;                // IDL Decoded
wire         [3:0]  dec_eds;                // EDS Token Decoded
wire         [3:0]  dec_edb;                // EDS Token Decoded
wire         [3:0]  dec_aedb;               // Anticipated EDB Token Decoded
wire         [3:0]  arb_stp_sdp;            // Arbitrate between STP and SDP
reg          [31:0] stp_token;              // STP Token Data
reg          [31:0] int_pkt_data;           // Internal Aligned Packet Data
reg          [11:0] seq_num_stp;            // Sequence Number extracted from STP Token
reg          [3:0]  valid_start_mask;       // Mask STP/SDP depending on previous alignment
wire         [3:0]  link_mode_alignment_mask; // mask invalid alignments depending on min link mode supported: x1, x2 or x4
reg          [2:0]  pre_framing_err_stp;    // [2:1] STP Token Framing Error Pointer [0] STP Token Framing Error
assign link_mode_alignment_mask = (ALIGN_MODE == 0) ? 4'b0001 : // min link mode supported x4 
                                  (ALIGN_MODE == 1) ? 4'b1111 : // min link mode supported x1 
                                                      4'b0101;  // min link mode supported x2 

// Build a mask based on previous alignment:
//  - Ignore previously processed data
//  - Ignore bytes greater than prev_aligment when bytes between prev_alignment and new_alignment are not IDLs
// Used to mask start tokens (i.e. STP and SDP).
// As a result only the first valid start token is enabled
always @(*) begin : valid_start_mask_PROC
    valid_start_mask[0] = prev_alignment[0];
    valid_start_mask[1] = prev_alignment[1] | (valid_start_mask[0] && data_in[7:0]  ==8'h00);
    valid_start_mask[2] = prev_alignment[2] | (valid_start_mask[1] && data_in[15:8] ==8'h00);
    valid_start_mask[3] = prev_alignment[3] | (valid_start_mask[2] && data_in[23:16]==8'h00);
end

// Decode Framing Tokens
// Decode first valid STP and SDP Token
assign dec_stp = dec_stp_token & valid_start_mask & link_mode_alignment_mask;
assign dec_sdp = dec_sdp_token & valid_start_mask & link_mode_alignment_mask;
// Decode IDL Token
assign dec_idl = dec_idl_token & prev_alignment;
// Decode EDB Token (Anticipated and non-Anticipated
// Note: Previous alignment must be exact for EDB as 
// token directly follows LCRC in TLP
assign dec_aedb = dec_aedb_token & prev_alignment;
assign dec_edb = dec_edb_token & prev_alignment;

// Extract STP Token Data
always @(*) begin : extract_stp_token_PROC
    case (dec_stp[3:1]) // we have knowledge that the case expression can only be one-hot or zero
        3'b001 : stp_token = {next_data_in[7:0],  data_in[31:8]} ;
        3'b010 : stp_token = {next_data_in[15:0], data_in[31:16]} ;
        3'b100 : stp_token = {next_data_in[23:0], data_in[31:24]} ;
        default : stp_token = data_in[31:0] ;
    endcase
end

always @(*) begin : token_decode_PROC
    token           = S_NDV;
    tlp_cnt         = 0;
    framing_err     = 0;
    pre_framing_err_stp = 0;
    seq_num_stp     = 0;
    alignment       = prev_alignment;
    case (prev_token[8:5]) // decode upper 4 bits only
        S_SDP[8:5]: begin
                token = S_DDP;
            end // S_SDP
        S_STP[8:5]: begin
                tlp_cnt = prev_tlp_cnt - 1; // we expect prev_tlp_cnt to be at least 4, i.e. min(tlp_len) - 1, min(tlp_len) = 5 dwords
                token = S_DTP;
            end // S_STP
        S_DTP[8:5]: begin
            tlp_cnt = prev_tlp_cnt - 1;
            if (tlp_cnt>0)
                token = S_DTP;
            else if(|dec_aedb) 
                token = S_aEDB;
            else 
                token = S_END;
        end // S_DTP
        S_aEDB[8:5]: begin
            token = S_EDB;
            if (!(|dec_edb))
// ccx_line_begin: ; "Unreachable code because the condition is not feasible during nomal operation. Leave the line only for safety."
              framing_err = {3'h2,1'b1}; // Framing Error reported if current data is not a valid EDB token and previous token was aEDB.
// ccx_line_end
            else
              framing_err = {3'h0,1'b0}; 
        end // S_aEDB
        default: begin
            case ( {|dec_idl, |dec_sdp, |dec_stp} ) // we have knowledge that the case expression can only be one-hot or zero
                                                           // this is due to the fact that first 8 bits of idl, stp, sdp tokens are mutually exclusive: idl=8'h00, sdp=8'hf0, stp= 'hxf
                3'b100 : begin
                    token     = S_IDL; 
                    alignment = 4'b0001; 
                end
                3'b010 : begin
                    token     = S_SDP; 
                    alignment = dec_sdp; 
                    if( !accept_stp_sdp && (prev_token[`TKF_S_IDL_BIT] || prev_token[`TKF_S_EDS_BIT]))
                      framing_err = {3'h3,1'b1}; // in these two states we can only accept STP SDP in certain positions, depending on link mode
                end
                3'b001 : begin
                    if( dec_eds_token ) begin 
                        token     = S_EDS;
                    end else begin
                        token     = S_STP; 
                        alignment = dec_stp;
                        if( !accept_stp_sdp && (prev_token[`TKF_S_IDL_BIT] || prev_token[`TKF_S_EDS_BIT]))
                          framing_err = {3'h4,1'b1}; // in these two states we can only accept STP SDP in certain positions, depending on link mode
                        {tlp_cnt, seq_num_stp, pre_framing_err_stp} = check_stp(stp_token); 
                    end
                end
                default : begin
                    framing_err = {3'h1,1'b1};
                end
            endcase
        end // S_IDL, S_EDS, S_EDB, S_DDP, S_END
    endcase // prev_token
end

assign framing_err_stp = pre_framing_err_stp[0];

// align data based on byte where first token of packet was recevied
// Align Input Data based on Byte where STP or SDP Token was decoded.
// This Byte corresponds to Lane 0 and data is aligned to this Byte
// until an STP Or SDP Token with different alignment is received or
// IDL is received.
always @(*) begin : data_align_PROC
    case (alignment[3:1]) // we have knowledge that the case expression can only be one-hot or zero
        3'b001 : int_pkt_data     = {next_data_in[15:0], data_in[31:16]};
        3'b010 : int_pkt_data     = {next_data_in[23:0], data_in[31:24]};
        3'b100 : int_pkt_data     = next_data_in[31:0];
        default : int_pkt_data     = {next_data_in[7:0], data_in[31:8]}; // 4'b0000/4'b0001 case
    endcase
end

// adaptation of data format and control signals to the interface expected by tlp_extract for Gen1/Gen2
always @(*) begin : data_format_PROC
    dllp_start = 0;
    tlp_start = 0;
    pkt_end = 0;
    pkt_edb = 0;
    pkt_data = 0;
    pkt_err = framing_err[0]  ? {2'b0_0 ,framing_err[3:1]        ,1'b1} :
              framing_err_stp ? {3'b1_00,pre_framing_err_stp[2:1],1'b1} : 6'b0_0000_0;
    case (token)
        S_SDP: begin
            pkt_data[31:0] = {int_pkt_data[31:8], SDP_8B};
            dllp_start = 1;
        end // S_SDP
        S_DDP, S_END: begin
            pkt_data[31:0] = {END_8B, int_pkt_data[23:0]};
            pkt_end = 1;
        end // S_DDP, S_END
        S_STP: begin
            pkt_data[31:0] = {int_pkt_data[31:24], seq_num_stp[7:0], {4'b0000, seq_num_stp[11:8]}, STP_8B};
            tlp_start = 1;
        end // S_STP
        S_aEDB: begin
            pkt_data[31:0] = {EDB_8B, int_pkt_data[23:0]};
            pkt_edb = 1;
        end // S_aEDB
        default: begin
            pkt_data[31:0] = int_pkt_data[31:0]; // pkt_data is dont care for Layer 2 for EDS/EDB/IDL, so default is same as DTP
        end // S_DTP, S_EDS, S_EDB, S_IDL
    endcase // token
end

// tlp_cnt = tlp_len - 1, the tlp_len encoded in STP is the actual total number of DW of the TLP
function automatic [25:0] check_stp (input [31:0] stp_token);
    reg [10:0] tlp_cnt;     // output
    reg [11:0] seq_num;     // output
    reg [2:0]  framing_err; // output
    reg [10:0] stp_tlp_len;
    reg [3:0]  extrct_fcrc, calc_fcrc;
    reg        extrct_fp, calc_fp;
    begin
        stp_tlp_len = {stp_token[14:8], stp_token[7:4]};     // Extract STP TLP Length
        tlp_cnt     = stp_tlp_len - 1;                       // Subtract 1 DW to get actual TLP Length
        seq_num     = {stp_token[19:16], stp_token[31:24]};  // Extract Sequence Number
        extrct_fcrc = stp_token[23:20];                      // Extract Frame CRC
        extrct_fp   = stp_token[15];                         // Extract Frame Parity
        calc_fcrc   = get_frame_crc(stp_tlp_len);            // Calculate Framce CRC based on STP TLP Length
        calc_fp     = get_frame_parity(stp_tlp_len);         // Calculate Frame Parity based on STP TLP Length

        framing_err = (extrct_fcrc != calc_fcrc)             ? {2'b01,1'b1}  : // Frame CRC Error
                      (extrct_fp   != calc_fp)               ? {2'b10,1'b1}  : // Frame Parity Error
                      (stp_tlp_len < `CX_GEN3_MIN_TLP_LEN)   ? {2'b11,1'b1}  : // STP TLP Length Error
                                                               {2'b00,1'b0}  ;

        return {tlp_cnt, seq_num, framing_err};
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
function automatic get_frame_parity;
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

`ifndef SYNTHESIS
//VCS coverage off
wire [4*8-1:0]  TOKEN;
wire [4*8-1:0]  PREV_TOKEN;

assign TOKEN      = (token  == S_IDL)       ? "IDL"  : 
                    (token  == S_EDS)       ? "EDS"  : 
                    (token  == S_EDB)       ? "EDB"  : 
                    (token  == S_SDP)       ? "SDP"  : 
                    (token  == S_DDP)       ? "DDP"  : 
                    (token  == S_STP)       ? "STP"  : 
                    (token  == S_DTP)       ? "DTP"  : 
                    (token  == S_END)       ? "END"  : 
                    (token  == S_aEDB)      ? "aEDB" : 
                    (token  == S_NDV)       ? "NDV"  : "ERR" ;

assign PREV_TOKEN = (prev_token  == S_IDL)  ? "IDL"  : 
                    (prev_token  == S_EDS)  ? "EDS"  : 
                    (prev_token  == S_EDB)  ? "EDB"  : 
                    (prev_token  == S_SDP)  ? "SDP"  : 
                    (prev_token  == S_DDP)  ? "DDP"  : 
                    (prev_token  == S_STP)  ? "STP"  : 
                    (prev_token  == S_DTP)  ? "DTP"  : 
                    (prev_token  == S_END)  ? "END"  : 
                    (prev_token  == S_aEDB) ? "aEDB" : 
                    (prev_token  == S_NDV)  ? "NDV"  : "ERR" ;  

//VCS coverage on
`endif // SYNTHESIS

endmodule // rplh_token_finder3_slv
