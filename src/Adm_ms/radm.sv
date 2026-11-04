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
// --   RCS information:
// ---    $DateTime: 2024/01/26 07:16:49 $
// ---    $Revision: #16 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm.sv#16 $
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/pcie_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module  radm
  import pcie_pkg::E_P;
  import pcie_pkg::E_NP;
  import pcie_pkg::E_CPL;
  import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD;
  import DWC_pcie_ctl_pkg::np_req_tx_type_e;
  import DWC_pcie_ctl_pkg::NW;
  import DWC_pcie_ctl_pkg::NVC_WD;
  import DWC_pcie_ctl_pkg::TAG_SIZE;
  import DWC_pcie_ctl_pkg::DW;
  import DWC_pcie_ctl_pkg::DCA_WD;
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NVF;
  import DWC_pcie_ctl_pkg::NVC;
  import DWC_pcie_ctl_pkg::PF_WD;
  import DWC_pcie_ctl_pkg::VFI_WD;
  import DWC_pcie_ctl_pkg::VF_WD;
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_RADM;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_core_pkg::QDW_DW;
  import DWC_pcie_core_pkg::QDW_PAR;
  import DWC_pcie_core_pkg::radm_hdr_log_s;
  import DWC_pcie_core_pkg::xadm_radm_tx_npr_t;
  import DWC_pcie_core_pkg::radm_xadm_rcvd_cpl_t;
  import DWC_pcie_core_pkg::radm_xadm_timeout_npr_t;
  import DWC_pcie_core_pkg::RX_NQDW;
  import radm_ms_pkg::radm_form_s;
  import radm_ms_pkg::radm_outq_tlp_s;
  import radm_ms_pkg::radm_rx_tlp_s;
  import radm_ms_pkg::NQW;
  import radm_ms_pkg::NQW_R;
  import radm_ms_pkg::N_RADM_CPL_TLP;
  import radm_ms_pkg::NO_OF_TRGT0_INTF;
  import radm_ms_pkg::NHW;
  import radm_ms_pkg::PKT_ORD_WD;
  import radm_ms_pkg::HW;
  import radm_ms_pkg::RADM_HDR_PROT_WD;
  import radm_ms_pkg::FILTER_DEMUX_TRGT1_CKH_CNTS;
  import radm_ms_pkg::CPL_LUT_DEPTH_EXTERNAL;
  import radm_ms_pkg::INT_NVF;
  import radm_ms_pkg::N_TRGT1_INTF;
  import radm_ms_pkg::FX_TLP;
  import radm_ms_pkg::INT_HDW;
  import radm_ms_pkg::radm_cfg_i_s;
  import radm_ms_pkg::radm_cfg_ntlp_ntrgt_i_s;
  import radm_ms_pkg::radm_cfg_ntlp_ntrgt_o_s;
  import radm_ms_pkg::radm_cfg_atu_s;
  import radm_ms_pkg::trgt1_p_out_s;
  import radm_ms_pkg::trgt1_np_out_s;
  import radm_ms_pkg::trgt1_cpl_out_s;
  import radm_ms_pkg::ras_des_dbg_ntrgt_ntlp_s;
  import radm_ms_pkg::radm_qstatic_s;
  import radm_ms_pkg::flt_cpl_lut_s;
  import radm_ms_pkg::radm_crd_restore_s;
  import radm_ms_pkg::flt_q_dmux_o_s;
  import radm_ms_pkg::port_trgt_clkg_ctrl_s;
  import radm_ms_pkg::trgt_grnt_top_s;
  import radm_ms_pkg::rtrgt1_tlp_out_s;
  import radm_ms_pkg::pktstr_hlog_s;
