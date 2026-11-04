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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_slv_pkg.svh#10 $
// -------------------------------------------------------------------------
// --- Description: AXI Slave Interface Package
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_AXI_SLV_PKG__SVH__
`define __GUARD__DWC_PCIE_AXI_SLV_PKG__SVH__

package DWC_pcie_axi_slv_pkg;

//----------------------------------------------------------------------\\
//---------------------------Local Parameters---------------------------\\
//----------------------------------------------------------------------\\

  localparam SLV_AW_EXTRA_PYLD_WIDTH      = `CC_SLV_AW_EXTRA_PYLD_WIDTH;
  localparam SLV_W_EXTRA_PYLD_WIDTH       = `CC_SLV_W_EXTRA_PYLD_WIDTH ;
  localparam SLV_AR_EXTRA_PYLD_WIDTH      = `CC_SLV_AR_EXTRA_PYLD_WIDTH;
  localparam SLV_R_EXTRA_PYLD_WIDTH       = `CC_SLV_R_EXTRA_PYLD_WIDTH ;
  localparam SLV_B_EXTRA_PYLD_WIDTH       = `CC_SLV_B_EXTRA_PYLD_WIDTH ;

  localparam SLV_AW_EXTRA_PYLD_PAR_WIDTH  = `CC_SLV_AW_EXTRA_PYLD_PAR_WIDTH;
  localparam SLV_W_EXTRA_PYLD_PAR_WIDTH   = `CC_SLV_W_EXTRA_PYLD_PAR_WIDTH ;
  localparam SLV_AR_EXTRA_PYLD_PAR_WIDTH  = `CC_SLV_AR_EXTRA_PYLD_PAR_WIDTH;
  localparam SLV_R_EXTRA_PYLD_PAR_WIDTH   = `CC_SLV_R_EXTRA_PYLD_PAR_WIDTH ;
  localparam SLV_B_EXTRA_PYLD_PAR_WIDTH   = `CC_SLV_B_EXTRA_PYLD_PAR_WIDTH ;

  localparam SLV_AW_USER_SIZE             = `CC_SLV_AW_USER_WIDTH;
  localparam SLV_W_USER_SIZE              = `CC_SLV_W_USER_WIDTH ;
  localparam SLV_AR_USER_SIZE             = `CC_SLV_AR_USER_WIDTH;
  localparam SLV_R_USER_SIZE              = `CC_SLV_R_USER_WIDTH ;
  localparam SLV_B_USER_SIZE              = `CC_SLV_B_USER_WIDTH ;

  localparam DBI_SLV_AW_USER_SIZE         = `CC_DBI_SLV_AW_USER_WIDTH;
  localparam DBI_SLV_W_USER_SIZE          = `CC_DBI_SLV_W_USER_WIDTH ;
  localparam DBI_SLV_AR_USER_SIZE         = `CC_DBI_SLV_AR_USER_WIDTH;
  localparam DBI_SLV_R_USER_SIZE          = `CC_DBI_SLV_R_USER_WIDTH ;
  localparam DBI_SLV_B_USER_SIZE          = `CC_DBI_SLV_B_USER_WIDTH ;

  localparam NFUNC_WD                     = `CX_NFUNC_WD               ;
  localparam NVFUNC_WD                    = `CX_NVFUNC_WD              ;
  localparam NPRFX                        = `CX_NPRFX                  ;
  localparam TAG_SIZE                     = `CX_TAG_SIZE               ;
  localparam SLV_BUS_ID_WIDTH             = `CC_SLV_BUS_ID_WIDTH       ;
  localparam SLV_BURST_LEN_PW             = `CC_SLV_INT_BURST_LEN_PW   ;
  localparam AXI_LOCK_WIDTH               = `CC_AXI_LOCK_WIDTH         ;
  localparam SLV_MISC_INFO_PWD            = `SLV_MISC_INFO_PW          ;
  localparam SLV_BUS_WSTRB_WIDTH          = `CC_SLV_BUS_WSTRB_WIDTH    ;
  localparam SLV_RESP_MISC_INFO_PWD       = `SLV_RESP_MISC_INFO_PW     ;

  localparam TX_TLP_PREFIX_WD             = (32*`CX_NPRFX)+ `CX_PRFX_PAR_WD;

  localparam AXI_SLV_AMBA_PAR_LOG_WD = 21 + 2 + 1;

//----------------------------------------------------------------------\\
//------------------------------AW CHANNEL------------------------------\\
//----------------------------------------------------------------------\\

  typedef struct packed {
    logic [63:0]                         hdr_34dw;
    logic                                nw;
    logic [1:0]                          ats;
    logic [(32*NPRFX) -1:0]              tlpprfx;
    logic [TAG_SIZE-1:0]                 p_tag;
    logic [10:0]                         tph;
    logic                                atu_bypass;
    logic                                ido;
    logic [8:0]                          dst_segment;
  } pkg_axi_slv_awmisc_info_s;

  typedef struct packed {
    logic [SLV_BUS_ID_WIDTH-1:0]         id;
    logic                                valid;
    logic [SLV_BURST_LEN_PW-1:0]         len;
    logic [2:0]                          size;
    logic [1:0]                          burst;
    logic [AXI_LOCK_WIDTH-1:0]           lock;
    logic [3:0]                          cache;
    logic [2:0]                          prot;
    logic [SLV_MISC_INFO_PWD-1:0]        misc_info;
    pkg_axi_slv_awmisc_info_s            misc_info_s;
    logic [3:0]                          qos;
    logic [1:0]                          bar;
    logic [1:0]                          domain;
    logic [`CC_AXIJ_DMWR_VALUE *2+2:0]   snoop;
    logic [5:0]                          atop;
  } pkg_axi_slv_aw_s;


