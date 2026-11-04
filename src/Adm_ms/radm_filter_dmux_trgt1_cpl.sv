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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_filter_dmux_trgt1_cpl.sv#6 $
// -------------------------------------------------------------------------
// -------------------------------------------------------------------------
//Description: 
//This moduls is TOP module of posted TLP type. This module is instantiation of  - 
//    - Completion TLP header decoding module 
//    - Completion filter module 
//    - Completion demux control module to route the posted TLP to TRGT1 or TRGT0 or to TRASH the TLP
//    - Completion TRGT1 control module. TRGT1 interface is per FC type
//    - Gets input from CDM configuration registers
//    - Sends/Receive address, status and any other configuration updates into/from registers
//    Hierarchy - 
//      radm_filter_dmux_trgt1_cpl 
//         |
//          radm_hdr_dec_cpl
//          radm_filter_cpl
//          radm_demux_ctrl
//          radm_trgt1_ctrl
//
//--------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_filter_dmux_trgt1_cpl 
  
  import radm_ms_pkg::PKT_ORD_WD;
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD;
  import radm_ms_pkg::FILTER_CHK_CNTS;
  import radm_ms_pkg::HDR_DEC_CHK_CNTS;
  import radm_ms_pkg::TRGT1_CHK_CNTS;
  import radm_ms_pkg::FILTER_DEMUX_TRGT1_CPL_CHK_CNTS;
  import radm_ms_pkg::TRGT_DATA_WD;
  import radm_ms_pkg::radm_rx_tlp_s;
  import radm_ms_pkg::TRGT_DATA_PROT_WD;
  import radm_ms_pkg::TRGT1_HDR_WD;
  import radm_ms_pkg::D_CPL_FIFO_DEPTH;
  import radm_ms_pkg::D_CPL_ADDR_WIDTH;
  import radm_ms_pkg::INT_DWIDTH;
  import radm_ms_pkg::INT_HWIDTH;
  import radm_ms_pkg::INT_HDW;
  import radm_ms_pkg::radm_cfg_i_s;
  import radm_ms_pkg::radm_cfg_tlp_o_s;
  import radm_ms_pkg::trgt_fifo_rd_grnt_s;
  import radm_ms_pkg::trgt1_cpl_out_s;
  import radm_ms_pkg::radm_ord_mgr_flt_data_s;
  import radm_ms_pkg::radm_hdr_dec_flt_s;
  import radm_ms_pkg::flt_q_dmux_o_s;
  import radm_ms_pkg::flt_cpl_lut_s;
  import radm_ms_pkg::FLT_CPL_HDR_PROT_WIDTH;
  import radm_ms_pkg::FLT_CPL_HDR_WIDTH ;
  import radm_ms_pkg::radm_crd_restore_s;
  import radm_ms_pkg::flt_data_o_s;
  import radm_ms_pkg::flt_cpl_hdr_o_s;
  import radm_ms_pkg::dmux_clkg_ctrl_s;
  import radm_ms_pkg::TRGT1_CPL_OUT_WD;
  import radm_ms_pkg::TRGT1_CPL_HDR_WD;
  import radm_ms_pkg::TRGT1_CPL_RHDR_WD;
  import radm_ms_pkg::TRGT1_CPL_HDR_PROT_WD;
  import radm_ms_pkg::rtrgt1_tlp_out_s;
  import radm_ms_pkg::pktstr_hlog_s;
`ifndef SYNTHESIS
`endif
  import DWC_pcie_ctl_pkg::TAG_SIZE;
  import DWC_pcie_ctl_pkg::NVF;
   import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;


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
    // Config
    input   radm_cfg_i_s                                  radm_cfg_i,
    output  radm_cfg_tlp_o_s                              radm_cfg_o,
    // end config 

