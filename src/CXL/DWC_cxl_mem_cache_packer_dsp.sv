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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2024/01/19 09:25:58 $
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_packer_dsp.sv#2 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Host Flit Packer
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_packer_dsp 
    import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)(
    input                                       core_clk,                // Core clock
    input                                       core_rst_n,              // Core active low asynchronous reset
    input                                       pack_enable,             // Enable Flit Packer
    input                                       cxl_packer_reverse,      // Reverse Protocol Mode
    input  [511:0]                              cxl_packer_flit,         // Flit on the Packer output
    input                                       cxl_packer_all_data,     // All Data Rollover
    input  [4:0]                                cxl_packer_rollover,     // Data Rollover Counter
    input  [3:0]                                cxl_packer_slot_vld,     // Slot Valid
    input                                       cxl_prot_msg_halt,       // CXL Protocol Message Channel Halt
    input                                       cxl_prot_data_halt,      // CXL Protocol Data Channel Halt
    input                                       cfg_cache_poison_start,  // CachePoisonInjectionStart
    output                                      cfg_cache_poison_busy,   // CachePoisonInjectionBusy
    output [TX_CRDIF_WIDTH-1:0]                 cache_req_vld,           // CXL.cache Request channel valid bit
    output [TX_CRDIF_WIDTH-1:0]                 cache_rsp_vld,           // CXL.cache Response channel valid bit
    output [TX_CRDIF_WIDTH-1:0]                 cache_hdr_vld,           // CXL.cache Data channel valid bit
    output CXL_HDR_t                            cache_hdr,               // CXL.cache Rule Packer Header
    output SLOT_HDR_t                           cache_slot,              // CXL.cache Slot Information
    input                                       cxl_cache_data_ena,      // CXL.cache Data Enable
    input                                       cfg_mem_poison_start,    // MemPoisonInjectionStart
    output                                      cfg_mem_poison_busy,     // MemPoisonInjectionBusy
    output [TX_CRDIF_WIDTH-1:0]                 mem_req_vld,             // CXL.mem Request channel valid bit
    output [TX_CRDIF_WIDTH-1:0]                 mem_hdr_vld,             // CXL.mem Data channel valid bit
    output CXL_HDR_t                            mem_hdr,                 // CXL.mem Rule Packer Header
    output SLOT_HDR_t                           mem_slot,                // CXL.mem Slot Information
    output                                      mem_pending_vld,         // CXL.mem Pending Message
    input                                       cxl_mem_data_ena,        // CXL.mem Data Enable
    output logic                                cxl_tl_pending_o,        // Pending message on the TL Interface
    DWC_cxl_pack_llctrl_if.slave_ctrl_mp        b_llctrl,                // Link Layer Controller to Flit Packer Interface
    DWC_cxl_txtl_llctrl_if.pack_slave_host_mp   b_txtl_llctrl            // Flit Packer to Transaction Layer Interface

);

