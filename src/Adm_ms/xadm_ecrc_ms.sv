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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_ecrc_ms.sv#3 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module xadm_ecrc_ms
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::NW;
import DWC_pcie_ctl_pkg::NPRFX;
import DWC_pcie_core_pkg::ADM_PRFX_HDR_NW;
import DWC_pcie_core_pkg::xadm_pkt_t;
#(
    parameter N          = 1,
    parameter IS_FOR_HDR = 0,
    parameter USE_BCM49  = 0
)
(
    input logic               clk,
    input logic               rst_n,
    input logic               in_flit_mode_enable, 
    input xadm_pkt_t  [N-1:0] in_pkt,
    output logic      [N-1:0] out_halt,
    output xadm_pkt_t [N-1:0] out_pkt,
    input logic       [N-1:0] in_halt
    
);
assign out_halt = in_halt;

wire [511:0] ecrc_rx_init_vec = 512'hDF27BB8271C48353082FBB794191AF83869D3834E2265DB9CD55919B0D0E66733AA01F608E3D684D5FE50C641470E51CD61C3A65F50B27F746AF6449FFFFFFFF;

localparam DW = IS_FOR_HDR==1?ADM_PRFX_HDR_NW:NW;
function automatic logic[31:0] flipbits32 (logic[31:0] a);
    for (int i=0; i<32; i=i+1) flipbits32[i] = a[31-i];
endfunction
function automatic logic[DW*32-1:0] flipbits_all_DW (logic[DW*32-1:0] a);
    for (int i=0; i<DW*32; i=i+1) flipbits_all_DW[i] = a[DW*32-1-i];
endfunction

logic [N-1:0][DW-1:0][31:0] data,data_with_crc_state;
logic [N-1:0][DW-1:0][31:0] crc_state_j_vec;
logic [N-1:0][31:0]         crc_state_i, crc_state_j, r_crc_state;
logic [N-1:0][DW-1:0]       end_marker;


// Calculate one-hot markers.
// May be moved to another block to improve timing
logic[N-1:0][NPRFX+1:0] hdr_start_oh;
logic[N-1:0][NPRFX:0] e2e_or_hdr_start_oh;
logic[N-1:0][ADM_PRFX_HDR_NW-1:0]   hdr_end_oh;
logic[N-1:0][NW-1:0]    data_end_oh;
always_comb begin
    hdr_start_oh        = '0;
    e2e_or_hdr_start_oh = '0;
    hdr_end_oh          = '0;
    data_end_oh         = '0;
    for(int i = 0; i < N; i++)begin

        // Find the start of the Header
        for(int j = 0; j <= NPRFX; j++) 
            hdr_start_oh[i][j] = (hdr_start_oh[i]=='0 && in_pkt[i].hdr_dwen[j]) ? 1'b1 : 1'b0;

        // Find the first E2E prefix or the first Header word (skip Local
        // prefixes not included in ECRC calculation)
        for(int j = 0; j <= NPRFX; j++) 
            e2e_or_hdr_start_oh[i][j] = (e2e_or_hdr_start_oh[i]=='0 && (hdr_start_oh[i][j] || in_pkt[i].prfx_hdr[j][7:4]==4'b1001)) ? 1'b1 : 1'b0;
        
        // Find the end of the Header. If not found, the end is the end of the bus
        for(int j = 0; j < ADM_PRFX_HDR_NW-1; j++)
            hdr_end_oh[i][j] = (in_pkt[i].hdr_dwen[j] && !in_pkt[i].hdr_dwen[j+1]) ? 1'b1 : 1'b0;
        hdr_end_oh[i][ADM_PRFX_HDR_NW-1] = hdr_end_oh[i]=='0 ? in_pkt[i].hv : 1'b0;
        
        // Find the end of the Data. If not found, the end is the end of the bus
        for(int j = 0; j < NW-1; j++)
            data_end_oh[i][j] = (in_pkt[i].data_dwen[j] && !in_pkt[i].data_dwen[j+1]) ? 1'b1 : 1'b0;
        data_end_oh[i][NW-1] = data_end_oh[i]=='0 ? in_pkt[i].dv : 1'b0;
    end
end