`ifndef SYNTHESIS
    // Outputs to testbench
    output logic                                          flt_pkt_num_cpl_valid,
    output logic [PKT_ORD_WD-1:0]                         flt_pkt_num_cpl,
`endif
    input radm_rx_tlp_s                                   rx_tlp,          // Received TLP struct, from OutQ/IDE, to filter
    input                                                 flit_mode, 
    // Filter I/O 
    //input [PKT_ORD_WD-1:0]                                ord_flt_p_pkt_num_cpl,                              
    input                                                 app_req_retry_en,
    input [NF-1:0]                                        app_pf_req_retry_en,

    // TO DO : SK 
    //  `ifdef CX_CCIX_INTERFACE_ENABLE
    //    ,
    //    input [CCIX_WD-1:0]                             hdr_dec_flt_hdr_ccix_tlp
    //  `endif // CX_CCIX_INTERFACE_ENABLE
    input                                                 cpl_mlf_err,
    input                                                 flt_q_cpl_last,
    input                                                 cpl_ur_err,
    input                                                 cpl_ca_err,
    input                                                 lut_filt_cpl_abort,
    input                                                 unexpected_cpl_err,
    input  [NP_REQ_TX_TYPE_WD-1:0]                        lut_flt_np_req_type,
    output [NP_REQ_TX_TYPE_WD-1:0]                        flt_xadm_np_req_type_o,

    output logic                                          cpl_tlp,
    output logic  [TAG_SIZE-1:0]                          flt_q_rcvd_cpl_tlp_tag,
    output logic  [2:0]                                   cpl_status,

    output logic                                          flt_dwlenEq0,
    output logic                                          rtlh_radm_ecrc_err,
    output logic                                          rtlh_radm_malform_tlp_err,
    output flt_q_dmux_o_s                                 flt_q_log_cpl_o,
    input  logic                                          log_halt_cpl,
    input                                                 trgt1_radm_intf_halt,
    output trgt1_cpl_out_s                                radm_trgt1_out_cpl,
    output flt_cpl_lut_s                                  flt_cpl_lut,
    input                                                 ecrc_err_inj_enable,
    output                                                ecrc_pkt_eot_with_vld_td,
    output trgt_fifo_rd_grnt_s                            trgt_fifo_hdr_data_grnt,