parameter DUMMY_H2D_REQ    = {H2D_68B_REQ_SIZE{1'b0}};
parameter DUMMY_H2D_RSP    = {H2D_68B_RESP_SIZE{1'b0}};
parameter DUMMY_H2D_HDR    = {H2D_68B_DHDR_SIZE{1'b0}};

// Message Channel Valid Bits and MDH Enable
logic [H2D_68B_REQ_NUM-1:0]     cxl_ch_h2d_req_vld;    // H2D Request Channel Valid Bits
logic [H2D_68B_RESP_NUM-1:0]    cxl_ch_h2d_rsp_vld;    // H2D Response Channel Valid Bits
logic [H2D_68B_DATA_NUM-1:0]    cxl_ch_h2d_hdr_vld;    // H2D Data Header Channel Valid Bits
logic [M2S_68B_NDR_NUM-1:0]     cxl_ch_m2s_req_vld;    // M2S Request Only Channel Valid Bits
logic [M2S_68B_DATA_NUM-1:0]    cxl_ch_m2s_rwd_vld;    // M2S RwD Channel Valid Bits

logic [H2D_68B_REQ_SIZE-1:0]    cxl_h2d_req_msg_s [0:H2D_68B_REQ_NUM-1];  // H2D Request Channel - 64 bits
logic [H2D_68B_RESP_SIZE-1:0]   cxl_h2d_rsp_msg_s [0:H2D_68B_RESP_NUM-1]; // H2D Response Channel - 32 bits
logic [H2D_68B_DHDR_SIZE-1:0]   cxl_h2d_hdr_msg_s [0:H2D_68B_DATA_NUM-1]; // H2D Data Header Channel - 24 bits
logic [H2D_68B_DDATA_SIZE-1:0]  cxl_h2d_data_msg_s;                   // H2D Data - 4x16B
logic [M2S_68B_NDR_SIZE-1:0]    cxl_m2s_req_msg_s [0:M2S_68B_NDR_NUM-1];  // M2S Request with no Data Channel - 87 bits
logic [M2S_68B_DHDR_SIZE-1:0]   cxl_m2s_hdr_msg_s [0:M2S_68B_DATA_NUM-1]; // M2S Request with Data Channel Header - 87 bits
logic [M2S_68B_DDATA_SIZE-1:0]  cxl_m2s_data_msg_s;                   // M2S Data - 4x16B

logic [H2D_68B_REQ_NUM-1:0]     cxl_ch_h2d_req_gnt_halt;     // H2D Request Channel Valid Bits
logic [H2D_68B_RESP_NUM-1:0]    cxl_ch_h2d_rsp_gnt_halt;     // H2D Response Channel Valid Bits
logic [H2D_68B_DATA_NUM-1:0]    cxl_ch_h2d_hdr_gnt_halt;     // H2D Data Header Channel Valid Bits
logic [M2S_68B_NDR_NUM-1:0]     cxl_ch_m2s_req_gnt_halt;     // M2S Request Only Channel Valid Bits
logic [M2S_68B_DATA_NUM-1:0]    cxl_ch_m2s_rwd_gnt_halt;     // M2S RwD Channel Valid Bits

logic [M2S_68B_DATA_NUM-1:0]    cxl_ch_m2s_be;
logic [M2S_68B_DATA_NUM-1:0]    cxl_ch_m2s_rwd_be_vld;
logic                           cxl_mem_mdh_s;       // MDH flag for CXL.mem protocol
logic                           cxl_cache_mdh_s;     // MDH flag for CXL.cache protocol

// Arbitration Signals
logic                       rr_arb_req_rsp_r, rr_arb_req_rsp_nxt;        // Arbitration between CXL.cache Request (H0 and H2) and Data (H1 and H3) slot types on Slot 0
                                                                         // If 1 - selects H1 or H3 slot types, otherwise if 0 - H0 or H2 slot types
logic                       rr_arb_req_rwd_r, rr_arb_req_rwd_nxt;        // Arbitration between CXL.mem Request (H5) and CXL.mem RwD (H4) messages when filling Slots 1-3
                                                                         // If 1 - prioritize CXL.mem Rwd messages, otherwise if 0 - prioritize CXL.mem Request messages

// CXL.cache Table Signals
CXL_HDR_t                   cache_mem_hdr_s;     // CXL.cache Rule Packer Header
SLOT_HDR_t                  cache_mem_slot_s;    // CXL.cache Slot Information

// CXL.mem Table Signals
CXL_HDR_t                   mem_cache_hdr_s;     // CXL.mem Rule Packer Header
SLOT_HDR_t                  mem_cache_slot_s;    // CXL.mem Slot Information
CXL_HDR_t                   cxl_flit_hdr_s;      // Slot Mapping Flit Header

// Channel Halt Generation Signals
logic                       cxl_prot_msg_halt_s;          // CXL Protocol Message Channel Halt
logic                       cxl_prot_data_halt_s;         // CXL Protocol Data Channel Halt - d2h_data and s2m_data


assign cxl_flit_hdr_s  = cxl_packer_flit[31:0];

assign cxl_ch_m2s_be = { !cxl_ch_m2s_rwd_vld[0] | (b_txtl_llctrl.s_cxl_m2s_be_vld_n[0]) };
assign cxl_ch_m2s_rwd_be_vld = { cxl_ch_m2s_rwd_vld[0] };

// If MDH is not disabled and all bytes are enabled on the channels where S2M Data Header message is valid
// then set MDH flag for CXL.mem protocol
assign cxl_mem_mdh_s   = 1'b0;//b_llctrl.s_cxl_ll_mem_mdh_en & (&cxl_ch_m2s_rwd_be_vld[1:0]);

// If MDH is not disabled then set MDH flag for CXL.cache protocol. Please not that Byte Enable bits are not
// applicable for CXL.cache data
assign cxl_cache_mdh_s = b_llctrl.s_cxl_ll_cache_mdh_en & (&cxl_ch_h2d_hdr_vld[1:0]);

assign mem_pending_vld = cxl_m2s_req_msg_s[0][0] || cxl_m2s_hdr_msg_s[0][0];


// -------------------------------------------------------------------------------------
// CXL.Cache/Mem Poison Mode
// -------------------------------------------------------------------------------------
logic cfg_cache_poison_start_r;
logic cfg_cache_poison_r, cfg_cache_poison_nxt;

assign cfg_cache_poison_busy = pack_enable && cfg_cache_poison_r;

always_comb begin
    if (cfg_cache_poison_start && !cfg_cache_poison_start_r && !cfg_cache_poison_r) begin
        cfg_cache_poison_nxt = 1'b1;
    end
    else if (cfg_cache_poison_r && cxl_h2d_hdr_msg_s[0][H2D_HDR_VLD] && !b_txtl_llctrl.s_cxl_h2d_hdr_halt[0]) begin
        cfg_cache_poison_nxt = 1'b0;
    end
    else begin
        cfg_cache_poison_nxt = cfg_cache_poison_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cfg_cache_poison_start_r <= #TP 1'b0;
        cfg_cache_poison_r       <= #TP 1'b0;
    end
    else begin
        cfg_cache_poison_start_r <= #TP cfg_cache_poison_start;
        cfg_cache_poison_r       <= #TP cfg_cache_poison_nxt;
    end
end

logic cfg_mem_poison_start_r;
logic cfg_mem_poison_r, cfg_mem_poison_nxt;

assign cfg_mem_poison_busy = pack_enable && cfg_mem_poison_r;

always_comb begin
    if (cfg_mem_poison_start && !cfg_mem_poison_start_r && !cfg_mem_poison_r) begin
        cfg_mem_poison_nxt = 1'b1;
    end
    else if (cfg_mem_poison_r && cxl_m2s_hdr_msg_s[0][M2S_HDR_VLD] && !b_txtl_llctrl.s_cxl_m2s_hdr_halt[0]) begin
        cfg_mem_poison_nxt = 1'b0;
    end
    else begin
        cfg_mem_poison_nxt = cfg_mem_poison_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cfg_mem_poison_start_r <= #TP 1'b0;
        cfg_mem_poison_r       <= #TP 1'b0;
    end
    else begin
        cfg_mem_poison_start_r <= #TP cfg_mem_poison_start;
        cfg_mem_poison_r       <= #TP cfg_mem_poison_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Gate valid channel messages if not enough credits are granted for a given channel.
// Assert halt signal for those channels.
// -------------------------------------------------------------------------------------
logic [H2D_68B_DATA_NUM:0] cxl_ll_cache_data_en;
logic [M2S_68B_DATA_NUM:0] cxl_ll_mem_data_en;

assign cxl_tl_pending_o = 1'b0    || b_txtl_llctrl.s_cxl_h2d_req[0][H2D_REQ_VLD] || b_txtl_llctrl.s_cxl_h2d_rsp[0][H2D_RESP_VLD] || b_txtl_llctrl.s_cxl_h2d_hdr[0][H2D_HDR_VLD]
    || b_txtl_llctrl.s_cxl_m2s_req[0][M2S_NDR_VLD] || b_txtl_llctrl.s_cxl_m2s_hdr[0][M2S_HDR_VLD]
 ;

always_comb begin
    // If Rollover Counter is equal to 3, it is expected that the next flit will be all data flit hence
    // flit packer should capture the number of headers equal (num_free_buff - 1)
    cxl_ll_cache_data_en = b_llctrl.s_cxl_ll_packer_data_en[H2D_68B_DATA_NUM:0] >> ((cxl_packer_rollover == 5'd3) ? 1 : 0);

    for (int i = 0; i < H2D_68B_REQ_NUM; i++)  begin
        cxl_h2d_req_msg_s[i] = b_llctrl.s_cxl_ll_cache_req_gnt[i] ? b_txtl_llctrl.s_cxl_h2d_req[i][H2D_68B_REQ_SIZE-1:0] : '0;
        cxl_ch_h2d_req_gnt_halt[i] = ~b_llctrl.s_cxl_ll_cache_req_gnt[i] & b_txtl_llctrl.s_cxl_h2d_req[i][H2D_REQ_VLD];
    end
    for (int i = 0; i < H2D_68B_RESP_NUM; i++) begin
        cxl_h2d_rsp_msg_s[i] = b_llctrl.s_cxl_ll_cache_rsp_gnt[i] ? b_txtl_llctrl.s_cxl_h2d_rsp[i][H2D_68B_RESP_SIZE-1:0] : '0;
        cxl_ch_h2d_rsp_gnt_halt[i] = ~b_llctrl.s_cxl_ll_cache_rsp_gnt[i] & b_txtl_llctrl.s_cxl_h2d_rsp[i][H2D_RESP_VLD];
    end
    for (int i = 0; i < H2D_68B_DATA_NUM; i++) begin
        cxl_h2d_hdr_msg_s[i] = (b_llctrl.s_cxl_ll_cache_data_gnt[i] & cxl_ll_cache_data_en[i] & b_txtl_llctrl.s_cxl_h2d_data_vld[0]) ? b_txtl_llctrl.s_cxl_h2d_hdr[i][H2D_68B_DHDR_SIZE-1:0] : '0;
        cxl_ch_h2d_hdr_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_cache_data_gnt[i] & cxl_ll_cache_data_en[i] & b_txtl_llctrl.s_cxl_h2d_data_vld[0]) & b_txtl_llctrl.s_cxl_h2d_hdr[i][H2D_HDR_VLD];
    end
    // Overwrite Poison Bit
    cxl_h2d_hdr_msg_s[0][H2D_68B_POISON_BIT] = cxl_h2d_hdr_msg_s[0][H2D_HDR_VLD] ? (b_txtl_llctrl.s_cxl_h2d_hdr[0][H2D_68B_POISON_BIT] | cfg_cache_poison_r) : 1'b0;
    cxl_h2d_data_msg_s = b_txtl_llctrl.s_cxl_h2d_data[0];
    // If Rollover Counter is equal to 3, it is expected that the next flit will be all data flit hence
    // flit packer should capture the number of headers equal (num_free_buff - 1)
    // As M2S data message has a ByteEnable then the situation when Rollover Counter is equal 2 and BE is enable
    // it is expected that the next flit is also ADF flit
    cxl_ll_mem_data_en = b_llctrl.s_cxl_ll_packer_data_en[M2S_68B_DATA_NUM:0] >> (((cxl_packer_rollover == 5'd3) || ((cxl_packer_rollover == 5'd2) && !(&b_txtl_llctrl.s_cxl_m2s_be[0]))) ? 1 : 0);

    for (int i = 0; i < M2S_68B_NDR_NUM; i++) begin
        cxl_m2s_req_msg_s[i] = b_llctrl.s_cxl_ll_mem_ndr_gnt[i] ? b_txtl_llctrl.s_cxl_m2s_req[i][M2S_68B_NDR_SIZE-1:0] : '0;
        cxl_ch_m2s_req_gnt_halt[i] = ~b_llctrl.s_cxl_ll_mem_ndr_gnt[i] & b_txtl_llctrl.s_cxl_m2s_req[i][M2S_NDR_VLD];
    end
    for (int i = 0; i < M2S_68B_DATA_NUM; i++) begin
        cxl_m2s_hdr_msg_s[i] = (b_llctrl.s_cxl_ll_mem_dr_gnt[i] & cxl_ll_mem_data_en[i] & b_txtl_llctrl.s_cxl_m2s_data_vld[0]) ? b_txtl_llctrl.s_cxl_m2s_hdr[i][M2S_68B_DHDR_SIZE-1:0] : '0;
        cxl_ch_m2s_rwd_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_mem_dr_gnt[i] & cxl_ll_mem_data_en[i] & b_txtl_llctrl.s_cxl_m2s_data_vld[0]) & b_txtl_llctrl.s_cxl_m2s_hdr[i][M2S_HDR_VLD];
    end
    // Overwrite Poison Bit
    cxl_m2s_hdr_msg_s[0][M2S_68B_POISON_BIT] = cxl_m2s_hdr_msg_s[0][M2S_HDR_VLD] ? (b_txtl_llctrl.s_cxl_m2s_hdr[0][M2S_68B_POISON_BIT] | cfg_mem_poison_r) : 1'b0;
    cxl_m2s_data_msg_s = b_txtl_llctrl.s_cxl_m2s_data[0];
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Extarct channel message valid bits
// -------------------------------------------------------------------------------------
always_comb begin
    for (int i = 0; i < H2D_68B_REQ_NUM; i++)  cxl_ch_h2d_req_vld[i] = cxl_h2d_req_msg_s[i][H2D_REQ_VLD];
    for (int i = 0; i < H2D_68B_RESP_NUM; i++) cxl_ch_h2d_rsp_vld[i] = cxl_h2d_rsp_msg_s[i][H2D_RESP_VLD];
    for (int i = 0; i < H2D_68B_DATA_NUM; i++) cxl_ch_h2d_hdr_vld[i] = cxl_h2d_hdr_msg_s[i][H2D_HDR_VLD];
    for (int i = 0; i < M2S_68B_NDR_NUM; i++)  cxl_ch_m2s_req_vld[i] = cxl_m2s_req_msg_s[i][M2S_NDR_VLD];
    for (int i = 0; i < M2S_68B_DATA_NUM; i++) cxl_ch_m2s_rwd_vld[i] = cxl_m2s_hdr_msg_s[i][M2S_HDR_VLD];
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Generate valid signals for credit tracking
// -------------------------------------------------------------------------------------
assign cache_req_vld  = {{(TX_CRDIF_WIDTH-H2D_68B_REQ_NUM){1'b0}} , cxl_ch_h2d_req_vld & ~b_txtl_llctrl.s_cxl_h2d_req_halt[H2D_68B_REQ_NUM  - 1: 0]};
assign cache_rsp_vld  = {{(TX_CRDIF_WIDTH-H2D_68B_RESP_NUM){1'b0}}, cxl_ch_h2d_rsp_vld & ~b_txtl_llctrl.s_cxl_h2d_rsp_halt[H2D_68B_RESP_NUM - 1: 0]};
assign cache_hdr_vld  = {{(TX_CRDIF_WIDTH-H2D_68B_DATA_NUM){1'b0}}, cxl_ch_h2d_hdr_vld & ~b_txtl_llctrl.s_cxl_h2d_hdr_halt[H2D_68B_DATA_NUM - 1: 0]};
assign mem_req_vld    = {{(TX_CRDIF_WIDTH-M2S_68B_NDR_NUM){1'b0}} , cxl_ch_m2s_req_vld & ~b_txtl_llctrl.s_cxl_m2s_req_halt[M2S_68B_NDR_NUM  - 1:0]};
assign mem_hdr_vld    = {{(TX_CRDIF_WIDTH-M2S_68B_DATA_NUM){1'b0}}, cxl_ch_m2s_rwd_vld & ~b_txtl_llctrl.s_cxl_m2s_hdr_halt[M2S_68B_DATA_NUM - 1:0]};
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL.cache Packing Rules
// -------------------------------------------------------------------------------------
//
// MSG_PRIORITY - REQUEST (0) OR RESP/DATA (1)
//
// -------------------------------------------------------------------------------------
always_comb begin
    cache_hdr  = '0;
    cache_slot = '0;
    
    cache_hdr.ProtType    = CXL_HDR_PROT;
    cache_hdr.BE      = 1'b0;
    cache_hdr.Sz      = 1'b1;
    cache_hdr.Ack     = b_llctrl.s_cxl_hdr_ack_bit;
    cache_hdr.ReqCrd  = b_llctrl.s_cxl_hdr_req_crd;
    cache_hdr.RspCrd  = b_llctrl.s_cxl_hdr_rsp_crd;
    cache_hdr.DataCrd = b_llctrl.s_cxl_hdr_data_crd;

    casez ({rr_arb_req_rsp_r, cxl_cache_mdh_s, cxl_ch_h2d_hdr_vld, cxl_ch_h2d_rsp_vld, cxl_ch_h2d_req_vld})
        // IF (MSG_PRIORITY == 0) && (H2D REQ = 2) && (H2D RESP > 0) && (H2D DATA > 0)
        12'b0_?_???1_???1_11: begin
            // RULE FORMAT: H0-G2-G0-G0
            cache_hdr.Slot0 = CXL_HDR_SLOT_H0;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G2;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot3 = CXL_HDR_SLOT_G0;

            // H0 -  H2D_REQ H2D_RSP 
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_rsp_msg_s[0], cxl_h2d_req_msg_s[0], cache_hdr}};
            // G2 -  H2D_REQ H2D_DATA H2D_RSP 
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd1, Slot:{8'd0, cxl_h2d_rsp_msg_s[1], cxl_h2d_hdr_msg_s[0], cxl_h2d_req_msg_s[1]}};
            // G0 -  DATA 
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[127:0]}};
            // G0 -  DATA 
            cache_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[255:128]}};
        end
        // IF (MSG_PRIORITY == 0) && (H2D REQ = 2) && (H2D RESP > 2) && (H2D DATA = 0)
        12'b0_?_???0_?111_11: begin
            // RULE FORMAT: H0-G2-G1-NA
            cache_hdr.Slot0 = CXL_HDR_SLOT_H0;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G2;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot1;

            cache_hdr.BE = cache_mem_hdr_s.BE;
            
            // H0 -  H2D_REQ H2D_RSP 
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_rsp_msg_s[0], cxl_h2d_req_msg_s[0], cache_hdr}};
            // G2 -  H2D_REQ H2D_DATA H2D_RSP 
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{8'd0, cxl_h2d_rsp_msg_s[1], cxl_h2d_hdr_msg_s[0], cxl_h2d_req_msg_s[1]}};
            // G1 -  H2D_RSP H2D_RSP H2D_RSP H2D_RSP 
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{DUMMY_H2D_RSP, DUMMY_H2D_RSP, cxl_h2d_rsp_msg_s[3], cxl_h2d_rsp_msg_s[2]}};
            // CACHE - CXL.cache Slots
            cache_slot.Slot3 = cache_mem_slot_s.Slot1;
        end
        // IF (MSG_PRIORITY == 0) && (H2D REQ = 2) && (H2D RESP <= 2) && (H2D DATA = 0)
        // IF (MSG_PRIORITY == 1) && (H2D REQ = 2) && (H2D RESP <  2) && (H2D DATA = 0)
        12'b0_?_???0_00??_11, 12'b1_?_???0_000?_11: begin
            // RULE FORMAT: H0-G2-NA-NA
            cache_hdr.Slot0 = CXL_HDR_SLOT_H0;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G2;
            cache_hdr.Slot2 = cache_mem_hdr_s.Slot1;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot2;

            cache_hdr.BE = cache_mem_hdr_s.BE;
            
            // H0 -  H2D_REQ H2D_RSP 
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_rsp_msg_s[0], cxl_h2d_req_msg_s[0], cache_hdr}};
            // G2 -  H2D_REQ H2D_DATA H2D_RSP 
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{8'd0, cxl_h2d_rsp_msg_s[1], cxl_h2d_hdr_msg_s[0], cxl_h2d_req_msg_s[1]}};
            // CACHE - CXL.cache Slots
            cache_slot.Slot2 = cache_mem_slot_s.Slot1;
            // CACHE - CXL.cache Slots
            cache_slot.Slot3 = cache_mem_slot_s.Slot2;
        end
        // IF (MSG_PRIORITY == 0) && (H2D REQ = 1) && (H2D RESP > 0) && (H2D DATA > 0) && MDH
        12'b0_1_??11_???1_01: begin
            // RULE FORMAT: H0-G3-G0-G0
            cache_hdr.Slot0 = CXL_HDR_SLOT_H0;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G3;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot3 = CXL_HDR_SLOT_G0;

            // H0 -  H2D_REQ H2D_RSP 
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_rsp_msg_s[0], cxl_h2d_req_msg_s[0], cache_hdr}};
            // G3 -  H2D_DATA H2D_DATA H2D_DATA H2D_DATA H2D_RSP 
            cache_slot.Slot1 = '{Valid:1'b1, Data:cxl_ch_h2d_hdr_vld, Slot:{cxl_h2d_rsp_msg_s[1], cxl_h2d_hdr_msg_s[3], cxl_h2d_hdr_msg_s[2], cxl_h2d_hdr_msg_s[1], cxl_h2d_hdr_msg_s[0]}};
            // G0 -  DATA 
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[127:0]}};
            // G0 -  DATA 
            cache_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[255:128]}};
        end
        // IF (MSG_PRIORITY == 0) && (H2D REQ = 1) && (H2D RESP > 0) && (H2D DATA > 0) && !MDH
        12'b0_0_???1_???1_01: begin
            // RULE FORMAT: H0-G2-G0-G0
            cache_hdr.Slot0 = CXL_HDR_SLOT_H0;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G2;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot3 = CXL_HDR_SLOT_G0;

            // H0 -  H2D_REQ H2D_RSP 
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_rsp_msg_s[0], cxl_h2d_req_msg_s[0], cache_hdr}};
            // G2 -  H2D_REQ H2D_DATA H2D_RSP 
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd1, Slot:{8'd0, cxl_h2d_rsp_msg_s[1], cxl_h2d_hdr_msg_s[0], cxl_h2d_req_msg_s[1]}};
            // G0 -  DATA 
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[127:0]}};
            // G0 -  DATA 
            cache_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[255:128]}};
        end
        // IF (MSG_PRIORITY == 0) && (H2D REQ = 1) && (H2D RESP > 1) && (H2D DATA = 0)
        12'b0_?_???0_??11_01: begin
            // RULE FORMAT: H0-G1-NA-NA
            cache_hdr.Slot0 = CXL_HDR_SLOT_H0;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot2 = cache_mem_hdr_s.Slot1;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot2;
            
            cache_hdr.BE = cache_mem_hdr_s.BE;

            // H0 -  H2D_REQ H2D_RSP 
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_rsp_msg_s[0], cxl_h2d_req_msg_s[0], cache_hdr}};
            // G1 -  H2D_RSP H2D_RSP H2D_RSP H2D_RSP 
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{DUMMY_H2D_RSP, cxl_h2d_rsp_msg_s[3], cxl_h2d_rsp_msg_s[2], cxl_h2d_rsp_msg_s[1]}};
            // CACHE - CXL.cache Slots
            cache_slot.Slot2 = cache_mem_slot_s.Slot1;
            // CACHE - CXL.cache Slots
            cache_slot.Slot3 = cache_mem_slot_s.Slot2;
        end
        // IF (MSG_PRIORITY == 0) && (H2D REQ = 1) && (H2D RESP < 2) && (H2D DATA = 0)
        // IF (MSG_PRIORITY == 1) && (H2D REQ = 1) && (H2D RESP < 2) && (H2D DATA = 0)
        12'b0_?_???0_000?_01, 12'b1_?_???0_000?_01: begin
            // RULE FORMAT: H0-NA-NA-NA
            cache_hdr.Slot0 = CXL_HDR_SLOT_H0;
            cache_hdr.Slot1 = cache_mem_hdr_s.Slot1;
            cache_hdr.Slot2 = cache_mem_hdr_s.Slot2;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot3;
            
            cache_hdr.BE = cache_mem_hdr_s.BE;            

            // H0 -  H2D_REQ H2D_RSP 
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_rsp_msg_s[0], cxl_h2d_req_msg_s[0], cache_hdr}};
            // CACHE - CXL.cache Slots
            cache_slot.Slot1 = cache_mem_slot_s.Slot1;
            // CACHE - CXL.cache Slots
            cache_slot.Slot2 = cache_mem_slot_s.Slot2;
            // CACHE - CXL.cache Slots
            cache_slot.Slot3 = cache_mem_slot_s.Slot3;
        end
        // IF (MSG_PRIORITY == 0) && (H2D REQ > 0) && (H2D RESP = 0) && (H2D DATA > 0)
        12'b0_?_???1_???0_?1: begin
            // RULE FORMAT: H2-G0-G0-G0
            cache_hdr.Slot0 = CXL_HDR_SLOT_H2;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot3 = CXL_HDR_SLOT_G0;

            // H2 -  H2D_REQ H2D_DATA 
            cache_slot.Slot0 = '{Valid:1'b1, Data:{3'd0, cxl_ch_h2d_hdr_vld[0]}, Slot:{8'd0, cxl_h2d_hdr_msg_s[0], cxl_h2d_req_msg_s[0], cache_hdr}};
            // G0 -  DATA 
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[127:0]}};
            // G0 -  DATA 
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[255:128]}};
            // G0 -  DATA 
            cache_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[383:256]}};
        end
        
        // IF (MSG_PRIORITY == 0) && (H2D REQ = 0) && (H2D RESP = 0) && (H2D DATA > 0) && MDH
        // IF (MSG_PRIORITY == 1) && (H2D REQ = X) && (H2D RESP = 0) && (H2D DATA > 0) && MDH
        12'b1_1_??11_???0_??, 12'b0_1_??11_???0_?0: begin
            // RULE FORMAT: H3-G0-G0-G0
            cache_hdr.Slot0 = CXL_HDR_SLOT_H3;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot3 = CXL_HDR_SLOT_G0;

            // H3 -  H2D_DATA H2D_DATA H2D_DATA H2D_DATA 
            cache_slot.Slot0 = '{Valid:1'b1, Data:cxl_ch_h2d_hdr_vld, Slot:{cxl_h2d_hdr_msg_s[3], cxl_h2d_hdr_msg_s[2], cxl_h2d_hdr_msg_s[1], cxl_h2d_hdr_msg_s[0], cache_hdr}};
            // G0 -  DATA 
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[127:0]}};
            // G0 -  DATA 
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[255:128]}};
            // G0 -  DATA 
            cache_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[383:256]}};
        end
        // IF (MSG_PRIORITY == 1) && (H2D REQ = X) && (H2D RESP = 0) && (H2D DATA > 0) && MDH
        12'b1_0_???1_???0_??, 12'b0_0_???1_???0_?0: begin
            // RULE FORMAT: H2-G0-G0-G0
            cache_hdr.Slot0 = CXL_HDR_SLOT_H2;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot3 = CXL_HDR_SLOT_G0;

            // H2 -  H2D_REQ H2D_DATA 
            cache_slot.Slot0 = '{Valid:1'b1, Data:{3'd0, cxl_ch_h2d_hdr_vld[0]}, Slot:{8'd0, cxl_h2d_hdr_msg_s[0], cxl_h2d_req_msg_s[0], cache_hdr}};
            // G0 -  DATA 
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[127:0]}};
            // G0 -  DATA 
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[255:128]}};
            // G0 -  DATA 
            cache_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[383:256]}};
        end
        // IF (MSG_PRIORITY == 1) && (H2D REQ = X) && (H2D RESP > 0) && (H2D DATA > 0)
        12'b1_?_???1_???1_??, 12'b0_?_???1_???1_?0: begin
            // RULE FORMAT: H1-G0-G0-G0
            cache_hdr.Slot0 = CXL_HDR_SLOT_H1;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot3 = CXL_HDR_SLOT_G0;

            // H1 -  H2D_DATA H2D_RSP H2D_RSP 
            cache_slot.Slot0 = '{Valid:1'b1, Data:{3'd0, cxl_ch_h2d_hdr_vld[0]}, Slot:{8'd0, cxl_h2d_rsp_msg_s[1], cxl_h2d_rsp_msg_s[0], cxl_h2d_hdr_msg_s[0], cache_hdr}};
            // G0 -  DATA 
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[127:0]}};
            // G0 -  DATA 
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[255:128]}};
            // G0 -  DATA 
            cache_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[383:256]}};
        end
        // IF (MSG_PRIORITY == X) && (H2D REQ = 0) && (H2D RESP > 0) && (H2D RESP <= 2) && (H2D DATA = 0)
        12'b?_?_???0_00?1_?0: begin
            // RULE FORMAT: H1-NA-NA-NA
            cache_hdr.Slot0 = CXL_HDR_SLOT_H1;
            cache_hdr.Slot1 = cache_mem_hdr_s.Slot1;
            cache_hdr.Slot2 = cache_mem_hdr_s.Slot2;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot3;

            cache_hdr.BE = cache_mem_hdr_s.BE;
            
            // H1 -  H2D_DATA H2D_RSP H2D_RSP 
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{8'd0, cxl_h2d_rsp_msg_s[1], cxl_h2d_rsp_msg_s[0], cxl_h2d_hdr_msg_s[0], cache_hdr}};
            // CACHE - CXL.cache Slots
            cache_slot.Slot1 = cache_mem_slot_s.Slot1;
            // CACHE - CXL.cache Slots
            cache_slot.Slot2 = cache_mem_slot_s.Slot2;
            // CACHE - CXL.cache Slots
            cache_slot.Slot3 = cache_mem_slot_s.Slot3;
        end
        // IF (MSG_PRIORITY == X) && (H2D REQ = 0) && (H2D RESP > 2) && (H2D DATA = 0)
        12'b?_?_???0_?111_?0: begin
            // RULE FORMAT: H1-G1-NA-NA
            cache_hdr.Slot0 = CXL_HDR_SLOT_H1;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot2 = cache_mem_hdr_s.Slot1;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot2;

            cache_hdr.BE = cache_mem_hdr_s.BE;
            
            // H1 -  H2D_DATA H2D_RSP H2D_RSP 
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{8'd0, cxl_h2d_rsp_msg_s[1], cxl_h2d_rsp_msg_s[0], cxl_h2d_hdr_msg_s[0], cache_hdr}};
            // G1 -  H2D_RSP H2D_RSP H2D_RSP H2D_RSP 
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{DUMMY_H2D_RSP, DUMMY_H2D_RSP, cxl_h2d_rsp_msg_s[3], cxl_h2d_rsp_msg_s[2]}};
            // CACHE - CXL.cache Slots
            cache_slot.Slot2 = cache_mem_slot_s.Slot1;
            // CACHE - CXL.cache Slots
            cache_slot.Slot3 = cache_mem_slot_s.Slot2;
        end
        // IF (MSG_PRIORITY == 1) && (H2D REQ = 1) && (H2D RESP > 1) && (H2D RESP < 4) && (H2D DATA = 0)
        12'b1_?_???0_0?11_01: begin
            // RULE FORMAT: H1-G2-NA-NA
            cache_hdr.Slot0 = CXL_HDR_SLOT_H1;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G2;
            cache_hdr.Slot2 = cache_mem_hdr_s.Slot1;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot2;

            cache_hdr.BE = cache_mem_hdr_s.BE;
            
            // H1 -  H2D_DATA H2D_RSP H2D_RSP 
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{8'd0, cxl_h2d_rsp_msg_s[1], cxl_h2d_rsp_msg_s[0], cxl_h2d_hdr_msg_s[0], cache_hdr}};
            // G2 -  H2D_REQ H2D_DATA H2D_RSP 
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{8'd0, cxl_h2d_rsp_msg_s[2], cxl_h2d_hdr_msg_s[0], cxl_h2d_req_msg_s[0]}};
            // CACHE - CXL.cache Slots
            cache_slot.Slot2 = cache_mem_slot_s.Slot1;
            // CACHE - CXL.cache Slots
            cache_slot.Slot3 = cache_mem_slot_s.Slot2;
        end
        // IF (MSG_PRIORITY == 1) && (H2D REQ = 2) && (H2D RESP > 1) && (H2D DATA = 0)
        // IF (MSG_PRIORITY == 1) && (H2D REQ = 1) && (H2D RESP = 4) && (H2D DATA = 0)
        12'b1_?_???0_??11_11, 12'b1_?_???0_1111_01: begin
            // RULE FORMAT: H1-G2-G2-NA
            cache_hdr.Slot0 = CXL_HDR_SLOT_H1;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G2;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G2;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot1;

            cache_hdr.BE = cache_mem_hdr_s.BE;
            
            // H1 -  H2D_DATA H2D_RSP H2D_RSP 
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{8'd0, cxl_h2d_rsp_msg_s[1], cxl_h2d_rsp_msg_s[0], cxl_h2d_hdr_msg_s[0], cache_hdr}};
            // G2 -  H2D_REQ H2D_DATA H2D_RSP 
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{8'd0, cxl_h2d_rsp_msg_s[2], cxl_h2d_hdr_msg_s[0], cxl_h2d_req_msg_s[0]}};
            // G2 -  H2D_REQ H2D_DATA H2D_RSP 
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{8'd0, cxl_h2d_rsp_msg_s[3], cxl_h2d_hdr_msg_s[0], cxl_h2d_req_msg_s[1]}};
            // CACHE - CXL.cache Slots
            cache_slot.Slot3 = cache_mem_slot_s.Slot1;
        end
        default: begin
            // NA-NA-NA-NA
            cache_hdr.Slot0 = CXL_HDR_SLOT_0_t'('0);
            cache_hdr.Slot1 = cache_mem_hdr_s.Slot1;//CXL_HDR_SLOT_N_t'('0);
            cache_hdr.Slot2 = cache_mem_hdr_s.Slot2;//CXL_HDR_SLOT_N_t'('0);
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot3;//CXL_HDR_SLOT_N_t'('0);
            
            cache_slot = SLOT_HDR_t'('0);
        end
    endcase
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL.cache MEM Packing Rules
// -------------------------------------------------------------------------------------
//
// [TRY TO FIT MEM MESSAGES]
//
// -------------------------------------------------------------------------------------
always_comb begin
    cache_mem_hdr_s  = '{ Slot0:CXL_HDR_SLOT_H5, Slot1:CXL_HDR_SLOT_G5, Slot2:CXL_HDR_SLOT_G5, Slot3:CXL_HDR_SLOT_G5, ProtType: CXL_HDR_PROT, default: '0};
    cache_mem_slot_s = '0;
    casez ({cxl_ch_m2s_req_vld, cxl_ch_m2s_rwd_vld})
        // IF (M2S REQ = 1) && (M2S DATA > 0)
        3'b011: begin
            // RULE FORMAT: G4-G5-G0
            cache_mem_hdr_s.Slot1 = CXL_HDR_SLOT_G4;
            cache_mem_hdr_s.Slot2 = CXL_HDR_SLOT_G5;
            cache_mem_hdr_s.Slot3 = CXL_HDR_SLOT_G0;

            cache_mem_hdr_s.BE    = ~cxl_ch_m2s_be[0];
            
            // G4 -  M2S_REQ H2D_DATA 
            cache_mem_slot_s.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{16'd0, DUMMY_H2D_HDR, 1'b0, cxl_m2s_req_msg_s[0]}};
            // G5 -  M2S_DATA H2D_RSP 
            cache_mem_slot_s.Slot2 = '{Valid:1'b1, Data:{3'd0, cxl_ch_m2s_rwd_vld}, Slot:{8'd0, DUMMY_H2D_RSP, 1'b0, cxl_m2s_hdr_msg_s[0]}};
            // G0 -  DATA 
            cache_mem_slot_s.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_m2s_data_msg_s[127:0]}};
        end
        // IF (M2S REQ = 0) && (M2S DATA > 0)
        3'b001: begin
            // RULE FORMAT: G5-G0-G0
            cache_mem_hdr_s.Slot1 = CXL_HDR_SLOT_G5;
            cache_mem_hdr_s.Slot2 = CXL_HDR_SLOT_G0;
            cache_mem_hdr_s.Slot3 = CXL_HDR_SLOT_G0;

            cache_mem_hdr_s.BE    = ~cxl_ch_m2s_be[0];
            
            // G5 -  M2S_DATA H2D_RSP 
            cache_mem_slot_s.Slot1 = '{Valid:1'b1, Data:{3'd0, cxl_ch_m2s_rwd_vld}, Slot:{8'd0, DUMMY_H2D_RSP, 1'b0, cxl_m2s_hdr_msg_s[0]}};
            // G0 - CXL.mem DRS Data
            cache_mem_slot_s.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_m2s_data_msg_s[127:0]};
            // G0 - CXL.mem DRS Data
            cache_mem_slot_s.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_m2s_data_msg_s[255:128]};
        end
        default: begin
            // RULE FORMAT: G4-G4-G5
            cache_mem_hdr_s.Slot1 = CXL_HDR_SLOT_G4;
            cache_mem_hdr_s.Slot2 = CXL_HDR_SLOT_G4;
            cache_mem_hdr_s.Slot3 = CXL_HDR_SLOT_G5;

            cache_mem_hdr_s.BE    = ~cxl_ch_m2s_be[0];

            // G4 -  M2S_REQ H2D_DATA 
            cache_mem_slot_s.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{16'd0, DUMMY_H2D_HDR, 1'b0, cxl_m2s_req_msg_s[0]}};
            // G4 -  M2S_REQ H2D_DATA 
            cache_mem_slot_s.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{16'd0, DUMMY_H2D_HDR, 1'b0, cxl_m2s_req_msg_s[1]}};
            // G5 -  M2S_DATA H2D_RSP 
            cache_mem_slot_s.Slot3 = '{Valid:1'b1, Data:{3'd0, cxl_ch_m2s_rwd_vld}, Slot:{8'd0, DUMMY_H2D_RSP, 1'b0, cxl_m2s_hdr_msg_s[0]}};
        end
    endcase
end
// -------------------------------------------------------------------------------------



// -------------------------------------------------------------------------------------
// CXL.mem Packing Rules
// -------------------------------------------------------------------------------------
//
// MSG PRIORITY - M2S REQUEST (0) , M2S DATA (1)
// 
// IF (M2S REQ > 0) && ((MSG_PRIORITY == 0) || (M2S DATA = 0)) BEGIN
//     SLOT0 = H5
//     IF (M2S REQ > 1) BEGIN
//         SLOT1 = G4
//         IF (H2D DATA > 0) BEGIN // H5-G4-G0-G0
//             SLOT2 = G0
//             SLOT3 = G0
//         END
//         ELSE BEGIN
//             IF (M2S DATA > 0) BEGIN // H5-G4-G5-G0
//             ELSE [TRY TO FIT CACHE MESSAGES] // H5-G4-NA-NA
//         END
//     END
//     ELSE BEGIN
//         IF (M2S DATA > 0) BEGIN // H5-G5-G0-G0
//         ELSE [TRY TO FIT CACHE MESSAGES] // H5-NA-NA-NA
//     END
// END
// ELSE IF (M2S DATA > 0) && ((MSG_PRIORITY == 1) || (M2S REQ = 0)) BEGIN // H4-G0-G0-G0
//     SLOT0 = H4
//     SLOT1 = G0
//     SLOT2 = G0
//     SLOT3 = G0
// END
// ELSE [CACHE PRIORITY]
//
// -------------------------------------------------------------------------------------
logic cxl_ch_h2d_hdr_vld_s;

always_comb begin
    mem_hdr  = '0;
    mem_slot = SLOT_HDR_t'('0);
    
    mem_hdr.ProtType = CXL_HDR_PROT;
    mem_hdr.ProtRev  = cxl_packer_reverse;
    mem_hdr.BE       = 1'b0;
    mem_hdr.Sz       = 1'b1;
    mem_hdr.Ack      = b_llctrl.s_cxl_hdr_ack_bit;
    mem_hdr.RevCrd   = cxl_packer_reverse;
    mem_hdr.ReqCrd   = b_llctrl.s_cxl_hdr_req_crd;
    mem_hdr.RspCrd   = b_llctrl.s_cxl_hdr_rsp_crd;
    mem_hdr.DataCrd  = b_llctrl.s_cxl_hdr_data_crd;

    cxl_ch_h2d_hdr_vld_s = cxl_ch_h2d_hdr_vld[0];

    casez ({rr_arb_req_rwd_r, cxl_ch_m2s_req_vld, cxl_ch_m2s_rwd_vld, cxl_ch_h2d_hdr_vld_s})
        // IF (MSG_PRIORITY == 0) && (M2S REQ = 0) && (M2S DATA > 0)
        // IF (MSG_PRIORITY == 1) && (M2S REQ = X) && (M2S DATA > 0)
        5'b1_??_1_?, 5'b0_?0_1_?: begin
            // RULE FORMAT: H4-G0-G0-G0
            mem_hdr.Slot0 = CXL_HDR_SLOT_H4;
            mem_hdr.Slot1 = CXL_HDR_SLOT_G0;
            mem_hdr.Slot2 = CXL_HDR_SLOT_G0;
            mem_hdr.Slot3 = CXL_HDR_SLOT_G0;
            mem_hdr.BE    = ~cxl_ch_m2s_be[0];

            // H4 -  M2S_DATA 
            mem_slot.Slot0 = '{Valid:1'b1, Data:4'd1, Slot:{9'd0, cxl_m2s_hdr_msg_s[0], mem_hdr}};
            // G0 -  DATA 
            mem_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_m2s_data_msg_s[127:0]}};
            // G0 -  DATA 
            mem_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_m2s_data_msg_s[255:128]}};
            // G0 -  DATA 
            mem_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_m2s_data_msg_s[383:256]}};
        end

        // IF (MSG_PRIORITY == 0) && (M2S REQ = 1) && (M2S DATA > 0)
        5'b0_01_1_?: begin
            // RULE FORMAT: H5-G5-G0-G0
            mem_hdr.Slot0 = CXL_HDR_SLOT_H5;
            mem_hdr.Slot1 = CXL_HDR_SLOT_G5;
            mem_hdr.Slot2 = CXL_HDR_SLOT_G0;
            mem_hdr.Slot3 = CXL_HDR_SLOT_G0;
            mem_hdr.BE    = ~cxl_ch_m2s_be[0];

            // H5 -  M2S_REQ 
            mem_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_m2s_req_msg_s[0], mem_hdr}};
            // G5 -  M2S_DATA H2D_RSP 
            mem_slot.Slot1 = '{Valid:1'b1, Data:4'd1, Slot:{8'd0, cxl_h2d_rsp_msg_s[0], 1'b0, cxl_m2s_hdr_msg_s[0]}};
            // G0 -  DATA 
            mem_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_m2s_data_msg_s[127:0]}};
            // G0 -  DATA 
            mem_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_m2s_data_msg_s[255:128]}};
        end

        // IF (MSG_PRIORITY == 0) && (M2S REQ = 1) && (M2S DATA = 0)
        // IF (MSG_PRIORITY == 1) && (M2S REQ = 1) && (M2S DATA = 0)
        5'b0_01_0_?, 5'b1_01_0_?: begin
            // RULE FORMAT: H5-NA-NA-NA
            mem_hdr.Slot0 = CXL_HDR_SLOT_H5;
            mem_hdr.Slot1 = mem_cache_hdr_s.Slot1;
            mem_hdr.Slot2 = mem_cache_hdr_s.Slot2;
            mem_hdr.Slot3 = mem_cache_hdr_s.Slot3;

            // H5 -  M2S_REQ 
            mem_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_m2s_req_msg_s[0], mem_hdr}};
            // CACHE - CXL.cache Slots
            mem_slot.Slot1 = mem_cache_slot_s.Slot1;
            // CACHE - CXL.cache Slots
            mem_slot.Slot2 = mem_cache_slot_s.Slot2;
            // CACHE - CXL.cache Slots
            mem_slot.Slot3 = mem_cache_slot_s.Slot3;
        end

        // IF (MSG_PRIORITY == 0) && (M2S REQ = 2) && (M2S DATA > 0) && (H2D DATA = 0)
        5'b0_11_1_0: begin
            // RULE FORMAT: H5-G4-G5-G0
            mem_hdr.Slot0 = CXL_HDR_SLOT_H5;
            mem_hdr.Slot1 = CXL_HDR_SLOT_G4;
            mem_hdr.Slot2 = CXL_HDR_SLOT_G5;
            mem_hdr.Slot3 = CXL_HDR_SLOT_G0;
            mem_hdr.BE    = ~cxl_ch_m2s_be[0];

            // H5 -  M2S_REQ 
            mem_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_m2s_req_msg_s[0], mem_hdr}};
            // G4 -  M2S_REQ H2D_DATA 
            mem_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{16'd0, DUMMY_H2D_HDR, 1'b0, cxl_m2s_req_msg_s[1]}};
            // G5 -  M2S_DATA H2D_RSP 
            mem_slot.Slot2 = '{Valid:1'b1, Data:4'd1, Slot:{8'd0, cxl_h2d_rsp_msg_s[0], 1'b0, cxl_m2s_hdr_msg_s[0]}};
            // G0 -  DATA 
            mem_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_m2s_data_msg_s[127:0]}};
        end

        // IF (MSG_PRIORITY == 0) && (M2S REQ = 2) && (M2S DATA = 0) && (H2D DATA = 0)
        // IF (MSG_PRIORITY == 1) && (M2S REQ = 2) && (M2S DATA = 0) && (H2D DATA = 0)
        5'b0_11_0_0, 5'b1_11_0_0: begin
            // RULE FORMAT: H5-G4-NA-NA
            mem_hdr.Slot0 = CXL_HDR_SLOT_H5;
            mem_hdr.Slot1 = CXL_HDR_SLOT_G4;
            mem_hdr.Slot2 = mem_cache_hdr_s.Slot1;
            mem_hdr.Slot3 = mem_cache_hdr_s.Slot2;

            // H5 -  M2S_REQ 
            mem_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_m2s_req_msg_s[0], mem_hdr}};
            // G4 -  M2S_REQ H2D_DATA 
            mem_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{16'd0, DUMMY_H2D_HDR, 1'b0, cxl_m2s_req_msg_s[1]}};
            // CACHE - CXL.cache Slots
            mem_slot.Slot2 = mem_cache_slot_s.Slot1;
            // CACHE - CXL.cache Slots
            mem_slot.Slot3 = mem_cache_slot_s.Slot2;
        end

        // IF (MSG_PRIORITY == 0) && (M2S REQ = 2) && (M2S DATA = X) && (H2D DATA > 0)
        // IF (MSG_PRIORITY == 1) && (M2S REQ = 2) && (M2S DATA = 0) && (H2D DATA > 0)
        5'b0_11_?_1, 5'b1_11_0_1: begin
            // RULE FORMAT: H5-G4-G0-G0
            mem_hdr.Slot0 = CXL_HDR_SLOT_H5;
            mem_hdr.Slot1 = CXL_HDR_SLOT_G4;
            mem_hdr.Slot2 = CXL_HDR_SLOT_G0;
            mem_hdr.Slot3 = CXL_HDR_SLOT_G0;

            // H5 -  M2S_REQ 
            mem_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_m2s_req_msg_s[0], mem_hdr}};
            // G4 -  M2S_REQ H2D_DATA 
            mem_slot.Slot1 = '{Valid:1'b1, Data:{3'd0, cxl_ch_h2d_hdr_vld[0]}, Slot:{16'd0, cxl_h2d_hdr_msg_s[0], 1'b0, cxl_m2s_req_msg_s[1]}};
            // G0 -  DATA 
            mem_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[127:0]}};
            // G0 -  DATA 
            mem_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_h2d_data_msg_s[255:128]}};
        end
        default: begin
            // NA-NA-NA-NA
            mem_hdr.Slot0 = CXL_HDR_SLOT_0_t'('0);
            mem_hdr.Slot1 = mem_cache_hdr_s.Slot1;//CXL_HDR_SLOT_N_t'('0);
            mem_hdr.Slot2 = mem_cache_hdr_s.Slot2;//CXL_HDR_SLOT_N_t'('0);
            mem_hdr.Slot3 = mem_cache_hdr_s.Slot3;//CXL_HDR_SLOT_N_t'('0);
            
            mem_slot = SLOT_HDR_t'('0);
        end
    endcase
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL.mem CACHE Packing Rules
// -------------------------------------------------------------------------------------
//
// [TRY TO FIT CACHE MESSAGES]
// IF (H2D DATA > 0) BEGIN
//     G2-G0-G0
// END
// ELSE IF (H2D DATA = 0) && (H2D REQ > 1) BEGIN
//     G2-G2-G1
// END
// ELSE BEGIN
//     G2-G1-G1
// END
//
// -------------------------------------------------------------------------------------
always_comb begin
    mem_cache_hdr_s  = '{ Slot0:CXL_HDR_SLOT_H5, Slot1:CXL_HDR_SLOT_G5, Slot2:CXL_HDR_SLOT_G5, Slot3:CXL_HDR_SLOT_G5, ProtType: CXL_HDR_PROT, default: '0};
    mem_cache_slot_s = '0;
    casez ({cxl_ch_h2d_hdr_vld[0], cxl_ch_h2d_req_vld[1]})
        // IF (H2D DATA > 0)
        2'b1?: begin
            // RULE FORMAT: G2-G0-G0
            mem_cache_hdr_s.Slot1 = CXL_HDR_SLOT_G2;
            mem_cache_hdr_s.Slot2 = CXL_HDR_SLOT_G0;
            mem_cache_hdr_s.Slot3 = CXL_HDR_SLOT_G0;
            
            // G2 -  H2D_REQ H2D_DATA H2D_RSP 
            mem_cache_slot_s.Slot1 = '{Valid:1'b1, Data:4'd1, Slot:{8'd0, cxl_h2d_rsp_msg_s[0], cxl_h2d_hdr_msg_s[0], cxl_h2d_req_msg_s[0]}};
            // G0 - CXL.cache D2H Data
            mem_cache_slot_s.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_h2d_data_msg_s[127:0]};
            // G0 - CXL.cache D2H Data
            mem_cache_slot_s.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_h2d_data_msg_s[255:128]};
        end
        // IF (H2D DATA = 0) && (H2D REQ > 1)
        2'b01: begin
            // RULE FORMAT: G2-G2-G1
            mem_cache_hdr_s.Slot1 = CXL_HDR_SLOT_G2;
            mem_cache_hdr_s.Slot2 = CXL_HDR_SLOT_G2;
            mem_cache_hdr_s.Slot3 = CXL_HDR_SLOT_G1;

            // G2 -  H2D_REQ H2D_DATA H2D_RSP 
            mem_cache_slot_s.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{8'd0, cxl_h2d_rsp_msg_s[0], cxl_h2d_hdr_msg_s[0], cxl_h2d_req_msg_s[0]}};
            // G2 -  H2D_REQ H2D_DATA H2D_RSP 
            mem_cache_slot_s.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{8'd0, cxl_h2d_rsp_msg_s[1], cxl_h2d_hdr_msg_s[1], cxl_h2d_req_msg_s[1]}};
            // G1 -  H2D_RSP H2D_RSP H2D_RSP H2D_RSP 
            mem_cache_slot_s.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{DUMMY_H2D_RSP, DUMMY_H2D_RSP, cxl_h2d_rsp_msg_s[3], cxl_h2d_rsp_msg_s[2]}};
        end
        default: begin
            // RULE FORMAT: G2-G1-G1
            mem_cache_hdr_s.Slot1 = CXL_HDR_SLOT_G2;
            mem_cache_hdr_s.Slot2 = CXL_HDR_SLOT_G1;
            mem_cache_hdr_s.Slot3 = CXL_HDR_SLOT_G1;

            // G2 -  H2D_REQ H2D_DATA H2D_RSP 
            mem_cache_slot_s.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{8'd0, cxl_h2d_rsp_msg_s[0], cxl_h2d_hdr_msg_s[0], cxl_h2d_req_msg_s[0]}};
            // G1 -  H2D_RSP H2D_RSP H2D_RSP H2D_RSP 
            mem_cache_slot_s.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{DUMMY_H2D_RSP, cxl_h2d_rsp_msg_s[3], cxl_h2d_rsp_msg_s[2], cxl_h2d_rsp_msg_s[1]}};
            // G1 -  H2D_RSP H2D_RSP H2D_RSP H2D_RSP 
            mem_cache_slot_s.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{DUMMY_H2D_RSP, DUMMY_H2D_RSP, DUMMY_H2D_RSP, DUMMY_H2D_RSP}};
        end
    endcase