`ifndef SYNTHESIS
`endif
#(
    /////////////////////////////////////////////////
    // Override parameters.
    /////////////////////////////////////////////////
    parameter               FORMQ_RD_PORTS   =   `CX_RADM_FORMQ_N_READ_PORT_VC,
    parameter               RAM_WD_VC0_P     =   `RAM_WD_VC0_P,
    parameter               RAM_DP_VC0_P     =   `RAM_DP_VC0_P,
    parameter               RAM_PW_VC0_P     =   `RAM_PW_VC0_P ,
    parameter               RAM_WD_VC0_NP    =   `RAM_WD_VC0_NP,
    parameter               RAM_DP_VC0_NP    =   `RAM_DP_VC0_NP,
    parameter               RAM_PW_VC0_NP    =   `RAM_PW_VC0_NP,
    parameter               RAM_WD_VC0_CPL   =   `RAM_WD_VC0_CPL,
    parameter               RAM_DP_VC0_CPL   =   `RAM_DP_VC0_CPL,
    parameter               RAM_PW_VC0_CPL   =   `RAM_PW_VC0_CPL

)
              (
    input                                               core_clk,
    input                                               core_rst_n,
    input                                               non_sticky_rst_n,
    input                                               flit_mode_en,
    input                                               pm_l1_aspm_entr,
    input                                               radm_clk_ug,                        // ungated radm clock used to clock through anticipated RID in the radm cpl filter
    input                                               cfg_radm_clk_control,               // enable clock gating in the radm 
    input                                               rstctl_core_flush_req,
    //--------------- Interace from RTLH ---------------------
    input    DWC_pcie_core_pkg::rtlh_radm_datapath_t    rtlh_radm,
   `ifndef SYNTHESIS
    // Outputs to testbench
    output DWC_pcie_core_pkg::radm_tb_tlp_ordering_t    radm_tlp_order,  
    output logic [N_TRGT1_INTF-1:0]                     radm_flt_pkt_num_p_valid,
    output logic [(N_TRGT1_INTF*PKT_ORD_WD)-1:0]        radm_flt_pkt_num_p,
    output logic [N_TRGT1_INTF-1:0]                     radm_flt_pkt_num_np_valid,
    output logic [(N_TRGT1_INTF*PKT_ORD_WD)-1:0]        radm_flt_pkt_num_np,
    output logic [N_TRGT1_INTF-1:0]                     radm_flt_pkt_num_cpl_valid,
    output logic [(N_TRGT1_INTF*PKT_ORD_WD)-1:0]        radm_flt_pkt_num_cpl,
   `endif // !SYNTHESIS      
    //--------------- Interface from XADM --------------------
    ///////////////////// transmitted NP TLP inputs /////////////////////
    input   xadm_radm_tx_npr_t                          xadm_radm_tx_npr,
    //--------------- External Memory Interfaces -------------
    output [NQW*RAM_PW_VC0_P-1:0]                       radm_formqram_addra_vc0_p,          // RAM write address
    output [NQW-1:0]                                    radm_formqram_ena_vc0_p,            // RAM enable A
    output [NQW-1:0]                                    radm_formqram_wea_vc0_p,            // RAM write enable A
    output [NQW*RAM_WD_VC0_P-1:0]                       radm_formqram_dina_vc0_p,           // RAM write data A
    output [NQW*RAM_PW_VC0_P-1:0]                       radm_formqram_addrb_vc0_p,          // RAM read address B
    output [NQW-1:0]                                    radm_formqram_enb_vc0_p,            // RAM enable B
    input  [NQW*RAM_WD_VC0_P-1:0]                       formqram_radm_doutb_vc0_p,          // RAM read data B

    output [NQW*RAM_PW_VC0_NP-1:0]                      radm_formqram_addra_vc0_np,         // RAM write address
    output [NQW-1:0]                                    radm_formqram_ena_vc0_np,           // RAM enable A
    output [NQW-1:0]                                    radm_formqram_wea_vc0_np,           // RAM write enable A
    output [NQW*RAM_WD_VC0_NP-1:0]                      radm_formqram_dina_vc0_np,          // RAM write data A
    output [NQW*RAM_PW_VC0_NP-1:0]                      radm_formqram_addrb_vc0_np,         // RAM read address B
    output [NQW-1:0]                                    radm_formqram_enb_vc0_np,           // RAM enable B
    input  [NQW*RAM_WD_VC0_NP-1:0]                      formqram_radm_doutb_vc0_np,         // RAM read data B

    output [NQW*RAM_PW_VC0_CPL-1:0]                     radm_formqram_addra_vc0_cpl,        // RAM write address
    output [NQW-1:0]                                    radm_formqram_ena_vc0_cpl,          // RAM enable A
    output [NQW-1:0]                                    radm_formqram_wea_vc0_cpl,          // RAM write enable A
    output [NQW*RAM_WD_VC0_CPL-1:0]                     radm_formqram_dina_vc0_cpl,         // RAM write data A
    output [NQW*RAM_PW_VC0_CPL-1:0]                     radm_formqram_addrb_vc0_cpl,        // RAM read address B
    output [NQW-1:0]                                    radm_formqram_enb_vc0_cpl,          // RAM enable B
    input  [NQW*RAM_WD_VC0_CPL-1:0]                     formqram_radm_doutb_vc0_cpl,        // RAM read data B

    output   [NVC-1:0][FORMQ_RD_PORTS-1:0]              radm_rtlh_ph_ca,                    // Credit allocated (header)
    output   [NVC-1:0][FORMQ_RD_PORTS-1:0]              radm_rtlh_nph_ca,                   // Credit allocated (header)
    output   [NVC-1:0][FORMQ_RD_PORTS-1:0]              radm_rtlh_cplh_ca                   // Credit allocated (header)
      ,   
      output   [NVC-1:0][DCA_WD-1:0]                    radm_rtlh_pd_ca,                    // Credit allocated (data)
      output   [NVC-1:0][DCA_WD-1:0]                    radm_rtlh_npd_ca,                   // Credit allocated (data)
      output   [NVC-1:0][DCA_WD-1:0]                    radm_rtlh_cpld_ca                   // Credit allocated (data)

    ///////////////////  CPL LUT signals  ///////////////////////////////       
    ,       
    input                                               cfg_p2p_track_cpl_to,              // 0: bydefault, do not track cpl in lut for P2P; 1: track cpl in lut for P2P.
    input                                               cfg_p2p_err_rpt_ctrl,              // 1: bydefault, P2P error reporting enable; 0: P2P error reporting disable.
    input   [3:0]                                       device_type                        // "static"
      ,   
      input                                             cdm_dpc_triggered,                 // DPC has been triggered indication
      input                                             cdm_core_in_dpc,                   // Core is in Downstream Port Containment mode.
      input                                             cfg_dpc_cpl_cntrl                  // DPC CPL control bit from CDM. To redirect poison err to UR/CA     
    //////////////// completion packet signals ///////////////////  

    



    
      ,
      input   [(4*NF)-1:0]                              cfg_cpl_timeout_range      // "static" // Completion timeout ranges
    ,
    input   [(NF-1):0]                                  cfg_cpl_timeout_disable,    // "static" // Completion timeout disable
    input                                               xtlh_np_tlp_early,          // an early indication from layer3 that a NP TLP has been sent
    input   [2:0]                                       current_data_rate          // "static" // 0=running at gen1 rate, 1=running at gen2 rate, 2-gen3, 3-gen4
    ,
    output  [NF-1:0]                                    radm_cpl_pending,
    output                                              radm_cpl_timeout,
    output                                              radm_cpl_timeout_cdm,       // Same information as radm_cpl_timeout but without the timeout tags flr'ed
    output  [2:0]                                       radm_timeout_cpl_tc,        // not used
    output  [2:0]                                       radm_timeout_cpl_attr      // not used
    ,
    output  [TAG_SIZE-1:0]                              radm_timeout_cpl_tag,
    output  [PF_WD-1:0]                                 radm_timeout_func_num,
    output  [11:0]                                      radm_timeout_cpl_len

    ,output  [CPL_LUT_DEPTH_EXTERNAL-1:0]         radm_cpl_lut_valid

    /////////////////////////////////// TRGT1 Signals ///////////////////////////////////////
    // Configurations 
    ,
    input   radm_cfg_i_s                                radm_cfg_i,
    input   radm_cfg_ntlp_ntrgt_i_s                     radm_cfg_ntlp_ntrgt_i,
    output  radm_cfg_ntlp_ntrgt_o_s                     radm_cfg_ntlp_ntrgt_o,
    output  radm_hdr_log_s                              radm_hdr_log, // output from radm_hdr_log
    output logic [N_TRGT1_INTF*2*64-1:0]                flt_cdm_addr_o,
    output logic [N_TRGT1_INTF*2-1:0]                   flt_cdm_addr_valid_o,
    // ATU
    input radm_cfg_atu_s                                radm_cfg_atu_in ,
    // configurations end 

    // Posted
    input                                               app_req_retry_en,
    input [N_TRGT1_INTF*NF-1:0]                            app_pf_req_retry_en

    ,
    output  logic  [51:0]                               rcrb_base_addr,             // Indicates the base address for the RCRB region. The upper address bits[63:12] of the first memory access received after link initialization is the RCRB base address
    output  logic                                       rcrb_base_addr_valid        // Indicates the base address valid for the RCRB region

    // --------------- Inputs ---------------------
    // cpl
    ,
    input    [N_TRGT1_INTF-1:0]                         trgt1_radm_intf_halt_cpl,
    // posted
    input                                               trgt0_radm_halt,
    input   [N_TRGT1_INTF-1:0]                          trgt1_radm_intf_halt_p,
    // non posted
    input   [N_TRGT1_INTF-1:0]                          trgt1_radm_intf_halt_np

    /// For completion 

    // Filter I/O 

    //  `ifdef CX_CCIX_INTERFACE_ENABLE
    //    ,
    //      input [N_TRGT1_INTF*CCIX_WD-1:0]            hdr_dec_flt_hdr_ccix_tlp_cpl
    //  `endif // CX_CCIX_INTERFACE_ENABLE              
    //`ifdef CX_RASDP_EN                                
    //    input  [N_TRGT1_INTF-1:0]                     ras_radm_prot_disable_cpl,
    // `endif // CX_RASDP_EN

      //  `ifdef CX_CCIX_INTERFACE_ENABLE
      //    ,
      //    output logic [CCIX_WD-1:0]                  ccix_p_0_tlp
      //  `endif // CX_CCIX_INTERFACE_ENABLE
      //,
       ,
      output trgt1_p_out_s [N_TRGT1_INTF-1:0]             radm_trgt1_out_p  

      //,
      //output logic [127:0]                              radm_hdr_np_0_log

      // `ifdef CX_CCIX_INTERFACE_ENABLE
      //   ,
      //   output logic [CCIX_WD-1:0]                   ccix_np_0_tlp
      // `endif // CX_CCIX_INTERFACE_ENABLE
      ,
      output trgt1_np_out_s [N_TRGT1_INTF-1:0]            radm_trgt1_out_np,  
      output trgt1_cpl_out_s [N_TRGT1_INTF-1:0]           radm_trgt1_out_cpl,  
      output logic                                        radm_trgt1_p_pending 
     

  /////////////////////////////////////////
  // Output ports from trgt0 module
  //
  ,
  output logic  [DW+`TRGT_DATA_PROT_WD-1:0] radm_trgt0_data, 
  output logic                         radm_trgt0_abort,
  output logic                         radm_trgt0_dv,
  output logic  [NW-1:0]               radm_trgt0_dwen,
  output logic                         radm_trgt0_ecrc_err,
  output logic                         radm_trgt0_eot,   
  output logic [`TRGT_HDR_WD-1:0]      radm_trgt0_hdr,   
  output logic                         radm_trgt0_pending,   
  output logic                         radm_trgt0_hv,
  output logic                         radm_trgt0_np_rsvd
  
// RADM diag interface
  ,output logic [NVC-1:0]                           radm_qoverflow_ms,
  output logic [NVC-1:0]                           radm_q_not_empty_ms,
  output logic                                     radm_formq_read_err_ms,
  output logic                                     radm_formq_overflow_ms,
  output logic                                     radm_formq_not_empty_ms
  
  //ide interface
    ,output logic                                radm_idle
    ,output logic                                radm_clk_en
    ,
    output ras_dp_err_log_t                                    ras_dp_err_log,
    input logic                                                rasdp_error_mode
    ,input  ras_dp_err_inj_t                                   ras_dp_err_inj
    ,input                                                     ras_dp_err_inj_wake_up
      ,input                                       cdm_ras_des_einj0_enable         // Error injection 0 enable
      ,input   [3:0]                               cdm_ras_des_einj0_crc_type       // Error injection 0 CRC type selector
      ,input   [7:0]                               cdm_ras_des_einj0_count          // Error injection 0 Count
      ,input   [2:0]                               cdm_ras_des_einj0_vc_sel         // Error injection 0 ECRC Virtual Channel Selection
      ,input   [1:0]                               cdm_ras_des_einj0_fc_sel         // Error injection 0 ECRC Flow Control Selection 
      ,input                                       cdm_ras_des_einj0_intf_sel       // Error injection 0 ECRC Interface Selection
      ,output  [2:0]                               radm_einj0_ecrc_evt              // Error injection 0 Rx ECRC TLP event
    ,output ras_des_dbg_ntrgt_ntlp_s               radm_ras_des_err_info_0

  );
