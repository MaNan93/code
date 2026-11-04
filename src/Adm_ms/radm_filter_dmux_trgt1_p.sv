//
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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_filter_dmux_trgt1_p.sv#7 $
// -------------------------------------------------------------------------
//Description: 
//This moduls is TOP module of posted TLP type. This module is instantiation of  - 
//    - Posted TLP header decoding module 
//    - Posted filter module 
//    - Posted demux control module to route the posted TLP to TRGT1 or TRGT0 or to TRASH the TLP
//    - Posted TRGT1 control module. TRGT1 interface is per FC type
//    - Gets input from CDM configuration registers
//    - Sends/Receive address, status and any other configuration updates into/from registers
//    Hierarchy - 
//      radm_filter_dmux_trgt1_p 
//         |
//          radm_hdr_dec_p
//          radm_filter_p
//          radm_demux_ctrl
//          radm_trgt1_ctrl
//
//--------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/pcie_pkg.svh"

module radm_filter_dmux_trgt1_p

  import pcie_pkg::E_P;
  /////////////////////////////////////////
  //import radm_ms_pkg starts
  import radm_ms_pkg::ATU_IN_MIN1;
  import radm_ms_pkg::PKT_ORD_WD;
  import radm_ms_pkg::FILTER_CHK_CNTS;
  import radm_ms_pkg::HDR_DEC_CHK_CNTS;
  import radm_ms_pkg::ATU_CHK_CNTS;
  import radm_ms_pkg::TRGT1_CHK_CNTS;
  import radm_ms_pkg::FILTER_DEMUX_TRGT1_P_CHK_CNTS;
  import radm_ms_pkg::TRGT_DATA_WD;
  import radm_ms_pkg::TRGT_DATA_PROT_WD;
  import radm_ms_pkg::TRGT1_HDR_WD;

  import radm_ms_pkg::D_P_FIFO_DEPTH;
  import radm_ms_pkg::D_P_ADDR_WIDTH;
  import radm_ms_pkg::INT_DWIDTH;
  import radm_ms_pkg::INT_HWIDTH;
  import radm_ms_pkg::INT_HDW;
  import radm_ms_pkg::radm_cfg_atu_s;
  import radm_ms_pkg::radm_flt_atu_s;
  import radm_ms_pkg::ATU_IPIPE_PROT_WD;
  import radm_ms_pkg::radm_cfg_i_s;
  import radm_ms_pkg::radm_cfg_tlp_i_s;
  import radm_ms_pkg::radm_cfg_tlp_o_s;
  import radm_ms_pkg::trgt_fifo_rd_grnt_s;
  import radm_ms_pkg::radm_ord_mgr_flt_data_s;
  import radm_ms_pkg::radm_hdr_dec_flt_s;
  import radm_ms_pkg::flt_q_dmux_o_s;
  import radm_ms_pkg::FLT_P_HDR_WIDTH ;
  import radm_ms_pkg::FLT_P_HDR_PROT_WIDTH;
  import radm_ms_pkg::radm_crd_restore_s;
  import radm_ms_pkg::flt_data_o_s;
  import radm_ms_pkg::flt_p_hdr_o_s;
  import radm_ms_pkg::trgt1_p_out_s;
  import radm_ms_pkg::dmux_clkg_ctrl_s;
  import radm_ms_pkg::TRGT1_P_OUT_WD;
  import radm_ms_pkg::TRGT1_P_HDR_WD;
  import radm_ms_pkg::TRGT1_P_RHDR_WD;
  import radm_ms_pkg::radm_rx_tlp_s;
  import radm_ms_pkg::rtrgt1_tlp_out_s;
  import radm_ms_pkg::pktstr_hlog_s;
  //import radm_ms_pkg ends`ifndef SYNTHESIS
`ifndef SYNTHESIS
`endif
  //import DWC_pcie_ctl_pkg starts
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NVF;
  import DWC_pcie_ctl_pkg::RAS_PROT_RANGE;
  import DWC_pcie_ctl_pkg::RAS_PROT_TYPE;
  import DWC_pcie_ctl_pkg::RAS_PARITY_MODE;
   import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
   //import DWC_pcie_ctl_pkg ends

