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
// ---   $DateTime: 2024/01/19 09:25:58 $
// ---   $Revision: #8 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/svif/DWC_cxl_txtl_llctrl_if.svh#8 $
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_CXL_TXTL_LLCTRL_IF__SVH__
`define __GUARD__DWC_CXL_TXTL_LLCTRL_IF__SVH__
interface DWC_cxl_txtl_llctrl_if

  import DWC_cxl_pkg::*;
  #();

// -------------------------------------------------------------------------------------
// Common Interface
// -------------------------------------------------------------------------------------
    logic                        s_cxl_cache_enable;               // Enable CXL.cache interface
    logic                        s_cxl_cache_app_pending;          // Indicates pending CXL.cache traffic at the application layer
    logic                        s_cxl_mem_enable;                 // Enable CXL.mem interface
    logic                        s_cxl_mem_app_pending;            // Indicates pending CXL.mem traffic at the application layer
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Host Flit Packer Message Channel Interface
// -------------------------------------------------------------------------------------
    // H2D Request Channels. Maximum 2 messages per flit
    logic [H2D_REQ_SIZE-1:0]      s_cxl_h2d_req [0:H2D_REQ_NUM-1];      // H2D Request Channel - 64 bits
    logic [H2D_MSG_CNT_WD-1:0]    s_cxl_h2d_req_cnt [0:H2D_REQ_NUM-1];  // H2D Request Message Count
    logic [H2D_REQ_NUM-1 :0]      s_cxl_h2d_req_halt;                   // H2D Request Channel Halt
    // H2D Response Channels. Maximum 4 messages per flit
    logic [H2D_RESP_SIZE-1:0]     s_cxl_h2d_rsp [0:H2D_RESP_NUM-1];     // H2D Response Channel - 32 bits
    logic [H2D_MSG_CNT_WD-1:0]    s_cxl_h2d_rsp_cnt [0:H2D_RESP_NUM-1]; // H2D Response Message Count
    logic [H2D_RESP_NUM-1 :0]     s_cxl_h2d_rsp_halt;                   // H2D Response Channel Halt
    // H2D Data Header - 24 bits. Maximum 4 headers per flit
    logic [H2D_DHDR_SIZE-1 :0]    s_cxl_h2d_hdr [0:H2D_DATA_NUM-1];     // H2D Data Header Channel - 24 bits
    logic [H2D_DATA_NUM-1  :0]    s_cxl_h2d_hdr_halt;                   // H2D Data Header Channel Halt
    logic [H2D_DDATA_NUM-1 :0]    s_cxl_h2d_data_vld;                   // H2D Data Valid
    logic [H2D_DDATA_SIZE-1:0]    s_cxl_h2d_data [0:H2D_DDATA_NUM-1];   // H2D Data - 4x16B
    logic [H2D_DDATA_NUM-1 :0]    s_cxl_h2d_data_halt;                  // H2D Data Channel Halt
    logic [H2D_REQ_CHK_SIZE-1  :0] s_cxl_h2d_req_chk [0:H2D_REQ_NUM-1];  // H2D Request Protection Code
    logic [H2D_RESP_CHK_SIZE-1 :0] s_cxl_h2d_rsp_chk [0:H2D_RESP_NUM-1]; // H2D Response Protection Code
    logic [H2D_DHDR_CHK_SIZE-1 :0] s_cxl_h2d_hdr_chk [0:H2D_DATA_NUM-1]; // H2D Data Header Protection Code
    logic [H2D_DDATA_CHK_SIZE-1:0] s_cxl_h2d_data_chk[0:H2D_DATA_NUM-1]; // H2D Data Protection Code for 4 channels
    logic [H2D_DDATA_SIZE-1    :0] s_cxl_h2d_data_arr[0:H2D_DATA_NUM-1]; // H2D Data - 4x4x16B
    // M2S Request with No Data Channels. Maximum 2 messages per flit
    logic [M2S_NDR_SIZE-1:0]       s_cxl_m2s_req [0:M2S_NDR_NUM-1];      // M2S Request with no Data Channel - 87 bits
    logic [M2S_NDR_NUM-1 :0]       s_cxl_m2s_req_halt;                   // M2S Request with no Data Channel Halt
    // M2S Request with Data Channel. Maximum 1 messages per flit
    logic [M2S_DHDR_SIZE-1 :0]     s_cxl_m2s_hdr [0:M2S_DATA_NUM-1];     // M2S Request with Data Channel Header - 87 bits
    logic [M2S_DBE_SIZE-1  :0]     s_cxl_m2s_be  [0:M2S_DDATA_NUM-1];    // M2S Request with Data Channel Byte Enable - 63 bits (it is not a part of the header)
    logic [M2S_DATA_NUM-1  :0]     s_cxl_m2s_be_vld_n;                     // M2S Byte Enable Valid for 68B mode   
    logic [M2S_DATA_NUM-1  :0]     s_cxl_m2s_hdr_halt;                   // M2S RwD Header Channel Halt
    logic [M2S_DDATA_NUM-1 :0]     s_cxl_m2s_data_vld;                   // M2S Data Valid
    logic [M2S_DDATA_SIZE-1:0]     s_cxl_m2s_data [0:M2S_DDATA_NUM-1];   // M2S Request with Data Channel Data  - 4x16B
    logic [M2S_DDATA_NUM-1 :0]     s_cxl_m2s_data_halt;                  // M2S Data Channel Halt
    logic [M2S_NDR_CHK_SIZE-1  :0] s_cxl_m2s_req_chk [0:M2S_NDR_NUM -1];  // M2S Request Protection Code
    logic [M2S_DHDR_CHK_SIZE-1 :0] s_cxl_m2s_hdr_chk [0:M2S_DATA_NUM-1];  // M2S Data Header Protection Code
    logic [M2S_DDATA_CHK_SIZE-1:0] s_cxl_m2s_data_chk[0:M2S_DATA_NUM-1];  // M2S Data Protection Code for 4 channels
    logic [M2S_DDATA_SIZE-1    :0] s_cxl_m2s_data_arr[0:M2S_DATA_NUM-1];  // M2S Request with Data Channel Data  - 4x4x16B
    logic [M2S_DBE_CHK_SIZE-1  :0] s_cxl_m2s_be_chk  [0:M2S_DATA_NUM-1];  // M2S Data BE Protection Code
    logic [M2S_DBE_SIZE-1:      0] s_cxl_m2s_be_arr  [0:M2S_DATA_NUM-1];
    logic [M2S_BI_RSP_SIZE-1:0]          s_cxl_m2s_bi_rsp [0:M2S_BI_RSP_NUM-1];     // M2S BI Response Channel
    logic [M2S_BI_RSP_NUM-1:0]           s_cxl_m2s_bi_rsp_halt;                     // M2S BI Response Channel Halt
    logic [M2S_BI_RSP_CHK_SIZE-1:0]      s_cxl_m2s_bi_rsp_chk [0:M2S_BI_RSP_NUM-1]; // M2S BI Response Protection Code
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Device Flit Packer Message Channel Interface
// -------------------------------------------------------------------------------------
    // D2H Request Channels. Maximum 4 messages per flit
    logic [D2H_REQ_SIZE-1:0]         s_cxl_d2h_req [0:D2H_REQ_NUM-1];      // H2D Request Channel - 79 bits
    logic [D2H_REQ_NUM-1:0]          s_cxl_d2h_req_halt;                   // H2D Request Channel Halt
    // H2D Response Channels. Maximum 4 messages per flit
    logic [D2H_RESP_SIZE-1:0]        s_cxl_d2h_rsp [0:D2H_RESP_NUM-1];     // D2H Response Channel - 20 bits
    logic [D2H_RESP_NUM-1:0]         s_cxl_d2h_rsp_halt;                   // D2H Response Channel Halt
    // H2D Data Header - 24 bits. Maximum 4 headers per flit
    logic [D2H_DHDR_SIZE-1:0]        s_cxl_d2h_hdr [0:D2H_DATA_NUM-1];     // D2H Data Header Channel - 17 bits
    logic [D2H_DBE_SIZE-1:0]         s_cxl_d2h_be [0:D2H_DDATA_NUM-1];     // D2H Byte Enable Channel 0 - 63 bits (it is not a part of the header)
    logic [D2H_DATA_NUM-1:0]         s_cxl_d2h_be_vld_n ;                  // D2H Byte Enable Valid for 68B mode 
    logic [D2H_DATA_NUM-1:0]         s_cxl_d2h_hdr_halt;                   // D2H Data Header Channel Halt
    logic [D2H_DDATA_NUM-1:0]        s_cxl_d2h_data_vld;                   // D2H Data Valid
    logic [D2H_DDATA_SIZE-1:0]       s_cxl_d2h_data [0:D2H_DDATA_NUM-1];   // D2H Data - 4x16B
    logic [D2H_DDATA_NUM-1:0]        s_cxl_d2h_data_halt;                  // D2H Data Channel Halt
    logic [D2H_REQ_CHK_SIZE-1  :0]   s_cxl_d2h_req_chk [0:D2H_REQ_NUM-1];  // D2H Request Protection Code
    logic [D2H_RESP_CHK_SIZE-1 :0]   s_cxl_d2h_rsp_chk [0:D2H_RESP_NUM-1]; // D2H Response Protection Code
    logic [D2H_DHDR_CHK_SIZE-1 :0]   s_cxl_d2h_hdr_chk [0:D2H_DATA_NUM-1]; // D2H Data Header+BE Protection Code
    logic [D2H_DDATA_CHK_SIZE-1:0]   s_cxl_d2h_data_chk[0:D2H_DATA_NUM-1]; // D2H Data Protection Code for 4 channels
    logic [D2H_DDATA_SIZE-1    :0]   s_cxl_d2h_data_arr[0:D2H_DATA_NUM-1]; // D2H Data - 4x4x16B
    logic [D2H_DBE_CHK_SIZE-1  :0]   s_cxl_d2h_be_chk  [0:D2H_DATA_NUM-1];    
    logic [D2H_DBE_SIZE-1      :0]   s_cxl_d2h_be_arr  [0:D2H_DATA_NUM-1];
    // M2S Request with No Data Channels. Maximum 2 messages per flit
    logic [S2M_NDR_SIZE-1:0]         s_cxl_s2m_ndr [0:S2M_NDR_NUM-1];      // S2M NDR Channel - 28 bits
    logic [S2M_NDR_NUM-1 :0]         s_cxl_s2m_ndr_halt;                   // S2M NDR Channel Halt
    // M2S Request with Data Channel. Maximum 1 messages per flit
    logic [S2M_DHDR_SIZE-1 :0]       s_cxl_s2m_hdr [0:S2M_DATA_NUM-1];     // S2M DRC Header Channel - 40 bits
    logic [S2M_DATA_NUM-1  :0]       s_cxl_s2m_hdr_halt;                   // S2M DRC Header Channel Halt
    logic [S2M_DDATA_NUM-1 :0]       s_cxl_s2m_data_vld;                   // S2M Data Valid
    logic [S2M_DDATA_SIZE-1:0]       s_cxl_s2m_data [0:S2M_DDATA_NUM-1];   // S2M DRC Data Channel Data  - 4x16B
    logic [S2M_DDATA_NUM-1 :0]       s_cxl_s2m_data_halt;                  // S2M DRC Data Channel Halt

    logic [S2M_NDR_CHK_SIZE-1  :0]   s_cxl_s2m_ndr_chk [0:S2M_NDR_NUM-1];  // S2M Request Protection Code
    logic [S2M_DHDR_CHK_SIZE-1 :0]   s_cxl_s2m_hdr_chk [0:S2M_DATA_NUM-1]; // S2M Data Header Protection Code
    logic [S2M_DDATA_CHK_SIZE-1:0]   s_cxl_s2m_data_chk[0:S2M_DATA_NUM-1]; // S2M Data Protection Code for 4 channels
    logic [S2M_DDATA_SIZE-1    :0]   s_cxl_s2m_data_arr[0:S2M_DATA_NUM-1]; // S2M DRC Data Channel Data  - 4x4x16B
    logic [S2M_BI_SNP_SIZE-1:0]          s_cxl_s2m_bi_snp [0:S2M_BI_SNP_NUM-1];     // S2M BI Snoop Channel
    logic [S2M_BI_SNP_NUM-1 :0]          s_cxl_s2m_bi_snp_halt;                     // S2M BI Snoop Channel Halt
    logic [S2M_BI_SNP_CHK_SIZE-1:0]      s_cxl_s2m_bi_snp_chk [0:S2M_BI_SNP_NUM-1]; // S2M BI Snoop Protection Code
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// TX Transaction Layer interface with Host Flit Packer
// -------------------------------------------------------------------------------------
modport master_host_mp(
    output  s_cxl_cache_enable,
    output  s_cxl_cache_app_pending
    ,
    output  s_cxl_mem_enable,
    output  s_cxl_mem_app_pending
    ,
    output  s_cxl_h2d_req,
    output  s_cxl_h2d_req_cnt,
    output  s_cxl_h2d_rsp,
    output  s_cxl_h2d_rsp_cnt,
    output  s_cxl_h2d_hdr,
    output  s_cxl_h2d_data_vld,
    output  s_cxl_h2d_data
    ,
    output  s_cxl_m2s_req,
    output  s_cxl_m2s_hdr,
    output  s_cxl_m2s_be,
    output  s_cxl_m2s_be_vld_n,
    output  s_cxl_m2s_data_vld,
    output  s_cxl_m2s_data
    ,
    output s_cxl_m2s_bi_rsp
    ,
    input   s_cxl_h2d_req_halt,
    input   s_cxl_h2d_rsp_halt,
    input   s_cxl_h2d_hdr_halt,
    input   s_cxl_h2d_data_halt
    ,
    input   s_cxl_m2s_req_halt,
    input   s_cxl_m2s_hdr_halt,
    input   s_cxl_m2s_data_halt
    ,
    input  s_cxl_m2s_bi_rsp_halt
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Host Flit Packer interface with TX Transaction Layer
// -------------------------------------------------------------------------------------
modport slave_host_mp(
    input   s_cxl_cache_enable,
    input   s_cxl_cache_app_pending
    ,
    input   s_cxl_mem_enable,
    input   s_cxl_mem_app_pending
    ,
    input   s_cxl_h2d_req,
    input   s_cxl_h2d_req_cnt,
    input   s_cxl_h2d_rsp,
    input   s_cxl_h2d_rsp_cnt,
    input   s_cxl_h2d_hdr,
    input   s_cxl_h2d_data_vld,
    input   s_cxl_h2d_data
    ,
    input   s_cxl_m2s_req,
    input   s_cxl_m2s_hdr,
    input   s_cxl_m2s_be,
    input   s_cxl_m2s_be_vld_n,
    input   s_cxl_m2s_data_vld,
    input   s_cxl_m2s_data
    ,
    input  s_cxl_m2s_bi_rsp

    ,
    output  s_cxl_h2d_req_halt,
    output  s_cxl_h2d_rsp_halt,
    output  s_cxl_h2d_hdr_halt,
    output  s_cxl_h2d_data_halt
    ,
    output  s_cxl_m2s_req_halt,
    output  s_cxl_m2s_hdr_halt,
    output  s_cxl_m2s_data_halt
    ,
    output s_cxl_m2s_bi_rsp_halt
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// TX Transaction Layer interface with Device Flit Packer
// -------------------------------------------------------------------------------------
modport master_dev_mp(
    output  s_cxl_cache_enable,
    output  s_cxl_cache_app_pending
    ,
    output  s_cxl_mem_enable,
    output  s_cxl_mem_app_pending
    ,
    output  s_cxl_d2h_req,
    output  s_cxl_d2h_rsp,
    output  s_cxl_d2h_hdr,
    output  s_cxl_d2h_be,
    output  s_cxl_d2h_be_vld_n,
    output  s_cxl_d2h_data_vld,
    output  s_cxl_d2h_data
    ,
    output  s_cxl_s2m_ndr,
    output  s_cxl_s2m_hdr,
    output  s_cxl_s2m_data_vld,
    output  s_cxl_s2m_data
    ,
    output s_cxl_s2m_bi_snp

    ,
    input   s_cxl_d2h_req_halt,
    input   s_cxl_d2h_rsp_halt,
    input   s_cxl_d2h_hdr_halt,
    input   s_cxl_d2h_data_halt
    ,
    input   s_cxl_s2m_ndr_halt,
    input   s_cxl_s2m_hdr_halt,
    input   s_cxl_s2m_data_halt
    ,
    input  s_cxl_s2m_bi_snp_halt
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Device Flit Packer interface with TX Transaction Layer
// -------------------------------------------------------------------------------------
modport slave_dev_mp(
    input   s_cxl_cache_enable,
    input   s_cxl_cache_app_pending
    ,
    input   s_cxl_mem_enable,
    input  s_cxl_mem_app_pending
    ,
    input   s_cxl_d2h_req,
    input   s_cxl_d2h_rsp,
    input   s_cxl_d2h_hdr,
    input   s_cxl_d2h_be,
    input   s_cxl_d2h_be_vld_n,
    input   s_cxl_d2h_data_vld,
    input   s_cxl_d2h_data
    ,
    input   s_cxl_s2m_ndr,
    input   s_cxl_s2m_hdr,
    input   s_cxl_s2m_data_vld,
    input   s_cxl_s2m_data
    ,
    input  s_cxl_s2m_bi_snp

    ,
    output  s_cxl_d2h_req_halt,
    output  s_cxl_d2h_rsp_halt,
    output  s_cxl_d2h_hdr_halt,
    output  s_cxl_d2h_data_halt
    ,
    output  s_cxl_s2m_ndr_halt,
    output  s_cxl_s2m_hdr_halt,
    output  s_cxl_s2m_data_halt
    ,
    output s_cxl_s2m_bi_snp_halt
);

// -------------------------------------------------------------------------------------
// Master RASDP Interface
// -------------------------------------------------------------------------------------
modport master_rasdp_mp(
    output    s_cxl_h2d_req_chk ,
    output    s_cxl_h2d_rsp_chk ,
    output    s_cxl_h2d_hdr_chk ,
    output    s_cxl_h2d_data_chk,
    output    s_cxl_h2d_data_arr
 , // CX_CXL_MEM_EN
    output    s_cxl_m2s_req_chk ,
    output    s_cxl_m2s_hdr_chk ,
    output    s_cxl_m2s_data_chk,
    output    s_cxl_m2s_data_arr,
    output    s_cxl_m2s_be_chk,
    output    s_cxl_m2s_be_arr
    ,
    output   s_cxl_m2s_bi_rsp_chk
    ,
    output    s_cxl_d2h_req_chk ,
    output    s_cxl_d2h_rsp_chk ,
    output    s_cxl_d2h_hdr_chk ,
    output    s_cxl_d2h_data_chk,
    output    s_cxl_d2h_data_arr,
    output    s_cxl_d2h_be_chk,
    output    s_cxl_d2h_be_arr
 , // CX_CXL_MEM_EN
    output    s_cxl_s2m_ndr_chk ,
    output    s_cxl_s2m_hdr_chk ,
    output    s_cxl_s2m_data_chk,
    output    s_cxl_s2m_data_arr
    ,
    output   s_cxl_s2m_bi_snp_chk
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Slave RASDP Interface
// -------------------------------------------------------------------------------------
modport slave_rasdp_mp(
    input     s_cxl_h2d_req_chk ,
    input     s_cxl_h2d_rsp_chk ,
    input     s_cxl_h2d_hdr_chk ,
    input     s_cxl_h2d_data_chk,
    input     s_cxl_h2d_data_arr
 , // CX_CXL_MEM_EN
    input     s_cxl_m2s_req_chk ,
    input     s_cxl_m2s_hdr_chk ,
    input     s_cxl_m2s_data_chk,
    input     s_cxl_m2s_data_arr,
    input     s_cxl_m2s_be_chk,
    input     s_cxl_m2s_be_arr    
    ,
    input    s_cxl_m2s_bi_rsp_chk
    ,
    input     s_cxl_d2h_req_chk ,
    input     s_cxl_d2h_rsp_chk ,
    input     s_cxl_d2h_hdr_chk ,
    input     s_cxl_d2h_data_chk,
    input     s_cxl_d2h_data_arr,
    input     s_cxl_d2h_be_chk,
    input     s_cxl_d2h_be_arr
 , // CX_CXL_MEM_EN
    input     s_cxl_s2m_ndr_chk ,
    input     s_cxl_s2m_hdr_chk ,
    input     s_cxl_s2m_data_chk,
    input     s_cxl_s2m_data_arr
    ,
    input    s_cxl_s2m_bi_snp_chk 
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// TX Transaction Layer interface with Host Flit Packer (Inside Packer)
// -------------------------------------------------------------------------------------
modport pack_master_host_mp(
    output  s_cxl_cache_enable,
    output  s_cxl_cache_app_pending
    ,
    output  s_cxl_mem_enable,
    output  s_cxl_mem_app_pending
    ,
    output  s_cxl_h2d_req,
    output  s_cxl_h2d_rsp,
    output  s_cxl_h2d_hdr,
    output  s_cxl_h2d_data_vld,
    output  s_cxl_h2d_data
    ,
    output  s_cxl_m2s_req,
    output  s_cxl_m2s_hdr,
    output  s_cxl_m2s_be,
    output  s_cxl_m2s_be_vld_n,
    output  s_cxl_m2s_data_vld,
    output  s_cxl_m2s_data
    ,
    output s_cxl_m2s_bi_rsp
    ,
    input   s_cxl_h2d_req_halt,
    input   s_cxl_h2d_rsp_halt,
    input   s_cxl_h2d_hdr_halt,
    input   s_cxl_h2d_data_halt
    ,
    input   s_cxl_m2s_req_halt,
    input   s_cxl_m2s_hdr_halt,
    input   s_cxl_m2s_data_halt
    ,
    input  s_cxl_m2s_bi_rsp_halt
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Host Flit Packer interface with TX Transaction Layer (Inside Packer)
// -------------------------------------------------------------------------------------
modport pack_slave_host_mp(
    input   s_cxl_cache_enable,
    input   s_cxl_cache_app_pending
    ,
    input   s_cxl_mem_enable,
    input   s_cxl_mem_app_pending
    ,
    input   s_cxl_h2d_req,
    input   s_cxl_h2d_rsp,
    input   s_cxl_h2d_hdr,
    input   s_cxl_h2d_data_vld,
    input   s_cxl_h2d_data
    ,
    input   s_cxl_m2s_req,
    input   s_cxl_m2s_hdr,
    input   s_cxl_m2s_be,
    input   s_cxl_m2s_be_vld_n,
    input   s_cxl_m2s_data_vld,
    input   s_cxl_m2s_data
    ,
    input  s_cxl_m2s_bi_rsp

    ,
    output  s_cxl_h2d_req_halt,
    output  s_cxl_h2d_rsp_halt,
    output  s_cxl_h2d_hdr_halt,
    output  s_cxl_h2d_data_halt
    ,
    output  s_cxl_m2s_req_halt,
    output  s_cxl_m2s_hdr_halt,
    output  s_cxl_m2s_data_halt
    ,
    output s_cxl_m2s_bi_rsp_halt
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// TX Transaction Layer interface with Device Flit Packer (Inside Packer)
// -------------------------------------------------------------------------------------
modport pack_master_dev_mp(
    output  s_cxl_cache_enable,
    output  s_cxl_cache_app_pending
    ,
    output  s_cxl_mem_enable,
    output  s_cxl_mem_app_pending
    ,
    output  s_cxl_d2h_req,
    output  s_cxl_d2h_rsp,
    output  s_cxl_d2h_hdr,
    output  s_cxl_d2h_be,
    output  s_cxl_d2h_be_vld_n,
    output  s_cxl_d2h_data_vld,
    output  s_cxl_d2h_data
    ,
    output  s_cxl_s2m_ndr,
    output  s_cxl_s2m_hdr,
    output  s_cxl_s2m_data_vld,
    output  s_cxl_s2m_data
    ,
    output s_cxl_s2m_bi_snp

    ,
    input   s_cxl_d2h_req_halt,
    input   s_cxl_d2h_rsp_halt,
    input   s_cxl_d2h_hdr_halt,
    input   s_cxl_d2h_data_halt
    ,
    input   s_cxl_s2m_ndr_halt,
    input   s_cxl_s2m_hdr_halt,
    input   s_cxl_s2m_data_halt
    ,
    input  s_cxl_s2m_bi_snp_halt
);
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Device Flit Packer interface with TX Transaction Layer (Inside Packer)
// -------------------------------------------------------------------------------------
modport pack_slave_dev_mp(
    input   s_cxl_cache_enable,
    input   s_cxl_cache_app_pending
    ,
    input   s_cxl_mem_enable,
    input  s_cxl_mem_app_pending
    ,
    input   s_cxl_d2h_req,
    input   s_cxl_d2h_rsp,
    input   s_cxl_d2h_hdr,
    input   s_cxl_d2h_be,
    input   s_cxl_d2h_be_vld_n,
    input   s_cxl_d2h_data_vld,
    input   s_cxl_d2h_data
    ,
    input   s_cxl_s2m_ndr,
    input   s_cxl_s2m_hdr,
    input   s_cxl_s2m_data_vld,
    input   s_cxl_s2m_data
    ,
    input  s_cxl_s2m_bi_snp

    ,
    output  s_cxl_d2h_req_halt,
    output  s_cxl_d2h_rsp_halt,
    output  s_cxl_d2h_hdr_halt,
    output  s_cxl_d2h_data_halt
    ,
    output  s_cxl_s2m_ndr_halt,
    output  s_cxl_s2m_hdr_halt,
    output  s_cxl_s2m_data_halt
    ,
    output s_cxl_s2m_bi_snp_halt
);

endinterface : DWC_cxl_txtl_llctrl_if

`endif // __GUARD__DWC_CXL_TXTL_LLCTRL_IF__SVH__
