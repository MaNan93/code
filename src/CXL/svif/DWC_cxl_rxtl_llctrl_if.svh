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
// ---   $DateTime: 2023/06/26 08:32:07 $
// ---   $Revision: #1 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/svif/DWC_cxl_rxtl_llctrl_if.svh#1 $
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_CXL_RXTL_LLCTRL_IF__SVH__
`define __GUARD__DWC_CXL_RXTL_LLCTRL_IF__SVH__
interface DWC_cxl_rxtl_llctrl_if
  import DWC_cxl_pkg::*;
  #(
      parameter H2D_INT_DATA_NUM = H2D_DDATA_NUM,
      parameter M2S_INT_DATA_NUM = M2S_DDATA_NUM,
      parameter D2H_INT_DATA_NUM = D2H_DDATA_NUM,
      parameter S2M_INT_DATA_NUM = S2M_DDATA_NUM
  );
  logic [H2D_REQ_SIZE-1:0]           s_cxl_h2d_req [0:H2D_REQ_NUM-1]                  ; // Two H2D Request Channels 
  logic [H2D_RESP_SIZE-1:0]          s_cxl_h2d_resp [0:H2D_RESP_NUM-1]                ; // Four H2D Response Channels
  logic [H2D_DHDR_SIZE-1:0]          s_cxl_h2d_dhr [0:H2D_INT_DATA_NUM-1]             ; // Four H2D Data Header Channels
  logic [H2D_DDATA_SIZE-1:0]         s_cxl_h2d_data [0:H2D_DDATA_NUM-1]               ; // H2D Data Channel
  logic [H2D_DDATA_NUM-1:0]          s_cxl_h2d_data_valid                             ; // Valid Signal for H2D Data Channel
  logic [H2D_REQ_CHK_SIZE-1:0]       s_cxl_h2d_req_chk [0:H2D_REQ_NUM-1]              ; // Two H2D Request Channels 
  logic [H2D_RESP_CHK_SIZE-1:0]      s_cxl_h2d_resp_chk [0:H2D_RESP_NUM-1]            ; // Four H2D Response Channels
  logic [H2D_DHDR_CHK_SIZE-1:0]      s_cxl_h2d_dhr_chk [0:H2D_INT_DATA_NUM-1]         ; // Four H2D Data Header Channels
  logic [H2D_DDATA_CHK_SIZE-1:0]     s_cxl_h2d_data_chk [0:H2D_DDATA_NUM-1]           ; // H2D Data Channel
  logic [H2D_DDATA_NUM-1:0]          s_cxl_h2d_data_valid_chk                         ; // Valid Signal for H2D Data Channel
  logic [D2H_REQ_SIZE-1:0]           s_cxl_d2h_req [0:D2H_REQ_NUM-1]                  ; // Four D2H Request Channels
  logic [D2H_RESP_SIZE-1:0]          s_cxl_d2h_resp [0:D2H_RESP_NUM-1]                ; // Two D2H Response Channels
  logic [D2H_DHDR_SIZE-1:0]          s_cxl_d2h_dhr [0:D2H_INT_DATA_NUM-1]             ; // Four D2H Data Header Channels
  logic [D2H_DDATA_SIZE-1:0]         s_cxl_d2h_data [0:D2H_DDATA_NUM-1]               ; // D2H Data Channel
  logic [D2H_DDATA_NUM-1:0]          s_cxl_d2h_data_valid                             ; // Valid Signal for D2H Data Channel
  logic [D2H_DBE_SIZE-1:0]           s_cxl_d2h_byte_en [0:D2H_DDATA_NUM-1]            ; // D2H Data Byte Enables for 512 bit D2H data
  logic [D2H_DDATA_NUM-1:0]          s_cxl_d2h_byte_en_valid                          ; // Byte Enable Valid Signal for D2H Data
  logic [D2H_REQ_CHK_SIZE-1:0]       s_cxl_d2h_req_chk [0:D2H_REQ_NUM-1]              ; // Four D2H Request Channels
  logic [D2H_RESP_CHK_SIZE-1:0]      s_cxl_d2h_resp_chk [0:D2H_RESP_NUM-1]            ; // Two D2H Response Channels
  logic [D2H_DHDR_CHK_SIZE-1:0]      s_cxl_d2h_dhr_chk [0:D2H_INT_DATA_NUM-1]         ; // Four D2H Data Header Channels
  logic [D2H_DDATA_CHK_SIZE-1:0]     s_cxl_d2h_data_chk [0:D2H_DDATA_NUM-1]           ; // D2H Data Channel
  logic [D2H_DDATA_NUM-1:0]          s_cxl_d2h_data_valid_chk                         ; // Valid Signal for D2H Data Channel
  logic [D2H_DBE_CHK_SIZE-1:0]       s_cxl_d2h_byte_en_chk [0:D2H_DDATA_NUM-1]        ; // D2H Data Byte Enables for 512 bit D2H data
  logic [D2H_DDATA_NUM-1:0]          s_cxl_d2h_byte_en_valid_chk                      ; // Byte Enable Valid Signal for D2H Data
  logic [M2S_DHDR_SIZE-1:0]          s_cxl_m2s_dhr [0:M2S_INT_DATA_NUM-1]             ; // M2S Data Header Channel
  logic [M2S_DDATA_SIZE-1:0]         s_cxl_m2s_data [0:M2S_DDATA_NUM-1]               ; // M2S Data Channel
  logic [M2S_DDATA_NUM-1:0]          s_cxl_m2s_data_valid                             ; // Valid Signal for M2S Data Channel
  logic [M2S_DBE_SIZE-1:0]           s_cxl_m2s_byte_en [0:M2S_DDATA_NUM-1]            ; // M2S Data Byte Enables for 512 bit M2S data
  logic [M2S_DDATA_NUM-1:0]          s_cxl_m2s_byte_en_valid                          ; // Byte Enable Valid Signal for M2S Data
  logic [M2S_NDR_SIZE-1:0]           s_cxl_m2s_req [0:M2S_NDR_NUM-1]                  ; // Two M2S Request Channels
  logic [M2S_DHDR_CHK_SIZE-1:0]      s_cxl_m2s_dhr_chk [0:M2S_INT_DATA_NUM-1]         ; // M2S Data Header Channel
  logic [M2S_DDATA_CHK_SIZE-1:0]     s_cxl_m2s_data_chk [0:M2S_DDATA_NUM-1]           ; // M2S Data Channel
  logic [M2S_DDATA_NUM-1:0]          s_cxl_m2s_data_valid_chk                         ; // Valid Signal for M2S Data Channel
  logic [M2S_DBE_CHK_SIZE-1:0]       s_cxl_m2s_byte_en_chk [0:M2S_DDATA_NUM-1]        ; // M2S Data Byte Enables for 512 bit M2S data
  logic [M2S_DDATA_NUM-1:0]          s_cxl_m2s_byte_en_valid_chk                      ; // Byte Enable Valid Signal for M2S Data
  logic [M2S_NDR_CHK_SIZE-1:0]       s_cxl_m2s_req_chk [0:M2S_NDR_NUM-1]              ; // Two M2S Request Channels
  logic [S2M_NDR_SIZE-1:0]           s_cxl_s2m_ndr [0:S2M_NDR_NUM-1]                  ; // Three S2M No Data Response Channels
  logic [S2M_DHDR_SIZE-1:0]          s_cxl_s2m_drs [0:S2M_INT_DATA_NUM-1]             ; // Three S2M Data Response Channels
  logic [S2M_DDATA_SIZE-1:0]         s_cxl_s2m_data [0:S2M_DDATA_NUM-1]               ; // S2M Data Channel
  logic [S2M_DDATA_NUM-1:0]          s_cxl_s2m_data_valid                             ; // Valid Signal for S2M Data Channel 
  logic [S2M_NDR_CHK_SIZE-1:0]       s_cxl_s2m_ndr_chk [0:S2M_NDR_NUM-1]              ; // Three S2M No Data Response Channels
  logic [S2M_DHDR_CHK_SIZE-1:0]      s_cxl_s2m_drs_chk [0:S2M_INT_DATA_NUM-1]         ; // Three S2M Data Response Channels
  logic [S2M_DDATA_CHK_SIZE-1:0]     s_cxl_s2m_data_chk [0:S2M_DDATA_NUM-1]           ; // S2M Data Channel
  logic [S2M_DDATA_NUM-1:0]          s_cxl_s2m_data_valid_chk                         ; // Valid Signal for S2M Data Channel 
  logic [M2S_BI_RSP_SIZE-1:0]        s_cxl_m2s_bi_rsp [0:M2S_BI_RSP_NUM-1]            ;
  logic [M2S_BI_RSP_CHK_SIZE-1:0]    s_cxl_m2s_bi_rsp_chk [0:M2S_BI_RSP_NUM-1]        ;
  
  logic [S2M_BI_SNP_SIZE-1:0]        s_cxl_s2m_bi_snp [0:S2M_BI_SNP_NUM-1]            ;
  logic [S2M_BI_SNP_CHK_SIZE-1:0]    s_cxl_s2m_bi_snp_chk [0:S2M_BI_SNP_NUM-1]        ;

modport master_mp(
  output                  s_cxl_h2d_req                               ,            
  output                  s_cxl_h2d_resp                              ,           
  output                  s_cxl_h2d_dhr                               ,            
  output                  s_cxl_h2d_data                              ,               
  output                  s_cxl_h2d_data_valid                        
    ,
  output                  s_cxl_d2h_req                               ,                  
  output                  s_cxl_d2h_resp                              ,                 
  output                  s_cxl_d2h_dhr                               ,                  
  output                  s_cxl_d2h_data                              ,                     
  output                  s_cxl_d2h_data_valid                        ,              
  output                  s_cxl_d2h_byte_en                           ,            
  output                  s_cxl_d2h_byte_en_valid           
  ,
  output                  s_cxl_m2s_data                              ,        
  output                  s_cxl_m2s_data_valid                        ,              
  output                  s_cxl_m2s_dhr                               ,                    
  output                  s_cxl_m2s_byte_en                           ,               
  output                  s_cxl_m2s_byte_en_valid                     ,           
  output                  s_cxl_m2s_req                    
    ,
  output                  s_cxl_s2m_ndr                               ,   
  output                  s_cxl_s2m_drs                               ,    
  output                  s_cxl_s2m_data                              ,
  output                  s_cxl_s2m_data_valid                        
  ,
  output                  s_cxl_m2s_bi_rsp                           
  ,
  output                  s_cxl_s2m_bi_snp
);

modport slave_mp(
  input                   s_cxl_h2d_req                               ,            
  input                   s_cxl_h2d_resp                              ,           
  input                   s_cxl_h2d_dhr                               ,            
  input                   s_cxl_h2d_data                              ,               
  input                   s_cxl_h2d_data_valid                        
    ,
  input                   s_cxl_d2h_req                               ,                  
  input                   s_cxl_d2h_resp                              ,                 
  input                   s_cxl_d2h_dhr                               ,                  
  input                   s_cxl_d2h_data                              ,                     
  input                   s_cxl_d2h_data_valid                        ,              
  input                   s_cxl_d2h_byte_en                           ,            
  input                   s_cxl_d2h_byte_en_valid           
  ,
  input                   s_cxl_m2s_data                              ,        
  input                   s_cxl_m2s_data_valid                        ,              
  input                   s_cxl_m2s_dhr                               ,                    
  input                   s_cxl_m2s_byte_en                           ,               
  input                   s_cxl_m2s_byte_en_valid                     ,           
  input                   s_cxl_m2s_req
    ,
  input                   s_cxl_s2m_ndr                               ,   
  input                   s_cxl_s2m_drs                               ,    
  input                   s_cxl_s2m_data                              ,
  input                   s_cxl_s2m_data_valid                        
  ,
  input                   s_cxl_m2s_bi_rsp                           
  ,        
  input                   s_cxl_s2m_bi_snp
);


modport master_rasdp_mp(
  output                  s_cxl_h2d_req                               ,            
  output                  s_cxl_h2d_resp                              ,           
  output                  s_cxl_h2d_dhr                               ,            
  output                  s_cxl_h2d_data                              ,               
  output                  s_cxl_h2d_data_valid              
    ,
  output                  s_cxl_h2d_req_chk                           ,            
  output                  s_cxl_h2d_resp_chk                          ,           
  output                  s_cxl_h2d_dhr_chk                           ,            
  output                  s_cxl_h2d_data_chk                          ,               
  output                  s_cxl_h2d_data_valid_chk             
    ,
  output                  s_cxl_d2h_req                               ,                  
  output                  s_cxl_d2h_resp                              ,                 
  output                  s_cxl_d2h_dhr                               ,                  
  output                  s_cxl_d2h_data                              ,                     
  output                  s_cxl_d2h_data_valid                        ,              
  output                  s_cxl_d2h_byte_en                           ,            
  output                  s_cxl_d2h_byte_en_valid           
    ,
  output                  s_cxl_d2h_req_chk                           , 
  output                  s_cxl_d2h_resp_chk                          ,
  output                  s_cxl_d2h_dhr_chk                           ,                  
  output                  s_cxl_d2h_data_chk                          ,                     
  output                  s_cxl_d2h_data_valid_chk                    ,              
  output                  s_cxl_d2h_byte_en_chk                       ,            
  output                  s_cxl_d2h_byte_en_valid_chk           
  ,
  output                  s_cxl_m2s_data                              ,        
  output                  s_cxl_m2s_data_valid                        ,              
  output                  s_cxl_m2s_dhr                               ,                    
  output                  s_cxl_m2s_byte_en                           ,               
  output                  s_cxl_m2s_byte_en_valid                     ,           
  output                  s_cxl_m2s_req                    
    ,
  output                  s_cxl_m2s_data_chk                          ,        
  output                  s_cxl_m2s_data_valid_chk                    ,              
  output                  s_cxl_m2s_dhr_chk                           ,                    
  output                  s_cxl_m2s_byte_en_chk                       ,               
  output                  s_cxl_m2s_byte_en_valid_chk                 ,           
  output                  s_cxl_m2s_req_chk                    
    ,
  output                  s_cxl_s2m_ndr                               ,   
  output                  s_cxl_s2m_drs                               ,    
  output                  s_cxl_s2m_data                              ,
  output                  s_cxl_s2m_data_valid               
    ,
  output                  s_cxl_s2m_ndr_chk                           ,   
  output                  s_cxl_s2m_drs_chk                           ,    
  output                  s_cxl_s2m_data_chk                          ,
  output                  s_cxl_s2m_data_valid_chk               
  ,
  output                  s_cxl_m2s_bi_rsp                           
    ,
  output                  s_cxl_m2s_bi_rsp_chk                   
  ,
  output                  s_cxl_s2m_bi_snp
    ,
  output                  s_cxl_s2m_bi_snp_chk
);

modport slave_rasdp_mp(
  input                   s_cxl_h2d_req                               ,            
  input                   s_cxl_h2d_resp                              ,           
  input                   s_cxl_h2d_dhr                               ,            
  input                   s_cxl_h2d_data                              ,               
  input                   s_cxl_h2d_data_valid              
    ,
  input                   s_cxl_h2d_req_chk                           ,            
  input                   s_cxl_h2d_resp_chk                          ,           
  input                   s_cxl_h2d_dhr_chk                           ,            
  input                   s_cxl_h2d_data_chk                          ,               
  input                   s_cxl_h2d_data_valid_chk              
    ,
  input                   s_cxl_d2h_req                               ,                  
  input                   s_cxl_d2h_resp                              ,                 
  input                   s_cxl_d2h_dhr                               ,                  
  input                   s_cxl_d2h_data                              ,                     
  input                   s_cxl_d2h_data_valid                        ,              
  input                   s_cxl_d2h_byte_en                           ,            
  input                   s_cxl_d2h_byte_en_valid           
    ,
  input                   s_cxl_d2h_req_chk                           ,                  
  input                   s_cxl_d2h_resp_chk                          ,                 
  input                   s_cxl_d2h_dhr_chk                           ,                  
  input                   s_cxl_d2h_data_chk                          ,                     
  input                   s_cxl_d2h_data_valid_chk                    ,              
  input                   s_cxl_d2h_byte_en_chk                       ,            
  input                   s_cxl_d2h_byte_en_valid_chk           
  ,
  input                   s_cxl_m2s_data                              ,        
  input                   s_cxl_m2s_data_valid                        ,              
  input                   s_cxl_m2s_dhr                               ,                    
  input                   s_cxl_m2s_byte_en                           ,               
  input                   s_cxl_m2s_byte_en_valid                     ,           
  input                   s_cxl_m2s_req
    ,
  input                   s_cxl_m2s_data_chk                          ,        
  input                   s_cxl_m2s_data_valid_chk                    ,              
  input                   s_cxl_m2s_dhr_chk                           ,                    
  input                   s_cxl_m2s_byte_en_chk                       ,               
  input                   s_cxl_m2s_byte_en_valid_chk                 ,           
  input                   s_cxl_m2s_req_chk
    ,
  input                   s_cxl_s2m_ndr                               ,   
  input                   s_cxl_s2m_drs                               ,    
  input                   s_cxl_s2m_data                              ,
  input                   s_cxl_s2m_data_valid             
    ,
  input                   s_cxl_s2m_ndr_chk                           ,   
  input                   s_cxl_s2m_drs_chk                           ,    
  input                   s_cxl_s2m_data_chk                          ,
  input                   s_cxl_s2m_data_valid_chk             
  ,
  input                   s_cxl_m2s_bi_rsp                           
    ,
  input                   s_cxl_m2s_bi_rsp_chk                           
  ,        
  input                   s_cxl_s2m_bi_snp
    ,
  input                   s_cxl_s2m_bi_snp_chk
);



  //  Define a macro to concatenate the check bits with the signal.
  //  The use of a macro for variable sized inputs and outputs seems easier
  //  than the use of variable sized functions/tasks.
  //
  //  For the case of DATACHK, the macro actually concatenates.
  //  For no DATACHK, the macro just copies the (unpacked) input
  //  into the packed result.
  //  If both were packed arrays it would have been easier to say result=value;
  //
  //  Within the definition of the macro, we use the double-tick (``) to form
  //  the names of the signals by appending the passed variable name to the
  //  text given inside the macro.
  `define GET_RES(NUM, VAL, val)                                        \
  logic [(NUM-1):0][(VAL``_RX_CH_SIZE-1):0] cxl_ch_dltl_``val;          \
  always_comb begin                                                     \
    for (int i=0; i<NUM; i=i+1) begin                                   \
      cxl_ch_dltl_``val[i][(VAL``_RX_CH_SIZE-1):0] =  {                 \
          s_cxl_``val``_chk[i][(VAL``_CHK_SIZE-1):0]                    \
        ,                                                               \
          s_cxl_``val[i][(VAL``_SIZE-1):0]                              \
      };                                                                \
    end                                                                 \
  end                       // End of macro definition
  `GET_RES(H2D_REQ_NUM, H2D_REQ, h2d_req)
  `GET_RES(H2D_RESP_NUM, H2D_RESP, h2d_resp)
  `GET_RES(H2D_DDATA_NUM, H2D_DDATA, h2d_data)
  `GET_RES(H2D_INT_DATA_NUM, H2D_DHDR, h2d_dhr)

  `GET_RES(D2H_REQ_NUM, D2H_REQ, d2h_req)
  `GET_RES(D2H_RESP_NUM, D2H_RESP, d2h_resp)
  `GET_RES(D2H_DDATA_NUM, D2H_DDATA, d2h_data)
  `GET_RES(D2H_INT_DATA_NUM, D2H_DHDR, d2h_dhr)
  `GET_RES(D2H_DDATA_NUM, D2H_DBE, d2h_byte_en)

  `GET_RES(M2S_NDR_NUM, M2S_NDR, m2s_req)
  `GET_RES(M2S_DDATA_NUM, M2S_DDATA, m2s_data)
  `GET_RES(M2S_INT_DATA_NUM, M2S_DHDR, m2s_dhr)
  `GET_RES(M2S_DDATA_NUM, M2S_DBE, m2s_byte_en)
  `GET_RES(M2S_BI_RSP_NUM, M2S_BI_RSP, m2s_bi_rsp)

  `GET_RES(S2M_NDR_NUM, S2M_NDR, s2m_ndr)
  `GET_RES(S2M_DDATA_NUM, S2M_DDATA, s2m_data)
  `GET_RES(S2M_INT_DATA_NUM, S2M_DHDR, s2m_drs)
  `GET_RES(S2M_BI_SNP_NUM, S2M_BI_SNP, s2m_bi_snp)


