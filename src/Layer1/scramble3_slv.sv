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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/scramble3_slv.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// -- PCIe scrambler for gen3. scramble3_slv is a wrapper to pipe_gen3_scrmbl
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/xmlh_pkg.svh"

 
 module scramble3_slv
 import xmlh_pkg::skp_replace_t;
 import xmlh_pkg::data_rate_enc_t;
  #(parameter INST = 0,
    parameter TP      = `TP,
    parameter RX_SIDE = 1,         // Tx:0 / Rx:1
    parameter REGIN   = 1,
    parameter REGOUT  = 1,
    parameter NB   = `CX_NB,
    parameter NBK  = `CX_NBK,
    parameter SB_WD= `CX_MAC_SB_WD,
    parameter SH_WD= `CX_MAC_SH_WD,
    parameter LFSR_REGOUT = 0,
    parameter CALC_PARITY_BEFORE_SCRAMBLE = 0,
    parameter AW   = `CX_ANB_WD ,
    parameter DCB_WD = (NB>=8 ? NB/8 : 1)
   ,
    parameter PRECODING_REGOUT = 0
   ,
    parameter GLAYCODING_REGOUT = 0 
  )
  (
  input                  core_clk,
  input                  core_rst_n,
  input  data_rate_enc_t crnt_rate_enc,
  input                  cfg_elastic_buffer_mode,
  input                  scrambler_disable,
  input                  dc_balance_disable,
  input                  scramble_en,
  input                  data_dv,
  input     [(NB*8)-1:0] data,
  input      [SB_WD-1:0] startblock,
  input            [2:0] skp_os_align_sts_logic,
  input        [NBK-1:0] datak,
  input            [2:0] lfsr_sel,
  input                  aligned,
  input                  txelecidle,
  input         [NB-1:0] error,
  input [SB_WD-1:0][4:0] data_osfound,
  input      [SB_WD-1:0] skipremoved,
  input         [AW-1:0] active_nb_gen34,
  input                  ltssm_in_compliance,
  input            [2:0] current_data_rate,
  input                  ltssm_in_rcvryspeed,
  input                  precoding_enable,
  input                  gen6_compliance_sending,
  input                  smlh_flit_mode_enable,
  input                  l0p_eieos_rcvd_ln0,
  input            [1:0] l0p_active_lfsr_info, // {advance 8blocks, advance 1 block}

  output        [NB-1:0] scramble_error,
  output                 scramble_data_dv,
  output    [(NB*8)-1:0] scramble_data,
  output     [SB_WD-1:0] scramble_startblock,
  output reg   [NBK-1:0] scramble_datak,
  output     [SB_WD-1:0] scramble_skprm,
  output     [SB_WD-1:0] scramble_even_parity,
  output reg             scramble_lfsr_rollover,
  output     [SB_WD-1:0] scramble_inskp,
  output logic     [2:0] scramble_skp_os_align_sts,
  output [SB_WD-1:0][4:0] scramble_data_osfound,
  output     [SB_WD-1:0] scramble_ints0,
  output    [DCB_WD-1:0] scramble_dcb_det,
  output     [SB_WD-1:0] scramble_ints1,
  output     [SB_WD-1:0] scramble_ints2,
  output     [SB_WD-1:0] scramble_ineie,
  output     [SB_WD-1:0] scramble_eie_det,
  output                 scramble_aligned,
  output     [SB_WD-1:0] scramble_insds
  ,
  output           [3:0] l0p_datastream_info // {eios detection, advance 1 block,initial, data stream}
  );

  localparam SIG_WIDTH  = (NB >= 32) ? 5+NB : (NB >= 8) ? 4+NB : 3+NB ; // Width of Extra Signals Bus


skp_replace_t skp_os_align_sts;
wire [22:0] scramble_lfsr_value;
wire [22:0] scramble_init_lfsr_value;
wire [22:0] scramble_roll_lfsr_value;
wire [SIG_WIDTH-1:0]  in_extra_sig;
wire [SIG_WIDTH-1:0]  scramble_out_extra_sig;
wire [SH_WD-1:0]      int_scramble_datak;    
wire        scramble_in_compliance; // Unused

