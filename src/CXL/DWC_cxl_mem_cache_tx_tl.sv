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
// ---   $Revision: #13 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_tx_tl.sv#13 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Transmitter Transaction Layer Top Module 
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_txtl_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_app_ch_if.svh"
`include "CXL/svif/DWC_cxl_app_ch_init_if.svh"

module DWC_cxl_mem_cache_tx_tl
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
 )(
    // -------------------------------------------------------------------------------------
    // Clock and Reset
    // -------------------------------------------------------------------------------------
    DWC_cxl_clk_rst_if.slave_mp          b_clk,                   // Clock and Reset interface
    // -------------------------------------------------------------------------------------
    // Configuration Interface
    // -------------------------------------------------------------------------------------
    input                                cfg_cxl_cache_capable,   // Enable CXL.cache protocol
    input                                cfg_cxl_mem_capable,     // Enable CXL.mem protocol
    input                                cfg_dev_mode,            // Device Mode: 1 - Host, 0 - Device
    // -------------------------------------------------------------------------------------
    // Low Power Handshake Interface
    // -------------------------------------------------------------------------------------
    input                                cxl_lp_req,              // Low Power mode request
    output                               cxl_lp_ack,              // Low Power mode acknowledge
    // -------------------------------------------------------------------------------------
    // Link Status Interface
    // -------------------------------------------------------------------------------------
    input                                cxl_ll_idle,             // CXL LL Controller is in Idle state
    input                                core_link_up             // Data Link Layer Up/Down Indicator
    // -------------------------------------------------------------------------------------
    // CXL Protocol Link Initialization Interface
    // -------------------------------------------------------------------------------------
    , DWC_cxl_app_ch_init_if.slave_mp    b_app_cache_init
    , DWC_cxl_app_ch_init_if.slave_mp    b_app_mem_init
    // -------------------------------------------------------------------------------------
    // CXL Interface Channels
    // -------------------------------------------------------------------------------------
    , DWC_cxl_app_ch_if.slave_host_mp        b_app_host_chi  // Application Host Channel Interface
    , DWC_cxl_txtl_llctrl_if.master_host_mp  b_txtl_host     // Transaction Layer Interface for Host Channels
    , DWC_cxl_app_ch_if.slave_device_mp      b_app_dev_chi   // Application Device Channel Interface
    , DWC_cxl_txtl_llctrl_if.master_dev_mp   b_txtl_dev      // Transaction Layer Interface for Device Channels
    // -------------------------------------------------------------------------------------
    // RASDP Wrapper Interface
    // -------------------------------------------------------------------------------------
    , DWC_cxl_txtl_llctrl_if.master_rasdp_mp b_txtl_rasdp    // Transaction Layer - RASDP Wrapper Interface
    // -------------------------------------------------------------------------------------
    // RAS Wrapper Interface
    // -------------------------------------------------------------------------------------
    , output [7:0]                          cxl_tx_fifo_ovflw_o // Transmitter Channel Message FIFO Overflow
    // -------------------------------------------------------------------------------------
    // CXL Transmitter RAM Interfaces
    // -------------------------------------------------------------------------------------
);

// -------------------------------------------------------------------------------------
// Core clock register instantiation
// -------------------------------------------------------------------------------------
logic pos_core_clk;

assign pos_core_clk = 1'b1;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Register Device Mode in cxl_clk domain
// -------------------------------------------------------------------------------------
logic cfg_dev_mode_cxl;
localparam M2S_BE_CH_SIZE  = M2S_DBE_SIZE + M2S_DBE_CHK_SIZE; //defined here because it is used in S2M can be moved to pkg
delay_n
 #(
    .N     (1)
) u_delay_cfg_dev_mode_reg (
    .clk   (b_clk.s_cxl_clk),
    .rst_n (b_clk.s_cxl_rst_n),
    .clear (1'b0),
    .din   (cfg_dev_mode),
    .dout  (cfg_dev_mode_cxl)
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Passing signals from Application to Transaction Layer Interface
// -------------------------------------------------------------------------------------
logic cxl_cache_app_pending_r;
assign b_txtl_dev.s_cxl_cache_app_pending = cxl_cache_app_pending_r;
assign b_txtl_host.s_cxl_cache_app_pending = cxl_cache_app_pending_r;
delay_n
 #(
    .N     (1),
    .WD    (1)
) u_cache_app_pending (
    .clk   (b_clk.s_core_clk),
    .rst_n (b_clk.s_core_rst_n),
    .clear (1'b0),
    .din   (b_app_cache_init.s_cxl_app_pending),
    .dout  (cxl_cache_app_pending_r)
);

logic cxl_mem_app_pending_r;
assign b_txtl_dev.s_cxl_mem_app_pending = cxl_mem_app_pending_r;
assign b_txtl_host.s_cxl_mem_app_pending = cxl_mem_app_pending_r;
delay_n
 #(
    .N     (1),
    .WD    (1)
) u_mem_app_pending (
    .clk   (b_clk.s_core_clk),
    .rst_n (b_clk.s_core_rst_n),
    .clear (1'b0),
    .din   (b_app_mem_init.s_cxl_app_pending),
    .dout  (cxl_mem_app_pending_r)
);  
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Channel Message Buffers Overflow Flags
// Data, Data Header, Response, Request
// -------------------------------------------------------------------------------------
logic [7:0] host_chmsg_buff_ovflw_s;

logic [H2D_REQ_IFNUM -1:0] host_cache_req_ovflw_s;
logic [H2D_RESP_IFNUM-1:0] host_cache_rsp_ovflw_s;
logic [H2D_DATA_IFNUM-1:0] host_cache_data_ovflw_s;
logic [H2D_DATA_IFNUM-1:0] host_cache_hdr_ovflw_s;

logic [M2S_NDR_IFNUM    -1:0] host_mem_ndr_ovflw_s;
logic [M2S_BI_RSP_IFNUM -1:0] host_mem_bi_rsp_ovflw_s;
logic [M2S_DATA_IFNUM   -1:0] host_mem_hdr_ovflw_s;
logic [M2S_DATA_IFNUM   -1:0] host_mem_data_ovflw_s;




//Here overflow and empty signals are added per channel message, this is a needed step in parametrization because the number of channels is now parametrized.
//This makes it easier generating these signals where their widths are function of the *_IFNUM parameter, and iterating on them using loop iterator when generating different number of channels
//Oring between different channels of the same type happens as it was the case with h2d resp and d2h req in 68B mode
assign host_chmsg_buff_ovflw_s[3:0] = {(|host_cache_data_ovflw_s), (|host_cache_hdr_ovflw_s), (|host_cache_rsp_ovflw_s), (|host_cache_req_ovflw_s) };
//logic [3:0] host_mem_buff_ovflw_s; // 3: M2S Data, 2: M2S Data Header, 1: M2S Request, 0: M2S BI-Response; 

assign host_chmsg_buff_ovflw_s[7:4] = { (|host_mem_data_ovflw_s), (|host_mem_hdr_ovflw_s), (|host_mem_bi_rsp_ovflw_s) , (|host_mem_ndr_ovflw_s) };

logic [7:0] dev_chmsg_buff_ovflw_s;

logic [D2H_REQ_IFNUM -1:0] dev_cache_req_ovflw_s;
logic [D2H_RESP_IFNUM-1:0] dev_cache_rsp_ovflw_s;
logic [D2H_DATA_IFNUM-1:0] dev_cache_data_ovflw_s;
logic [D2H_DATA_IFNUM-1:0] dev_cache_hdr_ovflw_s;

logic [S2M_NDR_IFNUM    -1:0] dev_mem_ndr_ovflw_s;
logic [S2M_BI_SNP_IFNUM -1:0] dev_mem_bi_snp_ovflw_s;
logic [S2M_DATA_IFNUM   -1:0] dev_mem_hdr_ovflw_s;
logic [S2M_DATA_IFNUM   -1:0] dev_mem_data_ovflw_s;




assign dev_chmsg_buff_ovflw_s[3:0] = {(|dev_cache_data_ovflw_s), (|dev_cache_hdr_ovflw_s), (|dev_cache_rsp_ovflw_s), (|dev_cache_req_ovflw_s)};


assign dev_chmsg_buff_ovflw_s[7:4] = { (|dev_mem_data_ovflw_s), (|dev_mem_hdr_ovflw_s), (|dev_mem_ndr_ovflw_s), (|dev_mem_bi_snp_ovflw_s) };

assign cxl_tx_fifo_ovflw_o = 8'h00   | host_chmsg_buff_ovflw_s 
 | dev_chmsg_buff_ovflw_s ;
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// RAM Interface Instantiation and Connections
// -------------------------------------------------------------------------------------
DWC_cxl_ram2p_if  #( .DATA_WIDTH (HD_DATAW), .ADDR_WIDTH (HD_DATA_RAM_ADDRW) )     b_cxl_slv_h2d_data_ram ();
DWC_cxl_ram2p_if  #( .DATA_WIDTH (HD_DATAW), .ADDR_WIDTH (HD_DATA_RAM_ADDRW) )     b_cxl_slv_d2h_data_ram ();

DWC_cxl_ram2p_if  #( .DATA_WIDTH (HD_DATAW), .ADDR_WIDTH (HD_DATA_RAM_ADDRW) )     b_cxl_slv_hd_chdata_buff ();


assign b_cxl_slv_hd_chdata_buff.s_ram_we       = cfg_dev_mode_cxl ? b_cxl_slv_h2d_data_ram.s_ram_we      : b_cxl_slv_d2h_data_ram.s_ram_we      ;
assign b_cxl_slv_hd_chdata_buff.s_ram_wr_addr  = cfg_dev_mode_cxl ? b_cxl_slv_h2d_data_ram.s_ram_wr_addr : b_cxl_slv_d2h_data_ram.s_ram_wr_addr ;
assign b_cxl_slv_hd_chdata_buff.s_ram_wdata    = cfg_dev_mode_cxl ? b_cxl_slv_h2d_data_ram.s_ram_wdata   : b_cxl_slv_d2h_data_ram.s_ram_wdata   ;
assign b_cxl_slv_hd_chdata_buff.s_ram_rd_addr  = cfg_dev_mode_cxl ? b_cxl_slv_h2d_data_ram.s_ram_rd_addr : b_cxl_slv_d2h_data_ram.s_ram_rd_addr ;
assign b_cxl_slv_hd_chdata_buff.s_ram_rd       = cfg_dev_mode_cxl ? b_cxl_slv_h2d_data_ram.s_ram_rd      : b_cxl_slv_d2h_data_ram.s_ram_rd      ;
assign b_cxl_slv_h2d_data_ram.s_ram_rdata      = b_cxl_slv_hd_chdata_buff.s_ram_rdata;
assign b_cxl_slv_d2h_data_ram.s_ram_rdata      = b_cxl_slv_hd_chdata_buff.s_ram_rdata;





DWC_cxl_ram2p_if  #( .DATA_WIDTH (MS_DATAW), .ADDR_WIDTH (MS_DATA_RAM_ADDRW) )     b_cxl_slv_m2s_data_ram ();
DWC_cxl_ram2p_if  #( .DATA_WIDTH (MS_DATAW), .ADDR_WIDTH (MS_DATA_RAM_ADDRW) )     b_cxl_slv_s2m_data_ram ();


DWC_cxl_ram2p_if  #( .DATA_WIDTH (MS_DATAW), .ADDR_WIDTH (MS_DATA_RAM_ADDRW) )     b_cxl_slv_ms_chdata_buff ();


assign b_cxl_slv_ms_chdata_buff.s_ram_we       = cfg_dev_mode_cxl ? b_cxl_slv_m2s_data_ram.s_ram_we      : b_cxl_slv_s2m_data_ram.s_ram_we      ;
assign b_cxl_slv_ms_chdata_buff.s_ram_wr_addr  = cfg_dev_mode_cxl ? b_cxl_slv_m2s_data_ram.s_ram_wr_addr : b_cxl_slv_s2m_data_ram.s_ram_wr_addr ;
assign b_cxl_slv_ms_chdata_buff.s_ram_wdata    = cfg_dev_mode_cxl ? b_cxl_slv_m2s_data_ram.s_ram_wdata   : b_cxl_slv_s2m_data_ram.s_ram_wdata   ;
assign b_cxl_slv_ms_chdata_buff.s_ram_rd_addr  = cfg_dev_mode_cxl ? b_cxl_slv_m2s_data_ram.s_ram_rd_addr : b_cxl_slv_s2m_data_ram.s_ram_rd_addr ;
assign b_cxl_slv_ms_chdata_buff.s_ram_rd       = cfg_dev_mode_cxl ? b_cxl_slv_m2s_data_ram.s_ram_rd      : b_cxl_slv_s2m_data_ram.s_ram_rd      ;
assign b_cxl_slv_m2s_data_ram.s_ram_rdata      = b_cxl_slv_ms_chdata_buff.s_ram_rdata;
assign b_cxl_slv_s2m_data_ram.s_ram_rdata      = b_cxl_slv_ms_chdata_buff.s_ram_rdata;

  DWC_cxl_mem_cache_tx_tl_ram
   u_data_ram (
    .b_clk                                          ( b_clk                                    )
    , .b_cxl_slv_hd_data_ram                        ( b_cxl_slv_hd_chdata_buff.slave_chdata_mp )
    , .b_cxl_slv_ms_data_ram                        ( b_cxl_slv_ms_chdata_buff.slave_chdata_mp )
  );
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// H2D Request-Response Message Cycle Counter
// -------------------------------------------------------------------------------------
logic [H2D_MSG_CNT_WD-1:0] cache_cycle_cnt_r;
logic                      cache_h2d_req_vld_s;

always_comb begin
    cache_h2d_req_vld_s = 1'b0;
    for (int i = 0; i < H2D_REQ_IFNUM; i++)  cache_h2d_req_vld_s = cache_h2d_req_vld_s | b_app_host_chi.s_cxl_h2d_req[i][H2D_REQ_VLD]   ;
end

always_ff @(posedge b_clk.s_cxl_clk or negedge b_clk.s_cxl_rst_n) begin
    if (!b_clk.s_cxl_rst_n) begin
        cache_cycle_cnt_r <= #TP '0;
    end
    else if (cache_h2d_req_vld_s) begin
        cache_cycle_cnt_r <= #TP cache_cycle_cnt_r + H2D_MSG_CNT_WD'(1);
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL.cache Protocol Link Activation FSM
// -------------------------------------------------------------------------------------
logic       cxl_cache_init_req_r;
logic       cxl_cache_lp_ack;
logic       cxl_cache_crd_ena;
logic       cxl_cache_crd_rst;
logic       cxl_cache_busy_r;
logic       cxl_cache_busy_s;
logic       cxl_cache_idle_s;
logic       cxl_cache_init_ack_r;

logic       cxl_h2d_busy_s;
//logic [4:0] host_cache_buff_empty_s;
logic [3:0] host_cache_buff_empty_s;
logic [H2D_REQ_IFNUM -1:0] host_cache_req_empty_s;
logic [H2D_RESP_IFNUM-1:0] host_cache_rsp_empty_s;
logic [H2D_DATA_IFNUM-1:0] host_cache_data_empty_s;
logic [H2D_DATA_IFNUM-1:0] host_cache_hdr_empty_s;


assign host_cache_buff_empty_s = {(&host_cache_data_empty_s), (&host_cache_hdr_empty_s), (&host_cache_rsp_empty_s), (&host_cache_req_empty_s)};
assign cxl_h2d_busy_s = ~(&host_cache_buff_empty_s);
assign b_txtl_host.s_cxl_cache_enable = cxl_cache_init_ack_r;
logic cxl_d2h_busy_s;
//logic [4:0] dev_cache_buff_empty_s;
logic [3:0] dev_cache_buff_empty_s;


logic [D2H_REQ_IFNUM -1:0] dev_cache_req_empty_s;
logic [D2H_RESP_IFNUM-1:0] dev_cache_rsp_empty_s;
logic [D2H_DATA_IFNUM-1:0] dev_cache_data_empty_s;
logic [D2H_DATA_IFNUM-1:0] dev_cache_hdr_empty_s;

assign dev_cache_buff_empty_s = {(&dev_cache_data_empty_s), (&dev_cache_hdr_empty_s), (&dev_cache_rsp_empty_s), (&dev_cache_req_empty_s)};

assign cxl_d2h_busy_s = ~(&dev_cache_buff_empty_s);
assign b_txtl_dev.s_cxl_cache_enable  = cxl_cache_init_ack_r;

assign cxl_cache_busy_s = 1'b0/*b_app_cache_init.s_cxl_init_req*/ || cxl_h2d_busy_s || cxl_d2h_busy_s; 
assign cxl_cache_idle_s = ~cxl_cache_busy_r & cxl_ll_idle;

delay_n
 #(
    .N     (1),
    .WD    (1)
) u_delay_cache_busy (
    .clk   (b_clk.s_cxl_clk),
    .rst_n (b_clk.s_cxl_rst_n),
    .clear (1'b0),
    .din   (cxl_cache_busy_s),
    .dout  (cxl_cache_busy_r)
);

delay_n
 #(
    .N     (1),
    .WD    (1)
) u_delay_cache_init_ack (
    .clk   (b_clk.s_core_clk),
    .rst_n (b_clk.s_core_rst_n),
    .clear (1'b0),
    .din   (b_app_cache_init.s_cxl_init_ack),
    .dout  (cxl_cache_init_ack_r)
);

delay_n
 #(
    .WD    (1)
) u_cache_init_req (
    .clk   (b_clk.s_cxl_clk),
    .rst_n (b_clk.s_cxl_rst_n),
    .clear (1'b0),
    .din   (b_app_cache_init.s_cxl_init_req),
    .dout  (cxl_cache_init_req_r)
);

DWC_cxl_mem_cache_tx_tl_prot_fsm
 u_tx_tl_cache_prot_fsm (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .cfg_cxl_prot_capable (cfg_cxl_cache_capable),
    .cxl_lp_req           (cxl_lp_req),
    .cxl_lp_ack           (cxl_cache_lp_ack),
    .core_link_up         (core_link_up),
    .cxl_tx_idle          (cxl_cache_idle_s),
    .cxl_prot_init_req    (cxl_cache_init_req_r),
    .cxl_prot_init_ack    (b_app_cache_init.s_cxl_init_ack),
    .cxl_prot_crd_ena     (cxl_cache_crd_ena),
    .cxl_prot_crd_rst     (cxl_cache_crd_rst)
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXL.mem Protocol Link Activation FSM
// -------------------------------------------------------------------------------------
logic       cxl_mem_init_req_r;
logic       cxl_mem_lp_ack;
logic       cxl_mem_crd_ena;
logic       cxl_mem_crd_rst;
logic       cxl_mem_busy_r;
logic       cxl_mem_busy_s;
logic       cxl_mem_idle_s;
logic       cxl_mem_init_ack_r;

logic       cxl_m2s_crd_ena;

assign cxl_m2s_crd_ena = cxl_mem_crd_ena && cfg_dev_mode_cxl;
logic       cxl_s2m_crd_ena;

assign cxl_s2m_crd_ena = cxl_mem_crd_ena && !cfg_dev_mode_cxl;

logic cxl_m2s_busy_s;
logic [3:0] host_mem_buff_empty_s;

logic [M2S_NDR_IFNUM    -1:0] host_mem_ndr_empty_s;
logic [M2S_BI_RSP_IFNUM -1:0] host_mem_bi_rsp_empty_s;
logic [M2S_DATA_IFNUM   -1:0] host_mem_hdr_empty_s;
logic [M2S_DATA_IFNUM   -1:0] host_mem_data_empty_s;

assign host_mem_buff_empty_s = {host_mem_data_empty_s, host_mem_hdr_empty_s, (|host_mem_ndr_empty_s), (|host_mem_bi_rsp_empty_s)};
assign cxl_m2s_busy_s = ~(&host_mem_buff_empty_s);
assign b_txtl_host.s_cxl_mem_enable  = cxl_mem_init_ack_r;
logic cxl_s2m_busy_s;
logic [3:0] dev_mem_buff_empty_s;

logic [S2M_NDR_IFNUM    -1:0] dev_mem_ndr_empty_s;
logic [S2M_BI_SNP_IFNUM -1:0] dev_mem_bi_snp_empty_s;
logic [S2M_DATA_IFNUM   -1:0] dev_mem_hdr_empty_s;
logic [S2M_DATA_IFNUM   -1:0] dev_mem_data_empty_s;
assign dev_mem_buff_empty_s = {dev_mem_data_empty_s, dev_mem_hdr_empty_s, (|dev_mem_ndr_empty_s), (|dev_mem_bi_snp_empty_s)};
assign cxl_s2m_busy_s = ~(&dev_mem_buff_empty_s);
assign b_txtl_dev.s_cxl_mem_enable   = cxl_mem_init_ack_r;

assign cxl_mem_busy_s = 1'b0/*b_app_mem_init.s_cxl_init_req*/ || cxl_m2s_busy_s || cxl_s2m_busy_s; 
assign cxl_mem_idle_s = ~cxl_mem_busy_r & cxl_ll_idle;

delay_n
 #(
    .N     (1),
    .WD    (1)
) u_delay_mem_busy (
    .clk   (b_clk.s_cxl_clk),
    .rst_n (b_clk.s_cxl_rst_n),
    .clear (1'b0),
    .din   (cxl_mem_busy_s),
    .dout  (cxl_mem_busy_r)
);

delay_n
 #(
    .N     (1),
    .WD    (1)
) u_delay_mem_init_ack (
    .clk   (b_clk.s_core_clk),
    .rst_n (b_clk.s_core_rst_n),
    .clear (1'b0),
    .din   (b_app_mem_init.s_cxl_init_ack),
    .dout  (cxl_mem_init_ack_r)
);

delay_n
 #(
    .WD    (1)
) u_mem_init_req (
    .clk   (b_clk.s_cxl_clk),
    .rst_n (b_clk.s_cxl_rst_n),
    .clear (1'b0),
    .din   (b_app_mem_init.s_cxl_init_req),
    .dout  (cxl_mem_init_req_r)
);

DWC_cxl_mem_cache_tx_tl_prot_fsm
 u_tx_tl_mem_prot_fsm (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .cfg_cxl_prot_capable (cfg_cxl_mem_capable),
    .cxl_lp_req           (cxl_lp_req),
    .cxl_lp_ack           (cxl_mem_lp_ack),
    .core_link_up         (core_link_up),
    .cxl_tx_idle          (cxl_mem_idle_s),
    .cxl_prot_init_req    (cxl_mem_init_req_r),
    .cxl_prot_init_ack    (b_app_mem_init.s_cxl_init_ack),
    .cxl_prot_crd_ena     (cxl_mem_crd_ena),
    .cxl_prot_crd_rst     (cxl_mem_crd_rst)
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Low Power acknowledge
// -------------------------------------------------------------------------------------
logic cxl_lp_ack_r, cxl_lp_ack_nxt;

assign cxl_lp_ack = cxl_lp_ack_r;

always_comb begin
    cxl_lp_ack_nxt = 1'b1;
    cxl_lp_ack_nxt = cxl_lp_ack_nxt & cxl_cache_lp_ack;
    cxl_lp_ack_nxt = cxl_lp_ack_nxt & cxl_mem_lp_ack;
end

always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin
    if (!b_clk.s_core_rst_n) begin
        cxl_lp_ack_r <= #TP 1'b1;
    end
    else begin
        cxl_lp_ack_r <= #TP cxl_lp_ack_nxt;
    end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// D2H Request Channel Connections
// -------------------------------------------------------------------------------------


localparam D2H_REQ_CH_SIZE = D2H_REQ_SIZE + D2H_REQ_CHK_SIZE;

// TX Channel Message Controller Outputs
logic [D2H_REQ_CH_SIZE-1:0]  s_txtl_dev_d2h_req [0:D2H_REQ_NUM-1];

/*Parametrization*/
//cxl_tl_buff_array_d2h_req signal replaces cxl_tl_buff[0|1]_ch[0 ... 4]_d2h_req, each of those signals were D2H_REQ_CH_SIZE width.
//D2H_REQ_IFNUM determines how many buff needed (i.e., how many channel implemented)
//where D2H_REQ_NUM determines how many messages are offloaded to LL (i.e., the channel number)
//Thus the three dimensions:
//D2H_REQ_CH_SIZE: width of a single channel. D2H_REQ_NUM: how many offloaded message per channel. D2H_REQ_IFNUM: how many channel.
//same applies for all added 3D arrays.
logic [D2H_REQ_NUM-1:0][D2H_REQ_CH_SIZE-1:0] cxl_tl_buff_array_d2h_req [D2H_REQ_IFNUM]; //chmsg buffer output
logic [D2H_REQ_NUM-1:0]                      cxl_tl_array_d2h_req_halt [D2H_REQ_IFNUM]; // arbiter halt output
logic [D2H_REQ_NUM-1:0][D2H_REQ_CH_SIZE-1:0] cxl_tl_d2h_req_s;                          // control module data input
logic [D2H_REQ_NUM-1:0]                      cxl_tl_d2h_req_halt_s;                     //control module halt output

// -------------------------------------------------------------------------------------
// D2H Request Buffer
// -------------------------------------------------------------------------------------

generate
for (genvar i =0; i < D2H_REQ_IFNUM; i++) begin : D2H_REQ_BUFFER
DWC_cxl_mem_cache_tx_tl_chmsg_buff
 #(
    .CXL_CHMSG_CREDITS    (CXL_CHI_MAXCREDITS),
    .CXL_CHMSG_NUM        (D2H_REQ_NUM),
    .CXL_CHMSG_WIDTH      (D2H_REQ_CH_SIZE)
) u_d2h_req_buff (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .core_clk             (b_clk.s_core_clk),
    .core_rst_n           (b_clk.s_core_rst_n),
    .pos_core_clk         (pos_core_clk),
    .cxl_chmsg_crd_rst_i  (cxl_cache_crd_rst),
    .cxl_chmsg_en_i       (cxl_cache_crd_ena & ~cfg_dev_mode_cxl),
    .cxl_chmsg_i          ({ b_app_dev_chi.s_cxl_d2h_req_chk[i] , b_app_dev_chi.s_cxl_d2h_req[i]}),
    .cxl_chmsg_halt_i     (cxl_tl_array_d2h_req_halt[i]),
    .cxl_chdata_af_i      (1'b0),
    .cxl_chmsg_pop_valid  (),
    .cxl_chmsg_chid       (),
    .cxl_chmsg_ovflw_o    (dev_cache_req_ovflw_s[i]), 
    .cxl_chmsg_empty_o    (dev_cache_req_empty_s[i]), 
    .cxl_chmsg_o          (cxl_tl_buff_array_d2h_req[i]),
    .cxl_chmsg_crd_o      (b_app_dev_chi.s_cxl_d2h_req_crd[i])
);
end
endgenerate

// -------------------------------------------------------------------------------------
// D2H Request Channel Transaction Layer Controller
// -------------------------------------------------------------------------------------
generate if (D2H_REQ_IFNUM > 1) begin: D2H_REQ_ARB_CTRL  
logic [D2H_REQ_NUM-1:0] cxl_arb_d2h_req_halt;
logic [D2H_REQ_NUM-1:0][D2H_REQ_CH_SIZE-1:0] cxl_arb_arr_d2h_req; //arbiter data output
DWC_cxl_mem_cache_tx_tl_chmsg_arb
 #(
    .CXL_CHMSG_NUM    (D2H_REQ_NUM),
    .CXL_CHMSG_WIDTH  (D2H_REQ_CH_SIZE),
    .CXL_CHANNEL_NUM  (D2H_REQ_IFNUM)
) u_d2h_req_arb (
    .core_clk               (b_clk.s_core_clk),
    .core_rst_n             (b_clk.s_core_rst_n),
    .cxl_arb_chmsg_i        (cxl_tl_buff_array_d2h_req),
    .cxl_arb_chmsg_halt_i   (cxl_arb_d2h_req_halt),
    .cxl_arb_chmsg_halt_o   (cxl_tl_array_d2h_req_halt),
    .cxl_arb_chmsg_o        (cxl_arb_arr_d2h_req) 
);

assign cxl_tl_d2h_req_s = cxl_arb_arr_d2h_req;
assign cxl_arb_d2h_req_halt = cxl_tl_d2h_req_halt_s;
end
else begin:  D2H_REQ_CTRL
//D2H_REQ_IFNUM = 1

assign cxl_tl_d2h_req_s = cxl_tl_buff_array_d2h_req[0];
//Connecting halt output of control module to halt_i[0] of the channel message buffer because this is what the else part indicates
assign cxl_tl_array_d2h_req_halt[0] = cxl_tl_d2h_req_halt_s;

end
endgenerate

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( D2H_REQ_NUM     ),
    .CXL_CHMSG_WIDTH     ( D2H_REQ_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0            )
) u_d2h_req_regout (
    .core_clk            ( b_clk.s_core_clk               ),
    .core_rst_n          ( b_clk.s_core_rst_n             ),
    .cxl_tl_chmsg_vld_i  ( '0                             ),
    .cxl_tl_chmsg_i      ( cxl_tl_d2h_req_s               ),
    .cxl_ll_chmsg_halt_i ( b_txtl_dev.s_cxl_d2h_req_halt  ),
    .cxl_ll_chmsg_o      ( s_txtl_dev_d2h_req             ),
    .cxl_tl_chmsg_halt_o ( cxl_tl_d2h_req_halt_s          )
);

generate 
for (genvar i =0; i<D2H_REQ_NUM; i++) begin: D2H_REQ_LL
  assign { b_txtl_rasdp.s_cxl_d2h_req_chk[i] , b_txtl_dev.s_cxl_d2h_req[i]} = s_txtl_dev_d2h_req[i];
end
endgenerate





// -------------------------------------------------------------------------------------
// D2H Response Parametrized Channel Connections
// -------------------------------------------------------------------------------------
localparam D2H_RESP_CH_SIZE = D2H_RESP_SIZE + D2H_RESP_CHK_SIZE;

// TX Channel Message Controller Outputs
logic [D2H_RESP_CH_SIZE-1:0]                    s_txtl_dev_d2h_rsp [0:D2H_RESP_NUM-1];

logic [D2H_RESP_NUM-1:0] [D2H_RESP_CH_SIZE-1:0] cxl_tl_arr_d2h_rsp [D2H_RESP_IFNUM];
logic [D2H_RESP_NUM-1:0]                        cxl_tl_arr_d2h_rsp_halt [D2H_RESP_IFNUM];

logic [D2H_RESP_NUM-1:0] [D2H_RESP_CH_SIZE-1:0] cxl_tl_d2h_rsp_s;       //control module input data
logic [D2H_RESP_NUM-1:0]                        cxl_tl_d2h_rsp_halt_s;  //control module output halt

// -------------------------------------------------------------------------------------
// D2H Response Channel Buffer
// -------------------------------------------------------------------------------------
generate
for (genvar i =0; i < D2H_RESP_IFNUM; i++) begin : D2H_RSP_BUFFER
DWC_cxl_mem_cache_tx_tl_chmsg_buff
 #(
    .CXL_CHMSG_CREDITS    (CXL_CHI_MAXCREDITS),
    .CXL_CHMSG_NUM        (D2H_RESP_NUM),
    .CXL_CHMSG_WIDTH      (D2H_RESP_CH_SIZE)
) u_d2h_rsp_buff (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .core_clk             (b_clk.s_core_clk),
    .core_rst_n           (b_clk.s_core_rst_n),
    .pos_core_clk         (pos_core_clk),
    .cxl_chmsg_crd_rst_i  (cxl_cache_crd_rst),
    .cxl_chmsg_en_i       (cxl_cache_crd_ena & ~cfg_dev_mode_cxl),
    .cxl_chmsg_i          ({ b_app_dev_chi.s_cxl_d2h_resp_chk[i] , b_app_dev_chi.s_cxl_d2h_resp[i]}),
    .cxl_chmsg_halt_i     (cxl_tl_arr_d2h_rsp_halt[i]),
    .cxl_chdata_af_i      (1'b0),
    .cxl_chmsg_pop_valid  (),
    .cxl_chmsg_chid       (),
    .cxl_chmsg_ovflw_o    (dev_cache_rsp_ovflw_s[i]),
    .cxl_chmsg_empty_o    (dev_cache_rsp_empty_s[i]),
    .cxl_chmsg_o          (cxl_tl_arr_d2h_rsp[i]),
    .cxl_chmsg_crd_o      (b_app_dev_chi.s_cxl_d2h_resp_crd[i])
);
end 
endgenerate
// -------------------------------------------------------------------------------------
// D2H Response Channel Transaction Layer Controller
// -------------------------------------------------------------------------------------

generate if (D2H_RESP_IFNUM > 1) begin: D2H_RSP_ARB_CTRL 
logic [D2H_RESP_NUM-1:0][D2H_RESP_CH_SIZE-1:0]  cxl_arb_arr_d2h_rsp;
logic [D2H_RESP_NUM-1:0]      cxl_arb_d2h_rsp_halt;

DWC_cxl_mem_cache_tx_tl_chmsg_arb
 #(
    .CXL_CHMSG_NUM    (D2H_RESP_NUM),
    .CXL_CHMSG_WIDTH  (D2H_RESP_CH_SIZE),
    .CXL_CHANNEL_NUM  (D2H_RESP_IFNUM)
) u_d2h_rsp_arb (
    .core_clk               (b_clk.s_core_clk),
    .core_rst_n             (b_clk.s_core_rst_n),
    .cxl_arb_chmsg_i        (cxl_tl_arr_d2h_rsp),
    .cxl_arb_chmsg_halt_i   (cxl_arb_d2h_rsp_halt),
    .cxl_arb_chmsg_halt_o   (cxl_tl_arr_d2h_rsp_halt),
    .cxl_arb_chmsg_o        (cxl_arb_arr_d2h_rsp) 
);

assign cxl_tl_d2h_rsp_s  = cxl_arb_arr_d2h_rsp;
assign cxl_arb_d2h_rsp_halt = cxl_tl_d2h_rsp_halt_s;

end
else begin: D2H_RSP_CTRL

assign cxl_tl_d2h_rsp_s  = cxl_tl_arr_d2h_rsp[0];
assign cxl_tl_arr_d2h_rsp_halt[0] = cxl_tl_d2h_rsp_halt_s;

end
endgenerate

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( D2H_RESP_NUM     ),
    .CXL_CHMSG_WIDTH     ( D2H_RESP_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0             )
) u_d2h_rsp_regout (
    .core_clk            ( b_clk.s_core_clk               ),
    .core_rst_n          ( b_clk.s_core_rst_n             ),
    .cxl_tl_chmsg_vld_i  ( '0                             ),
    .cxl_tl_chmsg_i      ( cxl_tl_d2h_rsp_s               ),
    .cxl_ll_chmsg_halt_i ( b_txtl_dev.s_cxl_d2h_rsp_halt  ),
    .cxl_ll_chmsg_o      ( s_txtl_dev_d2h_rsp             ),
    .cxl_tl_chmsg_halt_o ( cxl_tl_d2h_rsp_halt_s          )
);

generate 
for (genvar i =0; i<D2H_RESP_NUM; i++) begin: D2H_RSP_LL
  assign { b_txtl_rasdp.s_cxl_d2h_rsp_chk[i] , b_txtl_dev.s_cxl_d2h_rsp[i]} = s_txtl_dev_d2h_rsp[i];
end
endgenerate







// -------------------------------------------------------------------------------------
// D2H Data Channel Parametrization Connections
// -------------------------------------------------------------------------------------
  localparam D2H_HDR_CH_SIZE = D2H_DHDR_SIZE  + D2H_DHDR_CHK_SIZE;
localparam D2H_BE_CH_SIZE  = D2H_DBE_SIZE + D2H_DBE_CHK_SIZE;
logic                        cxl_d2h_data_af_s;
// TX Channel Message Controller Outputs
logic [D2H_HDR_CH_SIZE-1:0]  s_txtl_dev_d2h_hdr [0:D2H_DATA_NUM-1];
logic [D2H_DATA_NUM-1:0][D2H_HDR_CH_SIZE-1:0]  cxl_tl_arr_d2h_hdr;
logic [D2H_DATA_NUM-1:0]  cxl_tl_arr_d2h_hdr_halt ;
logic s_cxl_d2h_be_vld_n;

// -------------------------------------------------------------------------------------
// D2H Data Channel Header Buffer
// -------------------------------------------------------------------------------------
assign s_cxl_d2h_be_vld_n = &b_app_dev_chi.s_cxl_d2h_data[0][(D2H_DBE_SIZE + D2H_DHDR_SIZE - 1) -: D2H_DBE_SIZE];

DWC_cxl_mem_cache_tx_tl_chmsg_buff
 #(
    .CXL_CHMSG_CREDITS    (CXL_CHI_MAXCREDITS),
    .CXL_CHMSG_NUM        (D2H_DATA_NUM),
    .CXL_CHMSG_WIDTH      (D2H_HDR_CH_SIZE)
) u_d2h_hdr_buff (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .core_clk             (b_clk.s_core_clk),
    .core_rst_n           (b_clk.s_core_rst_n),
    .pos_core_clk         (pos_core_clk),
    .cxl_chmsg_crd_rst_i  (cxl_cache_crd_rst),
    .cxl_chmsg_en_i       (cxl_cache_crd_ena & ~cfg_dev_mode_cxl),
    .cxl_chmsg_i          ({ b_app_dev_chi.s_cxl_d2h_data_chk[0][D2H_DHDR_CHK_SIZE-1:0] , b_app_dev_chi.s_cxl_d2h_data[0][D2H_DHDR_SIZE-1:0]}),
    .cxl_chmsg_halt_i     (cxl_tl_arr_d2h_hdr_halt),
    .cxl_chdata_af_i      (cxl_d2h_data_af_s),
    .cxl_chmsg_pop_valid  (),
    .cxl_chmsg_chid       (), 
    .cxl_chmsg_ovflw_o    (dev_cache_hdr_ovflw_s[0]),
    .cxl_chmsg_empty_o    (dev_cache_hdr_empty_s[0]),
    .cxl_chmsg_o          (cxl_tl_arr_d2h_hdr),
    .cxl_chmsg_crd_o      (b_app_dev_chi.s_cxl_d2h_data_crd[0])
);

// -------------------------------------------------------------------------------------
// D2H Data Channel Transaction Layer Controller
// -------------------------------------------------------------------------------------

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( D2H_DATA_NUM    ),
    .CXL_CHMSG_WIDTH     ( D2H_HDR_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0            )
) u_d2h_hdr_regout (
    .core_clk            ( b_clk.s_core_clk               ),
    .core_rst_n          ( b_clk.s_core_rst_n             ),
    .cxl_tl_chmsg_vld_i  ( '0                             ),
    .cxl_tl_chmsg_i      ( cxl_tl_arr_d2h_hdr             ),
    .cxl_ll_chmsg_halt_i ( b_txtl_dev.s_cxl_d2h_hdr_halt  ),
    .cxl_ll_chmsg_o      ( s_txtl_dev_d2h_hdr             ),
    .cxl_tl_chmsg_halt_o ( cxl_tl_arr_d2h_hdr_halt        )
);


generate 
for (genvar i =0; i<D2H_DATA_NUM; i++) begin: D2H_HDR_LL
  assign b_txtl_dev.s_cxl_d2h_hdr[i] = s_txtl_dev_d2h_hdr[i][D2H_DHDR_SIZE-1 :0]; 
end 
endgenerate

// -------------------------------------------------------------------------------------
// D2H Data Channel Data Buffer
// -------------------------------------------------------------------------------------
localparam D2H_DATA_CH_SIZE = D2H_DDATA_SIZE + D2H_DDATA_CHK_SIZE;
localparam D2H_DATA_BE_CH_SIZE = D2H_DDATA_SIZE + D2H_DBE_SIZE + D2H_DDATA_CHK_SIZE + D2H_DBE_CHK_SIZE;
localparam D2H_DATA_OUT_NUM = D2H_DDATA_NUM + (D2H_DATA_NUM - D2H_DDATA_NUM);
logic [D2H_DATA_BE_CH_SIZE-1:0]                         s_cxl_d2h_data_be      [0:D2H_DATA_IFNUM-1];
logic [D2H_DATA_BE_CH_SIZE-1:0]                         s_txtl_dev_d2h_data_be [0:D2H_DATA_OUT_NUM-1];
logic [D2H_BE_CH_SIZE-1:0]                              s_txtl_dev_d2h_be      [0:D2H_DATA_OUT_NUM-1];
logic [D2H_DATA_OUT_NUM-1:0][D2H_DATA_BE_CH_SIZE-1:0]   s_txtl_dev_buff_d2h_data_be ;
logic [D2H_DDATA_NUM-1:0]                               s_txtl_dev_buff_d2h_data_be_vld ;
logic [D2H_DDATA_NUM-1:0]                               s_txtl_dev_buff_d2h_data_be_halt ;

assign s_cxl_d2h_data_be[0] = { b_app_dev_chi.s_cxl_d2h_data_chk[0][(D2H_DBE_CHK_SIZE + D2H_DHDR_CHK_SIZE - 1) -: D2H_DBE_CHK_SIZE ],   // BE protection bits
                                b_app_dev_chi.s_cxl_d2h_data_chk[0][D2H_DATA_CHK_SIZE-1 -:  D2H_DDATA_CHK_SIZE],                        // data protection bits
                                b_app_dev_chi.s_cxl_d2h_data[0][(D2H_DBE_SIZE + D2H_DHDR_SIZE - 1) -: D2H_DBE_SIZE],                    // BE 
                                b_app_dev_chi.s_cxl_d2h_data[0][(D2H_DATA_SIZE-1) -: D2H_DDATA_SIZE]};                                  // data 
 
DWC_cxl_mem_cache_tx_tl_chdata_buff
 #(
    .CXL_CHDATA_CREDITS ( CXL_CHI_MAXCREDITS  ),
    .CXL_CHDATA_MSGNUM  ( D2H_DATA_NUM        ),
    .CXL_CHDATA_PATH    ( D2H_DDATA_NUM       ),
    .CXL_CHDATA_WIDTH   ( D2H_DATA_BE_CH_SIZE ),
    .CXL_CHRAM_DATAW    ( HD_DATAW            ),
    .CXL_CHRAM_ADDRW    ( HD_DATA_RAM_ADDRW   ),
    .CXL_CHRAM_DEPTH    ( HD_DATA_RAM_DEPTH   )
) u_d2h_data_buff (
    .cxl_clk            ( b_clk.s_cxl_clk                               ),
    .cxl_rst_n          ( b_clk.s_cxl_rst_n                             ),
    .core_clk           ( b_clk.s_core_clk                              ),
    .core_rst_n         ( b_clk.s_core_rst_n                            ),
    .pos_core_clk       ( pos_core_clk                                  ),
    .cxl_chdata_vld_i   ( b_app_dev_chi.s_cxl_d2h_data[0][D2H_HDR_VLD]  ),
    .cxl_chdata_i       ( s_cxl_d2h_data_be[0]                          ),
    .cxl_chdata_halt_i  ( s_txtl_dev_buff_d2h_data_be_halt              ),
    .cxl_ram_rdata      ( b_cxl_slv_d2h_data_ram.s_ram_rdata            ),
    .cxl_ram_re         ( b_cxl_slv_d2h_data_ram.s_ram_rd               ),
    .cxl_ram_raddr      ( b_cxl_slv_d2h_data_ram.s_ram_rd_addr          ),
    .cxl_ram_we         ( b_cxl_slv_d2h_data_ram.s_ram_we               ),
    .cxl_ram_waddr      ( b_cxl_slv_d2h_data_ram.s_ram_wr_addr          ),
    .cxl_ram_wdata      ( b_cxl_slv_d2h_data_ram.s_ram_wdata            ),
    .cxl_chdata_ovflw_o ( dev_cache_data_ovflw_s[0]                     ),
    .cxl_chdata_empty_o ( dev_cache_data_empty_s[0]                     ),
    .cxl_chdata_af_o    ( cxl_d2h_data_af_s                             ),
    .cxl_chdata_vld_o   ( s_txtl_dev_buff_d2h_data_be_vld               ),
    .cxl_chdata_o       ( s_txtl_dev_buff_d2h_data_be                   )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_DATA      ( 1'b1                ),
    .CXL_CHMSG_NUM       ( D2H_DATA_OUT_NUM    ),
    .CXL_CHMSG_VLD_NUM   ( D2H_DDATA_NUM       ),
    .CXL_CHMSG_WIDTH     ( D2H_DATA_BE_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0                )
) u_d2h_data_regout (
    .core_clk            ( b_clk.s_core_clk                 ),
    .core_rst_n          ( b_clk.s_core_rst_n               ),
    .cxl_tl_chmsg_i      ( s_txtl_dev_buff_d2h_data_be      ),
    .cxl_tl_chmsg_vld_i  ( s_txtl_dev_buff_d2h_data_be_vld  ),
    .cxl_ll_chmsg_halt_i ( b_txtl_dev.s_cxl_d2h_data_halt   ),
    .cxl_ll_chmsg_o      ( s_txtl_dev_d2h_data_be           ),
    .cxl_ll_chmsg_vld_o  ( b_txtl_dev.s_cxl_d2h_data_vld    ),
    .cxl_tl_chmsg_halt_o ( s_txtl_dev_buff_d2h_data_be_halt )
);


generate
  for (genvar i=0; i<D2H_DDATA_NUM; i++ ) begin: D2H_DATA_LL
    assign b_txtl_dev.s_cxl_d2h_data[i] = s_txtl_dev_d2h_data_be[i][D2H_DDATA_SIZE-1:0];
    assign b_txtl_dev.s_cxl_d2h_be[i]   = s_txtl_dev_d2h_be[i][D2H_DBE_SIZE-1 :0];
  end
endgenerate
generate
  for (genvar i=0; i<D2H_DATA_OUT_NUM; i++ ) begin: D2H_DATA_BE
    assign s_txtl_dev_d2h_be[i] = { s_txtl_dev_d2h_data_be[i][D2H_DATA_BE_CH_SIZE-1 -: D2H_DBE_CHK_SIZE] , s_txtl_dev_d2h_data_be[i][(D2H_DDATA_SIZE + D2H_DBE_SIZE -1 ) -: D2H_DBE_SIZE]};
  end
endgenerate
generate
  for (genvar i=0; i<D2H_DATA_NUM; i++ ) begin: D2H_DATA_RASDP
    assign b_txtl_rasdp.s_cxl_d2h_data_chk[i] = s_txtl_dev_d2h_data_be[i][(D2H_DATA_BE_CH_SIZE - D2H_DBE_CHK_SIZE -1) -: D2H_DDATA_CHK_SIZE];
    assign b_txtl_rasdp.s_cxl_d2h_data_arr[i] = s_txtl_dev_d2h_data_be[i][D2H_DDATA_SIZE -1:0];
    assign b_txtl_rasdp.s_cxl_d2h_be_chk[i]   = s_txtl_dev_d2h_be[i][(D2H_BE_CH_SIZE-1) -: D2H_DBE_CHK_SIZE];
    assign b_txtl_rasdp.s_cxl_d2h_be_arr[i]   = s_txtl_dev_d2h_be[i][D2H_DBE_SIZE-1 : 0];
    assign b_txtl_rasdp.s_cxl_d2h_hdr_chk[i]  = s_txtl_dev_d2h_hdr[i][(D2H_HDR_CH_SIZE-1) -: D2H_DHDR_CHK_SIZE];  
  end
endgenerate


generate
  for (genvar i =0; i<D2H_DATA_NUM; i++) begin: D2H_BE_VLD
    assign b_txtl_dev.s_cxl_d2h_be_vld_n[i] =  '0; //to avoid undriven output ports. 
  end
endgenerate  
  





// -------------------------------------------------------------------------------------
// S2M NDR Response Parametrized Channel Connections
// -------------------------------------------------------------------------------------
localparam S2M_NDR_CH_SIZE = S2M_NDR_SIZE + S2M_NDR_CHK_SIZE;

// TX Channel Message Controller Outputs

logic [S2M_NDR_NUM-1:0][S2M_NDR_CH_SIZE-1:0]  cxl_tl_s2m_ndr_s;                     //chmsg control input data
logic [S2M_NDR_CH_SIZE-1:0]                   s_txtl_dev_s2m_ndr [0:S2M_NDR_NUM-1]; //chmsg ctrl output --> LL
logic [S2M_NDR_NUM-1:0]                       cxl_tl_s2m_ndr_halt_s;                // chmsg ctrl module output halt

// -------------------------------------------------------------------------------------
// S2M NDR Response Channel Transaction Layer Controller
// -------------------------------------------------------------------------------------



logic [S2M_NDR_NUM-1:0]  cxl_tl_arr_s2m_ndr_halt[S2M_NDR_IFNUM]; //output halt from fifo control/arbiter to chmsg buffers
logic [S2M_NDR_NUM-1:0][S2M_NDR_CH_SIZE-1:0]  cxl_arb_arr_s2m_ndr; //output from fifo ctrl/arbiter to chmsg ctrl
logic [S2M_NDR_NUM-1:0]      cxl_arb_s2m_ndr_halt; //input halt from LL to fifo ctrl / arbiter
localparam S2M_NDR_IFNUM_LOG = (S2M_NDR_IFNUM == 1) ? 1 : $clog2(S2M_NDR_IFNUM);
localparam S2M_NDR_CH_SIZE_ADJ = S2M_NDR_CH_SIZE + S2M_NDR_IFNUM_LOG;
logic [S2M_NDR_CH_SIZE_ADJ-1 : 0] cxl_s2m_ndr_chmsg_i [S2M_NDR_IFNUM]; // output from fifo control, input to chmsg buffers
logic [S2M_NDR_NUM-1:0][S2M_NDR_CH_SIZE_ADJ-1:0]  cxl_tl_arr_s2m_ndr[S2M_NDR_IFNUM]; // output from chmsg buffers, input to fifo control
logic cxl_s2m_ndr_pop_valid [S2M_NDR_IFNUM];
logic [S2M_NDR_IFNUM_LOG-1:0] cxl_s2m_ndr_chid [S2M_NDR_IFNUM];
logic  [S2M_NDR_CH_SIZE-1 : 0] cxl_s2m_ndr_fifoctrl_data_i [0 : S2M_NDR_IFNUM-1];
// -------------------------------------------------------------------------------------
// S2M NDR Response Channel Buffer
// -------------------------------------------------------------------------------------
generate
for (genvar i =0; i < S2M_NDR_IFNUM; i++) begin : S2M_NDR_BUFFER_ORD
DWC_cxl_mem_cache_tx_tl_chmsg_buff
 #(
    .CXL_CHMSG_CREDITS    (CXL_CHI_MAXCREDITS),
    .CXL_CHMSG_NUM        (S2M_NDR_NUM),
    .CXL_CHANNEL_NUM      (S2M_NDR_IFNUM),
    .CXL_CHMSG_WIDTH      (S2M_NDR_CH_SIZE_ADJ)
) u_s2m_ndr_buff (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .core_clk             (b_clk.s_core_clk),
    .core_rst_n           (b_clk.s_core_rst_n),
    .pos_core_clk         (pos_core_clk),
    .cxl_chmsg_crd_rst_i  (cxl_mem_crd_rst),
    .cxl_chmsg_en_i       (cxl_s2m_crd_ena),
    .cxl_chmsg_i          (cxl_s2m_ndr_chmsg_i[i]),
    .cxl_chmsg_halt_i     (cxl_tl_arr_s2m_ndr_halt[i]),
    .cxl_chdata_af_i      (1'b0),
    .cxl_chmsg_pop_valid  (cxl_s2m_ndr_pop_valid[i]),
    .cxl_chmsg_chid       (cxl_s2m_ndr_chid[i]),
    .cxl_chmsg_ovflw_o    (dev_mem_ndr_ovflw_s[i]), 
    .cxl_chmsg_empty_o    (dev_mem_ndr_empty_s[i]),
    .cxl_chmsg_o          (cxl_tl_arr_s2m_ndr[i]),
    .cxl_chmsg_crd_o      ()
);
assign cxl_s2m_ndr_fifoctrl_data_i[i]= { b_app_dev_chi.s_cxl_s2m_ndr_chk[i] , b_app_dev_chi.s_cxl_s2m_ndr[i]};
end 
endgenerate

DWC_cxl_mem_cache_tx_tl_fifo_ctrl
 #(
    .CXL_CHMSG_NUM(S2M_NDR_NUM),
    .CXL_CHMSG_WIDTH(S2M_NDR_CH_SIZE),
    .CXL_CHANNEL_NUM(S2M_NDR_IFNUM),
    .CXL_CHMSG_CREDITS(CXL_CHI_MAXCREDITS)
) u_s2m_ndr_fifo_ctrl (
        .cxl_clk(b_clk.s_cxl_clk),
        .cxl_rst_n(b_clk.s_cxl_rst_n),
        .core_clk(b_clk.s_core_clk),
        .core_rst_n(b_clk.s_core_rst_n),
    // -------------------------------------------------------------------------------------
    // Application Layer Connections
    // -------------------------------------------------------------------------------------    
        .cxl_fifoctrl_data_i(cxl_s2m_ndr_fifoctrl_data_i), //Input Data from Application Layer
        .cxl_fifoctrl_crd_o(b_app_dev_chi.s_cxl_s2m_ndr_crd), //Output Credit to Application Layer
    // -------------------------------------------------------------------------------------
    // Credit Control Connections
    // ------------------------------------------------------------------------------------- 
        .cxl_chmsg_en_i(cxl_s2m_crd_ena),
        .cxl_chmsg_crd_rst_i(cxl_mem_crd_rst),
        .cxl_chmsg_pop_valid_i(cxl_s2m_ndr_pop_valid), // Indicates if data is written into offloading fifo of the concerned channel message buffer
        .cxl_chmsg_chid(cxl_s2m_ndr_chid), //channel ID of the popped messsge, represents which channel the application intended to push data in,
    //                                                                     and used to return credits to that channel
    // -------------------------------------------------------------------------------------
    // Channel Message Buffers Connections
    // ------------------------------------------------------------------------------------- 
        .cxl_chmsg_data_o(cxl_s2m_ndr_chmsg_i), //Output data in a RR fashion to channel message buffers
        .cxl_chmsg_data_i (cxl_tl_arr_s2m_ndr), //Input data from channel message buffers 
        .cxl_chmsg_halt_o (cxl_tl_arr_s2m_ndr_halt), //output halt to different channel message buffers
    // -------------------------------------------------------------------------------------
    // Interface with Link Layer
    // ------------------------------------------------------------------------------------- 
        .cxl_fifoctrl_halt_i(cxl_arb_s2m_ndr_halt), //input halt from link layer
        .cxl_fifoctrl_data_o(cxl_arb_arr_s2m_ndr) //output data to link layer
);



assign cxl_tl_s2m_ndr_s     = cxl_arb_arr_s2m_ndr;
assign cxl_arb_s2m_ndr_halt = cxl_tl_s2m_ndr_halt_s;

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( S2M_NDR_NUM     ),
    .CXL_CHMSG_WIDTH     ( S2M_NDR_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0            )
) u_s2m_ndr_regout (
    .core_clk            ( b_clk.s_core_clk               ),
    .core_rst_n          ( b_clk.s_core_rst_n             ),
    .cxl_tl_chmsg_vld_i  ( '0                             ),
    .cxl_tl_chmsg_i      ( cxl_tl_s2m_ndr_s               ),
    .cxl_ll_chmsg_halt_i ( b_txtl_dev.s_cxl_s2m_ndr_halt  ),
    .cxl_ll_chmsg_o      ( s_txtl_dev_s2m_ndr             ),
    .cxl_tl_chmsg_halt_o ( cxl_tl_s2m_ndr_halt_s          )
);
// -------------------------------------------------------------------------------------
generate 
for (genvar i =0; i<S2M_NDR_NUM; i++) begin: S2M_NDR_LL
assign { b_txtl_rasdp.s_cxl_s2m_ndr_chk[i] , b_txtl_dev.s_cxl_s2m_ndr[i]} = s_txtl_dev_s2m_ndr[i];
end
endgenerate






// -------------------------------------------------------------------------------------
// S2M DRC Response Parametrized Channel Connections
// -------------------------------------------------------------------------------------
localparam S2M_HDR_CH_SIZE = S2M_DHDR_SIZE + S2M_DHDR_CHK_SIZE;
logic                        cxl_s2m_data_af_s;
logic [S2M_DATA_NUM-1:0][S2M_HDR_CH_SIZE-1:0]  cxl_tl_arr_s2m_drc;
logic [S2M_DATA_NUM-1:0]                       cxl_tl_arr_s2m_drc_halt;
// TX Channel Message Controller Outputs
logic [S2M_HDR_CH_SIZE-1:0]  s_txtl_dev_s2m_drc [0:S2M_DATA_NUM-1];

// -------------------------------------------------------------------------------------
// S2M DRC Response Channel Header Buffer
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_tx_tl_chmsg_buff
 #(
    .CXL_CHMSG_CREDITS (CXL_CHI_MAXCREDITS),
    .CXL_CHMSG_NUM     (S2M_DATA_NUM),
    .CXL_CHMSG_WIDTH   (S2M_HDR_CH_SIZE)
) u_s2m_hdr_buff (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .core_clk             (b_clk.s_core_clk),
    .core_rst_n           (b_clk.s_core_rst_n),
    .pos_core_clk         (pos_core_clk),
    .cxl_chmsg_crd_rst_i  (cxl_mem_crd_rst),
    .cxl_chmsg_en_i       (cxl_s2m_crd_ena),
    .cxl_chmsg_i          ({ b_app_dev_chi.s_cxl_s2m_drc_chk[0][(S2M_DATA_CHK_SIZE-S2M_DDATA_CHK_SIZE)-1:0] , b_app_dev_chi.s_cxl_s2m_drc[0][S2M_DHDR_SIZE-1:0]}),
    .cxl_chmsg_halt_i     (cxl_tl_arr_s2m_drc_halt),
    .cxl_chdata_af_i      (cxl_s2m_data_af_s),
    .cxl_chmsg_pop_valid  (),
    .cxl_chmsg_chid       (),
    .cxl_chmsg_ovflw_o    (dev_mem_hdr_ovflw_s[0]),
    .cxl_chmsg_empty_o    (dev_mem_hdr_empty_s[0]),
    .cxl_chmsg_o          (cxl_tl_arr_s2m_drc),
    .cxl_chmsg_crd_o      (b_app_dev_chi.s_cxl_s2m_drc_crd[0])
);
// -------------------------------------------------------------------------------------
// S2M DRC Response Channel Transaction Layer Controller
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( S2M_DATA_NUM    ),
    .CXL_CHMSG_WIDTH     ( S2M_HDR_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0            )
) u_s2m_drc_regout (
    .core_clk            ( b_clk.s_core_clk               ),
    .core_rst_n          ( b_clk.s_core_rst_n             ),
    .cxl_tl_chmsg_vld_i  ( '0                             ),
    .cxl_tl_chmsg_i      ( cxl_tl_arr_s2m_drc             ),
    .cxl_ll_chmsg_halt_i ( b_txtl_dev.s_cxl_s2m_hdr_halt  ),
    .cxl_ll_chmsg_o      ( s_txtl_dev_s2m_drc             ),
    .cxl_tl_chmsg_halt_o ( cxl_tl_arr_s2m_drc_halt        )
);
generate
for (genvar i =0; i< S2M_DATA_NUM; i++) begin: S2M_HDR_LL
assign { b_txtl_rasdp.s_cxl_s2m_hdr_chk[i] , b_txtl_dev.s_cxl_s2m_hdr[i]} = s_txtl_dev_s2m_drc[i];
end
endgenerate
// -------------------------------------------------------------------------------------
// S2M DRC Response Channel Data Buffer
// -------------------------------------------------------------------------------------
localparam S2M_DATA_CH_SIZE = S2M_DDATA_SIZE + S2M_DDATA_CHK_SIZE;
localparam S2M_DATA_OUT_NUM = S2M_DDATA_NUM + (S2M_DATA_NUM - S2M_DDATA_NUM);
logic [S2M_DATA_CH_SIZE-1:0]                         cxl_slv_s2m_data_ram_wdata;
logic [S2M_DATA_CH_SIZE-1:0]                         s_txtl_dev_s2m_data [0:S2M_DATA_OUT_NUM-1];
logic [S2M_DATA_OUT_NUM-1:0] [S2M_DATA_CH_SIZE-1:0]  s_txtl_dev_buff_s2m_data ;
logic [S2M_DDATA_NUM-1:0]                            s_txtl_dev_buff_s2m_data_vld ;
logic [S2M_DDATA_NUM-1:0]                            s_txtl_dev_buff_s2m_data_halt ;
logic [S2M_DATA_CH_SIZE-1:0]                         s_txtl_dev_app_s2m_data;
generate
for (genvar i =0; i< S2M_DDATA_NUM; i++) begin: S2M_DATA_LL
assign b_txtl_dev.s_cxl_s2m_data[i] = s_txtl_dev_s2m_data[i][S2M_DDATA_SIZE-1:0];
end
endgenerate


assign s_txtl_dev_app_s2m_data = { b_app_dev_chi.s_cxl_s2m_drc_chk[0][S2M_DATA_CHK_SIZE-1:(S2M_DATA_CHK_SIZE-S2M_DDATA_CHK_SIZE)] , b_app_dev_chi.s_cxl_s2m_drc[0][(S2M_DATA_SIZE-1)-:S2M_DDATA_SIZE]};

DWC_cxl_mem_cache_tx_tl_chdata_buff
 #(
    .CXL_CHDATA_CREDITS ( CXL_CHI_MAXCREDITS ),
    .CXL_CHDATA_MSGNUM  ( S2M_DATA_NUM       ),
    .CXL_CHDATA_PATH    ( S2M_DDATA_NUM      ),
    .CXL_CHDATA_WIDTH   ( S2M_DATA_CH_SIZE   ),
    .CXL_CHRAM_DATAW    ( S2M_DATA_CH_SIZE   ),
    .CXL_CHRAM_ADDRW    ( MS_DATA_RAM_ADDRW  ),
    .CXL_CHRAM_DEPTH    ( MS_DATA_RAM_DEPTH  )
) u_s2m_data_buff (
    .cxl_clk            ( b_clk.s_cxl_clk                                            ),
    .cxl_rst_n          ( b_clk.s_cxl_rst_n                                          ),
    .core_clk           ( b_clk.s_core_clk                                           ),
    .core_rst_n         ( b_clk.s_core_rst_n                                         ),
    .pos_core_clk       ( pos_core_clk                                               ),
    .cxl_chdata_vld_i   ( b_app_dev_chi.s_cxl_s2m_drc[0][S2M_HDR_VLD]                ),
    .cxl_chdata_i       ( s_txtl_dev_app_s2m_data                                    ),
    .cxl_chdata_halt_i  ( s_txtl_dev_buff_s2m_data_halt                              ),
    .cxl_ram_rdata      ( b_cxl_slv_s2m_data_ram.s_ram_rdata[S2M_DATA_CH_SIZE -1 :0] ),
    .cxl_ram_wdata      ( cxl_slv_s2m_data_ram_wdata                                 ),
    .cxl_ram_re         ( b_cxl_slv_s2m_data_ram.s_ram_rd                            ),
    .cxl_ram_raddr      ( b_cxl_slv_s2m_data_ram.s_ram_rd_addr                       ),
    .cxl_ram_we         ( b_cxl_slv_s2m_data_ram.s_ram_we                            ),
    .cxl_ram_waddr      ( b_cxl_slv_s2m_data_ram.s_ram_wr_addr                       ),
    .cxl_chdata_ovflw_o ( dev_mem_data_ovflw_s[0]                                    ),
    .cxl_chdata_empty_o ( dev_mem_data_empty_s[0]                                    ),
    .cxl_chdata_af_o    ( cxl_s2m_data_af_s                                          ),
    .cxl_chdata_vld_o   ( s_txtl_dev_buff_s2m_data_vld                               ),
    .cxl_chdata_o       ( s_txtl_dev_buff_s2m_data                                   )
);
assign  b_cxl_slv_s2m_data_ram.s_ram_wdata = {{M2S_BE_CH_SIZE{1'b0}} , cxl_slv_s2m_data_ram_wdata};
generate
for (genvar i =0; i< S2M_DATA_NUM; i++) begin: S2M_DATA_RASDP
assign {b_txtl_rasdp.s_cxl_s2m_data_chk[i], b_txtl_rasdp.s_cxl_s2m_data_arr[i]} = s_txtl_dev_s2m_data[i];
end
endgenerate


DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_DATA      ( 1'b1             ),
    .CXL_CHMSG_NUM       ( S2M_DATA_OUT_NUM ),
    .CXL_CHMSG_VLD_NUM   ( S2M_DDATA_NUM    ),
    .CXL_CHMSG_WIDTH     ( S2M_DATA_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0             )
) u_s2m_data_regout (
    .core_clk            ( b_clk.s_core_clk                 ),
    .core_rst_n          ( b_clk.s_core_rst_n               ),
    .cxl_tl_chmsg_i      ( s_txtl_dev_buff_s2m_data         ),
    .cxl_tl_chmsg_vld_i  ( s_txtl_dev_buff_s2m_data_vld     ),
    .cxl_ll_chmsg_halt_i ( b_txtl_dev.s_cxl_s2m_data_halt   ),
    .cxl_ll_chmsg_o      ( s_txtl_dev_s2m_data              ),
    .cxl_ll_chmsg_vld_o  ( b_txtl_dev.s_cxl_s2m_data_vld    ),
    .cxl_tl_chmsg_halt_o ( s_txtl_dev_buff_s2m_data_halt    )
);







// -------------------------------------------------------------------------------------
// H2D Response Channel Parametrized Connections
// -------------------------------------------------------------------------------------
localparam H2D_RESP_CH_SIZE = H2D_MSG_CNT_WD + H2D_RESP_SIZE + H2D_RESP_CHK_SIZE;
logic [H2D_RESP_NUM-1:0][H2D_RESP_CH_SIZE-1:0]  cxl_tl_buff_arr_h2d_rsp[H2D_RESP_IFNUM];
logic [H2D_RESP_NUM-1:0]                        cxl_tl_arr_h2d_rsp_halt[H2D_RESP_IFNUM];
logic [H2D_RESP_NUM-1:0][H2D_RESP_CH_SIZE-1:0]  cxl_tl_buff_h2d_rsp_s; // control module input data 
logic [H2D_RESP_NUM-1:0]                        cxl_tl_h2d_rsp_halt_s; // control module output halt

// TX Channel Message Controller Outputs
logic [H2D_RESP_CH_SIZE-1:0]  s_txtl_host_h2d_rsp [0:H2D_RESP_NUM-1];

// -------------------------------------------------------------------------------------
// H2D Response Channel Buffer
// -------------------------------------------------------------------------------------
generate
for (genvar i =0; i < H2D_RESP_IFNUM; i++) begin : H2D_RSP_BUFFER
DWC_cxl_mem_cache_tx_tl_chmsg_buff
 #(
    .CXL_CHMSG_CREDITS    (CXL_CHI_MAXCREDITS),
    .CXL_CHMSG_NUM        (H2D_RESP_NUM),
    .CXL_CHMSG_WIDTH      (H2D_RESP_CH_SIZE)
) u_h2d_rsp_buff (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .core_clk             (b_clk.s_core_clk),
    .core_rst_n           (b_clk.s_core_rst_n),
    .pos_core_clk         (pos_core_clk),
    .cxl_chmsg_crd_rst_i  (cxl_cache_crd_rst),
    .cxl_chmsg_en_i       (cxl_cache_crd_ena & cfg_dev_mode_cxl),
    .cxl_chmsg_i          ({cache_cycle_cnt_r, b_app_host_chi.s_cxl_h2d_resp_chk[i] , b_app_host_chi.s_cxl_h2d_resp[i]}),
    .cxl_chmsg_halt_i     (cxl_tl_arr_h2d_rsp_halt[i]),
    .cxl_chdata_af_i      (1'b0),
    .cxl_chmsg_pop_valid  (),
    .cxl_chmsg_chid       (),
    .cxl_chmsg_ovflw_o    (host_cache_rsp_ovflw_s[i]), 
    .cxl_chmsg_empty_o    (host_cache_rsp_empty_s[i]), 
    .cxl_chmsg_o          (cxl_tl_buff_arr_h2d_rsp[i]),
    .cxl_chmsg_crd_o      (b_app_host_chi.s_cxl_h2d_resp_crd[i])
);
end
endgenerate

// -------------------------------------------------------------------------------------
// H2D Response Channel Transaction Layer Controller
// -------------------------------------------------------------------------------------
generate if (H2D_RESP_IFNUM > 1) begin: H2D_RSP_ARB_CTRL  //TODO: We can generate 2 or 3 H2D IFNUM, this will be resolved with the new arbiter
logic [H2D_RESP_NUM-1:0][H2D_RESP_CH_SIZE-1:0]  cxl_arb_arr_h2d_rsp;
logic [H2D_RESP_NUM-1:0] cxl_arb_h2d_rsp_halt;
DWC_cxl_mem_cache_tx_tl_chmsg_arb
 #(
    .CXL_CHMSG_NUM    (H2D_RESP_NUM),
    .CXL_CHMSG_WIDTH  (H2D_RESP_CH_SIZE),
    .CXL_CHANNEL_NUM  (H2D_RESP_IFNUM)
) u_h2d_rsp_arb (
    .core_clk               (b_clk.s_core_clk),
    .core_rst_n             (b_clk.s_core_rst_n),
    .cxl_arb_chmsg_i        (cxl_tl_buff_arr_h2d_rsp),
    .cxl_arb_chmsg_halt_i   (cxl_arb_h2d_rsp_halt),
    .cxl_arb_chmsg_halt_o   (cxl_tl_arr_h2d_rsp_halt),
    .cxl_arb_chmsg_o        (cxl_arb_arr_h2d_rsp)
);
assign cxl_tl_buff_h2d_rsp_s      = cxl_arb_arr_h2d_rsp;
assign cxl_arb_h2d_rsp_halt       = cxl_tl_h2d_rsp_halt_s;
end
else begin : H2D_RSP_CTRL
assign cxl_tl_buff_h2d_rsp_s      = cxl_tl_buff_arr_h2d_rsp[0];
assign cxl_tl_arr_h2d_rsp_halt[0] = cxl_tl_h2d_rsp_halt_s;
end
endgenerate


DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( H2D_RESP_NUM     ),
    .CXL_CHMSG_WIDTH     ( H2D_RESP_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0             )
) u_h2d_rsp_regout (
    .core_clk            ( b_clk.s_core_clk               ),
    .core_rst_n          ( b_clk.s_core_rst_n             ),
    .cxl_tl_chmsg_vld_i  ( '0                             ),
    .cxl_tl_chmsg_i      ( cxl_tl_buff_h2d_rsp_s          ),
    .cxl_ll_chmsg_halt_i ( b_txtl_host.s_cxl_h2d_rsp_halt ),
    .cxl_ll_chmsg_o      ( s_txtl_host_h2d_rsp            ),
    .cxl_tl_chmsg_halt_o ( cxl_tl_h2d_rsp_halt_s          )
);
generate 
for (genvar i =0; i<H2D_RESP_NUM; i++) begin: H2d_RSP_LL
assign {b_txtl_host.s_cxl_h2d_rsp_cnt[i] , b_txtl_rasdp.s_cxl_h2d_rsp_chk[i] , b_txtl_host.s_cxl_h2d_rsp[i]} = s_txtl_host_h2d_rsp[i];
end
endgenerate
// -------------------------------------------------------------------------------------




// -------------------------------------------------------------------------------------
// H2D Request Parametrized Channel Connections
// -------------------------------------------------------------------------------------
localparam H2D_REQ_CH_SIZE = H2D_MSG_CNT_WD + H2D_REQ_SIZE + H2D_REQ_CHK_SIZE;

// TX Channel Message Controller Outputs
logic [H2D_REQ_CH_SIZE-1:0]                   s_txtl_host_h2d_req [0:H2D_REQ_NUM-1];
logic [H2D_REQ_NUM-1:0][H2D_REQ_CH_SIZE-1:0]  cxl_tl_arr_h2d_req [H2D_REQ_IFNUM];
logic [H2D_REQ_NUM-1:0]                       cxl_tl_arr_h2d_req_halt[H2D_REQ_IFNUM];
logic [H2D_REQ_NUM-1:0][H2D_REQ_CH_SIZE-1:0]  cxl_tl_h2d_req_s;       //control module data input
logic [H2D_REQ_NUM-1:0]                       cxl_tl_h2d_req_halt_s;  //control module halt output

// -------------------------------------------------------------------------------------
// H2D Request Channel Buffer
// -------------------------------------------------------------------------------------
generate
for (genvar i =0; i < H2D_REQ_IFNUM; i++) begin : H2D_REQ_BUFFER
DWC_cxl_mem_cache_tx_tl_chmsg_buff
 #(
    .CXL_CHMSG_CREDITS    ( CXL_CHI_MAXCREDITS ),
    .CXL_CHMSG_NUM        ( H2D_REQ_NUM        ),
    .CXL_CHMSG_WIDTH      ( H2D_REQ_CH_SIZE    )
) u_h2d_req_buff (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .core_clk             (b_clk.s_core_clk),
    .core_rst_n           (b_clk.s_core_rst_n),
    .pos_core_clk         (pos_core_clk),
    .cxl_chmsg_crd_rst_i  (cxl_cache_crd_rst),
    .cxl_chmsg_en_i       (cxl_cache_crd_ena & cfg_dev_mode_cxl),
    .cxl_chmsg_i          ({cache_cycle_cnt_r, b_app_host_chi.s_cxl_h2d_req_chk[i] , b_app_host_chi.s_cxl_h2d_req[i]}),
    .cxl_chmsg_halt_i     (cxl_tl_arr_h2d_req_halt[i]),
    .cxl_chdata_af_i      (1'b0),
    .cxl_chmsg_pop_valid  (),
    .cxl_chmsg_chid       (),
    .cxl_chmsg_ovflw_o    (host_cache_req_ovflw_s[i]),
    .cxl_chmsg_empty_o    (host_cache_req_empty_s[i]),
    .cxl_chmsg_o          (cxl_tl_arr_h2d_req[i]),
    .cxl_chmsg_crd_o      (b_app_host_chi.s_cxl_h2d_req_crd[i])
);
end 
endgenerate

// -------------------------------------------------------------------------------------
// H2D Request Channel Transaction Layer Controller
// -------------------------------------------------------------------------------------

generate if (H2D_REQ_IFNUM > 1) begin: H2D_REQ_ARB_CTRL  
logic [H2D_REQ_NUM-1:0][H2D_REQ_CH_SIZE-1:0]  cxl_arb_arr_h2d_req;
logic [H2D_REQ_NUM-1:0]      cxl_arb_h2d_req_halt;
DWC_cxl_mem_cache_tx_tl_chmsg_arb
 #(
    .CXL_CHMSG_NUM    (H2D_REQ_NUM),
    .CXL_CHMSG_WIDTH  (H2D_REQ_CH_SIZE),
    .CXL_CHANNEL_NUM  (H2D_REQ_IFNUM)
) u_h2d_req_arb (
    .core_clk               (b_clk.s_core_clk),
    .core_rst_n             (b_clk.s_core_rst_n),
    .cxl_arb_chmsg_i        (cxl_tl_arr_h2d_req),
    .cxl_arb_chmsg_halt_i   (cxl_arb_h2d_req_halt),
    .cxl_arb_chmsg_halt_o   (cxl_tl_arr_h2d_req_halt),
    .cxl_arb_chmsg_o        (cxl_arb_arr_h2d_req)
);
assign cxl_tl_h2d_req_s     = cxl_arb_arr_h2d_req;
assign cxl_arb_h2d_req_halt = cxl_tl_h2d_req_halt_s;


end
else begin: H2D_REQ_CTRL


assign cxl_tl_h2d_req_s           = cxl_tl_arr_h2d_req[0];
assign cxl_tl_arr_h2d_req_halt[0] = cxl_tl_h2d_req_halt_s;

end
endgenerate

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( H2D_REQ_NUM     ),
    .CXL_CHMSG_WIDTH     ( H2D_REQ_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0            )
) u_h2d_req_regout (
    .core_clk            ( b_clk.s_core_clk               ),
    .core_rst_n          ( b_clk.s_core_rst_n             ),
    .cxl_tl_chmsg_vld_i  ( '0                             ),
    .cxl_tl_chmsg_i      ( cxl_tl_h2d_req_s               ),
    .cxl_ll_chmsg_halt_i ( b_txtl_host.s_cxl_h2d_req_halt ),
    .cxl_ll_chmsg_o      ( s_txtl_host_h2d_req            ),
    .cxl_tl_chmsg_halt_o ( cxl_tl_h2d_req_halt_s          )
);

generate 
for (genvar i =0; i<H2D_REQ_NUM; i++) begin: H2D_REQ_LL
assign {b_txtl_host.s_cxl_h2d_req_cnt[i] , b_txtl_rasdp.s_cxl_h2d_req_chk[i] , b_txtl_host.s_cxl_h2d_req[i]} = s_txtl_host_h2d_req[i];
end
endgenerate





// -------------------------------------------------------------------------------------
// H2D Data Parametrized Channel Connections
// -------------------------------------------------------------------------------------
localparam H2D_HDR_CH_SIZE = H2D_DHDR_SIZE + H2D_DHDR_CHK_SIZE;
logic                        cxl_h2d_data_af_s;
// TX Channel Message Controller Outputs
logic [H2D_HDR_CH_SIZE-1:0]  s_txtl_host_h2d_hdr [0:H2D_DATA_NUM-1];
logic [H2D_DATA_NUM-1:0][H2D_HDR_CH_SIZE-1:0]  cxl_tl_arr_h2d_hdr;
logic [H2D_DATA_NUM-1:0]                       cxl_tl_arr_h2d_hdr_halt;
// -------------------------------------------------------------------------------------
// H2D Data Channel Header Buffer
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_tx_tl_chmsg_buff
 #(
    .CXL_CHMSG_CREDITS    (CXL_CHI_MAXCREDITS),
    .CXL_CHMSG_NUM        (H2D_DATA_NUM      ),
    .CXL_CHMSG_WIDTH      (H2D_HDR_CH_SIZE   )
) u_h2d_hdr_buff (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .core_clk             (b_clk.s_core_clk),
    .core_rst_n           (b_clk.s_core_rst_n),
    .pos_core_clk         (pos_core_clk),
    .cxl_chmsg_crd_rst_i  (cxl_cache_crd_rst),
    .cxl_chmsg_en_i       (cxl_cache_crd_ena & cfg_dev_mode_cxl),
    .cxl_chmsg_i          ({ b_app_host_chi.s_cxl_h2d_data_chk[0][(H2D_DATA_CHK_SIZE-H2D_DDATA_CHK_SIZE)-1:0] , b_app_host_chi.s_cxl_h2d_data[0][H2D_DHDR_SIZE-1:0]}),
    .cxl_chmsg_halt_i     (cxl_tl_arr_h2d_hdr_halt),
    .cxl_chdata_af_i      (cxl_h2d_data_af_s),
    .cxl_chmsg_pop_valid  (),
    .cxl_chmsg_chid       (),
    .cxl_chmsg_ovflw_o    (host_cache_hdr_ovflw_s[0]),
    .cxl_chmsg_empty_o    (host_cache_hdr_empty_s[0]),
    .cxl_chmsg_o          (cxl_tl_arr_h2d_hdr),
    .cxl_chmsg_crd_o      (b_app_host_chi.s_cxl_h2d_data_crd[0])
);
// -------------------------------------------------------------------------------------
// H2D Data Header Channel Transaction Layer Controller
// -------------------------------------------------------------------------------------



DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( H2D_DATA_NUM    ),
    .CXL_CHMSG_WIDTH     ( H2D_HDR_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0            )
) u_h2d_hdr_regout (
    .core_clk            ( b_clk.s_core_clk               ),
    .core_rst_n          ( b_clk.s_core_rst_n             ),
    .cxl_tl_chmsg_vld_i  ( '0                             ),
    .cxl_tl_chmsg_i      ( cxl_tl_arr_h2d_hdr             ),
    .cxl_ll_chmsg_halt_i ( b_txtl_host.s_cxl_h2d_hdr_halt ),
    .cxl_ll_chmsg_o      ( s_txtl_host_h2d_hdr            ),
    .cxl_tl_chmsg_halt_o ( cxl_tl_arr_h2d_hdr_halt        )
);

// TX Channel Message Controller <-> Link Layer Connections
generate 
for (genvar i =0; i<H2D_DATA_NUM; i++) begin: H2D_HDR_LL
assign { b_txtl_rasdp.s_cxl_h2d_hdr_chk[i] , b_txtl_host.s_cxl_h2d_hdr[i]} = s_txtl_host_h2d_hdr[i];
end 
endgenerate


// -------------------------------------------------------------------------------------
// H2D Data Channel Data Buffer
// -------------------------------------------------------------------------------------
localparam H2D_DATA_CH_SIZE = H2D_DDATA_SIZE + H2D_DDATA_CHK_SIZE;
localparam H2D_DATA_OUT_NUM = H2D_DDATA_NUM + (H2D_DATA_NUM - H2D_DDATA_NUM);

logic [H2D_DATA_CH_SIZE-1:0]                         s_txtl_host_h2d_data [0:H2D_DATA_OUT_NUM-1] ;
logic [H2D_DATA_OUT_NUM-1:0] [H2D_DATA_CH_SIZE-1:0]  s_txtl_host_buff_h2d_data ;
logic [H2D_DDATA_NUM-1:0]                            s_txtl_host_buff_h2d_data_vld ;
logic [H2D_DDATA_NUM-1:0]                            s_txtl_host_buff_h2d_data_halt ;
logic [H2D_DATA_CH_SIZE-1:0]                         cxl_slv_h2d_data_ram_wdata;
logic [H2D_DATA_CH_SIZE-1:0]                         s_txtl_host_app_h2d_data;
generate 
for (genvar i =0; i<H2D_DDATA_NUM; i++) begin: H2D_DATA_LL
  assign b_txtl_host.s_cxl_h2d_data[i] = s_txtl_host_h2d_data[i][H2D_DDATA_SIZE-1:0];
end 
endgenerate

generate 
for (genvar i =0; i<H2D_DATA_NUM; i++) begin: H2D_DATA_RASDP
  assign {b_txtl_rasdp.s_cxl_h2d_data_chk[i], b_txtl_rasdp.s_cxl_h2d_data_arr[i]} = s_txtl_host_h2d_data[i];
end 
endgenerate

assign s_txtl_host_app_h2d_data = { b_app_host_chi.s_cxl_h2d_data_chk[0][H2D_DATA_CHK_SIZE-1:(H2D_DATA_CHK_SIZE-H2D_DDATA_CHK_SIZE)] , b_app_host_chi.s_cxl_h2d_data[0][(H2D_DATA_SIZE-1)-:H2D_DDATA_SIZE]}; 

DWC_cxl_mem_cache_tx_tl_chdata_buff
 #(
    .CXL_CHDATA_CREDITS ( CXL_CHI_MAXCREDITS ),
    .CXL_CHDATA_MSGNUM  ( H2D_DATA_NUM       ),
    .CXL_CHDATA_PATH    ( H2D_DDATA_NUM      ),
    .CXL_CHDATA_WIDTH   ( H2D_DATA_CH_SIZE   ),
    .CXL_CHRAM_DATAW    ( H2D_DATA_CH_SIZE   ),
    .CXL_CHRAM_ADDRW    ( HD_DATA_RAM_ADDRW  ),
    .CXL_CHRAM_DEPTH    ( HD_DATA_RAM_DEPTH  )
) u_h2d_data_buff (
    .cxl_clk            ( b_clk.s_cxl_clk                                            ),
    .cxl_rst_n          ( b_clk.s_cxl_rst_n                                          ),
    .core_clk           ( b_clk.s_core_clk                                           ),
    .core_rst_n         ( b_clk.s_core_rst_n                                         ),
    .pos_core_clk       ( pos_core_clk                                               ),
    .cxl_chdata_vld_i   ( b_app_host_chi.s_cxl_h2d_data[0][H2D_HDR_VLD]              ),
    .cxl_chdata_i       ( s_txtl_host_app_h2d_data                                   ),
    .cxl_chdata_halt_i  ( s_txtl_host_buff_h2d_data_halt                             ),
    .cxl_ram_rdata      ( b_cxl_slv_h2d_data_ram.s_ram_rdata[H2D_DATA_CH_SIZE -1 :0] ),
    .cxl_ram_wdata      ( cxl_slv_h2d_data_ram_wdata                                 ),
    .cxl_ram_re         ( b_cxl_slv_h2d_data_ram.s_ram_rd                            ),
    .cxl_ram_raddr      ( b_cxl_slv_h2d_data_ram.s_ram_rd_addr                       ),
    .cxl_ram_we         ( b_cxl_slv_h2d_data_ram.s_ram_we                            ),
    .cxl_ram_waddr      ( b_cxl_slv_h2d_data_ram.s_ram_wr_addr                       ),
    .cxl_chdata_ovflw_o ( host_cache_data_ovflw_s[0]                                 ),
    .cxl_chdata_empty_o ( host_cache_data_empty_s[0]                                 ),
    .cxl_chdata_af_o    ( cxl_h2d_data_af_s                                          ),
    .cxl_chdata_vld_o   ( s_txtl_host_buff_h2d_data_vld                              ),
    .cxl_chdata_o       ( s_txtl_host_buff_h2d_data                                  )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_DATA      ( 1'b1             ),
    .CXL_CHMSG_NUM       ( H2D_DATA_OUT_NUM ),
    .CXL_CHMSG_VLD_NUM   ( H2D_DDATA_NUM    ),
    .CXL_CHMSG_WIDTH     ( H2D_DATA_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0             )
) u_h2d_data_regout (
    .core_clk            ( b_clk.s_core_clk                ),
    .core_rst_n          ( b_clk.s_core_rst_n              ),
    .cxl_tl_chmsg_i      ( s_txtl_host_buff_h2d_data       ),
    .cxl_tl_chmsg_vld_i  ( s_txtl_host_buff_h2d_data_vld   ),
    .cxl_ll_chmsg_halt_i ( b_txtl_host.s_cxl_h2d_data_halt ),
    .cxl_ll_chmsg_o      ( s_txtl_host_h2d_data            ),
    .cxl_ll_chmsg_vld_o  ( b_txtl_host.s_cxl_h2d_data_vld  ),
    .cxl_tl_chmsg_halt_o ( s_txtl_host_buff_h2d_data_halt  )
);

assign  b_cxl_slv_h2d_data_ram.s_ram_wdata = {{D2H_BE_CH_SIZE{1'b0}} , cxl_slv_h2d_data_ram_wdata};

// -------------------------------------------------------------------------------------



// -------------------------------------------------------------------------------------
// M2S Request Parametrized Channel Connections
// -------------------------------------------------------------------------------------
localparam M2S_NDR_CH_SIZE = M2S_NDR_SIZE + M2S_NDR_CHK_SIZE;
// TX Channel Message Controller Outputs
logic [M2S_NDR_CH_SIZE-1:0]  s_txtl_host_m2s_req [0:M2S_NDR_NUM-1];

// TX Channel Message Controller <-> Link Layer Connections


logic [M2S_NDR_NUM-1:0]                       cxl_tl_arr_m2s_ndr_halt[M2S_NDR_IFNUM];
logic [M2S_NDR_NUM-1:0][M2S_NDR_CH_SIZE-1:0]  cxl_tl_m2s_ndr_s;       //control module input data
logic [M2S_NDR_NUM-1:0]                       cxl_tl_m2s_ndr_halt_s;  // control module output halt



// -------------------------------------------------------------------------------------
// M2S NDR Response Channel Transaction Layer Controller
// -------------------------------------------------------------------------------------


logic [M2S_NDR_NUM-1:0][M2S_NDR_CH_SIZE-1:0]  cxl_tl_arr_m2s_ndr[M2S_NDR_IFNUM];

// -------------------------------------------------------------------------------------
// M2S Request Channel Buffer
// -------------------------------------------------------------------------------------

DWC_cxl_mem_cache_tx_tl_chmsg_buff
 #(
    .CXL_CHMSG_CREDITS    (CXL_CHI_MAXCREDITS),
    .CXL_CHMSG_NUM        (M2S_NDR_NUM),
    .CXL_CHMSG_WIDTH      (M2S_NDR_CH_SIZE)
) u_m2s_req_buff (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .core_clk             (b_clk.s_core_clk),
    .core_rst_n           (b_clk.s_core_rst_n),
    .pos_core_clk         (pos_core_clk),
    .cxl_chmsg_crd_rst_i  (cxl_mem_crd_rst),
    .cxl_chmsg_en_i       (cxl_m2s_crd_ena),
    .cxl_chmsg_i          ({ b_app_host_chi.s_cxl_m2s_req_chk[0] , b_app_host_chi.s_cxl_m2s_req[0]}),
    .cxl_chmsg_halt_i     (cxl_tl_arr_m2s_ndr_halt[0]),
    .cxl_chdata_af_i      (1'b0),
    .cxl_chmsg_pop_valid  (),
    .cxl_chmsg_chid       (),
    .cxl_chmsg_ovflw_o    (host_mem_ndr_ovflw_s[0]),
    .cxl_chmsg_empty_o    (host_mem_ndr_empty_s[0]),
    .cxl_chmsg_o          (cxl_tl_arr_m2s_ndr[0]),
    .cxl_chmsg_crd_o      (b_app_host_chi.s_cxl_m2s_req_crd[0])
);

assign cxl_tl_m2s_ndr_s  = cxl_tl_arr_m2s_ndr[0];
assign cxl_tl_arr_m2s_ndr_halt[0] = cxl_tl_m2s_ndr_halt_s ;


DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( M2S_NDR_NUM      ),
    .CXL_CHMSG_WIDTH     ( M2S_NDR_CH_SIZE  ),
    .CXL_CHMSG_REG       ( 1'b0             )
) u_m2s_req_regout (
    .core_clk            ( b_clk.s_core_clk               ),
    .core_rst_n          ( b_clk.s_core_rst_n             ),
    .cxl_tl_chmsg_vld_i  ( '0                             ),
    .cxl_tl_chmsg_i      ( cxl_tl_m2s_ndr_s               ),
    .cxl_ll_chmsg_halt_i ( b_txtl_host.s_cxl_m2s_req_halt ),
    .cxl_ll_chmsg_o      ( s_txtl_host_m2s_req            ),
    .cxl_tl_chmsg_halt_o ( cxl_tl_m2s_ndr_halt_s          )
);


// TX Channel Message Controller <-> Link Layer Connections
generate
for (genvar i=0; i<M2S_NDR_NUM; i++ ) begin: M2S_REQ
assign { b_txtl_rasdp.s_cxl_m2s_req_chk[i] , b_txtl_host.s_cxl_m2s_req[i]} = s_txtl_host_m2s_req[i];
end
endgenerate



// -------------------------------------------------------------------------------------
// M2S Request with Data Channel Connections
// -------------------------------------------------------------------------------------

  localparam M2S_HDR_CH_SIZE = M2S_DHDR_SIZE + M2S_DHDR_CHK_SIZE;
logic [M2S_DATA_NUM-1:0] [M2S_HDR_CH_SIZE-1:0]  cxl_tl_ch_m2s_hdr;
logic [M2S_DATA_NUM-1:0]     cxl_tl_ch_m2s_hdr_halt;
logic                        cxl_m2s_data_af_s;
// TX Channel Message Controller Outputs
logic [M2S_HDR_CH_SIZE-1:0]  s_txtl_host_m2s_hdr [0:M2S_DATA_NUM-1];
logic s_cxl_m2s_be_vld_n;

// -------------------------------------------------------------------------------------
// M2S Request with Data Channel Header Buffer
// -------------------------------------------------------------------------------------
assign s_cxl_m2s_be_vld_n = &b_app_host_chi.s_cxl_m2s_rwd[0][(M2S_DBE_SIZE + M2S_DHDR_SIZE -1) -: M2S_DBE_SIZE];
DWC_cxl_mem_cache_tx_tl_chmsg_buff
 #(
    .CXL_CHMSG_CREDITS    ( CXL_CHI_MAXCREDITS ),
    .CXL_CHMSG_NUM        ( M2S_DATA_NUM       ),
    .CXL_CHMSG_WIDTH      ( M2S_HDR_CH_SIZE    )
) u_m2s_hdr_buff (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .core_clk             (b_clk.s_core_clk),
    .core_rst_n           (b_clk.s_core_rst_n),
    .pos_core_clk         (pos_core_clk),
    .cxl_chmsg_crd_rst_i  (cxl_mem_crd_rst),
    .cxl_chmsg_en_i       (cxl_m2s_crd_ena),
    .cxl_chmsg_i          ({ b_app_host_chi.s_cxl_m2s_rwd_chk[0][M2S_DHDR_CHK_SIZE-1:0] ,  b_app_host_chi.s_cxl_m2s_rwd[0][M2S_DHDR_SIZE-1:0]}),
    .cxl_chmsg_halt_i     (cxl_tl_ch_m2s_hdr_halt),
    .cxl_chdata_af_i      (cxl_m2s_data_af_s),
    .cxl_chmsg_pop_valid  (),
    .cxl_chmsg_chid       (),
    .cxl_chmsg_ovflw_o    (host_mem_hdr_ovflw_s[0]),
    .cxl_chmsg_empty_o    (host_mem_hdr_empty_s[0]),
    .cxl_chmsg_o          (cxl_tl_ch_m2s_hdr),
    .cxl_chmsg_crd_o      (b_app_host_chi.s_cxl_m2s_rwd_crd[0])
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( M2S_DATA_NUM     ),
    .CXL_CHMSG_WIDTH     ( M2S_HDR_CH_SIZE  ),
    .CXL_CHMSG_REG       ( 1'b0             )
) u_m2s_rwd_regout (
    .core_clk            ( b_clk.s_core_clk               ),
    .core_rst_n          ( b_clk.s_core_rst_n             ),
    .cxl_tl_chmsg_vld_i  ( '0                             ),
    .cxl_tl_chmsg_i      ( cxl_tl_ch_m2s_hdr              ),
    .cxl_ll_chmsg_halt_i ( b_txtl_host.s_cxl_m2s_hdr_halt ),
    .cxl_ll_chmsg_o      ( s_txtl_host_m2s_hdr            ),
    .cxl_tl_chmsg_halt_o ( cxl_tl_ch_m2s_hdr_halt         )
);

// -------------------------------------------------------------------------------------
// M2S Request with Data Channel Data Buffer
// -------------------------------------------------------------------------------------
localparam M2S_DATA_CH_SIZE = M2S_DDATA_SIZE + M2S_DDATA_CHK_SIZE;
localparam M2S_DATA_BE_CH_SIZE = M2S_DDATA_SIZE + M2S_DBE_SIZE + M2S_DDATA_CHK_SIZE + M2S_DBE_CHK_SIZE;
localparam M2S_DATA_OUT_NUM = M2S_DDATA_NUM + (M2S_DATA_NUM - M2S_DDATA_NUM);

logic [M2S_DATA_BE_CH_SIZE-1:0]                       s_txtl_host_m2s_data_be [0:M2S_DATA_OUT_NUM-1] ;
logic [M2S_DATA_BE_CH_SIZE-1:0]                       s_cxl_m2s_data_be [0:M2S_DATA_IFNUM-1];
logic [M2S_BE_CH_SIZE-1     :0]                       s_txtl_host_m2s_be [0:M2S_DATA_OUT_NUM-1];
logic [M2S_DATA_OUT_NUM-1:0][M2S_DATA_BE_CH_SIZE-1:0] s_txtl_host_buff_m2s_data_be ;
logic [M2S_DDATA_NUM-1:0]                             s_txtl_host_buff_m2s_data_be_vld ;
logic [M2S_DDATA_NUM-1:0]                             s_txtl_host_buff_m2s_data_be_halt ;

assign s_cxl_m2s_data_be[0] = { b_app_host_chi.s_cxl_m2s_rwd_chk[0][(M2S_DBE_CHK_SIZE + M2S_DHDR_CHK_SIZE -1) -: M2S_DBE_CHK_SIZE ], // BE protection bits
                                b_app_host_chi.s_cxl_m2s_rwd_chk[0][M2S_DATA_CHK_SIZE-1 -: M2S_DDATA_CHK_SIZE],                      // data protection bits
                                b_app_host_chi.s_cxl_m2s_rwd[0][(M2S_DBE_SIZE + M2S_DHDR_SIZE -1) -: M2S_DBE_SIZE],                  // BE                                 
                                b_app_host_chi.s_cxl_m2s_rwd[0][(M2S_DATA_SIZE-1) -: M2S_DDATA_SIZE]};                               // data 

DWC_cxl_mem_cache_tx_tl_chdata_buff
 #(
    .CXL_CHDATA_CREDITS ( CXL_CHI_MAXCREDITS  ),
    .CXL_CHDATA_MSGNUM  ( M2S_DATA_NUM        ),
    .CXL_CHDATA_PATH    ( M2S_DDATA_NUM       ),
    .CXL_CHDATA_WIDTH   ( M2S_DATA_BE_CH_SIZE ),
    .CXL_CHRAM_DATAW    ( MS_DATAW            ),
    .CXL_CHRAM_ADDRW    ( MS_DATA_RAM_ADDRW   ),
    .CXL_CHRAM_DEPTH    ( MS_DATA_RAM_DEPTH   )
) u_m2s_data_buff (
    .cxl_clk            ( b_clk.s_cxl_clk                              ),
    .cxl_rst_n          ( b_clk.s_cxl_rst_n                            ),
    .core_clk           ( b_clk.s_core_clk                             ),
    .core_rst_n         ( b_clk.s_core_rst_n                           ),
    .pos_core_clk       ( pos_core_clk                                 ),
    .cxl_chdata_vld_i   ( b_app_host_chi.s_cxl_m2s_rwd[0][M2S_HDR_VLD] ),
    .cxl_chdata_i       ( s_cxl_m2s_data_be[0]                         ),
    .cxl_chdata_halt_i  ( s_txtl_host_buff_m2s_data_be_halt            ),
    .cxl_ram_rdata      ( b_cxl_slv_m2s_data_ram.s_ram_rdata           ),
    .cxl_ram_re         ( b_cxl_slv_m2s_data_ram.s_ram_rd              ),
    .cxl_ram_raddr      ( b_cxl_slv_m2s_data_ram.s_ram_rd_addr         ),
    .cxl_ram_we         ( b_cxl_slv_m2s_data_ram.s_ram_we              ),
    .cxl_ram_waddr      ( b_cxl_slv_m2s_data_ram.s_ram_wr_addr         ),
    .cxl_ram_wdata      ( b_cxl_slv_m2s_data_ram.s_ram_wdata           ),
    .cxl_chdata_ovflw_o ( host_mem_data_ovflw_s[0]                     ),
    .cxl_chdata_empty_o ( host_mem_data_empty_s[0]                     ),
    .cxl_chdata_af_o    ( cxl_m2s_data_af_s                            ),
    .cxl_chdata_vld_o   ( s_txtl_host_buff_m2s_data_be_vld             ),
    .cxl_chdata_o       ( s_txtl_host_buff_m2s_data_be                 )
);

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_DATA      ( 1'b1                ),
    .CXL_CHMSG_NUM       ( M2S_DATA_OUT_NUM    ),
    .CXL_CHMSG_VLD_NUM   ( M2S_DDATA_NUM       ),
    .CXL_CHMSG_WIDTH     ( M2S_DATA_BE_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0                )
) u_m2s_data_regout (
    .core_clk            ( b_clk.s_core_clk                  ),
    .core_rst_n          ( b_clk.s_core_rst_n                ),
    .cxl_tl_chmsg_i      ( s_txtl_host_buff_m2s_data_be      ),
    .cxl_tl_chmsg_vld_i  ( s_txtl_host_buff_m2s_data_be_vld  ),
    .cxl_ll_chmsg_halt_i ( b_txtl_host.s_cxl_m2s_data_halt   ),
    .cxl_ll_chmsg_o      ( s_txtl_host_m2s_data_be           ),
    .cxl_ll_chmsg_vld_o  ( b_txtl_host.s_cxl_m2s_data_vld    ),
    .cxl_tl_chmsg_halt_o ( s_txtl_host_buff_m2s_data_be_halt )
);

// -------------------------------------------------------------------------------------
// M2S Request with Data Channel Transaction Layer Controller
// -------------------------------------------------------------------------------------
// TX Channel Message Controller <-> Link Layer Connections
generate
for (genvar i=0; i<M2S_DATA_OUT_NUM; i++ ) begin: M2S_DATA_BE
  assign  s_txtl_host_m2s_be [i]= { s_txtl_host_m2s_data_be[i][M2S_DATA_BE_CH_SIZE-1 -: M2S_DBE_CHK_SIZE] ,   s_txtl_host_m2s_data_be[i][(M2S_DDATA_SIZE + M2S_DBE_SIZE -1) -: M2S_DBE_SIZE]};
end
endgenerate

generate 
  for (genvar i=0; i<M2S_DATA_NUM; i++ ) begin: M2S_HDR_LL
    assign b_txtl_host.s_cxl_m2s_hdr[i] = s_txtl_host_m2s_hdr[i][M2S_DHDR_SIZE -1 :0];
  end
endgenerate

generate
  for (genvar i=0; i<M2S_DDATA_NUM; i++ ) begin: M2S_DATA_LL
    assign b_txtl_host.s_cxl_m2s_data[i] = s_txtl_host_m2s_data_be[i][M2S_DDATA_SIZE-1:0];
    assign b_txtl_host.s_cxl_m2s_be[i]   = s_txtl_host_m2s_be[i] [M2S_DBE_SIZE  -1 :0];
  end
endgenerate


generate
for (genvar i=0; i<M2S_DATA_NUM; i++ ) begin: M2S_RASDP
  assign b_txtl_rasdp.s_cxl_m2s_data_chk[i] = s_txtl_host_m2s_data_be[i][(M2S_DATA_BE_CH_SIZE-M2S_DBE_CHK_SIZE-1) -: M2S_DDATA_CHK_SIZE];
  assign b_txtl_rasdp.s_cxl_m2s_data_arr[i] = s_txtl_host_m2s_data_be[i][M2S_DDATA_SIZE-1:0];
  assign b_txtl_rasdp.s_cxl_m2s_be_chk[i]   = s_txtl_host_m2s_be[i][M2S_BE_CH_SIZE-1 -: M2S_DBE_CHK_SIZE];
  assign b_txtl_rasdp.s_cxl_m2s_be_arr[i]   = s_txtl_host_m2s_be[i][M2S_DBE_SIZE-1 : 0];
  assign b_txtl_rasdp.s_cxl_m2s_hdr_chk[i]  = s_txtl_host_m2s_hdr[i][M2S_HDR_CH_SIZE-1 -: M2S_DHDR_CHK_SIZE];
end
endgenerate


generate 
  for (genvar i=0; i<M2S_DATA_NUM; i++ ) begin: M2S_BE_VLD
    assign b_txtl_host.s_cxl_m2s_be_vld_n[i] =  '0; //to avoid undriven output ports. 
  end
endgenerate


// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// S2M Back-Invalidate Snoop
// -------------------------------------------------------------------------------------
localparam S2M_BI_SNP_CH_SIZE = S2M_BI_SNP_SIZE + S2M_BI_SNP_CHK_SIZE;

// TX Channel Message Buffer <-> Channel Message Parametrized Controller connections
logic [S2M_BI_SNP_NUM-1:0][S2M_BI_SNP_CH_SIZE-1:0]   cxl_tl_arr_s2m_bi_snp[S2M_BI_SNP_IFNUM];
logic [S2M_BI_SNP_NUM-1:0]                           cxl_tl_arr_s2m_bi_snp_halt[S2M_BI_SNP_IFNUM];

logic [S2M_BI_SNP_NUM-1:0][S2M_BI_SNP_CH_SIZE-1:0]   cxl_tl_s2m_bi_snp_s;       //control module data input
logic [S2M_BI_SNP_NUM-1:0]                           cxl_tl_s2m_bi_snp_halt_s;  //control module halt output
// TX Channel Message Controller Outputs
logic [S2M_BI_SNP_CH_SIZE-1:0]  s_txtl_dev_s2m_bi_snp [0:S2M_BI_SNP_NUM-1];

// TX Channel Message Controller <-> Link Layer Connections

generate 
for (genvar i=0; i<S2M_BI_SNP_NUM; i++ ) begin: S2M_BI_SNP_LL
assign { b_txtl_rasdp.s_cxl_s2m_bi_snp_chk[i] , b_txtl_dev.s_cxl_s2m_bi_snp[i]} = s_txtl_dev_s2m_bi_snp[i];
end
endgenerate

// -------------------------------------------------------------------------------------
// S2M Back-Invalidate Snoop Channel Buffer
// -------------------------------------------------------------------------------------

generate
for (genvar i =0; i < S2M_BI_SNP_IFNUM ; i++) begin : S2M_BI_SNP
DWC_cxl_mem_cache_tx_tl_chmsg_buff
 #(
    .CXL_CHMSG_CREDITS    (CXL_CHI_MAXCREDITS),
    .CXL_CHMSG_NUM        (S2M_BI_SNP_NUM),
    .CXL_CHMSG_WIDTH      (S2M_BI_SNP_CH_SIZE)
) u_s2m_bi_snp_buff (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .core_clk             (b_clk.s_core_clk),
    .core_rst_n           (b_clk.s_core_rst_n),
    .pos_core_clk         (pos_core_clk),
    .cxl_chmsg_crd_rst_i  (cxl_mem_crd_rst),
    .cxl_chmsg_en_i       (cxl_mem_crd_ena && !cfg_dev_mode_cxl),
    .cxl_chmsg_i          ({ b_app_dev_chi.s_cxl_s2m_bi_snp_chk[i] , b_app_dev_chi.s_cxl_s2m_bi_snp[i]}),
    .cxl_chmsg_halt_i     (cxl_tl_arr_s2m_bi_snp_halt[i]),
    .cxl_chdata_af_i      (1'b0),
    .cxl_chmsg_pop_valid  (),
    .cxl_chmsg_chid       (),
    .cxl_chmsg_ovflw_o    (dev_mem_bi_snp_ovflw_s[i]),
    .cxl_chmsg_empty_o    (dev_mem_bi_snp_empty_s[i]),
    .cxl_chmsg_o          (cxl_tl_arr_s2m_bi_snp[i]),
    .cxl_chmsg_crd_o      (b_app_dev_chi.s_cxl_s2m_bi_snp_crd[i])
);
end 
endgenerate
// -------------------------------------------------------------------------------------
// S2M Back-Invalidate Snoop Channel Transaction Layer Controller
// -------------------------------------------------------------------------------------

generate if (S2M_BI_SNP_IFNUM > 1) begin: S2M_BI_SNP_ARB_CTRL
logic [S2M_BI_SNP_NUM-1:0][S2M_BI_SNP_CH_SIZE-1:0]  cxl_arb_arr_s2m_bi_snp;
logic [S2M_BI_SNP_NUM-1:0]      cxl_arb_s2m_bi_snp_halt;

DWC_cxl_mem_cache_tx_tl_chmsg_arb
 #(
    .CXL_CHMSG_NUM    (S2M_BI_SNP_NUM),
    .CXL_CHMSG_WIDTH  (S2M_BI_SNP_CH_SIZE),
    .CXL_CHANNEL_NUM  (S2M_BI_SNP_IFNUM)
) u_s2m_bi_snp_arb (
    .core_clk               (b_clk.s_core_clk),
    .core_rst_n             (b_clk.s_core_rst_n),
    .cxl_arb_chmsg_i        (cxl_tl_arr_s2m_bi_snp),
    .cxl_arb_chmsg_halt_i   (cxl_arb_s2m_bi_snp_halt),
    .cxl_arb_chmsg_halt_o   (cxl_tl_arr_s2m_bi_snp_halt),
    .cxl_arb_chmsg_o        (cxl_arb_arr_s2m_bi_snp) 
);

assign cxl_tl_s2m_bi_snp_s     = cxl_arb_arr_s2m_bi_snp;
assign cxl_arb_s2m_bi_snp_halt = cxl_tl_s2m_bi_snp_halt_s;
end
else begin: S2M_BI_SNP_CTRL

assign cxl_tl_s2m_bi_snp_s           = cxl_tl_arr_s2m_bi_snp[0];
assign cxl_tl_arr_s2m_bi_snp_halt[0] = cxl_tl_s2m_bi_snp_halt_s;

end
endgenerate


DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( S2M_BI_SNP_NUM     ),
    .CXL_CHMSG_WIDTH     ( S2M_BI_SNP_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0               )
) u_s2m_bi_snp_regout (
    .core_clk            ( b_clk.s_core_clk                 ),
    .core_rst_n          ( b_clk.s_core_rst_n               ),
    .cxl_tl_chmsg_vld_i  ( '0                               ),
    .cxl_tl_chmsg_i      ( cxl_tl_s2m_bi_snp_s              ),
    .cxl_ll_chmsg_halt_i ( b_txtl_dev.s_cxl_s2m_bi_snp_halt ),
    .cxl_ll_chmsg_o      ( s_txtl_dev_s2m_bi_snp            ),
    .cxl_tl_chmsg_halt_o ( cxl_tl_s2m_bi_snp_halt_s         )
);
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// M2S Back-Invalidate Response
// -------------------------------------------------------------------------------------
localparam M2S_BI_RSP_CH_SIZE = M2S_BI_RSP_SIZE + M2S_BI_RSP_CHK_SIZE;

// TX Channel Message Controller Outputs
logic [M2S_BI_RSP_CH_SIZE-1:0]                      s_txtl_host_m2s_bi_rsp [0:M2S_BI_RSP_NUM-1];
// TX Channel Message Buffer <-> Channel Message Parametrized Controller connections
logic [M2S_BI_RSP_NUM-1:0][M2S_BI_RSP_CH_SIZE-1:0]  cxl_tl_arr_m2s_bi_rsp[M2S_BI_RSP_IFNUM];
logic [M2S_BI_RSP_NUM-1:0]                          cxl_tl_arr_m2s_bi_rsp_halt[M2S_BI_RSP_IFNUM];

logic [M2S_BI_RSP_NUM-1:0][M2S_BI_RSP_CH_SIZE-1:0]  cxl_tl_m2s_bi_rsp_s;      //control module data input
logic [M2S_BI_RSP_NUM-1:0]                          cxl_tl_m2s_bi_rsp_halt_s; //control module halt output


// TX Channel Message Controller <-> Link Layer Connections


// -------------------------------------------------------------------------------------
// M2S Back-Invalidate Response Channel Buffer
// -------------------------------------------------------------------------------------
generate
for (genvar i =0; i < M2S_BI_RSP_IFNUM; i++) begin : M2S_BI_RSP
DWC_cxl_mem_cache_tx_tl_chmsg_buff
 #(
    .CXL_CHMSG_CREDITS    (CXL_CHI_MAXCREDITS),
    .CXL_CHMSG_NUM        (M2S_BI_RSP_NUM),
    .CXL_CHMSG_WIDTH      (M2S_BI_RSP_CH_SIZE)
) u_m2s_bi_rsp_buff (
    .cxl_clk              (b_clk.s_cxl_clk),
    .cxl_rst_n            (b_clk.s_cxl_rst_n),
    .core_clk             (b_clk.s_core_clk),
    .core_rst_n           (b_clk.s_core_rst_n),
    .pos_core_clk         (pos_core_clk),
    .cxl_chmsg_crd_rst_i  (cxl_mem_crd_rst),
    .cxl_chmsg_en_i       (cxl_mem_crd_ena && cfg_dev_mode_cxl),
    .cxl_chmsg_i          ({ b_app_host_chi.s_cxl_m2s_bi_rsp_chk[i] , b_app_host_chi.s_cxl_m2s_bi_rsp[i]}),
    .cxl_chmsg_halt_i     (cxl_tl_arr_m2s_bi_rsp_halt[i]),
    .cxl_chdata_af_i      (1'b0),
    .cxl_chmsg_pop_valid  (),
    .cxl_chmsg_chid       (),
    .cxl_chmsg_ovflw_o    (host_mem_bi_rsp_ovflw_s[i]),
    .cxl_chmsg_empty_o    (host_mem_bi_rsp_empty_s[i]),
    .cxl_chmsg_o          (cxl_tl_arr_m2s_bi_rsp[i]),
    .cxl_chmsg_crd_o      (b_app_host_chi.s_cxl_m2s_bi_rsp_crd[i])
);
end 
endgenerate

// -------------------------------------------------------------------------------------
// M2S Back-Invalidate Response Channel Transaction Layer Controller
// -------------------------------------------------------------------------------------

generate if (M2S_BI_RSP_IFNUM > 1) begin: M2S_BI_RSP_ARB_CTRL
logic [M2S_BI_RSP_NUM-1:0][M2S_BI_RSP_CH_SIZE-1:0]  cxl_arb_arr_m2s_bi_rsp;
logic [M2S_BI_RSP_NUM-1:0]      cxl_arb_m2s_bi_rsp_halt;

DWC_cxl_mem_cache_tx_tl_chmsg_arb
 #(
    .CXL_CHMSG_NUM    (M2S_BI_RSP_NUM),
    .CXL_CHMSG_WIDTH  (M2S_BI_RSP_CH_SIZE),
    .CXL_CHANNEL_NUM  (M2S_BI_RSP_IFNUM)
) u_m2s_bi_rsp_arb (
    .core_clk               (b_clk.s_core_clk),
    .core_rst_n             (b_clk.s_core_rst_n),
    .cxl_arb_chmsg_i        (cxl_tl_arr_m2s_bi_rsp),
    .cxl_arb_chmsg_halt_i   (cxl_arb_m2s_bi_rsp_halt),
    .cxl_arb_chmsg_halt_o   (cxl_tl_arr_m2s_bi_rsp_halt),
    .cxl_arb_chmsg_o        (cxl_arb_arr_m2s_bi_rsp) 
);

assign cxl_tl_m2s_bi_rsp_s     = cxl_arb_arr_m2s_bi_rsp;
assign cxl_arb_m2s_bi_rsp_halt = cxl_tl_m2s_bi_rsp_halt_s;
end
else begin: M2S_BI_RSP_CTRL

assign cxl_tl_m2s_bi_rsp_s           = cxl_tl_arr_m2s_bi_rsp[0];
assign cxl_tl_arr_m2s_bi_rsp_halt[0] = cxl_tl_m2s_bi_rsp_halt_s;

end
endgenerate

DWC_cxl_mem_cache_tx_tl_ch_reg
 #(
    .CXL_CHMSG_NUM       ( M2S_BI_RSP_NUM     ),
    .CXL_CHMSG_WIDTH     ( M2S_BI_RSP_CH_SIZE ),
    .CXL_CHMSG_REG       ( 1'b0               )
) u_m2s_bi_rsp_regout (
    .core_clk            ( b_clk.s_core_clk                   ),
    .core_rst_n          ( b_clk.s_core_rst_n                 ),
    .cxl_tl_chmsg_vld_i  ( '0                                 ),
    .cxl_tl_chmsg_i      ( cxl_tl_m2s_bi_rsp_s                ),
    .cxl_ll_chmsg_halt_i ( b_txtl_host.s_cxl_m2s_bi_rsp_halt  ),
    .cxl_ll_chmsg_o      ( s_txtl_host_m2s_bi_rsp             ),
    .cxl_tl_chmsg_halt_o ( cxl_tl_m2s_bi_rsp_halt_s           )
);
// TX Channel Message Controller <-> Link Layer Connections
generate 
for (genvar i =0; i<M2S_BI_RSP_NUM; i++) begin: M2S_BI_RSP_LL
assign { b_txtl_rasdp.s_cxl_m2s_bi_rsp_chk[i] , b_txtl_host.s_cxl_m2s_bi_rsp[i]} = s_txtl_host_m2s_bi_rsp[i];
end
endgenerate



// -------------------------------------------------------------------------------------

endmodule : DWC_cxl_mem_cache_tx_tl
