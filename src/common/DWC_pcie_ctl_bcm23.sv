
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

//
// Description : DWC_pcie_ctl_bcm23.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 1585d6e8
//
////////////////////////////////////////////////////////////////////////////////



module DWC_pcie_ctl_bcm23 (
             clk_s,
             rst_s_n,
             init_s_n,
             event_s,
             ack_s,
             busy_s,

             clk_d,
             rst_d_n,
             init_d_n,
             event_d
             );

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

 parameter integer REG_EVENT    = 1;    // RANGE 0 to 1
 parameter integer REG_ACK      = 1;    // RANGE 0 to 1
 parameter integer ACK_DELAY    = 1;    // RANGE 0 to 1
 parameter integer F_SYNC_TYPE  = 2;    // RANGE 0 to 4
 parameter integer R_SYNC_TYPE  = 2;    // RANGE 0 to 4
 parameter integer VERIF_EN     = 1;    // RANGE 0 to 4
 parameter integer PULSE_MODE   = 0;    // RANGE 0 to 3
 parameter integer SVA_TYPE     = 0;

 localparam F_SYNC_TYPE_P8 = F_SYNC_TYPE + 8;
 localparam R_SYNC_TYPE_P8 = R_SYNC_TYPE + 8;
`ifndef SYNTHESIS
`ifdef DWC_BCM_MSG_VERBOSITY
  localparam BCM_MSG_VERBOSITY = `DWC_BCM_MSG_VERBOSITY;
`else
  localparam BCM_MSG_VERBOSITY_DEF = 32'hfffffff1;

  `ifndef DWC_DISABLE_CDC_METHOD_REPORTING
    localparam BCM_MSG_VERBOSITY_TMP2 = 32'h00000004;
  `else
    localparam BCM_MSG_VERBOSITY_TMP2 = 32'h0;
  `endif

  localparam BCM_MSG_VERBOSITY = BCM_MSG_VERBOSITY_DEF |
               BCM_MSG_VERBOSITY_TMP2;
`endif
`endif

input  clk_s;                   // clock input for source domain
input  rst_s_n;                 // active low async. reset in clk_s domain
input  init_s_n;                // active low sync. reset in clk_s domain
input  event_s;                 // event pulseack input (active high event)
output ack_s;                   // event pulseack output (active high event)
output busy_s;                  // event pulseack output (active high event)

input  clk_d;                   // clock input for destination domain
input  rst_d_n;                 // active low async. reset in clk_d domain
input  init_d_n;                // active low sync. reset in clk_d domain
output event_d;                 // event pulseack output (active high event)

wire   tgl_s_event_cc;
wire   tgl_d_event_cc;
reg    tgl_s_event_q;
reg    tgl_s_evnt_nfb_cdc;
wire   tgl_s_ack_x;

wire   tgl_s_event_x;
wire   tgl_d_event_d;
wire   tgl_d_event_a;

wire   tgl_s_ack_d;
reg    tgl_s_ack_q;
wire   nxt_busy_state;
reg    busy_state;
wire   tgl_d_event_dx;    // event seen via edge detect (before registered)
reg    tgl_d_event_q;     // registered version of event seen


`ifndef SYNTHESIS
  initial begin
    if (((F_SYNC_TYPE > 0)&&(F_SYNC_TYPE < 8))&&(BCM_MSG_VERBOSITY[2]==1'b1))
       $display("Information: *** Instance %m module is using the <Toggle Type Event Sychronizer with busy and acknowledge (3)> Clock Domain Crossing Method ***");
  end

`endif


  always @ (posedge clk_s or negedge rst_s_n) begin : event_lauch_reg_PROC
    if (rst_s_n == 1'b0) begin
      tgl_s_event_q    <= 1'b0;
      tgl_s_evnt_nfb_cdc<= 1'b0;
      busy_state       <= 1'b0;
      tgl_s_ack_q      <= 1'b0;
    end else if (init_s_n == 1'b0) begin
      tgl_s_event_q    <= 1'b0;
      tgl_s_evnt_nfb_cdc<= 1'b0;
      busy_state       <= 1'b0;
      tgl_s_ack_q      <= 1'b0;
    end else begin
      tgl_s_event_q    <= tgl_s_event_x;
      tgl_s_evnt_nfb_cdc<= tgl_s_event_x;
      busy_state       <= nxt_busy_state;
      tgl_s_ack_q      <= tgl_s_ack_d;
    end
  end // always : event_lauch_reg_PROC



  assign tgl_s_event_cc = tgl_s_evnt_nfb_cdc;
  DWC_pcie_ctl_bcm21
   #(1, F_SYNC_TYPE_P8, VERIF_EN, SVA_TYPE) U_DW_SYNC_F(
        .clk_d(clk_d),
        .rst_d_n(rst_d_n),
        .data_s(tgl_s_event_cc),
        .data_d(tgl_d_event_d) );


  assign tgl_d_event_cc = tgl_d_event_a;
  DWC_pcie_ctl_bcm21
   #(1, R_SYNC_TYPE_P8, VERIF_EN, SVA_TYPE) U_DW_SYNC_R(
        .clk_d(clk_s),
        .rst_d_n(rst_s_n),
        .data_s(tgl_d_event_cc),
        .data_d(tgl_s_ack_d) );

  always @ (posedge clk_d or negedge rst_d_n) begin : second_sync_PROC
    if (rst_d_n == 1'b0) begin
      tgl_d_event_q      <= 1'b0;
    end else if (init_d_n == 1'b0) begin
      tgl_d_event_q      <= 1'b0;
    end else begin
      tgl_d_event_q      <= tgl_d_event_d;
    end
  end // always


generate

    if (PULSE_MODE <= 0) begin : GEN_PLSMD0
      assign tgl_s_event_x = tgl_s_event_q   ^ (event_s && (! busy_state));
    end

    if (PULSE_MODE == 1) begin : GEN_PLSMD1
      reg  event_s_cap;
      always@ (posedge clk_s or negedge rst_s_n) begin : event_s_cap_PROC
        if (rst_s_n == 1'b0) begin
          event_s_cap <= 1'b0;
        end else if (init_s_n == 1'b0) begin
          event_s_cap <= 1'b0;
        end else begin
          event_s_cap <= event_s;
        end
      end

      assign tgl_s_event_x = tgl_s_event_q   ^ (! busy_state &(event_s & (! event_s_cap)));
    end

    if (PULSE_MODE == 2) begin : GEN_PLSMD2
      reg  event_s_cap;
      always @ (posedge clk_s or negedge rst_s_n) begin : event_s_cap_PROC
        if (rst_s_n == 1'b0) begin
          event_s_cap <= 1'b0;
        end else if (init_s_n == 1'b0) begin
          event_s_cap <= 1'b0;
        end else begin
          event_s_cap <= event_s;
        end
      end

      assign tgl_s_event_x = tgl_s_event_q  ^ (! busy_state &(event_s_cap & (!event_s)));
    end

    if (PULSE_MODE >= 3) begin : GEN_PLSMD3
      reg  event_s_cap;
      always @ (posedge clk_s or negedge rst_s_n) begin : event_s_cap_PROC
        if (rst_s_n == 1'b0) begin
          event_s_cap <= 1'b0;
        end else if (init_s_n == 1'b0) begin
          event_s_cap <= 1'b0;
        end else begin
          event_s_cap <= event_s;
        end
      end

      assign tgl_s_event_x = tgl_s_event_q ^ (! busy_state & (event_s ^ event_s_cap));
    end

endgenerate
  assign tgl_d_event_dx = tgl_d_event_d ^ tgl_d_event_q;
  //assign tgl_s_event_x  = tgl_s_event_q ^ (event_s & ! busy_s);
  assign tgl_s_ack_x    = tgl_s_ack_d   ^ tgl_s_ack_q;
  assign nxt_busy_state = tgl_s_event_x ^ tgl_s_ack_d;

  generate
    if (REG_EVENT == 0) begin : GEN_RGEVT0
      assign event_d       = tgl_d_event_dx;
    end

    else begin : GEN_RGRVT1
      reg    tgl_d_event_qx;      // xor of dest dom data and registered version

      always @ (posedge clk_d or negedge rst_d_n) begin : tgl_d_event_qx_PROC
        if (rst_d_n == 1'b0) begin
          tgl_d_event_qx     <= 1'b0;
        end else if (init_d_n == 1'b0) begin
          tgl_d_event_qx     <= 1'b0;
        end else begin
          tgl_d_event_qx     <= tgl_d_event_dx;
        end
      end

      assign event_d       = tgl_d_event_qx;
    end
  endgenerate

  generate
    if (REG_ACK == 0) begin : GEN_RGACK0
      assign ack_s         = tgl_s_ack_x;
    end

    else begin : GEN_RGACK1
      reg    srcdom_ack;

      always @ (posedge clk_s or negedge rst_s_n) begin : srcdom_ack_PROC
        if (rst_s_n == 1'b0) begin
          srcdom_ack <= 1'b0;
        end else if (init_s_n == 1'b0) begin
          srcdom_ack <= 1'b0;
        end else begin
          srcdom_ack <= tgl_s_ack_x;
        end
      end

      assign ack_s         = srcdom_ack;
    end
  endgenerate

  generate
    if (ACK_DELAY == 0) begin : GEN_AKDLY0
      assign tgl_d_event_a = tgl_d_event_d;
    end

    else begin : GEN_AKDLY1
      reg tgl_d_event_nfb_cdc;

      always @ (posedge clk_d or negedge rst_d_n) begin : third_sync_PROC
        if (rst_d_n == 1'b0) begin
          tgl_d_event_nfb_cdc <= 1'b0;
        end else if (init_d_n == 1'b0) begin
          tgl_d_event_nfb_cdc <= 1'b0;
        end else begin
          tgl_d_event_nfb_cdc <= tgl_d_event_d;
        end
      end // always

      assign tgl_d_event_a = tgl_d_event_nfb_cdc;
    end
  endgenerate


  assign busy_s = busy_state;

`ifdef DWC_BCM_SNPS_ASSERT_ON
`ifndef SYNTHESIS

  DWC_pcie_ctl_sva03 #(F_SYNC_TYPE&7,  PULSE_MODE) P_PULSEACK_SYNC_HS (.*);

  generate if (SVA_TYPE == 1) begin : GEN_SVATP_EQ_1
    DWC_pcie_ctl_sva02 #(
      .F_SYNC_TYPE    (F_SYNC_TYPE&7),
      .PULSE_MODE     (PULSE_MODE   )
    ) P_PULSE_SYNC_HS (
        .clk_s        (clk_s        )
      , .rst_s_n      (rst_s_n      )
      , .rst_d_n      (rst_d_n      )
      , .init_s_n     (init_s_n     )
      , .init_d_n     (init_d_n     )
      , .event_s      (event_s      )
      , .event_d      (event_d      )
    );
  end endgenerate

  generate if ((F_SYNC_TYPE==0) || (R_SYNC_TYPE==0)) begin : GEN_SINGLE_CLOCK_CANDIDATE
    DWC_pcie_ctl_sva07 #(F_SYNC_TYPE, R_SYNC_TYPE) P_CDC_CLKCOH (.*);
  end endgenerate

`endif // SYNTHESIS
`endif // DWC_BCM_SNPS_ASSERT_ON

// spyglass enable_block W146
endmodule
