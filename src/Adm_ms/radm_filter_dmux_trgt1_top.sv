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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_filter_dmux_trgt1_top.sv#11 $
// -------------------------------------------------------------------------
// -------------------------------------------------------------------------
//Description: 
//This moduls is TOP module of all TLP type (P,NP,CPL) sub module TOP. This module is instantiation of  - 
//    - radm_filter_dmux_trgt1
//      Number of instantiation of above module depends on number of TRGT1 interfaces are supported 
//      (each TRGT1 interface has three FC type i.e. P,NP,CPL)
//- This modules takes input from CDM modules (Configuration inputs) and provides it to all other 
//TLP types submodule TOP to get configuration inputs to all TLP type modules 
//- This modules sends output respective filter and other TLP type modules and provides it to CDM block for 
//all TLP types 
//- This module sends seperate signals to respective TRGT1 TLP type interface  and as per number of 
//  TRGT1 interfaces are supported 
//--------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_filter_dmux_trgt1_top
  /////////////////////////////////////////
  //import radm_ms_pkg starts
  import radm_ms_pkg::PKT_ORD_WD;
  import radm_ms_pkg::FILTER_DEMUX_TRGT1_CKH_CNTS;
  import radm_ms_pkg::N_TRGT1_INTF;
  import radm_ms_pkg::FX_TLP;
  import radm_ms_pkg::SNOOP_VPD_WD;
  import radm_ms_pkg::NO_OF_TRGT0_INTF;
  import radm_ms_pkg::INT_HDW;
  import radm_ms_pkg::radm_cfg_atu_s;
  import radm_ms_pkg::radm_cfg_i_s;
  import radm_ms_pkg::radm_cfg_ntlp_ntrgt_i_s;
  import radm_ms_pkg::radm_cfg_ntlp_i_s;
  import radm_ms_pkg::radm_cfg_ntlp_ntrgt_o_s;
  import radm_ms_pkg::radm_cfg_ntlp_o_s;
  import radm_ms_pkg::trgt_grnt_top_s;
  import radm_ms_pkg::radm_ord_mgr_flt_data_s;
  import radm_ms_pkg::flt_q_dmux_o_s;
  import radm_ms_pkg::flt_cpl_lut_s;
  import radm_ms_pkg::radm_crd_restore_s;
  import radm_ms_pkg::trgt1_p_out_s;
  import radm_ms_pkg::trgt1_np_out_s;
  import radm_ms_pkg::trgt1_cpl_out_s;
  import radm_ms_pkg::port_trgt_clkg_ctrl_s;
  import radm_ms_pkg::radm_rx_tlp_s;
  import radm_ms_pkg::rtrgt1_tlp_out_s;
  import radm_ms_pkg::pktstr_hlog_s;
  //import radm_ms_pkg ends
  //////////////////////////////////////////
`ifndef SYNTHESIS
`endif
  //////////////////////////////////////////
  //import DWC_pcie_ctl_pkg starts
  import DWC_pcie_ctl_pkg::TAG_SIZE;
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::PF_WD;  
  import DWC_pcie_ctl_pkg::NVF;
  import DWC_pcie_ctl_pkg::VF_WD;
  import DWC_pcie_ctl_pkg::VFI_WD;
  import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD;
   import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  //import DWC_pcie_ctl_pkg ends
  /////////////////////////////////////
  
