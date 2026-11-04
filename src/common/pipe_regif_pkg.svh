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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/pipe_regif_pkg.svh#11 $
// --------------------------------------------------------------------------------------------
// --- Description:
// --------------------------------------------------------------------------------------------

`ifndef __GUARD__PIPE_REGIF_PKG__SVH__
`define __GUARD__PIPE_REGIF_PKG__SVH__


package pipe_regif_pkg;
// --------------------------------------------------------------------------------
//  MessageBus Command
// --------------------------------------------------------------------------------
  typedef enum logic [2:0] {
    NOP,
    WR_UNCOM,
    WR_COM,
    RD,
    RD_CPL,
    WR_ACK
  } msgbus_cmd_e;

  localparam int  MSGBUS_CMD_NUM = 6;

  localparam bit [3:0]  MSGBUS_CMD[MSGBUS_CMD_NUM] = {
    4'b0000, // NOP
    4'b0001, // WR_UNCOM
    4'b0010, // WR_COM
    4'b0011, // RD
    4'b0100, // RD_CPL
    4'b0101  // WR_ACK
  };

// --------------------------------------------------------------------------------
//  MessageBus Register Property
// --------------------------------------------------------------------------------
  typedef enum logic [1:0] {
    LEVEL,
    CYCLE,
    RESERVED
  } reg_attr_e;

  typedef struct packed {
    logic [11:0]      addr;
    logic [7:0]       val;
    reg_attr_e [7:0]  attr;
  } reg_info_s;