output ras_dp_err_log_t [FILTER_DEMUX_TRGT1_CPL_CHK_CNTS-1:0] ras_dp_err_log,
    input  ras_dp_err_inj_t                               ras_dp_err_inj,
    output radm_crd_restore_s                             pktadj_crdmgr_crd_restore,
    // Clock Gating Control Signals 
    output dmux_clkg_ctrl_s                               dmux_clkg_ctrl
);

  //-----------------------------------------------------------------------------
  // Localparam declaration
  //-----------------------------------------------------------------------------
  localparam CPL_BYPASS = 0 + 1 ;

  //---------------------------------------------------------------------
  localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
  localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
  localparam PROT_WD         = `TRGT_DATA_PROT_WD;   
  localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
  localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;

  localparam HDR_DEC_CHK_NO  = 1;
  localparam FILTER_P_CHK_NO = HDR_DEC_CHK_NO + FILTER_CHK_CNTS;
  localparam TRGT1_CKH_NO    = FILTER_P_CHK_NO + TRGT1_CHK_CNTS;
 // Following paramter to detect configured RADM_QMODE is in Cut-Thr/Bypass/Store-forward
  localparam RADM_QMODE_CT_BYP    = (`RADM_CPL_QMODE_VC0 != 1);
  //-------------------------------------- Signal declaration --------------------------------------

  radm_hdr_dec_flt_s                                            hdr_dec_flt; 
  radm_hdr_dec_flt_s                                            hdr_dec_flt_cpl; 
  // flt_q_dmux_o_s                                                flt_q_dmux_o_cpl;
  flt_data_o_s                                                  flt_pktadj_data;
  flt_cpl_hdr_o_s                                               flt_pktadj_hdr;
  flt_data_o_s                                                  pktadj_q_data;
  flt_cpl_hdr_o_s                                               pktadj_q_hdr;
  flt_q_dmux_o_s                                                flt_q_dmux_fifo_out;
  logic                                                         flt_q_dmux_fifo_pipe_empty;
  logic  [INT_DWIDTH -1:0]                                      radm_trgt1_data_dmux;
  logic  [INT_HWIDTH -1:0]                                      radm_trgt1_hdr_dmux;
  logic  [INT_HDW -1:0]                                         dmux_trgt1_req;
   // eCRC related Ports
   logic                                                tlp_ecrc_match_err;
   logic                                                malform_ecrc_err;
   logic [2:0]                                          hdr_dec_ecrc_pfrx_dw_count;     // Total Prefix Count
   logic [4-1:0]                                        hdr_dec_ecrc_local_prfx_cnt;    // Local Prefix Count

   radm_ord_mgr_flt_data_s  ecrc_rmvd_flt_data;
 
  
  radm_hdr_dec_cpl
  
      #(
        .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+HDR_DEC_CHK_NO-1)
      ) u_radm_hdr_dec_cpl 
  (

    .core_clk                               (core_clk                   ),
    .radm_clk_ug                            (radm_clk_ug                ),
    .core_rst_n                             (core_rst_n                 ),                        
    .flit_mode                              (flit_mode                  ),
    .rx_tlp                                 (rx_tlp                     ),
    .hdr_dec_flt_cpl                        (hdr_dec_flt                ), 
    .hdr_dec_ecrc_pfrx_dw_count             (hdr_dec_ecrc_pfrx_dw_count ),
    .hdr_dec_ecrc_local_prfx_cnt            (hdr_dec_ecrc_local_prfx_cnt),
    .lut_flt_np_req_type                    (lut_flt_np_req_type),
    .hdr_dec_ecrc_dwen                      ()
    ,
      .ras_dp_err_log                                         (ras_dp_err_log[HDR_DEC_CHK_NO-1:HDR_DEC_CHK_NO-HDR_DEC_CHK_CNTS]        )
      ,
      .ras_dp_err_inj                                         (ras_dp_err_inj                   )
  );

    flt_cpl_lut_s                                 flt_cpl_lut_in;
    radm_ord_mgr_flt_data_s                       ord_flt_data_cpl_in;
    radm_hdr_dec_flt_s                            hdr_dec_flt_cpl_in;
    logic  [15:0]                                 filt_ant_rid_cpl_in; 
    logic                                         rtlh_radm_parerr_int; 


  radm_anti_addr_ctrl
   u_radm_anti_addr_ctrl (

  // ---- inputs ---------------
  .core_clk                                  (core_clk),
  .radm_clk_ug                               (radm_clk_ug),
  .core_rst_n                                (core_rst_n),
  .flit_mode                                 (flit_mode ),
  .hdr_dec_flt                               (hdr_dec_flt_cpl), 
  .ord_flt_data                              (ecrc_rmvd_flt_data),
  .rtlh_radm_parerr                          (1'b0),
  .lut_flt_np_req_type                       (lut_flt_np_req_type),
  .ord_flt_data_in                       (ord_flt_data_cpl_in),
  .hdr_dec_flt_in                        (hdr_dec_flt_cpl_in),
  .ant_extract_addr                      (), 
  .ant_extract_addr_valid                (), 
  .flt_cpl_lut                           (flt_cpl_lut_in),
  .rtlh_radm_parerr_int                  (rtlh_radm_parerr_int),
  .filt_ant_rid                          (filt_ant_rid_cpl_in)

 );



  radm_filter_cpl
   
      #(
      .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+HDR_DEC_CHK_NO)
     )   
  u_radm_filter_cpl
  (
    .core_clk                                      (core_clk                             ),
    .radm_clk_ug                                   (radm_clk_ug                          ),
    .core_rst_n                                    (core_rst_n                           ),
    .flit_mode                                     (flit_mode                            ),
    .radm_cfg_i                                    (radm_cfg_i                           ),
    .radm_cfg_o                                    (radm_cfg_o                           ),
    .filt_ant_rid_cpl_in                           (filt_ant_rid_cpl_in                  ),
    .flt_cpl_lut_in                                (flt_cpl_lut_in                       ),
    .app_req_retry_en                              (app_req_retry_en                     ),
    .app_pf_req_retry_en                           (app_pf_req_retry_en                  ),
    .ord_flt_data_cpl                              (ord_flt_data_cpl_in                  ),
    //  `ifdef CX_CCIX_INTERFACE_ENABLE
    //    .hdr_dec_flt_hdr_ccix_tlp                (hdr_dec_flt_hdr_ccix_tlp             ),
    //  `endif // CX_CCIX_INTERFACE_ENABLE
    .cpl_mlf_err                                   (cpl_mlf_err                          ),
    .flt_q_cpl_last                                (flt_q_cpl_last                       ),
    .cpl_ur_err                                    (cpl_ur_err                           ),
    .cpl_ca_err                                    (cpl_ca_err                           ),
    .lut_filt_cpl_abort                            (lut_filt_cpl_abort                           ),
    .unexpected_cpl_err                            (unexpected_cpl_err                   ),
    .flt_q_data_o_cpl                              (flt_pktadj_data                      ),
    .flt_q_hdr_o_cpl                               (flt_pktadj_hdr                       ),
    // .flt_q_dmux_o_cpl                              (flt_q_dmux_o_cpl                     ),
    .cpl_tlp                                       (cpl_tlp                              ),
    .flt_q_rcvd_cpl_tlp_tag                        (flt_q_rcvd_cpl_tlp_tag               ),

    .flt_dwlenEq0                                  (flt_dwlenEq0                         ),
    .rtlh_radm_ecrc_err                            (rtlh_radm_ecrc_err                   ),
    .rtlh_radm_malform_tlp_err                     (rtlh_radm_malform_tlp_err            ),
    .cpl_status                                    (cpl_status                           ),
    .flt_cpl_lut                                   (flt_cpl_lut                          ),
    .rtlh_radm_parerr_int                          (rtlh_radm_parerr_int                 ),
    .radm_ecrc_err                                 (tlp_ecrc_match_err                   ), 
    .malform_ecrc_err                              (malform_ecrc_err                     ),
    .hdr_dec_flt_cpl                               (hdr_dec_flt_cpl_in                   ),
    .rx_tlp_hdr                                    (rx_tlp.tlp.hdr                       )
    ,
    .ras_dp_err_log                                         (ras_dp_err_log[FILTER_P_CHK_NO-1:FILTER_P_CHK_NO-FILTER_CHK_CNTS]        )
    ,
    .ras_dp_err_inj                                         (ras_dp_err_inj                   )
    );