localparam  P0  = 0; // Port 0 - this will become an actual index when MultiPort will be supported
localparam  VC0 = 0; // VC 0 - this will become an actual index when MultiVC will be supported
localparam    N_RADM_HDEC_CHK     = 0;
localparam    N_RADM_FORMQ_CHK_VC0  = NVC*3*(2*NQW+NQW_R);
localparam    N_RADM_IDE_CHK      = 0 ;
localparam    N_RADM_FILTER_CHK   = 0 + N_TRGT1_INTF*(FILTER_DEMUX_TRGT1_CKH_CNTS);
localparam    N_RADM_TRGT0_CHK    = 1 + N_TRGT1_INTF*(2);

localparam BLOCK_RAS_DP_PROT_CHK_N = 
                                     N_RADM_HDEC_CHK +    // header decoder checkers
                                     N_RADM_FORMQ_CHK_VC0 +   // Form queue checkers
                                     N_RADM_IDE_CHK +     // IDE checkers
                                     N_RADM_FILTER_CHK +   // Filter checkers
                                     N_RADM_TRGT0_CHK;   // Target 0 checkers

localparam RAS_DP_PROT_CHK_ID_BASE_HDEC                    = RAS_DP_PROT_CHK_ID_BASE_RADM     + 0;
localparam RAS_DP_PROT_CHK_ID_BASE_FORMQ                   = RAS_DP_PROT_CHK_ID_BASE_HDEC     + 1*N_RADM_HDEC_CHK;
localparam RAS_DP_PROT_CHK_ID_BASE_IDE                     = RAS_DP_PROT_CHK_ID_BASE_FORMQ    + 1*N_RADM_FORMQ_CHK_VC0;
localparam RAS_DP_PROT_CHK_ID_BASE_FILTER                  = RAS_DP_PROT_CHK_ID_BASE_IDE      + 1*N_RADM_IDE_CHK;
localparam RAS_DP_PROT_CHK_ID_BASE_TRGT0                   = RAS_DP_PROT_CHK_ID_BASE_FILTER   + 1*N_RADM_FILTER_CHK;


ras_dp_err_inj_t ras_dp_err_inj_central;
ras_dp_err_inj_t ras_dp_err_inj_formq;
ras_dp_err_inj_t ras_dp_err_inj_filter;
ras_dp_err_inj_t ras_dp_err_inj_trgt0;

localparam CENTRAL_BLOCK_RAS_DP_PROT_CHK_N = 2 + 1;
localparam FORMATION_CKHS = NVC;
ras_dp_err_log_t [CENTRAL_BLOCK_RAS_DP_PROT_CHK_N-1:0] ras_dp_err_log_central;
ras_dp_err_log_t [FORMATION_CKHS-1:0] ras_dp_err_log_formq;
ras_dp_err_log_t [N_RADM_FILTER_CHK-1:0] ras_dp_err_log_filter;
ras_dp_err_log_t [N_RADM_TRGT0_CHK-1:0] ras_dp_err_log_trgt0;

logic [14:0] out_ras_dp_wake_up;

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N         (FORMATION_CKHS),
    .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1)
) u_ras_dp_err_mgr_formq (
    .clk                (core_clk),
    .rst_n              (core_rst_n),
    .out_ras_dp_wake_up (out_ras_dp_wake_up[0]),
    .in_ras_dp_err_inj  (ras_dp_err_inj_central),
    .out_ras_dp_err_inj (ras_dp_err_inj_formq),
    .in_ras_dp_err_log  (ras_dp_err_log_formq),
    .out_ras_dp_err_log (ras_dp_err_log_central[0])
);

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N (N_RADM_TRGT0_CHK)
) u_ras_dp_err_mgr_trgt0 (
    .clk                (core_clk),
    .rst_n              (core_rst_n),
    .out_ras_dp_wake_up (out_ras_dp_wake_up[1]),
    .in_ras_dp_err_inj  (ras_dp_err_inj_central),
    .out_ras_dp_err_inj (ras_dp_err_inj_trgt0),
    .in_ras_dp_err_log  (ras_dp_err_log_trgt0),
    .out_ras_dp_err_log (ras_dp_err_log_central[1])
);

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N (N_RADM_FILTER_CHK)
) u_ras_dp_err_mgr_filter (
    .clk                (core_clk),
    .rst_n              (core_rst_n),
    .out_ras_dp_wake_up (out_ras_dp_wake_up[2]),
    .in_ras_dp_err_inj  (ras_dp_err_inj_central),
    .out_ras_dp_err_inj (ras_dp_err_inj_filter),
    .in_ras_dp_err_log  (ras_dp_err_log_filter),
    .out_ras_dp_err_log (ras_dp_err_log_central[2])
);

