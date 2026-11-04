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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/06/26 08:32:07 $
// ---   $Revision: #1 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rx_rasdp_wr_ms.sv#1 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Receiver RASDP Wrapper Module for Multistream Architecture
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_rx_rasdp_wr_ms
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
 )(
    // Clock and Reset
      input                                          core_clk             // Core clock
    ,input                                           core_rst_n           // Core active low asynchronous reset
    ,DWC_cxl_rxtl_llctrl_if.slave_mp                 b_rxdl_llctrl        // RASDP Wrapper - Link Layer Interface for Host Channels
    ,DWC_cxl_rxtl_llctrl_if.master_rasdp_mp          b_rxtl_llctrl        // Transaction Layer - RASDP Wrapper Interface for Host Channels
);

// -------------------------------------------------------------------------------------
// TL Interface
// -------------------------------------------------------------------------------------
logic                  [H2D_REQ_SIZE-1:0]       cxl_dltl_h2d_req [0:H2D_REQ_NUM-1]              ; //H2D Request channels
logic                  [H2D_RESP_SIZE-1:0]      cxl_dltl_h2d_resp [0:H2D_RESP_NUM-1]            ; //H2D Response Channels
logic                  [H2D_DHDR_SIZE-1:0]      cxl_dltl_h2d_dhr [0:H2D_DDATA_NUM-1]            ; // H2D Data Header Channels
logic                  [H2D_DDATA_SIZE-1:0]     cxl_dltl_h2d_data [0:H2D_DDATA_NUM-1]           ; //H2D Data Channels
logic                  [H2D_DDATA_NUM-1:0]      cxl_dltl_h2d_data_valid                         ; // Valid Signal for H2D Data Channels

logic                  [D2H_REQ_SIZE-1:0]       cxl_dltl_d2h_req [0:D2H_REQ_NUM-1]              ; // D2H Request Channels
logic                  [D2H_RESP_SIZE-1:0]      cxl_dltl_d2h_resp [0:D2H_RESP_NUM-1]            ; // D2H Response Channels
logic                  [D2H_DHDR_SIZE-1:0]      cxl_dltl_d2h_dhr [0:D2H_DDATA_NUM-1]            ; // D2H Data Header Channels
logic                  [D2H_DDATA_SIZE-1:0]     cxl_dltl_d2h_data [0:D2H_DDATA_NUM-1]           ; // D2H Data Channels
logic                  [D2H_DDATA_NUM-1:0]      cxl_dltl_d2h_data_valid                         ; // Valid Signal for D2H Data Channels
logic                  [D2H_DBE_SIZE-1:0]       cxl_dltl_d2h_byte_en [0:D2H_DDATA_NUM-1]        ; // D2H Data Byte Enables for 512 bit D2H data
logic                  [D2H_DDATA_NUM-1:0]      cxl_dltl_d2h_byte_en_valid                      ; // Byte Enable Valid Signal for D2H Data

logic                  [M2S_DDATA_SIZE-1:0]     cxl_dltl_m2s_data [0:M2S_DDATA_NUM-1]           ; // M2S Data Channels
logic                  [M2S_DDATA_NUM-1:0]      cxl_dltl_m2s_data_valid                         ; // Valid Signal for M2S Data Channels
logic                  [M2S_DHDR_SIZE-1:0]      cxl_dltl_m2s_dhr [0:M2S_DDATA_NUM-1]            ; // M2S Data Header Channels
logic                  [M2S_DBE_SIZE-1:0]       cxl_dltl_m2s_byte_en [0:M2S_DDATA_NUM-1]        ; // M2S Data Byte Enables for 512 bit M2S data
logic                  [M2S_DDATA_NUM-1:0]      cxl_dltl_m2s_byte_en_valid                      ; // Byte Enable Valid Signal for M2S Data
logic                  [M2S_NDR_SIZE-1:0]       cxl_dltl_m2s_req [0:M2S_NDR_NUM-1]              ; // M2S Request Channels

logic                  [S2M_NDR_SIZE-1:0]       cxl_dltl_s2m_ndr [0:S2M_NDR_NUM-1]              ; // S2M No Data Response Channels    
logic                  [S2M_DHDR_SIZE-1:0]      cxl_dltl_s2m_drs [0:S2M_DDATA_NUM-1]            ; // S2M Data Response Channels     
logic                  [S2M_DDATA_SIZE-1:0]     cxl_dltl_s2m_data [0:S2M_DDATA_NUM-1]           ; // S2M Data Channels
logic                  [S2M_DDATA_NUM-1:0]      cxl_dltl_s2m_data_valid                         ; // Valid Signal for S2M Data Channels

logic                  [M2S_BI_RSP_SIZE-1:0]    cxl_dltl_m2s_bi_rsp [0:M2S_BI_RSP_NUM-1]        ;

logic                  [S2M_BI_SNP_SIZE-1:0]    cxl_dltl_s2m_bi_snp [0:S2M_BI_SNP_NUM-1]        ;

// Outputs
logic                 [H2D_REQ_SIZE-1:0]       cxl_rasdp_h2d_req [0:H2D_REQ_NUM-1]              ; // H2D Request Channels
logic                 [H2D_RESP_SIZE-1:0]      cxl_rasdp_h2d_resp [0:H2D_RESP_NUM-1]            ; // H2D Response Channels
logic                 [H2D_DHDR_SIZE-1:0]      cxl_rasdp_h2d_dhr [0:H2D_DDATA_NUM-1]            ; // H2D Data Header Channels
logic                 [H2D_DDATA_SIZE-1:0]     cxl_rasdp_h2d_data [0:H2D_DDATA_NUM-1]           ; // H2D Data Channels
logic                 [H2D_DDATA_NUM-1:0]      cxl_rasdp_h2d_data_valid                         ; // Valid Signal for H2D Data Channels

