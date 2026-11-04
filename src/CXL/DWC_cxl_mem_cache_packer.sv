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
// ---   $Revision: #6 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_packer.sv#6 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Host Flit Packer
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_packer
    import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)
                                   (
    input                                       core_clk,                // Core clock
    input                                       core_rst_n,              // Core active low asynchronous reset
    input                                       cfg_device_mode,
    input                                       cxl_pcie_flit_mode,
    input                                       cxl_packer_force_crd,
    input CRD_256B_t                            cxl_crd_arb_256B_crd,
    input                                       cfg_cache_poison_start,  // CachePoisonInjectionStart
    output                                      cfg_cache_poison_busy,   // CachePoisonInjectionBusy
    input                                       cfg_mem_poison_start,    // MemPoisonInjectionStart
    output                                      cfg_mem_poison_busy,     // MemPoisonInjectionBusy
    DWC_cxl_txtl_llctrl_if.slave_host_mp        b_txtl_host,             // Flit Packer to Transaction Layer Interface
    DWC_cxl_txtl_llctrl_if.slave_dev_mp         b_txtl_dev,              // Flit Packer to Transaction Layer Interface
    DWC_cxl_pack_llctrl_if.slave_ctrl_mp        b_llctrl,                // Link Layer Controller to Flit Packer Interface
    DWC_cxl_pack_llctrl_if.master_pack_rasdp_mp b_pack                   // Flit Packer to Link Layer Controller Interface

);

  logic cfg_cache_poison_busy_68byte;
  logic cfg_cache_poison_busy_256byte;
  logic cfg_mem_poison_busy_68byte;
  logic cfg_mem_poison_busy_256byte;
  


DWC_cxl_txtl_llctrl_if  b_txtl_host_68byte();
DWC_cxl_txtl_llctrl_if  b_txtl_dev_68byte();
DWC_cxl_pack_llctrl_if  b_llctrl_68byte();
DWC_cxl_pack_llctrl_if  b_pack_68byte();

DWC_cxl_txtl_llctrl_if  b_txtl_host_256byte();
DWC_cxl_txtl_llctrl_if   b_txtl_dev_256byte();
DWC_cxl_pack_llctrl_if  b_llctrl_256byte();
DWC_cxl_pack_llctrl_if b_pack_256byte();

// -------------------------------------------------------------------------------------
// H2D Request/Response Ordering Halt Generation
// -------------------------------------------------------------------------------------
logic [H2D_MSG_CNT_WD-1:0]    cxl_h2d_req_cnt [0:H2D_REQ_NUM-1];
logic [H2D_MSG_CNT_WD-1:0]    cxl_h2d_rsp_cnt [0:H2D_RESP_NUM-1];
logic [H2D_REQ_NUM-1:0]       cxl_h2d_req_rsp_halt; // This signal must gate H2D Request valid bits on Transaction Layer outputs

logic [H2D_REQ_SIZE-1:0] s_cxl_ctl_h2d_req [0:H2D_REQ_NUM-1];
logic [H2D_REQ_NUM-1:0]  s_cxl_ctl_h2d_req_halt;

logic h2d_cnt_cmp_mt_s;
logic h2d_cnt_cmp_lw_s;
logic cxl_h2d_req_rsp_start_halt;

always_comb begin
for (int i = 0; i < H2D_REQ_NUM; i++) begin: H2D_REQ_CNT
    cxl_h2d_req_cnt[i] = b_txtl_host.s_cxl_h2d_req_cnt[i];
    end
