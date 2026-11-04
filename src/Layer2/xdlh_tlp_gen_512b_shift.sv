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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_tlp_gen_512b_shift.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description: Storage and shifting after inserting Layer2 and Layer1 overhead.
// -----------------------------------------------------------------------------
//
// After inserting Layer2 and Layer1 overhead the TLP datapath can expand up to 21 dwords. This can be easily seen
// considering the worst case of a TLP datapath consisting of 2xEOTs + 1xSOT, plus the insertion of 1 DLLP => total 
// overhead = 5 dwords. The shift register is unable to transmit unless there are more than 15 dwords in Gen3 and 16
// dwords in Gen1/Gen2, therefore the total storage capacity of the shift register must be:
// 16 dwords + 21 dwords = 37 dwords.
// The reason for the difference between Gen1/Gen2 and Gen3 is because in Gen1/Gen2 STP is 24bits instead of 32 
// and we need extra 8 bits of data for assembling a full valid datapath for transmission.


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xdlh_tlp_gen_512b_shift
#(
parameter NW = 16,// number of dwords in the input datapath, this module only supports 16
parameter MNW = NW+5,  // number of dwords in the merged datapath, after insertion of one DLLP, one STP, two LCRCs, a 16 DWs input datapath can expand into 21 DWs
parameter SNW = 37,  // number of dwords in the shift register
parameter CW = 5,  // control width, number of control bits {edb, sdp, dwen, eot, sot} for one dword 
parameter TP = `TP
)
(
// ---- inputs ---------------
input                          core_clk,
input                          core_rst_n,
input [MNW*(32+CW)-1:0]        merged_edata, // merged input datapath, for 512b consists of 21 words 32+CW bits each
input                          merged_edata_pkt_pending,  // merged data contains a packet
input                          xmlh_skip_pending, // used here detect when the fifo can be halted following an end and all idles
input                          input_halt, // pause advancement of the shift register 
input                          data_rate_is_gen3,
// ---- outputs ---------------
output                         out_dllp_halt,
output [NW*32-1:0]             output_data,
output [NW-1:0]                output_sot, // start of TLP
output [NW-1:0]                output_eot, // end of TLP/DLLP
output [NW-1:0]                output_dwen, // TLP/DLLP
output [NW-1:0]                output_sdp, // start of DLLP
output                         output_halt, // pause the processing of the input datapath
output                         output_skip_halt,
output                         output_dv // output data is valid
,output                         tlpgen_pkt_pending // TLP has been registered and is pending transmission
);

localparam EDB_BIT = 4;
localparam SDP_BIT = 3;
localparam DWEN_BIT = 2;
localparam EOT_BIT = 1;
localparam SOT_BIT = 0;

wire [(32+CW)-1:0] m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0;
wire [(32+CW)-1:0] s36, s35, s34, s33, s32, s31, s30, s29, s28, s27, s26, s25, s24, s23, s22, s21, s20, s19, s18, s17, s16, s15, s14, s13, s12, s11, s10,  s9,  s8,  s7,  s6,  s5,  s4,  s3,  s2,  s1,  s0;
reg [SNW*(32+CW)-1:0] shift_edata; // accumulated + output datapath words (32b data + 5b control), the lower 16 words are transmitted, the upper 21 are accumulated
wire [SNW*(32+CW)-1:0] next_shift_edata;
wire next_shift_edata_pkt_pending;
reg shift_edata_pkt_pending;

wire [4:0] merged_dws_num;
wire [5:0] total_dws_num;
wire [4:0] next_accumulated_dws_num;
reg  [4:0] accumulated_dws_num;
wire [(32+CW)-1:0] ___ = 0; // do not care datapath  
wire [4:0] output_dws_num; // the number of DWs shifted out, it is usually NW for full shift, it can be 1..NW-1 for partial shift
wire [NW-1:0] output_edb;
wire [NW*32-1:0] gen3_output_data, gen12_output_data;
reg skip_pending_halt;
wire edb_detected_halt;
wire accumulated_dws_num_halt;
wire skip_pending_halt_set, skip_pending_halt_rst;
reg [SNW-1:0] shift_sot, shift_eot, shift_dwen, shift_sdp, shift_edb, next_shift_sot;

wire last_out_eot; 
wire [4:0] output_dws_num_gen3;
wire [4:0] output_dws_num_gen12;

wire [SNW:0] ext_shift_dwen;
reg [5:0] loaded_dws_num; 
wire en_shift;

assign out_dllp_halt = |shift_sdp[SNW-1:NW] | output_halt;


assign {m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0} = merged_edata;
assign {s36, s35, s34, s33, s32, s31, s30, s29, s28, s27, s26, s25, s24, s23, s22, s21, s20, s19, s18, s17, s16, s15, s14, s13, s12, s11, s10,  s9,  s8,  s7,  s6,  s5,  s4,  s3,  s2,  s1,  s0} = shift_edata;

// extract the dwen vector and calculate how many merged DWs are valid
assign merged_dws_num = 
                        m20[32+DWEN_BIT] ? 21 :
                        m19[32+DWEN_BIT] ? 20 :
                        m18[32+DWEN_BIT] ? 19 :
                        m17[32+DWEN_BIT] ? 18 :
                        m16[32+DWEN_BIT] ? 17 :
                        m15[32+DWEN_BIT] ? 16 :
                        m14[32+DWEN_BIT] ? 15 :
                        m13[32+DWEN_BIT] ? 14 :
                        m12[32+DWEN_BIT] ? 13 :
                        m11[32+DWEN_BIT] ? 12 :
                        m10[32+DWEN_BIT] ? 11 :
                        m9[32+DWEN_BIT] ? 10 :
                        m8[32+DWEN_BIT] ? 9 :
                        m7[32+DWEN_BIT] ? 8 :
                        m6[32+DWEN_BIT] ? 7 :
                        m5[32+DWEN_BIT] ? 6 :
                        m4[32+DWEN_BIT] ? 5 :
                        m3[32+DWEN_BIT] ? 4 :
                        m2[32+DWEN_BIT] ? 3 :
                        m1[32+DWEN_BIT] ? 2 :
                        m0[32+DWEN_BIT] ? 1 : 0;
                     
assign total_dws_num = {1'b0,merged_dws_num} + {1'b0,accumulated_dws_num};

assign last_out_eot = shift_eot[NW-1:0] > shift_sot[NW-1:0];

assign output_dws_num_gen3 = ((total_dws_num < 16) & !last_out_eot) ? 5'd0 : 5'd16;
assign output_dws_num_gen12 = ((total_dws_num < 17) & !last_out_eot) ? 5'd0 : 5'd16;


assign output_dws_num = data_rate_is_gen3 ? output_dws_num_gen3 : output_dws_num_gen12;


// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: total_dws_num - output_dws_num results in a number between 0 and 21. It can be truncated without loss over 5 bits.

assign next_accumulated_dws_num      = 
                                       !en_shift ? (((merged_dws_num + loaded_dws_num) > 16) ? (merged_dws_num + loaded_dws_num - 16) :  0) :
                                       (data_rate_is_gen3 ? (accumulated_dws_num > 15) : (accumulated_dws_num > 16)) ? (accumulated_dws_num - output_dws_num) : // this assumes we halt the fifo while we shift out the accumulated datapath
                                       (data_rate_is_gen3 ? (total_dws_num > 15) : (total_dws_num > 16)) ? (total_dws_num - output_dws_num) :                                      
                                       0;
// spyglass enable_block W164a

assign en_shift = (loaded_dws_num == 0) | last_out_eot | (loaded_dws_num > 15) & data_rate_is_gen3 | (loaded_dws_num > 16) & !data_rate_is_gen3; 

assign ext_shift_dwen  = {1'b0, shift_dwen};

always @(*) begin : loaded_dws_PROC

integer i; 
loaded_dws_num = 0; 

    for (i=0; i<SNW; i=i+1)  begin
       if (ext_shift_dwen[i] & !ext_shift_dwen[i+1])
            loaded_dws_num = i+1;
     end   
 end


assign next_shift_edata = 
               en_shift & (accumulated_dws_num ==  0)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0} :
               en_shift & (accumulated_dws_num ==  1)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s16} :
               en_shift & (accumulated_dws_num ==  2)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s17, s16} :
               en_shift & (accumulated_dws_num ==  3)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s18, s17, s16} :
               en_shift & (accumulated_dws_num ==  4)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num ==  5)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s20, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num ==  6)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s21, s20, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num ==  7)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s22, s21, s20, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num ==  8)  ? {___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s23, s22, s21, s20, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num ==  9)  ? {___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s24, s23, s22, s21, s20, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num == 10)  ? {___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s25, s24, s23, s22, s21, s20, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num == 11)  ? {___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s26, s25, s24, s23, s22, s21, s20, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num == 12)  ? {___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s27, s26, s25, s24, s23, s22, s21, s20, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num == 13)  ? {___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s28, s27, s26, s25, s24, s23, s22, s21, s20, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num == 14)  ? {___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s29, s28, s27, s26, s25, s24, s23, s22, s21, s20, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num == 15)  ? {___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s30, s29, s28, s27, s26, s25, s24, s23, s22, s21, s20, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num == 16)  ? {m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s31, s30, s29, s28, s27, s26, s25, s24, s23, s22, s21, s20, s19, s18, s17, s16} :
               en_shift & (accumulated_dws_num  > 16)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, s36, s35, s34, s33, s32, s31, s30, s29, s28, s27, s26, s25, s24, s23, s22, s21, s20, s19, s18, s17, s16} : // The max number of accumulated dwords that can be found in the shift register is SNW-NW=21.
              !en_shift & (loaded_dws_num      ==  1)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0,  s0} : // From here on the fifo is halted so no need to assign new merged data into the register
              !en_shift & (loaded_dws_num      ==  2)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0,  s1,  s0} :
              !en_shift & (loaded_dws_num      ==  3)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      ==  4)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0,  s3,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      ==  5)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0,  s4,  s3,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      ==  6)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0,  s5,  s4,  s3,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      ==  7)  ? {___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0,  s6,  s5,  s4,  s3,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      ==  8)  ? {___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0,  s7,  s6,  s5,  s4,  s3,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      ==  9)  ? {___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0,  s8,  s7,  s6,  s5,  s4,  s3,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      == 10)  ? {___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0,  s9,  s8,  s7,  s6,  s5,  s4,  s3,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      == 11)  ? {___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s10,  s9,  s8,  s7,  s6,  s5,  s4,  s3,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      == 12)  ? {___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s11, s10,  s9,  s8,  s7,  s6,  s5,  s4,  s3,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      == 13)  ? {___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s12, s11, s10,  s9,  s8,  s7,  s6,  s5,  s4,  s3,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      == 14)  ? {___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s13, s12, s11, s10,  s9,  s8,  s7,  s6,  s5,  s4,  s3,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      == 15)  ? {___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s14, s13, s12, s11, s10,  s9,  s8,  s7,  s6,  s5,  s4,  s3,  s2,  s1,  s0} :
              !en_shift & (loaded_dws_num      == 16)  ? {m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0, s15, s14, s13, s12, s11, s10,  s9,  s8,  s7,  s6,  s5,  s4,  s3,  s2,  s1,  s0} :
                                                         {___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, ___, m20, m19, m18, m17, m16, m15, m14, m13, m12, m11, m10,  m9,  m8,  m7,  m6,  m5,  m4,  m3,  m2,  m1,  m0} ;

assign next_shift_edata_pkt_pending = 
               en_shift & (accumulated_dws_num == 0)  ? merged_edata_pkt_pending :
               en_shift & (accumulated_dws_num  > 0)  ? 1'b1 :
              !en_shift & (loaded_dws_num       > 0)  ? 1'b1 :
                                                        merged_edata_pkt_pending ;

always @(posedge core_clk or negedge core_rst_n) begin : state_seq_PROC
    if ( !core_rst_n ) begin
        accumulated_dws_num <= #TP 0;
        shift_edata         <= #TP 0;
        shift_edata_pkt_pending <= #TP 0;
    end else begin
        if ( !input_halt ) begin
            accumulated_dws_num <= #TP next_accumulated_dws_num;
            shift_edata         <= #TP next_shift_edata;
            shift_edata_pkt_pending <= #TP next_shift_edata_pkt_pending;
        end
    end
end

always @(*) begin : shift_controls_PROC
    integer i;
    for(i=0; i<SNW; i=i+1) begin
        shift_sot[i]  = shift_edata[(32+CW)*i+32+SOT_BIT];
        shift_eot[i]  = shift_edata[(32+CW)*i+32+EOT_BIT];
        shift_dwen[i] = shift_edata[(32+CW)*i+32+DWEN_BIT];
        shift_sdp[i]  = shift_edata[(32+CW)*i+32+SDP_BIT];
        shift_edb[i]  = shift_edata[(32+CW)*i+32+EDB_BIT];
        next_shift_sot[i] = next_shift_edata[(32+CW)*i+32+SOT_BIT];
    end
end

// start halt logic
assign edb_detected_halt = |shift_edb; // after edb enters the shift reg halt the fifo until it is shifted out, needed to ensure sufficient idles to position stp/sdp correctly
assign accumulated_dws_num_halt = data_rate_is_gen3 ? (accumulated_dws_num > 15) : (accumulated_dws_num > 16); // halt the fifo when there is sufficient data accumulated in shift reg to create a full datapath cycle

assign skip_pending_halt_rst =  !output_dv;


always @(posedge core_clk or negedge core_rst_n) begin : skip_pending_halt_seq_PROC
    if ( !core_rst_n ) begin
        skip_pending_halt <= #TP 0;
    end else begin
        if( xmlh_skip_pending  & output_dv & !input_halt & !(accumulated_dws_num_halt | edb_detected_halt)) begin
            skip_pending_halt <= #TP 1;
        end else if ( skip_pending_halt_rst ) begin
            skip_pending_halt <= #TP 0;
        end
    end
end

reg skip_pending_halt_q;

always @(posedge core_clk or negedge core_rst_n) 
    if ( !core_rst_n )
       skip_pending_halt_q <= #TP 0;
    else if (!input_halt) skip_pending_halt_q <= #TP skip_pending_halt;
    

assign output_skip_halt = accumulated_dws_num_halt | edb_detected_halt | (skip_pending_halt  | skip_pending_halt_q) & xmlh_skip_pending;

assign output_halt = accumulated_dws_num_halt | edb_detected_halt | skip_pending_halt | xmlh_skip_pending  & output_dv;


// end halt logic

// start data valid logic
assign output_dv = shift_eot[15] | 
                   (~|shift_dwen[15]    & shift_eot[14]) |
                   (~|shift_dwen[15:14] & shift_eot[13]) |
                   (~|shift_dwen[15:13] & shift_eot[12]) |
                   (~|shift_dwen[15:12] & shift_eot[11]) |
                   (~|shift_dwen[15:11] & shift_eot[10]) |
                   (~|shift_dwen[15:10] & shift_eot[ 9]) |
                   (~|shift_dwen[15: 9] & shift_eot[ 8]) |
                   (~|shift_dwen[15: 8] & shift_eot[ 7]) |
                   (~|shift_dwen[15: 7] & shift_eot[ 6]) |
                   (~|shift_dwen[15: 6] & shift_eot[ 5]) |
                   (~|shift_dwen[15: 5] & shift_eot[ 4]) |
                   (~|shift_dwen[15: 4] & shift_eot[ 3]) |
                   (~|shift_dwen[15: 3] & shift_eot[ 2]) |
                   (~|shift_dwen[15: 2] & shift_eot[ 1]) |
                   (~|shift_dwen[15: 1] & shift_eot[ 0]) |
                   (data_rate_is_gen3 ? shift_dwen[15] : s16[32+DWEN_BIT]);

// end data valid logic

assign gen3_output_data  = {s15[31:0], s14[31:0], s13[31:0], s12[31:0], s11[31:0], s10[31:0], s9[31:0], s8[31:0], s7[31:0], s6[31:0], s5[31:0], s4[31:0], s3[31:0], s2[31:0], s1[31:0], s0[31:0]};
assign gen12_output_data = gen3_to_gen12_transform(s16[7:0], gen3_output_data[NW*32-1:0], output_edb[NW-1:0], output_eot [NW-1:0]);
assign output_data = data_rate_is_gen3 ? gen3_output_data : gen12_output_data;

assign output_sot  = output_dv ? shift_sot[NW-1:0] : {NW{1'b0}};
assign output_eot  = output_dv ? shift_eot[NW-1:0] : {NW{1'b0}};
assign output_dwen = output_dv ? shift_dwen[NW-1:0] :{NW{1'b0}};
assign output_sdp  = output_dv ? shift_sdp[NW-1:0] : {NW{1'b0}}; 
assign output_edb  = shift_edb[NW-1:0];


assign tlpgen_pkt_pending = shift_edata_pkt_pending 
                            || (next_shift_edata_pkt_pending && !input_halt); // assert pkt_pending on the cycle where we register a packet in the shift register

function automatic [NW*32-1:0] gen3_to_gen12_transform(input [7:0] extra_byte, input [NW*32-1:0] gen3_data, input [NW-1:0] edb, eot);
    integer i;
    begin
        // shift by 8 bits
        gen3_to_gen12_transform = {extra_byte[7:0], gen3_data[NW*32-1:8]};
        // insert EDB/END symbols
        for(i=0; i<NW; i=i+1) begin
            if(edb[i]) begin
                gen3_to_gen12_transform[32*(i+1)-1 -: 8] = `EDB_8B; // override most significant 8-bits with EDB 
            end else if(eot[i]) begin
                gen3_to_gen12_transform[32*(i+1)-1 -: 8] = `END_8B; // override most significant 8-bits with END 
            end
        end
    end
endfunction

endmodule // xdlh_tlp_gen_512b_shift