logic                 [H2D_REQ_CHK_SIZE-1:0]   cxl_rasdp_h2d_req_chk [0:H2D_REQ_NUM-1]          ;
logic                 [H2D_RESP_CHK_SIZE-1:0]  cxl_rasdp_h2d_resp_chk [0:H2D_RESP_NUM-1]        ;
logic                 [H2D_DHDR_CHK_SIZE-1:0]  cxl_rasdp_h2d_dhr_chk [0:H2D_DDATA_NUM-1]        ;
logic                 [H2D_DDATA_CHK_SIZE-1:0] cxl_rasdp_h2d_data_chk [0:H2D_DDATA_NUM-1]       ;
logic                 [H2D_DDATA_NUM-1:0]      cxl_rasdp_h2d_data_valid_inv                     ;
  
logic                 [D2H_REQ_SIZE-1:0]       cxl_rasdp_d2h_req [0:D2H_REQ_NUM-1]              ; // D2H Request Channels
logic                 [D2H_RESP_SIZE-1:0]      cxl_rasdp_d2h_resp [0:D2H_RESP_NUM-1]            ; // D2H Response Ch
logic                 [D2H_DHDR_SIZE-1:0]      cxl_rasdp_d2h_dhr [0:D2H_DDATA_NUM-1]            ; // D2H Data Header Channels
logic                 [D2H_DDATA_SIZE-1:0]     cxl_rasdp_d2h_data [0:D2H_DDATA_NUM-1]           ; // D2H Data Channels
logic                 [D2H_DDATA_NUM-1:0]      cxl_rasdp_d2h_data_valid                         ; // Valid Signal for D2H Data Channels
logic                 [D2H_DBE_SIZE-1:0]       cxl_rasdp_d2h_byte_en [0:D2H_DDATA_NUM-1]        ; // D2H Data Byte Enables for 512 bit D2H data
logic                 [D2H_DDATA_NUM-1:0]      cxl_rasdp_d2h_byte_en_valid                      ; // Byte Enable Valid Signal for D2H Data

logic                 [D2H_REQ_CHK_SIZE-1:0]   cxl_rasdp_d2h_req_chk [0:D2H_REQ_NUM-1]          ;
logic                 [D2H_RESP_CHK_SIZE-1:0]  cxl_rasdp_d2h_resp_chk [0:D2H_RESP_NUM-1]        ;
logic                 [D2H_DHDR_CHK_SIZE-1:0]  cxl_rasdp_d2h_dhr_chk [0:D2H_DDATA_NUM-1]        ;
logic                 [D2H_DDATA_CHK_SIZE-1:0] cxl_rasdp_d2h_data_chk [0:D2H_DDATA_NUM-1]       ;
logic                 [D2H_DDATA_NUM-1:0]      cxl_rasdp_d2h_data_valid_inv                     ;
logic                 [D2H_DBE_CHK_SIZE-1:0]   cxl_rasdp_d2h_byte_en_chk [0:D2H_DDATA_NUM-1]    ;
logic                 [D2H_DDATA_NUM-1:0]      cxl_rasdp_d2h_byte_en_valid_inv                  ;
 
logic                 [M2S_DDATA_SIZE-1:0]     cxl_rasdp_m2s_data [0:M2S_DDATA_NUM-1]           ; // M2S Data Channels
logic                 [M2S_DDATA_NUM-1:0]      cxl_rasdp_m2s_data_valid                         ; // Valid Signal for M2S Data Channel
logic                 [M2S_DHDR_SIZE-1:0]      cxl_rasdp_m2s_dhr [0:M2S_DDATA_NUM-1]            ; // M2S Data Header Channels
logic                 [M2S_DBE_SIZE-1:0]       cxl_rasdp_m2s_byte_en [0:M2S_DDATA_NUM-1]        ; // M2S Data Byte Enables for 512 bit M2S data
logic                 [M2S_DDATA_NUM-1:0]      cxl_rasdp_m2s_byte_en_valid                      ; // Byte Enable Valid Signal for M2S Data
logic                 [M2S_NDR_SIZE-1:0]       cxl_rasdp_m2s_req [0:M2S_NDR_NUM-1]              ; // M2S Request Channels
  
logic                 [M2S_NDR_CHK_SIZE-1:0]   cxl_rasdp_m2s_req_chk [0:M2S_NDR_NUM-1]          ;
logic                 [M2S_DHDR_CHK_SIZE-1:0]  cxl_rasdp_m2s_dhr_chk [0:M2S_DDATA_NUM-1]        ;
logic                 [M2S_DDATA_CHK_SIZE-1:0] cxl_rasdp_m2s_data_chk [0:M2S_DDATA_NUM-1]       ;
logic                 [M2S_DDATA_NUM-1:0]      cxl_rasdp_m2s_data_valid_inv                     ;
logic                 [M2S_DBE_CHK_SIZE-1:0]   cxl_rasdp_m2s_byte_en_chk [0:M2S_DDATA_NUM-1]    ;
logic                 [M2S_DDATA_NUM-1:0]      cxl_rasdp_m2s_byte_en_valid_inv                  ;
  
