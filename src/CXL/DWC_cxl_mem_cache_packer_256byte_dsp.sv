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

// -----------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2024/01/19 09:25:58 $
// ---   $Author: neira $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_packer_256byte_dsp.sv#2 $
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "CXL/svif/DWC_cxl_pack_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_txtl_llctrl_if.svh"

module DWC_cxl_mem_cache_packer_256byte_dsp 
    import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)
                                               (
    input                                       core_clk,                                       // Core clock
    input                                       core_rst_n,                                     // Core active low asynchronous reset
    input                                       pack_enable,                                    // Enable Flit Packer
    input  SLOT_DESCR_256B_t                    cxl_packer_flit  [0 : FLIT_SLOT_NUM-1],         // Flit on the Packer output
    input                                       cxl_prot_msg_halt,                              // CXL Protocol Message Channel Halt
    input                                       cxl_prot_data_halt,                             // CXL Protocol Data Channel Halt
    input CXL_SLOT_TYPES                        cxl_slot_type,                                  // Define Slot#0 Type G, H or Hs
    input                                       cxl_rst_msk,                                    // Reset HDRs counters
    input                                       cxl_data_en,                                    // Enable data HDR packing 
    input RR_256B_ARB_STATE_t                   mem_cache_arb,                                  // Current cycle is MEM or Cache round
    input [5:0]                                 roll_over_cnt,                                  // Rollover counter
    input                                       shift_h2d_data,                                  // Shift H2D data channel in Case the Data packer (Rollover packer) Used 1st channel
    input                                       cfg_cache_poison_start,                          // CachePoisonInjectionStart
    output                                      cfg_cache_poison_busy,                           // CachePoisonInjectionBusy
    output [TX_CRDIF_WIDTH-1:0]                 cache_req_vld,                                   // CXL.cache Request channel valid bit
    output [TX_CRDIF_WIDTH-1:0]                 cache_rsp_vld,                                   // CXL.cache Response channel valid bit
    output [TX_CRDIF_WIDTH-1:0]                 cache_hdr_vld,                                   // CXL.cache Data channel valid bit
    output SLOT_DESCR_256B_t                    cache_flit [0:FLIT_NUM_PAGE-1]
                                                                [0 : FLIT_SLOT_NUM_PAGE-1],      // CXL.cache Slot Information
    output logic                                cxl_cache_pending,                               // CXL.Cache Pending requests

    input                                       shift_m2s_data,                                  // Shift M2S data channel in Case the Data packer (Rollover packer) Used 1st channel
    input                                       cfg_mem_poison_start,                            // MemPoisonInjectionStart
    output                                      cfg_mem_poison_busy,                             // MemPoisonInjectionBusy
    output [TX_CRDIF_WIDTH-1:0]                 mem_req_vld,                                     // CXL.mem Request channel valid bit
    output [TX_CRDIF_WIDTH-1:0]                 mem_hdr_vld,                                     // CXL.mem Data channel valid bit
    output SLOT_DESCR_256B_t                    mem_flit  [0:FLIT_NUM_PAGE-1]
                                                                [0 : FLIT_SLOT_NUM_PAGE-1],      // CXL.mem Rule Packer Header
    output logic                                cxl_mem_pending,                                 // CXL.mem Pending requests
    output [TX_CRDIF_WIDTH-1:0]                 mem_rsp_vld,                                     // CXL.mem Response channel valid bit
    output logic                                cxl_tl_pending_o,                                // Pending message on the TL Interface
    DWC_cxl_pack_llctrl_if.slave_ctrl_mp        b_llctrl,                                        // Link Layer Controller to Flit Packer Interface
    DWC_cxl_txtl_llctrl_if.pack_slave_host_mp   b_txtl_llctrl                                    // Flit Packer to Transaction Layer Interface

);

// Channel Halt Generation Signals
logic                                cxl_prot_msg_halt_s;                                // CXL Protocol Message Channel Halt
logic                                cxl_prot_data_halt_s;                               // CXL Protocol Data Channel Halt - d2h_data and s2m_data

// MeM logic that is used by cache arbiter
SLOT_DESCR_256B_t       mem_slots[0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];           // Mem Only page slots without cache for each page                            
logic [M2S_256B_NDR_NUM-1:0]          cxl_ch_m2s_req_vld, cxl_ch_m2s_req_vld_nxt;         // M2S Request  Channel Valid Bits
logic [M2S_256B_DATA_NUM-1:0]         cxl_ch_m2s_rwd_vld, cxl_ch_m2s_rwd_vld_nxt;         // M2S RwD Channel Valid Bits
logic [M2S_256B_NDR_NUM-1:0]          s_cxl_ch_m2s_req_msk, r_cxl_ch_m2s_req_msk;         // M2S Request Channel Mask to insure 128B rolling by 64B step group max. number of messages
logic [M2S_256B_DATA_NUM-1:0]         s_cxl_ch_m2s_rwd_msk, r_cxl_ch_m2s_rwd_msk;         // M2S RWD  Channel Mask to insure 128B rolling by 64B step group max. number of messages
logic                                 m2s_rwd_vld_0, m2s_req_vld_0;                       // M2S has at least valid message 
   
logic [M2S_256B_BI_RSP_NUM-1:0]        cxl_ch_m2s_bi_rsp_vld;                             // M2S BI Response Channel Valid Bits
logic [M2S_256B_BI_RSP_NUM-1:0]        s_cxl_ch_m2s_bi_rsp_msk, r_cxl_ch_m2s_bi_rsp_msk;  // M2S BI  Channel Mask to insure 128B rolling by 64B step group max. number of messages
logic                                  m2s_bi_rsp_vld_0;                                  // M2S has at least valid message


// Halt host packer if the host packer is not enabled (Device Mode) or the packer is halted 
// Note cxl_prot_msg_halt == cxl_prot_data_halt
assign cxl_prot_msg_halt_s  = ~pack_enable | cxl_prot_msg_halt;
assign cxl_prot_data_halt_s = ~pack_enable | cxl_prot_data_halt;




// Message Channel Valid Bits and MDH Enable


logic [H2D_256B_REQ_NUM -1:0]    cxl_ch_h2d_req_vld, cxl_ch_h2d_req_vld_nxt;          // H2D Request Channel Valid Bits
logic [H2D_256B_RESP_NUM-1:0]    cxl_ch_h2d_rsp_vld, cxl_ch_h2d_rsp_vld_nxt;          // H2D Response Channel Valid Bits
logic [H2D_256B_DATA_NUM-1:0]     cxl_ch_h2d_hdr_vld, cxl_ch_h2d_hdr_vld_nxt;         // H2D Data Header Channel Valid Bits
                                                                                      
logic [H2D_256B_REQ_NUM -1:0]    s_cxl_ch_h2d_req_msk, r_cxl_ch_h2d_req_msk;          // H2D Request  Channel Mask to insure 128B rolling by 64B step group max. number of messages
logic [H2D_256B_RESP_NUM-1:0]    s_cxl_ch_h2d_rsp_msk, r_cxl_ch_h2d_rsp_msk;          // H2D RSP  Channel Mask to insure 128B rolling by 64B step group max. number of messages
logic [H2D_256B_DATA_NUM-1:0]    s_cxl_ch_h2d_hdr_msk, r_cxl_ch_h2d_hdr_msk;          // H2D HDR  Channel Mask to insure 128B rolling by 64B step group max. number of messages
                                                                                      
                                                                                      
logic [H2D_256B_REQ_SIZE-1:0]    cxl_h2d_req_msg_s  [0:H2D_256B_REQ_NUM-1];                 // H2D Request Channels messages
logic [H2D_256B_RESP_SIZE-1:0]   cxl_h2d_rsp_msg_s  [0:H2D_256B_RESP_NUM-1];                // H2D Response Channels messages
logic [H2D_256B_DHDR_SIZE-1:0]   cxl_h2d_hdr_msg_s  [0:H2D_256B_DATA_NUM-1];                // H2D Data Header Channels messages
logic [H2D_256B_DDATA_SIZE-1:0]  cxl_h2d_data_msg_s [0:H2D_256B_DDATA_NUM-1];               // H2D Data channels
                                                                                            
logic [H2D_256B_REQ_NUM-1:0]     cxl_ch_h2d_req_gnt_halt;                                   // H2D Request Channel halt due to credit
logic [H2D_256B_RESP_NUM-1:0]    cxl_ch_h2d_rsp_gnt_halt;                                   // H2D Response Channel halt due to credit
logic [H2D_256B_DATA_NUM-1:0]    cxl_ch_h2d_hdr_gnt_halt;                                   // H2D Data Header Channel halt due to credit
                                                                                            
logic                            cfg_cache_poison_start_r;                                  // Poison Start
logic                            cfg_cache_poison_r, cfg_cache_poison_nxt;                  // Poison bit
                                                                                            
                                                                                            
SLOT_DESCR_256B_t  cache_data_slots [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];          // Cache Data HDR slots per page
SLOT_DESCR_256B_t  cache_hdr_slots  [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];          // Cache Header without Data slots per page
SLOT_DESCR_256B_t  cache_slots      [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];          // Cache Header + Data slots per page
SLOT_DESCR_256B_t  cache_n_mem_slots[0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];          // Cache + slots per page (Cache has higher priority)
                                                                                            
logic [SLOT_CNT_WIDTH_PAGE - 1   : 0]          mem_slot_idx;                                // Mem Slots per page indexer while packing cache_n_mem_slots
CXL_SLOT_TYPES                                 cache_hdr_slot_type;                         // Current Cache HDRs slot type (G, H, OR Hs)
CXL_SLOT_TYPES                                 cache_data_slot_type;                        // Current Cache Data-HDRs slot type (G, H, OR Hs)
logic [H2D_REQ_CNT_WIDTH - 1: 0]               h2d_req_idx;                                 // H2D Req message indexer 
logic [H2D_RSP_CNT_WIDTH - 1: 0]               h2d_rsp_idx;                                 // H2D Rsp message indexer 
CXL_CACHE_RR_HDR_STATE                         s_rr_cache_req  [0 : FLIT_SLOT_NUM-1];       // Per Slot RR H2D Req/RSP arbiter
CXL_CACHE_RR_HDR_STATE                         r_rr_cache_req  [0 : FLIT_SLOT_NUM-1];       // Per Slot RR H2D Req/RSP arbiter
CXL_CACHE_RR_DATA_STATE                        r_rr_cache_data, s_rr_cache_data ;           // Per Cycle RR H2D HDR/Data arbiter
logic                                          s_cache_data_vld, s_cache_req_rsp_vld;       // Cache HDR sent to arbiter
logic                                          cache_data_vld;                              // Cache Data sent to arbiter

