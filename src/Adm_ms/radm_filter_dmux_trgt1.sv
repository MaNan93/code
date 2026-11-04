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
// ---    $DateTime: 2024/01/26 07:16:49 $
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_filter_dmux_trgt1.sv#11 $
// -------------------------------------------------------------------------
// -------------------------------------------------------------------------
//Description: 
//This moduls is TOP module of posted,Non-Posted and Completion TLP typeof single VC. 
//This module is instantiates following modules -  
//    - Intergated top of posted module
//    - Intergated top of NON-posted module
//    - Intergated top of Completion module
//      radm_filter_dmux_trgt1 
//         |
//          radm_filter_dmux_trgt1_p
//          radm_filter_dmux_trgt1_np
//          radm_filter_dmux_trgt1_cpl
//--------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/pcie_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module radm_filter_dmux_trgt1
  import pcie_pkg::E_P;
  import pcie_pkg::E_NP;
  import pcie_pkg::E_CPL;
  import radm_ms_pkg::PKT_ORD_WD;
  import radm_ms_pkg::FILTER_DEMUX_TRGT1_P_CHK_CNTS;
  import radm_ms_pkg::FILTER_DEMUX_TRGT1_NP_CHK_CNTS;
  import radm_ms_pkg::FILTER_DEMUX_TRGT1_CPL_CHK_CNTS;
  import radm_ms_pkg::FILTER_DEMUX_TRGT1_CKH_CNTS;
  import radm_ms_pkg::N_TRGT1_INTF;
  import radm_ms_pkg::FX_TLP;
  import radm_ms_pkg::INT_HDW;
  import radm_ms_pkg::radm_cfg_atu_s;
  import radm_ms_pkg::radm_cfg_i_s;
  import radm_ms_pkg::radm_cfg_ntlp_i_s;
  import radm_ms_pkg::radm_cfg_ntlp_nf_s;
  import radm_ms_pkg::radm_cfg_tlp_i_s;
  import radm_ms_pkg::radm_cfg_ntlp_o_s;
  import radm_ms_pkg::radm_cfg_tlp_o_s;
  import radm_ms_pkg::trgt_grnt_trgt1_s;
  import radm_ms_pkg::radm_ord_mgr_flt_data_s;
  import radm_ms_pkg::flt_q_dmux_o_s;
  import radm_ms_pkg::flt_cpl_lut_s;
  import radm_ms_pkg::radm_crd_restore_s;
  import radm_ms_pkg::trgt1_p_out_s;
  import radm_ms_pkg::trgt1_np_out_s;
  import radm_ms_pkg::trgt1_cpl_out_s;
  import radm_ms_pkg::trgt_clkg_ctrl_s;
  import radm_ms_pkg::radm_rx_tlp_s;
  import radm_ms_pkg::rtrgt1_tlp_out_s;
  import radm_ms_pkg::pktstr_hlog_s;
  //import radm_ms_pkg ends
  //////////////////////////////////////////
`ifndef SYNTHESIS
`endif
  //////////////////////////////////////////
  //import DWC_pcie_ctl_pkg starts
  import DWC_pcie_ctl_pkg::NW;
  import DWC_pcie_ctl_pkg::PF_WD;  
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::TAG_SIZE;
  import DWC_pcie_ctl_pkg::NVF  ;
  import DWC_pcie_ctl_pkg::VF_WD;
  import DWC_pcie_ctl_pkg::VFI_WD;

   import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD;
  //import DWC_pcie_ctl_pkg ends
  /////////////////////////////////////
  /////////////////////////////////////
  //import DWC_pcie_core_pkg starts
  import DWC_pcie_core_pkg::CCIX_WD;
  //import DWC_pcie_core_pkg ends
  ////////////////////////////////////
