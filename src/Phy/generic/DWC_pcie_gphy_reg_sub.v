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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Phy/generic/DWC_pcie_gphy_reg_sub.v#2 $
// -------------------------------------------------------------------------
// --- Description: PHY Register model
// -------------------------------------------------------------------------

module DWC_pcie_gphy_reg_sub
#(
    parameter TP            = 0,
    parameter pREG_ADDRESS  = 12'h000,
    parameter pRESET_VALUE  = 8'h00,
    parameter pRESERVED_BIT = 8'h00,
    parameter pVOLATILE_BIT = 8'h00
) (
input                         pclk,
input                         phy_rst_n,
input       [3:0]             mac_phy_command,
input       [11:0]            mac_phy_address,
input       [7:0]             mac_phy_data,
output  reg [7:0]             phy_reg
);
wire                          write_uncommitted;
wire                          write_committed;
reg                           phy_reg_uc_valid;
reg         [7:0]             phy_reg_uc;

// -------------------------------------------------------------------------
// Command Flags
// -------------------------------------------------------------------------
assign write_uncommitted = (mac_phy_command==`GPHY_CMD_WR_UC) ? 1'b1 : 1'b0 ;
assign write_committed   = (mac_phy_command==`GPHY_CMD_WR_C)  ? 1'b1 : 1'b0 ;

// -------------------------------------------------------------------------
// Read Data
// -------------------------------------------------------------------------
always @(posedge pclk or negedge phy_rst_n) begin
  if (!phy_rst_n) begin
    phy_reg_uc_valid <= #TP 1'b0;
    phy_reg_uc       <= #TP pRESET_VALUE;
    phy_reg          <= #TP pRESET_VALUE;
  end else begin
    phy_reg_uc_valid <= #TP (write_uncommitted & mac_phy_address==pREG_ADDRESS) ?          1'b1 :
                            (write_committed                                  ) ?          1'b0 : phy_reg_uc_valid;
    phy_reg_uc       <= #TP (write_uncommitted & mac_phy_address==pREG_ADDRESS) ? (mac_phy_data & ~pRESERVED_BIT) : phy_reg_uc;
    phy_reg          <= #TP (write_committed   & mac_phy_address==pREG_ADDRESS) ? (mac_phy_data & ~pRESERVED_BIT) : 
                            (write_committed   & phy_reg_uc_valid             ) ?                      phy_reg_uc : (phy_reg & ~pVOLATILE_BIT);
  end
end


endmodule // DWC_pcie_gphy_reg_sub
