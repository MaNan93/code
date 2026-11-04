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
// --- RCS information:
// ---   $DateTime: 2024/01/10 14:23:51 $
// ---   $Revision: #13 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_arb_mux.sv#13 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL ARB/MUX Layer. The ARB/MUX provides dynamic muxing of the CXL.io and CXL.cachemem
// link layer control and data signals to interface with the Flex Bus physical layer.
//
// This module implements arbitration and multiplexing between CXL.io and 
// CXL.cachemem datapath on SPIF interface from vLSM to the Physical Layer.
// Interfaces with CXL.io and CXL.cachemem Link vLSM ALMP Generators to communicate 
// ALMP packets over the link. ALMP interface is implemented as a signle cycle
// command.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Spif/pkg/spif_pkg.svh"

module DWC_cxl_arb_mux
    import spif_pkg::*;
#(
    parameter TP = `TP
) 
                          (
// Inputs ------------------------------------------------------------------------------
    input                             core_clk              , // Core clock
    input                             core_rst_n            , // Core reset
    input        [3:0]                cfg_cxl_io_arb_weight , // CXL.io Weighted Round Robin Arbitration Weight
    input        [3:0]                cfg_cxl_mc_arb_weight , // CXL.cache and CXL.mem Weighted Round Robin Arbitration Weight
    input                             pcie_flit_mode        , // PCIe Flit Mode
    input                             pcie_nfm_mode         , // PCIe non-Flit Mode
// CXL.io ALMP Message Interface -------------------------------------------------------
    input                             almp_io_valid         , // CXL.io ALMP data valid
    input        [127:0]              almp_io_data          , // CXL.io ALMP data
    output logic                      almp_io_trdy          , // ABB/MUX is ready to accept ALMP message
    input        [15:0]               almp_io_data_chk      , // CXL.io ALMP data prot
// CXL.io Link Layer to vLSM SPIF Interface --------------------------------------------
    input  stream_id_e                vlsm_io_stream        , // Link Layer indicates the Stream ID to use with data
    input                             vlsm_io_irdy          , // Link Layer is ready to transfer data
    input        [1:0]                vlsm_io_pri           , // Link Layer indicating priority of lp_irdy
    input        [SPIF_LP_NVLD-1:0]   vlsm_io_valid         , // Link Layer indicates data valid on the corresponding lp_data bytes
    input        [SPIF_NBYTES*8-1:0]  vlsm_io_data          , // Link Layer data
    input        [SPIF_NWORDS-1:0]    vlsm_io_dlp_start     , // Start of Data Link Layer Packet in the word
    input        [SPIF_NWORDS-1:0]    vlsm_io_dlp_end       , // End of Data Link Layer Packet in the word
    input        [SPIF_NWORDS-1:0]    vlsm_io_tlp_start     , // Start of Transaction Layer Packet in the word
    input        [SPIF_NWORDS-1:0]    vlsm_io_tlp_end       , // End of Transaction Layer Packet in the word
    input        [SPIF_NBYTES-1:0]    vlsm_io_data_chk      , // Link Layer data protection code
    input                             vlsm_io_rasdp_error   , // Link Layer datapath protection error
    input                             vlsm_io_nop_flit      , // Link Layer indicates that the flit is NOP and is permitted to bypass TX Retry Buffer
    output logic                      vlsm_io_trdy          , // Physical Layer is ready to accept data
// CXL.cachemem ALMP Message Interface -------------------------------------------------
    input                             almp_mc_valid         , // CXL.io ALMP data valid
    input        [127:0]              almp_mc_data          , // CXL.io ALMP data
    output logic                      almp_mc_trdy          , // ABB/MUX is ready to accept ALMP message
    input        [15:0]               almp_mc_data_chk      , // CXL.io ALMP data prot
// CXL.cachemem Link Layer to vLSM SPIF Interface --------------------------------------
    input  stream_id_e                vlsm_mc_stream        , // Link Layer indicates the Stream ID to use with data
    input                             vlsm_mc_irdy          , // Link Layer is ready to transfer data
    input        [1:0]                vlsm_mc_pri           , // Link Layer indicating priority of lp_irdy
    input        [SPIF_LP_NVLD-1:0]   vlsm_mc_valid         , // Link Layer indicates data valid on the corresponding lp_data bytes
    input        [SPIF_NBYTES*8-1:0]  vlsm_mc_data          , // Link Layer data
    input                             vlsm_mc_crc_valid     , // Link Layer indication that corresponding CRC bytes are valid
    input        [SPIF_NCRC*8-1:0]    vlsm_mc_crc_data      , // Link Layer CRC bytes
    input        [SPIF_NBYTES-1:0]    vlsm_mc_data_chk      , // Link Layer data protection code
    input                             vlsm_mc_rasdp_error   , // Link Layer datapath protection error
    input                             vlsm_mc_nop_flit      , // Link Layer indicates that the flit is NOP and is permitted to bypass TX Retry Buffer
    input                             vlsm_mc_corrupt_crc   , // Link Layer indicates that the flit needs containment
    output logic                      vlsm_mc_trdy          , // Physical Layer is ready to accept data
// vLSM to Physical Layer SPIF Interface -----------------------------------------------
    input                             vlsm_pl_trdy          , // Physical Layer is ready to accept data
    input                             vlsm_pl_stall_req     , // Physical Layer stall request
    output logic                      vlsm_lp_stall_ack     , // Link Layer stall acknowledge
    output logic                      vlsm_lp_irdy          , // Link Layer is ready to transfer data
    output logic [1:0]                vlsm_lp_pri           , // Link Layer indicating priority of lp_irdy
    output logic [SPIF_LP_NVLD-1:0]   vlsm_lp_valid         , // Link Layer indicates data valid on the corresponding lp_data bytes
    output logic [SPIF_NBYTES*8-1:0]  vlsm_lp_data          , // Link Layer data
    output logic                      vlsm_lp_crc_valid     , // Link Layer indication that corresponding CRC bytes are valid
    output logic [SPIF_NCRC*8-1:0]    vlsm_lp_crc_data      , // Link Layer CRC bytes
    output logic [SPIF_NWORDS-1:0]    vlsm_lp_dlp_start     , // Start of Data Link Layer Packet in the word
    output logic [SPIF_NWORDS-1:0]    vlsm_lp_dlp_end       , // End of Data Link Layer Packet in the word
    output logic [SPIF_NWORDS-1:0]    vlsm_lp_tlp_start     , // Start of Transaction Layer Packet in the word
    output logic [SPIF_NWORDS-1:0]    vlsm_lp_tlp_end       , // End of Transaction Layer Packet in the word
    output logic [SPIF_NBYTES-1:0]    vlsm_lp_data_chk      ,
    output logic                      vlsm_lp_rasdp_error   ,
    output logic                      vlsm_lp_nop_flit      , // Link Layer indicates that the flit is NOP and is permitted to bypass TX Retry Buffer
    output logic                      vlsm_lp_corrupt_crc   , // Link Layer indicates that the flit needs containment
    output stream_id_e                vlsm_lp_stream          // Link Layer indicates the Stream ID to use with data
);

// Arbiter Configuration Parameters
localparam         NUM_CLIENTS     = 2;
localparam         P_WIDTH         = 4;

// Arbiter Grant Encodings
localparam [1:0]   ARB_GNT_IO      = 2'b01;
localparam [1:0]   ARB_GNT_MC      = 2'b10;

// Arbiter Decision Structure
typedef struct packed {
    logic                               almp ; // Arbiter Grant is based on ALMP Request
    logic [(NUM_CLIENTS - 1) : 0]       grant; // Arbiter Grant
} arb_grant_t;

// Local Declarations
logic [(NUM_CLIENTS - 1) : 0]           arb_force_s;   // Arbitration Decision force to CXL.io and CXL.cachemem
logic                                   arb_almp_s;    // Arbitration Grant is based on ALMP message request
logic                                   arb_halt_s;    // Arbitration Halt when flit is in progress
logic                                   arb_done_s;    // Arbitration Done asserted on the last cycle of the flit
logic                                   arb_ena_s;     // Arbitration Enable
logic [(NUM_CLIENTS - 1) : 0]           arb_req_s;     // Arbitration Request
logic [(NUM_CLIENTS - 1) : 0]           arb_gnt_s;     // Arbitration Grant
arb_grant_t                             arb_grant_nxt; // Arbitration Grant - next state
arb_grant_t                             arb_grant_r;   // Arbitration Grant (stable for the flit duration)
arb_grant_t                             arb_grant;     // Arbitration Grant (stable for the flit duration)


// ----------------------------------------------------------------------------
// ARB/MUX stall_req/stall_ack handshake
// ----------------------------------------------------------------------------
logic vlsm_lp_stall_ack_nxt;

always_comb begin
    // Assert ARB/MUX Stall Acknowledge at the cycle arbitration decision is made, i.e. SOF cycle
    if (vlsm_pl_stall_req && !arb_halt_s)
       vlsm_lp_stall_ack_nxt = 1'b1;
    // De-assert ARB/MUX Stall Acknowledge on de-assertion of ARB/MUX Stall Request
    else if (!vlsm_pl_stall_req && vlsm_lp_stall_ack)
       vlsm_lp_stall_ack_nxt = 1'b0;
    else
       vlsm_lp_stall_ack_nxt = vlsm_lp_stall_ack;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        vlsm_lp_stall_ack <= # TP 1'b0;
    end
    else begin
        vlsm_lp_stall_ack <= # TP vlsm_lp_stall_ack_nxt;
    end
end
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// DW Counter: counts number of DWs in the flit
// ----------------------------------------------------------------------------
logic  int_halt_s;
logic  int_done_s;

assign arb_halt_s = pcie_nfm_mode ? 1'b0 : int_halt_s;
assign arb_done_s = pcie_nfm_mode ? 1'b1 : int_done_s;

spif_flit_dw_cnt
 u_flit_dw_cnt (
    .core_clk           ( core_clk                     ),
    .core_rst_n         ( core_rst_n                   ),
    .pcie_flit_mode     ( pcie_flit_mode               ),
    .rst_flit_alignment ( 1'b0                         ),
    .dw_cnt_ena         ( vlsm_lp_irdy && vlsm_pl_trdy ),
    .dw_cnt_idle        ( /* Unconnected */            ),
    .dw_cnt_busy        ( int_halt_s                   ),
    .dw_cnt_last        ( /* Unconnected */            ),
    .dw_cnt_done        ( int_done_s                   )
);
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// ARB/MUX Arbitration
// ----------------------------------------------------------------------------
// Force arbitration decision if flit priority is High (lp_pri[0]=0) on the corresponding Link Layer interface
// If both CXL.io and CXL.cachemem Link Layer de-assert lp_pri[0] then the priority is equaly high
assign arb_force_s  = {vlsm_mc_irdy && !vlsm_mc_pri[0], vlsm_io_irdy && !vlsm_io_pri[0]};

// Gate arbitration request if ARB/MUX is stalled
// Gate CXL.cachemem request if CXL.io flit priority is High (lp_pri[0]=0)
assign arb_req_s    = (vlsm_pl_stall_req || vlsm_lp_stall_ack) ? 2'b00: ( ((|arb_force_s)? arb_force_s : {NUM_CLIENTS{1'b1}}) & {(vlsm_mc_irdy || almp_mc_valid), (vlsm_io_irdy || almp_io_valid)});

assign arb_almp_s   = ((arb_gnt_s == ARB_GNT_IO) && almp_io_valid && !arb_force_s[0]) || ((arb_gnt_s == ARB_GNT_MC) && almp_mc_valid && !arb_force_s[1]);

// Enable arbitration request when there is no flit in progress and there is no decision made previously
assign arb_ena_s    = !arb_halt_s && !(|arb_grant_r.grant);

assign arb_grant    = arb_ena_s ? {arb_almp_s, arb_gnt_s} : arb_grant_r;

always_comb begin
    // reset arbitration decision on the last cycle of the flit
    if (vlsm_pl_trdy && arb_done_s) begin
        arb_grant_nxt = '0;
    // capture arbitration decision at start of flit cycle if no decision has been made yet
    end else if (arb_ena_s) begin
        arb_grant_nxt = {arb_almp_s, arb_gnt_s};
    end else begin
        arb_grant_nxt = arb_grant_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        arb_grant_r <= # TP '0;
    end
    else begin
        arb_grant_r <= # TP arb_grant_nxt;
    end
end

// wrapper for weighted round-robin (wrr) arbitration, instantiating weight-to-priority converter and arbiter
DWC_pcie_arb_wrr
 #(
    .NUM_CLIENTS       ( NUM_CLIENTS           ),
    .P_WIDTH           ( P_WIDTH               )
) u_cxl_arb_wrr (
    .core_clk          ( core_clk              ),
    .core_rst_n        ( core_rst_n            ),
    .cfg_io_arb_weight ( cfg_cxl_io_arb_weight ),
    .cfg_mc_arb_weight ( cfg_cxl_mc_arb_weight ),
    .arb_enable        ( arb_ena_s             ),
    .arb_req           ( arb_req_s             ),
    .arb_gnt           ( arb_gnt_s             )
);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// ARB/MUX Mux based on the decision from the ARB/MUX Arbiter
// ----------------------------------------------------------------------------
always_comb begin : flit_mux_PROC
    almp_io_trdy        = '0 ;
    almp_mc_trdy        = '0 ;
    vlsm_io_trdy        = '0 ;
    vlsm_mc_trdy        = '0 ;

    vlsm_lp_irdy        = '0 ;
    vlsm_lp_pri         = 2'b01 ;
    vlsm_lp_valid       = '0 ;
    vlsm_lp_data        = '0 ;
    vlsm_lp_crc_valid   = '0 ;
    vlsm_lp_crc_data    = '0 ;
    vlsm_lp_dlp_start   = '0 ;
    vlsm_lp_dlp_end     = '0 ;
    vlsm_lp_tlp_start   = '0 ;
    vlsm_lp_tlp_end     = '0 ;
    vlsm_lp_stream      = SID_RSVD ;
    vlsm_lp_data_chk    = '0;
    vlsm_lp_rasdp_error = '0;
    vlsm_lp_nop_flit    = '0 ;
    vlsm_lp_corrupt_crc = '0 ;

    unique case (arb_grant.grant) 
        ARB_GNT_IO        : begin
            if (arb_grant.almp) begin
                almp_io_trdy        = vlsm_pl_trdy && !arb_halt_s ;

                vlsm_lp_stream      = SID_ALMP            ;
                vlsm_lp_irdy        = 1'b1                ;
                vlsm_lp_valid       = 1'b1                ;
                vlsm_lp_data        = arb_halt_s ? '0 : {{(SPIF_NBYTES*8-128){1'b0}}, almp_io_data};
                vlsm_lp_data_chk    = arb_halt_s ? {SPIF_NBYTES{1'b1}} : {{(SPIF_NBYTES-16){1'b1}}, almp_io_data_chk};
            end
            else begin
                vlsm_io_trdy        = vlsm_pl_trdy        ;

                vlsm_lp_stream      = vlsm_io_stream      ;
                vlsm_lp_irdy        = vlsm_io_irdy        ;
                vlsm_lp_pri         = vlsm_io_pri         ;
                vlsm_lp_valid       = vlsm_io_valid       ;
                vlsm_lp_data        = vlsm_io_data        ;
                vlsm_lp_dlp_start   = vlsm_io_dlp_start   ;
                vlsm_lp_dlp_end     = vlsm_io_dlp_end     ;
                vlsm_lp_tlp_start   = vlsm_io_tlp_start   ;
                vlsm_lp_tlp_end     = vlsm_io_tlp_end     ;
                vlsm_lp_data_chk    = vlsm_io_data_chk    ;
                vlsm_lp_rasdp_error = vlsm_io_rasdp_error ;
                vlsm_lp_nop_flit    = vlsm_io_nop_flit    ;
            end
        end
        ARB_GNT_MC : begin
            if (arb_grant.almp) begin
                almp_mc_trdy        = vlsm_pl_trdy && !arb_halt_s ;
                vlsm_lp_stream      = SID_ALMP            ;
                vlsm_lp_irdy        = 1'b1                ;
                vlsm_lp_valid       = 1'b1                ;
                vlsm_lp_data        = arb_halt_s ? '0 : {{(SPIF_NBYTES*8-128){1'b0}}, almp_mc_data};
                vlsm_lp_data_chk    = arb_halt_s ? {SPIF_NBYTES{1'b1}} : {{(SPIF_NBYTES-16){1'b1}}, almp_mc_data_chk};
        end
            else begin
                vlsm_mc_trdy        = vlsm_pl_trdy        ;

                vlsm_lp_stream      = vlsm_mc_stream      ;
                vlsm_lp_irdy        = vlsm_mc_irdy        ;
                vlsm_lp_pri         = vlsm_mc_pri         ;
                vlsm_lp_valid       = vlsm_mc_valid       ;
                vlsm_lp_data        = vlsm_mc_data        ;
                vlsm_lp_crc_valid   = vlsm_mc_crc_valid   ;
                vlsm_lp_crc_data    = vlsm_mc_crc_data    ;
                vlsm_lp_data_chk    = vlsm_mc_data_chk    ;
                vlsm_lp_rasdp_error = vlsm_mc_rasdp_error ;
                vlsm_lp_nop_flit    = vlsm_mc_nop_flit    ;
                vlsm_lp_corrupt_crc = vlsm_mc_corrupt_crc ;
            end
        end
        default          : begin 
            // No arbitration decision is made
            vlsm_lp_irdy  = 1'b0;
        end
    endcase
end
// ----------------------------------------------------------------------------

endmodule