#(
  parameter RAS_DP_PROT_CHK_ID_BASE  = 0
)
  
                                   (
    // --------------- Inputs ---------------------
    input                                                     core_clk,
    input                                                     radm_clk_ug,
    input                                                     core_rst_n,
    input                                                     non_sticky_rst_n,
    // Configurations                           
    input   radm_cfg_i_s                                      radm_cfg_i,
    input   radm_cfg_ntlp_ntrgt_i_s                           radm_cfg_ntlp_ntrgt_i,
    output  radm_cfg_ntlp_ntrgt_o_s                           radm_cfg_ntlp_ntrgt_o,
    output logic [N_TRGT1_INTF*2*64-1:0]                      flt_cdm_addr_o,
    output logic [N_TRGT1_INTF*2-1:0]                         flt_cdm_addr_valid_o,
    output logic                                             cpl_0_tlp_cpl,
    output logic [2:0]                                       cpl_0_status_cpl,
    output logic                                             cpl_0_flt_dwlenEq0_cpl,
    output logic                                             cpl_0_rtlh_radm_ecrc_err_cpl,
    output logic                                             cpl_0_rtlh_radm_malform_tlp_err_cpl
    // ATU                          
     ,
    input   radm_cfg_atu_s                                    radm_cfg_atu_in 
    // configurations end  

    // ORD TO HDR_EDC 
     , 

    input  radm_rx_tlp_s  [2:0]                               rx_tlp,          // Received TLP struct, from OutQ/IDE, to filter

    // Posted
    input                                                     flit_mode, 
    input                                                     app_req_retry_en,
    input    [NF-1:0]                                         app_pf_req_retry_en


    ,
    output  logic  [51:0]                                 rcrb_base_addr,             // Indicates the base address for the RCRB region. The upper address bits[63:12] of the first memory access received after link initialization is the RCRB base address
    output  logic                                         rcrb_base_addr_valid        // Indicates the base address valid for the RCRB region

    ,
    //  `ifdef CX_CCIX_INTERFACE_ENABLE
    //    ,
    //    input [N_TRGT1_INTF*CCIX_WD-1:0]                    hdr_dec_flt_hdr_p_ccix_tlp
    //  `endif // CX_CCIX_INTERFACE_ENABLE                   
    // Filter I/O                    
     


    // --------------- Inputs ---------------------
    // cpl
      input  [N_TRGT1_INTF-1:0]                               trgt1_radm_intf_halt_cpl,
    // posted
    input  [N_TRGT1_INTF-1:0]                                 trgt0_radm_halt_int_p,
    input  [N_TRGT1_INTF-1:0]                               trgt1_radm_intf_halt_p
    // non posted

    // Filter I/O 
    ,
    //  `ifdef CX_CCIX_INTERFACE_ENABLE
    //    ,
    //      input [N_TRGT1_INTF*CCIX_WD-1:0]                     hdr_dec_flt_np_ccix_tlp
    //  `endif // CX_CCIX_INTERFACE_ENABLE
    input  [N_TRGT1_INTF-1:0]                                 trgt0_radm_halt_int_np,
    input  [N_TRGT1_INTF-1:0]                               trgt1_radm_intf_halt_np,

    /// For completion 

    // Filter I/O 
    //  `ifdef CX_CCIX_INTERFACE_ENABLE
    //    ,
    //      input [N_TRGT1_INTF*CCIX_WD-1:0]                  hdr_dec_flt_hdr_ccix_tlp_cpl
    //  `endif // CX_CCIX_INTERFACE_ENABLE
    // `ifdef CX_RASDP_EN
    // input  [N_TRGT1_INTF-1:0]                              ras_radm_prot_disable_cpl,
    // `endif // CX_RASDP_EN
    input  [N_TRGT1_INTF-1:0]                                 cpl_mlf_err_cpl,
    input  [N_TRGT1_INTF-1:0]                                 flt_q_cpl_last_cpl,
    input  [N_TRGT1_INTF-1:0]                                 cpl_ur_err_cpl,
    input  [N_TRGT1_INTF-1:0]                                 cpl_ca_err_cpl,
    input  [N_TRGT1_INTF-1:0]                                 lut_filt_cpl_abort,
    input  [N_TRGT1_INTF-1:0]                                 unexpected_cpl_err_cpl,
    input  [N_TRGT1_INTF-1:0][NP_REQ_TX_TYPE_WD-1:0]          lut_flt_np_req_type,
    output [N_TRGT1_INTF-1:0][NP_REQ_TX_TYPE_WD-1:0]          flt_xadm_np_req_type_o,
    // posted
      //  `ifdef CX_CCIX_INTERFACE_ENABLE
      //    ,
      //    output logic [CCIX_WD-1:0]                                ccix_p_0_tlp
      //  `endif // CX_CCIX_INTERFACE_ENABLE
      output  logic [NO_OF_TRGT0_INTF-1:0][INT_HDW -1 : 0]            dmux_trgt0_req,
      output  logic [N_TRGT1_INTF-1:0]                                dmux_trgt0_p_fifo_pipe_empty,
      output trgt1_p_out_s [N_TRGT1_INTF-1:0]                         radm_trgt1_out_p 
      // non posted
      //output logic [127:0]                                            radm_hdr_np_0_log,

      //  `ifdef CX_CCIX_INTERFACE_ENABLE
      //    output logic [CCIX_WD-1:0]                                ccix_np_0_tlp,
      //  `endif // CX_CCIX_INTERFACE_ENABLE
     // output logic [SNOOP_VPD_WD -1:0]                                radm_snoop_np_0_upd,
      ,
      output trgt1_np_out_s [N_TRGT1_INTF-1:0]                            radm_trgt1_out_np,
      `ifndef SYNTHESIS
      // Outputs to testbench
      output logic [N_TRGT1_INTF-1:0]                                  flt_pkt_num_p_valid,
      output logic [N_TRGT1_INTF-1:0][PKT_ORD_WD-1:0]                  flt_pkt_num_p,
      output logic [N_TRGT1_INTF-1:0]                                  flt_pkt_num_np_valid,
      output logic [N_TRGT1_INTF-1:0][PKT_ORD_WD-1:0]                  flt_pkt_num_np,
      output logic [N_TRGT1_INTF-1:0]                                  flt_pkt_num_cpl_valid,
      output logic [N_TRGT1_INTF-1:0][PKT_ORD_WD-1:0]                  flt_pkt_num_cpl,
      `endif

      //------------------------------
      //Header Logging Interface
      output flt_q_dmux_o_s [N_TRGT1_INTF-1:0]                      flt_q_log_p_o,
      output flt_q_dmux_o_s [N_TRGT1_INTF-1:0]                      flt_q_log_np_o,
      output flt_q_dmux_o_s [N_TRGT1_INTF-1:0]                      flt_q_log_cpl_o,
      input logic           [FX_TLP-1:0]                            log_halt,
      //--------------------------------------------//
      // For completion                   
      output trgt1_cpl_out_s [N_TRGT1_INTF-1:0]                       radm_trgt1_out_cpl,
      output flt_cpl_lut_s                                            flt_cpl_lut,
      output trgt_grnt_top_s                                          trgt_grnt_trgt1_top, 
        
      output radm_crd_restore_s [N_TRGT1_INTF-1:0]                    pktadj_crdmgr_crd_restore_p,
      output radm_crd_restore_s [N_TRGT1_INTF-1:0]                    pktadj_crdmgr_crd_restore_np,
      output radm_crd_restore_s [N_TRGT1_INTF-1:0]                    pktadj_crdmgr_crd_restore_cpl,
      // Demux Clock Gating Control Signals
      output port_trgt_clkg_ctrl_s                                    port_trgt_clkg_ctrl

      ,
      input logic  [N_TRGT1_INTF-1:0][3-1:0]                          ecrc_err_inj_enable,
      output logic [N_TRGT1_INTF-1:0][3-1:0]                          ecrc_pkt_eot_with_vld_td
      ,output ras_dp_err_log_t   [N_TRGT1_INTF-1:0][FILTER_DEMUX_TRGT1_CKH_CNTS-1:0]       ras_dp_err_log
      ,input  ras_dp_err_inj_t                                        ras_dp_err_inj
  );

    //-------------------- Signal declaration-------------------------
    // configurations
    radm_cfg_ntlp_i_s  [N_TRGT1_INTF-1:0]                     radm_cfg_ntlp_i_int;
    radm_cfg_ntlp_o_s  [N_TRGT1_INTF-1:0]                     radm_cfg_ntlp_o_int;
    logic  [2*64-1:0]                                         flt_cdm_addr_o_int[N_TRGT1_INTF-1:0];
    logic  [2-1:0]                                            flt_cdm_addr_vld_o_int[N_TRGT1_INTF-1:0];
    // posted

    // Filter I/O                       

    //`ifdef CX_CCIX_INTERFACE_ENABLE
    //  logic [CCIX_WD-1:0]                                   hdr_dec_flt_hdr_p_ccix_tlp_int[0:N_TRGT1_INTF-1];
    //`endif // CX_CCIX_INTERFACE_ENABLE

    // logic [INT_HDW -1:0]                                      dmux_trgt0_req_p[0:N_TRGT1_INTF-1];
    // non posted
    // Filter I/O     
    //`ifdef CX_CCIX_INTERFACE_ENABLE
    //  logic [CCIX_WD-1:0]                                   hdr_dec_flt_np_ccix_tlp_int[0:N_TRGT1_INTF-1];
    //`endif // CX_CCIX_INTERFACE_ENABLE

    // ---- outputs ---------------

    //logic [INT_HDW -1:0]                                    dmux_trgt0_req_np[0:N_TRGT1_INTF-1];
    //logic [INT_HDW -1:0]                                    dmux_trgt0_req[0:N_TRGT1_INTF-1];
    // For completion 

    // Filter I/O             
    //`ifdef CX_CCIX_INTERFACE_ENABLE
    //  logic [CCIX_WD-1:0]                                   hdr_dec_flt_hdr_ccix_tlp_cpl_int[0:N_TRGT1_INTF-1];
    //`endif // CX_CCIX_INTERFACE_ENABLE

    logic [N_TRGT1_INTF-1:0]                                  cpl_tlp_cpl;
    logic [N_TRGT1_INTF-1:0]                                  flt_dwlenEq0_cpl;
    logic [N_TRGT1_INTF-1:0]                                  rtlh_radm_ecrc_err_cpl;
    logic [N_TRGT1_INTF-1:0]                                  rtlh_radm_malform_tlp_err_cpl;
    logic  [2:0]                                              cpl_status_cpl[0:N_TRGT1_INTF-1];

    logic  [TAG_SIZE-1:0]                                     flt_q_rcvd_cpl_tlp_tag_cpl[0:N_TRGT1_INTF-1];
    //logic  [SNOOP_VPD_WD -1:0]                                radm_snoop_upd_cpl[0:N_TRGT1_INTF-1];

    //logic [INT_HDW -1:0]                                        dmux_trgt0_req_cpl[0:N_TRGT1_INTF-1];
      //-------- radm_hdr_log signals ---------//
      logic [N_TRGT1_INTF-1:0]                                log_halt_p   ;
      logic [N_TRGT1_INTF-1:0]                                log_halt_np  ;
      logic [N_TRGT1_INTF-1:0]                                log_halt_cpl ;