//-----------------------------------------------------------------------------
// Parameter/Localparam declaration
//-----------------------------------------------------------------------------
#(
    parameter RAS_DP_PROT_CHK_ID_BASE  = 0
)
//-----------------------------------------------------------------------------
// I/O Declaration
//-----------------------------------------------------------------------------

                                 (
    // I/O hdc_dec
    input                                                 core_clk,
    input                                                 radm_clk_ug,
    input                                                 core_rst_n,
    input                                                 non_sticky_rst_n,
    // Config
    input   radm_cfg_i_s                                  radm_cfg_i,
    input   radm_cfg_tlp_i_s                              radm_cfg_tlp_i,
    output  radm_cfg_tlp_o_s                              radm_cfg_o,
    // end config

`ifndef SYNTHESIS
    // Outputs to testbench
    output logic                                          flt_pkt_num_p_valid,
    output logic [PKT_ORD_WD-1:0]                         flt_pkt_num_p,
`endif

    input radm_rx_tlp_s                                   rx_tlp,          // Received TLP struct, from OutQ/IDE, to filter

    input                                                 flit_mode, 
    // Filter I/O 
    input                                                 app_req_retry_en,

    input [NF-1:0]                                        app_pf_req_retry_en,
    // TO DO : SK
    //prfxHdr_flt_hdr_p,
    //  `ifdef CX_CCIX_INTERFACE_ENABLE
    //    ,
    //    input [CCIX_WD-1:0]                             hdr_dec_flt_hdr_p_ccix_tlp
    //  `endif // CX_CCIX_INTERFACE_ENABLE
    input                                                 rtlh_radm_parerr,
    // ATU
    input radm_cfg_atu_s                                  radm_cfg_atu_in,
    // ATU end

    input                                                 trgt0_radm_halt_int,
    output logic [INT_HDW -1:0]                           dmux_trgt0_req ,
    output logic                                          dmux_trgt0_fifo_pipe_empty,  
    output flt_q_dmux_o_s                                 flt_q_log_p_o,
    input  logic                                          log_halt_p,
    //----------------------------------------------//
    input                                                 trgt1_radm_intf_halt,
    // ---- outputs ---------------
    output trgt1_p_out_s                                  radm_trgt1_out_p, 
    output logic [64-1:0]                                 flt_cdm_addr_p,
    output logic                                          flt_cdm_addr_valid_p,
    input                                                 ecrc_err_inj_enable,
    output                                                ecrc_pkt_eot_with_vld_td,
    output trgt_fifo_rd_grnt_s                            trgt_fifo_hdr_data_grnt,
    output ras_dp_err_log_t [FILTER_DEMUX_TRGT1_P_CHK_CNTS-1:0]  ras_dp_err_log,
    input  ras_dp_err_inj_t                               ras_dp_err_inj,
    output radm_crd_restore_s                             pktadj_crdmgr_crd_restore,
    // Clock Gating Control Signals 
    output dmux_clkg_ctrl_s                               dmux_clkg_ctrl
);

//---------------------------------------------------------------------
    localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
    localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
    localparam PROT_WD         = `TRGT_DATA_PROT_WD;   
    localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
    localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;
    localparam HDR_DEC_CHK_NO  = 1;
    localparam FILTER_P_CHK_NO = HDR_DEC_CHK_NO + FILTER_CHK_CNTS;
    localparam ATU_CHK_NO      = FILTER_P_CHK_NO + ATU_CHK_CNTS;
    localparam TRGT1_CKH_NO    = ATU_CHK_NO + TRGT1_CHK_CNTS;
 // Following paramter to detect configured RADM_QMODE is in Cut-Thr/Bypass/Store-forward
    localparam RADM_QMODE_CT_BYP    = (`RADM_P_QMODE_VC0 != 1); 

    //------------------------------------- Signal declaration -------------------------------------
    // Structured declaration of IO's
    // Please refer radm_ms_pkg.svh to get more information on these structures

    radm_hdr_dec_flt_s                                              hdr_dec_flt; 
    radm_hdr_dec_flt_s                                              hdr_dec_flt_p; 
    // flt_q_dmux_o_s                                                  flt_q_dmux_o_p;
    flt_data_o_s                                                    flt_pktadj_data;
    flt_p_hdr_o_s                                                   flt_pktadj_hdr;
    flt_data_o_s                                                    pktadj_q_data;
    flt_p_hdr_o_s                                                   pktadj_q_hdr;

    radm_flt_atu_s                                                  radm_flt_atu_int;
    logic                                                           radm_flt_atu_hv;
    logic                                                           radm_atu_uppr_bytes_valid;
    logic                                                           radm_flt_atu_eot;
    logic [$clog2(ATU_IN_MIN1)-1:0]                                 radm_atu_sloc_region;
    logic                                                           radm_atu_sloc_match;
    logic                                                           radm_atu_cbuf_err;
   // End Structure calling
      
   // Internal wire/reg  Declaration (in SV wire/reg is considered as loic declaration) 
    logic [INT_HDW-1:0]                                             dmux_trgt1_req; 
    logic [INT_DWIDTH-1 :0]                                         radm_trgt1_data_dmux;
    logic [INT_HWIDTH-1:0]                                          radm_trgt1_hdr_dmux;
    logic [64-1:0]                                                  rtranslated_addr_in_d;
    logic [2-1:0]                                                   rtranslated_err_in_d;
    // eCRC related Ports
    logic                                                            tlp_ecrc_match_err;
    logic                                                            malform_ecrc_err;
    logic [2:0]                                                      hdr_dec_ecrc_pfrx_dw_count;    // Total Prefix Count
    logic [4-1:0]                                                    hdr_dec_ecrc_local_prfx_cnt;   // Local Prefix Count
    
    radm_ord_mgr_flt_data_s  ecrc_rmvd_flt_data;