logic                 [S2M_NDR_SIZE-1:0]       cxl_rasdp_s2m_ndr [0:S2M_NDR_NUM-1]              ; // S2M No Data Response Channels
logic                 [S2M_DHDR_SIZE-1:0]      cxl_rasdp_s2m_drs [0:S2M_DDATA_NUM-1]             ; // S2M Data Response Channels
logic                 [S2M_DDATA_SIZE-1:0]     cxl_rasdp_s2m_data [0:S2M_DDATA_NUM-1]           ; // S2M Data Channels
logic                 [S2M_DDATA_NUM-1:0]      cxl_rasdp_s2m_data_valid; // Valid Signal for S2M Data Channels

logic                 [S2M_NDR_CHK_SIZE-1:0]   cxl_rasdp_s2m_ndr_chk [0:S2M_NDR_NUM-1]          ;
logic                 [S2M_DHDR_CHK_SIZE-1:0]  cxl_rasdp_s2m_drs_chk [0:S2M_DDATA_NUM-1]         ;
logic                 [S2M_DDATA_CHK_SIZE-1:0] cxl_rasdp_s2m_data_chk [0:S2M_DDATA_NUM-1]       ;
logic                 [S2M_DDATA_NUM-1:0]      cxl_rasdp_s2m_data_valid_inv                     ;
  
logic                 [M2S_BI_RSP_SIZE-1:0]        cxl_rasdp_m2s_bi_rsp [0:M2S_BI_RSP_NUM-1]    ;

logic                 [M2S_BI_RSP_CHK_SIZE-1:0]    cxl_rasdp_m2s_bi_rsp_chk [0:M2S_BI_RSP_NUM-1];

logic                 [S2M_BI_SNP_SIZE-1:0]        cxl_rasdp_s2m_bi_snp [0:S2M_BI_SNP_NUM-1]    ;

logic                 [S2M_BI_SNP_CHK_SIZE-1:0]    cxl_rasdp_s2m_bi_snp_chk [0:S2M_BI_SNP_NUM-1];


assign cxl_dltl_h2d_req           = b_rxdl_llctrl.s_cxl_h2d_req            ; 
assign cxl_dltl_h2d_resp          = b_rxdl_llctrl.s_cxl_h2d_resp           ;              
assign cxl_dltl_h2d_dhr           = b_rxdl_llctrl.s_cxl_h2d_dhr            ;              
assign cxl_dltl_h2d_data          = b_rxdl_llctrl.s_cxl_h2d_data           ;
assign cxl_dltl_h2d_data_valid    = b_rxdl_llctrl.s_cxl_h2d_data_valid     ;
assign cxl_dltl_d2h_req           = b_rxdl_llctrl.s_cxl_d2h_req            ;          
assign cxl_dltl_d2h_resp          = b_rxdl_llctrl.s_cxl_d2h_resp           ;         
assign cxl_dltl_d2h_dhr           = b_rxdl_llctrl.s_cxl_d2h_dhr            ;          
assign cxl_dltl_d2h_data          = b_rxdl_llctrl.s_cxl_d2h_data           ; 
assign cxl_dltl_d2h_data_valid    = b_rxdl_llctrl.s_cxl_d2h_data_valid     ;
assign cxl_dltl_d2h_byte_en       = b_rxdl_llctrl.s_cxl_d2h_byte_en        ; 
assign cxl_dltl_d2h_byte_en_valid = b_rxdl_llctrl.s_cxl_d2h_byte_en_valid  ;
assign cxl_dltl_m2s_data          = b_rxdl_llctrl.s_cxl_m2s_data           ; 
assign cxl_dltl_m2s_data_valid    = b_rxdl_llctrl.s_cxl_m2s_data_valid     ; 
assign cxl_dltl_m2s_dhr           = b_rxdl_llctrl.s_cxl_m2s_dhr            ; 
assign cxl_dltl_m2s_byte_en       = b_rxdl_llctrl.s_cxl_m2s_byte_en        ; 
assign cxl_dltl_m2s_byte_en_valid = b_rxdl_llctrl.s_cxl_m2s_byte_en_valid  ; 
assign cxl_dltl_m2s_req           = b_rxdl_llctrl.s_cxl_m2s_req            ; 
assign cxl_dltl_s2m_ndr           = b_rxdl_llctrl.s_cxl_s2m_ndr            ;         
assign cxl_dltl_s2m_drs           = b_rxdl_llctrl.s_cxl_s2m_drs            ;          
assign cxl_dltl_s2m_data          = b_rxdl_llctrl.s_cxl_s2m_data           ;
assign cxl_dltl_s2m_data_valid    = b_rxdl_llctrl.s_cxl_s2m_data_valid     ;
assign cxl_dltl_m2s_bi_rsp         = b_rxdl_llctrl.s_cxl_m2s_bi_rsp        ;
assign cxl_dltl_s2m_bi_snp        = b_rxdl_llctrl.s_cxl_s2m_bi_snp         ;

// Outputs
assign b_rxtl_llctrl.s_cxl_h2d_req               = cxl_rasdp_h2d_req              ;            
assign b_rxtl_llctrl.s_cxl_h2d_resp              = cxl_rasdp_h2d_resp             ;            
assign b_rxtl_llctrl.s_cxl_h2d_dhr               = cxl_rasdp_h2d_dhr              ;           
assign b_rxtl_llctrl.s_cxl_h2d_data              = cxl_rasdp_h2d_data             ; 
assign b_rxtl_llctrl.s_cxl_h2d_data_valid        = cxl_rasdp_h2d_data_valid       ; 
assign b_rxtl_llctrl.s_cxl_h2d_req_chk           = cxl_rasdp_h2d_req_chk          ; 
assign b_rxtl_llctrl.s_cxl_h2d_resp_chk          = cxl_rasdp_h2d_resp_chk         ;   
assign b_rxtl_llctrl.s_cxl_h2d_dhr_chk           = cxl_rasdp_h2d_dhr_chk          ;           
assign b_rxtl_llctrl.s_cxl_h2d_data_chk          = cxl_rasdp_h2d_data_chk         ; 
assign b_rxtl_llctrl.s_cxl_h2d_data_valid_chk    = cxl_rasdp_h2d_data_valid_inv   ;   

