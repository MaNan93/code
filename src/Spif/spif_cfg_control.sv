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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Spif/spif_cfg_control.sv#2 $
// -----------------------------------------------------------------------------
// --- Module Description: SPIF.CFG Control
// -----------------------------------------------------------------------------
// --- The SPIF.CFG Control module has three main features:
// ---   - Receive Register Access Requests from Local Bus Controller (LBC) and
// ---     all related data to generate the Register Access Request Packets to
// ---     be sent through the SPIF.CFG Interface.
// ---   - Receive Register Access Completion Packets from SPIF.CFG Interface,
// ---     unpack all the data and forwarding it to the Local Bus Controller.
// ---   - Manage the Packet control of SPIF.CFG Interface, including the
// ---     credits availability and error checking in the Completion Packets.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module spif_cfg_control #(
  parameter MP_SPIF_DW   = 32, // Data Width
  parameter MP_SPIF_NCFG = 32, // Width of SPIF Configuration Interface data (*_cfg_data)
  parameter MP_SPIF_CRD  = 1   // Available credits of SPIF.CFG Interface
  )
  (
  // Inputs
  input  wire                    core_clk           , // Clock
  input  wire                    core_rst_n         , // Asynchronous Reset
  input  wire                    ispif_req_trigger_p, // Send new Request to SPIF.CFG Interface (Pulse)
  input  wire   [MP_SPIF_DW-1:0] ispif_req_data     , // Register Access Data
  input  wire             [23:0] ispif_req_addr     , // Register Access Address
  input  wire              [7:0] ispif_req_pf       , // Register Access Physical Function Number
  input  wire              [8:0] ispif_req_vf       , // Register Access Virtual Function + Virtual Function Number
  input  wire                    ispif_req_we       , // Register Access Write Enable
  input  wire              [3:0] ispif_req_be       , // Register Access Byte Enable
  input  wire                    ispif_req_fw       , // Register Access Force Write
  input  wire                    ispif_req_sh       , // Register Access Shadow Register
  input  wire                    ispif_req_type     , // Register Access Packet Type (1'b0 - CFG Access / 1'b1 - MEM Access)
  input  wire              [4:0] ispif_req_dstid    , // Register Access Destination ID (2'b00 - PCIe / 2'b01 - CXL / 2'b10 - UCIe)
  output wire                    ospif_req_crd_full , // Register Access No Credits Available
  // Outputs
  output wire   [MP_SPIF_DW-1:0] ospif_cpl_data     , // Register Access Data Read
  output wire                    ospif_cpl_data_p   , // Register Access Data Available (Pulse)
  output wire                    ospif_cpl_avail_p  , // Register Access Completion Packet Available (Pulse)
  output wire                    ospif_cpl_err      , // Register Access Error
  // SPIF.CFG Interface (Ingoing Completion)
  input  wire                    ispif_pl_cfg_vld   , // SPIF.CFG Interface Valid Signal
  input  wire [MP_SPIF_NCFG-1:0] ispif_pl_cfg_data  , // SPIF.CFG Interface Data Signal
  // SPIF.CFG Interface (Outgoing Request)
  output wire                    ospif_lp_cfg_vld   , // SPIF.CFG Interface Valid Signal
  output wire [MP_SPIF_NCFG-1:0] ospif_lp_cfg_data    // SPIF.CFG Interface Data
  );

  // Localparameter declaration ********************************************************************************************************************************
  localparam TP = `TP;

  localparam LP_MEM_ACCESS = 1'b0;

  // Signal declaration ****************************************************************************************************************************************
  wire                                     wspif_req_dv_en;
  reg                                [2:0] rspif_req_dv_en_sr;
  reg  [(MP_SPIF_DW - MP_SPIF_NCFG - 1):0] rspif_req_data_sr;

  wire                                     wspif_req_pkt_fw;
  wire                                     wspif_req_pkt_sh;
  wire                               [7:0] wspif_req_pkt_be;
  reg                               [28:0] wspif_req_pkt_addr;
  wire                                     wspif_req_pkt_vf;
  wire                                     wspif_req_pkt_dp;
  wire                                     wspif_req_pkt_cp;
  reg                                [4:0] wspif_req_pkt_opcode;
  reg                                [4:0] rspif_req_pkt_tag_cnt;
  wire                              [61:0] wspif_req_pkt_pre_header;
  wire                  [MP_SPIF_NCFG-1:0] wspif_req_pkt_data;
  wire                                     wspif_req_pkt_hv_p;
  wire                                     wspif_req_pkt_dv;
  wire                                     wspif_req_pkt_eot_p;

  wire                               [4:0] wspif_cpl_pkt_tag;
  wire                               [1:0] wspif_cpl_pkt_len;
  wire                                     wspif_cpl_pkt_dp;
  wire                                     wspif_cpl_pkt_cp;
  wire                                     wspif_cpl_pkt_ep;
  wire                               [2:0] wspif_cpl_pkt_status;
  wire                  [MP_SPIF_NCFG-1:0] wspif_cpl_pkt_data;
  wire                                     wspif_cpl_pkt_hv_p;
  wire                                     wspif_cpl_pkt_dv;
  wire                                     wspif_cpl_pkt_eot_p;

  reg                                [4:0] rspif_cpl_pkt_tag;
  reg                                [1:0] rspif_cpl_pkt_len;
  reg                                      rspif_cpl_pkt_dp;
  reg                                      rspif_cpl_pkt_cp;
  reg                                      rspif_cpl_pkt_ep;
  reg                                [2:0] rspif_cpl_pkt_status;
  reg                                      rspif_cpl_pkt_eot_p_1d;

  reg                               [63:0] rspif_cpl_pkt_data_sr;
  reg                               [63:0] wspif_cpl_pkt_rcvd_data;
  wire                                     wspif_cpl_pkt_dp_check;
  wire                                     wspif_cpl_pkt_cp_check;
  wire                                     wspif_cpl_pkt_status_check;
  wire                                     wsipf_cpl_pkt_parity_err;
  reg                                [4:0] rspif_sent_tag;
  wire                                     wspif_cpl_pkt_tag_check_p;

  //************************************************************************************************************************************************************
  // Register Access Request Packet
  //************************************************************************************************************************************************************

  // PCIe Controller only supports 1 DWORD of Payload to CDM access, so only 4 LSB are used
  assign wspif_req_pkt_be = (MP_SPIF_DW == 32) ? {4'b0,ispif_req_be} : 8'b0;
  // UCIe does not have any Functions
  assign wspif_req_pkt_vf = ispif_req_vf[8];
  // Even Parity of Data Payload
  assign wspif_req_pkt_dp = ispif_req_we ? (^ispif_req_data) : 1'b0;
  // Even Parity of Header
  assign wspif_req_pkt_cp = ^wspif_req_pkt_pre_header;

  // Address
  always @(*) begin : cspif_req_pkt_addr_PROC
    if (ispif_req_type == LP_MEM_ACCESS) begin // MEM Access
      wspif_req_pkt_addr = {5'b00000, ispif_req_addr[23:0]};
    end else begin // CFG Access
      //                    VF[7:0]            PF[7:0]            Rsv   Offset
      wspif_req_pkt_addr = {ispif_req_vf[7:0], ispif_req_pf[7:0], 1'b0, ispif_req_addr[11:0]};
    end
  end

  // OPCODE definition
  always @(*) begin : cspif_req_pkt_opcode_PROC
    if (MP_SPIF_DW == 32) begin
      if (ispif_req_we) begin
        if (ispif_req_type == LP_MEM_ACCESS) begin
          wspif_req_pkt_opcode = 5'b00001; // MEMDDWR
        end else begin
          wspif_req_pkt_opcode = 5'b00101; // CFGDDWR
        end
      end else begin
        if (ispif_req_type == LP_MEM_ACCESS) begin
          wspif_req_pkt_opcode = 5'b00000; // MEMDDRD
        end else begin
          wspif_req_pkt_opcode = 5'b00100; // CFGDDRD
        end
      end
    end else begin
      if (ispif_req_we) begin
        if (ispif_req_type == LP_MEM_ACCESS) begin
          wspif_req_pkt_opcode = 5'b01001; // MEMQDWR
        end else begin
          wspif_req_pkt_opcode = 5'b01101; // CFGQDWR
        end
      end else begin
        if (ispif_req_type == LP_MEM_ACCESS) begin
          wspif_req_pkt_opcode = 5'b01000; // MEMQDRD
        end else begin
          wspif_req_pkt_opcode = 5'b01100; // CFGQDRD
        end
      end
    end
  end // cspif_req_pkt_opcode_PROC

  // TAG field of Requester Packet. This field is a counter from 0 to 31. Overflow is expected
  always @(posedge core_clk or negedge core_rst_n) begin : sspif_tag_cnt_PROC
    if (!core_rst_n) begin
      rspif_req_pkt_tag_cnt <= #TP 5'd0;
    end else begin
      if (ispif_req_trigger_p) begin
        rspif_req_pkt_tag_cnt <= #TP rspif_req_pkt_tag_cnt + 5'd1;
      end
    end
  end // sspif_tag_cnt_PROC

  assign wspif_req_pkt_pre_header = {wspif_req_pkt_vf,      // Virtual Function
                                     wspif_req_pkt_addr,    // Address
                                     ispif_req_dstid,       // Destination ID
                                     rspif_req_pkt_tag_cnt, // Tag
                                     wspif_req_pkt_be,      // Byte Enable
                                     6'b000000,             // 6 Bits Reserved
                                     ispif_req_sh,          // Shadow Register
                                     ispif_req_fw,          // Force Write
                                     1'b0,                  // Data Poison
                                     wspif_req_pkt_opcode}; // OPCODE

  // Request Packet Payload
  assign wspif_req_dv_en = ispif_req_trigger_p && ispif_req_we;

  generate
    if (MP_SPIF_NCFG == 16) begin

      always @(posedge core_clk or negedge core_rst_n) begin : sspif_req_dv_en_sr_PROC
        if (!core_rst_n) begin
          rspif_req_dv_en_sr <= #TP 3'b000;
        end else begin
          if (wspif_req_dv_en) begin
            rspif_req_dv_en_sr <= #TP 3'b001;
          end else begin
            if (|rspif_req_dv_en_sr) begin
              rspif_req_dv_en_sr <= #TP {1'b0,rspif_req_dv_en_sr[2:1]};
            end
          end
        end
      end // sspif_req_dv_en_sr_PROC

      always @(posedge core_clk or negedge core_rst_n) begin : sspif_req_data_PROC
        if (!core_rst_n) begin
          rspif_req_data_sr <= #TP 16'd0;
        end else begin
          if (ispif_req_trigger_p && ispif_req_we) begin
            rspif_req_data_sr <= #TP ispif_req_data[31:16];
          end else begin
            if (|rspif_req_dv_en_sr) begin
              rspif_req_data_sr <= #TP 16'd0;
            end
          end
        end
      end // sspif_req_data_PROC

    end else if (MP_SPIF_NCFG == 8) begin

      always @(posedge core_clk or negedge core_rst_n) begin : sspif_req_dv_en_sr_PROC
        if (!core_rst_n) begin
          rspif_req_dv_en_sr <= #TP 3'b000;
        end else begin
          if (wspif_req_dv_en) begin
            rspif_req_dv_en_sr <= #TP 3'b111;
          end else begin
            if (|rspif_req_dv_en_sr) begin
              rspif_req_dv_en_sr <= #TP {1'b0,rspif_req_dv_en_sr[2:1]};
            end
          end
        end
      end // sspif_req_dv_en_sr_PROC

      always @(posedge core_clk or negedge core_rst_n) begin : sspif_req_data_PROC
        if (!core_rst_n) begin
          rspif_req_data_sr <= #TP {(MP_SPIF_DW - MP_SPIF_NCFG){1'b0}};
        end else begin
          if (ispif_req_trigger_p && ispif_req_we) begin
            rspif_req_data_sr <= #TP ispif_req_data[(MP_SPIF_DW-1):MP_SPIF_NCFG];
          end else begin
            if (|rspif_req_dv_en_sr) begin
              rspif_req_data_sr <= #TP {{MP_SPIF_NCFG{1'b0}},rspif_req_data_sr[((MP_SPIF_DW - 1) - MP_SPIF_NCFG):MP_SPIF_NCFG]};
            end
          end
        end
      end // sspif_req_data_PROC

    end
  endgenerate

  generate
    if (MP_SPIF_NCFG == 32) begin
      assign wspif_req_pkt_data  = ispif_req_data;
      assign wspif_req_pkt_dv    = wspif_req_dv_en;
      assign wspif_req_pkt_eot_p = ispif_req_trigger_p;
      assign wspif_req_pkt_hv_p  = ispif_req_trigger_p;
    end else begin
      assign wspif_req_pkt_data  = wspif_req_dv_en ? ispif_req_data[MP_SPIF_NCFG-1:0] : rspif_req_data_sr[MP_SPIF_NCFG-1:0];
      assign wspif_req_pkt_dv    = wspif_req_dv_en ? 1'b1 : rspif_req_dv_en_sr[0];
      assign wspif_req_pkt_eot_p = (rspif_req_dv_en_sr == 3'b001);
      assign wspif_req_pkt_hv_p  = ispif_req_trigger_p;
    end
  endgenerate

  spif_cfg_if_requester
   #(
    .MP_SPIF_NCFG (MP_SPIF_NCFG), // SPIF.CFG Interface Data Width
    .MP_SPIF_CRD  (1           ) // SPIF.CFG Interface Credits
    )
    u_spif_cfg_if_requester(
      .core_clk             (core_clk             ),
      .core_rst_n           (core_rst_n           ),
      // SPIF.CFG Interface (Requester Interface)
      .ispif_pl_cfg_vld     (ispif_pl_cfg_vld     ),
      .ispif_pl_cfg_data    (ispif_pl_cfg_data    ),
      .ospif_lp_cfg_vld     (ospif_lp_cfg_vld     ),
      .ospif_lp_cfg_data    (ospif_lp_cfg_data    ),
      // Request Packet Fields
      .ispif_req_pkt_opcode (wspif_req_pkt_opcode ),
      .ispif_req_pkt_ep     (1'b0                 ),
      .ispif_req_pkt_fw     (ispif_req_fw         ),
      .ispif_req_pkt_sh     (ispif_req_sh         ),
      .ispif_req_pkt_be     (wspif_req_pkt_be     ),
      .ispif_req_pkt_tag    (rspif_req_pkt_tag_cnt),
      .ispif_req_pkt_dstid  (ispif_req_dstid      ),
      .ispif_req_pkt_addr   (wspif_req_pkt_addr   ),
      .ispif_req_pkt_vf     (wspif_req_pkt_vf     ),
      .ispif_req_pkt_cp     (wspif_req_pkt_cp     ),
      .ispif_req_pkt_dp     (wspif_req_pkt_dp     ),
      .ispif_req_pkt_data   (wspif_req_pkt_data   ),
      .ospif_req_crd_full   (ospif_req_crd_full   ),
      // Request Packet Control Flags
      .ispif_req_pkt_hv_p   (wspif_req_pkt_hv_p   ),
      .ispif_req_pkt_dv     (wspif_req_pkt_dv     ),
      .ispif_req_pkt_eot_p  (wspif_req_pkt_eot_p  ),
      // Completion Packet Fields
      .ospif_cpl_pkt_tag    (wspif_cpl_pkt_tag    ),
      .ospif_cpl_pkt_len    (wspif_cpl_pkt_len    ),
      .ospif_cpl_pkt_dp     (wspif_cpl_pkt_dp     ),
      .ospif_cpl_pkt_cp     (wspif_cpl_pkt_cp     ),
      .ospif_cpl_pkt_ep     (wspif_cpl_pkt_ep     ),
      .ospif_cpl_pkt_status (wspif_cpl_pkt_status ),
      .ospif_cpl_pkt_data   (wspif_cpl_pkt_data   ),
      // Completion Packet Control Flags
      .ospif_cpl_pkt_hv_p   (wspif_cpl_pkt_hv_p   ),
      .ospif_cpl_pkt_dv     (wspif_cpl_pkt_dv     ),
      .ospif_cpl_pkt_eot_p  (wspif_cpl_pkt_eot_p  )
    );

  //************************************************************************************************************************************************************
  // Register Access Completion Packet
  //************************************************************************************************************************************************************

  // Shift Register holding the data received through SPIF.CFG interface
  always @(posedge core_clk or negedge core_rst_n) begin : sspif_cpl_pkt_data_sr_PROC
    if (!core_rst_n) begin
      rspif_cpl_pkt_data_sr <= #TP 64'd0;
    end else begin
      if (wspif_cpl_pkt_dv) begin
        rspif_cpl_pkt_data_sr <= #TP {wspif_cpl_pkt_data,rspif_cpl_pkt_data_sr[63:MP_SPIF_NCFG]};
      end else begin
        if (ospif_cpl_avail_p) begin
          rspif_cpl_pkt_data_sr <= #TP 64'd0;
        end
      end
    end
  end // sspif_cpl_pkt_data_sr_PROC

  always @(*) begin : cspif_cpl_pkt_rcvd_data_PROC
    case (rspif_cpl_pkt_len)
      2'b00   : wspif_cpl_pkt_rcvd_data = 64'd0;                                //  0b of Data - 32b of Header
      2'b01   : wspif_cpl_pkt_rcvd_data = {32'd0,rspif_cpl_pkt_data_sr[63:32]}; // 32b of Data - 32b of Header
      2'b10   : wspif_cpl_pkt_rcvd_data = rspif_cpl_pkt_data_sr;                // 64b of Data - 32b of Header
      default : wspif_cpl_pkt_rcvd_data = 64'd0;                                // Reserved definition
    endcase
  end // cspif_cpl_pkt_rcvd_data_PROC

  always @(posedge core_clk or negedge core_rst_n) begin : sspif_cpl_pkt_PROC
    if (!core_rst_n) begin
      rspif_cpl_pkt_tag    <= #TP 5'd0;
      rspif_cpl_pkt_len    <= #TP 2'd0;
      rspif_cpl_pkt_dp     <= #TP 1'd0;
      rspif_cpl_pkt_cp     <= #TP 1'd0;
      rspif_cpl_pkt_ep     <= #TP 1'd0;
      rspif_cpl_pkt_status <= #TP 3'd0;
    end else begin
      if (wspif_cpl_pkt_hv_p) begin
        rspif_cpl_pkt_tag    <= #TP wspif_cpl_pkt_tag;
        rspif_cpl_pkt_len    <= #TP wspif_cpl_pkt_len;
        rspif_cpl_pkt_dp     <= #TP wspif_cpl_pkt_dp;
        rspif_cpl_pkt_cp     <= #TP wspif_cpl_pkt_cp;
        rspif_cpl_pkt_ep     <= #TP wspif_cpl_pkt_ep;
        rspif_cpl_pkt_status <= #TP wspif_cpl_pkt_status;
      end
    end
  end // sspif_cpl_pkt_PROC

  always @(posedge core_clk or negedge core_rst_n) begin : sspif_cpl_pkt_eot_p_1d_PROC
    if (!core_rst_n) begin
      rspif_cpl_pkt_eot_p_1d <= #TP 1'd0;
    end else begin
      rspif_cpl_pkt_eot_p_1d <= #TP wspif_cpl_pkt_eot_p;
    end
  end // sspif_cpl_pkt_eot_p_1d_PROC

  // Even Parity of Data Payload
  assign wspif_cpl_pkt_dp_check     = (rspif_cpl_pkt_dp == ^wspif_cpl_pkt_rcvd_data);
  // Even Parity of Header - Excluding CP and DP fields
  assign wspif_cpl_pkt_cp_check     = (rspif_cpl_pkt_cp == ^{rspif_cpl_pkt_tag,rspif_cpl_pkt_len,rspif_cpl_pkt_ep,rspif_cpl_pkt_status});
  // Status Check
  assign wspif_cpl_pkt_status_check = (rspif_cpl_pkt_status == 3'b001);

  // Outputs definition
  assign ospif_cpl_data    = (rspif_cpl_pkt_len == 2'b00) ? {(MP_SPIF_DW){1'b0}} : wspif_cpl_pkt_rcvd_data[MP_SPIF_DW-1:0];
  assign ospif_cpl_data_p  = rspif_cpl_pkt_eot_p_1d && (rspif_cpl_pkt_len != 2'b00);
  assign ospif_cpl_avail_p = rspif_cpl_pkt_eot_p_1d;
  assign ospif_cpl_err     = rspif_cpl_pkt_eot_p_1d && ((!wspif_cpl_pkt_dp_check)    || // Parity of Data Payload Check
                                                        (!wspif_cpl_pkt_cp_check)    || // Parity of Header Check
                                                          wspif_cpl_pkt_status_check || // Status Check
                                                        (!wspif_cpl_pkt_tag_check_p) ); // TAG Check

  //************************************************************************************************************************************************************
  // TAG Management
  //************************************************************************************************************************************************************

  // Sample the last TAG sent.
  always @(posedge core_clk or negedge core_rst_n) begin : sspif_sent_tag_PROC
    if (!core_rst_n) begin
      rspif_sent_tag <= #TP 5'b0;
    end else begin
      if (ispif_req_trigger_p) begin
        rspif_sent_tag <= #TP rspif_req_pkt_tag_cnt;
      end
    end
  end // sspif_sent_tag_PROC

  assign wspif_cpl_pkt_tag_check_p = rspif_cpl_pkt_eot_p_1d && (rspif_cpl_pkt_tag == rspif_sent_tag);

endmodule