wire [(NB*8)-1:0]     out_data;
wire [SB_WD-1:0]      out_even_parity;
wire [22:0]           out_lfsr;
wire  [SB_WD-1:0]     out_int_startblock;
wire [SH_WD-1:0]      out_int_syncheader;
wire [SB_WD-1:0]      out_int_eios;
wire [DCB_WD-1:0]     out_dcb_det;
wire [SB_WD-1:0]      out_startblock;
wire [SH_WD-1:0]      out_syncheader;    
skp_replace_t         out_skp_os_align_sts;
wire [SIG_WIDTH-1:0]  out_extra_sig;
wire                  out_data_dv;
wire [SB_WD-1:0]      out_skipremoved;
wire                  out_aligned;
wire [NB-1:0]         out_error;
wire                  out_in_compliance;
wire [SB_WD-1:0]      scramble_ctlskp_end_sym;
reg [SH_WD-1:0]       int_datak;


// Type casting : logic type to enum type
always_comb begin
    skp_os_align_sts          = skp_replace_t'( skp_os_align_sts_logic ) ;
    scramble_skp_os_align_sts = out_skp_os_align_sts ;
end

    // datak is used to carry syncheader
always @(*) begin : syncheader_to_datak_PROC
    scramble_datak      = 0;
    scramble_datak[SH_WD-1:0] = int_scramble_datak[SH_WD-1:0];
end

// Detect rollover point when the lfsr matches the seed. This is needed to insert EIEOS after a 
// sequence of 65536 uninterrupted TS1s sent during equalization when the reset EIEOS count is set.
always @(posedge core_clk or negedge core_rst_n) begin : lfsr_rollover_proc
    if (!core_rst_n) begin
        scramble_lfsr_rollover <= #TP 1'b0;
    end else begin
        scramble_lfsr_rollover <= #TP (scramble_roll_lfsr_value == scramble_lfsr_value);
    end
end

//delay signals same as data
assign in_extra_sig = {error, data_dv, skipremoved,
                       ltssm_in_compliance,
                       aligned};
assign {out_error, out_data_dv, out_skipremoved,
        out_in_compliance,
        out_aligned} = out_extra_sig;

assign {scramble_error, scramble_data_dv, scramble_skprm,
        scramble_in_compliance,
        scramble_aligned} = scramble_out_extra_sig;

//transform datak to 2-bit int_datak
always @(*) begin : datak_to_syncheader_PROC
    int_datak = 0;
    int_datak = datak[SH_WD-1:0];
end

// Added pipeline to implove timings for stable signals per lanes
localparam N_DELAY_CYLES  = 0 + 1;
localparam DATAPATH_WIDTH = 4 + AW + 1 + 4 + 1 + 1 + 1;
localparam RESET_VALUE    = {(DATAPATH_WIDTH-1)'(0) , 1'b1}; // dc_balance_disable=1 , The others = 0
wire  [DATAPATH_WIDTH-1:0]  pipeline_in;
wire  [DATAPATH_WIDTH-1:0]  pipeline_out;
wire                   cfg_elastic_buffer_mode_i;
wire                   scrambler_disable_i;
wire                   dc_balance_disable_i;
wire                   scramble_en_i;
wire          [AW-1:0] active_nb_gen34_i;
wire             [2:0] current_data_rate_i;
wire                   ltssm_in_rcvryspeed_i;
wire                   precoding_enable_i;
wire                   gen6_compliance_sending_i;
wire                   smlh_flit_mode_enable_i;
// L0p State
typedef enum logic [1:0] {
  L0P_IDLE,         // IDLE
  L0P_DATASTREAM,   // In Data stream
  L0P_INACTIVE      // In inactive after eios detection
} state_l0p_e;
state_l0p_e            next_l0p_state, curnt_l0p_state;
wire  [1:0]            l0p_in_lfsr_info; // {load, in l0p progress}
wire  [22:0]           l0p_in_lfsr_value;
wire  [4:0]            l0p_out_lfsr_info; // {eios,eieos,sdsos,advance 1blk,load}
wire  [22:0]           l0p_out_lfsr_value;
reg   [22:0]           l0p_lfsr;
reg   [22:0]           next_lfsr_1blk;
reg   [22:0]           next_lfsr_8blk;
reg                    data_dv_1d;

always @( * ) begin : next_l0p_state_PROC
    next_l0p_state = curnt_l0p_state;
    case(curnt_l0p_state)
        L0P_DATASTREAM: begin
            if(l0p_out_lfsr_info[3]) begin //eieos detection
                next_l0p_state = L0P_IDLE;
            end else if(l0p_out_lfsr_info[4]) begin //eios detection
                next_l0p_state = L0P_INACTIVE;
            end
        end
        L0P_INACTIVE: begin
            if(l0p_out_lfsr_info[2]) begin //SDS detection
                next_l0p_state = L0P_DATASTREAM;
            end
        end
        default: begin // L0P_IDLE
            if(smlh_flit_mode_enable_i && l0p_out_lfsr_info[2]) begin //SDS detection
                next_l0p_state = L0P_DATASTREAM;
            end
        end
    endcase
