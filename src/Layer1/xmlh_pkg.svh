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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_pkg.svh#3 $
// --------------------------------------------------------------------------------------------
// --- Description: XMLH module package
// --------------------------------------------------------------------------------------------

`ifndef __GUARD__XMLH_PKG__SVH__
`define __GUARD__XMLH_PKG__SVH__

package xmlh_pkg;

// --------------------------------------------------------------------------------
//  cC parameter
// --------------------------------------------------------------------------------
 localparam INST          = 0;                                                           // The uniquifying localparam for each port logic instance.
 localparam NL            = `CX_NL;                                                      // Max number of lanes supported
 localparam NB            = `CX_NB;                                                      // Number of symbols (bytes) per clock cycle
 localparam NBK           = `CX_NBK;                                                     // Number of symbols (bytes) per clock cycle for datak
 localparam NW            = `CX_PL_NW;                                                   // Number of 32-bit dwords handled by the datapath each clock.
 localparam DW            = `CX_PL_DW;                                                   // Width of datapath in bits.
 localparam NBIT          = `CX_NB * 8;                                                  // Number of bits per lane
 localparam NBITK         = `CX_NB;                                                      // Number of bits per lane (Data K)
 localparam NBIT2         = (NBIT> 128) ? 128 : NBIT;                                    // Number of bits per lane for 32s logic
 localparam NBYTE         = `CX_PL_NW * 4;                                               // The number of bytes in CX_DW
 localparam NBLOCK        = (NBIT> 128) ? NBIT/128 : 1;                                  // Number of Data Blocks per lane
 localparam NQW           = (NBIT> 64)  ? NBIT/64  : 1 ;     // Number of QWORD per lane for Gen6
 localparam LOG2NBYTE     = `CX_LOGBASE2(NBYTE);                                         // log2 number of bytes in CX_DW
 localparam LOG2NW        = `CX_LOGBASE2(NW);                                            // log2 number of bytes in CX_PL_NW
 localparam TP            = `TP;                                                         // Clock to Q delay (simulator insurance)
 localparam TIMER_BITS    = 11;
 localparam TX_PSET_WD    = 4;                                                           // preset bit width
 localparam EIEOS_MASK_LOGIC_ENABLE = 0;                                                 // set to 1 if you want to go back to per lane mechanism
 localparam TS1_NUM = `GEN3_TS1_NUM_FOR_RESET_EIEOS;                                     // <65535 for test only. real is default 65535
 localparam AW            = `CX_ANB_WD;                                                  // Width of the active number of bytes
 localparam TS_0_WD       = 48;                                                          // ts0 info sym6-1

 localparam EQTS_WD      = 32;                                                           // Number of bits of Per Lane Equalization Information
 localparam SLICE_WD     = (NW>8) ? LOG2NBYTE : 5;                                       // scale for 512b and higher widths, hardcoded for lower widths for backward compatibility
 localparam NB_G1        = `CX_NB_GEN1;                                                  // Gen1 Sness
 localparam NB_G3        = `CX_NB_GEN3;                                                  // Gen3 Sness
 localparam SLICEK_WD    = LOG2NBYTE;                                                    // for k-char to fix lint
 localparam S_WD         = `CX_LOGBASE2(16/NB_G1);                                       // ts_sym_cnt bit width to fix lint

 localparam PAT_NB       = (NB==32) ? 16 : NB ;
 localparam PAT_NBK      = (NB==32) ? 16 : NBK;
 localparam PAT_NBIT     = PAT_NB * 8;
 // NW=16
 localparam MAX_NL_NB4   = 16;                       // Max Number of lanes @active_nb=4
 localparam MAX_NL_NB8   = 8;                        // Max Number of lanes @active_nb=8
 localparam MAX_NL_NB16  = 4;                        // Max Number of lanes @active_nb=16
 localparam CMD_NORM_WD  =                           // Number of bits of ltssm_cmd_is_norm signal
                             1 +                  // Added for 1 cycle delay into xdlh_xmlh_pkt_pending
                             3 
                             + 5                   // Add in new arch for robustness
                           ;                       // Number of bits of ltssm_cmd_is_norm signal
 localparam TXSB_WD      = `CX_MAC_SB_WD;          // Number of bits of per txstartblock
 localparam TXSH_WD      = `CX_MAC_SH_WD;          // Number of bits of per txsyncheader
 localparam OS_WD                 = `CX_MAC_SB_WD; // Number of OS width
 localparam NUM_OS_GEN            = 2 ;
 localparam G6_BLOCK_SIZE         = 'd16 ;
 localparam BYTE_XMT_LATENCY      = 1 ;                                                // Data latency in xmlh_byte_xmt (cycle)
 localparam OSFLG_WD              = 5 ;
// for DataThrottling
 localparam DT_RATE_GEN1          = `CX_MAC_GEN1_DT_RATE;
 localparam DT_RATE_GEN2          = `CX_MAC_GEN2_DT_RATE;
 localparam DT_RATE_GEN3          = `CX_MAC_GEN3_DT_RATE;
 localparam DT_RATE_GEN4          = `CX_MAC_GEN4_DT_RATE;
 localparam DT_RATE_GEN5          = `CX_MAC_GEN5_DT_RATE;
 localparam DT_RATE_GEN6          = `CX_MAC_GEN6_DT_RATE;
 
 localparam int DT_RATE_GENX [6:1]    = {DT_RATE_GEN6, DT_RATE_GEN5, DT_RATE_GEN4, DT_RATE_GEN3, DT_RATE_GEN2, DT_RATE_GEN1};
 localparam int MAX_DT_RATE           = get_max_dt_rate( DT_RATE_GENX ) ;
 localparam DT_CNT_WD             = (MAX_DT_RATE == 1) ? 1 : $clog2(MAX_DT_RATE) ;

  function automatic integer get_max_dt_rate (
    int  dt_rate [6:1]
  );
    int  ret;
    ret = dt_rate[1];
    for(int i = 2; i < 7; i++) begin
      if(ret < dt_rate[i]) begin
        ret = dt_rate[i];
      end
    end
    return ret;
  endfunction

 


 localparam CNT_16 = 16 
                     ;
 localparam CNT_1024 = 1024 
                   ;

 
 localparam SKP_INTVL_1b1b_DBLOCK_CCLK             = 740 ;
 localparam SKP_INTVL_1b1b_DBLOCK_SRIS             =  72 ;
 localparam SKP_INTVL_8b10b_FLIT_SRIS              = 136/`CX_PL_FREQ_MULTIPLIER ;


 localparam FLIT_INTVL_X1__1b1b_CCLK               =  46 ;
 localparam FLIT_INTVL_X2__1b1b_CCLK               =  93 ;
 localparam FLIT_INTVL_X4__1b1b_CCLK               = 187 ;
 localparam FLIT_INTVL_X8__1b1b_CCLK               = 374 ;
 localparam FLIT_INTVL_X16_1b1b_CCLK               = 748 ;
 localparam FLIT_INTVL_X1__128b130b_CCLK           =  23 ;
 localparam FLIT_INTVL_X2__128b130b_CCLK           =  46 ;
 localparam FLIT_INTVL_X4__128b130b_CCLK           =  93 ;
 localparam FLIT_INTVL_X8__128b130b_CCLK           = 187 ;
 localparam FLIT_INTVL_X16_128b130b_CCLK           = 374 ;
 localparam FLIT_INTVL_X1__1b1b_SRIS               =   4 ;
 localparam FLIT_INTVL_X2__1b1b_SRIS               =   9 ;
 localparam FLIT_INTVL_X4__1b1b_SRIS               =  18 ;
 localparam FLIT_INTVL_X8__1b1b_SRIS               =  37 ;
 localparam FLIT_INTVL_X16_1b1b_SRIS               =  74 ;
 localparam FLIT_INTVL_X1__128b130b_SRIS           =   2 ;
 localparam FLIT_INTVL_X2__128b130b_SRIS           =   4 ;
 localparam FLIT_INTVL_X4__128b130b_SRIS           =   9 ;
 localparam FLIT_INTVL_X8__128b130b_SRIS           =  18 ;
 localparam FLIT_INTVL_X16_128b130b_SRIS           =  37 ;

 localparam FLIT_INTVL_CXL_SYNC_CCLK               =  88 ;      // CXL / Common Clock / Not syncheader bypass
 localparam FLIT_INTVL_CXL_SYNB_CCLK               =  80 ;      // CXL / Common Clock /     syncheader bypass
 localparam FLIT_INTVL_CXL_SYNC_SRIS               =   8 ;      // CXL / SRIS         / Not syncheader bypass

 localparam CMPSQ_BLOCK_NUM_8b10b                  =   8 ;
 localparam CMPSQ_BLOCK_NUM_G3G4                   =  36 ;
 localparam CMPSQ_BLOCK_NUM_G5                     =  CMPSQ_BLOCK_NUM_G3G4 + 1 ;
 localparam CMPSQ_BLOCK_NUM_1b1b                   = 64 + 64 + 9 ;

 localparam MCMPSQ_BLOCK_NUM_8b10b                 =   8 ;
 localparam MCMPSQ_BLOCK_NUM_G3G4_CCLK_PHASE0      = 1 + 256 ;   //   EIE + 256*IDLE
 localparam MCMPSQ_BLOCK_NUM_G5_CCLK_PHASE0        = 2 + 256 ;   // 2*EIE + 256*IDLE
 localparam MCMPSQ_BLOCK_NUM_128b130b_CCLK_PHASE1  = 257 ;       //   SKP + 256*IDLE
 localparam MCMPSQ_BLOCK_NUM_G3G4_SRIS_PHASE0      = 1 ;         //   EIE
 localparam MCMPSQ_BLOCK_NUM_G5_SRIS_PHASE0        = 2 ;         // 2*EIE
 localparam MCMPSQ_BLOCK_NUM_128b130b_SRIS_PHASE1  = 33 ;        //   SKP + 32*IDLE

 localparam PHASE_NUM_128b130b_CCLK                = 1 + 255 ;   // 1*Phase0 + 255*Phase1
 localparam PHASE_NUM_128b130b_SRIS                = 1 + 2048 ;  // 1*Phase0 + 2048*Phase1

 localparam MCMPSQ_QW_NUM_1b1b_CCLK                = 1*2 + 256*2 + 255*256*2 + 255*5 ;   // ('d132,349): QW size of Gen6 Modified compliance(Common CLK) : EIE*1 + 128'd0*256 + 128'd0*256*255 + SKP*255
 localparam MCMPSQ_QW_NUM_1b1b_SRIS                = 1*2 + 2048*32*2 + 2048*5 ;          // ('d141,314): QW size of Gen6 Modified compliance SRIS)       : EIE*1 + 128'd0*32*2048 + SKP*248
 localparam G6_BLOCK_QW_SIZE                       = G6_BLOCK_SIZE/8 ;  // QW(8byte) size

 localparam OSFLG_IDLE                             = 5'b0_0000 ;
 localparam OSFLG_SKP                              = 5'b0_0001 ;
 localparam OSFLG_SKPEND                           = 5'b0_0011 ;
 localparam OSFLG_EI                               = 5'b0_0100 ;
 localparam OSFLG_EIE                              = 5'b0_1000 ;
 localparam OSFLG_SDS                              = 5'b1_0000 ;


