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
// ---    $DateTime: 2023/12/08 02:00:35 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_hdr_dec_common.sv#8 $
// -------------------------------------------------------------------------
// Decription: 
// This modules does First Dword decoding of all TLP types in Flit mode and NON-Flit mode.
// Depends on Flit mode and Non-flit mode, different fields from first Dword of incoming TLP decodes and forms 
// First Dword in the form of NON-FLIT mode format before sending it to respetive TLP type decoder module.
// This modules instantiates in P,NP and CPL TLP decoder module.
//--------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/pcie_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_hdr_dec_common
  import pcie_pkg::decoded_tlp_type_s;
  import pcie_pkg::f_decode_tlp_type;
  import pcie_pkg::f_decode_ohc_len ;
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NW_PRFX;
  import DWC_pcie_ctl_pkg::NPRFX;
  import radm_ms_pkg::NHW;
  import radm_ms_pkg::HW;
  import radm_ms_pkg::HW_NFT;
  import radm_ms_pkg::radm_tlp_hdr_s;
  import radm_ms_pkg::radm_hdr_log_rcvd_flds_s ;
  import radm_ms_pkg::PRFX_WD;
  import radm_ms_pkg::TLP_FMT_WD;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_decx_present_s;
  import radm_ms_pkg::radm_hdr_dec_com_tlp_s;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_dw_s;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_ex_present_s;

// Local paramter declaration
  #(
  )

