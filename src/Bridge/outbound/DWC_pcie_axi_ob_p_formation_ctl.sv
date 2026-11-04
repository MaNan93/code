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
// ---    $DateTime: 2022/05/05 01:39:57 $
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_axi_ob_p_formation_ctl.sv#12 $
// -------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"


 module DWC_pcie_axi_ob_p_formation_ctl
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter PRF_TLP_DATA_WIDTH               = 32,
  parameter PRF_TLP_NUM_WSTRBS               = 4,
  parameter PRF_TLP_NUM_WSTRBS_GT_4          = 0,
  parameter PRF_TLP_NUM_DWORDS               = 1,
  parameter SLV_BUS_ADDR_WIDTH               = 32,
  parameter SLAVE_BUS_ADDR_WIDTH             = 32,
  parameter SLV_MTU_PW                       = 32,
  parameter SLV_BURST_LEN_PW                 = 32,
  parameter P_REQ_INFO_PASS_WD               = 32,
  parameter CX_RAS_PROT_RANGE                = 4,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                               = `TP
  )
  (
  // -------------------------------------------------------------------------------------
  // Clocks and Resets
  // -------------------------------------------------------------------------------------
  input                                              slv_aclk,
  input                                              slv_aresetn,
  // -------------------------------------------------------------------------------------
  // Posted Request interface
  // -------------------------------------------------------------------------------------
  input                                              p_valid,
  input                                              p_last,
  input       [PRF_TLP_NUM_WSTRBS-1:0]               p_strb,
  input       [PRF_TLP_NUM_WSTRBS-1:0]               p_ep_strb,
  input       [PRF_TLP_NUM_WSTRBS-1:0]               p_silentDrop_strb,
  input       [PRF_TLP_NUM_WSTRBS-1:0]               p_silentDrop_strb_masked,
  input       [PRF_TLP_DATA_WIDTH-1:0]               p_data,
  input       [SLV_BUS_ADDR_WIDTH-1:0]               p_addr,
  input       [2:0]                                  p_size,
  input       [SLV_BURST_LEN_PW-1:0]                 p_len,
  input       [7:0]                                  p_msg_code,
  input       [4:0]                                  p_type,
  input       [P_REQ_INFO_PASS_WD-1:0]               p_req_info_pass,
  output wire                                        ctl_p_halt,
  // -------------------------------------------------------------------------------------
  // Posted Request TLP interface
  // -------------------------------------------------------------------------------------
  output wire [7:0]                                  ctl_tlp_byte_en,
  output wire                                        ctl_tlp_dv,
  output wire                                        ctl_tlp_eot,
  output wire                                        ctl_tlp_hv,
  output wire [1:0]                                  ctl_tlp_fmt,
  output wire [SLV_MTU_PW-1:0]                       ctl_tlp_byte_len,
  output wire [P_REQ_INFO_PASS_WD-1:0]               ctl_p_req_info_pass,
  output wire [SLV_BUS_ADDR_WIDTH-1:0]               ctl_tlp_addr,
  output wire [PRF_TLP_DATA_WIDTH-1:0]               ctl_tlp_data,
  output wire [PRF_TLP_NUM_WSTRBS-1:0]               ctl_tlp_strb,
  output wire [PRF_TLP_NUM_WSTRBS-1:0]               ctl_tlp_ep_strb,
  output wire [PRF_TLP_NUM_WSTRBS-1:0]               ctl_tlp_silentDrop_strb,
  output wire [PRF_TLP_NUM_WSTRBS-1:0]               ctl_tlp_silentDrop_strb_masked,
  input                                              pdcmp_halt
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam SLAVE_BUS_ADDR_PAR_WD           = SLV_BUS_ADDR_WIDTH - SLAVE_BUS_ADDR_WIDTH;

  // AXI posted burst states
  localparam ST_P_IDLE                       = 1'b0;
  localparam ST_P_MULTI_BEAT                 = 1'b1;

  // Pipelined posted interface width
  // {byte_en, dv, eot, hv, fmt, byte_len, req_info_pass, addr, data, lastReq}
  localparam P_INTF_WIDTH = {13 +
                             SLV_MTU_PW +
                             P_REQ_INFO_PASS_WD +
                             SLV_BUS_ADDR_WIDTH +
                             PRF_TLP_NUM_WSTRBS +
                             PRF_TLP_NUM_WSTRBS +
                             PRF_TLP_NUM_WSTRBS +
                             PRF_TLP_NUM_WSTRBS +
                             PRF_TLP_DATA_WIDTH};
  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  wire [SLV_BUS_ADDR_WIDTH-1:0]                      s_tlp_addr;
  wire                                               s_msg;
  wire  [SLV_BUS_ADDR_WIDTH -1:0]                    p_addr_par_msb;
  wire                                               s_addr_64;
  wire [1:0]                                         s_tlp_fmt;

  reg  [SLV_MTU_PW-1:0]                              s_p_num_bytes_per_beat;
  wire [SLV_MTU_PW-1:0]                              s_p_num_bytes;
  reg  [SLV_MTU_PW-1:0]                              r_p_num_bytes;

  wire                                               s_zero_byte_write;

  reg                                                s_tlp_hv;
  reg                                                r_tlp_hv;
  reg                                                s_tlp_dv;
  reg                                                r_tlp_dv;
  reg                                                s_tlp_eot;
  reg                                                r_tlp_eot;
  reg  [SLV_MTU_PW-1:0]                              s_p_burst_size;
  reg  [SLV_MTU_PW-1:0]                              r_p_burst_size;
  wire [SLV_MTU_PW-1:0]                              s_p_len_shift_size;
  reg                                                s_tlp_with_data;
  reg                                                r_tlp_with_data;
  reg                                                s_tlp_fsm;
  reg                                                r_tlp_fsm;

  reg  [3:0]                                         s_fbe;
  wire                                               s_p_burst_size_gt_dword;

  reg  [12:0]                                        s_p_burst_size_dw_algnd;
  reg  [13:0]                                        s_p_burst_size_dw_algnd_last;
  reg  [3:0]                                         s_lbe;
  wire [10:0]                                        s_tlp_num_dwords;
  wire [12:0]                                        s_tlp_byte_len;

  reg                                                s_ncbe_fbe;
  reg                                                s_ncbe_lbe_fbe;
  reg  [3:0]                                         s_tlp_fbe;
  reg  [3:0]                                         s_tlp_lbe;
  reg  [PRF_TLP_NUM_WSTRBS-1:0]                      r_p_strb;
  reg  [3:0]                                         s_p_strb_fbe;
  reg  [7:0]                                         s_p_strb_lbe_fbe;
  wire [7:0]                                         s_tlp_byte_en;

  wire [P_INTF_WIDTH -1:0]                           p_tlp_intf;
  wire [P_INTF_WIDTH -1:0]                           pdly1_p_tlp_intf;
  wire                                               s_pdcmp_halt;
  wire                                               pdly1_halt;
  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  // Decode message type
  assign s_msg = (p_type[4:3] == 2'b10);

  // Pass the byte aligned address to the decomposer.
  // If message then the decomposer will pass the address to the client.
  // If MWr the decomposer will align the byte aligned address to decomposed dword
  // aligned address boundaries.
  // Note: address parity checked and re-calculated by the decomposer. Therefore
  // address not dword aligned in the formation block.
  assign s_tlp_addr = p_addr;

  // -------------------------------------------------------------------------------------
  // Generate TLP format field
  // MWr:  10 (3 dword with and without data),
  // MWr:  11 (4 dword with and without data)
  // Msg:  01 (4 dword),
  // MsgD: 11 (4 dword with data)
  // -------------------------------------------------------------------------------------
  // Detect 64-bit MWr address
  // If parity enabled we need to extract the upper address bytes for compaison purposes
  assign p_addr_par_msb = swap_addr_par(p_addr);

  generate
    case (SLAVE_BUS_ADDR_WIDTH)
      64 : begin : gen_s_addr_64
         // 4 dword header MWr
         assign s_addr_64 = |p_addr_par_msb[63:32] && (p_type == 5'b0);
      end
      default : begin  : gen_s_addr_default
         assign s_addr_64 = 1'b0;
      end
    endcase
  endgenerate

  assign s_tlp_fmt    = {((s_msg && !s_tlp_with_data) ? 1'b0 : 1'b1), (s_msg ? 1'b1 :s_addr_64)};

  // -------------------------------------------------------------------------------------
  // Calculate the actual valid number of bytes and update value on the last beat
  // The last beat can contain no data if trailing null writes received on the W Channel.
  // -------------------------------------------------------------------------------------
  // Calculate number of bytes per beat
  always @(*) begin : proc_comb_num_p_bytes
    integer i;
    s_p_num_bytes_per_beat = {SLV_MTU_PW{1'b0}};

    for (i=0; i<PRF_TLP_NUM_WSTRBS; i=i+1) begin
      // spyglass disable_block W164a
      // SMD: Identifies assignments in which the LHS width is less than the RHS width
      // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
      s_p_num_bytes_per_beat = s_p_num_bytes_per_beat + p_strb[i];
      // spyglass enable_block W164a
    end
  end

  // Accumulate bytes per beat
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
  assign s_p_num_bytes = (r_p_num_bytes + s_p_num_bytes_per_beat);
// spyglass enable_block W164a

  // Store accumulated bytes per beat
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_p_num_bytes
    if (slv_aresetn == 1'b0) begin
      r_p_num_bytes <= #TP {SLV_MTU_PW{1'b0}};
    end else if (!pdly1_halt) begin
      if (p_valid && p_last) begin
        // Initialise
        r_p_num_bytes <= #TP {SLV_MTU_PW{1'b0}};
      end else if (p_valid) begin
        // Accumulate
        r_p_num_bytes <= #TP s_p_num_bytes;
      end
    end
  end

  // Detect zero byte write
  assign s_zero_byte_write = p_valid && p_last && ~|p_strb && !s_msg;

  assign s_p_len_shift_size = SLV_MTU_PW'((p_len + 1) << p_size);

  // -------------------------------------------------------------------------------------
  // Write FSM
  // -------------------------------------------------------------------------------------
  // FSM combinational
  always @(*) begin : proc_comb_tlp_fsm
    // Initialise
    s_tlp_hv        = r_tlp_hv;
    s_tlp_dv        = r_tlp_dv;
    s_tlp_eot       = r_tlp_eot;
    // If not last then burst size equals number of beats times number of bytes per beat
    // else its the actual number of write strobes
    s_p_burst_size  = r_p_burst_size;
    s_tlp_with_data = r_tlp_with_data; // hold for last beat (may contain null write)
    s_tlp_fsm       = r_tlp_fsm;

    if (!pdly1_halt) begin
      case (r_tlp_fsm)
        ST_P_IDLE : begin
          s_tlp_hv = p_valid;
          // Data valid not asserted for msg without data
          // Data valid asserted for valid data and zero byte write
          s_tlp_with_data = p_valid && |p_strb;
          s_tlp_dv        = s_tlp_with_data || s_zero_byte_write;

          if (p_valid && p_last) begin
            s_tlp_eot = 1'b1;
          end else begin
            s_tlp_eot = 1'b0;
          end

          if (p_valid && p_last) begin
            // Single-beat request
            s_p_burst_size = s_p_num_bytes;
          end else if (p_valid) begin
            // Multi-beat request
            s_p_burst_size = s_p_len_shift_size;
            s_tlp_fsm = ST_P_MULTI_BEAT;
          end
        end
        ST_P_MULTI_BEAT : begin
          s_tlp_hv = 1'b0;
          // For trailing null transfers the AXI slave interface module discards null beats
          // except the first trailing null write.
          // TLP data valid is not asserted for the last null beat.
          s_tlp_dv = p_valid && |p_strb;

          if (p_valid && p_last) begin
            s_tlp_eot = 1'b1;
            // unaligned starting address and trailing null write
            s_p_burst_size = s_p_num_bytes;
            s_tlp_fsm = ST_P_IDLE;
          end else begin
            s_p_burst_size = s_p_len_shift_size;
          end
        end
      endcase
    end
  end

  // FSM sequential
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_tlp_fsm
    if (!slv_aresetn) begin
      r_tlp_fsm       <= # TP 1'b0;
      r_tlp_hv        <= # TP 1'b0;
      r_tlp_dv        <= # TP 1'b0;
      r_tlp_eot       <= # TP 1'b0;
      r_p_burst_size  <= # TP {SLV_MTU_PW{1'b0}};
      r_tlp_with_data <= # TP 1'b0;
    end else if (!pdly1_halt) begin
      r_tlp_fsm       <= # TP s_tlp_fsm;
      r_tlp_hv        <= # TP s_tlp_hv;
      r_tlp_dv        <= # TP s_tlp_dv;
      r_tlp_eot       <= # TP s_tlp_eot;
      r_p_burst_size  <= # TP s_p_burst_size;
      r_tlp_with_data <= # TP s_tlp_with_data;
    end
  end

  // -------------------------------------------------------------------------------------
  // Generate the first byte enable; contiguous byte transfers
  // -------------------------------------------------------------------------------------
  assign s_p_burst_size_gt_dword = |s_p_burst_size[SLV_MTU_PW-1:2];

  always @(*) begin : proc_comb_fbe
    //      byte offset , num bytes in first dword
    casez  ({p_addr[1:0], s_p_burst_size[1:0]})
      4'b0000:
        s_fbe = s_p_burst_size_gt_dword ? 4'b1111 : 4'b0000;
      4'b0001:
        s_fbe = s_p_burst_size_gt_dword ? 4'b1111: 4'b0001;
      4'b0010:
        s_fbe = s_p_burst_size_gt_dword ? 4'b1111: 4'b0011;
      4'b0011:
        s_fbe = s_p_burst_size_gt_dword ? 4'b1111: 4'b0111;

      4'b0100:
        s_fbe = s_p_burst_size_gt_dword ? 4'b1110 : 4'b0000;
      4'b0101:
        s_fbe = s_p_burst_size_gt_dword ? 4'b1110: 4'b0010;
      4'b0110:
        s_fbe = s_p_burst_size_gt_dword ? 4'b1110: 4'b0110;
      4'b0111:
        s_fbe = 4'b1110;

      4'b1000:
        s_fbe = s_p_burst_size_gt_dword ? 4'b1100 : 4'b0000;
      4'b1001:
        s_fbe = s_p_burst_size_gt_dword ? 4'b1100: 4'b0100;
      4'b101?:
        s_fbe = 4'b1100;

      4'b1100:
        s_fbe = s_p_burst_size_gt_dword ? 4'b1000 : 4'b0000;

      default:
        s_fbe = 4'b1000;
    endcase
  end


  // Generate the dword length based on the AXI transfer control information
  // -------------------------------------------------------------------------------------
  // Calculate the number of dword aligned bytes on the number of bytes per beat and
  // the starting address offset
  always @(*) begin : proc_comb_num_bytes_from_dw_bndry
    s_p_burst_size_dw_algnd = 13'd0;
    case (p_size)
      3'b000: // 1 byte
        s_p_burst_size_dw_algnd = {{(13-SLV_MTU_PW){1'b0}},s_p_burst_size} + {11'd0, p_addr[1:0]};
      3'b001: // 2 byte
        s_p_burst_size_dw_algnd = {{(13-SLV_MTU_PW){1'b0}},s_p_burst_size} + {11'd0, p_addr[1], 1'b0};
      3'b010: // 4 byte
        s_p_burst_size_dw_algnd = {{(13-SLV_MTU_PW){1'b0}},s_p_burst_size};
      3'b011: // 8 byte
        s_p_burst_size_dw_algnd = {{(13-SLV_MTU_PW){1'b0}},s_p_burst_size} - {10'd0, p_addr[2], 2'b0};
      3'b100: // 16 byte
        s_p_burst_size_dw_algnd = {{(13-SLV_MTU_PW){1'b0}},s_p_burst_size} - {9'd0, p_addr[3:2], 2'b0};
      3'b101: // 32 byte
        s_p_burst_size_dw_algnd = {{(13-SLV_MTU_PW){1'b0}},s_p_burst_size} - {8'd0,p_addr[4:2], 2'b0};
      3'b110: // 64 byte
        s_p_burst_size_dw_algnd = {{(13-SLV_MTU_PW){1'b0}},s_p_burst_size} - {7'd0,p_addr[5:2], 2'b0};
    endcase
  end

  // Update the number of dword aligned bytes on the last beat based on the actual
  // number of write strobes
  // -------------------------------------------------------------------------------------
  always @(*) begin : proc_comb_tlp_num_bytes_dw_algnd
    s_p_burst_size_dw_algnd_last = {1'b0,s_p_burst_size_dw_algnd};

    if (!s_tlp_eot) begin
      // calculated number of bytes as per request info
      s_p_burst_size_dw_algnd_last = {1'b0,s_p_burst_size_dw_algnd};
    end else begin
      // actual number of bytes plus dword byte offset
      if (s_msg) s_p_burst_size_dw_algnd_last = ({{(14-SLV_MTU_PW){1'b0}},s_p_burst_size} );
      else s_p_burst_size_dw_algnd_last = ({{(14-SLV_MTU_PW){1'b0}},s_p_burst_size} + {12'd0, p_addr[1:0]});
    end
  end

  // Generate last byte enable; contiguous transfers
  // -------------------------------------------------------------------------------------
  // Encode last byte enable
  always @(*) begin : proc_comb_lbe
    // Initialise
    s_lbe = 4'b0; // Set to all zeros for 1 dword transfer

    if (s_p_burst_size_dw_algnd_last>4) begin
      case  (s_p_burst_size_dw_algnd_last[1:0])
        2'b00:
          s_lbe = 4'b1111;
        2'b01:
          s_lbe = 4'b0001;
        2'b10:
          s_lbe = 4'b0011;
        default:
          s_lbe = 4'b0111;
      endcase
    end
  end

  // Calculate dword length in bytes, contiguous transfers
  // -------------------------------------------------------------------------------------
  // Convert dword aligned bytes to number of dwords
  // Note: zero length posted write supported but has no effect at destination
  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
  assign s_tlp_num_dwords = s_p_burst_size_dw_algnd_last[12:2] +
                            (|s_p_burst_size_dw_algnd_last[1:0]) +
                            !(|s_p_burst_size_dw_algnd_last);
  // spyglass enable_block W164a


  // -------------------------------------------------------------------------------------
  // FBE: - If length > 1 dword then fbe must be non-zero
  //      - 1 dword write request with fbe all zeros permitted, has no effect at destination
  //      - non-contiguous fbe permitted for 1 and 2 dword requests
  //
  // LBE: - If length equal to 1 dword then all zeros, > 1 dword then must be non-zero
  //      - non-contiguous lbe permitted for 2 dword requests
  // -------------------------------------------------------------------------------------
  generate
    if (PRF_TLP_NUM_WSTRBS_GT_4) begin : gen_ncbe
      always @(*) begin : proc_comb_ncbe
        s_ncbe_fbe     = 1'b0;
        s_ncbe_lbe_fbe = 1'b0;
        s_tlp_fbe      = 4'b0;
        s_tlp_lbe      = 4'b0;

        if (s_tlp_eot) begin // Valid data or trailing null(dv not asserted)
          if (s_tlp_num_dwords<=2) begin
            // Applicable to non-contiguous 1 dword transfers
            s_ncbe_fbe     = fn_ncbe_fbe(p_strb[3:0]);
            // Applicable to non-contiguous 2 dword transfers
            // Set if 2 dword transfer is non-contigiuous and last byte enable is non-zero
            s_ncbe_lbe_fbe = fn_ncbe_lbe_fbe(p_strb[7:0]);
          end
        end

        // Pass strobes if 1 or 2 dword transfer is non-contiguous
        s_tlp_fbe = s_ncbe_fbe || s_ncbe_lbe_fbe ? p_strb[3:0] : s_fbe;
        s_tlp_lbe = s_ncbe_lbe_fbe               ? p_strb[7:4] : s_lbe;
      end

    end else begin : gen_ncbe

      // Retime the write strobe
      always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_strb
        if (!slv_aresetn) begin
          r_p_strb <= # TP {PRF_TLP_NUM_WSTRBS{1'b0}};
        end else if (!pdly1_halt) begin
          if (p_valid) begin // Note: if trailing null pvalid still asserted
            if (p_last) begin
              r_p_strb <= # TP {PRF_TLP_NUM_WSTRBS{1'b0}};
            end else begin
              r_p_strb <= # TP p_strb;
            end
          end
        end
      end

      always @(*) begin : proc_comb_ncbe
        // Initialise
        s_ncbe_fbe     = 1'b0;
        s_ncbe_lbe_fbe = 1'b0;
        s_tlp_fbe      = 4'b0;
        s_tlp_lbe      = 4'b0;

        // fbe
        s_p_strb_fbe = s_tlp_hv ? p_strb : r_p_strb;

        // {lbe, fbe}
        if (s_tlp_hv && s_tlp_eot) begin // 1 beat
          s_p_strb_lbe_fbe = {r_p_strb, p_strb}; // {4'b0, fbe}
        end else begin // 2 beat contiguous, 2 beat with trailing null, 2 beat ncbe (1 or 2 dwords)
          s_p_strb_lbe_fbe = {p_strb, r_p_strb}; // {lbe, fbe}
        end

        if (s_tlp_eot) begin // Valid data or trailing null(dv not asserted)
          if (s_tlp_num_dwords<=2) begin
            // Applicable to non-contiguous 1 dword transfers
            s_ncbe_fbe     = fn_ncbe_fbe(s_p_strb_fbe);
            // Applicable to non-contiguous 2 dword transfers
            // Set if 2 dword transfer is non-contigiuous and last byte enable is non-zero
            s_ncbe_lbe_fbe = fn_ncbe_lbe_fbe(s_p_strb_lbe_fbe);
          end
        end

        // Pass strobes if 1 or 2 dword transfer is non-contiguous
        s_tlp_fbe = s_ncbe_fbe || s_ncbe_lbe_fbe ? s_p_strb_fbe : s_fbe;
        s_tlp_lbe = s_ncbe_lbe_fbe               ? p_strb : s_lbe;
      end

    end
  endgenerate

  // Express number of dwords in bytes.
  // For 2 dword ncbe num bytes can be less than 1 dword so force length to 2 dwords
  assign s_tlp_byte_len = s_ncbe_lbe_fbe ? 13'h8 : {s_tlp_num_dwords, 2'b0};

  // Concatenate the last and first byte enables.
  // If message replace byte enabled with message code
  assign s_tlp_byte_en = s_msg ? p_msg_code : {s_tlp_lbe, s_tlp_fbe};

// -------------------------------------------------------------------------------------
// Instantiate pipe delay
// -------------------------------------------------------------------------------------
  assign ctl_p_halt = pdly1_halt;

  // {byte_en, dv, eot, hv, fmt, byte_len, req_info_pass}
  assign p_tlp_intf = {
    s_tlp_byte_en
  , s_tlp_dv
  , s_tlp_eot
  , s_tlp_hv
  , s_tlp_fmt
  , s_tlp_byte_len[SLV_MTU_PW-1:0]
  , p_req_info_pass
  , s_tlp_addr
  , p_data
  , p_strb
  , p_ep_strb
  , p_silentDrop_strb
  , p_silentDrop_strb_masked
  };

  delay_1_w_stalling
  
  #(.DELAY_EN                              (1)
   ,.WD                                    (P_INTF_WIDTH)
   ,.CAN_STALL                             (1)
  )
  u_pdly1
  (
    .clk        (slv_aclk),
    .rst_n      (slv_aresetn),
    .din        (p_tlp_intf),
    .stallout   (pdly1_halt),
    .clear      (1'b0),

    .dout       (pdly1_p_tlp_intf),
    .stall      (s_pdcmp_halt)
  );

  // Halt pipeline
  assign s_pdcmp_halt = pdcmp_halt && (ctl_tlp_hv || ctl_tlp_dv || ctl_tlp_eot);

// -------------------------------------------------------------------------------------
// Assign outputs
// -------------------------------------------------------------------------------------
  assign { ctl_tlp_byte_en
         , ctl_tlp_dv
         , ctl_tlp_eot
         , ctl_tlp_hv
         , ctl_tlp_fmt
         , ctl_tlp_byte_len
         , ctl_p_req_info_pass
         , ctl_tlp_addr
         , ctl_tlp_data
         , ctl_tlp_strb
         , ctl_tlp_ep_strb
         , ctl_tlp_silentDrop_strb
         , ctl_tlp_silentDrop_strb_masked
         } = pdly1_p_tlp_intf;

// -------------------------------------------------------------------------------------
// Functions
// -------------------------------------------------------------------------------------
  function automatic [SLV_BUS_ADDR_WIDTH -1:0] swap_addr_par;
    input [SLV_BUS_ADDR_WIDTH -1:0]   in_addr;
    integer i,j;
    begin
      swap_addr_par =0;
      for (i=0; i<SLAVE_BUS_ADDR_PAR_WD; i=i+1) begin
        for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
            swap_addr_par[i*CX_RAS_PROT_RANGE +j] = in_addr[i*CX_RAS_PROT_RANGE +j +i];
        end
        swap_addr_par[SLV_BUS_ADDR_WIDTH - SLAVE_BUS_ADDR_PAR_WD +i] = in_addr[(i+1)*CX_RAS_PROT_RANGE +i];
      end
    end
  endfunction

  function automatic fn_ncbe_fbe;
    input   [3:0] s_fbe;
    reg           ncbe;
    begin
      case(s_fbe)
        // Allowed combinations of non-contiguous byte enables
        4'b0101,
        4'b1001,
        4'b1010,
        4'b1011,
        4'b1101: ncbe = 1'b1; // Non-Contiguous
        default: ncbe = 1'b0; // Contiguous
      endcase
      fn_ncbe_fbe = ncbe;
    end
  endfunction

// Determines if a 2DW Request has Non-Contiguous Byte Enables
  function automatic fn_ncbe_lbe_fbe;
    input [7:0] s_tlp_lbe_fbe;
    reg           ncbe;
    begin
      case(s_tlp_lbe_fbe)
        // Allowed combinations of contiguous byte enables
        8'b1111_1111,
        8'b1111_1110,
        8'b1111_1100,
        8'b1111_1000,
        8'b0111_1111,
        8'b0111_1110,
        8'b0111_1100,
        8'b0111_1000,
        8'b0011_1111,
        8'b0011_1110,
        8'b0011_1100,
        8'b0011_1000,
        8'b0001_1111,
        8'b0001_1110,
        8'b0001_1100,
        8'b0001_1000: ncbe = 1'b0; // Contiguous
        default     : ncbe = 1'b1; // Non-Contiguous
      endcase
      // Non-contiguous byte enables and lbe != 0.
      fn_ncbe_lbe_fbe = ncbe && (s_tlp_lbe_fbe[7:4] != 4'b0);
    end
  endfunction

endmodule
