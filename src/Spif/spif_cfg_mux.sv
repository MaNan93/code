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

// -----------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2024/01/10 14:23:51 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Spif/spif_cfg_mux.sv#2 $
// -----------------------------------------------------------------------------
// --- Module Description: SPIF.CFG Multiplexer
// -----------------------------------------------------------------------------
// --- The SPIF.CFG Multiplexer module allows the routing of Register Access
// --- Request Packets from SPIF.CFG Completer to different SPIF.CFG Requesters
// --- and the forwarding of all Register Access Completion Packets back to
// --- SPIF.CFG Completer.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module spif_cfg_mux #(
  parameter MP_SPIF_NCFG = 32 // Width of SPIF Configuration Interface data (*_cfg_data)
  )
  (
  // Inputs
  input  wire                    core_clk              , // Clock
  input  wire                    core_rst_n            , // Asynchronous Reset
  // SPIF.CFG Interface (Completer Interface / Upstream Port)
  input  wire                    ispif_lp_cfg_vld_cpl  , // SPIF.CFG Interface Valid Signal (Request Packet)
  input  wire [MP_SPIF_NCFG-1:0] ispif_lp_cfg_data_cpl , // SPIF.CFG Interface Data Signal  (Request Packet)
  output wire                    ospif_pl_cfg_vld_cpl  , // SPIF.CFG Interface Valid Signal (Completion Packet)
  output wire [MP_SPIF_NCFG-1:0] ospif_pl_cfg_data_cpl , // SPIF.CFG Interface Data         (Completion Packet)
  // SPIF.CFG Interface (Requester Interface 0)
  input  wire                    ispif_pl_cfg_vld_req0 , // SPIF.CFG Interface Valid Signal (Completion Packet)
  input  wire [MP_SPIF_NCFG-1:0] ispif_pl_cfg_data_req0, // SPIF.CFG Interface Data Signal  (Completion Packet)
  output wire                    ospif_lp_cfg_vld_req0 , // SPIF.CFG Interface Valid Signal (Request Packet)
  output wire [MP_SPIF_NCFG-1:0] ospif_lp_cfg_data_req0, // SPIF.CFG Interface Data         (Request Packet)
  // SPIF.CFG Interface (Requester Interface 1)
  input  wire                    ispif_pl_cfg_vld_req1 , // SPIF.CFG Interface Valid Signal (Completion Packet)
  input  wire [MP_SPIF_NCFG-1:0] ispif_pl_cfg_data_req1, // SPIF.CFG Interface Data Signal  (Completion Packet)
  output wire                    ospif_lp_cfg_vld_req1 , // SPIF.CFG Interface Valid Signal (Request Packet)
  output wire [MP_SPIF_NCFG-1:0] ospif_lp_cfg_data_req1, // SPIF.CFG Interface Data         (Request Packet)
  // SPIF.CFG Interface (Requester Interface 2)
  input  wire                    ispif_pl_cfg_vld_req2 , // SPIF.CFG Interface Valid Signal (Completion Packet)
  input  wire [MP_SPIF_NCFG-1:0] ispif_pl_cfg_data_req2, // SPIF.CFG Interface Data Signal  (Completion Packet)
  output wire                    ospif_lp_cfg_vld_req2 , // SPIF.CFG Interface Valid Signal (Request Packet)
  output wire [MP_SPIF_NCFG-1:0] ospif_lp_cfg_data_req2  // SPIF.CFG Interface Data         (Request Packet)
  );

  // Localparameter declaration ********************************************************************************************************************************
  localparam TP = `TP;

  localparam LP_DSTID_PCIE = 2'b00;
  localparam LP_DSTID_CXL  = 2'b01;
  localparam LP_DSTID_UCIE = 2'b10;

  // Signal declaration ****************************************************************************************************************************************
  integer                 vidx;
  reg               [4:0] rspif_req_pkt_dstid;
  wire              [4:0] wspif_req_pkt_dstid_mux;

  wire                    wspif_req_pkt_mux_req0_active;
  wire                    wspif_req_pkt_mux_req1_active;
  wire                    wspif_req_pkt_mux_req2_active;

  wire              [4:0] wspif_req_pkt_opcode;
  wire                    wspif_req_pkt_ep;
  wire                    wspif_req_pkt_fw;
  wire                    wspif_req_pkt_sh;
  wire              [7:0] wspif_req_pkt_be;
  wire              [4:0] wspif_req_pkt_tag;
  wire              [4:0] wspif_req_pkt_dstid;
  wire             [28:0] wspif_req_pkt_addr;
  wire                    wspif_req_pkt_vf;
  wire                    wspif_req_pkt_cp;
  wire                    wspif_req_pkt_dp;
  wire [MP_SPIF_NCFG-1:0] wspif_req_pkt_data;
  wire                    wspif_req_pkt_hv_p;
  wire                    wspif_req_pkt_dv;
  wire                    wspif_req_pkt_eot_p;

  wire                    wspif_req_pkt_hv_p_req0;
  wire                    wspif_req_pkt_dv_req0;
  wire                    wspif_req_pkt_eot_p_req0;

  wire                    wspif_req_pkt_hv_p_req1;
  wire                    wspif_req_pkt_dv_req1;
  wire                    wspif_req_pkt_eot_p_req1;

  wire                    wspif_req_pkt_hv_p_req2;
  wire                    wspif_req_pkt_dv_req2;
  wire                    wspif_req_pkt_eot_p_req2;

  reg               [1:0] rspif_cpl_pkt_mux_sel;

  reg               [4:0] wspif_cpl_pkt_tag;
  reg               [1:0] wspif_cpl_pkt_len;
  reg                     wspif_cpl_pkt_dp;
  reg                     wspif_cpl_pkt_cp;
  reg                     wspif_cpl_pkt_ep;
  reg               [2:0] wspif_cpl_pkt_status;
  reg  [MP_SPIF_NCFG-1:0] wspif_cpl_pkt_data;
  reg                     wspif_cpl_pkt_hv_p;
  reg                     wspif_cpl_pkt_dv;
  reg                     wspif_cpl_pkt_eot_p;

  wire              [4:0] wspif_cpl_pkt_tag_req0;
  wire              [1:0] wspif_cpl_pkt_len_req0;
  wire                    wspif_cpl_pkt_dp_req0;
  wire                    wspif_cpl_pkt_cp_req0;
  wire                    wspif_cpl_pkt_ep_req0;
  wire              [2:0] wspif_cpl_pkt_status_req0;
  wire [MP_SPIF_NCFG-1:0] wspif_cpl_pkt_data_req0;
  wire                    wspif_cpl_pkt_hv_p_req0;
  wire                    wspif_cpl_pkt_dv_req0;
  wire                    wspif_cpl_pkt_eot_p_req0;

  wire              [4:0] wspif_cpl_pkt_tag_req1;
  wire              [1:0] wspif_cpl_pkt_len_req1;
  wire                    wspif_cpl_pkt_dp_req1;
  wire                    wspif_cpl_pkt_cp_req1;
  wire                    wspif_cpl_pkt_ep_req1;
  wire              [2:0] wspif_cpl_pkt_status_req1;
  wire [MP_SPIF_NCFG-1:0] wspif_cpl_pkt_data_req1;
  wire                    wspif_cpl_pkt_hv_p_req1;
  wire                    wspif_cpl_pkt_dv_req1;
  wire                    wspif_cpl_pkt_eot_p_req1;

  wire              [4:0] wspif_cpl_pkt_tag_req2;
  wire              [1:0] wspif_cpl_pkt_len_req2;
  wire                    wspif_cpl_pkt_dp_req2;
  wire                    wspif_cpl_pkt_cp_req2;
  wire                    wspif_cpl_pkt_ep_req2;
  wire              [2:0] wspif_cpl_pkt_status_req2;
  wire [MP_SPIF_NCFG-1:0] wspif_cpl_pkt_data_req2;
  wire                    wspif_cpl_pkt_hv_p_req2;
  wire                    wspif_cpl_pkt_dv_req2;
  wire                    wspif_cpl_pkt_eot_p_req2;

  //************************************************************************************************************************************************************
  // Completer Interface (Upstream Port)
  //************************************************************************************************************************************************************

  spif_cfg_if_completer
   #(
    .MP_SPIF_NCFG (MP_SPIF_NCFG) // Data Width
    )
    u_spif_cfg_if_completer(
      .core_clk              (core_clk              ),
      .core_rst_n            (core_rst_n            ),
      // SPIF.CFG Interface (Completer Interface / Upstream Port)
      .ispif_lp_cfg_vld      (ispif_lp_cfg_vld_cpl  ),
      .ispif_lp_cfg_data     (ispif_lp_cfg_data_cpl ),
      .ospif_pl_cfg_vld      (ospif_pl_cfg_vld_cpl  ),
      .ospif_pl_cfg_data     (ospif_pl_cfg_data_cpl ),
      // Completion Packet Fields
      .ispif_cpl_pkt_tag     (wspif_cpl_pkt_tag     ),
      .ispif_cpl_pkt_len     (wspif_cpl_pkt_len     ),
      .ispif_cpl_pkt_dp      (wspif_cpl_pkt_dp      ),
      .ispif_cpl_pkt_cp      (wspif_cpl_pkt_cp      ),
      .ispif_cpl_pkt_ep      (wspif_cpl_pkt_ep      ),
      .ispif_cpl_pkt_status  (wspif_cpl_pkt_status  ),
      .ispif_cpl_pkt_data    (wspif_cpl_pkt_data    ),
      // Completion Packet Control Flags
      .ispif_cpl_pkt_hv_p    (wspif_cpl_pkt_hv_p    ),
      .ispif_cpl_pkt_dv      (wspif_cpl_pkt_dv      ),
      .ispif_cpl_pkt_eot_p   (wspif_cpl_pkt_eot_p   ),
      // Request Packet Fields
      .ospif_req_pkt_opcode  (wspif_req_pkt_opcode  ),
      .ospif_req_pkt_ep      (wspif_req_pkt_ep      ),
      .ospif_req_pkt_fw      (wspif_req_pkt_fw      ),
      .ospif_req_pkt_sh      (wspif_req_pkt_sh      ),
      .ospif_req_pkt_be      (wspif_req_pkt_be      ),
      .ospif_req_pkt_tag     (wspif_req_pkt_tag     ),
      .ospif_req_pkt_dstid   (wspif_req_pkt_dstid   ),
      .ospif_req_pkt_addr    (wspif_req_pkt_addr    ),
      .ospif_req_pkt_vf      (wspif_req_pkt_vf      ),
      .ospif_req_pkt_cp      (wspif_req_pkt_cp      ),
      .ospif_req_pkt_dp      (wspif_req_pkt_dp      ),
      .ospif_req_pkt_data    (wspif_req_pkt_data    ),
      // Request Packet Control Flags
      .ospif_req_pkt_hv_p    (wspif_req_pkt_hv_p    ),
      .ospif_req_pkt_dv      (wspif_req_pkt_dv      ),
      .ospif_req_pkt_eot_p   (wspif_req_pkt_eot_p   )
    );

  //************************************************************************************************************************************************************
  // Request Packet Multiplexer
  //************************************************************************************************************************************************************

  // Sample the DSTID field (used for Packet Muxing)
  always @(posedge core_clk or negedge core_rst_n) begin : sspif_req_pkt_dstid_PROC
    if (!core_rst_n) begin
      rspif_req_pkt_dstid <= #TP  5'd0;
    end else begin
      if (wspif_req_pkt_hv_p) begin
        rspif_req_pkt_dstid <= #TP wspif_req_pkt_dstid;
      end
    end
  end // sspif_req_pkt_dstid_PROC

  // Get the DSTID combinational and sequential
  assign wspif_req_pkt_dstid_mux = wspif_req_pkt_hv_p ? wspif_req_pkt_dstid : rspif_req_pkt_dstid;

  // Request Packet Multiplexer
  assign wspif_req_pkt_mux_req0_active = (wspif_req_pkt_dstid_mux[4:3] == LP_DSTID_PCIE);
  assign wspif_req_pkt_mux_req1_active = (wspif_req_pkt_dstid_mux[4:3] == LP_DSTID_CXL );
  assign wspif_req_pkt_mux_req2_active = (wspif_req_pkt_dstid_mux[4:3] == LP_DSTID_UCIE);

  assign wspif_req_pkt_hv_p_req0   = wspif_req_pkt_mux_req0_active && wspif_req_pkt_hv_p;
  assign wspif_req_pkt_dv_req0     = wspif_req_pkt_mux_req0_active && wspif_req_pkt_dv;
  assign wspif_req_pkt_eot_p_req0  = wspif_req_pkt_mux_req0_active && wspif_req_pkt_eot_p;

  assign wspif_req_pkt_hv_p_req1   = wspif_req_pkt_mux_req1_active && wspif_req_pkt_hv_p;
  assign wspif_req_pkt_dv_req1     = wspif_req_pkt_mux_req1_active && wspif_req_pkt_dv;
  assign wspif_req_pkt_eot_p_req1  = wspif_req_pkt_mux_req1_active && wspif_req_pkt_eot_p;

  assign wspif_req_pkt_hv_p_req2   = wspif_req_pkt_mux_req2_active && wspif_req_pkt_hv_p;
  assign wspif_req_pkt_dv_req2     = wspif_req_pkt_mux_req2_active && wspif_req_pkt_dv;
  assign wspif_req_pkt_eot_p_req2  = wspif_req_pkt_mux_req2_active && wspif_req_pkt_eot_p;

  //************************************************************************************************************************************************************
  // Requester Interfaces (Downstream Ports)
  //************************************************************************************************************************************************************

  spif_cfg_if_requester
   #(
    .MP_SPIF_NCFG (MP_SPIF_NCFG), // SPIF.CFG Interface Data Width
    .MP_SPIF_CRD  (1           )  // SPIF.CFG Interface Credits
    )
    u0_spif_cfg_if_requester(
      .core_clk             (core_clk                 ),
      .core_rst_n           (core_rst_n               ),
      // SPIF.CFG Interface
      .ispif_pl_cfg_vld     (ispif_pl_cfg_vld_req0    ),
      .ispif_pl_cfg_data    (ispif_pl_cfg_data_req0   ),
      .ospif_lp_cfg_vld     (ospif_lp_cfg_vld_req0    ),
      .ospif_lp_cfg_data    (ospif_lp_cfg_data_req0   ),
      // Request Packet Fields
      .ispif_req_pkt_opcode (wspif_req_pkt_opcode     ),
      .ispif_req_pkt_ep     (wspif_req_pkt_ep         ),
      .ispif_req_pkt_fw     (wspif_req_pkt_fw         ),
      .ispif_req_pkt_sh     (wspif_req_pkt_sh         ),
      .ispif_req_pkt_be     (wspif_req_pkt_be         ),
      .ispif_req_pkt_tag    (wspif_req_pkt_tag        ),
      .ispif_req_pkt_dstid  (wspif_req_pkt_dstid      ),
      .ispif_req_pkt_addr   (wspif_req_pkt_addr       ),
      .ispif_req_pkt_vf     (wspif_req_pkt_vf         ),
      .ispif_req_pkt_cp     (wspif_req_pkt_cp         ),
      .ispif_req_pkt_dp     (wspif_req_pkt_dp         ),
      .ispif_req_pkt_data   (wspif_req_pkt_data       ),
      // spyglass disable_block UnloadedOutTerm-ML W287b
      // SMD: Detected unloaded(unconnected) output terminal / Instance output port '*' is not connected
      // SJ: Port not connected by design
      .ospif_req_crd_full   (/*UNCONNECTED*/          ),
      // spyglass enable_block UnloadedOutTerm-ML W287b
      // Request Packet Control Flags
      .ispif_req_pkt_hv_p   (wspif_req_pkt_hv_p_req0  ),
      .ispif_req_pkt_dv     (wspif_req_pkt_dv_req0    ),
      .ispif_req_pkt_eot_p  (wspif_req_pkt_eot_p_req0 ),
      // Completion Packet Fields
      .ospif_cpl_pkt_tag    (wspif_cpl_pkt_tag_req0   ),
      .ospif_cpl_pkt_len    (wspif_cpl_pkt_len_req0   ),
      .ospif_cpl_pkt_dp     (wspif_cpl_pkt_dp_req0    ),
      .ospif_cpl_pkt_cp     (wspif_cpl_pkt_cp_req0    ),
      .ospif_cpl_pkt_ep     (wspif_cpl_pkt_ep_req0    ),
      .ospif_cpl_pkt_status (wspif_cpl_pkt_status_req0),
      .ospif_cpl_pkt_data   (wspif_cpl_pkt_data_req0  ),
      // Completion Packet Control Flags
      .ospif_cpl_pkt_hv_p   (wspif_cpl_pkt_hv_p_req0  ),
      .ospif_cpl_pkt_dv     (wspif_cpl_pkt_dv_req0    ),
      .ospif_cpl_pkt_eot_p  (wspif_cpl_pkt_eot_p_req0 )
    );

  spif_cfg_if_requester
   #(
    .MP_SPIF_NCFG (MP_SPIF_NCFG), // SPIF.CFG Interface Data Width
    .MP_SPIF_CRD  (1           )  // SPIF.CFG Interface Credits
    )
    u1_spif_cfg_if_requester(
      .core_clk             (core_clk                 ),
      .core_rst_n           (core_rst_n               ),
      // SPIF.CFG Interface
      .ispif_pl_cfg_vld     (ispif_pl_cfg_vld_req1    ),
      .ispif_pl_cfg_data    (ispif_pl_cfg_data_req1   ),
      .ospif_lp_cfg_vld     (ospif_lp_cfg_vld_req1    ),
      .ospif_lp_cfg_data    (ospif_lp_cfg_data_req1   ),
      // Request Packet Fields
      .ispif_req_pkt_opcode (wspif_req_pkt_opcode     ),
      .ispif_req_pkt_ep     (wspif_req_pkt_ep         ),
      .ispif_req_pkt_fw     (wspif_req_pkt_fw         ),
      .ispif_req_pkt_sh     (wspif_req_pkt_sh         ),
      .ispif_req_pkt_be     (wspif_req_pkt_be         ),
      .ispif_req_pkt_tag    (wspif_req_pkt_tag        ),
      .ispif_req_pkt_dstid  (wspif_req_pkt_dstid      ),
      .ispif_req_pkt_addr   (wspif_req_pkt_addr       ),
      .ispif_req_pkt_vf     (wspif_req_pkt_vf         ),
      .ispif_req_pkt_cp     (wspif_req_pkt_cp         ),
      .ispif_req_pkt_dp     (wspif_req_pkt_dp         ),
      .ispif_req_pkt_data   (wspif_req_pkt_data       ),
      // spyglass disable_block UnloadedOutTerm-ML W287b
      // SMD: Detected unloaded(unconnected) output terminal / Instance output port '*' is not connected
      // SJ: Port not connected by design
      .ospif_req_crd_full   (/*UNCONNECTED*/          ),
      // spyglass enable_block UnloadedOutTerm-ML W287b
      // Request Packet Control Flags
      .ispif_req_pkt_hv_p   (wspif_req_pkt_hv_p_req1  ),
      .ispif_req_pkt_dv     (wspif_req_pkt_dv_req1    ),
      .ispif_req_pkt_eot_p  (wspif_req_pkt_eot_p_req1 ),
      // Completion Packet Fields
      .ospif_cpl_pkt_tag    (wspif_cpl_pkt_tag_req1   ),
      .ospif_cpl_pkt_len    (wspif_cpl_pkt_len_req1   ),
      .ospif_cpl_pkt_dp     (wspif_cpl_pkt_dp_req1    ),
      .ospif_cpl_pkt_cp     (wspif_cpl_pkt_cp_req1    ),
      .ospif_cpl_pkt_ep     (wspif_cpl_pkt_ep_req1    ),
      .ospif_cpl_pkt_status (wspif_cpl_pkt_status_req1),
      .ospif_cpl_pkt_data   (wspif_cpl_pkt_data_req1  ),
      // Completion Packet Control Flags
      .ospif_cpl_pkt_hv_p   (wspif_cpl_pkt_hv_p_req1  ),
      .ospif_cpl_pkt_dv     (wspif_cpl_pkt_dv_req1    ),
      .ospif_cpl_pkt_eot_p  (wspif_cpl_pkt_eot_p_req1 )
    );

  spif_cfg_if_requester
   #(
    .MP_SPIF_NCFG (MP_SPIF_NCFG), // SPIF.CFG Interface Data Width
    .MP_SPIF_CRD  (1           )  // SPIF.CFG Interface Credits
    )
    u2_spif_cfg_if_requester(
      .core_clk             (core_clk                 ),
      .core_rst_n           (core_rst_n               ),
      // SPIF.CFG Interface
      .ispif_pl_cfg_vld     (ispif_pl_cfg_vld_req2    ),
      .ispif_pl_cfg_data    (ispif_pl_cfg_data_req2   ),
      .ospif_lp_cfg_vld     (ospif_lp_cfg_vld_req2    ),
      .ospif_lp_cfg_data    (ospif_lp_cfg_data_req2   ),
      // Request Packet Fields
      .ispif_req_pkt_opcode (wspif_req_pkt_opcode     ),
      .ispif_req_pkt_ep     (wspif_req_pkt_ep         ),
      .ispif_req_pkt_fw     (wspif_req_pkt_fw         ),
      .ispif_req_pkt_sh     (wspif_req_pkt_sh         ),
      .ispif_req_pkt_be     (wspif_req_pkt_be         ),
      .ispif_req_pkt_tag    (wspif_req_pkt_tag        ),
      .ispif_req_pkt_dstid  (wspif_req_pkt_dstid      ),
      .ispif_req_pkt_addr   (wspif_req_pkt_addr       ),
      .ispif_req_pkt_vf     (wspif_req_pkt_vf         ),
      .ispif_req_pkt_cp     (wspif_req_pkt_cp         ),
      .ispif_req_pkt_dp     (wspif_req_pkt_dp         ),
      .ispif_req_pkt_data   (wspif_req_pkt_data       ),
      // spyglass disable_block UnloadedOutTerm-ML W287b
      // SMD: Detected unloaded(unconnected) output terminal / Instance output port '*' is not connected
      // SJ: Port not connected by design
      .ospif_req_crd_full   (/*UNCONNECTED*/          ),
      // spyglass enable_block UnloadedOutTerm-ML W287b
      // Request Packet Control Flags
      .ispif_req_pkt_hv_p   (wspif_req_pkt_hv_p_req2  ),
      .ispif_req_pkt_dv     (wspif_req_pkt_dv_req2    ),
      .ispif_req_pkt_eot_p  (wspif_req_pkt_eot_p_req2 ),
      // Completion Packet Fields
      .ospif_cpl_pkt_tag    (wspif_cpl_pkt_tag_req2   ),
      .ospif_cpl_pkt_len    (wspif_cpl_pkt_len_req2   ),
      .ospif_cpl_pkt_dp     (wspif_cpl_pkt_dp_req2    ),
      .ospif_cpl_pkt_cp     (wspif_cpl_pkt_cp_req2    ),
      .ospif_cpl_pkt_ep     (wspif_cpl_pkt_ep_req2    ),
      .ospif_cpl_pkt_status (wspif_cpl_pkt_status_req2),
      .ospif_cpl_pkt_data   (wspif_cpl_pkt_data_req2  ),
      // Completion Packet Control Flags
      .ospif_cpl_pkt_hv_p   (wspif_cpl_pkt_hv_p_req2  ),
      .ospif_cpl_pkt_dv     (wspif_cpl_pkt_dv_req2    ),
      .ospif_cpl_pkt_eot_p  (wspif_cpl_pkt_eot_p_req2 )
    );

  //************************************************************************************************************************************************************
  // Completion Packet Multiplexer
  //************************************************************************************************************************************************************

   wire wspif_cpl_pkt_active;
   wire [1:0] wspif_cpl_pkt_mux;
   wire [1:0] wspif_cpl_pkt_mux_sel;

  assign wspif_cpl_pkt_active = wspif_cpl_pkt_hv_p_req0 || wspif_cpl_pkt_hv_p_req1 || wspif_cpl_pkt_hv_p_req2;

  // Get which interface is active
  always @(posedge core_clk or negedge core_rst_n) begin : sspif_cpl_pkt_mux_PROC
    if (!core_rst_n) begin
      rspif_cpl_pkt_mux_sel <= #TP 2'd0;
    end else begin
      if (wspif_cpl_pkt_active) begin
        rspif_cpl_pkt_mux_sel <= #TP wspif_cpl_pkt_mux_sel;
      end
    end
  end // sspif_cpl_pkt_mux_PROC

  assign wspif_cpl_pkt_mux_sel = wspif_cpl_pkt_hv_p_req0 ? LP_DSTID_PCIE :
                                 wspif_cpl_pkt_hv_p_req1 ? LP_DSTID_CXL  :
                                 wspif_cpl_pkt_hv_p_req2 ? LP_DSTID_UCIE :
                                                           2'b00         ;

  // Get the MUX Selector combitional and sequential
  assign wspif_cpl_pkt_mux = wspif_cpl_pkt_active ? wspif_cpl_pkt_mux_sel : rspif_cpl_pkt_mux_sel;

  assign wspif_cpl_pkt_tag     = (wspif_cpl_pkt_mux == LP_DSTID_PCIE) ? wspif_cpl_pkt_tag_req0    :
                                 (wspif_cpl_pkt_mux == LP_DSTID_CXL ) ? wspif_cpl_pkt_tag_req1    :
                                 (wspif_cpl_pkt_mux == LP_DSTID_UCIE) ? wspif_cpl_pkt_tag_req2    :
                                                                        5'b00000                  ;
  assign wspif_cpl_pkt_len     = (wspif_cpl_pkt_mux == LP_DSTID_PCIE) ? wspif_cpl_pkt_len_req0    :
                                 (wspif_cpl_pkt_mux == LP_DSTID_CXL ) ? wspif_cpl_pkt_len_req1    :
                                 (wspif_cpl_pkt_mux == LP_DSTID_UCIE) ? wspif_cpl_pkt_len_req2    :
                                                                        2'b00                     ;
  assign wspif_cpl_pkt_dp      = (wspif_cpl_pkt_mux == LP_DSTID_PCIE) ? wspif_cpl_pkt_dp_req0     :
                                 (wspif_cpl_pkt_mux == LP_DSTID_CXL ) ? wspif_cpl_pkt_dp_req1     :
                                 (wspif_cpl_pkt_mux == LP_DSTID_UCIE) ? wspif_cpl_pkt_dp_req2     :
                                                                        1'b0                      ;
  assign wspif_cpl_pkt_cp      = (wspif_cpl_pkt_mux == LP_DSTID_PCIE) ? wspif_cpl_pkt_cp_req0     :
                                 (wspif_cpl_pkt_mux == LP_DSTID_CXL ) ? wspif_cpl_pkt_cp_req1     :
                                 (wspif_cpl_pkt_mux == LP_DSTID_UCIE) ? wspif_cpl_pkt_cp_req2     :
                                                                        1'b0                      ;
  assign wspif_cpl_pkt_ep      = (wspif_cpl_pkt_mux == LP_DSTID_PCIE) ? wspif_cpl_pkt_ep_req0     :
                                 (wspif_cpl_pkt_mux == LP_DSTID_CXL ) ? wspif_cpl_pkt_ep_req1     :
                                 (wspif_cpl_pkt_mux == LP_DSTID_UCIE) ? wspif_cpl_pkt_ep_req2     :
                                                                        1'b0                      ;
  assign wspif_cpl_pkt_status  = (wspif_cpl_pkt_mux == LP_DSTID_PCIE) ? wspif_cpl_pkt_status_req0 :
                                 (wspif_cpl_pkt_mux == LP_DSTID_CXL ) ? wspif_cpl_pkt_status_req1 :
                                 (wspif_cpl_pkt_mux == LP_DSTID_UCIE) ? wspif_cpl_pkt_status_req2 :
                                                                        1'b0                      ;
  assign wspif_cpl_pkt_data    = (wspif_cpl_pkt_mux == LP_DSTID_PCIE) ? wspif_cpl_pkt_data_req0   :
                                 (wspif_cpl_pkt_mux == LP_DSTID_CXL ) ? wspif_cpl_pkt_data_req1   :
                                 (wspif_cpl_pkt_mux == LP_DSTID_UCIE) ? wspif_cpl_pkt_data_req2   :
                                                                        1'b0                      ;
  assign wspif_cpl_pkt_hv_p    = (wspif_cpl_pkt_mux == LP_DSTID_PCIE) ? wspif_cpl_pkt_hv_p_req0   :
                                 (wspif_cpl_pkt_mux == LP_DSTID_CXL ) ? wspif_cpl_pkt_hv_p_req1   :
                                 (wspif_cpl_pkt_mux == LP_DSTID_UCIE) ? wspif_cpl_pkt_hv_p_req2   :
                                                                        1'b0                      ;
  assign wspif_cpl_pkt_dv      = (wspif_cpl_pkt_mux == LP_DSTID_PCIE) ? wspif_cpl_pkt_dv_req0     :
                                 (wspif_cpl_pkt_mux == LP_DSTID_CXL ) ? wspif_cpl_pkt_dv_req1     :
                                 (wspif_cpl_pkt_mux == LP_DSTID_UCIE) ? wspif_cpl_pkt_dv_req2     :
                                                                        1'b0                      ;
  assign wspif_cpl_pkt_eot_p   = (wspif_cpl_pkt_mux == LP_DSTID_PCIE) ? wspif_cpl_pkt_eot_p_req0  :
                                 (wspif_cpl_pkt_mux == LP_DSTID_CXL ) ? wspif_cpl_pkt_eot_p_req1  :
                                 (wspif_cpl_pkt_mux == LP_DSTID_UCIE) ? wspif_cpl_pkt_eot_p_req2  :
                                                                        1'b0                      ;

endmodule
