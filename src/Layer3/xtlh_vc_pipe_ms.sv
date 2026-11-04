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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_vc_pipe_ms.sv#5 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_vc_pipe_ms
import xtlh_ms_pkg::xtlh_vc_pkt_struct;
import cx_pl_pkg::P_NW;
#(
    parameter N                       = 2,
    parameter PIPE                    = 1,
    parameter CAN_STALL               = 1
)
(
    input  logic                            clk,
    input  logic                            rst_n,
    
    input  xtlh_vc_pkt_struct       [N-1:0] in_pkt,
    output logic                    [N-1:0] out_halt,
    
    output xtlh_vc_pkt_struct       [N-1:0] out_pkt,
    input  logic                    [N-1:0] in_halt
);

localparam TOTAL_WIDTH = $bits(in_pkt[0]);

logic      [N-1:0][TOTAL_WIDTH-1:0]  in_pkt_vector;
logic      [N-1:0][TOTAL_WIDTH-1:0]  out_pkt_vector;
logic      [$clog2(TOTAL_WIDTH)-1:0] IN_OFFSET;
logic      [$clog2(TOTAL_WIDTH)-1:0] OUT_OFFSET;


always_comb begin
    for (int i = 0; i < N; i++) begin : g_ifs
        IN_OFFSET=0;
        // fill the vector to ras_dp_pipe with fields to be protected
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].data)]            = in_pkt[i].data;               IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].data);
        // fill the remaining part of vector to ras_dp_pipe with fields not to be protected
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].sot)]             = in_pkt[i].sot;                IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].sot);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].soh)]             = in_pkt[i].soh;                IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].soh);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].dv)]              = in_pkt[i].dv;                 IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].dv);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].eot)]             = in_pkt[i].eot;                IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].eot);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].is_from_dma)]     = in_pkt[i].is_from_dma;        IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].is_from_dma);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].is_from_msg_gen)] = in_pkt[i].is_from_msg_gen;    IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].is_from_msg_gen);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].intf)]            = in_pkt[i].intf;               IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].intf);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].badeot)]          = in_pkt[i].badeot;             IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].badeot);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].dwen)]            = in_pkt[i].dwen;               IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].dwen);
          in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].ep)]              = in_pkt[i].ep;               IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].ep);
          in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].ptm)]             = in_pkt[i].ptm;              IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].ptm);
          in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].pme_to_ack)]      = in_pkt[i].pme_to_ack;       IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].pme_to_ack);
          in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].tlp_len)]         = in_pkt[i].tlp_len;          IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].tlp_len);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].ras_dp_err_inband_kbd)]  = in_pkt[i].ras_dp_err_inband_kbd;  IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].ras_dp_err_inband_kbd);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt[0].tlp_prot)]               = in_pkt[i].tlp_prot;               IN_OFFSET = IN_OFFSET + $bits(in_pkt[0].tlp_prot);
    end
end

for (genvar i = 0; i < N; i++)begin : g_pipe
    delay_n_w_enable
     #(
        .N(PIPE),
        .WD(TOTAL_WIDTH),
        .RESETVAL(0)
    ) u_delay_n_w_enable (
        .clk     (clk               ),
        .rst_n   (rst_n             ),
        .clear   (1'b0              ),
        .en      (1'b1              ),
        .din     (in_pkt_vector[i]  ),
        .dout    (out_pkt_vector[i]));
end
assign out_halt= '0;

always_comb begin
    for (int i = 0; i < N; i++)begin : g_ifs
        OUT_OFFSET=0;
        // fill from the ras_dp_pipe vector with fields to be protected
        out_pkt[i].data            = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].data)];                  OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].data);
        // fill the remaining part with fields not to be protected
        out_pkt[i].sot             = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].sot)];                   OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].sot);
        out_pkt[i].soh             = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].soh)];                   OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].soh);
        out_pkt[i].dv              = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].dv)];                    OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].dv);
        out_pkt[i].eot             = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].eot)];                   OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].eot);
        out_pkt[i].is_from_dma     = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].is_from_dma)];           OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].is_from_dma);
        out_pkt[i].is_from_msg_gen = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].is_from_msg_gen)];       OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].is_from_msg_gen);
        out_pkt[i].intf            = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].intf)];                  OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].intf);
        out_pkt[i].badeot          = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].badeot)];                OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].badeot);
        out_pkt[i].dwen            = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].dwen)];                  OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].dwen);
          out_pkt[i].ep              = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].ep)];                  OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].ep);
          out_pkt[i].ptm             = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].ptm)];                 OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].ptm);
         out_pkt[i].pme_to_ack       = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].pme_to_ack)];          OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].pme_to_ack);
          out_pkt[i].tlp_len         = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].tlp_len)];             OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].tlp_len);
        out_pkt[i].ras_dp_err_inband_kbd = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].ras_dp_err_inband_kbd)];  OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].ras_dp_err_inband_kbd);
        out_pkt[i].tlp_prot              = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].tlp_prot)];               OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].tlp_prot);
    end
end

endmodule