//-----------------------------------------------------------------------------
// Parameter declaration
//-----------------------------------------------------------------------------
#(
  parameter RAS_DP_PROT_CHK_ID_BASE  = 0
)
//-----------------------------------------------------------------------------
// I/O Declaration
//-----------------------------------------------------------------------------
  
                               ( 

    // Configurations 
    input  radm_cfg_i_s                                 radm_cfg_i,
    input  radm_cfg_ntlp_i_s                            radm_cfg_ntpl_i,


    output radm_cfg_ntlp_o_s                            radm_cfg_o,
    output logic [2*64-1:0]                             flt_cdm_addr_o,                          
    output logic [2-1:0]                                flt_cdm_addr_valid_o,                          
    // Configurations end

    input radm_rx_tlp_s  [2:0]                          rx_tlp,          // Received TLP struct, from OutQ/IDE, to filter

    /// Posted
    input                                               core_clk,
    input                                               radm_clk_ug,
    input                                               core_rst_n,
    input                                               non_sticky_rst_n,
    input                                               flit_mode, 
    // Filter I/O                         
    input                                               app_req_retry_en,
    input    [NF-1 : 0]                                 app_pf_req_retry_en,

    //  `ifdef CX_CCIX_INTERFACE_ENABLE
    //    input [CCIX_WD-1:0]                           hdr_dec_flt_hdr_p_ccix_tlp,
    //  `endif // CX_CCIX_INTERFACE_ENABLE

    // ATU
    input radm_cfg_atu_s                                radm_cfg_atu_in,
    // ATU end


    output  logic  [51:0]                               rcrb_base_addr,             // Indicates the base address for the RCRB region. The upper address bits[63:12] of the first memory access received after link initialization is the RCRB base address
    output  logic                                       rcrb_base_addr_valid,       // Indicates the base address valid for the RCRB region
  // ------------------------------------------------------------------------------------
  // Header Logging Interface
    output flt_q_dmux_o_s                               flt_q_log_p_o,
    output flt_q_dmux_o_s                               flt_q_log_np_o,
    output flt_q_dmux_o_s                               flt_q_log_cpl_o,
    input  logic                                        log_halt_p,
    input  logic                                        log_halt_np,
    input  logic                                        log_halt_cpl,
  //------------------------------------------//
    input                                               trgt0_radm_halt_int_p,
    output  logic [INT_HDW -1:0]                        dmux_trgt0_req_p,
    output  logic                                       dmux_trgt0_fifo_pipe_empty_p,
    input                                               trgt1_radm_intf_halt_p,
    output trgt1_p_out_s                                radm_trgt1_out_p,
    output radm_crd_restore_s                           pktadj_crdmgr_crd_restore_p,
    // Posted End

    // Non-Posted start   
    // Filter I/O 
    // `ifdef CX_CCIX_INTERFACE_ENABLE
    //   input [CCIX_WD-1:0]                            hdr_dec_flt_np_ccix_tlp,
    // `endif // CX_CCIX_INTERFACE_ENABLE
    //------------------------------------------//    
    input                                               trgt0_radm_halt_int_np,
    output  logic [INT_HDW -1:0]                        dmux_trgt0_req_np,
    input                                               trgt1_radm_intf_halt_np,
    output trgt1_np_out_s                               radm_trgt1_out_np,
    output radm_crd_restore_s                           pktadj_crdmgr_crd_restore_np,

    /// For completion 
    // Filter I/O 
    //  `ifdef CX_CCIX_INTERFACE_ENABLE
    //    input [CCIX_WD-1:0]                           hdr_dec_flt_hdr_ccix_tlp_cpl,
    //  `endif // CX_CCIX_INTERFACE_ENABLE
    input                                               cpl_mlf_err_cpl,
    input                                               flt_q_cpl_last_cpl,
    input                                               cpl_ur_err_cpl,
    input                                               cpl_ca_err_cpl,
    input                                               lut_filt_cpl_abort,
    input                                               unexpected_cpl_err_cpl,
    input  [NP_REQ_TX_TYPE_WD-1:0]                      lut_flt_np_req_type,
    output [NP_REQ_TX_TYPE_WD-1:0]                      flt_xadm_np_req_type_o,

    // ---- outputs ---------------
    //radm_ecrc_err,
    //radm_mlf_tlp_err,
    //radm_mlf_tlp_err_ptr
    //radm_tlp_prfx_log
    // `ifdef CX_SRIOV_ENABLE
    //   output logic                                   radm_rcvd_cpl_ca_vf_cpl
    // `endif // CX_SRIOV_ENABLE
    //------------------------------------------//
    output logic                                        cpl_tlp_cpl,
    output logic  [TAG_SIZE-1:0]                        flt_q_rcvd_cpl_tlp_tag_cpl,
    output logic  [2:0]                                 cpl_status_cpl,

    output logic                                        flt_dwlenEq0_cpl,
    output logic                                        rtlh_radm_ecrc_err_cpl,
    output logic                                        rtlh_radm_malform_tlp_err_cpl,
    input                                               trgt1_radm_intf_halt_cpl,
    output trgt1_cpl_out_s                              radm_trgt1_out_cpl,
    output radm_crd_restore_s                           pktadj_crdmgr_crd_restore_cpl,

    output flt_cpl_lut_s                                flt_cpl_lut,
    // Demux Clock Gating Control Signals
    output trgt_clkg_ctrl_s                             trgt_clkg_ctrl, // [CPL,NP,P]
`ifndef SYNTHESIS
    // Outputs to testbench
    output logic                                        flt_pkt_num_p_valid,
    output logic [PKT_ORD_WD-1:0]                       flt_pkt_num_p,

    output logic                                        flt_pkt_num_np_valid,
    output logic [PKT_ORD_WD-1:0]                       flt_pkt_num_np,

    output logic                                        flt_pkt_num_cpl_valid,
    output logic [PKT_ORD_WD-1:0]                       flt_pkt_num_cpl,

`endif
    input logic  [3-1:0]                                ecrc_err_inj_enable,
    output logic [3-1:0]                                ecrc_pkt_eot_with_vld_td,
    output trgt_grnt_trgt1_s                            trgt_grnt_trgt1
    ,output ras_dp_err_log_t   [FILTER_DEMUX_TRGT1_CKH_CNTS-1:0]                 ras_dp_err_log
    ,input  ras_dp_err_inj_t                            ras_dp_err_inj
  );

  //------------------------ signal decalration -------------------------------------
  // configurations
  radm_cfg_tlp_i_s  [1:0] radm_cfg_i_int;
  radm_cfg_tlp_o_s  [2:0] radm_cfg_o_int;
  //================================================================================
  // This block segregate input configurations as each input configuration consists of 3 tlp i.e cpl, non-posted & posted
  // and concatenate config output coming from cpl, np & posted into single bus and sends out.
      
   radm_cfg_ntlp_nf_s                           radm_cfg_ntpl_nf;
   logic [64-1:0]                               flt_cdm_addr_int [1:0];   
   logic [1:0]                                  flt_cdm_addr_valid_int;   

