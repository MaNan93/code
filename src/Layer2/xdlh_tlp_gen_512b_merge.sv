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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_tlp_gen_512b_merge.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description: Combinatorial expansion of the Layer3 datapath after
//     inserting Layer2 and Layer1 overhead.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xdlh_tlp_gen_512b_merge
#(
parameter NW = 16,// number of dwords in the input datapath, this module only supports 16
parameter MNW = NW+5,  // number of dwords in the merged datapath, after insertion of one DLLP, one STP, two LCRCs, an 8 DWs input datapath can expand into 13 DWs
parameter CW = 5,   // control width, number of control bits {edb, sdp, dwen, eot, sot} for one dword 
parameter OUTPUT_REG = 0,
parameter TP         = `TP    
)
(
// ---- inputs ---------------
input                          core_clk,
input                          core_rst_n,
input                          input_dv,  // input datapath valid
input [32*NW-1:0]              input_data,  // input datapath 
input [NW-1:0]                 input_sot,
input [NW-1:0]                 input_eot,
input [NW-1:0]                 input_edb,
input [NW-1:0]                 input_dwen,
input [31:0]                   input_crc0,
input [31:0]                   input_crc1,
input [63:0]                   input_dllp,
input [31:0]                   input_stp,
input                          dllp_xmt_req,
input                          data_rate_is_gen3,
input                          out_dllp_halt,
input                          xmlh_skip_pending,// used here to preempt DLLP insertion
// ---- outputs ---------------
output reg                     dllp_xmt_halt, // dllp cannot be inserted
output [MNW*(32+CW)-1:0]       merged_edata,  // merged (i.e. after Layer2 overhead insertion) extended (i.e. including controls) data
output                         merged_edata_pkt_pending  // merged data contains a packet
);

// parameter TP = 0;
localparam EDB_BIT  = 4;
localparam SDP_BIT  = 3;
localparam DWEN_BIT = 2;
localparam EOT_BIT  = 1;
localparam SOT_BIT  = 0;
localparam IDL = 2'b00;
localparam SOT = 2'b01;
localparam DAT = 2'b10;
localparam EOT = 2'b11;

// Remove EDBs when related to masked (DWEN disabled) TLPs.
// This prevents the contamination of a good TLP when followed by a nullified and masked one-cycle TLP.
wire [NW-1:0] int_edb;
assign int_edb = input_edb & input_dwen;

// indicate if we have one or two edbs on the input
wire edb0 =  (|int_edb); 
wire edb1 = !(^int_edb) & (|int_edb);   // If 2 EOTs, XOR is 0 and OR is 1
wire edb = input_dv & (edb0 | edb1); // note: the OR is unnecessary if xtlh guarantees no more than one EDB in a clock cycle
wire [2*NW-1:0] tmp_dec_input_vec;

wire [31:0] tmp_stp_data = input_stp; // encoding for the actual STP token
wire [31:0] tmp_edb_data = {`EDB_TOKEN_3, `EDB_TOKEN_2, `EDB_TOKEN_1, `EDB_TOKEN_0}; // encoding for Gen3 EDB token
wire [31:0] tmp_idl_data = 32'h00000000;
wire int_dllp_xmt_req = dllp_xmt_req & ~xmlh_skip_pending & ~out_dllp_halt;  // halt DLLP insertion when a skip is pending

// 4-bit control {sdp, dwen, eot, sot} + 32-bit data, concatenated to facilitate manipulation in the overhead insertion process
wire [(32+CW)-1:0] d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15, e000, e00, e01, e100, e10, e11, dllp0, dllp1, stp, __i__; // {sdp, dwen, eot, sot, data[31:0]}

// the dword inserted on 1st TLP-end when we know edb = 0
assign e000 = {5'b00110, input_crc0};

// the first dword inserted on 1st TLP-end as a function of edb
assign e00 = (!data_rate_is_gen3) ? (edb ? {5'b10110, ~input_crc0} : {5'b00110, input_crc0}) : 
                                    (edb ? {5'b00100, ~input_crc0} : {5'b00110, input_crc0}); // for Gen3, in case of EDB, EOT is pushed out one dword

// the second dword inserted on 1st TLP-end as a function of edb 
assign e01 = (!data_rate_is_gen3) ? {5'b00000, tmp_idl_data} : // for Gen2 it reduces to idles as there is no extra EDB token to insert
                                    (edb ? {5'b10110, tmp_edb_data} : {5'b00000, tmp_idl_data}); // for Gen3, in case of EDB, EOT and EDB are both active one 2nd dword

// the dword inserted on 2nd TLP-end when we know edb = 0
assign e100 = {5'b00110, input_crc1};

// the first dword inserted on 2nd TLP-end as a function of edb
assign e10 = (!data_rate_is_gen3) ? (edb ? {5'b10110, ~input_crc1} : {5'b00110, input_crc1}) :
                                    (edb ? {5'b00100, ~input_crc1} : {5'b00110, input_crc1}); // for Gen3, in case of EDB, EOT is pushed out one dword

// the second dword inserted on 2nd TLP-end as a function of edb
assign e11 = (!data_rate_is_gen3) ? {5'b00000, tmp_idl_data} : // for Gen2 it reduces to idles as there is no extra EDB token to insert
                                    (edb ? {5'b10110, tmp_edb_data} : {5'b00000, tmp_idl_data}); // for Gen3, in case of EDB, EOT and EDB are both active one 2nd dword

reg [MNW*(32+CW)-1:0] m_edata, next_m_edata;
reg next_m_pkt_pending, m_pkt_pending;

assign tmp_dec_input_vec = input_dv ? { // use input_dv=0 to treat datapath as idle
                        dec_input(input_sot[15], input_eot[15], input_dwen[15]),
                        dec_input(input_sot[14], input_eot[14], input_dwen[14]), 
                        dec_input(input_sot[13], input_eot[13], input_dwen[13]),
                        dec_input(input_sot[12], input_eot[12], input_dwen[12]), 
                        dec_input(input_sot[11], input_eot[11], input_dwen[11]),
                        dec_input(input_sot[10], input_eot[10], input_dwen[10]), 
                        dec_input(input_sot[9] , input_eot[9] , input_dwen[9] ),
                        dec_input(input_sot[8] , input_eot[8] , input_dwen[8] ),
                        dec_input(input_sot[7] , input_eot[7] , input_dwen[7] ),
                        dec_input(input_sot[6] , input_eot[6] , input_dwen[6] ), 
                        dec_input(input_sot[5] , input_eot[5] , input_dwen[5] ),
                        dec_input(input_sot[4] , input_eot[4] , input_dwen[4] ), 
                        dec_input(input_sot[3] , input_eot[3] , input_dwen[3] ),
                        dec_input(input_sot[2] , input_eot[2] , input_dwen[2] ), 
                        dec_input(input_sot[1] , input_eot[1] , input_dwen[1] ),
                        dec_input(input_sot[0] , input_eot[0] , input_dwen[0] )
                       } :  16'h0000;

assign { d15[32+EDB_BIT],   d14[32+EDB_BIT],   d13[32+EDB_BIT],   d12[32+EDB_BIT],   d11[32+EDB_BIT],   d10[32+EDB_BIT],   d9[32+EDB_BIT],   d8[32+EDB_BIT],   d7[32+EDB_BIT],   d6[32+EDB_BIT],   d5[32+EDB_BIT],   d4[32+EDB_BIT],   d3[32+EDB_BIT],   d2[32+EDB_BIT],   d1[32+EDB_BIT],   d0[32+EDB_BIT]}   = 0; // true edb will be inserted as an extra dw by this module
assign { d15[32+DWEN_BIT],  d14[32+DWEN_BIT],  d13[32+DWEN_BIT],  d12[32+DWEN_BIT],  d11[32+DWEN_BIT],  d10[32+DWEN_BIT],  d9[32+DWEN_BIT],  d8[32+DWEN_BIT],  d7[32+DWEN_BIT],  d6[32+DWEN_BIT],  d5[32+DWEN_BIT],  d4[32+DWEN_BIT],  d3[32+DWEN_BIT],  d2[32+DWEN_BIT],  d1[32+DWEN_BIT],  d0[32+DWEN_BIT]}  = input_dwen;
assign { d15[32+SDP_BIT],   d14[32+SDP_BIT],   d13[32+SDP_BIT],   d12[32+SDP_BIT],   d11[32+SDP_BIT],   d10[32+SDP_BIT],   d9[32+SDP_BIT],   d8[32+SDP_BIT],   d7[32+SDP_BIT],   d6[32+SDP_BIT],   d5[32+SDP_BIT],   d4[32+SDP_BIT],   d3[32+SDP_BIT],   d2[32+SDP_BIT],   d1[32+SDP_BIT],   d0[32+SDP_BIT]}   = 0; // this is tlp data, therefore sdp=0 
assign { d15[32+EOT_BIT],   d14[32+EOT_BIT],   d13[32+EOT_BIT],   d12[32+EOT_BIT],   d11[32+EOT_BIT],   d10[32+EOT_BIT],   d9[32+EOT_BIT],   d8[32+EOT_BIT],   d7[32+EOT_BIT],   d6[32+EOT_BIT],   d5[32+EOT_BIT],   d4[32+EOT_BIT],   d3[32+EOT_BIT],   d2[32+EOT_BIT],   d1[32+EOT_BIT],   d0[32+EOT_BIT]}   = 0; // true eot will be inserted as an extra dw by this module
assign { d15[32+SOT_BIT],   d14[32+SOT_BIT],   d13[32+SOT_BIT],   d12[32+SOT_BIT],   d11[32+SOT_BIT],   d10[32+SOT_BIT],   d9[32+SOT_BIT],   d8[32+SOT_BIT],   d7[32+SOT_BIT],   d6[32+SOT_BIT],   d5[32+SOT_BIT],   d4[32+SOT_BIT],   d3[32+SOT_BIT],   d2[32+SOT_BIT],   d1[32+SOT_BIT],   d0[32+SOT_BIT]}   = 0; // true stp will be inserted as an extra dw by this module
assign { d15[31:0],         d14[31:0],         d13[31:0],         d12[31:0],         d11[31:0],         d10[31:0],         d9[31:0],         d8[31:0],         d7[31:0],         d6[31:0],         d5[31:0],         d4[31:0],         d3[31:0],         d2[31:0],         d1[31:0],         d0[31:0]}         = input_data;


assign stp   = {5'b00101, tmp_stp_data};      // {edb=0, sdp=0, dwen=1, eot=0, sot=1}
assign dllp0 = {1'b0, 4'b1100, input_dllp[31:0]};  // {edb=0, sdp=1, dwen=1, eot=0, sot=0} // dwen is 1 for both tlp and dllp data
assign dllp1 = {5'b00110, input_dllp[63:32]}; // {edb=0, sdp=0, dwen=1, eot=1, sot=0} // eot is 1 for both tlp and dllp end
assign __i__ = {5'b00000, tmp_idl_data};


always @(posedge core_clk or negedge core_rst_n) begin : m_edata_PROC
    if ( !core_rst_n ) begin
        m_edata <= #TP 0;
        m_pkt_pending <= #TP 0;
    end else begin
        m_edata <= #TP next_m_edata;
        m_pkt_pending <= #TP next_m_pkt_pending;
    end
end

assign merged_edata = OUTPUT_REG ? m_edata : next_m_edata;
assign merged_edata_pkt_pending = OUTPUT_REG ? m_pkt_pending : next_m_pkt_pending;

typedef enum logic [2*NW-1:0] {
    i_i_i_i_i_i_i_i_i_i_i_i_i_e_d_s = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT} /* 1  s on dw0, various d-lengths, e, idle */,
    i_i_i_i_i_i_i_i_i_i_i_i_e_d_d_s = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT} /* 2  */,
    i_i_i_i_i_i_i_i_i_i_i_e_d_d_d_s = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT} /* 3  */,
    i_i_i_i_i_i_i_i_i_i_e_d_d_d_d_s = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT} /* 4  */,
    i_i_i_i_i_i_i_i_i_e_d_d_d_d_d_s = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT} /* 5  */,
    i_i_i_i_i_i_i_i_e_d_d_d_d_d_d_s = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT} /* 6  */,
    i_i_i_i_i_i_i_e_d_d_d_d_d_d_d_s = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT} /* 7.0  */,
    i_i_i_i_i_i_e_d_d_d_d_d_d_d_d_s = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT} /* 7.1  */,
    i_i_i_i_i_e_d_d_d_d_d_d_d_d_d_s = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT} /* 7.2  */,
    i_i_i_i_e_d_d_d_d_d_d_d_d_d_d_s = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT} /* 7.3  */,
    i_i_i_e_d_d_d_d_d_d_d_d_d_d_d_s = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT} /* 7.4  */,
    i_i_e_d_d_d_d_d_d_d_d_d_d_d_d_s = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT} /* 7.5  */,
    i_e_d_d_d_d_d_d_d_d_d_d_d_d_d_s = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT} /* 7.6  */,
    e_d_d_d_d_d_d_d_d_d_d_d_d_d_d_s = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT} /* 7.7  */,
    d_d_d_d_d_d_d_d_d_d_d_d_d_d_d_s = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT} /* 7.8  */,
    i_i_i_i_i_i_i_i_i_i_i_i_i_i_e_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT} /* 8  d on dw0, various d-lengths, e, idle (no s) */,
    i_i_i_i_i_i_i_i_i_i_i_i_i_e_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT} /* 1+8  sub-cases obtained replacing "s" on DW0 with "d" */,
    i_i_i_i_i_i_i_i_i_i_i_i_e_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT} /* 2+8  */,
    i_i_i_i_i_i_i_i_i_i_i_e_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT} /* 3+8  */,
    i_i_i_i_i_i_i_i_i_i_e_d_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT} /* 4+8  */,
    i_i_i_i_i_i_i_i_i_e_d_d_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT} /* 5+8  */,
    i_i_i_i_i_i_i_i_e_d_d_d_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 6.0+8  */,
    i_i_i_i_i_i_i_e_d_d_d_d_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 6.1+8  */,
    i_i_i_i_i_i_e_d_d_d_d_d_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 6.2+8  */,
    i_i_i_i_i_e_d_d_d_d_d_d_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 6.3+8  */,
    i_i_i_i_e_d_d_d_d_d_d_d_d_d_d_d = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 6.4+8  */,
    i_i_i_e_d_d_d_d_d_d_d_d_d_d_d_d = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 6.5+8  */,
    i_i_e_d_d_d_d_d_d_d_d_d_d_d_d_d = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 6.6+8  */,
    i_e_d_d_d_d_d_d_d_d_d_d_d_d_d_d = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 6.7+8  */,
    e_d_d_d_d_d_d_d_d_d_d_d_d_d_d_d = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 6.8+8  */,
    d_d_d_d_d_d_d_d_d_d_d_d_d_d_d_d = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 7+8  */,
    i_i_i_i_i_i_i_i_i_i_i_e_d_s_e_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, EOT, DAT} /* 16  d on dw0, various d-lengths, e, s, various d-lenghts */,
    i_i_i_i_i_i_i_i_i_i_e_d_d_s_e_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, EOT, DAT} /* 17  */,
    i_i_i_i_i_i_i_i_i_e_d_d_d_s_e_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, EOT, DAT} /* 18  */,
    i_i_i_i_i_i_i_i_e_d_d_d_d_s_e_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, EOT, DAT} /* 19  */,
    i_i_i_i_i_i_i_e_d_d_d_d_d_s_e_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT} /* 20.0  */,
    i_i_i_i_i_i_e_d_d_d_d_d_d_s_e_d = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT} /* 20.1  */,
    i_i_i_i_i_e_d_d_d_d_d_d_d_s_e_d = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT} /* 20.2  */,
    i_i_i_i_e_d_d_d_d_d_d_d_d_s_e_d = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT} /* 20.3  */,
    i_i_i_e_d_d_d_d_d_d_d_d_d_s_e_d = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT} /* 20.4  */,
    i_i_e_d_d_d_d_d_d_d_d_d_d_s_e_d = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT} /* 20.5  */,
    i_e_d_d_d_d_d_d_d_d_d_d_d_s_e_d = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT} /* 20.6  */,
    e_d_d_d_d_d_d_d_d_d_d_d_d_s_e_d = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT} /* 20.7  */,
    d_d_d_d_d_d_d_d_d_d_d_d_d_s_e_d = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT} /* 20.8  */,
    i_i_i_i_i_i_i_i_i_i_e_d_s_e_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, EOT, DAT, DAT} /* 21  d on dw0,dw1 */,
    i_i_i_i_i_i_i_i_i_e_d_d_s_e_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, EOT, DAT, DAT} /* 22  */,
    i_i_i_i_i_i_i_i_e_d_d_d_s_e_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, EOT, DAT, DAT} /* 23.0  */,
    i_i_i_i_i_i_i_e_d_d_d_d_s_e_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT} /* 23.1  */,
    i_i_i_i_i_i_e_d_d_d_d_d_s_e_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT} /* 23.2  */,
    i_i_i_i_i_e_d_d_d_d_d_d_s_e_d_d = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT} /* 23.3  */,
    i_i_i_i_e_d_d_d_d_d_d_d_s_e_d_d = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT} /* 23.4  */,
    i_i_i_e_d_d_d_d_d_d_d_d_s_e_d_d = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT} /* 23.5  */,
    i_i_e_d_d_d_d_d_d_d_d_d_s_e_d_d = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT} /* 23.6  */,
    i_e_d_d_d_d_d_d_d_d_d_d_s_e_d_d = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT} /* 23.7  */,
    e_d_d_d_d_d_d_d_d_d_d_d_s_e_d_d = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT} /* 23.8  */,
    d_d_d_d_d_d_d_d_d_d_d_d_s_e_d_d = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT} /* 24  */,
    i_i_i_i_i_i_i_i_i_e_d_s_e_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, EOT, DAT, DAT, DAT} /* 25  d on dw0,dw1,dw2 */,
    i_i_i_i_i_i_i_i_e_d_d_s_e_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, EOT, DAT, DAT, DAT} /* 26.0  */,
    i_i_i_i_i_i_i_e_d_d_d_s_e_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT} /* 26.1  */,
    i_i_i_i_i_i_e_d_d_d_d_s_e_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT} /* 26.2  */,
    i_i_i_i_i_e_d_d_d_d_d_s_e_d_d_d = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT} /* 26.3  */,
    i_i_i_i_e_d_d_d_d_d_d_s_e_d_d_d = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT} /* 26.4  */,
    i_i_i_e_d_d_d_d_d_d_d_s_e_d_d_d = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT} /* 26.5  */,
    i_i_e_d_d_d_d_d_d_d_d_s_e_d_d_d = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT} /* 26.6  */,
    i_e_d_d_d_d_d_d_d_d_d_s_e_d_d_d = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT} /* 26.7  */,
    e_d_d_d_d_d_d_d_d_d_d_s_e_d_d_d = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT} /* 26.8  */,
    d_d_d_d_d_d_d_d_d_d_d_s_e_d_d_d = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT} /* 27  */,
    i_i_i_i_i_i_i_i_e_d_s_e_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, EOT, DAT, DAT, DAT, DAT} /* 28.0  d on dw0,dw1,dw2,dw3 */,
    i_i_i_i_i_i_i_e_d_d_s_e_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT} /* 28.1  */,
    i_i_i_i_i_i_e_d_d_d_s_e_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT} /* 28.2  */,
    i_i_i_i_i_e_d_d_d_d_s_e_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT} /* 28.3  */,
    i_i_i_i_e_d_d_d_d_d_s_e_d_d_d_d = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT} /* 28.4  */,
    i_i_i_e_d_d_d_d_d_d_s_e_d_d_d_d = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT} /* 28.5  */,
    i_i_e_d_d_d_d_d_d_d_s_e_d_d_d_d = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT} /* 28.6  */,
    i_e_d_d_d_d_d_d_d_d_s_e_d_d_d_d = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT} /* 28.7  */,
    e_d_d_d_d_d_d_d_d_d_s_e_d_d_d_d = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT} /* 28.8  */,
    d_d_d_d_d_d_d_d_d_d_s_e_d_d_d_d = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT} /* 29  */,
    i_i_i_i_i_i_i_e_d_s_e_d_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT} /* 30.0  d on dw0,dw1,dw2,dw3,dw4 */,
    i_i_i_i_i_i_e_d_d_s_e_d_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT} /* 30.1  */,
    i_i_i_i_i_e_d_d_d_s_e_d_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT} /* 30.2  */,
    i_i_i_i_e_d_d_d_d_s_e_d_d_d_d_d = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT} /* 30.3  */,
    i_i_i_e_d_d_d_d_d_s_e_d_d_d_d_d = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT} /* 30.4  */,
    i_i_e_d_d_d_d_d_d_s_e_d_d_d_d_d = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT} /* 30.5  */,
    i_e_d_d_d_d_d_d_d_s_e_d_d_d_d_d = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT} /* 30.6  */,
    e_d_d_d_d_d_d_d_d_s_e_d_d_d_d_d = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT} /* 30.7  */,
    d_d_d_d_d_d_d_d_d_s_e_d_d_d_d_d = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT} /* 30.8  */,
    i_i_i_i_i_i_e_d_s_e_d_d_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.0  d on dw0,dw1,dw2,dw3,dw4,dw5 */,
    i_i_i_i_i_e_d_d_s_e_d_d_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.1  */,
    i_i_i_i_e_d_d_d_s_e_d_d_d_d_d_d = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.2  */,
    i_i_i_e_d_d_d_d_s_e_d_d_d_d_d_d = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.3  */,
    i_i_e_d_d_d_d_d_s_e_d_d_d_d_d_d = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.4  */,
    i_e_d_d_d_d_d_d_s_e_d_d_d_d_d_d = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.5  */,
    e_d_d_d_d_d_d_d_s_e_d_d_d_d_d_d = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.6  */,
    d_d_d_d_d_d_d_d_s_e_d_d_d_d_d_d = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.7  */,
    i_i_i_i_i_e_d_s_e_d_d_d_d_d_d_d = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.8  d on dw0,dw1,dw2,dw3,dw4,dw5,dw6 */,
    i_i_i_i_e_d_d_s_e_d_d_d_d_d_d_d = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.9  */,
    i_i_i_e_d_d_d_s_e_d_d_d_d_d_d_d = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.10  */,
    i_i_e_d_d_d_d_s_e_d_d_d_d_d_d_d = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.11  */,
    i_e_d_d_d_d_d_s_e_d_d_d_d_d_d_d = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.12  */,
    e_d_d_d_d_d_d_s_e_d_d_d_d_d_d_d = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.13  */,
    d_d_d_d_d_d_d_s_e_d_d_d_d_d_d_d = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.14  */,
    i_i_i_i_e_d_s_e_d_d_d_d_d_d_d_d = {IDL, IDL, IDL, IDL, EOT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.15  d on dw0,dw1,dw2,dw3,dw4,dw5,dw6,dw7 */,
    i_i_i_e_d_d_s_e_d_d_d_d_d_d_d_d = {IDL, IDL, IDL, EOT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.16  */,
    i_i_e_d_d_d_s_e_d_d_d_d_d_d_d_d = {IDL, IDL, EOT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.17  */,
    i_e_d_d_d_d_s_e_d_d_d_d_d_d_d_d = {IDL, EOT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.18  */,
    e_d_d_d_d_d_s_e_d_d_d_d_d_d_d_d = {EOT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.19  */,
    d_d_d_d_d_d_s_e_d_d_d_d_d_d_d_d = {DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.20  */,
    i_i_i_e_d_s_e_d_d_d_d_d_d_d_d_d = {IDL, IDL, IDL, EOT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.21  d on dw0,dw1,dw2,dw3,dw4,dw5,dw6,dw7,dw8 */,
    i_i_e_d_d_s_e_d_d_d_d_d_d_d_d_d = {IDL, IDL, EOT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.22  */,
    i_e_d_d_d_s_e_d_d_d_d_d_d_d_d_d = {IDL, EOT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.23  */,
    e_d_d_d_d_s_e_d_d_d_d_d_d_d_d_d = {EOT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.24  */,
    d_d_d_d_d_s_e_d_d_d_d_d_d_d_d_d = {DAT, DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.25  */,
    i_i_e_d_s_e_d_d_d_d_d_d_d_d_d_d = {IDL, IDL, EOT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.26  d on dw0,dw1,dw2,dw3,dw4,dw5,dw6,dw7,dw8,dw9 */,
    i_e_d_d_s_e_d_d_d_d_d_d_d_d_d_d = {IDL, EOT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.27  */,
    e_d_d_d_s_e_d_d_d_d_d_d_d_d_d_d = {EOT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.28  */,
    d_d_d_d_s_e_d_d_d_d_d_d_d_d_d_d = {DAT, DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.29  */,
    i_e_d_s_e_d_d_d_d_d_d_d_d_d_d_d = {IDL, EOT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.30  d on dw0,dw1,dw2,dw3,dw4,dw5,dw6,dw7,dw8,dw9,dw10 */,
    e_d_d_s_e_d_d_d_d_d_d_d_d_d_d_d = {EOT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.31  */,
    d_d_d_s_e_d_d_d_d_d_d_d_d_d_d_d = {DAT, DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.32  */,
    e_d_s_e_d_d_d_d_d_d_d_d_d_d_d_d = {EOT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.33  d on dw0,dw1,dw2,dw3,dw4,dw5,dw6,dw7,dw8,dw9,dw10,dw11 */,
    d_d_s_e_d_d_d_d_d_d_d_d_d_d_d_d = {DAT, DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.34  */,
    d_s_e_d_d_d_d_d_d_d_d_d_d_d_d_d = {DAT, SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.35  d on dw0,dw1,dw2,dw3,dw4,dw5,dw6,dw7,dw8,dw9,dw10,dw11,dw12 */,
    s_e_d_d_d_d_d_d_d_d_d_d_d_d_d_d = {SOT, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT} /* 31.36  */,
    i_i_i_i_i_i_i_i_i_i_i_i_i_i_i_e = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT} /* 32  e on dw0, idle (no s) */,
    i_i_i_i_i_i_i_i_i_i_i_i_e_d_s_e = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, EOT} /* 33  e on dw0, s, various d-lenghts */,
    i_i_i_i_i_i_i_i_i_i_i_e_d_d_s_e = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, EOT} /* 34  */,
    i_i_i_i_i_i_i_i_i_i_e_d_d_d_s_e = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, EOT} /* 35  */,
    i_i_i_i_i_i_i_i_i_e_d_d_d_d_s_e = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, EOT} /* 36  */,
    i_i_i_i_i_i_i_i_e_d_d_d_d_d_s_e = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, EOT} /* 37.0  */,
    i_i_i_i_i_i_i_e_d_d_d_d_d_d_s_e = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT} /* 37.1  */,
    i_i_i_i_i_i_e_d_d_d_d_d_d_d_s_e = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT} /* 37.2  */,
    i_i_i_i_i_e_d_d_d_d_d_d_d_d_s_e = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT} /* 37.3  */,
    i_i_i_i_e_d_d_d_d_d_d_d_d_d_s_e = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT} /* 37.4  */,
    i_i_i_e_d_d_d_d_d_d_d_d_d_d_s_e = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT} /* 37.5  */,
    i_i_e_d_d_d_d_d_d_d_d_d_d_d_s_e = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT} /* 37.6  */,
    i_e_d_d_d_d_d_d_d_d_d_d_d_d_s_e = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT} /* 37.7  */,
    e_d_d_d_d_d_d_d_d_d_d_d_d_d_s_e = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT} /* 37.8  */,
    d_d_d_d_d_d_d_d_d_d_d_d_d_d_s_e = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, EOT} /* 38  */,
    i_i_i_i_i_i_i_i_i_i_i_i_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 0  i on dw0, no s */,
    i_i_i_i_i_i_i_i_i_i_i_e_d_s_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, IDL, IDL} /* 16+23  sub-cases obtained replacing everything prior to sot with idles (replay buffer case) */,
    i_i_i_i_i_i_i_i_i_i_e_d_d_s_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, IDL, IDL} /* 17+23  */,
    i_i_i_i_i_i_i_i_i_e_d_d_d_s_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, IDL, IDL} /* 18+23  */,
    i_i_i_i_i_i_i_i_e_d_d_d_d_s_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, IDL, IDL} /* 19+23  */,
    i_i_i_i_i_i_i_e_d_d_d_d_d_s_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL} /* 20.0+23  */,
    i_i_i_i_i_i_e_d_d_d_d_d_d_s_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL} /* 20.1+23  */,
    i_i_i_i_i_e_d_d_d_d_d_d_d_s_i_i = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL} /* 20.2+23  */,
    i_i_i_i_e_d_d_d_d_d_d_d_d_s_i_i = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL} /* 20.3+23  */,
    i_i_i_e_d_d_d_d_d_d_d_d_d_s_i_i = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL} /* 20.4+23  */,
    i_i_e_d_d_d_d_d_d_d_d_d_d_s_i_i = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL} /* 20.5+23  */,
    i_e_d_d_d_d_d_d_d_d_d_d_d_s_i_i = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL} /* 20.6+23  */,
    e_d_d_d_d_d_d_d_d_d_d_d_d_s_i_i = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL} /* 20.7+23  */,
    d_d_d_d_d_d_d_d_d_d_d_d_d_s_i_i = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL} /* 20.8+23  */,
    i_i_i_i_i_i_i_i_i_i_e_d_s_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, IDL, IDL, IDL} /* 21+23  */,
    i_i_i_i_i_i_i_i_i_e_d_d_s_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, IDL, IDL, IDL} /* 22+23  */,
    i_i_i_i_i_i_i_i_e_d_d_d_s_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, IDL, IDL, IDL} /* 23.0+23  */,
    i_i_i_i_i_i_i_e_d_d_d_d_s_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL} /* 23.1+23  */,
    i_i_i_i_i_i_e_d_d_d_d_d_s_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL} /* 23.2+23  */,
    i_i_i_i_i_e_d_d_d_d_d_d_s_i_i_i = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL} /* 23.3+23  */,
    i_i_i_i_e_d_d_d_d_d_d_d_s_i_i_i = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL} /* 23.4+23  */,
    i_i_i_e_d_d_d_d_d_d_d_d_s_i_i_i = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL} /* 23.5+23  */,
    i_i_e_d_d_d_d_d_d_d_d_d_s_i_i_i = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL} /* 23.6+23  */,
    i_e_d_d_d_d_d_d_d_d_d_d_s_i_i_i = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL} /* 23.7+23  */,
    e_d_d_d_d_d_d_d_d_d_d_d_s_i_i_i = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL} /* 23.8+23  */,
    d_d_d_d_d_d_d_d_d_d_d_d_s_i_i_i = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL} /* 24+23  */,
    i_i_i_i_i_i_i_i_i_e_d_s_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, IDL, IDL, IDL, IDL} /* 25+23  */,
    i_i_i_i_i_i_i_i_e_d_d_s_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, IDL, IDL, IDL, IDL} /* 26.0+23  */,
    i_i_i_i_i_i_i_e_d_d_d_s_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL} /* 26.1+23  */,
    i_i_i_i_i_i_e_d_d_d_d_s_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL} /* 26.2+23  */,
    i_i_i_i_i_e_d_d_d_d_d_s_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL} /* 26.3+23  */,
    i_i_i_i_e_d_d_d_d_d_d_s_i_i_i_i = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL} /* 26.4+23  */,
    i_i_i_e_d_d_d_d_d_d_d_s_i_i_i_i = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL} /* 26.5+23  */,
    i_i_e_d_d_d_d_d_d_d_d_s_i_i_i_i = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL} /* 26.6+23  */,
    i_e_d_d_d_d_d_d_d_d_d_s_i_i_i_i = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL} /* 26.7+23  */,
    e_d_d_d_d_d_d_d_d_d_d_s_i_i_i_i = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL} /* 26.8+23  */,
    d_d_d_d_d_d_d_d_d_d_d_s_i_i_i_i = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL} /* 27+23  */,
    i_i_i_i_i_i_i_i_e_d_s_i_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, IDL, IDL, IDL, IDL, IDL} /* 28.0+23  */,
    i_i_i_i_i_i_i_e_d_d_s_i_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL} /* 28.1+23  */,
    i_i_i_i_i_i_e_d_d_d_s_i_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL} /* 28.2+23  */,
    i_i_i_i_i_e_d_d_d_d_s_i_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL} /* 28.3+23  */,
    i_i_i_i_e_d_d_d_d_d_s_i_i_i_i_i = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL} /* 28.4+23  */,
    i_i_i_e_d_d_d_d_d_d_s_i_i_i_i_i = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL} /* 28.5+23  */,
    i_i_e_d_d_d_d_d_d_d_s_i_i_i_i_i = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL} /* 28.6+23  */,
    i_e_d_d_d_d_d_d_d_d_s_i_i_i_i_i = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL} /* 28.7+23  */,
    e_d_d_d_d_d_d_d_d_d_s_i_i_i_i_i = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL} /* 28.8+23  */,
    d_d_d_d_d_d_d_d_d_d_s_i_i_i_i_i = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL} /* 29+23  */,
    i_i_i_i_i_i_i_e_d_s_i_i_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL} /* 30.0+23  */,
    i_i_i_i_i_i_e_d_d_s_i_i_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL} /* 30.1+23  */,
    i_i_i_i_i_e_d_d_d_s_i_i_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL} /* 30.2+23  */,
    i_i_i_i_e_d_d_d_d_s_i_i_i_i_i_i = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL} /* 30.3+23  */,
    i_i_i_e_d_d_d_d_d_s_i_i_i_i_i_i = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL} /* 30.4+23  */,
    i_i_e_d_d_d_d_d_d_s_i_i_i_i_i_i = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL} /* 30.5+23  */,
    i_e_d_d_d_d_d_d_d_s_i_i_i_i_i_i = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL} /* 30.6+23  */,
    e_d_d_d_d_d_d_d_d_s_i_i_i_i_i_i = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL} /* 30.7+23  */,
    d_d_d_d_d_d_d_d_d_s_i_i_i_i_i_i = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL} /* 30.8+23  */,
    i_i_i_i_i_i_e_d_s_i_i_i_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.0+23  */,
    i_i_i_i_i_e_d_d_s_i_i_i_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.1+23  */,
    i_i_i_i_e_d_d_d_s_i_i_i_i_i_i_i = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.2+23  */,
    i_i_i_e_d_d_d_d_s_i_i_i_i_i_i_i = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.3+23  */,
    i_i_e_d_d_d_d_d_s_i_i_i_i_i_i_i = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.4+23  */,
    i_e_d_d_d_d_d_d_s_i_i_i_i_i_i_i = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.5+23  */,
    e_d_d_d_d_d_d_d_s_i_i_i_i_i_i_i = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.6+23  */,
    d_d_d_d_d_d_d_d_s_i_i_i_i_i_i_i = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.7+23  */,
    i_i_i_i_i_e_d_s_i_i_i_i_i_i_i_i = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.8+23  */,
    i_i_i_i_e_d_d_s_i_i_i_i_i_i_i_i = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.9+23  */,
    i_i_i_e_d_d_d_s_i_i_i_i_i_i_i_i = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.10+23  */,
    i_i_e_d_d_d_d_s_i_i_i_i_i_i_i_i = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.11+23  */,
    i_e_d_d_d_d_d_s_i_i_i_i_i_i_i_i = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.12+23  */,
    e_d_d_d_d_d_d_s_i_i_i_i_i_i_i_i = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.13+23  */,
    d_d_d_d_d_d_d_s_i_i_i_i_i_i_i_i = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.14+23  */,
    i_i_i_i_e_d_s_i_i_i_i_i_i_i_i_i = {IDL, IDL, IDL, IDL, EOT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.15+23  */,
    i_i_i_e_d_d_s_i_i_i_i_i_i_i_i_i = {IDL, IDL, IDL, EOT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.16+23  */,
    i_i_e_d_d_d_s_i_i_i_i_i_i_i_i_i = {IDL, IDL, EOT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.17+23  */,
    i_e_d_d_d_d_s_i_i_i_i_i_i_i_i_i = {IDL, EOT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.18+23  */,
    e_d_d_d_d_d_s_i_i_i_i_i_i_i_i_i = {EOT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.19+23  */,
    d_d_d_d_d_d_s_i_i_i_i_i_i_i_i_i = {DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.20+23  */,
    i_i_i_e_d_s_i_i_i_i_i_i_i_i_i_i = {IDL, IDL, IDL, EOT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.21+23  */,
    i_i_e_d_d_s_i_i_i_i_i_i_i_i_i_i = {IDL, IDL, EOT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.22+23  */,
    i_e_d_d_d_s_i_i_i_i_i_i_i_i_i_i = {IDL, EOT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.23+23  */,
    e_d_d_d_d_s_i_i_i_i_i_i_i_i_i_i = {EOT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.24+23  */,
    d_d_d_d_d_s_i_i_i_i_i_i_i_i_i_i = {DAT, DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.25+23  */,
    i_i_e_d_s_i_i_i_i_i_i_i_i_i_i_i = {IDL, IDL, EOT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.26+23  */,
    i_e_d_d_s_i_i_i_i_i_i_i_i_i_i_i = {IDL, EOT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.27+23  */,
    e_d_d_d_s_i_i_i_i_i_i_i_i_i_i_i = {EOT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.28+23  */,
    d_d_d_d_s_i_i_i_i_i_i_i_i_i_i_i = {DAT, DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.29+23  */,
    i_e_d_s_i_i_i_i_i_i_i_i_i_i_i_i = {IDL, EOT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.30+23  */,
    e_d_d_s_i_i_i_i_i_i_i_i_i_i_i_i = {EOT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.31+23  */,
    d_d_d_s_i_i_i_i_i_i_i_i_i_i_i_i = {DAT, DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.32+23  */,
    e_d_s_i_i_i_i_i_i_i_i_i_i_i_i_i = {EOT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.33+23  */,
    d_d_s_i_i_i_i_i_i_i_i_i_i_i_i_i = {DAT, DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.34+23  */,
    d_s_i_i_i_i_i_i_i_i_i_i_i_i_i_i = {DAT, SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.35+23  */,
    s_i_i_i_i_i_i_i_i_i_i_i_i_i_i_i = {SOT, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL} /* 31.36+23  */,
    i_i_i_i_i_i_i_i_i_i_i_i_e_d_s_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, SOT, IDL} /* 33+23  */,
    i_i_i_i_i_i_i_i_i_i_i_e_d_d_s_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, SOT, IDL} /* 34+23  */,
    i_i_i_i_i_i_i_i_i_i_e_d_d_d_s_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, SOT, IDL} /* 35+23  */,
    i_i_i_i_i_i_i_i_i_e_d_d_d_d_s_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, SOT, IDL} /* 36+23  */,
    i_i_i_i_i_i_i_i_e_d_d_d_d_d_s_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, SOT, IDL} /* 37.0+23  */,
    i_i_i_i_i_i_i_e_d_d_d_d_d_d_s_i = {IDL, IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL} /* 37.1+23  */,
    i_i_i_i_i_i_e_d_d_d_d_d_d_d_s_i = {IDL, IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL} /* 37.2+23  */,
    i_i_i_i_i_e_d_d_d_d_d_d_d_d_s_i = {IDL, IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL} /* 37.3+23  */,
    i_i_i_i_e_d_d_d_d_d_d_d_d_d_s_i = {IDL, IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL} /* 37.4+23  */,
    i_i_i_e_d_d_d_d_d_d_d_d_d_d_s_i = {IDL, IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL} /* 37.5+23  */,
    i_i_e_d_d_d_d_d_d_d_d_d_d_d_s_i = {IDL, IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL} /* 37.6+23  */,
    i_e_d_d_d_d_d_d_d_d_d_d_d_d_s_i = {IDL, EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL} /* 37.7+23  */,
    e_d_d_d_d_d_d_d_d_d_d_d_d_d_s_i = {EOT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL} /* 37.8+23  */,
    d_d_d_d_d_d_d_d_d_d_d_d_d_d_s_i = {DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, DAT, SOT, IDL} /* 38+23  */
} dec_input_vec_t;
dec_input_vec_t dec_input_vec;
assign dec_input_vec = dec_input_vec_t'(tmp_dec_input_vec);

// insert overhead into the datapath
always @(*) begin : next_m_edata_PROC

    next_m_pkt_pending = 1'b1;
    dllp_xmt_halt = (edb) ? 1 : ~int_dllp_xmt_req; // by default halt dllp when edb, exceptions to the rule are handled case by case in the case items

    unique case ( dec_input_vec )
        i_i_i_i_i_i_i_i_i_i_i_i_i_e_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d2,    d1,    d0,   stp};
        end
        i_i_i_i_i_i_i_i_i_i_i_i_e_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0,   stp};
        end
        i_i_i_i_i_i_i_i_i_i_i_e_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d4,    d3,    d2,    d1,    d0,   stp};
        end
        i_i_i_i_i_i_i_i_i_i_e_d_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
        end
        i_i_i_i_i_i_i_i_i_e_d_d_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
        end
        i_i_i_i_i_i_i_i_e_d_d_d_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
        end
        i_i_i_i_i_i_i_e_d_d_d_d_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
        end
        i_i_i_i_i_i_e_d_d_d_d_d_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
        end
        i_i_i_i_i_e_d_d_d_d_d_d_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
        end
        i_i_i_i_e_d_d_d_d_d_d_d_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
        end
        i_i_i_e_d_d_d_d_d_d_d_d_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e01,   e00,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
        end
        i_i_e_d_d_d_d_d_d_d_d_d_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e01,   e00,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, dllp1, dllp0,  e000,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
        end
        i_e_d_d_d_d_d_d_d_d_d_d_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e01,   e00,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, dllp1, dllp0,  e000,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
        end
        e_d_d_d_d_d_d_d_d_d_d_d_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e01,   e00,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, dllp1, dllp0,  e000,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
        end
        d_d_d_d_d_d_d_d_d_d_d_d_d_d_d_s : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0,   stp};
            dllp_xmt_halt = 1; // dllp cannot be inserted in this cycle (because we do not have an EOT)
        end
        i_i_i_i_i_i_i_i_i_i_i_i_i_i_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_i_i_i_i_i_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_i_i_i_i_e_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_i_i_i_e_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_i_i_e_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_i_e_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_e_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_e_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_e_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_e_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_e_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_e_d_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_e_d_d_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e01,   e00,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_e_d_d_d_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e01,   e00,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, dllp1, dllp0,  e000,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        e_d_d_d_d_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e01,   e00,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, dllp1, dllp0,  e000,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        d_d_d_d_d_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            dllp_xmt_halt = 1; // dllp cannot be inserted in this cycle (because we do not have an EOT)
        end
        i_i_i_i_i_i_i_i_i_i_i_e_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_i_i_e_d_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d5,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_i_e_d_d_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d6,    d5,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_e_d_d_d_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d7,    d6,    d5,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        i_i_i_i_i_i_i_e_d_d_d_d_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        i_i_i_i_i_i_e_d_d_d_d_d_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        i_i_i_i_i_e_d_d_d_d_d_d_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        i_i_i_i_e_d_d_d_d_d_d_d_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        i_i_i_e_d_d_d_d_d_d_d_d_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        i_i_e_d_d_d_d_d_d_d_d_d_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = { __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        i_e_d_d_d_d_d_d_d_d_d_d_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = { __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        e_d_d_d_d_d_d_d_d_d_d_d_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        d_d_d_d_d_d_d_d_d_d_d_d_d_s_e_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp,  e000,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0,  e000,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_i_i_e_d_s_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d5,    d4,    d3,   stp,  e000,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d5,    d4,    d3,   stp, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_i_e_d_d_s_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d6,    d5,    d4,    d3,   stp,  e000,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_e_d_d_d_s_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d7,    d6,    d5,    d4,    d3,   stp,  e000,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_e_d_d_d_d_s_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d8,    d7,    d6,    d5,    d4,    d3,   stp,  e000,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_e_d_d_d_d_d_s_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp,  e000,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        i_i_i_i_i_e_d_d_d_d_d_d_s_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp,  e000,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        i_i_i_i_e_d_d_d_d_d_d_d_s_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp,  e000,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        i_i_i_e_d_d_d_d_d_d_d_d_s_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp,  e000,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        i_i_e_d_d_d_d_d_d_d_d_d_s_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp,  e000,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        i_e_d_d_d_d_d_d_d_d_d_d_s_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp,  e000,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        e_d_d_d_d_d_d_d_d_d_d_d_s_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp,  e000,    d2,    d1,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        d_d_d_d_d_d_d_d_d_d_d_d_s_e_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp,  e000,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0,  e000,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_i_e_d_s_e_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d6,    d5,    d4,   stp,  e000,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d6,    d5,    d4,   stp, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_e_d_d_s_e_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d7,    d6,    d5,    d4,   stp,  e000,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_e_d_d_d_s_e_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d8,    d7,    d6,    d5,    d4,   stp,  e000,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_e_d_d_d_d_s_e_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,    d6,    d5,    d4,   stp,  e000,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_e_d_d_d_d_d_s_e_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp,  e000,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_e_d_d_d_d_d_d_s_e_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp,  e000,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0};
        end
        i_i_i_e_d_d_d_d_d_d_d_s_e_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp,  e000,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0};
        end
        i_i_e_d_d_d_d_d_d_d_d_s_e_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp,  e000,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0};
        end
        i_e_d_d_d_d_d_d_d_d_d_s_e_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp,  e000,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0};
        end
        e_d_d_d_d_d_d_d_d_d_d_s_e_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp,  e000,    d3,    d2,    d1,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0};
        end
        d_d_d_d_d_d_d_d_d_d_d_s_e_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp,  e000,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0,  e000,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_e_d_s_e_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d7,    d6,    d5,   stp,  e000,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d7,    d6,    d5,   stp, dllp1, dllp0,  e000,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_e_d_d_s_e_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d8,    d7,    d6,    d5,   stp,  e000,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0,  e000,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_e_d_d_d_s_e_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,    d6,    d5,   stp,  e000,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0,  e000,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_e_d_d_d_d_s_e_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,    d6,    d5,   stp,  e000,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0,  e000,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_e_d_d_d_d_d_s_e_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp,  e000,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0,  e000,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_e_d_d_d_d_d_d_s_e_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp,  e000,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0,  e000,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_e_d_d_d_d_d_d_d_s_e_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp,  e000,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0,  e000,    d4,    d3,    d2,    d1,    d0};
        end
        i_e_d_d_d_d_d_d_d_d_s_e_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp,  e000,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0,  e000,    d4,    d3,    d2,    d1,    d0};
        end
        e_d_d_d_d_d_d_d_d_d_s_e_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp,  e000,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0,  e000,    d4,    d3,    d2,    d1,    d0};
        end
        d_d_d_d_d_d_d_d_d_d_s_e_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp,  e000,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0,  e000,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_e_d_s_e_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d8,    d7,    d6,   stp,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d8,    d7,    d6,   stp, dllp1, dllp0,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_e_d_d_s_e_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,    d6,   stp,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_e_d_d_d_s_e_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,    d6,   stp,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_e_d_d_d_d_s_e_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,    d6,   stp,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_e_d_d_d_d_d_s_e_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_e_d_d_d_d_d_d_s_e_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_e_d_d_d_d_d_d_d_s_e_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        e_d_d_d_d_d_d_d_d_s_e_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        d_d_d_d_d_d_d_d_d_s_e_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0,  e000,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_e_d_s_e_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,   stp,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,   stp, dllp1, dllp0,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_e_d_d_s_e_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,   stp,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_e_d_d_d_s_e_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,   stp,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_e_d_d_d_d_s_e_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,   stp,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_e_d_d_d_d_d_s_e_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_e_d_d_d_d_d_d_s_e_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        e_d_d_d_d_d_d_d_s_e_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        d_d_d_d_d_d_d_d_s_e_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0,  e000,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_e_d_s_e_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,   stp,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,   stp, dllp1, dllp0,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_e_d_d_s_e_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,   stp,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,   stp, dllp1, dllp0,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_e_d_d_d_s_e_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,   stp,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,   stp, dllp1, dllp0,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_e_d_d_d_d_s_e_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,   stp,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,   stp, dllp1, dllp0,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_e_d_d_d_d_d_s_e_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,   stp,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,   stp, dllp1, dllp0,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        e_d_d_d_d_d_d_s_e_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,   stp,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,   stp, dllp1, dllp0,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        d_d_d_d_d_d_d_s_e_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,   stp,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,   stp, dllp1, dllp0,  e000,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_e_d_s_e_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,   stp,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,   stp, dllp1, dllp0,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_e_d_d_s_e_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,   stp,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,   stp, dllp1, dllp0,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_e_d_d_d_s_e_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,   stp,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,   stp, dllp1, dllp0,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_e_d_d_d_d_s_e_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,   stp,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,   stp, dllp1, dllp0,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        e_d_d_d_d_d_s_e_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,   stp,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,   stp, dllp1, dllp0,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        d_d_d_d_d_d_s_e_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,   stp,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,   stp, dllp1, dllp0,  e000,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_e_d_s_e_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,   stp,  e000,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__, __i__,  e100,   d12,   d11,   d10,   stp, dllp1, dllp0,  e000,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_e_d_d_s_e_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,   stp,  e000,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__,  e100,   d13,   d12,   d11,   d10,   stp, dllp1, dllp0,  e000,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_e_d_d_d_s_e_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,   stp,  e000,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,  e100,   d14,   d13,   d12,   d11,   d10,   stp, dllp1, dllp0,  e000,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        e_d_d_d_d_s_e_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,   stp,  e000,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   d12,   d11,   d10,   stp, dllp1, dllp0,  e000,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        d_d_d_d_d_s_e_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,   stp,  e000,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   d12,   d11,   d10,   stp, dllp1, dllp0,  e000,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_e_d_s_e_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   stp,  e000,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__, __i__,  e100,   d13,   d12,   d11,   stp, dllp1, dllp0,  e000,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_e_d_d_s_e_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   stp,  e000,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,  e100,   d14,   d13,   d12,   d11,   stp, dllp1, dllp0,  e000,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        e_d_d_d_s_e_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   stp,  e000,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   d12,   d11,   stp, dllp1, dllp0,  e000,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        d_d_d_d_s_e_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   stp,  e000,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   d12,   d11,   stp, dllp1, dllp0,  e000,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_e_d_s_e_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e11,   e10,   d14,   d13,   d12,   stp,  e000,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,  e100,   d14,   d13,   d12,   stp, dllp1, dllp0,  e000,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        e_d_d_s_e_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   d12,   stp,  e000,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   d12,   stp, dllp1, dllp0,  e000,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        d_d_d_s_e_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   stp,  e000,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   d12,   stp, dllp1, dllp0,  e000,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        e_d_s_e_d_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   stp,  e000,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   stp, dllp1, dllp0,  e000,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        d_d_s_e_d_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   stp,  e000,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   stp, dllp1, dllp0,  e000,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        d_s_e_d_d_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   stp,  e000,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   stp, dllp1, dllp0,  e000,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        s_e_d_d_d_d_d_d_d_d_d_d_d_d_d_d : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   stp,  e000,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
            else                        next_m_edata = { __i__,   d15,   stp, dllp1, dllp0,  e000,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,    d0};
        end
        i_i_i_i_i_i_i_i_i_i_i_i_i_i_i_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e01,   e00,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0,  e000,    d0};
        end
        i_i_i_i_i_i_i_i_i_i_i_i_e_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        i_i_i_i_i_i_i_i_i_i_i_e_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        i_i_i_i_i_i_i_i_i_i_e_d_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d5,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        i_i_i_i_i_i_i_i_i_e_d_d_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d6,    d5,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        i_i_i_i_i_i_i_i_e_d_d_d_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        i_i_i_i_i_i_i_e_d_d_d_d_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        i_i_i_i_i_i_e_d_d_d_d_d_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        i_i_i_i_i_e_d_d_d_d_d_d_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        i_i_i_i_e_d_d_d_d_d_d_d_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        i_i_i_e_d_d_d_d_d_d_d_d_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        i_i_e_d_d_d_d_d_d_d_d_d_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        i_e_d_d_d_d_d_d_d_d_d_d_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        e_d_d_d_d_d_d_d_d_d_d_d_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = {  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        d_d_d_d_d_d_d_d_d_d_d_d_d_d_s_e : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp,  e000,    d0};
            else                        next_m_edata = { __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0,  e000,    d0};
        end
        i_i_i_i_i_i_i_i_i_i_i_e_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_i_i_e_d_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d5,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_i_e_d_d_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d6,    d5,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_e_d_d_d_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d7,    d6,    d5,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_e_d_d_d_d_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_e_d_d_d_d_d_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_e_d_d_d_d_d_d_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        i_i_i_i_e_d_d_d_d_d_d_d_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        i_i_i_e_d_d_d_d_d_d_d_d_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        i_i_e_d_d_d_d_d_d_d_d_d_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        i_e_d_d_d_d_d_d_d_d_d_d_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        e_d_d_d_d_d_d_d_d_d_d_d_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__,  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        d_d_d_d_d_d_d_d_d_d_d_d_d_s_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_i_i_e_d_s_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d5,    d4,    d3,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d5,    d4,    d3,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_i_e_d_d_s_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d6,    d5,    d4,    d3,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_e_d_d_d_s_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d7,    d6,    d5,    d4,    d3,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_e_d_d_d_d_s_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d8,    d7,    d6,    d5,    d4,    d3,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_e_d_d_d_d_d_s_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_e_d_d_d_d_d_d_s_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0};
        end
        i_i_i_i_e_d_d_d_d_d_d_d_s_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0};
        end
        i_i_i_e_d_d_d_d_d_d_d_d_s_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0};
        end
        i_i_e_d_d_d_d_d_d_d_d_d_s_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0};
        end
        i_e_d_d_d_d_d_d_d_d_d_d_s_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0};
        end
        e_d_d_d_d_d_d_d_d_d_d_d_s_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0};
        end
        d_d_d_d_d_d_d_d_d_d_d_d_s_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_i_e_d_s_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d6,    d5,    d4,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d6,    d5,    d4,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_e_d_d_s_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d7,    d6,    d5,    d4,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_e_d_d_d_s_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d8,    d7,    d6,    d5,    d4,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_e_d_d_d_d_s_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,    d6,    d5,    d4,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_e_d_d_d_d_d_s_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0};
        end
        i_i_i_i_e_d_d_d_d_d_d_s_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0};
        end
        i_i_i_e_d_d_d_d_d_d_d_s_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0};
        end
        i_i_e_d_d_d_d_d_d_d_d_s_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0};
        end
        i_e_d_d_d_d_d_d_d_d_d_s_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0};
        end
        e_d_d_d_d_d_d_d_d_d_d_s_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0};
        end
        d_d_d_d_d_d_d_d_d_d_d_s_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_e_d_s_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d7,    d6,    d5,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d7,    d6,    d5,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_e_d_d_s_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d8,    d7,    d6,    d5,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_e_d_d_d_s_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,    d6,    d5,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_e_d_d_d_d_s_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,    d6,    d5,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0};
        end
        i_i_i_i_e_d_d_d_d_d_s_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0};
        end
        i_i_i_e_d_d_d_d_d_d_s_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0};
        end
        i_i_e_d_d_d_d_d_d_d_s_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0};
        end
        i_e_d_d_d_d_d_d_d_d_s_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0};
        end
        e_d_d_d_d_d_d_d_d_d_s_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0};
        end
        d_d_d_d_d_d_d_d_d_d_s_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_e_d_s_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d8,    d7,    d6,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d8,    d7,    d6,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_e_d_d_s_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,    d6,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_e_d_d_d_s_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,    d6,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0};
        end
        i_i_i_i_e_d_d_d_d_s_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,    d6,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0};
        end
        i_i_i_e_d_d_d_d_d_s_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0};
        end
        i_i_e_d_d_d_d_d_d_s_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0};
        end
        i_e_d_d_d_d_d_d_d_s_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0};
        end
        e_d_d_d_d_d_d_d_d_s_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0};
        end
        d_d_d_d_d_d_d_d_d_s_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_e_d_s_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_e_d_d_s_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0};
        end
        i_i_i_i_e_d_d_d_s_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0};
        end
        i_i_i_e_d_d_d_d_s_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0};
        end
        i_i_e_d_d_d_d_d_s_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0};
        end
        i_e_d_d_d_d_d_d_s_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0};
        end
        e_d_d_d_d_d_d_d_s_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0};
        end
        d_d_d_d_d_d_d_d_s_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_e_d_s_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,   stp, dllp1, dllp0};
        end
        i_i_i_i_e_d_d_s_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,   stp, dllp1, dllp0};
        end
        i_i_i_e_d_d_d_s_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,   stp, dllp1, dllp0};
        end
        i_i_e_d_d_d_d_s_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,   stp, dllp1, dllp0};
        end
        i_e_d_d_d_d_d_s_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,   stp, dllp1, dllp0};
        end
        e_d_d_d_d_d_d_s_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,   stp, dllp1, dllp0};
        end
        d_d_d_d_d_d_d_s_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,   stp, dllp1, dllp0};
        end
        i_i_i_i_e_d_s_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,   stp, dllp1, dllp0};
        end
        i_i_i_e_d_d_s_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,   stp, dllp1, dllp0};
        end
        i_i_e_d_d_d_s_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,   stp, dllp1, dllp0};
        end
        i_e_d_d_d_d_s_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,   stp, dllp1, dllp0};
        end
        e_d_d_d_d_d_s_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,   stp, dllp1, dllp0};
        end
        d_d_d_d_d_d_s_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,   stp, dllp1, dllp0};
        end
        i_i_i_e_d_s_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d12,   d11,   d10,   stp, dllp1, dllp0};
        end
        i_i_e_d_d_s_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d13,   d12,   d11,   d10,   stp, dllp1, dllp0};
        end
        i_e_d_d_d_s_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d14,   d13,   d12,   d11,   d10,   stp, dllp1, dllp0};
        end
        e_d_d_d_d_s_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d15,   d14,   d13,   d12,   d11,   d10,   stp, dllp1, dllp0};
        end
        d_d_d_d_d_s_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,   stp, dllp1, dllp0};
        end
        i_i_e_d_s_i_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d13,   d12,   d11,   stp, dllp1, dllp0};
        end
        i_e_d_d_s_i_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d14,   d13,   d12,   d11,   stp, dllp1, dllp0};
        end
        e_d_d_d_s_i_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d15,   d14,   d13,   d12,   d11,   stp, dllp1, dllp0};
        end
        d_d_d_d_s_i_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   stp, dllp1, dllp0};
        end
        i_e_d_s_i_i_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d14,   d13,   d12,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d14,   d13,   d12,   stp, dllp1, dllp0};
        end
        e_d_d_s_i_i_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   d12,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d15,   d14,   d13,   d12,   stp, dllp1, dllp0};
        end
        d_d_d_s_i_i_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   stp, dllp1, dllp0};
        end
        e_d_s_i_i_i_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d15,   d14,   d13,   stp, dllp1, dllp0};
        end
        d_d_s_i_i_i_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   stp, dllp1, dllp0};
        end
        d_s_i_i_i_i_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   d14,   stp, dllp1, dllp0};
        end
        s_i_i_i_i_i_i_i_i_i_i_i_i_i_i_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   d15,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_i_i_i_i_e_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_i_i_i_e_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_i_i_e_d_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d5,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_i_e_d_d_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d6,    d5,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_i_e_d_d_d_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_i_e_d_d_d_d_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_i_e_d_d_d_d_d_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        i_i_i_i_i_e_d_d_d_d_d_d_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        i_i_i_i_e_d_d_d_d_d_d_d_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,  e100,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        i_i_i_e_d_d_d_d_d_d_d_d_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__, __i__,  e100,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        i_i_e_d_d_d_d_d_d_d_d_d_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   e11,   e10,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__, __i__,  e100,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        i_e_d_d_d_d_d_d_d_d_d_d_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__,   e11,   e10,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__,  e100,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        e_d_d_d_d_d_d_d_d_d_d_d_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__,   e11,   e10,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__,  e100,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end
        d_d_d_d_d_d_d_d_d_d_d_d_d_d_s_i : begin
            if(!int_dllp_xmt_req | edb) next_m_edata = { __i__, __i__, __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp};
            else                        next_m_edata = { __i__, __i__, __i__,   d15,   d14,   d13,   d12,   d11,   d10,    d9,    d8,    d7,    d6,    d5,    d4,    d3,    d2,    d1,   stp, dllp1, dllp0};
        end

        default /* i_i_i_i_i_i_i_i_i_i_i_i_i_i_i_i */ : begin //- if PM DLLP then replicate across the line; while ensuring SDP/END must not be placed on the Link more frequently than once per Symbol Time
            if(!int_dllp_xmt_req | edb) next_m_edata = {__i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__};
            else if (input_dllp[23:20] == 4'h2) next_m_edata = {__i__,__i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0, __i__, __i__, dllp1, dllp0, __i__, __i__, dllp1, dllp0, __i__, __i__, dllp1, dllp0};
            else                        next_m_edata = {__i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, __i__, dllp1, dllp0};
            next_m_pkt_pending = int_dllp_xmt_req; // the only case where pending can be set to 0 is when hit this case and no dllp
        end
    endcase
end // next_m_edata_PROC

// www: revisit, is this logic really necessary?, Cant we just use the input controls directly?
function automatic [1:0] dec_input(input sot, eot, dwen);
    begin
        if(dwen == 1'b0) dec_input = IDL;
        else if(sot == 1'b1) dec_input = SOT;
        else if(eot == 1'b1) dec_input = EOT;
        else dec_input = DAT;
    end
endfunction

`ifndef SYNTHESIS
//VCS coverage off
// check that after edb there are only idles, return 0 if check fails
function chk_edb_fb_all_idles(input [NW-1:0] edb, dwen);
    integer i, j;
    begin
        chk_edb_fb_all_idles = 1;
        for(i=0; i<NW-1; i=i+1) begin
            if( edb[i] ) begin
                for(j=i+1; j<NW; j=j+1) begin
                    if( dwen[j] ) begin
                        chk_edb_fb_all_idles = 0;
                    end
                end
            end
        end
    end
endfunction
always @(posedge core_clk) begin : chk_edb_fb_all_idles_PROC
    if((core_rst_n===1'b1) && (input_dv===1'b1) && (chk_edb_fb_all_idles(input_edb, input_dwen) == 0)) $display("%0d %m: ERROR: detected datapath with edb and not all idles afterwards", $time);
end
//VCS coverage on
`endif


endmodule // xdlh_tlp_gen_512b_merge
