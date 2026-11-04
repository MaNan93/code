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
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/svif/DWC_cxl_app_ch_if.svh#3 $
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_CXL_APP_CH_IF__SVH__
`define __GUARD__DWC_CXL_APP_CH_IF__SVH__
interface DWC_cxl_app_ch_if
  import DWC_cxl_pkg::*;
  #();

  //----------------------------------------------------------------------------------------
  // Application channel interface signals. Based on the controller configuration for 
  // RC or EP, one or other modport is getting used inside the CXL controller.
  //
  //----------------------------------------------------------------------------------------
  // Cache H2D Application Interfaces.
  wire [H2D_REQ_SIZE-1  : 0]                s_cxl_h2d_req[0:H2D_REQ_IFNUM-1]   ;     // H2D Request Channel
  wire [H2D_RESP_SIZE-1 : 0]                s_cxl_h2d_resp[0:H2D_RESP_IFNUM-1] ;     // H2D Response Channel
  wire [H2D_DATA_SIZE-1 : 0]                s_cxl_h2d_data[0:H2D_DATA_IFNUM-1] ;     // H2D Data Channel: Header + Data

  // Cache D2H Application Interfaces.
  wire [D2H_REQ_SIZE-1  : 0]                s_cxl_d2h_req[0:D2H_REQ_IFNUM-1]   ;     // D2H Request Channel
  wire [D2H_RESP_SIZE-1 : 0]                s_cxl_d2h_resp[0:D2H_RESP_IFNUM-1] ;     // D2H Response Channel
  wire [D2H_DATA_SIZE-1 : 0]                s_cxl_d2h_data[0:D2H_DATA_IFNUM-1] ;     // D2H Data Channel: Header + Data + BE 


  // Cache M2S Application Interfaces.
  wire [M2S_NDR_SIZE-1  : 0]                s_cxl_m2s_req[0:M2S_NDR_IFNUM-1]   ;     // M2S Request Channel
  wire [M2S_DATA_SIZE-1 : 0]                s_cxl_m2s_rwd[0:M2S_DATA_IFNUM-1]  ;     // M2S Request with Data Channel: Header + BE + Data


  // Cache S2M Application Interfaces.
  wire [S2M_NDR_SIZE-1  : 0]                s_cxl_s2m_ndr[0:S2M_NDR_IFNUM-1]   ;     // S2M Response NDR Channel
  wire [S2M_DATA_SIZE-1 : 0]                s_cxl_s2m_drc[0:S2M_DATA_IFNUM-1]  ;     // S2M Response DRC Channel: Header + Data

  wire [(M2S_BI_RSP_SIZE-1)       : 0]          s_cxl_m2s_bi_rsp[0:M2S_BI_RSP_IFNUM-1]    ; // M2S Back-Invalidate Response Channel
  wire [(S2M_BI_SNP_SIZE-1)       : 0]          s_cxl_s2m_bi_snp[0:S2M_BI_SNP_IFNUM-1]    ; // S2M Back-Invalidate Snoop Channel

  //----------------------------------------------------------------------------------------
  // Application channel DPP or ECC check interface signals. Based on the controller configuration for 
  // RC or EP, one or other modport is getting used inside the CXL controller.
  //
  //----------------------------------------------------------------------------------------
  // Cache H2D Application DPP or ECC check Interfaces.
  wire [(H2D_REQ_CHK_SIZE-1)  : 0]          s_cxl_h2d_req_chk[0:H2D_REQ_IFNUM-1]   ; // H2D Request Channels DPP or ECC check        
  wire [(H2D_RESP_CHK_SIZE-1) : 0]          s_cxl_h2d_resp_chk[0:H2D_RESP_IFNUM-1] ; // H2D Response Channels DPP or ECC check
  wire [(H2D_DATA_CHK_SIZE-1) : 0]          s_cxl_h2d_data_chk[0:H2D_DATA_IFNUM-1] ; // H2D Data Channels DPP or ECC check
  
  // Cache D2H Application DPP or ECC check Interfaces.
  wire [(D2H_REQ_CHK_SIZE-1)  : 0]          s_cxl_d2h_req_chk[0:D2H_REQ_IFNUM-1]    ; // D2H Request Channels DPP or ECC check
  wire [(D2H_RESP_CHK_SIZE-1) : 0]          s_cxl_d2h_resp_chk[0:D2H_RESP_IFNUM-1]  ; // D2H Response Channels DPP or ECC check
  wire [(D2H_DATA_CHK_SIZE-1) : 0]          s_cxl_d2h_data_chk[0:D2H_DATA_IFNUM-1]  ; // D2H Data Channels DPP or ECC check
  // Cache M2S Application DPP or ECC check Interfaces.
  wire [(M2S_NDR_CHK_SIZE-1)  : 0]          s_cxl_m2s_req_chk[0:M2S_NDR_IFNUM-1]   ; // M2S Request Channels DPP or ECC check 
  wire [(M2S_DATA_CHK_SIZE-1) : 0]          s_cxl_m2s_rwd_chk[0:M2S_DATA_IFNUM-1]  ; // M2S Request Data Channel DPP or ECC check

  // Cache S2M Application DPP or ECC check Interfaces.
  wire [(S2M_NDR_CHK_SIZE-1)  : 0]          s_cxl_s2m_ndr_chk[0:S2M_NDR_IFNUM-1]    ; // S2M Response NDR Channels DPP or ECC check
  wire [(S2M_DATA_CHK_SIZE-1) : 0]          s_cxl_s2m_drc_chk[0:S2M_DATA_IFNUM-1]   ; // S2M Response DRC Channels DPP or ECC check

  wire [(M2S_BI_RSP_CHK_SIZE-1)   : 0]          s_cxl_m2s_bi_rsp_chk[0:M2S_BI_RSP_IFNUM-1]  ; // M2S Back-Invalidate Response Channel DPP or ECC check
  wire [(S2M_BI_SNP_CHK_SIZE-1)   : 0]          s_cxl_s2m_bi_snp_chk[0:S2M_BI_SNP_IFNUM-1]  ; // S2M Back-Invalidate Snoop Channel DPP or ECC check

  //----------------------------------------------------------------------------------------
  // Application channel credit interface signals. Based on the controller configuration for 
  // RC or EP, one or other modport is getting used inside the CXL controller.
  //
  //----------------------------------------------------------------------------------------
  // Cache H2D Application credit Interfaces.
  wire                                      s_cxl_h2d_req_crd[0:H2D_REQ_IFNUM-1]   ; // H2D Request Channels credit        
  wire                                      s_cxl_h2d_resp_crd[0:H2D_RESP_IFNUM-1] ; // H2D Response Channels credit
  wire                                      s_cxl_h2d_data_crd[0:H2D_DATA_IFNUM-1] ; // H2D Data Channels credit
  
  // Cache D2H Application Credit Interfaces.
  wire                                      s_cxl_d2h_req_crd[0:D2H_REQ_IFNUM-1]    ; // D2H Request Channels credit
  wire                                      s_cxl_d2h_resp_crd[0:D2H_RESP_IFNUM-1]  ; // D2H Response Channels credit
  wire                                      s_cxl_d2h_data_crd[0:D2H_DATA_IFNUM-1]  ; // D2H Data Channels credit
  // Cache M2S Application Credit Interfaces.
  wire                                      s_cxl_m2s_req_crd[0:M2S_NDR_IFNUM-1]   ; // M2S Request Channels credit 
  wire                                      s_cxl_m2s_rwd_crd[0:M2S_DATA_IFNUM-1]  ; // M2S Request Data Channel credit

  // Cache S2M Application Credit Interfaces.
  wire                                      s_cxl_s2m_ndr_crd[0:S2M_NDR_IFNUM-1]    ; // S2M Response NDR Channels credit
  wire                                      s_cxl_s2m_drc_crd[0:S2M_DATA_IFNUM-1]   ; // S2M Response DRC Channels credit
  wire                                      s_cxl_m2s_bi_rsp_crd[0:M2S_BI_RSP_IFNUM-1]  ; // M2S Back-Invalidate Response Channel credit
  wire                                      s_cxl_s2m_bi_snp_crd[0:S2M_BI_SNP_IFNUM-1]  ; // S2M Back-Invalidate Snoop Channel credit

// -------------------------------------------------------------------------------------
// CXL RC TX interfaces
// -------------------------------------------------------------------------------------
modport slave_host_mp(
    // Channel Message Interface
       input    s_cxl_h2d_req,
       input    s_cxl_h2d_resp, 
       input    s_cxl_h2d_data,
       input    s_cxl_h2d_req_chk,
       input    s_cxl_h2d_resp_chk, 
       input    s_cxl_h2d_data_chk,

       input    s_cxl_m2s_req,
       input    s_cxl_m2s_rwd,
       input    s_cxl_m2s_req_chk,
       input    s_cxl_m2s_rwd_chk,

       input    s_cxl_m2s_bi_rsp,
       input    s_cxl_m2s_bi_rsp_chk,

    // Channel Credit Interface
       output   s_cxl_h2d_req_crd,
       output   s_cxl_h2d_resp_crd, 
       output   s_cxl_h2d_data_crd
       ,
       output   s_cxl_m2s_req_crd,
       output   s_cxl_m2s_rwd_crd
       ,
       output   s_cxl_m2s_bi_rsp_crd
); // slave_host_mp
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// CXL RC RX Interface
// -------------------------------------------------------------------------------------
modport master_device_mp(
    // Channel Message Interface
       output   s_cxl_d2h_req,
       output   s_cxl_d2h_resp, 
       output   s_cxl_d2h_data,
       output   s_cxl_d2h_req_chk,
       output   s_cxl_d2h_resp_chk, 
       output   s_cxl_d2h_data_chk,

       output   s_cxl_s2m_ndr,
       output   s_cxl_s2m_drc,
       output   s_cxl_s2m_ndr_chk,
       output   s_cxl_s2m_drc_chk,

       output   s_cxl_s2m_bi_snp,
       output   s_cxl_s2m_bi_snp_chk,

    // Channel Credit Interface
       input    s_cxl_d2h_req_crd,
       input    s_cxl_d2h_resp_crd, 
       input    s_cxl_d2h_data_crd
       ,
       input    s_cxl_s2m_ndr_crd,
       input    s_cxl_s2m_drc_crd
       ,
       input    s_cxl_s2m_bi_snp_crd
); // master_device_mp
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// CXL EP TX Interfaces
// -------------------------------------------------------------------------------------
modport slave_device_mp(
    // Channel Message Interface
       input    s_cxl_d2h_req,
       input    s_cxl_d2h_resp, 
       input    s_cxl_d2h_data,
       input    s_cxl_d2h_req_chk,
       input    s_cxl_d2h_resp_chk, 
       input    s_cxl_d2h_data_chk,

       input    s_cxl_s2m_ndr,
       input    s_cxl_s2m_drc,
       input    s_cxl_s2m_ndr_chk,
       input    s_cxl_s2m_drc_chk,

       input    s_cxl_s2m_bi_snp,
       input    s_cxl_s2m_bi_snp_chk,

    // Channel Credit Interface
       output   s_cxl_d2h_req_crd,
       output   s_cxl_d2h_resp_crd, 
       output   s_cxl_d2h_data_crd
       ,
       output   s_cxl_s2m_ndr_crd,
       output   s_cxl_s2m_drc_crd
       ,
       output   s_cxl_s2m_bi_snp_crd
); // slave_device_mp

// -------------------------------------------------------------------------------------
// CXL EP RX interfaces
// -------------------------------------------------------------------------------------
modport master_host_mp(
    // Channel Message Interface
       output   s_cxl_h2d_req,
       output   s_cxl_h2d_resp, 
       output   s_cxl_h2d_data,
       output   s_cxl_h2d_req_chk,
       output   s_cxl_h2d_resp_chk, 
       output   s_cxl_h2d_data_chk,

       output   s_cxl_m2s_req,
       output   s_cxl_m2s_rwd,
       output   s_cxl_m2s_req_chk,
       output   s_cxl_m2s_rwd_chk,

       output   s_cxl_m2s_bi_rsp,
       output   s_cxl_m2s_bi_rsp_chk,

    // Channel Credit Interface
       input    s_cxl_h2d_req_crd,
       input    s_cxl_h2d_resp_crd, 
       input    s_cxl_h2d_data_crd
       ,
       input    s_cxl_m2s_req_crd,
       input    s_cxl_m2s_rwd_crd
       ,
       input    s_cxl_m2s_bi_rsp_crd
); // master_host_mp
// -------------------------------------------------------------------------------------
         
endinterface : DWC_cxl_app_ch_if
`endif // __GUARD__DWC_CXL_APP_CH_IF__SVH__