assign b_rxtl_llctrl.s_cxl_d2h_req               = cxl_rasdp_d2h_req              ;          
assign b_rxtl_llctrl.s_cxl_d2h_resp              = cxl_rasdp_d2h_resp             ;         
assign b_rxtl_llctrl.s_cxl_d2h_dhr               = cxl_rasdp_d2h_dhr              ;        
assign b_rxtl_llctrl.s_cxl_d2h_data              = cxl_rasdp_d2h_data             ;
assign b_rxtl_llctrl.s_cxl_d2h_data_valid        = cxl_rasdp_d2h_data_valid       ;
assign b_rxtl_llctrl.s_cxl_d2h_byte_en           = cxl_rasdp_d2h_byte_en          ;
assign b_rxtl_llctrl.s_cxl_d2h_byte_en_valid     = cxl_rasdp_d2h_byte_en_valid    ; 
assign b_rxtl_llctrl.s_cxl_d2h_req_chk           = cxl_rasdp_d2h_req_chk          ;    
assign b_rxtl_llctrl.s_cxl_d2h_resp_chk          = cxl_rasdp_d2h_resp_chk         ;    
assign b_rxtl_llctrl.s_cxl_d2h_dhr_chk           = cxl_rasdp_d2h_dhr_chk          ;   
assign b_rxtl_llctrl.s_cxl_d2h_data_chk          = cxl_rasdp_d2h_data_chk         ;  
assign b_rxtl_llctrl.s_cxl_d2h_data_valid_chk    = cxl_rasdp_d2h_data_valid_inv   ;     
assign b_rxtl_llctrl.s_cxl_d2h_byte_en_chk       = cxl_rasdp_d2h_byte_en_chk      ;  
assign b_rxtl_llctrl.s_cxl_d2h_byte_en_valid_chk = cxl_rasdp_d2h_byte_en_valid_inv;  

assign b_rxtl_llctrl.s_cxl_m2s_data              = cxl_rasdp_m2s_data             ;
assign b_rxtl_llctrl.s_cxl_m2s_data_valid        = cxl_rasdp_m2s_data_valid       ;
assign b_rxtl_llctrl.s_cxl_m2s_dhr               = cxl_rasdp_m2s_dhr              ;
assign b_rxtl_llctrl.s_cxl_m2s_byte_en           = cxl_rasdp_m2s_byte_en          ;
assign b_rxtl_llctrl.s_cxl_m2s_byte_en_valid     = cxl_rasdp_m2s_byte_en_valid    ;
assign b_rxtl_llctrl.s_cxl_m2s_req               = cxl_rasdp_m2s_req              ;    
assign b_rxtl_llctrl.s_cxl_m2s_req_chk           = cxl_rasdp_m2s_req_chk          ; 
assign b_rxtl_llctrl.s_cxl_m2s_dhr_chk           = cxl_rasdp_m2s_dhr_chk          ;  
assign b_rxtl_llctrl.s_cxl_m2s_data_chk          = cxl_rasdp_m2s_data_chk         ;  
assign b_rxtl_llctrl.s_cxl_m2s_data_valid_chk    = cxl_rasdp_m2s_data_valid_inv   ;    
assign b_rxtl_llctrl.s_cxl_m2s_byte_en_chk       = cxl_rasdp_m2s_byte_en_chk      ;  
assign b_rxtl_llctrl.s_cxl_m2s_byte_en_valid_chk = cxl_rasdp_m2s_byte_en_valid_inv;  

assign b_rxtl_llctrl.s_cxl_s2m_ndr               = cxl_rasdp_s2m_ndr              ;     
assign b_rxtl_llctrl.s_cxl_s2m_drs               = cxl_rasdp_s2m_drs              ;      
assign b_rxtl_llctrl.s_cxl_s2m_data              = cxl_rasdp_s2m_data             ;
assign b_rxtl_llctrl.s_cxl_s2m_data_valid        = cxl_rasdp_s2m_data_valid       ; 
assign b_rxtl_llctrl.s_cxl_s2m_ndr_chk           = cxl_rasdp_s2m_ndr_chk          ;   
assign b_rxtl_llctrl.s_cxl_s2m_drs_chk           = cxl_rasdp_s2m_drs_chk          ;              
assign b_rxtl_llctrl.s_cxl_s2m_data_chk          = cxl_rasdp_s2m_data_chk         ;   
assign b_rxtl_llctrl.s_cxl_s2m_data_valid_chk    = cxl_rasdp_s2m_data_valid_inv   ;   

assign b_rxtl_llctrl.s_cxl_m2s_bi_rsp            = cxl_rasdp_m2s_bi_rsp           ;
assign b_rxtl_llctrl.s_cxl_m2s_bi_rsp_chk        = cxl_rasdp_m2s_bi_rsp_chk       ;
assign b_rxtl_llctrl.s_cxl_s2m_bi_snp            = cxl_rasdp_s2m_bi_snp           ;
assign b_rxtl_llctrl.s_cxl_s2m_bi_snp_chk        = cxl_rasdp_s2m_bi_snp_chk       ;




