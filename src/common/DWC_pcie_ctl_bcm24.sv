
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
// Description : DWC_pcie_ctl_bcm24.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: b8f4f6d9
//
////////////////////////////////////////////////////////////////////////////////





module DWC_pcie_ctl_bcm24 (
    clk_s,
    rst_s_n,
    init_s_n,
    en_s,
    count_s,
    offset_count_s,

    clk_d,
    rst_d_n,
    init_d_n,
    count_d
    );

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

parameter integer WIDTH                        = 8;  // RANGE 1 to 32
parameter integer OFFSET                       = 0;  // RANGE 0 to (2**(WIDTH-1) - 1)
parameter integer REG_COUNT_D                  = 1;  // RANGE 0 to 1
parameter integer F_SYNC_TYPE                  = 2;  // RANGE 0 to 4
parameter integer VERIF_EN                     = 1;  // RANGE 0 to 4
parameter integer PIPE_DELAY                   = 0;  // RANGE 0 to 2
parameter integer REG_COUNT_S                  = 1;  // RANGE 0 to 1
parameter integer REG_OFFSET_COUNT_S           = 1;  // RANGE 0 to 1

localparam F_SYNC_TYPE_P8 = F_SYNC_TYPE + 8;
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


input                      clk_s;            // clock input from source domain
input                      rst_s_n;          // active low asynchronous reset from source domain
input                      init_s_n;         // active low synchronous reset from source domain
input                      en_s;             // enable source domain
output [WIDTH-1:0]         count_s;          // binary counter value to source domain
output [WIDTH-1:0]         offset_count_s;   // binary counter OFFSET value to source domain

input                      clk_d;            // clock input from destination domain
input                      rst_d_n;          // active low asynchronous reset from destination domain
// spyglass disable_block W240
// SMD: An input port is never read in the module
// SJ: The following port(s) are not used in certain configurations.
input                      init_d_n;         // active low synchronous reset from destination domain
// spyglass enable_block W240
output [WIDTH-1:0]         count_d;          // binary counter value to destination domain

wire                    drs_en_s;
wire   [WIDTH-1:0]      count_s_int_xor;

wire   [WIDTH-1:0]      next_count_s_int;
wire   [WIDTH:0]        next_count_s_adv;
wire   [WIDTH:0]        temp_count_s_adv;
wire   [WIDTH-1:0]      next_offset_count_s_int;
wire   [WIDTH:0]        next_offset_count_s;
wire   [WIDTH:0]        temp_offset_count_s;
reg    [WIDTH-1:0]      count_s_int;
reg    [WIDTH-1:0]      offset_count_s_int;

wire   [WIDTH-1:0]      bin2gray_s_func_out;
wire   [WIDTH-1:0]      next_bin2gray_s;
reg    [WIDTH-1:0]      bin2gray_s;
reg    [WIDTH-1:0]      bin2gray_s_d1;
reg    [WIDTH-1:0]      bin2gray_s_d2;
wire   [WIDTH-1:0]      bin2gray_s_pipe;
wire   [WIDTH-1:0]      bin2gray_cc;

wire   [WIDTH-1:0]      dw_sync_bin2gray_d;
wire   [WIDTH-1:0]      gray2bin_d_func_out;
wire   [WIDTH-1:0]      forced_value_bin2gray;

wire   [WIDTH-1:0]      count_d_int_xor;

wire   [WIDTH-1:0]      one;



