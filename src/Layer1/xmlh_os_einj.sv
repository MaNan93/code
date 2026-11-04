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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_os_einj.sv#3 $
// ------------------------------------------------------------------------- 
// ----------------------------------------------------------------------------- 
// --- Module Description: 
// ----------------------------------------------------------------------------- 
// --- This module contains Flit Error Injection Extended Capability, specifically OS Error Injection. 
// --- This capability is optional. This capability is permitted in Downstream Ports, in Function 0 of an Upstream Port, and inRCRBs.  
// --- This capability is not permitted in other Functions. 
// ----------------------------------------------------------------------------- 

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Layer1/xmlh_pkg.svh"

module xmlh_os_einj
    import xmlh_pkg::P_SKP_REPLACE_IDLE;
    import xmlh_pkg::OSFLG_WD;
    import DWC_pcie_core_pkg::cfg_os_einj_ctrl_1_t;
    import DWC_pcie_core_pkg::cfg_os_einj_ctrl_2_t;
    import DWC_pcie_core_pkg::cfg_os_einj_status_t;
    import DWC_pcie_core_pkg::xmlh_einj_in_os_t;
    import DWC_pcie_core_pkg::ltssm_state_e;
    import DWC_pcie_core_pkg::S_DETECT_QUIET;
    import DWC_pcie_core_pkg::S_DETECT_ACT;
    import DWC_pcie_core_pkg::S_POLL_ACTIVE;
    import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
    import DWC_pcie_core_pkg::S_POLL_CONFIG;
    import DWC_pcie_core_pkg::S_PRE_DETECT_QUIET;
    import DWC_pcie_core_pkg::S_DETECT_WAIT;
    import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
    import DWC_pcie_core_pkg::S_CFG_LINKWD_ACEPT;
    import DWC_pcie_core_pkg::S_CFG_LANENUM_WAIT;
    import DWC_pcie_core_pkg::S_CFG_LANENUM_ACEPT;
    import DWC_pcie_core_pkg::S_CFG_COMPLETE;
    import DWC_pcie_core_pkg::S_CFG_IDLE;
    import DWC_pcie_core_pkg::S_RCVRY_LOCK;
    import DWC_pcie_core_pkg::S_RCVRY_SPEED;
    import DWC_pcie_core_pkg::S_RCVRY_RCVRCFG;
    import DWC_pcie_core_pkg::S_RCVRY_IDLE;
    import DWC_pcie_core_pkg::S_L0;
    import DWC_pcie_core_pkg::S_RCVRY_EQ0;
    import DWC_pcie_core_pkg::S_RCVRY_EQ1;
    import DWC_pcie_core_pkg::S_RCVRY_EQ2;
    import DWC_pcie_core_pkg::S_RCVRY_EQ3;
#(
    parameter INST              = 0,             // The uniquifying parameter for each port logic instance.
    parameter AW                = `CX_ANB_WD,    // Width of the active number of bytes
    parameter NL                = `CX_NL,        // Max number of lanes supported
    parameter NB                = `CX_NB,        // Number of symbols (bytes) per clock cycle
    parameter NBK               = `CX_NBK,       // Number of symbols (bytes) per clock cycle for datak
    parameter MAC_TXSB_WD       = `CX_MAC_SB_WD  // Width of the start block
) (
    // Inputs
    input                                           core_clk,
    input                                           core_rst_n,
    input  [NL-1:0]                                 smlh_lanes_active,
    input  [2:0]                                    current_data_rate,
    input  [AW-1:0]                                 active_nb,
    input                                           ltssm_flit_mode,
    input  ltssm_state_e                            smlh_ltssm_state,
    input                                           cfg_flit_err_inj_latency,
    input  cfg_os_einj_ctrl_1_t                     cfg_os_einj_ctrl_1,
    input  cfg_os_einj_ctrl_2_t                     cfg_os_einj_ctrl_2,
    input  ltssm_state_e                            xmtbyte_latched_loadpat_ltssmstate,
    input  xmlh_einj_in_os_t                        xmtbyte_einj_in_os,
    input  [(NL*NB*8)-1:0]                          xmtbyte_txdata,                    // data bytes
    input                                           xmtbyte_txdata_dv,                 // data bytes are valid
    input  [(NL*NBK)-1:0]                           xmtbyte_txdatak,                   // K character indication for each byte
    input  [NL-1:0][MAC_TXSB_WD-1:0][OSFLG_WD-1:0]  xmtbyte_ossending,    // Sending OS Flag 
    input  [(NL*MAC_TXSB_WD)-1:0]                   xmtbyte_txstartblock,              // Indicates the starting symbol for a 130b block
    input  [NL-1:0][2:0]                            xmtbyte_skp_os_align_sts,          // Indicates current sending Data have LFSR/Parity field of SKP OS
    input  [NL-1:0]                                 xmtbyte_txelecidle,                // Lanes to put in electrical idle
    input  [NL-1:0]                                 xmtbyte_txelecidle_scramble,       // Lanes to put in electrical idle for scrambler at 16s
    input  [NL-1:0]                                 pm_xmlh_scramble_even_parity,      // Current rx skip even data parity shadowed in always on domain
    input                                           xmtbyte_txdetectrx_loopback,       // PIPE TxDetectLoopback. Need to align TxData
    input  [NL-1:0]                                 xmtbyte_txcompliance,              // PIPE TxCompliance. Need to align TxData
    input                                           xmtbyte_link_in_training,          // Indicates byte machine is sending training sequences or compliance pattern
    // Outputs
    output cfg_os_einj_status_t                     xmlh_tx_os_einj_status,
    output [(NL*NB*8)-1:0]                          xmteinj_txdata,
    output                                          xmteinj_txdata_dv,
    output [(NL*NBK)-1:0]                           xmteinj_txdatak,
    output [NL-1:0][MAC_TXSB_WD-1:0][OSFLG_WD-1:0]  xmteinj_ossending,
    output [(NL*MAC_TXSB_WD)-1:0]                   xmteinj_txstartblock,
    output [NL-1:0][2:0]                            xmteinj_skp_os_align_sts,
    output [NL-1:0]                                 xmteinj_txelecidle,
    output [NL-1:0]                                 xmteinj_txelecidle_scramble,
    output [NL-1:0]                                 xmteinj_pm_xmlh_scramble_even_parity,
    output                                          xmteinj_txdetectrx_loopback,
    output [NL-1:0]                                 xmteinj_txcompliance,
    output                                          xmteinj_link_in_training
);

localparam TP = `TP;

// Control Signal: The following signals contribute to enabling error injection for the current active_bytes, i.e., the active_nb bytes of input data
// Enable Tx OS Error Injection when: cfg_os_einj_ctrl_1.os_error_injection_en and cfg_os_einj_ctrl_1.tx_os_error_injection_en
wire ctrl_1_tx_os_einj_en = cfg_os_einj_ctrl_1.os_error_injection_en && cfg_os_einj_ctrl_1.tx_os_error_injection_en;

