
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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_pkg.svh#7 $
// -------------------------------------------------------------------------
// --- Description: CDM Package
// ---   - Includes structures for the different counter pulses
// -------------------------------------------------------------------------
`ifndef __GUARD__CDM_PKG__SVH__
`define __GUARD__CDM_PKG__SVH__

package cdm_pkg;

typedef struct packed{
  logic ctxram          ;
  logic rbuff           ;
  logic rdbuff_ctrl_dt  ;
  logic radm_bypass_hd  ;
  logic radm_bypass_dt  ;
  logic trgt1_hd        ;
  logic trgt1_dt        ;
  logic radm_trgt1_hd   ;
  logic radm_trgt1_dt   ;
  logic wr_tlpg2trgt_hd ;
  logic rd_tlpg2trgt_hd ;
} edma_ib_error_s;

typedef struct packed{
  logic client1_hd      ;
  logic client1_dt      ;
  logic rd_tlpg2xali_hd ;
  logic client0_hd      ;
  logic client0_dt      ;
  logic client0_ba_hd   ;
} edma_ob_error_s;

typedef struct packed{
  logic cplBuffer              ;
  logic rdEng_ctrl_ll          ;
  logic rdEng_llq_ovrl         ;
  logic rdEng_c2w_lut          ;
  logic rdEng_stsh_lut         ;
  logic rdEng_msi              ;
  logic rdbuff_dt              ;
  logic rdbuff_cpl2mwr_hd      ;
  logic arbiter_bypass_hd      ;
  logic arbiter_trgt_out_hd    ;
  logic arbiter_trgt_in_hd     ;
  logic wrapper_bypass_hd      ;
  logic wrapper_trgt1_hd       ;
} hdma_ib_error_s;

typedef struct packed{
  logic wrEng_ctrl_ll          ;
  logic wrEng_llq_ovrl         ;
  logic wrEng_c2w_lut          ;
  logic wrEng_stsh_lut         ;
  logic wrEng_msi              ;
  logic arbiter_client1_hd     ;
  logic arbiter_client0_out_hd ;
  logic arbiter_client0_in_dt  ;
  logic arbiter_client0_in_hd  ;
  logic wrapper_client1_hd     ;
  logic wrapper_client0_hd     ;
} hdma_ob_error_s;

typedef struct packed{
  logic wreq_ptrk_dt      ;
  logic wreq_ptrk_ad      ;
  logic wreq_ptrk_hdr     ;
  logic wreq_ptrk_data    ;
  logic rreq_ordr         ;
  logic rreq_c2a_cdc      ;
  logic wreq_c2a_cdc      ;
  logic rdq_ordr_ad       ;
  logic rtrgt_ad          ;
  logic rtrgt_dt          ;
  logic wr_dcmp_dt        ;
  logic wr_dcmp_ad        ;
  logic rd_dcmp_ad        ;
  logic wq_mrf_dt         ;
  logic wq_mrf_ad         ;
  logic rd_mrf_ad         ;
  logic mstr_if           ;
} axi_ib_mstr_req_error_s;

typedef struct packed{
  logic rtrgt_p_ad        ;
  logic rtrgt_p_dt        ;
  logic rtrgt_np_ad       ;
  logic rtrgt_np_dt       ;
  logic rtrgt_cpl_ad      ;
  logic rtrgt_cpl_dt      ;
  logic rtrgt_ad          ;
  logic rtrgt_dt          ;
  logic sch_p_ad          ;
  logic sch_p_dt          ;
  logic sch_np_ad         ;
  logic sch_np_dt         ;
  logic sch_p_hdr         ;
  logic sch_p_data        ;
  logic sch_np_hdr        ;
  logic sch_np_data       ;
} axi_ib_sch_error_s;

typedef struct packed{
  logic wreq_ptrk_dt   ;
  logic wreq_ptrk_ad   ;
  logic wreq_ptrk_hdr  ;
  logic wreq_ptrk_data ;
  logic rreq_c2a_cdc   ;
  logic wreq_c2a_cdc   ;
  logic wr_dcmp_dt     ;
  logic wr_dcmp_ad     ;
  logic rd_dcmp_ad     ;
  logic wq_mrf_dt      ;
  logic wq_mrf_ad      ;
  logic rd_mrf_ad      ;
  logic mstrh_if       ;
} axi_ibh_mstr_req_error_s;