// --------------------------------------------------------------------------------
//  PHY Register
// --------------------------------------------------------------------------------
  typedef enum logic [3:0] {
    RX_MARGIN_CONTROL0,
    RX_MARGIN_CONTROL1,
    ELASTIC_BUFFER_CONTROL,
    PHY_RX_CONTROL0,
    PHY_RX_CONTROL1,
    PHY_RX_CONTROL3,
    PHY_RX_CONTROL4,
    PHY_TX_CONTROL2,
    PHY_TX_CONTROL3,
    PHY_TX_CONTROL4,
    PHY_TX_CONTROL5,
    PHY_TX_CONTROL6,
    PHY_TX_CONTROL7,
    PHY_TX_CONTROL8,
    PHY_TX_CONTROL9,
    PHY_COMMON_CONTROL0
  } phy_reg_e;

  localparam int  PHY_REG_NUM = 14 + 2;

  localparam reg_info_s  PHY_REG_INFO[PHY_REG_NUM] = '{
    // RX_MARGIN_CONTROL0
    '{addr: 12'h0, val: {4'h0, 1'h0, 1'h0, 1'h0, 1'h0},
      attr: {{4{RESERVED}}, CYCLE, CYCLE, LEVEL, LEVEL}},
    // RX_MARGIN_CONTROL1
    '{addr: 12'h1, val: {1'h0, 7'h0}, attr: {LEVEL, {7{LEVEL}}}},
    // ELASTIC_BUFFER_CONTROL
    '{addr: 12'h2, val: {8'h0}, attr: {8{LEVEL}}},
    // PHY_RX_CONTROL0
    '{addr: 12'h3, val: {6'h0, 1'h0, 1'h0}, attr: {{6{RESERVED}}, LEVEL, LEVEL}},
    // PHY_RX_CONTROL1
    '{addr: 12'h4, val: {5'h0, 1'h0, 2'h0}, attr: {{5{RESERVED}}, LEVEL, {2{RESERVED}}}},
    // PHY_RX_CONTROL3
    '{addr: 12'h6, val: {5'h0, 1'h0, 1'h0, 1'h0},
      attr: {{5{RESERVED}}, LEVEL, LEVEL, LEVEL}},
    // PHY_RX_CONTROL4
    '{addr: 12'h8, val: {6'h0, 1'h0, 1'h0}, attr: {{6{RESERVED}}, CYCLE, LEVEL}},
    // PHY_TX_CONTROL2
    '{addr: 12'h402, val: {8'h1}, attr: {8{LEVEL}}},
    // PHY_TX_CONTROL3
    '{addr: 12'h403, val: {8'h0}, attr: {8{LEVEL}}},
    // PHY_TX_CONTROL4
    '{addr: 12'h404, val: {8'h0}, attr: {8{LEVEL}}},
    // PHY_TX_CONTROL5
    '{addr: 12'h405, val: {1'h0, 1'h0, 6'h0}, attr: {CYCLE, RESERVED, {6{LEVEL}}}},
    // PHY_TX_CONTROL6
    '{addr: 12'h406, val: {8'h0}, attr: {8{LEVEL}}},
    // PHY_TX_CONTROL7
    '{addr: 12'h407, val: {8'h0}, attr: {8{LEVEL}}},
    // PHY_TX_CONTROL8
    '{addr: 12'h408, val: {4'h0, 1'h0, 3'h0}, attr: {{4{RESERVED}}, LEVEL, {3{LEVEL}}}},
    // PHY_TX_CONTROL9
    '{addr: 12'h409, val: {8'h0}, attr: {8{LEVEL}}},
    // PHY_COMMON_CONTROL0
    '{addr: 12'h800, val: {7'h0, 1'h0}, attr: {{7{RESERVED}}, LEVEL}}
  };

  function automatic logic  exists_phy_reg(phy_reg_e  e);
    logic  ret;
    case(e)
      RX_MARGIN_CONTROL0,
      RX_MARGIN_CONTROL1: ret = 1'h1;
      PHY_RX_CONTROL1: ret = 1'h1;
      PHY_RX_CONTROL3: ret = 1'h1;
      PHY_TX_CONTROL2,
      PHY_TX_CONTROL3,
      PHY_TX_CONTROL4: ret = 1'h1;
      PHY_TX_CONTROL5,
      PHY_TX_CONTROL6,
      PHY_TX_CONTROL7: ret = 1'h1;
      PHY_TX_CONTROL8: ret = 1'h1;
      PHY_TX_CONTROL9: ret = 1'h1;
      default: ret = 1'h0;
    endcase
    return ret;
  endfunction

// --------------------------------------------------------------------------------
//  MAC Register
// --------------------------------------------------------------------------------
  typedef enum logic [3 + 1:0] {
    RX_MARGIN_STATUS0,
    RX_MARGIN_STATUS1,
    RX_MARGIN_STATUS2,
    ELASTIC_BUFFER_STATUS,
    ELASTIC_BUFFER_LOCATION,
    RX_LINK_EVALUATION_STATUS0,
    RX_LINK_EVALUATION_STATUS1,
    RX_LINK_EVALUATION_STATUS2,
    RX_LINK_EVALUATION_STATUS3,
    TX_STATUS0,
    TX_STATUS1,
    TX_STATUS2,
    TX_STATUS3,
    TX_STATUS4,
    TX_STATUS5,
    TX_STATUS6,
    RX_STATUS4,
    RX_STATUS5
    ,
    TX_STATUS7,
    TX_STATUS8,
    TX_STATUS9
  } mac_reg_e;

  localparam  MAC_REG_NUM = 16 + 5;

  localparam reg_info_s  MAC_REG_INFO[MAC_REG_NUM] = '{
    // RX_MARGIN_STATUS0
    '{addr: 12'h0, val: {6'h0, 1'h0, 1'h0}, attr: {{6{RESERVED}}, CYCLE, CYCLE}},
    // RX_MARGIN_STATUS1
    '{addr: 12'h1, val: {1'h0, 7'h0}, attr: {RESERVED, {7{LEVEL}}}},
    // RX_MARGIN_STATUS2
    '{addr: 12'h2, val: {2'h0, 6'h0}, attr: {{2{RESERVED}}, {6{LEVEL}}}},
    // ELASTIC_BUFFER_STATUS
    '{addr: 12'h3, val: {7'h0, 1'h0}, attr: {{7{RESERVED}}, CYCLE}},
    // ELASTIC_BUFFER_LOCATION
    '{addr: 12'h4, val: {8'h0}, attr: {8{LEVEL}}},
    // RX_LINK_EVALUATION_STATUS0
    '{addr: 12'ha, val: {8'h0}, attr: {8{LEVEL}}},
    // RX_LINK_EVALUATION_STATUS1
    '{addr: 12'hb, val: {2'h0, 6'h0}, attr: {{2{RESERVED}}, {6{LEVEL}}}},
    // RX_LINK_EVALUATION_STATUS2
    '{addr: 12'he, val: {1'h0, 3'h0, 1'h0, 3'h0}, attr: {RESERVED, {3{LEVEL}}, RESERVED, {3{LEVEL}}}},
    // RX_LINK_EVALUATION_STATUS3
    '{addr: 12'hf, val: {1'h0, 3'h0, 1'h0, 3'h0}, attr: {RESERVED, {3{LEVEL}}, RESERVED, {3{LEVEL}}}},
    // TX_STATUS0
    '{addr: 12'h400, val: {8'h0}, attr: {8{LEVEL}}},
    // TX_STATUS1
    '{addr: 12'h401, val: {8'h0}, attr: {8{LEVEL}}},
    // TX_STATUS2
    '{addr: 12'h402, val: {8'h0}, attr: {8{LEVEL}}},
    // TX_STATUS3
    '{addr: 12'h403, val: {2'h0, 6'h0}, attr: {{2{RESERVED}}, {6{LEVEL}}}},
    // TX_STATUS4
    '{addr: 12'h404, val: {2'h0, 6'h0}, attr: {{2{RESERVED}}, {6{LEVEL}}}},
    // TX_STATUS5
    '{addr: 12'h405, val: {2'h0, 6'h0}, attr: {{2{RESERVED}}, {6{LEVEL}}}},
    // TX_STATUS6
    '{addr: 12'h406, val: {2'h0, 6'h0}, attr: {{2{RESERVED}}, {6{LEVEL}}}},
    // RX_STATUS4
    '{addr: 12'hc, val: {2'h0, 6'h0}, attr: {{2{RESERVED}}, {6{LEVEL}}}},
    // RX_STATUS5
    '{addr: 12'hd, val: {2'h0, 6'h0}, attr: {{2{RESERVED}}, {6{LEVEL}}}}
   ,
    // TX_STATUS7
    '{addr: 12'h407, val: {8'h0}, attr: {8{LEVEL}}},
    // TX_STATUS8
    '{addr: 12'h408, val: {8'h0}, attr: {8{LEVEL}}},
    // TX_STATUS8
    '{addr: 12'h409, val: {8'h0}, attr: {8{LEVEL}}}
  };

  function automatic logic  exists_mac_reg(mac_reg_e  e);
    logic  ret;
    case(e)
      RX_MARGIN_STATUS0,
      RX_MARGIN_STATUS1,
      RX_MARGIN_STATUS2: ret = 1'h1;
      RX_LINK_EVALUATION_STATUS0,
      RX_LINK_EVALUATION_STATUS1: ret = 1'h1;
      RX_LINK_EVALUATION_STATUS2,
      RX_LINK_EVALUATION_STATUS3: ret = 1'h1;
      TX_STATUS0,
      TX_STATUS1,
      TX_STATUS2,
      TX_STATUS3,
      TX_STATUS4: ret = 1'h1;
      TX_STATUS5,
      TX_STATUS6: ret = 1'h1;
      RX_STATUS4,
      RX_STATUS5: ret = 1'h1;
      TX_STATUS7,
      TX_STATUS8,
      TX_STATUS9: ret = 1'h1;
      default: ret = 1'h0;
    endcase
    return ret;
  endfunction


endpackage // pipe_regif_pkg

`endif // __GUARD__PIPE_REGIF_PKG__SVH__