///////////////////
// Checker for HDR
///////////////////






    radm_hdr_dec_p
     
        #(
      .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+HDR_DEC_CHK_NO-1)
        ) 
    u_radm_hdr_dec_p 
    (
      .core_clk                    (core_clk                  ),
      .radm_clk_ug                 (radm_clk_ug               ),
      .core_rst_n                  (core_rst_n                ),
      .flit_mode                   (flit_mode                 ),
      .rx_tlp                      (rx_tlp                    ),
      .hdr_dec_flt_p               (hdr_dec_flt             ), 
      .hdr_dec_ecrc_pfrx_dw_count  (hdr_dec_ecrc_pfrx_dw_count),
      .hdr_dec_ecrc_local_prfx_cnt (hdr_dec_ecrc_local_prfx_cnt),
      .hdr_dec_ecrc_dwen           ()
      ,
      .ras_dp_err_log                                         (ras_dp_err_log[HDR_DEC_CHK_NO-1:HDR_DEC_CHK_NO-HDR_DEC_CHK_CNTS]        )
      ,
      .ras_dp_err_inj                                         (ras_dp_err_inj                   )
    );
/////////////////////
// generator  for header and prefix
/////////////////////





    // ATU
    logic    [ATU_IPIPE_PROT_WD-1:0]    radm_flt_atu_hdr_prot;
      radm_atu_in_top
      
      #( 
      .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+FILTER_P_CHK_NO)
       ) 
       u_radm_atu_in_top
      (
        .core_clk                                         (core_clk                                     ),                          
        .radm_clk_ug                                      (radm_clk_ug                                  ),                          
        .non_sticky_rst_n                                 (non_sticky_rst_n                             ),
        .radm_flt_atu_hdr                                 (radm_flt_atu_int                             ),
        .radm_flt_atu_hv                                  (radm_flt_atu_hv                              ),
        .dmux_flt_halt_in                                 (1'b0                                         ),
        .radm_cfg_atu_in                                  (radm_cfg_atu_in                              )

          ,
          .radm_atu_translated_addr                       (rtranslated_addr_in_d                        ),
          .radm_atu_translated_err                        (rtranslated_err_in_d                         )
          , 
          .radm_atu_uppr_bytes_valid                     (radm_atu_uppr_bytes_valid            )
          ,
          .radm_atu_sloc_region                          (radm_atu_sloc_region                 ),
          .radm_atu_sloc_match                           (radm_atu_sloc_match                  ),
          .radm_atu_cbuf_err                             (radm_atu_cbuf_err                    ),
          .radm_flt_atu_eot                              (radm_flt_atu_eot                     )
          ,.radm_flt_atu_hdr_prot                        (radm_flt_atu_hdr_prot)
          ,.ras_dp_err_log                               (ras_dp_err_log[ATU_CHK_NO-1:ATU_CHK_NO-ATU_CHK_CNTS])
          ,.ras_dp_err_inj                               (ras_dp_err_inj)
      );
        //
   // `else // CX_ATU_CTRL_EN
   //   `ifdef CX_RASDP_EN
   //     assign ras_dp_err_log[4:3] = '0;
   //   `endif // CX_RASDP_EN


    radm_ord_mgr_flt_data_s                       ord_flt_data_p_in;
    radm_hdr_dec_flt_s                            hdr_dec_flt_p_in;
    logic  [15:0]                                 filt_ant_rid_p_in; 
    flt_q_dmux_o_s                                flt_q_dmux_fifo_out;
    logic                                         flt_q_dmux_fifo_pipe_empty;
    assign dmux_trgt0_fifo_pipe_empty = flt_q_dmux_fifo_pipe_empty;
    
  radm_anti_addr_ctrl
   u_radm_anti_addr_ctrl (

  // ---- inputs ---------------
  .core_clk                                  (core_clk),
  .radm_clk_ug                               (radm_clk_ug),
  .core_rst_n                                (core_rst_n),
  .flit_mode                                 (flit_mode),
  .hdr_dec_flt                               (hdr_dec_flt_p), 
  .ord_flt_data                              (ecrc_rmvd_flt_data),
  .rtlh_radm_parerr                          (rtlh_radm_parerr),
   .lut_flt_np_req_type                       ('0),
  .ord_flt_data_in                       (ord_flt_data_p_in),
  .hdr_dec_flt_in                        (hdr_dec_flt_p_in),
  .ant_extract_addr                      (flt_cdm_addr_p), 
  .ant_extract_addr_valid                (flt_cdm_addr_valid_p), 
  .rtlh_radm_parerr_int                  (rtlh_radm_parerr_int), 
  .flt_cpl_lut                           (),
  .filt_ant_rid                          (filt_ant_rid_p_in)
 );


    radm_filter_p
     
      #(
      .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+HDR_DEC_CHK_NO)
     ) 
     u_radm_filter_p
     (
      .core_clk                                           (core_clk                                     ),
      .radm_clk_ug                                        (radm_clk_ug                                  ),
      .core_rst_n                                         (core_rst_n                                   ),
      .flit_mode                                          (flit_mode                                    ),
      .radm_cfg_i                                         (radm_cfg_i                                   ),
      .radm_cfg_tlp_i                                     (radm_cfg_tlp_i                               ),
      .radm_cfg_o                                         (radm_cfg_o                                   ),
      .rtlh_radm_parerr_int                               (rtlh_radm_parerr_int                         ), 
      .radm_ecrc_err                                      (tlp_ecrc_match_err                           ), 
      .malform_ecrc_err                                   (malform_ecrc_err                             ), 
      .filt_ant_rid                                       (filt_ant_rid_p_in                            ), 

      .app_req_retry_en                                   (app_req_retry_en                             ),
      .app_pf_req_retry_en                                (app_pf_req_retry_en                          ),
      // timed with flt_q time domain.
      .ord_flt_data_p                                     (ord_flt_data_p_in                            ),
      //  `ifdef CX_CCIX_INTERFACE_ENABLE
      //    .hdr_dec_flt_p_ccix_tlp                       (hdr_dec_flt_hdr_p_ccix_tlp),
      //  `endif // CX_CCIX_INTERFACE_ENABLE
      .rtlh_radm_parerr                                   (rtlh_radm_parerr                             ),
        .rtranslated_addr_in_d                            (rtranslated_addr_in_d                        ),
        .rtranslated_err_in_d                             (rtranslated_err_in_d                         ),
     
      .radm_atu_uppr_bytes_valid                          (radm_atu_uppr_bytes_valid                    ),
      .radm_flt_atu_out                                   (radm_flt_atu_int                             ),
      .radm_flt_atu_hv                                    (radm_flt_atu_hv                              ),
      .radm_flt_atu_hdr_prot                              (radm_flt_atu_hdr_prot),
      .radm_flt_atu_eot                                   (radm_flt_atu_eot                             ),
      .radm_atu_sloc_region                               (radm_atu_sloc_region                         ),
      .radm_atu_sloc_match                                (radm_atu_sloc_match                          ),
      .radm_atu_cbuf_err                                  (radm_atu_cbuf_err                            ),

      // ---- outputs ---------------
      .flt_q_data_o_p                                     (flt_pktadj_data                              ),
      .flt_q_hdr_o_p                                      (flt_pktadj_hdr                               ),
      // .flt_q_dmux_o_p                                     (flt_q_dmux_o_p                               ),
      .hdr_dec_flt_p                                      (hdr_dec_flt_p_in                             ),
      .rx_tlp_hdr                                         (rx_tlp.tlp.hdr                               )
 
      ,
      .ras_dp_err_log                                         (ras_dp_err_log[FILTER_P_CHK_NO-1:FILTER_P_CHK_NO-FILTER_CHK_CNTS]        )
      ,
      .ras_dp_err_inj                                         (ras_dp_err_inj                   )

    );


