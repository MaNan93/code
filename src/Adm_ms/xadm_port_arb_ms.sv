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
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_port_arb_ms.sv#5 $
// -------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// --- Module Description:
// This module takes several sources (XALI,MSG/LBC,DMA,XALI Translated by ATU) and arbitrates between them.
// MSG/LBC is high priority and gets scheduled ASAP.
// The other are managed in RR.
// At any given cycle, only one source is connected to the output, so different sources are never mixed up.
// XALI sources can have two interfaces. Because we never mix multiple sources, when we want to switch
// to another source we must have finished the packet on both XALI interfaces. This arbiter takes care of that.
//
// Note: Sequence Numbers are recreated when transferring packets, as different sources have different generators.
// Note that the output SeqNum starts from 0 at reset, but it is not required for input sources to start from 0 at reset.
// The only assumption is that SeqNum at inputs are kept consistent (never more than 1 of difference).
//
// This module has always all the interfaces defined, to keep it clear.
// Unused interfaces are supposed to be tied to 0.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module xadm_port_arb_ms
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::E_TX_PORT_ID_XALI;
import DWC_pcie_ctl_pkg::E_TX_PORT_ID_MSG;
import DWC_pcie_ctl_pkg::E_TX_PORT_ID_LBC;
import DWC_pcie_ctl_pkg::E_TX_PORT_ID_DMA;
import DWC_pcie_core_pkg::xadm_pkt_t;
#(
    parameter VC = 0,
    parameter N_HP=1, //0,1
    parameter HP_MULTI_CYCLE_CAPABLE=0,
    parameter N_XALI=1, //1,2
    parameter N_DMA=0 //0,1
)
(
    input logic             clk,
    input logic             rst_n,
    
    input xadm_pkt_t        in_hp_pkt,
    output logic            out_hp_halt,
    input xadm_pkt_t  [1:0] in_xali_pkt,
    output logic      [1:0] out_xali_halt,
    input xadm_pkt_t        in_dma_pkt,
    output logic            out_dma_halt,
    
    output xadm_pkt_t [1:0] out_pkt,
    input logic       [1:0] in_halt
);

localparam USE_GENERIC_ARB = 1;
localparam REQ_WD = (1+1+1); // HP+XALI+DMA+XALI_TRANSLATED;
typedef enum int {S_HP_B=0, S_XALI_B=1, S_DMA_B=2} e_sources_bit;

