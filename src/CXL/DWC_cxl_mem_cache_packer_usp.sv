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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_packer_usp.sv#2 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Device Flit Packer
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_packer_usp 
    import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)(
    input                                     core_clk,                // Core clock
    input                                     core_rst_n,              // Core active low asynchronous reset
    input                                     pack_enable,             // Enable Flit Packer
    input                                     cxl_packer_reverse,      // Reverse Protocol Mode
    input  [511:0]                            cxl_packer_flit,         // Flit on the Packer output
    input                                     cxl_packer_all_data,     // All Data Rollover
    input  [4:0]                              cxl_packer_rollover,     // Data Rollover Counter
    input  [3:0]                              cxl_packer_slot_vld,     // Slot Valid
    input                                     cxl_prot_msg_halt,       // CXL Protocol Message Channel Halt
    input                                     cxl_prot_data_halt,      // CXL Protocol Data Channel Halt
    input                                     cfg_cache_poison_start,  // CachePoisonInjectionStart
    output                                    cfg_cache_poison_busy,   // CachePoisonInjectionBusy
    output [TX_CRDIF_WIDTH-1:0]               cache_req_vld,           // CXL.cache Request channel valid bit
    output [TX_CRDIF_WIDTH-1:0]               cache_rsp_vld,           // CXL.cache Response channel valid bit
    output [TX_CRDIF_WIDTH-1:0]               cache_hdr_vld,           // CXL.cache Data channel valid bit
    output CXL_HDR_t                          cache_hdr,               // CXL.cache Rule Packer Header
    output SLOT_HDR_t                         cache_slot,              // CXL.cache Slot Information
    input                                     cxl_cache_data_ena,      // CXL.cache Data Enable
    input                                     cfg_mem_poison_start,    // MemPoisonInjectionStart
    output                                    cfg_mem_poison_busy,     // MemPoisonInjectionBusy
    output [TX_CRDIF_WIDTH-1:0]               mem_rsp_vld,             // CXL.mem Response channel valid bit
    output [TX_CRDIF_WIDTH-1:0]               mem_hdr_vld,             // CXL.mem Data channel valid bit
    output CXL_HDR_t                          mem_hdr,                 // CXL.mem Rule Packer Header
    output SLOT_HDR_t                         mem_slot,                // CXL.mem Slot Information
    output                                    mem_pending_vld,         // CXL.mem Pending Message
    input                                     cxl_mem_data_ena,        // CXL.mem Data Enable
    output logic                              cxl_tl_pending_o,        // Pending message on the TL Interface
    DWC_cxl_pack_llctrl_if.slave_ctrl_mp      b_llctrl,                // Link Layer Controller to Flit Packer Interface
    DWC_cxl_txtl_llctrl_if.pack_slave_dev_mp  b_txtl_llctrl            // Flit Packer to Transaction Layer Interface

);

//local param to support backward compatibility to CXL version 1.1
localparam S2M_NDR_SIZE_DL  = S2M_68B_NDR_SIZE ;
localparam S2M_NDR_SIZE_NDL = (S2M_NDR_SIZE_DL-S2M_NDR_DEVLOAD_WD);

