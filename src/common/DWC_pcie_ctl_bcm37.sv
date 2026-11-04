
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
// Description : DWC_pcie_ctl_bcm37.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: fa2180ed
//
////////////////////////////////////////////////////////////////////////////////




module DWC_pcie_ctl_bcm37 (
    clk_s,
    rst_s_n,
    init_s_n,
    clr_s,
    clr_sync_s,
    clr_in_prog_s,
    clr_cmplt_s,

    clk_d,
    rst_d_n,
    init_d_n,
    clr_d,
    clr_in_prog_d,
    clr_sync_d,
    clr_cmplt_d
    );

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

parameter integer F_SYNC_TYPE  = 2;  // RANGE 0 to 4
parameter integer R_SYNC_TYPE  = 2;  // RANGE 0 to 4
parameter integer REG_IN_PROG  = 1;  // RANGE 0 to 1
parameter integer VERIF_EN     = 1;  // RANGE 0 to 4


localparam F_SYNC_TYPE_P8                 = F_SYNC_TYPE + 8;
localparam R_SYNC_TYPE_P8                 = R_SYNC_TYPE + 8;
localparam PS_CLR_FROM_DEST_VERIF_EN      = ((VERIF_EN==2)?4:((VERIF_EN==3)?1:VERIF_EN));
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

input                   clk_s;         // clock input from source domain
input                   rst_s_n;       // active low asynchronous reset from source domain
input                   init_s_n;      // active low synchronous reset from source domain
input                   clr_s;         // active high clear from source domain
output                  clr_sync_s;    // clear to source domain sequential devices
output                  clr_in_prog_s; // clear in progress status to source domain
output                  clr_cmplt_s;   // clear sequence complete (pulse)

input                   clk_d;         // clock input from destination domain
input                   rst_d_n;       // active low asynchronous reset from destination domain
input                   init_d_n;      // active low synchronous reset from destination domain
input                   clr_d;         // active high clear from destination domain
output                  clr_in_prog_d; // clear in progress status to source domain
output                  clr_sync_d;    // clear to destination domain sequential devices (pulse)
output                  clr_cmplt_d;   // clear sequence complete (pulse)


wire                         drs_clr_s;
wire                         drs_clr_d;

wire                         clr_s_re_cc;
wire                         clr_s_merge_cc;


reg   [1:0]                  clr_vec_s;

wire  [1:0]                  next_clr_vec_s;

wire                         next_clr_in_prog_d_int;
reg                          clr_in_prog_d_int;
reg                          clr_in_prog_d_int_d1;


wire                         clr_d_merge;

wire                         clr_sync_s_int;
reg                          clr_sync_s_int_d1;

wire                         start_ack_d_event;
reg                          start_ack_d;
wire                         next_start_ack_d;

wire                         clr_ack_s;

reg                          clr_cmplt_s_int;
wire                         next_clr_cmplt_s_int;
wire                         clr_cmplt_s;

reg                          clr_cmplt_d_int;
wire                         next_clr_cmplt_d_int;
wire                         clr_cmplt_d;

wire                         next_event_hold;
wire                         rls_event_hold;
reg                          event_hold;

wire                         set_clr_d_mask;
wire                         unset_clr_d_mask;
wire                         next_clr_d_mask;
reg                          clr_d_mask;
wire                         clr_d_merge_masked;






`ifndef SYNTHESIS
  initial begin
    if (((F_SYNC_TYPE > 0)&&(F_SYNC_TYPE < 8))&&(BCM_MSG_VERBOSITY[2]==1'b1))
       $display("Information: *** Instance %m module is using the <Reset Sequence Synchronizer (12)> Clock Domain Crossing Method ***");
  end

`endif


assign drs_clr_s = clr_s;
assign drs_clr_d = clr_d;


