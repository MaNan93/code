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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_rx_blockalign.sv#11 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture receiver side block align module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_rx_blockalign

  import serdes_pipe_pkg::*;
#(
  parameter int  BUF_WD = BLOCK_WD - 1
) (
  // ------------- input -----------------
  input logic                               rx_clk,
  input logic                               rx_rst_n,
  input logic                               rx_sync_rst,
  input logic                               sync_hdr_bypass_en,
  input logic                               deskew_aligned_to_unaligned,
  input logic                               flit_mode_enable,
  input logic                               encdec_8b10b,
  input logic [PHY_RAW_WD-1:0]              raw_width,
  input logic [RATE_WD-1:0]                 pipe_rate,
  input logic [$bits(pipe_data128b_t)-1:0]  pipe_rxdata,
  input logic [BUF_WD-1:0]                  buf_rxdata,
  input logic                               pipe_blockaligncontrol,
  input logic                               pipe_loopback_slave,
  input logic                               eios_found,
  input logic                               err_syncheader_bypass,
  input logic                               err_undef_syncheader,
  input logic                               err_undef_skp,
  input logic                               err_skp_wo_skp_end,
  input logic                               err_skp_after_sds,
  input logic                               err_estore_overflow,
  input logic                               err_estore_underflow,
  // ------------- output ----------------
  output logic                              eieos_str_found,
  output logic                              block_aligned,
  output logic                              align_detected,
  output logic [PHY_RAW_WD-1:0]             align_offset
);

// --------------------------------------------------------------------------------
//  Common internal parameter / type
// --------------------------------------------------------------------------------

  typedef struct packed {
    logic                   en;
    logic [PHY_RAW_WD-1:0]  offset;
  }  osfind_t;

// --------------------------------------------------------------------------------
//  Common internal signal
// --------------------------------------------------------------------------------
  logic [BLOCK_WD-1:0]  eieos_fmt;

  always_comb begin: eieos_fmt_PROC
    case(pipe_rate)
      RATE_WD'(`GEN4_RATE): eieos_fmt = GEN4_EIEOS_FMT;
      RATE_WD'(`GEN5_RATE): eieos_fmt = GEN5_EIEOS_FMT;
      RATE_WD'(`GEN6_RATE): eieos_fmt = {GEN6_EIEOS_FMT,2'b00};
      default: eieos_fmt = GEN3_EIEOS_FMT;
    endcase
  end

  logic  align_en;
  assign align_en = !encdec_8b10b && (pipe_blockaligncontrol && !pipe_loopback_slave);

  logic [$bits(pipe_data128b_t)+BUF_WD-1:0]  concat_rxdata;
  assign concat_rxdata = {pipe_rxdata, buf_rxdata};

