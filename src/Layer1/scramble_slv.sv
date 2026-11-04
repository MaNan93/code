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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/scramble_slv.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// -- PCI-E scrambler - 16bit version (1 or 2 symbols per cycle)
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module scramble_slv (
    // Inputs
    core_rst_n,
    core_clk,
    scrambler_disable,
    scramble_en,
    data_dv,
    aligned,
    data,
    datak,
    error,
    wait4idle,
    skipremoved,
    active_nb,
    smlh_flit_mode_enable,

    // Outputs
    scramble_data_dv,
    scramble_aligned,
    scramble_data,
    scramble_data_comma,
    scramble_data_skip,
    scramble_data_skprm,
    scramble_datak,
    scramble_error,
    wait4idle_nd
);
parameter   INST    = 0;        // The uniquifying parameter for each port logic instance.
parameter   RX_SIDE = 1;        // Tx:0 / Rx:1
parameter   REGOUT  = 1;        // Optional output registering
parameter   NB      = `CX_NB;   // Number of symbols (bytes) per clock cycle
parameter   NBK     = `CX_NBK;  // Number of symbols (bytes) per clock cycle for datak
parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)


// ---------------------------------------------------------------------------------------------------
// IO Declarations
// ---------------------------------------------------------------------------------------------------
input                   core_rst_n;
input                   core_clk;
input                   scrambler_disable;  // disable scrambler
input                   scramble_en;
input                   data_dv;            // data bytes are valid
input                   aligned;            // data bytes are valid
input   [(NB*8)-1:0]    data;               // data bytes
input   [NBK-1:0]       datak;              // K character indication for each byte
input   [NB-1:0]        error;              // error indication for each byte
input                   wait4idle;
input                   skipremoved;        // skip symbols removed indication
input   [3:0]           active_nb;
input                   smlh_flit_mode_enable;

output                  scramble_data_dv;   // output is valid
output                  scramble_aligned;   // output is valid
output  [(NB*8)-1:0]    scramble_data;      // data bytes
output  [NB-1:0]        scramble_data_comma;// comma character indication for each byte
output  [NB-1:0]        scramble_data_skip; // skip character indication for each byte
output  [NB-1:0]        scramble_data_skprm;// COM & skipremoved (take lower COM if two COMs are in the clock)
output  [NBK-1:0]       scramble_datak;     // K character indication for each byte
output  [NB-1:0]        scramble_error;     // error indication for each byte
output  logic           wait4idle_nd;

// ---------------------------------------------------------------------------------------------------
// Regs & Wires
// ---------------------------------------------------------------------------------------------------
// Output registers
logic                   scramble_data_dv;   
logic                   scramble_aligned;   
logic   [(NB*8)-1:0]    scramble_data;      
logic   [NB-1:0]        scramble_data_comma;
logic   [NB-1:0]        scramble_data_skip; 
logic   [NB-1:0]        scramble_data_skprm;
logic   [NBK-1:0]       scramble_datak;     
logic   [NB-1:0]        scramble_error;     

// Output (combinational)
wire                    scramble_data_dv_c;
wire                    scramble_aligned_c;
wire     [(NB*8)-1:0]    scramble_data_c;
wire     [NB-1:0]        scramble_data_comma_c;
wire     [NB-1:0]        scramble_data_skip_c;
wire     [NB-1:0]        scramble_data_skprm_c;
wire     [NB-1:0]        scramble_datak_c;
wire     [NB-1:0]        scramble_error_c;

// Internal registers
reg     [15:0]  lfsr;

// Define internal buses based on 2 symbols per clock. When NB=1 only low bits are used.
//parameter   MNB     = 2;        // Maximum supported symbols per cycle

wire [(NB*8)-1:0]       i_data;
wire [(NB-1):0]         i_datak;
wire [(NB-1):0]         i_error;
wire [(NB*8-1):0]       i_scrambled_data;

wire                    comma0;
wire                    skip0;
wire                    bypass0;
wire [15:0]             lfsr_adv8;