wire g1_rate                = (current_data_rate == `GEN1_RATE);
wire g2_rate                = (current_data_rate == `GEN2_RATE);
wire g6_rate                = (current_data_rate == `GEN6_RATE);
wire g12_rate               = g1_rate || g2_rate;
wire xmtbyte_in_skp_or_eios = xmtbyte_einj_in_os.in_skp || xmtbyte_einj_in_os.in_eid;
wire g12_short_os           = g12_rate && xmtbyte_in_skp_or_eios;

// Only defined symbols participate in error injection, in particular just the 4 symbols of Gen1/2 Skip & EIOS
wire [15:0] einj_bytes;
wire [15:0] einj_bytes_mask = g12_short_os ? 16'h000F : 16'hFFFF;
wire        any_byte_einj   = |(einj_bytes & einj_bytes_mask);

// Enable Tx OS Error Injection when: active_bytes belong to OS whose type is targeted in cfg_os_einj_ctrl_1
// For a 4-byte OS, if symbols selected for corruption (through control register, PRNG will always select valid bytes of OS) do not
// include any of the 4 bytes then error injection does not take place and the OS does not contribute to spacing
wire in_targeted_os = xmtbyte_txdata_dv && any_byte_einj && (
    (xmtbyte_einj_in_os.in_ts0 && cfg_os_einj_ctrl_1.inject_error_on_ts0) ||
    (xmtbyte_einj_in_os.in_ts1 && cfg_os_einj_ctrl_1.inject_error_on_ts1) ||
    (xmtbyte_einj_in_os.in_ts2 && cfg_os_einj_ctrl_1.inject_error_on_ts2) ||
    (xmtbyte_einj_in_os.in_skp && cfg_os_einj_ctrl_1.inject_error_on_skp) ||
    (xmtbyte_einj_in_os.in_eie && cfg_os_einj_ctrl_1.inject_error_on_eie) ||
    (xmtbyte_einj_in_os.in_eid && cfg_os_einj_ctrl_1.inject_error_on_eid) ||
    (xmtbyte_einj_in_os.in_sds && cfg_os_einj_ctrl_1.inject_error_on_sds)
);

// Enable Tx OS Error Injection when: OS is sent in LTSSM state targeted in cfg_os_einj_ctrl_1
wire latched_ltssm_polling         = (xmtbyte_latched_loadpat_ltssmstate == S_POLL_ACTIVE)       || (xmtbyte_latched_loadpat_ltssmstate == S_POLL_COMPLIANCE)  || (xmtbyte_latched_loadpat_ltssmstate == S_POLL_CONFIG);
wire latched_ltssm_cfg             = (xmtbyte_latched_loadpat_ltssmstate == S_CFG_LINKWD_START)  || (xmtbyte_latched_loadpat_ltssmstate == S_CFG_LINKWD_ACEPT) || (xmtbyte_latched_loadpat_ltssmstate == S_CFG_LANENUM_WAIT) ||
                                     (xmtbyte_latched_loadpat_ltssmstate == S_CFG_LANENUM_ACEPT) || (xmtbyte_latched_loadpat_ltssmstate == S_CFG_COMPLETE)     || (xmtbyte_latched_loadpat_ltssmstate == S_CFG_IDLE);
wire latched_ltssm_l0              = (xmtbyte_latched_loadpat_ltssmstate == S_L0);
wire latched_ltssm_rvcry_noneq     = (xmtbyte_latched_loadpat_ltssmstate == S_RCVRY_LOCK)        || (xmtbyte_latched_loadpat_ltssmstate == S_RCVRY_SPEED)      || (xmtbyte_latched_loadpat_ltssmstate == S_RCVRY_RCVRCFG)    ||
                                     (xmtbyte_latched_loadpat_ltssmstate == S_RCVRY_IDLE);
wire latched_ltssm_rcvry_eq_ph_0_1 = (xmtbyte_latched_loadpat_ltssmstate == S_RCVRY_EQ0)         || (xmtbyte_latched_loadpat_ltssmstate == S_RCVRY_EQ1);
wire latched_ltssm_rcvry_eq_ph_2   = (xmtbyte_latched_loadpat_ltssmstate == S_RCVRY_EQ2);
wire latched_ltssm_rcvry_eq_ph_3   = (xmtbyte_latched_loadpat_ltssmstate == S_RCVRY_EQ3);

wire targeted_ltssm_state = (
    (latched_ltssm_polling         && cfg_os_einj_ctrl_1.inject_error_in_polling)         ||
    (latched_ltssm_cfg             && cfg_os_einj_ctrl_1.inject_error_in_cfg)             ||
    (latched_ltssm_l0              && cfg_os_einj_ctrl_1.inject_error_in_l0)              ||
    (latched_ltssm_rvcry_noneq     && cfg_os_einj_ctrl_1.inject_error_in_rvcry_noneq)     ||
    (latched_ltssm_rcvry_eq_ph_0_1 && cfg_os_einj_ctrl_1.inject_error_in_rcvry_eq_ph_0_1) ||
    (latched_ltssm_rcvry_eq_ph_2   && cfg_os_einj_ctrl_1.inject_error_in_rcvry_eq_ph_2)   ||
    (latched_ltssm_rcvry_eq_ph_3   && cfg_os_einj_ctrl_1.inject_error_in_rcvry_eq_ph_3)
);

// Enable Tx OS Error Injection when: Actual number of errors injected is less than cfg_os_einj_ctrl_1.number_of_errors_injected or cfg_os_einj_ctrl_1.number_of_errors_injected == 0
wire  [4:0] ctrl_1_num_einj               = cfg_os_einj_ctrl_1.number_of_errors_injected;
wire        continuous_error_injection    = (ctrl_1_num_einj == '0);
wire        os_last_active_bytes_einj;
logic [4:0] errors_injected_count;
wire        einj_any_status_complete;
wire        max_number_of_errors_injected = (errors_injected_count == ctrl_1_num_einj) || einj_any_status_complete;
wire        counting_errors_injected      = continuous_error_injection || !max_number_of_errors_injected;

always_ff @(posedge core_clk, negedge core_rst_n) begin: errors_injected_count_PROC
    if (!core_rst_n) begin
        errors_injected_count <= #TP '0;
    end else if (!ctrl_1_tx_os_einj_en || continuous_error_injection) begin
        errors_injected_count <= #TP '0;
    end else if (os_last_active_bytes_einj && (errors_injected_count < ctrl_1_num_einj)) begin
        // Count each OS that has injected error. Signal os_last_active_bytes_einj asserts for one cycle at end of OS with injected error
        errors_injected_count <= #TP errors_injected_count + 1;
    end
end // errors_injected_count_PROC

logic continuous_error_injection_d;

always_ff @(posedge core_clk, negedge core_rst_n) begin: continuous_error_injection_d_PROC
    if (!core_rst_n) begin
        continuous_error_injection_d <= #TP 1'b0;
    end else begin
        continuous_error_injection_d <= #TP continuous_error_injection;
    end
end // continuous_error_injection_d_PROC

// If OS error injection has not already occurred, then enable spacing condition for first OS
logic latched_1_os_einj;

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_os_einj_PROC
    if (!core_rst_n) begin
        latched_1_os_einj <= #TP 1'b0;
    end else if (!ctrl_1_tx_os_einj_en) begin
        latched_1_os_einj <= #TP 1'b0;
    end else if (os_last_active_bytes_einj) begin
        latched_1_os_einj <= #TP 1'b1;
    end
end // latched_1_os_einj_PROC

// Enable Tx OS Error Injection when: This is the next targeted OS according to spacing_between_errors
logic       os_last_active_bytes;
logic [7:0] targeted_os_count;
wire  [7:0] random_os_spacing;
wire  [7:0] ctrl_1_os_spacing      = cfg_os_einj_ctrl_1.spacing_between_errors;
wire  [7:0] spacing_between_errors = (ctrl_1_os_spacing == '0) ? random_os_spacing : ctrl_1_os_spacing;
wire        spacing_en             = (targeted_os_count == 8'(spacing_between_errors - 1)) || !latched_1_os_einj;

localparam PRNG_OS_SPACING_MIN   = 1;
localparam PRNG_OS_SPACING_MAX   = 127;
// See psuedo_random_generator for nbits calculations. For this min/max, nbits == 7
localparam PRNG_OS_SPACING_NBITS = 7;

wire [PRNG_OS_SPACING_NBITS-1:0] prng_os_spacing;
assign random_os_spacing = 8'(prng_os_spacing);

wire prng_os_spacing_en = os_last_active_bytes_einj;

always_ff @(posedge core_clk, negedge core_rst_n) begin: targeted_os_count_PROC
    if (!core_rst_n) begin
        targeted_os_count <= #TP '0;
    end else if (!ctrl_1_tx_os_einj_en || os_last_active_bytes_einj) begin
        targeted_os_count <= #TP '0;
    end else if (targeted_ltssm_state && (in_targeted_os && os_last_active_bytes)) begin
        // Count up when current OS is a targeted OS, in targeted LTSSM state but no error injection because it doesn't match the spacing
        targeted_os_count <= #TP targeted_os_count + 1;
    end
end // targeted_os_count_PROC

// Only active lanes participate in error injection
wire [15:0] einj_lanes;
wire        any_lane_einj = |(16'(smlh_lanes_active) & einj_lanes);

// Overall enable signal
wire        einj_any_status_aborted;
wire        os_einj_en = ltssm_flit_mode && ctrl_1_tx_os_einj_en && in_targeted_os && targeted_ltssm_state && counting_errors_injected && spacing_en && any_lane_einj && !einj_any_status_aborted;

logic [5:0] os_byte; // max value is 40 for Gen6 Skip OS => 6 bits for counter
logic [5:0] os_last_active_bytes_pos;

localparam logic [5:0] SHORT_OS_LENGTH     = 6'd4;
localparam logic [5:0] OS_LENGTH           = 6'd16;
localparam logic [5:0] GEN6_SKIP_OS_LENGTH = 6'd40;

always_comb begin: os_last_active_bytes_pos_PROC
    // Gen1-2: 1s, 2s, 4s
    // Gen3-5: 2s, 4s, 8s, 16s
    //   Gen6: 4s, 8s, 32s
    //   Gen6 16s not currently supported

    case (active_nb)

    'd2: begin
        if (g12_short_os) begin
            os_last_active_bytes_pos = SHORT_OS_LENGTH - 6'd2;
        end else begin
            os_last_active_bytes_pos = OS_LENGTH - 6'd2;
        end
    end

    'd4: begin
        if (g6_rate && xmtbyte_einj_in_os.in_skp) begin
            os_last_active_bytes_pos = GEN6_SKIP_OS_LENGTH - 6'd4;
        end else if (g12_short_os) begin
            os_last_active_bytes_pos = SHORT_OS_LENGTH - 6'd4;
        end else begin
            os_last_active_bytes_pos = OS_LENGTH - 6'd4;
        end
    end

    'd8: begin
        if (g6_rate && xmtbyte_einj_in_os.in_skp) begin
            os_last_active_bytes_pos = GEN6_SKIP_OS_LENGTH - 6'd8;
        end else begin
            os_last_active_bytes_pos = OS_LENGTH - 6'd8;
        end
    end
    


    default: begin
        // Keep linter happy but should never be here
        os_last_active_bytes_pos = '0;
    end
    endcase // case(active_nb)

    os_last_active_bytes = (os_byte == os_last_active_bytes_pos) ;
end // os_last_active_bytes_pos_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: os_byte_PROC
    if (!core_rst_n) begin
        os_byte <= #TP '0;
    end else if (!in_targeted_os || os_last_active_bytes) begin
        os_byte <= #TP '0;
    end else if (in_targeted_os & xmtbyte_txdata_dv) begin
        // in_targeted_os asserts only for the duration of the target OSes appearing in txdata and accounts for txdata_dv
        os_byte <= #TP 6'(os_byte + active_nb);
    end
end // os_byte_PROC

assign os_last_active_bytes_einj = os_einj_en && os_last_active_bytes;

///////////////////
// Inject Errors //
///////////////////
logic [(NL*NB*8)-1:0] int_data_einj;
logic [15:0]          random_einj_bytes;
wire  [15:0]          ctrl_1_einj_bytes = cfg_os_einj_ctrl_2.error_injection_bytes;
assign                einj_bytes        = (ctrl_1_einj_bytes == '0) ? random_einj_bytes : ctrl_1_einj_bytes;
assign                einj_lanes        = cfg_os_einj_ctrl_2.error_injection_lanes;

// Spec says to randomly generate between 1 and 16, but then we need to subtract 1 anyway so generate between 0 and 15
localparam PRNG_EINJ_BYTES_MIN   = 0;
localparam PRNG_EINJ_BYTES_MAX   = 15;
// See psuedo_random_generator for num bits calculations. For this min/max, nbits == 5
localparam PRNG_EINJ_BYTES_NBITS = 5;

wire [PRNG_EINJ_BYTES_NBITS-1:0] prng_einj_byte;
wire prng_einj_byte_en = os_last_active_bytes_einj;

// But if prng_einj_byte is outside {0, ..., 3} for short OS, need to "mod 4" to bring into range (otherwise no einj occurs in short OS and no new prng_einj_byte generated)
// {0, ..., 15} "mod 4" to {0, ..., 3} sustains uniform PRNG. Bitwise equivalent to "mod 4" is "& 3"
// prng_einj_byte is 5-bit signal but is never outside {0, ..., 15}, i.e., downcast to 4-bit and keep linter happy
wire [3:0] random_einj_byte = (g12_short_os) ? 4'(prng_einj_byte & 'd3) : 4'(prng_einj_byte);

always_comb begin: random_einj_bytes_PROC
    random_einj_bytes                   = '0;
    random_einj_bytes[random_einj_byte] = 1'b1;
end // random_einj_bytes_PROC

always_comb begin: inject_errors_PROC
    int_data_einj = xmtbyte_txdata;

    if (os_einj_en) begin
        for (int i = 0; i < NL; i++) begin
            if (smlh_lanes_active[i] && einj_lanes[i]) begin
                if (g6_rate && xmtbyte_einj_in_os.in_skp) begin
                    if (`CX_NB_GEN6 == 8) begin
                        case (os_byte)

                        6'd0: begin
                            // Normally, each bit of 16-bit error_injection_bytes corresponds to a symbol of 16-byte OS
                            // But for Gen6 Skip OS, Spec says each bit corresponds to 2.5 bytes, 20 bits, of the 40-symbol Skip OS
                            // This means some '2.5 bytes' cross over to the next cycle of active bytes
                            // Symbols 0-7
                            int_data_einj[(i*NB*8 +  0) +: 20] = einj_bytes[ 0] ? (xmtbyte_txdata[(i*NB*8 +  0) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 +  0) +: 20];
                            int_data_einj[(i*NB*8 + 20) +: 20] = einj_bytes[ 1] ? (xmtbyte_txdata[(i*NB*8 + 20) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 + 20) +: 20];
                            int_data_einj[(i*NB*8 + 40) +: 20] = einj_bytes[ 2] ? (xmtbyte_txdata[(i*NB*8 + 40) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 + 40) +: 20];
                            int_data_einj[(i*NB*8 + 60) +:  4] = einj_bytes[ 3] ? (xmtbyte_txdata[(i*NB*8 + 60) +:  4] ^     'h1) : xmtbyte_txdata[(i*NB*8 + 60) +:  4];
                        end

                        6'd8: begin
                            // Symbols 8-15
                            int_data_einj[(i*NB*8 +  0) +: 16] = einj_bytes[ 3] ? (xmtbyte_txdata[(i*NB*8 +  0) +: 16] ^  'h1111) : xmtbyte_txdata[(i*NB*8 +  0) +: 16];
                            int_data_einj[(i*NB*8 + 16) +: 20] = einj_bytes[ 4] ? (xmtbyte_txdata[(i*NB*8 + 16) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 + 16) +: 20];
                            int_data_einj[(i*NB*8 + 36) +: 20] = einj_bytes[ 5] ? (xmtbyte_txdata[(i*NB*8 + 36) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 + 36) +: 20];
                            int_data_einj[(i*NB*8 + 56) +:  8] = einj_bytes[ 6] ? (xmtbyte_txdata[(i*NB*8 + 56) +:  8] ^    'h11) : xmtbyte_txdata[(i*NB*8 + 56) +:  8];
                        end

                        6'd16: begin
                            // Symbols 16-23
                            int_data_einj[(i*NB*8 +  0) +: 12] = einj_bytes[ 6] ? (xmtbyte_txdata[(i*NB*8 +  0) +: 12] ^   'h111) : xmtbyte_txdata[(i*NB*8 +  0) +: 12];
                            int_data_einj[(i*NB*8 + 12) +: 20] = einj_bytes[ 7] ? (xmtbyte_txdata[(i*NB*8 + 12) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 + 12) +: 20];
                            int_data_einj[(i*NB*8 + 32) +: 20] = einj_bytes[ 8] ? (xmtbyte_txdata[(i*NB*8 + 32) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 + 32) +: 20];
                            int_data_einj[(i*NB*8 + 52) +: 12] = einj_bytes[ 9] ? (xmtbyte_txdata[(i*NB*8 + 52) +: 12] ^   'h111) : xmtbyte_txdata[(i*NB*8 + 52) +: 12];
                        end

                        6'd24: begin
                            // Symbols 24-31
                            int_data_einj[(i*NB*8 +  0) +:  8] = einj_bytes[ 9] ? (xmtbyte_txdata[(i*NB*8 +  0) +:  8] ^    'h11) : xmtbyte_txdata[(i*NB*8 +  0) +:  8];
                            int_data_einj[(i*NB*8 +  8) +: 20] = einj_bytes[10] ? (xmtbyte_txdata[(i*NB*8 +  8) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 +  8) +: 20];
                            int_data_einj[(i*NB*8 + 28) +: 20] = einj_bytes[11] ? (xmtbyte_txdata[(i*NB*8 + 28) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 + 28) +: 20];
                            int_data_einj[(i*NB*8 + 48) +: 16] = einj_bytes[12] ? (xmtbyte_txdata[(i*NB*8 + 48) +: 16] ^  'h1111) : xmtbyte_txdata[(i*NB*8 + 48) +: 16];
                        end

                        6'd32: begin
                            // Symbols 32-39
                            int_data_einj[(i*NB*8 +  0) +:  4] = einj_bytes[12] ? (xmtbyte_txdata[(i*NB*8 +  0) +:  4] ^     'h1) : xmtbyte_txdata[(i*NB*8 +  0) +:  4];
                            int_data_einj[(i*NB*8 +  4) +: 20] = einj_bytes[13] ? (xmtbyte_txdata[(i*NB*8 +  4) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 +  4) +: 20];
                            int_data_einj[(i*NB*8 + 24) +: 20] = einj_bytes[14] ? (xmtbyte_txdata[(i*NB*8 + 24) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 + 24) +: 20];
                            int_data_einj[(i*NB*8 + 44) +: 20] = einj_bytes[15] ? (xmtbyte_txdata[(i*NB*8 + 44) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 + 44) +: 20];
                        end

                        endcase // case(os_byte)
                    end else if (`CX_NB_GEN6 == 4) begin
                        case (os_byte)

                        6'd0: begin
                            // Symbols 0-3
                            int_data_einj[(i*NB*8 +  0) +: 20] = einj_bytes[ 0] ? (xmtbyte_txdata[(i*NB*8 +  0) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 +  0) +: 20];
                            int_data_einj[(i*NB*8 + 20) +: 12] = einj_bytes[ 1] ? (xmtbyte_txdata[(i*NB*8 + 20) +: 12] ^   'h111) : xmtbyte_txdata[(i*NB*8 + 20) +: 12];
                        end

                        6'd4: begin
                            // Symbols 4-7
                            int_data_einj[(i*NB*8 +  0) +:  8] = einj_bytes[ 1] ? (xmtbyte_txdata[(i*NB*8 +  0) +:  8] ^    'h11) : xmtbyte_txdata[(i*NB*8 +  0) +:  8];
                            int_data_einj[(i*NB*8 +  8) +: 20] = einj_bytes[ 2] ? (xmtbyte_txdata[(i*NB*8 +  8) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 +  8) +: 20];
                            int_data_einj[(i*NB*8 + 28) +:  4] = einj_bytes[ 3] ? (xmtbyte_txdata[(i*NB*8 + 28) +:  4] ^     'h1) : xmtbyte_txdata[(i*NB*8 + 28) +:  4];
                        end

                        6'd8: begin
                            // Symbols 8-11
                            int_data_einj[(i*NB*8 +  0) +: 16] = einj_bytes[ 3] ? (xmtbyte_txdata[(i*NB*8 +  0) +: 16] ^  'h1111) : xmtbyte_txdata[(i*NB*8 +  0) +: 16];
                            int_data_einj[(i*NB*8 + 16) +: 16] = einj_bytes[ 4] ? (xmtbyte_txdata[(i*NB*8 + 16) +: 16] ^  'h1111) : xmtbyte_txdata[(i*NB*8 + 16) +: 16];
                        end

                        6'd12: begin
                            // Symbols 12-15
                            int_data_einj[(i*NB*8 +  0) +:  4] = einj_bytes[ 4] ? (xmtbyte_txdata[(i*NB*8 +  0) +:  4] ^     'h1) : xmtbyte_txdata[(i*NB*8 +  0) +:  4];
                            int_data_einj[(i*NB*8 +  4) +: 20] = einj_bytes[ 5] ? (xmtbyte_txdata[(i*NB*8 +  4) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 +  4) +: 20];
                            int_data_einj[(i*NB*8 + 24) +:  8] = einj_bytes[ 6] ? (xmtbyte_txdata[(i*NB*8 + 24) +:  8] ^    'h11) : xmtbyte_txdata[(i*NB*8 + 24) +:  8];
                        end

                        6'd16: begin
                            // Symbols 16-19
                            int_data_einj[(i*NB*8 +  0) +: 12] = einj_bytes[ 6] ? (xmtbyte_txdata[(i*NB*8 +  0) +: 12] ^   'h111) : xmtbyte_txdata[(i*NB*8 +  0) +: 12];
                            int_data_einj[(i*NB*8 + 12) +: 20] = einj_bytes[ 7] ? (xmtbyte_txdata[(i*NB*8 + 12) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 + 12) +: 20];
                        end

                        6'd20: begin
                            // Symbols 20-23
                            int_data_einj[(i*NB*8 +  0) +: 20] = einj_bytes[ 8] ? (xmtbyte_txdata[(i*NB*8 +  0) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 +  0) +: 20];
                            int_data_einj[(i*NB*8 + 20) +: 12] = einj_bytes[ 9] ? (xmtbyte_txdata[(i*NB*8 + 20) +: 12] ^   'h111) : xmtbyte_txdata[(i*NB*8 + 20) +: 12];
                        end

                        6'd24: begin
                            // Symbols 24-37
                            int_data_einj[(i*NB*8 +  0) +:  8] = einj_bytes[ 9] ? (xmtbyte_txdata[(i*NB*8 +  0) +:  8] ^    'h11) : xmtbyte_txdata[(i*NB*8 +  0) +:  8];
                            int_data_einj[(i*NB*8 +  8) +: 20] = einj_bytes[10] ? (xmtbyte_txdata[(i*NB*8 +  8) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 +  8) +: 20];
                            int_data_einj[(i*NB*8 + 28) +:  4] = einj_bytes[11] ? (xmtbyte_txdata[(i*NB*8 + 28) +:  4] ^     'h1) : xmtbyte_txdata[(i*NB*8 + 28) +:  4];
                        end

                        6'd28: begin
                            // Symbols 28-31
                            int_data_einj[(i*NB*8 +  0) +: 16] = einj_bytes[11] ? (xmtbyte_txdata[(i*NB*8 +  0) +: 16] ^  'h1111) : xmtbyte_txdata[(i*NB*8 +  0) +: 16];
                            int_data_einj[(i*NB*8 + 16) +: 16] = einj_bytes[12] ? (xmtbyte_txdata[(i*NB*8 + 16) +: 16] ^  'h1111) : xmtbyte_txdata[(i*NB*8 + 16) +: 16];
                        end

                        6'd32: begin
                            // Symbols 32-35
                            int_data_einj[(i*NB*8 +  0) +:  4] = einj_bytes[12] ? (xmtbyte_txdata[(i*NB*8 +  0) +:  4] ^     'h1) : xmtbyte_txdata[(i*NB*8 +  0) +:  4];
                            int_data_einj[(i*NB*8 +  4) +: 20] = einj_bytes[13] ? (xmtbyte_txdata[(i*NB*8 +  4) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 +  4) +: 20];
                            int_data_einj[(i*NB*8 + 24) +:  8] = einj_bytes[14] ? (xmtbyte_txdata[(i*NB*8 + 24) +:  8] ^    'h11) : xmtbyte_txdata[(i*NB*8 + 24) +:  8];
                        end

                        6'd36: begin
                            // Symbols 36-39
                            int_data_einj[(i*NB*8 +  0) +: 12] = einj_bytes[14] ? (xmtbyte_txdata[(i*NB*8 +  0) +: 12] ^   'h111) : xmtbyte_txdata[(i*NB*8 +  0) +: 12];
                            int_data_einj[(i*NB*8 + 12) +: 20] = einj_bytes[15] ? (xmtbyte_txdata[(i*NB*8 + 12) +: 20] ^ 'h11111) : xmtbyte_txdata[(i*NB*8 + 12) +: 20];
                        end

                        endcase // case(os_byte)
                    end else if (`CX_NB_GEN6 == 16) begin
                        // Gen6 16s not currently supported
                    end else begin
                    end
                end else begin
                    // For injecting errors in everything else that isn't a Gen6 Skip OS
                    case (active_nb)

                    'd2: begin
                        for (int b = 0; b < 2; b++) begin
                            int_data_einj[(i*NB*8 + b*8) +: 8] = einj_bytes[os_byte + b] ? (xmtbyte_txdata[(i*NB*8 + b*8) +: 8] ^ 'h11)  : xmtbyte_txdata[(i*NB*8 + b*8) +: 8];
                        end
                    end

                    'd4: begin
                        for (int b = 0; b < 4; b++) begin
                            int_data_einj[(i*NB*8 + b*8) +: 8] = einj_bytes[os_byte + b] ? (xmtbyte_txdata[(i*NB*8 + b*8) +: 8] ^ 'h11) : xmtbyte_txdata[(i*NB*8 + b*8) +: 8];
                        end
                    end

                    'd8: begin
                        for (int b = 0; b < 8; b++) begin
                            int_data_einj[(i*NB*8 + b*8) +: 8] = einj_bytes[os_byte + b] ? (xmtbyte_txdata[(i*NB*8 + b*8) +: 8] ^ 'h11) : xmtbyte_txdata[(i*NB*8 + b*8) +: 8];
                        end
                    end


                    endcase // case(active_nb)
                end
            end
        end
    end
end // inject_errors_PROC

logic [(NL*NB*8)-1:0]                          int_data_einj_r;
logic                                          int_data_dv_einj_r;
logic [(NL*NBK)-1:0]                           int_datak_einj_r;
logic [NL-1:0][MAC_TXSB_WD-1:0][OSFLG_WD-1:0]  int_ossending_einj_r ;
logic [(NL*MAC_TXSB_WD)-1:0]                   int_startblock_einj_r;
logic [NL-1:0][2:0]                            int_skp_os_align_sts_r;
logic [NL-1:0]                                 int_elecidle_r;
logic [NL-1:0]                                 int_elecidle_scramble_r;
logic [NL-1:0]                                 int_pm_xmlh_scramble_even_parity_r;
logic                                          int_txdetectrx_loopback_r;
logic [NL-1:0]                                 int_txcompliance_r;
logic                                          int_link_in_training_r;
logic                                          in_rcvr_detection ;

// Register the error injected data, and also give related signals the same latency
always_ff @(posedge core_clk, negedge core_rst_n) begin: int_data_einj_r_PROC
    if (!core_rst_n) begin
        int_data_einj_r                    <= #TP '0;
        int_data_dv_einj_r                 <= #TP 1'b0;
        int_datak_einj_r                   <= #TP '0;
        int_ossending_einj_r               <= #TP '0;
        int_startblock_einj_r              <= #TP '0;
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            int_skp_os_align_sts_r[ii]     <= #TP P_SKP_REPLACE_IDLE;
        end
        int_elecidle_r                     <= #TP '1;
        int_elecidle_scramble_r            <= #TP '1;
        int_pm_xmlh_scramble_even_parity_r <= #TP '0;
        int_txdetectrx_loopback_r          <= #TP '0;
        int_txcompliance_r                 <= #TP '0;
        int_link_in_training_r             <= #TP 1'b0;
    end else begin
        int_data_einj_r                    <= #TP int_data_einj;
        int_data_dv_einj_r                 <= #TP xmtbyte_txdata_dv;
        int_datak_einj_r                   <= #TP xmtbyte_txdatak;
        int_ossending_einj_r               <= #TP xmtbyte_ossending;
        int_startblock_einj_r              <= #TP xmtbyte_txstartblock;
        int_skp_os_align_sts_r             <= #TP xmtbyte_skp_os_align_sts;
        int_elecidle_r                     <= #TP xmtbyte_txelecidle;
        int_elecidle_scramble_r            <= #TP xmtbyte_txelecidle_scramble;
        int_pm_xmlh_scramble_even_parity_r <= #TP pm_xmlh_scramble_even_parity;
        int_txdetectrx_loopback_r          <= #TP xmtbyte_txdetectrx_loopback;
        int_txcompliance_r                 <= #TP xmtbyte_txcompliance;
        int_link_in_training_r             <= #TP xmtbyte_link_in_training;
    end
end // int_data_einj_r_PROC

logic latched_flit_err_inj_latency;

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_flit_err_inj_latency_PROC
    if (!core_rst_n) begin
        latched_flit_err_inj_latency <= #TP 1'b0;
    end else if (smlh_ltssm_state == S_DETECT_QUIET || smlh_ltssm_state == S_DETECT_ACT || smlh_ltssm_state == S_DETECT_WAIT) begin
        latched_flit_err_inj_latency <= #TP cfg_flit_err_inj_latency;
    end
end // latched_flit_err_inj_latency_PROC

// xmtbyte_txdetectrx_loopback for Receiver Detection shall not be delayed.(LTSSM cann't work if delay)
always_comb begin
    in_rcvr_detection = (smlh_ltssm_state == S_DETECT_QUIET)
                      | (smlh_ltssm_state == S_DETECT_ACT  )
                      | (smlh_ltssm_state == S_PRE_DETECT_QUIET )
                      | (smlh_ltssm_state == S_DETECT_WAIT )
                      | (smlh_ltssm_state == S_POLL_ACTIVE ) ;
end

// Connecting error injected data to the module outputs
assign xmteinj_txdata                       = latched_flit_err_inj_latency                        ? int_data_einj_r                    : xmtbyte_txdata;
assign xmteinj_txdata_dv                    = latched_flit_err_inj_latency                        ? int_data_dv_einj_r                 : xmtbyte_txdata_dv;
assign xmteinj_txdatak                      = latched_flit_err_inj_latency                        ? int_datak_einj_r                   : xmtbyte_txdatak;
assign xmteinj_ossending                    = latched_flit_err_inj_latency                        ? int_ossending_einj_r               : xmtbyte_ossending;
assign xmteinj_txstartblock                 = latched_flit_err_inj_latency                        ? int_startblock_einj_r              : xmtbyte_txstartblock;
assign xmteinj_skp_os_align_sts             = latched_flit_err_inj_latency                        ? int_skp_os_align_sts_r             : xmtbyte_skp_os_align_sts;
assign xmteinj_txelecidle                   = latched_flit_err_inj_latency                        ? int_elecidle_r                     : xmtbyte_txelecidle;
assign xmteinj_txelecidle_scramble          = latched_flit_err_inj_latency                        ? int_elecidle_scramble_r            : xmtbyte_txelecidle_scramble;
assign xmteinj_pm_xmlh_scramble_even_parity = latched_flit_err_inj_latency                        ? int_pm_xmlh_scramble_even_parity_r : pm_xmlh_scramble_even_parity;
assign xmteinj_txdetectrx_loopback          = (latched_flit_err_inj_latency & ~in_rcvr_detection) ? int_txdetectrx_loopback_r          : xmtbyte_txdetectrx_loopback;
assign xmteinj_txcompliance                 = latched_flit_err_inj_latency                        ? int_txcompliance_r                 : xmtbyte_txcompliance;
assign xmteinj_link_in_training             = latched_flit_err_inj_latency                        ? int_link_in_training_r             : xmtbyte_link_in_training;

////////////////////
// Status Signals //
////////////////////
wire  ctrl_1_os_einj_en              = cfg_os_einj_ctrl_1.os_error_injection_en;
logic ctrl_1_os_einj_en_d;
wire  ctrl_1_os_einj_en_rising_edge  =  ctrl_1_os_einj_en && !ctrl_1_os_einj_en_d;
wire  ctrl_1_os_einj_en_falling_edge = !ctrl_1_os_einj_en &&  ctrl_1_os_einj_en_d;

always_ff @(posedge core_clk, negedge core_rst_n) begin: ctrl_1_os_einj_en_d_PROC
    if (!core_rst_n) begin
        ctrl_1_os_einj_en_d <= #TP 1'b0;
    end else begin
        ctrl_1_os_einj_en_d <= #TP ctrl_1_os_einj_en;
    end
end // ctrl_1_os_einj_en_d_PROC

cfg_os_einj_ctrl_1_t cfg_os_einj_ctrl_1_d;
cfg_os_einj_ctrl_2_t cfg_os_einj_ctrl_2_d;

wire ctrl_1_changed   = !ctrl_1_os_einj_en_rising_edge && (cfg_os_einj_ctrl_1 != cfg_os_einj_ctrl_1_d);
wire ctrl_2_changed   = (cfg_os_einj_ctrl_2 != cfg_os_einj_ctrl_2_d);
wire ctrl_reg_changed = ctrl_1_changed || ctrl_2_changed;

always_ff @(posedge core_clk, negedge core_rst_n) begin: cfg_os_einj_ctrl_d_PROC
    if (!core_rst_n) begin
        cfg_os_einj_ctrl_1_d <= #TP '0;
        cfg_os_einj_ctrl_2_d <= #TP '0;
    end else begin
        cfg_os_einj_ctrl_1_d <= #TP cfg_os_einj_ctrl_1;
        cfg_os_einj_ctrl_2_d <= #TP cfg_os_einj_ctrl_2;
    end
end // cfg_os_einj_ctrl_d_PROC

// Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
// injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
// or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
// The "not complete" part is handled in each status signal always block
wire einj_en_and_ctrl_reg_changed = ctrl_1_os_einj_en && ctrl_reg_changed;
// For continuous_error_injection, user halts einj by deasserting ctrl_1_os_einj_en and this brings a valid end to einj, i.e., status goes to COMPLETE, not ABORTED
// When ctrl_1_os_einj_en is deasserted, it's possible that other fields in the control registers change at the same time, including ctrl_1_num_einj, without causing error case
// Therefore, check continuous_error_injection_d (one cycle delayed) when checking ctrl_1_os_einj_en_falling_edge
wire ctrl_reg_error_case          = ((ctrl_1_os_einj_en_falling_edge && !continuous_error_injection_d) || einj_en_and_ctrl_reg_changed);

typedef enum logic [1:0] {
    NO_ERROR_INJECTED          = 2'b00,
    ERROR_INJECTION_INCOMPLETE = 2'b01,
    ERROR_INJECTION_COMPLETE   = 2'b10,
    ERROR_INJECTION_ABORTED    = 2'b11
} einj_status_t;

logic         latched_1_ts0_einj;
einj_status_t einj_status_ts0;
wire          einj_status_ts0_incomplete = (einj_status_ts0 == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_ts0_complete   = (einj_status_ts0 == ERROR_INJECTION_COMPLETE);
wire          einj_status_ts0_aborted    = (einj_status_ts0 == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_ts0_einj_PROC
    if (!core_rst_n) begin
        latched_1_ts0_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_ts0_einj <= #TP 1'b0;
    end else if (os_einj_en && xmtbyte_einj_in_os.in_ts0) begin
        // At least one error is injected
        latched_1_ts0_einj <= #TP 1'b1;
    end
end // latched_1_ts0_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_ts0_PROC
    if (!core_rst_n) begin
        einj_status_ts0 <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_ts0 <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_ts0_incomplete) || einj_status_ts0_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_ts0 <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_ts0_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_ts0 <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_ts0_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_ts0 <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_ts0_PROC

logic         latched_1_ts1_einj;
einj_status_t einj_status_ts1;
wire          einj_status_ts1_incomplete = (einj_status_ts1 == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_ts1_complete   = (einj_status_ts1 == ERROR_INJECTION_COMPLETE);
wire          einj_status_ts1_aborted    = (einj_status_ts1 == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_ts1_einj_PROC
    if (!core_rst_n) begin
        latched_1_ts1_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_ts1_einj <= #TP 1'b0;
    end else if (os_einj_en && xmtbyte_einj_in_os.in_ts1) begin
        // At least one error is injected
        latched_1_ts1_einj <= #TP 1'b1;
    end
end // latched_1_ts1_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_ts1_PROC
    if (!core_rst_n) begin
        einj_status_ts1 <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_ts1 <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_ts1_incomplete) || einj_status_ts1_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_ts1 <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_ts1_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_ts1 <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_ts1_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_ts1 <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_ts1_PROC

logic         latched_1_ts2_einj;
einj_status_t einj_status_ts2;
wire          einj_status_ts2_incomplete = (einj_status_ts2 == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_ts2_complete   = (einj_status_ts2 == ERROR_INJECTION_COMPLETE);
wire          einj_status_ts2_aborted    = (einj_status_ts2 == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_ts2_einj_PROC
    if (!core_rst_n) begin
        latched_1_ts2_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_ts2_einj <= #TP 1'b0;
    end else if (os_einj_en && xmtbyte_einj_in_os.in_ts2) begin
        // At least one error is injected
        latched_1_ts2_einj <= #TP 1'b1;
    end
end // latched_1_ts2_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_ts2_PROC
    if (!core_rst_n) begin
        einj_status_ts2 <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_ts2 <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_ts2_incomplete) || einj_status_ts2_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_ts2 <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_ts2_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_ts2 <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_ts2_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_ts2 <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_ts2_PROC

logic         latched_1_skp_einj;
einj_status_t einj_status_skp;
wire          einj_status_skp_incomplete = (einj_status_skp == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_skp_complete   = (einj_status_skp == ERROR_INJECTION_COMPLETE);
wire          einj_status_skp_aborted    = (einj_status_skp == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_skp_einj_PROC
    if (!core_rst_n) begin
        latched_1_skp_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_skp_einj <= #TP 1'b0;
    end else if (os_einj_en && xmtbyte_einj_in_os.in_skp) begin
        // At least one error is injected
        latched_1_skp_einj <= #TP 1'b1;
    end
end // latched_1_skp_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_skp_PROC
    if (!core_rst_n) begin
        einj_status_skp <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_skp <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_skp_incomplete) || einj_status_skp_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_skp <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_skp_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_skp <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_skp_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_skp <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_skp_PROC

logic         latched_1_eie_einj;
einj_status_t einj_status_eie;
wire          einj_status_eie_incomplete = (einj_status_eie == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_eie_complete   = (einj_status_eie == ERROR_INJECTION_COMPLETE);
wire          einj_status_eie_aborted    = (einj_status_eie == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_eie_einj_PROC
    if (!core_rst_n) begin
        latched_1_eie_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_eie_einj <= #TP 1'b0;
    end else if (os_einj_en && xmtbyte_einj_in_os.in_eie) begin
        // At least one error is injected
        latched_1_eie_einj <= #TP 1'b1;
    end
end // latched_1_eie_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_eie_PROC
    if (!core_rst_n) begin
        einj_status_eie <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_eie <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_eie_incomplete) || einj_status_eie_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_eie <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_eie_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_eie <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_eie_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_eie <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_eie_PROC

logic         latched_1_eid_einj;
einj_status_t einj_status_eid;
wire          einj_status_eid_incomplete = (einj_status_eid == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_eid_complete   = (einj_status_eid == ERROR_INJECTION_COMPLETE);
wire          einj_status_eid_aborted    = (einj_status_eid == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_eid_einj_PROC
    if (!core_rst_n) begin
        latched_1_eid_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_eid_einj <= #TP 1'b0;
    end else if (os_einj_en && xmtbyte_einj_in_os.in_eid) begin
        // At least one error is injected
        latched_1_eid_einj <= #TP 1'b1;
    end
end // latched_1_eid_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_eid_PROC
    if (!core_rst_n) begin
        einj_status_eid <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_eid <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_eid_incomplete) || einj_status_eid_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_eid <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_eid_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_eid <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_eid_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_eid <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_eid_PROC

logic         latched_1_sds_einj;
einj_status_t einj_status_sds;
wire          einj_status_sds_incomplete = (einj_status_sds == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_sds_complete   = (einj_status_sds == ERROR_INJECTION_COMPLETE);
wire          einj_status_sds_aborted    = (einj_status_sds == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_sds_einj_PROC
    if (!core_rst_n) begin
        latched_1_sds_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_sds_einj <= #TP 1'b0;
    end else if (os_einj_en && xmtbyte_einj_in_os.in_sds) begin
        // At least one error is injected
        latched_1_sds_einj <= #TP 1'b1;
    end
end // latched_1_sds_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_sds_PROC
    if (!core_rst_n) begin
        einj_status_sds <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_sds <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_sds_incomplete) || einj_status_sds_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_sds <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_sds_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_sds <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_sds_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_sds <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_sds_PROC

logic         latched_1_polling_einj;
einj_status_t einj_status_polling;
wire          einj_status_polling_incomplete = (einj_status_polling == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_polling_complete   = (einj_status_polling == ERROR_INJECTION_COMPLETE);
wire          einj_status_polling_aborted    = (einj_status_polling == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_polling_einj_PROC
    if (!core_rst_n) begin
        latched_1_polling_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_polling_einj <= #TP 1'b0;
    end else if (os_einj_en && latched_ltssm_polling) begin
        // At least one error is injected
        latched_1_polling_einj <= #TP 1'b1;
    end
end // latched_1_polling_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_polling_PROC
    if (!core_rst_n) begin
        einj_status_polling <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_polling <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_polling_incomplete) || einj_status_polling_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_polling <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_polling_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_polling <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_polling_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_polling <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_polling_PROC

logic         latched_1_cfg_einj;
einj_status_t einj_status_cfg;
wire          einj_status_cfg_incomplete = (einj_status_cfg == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_cfg_complete   = (einj_status_cfg == ERROR_INJECTION_COMPLETE);
wire          einj_status_cfg_aborted    = (einj_status_cfg == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_cfg_einj_PROC
    if (!core_rst_n) begin
        latched_1_cfg_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_cfg_einj <= #TP 1'b0;
    end else if (os_einj_en && latched_ltssm_cfg) begin
        // At least one error is injected
        latched_1_cfg_einj <= #TP 1'b1;
    end
end // latched_1_cfg_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_cfg_PROC
    if (!core_rst_n) begin
        einj_status_cfg <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_cfg <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_cfg_incomplete) || einj_status_cfg_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_cfg <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_cfg_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_cfg <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_cfg_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_cfg <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_cfg_PROC

logic         latched_1_l0_einj;
einj_status_t einj_status_l0;
wire          einj_status_l0_incomplete = (einj_status_l0 == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_l0_complete   = (einj_status_l0 == ERROR_INJECTION_COMPLETE);
wire          einj_status_l0_aborted    = (einj_status_l0 == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_l0_einj_PROC
    if (!core_rst_n) begin
        latched_1_l0_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_l0_einj <= #TP 1'b0;
    end else if (os_einj_en && latched_ltssm_l0) begin
        // At least one error is injected
        latched_1_l0_einj <= #TP 1'b1;
    end
end // latched_1_l0_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_l0_PROC
    if (!core_rst_n) begin
        einj_status_l0 <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_l0 <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_l0_incomplete) || einj_status_l0_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_l0 <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_l0_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_l0 <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_l0_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_l0 <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_l0_PROC

logic         latched_1_rvcry_noneq_einj;
einj_status_t einj_status_rvcry_noneq;
wire          einj_status_rvcry_noneq_incomplete = (einj_status_rvcry_noneq == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_rvcry_noneq_complete   = (einj_status_rvcry_noneq == ERROR_INJECTION_COMPLETE);
wire          einj_status_rvcry_noneq_aborted    = (einj_status_rvcry_noneq == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_rvcry_noneq_einj_PROC
    if (!core_rst_n) begin
        latched_1_rvcry_noneq_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_rvcry_noneq_einj <= #TP 1'b0;
    end else if (os_einj_en && latched_ltssm_rvcry_noneq) begin
        // At least one error is injected
        latched_1_rvcry_noneq_einj <= #TP 1'b1;
    end
end // latched_1_rvcry_noneq_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_rvcry_noneq_PROC
    if (!core_rst_n) begin
        einj_status_rvcry_noneq <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_rvcry_noneq <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_rvcry_noneq_incomplete) || einj_status_rvcry_noneq_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_rvcry_noneq <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_rvcry_noneq_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_rvcry_noneq <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_rvcry_noneq_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_rvcry_noneq <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_rvcry_noneq_PROC

logic         latched_1_rcvry_eq_ph_0_1_einj;
einj_status_t einj_status_rcvry_eq_ph_0_1;
wire          einj_status_rcvry_eq_ph_0_1_incomplete = (einj_status_rcvry_eq_ph_0_1 == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_rcvry_eq_ph_0_1_complete   = (einj_status_rcvry_eq_ph_0_1 == ERROR_INJECTION_COMPLETE);
wire          einj_status_rcvry_eq_ph_0_1_aborted    = (einj_status_rcvry_eq_ph_0_1 == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_rcvry_eq_ph_0_1_einj_PROC
    if (!core_rst_n) begin
        latched_1_rcvry_eq_ph_0_1_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_rcvry_eq_ph_0_1_einj <= #TP 1'b0;
    end else if (os_einj_en && latched_ltssm_rcvry_eq_ph_0_1) begin
        // At least one error is injected
        latched_1_rcvry_eq_ph_0_1_einj <= #TP 1'b1;
    end
end // latched_1_rcvry_eq_ph_0_1_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_rcvry_eq_ph_0_1_PROC
    if (!core_rst_n) begin
        einj_status_rcvry_eq_ph_0_1 <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_rcvry_eq_ph_0_1 <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_rcvry_eq_ph_0_1_incomplete) || einj_status_rcvry_eq_ph_0_1_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_rcvry_eq_ph_0_1 <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_rcvry_eq_ph_0_1_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_rcvry_eq_ph_0_1 <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_rcvry_eq_ph_0_1_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_rcvry_eq_ph_0_1 <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_rcvry_eq_ph_0_1_PROC

logic         latched_1_rcvry_eq_ph_2_einj;
einj_status_t einj_status_rcvry_eq_ph_2;
wire          einj_status_rcvry_eq_ph_2_incomplete = (einj_status_rcvry_eq_ph_2 == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_rcvry_eq_ph_2_complete   = (einj_status_rcvry_eq_ph_2 == ERROR_INJECTION_COMPLETE);
wire          einj_status_rcvry_eq_ph_2_aborted    = (einj_status_rcvry_eq_ph_2 == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_rcvry_eq_ph_2_einj_PROC
    if (!core_rst_n) begin
        latched_1_rcvry_eq_ph_2_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_rcvry_eq_ph_2_einj <= #TP 1'b0;
    end else if (os_einj_en && latched_ltssm_rcvry_eq_ph_2) begin
        // At least one error is injected
        latched_1_rcvry_eq_ph_2_einj <= #TP 1'b1;
    end
end // latched_1_rcvry_eq_ph_2_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_rcvry_eq_ph_2_PROC
    if (!core_rst_n) begin
        einj_status_rcvry_eq_ph_2 <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_rcvry_eq_ph_2 <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_rcvry_eq_ph_2_incomplete) || einj_status_rcvry_eq_ph_2_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_rcvry_eq_ph_2 <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_rcvry_eq_ph_2_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_rcvry_eq_ph_2 <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_rcvry_eq_ph_2_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_rcvry_eq_ph_2 <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_rcvry_eq_ph_2_PROC

logic         latched_1_rcvry_eq_ph_3_einj;
einj_status_t einj_status_rcvry_eq_ph_3;
wire          einj_status_rcvry_eq_ph_3_incomplete = (einj_status_rcvry_eq_ph_3 == ERROR_INJECTION_INCOMPLETE);
wire          einj_status_rcvry_eq_ph_3_complete   = (einj_status_rcvry_eq_ph_3 == ERROR_INJECTION_COMPLETE);
wire          einj_status_rcvry_eq_ph_3_aborted    = (einj_status_rcvry_eq_ph_3 == ERROR_INJECTION_ABORTED);

always_ff @(posedge core_clk, negedge core_rst_n) begin: latched_1_rcvry_eq_ph_3_einj_PROC
    if (!core_rst_n) begin
        latched_1_rcvry_eq_ph_3_einj <= #TP 1'b0;
    end else if (ctrl_1_os_einj_en_falling_edge) begin
        latched_1_rcvry_eq_ph_3_einj <= #TP 1'b0;
    end else if (os_einj_en && latched_ltssm_rcvry_eq_ph_3) begin
        // At least one error is injected
        latched_1_rcvry_eq_ph_3_einj <= #TP 1'b1;
    end
end // latched_1_rcvry_eq_ph_3_einj_PROC

always_ff @(posedge core_clk, negedge core_rst_n) begin: einj_status_rcvry_eq_ph_3_PROC
    if (!core_rst_n) begin
        einj_status_rcvry_eq_ph_3 <= #TP NO_ERROR_INJECTED;
    end else if (ctrl_1_os_einj_en_rising_edge) begin
        einj_status_rcvry_eq_ph_3 <= #TP NO_ERROR_INJECTED;
    end else if ((ctrl_reg_error_case && einj_status_rcvry_eq_ph_3_incomplete) || einj_status_rcvry_eq_ph_3_aborted) begin
        // Error case – error injection aborted, either Ordered Set Error Injection Enable was cleared while
        // injection was incomplete or optionally any bit in Ordered Set Error Injection Control 1[31:1]
        // or Ordered Set Injection Control 2 was changed while Injection was enabled and not complete.
        einj_status_rcvry_eq_ph_3 <= #TP ERROR_INJECTION_ABORTED;
    end else if (latched_1_rcvry_eq_ph_3_einj && counting_errors_injected) begin
        // At least one error is injected, but not completed
        einj_status_rcvry_eq_ph_3 <= #TP ERROR_INJECTION_INCOMPLETE;
    end else if (latched_1_rcvry_eq_ph_3_einj && !counting_errors_injected) begin
        // Error injection completed
        einj_status_rcvry_eq_ph_3 <= #TP ERROR_INJECTION_COMPLETE;
    end
end // einj_status_rcvry_eq_ph_3_PROC

always_comb begin: xmlh_tx_os_einj_status_PROC
    xmlh_tx_os_einj_status.ts0             = einj_status_ts0;
    xmlh_tx_os_einj_status.ts1             = einj_status_ts1;
    xmlh_tx_os_einj_status.ts2             = einj_status_ts2;
    xmlh_tx_os_einj_status.skp             = einj_status_skp;
    xmlh_tx_os_einj_status.eie             = einj_status_eie;
    xmlh_tx_os_einj_status.eid             = einj_status_eid;
    xmlh_tx_os_einj_status.sds             = einj_status_sds;

    xmlh_tx_os_einj_status.polling         = einj_status_polling;
    xmlh_tx_os_einj_status.cfg             = einj_status_cfg;
    xmlh_tx_os_einj_status.l0              = einj_status_l0;
    xmlh_tx_os_einj_status.rvcry_noneq     = einj_status_rvcry_noneq;
    xmlh_tx_os_einj_status.rcvry_eq_ph_0_1 = einj_status_rcvry_eq_ph_0_1;
    xmlh_tx_os_einj_status.rcvry_eq_ph_2   = einj_status_rcvry_eq_ph_2;
    xmlh_tx_os_einj_status.rcvry_eq_ph_3   = einj_status_rcvry_eq_ph_3;
end // xmlh_tx_os_einj_status_PROC

assign einj_any_status_complete = !ctrl_1_os_einj_en_rising_edge && (
    einj_status_ts0_complete             ||
    einj_status_ts1_complete             ||
    einj_status_ts2_complete             ||
    einj_status_skp_complete             ||
    einj_status_eie_complete             ||
    einj_status_eid_complete             ||
    einj_status_sds_complete             ||
    einj_status_polling_complete         ||
    einj_status_cfg_complete             ||
    einj_status_l0_complete              ||
    einj_status_rvcry_noneq_complete     ||
    einj_status_rcvry_eq_ph_0_1_complete ||
    einj_status_rcvry_eq_ph_2_complete   ||
    einj_status_rcvry_eq_ph_3_complete
);

assign einj_any_status_aborted = !ctrl_1_os_einj_en_rising_edge && (
    einj_status_ts0_aborted             ||
    einj_status_ts1_aborted             ||
    einj_status_ts2_aborted             ||
    einj_status_skp_aborted             ||
    einj_status_eie_aborted             ||
    einj_status_eid_aborted             ||
    einj_status_sds_aborted             ||
    einj_status_polling_aborted         ||
    einj_status_cfg_aborted             ||
    einj_status_l0_aborted              ||
    einj_status_rvcry_noneq_aborted     ||
    einj_status_rcvry_eq_ph_0_1_aborted ||
    einj_status_rcvry_eq_ph_2_aborted   ||
    einj_status_rcvry_eq_ph_3_aborted
);

pseudo_random_generator
 #(
    .MIN        (PRNG_OS_SPACING_MIN),
    .MAX        (PRNG_OS_SPACING_MAX)
) u_prng_os_spacing (
    .core_clk   (core_clk),
    .core_rst_n (core_rst_n),
    .en         (prng_os_spacing_en),
    .rand_num   (prng_os_spacing)
); // u_prng_os_spacing

pseudo_random_generator
 #(
    .MIN        (PRNG_EINJ_BYTES_MIN),
    .MAX        (PRNG_EINJ_BYTES_MAX)
) u_prng_einj_byte (
    .core_clk   (core_clk),
    .core_rst_n (core_rst_n),
    .en         (prng_einj_byte_en),
    .rand_num   (prng_einj_byte)
); // u_prng_einj_byte

endmodule