// --------------------------------------------------------------------------------
//  EIEOS finding
// --------------------------------------------------------------------------------
  osfind_t  eieos_fmt_found;

  always_comb begin: eieos_fmt_found_PROC
    eieos_fmt_found = '0;
    for(int i = 0; i < $bits(pipe_data128b_t); i++) begin
      if(i < raw_width) begin
        if(concat_rxdata[i+:$bits(eieos_fmt)] == eieos_fmt) begin
          eieos_fmt_found.en = 1'h1;
          eieos_fmt_found.offset = PHY_RAW_WD'(i);
        end
      end
    end
  end

  // `ifdef CX_GEN6_SPEED
  // function automatic integer  check_gen6_eieos_fmt (
  //   logic [(BLOCK_WD-SYNC_HDR_WD)-1:0] data
  // );
  //   integer ret;
  //   ret = 0;
  //   for(int i = 0; i < 4; i++) begin
  //     if(data[i*8+:40] == 'h00_00_00_00_00) begin
  //       for(int j = 0; j < 4; j++) begin
  //         if(data[j*8+64+:40] == 'hAA_AA_AA_AA_AA) begin
  //           if(data[7:0] == 'h00 || data[71:64] == 'hAA) begin 
  //             ret = 1;
  //           end
  //         end
  //       end
  //     end
  //   end
  //   return ret;
  // endfunction
  // `endif // CX_GEN6_SPEED

  osfind_t  eieos_wo_synchdr_fmt_found;

  always_comb begin: eieos_wo_synchdr_fmt_found_PROC
    eieos_wo_synchdr_fmt_found = '0;
    for(int i = $bits(pipe_data128b_t) - 1; i >= 0; i--) begin
      if(i < raw_width) begin
        if(concat_rxdata[i+SYNC_HDR_WD+:(BLOCK_WD-SYNC_HDR_WD)] == eieos_fmt[BLOCK_WD-1:SYNC_HDR_WD]) begin
            eieos_wo_synchdr_fmt_found.offset = PHY_RAW_WD'(i);
            eieos_wo_synchdr_fmt_found.en = 1'h1;
        end
      end
    end
  end


  // In Gen6: To mask the unexpected block alignment issue(with Idle data) when polarity reverse is enabled.
  // Masked for first 3 cycles after buf_rxdata out of reset.
  logic block_align_det_en;
  logic block_align_det_en_d1;
  logic block_align_det_en_d2;
  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: block_align_det_PROC
    if(!rx_rst_n) begin
      block_align_det_en    <= #`TP 1'h0;
      block_align_det_en_d1 <= #`TP 1'h0;
      block_align_det_en_d2 <= #`TP 1'h0;
    end
    else if(rx_sync_rst) begin
      block_align_det_en    <= #`TP 1'h0;
      block_align_det_en_d1 <= #`TP 1'h0;
      block_align_det_en_d2 <= #`TP 1'h0;
    end
    else begin
      block_align_det_en    <= #`TP 1'h1;
      block_align_det_en_d1 <= #`TP block_align_det_en;
      block_align_det_en_d2 <= #`TP block_align_det_en_d1;
    end
  end
  osfind_t  eieos_found;

  always_comb begin: eieos_found_PROC
    eieos_found = eieos_fmt_found;
    if(sync_hdr_bypass_en || (pipe_rate inside {`GEN6_RATE})) begin
      eieos_found = eieos_wo_synchdr_fmt_found;
    end
  end

  assign eieos_str_found = eieos_found.en && block_align_det_en_d2;

// ------------------------------------------------------------------------------
//  Block align
// --------------------------------------------------------------------------------
  logic  err_detected;

  always_comb begin: err_detected_PROC
    err_detected = err_undef_syncheader || err_undef_skp || err_estore_overflow || err_estore_underflow;
    if(sync_hdr_bypass_en) begin
      err_detected = err_detected || err_syncheader_bypass;
    end
    if(pipe_rate inside {`GEN6_RATE}) begin
      err_detected = err_detected || err_syncheader_bypass || err_skp_wo_skp_end || err_skp_after_sds;
    end
    if(sync_hdr_bypass_en && flit_mode_enable) begin
      err_detected = err_detected || err_syncheader_bypass || err_skp_after_sds;
    end
  end

  logic  align_lost;
// TBD
  logic  deskew_release;
  assign deskew_release = deskew_aligned_to_unaligned && !sync_hdr_bypass_en;
  assign align_detected = align_en && eieos_found.en && block_align_det_en_d2;
  assign align_offset = !block_align_det_en_d2 ? '0: eieos_found.offset;
  assign align_lost = !pipe_loopback_slave && (eios_found || err_detected || deskew_release);

  always_ff @(posedge rx_clk or negedge rx_rst_n) begin: block_aligned_PROC
    if(!rx_rst_n) begin
      block_aligned <= #`TP 1'h0;
    end
    else if(rx_sync_rst) begin
      block_aligned <= #`TP 1'h0;
    end
    else if(align_lost) begin
      block_aligned <= #`TP 1'h0;
    end
    else if(align_detected) begin
      block_aligned <= #`TP 1'h1;
    end
  end

endmodule: serdes_pipe_rx_blockalign
