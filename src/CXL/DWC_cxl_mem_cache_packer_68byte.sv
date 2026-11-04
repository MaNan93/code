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
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_packer_68byte.sv#3 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Host Flit Packer
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_packer_68byte 
    import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)
                                          (
    input                                       core_clk,                // Core clock
    input                                       core_rst_n,              // Core active low asynchronous reset
    input                                       cfg_device_mode,
    input                                       cxl_pcie_flit_mode,
    input                                       cfg_cache_poison_start,  // CachePoisonInjectionStart
    output                                      cfg_cache_poison_busy,   // CachePoisonInjectionBusy
    input                                       cfg_mem_poison_start,    // MemPoisonInjectionStart
    output                                      cfg_mem_poison_busy,     // MemPoisonInjectionBusy

    DWC_cxl_txtl_llctrl_if.pack_slave_host_mp   b_txtl_host,             // Flit Packer to Transaction Layer Interface
    DWC_cxl_txtl_llctrl_if.pack_slave_dev_mp    b_txtl_dev,              // Flit Packer to Transaction Layer Interface
    DWC_cxl_pack_llctrl_if.slave_ctrl_mp        b_llctrl,                // Link Layer Controller to Flit Packer Interface
    DWC_cxl_pack_llctrl_if.master_pack_mp       b_pack                   // Flit Packer to Link Layer Controller Interface
);


typedef enum logic {
   CXL_CACHE = 1'b0,
   CXL_MEM   = 1'b1
} RR_ARB_STATE_t;


// -------------------------------------------------------------------------------------
// CXL.cache Table Signals
// -------------------------------------------------------------------------------------
CXL_HDR_t                   mux_cache_hdr_s;         // CXL.cache Packer Header
SLOT_HDR_t                  mux_cache_slot_s;        // CXL.cache Slot Structure
logic [TX_CRDIF_WIDTH-1:0]  mux_cache_req_vld_s;     // CXL.cache Request channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  mux_cache_rsp_vld_s;     // CXL.cache Response channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  mux_cache_hdr_vld_s;     // CXL.cache Data channel valid bit
logic [511:0]               mux_cache_data_msg_s;    // CXL.cache Data - 4x16B
logic                       mux_cache_data_vld_s;    // CXL.cache Data Valid
logic [63:0]                mux_cache_be_msg_s;      // CXL.cache Byte Enable Valid
CXL_HDR_t                   h2d_cache_hdr_s;         // CXL.cache H2D Packer Header
SLOT_HDR_t                  h2d_cache_slot_s;        // CXL.cache H2D Slot Structure
logic [TX_CRDIF_WIDTH-1:0]  h2d_cache_req_vld_s;     // CXL.cache H2D Request channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  h2d_cache_rsp_vld_s;     // CXL.cache H2D Response channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  h2d_cache_hdr_vld_s;     // CXL.cache H2D Data channel valid bit
CXL_HDR_t                   d2h_cache_hdr_s;         // CXL.cache D2H Packer Header
SLOT_HDR_t                  d2h_cache_slot_s;        // CXL.cache D2H Slot Structure
logic [TX_CRDIF_WIDTH-1:0]  d2h_cache_req_vld_s;     // CXL.cache D2H Request channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  d2h_cache_rsp_vld_s;     // CXL.cache D2H Response channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  d2h_cache_hdr_vld_s;     // CXL.cache D2H Data channel valid bit

// -------------------------------------------------------------------------------------
// CXL.mem Table Signals
// -------------------------------------------------------------------------------------
CXL_HDR_t                   mux_mem_hdr_s;           // CXL.mem Packer Header
SLOT_HDR_t                  mux_mem_slot_s;          // CXL.mem Slot Structure
logic [TX_CRDIF_WIDTH-1:0]  mux_mem_ndr_vld_s;       // CXL.mem Request/Response channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  mux_mem_hdr_vld_s;       // CXL.mem Data channel valid bit
logic [511:0]               mux_mem_data_msg_s;      // CXL.mem Data - 4x16B
logic                       mux_mem_data_vld_s;      // CXL.mem Data Valid
logic [63:0]                mux_mem_be_msg_s;        // CXL.mem Byte Enable
CXL_HDR_t                   m2s_mem_hdr_s;           // CXL.mem M2S Packer Header
SLOT_HDR_t                  m2s_mem_slot_s;          // CXL.mem M2S Slot Structure
logic [TX_CRDIF_WIDTH-1:0]  m2s_mem_req_vld_s;       // CXL.mem M2S Request channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  m2s_mem_hdr_vld_s;       // CXL.mem M2S RwD channel valid bit
logic                       m2s_mem_pending_s;       // CXL.mem M2S Pending Message
CXL_HDR_t                   s2m_mem_hdr_s;           // CXL.mem S2M Packer Header
SLOT_HDR_t                  s2m_mem_slot_s;          // CXL.mem S2M Slot Structure
logic [TX_CRDIF_WIDTH-1:0]  s2m_mem_rsp_vld_s;       // CXL.mem S2M Response channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  s2m_mem_hdr_vld_s;       // CXL.mem S2M DRC channel valid bit
logic                       s2m_mem_pending_s;       // CXL.mem S2M Pending Message


