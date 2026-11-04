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

// ---------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2024/01/10 14:23:51 $
// ---   $Revision: #1 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_arb_wrr_arbitration.sv#1 $
// ---------------------------------------------------------------------------
// --- Module Description: NUM_CLIENTS=2: use 2 client round-robin arbiter with priority input (used for cxl ARB/MUX)
//                         NUM_CLIENTS>2: use BCM53mod
// ---------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_pcie_arb_wrr_arbitration
#( parameter TP                = `TP,
   parameter NUM_CLIENTS       = 2,
   parameter P_WIDTH           = 4
) 
                                   (
    input                             core_clk,
    input                             core_rst_n,
    input  logic                      enable,
    input  logic [NUM_CLIENTS-1:0]    prior,
    input  logic [NUM_CLIENTS-1:0]    req_in,
    output logic [NUM_CLIENTS-1:0]    grant
);

generate
  // -------------------------------------------------------------------------------------
  // 2 client arbiter, logic optimised arbiter (compared to BCMmod53)
  // -------------------------------------------------------------------------------------
  if (NUM_CLIENTS == 2) begin: gen_2client_arb

logic [NUM_CLIENTS-1:0]        prv_gnt_nxt, prv_gnt_r;
logic [NUM_CLIENTS-1:0]        masked_req;
logic [NUM_CLIENTS-1:0]        int_mask;
logic [NUM_CLIENTS-1:0]        int_gnt;

// priority relevant when both clients are requesting simultaneously
// - both priority bits set: arbiter will start with client 0 (aligned with BCM53mod)
// - priority on one client: request will be masked with priority

assign masked_req = req_in & int_mask;

assign grant = int_gnt;

// --- int_mask logic ----
always_comb begin
    if (&req_in) begin
         // if both clients request and priority is set for a client then assign priority to the int_mask
         if ((prior==2'b01) || (prior==2'b10)) begin
             int_mask = prior;
         end
         else begin
             //if no or same priority toggle the int_mask based on previous grant
             case (prv_gnt_r)
                 2'b01:   int_mask = 2'b10;
                 default: int_mask = 2'b01;
             endcase
         end
    end
    else begin
        // single client requests, set mask same as request
        int_mask = req_in;
    end
end

// --- grant logic --- 
always_comb begin
    prv_gnt_nxt = prv_gnt_r;

    // if both clients request, toggle the mask
    if (&req_in) begin
        for (integer i=0; i < NUM_CLIENTS; i++) begin
            int_gnt[i] = 1'b0;
            if (masked_req[i]) begin
                int_gnt[i] = 1'b1;
            end
        end
    end
    else begin
        // if 1 client request, grant the request
        int_gnt = masked_req;
    end

    // latch the current grant. It will become the previous grant for decision on next request
    if (enable) begin
        //if (&req_in && !(|prior)) begin
        if (&req_in) begin
            // if both client and priority is zero or same, then latch current grant (for toggling on next request)
            prv_gnt_nxt = int_gnt;
        end    
        else begin
            // for single request keep prev grant at 2'b10, that for next simultaneous requests it can start with client0
            prv_gnt_nxt = 2'b10;
        end
    end
end

// --- clocked process--- 
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        prv_gnt_r <= # TP '0;
    end
    else begin
        prv_gnt_r <= # TP prv_gnt_nxt;
    end
end


  // -------------------------------------------------------------------------------------
  // For more than 2 clients use bcmmod53 arbiter
  // -------------------------------------------------------------------------------------
  end else begin : gen_multiclient_arb
  
// Arbiter Configuration Parameters
localparam         INDEX_WD        = $clog2(NUM_CLIENTS);
localparam         OUTPUT_MODE     = 0;
localparam integer REG_DELAY_DENOM = 1000;
localparam integer REG_DELAY_TIME  = `TP * REG_DELAY_DENOM;
  
logic [(NUM_CLIENTS * P_WIDTH) - 1 : 0] arb_pri_s;
  
// map priority to lowest bits of P_WIDTH bus per client
always_comb begin
    arb_pri_s = '0;
    for (integer i=0; i < NUM_CLIENTS; i++) begin
        // assign priority to lowest bit position of prior input per client, lowest value is highest priority
        arb_pri_s[i*P_WIDTH] = ~prior[i];
    end
end
  
  // Instantiate priority arbiter, fairness among equals
DWC_pcie_ctl_bcmmod53
 #(
    .N               ( NUM_CLIENTS         ),
    .P_WIDTH         ( P_WIDTH             ),
    .PARK_MODE       ( 0                   ),
    .PARK_INDEX      ( 2                   ),
    .OUTPUT_MODE     ( OUTPUT_MODE         ),
    .INDEX_WIDTH     ( INDEX_WD            ),
    .REG_DELAY_TIME  ( REG_DELAY_TIME      ),
    .REG_DELAY_DENOM ( REG_DELAY_DENOM     )
) u_cxl_arbiter (
    .clk             ( core_clk            ),
    .rst_n           ( core_rst_n          ),
    .init_n          ( 1'b1                ),
    .enable          ( enable              ),
    .request         ( req_in              ),
    .prior           ( arb_pri_s           ),
    .lock            ( {NUM_CLIENTS{1'b0}} ),
    .mask            ( {NUM_CLIENTS{1'b0}} ),
    .parked          ( /* Unconnected */   ),
    .granted         ( /* Unconnected */   ),
    .locked          ( /* Unconnected */   ),
    .grant           ( grant               ),
    .grant_index     ( /* Unconnected */   )
);
  end
endgenerate
// -------------------------------------------------------------------------------------

endmodule
