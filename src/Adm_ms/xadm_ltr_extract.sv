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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_ltr_extract.sv#2 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module xadm_ltr_extract
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::NW;
import DWC_pcie_ctl_pkg::NPRFX;
import DWC_pcie_core_pkg::ADM_PRFX_HDR_NW;
import DWC_pcie_core_pkg::xadm_pkt_t;
#(
    parameter N = 1
)
(
    input  logic                    clk,
    input  logic                    rst_n,
    input  xadm_pkt_t [N-1:0]       in_pkt,
    input  logic      [N-1:0]       out_halt,
    output logic                    xadm_msg_ltr,
    output logic             [31:0] xadm_msg_ltr_latency
);

logic [N-1:0][$clog2(NPRFX+1)-1:0] soh;

always_comb begin
    soh = '0;
    for (int i = 0; i < N; i++) begin
        for (int j = 1; j <= NPRFX; j++) begin
            if (in_pkt[i].prfx_dwen[j-1]) begin
                soh[i] = j;
            end
        end
    end
end

generate
    if (N == 0) begin : g_eq0
        assign xadm_msg_ltr         = '0;
        assign xadm_msg_ltr_latency = '0;
    end else if (N == 1) begin : g_lt2
        logic is_ltr;
        assign is_ltr = in_pkt[0].hv && in_pkt[0].support.msg_is_ltr && (!out_halt[0]);
        always_ff@(posedge clk or negedge rst_n)begin
            if (!rst_n) begin
                xadm_msg_ltr_latency <= #TP '0;
                xadm_msg_ltr         <= #TP '0;
            end else begin
                if (is_ltr) begin
                    xadm_msg_ltr         <= #TP 1'b1;
                    xadm_msg_ltr_latency <= #TP in_pkt[0].prfx_hdr[soh+3];
                end else begin
                    xadm_msg_ltr         <= #TP '0;
                    xadm_msg_ltr_latency <= #TP '0;
                end
            end
        end
    end else begin : g_eq2
        logic [1:0] is_ltr;
        assign is_ltr[0] = in_pkt[0].hv && in_pkt[0].support.msg_is_ltr && (!out_halt[0]);
        assign is_ltr[1] = in_pkt[1].hv && in_pkt[1].support.msg_is_ltr && (!out_halt[1]);
        logic first_is_priority;
        assign first_is_priority = (in_pkt[1].order_seqnum == (in_pkt[0].order_seqnum + 3'd1));
        always_ff@(posedge clk or negedge rst_n)begin
            if (!rst_n) begin
                xadm_msg_ltr_latency <= #TP '0;
                xadm_msg_ltr         <= #TP '0;
            end else begin
                if (is_ltr[0] && first_is_priority) begin
                    xadm_msg_ltr         <= #TP 1'b1;
                    xadm_msg_ltr_latency <= #TP in_pkt[0].prfx_hdr[soh[0]+3];
                end else if (is_ltr[1]) begin
                    xadm_msg_ltr         <= #TP 1'b1;
                    xadm_msg_ltr_latency <= #TP in_pkt[1].prfx_hdr[soh[1]+3];
                end else begin
                    xadm_msg_ltr         <= #TP 1'b0;
                    xadm_msg_ltr_latency <= #TP '0;
                end
            end
        end
    end
endgenerate


endmodule