parameter DUMMY_D2H_RSP    = {D2H_68B_RESP_SIZE{1'b0}};
parameter DUMMY_D2H_HDR    = {D2H_68B_DHDR_SIZE{1'b0}};
parameter DUMMY_S2M_NDR    = {S2M_NDR_SIZE_DL{1'b0}};


logic [D2H_68B_REQ_NUM-1:0]      cxl_ch_d2h_req_vld;  // Maximum 4 messages per flit
logic [D2H_68B_RESP_NUM-1:0]     cxl_ch_d2h_rsp_vld;  // Maximum 2 messages per flit
logic [D2H_68B_DATA_NUM-1:0]     cxl_ch_d2h_hdr_vld;  // Maximum 4 messages per flit
logic [S2M_68B_NDR_NUM-1:0]      cxl_ch_s2m_ndr_vld;  // Maximum 2 messages per flit
logic [S2M_68B_DATA_NUM-1:0]     cxl_ch_s2m_drc_vld;  // Maximum 3 messages per flit

logic [D2H_68B_REQ_SIZE-1:0]     cxl_d2h_req_msg_s [0:D2H_68B_REQ_NUM-1];  // H2D Request Channel - 79 bits
logic [D2H_68B_RESP_SIZE-1:0]    cxl_d2h_rsp_msg_s [0:D2H_68B_RESP_NUM-1]; // D2H Response Channel - 20 bits
logic [D2H_68B_DHDR_SIZE-1:0]    cxl_d2h_hdr_msg_s [0:D2H_68B_DATA_NUM-1]; // D2H Data Header Channel - 17 bits
logic [D2H_68B_DDATA_SIZE-1:0]   cxl_d2h_data_msg_s;                   // D2H Data - 4x16B
logic [S2M_68B_NDR_SIZE-1:0]     cxl_s2m_ndr_msg_s [0:S2M_68B_NDR_NUM-1];  // S2M NDR Channel - 28/30 bits respectively for  CXL1.1,CXL2.0
logic [S2M_68B_DHDR_SIZE-1:0]    cxl_s2m_hdr_msg_s [0:S2M_68B_DATA_NUM-1]; // S2M DRC Header Channel - 40 bits
logic [S2M_68B_DDATA_SIZE-1:0]   cxl_s2m_data_msg_s;                   // S2M Data - 4x16B

logic [D2H_68B_REQ_NUM-1:0]      cxl_ch_d2h_req_gnt_halt;  // Maximum 4 messages per flit
logic [D2H_68B_RESP_NUM-1:0]     cxl_ch_d2h_rsp_gnt_halt;  // Maximum 2 messages per flit
logic [D2H_68B_DATA_NUM-1:0]     cxl_ch_d2h_hdr_gnt_halt;  // Maximum 4 messages per flit
logic [S2M_68B_NDR_NUM-1:0]      cxl_ch_s2m_ndr_gnt_halt;  // Maximum 2 messages per flit
logic [S2M_68B_DATA_NUM-1:0]     cxl_ch_s2m_drc_gnt_halt;  // Maximum 3 messages per flit

// MDH control signals
logic [D2H_68B_DATA_NUM-1:0]     cxl_ch_d2h_be;             // BE flags per channel if all Byte Enables are set
logic [D2H_68B_DATA_NUM-1:0]     cxl_ch_d2h_hdr_be_vld;     // Maximum 4 messages per flit
logic                            cxl_cache_mdh_s;           // MDH flag for CXL.cache protocol
logic                        cxl_mem_mdh_s;             // MDH flag for CXL.mem protocol
// Arbitration control signals
logic                        rr_arb_req_rsp_r, rr_arb_req_rsp_nxt;       // Arbitration between Cache Request and Response/Data messages
logic                        rr_arb_mem_data_r, rr_arb_mem_data_nxt;     // Arbitration between S2M NDR and Data messages

// CXL.cache flit packing tables
CXL_HDR_t                    cache_mem_hdr_s;                        // CXL.cache Mem Rule Packer Header
SLOT_HDR_t                   cache_mem_slot_s;                       // CXL.cache Mem Slot Information
// CXL.mem flit packing tables
CXL_HDR_t                    mem_cache_hdr_s;                        // CXL.mem Cache Rule Packer Header
SLOT_HDR_t                   mem_cache_slot_s;                       // CXL.mem Cache Slot Information
CXL_HDR_t                    cxl_flit_hdr_s;      // Slot Mapping Flit Header

// Channel Halt Generation Signals
logic                        cxl_prot_msg_halt_s;          // CXL Protocol Message Channel Halt
logic                        cxl_prot_data_halt_s;         // CXL Protocol Data Channel Halt - d2h_data and s2m_data

assign cxl_flit_hdr_s  = cxl_packer_flit[31:0];

assign cxl_ch_d2h_be = {!cxl_ch_d2h_hdr_vld[3] | (b_txtl_llctrl.s_cxl_d2h_be_vld_n[3]), !cxl_ch_d2h_hdr_vld[2] | (b_txtl_llctrl.s_cxl_d2h_be_vld_n[2]), 
                        !cxl_ch_d2h_hdr_vld[1] | (b_txtl_llctrl.s_cxl_d2h_be_vld_n[1]), !cxl_ch_d2h_hdr_vld[0] | (b_txtl_llctrl.s_cxl_d2h_be_vld_n[0])};
assign cxl_ch_d2h_hdr_be_vld = { &(cxl_ch_d2h_hdr_vld[3:0] & cxl_ch_d2h_be[3:0]), &(cxl_ch_d2h_hdr_vld[2:0] & cxl_ch_d2h_be[2:0]),
                                 &(cxl_ch_d2h_hdr_vld[1:0] & cxl_ch_d2h_be[1:0]), cxl_ch_d2h_hdr_vld[0]/* & cxl_ch_d2h_be[0]*/ };

// If MDH is not disabled and all bytes are enabled on the channels where D2H Data Header message is valid
// then set MDH flag for CXL.cache protocol
assign cxl_cache_mdh_s = b_llctrl.s_cxl_ll_cache_mdh_en & (&cxl_ch_d2h_hdr_be_vld[1:0]);

// If MDH is not disabled then set MDH flag for CXL.mem protocol. Please not that Byte Enable bits are not
// applicable for CXL.mem data
assign cxl_mem_mdh_s   = b_llctrl.s_cxl_ll_mem_mdh_en & (&cxl_ch_s2m_drc_vld[1:0]);

assign mem_pending_vld = cxl_s2m_ndr_msg_s[0][0] || cxl_s2m_hdr_msg_s[0][0];



// -------------------------------------------------------------------------------------
// CXL.Cache/Mem Poison Mode
// -------------------------------------------------------------------------------------
logic cfg_cache_poison_start_r;
logic cfg_cache_poison_r, cfg_cache_poison_nxt;

assign cfg_cache_poison_busy = cfg_cache_poison_r;

always_comb begin
    if (cfg_cache_poison_start && !cfg_cache_poison_start_r && !cfg_cache_poison_r) begin
        cfg_cache_poison_nxt = 1'b1;
    end
    else if (cfg_cache_poison_r && cxl_d2h_hdr_msg_s[0][D2H_HDR_VLD] && !b_txtl_llctrl.s_cxl_d2h_hdr_halt[0]) begin
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

assign cfg_mem_poison_busy = cfg_mem_poison_r;

always_comb begin
    if (cfg_mem_poison_start && !cfg_mem_poison_start_r && !cfg_mem_poison_r) begin
        cfg_mem_poison_nxt = 1'b1;
    end
    else if (cfg_mem_poison_r && cxl_s2m_hdr_msg_s[0][S2M_HDR_VLD] && !b_txtl_llctrl.s_cxl_s2m_hdr_halt[0]) begin
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
// Gate valid channel messages if not enough credits are granted for a given channel or
// not enough free space is left in the Retry Buffer
// Assert halt signal for those channels.
// -------------------------------------------------------------------------------------
logic [D2H_68B_DATA_NUM:0] cxl_ll_cache_data_en;
logic [S2M_68B_DATA_NUM:0] cxl_ll_mem_data_en;

assign cxl_tl_pending_o = 1'b0    || b_txtl_llctrl.s_cxl_d2h_req[0][D2H_REQ_VLD] || b_txtl_llctrl.s_cxl_d2h_rsp[0][D2H_RESP_VLD] || b_txtl_llctrl.s_cxl_d2h_hdr[0][D2H_HDR_VLD]
    || b_txtl_llctrl.s_cxl_s2m_ndr[0][S2M_NDR_VLD] || b_txtl_llctrl.s_cxl_s2m_hdr[0][S2M_HDR_VLD]
 ;

always_comb begin
    // If Rollover Counter is equal to 3, it is expected that the next flit will be all data flit hence
    // flit packer should capture the number of headers equal (num_free_buff - 1)
    // As D2H data message has a ByteEnable then the situation when Rollover Counter is equal 2 and BE is enable
    // it is expected that the next flit is also ADF flit
    cxl_ll_cache_data_en = b_llctrl.s_cxl_ll_packer_data_en[D2H_68B_DATA_NUM:0] >> (((cxl_packer_rollover == 5'd3) || ((cxl_packer_rollover == 5'd2) && !(&b_txtl_llctrl.s_cxl_d2h_be[0]))) ? 1 : 0);

    for (int i = 0; i < D2H_68B_REQ_NUM; i++)  begin
        cxl_d2h_req_msg_s[i] = b_llctrl.s_cxl_ll_cache_req_gnt[i] ? b_txtl_llctrl.s_cxl_d2h_req[i][D2H_68B_REQ_SIZE-1:0] : '0;
        cxl_ch_d2h_req_gnt_halt[i] = ~b_llctrl.s_cxl_ll_cache_req_gnt[i] & b_txtl_llctrl.s_cxl_d2h_req[i][D2H_REQ_VLD];
    end
    for (int i = 0; i < D2H_68B_RESP_NUM; i++) begin
        cxl_d2h_rsp_msg_s[i] = b_llctrl.s_cxl_ll_cache_rsp_gnt[i] ? b_txtl_llctrl.s_cxl_d2h_rsp[i][D2H_68B_RESP_SIZE-1:0] : '0;
        cxl_ch_d2h_rsp_gnt_halt[i] = ~b_llctrl.s_cxl_ll_cache_rsp_gnt[i] & b_txtl_llctrl.s_cxl_d2h_rsp[i][D2H_RESP_VLD];
    end
    for (int i = 0; i < D2H_68B_DATA_NUM; i++) begin
        cxl_d2h_hdr_msg_s[i] = (b_llctrl.s_cxl_ll_cache_data_gnt[i] & cxl_ll_cache_data_en[i] & b_txtl_llctrl.s_cxl_d2h_data_vld[0]) ? b_txtl_llctrl.s_cxl_d2h_hdr[i][D2H_68B_DHDR_SIZE-1:0] : '0;
        cxl_ch_d2h_hdr_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_cache_data_gnt[i] & cxl_ll_cache_data_en[i] & b_txtl_llctrl.s_cxl_d2h_data_vld[0]) & b_txtl_llctrl.s_cxl_d2h_hdr[i][D2H_HDR_VLD];
    end
    // Overwrite Poison Bit
    cxl_d2h_hdr_msg_s[0][D2H_68B_POISON_BIT] = cxl_d2h_hdr_msg_s[0][D2H_HDR_VLD] ? (b_txtl_llctrl.s_cxl_d2h_hdr[0][D2H_68B_POISON_BIT] | cfg_cache_poison_r) : 1'b0;
    cxl_d2h_data_msg_s = b_txtl_llctrl.s_cxl_d2h_data[0];
    // If Rollover Counter is equal to 3, it is expected that the next flit will be all data flit hence
    // flit packer should capture the number of headers equal (num_free_buff - 1)
    cxl_ll_mem_data_en = b_llctrl.s_cxl_ll_packer_data_en[S2M_68B_DATA_NUM:0] >> ((cxl_packer_rollover == 5'd3) ? 1 : 0);

    for (int i = 0; i < S2M_68B_NDR_NUM; i++) begin
        cxl_s2m_ndr_msg_s[i] = b_llctrl.s_cxl_ll_mem_ndr_gnt[i] ? b_txtl_llctrl.s_cxl_s2m_ndr[i][S2M_68B_NDR_SIZE-1:0] : '0;
        cxl_ch_s2m_ndr_gnt_halt[i] = ~b_llctrl.s_cxl_ll_mem_ndr_gnt[i] & b_txtl_llctrl.s_cxl_s2m_ndr[i][S2M_NDR_VLD];
    end
    for (int i = 0; i < S2M_68B_DATA_NUM; i++) begin
        cxl_s2m_hdr_msg_s[i] = (b_llctrl.s_cxl_ll_mem_dr_gnt[i] & cxl_ll_mem_data_en[i] & b_txtl_llctrl.s_cxl_s2m_data_vld[0]) ? b_txtl_llctrl.s_cxl_s2m_hdr[i][S2M_68B_DHDR_SIZE-1:0] : '0;
        cxl_ch_s2m_drc_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_mem_dr_gnt[i] & cxl_ll_mem_data_en[i] & b_txtl_llctrl.s_cxl_s2m_data_vld[0]) & b_txtl_llctrl.s_cxl_s2m_hdr[i][S2M_HDR_VLD];
    end
    // Overwrite Poison Bit
    cxl_s2m_hdr_msg_s[0][S2M_68B_POISON_BIT] = cxl_s2m_hdr_msg_s[0][S2M_HDR_VLD] ? (b_txtl_llctrl.s_cxl_s2m_hdr[0][S2M_68B_POISON_BIT] | cfg_mem_poison_r) : 1'b0;
    cxl_s2m_data_msg_s = b_txtl_llctrl.s_cxl_s2m_data[0];
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Extarct channel message valid bits
// -------------------------------------------------------------------------------------
always_comb begin
    for (int i = 0; i < D2H_68B_REQ_NUM; i++)  cxl_ch_d2h_req_vld[i] = cxl_d2h_req_msg_s[i][D2H_REQ_VLD];
    for (int i = 0; i < D2H_68B_RESP_NUM; i++) cxl_ch_d2h_rsp_vld[i] = cxl_d2h_rsp_msg_s[i][D2H_RESP_VLD];
    for (int i = 0; i < D2H_68B_DATA_NUM; i++) cxl_ch_d2h_hdr_vld[i] = cxl_d2h_hdr_msg_s[i][D2H_HDR_VLD];
    for (int i = 0; i < S2M_68B_NDR_NUM; i++)  cxl_ch_s2m_ndr_vld[i] = cxl_s2m_ndr_msg_s[i][S2M_NDR_VLD];
    for (int i = 0; i < S2M_68B_DATA_NUM; i++) cxl_ch_s2m_drc_vld[i] = cxl_s2m_hdr_msg_s[i][S2M_HDR_VLD];
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Generate valid signals for credit tracking
// -------------------------------------------------------------------------------------
assign cache_req_vld   = {{(TX_CRDIF_WIDTH-D2H_68B_REQ_NUM){1'b0}} , cxl_ch_d2h_req_vld & ~b_txtl_llctrl.s_cxl_d2h_req_halt[D2H_68B_REQ_NUM  -1:0]};
assign cache_rsp_vld   = {{(TX_CRDIF_WIDTH-D2H_68B_RESP_NUM){1'b0}}, cxl_ch_d2h_rsp_vld & ~b_txtl_llctrl.s_cxl_d2h_rsp_halt[D2H_68B_RESP_NUM -1:0]};
assign cache_hdr_vld   = {{(TX_CRDIF_WIDTH-D2H_68B_DATA_NUM){1'b0}}, cxl_ch_d2h_hdr_vld & ~b_txtl_llctrl.s_cxl_d2h_hdr_halt[D2H_68B_DATA_NUM -1:0]};
assign mem_rsp_vld = {{(TX_CRDIF_WIDTH-S2M_68B_NDR_NUM){1'b0}} , cxl_ch_s2m_ndr_vld & ~b_txtl_llctrl.s_cxl_s2m_ndr_halt[S2M_68B_NDR_NUM  - 1:0]};
assign mem_hdr_vld = {{(TX_CRDIF_WIDTH-S2M_68B_DATA_NUM){1'b0}}, cxl_ch_s2m_drc_vld & ~b_txtl_llctrl.s_cxl_s2m_hdr_halt[S2M_68B_DATA_NUM - 1:0]};
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Append 2-bits Device Load to S2M NDR for CXL1.1
// -------------------------------------------------------------------------------------
logic [S2M_NDR_SIZE_DL-1:0]     cxl_s2m_ndr_msg_t [0:S2M_68B_NDR_NUM-1];  // S2M NDR Channel - 30 bits

always_comb begin
    for (int i = 0; i < S2M_68B_NDR_NUM; i++) begin 
        cxl_s2m_ndr_msg_t[i] = DUMMY_S2M_NDR;
        cxl_s2m_ndr_msg_t[i] = cxl_s2m_ndr_msg_s[i];
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL.cache Packing Rules
// -------------------------------------------------------------------------------------
//
// MSG_PRIORITY - REQUEST (0) OR RESP/DATA (1)
// 
// IF (D2H REQ > 0) ? ((MSG_PRIORITY == 0) || ((D2H RESP = 0) && (D2H DATA = 0))) BEGIN
//     SLOT0 = H1
//     IF (D2H DATA > 0) BEGIN // H1-G0-G0-G0
//         SLOT1 = G0
//         SLOT2 = G0
//         SLOT3 = G0
//     END
//     ELSE BEGIN
//         IF ((D2H REQ > 1) || (D2H RESP > 0)) BEGIN
//             SLOT1 = G1
//             IF (D2H REQ > 2) BEGIN
//                 SLOT2 = G1
//                 IF (D2H REQ > 3) BEGIN // H1-G1-G1-G1
//                     SLOT3 = G1
//                 END
//                 ELSE [TRY TO FIT MEM MESSAGES] // H1-G1-G1-NA
//             END
//             ELSE [TRY TO FIT MEM MESSAGES] // H1-G1-NA-NA
//         END
//         ELSE [TRY TO FIT MEM MESSAGES] // H1-NA-NA-NA
//     END
// END
// ELSE IF ((D2H RESP > 0) || (D2H DATA > 0)) ? ((MSG_PRIORITY == 1) || (D2H REQ = 0)) BEGIN
//     IF (MDH) BEGIN // H2-G0-G0-G0
//         SLOT0 = H2
//         SLOT1 = G0
//         SLOT2 = G0
//         SLOT3 = G0
//     END
//     ELSE BEGIN
//         SLOT0 = H0
//         IF (D2H DATA > 0) BEGIN  // H0-G0-G0-G0
//             SLOT1 = G0
//             SLOT2 = G0
//             SLOT3 = G0
//         END
//         ELSE BEGIN
//             IF (D2H REQ > 0) BEGIN
//                 SLOT1 = G1
//                 IF (D2H REQ > 1) BEGIN
//                     SLOT2 = G1
//                     IF (D2H REQ > 2) BEGIN // H0-G1-G1-G1
//                         SLOT3 = G1
//                     END
//                     ELSE [TRY TO FIT MEM MESSAGES] // H0-G1-G1-NA
//                 END
//                 ELSE [TRY TO FIT MEM MESSAGES] // H0-G1-NA-NA
//             END
//             ELSE [TRY TO FIT MEM MESSAGES] // H0-NA-NA-NA
//         END
//     END
// END
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

    casez ({rr_arb_req_rsp_r, cxl_cache_mdh_s, cxl_ch_d2h_hdr_vld, cxl_ch_d2h_rsp_vld, cxl_ch_d2h_req_vld})
        // IF (MSG_PRIORITY == 0) && (D2H REQ > 0) && (D2H RESP = X) && (D2H DATA > 0)
        12'b0_?_???1_??_???1: begin
            // RULE FORMAT: H1-G0-G0-G0 
            cache_hdr.Slot0 = CXL_HDR_SLOT_H1;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot3 = CXL_HDR_SLOT_G0;
            cache_hdr.BE    = ~cxl_ch_d2h_be[0];

            // H1 - CXL.cache Req + CXL.cache Data Header (96 bits)
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd1, Slot:{cxl_d2h_hdr_msg_s[0], cxl_d2h_req_msg_s[0], cache_hdr}};
            // G0 - CXL.cache D2H Data
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[127:0]};
            // G0 - CXL.cache D2H Data
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[255:128]};
            // G0 - CXL.cache D2H Data
            cache_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[383:256]};
        end
        // IF (MSG_PRIORITY == X) && (D2H REQ = 1) && (D2H RESP = 0) && (D2H DATA = 0)
        12'b?_?_???0_?0_0001: begin
            // RULE FORMAT: H1-NA-NA-NA 
            cache_hdr.Slot0 = CXL_HDR_SLOT_H1;
            cache_hdr.Slot1 = cache_mem_hdr_s.Slot1;
            cache_hdr.Slot2 = cache_mem_hdr_s.Slot2;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot3;

            // H1 - CXL.cache Req + CXL.cache Data Header (96 bits)
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_d2h_hdr_msg_s[0], cxl_d2h_req_msg_s[0], cache_hdr}};
            // N/A
            cache_slot.Slot1 = cache_mem_slot_s.Slot1;
            // N/A
            cache_slot.Slot2 = cache_mem_slot_s.Slot2;
            // N/A
            cache_slot.Slot3 = cache_mem_slot_s.Slot3;
        end
        // IF ((MSG_PRIORITY == 0) && (D2H REQ = 1) && (D2H RESP > 0) && (D2H DATA = 0))
        // IF ((MSG_PRIORITY == 0) && (D2H REQ = 2) && (D2H RESP = X) && (D2H DATA = 0)) OR
        // IF ((MSG_PRIORITY == 1) && (D2H REQ = 2) && (D2H RESP = 0) && (D2H DATA = 0))
        12'b0_?_???0_?1_0001, 12'b0_?_???0_??_0011, 12'b1_?_???0_?0_0011: begin
            // RULE FORMAT: H1-G1-NA-NA 
            cache_hdr.Slot0 = CXL_HDR_SLOT_H1;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot2 = cache_mem_hdr_s.Slot1;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot2;

            // H1 - CXL.cache Req + CXL.cache Data Header (96 bits)
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_d2h_hdr_msg_s[0], cxl_d2h_req_msg_s[0], cache_hdr}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_d2h_rsp_msg_s[1], cxl_d2h_rsp_msg_s[0], cxl_d2h_req_msg_s[1]}};
            // N/A
            cache_slot.Slot2 = cache_mem_slot_s.Slot1;
            // N/A
            cache_slot.Slot3 = cache_mem_slot_s.Slot2;
        end
        // IF ((MSG_PRIORITY == 0) && (D2H REQ = 3) && (D2H RESP = X) && (D2H DATA = 0)) OR
        // IF ((MSG_PRIORITY == 1) && (D2H REQ = 3) && (D2H RESP = 0) && (D2H DATA = 0))
        12'b0_?_???0_??_0111, 12'b1_?_???0_?0_0111: begin
            // RULE FORMAT: H1-G1-G1-NA 
            cache_hdr.Slot0 = CXL_HDR_SLOT_H1;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot1;

            // H1 - CXL.cache Req + CXL.cache Data Header (96 bits)
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_d2h_hdr_msg_s[0], cxl_d2h_req_msg_s[0], cache_hdr}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_d2h_rsp_msg_s[1], cxl_d2h_rsp_msg_s[0], cxl_d2h_req_msg_s[1]}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, DUMMY_D2H_RSP, DUMMY_D2H_RSP, cxl_d2h_req_msg_s[2]}};
            // N/A
            cache_slot.Slot3 = cache_mem_slot_s.Slot1;
        end
        // IF ((MSG_PRIORITY == 0) && (D2H REQ = 4) && (D2H RESP = X) && (D2H DATA = 0)) OR
        // IF ((MSG_PRIORITY == 1) && (D2H REQ = 4) && (D2H RESP = 0) && (D2H DATA = 0))
        12'b0_?_???0_??_1111, 12'b1_?_???0_?0_1111: begin
            // RULE FORMAT: H1-G1-G1-G1 
            cache_hdr.Slot0 = CXL_HDR_SLOT_H1;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot3 = CXL_HDR_SLOT_G1;

            // H1 - CXL.cache Req + CXL.cache Data Header (96 bits)
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{cxl_d2h_hdr_msg_s[0], cxl_d2h_req_msg_s[0], cache_hdr}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_d2h_rsp_msg_s[1], cxl_d2h_rsp_msg_s[0], cxl_d2h_req_msg_s[1]}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, DUMMY_D2H_RSP, DUMMY_D2H_RSP, cxl_d2h_req_msg_s[2]}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            cache_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, DUMMY_D2H_RSP, DUMMY_D2H_RSP, cxl_d2h_req_msg_s[3]}};
        end
        // IF ((MSG_PRIORITY == 0) && (D2H REQ = 0) && (D2H RESP = X) && (D2H DATA > 0) && MDH) OR
        // IF ((MSG_PRIORITY == 1) && (D2H REQ = X) && (D2H RESP = X) && (D2H DATA > 0) && MDH)
        12'b0_1_??11_??_???0, 12'b1_1_??11_??_????: begin
            // RULE FORMAT: H2-G0-G0-G0
            cache_hdr.Slot0 = CXL_HDR_SLOT_H2;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot3 = CXL_HDR_SLOT_G0;

            // H2 - 4 x CXL.cache Data Header + CXL.cache Resp (88 bits)
            cache_slot.Slot0 = '{Valid:1'b1, Data:cxl_ch_d2h_hdr_be_vld, Slot:{8'd0, cxl_d2h_rsp_msg_s[0],
                                                                                       cxl_ch_d2h_hdr_be_vld[3] ? cxl_d2h_hdr_msg_s[3] : 17'd0,
                                                                                       cxl_ch_d2h_hdr_be_vld[2] ? cxl_d2h_hdr_msg_s[2] : 17'd0,
                                                                                       cxl_ch_d2h_hdr_be_vld[1] ? cxl_d2h_hdr_msg_s[1] : 17'd0,
                                                                                       cxl_ch_d2h_hdr_be_vld[0] ? cxl_d2h_hdr_msg_s[0] : 17'd0,
                                                                                       cache_hdr}};
            // G0 - CXL.cache D2H Data
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[127:0]};
            // G0 - CXL.cache D2H Data
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[255:128]};
            // G0 - CXL.cache D2H Data
            cache_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[383:256]};
        end
        // IF ((MSG_PRIORITY == 0) && (D2H REQ = 0) && (D2H RESP = X) && (D2H DATA > 0) && !MDH) OR
        // IF ((MSG_PRIORITY == 1) && (D2H REQ = X) && (D2H RESP = X) && (D2H DATA > 0) && !MDH)
        12'b0_0_???1_??_???0, 12'b1_0_???1_??_????: begin
            // RULE FORMAT: H0-G0-G0-G0
            cache_hdr.Slot0 = CXL_HDR_SLOT_H0;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G0;
            cache_hdr.Slot3 = CXL_HDR_SLOT_G0;
            cache_hdr.BE    = ~cxl_ch_d2h_be[0];

            // H0 - CXL.cache Data Header + 2 CXL.cache Resp + CXL.mem NDR (87 bits)
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd1, Slot:{9'd0, cxl_s2m_ndr_msg_t[0], cxl_d2h_rsp_msg_s[1], cxl_d2h_rsp_msg_s[0], cxl_d2h_hdr_msg_s[0], cache_hdr}};
            // G0 - CXL.cache D2H Data
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[127:0]};
            // G0 - CXL.cache D2H Data
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[255:128]};
            // G0 - CXL.cache D2H Data
            cache_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[383:256]};
        end
        // IF (MSG_PRIORITY == X) && (D2H REQ = 0) && (D2H RESP > 0) && (D2H DATA = 0)
        12'b?_?_???0_?1_???0: begin
            // RULE FORMAT: H0-NA-NA-NA 
            cache_hdr.Slot0 = CXL_HDR_SLOT_H0;
            cache_hdr.Slot1 = cache_mem_hdr_s.Slot1;
            cache_hdr.Slot2 = cache_mem_hdr_s.Slot2;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot3;

            // H0 - CXL.cache Data Header + 2 CXL.cache Resp + CXL.mem NDR (87 bits)
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_s2m_ndr_msg_t[0], cxl_d2h_rsp_msg_s[1], cxl_d2h_rsp_msg_s[0], cxl_d2h_hdr_msg_s[0], cache_hdr}};
            // N/A
            cache_slot.Slot1 = cache_mem_slot_s.Slot1;
            // N/A
            cache_slot.Slot2 = cache_mem_slot_s.Slot2;
            // N/A
            cache_slot.Slot3 = cache_mem_slot_s.Slot3;
        end
        // IF ((MSG_PRIORITY == 1) && (D2H REQ = 1) && (D2H RESP > 0) && (D2H DATA = 0))
        12'b1_?_???0_?1_0001: begin
            // RULE FORMAT: H0-G1-NA-NA 
            cache_hdr.Slot0 = CXL_HDR_SLOT_H0;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot2 = cache_mem_hdr_s.Slot1;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot2;

            // H0 - CXL.cache Data Header + 2 CXL.cache Resp + CXL.mem NDR (87 bits)
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_s2m_ndr_msg_t[0], cxl_d2h_rsp_msg_s[1], cxl_d2h_rsp_msg_s[0], cxl_d2h_hdr_msg_s[0], cache_hdr}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0,  DUMMY_D2H_RSP, DUMMY_D2H_RSP, cxl_d2h_req_msg_s[0]}};
            // N/A
            cache_slot.Slot2 = cache_mem_slot_s.Slot1;
            // N/A
            cache_slot.Slot3 = cache_mem_slot_s.Slot2;
        end
        // IF ((MSG_PRIORITY == 1) && (D2H REQ = 2) && (D2H RESP > 0) && (D2H DATA = 0))
        12'b1_?_???0_?1_0011: begin
            // RULE FORMAT: H0-G1-G1-NA 
            cache_hdr.Slot0 = CXL_HDR_SLOT_H0;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot3 = cache_mem_hdr_s.Slot1;

            // H0 - CXL.cache Data Header + 2 CXL.cache Resp + CXL.mem NDR (87 bits)
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_s2m_ndr_msg_t[0], cxl_d2h_rsp_msg_s[1], cxl_d2h_rsp_msg_s[0], cxl_d2h_hdr_msg_s[0], cache_hdr}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, DUMMY_D2H_RSP, DUMMY_D2H_RSP, cxl_d2h_req_msg_s[0]}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, DUMMY_D2H_RSP, DUMMY_D2H_RSP, cxl_d2h_req_msg_s[1]}};
            // N/A
            cache_slot.Slot3 = cache_mem_slot_s.Slot1;
        end
        // IF ((MSG_PRIORITY == 1) && (D2H REQ > 2) && (D2H RESP > 0) && (D2H DATA = 0))
        12'b1_?_???0_?1_?111: begin
            // RULE FORMAT: H0-G1-G1-G1 
            cache_hdr.Slot0 = CXL_HDR_SLOT_H0;
            cache_hdr.Slot1 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot2 = CXL_HDR_SLOT_G1;
            cache_hdr.Slot3 = CXL_HDR_SLOT_G1;

            // H0 - CXL.cache Data Header + 2 CXL.cache Resp + CXL.mem NDR (87 bits)
            cache_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_s2m_ndr_msg_t[0], cxl_d2h_rsp_msg_s[1], cxl_d2h_rsp_msg_s[0], cxl_d2h_hdr_msg_s[0], cache_hdr}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            cache_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, DUMMY_D2H_RSP, DUMMY_D2H_RSP, cxl_d2h_req_msg_s[0]}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            cache_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, DUMMY_D2H_RSP, DUMMY_D2H_RSP, cxl_d2h_req_msg_s[1]}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            cache_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, DUMMY_D2H_RSP, DUMMY_D2H_RSP, cxl_d2h_req_msg_s[2]}};
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
// IF (MDH) BEGIN
//     G6-G0-G0
// END
// ELSE IF (S2M DATA > 0) BEGIN
//     G4-G0-G0
// END
// ELSE BEGIN
//     G5-G5-G5
// END
//
// -------------------------------------------------------------------------------------
always_comb begin
    cache_mem_hdr_s  = '{ Slot0:CXL_HDR_SLOT_H4, Slot1:CXL_HDR_SLOT_G5, Slot2:CXL_HDR_SLOT_G5, Slot3:CXL_HDR_SLOT_G5, ProtType: CXL_HDR_PROT, default: '0};
    cache_mem_slot_s = '0;
    casez ({cxl_mem_mdh_s, cxl_ch_s2m_drc_vld[0]})
        // IF (MDH == 1) && (S2M_DATA > 1)
        2'b11: begin
            // RULE FORMAT: G6-G0-G0
            cache_mem_hdr_s.Slot1 = CXL_HDR_SLOT_G6;
            cache_mem_hdr_s.Slot2 = CXL_HDR_SLOT_G0;
            cache_mem_hdr_s.Slot3 = CXL_HDR_SLOT_G0;
            
            // G6 - 3 x CXL.mem DRS Header (120 bits)
            cache_mem_slot_s.Slot1 = '{Valid:1'b1, Data:{1'd0, cxl_ch_s2m_drc_vld[2:0]}, Slot:{8'd0, cxl_s2m_hdr_msg_s[2], cxl_s2m_hdr_msg_s[1], cxl_s2m_hdr_msg_s[0]}};
            // G0 - CXL.mem DRS Data
            cache_mem_slot_s.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[127:0]};
            // G0 - CXL.mem DRS Data
            cache_mem_slot_s.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[255:128]};
        end
        // IF (MDH == 0) && (S2M_DATA > 0)
        2'b01: begin
            // RULE FORMAT: G4-G0-G0
            cache_mem_hdr_s.Slot1 = CXL_HDR_SLOT_G4;
            cache_mem_hdr_s.Slot2 = CXL_HDR_SLOT_G0;
            cache_mem_hdr_s.Slot3 = CXL_HDR_SLOT_G0;
            
            // G4 - CXL.mem DRS Header + 2 x CXL.mem NDR (100 bits)
            cache_mem_slot_s.Slot1 = '{Valid:1'b1, Data:4'd1, Slot:{28'd0, (cache_hdr.Slot0 == CXL_HDR_SLOT_H0) ? {s2m_ndr_msg_order({DUMMY_S2M_NDR,cxl_s2m_ndr_msg_t[1]})} : {s2m_ndr_msg_order({cxl_s2m_ndr_msg_t[1],cxl_s2m_ndr_msg_t[0]})}, cxl_s2m_hdr_msg_s[0]}};
            // G0 - CXL.mem DRS Data
            cache_mem_slot_s.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[127:0]};
            // G0 - CXL.mem DRS Data
            cache_mem_slot_s.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[255:128]};
        end
        default: begin
            // RULE FORMAT: G5-G5-G5
            cache_mem_hdr_s.Slot1 = CXL_HDR_SLOT_G5;
            cache_mem_hdr_s.Slot2 = CXL_HDR_SLOT_G5;
            cache_mem_hdr_s.Slot3 = CXL_HDR_SLOT_G5;

            // G5 - 2 x CXL.mem NDR (60 bits)
            cache_mem_slot_s.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{68'd0, (cache_hdr.Slot0 == CXL_HDR_SLOT_H0) ? {s2m_ndr_msg_order({DUMMY_S2M_NDR,cxl_s2m_ndr_msg_t[1]})} : {s2m_ndr_msg_order({cxl_s2m_ndr_msg_t[1],cxl_s2m_ndr_msg_t[0]})}}};
            // G5 - 2 x CXL.mem NDR (60 bits)
            cache_mem_slot_s.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{68'd0, DUMMY_S2M_NDR, DUMMY_S2M_NDR}};
            // G5 - 2 x CXL.mem NDR (60 bits)
            cache_mem_slot_s.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{68'd0, DUMMY_S2M_NDR, DUMMY_S2M_NDR}};
        end
    endcase
end
// -------------------------------------------------------------------------------------




// -------------------------------------------------------------------------------------
// CXL.mem Packing Rules
// -------------------------------------------------------------------------------------
//
// MSG_PRIORITY - S2M RESP (0) OR S2M DATA (1)
// 
// IF (S2M RESP > 0) && ((MSG_PRIORITY == 0) || (S2M DATA = 0)) BEGIN
//     IF (S2M RESP > 1) BEGIN
//         SLOT0 = H4
//      IF (MDH) BEGIN // H4-G6-G0-G0
//             SLOT1 = G6
//             SLOT2 = G0
//             SLOT3 = G0
//      END
//      ELSE IF (S2M DATA > 0) BEGIN // H4-G4-G0-G0
//             SLOT1 = G4
//             SLOT2 = G0
//             SLOT3 = G0
//      END
//      ELSE [TRY TO FIT CACHE MESSAGES] // H4-NA-NA-NA
//  END
//  ELSE BEGIN
//         SLOT0 = H3
//      IF (S2M DATA > 0) BEGIN  // H3-G0-G0-G0
//             SLOT1 = G0
//             SLOT2 = G0
//             SLOT3 = G0
//      END
//      ELSE [TRY TO FIT CACHE MESSAGES] // H3-NA-NA-NA
//  END
// END
// ELSE IF (S2M DATA > 0) && ((MSG_PRIORITY == 1) || (S2M RESP = 0)) BEGIN
//  IF (MDH) BEGIN // H5-G0-G0-G0
//         SLOT0 = H5
//         SLOT1 = G0
//         SLOT2 = G0
//         SLOT3 = G0
//  END
//  ELSE BEGIN // H3-G0-G0-G0
//         SLOT0 = H3
//         SLOT1 = G0
//         SLOT2 = G0
//         SLOT3 = G0
//  END
// END
// ELSE [CACHE PRIORITY]
//
// -------------------------------------------------------------------------------------
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

    casez ({rr_arb_mem_data_r, cxl_mem_mdh_s, cxl_ch_s2m_drc_vld, cxl_ch_s2m_ndr_vld})
        // IF (MSG_PRIORITY == 0) && (MDH == 1) && (S2M_DATA > 1) && (S2M RESP == 2)
        7'b0_1_?11_11: begin
            // RULE FORMAT: H4-G6-G0-G0
            mem_hdr.Slot0 = CXL_HDR_SLOT_H4;
            mem_hdr.Slot1 = CXL_HDR_SLOT_G6;
            mem_hdr.Slot2 = CXL_HDR_SLOT_G0;
            mem_hdr.Slot3 = CXL_HDR_SLOT_G0;

            // H4 - 2 x CXL.mem NDR (60 bits)
            mem_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{36'd0,s2m_ndr_msg_order({cxl_s2m_ndr_msg_t[1],cxl_s2m_ndr_msg_t[0]}), mem_hdr}};
            // G6 - 3 x CXL.mem DRS Header (120 bits)
            mem_slot.Slot1 = '{Valid:1'b1, Data:{1'd0, cxl_ch_s2m_drc_vld[2:0]}, Slot:{8'd0, cxl_s2m_hdr_msg_s[2], cxl_s2m_hdr_msg_s[1], cxl_s2m_hdr_msg_s[0]}};
            // G0 - CXL.mem DRS Data
            mem_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[127:0]};
            // G0 - CXL.mem DRS Data
            mem_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[255:128]};
        end
        // IF (MSG_PRIORITY == 0) && (MDH == 0) && (S2M_DATA > 0) && (S2M RESP == 2)
        7'b0_0_??1_11: begin
            // RULE FORMAT: H4-G4-G0-G0
            mem_hdr.Slot0 = CXL_HDR_SLOT_H4;
            mem_hdr.Slot1 = CXL_HDR_SLOT_G4;
            mem_hdr.Slot2 = CXL_HDR_SLOT_G0;
            mem_hdr.Slot3 = CXL_HDR_SLOT_G0;

            // H4 - 2 x CXL.mem NDR (60 bits)
            mem_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{36'd0,s2m_ndr_msg_order({cxl_s2m_ndr_msg_t[1],cxl_s2m_ndr_msg_t[0]}), mem_hdr}};
            // G4 - CXL.mem DRS Header + 2 x CXL.mem NDR (96 bits)
            mem_slot.Slot1 = '{Valid:1'b1, Data:4'd1, Slot:{32'd0, 56'd0, cxl_s2m_hdr_msg_s[0]}};
            // G0 - CXL.mem DRS Data
            mem_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[127:0]};
            // G0 - CXL.mem DRS Data
            mem_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[255:128]};
        end
        // IF (MSG_PRIORITY == 0) && (MDH == X) && (S2M_DATA > 0) && (S2M RESP = 1)
        // IF (MSG_PRIORITY == 0) && (MDH == 0) && (S2M_DATA > 0) && (S2M RESP = 0)
        // IF (MSG_PRIORITY == 1) && (MDH == 0) && (S2M_DATA > 0) && (S2M RESP == X)        
        7'b0_?_??1_01, 7'b0_0_??1_?0, 7'b1_0_??1_??: begin
            // RULE FORMAT: H3-G0-G0-G0
            mem_hdr.Slot0 = CXL_HDR_SLOT_H3;
            mem_hdr.Slot1 = CXL_HDR_SLOT_G0;
            mem_hdr.Slot2 = CXL_HDR_SLOT_G0;
            mem_hdr.Slot3 = CXL_HDR_SLOT_G0;

            // H3 - CXL.mem DRS Header + CXL.mem NDR (70 bits)
            mem_slot.Slot0 = '{Valid:1'b1, Data:4'd1, Slot:{26'd0, cxl_s2m_ndr_msg_t[0], cxl_s2m_hdr_msg_s[0], mem_hdr}};
            // G0 - CXL.mem DRS Data
            mem_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[127:0]};
            // G0 - CXL.mem DRS Data
            mem_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[255:128]};
            // G0 - CXL.mem DRS Data
            mem_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[383:256]};
        end
        // IF (MSG_PRIORITY == X) && (MDH == 0) && (S2M_DATA = 0) && (S2M RESP > 0)
        7'b?_0_??0_?1: begin
            // RULE FORMAT: H4-NA-NA-NA
            mem_hdr.Slot0 = CXL_HDR_SLOT_H4;
            mem_hdr.Slot1 = mem_cache_hdr_s.Slot1;
            mem_hdr.Slot2 = mem_cache_hdr_s.Slot2;
            mem_hdr.Slot3 = mem_cache_hdr_s.Slot3;
            
            mem_hdr.BE = mem_cache_hdr_s.BE;

            // H4 - 2 x CXL.mem NDR (60 bits)
            mem_slot.Slot0 = '{Valid:1'b1, Data:4'd0, Slot:{36'd0,s2m_ndr_msg_order({cxl_s2m_ndr_msg_t[1],cxl_s2m_ndr_msg_t[0]}), mem_hdr}};
            // N/A
            mem_slot.Slot1 = mem_cache_slot_s.Slot1;
            // N/A
            mem_slot.Slot2 = mem_cache_slot_s.Slot2;
            // N/A
            mem_slot.Slot3 = mem_cache_slot_s.Slot3;
        end
        // IF (MSG_PRIORITY == 1) && (MDH == 1) && (S2M_DATA > 1) && (S2M RESP > 0)
        // IF (MSG_PRIORITY == 0) && (MDH == 1) && (S2M_DATA > 1) && (S2M RESP = 0)
        7'b1_1_?11_??, 7'b0_1_?11_?0: begin
            // RULE FORMAT: H5-G0-G0-G0
            mem_hdr.Slot0 = CXL_HDR_SLOT_H5;
            mem_hdr.Slot1 = CXL_HDR_SLOT_G0;
            mem_hdr.Slot2 = CXL_HDR_SLOT_G0;
            mem_hdr.Slot3 = CXL_HDR_SLOT_G0;
            
            // H5 - 2 x CXL.mem DRS Header (80 bits)
            mem_slot.Slot0 = '{Valid:1'b1, Data:{2'd0, cxl_ch_s2m_drc_vld[1:0]}, Slot:{16'd0, cxl_s2m_hdr_msg_s[1], cxl_s2m_hdr_msg_s[0], mem_hdr}};
            // G0 - CXL.mem DRS Data
            mem_slot.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[127:0]};
            // G0 - CXL.mem DRS Data
            mem_slot.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[255:128]};
            // G0 - CXL.mem DRS Data
            mem_slot.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_s2m_data_msg_s[383:256]};
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
// IF (MDH) BEGIN
//     G3-G0-G0
// END
// IF (D2H DATA > 0) BEGIN
//     G2-G0-G0
// END
// ELSE BEGIN
//     G1-G1-G1
// END
//
// -------------------------------------------------------------------------------------
always_comb begin
    mem_cache_hdr_s  = '{ Slot0:CXL_HDR_SLOT_H4, Slot1:CXL_HDR_SLOT_G5, Slot2:CXL_HDR_SLOT_G5, Slot3:CXL_HDR_SLOT_G5, ProtType: CXL_HDR_PROT, default: '0};
    mem_cache_slot_s = '0;
    casez ({cxl_cache_mdh_s, cxl_ch_d2h_hdr_vld[0]})
        // IF (MDH == 1) && (D2H_DATA > 1)
        2'b11: begin
            // RULE FORMAT: G3-G0-G0
            mem_cache_hdr_s.Slot1 = CXL_HDR_SLOT_G3;
            mem_cache_hdr_s.Slot2 = CXL_HDR_SLOT_G0;
            mem_cache_hdr_s.Slot3 = CXL_HDR_SLOT_G0;
            
            // G3 - 4 x CXL.cache Data Header (68 bits)
            mem_cache_slot_s.Slot1 = '{Valid:1'b1, Data:cxl_ch_d2h_hdr_be_vld, Slot:{60'd0, cxl_ch_d2h_hdr_be_vld[3] ? cxl_d2h_hdr_msg_s[3] : 17'd0,
                                                                                            cxl_ch_d2h_hdr_be_vld[2] ? cxl_d2h_hdr_msg_s[2] : 17'd0,
                                                                                            cxl_ch_d2h_hdr_be_vld[1] ? cxl_d2h_hdr_msg_s[1] : 17'd0,
                                                                                            cxl_ch_d2h_hdr_be_vld[0] ? cxl_d2h_hdr_msg_s[0] : 17'd0}};
            // G0 - CXL.cache D2H Data
            mem_cache_slot_s.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[127:0]};
            // G0 - CXL.cache D2H Data
            mem_cache_slot_s.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[255:128]};
        end
        // IF (MDH == 0) && (D2H_DATA > 0)
        2'b01: begin
            // RULE FORMAT: G2-G0-G0
            mem_cache_hdr_s.Slot1 = CXL_HDR_SLOT_G2;
            mem_cache_hdr_s.Slot2 = CXL_HDR_SLOT_G0;
            mem_cache_hdr_s.Slot3 = CXL_HDR_SLOT_G0;
            
            mem_cache_hdr_s.BE    = ~cxl_ch_d2h_be[0];
            
            // G2 - CXL.cache Req + CXL.cache Data Header + CXL.cache Resp (116 bits)
            mem_cache_slot_s.Slot1 = '{Valid:1'b1, Data:4'd1, Slot:{12'd0, cxl_d2h_rsp_msg_s[0], cxl_d2h_hdr_msg_s[0], cxl_d2h_req_msg_s[0]}};
            // G0 - CXL.cache D2H Data
            mem_cache_slot_s.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[127:0]};
            // G0 - CXL.cache D2H Data
            mem_cache_slot_s.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:cxl_d2h_data_msg_s[255:128]};
        end
        default: begin
            // RULE FORMAT: G1-G1-G1
            mem_cache_hdr_s.Slot1 = CXL_HDR_SLOT_G1;
            mem_cache_hdr_s.Slot2 = CXL_HDR_SLOT_G1;
            mem_cache_hdr_s.Slot3 = CXL_HDR_SLOT_G1;
            
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            mem_cache_slot_s.Slot1 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, cxl_d2h_rsp_msg_s[1], cxl_d2h_rsp_msg_s[0], cxl_d2h_req_msg_s[0]}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            mem_cache_slot_s.Slot2 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, DUMMY_D2H_RSP, DUMMY_D2H_RSP, cxl_d2h_req_msg_s[1]}};
            // G1 - CXL.cache Req + 2 CXL.cache Resp (119 bits)
            mem_cache_slot_s.Slot3 = '{Valid:1'b1, Data:4'd0, Slot:{9'd0, DUMMY_D2H_RSP, DUMMY_D2H_RSP, cxl_d2h_req_msg_s[2]}};
        end
    endcase
