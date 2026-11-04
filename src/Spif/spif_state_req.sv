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
// --- RCS information:
// ---  $DateTime: 2023/12/22 07:15:34 $
// ---  $Revision: #3 $
// ---  $Id: //dwh/pcie_iip/main/fairbanks/design/Spif/spif_state_req.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// SPIF Link Layer State Request FSM
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"

module spif_state_req
  import spif_pkg::*;                                          // Import SPIF package
#(
  parameter  PROTOCOL      = 0,  // 0 - CXL.io; 1 - CXL.cachemem
  parameter  TP            = `TP
) 
                       (
  // Inputs
  input                                core_clk,
  input                                core_rst_n,
  input                                pl_protocol_vld,        // Physical Layer Protocol Valid
  input  protocol_type_e               pl_protocol,            // Physical Layer Protocol Type
  input  protocol_fmt_e                pl_protocol_fmt,        // Physical Layer Protocol Flit Format
  input                                pl_inband_pres,         // Physical Layer Inband Presence Detected
  input                                pl_phyinretrain,        // Physical Layer Recovery
  input  state_enc_e                   pl_state_sts,           // Physical Layer State Status
  input                                pl_stall_req,           // Physical Layer Stall Request
  input                                lp_pm_l1_req,           // Link Layer L1 Request
  input                                lp_pm_l2_req,           // Link Layer L2 Request
  input                                lp_pm_l0s_req,          // Link Layer L0S Request
  input                                lp_retrain_req,         // Link Layer Retrain Request
  input                                lp_reset_req,           // Link Layer Reset Request
  input                                lp_disable_req,         // Link Layer Disable Request
  // Outputs
  output state_enc_e                   lp_state_req,           // Link Layer State Request
  output                               lp_protocol_vld,        // Link Layer Protocol Valid
  output protocol_type_e               lp_protocol,            // Link Layer Protocol Type
  output protocol_fmt_e                lp_protocol_fmt         // Link Layer Protocol Flit Format
);


// -------------------------------------------------------------------------------------
// Rulse for Link Layer:
// Link Layer must sample and store pl_protocol when pl_protocol_vld = 1 and pl_state_sts = RESET and pl_inband_pres = 1.
// It must treat this save value as the negotiated protocol until pl_state_sts = RESET and pl_inband_pres = 0.
// -------------------------------------------------------------------------------------
logic             lp_protocol_vld_r, lp_protocol_vld_nxt;  // Link Layer protocol valid
protocol_type_e   lp_protocol_r    , lp_protocol_nxt;      // Link Layer sampled protocol
protocol_fmt_e    lp_protocol_fmt_r, lp_protocol_fmt_nxt;  // Link Layer sampled protocol flit format

assign lp_protocol_vld = lp_protocol_vld_r;
assign lp_protocol     = lp_protocol_r;
assign lp_protocol_fmt = lp_protocol_fmt_r;

always_comb begin
    if (pl_protocol_vld && (pl_state_sts == RESET) && pl_inband_pres) begin
        lp_protocol_vld_nxt = 1'b1;
        lp_protocol_nxt     = pl_protocol;
        lp_protocol_fmt_nxt = pl_protocol_fmt;
    end
    else if ((pl_state_sts == RESET) && !pl_inband_pres) begin
        lp_protocol_vld_nxt = 1'b0;
        lp_protocol_nxt     = PCIE_MODE;
        lp_protocol_fmt_nxt = FMT_NONE_FLIT;
    end
    else begin
        lp_protocol_vld_nxt = lp_protocol_vld_r;
        lp_protocol_nxt     = lp_protocol_r;
        lp_protocol_fmt_nxt = lp_protocol_fmt_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        lp_protocol_vld_r   <= # TP 1'b0;
        lp_protocol_r       <= # TP PCIE_MODE;
        lp_protocol_fmt_r   <= # TP FMT_NONE_FLIT;
    end else begin
        lp_protocol_vld_r   <= # TP lp_protocol_vld_nxt;
        lp_protocol_r       <= # TP lp_protocol_nxt;
        lp_protocol_fmt_r   <= # TP lp_protocol_fmt_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Protocol Decoder Instantiation to be used on the hierarchy level
// -------------------------------------------------------------------------------------
protocol_cfg_t    lp_protocol_cfg; // Link Layer Protocol Configuration

spif_protocol_dec
 u_spif_protocol (
    // Inputs
    .core_clk        ( core_clk          ),
    .core_rst_n      ( core_rst_n        ),
    .pl_protocol_vld ( lp_protocol_vld_r ),
    .pl_protocol     ( lp_protocol_r     ),
    .pl_protocol_fmt ( lp_protocol_fmt_r ),
    // Outputs
    .pl_protocol_cfg ( lp_protocol_cfg   )
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Link Layer State Request FSM
// -------------------------------------------------------------------------------------
state_enc_e  state_r, state_nxt;  // Link Layer State Request FSM
logic        pm_active_req_s;     // Request to exit from PM state
logic        pm_cancel_ena_s;     // Enables PM request cancellation
logic        lp_active_req_s;     // Link Layer Active Request

// Link Layer State Request output
assign lp_state_req    = state_r;
// Link Layer requests Active when corresponding protocol is valid
assign lp_active_req_s = lp_protocol_vld && ((PROTOCOL == 1) ? (lp_protocol_cfg.cxl_cache_enable || lp_protocol_cfg.cxl_mem_enable) : (lp_protocol_cfg.pcie_mode_enable || lp_protocol_cfg.cxl_mode_enable));
// PM request is de-asserted when FSM is in corresponding PM state or Downstream Port rejected PM entry request (pl_state_sts == ACTIVE_L0S_PMNAK)
assign pm_active_req_s = ((state_r == IDLE_L1_1) && !lp_pm_l1_req) || ((state_r == L2) && !lp_pm_l2_req);
// In CXL 68B flit mode it is allowed to cancel PM entry request before pl_stall_req is asserted
assign pm_cancel_ena_s = !pl_stall_req && lp_protocol_cfg.cxl_mode_enable && !lp_protocol_cfg.cxl_pcie_flit_mode;

always_comb begin
    if (lp_disable_req) begin
        state_nxt = DISABLED;
    end
    else if (lp_reset_req) begin
        state_nxt = LINKRESET;
    end
    // If Link Layer requests a recovery and the pl_state_sts is ACTIVE then
    // change the requested state to RETRAIN on SPIF interface to request Physical Layer
    // to go into the recovery
    // Note: Link Layer can request a recovery only when Link vLSM is in ACTIVE state
    // Note: As in CXL 256B Flit Mode the recovery is not exposed on pl_state_sts as RETRAIN, it is required to check that 
    // pl_phyinretrain is de-asserted, i.e. the recovery is completed before attempting another RETRAIN request to LogPHY.
    else if (lp_retrain_req && (state_r == ACTIVE) && (pl_state_sts == ACTIVE) && !pl_phyinretrain) begin
        state_nxt = RETRAIN;
    end
    else begin
        case (state_r)
            ACTIVE: begin
                // If pl_state_sts is ACTIVE and Link Layer requests L1 Entry then
                // change the requested state on SPIF interface to IDLE_L1_1
                // Note: Link Layer must not assert lp_pm_l1_req and lp_pm_l2_req at the same time
                if ((pl_state_sts == ACTIVE) && lp_pm_l1_req) begin
                    state_nxt = IDLE_L1_1;
                end
                // If pl_state_sts is ACTIVE and Link Layer requests L2 Entry then
                // change the requested state on SPIF interface to L2
                else if ((pl_state_sts == ACTIVE) && lp_pm_l2_req) begin
                    state_nxt = L2;
                end
                // If pl_state_sts is ACTIVE and Link Layer requests L0S Entry in PCIe mode then
                // change the requested state on SPIF interface to ACTIVE_L0S_PMNAK
                else if ((pl_state_sts == ACTIVE) && lp_pm_l0s_req && lp_protocol_cfg.pcie_mode_enable) begin
                    state_nxt = ACTIVE_L0S_PMNAK;
                end
                else begin
                    state_nxt = state_r;
                end
            end
            ACTIVE_L0S_PMNAK: begin
                if (!lp_pm_l0s_req) begin
                    state_nxt = ACTIVE;
                end
                else begin
                    state_nxt = state_r;
                end
            end
            IDLE_L1_1, L2: begin
                // It is allowed to change the requested state back to ACTIVE before the point 
                // the physical layer asserted pl_stall_req and started PM entry for 68B or 
                // after the point it reached PM or PMNAK state
                if (pm_active_req_s && (pm_cancel_ena_s || (pl_state_sts inside {IDLE_L1_1 , ACTIVE_L0S_PMNAK})) || (pl_state_sts == RETRAIN)) begin
                    state_nxt = ACTIVE;
                end
                else begin
                    state_nxt = state_r;
                end
            end
            RETRAIN: begin
                // When a recovery is requested then wait until Physical Layer transits to RETRAIN state
                // before changing the requested state to ACTIVE
                // Note: In CXL 256B Flit Mode recovery is not exposed on pl_state_sts as RETRAIN state henc
                // pl_phyinretrain indication from LogPHY is used to indicate that the recovery is triggered
                if ( lp_protocol_cfg.cxl_pcie_flit_mode ? pl_phyinretrain : (pl_state_sts == RETRAIN)) begin
                    state_nxt = ACTIVE;
                end
                else begin
                    state_nxt = state_r;
                end
            end
            default: begin
                // Request Active if corresponding Link Layer protocol is enabled
                if (lp_active_req_s) begin
                    state_nxt = ACTIVE;
                end
                else begin
                    state_nxt = state_r;
                end
            end
        endcase
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        state_r      <= #TP RESET;
    end else begin
        state_r      <= #TP state_nxt;
    end
end
// -------------------------------------------------------------------------------------

endmodule
