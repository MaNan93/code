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
// ---    $DateTime: 2023/12/06 00:52:40 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_hdr_dec_p.sv#7 $
// -------------------------------------------------------------------------
// Description: 
// This module is to form header as per mode of operation (FLIT mode or NON-FLIT mode)
// Each field from incoming header seperates as P TLP type and forms header as per the required 
// Header format in NON-FLIT mode before giving it to respective TLP filter type. 
// Required functions and structures are added in radm_ms_pkg.svh module. 
// ---------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module radm_hdr_dec_p
  import pcie_pkg::mode_e;
  import pcie_pkg::tlp_hdr_pkt_s;
  import pcie_pkg::f_tlp_is_fm_p_rsvd;
  //////////////////////////////////////
  //import radm_ms_pkg parameters for radm_hdr_dec_p: starts
  import DWC_pcie_ctl_pkg::NW;
  import radm_ms_pkg::RADM_HDR_PROT_WD;
  import radm_ms_pkg::CPL_LUT_PTR_WD;
  import radm_ms_pkg::NHW;
  import radm_ms_pkg::HW;
  import radm_ms_pkg::HW_NFT;
  import radm_ms_pkg::radm_rx_tlp_s;
  import radm_ms_pkg::HW_NFT_PAR;
  import radm_ms_pkg::ST_WD;
  import radm_ms_pkg::PRFX_WD;
  import radm_ms_pkg::PRFX_WD_PAR;
  import radm_ms_pkg::radm_hdr_log_rcvd_flds_s ;
  import radm_ms_pkg::TLP_FMT_WD;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_decx_present_s;
  import radm_ms_pkg::radm_hdr_dec_flt_s;
  import radm_ms_pkg::radm_hdr_dec_com_tlp_s;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_dw_s;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_ex_present_s;

  //import radm_ms_pkg parameters for radm_hdr_dec_p: ends
  ////////////////////////////////////


///////////////////////////////////////////////////////////
// import  DWC_pcie_ctl_pkg for radm_hdr_dec_p: starts
  import DWC_pcie_ctl_pkg::TAG_SIZE         ;
    import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
// import  DWC_pcie_ctl_pkg for radm_hdr_dec_p: ends
/////////////////////////////////////////////////////





    // parameter/localparam Declaration 
#(
  parameter RAS_DP_PROT_CHK_ID_BASE  = 0
)
  
                       (
    // Input/Output Declaration 

    input                                 core_clk,
    input                                 radm_clk_ug,
    input                                 core_rst_n,
      
    input                                 flit_mode,                    // If FLIT_MODE is enabled and physical layer detects flit mode, this signal asserts. If this signal is low controller works in NON-FLIT mode even of FLIT_MODE configuration is enabled.
    input  radm_rx_tlp_s                  rx_tlp,                       // Received TLP struct, from OutQ/IDE, to filter
    output radm_hdr_dec_flt_s             hdr_dec_flt_p,                // Structured inputs received from HDR_Comon_dec 
    output ras_dp_err_log_t                 ras_dp_err_log,
    input  ras_dp_err_inj_t                 ras_dp_err_inj ,  
    output [2:0]                          hdr_dec_ecrc_pfrx_dw_count,   // Total Prefix Count
    output [4-1:0]                        hdr_dec_ecrc_local_prfx_cnt,  // Local Prefix Count
    output [NHW-1:0]                      hdr_dec_ecrc_dwen             // Local Prefix dwen tied to zero
  );
  localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
  localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
  localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
  localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;

    // Internal wire/reg  Declaration (in SV wire/reg is considered as loic declaration) 
   logic  [NHW-1:0]                    hdr_dec_flt_prfx_dwen;
   logic  [4-1:0]                      hdr_dec_local_prfx_cnt_in;
   logic                               ohc_b_present;
   logic                               sub_strem_id_seven;
    logic                               radm_malf_tlp_err_hdr;
    logic                               radm_malf_tlp_err_hdr_prfx;
    logic                               radm_malf_tlp_err_hdr_flit;

   logic  [2:0]                        pfrx_dw_count_nfm_in;
    /// COMMON
    radm_hdr_log_rcvd_flds_s              log_rcvd_flds, log_rcvd_flds_i ;
    logic                                 ohc_a1_form_err;
    logic                                 ohc_a_be_form_err;
    logic                                 ohc_a4_form_err;
    logic                                 ohc_ur_err_p;
    logic                                 ide_ohc_c_err;
    logic                                 ide_prfx_vld;
    logic [1:0]                           hdr_dec_tlp_ph;
    logic                                 hdr_dec_tlp_nw;
    logic                                 tlp_ln;
    logic [HW_NFT-1:0]                    tmp_hdr;
    logic [TLP_FMT_WD-1:0]                tlp_fmt;
    logic [4:0]                           tlp_type_int;
    logic                                 curnt_ismsg;
    logic [7 : 0]                         hdr_dec_flt_cpltr_seg;
    logic [8 : 0]                         hdr_dec_flt_dest_seg;
    logic [8 : 0]                         hdr_dec_flt_reqtr_seg;
    logic [14-1:0]                        tlp_tag_14bit;
    logic [14-1:0]                        tlp_tag_6bit_msg;
    logic                                 curnt_ismemwr;
    logic                                 curnt_is_tphmemwr;
    logic [9:0]                           hdr_dw_len;
    logic [7:0]                           ohc_c_pr_sent_cntr; 
    logic [7:0]                           ohc_c_strm_in     ;
    logic [3:0]                           ohc_c_sub_strm_id ;
    logic                                 ohc_c_t           ;
    logic                                 ohc_c_k           ;
    logic [22:0]                          ohc_c_info        ;
    // logic [(HW) - 1 : 0]                  hdr_to_flt_fm;
      logic                               hdr_dec_flt_prfx_p_dwen;
      radm_hdr_dec_com_ohc_dw_s           ohc_dw_p;           // Called in the form of structure
      radm_hdr_dec_com_ohc_ex_present_s   ohc_ex_present_p;   // Called in the form of structure
    logic [19:0]                          ohc_a_pasid;
    logic                                 ohc_a_er;
    logic                                 ohc_a_pmr;
    logic                                 ohc_a_pv;
    logic                                 ohc_a_nw;
    logic                                 tlp_nw;
    logic [15:0]                          ohc_b_st;
    logic                                 ohc_b_av;
    logic  [2:0]                          ohc_b_ama;
    logic  [1:0]                          ohc_b_hv;
    logic  [1:0]                          ohc_b_ph;
    logic [22:0]                          hdr_dec_flt_pasid_er_pmr_pv_in; 
    logic [9:0]                           com_dw_len;
    logic [7 : 0]                         ohc_a_dest_segment;
    logic [7 : 0]                         ohc_a_cpl_segment;
    logic [2:0]                           ohc_a_cpl_status; 
    logic                                 ohc_a_dsv;
    logic [7 : 0]                         ohc_c_reqtr_segment;
    logic                                 ohc_c_rsv;
    radm_hdr_dec_com_ohc_decx_present_s   ohc_decx_present_p;
    
    logic [7:0]                           flit_byte_en;
    logic                                 ohc_c_present;          
    logic                                 hdr_th;
    logic                                 curnt_is_tph;
    logic [TAG_SIZE-1:0]                  tlp_tag;
    logic                                 curnt_istransreq;
    logic [7:0]                           hdr_dw4_byte0;
    logic                                 ohc_a1_present;
    logic                                 ohc_a4_present;
    logic                                 ohc_a_present;
          
    logic [3:0]                           ohc_a_ldw_be; 
    logic [3:0]                           ohc_a_ldw_be_in; 
    logic [3:0]                           ohc_a_fdw_be;  
    logic [3:0]                           ohc_a_fdw_be_in;  
    logic [14:0]                          hdr_rsvd;
    logic [NHW - 1:0][32 - 1:0]           hdr_dw;
    logic                                 ohc_a1_pv; 
    logic [1:0]                           ohc_tlp_addr;
    logic                                 e_e_prfx_type4;
    logic [7:0 ]                          int_byte_en;
    logic [7:0 ]                          ohc_b_st_lb;
    logic [7:0 ]                          ohc_c_cpltr_segment;
    logic [2:0]                           local_prfx_fmt;
    logic [2:0]                           e_e_prfx_fmt;
    logic                                 local_prfx_type4;
    logic [7:0]                           local_prfx_decode;
    logic [3:0]                           e2e_prfx_decode;
    logic [7:0]                           pasid_decode;
    logic [8 : 0]                         hdr_dec_flt_dest_seg_in;
    logic [8 : 0]                         hdr_dec_flt_reqtr_seg_in;
    logic [6:0]                           fmt_type;
    logic  [31:0]                         int_common_hdr;
    radm_hdr_dec_com_tlp_s                tlp_p;
  logic [HW_NFT-1:0]                          hdr_to_flt_nfm;
    logic [PRFX_WD-1:0]                   hdr_dec_flt_prfx;
   logic                                  tlp_ats_vld;

  tlp_hdr_pkt_s                         s_tlp_hdr_pkt;
  logic [2:0]                           s_tlp_fm_p_rsvd_info; 
  logic                                 s_tlp_is_fm_p_rsvd;                               
  logic                                 s_tlp_is_fm_p_rsvd_routed_by_addr;

  //////////////////////////////////////////////////////////
  // Instantitation of Gen6 common header decoder 
  //Gen6 FLIT Common header decoder for all TLP types 
  //for more detail please refer module radm_hdr_dec_common.sv
  ////////////////////////////////////////////////////////////
