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
// ---    $DateTime: 2024/01/03 02:06:32 $
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_pkg.svh#13 $
// --------------------------------------------------------------------------------------------
// --- Description: SerDes archtecture module package
// --------------------------------------------------------------------------------------------

`ifndef __GUARD__SERDES_PIPE_PKG__SVH__
`define __GUARD__SERDES_PIPE_PKG__SVH__

package serdes_pipe_pkg;

// --------------------------------------------------------------------------------
//  cC parameter
// --------------------------------------------------------------------------------
  localparam int  PHY_NB       = `CX_PHY_NB;
  localparam int  RATE_WD      = `CX_PHY_RATE_WD;
  localparam int  WIDTH_WD     = `CX_PHY_WIDTH_WD;
  localparam int  PHY_TXEI_WD  = `CX_PHY_TXEI_WD;
//  localparam int  PHY_128B130B_NB = `CX_PHY_128B130B_NB;
  localparam int  PHY_128B130B_NB = (`CX_MAX_PCIE_SPEED==3) ? `CX_PHY_NB_GEN3 : (`CX_MAX_PCIE_SPEED==4) ? `CX_PHY_NB_GEN4 : `CX_PHY_NB_GEN5;
  localparam int  PHY_RXSB_WD     = `CX_PHY_RXSB_WD;
  localparam int  PHY_RXSH_WD     = `CX_PHY_RXSH_WD;
  localparam int  PHY_TXSB_WD     = `CX_PHY_TXSB_WD;
  localparam int  PHY_TXSH_WD     = `CX_PHY_TXSH_WD;
  localparam int  BAC_WD          = `CX_BAC_WD;
  localparam int  PHY_8B10B_NB = `CX_PHY_8B10B_NB;
  localparam int  SYNC_TYPE    = `CX_PCIE_SYNC_DEPTH;

// --------------------------------------------------------------------------------
//  8b/10b encoding parameter
// --------------------------------------------------------------------------------
  localparam int  SYM_8B_WD        = 8;
  localparam int  SYM_10B_WD       = 10;
  localparam int  PHY_8B10B_SYM_WD = $clog2(PHY_8B10B_NB + 1);
  localparam int  PHY_10B_RAW_WD   = $clog2(SYM_10B_WD * PHY_8B10B_NB + 1);

  localparam bit [SYM_8B_WD-1:0]   SYM_8B_EDB  = 'hfe;  // K30.7
  localparam bit [SYM_10B_WD-1:0]  SYM_SKP_10B = 'h0f4; // K28.0
  localparam bit [SYM_10B_WD-1:0]  SYM_10B_SKP = 'h0f4; // K28.0
  localparam bit [SYM_10B_WD-1:0]  SYM_10B_IDL = 'h0f3; // K28.3
  localparam bit [SYM_10B_WD-1:0]  SYM_10B_COM = 'h0fa; // K28.5

  typedef logic [PHY_8B10B_NB-1:0][SYM_8B_WD-1:0]   pipe_data8b_t;
  typedef logic [PHY_8B10B_NB-1:0][SYM_10B_WD-1:0]  pipe_data10b_t;

// --------------------------------------------------------------------------------
//  128b/130b encoding parameter / type
// --------------------------------------------------------------------------------
  localparam int  SYM_WD        = 8;
  localparam int  PHY_SYM_WD    = $clog2(PHY_NB + 1);
  localparam int  PHY_RAW_WD    = $clog2(SYM_WD * PHY_NB + 1);
  localparam int  SYNC_HDR_WD   = 2;
  localparam int  BLOCK_SYM_NUM = 16;
  localparam int  BLOCK_WD      = (SYM_WD * BLOCK_SYM_NUM) + SYNC_HDR_WD;
  localparam int  BLOCK_INT     = 4;
  localparam int  BLOCK_INT_GEN6= 8;

  localparam bit [SYNC_HDR_WD-1:0]  SYNC_HDR_OS   = 'b01;
  localparam bit [SYNC_HDR_WD-1:0]  SYNC_HDR_DATA = 'b10;

  localparam bit [SYM_WD-1:0]  SYM_GEN3_SKP      = 'haa;
  localparam bit [SYM_WD-1:0]  SYM_GEN5_SKP      = 'h99;
  localparam bit [SYM_WD-1:0]  SYM_SKP_END       = 'he1;
  localparam bit [SYM_WD-1:0]  SYM_SKP_END_CTL   = 'h78;
  localparam bit [SYM_WD-1:0]  SYM_EI            = 'h66;
  localparam bit [SYM_WD-1:0]  SYM_EIE           = 'h00;

  localparam bit [SYM_WD-1:0]  SYM_SDS_ID        = 'he1;
  localparam bit [SYM_WD-1:0]  SYM_GEN3_SDS_BODY = 'h55;
  localparam bit [SYM_WD-1:0]  SYM_GEN5_SDS_BODY = 'h87;

  localparam bit [BLOCK_WD-1:0]  EIOS_FMT       = {{BLOCK_SYM_NUM{SYM_EI}}, SYNC_HDR_OS};
  localparam bit [BLOCK_WD-1:0]  GEN3_EIEOS_FMT = {{8{~SYM_EIE, SYM_EIE}}, SYNC_HDR_OS};
  localparam bit [BLOCK_WD-1:0]  GEN4_EIEOS_FMT = {{4{{2{~SYM_EIE}}, {2{SYM_EIE}}}}, SYNC_HDR_OS};
  localparam bit [BLOCK_WD-1:0]  GEN5_EIEOS_FMT = {{2{{4{~SYM_EIE}}, {4{SYM_EIE}}}}, SYNC_HDR_OS};
  localparam bit [BLOCK_WD-1:0]  GEN6_EIEOS_FMT = 130'hFFFFFFFFFFFFFFFF_0000000000000000;

  localparam bit [BLOCK_SYM_NUM*SYM_WD-1:0]  GEN6_EIOS_FMT   = 128'hF00FF00FF00FF00F_F00FF00FF00FF00F;
  localparam bit [BLOCK_SYM_NUM*SYM_WD-1:0]  GEN6_SDSOS_FMT  = 128'hC6C6C6B1C6C6C6B1_C6C6C6B1C6C6C6B1;
  localparam bit [BLOCK_INT_GEN6*SYM_WD-1:0] GEN6_SKPOS_FMT  =  64'h0FF00FF00FF00FF0;
  localparam bit [BLOCK_INT_GEN6*SYM_WD-1:0] GEN6_SKPEND_FMT =  64'hF000F0FFF000F0FF;

  typedef logic [PHY_NB-1:0][SYM_WD-1:0]            pipe_data128b_t;
  typedef logic [PHY_RXSB_WD-1:0][SYNC_HDR_WD-1:0]  pipe_syncheader_t;


// --------------------------------------------------------------------------------
//  Common parameter / type / function
// --------------------------------------------------------------------------------
  localparam int  ORIG_DATA_WD   = SYM_WD * PHY_NB;
  localparam int  SERDES_DATA_WD = SYM_10B_WD * PHY_NB;
// Ordered Set insertion interval once Data Stream starts in terms of number of Blocks
  localparam int OS_INTVL_BLOCKS_X1__1b1b_CCLK               =  736; // Common CLK , 1b1b     , x1   (  46 Flits = 736 Blocks )
  localparam int OS_INTVL_BLOCKS_X2__1b1b_CCLK               =  744; // Common CLK , 1b1b     , x2   (  93 Flits = 744 Blocks )
  localparam int OS_INTVL_BLOCKS_X4__1b1b_CCLK               =  748; // Common CLK , 1b1b     , x4   ( 187 Flits = 748 Blocks )
  localparam int OS_INTVL_BLOCKS_X8__1b1b_CCLK               =  748; // Common CLK , 1b1b     , x8   ( 374 Flits = 748 Blocks )
  localparam int OS_INTVL_BLOCKS_X16_1b1b_CCLK               =  748; // Common CLK , 1b1b     , x16  ( 748 Flits = 748 Blocks )

  localparam int OS_INTVL_BLOCKS_X1__128b130b_CCLK           =  368; // Common CLK , 128b130b , x1   (  23 Flits = 368 Blocks )
  localparam int OS_INTVL_BLOCKS_X2__128b130b_CCLK           =  368; // Common CLK , 128b130b , x2   (  46 Flits = 368 Blocks )
  localparam int OS_INTVL_BLOCKS_X4__128b130b_CCLK           =  372; // Common CLK , 128b130b , x4   (  93 Flits = 372 Blocks )
  localparam int OS_INTVL_BLOCKS_X8__128b130b_CCLK           =  374; // Common CLK , 128b130b , x8   ( 187 Flits = 374 Blocks )
  localparam int OS_INTVL_BLOCKS_X16_128b130b_CCLK           =  374; // Common CLK , 128b130b , x16  ( 374 Flits = 374 Blocks )

  localparam int OS_INTVL_BLOCKS_X1__1b1b_SRIS               =  64;  // SRIS       , 1b1b     , x1   (   4 Flits = 64 Blocks )
  localparam int OS_INTVL_BLOCKS_X2__1b1b_SRIS               =  72;  // SRIS       , 1b1b     , x2   (   9 Flits = 72 Blocks )
  localparam int OS_INTVL_BLOCKS_X4__1b1b_SRIS               =  72;  // SRIS       , 1b1b     , x4   (  18 Flits = 72 Blocks )
  localparam int OS_INTVL_BLOCKS_X8__1b1b_SRIS               =  74;  // SRIS       , 1b1b     , x8   (  37 Flits = 74 Blocks )
  localparam int OS_INTVL_BLOCKS_X16_1b1b_SRIS               =  74;  // SRIS       , 1b1b     , x16  (  74 Flits = 74 Blocks )

  localparam int OS_INTVL_BLOCKS_X1__128b130b_SRIS           =  32;  // SRIS       , 128b130b , x1   (   2 Flits = 32 Blocks )
  localparam int OS_INTVL_BLOCKS_X2__128b130b_SRIS           =  32;  // SRIS       , 128b130b , x2   (   4 Flits = 32 Blocks )
  localparam int OS_INTVL_BLOCKS_X4__128b130b_SRIS           =  36;  // SRIS       , 128b130b , x4   (   9 Flits = 36 Blocks )
  localparam int OS_INTVL_BLOCKS_X8__128b130b_SRIS           =  36;  // SRIS       , 128b130b , x8   (  18 Flits = 36 Blocks )
  localparam int OS_INTVL_BLOCKS_X16_128b130b_SRIS           =  37;  // SRIS       , 128b130b , x16  (  37 Flits = 37 Blocks )

  typedef logic [PHY_NB-1:0][SYM_10B_WD-1:0]  pipe_data_t;


  localparam int OS_FIND_GEN6_NB = (PHY_NB > BLOCK_INT_GEN6) ? PHY_NB : BLOCK_INT_GEN6;
  localparam int OS_FIND_GEN6_WD = OS_FIND_GEN6_NB/BLOCK_INT_GEN6;

  typedef logic [PHY_RXSB_WD-1:0][4:0] os_found_t;

  localparam int OS_FOUND_EIOS  = 2;
  localparam int OS_FOUND_EIEOS = 3;
  localparam int OS_FOUND_SDS   = 4;

  typedef enum logic [2:0] {
    NONE    = 3'b000, 
    SKP     = 3'b001,
    SKP_END = 3'b010,
    EIOS    = 3'b011,
    EIEOS   = 3'b100, 
    SDS     = 3'b101
  }  os_t;

  function automatic logic [PHY_SYM_WD-1:0]  get_symbol_width (
    logic [WIDTH_WD-1:0]  pipe_width
  );
    logic [PHY_SYM_WD-1:0]  ret;
    ret = $bits(ret)'(1'h1 << pipe_width);
    return ret;
  endfunction

  function automatic logic [$clog2(SERDES_DATA_WD+1)-1:0]  get_raw_width (
    logic [WIDTH_WD-1:0]  pipe_width,
    logic                 encdec_8b10b
  );
    logic [$clog2(SERDES_DATA_WD+1)-1:0]  ret;
    ret = $bits(ret)'((encdec_8b10b) ? (SYM_10B_WD << pipe_width) : (SYM_WD << pipe_width));
    return ret;
  endfunction


endpackage // serdes_pipe_pkg

`endif // __GUARD__SERDES_PIPE_PKG__SVH__