radm_pkt_adj

#(.H_TYPE(flt_cpl_hdr_o_s))
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
//`ifdef CX_RASDP_EN    
//assign ras_dp_err_log[4:3] = '0;
//`endif // CX_RASDP_EN

    radm_trgt_pkt_store
    
    #(.H_FIFO_WIDTH   ($bits(flt_cpl_hdr_o_s)),
      .H_STR_P_TYPE   (0),
      .H_STR_NP_TYPE  (0),
      .CPL_BYPASS     (CPL_BYPASS),
      .ST_CT_CTRL     (`RADM_CPL_QMODE_VC0),
      .D_FIFO_DEPTH   (D_CPL_FIFO_DEPTH),
      .D_ADDR_WIDTH   (D_CPL_ADDR_WIDTH)
    )  
    u_radm_trgt_pkt_store 
      (
        .core_clk                 (core_clk),           
        .core_rst_n               (core_rst_n),  
        .trgt_halt                (trgt_halt), 
        .flt_q_data_in            (pktadj_q_data),
        .flt_q_hdr_in             (pktadj_q_hdr),
        .radm_trgt_fifo_out       (flt_q_dmux_fifo_out), 
        .radm_trgt_fifo_pipe_empty(flt_q_dmux_fifo_pipe_empty),
        .trgt_fifo_hdr_data_grnt  (trgt_fifo_hdr_data_grnt)
`ifndef SYNTHESIS
  ,
        .flt_pkt_num_valid        (flt_pkt_num_cpl_valid),
        .flt_pkt_num              (flt_pkt_num_cpl)
`endif
      );

logic stall_trgt1;

  radm_demux_ctrl
  
  #(
  ) u_radm_demux_ctrl(
    // Clock and Reset
    .core_clk                                      (core_clk                             ),
    .radm_clk_ug                                   (radm_clk_ug                          ),
    .core_rst_n                                    (core_rst_n                           ),
    // Configuration
    .radm_qmode_ct_byp                             (RADM_QMODE_CT_BYP                    ), // Cut-Thru/Bypass
    // Packet Store to Demux Interface
    .flt_q_dmux_in                                 (flt_q_dmux_fifo_out                  ), 
    .trgt_halt                                     (trgt_halt                            ),
    // Demux to TRGT Interface
    .dmux_trgt1_req                                (dmux_trgt1_req                       ),
    .radm_trgt1_data_dmux                          (radm_trgt1_data_dmux                 ),
    .radm_trgt1_hdr_dmux                           (radm_trgt1_hdr_dmux                  ),
    .stall_trgt1                                   (stall_trgt1                          ),
    .dmux_trgt0_req                                (                                     ),
    .trgt0_radm_halt_int                           (1'b0                                 ), 
    // Clock Gating Control Signals
    .dmux_clkg_ctrl                                (dmux_clkg_ctrl                       ),
    // Demux to Header Log Interface
    .flt_q_dmux_hdr_log                            (flt_q_log_cpl_o                      ),  
    .log_halt                                      (log_halt_cpl                         )
  );

  radm_trgt1_ctrl
   
  #(
   .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+FILTER_P_CHK_NO),
   .FLT_H_WIDTH       (FLT_CPL_HDR_WIDTH),   // Filter Header width
   .FLT_H_PROT_WIDTH  (FLT_CPL_HDR_PROT_WIDTH),   // Filter Header Prot width
   .TRGT1_OUT_WD      (TRGT1_CPL_OUT_WD),  
   .TRGT1_HDR_WD      (TRGT1_CPL_HDR_WD),
   .TRGT1_RHDR_WD     (TRGT1_CPL_RHDR_WD),
   .TRGT1_H_PROT_WD   (`CX_RASDP_TRGT1_CPL_HDR_PROT_WD),   
   .H_IS_P_TYPE       (0),   // P Type Header
   .H_IS_NP_TYPE      (0)    // NP Type Header
  )   
  u_radm_trgt1_ctrl
  (

    // Clock and Reset
    .core_clk                                      (core_clk                             ),
    .radm_clk_ug                                   (radm_clk_ug                          ),
    .core_rst_n                                    (core_rst_n                           ),
    .flit_mode                                     (flit_mode                            ),
    .stall_trgt1                                   (stall_trgt1                          ),
    .radm_trgt1_data_dmux                          (radm_trgt1_data_dmux                 ),
    .radm_trgt1_hdr_dmux                           (radm_trgt1_hdr_dmux                  ),
    .trgt1_radm_intf_halt                          (trgt1_radm_intf_halt                 ),
    .trgt1_xadm_np_req_type                        (flt_xadm_np_req_type_o               ),
    .log_halt                                      (log_halt_cpl                         ),
    .radm_trgt1_out                                (radm_trgt1_out_cpl                   )
    ,
    .ras_dp_err_log                                (ras_dp_err_log[TRGT1_CKH_NO-1:TRGT1_CKH_NO-TRGT1_CHK_CNTS])
    ,
    .ras_dp_err_inj                                (ras_dp_err_inj                       )
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
                
                .valid_in (radm_trgt1_out_cpl.radm_trgt1_dv),
                .din      (radm_trgt1_out_cpl.radm_trgt1_data[TRGT_DATA_WD-TRGT_DATA_PROT_WD-1:0]),
                .din_prot (radm_trgt1_out_cpl.radm_trgt1_data[TRGT_DATA_WD-1:TRGT_DATA_WD-TRGT_DATA_PROT_WD]),
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
    .ecrc_err_inj_enable     (ecrc_err_inj_enable       ),
    .pkt_eot_with_vld_td     (ecrc_pkt_eot_with_vld_td  ),
    .ecrc_rmvd_flt_data     (ecrc_rmvd_flt_data         ),
    .tlp_ecrc_match_err     (tlp_ecrc_match_err         ),
    .malform_ecrc_err       (malform_ecrc_err           ),
    .hdr_dec_flt_p            (hdr_dec_flt_cpl) 
  );


endmodule
