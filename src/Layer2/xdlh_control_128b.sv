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
// ---    $DateTime: 2024/01/22 13:12:34 $
// ---    $Revision: #16 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_control_128b.sv#16 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit Data Link Layer Handler Controller
// -----------------------------------------------------------------------------
// --- This module handles DLP layer dllp and tlp mux/control logic. And it includes the following functions:
// --- 1. Arbitrates for transmitting DLLP and TLP.
// --- 2. Mux the tlp and dllp data and output to xmlh
// --- This module handles 128b, 256b and 512b datapath widths.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

 
 module xdlh_control_128b 
 import cx_pl_pkg::P_NW;
 import cx_pl_pkg::P_NFM_NW;
 (
    // Inputs
    core_clk,
    core_rst_n,
    rdlh_link_up,
    current_data_rate,
    smlh_link_mode,

    tlp_sot,
    tlp_eot,
    tlp_data,
    tlp_dwen,
    dllp_sdp,
    tlp_dllp_dv,
    rbuf_replaying,

    tlpgen_pkt_pending,
    smlh_in_l0_l0s_l1,
    xmlh_cmd_is_data,
    xmlh_xdlh_halt,
// Outputs
    xdlh_control_stp,
    xdlh_control_sdp,
    xdlh_control_eot,
    xdlh_control_next_eot,
    xdlh_control_next_stp,
    xdlh_control_next_sdp,
    xdlh_control_dv,
    xdlh_control_data,
    xdlh_control_pad,
    xdlh_rbuf_replaying,
    xdctrl_tlp_halt,
    xdctrl_dllp_halt1,
 //   xdctrl_dllp_halt,
    xdlh_control_pkt_pending,
    xdctrl_nodllp_pending,
    xdlh_xmt_pme_ack,
    xdlh_dllp_sent
    ,
    xdlh_dllp_end
);
parameter   INST    = 0;        // The uniquifying parameter for each port logic instance.
parameter   NW          = (P_NW>16) ? P_NFM_NW : P_NW;   // Number of 32-bit dwords handled by the datapath each clock. This module supports 4, 8 and 16 
parameter   DW      = (32*NW);  // Width of datapath in bits.
parameter   TP      = `TP;      // Clock to Q delay (simulator insurance)
parameter   NB      = (P_NW>16) ? `CX_NB_GEN5 : `CX_NB;   // Number of symbols (bytes) per clock cycle.
parameter   NL      = `CX_NL;   // Max number of lanes supported

// ==========================================================================
// Parameters
// ==========================================================================

parameter S_IDLE            = 3'b0;
parameter S_DLLP_LSB        = 3'b001;
parameter S_DLLP_MSB        = 3'b010;
parameter S_TLP             = 3'b100;
parameter S_TLP_END         = 3'b101;

// ==========================================================================
// inputs
// ==========================================================================
input                   core_clk;
input                   core_rst_n;
input   [2:0]           current_data_rate;
input   [DW-1:0]        tlp_data;
input   [NW-1:0]        tlp_dwen;
input   [NW-1:0]        tlp_sot;
input   [NW-1:0]        tlp_eot;
input   [NW-1:0]        dllp_sdp;
input                   rbuf_replaying;
input                   rdlh_link_up;
input   [5:0]           smlh_link_mode;
input                   tlp_dllp_dv;
input                   tlpgen_pkt_pending;
input                   smlh_in_l0_l0s_l1; // the states where we want to fill the pipeline if there is a packet pending
input                   xmlh_cmd_is_data;  // xmtbyte state machine is waiting for packet start or packet end
input                   xmlh_xdlh_halt;

// ==========================================================================
// outputs
// ==========================================================================
output                  xdlh_control_dv;
output  [DW-1:0]        xdlh_control_data;
output  [NW-1:0]        xdlh_control_pad;
output  [NW-1:0]        xdlh_control_sdp;                      // Start DLP packet
output  [NW-1:0]        xdlh_control_stp;                      // Start TLP packet
output  [NW-1:0]        xdlh_control_eot;                      // End DLP or TLP packet
output  [NW-1:0]        xdlh_control_next_eot;                 // End DLP or TLP packet
output  [NW-1:0]        xdlh_control_next_stp;                 // Strat  TLP on next packet
output  [NW-1:0]        xdlh_control_next_sdp;                 // Start DLLP on next packet
output                  xdlh_rbuf_replaying;
// output                  xdctrl_dllp_halt;
output                  xdlh_xmt_pme_ack;
output  [NW-1:0]        xdlh_dllp_sent;
output  [NW-1:0]        xdlh_dllp_end;
output                  xdctrl_nodllp_pending;
output                  xdlh_control_pkt_pending;
output                  xdctrl_tlp_halt;
output                  xdctrl_dllp_halt1;