end
// -------------------------------------------------------------------------------------



// -------------------------------------------------------------------------------------
// Message Arbitration
// -------------------------------------------------------------------------------------
always_comb begin
    rr_arb_req_rsp_nxt = rr_arb_req_rsp_r;
    rr_arb_req_rwd_nxt = rr_arb_req_rwd_r;
    if ((|cxl_packer_slot_vld) & ~b_llctrl.s_cxl_ll_packer_halt) begin
        if (rr_arb_req_rwd_r & (|mem_hdr_vld) & ~(|mem_req_vld))
             rr_arb_req_rwd_nxt = 1'b0;
        else 
        if (~rr_arb_req_rwd_r & ~(|mem_hdr_vld) & (|mem_req_vld))
             rr_arb_req_rwd_nxt = 1'b1;
        if (rr_arb_req_rsp_r &  (|cache_rsp_vld) & ~(|cache_req_vld))
             rr_arb_req_rsp_nxt = 1'b0;
        else 
        if (~rr_arb_req_rsp_r & ~(|cache_rsp_vld) & (|cache_req_vld))
             rr_arb_req_rsp_nxt = 1'b1;
    end
end


always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        rr_arb_req_rsp_r    <= #TP 1'b0;
        rr_arb_req_rwd_r    <= #TP 1'b0;
    end
    else begin
        rr_arb_req_rsp_r    <= #TP rr_arb_req_rsp_nxt;
        rr_arb_req_rwd_r    <= #TP rr_arb_req_rwd_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Channel Halt Interface
