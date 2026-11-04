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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_packer_256byte_usp.sv#2 $
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "CXL/svif/DWC_cxl_pack_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_txtl_llctrl_if.svh"

module DWC_cxl_mem_cache_packer_256byte_usp
    import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)
                                               (
    input                                     core_clk,                                // Core clock
    input                                     core_rst_n,                              // Core active low asynchronous reset
    input                                     pack_enable,                             // Enable Flit Packer
    input  SLOT_DESCR_256B_t                  cxl_packer_flit  [0 : FLIT_SLOT_NUM-1],  // Flit on the Packer output
    input                                     cxl_prot_msg_halt,                       // CXL Protocol Message Channel Halt
    input                                     cxl_prot_data_halt,                      // CXL Protocol Data Channel Halt
    input CXL_SLOT_TYPES                      cxl_slot_type,                           // Define Slot#0 Type G, H or Hs
    input                                     cxl_rst_msk,                             // Reset HDRs counters
    input                                     cxl_data_en,                             // Enable data HDR packing 
    input RR_256B_ARB_STATE_t                 mem_cache_arb,                           // Current cycle is MEM or Cache round
    input [5:0]                               roll_over_cnt,                           // Rollover counter

    input                                     shift_d2h_data,                           // Shift D2H data channel in Case the Data packer (Rollover packer) Used 1st channel
    input                                     cfg_cache_poison_start,                   // CachePoisonInjectionStart
    output                                    cfg_cache_poison_busy,                    // CachePoisonInjectionBusy
    output [TX_CRDIF_WIDTH-1:0]               cache_req_vld,                            // CXL.cache Request channel valid bit
    output [TX_CRDIF_WIDTH-1:0]               cache_rsp_vld,                            // CXL.cache Response channel valid bit
    output [TX_CRDIF_WIDTH-1:0]               cache_hdr_vld,                            // CXL.cache Data channel valid bit
    output SLOT_DESCR_256B_t                  cache_flit [0:FLIT_NUM_PAGE-1]
                                                       [0 : FLIT_SLOT_NUM_PAGE-1],      // CXL.cache Slot Information
    output logic                              cxl_cache_pending,                        // CXL.cache pending requests
    input                                     shift_s2m_data,                            // Shift M2S data channel in Case the Data packer (Rollover packer) Used 1st channel
    input                                     cfg_mem_poison_start,                      // MemPoisonInjectionStart
    output                                    cfg_mem_poison_busy,                       // MemPoisonInjectionBusy
    output [TX_CRDIF_WIDTH-1:0]               mem_rsp_vld,                               // CXL.mem RSP channel valid bit
    output [TX_CRDIF_WIDTH-1:0]               mem_hdr_vld,                               // CXL.mem Data channel valid bit
    output SLOT_DESCR_256B_t                  mem_flit [0:FLIT_NUM_PAGE-1]
                                                            [0 : FLIT_SLOT_NUM_PAGE-1],  // CXL.Mem Slot Information
    output logic                              cxl_mem_pending,                           // CXL.mem pending requests
    output [TX_CRDIF_WIDTH-1:0]               mem_req_vld,                                // CXL.mem BI Snoop channel valid bit
    output logic                              cxl_tl_pending_o,                           // Pending message on the TL Interface
    DWC_cxl_pack_llctrl_if.slave_ctrl_mp      b_llctrl,                                   // Link Layer Controller to Flit Packer Interface
    DWC_cxl_txtl_llctrl_if.pack_slave_dev_mp  b_txtl_llctrl                               // Flit Packer to Transaction Layer Interface

);

// Channel Halt Generation Signals
logic                        cxl_prot_msg_halt_s;          // CXL Protocol Message Channel Halt
logic                        cxl_prot_data_halt_s;         // CXL Protocol Data Channel Halt - d2h_data and s2m_data


assign cxl_prot_msg_halt_s  = ~pack_enable | cxl_prot_msg_halt;
assign cxl_prot_data_halt_s = ~pack_enable | cxl_prot_data_halt;


SLOT_DESCR_256B_t       mem_slots[0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];           // Mem Only flit without cache                             

logic [S2M_256B_NDR_NUM-1:0]     cxl_ch_s2m_ndr_vld, cxl_ch_s2m_ndr_vld_nxt;    // S2M Request Only Channel Valid Bits
logic [S2M_256B_DATA_NUM-1:0]    cxl_ch_s2m_drs_vld, cxl_ch_s2m_drs_vld_nxt;    // S2M DRS Channel Valid Bits
logic [S2M_256B_BI_SNP_NUM-1:0]   cxl_ch_s2m_bi_snp_vld; // S2M BI Snoop Channel Valid Bits
logic s2m_drs_vld_0, s2m_bi_snp_vld_0, s2m_ndr_vld_0;
logic [3:0] force_mem_data;


logic [D2H_256B_REQ_NUM -1:0]    cxl_ch_d2h_req_vld, cxl_ch_d2h_req_vld_nxt;    // D2H Request Channel Valid Bits
logic [D2H_256B_RESP_NUM-1:0]    cxl_ch_d2h_rsp_vld, cxl_ch_d2h_rsp_vld_nxt;    // D2H Response Channel Valid Bits
logic [D2H_256B_DATA_NUM-1:0]    cxl_ch_d2h_hdr_vld, cxl_ch_d2h_hdr_vld_nxt;    // D2H Data Header Channel Valid Bits


logic [D2H_256B_REQ_NUM -1:0]    s_cxl_ch_d2h_req_msk, r_cxl_ch_d2h_req_msk; 
logic [D2H_256B_RESP_NUM-1:0]    s_cxl_ch_d2h_rsp_msk, r_cxl_ch_d2h_rsp_msk; 
logic [D2H_256B_DATA_NUM-1:0]    s_cxl_ch_d2h_hdr_msk, r_cxl_ch_d2h_hdr_msk; 

logic [D2H_256B_REQ_SIZE-1:0]    cxl_d2h_req_msg_s  [0:D2H_256B_REQ_NUM-1];     // D2H Request Channel - 64 bits
logic [D2H_256B_RESP_SIZE-1:0]   cxl_d2h_rsp_msg_s  [0:D2H_256B_RESP_NUM-1];    // D2H Response Channel - 32 bits
logic [D2H_256B_DHDR_SIZE-1:0]   cxl_d2h_hdr_msg_s  [0:D2H_256B_DATA_NUM-1];     // D2H Data Header Channel - 24 bits
logic [D2H_256B_DDATA_SIZE-1:0]  cxl_d2h_data_msg_s [0:D2H_256B_DDATA_NUM-1];   // D2H Data - 4x16B
logic [D2H_256B_DBE_SIZE-1:0]    cxl_d2h_be_s       [0:D2H_256B_DDATA_NUM-1];   // Byte Enable


logic [D2H_256B_REQ_NUM-1:0]     cxl_ch_d2h_req_gnt_halt;     // D2H Request Channel Valid Bits
logic [D2H_256B_RESP_NUM-1:0]    cxl_ch_d2h_rsp_gnt_halt;     // D2H Response Channel Valid Bits
logic [D2H_256B_DATA_NUM-1:0]    cxl_ch_d2h_hdr_gnt_halt;     // D2H Data Header Channel Valid Bits

logic cfg_cache_poison_start_r;
logic cfg_cache_poison_r, cfg_cache_poison_nxt;


SLOT_DESCR_256B_t  cache_data_slots [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];          // Cache Data HDR flit
SLOT_DESCR_256B_t  cache_hdr_slots  [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];          // Cache Header without Data flit
SLOT_DESCR_256B_t  cache_slots      [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];          // Cache Header + Data Flits
SLOT_DESCR_256B_t  cache_n_mem_slots[0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];          // Cache + Mem Flit (Cache has higher priority)

logic [SLOT_CNT_WIDTH_PAGE - 1   : 0] mem_slot_idx;
CXL_SLOT_TYPES                        cache_slot_type;
CXL_SLOT_TYPES                        cache_data_slot_type;
logic [D2H_REQ_CNT_WIDTH - 1: 0]      d2h_req_idx;
logic [D2H_RSP_CNT_WIDTH - 1: 0]      d2h_rsp_idx;
CXL_CACHE_RR_HDR_STATE  s_rr_cache_req  [0 : FLIT_SLOT_NUM-1];
CXL_CACHE_RR_HDR_STATE  r_rr_cache_req  [0 : FLIT_SLOT_NUM-1];
CXL_CACHE_RR_DATA_STATE r_rr_cache_data, s_rr_cache_data ;
logic s_cache_data_vld, s_cache_req_rsp_vld;


logic [SLOT_CNT_WIDTH_PAGE - 1   : 0] cache_hdr_slot_idx, cache_data_slot_idx;
logic cache_data_vld;
logic s_cache_req_vld, s_cache_rsp_vld;
logic  d2h_req_vld_0, d2h_rsp_vld_0, d2h_hdr_vld_0; // D2H has at least valid message 

// -------------------------------------------------------------------------------------
// CXL.Cache Poison Mode
// -------------------------------------------------------------------------------------

