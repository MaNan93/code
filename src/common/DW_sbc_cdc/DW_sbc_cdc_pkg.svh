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
// ---    $DateTime: 2021/10/29 02:04:56 $ 
// ---    $Revision: #3 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh#3 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__DW_SBC_CDC_PKG__SVH__
`define __GUARD__DW_SBC_CDC_PKG__SVH__

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

package DW_sbc_cdc_pkg;

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

  // ##########################################################################
  //                                Enumerations                               
  // ##########################################################################
  typedef enum logic {
     E_FALSE = 1'b0
    ,E_TRUE  = 1'b1
  } bool_e;

  typedef enum logic [1:0] {
     E_POP_IDLE = 2'b00
    ,E_POP      = 2'b01
    ,E_PEEK     = 2'b10
  } popCommand_e;

  typedef enum logic [2:0] {
     E_PUSH_IDLE = 3'b000
    ,E_START     = 3'b001
    ,E_DROP      = 3'b010
    ,E_KEEP      = 3'b011
    ,E_PUSH      = 3'b100
    ,E_DROPSTART = 3'b101
    ,E_DROPSTARTKEEP = 3'b110
  } pushCommand_e;

  typedef enum logic [2:0] {
     E_DEFAULT_ARCH = 3'b000
    ,E_PSH_FASTER   = 3'b001
    ,E_POP_FASTER   = 3'b010
    ,E_CDC_DISABLED = 3'b011
    ,E_LEAVE_UNCONNECTED = 3'b100
  } syncArch_e;

  typedef enum logic [2:0] {
     E_SYNC_HSK  = 3'b000
    ,E_SYNC_GRAY = 3'b001
    ,E_SYNC_FIFO = 3'b010
    ,E_SYNC_OFF  = 3'b011
    ,E_SYNC_TIE_LOW = 3'b100
  } syncType_e;

// SNPS_SysML_CODE_START
  function automatic logic popActiveMovePtr(input popCommand_e popc);
    popActiveMovePtr = (popc == E_POP);
  endfunction

  function automatic logic popActive(input popCommand_e popc);
    popActive = (popc == E_POP) || (popc == E_PEEK);
  endfunction

  function automatic logic pushActive(input pushCommand_e pshc);
    pushActive = (pshc == E_KEEP)          ||
                 (pshc == E_PUSH)          ||
                 (pshc == E_DROPSTART)     ||
                 (pshc == E_START)         ||
                 (pshc == E_DROPSTARTKEEP)   ;
  endfunction

  function automatic logic popInbounds(input popCommand_e popc);
    popInbounds = (popc == E_POP_IDLE) ||
                  (popc == E_POP     ) ||
                  (popc == E_PEEK    )   ;
  endfunction

  function automatic logic pushInbounds(input pushCommand_e pshc);
    pushInbounds = (pshc == E_PUSH_IDLE    ) ||
                   (pshc == E_START        ) ||
                   (pshc == E_DROP         ) ||
                   (pshc == E_KEEP         ) ||
                   (pshc == E_PUSH         ) ||
                   (pshc == E_DROPSTART    ) ||
                   (pshc == E_DROPSTARTKEEP)   ;
  endfunction

  function automatic logic pushActiveForward(input pushCommand_e pshc);
    pushActiveForward = (pshc == E_KEEP ) ||
                        (pshc == E_PUSH )   ;
  endfunction

  function automatic logic pushUpdateCounter(input pushCommand_e pshc);
    pushUpdateCounter = (pshc == E_KEEP         ) ||
                        (pshc == E_DROPSTARTKEEP)   ;
  endfunction

  /* if 1, will write over unkept */
  function automatic logic pushTrashUnkept(input pushCommand_e pshc);
    pushTrashUnkept = (pshc == E_START)         ||
                      (pshc == E_DROPSTART)     ||
                      (pshc == E_DROPSTARTKEEP)   ;
  endfunction

  // Push commands that may only be used on a clean segment
  function automatic logic pushImpliedCleanSeg(input pushCommand_e pshc);
    pushImpliedCleanSeg = 1'b0; /* blame rdbuff compat. -- (pshc == E_START); -- */
  endfunction

  // Push commands that may only be used on a dirty segment
  function automatic logic pushImpliedDirtySeg(input pushCommand_e pshc);
    pushImpliedDirtySeg = (pshc == E_PUSH     )   ;
  endfunction

  // Detect dirty to clean segment transition
  function automatic logic pushWillCleanSeg(input pushCommand_e pshc);
    pushWillCleanSeg = (pshc == E_KEEP)          ||
                       (pshc == E_DROP)          ||
                       (pshc == E_DROPSTARTKEEP)   ;
  endfunction

  // Detect clean to dirty segment transition
  function automatic logic pushWillSoilSeg(input pushCommand_e pshc);
    pushWillSoilSeg = (pshc == E_START    ) ||
                      (pshc == E_DROPSTART)   ;
  endfunction
// SNPS_SysML_CODE_END

endpackage : DW_sbc_cdc_pkg

// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

`endif // __GUARD__DW_SBC_CDC_PKG__SVH__