always_comb begin
  log_halt_p   = '0 ;
  log_halt_np  = '0 ;
  log_halt_cpl = '0 ;
  for (int i=0; i<N_TRGT1_INTF; i++) begin
    for (int j=0; j<3; j++) begin
      if (j==0) begin
        log_halt_p[i]   = log_halt[i*3+0] ;
      end
      else if (j==1) begin
        log_halt_np[i]  = log_halt[i*3+1] ;
      end
      else begin
        log_halt_cpl[i] = log_halt[i*3+2] ;
      end
    end
  end
end
    //----------------------------------------------------------------------------------
      // assign  dmux_p_0_trgt0_req                               =  dmux_trgt0_req_p[0];

      // ---- outputs ---------------
      // for completion

      assign   cpl_0_tlp_cpl                                      = cpl_tlp_cpl[0];
      assign   cpl_0_status_cpl                                   = cpl_status_cpl[0];
      assign   cpl_0_flt_dwlenEq0_cpl                             = flt_dwlenEq0_cpl[0];
      assign   cpl_0_rtlh_radm_ecrc_err_cpl                       = rtlh_radm_ecrc_err_cpl[0];
      assign   cpl_0_rtlh_radm_malform_tlp_err_cpl                = rtlh_radm_malform_tlp_err_cpl[0];