// -------------------------------------------------------------------------------------
logic [$clog2(H2D_68B_REQ_NUM):0]    cxl_ch_h2d_req_cnt;       // Number of valid H2D Request Messages in the output flit
logic [$clog2(H2D_68B_RESP_NUM):0]   cxl_ch_h2d_rsp_cnt;       // Number of valid H2D Response Messages in the output flit
logic [$clog2(H2D_68B_DATA_NUM):0]   cxl_ch_h2d_hdr_cnt;       // Number of valid H2D Data Messages in the output flit
logic [$clog2(M2S_68B_NDR_NUM):0]    cxl_ch_m2s_req_cnt;       // Number of valid M2S Request Only Messages in the output flit
logic [$clog2(M2S_68B_DATA_NUM):0]   cxl_ch_m2s_hdr_cnt;       // Number of valid M2S Data Messages in the output flit
logic [$clog2(M2S_68B_BI_RSP_NUM):0] cxl_ch_m2s_bi_rsp_cnt;    // Number of valid M2S BI Response Messages in the output flit

CXL_HDR_SLOT_0_t               cxl_flit_slot0_type_s;    // Loop variable, Slot Type in Slots 0
CXL_HDR_SLOT_N_t               cxl_flit_slotN_type_s;    // Loop variable, Slot Type in Slots 1-3
logic [127:0]                  cxl_flit_slot_data_s;     // Loop variable, Slot Data in Slots 0-3

