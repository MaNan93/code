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
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pm_active_flags.sv#14 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Contains logic to generate various flags which are used internally in
// --- pm_protocol_fsm
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"
 
 module pm_active_flags
  import cx_pl_pkg::dllp_struct;
  import cx_pl_pkg::PM_ENTER_L1;
  import cx_pl_pkg::PM_ENTER_L23;
  import cx_pl_pkg::PM_ACTIVE_STATE_REQUEST_L1;
  import cx_pl_pkg::NOP_DLLP;
  import cx_pl_pkg::PM_REQUEST_ACK;
  import cx_pl_pkg::DUMMY;
  import spif_pkg::state_enc_e;
  import spif_pkg::RETRAIN;
  import spif_pkg::IDLE_L1_1;
  import spif_pkg::ACTIVE_L0S_PMNAK;
    // Parameters
#( 
  parameter TP = `TP
) 
                         (
  // Inputs
  input               core_clk,                      // Core clock
  input               core_rst_n,                    // Core reset
  input               cxl_pcie_flit_mode,            // CXL 256B Flit Mode enable
  input               smlh_link_up,                  // LogPHY is in link up
  input               smlh_in_l1,                    // LogPHY is in L1
  input               smlh_in_l0,                    // LogPHY is in ACTIVE state
  input               smlh_in_rl0s,                  // LogPHY is in RX L0s state
  input               smlh_link_in_training,         // LogPHY is in RETRAIN state
  input               usp_link_l1_in_progress,       // TOBEREMOVED: USP PM Link FSM L1 entry is in progress
  input               usp_prot_wait_dstate_update,   // USP PM Protocol FSM is in WAIT_FOR_DSTATE_UPDATE
  input               usp_prot_l1_block_tlp,         // USP PM Protocol FSM is in L1_BLOCK_TLP
  input               usp_prot_l1_wait_last_tlp_ack, // USP PM Protocol FSM is in L1_WAIT_LAST_TLP_ACK
  input               usp_prot_l1_wait_pmdllp_ack,   // USP PM Protocol FSM is in L1_WAIT_PMDLLP_ACK
  input               usp_prot_l23_block_tlp,        // USP PM Protocol FSM is in L23_BLOCK_TLP
  input               usp_prot_l23_wait_pmdllp_ack,  // USP PM Protocol FSM is in L23_WAIT_PMDLLP_ACK
  input               usp_prot_wait_last_pmdllp,     // USP PM Protocol FSM is in WAIT_LAST_PMDLLP
  input               dsp_prot_wait_last_pmdllp,     // DSP PM Protocol FSM is in WAIT_LAST_PMDLLP
  input               latch_as_entr_l1,              // ASPM L1 entry
  input               radm_pm_asnak,                 // RADM PM_Active_State_Nak received
  input               pm_aspm_l1_en,                 // PME Controller indicates to the PM Protocol FSM that L1 ASPM is enabled
  input               pm_l23_entry_flag_clear,       // Clear L23 entry flag
  input               pm_l23_restart_clear,          // Clear L23 restart flag
  input               pm_l23_entry_abort,            // Aborted L23 entry during transmission of PM_Enter_L23 DLLP's
  input               pm_req_ack_ena,                // Enable PM Request Acknowledge DLLP
  input  dllp_struct  pm_dllp_ack,                   // PM DLLP Acknowledge
  input               spif_enable,                   // SPIF is enabled
  input  state_enc_e  pl_state_sts,                  // States Status on SPIF Interface
  input               pm_prot_enter_l1,              // Drive PCIe/CXL.io to enter L1.
  input               pm_prot_enter_l2,              // Drive PCIe/CXL.io to enter L2.
  input               prot_pm_l1_exit,               // Link Layer indicates to Protocol FSM to exit L1
  input               prot_pm_l23_exit,              // Link Layer indicates to Protocol FSM to exit L23
  // Outputs
  output logic        prot_pm_l1_finish,             // Drive Protocol FSM to exit from L1 when Link Layer exits L1
  output logic        prot_pm_l23_finish,            // Drive Protocol FSM to exit from L23 when Link Layer exits exits L1
  output logic        pm_l1_aspm_flag,               // L1 ASPM entry flag
  output logic        pm_l23_entry_flag,             // L23 Ready entry flag
  output logic        pm_timeout,                    // Timeout
  output logic        pm_l23_entry_restart,          // Restart aborted L23 entry negotiation
  output logic        pm_l1_pcipm_hs_done,           // PM_Enter_L1 requested by PM block and sent by XDLH 
  output logic        pm_l1_aspm_hs_done,            // PM_Active_State_Request_L1 requested by PM block and sent by XDLH 
  output logic        pm_l23_hs_done,                // PM_Enter_L23 requested by PM block and sent by XDLH
  output dllp_struct  pm_xdlh_dllp_req               // PM to XDLH DLLP Request
);

// -----------------------------------------------------------------------------
// Net Declarations
// -----------------------------------------------------------------------------
wire  int_set_l1_aspm_flag;
wire  int_clear_l1_aspm_flag;
wire  int_set_l23_entry_flag;
wire  int_clear_l23_entry_flag;
wire  int_req_l1_dllp;
wire  int_set_actst_req_l1;
wire  int_clear_req_l1;
wire  int_set_pm_req_l1;
wire  int_set_pm_req_l23;
wire  int_clear_pm_req_l23;
wire  int_clear_l23_restart;
wire  int_set_last_pmdllp;
wire  int_clear_last_pmdllp;
wire  int_set_pm_req_ack;
wire  int_clear_pm_req_ack;
wire int_set_l1_pcipm_hs;
wire int_set_l1_aspm_hs;
wire int_set_l23_hs;
wire int_clear_l1_pcipm_hs;
wire int_clear_l1_aspm_hs;
wire int_clear_l23_hs;

wire pm_xdlh_enter_l23;      // Request to transmit PM_Enter_L23 DLLP's
wire pm_xdlh_enter_l1;       // Request to transmit PM_Enter_L1 DLLP's
wire pm_xdlh_actst_req_l1;   // Request to transmit PM_Active_State_Request_L1 DLLP's
wire int_clear_prot_pm_l1_finish;
wire int_set_prot_pm_l1_finish;
wire int_clear_prot_pm_l23_finish;
wire int_set_prot_pm_l23_finish;
wire int_active_pmnak;

// L1 request NAKed by DSP in Active Power Management flow defined when PM DLLP is not enabled (CXL 256B flit mode)
assign int_active_pmnak = 1'b0 || (cxl_pcie_flit_mode && (pl_state_sts == ACTIVE_L0S_PMNAK));

// ASPM L1 flag this flag is set when L1 ASPM entry negotiation has been initiated
// but is interrupted by LTSSM going through Recovery
// The flag is necessary to direct the USP to restart the L1 ASPM negotiation when Recovery
// has completed.
assign int_set_l1_aspm_flag = pm_aspm_l1_en && !pm_l23_entry_flag && latch_as_entr_l1 && 
(usp_prot_l1_block_tlp || usp_prot_l1_wait_last_tlp_ack || usp_prot_l1_wait_pmdllp_ack || usp_prot_wait_last_pmdllp ||
( spif_enable ? 1'b0 : usp_link_l1_in_progress) ) && smlh_link_in_training;

// The flag is cleared if the ASPM L1 request is Naked by DSP or if PCI-PM L1/L23 is initiated or upon completion
// of L1 entry process or if the link reset request is asserted or L1 request NAKed by DSP at Phase 2 negotiation for CXL 256B flit mode
assign int_clear_l1_aspm_flag = (int_req_l1_dllp && radm_pm_asnak && latch_as_entr_l1) || !latch_as_entr_l1 ||
usp_prot_l23_block_tlp || !smlh_link_up || smlh_in_l1 || int_active_pmnak;

// L2 entry flag
// Set the flag when entry DLLP's are being sent
// Clear the flag if we go back to the IDLE state for any reason or if we complete L2 entry
assign int_set_l23_entry_flag = usp_prot_l23_wait_pmdllp_ack;
assign int_clear_l23_entry_flag = pm_l23_entry_flag_clear;

// L23 Negotiation restart flag
// Set the flag if a transition from L23_WAIT_PMDLLP_ACK to IDLE occurs
// Clear the flag upon completion of L23 entry or if the link is reset
assign int_clear_l23_restart = pm_l23_restart_clear;

// Create flags for various purposes
pm_flag
 u_flag_inst [2:0] (
  // Inputs
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  ({int_clear_l1_aspm_flag, int_clear_l23_entry_flag, int_clear_l23_restart}),
  .set    ({int_set_l1_aspm_flag, int_set_l23_entry_flag, pm_l23_entry_abort}),
  // Outputs
  .flag_r ({pm_l1_aspm_flag, pm_l23_entry_flag, pm_l23_entry_restart})
);

// Detect a transition to the L1_WAIT_PMDLLP_ACK state to initiate relevant L1 entry protocol
assign int_req_l1_dllp = usp_prot_l1_wait_pmdllp_ack;

// Logic for setting the request to the XDLH to transmit PM_Active_State_Request_L1 DLLP
assign int_set_actst_req_l1 = (int_req_l1_dllp && latch_as_entr_l1) && !smlh_link_in_training;
assign int_clear_req_l1 = !int_req_l1_dllp;

// Logic for setting the request to the XDLH to transmit PM_Enter_L1 DLLP
assign int_set_pm_req_l1 = (int_req_l1_dllp && !latch_as_entr_l1) && !smlh_link_in_training;

// Logic for setting the request to the XDLH to transmit PM_Enter_L2 DLLP
assign int_set_pm_req_l23 = usp_prot_l23_wait_pmdllp_ack && !smlh_link_in_training;
assign int_clear_pm_req_l23 = (!usp_prot_l23_wait_pmdllp_ack);

assign int_set_last_pmdllp = usp_prot_wait_last_pmdllp || dsp_prot_wait_last_pmdllp;
assign int_clear_last_pmdllp = !usp_prot_wait_last_pmdllp && !dsp_prot_wait_last_pmdllp;

assign int_set_pm_req_ack = dsp_prot_wait_last_pmdllp && pm_req_ack_ena;
assign int_clear_pm_req_ack= !dsp_prot_wait_last_pmdllp || !pm_req_ack_ena;


pm_flag
 u_pm_dllp_req_inst [4:0] (
  // Inputs
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  ({int_clear_pm_req_l23, int_clear_req_l1, int_clear_req_l1,int_clear_pm_req_ack,int_clear_last_pmdllp}),
  .set    ({int_set_pm_req_l23, int_set_pm_req_l1, int_set_actst_req_l1,int_set_pm_req_ack,int_set_last_pmdllp}),
  // Outputs
  .flag_r ({pm_xdlh_enter_l23, pm_xdlh_enter_l1, pm_xdlh_actst_req_l1,pm_xdlh_req_ack,pm_xdlh_last_pmdllp})

);

//
always_comb begin
  if (pm_xdlh_enter_l23) begin
     pm_xdlh_dllp_req.dllp_type= PM_ENTER_L23;
     pm_xdlh_dllp_req.valid = 1'b1;
     pm_xdlh_dllp_req.pyld  = 24'b0;
  end
  else if (pm_xdlh_enter_l1) begin
     pm_xdlh_dllp_req.dllp_type= PM_ENTER_L1;
     pm_xdlh_dllp_req.valid = 1'b1;
     pm_xdlh_dllp_req.pyld  = 24'b0;
  end
  else if (pm_xdlh_actst_req_l1) begin
     pm_xdlh_dllp_req.dllp_type= PM_ACTIVE_STATE_REQUEST_L1;
     pm_xdlh_dllp_req.valid = 1'b1;
     pm_xdlh_dllp_req.pyld  = 24'b0;
  end
  else if (pm_xdlh_req_ack)begin
     pm_xdlh_dllp_req.dllp_type= PM_REQUEST_ACK;
     pm_xdlh_dllp_req.valid = 1'b1;
     pm_xdlh_dllp_req.pyld  = 24'b0;
  end
  else if (pm_xdlh_last_pmdllp)begin
     pm_xdlh_dllp_req.dllp_type= NOP_DLLP;
     pm_xdlh_dllp_req.valid = 1'b1;
     pm_xdlh_dllp_req.pyld  = 24'b0;
  end
  else begin
     pm_xdlh_dllp_req.dllp_type=NOP_DLLP;
     pm_xdlh_dllp_req.valid = 1'b0;
     pm_xdlh_dllp_req.pyld  = 24'b0;
  end
end 

// Watchdog timer for USP_*_WAIT_DSTATE_UPDATE state
pm_active_timer
 u_pm_active_timer (
  // Inputs
  .core_clk      (core_clk),
  .core_rst_n    (core_rst_n),
  .smlh_in_rl0s  (smlh_in_rl0s),  
  .usp_prot_wait_dstate_update(usp_prot_wait_dstate_update),
  .smlh_in_l0    (smlh_in_l0),
  // Outputs
  .pm_timeout    (pm_timeout)
);

// Create flags to indicate PM DLLP's requested by PM block have been sent by the Layer2
assign int_set_l23_hs = (pm_dllp_ack.valid && (pm_dllp_ack.dllp_type==PM_ENTER_L23) && pm_xdlh_enter_l23)? 1'b1: 1'b0;
assign int_set_l1_pcipm_hs = (pm_dllp_ack.valid && (pm_dllp_ack.dllp_type==PM_ENTER_L1) && pm_xdlh_enter_l1)?1'b1:1'b0;
assign int_set_l1_aspm_hs = (pm_dllp_ack.valid && (pm_dllp_ack.dllp_type==PM_ACTIVE_STATE_REQUEST_L1) && pm_xdlh_actst_req_l1)? 1'b1:1'b0;

assign int_clear_l23_hs = !pm_xdlh_enter_l23;
assign int_clear_l1_pcipm_hs = !pm_xdlh_enter_l1;
assign int_clear_l1_aspm_hs = !pm_xdlh_actst_req_l1;

pm_flag
 u_pm_dllp_hs_inst [2:0] (
  // Inputs
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  ({int_clear_l23_hs, int_clear_l1_pcipm_hs, int_clear_l1_aspm_hs}),
  .set    ({int_set_l23_hs, int_set_l1_pcipm_hs, int_set_l1_aspm_hs}),
  // Outputs
  .flag_r ({pm_l23_hs_done, pm_l1_pcipm_hs_done, pm_l1_aspm_hs_done})
);

assign int_clear_prot_pm_l1_finish  = (!pm_prot_enter_l1 && prot_pm_l1_finish ) || !smlh_link_up;
assign int_set_prot_pm_l1_finish    = prot_pm_l1_exit;

assign int_clear_prot_pm_l23_finish = (!pm_prot_enter_l2 && prot_pm_l23_finish) || !smlh_link_up;
assign int_set_prot_pm_l23_finish   = prot_pm_l23_exit;

pm_flag
 u_pm_vlsm_hs_inst [1:0] (
  // Inputs
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  ({int_clear_prot_pm_l1_finish, int_clear_prot_pm_l23_finish}),
  .set    ({int_set_prot_pm_l1_finish, int_set_prot_pm_l23_finish}),
  // Outputs
  .flag_r ({prot_pm_l1_finish, prot_pm_l23_finish})
);

endmodule