for (int i = 0; i < H2D_RESP_NUM; i++) begin: H2D_RESP_CNT
    cxl_h2d_rsp_cnt[i] = b_txtl_host.s_cxl_h2d_rsp_cnt[i];
    end
    cxl_h2d_req_rsp_halt = '0;
    cxl_h2d_req_rsp_start_halt = 1'b0;
    for (int i = 0; i < H2D_REQ_NUM; i++) begin
        // If channel with a lower index is halted the halt the rest of the channels
        if (cxl_h2d_req_rsp_start_halt) cxl_h2d_req_rsp_halt[i] = 1'b1;
        else begin
            for (int j = 0; j < H2D_RESP_NUM; j++) begin
                if (!cxl_h2d_req_rsp_start_halt) begin
                    h2d_cnt_cmp_mt_s = (cxl_h2d_req_cnt[i][H2D_MSG_CNT_WD-1] ^ cxl_h2d_rsp_cnt[j][H2D_MSG_CNT_WD-1]);
                    h2d_cnt_cmp_lw_s = h2d_cnt_cmp_mt_s ? (cxl_h2d_req_cnt[i][H2D_MSG_CNT_WD-2:0] > cxl_h2d_rsp_cnt[j][H2D_MSG_CNT_WD-2:0]) : 
                                                          (cxl_h2d_req_cnt[i][H2D_MSG_CNT_WD-2:0] < cxl_h2d_rsp_cnt[j][H2D_MSG_CNT_WD-2:0]);
                    
                    if (b_txtl_host.s_cxl_h2d_rsp[j][0] && !h2d_cnt_cmp_lw_s) begin
                        cxl_h2d_req_rsp_halt[i] = 1'b1;
                        cxl_h2d_req_rsp_start_halt = 1'b1;
                        //break;
                    end
                end
            end
        end
    end
end

generate 
for (genvar i =0; i<H2D_REQ_NUM; i++) begin: H2D_REQ_LL
// Gate valid bits on the Flit Packer inputs
  assign s_cxl_ctl_h2d_req[i] = {b_txtl_host.s_cxl_h2d_req[i][H2D_REQ_SIZE-1:1], b_txtl_host.s_cxl_h2d_req[i][0] & !cxl_h2d_req_rsp_halt[i]};

// Halt Transaction Layer
  assign b_txtl_host.s_cxl_h2d_req_halt[i] = s_cxl_ctl_h2d_req_halt[i] | cxl_h2d_req_rsp_halt[i];
end
endgenerate

// -------------------------------------------------------------------------------------
  
  DWC_cxl_mem_cache_packer_68byte
  
  u_packer_68byte
  (
    .core_clk                       ( core_clk                              ),
    .core_rst_n                     ( core_rst_n                            ),
    .cfg_device_mode                ( cfg_device_mode                       ),
    .cxl_pcie_flit_mode             ( cxl_pcie_flit_mode                    ),
    .cfg_cache_poison_start         ( cfg_cache_poison_start                ),
    .cfg_cache_poison_busy          ( cfg_cache_poison_busy_68byte          ),
    .cfg_mem_poison_start           ( cfg_mem_poison_start                  ),
    .cfg_mem_poison_busy            ( cfg_mem_poison_busy_68byte            ),
    .b_txtl_host                    ( b_txtl_host_68byte.pack_slave_host_mp ),
    .b_txtl_dev                     ( b_txtl_dev_68byte.pack_slave_dev_mp   ),
    .b_llctrl                       ( b_llctrl_68byte.slave_ctrl_mp         ),
    .b_pack                         ( b_pack_68byte.master_pack_mp          )
  );
  assign cfg_cache_poison_busy = cfg_cache_poison_busy_68byte | cfg_cache_poison_busy_256byte;
  assign cfg_mem_poison_busy = cfg_mem_poison_busy_68byte | cfg_mem_poison_busy_256byte;


  DWC_cxl_mem_cache_packer_256byte
  
  u_packer_256byte
  (
    .core_clk                       ( core_clk                                ),
    .core_rst_n                     ( core_rst_n                              ),
    .cfg_device_mode                ( cfg_device_mode                         ),
    .cxl_pcie_flit_mode             ( cxl_pcie_flit_mode                      ),
    .cxl_packer_force_crd           ( cxl_packer_force_crd                    ),
    .cfg_cache_poison_start         ( cfg_cache_poison_start                  ),
    .cfg_cache_poison_busy          ( cfg_cache_poison_busy_256byte           ),
    .cfg_mem_poison_start           ( cfg_mem_poison_start                    ),
    .cfg_mem_poison_busy            ( cfg_mem_poison_busy_256byte             ),
    .b_txtl_host                    ( b_txtl_host_256byte.pack_slave_host_mp  ),
    .b_txtl_dev                     ( b_txtl_dev_256byte.pack_slave_dev_mp    ),
    .b_llctrl                       ( b_llctrl_256byte.slave_ctrl_mp          ),
    .cxl_crd_arb_256B_crd           ( cxl_crd_arb_256B_crd                    ),
    .b_pack                         ( b_pack_256byte.master_pack_mp           )
  );