generate
    if (USE_GENERIC_ARB == 0) begin : g_custom_arb
        // Parameters and variables
        localparam REQ_RR_WD = (1+1);   // XALI+DMA+XALI_TRANSLATED;

        typedef struct packed{
            logic [REQ_RR_WD-1:0]   req_priority;
            logic [1:0][2:0]        order_seqnum;
            logic [1:0]             transfer_ongoing_on_itf;
            logic                   transfer_ongoing;
            logic [2:0]             seqnum_tracker;
            logic [REQ_WD-1:0]      granting;
        } s_t;
        s_t c, r;

        // STEP 1:
        // Assign requests from different sources, with MSG/LBC being in position 0.
        // A request is the hv
        wire [REQ_WD-1:0] req;
        assign    req[S_HP_B]   = in_hp_pkt.hv && N_HP==1;
        assign    req[S_XALI_B] = in_xali_pkt[0].hv || (in_xali_pkt[1].hv && N_XALI==2);
        assign    req[S_DMA_B]  = in_dma_pkt.hv && N_DMA==1;
        // STEP 2:
        // Round robin arbiter. Exclude bit 0 (HP) from req (as MSG/LBC is not in RR scheme).
        // When HP is requesting, gnt is forced to accept it.
        logic[REQ_WD-1:0] gnt;
        always_comb begin
            case({req,r.req_priority})
                5'b010_01,
                5'b010_10,
                5'b110_01: gnt = 3'b010; //accept xali0

                5'b100_10,
                5'b100_01,
                5'b110_10: gnt = 3'b100; //accept xali1

                default: gnt = {2'b00,req[S_HP_B]}; //accept HP, if requesting
            endcase
        end

        // STEP 3:
        // With 2 parallel interfaces, there is the risk of never being able to switch to another source.
        // Indeed, if a packet ends (EOT) but on the parallel interface it is still going on, we may enter a loop where we continuously accepts new pkts.
        // When the arbiter wants to change (gnt is "not us" and someone is requesting, so we are not the desired source anymore), we stop to accept packets.
        // Also, precalculate which between xali and xali_translated has the higher seqnum, to be used later on.
        wire force_stop_to_accept_from_xali_0 = in_xali_pkt[0].hv && !gnt[S_XALI_B] && |req;
        wire force_stop_to_accept_from_xali_1 = N_XALI==2 && in_xali_pkt[1].hv && !gnt[S_XALI_B] && |req;
        wire xali_prio                        = N_XALI==1 ? 1'b0 : in_xali_pkt[0].order_seqnum==3'(in_xali_pkt[1].order_seqnum+3'd1) ? 1'b1 : 1'b0;
        wire prio = xali_prio;

        // STEP 4:
        // Main combinational process, connecting outputs to inputs and others
        always_comb begin : main_comb_PROC
            logic one_accepted, two_accepted;
            // STEP 4.1:
            // Initialise comb signals.
            // In particular, halts by default if input interface has one hv
            c                = r;
            out_pkt          = '0;
            out_hp_halt      = in_hp_pkt.hv || N_HP==0;
            out_dma_halt     = in_dma_pkt.hv || N_DMA==0;
            out_xali_halt[0] = in_xali_pkt[0].hv;
            out_xali_halt[1] = in_xali_pkt[1].hv || N_XALI==1;
            
            // STEP 4.2:
            // Consider the case of a transfer already ongoing (so we have one or two unfinished pkts).
            // We must continue to stream from the same source, which is what we granted before (r.granting)
            // Note that if a new pkt appears from that source and we decided to switch to someone else, we do not accept it (force_stop).
            if(r.transfer_ongoing)begin
                unique case(1'b1)
                    r.granting[S_HP_B]: begin
                        if(N_HP==1 && HP_MULTI_CYCLE_CAPABLE==1)begin
                            out_pkt[0]  = in_hp_pkt;
                            out_hp_halt = in_halt[0];
                        end
                    end
                    r.granting[S_XALI_B]: begin // XALI, continue transfer
                        out_pkt[0]       = force_stop_to_accept_from_xali_0 ? '0 : in_xali_pkt[0];
                        out_xali_halt[0] = force_stop_to_accept_from_xali_0 ? 1'b1 : in_halt[0];
                        if(N_XALI==2)begin
                            out_pkt[1]       = force_stop_to_accept_from_xali_1 ? '0 : in_xali_pkt[1];
                            out_xali_halt[1] = force_stop_to_accept_from_xali_1 ? 1'b1 : in_halt[1];
                        end
                    end
                    r.granting[S_DMA_B]: begin //DMA, continue transfer
                        if(N_DMA==1)begin
                            out_pkt[0]   = in_dma_pkt;
                            out_dma_halt = in_halt[0];
                        end
                    end
                    default: begin end
                endcase
            end
            // STEP 4.3
            // Consider the case where we transferred the eot before, so this is a new cycle and we are free to
            // obey to the arbiter choice (gnt).
            else begin
                c.granting = gnt;
                unique case(1'b1)
                    gnt[S_HP_B] : begin
                        if(N_HP==1)begin
                            out_pkt[0]  = in_hp_pkt;
                            out_hp_halt = in_halt[0];
                        end
                    end
                    gnt[S_XALI_B]: begin
                        out_pkt[0]       = in_xali_pkt[0];
                        out_xali_halt[0] = in_halt[0];
                        if(N_XALI==2)begin
                            out_pkt[1]       = in_xali_pkt[1];
                            out_xali_halt[1] = in_halt[1];
                        end
                    end
                    gnt[S_DMA_B]: begin
                        out_pkt[0]   = in_dma_pkt;
                        out_dma_halt = in_halt[0];
                    end
                    default: begin end
                endcase
                
                // Update Round Robin arbiter if we have selected a source in RR scheme (not HP)
                c.req_priority[REQ_RR_WD-1:0] = ( gnt[S_DMA_B] || gnt[S_XALI_B]) ?
                        {gnt[REQ_WD-2:1], gnt[REQ_WD-1]} : r.req_priority[REQ_RR_WD-1:0];
            end
            
            // STEP 4.4
            // We must keep track of unfinished packets, as we can't switch source in that case.
            c.transfer_ongoing_on_itf[0] = (out_pkt[0].eot && !in_halt[0]) ? 1'b0 : (out_pkt[0].dv && !in_halt[0]) ? 1'b1 : r.transfer_ongoing_on_itf[0];
            c.transfer_ongoing_on_itf[1] = N_XALI==1 ? 1'b0 : (out_pkt[1].eot && !in_halt[1]) ? 1'b0 : (out_pkt[1].dv && !in_halt[1]) ? 1'b1 : r.transfer_ongoing_on_itf[1];
            c.transfer_ongoing           = |c.transfer_ongoing_on_itf; // only to optimize synthesis
            
            // STEP 4.5
            // Overwrite the sequence number of the output packet.
            // This is done to "unify" the seqnums coming from different sources.
            // Note that the seqnum is assigned only on hv, for the rest of the packet the seqnum is held.
            out_pkt[0].order_seqnum = r.order_seqnum[0];
            out_pkt[1].order_seqnum = r.order_seqnum[1];
            if(N_XALI==2)begin
                case({out_pkt[1].hv, out_pkt[0].hv})
                    2'b01 : begin
                        out_pkt[0].order_seqnum = r.seqnum_tracker;
                    end
                    2'b10 : begin
                        out_pkt[1].order_seqnum = r.seqnum_tracker;
                    end
                    2'b11 : begin
                        // special case of two pkts in parallel, can happen only for xali or xali_translated
                        // Depending on their ORIGINAL seqnum, decides who's going to have the highest new seqnum.
                        out_pkt[0].order_seqnum = !prio ? (r.seqnum_tracker) : 3'(r.seqnum_tracker+3'd1);
                        out_pkt[1].order_seqnum = prio ? (r.seqnum_tracker) : 3'(r.seqnum_tracker+3'd1);
                    end
                    default: begin
                    end
                endcase
            end else begin
                if(out_pkt[0].hv)begin
                    out_pkt[0].order_seqnum = r.seqnum_tracker;
                end
            end
            
            // STEP 4.6
            // Update the seqnum tracker depending on how many new packets we have accepted
            // Precalculate +1 and +2 and +3 to improve synthesis
            one_accepted     = ((out_pkt[0].hv && !in_halt[0]) || (N_XALI==2 && out_pkt[1].hv && !in_halt[1]));
            two_accepted     = N_XALI==1 ? 1'b0 : ((out_pkt[0].hv && !in_halt[0]) && (out_pkt[1].hv && !in_halt[1]));
            c.seqnum_tracker = (N_XALI==2 && two_accepted) ? 3'(r.seqnum_tracker+3'd2) : one_accepted ? (r.seqnum_tracker+3'd1) : r.seqnum_tracker;
            
            for(int i = 0; i < 2; i++)begin
                c.order_seqnum[i] = out_pkt[i].order_seqnum;
            end
        end

        // STEP 5
        // Registers assignment
        always_ff @(posedge clk or negedge rst_n)begin : main_seq_PROC
            if(!rst_n)begin
                r                 <= #TP '0;
                r.req_priority[0] <= #TP 1'b1;
            end else begin
                r <= #TP c;
            end
        end
    end else begin : g_use_generic_arb
        localparam N_PR1 = 1 + N_DMA;
        
        xadm_pkt_t            [1:0] in_pr0_pkt;
        logic                 [1:0] out_pr0_halt;
        
        xadm_pkt_t [N_PR1-1:0][1:0] in_pr1_pkt;
        logic      [N_PR1-1:0][1:0] out_pr1_halt;

        // High priority maps to priority 0 (pr0)
        // 0
        if (N_HP > 0) begin
            assign in_pr0_pkt[0]               = in_hp_pkt;
            assign out_hp_halt                 = out_pr0_halt[0];
        end else begin
            assign in_pr0_pkt[0]               = '0;
            assign out_hp_halt                 = '0;
        end
        // 1
        assign in_pr0_pkt[1]               = '0;
        //assign out_hp_halt[1] = out_pr0_halt[1];

        // Other packets map to priority 1 (pr1)
        // 0
        assign in_pr1_pkt[0][0]            = in_xali_pkt[0];
        assign out_xali_halt[0]            = out_pr1_halt[0][0];
        if (N_DMA > 0) begin
            assign in_pr1_pkt[1][0]            = in_dma_pkt;
            assign out_dma_halt                = out_pr1_halt[1][0];
        end else begin
            assign out_dma_halt                = '0;
        end
        // 1
        if (N_XALI > 1) begin
            assign in_pr1_pkt[0][1] = in_xali_pkt[1];
            assign out_xali_halt[1] = out_pr1_halt[0][1];
        end else begin
            assign in_pr1_pkt[0][1] = '0;
            assign out_xali_halt[1] = '1;
        end
        if (N_DMA > 0) begin
            assign in_pr1_pkt[1][1] = '0;
        end
        //assign out_dma_halt[1] = out_pr1_halt[1][1];

        xadm_pkt_t [1:0] pkt_to_order_seq_num_gen;
        xadm_generic_dual_arb_ms
         #(
            .N_PR1(N_PR1),
            .PKT_TYPE(xadm_pkt_t),
            .NO_PR0_PKT(N_HP == 0),
            .N(N_XALI)
        ) u_xadm_generic_dual_arb_ms (
            .clk          (clk),
            .rst_n        (rst_n),
            .in_pr0_pkt   (in_pr0_pkt),
            .out_pr0_halt (out_pr0_halt),
            .in_pr1_pkt   (in_pr1_pkt),
            .in_pr1_mask  ('0),
            .out_pr1_halt (out_pr1_halt),
            .out_pkt      (pkt_to_order_seq_num_gen),
            .in_halt      (in_halt)
        );
        order_seq_num_gen_ms
         #(
            .PKT_TYPE(xadm_pkt_t),
            .N(N_XALI)
        ) u_order_seq_num_gen_ms (
            .clk          (clk),
            .rst_n        (rst_n),
            .in_pkt       (pkt_to_order_seq_num_gen),
            .out_pkt      (out_pkt),
            .in_halt      (in_halt)
        );
    end
endgenerate


endmodule