end

always @( posedge core_clk or negedge core_rst_n ) begin : curnt_l0p_state_PROC
    if ( ~core_rst_n ) begin
       curnt_l0p_state       <= #TP L0P_IDLE;
    end else begin
       curnt_l0p_state       <= #TP (l0p_eieos_rcvd_ln0) ? L0P_IDLE : next_l0p_state;
    end
end // curnt_l0p_state_PROC

// Warning-[VCM-TRIMVEC] Too many vectors in condition coverage
//VCS coverage off
// Shadow LFSR for l0p
always @(*) begin: l0p_lfsr_proc
    // lfsr[22:0]=1+x^2+x^5+x^8+x^16+x^21+x^23
    // Advance 1 blocks
    next_lfsr_1blk[0] = l0p_lfsr[0] ^ l0p_lfsr[1] ^ l0p_lfsr[2] ^ l0p_lfsr[6] ^ l0p_lfsr[8] ^ l0p_lfsr[9] ^ l0p_lfsr[11] ^ l0p_lfsr[12] ^ l0p_lfsr[14] ^ l0p_lfsr[16] ^ l0p_lfsr[18] ^ l0p_lfsr[19] ^ l0p_lfsr[21] ^ l0p_lfsr[22];
    next_lfsr_1blk[1] = l0p_lfsr[1] ^ l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[7] ^ l0p_lfsr[9] ^ l0p_lfsr[10] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[15] ^ l0p_lfsr[17] ^ l0p_lfsr[19] ^ l0p_lfsr[20] ^ l0p_lfsr[22];
    next_lfsr_1blk[2] = l0p_lfsr[1] ^ l0p_lfsr[3] ^ l0p_lfsr[4] ^ l0p_lfsr[6] ^ l0p_lfsr[9] ^ l0p_lfsr[10] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[19] ^ l0p_lfsr[20] ^ l0p_lfsr[22];
    next_lfsr_1blk[3] = l0p_lfsr[2] ^ l0p_lfsr[4] ^ l0p_lfsr[5] ^ l0p_lfsr[7] ^ l0p_lfsr[10] ^ l0p_lfsr[11] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[20] ^ l0p_lfsr[21];
    next_lfsr_1blk[4] = l0p_lfsr[0] ^ l0p_lfsr[3] ^ l0p_lfsr[5] ^ l0p_lfsr[6] ^ l0p_lfsr[8] ^ l0p_lfsr[11] ^ l0p_lfsr[12] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[21] ^ l0p_lfsr[22];
    next_lfsr_1blk[5] = l0p_lfsr[0] ^ l0p_lfsr[2] ^ l0p_lfsr[4] ^ l0p_lfsr[7] ^ l0p_lfsr[8] ^ l0p_lfsr[11] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[18] ^ l0p_lfsr[19] ^ l0p_lfsr[21];
    next_lfsr_1blk[6] = l0p_lfsr[0] ^ l0p_lfsr[1] ^ l0p_lfsr[3] ^ l0p_lfsr[5] ^ l0p_lfsr[8] ^ l0p_lfsr[9] ^ l0p_lfsr[12] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[16] ^ l0p_lfsr[19] ^ l0p_lfsr[20] ^ l0p_lfsr[22];
    next_lfsr_1blk[7] = l0p_lfsr[1] ^ l0p_lfsr[2] ^ l0p_lfsr[4] ^ l0p_lfsr[6] ^ l0p_lfsr[9] ^ l0p_lfsr[10] ^ l0p_lfsr[13] ^ l0p_lfsr[15] ^ l0p_lfsr[16] ^ l0p_lfsr[17] ^ l0p_lfsr[20] ^ l0p_lfsr[21];
    next_lfsr_1blk[8] = l0p_lfsr[0] ^ l0p_lfsr[1] ^ l0p_lfsr[3] ^ l0p_lfsr[5] ^ l0p_lfsr[6] ^ l0p_lfsr[7] ^ l0p_lfsr[8] ^ l0p_lfsr[9] ^ l0p_lfsr[10] ^ l0p_lfsr[12] ^ l0p_lfsr[17] ^ l0p_lfsr[19];
    next_lfsr_1blk[9] = l0p_lfsr[1] ^ l0p_lfsr[2] ^ l0p_lfsr[4] ^ l0p_lfsr[6] ^ l0p_lfsr[7] ^ l0p_lfsr[8] ^ l0p_lfsr[9] ^ l0p_lfsr[10] ^ l0p_lfsr[11] ^ l0p_lfsr[13] ^ l0p_lfsr[18] ^ l0p_lfsr[20];
    next_lfsr_1blk[10] = l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[5] ^ l0p_lfsr[7] ^ l0p_lfsr[8] ^ l0p_lfsr[9] ^ l0p_lfsr[10] ^ l0p_lfsr[11] ^ l0p_lfsr[12] ^ l0p_lfsr[14] ^ l0p_lfsr[19] ^ l0p_lfsr[21];
    next_lfsr_1blk[11] = l0p_lfsr[0] ^ l0p_lfsr[3] ^ l0p_lfsr[4] ^ l0p_lfsr[6] ^ l0p_lfsr[8] ^ l0p_lfsr[9] ^ l0p_lfsr[10] ^ l0p_lfsr[11] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[15] ^ l0p_lfsr[20] ^ l0p_lfsr[22];
    next_lfsr_1blk[12] = l0p_lfsr[1] ^ l0p_lfsr[4] ^ l0p_lfsr[5] ^ l0p_lfsr[7] ^ l0p_lfsr[9] ^ l0p_lfsr[10] ^ l0p_lfsr[11] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[16] ^ l0p_lfsr[21];
    next_lfsr_1blk[13] = l0p_lfsr[0] ^ l0p_lfsr[2] ^ l0p_lfsr[5] ^ l0p_lfsr[6] ^ l0p_lfsr[8] ^ l0p_lfsr[10] ^ l0p_lfsr[11] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[17] ^ l0p_lfsr[22];
    next_lfsr_1blk[14] = l0p_lfsr[1] ^ l0p_lfsr[3] ^ l0p_lfsr[6] ^ l0p_lfsr[7] ^ l0p_lfsr[9] ^ l0p_lfsr[11] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[16] ^ l0p_lfsr[18];
    next_lfsr_1blk[15] = l0p_lfsr[0] ^ l0p_lfsr[2] ^ l0p_lfsr[4] ^ l0p_lfsr[7] ^ l0p_lfsr[8] ^ l0p_lfsr[10] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[16] ^ l0p_lfsr[17] ^ l0p_lfsr[19];
    next_lfsr_1blk[16] = l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[5] ^ l0p_lfsr[6] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[15] ^ l0p_lfsr[17] ^ l0p_lfsr[19] ^ l0p_lfsr[20] ^ l0p_lfsr[21] ^ l0p_lfsr[22];
    next_lfsr_1blk[17] = l0p_lfsr[0] ^ l0p_lfsr[3] ^ l0p_lfsr[4] ^ l0p_lfsr[6] ^ l0p_lfsr[7] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[16] ^ l0p_lfsr[18] ^ l0p_lfsr[20] ^ l0p_lfsr[21] ^ l0p_lfsr[22];
    next_lfsr_1blk[18] = l0p_lfsr[1] ^ l0p_lfsr[4] ^ l0p_lfsr[5] ^ l0p_lfsr[7] ^ l0p_lfsr[8] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[17] ^ l0p_lfsr[19] ^ l0p_lfsr[21] ^ l0p_lfsr[22];
    next_lfsr_1blk[19] = l0p_lfsr[0] ^ l0p_lfsr[2] ^ l0p_lfsr[5] ^ l0p_lfsr[6] ^ l0p_lfsr[8] ^ l0p_lfsr[9] ^ l0p_lfsr[15] ^ l0p_lfsr[16] ^ l0p_lfsr[18] ^ l0p_lfsr[20] ^ l0p_lfsr[22];
    next_lfsr_1blk[20] = l0p_lfsr[0] ^ l0p_lfsr[1] ^ l0p_lfsr[3] ^ l0p_lfsr[6] ^ l0p_lfsr[7] ^ l0p_lfsr[9] ^ l0p_lfsr[10] ^ l0p_lfsr[16] ^ l0p_lfsr[17] ^ l0p_lfsr[19] ^ l0p_lfsr[21];
    next_lfsr_1blk[21] = l0p_lfsr[0] ^ l0p_lfsr[4] ^ l0p_lfsr[6] ^ l0p_lfsr[7] ^ l0p_lfsr[9] ^ l0p_lfsr[10] ^ l0p_lfsr[12] ^ l0p_lfsr[14] ^ l0p_lfsr[16] ^ l0p_lfsr[17] ^ l0p_lfsr[19] ^ l0p_lfsr[20] ^ l0p_lfsr[21];
    next_lfsr_1blk[22] = l0p_lfsr[0] ^ l0p_lfsr[1] ^ l0p_lfsr[5] ^ l0p_lfsr[7] ^ l0p_lfsr[8] ^ l0p_lfsr[10] ^ l0p_lfsr[11] ^ l0p_lfsr[13] ^ l0p_lfsr[15] ^ l0p_lfsr[17] ^ l0p_lfsr[18] ^ l0p_lfsr[20] ^ l0p_lfsr[21] ^ l0p_lfsr[22];
    // Advance 8 blocks for lane skew in RMLH
    next_lfsr_8blk[0] = l0p_lfsr[1] ^ l0p_lfsr[2] ^ l0p_lfsr[4] ^ l0p_lfsr[5] ^ l0p_lfsr[9] ^ l0p_lfsr[11] ^ l0p_lfsr[12] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[16] ^ l0p_lfsr[19] ^ l0p_lfsr[21] ^ l0p_lfsr[22];
    next_lfsr_8blk[1] = l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[5] ^ l0p_lfsr[6] ^ l0p_lfsr[10] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[15] ^ l0p_lfsr[16] ^ l0p_lfsr[17] ^ l0p_lfsr[20] ^ l0p_lfsr[22];
    next_lfsr_8blk[2] = l0p_lfsr[0] ^ l0p_lfsr[1] ^ l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[5] ^ l0p_lfsr[6] ^ l0p_lfsr[7] ^ l0p_lfsr[9] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[15] ^ l0p_lfsr[17] ^ l0p_lfsr[18] ^ l0p_lfsr[19] ^ l0p_lfsr[22];
    next_lfsr_8blk[3] = l0p_lfsr[1] ^ l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[4] ^ l0p_lfsr[6] ^ l0p_lfsr[7] ^ l0p_lfsr[8] ^ l0p_lfsr[10] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[16] ^ l0p_lfsr[18] ^ l0p_lfsr[19] ^ l0p_lfsr[20];
    next_lfsr_8blk[4] = l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[4] ^ l0p_lfsr[5] ^ l0p_lfsr[7] ^ l0p_lfsr[8] ^ l0p_lfsr[9] ^ l0p_lfsr[11] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[17] ^ l0p_lfsr[19] ^ l0p_lfsr[20] ^ l0p_lfsr[21];
    next_lfsr_8blk[5] = l0p_lfsr[1] ^ l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[6] ^ l0p_lfsr[8] ^ l0p_lfsr[10] ^ l0p_lfsr[11] ^ l0p_lfsr[14] ^ l0p_lfsr[18] ^ l0p_lfsr[19] ^ l0p_lfsr[20];
    next_lfsr_8blk[6] = l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[4] ^ l0p_lfsr[7] ^ l0p_lfsr[9] ^ l0p_lfsr[11] ^ l0p_lfsr[12] ^ l0p_lfsr[15] ^ l0p_lfsr[19] ^ l0p_lfsr[20] ^ l0p_lfsr[21];
    next_lfsr_8blk[7] = l0p_lfsr[3] ^ l0p_lfsr[4] ^ l0p_lfsr[5] ^ l0p_lfsr[8] ^ l0p_lfsr[10] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[16] ^ l0p_lfsr[20] ^ l0p_lfsr[21] ^ l0p_lfsr[22];
    next_lfsr_8blk[8] = l0p_lfsr[0] ^ l0p_lfsr[1] ^ l0p_lfsr[2] ^ l0p_lfsr[6] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[15] ^ l0p_lfsr[16] ^ l0p_lfsr[17] ^ l0p_lfsr[19];
    next_lfsr_8blk[9] = l0p_lfsr[1] ^ l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[7] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[16] ^ l0p_lfsr[17] ^ l0p_lfsr[18] ^ l0p_lfsr[20];
    next_lfsr_8blk[10] = l0p_lfsr[0] ^ l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[4] ^ l0p_lfsr[8] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[17] ^ l0p_lfsr[18] ^ l0p_lfsr[19] ^ l0p_lfsr[21];
    next_lfsr_8blk[11] = l0p_lfsr[1] ^ l0p_lfsr[3] ^ l0p_lfsr[4] ^ l0p_lfsr[5] ^ l0p_lfsr[9] ^ l0p_lfsr[15] ^ l0p_lfsr[16] ^ l0p_lfsr[18] ^ l0p_lfsr[19] ^ l0p_lfsr[20] ^ l0p_lfsr[22];
    next_lfsr_8blk[12] = l0p_lfsr[0] ^ l0p_lfsr[2] ^ l0p_lfsr[4] ^ l0p_lfsr[5] ^ l0p_lfsr[6] ^ l0p_lfsr[10] ^ l0p_lfsr[16] ^ l0p_lfsr[17] ^ l0p_lfsr[19] ^ l0p_lfsr[20] ^ l0p_lfsr[21];
    next_lfsr_8blk[13] = l0p_lfsr[1] ^ l0p_lfsr[3] ^ l0p_lfsr[5] ^ l0p_lfsr[6] ^ l0p_lfsr[7] ^ l0p_lfsr[11] ^ l0p_lfsr[17] ^ l0p_lfsr[18] ^ l0p_lfsr[20] ^ l0p_lfsr[21] ^ l0p_lfsr[22];
    next_lfsr_8blk[14] = l0p_lfsr[2] ^ l0p_lfsr[4] ^ l0p_lfsr[6] ^ l0p_lfsr[7] ^ l0p_lfsr[8] ^ l0p_lfsr[12] ^ l0p_lfsr[18] ^ l0p_lfsr[19] ^ l0p_lfsr[21] ^ l0p_lfsr[22];
    next_lfsr_8blk[15] = l0p_lfsr[0] ^ l0p_lfsr[3] ^ l0p_lfsr[5] ^ l0p_lfsr[7] ^ l0p_lfsr[8] ^ l0p_lfsr[9] ^ l0p_lfsr[13] ^ l0p_lfsr[19] ^ l0p_lfsr[20] ^ l0p_lfsr[22];
    next_lfsr_8blk[16] = l0p_lfsr[0] ^ l0p_lfsr[2] ^ l0p_lfsr[5] ^ l0p_lfsr[6] ^ l0p_lfsr[8] ^ l0p_lfsr[10] ^ l0p_lfsr[11] ^ l0p_lfsr[12] ^ l0p_lfsr[15] ^ l0p_lfsr[16] ^ l0p_lfsr[19] ^ l0p_lfsr[20] ^ l0p_lfsr[22];
    next_lfsr_8blk[17] = l0p_lfsr[0] ^ l0p_lfsr[1] ^ l0p_lfsr[3] ^ l0p_lfsr[6] ^ l0p_lfsr[7] ^ l0p_lfsr[9] ^ l0p_lfsr[11] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[16] ^ l0p_lfsr[17] ^ l0p_lfsr[20] ^ l0p_lfsr[21];
    next_lfsr_8blk[18] = l0p_lfsr[0] ^ l0p_lfsr[1] ^ l0p_lfsr[2] ^ l0p_lfsr[4] ^ l0p_lfsr[7] ^ l0p_lfsr[8] ^ l0p_lfsr[10] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[17] ^ l0p_lfsr[18] ^ l0p_lfsr[21] ^ l0p_lfsr[22];
    next_lfsr_8blk[19] = l0p_lfsr[1] ^ l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[5] ^ l0p_lfsr[8] ^ l0p_lfsr[9] ^ l0p_lfsr[11] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[18] ^ l0p_lfsr[19] ^ l0p_lfsr[22];
    next_lfsr_8blk[20] = l0p_lfsr[0] ^ l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[4] ^ l0p_lfsr[6] ^ l0p_lfsr[9] ^ l0p_lfsr[10] ^ l0p_lfsr[12] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[16] ^ l0p_lfsr[19] ^ l0p_lfsr[20];
    next_lfsr_8blk[21] = l0p_lfsr[0] ^ l0p_lfsr[2] ^ l0p_lfsr[3] ^ l0p_lfsr[7] ^ l0p_lfsr[9] ^ l0p_lfsr[10] ^ l0p_lfsr[12] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[17] ^ l0p_lfsr[19] ^ l0p_lfsr[20] ^ l0p_lfsr[22];
    next_lfsr_8blk[22] = l0p_lfsr[0] ^ l0p_lfsr[1] ^ l0p_lfsr[3] ^ l0p_lfsr[4] ^ l0p_lfsr[8] ^ l0p_lfsr[10] ^ l0p_lfsr[11] ^ l0p_lfsr[13] ^ l0p_lfsr[14] ^ l0p_lfsr[15] ^ l0p_lfsr[18] ^ l0p_lfsr[20] ^ l0p_lfsr[21];