// ==========================================================================
// IO declaration
// ==========================================================================
//reg    [(TX_NDLLP*64) -1:0]clkd_dllp_pkt;
reg     [DW-1:0]        xdlh_control_data;
reg     [NW-1:0]        xdlh_control_pad;
reg     [NW-1:0]        xdlh_control_sdp;                      // Start DLP packet
reg     [NW-1:0]        xdlh_control_stp;                      // Start TLP packet
reg     [NW-1:0]        xdlh_control_eot;                      // End DLP or TLP packet
reg                     xdlh_rbuf_replaying;
// wire                    xdctrl_dllp_halt;
wire                    xdctrl_tlp_halt;
reg                     xdlh_xmt_pme_ack;
wire    [NW-1:0]        xdlh_dllp_sent;
wire    [NW-1:0]        xdlh_dllp_end;
wire                    xdlh_control_pkt_pending;

// ==========================================================================
// internal signal declaration
// ==========================================================================
wire    [DW-1:0]        int_xmlh_data;
wire    [NW-1:0]        int_xmlh_dwen;
wire    [NW-1:0]        int_xmlh_pad;
wire    [NW-1:0]        int_xmlh_sdp;                      // Start DLP packet
wire    [NW-1:0]        int_xmlh_stp;                      // Start TLP packet
wire    [NW-1:0]        int_xmlh_eot;                      // End DLP or TLP packet
wire    [NW-1:0]        xdlh_control_next_eot;                // End DLP or TLP packet
wire    [NW-1:0]        xdlh_control_next_stp;                // Start  TLP next packet
wire    [NW-1:0]        xdlh_control_next_sdp;                // Start DLP next packet
wire xdctrl_dllp_halt1;

wire   [NW-1:0]         valid_tlp_sot;
reg                     latchd_tlp_packd;
reg    [DW-1:0]         int_tlp_data;
reg                     xdlh_control_dv;
wire                    int_xmlh_dv;
reg                     xdctrl_nodllp_pending;
reg  [1:0]              xdctrl_pipeline_empty_r;  // XDLH TX pipeline empty flag
wire                    tlp_is_pme_to_ack;
wire                    xmlh_ready_for_tlp;
reg  [NW-1:0] tmp_eot;
wire [NW:0] int_tlp_ext;
reg tlp_is_pme_ack;
reg check_pme_dw0;
reg check_pme_dw1;
reg check_hdr0_dw0;

reg check_pme_dw0_r;
reg check_pme_dw1_r;
reg check_hdr0_dw0_r;
reg [NW-1:0] int_pad;
wire        int_valid_eot;
wire        int_pme_to_ack_flag;
reg         int_pme_to_ack_flag_r;

//-----------------------------------------------------------------------------------
//


assign      valid_tlp_sot        = tlp_sot & {NW{rdlh_link_up}};

always @(*) begin : PROC_TLP_DATA
    integer j;
    for(j = 0; j < NW; j = j + 1)begin
       int_tlp_data[32*j +: 32] = {32{tlp_dwen[j]}} & tlp_data[32*j +: 32];
    end
end


// output drive mux
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        xdlh_control_stp       <= #TP 0;
        xdlh_control_sdp       <= #TP 0;
        xdlh_control_data      <= #TP 0;
        xdlh_control_pad       <= #TP 0;
        xdlh_control_eot       <= #TP 0;
        xdlh_control_dv        <= #TP 0;
        xdlh_rbuf_replaying    <= #TP 0;
    // load pipeline when empty or no halt from xmlh
    end else if (!xdlh_control_dv | !xmlh_xdlh_halt) begin
        xdlh_control_data      <= #TP int_xmlh_data;
        xdlh_control_pad       <= #TP int_xmlh_pad;
        xdlh_control_eot       <= #TP int_xmlh_eot;
        xdlh_control_stp       <= #TP int_xmlh_stp;
        xdlh_control_sdp       <= #TP int_xmlh_sdp;
        xdlh_control_dv        <= #TP int_xmlh_dv;
        xdlh_rbuf_replaying    <= #TP rbuf_replaying;
    end