radm_pkt_adj

#(.H_TYPE(flt_p_hdr_o_s))
u_radm_pkt_adj (
    .core_clk                   (core_clk),
    .core_rst_n                 (core_rst_n),
    .flt_pktadj_data            (flt_pktadj_data),
    .flt_pktadj_hdr             (flt_pktadj_hdr),
    .flit_mode                  (flit_mode),
    .pktadj_q_data              (pktadj_q_data),
    .pktadj_q_hdr               (pktadj_q_hdr),
    .pktadj_crdmgr_crd_restore  (pktadj_crdmgr_crd_restore)
);

logic trgt_halt;
logic stall_trgt1;
      
radm_trgt_pkt_store

  #(.H_FIFO_WIDTH   ($bits(flt_p_hdr_o_s)),
    .H_STR_P_TYPE   (1),
    .H_STR_NP_TYPE  (0),
    .CPL_BYPASS     (0),
    .ST_CT_CTRL     (`RADM_P_QMODE_VC0),
    .D_FIFO_DEPTH   (D_P_FIFO_DEPTH),
    .D_ADDR_WIDTH   (D_P_ADDR_WIDTH)
  )  
u_radm_trgt_pkt_store 
  (
    .core_clk                 (core_clk),           
    .core_rst_n               (core_rst_n), 
    .flt_q_data_in            (pktadj_q_data),
    .flt_q_hdr_in             (pktadj_q_hdr),
    .radm_trgt_fifo_out       (flt_q_dmux_fifo_out), 
    .radm_trgt_fifo_pipe_empty(flt_q_dmux_fifo_pipe_empty), 
    .trgt_fifo_hdr_data_grnt  (trgt_fifo_hdr_data_grnt), 
    .trgt_halt                (trgt_halt) 
`ifndef SYNTHESIS
  ,
        .flt_pkt_num_valid        (flt_pkt_num_p_valid),
        .flt_pkt_num              (flt_pkt_num_p)
`endif
  );


    radm_demux_ctrl
    
    #(
    ) u_radm_demux_ctrl 
    (
      // Clock and Reset
      .core_clk                                     (core_clk                       ),
      .radm_clk_ug                                  (radm_clk_ug                    ),
      .core_rst_n                                   (core_rst_n                     ),
      // Configuration
      .radm_qmode_ct_byp                            (RADM_QMODE_CT_BYP              ), // Cut-Thru/bypass
      .flt_q_dmux_in                                (flt_q_dmux_fifo_out            ),  
      .trgt_halt                                    (trgt_halt                      ), 
      // Demux to TRGT Interface
      .dmux_trgt1_req                               (dmux_trgt1_req                 ),
      .radm_trgt1_data_dmux                         (radm_trgt1_data_dmux           ),
      .radm_trgt1_hdr_dmux                          (radm_trgt1_hdr_dmux            ),
      .stall_trgt1                                  (stall_trgt1                    ), 
      .dmux_trgt0_req                               (dmux_trgt0_req                 ),
      .trgt0_radm_halt_int                          (trgt0_radm_halt_int            ),
      // Clock Gating Control Signals 
      .dmux_clkg_ctrl                               (dmux_clkg_ctrl                 ),
      // Demux to Header Log Interface
      .flt_q_dmux_hdr_log                           (flt_q_log_p_o                  ), 
      .log_halt                                     (log_halt_p                     )
    );

    radm_trgt1_ctrl
     
     #(
      .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+ATU_CHK_NO),
      .FLT_H_WIDTH       (FLT_P_HDR_WIDTH),   // Filter Header width
      .FLT_H_PROT_WIDTH  (FLT_P_HDR_PROT_WIDTH),   // Filter Header Prot width
      .TRGT1_OUT_WD      (TRGT1_P_OUT_WD),  
      .TRGT1_HDR_WD      (TRGT1_P_HDR_WD),
      .TRGT1_RHDR_WD     (TRGT1_P_RHDR_WD),
      .TRGT1_H_PROT_WD   (`CX_RASDP_TRGT1_P_HDR_PROT_WD),
      .H_IS_P_TYPE       (1),   // P Type Header
      .H_IS_NP_TYPE      (0)    // NP Type Header
     ) 
    u_radm_trgt1_ctrl
    (

      .core_clk                                    (core_clk                      ),
      .radm_clk_ug                                 (radm_clk_ug                   ),
      .core_rst_n                                  (core_rst_n                    ),
      .flit_mode                                   (flit_mode                     ),
      .stall_trgt1                                 (stall_trgt1                   ),
      .radm_trgt1_data_dmux                        (radm_trgt1_data_dmux          ),
      .radm_trgt1_hdr_dmux                         (radm_trgt1_hdr_dmux           ),
      .trgt1_radm_intf_halt                        (trgt1_radm_intf_halt          ),
      .trgt1_xadm_np_req_type                      (),
      .log_halt                                    (log_halt_p                    ),
      .radm_trgt1_out                              (radm_trgt1_out_p              )
      ,
      .ras_dp_err_log                              (ras_dp_err_log[TRGT1_CKH_NO-1:TRGT1_CKH_NO-TRGT1_CHK_CNTS])
      ,
      .ras_dp_err_inj                              (ras_dp_err_inj                )
    );