end
//VCS coverage on

always @( posedge core_clk or negedge core_rst_n ) begin : l0p_lfsr_PROC
    if ( ~core_rst_n ) begin
       l0p_lfsr <= #TP '0;
    end else begin
       case(curnt_l0p_state)
           L0P_DATASTREAM: begin
               if(l0p_out_lfsr_info[0]) begin // load
                   l0p_lfsr <= #TP l0p_out_lfsr_value;
               end else if(l0p_out_lfsr_info[1]) begin //advance 1 block
                   l0p_lfsr <= #TP next_lfsr_1blk;
               end
           end
           L0P_INACTIVE: begin
               if(l0p_active_lfsr_info[0]) begin // advance 1 block
                   l0p_lfsr <= #TP next_lfsr_1blk;
               end else if(l0p_active_lfsr_info[1]) begin //advance 8 blocks
                   l0p_lfsr <= #TP next_lfsr_8blk;
               end
           end
           default: begin
               l0p_lfsr <= #TP 0;
           end
       endcase
    end
end // l0p_lfsr_PROC

always @( posedge core_clk or negedge core_rst_n ) begin : data_dv_1d_PROC
    if ( ~core_rst_n ) begin
        data_dv_1d <= #TP 1'b0;
    end else begin
        data_dv_1d <= #TP data_dv;
    end