// Arbitration Signals
RR_ARB_STATE_t              rr_arb_state_r, rr_arb_state_nxt;       // CXL.cache/mem round-robin arbitration state

// Rule Packer Signals
CXL_HDR_t                   r_hdr_s;                                // Rule Packer Header
SLOT_HDR_t                  r_slot_s;                               // Rule Packer Slot Information
logic                       r_byte_en_r, r_byte_en_nxt;             // Indicates whether BE bit is set in the flit header

// Rollover Counter Signals
logic [4:0]                 roll_cntr_r, roll_cntr_nxt;             // Rollover Counter
logic [4:0]                 roll_cntr_inc_s;                        // Rollover Counter Increment
logic [2:0]                 roll_cntr_dec_s;                        // Rollover Counter Decrement
logic                       roll_data_prot_r, roll_data_prot_nxt;   // Rollover Protocol - indicates whether rollover data is CXL.cache (0) or CXL.mem (1)
logic                       roll_data_vld_r, roll_data_vld_nxt;     // Rollover Data Valid
logic [511:0]               roll_data_r, roll_data_nxt;             // Rollover Data
logic                       roll_all_data_s;                        // Rollover ADF flag
logic [63:0]                roll_data_be_r, roll_data_be_nxt;       // Rollover Data Byte Enable bits if enabled
logic [511:0]               roll_data_msg_s;                        // Rollover Protocol Data Mux
logic                       roll_data_vld_s;                        // Rollover Data Valid

// Slot Mapping Signals
CXL_HDR_t                   cxl_flit_hdr_s;                         // Slot Mapping Flit Header
logic [3:0]                 cxl_slot_vld_s;                         // Slot Mapping Slot Valid
SLOT_DATA_HDR_t             cxl_data_hdr_s;                         // Slot Mapping Number of Data Headers in Slot0-3
logic [511:0]               cxl_flit_s;                             // Slot Mapping output flit

// Channel Halt Generation Signals
logic                       cxl_prot_msg_halt_s;                    // CXL Protocol Message Channel Halt
logic                       cxl_prot_data_halt_s;                   // CXL Protocol Data Channel Halt - d2h_data and s2m_data
logic                       cxl_cache_data_ena_s;                   // CXL.cache Data Enable
logic                       cxl_mem_data_ena_s;                     // CXL.mem Data Enable

logic                       host_packer_ena_s;                      // Host Packer Enable
logic                       dev_packer_ena_s;                       // Device Packer Enable
logic                       host_packer_rev_s;                      // Host Packer Reverse
logic                       dev_packer_rev_s;                       // Device Packer Reverse
logic                       tl_pending_s;                           // Pending message on the TL Interface
logic                       host_tl_pending_s;                      // Host Pending message on the TL Interface
logic                       dev_tl_pending_s;                       // Device Pending message on the TL Interface

assign  tl_pending_s = 1'b0       || host_tl_pending_s 
     || dev_tl_pending_s  ;

// Combining and Passing app_pending signal
assign b_pack.s_cxl_app_pending = 0
 || b_txtl_host.s_cxl_cache_app_pending 
   || b_txtl_host.s_cxl_mem_app_pending 
 || b_txtl_dev.s_cxl_cache_app_pending 
   || b_txtl_dev.s_cxl_mem_app_pending 
 ; // CX_CXL_USP_PACKER_ENABLE                             