generate
    if(USE_BCM49==1)begin : g_use_bcm49
        //logic [N-1:0][2+$clog2(DW+1)-1:0] num_bytes_unused;
        for(genvar i = 0; i < N; i++)begin : g_i
            if(IS_FOR_HDR==1)begin : g_hdr
                assign crc_state_i[i]      = 32'hFFFFFFFF;
                //assign num_bytes_unused[i] = {in_pkt[i].num_hdr_dw_unused,2'b00};
                always_comb begin : hdr_PROC
                    data[i] = in_pkt[i].prfx_hdr;
                    for(int j = 0; j <= NPRFX+1;j++)begin
                        data[i][j] = data[i][j] | (!in_flit_mode_enable ?   (hdr_start_oh[i][j] ? 32'h0040_0001 : 32'h0) : 
                                                                            (hdr_start_oh[i][j] ? 32'h0000_0001 : (j > 0 && hdr_start_oh[i][j-1]) ? 32'h0080_0000 : 32'h0));
                    end
                    for(int j = 0; j < NPRFX;j++)   data[i] = e2e_or_hdr_start_oh[i][j] ? (data[i] >> j*32) : data[i];
                end
            end else begin : g_data
                assign crc_state_i[i]      = in_pkt[i].hv ? in_pkt[i].ecrc : r_crc_state[i];
                //assign num_bytes_unused[i] = {in_pkt[i].num_data_dw_unused, 2'b00};
                assign data[i]             = in_pkt[i].data;
                always_ff@(posedge clk or negedge rst_n)begin
                    if(!rst_n)  r_crc_state[i] <= #TP '0;
                    else        r_crc_state[i] <= #TP !in_halt[i] ? crc_state_j[i] : r_crc_state[i];
                end
            end
            always_comb begin : g_common
                out_pkt[i]      = in_pkt[i];
                out_pkt[i].ecrc = IS_FOR_HDR==1 ? crc_state_j[i] : flipbits32(~crc_state_j[i]);
            end
            DWC_pcie_ctl_bcm49_sv #(.DATA_WIDTH(DW*32), .POLY_SIZE(32), .POLY_COEF0(32'h1DB7), .POLY_COEF1(32'h04C1), .BYTES_NOT_USED_WIDTH(2+$clog2(DW+1)))
            u_crc
            (
                .data_in       (flipbits_all_DW(data[i])),
                .crc_i         (crc_state_i[i]          ),
                .crc_j         (crc_state_j[i]          ),
                .bytes_not_used(0/*num_bytes_unused[i]*/));
        end : g_i
        
    end else begin : g_use_bcmmod48
        logic [N-1:0] started;
        for(genvar i = 0; i < N; i++)begin : g_i

            // Logic for Prefix+Header
            // 1) Set invariant bits in the header
            // 2) Find the initial CRC state to be used (crc_state_i), skipping Local Prefixes
            if(IS_FOR_HDR==1)begin : g_hdr
                always_comb begin : hdr_PROC
                    data[i]        = in_pkt[i].prfx_hdr;
                    crc_state_i[i] = ecrc_rx_init_vec[31:0];
                    started[i]     = 1'b0;
                    for(int j = 0; j <= NPRFX+1;j++)
                        data[i][j] = data[i][j] | (!in_flit_mode_enable ?   (hdr_start_oh[i][j] ? 32'h0040_0001 : 32'h0) : 
                                                                            (hdr_start_oh[i][j] ? 32'h0000_0001 : (j > 0 && hdr_start_oh[i][j-1]) ? 32'h0080_0000 : 32'h0));
                    for(int j = 0; j <= NPRFX;j++)begin
                        started[i]     = started[i] || e2e_or_hdr_start_oh[i][j];
                        data[i][j]     = started[i] ? data[i][j] : 32'd0;
                        crc_state_i[i] = e2e_or_hdr_start_oh[i][j] ? flipbits32(ecrc_rx_init_vec[j*32+:32]) : crc_state_i[i];
                    end
                    end_marker[i] = hdr_end_oh[i];
                end
            end 
            // Logic for Data
            // 1) Select the initial CRC state (either the one coming from the header or the one calculated at the previous cycle
            // 2) Register the CRC State to be used at the next cycle if packet isn't finished
            else begin : g_data
                assign crc_state_i[i] = in_pkt[i].hv ? flipbits32(in_pkt[i].ecrc) : flipbits32(r_crc_state[i]);
                assign data[i]        = in_pkt[i].data;
                assign end_marker[i]  = data_end_oh[i];
                always_ff@(posedge clk or negedge rst_n)begin
                    if(!rst_n)  r_crc_state[i] <= #TP '0;
                    else        r_crc_state[i] <= #TP !in_halt[i] ? crc_state_j[i] : r_crc_state[i];
                end
            end : g_data
            
            // Common logic for Header and Data
            // 1) Pre-process the hdr/data (as needed by bcmmod48) depending on the end marker
            // 2) Set the new CRC State according to the output of bcmmod48 and the end marker
            // 3) if HDR, output the CRC State. If DATA, output the CRC
            always_comb begin : g_common
                data_with_crc_state[i] = data[i] ^ {{DW-1{32'h0}}, (crc_state_i[i])};
                crc_state_j[i]         = crc_state_j_vec[i][DW-1];
                for(int j = 0; j < DW; j++)begin
                    if(end_marker[i][j])begin
                        data_with_crc_state[i] = (data[i] ^ {{DW-1{32'h0}}, (crc_state_i[i])}) << (32*(DW-1-j));
                        crc_state_j[i]         = crc_state_j_vec[i][j];
                    end
                end
                out_pkt[i]      = in_pkt[i];
                out_pkt[i].ecrc = IS_FOR_HDR==1 ? crc_state_j[i] : !in_pkt[i].dv ? flipbits32(~in_pkt[i].ecrc) : flipbits32(~crc_state_j[i]);
            end
            DWC_pcie_ctl_bcmmod48
             #(.DATA_WIDTH(DW*32), .POLY_SIZE(32), .POLY_COEF0(32'h1DB7), .POLY_COEF1(32'h04C1))
            u_crc
            (.data_in       (flipbits_all_DW(data_with_crc_state[i])), .crc_j         (crc_state_j_vec[i]          ));
        end : g_i
    end : g_use_bcmmod48
endgenerate

endmodule

