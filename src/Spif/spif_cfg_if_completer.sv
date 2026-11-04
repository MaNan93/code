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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Spif/spif_cfg_if_completer.sv#2 $
// -----------------------------------------------------------------------------
// --- Module Description: SPIF.CFG Interface Completer
// -----------------------------------------------------------------------------
// --- The SPIF.CFG Interface Requester manages the transmission of Completion
// --- Access Request Packet and the reception of Register Access Requester
// --- Packet, both through the SPIF.CFG Interface.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module spif_cfg_if_completer #(
  parameter MP_SPIF_NCFG = 32 // Width of SPIF Configuration Interface data (*_cfg_data)
  )
  (
  // Inputs
  input  wire                    core_clk            , // Clock
  input  wire                    core_rst_n          , // Asynchronous Reset
  // SPIF.CFG Interface (Completer Interface / Upstream Port)
  input  wire                    ispif_lp_cfg_vld    , // SPIF.CFG Interface Valid Signal (Request Packet)
  input  wire [MP_SPIF_NCFG-1:0] ispif_lp_cfg_data   , // SPIF.CFG Interface Data Signal  (Request Packet)
  output wire                    ospif_pl_cfg_vld    , // SPIF.CFG Interface Valid Signal (Completion Packet)
  output wire [MP_SPIF_NCFG-1:0] ospif_pl_cfg_data   , // SPIF.CFG Interface Data         (Completion Packet)
  // Completion Packet Fields
  input  wire              [4:0] ispif_cpl_pkt_tag   , // Header TAG    (Completion Packet)
  input  wire              [1:0] ispif_cpl_pkt_len   , // Header LEN    (Completion Packet)
  input  wire                    ispif_cpl_pkt_dp    , // Header DP     (Completion Packet)
  input  wire                    ispif_cpl_pkt_cp    , // Header CP     (Completion Packet)
  input  wire                    ispif_cpl_pkt_ep    , // Header EP     (Completion Packet)
  input  wire              [2:0] ispif_cpl_pkt_status, // Header STATUS (Completion Packet)
  input  wire [MP_SPIF_NCFG-1:0] ispif_cpl_pkt_data  , // Data Payload  (Completion Packet)
  // Completion Packet Control Flags
  input  wire                    ispif_cpl_pkt_hv_p  , // SPIF.CFG Interface Request Packet Header Valid (Pulse)
  input  wire                    ispif_cpl_pkt_dv    , // SPIF.CFG Interface Request Packet Data Valid
  input  wire                    ispif_cpl_pkt_eot_p , // SPIF.CFG Interface Request End of Transmission (Pulse)
  // Request Packet Fields
  output wire              [4:0] ospif_req_pkt_opcode, // Header OPCODE field (Request Packet)
  output wire                    ospif_req_pkt_ep    , // Header EP field     (Request Packet)
  output wire                    ospif_req_pkt_fw    , // Header FW field     (Request Packet)
  output wire                    ospif_req_pkt_sh    , // Header SH field     (Request Packet)
  output wire              [7:0] ospif_req_pkt_be    , // Header BE field     (Request Packet)
  output wire              [4:0] ospif_req_pkt_tag   , // Header TAG field    (Request Packet)
  output wire              [4:0] ospif_req_pkt_dstid , // Header DSTID field  (Request Packet)
  output wire             [28:0] ospif_req_pkt_addr  , // Header ADDR field   (Request Packet)
  output wire                    ospif_req_pkt_vf    , // Header VF field     (Request Packet)
  output wire                    ospif_req_pkt_cp    , // Header CP field     (Request Packet)
  output wire                    ospif_req_pkt_dp    , // Header DP field     (Request Packet)
  output wire [MP_SPIF_NCFG-1:0] ospif_req_pkt_data  , // Data Payload        (Request Packet)
  // Request Packet Control Flags
  output reg                     ospif_req_pkt_hv_p  , // SPIF.CFG Interface Request Packet Header Valid (Pulse)
  output wire                    ospif_req_pkt_dv    , // SPIF.CFG Interface Request Packet Data Valid
  output wire                    ospif_req_pkt_eot_p   // SPIF.CFG Interface Request End of Transmission (Pulse)
  );

  // Localparameter declaration ********************************************************************************************************************************
  localparam TP = `TP;

  localparam LP_DWORD_PHASES = (MP_SPIF_NCFG ==  8) ? 5'd4 :
                               (MP_SPIF_NCFG == 16) ? 5'd2 :
                               (MP_SPIF_NCFG == 32) ? 5'd1 :
                                                      5'd1 ;

  localparam LP_REQ_PKT_HEADER_PHASES   = LP_DWORD_PHASES * 2; // 2 DWORDs
  localparam LP_REQ_PKT_DATA_32B_PHASES = LP_DWORD_PHASES    ; // 1 DWORD
  localparam LP_REQ_PKT_DATA_64B_PHASES = LP_DWORD_PHASES * 2; // 2 DWORDs

  localparam LP_CPL_PKT_HEADER_PHASES   = LP_DWORD_PHASES    ; // 1 DWORD
  localparam LP_CPL_PKT_DATA_32B_PHASES = LP_DWORD_PHASES    ; // 1 DWORD
  localparam LP_CPL_PKT_DATA_64B_PHASES = LP_DWORD_PHASES * 2; // 2 DWORDs

  // Signal declaration ****************************************************************************************************************************************
  reg                    [4:0] rreq_pkt_phase_cnt;
  wire                         wreq_pkt_new_p;
  reg                          wreq_pkt_header_en;
  wire                         wreq_pkt_header_end_p;
  wire                         wreq_pkt_data_end_p;
  wire                         wreq_pkt_opcode_read;
  wire                         wreq_pkt_opcode_64b;
  reg                    [4:0] rreq_pkt_total_phases;
  reg                   [63:0] rreq_pkt_header_sr;

  reg                    [4:0] rcpl_pkt_phase_cnt;
  reg                    [4:0] wcpl_pkt_total_phases;
  reg                    [4:0] rcpl_pkt_total_phases;
  wire                   [4:0] wcpl_pkt_total_phases_or;
  wire                         wcpl_pkt_sent_p;
  reg                          rcpl_pkt_active;
  wire                         wcpl_pkt_active;
  reg                    [1:0] rcpl_pkt_len;
  wire                   [1:0] wcpl_pkt_len;
  wire      [MP_SPIF_NCFG-1:0] wcpl_pkt_header;
  wire                         wcpl_pkt_header_en;
  wire                  [31:0] wcpl_pkt_header_fields;
  reg  [(31 - MP_SPIF_NCFG):0] rcpl_pkt_header_sr;
  wire                         wcpl_pkt_data_en;
  reg                   [63:0] rcpl_pkt_data_sr;

  //************************************************************************************************************************************************************
  // Register Access Request Packet
  //************************************************************************************************************************************************************

  // Receive Request Packet Phase counter
  always @(posedge core_clk or negedge core_rst_n) begin : sreq_pkt_phase_cnt_PROC
    if (!core_rst_n) begin
      rreq_pkt_phase_cnt <= #TP 5'd0;
    end else begin
      if (ospif_req_pkt_eot_p) begin
        rreq_pkt_phase_cnt <= #TP 5'd0;
      end else begin
        if (ispif_lp_cfg_vld) begin
          rreq_pkt_phase_cnt <= #TP rreq_pkt_phase_cnt + 5'd1;
        end
      end
    end
  end // sreq_pkt_phase_cnt_PROC

  // Control Flags (Request Packet) ****************************************************************************************************************************

  // Flag (Pulse) that marks a new Request Packet in incoming SPIF.CFG Interface
  assign wreq_pkt_new_p = ispif_lp_cfg_vld && (rreq_pkt_phase_cnt == 5'd0);

  // The SPIF.CFG Interface has Header information in the current clock cycle
  assign wreq_pkt_header_en = ispif_lp_cfg_vld && (rreq_pkt_phase_cnt <= (LP_REQ_PKT_HEADER_PHASES - 5'd1));

  // The transmission of Packet Header is over
  assign wreq_pkt_header_end_p = ispif_lp_cfg_vld && (rreq_pkt_phase_cnt == (LP_REQ_PKT_HEADER_PHASES - 5'd1));

  // The transmission of Packet Data is over
  assign wreq_pkt_data_end_p = ispif_lp_cfg_vld && (rreq_pkt_phase_cnt == (rreq_pkt_total_phases - 5'd1)) && (!wreq_pkt_header_end_p);

  // Flags that signals if the incoming Request Packet is a Read Operation
  assign wreq_pkt_opcode_read = (ispif_lp_cfg_data[4:0] == 5'b00000) ||
                                (ispif_lp_cfg_data[4:0] == 5'b00100) ||
                                (ispif_lp_cfg_data[4:0] == 5'b01000) ||
                                (ispif_lp_cfg_data[4:0] == 5'b01100) ;

  // Flags that signals if the incoming Request Packet has 64 bits of payload
  assign wreq_pkt_opcode_64b = (ispif_lp_cfg_data[4:0] == 5'b01001) ||
                               (ispif_lp_cfg_data[4:0] == 5'b01101) ||
                               (ispif_lp_cfg_data[4:0] == 5'b01000) ||
                               (ispif_lp_cfg_data[4:0] == 5'b01100) ;

  // Total Phases (Request Packet) *****************************************************************************************************************************

  // Calculate the Length of Request Packet
  always @(posedge core_clk or negedge core_rst_n) begin : sreq_pkt_len_PROC
    if (!core_rst_n) begin
      rreq_pkt_total_phases <= #TP 5'd0;
    end else begin
      if (wreq_pkt_new_p) begin
        if (wreq_pkt_opcode_read) begin
          // No payload available
          rreq_pkt_total_phases <= #TP LP_REQ_PKT_HEADER_PHASES;
        end else begin
          if (wreq_pkt_opcode_64b) begin
            rreq_pkt_total_phases <= #TP LP_REQ_PKT_DATA_64B_PHASES + LP_REQ_PKT_HEADER_PHASES;
          end else begin
            rreq_pkt_total_phases <= #TP LP_REQ_PKT_DATA_32B_PHASES + LP_REQ_PKT_HEADER_PHASES;
          end
        end
      end else begin
        if (ospif_req_pkt_eot_p) begin
          rreq_pkt_total_phases <= #TP 5'd0;
        end
      end
    end
  end // sreq_pkt_len_PROC

  // Data Store (Request Packet) *******************************************************************************************************************************

  // Shift Register holding the Header received through SPIF.CFG interface
  always @(posedge core_clk or negedge core_rst_n) begin : sreq_pkt_header_PROC
    if (!core_rst_n) begin
      rreq_pkt_header_sr <= #TP 64'd0;
    end else begin
      if (wreq_pkt_header_en) begin
        rreq_pkt_header_sr <= #TP {ispif_lp_cfg_data,rreq_pkt_header_sr[63:MP_SPIF_NCFG]};
      end else begin
        rreq_pkt_header_sr <= #TP 64'd0;
      end
    end
  end // sreq_pkt_header_PROC

  // Output Definition (Request Packet) ************************************************************************************************************************

  always @(posedge core_clk or negedge core_rst_n) begin : sreq_pkt_PROC
    if (!core_rst_n) begin
      ospif_req_pkt_hv_p <= #TP 1'b0;
    end else begin
      ospif_req_pkt_hv_p <= #TP wreq_pkt_header_end_p;
    end
  end // sreq_pkt_PROC

  // Flag (Pulse) that signals that the Header has been received
  assign ospif_req_pkt_dv = ispif_lp_cfg_vld && (rreq_pkt_phase_cnt >= (LP_REQ_PKT_HEADER_PHASES));

  // Flag (Pulse) that signals that the end of transmission
  assign ospif_req_pkt_eot_p = (rreq_pkt_total_phases > LP_REQ_PKT_HEADER_PHASES) ? wreq_pkt_data_end_p : ospif_req_pkt_hv_p;

  // Header Fields assignment
  assign ospif_req_pkt_opcode = rreq_pkt_header_sr[4:0];
  assign ospif_req_pkt_ep     = rreq_pkt_header_sr[5];
  assign ospif_req_pkt_fw     = rreq_pkt_header_sr[6];
  assign ospif_req_pkt_sh     = rreq_pkt_header_sr[7];
  assign ospif_req_pkt_be     = rreq_pkt_header_sr[21:14];
  assign ospif_req_pkt_tag    = rreq_pkt_header_sr[26:22];
  assign ospif_req_pkt_dstid  = rreq_pkt_header_sr[31:27];
  assign ospif_req_pkt_addr   = rreq_pkt_header_sr[60:32];
  assign ospif_req_pkt_vf     = rreq_pkt_header_sr[61];
  assign ospif_req_pkt_cp     = rreq_pkt_header_sr[62];
  assign ospif_req_pkt_dp     = rreq_pkt_header_sr[63];

  // Payload assignment
  assign ospif_req_pkt_data   = {MP_SPIF_NCFG{ospif_req_pkt_dv}} & ispif_lp_cfg_data;

  //************************************************************************************************************************************************************
  // Register Access Completion Packet
  //************************************************************************************************************************************************************

  // Completion Packet Phase counter
  always @(posedge core_clk or negedge core_rst_n) begin : scpl_pkt_phase_cnt_PROC
    if (!core_rst_n) begin
      rcpl_pkt_phase_cnt <= #TP 5'd0;
    end else begin
      if (wcpl_pkt_sent_p) begin
        rcpl_pkt_phase_cnt <= #TP 5'd0;
      end else begin
        if (wcpl_pkt_active) begin
          rcpl_pkt_phase_cnt <= #TP rcpl_pkt_phase_cnt + 5'd1;
        end
      end
    end
  end // scpl_pkt_phase_cnt_PROC

  // Total Phases (Completion Packet) **************************************************************************************************************************

  always @(*) begin : scpl_pkt_total_phases_PROC
    if (ispif_cpl_pkt_hv_p) begin
      case (ispif_cpl_pkt_len)
        2'b00   : wcpl_pkt_total_phases = LP_CPL_PKT_HEADER_PHASES;
        2'b01   : wcpl_pkt_total_phases = LP_CPL_PKT_HEADER_PHASES + LP_CPL_PKT_DATA_32B_PHASES;
        2'b10   : wcpl_pkt_total_phases = LP_CPL_PKT_HEADER_PHASES + LP_CPL_PKT_DATA_64B_PHASES;
        // Default not reachable by SPIF.CFG Specification
        default : wcpl_pkt_total_phases = 5'd1;
      endcase
    end else begin
      wcpl_pkt_total_phases = 5'd0;
    end
  end // scpl_pkt_total_phases_PROC

  always @(posedge core_clk or negedge core_rst_n) begin : ccpl_pkt_total_phases_PROC
    if (!core_rst_n) begin
      rcpl_pkt_total_phases <= #TP 5'd0;
    end else begin
      if (wcpl_pkt_sent_p) begin
        rcpl_pkt_total_phases <= #TP 5'd0;
      end else begin
        if (ispif_cpl_pkt_hv_p) begin
          rcpl_pkt_total_phases <= #TP wcpl_pkt_total_phases;
        end
      end
    end
  end // ccpl_pkt_total_phases_PROC

  assign wcpl_pkt_total_phases_or = wcpl_pkt_total_phases | rcpl_pkt_total_phases;

  // Transmission Active (Completion Packet) *******************************************************************************************************************

  // Completion Packet transmission is ongoing
  always @(posedge core_clk or negedge core_rst_n) begin : scpl_pkt_active_PROC
    if (!core_rst_n) begin
      rcpl_pkt_active <= #TP 1'b0;
    end else begin
      if (wcpl_pkt_sent_p) begin
        rcpl_pkt_active <= #TP 1'b0;
      end else begin
        if (ispif_cpl_pkt_hv_p) begin
          rcpl_pkt_active <= #TP 1'b1;
        end
      end
    end
  end // scpl_pkt_active_PROC

  assign wcpl_pkt_active = ispif_cpl_pkt_hv_p | rcpl_pkt_active;

  // Control Flags (Completion Packet) *************************************************************************************************************************

  // Flag (Pulse) that signals the end of Completion Packet transmission
  assign wcpl_pkt_sent_p = wcpl_pkt_active && (rcpl_pkt_phase_cnt == (wcpl_pkt_total_phases_or - 5'd1));

  // Flag (Pulse) that signals the transmission of Header
  assign wcpl_pkt_header_en = wcpl_pkt_active && (rcpl_pkt_phase_cnt <= (LP_CPL_PKT_HEADER_PHASES - 5'd1));

  // Flag that signals the transmission of Payload
  assign wcpl_pkt_data_en = wcpl_pkt_active && (rcpl_pkt_phase_cnt > (LP_CPL_PKT_HEADER_PHASES - 5'd1));

  // Completion Packet Header definition
  assign wcpl_pkt_header_fields = {5'b00000,              // 5 Bits Reserved
                                   ispif_cpl_pkt_tag,     // Completion Tag
                                   12'b000000000000,      // 12 Bits Reserved
                                   ispif_cpl_pkt_len,     // Length
                                   ispif_cpl_pkt_dp,      // Data Parity
                                   ispif_cpl_pkt_cp,      // CP field
                                   ispif_cpl_pkt_ep,      // Data Poison
                                   2'b00,                 // 2 Bits Reserved
                                   ispif_cpl_pkt_status}; // Status

  always @(posedge core_clk or negedge core_rst_n) begin : scpl_pkt_len_PROC
    if (!core_rst_n) begin
      rcpl_pkt_len <= #TP 2'd0;
    end else begin
      if (ispif_cpl_pkt_hv_p) begin
        rcpl_pkt_len <= #TP ispif_cpl_pkt_len;
      end
    end
  end // scpl_pkt_len_PROC

  assign wcpl_pkt_len = ispif_cpl_pkt_hv_p ? ispif_cpl_pkt_len : rcpl_pkt_len;

  // Data Store (Completion Packet) ****************************************************************************************************************************

  generate
    if (MP_SPIF_NCFG == 32) begin

      // If MP_SPIF_NCFG is set to 32, there is no Shift-Register since the Header uses only 32 bits
      assign wcpl_pkt_header = ispif_cpl_pkt_hv_p ? wcpl_pkt_header_fields : 32'd0;

    end else if (MP_SPIF_NCFG == 16) begin

      // If MP_SPIF_NCFG is set to 16, only the 16 MSB must be sampled
      always @(posedge core_clk or negedge core_rst_n) begin : scpl_pkt_header_sr_PROC
        if (!core_rst_n) begin
          rcpl_pkt_header_sr <= #TP 16'd0;
        end else begin
          if (ispif_cpl_pkt_hv_p) begin
            rcpl_pkt_header_sr <= #TP wcpl_pkt_header_fields[31:16];
          end else begin
            if (ospif_pl_cfg_vld) begin
              rcpl_pkt_header_sr <= #TP 16'd0;
            end
          end
        end
      end // scpl_pkt_header_sr_PROC

      assign wcpl_pkt_header = ispif_cpl_pkt_hv_p ? wcpl_pkt_header_fields[15:0] : rcpl_pkt_header_sr;

    end else begin

      // Shift Register holding the Header received through SPIF.CFG interface
      always @(posedge core_clk or negedge core_rst_n) begin : scpl_pkt_header_sr_PROC
        if (!core_rst_n) begin
          rcpl_pkt_header_sr <= #TP {(32 - MP_SPIF_NCFG){1'b0}};
        end else begin
          if (ispif_cpl_pkt_hv_p) begin
            rcpl_pkt_header_sr <= #TP wcpl_pkt_header_fields[31:MP_SPIF_NCFG];
          end else begin
            if (ospif_pl_cfg_vld) begin
              rcpl_pkt_header_sr <= #TP {{MP_SPIF_NCFG{1'b0}},rcpl_pkt_header_sr[(31 - MP_SPIF_NCFG):MP_SPIF_NCFG]};
            end
          end
        end
      end // scpl_pkt_header_sr_PROC

      assign wcpl_pkt_header = ispif_cpl_pkt_hv_p ? wcpl_pkt_header_fields[MP_SPIF_NCFG-1:0] : rcpl_pkt_header_sr[MP_SPIF_NCFG-1:0];
    end
  endgenerate

  // Shift Register holding the data received through SPIF.CFG interface
  always @(posedge core_clk or negedge core_rst_n) begin : scpl_pkt_data_sr_PROC
    if (!core_rst_n) begin
      rcpl_pkt_data_sr <= #TP 64'd0;
    end else begin
      // Shift Register when receiveing or sending payload data
      if (ispif_cpl_pkt_dv || wcpl_pkt_data_en) begin
        rcpl_pkt_data_sr <= #TP {ispif_cpl_pkt_data,rcpl_pkt_data_sr[63:MP_SPIF_NCFG]};
      end
    end
  end // scpl_pkt_data_sr_PROC

  // Output Definition (Completion Packet) *********************************************************************************************************************

  // Since the header has always one DWORD of lengh, the sample of Packet Data (Payload) is always performed from the same position
  assign ospif_pl_cfg_vld  = wcpl_pkt_active;
  assign ospif_pl_cfg_data = wcpl_pkt_header_en ? wcpl_pkt_header :
                             wcpl_pkt_active    ? ((wcpl_pkt_len==2'b10) ? rcpl_pkt_data_sr[0+:MP_SPIF_NCFG] :
                                                                           rcpl_pkt_data_sr[32+:MP_SPIF_NCFG]) :
                                                  {MP_SPIF_NCFG{1'b0}};

endmodule
