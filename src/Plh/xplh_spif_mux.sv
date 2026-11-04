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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_spif_mux.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit Data Link Layer Hander
// --- This module handles 128b, 256b and 512b datapath widths. 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer2/svif/tx_lp_if.svh"
`include "Spif/pkg/spif_pkg.svh"
`include "products/cx_pl_pkg.svh"

module xplh_spif_mux
    import spif_pkg::SPIF_LP_NVLD;
    import spif_pkg::SPIF_NBYTES;
    import spif_pkg::SPIF_NCRC;
    import spif_pkg::SPIF_NWORDS;
    import spif_pkg::stream_id_e;
    import spif_pkg::SID_PCIE;
    import spif_pkg::SID_CXL_IO;
    import spif_pkg::SID_CXL_CM;
    import spif_pkg::SID_ALMP;
    import cx_pl_pkg::P_NW;
    import cx_pl_pkg::P_NFM_NW;
#(
    parameter   INST        = 0,             // The uniquifying parameter for each port logic instance.
    parameter   TP          = `TP            // Clock to Q delay (simulator insurance)
) 
                        (
// Interfaces --------------------------------------------------------------------------
    tx_lp_if.slave_mp                b_xdlh_xplh_sp        , // Link Layer Transmit Slave Port XDLH->XPLH
    tx_lp_if.master_mp               b_xplh_xmlh_mp        , // Link Layer Transmit Master Port XPLH->XMLH
// Inputs ------------------------------------------------------------------------------
    input                            core_clk              , // Core clock
    input                            core_rst_n            , // Core reset
    input                            spif_enable           , // SPIF Interface Enable
    input                            pcie_flit_mode        , // PCIe Flit Mode
    input                            pcie_nfm_mode         , // PCIe non-Flit Mode 
    input                            cxl_mode_enable       , // Set to 1 when both sides enable/support/exchange CXL mode and current speed of the link is Gen3 or above
    input                            xplh_payload_enable   , // Enable payload flits from Link Layers
    input   [5:0]                    xplh_link_mode        , // Current Link Width
    input                            xplh_stall_ack        , // Stall acknowledge on SPIF interface
    input        stream_id_e         vlsm_lp_stream        , // Link Layer indicates the Stream ID to use with data
    input                            vlsm_lp_irdy          , // Link Layer is ready to transfer data
    input        [SPIF_LP_NVLD-1:0]  vlsm_lp_valid         , // Link Layer indicates data valid on the corresponding lp_data bytes
    input        [SPIF_NBYTES*8-1:0] vlsm_lp_data          , // Link Layer data
    input                            vlsm_lp_crc_valid     , // Link Layer indication that corresponding CRC bytes are valid
    input        [SPIF_NCRC*8-1:0]   vlsm_lp_crc_data      , // Link Layer CRC bytes
    input        [SPIF_NWORDS-1:0]   vlsm_lp_dlp_start     , // Start of Data Link Layer Packet in the word
    input        [SPIF_NWORDS-1:0]   vlsm_lp_dlp_end       , // End of Data Link Layer Packet in the word
    input        [SPIF_NWORDS-1:0]   vlsm_lp_tlp_start     , // Start of Transaction Layer Packet in the word
    input        [SPIF_NWORDS-1:0]   vlsm_lp_tlp_end       , // End of Transaction Layer Packet in the word
    input        [SPIF_NBYTES-1:0]   vlsm_lp_data_chk      ,
    input                            vlsm_lp_rasdp_error   ,
    input                            vlsm_lp_nop_flit      , // Link Layer indicates that the flit is NOP and is permitted to bypass TX Retry Buffer
    output logic                     vlsm_pl_skip_trdy     , // Packet Layer indicates that it is ready to insert Skip Ordered Set
    output logic                     vlsm_pl_trdy            // Physical Layer is ready to accept data
);

// Reduced data width for 1024-bit core in PCIe non-flit mode
localparam SPIF_NFMWORDS        = (SPIF_NWORDS > 16) ? 16 : SPIF_NWORDS;
localparam SPIF_NFMBYTES        = (SPIF_NBYTES > 64) ? 64 : SPIF_NBYTES;
// www.ToDo Move the following to global CXL library
localparam CXL_RESERVED          = 16'b0000_0000_0000_0000; // Reserved bytes at the end of CXL.io flits
localparam CXL_PID_IO            = 16'b1111_1111_1111_1111; // CXL.io
localparam CXL_PID_CACHE_MEM     = 16'b0101_0101_0101_0101; // CXL.cache/CXL.mem
localparam CXL_PID_NULL          = 16'b1001_1001_1001_1001; // NULL flit (generated by the Physical Layer)
localparam CXL_PID_ALMP          = 16'b1100_1100_1100_1100; // CXL ARB/MUX Link Management Packets (ALMPs)

// XPLH Shift and Merge module interface signals
logic                       shifted_halt        ; // When set to 0 indicates that the merge/shift has accepted the flit.  When set to 1 halts the Mux/Arb from transmission.
logic                       shifted_pkt_pending ; // When set to 1 indicates that the merge/shift has pending CXL.io packets
logic [SPIF_NFMBYTES*8-1:0] shifted_data        ;
logic [SPIF_NFMWORDS-1:0]   shifted_stp         ;
logic [SPIF_NFMWORDS-1:0]   shifted_sdp         ;
logic [SPIF_NFMWORDS-1:0]   shifted_eot         ;
logic [SPIF_NFMWORDS-1:0]   shifted_pad         ;
logic [SPIF_NFMWORDS-1:0]   shifted_next_stp    ;
logic [SPIF_NFMWORDS-1:0]   shifted_next_sdp    ;
logic [SPIF_NFMWORDS-1:0]   shifted_next_eot    ;
logic [SPIF_NFMWORDS-1:0]   shifted_next_pad    ;
logic [SPIF_NFMWORDS-1:0]   shifted_pid         ;
logic                       xplh_null_active_nxt; // NULL Flit is in progress - next state
logic                       xplh_null_active_r  ; // NULL Flit is in progress - register
logic                       xplh_pyld_enable_nxt;
logic                       xplh_pyld_enable_r  ;
logic                       vlsm_lp_sof         ; // Start of flit
logic                       vlsm_lp_eof         ; // End of flit
logic                       vlsm_lp_eop         ; // End of payload
logic [SPIF_NBYTES*8-1:0]   vlsm_lp_data_s      ;
logic [SPIF_NBYTES-1:0]     vlsm_lp_data_chk_s  ;

// ----------------------------------------------------------------------------
// Output Assignment
// ----------------------------------------------------------------------------
assign vlsm_pl_trdy  = spif_enable && ( pcie_flit_mode ? (!b_xplh_xmlh_mp.halt_in && xplh_pyld_enable_r) : (!shifted_halt && !xplh_null_active_r) );
assign vlsm_pl_skip_trdy = spif_enable && b_xplh_xmlh_mp.skip_pending;

// ----------------------------------------------------------------------------
// DW Counter: counts number of DWs in the flit
// ----------------------------------------------------------------------------
logic dw_cnt_ena_s;
logic dw_cnt_idle_s;
logic dw_cnt_done_s;
logic dw_cnt_last_s;

// Flit Markers are tied to 0 in PCIe non-Flit mode as they are only applicable in the PCIe/CXL flit mode of operation
assign vlsm_lp_sof = pcie_nfm_mode ? 1'b0 : dw_cnt_idle_s;
assign vlsm_lp_eof = pcie_nfm_mode ? 1'b0 : dw_cnt_done_s;
assign vlsm_lp_eop = pcie_nfm_mode ? 1'b0 : dw_cnt_last_s;

assign dw_cnt_ena_s = spif_enable && ( pcie_flit_mode ? (vlsm_lp_irdy && vlsm_pl_trdy) : !shifted_halt );

spif_flit_dw_cnt
 u_flit_dw_cnt (
    .core_clk           ( core_clk                          ),
    .core_rst_n         ( core_rst_n                        ),
    .pcie_flit_mode     ( pcie_flit_mode                    ),
    .rst_flit_alignment ( b_xplh_xmlh_mp.rst_flit_alignment ),
    .dw_cnt_ena         ( dw_cnt_ena_s                      ),
    .dw_cnt_idle        ( dw_cnt_idle_s                     ),
    .dw_cnt_busy        ( /* Unconnected */                 ),
    .dw_cnt_last        ( dw_cnt_last_s                     ),
    .dw_cnt_done        ( dw_cnt_done_s                     )
);
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// FlitUsage/FlitType insertion into of the flit
// ----------------------------------------------------------------------------
logic [1:0] flit_type_s; // 2-bit FlitType in DLP0 byte

always_comb begin
    case (vlsm_lp_stream)
        SID_CXL_CM: flit_type_s = 2'b10;
        SID_ALMP  : flit_type_s = 2'b11;
        default   : flit_type_s = vlsm_lp_data[7:6];
    endcase
end

always_comb begin
    vlsm_lp_data_s = vlsm_lp_data;
    vlsm_lp_data_chk_s = vlsm_lp_data_chk;

    if (vlsm_lp_sof && cxl_mode_enable) begin
        vlsm_lp_data_s[7:6] = flit_type_s;
        vlsm_lp_data_chk_s[0] = vlsm_lp_data_chk[0] ^ (^(flit_type_s ^ vlsm_lp_data[7:6]));
    end
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Mux between Native PCIe and SPIF Interface
// ----------------------------------------------------------------------------
logic  spif_flit_mode_sel;
assign spif_flit_mode_sel = xplh_pyld_enable_r && vlsm_lp_irdy;

always_comb begin
    // Signals connected directly from XMLH to XDLH via ARB/MUX interface
    b_xdlh_xplh_sp.skip_pending       = b_xplh_xmlh_mp.skip_pending;
    b_xdlh_xplh_sp.cmd_is_data        = b_xplh_xmlh_mp.cmd_is_data;
    b_xdlh_xplh_sp.rst_flit_alignment = b_xplh_xmlh_mp.rst_flit_alignment;

    if (spif_enable) begin
        b_xdlh_xplh_sp.halt_in      = 1'b1; // Halt XDLH-XPLH Interface in CXL Mode and use LPIF Interface
        b_xplh_xmlh_mp.data_valid   = spif_flit_mode_sel ? 1'b1                   : 1'b0;
        b_xplh_xmlh_mp.data_out     = spif_flit_mode_sel ? vlsm_lp_data_s         : {{((SPIF_NBYTES - SPIF_NFMBYTES)*8){1'b0}}, shifted_data};
        b_xplh_xmlh_mp.stp          = {{(SPIF_NWORDS - SPIF_NFMWORDS){1'b0}}, shifted_stp};
        b_xplh_xmlh_mp.sdp          = {{(SPIF_NWORDS - SPIF_NFMWORDS){1'b0}}, shifted_sdp};
        b_xplh_xmlh_mp.eot          = {{(SPIF_NWORDS - SPIF_NFMWORDS){1'b0}}, shifted_eot};
        b_xplh_xmlh_mp.pid          = {{(SPIF_NWORDS - SPIF_NFMWORDS){1'b0}}, shifted_pid};
        b_xplh_xmlh_mp.pad          = {{(SPIF_NWORDS - SPIF_NFMWORDS){1'b0}}, shifted_pad};
        b_xplh_xmlh_mp.next_stp     = {{(SPIF_NWORDS - SPIF_NFMWORDS){1'b0}}, shifted_next_stp};
        b_xplh_xmlh_mp.next_sdp     = {{(SPIF_NWORDS - SPIF_NFMWORDS){1'b0}}, shifted_next_sdp};
        b_xplh_xmlh_mp.next_eot     = {{(SPIF_NWORDS - SPIF_NFMWORDS){1'b0}}, shifted_next_eot};
        b_xplh_xmlh_mp.pkt_pending  = shifted_pkt_pending;
        b_xplh_xmlh_mp.sof          = spif_flit_mode_sel ? vlsm_lp_sof                       : 1'b0;
        b_xplh_xmlh_mp.eof          = spif_flit_mode_sel ? {vlsm_lp_eof, vlsm_lp_eop}        : 2'd0;
        b_xplh_xmlh_mp.enf          = spif_flit_mode_sel ? (vlsm_lp_nop_flit && (vlsm_lp_eop || vlsm_lp_eof)) : 1'b0;
        b_xplh_xmlh_mp.flit_tlp_dv  = 1'b0;         // Tied off in CXL Mode
        b_xplh_xmlh_mp.flit_prot    = spif_flit_mode_sel ? vlsm_lp_data_chk_s  : {SPIF_NBYTES{1'b0}};
        b_xplh_xmlh_mp.ras_dp_err_inband_kbd = spif_flit_mode_sel ? vlsm_lp_rasdp_error : 1'b0;
        b_xplh_xmlh_mp.flit_type_s  = 2'b00;        // Tied off due to an alternative way in CXL and PCIe SPIF modes
    end
    else begin
        b_xdlh_xplh_sp.halt_in      = b_xplh_xmlh_mp.halt_in;
        b_xplh_xmlh_mp.data_valid   = b_xdlh_xplh_sp.data_valid;
        b_xplh_xmlh_mp.data_out     = b_xdlh_xplh_sp.data_out;
        b_xplh_xmlh_mp.stp          = b_xdlh_xplh_sp.stp;
        b_xplh_xmlh_mp.sdp          = b_xdlh_xplh_sp.sdp;
        b_xplh_xmlh_mp.eot          = b_xdlh_xplh_sp.eot;
        b_xplh_xmlh_mp.pid          = {SPIF_NWORDS{1'b0}}; // Unused in PCIe Mode
        b_xplh_xmlh_mp.pad          = b_xdlh_xplh_sp.pad;
        b_xplh_xmlh_mp.next_stp     = b_xdlh_xplh_sp.next_stp;
        b_xplh_xmlh_mp.next_eot     = b_xdlh_xplh_sp.next_eot;
        b_xplh_xmlh_mp.next_sdp     = b_xdlh_xplh_sp.next_sdp;
        b_xplh_xmlh_mp.pkt_pending  = b_xdlh_xplh_sp.pkt_pending;
        b_xplh_xmlh_mp.sof          = b_xdlh_xplh_sp.sof;
        b_xplh_xmlh_mp.eof          = b_xdlh_xplh_sp.eof;
        b_xplh_xmlh_mp.enf          = b_xdlh_xplh_sp.enf;
        b_xplh_xmlh_mp.flit_tlp_dv  = b_xdlh_xplh_sp.flit_tlp_dv;
        b_xplh_xmlh_mp.flit_prot    = b_xdlh_xplh_sp.flit_prot;
        b_xplh_xmlh_mp.ras_dp_err_inband_kbd = b_xdlh_xplh_sp.ras_dp_err_inband_kbd;
        b_xplh_xmlh_mp.flit_type_s  = b_xdlh_xplh_sp.flit_type_s;
    end
end
// ----------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// CXL Merge and Shift module instantiation
// -------------------------------------------------------------------------------------
logic [SPIF_NFMWORDS:0]         cxl_arb_stp;
logic [SPIF_NFMWORDS:0]         cxl_arb_sdp;
logic [SPIF_NFMWORDS:0]         cxl_arb_eot;
logic [(SPIF_NFMBYTES+4)*8-1:0] cxl_arb_data;
logic [15:0]                    cxl_arb_pid;
logic [SPIF_NCRC*8-1:0]         cxl_arb_crc;
logic                           cxl_arb_pkt_pending;
logic                           cxl_arb_halt;
logic                           cxl_arb_rst_flit_alignment;
logic                           shifted_pkt_pending_s;
logic                           shifted_halt_s;

assign shifted_pkt_pending = pcie_nfm_mode ? (!xplh_stall_ack || shifted_pkt_pending_s     ) : shifted_pkt_pending_s;
assign shifted_halt        = pcie_nfm_mode ? (shifted_pkt_pending_s ? shifted_halt_s : 1'b0) : shifted_halt_s;

// Extend pointers from SPIF_NWORDS to SPIF_NWORDS+1. After PID insertion the datapath is shifted by a word (2 Bytes).
// Start pointers are aligned with the DW containing the start of the packet in thw MSW
// End pointers are aligned with the DW containg the end of the packet in the LSW
assign cxl_arb_stp         = xplh_null_active_r ? '0 : {1'b0, vlsm_lp_tlp_start[SPIF_NFMWORDS-1:0]};
assign cxl_arb_sdp         = xplh_null_active_r ? '0 : {1'b0, vlsm_lp_dlp_start[SPIF_NFMWORDS-1:0]};
assign cxl_arb_eot         = xplh_null_active_r ? '0 : (vlsm_lp_sof ? {(vlsm_lp_tlp_end[SPIF_NFMWORDS-1:0] | vlsm_lp_dlp_end[SPIF_NFMWORDS-1:0]), 1'b0} : 
                                                                      {1'b0, (vlsm_lp_tlp_end[SPIF_NFMWORDS-1:0] | vlsm_lp_dlp_end[SPIF_NFMWORDS-1:0])});

// In PCIe Flit mode disable Shift&Merge module by keeping cxl_arb_halt and cxl_arb_rst_flit_alignment always asserted
assign cxl_arb_halt               = pcie_flit_mode ? 1'b1 : ((cxl_mode_enable || pcie_nfm_mode) ? b_xplh_xmlh_mp.halt_in            : 1'b1);
assign cxl_arb_rst_flit_alignment = pcie_flit_mode ? 1'b1 : ((cxl_mode_enable || pcie_nfm_mode) ? b_xplh_xmlh_mp.rst_flit_alignment : 1'b0);

// Imitate packet pending on XMLH interface based on LPIF stall_req/stall_ack handshake
assign cxl_arb_pkt_pending = vlsm_lp_irdy;

assign cxl_arb_crc         = vlsm_lp_crc_valid ? vlsm_lp_crc_data : CXL_RESERVED;
assign cxl_arb_data        = xplh_null_active_r ? '0 : (vlsm_lp_sof ? {cxl_arb_crc, vlsm_lp_data[SPIF_NFMBYTES*8-1:0], cxl_arb_pid} : {CXL_RESERVED, cxl_arb_crc, vlsm_lp_data[SPIF_NFMBYTES*8-1:0]});

always_comb begin
    case (vlsm_lp_stream)
        SID_CXL_IO: cxl_arb_pid = CXL_PID_IO;
        SID_CXL_CM: cxl_arb_pid = CXL_PID_CACHE_MEM;
        SID_ALMP  : cxl_arb_pid = CXL_PID_ALMP;
        default   : cxl_arb_pid = !cxl_mode_enable ? CXL_RESERVED : CXL_PID_NULL;
    endcase
end

always_comb begin
    if (cxl_arb_rst_flit_alignment || (vlsm_lp_eof && !shifted_halt))
       xplh_null_active_nxt = 1'b0;
    else if (vlsm_lp_sof && !vlsm_lp_eof && !shifted_halt && (cxl_arb_pid == CXL_PID_NULL))
       xplh_null_active_nxt = 1'b1;
    else if (vlsm_lp_eof && !shifted_halt)
       xplh_null_active_nxt = 1'b0;
    else
       xplh_null_active_nxt = xplh_null_active_r;
end

always @(posedge core_clk or negedge core_rst_n) begin
    if ( !core_rst_n )
        xplh_null_active_r <= #TP 1'b0;
    else
        xplh_null_active_r <= #TP xplh_null_active_nxt;
end

// In CXL mode, latch the first risign edge of smlh_in_l0 to enable pl_trdy only after link is trained to the target speed
always_comb begin
    if (pcie_flit_mode)
        xplh_pyld_enable_nxt = xplh_pyld_enable_r || (cxl_mode_enable ? xplh_payload_enable : 1'b1);
    else
        xplh_pyld_enable_nxt = xplh_pyld_enable_r;
end

always @(posedge core_clk or negedge core_rst_n) begin
    if ( !core_rst_n )
        xplh_pyld_enable_r <= #TP 1'b0;
    else
        xplh_pyld_enable_r <= #TP xplh_pyld_enable_nxt;
end

xplh_cxl_merge_shift

#(INST) u_merge_shift(
    // -- inputs --
    .core_clk                          (core_clk),
    .core_rst_n                        (core_rst_n),
    .cxl_mode_enable                   (cxl_mode_enable),
    .cxl_arb_pkt_pending               (cxl_arb_pkt_pending),
    .cxl_arb_data                      (cxl_arb_data),
    .cxl_arb_pad                       (shifted_next_pad),
    .cxl_arb_stp                       (cxl_arb_stp),
    .cxl_arb_sdp                       (cxl_arb_sdp),
    .cxl_arb_eot                       (cxl_arb_eot),
    .xmlh_xdlh_halt                    (cxl_arb_halt),
    .xmlh_xdlh_rst_flit_alignment      (cxl_arb_rst_flit_alignment),
    // -- outputs --
    .shifted_halt                      (shifted_halt_s),
    .shifted_pkt_pending               (shifted_pkt_pending_s),
    .shifted_data                      (shifted_data),
    .shifted_pid                       (shifted_pid),
    .shifted_pad                       (shifted_pad),
    .shifted_stp                       (shifted_stp),
    .shifted_sdp                       (shifted_sdp),
    .shifted_eot                       (shifted_eot),
    .shifted_next_stp                  (shifted_next_stp),
    .shifted_next_sdp                  (shifted_next_sdp),
    .shifted_next_eot                  (shifted_next_eot)
);
// -------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------
// PAD Signal Generation
//----------------------------------------------------------------------------------------
localparam NB      = (P_NW > 16) ? `CX_NB_GEN5 : `CX_NB;   // Number of symbols (bytes) per clock cycle. 
localparam NL      = `CX_NL;                               // Max number of lanes supported
 