//---------------------------------------------------------------------------
// Following block seperates signals per TRGT1_INTERFACE
//---------------------------------------------------------------------------

    always_comb begin
      for (int i = 0; i < N_TRGT1_INTF; i = i + 1) begin
        // configurations
        radm_cfg_ntlp_i_int[i].cfg_io_match                                           =  radm_cfg_ntlp_ntrgt_i.cfg_io_match[i*NF*2+NF*2-1 -: NF*2];            
        radm_cfg_ntlp_i_int[i].cfg_config_above_match                                 =  radm_cfg_ntlp_ntrgt_i.cfg_config_above_match[i*NF*2+NF*2-1 -: NF*2];
        radm_cfg_ntlp_i_int[i].cfg_bar_match                                          =  radm_cfg_ntlp_ntrgt_i.cfg_bar_match[i*NF*12+NF*12-1 -: NF*12];      
        radm_cfg_ntlp_i_int[i].cfg_rom_match                                          =  radm_cfg_ntlp_ntrgt_i.cfg_rom_match[i*NF*2+NF*2-1 -: NF*2];
          radm_cfg_ntlp_i_int[i].cfg_rcrb_match                                       = radm_cfg_ntlp_ntrgt_i.cfg_rcrb_match[1:0];
          for (int j = 0; j < NF; j = j + 1)
              radm_cfg_ntlp_i_int[i].cfg_cxl_mbar0_match[j]                               = radm_cfg_ntlp_ntrgt_i.cfg_cxl_mbar0_match[j][1:0];
          radm_cfg_ntlp_i_int[i].cxl_2_0_mbar0_access_int                             = radm_cfg_ntlp_ntrgt_i.cxl_2_0_mbar0_access_int[1:0];
          radm_cfg_ntlp_i_int[i].cfg_cxl_alt_mem_match                                = radm_cfg_ntlp_ntrgt_i.cfg_cxl_alt_mem_match[i*NF*2+NF*2-1 -: NF*2];
          radm_cfg_ntlp_i_int[i].cfg_cxl_alt_prefmem_match                            = radm_cfg_ntlp_ntrgt_i.cfg_cxl_alt_prefmem_match[i*NF*2+NF*2-1 -: NF*2];
          radm_cfg_ntlp_i_int[i].cfg_rcrb_mbar0_match                                 = radm_cfg_ntlp_ntrgt_i.cfg_rcrb_mbar0_match[1:0];
          radm_cfg_ntlp_i_int[i].cfg_rcrb_mbar0_match_int                             = radm_cfg_ntlp_ntrgt_i.cfg_rcrb_mbar0_match_int[1:0];
        radm_cfg_ntlp_i_int[i].cfg_prefmem_match                                      =  radm_cfg_ntlp_ntrgt_i.cfg_prefmem_match[i*2*NF+NF*2-1 -: NF*2]; 
        radm_cfg_ntlp_i_int[i].cfg_mem_match                                          =  radm_cfg_ntlp_ntrgt_i.cfg_mem_match[i*2*NF+NF*2-1 -: NF*2];
//        radm_cfg_ntlp_i_int[i].cfg_p2p_err_rpt_ctrl                                 =  radm_cfg_ntlp_ntrgt_i.cfg_p2p_err_rpt_ctrl[i*3+2 -: 3]; 