// ------------------------------------------------------------------------------------
//  typedef
// ------------------------------------------------------------------------------------

// --- Arbitration Grant ---
 localparam   GRANT_WD          = 15 ;               // Grant signal bitwidth (1hot)
 localparam   G_EDS_BIT         = 0  ;
 localparam   G_EI_BIT          = 1  ;
 localparam   G_EIE_BIT         = 2  ;
 localparam   G_EIE_8SYM_BIT    = 3  ;
 localparam   G_SKP_BIT         = 4  ;
 localparam   G_SDS_BIT         = 5  ;
 localparam   G_IDLE_BIT        = 6  ;
 localparam   G_TS0_BIT         = 7  ;
 localparam   G_TS1_BIT         = 8  ;
 localparam   G_TS2_BIT         = 9  ;
 localparam   G_FTS_BIT         = 10 ;
 localparam   G_CMP_BIT         = 11 ;
 localparam   G_MCMP_BIT        = 12 ;
 localparam   G_EIDLE_BIT       = 13 ;
 localparam   G_DATA_BIT        = 14 ;

  typedef enum logic [GRANT_WD-1:0] {
        G_EDS           = GRANT_WD'( 1 << G_EDS_BIT      )  ,
        G_EI_OS         = GRANT_WD'( 1 << G_EI_BIT       )  ,
        G_EIE_OS        = GRANT_WD'( 1 << G_EIE_BIT      )  ,
        G_EIE_8SYM_OS   = GRANT_WD'( 1 << G_EIE_8SYM_BIT )  ,
        G_SKP_OS        = GRANT_WD'( 1 << G_SKP_BIT      )  ,
        G_SDS_OS        = GRANT_WD'( 1 << G_SDS_BIT      )  ,
        G_IDLE          = GRANT_WD'( 1 << G_IDLE_BIT     )  ,
        G_TS0_OS        = GRANT_WD'( 1 << G_TS0_BIT      )  ,
        G_TS1_OS        = GRANT_WD'( 1 << G_TS1_BIT      )  ,
        G_TS2_OS        = GRANT_WD'( 1 << G_TS2_BIT      )  ,
        G_FTS_OS        = GRANT_WD'( 1 << G_FTS_BIT      )  ,
        G_CMP_PTN       = GRANT_WD'( 1 << G_CMP_BIT      )  ,
        G_MCMP_PTN      = GRANT_WD'( 1 << G_MCMP_BIT     )  ,
        G_EIDLE         = GRANT_WD'( 1 << G_EIDLE_BIT    )  ,
        G_DATA          = GRANT_WD'( 1 << G_DATA_BIT     )   
  }  grant_t;