assign xdlh_control_next_eot = (!xdlh_control_dv | !xmlh_xdlh_halt) ? int_xmlh_eot : xdlh_control_eot;
assign xdlh_control_next_stp = (!xdlh_control_dv | !xmlh_xdlh_halt) ? int_xmlh_stp : xdlh_control_stp;
assign xdlh_control_next_sdp = (!xdlh_control_dv | !xmlh_xdlh_halt) ? int_xmlh_sdp : xdlh_control_sdp;

// ready for storing a packet into the pipeline knowing that the encoding is not going to change
assign xmlh_ready_for_tlp = smlh_in_l0_l0s_l1 || xmlh_cmd_is_data;

//assign xdctrl_tlp_halt      = (xmlh_xdlh_halt && xdlh_control_dv) || ( (|tlp_sot) || (|dllp_sdp)) && !rdlh_link_up ;
assign xdctrl_tlp_halt      = xdctrl_dllp_halt1 || (|tlp_sot) && !rdlh_link_up;
// If data valid then propagate xmlh_xdlh_halt to xdctrl_dllp_halt1, otherwise
// if transmit datapath is enabled then de-assert xdctrl_dllp_halt1 to fill pipelines, and
// if transmit datapath is not enabled then do not allow pipelines to fill once they are drained
assign xdctrl_dllp_halt1    = xdlh_control_dv ? xmlh_xdlh_halt : (xmlh_ready_for_tlp ? 1'b0 : &xdctrl_pipeline_empty_r);

// Transmit pipeline empty signal. Two stage register to brake combinational loop between XDLH Control and XDLH TLP Gen
// when using xdlh_control_pkt_pending instead.
always @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n)
        xdctrl_pipeline_empty_r <= #TP '1;
    else
        xdctrl_pipeline_empty_r <= #TP {xdctrl_pipeline_empty_r[0], !int_xmlh_dv && !tlpgen_pkt_pending};
end

// Pad to the end of each symbol when an end/edb is seen