//`ifdef CX_DPC_ENABLE
//
//        radm_cfg_ntlp_i_int[i].dpc_nonfatal_err_gate                              =  radm_cfg_ntlp_ntrgt_i.dpc_nonfatal_err_gate[i*3+2 -: 3]; 
//        radm_cfg_ntlp_i_int[i].dpc_fatal_err_gate                                  =  radm_cfg_ntlp_ntrgt_i.dpc_fatal_err_gate[i*3+2 -: 3]; 
//        radm_cfg_ntlp_i_int[i].cdm_core_in_dpc                                     =  radm_cfg_ntlp_ntrgt_i.cdm_core_in_dpc[i*3+2 -: 3]; 
//`endif // CX_DPC_ENABLE

   



  // ---- outputs ---------------
    radm_cfg_ntlp_ntrgt_o.radm_ptm_req[i*3+2 -: 3]                                                     =  radm_cfg_ntlp_o_int[i].radm_ptm_req; 
    radm_cfg_ntlp_ntrgt_o.radm_ptm_res_msg[i*3+2 -: 3]                                                     =  radm_cfg_ntlp_o_int[i].radm_ptm_res_msg; 
    radm_cfg_ntlp_ntrgt_o.radm_ptm_res_d_msg[i*3+2 -: 3]                                                   =  radm_cfg_ntlp_o_int[i].radm_ptm_res_d_msg; 
    radm_cfg_ntlp_ntrgt_o.radm_ptm_master_time[i*3*64+3*64-1 -: 3*64]                                      =  radm_cfg_ntlp_o_int[i].radm_ptm_master_time; 
    radm_cfg_ntlp_ntrgt_o.radm_ptm_prop_delay[i*3*32+3*32-1 -: 3*32]                                       =  radm_cfg_ntlp_o_int[i].radm_ptm_prop_delay; 
  //radm_cfg_ntlp_ntrgt_o.flt_cdm_addr[i*3*64+3*64-1 -: 3*64]                                                =  radm_cfg_ntlp_o_int[i].flt_cdm_addr; 
  radm_cfg_ntlp_ntrgt_o.flt_cdm_pf[i*3*PF_WD+3*PF_WD-1 -: 3*PF_WD]                                         =  radm_cfg_ntlp_o_int[i].flt_cdm_pf;
  radm_cfg_ntlp_ntrgt_o.radm_ecrc_err[i*3+3-1 -: 3]                                               =  radm_cfg_ntlp_o_int[i].radm_ecrc_err; 
  radm_cfg_ntlp_ntrgt_o.radm_mlf_tlp_err[i*3+3-1 -: 3]                                            =  radm_cfg_ntlp_o_int[i].radm_mlf_tlp_err; 
    radm_cfg_ntlp_ntrgt_o.radm_mlf_tlp_err_ptr[i*24+23 -: 24]                                              =  radm_cfg_ntlp_o_int[i].radm_mlf_tlp_err_ptr; 
  radm_cfg_ntlp_ntrgt_o.radm_rcvd_wreq_poisoned[i*3*NF+3*NF-1 -: 3*NF]                            =  radm_cfg_ntlp_o_int[i].radm_rcvd_wreq_poisoned; 
  radm_cfg_ntlp_ntrgt_o.radm_rcvd_req_ur[i*3*NF+3*NF-1 -: 3*NF]                                   =  radm_cfg_ntlp_o_int[i].radm_rcvd_req_ur; 
  radm_cfg_ntlp_ntrgt_o.radm_rcvd_req_ca[i*3+3-1 -: 3]                                            =  radm_cfg_ntlp_o_int[i].radm_rcvd_req_ca; 
  radm_cfg_ntlp_ntrgt_o.radm_hdr_log_valid[i*3*NF+3*NF-1 -: 3*NF]                                          =  radm_cfg_ntlp_o_int[i].radm_hdr_log_valid;
  radm_cfg_ntlp_ntrgt_o.radm_hdr_log[i*3*128+3*128-1 -: 3*128]                                             =  radm_cfg_ntlp_o_int[i].radm_hdr_log;
    radm_cfg_ntlp_ntrgt_o.radm_tlp_prfx_log[i*3*128+3*128-1 -: 3*128]                                      =  radm_cfg_ntlp_o_int[i].radm_tlp_prfx_log; 




  radm_cfg_ntlp_ntrgt_o.radm_msg_payload[i*3*64+3*64-1 -: 3*64]                                            =  radm_cfg_ntlp_o_int[i].radm_msg_payload; 

  radm_cfg_ntlp_ntrgt_o.radm_slot_pwr_limit[i*3+2 -: 3]                                                    =  radm_cfg_ntlp_o_int[i].radm_slot_pwr_limit; 
  radm_cfg_ntlp_ntrgt_o.radm_pm_asnak[i*3+2 -: 3]                                                          =  radm_cfg_ntlp_o_int[i].radm_pm_asnak; 
    radm_cfg_ntlp_ntrgt_o.radm_pm_turnoff[i*3+2 -: 3]                                                      =  radm_cfg_ntlp_o_int[i].radm_pm_turnoff;
    radm_cfg_ntlp_ntrgt_o.radm_msg_unlock[i*3+2 -: 3]                                                      =  radm_cfg_ntlp_o_int[i].radm_msg_unlock;
  radm_cfg_ntlp_ntrgt_o.int_radm_pm_pme[i*3+2 -: 3]                                                            =  radm_cfg_ntlp_o_int[i].int_radm_pm_pme; 
  radm_cfg_ntlp_ntrgt_o.radm_pm_to_ack[i*3+2 -: 3]                                                         =  radm_cfg_ntlp_o_int[i].radm_pm_to_ack; 
  radm_cfg_ntlp_ntrgt_o.radm_vendor_msg[i*3+2 -: 3]                                                        =  radm_cfg_ntlp_o_int[i].radm_vendor_msg; 
  radm_cfg_ntlp_ntrgt_o.radm_vendor_msg_type[i*3+2 -: 3]                                                   =  radm_cfg_ntlp_o_int[i].radm_vendor_msg_type; 
    radm_cfg_ntlp_ntrgt_o.radm_msg_idle[i*3+2 -: 3]                                                        =  radm_cfg_ntlp_o_int[i].radm_msg_idle; 
    radm_cfg_ntlp_ntrgt_o.radm_msg_obff[i*3+2 -: 3]                                                        =  radm_cfg_ntlp_o_int[i].radm_msg_obff; 
    radm_cfg_ntlp_ntrgt_o.radm_msg_cpu_active[i*3+2 -: 3]                                                  =  radm_cfg_ntlp_o_int[i].radm_msg_cpu_active; 
  radm_cfg_ntlp_ntrgt_o.radm_rcvd_tlp_req_id[i*48+47 -: 48]                                                =  radm_cfg_ntlp_o_int[i].radm_rcvd_tlp_req_id; 
      radm_cfg_ntlp_ntrgt_o.radm_snoop_upd                                  =   radm_cfg_ntlp_o_int[i].radm_snoop_upd; 
      radm_cfg_ntlp_ntrgt_o.radm_snoop_dev_num                              =   radm_cfg_ntlp_o_int[i].radm_snoop_dev_num; 
      radm_cfg_ntlp_ntrgt_o.radm_snoop_bus_num                              =   radm_cfg_ntlp_o_int[i].radm_snoop_bus_num; 
      radm_cfg_ntlp_ntrgt_o.cfg_segment_id                              =   radm_cfg_ntlp_o_int[i].cfg_segment_id; 

      radm_cfg_ntlp_ntrgt_o.radm_rcvd_cpl_poisoned                     =   radm_cfg_ntlp_o_int[i].radm_rcvd_cpl_poisoned; 
      radm_cfg_ntlp_ntrgt_o.radm_rcvd_cpl_ur                           =   radm_cfg_ntlp_o_int[i].radm_rcvd_cpl_ur; 
      radm_cfg_ntlp_ntrgt_o.radm_rcvd_cpl_ca                            =   radm_cfg_ntlp_o_int[i].radm_rcvd_cpl_ca; 
      radm_cfg_ntlp_ntrgt_o.radm_unexp_cpl_err                          =   radm_cfg_ntlp_o_int[i].radm_unexp_cpl_err; 

      radm_cfg_ntlp_ntrgt_o.radm_rcvd_acs_err                            =   radm_cfg_ntlp_o_int[i].radm_rcvd_acs_err; 
  // `ifdef CX_CCIX_INTERFACE_ENABLE
  //   radm_cfg_ntlp_ntrgt_o.ccix_tlp[i*3*CCIX_WD+3*CCIX_WD-1 -: 3*CCIX_WD]                     =  radm_cfg_ntlp_o_int[i].ccix_tlp; 
  // `endif // CX_CCIX_INTERFACE_ENABLE
  radm_cfg_ntlp_ntrgt_o.flt_dwlenEq0[i*3+2 -: 3]                                                           =  radm_cfg_ntlp_o_int[i].flt_dwlenEq0; 
  radm_cfg_ntlp_ntrgt_o.tlp_poisoned[i*3+2 -: 3]                                                           =  radm_cfg_ntlp_o_int[i].tlp_poisoned; 
      radm_cfg_ntlp_ntrgt_o.radm_inta_asserted[i*3+2 -: 3]              =  radm_cfg_ntlp_o_int[i].radm_inta_asserted; 
      radm_cfg_ntlp_ntrgt_o.radm_intb_asserted[i*3+2 -: 3]              =  radm_cfg_ntlp_o_int[i].radm_intb_asserted; 
      radm_cfg_ntlp_ntrgt_o.radm_intc_asserted[i*3+2 -: 3]              =  radm_cfg_ntlp_o_int[i].radm_intc_asserted; 
      radm_cfg_ntlp_ntrgt_o.radm_intd_asserted[i*3+2 -: 3]              =  radm_cfg_ntlp_o_int[i].radm_intd_asserted; 
      radm_cfg_ntlp_ntrgt_o.radm_inta_deasserted[i*3+2 -: 3]            =  radm_cfg_ntlp_o_int[i].radm_inta_deasserted; 
      radm_cfg_ntlp_ntrgt_o.radm_intb_deasserted[i*3+2 -: 3]            =  radm_cfg_ntlp_o_int[i].radm_intb_deasserted; 
      radm_cfg_ntlp_ntrgt_o.radm_intc_deasserted[i*3+2 -: 3]            =  radm_cfg_ntlp_o_int[i].radm_intc_deasserted; 
      radm_cfg_ntlp_ntrgt_o.radm_intd_deasserted[i*3+2 -: 3]            =  radm_cfg_ntlp_o_int[i].radm_intd_deasserted; 
      radm_cfg_ntlp_ntrgt_o.radm_err_cor[i*3+2 -: 3]                    =  radm_cfg_ntlp_o_int[i].radm_err_cor; 
      radm_cfg_ntlp_ntrgt_o.radm_err_nf[i*3+2 -: 3]                     =  radm_cfg_ntlp_o_int[i].radm_err_nf; 
      radm_cfg_ntlp_ntrgt_o.radm_err_f[i*3+2 -: 3]                      =  radm_cfg_ntlp_o_int[i].radm_err_f; 
      radm_cfg_ntlp_ntrgt_o.radm_drs_msg[i*3+2 -: 3]                    = radm_cfg_ntlp_o_int[i].radm_drs_msg;
      radm_cfg_ntlp_ntrgt_o.radm_frs_msg_reason[i*12+11 -: 12]    = radm_cfg_ntlp_o_int[i].radm_frs_msg_reason;
      radm_cfg_ntlp_ntrgt_o.radm_frs_msg[i*3+2 -: 3]              = radm_cfg_ntlp_o_int[i].radm_frs_msg;
      radm_cfg_ntlp_ntrgt_o.radm_msg_ltr[i*3+2 -: 3]                         = radm_cfg_ntlp_o_int[i].radm_msg_ltr;
      radm_cfg_ntlp_ntrgt_o.radm_msg_ltr_latency[i*3*32+3*32-1 -: 3*32]      = radm_cfg_ntlp_o_int[i].radm_msg_ltr_latency;


  flt_cdm_addr_o[i*2*64+2*64-1 -: 2*64]                                           = flt_cdm_addr_o_int[i];
  flt_cdm_addr_valid_o[i*2+2-1 -: 2]                                              = flt_cdm_addr_vld_o_int[i];
  // completion
  // Filter I/O                                                                             
  // `ifdef CX_CCIX_INTERFACE_ENABLE                                                                  
  //   hdr_dec_flt_hdr_ccix_tlp_cpl_int[i]                                                       = hdr_dec_flt_hdr_ccix_tlp_cpl[i*CCIX_WD+CCIX_WD-1 -: CCIX_WD];
  // `endif // CX_CCIX_INTERFACE_ENABLE                                                               
  // non posted
  // Filter I/O                                                                                        
  //  `ifdef CX_CCIX_INTERFACE_ENABLE                    
  //   hdr_dec_flt_np_ccix_tlp_int[i]                                                             = hdr_dec_flt_np_ccix_tlp[i*CCIX_WD+CCIX_WD-1 -: CCIX_WD];
  //  `endif // CX_CCIX_INTERFACE_ENABLE                 
  // posted
  // Filter I/O   
  //  `ifdef CX_CCIX_INTERFACE_ENABLE 
  //    hdr_dec_flt_hdr_p_ccix_tlp_int[i]                                                        =  hdr_dec_flt_hdr_p_ccix_tlp[i*CCIX_WD+CCIX_WD-1 -: CCIX_WD];
  //  `endif // CX_CCIX_INTERFACE_ENABLE  
    end //for loop

