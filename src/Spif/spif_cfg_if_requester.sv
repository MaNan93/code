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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Spif/spif_cfg_if_requester.sv#2 $
// -----------------------------------------------------------------------------
// --- Module Description: SPIF.CFG Interface Requester
// -----------------------------------------------------------------------------
// --- The SPIF.CFG Interface Requester manages the transmission of Register
// --- Access Request Packet and the reception of Register Access Completion
// --- Packet, both through the SPIF.CFG Interface.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module spif_cfg_if_requester #(
  parameter MP_SPIF_NCFG = 32, // Width of SPIF Configuration Interface data (*_cfg_data)
  parameter MP_SPIF_CRD  = 1   // Credits of SPIF Configuration Interface
  )
  (
  input  wire                    core_clk            , // Clock
  input  wire                    core_rst_n          , // Asynchronous Reset
  // SPIF.CFG Interface (Completer Interface / Upstream Port)
  input  wire                    ispif_pl_cfg_vld    , // SPIF.CFG Interface Valid Signal (Completion Packet)
  input  wire [MP_SPIF_NCFG-1:0] ispif_pl_cfg_data   , // SPIF.CFG Interface Data Signal  (Completion Packet)
  output wire                    ospif_lp_cfg_vld    , // SPIF.CFG Interface Valid Signal (Request Packet)
  output wire [MP_SPIF_NCFG-1:0] ospif_lp_cfg_data   , // SPIF.CFG Interface Data         (Request Packet)
  // Request Packet Fields
  input  wire              [4:0] ispif_req_pkt_opcode, // Header OPCODE field (Request Packet)
  input  wire                    ispif_req_pkt_ep    , // Header EP field     (Request Packet)
  input  wire                    ispif_req_pkt_fw    , // Header FW field     (Request Packet)
  input  wire                    ispif_req_pkt_sh    , // Header SH field     (Request Packet)
  input  wire              [7:0] ispif_req_pkt_be    , // Header BE field     (Request Packet)
  input  wire              [4:0] ispif_req_pkt_tag   , // Header TAG field    (Request Packet)
  input  wire              [4:0] ispif_req_pkt_dstid , // Header DSTID field  (Request Packet)
  input  wire             [28:0] ispif_req_pkt_addr  , // Header ADDR field   (Request Packet)
  input  wire                    ispif_req_pkt_vf    , // Header VF field     (Request Packet)
  input  wire                    ispif_req_pkt_cp    , // Header CP field     (Request Packet)
  input  wire                    ispif_req_pkt_dp    , // Header DP field     (Request Packet)
  input  wire [MP_SPIF_NCFG-1:0] ispif_req_pkt_data  , // Data Payload        (Request Packet)
  // Request Packet Control Flags
  input  wire                    ispif_req_pkt_hv_p  , // SPIF.CFG Interface Request Packet Header Valid (Pulse)
  input  wire                    ispif_req_pkt_dv    , // SPIF.CFG Interface Request Packet Data Valid
  input  wire                    ispif_req_pkt_eot_p , // SPIF.CFG Interface Request End of Transmission (Pulse)
  output wire                    ospif_req_crd_full  , // SPIF.CFG Interface No credits available
  // Completion Packet Fields
  output wire              [4:0] ospif_cpl_pkt_tag   , // Header TAG    (Completion Packet)
  output wire              [1:0] ospif_cpl_pkt_len   , // Header LEN    (Completion Packet)
  output wire                    ospif_cpl_pkt_dp    , // Header DP     (Completion Packet)
  output wire                    ospif_cpl_pkt_cp    , // Header CP     (Completion Packet)
  output wire                    ospif_cpl_pkt_ep    , // Header EP     (Completion Packet)
  output wire              [2:0] ospif_cpl_pkt_status, // Header STATUS (Completion Packet)
  output wire [MP_SPIF_NCFG-1:0] ospif_cpl_pkt_data  , // Data Payload  (Completion Packet)
  // Completion Packet Control Flags
  output reg                     ospif_cpl_pkt_hv_p  , // SPIF.CFG Interface Request Packet Header Valid (Pulse)
  output wire                    ospif_cpl_pkt_dv    , // SPIF.CFG Interface Request Packet Data Valid
  output wire                    ospif_cpl_pkt_eot_p   // SPIF.CFG Interface Request End of Transmission (Pulse)
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
  reg                    [4:0] rspif_crd_cnt;
  wire                         wspif_req_crd_full;

  reg                    [4:0] rcpl_pkt_phase_cnt;
  wire                         wcpl_pkt_new_p;
  wire                         wcpl_pkt_header_en;
  wire                         wcpl_pkt_header_end_p;
  wire                         wcpl_pkt_data_end_p;
  wire                         wcpl_pkt_len_phase_p;
  wire                   [1:0] wcpl_pkt_len_field;
  reg                    [4:0] wcpl_pkt_phases;
  reg                    [4:0] rcpl_pkt_phases;
  wire                   [4:0] wcpl_pkt_total_phases;
  reg                   [31:0] rcpl_pkt_header_sr;

  reg                    [4:0] rreq_pkt_phase_cnt;
  wire                         wreq_pkt_opcode_read;
  wire                         wreq_pkt_opcode_64b;
  reg                    [4:0] rreq_pkt_total_phases;
  reg                    [4:0] wreq_pkt_total_phases;
  wire                   [4:0] wreq_pkt_total_phases_or;
  reg                          rreq_pkt_active;
  wire                         wreq_pkt_active;
  wire                         wreq_pkt_sent_p;
  wire                         wreq_pkt_header_en;
  wire      [MP_SPIF_NCFG-1:0] wreq_pkt_header;
  wire                  [63:0] wreq_pkt_header_fields;
  reg  [(63 - MP_SPIF_NCFG):0] rreq_pkt_header_sr;
  wire                         wreq_pkt_data_en;
  reg                   [63:0] rreq_pkt_data_sr;

  //************************************************************************************************************************************************************
  // SPIF.CFG Interface Credit Management
  //************************************************************************************************************************************************************

  // SPIF.CFG Credits counting
  always @(posedge core_clk or negedge core_rst_n) begin : sspif_crd_cnt_PROC
    if (!core_rst_n) begin
      rspif_crd_cnt <= #TP 5'd0;
    end else begin
      // If both flag occur at same time, the counter cannot change.
      if (wreq_pkt_sent_p ^ ospif_cpl_pkt_hv_p) begin
        if (wreq_pkt_sent_p) begin
          rspif_crd_cnt <= #TP rspif_crd_cnt + 5'd1;
        end else begin
          if (ospif_cpl_pkt_hv_p) begin
            rspif_crd_cnt <= #TP rspif_crd_cnt - 5'd1;
          end
        end
      end
    end
  end // sspif_crd_cnt_PROC

  // Internal flags that indicates no more SPIF.CFG credits available flag
  assign wspif_req_crd_full = (rspif_crd_cnt == MP_SPIF_CRD);

  // To output add the current Request Packet transmission in order to gate new Requests
  assign ospif_req_crd_full = wspif_req_crd_full && rreq_pkt_active;

  //************************************************************************************************************************************************************
  // Register Access Request Packet
  //************************************************************************************************************************************************************

  // Completion Packet Phase counter
  always @(posedge core_clk or negedge core_rst_n) begin : sreq_pkt_phase_cnt_PROC
    if (!core_rst_n) begin
      rreq_pkt_phase_cnt <= #TP 5'd0;
    end else begin
      if (wreq_pkt_sent_p) begin
        rreq_pkt_phase_cnt <= #TP 5'd0;
      end else begin
        if (wreq_pkt_active) begin
          rreq_pkt_phase_cnt <= #TP rreq_pkt_phase_cnt + 5'd1;
        end
      end
    end
  end // sreq_pkt_phase_cnt_PROC

  // Flags that signals if the incoming Request Packet is a Read Operation
  assign wreq_pkt_opcode_read = (ispif_req_pkt_opcode[4:0] == 5'b00000) ||
                                (ispif_req_pkt_opcode[4:0] == 5'b00100) ||
                                (ispif_req_pkt_opcode[4:0] == 5'b01000) ||
                                (ispif_req_pkt_opcode[4:0] == 5'b01100) ;

  // Flags that signals if the incoming Request Packet has 64 bits of payload
  assign wreq_pkt_opcode_64b = (ispif_req_pkt_opcode[4:0] == 5'b01001) ||
                               (ispif_req_pkt_opcode[4:0] == 5'b01101) ||
                               (ispif_req_pkt_opcode[4:0] == 5'b01000) ||
                               (ispif_req_pkt_opcode[4:0] == 5'b01100) ;

  // Total Phases (Request Packet) *****************************************************************************************************************************

  // Calculate the Length of Request Packet
  always @(*) begin : creq_pkt_len_PROC
    if (ispif_req_pkt_hv_p) begin
      if (wreq_pkt_opcode_read) begin
        // No payload available
        wreq_pkt_total_phases = LP_REQ_PKT_HEADER_PHASES;
      end else begin
        if (wreq_pkt_opcode_64b) begin
          wreq_pkt_total_phases = LP_REQ_PKT_DATA_64B_PHASES + LP_REQ_PKT_HEADER_PHASES;
        end else begin
          wreq_pkt_total_phases = LP_REQ_PKT_DATA_32B_PHASES + LP_REQ_PKT_HEADER_PHASES;
        end
      end
    end else begin
      wreq_pkt_total_phases = 5'd0;
    end
  end // creq_pkt_len_PROC

  always @(posedge core_clk or negedge core_rst_n) begin : sreq_pkt_len_PROC
    if (!core_rst_n) begin
      rreq_pkt_total_phases <= #TP 5'd0;
    end else begin
      if (wreq_pkt_sent_p) begin
        rreq_pkt_total_phases <= #TP 5'd0;
      end else begin
        if (ispif_req_pkt_hv_p) begin
          rreq_pkt_total_phases <= #TP wreq_pkt_total_phases;
        end
      end
    end
  end // sreq_pkt_len_PROC

  assign wreq_pkt_total_phases_or = wreq_pkt_total_phases | rreq_pkt_total_phases;

  // Transmission Active (Request Packet) **********************************************************************************************************************

  // Request Packet transmission is ongoing
  always @(posedge core_clk or negedge core_rst_n) begin : sreq_pkt_active_PROC
    if (!core_rst_n) begin
      rreq_pkt_active <= #TP 1'b0;
    end else begin
      if (ispif_req_pkt_hv_p && (!wspif_req_crd_full)) begin
        rreq_pkt_active <= #TP 1'b1;
      end else begin
        if (wreq_pkt_sent_p) begin
          rreq_pkt_active <= #TP 1'b0;
        end
      end
    end
  end // sreq_pkt_active_PROC

  assign wreq_pkt_active = ispif_req_pkt_hv_p | rreq_pkt_active;

  // Control Flags  (Request Packet) ***************************************************************************************************************************

  // Flag (Pulse) that signals the end of Request Packet transmission
  assign wreq_pkt_sent_p = wreq_pkt_active && (rreq_pkt_phase_cnt == (wreq_pkt_total_phases_or - 5'd1));

  // Flag that signals the transmission of Header
  assign wreq_pkt_header_en = wreq_pkt_active && (rreq_pkt_phase_cnt <= (LP_REQ_PKT_HEADER_PHASES - 5'd1));

  // Flag that signals the transmission of Payload
  assign wreq_pkt_data_en = wreq_pkt_active && (rreq_pkt_phase_cnt > (LP_REQ_PKT_HEADER_PHASES - 5'd1));

  // Data Store  (Request Packet) ******************************************************************************************************************************

  // Completion Packet Header definition
  assign wreq_pkt_header_fields = {ispif_req_pkt_dp,      // Data Parity
                                   ispif_req_pkt_cp,      // Control Parity
                                   ispif_req_pkt_vf,      // Virtual Function
                                   ispif_req_pkt_addr,    // Address
                                   ispif_req_pkt_dstid,   // Destination ID (UCIe only)
                                   ispif_req_pkt_tag,     // Tag
                                   ispif_req_pkt_be,      // Byte Enable
                                   6'b000000,             // 6 Bits Reserved
                                   ispif_req_pkt_sh,      // Shadow Register
                                   ispif_req_pkt_fw,      // Force Write
                                   ispif_req_pkt_ep,      // Data Poison
                                   ispif_req_pkt_opcode}; // OPCODE

  // Shift Register holding the Header received through SPIF.CFG interface
  // The Header of Request Packet has always 64 bits. Since the data of the first clock cycle is sent using combinational logic, there is no need to store them.
  generate
    if (MP_SPIF_NCFG == 32) begin
      always @(posedge core_clk or negedge core_rst_n) begin : sreq_pkt_header_sr_PROC
        if (!core_rst_n) begin
          rreq_pkt_header_sr <= #TP 32'd0;
        end else begin
          if (ispif_req_pkt_hv_p) begin
            rreq_pkt_header_sr <= #TP wreq_pkt_header_fields[63:32];
          end else begin
            if (ospif_lp_cfg_vld) begin
              rreq_pkt_header_sr <= #TP 32'd0;
            end
          end
        end
      end
    // MP_SPIF_NCFG != 32
    end else begin
      always @(posedge core_clk or negedge core_rst_n) begin : sreq_pkt_header_sr_PROC
        if (!core_rst_n) begin
          rreq_pkt_header_sr <= #TP {(64 - MP_SPIF_NCFG){1'b0}};
        end else begin
          if (ispif_req_pkt_hv_p) begin
            rreq_pkt_header_sr <= #TP wreq_pkt_header_fields[63:MP_SPIF_NCFG];
          end else begin
            if (ospif_lp_cfg_vld) begin
              rreq_pkt_header_sr <= #TP {{MP_SPIF_NCFG{1'b0}},rreq_pkt_header_sr[(63 - MP_SPIF_NCFG):MP_SPIF_NCFG]};
            end
          end
        end
      end // scpl_pkt_header_sr_PROC
    end
  endgenerate

  assign wreq_pkt_header = ispif_req_pkt_hv_p ? wreq_pkt_header_fields[MP_SPIF_NCFG-1:0] : rreq_pkt_header_sr[MP_SPIF_NCFG-1:0];

  // Shift Register holding the data received through SPIF.CFG interface
  always @(posedge core_clk or negedge core_rst_n) begin : sreq_pkt_data_sr_PROC
    if (!core_rst_n) begin
      rreq_pkt_data_sr <= #TP 64'd0;
    end else begin
      if (ispif_req_pkt_dv || wreq_pkt_data_en) begin
        rreq_pkt_data_sr <= #TP {ispif_req_pkt_data,rreq_pkt_data_sr[63:MP_SPIF_NCFG]};
      end
    end
  end // sreq_pkt_data_sr_PROC

  // Output Definition  (Request Packet) ***********************************************************************************************************************

  // Since the header has always two DWORDs of lengh, the sample of Packet Data (Payload) is always performed from the same position
  assign ospif_lp_cfg_vld  =  (!wspif_req_crd_full) && wreq_pkt_active;
  assign ospif_lp_cfg_data = ((!wspif_req_crd_full) && wreq_pkt_header_en) ? wreq_pkt_header :
                                                       wreq_pkt_active     ? (wreq_pkt_opcode_64b ? rreq_pkt_data_sr[0+:MP_SPIF_NCFG] :
                                                                                                    rreq_pkt_data_sr[32+:MP_SPIF_NCFG] ) :
                                                                             {MP_SPIF_NCFG{1'b0}}                                        ;

  //************************************************************************************************************************************************************
  // Register Access Completion Packet
  //************************************************************************************************************************************************************

  // Receive Completion Packet Phase counter
  always @(posedge core_clk or negedge core_rst_n) begin : scpl_pkt_phase_cnt_PROC
    if (!core_rst_n) begin
      rcpl_pkt_phase_cnt <= #TP 5'd0;
    end else begin
      if (ospif_cpl_pkt_eot_p) begin
        rcpl_pkt_phase_cnt <= #TP 5'd0;
      end else begin
        if (ispif_pl_cfg_vld) begin
          rcpl_pkt_phase_cnt <= #TP rcpl_pkt_phase_cnt + 5'd1;
        end
      end
    end
  end // scpl_pkt_phase_cnt_PROC

  // Control Flags (Completion Packet) *************************************************************************************************************************

  // Flag (Pulse) that marks a new Request Packet in incoming SPIF.CFG Interface
  assign wcpl_pkt_new_p = ispif_pl_cfg_vld && (rcpl_pkt_phase_cnt == 5'd0);

  // The SPIF.CFG Interface has Header information in the current clock cycle
  assign wcpl_pkt_header_en = ispif_pl_cfg_vld && (rcpl_pkt_phase_cnt <= (LP_CPL_PKT_HEADER_PHASES - 5'd1));

  // The transmission of Packet Header is over
  assign wcpl_pkt_header_end_p = ispif_pl_cfg_vld && (rcpl_pkt_phase_cnt == (LP_CPL_PKT_HEADER_PHASES - 5'd1));

  // The transmission of Packet Data is over
  assign wcpl_pkt_data_end_p = ispif_pl_cfg_vld && (rcpl_pkt_phase_cnt == (wcpl_pkt_total_phases - 5'd1));

  // Flag (Pulse) that marks the Phase of LEN field
  assign wcpl_pkt_len_phase_p = ispif_pl_cfg_vld && (rcpl_pkt_phase_cnt == ((MP_SPIF_NCFG == 8) ? 5'd1 : 5'd0));

  // Get LEN field
  generate
    if (MP_SPIF_NCFG == 8) begin
      assign wcpl_pkt_len_field = ispif_pl_cfg_data[1:0];
    end else begin
      assign wcpl_pkt_len_field = ispif_pl_cfg_data[9:8];
    end
  endgenerate

  // Total Phases (Completion Packet) **************************************************************************************************************************

  // Calculate the Length of Completion Packet
  always @(*) begin : ccpl_pkt_phases_PROC
    if (wcpl_pkt_len_phase_p) begin
      case (wcpl_pkt_len_field)
        2'b00   : wcpl_pkt_phases = LP_CPL_PKT_HEADER_PHASES;
        2'b01   : wcpl_pkt_phases = LP_CPL_PKT_DATA_32B_PHASES + LP_CPL_PKT_HEADER_PHASES;
        2'b10   : wcpl_pkt_phases = LP_CPL_PKT_DATA_64B_PHASES + LP_CPL_PKT_HEADER_PHASES;
        default : wcpl_pkt_phases = 5'd0;
      endcase
    end else begin
      wcpl_pkt_phases = 5'd0;
    end
  end // sreq_pkt_len_PROC

  always @(posedge core_clk or negedge core_rst_n) begin : scpl_pkt_phases_PROC
    if (!core_rst_n) begin
      rcpl_pkt_phases <= #TP 5'd0;
    end else begin
      if (ospif_cpl_pkt_eot_p) begin
        rcpl_pkt_phases <= #TP 5'd0;
      end else begin
        if (wcpl_pkt_len_phase_p) begin
          rcpl_pkt_phases <= #TP wcpl_pkt_phases;
        end
      end
    end
  end // sreq_pkt_len_PROC

  assign wcpl_pkt_total_phases = wcpl_pkt_len_phase_p ? wcpl_pkt_phases : rcpl_pkt_phases;

  // Data Store (Completion Packet) ****************************************************************************************************************************

  // Shift Register holding the Header received through SPIF.CFG interface
  generate
    if (MP_SPIF_NCFG == 32) begin
      always @(posedge core_clk or negedge core_rst_n) begin : scpl_pkt_header_PROC
          if (!core_rst_n) begin
            rcpl_pkt_header_sr <= #TP 32'd0;
          end else begin
            if (wcpl_pkt_header_en) begin
              rcpl_pkt_header_sr <= #TP ispif_pl_cfg_data;
            end else begin
              rcpl_pkt_header_sr <= #TP 32'd0;
            end
          end
        end // scpl_pkt_header_PROC
    end else begin // MP_SPIF_NCFG != 32
      always @(posedge core_clk or negedge core_rst_n) begin : scpl_pkt_header_PROC
        if (!core_rst_n) begin
          rcpl_pkt_header_sr <= #TP 32'd0;
        end else begin
          if (wcpl_pkt_header_en) begin
            rcpl_pkt_header_sr <= #TP {ispif_pl_cfg_data,rcpl_pkt_header_sr[31:MP_SPIF_NCFG]};
          end else begin
            rcpl_pkt_header_sr <= #TP 32'd0;
          end
        end
      end // scpl_pkt_header_PROC
    end
  endgenerate

  // Output Definition (Completion Packet) *********************************************************************************************************************

  always @(posedge core_clk or negedge core_rst_n) begin : scpl_pkt_PROC
    if (!core_rst_n) begin
      ospif_cpl_pkt_hv_p <= #TP 1'b0;
    end else begin
      ospif_cpl_pkt_hv_p <= #TP wcpl_pkt_header_end_p;
    end
  end // scpl_pkt_PROC

  // Flag (Pulse) that signals that the Header has been received
  assign ospif_cpl_pkt_dv = ispif_pl_cfg_vld && (rcpl_pkt_phase_cnt >= (LP_CPL_PKT_HEADER_PHASES));

  // Flag (Pulse) that signals that the end of transmission
  assign ospif_cpl_pkt_eot_p = (wcpl_pkt_total_phases > LP_CPL_PKT_HEADER_PHASES) ? wcpl_pkt_data_end_p : ospif_cpl_pkt_hv_p;

  // Header Fields assignment
  assign ospif_cpl_pkt_tag    = rcpl_pkt_header_sr[26:22];
  assign ospif_cpl_pkt_len    = rcpl_pkt_header_sr[9:8];
  assign ospif_cpl_pkt_dp     = rcpl_pkt_header_sr[7];
  assign ospif_cpl_pkt_cp     = rcpl_pkt_header_sr[6];
  assign ospif_cpl_pkt_ep     = rcpl_pkt_header_sr[5];
  assign ospif_cpl_pkt_status = rcpl_pkt_header_sr[2:0];

  // Payload assignment
  assign ospif_cpl_pkt_data   = {MP_SPIF_NCFG{ospif_cpl_pkt_dv}} & ispif_pl_cfg_data;

endmodule