always_comb begin
    b_txtl_host_68byte.s_cxl_cache_enable = b_txtl_host.s_cxl_cache_enable;
    b_txtl_host_68byte.s_cxl_cache_app_pending = b_txtl_host.s_cxl_cache_app_pending;
    b_txtl_host_68byte.s_cxl_mem_enable = b_txtl_host.s_cxl_mem_enable;
    b_txtl_host_68byte.s_cxl_mem_app_pending = b_txtl_host.s_cxl_mem_app_pending;

  b_txtl_dev_68byte.s_cxl_cache_enable = b_txtl_dev.s_cxl_cache_enable;
  b_txtl_dev_68byte.s_cxl_cache_app_pending = b_txtl_dev.s_cxl_cache_app_pending;
  b_txtl_dev_68byte.s_cxl_mem_enable   = b_txtl_dev.s_cxl_mem_enable;
  b_txtl_dev_68byte.s_cxl_mem_app_pending = b_txtl_dev.s_cxl_mem_app_pending;

      b_txtl_host_256byte.s_cxl_cache_enable = b_txtl_host.s_cxl_cache_enable;
      b_txtl_host_256byte.s_cxl_cache_app_pending = b_txtl_host.s_cxl_cache_app_pending;
      b_txtl_host_256byte.s_cxl_mem_enable = b_txtl_host.s_cxl_mem_enable;
      b_txtl_host_256byte.s_cxl_mem_app_pending = b_txtl_host.s_cxl_mem_app_pending;

    b_txtl_dev_256byte.s_cxl_cache_enable = b_txtl_dev.s_cxl_cache_enable;
    b_txtl_dev_256byte.s_cxl_cache_app_pending = b_txtl_dev.s_cxl_cache_app_pending;
    b_txtl_dev_256byte.s_cxl_mem_enable   = b_txtl_dev.s_cxl_mem_enable;
    b_txtl_dev_256byte.s_cxl_mem_app_pending = b_txtl_dev.s_cxl_mem_app_pending;


    b_txtl_host_68byte.s_cxl_h2d_req        =  s_cxl_ctl_h2d_req             ;
    b_txtl_host_68byte.s_cxl_h2d_rsp        =  b_txtl_host.s_cxl_h2d_rsp     ;
    b_txtl_host_68byte.s_cxl_h2d_hdr        =  b_txtl_host.s_cxl_h2d_hdr     ;
    b_txtl_host_68byte.s_cxl_h2d_data_vld   =  b_txtl_host.s_cxl_h2d_data_vld;
    b_txtl_host_68byte.s_cxl_h2d_data       =  b_txtl_host.s_cxl_h2d_data    ;
    b_txtl_host_256byte.s_cxl_h2d_req      =  s_cxl_ctl_h2d_req             ;
    b_txtl_host_256byte.s_cxl_h2d_rsp      =  b_txtl_host.s_cxl_h2d_rsp     ;
    b_txtl_host_256byte.s_cxl_h2d_hdr      =  b_txtl_host.s_cxl_h2d_hdr     ;
    b_txtl_host_256byte.s_cxl_h2d_data_vld =  b_txtl_host.s_cxl_h2d_data_vld;
    b_txtl_host_256byte.s_cxl_h2d_data     =  b_txtl_host.s_cxl_h2d_data    ;
    s_cxl_ctl_h2d_req_halt                 = (cxl_pcie_flit_mode)? b_txtl_host_256byte.s_cxl_h2d_req_halt  :  b_txtl_host_68byte.s_cxl_h2d_req_halt ;
    b_txtl_host.s_cxl_h2d_rsp_halt         = (cxl_pcie_flit_mode)? b_txtl_host_256byte.s_cxl_h2d_rsp_halt  :  b_txtl_host_68byte.s_cxl_h2d_rsp_halt ;
    b_txtl_host.s_cxl_h2d_hdr_halt         = (cxl_pcie_flit_mode)? b_txtl_host_256byte.s_cxl_h2d_hdr_halt  :  b_txtl_host_68byte.s_cxl_h2d_hdr_halt ;
    b_txtl_host.s_cxl_h2d_data_halt        = (cxl_pcie_flit_mode)? b_txtl_host_256byte.s_cxl_h2d_data_halt :  b_txtl_host_68byte.s_cxl_h2d_data_halt;

  b_txtl_host_68byte.s_cxl_m2s_req         = b_txtl_host.s_cxl_m2s_req     ;
  b_txtl_host_68byte.s_cxl_m2s_hdr         = b_txtl_host.s_cxl_m2s_hdr     ;
  b_txtl_host_68byte.s_cxl_m2s_be          = b_txtl_host.s_cxl_m2s_be      ;
  b_txtl_host_68byte.s_cxl_m2s_be_vld_n    = b_txtl_host.s_cxl_m2s_be_vld_n;
  b_txtl_host_68byte.s_cxl_m2s_data_vld    = b_txtl_host.s_cxl_m2s_data_vld;
  b_txtl_host_68byte.s_cxl_m2s_data        = b_txtl_host.s_cxl_m2s_data    ;
  b_txtl_host_68byte.s_cxl_m2s_bi_rsp      = '{default:'0};
  b_txtl_host_256byte.s_cxl_m2s_req        = b_txtl_host.s_cxl_m2s_req     ;
  b_txtl_host_256byte.s_cxl_m2s_hdr        = b_txtl_host.s_cxl_m2s_hdr     ;
  b_txtl_host_256byte.s_cxl_m2s_be         = b_txtl_host.s_cxl_m2s_be      ;
  b_txtl_host_256byte.s_cxl_m2s_be_vld_n   = b_txtl_host.s_cxl_m2s_be_vld_n;
  b_txtl_host_256byte.s_cxl_m2s_data_vld   = b_txtl_host.s_cxl_m2s_data_vld;
  b_txtl_host_256byte.s_cxl_m2s_data       = b_txtl_host.s_cxl_m2s_data    ;
  b_txtl_host_256byte.s_cxl_m2s_bi_rsp     = b_txtl_host.s_cxl_m2s_bi_rsp  ;
  b_txtl_host.s_cxl_m2s_req_halt           = (cxl_pcie_flit_mode)? b_txtl_host_256byte.s_cxl_m2s_req_halt    : b_txtl_host_68byte.s_cxl_m2s_req_halt  ;
  b_txtl_host.s_cxl_m2s_hdr_halt           = (cxl_pcie_flit_mode)? b_txtl_host_256byte.s_cxl_m2s_hdr_halt    : b_txtl_host_68byte.s_cxl_m2s_hdr_halt  ;
  b_txtl_host.s_cxl_m2s_data_halt          = (cxl_pcie_flit_mode)? b_txtl_host_256byte.s_cxl_m2s_data_halt   : b_txtl_host_68byte.s_cxl_m2s_data_halt ;
  b_txtl_host.s_cxl_m2s_bi_rsp_halt        = (cxl_pcie_flit_mode)? b_txtl_host_256byte.s_cxl_m2s_bi_rsp_halt : b_txtl_host_68byte.s_cxl_m2s_bi_rsp_halt ;


  b_txtl_dev_68byte.s_cxl_d2h_req       = b_txtl_dev.s_cxl_d2h_req     ;
  b_txtl_dev_68byte.s_cxl_d2h_rsp       = b_txtl_dev.s_cxl_d2h_rsp     ;
  b_txtl_dev_68byte.s_cxl_d2h_hdr       = b_txtl_dev.s_cxl_d2h_hdr     ;
  b_txtl_dev_68byte.s_cxl_d2h_be        = b_txtl_dev.s_cxl_d2h_be      ;
  b_txtl_dev_68byte.s_cxl_d2h_be_vld_n  = b_txtl_dev.s_cxl_d2h_be_vld_n;
  b_txtl_dev_68byte.s_cxl_d2h_data_vld  = b_txtl_dev.s_cxl_d2h_data_vld;
  b_txtl_dev_68byte.s_cxl_d2h_data      = b_txtl_dev.s_cxl_d2h_data    ;
  b_txtl_dev_256byte.s_cxl_d2h_req      = b_txtl_dev.s_cxl_d2h_req     ;
  b_txtl_dev_256byte.s_cxl_d2h_rsp      = b_txtl_dev.s_cxl_d2h_rsp     ;
  b_txtl_dev_256byte.s_cxl_d2h_hdr      = b_txtl_dev.s_cxl_d2h_hdr     ;
  b_txtl_dev_256byte.s_cxl_d2h_be       = b_txtl_dev.s_cxl_d2h_be      ;
  b_txtl_dev_256byte.s_cxl_d2h_be_vld_n = b_txtl_dev.s_cxl_d2h_be_vld_n;
  b_txtl_dev_256byte.s_cxl_d2h_data_vld = b_txtl_dev.s_cxl_d2h_data_vld;
  b_txtl_dev_256byte.s_cxl_d2h_data     = b_txtl_dev.s_cxl_d2h_data    ;
  b_txtl_dev.s_cxl_d2h_req_halt         = (cxl_pcie_flit_mode)? b_txtl_dev_256byte.s_cxl_d2h_req_halt  : b_txtl_dev_68byte.s_cxl_d2h_req_halt ;
  b_txtl_dev.s_cxl_d2h_rsp_halt         = (cxl_pcie_flit_mode)? b_txtl_dev_256byte.s_cxl_d2h_rsp_halt  : b_txtl_dev_68byte.s_cxl_d2h_rsp_halt ;
  b_txtl_dev.s_cxl_d2h_hdr_halt         = (cxl_pcie_flit_mode)? b_txtl_dev_256byte.s_cxl_d2h_hdr_halt  : b_txtl_dev_68byte.s_cxl_d2h_hdr_halt ;
  b_txtl_dev.s_cxl_d2h_data_halt        = (cxl_pcie_flit_mode)? b_txtl_dev_256byte.s_cxl_d2h_data_halt : b_txtl_dev_68byte.s_cxl_d2h_data_halt;

  b_txtl_dev_68byte.s_cxl_s2m_ndr       = b_txtl_dev.s_cxl_s2m_ndr     ;
  b_txtl_dev_68byte.s_cxl_s2m_hdr       = b_txtl_dev.s_cxl_s2m_hdr     ;
  b_txtl_dev_68byte.s_cxl_s2m_data_vld  = b_txtl_dev.s_cxl_s2m_data_vld;
  b_txtl_dev_68byte.s_cxl_s2m_data      = b_txtl_dev.s_cxl_s2m_data    ;
  b_txtl_dev_68byte.s_cxl_s2m_bi_snp    = '{default:'0};
  b_txtl_dev_256byte.s_cxl_s2m_ndr      = b_txtl_dev.s_cxl_s2m_ndr     ;
  b_txtl_dev_256byte.s_cxl_s2m_hdr      = b_txtl_dev.s_cxl_s2m_hdr     ;
  b_txtl_dev_256byte.s_cxl_s2m_data_vld = b_txtl_dev.s_cxl_s2m_data_vld;
  b_txtl_dev_256byte.s_cxl_s2m_data     = b_txtl_dev.s_cxl_s2m_data    ;
  b_txtl_dev_256byte.s_cxl_s2m_bi_snp   = b_txtl_dev.s_cxl_s2m_bi_snp  ;
  b_txtl_dev.s_cxl_s2m_ndr_halt         = (cxl_pcie_flit_mode)? b_txtl_dev_256byte.s_cxl_s2m_ndr_halt    : b_txtl_dev_68byte.s_cxl_s2m_ndr_halt   ;
  b_txtl_dev.s_cxl_s2m_hdr_halt         = (cxl_pcie_flit_mode)? b_txtl_dev_256byte.s_cxl_s2m_hdr_halt    : b_txtl_dev_68byte.s_cxl_s2m_hdr_halt   ;
  b_txtl_dev.s_cxl_s2m_data_halt        = (cxl_pcie_flit_mode)? b_txtl_dev_256byte.s_cxl_s2m_data_halt   : b_txtl_dev_68byte.s_cxl_s2m_data_halt  ;
  b_txtl_dev.s_cxl_s2m_bi_snp_halt      = (cxl_pcie_flit_mode)? b_txtl_dev_256byte.s_cxl_s2m_bi_snp_halt : b_txtl_dev_68byte.s_cxl_s2m_bi_snp_halt;

  b_llctrl_68byte.s_cxl_ll_cache_mdh_en   = b_llctrl.s_cxl_ll_cache_mdh_en  ;
  b_llctrl_68byte.s_cxl_ll_cache_data_gnt = b_llctrl.s_cxl_ll_cache_data_gnt;
  b_llctrl_68byte.s_cxl_ll_cache_rsp_gnt  = b_llctrl.s_cxl_ll_cache_rsp_gnt ;
  b_llctrl_68byte.s_cxl_ll_cache_req_gnt  = b_llctrl.s_cxl_ll_cache_req_gnt ;
  b_llctrl_68byte.s_cxl_ll_mem_mdh_en     = b_llctrl.s_cxl_ll_mem_mdh_en ;
  b_llctrl_68byte.s_cxl_ll_mem_dr_gnt     = b_llctrl.s_cxl_ll_mem_dr_gnt ;
  b_llctrl_68byte.s_cxl_ll_mem_ndr_gnt    = b_llctrl.s_cxl_ll_mem_ndr_gnt;
  b_llctrl_68byte.s_cxl_ll_mem_bi_gnt     = '0;
  b_llctrl_68byte.s_cxl_hdr_ack_bit       = b_llctrl.s_cxl_hdr_ack_bit  ;
  b_llctrl_68byte.s_cxl_hdr_data_crd      = b_llctrl.s_cxl_hdr_data_crd ;
  b_llctrl_68byte.s_cxl_hdr_rsp_crd       = b_llctrl.s_cxl_hdr_rsp_crd  ;
  b_llctrl_68byte.s_cxl_hdr_req_crd       = b_llctrl.s_cxl_hdr_req_crd  ;
  b_llctrl_68byte.s_cxl_ll_packer_data_en = b_llctrl.s_cxl_ll_packer_data_en;
  b_llctrl_68byte.s_cxl_ll_packer_halt    = b_llctrl.s_cxl_ll_packer_halt   ;
  
  b_llctrl_256byte.s_cxl_ll_cache_mdh_en   = b_llctrl.s_cxl_ll_cache_mdh_en  ;
  b_llctrl_256byte.s_cxl_ll_cache_data_gnt = b_llctrl.s_cxl_ll_cache_data_gnt;
  b_llctrl_256byte.s_cxl_ll_cache_rsp_gnt  = b_llctrl.s_cxl_ll_cache_rsp_gnt ;
  b_llctrl_256byte.s_cxl_ll_cache_req_gnt  = b_llctrl.s_cxl_ll_cache_req_gnt ;
  b_llctrl_256byte.s_cxl_ll_mem_mdh_en     = b_llctrl.s_cxl_ll_mem_mdh_en ;
  b_llctrl_256byte.s_cxl_ll_mem_dr_gnt     = b_llctrl.s_cxl_ll_mem_dr_gnt ;
  b_llctrl_256byte.s_cxl_ll_mem_ndr_gnt    = b_llctrl.s_cxl_ll_mem_ndr_gnt;
  b_llctrl_256byte.s_cxl_ll_mem_bi_gnt     = b_llctrl.s_cxl_ll_mem_bi_gnt ;
  b_llctrl_256byte.s_cxl_hdr_ack_bit       = b_llctrl.s_cxl_hdr_ack_bit  ;
  b_llctrl_256byte.s_cxl_hdr_data_crd      = b_llctrl.s_cxl_hdr_data_crd ;
  b_llctrl_256byte.s_cxl_hdr_rsp_crd       = b_llctrl.s_cxl_hdr_rsp_crd  ;
  b_llctrl_256byte.s_cxl_hdr_req_crd       = b_llctrl.s_cxl_hdr_req_crd  ;
  b_llctrl_256byte.s_cxl_ll_packer_data_en = b_llctrl.s_cxl_ll_packer_data_en;
  b_llctrl_256byte.s_cxl_ll_packer_halt    = b_llctrl.s_cxl_ll_packer_halt   ;


  b_pack.s_cxl_cache_req_valid    = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_cache_req_valid  : b_pack_68byte.s_cxl_cache_req_valid;
  b_pack.s_cxl_cache_rsp_valid    = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_cache_rsp_valid  : b_pack_68byte.s_cxl_cache_rsp_valid;
  b_pack.s_cxl_cache_dhdr_valid   = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_cache_dhdr_valid : b_pack_68byte.s_cxl_cache_dhdr_valid;
  b_pack.s_cxl_mem_ndr_valid      = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_mem_ndr_valid    : b_pack_68byte.s_cxl_mem_ndr_valid     ;
  b_pack.s_cxl_mem_dr_valid       = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_mem_dr_valid     : b_pack_68byte.s_cxl_mem_dr_valid      ;
  b_pack.s_cxl_mem_bi_valid       = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_mem_bi_valid     : b_pack_68byte.s_cxl_mem_bi_valid      ;
  b_pack.s_cxl_packer_valid       = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_packer_valid      : b_pack_68byte.s_cxl_packer_valid      ;
  b_pack.s_cxl_packer_flit        = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_packer_flit       : b_pack_68byte.s_cxl_packer_flit       ;
  b_pack.s_cxl_packer_flit_chk    =  '0; //To be set in RAS Wrapper 
  b_pack.s_cxl_packer_all_data    = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_packer_all_data   : b_pack_68byte.s_cxl_packer_all_data   ;
  b_pack.s_cxl_packer_last        = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_packer_last       : b_pack_68byte.s_cxl_packer_last       ;
  b_pack.s_cxl_packer_idle        = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_packer_idle       : b_pack_68byte.s_cxl_packer_idle       ;
  b_pack.s_cxl_packer_llctrl_halt = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_packer_llctrl_halt: b_pack_68byte.s_cxl_packer_llctrl_halt;
  b_pack.s_cxl_app_pending        = (cxl_pcie_flit_mode)? b_pack_256byte.s_cxl_app_pending       : b_pack_68byte.s_cxl_app_pending       ;
  
end

endmodule : DWC_cxl_mem_cache_packer
