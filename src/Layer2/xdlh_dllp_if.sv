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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_dllp_if.sv#4 $
// -------------------------------------------------------------------------
// --- Function Description:
// -----------------------------------------------------------------------------
// --- This module interfaces with the modules requesting DLLP transmission and
// --- forwards the requests to the DLLP generation module depending on Flit Mode.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module xdlh_dllp_if  
  import cx_pl_pkg::*;
#(
  parameter TP = `TP,
  parameter REGOUT = 1'b0 // Register the Outputs
)
                     (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                   core_clk,                           // Core Clock
  input                   core_rst_n,                         // Asynchronous Reset
  // -------------------------------------------------------------------------------------
  // Flit Mode Interface
  // -------------------------------------------------------------------------------------
  input                   flit_mode,                          // Flit Mode Enable
  // -------------------------------------------------------------------------------------
  // Link Status Interface
  // -------------------------------------------------------------------------------------
  input                   xdlh_block_dl_init,                 // SPIF: Indication from the LogPHY to block Initialization of DLLPs
  input                   xdlh_dl_active,                     // SPIF: Indication from the Link Layer that DLCMSM is in DL_ACTIVE state
  input                   smlh_eq_pending,                    // Equalization pending
  // -------------------------------------------------------------------------------------
  // Ack/Nak DLLP Interface
  // -------------------------------------------------------------------------------------
  input                   rdlh_xdlh_req2send_ack,             // Request to send an Ack DLLP
  input                   rdlh_xdlh_req2send_nack,            // Request to send a Nak DLLP
  input                   rdlh_xdlh_req2send_ack_due2dup,     // Duplicate Ack received
  input   [11 : 0]        rdlh_xdlh_req_acknack_seqnum,       // Sequence number of the received TLP 
  output  logic           xdlh_dllp_if_req2send_ack,          // Request to send an Ack DLLP
  output  logic           xdlh_dllp_if_req2send_nack,         // Request to send a Nak DLLP
  output  logic           xdlh_dllp_if_req2send_ack_due2dup,  // Duplicate Ack received
  output  logic [11 : 0]  xdlh_dllp_if_req_acknack_seqnum,    // Sequence number of the received TLP 
  // -------------------------------------------------------------------------------------
  // Vendor Specific DLLP Interface 
  // -------------------------------------------------------------------------------------
  input   dllp_struct     cfg_other_msg_request,              // Vendor Specific DLLP Request
  input                   xdlh_fm_dllp_gen_other_msg_ack,     // DLLP Generator acknowledges Vendor Specific DLLP has been sent
  output  dllp_struct     xdlh_dllp_if_other_msg_request,     // Vendor Specific DLLP Request
  output  dllp_struct     xdlh_dllp_if_fm_other_msg_request,  // Vendor Specific DLLP Request to Flit Mode DLLP Generator
  // -------------------------------------------------------------------------------------
  // FC DLLP Interface
  // -------------------------------------------------------------------------------------
  input                   rtlh_xdlh_fc_req,                   // RTLH Request to send FC DLLP
  input   [31 : 0]        rtlh_xdlh_fc_data,                  // Content data for FC update, which has be to be valid when RTLH_FC_REQ is asserted
  input                   rtlh_xdlh_fc_req_low,               // FC DLLP Low-priority
  input                   rtlh_xdlh_opt_upd,                  // RTLH is sending an Optimized Update FC DLLP
  input                   xdlh_dllp_gen_fc_ack,               // Acknowledge that FC DLLP has been transmitted
  input                   xdlh_fm_dllp_gen_fc_ack,            // Acknowledge that FC DLLP has been transmitted
  output  dllp_struct     xdlh_dllp_if_fc_req,                // Request to send FC DLLP
  output  dllp_struct     xdlh_dllp_if_fm_fc_req,             // Flit Mode Request to send FC DLLP
  output  logic           xdlh_dllp_if_fc_req_low,            // FC DLLP Low-priority
  output  logic           xdlh_dllp_if_fm_opt_upd,            // RTLH is sending an Optimized Update FC DLLP
  output  logic           xdlh_dllp_if_fc_ack,                // Acknowledge that FC DLLP has been transmitted
  // -------------------------------------------------------------------------------------
  // PM DLLP Interface
  // -------------------------------------------------------------------------------------
  input   dllp_struct     pm_xdlh_dllp,                       // Power Management request to send PM DLLP
  output  dllp_struct     xdlh_dllp_if_pm_dllp,               // Power Management request to send PM DLLP
  output  dllp_struct     xdlh_dllp_if_fm_pm_dllp,            // Power Management request to send PM DLLP
  output  logic           xdlh_dllp_if_pm_ack,                // XDLH Acknowledges the PM DLLP has been sent
  input                   xdlh_dllp_gen_pm_ack,               // XDLH Acknowledges the PM DLLP has been sent
  input                   xdlh_fm_dllp_gen_pm_ack,            // XDLH Acknowledges the PM DLLP has been sent
  // -------------------------------------------------------------------------------------
  // DL FEATURE DLLP Interface
  // -------------------------------------------------------------------------------------
  input                   xdlh_fm_dllp_gen_feature_ack,       // XDLH Acknowledges DL Feature DLLP has been sent
  output  logic           xdlh_dllp_if_feature_ack,           // DL Feature Sent
  input                   send_feature_dllp,                  // Request to send the feature DLLP
  input   [22 : 0]        cfg_local_feature_support,          // Local Feature Support
  input                   cfg_dlink_feature_valid,            // Indicates this device has received a Data LInk Feature DLLP after entering L0
  output  dllp_struct     xdlh_dllp_if_fm_feature_dllp        // FM Send Feature DLLP
);

// -------------------------------------------------------------------------------------
// Declarations
// -------------------------------------------------------------------------------------
logic int_fm_dllp_gen_valid;
logic int_fm_dllp_gen_valid_r;


// -------------------------------------------------------------------------------------
// Ack/Nak DLLP Interface
// -------------------------------------------------------------------------------------
// This DLLP Interface is only active in Non-Flit Mode it will be forced to inactive state
// in Flit Mode.
always_comb begin : ack_nak_dllp_mux_PROC
  xdlh_dllp_if_req2send_ack = 1'b0;
  xdlh_dllp_if_req2send_nack = 1'b0;
  xdlh_dllp_if_req2send_ack_due2dup = 1'b0;
  xdlh_dllp_if_req_acknack_seqnum = 12'h000;
  if(flit_mode == 1'b0) begin
    xdlh_dllp_if_req2send_ack = rdlh_xdlh_req2send_ack;
    xdlh_dllp_if_req2send_nack = rdlh_xdlh_req2send_nack;
    xdlh_dllp_if_req2send_ack_due2dup = rdlh_xdlh_req2send_ack_due2dup;
    xdlh_dllp_if_req_acknack_seqnum = rdlh_xdlh_req_acknack_seqnum;
  end
end : ack_nak_dllp_mux_PROC

// -------------------------------------------------------------------------------------
// Vendor Specific DLLP Interface 
// -------------------------------------------------------------------------------------
always_comb begin : req_ack_PROC
  if(xdlh_fm_dllp_gen_other_msg_ack)
    int_fm_dllp_gen_valid = 1'b0;
  else if(cfg_other_msg_request.valid)
    int_fm_dllp_gen_valid = 1'b1;
  else
    int_fm_dllp_gen_valid = int_fm_dllp_gen_valid_r;
end : req_ack_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n)
    int_fm_dllp_gen_valid_r <= #TP 1'b0;
  else
    int_fm_dllp_gen_valid_r <= #TP int_fm_dllp_gen_valid;
end

// This DLLP interface is active in both Flit mode and non-Flit mode
always_comb begin : vendor_dllp_mux_PROC
  xdlh_dllp_if_other_msg_request = '0;
  xdlh_dllp_if_fm_other_msg_request.pyld = cfg_other_msg_request.pyld;
  xdlh_dllp_if_fm_other_msg_request.dllp_type = NOP_DLLP;
  xdlh_dllp_if_fm_other_msg_request.valid = '0;
  if(flit_mode) begin
    // Send Vendor Specific DLLP when DL_Active and no Eq pending
    if(xdlh_dl_active && !smlh_eq_pending) begin
      xdlh_dllp_if_fm_other_msg_request.valid = int_fm_dllp_gen_valid || int_fm_dllp_gen_valid_r;
      xdlh_dllp_if_fm_other_msg_request.dllp_type = cfg_other_msg_request.dllp_type;
    end else begin
      xdlh_dllp_if_fm_other_msg_request.valid = '0;
      xdlh_dllp_if_fm_other_msg_request.dllp_type = NOP_DLLP;
    end
  end else begin
    xdlh_dllp_if_other_msg_request = cfg_other_msg_request;
  end
end : vendor_dllp_mux_PROC

// -------------------------------------------------------------------------------------
// FC DLLP Interface
// -------------------------------------------------------------------------------------
// The FC DLLP Interface is active in both Flit mode and non-Flit mode.
// Certain signals are only used in one mode or the other.
always_comb begin : fc_dllp_mux_PROC
  xdlh_dllp_if_fc_req = '0;
  xdlh_dllp_if_fm_fc_req = '0;
  xdlh_dllp_if_fm_fc_req.dllp_type = NOP_DLLP;
  xdlh_dllp_if_fm_opt_upd = 1'b0;
  xdlh_dllp_if_fc_req_low = 1'b0;
  xdlh_dllp_if_fc_ack = 1'b0;
  if(flit_mode) begin
    // Send FC DLLP when DL is not inactive (e.g. DL_Init)
    xdlh_dllp_if_fm_fc_req.valid = !xdlh_block_dl_init ? rtlh_xdlh_fc_req : 1'b0;
    if(xdlh_dllp_if_fm_fc_req.valid) begin
      xdlh_dllp_if_fm_fc_req.dllp_type = dllp_type_e'(rtlh_xdlh_fc_data[7 : 0]);
      xdlh_dllp_if_fm_fc_req.pyld = rtlh_xdlh_fc_data[31 : 8];
      xdlh_dllp_if_fm_opt_upd = rtlh_xdlh_opt_upd;
    end
    xdlh_dllp_if_fc_ack = xdlh_fm_dllp_gen_fc_ack;
  end else begin
    xdlh_dllp_if_fc_req.valid = rtlh_xdlh_fc_req;
    xdlh_dllp_if_fc_req.dllp_type = dllp_type_e'(rtlh_xdlh_fc_data[7 : 0]);
    xdlh_dllp_if_fc_req.pyld = rtlh_xdlh_fc_data[31 : 8];
    xdlh_dllp_if_fc_req_low = rtlh_xdlh_fc_req_low;
    xdlh_dllp_if_fc_ack = xdlh_dllp_gen_fc_ack;
  end
end : fc_dllp_mux_PROC

// -------------------------------------------------------------------------------------
// PM DLLP Interface
// -------------------------------------------------------------------------------------
// The PM DLLP Interface is Active in both Flit Mode and non-Flit Mode
always_comb begin : pm_dllp_mux_PROC
  xdlh_dllp_if_pm_dllp = '0;
  xdlh_dllp_if_fm_pm_dllp = '0;
  xdlh_dllp_if_fm_pm_dllp.dllp_type = NOP_DLLP;
  xdlh_dllp_if_pm_ack = 1'b0;
  if(flit_mode) begin
    // Send PM DLLP when DL_Active and no Eq pending
    if(!smlh_eq_pending && xdlh_dl_active) begin
      xdlh_dllp_if_fm_pm_dllp = pm_xdlh_dllp;
    end else begin
      xdlh_dllp_if_fm_pm_dllp = '0;
      xdlh_dllp_if_fm_pm_dllp.dllp_type = NOP_DLLP;
    end
    xdlh_dllp_if_pm_ack = xdlh_fm_dllp_gen_pm_ack;
  end else begin
    xdlh_dllp_if_pm_dllp = pm_xdlh_dllp;
    xdlh_dllp_if_pm_ack = xdlh_dllp_gen_pm_ack;
  end
end : pm_dllp_mux_PROC

// -------------------------------------------------------------------------------------
// DL FEATURE DLLP Interface
// -------------------------------------------------------------------------------------
// DL Feature Interface is active in both modes
always_comb begin : feature_dllp_mux_PROC
  xdlh_dllp_if_fm_feature_dllp = '0;
  xdlh_dllp_if_fm_feature_dllp.dllp_type = NOP_DLLP;
  xdlh_dllp_if_feature_ack = '0;
  if(flit_mode) begin
    xdlh_dllp_if_feature_ack = xdlh_fm_dllp_gen_feature_ack;
    // Send the Feature DLLP in DL_Feature state
    if(send_feature_dllp) begin
      xdlh_dllp_if_fm_feature_dllp.dllp_type = DATA_LINK_FEATURE;
      xdlh_dllp_if_fm_feature_dllp.pyld = {cfg_local_feature_support[7:0], cfg_local_feature_support[15:8], cfg_dlink_feature_valid, cfg_local_feature_support[22:16]};
      xdlh_dllp_if_fm_feature_dllp.valid = 1'b1;
    end
  end
end : feature_dllp_mux_PROC

endmodule