// -------------------------------------------------------------------------------------
// Assign output Flit Signals
// -------------------------------------------------------------------------------------
assign b_pack.s_cxl_packer_valid    = (|cxl_slot_vld_s) & ~b_llctrl.s_cxl_ll_packer_halt;
assign b_pack.s_cxl_packer_flit     = {{(CXL_DATA_WD-512){1'b0}}, cxl_flit_s};
assign b_pack.s_cxl_packer_all_data = roll_all_data_s;
assign b_pack.s_cxl_packer_last     = ~(|roll_cntr_nxt[4:2]);
assign b_pack.s_cxl_packer_idle     = !(tl_pending_s || (|roll_cntr_r) || mux_cache_slot_s.Slot0.Valid 
   || mux_mem_slot_s.Slot0.Valid );
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Valid signals for credit tracking
// -------------------------------------------------------------------------------------
assign b_pack.s_cxl_cache_req_valid  = mux_cache_req_vld_s;
assign b_pack.s_cxl_cache_rsp_valid  = mux_cache_rsp_vld_s;
assign b_pack.s_cxl_cache_dhdr_valid = mux_cache_hdr_vld_s;
assign b_pack.s_cxl_mem_ndr_valid    = mux_mem_ndr_vld_s;
assign b_pack.s_cxl_mem_dr_valid     = mux_mem_hdr_vld_s;
assign b_pack.s_cxl_mem_bi_valid     = '0 ;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Host/Device Packer Select
// -------------------------------------------------------------------------------------
assign host_packer_ena_s =  cfg_device_mode & (!cxl_pcie_flit_mode);
assign dev_packer_ena_s  = !cfg_device_mode & (!cxl_pcie_flit_mode);

assign host_packer_rev_s = !cfg_device_mode;
assign dev_packer_rev_s  = cfg_device_mode;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Halt Signals
// -------------------------------------------------------------------------------------
assign roll_all_data_s = |roll_cntr_r[4:2];
assign cxl_flit_hdr_s  = cxl_flit_s[31:0];

// Halt Protocol Message Channels when CXL Flit Packer is under back pressure or
// when the current flit is all data flit or Control Flit is valid on the Flit Packer inputs
assign cxl_prot_msg_halt_s  = b_llctrl.s_cxl_ll_packer_halt | roll_all_data_s;

// Halt Protocol Data Channels when CXL Flit Packer is under back pressure or
// Control Flit is valid on the Flit Packer inputs when the current flit is not an all data flit
assign cxl_prot_data_halt_s = b_llctrl.s_cxl_ll_packer_halt;

assign cxl_cache_data_ena_s = !(((roll_cntr_r == 5'd4) || (r_byte_en_r && (roll_cntr_r == 5'd5))) ? roll_data_vld_r : 1'b0) && !roll_data_prot_r ;
assign cxl_mem_data_ena_s   = !(((roll_cntr_r == 5'd4) || (r_byte_en_r && (roll_cntr_r == 5'd5))) ? roll_data_vld_r : 1'b0) && roll_data_prot_r  ;

// Halt Link Layer Control Flit only when the current flit is all data flit as defined in CXL Spec:
// - Control flits cannot be interleaved with all data flits. This also implies that when an
//   all-data flit is expected following a protocol flit (due to Rollover), the Tx cannot
//   send a Control flit before the all data flit.
assign b_pack.s_cxl_packer_llctrl_halt = roll_all_data_s;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL.cache H2D-D2H mux
// -------------------------------------------------------------------------------------
always_comb begin
    if (host_packer_ena_s) begin
        mux_cache_hdr_s      = h2d_cache_hdr_s ;
        mux_cache_slot_s     = h2d_cache_slot_s ;
        mux_cache_req_vld_s  = h2d_cache_req_vld_s ;
        mux_cache_rsp_vld_s  = h2d_cache_rsp_vld_s ;
        mux_cache_hdr_vld_s  = h2d_cache_hdr_vld_s ;
        mux_cache_data_msg_s = b_txtl_host.s_cxl_h2d_data[0] ;
        mux_cache_data_vld_s = b_txtl_host.s_cxl_h2d_data_vld[0] ;
        mux_cache_be_msg_s   = 64'd0;
    end
    else begin
        mux_cache_hdr_s      = d2h_cache_hdr_s ;
        mux_cache_slot_s     = d2h_cache_slot_s ;
        mux_cache_req_vld_s  = d2h_cache_req_vld_s ;
        mux_cache_rsp_vld_s  = d2h_cache_rsp_vld_s ;
        mux_cache_hdr_vld_s  = d2h_cache_hdr_vld_s ;
        mux_cache_data_msg_s = b_txtl_dev.s_cxl_d2h_data[0] ;
        mux_cache_data_vld_s = b_txtl_dev.s_cxl_d2h_data_vld[0] ;
        mux_cache_be_msg_s   = b_txtl_dev.s_cxl_d2h_be[0] ;
    end
end

// -------------------------------------------------------------------------------------
// CXL.mem M2S-S2M mux
// -------------------------------------------------------------------------------------
always_comb begin
    if (host_packer_ena_s) begin
        mux_mem_hdr_s        =    m2s_mem_hdr_s ;
        mux_mem_slot_s       =    m2s_mem_slot_s ;
        mux_mem_ndr_vld_s    =    m2s_mem_req_vld_s ;
        mux_mem_hdr_vld_s    =    m2s_mem_hdr_vld_s ;
        mux_mem_data_msg_s   =    b_txtl_host.s_cxl_m2s_data[0] ;
        mux_mem_data_vld_s   =    b_txtl_host.s_cxl_m2s_data_vld[0] ;
        mux_mem_be_msg_s     =    b_txtl_host.s_cxl_m2s_be[0] ;
    end
    else begin
        mux_mem_hdr_s        =    s2m_mem_hdr_s ;
        mux_mem_slot_s       =    s2m_mem_slot_s ;
        mux_mem_ndr_vld_s    =    s2m_mem_rsp_vld_s ;
        mux_mem_hdr_vld_s    =    s2m_mem_hdr_vld_s ;
        mux_mem_data_msg_s   =    b_txtl_dev.s_cxl_s2m_data[0] ;
        mux_mem_data_vld_s   =    b_txtl_dev.s_cxl_s2m_data_vld[0] ;
        mux_mem_be_msg_s     = 64'd0;
    end
end


// -------------------------------------------------------------------------------------
// Protocol Arbitration between CXL.cache and CXL.mem protocols
// -------------------------------------------------------------------------------------
always_comb begin
    if (!cxl_prot_msg_halt_s && mux_cache_slot_s.Slot0.Valid  && ((rr_arb_state_r == CXL_CACHE) || ~mux_mem_slot_s.Slot0.Valid) ) begin
        r_slot_s      = mux_cache_slot_s;
        r_byte_en_nxt = mux_cache_hdr_s.BE;

        rr_arb_state_nxt = CXL_MEM;
    end else
    if (!cxl_prot_msg_halt_s && mux_mem_slot_s.Slot0.Valid && ((rr_arb_state_r == CXL_MEM) || !mux_cache_slot_s.Slot0.Valid) ) begin
        r_slot_s      = mux_mem_slot_s;
        r_byte_en_nxt = mux_mem_hdr_s.BE;

        rr_arb_state_nxt = CXL_CACHE;
    end else 
    begin
        r_slot_s      = '0;
        r_byte_en_nxt = r_byte_en_r;

        if (roll_all_data_s) begin
            {r_slot_s.Slot3.Slot, r_slot_s.Slot2.Slot, r_slot_s.Slot1.Slot, r_slot_s.Slot0.Slot} = roll_data_msg_s;
        end
        else begin
            r_slot_s.Slot0.Slot[2]     = b_llctrl.s_cxl_hdr_ack_bit;
            if (host_packer_ena_s) r_slot_s.Slot0.Slot[16:5]  = {3'h5, 3'h5, 3'h5, 3'h5}; // Host
            else                   r_slot_s.Slot0.Slot[16:5]  = {3'h5, 3'h5, 3'h5, 3'h4}; // Device
            r_slot_s.Slot0.Slot[23:20] = b_llctrl.s_cxl_hdr_rsp_crd;
            r_slot_s.Slot0.Slot[27:24] = b_llctrl.s_cxl_hdr_req_crd;
            r_slot_s.Slot0.Slot[31:28] = b_llctrl.s_cxl_hdr_data_crd;
        end
        
        rr_arb_state_nxt = rr_arb_state_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        rr_arb_state_r      <= #TP CXL_CACHE;
        r_byte_en_r         <= #TP 1'b0;
    end
    else begin
        rr_arb_state_r      <= #TP rr_arb_state_nxt;
        r_byte_en_r         <= #TP r_byte_en_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Slot Mapping
//
// CXL Specification Rules:
// - If there's no rollover, each of the 4 slots will be packed independently.
// - If there's a rollover of 1 16B data chunk, Slot 1 must necessarily contain the rollover data chunk. Slot 0, Slot 2 and Slot 3 will be packed independently.
// - If there's a rollover of 2 16B data chunks, Slots 1 and Slots 2 must necessarily contain the 2 rollover data chunks. Slot 0 and Slot 3 will be packed independently.
// - If there's a rollover of 3 16B data chunks, Slots 1, Slots 2 and Slots 3 must necessarily contain the 3 rollover data chunks. Slot 0 will be packed independently.
// - If there's a rollover of more than 3 16B data chunks, the next flit must necessarily be an all data flit.
// 
// -------------------------------------------------------------------------------------
always_comb begin
    r_hdr_s = r_slot_s.Slot0.Slot[31:0];
    case ({roll_all_data_s, roll_cntr_r[1:0]})
        3'b000 : begin
            cxl_slot_vld_s = {r_slot_s.Slot3.Valid, r_slot_s.Slot2.Valid, r_slot_s.Slot1.Valid, r_slot_s.Slot0.Valid};
            cxl_data_hdr_s = {r_slot_s.Slot3.Data,  r_slot_s.Slot2.Data,  r_slot_s.Slot1.Data,  r_slot_s.Slot0.Data};
            cxl_flit_s     = {r_slot_s.Slot3.Slot, r_slot_s.Slot2.Slot,  r_slot_s.Slot1.Slot,  r_slot_s.Slot0.Slot};
        end
        3'b001 : begin
            r_hdr_s.Slot3 = r_hdr_s.Slot2;   // Slot 3, Slot 2 and Slot 0 are packed independently
            r_hdr_s.Slot2 = r_hdr_s.Slot1;   // Slot 3, Slot 2 and Slot 0 are packed independently
            r_hdr_s.Slot1 = CXL_HDR_SLOT_G0; // Slot 1 - rollover data chunk

            cxl_slot_vld_s = {r_slot_s.Slot2.Valid, r_slot_s.Slot1.Valid, 1'b1, r_slot_s.Slot0.Valid};
            cxl_data_hdr_s = {r_slot_s.Slot2.Data,  r_slot_s.Slot1.Data,  4'd0, r_slot_s.Slot0.Data};
            //r_hdr_s.BE = r_hdr_s.BE & (|cxl_data_hdr_s);
            cxl_flit_s     = {r_slot_s.Slot2.Slot, r_slot_s.Slot1.Slot, ~r_byte_en_r ? roll_data_r[511:384] : {64'd0, roll_data_be_r}, r_slot_s.Slot0.Slot[127:32], r_hdr_s};
        end
        3'b010 : begin
            r_hdr_s.Slot3 = r_hdr_s.Slot1;   // Slot 3 and Slot 0 are packed independently
            r_hdr_s.Slot2 = CXL_HDR_SLOT_G0; // Slot 2 and Slot 1 - rollover data chunks
            r_hdr_s.Slot1 = CXL_HDR_SLOT_G0; // Slot 2 and Slot 1 - rollover data chunks

            cxl_slot_vld_s = {r_slot_s.Slot1.Valid, 1'b1, 1'b1, r_slot_s.Slot0.Valid};
            cxl_data_hdr_s = {r_slot_s.Slot1.Data,  4'd0, 4'd0, r_slot_s.Slot0.Data};
            //r_hdr_s.BE = r_hdr_s.BE & (|cxl_data_hdr_s);
            cxl_flit_s     = {r_slot_s.Slot1.Slot, ~r_byte_en_r ? {roll_data_r[511:384], roll_data_r[383:256]} : {{64'd0, roll_data_be_r}, roll_data_r[511:384]}, r_slot_s.Slot0.Slot[127:32], r_hdr_s};
        end
        3'b011 : begin
            r_hdr_s.Slot3 = CXL_HDR_SLOT_G0; // Slot 3, Slot 2 and Slot 1 - rollover data chunks
            r_hdr_s.Slot2 = CXL_HDR_SLOT_G0; // Slot 3, Slot 2 and Slot 1 - rollover data chunks
            r_hdr_s.Slot1 = CXL_HDR_SLOT_G0; // Slot 3, Slot 2 and Slot 1 - rollover data chunks

            cxl_slot_vld_s = {1'b1, 1'b1, 1'b1, r_slot_s.Slot0.Valid};
            cxl_data_hdr_s = {4'd0, 4'd0, 4'd0, r_slot_s.Slot0.Data};
            //r_hdr_s.BE = r_hdr_s.BE & (|cxl_data_hdr_s);
            cxl_flit_s     = {~r_byte_en_r ? {roll_data_r[511:384], roll_data_r[383:256], roll_data_r[255:128]} : {{64'd0, roll_data_be_r}, roll_data_r[511:384], roll_data_r[383:256]}, r_slot_s.Slot0.Slot[127:32], r_hdr_s};
        end
        default: begin
            cxl_slot_vld_s = {1'b1, 1'b1, 1'b1, 1'b1};
            cxl_data_hdr_s = {4'd0, 4'd0, 4'd0, 4'd0};
            if (roll_cntr_r == 5'd4) begin
                if (!roll_data_vld_r) cxl_slot_vld_s = {1'b0, 1'b0, 1'b0, 1'b0};
                cxl_flit_s     = ~r_byte_en_r ? {roll_data_r[511:384], roll_data_r[383:256], roll_data_r[255:128], roll_data_r[127:0]} : 
                                                {{64'd0, roll_data_be_r}, roll_data_r[511:384], roll_data_r[383:256], roll_data_r[255:128]};
            end
            else begin
                if (r_byte_en_r) begin
                    if ((roll_cntr_r[1:0] == 2'b01) ? !roll_data_vld_r : !roll_data_vld_s) cxl_slot_vld_s = {1'b0, 1'b0, 1'b0, 1'b0};
                    case (roll_cntr_r[1:0])
                        2'b01 : cxl_flit_s = {roll_data_r[511:384], roll_data_r[383:256], roll_data_r[255:128], roll_data_r[127:0]};
                        2'b10 : cxl_flit_s = {r_slot_s.Slot2.Slot, r_slot_s.Slot1.Slot,  r_slot_s.Slot0.Slot,  roll_data_r[511:384]};
                        2'b11 : cxl_flit_s = {r_slot_s.Slot1.Slot, r_slot_s.Slot0.Slot,  roll_data_r[511:384], roll_data_r[383:256]};
                        2'b00 : cxl_flit_s = {r_slot_s.Slot0.Slot, roll_data_r[511:384], roll_data_r[383:256], roll_data_r[255:128]};
                    endcase
                end
                else begin
                    if ((roll_cntr_r[1:0] == 2'b00) ? !roll_data_vld_r : !roll_data_vld_s) cxl_slot_vld_s = {1'b0, 1'b0, 1'b0, 1'b0};
                    case (roll_cntr_r[1:0])
                        2'b00 : cxl_flit_s = {roll_data_r[511:384], roll_data_r[383:256], roll_data_r[255:128], roll_data_r[127:0]};
                        2'b01 : cxl_flit_s = {r_slot_s.Slot2.Slot, r_slot_s.Slot1.Slot,  r_slot_s.Slot0.Slot,  roll_data_r[511:384]};
                        2'b10 : cxl_flit_s = {r_slot_s.Slot1.Slot, r_slot_s.Slot0.Slot,  roll_data_r[511:384], roll_data_r[383:256]};
                        2'b11 : cxl_flit_s = {r_slot_s.Slot0.Slot, roll_data_r[511:384], roll_data_r[383:256], roll_data_r[255:128]};
                    endcase
                end
            end
        end
    endcase
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Rollover Counter
// -------------------------------------------------------------------------------------
assign roll_data_vld_s = 1'b0 || (!roll_data_prot_r && mux_cache_data_vld_s)
   || ( roll_data_prot_r && mux_mem_data_vld_s  ) ;

assign roll_data_msg_s = roll_data_prot_r ? mux_mem_data_msg_s : mux_cache_data_msg_s;

always_comb begin
    // Update Rollover Counter the cycle we are capturing protocol flit into the output register
    if (b_pack.s_cxl_packer_valid) begin
        roll_cntr_dec_s = roll_all_data_s ? 3'd4 : ( (cxl_slot_vld_s[1] & (cxl_flit_hdr_s.Slot1 == CXL_HDR_SLOT_G0)) +
                          (cxl_slot_vld_s[2] & (cxl_flit_hdr_s.Slot2 == CXL_HDR_SLOT_G0)) + (cxl_slot_vld_s[3] & (cxl_flit_hdr_s.Slot3 == CXL_HDR_SLOT_G0)) );
    
        roll_cntr_inc_s = 4*cntDataHeaders(cxl_data_hdr_s) + ((cxl_flit_hdr_s.BE ? 1 : 0) & |cxl_data_hdr_s);
    end
    else begin
        roll_cntr_dec_s = '0;
        roll_cntr_inc_s = '0;
    end

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The design intent never overflows the counter
    roll_cntr_nxt = (roll_cntr_r + roll_cntr_inc_s) - roll_cntr_dec_s;
// spyglass enable_block W164a
end

always_comb begin
    if (|mux_cache_hdr_vld_s) begin
        roll_data_prot_nxt = 1'b0;
        roll_data_be_nxt   = mux_cache_be_msg_s;
        roll_data_nxt      = mux_cache_data_msg_s;
        roll_data_vld_nxt  = mux_cache_data_vld_s;
    end else 
    if (|mux_mem_hdr_vld_s) begin
        roll_data_prot_nxt = 1'b1;
        roll_data_be_nxt   = mux_mem_be_msg_s;
        roll_data_nxt      = mux_mem_data_msg_s;
        roll_data_vld_nxt  = mux_mem_data_vld_s;
    end else 
    begin
        roll_data_prot_nxt = roll_data_prot_r;
        roll_data_be_nxt   = roll_data_be_r;
        
        if (b_pack.s_cxl_packer_valid || !roll_data_vld_r) begin
            roll_data_nxt     = roll_data_msg_s;
            roll_data_vld_nxt = roll_data_vld_s;
        end
        else begin
            roll_data_nxt     = roll_data_r;
            roll_data_vld_nxt = roll_data_vld_r;
        end
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        roll_cntr_r      <= #TP '0;
        roll_data_prot_r <= #TP 1'b0;
        roll_data_vld_r  <= #TP 1'b0;
        roll_data_r      <= #TP '0;
        roll_data_be_r   <= #TP '1;
    end
    else begin
        roll_cntr_r      <= #TP roll_cntr_nxt;
        roll_data_prot_r <= #TP roll_data_prot_nxt;
        roll_data_vld_r  <= #TP roll_data_vld_nxt;
        roll_data_r      <= #TP roll_data_nxt;
        roll_data_be_r   <= #TP roll_data_be_nxt;
    end
end
// -------------------------------------------------------------------------------------






 wire cfg_host_cache_poison_start; 
 wire cfg_host_cache_poison_busy; 
 wire cfg_dev_cache_poison_start;
 wire cfg_dev_cache_poison_busy;
assign cfg_cache_poison_busy = 1'b0 || cfg_host_cache_poison_busy || cfg_dev_cache_poison_busy;
 wire cfg_host_mem_poison_start; 
 wire cfg_host_mem_poison_busy; 
 wire cfg_dev_mem_poison_start;
 wire cfg_dev_mem_poison_busy;
assign cfg_mem_poison_busy = 1'b0 || cfg_host_mem_poison_busy || cfg_dev_mem_poison_busy;



// -------------------------------------------------------------------------------------
// Host Flit Packer Instantiation
// -------------------------------------------------------------------------------------
assign cfg_host_cache_poison_start = cfg_cache_poison_start && host_packer_ena_s;
assign cfg_host_mem_poison_start   = cfg_mem_poison_start && host_packer_ena_s;


DWC_cxl_mem_cache_packer_dsp
 u_link_dsp_flit_packer (
    .core_clk               ( core_clk                       ),
    .core_rst_n             ( core_rst_n                     ),
    .pack_enable            ( host_packer_ena_s              ),
    .cxl_packer_reverse     ( host_packer_rev_s              ),
    .cxl_packer_flit        ( cxl_flit_s                     ),
    .cxl_packer_all_data    ( roll_all_data_s                ),
    .cxl_packer_rollover    ( roll_cntr_r                    ),
    .cxl_packer_slot_vld    ( cxl_slot_vld_s                 ),
    .cxl_prot_msg_halt      ( cxl_prot_msg_halt_s            ),
    .cxl_prot_data_halt     ( cxl_prot_data_halt_s           ),
    .cfg_cache_poison_start ( cfg_host_cache_poison_start    ),
    .cfg_cache_poison_busy  ( cfg_host_cache_poison_busy     ),
    .cxl_cache_data_ena     ( cxl_cache_data_ena_s           ),
    .cache_hdr              ( h2d_cache_hdr_s                ),
    .cache_slot             ( h2d_cache_slot_s               ),
    .cache_req_vld          ( h2d_cache_req_vld_s            ),
    .cache_rsp_vld          ( h2d_cache_rsp_vld_s            ),
    .cache_hdr_vld          ( h2d_cache_hdr_vld_s            ),
    .cfg_mem_poison_start   ( cfg_host_mem_poison_start      ),
    .cfg_mem_poison_busy    ( cfg_host_mem_poison_busy       ),
    .cxl_mem_data_ena       ( cxl_mem_data_ena_s             ),
    .mem_hdr                ( m2s_mem_hdr_s                  ),
    .mem_slot               ( m2s_mem_slot_s                 ),
    .mem_req_vld            ( m2s_mem_req_vld_s              ),
    .mem_hdr_vld            ( m2s_mem_hdr_vld_s              ),
    .mem_pending_vld        ( m2s_mem_pending_s              ),
    .cxl_tl_pending_o       ( host_tl_pending_s              ),
    .b_llctrl               ( b_llctrl                       ),
    .b_txtl_llctrl          ( b_txtl_host                    )
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Device Flit Packer Instantiation
// -------------------------------------------------------------------------------------
assign cfg_dev_cache_poison_start = cfg_cache_poison_start && dev_packer_ena_s;
assign cfg_dev_mem_poison_start   = cfg_mem_poison_start && dev_packer_ena_s;


DWC_cxl_mem_cache_packer_usp
 u_link_usp_flit_packer (
    .core_clk               ( core_clk                       ),
    .core_rst_n             ( core_rst_n                     ),
    .pack_enable            ( dev_packer_ena_s               ),
    .cxl_packer_reverse     ( dev_packer_rev_s               ),
    .cxl_packer_flit        ( cxl_flit_s                     ),
    .cxl_packer_all_data    ( roll_all_data_s                ),
    .cxl_packer_rollover    ( roll_cntr_r                    ),
    .cxl_packer_slot_vld    ( cxl_slot_vld_s                 ),
    .cxl_prot_msg_halt      ( cxl_prot_msg_halt_s            ),
    .cxl_prot_data_halt     ( cxl_prot_data_halt_s           ),
    .cfg_cache_poison_start ( cfg_dev_cache_poison_start     ),
    .cfg_cache_poison_busy  ( cfg_dev_cache_poison_busy      ),
    .cxl_cache_data_ena     ( cxl_cache_data_ena_s           ),
    .cache_hdr              ( d2h_cache_hdr_s                ),
    .cache_slot             ( d2h_cache_slot_s               ),
    .cache_req_vld          ( d2h_cache_req_vld_s            ),
    .cache_rsp_vld          ( d2h_cache_rsp_vld_s            ),
    .cache_hdr_vld          ( d2h_cache_hdr_vld_s            ),
    .cfg_mem_poison_start   ( cfg_dev_mem_poison_start       ),
    .cfg_mem_poison_busy    ( cfg_dev_mem_poison_busy        ),
    .cxl_mem_data_ena       ( cxl_mem_data_ena_s             ),
    .mem_hdr                ( s2m_mem_hdr_s                  ),
    .mem_slot               ( s2m_mem_slot_s                 ),
    .mem_rsp_vld            ( s2m_mem_rsp_vld_s              ),
    .mem_hdr_vld            ( s2m_mem_hdr_vld_s              ),
    .mem_pending_vld        ( s2m_mem_pending_s              ),
    .cxl_tl_pending_o       ( dev_tl_pending_s               ),
    .b_llctrl               ( b_llctrl                       ),
    .b_txtl_llctrl          ( b_txtl_dev                     )
);
// -------------------------------------------------------------------------------------



// -------------------------------------------------------------------------------------
// Count number of Data Headers in the flit
// -------------------------------------------------------------------------------------
function automatic [2:0] cntDataHeaders;
    input   [15:0] data_hdr;
    reg     [2:0]  result;

    logic [3:0] data_hdr_s;
    integer i;
begin
    result = '0;

    // Only one out 4 slots may contain data header(s)  
    data_hdr_s = data_hdr[15:12] | data_hdr[11:8] | data_hdr[7:4] | data_hdr[3:0];

    for (i = 0; i < 4; i++)
        if (data_hdr_s[i]) result = result + 1;

    cntDataHeaders = result;
end
endfunction
// -------------------------------------------------------------------------------------


endmodule : DWC_cxl_mem_cache_packer_68byte