localparam H2D_REQ_PAD_ZEROS = (H2D_REQ_CHK_SIZE/CX_CXL_CHI_PROT_RANGE_WIDTH)*CX_CXL_CHI_PROT_RANGE-H2D_REQ_SIZE;
localparam H2D_REQ_DATA_WD   = H2D_REQ_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

wire    [H2D_REQ_DATA_WD-1:0]       cxl_rasdp_h2d_req_int [0:H2D_REQ_NUM-1];

generate
for(genvar i = 0; i < H2D_REQ_NUM; i++) begin: bus_protect_gen_h2d_request_channels

assign cxl_rasdp_h2d_req[i] = cxl_rasdp_h2d_req_int[i][H2D_REQ_DATA_WD-1:H2D_REQ_PAD_ZEROS];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( H2D_REQ_DATA_WD         ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( H2D_REQ_CHK_SIZE        ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_h2d_req_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( {cxl_dltl_h2d_req[i],{(H2D_REQ_PAD_ZEROS){1'b0}}} ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_h2d_req_int[i]                          ),
    .dout_prot                 ( cxl_rasdp_h2d_req_chk[i]                          ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate

localparam H2D_RESP_PAD_ZEROS = (H2D_RESP_CHK_SIZE/CX_CXL_CHI_PROT_RANGE_WIDTH)*CX_CXL_CHI_PROT_RANGE-H2D_RESP_SIZE;
localparam H2D_RESP_DATA_WD = H2D_RESP_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

wire    [H2D_RESP_DATA_WD-1:0]       cxl_rasdp_h2d_resp_int [0:H2D_RESP_NUM-1];

generate
for(genvar i = 0; i < H2D_RESP_NUM; i++) begin: bus_protect_gen_h2d_response_channels

assign cxl_rasdp_h2d_resp[i] = cxl_rasdp_h2d_resp_int[i][H2D_RESP_DATA_WD-1:H2D_RESP_PAD_ZEROS];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( H2D_RESP_DATA_WD        ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( H2D_RESP_CHK_SIZE       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_h2d_resp_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( {cxl_dltl_h2d_resp[i],{(H2D_RESP_PAD_ZEROS){1'b0}}} ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_h2d_resp_int[i]                           ),
    .dout_prot                 ( cxl_rasdp_h2d_resp_chk[i]                           ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate


localparam H2D_DHDR_PAD_ZEROS = (H2D_DHDR_CHK_SIZE/CX_CXL_CHI_PROT_RANGE_WIDTH)*CX_CXL_CHI_PROT_RANGE-H2D_DHDR_SIZE;
localparam H2D_DHDR_DATA_WD = H2D_DHDR_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

wire    [H2D_DHDR_DATA_WD-1:0]       cxl_rasdp_h2d_dhr_int [0:H2D_DDATA_NUM-1];

generate
for(genvar i = 0; i < H2D_DDATA_NUM; i++) begin : bus_protect_gen_h2d_data_header_channels

assign cxl_rasdp_h2d_dhr[i] = cxl_rasdp_h2d_dhr_int[i][H2D_DHDR_DATA_WD-1:H2D_DHDR_PAD_ZEROS];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( H2D_DHDR_DATA_WD        ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( H2D_DHDR_CHK_SIZE       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_h2d_dhr_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( {cxl_dltl_h2d_dhr[i],{(H2D_DHDR_PAD_ZEROS){1'b0}}} ),
    .din_prot                  ( '0                                                 ),
    .dout                      ( cxl_rasdp_h2d_dhr_int[i]                           ),
    .dout_prot                 ( cxl_rasdp_h2d_dhr_chk[i]                           ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate

 
localparam H2D_DDATA_DATA_WD = H2D_DDATA_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

generate
for(genvar i = 0; i < H2D_DDATA_NUM; i++) begin : bus_protect_gen_h2d_data_channels
ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( H2D_DDATA_DATA_WD       ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( H2D_DDATA_CHK_SIZE      ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_h2d_data_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( cxl_dltl_h2d_data[i]                              ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_h2d_data[i]                             ),
    .dout_prot                 ( cxl_rasdp_h2d_data_chk[i]                         ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( cxl_dltl_h2d_data_valid[i]                        ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( cxl_rasdp_h2d_data_valid[i]                       ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate

generate
for(genvar i = 0; i < H2D_DDATA_NUM; i++) begin : delay_n_h2d_data_valid_channels
delay_n
 #(
    .N        (1),
    .WD       (1),
    .RESETVAL (1'b1)
) u_h2d_data_valid_inv_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (!cxl_dltl_h2d_data_valid[i]),
    .dout  (cxl_rasdp_h2d_data_valid_inv[i])
);
end
endgenerate




localparam M2S_NDR_PAD_ZEROS = (M2S_NDR_CHK_SIZE/CX_CXL_CHI_PROT_RANGE_WIDTH)*CX_CXL_CHI_PROT_RANGE-M2S_NDR_SIZE;
localparam M2S_NDR_DATA_WD = M2S_NDR_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

wire   [M2S_NDR_DATA_WD-1:0]      cxl_rasdp_m2s_req_int [0:M2S_NDR_NUM-1];

generate
for(genvar i = 0; i < M2S_NDR_NUM; i++) begin : bus_protect_gen_m2s_request_channels

assign cxl_rasdp_m2s_req[i] = cxl_rasdp_m2s_req_int[i][M2S_NDR_DATA_WD-1:M2S_NDR_PAD_ZEROS];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( M2S_NDR_DATA_WD        ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( M2S_NDR_CHK_SIZE       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_m2s_ndr_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( {cxl_dltl_m2s_req[i],{(M2S_NDR_PAD_ZEROS){1'b0}}} ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_m2s_req_int[i]                          ),
    .dout_prot                 ( cxl_rasdp_m2s_req_chk[i]                          ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate


localparam M2S_DHDR_PAD_ZEROS = (M2S_DHDR_CHK_SIZE/CX_CXL_CHI_PROT_RANGE_WIDTH)*CX_CXL_CHI_PROT_RANGE-M2S_DHDR_SIZE;
localparam M2S_DHDR_DATA_WD = M2S_DHDR_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

wire    [M2S_DHDR_DATA_WD-1:0]       cxl_rasdp_m2s_dhr_int [0:M2S_DDATA_NUM-1];
 
generate
for(genvar i = 0; i < M2S_DDATA_NUM; i++) begin : bus_protect_gen_m2s_data_header_channels

assign cxl_rasdp_m2s_dhr[i] = cxl_rasdp_m2s_dhr_int[i][M2S_DHDR_DATA_WD-1:M2S_DHDR_PAD_ZEROS];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( M2S_DHDR_DATA_WD        ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( M2S_DHDR_CHK_SIZE       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_m2s_dhr_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( {cxl_dltl_m2s_dhr[i],{(M2S_DHDR_PAD_ZEROS){1'b0}}} ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_m2s_dhr_int[i]                           ),
    .dout_prot                 ( cxl_rasdp_m2s_dhr_chk[i]                           ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate


localparam M2S_DDATA_DATA_WD = M2S_DDATA_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

generate
for(genvar i = 0; i < M2S_DDATA_NUM; i++) begin : bus_protect_gen_m2s_data_channels
ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( M2S_DDATA_DATA_WD       ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( M2S_DDATA_CHK_SIZE      ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_m2s_data_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( cxl_dltl_m2s_data[i]                              ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_m2s_data[i]                             ),
    .dout_prot                 ( cxl_rasdp_m2s_data_chk[i]                         ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( cxl_dltl_m2s_data_valid[i]                        ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( cxl_rasdp_m2s_data_valid[i]                       ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate

generate
for(genvar i = 0; i < M2S_DDATA_NUM; i++) begin : delay_n_m2s_data_valid_channels
delay_n
 #(
    .N        (1),
    .WD       (1),
    .RESETVAL (1'b1)
) u_m2s_data_valid_inv_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (!cxl_dltl_m2s_data_valid[i]),
    .dout  (cxl_rasdp_m2s_data_valid_inv[i])
);
end
endgenerate

localparam M2S_DBE_DATA_WD = M2S_DBE_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

generate
for(genvar i = 0; i < M2S_DDATA_NUM; i++) begin : bus_protect_gen_m2s_byte_enable_channels
ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( M2S_DBE_DATA_WD        ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( M2S_DBE_CHK_SIZE       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_m2s_byte_en_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( cxl_dltl_m2s_byte_en[i]                           ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_m2s_byte_en[i]                          ),
    .dout_prot                 ( cxl_rasdp_m2s_byte_en_chk[i]                      ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( cxl_dltl_m2s_byte_en_valid[i]                     ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( cxl_rasdp_m2s_byte_en_valid[i]                    ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate

generate
for(genvar i = 0; i < M2S_DDATA_NUM; i++) begin : delay_n_m2s_byte_enable_valid_channels
delay_n
 #(
    .N        (1),
    .WD       (1),
    .RESETVAL (1'b1)
) u_m2s__byte_en_valid_inv_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (!cxl_dltl_m2s_byte_en_valid[i]),
    .dout  (cxl_rasdp_m2s_byte_en_valid_inv[i])
);
end
endgenerate


localparam M2S_BI_RSP_PAD_ZEROS = (M2S_BI_RSP_CHK_SIZE/CX_CXL_CHI_PROT_RANGE_WIDTH)*CX_CXL_CHI_PROT_RANGE-M2S_BI_RSP_SIZE;
localparam M2S_BI_RSP_DATA_WD   = M2S_BI_RSP_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

wire   [M2S_BI_RSP_DATA_WD-1:0]      cxl_rasdp_m2s_bi_rsp_int [0:M2S_BI_RSP_NUM-1];

generate
for(genvar i = 0; i < M2S_BI_RSP_NUM; i++) begin : bus_protect_gen_m2s_back_invalidate_response_channels

assign cxl_rasdp_m2s_bi_rsp[i] = cxl_rasdp_m2s_bi_rsp_int[i][M2S_BI_RSP_DATA_WD-1:M2S_BI_RSP_PAD_ZEROS];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( M2S_BI_RSP_DATA_WD      ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( M2S_BI_RSP_CHK_SIZE     ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_m2s_bi_rsp_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( {cxl_dltl_m2s_bi_rsp[i],{(M2S_BI_RSP_PAD_ZEROS){1'b0}}} ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_m2s_bi_rsp_int[i]                       ),
    .dout_prot                 ( cxl_rasdp_m2s_bi_rsp_chk[i]                       ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate




localparam D2H_RESP_PAD_ZEROS = (D2H_RESP_CHK_SIZE/CX_CXL_CHI_PROT_RANGE_WIDTH)*CX_CXL_CHI_PROT_RANGE-D2H_RESP_SIZE;
localparam D2H_RESP_DATA_WD   = D2H_RESP_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

wire    [D2H_RESP_DATA_WD-1:0]       cxl_rasdp_d2h_resp_int [0:D2H_RESP_NUM-1];

generate
for(genvar i = 0; i < D2H_RESP_NUM; i++) begin : bus_protect_gen_d2h_response_channels

assign cxl_rasdp_d2h_resp[i] = cxl_rasdp_d2h_resp_int[i][D2H_RESP_DATA_WD-1:D2H_RESP_PAD_ZEROS];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( D2H_RESP_DATA_WD        ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( D2H_RESP_CHK_SIZE       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_d2h_resp_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( {cxl_dltl_d2h_resp[i],{(D2H_RESP_PAD_ZEROS){1'b0}}} ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_d2h_resp_int[i]                         ),
    .dout_prot                 ( cxl_rasdp_d2h_resp_chk[i]                         ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate


localparam D2H_REQ_PAD_ZEROS = (D2H_REQ_CHK_SIZE/CX_CXL_CHI_PROT_RANGE_WIDTH)*CX_CXL_CHI_PROT_RANGE-D2H_REQ_SIZE;
localparam D2H_REQ_DATA_WD = D2H_REQ_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

wire    [D2H_REQ_DATA_WD-1:0]       cxl_rasdp_d2h_req_int [0:D2H_REQ_NUM-1];

generate
for(genvar i = 0; i < D2H_REQ_NUM; i++) begin : bus_protect_gen_d2h_request_channels

assign cxl_rasdp_d2h_req[i] = cxl_rasdp_d2h_req_int[i][D2H_REQ_DATA_WD-1:D2H_REQ_PAD_ZEROS];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( D2H_REQ_DATA_WD        ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( D2H_REQ_CHK_SIZE       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_d2h_req_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( {cxl_dltl_d2h_req[i],{(D2H_REQ_PAD_ZEROS){1'b0}}} ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_d2h_req_int[i]                          ),
    .dout_prot                 ( cxl_rasdp_d2h_req_chk[i]                          ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate


localparam D2H_DHDR_PAD_ZEROS = (D2H_DHDR_CHK_SIZE/CX_CXL_CHI_PROT_RANGE_WIDTH)*CX_CXL_CHI_PROT_RANGE-D2H_DHDR_SIZE;
localparam D2H_DHDR_DATA_WD = D2H_DHDR_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

wire    [D2H_DHDR_DATA_WD-1:0]       cxl_rasdp_d2h_dhr_int [0:D2H_DDATA_NUM-1];
 
generate
for(genvar i = 0; i < D2H_DDATA_NUM; i++) begin : bus_protect_gen_d2h_data_header_channels

assign cxl_rasdp_d2h_dhr[i] = cxl_rasdp_d2h_dhr_int[i][D2H_DHDR_DATA_WD-1:D2H_DHDR_PAD_ZEROS];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( D2H_DHDR_DATA_WD        ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( D2H_DHDR_CHK_SIZE       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_d2h_dhr_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( {cxl_dltl_d2h_dhr[i],{(D2H_DHDR_PAD_ZEROS){1'b0}}} ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_d2h_dhr_int[i]                          ),
    .dout_prot                 ( cxl_rasdp_d2h_dhr_chk[i]                          ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate

 
localparam D2H_DDATA_DATA_WD = D2H_DDATA_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

generate
for(genvar i = 0; i < D2H_DDATA_NUM; i++) begin : bus_protect_gen_d2h_data_channels
ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( D2H_DDATA_DATA_WD        ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( D2H_DDATA_CHK_SIZE       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_d2h_data_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( cxl_dltl_d2h_data[i]                              ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_d2h_data[i]                             ),
    .dout_prot                 ( cxl_rasdp_d2h_data_chk[i]                         ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( cxl_dltl_d2h_data_valid[i]                        ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( cxl_rasdp_d2h_data_valid[i]                       ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate

generate
for(genvar i = 0; i < D2H_DDATA_NUM; i++) begin : delay_n_d2h_data_valid_channels
delay_n
 #(
    .N        (1),
    .WD       (1),
    .RESETVAL (1'b1)
) u_d2h_data_valid_inv_reg(
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (!cxl_dltl_d2h_data_valid[i]),
    .dout  (cxl_rasdp_d2h_data_valid_inv[i])
);
end
endgenerate

localparam D2H_DBE_DATA_WD = D2H_DBE_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;
 
generate
for(genvar i = 0; i < D2H_DDATA_NUM; i++) begin : bus_protect_gen_d2h_byte_enable_channels
ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( D2H_DBE_DATA_WD         ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( D2H_DBE_CHK_SIZE        ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_d2h_byte_en_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( cxl_dltl_d2h_byte_en[i]                           ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_d2h_byte_en[i]                          ),
    .dout_prot                 ( cxl_rasdp_d2h_byte_en_chk[i]                      ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( cxl_dltl_d2h_byte_en_valid[i]                     ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( cxl_rasdp_d2h_byte_en_valid[i]                    ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate

generate
for(genvar i = 0; i < D2H_DDATA_NUM; i++) begin : delay_n_d2h_byte_enable_valid_channels
delay_n
 #(
    .N        (1),
    .WD       (1),
    .RESETVAL (1'b1)
) u_d2h_byte_en_valid_inv_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (!cxl_dltl_d2h_byte_en_valid[i]),
    .dout  (cxl_rasdp_d2h_byte_en_valid_inv[i])
);
end
endgenerate




localparam S2M_NDR_PAD_ZEROS = (S2M_NDR_CHK_SIZE/CX_CXL_CHI_PROT_RANGE_WIDTH)*CX_CXL_CHI_PROT_RANGE-S2M_NDR_SIZE;
localparam S2M_NDR_DATA_WD = S2M_NDR_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

wire   [S2M_NDR_DATA_WD-1:0]      cxl_rasdp_s2m_ndr_int [0:S2M_NDR_NUM-1];

generate
for(genvar i = 0; i < S2M_NDR_NUM; i++) begin : bus_protect_gen_s2m_non_data_response_channels

assign cxl_rasdp_s2m_ndr[i] = cxl_rasdp_s2m_ndr_int[i][S2M_NDR_DATA_WD-1:S2M_NDR_PAD_ZEROS];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( S2M_NDR_DATA_WD         ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( S2M_NDR_CHK_SIZE        ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_s2m_ndr_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( {cxl_dltl_s2m_ndr[i],{(S2M_NDR_PAD_ZEROS){1'b0}}} ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_s2m_ndr_int[i]                          ),
    .dout_prot                 ( cxl_rasdp_s2m_ndr_chk[i]                          ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate


localparam S2M_DHDR_PAD_ZEROS = (S2M_DHDR_CHK_SIZE/CX_CXL_CHI_PROT_RANGE_WIDTH)*CX_CXL_CHI_PROT_RANGE-S2M_DHDR_SIZE;
localparam S2M_DHDR_DATA_WD = S2M_DHDR_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

wire    [S2M_DHDR_DATA_WD-1:0]       cxl_rasdp_s2m_drs_int [0:S2M_DDATA_NUM-1];
 
generate
for(genvar i = 0; i < S2M_DDATA_NUM; i++) begin : bus_protect_gen_s2m_data_response_channels

assign cxl_rasdp_s2m_drs[i] = cxl_rasdp_s2m_drs_int[i][S2M_DHDR_DATA_WD-1:S2M_DHDR_PAD_ZEROS];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( S2M_DHDR_DATA_WD        ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( S2M_DHDR_CHK_SIZE       ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_s2m_drs_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( {cxl_dltl_s2m_drs[i],{(S2M_DHDR_PAD_ZEROS){1'b0}}}),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_s2m_drs_int[i]                          ),
    .dout_prot                 ( cxl_rasdp_s2m_drs_chk[i]                          ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate

 
localparam S2M_DDATA_DATA_WD = S2M_DDATA_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

generate
for(genvar i = 0; i < S2M_DDATA_NUM; i++) begin : bus_protect_gen_s2m_data_channels
ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( S2M_DDATA_DATA_WD       ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( S2M_DDATA_CHK_SIZE      ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_s2m_data_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( cxl_dltl_s2m_data[i]                              ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_s2m_data[i]                             ),
    .dout_prot                 ( cxl_rasdp_s2m_data_chk[i]                         ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( cxl_dltl_s2m_data_valid[i]                        ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( cxl_rasdp_s2m_data_valid[i]                       ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate

generate
for(genvar i = 0; i < S2M_DDATA_NUM; i++) begin : delay_n_s2m_data_valid_channels
delay_n
 #(
    .N        (1),
    .WD       (1),
    .RESETVAL (1'b1)
) u_s2m_data_valid_inv_reg (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (!cxl_dltl_s2m_data_valid[i]),
    .dout  (cxl_rasdp_s2m_data_valid_inv[i])
);
end
endgenerate


localparam S2M_BI_SNP_PAD_ZEROS = (S2M_BI_SNP_CHK_SIZE/CX_CXL_CHI_PROT_RANGE_WIDTH)*CX_CXL_CHI_PROT_RANGE-S2M_BI_SNP_SIZE;
localparam S2M_BI_SNP_DATA_WD   = S2M_BI_SNP_CHK_SIZE*CX_CXL_CHI_PROT_RANGE_WIDTH;

wire   [S2M_BI_SNP_DATA_WD-1:0]      cxl_rasdp_s2m_bi_snp_int [0:S2M_BI_SNP_NUM-1];

generate
for(genvar i = 0; i < S2M_BI_SNP_NUM; i++) begin : bus_protect_gen_s2m_back_invalidate_snoop_channels

assign cxl_rasdp_s2m_bi_snp[i] = cxl_rasdp_s2m_bi_snp_int[i][S2M_BI_SNP_DATA_WD-1:S2M_BI_SNP_PAD_ZEROS];

ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 1                       ), // Pipeline stage: 1
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_CHI_PROT_TYPE    ), // Protection type
    .PROT_RANGE              ( CX_CXL_CHI_PROT_RANGE   ), // Protection range
    .TOTAL_WIDTH             ( S2M_BI_SNP_DATA_WD      ), // Data width: message width extended to prot range bits boundary
    .PROT_WD                 ( S2M_BI_SNP_CHK_SIZE     ), // Protection code width
    .PARITY_MODE             ( CX_CXL_CHI_PARITY_MODE  ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is not enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_s2m_bi_snp_ras_dp_pipe (
    .clk                       ( core_clk                                          ),
    .rst_n                     ( core_rst_n                                        ),
    .din                       ( {cxl_dltl_s2m_bi_snp[i],{(S2M_BI_SNP_PAD_ZEROS){1'b0}}} ),
    .din_prot                  ( '0                                                ),
    .dout                      ( cxl_rasdp_s2m_bi_snp_int[i]                        ),
    .dout_prot                 ( cxl_rasdp_s2m_bi_snp_chk[i]                        ),
    .en                        ( 1'b1                                              ),
    .bypass                    ( 1'b0                                              ),
    .stall                     ( 1'b0                                              ),
    .stallout                  ( /* Unused */                                      ),
    .valid_in                  ( 1'b0                                              ),
    .halt_out                  ( /* Unused */                                      ),
    .valid_out                 ( /* Unused */                                      ),
    .halt_in                   ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                              ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                                      ),
    .ras_dp_err_log            ( /* Unused */                                      )
    ,
    .ras_dp_err_inj            ( '0                                                )
);
end
endgenerate





endmodule : DWC_cxl_mem_cache_rx_rasdp_wr_ms
