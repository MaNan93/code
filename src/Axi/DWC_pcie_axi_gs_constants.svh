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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_gs_constants.svh#4 $
// -------------------------------------------------------------------------

// --------------------------------------------------------------------
//
// AUTHOR:    Tom Marshall      01/10/2006
//
// VERSION:   DWC_pcie_axi_gs_constants Local Constant Defines File
//
//
//---------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_AXI_GS_CONSTANTS__SVH__
`define __GUARD__DWC_PCIE_AXI_GS_CONSTANTS__SVH__

// Description:  Maximum number of exclusive accesses to be monitored
// DefaultValue: 0
// EnumValues:   0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16
`define GSX_AXI_EX_ACCESS 0


// Description:  GIF Lite (no response signals)
// DefaultValue: false
// EnumValues:   0 1
// ValueRange:   false true
`define GSX_GIF_LITE 0


// Description:  Posted writes on GIF
// DefaultValue: 1
// EnumValues:   1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16
`define GSX_BID_BUFFER 16


// Description:  Posted reads on GIF
// DefaultValue: 1
// EnumValues:   1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16
`define GSX_RID_BUFFER 1


// Description:  Request buffer depth
//
//                for maximum throughput:
//                  if (GSX_DIRECT_GIF_READY)
//                    GSX_REQ_BUFFER >= 1: zero idle cycles between transactions
//                  else
//                    GSX_REQ_BUFFER == 1: one idle cycle between transactions
//                    GSX_REQ_BUFFER >= 2: zero idle cycles between transactions
// DefaultValue: 1
// EnumValues:   1 2 3 4
`define GSX_REQ_BUFFER 1


// Description:  Write data buffer depth
//
//                for maximum throughput:
//                  if (GSX_DIRECT_GIF_READY)
//                    GSX_WDATA_BUFFER >= 1: zero idle cycles between write beats
//                  else
//                    GSX_WDATA_BUFFER == 1: one idle cycle between write beats
//                    GSX_WDATA_BUFFER >= 2: zero idle cycles between write beats
// DefaultValue: 1
// EnumValues:   1 2 3 4
`define GSX_WDATA_BUFFER 1


// Description:  Response buffer depth
//
//                for maximum throughput:
//                  if (GSX_GIF_LITE)
//                    if (GSX_DIRECT_AXI_READY)
//                      GSX_RESP_BUFFER == 1: 1/2 throughput
//                      GSX_RESP_BUFFER >= 2: full throughput
//                    else
//                      GSX_RESP_BUFFER == 1: 1/3 throughput
//                      GSX_RESP_BUFFER == 2: 1/2 throughput
//                      GSX_RESP_BUFFER >= 3: full throughput
//                  else
//                    if (GSX_DIRECT_AXI_READY)
//                      GSX_RESP_BUFFER == 1:     throughput
//                    else
//                      GSX_RESP_BUFFER == 1:     throughput
// DefaultValue: 1
// EnumValues:   1 2 3 4
`define GSX_RESP_BUFFER 1


// See databook for side effect of DIRECT_AXI_READY
// and GIF_LITE both enabled with a slow GCLK.


// Description:  Direct feedthrough of AXI ready signals to GIF.
// DefaultValue: true
// EnumValues:   0 1
// ValueRange:   false true
`define GSX_DIRECT_AXI_READY 1


// Description:  Direct feedthrough of saccept to AXI.
// DefaultValue: true
// EnumValues:   0 1
// ValueRange:   false true
`define GSX_DIRECT_GIF_READY 1



// -------------------------------------
// simulation parameters available in cC
// -------------------------------------


// Description:  This is a testbench parameter. The design does not depend on this
//               parameter. This parameter specifies the clock period of the primary
//               AXI system (also called AXI system "A") used in the testbench to drive
//               the Bridge slave interface.
// DefaultValue: 10
// MinValue:     -2147483648
// MaxValue:     2147483647
//`define SIM_ACLK_PERIOD 10


// Description:  This is a testbench parameter. The design does not depend from this
//               parameter. This parameter specifies the clock period of the secondary
//               AHB system (also called AHB system "B") used in the testbench to drive
//               the Bridge master interface.
// DefaultValue: 10
// MinValue:     -2147483648
// MaxValue:     2147483647
//`define SIM_GCLK_PERIOD 10


// --------------------------------------------------------
// simulation parameters available in cC but not in the GUI
// (used for regressions)
// do not change !
// --------------------------------------------------------

// the number of random sequences for each master to be generated in random test.
// This is a parameter for regressions. Set to 10 for short simulations. 50 is for
// medium simulations (2-3 min). 500 for long simulations (~30 min). 5000 for extra long.

`define SIM_NUM_SEQUENCES 10

// this enables tests to produce additional dump files with information about the
// random transfers generated, the addresses values observed on the bus etc.

`define SIM_DEBUG_LEVEL 0

// this enables tests to use a variable seed (related with the OS time) to
// initialize random generators.

`define SIM_USE_VARIABLE_SEED 0


// AXI Slave Constants
`define GSX_SRESP_OK_R     2'b00
`define GSX_SRESP_OK_W     2'b01
`define GSX_SRESP_SLVERR_R 2'b10
`define GSX_SRESP_SLVERR_W 2'b11

`define GSX_BURST_FIXED  2'b00
`define GSX_BURST_INCR   2'b01
`define GSX_BURST_WRAP   2'b10
`define GSX_BURST_UINCR  2'b11

`define GSX_AXI_FIXED 2'b00
`define GSX_AXI_INCR  2'b01
`define GSX_AXI_WRAP  2'b10
`define GSX_AXI_RESVD 2'b11

`define GSX_AXI_OKAY   2'b00
`define GSX_AXI_EXOKAY 2'b01
`define GSX_AXI_SLVERR 2'b10
`define GSX_AXI_DECERR 2'b11

`endif // __GUARD__DWC_PCIE_AXI_GS_CONSTANTS__SVH__