always_comb begin : remap_per_tlp_to_per_func
    integer i,j;
    radm_cfg_ntpl_nf.cfg_io_match = 0;
    radm_cfg_ntpl_nf.cfg_bar_match = 0;
    radm_cfg_ntpl_nf.cfg_rom_match = 0;
    radm_cfg_ntpl_nf.cfg_config_above_match = 0;
    radm_cfg_ntpl_nf.cfg_rcrb_match            = radm_cfg_ntpl_i.cfg_rcrb_match;
    radm_cfg_ntpl_nf.cxl_2_0_mbar0_access_int  = radm_cfg_ntpl_i.cxl_2_0_mbar0_access_int;
    radm_cfg_ntpl_nf.cfg_rcrb_mbar0_match      = radm_cfg_ntpl_i.cfg_rcrb_mbar0_match;
    radm_cfg_ntpl_nf.cfg_rcrb_mbar0_match_int  = radm_cfg_ntpl_i.cfg_rcrb_mbar0_match_int;
    for(i = 0; i < FX_TLP-N_TRGT1_INTF; i = i + 1) begin
        for(j = 0; j < NF; j = j + 1) begin
            radm_cfg_ntpl_nf.cfg_io_match[i*NF+j]                =
                radm_cfg_ntpl_i.cfg_io_match[i+j*(FX_TLP-N_TRGT1_INTF)];
            radm_cfg_ntpl_nf.cfg_bar_match[6*(i*NF+j) +: 6]      =
                radm_cfg_ntpl_i.cfg_bar_match[6*i+j*6*(FX_TLP-N_TRGT1_INTF) +: 6];
            radm_cfg_ntpl_nf.cfg_rom_match[i*NF+j]               =
                radm_cfg_ntpl_i.cfg_rom_match[i+j*(FX_TLP-N_TRGT1_INTF)];
            radm_cfg_ntpl_nf.cfg_config_above_match[i*NF+j]      =
                radm_cfg_ntpl_i.cfg_config_above_match[i+j*(FX_TLP-N_TRGT1_INTF)];
            radm_cfg_ntpl_nf.cfg_mem_match[i*NF+j]               =
                radm_cfg_ntpl_i.cfg_mem_match[i+j*(FX_TLP-N_TRGT1_INTF)];
            radm_cfg_ntpl_nf.cfg_prefmem_match[i*NF+j]           =
                radm_cfg_ntpl_i.cfg_prefmem_match[i+j*(FX_TLP-N_TRGT1_INTF)];
            radm_cfg_ntpl_nf.cfg_cxl_mbar0_match[i][j]           = radm_cfg_ntpl_i.cfg_cxl_mbar0_match[j][i];
            radm_cfg_ntpl_nf.cfg_cxl_alt_mem_match[i*NF+j]       = radm_cfg_ntpl_i.cfg_cxl_alt_mem_match[i+j*(FX_TLP-N_TRGT1_INTF)];
            radm_cfg_ntpl_nf.cfg_cxl_alt_prefmem_match[i*NF+j]   = radm_cfg_ntpl_i.cfg_cxl_alt_prefmem_match[i+j*(FX_TLP-N_TRGT1_INTF)];
        end
    end
