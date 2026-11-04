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
// ---    $DateTime: 2022/04/20 07:46:40 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_atop_pkg.svh#8 $
// -------------------------------------------------------------------------
// --- Description: AXI Atomic Operations Package
// -------------------------------------------------------------------------
`ifndef __GUARD__DWC_PCIE_BRIDGE_ATOP_PKG__SVH__
`define __GUARD__DWC_PCIE_BRIDGE_ATOP_PKG__SVH__

`include "include/DWC_pcie_ctl_all_defs.svh"

package DWC_pcie_bridge_atop_pkg;

  typedef enum logic [6:0] {
    FETCHADD32      = `FETCHADD32
   ,FETCHADD64      = `FETCHADD64
   ,SWAP32          = `SWAP32
   ,SWAP64          = `SWAP64
   ,CAS32           = `CAS32
   ,CAS64           = `CAS64
   ,MWR32           = `MWR32
   ,MWR64           = `MWR64
   ,IOWR            = `IOWR
   ,CFGWR0          = `CFGWR0
   ,CFGWR1          = `CFGWR1
   ,MSG_ROUTED_RC   = {`MSG_4,3'b000}
   ,MSG_ROUTED_AD   = {`MSG_4,3'b001}
   ,MSG_ROUTED_ID   = {`MSG_4,3'b010}
   ,MSG_BROAD_RC    = {`MSG_4,3'b011}
   ,MSG_LOCAL       = {`MSG_4,3'b100}
   ,MSG_GROUTED_RC  = {`MSG_4,3'b101}
   ,MSG_RES0        = {`MSG_4,3'b110}
   ,MSG_RES1        = {`MSG_4,3'b111}
   ,MSGD_ROUTED_RC  = {`MSGD_4,3'b000}
   ,MSGD_ROUTED_AD  = {`MSGD_4,3'b001}
   ,MSGD_ROUTED_ID  = {`MSGD_4,3'b010}
   ,MSGD_BROAD_RC   = {`MSGD_4,3'b011}
   ,MSGD_LOCAL      = {`MSGD_4,3'b100}
   ,MSGD_GROUTED_RC = {`MSGD_4,3'b101}
   ,MSGD_RES0       = {`MSGD_4,3'b110}
   ,MSGD_RES1       = {`MSGD_4,3'b111}
  } pkg_atop_fmt_type_e;

  typedef enum logic [5:0] {
    LOAD_LE = `AXI_ATOP_LOAD_LE
   ,LOAD_BE = `AXI_ATOP_LOAD_BE
   ,SWAP    = `AXI_ATOP_SWAP
   ,CAS     = `AXI_ATOP_CAS
   ,NONE    = `AXI_ATOP_NONE
  } pkg_atop_awatop_e;

  typedef struct {
    logic                               w_wq_write        ;
    logic                               w_wq_ready        ;
    logic [`CC_MAX_MSTR_TAG_PW-1:0]     w_wq_id           ;
    logic [`CC_MSTR_MTU_PW-1:0]         w_wq_len          ;
    logic                               w_wq_last         ;
    logic [`CC_MSTR_BUS_ADDR_WIDTH-1:0] w_wq_addr         ;
    pkg_atop_fmt_type_e                 w_wq_fmt_type     ;
    logic [2:0]                         w_wq_mmisc_info_tc;
    logic                               w_wq_mmisc_info_ro;
    logic                               w_wq_mmisc_info_ns;
  } pkg_atop_writeq_to_gmread_s;

  localparam ADDR_WD_LOG2 = $clog2(`CC_MSTR_BUS_ADDR_WIDTH);

  function automatic [2:0] log2 ([`CC_MSTR_MTU_PW-1:0] length);
    integer i;
    begin
      length = length - 1;
      log2=0;
      for (i=0;i<(`CC_MSTR_MTU_PW-1);i=i+1)
        if (length[i]) log2 = i+1;
    end
  endfunction

  function automatic logic addr_naligned ([`CC_MSTR_BUS_ADDR_WIDTH-1:0] address, [2:0] size, [`CC_MSTR_BURST_LEN_PW-1:0] length);
    begin
      case(3'(length))
        0,1:
          addr_naligned = address[(ADDR_WD_LOG2)'(size + length - 1)];
        3:
          addr_naligned = address[(ADDR_WD_LOG2)'(size + length - 2)];
        7:
          addr_naligned = address[(ADDR_WD_LOG2)'(size + length - 5)];
        default:
          addr_naligned = address[(ADDR_WD_LOG2)'(size + length - 1)];
      endcase
    end
  endfunction

endpackage : DWC_pcie_bridge_atop_pkg

`endif // __GUARD__DWC_PCIE_BRIDGE_ATOP_PKG__SVH__

