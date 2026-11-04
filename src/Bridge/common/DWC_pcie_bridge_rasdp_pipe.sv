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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/common/DWC_pcie_bridge_rasdp_pipe.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
//  The major funcions:
//  This module gather all ras_dp_err_logs from AXI Bridge (AXI slave,
//  Inbound, Outbound and DTIM) which are in different clock domains and
//  categorize them into 3 classes, master/slave, and core clock interfaces.
//  Multiple Error manager have been used to break the combinational logic and
//  to improve the timing.
//
//                                                                    +---------+
//     Other Core Clk domain logs ----------------------------------->|         |
//                                                                    |         |
//      Slv Logs     +---------------+         +-----------+          |         |
//     -------------->  Slv Err Mgr  |-------->| CDC RAS   |--------->|         |
//                   +---------------+         +-----------+          |         |
//                                                                    |         |
//      Mstr Logs    +---------------+         +-----------+          |         |
//     -------------->  Mstr Err Mgr |-------->| CDC RAS   |--------->|         |
//                   +---------------+         +-----------+          |         |
//                                             +---------------+      |  Core   |
//   ORDRB Logs (core domain) ---------------->|ORDRB Err Mgr  |----->|         |
//                                             +---------------+      |  Err    |------->Output to CDM
//                                                                    |         |
//                                         +-------------------+      |  Mgr    |
//   High Freq Logs (core domain) -------->| High Freq Err Mgr |----->|         |
//                                         +-------------------+      |         |
//                                                                    |         |
//                                             +---------------+      |         |
//   HP Master Logs (core domain) ------------>|HP Mstr Err Mgr|----->|         |
//                                             +---------------+      +---------+
//

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Axi/DWC_pcie_axi_mstr_pkg.svh"
`include "Axi/DWC_pcie_axi_slv_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

 module DWC_pcie_bridge_rasdp_pipe

 import DWC_pcie_axi_mstr_pkg::*;
 import DWC_pcie_axi_slv_pkg::*;
 import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
 import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
 import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 #(
    parameter CORE_RASDP_WAKEUP_WD                                                  = 6
  )
  (
  //------------------------------------------------ Clocks ------------------------------------------------
    input                                                                         core_clk
   ,input                                                                         core_rst_n
   ,output logic [CORE_RASDP_WAKEUP_WD-1:0]                                       core_ras_dp_wake_up
   ,input                                                                         mstr_aclk
   ,input                                                                         mstr_aclk_ug
   ,input                                                                         mstr_aresetn
   ,output logic [1:0]                                                            mstr_ras_dp_wake_up
   ,input                                                                         slv_aclk
   ,input                                                                         slv_aclk_ug
   ,input                                                                         slv_aresetn
   ,output logic [1:0]                                                            slv_ras_dp_wake_up
  //------------------------------------------------ Slave ras_dp_logs -------------------------------------
  //----- slv_rreq -----
   ,input ras_dp_err_log_t                                                        sif_swrq_swwrap_dt_ras_dp_err_log                        /* slv_aclk */
   ,input ras_dp_err_log_t                                                        sif_swrq_swwrap_ad_ras_dp_err_log                        /* slv_aclk */
   ,input ras_dp_err_log_t                                                        sif_srrp_srwrap_ad_ras_dp_err_log                        /* slv_aclk */
   ,input ras_dp_err_log_t                                                        sif_swrq_dt_ras_dp_err_log                               /* slv_aclk */
   ,input ras_dp_err_log_t                                                        sif_swrq_ad_ras_dp_err_log                               /* slv_aclk */
   ,input ras_dp_err_log_t                                                        sif_srsp_rslv_dt_ras_dp_err_log                          /* slv_aclk */
   ,input ras_dp_err_log_t                                                        sif_swrq_npw_dt_ras_dp_err_log                           /* slv_aclk */
   ,input ras_dp_err_log_t                                                        sif_swrq_npw_ad_ras_dp_err_log                           /* slv_aclk */
   ,input ras_dp_err_log_t                                                        sif_recc_npw_sab_ras_dp_err_log                          /* slv_aclk */
  //------------------------------------------------ Outbound ras_dp_logs ----------------------------------
   ,input ras_dp_err_log_t                                                        ob_npdcmp_inq_dt_ras_dp_err_log                          /* slv_aclk */
   ,input ras_dp_err_log_t                                                        ob_recc_cnt_ob_npdcmp_ras_dp_err_log                     /* core_clk */
   ,input ras_dp_err_log_t                                                        ob_recc_cnt_ob_pdcmp_ras_dp_err_log                      /* core_clk */
   ,input ras_dp_err_log_t                                                        ob_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log                  /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_ob_cpl_comp_dt_ras_dp_err_log_g                      /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_ob_recc_cnt_ob_ccmp_dt_ras_dp_log                    /* slv_aclk */
   ,input ras_dp_err_log_t                                                        ob_pdcmp_inq_dt_ras_dp_err_log                           /* slv_aclk */
   ,input ras_dp_err_log_t                                                        ob_pdcmp_ad_ras_dp_err_log                               /* slv_aclk */
   ,input ras_dp_err_log_t                                                        ob_npdcmp_ad_ras_dp_err_log                              /* slv_aclk */
  //----------------------------------------------- Inbound ras_dp_logs ------------------------------------
   //-- mcb --

   ,input ras_dp_err_log_t                                                        mcb_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log              /* core_clk */
   ,input ras_dp_err_log_t                                                        mcb_ib_mcpl_a2c_dt_ras_dp_err_log                        // `ifndef CC_HIGH_FREQUENCY_AXI_MASTER -> master, else core clock

   //-- axi_gm --
   ,input ras_dp_err_log_t                                                        axigm_ibr_rmstr_ad_ras_dp_err_log                        /* core_clk if CC_HIGH_FREQUENCY_AXI_INTERFACE is enabled and mstr_clk if not */
   ,input ras_dp_err_log_t                                                        axigm_ibr_wmstr_ad_ras_dp_err_log                        /* core_clk if CC_HIGH_FREQUENCY_AXI_INTERFACE is enabled and mstr_clk if not */
   ,input ras_dp_err_log_t                                                        axigm_ibr_wmstr_dt_ras_dp_err_log                        /* core_clk if CC_HIGH_FREQUENCY_AXI_INTERFACE is enabled and mstr_clk if not */
   ,input ras_dp_err_log_t                                                        axi_rtrgt_p_ad_ras_dp_err_log                            /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_rtrgt_p_dt_ras_dp_err_log                            /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_rtrgt_np_ad_ras_dp_err_log                           /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_rtrgt_np_dt_ras_dp_err_log                           /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_rtrgt_cpl_ad_ras_dp_err_log                          /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_rtrgt_cpl_dt_ras_dp_err_log                          /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_ib_sch_p_ad_ras_dp_err_log                           /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_ib_sch_p_dt_ras_dp_err_log                           /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_rbyp_ad_ras_dp_err_log_g                             /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_rbyp_dt_ras_dp_err_log_g                             /* core_clk */
   ,input ras_dp_err_log_t                                                        sch_p_data_recc_corr_cnt_ras_dp_err_log                  /* core_clk */
   ,input ras_dp_err_log_t                                                        sch_p_hdr_recc_corr_cnt_ras_dp_err_log                   /* core_clk */

   ,input ras_dp_err_log_t                                                        axi_ib_sch_np_ad_ras_dp_err_log                          /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_ib_sch_np_dt_ras_dp_err_log                          /* core_clk */
   ,input ras_dp_err_log_t                                                        sch_np_data_recc_corr_cnt_ras_dp_err_log                 /* core_clk */
   ,input ras_dp_err_log_t                                                        sch_np_hdr_recc_corr_cnt_ras_dp_err_log                  /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_trgt1_dt_ras_dp_err_log_g                            /* core_clk */
   //-- ibreq --
   ,input ras_dp_err_log_t                                                        rdq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log          /* mstr_aclk */
   ,input ras_dp_err_log_t                                                        wrq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log          /* mstr_aclk */
   ,input ras_dp_err_log_t                                                        axi_mstr_req_rd_ad_ras_dp_err_log_g                      /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_mstr_req_wr_ad_ras_dp_err_log_g                      /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_mstr_req_dt_ras_dp_err_log_g                         /* core_clk */
   ,input ras_dp_err_log_t                                                        axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log                   /* core_clk  */
   ,input ras_dp_err_log_t                                                        mcb_ib_mcpl_sb_dt_ras_dp_err_log                         // master ifndef CC_HIGH_FREQUENCY_AXI_MASTER else core
  //----------------------------------------------- DTIM ras_dp_err_logs -----------------------------------

   ,input ras_dp_err_log_t                                                        axi_ibrd_dcmp_ad_ras_dp_err_log                          /* code_clk */
   ,input ras_dp_err_log_t                                                        axi_ibwr_dcmp_ad_ras_dp_err_log                          /* code_clk */

  //-------------------- Slave intf ras_dp_err_logs --------
   ,input ras_dp_err_log_t                                                        mstr_misb_ras_dp_err_log                                 /* mstr_aclk */
   ,input ras_dp_err_log_t                                                        axi_sisb_aw_ad_ras_dp_err_log                            /* slv_aclk */
   ,input ras_dp_err_log_t                                                        axi_sisb_ar_ad_ras_dp_err_log                            /* slv_aclk */
   ,input ras_dp_err_log_t                                                        axi_sisb_w_dt_ras_dp_err_log                             /* slv_aclk */
   ,input ras_dp_err_log_t                                                        axi_c1_dt_ras_dp_err_log_g                               /* core_clk  u_rasdp */
   ,input ras_dp_err_log_t                                                        axi_c2_dt_ras_dp_err_log_g                               /* core_clk  u_rasdp */
   ,input ras_dp_err_log_t                                                        axi_c1_ad_ras_dp_err_log_g                               /* core_clk  u_rasdp */
   ,input ras_dp_err_log_t                                                        axi_c2_ad_ras_dp_err_log_g                               /* core_clk  u_rasdp */
   ,input ras_dp_err_log_t                                                        axi_ib_mcpl_dt_ras_dp_err_log_g                          /* core_clk  u_rasdp */
   ,input ras_dp_err_inj_t                                                        core_clk_ras_dp_err_inj_from_cdm                         // From the CDM
   ,output ras_dp_err_inj_t                                                       core_clk_ras_dp_err_inj
   ,output ras_dp_err_inj_t                                                       ras_dp_err_inj_slv_aclk
   ,output ras_dp_err_inj_t                                                       ras_dp_err_inj_mstr_aclk

   ,output ras_dp_err_inj_t                                                       core_clk_ordrb_ras_dp_err_inj
   ,output ras_dp_err_inj_t                                                       core_clk_high_freq_ras_dp_err_inj
   ,output ras_dp_err_inj_t                                                       core_clk_hp_mstr_ras_dp_err_inj

   ,output ras_dp_err_log_t                                                       core_clk_ras_dp_err_log_to_cdm                           // Go to the CDM
  );

 // -------------------------------------------------------------------------------------------------------
 // Local parameters declaration
 // -------------------------------------------------------------------------------------------------------
   localparam SYNC_DEPTH  = `CX_PCIE_SYNC_DEPTH;

// Width of bus in slave clock domain
// ------------------------------------
   localparam SLV_ERR_LOG_SYNC_WD   =   3   // ob_pdcmp_inq_dt_ras_dp_err_log,
                                            // ob_pdcmp_ad_ras_dp_err_log,
                                            // ob_npdcmp_ad_ras_dp_err_log
                                        + 6 // sif_swrq_dt_ras_dp_err_log
                                            // sif_swrq_ad_ras_dp_err_log
                                            // sif_srsp_rslv_dt_ras_dp_err_log
                                            // sif_swrq_npw_dt_ras_dp_err_log
                                            // sif_swrq_npw_ad_ras_dp_err_log
                                            // sif_recc_npw_sab_ras_dp_err_log

                                        + 3 // sif_swrq_swwrap_dt_ras_dp_err_log
                                            // sif_swrq_swwrap_ad_ras_dp_err_log
                                            // sif_srrp_srwrap_ad_ras_dp_err_log
                                        + 1  // ob_npdcmp_inq_dt_ras_dp_err_log
                                        + 3 // axi_sisb_aw_ad_ras_dp_err_log
                                            // axi_sisb_ar_ad_ras_dp_err_log
                                            // axi_sisb_w_dt_ras_dp_err_log
                                         + 1 // axi_ob_recc_cnt_ob_ccmp_dt_ras_dp_log
                                        ;
                                        

// Width of bus in master clock domain
// ------------------------------------
   localparam MSTR_ERR_LOG_SYNC_WD =    0
                                        + 2                                      // rdq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log, wrq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log
                                        + 1                                      // mstr_misb_ras_dp_err_log
                                        + 3

                                        + 1

                                      ;

// Width of bus in core clock domain
// ------------------------------------
  localparam ORDRB_ERR_LOG_WD =                                 + 8 // axi_rtrgt_p_ad_ras_dp_err_log
                                     // axi_rtrgt_p_dt_ras_dp_err_log
                                     // axi_rtrgt_np_ad_ras_dp_err_log
                                     // axi_rtrgt_np_dt_ras_dp_err_log
                                     // axi_rtrgt_cpl_ad_ras_dp_err_log
                                     // axi_rtrgt_cpl_dt_ras_dp_err_log
                                     // axi_ib_sch_p_ad_ras_dp_err_log
                                     // axi_ib_sch_p_dt_ras_dp_err_log
                                 + 6  // sch_p_data_recc_corr_cnt_ras_dp_err_log
                                      // sch_p_hdr_recc_corr_cnt_ras_dp_err_log
                                      // axi_ib_sch_np_ad_ras_dp_err_log
                                      // axi_ib_sch_np_dt_ras_dp_err_log
                                      // sch_np_data_recc_corr_cnt_ras_dp_err_log
                                      // sch_np_hdr_recc_corr_cnt_ras_dp_err_log
                                 + 1  // axi_ob_cpl_comp_dt_ras_dp_err_log_g
                               ;

  localparam HIGH_FREQ_SLV_LOGS_WD =                                       1 // ob_recc_cnt_ob_npdcmp_ras_dp_err_log
                                    ;

  localparam HP_MASTER_LOGS_WD =   2  // ob_recc_cnt_ob_pdcmp_ras_dp_err_log,
                                      // ob_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log
                                 + 1 // mcb_ib_mcpl_sb_dt_ras_dp_err_log
                               ;

  localparam CORE_ERR_LOG_SYNC_WD  =  4     // axi_c1_dt_ras_dp_err_log_g
                                            // axi_c2_dt_ras_dp_err_log_g
                                            // axi_c1_ad_ras_dp_err_log_g
                                            // axi_c2_ad_ras_dp_err_log_g
                                       + 1  // mcb_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log
                                        + 1 // axi_trgt1_dt_ras_dp_err_log_g
                                        + 1 // axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log
                                        + 2 // axi_ibrd_dcmp_ad_ras_dp_err_log
                                            // axi_ibwr_dcmp_ad_ras_dp_err_log
                                        + 2 // slv_clk_ras_dp_err_log_to_err_mgr
                                            // mstr_clk_ras_dp_err_log_to_err_mgr
                                        + 3 // axi_mstr_req_rd_ad_ras_dp_err_log_g
                                            // axi_mstr_req_wr_ad_ras_dp_err_log_g
                                            // axi_mstr_req_dt_ras_dp_err_log_g
                                        + 4 // axi_ib_mcpl_dt_ras_dp_err_log_g
                                            // ordrb_ras_dp_err_logs_out
                                            // high_freq_axi_slv_logs_out
                                            // hp_master_logs_out
                                        ;

 // -------------------------------------------------------------------------------------------------------
 // Wires
 // -------------------------------------------------------------------------------------------------------
  ras_dp_err_log_t [SLV_ERR_LOG_SYNC_WD-1:0]                           slv_clk_ras_dp_err_logs;
  ras_dp_err_log_t [MSTR_ERR_LOG_SYNC_WD-1:0]                          mstr_clk_ras_dp_err_logs;
  ras_dp_err_log_t [CORE_ERR_LOG_SYNC_WD-1:0]                          core_clk_ras_dp_err_logs;
  ras_dp_err_log_t [ORDRB_ERR_LOG_WD-1:0]                              ordrb_ras_dp_err_logs;
  ras_dp_err_log_t [HIGH_FREQ_SLV_LOGS_WD-1:0]                         high_freq_axi_slv_logs;
  ras_dp_err_log_t [HP_MASTER_LOGS_WD-1:0]                             hp_master_logs;

  // Err Mgr output wires
  ras_dp_err_log_t                                                     ordrb_ras_dp_err_logs_out   ;
  ras_dp_err_log_t                                                     high_freq_axi_slv_logs_out  ;
  ras_dp_err_log_t                                                     hp_master_logs_out          ;

  ras_dp_err_log_t                                                     slv_clk_ras_dp_err_log_to_cdc;
  ras_dp_err_log_t                                                     mstr_clk_ras_dp_err_log_to_cdc;
  ras_dp_err_log_t                                                     slv_clk_ras_dp_err_log_to_err_mgr;
  ras_dp_err_log_t                                                     mstr_clk_ras_dp_err_log_to_err_mgr;
  ras_dp_err_inj_t                                                     slv_clk_ras_dp_err_inj;
  ras_dp_err_inj_t                                                     mstr_clk_ras_dp_err_inj;


// --- Gathering all slave clock domain ras_dp_err_log(s) ----
  assign slv_clk_ras_dp_err_logs = {                                       sif_swrq_dt_ras_dp_err_log,
                                       sif_swrq_ad_ras_dp_err_log,
                                       sif_srsp_rslv_dt_ras_dp_err_log,
                                       sif_swrq_npw_dt_ras_dp_err_log,
                                       sif_swrq_npw_ad_ras_dp_err_log,
                                       sif_recc_npw_sab_ras_dp_err_log,
                                       sif_swrq_swwrap_dt_ras_dp_err_log,
                                       sif_swrq_swwrap_ad_ras_dp_err_log,
                                       sif_srrp_srwrap_ad_ras_dp_err_log,
                                       ob_npdcmp_inq_dt_ras_dp_err_log,
                                       axi_sisb_aw_ad_ras_dp_err_log,
                                       axi_sisb_ar_ad_ras_dp_err_log,
                                       axi_sisb_w_dt_ras_dp_err_log,
                                       axi_ob_recc_cnt_ob_ccmp_dt_ras_dp_log,
                                       ob_pdcmp_inq_dt_ras_dp_err_log,
                                       ob_pdcmp_ad_ras_dp_err_log,
                                       ob_npdcmp_ad_ras_dp_err_log
                                   };
                                   
// --- Gathering all dbi clock domain ras_dp_err_log(s) ----

// --- Gathering all master clock domain ras_dp_err_log(s) ----
  assign mstr_clk_ras_dp_err_logs= {                                          rdq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log
                                        , wrq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log
                                        , mstr_misb_ras_dp_err_log
                                        , axigm_ibr_rmstr_ad_ras_dp_err_log
                                        , axigm_ibr_wmstr_ad_ras_dp_err_log
                                        , axigm_ibr_wmstr_dt_ras_dp_err_log

                                        , mcb_ib_mcpl_a2c_dt_ras_dp_err_log

                                   };

  assign core_clk_ras_dp_err_logs = {     axi_c1_dt_ras_dp_err_log_g
                                        , axi_c2_dt_ras_dp_err_log_g
                                        , axi_c1_ad_ras_dp_err_log_g
                                        , axi_c2_ad_ras_dp_err_log_g
                                        , mcb_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log
                                        , axi_trgt1_dt_ras_dp_err_log_g
                                        , axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log
                                        , axi_ibrd_dcmp_ad_ras_dp_err_log
                                        , axi_ibwr_dcmp_ad_ras_dp_err_log
                                        , slv_clk_ras_dp_err_log_to_err_mgr
                                        , mstr_clk_ras_dp_err_log_to_err_mgr
                                        , axi_mstr_req_rd_ad_ras_dp_err_log_g
                                        , axi_mstr_req_wr_ad_ras_dp_err_log_g
                                        , axi_mstr_req_dt_ras_dp_err_log_g
                                        , axi_ib_mcpl_dt_ras_dp_err_log_g
                                        , ordrb_ras_dp_err_logs_out
                                        , high_freq_axi_slv_logs_out
                                        , hp_master_logs_out
                                      };

  assign ordrb_ras_dp_err_logs = {
                                   axi_rtrgt_p_ad_ras_dp_err_log
                                 , axi_rtrgt_p_dt_ras_dp_err_log
                                 , axi_rtrgt_np_ad_ras_dp_err_log
                                 , axi_rtrgt_np_dt_ras_dp_err_log
                                 , axi_rtrgt_cpl_ad_ras_dp_err_log
                                 , axi_rtrgt_cpl_dt_ras_dp_err_log
                                 , axi_ib_sch_p_ad_ras_dp_err_log
                                 , axi_ib_sch_p_dt_ras_dp_err_log
                                 , sch_p_data_recc_corr_cnt_ras_dp_err_log
                                 , sch_p_hdr_recc_corr_cnt_ras_dp_err_log
                                 , axi_ib_sch_np_ad_ras_dp_err_log
                                 , axi_ib_sch_np_dt_ras_dp_err_log
                                 , sch_np_data_recc_corr_cnt_ras_dp_err_log
                                 , sch_np_hdr_recc_corr_cnt_ras_dp_err_log
                                 , axi_ob_cpl_comp_dt_ras_dp_err_log_g
  };

  assign high_freq_axi_slv_logs = {                                        ob_recc_cnt_ob_npdcmp_ras_dp_err_log
                                  };

  assign hp_master_logs         = {
                                    ob_recc_cnt_ob_pdcmp_ras_dp_err_log
                                  , ob_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log
                                  , mcb_ib_mcpl_sb_dt_ras_dp_err_log
  };



  // RAS DP CDC
  // ---------------------------------------------------------------
  
  ras_cdc
  
  #(
     .F_SYNC_TYPE                   (SYNC_DEPTH                        )
    ,.R_SYNC_TYPE                   (SYNC_DEPTH                        )
   ) u_ras_cdc_slv_clk_logs (
     // source side
      .clk_ch                       (slv_aclk                          )
     ,.rst_ch_n                     (slv_aresetn                       )
     ,.out_ras_dp_err_inj           (slv_clk_ras_dp_err_inj            )
     ,.out_ras_dp_wake_up_ch        (slv_ras_dp_wake_up[1]             )
     ,.in_ras_dp_err_log            (slv_clk_ras_dp_err_log_to_cdc     )
     // destination side
     ,.clk_tr                       (core_clk                          )
     ,.rst_tr_n                     (core_rst_n                        )
     ,.in_ras_dp_err_inj            (core_clk_ras_dp_err_inj)
     ,.out_ras_dp_wake_up_tr        (core_ras_dp_wake_up[0]            )
     ,.out_ras_dp_err_log           (slv_clk_ras_dp_err_log_to_err_mgr )
   );

  ras_cdc
  
  #(
     .F_SYNC_TYPE                   (SYNC_DEPTH                         )
    ,.R_SYNC_TYPE                   (SYNC_DEPTH                         )
   ) u_ras_cdc_mstr_clk_logs (
     // source side
      .clk_ch                       (mstr_aclk                          )
     ,.rst_ch_n                     (mstr_aresetn                       )
     ,.out_ras_dp_err_inj           (mstr_clk_ras_dp_err_inj            )
     ,.out_ras_dp_wake_up_ch        (mstr_ras_dp_wake_up[1]             )
     ,.in_ras_dp_err_log            (mstr_clk_ras_dp_err_log_to_cdc     )
     // destination side
     ,.clk_tr                       (core_clk                           )
     ,.rst_tr_n                     (core_rst_n                         )
     ,.in_ras_dp_err_inj            (core_clk_ras_dp_err_inj            )
     ,.out_ras_dp_wake_up_tr        (core_ras_dp_wake_up[1]             )
     ,.out_ras_dp_err_log           (mstr_clk_ras_dp_err_log_to_err_mgr )
   );

  // Ras DP Error Managers
  // ----------------------------------------------------------------
  // slave clk logs
  // ---------------
  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (SLV_ERR_LOG_SYNC_WD       ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1                         )
  ) u_slv_ras_dp_err_mgr (
    .clk                        (slv_aclk_ug                   )
   ,.rst_n                      (slv_aresetn                   )
   ,.out_ras_dp_wake_up         (slv_ras_dp_wake_up[0]         )
   ,.in_ras_dp_err_inj          (slv_clk_ras_dp_err_inj        )
   ,.out_ras_dp_err_inj         (ras_dp_err_inj_slv_aclk       )
  ,.in_ras_dp_err_log           (slv_clk_ras_dp_err_logs       )
  ,.out_ras_dp_err_log          (slv_clk_ras_dp_err_log_to_cdc )
   );
   

  // master clk logs
  // ---------------
  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (MSTR_ERR_LOG_SYNC_WD      ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1                         )
  ) u_mstr_ras_dp_err_mgr (
    .clk                        (mstr_aclk_ug                  )
   ,.rst_n                      (mstr_aresetn                  )
   ,.out_ras_dp_wake_up         (mstr_ras_dp_wake_up[0]        )
   ,.in_ras_dp_err_inj          (mstr_clk_ras_dp_err_inj       )
   ,.out_ras_dp_err_inj         (ras_dp_err_inj_mstr_aclk      )
  ,.in_ras_dp_err_log           (mstr_clk_ras_dp_err_logs      )
  ,.out_ras_dp_err_log          (mstr_clk_ras_dp_err_log_to_cdc)
   );

  // core clk logs
  // ---------------
  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (ORDRB_ERR_LOG_WD          ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1                         )
  ) u_core_ordrb_err_mgr (
    .clk                        (core_clk                      )
   ,.rst_n                      (core_rst_n                    )
   ,.out_ras_dp_wake_up         (core_ras_dp_wake_up[2]        )
   ,.in_ras_dp_err_inj          (core_clk_ras_dp_err_inj       )
   ,.out_ras_dp_err_inj         (core_clk_ordrb_ras_dp_err_inj )
  ,.in_ras_dp_err_log           (ordrb_ras_dp_err_logs         )
  ,.out_ras_dp_err_log          (ordrb_ras_dp_err_logs_out     )
   );

  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (HIGH_FREQ_SLV_LOGS_WD        ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1                            )
  ) u_core_high_freq_slv_err_mgr (
    .clk                        (core_clk                         )
   ,.rst_n                      (core_rst_n                       )
   ,.out_ras_dp_wake_up         (core_ras_dp_wake_up[3]           )
   ,.in_ras_dp_err_inj          (core_clk_ras_dp_err_inj          )
   ,.out_ras_dp_err_inj         (core_clk_high_freq_ras_dp_err_inj)
  ,.in_ras_dp_err_log           (high_freq_axi_slv_logs           )
  ,.out_ras_dp_err_log          (high_freq_axi_slv_logs_out       )
   );

  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (HP_MASTER_LOGS_WD           ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1                           )
  ) u_core_hp_master_err_mgr (
    .clk                        (core_clk                        )
   ,.rst_n                      (core_rst_n                      )
   ,.out_ras_dp_wake_up         (core_ras_dp_wake_up[4]          )
   ,.in_ras_dp_err_inj          (core_clk_ras_dp_err_inj         )
   ,.out_ras_dp_err_inj         (core_clk_hp_mstr_ras_dp_err_inj )
  ,.in_ras_dp_err_log           (hp_master_logs                  )
  ,.out_ras_dp_err_log          (hp_master_logs_out              )
   );

  // the main err mgr
  ras_dp_err_mgr
  
  #(
   .BLOCK_RAS_DP_PROT_CHK_N         (CORE_ERR_LOG_SYNC_WD        ),
   .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1                           )
  ) u_core_ras_dp_err_mgr (
    .clk                        (core_clk                        )
   ,.rst_n                      (core_rst_n                      )
   ,.out_ras_dp_wake_up         (core_ras_dp_wake_up[5]          )
   ,.in_ras_dp_err_inj          (core_clk_ras_dp_err_inj_from_cdm)
   ,.out_ras_dp_err_inj         (core_clk_ras_dp_err_inj         )
  ,.in_ras_dp_err_log           (core_clk_ras_dp_err_logs        )
  ,.out_ras_dp_err_log          (core_clk_ras_dp_err_log_to_cdm  )
   );

endmodule