logic [SLOT_CNT_WIDTH_PAGE - 1   : 0]          cache_hdr_slot_idx, cache_data_slot_idx;     // Cache HDR/Data indexer while packing cache_slots per page
logic                                          s_cache_req_vld, s_cache_rsp_vld;            //Cache Req/Rsp sent to arbiter

logic                                          h2d_req_vld_0, h2d_rsp_vld_0, h2d_hdr_vld_0; // H2D has at least valid message 

// -------------------------------------------------------------------------------------
// CXL.Cache Poison Mode
// -------------------------------------------------------------------------------------
// Insert poison bit at H2D Data Header 

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
    else if (pack_enable) begin
        cfg_cache_poison_start_r <= #TP cfg_cache_poison_start;
        cfg_cache_poison_r       <= #TP cfg_cache_poison_nxt;
    end
end
//----------------------------------------------------------------------
//              Mask Generation logic
//----------------------------------------------------------------------
// The packer need to ensure the max. number allowed per 8 slots (rolling by 4 slots step)
// as per definend in CXL 3.0 Flit packing rules
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      r_cxl_ch_h2d_req_msk <= #TP '1;
      r_cxl_ch_h2d_rsp_msk <= #TP '1;
      r_cxl_ch_h2d_hdr_msk <= #TP '1;
    end
    else if (!cxl_prot_msg_halt_s) begin
      r_cxl_ch_h2d_req_msk <= #TP  s_cxl_ch_h2d_req_msk;
      r_cxl_ch_h2d_rsp_msk <= #TP  s_cxl_ch_h2d_rsp_msk;
      r_cxl_ch_h2d_hdr_msk <= #TP  s_cxl_ch_h2d_hdr_msk;
    end
end

// --------------------------------------------------------------------------------
// Extarct channel message valid bits if the packer has a credit grant
// If the Packer doesn't have a credit grant on a valid message, halt it.
// the packer can't halt invalid messages anyway to keep its processing in the TL
// --------------------------------------------------------------------------------

always_comb begin

  for (int i = 0; i < H2D_256B_REQ_NUM; i++)  begin
      cxl_h2d_req_msg_s[i] = (b_llctrl.s_cxl_ll_cache_req_gnt[i]) ? b_txtl_llctrl.s_cxl_h2d_req[i] : '0;
      cxl_ch_h2d_req_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_cache_req_gnt[i]) & b_txtl_llctrl.s_cxl_h2d_req[i][H2D_REQ_VLD];
  end
  for (int i = 0; i < H2D_256B_REQ_NUM; i++)  cxl_ch_h2d_req_vld[i] = cxl_h2d_req_msg_s[i][H2D_REQ_VLD];
  
  for (int i = 0; i < H2D_256B_RESP_NUM; i++) begin
      cxl_h2d_rsp_msg_s[i] = (b_llctrl.s_cxl_ll_cache_rsp_gnt[i] ) ? b_txtl_llctrl.s_cxl_h2d_rsp[i] : '0;
      cxl_ch_h2d_rsp_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_cache_rsp_gnt[i]) & b_txtl_llctrl.s_cxl_h2d_rsp[i][H2D_RESP_VLD];
  end
  for (int i = 0; i < H2D_256B_RESP_NUM; i++) cxl_ch_h2d_rsp_vld[i] = cxl_h2d_rsp_msg_s[i][H2D_RESP_VLD];

  
  for (int i = 0; i < H2D_256B_DATA_NUM; i++) begin
   // the HDR is always associated with data, so if no data valid message, the packer can't pack data HDRs
    cxl_h2d_hdr_msg_s[i] = (b_llctrl.s_cxl_ll_cache_data_gnt[i] & b_txtl_llctrl.s_cxl_h2d_data_vld[0] & cxl_data_en) ? b_txtl_llctrl.s_cxl_h2d_hdr[i] : '0;
    cxl_ch_h2d_hdr_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_cache_data_gnt[i] & b_txtl_llctrl.s_cxl_h2d_data_vld[0] & cxl_data_en) & b_txtl_llctrl.s_cxl_h2d_hdr[i][H2D_HDR_VLD];
  end
  for (int i = 0; i < H2D_256B_DATA_NUM; i++) cxl_ch_h2d_hdr_vld[i] = cxl_h2d_hdr_msg_s[i][H2D_HDR_VLD];

  // Overwrite Poison Bit
  cxl_h2d_hdr_msg_s[0][H2D_256B_POISON_BIT] = cxl_h2d_hdr_msg_s[0][H2D_HDR_VLD] ? (b_txtl_llctrl.s_cxl_h2d_hdr[0][H2D_256B_POISON_BIT] | cfg_cache_poison_r) : 1'b0;
  for (int i = 0; i < H2D_256B_DDATA_NUM; i++) cxl_h2d_data_msg_s[i] = b_txtl_llctrl.s_cxl_h2d_data[i];
end