generate
  if (REG_IN_PROG == 0) begin : GEN_CLR_D_MASK_RIP0
    reg clr_d_merge_d1;

    always @ (posedge clk_d or negedge rst_d_n) begin : clr_d_merge_d1_PROC
      if (rst_d_n == 1'b0) begin
        clr_d_merge_d1       <= 1'b0;
      end else if (init_d_n == 1'b0) begin
        clr_d_merge_d1       <= 1'b0;
      end else begin
        clr_d_merge_d1       <= clr_d_merge;
      end
    end

    assign set_clr_d_mask = (clr_d_merge && (!clr_d_merge_d1)) || ((next_clr_in_prog_d_int && (!clr_in_prog_d_int)) && clr_d_merge);
  end else begin : GEN_CLR_D_MASK_RIP1
    assign set_clr_d_mask = next_clr_in_prog_d_int && (!clr_in_prog_d_int);
  end
endgenerate

assign unset_clr_d_mask = !next_clr_in_prog_d_int && clr_in_prog_d_int;
assign next_clr_d_mask  = (set_clr_d_mask && (!unset_clr_d_mask)) ? 1'b1 :
                            (unset_clr_d_mask) ? 1'b0 : clr_d_mask;


DWC_pcie_ctl_bcm22
 #(1, F_SYNC_TYPE_P8, VERIF_EN, 1, 0) U_PS_CLR_FROM_SRC (
            .clk_s(clk_s),
            .rst_s_n(rst_s_n),
            .init_s_n(init_s_n),
            .event_s(drs_clr_s),
            .clk_d(clk_d),
            .rst_d_n(rst_d_n),
            .init_d_n(init_d_n),
            .event_d(clr_s_re_cc)
            );


wire                         clr_s_cc;
wire                         drs_clr_s_cc;


  assign drs_clr_s_cc = drs_clr_s;
  DWC_pcie_ctl_bcm21
   #(1, F_SYNC_TYPE_P8, VERIF_EN, 0) U_SYNC_CLR_S(
        .clk_d(clk_d),
        .rst_d_n(rst_d_n),
        .data_s(drs_clr_s_cc),
        .data_d(clr_s_cc) );

assign clr_s_merge_cc = clr_s_re_cc || clr_s_cc;



assign clr_d_merge              = clr_s_merge_cc || drs_clr_d;
assign clr_d_merge_masked       = clr_d_merge && (!clr_d_mask);

DWC_pcie_ctl_bcm22
 #(0, R_SYNC_TYPE_P8, PS_CLR_FROM_DEST_VERIF_EN, 0, 0) U_PS_CLR_FROM_DEST (
            .clk_s(clk_d),
            .rst_s_n(rst_d_n),
            .init_s_n(init_d_n),
            .event_s(clr_d_merge_masked),
            .clk_d(clk_s),
            .rst_d_n(rst_s_n),
            .init_d_n(init_s_n),
            .event_d(clr_sync_s_int)
            );

DWC_pcie_ctl_bcm22
 #(0, F_SYNC_TYPE_P8, VERIF_EN, 0, 0) U_PS_FB_TO_DEST (
            .clk_s(clk_s),
            .rst_s_n(rst_s_n),
            .init_s_n(init_s_n),
            .event_s(clr_sync_s_int_d1),
            .clk_d(clk_d),
            .rst_d_n(rst_d_n),
            .init_d_n(init_d_n),
            .event_d(start_ack_d_event)
            );


// spyglass disable_block Ac_conv01
// SMD: Checks sequential convergence of same-domain signals synchronized in the same destination domain
// SJ: The two signals that have been synchronized and converged on this portion of logic are guaranteed never to both be high at the same time and that they will never be changing at the same rising edge of this clock.
// spyglass disable_block Ac_conv02
// SMD: Checks combinational convergence of same-domain signals synchronized in the same destination domain
// SJ: The two signals that have been synchronized and converged on this portion of logic are guaranteed never to both be high at the same time and that they will never be changing at the same rising edge of this clock.
assign rls_event_hold   = !start_ack_d_event && (!clr_d_merge && event_hold);
// spyglass enable_block Ac_conv02
assign next_event_hold  = (start_ack_d_event && clr_d_merge) ? 1'b1 :
                            rls_event_hold ? 1'b0 : event_hold;

assign next_start_ack_d  = (start_ack_d_event && (!clr_d_merge) && (!event_hold)) ||
                           rls_event_hold;
// spyglass enable_block Ac_conv01


DWC_pcie_ctl_bcm22
 #(0, R_SYNC_TYPE_P8, VERIF_EN, 0, 0) U_PS_ACK_TO_SRC (
            .clk_s(clk_d),
            .rst_s_n(rst_d_n),
            .init_s_n(init_d_n),
            .event_s(start_ack_d),
            .clk_d(clk_s),
            .rst_d_n(rst_s_n),
            .init_d_n(init_s_n),
            .event_d(clr_ack_s)
            );