end

//--------------------------------------------------------------------------------
// Following block is instantiation of per VC common TLP type TOP
// Number of instantiation is depends on number of TRGT1 interfaces are configured
//--------------------------------------------------------------------------------
    
genvar trgt1_num;
generate
  for (trgt1_num=0; trgt1_num < N_TRGT1_INTF; trgt1_num = trgt1_num+1) begin : gen_trgt1_intf_
    radm_filter_dmux_trgt1
     
    #(
      .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+trgt1_num*FILTER_DEMUX_TRGT1_CKH_CNTS)
    ) 
    u_radm_filter_dmux_trgt1 (

      .core_clk                                               (core_clk),
      .radm_clk_ug                                            (radm_clk_ug),
      .core_rst_n                                             (core_rst_n),
      .non_sticky_rst_n                                       (non_sticky_rst_n),
      // configurations               
      .radm_cfg_i                                             (radm_cfg_i),
      .radm_cfg_ntpl_i                                        (radm_cfg_ntlp_i_int[trgt1_num]),
      .radm_cfg_o                                             (radm_cfg_ntlp_o_int[trgt1_num]),
      .flt_cdm_addr_o                                         (flt_cdm_addr_o_int[trgt1_num]),
      .flt_cdm_addr_valid_o                                   (flt_cdm_addr_vld_o_int[trgt1_num]),
      .radm_cfg_atu_in                                        (radm_cfg_atu_in),
      .rx_tlp                                                 (rx_tlp),
      .flit_mode                                              (flit_mode), 
      .app_req_retry_en                                       (app_req_retry_en),
      .app_pf_req_retry_en                                    (app_pf_req_retry_en),
      .rcrb_base_addr                                         (rcrb_base_addr                               ),
      .rcrb_base_addr_valid                                   (rcrb_base_addr_valid                         ),

      // Posted               
      // Filter I/O                       
      //`ifdef CX_CCIX_INTERFACE_ENABLE                     
      //  .hdr_dec_flt_hdr_p_ccix_tlp                         (hdr_dec_flt_hdr_p_ccix_tlp_int[trgt1_num]),
      //`endif // CX_CCIX_INTERFACE_ENABLE                
      // ---- outputs ---------------
      .trgt0_radm_halt_int_p                                  (trgt0_radm_halt_int_p[trgt1_num]), 
      .dmux_trgt0_req_p                                       (dmux_trgt0_req[trgt1_num + trgt1_num]), 
      .dmux_trgt0_fifo_pipe_empty_p                           (dmux_trgt0_p_fifo_pipe_empty[trgt1_num + trgt1_num]), 
      .trgt1_radm_intf_halt_p                                 (trgt1_radm_intf_halt_p[trgt1_num]),
      //----------------------------------------               
      .radm_trgt1_out_p                                       (radm_trgt1_out_p[trgt1_num]),
      .pktadj_crdmgr_crd_restore_p                            (pktadj_crdmgr_crd_restore_p[trgt1_num]),
      // Posted End

      // Non-Posted start   
      // Filter I/O                 
      //`ifdef CX_CCIX_INTERFACE_ENABLE
      //  .hdr_dec_flt_np_ccix_tlp                            (hdr_dec_flt_np_ccix_tlp_int[trgt1_num]),
      //`endif // CX_CCIX_INTERFACE_ENABLE
      // ---- outputs ---------------
      .trgt0_radm_halt_int_np                                 (trgt0_radm_halt_int_np[trgt1_num]),
      .trgt1_radm_intf_halt_np                                (trgt1_radm_intf_halt_np[trgt1_num]),
      .dmux_trgt0_req_np                                      (dmux_trgt0_req[trgt1_num+trgt1_num+1]),
      //----------------------------------------                              
      // Header Logging Interface
      .flt_q_log_p_o                                          (flt_q_log_p_o[trgt1_num]),
      .flt_q_log_cpl_o                                        (flt_q_log_cpl_o[trgt1_num]),
      .flt_q_log_np_o                                         (flt_q_log_np_o[trgt1_num]),
      .log_halt_p                                             (log_halt_p[trgt1_num]),
      .log_halt_np                                            (log_halt_np[trgt1_num]),
      .log_halt_cpl                                           (log_halt_cpl[trgt1_num]),
      //----------------------------------------                              
      .radm_trgt1_out_np                                      (radm_trgt1_out_np[trgt1_num]),
      .pktadj_crdmgr_crd_restore_np                           (pktadj_crdmgr_crd_restore_np[trgt1_num]),

      // For completion     
      // Filter I/O 
      //`ifdef CX_CCIX_INTERFACE_ENABLE
      //  .hdr_dec_flt_hdr_ccix_tlp_cpl                       (hdr_dec_flt_hdr_ccix_tlp_cpl_int[trgt1_num]),
      //`endif // CX_CCIX_INTERFACE_ENABLE
      // `ifdef CX_RASDP_EN             
      // .ras_radm_prot_disable_cpl                           (ras_radm_prot_disable_cpl[trgt1_num]),
      // `endif // CX_RASDP_EN
      .cpl_mlf_err_cpl                                        (cpl_mlf_err_cpl[trgt1_num]),
      .flt_q_cpl_last_cpl                                     (flt_q_cpl_last_cpl[trgt1_num]),
      .cpl_ur_err_cpl                                         (cpl_ur_err_cpl[trgt1_num]),
      .cpl_ca_err_cpl                                         (cpl_ca_err_cpl[trgt1_num]),
      .lut_filt_cpl_abort                                     (lut_filt_cpl_abort[trgt1_num]),
      .unexpected_cpl_err_cpl                                 (unexpected_cpl_err_cpl[trgt1_num]),
      .lut_flt_np_req_type                                    (lut_flt_np_req_type[trgt1_num]),
      .flt_xadm_np_req_type_o                                 (flt_xadm_np_req_type_o[trgt1_num]),
      // ---- outputs ---------------
      .cpl_tlp_cpl                                            (cpl_tlp_cpl[trgt1_num]),
      .flt_dwlenEq0_cpl                                       (flt_dwlenEq0_cpl[trgt1_num]),
      .rtlh_radm_ecrc_err_cpl                                 (rtlh_radm_ecrc_err_cpl[trgt1_num]),
      .rtlh_radm_malform_tlp_err_cpl                          (rtlh_radm_malform_tlp_err_cpl[trgt1_num]),
      .flt_q_rcvd_cpl_tlp_tag_cpl                             (flt_q_rcvd_cpl_tlp_tag_cpl[trgt1_num]),
      .cpl_status_cpl                                         (cpl_status_cpl[trgt1_num]),
      //----------------------------------------               
      .trgt1_radm_intf_halt_cpl                               (trgt1_radm_intf_halt_cpl[trgt1_num]),
      .radm_trgt1_out_cpl                                     (radm_trgt1_out_cpl[trgt1_num]),
      .pktadj_crdmgr_crd_restore_cpl                          (pktadj_crdmgr_crd_restore_cpl[trgt1_num]),
      .flt_cpl_lut                                            (flt_cpl_lut),
      .trgt_grnt_trgt1                                        (trgt_grnt_trgt1_top.trgt_grnt_trgt1_top[trgt1_num]),
      // Demux Clock Gating Control Signals
      .trgt_clkg_ctrl                                         (port_trgt_clkg_ctrl.port_trgt_clkg_ctrl[trgt1_num])
`ifndef SYNTHESIS
      ,
      .flt_pkt_num_p_valid                                    (flt_pkt_num_p_valid[trgt1_num]),
      .flt_pkt_num_p                                          (flt_pkt_num_p[trgt1_num]),
      .flt_pkt_num_np_valid                                   (flt_pkt_num_np_valid[trgt1_num]),
      .flt_pkt_num_np                                         (flt_pkt_num_np[trgt1_num]),
      .flt_pkt_num_cpl_valid                                  (flt_pkt_num_cpl_valid[trgt1_num]),
      .flt_pkt_num_cpl                                        (flt_pkt_num_cpl[trgt1_num])
`endif

      , 
      .ecrc_err_inj_enable                                    (ecrc_err_inj_enable[trgt1_num]),
      .ecrc_pkt_eot_with_vld_td                               (ecrc_pkt_eot_with_vld_td[trgt1_num])
      ,
      .ras_dp_err_log                                         (ras_dp_err_log[trgt1_num]        )
      ,
      .ras_dp_err_inj                                         (ras_dp_err_inj                   )
);
  end // gen_trgt1_intf_
endgenerate

endmodule

