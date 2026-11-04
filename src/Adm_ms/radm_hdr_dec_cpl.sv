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
// ---    $DateTime: 2023/12/06 00:52:40 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_hdr_dec_cpl.sv#6 $
// -------------------------------------------------------------------------
// Description: 
// This module is to form header as per mode of operation (FLIT mode or NON-FLIT mode)
// Each field from incoming header seperates as Posted TLP type and forms header as per the required 
// Header format in NON-FLIT mode before giving it to respective TLP filter type. 
// Required functions and structures are added in radm_ms_pkg.svh module. 
// ---------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_hdr_dec_cpl

  import radm_ms_pkg::RADM_HDR_PROT_WD;
  import radm_ms_pkg::NHW;
  import radm_ms_pkg::HW;
  import radm_ms_pkg::radm_rx_tlp_s;
  import radm_ms_pkg::HW_NFT;
  import radm_ms_pkg::HW_NFT_PAR;
  import radm_ms_pkg::PRFX_WD;
  import radm_ms_pkg::PRFX_WD_PAR;
  import radm_ms_pkg::radm_hdr_log_rcvd_flds_s ;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_decx_present_s;
  import radm_ms_pkg::radm_hdr_dec_flt_s;
  import radm_ms_pkg::radm_hdr_dec_com_tlp_s;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_dw_s;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_ex_present_s;

    import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
    import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
    import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD ;


    // parameter/localparam Declaration 