assign out_ras_dp_wake_up[3] = 1'b0;

ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N         (CENTRAL_BLOCK_RAS_DP_PROT_CHK_N),
    .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1)
) u_ras_dp_err_mgr (
    .clk                (core_clk),
    .rst_n              (core_rst_n),
    .out_ras_dp_wake_up (out_ras_dp_wake_up[4]),
    .in_ras_dp_err_inj  (ras_dp_err_inj              ),
    .out_ras_dp_err_inj (ras_dp_err_inj_central  ),
    .in_ras_dp_err_log  (ras_dp_err_log_central),
    .out_ras_dp_err_log (ras_dp_err_log              )
);

  localparam DATA_PROT_WD = `TRGT_DATA_PROT_WD;

  ///////////////////////////////////////////////////////////////////////////
  // Local wires and registers
  //
  ///////////////////////////////////////////////////////////////////////////
  //---------------------- Quasi-Static Signals------------------------------
  radm_qstatic_s                                                 radm_qstatic_in;   
  radm_qstatic_s                                                 radm_qstatic_in_d;   

  //----------------------filter interface signals---------------------------
  radm_cfg_i_s                                                   radm_cfg_i_int;

  radm_form_s     [2:0][FORMQ_RD_PORTS-1:0]                       rxq_tlp;               // FormationQ TLP interface
  wire            [2:0]                                           outqmgr_form_halt;     // Halt signals - back pressure to Formation Queues

  radm_outq_tlp_s [2:0]                                           outq_tlp;          // OutQ manager to Filter interface
  radm_rx_tlp_s   [2:0]                                           rx_tlp;            // Received TLP struct, from OutQ/IDE, to filter

  flt_cpl_lut_s                                                   flt_cpl_lut;

  logic    hdr_log_idle ;    
  logic    [N_TRGT1_INTF-1:0][3-1:0]                              ecrc_err_inj_enable;
  logic    [N_TRGT1_INTF-1:0][3-1:0]                              ecrc_pkt_eot_with_vld_td;

  logic    [NVC-1:0][RX_NQDW-1:0]                                 hdec_form_nqdw_hv_p;          
  logic    [NVC-1:0][RX_NQDW-1:0]                                 hdec_form_nqdw_dv_p;         
  logic    [NVC-1:0][RX_NQDW-1:0]                                 hdec_form_nqdw_eot_p;  
  logic    [NVC-1:0][RX_NQDW-1:0]                                 hdec_form_nqdw_hv_np;        
  logic    [NVC-1:0][RX_NQDW-1:0]                                 hdec_form_nqdw_dv_np;         
  logic    [NVC-1:0][RX_NQDW-1:0]                                 hdec_form_nqdw_eot_np;    
  logic    [NVC-1:0][RX_NQDW-1:0]                                 hdec_form_nqdw_hv_cpl;        
  logic    [NVC-1:0][RX_NQDW-1:0]                                 hdec_form_nqdw_dv_cpl;         
  logic    [NVC-1:0][RX_NQDW-1:0]                                 hdec_form_nqdw_eot_cpl;
  logic    [RX_NQDW-1:0][QDW_DW+QDW_PAR-1:0]                                 hdec_form_nqdw_data;          
  logic    [RX_NQDW-1:0][4-1:0]                                   hdec_form_nqdw_hdwen;         
  logic    [RX_NQDW-1:0][4-1:0]                                   hdec_form_nqdw_ddwen;         
  logic    [RX_NQDW-1:0]                                          hdec_form_nqdw_dllp_err;  
  logic    [RX_NQDW-1:0]                                          hdec_form_nqdw_fm_poisoned;
  logic    [RX_NQDW-1:0]                                          hdec_form_nqdw_fm_nullified;
  logic    [NVC-1:0][RX_NQDW-1:0][PKT_ORD_WD-1:0]                 hdec_form_p_pkt_order_num;
  logic    [RX_NQDW-1:0]                                          hdec_form_prefix_qdw;   
  logic    [NVC-1:0][2:0]                                         hdec_form_discard_prefixes; 
  logic    [RX_NQDW-1:0]                                          hdec_form_mac_ecrc_qdw;         

  logic    [NVC-1:0][2:0]                                         radm_formq_not_empty;  
  logic    [NVC-1:0][2:0]                                         outqmgr_filt_formq_not_empty;
  logic    [NVC-1:0][2:0]                                         radm_formq_overflow;  
 
  radm_crd_restore_s                                              pktadj_crdmgr_crd_restore_p;
  radm_crd_restore_s                                              pktadj_crdmgr_crd_restore_np;
  radm_crd_restore_s                                              pktadj_crdmgr_crd_restore_cpl;

  /////////////////////////////////////////
  // Local wires between filter and CPL LUT
  logic    [N_RADM_CPL_TLP-1:0][3-1:0]                            filt_lut_cpl_status;
  logic    [N_RADM_CPL_TLP-1:0]                                   filt_lut_dwlenEq0;
  logic    [N_RADM_CPL_TLP-1:0]                                   rtlh_radm_malform_tlp_err;  // Indication that TLP is malformed (valid @ HV)
  logic    [N_RADM_CPL_TLP-1:0]                                   rtlh_radm_ecrc_err;         // Indication that TLP has ECRC err (valid @ EOT)
  logic    [N_RADM_CPL_TLP-1:0]                                   lut_filt_cpl_abort;
  logic    [N_RADM_CPL_TLP-1:0]                                   lut_filt_cpl_last_cpl;
  logic    [N_RADM_CPL_TLP-1:0]                                   lut_filt_cpl_mlf_err_cpl;
  logic    [N_RADM_CPL_TLP-1:0]                                   lut_filt_cpl_ur_err_cpl;
  logic    [N_RADM_CPL_TLP-1:0]                                   lut_filt_cpl_ca_err_cpl;
  logic    [N_RADM_CPL_TLP-1:0]                                   lut_filt_unexpected_cpl_err_cpl;

  logic   [NF-1:0]                                                radm_flr_pf_active;         // Asserted by the filter when an FLR is snooped
  logic                                                           radm_cpl_lut_busy;          // CPL LUT busy indication
  logic                                                           radm_cpl_lut_pending;
  logic [NVF-1:0]                                          radm_flr_vf_active; 


  logic                                                           filt_ord_cpl_1_halt_in_cpl;
  logic                                                           filt_ord_p_1_halt_in_p;
  flt_q_dmux_o_s [N_TRGT1_INTF-1:0]                               p_radm_hdr_log_i;
  flt_q_dmux_o_s [N_TRGT1_INTF-1:0]                               np_radm_hdr_log_i;
  flt_q_dmux_o_s [N_TRGT1_INTF-1:0]                               cpl_radm_hdr_log_i;
  logic [FX_TLP-1:0]                                              log_halt;

  logic  cpl_trgt_interface_no;
logic [6:0]                                       radm_timeout_low_addr;
logic [NP_REQ_TX_TYPE_WD-1:0]                     radm_timeout_np_req_type;  
logic [N_RADM_CPL_TLP-1:0][NP_REQ_TX_TYPE_WD-1:0] lut_flt_np_req_type;
logic [N_TRGT1_INTF-1:0][NP_REQ_TX_TYPE_WD-1:0]   flt_xadm_np_req_type_o;
logic [3:0]                                       device_type_d;                       // "static"

logic                                    radm_clk_en_int;

  assign  radm_trgt0_pending = 1'b0;

  port_trgt_clkg_ctrl_s                  port_trgt_clkg_ctrl; // Demux Clock Gating Info
  logic                                  radm_trgt0_p, radm_trgt0_np;


// --------------------------------------------------------------------------------------
// Module Instantiation
// --------------------------------------------------------------------------------------

  radm_tlp_header_decoder
   u_radm_tlp_header_decoder
  (
    .core_clk                      (core_clk                      ),                         
    .core_rst_n                    (core_rst_n                    ),                        
    .flit_mode_en                  (radm_qstatic_in_d.flit_mode_en[0]),
    .cfg_ecrc_chk_en               (radm_cfg_i_int.cfg_ecrc_chk_en), 
    // rtlh to radm interface
    .rtlh_radm                     (rtlh_radm                     ),     
    `ifndef SYNTHESIS
    .radm_tlp_order                (radm_tlp_order                ), 
    `endif // !SYNTHESIS   
    // Denuxed interfaces for each interface of formation queue signals.
    .hdec_form_nqdw_hv_p           (hdec_form_nqdw_hv_p           ),        
    .hdec_form_nqdw_dv_p           (hdec_form_nqdw_dv_p           ),         
    .hdec_form_nqdw_eot_p          (hdec_form_nqdw_eot_p          ),  
    .hdec_form_nqdw_hv_np          (hdec_form_nqdw_hv_np          ),        
    .hdec_form_nqdw_dv_np          (hdec_form_nqdw_dv_np          ),         
    .hdec_form_nqdw_eot_np         (hdec_form_nqdw_eot_np         ),    
    .hdec_form_nqdw_hv_cpl         (hdec_form_nqdw_hv_cpl         ),        
    .hdec_form_nqdw_dv_cpl         (hdec_form_nqdw_dv_cpl         ),         
    .hdec_form_nqdw_eot_cpl        (hdec_form_nqdw_eot_cpl        ),
    .hdec_form_nqdw_data           (hdec_form_nqdw_data           ),         
    .hdec_form_nqdw_hdwen          (hdec_form_nqdw_hdwen          ),        
    .hdec_form_nqdw_ddwen          (hdec_form_nqdw_ddwen          ),         
    .hdec_form_nqdw_dllp_err       (hdec_form_nqdw_dllp_err       ),
    .hdec_form_nqdw_fm_poisoned    (hdec_form_nqdw_fm_poisoned    ),
    .hdec_form_nqdw_fm_nullified   (hdec_form_nqdw_fm_nullified   ),
    .hdec_form_p_pkt_order_num     (hdec_form_p_pkt_order_num     ),
    .hdec_form_mac_ecrc_qdw        (hdec_form_mac_ecrc_qdw        ) 
    ,
    .hdec_form_prefix_qdw          (hdec_form_prefix_qdw          ),
    .hdec_form_discard_prefixes    (hdec_form_discard_prefixes    )
  );


  radm_formation_ms
   
  #(   
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_FORMQ),
    .RAM_WD_P                      (RAM_WD_VC0_P                      ),     
    .RAM_DP_P                      (RAM_DP_VC0_P                      ),    
    .RAM_PW_P                      (RAM_PW_VC0_P                      ),  

    .RAM_WD_NP                     (RAM_WD_VC0_NP                     ),    
    .RAM_DP_NP                     (RAM_DP_VC0_NP                     ),    
    .RAM_PW_NP                     (RAM_PW_VC0_NP                     ),    

    .RAM_WD_CPL                    (RAM_WD_VC0_CPL                    ),   
    .RAM_DP_CPL                    (RAM_DP_VC0_CPL                    ),   
    .RAM_PW_CPL                    (RAM_PW_VC0_CPL                    )   
  ) u_radm_formation_ms
  (
    //--------------------- inputs --------------------------------------------
    .hdec_form_nqdw_data           (hdec_form_nqdw_data               ),         
    .hdec_form_nqdw_hdwen          (hdec_form_nqdw_hdwen              ),        
    .hdec_form_nqdw_ddwen          (hdec_form_nqdw_ddwen              ),  
    .hdec_form_nqdw_hv_p           (hdec_form_nqdw_hv_p[0]            ),        
    .hdec_form_nqdw_dv_p           (hdec_form_nqdw_dv_p[0]            ),         
    .hdec_form_nqdw_eot_p          (hdec_form_nqdw_eot_p[0]           ),  
    .hdec_form_nqdw_hv_np          (hdec_form_nqdw_hv_np[0]           ),        
    .hdec_form_nqdw_dv_np          (hdec_form_nqdw_dv_np[0]           ),         
    .hdec_form_nqdw_eot_np         (hdec_form_nqdw_eot_np[0]          ),    
    .hdec_form_nqdw_hv_cpl         (hdec_form_nqdw_hv_cpl[0]          ),        
    .hdec_form_nqdw_dv_cpl         (hdec_form_nqdw_dv_cpl[0]          ),         
    .hdec_form_nqdw_eot_cpl        (hdec_form_nqdw_eot_cpl[0]         ),
    .hdec_form_nqdw_dllp_err       (hdec_form_nqdw_dllp_err           ),
    .hdec_form_nqdw_fm_poisoned    (hdec_form_nqdw_fm_poisoned        ),
    .hdec_form_nqdw_fm_nullified   (hdec_form_nqdw_fm_nullified       ),
    .hdec_form_p_pkt_order_num     (hdec_form_p_pkt_order_num[0]      ),  
    .hdec_form_prefix_qdw          (hdec_form_prefix_qdw              ),
    .hdec_form_discard_prefixes    (hdec_form_discard_prefixes[0]     ),
    .hdec_form_mac_ecrc_qdw        (hdec_form_mac_ecrc_qdw            ),        

    // External RAM interfaces 
    .radm_formqram_addra_p         (radm_formqram_addra_vc0_p         ),         
    .radm_formqram_ena_p           (radm_formqram_ena_vc0_p           ),           
    .radm_formqram_wea_p           (radm_formqram_wea_vc0_p           ),           
    .radm_formqram_dina_p          (radm_formqram_dina_vc0_p          ),          
    .radm_formqram_addrb_p         (radm_formqram_addrb_vc0_p         ),         
    .radm_formqram_enb_p           (radm_formqram_enb_vc0_p           ),           
    .formqram_radm_doutb_p         (formqram_radm_doutb_vc0_p         ),     

    .radm_formqram_addra_np        (radm_formqram_addra_vc0_np        ),         
    .radm_formqram_ena_np          (radm_formqram_ena_vc0_np          ),           
    .radm_formqram_wea_np          (radm_formqram_wea_vc0_np          ),           
    .radm_formqram_dina_np         (radm_formqram_dina_vc0_np         ),          
    .radm_formqram_addrb_np        (radm_formqram_addrb_vc0_np        ),         
    .radm_formqram_enb_np          (radm_formqram_enb_vc0_np          ),           
    .formqram_radm_doutb_np        (formqram_radm_doutb_vc0_np        ),    

    .radm_formqram_addra_cpl       (radm_formqram_addra_vc0_cpl       ),         
    .radm_formqram_ena_cpl         (radm_formqram_ena_vc0_cpl         ),           
    .radm_formqram_wea_cpl         (radm_formqram_wea_vc0_cpl         ),           
    .radm_formqram_dina_cpl        (radm_formqram_dina_vc0_cpl        ),          
    .radm_formqram_addrb_cpl       (radm_formqram_addrb_vc0_cpl       ),         
    .radm_formqram_enb_cpl         (radm_formqram_enb_vc0_cpl         ),           
    .formqram_radm_doutb_cpl       (formqram_radm_doutb_vc0_cpl       ),     

    // Next stage ordering and filter signals
    .rxq_tlp                       (rxq_tlp                           ),
    .outqmgr_form_halt             (outqmgr_form_halt                 ),
    
    // Credit release signals to RTLH
    .radm_rtlh_h_ca_p              (radm_rtlh_ph_ca[0]                ),              
    .radm_rtlh_d_ca_p              (radm_rtlh_pd_ca[0]                ),   
    .radm_rtlh_h_ca_np             (radm_rtlh_nph_ca[0]               ),              
    .radm_rtlh_d_ca_np             (radm_rtlh_npd_ca[0]               ), 
    .radm_rtlh_h_ca_cpl            (radm_rtlh_cplh_ca[0]              ),              
    .radm_rtlh_d_ca_cpl            (radm_rtlh_cpld_ca[0]              ),   
    .radm_formq_overflow_p         (radm_formq_overflow[0][0]         ),
    .radm_formq_overflow_np        (radm_formq_overflow[0][1]         ),
    .radm_formq_overflow_cpl       (radm_formq_overflow[0][2]         ),
    .ras_dp_err_log                (ras_dp_err_log_formq     ),
    .out_ras_dp_wake_up            (out_ras_dp_wake_up[14:5]),
    .ras_dp_err_inj                (ras_dp_err_inj_formq              ),
    .flit_mode_en                  (radm_qstatic_in_d.flit_mode_en[0] ),
    .radm_clk_ug                   (radm_clk_ug                       ),
    .core_clk                      (core_clk                          ),                         
    .core_rst_n                    (core_rst_n                        )  
  );

  assign radm_formq_not_empty[0][E_P]   =  rxq_tlp[E_P]  [P0].q_not_empty;
  assign radm_formq_not_empty[0][E_NP ] =  rxq_tlp[E_NP] [P0].q_not_empty;
  assign radm_formq_not_empty[0][E_CPL] =  rxq_tlp[E_CPL][P0].q_not_empty;

  logic [N_TRGT1_INTF-1:0]                                        trgt0_radm_halt_int_p;
  logic [N_TRGT1_INTF-1:0]                                        trgt0_radm_halt_int_np;
  logic [NO_OF_TRGT0_INTF-1:0][INT_HDW-1:0]                       dmux_trgt0_req;   
  logic [N_TRGT1_INTF-1:0]                                        dmux_trgt0_p_fifo_pipe_empty;   

  logic                                                           cpl_0_tlp_cpl; 
  logic [2:0]                                                     cpl_0_status_cpl;
  logic                                                           cpl_0_flt_dwlenEq0_cpl;
  logic                                                           cpl_0_rtlh_radm_ecrc_err_cpl ;
  logic                                                           cpl_0_rtlh_radm_malform_tlp_err_cpl ;

  trgt_grnt_top_s                                                 trgt_grnt_trgt1_top; 

  // Ordering module instance
  radm_outq_mgr_ms
        u_radm_outq_mgr_ms
  (
    .core_clk                      (core_clk                     ),
    .core_rst_n                    (core_rst_n                   ),
    .radm_idle                     (radm_idle                    ),

    .rxq_tlp                       (rxq_tlp                      ),


    .outqmgr_form_halt             (outqmgr_form_halt            ),

    .pktadj_crdmgr_crd_restore_p   (pktadj_crdmgr_crd_restore_p  ), 
    .pktadj_crdmgr_crd_restore_np  (pktadj_crdmgr_crd_restore_np ), 
    .pktadj_crdmgr_crd_restore_cpl (pktadj_crdmgr_crd_restore_cpl), 

    .trgt_grnt_trgt1_top           (trgt_grnt_trgt1_top          ), 

    .outqmgr_filt_formq_not_empty  (outqmgr_filt_formq_not_empty ),   

    ///////// Signals going to the next stage VC arbiter/filters
    .outq_tlp                      (outq_tlp                     )
  );



  // Adding pipeline to break the combo path from ATU translated Address to CDM error log
  radm_cfg_ntlp_ntrgt_o_s                     radm_cfg_ntlp_ntrgt_o_int;

  delay_n
   
    #( .N (1), .WD ($bits(radm_cfg_ntlp_ntrgt_o_s)) )
    u_radm_cfg_o_pipe (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .din    (radm_cfg_ntlp_ntrgt_o_int),
    .dout   (radm_cfg_ntlp_ntrgt_o)
  );
  
  // Instance TOP module for decoder/filters/demux/trgt1 control logic 
  // Below module willgenerate TRGT1 signals as per number TRGT1 interfaces
  radm_filter_dmux_trgt1_top
  
 #( 
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_FILTER)
  )  
  u_radm_filter_dmux_trgt1_top
  (
    .core_clk                                     (core_clk                                                ),       
    .radm_clk_ug                                  (radm_clk_ug                                             ),  
    .core_rst_n                                   (core_rst_n                                              ),  
    .non_sticky_rst_n                             (non_sticky_rst_n                                        ),
    .radm_cfg_i                                   (radm_cfg_i_int                                          ),
    .radm_cfg_ntlp_ntrgt_i                        (radm_cfg_ntlp_ntrgt_i                                   ),
    .radm_cfg_ntlp_ntrgt_o                        (radm_cfg_ntlp_ntrgt_o_int                               ),
    .flt_cdm_addr_o                               (flt_cdm_addr_o                                          ),
    .flt_cdm_addr_valid_o                         (flt_cdm_addr_valid_o                                    ),
    .trgt_grnt_trgt1_top                          (trgt_grnt_trgt1_top                                     ), 

    .cpl_0_tlp_cpl                                (cpl_0_tlp_cpl),
    .cpl_0_status_cpl                             (cpl_0_status_cpl),
    .cpl_0_flt_dwlenEq0_cpl                       (cpl_0_flt_dwlenEq0_cpl),
    .cpl_0_rtlh_radm_ecrc_err_cpl                 (cpl_0_rtlh_radm_ecrc_err_cpl),  
    .cpl_0_rtlh_radm_malform_tlp_err_cpl          (cpl_0_rtlh_radm_malform_tlp_err_cpl),
    .radm_cfg_atu_in                              (radm_cfg_atu_in                                         ),
    // Posted                                    
    .flit_mode                                    (radm_qstatic_in_d.flit_mode_en[1]                       ),  
    .app_req_retry_en                             (app_req_retry_en                                        ),  
    .app_pf_req_retry_en                          (app_pf_req_retry_en                                     ),  
      .rcrb_base_addr                                     (rcrb_base_addr                               ),
      .rcrb_base_addr_valid                               (rcrb_base_addr_valid                         ),

    .rx_tlp                                       (rx_tlp                                                  ),

    // cpl                                        
    .trgt1_radm_intf_halt_cpl                     (trgt1_radm_intf_halt_cpl                                ),  
    // posted                                      
    .trgt0_radm_halt_int_p                        (trgt0_radm_halt_int_p                                   ),  
    .trgt1_radm_intf_halt_p                     (trgt1_radm_intf_halt_p                                  ),  
    // non posted                                 

    // Filter I/O                                  
    .trgt0_radm_halt_int_np                       (trgt0_radm_halt_int_np                                  ),  
    .trgt1_radm_intf_halt_np                    (trgt1_radm_intf_halt_np                                 ),  
    /// For completion                             
    // Filter I/O                                  
    //  `ifdef CX_CCIX_INTERFACE_ENABLE                 
    //  .hdr_dec_flt_hdr_ccix_tlp_cpl             (hdr_dec_flt_hdr_ccix_tlp_cpl                            ),  
    //  `endif // CX_CCIX_INTERFACE_ENABLE             
    //`ifdef CX_RASDP_EN                              
    //.ras_radm_prot_disable_cpl                  (ras_radm_prot_disable_cpl                               ),  
    //`endif // CX_RASDP_EN                          

    .cpl_mlf_err_cpl                              (lut_filt_cpl_mlf_err_cpl                                         ),  
    .lut_filt_cpl_abort                           (lut_filt_cpl_abort                                      ),  
    .flt_q_cpl_last_cpl                           (lut_filt_cpl_last_cpl                                      ),  
    .cpl_ur_err_cpl                               (lut_filt_cpl_ur_err_cpl                                          ),  
    .cpl_ca_err_cpl                               (lut_filt_cpl_ca_err_cpl                                          ),  
    .unexpected_cpl_err_cpl                       (lut_filt_unexpected_cpl_err_cpl                                  ),  
    .lut_flt_np_req_type                          (lut_flt_np_req_type                                              ),
    .flt_xadm_np_req_type_o                       (flt_xadm_np_req_type_o                                           ),
    //    
      //  `ifdef CX_CCIX_INTERFACE_ENABLE                 
      //  .ccix_p_0_tlp                           (ccix_p_0_tlp                                            ),  
      //  `endif // CX_CCIX_INTERFACE_ENABLE             
    .dmux_trgt0_req                             (dmux_trgt0_req                                          ),
    .dmux_trgt0_p_fifo_pipe_empty                    (dmux_trgt0_p_fifo_pipe_empty                                 ), 
     // .radm_hdr_np_0_log                           (radm_hdr_np_0_log                                      ), 
      //  `ifdef CX_CCIX_INTERFACE_ENABLE                 
      //  .ccix_np_0_tlp                           (ccix_np_0_tlp                                          ),  
      //  `endif // CX_CCIX_INTERFACE_ENABLE             
      // For completion                              
    .flt_cpl_lut                                 (flt_cpl_lut                               ),  
    .port_trgt_clkg_ctrl                         (port_trgt_clkg_ctrl                                     ), 
    .radm_trgt1_out_p                            (radm_trgt1_out_p                                ),
    .radm_trgt1_out_np                           (radm_trgt1_out_np                                ),  
    .radm_trgt1_out_cpl                          (radm_trgt1_out_cpl                                ), 
    .pktadj_crdmgr_crd_restore_p                 (pktadj_crdmgr_crd_restore_p                           ),
    .pktadj_crdmgr_crd_restore_np                (pktadj_crdmgr_crd_restore_np                          ),
    .pktadj_crdmgr_crd_restore_cpl               (pktadj_crdmgr_crd_restore_cpl                         )
      ,
      .flt_q_log_p_o                                (p_radm_hdr_log_i                                      ),
      .flt_q_log_np_o                               (np_radm_hdr_log_i                                     ),
      .flt_q_log_cpl_o                              (cpl_radm_hdr_log_i                                    ),
      .log_halt                                     (log_halt                                              )
      ,
      .ecrc_err_inj_enable                          (ecrc_err_inj_enable),
      .ecrc_pkt_eot_with_vld_td                     (ecrc_pkt_eot_with_vld_td)
    ,
    .ras_dp_err_log                                 (ras_dp_err_log_filter            )
    ,
    .ras_dp_err_inj                                 (ras_dp_err_inj_filter            )
