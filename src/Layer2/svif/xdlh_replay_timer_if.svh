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
// ---    $Revision: #2 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/svif/xdlh_replay_timer_if.svh#2 $ 
// -------------------------------------------------------------------------
`ifndef __GUARD__XDLH_REPLAY_TIMER_IF__SVH__
`define __GUARD__XDLH_REPLAY_TIMER_IF__SVH__

interface xdlh_replay_timer_if ();

  logic           replay_timer_start;
  logic           replay_timer_hold;
  logic           replay_timer_reset;
  logic           replay_req;
  logic           replay_ack;
  logic [16 : 0]  replay_timer;

  modport master_mp (
    output  replay_timer_start,
    output  replay_timer_hold,
    output  replay_timer_reset,
    output  replay_ack,
    input   replay_req,
    input   replay_timer
  );

  modport slave_mp (
    input   replay_timer_start,
    input   replay_timer_hold,
    input   replay_timer_reset,
    input   replay_ack,
    output  replay_req,
    output  replay_timer
  );


endinterface

`endif // __GUARD__XDLH_REPLAY_TIMER_IF__SVH__