typedef struct packed{
  axi_ibh_mstr_req_error_s ibh ;
  axi_ib_mstr_req_error_s  ib  ;
} axi_ib_req_error_s;

typedef struct packed{
  logic wrp_rsp_rob     ;
  logic ob_ccmp_data    ;
  logic ob_cpl_c2a_cdc  ;
  logic rbyp_ad         ;
  logic rbyp_dt         ;
  logic ob_cpl_c2a_dt   ;
  logic ob_cpl_comp_dt  ;
  logic wprordr_wrap_dt ;
} axi_ib_cpl_error_s;

typedef struct packed{
  logic srrq_ad           ;
  logic swrq_ad           ;
  logic npw_sab           ;
  logic ob_npdcmp         ;
  logic ob_pdcmp_hdr      ;
  logic ob_pdcmp_data     ;
  logic swrq_npw_ad       ;
  logic swrq_npw_dt       ;
  logic ob_np_dcmp_inq_dt ;
  logic ob_p_dcmp_inq_dt  ;
  logic c2_ad             ;
  logic c2_dt             ;
  logic c1_ad             ;
  logic c1_dt             ;
  logic npqdec_ad         ;
  logic pqdec_ad          ;
  logic swwrap_dt         ;
  logic swwrap_ad         ;
  logic srwrap_ad         ;
  logic slnull_dt         ;
  logic slnull_ad         ;
  logic slv_if            ;
  logic dbi_if            ;
} axi_ob_req_error_s;

typedef struct packed{
  logic sb         ;
  logic a2c_cdc    ;
  logic sb_dt      ;
  logic a2c_dt     ;
  logic dt         ;
} axi_mcb_mstr_error_s;

typedef struct packed{
  axi_mcb_mstr_error_s hp_mstr;
  axi_mcb_mstr_error_s mstr;
} axi_mcb_error_s;

typedef struct packed{
  hdma_ib_error_s hdma ;
  edma_ib_error_s edma ;
} dma_ib_error_s;

typedef struct packed{
  hdma_ob_error_s hdma ;
  edma_ob_error_s edma ;
} dma_ob_error_s;

typedef struct packed{
  axi_ib_sch_error_s axi_ib_sch ;
  hdma_ib_error_s    hdma_ib    ;
  hdma_ob_error_s    hdma_ob    ;
  edma_ib_error_s    edma_ib    ;
  edma_ob_error_s    edma_ob    ;
  axi_ib_req_error_s axi_ib_req ;
  axi_ib_cpl_error_s axi_ib_cpl ;
  axi_ob_req_error_s axi_ob_req ;
  axi_mcb_error_s    axi_mcb    ;
} app_error_s;

typedef struct packed{
  logic la_hdr ;
} ltim_error_s;

typedef struct packed{
  logic msi_dt ;
  logic reqid  ;
} msigic_error_s;

typedef struct packed{
  logic tlp_prfx    ;
  logic hram_hdr    ;
  logic ltimlr_hdr  ;
  logic appram_rd   ;
  logic ohram_rd    ;
  logic ahram_rd    ;
  logic dram_raspar ;
  logic dram_rd     ;
  logic fdram_rd    ;
  logic sbcram_rd   ;
  logic msi_hdr     ;
  logic trgt_hd     ;
  logic rampop_hdr  ;
  logic outmux_hdr  ;
  logic outmux_dt   ;
} ordrb_error_s;

typedef struct packed{
  ltim_error_s   ltim;
  msigic_error_s msigic;
  ordrb_error_s  ordrb;
} ltim_ordrb_msigic_error_s;


typedef struct packed{
  logic ohram_rd    ;
  logic ahram_rd    ;
  logic dram_rd     ;
  logic fdram_rd    ;
  logic sbcram_rd   ;
} ordrb_error_addr_s;

// FLIT Log 1/2 Registers
typedef struct packed {
  logic [2:0] link_width;
  logic [3:0] flit_offset;
  logic [4:0] cons_error;
  logic unrec_flit;
  logic fec_uncorrectable_err;
  logic [7:0] synd_par_0;
  logic [7:0] synd_chk_0;
  logic [7:0] synd_par_1;
  logic [7:0] synd_chk_1;
  logic [7:0] synd_par_2;
  logic [7:0] synd_chk_2;
} flit_error_log;

endpackage: cdm_pkg

`endif //__GUARD__CDM_PKG__SVH__