`ifndef SYNTHESIS
    ,
    .flt_pkt_num_p_valid                            (radm_flt_pkt_num_p_valid),
    .flt_pkt_num_p                                  (radm_flt_pkt_num_p),
    .flt_pkt_num_np_valid                           (radm_flt_pkt_num_np_valid),
    .flt_pkt_num_np                                 (radm_flt_pkt_num_np),
    .flt_pkt_num_cpl_valid                          (radm_flt_pkt_num_cpl_valid),
    .flt_pkt_num_cpl                                (radm_flt_pkt_num_cpl)
`endif
  );



assign rx_tlp = outq_tlp;




// TRGT0 module instance
radm_trgt0_ctrl

 #(
    .RAS_DP_PROT_CHK_ID_BASE  (RAS_DP_PROT_CHK_ID_BASE_TRGT0)
 )
u_radm_trgt0_ctrl
(
  .core_clk                     (core_clk                         ),   
  .core_rst_n                   (core_rst_n                       ),      
  .flit_mode                    (radm_qstatic_in_d.flit_mode_en[1]),      
  .device_type                  (device_type_d                    ),
  .pm_l1_aspm_entr              (pm_l1_aspm_entr                  ),
  .dmux_trgt0_req               (dmux_trgt0_req                   ),     
  .dmux_trgt0_p_fifo_pipe_empty (dmux_trgt0_p_fifo_pipe_empty     ), 
  .trgt0_radm_halt              (trgt0_radm_halt                  ),     
  .radm_trgt0_data              (radm_trgt0_data                  ),     
  .radm_trgt0_abort             (radm_trgt0_abort                 ),     
  .radm_trgt0_dv                (radm_trgt0_dv                    ),     
  .radm_trgt0_dwen              (radm_trgt0_dwen                  ),     
  .radm_trgt0_ecrc_err          (radm_trgt0_ecrc_err              ),     
  .radm_trgt0_eot               (radm_trgt0_eot                   ),     
  .radm_trgt0_hdr               (radm_trgt0_hdr                   ),     
  .radm_trgt0_hv                (radm_trgt0_hv                    ),     
  .radm_trgt0_np_rsvd           (radm_trgt0_np_rsvd               ),     
  .trgt0_radm_halt_int_p        (trgt0_radm_halt_int_p            ),     
  .trgt0_radm_halt_int_np       (trgt0_radm_halt_int_np           ),     
  // Clock Gating Control Info
  .radm_trgt0_p                 (radm_trgt0_p                     ),
  .radm_trgt0_np                (radm_trgt0_np                    )
  ,.ras_dp_err_log              (ras_dp_err_log_trgt0             )
  ,.ras_dp_err_inj              (ras_dp_err_inj_trgt0             )
);
 
  // TO DO : NIlesh/Sanjay to add Daignostic info for RADM
  assign radm_qoverflow_ms               = |radm_formq_overflow;
  assign radm_q_not_empty_ms             = |radm_formq_not_empty;
  assign radm_formq_read_err_ms          = 'd0;
  assign radm_formq_overflow_ms          = |radm_formq_overflow;
  assign radm_formq_not_empty_ms         = |radm_formq_not_empty;


