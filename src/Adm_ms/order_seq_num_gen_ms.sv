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
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/order_seq_num_gen_ms.sv#2 $
// -------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// --- Module Description:
// This module (re)generates order sequence number for dual channel
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
module order_seq_num_gen_ms
import DWC_pcie_core_pkg::xadm_pkt_t;
#(
    parameter type PKT_TYPE = xadm_pkt_t,
    parameter      N        = 2
)
(
    input  logic                     clk,
    input  logic                     rst_n,
    // input channel 
    input  PKT_TYPE            [1:0] in_pkt,
    // output channel
    output PKT_TYPE            [1:0] out_pkt,
    input  logic               [1:0] in_halt
);

 
logic     [2:0]      pkt_num;
logic     [1:0][2:0] c_order_seqnum,r_order_seqnum; 

  `SNPS_UNR_CONSTANT("In single port mode, packet at second interface cannot be asserted as 2'nd port not exits", in_pkt[1], '0,N<2)
  `SNPS_UNR_CONSTANT("In single port mode, halt at second interface cannot be asserted as 2'nd port not exits", in_halt[1], 1'b0,N<2)

generate 
    always_comb begin 
// Initalization of the out_pkt
            out_pkt = in_pkt;
// Initialize the order_seqnum with its registered value, this ensures that a multi-cycle tlp keeps its order_seqnum
            for (int i=0; i<2; i++) begin
                out_pkt[i].order_seqnum = r_order_seqnum[i]; 
            end 
// In case of one (or two) tlps starting (hv), give them new sequence numbers,
// based on whether they start together or not. 
// Note that, if a new starting tlp is unhalted, the pkt_num is also updated, depending on how many parallel tlps are unhalted together
            if (in_pkt[0].hv && in_pkt[1].hv) begin        // two TLPs ended in a cycle
                if (in_pkt[0].order_seqnum == 3'(in_pkt[1].order_seqnum + 3'd1)) begin
                    out_pkt[0].order_seqnum = pkt_num + 1;
                    out_pkt[1].order_seqnum = pkt_num;
                end else begin 
                    out_pkt[0].order_seqnum = pkt_num;
                    out_pkt[1].order_seqnum = pkt_num + 1;
                end
            end else begin                               // one TLP ended in a cycle       
                for (int i=0; i<2; i++) begin
                    if (in_pkt[i].hv) begin 
                        out_pkt[i].order_seqnum = pkt_num;
                    end
                end
            end
// Finally, ensure that, for each tlp, we register the new order_seqnum used for it, so it gets kept for multicycle tlps
            for (int i=0; i<2; i++) begin
                c_order_seqnum[i] = out_pkt[i].order_seqnum ; 
            end 
        end 
endgenerate

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
       pkt_num         <= #`TP '0;  
       r_order_seqnum  <= #`TP '0;
    end else begin
       if ((in_pkt[0].hv && !in_halt[0]) && (in_pkt[1].hv && !in_halt[1])) begin              // two TLPs ended in a cycle
            pkt_num    <= #`TP pkt_num + 2;
       end else if ((in_pkt[0].hv && !in_halt[0]) || (in_pkt[1].hv && !in_halt[1])) begin     // one TLP ended in a cycle
            pkt_num    <= #`TP pkt_num + 1;
       end
        r_order_seqnum <= #`TP c_order_seqnum;
    end
end

endmodule

