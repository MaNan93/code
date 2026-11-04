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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xaim_ms_pkg.svh#13 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------

`ifndef __GUARD__XAIM_MS_PKG__SVH__
`define __GUARD__XAIM_MS_PKG__SVH__

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/pcie_pkg.svh"
`include "include/pcie_defs.svh"

package xaim_ms_pkg;
    // -----------------------------------------------------------------------------
    // 1. Imports from other packages
    // -----------------------------------------------------------------------------
    import DWC_pcie_core_pkg::*;  // Import everything temporarily
    import DWC_pcie_ctl_pkg::*;  
    import pcie_pkg::*;

    // -----------------------------------------------------------------------------
    // 2. Parameter Declarations
    // -----------------------------------------------------------------------------
    // Local Param Defines
    localparam OHC_A  = 0;
    localparam OHC_B  = 1;
    localparam OHC_C  = 2;
    localparam OHC_E1 = 3;
    localparam OHC_E2 = 4;
    localparam OHC_E3 = 5;
    localparam OHC_E4 = 6;
    
    //localparam N_XALI_P_IF    = (N_XALI_IF+1)/3;
    //localparam N_XALI_NP_IF   = (N_XALI_IF+1)/3;
    localparam N_XALI_P_NP_IF = N_XALI_P_IF + N_XALI_NP_IF;
    //localparam N_XALI_CPL_IF  = (N_XALI_IF+1)/3;

    localparam LEN_OFFSET_WIDTH  = NW==32 ? 5 : NW==16 ? 4 : NW==8 ? 3 : NW==4 ? 2 : 1;  // bus width of tlp_raw_bytelen_offset in xadm_data_align module
 
    localparam XAIM_RAS_DES_EN    = (1) ? 1 : 0;
    localparam XAIM_ATU_CTRL_EN   =         (1) ? 1 : 0;
    localparam XAIM_ATU_CPIPE_EN  = 0;
    localparam XAIM_ATU_OPIPE_EN  = 0;
    localparam XAIM_CPL_LUT_EN    =        (1) ? 1 : 0;
    localparam XAIM_TLUT_IPIPE_EN = 0;
    localparam XAIM_CX_IS_SW      = 0;

    // Parameter Defines for XAIM Pipelines
    localparam P_NP_ATU_IPIPE_BPG_EN_PRFX = 0;
    localparam P_NP_ATU_CPIPE_BPG_EN_PRFX = 0;
    localparam P_NP_ATU_OPIPE_BPG_EN_PRFX = 0;
    localparam P_NP_ATU_IPIPE_BPG_EN_HDR  = 0;
    localparam P_NP_ATU_IPIPE_BPG_EN_DATA = 0;
    localparam P_NP_ATU_IPIPE_BPC_EN      = 1;
    localparam P_NP_ATU_CPIPE_BPG_EN_HDR  = XAIM_ATU_CPIPE_EN;
    localparam P_NP_ATU_CPIPE_BPG_EN_DATA = 0;
    localparam P_NP_ATU_CPIPE_BPC_EN      = XAIM_ATU_CPIPE_EN;
    localparam P_NP_ATU_OPIPE_BPG_EN_HDR  = XAIM_ATU_OPIPE_EN;
    localparam P_NP_ATU_OPIPE_BPG_EN_DATA = 0;
    localparam P_NP_ATU_OPIPE_BPC_EN      = XAIM_ATU_OPIPE_EN;
    localparam P_NP_ATU_IPIPE_EN          = 1;
    localparam P_NP_ATU_CPIPE_EN          = XAIM_ATU_CPIPE_EN;
    localparam P_NP_ATU_OPIPE_EN          = XAIM_ATU_OPIPE_EN;

    localparam CPL_TLUT_IPIPE_BPG_EN_PRFX = 0;
    localparam CPL_TLUT_OPIPE_BPG_EN_PRFX = 0;
    localparam CPL_TLUT_IPIPE_BPG_EN_HDR  = 0;
    localparam CPL_TLUT_IPIPE_BPG_EN_DATA = 0;
    localparam CPL_TLUT_IPIPE_BPC_EN      = 1;
    localparam CPL_TLUT_OPIPE_BPG_EN_HDR  = 0;
    localparam CPL_TLUT_OPIPE_BPG_EN_DATA = 0;
    localparam CPL_TLUT_OPIPE_BPC_EN      = 0;
    localparam CPL_TLUT_IPIPE_EN          = XAIM_TLUT_IPIPE_EN;
    localparam CPL_TLUT_OPIPE_EN          = 0;

    localparam P_NP_HDR_IPIPE_BPG_EN_PRFX = 0;
    localparam CPL_HDR_IPIPE_BPG_EN_PRFX  = 0;
    localparam MSG_HDR_IPIPE_BPG_EN_PRFX  = 0;
    localparam LBC_HDR_IPIPE_BPG_EN_PRFX  = 0;
    localparam P_NP_HDR_IPIPE_BPG_EN_HDR  = 0;
    localparam P_NP_HDR_IPIPE_BPG_EN_DATA = 0;
    localparam P_NP_HDR_IPIPE_BPC_EN      = (XAIM_ATU_CTRL_EN == 0);
    localparam P_NP_HDR_IPIPE_BPC_EN_PRFX = 0 + P_NP_HDR_IPIPE_BPC_EN;
    localparam P_NP_HDR_CPIPE_BPG_EN      = XAIM_RAS_DES_EN;
    localparam P_NP_HDR_CPIPE_BPC_EN      = XAIM_RAS_DES_EN;
    localparam P_NP_HDR_OPIPE_BPG_EN      = 1;
    localparam P_NP_HDR_OPIPE_BPC_EN      = 0;
    localparam CPL_HDR_IPIPE_BPG_EN_HDR   = 0;
    localparam CPL_HDR_IPIPE_BPG_EN_DATA  = 0;
    localparam CPL_HDR_IPIPE_BPC_EN       = (XAIM_CPL_LUT_EN == 0);
    localparam CPL_HDR_IPIPE_BPC_EN_PRFX  = 0 + CPL_HDR_IPIPE_BPC_EN;
    localparam CPL_HDR_CPIPE_BPG_EN       = XAIM_RAS_DES_EN;
    localparam CPL_HDR_CPIPE_BPC_EN       = XAIM_RAS_DES_EN;
    localparam CPL_HDR_OPIPE_BPG_EN       = 1;
    localparam CPL_HDR_OPIPE_BPC_EN       = 0;
    localparam MSG_HDR_IPIPE_BPG_EN_HDR   = 0;
    localparam MSG_HDR_IPIPE_BPG_EN_DATA  = 0;
    localparam MSG_HDR_IPIPE_BPC_EN       = 1;
    localparam MSG_HDR_IPIPE_BPC_EN_PRFX  = 0 + MSG_HDR_IPIPE_BPC_EN;
    localparam MSG_HDR_CPIPE_BPG_EN       = XAIM_RAS_DES_EN;
    localparam MSG_HDR_CPIPE_BPC_EN       = XAIM_RAS_DES_EN;
    localparam MSG_HDR_OPIPE_BPG_EN       = 1;
    localparam MSG_HDR_OPIPE_BPC_EN       = 0;
    localparam LBC_HDR_IPIPE_BPG_EN_HDR   = 0;
    localparam LBC_HDR_IPIPE_BPG_EN_DATA  = 0;
    localparam LBC_HDR_IPIPE_BPC_EN       = 1;
    localparam LBC_HDR_IPIPE_BPC_EN_PRFX  = 0 + LBC_HDR_IPIPE_BPC_EN;
    localparam LBC_HDR_CPIPE_BPG_EN       = XAIM_RAS_DES_EN;
    localparam LBC_HDR_CPIPE_BPC_EN       = XAIM_RAS_DES_EN;
    localparam LBC_HDR_OPIPE_BPG_EN       = 1;
    localparam LBC_HDR_OPIPE_BPC_EN       = 0;
    localparam P_NP_HDR_CPIPE_EN          = XAIM_RAS_DES_EN;
    localparam CPL_HDR_CPIPE_EN           = XAIM_RAS_DES_EN;
    localparam MSG_HDR_CPIPE_EN           = XAIM_RAS_DES_EN;
    localparam LBC_HDR_CPIPE_EN           = XAIM_RAS_DES_EN;
    localparam P_NP_HDR_IPIPE_EN          = 0; //(XAIM_ATU_CTRL_EN == 0);
    localparam P_NP_HDR_OPIPE_EN          = 1;
    localparam CPL_HDR_IPIPE_EN           = 0; //(XAIM_CPL_LUT_EN == 0); //XAIM_RAS_DES_EN;
    localparam CPL_HDR_OPIPE_EN           = 1;
    localparam MSG_HDR_IPIPE_EN           = 0;
    localparam MSG_HDR_OPIPE_EN           = 1;
    localparam LBC_HDR_IPIPE_EN           = 0; //XAIM_RAS_DES_EN;
    localparam LBC_HDR_OPIPE_EN           = 1;


    //Calculate the Number of protection Codes
    localparam NLOGS_XAIM         = 3;                                       // No of Logs in XAIM pipeline (prefix/hdr/data)
    localparam NLOGS_XAIM_ACT     = 1 + 2; // No of Active Logs in XAIM pipeline (prefix/hdr/data)
    localparam NLOGS_XADM         = 1;                                        // No of Logs in XADM pipeline (combined)
    localparam NLOGS_XADM_ACT     = 1;                                        // No of Active Logs in XADM pipeline (combined)

    localparam NLOGS_ATU          = NLOGS_XAIM*3;                             // NLOGS_XAIM x (3 Possible Pipeline (IPIPE/CPIPE/OPIPE))
    localparam NLOGS_TLUT         = NLOGS_XAIM*2;                             // NLOGS_XAIM x (2 Possible Pipeline (IPIPE/OPIPE))   
    localparam NLOGS_HDR          = NLOGS_XAIM*1 + NLOGS_XADM;                // NLOGS_XAIM x (1 Possible Pipeline (IPIPE)) + (1 Possible Pipeline (CPIPE))

    //localparam TOT_NLOGS_P_NP_ATU = (NLOGS_ATU  * N_XALI_P_NP_IF);            // (NLOGS in the ATU)  x (N_XALI_P_NP_IF Posted/Non-Posted Interfaces)
    //localparam TOT_NLOGS_P_NP_HDR = (NLOGS_HDR  * N_XALI_P_NP_IF);            // (NLOGS in the HDR)  x (N_XALI_P_NP_IF Posted/Non-Posted Interfaces)
    localparam TOT_NLOGS_P_ATU    = (NLOGS_ATU  * N_XALI_P_IF);               // (NLOGS in the ATU)  x (N_XALI_P_IF    Posted Interfaces)
    localparam TOT_NLOGS_P_HDR    = (NLOGS_HDR  * N_XALI_P_IF);               // (NLOGS in the HDR)  x (N_XALI_P_IF    Posted Interfaces)
    localparam TOT_NLOGS_NP_ATU   = (NLOGS_ATU  * N_XALI_NP_IF);              // (NLOGS in the ATU)  x (N_XALI_NP_IF   Non-Posted Interfaces)
    localparam TOT_NLOGS_NP_HDR   = (NLOGS_HDR  * N_XALI_NP_IF);              // (NLOGS in the HDR)  x (N_XALI_NP_IF   Non-Posted Interfaces)
    localparam TOT_NLOGS_CPL_TLUT = (NLOGS_TLUT * N_XALI_CPL_IF);             // (NLOGS in the TLUT) x (N_XALI_CPL_IF  Completion Interfaces)
    localparam TOT_NLOGS_CPL_HDR  = (NLOGS_HDR  * N_XALI_CPL_IF);             // (NLOGS in the HDR)  x (N_XALI_CPL_IF  Completion Interfaces)
    localparam TOT_NLOGS_MSG_HDR  = NLOGS_HDR;                                // (NLOGS in the HDR) (Single interface)
    localparam TOT_NLOGS_LBC_HDR  = NLOGS_HDR;                                // (NLOGS in the HDR) (Single interface)

    localparam ACT_NLOGS_P_NP     = (                                      ( NLOGS_XAIM_ACT * ( P_NP_ATU_IPIPE_BPC_EN + P_NP_ATU_CPIPE_BPC_EN + P_NP_ATU_OPIPE_BPC_EN ) ) +
                                      ( NLOGS_XAIM_ACT * P_NP_HDR_IPIPE_BPC_EN ) +
                                      ( NLOGS_XADM_ACT * P_NP_HDR_CPIPE_BPC_EN ) +
                                      ( NLOGS_XADM_ACT * P_NP_HDR_OPIPE_BPC_EN ) );

    localparam ACT_NLOGS_CPL      = (                                      ( NLOGS_XAIM_ACT * ( CPL_TLUT_IPIPE_BPC_EN + CPL_TLUT_OPIPE_BPC_EN ) ) +
                                      ( NLOGS_XAIM_ACT * CPL_HDR_IPIPE_BPC_EN ) +
                                      ( NLOGS_XADM_ACT * CPL_HDR_CPIPE_BPC_EN ) +
                                      ( NLOGS_XADM_ACT * CPL_HDR_OPIPE_BPC_EN ) );

    localparam ACT_NLOGS_MSG      = ( ( ( 1 + 2) * MSG_HDR_IPIPE_BPC_EN )
                                      + MSG_HDR_CPIPE_BPC_EN
                                      + MSG_HDR_OPIPE_BPC_EN );

    localparam ACT_NLOGS_LBC      = ( ( ( 1 + 2) * LBC_HDR_IPIPE_BPC_EN )
                                      + LBC_HDR_CPIPE_BPC_EN
                                      + LBC_HDR_OPIPE_BPC_EN );


    localparam NLOGS_MSGLBC_CH = ACT_NLOGS_LBC; // Should be the same on both

    // Calculate the RAS DP Base for each Module (Worst Case)
    //localparam RAS_DP_ID_BASE_P_NP_ATU  = RAS_DP_PROT_CHK_ID_BASE_XAIM;
    //localparam RAS_DP_ID_BASE_P_NP_HDR  = RAS_DP_ID_BASE_P_NP_ATU + TOT_NLOGS_P_NP_ATU;
    localparam RAS_DP_ID_BASE_P_ATU     = RAS_DP_PROT_CHK_ID_BASE_XAIM;
    localparam RAS_DP_ID_BASE_P_HDR     = RAS_DP_ID_BASE_P_ATU + TOT_NLOGS_P_ATU;
    localparam RAS_DP_ID_BASE_NP_ATU    = RAS_DP_ID_BASE_P_HDR + TOT_NLOGS_P_HDR;
    localparam RAS_DP_ID_BASE_NP_HDR    = RAS_DP_ID_BASE_NP_ATU + TOT_NLOGS_NP_ATU;
    localparam RAS_DP_ID_BASE_CPL_TLUT  = RAS_DP_ID_BASE_NP_HDR + TOT_NLOGS_NP_HDR;
    //localparam RAS_DP_ID_BASE_CPL_TLUT  = RAS_DP_ID_BASE_P_NP_HDR + TOT_NLOGS_P_NP_HDR;
    localparam RAS_DP_ID_BASE_CPL_HDR   = RAS_DP_ID_BASE_CPL_TLUT + TOT_NLOGS_CPL_TLUT;
    localparam RAS_DP_ID_BASE_MSG_HDR   = RAS_DP_ID_BASE_CPL_HDR  + TOT_NLOGS_CPL_HDR;
    localparam RAS_DP_ID_BASE_LBC_HDR   = RAS_DP_ID_BASE_MSG_HDR  + TOT_NLOGS_MSG_HDR;

    // Calculate the number of RAS checkers (Active)
    localparam BLOCK_RAS_DP_PROT_CHK_N  = ( ACT_NLOGS_P_NP * N_XALI_P_NP_IF) + ( ACT_NLOGS_CPL * N_XALI_CPL_IF ) + ACT_NLOGS_MSG + ACT_NLOGS_LBC;

    
    
/*    
    //Calculate the Number of protection Codes
    localparam NLOGS          = 3;
    localparam NCODES_ATU     = NLOGS*3;                          // (3 Possible Protection Codes) x (3 Possible Pipeline (IPIPE/CPIPE/OPIPE))
    localparam NCODES_TLUT    = NLOGS*2;                          // (3 Possible Protection Codes) x (2 Possible Pipeline (IPIPE/OPIPE))
    localparam NCODES_HDR     = NLOGS*1+1;                        // (3 Possible Protection Codes) x (1 Possible Pipeline (IPIPE) + 1 Possible )

    localparam NLOGS_P_NP_ATU = (NCODES_ATU  * N_XALI_P_NP_IF);   // (NCODES in the ATU)  x (N_XALI_P_NP_IF Posted/Non-Posted Interfaces)
    localparam NLOGS_P_NP_HDR = (NCODES_HDR  * N_XALI_P_NP_IF);   // (NCODES in the HDR)  x (N_XALI_P_NP_IF Posted/Non-Posted Interfaces)
    localparam NLOGS_CPL_TLUT = (NCODES_TLUT * N_XALI_CPL_IF);    // (NCODES in the TLUT) x (N_XALI_CPL_IF  Completion Interfaces)
    localparam NLOGS_CPL_HDR  = (NCODES_HDR  * N_XALI_CPL_IF);    // (NCODES in the HDR)  x (N_XALI_CPL_IF  Completion Interfaces)
    localparam NLOGS_MSG_HDR  = 3; //NCODES_HDR;                       // No Prefix, therefore no code needed for it.
    localparam NLOGS_LBC_HDR  = 3; //NCODES_HDR;                       // No Prefix, therefore no code needed for it.

    localparam NLOGS_P_NP_CH  = ( `ifdef CX_ATU_CTRL_EN
                                   ( NLOGS * ( P_NP_ATU_IPIPE_BPC_EN + P_NP_ATU_CPIPE_BPC_EN + P_NP_ATU_OPIPE_BPC_EN ) ) +
                                  `endif // CX_ATU_CTRL_EN
                                   ( NLOGS * P_NP_HDR_IPIPE_BPC_EN )
                                  `ifdef CX_RAS_DES_EINJ_ENABLE
                                   + P_NP_HDR_CPIPE_BPC_EN
                                  `endif // CX_RAS_DES_EINJ_ENABLE
                                   + P_NP_HDR_OPIPE_BPC_EN );
    localparam NLOGS_CPL_CH   = ( `ifdef TRGT_CPL_LUT_EN
                                   ( NLOGS * ( CPL_TLUT_IPIPE_BPC_EN + CPL_TLUT_OPIPE_BPC_EN ) ) +
                                  `endif // TRGT_CPL_LUT_EN
                                   ( NLOGS * CPL_HDR_IPIPE_BPC_EN )
                                  `ifdef CX_RAS_DES_EINJ_ENABLE
                                   + CPL_HDR_CPIPE_BPC_EN
                                  `endif // CX_RAS_DES_EINJ_ENABLE
                                   + CPL_HDR_OPIPE_BPC_EN );
   
    localparam NLOGS_MSG_CH   = ( ( 2 * MSG_HDR_IPIPE_BPC_EN )
                                  `ifdef CX_RAS_DES_EINJ_ENABLE
                                   + MSG_HDR_CPIPE_BPC_EN
                                  `endif // CX_RAS_DES_EINJ_ENABLE
                                   + MSG_HDR_OPIPE_BPC_EN); 

    localparam NLOGS_LBC_CH   = ( ( 2 * LBC_HDR_IPIPE_BPC_EN )
                                  `ifdef CX_RAS_DES_EINJ_ENABLE
                                   + LBC_HDR_CPIPE_BPC_EN
                                  `endif
                                   + LBC_HDR_OPIPE_BPC_EN);
    
    localparam NLOGS_MSGLBC_CH = NLOGS_LBC_CH; // Should be the same on both

    localparam NLOGS_P_NP     = NLOGS_P_NP_CH * N_XALI_P_NP_IF;
    localparam NLOGS_CPL      = NLOGS_CPL_CH * N_XALI_CPL_IF;
    localparam NLOGS_MSG      = NLOGS_MSG_CH;
    localparam NLOGS_LBC      = NLOGS_LBC_CH;


    // Calculate the RAS DP Base for each Module
    localparam RAS_DP_ID_BASE_P_NP_ATU  = RAS_DP_PROT_CHK_ID_BASE_XAIM;
    localparam RAS_DP_ID_BASE_P_NP_HDR  = RAS_DP_ID_BASE_P_NP_ATU + NLOGS_P_NP_ATU;
    localparam RAS_DP_ID_BASE_CPL_TLUT  = RAS_DP_ID_BASE_P_NP_HDR + NLOGS_P_NP_HDR;
    localparam RAS_DP_ID_BASE_CPL_HDR   = RAS_DP_ID_BASE_CPL_TLUT + NLOGS_CPL_TLUT;
    localparam RAS_DP_ID_BASE_MSG_HDR   = RAS_DP_ID_BASE_CPL_HDR  + NLOGS_CPL_HDR;
    localparam RAS_DP_ID_BASE_LBC_HDR   = RAS_DP_ID_BASE_MSG_HDR  + NLOGS_MSG_HDR;
    localparam BLOCK_RAS_DP_PROT_CHK_N  = NLOGS_P_NP + NLOGS_CPL + NLOGS_MSG + NLOGS_LBC;
*/

    // -----------------------------------------------------------------------------
    // 3. Enumerated Declarations
    // -----------------------------------------------------------------------------
    
    // -----------------------------------------------------------------------------
    // 4. Structure Declarations  // Rename all structs as type _s
    // -----------------------------------------------------------------------------
    typedef struct packed{
        ///////////////////////////////////////////
        // Prefix
        ///////////////////////////////////////////
        logic [XALI_PRFX_WO_PROT_WD-1:0] prfx;
        logic [XALI_PRFX_PROT_WD-1:0]    prfx_prot;
        logic                            rasdp_kbd_prfx;   
   
        ///////////////////////////////////////////
        // Header
        ///////////////////////////////////////////
        tlp_hdr_pkt_s                    tlp_hdr_pkt;         // Header in Enumerated form
        
        `ifndef SYNTHESIS
        tlp_hdr_decode_s                 tlp_hdr_decode;
        `endif // SYNTHESIS
        logic [XALI_HDR_PROT_WD-1:0]     hdr_prot;            // Header Protection Code for Xali
        logic [LBC_MSG_HDR_PROT_WD-1:0]  hdr_prot_msglbc;     // Header Protection Code for MsgGen/LBC
        logic [LBC_MSG_HDR_WO_PROT_WD-1:0] hdr_msglbc;        // Header Data for MsgGen/LBC
        logic                            rasdp_kbd_hdr;

        ///////////////////////////////////////////        
        // Data
        ///////////////////////////////////////////
        logic [XALI_DATA_WO_PROT_WD-1:0] data;
        logic [XALI_DATA_PROT_WD-1:0]    data_prot;
        logic                            rasdp_kbd_data;

        ///////////////////////////////////////////
        // Framing Signals
        ///////////////////////////////////////////
        adm_fs_s                         fs;
        
        ///////////////////////////////////////////
        // Supplimental Application Driven signals
        ///////////////////////////////////////////
        logic                            addr_align_en; 
        logic [12:0]                     tlp_byte_len;
        logic                            tlp_atu_bypass;
        logic          [LOOKUPID_WD-1:0] cpl_lookup_id;
        logic                            tlp_is_dma;

        ///////////////////////////////////////////
        // Supplimental XAIM Driven signals
        ///////////////////////////////////////////
        logic                            tlp_is_atu_translated;
    } xaim_pkt_t;


    typedef struct packed {
      logic      [BUSNUM_WD-1:0] cfg_pbus_num;
      logic      [DEVNUM_WD-1:0] cfg_pbus_dev_num;
      logic         [7:0] cfg_2ndbus_num;
      logic             [NF-1:0] cfg_ecrc_gen_en;
      logic               [31:0] cfg_trgt_cpl_lut_delete_entry;
      logic         [(3*NF)-1:0] cfg_max_rd_req_size;
      mode_e                     mode;

      logic                      cfg_rcb_128;
      logic               [23:0] cfg_tc_struc_vc_map ;
 
      logic                      einj6_enable;
      logic               [31:0] einj6_cmp_point_h0;
      logic               [31:0] einj6_cmp_point_h1;
      logic               [31:0] einj6_cmp_point_h2;
      logic               [31:0] einj6_cmp_point_h3;
      logic               [31:0] einj6_cmp_value_h0;
      logic               [31:0] einj6_cmp_value_h1;
      logic               [31:0] einj6_cmp_value_h2;
      logic               [31:0] einj6_cmp_value_h3;
      logic               [31:0] einj6_chg_point_h0;
      logic               [31:0] einj6_chg_point_h1;
      logic               [31:0] einj6_chg_point_h2;
      logic               [31:0] einj6_chg_point_h3;
      logic               [31:0] einj6_chg_value_h0;
      logic               [31:0] einj6_chg_value_h1;
      logic               [31:0] einj6_chg_value_h2;
      logic               [31:0] einj6_chg_value_h3;
      logic                [7:0] einj6_count;
      logic                      einj6_invt_cont;
      logic                [2:0] einj6_pkt_type;

      logic                [2:0] cfg_optional_ohc_ctrl;
      logic                [8:0] cfg_segment_id;
      
      logic                      cfg_client_p_block_new_tlp;
      logic                      cfg_client_np_block_new_tlp;
      logic                      cfg_client_cpl_block_new_tlp;

    } cdm_xaim_cfg_t;

    typedef struct packed {
      logic             [NF-1:0] flr_pf_done;
    } xaim_cdm_pkt_t;

    typedef struct packed {
      logic                [3:0] device_type;
      logic                      radm_trgt1_dma_grant ;
      logic                      radm_trgt1_dma_cpl_rlsd ;
    } xali_xaim_cfg_t;

    typedef struct packed {
      //`ifdef TRGT_CPL_LUT_EN
      logic               [13:0] trgt_lookup_id;
      logic                      trgt_lookup_empty;
      logic                      trgt_cpl_lut_empty;
      logic                [2:0] trgt_timeout_cpl_tc;
      logic                [1:0] trgt_timeout_cpl_attr;
      logic               [11:0] trgt_timeout_cpl_len;
      logic                      trgt_cpl_timeout;
      logic    [LOOKUPID_WD-1:0] trgt_timeout_lookup_id;
      logic          [PF_WD-1:0] trgt_timeout_cpl_func_num;
      //`endif // TRGT_CPL_LUT_EN
      logic                      radm_trgt1_lookup_id_consmd ;
      logic                      trgt_lut_dma_pkt_halt;

    } xaim_xali_pkt_t;

    typedef struct packed {
      logic                      xtlh_block_tlp;
      logic                      block_all_tlp;
      logic                [2:0] current_data_rate;
    } pmctrl_xaim_pkt_t;

    typedef struct packed {
      logic                      pkt_pending;
    } xaim_pmctrl_pkt_t;

    typedef struct packed {
      logic                             hv;
      logic                             dv;
      logic                             eot;
      logic    [ADM_DATA_W_PROT_WD-1:0] data;
      logic [LBC_MSG_HDR_W_PROT_WD-1:0] hdr;
      logic        [PRFX_W_PAR-1:0]     prfx;
    } msg_lbc_xaim_pkt_t;

    typedef struct packed {
      logic                      hv;                        // xaimFs_t
      logic                      eot;                       // xaimFs_t
      logic                      tlp_abort;                 // none
      logic                      dllp_abort;                // none
      logic                [1:0] fmt;                       // tlp_hdr_pkt_s
      logic                [4:0] tlp_type;                  // tlp_hdr_pkt_s
      logic                [9:0] dw_len;                    // tlp_hdr_pkt_s
      logic                [6:0] addr;                      // tlp_hdr_pkt_s
      logic                      cpl_last;                  // none
      logic                [2:0] cpl_status;                // tlp_hdr_pkt_s
      logic               [11:0] byte_cnt;                  // none
      logic                [2:0] tc;                        // tlp_hdr_pkt_s
      logic       [TAG_SIZE-1:0] tag;                       // tlp_hdr_pkt_s
      logic                      cpl_timeout;               // none
      logic               [11:0] timeout_cpl_byte_len;      // none
      logic                [2:0] timeout_cpl_tc;            // tlp_hdr_pkt_s ( timeout )
      logic       [TAG_SIZE-1:0] timeout_cpl_tag;           // tlp_hdr_pkt_s ( timeout )
      logic                      ecrc_err;                  // none
      logic        [ATTR_WD-1:0] attr;                      // tlp_hdr_pkt_s
      logic               [15:0] reqid;                     // tlp_hdr_pkt_s
      logic                [3:0] first_be;                  // tlp_hdr_pkt_s
      logic                [3:0] last_be;                   // tlp_hdr_pkt_s
      logic          [PF_WD-1:0] func_num;                  // tlp_hdr_pkt_s
      logic                [8:0] req_segment;               // tlp_hdr_pkt_s
      logic          [3*NVC-1:0] radm_grant_tlp_type;
      //`ifdef CC_DMA_ENABLE
      //logic                      radm_trgt1_dma_grant ;
      //logic                      radm_trgt1_dma_cpl_rlsd ;
      //`endif // CC_DMA_ENABLE
      logic                [1:0] at;                        // tlp_hdr_pkt_s
      //logic                [8:0] req_segment;
    } radm_xaim_pkt_t;

    typedef struct packed {
      logic            [NVC-1:0] cpl_lookup_id_rlsd;
      logic                      temp;
      logic          [3*NVC-1:0] trgt_lut_trgt1_radm_pkt_halt;         
    } xaim_radm_pkt_t;

    typedef struct packed {
      logic   [`CX_REMOTE_LUT_PTR_WIDTH-1:0] cfg_remote_max_bridge_tag ;
     
     } xaim_xali_cfg_t;



    // -----------------------------------------------------------------------------
    // 5. Function Declarations
    // -----------------------------------------------------------------------------
    function automatic logic [$clog2(ADM_PRFX_HDR_NW)-1:0] f_get_first_hdr_dw_index (
      input    [ADM_PRFX_HDR_NW-1:0] hdr_dwen
    );
      begin
        logic found;
        found = 1'b0;
        f_get_first_hdr_dw_index = '0;
        for (int dword=0; dword<ADM_PRFX_HDR_NW; dword++) begin
          if (found == '0) begin
            if (hdr_dwen[dword]) begin
              f_get_first_hdr_dw_index = ($clog2(ADM_PRFX_HDR_NW))'(dword);
              found = 1'b1;
            end
          end
        end
      end
    endfunction // f_get_first_hdr_dw_index

    function automatic xaim_pkt_t f_xali_to_xaim (
      input mode_e     mode,
      input xali_pkt_t xali_pkt
    );
      begin

        f_xali_to_xaim = '0; // Initalise to 0

        ///////////////////////////////////////////
        // Prefix
        ///////////////////////////////////////////
        
        f_xali_to_xaim.prfx                     = xali_pkt.prfx;
        f_xali_to_xaim.prfx_prot                = xali_pkt.prfx_prot;
        
        ///////////////////////////////////////////
        // Header
        ///////////////////////////////////////////
        f_xali_to_xaim.tlp_hdr_pkt.tlp_fmt        = (3)'(xali_pkt.hdr.tlp_fmt);
        f_xali_to_xaim.tlp_hdr_pkt.tlp_type       = xali_pkt.hdr.tlp_type;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_tc         = xali_pkt.hdr.tlp_tc;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_len        = xali_pkt.hdr.tlp_byte_len[11:2]; // Len is DW Len
        f_xali_to_xaim.tlp_hdr_pkt.tlp_th         = xali_pkt.hdr.tlp_th;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_ph         = xali_pkt.hdr.tlp_ph;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_st         = (16)'(xali_pkt.hdr.tlp_st);
        f_xali_to_xaim.tlp_hdr_pkt.tlp_attr       = (3)'(xali_pkt.hdr.tlp_attr);
        f_xali_to_xaim.tlp_hdr_pkt.tlp_td         = xali_pkt.hdr.tlp_td;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_ep         = xali_pkt.hdr.tlp_ep;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_req_id     = xali_pkt.hdr.remote_req_id;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_tag        = xali_pkt.hdr.tlp_tid;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_fdw_be     = xali_pkt.hdr.tlp_byte_en[3:0];
        f_xali_to_xaim.tlp_hdr_pkt.tlp_ldw_be     = xali_pkt.hdr.tlp_byte_en[7:4];
        f_xali_to_xaim.tlp_hdr_pkt.tlp_fn         = (8)'(xali_pkt.hdr.tlp_func_num);
        f_xali_to_xaim.tlp_hdr_pkt.tlp_addr       = xali_pkt.hdr.tlp_addr;  
        f_xali_to_xaim.tlp_hdr_pkt.tlp_at         = xali_pkt.hdr.tlp_ats;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_nw         = xali_pkt.hdr.tlp_nw;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_cpl_status = xali_pkt.hdr.cpl_status;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_byte_count = xali_pkt.hdr.cpl_byte_cnt;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_bcm        = xali_pkt.hdr.cpl_bcm;
        f_xali_to_xaim.tlp_hdr_pkt.tlp_req_seg    = xali_pkt.hdr.tlp_segment[7:0];
        f_xali_to_xaim.tlp_hdr_pkt.tlp_rsv        = xali_pkt.hdr.tlp_segment[8];
        f_xali_to_xaim.tlp_hdr_pkt.tlp_dst_seg    = xali_pkt.hdr.tlp_dst_segment[7:0];
        f_xali_to_xaim.tlp_hdr_pkt.tlp_dsv        = xali_pkt.hdr.tlp_dst_segment[8];
        f_xali_to_xaim.tlp_hdr_pkt.tlp_msg_code   = xali_pkt.hdr.tlp_byte_en[7:0];


        f_xali_to_xaim.hdr_prot                   = xali_pkt.hdr_prot;

        `ifndef SYNTHESIS
        f_xali_to_xaim.tlp_hdr_decode             = f_tlp_hdr_decode(mode, f_xali_to_xaim.tlp_hdr_pkt);
        `endif // SYNTHESIS

        ///////////////////////////////////////////        
        // Data
        ///////////////////////////////////////////
        f_xali_to_xaim.data                       = xali_pkt.data;
        f_xali_to_xaim.data_prot                  = xali_pkt.data_prot;

        ///////////////////////////////////////////
        // Framing Signals
        ///////////////////////////////////////////
        f_xali_to_xaim.fs.hv                      = xali_pkt.hdr.tlp_hv;      // Header Valid

        f_xali_to_xaim.fs.dv                      = xali_pkt.hdr.tlp_dv;      // Data Valid

        // General
        f_xali_to_xaim.fs.eot                     = xali_pkt.hdr.tlp_eot;     // EOT
        f_xali_to_xaim.fs.bad_eot                 = xali_pkt.hdr.tlp_bad_eot; // Bad EOT
        f_xali_to_xaim.fs.order_seqnum            = xali_pkt.order_seqnum;    // Sequence Number

        ///////////////////////////////////////////
        // Supplimental Application Driven signals
        ///////////////////////////////////////////    
        f_xali_to_xaim.addr_align_en              = xali_pkt.hdr.addr_align_en;
        f_xali_to_xaim.tlp_byte_len               = xali_pkt.hdr.tlp_byte_len;
        f_xali_to_xaim.tlp_atu_bypass             = xali_pkt.hdr.tlp_atu_bypass;
        f_xali_to_xaim.cpl_lookup_id              = xali_pkt.hdr.cpl_lookup_id;
        f_xali_to_xaim.tlp_is_dma                 = xali_pkt.is_dma;
      end
    endfunction // f_xali_to_xaim 

    function automatic xaim_pkt_t f_msglbc_to_xaim (
      input msg_lbc_xaim_pkt_t i_xaim_pkt
    );
      begin
        logic [12:0] tlp_byte_length;
        logic  [7:0] byte_en;
        logic [8:0] req_seg_id;

        f_msglbc_to_xaim                             = '0;                    // 
        //f_msglbc_to_xaim.prfx                        = '0;                    // "
        f_msglbc_to_xaim.fs.hv                       = i_xaim_pkt.hv;
        f_msglbc_to_xaim.fs.dv                       = i_xaim_pkt.dv;
        f_msglbc_to_xaim.fs.eot                      = i_xaim_pkt.eot;
        f_msglbc_to_xaim.data                        = i_xaim_pkt.data[(`CX_NW*32)-1:0];
        f_msglbc_to_xaim.addr_align_en               = i_xaim_pkt.hdr[`F_HDR_ADDR_ALIGN_EN];
        byte_en                                      = i_xaim_pkt.hdr[`F_HDR_BYTE_EN];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_fdw_be      = byte_en[3:0];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_ldw_be      = byte_en[7:4];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_cpl_id      = i_xaim_pkt.hdr[`F_HDR_REQ_ID];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_msg_code    = i_xaim_pkt.hdr[`F_HDR_TLP_MSG_CODE];
    
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_cpl_status  = i_xaim_pkt.hdr[`F_HDR_CPL_STATUS];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_bcm         = i_xaim_pkt.hdr[`F_HDR_CPL_BCM];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_byte_count  = i_xaim_pkt.hdr[`F_HDR_CPL_BYTE_CNT];
        //f_msglbc_to_xaim.tlp_hdr_pkt.tlp_req_id      = i_xaim_pkt.hdr[`F_HDR_REQ_ID];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_req_id      = i_xaim_pkt.hdr[`F_HDR_CPL_REQ_ID];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_fmt         = (3)'(i_xaim_pkt.hdr[`F_HDR_TLP_FMT]);
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_type        = i_xaim_pkt.hdr[`F_HDR_TLP_TYPE];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_tc          = i_xaim_pkt.hdr[`F_HDR_TLP_TC];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_td          = i_xaim_pkt.hdr[`F_HDR_TLP_TD];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_ep          = i_xaim_pkt.hdr[`F_HDR_TLP_EP];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_attr        = (3)'(i_xaim_pkt.hdr[`F_HDR_TLP_ATTR]);
        tlp_byte_length                                  = i_xaim_pkt.hdr[`F_HDR_TLP_BYTE_LEN];
        f_msglbc_to_xaim.tlp_byte_len                = tlp_byte_length;
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_len         = tlp_byte_length[11:2];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_tag         = i_xaim_pkt.hdr[`F_HDR_TLP_TAG];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_addr        = i_xaim_pkt.hdr[`F_HDR_TLP_ADDR];
        f_msglbc_to_xaim.hdr_msglbc                  = i_xaim_pkt.hdr[(`ST_HDR-1):0];
        f_msglbc_to_xaim.hdr_prot_msglbc             = i_xaim_pkt.hdr[(`ST_HDR+HDR_PROT_WD-1)-:HDR_PROT_WD];
        f_msglbc_to_xaim.data_prot                   = i_xaim_pkt.data[((32*`CX_NW)+`TRGT_DATA_PROT_WD)-1:(`CX_NW*32)];
        f_msglbc_to_xaim.prfx                        = i_xaim_pkt.prfx[PRFX_WO_PAR-1:0];
        f_msglbc_to_xaim.prfx_prot                   = i_xaim_pkt.prfx[PRFX_W_PAR-1:PRFX_WO_PAR];
        f_msglbc_to_xaim.tlp_atu_bypass              = 1'b1;

        req_seg_id                                   = i_xaim_pkt.hdr[`F_HDR_REQ_SEG_ID];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_dsv         = req_seg_id[8];
        f_msglbc_to_xaim.tlp_hdr_pkt.tlp_dst_seg     = req_seg_id[7:0];

    
      end
    endfunction // f_msglbc_to_xaim

    ///////////////////////////////////////////
    // Function to create an OHC-A DW
    ///////////////////////////////////////////
    function automatic logic [31:0] f_ohc_a_pack (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt,
      input ohc_type_e    ohc_type
    );
      begin
        logic [7:0] byte0;
        logic [7:0] byte1;
        logic [7:0] byte2;
        logic [7:0] byte3;

        // Initialise to 0
        byte0 = '0;
        byte1 = '0;
        byte2 = '0;
        byte3 = '0;

        case ( ohc_type )
        E_OHC_A1 : begin
          byte0 = {tlp_hdr_pkt.tlp_nw, tlp_hdr_pkt.tlp_pv, tlp_hdr_pkt.tlp_pmr, tlp_hdr_pkt.tlp_er, tlp_hdr_pkt.tlp_pasid[19:16]};
          byte1 = tlp_hdr_pkt.tlp_pasid[15:8];
          byte2 = tlp_hdr_pkt.tlp_pasid[7:0];
          byte3 = {tlp_hdr_pkt.tlp_ldw_be, tlp_hdr_pkt.tlp_fdw_be};
        end
        E_OHC_A2 : begin
          byte3 = {tlp_hdr_pkt.tlp_ldw_be, tlp_hdr_pkt.tlp_fdw_be};
        end
        E_OHC_A3 : begin
          byte0 = tlp_hdr_pkt.tlp_dst_seg;
          byte2 = {tlp_hdr_pkt.tlp_dsv, 7'h00};
          byte3 = {tlp_hdr_pkt.tlp_ldw_be, tlp_hdr_pkt.tlp_fdw_be};
        end
        E_OHC_A4 : begin
          byte0 = tlp_hdr_pkt.tlp_dst_seg;
          byte1 = tlp_hdr_pkt.tlp_pasid[15:8];
          byte2 = {tlp_hdr_pkt.tlp_dsv, tlp_hdr_pkt.tlp_pv, 2'b00, tlp_hdr_pkt.tlp_pasid[19:16]};
          byte3 = tlp_hdr_pkt.tlp_pasid[7:0];
        end
        E_OHC_A5 : begin
          byte0 = tlp_hdr_pkt.tlp_dst_seg;
          byte1 = tlp_hdr_pkt.tlp_cpl_seg;
          byte2 = {tlp_hdr_pkt.tlp_dsv, 7'h00};
          byte3 = {3'h0, tlp_hdr_pkt.tlp_addr[1:0], tlp_hdr_pkt.tlp_cpl_status};
        end
        endcase

        f_ohc_a_pack = {byte3, byte2, byte1, byte0};
      end
    endfunction // f_ohc_a_pack

    ///////////////////////////////////////////
    // Function to create an OHC-B DW
    ///////////////////////////////////////////
    function automatic logic [31:0] f_ohc_b_pack (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt,
      input ohc_type_e    ohc_type
    );
      begin
        logic [7:0] byte0;
        logic [7:0] byte1;
        logic [7:0] byte2;
        logic [7:0] byte3;

        byte0 = '0;
        byte1 = tlp_hdr_pkt.tlp_st[15:8];
        byte2 = tlp_hdr_pkt.tlp_st[7:0];
        byte3 = {tlp_hdr_pkt.tlp_ph, tlp_hdr_pkt.tlp_hv, tlp_hdr_pkt.tlp_ama, tlp_hdr_pkt.tlp_av};

        f_ohc_b_pack = {byte3, byte2, byte1, byte0};
      end
    endfunction // f_ohc_b_pack

    ///////////////////////////////////////////
    // Function to create an OHC-C DW
    ///////////////////////////////////////////
    function automatic logic [31:0] f_ohc_c_pack (
      input mode_e        mode,
      input tlp_hdr_pkt_s tlp_hdr_pkt,
      input ohc_type_e    ohc_type
    );
      begin
        logic [7:0] byte0;
        logic [7:0] byte1;
        logic [7:0] byte2;
        logic [7:0] byte3;

        byte0 = tlp_hdr_pkt.tlp_req_seg;
        byte1 = tlp_hdr_pkt.tlp_pr_sent_cnt;
        byte2 = tlp_hdr_pkt.tlp_stream_id;
        byte3 = {tlp_hdr_pkt.tlp_sub_stream, tlp_hdr_pkt.tlp_rsv, 1'b0, tlp_hdr_pkt.tlp_k, tlp_hdr_pkt.tlp_t};

        f_ohc_c_pack = {byte3, byte2, byte1, byte0};
      end
    endfunction // f_ohc_c_pack

    ///////////////////////////////////////////
    // Function to Determine OHC Mapping
    ///////////////////////////////////////////
    function automatic logic [6:0] [3:0] f_ohc_map (
      input logic [3:0] base,
      input logic [4:0] ohc_a_present,
      input logic       ohc_b_present,
      input logic       ohc_c_present,
      input logic [2:0] ohc_e_present
    );
      begin
        logic [6:0] [3:0] tlp_ohc_map;
        tlp_ohc_map = '0;

        // Mapping for OHC-A
        if ( |ohc_a_present ) begin
         tlp_ohc_map[OHC_A] = base;
        end
        // Mapping for OHC-B
        if ( ohc_b_present ) begin
          if ( |tlp_ohc_map[OHC_A] )
            tlp_ohc_map[OHC_B] = tlp_ohc_map[OHC_A] + 'd1;
          else
            tlp_ohc_map[OHC_B] = base;
        end
        // Mapping for OHC-C
        if ( ohc_c_present ) begin
          if ( |tlp_ohc_map[OHC_B] )
            tlp_ohc_map[OHC_C] = tlp_ohc_map[OHC_B] + 'd1;
          else if ( |tlp_ohc_map[OHC_A] )
            tlp_ohc_map[OHC_C] = tlp_ohc_map[OHC_A] + 'd1;
          else
            tlp_ohc_map[OHC_C] = base;
        end
        // Mapping for OHC-E
        if ( |ohc_e_present ) begin
          if ( |tlp_ohc_map[OHC_C] )
            tlp_ohc_map[OHC_E1] = tlp_ohc_map[OHC_C] + 'd1;  // OHC-E1
          else if ( |tlp_ohc_map[OHC_B] )
            tlp_ohc_map[OHC_E1] = tlp_ohc_map[OHC_B] + 'd1;
          else if ( |tlp_ohc_map[OHC_A] )
            tlp_ohc_map[OHC_E1] = tlp_ohc_map[OHC_A] + 'd1;
          else
            tlp_ohc_map[OHC_E1] = base;

          if (|ohc_e_present[2:1]) begin                     // OHC-E2
            tlp_ohc_map[OHC_E2] = tlp_ohc_map[OHC_E1] + 'd1;
          end
          if (ohc_e_present[2]) begin                        // OHC-E4
            tlp_ohc_map[OHC_E3] = tlp_ohc_map[OHC_E1] + 'd2;
            tlp_ohc_map[OHC_E4] = tlp_ohc_map[OHC_E1] + 'd3;
          end
        end

        f_ohc_map = tlp_ohc_map;
      end
    endfunction // f_ohc_map

    ///////////////////////////////////////////
    // Function which forms Base header
    ///////////////////////////////////////////
    function automatic logic [3:0] [31:0] f_base_hdr_form (
      input mode_e         mode,
      input tlp_hdr_pkt_s  tlp_hdr_pkt
    );
      begin
        logic [3:0] [31:0] tlp_hdr_dw;
        addr_size_e        addr_size;
        logic              tlp_is_cpl;
        logic              tlp_is_msg;
        logic              tlp_is_cfg;
        logic              tlp_is_io;
        logic              tlp_is_mem_wr;
        logic              tlp_is_mem_rd;
        logic              tlp_is_def_mem_wr;
        logic              tlp_is_mem;
        logic              tlp_is_atomic;
        logic              tlp_is_at_trans_req;

        // Initialise to 0
        tlp_hdr_dw          = '0;

        // Decode TLP
        addr_size           = f_tlp_addr_size(mode, tlp_hdr_pkt);
        tlp_is_cpl          = f_tlp_is_cpl(mode, tlp_hdr_pkt);
        tlp_is_msg          = f_tlp_is_msg(mode, tlp_hdr_pkt);
        tlp_is_io           = f_tlp_is_io(mode, tlp_hdr_pkt);
        tlp_is_mem_wr       = f_tlp_is_memwr(mode, tlp_hdr_pkt);
        tlp_is_mem_rd       = f_tlp_is_memrd(mode, tlp_hdr_pkt);
        tlp_is_def_mem_wr   = f_tlp_is_defmemwr(mode, tlp_hdr_pkt);
        tlp_is_mem          = tlp_is_mem_rd | tlp_is_mem_wr | tlp_is_def_mem_wr;
        tlp_is_atomic       = f_tlp_is_atomic(mode, tlp_hdr_pkt);
        tlp_is_at_trans_req = (tlp_is_mem_rd & (tlp_hdr_pkt.tlp_at == `DC_AT_TRANS_REQ));
        tlp_is_cfg          = f_tlp_is_cfg(mode, tlp_hdr_pkt); 

        // DW0
        if ( mode == E_FM ) begin
          tlp_hdr_dw[0][7:0]   = {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type};
          tlp_hdr_dw[0][15:8]  = {tlp_hdr_pkt.tlp_tc,  tlp_hdr_pkt.tlp_ohc};
          tlp_hdr_dw[0][23:16] = {tlp_hdr_pkt.tlp_ts, tlp_hdr_pkt.tlp_attr, tlp_hdr_pkt.tlp_len[9:8]};
          tlp_hdr_dw[0][31:24] = tlp_hdr_pkt.tlp_len[7:0];
        end else
        if ( mode == E_NFM ) begin
          tlp_hdr_dw[0][7:0]   = {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type};
          tlp_hdr_dw[0][15:8]  = {tlp_hdr_pkt.tlp_tag[9], tlp_hdr_pkt.tlp_tc, tlp_hdr_pkt.tlp_tag[8], tlp_hdr_pkt.tlp_attr[2], tlp_hdr_pkt.tlp_ln, tlp_hdr_pkt.tlp_th};
          tlp_hdr_dw[0][23:16] = {tlp_hdr_pkt.tlp_td, tlp_hdr_pkt.tlp_ep, tlp_hdr_pkt.tlp_attr[1:0], tlp_hdr_pkt.tlp_at, tlp_hdr_pkt.tlp_len[9:8]};
          tlp_hdr_dw[0][31:24] = tlp_hdr_pkt.tlp_len[7:0];
        end

        // DW1
        if ( tlp_is_cpl ) begin
          tlp_hdr_dw[1][7:0]   = tlp_hdr_pkt.tlp_cpl_id[15:8];
          tlp_hdr_dw[1][15:8]  = tlp_hdr_pkt.tlp_cpl_id[7:0];
        end else begin
          tlp_hdr_dw[1][7:0]   = tlp_hdr_pkt.tlp_req_id[15:8];
          tlp_hdr_dw[1][15:8]  = tlp_hdr_pkt.tlp_req_id[7:0];
        end
        if ( mode == E_FM ) begin
          if ( tlp_is_cpl )
            tlp_hdr_dw[1][23:16] = {tlp_hdr_pkt.tlp_ep, tlp_hdr_pkt.tlp_addr[6], tlp_hdr_pkt.tlp_tag[13:8]};
          else if ( tlp_is_msg )
            tlp_hdr_dw[1][23:16] = {tlp_hdr_pkt.tlp_ep, tlp_hdr_pkt.tlp_tag[6:0]};
          else
            tlp_hdr_dw[1][23:16] = {tlp_hdr_pkt.tlp_ep, 1'b0, tlp_hdr_pkt.tlp_tag[13:8]};

          if ( tlp_is_msg )
            tlp_hdr_dw[1][31:24] = tlp_hdr_pkt.tlp_msg_code;
          else
            tlp_hdr_dw[1][31:24] = tlp_hdr_pkt.tlp_tag[7:0];
        end else
        if ( mode == E_NFM ) begin
          if ( tlp_is_cpl )
            tlp_hdr_dw[1][23:16] = {tlp_hdr_pkt.tlp_cpl_status, tlp_hdr_pkt.tlp_bcm, tlp_hdr_pkt.tlp_byte_count[11:8]};
          else if ( tlp_is_mem_wr & tlp_hdr_pkt.tlp_th )
            tlp_hdr_dw[1][23:16] = tlp_hdr_pkt.tlp_st[7:0];
          else
            tlp_hdr_dw[1][23:16] = tlp_hdr_pkt.tlp_tag[7:0];

          if ( tlp_is_cpl )
            tlp_hdr_dw[1][31:24] = tlp_hdr_pkt.tlp_byte_count[7:0];
          else if ( tlp_is_msg )
            tlp_hdr_dw[1][31:24] = tlp_hdr_pkt.tlp_msg_code;
          else if ( ( tlp_is_mem_rd | tlp_is_def_mem_wr | tlp_is_atomic ) & tlp_hdr_pkt.tlp_th )
            tlp_hdr_dw[1][31:24] = tlp_hdr_pkt.tlp_st[7:0];
          else
            tlp_hdr_dw[1][31:24] = {tlp_hdr_pkt.tlp_ldw_be, tlp_hdr_pkt.tlp_fdw_be};
        end

        // DW2
        if ( ( tlp_is_io | tlp_is_mem | tlp_is_atomic ) & ( addr_size == E_ADDR32) ) begin
          tlp_hdr_dw[2][7:0]   = tlp_hdr_pkt.tlp_addr[31:24];
          tlp_hdr_dw[2][15:8]  = tlp_hdr_pkt.tlp_addr[23:16];
          tlp_hdr_dw[2][23:16] = tlp_hdr_pkt.tlp_addr[15:8];
          if ( mode == E_FM )
            tlp_hdr_dw[2][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], tlp_hdr_pkt.tlp_at};
          else
          if ( tlp_is_at_trans_req )
            tlp_hdr_dw[2][31:24] = {tlp_hdr_pkt.tlp_addr[7:1], tlp_hdr_pkt.tlp_nw};
          else if ( tlp_hdr_pkt.tlp_th & ( tlp_is_atomic | tlp_is_mem_rd | tlp_is_mem_wr ))
            tlp_hdr_dw[2][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], tlp_hdr_pkt.tlp_ph};
          else
            tlp_hdr_dw[2][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], 2'b00};
        end else if ( tlp_is_cfg ) begin
          tlp_hdr_dw[2][7:0]   = tlp_hdr_pkt.tlp_dst_id[15:8];
          tlp_hdr_dw[2][15:8]  = tlp_hdr_pkt.tlp_dst_id[7:0];
          tlp_hdr_dw[2][23:16] = {4'h0, tlp_hdr_pkt.tlp_ext_reg_num};
          tlp_hdr_dw[2][31:24] = {tlp_hdr_pkt.tlp_reg_num, 2'b00};
        end else if ( tlp_is_cpl & (mode == E_FM) ) begin
          tlp_hdr_dw[2][7:0]   = tlp_hdr_pkt.tlp_req_id[15:8];
          tlp_hdr_dw[2][15:8]  = tlp_hdr_pkt.tlp_req_id[7:0];
          tlp_hdr_dw[2][23:16] = {tlp_hdr_pkt.tlp_addr[5:2], tlp_hdr_pkt.tlp_byte_count[11:8]};
          tlp_hdr_dw[2][31:24] = tlp_hdr_pkt.tlp_byte_count[7:0];
        end else if ( tlp_is_cpl & (mode == E_NFM) ) begin
          tlp_hdr_dw[2][7:0]   = tlp_hdr_pkt.tlp_req_id[15:8];
          tlp_hdr_dw[2][15:8]  = tlp_hdr_pkt.tlp_req_id[7:0];
          tlp_hdr_dw[2][23:16] = tlp_hdr_pkt.tlp_tag[7:0];
          tlp_hdr_dw[2][31:24] = {1'b0, tlp_hdr_pkt.tlp_addr[6:0]};
        end else begin
          tlp_hdr_dw[2][7:0]   = tlp_hdr_pkt.tlp_addr[63:56];
          tlp_hdr_dw[2][15:8]  = tlp_hdr_pkt.tlp_addr[55:48];
          tlp_hdr_dw[2][23:16] = tlp_hdr_pkt.tlp_addr[47:40];
          tlp_hdr_dw[2][31:24] = tlp_hdr_pkt.tlp_addr[39:32];
        end

        // DW3
        if ( ( tlp_is_io | tlp_is_mem | tlp_is_atomic | tlp_is_msg ) & ( addr_size == E_ADDR64) ) begin
          tlp_hdr_dw[3][7:0]   = tlp_hdr_pkt.tlp_addr[31:24];
          tlp_hdr_dw[3][15:8]  = tlp_hdr_pkt.tlp_addr[23:16];
          tlp_hdr_dw[3][23:16] = tlp_hdr_pkt.tlp_addr[15:8];
          if ( tlp_is_msg )
            tlp_hdr_dw[3][31:24] = tlp_hdr_pkt.tlp_addr[7:0];
          else if (mode == E_FM)
            tlp_hdr_dw[3][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], tlp_hdr_pkt.tlp_at};
          else if ( tlp_is_at_trans_req )
            tlp_hdr_dw[3][31:24] = {tlp_hdr_pkt.tlp_addr[7:1], tlp_hdr_pkt.tlp_nw};
          else if ( tlp_hdr_pkt.tlp_th & ( tlp_is_atomic | tlp_is_mem_rd | tlp_is_mem_wr ))
            tlp_hdr_dw[3][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], tlp_hdr_pkt.tlp_ph};
          else
            tlp_hdr_dw[3][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], 2'b00};
        end
    
        f_base_hdr_form = tlp_hdr_dw; // Assign Output
    
      end
    endfunction // f_base_hdr_form

    ///////////////////////////////////////////
    // Function which forms Base header for Flit Mode
    ///////////////////////////////////////////
    function automatic logic [3:0] [31:0] f_base_hdr_form_fm (
        input mode_e         mode,
        input tlp_hdr_pkt_s  tlp_hdr_pkt
    );
        begin
            logic [3:0] [31:0] tlp_hdr_dw_fm;
            addr_size_e        addr_size;
            logic              tlp_is_cpl;
            logic              tlp_is_msg;
            logic              tlp_is_msgd;
            logic              tlp_is_cfg;
            logic              tlp_is_io;
            logic              tlp_is_mem_wr;
            logic              tlp_is_mem_rd;
            logic              tlp_is_def_mem_wr;
            logic              tlp_is_mem;
            logic              tlp_is_atomic;
            logic              tlp_is_at_trans_req;

        // Initialise to 0
            tlp_hdr_dw_fm          = '0;

        // Decode TLP
            addr_size           = f_tlp_addr_size(mode, tlp_hdr_pkt);
            tlp_is_cpl          = f_tlp_is_cpl(mode, tlp_hdr_pkt);
            tlp_is_msg          = f_tlp_is_msg(mode, tlp_hdr_pkt);
            tlp_is_msgd         = f_tlp_is_msgd(mode, tlp_hdr_pkt);
            tlp_is_io           = f_tlp_is_io(mode, tlp_hdr_pkt);
            tlp_is_mem_wr       = f_tlp_is_memwr(mode, tlp_hdr_pkt);
            tlp_is_mem_rd       = f_tlp_is_memrd(mode, tlp_hdr_pkt);
            tlp_is_def_mem_wr   = f_tlp_is_defmemwr(mode, tlp_hdr_pkt);
            tlp_is_mem          = tlp_is_mem_rd | tlp_is_mem_wr | tlp_is_def_mem_wr;
            tlp_is_atomic       = f_tlp_is_atomic(mode, tlp_hdr_pkt);
            tlp_is_at_trans_req = (tlp_is_mem_rd & (tlp_hdr_pkt.tlp_at == `DC_AT_TRANS_REQ));
            tlp_is_cfg          = f_tlp_is_cfg(mode, tlp_hdr_pkt); 


///////////////////////////////////////////
    if ( mode == E_FM ) begin
///////////////////////////////////////////
// DW0 - Byte 0-3 -- Header fields match for all TLP types
        tlp_hdr_dw_fm[0][7:0]   = {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type};                                  // B0
        tlp_hdr_dw_fm[0][15:8]  = {tlp_hdr_pkt.tlp_tc,  tlp_hdr_pkt.tlp_ohc};                                   // B1
        tlp_hdr_dw_fm[0][23:16] = {tlp_hdr_pkt.tlp_ts, tlp_hdr_pkt.tlp_attr, tlp_hdr_pkt.tlp_len[9:8]};         // B2
        tlp_hdr_dw_fm[0][31:24] = tlp_hdr_pkt.tlp_len[7:0];                                                     // B3
//*****************************************************************************
// DW1 - Byte 4-7
        if ( tlp_is_mem | tlp_is_atomic | tlp_is_io | tlp_is_cfg) begin // all mem types match Byte 4-5
            tlp_hdr_dw_fm[1][7:0]   = {tlp_hdr_pkt.tlp_req_id[15:8]};                                           // B4
            tlp_hdr_dw_fm[1][15:8]  = {tlp_hdr_pkt.tlp_req_id[7:0]};                                            // B5
            tlp_hdr_dw_fm[1][23:16] = {tlp_hdr_pkt.tlp_ep, 1'b0, tlp_hdr_pkt.tlp_tag[13:8]};                    // B6
            tlp_hdr_dw_fm[1][31:24] = tlp_hdr_pkt.tlp_tag[7:0];                                                 // B7
        end else if ( tlp_is_cpl ) begin
            tlp_hdr_dw_fm[1][7:0]   = tlp_hdr_pkt.tlp_cpl_id[15:8];                                             // B4
            tlp_hdr_dw_fm[1][15:8]  = tlp_hdr_pkt.tlp_cpl_id[7:0];                                              // B5
            tlp_hdr_dw_fm[1][23:16] = {tlp_hdr_pkt.tlp_ep, tlp_hdr_pkt.tlp_addr[6], tlp_hdr_pkt.tlp_tag[13:8]}; // B6
            tlp_hdr_dw_fm[1][31:24] = tlp_hdr_pkt.tlp_tag[7:0];                                                 // B7
        end else if ( tlp_is_msg | tlp_is_msgd ) begin
            tlp_hdr_dw_fm[1][7:0]   = tlp_hdr_pkt.tlp_req_id[15:8];                                             // B4
            tlp_hdr_dw_fm[1][15:8]  = tlp_hdr_pkt.tlp_req_id[7:0];                                              // B5
            if( tlp_hdr_pkt.tlp_msg_code[7:0] == `INVALIDATE_REQUEST ) begin
                tlp_hdr_dw_fm[1][23:16] = {tlp_hdr_pkt.tlp_ep, 2'b00, tlp_hdr_pkt.tlp_itag};                    // B6
            end else if ((tlp_hdr_pkt.tlp_msg_code[7:0] == `VENDOR_TYPE0) | (tlp_hdr_pkt.tlp_msg_code[7:0] == `VENDOR_TYPE1)) begin // incl PCI SIG, DRS, FRS, Hierarchy ID
                tlp_hdr_dw_fm[1][23:16] = {tlp_hdr_pkt.tlp_ep, tlp_hdr_pkt.tlp_vend_def[38:32]};                // B6 
            end else begin
                tlp_hdr_dw_fm[1][23:16] = {tlp_hdr_pkt.tlp_ep, tlp_hdr_pkt.tlp_tag[6:0]};                       // B6 
            end
            tlp_hdr_dw_fm[1][31:24] = tlp_hdr_pkt.tlp_msg_code;                                                 // B7
        end
//*****************************************************************************
// DW2 - Byte 8-11
        if ( tlp_is_io | tlp_is_mem | tlp_is_atomic ) begin
            if ( addr_size == E_ADDR64) begin 
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_addr[63:56];                                          // B8
                tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_addr[55:48];                                          // B9
                tlp_hdr_dw_fm[2][23:16] = tlp_hdr_pkt.tlp_addr[47:40];                                          // B10
                tlp_hdr_dw_fm[2][31:24] = tlp_hdr_pkt.tlp_addr[39:32];                                          // B11
            end else if ( addr_size == E_ADDR32) begin
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_addr[31:24];                                          // B8
                tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_addr[23:16];                                          // B9
                tlp_hdr_dw_fm[2][23:16] = tlp_hdr_pkt.tlp_addr[15:8];                                           // B10
                tlp_hdr_dw_fm[2][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], tlp_hdr_pkt.tlp_at};                      // B11
            end
        end else if ( tlp_is_cfg ) begin
            tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_dst_id[15:8];                                             // B8
            tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_dst_id[7:0];                                              // B9
            tlp_hdr_dw_fm[2][23:16] = {4'h0, tlp_hdr_pkt.tlp_ext_reg_num};                                      // B10
            tlp_hdr_dw_fm[2][31:24] = {tlp_hdr_pkt.tlp_reg_num, 2'b00};                                         // B11
        end else if ( tlp_is_cpl ) begin
            tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_dst_id[15:8];                                             // B8
            tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_dst_id[7:0];                                              // B9
            tlp_hdr_dw_fm[2][23:16] = {tlp_hdr_pkt.tlp_addr[5:2], tlp_hdr_pkt.tlp_byte_count[11:8]};            // B10
            tlp_hdr_dw_fm[2][31:24] = tlp_hdr_pkt.tlp_byte_count[7:0];                                          // B11
        end else if ( tlp_is_msg | tlp_is_msgd ) begin
//            if ( tlp_hdr_pkt.tlp_type[2:0] == E_MR_BY_ADDR ) begin //route by address - when addressing below 4GB the upper 32 address bits must be zero
            if ( tlp_hdr_pkt.tlp_type[2:0] == E_MR_BY_ID ) begin //route by ID
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_bn;                                                   // B8
                tlp_hdr_dw_fm[2][15:8]  = {tlp_hdr_pkt.tlp_dn, tlp_hdr_pkt.tlp_fn[2:0]};                        // B9
            end else if ( tlp_hdr_pkt.tlp_subtype== 8'b00000001 ) begin // tlp_type=rsvd //Hierarchy ID Message
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_hier_id[15:8];                                        // B8
                tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_hier_id[7:0];                                         // B9
            end
            if( tlp_hdr_pkt.tlp_msg_code[7:0] == `INVALIDATE_COMPLETION ) begin
                tlp_hdr_dw_fm[2][31:24] = {5'b00000, tlp_hdr_pkt.tlp_cc};                                       // B11
            end else if ( tlp_hdr_pkt.tlp_msg_code[7:0] == `PRS_REQ_TYPE ) begin
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_page_address[63:56];                                  // B8
                tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_page_address[55:48];                                  // B9
                tlp_hdr_dw_fm[2][23:16] = tlp_hdr_pkt.tlp_page_address[47:40];                                  // B10
                tlp_hdr_dw_fm[2][31:24] = tlp_hdr_pkt.tlp_page_address[39:32];                                  // B11
            end else if ( tlp_hdr_pkt.tlp_msg_code[7:0] == `PRG_RES_TYPE ) begin
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_dst_id[15:8];                                         // B8
                tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_dst_id[7:0];                                          // B9
                tlp_hdr_dw_fm[2][23:16] = {tlp_hdr_pkt.tlp_response_code, 3'b000, tlp_hdr_pkt.tlp_prg_index[8]};// B10
                tlp_hdr_dw_fm[2][31:24] = tlp_hdr_pkt.tlp_prg_index[7:0];                                       // B11
            end else if( tlp_hdr_pkt.tlp_msg_code[7:0] == `ERR_COR ) begin // ERR_NONFATAL and ERR_FATAL do not have the ECS field
                tlp_hdr_dw_fm[2][7:0]   = {tlp_hdr_pkt.tlp_ecs, 6'h00};                                         // B8
            end else if (  tlp_hdr_pkt.tlp_msg_code[7:0] == `IDE_FAIL_MSG_TYPE | tlp_hdr_pkt.tlp_msg_code[7:0] == `IDE_SYNC_MSG_TYPE ) begin
                if ( tlp_hdr_pkt.tlp_type[2:0] == E_MR_BY_ID ) begin // Selective Stream 
                    tlp_hdr_dw_fm[2][7:0]   = {tlp_hdr_pkt.tlp_destination_rid[15:8]};                          // B8
                    tlp_hdr_dw_fm[2][15:8]  = {tlp_hdr_pkt.tlp_destination_rid[7:0]};                           // B9
                end
                if ( tlp_hdr_pkt.tlp_msg_code[0] == 1'b1 ) begin // Fail Message (Link and Selective)
                    tlp_hdr_dw_fm[2][31:24] = tlp_hdr_pkt.tlp_ide_stream_id[7:0];                               // B11
                end
            end else if ((tlp_hdr_pkt.tlp_msg_code[7:0] == `VENDOR_TYPE0) | (tlp_hdr_pkt.tlp_msg_code[7:0] == `VENDOR_TYPE1)) begin // incl PCI SIG, DRS, FRS, Hierarchy ID
                if ( tlp_hdr_pkt.tlp_type[2:0] == E_MR_BY_ID ) begin // route by ID
                    tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_dst_id[15:8];                                     // B8
                    tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_dst_id[7:0];                                      // B9
                end
                tlp_hdr_dw_fm[2][23:16] = tlp_hdr_pkt.tlp_vend_id[15:8];                                        // B10
                tlp_hdr_dw_fm[2][31:24] = tlp_hdr_pkt.tlp_vend_id[7:0];                                         // B11
            //PTM messages (PTM_RES_TYPE) are generated in MSG_GEN so not considered by XAIM
            end
        end
//*****************************************************************************
// DW3 - Byte 12-15 - IO CFG and CPL are always only 3DW
        if ( ( tlp_is_mem | tlp_is_atomic ) & ( addr_size == E_ADDR64) ) begin
            tlp_hdr_dw_fm[3][7:0]   = tlp_hdr_pkt.tlp_addr[31:24];                                              // B12
            tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.tlp_addr[23:16];                                              // B13
            tlp_hdr_dw_fm[3][23:16] = tlp_hdr_pkt.tlp_addr[15:8];                                               // B14
            tlp_hdr_dw_fm[3][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], tlp_hdr_pkt.tlp_at};                          // B15
        end else if ( tlp_is_msg | tlp_is_msgd ) begin
            if ( tlp_hdr_pkt.tlp_type[2:0] == E_MR_BY_ADDR ) begin // route by address
                tlp_hdr_dw_fm[3][7:0]   = tlp_hdr_pkt.tlp_addr[31:24];                                          // B12
                tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.tlp_addr[23:16];                                          // B13
                tlp_hdr_dw_fm[3][23:16] = tlp_hdr_pkt.tlp_addr[15:8];                                           // B14
                tlp_hdr_dw_fm[3][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], tlp_hdr_pkt.tlp_at};                      // B15
            end else if( tlp_hdr_pkt.tlp_msg_code[7:0] == `INVALIDATE_COMPLETION ) begin
                tlp_hdr_dw_fm[3][7:0]   = tlp_hdr_pkt.tlp_itag_vector[31:24];                                   // B12
                tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.tlp_itag_vector[23:16];                                   // B13
                tlp_hdr_dw_fm[3][23:16] = tlp_hdr_pkt.tlp_itag_vector[15:8];                                    // B14
                tlp_hdr_dw_fm[3][31:24] = tlp_hdr_pkt.tlp_itag_vector[7:0];                                     // B15
            end else if ( tlp_hdr_pkt.tlp_msg_code[7:0] == `PRS_REQ_TYPE ) begin
                tlp_hdr_dw_fm[3][7:0]   = tlp_hdr_pkt.tlp_page_address[31:24];                                  // B12
                tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.tlp_page_address[23:16];                                  // B13
                tlp_hdr_dw_fm[3][23:16] = tlp_hdr_pkt.tlp_page_address[15:8];                                   // B14
                tlp_hdr_dw_fm[3][31:24] = tlp_hdr_pkt.tlp_page_address[7:0];                                    // B15
            end else if ((tlp_hdr_pkt.tlp_msg_code[7:0] == `VENDOR_TYPE0) | (tlp_hdr_pkt.tlp_msg_code[7:0] == `VENDOR_TYPE1)) begin // incl PCI SIG, DRS, FRS, Hierarchy ID
                tlp_hdr_dw_fm[3][7:0]   = tlp_hdr_pkt.tlp_vend_def[31:24];                                      // B12
                tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.tlp_vend_def[23:16];                                      // B13
                tlp_hdr_dw_fm[3][23:16] = tlp_hdr_pkt.tlp_vend_def[15:8];                                       // B14
                tlp_hdr_dw_fm[3][31:24] = tlp_hdr_pkt.tlp_vend_def[7:0];                                        // B15
            end else if( tlp_hdr_pkt.tlp_msg_code[7:0] == `LTR_MSG_CODE ) begin
                tlp_hdr_dw_fm[3][7:0]   = tlp_hdr_pkt.no_snoop_latency[15:8];                                   // B12
                tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.no_snoop_latency[7:0];                                    // B13
                tlp_hdr_dw_fm[3][23:16] = tlp_hdr_pkt.snoop_latency[15:8];                                      // B14
                tlp_hdr_dw_fm[3][31:24] = tlp_hdr_pkt.snoop_latency[7:0];                                       // B15
            end else if ( tlp_hdr_pkt.tlp_msg_code[7:0] == `OBFF ) begin
                tlp_hdr_dw_fm[3][31:24] = { 4'b0000, tlp_hdr_pkt.tlp_obff_code };                               // B15
            end else if ( tlp_hdr_pkt.tlp_msg_code[7:0] == `IDE_SYNC_MSG_TYPE ) begin // Sync message (Link and Selective) IDE Stream 
                tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.tlp_pr_sent_counter_cpl;                                  // B13
                tlp_hdr_dw_fm[3][31:24] = tlp_hdr_pkt.tlp_pr_sent_counter_npr;                                  // B15
            //PTM messages (PTM_RES_TYPE) are generated in MSG_GEN so not considered by XAIM
            end
        end
//*****************************************************************************
// DW4-DW7 - Currently do a straight swap Hdr field in - Hdr field out so do not consider here
//*****************************************************************************

///////////////////////////////////////////
    end else if ( mode == E_NFM ) begin
///////////////////////////////////////////
//*****************************************************************************
// DW0 - Byte 0-3 -- Header fields match for all TLP types
        tlp_hdr_dw_fm[0][7:0]   = {tlp_hdr_pkt.tlp_fmt, tlp_hdr_pkt.tlp_type};                                  // B0
        tlp_hdr_dw_fm[0][15:8]  = {tlp_hdr_pkt.tlp_tag[9], tlp_hdr_pkt.tlp_tc, tlp_hdr_pkt.tlp_tag[8], tlp_hdr_pkt.tlp_attr[2], tlp_hdr_pkt.tlp_ln, tlp_hdr_pkt.tlp_th}; // B1
        tlp_hdr_dw_fm[0][23:16] = {tlp_hdr_pkt.tlp_td, tlp_hdr_pkt.tlp_ep, tlp_hdr_pkt.tlp_attr[1:0], tlp_hdr_pkt.tlp_at, tlp_hdr_pkt.tlp_len[9:8]};                     // B2
        tlp_hdr_dw_fm[0][31:24] = tlp_hdr_pkt.tlp_len[7:0];                                                     // B3
//*****************************************************************************
// DW1 - Byte 4-7
        if ( tlp_is_mem | tlp_is_atomic | tlp_is_io | tlp_is_cfg) begin // all mem types match Byte 4-5
            tlp_hdr_dw_fm[1][7:0]   = tlp_hdr_pkt.tlp_req_id[15:8];                                             // B4
            tlp_hdr_dw_fm[1][15:8]  = tlp_hdr_pkt.tlp_req_id[7:0];                                              // B5
            if (tlp_is_mem_wr & tlp_hdr_pkt.tlp_th) begin
                tlp_hdr_dw_fm[1][23:16] = tlp_hdr_pkt.tlp_st[7:0];                                              // B6
                tlp_hdr_dw_fm[1][31:24] = {tlp_hdr_pkt.tlp_ldw_be, tlp_hdr_pkt.tlp_fdw_be};                     // B7
            end else if ( (tlp_is_mem_rd | tlp_is_def_mem_wr | tlp_is_atomic) & tlp_hdr_pkt.tlp_th ) begin
                tlp_hdr_dw_fm[1][23:16] = tlp_hdr_pkt.tlp_tag[7:0];                                             // B6 
                tlp_hdr_dw_fm[1][31:24] = tlp_hdr_pkt.tlp_st[7:0];                                              // B7
            end else begin // ( tlp_is_io | tlp_is_cfg | !TH)
                tlp_hdr_dw_fm[1][23:16] = tlp_hdr_pkt.tlp_tag[7:0];                                             // B6 
                tlp_hdr_dw_fm[1][31:24] = {tlp_hdr_pkt.tlp_ldw_be, tlp_hdr_pkt.tlp_fdw_be};                     // B7
            end
        end else if ( tlp_is_cpl ) begin
            tlp_hdr_dw_fm[1][7:0]   = tlp_hdr_pkt.tlp_cpl_id[15:8];                                             // B4
            tlp_hdr_dw_fm[1][15:8]  = tlp_hdr_pkt.tlp_cpl_id[7:0];                                              // B5
            tlp_hdr_dw_fm[1][23:16] = {tlp_hdr_pkt.tlp_cpl_status, tlp_hdr_pkt.tlp_bcm, tlp_hdr_pkt.tlp_byte_count[11:8]}; // B6
            tlp_hdr_dw_fm[1][31:24] = tlp_hdr_pkt.tlp_byte_count[7:0];                                          // B7
        end else if ( tlp_is_msg | tlp_is_msgd ) begin
            tlp_hdr_dw_fm[1][7:0]   = tlp_hdr_pkt.tlp_req_id[15:8];                                             // B4
            tlp_hdr_dw_fm[1][15:8]  = tlp_hdr_pkt.tlp_req_id[7:0];                                              // B5
            if( tlp_hdr_pkt.tlp_msg_code[7:0] == `INVALIDATE_REQUEST ) begin
                tlp_hdr_dw_fm[1][23:16] = {3'b000, tlp_hdr_pkt.tlp_itag};                                       // B6
            end else if ((tlp_hdr_pkt.tlp_msg_code[7:0] == `VENDOR_TYPE0) | (tlp_hdr_pkt.tlp_msg_code[7:0] == `VENDOR_TYPE1)) begin // incl PCI SIG, DRS, FRS, Hierarchy ID
                tlp_hdr_dw_fm[1][23:16] = {1'b0, tlp_hdr_pkt.tlp_vend_def[38:32]};                              // B6 
            end else begin
                tlp_hdr_dw_fm[1][23:16] = tlp_hdr_pkt.tlp_tag[7:0];                                             // B6 
            end
            tlp_hdr_dw_fm[1][31:24] = tlp_hdr_pkt.tlp_msg_code;                                                 // B7
        end
//*****************************************************************************
// DW2 - Byte 8-11
        if ( tlp_is_io | tlp_is_mem | tlp_is_atomic ) begin
            if ( addr_size == E_ADDR64) begin 
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_addr[63:56];                                          // B8
                tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_addr[55:48];                                          // B9
                tlp_hdr_dw_fm[2][23:16] = tlp_hdr_pkt.tlp_addr[47:40];                                          // B10
                tlp_hdr_dw_fm[2][31:24] = tlp_hdr_pkt.tlp_addr[39:32];                                          // B11
            end else if ( addr_size == E_ADDR32) begin
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_addr[31:24];                                          // B8
                tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_addr[23:16];                                          // B9
                tlp_hdr_dw_fm[2][23:16] = tlp_hdr_pkt.tlp_addr[15:8];                                           // B10
                if ( tlp_is_at_trans_req ) begin
                    tlp_hdr_dw_fm[2][31:24] = {tlp_hdr_pkt.tlp_addr[7:1], tlp_hdr_pkt.tlp_nw};                  // B11
                end else if ( tlp_hdr_pkt.tlp_th & ( tlp_is_atomic | tlp_is_mem )) begin
                    tlp_hdr_dw_fm[2][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], tlp_hdr_pkt.tlp_ph};                  // B11
                end else begin // (tlp_is_io)
                    tlp_hdr_dw_fm[2][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], 2'b00};                               // B11
                end
            end
        end else if ( tlp_is_cfg ) begin
            tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_dst_id[15:8];                                             // B8
            tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_dst_id[7:0];                                              // B9
            tlp_hdr_dw_fm[2][23:16] = {4'h0, tlp_hdr_pkt.tlp_ext_reg_num};                                      // B10
            tlp_hdr_dw_fm[2][31:24] = {tlp_hdr_pkt.tlp_reg_num, 2'b00};                                         // B11
        end else if ( tlp_is_cpl ) begin
            tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_req_id[15:8];                                             // B8
            tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_req_id[7:0];                                              // B9
            tlp_hdr_dw_fm[2][23:16] = tlp_hdr_pkt.tlp_tag[7:0];                                                 // B10
            tlp_hdr_dw_fm[2][31:24] = {1'b0, tlp_hdr_pkt.tlp_addr[6:0]};                                        // B11
        end else if ( tlp_is_msg | tlp_is_msgd ) begin
            if ( tlp_hdr_pkt.tlp_type[2:0] == E_MR_BY_ADDR ) begin // route by address
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_addr[31:24];                                          // B8
                tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_addr[23:16];                                          // B9
                tlp_hdr_dw_fm[2][23:16] = tlp_hdr_pkt.tlp_addr[15:8];                                           // B10
                tlp_hdr_dw_fm[2][31:24] = tlp_hdr_pkt.tlp_addr[7:0];                                            // B11
            end else if ( tlp_hdr_pkt.tlp_type[2:0] == E_MR_BY_ID ) begin // route by ID
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_bn;                                                   // B8
                tlp_hdr_dw_fm[2][15:8]  = {tlp_hdr_pkt.tlp_dn, tlp_hdr_pkt.tlp_fn[2:0]};                        // B9
            end else if ( tlp_hdr_pkt.tlp_subtype== 8'b00000001 ) begin // tlp_type=rsvd //Hierarchy ID Message
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_hier_id[15:8];                                        // B8
                tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_hier_id[7:0];                                         // B9
            end
            if( tlp_hdr_pkt.tlp_msg_code[7:0] == `INVALIDATE_COMPLETION ) begin
                tlp_hdr_dw_fm[2][31:24] = {5'b00000, tlp_hdr_pkt.tlp_cc};                                       // B11
            end else if ( tlp_hdr_pkt.tlp_msg_code[7:0] == `PRS_REQ_TYPE ) begin
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_page_address[63:56];                                  // B8
                tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_page_address[55:48];                                  // B9
                tlp_hdr_dw_fm[2][23:16] = tlp_hdr_pkt.tlp_page_address[47:40];                                  // B10
                tlp_hdr_dw_fm[2][31:24] = tlp_hdr_pkt.tlp_page_address[39:32];                                  // B11
            end else if ( tlp_hdr_pkt.tlp_msg_code[7:0] == `PRG_RES_TYPE ) begin
                tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_dst_id[15:8];                                         // B8
                tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_dst_id[7:0];                                          // B9
                tlp_hdr_dw_fm[2][23:16] = {tlp_hdr_pkt.tlp_response_code, 3'b000, tlp_hdr_pkt.tlp_prg_index[8]};// B10
                tlp_hdr_dw_fm[2][31:24] = tlp_hdr_pkt.tlp_prg_index[7:0];                                       // B11
            end else if( tlp_hdr_pkt.tlp_msg_code[7:0] == `ERR_COR ) begin // ERR_NONFATAL and ERR_FATAL do not have the ECS field
                tlp_hdr_dw_fm[2][7:0]   = {tlp_hdr_pkt.tlp_ecs, 6'h00};                                         // B8
            end else if (  tlp_hdr_pkt.tlp_msg_code[7:0] == `IDE_FAIL_MSG_TYPE | tlp_hdr_pkt.tlp_msg_code[7:0] == `IDE_SYNC_MSG_TYPE ) begin
                if ( tlp_hdr_pkt.tlp_type[2:0] == E_MR_BY_ID ) begin // Selective Stream 
                    tlp_hdr_dw_fm[2][7:0]   = {tlp_hdr_pkt.tlp_destination_rid[15:8]};                          // B8
                    tlp_hdr_dw_fm[2][15:8]  = {tlp_hdr_pkt.tlp_destination_rid[7:0]};                           // B9
                end
                if ( tlp_hdr_pkt.tlp_msg_code[0] == 1'b1 ) begin // Fail Message (Link and Selective)
                    tlp_hdr_dw_fm[2][31:24] = tlp_hdr_pkt.tlp_ide_stream_id[7:0];                               // B11
                end
            end else if ((tlp_hdr_pkt.tlp_msg_code[7:0] == `VENDOR_TYPE0) | (tlp_hdr_pkt.tlp_msg_code[7:0] == `VENDOR_TYPE1)) begin // incl PCI SIG, DRS, FRS, Hierarchy ID
                if ( tlp_hdr_pkt.tlp_type[2:0] == E_MR_BY_ID ) begin // route by ID
                    tlp_hdr_dw_fm[2][7:0]   = tlp_hdr_pkt.tlp_dst_id[15:8];                                     // B8
                    tlp_hdr_dw_fm[2][15:8]  = tlp_hdr_pkt.tlp_dst_id[7:0];                                      // B9
                end 
                tlp_hdr_dw_fm[2][23:16] = tlp_hdr_pkt.tlp_vend_id[15:8];                                        // B10
                tlp_hdr_dw_fm[2][31:24] = tlp_hdr_pkt.tlp_vend_id[7:0];                                         // B11
            //PTM messages (PTM_RES_TYPE) are generated in MSG_GEN so not considered by XAIM
            end
        end
//*****************************************************************************
// DW3 - Byte 12-15 - IO CFG and CPL are always only 3DW
        if ( ( tlp_is_mem | tlp_is_atomic ) & ( addr_size == E_ADDR64) ) begin 
            tlp_hdr_dw_fm[3][7:0]   = tlp_hdr_pkt.tlp_addr[31:24];                                              // B12
            tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.tlp_addr[23:16];                                              // B13
            tlp_hdr_dw_fm[3][23:16] = tlp_hdr_pkt.tlp_addr[15:8];                                               // B14
            if ( tlp_is_at_trans_req ) begin
                tlp_hdr_dw_fm[3][31:24] = {tlp_hdr_pkt.tlp_addr[7:1], tlp_hdr_pkt.tlp_nw};                      // B15
            end else if ( tlp_hdr_pkt.tlp_th & ( tlp_is_atomic | tlp_is_mem )) begin
                tlp_hdr_dw_fm[3][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], tlp_hdr_pkt.tlp_ph};                      // B15
            end else // (tlp_is_io)
                tlp_hdr_dw_fm[3][31:24] = {tlp_hdr_pkt.tlp_addr[7:2], 2'b00};                                   // B15
        end else if ( tlp_is_msg | tlp_is_msgd ) begin
            if ( tlp_hdr_pkt.tlp_type[2:0] == E_MR_BY_ADDR ) begin // route by address
                tlp_hdr_dw_fm[3][7:0]   = tlp_hdr_pkt.tlp_addr[31:24];                                          // B12
                tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.tlp_addr[23:16];                                          // B13
                tlp_hdr_dw_fm[3][23:16] = tlp_hdr_pkt.tlp_addr[15:8];                                           // B14
                tlp_hdr_dw_fm[3][31:24] = tlp_hdr_pkt.tlp_addr[7:0];                                            // B15
            end else if( tlp_hdr_pkt.tlp_msg_code[7:0] == `INVALIDATE_COMPLETION ) begin
                tlp_hdr_dw_fm[3][7:0]   = tlp_hdr_pkt.tlp_itag_vector[31:24];                                   // B12
                tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.tlp_itag_vector[23:16];                                   // B13
                tlp_hdr_dw_fm[3][23:16] = tlp_hdr_pkt.tlp_itag_vector[15:8];                                    // B14
                tlp_hdr_dw_fm[3][31:24] = tlp_hdr_pkt.tlp_itag_vector[7:0];                                     // B15
            end else if ( tlp_hdr_pkt.tlp_msg_code[7:0] == `PRS_REQ_TYPE ) begin
                tlp_hdr_dw_fm[3][7:0]   = tlp_hdr_pkt.tlp_page_address[31:24];                                  // B12
                tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.tlp_page_address[23:16];                                  // B13
                tlp_hdr_dw_fm[3][23:16] = tlp_hdr_pkt.tlp_page_address[15:8];                                   // B14
                tlp_hdr_dw_fm[3][31:24] = tlp_hdr_pkt.tlp_page_address[7:0];                                    // B15
            end else if ((tlp_hdr_pkt.tlp_msg_code[7:0] == `VENDOR_TYPE0) | (tlp_hdr_pkt.tlp_msg_code[7:0] == `VENDOR_TYPE1)) begin // incl PCI SIG, DRS, FRS, Hierarchy ID
                tlp_hdr_dw_fm[3][7:0]   = tlp_hdr_pkt.tlp_vend_def[31:24];                                      // B12
                tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.tlp_vend_def[23:16];                                      // B13
                tlp_hdr_dw_fm[3][23:16] = tlp_hdr_pkt.tlp_vend_def[15:8];                                       // B14
                tlp_hdr_dw_fm[3][31:24] = tlp_hdr_pkt.tlp_vend_def[7:0];                                        // B15
            end else if( tlp_hdr_pkt.tlp_msg_code[7:0] == `LTR_MSG_CODE ) begin
                tlp_hdr_dw_fm[3][7:0]   = tlp_hdr_pkt.no_snoop_latency[15:8];                                   // B12
                tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.no_snoop_latency[7:0];                                    // B13
                tlp_hdr_dw_fm[3][23:16] = tlp_hdr_pkt.snoop_latency[15:8];                                      // B14
                tlp_hdr_dw_fm[3][31:24] = tlp_hdr_pkt.snoop_latency[7:0];                                       // B15
            end else if ( tlp_hdr_pkt.tlp_msg_code[7:0] == `OBFF ) begin
                tlp_hdr_dw_fm[3][31:24] = { 4'b0000, tlp_hdr_pkt.tlp_obff_code };                               // B15
            end else if ( tlp_hdr_pkt.tlp_msg_code[7:0] == `IDE_SYNC_MSG_TYPE ) begin // Sync message (Link and Selective) IDE Stream 
                tlp_hdr_dw_fm[3][15:8]  = tlp_hdr_pkt.tlp_pr_sent_counter_cpl;                                  // B13
                tlp_hdr_dw_fm[3][31:24] = tlp_hdr_pkt.tlp_pr_sent_counter_npr;                                  // B15
            //PTM messages (PTM_RES_TYPE) are generated in MSG_GEN so not considered by XAIM
            end
        end
//*****************************************************************************
// DW4-DW7 - Currently do a straight swap Hdr field in - Hdr field out so do not consider here
//*****************************************************************************
    end

        f_base_hdr_form_fm = tlp_hdr_dw_fm; // Assign Output
    end
    endfunction // f_base_hdr_form_fm

    ///////////////////////////////////////////
    // Function to Return the one-hot encoding
    // of a value.
    ///////////////////////////////////////////
    function automatic logic [31:0] f_int_to_dwen (
      input logic          [4:0] value
    );
      for (int i=0; i<32; i++) begin
        if (value > (5'(i))) f_int_to_dwen[i] = 1'b1;
        else                 f_int_to_dwen[i] = 1'b0;
      end
    endfunction // f_int_to_dwen

endpackage : xaim_ms_pkg

`endif //__GUARD__XAIM_MS_PKG__SVH__