assign cfg_cache_poison_busy = pack_enable && cfg_cache_poison_r;

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
    else if (pack_enable) begin
        cfg_cache_poison_start_r <= #TP cfg_cache_poison_start;
        cfg_cache_poison_r       <= #TP cfg_cache_poison_nxt;
    end
end


//----------------------------------------------------------------------
//              Mask Generation logic
//----------------------------------------------------------------------
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        r_cxl_ch_d2h_req_msk <= #TP '1;
        r_cxl_ch_d2h_rsp_msk <= #TP '1;
        r_cxl_ch_d2h_hdr_msk <= #TP '1;
    end
    else if (!cxl_prot_msg_halt_s) begin
      r_cxl_ch_d2h_req_msk <= #TP s_cxl_ch_d2h_req_msk;
      r_cxl_ch_d2h_rsp_msk <= #TP s_cxl_ch_d2h_rsp_msk;
      r_cxl_ch_d2h_hdr_msk <= #TP s_cxl_ch_d2h_hdr_msk;
    end
end

// -------------------------------------------------------------------------------------
// Extarct channel message valid bits
// -------------------------------------------------------------------------------------

always_comb begin
  for (int i = 0; i < D2H_256B_REQ_NUM; i++)  begin
      cxl_d2h_req_msg_s[i] = (b_llctrl.s_cxl_ll_cache_req_gnt[i])? b_txtl_llctrl.s_cxl_d2h_req[i][D2H_256B_REQ_SIZE-1: 0] : '0;
      cxl_ch_d2h_req_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_cache_req_gnt[i]) & b_txtl_llctrl.s_cxl_d2h_req[i][D2H_REQ_VLD];
  end
  for (int i = 0; i < D2H_256B_RESP_NUM; i++) begin
      cxl_d2h_rsp_msg_s[i] = (b_llctrl.s_cxl_ll_cache_rsp_gnt[i] ) ? b_txtl_llctrl.s_cxl_d2h_rsp[i] : '0;
      cxl_ch_d2h_rsp_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_cache_rsp_gnt[i]) & b_txtl_llctrl.s_cxl_d2h_rsp[i][D2H_RESP_VLD];
  end
  for (int i = 0; i < D2H_256B_DATA_NUM; i++) begin
    cxl_d2h_hdr_msg_s[i] = (b_llctrl.s_cxl_ll_cache_data_gnt[i] & b_txtl_llctrl.s_cxl_d2h_data_vld[0] & cxl_data_en) ? b_txtl_llctrl.s_cxl_d2h_hdr[i] : '0;
    cxl_ch_d2h_hdr_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_cache_data_gnt[i] & b_txtl_llctrl.s_cxl_d2h_data_vld[0]  & cxl_data_en) & b_txtl_llctrl.s_cxl_d2h_hdr[i][D2H_HDR_VLD];
  end
  // Overwrite Poison Bit
    cxl_d2h_hdr_msg_s[0][D2H_256B_POISON_BIT] = cxl_d2h_hdr_msg_s[0][D2H_HDR_VLD] ? (b_txtl_llctrl.s_cxl_d2h_hdr[0][D2H_256B_POISON_BIT] | cfg_cache_poison_r) : 1'b0;
  for (int i = 0; i < D2H_256B_DDATA_NUM; i++) cxl_d2h_data_msg_s[i] = b_txtl_llctrl.s_cxl_d2h_data[i];
  for (int i = 0; i < D2H_256B_DDATA_NUM; i++) cxl_d2h_be_s[i] = b_txtl_llctrl.s_cxl_d2h_be[i];
end


always_comb begin
  for (int i = 0; i < D2H_256B_REQ_NUM; i++)  cxl_ch_d2h_req_vld[i] = cxl_d2h_req_msg_s[i][D2H_REQ_VLD];
  for (int i = 0; i < D2H_256B_RESP_NUM; i++) cxl_ch_d2h_rsp_vld[i] = cxl_d2h_rsp_msg_s[i][D2H_RESP_VLD];
  for (int i = 0; i < D2H_256B_DATA_NUM; i++) cxl_ch_d2h_hdr_vld[i] = cxl_d2h_hdr_msg_s[i][D2H_HDR_VLD];
end