/*
///////////////////////////////////////////
// TRGT1 data interface checker instance
`ifdef CX_RASDP_EN
// DPP checker for header input
            ras_dp_pipe #(
                .PIPELINE_TYPE           (0),                       // No pipeline only checker instance
                .RESETVAL                (0),                       // Reset value set to 0
                .N_STAGES                (0),                       // No pipeline delay from module
                .CAN_STALL               (0),                       // No stalling
                .RESET_STALL             (0),                       // Stall reset value set to 0.
                .BUS_PROTECT_GEN_EN      (0),                       // generater disabled
                .BUS_PROTECT_CHK_EN      (1),                       // Checker enabled
                .PROT_TYPE               (PROT_TYPE),               
                .PROT_RANGE              (PROT_RANGE),    
                .PROT_WD                 (PROT_WD),
                .PARITY_MODE             (PARITY_MODE),             
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),         
                .TOTAL_WIDTH             (TRGT_DATA_WD-TRGT_DATA_PROT_WD),    
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE)
            ) u_ras_dp_pipe (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (radm_trgt1_out_p.radm_trgt1_dv),
                .din      (radm_trgt1_out_p.radm_trgt1_data[TRGT_DATA_WD-TRGT_DATA_PROT_WD-1:0]),
                .din_prot (radm_trgt1_out_p.radm_trgt1_data[TRGT_DATA_WD-1:TRGT_DATA_WD-TRGT_DATA_PROT_WD]),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(                   ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  (ras_dp_err_log[4] )
                `ifdef CX_RAS_ERROR_INJ_EN
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                `endif // CX_RAS_ERROR_INJ_EN
                );
`endif // CX_RASDP_EN
*/

// ties-off ecrc dwen to zero and compare recieved ecrc
radm_ecrc_extract
 u_radm_ecrc_extract
  (
    .core_clk               (core_clk                   ),
    .core_rst_n             (core_rst_n                 ),
    .flit_mode              (flit_mode                  ),
    .halt_en                (1'b0                       ),
    .rx_tlp                 (rx_tlp                     ),
    .hdr_dec_flt            (hdr_dec_flt), 
    .flt_total_prfx_cnt     (hdr_dec_ecrc_pfrx_dw_count ),
    .flt_local_prfx_cnt     (hdr_dec_ecrc_local_prfx_cnt[2:0]),
    .cfg_ecrc_chk_en        (radm_cfg_i.cfg_ecrc_chk_en ),
    .ecrc_err_inj_enable    (ecrc_err_inj_enable        ),
    .pkt_eot_with_vld_td    (ecrc_pkt_eot_with_vld_td   ),
    .ecrc_rmvd_flt_data     (ecrc_rmvd_flt_data         ),
    .tlp_ecrc_match_err     (tlp_ecrc_match_err         ),
    .malform_ecrc_err       (malform_ecrc_err           ),
    .hdr_dec_flt_p          (hdr_dec_flt_p) 

  );


endmodule


