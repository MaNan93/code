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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_gm_constants.svh#4 $
// -------------------------------------------------------------------------

// --------------------------------------------------------------------
//
// AUTHOR:    Tom Marshall      01/10/2006
//
// VERSION:   DWC_pcie_axi_gm_constants Local Constant Defines File
//
//
//---------------------------------------------------------------------

`ifndef __GUARD__DWC_PCIE_AXI_GM_CONSTANTS__SVH__
`define __GUARD__DWC_PCIE_AXI_GM_CONSTANTS__SVH__

// Description:  Specify ID width on AXI.
// DefaultValue: 4
// EnumValues:   1 2 3 4 5 6 7 8 9 10 11 12 13
`define GMX_AXI_ID_WIDTH  `CC_MAX_MSTR_TAG_PW


// Description:  Specify protection encoding bit 0. Default 0 - Unpriviledge access
// DefaultValue: 0
// MinValue:     0
// MaxValue:     1
`define GMX_AXI_AWPROT_0 0


// Description:  Specify protection encoding bit 1. Default 1 - Non-secure access
// DefaultValue: 0
// MinValue:     0
// MaxValue:     1
`define GMX_AXI_AWPROT_1 1


// Description:  Specify protection encoding bit 2. Default 0 - Data access
// DefaultValue: 0
// MinValue:     0
// MaxValue:     1
`define GMX_AXI_AWPROT_2 0


// Description:  Specify protection encoding bit 0. Default 0 - Unpriviledge access
// DefaultValue: 0
// MinValue:     0
// MaxValue:     1
`define GMX_AXI_ARPROT_0 0


// Description:  Specify protection encoding bit 1. Default 1 - Non-secure acces
// DefaultValue: 0
// MinValue:     0
// MaxValue:     1
`define GMX_AXI_ARPROT_1 1


// Description:  Specify protection encoding bit 2. Default 0 - Data access
// DefaultValue: 0
// MinValue:     0
// MaxValue:     1
`define GMX_AXI_ARPROT_2 0

// Locked to AXI
//`define CC_MSTR_GIF_DATA_WIDTH `CC_MSTR_BUS_DATA_WIDTH
`define CC_MSTR_GIF_DATA_WIDTH `CC_CORE_DATA_BUS_WD

`define CC_MSTR_GIF_WSTRB_WIDTH (`PCIE_CORE_DATA_BUS_WD / 8 )


// Description:  GMX_DIRECT_AXI_READY
//                Direct feedthrough of AXI ready signals to GIF.
// DefaultValue: true
// EnumValues:   0 1
// ValueRange:   false true
`define GMX_DIRECT_AXI_READY 1


// Description:  Depth of the request buffer.
// DefaultValue: 1
// EnumValues:   1 2 3 4
`define GMX_REQ_BUFFER 1

`define GMX_REQ_BUFFER_ADDR_WIDTH (`GMX_REQ_BUFFER/3)+1


// Description:  Depth of the write data buffer.
// DefaultValue: 1
// EnumValues:   1 2 3 4
`define GMX_WDATA_BUFFER 1

`define GMX_WDATA_BUFFER_ADDR_WIDTH (`GMX_WDATA_BUFFER/3)+1


// Description:  GMX_DIRECT_GIF_READY
//                Direct feedthrough of GIF mready signal to AXI.
// DefaultValue: true
// EnumValues:   0 1
// ValueRange:   false true
`define GMX_DIRECT_GIF_READY 1


// Description:  Depth of the response buffer.
// DefaultValue: 1
// EnumValues:   1 2 3 4
`define GMX_RESP_BUFFER 1

`define GMX_RESP_BUFFER_ADDR_WIDTH (`GMX_RESP_BUFFER/3)+1


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
`define SIM_ACLK_PERIOD 10


// Description:  This is a testbench parameter. The design does not depend from this
//               parameter. This parameter specifies the clock period of the secondary
//               AHB system (also called AHB system "B") used in the testbench to drive
//               the Bridge master interface.
// DefaultValue: 30
// MinValue:     -2147483648
// MaxValue:     2147483647
`define SIM_GCLK_PERIOD 30


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

`endif // __GUARD__DWC_PCIE_AXI_GM_CONSTANTS__SVH__