end
// -------------------------------------------------------------------------------------





// -------------------------------------------------------------------------------------
// Message Arbitration
// -------------------------------------------------------------------------------------
always_comb begin
    rr_arb_req_rsp_nxt  = rr_arb_req_rsp_r;
    rr_arb_mem_data_nxt = rr_arb_mem_data_r;
    if ((|cxl_packer_slot_vld) & ~b_llctrl.s_cxl_ll_packer_halt) begin
        if (rr_arb_mem_data_r &  (|mem_hdr_vld) & ~(|mem_rsp_vld))
             rr_arb_mem_data_nxt = 1'b0;
        else 
        if (~rr_arb_mem_data_r & ~(|mem_hdr_vld) & (|mem_rsp_vld))
             rr_arb_mem_data_nxt = 1'b1;
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
        rr_arb_mem_data_r   <= #TP 1'b0;
    end
    else begin
        rr_arb_req_rsp_r    <= #TP rr_arb_req_rsp_nxt;
        rr_arb_mem_data_r   <= #TP rr_arb_mem_data_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Channel Halt Interface
// -------------------------------------------------------------------------------------
logic [$clog2(D2H_68B_REQ_NUM):0]    cxl_ch_d2h_req_cnt;       // Number of valid D2H Request Messages in the output flit
logic [$clog2(D2H_68B_RESP_NUM):0]   cxl_ch_d2h_rsp_cnt;       // Number of valid D2H Response Messages in the output flit
logic [$clog2(D2H_68B_DATA_NUM):0]   cxl_ch_d2h_hdr_cnt;       // Number of valid D2H Data Messages in the output flit
logic [$clog2(S2M_68B_NDR_NUM):0]    cxl_ch_s2m_ndr_cnt;       // Number of valid S2M NDR Messages in the output flit
logic [$clog2(S2M_68B_DATA_NUM):0]   cxl_ch_s2m_drc_cnt;       // Number of valid S2M DRC Messages in the output flit
logic [$clog2(S2M_68B_BI_SNP_NUM):0] cxl_ch_s2m_bi_snp_cnt;    // Number of valid S2M BI-Snoop Messages in the output flit