end // data_dv_1d_PROC

assign l0p_in_lfsr_info  = {(CALC_PARITY_BEFORE_SCRAMBLE==1 && txelecidle && data_dv && ~data_dv_1d), (curnt_l0p_state==L0P_INACTIVE)}; // {load, in l0p inactive}
assign l0p_in_lfsr_value = l0p_lfsr;
assign l0p_datastream_info = {|l0p_out_lfsr_info[4:3],l0p_out_lfsr_info[1], l0p_out_lfsr_info[0], (curnt_l0p_state==L0P_DATASTREAM)}; // {advance 1block. in datastream}

assign pipeline_in = {
 smlh_flit_mode_enable, 
 gen6_compliance_sending,
 precoding_enable,
 current_data_rate, ltssm_in_rcvryspeed,
   ltssm_in_compliance,
  active_nb_gen34, scramble_en, scrambler_disable, cfg_elastic_buffer_mode, dc_balance_disable};

delay_n_w_enable

#(N_DELAY_CYLES, DATAPATH_WIDTH, RESET_VALUE) u_delay_pipeline (
  .clk        (core_clk),
  .rst_n      (core_rst_n),
  .clear      (1'b0),
  .en         (1'b1),
  .din        (pipeline_in),
  .dout       (pipeline_out)
);

assign {
 smlh_flit_mode_enable_i, 
 gen6_compliance_sending_i,
 precoding_enable_i,
 current_data_rate_i, ltssm_in_rcvryspeed_i,
   ltssm_in_compliance_i,
  active_nb_gen34_i, scramble_en_i, scrambler_disable_i, cfg_elastic_buffer_mode_i, dc_balance_disable_i} = pipeline_out;

scramble3_pipe_gen3_scrmbl
 #(.INST(INST), .REGIN(REGIN), .REGOUT(REGOUT), .LFSR_REGOUT(LFSR_REGOUT), .SIG_WIDTH(SIG_WIDTH) , .AW(AW) , .CALC_PARITY_BEFORE_SCRAMBLE(CALC_PARITY_BEFORE_SCRAMBLE) , .PRECODING_REGOUT(PRECODING_REGOUT) , .GLAYCODING_REGOUT(GLAYCODING_REGOUT)) u_scramble3_pipe_gen3_scrmbl (
// ---- inputs ---------------
  .core_clk                (core_clk),
  .core_rst_n              (core_rst_n),
  .cfg_elastic_buffer_mode (cfg_elastic_buffer_mode_i),
  .scrmbl_disable          (scrambler_disable_i),
  .dc_balance_disable      (dc_balance_disable_i),
  .scramble_en             (scramble_en_i),
  .in_dataskip             (~data_dv),
  .in_data                 (data),
  .in_startblock           (startblock),
  .in_syncheader           (int_datak),
  .in_skp_os_align_sts     (skp_os_align_sts),
  .in_skipremoved          (skipremoved),
  .lfsr_sel                (lfsr_sel),
  .in_extra_sig            (in_extra_sig),
  .aligned                 (aligned),
  .txelecidle              (txelecidle),
  .active_nb_gen34         (active_nb_gen34_i),
  .in_data_osfound         (data_osfound), 
  .l0p_in_lfsr_info        (l0p_in_lfsr_info),
  .l0p_in_lfsr_value       (l0p_in_lfsr_value),
  .current_data_rate       (current_data_rate_i),
  .precoding_en            (precoding_enable_i),
  .gen6_compliance_sending (gen6_compliance_sending_i),
  
// ---- outputs ---------------
  .out_data          (out_data),
  .out_even_parity   (out_even_parity),
  .out_lfsr          (out_lfsr),
  .out_int_startblock(out_int_startblock),
  .out_int_syncheader(out_int_syncheader),
  .out_int_eios      (out_int_eios),
  .out_startblock    (out_startblock),
  .out_syncheader    (out_syncheader),
  .out_skp_os_align_sts (out_skp_os_align_sts),
  .out_extra_sig     (out_extra_sig),
  .out_data_osfound  (scramble_data_osfound), 
  .out_dcb_det       (out_dcb_det),
  .init_lfsr_value   (scramble_init_lfsr_value),
  .roll_lfsr_value   (scramble_roll_lfsr_value),
  .lfsr_value        (scramble_lfsr_value),
  .inskp             (scramble_inskp),
  .ints0             (scramble_ints0),
  .ints1             (scramble_ints1),
  .ints2             (scramble_ints2),
  .full_ineie        (scramble_ineie),
  .full_eieos_detected(scramble_eie_det),
  .insds             (scramble_insds)
  ,
  .l0p_out_lfsr_info  (l0p_out_lfsr_info),
  .l0p_out_lfsr_value (l0p_out_lfsr_value)
  ); 

