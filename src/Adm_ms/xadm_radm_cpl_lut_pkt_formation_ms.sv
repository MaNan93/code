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
// ---    $DateTime: 2023/05/05 11:28:46 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_radm_cpl_lut_pkt_formation_ms.sv#3 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module xadm_radm_cpl_lut_pkt_formation_ms
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::TAG_SIZE;
import DWC_pcie_ctl_pkg::NVC;
import DWC_pcie_ctl_pkg::N_XADM_IF;
import DWC_pcie_ctl_pkg::N_XADM_NP_IF;
import DWC_pcie_ctl_pkg::N_XADM_P_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_IF_VC;
import DWC_pcie_ctl_pkg::N_XADM_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::N_XADM_NP_CUMULATIVE_PER_VC;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_MEMRD_NON_ATS;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_MEMRD_ATS;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_IO_RD;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_IO_WR;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_CFG_RD;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_CFG_WR;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_ATOMIC;
import DWC_pcie_ctl_pkg::E_NP_REQ_TX_DMWR;
import DWC_pcie_core_pkg::ADM_PRFX_NW;
import DWC_pcie_core_pkg::xadm_radm_tx_npr_t;
import DWC_pcie_core_pkg::xadm_pkt_t;
(
    input logic                      clk,
    input logic                      rst_n,
    input logic                      cfg_flit_mode_en,
    input xadm_pkt_t [N_XADM_IF-1:0] in_pkt,
    input logic      [N_XADM_IF-1:0] in_halt,
    
    output xadm_radm_tx_npr_t        out_tx_npr,
    output logic                     out_wakeup
);

localparam int FLIT_MODE_ENABLE = 0 +1;
localparam int ATOMIC_EN = 0 +1;
localparam int CAN_BADEOT = 1 -1; // no bad_eot for AMBA 
localparam     END_TO_END_TLP_PRFX = 4'b1001;                  // Only for NFM

xadm_radm_tx_npr_t            c_info;
xadm_pkt_t [N_XADM_NP_IF-1:0] np_pkt;
logic      [N_XADM_NP_IF-1:0] np_halt;
logic [N_XADM_NP_IF-1:0] port_idx;

generate
    for(genvar vc = 0; vc < NVC; vc++) begin : g_xadm_to_radm_cpl_lut_vc
        for(genvar i = 0; i < N_XADM_NP_IF_VC[vc]; i++)begin : g_xadm_to_radm_cpl_lut_i
            localparam THIS_NP_IF = N_XADM_NP_CUMULATIVE_PER_VC[vc]+i;
            localparam THIS_IF    = N_XADM_CUMULATIVE_PER_VC[vc]+N_XADM_P_IF_VC[vc]+i;
            assign np_pkt[THIS_NP_IF]  = in_pkt[THIS_IF];
            assign np_halt[THIS_NP_IF] = in_halt[THIS_IF];
            assign port_idx[THIS_NP_IF] = i==0 ? 1'b0 : 1'b1;
        end
    end
endgenerate

function automatic logic[11:0] get_length_bytes (logic[9:0] length_dw, logic[3:0] first_be, logic[3:0] last_be);
    logic [2:0] sub;
    if(last_be==4'b0000)begin
        case (first_be)
            4'b1001, 4'b1011, 4'b1101, 4'b1111 : get_length_bytes = 12'd4;
            4'b0101, 4'b0111, 4'b1010, 4'b1110 : get_length_bytes = 12'd3;
            4'b0011, 4'b0110, 4'b1100          : get_length_bytes = 12'd2;
            default                            : get_length_bytes = 12'd1;          // TBD Can this ever be 0?
        endcase
    end else begin
        sub              = first_be[0] ? 3'd0 : first_be[1] ? 3'd1 : first_be[2] ? 3'd2 : 3'd3;
        sub              = last_be[3] ? (sub) : last_be[2] ? (sub+3'd1) : last_be[1] ? (sub+3'd2) : (sub+3'd3);
        get_length_bytes = {length_dw,2'b00} - {{9{1'b0}}, sub};
    end