CXL_HDR_SLOT_0_t               cxl_flit_slot0_type_s;    // Loop variable, Slot Type in Slots 0
CXL_HDR_SLOT_N_t               cxl_flit_slotN_type_s;    // Loop variable, Slot Type in Slots 1-3
logic [127:0]                  cxl_flit_slot_data_s;     // Loop variable, Slot Data in Slots 0-3

assign cxl_prot_msg_halt_s  = ~pack_enable | cxl_prot_msg_halt;
assign cxl_prot_data_halt_s = ~pack_enable | cxl_prot_data_halt;

always_comb begin
    // Initialize message counters counters
    cxl_ch_d2h_req_cnt    = 3'd0;
    cxl_ch_d2h_rsp_cnt    = 2'd0;
    cxl_ch_d2h_hdr_cnt    = 3'd0;
    cxl_ch_s2m_ndr_cnt    = 2'd0;
    cxl_ch_s2m_drc_cnt    = 2'd0;
    cxl_ch_s2m_bi_snp_cnt = 1'd0;

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
                        // CXL.cache Data Header + 2 CXL.cache Resp + CXL.mem NDR
                        if (cxl_flit_slot_data_s[32]) cxl_ch_d2h_hdr_cnt = 1;
                        if (cxl_flit_slot_data_s[32+D2H_68B_DHDR_SIZE]) cxl_ch_d2h_rsp_cnt = 1;
                        if (cxl_flit_slot_data_s[32+D2H_68B_DHDR_SIZE+1*D2H_68B_RESP_SIZE]) cxl_ch_d2h_rsp_cnt = 2;
                        if (cxl_flit_slot_data_s[32+D2H_68B_DHDR_SIZE+2*D2H_68B_RESP_SIZE]) cxl_ch_s2m_ndr_cnt = 1;
                    end
                    CXL_HDR_SLOT_H1: begin
                        // CXL.cache Req + CXL.cache Data Header
                        if (cxl_flit_slot_data_s[32]) cxl_ch_d2h_req_cnt = 1;
                        if (cxl_flit_slot_data_s[32+1*D2H_68B_REQ_SIZE]) cxl_ch_d2h_hdr_cnt = 1;
                    end
                    CXL_HDR_SLOT_H2: begin
                        // 4 CXL.cache Data Header + CXL.cache Resp
                        if (cxl_flit_slot_data_s[32]) cxl_ch_d2h_hdr_cnt = 1;
                        if (cxl_flit_slot_data_s[32+1*D2H_68B_DHDR_SIZE]) cxl_ch_d2h_hdr_cnt = 2;
                        if (cxl_flit_slot_data_s[32+2*D2H_68B_DHDR_SIZE]) cxl_ch_d2h_hdr_cnt = 3;
                        if (cxl_flit_slot_data_s[32+3*D2H_68B_DHDR_SIZE]) cxl_ch_d2h_hdr_cnt = 4;
                        if (cxl_flit_slot_data_s[32+4*D2H_68B_DHDR_SIZE]) cxl_ch_d2h_rsp_cnt = 1;
                    end
                    CXL_HDR_SLOT_H3: begin
                        // CXL.mem DRS Header + CXL.mem NDR
                        if (cxl_flit_slot_data_s[32]) cxl_ch_s2m_drc_cnt = 1;
                        if (cxl_flit_slot_data_s[32+S2M_68B_DHDR_SIZE]) cxl_ch_s2m_ndr_cnt = 1;
                    end
                    CXL_HDR_SLOT_H4: begin
                        // 2 CXL.mem NDR
                        if (cxl_flit_slot_data_s[32]) cxl_ch_s2m_ndr_cnt = 1;
                        if (cxl_flit_slot_data_s[32+S2M_NDR_SIZE_NDL]) cxl_ch_s2m_ndr_cnt = 2;
                    end
                    CXL_HDR_SLOT_H5: begin
                        // 2 CXL.mem DRS Header
                        if (cxl_flit_slot_data_s[32]) cxl_ch_s2m_drc_cnt = 1;
                        if (cxl_flit_slot_data_s[32+S2M_68B_DHDR_SIZE]) cxl_ch_s2m_drc_cnt = 2;
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
                    // G1-G6 SLOT TYPES
                    CXL_HDR_SLOT_G1: begin
                        // CXL.cache Req + 2 CXL.cache Resp
                        if (cxl_flit_slot_data_s[0]) cxl_ch_d2h_req_cnt++;
                        if (cxl_flit_slot_data_s[0+D2H_68B_REQ_SIZE]) cxl_ch_d2h_rsp_cnt++;
                        if (cxl_flit_slot_data_s[0+D2H_68B_REQ_SIZE+D2H_68B_RESP_SIZE]) cxl_ch_d2h_rsp_cnt++;
                    end
                    CXL_HDR_SLOT_G2: begin
                        // CXL.cache Req + CXL.cache Data Header + CXL.cache Resp
                        if (cxl_flit_slot_data_s[0]) cxl_ch_d2h_req_cnt++;
                        if (cxl_flit_slot_data_s[0+D2H_68B_REQ_SIZE]) cxl_ch_d2h_hdr_cnt = 1;
                        if (cxl_flit_slot_data_s[0+D2H_68B_REQ_SIZE+D2H_68B_DHDR_SIZE]) cxl_ch_d2h_rsp_cnt++;
                    end
                    CXL_HDR_SLOT_G3: begin
                        // 4 CXL.cache Data Header
                        if (cxl_flit_slot_data_s[0]) cxl_ch_d2h_hdr_cnt = 1;
                        if (cxl_flit_slot_data_s[0+1*D2H_68B_DHDR_SIZE]) cxl_ch_d2h_hdr_cnt = 2;
                        if (cxl_flit_slot_data_s[0+2*D2H_68B_DHDR_SIZE]) cxl_ch_d2h_hdr_cnt = 3;
                        if (cxl_flit_slot_data_s[0+3*D2H_68B_DHDR_SIZE]) cxl_ch_d2h_hdr_cnt = 4;
                    end
                    CXL_HDR_SLOT_G4: begin
                        // CXL.mem DRS Header + 2 CXL.mem NDR
                        if (cxl_flit_slot_data_s[0]) cxl_ch_s2m_drc_cnt = 1;
                        if (cxl_flit_slot_data_s[0+S2M_68B_DHDR_SIZE]) cxl_ch_s2m_ndr_cnt++;
                        if (cxl_flit_slot_data_s[0+S2M_68B_DHDR_SIZE+S2M_NDR_SIZE_NDL]) cxl_ch_s2m_ndr_cnt++;
                    end
                    CXL_HDR_SLOT_G5: begin
                        // 3 CXL.mem NDR
                        if (cxl_flit_slot_data_s[0]) cxl_ch_s2m_ndr_cnt++;
                        if (cxl_flit_slot_data_s[0+S2M_NDR_SIZE_NDL]) cxl_ch_s2m_ndr_cnt++;
                    end
                    CXL_HDR_SLOT_G6: begin
                        // 3 CXL.mem DRS Header
                        if (cxl_flit_slot_data_s[0]) cxl_ch_s2m_drc_cnt = 1;
                        if (cxl_flit_slot_data_s[0+1*S2M_68B_DHDR_SIZE]) cxl_ch_s2m_drc_cnt = 2;
                        if (cxl_flit_slot_data_s[0+2*S2M_68B_DHDR_SIZE]) cxl_ch_s2m_drc_cnt = 3;
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
    b_txtl_llctrl.s_cxl_d2h_req_halt = '1;
    b_txtl_llctrl.s_cxl_d2h_rsp_halt = '1;
    b_txtl_llctrl.s_cxl_d2h_hdr_halt = '1;
    
    b_txtl_llctrl.s_cxl_d2h_req_halt[D2H_68B_REQ_NUM-1:0] = cxl_prot_msg_halt_s ? {D2H_68B_REQ_NUM{1'b1}}  : (cxl_ch_d2h_req_gnt_halt | (cxl_ch_d2h_req_vld & ({D2H_68B_REQ_NUM{1'b1}}  << cxl_ch_d2h_req_cnt)));
    b_txtl_llctrl.s_cxl_d2h_rsp_halt[D2H_68B_RESP_NUM-1:0] = cxl_prot_msg_halt_s ? {D2H_68B_RESP_NUM{1'b1}} : (cxl_ch_d2h_rsp_gnt_halt | (cxl_ch_d2h_rsp_vld & ({D2H_68B_RESP_NUM{1'b1}} << cxl_ch_d2h_rsp_cnt)));
    b_txtl_llctrl.s_cxl_d2h_hdr_halt[D2H_68B_DATA_NUM-1:0] = cxl_prot_msg_halt_s ? {D2H_68B_DATA_NUM{1'b1}} : (cxl_ch_d2h_hdr_gnt_halt | (cxl_ch_d2h_hdr_vld & ({D2H_68B_DATA_NUM{1'b1}} << cxl_ch_d2h_hdr_cnt)));
    b_txtl_llctrl.s_cxl_s2m_ndr_halt = '1;
    b_txtl_llctrl.s_cxl_s2m_hdr_halt = '1;
    
    b_txtl_llctrl.s_cxl_s2m_ndr_halt[S2M_68B_NDR_NUM-1:0] = cxl_prot_msg_halt_s ? {S2M_68B_NDR_NUM{1'b1}}  : (cxl_ch_s2m_ndr_gnt_halt | (cxl_ch_s2m_ndr_vld & ({S2M_68B_NDR_NUM{1'b1}}  << cxl_ch_s2m_ndr_cnt)));
    b_txtl_llctrl.s_cxl_s2m_hdr_halt[S2M_68B_DATA_NUM-1:0] = cxl_prot_msg_halt_s ? {S2M_68B_DATA_NUM{1'b1}} : (cxl_ch_s2m_drc_gnt_halt | (cxl_ch_s2m_drc_vld & ({S2M_68B_DATA_NUM{1'b1}} << cxl_ch_s2m_drc_cnt)));
    b_txtl_llctrl.s_cxl_s2m_bi_snp_halt = '1;
    
    // If at least one Data Header is set then release corresponding data channel halt
    b_txtl_llctrl.s_cxl_d2h_data_halt = '1;
    b_txtl_llctrl.s_cxl_d2h_data_halt[0] = cxl_prot_data_halt_s ? 1'b1 : ~((b_txtl_llctrl.s_cxl_d2h_data_vld[0] & cxl_packer_all_data & cxl_cache_data_ena) | ((|cxl_ch_d2h_hdr_vld) & (cxl_ch_d2h_hdr_cnt > 0)));
    b_txtl_llctrl.s_cxl_s2m_data_halt = '1;
    b_txtl_llctrl.s_cxl_s2m_data_halt[0] = cxl_prot_data_halt_s ? 1'b1 : ~((b_txtl_llctrl.s_cxl_s2m_data_vld[0] & cxl_packer_all_data & cxl_mem_data_ena) | ((|cxl_ch_s2m_drc_vld) & (cxl_ch_s2m_drc_cnt > 0)));
end
// -------------------------------------------------------------------------------------


function automatic [(2*S2M_NDR_SIZE_DL)-1:0] s2m_ndr_msg_order (
  input [(2*S2M_NDR_SIZE_DL-1):0] s2m_ndr_msg
);
  begin
//Order Devload for 2 S2M NDR input
  s2m_ndr_msg_order = {s2m_ndr_msg[S2M_NDR_SIZE_DL-1:S2M_NDR_SIZE_DL-S2M_NDR_DEVLOAD_WD], s2m_ndr_msg[(2*S2M_NDR_SIZE_DL-1):S2M_NDR_SIZE_DL], s2m_ndr_msg[S2M_NDR_SIZE_DL-1-S2M_NDR_DEVLOAD_WD:0]};
  end
  return s2m_ndr_msg_order;
endfunction

endmodule : DWC_cxl_mem_cache_packer_usp