// -------------------------------------------------------------------------------------
// Generate valid signals for credit tracking
// -------------------------------------------------------------------------------------
assign cache_req_vld  = {{(TX_CRDIF_WIDTH-H2D_256B_REQ_NUM){1'b0}} , cxl_ch_h2d_req_vld & ~b_txtl_llctrl.s_cxl_h2d_req_halt};
assign cache_rsp_vld  = {{(TX_CRDIF_WIDTH-H2D_256B_RESP_NUM){1'b0}}, cxl_ch_h2d_rsp_vld & ~b_txtl_llctrl.s_cxl_h2d_rsp_halt};
assign cache_hdr_vld  = {{(TX_CRDIF_WIDTH-H2D_256B_DATA_NUM){1'b0}}, cxl_ch_h2d_hdr_vld & ~b_txtl_llctrl.s_cxl_h2d_hdr_halt};
// This is to see which flit type will use H slot
assign h2d_req_vld_0 = cxl_ch_h2d_req_vld[0] & r_cxl_ch_h2d_req_msk[0];
assign h2d_rsp_vld_0 = cxl_ch_h2d_rsp_vld[0] & r_cxl_ch_h2d_rsp_msk[0];
assign h2d_hdr_vld_0 = cxl_ch_h2d_hdr_vld[0] & r_cxl_ch_h2d_hdr_msk[0];
// -------------------------------------------------------------------------------------
// Cache arbitration logic
// -------------------------------------------------------------------------------------
// HDR without Data arbitration
// after core_rst the RR Arbiter will start with req,rsp,req,rsp,req,rsp ...
// if the req is valid, the RR Arbiter with start with ulternative in the next cycle rsp,req,rsp,req ... to ensure the fairness between req and rsp
always_comb begin  
  s_rr_cache_req  = r_rr_cache_req;
  s_cache_req_vld = cache_req_vld[0];
  s_cache_rsp_vld = cache_rsp_vld[0];   
  if ((s_rr_cache_req[0]==CXL_CACHE_RR_REQ && s_cache_req_vld) ||
      (s_rr_cache_req[0]==CXL_CACHE_RR_RSP && s_cache_rsp_vld) ) begin
    for(int i=1;i<FLIT_SLOT_NUM;i++) begin
      s_rr_cache_req[i-1] = r_rr_cache_req[i];
    end
    s_rr_cache_req[FLIT_SLOT_NUM-1] = r_rr_cache_req[0];
  end
end  

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin 
    for (int i = 0; i< FLIT_SLOT_NUM;i++) begin
      if (i%2 == 0)
        r_rr_cache_req[i] <= #TP CXL_CACHE_RR_REQ;
      else
        r_rr_cache_req[i] <= #TP CXL_CACHE_RR_RSP;
    end
  end
  else if(!cxl_prot_msg_halt_s) begin
    for (int i = 0; i< FLIT_SLOT_NUM;i++)
      r_rr_cache_req[i] <= #TP s_rr_cache_req[i];
  end
end
// HDR with Data arbitration
always_comb begin  
  s_rr_cache_data     = r_rr_cache_data;
  s_cache_data_vld    = cache_hdr_vld[0];
  s_cache_req_rsp_vld = cache_req_vld[0] | cache_rsp_vld[0] ;
  if ((s_rr_cache_data==CXL_CACHE_RR_DATA && s_cache_data_vld) ||
      (s_rr_cache_data==CXL_CACHE_RR_HDR && s_cache_req_rsp_vld) ) begin
    s_rr_cache_data = (r_rr_cache_data==CXL_CACHE_RR_DATA)? CXL_CACHE_RR_HDR : CXL_CACHE_RR_DATA;
  end
end  
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin 
    r_rr_cache_data <= #TP CXL_CACHE_RR_HDR;
  end
  else if(!cxl_prot_msg_halt_s && !cxl_prot_data_halt_s) begin
    r_rr_cache_data <= #TP s_rr_cache_data;
  end
end
  
// -------------------------------------------------------------------------------------
// Cache Data slots packing
// -------------------------------------------------------------------------------------
logic force_gslot_cache_data_n; // Force 1st slot to be a G slot in cache data packer
logic force_gslot_cache_hdr_n;  // Force 1st slot to be a G slot in cache HDR packer
logic cache_round;

assign cache_round = (mem_cache_arb==CXL_256B_CACHE)  | (!m2s_rwd_vld_0 & !m2s_req_vld_0 & !m2s_bi_rsp_vld_0 ) ;
generate 
  always_comb begin 
    // In case the HDR channel has higher priority then pack only G slots
    // In case mem channel has higher priority then pack only G slots
    // Note : if cxl_ch_h2d_rsp_vld[0]==0, all other h2d_rsp channels will not be valid (cxl_ch_h2d_rsp_vld[H2D_256B_RESP_NUM:1]==0) >> same for other chanels
    force_gslot_cache_data_n = ((~h2d_rsp_vld_0 & ~h2d_req_vld_0) | (r_rr_cache_data == CXL_CACHE_RR_DATA)) & cache_round;
   // if mdh is not enabled allow only one data header packing
   // r_cxl_ch_h2d_hdr_msk represents the number of h2d_hdr that are sent in the second page of the previous cycle so it should be taken into considerstion 
   // in h2d_hdr_vld  to sustain the max number of h2d_hdr that can be sent in 128B window
    cxl_ch_h2d_hdr_vld_nxt   = (b_llctrl.s_cxl_ll_cache_mdh_en) ? cxl_ch_h2d_hdr_vld &  r_cxl_ch_h2d_hdr_msk:
                                                                  cxl_ch_h2d_hdr_vld & 'h1 &  r_cxl_ch_h2d_hdr_msk;
    // In case No headers avaialbe then the 1st slot can be H/Hs slot else it must be G Slot
    if (FLIT_SLOT_NUM > 1) cache_data_slot_type = (force_gslot_cache_data_n)? cxl_slot_type : CXL_256B_SLOT_G;
    else                   cache_data_slot_type = cxl_slot_type;
    // Initialize 
    for (int i =0;i<FLIT_SLOT_NUM;i++) cache_data_slots[i/4][i%4] = 'd0;  
    // If the header is valid, then pack the Header and its associated data
    if (cxl_ch_h2d_hdr_vld_nxt[0]) begin
      cache_data_slots[0][0] = pack_slot_12 (cxl_h2d_hdr_msg_s, cxl_ch_h2d_hdr_vld_nxt, 'd0, cache_data_slot_type);
      //shift_h2d_data represents the data channel number (0/1) that the data will be packed from as for 8s packer there are 2 valid data channels 
      //shift_h2d_data is always equal zero for 1 page packing (4 slot)
      // For 2 pages The rollover packer can send 1x512bits of Data, this means that the packer should pack the 2nd channel of data (shift_h2d_data =1)
      // In case the rollover packed two new 512bits of Data this means No data needed from the Host packer 
      cache_data_slots[0][1] = pack_data(cxl_h2d_data_msg_s[shift_h2d_data], 'd0 ,3'd0, 1'b0, CXL_256B_CACHE_H);
      cache_data_slots[0][2] = pack_data(cxl_h2d_data_msg_s[shift_h2d_data], 'd0 ,3'd1, 1'b0, CXL_256B_CACHE_H);
      cache_data_slots[0][3] = pack_data(cxl_h2d_data_msg_s[shift_h2d_data], 'd0 ,3'd2, 1'b0, CXL_256B_CACHE_H);

    end   
  end
endgenerate
// -------------------------------------------------------------------------------------
// Cache Headers packing
// -------------------------------------------------------------------------------------
  always_comb begin     
   // r_cxl_ch_h2d_rsp_msk represents the number of h2d_rsp that are sent in the second page of the previous cycle so it should be taken into considerstion 
   // in h2d_rsp_vld  to sustain the max number of h2d_rsp that can be sent in 128B window (same for r_cxl_ch_h2d_req_msk)
    cxl_ch_h2d_rsp_vld_nxt = cxl_ch_h2d_rsp_vld & r_cxl_ch_h2d_rsp_msk;
    cxl_ch_h2d_req_vld_nxt = cxl_ch_h2d_req_vld & r_cxl_ch_h2d_req_msk;
    h2d_req_idx            = 'd0;
    h2d_rsp_idx            = 'd0;
    for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM; slot_idx++) begin
    
      cache_hdr_slots[slot_idx/4][slot_idx%4] = 'b0;
      force_gslot_cache_hdr_n                 = (slot_idx==0) & (!h2d_hdr_vld_0 | (r_rr_cache_data == CXL_CACHE_RR_HDR))  & cache_round;
      // Select Slot Type
      if (FLIT_SLOT_NUM > 1)  cache_hdr_slot_type = (force_gslot_cache_hdr_n)? cxl_slot_type : CXL_256B_SLOT_G;
      else                    cache_hdr_slot_type = cxl_slot_type;
// spyglass disable_block STARC05-2.8.1.3
// SMD: case constructs should not have overlapping clause conditions. (Verilog)
// SJ: This is to enable synthesis optimization
      // 1- RR between H2D RSP and H2D REQ
      // slot0 can cary req and resp, slot1 can carry rsp only so depending on valid req/rsp choose which slot can be packed
      casez ({r_rr_cache_req[slot_idx] ,cxl_ch_h2d_rsp_vld_nxt[0], cxl_ch_h2d_req_vld_nxt[0]})
        3'b?_0_1,
        {CXL_CACHE_RR_REQ, 2'b?_1}: begin 
          cache_hdr_slots[slot_idx/4][slot_idx%4] = pack_slot_00 (cxl_h2d_req_msg_s, cxl_ch_h2d_req_vld_nxt, h2d_req_idx, 
                                                     cxl_h2d_rsp_msg_s, cxl_ch_h2d_rsp_vld_nxt, h2d_rsp_idx,cache_hdr_slot_type);
         // counting number of req/rsp sent in slot0                                        
          h2d_req_idx                             = h2d_req_idx + h2d_req_max(cache_hdr_slot_type); 
          h2d_rsp_idx                             = h2d_rsp_idx + h2d_rsp_max(cache_hdr_slot_type, 1'b0); 
         // shift the valid by the number of req/rsp that are sent in slot0 to re-start the loop with the new valid
          cxl_ch_h2d_req_vld_nxt                  = cxl_ch_h2d_req_vld_nxt >> h2d_req_max(cache_hdr_slot_type); 
          cxl_ch_h2d_rsp_vld_nxt                  = cxl_ch_h2d_rsp_vld_nxt >> h2d_rsp_max(cache_hdr_slot_type, 1'b0); 
        end
        3'b?_1_0,
        {CXL_CACHE_RR_RSP, 2'b1_?}: begin 
          cache_hdr_slots[slot_idx/4][slot_idx%4]  = pack_slot_01 (cxl_h2d_rsp_msg_s, cxl_ch_h2d_rsp_vld_nxt, h2d_rsp_idx,cache_hdr_slot_type);
         // shift the valid by the number of rsp that are sent in slot1 to re-start the loop with the new valid
          cxl_ch_h2d_rsp_vld_nxt                   = cxl_ch_h2d_rsp_vld_nxt >> h2d_rsp_max(cache_hdr_slot_type, 1'b1); 
        // counting number of req/rsp sent in slot1 
          h2d_rsp_idx                              = h2d_rsp_idx + h2d_rsp_max(cache_hdr_slot_type, 1'b1);  
        end
      endcase
// spyglass enable_block STARC05-2.8.1.3
    end
  end
  
// -------------------------------------------------------------------------------------
// Cache Data + Headers packing (arbiterate between data/hdr slots)
// -------------------------------------------------------------------------------------
  always_comb begin   
    cache_data_slot_idx  = 'd0;
    cache_hdr_slot_idx   = 'd0;
    for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM_PAGE; slot_idx++) begin
      if (((r_rr_cache_data == CXL_CACHE_RR_DATA) && h2d_hdr_vld_0) || (!cache_hdr_slots[0][slot_idx].Valid)) begin
        cache_slots[0][slot_idx] = cache_data_slots[0][cache_data_slot_idx];
        cache_data_slot_idx      = cache_data_slot_idx + 'd1;
      end
      else begin
        cache_slots[0][slot_idx] = cache_hdr_slots[0][slot_idx];
      end
    end
  end
// -------------------------------------------------------------------------------------
// Pack Mem Slots in empty Cache Slots
// -------------------------------------------------------------------------------------
// 
 logic [SLOT_CNT_WIDTH_PAGE - 1   : 0] cache_temp_slot_idx;

  always_comb begin 
    mem_slot_idx        = 'd0;
    for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM_PAGE; slot_idx++) begin
        cache_n_mem_slots[0][slot_idx] = cache_slots[0][slot_idx];
      if (!cache_slots[0][slot_idx].Valid) begin
        cache_n_mem_slots[0][slot_idx] = mem_slots[0][mem_slot_idx];
        mem_slot_idx                   = mem_slot_idx + 'd1;
      end
    end
    

    
    
  end
  assign cache_flit = cache_n_mem_slots;

// -------------------------------------------------------------------------------------
// Cache Halt Gen
// -------------------------------------------------------------------------------------
  logic [$clog2(H2D_256B_REQ_NUM)  :0]   cxl_ch_h2d_req_cnt;       // Number of valid H2D Request Messages in the output flit
  logic [$clog2(H2D_256B_RESP_NUM) :0]   cxl_ch_h2d_rsp_cnt;       // Number of valid H2D Response Messages in the output flit
  logic [$clog2(H2D_256B_DATA_NUM) :0]   cxl_ch_h2d_hdr_cnt;       // Number of valid H2D Data Messages in the output flit
  logic [$clog2(H2D_256B_DDATA_NUM):0]   cxl_ch_h2d_data_cnt;      // Number of valid H2D Data Blocks in the output flit
  
  logic [H2D_256B_REQ_NUM   - 1:0]   s_cxl_ch_h2d_req_halt ;      
  logic [H2D_256B_RESP_NUM  - 1:0]   s_cxl_ch_h2d_rsp_halt ;      
  logic [H2D_256B_DATA_NUM  - 1:0]   s_cxl_ch_h2d_hdr_halt ;      
  logic [H2D_256B_DDATA_NUM - 1:0]   s_cxl_ch_h2d_data_halt;     
  logic [8 - 1                 :0]   s_cache_message_vld;    

  CXL_SLOT_TYPES cache_halt_slot_type;
  
  always_comb begin 
    cxl_ch_h2d_req_cnt    = 'd0;
    cxl_ch_h2d_rsp_cnt    = 'd0;
    cxl_ch_h2d_hdr_cnt    = 'd0;
    cxl_ch_h2d_data_cnt   = 'd0;
   // halt all the channels at first
    s_cxl_ch_h2d_req_halt = '1;
    s_cxl_ch_h2d_rsp_halt = '1;
    s_cxl_ch_h2d_hdr_halt = '1;
    s_cxl_ch_h2d_data_halt= '1;

    for (int slot_idx=0; slot_idx<FLIT_SLOT_NUM_PAGE ;slot_idx++) begin // extract halt signals for 4 slots packer (1st page)
      cache_halt_slot_type = (slot_idx==0)? cxl_slot_type:CXL_256B_SLOT_G;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: No overflow expected
        // H2D REQ
       // if slot0 is sent on cxl_packer_flit which means a valid h2d_req and valid h2d_rsp are sent so de-assert the halt on these sent channels
       // Note: h2d_rsp_max() return the max nuber of h2d_rsp that are sent in one slot (same for h2d_req_max())
      if ((cxl_packer_flit[slot_idx].slot_idx == 'd0) &&
           cxl_packer_flit[slot_idx].Valid && 
           (cxl_packer_flit[slot_idx].slot_type != CXL_256B_SLOT_DATA))begin
        s_cxl_ch_h2d_req_halt = s_cxl_ch_h2d_req_halt << h2d_req_max(cache_halt_slot_type);
      end
      // H2D RSP
      if ((cxl_packer_flit[slot_idx].slot_idx == 'd0) &&
           cxl_packer_flit[slot_idx].Valid && 
           (cxl_packer_flit[slot_idx].slot_type != CXL_256B_SLOT_DATA))begin

        s_cxl_ch_h2d_rsp_halt = s_cxl_ch_h2d_rsp_halt <<  h2d_rsp_max(cache_halt_slot_type, 1'b0);
      end
      else if (cxl_packer_flit[slot_idx].slot_idx == 'd1)begin
        s_cxl_ch_h2d_rsp_halt = s_cxl_ch_h2d_rsp_halt << h2d_rsp_max(cache_halt_slot_type, 1'b1);
      end
      // H2D HDR
      if ((cxl_packer_flit[slot_idx].slot_idx == 'd12))begin
        s_cxl_ch_h2d_hdr_halt = s_cxl_ch_h2d_hdr_halt << h2d_hdr_max(cache_halt_slot_type, b_llctrl.s_cxl_ll_cache_mdh_en);
      end
// spyglass enable_block W164a
      // de-assert the data channels halt also on the sent data on cxl_packer_flit
      if (cxl_packer_flit[slot_idx].data_info.data_strt & (cxl_packer_flit[slot_idx].data_info.data_type==CXL_256B_CACHE_H)) begin
        s_cxl_ch_h2d_data_halt = s_cxl_ch_h2d_data_halt << 1;
        cxl_ch_h2d_data_cnt++;
      end
    end
    s_cache_message_vld                        = 'd0;
    s_cache_message_vld[H2D_256B_REQ_NUM-1:0]  = cxl_ch_h2d_req_vld & ~s_cxl_ch_h2d_req_halt & ~cxl_ch_h2d_req_gnt_halt & r_cxl_ch_h2d_req_msk;
    cxl_ch_h2d_req_cnt                         = valid_cnt(s_cache_message_vld); 
    
    s_cache_message_vld                        = 'd0;
    s_cache_message_vld[H2D_256B_RESP_NUM-1:0] = cxl_ch_h2d_rsp_vld & ~s_cxl_ch_h2d_rsp_halt & ~cxl_ch_h2d_rsp_gnt_halt & r_cxl_ch_h2d_rsp_msk;
    cxl_ch_h2d_rsp_cnt                         = valid_cnt(s_cache_message_vld);
    
    s_cache_message_vld                        = 'd0;
    s_cache_message_vld[H2D_256B_DATA_NUM-1:0] = cxl_ch_h2d_hdr_vld & ~s_cxl_ch_h2d_hdr_halt & ~cxl_ch_h2d_hdr_gnt_halt & r_cxl_ch_h2d_hdr_msk;
    cxl_ch_h2d_hdr_cnt                         = valid_cnt(s_cache_message_vld);
    
    
    // Generate the mask for next page (next cycle) from the number of h2d_req/rsp/hdr sent on the 2nd page
    s_cxl_ch_h2d_req_msk  = {H2D_256B_REQ_NUM{1'b1}}  >> (cxl_ch_h2d_req_cnt);
    s_cxl_ch_h2d_rsp_msk  = {H2D_256B_RESP_NUM{1'b1}} >> (cxl_ch_h2d_rsp_cnt);  
    s_cxl_ch_h2d_hdr_msk  = {H2D_256B_DATA_NUM{1'b1}} >> (cxl_ch_h2d_hdr_cnt);

// generate TL interface halt
// for 8slots packer no need for r_cxl_ch_h2d_req_msk in the calculation of TL interface halt as all the valid h2d_req/rsp/hdr can be sent in the current 128B
    b_txtl_llctrl.s_cxl_h2d_req_halt  = cxl_prot_msg_halt_s ? {H2D_256B_REQ_NUM{1'b1}}     : 
                                        (  ~r_cxl_ch_h2d_req_msk | cxl_ch_h2d_req_gnt_halt | (cxl_ch_h2d_req_vld & s_cxl_ch_h2d_req_halt));
    b_txtl_llctrl.s_cxl_h2d_rsp_halt  = cxl_prot_msg_halt_s ? {H2D_256B_RESP_NUM{1'b1}}    : 
                                        (  ~r_cxl_ch_h2d_rsp_msk | cxl_ch_h2d_rsp_gnt_halt | (cxl_ch_h2d_rsp_vld & s_cxl_ch_h2d_rsp_halt));
    b_txtl_llctrl.s_cxl_h2d_hdr_halt  = cxl_prot_msg_halt_s ? {H2D_256B_DATA_NUM{1'b1}}    : 
                                        (  ~r_cxl_ch_h2d_hdr_msk | cxl_ch_h2d_hdr_gnt_halt | (cxl_ch_h2d_hdr_vld & s_cxl_ch_h2d_hdr_halt));
    b_txtl_llctrl.s_cxl_h2d_data_halt = cxl_prot_data_halt_s? {H2D_256B_DDATA_NUM{1'b1}}   : s_cxl_ch_h2d_data_halt;
  end
  //------------------------------------------------------------
  //            H2D Slot Packing 
  //-----------------------------------------------------------

  function automatic logic [$clog2(H2D_256B_REQ_NUM)  :0] h2d_req_max (
    CXL_SLOT_TYPES                  slot_type
  );
  logic [$clog2(H2D_256B_REQ_NUM)  :0] s_max_cnt;
  begin
    // +------------------+
    // |      H2D REQ     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 1 | 1 |  1 |
    // +-----+---+---+----+
    // | PBR | 1 | 1 |  x |
    // +-----+---+---+----+
    s_max_cnt = 'd1;
    return s_max_cnt;
  end
  endfunction
  function automatic logic [$clog2(H2D_256B_RESP_NUM) :0] h2d_rsp_max (
    CXL_SLOT_TYPES                  slot_type,
    logic                           cxl_slot_idx
  );
  logic [$clog2(H2D_256B_RESP_NUM)  :0] s_max_cnt;
  begin
    // Slot # 1
    // +------------------+
    // |      H2D RSP     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 3 | 2 |  2 |
    // +-----+---+---+----+
    // | PBR | 2 | 2 |  x |
    // +-----+---+---+----+
    
    // Slot # 0
    // +------------------+
    // |      H2D RSP     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 1 | 0 |  0 |
    // +-----+---+---+----+
    // | PBR | 0 | 0 |  x |
    // +-----+---+---+----+
    
    
    s_max_cnt = (cxl_slot_idx)? (((slot_type==CXL_256B_SLOT_G))? 'd3 : 'd2): 
                                (((slot_type==CXL_256B_SLOT_G))? 'd1 : 'd0);
    return s_max_cnt;
  end
  endfunction
  function automatic logic [$clog2(H2D_256B_DATA_NUM) :0] h2d_hdr_max (
      CXL_SLOT_TYPES                  slot_type
    , logic                           mdh_en
  );
  logic [$clog2(H2D_256B_DATA_NUM)  :0] s_max_cnt;
  begin
    // +------------------+
    // |      H2D HDR     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 4 | 3 |  3 |
    // +-----+---+---+----+
    // | PBR | 3 | 3 |  x |
    // +-----+---+---+----+
    s_max_cnt =   (!mdh_en)? 'd1 : 
                              ((slot_type==CXL_256B_SLOT_G))? 'd4 : 'd3;
    return s_max_cnt;
  end
  endfunction
  function automatic SLOT_DESCR_256B_t pack_slot_00 ( 
    logic [H2D_256B_REQ_SIZE-1      : 0] cxl_h2d_req_msg_s [0:H2D_256B_REQ_NUM-1] , 
    logic [H2D_256B_REQ_NUM-1       : 0] cxl_ch_h2d_req_vld                       , 
    logic [H2D_REQ_CNT_WIDTH -1     : 0] h2d_req_idx                              , 
    logic [H2D_256B_RESP_SIZE-1     : 0] cxl_h2d_rsp_msg_s [0:H2D_256B_RESP_NUM-1],
    logic [H2D_256B_RESP_NUM-1      : 0] cxl_ch_h2d_rsp_vld                       , 
    logic [H2D_RSP_CNT_WIDTH-1      : 0] h2d_rsp_idx                              , 
    CXL_SLOT_TYPES                  slot_type
    );
    SLOT_DESCR_256B_t slot_curr;
    logic is_g_slot;
    begin
      // G Slot   : 1 H2D REQ + 1 H2D RSP
      // H/Hs Slot: 1 H2D REQ
      slot_curr           = 'b0;
      slot_curr.Valid     = 1'b1;
      slot_curr.slot_idx  = 'd0;
      slot_curr.slot_type = slot_type;
      is_g_slot           = (slot_type == CXL_256B_SLOT_G);
        slot_curr.Slot[0 +: (H2D_HBR_REQ_SIZE+H2D_HBR_RESP_SIZE)]= 
        {
          cxl_h2d_rsp_msg_s[h2d_rsp_idx][H2D_HBR_RESP_SIZE -1: 0] & {H2D_HBR_RESP_SIZE{is_g_slot & cxl_ch_h2d_rsp_vld[0] }},
          cxl_h2d_req_msg_s[h2d_req_idx][H2D_HBR_REQ_SIZE -1 : 0]
        };
      return slot_curr;
    end
  endfunction
  function automatic SLOT_DESCR_256B_t pack_slot_01( 
    logic [H2D_256B_RESP_SIZE-1     : 0] cxl_h2d_rsp_msg_s [0:H2D_256B_RESP_NUM-1],
    logic [H2D_256B_RESP_NUM-1      : 0] cxl_ch_h2d_rsp_vld                       , 
    logic [H2D_RSP_CNT_WIDTH-1      : 0] h2d_rsp_idx                              , 
    CXL_SLOT_TYPES                       slot_type
    );
    SLOT_DESCR_256B_t slot_curr;
    logic is_g_slot;
    begin
      // G Slot   : 3 H2D RSP
      // H/Hs Slot: 2 H2D RSP
      slot_curr           = 'b0;
      slot_curr.Valid     = 1'b1;
      slot_curr.slot_idx  = 'd1;
      slot_curr.slot_type = slot_type;
      is_g_slot           = (slot_type == CXL_256B_SLOT_G);

// spyglass disable_block ImproperRangeIndex-ML
// SMD: INDEX larger than the bit width required for variable.
// SJ: for out of IDX the valid should be zero
        slot_curr.Slot[0 +: 3*H2D_HBR_RESP_SIZE]= 
        {
        cxl_h2d_rsp_msg_s[h2d_rsp_idx+'d2][H2D_HBR_RESP_SIZE-1:0] & {H2D_HBR_RESP_SIZE{is_g_slot & cxl_ch_h2d_rsp_vld[2]}},
        cxl_h2d_rsp_msg_s[h2d_rsp_idx+'d1][H2D_HBR_RESP_SIZE-1:0] & {H2D_HBR_RESP_SIZE{cxl_ch_h2d_rsp_vld[1]}},
        cxl_h2d_rsp_msg_s[h2d_rsp_idx][H2D_HBR_RESP_SIZE-1:0]
        };
// spyglass enable_block ImproperRangeIndex-ML
      return slot_curr;
    end
  endfunction
  function automatic SLOT_DESCR_256B_t pack_slot_12 ( 
    logic [H2D_256B_DHDR_SIZE-1     : 0] cxl_h2d_hdr_msg_s [0:H2D_256B_DATA_NUM-1],
    logic [H2D_256B_DATA_NUM-1      : 0] cxl_ch_h2d_hdr_vld                 , 
    logic                                h2d_hdr_idx                        , 

    CXL_SLOT_TYPES                       slot_type  
    );
    SLOT_DESCR_256B_t slot_curr;
    logic is_g_slot;
    begin
      // G Slot   : 4 H2D DH
      // H/Hs Slot: 3 H2D DH
      slot_curr           = 'b0;
      slot_curr.Valid     = 1'b1;
      slot_curr.slot_idx  = 'd12;
      slot_curr.slot_type = slot_type;
      is_g_slot           = (slot_type == CXL_256B_SLOT_G);
// spyglass disable_block W468
// SMD: Index variable is too short
// SJ: h2d_hdr_idx is only used when MDH is not enabled.
        slot_curr.Slot[0 +: 4*H2D_HBR_DHDR_SIZE]= 
        {
        cxl_h2d_hdr_msg_s[3][H2D_HBR_DHDR_SIZE - 1: 0] & {H2D_HBR_DHDR_SIZE{cxl_ch_h2d_hdr_vld[3] & is_g_slot}}, 
        cxl_h2d_hdr_msg_s[2][H2D_HBR_DHDR_SIZE - 1: 0] & {H2D_HBR_DHDR_SIZE{cxl_ch_h2d_hdr_vld[2]}}, 
        cxl_h2d_hdr_msg_s[1][H2D_HBR_DHDR_SIZE - 1: 0] & {H2D_HBR_DHDR_SIZE{cxl_ch_h2d_hdr_vld[1]}}, 
        cxl_h2d_hdr_msg_s[h2d_hdr_idx][H2D_HBR_DHDR_SIZE - 1: 0]
        };
        
// spyglass enable_block W468

      unique casez ({is_g_slot
                            , cxl_ch_h2d_hdr_vld[3:0]})
        5'b?_0001: begin 
          slot_curr.Data     = 'd4;
          slot_curr.data_vld = 'b1;
        end
        5'b?_0011: begin  
          slot_curr.Data     = 'd8;
          slot_curr.data_vld = 'b11;
        end
        5'b?_0111,
        5'b0_1111: begin 
          slot_curr.Data     = 'd12;
          slot_curr.data_vld = 'b111;
        end
        5'b1_1111:  begin 
          slot_curr.Data     = 'd16;
          slot_curr.data_vld = 'b1111;
        end
        default  : begin 
          slot_curr.Data     = 'd0;
          slot_curr.data_vld = 'd0;
        end
      endcase
      return slot_curr;
    end
  endfunction
  
  assign cxl_cache_pending = (h2d_req_vld_0 || h2d_rsp_vld_0 || h2d_hdr_vld_0) & pack_enable;


//------------------------------------------------------------
//          Mem Packer
//-----------------------------------------------------------
logic [M2S_256B_BI_RSP_NUM-1:0]  cxl_ch_m2s_bi_rsp_vld_nxt;

logic [M2S_256B_NDR_SIZE-1:0]    cxl_m2s_req_msg_s [0:M2S_256B_NDR_NUM-1];       // M2S Request with no Data Channel - 87 bits
logic [M2S_256B_DHDR_SIZE-1:0]   cxl_m2s_hdr_msg_s [0:M2S_256B_DATA_NUM-1];      // M2S Request with Data Channel Header - 87 bits
logic [M2S_DDATA_SIZE-1:0]       cxl_m2s_data_msg_s[0:M2S_DDATA_NUM-1];          // M2S Data - 4x16B
logic [M2S_DBE_SIZE-1:0]         s_cxl_m2s_be[0:M2S_DDATA_NUM-1];                // Byte Enable
logic [M2S_256B_BI_RSP_SIZE-1:0] cxl_m2s_bi_rsp_msg_s [0:M2S_256B_BI_RSP_NUM-1]; // M2S BI Response Data Channel - 38 bits
logic [M2S_256B_NDR_NUM-1:0]     cxl_ch_m2s_req_gnt_halt;                        // M2S Request Only Channel Valid Bits
logic [M2S_256B_DATA_NUM-1:0]    cxl_ch_m2s_rwd_gnt_halt;                        // M2S RwD Channel Valid Bits
logic [M2S_256B_BI_RSP_NUM-1:0]  cxl_ch_m2s_bi_rsp_gnt_halt;                     // M2S BI Response Channel Valid Bits
logic                            cfg_mem_poison_start_r;
logic                            cfg_mem_poison_r, cfg_mem_poison_nxt;


SLOT_DESCR_256B_t mem_data_slots    [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];
SLOT_DESCR_256B_t mem_n_cache_slots [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];
SLOT_DESCR_256B_t mem_hdr_slots     [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];

CXL_SLOT_TYPES                        mem_slot_type;
CXL_SLOT_TYPES                        mem_data_slot_type;
logic [M2S_REQ_CNT_WIDTH - 1   : 0]   m2s_req_idx;
logic [M2S_BI_RSP_CNT_WIDTH - 1: 0]   m2s_bi_rsp_idx;
logic [M2S_HDR_CNT_WIDTH - 1   : 0]   m2s_hdr_idx;
logic [SLOT_CNT_WIDTH_PAGE - 1 : 0]   cache_slot_idx;

logic mem_data_vld;
CXL_MEM_RR_HDR_STATE                  s_rr_mem_req       [0 : FLIT_SLOT_NUM-1];
CXL_MEM_RR_HDR_STATE                  r_rr_mem_req       [0 : FLIT_SLOT_NUM-1];
CXL_MEM_RR_HDR_STATE                  s_rr_mem_req_temp  [0 : FLIT_SLOT_NUM-1];
CXL_MEM_RR_DATA_STATE                 r_rr_mem_data, s_rr_mem_data;
logic                                 s_mem_req_vld, s_mem_bi_vld;
logic [M2S_DDATA_NUM-1: 0 ]           m2s_beb;                    // M2S Byte Enable Bit

logic [$clog2(M2S_256B_NDR_NUM):0]    cxl_ch_m2s_req_cnt;       // Number of valid M2S Request Only Messages in the output flit
logic [$clog2(M2S_256B_DATA_NUM):0]   cxl_ch_m2s_hdr_cnt;       // Number of valid M2S Data Messages in the output flit
logic [$clog2(M2S_256B_BI_RSP_NUM):0] cxl_ch_m2s_bi_rsp_cnt;    // Number of valid M2S BI Response Messages in the output flit
logic [$clog2(M2S_DDATA_NUM):0]       cxl_ch_m2s_data_cnt;      // Number of valid M2S Data Blocks in the output flit


logic [M2S_256B_NDR_NUM-1   :0]       s_cxl_ch_m2s_req_halt;       
logic [M2S_256B_DATA_NUM-1  :0]       s_cxl_ch_m2s_hdr_halt;       
logic [M2S_256B_BI_RSP_NUM-1:0]       s_cxl_ch_m2s_bi_rsp_halt;    
logic [M2S_DDATA_NUM-1      :0]       s_cxl_ch_m2s_data_halt;      

logic                                 s_mem_data_vld, s_mem_req_rsp_vld;
logic [SLOT_CNT_WIDTH_PAGE - 1   : 0] mem_hdr_slot_idx, mem_data_slot_idx;

logic                                 s_m2s_req_ze;              // Zero Extended Flag for M2S Req
logic                                 s_m2s_rwd_ze;              // Zero Extended Flag for M2S RwD

logic                                 force_gslot_mem_hdr_n;     // Force 1st slot to be a G slot in mem headers packer
logic                                 force_gslot_mem_data_n;    // Force 1st slot to be a G slot in mem Data packer
logic                                 mem_round;                 // Current RR arbitration is Mem
// -------------------------------------------------------------------------------------
// CXL.Mem Poison Mode
// -------------------------------------------------------------------------------------
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
//----------------------------------------------------------------------
//              Mask Generation logic
//----------------------------------------------------------------------
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      r_cxl_ch_m2s_req_msk    <= #TP '1;
      r_cxl_ch_m2s_rwd_msk    <= #TP '1;
      r_cxl_ch_m2s_bi_rsp_msk <= #TP '1;
    end
    else if (!cxl_prot_msg_halt_s) begin
      r_cxl_ch_m2s_req_msk    <= #TP s_cxl_ch_m2s_req_msk;
      r_cxl_ch_m2s_rwd_msk    <= #TP s_cxl_ch_m2s_rwd_msk;
      r_cxl_ch_m2s_bi_rsp_msk <= #TP s_cxl_ch_m2s_bi_rsp_msk;
    end
end
// -------------------------------------------------------------------------------------
// Extarct channel message valid bits
// -------------------------------------------------------------------------------------

always_comb begin
    for (int i = 0; i < M2S_256B_NDR_NUM; i++) begin
        cxl_m2s_req_msg_s[i] = (b_llctrl.s_cxl_ll_mem_ndr_gnt[i]) ? b_txtl_llctrl.s_cxl_m2s_req[i] : '0;
        cxl_ch_m2s_req_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_mem_ndr_gnt[i]) & b_txtl_llctrl.s_cxl_m2s_req[i][M2S_NDR_VLD];
    end
    // H  slot size is 14 Bytes 
    // Hs slot size is 12 Bytes
    // Check the Exteneded bits is equal to zero to pack these M2S REQ in H/Hs slots
    // In case of Cache Round this means the Cache packer will pack H/Hs slots and The Mem packer will pack G slots only so there is no need to check ZE
    // In case Lopt and PBR is not definend ZE is always 1
    s_m2s_req_ze = !mem_round |
                    ( 
 1'b1
                    );
    // No need to check MDH here bec. we can pack only 1 M2S RwD per slot
    for (int i = 0; i < M2S_256B_DATA_NUM; i++) begin
      cxl_m2s_hdr_msg_s[i] = (b_llctrl.s_cxl_ll_mem_dr_gnt[i]  & b_txtl_llctrl.s_cxl_m2s_data_vld[0] & cxl_data_en) ? b_txtl_llctrl.s_cxl_m2s_hdr[i] : '0;
      cxl_ch_m2s_rwd_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_mem_dr_gnt[i]  & b_txtl_llctrl.s_cxl_m2s_data_vld[0] & cxl_data_en) & b_txtl_llctrl.s_cxl_m2s_hdr[i][M2S_HDR_VLD];
    end
    s_m2s_rwd_ze =  !mem_round |
                    ( 
 1'b1
                    );
    // Overwrite Poison Bit
    cxl_m2s_hdr_msg_s[0][M2S_256B_POISON_BIT] = cxl_m2s_hdr_msg_s[0][M2S_HDR_VLD] ? (b_txtl_llctrl.s_cxl_m2s_hdr[0][M2S_256B_POISON_BIT] | cfg_mem_poison_r) : 1'b0;
    for (int i = 0; i < M2S_DDATA_NUM; i++) cxl_m2s_data_msg_s[i] = b_txtl_llctrl.s_cxl_m2s_data[i];
    for (int i = 0; i < M2S_DDATA_NUM; i++) s_cxl_m2s_be[i] = b_txtl_llctrl.s_cxl_m2s_be[i];
    for (int i = 0; i < M2S_256B_BI_RSP_NUM; i++) begin
        cxl_m2s_bi_rsp_msg_s[i] = (b_llctrl.s_cxl_ll_mem_bi_gnt[i]) ? b_txtl_llctrl.s_cxl_m2s_bi_rsp[i] : '0;
        cxl_ch_m2s_bi_rsp_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_mem_bi_gnt[i]) & b_txtl_llctrl.s_cxl_m2s_bi_rsp[i][M2S_BI_RSP_VLD];
    end
end

always_comb begin
  for (int i = 0; i < M2S_256B_NDR_NUM; i++)  cxl_ch_m2s_req_vld[i] = cxl_m2s_req_msg_s[i][M2S_NDR_VLD];
  for (int i = 0; i < M2S_256B_DATA_NUM; i++) cxl_ch_m2s_rwd_vld[i] = cxl_m2s_hdr_msg_s[i][M2S_HDR_VLD];
  for (int i = 0; i < M2S_256B_BI_RSP_NUM; i++) cxl_ch_m2s_bi_rsp_vld[i] = cxl_m2s_bi_rsp_msg_s[i][M2S_BI_RSP_VLD];
end

assign m2s_bi_rsp_vld_0 = cxl_ch_m2s_bi_rsp_vld[0] & r_cxl_ch_m2s_bi_rsp_msk[0];
assign m2s_rwd_vld_0    = cxl_ch_m2s_rwd_vld[0] & r_cxl_ch_m2s_rwd_msk[0];
assign m2s_req_vld_0    = cxl_ch_m2s_req_vld[0] & r_cxl_ch_m2s_req_msk[0];

// -------------------------------------------------------------------------------------
// Generate valid signals for credit tracking
// -------------------------------------------------------------------------------------
assign mem_req_vld    = {{(TX_CRDIF_WIDTH-M2S_256B_NDR_NUM){1'b0}} , cxl_ch_m2s_req_vld & ~b_txtl_llctrl.s_cxl_m2s_req_halt};
assign mem_hdr_vld    = {{(TX_CRDIF_WIDTH-M2S_256B_DATA_NUM){1'b0}}, cxl_ch_m2s_rwd_vld & ~b_txtl_llctrl.s_cxl_m2s_hdr_halt};
assign mem_rsp_vld    = {{(TX_CRDIF_WIDTH-M2S_256B_BI_RSP_NUM){1'b0}} , cxl_ch_m2s_bi_rsp_vld & ~b_txtl_llctrl.s_cxl_m2s_bi_rsp_halt};

// -------------------------------------------------------------------------------------
// Mem arbitration logic
// -------------------------------------------------------------------------------------
// M2S BI & REQ arbitration
always_comb begin  
  s_rr_mem_req  = r_rr_mem_req;
  s_mem_req_vld = mem_req_vld[0];
  s_mem_bi_vld  = mem_rsp_vld[0];   
  if ((s_rr_mem_req[0]==CXL_MEM_RR_REQ && s_mem_req_vld & s_m2s_req_ze) ||
      (s_rr_mem_req[0]==CXL_MEM_RR_BI && s_mem_bi_vld) ) begin
    for(int i=1;i<FLIT_SLOT_NUM;i++) begin
      s_rr_mem_req[i-1] = r_rr_mem_req[i];
    end
    s_rr_mem_req[FLIT_SLOT_NUM-1] = r_rr_mem_req[0];
  end
end  
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin 
    for (int i = 0; i< FLIT_SLOT_NUM;i++) begin
      if (i%2 == 0)
        r_rr_mem_req[i] <= #TP CXL_MEM_RR_REQ;
      else
        r_rr_mem_req[i] <= #TP CXL_MEM_RR_BI;
    end
  end
  else if(!cxl_prot_msg_halt_s) begin
    for (int i = 0; i< FLIT_SLOT_NUM;i++)
      r_rr_mem_req[i] <= #TP s_rr_mem_req[i];
  end
end

// Data & HDR arbitration
always_comb begin  
  s_rr_mem_data     = r_rr_mem_data;
  s_mem_data_vld    = mem_hdr_vld[0];
  s_mem_req_rsp_vld = mem_req_vld[0] | mem_rsp_vld[0] ;
  if ((s_rr_mem_data==CXL_MEM_RR_DATA && s_mem_data_vld) ||
      (s_rr_mem_data==CXL_MEM_RR_HDR && s_mem_req_rsp_vld) ) begin
    s_rr_mem_data = (r_rr_mem_data==CXL_MEM_RR_DATA)? CXL_MEM_RR_HDR : CXL_MEM_RR_DATA;
  end
end  
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin 
    r_rr_mem_data <= #TP CXL_MEM_RR_HDR;
  end
  else if(!cxl_prot_msg_halt_s && !cxl_prot_data_halt_s) begin
    r_rr_mem_data <= #TP s_rr_mem_data;
  end
end

// -------------------------------------------------------------------------------------
// MEM Data packing
// -------------------------------------------------------------------------------------
assign mem_round   = (mem_cache_arb==CXL_256B_MEM) | (!h2d_rsp_vld_0 & !h2d_req_vld_0 &  !h2d_hdr_vld_0) ;

always_comb begin  
  force_gslot_mem_data_n = (
  (!m2s_req_vld_0 & !m2s_bi_rsp_vld_0) | 
  (r_rr_mem_data == CXL_MEM_RR_DATA)
  )  & mem_round & s_m2s_rwd_ze;
  
  if (FLIT_SLOT_NUM > 1) mem_data_slot_type = (force_gslot_mem_data_n)? cxl_slot_type : CXL_256B_SLOT_G;
  else                   mem_data_slot_type = cxl_slot_type; 
  cxl_ch_m2s_rwd_vld_nxt     = cxl_ch_m2s_rwd_vld & r_cxl_ch_m2s_rwd_msk;
  m2s_beb[0]                 =
                                                                                    cxl_m2s_hdr_msg_s[0][M2S_RWD_BEB_IDX_HBR];
   
  for (int i =0;i<FLIT_SLOT_NUM;i++) mem_data_slots[i/4][i%4] = 'd0;
  
  if (cxl_ch_m2s_rwd_vld_nxt[0]) begin
    mem_data_slots[0][0] = pack_slot_14 (cxl_m2s_hdr_msg_s, 'd0, mem_data_slot_type);
    mem_data_slots[0][1] = pack_data(cxl_m2s_data_msg_s[shift_m2s_data], s_cxl_m2s_be[shift_m2s_data],'d0,  m2s_beb[0], CXL_256B_MEM_M);
    mem_data_slots[0][2] = pack_data(cxl_m2s_data_msg_s[shift_m2s_data], s_cxl_m2s_be[shift_m2s_data],'d1,  m2s_beb[0], CXL_256B_MEM_M);
    mem_data_slots[0][3] = pack_data(cxl_m2s_data_msg_s[shift_m2s_data], s_cxl_m2s_be[shift_m2s_data],'d2,  m2s_beb[0], CXL_256B_MEM_M);
  end


end


// -------------------------------------------------------------------------------------
// MEM Headers packing
// -------------------------------------------------------------------------------------
logic [$clog2(M2S_256B_BI_RSP_NUM):0] s_cxl_ch_m2s_bi_rsp_cnt [0:3]; 
logic [$clog2(M2S_256B_BI_RSP_NUM):0] s_cxl_ch_m2s_req_cnt [0:3]; 
logic [7:0] mem_hdr_temp_vld;
always_comb begin   
  cxl_ch_m2s_req_vld_nxt     = cxl_ch_m2s_req_vld & r_cxl_ch_m2s_req_msk;
  cxl_ch_m2s_bi_rsp_vld_nxt  =  cxl_ch_m2s_bi_rsp_vld & r_cxl_ch_m2s_bi_rsp_msk;

  m2s_hdr_idx                = 'd0;
  m2s_req_idx                = 'd0;
  m2s_bi_rsp_idx             = 'd0;
  // Force BI RSP in M2S REQ Zero Extended is not 1 to avoid pack M2S REQ at H/Hs slot
  if (s_m2s_req_ze) begin
    s_rr_mem_req_temp = r_rr_mem_req;
  end
  else begin
    for (int i = 0; i< FLIT_SLOT_NUM;i++) begin
      if (i%2 == 0)
        s_rr_mem_req_temp[i] = CXL_MEM_RR_BI;
      else
        s_rr_mem_req_temp[i] = CXL_MEM_RR_REQ;
    end
  end
    
  
  for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM; slot_idx++) begin
    mem_hdr_temp_vld = '0;
    mem_hdr_slots[slot_idx/4][slot_idx%4] = 'b0;
    force_gslot_mem_hdr_n  = (slot_idx==0) & (!(m2s_rwd_vld_0 & s_m2s_rwd_ze) | (r_rr_mem_data == CXL_MEM_RR_HDR)) & mem_round & (s_m2s_req_ze 
 | m2s_bi_rsp_vld_0);
    if (FLIT_SLOT_NUM > 1)  mem_slot_type = (force_gslot_mem_hdr_n)? cxl_slot_type : CXL_256B_SLOT_G;
    else                    mem_slot_type = cxl_slot_type;
    
// spyglass disable_block STARC05-2.8.1.3
// SMD: case constructs should not have overlapping clause conditions. (Verilog)
// SJ: This is to enable synthesis optimization
    casez ({s_rr_mem_req_temp[slot_idx] ,cxl_ch_m2s_req_vld_nxt[0], cxl_ch_m2s_bi_rsp_vld_nxt[0]})
      3'b?_0_1,
      {CXL_MEM_RR_BI, 2'b?_1}: begin 
        mem_hdr_slots[slot_idx/4][slot_idx%4]     = pack_slot_05 (cxl_m2s_bi_rsp_msg_s, cxl_ch_m2s_bi_rsp_vld_nxt, m2s_bi_rsp_idx, mem_slot_type);
        m2s_bi_rsp_idx                            = m2s_bi_rsp_idx + m2s_birsp_max(mem_slot_type);  
        cxl_ch_m2s_bi_rsp_vld_nxt                 = cxl_ch_m2s_bi_rsp_vld_nxt >>  m2s_birsp_max(mem_slot_type); 
      end
      3'b?_1_0,
      {CXL_MEM_RR_REQ ,2'b1_?}: begin 
        mem_hdr_slots[slot_idx/4][slot_idx%4]  = pack_slot_04 (cxl_m2s_req_msg_s, cxl_ch_m2s_req_vld_nxt, m2s_req_idx, mem_slot_type);
        m2s_req_idx                            = m2s_req_idx + m2s_req_max(mem_slot_type);
        cxl_ch_m2s_req_vld_nxt                 = cxl_ch_m2s_req_vld_nxt >> m2s_req_max(mem_slot_type); 
      end
    endcase
// spyglass enable_block STARC05-2.8.1.3
  end
end

// -------------------------------------------------------------------------------------
// Mem Data + Headers packing
// -------------------------------------------------------------------------------------
  logic skip_frst_slot;
  logic skip_hdr_slot;
  logic skip_dhdr_slot;
  // In case the M2S Req is not ZE and there is no BI message to be sent in H/Hs slot the We will send the DHDR (in case the DHDR is ZE)
  // Regardless the RR arbitration --> skip_hdr_slot
  // In case the M2S DHDR is not ZE, the H/Hs slot should carry normal M2S HDR, then pack the remaining slots with the Data Slots --> skip_dhdr_slot
  // In case Both DHDR and HDR are not ZE, then we can not pack any M2S HDRs/DHDRs to the H/Hs slot. --> skip_frst_slot
  // In case of skip_frst_slot asserted we should not pack Cache slots to avoid pack Cache DHDR slots in the H/HS slots 
  // Because if this happened we will not be able to send the Remaining M2S HDRs/DHDRs
  always_comb begin   
    mem_data_slot_idx  = 'd0;
    mem_hdr_slot_idx   = 'd0;
    skip_hdr_slot      = !s_m2s_req_ze & !m2s_bi_rsp_vld_0;
    
    for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM_PAGE; slot_idx++) begin  
      skip_dhdr_slot = (slot_idx==0)? !s_m2s_rwd_ze : 1'b0;
      skip_frst_slot = (slot_idx==0)? skip_hdr_slot & !s_m2s_rwd_ze : 1'b0;
      mem_slots[0][slot_idx] = 'd0;

      if (!skip_frst_slot) begin
        if (
        !mem_hdr_slots[0][slot_idx].Valid | 
        (((r_rr_mem_data == CXL_MEM_RR_DATA) | skip_hdr_slot) & m2s_rwd_vld_0 & !skip_dhdr_slot) // In case s_m2s_rwd_ze flag is not set 1st slot must carry HDR
        ) begin
          mem_slots[0][slot_idx] = mem_data_slots[0][mem_data_slot_idx];
          mem_data_slot_idx      = mem_data_slot_idx + 'd1;
        end
        else begin
          mem_slots[0][slot_idx] = mem_hdr_slots[0][slot_idx];
          mem_hdr_slot_idx         = mem_hdr_slot_idx + 'd1;
        end
      end
    end

  end
  
// -------------------------------------------------------------------------------------
// Pack Cache Slots in empty Mem Slots
// -------------------------------------------------------------------------------------
 logic [SLOT_CNT_WIDTH_PAGE - 1   : 0] mem_temp_slot_idx;

always_comb begin 
  cache_slot_idx    = 'd0;
  for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM_PAGE; slot_idx++) begin
    mem_n_cache_slots[0][slot_idx] = mem_slots[0][slot_idx];
    if ((!mem_slots[0][slot_idx].Valid & !skip_frst_slot)) begin
      mem_n_cache_slots[0][slot_idx] = cache_slots[0][cache_slot_idx];
      cache_slot_idx                 = cache_slot_idx + 'd1;
    end
  end

end
assign mem_flit = mem_n_cache_slots;


// -------------------------------------------------------------------------------------
// Mem Halt Gen
// -------------------------------------------------------------------------------------
logic [8-1:0] s_mem_message_vld;
CXL_SLOT_TYPES mem_halt_slot_type;
always_comb begin 
  cxl_ch_m2s_req_cnt       = 'd0;
  cxl_ch_m2s_hdr_cnt       = 'd0;
  cxl_ch_m2s_bi_rsp_cnt    = 'd0;
  cxl_ch_m2s_data_cnt      = 'd0;
  
  s_cxl_ch_m2s_req_halt    = '1;
  s_cxl_ch_m2s_hdr_halt    = '1;
  s_cxl_ch_m2s_bi_rsp_halt = '1;
  s_cxl_ch_m2s_data_halt   = '1;
  
  for (int slot_idx=0; slot_idx<FLIT_SLOT_NUM_PAGE ;slot_idx++) begin
    mem_halt_slot_type = (slot_idx==0)? cxl_slot_type : CXL_256B_SLOT_G;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: No overflow expected
      // M2S REQ
    if (cxl_packer_flit[slot_idx].slot_idx == 'd4)begin
      s_cxl_ch_m2s_req_halt = s_cxl_ch_m2s_req_halt << m2s_req_max(mem_halt_slot_type);
    end
    // M2S BIRsp
    if (cxl_packer_flit[slot_idx].slot_idx == 'd5)begin
      s_cxl_ch_m2s_bi_rsp_halt = s_cxl_ch_m2s_bi_rsp_halt << m2s_birsp_max(mem_halt_slot_type);
    end
    // M2S HDR
    if (cxl_packer_flit[slot_idx].slot_idx == 'd14)begin
      s_cxl_ch_m2s_hdr_halt = s_cxl_ch_m2s_hdr_halt << m2s_hdr_max(mem_halt_slot_type);
    end
// spyglass enable_block W164a
    if (cxl_packer_flit[slot_idx].data_info.data_strt && (cxl_packer_flit[slot_idx].data_info.data_type==CXL_256B_MEM_M)) begin
      s_cxl_ch_m2s_data_halt = s_cxl_ch_m2s_data_halt << 1;
      cxl_ch_m2s_data_cnt++;
    end
  end
  
  s_mem_message_vld                          = 'd0;
  s_mem_message_vld[M2S_256B_NDR_NUM-1:0]    = cxl_ch_m2s_req_vld & ~s_cxl_ch_m2s_req_halt & ~cxl_ch_m2s_req_gnt_halt & r_cxl_ch_m2s_req_msk;
  cxl_ch_m2s_req_cnt                         = valid_cnt(s_mem_message_vld);

  s_mem_message_vld                          = 'd0;
  s_mem_message_vld[M2S_256B_DATA_NUM-1:0]   = cxl_ch_m2s_rwd_vld & ~s_cxl_ch_m2s_hdr_halt & ~cxl_ch_m2s_rwd_gnt_halt & r_cxl_ch_m2s_rwd_msk;
  cxl_ch_m2s_hdr_cnt                         = valid_cnt(s_mem_message_vld);
  
  s_mem_message_vld                          = 'd0;
  s_mem_message_vld[M2S_256B_BI_RSP_NUM-1:0] = cxl_ch_m2s_bi_rsp_vld & ~s_cxl_ch_m2s_bi_rsp_halt & ~cxl_ch_m2s_bi_rsp_gnt_halt & r_cxl_ch_m2s_bi_rsp_msk;
  cxl_ch_m2s_bi_rsp_cnt                      = valid_cnt(s_mem_message_vld);

   


  s_cxl_ch_m2s_req_msk    =  {M2S_256B_NDR_NUM{1'b1}}     >> (cxl_ch_m2s_req_cnt);
  s_cxl_ch_m2s_rwd_msk    =  {M2S_256B_DATA_NUM{1'b1}}    >> (cxl_ch_m2s_hdr_cnt);
  s_cxl_ch_m2s_bi_rsp_msk =  {M2S_256B_BI_RSP_NUM{1'b1}}  >> (cxl_ch_m2s_bi_rsp_cnt);
  // Halt corresponding message channels
  // Halt Protocol Message Channels only if the message is valid otherwise do not assert
  // halt signal to allow channel to proceed

  b_txtl_llctrl.s_cxl_m2s_req_halt = cxl_prot_msg_halt_s ? {M2S_256B_NDR_NUM{1'b1}}        : 
                                    (  ~r_cxl_ch_m2s_req_msk | cxl_ch_m2s_req_gnt_halt | (cxl_ch_m2s_req_vld & s_cxl_ch_m2s_req_halt));
  b_txtl_llctrl.s_cxl_m2s_hdr_halt = cxl_prot_msg_halt_s ? {M2S_256B_DATA_NUM{1'b1}}       : 
                                    (  ~r_cxl_ch_m2s_rwd_msk | cxl_ch_m2s_rwd_gnt_halt | (cxl_ch_m2s_rwd_vld & s_cxl_ch_m2s_hdr_halt));
  b_txtl_llctrl.s_cxl_m2s_bi_rsp_halt = cxl_prot_msg_halt_s ? {M2S_256B_BI_RSP_NUM{1'b1}}  : 
                                      (  ~r_cxl_ch_m2s_bi_rsp_msk | cxl_ch_m2s_bi_rsp_gnt_halt | (cxl_ch_m2s_bi_rsp_vld & s_cxl_ch_m2s_bi_rsp_halt));
  b_txtl_llctrl.s_cxl_m2s_data_halt = cxl_prot_data_halt_s?  {M2S_DDATA_NUM{1'b1}}         : s_cxl_ch_m2s_data_halt;
end


 
function automatic logic [$clog2(M2S_256B_NDR_NUM)    :0] m2s_req_max   (
    CXL_SLOT_TYPES                  slot_type
  );
  logic [$clog2(M2S_256B_NDR_NUM)  :0] s_max_cnt;
  begin
    // +------------------+
    // |      M2S REQ     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 1 | 1 |  1 |
    // +-----+---+---+----+
    // | PBR | 1 | 1 |  x |
    // +-----+---+---+----+
    s_max_cnt = 'd1;
    return s_max_cnt;
  end
endfunction
function automatic logic [$clog2(M2S_256B_BI_RSP_NUM) :0] m2s_birsp_max (
    CXL_SLOT_TYPES                  slot_type
  );
  logic [$clog2(M2S_256B_BI_RSP_NUM)  :0] s_max_cnt;
  begin
    // +------------------+
    // |   M2S BI-RSP     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 3 | 2 |  2 |
    // +-----+---+---+----+
    // | PBR | 2 | 2 |  x |
    // +-----+---+---+----+

    
    s_max_cnt = ((slot_type==CXL_256B_SLOT_G)) ? 'd3 : 'd2;
    return s_max_cnt;
end
endfunction
function automatic logic [$clog2(M2S_256B_DATA_NUM)   :0] m2s_hdr_max   (
    CXL_SLOT_TYPES                  slot_type
  );
  logic [$clog2(M2S_256B_DATA_NUM)  :0] s_max_cnt;
  begin
    // +------------------+
    // |      M2S HDR     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 1 | 1 |  1 |
    // +-----+---+---+----+
    // | PBR | 1 | 1 |  x |
    // +-----+---+---+----+
    s_max_cnt = 'd1;
    return s_max_cnt;
  end
endfunction

function automatic SLOT_DESCR_256B_t pack_slot_04( 
  logic [M2S_256B_NDR_SIZE-1      : 0] cxl_m2s_req_msg_s [0:M2S_256B_NDR_NUM-1] ,
  logic [M2S_256B_NDR_NUM-1       : 0] cxl_ch_m2s_req_vld                       , 
  logic [M2S_REQ_CNT_WIDTH-1      : 0] m2s_req_idx                              , 
  CXL_SLOT_TYPES                       slot_type
  );
  SLOT_DESCR_256B_t slot_curr;
  begin
    // G Slot   : 1 M2S REQ
    // H/Hs Slot: 1 M2S REQ
    slot_curr           = 'b0;
    slot_curr.Valid     = 1'b1;
    slot_curr.slot_idx  = 'd4;
    slot_curr.slot_type = slot_type;
      slot_curr.Slot[0 +: M2S_HBR_NDR_SIZE] = 
      {
      cxl_m2s_req_msg_s[m2s_req_idx][0 +: M2S_HBR_NDR_SIZE]
      };
    return slot_curr;
  end
endfunction
function automatic SLOT_DESCR_256B_t pack_slot_05( 
  logic [M2S_256B_BI_RSP_SIZE-1      : 0] cxl_m2s_bi_rsp_msg_s [0:M2S_256B_BI_RSP_NUM-1] ,
  logic [M2S_256B_BI_RSP_NUM-1       : 0] cxl_ch_m2s_bi_rsp_vld                          , 
  logic [M2S_BI_RSP_CNT_WIDTH - 1    : 0] m2s_bi_rsp_idx                                 ,
  CXL_SLOT_TYPES                          slot_type
  );
  SLOT_DESCR_256B_t slot_curr;
  logic is_g_slot;
  begin
    // G Slot   : 3 M2S BIRsp
    // H/Hs Slot: 2 M2S BIRsp
    is_g_slot           = (slot_type == CXL_256B_SLOT_G);
    slot_curr           = 'b0;
    slot_curr.Valid     = 1'b1;
    slot_curr.slot_idx  = 'd5;
    slot_curr.slot_type = slot_type;
// spyglass disable_block ImproperRangeIndex-ML
// SMD: INDEX larger than the bit width required for variable.
// SJ: for out of IDX the valid should be zero
      slot_curr.Slot [0 +: 3*M2S_HBR_BI_RSP_SIZE]= 
      {
      cxl_m2s_bi_rsp_msg_s[m2s_bi_rsp_idx+2][0 +: M2S_HBR_BI_RSP_SIZE] & {M2S_HBR_BI_RSP_SIZE{cxl_ch_m2s_bi_rsp_vld[2] & is_g_slot}},
      cxl_m2s_bi_rsp_msg_s[m2s_bi_rsp_idx+1][0 +: M2S_HBR_BI_RSP_SIZE] & {M2S_HBR_BI_RSP_SIZE{cxl_ch_m2s_bi_rsp_vld[1]}},
      cxl_m2s_bi_rsp_msg_s[m2s_bi_rsp_idx  ][0 +: M2S_HBR_BI_RSP_SIZE]
      };
// spyglass enable_block ImproperRangeIndex-ML

    return slot_curr;
  end
endfunction
function automatic SLOT_DESCR_256B_t pack_slot_14( 
  logic [M2S_256B_DHDR_SIZE-1      : 0] cxl_m2s_hdr_msg_s [0:M2S_256B_DATA_NUM-1] ,
  logic [M2S_HDR_CNT_WIDTH-1       : 0] m2s_hdr_idx                               , 
  CXL_SLOT_TYPES                        slot_type
  );
  SLOT_DESCR_256B_t slot_curr;
  begin
    // G Slot   : 1 M2S RwD
    // H/Hs Slot: 1 M2S RwD
    slot_curr           = 'b0;
    slot_curr.Valid     = 1'b1;
    slot_curr.slot_idx  = 'd14;
    slot_curr.slot_type = slot_type;
      slot_curr.Slot[0 +: M2S_HBR_DHDR_SIZE]= 
      {
      cxl_m2s_hdr_msg_s[m2s_hdr_idx][0 +: M2S_HBR_DHDR_SIZE]
      };
    slot_curr.Data       = 'd4 + (
                                                                                cxl_m2s_hdr_msg_s[m2s_hdr_idx][M2S_RWD_BEB_IDX_HBR]);
    slot_curr.data_vld   = 'b1;
    slot_curr.be_vld[0]  =
                                                                                cxl_m2s_hdr_msg_s[m2s_hdr_idx][M2S_RWD_BEB_IDX_HBR];
    return slot_curr;
  end
endfunction




assign cxl_mem_pending = pack_enable & (m2s_req_vld_0 || m2s_rwd_vld_0
 || m2s_bi_rsp_vld_0) ;



assign cxl_tl_pending_o = (1'b0    || b_txtl_llctrl.s_cxl_h2d_req[0][H2D_REQ_VLD] || b_txtl_llctrl.s_cxl_h2d_rsp[0][H2D_RESP_VLD] || b_txtl_llctrl.s_cxl_h2d_hdr[0][H2D_HDR_VLD]
    || b_txtl_llctrl.s_cxl_m2s_req[0][M2S_NDR_VLD] || b_txtl_llctrl.s_cxl_m2s_hdr[0][M2S_HDR_VLD]
 || b_txtl_llctrl.s_cxl_m2s_bi_rsp[0][M2S_BI_RSP_VLD] );
                               

endmodule