//----------------------------------------------------------------------\\
//-------------------------------W CHANNEL------------------------------\\
//----------------------------------------------------------------------\\

  typedef struct packed {
    logic                                ep;
    logic                                silentDrop;
  } pkg_axi_slv_wmisc_info_s;

  typedef struct packed {
    logic                                valid;
    logic                                last;
    logic [SLV_BUS_WSTRB_WIDTH-1:0]      strb;
    pkg_axi_slv_wmisc_info_s             misc_info_s;
  } pkg_axi_slv_w_s;


//----------------------------------------------------------------------\\
//------------------------------AR CHANNEL------------------------------\\
//----------------------------------------------------------------------\\

  typedef struct packed {
    logic                                nw;
    logic [1:0]                          ats;
    logic [(32*NPRFX) -1:0]              tlpprfx;
    logic [10:0]                         tph;
    logic                                atu_bypass;
    logic                                ido;
    logic [8:0]                          dst_segment;
  } pkg_axi_slv_armisc_info_s;

  typedef struct packed {
    logic [SLV_BUS_ID_WIDTH-1:0]         id;
    logic                                valid;
    logic [SLV_BURST_LEN_PW-1:0]         len;
    logic [2:0]                          size;
    logic [1:0]                          burst;
    logic [AXI_LOCK_WIDTH-1:0]           lock;
    logic [3:0]                          cache;
    logic [2:0]                          prot;
    logic [SLV_MISC_INFO_PWD-1:0]        misc_info;
    pkg_axi_slv_armisc_info_s            misc_info_s;
    logic [3:0]                          qos;
    logic [1:0]                          bar;
    logic [1:0]                          domain;
    logic [3:0]                          snoop;
  } pkg_axi_slv_ar_s;


//----------------------------------------------------------------------\\
//-------------------------------R CHANNEL------------------------------\\
//----------------------------------------------------------------------\\

  typedef struct packed {
    logic [7:0]                          cpl_segment;
    logic [8:0]                          dst_segment;
    logic                                ido;
  } pkg_axi_slv_rmisc_info_s;

  typedef struct packed {
    logic [SLV_BUS_ID_WIDTH-1:0]         id;
    logic                                valid;
    logic                                last;
    logic [1:0]                          resp;
    logic [SLV_RESP_MISC_INFO_PWD-1:0]   misc_info;
    pkg_axi_slv_rmisc_info_s             misc_info_s;
  } pkg_axi_slv_r_s;


//----------------------------------------------------------------------\\
//-------------------------------B CHANNEL------------------------------\\
//----------------------------------------------------------------------\\

  typedef struct packed {
    logic [7:0]                          cpl_segment;
    logic [8:0]                          dst_segment;
  } pkg_axi_slv_bmisc_info_s;

  typedef struct packed {
    logic [SLV_BUS_ID_WIDTH-1:0]         id;
    logic                                valid;
    logic [`CC_AXIJ_DMWR_VALUE +1:0]     resp;
    logic [SLV_RESP_MISC_INFO_PWD-1:0]   misc_info;
    pkg_axi_slv_bmisc_info_s             misc_info_s;
  } pkg_axi_slv_b_s;


//----------------------------------------------------------------------\\
//---------------------------WRITE SLAVE INFO---------------------------\\
//----------------------------------------------------------------------\\

 typedef struct packed {
    logic [SLV_BUS_ID_WIDTH-1:0] id;
    logic                  [4:0] reqType;
    logic                        snp;
    logic                        ep;
    logic                        ns;
    logic                        ro;
    logic                  [2:0] tc;
    logic                  [7:0] msgCode;
    logic                        db;
    logic                        dbVldrq;
    logic         [NFUNC_WD-1:0] funcNum;
    logic                        nw;
    logic                  [1:0] ats;
    logic [TX_TLP_PREFIX_WD-1:0] tlpPrfx;
    logic         [TAG_SIZE-1:0] infoPostedTag;
    logic                 [10:0] tph;
    logic                        atuBypass;
    logic [8:0]                  dst_segment;
    logic                        ido;
    logic                  [2:0] cplStat;
    logic                        atomic_load_be;
    logic                        atomic_cas_wrap;
  } slv_wmiscInfo_s;


//----------------------------------------------------------------------\\
//------------------------------ERROR STATUS----------------------------\\
//----------------------------------------------------------------------\\

  typedef struct packed {
    logic                    awvalid;
    logic                    awpyld0;
    logic                    awpyld1;
    logic                    awpyld2;
    logic                    wvalid ;
    logic                    wpyld0 ;
    logic                    wpyld1 ;
    logic                    wpyld2 ;
    logic                    arvalid;
    logic                    arpyld0;
    logic                    arpyld1;
    logic                    arpyld2;
    logic                    rready ;
    logic                    bready ;
  } pkg_axi_slv_err_parity;

  typedef struct packed {
    logic                    awpyld0;
    logic                    awpyld1;
    logic                    wpyld0 ;
    logic                    wpyld1 ;
    logic                    arpyld0;
    logic                    arpyld1;
  } pkg_axi_slv_err_un_corr;

  typedef struct packed {
    logic                    awaddr_par;
    logic                    araddr_par;
    logic                    wdata_par ;
  } pkg_axi_slv_par_sts;

  typedef struct packed {
    pkg_axi_slv_err_un_corr  corr  ;
    pkg_axi_slv_err_un_corr  uncorr;
  } pkg_axi_slv_err_ecc;

  typedef struct packed {
    pkg_axi_slv_err_parity   parity;
    pkg_axi_slv_err_ecc      ecc   ;
  } pkg_axi_slv_err_sts;

endpackage : DWC_pcie_axi_slv_pkg

`endif //__GUARD__DWC_PCIE_AXI_SLV_PKG__SVH__