always_comb begin : PROC_PAD
    integer i;
    int_pad = {NW{1'b0}};
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
    for(i = 1; i < NW; i = i + 1) begin
        if(!(i % (NW/NB) == 0
            )
          )
            int_pad[i] = !(tlp_sot[i] | dllp_sdp[i]) & tlp_eot[i-1] || int_pad[i-1];
    end
end

assign int_xmlh_pad = int_pad;
assign int_xmlh_data = int_tlp_data;

assign int_xmlh_eot = tlp_eot;
assign int_xmlh_sdp = dllp_sdp ;

assign   int_xmlh_dv        = tlp_dllp_dv;

assign   int_xmlh_stp       = valid_tlp_sot ;

// An EOT was detected while Layer2 was not halted
assign int_valid_eot = ((|xdlh_control_eot) && !xmlh_xdlh_halt);

// Set this flag to 1 when the PME_To_Ack message type is detected
// Cleat this flag when the EOT corresponding to the PME_To_Ack has been detected
assign int_pme_to_ack_flag = (tlp_is_pme_ack ? 1'b1 : 
                             (xdlh_xmt_pme_ack ? 1'b0 : int_pme_to_ack_flag_r));

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n)
    begin
        xdlh_xmt_pme_ack      <= #TP 1'b0;
        int_pme_to_ack_flag_r <= #TP 1'b0;
    end
    else
    begin
        xdlh_xmt_pme_ack      <= #TP (int_pme_to_ack_flag && int_valid_eot);
        int_pme_to_ack_flag_r <= #TP int_pme_to_ack_flag;
    end
end


// ----------------------------------------------------------------------
// Detect PME_TO_ACK - Assuming that this message TLP will be without prefix - need to confirm.


always @(*) begin : PROC_PME_ACK
   integer i;
   tlp_is_pme_ack = 1'b0;
   check_pme_dw0 = 1'b0;
   check_pme_dw1 = 1'b0;
   check_hdr0_dw0 = 1'b0;

       if (   (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)  && check_pme_dw0_r && (xdlh_control_data[31:24] == `PME_TO_ACK)  ||
            !((current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)) && check_pme_dw0_r && (xdlh_control_data[23:16] == `PME_TO_ACK) )
        tlp_is_pme_ack = 1;
       else
       if (   (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) && check_hdr0_dw0_r && (xdlh_control_data[7:3] == {1'b0, `MSG_4}) && (xdlh_control_data[63:56] == `PME_TO_ACK) )
                tlp_is_pme_ack = 1;
       else

       if ( !((current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)) && check_pme_dw1_r && (xdlh_control_data[55:48] == `PME_TO_ACK) )
                tlp_is_pme_ack = 1;

       else
       begin
 //      integer i;
       for (i=0; i<NW; i=i+1)
        begin
       // LMD: Range index out of bound
       // LJ: The range of values of the signals xdlh_control_data[(NW*32)-1:0]
       // leda E267 off
    if (xdlh_control_stp[i] & (i< NW - 2))
        begin
            if (  (( (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) &&
            (xdlh_control_data[32*(i+1)+3 +:5] == {1'b0, `MSG_4}) &&  (xdlh_control_data[32*(i+2)+24+:8] == `PME_TO_ACK) ) ) ||
            ((    !((current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)) &&
            (xdlh_control_data[(32*i)+27+:5] == {1'b0, `MSG_4}) &&  (xdlh_control_data[32*(i+2)+16+:8] == `PME_TO_ACK))) )

                    tlp_is_pme_ack = 1;
        end
    else
        if (xdlh_control_stp[i] & (i == NW - 2))
        begin
            if ( ( (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) && (xdlh_control_data[32*(i+1)+3 +:5] == {1'b0, `MSG_4}))  ||
            (   !((current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)) && (xdlh_control_data[(32*i)+27 +:5] == {1'b0, `MSG_4})) )

                    check_pme_dw0 = 1'b1;
            end
    else
        if (xdlh_control_stp[i] & (i == NW - 1))
        begin
        if (   (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) )
                      check_hdr0_dw0 = 1'b1;
        else
        if ( !((current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE)) &&  (xdlh_control_data[(32*i)+27 +:5] == {1'b0, `MSG_4}) )
            check_pme_dw1 = 1'b1;
            end
       end
       // leda E267 on
       end
end



always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
       begin
        check_pme_dw0_r <=  #TP  1'b0;
        check_pme_dw1_r <=  #TP  1'b0;
        check_hdr0_dw0_r <= #TP  1'b0;
       end
       else
         begin
    if (|xdlh_control_stp & check_pme_dw0)
        check_pme_dw0_r  <=  #TP  1'b1;
    else
        if ((|xdlh_control_eot) && !xmlh_xdlh_halt)
            check_pme_dw0_r  <=  #TP  1'b0;

    if (|xdlh_control_stp & check_pme_dw1)
        check_pme_dw1_r  <=  #TP  1'b1;
    else
        if ((|xdlh_control_eot) && !xmlh_xdlh_halt)
            check_pme_dw1_r  <=  #TP  1'b0;

    if (|xdlh_control_stp & check_hdr0_dw0)
        check_hdr0_dw0_r  <=  #TP  1'b1;
    else
        if ((|xdlh_control_eot) && !xmlh_xdlh_halt)
            check_hdr0_dw0_r  <=  #TP  1'b0;
    end


//assign   tlp_is_pme_to_ack  = (current_data_rate == `GEN3_RATE) ? ((xdlh_control_data[38:35] == `MSG_4) && (xdlh_control_data[95:88] == `PME_TO_ACK))
//                                                               : ((xdlh_control_data[30:27] == `MSG_4) && (xdlh_control_data[87:80] == `PME_TO_ACK));






// for pm module output
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        xdctrl_nodllp_pending        <= #TP 1;
    else
        xdctrl_nodllp_pending        <= #TP !int_xmlh_dv & !xdlh_control_dv;


assign  xdlh_control_pkt_pending =  (int_xmlh_dv &&  !xdctrl_tlp_halt) ||    // TLP/DLLP about to be registered
                                 xdlh_control_dv                       ||    // TLP/DLLP already registered in xdlh_control
                                 tlpgen_pkt_pending;                     // TLP registered in TLP Generator

xdlh_detect_dllp

  // Parameters
  #(
    .INST       (INST),
    .NW         (NW),
    .DW         (DW),
    .DLLP_WD    (8),
    .MATCH_TYPE (1'b0)
  ) u_det_any_dllp (
    // Inputs
    .clk                  (core_clk),
    .rst_n                (core_rst_n),
    .dllp_type            (8'hFF),
    .sdp                  (xdlh_control_sdp),
    .data                 (xdlh_control_data),
    .eot                  (xdlh_control_eot),
    .current_data_rate    (current_data_rate),
    .halt                 (xmlh_xdlh_halt),
    // Outputs
    .dllp_match           (),
    .dllp_sent            (xdlh_dllp_sent)
    ,.dllp_end            (xdlh_dllp_end)
);


`ifndef SYNTHESIS
`endif // SYNTHESIS 
endmodule