wire                    comma1;
wire                    skip1;
wire                    bypass1;
wire [15:0]             lfsr_adv16;

wire                    comma2;
wire                    skip2;
wire                    bypass2;
wire [15:0]             lfsr_adv24;

wire                    comma3;
wire                    skip3;
wire                    bypass3;
wire [15:0]             lfsr_adv32;



typedef struct packed {
    logic                  scramble_aligned;   
    logic  [(NB*8)-1:0]    scramble_data;      
    logic  [NB-1:0]        scramble_data_comma;
    logic  [NB-1:0]        scramble_data_skip; 
    logic  [NB-1:0]        scramble_data_skprm;
    logic  [NBK-1:0]       scramble_datak;     
    logic  [NB-1:0]        scramble_error;     
    } scramble_out_data_t ;

scramble_out_data_t   pre_out_data ;
scramble_out_data_t   post_out_data ;
logic                 dly_clr_dv ;

assign i_data   = data  ;
assign i_datak  = datak[NB-1:0] ;
assign i_error  = error ;

assign scramble_data_comma_c = {
                                {NB-4{1'b0}},
                                comma3,
                                comma2,
                                comma1,
                                comma0
                                };

assign scramble_data_skip_c = {
                                {NB-4{1'b0}},
                                skip3,
                                skip2,
                                skip1,
                                skip0
                                } | scramble_data_skprm_c;

assign scramble_data_skprm_c = {
                                {NB-4{1'b0}},
                                skipremoved & comma3 & ~(comma0 | comma1 | comma2),
                                skipremoved & comma2 & ~(comma0 | comma1),
                                skipremoved & comma1 & ~comma0,
                                skipremoved & comma0
                                };

assign comma0   = (i_datak[0] && (i_data[(0*8)+7:(0*8)] == `COMMA_8B));
assign skip0    = (i_datak[0] && (i_data[(0*8)+7:(0*8)] == `SKIP_8B));
assign bypass0  = (scrambler_disable | i_datak[0]);

assign comma1   = (i_datak[1] && (i_data[(1*8)+7:(1*8)] == `COMMA_8B));
assign skip1    = (i_datak[1] && (i_data[(1*8)+7:(1*8)] == `SKIP_8B));
assign bypass1  = (scrambler_disable | i_datak[1]);

assign comma2   = (i_datak[2] && (i_data[(2*8)+7:(2*8)] == `COMMA_8B));
assign skip2    = (i_datak[2] && (i_data[(2*8)+7:(2*8)] == `SKIP_8B));
assign bypass2  = (scrambler_disable | i_datak[2]);

assign comma3   = (i_datak[3] && (i_data[(3*8)+7:(3*8)] == `COMMA_8B));
assign skip3    = (i_datak[3] && (i_data[(3*8)+7:(3*8)] == `SKIP_8B));
assign bypass3  = (scrambler_disable | i_datak[3]);

//
// The LFSR logic
//

assign lfsr_adv8    =   comma0          ?   16'hFFFF            :
                        skip0           ?   lfsr                : adv8_1dot0a(lfsr);

assign lfsr_adv16   =   comma1          ?   16'hFFFF            :
                        skip1           ?   lfsr_adv8           : adv8_1dot0a(lfsr_adv8);

assign lfsr_adv24   =   comma2          ?   16'hFFFF            :
                        skip2           ?   lfsr_adv16          : adv8_1dot0a(lfsr_adv16);

assign lfsr_adv32   =   comma3          ?   16'hFFFF            :
                        skip3           ?   lfsr_adv24          : adv8_1dot0a(lfsr_adv24);

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
        lfsr        <= #TP 16'hFFFF;
    else if (data_dv)
// LMD: Case statement without default clause and not all cases are covered
// LJ: active_nb is only defined to 1s, 2s, 4s, and 8s. The other cases are not used.
// leda W71 off
// LMD: Incomplete case statement
// LJ: active_nb is only defined to 1s, 2s, 4s, and 8s. The other cases are not used.
// leda DFT_022 off
            case (active_nb)
            4'b0010: lfsr        <= #TP lfsr_adv16;
            4'b0100: lfsr        <= #TP lfsr_adv32;
            4'b1000: lfsr        <= #TP 0; // Scrambler not used for 8s
        endcase // case(active_nb)
// leda DFT_022 on
// leda W71 on
end


// If the scrambler is not bypassed, scramble the output data (based on spec revision)
assign i_scrambled_data[(0*8)+7:(0*8)]  = bypass0 ? i_data[(0*8)+7:(0*8)] :
                                                    scramble8_1dot0a(lfsr, i_data[(0*8)+7:(0*8)]);

assign i_scrambled_data[(1*8)+7:(1*8)]  = (bypass1         ? i_data[(1*8)+7:(1*8)] :
                                              |active_nb[2:1] ? scramble8_1dot0a(lfsr_adv8, i_data[(1*8)+7:(1*8)]) :
                                               0);
assign i_scrambled_data[(2*8)+7:(2*8)]  = (bypass2      ? i_data[(2*8)+7:(2*8)] :
                                          active_nb[2] ? scramble8_1dot0a(lfsr_adv16, i_data[(2*8)+7:(2*8)]) :
                                           0);


assign i_scrambled_data[(3*8)+7:(3*8)]  = (bypass3 ? i_data[(3*8)+7:(3*8)] :
                                           active_nb[2] ? scramble8_1dot0a(lfsr_adv24, i_data[(3*8)+7:(3*8)]) :
                                           0);
// 8s mode of operation only for Gen3 data rate, uses Gen3-specific Scrambler
assign i_scrambled_data[(7*8)+7:(4*8)]  = 0;
//
// Output result
//

// Delay 2 cycle when CX_RMLH_SCRAMBLE_REGOUT is set.
// Because if CX_RMLH_SCRAMBLE_REGOUT is set, put pipe-line two stage between rmlh_pipe and smlh_seq_finder, and between smlh_seq_finder and rmlh_deskew
localparam N_DLY   = RX_SIDE ? REGOUT*2 : REGOUT ;
localparam DATA_WD = $bits( post_out_data ) ;

// There is a timing that the delayed scramble_data_dv value is keeping to 1 in gen3/4/5 rate.
// This causes an internal SVA failure in the deskew module. This value should be set to 0 in gen3/4/5 rate.
always_comb begin
        dly_clr_dv = '0 ;
end

delay_n_w_enable
 #(N_DLY ,  DATA_WD) u_delay_data  ( .clk(core_clk), .rst_n(core_rst_n), .clear(1'b0)      , .en(scramble_en), .din(pre_out_data), .dout(post_out_data));
delay_n_w_enable
 #(N_DLY ,  1      ) u_delay_dv    ( .clk(core_clk), .rst_n(core_rst_n), .clear(dly_clr_dv), .en(scramble_en), .din(data_dv), .dout(scramble_data_dv));
delay_n_w_enable
 #(N_DLY ,  1      ) u_wait4idle   ( .clk(core_clk), .rst_n(core_rst_n), .clear(dly_clr_dv), .en(scramble_en), .din(wait4idle), .dout(wait4idle_nd));

always_comb begin
    pre_out_data.scramble_aligned     = aligned ;   
    pre_out_data.scramble_data        = i_scrambled_data[(NB*8)-1:0] ;      
    pre_out_data.scramble_data_comma  = scramble_data_comma_c ;
    pre_out_data.scramble_data_skip   = scramble_data_skip_c ; 
    pre_out_data.scramble_data_skprm  = scramble_data_skprm_c ;
    pre_out_data.scramble_datak       = $bits( pre_out_data.scramble_datak)'( i_datak[NB-1:0] ) ;     
    pre_out_data.scramble_error       = i_error[NB-1:0] ;     
end

always_comb begin
    scramble_aligned           = post_out_data.scramble_aligned    ;
    scramble_data              = post_out_data.scramble_data       ;
    scramble_data_comma        = post_out_data.scramble_data_comma ;
    scramble_data_skip         = post_out_data.scramble_data_skip  ;
    scramble_data_skprm        = post_out_data.scramble_data_skprm ;
    scramble_datak             = post_out_data.scramble_datak      ;
    scramble_error             = post_out_data.scramble_error      ;
end

//-----------------------------------------------------------------------------
//   Scramble functions for the 1.0a version of the standard
//-----------------------------------------------------------------------------

//
// 8 Bit scramble function
//
function automatic [7:0] scramble8_1dot0a;
input   [15:0]  lfsr_bit;
input   [7:0]   inbyte_bit;

reg [15:0] bit_in;
reg [7:0] scrambit;
begin
    scrambit = 8'h00;
    bit_in  = lfsr_bit;
    scrambit[0] = bit_in[15]   ; // 0: 15
    scrambit[1] = bit_in[14]   ; // 1: 14
    scrambit[2] = bit_in[13]   ; // 2: 13
    scrambit[3] = bit_in[12]   ; // 3: 12
    scrambit[4] = bit_in[11]   ; // 4: 11
    scrambit[5] = bit_in[10]   ; // 5: 10
    scrambit[6] = bit_in[ 9]   ; // 6: 9
    scrambit[7] = bit_in[ 8]   ; // 7: 8
    scramble8_1dot0a = scrambit ^ inbyte_bit;
end
endfunction

// function lfsr shift by 8
function automatic [15:0] adv8_1dot0a;
input   [15:0]  bit_in;
begin
    adv8_1dot0a       = 16'h0000;
    adv8_1dot0a  [ 0] = bit_in[ 8]                                          ;   //  0:  8
    adv8_1dot0a  [ 1] = bit_in[ 9]                                          ;   //  1:  9
    adv8_1dot0a  [ 2] = bit_in[10]                                          ;   //  2: 10
    adv8_1dot0a  [ 3] = bit_in[11] ^ bit_in[ 8]                             ;   //  3: 11,  8
    adv8_1dot0a  [ 4] = bit_in[12] ^ bit_in[ 9] ^ bit_in[ 8]                ;   //  4: 12,  9,  8
    adv8_1dot0a  [ 5] = bit_in[13] ^ bit_in[10] ^ bit_in[ 9] ^ bit_in[ 8]   ;   //  5: 13, 10,  9,  8
    adv8_1dot0a  [ 6] = bit_in[14] ^ bit_in[11] ^ bit_in[10] ^ bit_in[ 9]   ;   //  6: 14, 11, 10,  9
    adv8_1dot0a  [ 7] = bit_in[15] ^ bit_in[12] ^ bit_in[11] ^ bit_in[10]   ;   //  7: 15, 12, 11, 10
    adv8_1dot0a  [ 8] = bit_in[ 0] ^ bit_in[13] ^ bit_in[12] ^ bit_in[11]   ;   //  8:  0, 13, 12, 11
    adv8_1dot0a  [ 9] = bit_in[ 1] ^ bit_in[14] ^ bit_in[13] ^ bit_in[12]   ;   //  9:  1, 14, 13, 12
    adv8_1dot0a  [10] = bit_in[ 2] ^ bit_in[15] ^ bit_in[14] ^ bit_in[13]   ;   // 10:  2, 15, 14, 13
    adv8_1dot0a  [11] = bit_in[ 3]              ^ bit_in[15] ^ bit_in[14]   ;   // 11:  3, 15,     14
    adv8_1dot0a  [12] = bit_in[ 4]                           ^ bit_in[15]   ;   // 12:  4,         15
    adv8_1dot0a  [13] = bit_in[ 5]                                          ;   // 13:  5
    adv8_1dot0a  [14] = bit_in[ 6]                                          ;   // 14:  6
    adv8_1dot0a  [15] = bit_in[ 7]                                          ;   // 15:  7
end
endfunction


endmodule