// --- Current Stream ---
 localparam   STREAM_WD            = 4 ;               // Current Stream bitwidth (1hot)
 localparam   OS_STREAM_BIT        = 0 ;
 localparam   DATA_STREAM_BIT      = 1 ;
 localparam   EIDLE_STREAM_BIT     = 2 ;
 localparam   CMP_STREAM_BIT       = 3 ;

  typedef enum logic [STREAM_WD-1:0] {
        OS_STREAM        = STREAM_WD'( 1 << OS_STREAM_BIT    ) ,
        DATA_STREAM      = STREAM_WD'( 1 << DATA_STREAM_BIT  ) ,
        EIDLE_STREAM     = STREAM_WD'( 1 << EIDLE_STREAM_BIT ) ,
        CMP_STREAM       = STREAM_WD'( 1 << CMP_STREAM_BIT   )  
  }  stream_t;

// --- L0p State ---
 localparam   L0P_STATE_WD         = 3 ;               // L0p State bitwidth (1hot)
 localparam   L0P_IDLE_BIT         = 0 ;
 localparam   L0P_UPSIZING_BIT     = 1 ;
 localparam   L0P_DWSIZING_BIT     = 2 ;

  typedef enum logic [L0P_STATE_WD-1:0] {
        L0P_IDLE        = L0P_STATE_WD'( 1 << L0P_IDLE_BIT     ) ,
        L0P_UPSIZING    = L0P_STATE_WD'( 1 << L0P_UPSIZING_BIT ) ,
        L0P_DWSIZING    = L0P_STATE_WD'( 1 << L0P_DWSIZING_BIT )  
  }  l0p_state_t;