//assign   cpl_tlp = {N_RADM_CPL_TLP{1'b1}};
assign   filt_lut_cpl_status                = cpl_0_status_cpl;
assign   rtlh_radm_malform_tlp_err = cpl_0_rtlh_radm_malform_tlp_err_cpl;
assign   rtlh_radm_ecrc_err        = cpl_0_rtlh_radm_ecrc_err_cpl;  

assign filt_lut_dwlenEq0 = cpl_0_flt_dwlenEq0_cpl;

logic flush;
assign flush = rstctl_core_flush_req || rasdp_error_mode;

radm_cpl_lut_ms
  u_radm_cpl_lut_ms
(

  .core_clk                             (core_clk                     ),
  .radm_clk_ug                          (radm_clk_ug                  ),                
  .core_rst_n                           (core_rst_n                   ),
  .rstctl_core_flush_req                (flush                        ),
  .cfg_filter_rule_mask                 (radm_qstatic_in_d.cfg_filter_rule_mask),       
  .cfg_pbus_dev_num                     (radm_qstatic_in_d.cfg_pbus_dev_num),           
  .cfg_pbus_num                         (radm_qstatic_in_d.cfg_pbus_num),               
  .cfg_p2p_track_cpl_to                 (cfg_p2p_track_cpl_to         ),       
  .cfg_p2p_err_rpt_ctrl                 (cfg_p2p_err_rpt_ctrl         ),       
  .tag_bits_13_to_10                    (flt_cpl_lut.flt_cpl_lut_uppr_4bit_tag),             
  .device_type                          (radm_qstatic_in_d.device_type),                  
    .cdm_dpc_triggered                  (cdm_dpc_triggered            ),          
    .cdm_core_in_dpc                    (cdm_core_in_dpc              ),   
    .cfg_dpc_cpl_cntrl                  (cfg_dpc_cpl_cntrl            ),  // DPC CPL control bit from CDM. To redirect poison err to UR/CA     

  //////////////// completion packet signals ///////////////////
  .cpl_tlp_ant_tag                   (flt_cpl_lut.flt_cpl_lut_tag    ),         
  .filt_lut_cpl_status                           (filt_lut_cpl_status                   ),
  .filt_lut_dwlenEq0                             (filt_lut_dwlenEq0                 ),  
  .filt_lut_hv                         (flt_cpl_lut.flt_cpl_lut_hv             ),               
  .filt_lut_hdr                        ({{((HW + RADM_HDR_PROT_WD) -128){1'b0}},flt_cpl_lut.flt_cpl_lut_hdr}  ),              
  .filt_lut_eot                        (flt_cpl_lut.flt_cpl_lut_eot ),              
  .filt_lut_dllp_err                   (flt_cpl_lut.flt_cpl_lut_dllp_err       ),   
  .filt_lut_malform_tlp_err            (rtlh_radm_malform_tlp_err    ),   
  .filt_lut_ecrc_err                   (rtlh_radm_ecrc_err           ),          
  .filt_lut_ant_formation              ('0      ),
  .filt_lut_ant_hv                     ('0      ),
  .filt_lut_formation                  ('0      ),        
  ///////////////////// transmitted NP TLP inputs /////////////////////
  .xadm_radm_tx_npr                     (xadm_radm_tx_npr             ),


  
  ///////////////// CPL TLP Status signals /////////////////////////
  .lut_filt_vendor_msg_id_match                  (          ), // No need to pass this signal from CPL_LUT to posted filter. In MS Arch related logic has added in filter itself instead of taking from CPL_LUT. 
  .lut_filt_cpl_abort                            (lut_filt_cpl_abort                    ),
  .lut_filt_cpl_last                             (lut_filt_cpl_last_cpl                 ),
  .lut_filt_cpl_mlf_err                          (lut_filt_cpl_mlf_err_cpl              ),
  .lut_filt_cpl_ur_err                           (lut_filt_cpl_ur_err_cpl               ),
  .lut_filt_cpl_ca_err                           (lut_filt_cpl_ca_err_cpl               ),
  .lut_filt_unexpected_cpl_err                   (lut_filt_unexpected_cpl_err_cpl       ),
  .np_req_type                                   (lut_flt_np_req_type                   ),
  .cpl_trgt_interface_no                         (cpl_trgt_interface_no                 ), 
  //////////////////////// timer block signals//////////////////////
    .cfg_cpl_timeout_range              (radm_qstatic_in_d.cfg_cpl_timeout_range        ),      
  .cfg_cpl_timeout_disable              (radm_qstatic_in_d.cfg_cpl_timeout_disable      ),   
  .xtlh_np_tlp_early                    ( xtlh_np_tlp_early           ),          
  .current_data_rate                    (radm_qstatic_in_d.current_data_rate),          
  .radm_cpl_pending                     (radm_cpl_pending             ),         
  .radm_cpl_lut_busy                    (radm_cpl_lut_busy            ),          
  .radm_cpl_timeout                     (radm_cpl_timeout             ),
  .radm_cpl_timeout_cdm                 (radm_cpl_timeout_cdm         ),       
  .radm_timeout_cpl_tc                  (radm_timeout_cpl_tc          ),        
  .radm_timeout_cpl_attr                (radm_timeout_cpl_attr        ),      
  .radm_timeout_cpl_tag                 (radm_timeout_cpl_tag         ),
  .radm_timeout_func_num                (radm_timeout_func_num        ),
  .radm_timeout_cpl_len                 (radm_timeout_cpl_len         ),
  .radm_timeout_low_addr                (radm_timeout_low_addr        ),
  .radm_timeout_np_req_type             (radm_timeout_np_req_type     ),    
  .radm_cpl_lut_valid                   (radm_cpl_lut_valid           ),
  .radm_cpl_lut_pending                 (radm_cpl_lut_pending         )
        
); // u_radm_cpl_lut_ms




// RADM Clock Control Instance
radm_clk_control_ms
 u_radm_clk_control (
    .radm_clk_ug                      (radm_clk_ug                     ),
    .core_rst_n                       (core_rst_n                      ),
    .clock_gating_en                  (cfg_radm_clk_control            ),
    .rtlh_radm_pending                (rtlh_radm.pending               ),
    .form_filt_hv_p                   (rxq_tlp[E_P][P0].tlp.hdr.hv     ),
    .filt_form_halt_in_p              (outqmgr_form_halt[E_P]          ),
    .form_filt_hv_np                  (rxq_tlp[E_NP][P0].tlp.hdr.hv    ),
    .filt_form_halt_in_np             (outqmgr_form_halt[E_NP]         ),
    .form_filt_hv_cpl                 (rxq_tlp[E_CPL][P0].tlp.hdr.hv   ),
    .filt_form_halt_in_cpl            (outqmgr_form_halt[E_CPL]        ),
    .radm_formq_not_empty             (radm_formq_not_empty            ),
    // TRGT Interface Signals
    .radm_trgt1_intf_eot_p            (radm_trgt1_out_p[0].flt_q_eot   ),
    .trgt1_radm_intf_halt_p           (trgt1_radm_intf_halt_p          ),
    .radm_trgt1_intf_eot_np           (radm_trgt1_out_np[0].flt_q_eot  ),
    .trgt1_radm_intf_halt_np          (trgt1_radm_intf_halt_np         ),
    .radm_trgt1_intf_eot_cpl          (radm_trgt1_out_cpl[0].flt_q_eot ),
    .trgt1_radm_intf_halt_cpl         (trgt1_radm_intf_halt_cpl        ),
    .radm_trgt0_p                     (radm_trgt0_p                    ),
    .radm_trgt0_np                    (radm_trgt0_np                   ),
    .radm_trgt1_p_pending             (radm_trgt1_p_pending            ),
    // Demux Clock Gating Control Signals
    .port_trgt_clkg_ctrl              (port_trgt_clkg_ctrl     ), 
    .radm_trgt0_halt                  (trgt0_radm_halt         ),     
    .radm_cpl_lut_pending             (radm_cpl_lut_pending    ),   
    .radm_cpl_lut_valid               (radm_cpl_lut_valid      ),     
    .radm_cpl_lut_busy                (radm_cpl_lut_busy       ),      
    .radm_rtlh_crd_pending            (1'b0),     // Do we need it????  
    .hdr_log_idle                     (hdr_log_idle            ),
    .radm_idle                        (radm_idle               ),
    .radm_clk_en                      (radm_clk_en_int         )
  );

  assign radm_clk_en = radm_clk_en_int
                       | (|out_ras_dp_wake_up)
                       | ras_dp_err_inj_wake_up
                       ;

// Pipelining Static/Quasi-static signals to reduce Fan-out
assign radm_qstatic_in.flit_mode_en             = {$bits(radm_qstatic_in.flit_mode_en){flit_mode_en}};
assign radm_qstatic_in.current_data_rate        = current_data_rate;
assign radm_qstatic_in.device_type              = device_type;
assign radm_qstatic_in.cfg_ecrc_chk_en          = radm_cfg_i.cfg_ecrc_chk_en;
assign radm_qstatic_in.cfg_upstream_port        = radm_cfg_i.cfg_upstream_port;
assign radm_qstatic_in.cfg_root_compx           = radm_cfg_i.cfg_root_compx;
assign radm_qstatic_in.cfg_endpoint             = radm_cfg_i.cfg_endpoint;
assign radm_qstatic_in.cfg_filter_rule_mask     = radm_cfg_i.cfg_filter_rule_mask;
assign radm_qstatic_in.cfg_pbus_dev_num         = radm_cfg_i.cfg_pbus_dev_num;
assign radm_qstatic_in.cfg_pbus_num             = radm_cfg_i.cfg_pbus_num;
assign radm_qstatic_in.cfg_tc_enable            = radm_cfg_i.cfg_tc_enable;
assign radm_qstatic_in.cfg_max_func_num         = radm_cfg_i.cfg_max_func_num;
assign radm_qstatic_in.cfg_max_payload          = radm_cfg_i.cfg_max_payload;
assign radm_qstatic_in.cfg_tc_struc_vc_map      = radm_cfg_i.cfg_tc_struc_vc_map;
assign radm_qstatic_in.cfg_cpl_timeout_range    = cfg_cpl_timeout_range;
assign radm_qstatic_in.cfg_cpl_timeout_disable  = cfg_cpl_timeout_disable;

// Filter Input structure update based on QS pipeline
always_comb begin
  radm_cfg_i_int                                    = radm_cfg_i;
  radm_cfg_i_int.cfg_ecrc_chk_en                    = radm_qstatic_in_d.cfg_ecrc_chk_en; 
  radm_cfg_i_int.cfg_tc_struc_vc_map                = radm_qstatic_in_d.cfg_tc_struc_vc_map; 
  radm_cfg_i_int.cfg_tc_enable                      = radm_qstatic_in_d.cfg_tc_enable; 
  radm_cfg_i_int.cfg_filter_rule_mask               = radm_qstatic_in_d.cfg_filter_rule_mask; 
  radm_cfg_i_int.cfg_max_func_num                   = radm_qstatic_in_d.cfg_max_func_num;
  radm_cfg_i_int.cfg_max_payload                    = radm_qstatic_in_d.cfg_max_payload; 
  radm_cfg_i_int.cfg_upstream_port                  = radm_qstatic_in_d.cfg_upstream_port;  
  radm_cfg_i_int.cfg_root_compx                     = radm_qstatic_in_d.cfg_root_compx;  
  radm_cfg_i_int.cfg_endpoint                       = radm_qstatic_in_d.cfg_endpoint;     
  radm_cfg_i_int.cfg_pbus_num                       = radm_qstatic_in_d.cfg_pbus_num; 
  radm_cfg_i_int.cfg_pbus_dev_num                   = radm_qstatic_in_d.cfg_pbus_dev_num; 
  radm_cfg_i_int.device_type                        = radm_qstatic_in_d.device_type;
end

delay_n
 
  #( .N (1), .WD ($bits(radm_qstatic_s)) )
  u_radm_qs_pipeline (
  .clk    (radm_clk_ug),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .din    (radm_qstatic_in),
  .dout   (radm_qstatic_in_d)
);

delay_n
 
  #( .N (1), .WD ($bits(device_type)) )
  u_radm_qs_device_type_pipe (
  .clk    (radm_clk_ug),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .din    (device_type),
  .dout   (device_type_d)
);

// Instantiation of radm_hdr_log


radm_hdr_log_ser

    u_hdr_log (
      .core_clk                      ( core_clk                             ),
      .core_rst_n                    ( core_rst_n                           ),
      .flit_mode                     ( radm_qstatic_in_d.flit_mode_en[1]    ),  // Registered flit_mode_en
      .cfg_max_end2end_tlp_prfxs     ( radm_cfg_i_int.cfg_max_end2end_tlp_prfxs ),
      .p_radm_hdr_log_i              ( p_radm_hdr_log_i                     ),
      .np_radm_hdr_log_i             ( np_radm_hdr_log_i                    ),
      .cpl_radm_hdr_log_i            ( cpl_radm_hdr_log_i                   ),
      //------ outputs ------//
      .radm_hdr_log                  ( radm_hdr_log                         ),
      .hdr_log_idle                  ( hdr_log_idle                         ),
      .halt_out                      ( log_halt                             )
    );

      radm_ecrc_einj_ctrl
       u_radm_ecrc_einj_ctrl
      (
        .core_clk                   (core_clk                  ),              
        .core_rst_n                 (core_rst_n                ),            
        .pkt_err_inj_enable_in      (ecrc_pkt_eot_with_vld_td  ),
        .cdm_ras_des_einj0_enable   (cdm_ras_des_einj0_enable  ),
        .cdm_ras_des_einj0_crc_type (cdm_ras_des_einj0_crc_type),
        .cdm_ras_des_einj0_count    (cdm_ras_des_einj0_count   ),
        .cdm_ras_des_einj0_vc_sel   (cdm_ras_des_einj0_vc_sel  ),
        .cdm_ras_des_einj0_fc_sel   (cdm_ras_des_einj0_fc_sel  ),
        .cdm_ras_des_einj0_intf_sel (cdm_ras_des_einj0_intf_sel),
        .err_inj_enable             (ecrc_err_inj_enable       ),
        .ecrc_einj_evt              (radm_einj0_ecrc_evt       )
      );


// RADM TRGT1 P/NP/CPL Debug Signals.
// Debug signals assigned per set of P/NP/CPL TRGT1 interfaces.
localparam MAX_PF_WD = $clog2(`CX_ABSOLUTE_MAX_NFUNC);

assign radm_ras_des_err_info_0.radm_cpl_uc    = radm_cfg_ntlp_ntrgt_o.radm_unexp_cpl_err;
assign radm_ras_des_err_info_0.radm_cpl_pois  = radm_cfg_ntlp_ntrgt_o.radm_rcvd_cpl_poisoned;
assign radm_ras_des_err_info_0.radm_cpl_ca    = radm_cfg_ntlp_ntrgt_o.radm_rcvd_cpl_ca;
assign radm_ras_des_err_info_0.radm_cpl_ur    = radm_cfg_ntlp_ntrgt_o.radm_rcvd_cpl_ur;
assign radm_ras_des_err_info_0.radm_wreq_pois =
{|radm_cfg_ntlp_ntrgt_o.radm_rcvd_wreq_poisoned[3*NF-1:2*NF],|radm_cfg_ntlp_ntrgt_o.radm_rcvd_wreq_poisoned[2*NF-1:NF],|radm_cfg_ntlp_ntrgt_o.radm_rcvd_wreq_poisoned[NF-1:0]};
assign radm_ras_des_err_info_0.radm_mlf_err   = radm_cfg_ntlp_ntrgt_o.radm_mlf_tlp_err;
assign radm_ras_des_err_info_0.radm_ecrc_err  = radm_cfg_ntlp_ntrgt_o.radm_ecrc_err;
  
always_comb begin
  for (int i = 0; i < 3; i = i + 1) begin
    // Extract P/NP/CPL physical function numbers.
    radm_ras_des_err_info_0.radm_pf[i*MAX_PF_WD +: MAX_PF_WD] = {{{(MAX_PF_WD-PF_WD){1'b0}},radm_cfg_ntlp_ntrgt_o.flt_cdm_pf[i*PF_WD +: PF_WD]}};
    // OR vector of per function request UR bits
    radm_ras_des_err_info_0.radm_req_ur[i]                    =  (|radm_cfg_ntlp_ntrgt_o.radm_rcvd_req_ur[i*NF +: NF]);
  end
end  

assign radm_ras_des_err_info_0.radm_req_ca = radm_cfg_ntlp_ntrgt_o.radm_rcvd_req_ca;


`ifndef SYNTHESIS
//VCS coverage off
//VCS coverage on
`endif // SYNTHESIS

endmodule