end

  always_comb begin
    for (int i = 0; i < 2; i = i + 1) begin
      // configurations
      radm_cfg_i_int[i].cfg_io_match                      =  radm_cfg_ntpl_nf.cfg_io_match[i*NF+NF-1 -: NF];            
      radm_cfg_i_int[i].cfg_config_above_match            =  radm_cfg_ntpl_nf.cfg_config_above_match[i*NF+NF-1 -: NF];
      radm_cfg_i_int[i].cfg_bar_match                     =  radm_cfg_ntpl_nf.cfg_bar_match[i*NF*6+NF*6-1 -: NF*6];      
      radm_cfg_i_int[i].cfg_rom_match                     =  radm_cfg_ntpl_nf.cfg_rom_match[i*NF+NF-1 -: NF];
      radm_cfg_i_int[i].cfg_mem_match                     = radm_cfg_ntpl_nf.cfg_mem_match[i*NF+NF-1 -: NF];
      radm_cfg_i_int[i].cfg_prefmem_match                 = radm_cfg_ntpl_nf.cfg_prefmem_match[i*NF+NF-1 -: NF];
      radm_cfg_i_int[i].cfg_rcrb_match                    = radm_cfg_ntpl_nf.cfg_rcrb_match[i];
      radm_cfg_i_int[i].cfg_cxl_mbar0_match               = radm_cfg_ntpl_nf.cfg_cxl_mbar0_match[i];
      radm_cfg_i_int[i].cxl_2_0_mbar0_access_int          = radm_cfg_ntpl_nf.cxl_2_0_mbar0_access_int[i];
      radm_cfg_i_int[i].cfg_cxl_alt_mem_match             = radm_cfg_ntpl_nf.cfg_cxl_alt_mem_match[i*NF+NF-1 -: NF];
      radm_cfg_i_int[i].cfg_cxl_alt_prefmem_match         = radm_cfg_ntpl_nf.cfg_cxl_alt_prefmem_match[i*NF+NF-1 -: NF];
      radm_cfg_i_int[i].cfg_rcrb_mbar0_match              = radm_cfg_ntpl_nf.cfg_rcrb_mbar0_match[i];
      radm_cfg_i_int[i].cfg_rcrb_mbar0_match_int          = radm_cfg_ntpl_nf.cfg_rcrb_mbar0_match_int[i];
     flt_cdm_addr_o[i*64+64-1 -: 64]                      =  flt_cdm_addr_int[i]; 
     flt_cdm_addr_valid_o[i]                              =  flt_cdm_addr_valid_int[i]; 
  end
end
  always_comb begin
    for (int i = 0; i < 3; i = i + 1) begin
      // configurations
    //  radm_cfg_i_int[i].cfg_p2p_err_rpt_ctrl  = radm_cfg_ntpl_i.cfg_p2p_err_rpt_ctrl[i];