// Pad to the end of each symbol when an end/edb is seen
always_comb begin : PROC_PAD
    integer i;
    shifted_next_pad = {P_NFM_NW{1'b0}};
    // Iterate over each dword, start from 1 as pad[0] can never be set.
    // Force Pad to 0 at symbol boundaries. An x16 core running at
    // x8(smlh_link_mode[4] == 0) is treated as having double the symbols
    // Only need to consider this case for x16 as x8 cores running at x4
    // will never pad.
    // 4.2.2 Framing Rules:
    // "For xN Links where N is 8 or more, if an END or EDB Symbol is
    // placed in a Lane K, where K does not equal N-1, and is not
    // followed by a STP or SDP Symbol in Lane K+1 (i.e., there is no
    // TLP or DLLP immediately following), then PAD Symbols must be
    // placed in Lanes K+1 to Lane N-1"
    // Set pad if eot or pad bit below is set and we did not just cross
    // a symbol boundary
    // Add condition that no new TLP starts
    // Note that the code below may generate pad also when the current 
    // link mode is x4, x2 or x1 whereas it is requested only for x8 or 
    // greater. This is considered by xmlh_byte_xmt which ignores the 
    // pad signal for link modes lower than x8. 
    // Todo: Consider to move this logic to xmlh_byte_xmt.
    for(i = 1; i < P_NFM_NW; i = i + 1) begin
        if(!(i % (P_NFM_NW/NB) == 0
            )
          )
            shifted_next_pad[i] = !(shifted_next_stp[i] || shifted_next_sdp[i]) && shifted_next_eot[i-1] || shifted_next_pad[i-1];
    end
end
//----------------------------------------------------------------------------------------

endmodule