wire [(NB*8)-1:0] tmp_out_data;
wire [SB_WD-1:0]  tmp_scramble_inskp;
wire [SB_WD-1:0]  tmp_scramble_insds;

localparam  TMP_PRECODING_REGOUT = 0 + PRECODING_REGOUT;
localparam  TMP_GLAYCODING_REGOUT = 0 +  GLAYCODING_REGOUT;
assign tmp_out_data = out_data;
assign tmp_scramble_inskp = scramble_inskp;
assign tmp_scramble_insds = scramble_insds;

scramble3_parity
 #(.INST(INST)) u_scramble3_parity (
// ---- inputs ---------------
  .core_clk                 (core_clk),
  .core_rst_n               (core_rst_n),
  .scramble_startblock      (out_int_startblock),
  .scramble_data_dv         (out_data_dv),
  .scramble_aligned         (out_aligned),
  .scramble_current_parity  (out_even_parity),
  .scramble_data_out        (out_data),
  .scramble_data_osfound_out (scramble_data_osfound), 
  .scramble_inskp           (tmp_scramble_inskp),
  .scramble_insds           (tmp_scramble_insds),
  .scramble_en              (scramble_en_i),
  .active_nb_gen34          (active_nb_gen34_i),
  .current_data_rate        (current_data_rate_i),
  .ltssm_in_rcvryspeed      (ltssm_in_rcvryspeed_i),
  .scramble_int_syncheader  (out_int_syncheader),
  .scramble_int_eios        (out_int_eios),
  .txelecidle               (txelecidle),
  .smlh_flit_mode_enable    (smlh_flit_mode_enable),
