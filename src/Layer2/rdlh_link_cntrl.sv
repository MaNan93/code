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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/rdlh_link_cntrl.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Data Link Layer Handler Link Control
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rdlh_link_cntrl(
    core_clk,
    core_rst_n,
    smlh_link_up,
    cfg_dll_lnk_en,
    rtlh_fci_done,
    rtlh_fci1_fci2,
    init_fc1_rcvd,
    dl_feature_en,
    cfg_remote_feature_ack,
    dl_feature_abort,

// outputs
    rdlh_link_up,
    rdlh_link_down,
    rdlh_dlcntrl_state
    ,
    rdlh_vc0_initfc1_status,
    rdlh_vc0_initfc2_status
    ,
    send_feature_dllp
    ,
    xdlh_rdlh_feature_ack
);
parameter   INST    = 0;                            // The uniquifying parameter for each port logic instance.
parameter   TP      = `TP;                          // Clock to Q delay (simulator insurance)
parameter   NW      = `CX_NW;                       // Number of 32-bit dwords handled by the datapath each clock.
parameter   RX_NDLLP = `CX_RX_NDLLP;                // Max number of DLLPs received per cycle

// =============================================================
// Parameters
// =============================================================
// The State variable encoding is moved to the include file since other
// blocks shared some of these parameters
// parameter S_DL_INACTIVE = 2'b00;
// parameter S_DL_FC_INIT  = 2'b01;
// parameter S_DL_ACTIVE   = 2'b11;
//
// Updated for Gen4.07 support
// parameter S_DL_FEATURE  = 2'b10

// =============================================================
// Inputs
// =============================================================
input           core_clk;
input           core_rst_n;
input           smlh_link_up;               // MAC layer link up
input           cfg_dll_lnk_en;             // software enable link
input           rtlh_fci_done;              // FC init done indication
input           rtlh_fci1_fci2;             // FC init1 and 2 state
input           dl_feature_en;              // indicates Data Link Features supported
input           cfg_remote_feature_ack;     // Indicates remote Data Link Features handshake completed
input           init_fc1_rcvd;              // Any INITFC1 has been received
input           dl_feature_abort;           // Abort dl feature if an MR-IOV is received to avoid deadlock
input           xdlh_rdlh_feature_ack;      // DL Feature DLLP Has been sent in Flit

// =============================================================
// Outputs
// =============================================================
output          rdlh_link_up;               // indicates link is up to receive fc2 pkt or fc update or tlps
output          rdlh_link_down;             // indicates link is in the inactive state
output  [1:0]   rdlh_dlcntrl_state;         // data link layer link status
output          send_feature_dllp;          // Transmit Feature DLLP
output          rdlh_vc0_initfc1_status;    // Level : VC0 Init-FC1 status for Ras D.E.S Silicon Debug
output          rdlh_vc0_initfc2_status;    // Level : VC0 Init-FC2 status for Ras D.E.S Silicon Debug 

// =============================================================
// IO Declaration
// =============================================================
// Register Outputs
reg             rdlh_link_up;
reg             rdlh_link_down;
reg    [1:0]    rdlh_dlcntrl_state;
wire            rdlh_vc0_initfc1_status;
wire            rdlh_vc0_initfc2_status;

// Registers
reg             r_rdlh_link_up;
reg             r_rdlh_link_down;
reg    [1:0]    r_rdlh_dlcntrl_state;

reg             send_feature_dllp;
reg             r_send_feature_dllp;


always@(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        r_rdlh_dlcntrl_state                <= #TP `S_DL_INACTIVE;
        r_rdlh_link_up                      <= #TP 1'b0;
        r_rdlh_link_down                    <= #TP 1'b1;
        r_send_feature_dllp                 <= #TP 1'b0;
    end else
        case (rdlh_dlcntrl_state)
            `S_DL_INACTIVE: begin
                r_rdlh_link_up              <= #TP 1'b0;
                r_rdlh_link_down            <= #TP 1'b1;
                r_send_feature_dllp         <= #TP 1'b0;
                if(smlh_link_up & cfg_dll_lnk_en & dl_feature_en)
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_FEATURE;
                else if(smlh_link_up & cfg_dll_lnk_en & (!dl_feature_en))
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_FC_INIT;
                else
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_INACTIVE;
            end
            `S_DL_FEATURE: begin
                r_rdlh_link_up              <= #TP 1'b0;
                r_rdlh_link_down            <= #TP 1'b1;
                r_send_feature_dllp         <= #TP 1'b1;
                if(!smlh_link_up)
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_INACTIVE;
                else if(cfg_remote_feature_ack | init_fc1_rcvd | dl_feature_abort & xdlh_rdlh_feature_ack)
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_FC_INIT;
                else
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_FEATURE;
            end
            `S_DL_FC_INIT: begin
                r_rdlh_link_up              <= #TP rtlh_fci1_fci2;
                r_rdlh_link_down            <= #TP 1'b0;
                r_send_feature_dllp         <= #TP 1'b0;
                if(!smlh_link_up)
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_INACTIVE;
                else if(rtlh_fci_done)
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_ACTIVE;
                else
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_FC_INIT;
            end

            `S_DL_ACTIVE : begin
                r_rdlh_link_up              <= #TP 1'b1;
                r_rdlh_link_down            <= #TP 1'b0;
                if(!smlh_link_up)
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_INACTIVE;
                else
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_ACTIVE;
            end

// mapping S_DL_INACTIVE to default state to facilitate code coverage
            default: begin
                if (smlh_link_up)
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_ACTIVE;
                else
                    r_rdlh_dlcntrl_state    <= #TP `S_DL_INACTIVE;
            end

        endcase
   end


assign rdlh_vc0_initfc1_status = (rdlh_dlcntrl_state == `S_DL_FC_INIT) & !rtlh_fci1_fci2;
assign rdlh_vc0_initfc2_status = (rdlh_dlcntrl_state == `S_DL_FC_INIT) & rtlh_fci1_fci2;
// Outputs
always @(*) begin : OUTPUTS
  rdlh_link_up          = r_rdlh_link_up;
  rdlh_link_down        = r_rdlh_link_down;
  rdlh_dlcntrl_state    = r_rdlh_dlcntrl_state;
  send_feature_dllp     = r_send_feature_dllp;

end

endmodule