// spyglass disable_block Ac_conv01
// SMD: Checks sequential convergence of same-domain signals synchronized in the same destination domain
// SJ: The two signals that have been synchronized and converged on this portion of logic are guaranteed never to both be high at the same time and that they will never be changing at the same rising edge of this clock.
// spyglass disable_block Ac_conv02
// SMD: Checks combinational convergence of same-domain signals synchronized in the same destination domain
// SJ: The two signals that have been synchronized and converged on this portion of logic are guaranteed never to both be high at the same time and that they will never be changing at the same rising edge of this clock.
  assign next_clr_vec_s         = ((clr_sync_s_int == 1'b1) && (clr_ack_s == 1'b0)) ? {clr_vec_s[0], 1'b1} :
                                      ((clr_sync_s_int == 1'b0) && (clr_ack_s == 1'b1)) ?  {1'b0, clr_vec_s[1]} :
                                         clr_vec_s;
// spyglass enable_block Ac_conv01
// spyglass enable_block Ac_conv02

  assign next_clr_cmplt_s_int   = ~next_clr_vec_s[0] && clr_vec_s[0];


  always @ (posedge clk_s or negedge rst_s_n) begin : posedge_src_registers_PROC
    if (rst_s_n == 1'b0) begin
      clr_vec_s            <= 2'b00;
      clr_cmplt_s_int      <= 1'b0;
      clr_sync_s_int_d1    <= 1'b0;
    end else if (init_s_n == 1'b0) begin
      clr_vec_s            <= 2'b00;
      clr_cmplt_s_int      <= 1'b0;
      clr_sync_s_int_d1    <= 1'b0;
    end else begin
      clr_vec_s            <= next_clr_vec_s;
      clr_cmplt_s_int      <= next_clr_cmplt_s_int;
      clr_sync_s_int_d1    <= clr_sync_s_int;
    end
  end


  assign next_clr_in_prog_d_int  = ((clr_d_merge_masked == 1'b1) && (start_ack_d == 1'b0)) ? 1'b1 :
                                       ((clr_d_merge_masked == 1'b0) && (start_ack_d == 1'b1)) ? 1'b0 :
                                          clr_in_prog_d_int;

  assign next_clr_cmplt_d_int   = ~clr_in_prog_d_int && clr_in_prog_d_int_d1;

  always @ (posedge clk_d or negedge rst_d_n) begin : posedge_dest_registers_PROC
    if (rst_d_n == 1'b0) begin
      clr_d_mask           <= 1'b0;
      event_hold           <= 1'b0;
      clr_in_prog_d_int    <= 1'b0;
      clr_in_prog_d_int_d1 <= 1'b0;
      start_ack_d          <= 1'b0;
      clr_cmplt_d_int      <= 1'b0;
    end else if (init_d_n == 1'b0) begin
      clr_d_mask           <= 1'b0;
      event_hold           <= 1'b0;
      clr_in_prog_d_int    <= 1'b0;
      clr_in_prog_d_int_d1 <= 1'b0;
      start_ack_d          <= 1'b0;
      clr_cmplt_d_int      <= 1'b0;
    end else begin
      clr_d_mask           <= next_clr_d_mask;
      event_hold           <= next_event_hold;
      clr_in_prog_d_int    <= next_clr_in_prog_d_int;
      clr_in_prog_d_int_d1 <= clr_in_prog_d_int;
      start_ack_d          <= next_start_ack_d;
      clr_cmplt_d_int      <= next_clr_cmplt_d_int;
    end
  end


  assign clr_sync_s      = clr_sync_s_int;
generate
  if (REG_IN_PROG == 1) begin : GEN_CIPS1
    wire clr_in_prog_s_int;
    assign clr_in_prog_s_int = clr_vec_s[0];
    assign clr_in_prog_s = clr_in_prog_s_int;
  end else begin : GEN_CIPS0
    assign clr_in_prog_s = next_clr_vec_s[0];
  end
endgenerate

  assign clr_cmplt_s     = clr_cmplt_s_int;

generate
  if (REG_IN_PROG == 1) begin : GEN_CIPD1
    assign clr_in_prog_d = clr_in_prog_d_int_d1;
  end else begin : GEN_CIPD0
     assign clr_in_prog_d = clr_in_prog_d_int;
  end
endgenerate

  assign clr_sync_d      = start_ack_d;
  assign clr_cmplt_d     = clr_cmplt_d_int;


`ifdef DWC_BCM_SNPS_ASSERT_ON
`ifndef SYNTHESIS
generate
  if ((F_SYNC_TYPE==0) || (R_SYNC_TYPE==0)) begin : GEN_SINGLE_CLOCK_CANDIDATE
    DWC_pcie_ctl_sva07 #(F_SYNC_TYPE, R_SYNC_TYPE) P_CDC_CLKCOH (.*);
  end
endgenerate
`endif // SYNTHESIS
`endif // DWC_BCM_SNPS_ASSERT_ON

// spyglass enable_block W146
endmodule