localparam [WIDTH-1:0] END_VALUE = ((32'b1 << WIDTH) - 32'b1) - $unsigned(OFFSET);



`ifndef SYNTHESIS
  initial begin
    if (((F_SYNC_TYPE > 0)&&(F_SYNC_TYPE < 8))&&(BCM_MSG_VERBOSITY[2]==1'b1))
       $display("Information: *** Instance %m module is using the <Gray Coded Synchronizer (4)> Clock Domain Crossing Method ***");
  end

`endif

generate
  if (WIDTH == 1) begin : GEN_ONE_W_EQ_1
    assign one = 1'b1;
  end else begin : GEN_ONE_W_GT_1
    assign one = {{WIDTH-1{1'b0}},1'b1};
  end
endgenerate


// spyglass disable_block ParamWidthMismatch-ML
// SMD: Parameter WIDTH does not match with the value assigned
// SJ: The legal value of RHS parameter cannot exceed the range that the LHS parameter can represent.  Even though there is a WIDTH mismatch, no information is lost in the assignment.
localparam [WIDTH-1:0] FORCED_VALUE   = OFFSET;
// spyglass enable_block ParamWidthMismatch-ML

  assign drs_en_s = en_s;


// spyglass disable_block W164b
// SMD: Identifies assignments in which the LHS WIDTH is greater than the RHS WIDTH
// SJ: In most cases, the expressions in the code are written such that the LHS result is one bit larger than the RHS operands (or they should be at the very least). This is the most conservative approach in having one more bit on the left-hand side (LHS) than the two operands of an expression on the right-hand side (RHS).
  assign temp_count_s_adv = count_s_int_xor + one;
// spyglass enable_block W164b
  assign next_count_s_adv      = ((OFFSET != 0) && (count_s_int_xor == END_VALUE)) ?
                                  {1'b0,FORCED_VALUE} : temp_count_s_adv;

  assign next_count_s_int = (init_s_n == 1'b0) ? FORCED_VALUE :
                              ((drs_en_s == 1'b1) ?  next_count_s_adv[WIDTH-1:0] : count_s_int_xor);

// spyglass disable_block W164b
// SMD: Identifies assignments in which the LHS WIDTH is greater than the RHS WIDTH
// SJ: In most cases, the expressions in the code are written such that the LHS result is one bit larger than the RHS operands (or they should be at the very least). This is the most conservative approach in having one more bit on the left-hand side (LHS) than the two operands of an expression on the right-hand side (RHS).
  assign temp_offset_count_s = offset_count_s_int + one;
// spyglass enable_block W164b
  assign next_offset_count_s     = (count_s_int_xor == END_VALUE) ?
                                       {WIDTH+1{1'b0}} : temp_offset_count_s;

  assign next_offset_count_s_int = (init_s_n == 1'b0) ? {WIDTH{1'b0}} :
                                     ((drs_en_s == 1'b1) ?  next_offset_count_s[WIDTH-1:0] : offset_count_s_int);

  // Gray Code encoder

  function automatic [WIDTH-1:0] func_bin2gray ;
    input [WIDTH-1:0]           f_b;    // input
    begin
      func_bin2gray  = f_b ^ ( f_b >> 1 );
    end
  endfunction

  assign bin2gray_s_func_out = func_bin2gray ( next_count_s_int );
  assign forced_value_bin2gray = func_bin2gray(FORCED_VALUE);

  assign next_bin2gray_s = (drs_en_s == 1'b1) ? (bin2gray_s_func_out ^ forced_value_bin2gray) : bin2gray_s;

  generate
    if (PIPE_DELAY == 0) begin : GEN_B2G_SPIPE_PD_GT_2
      assign bin2gray_s_pipe = bin2gray_s;
    end
    if (PIPE_DELAY == 1) begin : GEN_B2G_SPIPE_PD_EQ_1
      assign bin2gray_s_pipe = bin2gray_s_d1;
    end
    if (PIPE_DELAY >= 2) begin : GEN_B2G_SPIPE_PD_EQ_2
      assign bin2gray_s_pipe = bin2gray_s_d2;
    end
  endgenerate


  assign bin2gray_cc = bin2gray_s_pipe;
  DWC_pcie_ctl_bcm21
   #(WIDTH, F_SYNC_TYPE_P8, VERIF_EN, 0) U_SYNC(
        .clk_d(clk_d),
        .rst_d_n(rst_d_n),
        .data_s(bin2gray_cc),
        .data_d(dw_sync_bin2gray_d) );

// spyglass disable_block Ac_conv01
// SMD: Checks sequential convergence of same-domain signals synchronized in the same destination domain
// SJ: The bus being synchronized and then decoded (i.e. other_addr_decoded), is a Gray transition coded bus and is therefore safe to be followed by converging logic.
// spyglass disable_block Ac_conv02
// SMD: Checks combinational convergence of same-domain signals synchronized in the same destination domain
// SJ: The bus being synchronized and then decoded (i.e. other_addr_decoded), is a Gray transition coded bus and is therefore safe to be followed by converging logic.
  // Gray Code decoder

  function automatic [WIDTH-1:0] func_gray2bin ;
    input [WIDTH-1:0]           f_g;    // input
    reg   [WIDTH-1:0]           f_b;
    integer                     f_i;
    begin
      f_b = {WIDTH{1'b0}};
      for (f_i=WIDTH-1 ; f_i >= 0 ; f_i=f_i-1) begin
        if (f_i < WIDTH-1)
// spyglass disable_block SelfDeterminedExpr-ML
// SMD: Self determined expression found
// SJ: The expression indexing the vector/array will never exceed the bound of the vector/array.
          f_b[f_i] = f_g[f_i] ^ f_b[f_i+1];
// spyglass enable_block SelfDeterminedExpr-ML
        else
          f_b[f_i] = f_g[f_i];
      end // for (i
      func_gray2bin  = f_b;
    end
  endfunction

  assign gray2bin_d_func_out = func_gray2bin ( dw_sync_bin2gray_d );
// spyglass enable_block Ac_conv01
// spyglass enable_block Ac_conv02



  always @ (posedge clk_s or negedge rst_s_n) begin : source_registers_PROC
    if (rst_s_n == 1'b0) begin
      count_s_int          <= {WIDTH{1'b0}};
      offset_count_s_int   <= {WIDTH{1'b0}};
      bin2gray_s           <= {WIDTH{1'b0}};
      bin2gray_s_d1        <= {WIDTH{1'b0}};
// spyglass disable_block W528
// SMD: A signal or variable is set but never read
// SJ: Based on component configuration, this(these) signal(s) or parts of it will not be used to compute the final result.
      bin2gray_s_d2        <= {WIDTH{1'b0}};
// spyglass enable_block W528
    end else if (init_s_n == 1'b0) begin
      count_s_int          <= {WIDTH{1'b0}};
      offset_count_s_int   <= {WIDTH{1'b0}};
      bin2gray_s           <= {WIDTH{1'b0}};
      bin2gray_s_d1        <= {WIDTH{1'b0}};
      bin2gray_s_d2        <= {WIDTH{1'b0}};
    end else begin
      count_s_int          <= (next_count_s_int ^ FORCED_VALUE);
      offset_count_s_int   <= next_offset_count_s_int;
      bin2gray_s           <= next_bin2gray_s;
// spyglass disable_block Reset_sync04
// SMD: Asynchronous resets that are synchronized more than once in the same clock domain
// SJ: Spyglass recognizes every multi-flop synchronizer as a reset synchronizer, hence any design with a reset that feeds more than one synchronizer gets reported as violating this rule. This rule is waivered temporarily.
      bin2gray_s_d1        <= bin2gray_s;
// spyglass enable_block Reset_sync04
      bin2gray_s_d2        <= bin2gray_s_d1;
    end
  end

  assign count_s_int_xor = count_s_int ^ FORCED_VALUE;

generate
  if (REG_COUNT_D == 1) begin : GEN_CNT_D_INT_XOR_RCD_EQ_1
    reg [WIDTH-1:0] count_d_int;
    always @ (posedge clk_d or negedge rst_d_n) begin : dest_registers_PROC
      if (rst_d_n == 1'b0) begin
        count_d_int <= {WIDTH{1'b0}};
      end else if (init_d_n == 1'b0) begin
        count_d_int <= {WIDTH{1'b0}};
      end else begin
// spyglass disable_block Ac_conv01
// SMD: Checks sequential convergence of same-domain signals synchronized in the same destination domain
// SJ: The bus being synchronized and then decoded (i.e. other_addr_decoded), is a Gray transition coded bus and is therefore safe to be followed by converging logic.
        count_d_int <= gray2bin_d_func_out;
// spyglass enable_block Ac_conv01
      end
    end
    assign count_d_int_xor = count_d_int ^ FORCED_VALUE;

  end else begin : GEN_CNT_D_INT_XOR_RCD_NE_1
    assign count_d_int_xor = gray2bin_d_func_out ^ FORCED_VALUE;
  end
endgenerate

generate
  if (REG_COUNT_S == 1) begin : GEN_COUNT_S_RCS_EQ_1
    assign count_s = count_s_int_xor;
  end else begin : GEN_COUNT_S_RCS_NE_1
    assign count_s = next_count_s_int;
  end
endgenerate

generate
  if (REG_OFFSET_COUNT_S == 1) begin : GEN_OFFSET_CNT_S_INIT_ROCS_EQ_1
    assign offset_count_s = offset_count_s_int;
  end else begin : GEN_OFFSET_CNT_S_INIT_ROCS_NE_1
    assign offset_count_s = next_offset_count_s_int;
  end
endgenerate


assign count_d          = count_d_int_xor;

`ifdef DWC_BCM_SNPS_ASSERT_ON
`ifndef SYNTHESIS
  wire rst_all ;
  wire init_all;

  assign rst_all  = rst_s_n & rst_d_n;
  assign init_all = init_s_n & init_d_n;

  DWC_pcie_ctl_sva05 #(WIDTH, F_SYNC_TYPE) P_SVA_GRAY (
        .clk_d(clk_d),
        .rst_d_n(rst_all),
        .init_d_n(init_all),
        .data_s(bin2gray_cc) );

  generate
    if (F_SYNC_TYPE==0) begin : GEN_SINGLE_CLOCK_CANDIDATE
      DWC_pcie_ctl_sva07 #(F_SYNC_TYPE, F_SYNC_TYPE) P_CDC_CLKCOH (.*);
    end
  endgenerate

`endif // SYNTHESIS
`endif // DWC_BCM_SNPS_ASSERT_ON

// spyglass enable_block W146
endmodule
