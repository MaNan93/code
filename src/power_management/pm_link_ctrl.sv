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
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_link_ctrl.sv#1 $
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module provides link control logic
// --- 
// --- Following dynamic clock gating handshakes are implemented by this module:
// --- - pm_wake_req     / pm_wake_ack     : handshake to remove clock gating from the LogPHY
// --- - pm_pcie_clk_req / pm_pcie_clk_ack : handshake to remove clock gating from PCIe/CXL.io Link Layer
// --- - pm_cxl_clk_req  / pm_cxl_clk_ack  : handshake to remove clock gating from CXL.cacheme Link Layer
// --- - pm_clk_req      / pm_clk_ack      : handshake to remove clock gating from the interface clock
// ---   Note: interface (shared) clock is defined as clock required for all Link Layers operation
// --- 
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

module pm_link_ctrl #( 
  parameter TP = `TP
) (
  input            aux_clk,                // Auxiliary clock
  input            pwr_rst_n,              // Power-On reset
  input            pm_en_core_clk,         // PM Clock Contoller: core_clk is active. Used to acknowledge clock gating removal
  input            pm_wake_ena,            // Enable PM wakeup event
  input            pm_wake_req,            // PM WakeUp: Request to remove internal clock gating on LogPHY. As long as we drive
                                           // both Link Layer(s) and LogPHY with the same clock, when LogPHY is not enabled,
                                           // this request removes internal clock gating on Link Layers.
  input            pm_en_core_clk_gating,  // PM Active Controller: Enable core_clk gating when LogPHY is enabled
  input            pm_clk_req,             // PM Active Controller: LogPHY request to remove interface clock gating (clock required for all Link Layers operation)
  input            pl_pcie_clk_req,        // SPIF: LogPHY request to remove Link Layer clock gating
  input            pl_cxl_clk_req,         // SPIF: LogPHY request to remove Link Layer clock gating
  input            pl_phyinl1,             // SPIF: PM is in L1 and current power down state is P1
  input            pl_phyinl2,             // SPIF: PM is in L2 and current power down state is P2
  output logic     lp_pcie_clk_ack,        // SPIF: PCIe/CXL.io Link Layer acknowledges LogPHY request to remove the clock gating
  output logic     lp_cxl_clk_ack,         // SPIF: CXL.cachemem Link Layer acknowledges LogPHY request to remove the clock gating
  output logic     pm_clk_ack,             // PM Active Contoller: Acknowledgement of clock gating from the interface clock
  output logic     pm_wake_ack,            // PM WakeUp: WakeUp acknowledge from LogPHY when LogPHY is enabled
  output logic     pm_wakeup_event,        // PM Active Contoller: Wakeup event to LogPHY
  output logic     pm_linkst_en_core_clk   // PM Clock Contoller: request to enable core_clk
);

logic  int_pm_wake_req_s   ;  // Internal PM wakeup request to remove clock gating. Requested internally by PM WakeUp or by LogPHY.
logic  int_pm_wake_req_r   ;  // Latched PM wakeup request. Implement a hanshake with internal WakeUp acknowledge
logic  int_pm_wake_ack_r   ;  // WakeUp acknowledge on the internal WakeUp request
logic  int_pm_clk_req_s    ;  // Internal clock request
logic  int_pm_clk_ack_r    ;  // Internal clock acknowledge to int_pm_clk_req_s
logic  int_pm_wake_active_s;  // PM wakeup is in progress

// Assert PM wakeup event when either Link Layer requests LogPHY to remove clock gating or
// LogPHY requests Link Layer to remove clock gating for an interface/shared clock (core_clk)
assign pm_wakeup_event  = pm_wake_req || int_pm_clk_req_s;

// Enable core_clk if not in L2 or L1 if clock gating is enabled and there is no wakeup event
assign pm_linkst_en_core_clk = !(pl_phyinl2 || (pl_phyinl1 && pm_en_core_clk_gating && !int_pm_wake_req_s));

assign pm_clk_ack = int_pm_clk_ack_r;

// Assert wakeup event signal if PHY is in L1 and wakeup is enabled
assign int_pm_wake_req_s = (pl_phyinl1 ? pm_wake_ena : 1'b1) && ((pm_wakeup_event && !int_pm_wake_ack_r) || int_pm_wake_req_r);

// Assert internal clock request when PM request to remove clock gating from the interface clock
assign int_pm_clk_req_s   = pm_clk_req;

// Indicate that wakeup is in progress when wakeup request is asserted and it is not yet acknowledged
assign int_pm_wake_active_s = int_pm_wake_req_s && !int_pm_wake_ack_r;

// -----------------------------------------------------------------------------
// WakeUp and Clock Request/Acknowledge Handshake
// -----------------------------------------------------------------------------
// Latch internal WakeUp request
always @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n)
        int_pm_wake_req_r <=  #TP 1'b0;
    // Keep internal wakeup request until exit from PM state is complete
    // This guarantees that pl_phyinl1 and pl_phyinl2 transitions are observed by the Link Layer(s)
    else if (int_pm_wake_ack_r && !pm_wakeup_event && !(pl_phyinl1 || pl_phyinl2))
        int_pm_wake_req_r <=  #TP 1'b0;
    // Latch wakeup request
    else if (pm_wakeup_event)
        int_pm_wake_req_r <=  #TP 1'b1;
end

// WakeUp acknowledge on the internal WakeUp request
always @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n)
        int_pm_wake_ack_r <=  #TP 1'b0;
    else if (int_pm_wake_req_r && pm_linkst_en_core_clk && pm_en_core_clk)
        int_pm_wake_ack_r <=  #TP 1'b1;
    else if (!int_pm_wake_req_r && int_pm_wake_ack_r)
        int_pm_wake_ack_r <=  #TP 1'b0;
end

// WakeUp acknowledge on the SPIF Interface
always @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n)
        pm_wake_ack <=  #TP 1'b0;
    // Assert pm_wake_ack when pm_wake_req is acknowledged
    else if (pm_wake_req && int_pm_wake_ack_r)
        pm_wake_ack <=  #TP 1'b1;
    // Preserve pm_wake_ack asserted to block new wakeup requests until internal pm_wake_req is de-asserted
    else if (!pm_wake_req && pm_wake_ack && !int_pm_wake_ack_r)
        pm_wake_ack <=  #TP 1'b0;
end

// -----------------------------------------------------------------------------
// Clock Request/Acknowledge Handshake
// -----------------------------------------------------------------------------
// Clock acknowledge for common clock required for all Link Layers
always @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n)
        int_pm_clk_ack_r <=  #TP 1'b0;
    // Assert int_pm_clk_ack_r when internal pm_wake_req is acknowledged
    else if (int_pm_clk_req_s && int_pm_wake_ack_r)
        int_pm_clk_ack_r <=  #TP 1'b1;
    // Preserve int_pm_clk_ack_r asserted to block new wakeup requests until internal int_pm_clk_req_s is de-asserted
    else if (!int_pm_clk_req_s && int_pm_clk_ack_r)
        int_pm_clk_ack_r <=  #TP 1'b0;
end

// Clock acknowledge for PCIe/CXL.io clock on SPIF Interface
always @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n)
        lp_pcie_clk_ack <=  #TP 1'b0;
    // Assert int_pm_clk_ack_r when internal clock request is acknowledged
    else if (pl_pcie_clk_req && !int_pm_wake_active_s /* && PCIe clock enabled */)
        lp_pcie_clk_ack <=  #TP 1'b1;
    // Preserve lp_pcie_clk_ack asserted to block new wakeup requests until pl_pcie_clk_req is de-asserted
    else if (!pl_pcie_clk_req && lp_pcie_clk_ack)
        lp_pcie_clk_ack <=  #TP 1'b0;
end

// Clock acknowledge for CXL.cachemem clock on SPIF Interface
always @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n)
        lp_cxl_clk_ack <=  #TP 1'b0;
    // Assert int_pm_clk_ack_r when internal clock request is acknowledged
    else if (pl_cxl_clk_req && !int_pm_wake_active_s /* && CXL clock enabled */)
        lp_cxl_clk_ack <=  #TP 1'b1;
    // Preserve lp_cxl_clk_ack asserted to block new wakeup requests until pl_cxl_clk_req is de-asserted
    else if (!pl_cxl_clk_req && lp_cxl_clk_ack)
        lp_cxl_clk_ack <=  #TP 1'b0;
end
// -----------------------------------------------------------------------------

endmodule // pm_link_ctrl