// Inout/Output  declaration
  
                            (   
    input                                           flit_mode,
    input                                           core_clk,
    input                                           core_rst_n,
    input  radm_tlp_hdr_s                           rx_tlp_hdr,                   // Received TLP Header struct from OutQ/IDE
    input                                           rx_tlp_eot,                   // Received TLP EOT           from OutQ/IDE
    output logic [HW_NFT-1:0]                       hdr_to_flt_nfm,
    output logic [NHW-1:0]                          hdr_dec_flt_prfx_dwen,
    output logic [4-1:0]                            hdr_dec_local_prfx_cnt,
    output logic                                    sub_strem_id_seven,
    output                                          radm_malf_tlp_err_hdr,
    output                                          radm_malf_tlp_err_hdr_prfx,
    output                                          radm_malf_tlp_err_hdr_flit,
    output logic [2 :0]                             pfrx_dw_count_nfm
    ,                 
    output logic [PRFX_WD-1:0]                      hdr_dec_flt_prfx
      ,           
      output logic [NHW-1:0][32-1:0]                hdr_dw,
      output radm_hdr_log_rcvd_flds_s               log_rcvd_flds,
      input                                         curnt_iscpl,
      input                                         curnt_ismsg,
      input                                         curnt_is_cfg_io,
      output logic [31:0]                           int_common_hdr,
      output logic [6:0]                            fmt_type,  
      output logic                                  addr64,
      output logic [9:0]                            hdr_dw_len,
      input  logic [22:0]                           ohc_c_info,
      output  radm_hdr_dec_com_tlp_s                tlp,
      output radm_hdr_dec_com_ohc_decx_present_s    ohc_decx_present,
      output logic                                  tlp_ats_vld,
      input                                         ide_prfx_vld,
       input  logic [1:0] ohc_b_hv
        , 
        input  radm_hdr_dec_com_ohc_dw_s            ohc_ex_dw,
        output radm_hdr_dec_com_ohc_ex_present_s    ohc_ex_present,
        input  logic [7:0] st_15_8,
        input  logic [2:0] ohc_b_ama,
        input  logic ohc_b_av,
        input  logic [22:0] hdr_dec_flt_pasid_er_pmr_pv_in
  );

  /// COMMON

  logic                                 tlp_cpl_ep; 
  logic                                 tlp_ln;
  logic [TLP_FMT_WD-1:0]                tlp_fmt;
  logic [5-1:0]                         int_tlp_type;
  logic                                 tlp_ep;
  logic [2:0]                           tlp_attr;                           
  logic [(HW) - 1 : 0]                  hdr_to_flt_fm;
  logic [HW-1:0]                        hdr_to_flt_nfm_in;
  logic                                 stop_prfx_dec_flit;
  logic [HW-1:0]                        hdr_to_flt_nfm_r;
  logic [4-1:0]                        hdr_dw_cnt_fm,hdr_dw_cnt_nfm;
  logic [NHW-1:0]                       is_tlp_local_prfx;
  logic [NHW-1:0]                       prfx_type_rsrvd;
  logic [NPRFX-1 :0]                    pfrx_dw_count_fm_in;
  logic [3 :0]                          pfrx_dw_count_fm;
  logic [3 :0]                          pfrx_credit_rm_dw_count_fm;
  logic [3 :0]                          local_pfrx_dw_count_nfm;
  logic [(HW) - 1 : 0]                  hdr_to_flt_fm_prfx;
    logic [PRFX_WD-1:0]                 flit_mode_prfx;
    logic [PRFX_WD-1:0]                 flit_mode_prfx_r;
    logic [PRFX_WD-1:0]                 flit_local_pfrx;
    logic [(32*NHW)-1:0]                 flit_local_pfrx_in;
    // TLP Uses Dedicated Credits – 15th bit when Set indicates that the associated TLP must be handled using dedicated flow control credits
    assign  flit_local_pfrx            = ((flit_local_pfrx_in[7:0] == 8'h8d)) ? flit_local_pfrx_in[PRFX_WD+32-1:32] : flit_local_pfrx_in[PRFX_WD-1:0];
    assign  pfrx_credit_rm_dw_count_fm = ((flit_local_pfrx_in[7:0] == 8'h8d)) ? pfrx_dw_count_fm - 1 : pfrx_dw_count_fm;
    logic                               ohc_dec_e1_present;
    logic                               ohc_dec_e2_present;
    logic                               ohc_dec_e4_present;
    logic                               ohc_e_present;
    logic                               flit_local_prfx_present;
    logic [PRFX_WD-1:0]                 radm_xtract_radm_prfx_nfm; 
    logic [32*(NW_PRFX + 4)-1:0]        radm_xtract_radm_prfx_nfm_in; 
    logic [32*(NW_PRFX + 4)-1:0]        radm_xtract_radm_prfx_nfm_r; 
    assign  radm_xtract_radm_prfx_nfm    =  radm_xtract_radm_prfx_nfm_in[PRFX_WD-1:0];
  logic [2:0]                           tlp_tc;                           
  logic [1:0]                           tlp_ats;
  logic  [4:0]                          tlp_ohc;
  logic [9:0]                           com_dw_len;
  logic                                 hdr_th;
  logic [14:0]                          hdr_rsvd;
  logic [2:0]                           local_prfx_fmt;
  logic [2:0]                           e_e_prfx_fmt;
  logic                                 local_prfx_type4;
  logic [3:0]                           local_prfx_decode;
  logic [3:0]                           e2e_prfx_decode;
  logic [7:0]                           pasid_decode;
  logic [7:0]                           ideprfx_decode;
  logic                                 tlp_cpl_la_6; 
  logic [3:0]                           tlp_cpl_la_5_2; 
  logic                                 tlp_td;
  logic [NHW-1:0]                       radm_flt_hdr_ecrc_wen;
  logic [NHW-1:0]                       radm_nft_hdr_ecrc_wen;

      logic [7:0]   ohc_c_pr_sent_cntr; 
      logic [7:0]   ohc_c_strm_in     ;
      logic [3:0]   ohc_c_sub_strm_id ;
      logic         ohc_c_t           ;
      logic         ohc_c_k           ;
      logic         ohc_c_present     ;
      logic         ohc_c_p ;
      logic         ohc_c_m ;
      logic [6:0]  fmt_type_temp;

    assign tlp.tlp_type         = (flit_mode && ({tlp_fmt[1:0],int_tlp_type} == `FLIT_MRD32))  ? 5'b00000  : int_tlp_type;
    assign fmt_type_temp        = {tlp_fmt[1:0], tlp.tlp_type};
     assign  fmt_type           = fmt_type_temp; 
    assign addr64                       = (tlp_fmt[1:0] == 2'b01) || (tlp_fmt[1:0] == 2'b11);
    assign tlp.tlp_has_pyld             = fmt_type[6];
    assign  local_prfx_fmt            = 3'b100;
    assign  local_prfx_type4          = 1'b0;
    assign  local_prfx_decode         = {local_prfx_fmt, local_prfx_type4 };


      logic                             e_e_prfx_type4;
      logic  [7:0]                      tph_prfx_decode;

      assign  e2e_prfx_decode           = {local_prfx_fmt, e_e_prfx_type4};
      assign  tph_prfx_decode           = {e_e_prfx_fmt, e_e_prfx_type4, 4'b0000}; 

     // TPH prefix   
      assign tph_prfx_vld =   ohc_decx_present.ohc_dec_b_present && (&ohc_b_hv | ohc_b_av);



      assign  e_e_prfx_fmt              = 3'b100;
      assign  e_e_prfx_type4            = 1'b1;
      assign  pasid_decode              = {e_e_prfx_fmt, e_e_prfx_type4, 4'b0001};
      assign  ideprfx_decode            = {e_e_prfx_fmt,e_e_prfx_type4, 4'b0010};
    logic [19:0]                          ohc_a_pasid;
    logic                                 ohc_a_er;
    logic                                 ohc_a_pmr;
    logic                                 ohc_a_pv;
    logic                                 pasid_prfx_vld;                               
 

      logic  [31:0] tph_prfx;
      logic  [31:0] pasid_prfx;
      logic  [31:0] ide_prfx;
      logic  [7:0] st_15_8_in;

      assign  {ohc_a_pasid,ohc_a_er,ohc_a_pmr,ohc_a_pv} = hdr_dec_flt_pasid_er_pmr_pv_in;
      assign pasid_prfx_vld  =  ohc_decx_present.ohc_dec_a_present && ohc_a_pv;

      assign {ohc_c_present,ohc_c_pr_sent_cntr,ohc_c_strm_in,ohc_c_sub_strm_id,ohc_c_t,ohc_c_k} = ohc_c_info;

      assign ohc_c_m         = ohc_c_present & ((hdr_dw[0][21] & !hdr_dw[0][22] & hdr_dw[0][23]) || ohc_c_p);  
      assign ohc_c_p         = ohc_c_present & !hdr_dw[0][21] & hdr_dw[0][22] & hdr_dw[0][23];
      assign  st_15_8_in      =  &ohc_b_hv ? st_15_8 : 'd0;
      assign  tph_prfx        = {8'h00,ohc_b_ama,ohc_b_av,4'h0,st_15_8_in,e_e_prfx_fmt, e_e_prfx_type4, 4'b0000};
      assign  pasid_prfx      = {ohc_a_pasid[7:0],ohc_a_pasid[15:8],ohc_a_pmr,ohc_a_er,2'b00,ohc_a_pasid[19:16],pasid_decode};
      assign  ide_prfx      = 32'd0;


      assign flit_local_prfx_present    = |pfrx_credit_rm_dw_count_fm;
      assign ohc_e_present              = ohc_ex_present.ohc_e1_present | ohc_ex_present.ohc_e2_present | ohc_ex_present.ohc_e4_present;

      //////////////////////////////////////////////////////////////////////////////////////////////
      //
      // Following block forms FLIT mode prefixes received in different HDR DWORDS. 
      //////////////////////////////////////////////////////////////////////////////////////////////

      always_comb begin : FLIT_PRFX
        flit_mode_prfx                = flit_mode_prfx_r; 

        case ({rx_tlp_hdr.hv,ide_prfx_vld, pasid_prfx_vld,tph_prfx_vld,ohc_e_present,flit_local_prfx_present})
          6'b100000:
            begin
              flit_mode_prfx          = 'd0;
            end         
          6'b100001:          
            begin         
              flit_mode_prfx          = PRFX_WD'(flit_local_pfrx);
            end
          6'b100010:
            begin
              if (ohc_ex_present.ohc_e1_present)
                flit_mode_prfx        = PRFX_WD'(ohc_ex_dw.ohc_e1_dw0);
              else if (ohc_ex_present.ohc_e2_present)
                flit_mode_prfx        = PRFX_WD'({ohc_ex_dw.ohc_e2_dw1,ohc_ex_dw.ohc_e2_dw0});
            end
          6'b100011:
            begin
              if (ohc_ex_present.ohc_e1_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                   4'd1:flit_mode_prfx          = PRFX_WD'({ohc_ex_dw.ohc_e1_dw0,flit_local_pfrx[31:0]});
                   4'd2:flit_mode_prfx          = PRFX_WD'({ohc_ex_dw.ohc_e1_dw0,flit_local_pfrx[63:0]});
                 default: flit_mode_prfx        = 'd0;
               endcase
              end
              else if (ohc_ex_present.ohc_e2_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                   4'd1:flit_mode_prfx          = PRFX_WD'({ohc_ex_dw.ohc_e2_dw1,ohc_ex_dw.ohc_e2_dw0,flit_local_pfrx[31:0]});
               default: flit_mode_prfx        = 'd0;
              endcase
             end
              else if (ohc_ex_present.ohc_e4_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
              default: flit_mode_prfx        = 'd0;
             endcase
            end
            end
           6'b100100:
            begin         
              flit_mode_prfx          =    PRFX_WD'(tph_prfx);
            end
          6'b100101:          
            begin         
             case (pfrx_credit_rm_dw_count_fm)
                 4'd1:flit_mode_prfx          = PRFX_WD'({tph_prfx,flit_local_pfrx[31:0]});
                 4'd2:flit_mode_prfx          = PRFX_WD'({tph_prfx,flit_local_pfrx[63:0]});
                default:flit_mode_prfx          = 'd0;
             endcase
            end
           6'b100110:
            begin         
              if (ohc_ex_present.ohc_e1_present)
                flit_mode_prfx          =    PRFX_WD'({tph_prfx,ohc_ex_dw.ohc_e1_dw0});
              if (ohc_ex_present.ohc_e2_present)
                flit_mode_prfx          =    PRFX_WD'({tph_prfx,ohc_ex_dw.ohc_e2_dw1,ohc_ex_dw.ohc_e2_dw0});
            end
           6'b100111:
            begin
              if (ohc_ex_present.ohc_e1_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                   4'd1:flit_mode_prfx          = PRFX_WD'({tph_prfx,ohc_ex_dw.ohc_e1_dw0,flit_local_pfrx[31:0]});
                  default: flit_mode_prfx        = 'd0;
              endcase
              end
              else if (ohc_ex_present.ohc_e2_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                default: flit_mode_prfx        = 'd0;
              endcase
             end
              else if (ohc_ex_present.ohc_e4_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                  default: flit_mode_prfx        = 'd0;
             endcase
            end
           end
           6'b101000:
            begin         
              flit_mode_prfx          =    PRFX_WD'(pasid_prfx);
            end
           6'b101001:
            begin         
               case (pfrx_credit_rm_dw_count_fm)
                   4'd1:flit_mode_prfx          = PRFX_WD'({pasid_prfx,flit_local_pfrx[31:0]});
                   4'd2:flit_mode_prfx          = PRFX_WD'({pasid_prfx,flit_local_pfrx[63:0]});
                  default: flit_mode_prfx        = 'd0;
              endcase
            end
           6'b101010:
              if (ohc_ex_present.ohc_e1_present)
              begin
                 flit_mode_prfx          = PRFX_WD'({pasid_prfx,ohc_ex_dw.ohc_e1_dw0});
              end
              else if (ohc_ex_present.ohc_e2_present)
              begin
                 flit_mode_prfx          = PRFX_WD'({pasid_prfx,ohc_ex_dw.ohc_e2_dw1,ohc_ex_dw.ohc_e2_dw0});
              end
              else if (ohc_ex_present.ohc_e4_present)
              begin
              end
           6'b101011:
            begin         
              if (ohc_ex_present.ohc_e1_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                   4'd1:flit_mode_prfx          = PRFX_WD'({pasid_prfx,ohc_ex_dw.ohc_e1_dw0,flit_local_pfrx[31:0]});
                 default: flit_mode_prfx        = 'd0;
               endcase
              end
              else if (ohc_ex_present.ohc_e2_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                 default: flit_mode_prfx        = 'd0;
               endcase
             end
              else if (ohc_ex_present.ohc_e4_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
              default: flit_mode_prfx        = 'd0;
             endcase
            end
            end
           6'b101100:
            begin         
              flit_mode_prfx          =    PRFX_WD'({pasid_prfx,tph_prfx});
            end
           6'b101101:
            begin         
             case (pfrx_credit_rm_dw_count_fm)
                 4'd1:flit_mode_prfx          = PRFX_WD'({pasid_prfx,tph_prfx,flit_local_pfrx[31:0]});
                default:flit_mode_prfx          = 'd0;
             endcase
            end
           6'b101110:
            begin         
              if (ohc_ex_present.ohc_e1_present)
                flit_mode_prfx          =    PRFX_WD'({pasid_prfx,tph_prfx,ohc_ex_dw.ohc_e1_dw0});
            end

           6'b101111:
            begin         
              if (ohc_ex_present.ohc_e1_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                 default: flit_mode_prfx        = 'd0;
               endcase
              end
              else if (ohc_ex_present.ohc_e2_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                  default: flit_mode_prfx        = 'd0;
               endcase
             end
              else if (ohc_ex_present.ohc_e4_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
               default: flit_mode_prfx        = 'd0;
             endcase
            end
            end
          6'b110000:          
            begin         
              flit_mode_prfx          = PRFX_WD'(ide_prfx);
            end
          6'b110001:          
            begin         
             case (pfrx_credit_rm_dw_count_fm)
                  4'd1:flit_mode_prfx          = PRFX_WD'({ide_prfx,flit_local_pfrx[31:0]});
                  4'd2:flit_mode_prfx          = PRFX_WD'({ide_prfx,flit_local_pfrx[63:0]});
                default:flit_mode_prfx          = 'd0;
             endcase
            end
          6'b110010:
            begin
              if (ohc_ex_present.ohc_e1_present)
                flit_mode_prfx        = PRFX_WD'({ohc_ex_dw.ohc_e1_dw0,ide_prfx});
              else if (ohc_ex_present.ohc_e2_present)
                flit_mode_prfx        = PRFX_WD'({ohc_ex_dw.ohc_e2_dw1,ohc_ex_dw.ohc_e2_dw0,ide_prfx});
            end
          6'b110011:
            begin
              if (ohc_ex_present.ohc_e1_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                   4'd1:flit_mode_prfx          = PRFX_WD'({ohc_ex_dw.ohc_e1_dw0,ide_prfx,flit_local_pfrx[31:0]});
                  default: flit_mode_prfx        = 'd0;
                endcase
              end
              else if (ohc_ex_present.ohc_e2_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                  default: flit_mode_prfx        = 'd0;
                endcase
              end
              else if (ohc_ex_present.ohc_e4_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                 default: flit_mode_prfx        = 'd0;
             endcase
            end
           end
           6'b110100:
            begin         
              flit_mode_prfx          =    PRFX_WD'({tph_prfx,ide_prfx});
            end
           6'b110101:
            begin         
               case (pfrx_credit_rm_dw_count_fm)
                  4'd1:flit_mode_prfx          = PRFX_WD'({tph_prfx,ide_prfx,flit_local_pfrx[31:0]});
                  default: flit_mode_prfx        = 'd0;
              endcase
            end
           6'b110110:
            begin         
              if (ohc_ex_present.ohc_e1_present)
                flit_mode_prfx        = PRFX_WD'({tph_prfx,ohc_ex_dw.ohc_e1_dw0,ide_prfx});
            end
           6'b110111:
            begin         
              if (ohc_ex_present.ohc_e1_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                 default: flit_mode_prfx        = 'd0;
               endcase
              end
              else if (ohc_ex_present.ohc_e2_present)
              begin
              case (pfrx_credit_rm_dw_count_fm)
                  default: flit_mode_prfx        = 'd0;
                endcase
              end
              else if (ohc_ex_present.ohc_e4_present)
              begin
              case (pfrx_credit_rm_dw_count_fm)
              default: flit_mode_prfx        = 'd0;
             endcase
            end
           end
           6'b111000:
            begin         
              flit_mode_prfx          =    PRFX_WD'({pasid_prfx,ide_prfx});
            end
           6'b111001:
            begin         
               case (pfrx_credit_rm_dw_count_fm)
                   4'd1:flit_mode_prfx          = PRFX_WD'({pasid_prfx,ide_prfx,flit_local_pfrx[31:0]});
                  default: flit_mode_prfx        = 'd0;
              endcase
            end
           6'b111010:
            begin         
              if (ohc_ex_present.ohc_e1_present)
                flit_mode_prfx        = PRFX_WD'({pasid_prfx,ohc_ex_dw.ohc_e1_dw0,ide_prfx});
            end
           6'b111011:
            begin         
              if (ohc_ex_present.ohc_e1_present)
              begin
              case (pfrx_credit_rm_dw_count_fm)
                 default: flit_mode_prfx        = 'd0;
                endcase
              end
              else if (ohc_ex_present.ohc_e2_present)
              begin
              case (pfrx_credit_rm_dw_count_fm)
                  default: flit_mode_prfx        = 'd0;
               endcase
             end
             else if (ohc_ex_present.ohc_e4_present)
             begin
               case (pfrx_credit_rm_dw_count_fm)
                   default: flit_mode_prfx        = 'd0;
             endcase
            end
            end
           6'b111100:
            begin         
              flit_mode_prfx          =    PRFX_WD'({pasid_prfx,tph_prfx,ide_prfx});
            end
           6'b111101:
            begin         
             case (pfrx_credit_rm_dw_count_fm)
                default:flit_mode_prfx          = 'd0;
             endcase
            end
           6'b111110:
            begin         
               if (ohc_ex_present.ohc_e1_present)
                flit_mode_prfx        = PRFX_WD'({pasid_prfx,tph_prfx,ohc_ex_dw.ohc_e1_dw0,ide_prfx});
            end
           6'b111111:
            begin         
              if (ohc_ex_present.ohc_e1_present)
              begin
               case (pfrx_credit_rm_dw_count_fm)
                 default: flit_mode_prfx       = 'd0;
               endcase
             end
             else if (ohc_ex_present.ohc_e2_present)
             begin
             case (pfrx_credit_rm_dw_count_fm)
                 default: flit_mode_prfx        = 'd0;
               endcase
             end
             else if (ohc_ex_present.ohc_e4_present)
             begin
               case (pfrx_credit_rm_dw_count_fm)
                  default: flit_mode_prfx        = 'd0;
              endcase
            end
          end
         default:flit_mode_prfx = flit_mode_prfx_r;
       endcase 
    end

      assign hdr_to_flt_fm            = hdr_to_flt_fm_prfx;

    // Type field is in bits 4:0 of prefix.
    // Determine if a prefix type is reserved. Non-reserved includes ExtTPH, PASID, Vendor Defined and MRIOV.

    always_comb begin : detect_prefix_type
      integer i;
      prfx_type_rsrvd = 'd0;
      for(i = 0; i < NPRFX+1; i = i + 1) begin
        casez ({rx_tlp_hdr.hdr[i*32 +: 5],flit_mode})
          6'b00000?, 6'b01110?, 6'b01111?, 6'b10000?, 6'b10001?, 6'b11110?, 6'b11111? : prfx_type_rsrvd[i] = 0;
          6'b011011 : prfx_type_rsrvd[i] = 0;
          default  :  prfx_type_rsrvd[i] = 1;  // all other values => reserved type
        endcase
      end
    end

      always_comb begin : DECODE_LOCAL_PREFIX
        pfrx_dw_count_fm                                = 'd0;
        pfrx_dw_count_fm_in                             = 'd0;
        is_tlp_local_prfx                               = 'h0;
          flit_local_pfrx_in                            = 'd0;
        hdr_dw_cnt_fm                                   = 'h0;
        hdr_to_flt_fm_prfx                              =  hdr_to_flt_nfm_r;
        stop_prfx_dec_flit                              = 'd0;
        radm_flt_hdr_ecrc_wen                           = 'd0;

        if (rx_tlp_hdr.hv)
        begin
          for(int i = 0; i < NHW; i = i + 1) 
          begin
            is_tlp_local_prfx[i]                        = ((rx_tlp_hdr.hdr[i*32+7 -: 3] == local_prfx_fmt) &  (!rx_tlp_hdr.hdr[i*32+4]));
            if ((is_tlp_local_prfx[i] == 1) && !stop_prfx_dec_flit && (i < NPRFX+1))       
            begin
              pfrx_dw_count_fm                          = (pfrx_dw_count_fm[3:0] + 1);
              pfrx_dw_count_fm_in                       = pfrx_dw_count_fm - 1;
              radm_flt_hdr_ecrc_wen[i]                      = 1'b0;
              //flit_local_pfrx[32*pfrx_dw_count_fm_in[NPRFX-2:0] +:32]   = (rx_tlp_hdr.hdr[i*32 +: 32]); 
          flit_local_pfrx_in[32*i +:32]   = (rx_tlp_hdr.hdr[32*i +: 32]); 
            end
            else if ((is_tlp_local_prfx[i] == 0) | stop_prfx_dec_flit)  
            begin
              radm_flt_hdr_ecrc_wen[i]                      = rx_tlp_hdr.dwen[i];
              stop_prfx_dec_flit                        = 1'b1;
              // spyglass disable_block W164a
              // SMD: Identifies assignments in which the LHS width is less than the RHS width
              // SJ: Value of i will be always greater then or equals to pfrx_dw_count_fm. Underflow can never happen. 
              hdr_dw_cnt_fm                             = (i - pfrx_dw_count_fm); 
              // spyglass enable_block W164a
              hdr_to_flt_fm_prfx[(32*hdr_dw_cnt_fm) +:32] = (rx_tlp_hdr.hdr[i*32 +: 32]); 
            end
          end //for loophdr_dw_cnt_fm
        end
      end 

/////////////////////////
// generatre malformed error incase there is a problem in header/prefix arrangment
  // this is already generated in the IDE module so no need to duplicate the logic incase there is IDE core

decoded_tlp_type_s tlp_in_dec_type;
logic [2:0]        hdr_ohc_in_len;
logic [$clog2(4 +7 +1)-1:0] fm_hdr_in_size;
logic [(NHW)-1:0]                        pre_tlp_has_prefix_mal;
logic                                    stop_prfx_dec_mal ;
logic                                    stop_prfx_dec_flit_mal;
logic [NHW-1:0]                          is_tlp_local_prfx_mal;
logic [$clog2(NHW)-1:0]                  prefix_fmt_count_fm;//for malformed
logic [NHW-1:0]                          hdr_wen_count_nfm;//hdr malformed
logic [NHW-1:0]                          hdr_wen_count_fm;//hdr malformed
logic [NHW-1:0]                          hdr_wen_count;//hdr malformed
logic [$clog2(NHW)-1:0]          prefix_fmt_count_nfm;//for malformed
logic [$clog2(NHW)-1:0]          prefix_fmt_count;//for malformed

logic                            malformed_prefix ;
logic                            malformed_hdr_wen_lt_min ;
logic                            malformed_hdr_wen_gt_max ;
logic                            malformed_hdr_size_lt_min ;
logic                            malformed_hdr_size_gt_max ;

  always_comb begin : hdr_prefixes_count_nfm 

    stop_prfx_dec_mal                                              = 1'b0;
    
    pre_tlp_has_prefix_mal='0;
    prefix_fmt_count_nfm                                       = '0;

    hdr_wen_count_nfm                                          = '0;

    for(int i = 0; i < (NHW) ; i = i + 1) begin
      pre_tlp_has_prefix_mal[i]                                     =  rx_tlp_hdr.hdr[(32*i)+7] && !rx_tlp_hdr.hdr[(32*i)+6] &&
                                                                  !rx_tlp_hdr.hdr[(32*i)+5];// AL && rx_tlp_hdr.hv;
      prefix_fmt_count_nfm                                     = (pre_tlp_has_prefix_mal[i] && !stop_prfx_dec_mal)? prefix_fmt_count_nfm+ 1 : prefix_fmt_count_nfm; 
      if ((pre_tlp_has_prefix_mal[i] == 1) & (!stop_prfx_dec_mal) & (i < NPRFX)) begin //formate is prefix ////& (i < NPRFX) added
          // do nothing
      end //formate is prefix       
      else //if (((pre_tlp_has_prefix_mal[i] == 1'b0) | stop_prfx_dec_mal))// && rx_tlp_hdr.hv)           
      begin
        hdr_wen_count_nfm                                      = rx_tlp_hdr.dwen[i] ? (hdr_wen_count_nfm+ 1) : hdr_wen_count_nfm;
        stop_prfx_dec_mal                                          = 1'b1;
      end

    end
  end // hdr_prefixes_count_nfm

    always_comb begin : hdr_prefixes_count_fm
      is_tlp_local_prfx_mal                           = '0;
      stop_prfx_dec_flit_mal                          = '0;
      hdr_wen_count_fm                                = '0;
      prefix_fmt_count_fm                             = '0;
      if (rx_tlp_hdr.hv)
      begin
        for(int i = 0; i < NHW; i = i + 1) 
        begin
          is_tlp_local_prfx_mal[i]                                    = (rx_tlp_hdr.hdr[(32*i)+7 -: 4] == 4'b100_0);
          prefix_fmt_count_fm                                         = (is_tlp_local_prfx_mal[i]&& !stop_prfx_dec_flit_mal)? prefix_fmt_count_fm + 1 : prefix_fmt_count_fm; 
          if ((is_tlp_local_prfx_mal[i] == 1) && !stop_prfx_dec_flit_mal && (i < NPRFX))       
          begin
            // do nothing
          end
          else 
          begin
            hdr_wen_count_fm                                       = rx_tlp_hdr.dwen[i] ? (hdr_wen_count_fm + 1) : hdr_wen_count_fm ;
            stop_prfx_dec_flit_mal                                        = 1'b1;
          end
        end //for loop
      end
    end // hdr_prefixes_count_fm

// `ifdef SNPS_ASSERT_ON
// `ifndef SYNTHESIS
// 
// property p_no_malformed_pkt (logic hv, logic malformed);
//     @(posedge core_clk) disable iff (core_rst_n !==1'b1 )
//             (hv) |-> (!malformed) ;
// endproperty
// 
//   fv_chk_p_no_malformed_pkt: assert property(p_no_malformed_pkt(rx_tlp_hdr.hv, pcie_ide_malformed_tlp_err));
// 
// `endif // SYNTHESIS
// `endif // SNPS_ASSERT_ON

//////////////////////////////

    assign hdr_rsvd          = 'd0;  // Used to assign reserved filelds in HDR formation
    assign tlp_ln               = 1'b0; // As per Gen6 Protocol, LN is deprecated 
    assign hdr_th               =  ohc_decx_present.ohc_dec_b_present && ohc_b_hv[0]; // If OHC-B present TH is present

    assign int_common_hdr       = {com_dw_len[7:0],tlp_td,tlp_ep,tlp_attr[1:0], tlp_ats, com_dw_len[9:8],
 tlp.tlp_tag[9],
                                  tlp_tc, 
 tlp.tlp_tag[8],
                                  tlp_attr[2], 
 hdr_rsvd[2], 
                                  hdr_th,tlp_fmt, tlp.tlp_type};


    assign com_dw_len           = hdr_dw_len[9:0];


    //////////////////////////////////////////////////////////////////////////////////////
    // Following block seperates HDR dwords from incoming FLIT mode header
    // From received HDR Dwords each fields of HDR seperates to form header in NON-FLIT
    // mode
    //////////////////////////////////////////////////////////////////////////////////////
    always_comb begin  

      for(int i = 0; i < NHW; i = i + 1) begin
        hdr_dw[i]               = (hdr_to_flt_fm[i*32 +: 32]);
      end // for loop
    end 
   
    assign hdr_dw_len                           = {hdr_dw[0][17:16],{hdr_dw[0][24 +:8]}}; 
    assign tlp_td                               = hdr_dw[0][21];  // Bit 22 and 23 are reserved in Gen6 
    assign tlp_attr                             = hdr_dw[0][20:18]; 
    assign tlp_tc                               = hdr_dw[0][15:13]; 
    assign tlp_ohc                              = hdr_dw[0][12:8]; 
    assign tlp_fmt                              = hdr_dw[0][7:5];
    assign int_tlp_type                         = hdr_dw[0][4:0];
                
    assign tlp.tlp_rid                          = {hdr_dw[1][7:0],hdr_dw[1][15:8]};
    assign tlp.tlp_tag                          = {hdr_dw[1][21:16],hdr_dw[1][31:24]};
    assign tlp.tlp_tag_14bit_in                 = {hdr_dw[1][21:16],hdr_dw[1][31:24]};
    assign tlp_ep                               = {hdr_dw[1][23]} | (curnt_iscpl & tlp_cpl_ep);
    assign tlp_cpl_la_6                         = {hdr_dw[1][22]};
    assign tlp.tlp_msg_code                     = {hdr_dw[1][31:24]};
    assign tlp.tlp_cpl_id                       = {hdr_dw[1][7:0],hdr_dw[1][15:8]};
    assign tlp.tlp_cpl_dest_id                  = {hdr_dw[2][7:0],hdr_dw[2][15:8]};
    assign tlp_cpl_ep                           = {hdr_dw[1][23]};
    assign tlp_cpl_la_5_2                       = {hdr_dw[2][23:20]};
    assign tlp.tlp_cpl_byte_count               = {hdr_dw[2][19:16],{hdr_dw[2][24 +:8]}}; 
    assign tlp.tlp_addr                         = {hdr_dw[2],hdr_dw[3]};
    assign tlp_ats                              = (curnt_iscpl | curnt_ismsg | curnt_is_cfg_io) ? 2'b00 : (addr64 ? tlp.tlp_addr[25:24] : tlp.tlp_addr[57:56]) ;
     assign tlp_ats_vld                          = |tlp_ats;
    assign tlp.tlp_cpl_la_addr                  = {tlp_cpl_la_6,tlp_cpl_la_5_2};
    assign ohc_decx_present.ohc_dec_a_present   = tlp_ohc[0];
    assign ohc_decx_present.ohc_dec_b_present   = tlp_ohc[1];
    assign ohc_decx_present.ohc_dec_c_present   = tlp_ohc[2];
      assign  ohc_dec_e1_present                = tlp_ohc[3] && !tlp_ohc[4];
      assign  ohc_dec_e2_present                = !tlp_ohc[3] && tlp_ohc[4];
      assign  ohc_dec_e4_present                = tlp_ohc[3] && tlp_ohc[4];
      assign  ohc_ex_present.ohc_e1_present     = ohc_dec_e1_present;
      assign  ohc_ex_present.ohc_e2_present     = ohc_dec_e2_present;
      assign  ohc_ex_present.ohc_e4_present     = ohc_dec_e4_present;


  assign hdr_wen_count                   = flit_mode ? 
                                                  hdr_wen_count_fm : hdr_wen_count_nfm; 
  assign prefix_fmt_count                 = flit_mode ? 
                                                  prefix_fmt_count_fm : prefix_fmt_count_nfm; 

  assign tlp_in_dec_type = flit_mode ? f_decode_tlp_type(hdr_dw[0][7:0], 1'b1) : f_decode_tlp_type(hdr_to_flt_nfm[7:0], 1'b0); // type byte 0, bits 0->7

  assign hdr_ohc_in_len  = f_decode_ohc_len(hdr_dw[0][12:8]); // OHC Byte 1, bits 0->4
  assign fm_hdr_in_size = flit_mode ? {1'b0, tlp_in_dec_type.hdr_base_len} + {1'b0, hdr_ohc_in_len} : {1'b0, tlp_in_dec_type.hdr_base_len};

  //malformed TLP errors 
  //checking continous prefix DWs if they greater than NW_PRFX report malformed TLP prefix
  //checking continous header DWs if they greater than (11 FM) (4 if NFM) or less than 3 report malformed TLP header 
  //checking header size if it greater than (11 FM) (4 NFM) ro less than 3 report malformed TLP header
  assign malformed_hdr_wen_gt_max   = flit_mode ? (hdr_wen_count > 11) : (hdr_wen_count > 4) ; 
  assign malformed_hdr_wen_lt_min   = rx_tlp_hdr.hv ? (hdr_wen_count < 3) : '0; 
  assign malformed_prefix           = (prefix_fmt_count > NW_PRFX); 
  assign malformed_hdr_size_gt_max  = flit_mode ? (fm_hdr_in_size > 11) : (fm_hdr_in_size > 4) ; 
  assign malformed_hdr_size_lt_min  = rx_tlp_hdr.hv ? (fm_hdr_in_size < 3) : '0; 

// If invalid TS encoding is received then this should report as malformed TLP 
// TS - 3 bit encoding. If reserved encoding received at RADM, RADM should report malformed error)   
// 000b – No Trailer
// 001b – 1DW Trailer containing ECRC
// 010b – 1DW Trailer – Content Reserved
// 011b – 2DW Trailer – Content Reserved
// 100b – 2DW Trailer – Content Reserved
//101b – 3DW Trailer with IDE MAC if and only if OHC-C present and indicates IDE TLP; Else 3DW Trailer – Content
//Reserved
// 110b – 4DW Trailer with IDE MAC and PCRC if and only if OHC-C present and indicates IDE TLP; Else 4DW Trailer
// Content Reserved
// 111b – 5DW Trailer – Content Reserved

  logic [2:0] hdr_ts;
  logic       mlf_err_ts;
  logic       mlf_err_ts_r;

  assign   sub_strem_id_seven =  (ohc_c_sub_strm_id[2:0] == 3'b111);
  assign   hdr_ts             =  hdr_dw[0][23:21];

// Following always block is to check invalid TS filed reception and assertion of malformed error if TS is not received as expected. 
always_comb begin

         mlf_err_ts = mlf_err_ts_r; // Latching malformed error. In filter this signal is checked with EOT to assert final malformed error/tlp_abort signal assertion  
        

          if (rx_tlp_hdr.hv && flit_mode)
          begin
             case ({hdr_ts})
                   3'b000, 3'b001: mlf_err_ts = 1'b0;
                   default       : mlf_err_ts = 1'b1;
             endcase
          end
     end


  assign radm_malf_tlp_err_hdr = (malformed_hdr_wen_gt_max | malformed_hdr_wen_lt_min) |  (malformed_hdr_size_gt_max | malformed_hdr_size_lt_min) ;
  assign radm_malf_tlp_err_hdr_prfx = malformed_prefix;
  assign radm_malf_tlp_err_hdr_flit =  mlf_err_ts ;
  // Assignment for hdr_log_fields
  always_comb begin
      log_rcvd_flds                                     = '0 ;
      log_rcvd_flds.ohc_decx_present.ohc_dec_a_present  = tlp_ohc[0];
      log_rcvd_flds.ohc_decx_present.ohc_dec_b_present  = tlp_ohc[1];
      log_rcvd_flds.ohc_decx_present.ohc_dec_c_present  = tlp_ohc[2];
      log_rcvd_flds.ohc_uppr_43                         = tlp_ohc[4:3] ;
      log_rcvd_flds.ts_field                            = hdr_ts ;
  end
  
  
 // This signal should be used in ECRC check module to know valid Dword enables of received HDR   
  assign hdr_dec_flt_prfx_dwen             = flit_mode ? 
                                                  radm_flt_hdr_ecrc_wen : radm_nft_hdr_ecrc_wen;
  assign hdr_dec_local_prfx_cnt            = flit_mode ? 
                                                  pfrx_dw_count_fm : local_pfrx_dw_count_nfm;

  // For NON-FLIT mode of operation - 
  // Following logic to seperate HDR and Prefix from received full header from FormQ


    assign hdr_dec_flt_prfx                     = flit_mode ? 
                                                  flit_mode_prfx : radm_xtract_radm_prfx_nfm;
  

    logic [(NW_PRFX + 4)  -1 :0]              hdr_prfx_dwen_nfm;
    logic [(NW_PRFX + 4)-1 :0]                pre_tlp_has_prefix;
    logic [NW_PRFX-1 :0]                      pfrx_dw_count_nfm_in;
    logic                                     stop_prfx_dec ;
    logic                                     is_e2e_prfx;

    //assign hdr_dec_flt_prfx_dwen                ='d0;

    always_comb begin : detect_tlp_prefix

      pre_tlp_has_prefix                                          = 'd0;
      is_e2e_prfx                                                 = 1'd0;
      pfrx_dw_count_nfm                                           = 'd0; 
      pfrx_dw_count_nfm_in                                        = 'd0; 
      hdr_prfx_dwen_nfm                                           = 'd0;      
      hdr_to_flt_nfm_in                                           = (rx_tlp_hdr.hv)? '0 : hdr_to_flt_nfm_r;
        radm_xtract_radm_prfx_nfm_in                        = radm_xtract_radm_prfx_nfm_r;
      hdr_dw_cnt_nfm                                              = 'd0 ;
      stop_prfx_dec                                               = 1'b0;
      radm_nft_hdr_ecrc_wen                                       ='d0;
      local_pfrx_dw_count_nfm                                     ='d0;

      for(int i = 0; i < (NW_PRFX + 4); i = i + 1) begin
        pre_tlp_has_prefix[i]                                     =  rx_tlp_hdr.hdr[32*i+7] && !rx_tlp_hdr.hdr[32*i+6] &&
                                                                    !rx_tlp_hdr.hdr[32*i+5] && rx_tlp_hdr.hv;
        if ((pre_tlp_has_prefix[i] == 1) & (!stop_prfx_dec) & (i < 8))  // 8 is aligned with the behaviour of the radm_formation_queue
        begin
          if ( ( (prfx_type_rsrvd[i] & !rx_tlp_hdr.hdr[32*i+4]) || (!rx_tlp_hdr.hdr[32*i+4]) ) & (!is_e2e_prfx ) )
          begin
             // A value of 1'b0 in the Type[4] bit indicates the presence of a Local TLP Prefix
             radm_nft_hdr_ecrc_wen[i]                            = 1'b0;
             local_pfrx_dw_count_nfm                             = (local_pfrx_dw_count_nfm[3:0] + 1);
          end
          else 
          begin
             is_e2e_prfx                                         = 1'b1;
             radm_nft_hdr_ecrc_wen[i]                            = rx_tlp_hdr.dwen[i];
          end
          pfrx_dw_count_nfm                                       = (pfrx_dw_count_nfm[2:0] + 1);
          pfrx_dw_count_nfm_in                                    = pfrx_dw_count_nfm - 1;
   radm_xtract_radm_prfx_nfm_in[32*i +:32]  = rx_tlp_hdr.hdr[32*i +:32];
          hdr_prfx_dwen_nfm[i]                                    = 1'b1;
        end
        else if (((pre_tlp_has_prefix[i] == 0) | stop_prfx_dec)  && rx_tlp_hdr.hv)      
        begin
          radm_nft_hdr_ecrc_wen[i]                                = rx_tlp_hdr.dwen[i];
          stop_prfx_dec                                           = 1'b1;
          hdr_dw_cnt_nfm                                          = (i - pfrx_dw_count_nfm); 
          hdr_to_flt_nfm_in[32*hdr_dw_cnt_nfm +:32]               = (rx_tlp_hdr.hdr[i*32 +: 32]); 
        end

      end
    end


  assign hdr_to_flt_nfm               = hdr_to_flt_nfm_in[HW_NFT-1:0]; 


// Following block to select header as per FLIT mode or Non-FLit mode 

// `ifdef CX_TLP_PREFIX_ENABLE
  always_ff @(posedge core_clk or negedge core_rst_n)
  begin
    if(!core_rst_n) begin
      hdr_to_flt_nfm_r    <= #TP 'd0;
      mlf_err_ts_r        <= #TP 'd0;
      radm_xtract_radm_prfx_nfm_r   <= #TP  'd0;
      flit_mode_prfx_r             <= #TP  'd0;
    end else begin
      hdr_to_flt_nfm_r    <= #TP flit_mode ? hdr_to_flt_fm_prfx : hdr_to_flt_nfm_in;
      mlf_err_ts_r        <= #TP  mlf_err_ts;
      radm_xtract_radm_prfx_nfm_r   <= #TP  rx_tlp_eot ? 'd0  : radm_xtract_radm_prfx_nfm_in;
      flit_mode_prfx_r             <= #TP  rx_tlp_eot ? 'd0  : flit_mode_prfx;
    end
  end
// `endif

endmodule