// DPP checker for header input
            ras_dp_pipe
             #(
                .PIPELINE_TYPE           (0),                       // No pipeline only checker instance
                .RESETVAL                (0),                       // Reset value set to 0
                .N_STAGES                (0),                       // No pipeline delay from module
                .CAN_STALL               (0),                       // No stalling
                .RESET_STALL             (0),                       // Stall reset value set to 0.
                .BUS_PROTECT_GEN_EN      (0),                       // generater disabled
                .BUS_PROTECT_CHK_EN      (1),                       // Checker enabled
                .PROT_TYPE               (PROT_TYPE),               
                .PROT_RANGE              (PROT_RANGE),    
                .PROT_WD                 (HW/PROT_RANGE),
                .PARITY_MODE             (PARITY_MODE),             
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),         
                .TOTAL_WIDTH             (HW),                      // Total header width  
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE),
                .PIPE_RAS_DP_ERR_LOG     (1)
            ) u_ras_dp_pipe (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (rx_tlp.tlp.hdr.hv),
                .din      (rx_tlp.tlp.hdr.hdr[HW-1:0]),
                .din_prot (rx_tlp.tlp.hdr.hdr[HW+RADM_HDR_PROT_WD-1:HW]),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(                   ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  (ras_dp_err_log )
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );


// parity generate module instance without pipe delay for non flit mode hdr
            ras_dp_pipe
             #(
                .PIPELINE_TYPE           (0),                  // No pipeline only checker instance
                .RESETVAL                (0),                  
                .N_STAGES                (0),                  
                .CAN_STALL               (0),                  
                .RESET_STALL             (0),                  
                .BUS_PROTECT_GEN_EN      (1),                   
                .BUS_PROTECT_CHK_EN      (0),                  
                .PROT_TYPE               (PROT_TYPE),          // cc
                .PROT_RANGE              (PROT_RANGE),         // cc
                .PROT_WD                 (HW_NFT/PROT_RANGE),
                .PARITY_MODE             (PARITY_MODE),        // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),    // cc
                .TOTAL_WIDTH             (HW_NFT),             
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (0)
            ) u_ras_dp_pipe_gen_hdr (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (1'b1               ),
                .din      (hdr_dec_flt_p.hdr_dec_flt_hdr[HW_NFT-1:0] ),
                .din_prot ('0                  ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(hdr_dec_flt_p.hdr_dec_flt_hdr[HW_NFT+HW_NFT_PAR-1:HW_NFT]   ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  ()
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );
// parity generate module instance without pipe delay for non flit mode prefixes
            ras_dp_pipe
             #(
                .PIPELINE_TYPE           (0),                  // No pipeline only checker instance
                .RESETVAL                (0),                  
                .N_STAGES                (0),                  
                .CAN_STALL               (0),                  
                .RESET_STALL             (0),                  
                .BUS_PROTECT_GEN_EN      (1),                   
                .BUS_PROTECT_CHK_EN      (0),                  
                .PROT_TYPE               (PROT_TYPE),          // cc
                .PROT_RANGE              (PROT_RANGE),         // cc
                .PROT_WD                 (PRFX_WD/PROT_RANGE),
                .PARITY_MODE             (PARITY_MODE),        // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),    // cc
                .TOTAL_WIDTH             (PRFX_WD),             
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (0)
            ) u_ras_dp_pipe_gen_prfx (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (1'b1               ),
                .din      (hdr_dec_flt_p.hdr_dec_flt_prfx[PRFX_WD-1:0] ),
                .din_prot ('0                  ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(hdr_dec_flt_p.hdr_dec_flt_prfx[PRFX_WD+PRFX_WD_PAR-1:PRFX_WD]   ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  ()
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );


  radm_hdr_dec_common
   u_radm_hdr_dec_common 
  (
    .flit_mode                        (flit_mode              ),
    .core_clk                         (core_clk               ),
    .core_rst_n                       (core_rst_n             ),
    .rx_tlp_hdr                       (rx_tlp.tlp.hdr         ),
    .rx_tlp_eot                       (rx_tlp.tlp.ctl.eot     ),
    .hdr_to_flt_nfm                   (hdr_to_flt_nfm         ),
    .hdr_dec_flt_prfx_dwen            (hdr_dec_flt_prfx_dwen  ),
    .hdr_dec_local_prfx_cnt           (hdr_dec_local_prfx_cnt_in ),
    .sub_strem_id_seven               (sub_strem_id_seven ),
    .radm_malf_tlp_err_hdr            (radm_malf_tlp_err_hdr),
    .radm_malf_tlp_err_hdr_prfx       (radm_malf_tlp_err_hdr_prfx),
    .radm_malf_tlp_err_hdr_flit       (radm_malf_tlp_err_hdr_flit),
    .pfrx_dw_count_nfm                (pfrx_dw_count_nfm_in )
    , 
    .hdr_dec_flt_prfx                 (hdr_dec_flt_prfx)
      ,
      .curnt_iscpl                    (1'b0                   ),
      .curnt_ismsg                    (curnt_ismsg            ),
      .curnt_is_cfg_io                (1'b0                   ),
      .int_common_hdr                 (int_common_hdr         ),
      .hdr_dw                         (hdr_dw                 ),
      .log_rcvd_flds                  (log_rcvd_flds          ),
      .fmt_type                       (fmt_type               ),  
      .addr64                         (addr64                 ),
      .hdr_dw_len                     (hdr_dw_len             ),
      .ohc_decx_present               (ohc_decx_present_p     ),
      .tlp_ats_vld                    (tlp_ats_vld            ),
      .ide_prfx_vld                   (ide_prfx_vld          ),
      .tlp                            (tlp_p                  ),
      .ohc_c_info                     (ohc_c_info             ),
       .ohc_b_hv                      (ohc_b_hv               )
        ,
        .ohc_ex_present               (ohc_ex_present_p       ),
        .ohc_ex_dw                    (ohc_dw_p               ),
       .st_15_8                       (ohc_b_st[15:8]           ),
       .ohc_b_av                      (ohc_b_av               ),
       .ohc_b_ama                     (ohc_b_ama              ),
       .hdr_dec_flt_pasid_er_pmr_pv_in  (hdr_dec_flt_pasid_er_pmr_pv_in )
  );
    ////////////////////////////////////////////////////////
    // End of Common module instantation
    ////////////////////////////////////////////////////////
   

     always_comb begin : FLIT_PRFX_VLD
        ide_prfx_vld       = 1'b0;
        ide_ohc_c_err      = 1'b0;  
       
        if (ohc_c_present && flit_mode && !sub_strem_id_seven && rx_tlp.tlp.hdr.hv)
        begin
           ide_prfx_vld         = 1'b0; 
           ide_ohc_c_err        = 1'b1; 
        end
     end


    logic [31:0]                tlp_addr_32;  
    logic                       tlp_byte6_bit6;  
    assign tlp_byte6_bit6 = tlp_p.tlp_cpl_la_addr[4]; // For invalidate message and VDMs, Byte6[6:0] is used as a Tag/Vendor definitions. Part of Byte[6:0] is in Tag signal. This bit considered for message only
    assign tlp_addr_32  = tlp_p.tlp_addr[63:32];
    assign hdr_dec_flt_p.hdr_dec_flt_c_d_r_14bit_t  = {1'b0, ohc_ur_err_p, hdr_dec_tlp_nw,hdr_dec_tlp_ph,ohc_b_st_lb,hdr_dec_flt_cpltr_seg,hdr_dec_flt_dest_seg,hdr_dec_flt_reqtr_seg,tlp_tag_14bit};
    assign int_byte_en                              = {ohc_a_ldw_be[3:0], ohc_a_fdw_be[3:0]};

    assign ohc_b_st_lb                              =  (ohc_b_present && ohc_b_hv[0]) ? ohc_b_st[ST_WD-1:0] : 'd0;
    assign ohc_c_cpltr_segment                      = 'd0;
    assign curnt_ismsg                              = ((fmt_type[6:3] == `MSG_4) || (fmt_type[6:3] == `MSGD_4)) ;
    logic addr_routed_msg;
    logic route_to_root_cmplx_msg;
    logic id_routed_msg;
    assign addr_routed_msg                          = (fmt_type[2:0] == 3'b001) && curnt_ismsg;
    assign route_to_root_cmplx_msg                  = (fmt_type[2:0] == 3'b000) && curnt_ismsg;
    assign id_routed_msg                            = (fmt_type[2:0] == 3'b010) && curnt_ismsg;

    assign curnt_ismemwr                            = ((fmt_type == `MWR32)  || (fmt_type == `MWR64));
    assign curnt_istransreq                         = (curnt_ismemwr && tlp_ats_vld) ;

    assign tlp_type_int                             =  tlp_p.tlp_type;
    assign tlp_fmt                                  = hdr_dw[0][7:5];

    assign hdr_th                                   = int_common_hdr[8];
    //assign ohc_b_present                            = ohc_decx_present_p.ohc_dec_b_present && curnt_ismemwr;
    assign ohc_b_present                            = ohc_decx_present_p.ohc_dec_b_present ; // changed made as per latest spec update Errata ver 19
   // assign ohc_b_form_err                           = ohc_decx_present_p.ohc_dec_b_present && !curnt_ismemwr;
    assign hdr_dec_tlp_nw                           = curnt_istransreq ?  tlp_nw : 1'b0;
    assign hdr_dec_tlp_ph                           = (ohc_b_present && ohc_b_hv[0])  ? ohc_b_ph : 2'h0;

    logic tlp_nw_err;
    assign ohc_ur_err_p = rx_tlp.tlp.hdr.hv && flit_mode && (tlp_nw_err  || ohc_a4_form_err || ide_ohc_c_err);



    assign tlp_nw                                   = ohc_a_nw ;
    assign tlp_nw_err                               = ohc_a_nw && !curnt_istransreq;
    assign curnt_is_tph                             = curnt_is_tphmemwr;
    assign tlp_tag                                  = curnt_is_tph ? {{(TAG_SIZE - 8){1'b0}},ohc_b_st[7:0]} : tlp_p.tlp_tag;
    assign flit_byte_en                             = {ohc_a_ldw_be[3:0], ohc_a_fdw_be[3:0]};
    assign ohc_a1_present                           = ohc_decx_present_p.ohc_dec_a_present && ( curnt_ismemwr || addr_routed_msg || route_to_root_cmplx_msg);
    //assign ohc_a1_form_err                          = ohc_decx_present_p.ohc_dec_a_present && !(curnt_ismemwr || addr_routed_msg || curnt_istransreq);
    assign ohc_a_ldw_be        = ohc_a1_present ?    ohc_a_ldw_be_in : ((|hdr_dw_len[9:1]) ||  !(|hdr_dw_len[9:0])) ? 4'hf : 'd0; 
    assign ohc_a_fdw_be        = ohc_a1_present ?    ohc_a_fdw_be_in  : 4'hf; 
    assign ohc_a_be_form_err   = ohc_a1_present &&  !((|ohc_a_ldw_be_in) || (|ohc_a_fdw_be_in));  
    assign ohc_a4_present                   = ohc_decx_present_p.ohc_dec_a_present && id_routed_msg; 
    assign ohc_a4_form_err                          = ohc_decx_present_p.ohc_dec_a_present && curnt_ismsg && ((id_routed_msg && tlp_p.tlp_msg_code == `INVALIDATE_COMPLETION) && ohc_a_pv); 

    assign ohc_a_present                            = ohc_decx_present_p.ohc_dec_a_present && (ohc_a1_present  || ohc_a4_present ) ;
    assign ohc_a1_pv                                = ohc_decx_present_p.ohc_dec_a_present &  hdr_dw4_byte0[6];
    assign hdr_dw4_byte0                            = ohc_decx_present_p.ohc_dec_a_present ? (addr64 ? (hdr_dw[4][31:24]) : (hdr_dw[4][31:24]))  : 'd0;
    assign ohc_c_present                            = ohc_decx_present_p.ohc_dec_c_present ;
    assign tlp_ln                                   = 1'b0; 
    assign hdr_dec_flt_pasid_er_pmr_pv_in           = {ohc_a_pasid,ohc_a_er,ohc_a_pmr,ohc_a_pv};
    // form basic headers

    assign curnt_is_tphmemwr                        = 1'b0; // TODO karam to review this: curnt_ismemwr && hdr_th && `CX_TPH_ENABLE_VALUE;
    assign hdr_dec_flt_dest_seg_in                  = {ohc_a_dsv,ohc_a_dest_segment};
    assign hdr_dec_flt_reqtr_seg_in                 = {ohc_c_rsv,ohc_c_reqtr_segment};


    ///////////////////////////////////////////////////////////////////////////////////////
    // Following block seperated OHC fields as per received OHC header
    //////////////////////////////////////////////////////////////////////////////////////

    always_comb begin : DECODE_OHC
      ohc_a_pasid[19:0]               = 'd0;
      ohc_a_er                        = 'd0; 
      ohc_a_pmr                       = 'd0; 
      ohc_a_pv                        = 'd0;
      ohc_a_nw                        = 'd0;
      ohc_a_ldw_be_in                    = 'd0;
      ohc_a_fdw_be_in                    = 'd0; 
      ohc_a_dsv                       = 1'b0;
      ohc_a_dest_segment[7:0]         = 'd0;
      ohc_a_cpl_segment               = 'd0;
      ohc_a_cpl_status                = 'd0;
      ohc_tlp_addr[1:0]               = 'd0;

      case ({ohc_a4_present,ohc_a1_present,addr64})
        3'b011:
          begin
            ohc_a_pasid[19:0]         = {hdr_dw[4][3:0],hdr_dw[4][15:8],hdr_dw[4][23:16]};
            ohc_a_er                  =  hdr_dw[4][4];
            ohc_a_pmr                 =  hdr_dw[4][5];
            ohc_a_pv                  =  hdr_dw[4][6];
            ohc_a_nw                  =  hdr_dw[4][7];
            ohc_a_ldw_be_in              =  hdr_dw[4][31:28];
            ohc_a_fdw_be_in              =  hdr_dw[4][27:24];
          end
        3'b010:
          begin
            ohc_a_pasid[19:0]         = {hdr_dw[3][3:0],hdr_dw[3][15:8],hdr_dw[3][23:16]};
            ohc_a_er                  =  hdr_dw[3][4];
            ohc_a_pmr                 =  hdr_dw[3][5];
            ohc_a_pv                  =  hdr_dw[3][6];
            ohc_a_nw                  =  hdr_dw[3][7];
            ohc_a_ldw_be_in              =  hdr_dw[3][31:28];
            ohc_a_fdw_be_in              =  hdr_dw[3][27:24];
          end
        3'b101:
          begin
            ohc_a_pasid[19:0]         = {hdr_dw[4][19:16],hdr_dw[4][15:8],hdr_dw[4][31:24]};
            ohc_a_pv                  =  hdr_dw[4][22];
            ohc_a_dsv                 = hdr_dw[4][23];
            ohc_a_dest_segment[7:0]   = hdr_dw[4][7:0];
          end
        3'b100:
          begin
            ohc_a_pasid[19:0]         = {hdr_dw[3][19:16],hdr_dw[3][15:8],hdr_dw[3][31:24]};
            ohc_a_pv                  =  hdr_dw[3][22];
            ohc_a_dsv = hdr_dw[3][23];
            ohc_a_dest_segment[7:0]   = hdr_dw[3][7:0];
          end
        default:
          begin
            ohc_a_pasid[19:0]         = 'd0;
            ohc_a_er                  = 'd0; 
            ohc_a_pmr                 = 'd0; 
            ohc_a_pv                  = 'd0;
            ohc_a_ldw_be_in              = 'd0;
            ohc_a_fdw_be_in              = 'd0; 
            ohc_a_dsv                 = 1'b0;
            ohc_a_dest_segment[7:0]   = 'd0;
          end
      endcase

    end //DECODE_OHC



    always_comb begin : DECODE_PASID
      ohc_b_st[15:0]                  = 'd0;
      ohc_b_av                        = 'd0;
      ohc_b_ama                       = 'd0;
      ohc_b_hv                        = 'd0;
      ohc_b_ph                        = 'd0;

      if (rx_tlp.tlp.hdr.hv)
      begin
        case ({ohc_b_present,ohc_a_present,addr64})
          3'b111:
            begin
              ohc_b_st[15:0]          = {hdr_dw[5][15:8],hdr_dw[5][23:16]};
              ohc_b_av                = hdr_dw[5][24];
              ohc_b_ama               = hdr_dw[5][27:25];
              ohc_b_hv                = hdr_dw[5][29:28];
              ohc_b_ph                = hdr_dw[5][31:30];
            end

          3'b110,3'b101:
            begin
              ohc_b_st[15:0]          = {hdr_dw[4][15:8],hdr_dw[4][23:16]};
              ohc_b_av                = hdr_dw[4][24];
              ohc_b_ama               = hdr_dw[4][27:25];
              ohc_b_hv                = hdr_dw[4][29:28];
              ohc_b_ph                = hdr_dw[4][31:30];
            end       
          3'b100:       
            begin       
              ohc_b_st[15:0]          = {hdr_dw[3][15:8],hdr_dw[3][23:16]};
              ohc_b_av                = hdr_dw[3][24];
              ohc_b_ama               = hdr_dw[3][27:25];
              ohc_b_hv                = hdr_dw[3][29:28];
              ohc_b_ph                = hdr_dw[3][31:30];
            end
          default:
            begin
              ohc_b_st[15:0]          = 'd0;
              ohc_b_av                = 'd0;
              ohc_b_ama               = 'd0;
              ohc_b_hv                = 'd0;
              ohc_b_ph                = 'd0;
            end
        endcase
      end //DECODE_PASID
    end



assign ohc_c_info = {ohc_c_present,ohc_c_pr_sent_cntr,ohc_c_strm_in,ohc_c_sub_strm_id,ohc_c_t,ohc_c_k};

    always_comb begin : DECODE_PASID_2
      ohc_c_reqtr_segment     = 'd0;
      ohc_c_pr_sent_cntr      = 'd0; 
      ohc_c_strm_in           = 'd0;
      ohc_c_sub_strm_id       = 'd0;
      ohc_c_t                 = 'd0;
      ohc_c_k                 = 'd0;
      ohc_c_rsv               = 'd0;

      if (rx_tlp.tlp.hdr.hv)
      begin
        case ({ohc_c_present,ohc_b_present,ohc_a_present,addr64})
          4'b1111:
            begin
              ohc_c_reqtr_segment     = hdr_dw[6][7:0];
              ohc_c_pr_sent_cntr      = hdr_dw[6][15:8];
              ohc_c_strm_in           = hdr_dw[6][23:16];
              ohc_c_sub_strm_id       = hdr_dw[6][31:28];
              ohc_c_t                 = hdr_dw[6][24];
              ohc_c_k                 = hdr_dw[6][25];
              ohc_c_rsv               = hdr_dw[6][27];
            end

          4'b1110,4'b1101,4'b1011:
            begin
              ohc_c_reqtr_segment     = hdr_dw[5][7:0];
              ohc_c_pr_sent_cntr      = hdr_dw[5][15:8];
              ohc_c_strm_in           = hdr_dw[5][23:16];
              ohc_c_sub_strm_id       = hdr_dw[5][31:28];
              ohc_c_t                 = hdr_dw[5][24];
              ohc_c_k                 = hdr_dw[5][25];
              ohc_c_rsv               = hdr_dw[5][27];
            end
          4'b1100,4'b1001,4'b1010:
            begin
              ohc_c_reqtr_segment     = hdr_dw[4][7:0];
              ohc_c_pr_sent_cntr      = hdr_dw[4][15:8];
              ohc_c_strm_in           = hdr_dw[4][23:16];
              ohc_c_sub_strm_id       = hdr_dw[4][31:28];
              ohc_c_t                 = hdr_dw[4][24];
              ohc_c_k                 = hdr_dw[4][25];
              ohc_c_rsv               = hdr_dw[4][27];
            end
          4'b1000:
            begin
              ohc_c_reqtr_segment     = hdr_dw[3][7:0];
              ohc_c_pr_sent_cntr      = hdr_dw[3][15:8];
              ohc_c_strm_in           = hdr_dw[3][23:16];
              ohc_c_sub_strm_id       = hdr_dw[3][31:28];
              ohc_c_t                 = hdr_dw[3][24];
              ohc_c_k                 = hdr_dw[3][25];
              ohc_c_rsv               = hdr_dw[3][27];
            end
          default:
            begin
              ohc_c_reqtr_segment     = 'd0;
              ohc_c_pr_sent_cntr      = 'd0; 
              ohc_c_strm_in           = 'd0;
              ohc_c_sub_strm_id       = 'd0;
              ohc_c_t                 = 'd0;
              ohc_c_k                 = 'd0;
              ohc_c_rsv               = 'd0;
            end
        endcase
      end //DECODE_PASID_2
    end




      assign  local_prfx_fmt          = 3'b100;
      assign  local_prfx_type4        = 1'b0;
      assign  local_prfx_decode       = {local_prfx_fmt, local_prfx_type4, 4'b0000};
      assign  e2e_prfx_decode         = {local_prfx_fmt, e_e_prfx_type4};
      assign  e_e_prfx_fmt            = 3'b100;
      assign  e_e_prfx_type4          = 1'b1;
      assign  pasid_decode            = {e_e_prfx_fmt, e_e_prfx_type4, 4'b0001};
      assign hdr_dec_flt_prfx_p_dwen  = 'd0;

      always_comb begin : DECODE_PREFIX1
        ohc_dw_p.ohc_e1_dw0                = 'd0;

        if (rx_tlp.tlp.hdr.hv )
        begin
          case ({ohc_ex_present_p.ohc_e1_present,ohc_c_present,ohc_b_present,ohc_a_present,addr64})
            5'b10000:
              begin
                ohc_dw_p.ohc_e1_dw0[31:0]  = (hdr_dw[3][7:4] == 4'b0001) ?  {hdr_dw[3][31:8],4'b1001,hdr_dw[3][3:0]} : 'd0;
              end
            5'b10001,5'b10010,5'b10100,5'b11000:
              begin
                ohc_dw_p.ohc_e1_dw0[31:0] = (hdr_dw[4][7:4] == 4'b0001) ?  {hdr_dw[4][31:8],4'b1001,hdr_dw[4][3:0]} : 'd0;
              end
            5'b10011,5'b10101,5'b11001,5'b10110,5'b11010,5'b11100:
              begin
                ohc_dw_p.ohc_e1_dw0[31:0] = (hdr_dw[5][7:4] == 4'b0001) ?  {hdr_dw[5][31:8],4'b1001,hdr_dw[5][3:0]} : 'd0;
              end
            5'b10111,5'b11011,5'b11101,5'b11110:
              begin
                ohc_dw_p.ohc_e1_dw0[31:0] = (hdr_dw[6][7:4] == 4'b0001) ?  {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;
              end
            5'b11111:
              begin
                ohc_dw_p.ohc_e1_dw0[31:0] = (hdr_dw[7][7:4] == 4'b0001) ?  {hdr_dw[7][31:8],4'b1001,hdr_dw[7][3:0]} : 'd0;
              end
            default:
              begin
                ohc_dw_p.ohc_e1_dw0[31:0] = 'd0;
              end
          endcase
        end //DECODE_PREFIX1
      end

      always_comb begin : DECODE

        ohc_dw_p.ohc_e2_dw0          = 'd0;
        ohc_dw_p.ohc_e2_dw1          = 'd0;

        if (rx_tlp.tlp.hdr.hv )
        begin
          case ({ohc_ex_present_p.ohc_e2_present,ohc_c_present,ohc_b_present,ohc_a_present,addr64})
            5'b10000:
              begin
                ohc_dw_p.ohc_e2_dw0 = (hdr_dw[3][7:4] == 4'b0001) ?  {hdr_dw[3][31:8],4'b1001,hdr_dw[3][3:0]} : 'd0;
                ohc_dw_p.ohc_e2_dw1 = (hdr_dw[4][7:4] == 4'b0001) ? {hdr_dw[4][31:8],4'b1001,hdr_dw[4][3:0]} : 'd0;

              end
            5'b10001,5'b10010,5'b10100,5'b11000:
              begin
                ohc_dw_p.ohc_e2_dw0 = (hdr_dw[4][7:4] == 4'b0001) ? {hdr_dw[4][31:8],4'b1001,hdr_dw[4][3:0]} : 'd0;
                ohc_dw_p.ohc_e2_dw1 = (hdr_dw[5][7:4] == 4'b0001) ? {hdr_dw[5][31:8],4'b1001,hdr_dw[5][3:0]} : 'd0;
              end
            5'b10011,5'b10101,5'b10110,5'b11001,5'b11010,5'b11100:
              begin
                ohc_dw_p.ohc_e2_dw0 = (hdr_dw[5][7:4] == 4'b0001) ? {hdr_dw[5][31:8],4'b1001,hdr_dw[5][3:0]} : 'd0;

                ohc_dw_p.ohc_e2_dw1 = (hdr_dw[6][7:4] == 4'b0001) ? {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;

              end
            5'b10111,5'b11101,5'b11110,5'b11011:
              begin
                ohc_dw_p.ohc_e2_dw0 = (hdr_dw[6][7:4] == 4'b0001) ? {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;

                ohc_dw_p.ohc_e2_dw1 = (hdr_dw[7][7:4] == 4'b0001) ? {hdr_dw[7][31:8],4'b1001,hdr_dw[7][3:0]} : 'd0;

              end
            5'b11111:
              begin
                ohc_dw_p.ohc_e2_dw0 = (hdr_dw[7][7:4] == 4'b0001) ? {hdr_dw[7][31:8],4'b1001,hdr_dw[7][3:0]} : 'd0;
                ohc_dw_p.ohc_e2_dw1 = (hdr_dw[8][7:4] == 4'b0001) ? {hdr_dw[8][31:8],4'b1001,hdr_dw[8][3:0]} : 'd0;
              end
            default:
              begin
                ohc_dw_p.ohc_e2_dw0 = 'd0;
                ohc_dw_p.ohc_e2_dw1 = 'd0;
              end
          endcase
        end //DECODE
      end



      always_comb begin : DECODE1
        ohc_dw_p.ohc_e4_dw0         = 'd0;
        ohc_dw_p.ohc_e4_dw1         = 'd0;
        ohc_dw_p.ohc_e4_dw2         = 'd0;
        ohc_dw_p.ohc_e4_dw3         = 'd0;

        if (rx_tlp.tlp.hdr.hv )
        begin
          case ({ohc_ex_present_p.ohc_e4_present,ohc_c_present,ohc_b_present,ohc_a_present,addr64})
            5'b10000:
              begin
                ohc_dw_p.ohc_e4_dw0 = (hdr_dw[3][7:4] == 4'b0001) ? {hdr_dw[3][31:8],4'b1001,hdr_dw[3][3:0]} : 'd0;

                ohc_dw_p.ohc_e4_dw1 = (hdr_dw[4][7:4] == 4'b0001) ? {hdr_dw[4][31:8],4'b1001,hdr_dw[4][3:0]} : 'd0;

                ohc_dw_p.ohc_e4_dw2 = (hdr_dw[5][7:4] == 4'b0001) ? {hdr_dw[5][31:8],4'b1001,hdr_dw[5][3:0]} : 'd0;

                ohc_dw_p.ohc_e4_dw3 = (hdr_dw[6][7:4] == 4'b0001) ? {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;

              end
            5'b10001,5'b10010,5'b10100,5'b11000:
              begin
                ohc_dw_p.ohc_e4_dw0 = (hdr_dw[4][7:4] == 4'b0001) ? {hdr_dw[4][31:8],4'b1001,hdr_dw[4][3:0]} : 'd0;
                ohc_dw_p.ohc_e4_dw1 = (hdr_dw[5][7:4] == 4'b0001) ? {hdr_dw[5][31:8],4'b1001,hdr_dw[5][3:0]} : 'd0;

                ohc_dw_p.ohc_e4_dw2 = (hdr_dw[6][7:4] == 4'b0001) ? {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;

                ohc_dw_p.ohc_e4_dw3 = (hdr_dw[7][7:4] == 4'b0001) ? {hdr_dw[7][31:8],4'b1001,hdr_dw[7][3:0]} : 'd0;

              end
            5'b10011,5'b10101,5'b11001,5'b10110,5'b11100,5'b11010:
              begin
                ohc_dw_p.ohc_e4_dw0 = (hdr_dw[5][7:4] == 4'b0001) ? {hdr_dw[5][31:8],4'b1001,hdr_dw[5][3:0]} : 'd0;
                ohc_dw_p.ohc_e4_dw1 = (hdr_dw[6][7:4] == 4'b0001) ? {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;
                ohc_dw_p.ohc_e4_dw2 = (hdr_dw[7][7:4] == 4'b0001) ? {hdr_dw[7][31:8],4'b1001,hdr_dw[7][3:0]} : 'd0;
                ohc_dw_p.ohc_e4_dw3 = (hdr_dw[8][7:4] == 4'b0001) ? {hdr_dw[8][31:8],4'b1001,hdr_dw[8][3:0]} : 'd0;
              end
            5'b10111,5'b11011,5'b11101,5'b11110:
              begin
                ohc_dw_p.ohc_e4_dw0 = (hdr_dw[6][7:4] == 4'b0001) ? {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;
                ohc_dw_p.ohc_e4_dw1 = (hdr_dw[7][7:4] == 4'b0001) ? {hdr_dw[7][31:8],4'b1001,hdr_dw[7][3:0]} : 'd0;
                ohc_dw_p.ohc_e4_dw2 = (hdr_dw[8][7:4] == 4'b0001) ? {hdr_dw[8][31:8],4'b1001,hdr_dw[8][3:0]} : 'd0;
                ohc_dw_p.ohc_e4_dw3 = (hdr_dw[9][7:4] == 4'b0001) ? {hdr_dw[9][31:8],4'b1001,hdr_dw[9][3:0]} : 'd0;
              end
            5'b11111:
              begin
                ohc_dw_p.ohc_e4_dw0 = (hdr_dw[7][7:4] == 4'b0001) ? {hdr_dw[7][31:8],4'b1001,hdr_dw[7][3:0]} : 'd0;
                ohc_dw_p.ohc_e4_dw1 = (hdr_dw[8][7:4] == 4'b0001) ? {hdr_dw[8][31:8],4'b1001,hdr_dw[8][3:0]} : 'd0;
                ohc_dw_p.ohc_e4_dw2 = (hdr_dw[9][7:4] == 4'b0001) ? {hdr_dw[9][31:8],4'b1001,hdr_dw[9][3:0]} : 'd0;
                ohc_dw_p.ohc_e4_dw3 = (hdr_dw[10][7:4] == 4'b0001) ? {hdr_dw[10][31:8],4'b1001,hdr_dw[10][3:0]} : 'd0;
              end
            default:
              begin
                ohc_dw_p.ohc_e4_dw0 = 'd0;
                ohc_dw_p.ohc_e4_dw1 = 'd0;
                ohc_dw_p.ohc_e4_dw2 = 'd0;
                ohc_dw_p.ohc_e4_dw3 = 'd0;
              end
          endcase
        end //DECODE1
      end


      assign  hdr_rsvd = 'd0;
    //-----------------------------------------------------------------------------------------
    //Following block forms header as per received TLP type. Header is formed as a NON-FLIT header 
    //from received non-flit header fields
    //-----------------------------------------------------------------------------------------
  assign s_tlp_is_fm_p_rsvd_routed_by_addr = '0;

  always_comb begin: HDR
    tmp_hdr = '0;
    // FM Reserved TLPs (Routed by 64-bit Address) 
    if (s_tlp_is_fm_p_rsvd_routed_by_addr) begin
      // Converted common Mem NFM Header
       tmp_hdr = { tlp_p.tlp_addr[31:0],tlp_p.tlp_addr[63:32], 
                   ohc_a_ldw_be[3:0], ohc_a_fdw_be[3:0], tlp_tag[0 +:8], tlp_p.tlp_rid[7:0], tlp_p.tlp_rid[15:8],
                   int_common_hdr};
    end else begin

      casez (fmt_type) // Converted NFM Type [6:0]
        `MWR32, `MWR64:
          begin
              case (addr64)
                1'b1:
                  tmp_hdr   = { tlp_p.tlp_addr[31:0],tlp_p.tlp_addr[63:32], 
                                ohc_a_ldw_be[3:0], ohc_a_fdw_be[3:0], tlp_tag[0 +:8], tlp_p.tlp_rid[7:0], tlp_p.tlp_rid[15:8],
                                int_common_hdr};
                1'b0: 
                  tmp_hdr   = { {(HW_NFT - 96){1'b0}}, tlp_addr_32[31:0], ohc_a_ldw_be[3:0], ohc_a_fdw_be[3:0], tlp_tag[0 +:8], tlp_p.tlp_rid[7:0], tlp_p.tlp_rid[15:8],
                                int_common_hdr};
                default:  
                  tmp_hdr   = 'd0;
              endcase
          end

        `MSG , `MSGD:  // msg with out data
          begin
              tmp_hdr       = {  tlp_p.tlp_addr[31:0],tlp_p.tlp_addr[63:32], tlp_p.tlp_msg_code,tlp_tag[0+:8], tlp_p.tlp_rid[7:0], tlp_p.tlp_rid[15:8],
                                int_common_hdr};
          end
        default:
          begin
            tmp_hdr   = { tlp_p.tlp_addr[31:0],tlp_p.tlp_addr[63:32], 
                          ohc_a_ldw_be[3:0], ohc_a_fdw_be[3:0], tlp_tag[0 +:8], tlp_p.tlp_rid[7:0], tlp_p.tlp_rid[15:8],
                          int_common_hdr};
          end
      endcase
    end
  end: HDR


    assign com_dw_len       = hdr_dw_len[9:0];



  // -------------------------------------------------------------------------------------------
  // Following logic assigns Header, prefix, segment and other information to respective fields 
  // As per FLIT or NON-FLIT mode of operation. 
  // Filter logic decodes NON-FLIT mode of header. This has done to keep previous filter logic as 
  // it is for decoding the header
  // -------------------------------------------------------------------------------------------

   assign hdr_dec_flt_p.hdr_dec_flt_hdr[HW_NFT-1:0]   = flit_mode ? tmp_hdr : hdr_to_flt_nfm; 
  assign hdr_dec_flt_cpltr_seg                        = flit_mode ? ohc_c_cpltr_segment : 'd0;
  assign hdr_dec_flt_dest_seg                         = flit_mode ? hdr_dec_flt_dest_seg_in : 'd0;
  assign hdr_dec_flt_reqtr_seg                        = flit_mode ? hdr_dec_flt_reqtr_seg_in : 'd0;
  assign tlp_tag_6bit_msg                             =  tlp_p.tlp_tag_14bit_in >> 8 ; // for messages (invalidate and VDMs only 6 bits are used (moving 6 bits to LSB) 
  assign tlp_tag_14bit                                = flit_mode ? (curnt_ismsg ?  {7'h00,tlp_byte6_bit6,tlp_tag_6bit_msg[5:0]} : tlp_p.tlp_tag_14bit_in ) : 'd0; // For Invalidate and VDMs byte6[6:0] is used for Tag/Vendor definitions 
  assign hdr_dec_flt_p.hdr_dec_flt_hdr_dwen           = 'd0;
  assign hdr_dec_flt_p.hdr_dec_flt_hv                 = rx_tlp.tlp.hdr.hv; 
  assign hdr_dec_flt_p.hdr_dec_flt_prfx[PRFX_WD-1:0]  = hdr_dec_flt_prfx;
    assign hdr_dec_flt_p.hdr_dec_flt_pasid_er_pmr_pv  = flit_mode ? hdr_dec_flt_pasid_er_pmr_pv_in : 'd0;
  assign hdr_dec_flt_p.hdr_dec_flt_prfx_dwen        = hdr_dec_flt_prfx_dwen;
  assign hdr_dec_ecrc_local_prfx_cnt                = hdr_dec_local_prfx_cnt_in;
  assign hdr_dec_ecrc_dwen                          = hdr_dec_flt_p.hdr_dec_flt_prfx_dwen;
  assign hdr_dec_ecrc_pfrx_dw_count                 = pfrx_dw_count_nfm_in;
  assign hdr_dec_flt_p.hdr_dec_np_req_type          = 'd0; 

  assign  hdr_dec_flt_p.radm_malf_tlp_err_hdr      = radm_malf_tlp_err_hdr;
  assign  hdr_dec_flt_p.radm_malf_tlp_err_hdr_prfx = radm_malf_tlp_err_hdr_prfx;
  assign  hdr_dec_flt_p.radm_malf_tlp_err_hdr_flit = radm_malf_tlp_err_hdr_flit;

  //----- Header Log Logic -----//
  always_comb begin
      log_rcvd_flds_i                                     = log_rcvd_flds ;
      log_rcvd_flds_i.hv_1                                = ohc_b_hv[1];

  end
  assign  hdr_dec_flt_p.log_rcvd_flds              = log_rcvd_flds_i ;
  //----------------------------//
endmodule