assign cxl_prot_msg_halt_s  = ~pack_enable | cxl_prot_msg_halt;
assign cxl_prot_data_halt_s = ~pack_enable | cxl_prot_data_halt;

always_comb begin
    // Initialize message counters counters
    cxl_ch_h2d_req_cnt    = 2'd0;
    cxl_ch_h2d_rsp_cnt    = 3'd0;
    cxl_ch_h2d_hdr_cnt    = 3'd0;
    cxl_ch_m2s_req_cnt    = 2'd0;
    cxl_ch_m2s_hdr_cnt    = 1'd0;
    cxl_ch_m2s_bi_rsp_cnt = 2'd0;

    if (!cxl_packer_all_data) begin
        // Extract the number of every message packed in Slots 0-3 of the current flit
        for (int i = 0; i <= 3; i++) begin
            case (i)
                      0: {cxl_flit_slot0_type_s, cxl_flit_slot_data_s} = {cxl_flit_hdr_s.Slot0, cxl_packer_flit[127:0]};
                      1: {cxl_flit_slotN_type_s, cxl_flit_slot_data_s} = {cxl_flit_hdr_s.Slot1, cxl_packer_flit[255:128]};
                      2: {cxl_flit_slotN_type_s, cxl_flit_slot_data_s} = {cxl_flit_hdr_s.Slot2, cxl_packer_flit[383:256]};
                default: {cxl_flit_slotN_type_s, cxl_flit_slot_data_s} = {cxl_flit_hdr_s.Slot3, cxl_packer_flit[511:384]};
            endcase

            if (i == 0) begin
                case (cxl_flit_slot0_type_s)
                    // H0-H5 SLOT TYPES
                    CXL_HDR_SLOT_H0: begin
                        // CXL.cache Req + CXL.cache Resp
                        if (cxl_flit_slot_data_s[32]) cxl_ch_h2d_req_cnt = 1;
                        if (cxl_flit_slot_data_s[32+H2D_68B_REQ_SIZE]) cxl_ch_h2d_rsp_cnt = 1;
                    end
                    CXL_HDR_SLOT_H1: begin
                        // CXL.cache Data Header + 2 CXL.cache Resp
                        if (cxl_flit_slot_data_s[32]) cxl_ch_h2d_hdr_cnt = 1;
                        if (cxl_flit_slot_data_s[32+H2D_68B_DHDR_SIZE]) cxl_ch_h2d_rsp_cnt = 1;
                        if (cxl_flit_slot_data_s[32+H2D_68B_DHDR_SIZE+H2D_68B_RESP_SIZE]) cxl_ch_h2d_rsp_cnt = 2;
                    end
                    CXL_HDR_SLOT_H2: begin
                        // CXL.cache Req + CXL.cache Data Header
                        if (cxl_flit_slot_data_s[32]) cxl_ch_h2d_req_cnt = 1;
                        if (cxl_flit_slot_data_s[32+H2D_68B_REQ_SIZE]) cxl_ch_h2d_hdr_cnt = 1;
                    end
                    CXL_HDR_SLOT_H3: begin
                        // 4 CXL.cache Data Header 96
                        if (cxl_flit_slot_data_s[32]) cxl_ch_h2d_hdr_cnt = 1;
                        if (cxl_flit_slot_data_s[32+1*H2D_68B_DHDR_SIZE]) cxl_ch_h2d_hdr_cnt = 2;
                        if (cxl_flit_slot_data_s[32+2*H2D_68B_DHDR_SIZE]) cxl_ch_h2d_hdr_cnt = 3;
                        if (cxl_flit_slot_data_s[32+3*H2D_68B_DHDR_SIZE]) cxl_ch_h2d_hdr_cnt = 4;
                    end
                    CXL_HDR_SLOT_H4: begin
                        // CXL.mem RwD Header
                        if (cxl_flit_slot_data_s[32]) cxl_ch_m2s_hdr_cnt = 1;
                    end
                    CXL_HDR_SLOT_H5: begin
                        // CXL.mem Req Only
                        if (cxl_flit_slot_data_s[32]) cxl_ch_m2s_req_cnt = 1;
                    end
    // spyglass disable_block W193
    // SMD: Empty statement
    // SJ: Default statement is added to complete the case with no changes to the register(s) state
                    default: ;
    // spyglass enable_block W193
                endcase
            end
            else begin // i = 1-3
                case (cxl_flit_slotN_type_s)
                    // G1-G5 SLOT TYPES
                    CXL_HDR_SLOT_G1: begin
                        // 4 CXL.cache Resp
                        if (cxl_flit_slot_data_s[0]) cxl_ch_h2d_rsp_cnt++;
                        if (cxl_flit_slot_data_s[0+1*H2D_68B_RESP_SIZE]) cxl_ch_h2d_rsp_cnt++;
                        if (cxl_flit_slot_data_s[0+2*H2D_68B_RESP_SIZE]) cxl_ch_h2d_rsp_cnt++;
                        if (cxl_flit_slot_data_s[0+3*H2D_68B_RESP_SIZE]) cxl_ch_h2d_rsp_cnt++;
                    end
                    CXL_HDR_SLOT_G2: begin
                        // CXL.cache Req + CXL.cache Data Header + CXL.cache Resp
                        if (cxl_flit_slot_data_s[0]) cxl_ch_h2d_req_cnt++;
                        if (cxl_flit_slot_data_s[0+H2D_68B_REQ_SIZE]) cxl_ch_h2d_hdr_cnt = 1;
                        if (cxl_flit_slot_data_s[0+H2D_68B_REQ_SIZE+H2D_68B_DHDR_SIZE]) cxl_ch_h2d_rsp_cnt++;
                    end
                    CXL_HDR_SLOT_G3: begin
                        // 4 CXL.cache Data Header + CXL.cache Resp
                        if (cxl_flit_slot_data_s[0]) cxl_ch_h2d_hdr_cnt = 1;
                        if (cxl_flit_slot_data_s[0+1*H2D_68B_DHDR_SIZE]) cxl_ch_h2d_hdr_cnt = 2;
                        if (cxl_flit_slot_data_s[0+2*H2D_68B_DHDR_SIZE]) cxl_ch_h2d_hdr_cnt = 3;
                        if (cxl_flit_slot_data_s[0+3*H2D_68B_DHDR_SIZE]) cxl_ch_h2d_hdr_cnt = 4;
                        if (cxl_flit_slot_data_s[0+4*H2D_68B_DHDR_SIZE]) cxl_ch_h2d_rsp_cnt++;
                    end
                    CXL_HDR_SLOT_G4: begin
                        // CXL.mem Req + CXL.cache Data Header
                        if (cxl_flit_slot_data_s[0]) cxl_ch_m2s_req_cnt++;
                        if (cxl_flit_slot_data_s[0+(M2S_68B_NDR_SIZE+1)]) cxl_ch_h2d_hdr_cnt = 1;
                    end
                    CXL_HDR_SLOT_G5: begin
                        // CXL.mem RwD Header + CXL.cache Resp
                        if (cxl_flit_slot_data_s[0]) cxl_ch_m2s_hdr_cnt = 1;
                        if (cxl_flit_slot_data_s[0+(M2S_68B_DHDR_SIZE+1)]) cxl_ch_h2d_rsp_cnt++;
                    end
    // spyglass disable_block W193
    // SMD: Empty statement
    // SJ: Default statement is added to complete the case with no changes to the register(s) state
                    default: ;
    // spyglass enable_block W193
                endcase
            end
        end
    end
 
    // Halt corresponding message channels
    // Halt Protocol Message Channels only if the message is valid otherwise do not assert
    // halt signal to allow channel to proceed
    b_txtl_llctrl.s_cxl_h2d_req_halt = '1;
    b_txtl_llctrl.s_cxl_h2d_rsp_halt = '1;
    b_txtl_llctrl.s_cxl_h2d_hdr_halt = '1;
    
    b_txtl_llctrl.s_cxl_h2d_req_halt[H2D_68B_REQ_NUM-1:0] = cxl_prot_msg_halt_s ? {H2D_68B_REQ_NUM{1'b1}}  : (cxl_ch_h2d_req_gnt_halt | (cxl_ch_h2d_req_vld & ({H2D_68B_REQ_NUM{1'b1}}  << cxl_ch_h2d_req_cnt)));
    b_txtl_llctrl.s_cxl_h2d_rsp_halt[H2D_68B_RESP_NUM-1:0] = cxl_prot_msg_halt_s ? {H2D_68B_RESP_NUM{1'b1}} : (cxl_ch_h2d_rsp_gnt_halt | (cxl_ch_h2d_rsp_vld & ({H2D_68B_RESP_NUM{1'b1}} << cxl_ch_h2d_rsp_cnt)));
    b_txtl_llctrl.s_cxl_h2d_hdr_halt[H2D_68B_DATA_NUM-1:0] = cxl_prot_msg_halt_s ? {H2D_68B_DATA_NUM{1'b1}} : (cxl_ch_h2d_hdr_gnt_halt | (cxl_ch_h2d_hdr_vld & ({H2D_68B_DATA_NUM{1'b1}} << cxl_ch_h2d_hdr_cnt)));
    b_txtl_llctrl.s_cxl_m2s_req_halt    = '1;
    b_txtl_llctrl.s_cxl_m2s_hdr_halt    = '1;
    
    b_txtl_llctrl.s_cxl_m2s_req_halt[M2S_68B_NDR_NUM-1:0] = cxl_prot_msg_halt_s ? {M2S_68B_NDR_NUM{1'b1}}  : (cxl_ch_m2s_req_gnt_halt | (cxl_ch_m2s_req_vld & ({M2S_68B_NDR_NUM{1'b1}}  << cxl_ch_m2s_req_cnt)));
    b_txtl_llctrl.s_cxl_m2s_hdr_halt[M2S_68B_DATA_NUM-1:0] = cxl_prot_msg_halt_s ? {M2S_68B_DATA_NUM{1'b1}} : (cxl_ch_m2s_rwd_gnt_halt | (cxl_ch_m2s_rwd_vld & ({M2S_68B_DATA_NUM{1'b1}} << cxl_ch_m2s_hdr_cnt)));
    b_txtl_llctrl.s_cxl_m2s_bi_rsp_halt = '1;
    
    // If at least one Data Header is set then release corresponding data channel halt
    b_txtl_llctrl.s_cxl_h2d_data_halt = '1;
    b_txtl_llctrl.s_cxl_h2d_data_halt[0] = cxl_prot_data_halt_s ? 1'b1 : ~((b_txtl_llctrl.s_cxl_h2d_data_vld[0] & cxl_packer_all_data & cxl_cache_data_ena) | ((|cxl_ch_h2d_hdr_vld) & (cxl_ch_h2d_hdr_cnt > 0)));
    b_txtl_llctrl.s_cxl_m2s_data_halt = '1;
    b_txtl_llctrl.s_cxl_m2s_data_halt[0] = cxl_prot_data_halt_s ? 1'b1 : ~((b_txtl_llctrl.s_cxl_m2s_data_vld[0] & cxl_packer_all_data & cxl_mem_data_ena) | ((|cxl_ch_m2s_rwd_vld) & (cxl_ch_m2s_hdr_cnt > 0)));
end
// -------------------------------------------------------------------------------------


endmodule : DWC_cxl_mem_cache_packer_dsp