#(
    parameter RAS_DP_PROT_CHK_ID_BASE  = 0
)
  
                         (
    // Input/Output Declaration 

    input                           core_clk,
    input                           radm_clk_ug,
    input                           core_rst_n,

    input                           flit_mode,                    // If FLIT_MODE is enabled and physical layer detects flit mode, this signal asserts. If this signal is low controller works in NON-FLIT mode even of FLIT_MODE configuration is enabled.
    input  radm_rx_tlp_s            rx_tlp,                       // Received TLP struct, from OutQ/IDE, to filter
    input [NP_REQ_TX_TYPE_WD-1:0]   lut_flt_np_req_type,          // NP request type from LUT for CPL Filter
    output radm_hdr_dec_flt_s       hdr_dec_flt_cpl,              // Structured output to  filter CPL module
    output ras_dp_err_log_t                 ras_dp_err_log,
    input  ras_dp_err_inj_t                 ras_dp_err_inj ,  
    output [2:0]                    hdr_dec_ecrc_pfrx_dw_count,   // Total Prefix Count
    output [4-1:0]                  hdr_dec_ecrc_local_prfx_cnt,  // Local Prefix Count
    output [NHW-1:0]                hdr_dec_ecrc_dwen             // Local Prefix dwen tied to zero
  );
  localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
  localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
  localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
  localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;

    // Internal wire/reg  Declaration (in SV wire/reg is considered as loic declaration) 
  //
    logic  [NHW-1:0]                    hdr_dec_flt_prfx_dwen;
    logic  [4-1:0]                      hdr_dec_local_prfx_cnt_in;
    logic  [2:0]                        pfrx_dw_count_nfm_in;
    logic                               radm_malf_tlp_err_hdr;
    logic                               radm_malf_tlp_err_hdr_prfx;
    logic                               radm_malf_tlp_err_hdr_flit;
    logic                               sub_strem_id_seven;



    radm_hdr_log_rcvd_flds_s                    log_rcvd_flds, log_rcvd_flds_i ;
    /// COMMON
    logic                                       ide_ohc_c_err;
    logic                                       ide_prfx_vld;
    logic                                       ohc_ur_err_cpl;
          
    logic                                       tlp_ln;
    logic [HW_NFT-1:0]                          tmp_hdr;
          
    logic [9:0]                                 hdr_dw_len;
    logic [7:0]                                 ohc_c_pr_sent_cntr; 
    logic [7:0]                                 ohc_c_strm_in     ;
    logic [3:0]                                 ohc_c_sub_strm_id ;
    logic                                       ohc_c_t           ;
    logic                                       ohc_c_k           ;
    logic [22:0]                                ohc_c_info        ;
          
    logic [7 : 0]                               hdr_dec_flt_cpltr_seg;
    logic [8 : 0]                               hdr_dec_flt_dest_seg;
    logic [8 : 0]                               hdr_dec_flt_reqtr_seg;
    logic [14-1:0]                              tlp_tag_14bit;
    logic [6:0]                                 fmt_type;
    logic                                       addr64;
      logic                                     hdr_dec_flt_prfx_p_dwen;

      radm_hdr_dec_com_ohc_dw_s                 ohc_dw_cpl;        // Called in the form of structure
      radm_hdr_dec_com_ohc_ex_present_s         ohc_ex_present_cpl; // Called in the form of structure
    logic [22:0]                                hdr_dec_flt_pasid_er_pmr_pv_in; 
    logic [6:0]                                 tlp_addr_int;
    logic [7 : 0]                               ohc_c_reqtr_segment;
    logic                                       ohc_c_rsv;
    logic                                       ohc_a_dsv;
    logic [7 : 0]                               ohc_a_dest_segment;
    logic [7 : 0]                               ohc_a_cpl_segment;
    logic [2:0]                                 ohc_a_cpl_status;
    logic                                       ohc_c_present;
    radm_hdr_dec_com_ohc_decx_present_s         ohc_decx_present_cpl;
    

    logic                                       curnt_iscpl;
    // logic                                       flit_local_prfx_present;
    logic                                       ohc_a5_present;
    logic                                       ohc_a_present;
    logic [31:0]                                int_common_hdr;
    logic [14:0]                                hdr_rsvd;
    logic [NHW - 1:0][32 - 1:0]                 hdr_dw;
    logic [1:0]                                 ohc_tlp_addr; 
    logic                                       e_e_prfx_type4;
    logic [11:0]                                cpl_byte_cnt;
    logic                                       cpl_bcm;
    logic [7:0 ]                                ohc_c_cpltr_segment;
    logic [2:0]                                 local_prfx_fmt;
    logic [2:0]                                 e_e_prfx_fmt;
    logic                                       local_prfx_type4;
    logic [7:0]                                 local_prfx_decode;
    logic [3:0]                                 e2e_prfx_decode;
    logic [7:0]                                 pasid_decode;
    logic [8 : 0]                               hdr_dec_flt_dest_seg_in;
    logic [8 : 0]                               hdr_dec_flt_reqtr_seg_in;
    // logic tlp_cpl_ep;
    radm_hdr_dec_com_tlp_s                      tlp_cpl;
  logic [HW_NFT-1:0]                            hdr_to_flt_nfm;
    logic [PRFX_WD-1:0]                         hdr_dec_flt_prfx;
  ///////////////////////////////////////////////////////////
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
                .din      (hdr_dec_flt_cpl.hdr_dec_flt_hdr[HW_NFT-1:0] ),
                .din_prot ('0                  ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(hdr_dec_flt_cpl.hdr_dec_flt_hdr[HW_NFT+HW_NFT_PAR-1:HW_NFT]   ),
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
                .din      (hdr_dec_flt_cpl.hdr_dec_flt_prfx[PRFX_WD-1:0] ),
                .din_prot ('0                  ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(hdr_dec_flt_cpl.hdr_dec_flt_prfx[PRFX_WD+PRFX_WD_PAR-1:PRFX_WD]   ),
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
    .flit_mode                          (flit_mode              ),
    .core_clk                           (core_clk               ),
    .core_rst_n                         (core_rst_n             ),
    .rx_tlp_hdr                         (rx_tlp.tlp.hdr         ),
    .rx_tlp_eot                         (rx_tlp.tlp.ctl.eot     ),
    .hdr_to_flt_nfm                     (hdr_to_flt_nfm         ),
    .hdr_dec_flt_prfx_dwen              (hdr_dec_flt_prfx_dwen  ),
    .hdr_dec_local_prfx_cnt             (hdr_dec_local_prfx_cnt_in  ),
    .sub_strem_id_seven                 (sub_strem_id_seven  ),

    .radm_malf_tlp_err_hdr            (radm_malf_tlp_err_hdr),
    .radm_malf_tlp_err_hdr_prfx       (radm_malf_tlp_err_hdr_prfx),
    .radm_malf_tlp_err_hdr_flit       (radm_malf_tlp_err_hdr_flit),
    .pfrx_dw_count_nfm                  (pfrx_dw_count_nfm_in  )
      ,       
      .hdr_dec_flt_prfx                 (hdr_dec_flt_prfx)
      ,       
      .curnt_iscpl                      (curnt_iscpl            ),
      .curnt_ismsg                      (1'b0                   ),
      .curnt_is_cfg_io                  (1'b0                   ),
      .int_common_hdr                   (int_common_hdr         ),
      .hdr_dw                           (hdr_dw                 ),
      .log_rcvd_flds                    (log_rcvd_flds          ),
      .fmt_type                         (fmt_type               ),  
      .addr64                           (addr64                 ),
      .hdr_dw_len                       (hdr_dw_len             ),
      .ohc_decx_present                 (ohc_decx_present_cpl   ),
      .tlp_ats_vld                      (   ),
      .ide_prfx_vld                     (ide_prfx_vld          ),
      .tlp                              (tlp_cpl                ),
      .ohc_c_info                       (ohc_c_info             ),
       .ohc_b_hv                        (2'h0                   )
          ,
        .ohc_ex_present                 (ohc_ex_present_cpl     ),
        .ohc_ex_dw                      (ohc_dw_cpl             ),
       .st_15_8                       (8'h00           ),
       .ohc_b_av                      (1'b0            ),
       .ohc_b_ama                     (3'h0            ),
       .hdr_dec_flt_pasid_er_pmr_pv_in   (23'd0        )
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

    assign  hdr_dec_flt_cpl.hdr_dec_flt_c_d_r_14bit_t = {1'b0, ohc_ur_err_cpl,3'b0,8'h00,hdr_dec_flt_cpltr_seg,hdr_dec_flt_dest_seg,hdr_dec_flt_reqtr_seg,tlp_tag_14bit};
    assign cpl_byte_cnt                               = tlp_cpl.tlp_cpl_byte_count;
    assign cpl_bcm                                    = 1'b0; // Removed in FLIT mode 
    assign ohc_c_cpltr_segment                        = 'd0;

    assign curnt_iscpl                                = ((fmt_type  == `CPL)    || (fmt_type == `CPLD)  ||
                                                         (fmt_type  == `CPLLK)  || (fmt_type == `CPLDLK)); 

    assign ohc_a5_present                             =  ohc_decx_present_cpl.ohc_dec_a_present && curnt_iscpl;
    assign ohc_a_present                              = ohc_decx_present_cpl.ohc_dec_a_present && ( ohc_a5_present) ;
    assign ohc_c_present                              = ohc_decx_present_cpl.ohc_dec_c_present ;
    assign tlp_ln                                     = 1'b0; 
    assign hdr_dec_flt_pasid_er_pmr_pv_in             = 'd0;
    assign ohc_ur_err_cpl   = ide_ohc_c_err ;
    // form basic headers           
    // assign tlp_ep                                      = tlp_cpl_ep;
    assign hdr_dec_flt_dest_seg_in                    = {ohc_a_dsv,ohc_a_dest_segment};
    assign hdr_dec_flt_reqtr_seg_in                   = {ohc_c_rsv,ohc_c_reqtr_segment};

    ///////////////////////////////////////////////////////////////////////////////////////
    // Following block seperated OHC fields as per received OHC header
    //////////////////////////////////////////////////////////////////////////////////////

    always_comb begin : DECODE_OHC
      ohc_a_dsv                           = 1'b0;
      ohc_a_dest_segment[7:0]             = 'd0;
      ohc_a_cpl_segment                   = 'd0;
      ohc_a_cpl_status                    = 'd0;
      ohc_tlp_addr[1:0]                   = 'd0;    
        
      case ({ohc_a5_present,addr64})
        2'b10:
        begin
          ohc_a_dsv                       = hdr_dw[3][23];
          ohc_a_dest_segment[7:0]         = hdr_dw[3][7:0];
          ohc_a_cpl_segment               = hdr_dw[3][15:8];
          ohc_a_cpl_status                = hdr_dw[3][26:24];
          ohc_tlp_addr[1:0]               = hdr_dw[3][28:27];
        end
        2'b11:
        begin
          ohc_a_dsv                       = hdr_dw[4][23];
          ohc_a_dest_segment[7:0]         = hdr_dw[4][7:0];
          ohc_a_cpl_segment               = hdr_dw[4][15:8];
          ohc_a_cpl_status                = hdr_dw[4][26:24];
          ohc_tlp_addr[1:0]               = hdr_dw[4][28:27];
        end
        default:
        begin
          ohc_a_dsv                       = 'd0;
          ohc_a_dest_segment[7:0]         = 'd0;
          ohc_a_cpl_segment               = 'd0;
          ohc_a_cpl_status                = 'd0;
          ohc_tlp_addr[1:0]               = 'd0;
        end
      endcase
    end //DECODE_OHC

assign ohc_c_info = {ohc_c_present,ohc_c_pr_sent_cntr,ohc_c_strm_in,ohc_c_sub_strm_id,ohc_c_t,ohc_c_k};

    always_comb begin : DECODE_PASID_2
      ohc_c_reqtr_segment                 = 'd0;
      ohc_c_pr_sent_cntr                  = 'd0;
      ohc_c_strm_in                       = 'd0;
      ohc_c_sub_strm_id                   = 'd0;
      ohc_c_t                             = 'd0;
      ohc_c_k                             = 'd0;
      ohc_c_rsv                           = 'd0;
      
      if (rx_tlp.tlp.hdr.hv)
      begin
        case ({ohc_c_present,ohc_a_present,addr64})
          3'b111:
          begin
            ohc_c_reqtr_segment           = hdr_dw[5][7:0];
            ohc_c_pr_sent_cntr            = hdr_dw[5][15:8];
            ohc_c_strm_in                 = hdr_dw[5][23:16];
            ohc_c_sub_strm_id             = hdr_dw[5][31:28];
            ohc_c_t                       = hdr_dw[5][24];
            ohc_c_k                       = hdr_dw[5][25];
            ohc_c_rsv                     = hdr_dw[5][27];
          end
          3'b110,3'b101:
          begin
            ohc_c_reqtr_segment           = hdr_dw[4][7:0];
            ohc_c_pr_sent_cntr            = hdr_dw[4][15:8];
            ohc_c_strm_in                 = hdr_dw[4][23:16];
            ohc_c_sub_strm_id             = hdr_dw[4][31:28];
            ohc_c_t                       = hdr_dw[4][24];
            ohc_c_k                       = hdr_dw[4][25];
            ohc_c_rsv                     = hdr_dw[4][27];
          end
          3'b100:
          begin
            ohc_c_reqtr_segment           = hdr_dw[3][7:0];
            ohc_c_pr_sent_cntr            = hdr_dw[3][15:8];
            ohc_c_strm_in                 = hdr_dw[3][23:16];
            ohc_c_sub_strm_id             = hdr_dw[3][31:28];
            ohc_c_t                       = hdr_dw[3][24];
            ohc_c_k                       = hdr_dw[3][25];
            ohc_c_rsv                     = hdr_dw[3][27];
          end
          default:
          begin
            ohc_c_reqtr_segment           = 'd0;
            ohc_c_pr_sent_cntr            = 'd0;
            ohc_c_strm_in                 = 'd0;
            ohc_c_sub_strm_id             = 'd0;
            ohc_c_t                       = 'd0;
            ohc_c_k                       = 'd0;
            ohc_c_rsv                     = 'd0;
          end
        endcase
      end //DECODE_PASID_2
    end


      assign  local_prfx_fmt              = 3'b100;
      assign  local_prfx_type4            = 1'b0;
      assign  local_prfx_decode           = {local_prfx_fmt, local_prfx_type4, 4'b0000};
      assign  e2e_prfx_decode             = {local_prfx_fmt, e_e_prfx_type4};
      assign  e_e_prfx_fmt                = 3'b100;
      assign  e_e_prfx_type4              = 1'b1;
      assign  pasid_decode                = {e_e_prfx_fmt, e_e_prfx_type4, 4'b0001};
      assign  hdr_dec_flt_prfx_p_dwen     = 'd0;

      always_comb begin : DECODE_PREFIX1
         ohc_dw_cpl.ohc_e1_dw0                    = 'd0;
          
        if (rx_tlp.tlp.hdr.hv )
        begin
          case ({ohc_ex_present_cpl.ohc_e1_present,ohc_c_present,ohc_a_present,addr64})
            4'b1000:
            begin
              ohc_dw_cpl.ohc_e1_dw0[31:0]         = (hdr_dw[3][7:4] == 4'b0001) ?  {hdr_dw[3][31:8],4'b1001,hdr_dw[3][3:0]} : 'd0;
            end       
            4'b1001,4'b1010,4'b1100:        
            begin       
              ohc_dw_cpl.ohc_e1_dw0[31:0]         = (hdr_dw[4][7:4] == 4'b0001) ?  {hdr_dw[4][31:8],4'b1001,hdr_dw[4][3:0]} : 'd0;
            end       
            4'b1011,4'b1101,4'b1110:        
            begin       
              ohc_dw_cpl.ohc_e1_dw0[31:0]         = (hdr_dw[5][7:4] == 4'b0001) ?  {hdr_dw[5][31:8],4'b1001,hdr_dw[5][3:0]} : 'd0;
            end       
            4'b1111:        
            begin       
              ohc_dw_cpl.ohc_e1_dw0[31:0]         = (hdr_dw[6][7:4] == 4'b0001) ?  {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;
            end       
            default:        
            begin       
              ohc_dw_cpl.ohc_e1_dw0[31:0]         = 'd0;
            end
          endcase
        end //DECODE_PREFIX1
      end

      always_comb begin : DECODE

        ohc_dw_cpl.ohc_e2_dw0               = 'd0;
        ohc_dw_cpl.ohc_e2_dw1               = 'd0; 

        if (rx_tlp.tlp.hdr.hv )
        begin
          case ({ohc_ex_present_cpl.ohc_e2_present,ohc_c_present,ohc_a_present,addr64})
            4'b1000:
            begin
              ohc_dw_cpl.ohc_e2_dw0         = (hdr_dw[3][7:4] == 4'b0001) ?  {hdr_dw[3][31:8],4'b1001,hdr_dw[3][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e2_dw1         = (hdr_dw[4][7:4] == 4'b0001) ? {hdr_dw[4][31:8],4'b1001,hdr_dw[4][3:0]} : 'd0;
            end       
            4'b1001,4'b1010,4'b1100:        
            begin       
              ohc_dw_cpl.ohc_e2_dw0         = (hdr_dw[4][7:4] == 4'b0001) ? {hdr_dw[4][31:8],4'b1001,hdr_dw[4][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e2_dw1         = (hdr_dw[5][7:4] == 4'b0001) ? {hdr_dw[5][31:8],4'b1001,hdr_dw[5][3:0]} : 'd0;
            end       
            4'b1011,4'b1101,4'b1110:        
            begin       
              ohc_dw_cpl.ohc_e2_dw0         = (hdr_dw[5][7:4] == 4'b0001) ? {hdr_dw[5][31:8],4'b1001,hdr_dw[5][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e2_dw1         = (hdr_dw[6][7:4] == 4'b0001) ? {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;
            end       
            4'b1111:        
            begin       
              ohc_dw_cpl.ohc_e2_dw0         = (hdr_dw[6][7:4] == 4'b0001) ? {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e2_dw1         = (hdr_dw[7][7:4] == 4'b0001) ? {hdr_dw[7][31:8],4'b1001,hdr_dw[7][3:0]} : 'd0;
            end       
            default:        
            begin       
              ohc_dw_cpl.ohc_e2_dw0         = 'd0;
              ohc_dw_cpl.ohc_e2_dw1         = 'd0;
            end
          endcase
        end //DECODE
      end



      always_comb begin : DECODE1
        ohc_dw_cpl.ohc_e4_dw0       = 'd0;
        ohc_dw_cpl.ohc_e4_dw1       = 'd0;
        ohc_dw_cpl.ohc_e4_dw2       = 'd0;
        ohc_dw_cpl.ohc_e4_dw3       = 'd0;

        if (rx_tlp.tlp.hdr.hv )
        begin
          case ({ohc_ex_present_cpl.ohc_e4_present,ohc_c_present,ohc_a_present,addr64})
            4'b1000:
            begin
              ohc_dw_cpl.ohc_e4_dw0 = (hdr_dw[3][7:4] == 4'b0001) ? {hdr_dw[3][31:8],4'b1001,hdr_dw[3][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e4_dw1 = (hdr_dw[4][7:4] == 4'b0001) ? {hdr_dw[4][31:8],4'b1001,hdr_dw[4][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e4_dw2 = (hdr_dw[5][7:4] == 4'b0001) ? {hdr_dw[5][31:8],4'b1001,hdr_dw[5][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e4_dw3 = (hdr_dw[6][7:4] == 4'b0001) ? {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;
            end
            4'b1001,4'b1010,4'b1100:
            begin
              ohc_dw_cpl.ohc_e4_dw0 = (hdr_dw[4][7:4] == 4'b0001) ? {hdr_dw[4][31:8],4'b1001,hdr_dw[4][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e4_dw1 = (hdr_dw[5][7:4] == 4'b0001) ? {hdr_dw[5][31:8],4'b1001,hdr_dw[5][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e4_dw2 = (hdr_dw[6][7:4] == 4'b0001) ? {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e4_dw3 = (hdr_dw[7][7:4] == 4'b0001) ? {hdr_dw[7][31:8],4'b1001,hdr_dw[7][3:0]} : 'd0;
            end
            4'b1011,4'b1101,4'b1110:
            begin
              ohc_dw_cpl.ohc_e4_dw0 = (hdr_dw[5][7:4] == 4'b0001) ? {hdr_dw[5][31:8],4'b1001,hdr_dw[5][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e4_dw1 = (hdr_dw[6][7:4] == 4'b0001) ? {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e4_dw2 = (hdr_dw[7][7:4] == 4'b0001) ? {hdr_dw[7][31:8],4'b1001,hdr_dw[7][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e4_dw3 = (hdr_dw[8][7:4] == 4'b0001) ? {hdr_dw[8][31:8],4'b1001,hdr_dw[8][3:0]} : 'd0;
            end
            4'b1111:
            begin
              ohc_dw_cpl.ohc_e4_dw0 = (hdr_dw[6][7:4] == 4'b0001) ? {hdr_dw[6][31:8],4'b1001,hdr_dw[6][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e4_dw1 = (hdr_dw[7][7:4] == 4'b0001) ? {hdr_dw[7][31:8],4'b1001,hdr_dw[7][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e4_dw2 = (hdr_dw[8][7:4] == 4'b0001) ? {hdr_dw[8][31:8],4'b1001,hdr_dw[8][3:0]} : 'd0;
              ohc_dw_cpl.ohc_e4_dw3 = (hdr_dw[9][7:4] == 4'b0001) ? {hdr_dw[9][31:8],4'b1001,hdr_dw[9][3:0]} : 'd0;
            end
            default:
            begin
              ohc_dw_cpl.ohc_e4_dw0 = 'd0;
              ohc_dw_cpl.ohc_e4_dw1 = 'd0;
              ohc_dw_cpl.ohc_e4_dw2 = 'd0;
              ohc_dw_cpl.ohc_e4_dw3 = 'd0;
            end
          endcase
        end //DECODE1
      end

    assign  hdr_rsvd              = 'd0;
    assign tlp_addr_int             = {tlp_cpl.tlp_cpl_la_addr[4:0],ohc_tlp_addr};
    
    //-----------------------------------------------------------------------------------------
    //Following block forms header as per received TLP type. Header is formed as a NON-FLIT header 
    //from receibed non-flit header fields
    //-----------------------------------------------------------------------------------------

    always_comb begin: HDR1

      tmp_hdr = 'd0;
      casez (fmt_type)

        `CPL, `CPLLK, `CPLD, `CPLDLK:
        begin
          tmp_hdr                   =  { {(HW_NFT - 96){1'b0}},
                                         hdr_rsvd[7], tlp_addr_int[6:0], tlp_cpl.tlp_tag[0+:8], tlp_cpl.tlp_cpl_dest_id[7:0],
                                         tlp_cpl.tlp_cpl_dest_id[15:8],cpl_byte_cnt[7:0], ohc_a_cpl_status, cpl_bcm,
                                         cpl_byte_cnt[11:8], tlp_cpl.tlp_rid[7:0], tlp_cpl.tlp_rid[15:8],
                                         int_common_hdr};
        end

        default:
        begin
            tmp_hdr   = {{(HW_NFT - 32){1'b0}},int_common_hdr}; 
        end
      endcase
    end



  // -------------------------------------------------------------------------------------------
  // Following logic assigns Header, prefix, segment and other information to respective fields 
  // As per FLIT or NON-FLIT mode of operation. 
  // Filter logic decodes NON-FLIT mode of header. This has done to keep previous filter logic as 
  // it is for decoding the header
  // -------------------------------------------------------------------------------------------

  assign hdr_dec_flt_cpl.hdr_dec_flt_hdr[HW_NFT-1:0]    = flit_mode ? tmp_hdr :
                                                            hdr_to_flt_nfm;
  assign hdr_dec_flt_cpltr_seg                          = flit_mode ? ohc_a_cpl_segment :
                                                          'd0;
  assign hdr_dec_flt_dest_seg                           = flit_mode ? hdr_dec_flt_dest_seg_in :
                                                          'd0;
  assign hdr_dec_flt_reqtr_seg                          = flit_mode ? hdr_dec_flt_reqtr_seg_in : 
                                                          'd0;
  assign tlp_tag_14bit                                  = flit_mode ? tlp_cpl.tlp_tag_14bit_in : 
                                                          'd0;
  assign hdr_dec_flt_cpl.hdr_dec_flt_hdr_dwen           = 'd0;
  assign hdr_dec_flt_cpl.hdr_dec_flt_hv                 = rx_tlp.tlp.hdr.hv; 
  assign hdr_dec_flt_cpl.hdr_dec_flt_prfx[PRFX_WD-1:0] = hdr_dec_flt_prfx;
  assign hdr_dec_flt_cpl.hdr_dec_flt_pasid_er_pmr_pv  = flit_mode ? hdr_dec_flt_pasid_er_pmr_pv_in : 'd0;
    assign hdr_dec_flt_cpl.hdr_dec_flt_prfx_dwen        = hdr_dec_flt_prfx_dwen;
    assign hdr_dec_ecrc_local_prfx_cnt                  = hdr_dec_local_prfx_cnt_in;
    assign hdr_dec_ecrc_dwen                            = hdr_dec_flt_cpl.hdr_dec_flt_prfx_dwen;
    assign hdr_dec_ecrc_pfrx_dw_count                   = pfrx_dw_count_nfm_in;
    
    assign hdr_dec_flt_cpl.hdr_dec_np_req_type          = lut_flt_np_req_type; 

  assign  hdr_dec_flt_cpl.radm_malf_tlp_err_hdr      = radm_malf_tlp_err_hdr;
  assign  hdr_dec_flt_cpl.radm_malf_tlp_err_hdr_prfx = radm_malf_tlp_err_hdr_prfx;
  assign  hdr_dec_flt_cpl.radm_malf_tlp_err_hdr_flit = radm_malf_tlp_err_hdr_flit;

  //----- Header Log Logic -----//
  always_comb begin
      log_rcvd_flds_i                                     = log_rcvd_flds ;
      log_rcvd_flds_i.hv_1                                = '0 ;
  end
  assign  hdr_dec_flt_cpl.log_rcvd_flds              = log_rcvd_flds_i ;
  //----------------------------//

endmodule