// -------------------------------------------------------------------------------------
// Generate valid signals for credit tracking
// -------------------------------------------------------------------------------------
assign cache_req_vld   = {{(TX_CRDIF_WIDTH-D2H_256B_REQ_NUM){1'b0}} , cxl_ch_d2h_req_vld & ~b_txtl_llctrl.s_cxl_d2h_req_halt};
assign cache_rsp_vld   = {{(TX_CRDIF_WIDTH-D2H_256B_RESP_NUM){1'b0}}, cxl_ch_d2h_rsp_vld & ~b_txtl_llctrl.s_cxl_d2h_rsp_halt};
assign cache_hdr_vld   = {{(TX_CRDIF_WIDTH-D2H_256B_DATA_NUM){1'b0}}, cxl_ch_d2h_hdr_vld & ~b_txtl_llctrl.s_cxl_d2h_hdr_halt};
// This is to see which flit type will use H slot
assign d2h_req_vld_0 = cxl_ch_d2h_req_vld[0] & r_cxl_ch_d2h_req_msk[0];
assign d2h_rsp_vld_0 = cxl_ch_d2h_rsp_vld[0] & r_cxl_ch_d2h_rsp_msk[0];
assign d2h_hdr_vld_0 = cxl_ch_d2h_hdr_vld[0] & r_cxl_ch_d2h_hdr_msk[0];

// -------------------------------------------------------------------------------------
// Cache arbitration logic
// -------------------------------------------------------------------------------------
// HDR
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
// Data
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
logic [D2H_256B_DDATA_NUM-1:0] d2h_beb; // D2H Byte Enable Bit

assign cache_round = (mem_cache_arb==CXL_256B_CACHE)  | (!s2m_drs_vld_0 & !s2m_ndr_vld_0 & !s2m_bi_snp_vld_0 );
generate 
  always_comb begin   
    cxl_ch_d2h_hdr_vld_nxt =  ((!b_llctrl.s_cxl_ll_cache_mdh_en)? cxl_ch_d2h_hdr_vld & 'h1 :  cxl_ch_d2h_hdr_vld) & r_cxl_ch_d2h_hdr_msk;
    d2h_beb[0]             = 
                                                                                  cxl_d2h_hdr_msg_s[0][D2H_HDR_BEB_IDX_HBR];
    // In case No headers avaialbe then the 1st slot can be H/Hs slot else it must be G Slot
    force_gslot_cache_data_n = ((!d2h_rsp_vld_0 & !d2h_req_vld_0) | (r_rr_cache_data == CXL_CACHE_RR_DATA)) & cache_round;
    if (FLIT_SLOT_NUM > 1) cache_data_slot_type = force_gslot_cache_data_n ? cxl_slot_type : CXL_256B_SLOT_G;
    else cache_data_slot_type                = cxl_slot_type;
    // Initialize 
    for (int i =0;i<FLIT_SLOT_NUM;i++) cache_data_slots[i/4][i%4] = 'd0;  
    // If the header is valid, then pack the Header and its associated data
    if (cxl_ch_d2h_hdr_vld_nxt[0]) begin
      cache_data_slots[0][0] = pack_slot_13 (cxl_d2h_hdr_msg_s, cxl_ch_d2h_hdr_vld_nxt, 'd0, cache_data_slot_type);
      cache_data_slots[0][1] = pack_data(cxl_d2h_data_msg_s[shift_d2h_data], cxl_d2h_be_s[shift_d2h_data],'d0, d2h_beb[0], CXL_256B_CACHE_D);
      cache_data_slots[0][2] = pack_data(cxl_d2h_data_msg_s[shift_d2h_data], cxl_d2h_be_s[shift_d2h_data],'d1, d2h_beb[0], CXL_256B_CACHE_D);
      cache_data_slots[0][3] = pack_data(cxl_d2h_data_msg_s[shift_d2h_data], cxl_d2h_be_s[shift_d2h_data],'d2, d2h_beb[0], CXL_256B_CACHE_D);
    end
  end
endgenerate
// -------------------------------------------------------------------------------------
// Cache Headers packing
// -------------------------------------------------------------------------------------

  always_comb begin   
    cxl_ch_d2h_rsp_vld_nxt = cxl_ch_d2h_rsp_vld & r_cxl_ch_d2h_rsp_msk;
    cxl_ch_d2h_req_vld_nxt = cxl_ch_d2h_req_vld & r_cxl_ch_d2h_req_msk;
    d2h_req_idx            = 'd0;
    d2h_rsp_idx            = 'd0;
    for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM; slot_idx++) begin
      cache_hdr_slots[slot_idx/4][slot_idx%4] = 'b0;
      // Select Slot Type
      force_gslot_cache_hdr_n = (slot_idx==0) & (!d2h_hdr_vld_0 | (r_rr_cache_data == CXL_CACHE_RR_HDR)) & cache_round;
      if (FLIT_SLOT_NUM > 1) cache_slot_type = (force_gslot_cache_hdr_n)? cxl_slot_type : CXL_256B_SLOT_G;
      else cache_slot_type = cxl_slot_type;
      
// spyglass disable_block STARC05-2.8.1.3
// SMD: case constructs should not have overlapping clause conditions. (Verilog)
// SJ: This is to enable synthesis optimization
      // 1- RR between D2H RSP and D2H REQ
      casez ({r_rr_cache_req[slot_idx] ,cxl_ch_d2h_rsp_vld_nxt[0], cxl_ch_d2h_req_vld_nxt[0]})
        3'b?_0_1,
        {CXL_CACHE_RR_REQ, 2'b?_1}: begin 
          cache_hdr_slots[slot_idx/4][slot_idx%4] = pack_slot_02 (cxl_d2h_req_msg_s, cxl_ch_d2h_req_vld_nxt, d2h_req_idx, cxl_d2h_rsp_msg_s, cxl_ch_d2h_rsp_vld_nxt, d2h_rsp_idx,cache_slot_type);
          cxl_ch_d2h_req_vld_nxt                  = cxl_ch_d2h_req_vld_nxt >> d2h_req_max(cache_slot_type); 
          d2h_req_idx                             = d2h_req_idx + d2h_req_max(cache_slot_type); 
          cxl_ch_d2h_rsp_vld_nxt                  = cxl_ch_d2h_rsp_vld_nxt >> d2h_rsp_max(cache_slot_type,'d2); 
          d2h_rsp_idx                             = d2h_rsp_idx + d2h_rsp_max(cache_slot_type,'d2); 
        end
        3'b?_1_0,
        {CXL_CACHE_RR_RSP, 2'b1_?}: begin 
          cache_hdr_slots[slot_idx/4][slot_idx%4]   = pack_slot_03 (cxl_d2h_rsp_msg_s, cxl_ch_d2h_rsp_vld_nxt, d2h_rsp_idx,cache_slot_type);
          cxl_ch_d2h_rsp_vld_nxt                    = cxl_ch_d2h_rsp_vld_nxt >> d2h_rsp_max(cache_slot_type,'d3); 
          d2h_rsp_idx                               = d2h_rsp_idx + d2h_rsp_max(cache_slot_type,'d3); 
        end
      endcase
// spyglass enable_block STARC05-2.8.1.3
    end
  end
  
// -------------------------------------------------------------------------------------
// Cache Data + Headers packing
// -------------------------------------------------------------------------------------
  always_comb begin   
    cache_data_slot_idx  = 'd0;
    for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM_PAGE; slot_idx++) begin
      if (!cache_hdr_slots[0][slot_idx].Valid ||
      (((r_rr_cache_data == CXL_CACHE_RR_DATA) && d2h_hdr_vld_0))) begin
        cache_slots[0][slot_idx] = cache_data_slots[0][cache_data_slot_idx];
        cache_data_slot_idx   = cache_data_slot_idx + 'd1;
      end
      else begin
        cache_slots[0][slot_idx] = cache_hdr_slots[0][slot_idx];
      end
    end
  end
// -------------------------------------------------------------------------------------
// Pack Mem Slots in empty Cache Slots
// -------------------------------------------------------------------------------------
logic [SLOT_CNT_WIDTH_PAGE - 1:0] cache_temp_slot_idx;
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
  logic [$clog2(D2H_256B_REQ_NUM)  :0]   cxl_ch_d2h_req_cnt;       // Number of valid D2H Request Messages in the output flit
  logic [$clog2(D2H_256B_RESP_NUM) :0]   cxl_ch_d2h_rsp_cnt;       // Number of valid D2H Response Messages in the output flit
  logic [$clog2(D2H_256B_DATA_NUM) :0]   cxl_ch_d2h_hdr_cnt;       // Number of valid D2H Data Messages in the output flit
  logic [$clog2(D2H_256B_DDATA_NUM):0]   cxl_ch_d2h_data_cnt;      // Number of valid D2H Data Blocks in the output flit
  
  logic [D2H_256B_REQ_NUM-1  :0] s_cxl_ch_d2h_req_halt ; 
  logic [D2H_256B_RESP_NUM-1 :0] s_cxl_ch_d2h_rsp_halt ; 
  logic [D2H_256B_DATA_NUM-1 :0] s_cxl_ch_d2h_hdr_halt ; 
  logic [D2H_256B_DDATA_NUM-1:0] s_cxl_ch_d2h_data_halt;
  logic [8 - 1               :0] s_cache_message_vld;     
  CXL_SLOT_TYPES                 cache_halt_slot_type;

  always_comb begin 
    cxl_ch_d2h_req_cnt    = 'd0;
    cxl_ch_d2h_rsp_cnt    = 'd0;
    cxl_ch_d2h_hdr_cnt    = 'd0;
    cxl_ch_d2h_data_cnt   = 'd0;
    
    s_cxl_ch_d2h_req_halt = '1;
    s_cxl_ch_d2h_rsp_halt = '1;    
    s_cxl_ch_d2h_hdr_halt = '1;    
    s_cxl_ch_d2h_data_halt= '1;    
    
    for (int slot_idx=0; slot_idx<FLIT_SLOT_NUM_PAGE ;slot_idx++) begin
      cache_halt_slot_type = (slot_idx==0)? cxl_slot_type : CXL_256B_SLOT_G;

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: No overflow expected
      // D2H REQ
      if (cxl_packer_flit[slot_idx].slot_idx == 'd2)begin
        s_cxl_ch_d2h_req_halt = s_cxl_ch_d2h_req_halt << d2h_req_max(cache_halt_slot_type);
      end
      // D2H RSP
      if (cxl_packer_flit[slot_idx].slot_idx == 'd2)begin
        s_cxl_ch_d2h_rsp_halt = s_cxl_ch_d2h_rsp_halt << d2h_rsp_max(cache_halt_slot_type, 'd2);
      end
      else if (cxl_packer_flit[slot_idx].slot_idx == 'd3)begin
        s_cxl_ch_d2h_rsp_halt = s_cxl_ch_d2h_rsp_halt << d2h_rsp_max(cache_halt_slot_type, 'd3);
      end
      // D2H HDR
      if ((cxl_packer_flit[slot_idx].slot_idx == 'd13))begin
        s_cxl_ch_d2h_hdr_halt = s_cxl_ch_d2h_hdr_halt << d2h_hdr_max(cache_halt_slot_type, b_llctrl.s_cxl_ll_cache_mdh_en);
      end
// spyglass enable_block W164a

      if (cxl_packer_flit[slot_idx].data_info.data_strt & (cxl_packer_flit[slot_idx].data_info.data_type==CXL_256B_CACHE_D)) begin
        cxl_ch_d2h_data_cnt++;
        s_cxl_ch_d2h_data_halt = s_cxl_ch_d2h_data_halt << 1;
      end
    end
    s_cache_message_vld                        = 'd0;
    s_cache_message_vld[D2H_256B_REQ_NUM-1:0]  = cxl_ch_d2h_req_vld & ~s_cxl_ch_d2h_req_halt & ~cxl_ch_d2h_req_gnt_halt & r_cxl_ch_d2h_req_msk;
    cxl_ch_d2h_req_cnt                         = valid_cnt(s_cache_message_vld);
    
    s_cache_message_vld                        = 'd0;
    s_cache_message_vld[D2H_256B_RESP_NUM-1:0] = cxl_ch_d2h_rsp_vld & ~s_cxl_ch_d2h_rsp_halt & ~cxl_ch_d2h_rsp_gnt_halt & r_cxl_ch_d2h_rsp_msk;
    cxl_ch_d2h_rsp_cnt                         = valid_cnt(s_cache_message_vld);
    
    s_cache_message_vld                        = 'd0;
    s_cache_message_vld[D2H_256B_DATA_NUM-1:0] = cxl_ch_d2h_hdr_vld & ~s_cxl_ch_d2h_hdr_halt & ~cxl_ch_d2h_hdr_gnt_halt & r_cxl_ch_d2h_hdr_msk;
    cxl_ch_d2h_hdr_cnt                         = valid_cnt(s_cache_message_vld);
    

    
    
    
    s_cxl_ch_d2h_req_msk                       = {D2H_256B_REQ_NUM{1'b1}}  >> (cxl_ch_d2h_req_cnt);
    s_cxl_ch_d2h_rsp_msk                       = {D2H_256B_RESP_NUM{1'b1}} >> (cxl_ch_d2h_rsp_cnt);
    s_cxl_ch_d2h_hdr_msk                       = {D2H_256B_DATA_NUM{1'b1}} >> (cxl_ch_d2h_hdr_cnt);

    b_txtl_llctrl.s_cxl_d2h_req_halt  = cxl_prot_msg_halt_s ? {D2H_256B_REQ_NUM{1'b1}}     : 
                                      (  ~r_cxl_ch_d2h_req_msk | cxl_ch_d2h_req_gnt_halt | (cxl_ch_d2h_req_vld & s_cxl_ch_d2h_req_halt));
    b_txtl_llctrl.s_cxl_d2h_rsp_halt  = cxl_prot_msg_halt_s ? {D2H_256B_RESP_NUM{1'b1}}    : 
                                      (  ~r_cxl_ch_d2h_rsp_msk | cxl_ch_d2h_rsp_gnt_halt | (cxl_ch_d2h_rsp_vld & s_cxl_ch_d2h_rsp_halt));
    b_txtl_llctrl.s_cxl_d2h_hdr_halt  = cxl_prot_msg_halt_s ? {D2H_256B_DATA_NUM{1'b1}}    : 
                                      (  ~r_cxl_ch_d2h_hdr_msk | cxl_ch_d2h_hdr_gnt_halt | (cxl_ch_d2h_hdr_vld & s_cxl_ch_d2h_hdr_halt));
    b_txtl_llctrl.s_cxl_d2h_data_halt = cxl_prot_data_halt_s? {D2H_256B_DDATA_NUM{1'b1}}   : s_cxl_ch_d2h_data_halt;
  end

  ////
  //------------------------------------------------------------
  //            D2H Slot Packing 
  //-----------------------------------------------------------
  
  function automatic logic [$clog2(D2H_256B_REQ_NUM)  :0] d2h_req_max (
    CXL_SLOT_TYPES                  slot_type
  );
  logic [$clog2(D2H_256B_REQ_NUM)  :0] s_max_cnt;
  begin
    // +------------------+
    // |      D2H REQ     |
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
  function automatic logic [$clog2(D2H_256B_RESP_NUM) :0] d2h_rsp_max (
    CXL_SLOT_TYPES                  slot_type,
    logic  [3:0]                    cxl_slot_idx
  );
  logic [$clog2(D2H_256B_RESP_NUM)  :0] s_max_cnt;
  begin
    // Slot # 2
    // +------------------+
    // |      D2H RSP     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 2 | 1 |  0 |
    // +-----+---+---+----+
    // | PBR | 0 | 0 |  x |
    // +-----+---+---+----+
    
    // Slot # 3
    // +------------------+
    // |      D2H RSP     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 4 | 4 |  3 |
    // +-----+---+---+----+
    // | PBR | 3 | 3 |  x |
    // +-----+---+---+----+
    
    
    s_max_cnt = (cxl_slot_idx=='d2)? (((slot_type==CXL_256B_SLOT_G))? 'd2 : 
                                         ((slot_type==CXL_256B_SLOT_H)) ? 'd1 : 'd0): 
                                     (((slot_type==CXL_256B_SLOT_G | slot_type==CXL_256B_SLOT_H ))? 'd4 : 'd3);
    return s_max_cnt;
  end
  endfunction
  function automatic logic [$clog2(D2H_256B_DATA_NUM) :0] d2h_hdr_max (
    CXL_SLOT_TYPES                  slot_type
    ,logic                          mdh_en
  );
  logic [$clog2(D2H_256B_DATA_NUM)  :0] s_max_cnt;
  begin
    // +------------------+
    // |      D2H HDR     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 4 | 4 |  3 |
    // +-----+---+---+----+
    // | PBR | 3 | 3 |  x |
    // +-----+---+---+----+
    s_max_cnt =   (!mdh_en)? 'd1 :
                  ((slot_type==CXL_256B_SLOT_G | slot_type==CXL_256B_SLOT_H))? 'd4 : 'd3;
    return s_max_cnt;
  end
  endfunction
  ////
  function automatic SLOT_DESCR_256B_t pack_slot_02 ( 
    logic [D2H_256B_REQ_SIZE-1      : 0] cxl_d2h_req_msg_s [0:D2H_256B_REQ_NUM-1] , 
    logic [D2H_256B_REQ_NUM-1       : 0] cxl_ch_d2h_req_vld                  , 
    logic [D2H_REQ_CNT_WIDTH -1     : 0] d2h_req_idx                         , 
    logic [D2H_256B_RESP_SIZE-1     : 0] cxl_d2h_rsp_msg_s [0:D2H_256B_RESP_NUM-1],
    logic [D2H_256B_RESP_NUM-1      : 0] cxl_ch_d2h_rsp_vld                  , 
    logic [D2H_RSP_CNT_WIDTH-1      : 0] d2h_rsp_idx                         , 
    CXL_SLOT_TYPES                  slot_type
    );
    SLOT_DESCR_256B_t slot_curr;
    logic is_g_slot;
    logic is_hs_slot;
    begin
      // G Slot   : 1 D2H REQ + 2 D2H RSP
      // H Slot   : 1 D2H REQ + 1 D2H RSP
      // Hs Slot  : 1 D2H REQ
      slot_curr           = 'b0;
      slot_curr.Valid     = 1'b1;
      slot_curr.slot_idx  = 'd2;
      slot_curr.slot_type = slot_type;
      is_g_slot           = (slot_type == CXL_256B_SLOT_G);
      is_hs_slot          = 1'b0;
// spyglass disable_block ImproperRangeIndex-ML
// SMD: INDEX larger than the bit width required for variable.
// SJ: for out of IDX the valid should be zero
      slot_curr.Slot[0 +: (D2H_HBR_REQ_SIZE + (2*D2H_HBR_RESP_SIZE))]= 
      {
      cxl_d2h_rsp_msg_s[d2h_rsp_idx + 1][D2H_HBR_RESP_SIZE -1 : 0] & {D2H_HBR_RESP_SIZE{is_g_slot & cxl_ch_d2h_rsp_vld[1]}},
      cxl_d2h_rsp_msg_s[d2h_rsp_idx][D2H_HBR_RESP_SIZE -1 : 0] & {D2H_HBR_RESP_SIZE{cxl_ch_d2h_rsp_vld[0] & !is_hs_slot}},
      cxl_d2h_req_msg_s[d2h_req_idx][D2H_HBR_REQ_SIZE -1 : 0]
      };
// spyglass enable_block ImproperRangeIndex-ML
      return slot_curr;
    end
  endfunction
  
  function automatic SLOT_DESCR_256B_t pack_slot_03( 
    logic [D2H_256B_RESP_SIZE-1     : 0] cxl_d2h_rsp_msg_s [0:D2H_256B_RESP_NUM-1],
    logic [D2H_256B_RESP_NUM-1      : 0] cxl_ch_d2h_rsp_vld                  , 
    logic [D2H_RSP_CNT_WIDTH-1      : 0] d2h_rsp_idx                         , 
    CXL_SLOT_TYPES                       slot_type
    );
    SLOT_DESCR_256B_t slot_curr;
    logic is_g_slot;
    logic is_hs_slot;
    begin
      // G Slot   : 4 D2H RSP
      // H Slot   : 4 D2H RSP
      // Hs Slot  : 3 D2H RSP
      slot_curr           = 'b0;
      slot_curr.Valid     = 1'b1;
      slot_curr.slot_idx  = 'd3;
      slot_curr.slot_type = slot_type;
      is_g_slot           = (slot_type == CXL_256B_SLOT_G);
      is_hs_slot          = 1'b0;

// spyglass disable_block ImproperRangeIndex-ML
// SMD: INDEX larger than the bit width required for variable.
// SJ: for out of IDX the valid should be zero
      slot_curr.Slot[0 +: (4*D2H_HBR_RESP_SIZE)]= {
      cxl_d2h_rsp_msg_s[d2h_rsp_idx+'d3][D2H_HBR_RESP_SIZE -1 : 0] & {D2H_HBR_RESP_SIZE{cxl_ch_d2h_rsp_vld[3] & !is_hs_slot}},
      cxl_d2h_rsp_msg_s[d2h_rsp_idx+'d2][D2H_HBR_RESP_SIZE -1 : 0] & {D2H_HBR_RESP_SIZE{cxl_ch_d2h_rsp_vld[2]}},
      cxl_d2h_rsp_msg_s[d2h_rsp_idx+'d1][D2H_HBR_RESP_SIZE -1 : 0] & {D2H_HBR_RESP_SIZE{cxl_ch_d2h_rsp_vld[1]}},
      cxl_d2h_rsp_msg_s[d2h_rsp_idx][D2H_HBR_RESP_SIZE -1 : 0]
      };
// spyglass enable_block ImproperRangeIndex-ML

      return slot_curr;
    end
  endfunction
  
  function automatic SLOT_DESCR_256B_t pack_slot_13 ( 
    logic [D2H_256B_DHDR_SIZE-1      : 0] cxl_d2h_hdr_msg_s [0:D2H_256B_DATA_NUM-1],
    logic [D2H_256B_DATA_NUM-1       : 0] cxl_ch_d2h_hdr_vld                       , 
    logic                                 d2h_hdr_idx                              , 
    CXL_SLOT_TYPES                        slot_type
    );
    SLOT_DESCR_256B_t slot_curr;
    logic is_g_slot;
    logic is_hs_slot;
    begin
      // G Slot   : 4 D2H DH
      // H Slot   : 4 D2H DH
      // Hs Slot  : 3 D2H DH 
      slot_curr           = 'b0;
      slot_curr.Valid     = 1'b1;
      slot_curr.slot_idx  = 'd13;
      slot_curr.slot_type = slot_type;
      is_g_slot           = (slot_type == CXL_256B_SLOT_G);
      is_hs_slot          = 1'b0;
// spyglass disable_block W468
// SMD: Index variable is too short
// SJ: d2h_hdr_idx is only used when MDH is not enabled.

      slot_curr.Slot[0 +: (4*D2H_HBR_DHDR_SIZE)]= 
      {
      cxl_d2h_hdr_msg_s[3][D2H_HBR_DHDR_SIZE - 1: 0] & {D2H_HBR_DHDR_SIZE{cxl_ch_d2h_hdr_vld[3] & !is_hs_slot}}, 
      cxl_d2h_hdr_msg_s[2][D2H_HBR_DHDR_SIZE - 1: 0] & {D2H_HBR_DHDR_SIZE{cxl_ch_d2h_hdr_vld[2]}}, 
      cxl_d2h_hdr_msg_s[1][D2H_HBR_DHDR_SIZE - 1: 0] & {D2H_HBR_DHDR_SIZE{cxl_ch_d2h_hdr_vld[1]}}, 
      cxl_d2h_hdr_msg_s[d2h_hdr_idx][D2H_HBR_DHDR_SIZE - 1: 0]
      };
// spyglass enable_block W468

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: Data is 5 bits (Max 31) and max value after addation is 20
      unique casez ({is_hs_slot
                            , cxl_ch_d2h_hdr_vld[3:0]})
        5'b?_0001: begin 
          slot_curr.data_vld = 'b1;
          slot_curr.Data     = 'd4;
          for (int i=0;i<1;i++) begin
            slot_curr.be_vld[i]   = (
                                                                                          cxl_d2h_hdr_msg_s[d2h_hdr_idx+i][D2H_HDR_BEB_IDX_HBR]);
            slot_curr.Data        = slot_curr.Data + (
                                                                                                           cxl_d2h_hdr_msg_s[d2h_hdr_idx+i][D2H_HDR_BEB_IDX_HBR]);
          end
        end
        5'b?_0011: begin
          slot_curr.Data     = 'd8;
          slot_curr.data_vld = 'b11;
          for (int i=0;i<2;i++) begin
            slot_curr.be_vld[i]   = (
                                                                                          cxl_d2h_hdr_msg_s[d2h_hdr_idx+i][D2H_HDR_BEB_IDX_HBR]);
            slot_curr.Data        = slot_curr.Data + (
                                                                                                           cxl_d2h_hdr_msg_s[d2h_hdr_idx+i][D2H_HDR_BEB_IDX_HBR]);
          end        
        end
        5'b?_0111,
        5'b1_1111: begin 
          slot_curr.Data     = 'd12;
          slot_curr.data_vld = 'b111;
          for (int i=0;i<3;i++) begin
            slot_curr.be_vld[i]   = (
                                                                                          cxl_d2h_hdr_msg_s[d2h_hdr_idx+i][D2H_HDR_BEB_IDX_HBR]);
            slot_curr.Data        = slot_curr.Data + (
                                                                                                           cxl_d2h_hdr_msg_s[d2h_hdr_idx+i][D2H_HDR_BEB_IDX_HBR]);
          end  
        end
        5'b0_1111: begin 
          slot_curr.Data     = 'd16;
          slot_curr.data_vld = 'b1111;
          for (int i=0;i<4;i++) begin
            slot_curr.be_vld[i]   = (
                                                                                          cxl_d2h_hdr_msg_s[i][D2H_HDR_BEB_IDX_HBR]);
            slot_curr.Data        = slot_curr.Data + (
                                                                                                           cxl_d2h_hdr_msg_s[i][D2H_HDR_BEB_IDX_HBR]);
          end  
        end
        default: begin 
          slot_curr.Data     = 'd0;
          slot_curr.data_vld = 'b0;
          slot_curr.be_vld   = 'b0;
        end
      endcase
// spyglass enable_block W164a

      return slot_curr;
    end
  endfunction
  assign cxl_cache_pending = pack_enable & (b_txtl_llctrl.s_cxl_d2h_req[0][D2H_REQ_VLD] || b_txtl_llctrl.s_cxl_d2h_rsp[0][D2H_RESP_VLD] || b_txtl_llctrl.s_cxl_d2h_hdr[0][D2H_HDR_VLD]);

//------------------------------------------------------------------
//                       MEM packer
//------------------------------------------------------------------
logic [S2M_256B_BI_SNP_NUM-1:0]  cxl_ch_s2m_bi_snp_vld_nxt; // S2M BI Snoop Channel Valid Bits


logic [S2M_256B_NDR_NUM-1:0]     s_cxl_ch_s2m_ndr_msk, r_cxl_ch_s2m_ndr_msk;
logic [S2M_256B_DATA_NUM-1:0]    s_cxl_ch_s2m_drs_msk, r_cxl_ch_s2m_drs_msk;
logic [S2M_256B_BI_SNP_NUM-1:0]  s_cxl_ch_s2m_bi_snp_msk, r_cxl_ch_s2m_bi_snp_msk;



logic [S2M_256B_NDR_SIZE-1:0]    cxl_s2m_ndr_msg_s [0:S2M_256B_NDR_NUM-1];  // S2M Request with no Data Channel - 87 bits
logic [S2M_256B_DHDR_SIZE-1:0]   cxl_s2m_hdr_msg_s [0:S2M_256B_DATA_NUM-1]; // S2M Request with Data Channel Header - 87 bits
logic [S2M_256B_DDATA_SIZE-1:0]  cxl_s2m_data_msg_s[0:S2M_256B_DDATA_NUM-1]; // S2M Data - 4x16B
logic [S2M_BI_SNP_SIZE-1:0] cxl_s2m_bi_snp_msg_s [0:S2M_256B_BI_SNP_NUM-1]; // S2M BI Snoop Data Channel - 38 bits


logic [S2M_256B_NDR_NUM-1:0]     cxl_ch_s2m_ndr_gnt_halt;     // S2M Request Only Channel Valid Bits
logic [S2M_256B_DATA_NUM-1:0]    cxl_ch_s2m_drc_gnt_halt;     // S2M DRS Channel Valid Bits
logic [S2M_256B_BI_SNP_NUM-1:0]  cxl_ch_s2m_bi_snp_gnt_halt;  // S2M BI Snoop Channel Valid Bits
logic cfg_mem_poison_start_r;
logic cfg_mem_poison_r, cfg_mem_poison_nxt;


SLOT_DESCR_256B_t mem_data_slots    [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];
SLOT_DESCR_256B_t mem_n_cache_slots [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];
SLOT_DESCR_256B_t mem_hdr_slots     [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1];

CXL_SLOT_TYPES                      mem_data_slot_type;
CXL_SLOT_TYPES                      mem_slot_type;
logic [S2M_REQ_CNT_WIDTH - 1   : 0] s2m_ndr_idx;
logic [S2M_BI_SNP_CNT_WIDTH - 1: 0] s2m_bi_snp_idx;
logic [S2M_HDR_CNT_WIDTH - 1   : 0] s2m_drs_idx;
logic [SLOT_CNT_WIDTH - 1      : 0] mem_data_idx;
logic [SLOT_CNT_WIDTH_PAGE - 1 : 0] cache_slot_idx;

logic mem_data_vld;
CXL_MEM_RR_HDR_STATE               s_rr_mem_req  [0 : FLIT_SLOT_NUM-1];
CXL_MEM_RR_HDR_STATE               r_rr_mem_req  [0 : FLIT_SLOT_NUM-1];
CXL_MEM_RR_DATA_STATE              r_rr_mem_data, s_rr_mem_data;
logic s_mem_req_vld, s_mem_bi_vld;
logic m2s_byte_en;

logic [$clog2(S2M_256B_NDR_NUM):0]    cxl_ch_s2m_ndr_cnt;       // Number of valid S2M Request Only Messages in the output flit
logic [$clog2(S2M_256B_DATA_NUM):0]   cxl_ch_s2m_drs_cnt;       // Number of valid S2M Data Messages in the output flit
logic [$clog2(S2M_256B_BI_SNP_NUM):0] cxl_ch_s2m_bi_snp_cnt;    // Number of valid S2M BI Snoop Messages in the output flit
logic [$clog2(S2M_256B_DDATA_NUM):0]  cxl_ch_s2m_data_cnt;      // Number of valid S2M Data Blocks in the output flit


logic [S2M_256B_NDR_NUM    - 1:0]  s_cxl_ch_s2m_ndr_halt;   
logic [S2M_256B_DATA_NUM   - 1:0]  s_cxl_ch_s2m_drs_halt;   
logic [S2M_256B_BI_SNP_NUM - 1:0]  s_cxl_ch_s2m_bi_snp_halt;
logic [S2M_256B_DDATA_NUM  - 1:0]  s_cxl_ch_s2m_data_halt;  




logic s_mem_data_vld, s_mem_req_rsp_vld;
logic [SLOT_CNT_WIDTH_PAGE - 1   : 0] mem_hdr_slot_idx, mem_data_slot_idx;

// -------------------------------------------------------------------------------------
// CXL.Mem Poison Mode
// -------------------------------------------------------------------------------------
assign cfg_mem_poison_busy = pack_enable && cfg_mem_poison_r;

always_comb begin
    if (cfg_mem_poison_start && !cfg_mem_poison_start_r && !cfg_mem_poison_r) begin
        cfg_mem_poison_nxt = 1'b1;
    end
    else if (cfg_mem_poison_r && cxl_s2m_hdr_msg_s[0][M2S_HDR_VLD] && !b_txtl_llctrl.s_cxl_s2m_hdr_halt[0]) begin
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
      r_cxl_ch_s2m_ndr_msk    <= #TP '1;
      r_cxl_ch_s2m_drs_msk    <= #TP '1;
      r_cxl_ch_s2m_bi_snp_msk <= #TP '1;
    end
    else if (!cxl_prot_msg_halt_s) begin
      r_cxl_ch_s2m_ndr_msk    <= #TP  s_cxl_ch_s2m_ndr_msk   ;
      r_cxl_ch_s2m_drs_msk    <= #TP  s_cxl_ch_s2m_drs_msk   ;
      r_cxl_ch_s2m_bi_snp_msk <= #TP  s_cxl_ch_s2m_bi_snp_msk;
    end
end
// -------------------------------------------------------------------------------------
// Extarct channel message valid bits
// -------------------------------------------------------------------------------------

always_comb begin
    for (int i = 0; i < S2M_256B_NDR_NUM; i++) begin
        cxl_s2m_ndr_msg_s[i] = (b_llctrl.s_cxl_ll_mem_ndr_gnt[i]) ? b_txtl_llctrl.s_cxl_s2m_ndr[i] : '0;
        cxl_ch_s2m_ndr_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_mem_ndr_gnt[i]) & b_txtl_llctrl.s_cxl_s2m_ndr[i][S2M_NDR_VLD];
    end
    for (int i = 0; i < S2M_256B_DATA_NUM; i++) begin
      cxl_s2m_hdr_msg_s[i] = (b_llctrl.s_cxl_ll_mem_dr_gnt[i] & b_txtl_llctrl.s_cxl_s2m_data_vld[0] & cxl_data_en) ? b_txtl_llctrl.s_cxl_s2m_hdr[i] : '0;
      cxl_ch_s2m_drc_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_mem_dr_gnt[i] & b_txtl_llctrl.s_cxl_s2m_data_vld[0] & cxl_data_en) & b_txtl_llctrl.s_cxl_s2m_hdr[i][S2M_HDR_VLD];
    end
    // Overwrite Poison Bit
    cxl_s2m_hdr_msg_s[0][S2M_256B_POISON_BIT] = cxl_s2m_hdr_msg_s[0][S2M_HDR_VLD] ? (b_txtl_llctrl.s_cxl_s2m_hdr[0][S2M_256B_POISON_BIT] | cfg_mem_poison_r) : 1'b0;
    for (int i = 0; i < S2M_256B_DDATA_NUM; i++) cxl_s2m_data_msg_s[i] = b_txtl_llctrl.s_cxl_s2m_data[i];

    for (int i = 0; i < S2M_256B_BI_SNP_NUM; i++) begin
        cxl_s2m_bi_snp_msg_s[i] = (b_llctrl.s_cxl_ll_mem_bi_gnt[i]) ? b_txtl_llctrl.s_cxl_s2m_bi_snp[i] : '0;
        cxl_ch_s2m_bi_snp_gnt_halt[i] = ~(b_llctrl.s_cxl_ll_mem_bi_gnt[i]) & b_txtl_llctrl.s_cxl_s2m_bi_snp[i][S2M_BI_SNP_VLD];
    end
end

always_comb begin
  for (int i = 0; i < S2M_256B_NDR_NUM; i++)  cxl_ch_s2m_ndr_vld[i] = cxl_s2m_ndr_msg_s[i][S2M_NDR_VLD];
  for (int i = 0; i < S2M_256B_DATA_NUM; i++) cxl_ch_s2m_drs_vld[i] = cxl_s2m_hdr_msg_s[i][S2M_HDR_VLD];
  for (int i = 0; i < S2M_256B_BI_SNP_NUM; i++) cxl_ch_s2m_bi_snp_vld[i] = cxl_s2m_bi_snp_msg_s[i][S2M_BI_SNP_VLD];
end
assign s2m_bi_snp_vld_0 = cxl_ch_s2m_bi_snp_vld[0] & r_cxl_ch_s2m_bi_snp_msk[0];
assign s2m_drs_vld_0    = cxl_ch_s2m_drs_vld[0] & r_cxl_ch_s2m_drs_msk[0];
assign s2m_ndr_vld_0    = cxl_ch_s2m_ndr_vld[0] & r_cxl_ch_s2m_ndr_msk[0];
// -------------------------------------------------------------------------------------
// Generate valid signals for credit tracking
// -------------------------------------------------------------------------------------
assign mem_rsp_vld = {{(TX_CRDIF_WIDTH-S2M_256B_NDR_NUM){1'b0}} , cxl_ch_s2m_ndr_vld & ~b_txtl_llctrl.s_cxl_s2m_ndr_halt};
assign mem_hdr_vld = {{(TX_CRDIF_WIDTH-S2M_256B_DATA_NUM){1'b0}}, cxl_ch_s2m_drs_vld & ~b_txtl_llctrl.s_cxl_s2m_hdr_halt};
assign mem_req_vld    = {{(TX_CRDIF_WIDTH-S2M_256B_BI_SNP_NUM){1'b0}} , cxl_ch_s2m_bi_snp_vld & ~b_txtl_llctrl.s_cxl_s2m_bi_snp_halt};
// -------------------------------------------------------------------------------------
// Mem arbitration logic
// -------------------------------------------------------------------------------------
// BI & REQ arbitration
always_comb begin  
  s_rr_mem_req  = r_rr_mem_req;
  s_mem_req_vld = mem_req_vld[0];
  s_mem_bi_vld  = mem_rsp_vld[0];   
  if ((s_rr_mem_req[0]==CXL_MEM_RR_REQ && s_mem_req_vld) ||
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
  s_mem_req_rsp_vld = mem_rsp_vld[0] | mem_req_vld[0] ;
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
logic force_gslot_mem_hdr_n;
logic force_gslot_mem_data_n;
logic mem_round;
logic [2:0] data_idx;



assign mem_round   = (mem_cache_arb==CXL_256B_MEM) | (!d2h_rsp_vld_0 & !d2h_req_vld_0 &  !d2h_hdr_vld_0) ;
always_comb begin  
    force_gslot_mem_data_n = ((!s2m_ndr_vld_0 & !s2m_bi_snp_vld_0) | 
                                                 (r_rr_mem_data == CXL_MEM_RR_DATA)) & mem_round;
    if (FLIT_SLOT_NUM > 1) mem_data_slot_type = (force_gslot_mem_data_n)? cxl_slot_type : CXL_256B_SLOT_G;
    else mem_data_slot_type                   = cxl_slot_type;  
    
    cxl_ch_s2m_drs_vld_nxt   = ((!b_llctrl.s_cxl_ll_mem_mdh_en)? cxl_ch_s2m_drs_vld & 'h1 : cxl_ch_s2m_drs_vld) & r_cxl_ch_s2m_drs_msk;

  for (int i =0;i<FLIT_SLOT_NUM;i++) mem_data_slots[i/4][i%4] = 'd0;
  
  if (cxl_ch_s2m_drs_vld_nxt[0]) begin
    mem_data_slots[0][0] = pack_slot_15 (cxl_s2m_hdr_msg_s, cxl_ch_s2m_drs_vld_nxt, 'd0, mem_data_slot_type);
    mem_data_slots[0][1] = pack_data(cxl_s2m_data_msg_s[shift_s2m_data], 'd0, 'd0, 1'b0, CXL_256B_MEM_S); 
    mem_data_slots[0][2] = pack_data(cxl_s2m_data_msg_s[shift_s2m_data], 'd0, 'd1, 1'b0, CXL_256B_MEM_S); 
    mem_data_slots[0][3] = pack_data(cxl_s2m_data_msg_s[shift_s2m_data], 'd0, 'd2, 1'b0, CXL_256B_MEM_S); 
  end


end
// -------------------------------------------------------------------------------------
// MEM Headers packing
// -------------------------------------------------------------------------------------
always_comb begin   
  cxl_ch_s2m_ndr_vld_nxt     = cxl_ch_s2m_ndr_vld & r_cxl_ch_s2m_ndr_msk;
  cxl_ch_s2m_bi_snp_vld_nxt  = cxl_ch_s2m_bi_snp_vld & r_cxl_ch_s2m_bi_snp_msk;
  s2m_ndr_idx                = 'd0;
  s2m_bi_snp_idx             = 'd0;
  mem_data_idx               = 'd0;
  for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM; slot_idx++) begin
    mem_hdr_slots[slot_idx/4][slot_idx%4]= 'b0;
    force_gslot_mem_hdr_n   = (slot_idx==0) & (!s2m_drs_vld_0 | (r_rr_mem_data == CXL_MEM_RR_HDR)) & mem_round;
    if (FLIT_SLOT_NUM > 1)  mem_slot_type = (force_gslot_mem_hdr_n)? cxl_slot_type : CXL_256B_SLOT_G;
    else                    mem_slot_type = cxl_slot_type;
// spyglass disable_block STARC05-2.8.1.3
// SMD: case constructs should not have overlapping clause conditions. (Verilog)
// SJ: This is to enable synthesis optimization
    casez ({r_rr_mem_req[slot_idx] ,cxl_ch_s2m_ndr_vld_nxt[0], cxl_ch_s2m_bi_snp_vld_nxt[0]})
      3'b?_0_1,
      {CXL_MEM_RR_BI, 2'b?_1}: begin 
        mem_hdr_slots[slot_idx/4][slot_idx%4]  = pack_slot_06 (cxl_s2m_bi_snp_msg_s, cxl_ch_s2m_bi_snp_vld_nxt, s2m_bi_snp_idx, cxl_s2m_ndr_msg_s, cxl_ch_s2m_ndr_vld_nxt, s2m_ndr_idx, mem_slot_type);
        cxl_ch_s2m_bi_snp_vld_nxt              = cxl_ch_s2m_bi_snp_vld_nxt >>   s2m_bisnp_max(mem_slot_type); 
        cxl_ch_s2m_ndr_vld_nxt                 = cxl_ch_s2m_ndr_vld_nxt >> s2m_ndr_max(mem_slot_type,'d6);
        s2m_bi_snp_idx                         = s2m_bi_snp_idx +  s2m_bisnp_max(mem_slot_type);
        s2m_ndr_idx                            = s2m_ndr_idx + s2m_ndr_max(mem_slot_type,'d6);
      end
      3'b?_1_0,
      {CXL_MEM_RR_REQ ,2'b1_?}: begin 
        mem_hdr_slots[slot_idx/4][slot_idx%4] = pack_slot_07 (cxl_s2m_ndr_msg_s, cxl_ch_s2m_ndr_vld_nxt, s2m_ndr_idx, mem_slot_type);
        cxl_ch_s2m_ndr_vld_nxt                = cxl_ch_s2m_ndr_vld_nxt >> s2m_ndr_max(mem_slot_type,'d7); 
        s2m_ndr_idx                           = s2m_ndr_idx + s2m_ndr_max(mem_slot_type,'d7); 
      end
    endcase
// spyglass enable_block STARC05-2.8.1.3
  end
end

// -------------------------------------------------------------------------------------
// Mem Data + Headers packing
// -------------------------------------------------------------------------------------
  always_comb begin   
    mem_data_slot_idx  = 'd0;
    for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM_PAGE; slot_idx++) begin
      if (!mem_hdr_slots[0][slot_idx].Valid || ((r_rr_mem_data == CXL_MEM_RR_DATA) && s2m_drs_vld_0)) begin
        mem_slots[0][slot_idx] = mem_data_slots[0][mem_data_slot_idx];
        mem_data_slot_idx      = mem_data_slot_idx + 'd1;
      end
      else begin
        mem_slots[0][slot_idx]   = mem_hdr_slots[0][slot_idx];
      end
    end
  end
  
// -------------------------------------------------------------------------------------
// Pack Cache Slots in empty Mem Slots
// -------------------------------------------------------------------------------------
 logic [SLOT_CNT_WIDTH_PAGE - 1   : 0] mem_temp_slot_idx;

always_comb begin 
  cache_slot_idx = 'd0;
  for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM_PAGE; slot_idx++) begin
    mem_n_cache_slots[0][slot_idx] = mem_slots[0][slot_idx];
    if (!mem_slots[0][slot_idx].Valid) begin
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
  cxl_ch_s2m_ndr_cnt       = 'd0;
  cxl_ch_s2m_drs_cnt       = 'd0;
  cxl_ch_s2m_bi_snp_cnt    = 'd0;
  cxl_ch_s2m_data_cnt      = 'd0;

  s_cxl_ch_s2m_ndr_halt    = '1;
  s_cxl_ch_s2m_drs_halt    = '1;
  s_cxl_ch_s2m_bi_snp_halt = '1;
  s_cxl_ch_s2m_data_halt   = '1;

  for (int slot_idx=0; slot_idx<FLIT_SLOT_NUM_PAGE ;slot_idx++) begin
  
     mem_halt_slot_type = (slot_idx==0)? cxl_slot_type : CXL_256B_SLOT_G;

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: No overflow expected
     
      // S2M BISnp
    if (cxl_packer_flit[slot_idx].slot_idx == 'd6)begin
      s_cxl_ch_s2m_bi_snp_halt = s_cxl_ch_s2m_bi_snp_halt << s2m_bisnp_max(mem_halt_slot_type);
    end
    // S2M NDR
    if (cxl_packer_flit[slot_idx].slot_idx == 'd6)begin
      s_cxl_ch_s2m_ndr_halt = s_cxl_ch_s2m_ndr_halt << s2m_ndr_max(mem_halt_slot_type,'d6);
    end
    else if (cxl_packer_flit[slot_idx].slot_idx == 'd7)begin
      s_cxl_ch_s2m_ndr_halt = s_cxl_ch_s2m_ndr_halt << s2m_ndr_max(mem_halt_slot_type,'d7);
    end
    // S2M HDR
    if (cxl_packer_flit[slot_idx].slot_idx == 'd15)begin
      cxl_ch_s2m_drs_cnt    = cxl_ch_s2m_drs_cnt + s2m_hdr_max(mem_halt_slot_type, b_llctrl.s_cxl_ll_mem_mdh_en);
      s_cxl_ch_s2m_drs_halt = s_cxl_ch_s2m_drs_halt << s2m_hdr_max(mem_halt_slot_type, b_llctrl.s_cxl_ll_mem_mdh_en);
    end
// spyglass enable_block W164a
    if (cxl_packer_flit[slot_idx].data_info.data_strt & (cxl_packer_flit[slot_idx].data_info.data_type==CXL_256B_MEM_S)) begin
      cxl_ch_s2m_data_cnt++;
      s_cxl_ch_s2m_data_halt = s_cxl_ch_s2m_data_halt << 1;
    end
  end
  
  s_mem_message_vld                          = 'd0;
  s_mem_message_vld[S2M_256B_NDR_NUM-1:0]    = cxl_ch_s2m_ndr_vld & ~s_cxl_ch_s2m_ndr_halt & ~cxl_ch_s2m_ndr_gnt_halt & r_cxl_ch_s2m_ndr_msk;
  cxl_ch_s2m_ndr_cnt                         = valid_cnt(s_mem_message_vld);

  s_mem_message_vld                          = 'd0;
  s_mem_message_vld[S2M_256B_DATA_NUM-1:0]   = cxl_ch_s2m_drs_vld & ~s_cxl_ch_s2m_drs_halt & ~cxl_ch_s2m_drc_gnt_halt & r_cxl_ch_s2m_drs_msk;
  cxl_ch_s2m_drs_cnt                         = valid_cnt(s_mem_message_vld);
  
  s_mem_message_vld                          = 'd0;
  s_mem_message_vld[S2M_256B_BI_SNP_NUM-1:0] = cxl_ch_s2m_bi_snp_vld & ~s_cxl_ch_s2m_bi_snp_halt & ~cxl_ch_s2m_bi_snp_gnt_halt & r_cxl_ch_s2m_bi_snp_msk;
  cxl_ch_s2m_bi_snp_cnt                      = valid_cnt(s_mem_message_vld);

   

 
  
  s_cxl_ch_s2m_ndr_msk    = {S2M_256B_NDR_NUM{1'b1}}     >> (cxl_ch_s2m_ndr_cnt);
  s_cxl_ch_s2m_drs_msk    = {S2M_256B_DATA_NUM{1'b1}}    >> (cxl_ch_s2m_drs_cnt);
  s_cxl_ch_s2m_bi_snp_msk = {S2M_256B_BI_SNP_NUM{1'b1}}  >> (cxl_ch_s2m_bi_snp_cnt);
  // Halt corresponding message channels
  // Halt Protocol Message Channels only if the message is valid otherwise do not assert
  // halt signal to allow channel to proceed

  b_txtl_llctrl.s_cxl_s2m_ndr_halt = cxl_prot_msg_halt_s ? {S2M_256B_NDR_NUM{1'b1}}        : 
                                    (  ~r_cxl_ch_s2m_ndr_msk | cxl_ch_s2m_ndr_gnt_halt | (cxl_ch_s2m_ndr_vld & s_cxl_ch_s2m_ndr_halt));
  b_txtl_llctrl.s_cxl_s2m_hdr_halt = cxl_prot_msg_halt_s ? {S2M_256B_DATA_NUM{1'b1}}       : 
                                    (  ~r_cxl_ch_s2m_drs_msk | cxl_ch_s2m_drc_gnt_halt | (cxl_ch_s2m_drs_vld & s_cxl_ch_s2m_drs_halt));
  b_txtl_llctrl.s_cxl_s2m_bi_snp_halt = cxl_prot_msg_halt_s ? {S2M_256B_BI_SNP_NUM{1'b1}}  : 
                                      (  ~r_cxl_ch_s2m_bi_snp_msk | cxl_ch_s2m_bi_snp_gnt_halt | (cxl_ch_s2m_bi_snp_vld & s_cxl_ch_s2m_bi_snp_halt));
  b_txtl_llctrl.s_cxl_s2m_data_halt = cxl_prot_data_halt_s?  {S2M_256B_DDATA_NUM{1'b1}}    : s_cxl_ch_s2m_data_halt;
end




function automatic logic [$clog2(S2M_256B_NDR_NUM)    :0] s2m_ndr_max   (
    CXL_SLOT_TYPES                  slot_type,
    logic [3:0]                     cxl_slot_idx           
  );
  logic [$clog2(S2M_256B_NDR_NUM)  :0] s_max_cnt;
  begin

    // Slot # 6
    // +------------------+
    // |      S2M NDR     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 1 | 0 |  0 |
    // +-----+---+---+----+
    // | PBR | 0 | 0 |  x |
    // +-----+---+---+----+

    // Slot # 7
    // +------------------+
    // |      S2M NDR     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 3 | 2 |  2 |
    // +-----+---+---+----+
    // | PBR | 2 | 2 |  x |
    // +-----+---+---+----+
  
    s_max_cnt = (cxl_slot_idx=='d6)? (((slot_type==CXL_256B_SLOT_G))? 'd1 : 'd0): 
                                     (((slot_type==CXL_256B_SLOT_G))? 'd3 : 'd2);
    return s_max_cnt;
  end
endfunction
function automatic logic [$clog2(S2M_256B_BI_SNP_NUM) :0] s2m_bisnp_max (
    CXL_SLOT_TYPES                  slot_type
  );
  logic [$clog2(S2M_256B_BI_SNP_NUM)  :0] s_max_cnt;
  begin
    // +------------------+
    // |   S2M BI-SNP     |
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
function automatic logic [$clog2(S2M_256B_DATA_NUM)   :0] s2m_hdr_max   (
      CXL_SLOT_TYPES                 slot_type
    , logic                          mdh_en
  );
  logic [$clog2(S2M_256B_DATA_NUM)  :0] s_max_cnt;
  begin
    // +------------------+
    // |      S2M HDR     |
    // +-----+---+---+----+
    // |     | G | H | Hs |
    // +-----+---+---+----+
    // | HBR | 3 | 2 |  2 |
    // +-----+---+---+----+
    // | PBR | 2 | 2 |  x |
    // +-----+---+---+----+
   
    s_max_cnt = (!mdh_en)? 'd1 : 
              ((slot_type==CXL_256B_SLOT_G))? 'd3 : 'd2;
    return s_max_cnt;
  end
endfunction


function automatic SLOT_DESCR_256B_t pack_slot_06( 
  logic [S2M_BI_SNP_SIZE-1      : 0] cxl_s2m_bi_snp_msg_s [0:S2M_256B_BI_SNP_NUM-1] ,
  logic [S2M_256B_BI_SNP_NUM-1  : 0] cxl_ch_s2m_bi_snp_vld_nxt           ,
  logic [S2M_BI_SNP_CNT_WIDTH-1 : 0] s2m_bi_snp_idx                         , 
  logic [S2M_256B_NDR_SIZE-1    : 0] cxl_s2m_ndr_msg_s [0:S2M_256B_NDR_NUM-1] ,
  logic [S2M_256B_NDR_NUM-1     : 0] cxl_ch_s2m_ndr_vld                  , 
  logic [S2M_REQ_CNT_WIDTH-1    : 0] s2m_ndr_idx                         , 
  CXL_SLOT_TYPES                     slot_type
  );
  SLOT_DESCR_256B_t slot_curr;
  logic is_g_slot;
  begin
    // G Slot   : 1 S2M BI SNP + 1 S2M NDR
    // H/Hs Slot: 1 S2M BI SNP
    is_g_slot           = (slot_type == CXL_256B_SLOT_G);
    slot_curr           = 'b0;
    slot_curr.Valid     = 1'b1;
    slot_curr.slot_idx  = 'd6;
    slot_curr.slot_type = slot_type;
    slot_curr.Slot[0 +: (S2M_HBR_NDR_SIZE+S2M_HBR_BI_SNP_SIZE)]= 
    {
    cxl_s2m_ndr_msg_s[s2m_ndr_idx][0 +: S2M_HBR_NDR_SIZE] & {S2M_HBR_NDR_SIZE{cxl_ch_s2m_ndr_vld[0] & is_g_slot}},
    cxl_s2m_bi_snp_msg_s[s2m_bi_snp_idx][0 +: S2M_HBR_BI_SNP_SIZE]
    };
    return slot_curr;
  end
endfunction
function automatic SLOT_DESCR_256B_t pack_slot_07( 
  logic [S2M_256B_NDR_SIZE-1         : 0] cxl_s2m_ndr_msg_s [0:S2M_256B_NDR_NUM-1] ,
  logic [S2M_256B_NDR_NUM-1          : 0] cxl_ch_s2m_ndr_vld                  , 
  logic [S2M_REQ_CNT_WIDTH-1         : 0] s2m_ndr_idx                         ,
  CXL_SLOT_TYPES                     slot_type
  );
  logic is_g_slot;
  SLOT_DESCR_256B_t slot_curr;
  begin
    // G Slot   : 3 S2M NDR
    // H/Hs Slot: 2 S2M NDR
    is_g_slot           = (slot_type == CXL_256B_SLOT_G);
    slot_curr           = 'b0;
    slot_curr.Valid     = 1'b1;
    slot_curr.slot_idx  = 'd7;
    slot_curr.slot_type = slot_type;
// spyglass disable_block ImproperRangeIndex-ML
// SMD: INDEX larger than the bit width required for variable.
// SJ: for out of IDX the valid should be zero
    slot_curr.Slot[0 +: (3*S2M_HBR_NDR_SIZE)]= 
    {
    cxl_s2m_ndr_msg_s[s2m_ndr_idx + 2][0 +: S2M_HBR_NDR_SIZE] & {S2M_HBR_NDR_SIZE{cxl_ch_s2m_ndr_vld[2] & is_g_slot}},
    cxl_s2m_ndr_msg_s[s2m_ndr_idx + 1][0 +: S2M_HBR_NDR_SIZE] & {S2M_HBR_NDR_SIZE{cxl_ch_s2m_ndr_vld[1]}},
    cxl_s2m_ndr_msg_s[s2m_ndr_idx]    [0 +: S2M_HBR_NDR_SIZE]
    };
// spyglass enable_block ImproperRangeIndex-ML
    return slot_curr;
  end
endfunction
function automatic SLOT_DESCR_256B_t pack_slot_15( 
  logic [S2M_256B_DHDR_SIZE-1      : 0] cxl_s2m_hdr_msg_s [0:S2M_256B_DATA_NUM-1] ,
  logic [S2M_256B_DATA_NUM-1       : 0] cxl_ch_s2m_drs_vld_nxt               , 
  logic                                 s2m_drs_idx                          , 
  CXL_SLOT_TYPES                        slot_type
  );
  SLOT_DESCR_256B_t slot_curr;
  logic is_g_slot;
  begin
    // G Slot   : 3 S2M DRS 
    // H/Hs Slot: 2 S2M DRS 
    is_g_slot           = (slot_type == CXL_256B_SLOT_G);
    slot_curr           = 'b0;
    slot_curr.Valid     = 1'b1;
    slot_curr.slot_idx  = 'd15;
    slot_curr.slot_type = slot_type;
// spyglass disable_block W468
// SMD: Index variable is too short
// SJ: s2m_drs_idx is only used when MDH is not enabled.
    slot_curr.Slot[0 +: (3*S2M_HBR_DHDR_SIZE)]= 
    {
      cxl_s2m_hdr_msg_s[2][0 +: S2M_HBR_DHDR_SIZE] & {S2M_HBR_DHDR_SIZE{cxl_ch_s2m_drs_vld_nxt[2] & is_g_slot}},
      cxl_s2m_hdr_msg_s[1][0 +: S2M_HBR_DHDR_SIZE] & {S2M_HBR_DHDR_SIZE{cxl_ch_s2m_drs_vld_nxt[1]}},
      cxl_s2m_hdr_msg_s[s2m_drs_idx]    [0 +: S2M_HBR_DHDR_SIZE]
    };
// spyglass enable_block W468

    unique casez (cxl_ch_s2m_drs_vld_nxt[2:0])
      3'b001 : begin slot_curr.Data = 'd4; slot_curr.data_vld='b1;  end
      3'b011 : begin slot_curr.Data = 'd8; slot_curr.data_vld='b11; end
      3'b111 : begin slot_curr.Data = (is_g_slot)? 'd12: 'd8; 
                                           slot_curr.data_vld=(is_g_slot )? 'b111: 'b11; end
      default: begin slot_curr.Data = 'd0; slot_curr.data_vld='b0;  end
    endcase
    return slot_curr;
  end
endfunction

assign cxl_mem_pending = pack_enable & (b_txtl_llctrl.s_cxl_s2m_ndr[0][S2M_NDR_VLD] || b_txtl_llctrl.s_cxl_s2m_hdr[0][S2M_HDR_VLD]
 || b_txtl_llctrl.s_cxl_s2m_bi_snp[0][S2M_BI_SNP_VLD] );

assign cxl_tl_pending_o = (1'b0    || b_txtl_llctrl.s_cxl_d2h_req[0][D2H_REQ_VLD] || b_txtl_llctrl.s_cxl_d2h_rsp[0][D2H_RESP_VLD] || b_txtl_llctrl.s_cxl_d2h_hdr[0][D2H_HDR_VLD]
    || b_txtl_llctrl.s_cxl_s2m_ndr[0][S2M_NDR_VLD] || b_txtl_llctrl.s_cxl_s2m_hdr[0][S2M_HDR_VLD]
 || b_txtl_llctrl.s_cxl_s2m_bi_snp[0][S2M_BI_SNP_VLD]) ;
endmodule