// --- Date Rate ---
 localparam GEN1_BIT    = 0 ;
 localparam GEN2_BIT    = 1 ;
 localparam GEN3_BIT    = 2 ;
 localparam GEN4_BIT    = 3 ;
 localparam GEN5_BIT    = 4 ;
 localparam GEN6_BIT    = 5 ;
 localparam GEN7_BIT    = 6 ;
 localparam GEN8_BIT    = 7 ;
 
  typedef struct packed {
    logic [7:0]                 one_hot ;                    // 1hot current data rate [0]:Gen1/[1]:Gen2 ... [7]:Gen8
    logic [7:0]                 eq_or_higher ;               // indicates current data rate is GenX or higher [0]:Gen1 or higher/[1]:Gen2 or higher ... [7]:Gen8 or higher
    logic                       enc_8b10b ;                  // Indicates current data rate is Gen1 or Gen2.
    logic                       enc_128b130b ;               // Indicates current data rate is Gen3, Gen4 or Gen5.
    logic                       enc_1b1b ;                   // Indicates current data rate is Gen6 or higher.
  } data_rate_enc_t ;


// --- SKP OS LFSR/Parity replacement ---
  typedef enum logic [2:0] {
    SKP_REPLACE_IDLE           = 3'b000 ,
    STNDRD_SKP_PDT_128b130b    = 3'b001 ,
    STNDRD_SKP_POS_128b130b    = 3'b010 ,
    CNTL_SKP_128b130b          = 3'b011 ,
    PPT_0_SKP_1b1b             = 3'b100 ,
    PPT_1_SKP_1b1b             = 3'b101 
  }  skp_replace_t;
 
  localparam P_SKP_REPLACE_IDLE  = 3'b000 ;

endpackage // xmlh_pkg

`endif // __GUARD__XMLH_PKG__SVH__