//`ifdef CX_DPC_ENABLE
//
//        radm_cfg_i_int[i].dpc_nonfatal_err_gate                 =  radm_cfg_ntpl_i.dpc_nonfatal_err_gate[i]; 
//        radm_cfg_i_int[i].dpc_fatal_err_gate                    =  radm_cfg_ntpl_i.dpc_fatal_err_gate[i]; 
//        radm_cfg_i_int[i].cdm_core_in_dpc                       =  radm_cfg_ntpl_i.cdm_core_in_dpc[i]; 
//`endif // CX_DPC_ENABLE




      // ---- outputs ---------------
    //
      radm_cfg_o.radm_inta_asserted[i]              =  radm_cfg_o_int[i].radm_inta_asserted; 
      radm_cfg_o.radm_intb_asserted[i]              =  radm_cfg_o_int[i].radm_intb_asserted; 
      radm_cfg_o.radm_intc_asserted[i]              =  radm_cfg_o_int[i].radm_intc_asserted; 
      radm_cfg_o.radm_intd_asserted[i]              =  radm_cfg_o_int[i].radm_intd_asserted; 
      radm_cfg_o.radm_inta_deasserted[i]            =  radm_cfg_o_int[i].radm_inta_deasserted; 
      radm_cfg_o.radm_intb_deasserted[i]            =  radm_cfg_o_int[i].radm_intb_deasserted; 
      radm_cfg_o.radm_intc_deasserted[i]            =  radm_cfg_o_int[i].radm_intc_deasserted; 
      radm_cfg_o.radm_intd_deasserted[i]            =  radm_cfg_o_int[i].radm_intd_deasserted; 
      radm_cfg_o.radm_err_cor[i]                    =  radm_cfg_o_int[i].radm_err_cor; 
      radm_cfg_o.radm_err_nf[i]                     =  radm_cfg_o_int[i].radm_err_nf; 
      radm_cfg_o.radm_err_f[i]                      =  radm_cfg_o_int[i].radm_err_f; 

      radm_cfg_o.radm_drs_msg[i]                    = radm_cfg_o_int[i].radm_drs_msg;
      radm_cfg_o.radm_frs_msg_reason[i*4+3 -: 4]    = radm_cfg_o_int[i].radm_frs_msg_reason;
      radm_cfg_o.radm_frs_msg[i]                    = radm_cfg_o_int[i].radm_frs_msg;

      radm_cfg_o.radm_msg_ltr[i]                      = radm_cfg_o_int[i].radm_msg_ltr;
      radm_cfg_o.radm_msg_ltr_latency[i*32+31 -: 32]  = radm_cfg_o_int[i].radm_msg_ltr_latency;

        radm_cfg_o.radm_ptm_req[i]                                         =  radm_cfg_o_int[i].radm_ptm_req; 
        radm_cfg_o.radm_ptm_res_msg[i]                                         =  radm_cfg_o_int[i].radm_ptm_res_msg; 
        radm_cfg_o.radm_ptm_res_d_msg[i]                                       =  radm_cfg_o_int[i].radm_ptm_res_d_msg; 
        radm_cfg_o.radm_ptm_master_time[i*64+64-1 -: 64]                       =  radm_cfg_o_int[i].radm_ptm_master_time; 
        radm_cfg_o.radm_ptm_prop_delay[i*32+32-1 -: 32]                        =  radm_cfg_o_int[i].radm_ptm_prop_delay; 
      radm_cfg_o.flt_cdm_pf[i*PF_WD+PF_WD-1 -: PF_WD]                           =  radm_cfg_o_int[i].flt_cdm_pf;
      radm_cfg_o.radm_ecrc_err[i]                                               =  radm_cfg_o_int[i].radm_ecrc_err; 
      radm_cfg_o.radm_mlf_tlp_err[i]                                            =  radm_cfg_o_int[i].radm_mlf_tlp_err; 
        radm_cfg_o.radm_mlf_tlp_err_ptr[i*8+7 -: 8]                            =  radm_cfg_o_int[i].radm_mlf_tlp_err_ptr; 
      radm_cfg_o.radm_rcvd_wreq_poisoned[i*NF+NF-1 -: NF]                      =  radm_cfg_o_int[i].radm_rcvd_wreq_poisoned; 
      radm_cfg_o.radm_rcvd_req_ur[i*NF+NF-1 -: NF]                             =  radm_cfg_o_int[i].radm_rcvd_req_ur; 
      radm_cfg_o.radm_rcvd_req_ca[i]                                           =  radm_cfg_o_int[i].radm_rcvd_req_ca; 
      radm_cfg_o.radm_hdr_log_valid[i*NF+NF-1 -: NF]                           =  radm_cfg_o_int[i].radm_hdr_log_valid;
      radm_cfg_o.radm_hdr_log[i*128+128-1 -: 128]                              =  radm_cfg_o_int[i].radm_hdr_log;
        radm_cfg_o.radm_tlp_prfx_log[i*128+128-1 -: 128]                       =  radm_cfg_o_int[i].radm_tlp_prfx_log; 

    



      radm_cfg_o.radm_msg_payload[i*64+63 -: 64]                                                =  radm_cfg_o_int[i].radm_msg_payload; 

      radm_cfg_o.radm_slot_pwr_limit[i]                                                         =  radm_cfg_o_int[i].radm_slot_pwr_limit; 
      radm_cfg_o.radm_pm_asnak[i]                                                               =  radm_cfg_o_int[i].radm_pm_asnak; 
        radm_cfg_o.radm_pm_turnoff[i]                                                           =  radm_cfg_o_int[i].radm_pm_turnoff;
        radm_cfg_o.radm_msg_unlock[i]                                                           =  radm_cfg_o_int[i].radm_msg_unlock;
      radm_cfg_o.int_radm_pm_pme[i]                                                                 =  radm_cfg_o_int[i].int_radm_pm_pme; 
      radm_cfg_o.radm_pm_to_ack[i]                                                              =  radm_cfg_o_int[i].radm_pm_to_ack; 
      radm_cfg_o.radm_vendor_msg[i]                                                             =  radm_cfg_o_int[i].radm_vendor_msg; 
      radm_cfg_o.radm_vendor_msg_type[i]                                                        =  radm_cfg_o_int[i].radm_vendor_msg_type; 
        radm_cfg_o.radm_msg_idle[i]                                                             =  radm_cfg_o_int[i].radm_msg_idle; 
        radm_cfg_o.radm_msg_obff[i]                                                             =  radm_cfg_o_int[i].radm_msg_obff; 
        radm_cfg_o.radm_msg_cpu_active[i]                                                       =  radm_cfg_o_int[i].radm_msg_cpu_active; 
      radm_cfg_o.radm_rcvd_tlp_req_id[i*16+15 -: 16]                                            =  radm_cfg_o_int[i].radm_rcvd_tlp_req_id; 
      radm_cfg_o.radm_snoop_upd                                  =   radm_cfg_o_int[1].radm_snoop_upd; 
      // radm_cfg_o.radm_snoop_dev_num                              =   radm_cfg_o_int[1].radm_snoop_dev_num; 
      // radm_cfg_o.radm_snoop_bus_num                              =   radm_cfg_o_int[1].radm_snoop_bus_num; 
      // `ifdef CX_CCIX_INTERFACE_ENABLE
      //   radm_cfg_o.ccix_tlp[i*3*CCIX_WD+3*CCIX_WD-1 -: 3*CCIX_WD]                  =  radm_cfg_o_int[i].ccix_tlp; 
      // `endif // CX_CCIX_INTERFACE_ENABLE
      radm_cfg_o.flt_dwlenEq0[i]                                                                =  radm_cfg_o_int[i].flt_dwlenEq0; 
      radm_cfg_o.tlp_poisoned[i]                                                                =  radm_cfg_o_int[i].tlp_poisoned; 
      radm_cfg_o.radm_snoop_bus_num[i*8+7 -: 8]                                                 =  radm_cfg_o_int[i].radm_snoop_bus_num; 
      radm_cfg_o.radm_snoop_dev_num[i*5+4 -: 5]                                                 =  radm_cfg_o_int[i].radm_snoop_dev_num; 
      radm_cfg_o.cfg_segment_id[i*9+8 -: 9]                                                 =  radm_cfg_o_int[i].cfg_segment_id; 
      radm_cfg_o.radm_rcvd_cpl_poisoned[i]                                        =  radm_cfg_o_int[i].radm_rcvd_cpl_poisoned; 
      radm_cfg_o.radm_rcvd_cpl_ur[i]                                             =  radm_cfg_o_int[i].radm_rcvd_cpl_ur; 
      radm_cfg_o.radm_rcvd_cpl_ca[i]                                             =  radm_cfg_o_int[i].radm_rcvd_cpl_ca; 
      radm_cfg_o.radm_unexp_cpl_err[i]                                            =  radm_cfg_o_int[i].radm_unexp_cpl_err; 
      radm_cfg_o.radm_rcvd_acs_err[i]                            =   radm_cfg_o_int[i].radm_rcvd_acs_err; 


      // configurations end
    end // for loop
  end

  //=============================================
  // radm_filter_dmux_trgt1_p.sv
  //=============================================
  // Posted
  radm_filter_dmux_trgt1_p
   
  #(
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE)
  ) 
  u_radm_filter_dmux_trgt1_p 
  (
    .core_clk                                               (core_clk                                     ),
    .radm_clk_ug                                            (radm_clk_ug                                  ),
    .core_rst_n                                             (core_rst_n                                   ),
    .non_sticky_rst_n                                       (non_sticky_rst_n                             ),
    .radm_cfg_i                                             (radm_cfg_i                                   ),
    .radm_cfg_tlp_i                                         (radm_cfg_i_int[0]                            ),
    .radm_cfg_o                                             (radm_cfg_o_int[0]                            ),
    .rx_tlp                                                 (rx_tlp[E_P]                                  ),
    .flit_mode                                              (flit_mode                                    ),
    .flt_cdm_addr_p                                         (flt_cdm_addr_int[0]                          ),
    .flt_cdm_addr_valid_p                                   (flt_cdm_addr_valid_int[0]                    ),
    //                                    
    .app_req_retry_en                                       (app_req_retry_en                             ),
    .app_pf_req_retry_en                                    (app_pf_req_retry_en                          ),

    // TO DO : SK 
    //  `ifdef CX_CCIX_INTERFACE_ENABLE             
    //    .hdr_dec_flt_hdr_p_ccix_tlp                       (hdr_dec_flt_hdr_p_ccix_tlp                   ),
    //  `endif // CX_CCIX_INTERFACE_ENABLE              

    .rtlh_radm_parerr                                       (1'b0                                         ),
 
    // ATU                        
    .radm_cfg_atu_in                                        (radm_cfg_atu_in                              ),
    // ATU end
    .trgt0_radm_halt_int                                    (trgt0_radm_halt_int_p                        ),
    .dmux_trgt0_req                                         (dmux_trgt0_req_p                             ),
    .dmux_trgt0_fifo_pipe_empty                             (dmux_trgt0_fifo_pipe_empty_p                      ),
    .trgt1_radm_intf_halt                                   (trgt1_radm_intf_halt_p                       ),
    .radm_trgt1_out_p                                       (radm_trgt1_out_p                             ),
    .pktadj_crdmgr_crd_restore                              (pktadj_crdmgr_crd_restore_p                  ),
    .ecrc_err_inj_enable                                    (ecrc_err_inj_enable[0]                       ),
    .ecrc_pkt_eot_with_vld_td                               (ecrc_pkt_eot_with_vld_td[0]                  ),
    // Demux Clock Gating Control Signals 
    .dmux_clkg_ctrl                                         (trgt_clkg_ctrl.trgt_clkg_ctrl[0]             ),

`ifndef SYNTHESIS
    // Outputs to testbench
    .flt_pkt_num_p_valid                                    (flt_pkt_num_p_valid                          ),
    .flt_pkt_num_p                                          (flt_pkt_num_p                                ),
`endif
    .flt_q_log_p_o                                          (flt_q_log_p_o                                ),
    .log_halt_p                                             (log_halt_p                                   ),
    .trgt_fifo_hdr_data_grnt                                (trgt_grnt_trgt1.trgt_grnt_trgt1[0]           )
      ,
      .ras_dp_err_log                                       (ras_dp_err_log[0 +: FILTER_DEMUX_TRGT1_P_CHK_CNTS]        )
      ,
      .ras_dp_err_inj                                       (ras_dp_err_inj                               )
  );
  // Posted  End
  
  //=============================================
  // radm_filter_dmux_trgt1_np.sv
  //=============================================
  // Non-Posted

  radm_filter_dmux_trgt1_np
  
  #(
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+FILTER_DEMUX_TRGT1_P_CHK_CNTS)
  ) 
  u_radm_filter_dmux_trgt1_np 
  (
    .core_clk                                               (core_clk                                     ),
    .radm_clk_ug                                            (radm_clk_ug                                  ),
    .core_rst_n                                             (core_rst_n                                   ),
    .non_sticky_rst_n                                       (non_sticky_rst_n                             ),
    .radm_cfg_i                                             (radm_cfg_i                                   ),
    .radm_cfg_tlp_i                                         (radm_cfg_i_int[1]                            ),
    .radm_cfg_o                                             (radm_cfg_o_int[1]                            ),
    .rx_tlp                                                 (rx_tlp[E_NP]                                 ),
    .flit_mode                                              (flit_mode                                    ),
    .flt_cdm_addr_np                                        (flt_cdm_addr_int[1]                          ),     
    .flt_cdm_addr_valid_np                                  (flt_cdm_addr_valid_int[1]                    ),
    // Filter I/O         
    .app_req_retry_en                                       (app_req_retry_en                             ),
    .app_pf_req_retry_en                                    (app_pf_req_retry_en                          ),
    //  `ifdef CX_CCIX_INTERFACE_ENABLE         
    //    .hdr_dec_flt_np_ccix_tlp                          (hdr_dec_flt_np_ccix_tlp                      ),
    //  `endif // CX_CCIX_INTERFACE_ENABLE          
    .rtlh_radm_parerr                                       (1'b0                                         ),
    // ATU                        
    .radm_cfg_atu_in                                        (radm_cfg_atu_in                              ),
    // ATU end


    .rcrb_base_addr                                         (rcrb_base_addr                               ),
    .rcrb_base_addr_valid                                   (rcrb_base_addr_valid                         ),
    // ---- outputs ---------------         
    .trgt0_radm_halt_int                                    (trgt0_radm_halt_int_np                       ),
    .dmux_trgt0_req                                         (dmux_trgt0_req_np                            ),
    .trgt1_radm_intf_halt                                   (trgt1_radm_intf_halt_np                      ),
    // Demux Clock Gating Control Signals 
    .dmux_clkg_ctrl                                         (trgt_clkg_ctrl.trgt_clkg_ctrl[1]             ),

`ifndef SYNTHESIS
    // Outputs to testbench
    .flt_pkt_num_np_valid                                   (flt_pkt_num_np_valid                         ),
    .flt_pkt_num_np                                         (flt_pkt_num_np                               ),
`endif

    .ecrc_err_inj_enable                                    (ecrc_err_inj_enable[1]                       ),
    .ecrc_pkt_eot_with_vld_td                               (ecrc_pkt_eot_with_vld_td[1]                  ),
    .radm_trgt1_out_np                                      (radm_trgt1_out_np                            ),
    .pktadj_crdmgr_crd_restore                              (pktadj_crdmgr_crd_restore_np                 ),
    .flt_q_log_np_o                                         (flt_q_log_np_o                               ),
    .log_halt_np                                            (log_halt_np                                  ),
    .trgt_fifo_hdr_data_grnt                                (trgt_grnt_trgt1.trgt_grnt_trgt1[1]           )
    ,
    .ras_dp_err_log                                         (ras_dp_err_log[FILTER_DEMUX_TRGT1_P_CHK_CNTS +: FILTER_DEMUX_TRGT1_NP_CHK_CNTS] )
    ,
    .ras_dp_err_inj                                         (ras_dp_err_inj                               )
  );
  // Non-Posted end
    
  //=============================================
  // radm_filter_dmux_trgt1_cpl.sv
  //=============================================
  // Completion 

  radm_filter_dmux_trgt1_cpl
  
  #(
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+FILTER_DEMUX_TRGT1_P_CHK_CNTS+FILTER_DEMUX_TRGT1_NP_CHK_CNTS)
  ) u_radm_filter_dmux_trgt1_cpl (
    .core_clk                                               (core_clk                                     ),
    .radm_clk_ug                                            (radm_clk_ug                                  ),
    .core_rst_n                                             (core_rst_n                                   ),
    .radm_cfg_i                                             (radm_cfg_i                                   ),
    .radm_cfg_o                                             (radm_cfg_o_int[2]                            ),
    .rx_tlp                                                 (rx_tlp[E_CPL]                                ),
    .flit_mode                                              (flit_mode                                    ),
    // Filter I/O       
    .app_req_retry_en                                       (app_req_retry_en                             ),
    .app_pf_req_retry_en                                    (app_pf_req_retry_en                          ),
        
    //  `ifdef CX_CCIX_INTERFACE_ENABLE
    //    .hdr_dec_flt_hdr_ccix_tlp                         (hdr_dec_flt_hdr_ccix_tlp_cpl                 ),
    //  `endif // CX_CCIX_INTERFACE_ENABLE
    .cpl_mlf_err                                            (cpl_mlf_err_cpl                              ),
    .flt_q_cpl_last                                         (flt_q_cpl_last_cpl                           ),
    .cpl_ur_err                                             (cpl_ur_err_cpl                               ),
    .cpl_ca_err                                             (cpl_ca_err_cpl                               ),
    .lut_filt_cpl_abort                                     (lut_filt_cpl_abort                           ),
    .unexpected_cpl_err                                     (unexpected_cpl_err_cpl                       ),
    .lut_flt_np_req_type                                    (lut_flt_np_req_type                          ),
    .flt_xadm_np_req_type_o                                 (flt_xadm_np_req_type_o                       ),
        
    // ---- outputs ---------------       
    .cpl_tlp                                                (cpl_tlp_cpl                                  ),
    .flt_q_rcvd_cpl_tlp_tag                                 (flt_q_rcvd_cpl_tlp_tag_cpl                   ),
    .cpl_status                                             (cpl_status_cpl                               ),

    .flt_dwlenEq0                                           (flt_dwlenEq0_cpl),
    .rtlh_radm_ecrc_err                                     (rtlh_radm_ecrc_err_cpl),
    .rtlh_radm_malform_tlp_err                              (rtlh_radm_malform_tlp_err_cpl),
    .trgt1_radm_intf_halt                                   (trgt1_radm_intf_halt_cpl                     ),
    .flt_cpl_lut                                            (flt_cpl_lut                                  ),
    // Demux Clock Gating Control Signals
    .dmux_clkg_ctrl                                         (trgt_clkg_ctrl.trgt_clkg_ctrl[2]             ),

`ifndef SYNTHESIS
    // Outputs to testbench
    .flt_pkt_num_cpl_valid                                  (flt_pkt_num_cpl_valid                        ),
    .flt_pkt_num_cpl                                        (flt_pkt_num_cpl                              ),
`endif
    .ecrc_err_inj_enable                                    (ecrc_err_inj_enable[2]                       ),
    .ecrc_pkt_eot_with_vld_td                               (ecrc_pkt_eot_with_vld_td[2]                  ),
    .radm_trgt1_out_cpl                                     (radm_trgt1_out_cpl                           ),
    .pktadj_crdmgr_crd_restore                              (pktadj_crdmgr_crd_restore_cpl                ),
    .flt_q_log_cpl_o                                        (flt_q_log_cpl_o                              ),
    .log_halt_cpl                                           (log_halt_cpl                                 ),
    .trgt_fifo_hdr_data_grnt                                (trgt_grnt_trgt1.trgt_grnt_trgt1[2]           )
    ,
    .ras_dp_err_log                                         (ras_dp_err_log[FILTER_DEMUX_TRGT1_P_CHK_CNTS+FILTER_DEMUX_TRGT1_NP_CHK_CNTS +: FILTER_DEMUX_TRGT1_CPL_CHK_CNTS]        )
    ,
    .ras_dp_err_inj                                         (ras_dp_err_inj                               )
  );
  // completion end

endmodule //radm_filter_dmux_trgt1_ms 

