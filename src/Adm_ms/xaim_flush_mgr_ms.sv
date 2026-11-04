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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xaim_flush_mgr_ms.sv#2 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xaim_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module xaim_flush_mgr_ms
import DWC_pcie_core_pkg::*;
import DWC_pcie_ctl_pkg::*;
import xaim_ms_pkg::*;
import pcie_pkg::*;
#(
    parameter fc_type_e    FC_TYPE = E_P,
    parameter tx_port_id_e  PORT_E = E_TX_PORT_ID_LBC
)

                        (
    input  logic      clk,
    input  logic      rst_n,

    input  logic      in_flush,    
    input  logic      pm_xtlh_block_tlp,    
    input  logic      cfg_client_p_block_new_tlp,    
    input  logic      cfg_client_np_block_new_tlp,    
    input  logic      cfg_client_cpl_block_new_tlp,    
    input  logic      pm_block_all_tlp,    

    input  xaim_pkt_t in_pkt,
    output logic      out_halt,
    
    output xaim_pkt_t out_pkt,
    input  logic      in_halt
);

logic blocking_tlp_is_legal;
logic pm_block_stall;
logic stall_traffic;
logic tlp_is_p;    assign tlp_is_p    = (FC_TYPE==E_P);
logic tlp_is_np;   assign tlp_is_np   = (FC_TYPE==E_NP);
logic tlp_is_cpl;  assign tlp_is_cpl  = (FC_TYPE==E_CPL);
logic tlp_is_none; assign tlp_is_none = (FC_TYPE==E_FC_NONE);

// it is legal to backpressure a client interface if:
// 1. this is the last cycle of a TLP (eot asserted and halt de-asserted)
// 2. this is an idle cycle (hv, dv and eot de-asserted, whatever halt)
// 3. this is the first cycle of a TLP being halted (hv asserted and halt asserted, whatever dv/eot)
assign blocking_tlp_is_legal = ((in_pkt.fs.eot && (!in_halt)) || (!in_pkt.fs.hv && !in_pkt.fs.eot && !in_pkt.fs.dv) || (in_pkt.fs.hv && stall_traffic));


always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        pm_block_stall <= #TP 1'b0;
    end else begin
        if (blocking_tlp_is_legal) begin
            if (tlp_is_none) begin
                pm_block_stall <= #TP pm_block_all_tlp;
            end else if (tlp_is_p) begin
                pm_block_stall <= #TP pm_block_all_tlp || (pm_xtlh_block_tlp && cfg_client_p_block_new_tlp);
            end else if (tlp_is_np) begin
                pm_block_stall <= #TP pm_block_all_tlp || (pm_xtlh_block_tlp && cfg_client_np_block_new_tlp);
            end else if (tlp_is_cpl) begin
                pm_block_stall <= #TP pm_block_all_tlp || (pm_xtlh_block_tlp && cfg_client_cpl_block_new_tlp);
            end
        end
    end
end

assign stall_traffic = pm_block_stall;

always_comb begin
    out_pkt  = in_pkt;
    out_halt = in_halt;
    if (stall_traffic) begin
        out_halt           = 1'b1;
        out_pkt.fs.hv  = 1'b0;
        out_pkt.fs.dv  = 1'b0;
        out_pkt.fs.eot = 1'b0;
    end
end

endmodule