modport rxtl_integrated_rasdp_mp(
    input                   cxl_ch_dltl_h2d_req
  , input                   cxl_ch_dltl_h2d_resp
  , input                   cxl_ch_dltl_h2d_dhr
  , input                   cxl_ch_dltl_h2d_data
  , input                   s_cxl_h2d_data_valid
  , input                   s_cxl_h2d_data_valid_chk              
    ,
    input                   cxl_ch_dltl_d2h_req
  , input                   cxl_ch_dltl_d2h_resp
  , input                   cxl_ch_dltl_d2h_dhr
  , input                   cxl_ch_dltl_d2h_data
  , input                   cxl_ch_dltl_d2h_byte_en
  , input                   s_cxl_d2h_data_valid
  , input                   s_cxl_d2h_byte_en_valid
  , input                   s_cxl_d2h_data_valid_chk              
  , input                   s_cxl_d2h_byte_en_valid_chk              
  ,
    input                   cxl_ch_dltl_m2s_data
  , input                   cxl_ch_dltl_m2s_req
  , input                   cxl_ch_dltl_m2s_dhr
  , input                   cxl_ch_dltl_m2s_byte_en
  , input                   s_cxl_m2s_byte_en_valid
  , input                   s_cxl_m2s_data_valid
  , input                   s_cxl_m2s_data_valid_chk              
  , input                   s_cxl_m2s_byte_en_valid_chk              
    ,
    input                   cxl_ch_dltl_s2m_ndr
  , input                   cxl_ch_dltl_s2m_drs
  , input                   cxl_ch_dltl_s2m_data
  , input                   s_cxl_s2m_data_valid
  , input                   s_cxl_s2m_data_valid_chk              
  , input                   cxl_ch_dltl_m2s_bi_rsp
  , input                   cxl_ch_dltl_s2m_bi_snp
);
endinterface : DWC_cxl_rxtl_llctrl_if

`endif // __GUARD__DWC_CXL_RXTL_LLCTRL_IF__SVH__