// ---- outputs ---------------
  .scramble_ctlskp_end_sym_o (scramble_ctlskp_end_sym),
  .scramble_even_parity     (scramble_even_parity)
  ); 

generate if (RX_SIDE==0) begin : gen_skip_align
scramble3_skip_align
 #(.INST(INST), .SIG_WIDTH(SIG_WIDTH), .DCB_WD(DCB_WD)) u_scramble3_skip_align (
// ---- Inputs ---------------
    .core_clk               (core_clk),
    .core_rst_n             (core_rst_n),
    .extra_sig              (out_extra_sig),
    .data                   (out_data),
    .data_valid             (scramble_data_dv),
    .startblock             (out_startblock),
    .syncheader             (out_syncheader),
    .even_parity            (scramble_even_parity),
    .lfsr_value             (out_lfsr),
    .skp_os_align_sts       (out_skp_os_align_sts),
    .active_nb              (active_nb_gen34_i),
    .crnt_rate_enc          (crnt_rate_enc),
// ---- Outputs ---------------
    .scramble_dcb_det       (scramble_dcb_det),         // Fixed 0b. Not used in Tx Side.
    .scramble_extra_sig     (scramble_out_extra_sig),
    .scramble_data          (scramble_data),
    .scramble_startblock    (scramble_startblock),
    .scramble_syncheader    (int_scramble_datak)
    );
end
endgenerate
    
generate if (RX_SIDE==1) begin : gen_output_assign
    assign scramble_data            = out_data;
    assign int_scramble_datak       = out_syncheader;
    assign scramble_startblock      = out_startblock;
    assign scramble_out_extra_sig   = out_extra_sig;
    assign scramble_dcb_det         = out_dcb_det;
end
endgenerate

endmodule // scramble3_slv