endfunction

logic [N_XADM_NP_IF-1:0][4+FLIT_MODE_ENABLE-1:0][31:0] base_hdr; // get 5 DWs instead of 4 in case of flit mode to extract ByteEnable from OHC-A
logic [N_XADM_NP_IF-1:0]                               th_bit_is_set;
logic [N_XADM_NP_IF-1:0][3:0]                          first_be;
logic [N_XADM_NP_IF-1:0][3:0]                          last_be;
logic [N_XADM_NP_IF-1:0][9:0]                          length_field;
logic [N_XADM_NP_IF-1:0][9:0]                          length_field_for_atomic;
logic [N_XADM_NP_IF-1:0][11:0]                         length_bytes;
logic [N_XADM_NP_IF-1:0][2:0]                          attr;
logic [N_XADM_NP_IF-1:0][15:0]                         req_id;
logic [N_XADM_NP_IF-1:0][6:0]                          low_addr;
logic [N_XADM_NP_IF-1:0][TAG_SIZE-1:0]                 tag;
logic [N_XADM_NP_IF-1:0][2:0]                          tc;
logic [N_XADM_NP_IF-1:0]                               has_ohc_a;
logic [N_XADM_NP_IF-1:0][7:0]                          ohc_a_be;
logic [N_XADM_NP_IF-1:0][ADM_PRFX_NW:0]                hdr_start_oh;
always_comb begin
    for(int i = 0; i < N_XADM_NP_IF; i++)begin
        hdr_start_oh[i] = '0;
        base_hdr[i]     = '0;
        first_be[i]     = '0;
        last_be[i]      = '0;
        tag[i]          = '0;
        // Find the start of the Header
        for(int j = 0; j <= ADM_PRFX_NW; j++)
            hdr_start_oh[i][j] = (hdr_start_oh[i]=='0 && np_pkt[i].hdr_dwen[j]) ? 1'b1 : 1'b0;
        for(int j = 0; j <= ADM_PRFX_NW; j++)
            base_hdr[i] = hdr_start_oh[i][j] ? (np_pkt[i].prfx_hdr[j+:4+FLIT_MODE_ENABLE]) : base_hdr[i];
        
        // FLIT MODE
        if (cfg_flit_mode_en) begin
            th_bit_is_set[i] = 1'b0;
            tc[i]            = base_hdr[i][0][15:13];
            attr[i]          = base_hdr[i][0][20:18];
            has_ohc_a[i]     = base_hdr[i][0][8];
            ohc_a_be[i]      = base_hdr[i][0][5] ? (base_hdr[i][4][31:24]) : (base_hdr[i][3][31:24]);
            tag[i]           = {base_hdr[i][1][21:16],base_hdr[i][1][31:24]};
        end else
            // NON FLIT MODE
        begin
            th_bit_is_set[i]                              = base_hdr[i][0][8];
            tc[i]                                         = base_hdr[i][0][14:12];
            attr[i]                                       = {base_hdr[i][0][10],base_hdr[i][0][21:20]};
            has_ohc_a[i]                                  = '0;
            ohc_a_be[i]                                   = '0;
            tag[i][8 +2 -1:0] = { base_hdr[i][0][15],base_hdr[i][0][11], base_hdr[i][1][23:16]};
        end
        length_field[i]            = {base_hdr[i][0][17:16],base_hdr[i][0][31:24]};
        length_field_for_atomic[i] = (np_pkt[i].support.is_atomic_cas && ATOMIC_EN==1) ? {1'b0, length_field[i][9:1]} : length_field[i];
        req_id[i]                  = {base_hdr[i][1][7:0], base_hdr[i][1][15:8]};
        
        case(np_pkt[i].support.np_req_type)
            // For Memory Read Completions, Byte Count[11:0] is set accordingly
            E_NP_REQ_TX_MEMRD_NON_ATS: begin
                // FLIT MODE
                if (cfg_flit_mode_en) begin
                    // TH Bit not existing for flit mode, check if OHC-A exists
                    first_be[i] = !has_ohc_a[i] ? 4'b1111 : ohc_a_be[i][3:0];
                    last_be[i]  = !has_ohc_a[i] ? (length_field[i]==10'd1 ? 4'b0000 : 4'b1111) : ohc_a_be[i][7:4];
                end else
                    // NON FLIT MODE
                begin
                    // for memrd and dmwr, the First DW Byte Enabled and Last DW Byte Enabled is implied if TH bit is set
                    first_be[i] = th_bit_is_set[i] ? 4'b1111 : base_hdr[i][1][27:24];
                    last_be[i]  = th_bit_is_set[i] ? (length_field[i]==10'd1 ? 4'b0000 : 4'b1111) : base_hdr[i][1][31:28];
                end
                length_bytes[i]  = get_length_bytes(length_field[i], first_be[i], last_be[i]);
                low_addr[i][6:2] = base_hdr[i][0][5] ?  base_hdr[i][3][30:26] : base_hdr[i][2][30:26]; // This works only for non-Reserved TLPs in Flit Mode!!
                casez (first_be[i])
                    4'b??10: low_addr[i][1:0] = 2'b01;
                    4'b?100: low_addr[i][1:0] = 2'b10;
                    4'b1000: low_addr[i][1:0] = 2'b11;
                    default: low_addr[i][1:0] = 2'b00;
                endcase
            end

            E_NP_REQ_TX_MEMRD_ATS: begin
                first_be[i]     = 4'b1111; // For FM, this is Reserved and must be assumed 4'b1111; for NFM, this field must be by spec 4'b1111.
                last_be[i]      = 4'b1111; // For FM, this is Reserved and must be assumed 4'b1111; for NFM, this field must be by spec 4'b1111.
                length_bytes[i] = get_length_bytes(length_field[i], first_be[i], last_be[i]);
                low_addr[i]     = 7'd0; // Reserved in both FM and NFM
            end 
            
            // For AtomicOp Completions, the Byte Count value must equal the associated AtomicOp operand size in bytes.
            E_NP_REQ_TX_ATOMIC: begin
                first_be[i]     = 4'b1111;
                last_be[i]      = length_field[i]==10'd1 ? 4'b0000 : 4'b1111;
                length_bytes[i] = get_length_bytes(length_field_for_atomic[i], first_be[i], last_be[i]);
                low_addr[i]     = 7'd0;
            end
            
            // For all other types of Completions, the Byte Count value must be 4.
            default:begin
                length_bytes[i] = 12'd4;
                low_addr[i]     = 7'd0;
            end
        endcase
    end
end


always_comb begin
    c_info     = out_tx_npr;
    out_wakeup = 1'b0;
    for(int i = 0; i < N_XADM_NP_IF; i++)begin
        c_info.valid[i] = np_pkt[i].eot && (!np_pkt[i].bad_eot || CAN_BADEOT==0) && !np_halt[i] ;

        if(np_pkt[i].hv)begin
            c_info.attr[i]        = attr[i];
            c_info.len_bytes[i]   = length_bytes[i];
            c_info.low_addr[i]    = low_addr[i];
            c_info.np_req_type[i] = np_pkt[i].support.np_req_type;
            c_info.req_id[i]      = req_id[i];
            c_info.tag[i]         = tag[i];
            c_info.tc[i]          = tc[i];
        end
        // Assumption:
        // The number of NonPosted Interface in case of AXI is 2*NVC or 1*NVC;
        c_info.cpl_trgt_interface_no[i] = port_idx[i];
        
        out_wakeup |= c_info.valid[i] || out_tx_npr.valid[i];

    end
end

always_ff@(posedge clk or negedge rst_n)begin
    if(!rst_n) out_tx_npr <= #TP '0;
    else       out_tx_npr <= #TP c_info;
end


endmodule

