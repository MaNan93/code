
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
// Description : DWC_pcie_ctl_bcm21.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 7f0d8270
//
////////////////////////////////////////////////////////////////////////////////



`ifdef DWC_BCM21_ENABLE_CELLDEFINE
  `ifndef SYNTHESIS
    //type: DWC_pcie_ctl_bcm21
    `celldefine
  `endif
`endif
module DWC_pcie_ctl_bcm21 (
    clk_d,
    rst_d_n,
    data_s,
    data_d
    );

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

parameter integer WIDTH        = 1;  // RANGE 1 to 1024
parameter integer F_SYNC_TYPE  = 2;  // RANGE 0 to 4
// spyglass disable_block W175
// SMD: A parameter is declared but not used
// SJ: The following parameter(s) are not used in certain GCCM or GSCM configurations.
parameter integer VERIF_EN     = 1;  // RANGE 0 to 5
// spyglass enable_block W175
// spyglass disable_block W175
// SMD: A parameter is declared but not used
// SJ: The following parameter(s) are not used in certain GCCM or GSCM configurations.
parameter integer SVA_TYPE     = 1;
// spyglass enable_block W175


`ifndef SYNTHESIS
`ifdef DWC_BCM_MSG_VERBOSITY
  localparam BCM_MSG_VERBOSITY = `DWC_BCM_MSG_VERBOSITY;
`else
  localparam BCM_MSG_VERBOSITY_DEF = 32'hfffffff1;

  `ifdef DW_REPORT_SYNC_PARAMS
    localparam BCM_MSG_VERBOSITY_TMP1 = 32'h00000002;
  `else
    localparam BCM_MSG_VERBOSITY_TMP1 = 32'h0;
  `endif
  `ifndef DWC_DISABLE_CDC_METHOD_REPORTING
    localparam BCM_MSG_VERBOSITY_TMP2 = 32'h00000004;
  `else
    localparam BCM_MSG_VERBOSITY_TMP2 = 32'h0;
  `endif

  localparam BCM_MSG_VERBOSITY = BCM_MSG_VERBOSITY_DEF |
               BCM_MSG_VERBOSITY_TMP1 | BCM_MSG_VERBOSITY_TMP2;
`endif
`endif


input                   clk_d;      // clock input from destination domain
input                   rst_d_n;    // active low asynchronous reset from destination domain
input  [WIDTH-1:0]      data_s;     // data to be synchronized from source domain
output [WIDTH-1:0]      data_d;     // data synchronized to destination domain



wire   [WIDTH-1:0]      data_s_int;
wire   [WIDTH-1:0]      data_d_int;

`ifndef SYNTHESIS
  `ifdef DWC_BCM_SNPS_ASSERT_ON
wire                    clk_d_stopped;
  `else
    `ifdef DW_MODEL_MISSAMPLES
wire                    clk_d_stopped;
    `endif
  `endif
`endif


`ifndef SYNTHESIS
  initial begin
    if (((F_SYNC_TYPE > 0)&&(F_SYNC_TYPE < 8))&&(BCM_MSG_VERBOSITY[2]==1'b1))
       $display("Information: *** Instance %m module is using the <Double Register Synchronizer (1)> Clock Domain Crossing Method ***");
  end

  initial begin
    if (((F_SYNC_TYPE & 7) > 0) && (BCM_MSG_VERBOSITY[1]==1'b1) && (BCM_MSG_VERBOSITY[2]==1'b1))
      $display("Information: *** Instance %m is configured as follows: WIDTH is: %0d, F_SYNC_TYPE is: %0d ***", WIDTH, (F_SYNC_TYPE & 7));
  end
`endif



`ifdef SYNTHESIS
  assign data_s_int = data_s;
`else
  `ifdef DW_MODEL_MISSAMPLES
  initial begin
  if (BCM_MSG_VERBOSITY[0] == 1'b1)
    $display("Information: %m: *** Running with DW_MODEL_MISSAMPLES defined, VERIF_EN is: %0d ***",
                        VERIF_EN);
  end

     wire disable_missample;
  assign disable_missample = clk_d_stopped;

reg  [WIDTH-1:0]        last_data_dyn, data_s_delta_t;
reg  [WIDTH-1:0]        last_data_s, last_data_s_q, last_data_s_qq;
reg  [WIDTH-1:0]        data_select; initial data_select = {WIDTH{1'b0}};
wire [WIDTH-1:0]        data_s_sel_tmp;
    `ifdef DWC_BCM_SNPS_ASSERT_ON
    `ifdef DWC_BCM_CDC_COVERAGE_REPORT
event                   data_s_ms_vld;
      `endif
      `endif

`ifdef VCS
`ifdef UPF_POWER_AWARE
  (* vcs_reinit *)
`endif
`endif
    initial data_select = {WIDTH{1'b0}};




  generate if ((VERIF_EN % 2) == 1) begin : GEN_HO_VE_ODD
    if ((F_SYNC_TYPE & 7) == 1) begin : GEN_HO_FST_EQ_1
      always @ (negedge clk_d or data_s or rst_d_n) begin : PROC_catch_last_data_VE_EVEN
        data_s_delta_t <= data_s & {WIDTH{rst_d_n}};
        last_data_dyn <= ((disable_missample==1'b1) ? data_s : data_s_delta_t) & {WIDTH{rst_d_n}};
      end // PROC_catch_last_data

      always @ (negedge clk_d or negedge rst_d_n) begin : PROC_missample_hist_odd_VE_EVEN
        if (rst_d_n == 1'b0) begin
          last_data_s <= {WIDTH{1'b0}};
          last_data_s_qq <= {WIDTH{1'b0}};
        end else begin
          last_data_s <= data_s;
          if (disable_missample == 1'b1)
            last_data_s_qq <= data_s;
          else
            last_data_s_qq <= last_data_s_q;
        end
      end
    end else begin : GEN_HO_FST_NE_1
      always @ (posedge clk_d or data_s or rst_d_n) begin : PROC_catch_last_data_VE_EVEN
        data_s_delta_t <= data_s & {WIDTH{rst_d_n}};
        last_data_dyn <= ((disable_missample==1'b1) ? data_s : data_s_delta_t) & {WIDTH{rst_d_n}};
      end // PROC_catch_last_data

      always @ (posedge clk_d or negedge rst_d_n) begin : PROC_missample_hist_odd_VE_EVEN
        if (rst_d_n == 1'b0) begin
          last_data_s <= {WIDTH{1'b0}};
          last_data_s_qq <= {WIDTH{1'b0}};
        end else begin
          last_data_s <= data_s;
          if (disable_missample == 1'b1)
            last_data_s_qq <= data_s;
          else
            last_data_s_qq <= last_data_s_q;
        end
      end
    end
  end else begin : GEN_HO_VE_EVEN
    if ((F_SYNC_TYPE & 7) == 1) begin : GEN_HO_FST_EQ_1
      always @ (posedge clk_d or data_s or rst_d_n) begin : PROC_catch_last_data_VE_ODD
        data_s_delta_t <= data_s & {WIDTH{rst_d_n}};
        last_data_dyn <= ((disable_missample==1'b1) ? data_s : data_s_delta_t) & {WIDTH{rst_d_n}};
      end // PROC_catch_last_data

      always @ (posedge clk_d or negedge rst_d_n) begin : PROC_missample_hist_odd_VE_ODD
        if (rst_d_n == 1'b0) begin
          last_data_s <= {WIDTH{1'b0}};
          last_data_s_qq <= {WIDTH{1'b0}};
        end else begin
          last_data_s <= data_s;
          if (disable_missample == 1'b1)
            last_data_s_qq <= data_s;
          else
            last_data_s_qq <= last_data_s_q;
        end
      end
    end else begin : GEN_HO_FST_NE_1
      always @ (negedge clk_d or data_s or rst_d_n) begin : PROC_catch_last_data_VE_ODD
        data_s_delta_t <= data_s & {WIDTH{rst_d_n}};
        last_data_dyn <= ((disable_missample==1'b1) ? data_s : data_s_delta_t) & {WIDTH{rst_d_n}};
      end // PROC_catch_last_data

      always @ (negedge clk_d or negedge rst_d_n) begin : PROC_missample_hist_odd_VE_ODD
        if (rst_d_n == 1'b0) begin
          last_data_s <= {WIDTH{1'b0}};
          last_data_s_qq <= {WIDTH{1'b0}};
        end else begin
          last_data_s <= data_s;
          if (disable_missample == 1'b1)
            last_data_s_qq <= data_s;
          else
            last_data_s_qq <= last_data_s_q;
        end
      end
    end
  end endgenerate

  generate if ((F_SYNC_TYPE & 7) == 1) begin : GEN_LDSQ_FST_EQ_1
    always @ (negedge clk_d or negedge rst_d_n) begin : PROC_missample_hist_even
      if (rst_d_n == 1'b0) begin
        last_data_s_q <= {WIDTH{1'b0}};
      end else begin
        if (disable_missample == 1'b1)
          last_data_s_q <= data_s;
        else
          last_data_s_q <= last_data_s;
      end
    end // PROC_missample_hist_even
  end else begin : GEN_LDSQ_FST_NE_1
    always @ (posedge clk_d or negedge rst_d_n) begin : PROC_missample_hist_even
      if (rst_d_n == 1'b0) begin
        last_data_s_q <= {WIDTH{1'b0}};
      end else begin
        if (disable_missample == 1'b1)
          last_data_s_q <= data_s;
        else
          last_data_s_q <= last_data_s;
      end
    end // PROC_missample_hist_even
  end endgenerate


  generate if (VERIF_EN == 0) begin : GEN_DSI_VE_EQ_0

    assign data_s_int = data_s;

  end else if ((VERIF_EN == 2) || (VERIF_EN == 3)) begin : GEN_DSI_VE_EQ_2_OR_3

    reg  [WIDTH-1:0] data_select_2; initial data_select_2 = {WIDTH{1'b0}};
    wire [WIDTH-1:0] data_s_sel_0, data_s_sel_1;

  `ifdef VCS
  `ifdef UPF_POWER_AWARE
    (* vcs_reinit *)
  `endif
  `endif
    initial data_select_2 = {WIDTH{1'b0}};

    if (WIDTH < 32) begin : GEN_D_SEL_W_LT_32
      reg [31-WIDTH:0] data_select_lint_ext;
      reg [31-WIDTH:0] data_select_2_lint_ext;
      always @ (data_s or last_data_s) begin : PROC_mk_next_data_select
        if (data_s != last_data_s) begin
  `ifdef DWC_BCM_SV
          {data_select_lint_ext,  data_select  } = $urandom;
          {data_select_2_lint_ext,data_select_2} = $urandom;
  `else
          {data_select_lint_ext,  data_select  } = $random;
          {data_select_2_lint_ext,data_select_2} = $random;
  `endif
        end
      end  // PROC_mk_next_data_select
    end else if (WIDTH == 32) begin : GEN_D_SEL_W_EQ_32
      always @ (data_s or last_data_s) begin : PROC_mk_next_data_select
        if (data_s != last_data_s) begin
  `ifdef DWC_BCM_SV
          data_select   = $urandom;
          data_select_2 = $urandom;
  `else
          data_select   = $random;
          data_select_2 = $random;
  `endif
        end
      end  // PROC_mk_next_data_select
    end else begin : GEN_D_SEL_W_GT_32
  function automatic [WIDTH-1:0] wide_random;
    input [31:0]        in_width;   // should match "WIDTH" parameter -- need one input to satisfy Verilog function requirement

    reg   [WIDTH-1:0]   temp_result;
    reg   [31:0]        rand_slice;
    integer             i, j, base;


    begin
`ifdef DWC_BCM_SV
      temp_result = $urandom;
`else
      temp_result = $random;
`endif
      if (((WIDTH / 32) + 1) > 1) begin
        for (i=1 ; i < ((WIDTH / 32) + 1) ; i=i+1) begin
          base = i << 5;
`ifdef DWC_BCM_SV
          rand_slice = $urandom;
`else
          rand_slice = $random;
`endif
          for (j=0 ; ((j < 32) && (base+j < in_width)) ; j=j+1) begin
            temp_result[base+j] = rand_slice[j];
          end
        end
      end

      wide_random = temp_result;
    end
  endfunction  // wide_random

  initial begin : seed_random_PROC
    integer seed, init_rand;
    `ifdef DW_MISSAMPLE_SEED
      if (`DW_MISSAMPLE_SEED != 0)
        seed = `DW_MISSAMPLE_SEED;
      else
        seed = 32'h0badbeef;
    `else
      seed = 32'h0badbeef;
    `endif

`ifdef DWC_BCM_SV
    init_rand = $urandom(seed);
`else
    init_rand = $random(seed);
`endif
  end // seed_random_PROC

      always @ (data_s or last_data_s) begin : PROC_mk_next_data_select
        if (data_s != last_data_s) begin
          data_select = wide_random(WIDTH);
          data_select_2 = wide_random(WIDTH);
        end
      end  // PROC_mk_next_data_select
    end
    assign data_s_sel_tmp = (data_s & ~data_select) | (last_data_dyn & data_select);
    assign data_s_sel_0 = (disable_missample==1'b1) ? data_s : data_s_sel_tmp;
    assign data_s_sel_1 = (disable_missample==1'b1) ? data_s : ((last_data_s_q & ~data_select) | (last_data_s_qq & data_select));

    assign data_s_int = ((data_s_sel_0 & ~data_select_2) | (data_s_sel_1 & data_select_2));
    `ifdef DWC_BCM_SNPS_ASSERT_ON
    `ifdef DWC_BCM_CDC_COVERAGE_REPORT
    always@(data_s_int) begin
      if((data_s_int==$sampled(data_s)) && (!clk_d_stopped))
        -> data_s_ms_vld;
      end

      property data_s_missample_cov;
         @(data_s_ms_vld) disable iff (clk_d_stopped
                                       || !rst_d_n
                                         )
         ($sampled(clk_d_stopped)==1'b0);
      endproperty
      COVER_DATA_S_MISSAMPLE: cover property (data_s_missample_cov);
    `endif
    `endif

  end else begin : GEN_DSI_VE_EQ_1_OR_4_OR_5

    if (WIDTH < 32) begin : GEN_D_SEL_W_LT_32
      reg  [31-WIDTH:0] data_select_lint_ext;
      always @ (data_s or last_data_s) begin : PROC_mk_next_data_select
        if (data_s != last_data_s)
  `ifdef DWC_BCM_SV
          {data_select_lint_ext,data_select} = $urandom;
  `else
          {data_select_lint_ext,data_select} = $random;
  `endif
      end  // PROC_mk_next_data_select
    end else if (WIDTH == 32) begin : GEN_D_SEL_W_EQ_32
      always @ (data_s or last_data_s) begin : PROC_mk_next_data_select
        if (data_s != last_data_s)
  `ifdef DWC_BCM_SV
          data_select = $urandom;
  `else
          data_select = $random;
  `endif
      end  // PROC_mk_next_data_select
    end else begin : GEN_D_SEL_W_GT_32
  function automatic [WIDTH-1:0] wide_random;
    input [31:0]        in_width;   // should match "WIDTH" parameter -- need one input to satisfy Verilog function requirement

    reg   [WIDTH-1:0]   temp_result;
    reg   [31:0]        rand_slice;
    integer             i, j, base;


    begin
`ifdef DWC_BCM_SV
      temp_result = $urandom;
`else
      temp_result = $random;
`endif
      if (((WIDTH / 32) + 1) > 1) begin
        for (i=1 ; i < ((WIDTH / 32) + 1) ; i=i+1) begin
          base = i << 5;
`ifdef DWC_BCM_SV
          rand_slice = $urandom;
`else
          rand_slice = $random;
`endif
          for (j=0 ; ((j < 32) && (base+j < in_width)) ; j=j+1) begin
            temp_result[base+j] = rand_slice[j];
          end
        end
      end

      wide_random = temp_result;
    end
  endfunction  // wide_random

  initial begin : seed_random_PROC
    integer seed, init_rand;
    `ifdef DW_MISSAMPLE_SEED
      if (`DW_MISSAMPLE_SEED != 0)
        seed = `DW_MISSAMPLE_SEED;
      else
        seed = 32'h0badbeef;
    `else
      seed = 32'h0badbeef;
    `endif

`ifdef DWC_BCM_SV
    init_rand = $urandom(seed);
`else
    init_rand = $random(seed);
`endif
  end // seed_random_PROC

      always @ (data_s or last_data_s) begin : PROC_mk_next_data_select
        if (data_s != last_data_s)
          data_select = wide_random(WIDTH);
      end  // PROC_mk_next_data_select
    end
    assign data_s_sel_tmp = (data_s & ~data_select) | (last_data_dyn & data_select);
    assign data_s_int = (disable_missample==1'b1) ? data_s : data_s_sel_tmp;
  `ifdef DWC_BCM_SNPS_ASSERT_ON
  `ifdef DWC_BCM_CDC_COVERAGE_REPORT
  always@(data_s_int) begin
    if((data_s_int==$sampled(data_s)) && (!clk_d_stopped))
      -> data_s_ms_vld;
    end

      property data_s_missample_cov;
         @(data_s_ms_vld) disable iff (clk_d_stopped
                                       || !rst_d_n
                                         )
         ($sampled(clk_d_stopped)==1'b0);
      endproperty
      COVER_DATA_S_MISSAMPLE: cover property (data_s_missample_cov);
  `endif
  `endif

  end endgenerate

// { START Latency Accurate modeling
  initial begin : set_setup_hold_delay_PROC
    `ifndef DW_HOLD_MUX_DELAY
      `define DW_HOLD_MUX_DELAY  1
      if ((((F_SYNC_TYPE & 7) & 2) == 2) && (VERIF_EN == 5))
        $display("Information: %m: *** Warning: `DW_HOLD_MUX_DELAY is not defined so it is being set to: %0d ***", `DW_HOLD_MUX_DELAY);
    `endif

    `ifndef DW_SETUP_MUX_DELAY
      `define DW_SETUP_MUX_DELAY  1
      if ((((F_SYNC_TYPE & 7) & 2) == 2) && (VERIF_EN == 5))
        $display("Information: %m: *** Warning: `DW_SETUP_MUX_DELAY is not defined so it is being set to: %0d ***", `DW_SETUP_MUX_DELAY);
    `endif
  end // set_setup_hold_delay_PROC

  initial begin
    if ((((F_SYNC_TYPE & 7) & 2) == 2) && (VERIF_EN == 5) && (BCM_MSG_VERBOSITY[0] == 1'b1))
      $display("Information: %m: *** Running with Latency Accurate MISSAMPLES defined, VERIF_EN is: %0d ***", VERIF_EN);
  end

  reg [WIDTH-1:0] setup_mux_ctrl, hold_mux_ctrl;
  initial setup_mux_ctrl = {WIDTH{1'b0}};
  initial hold_mux_ctrl  = {WIDTH{1'b0}};

  wire [WIDTH-1:0] data_s_q;
  reg clk_d_q;
  initial clk_d_q = 1'b0;
  reg [WIDTH-1:0] setup_mux_out, d_muxout;
  reg [WIDTH-1:0] d_ff1, d_ff2;
  integer i,j,k;


generate if ((((F_SYNC_TYPE & 7) & 2) == 2) && (VERIF_EN == 5)) begin : GEN_MS_FST2OR3_VE5
  //Delay the destination clock
  always @ (posedge clk_d)
  #`DW_HOLD_MUX_DELAY clk_d_q = 1'b1;

  always @ (negedge clk_d)
  #`DW_HOLD_MUX_DELAY clk_d_q = 1'b0;

  //Delay the source data
  assign #`DW_SETUP_MUX_DELAY data_s_q = (!rst_d_n) ? {WIDTH{1'b0}}:data_s;

  //setup_mux_ctrl controls the data entering the flip flop
  always @ (data_s or data_s_q or setup_mux_ctrl) begin
    for (i=0;i<=WIDTH-1;i=i+1) begin
      if (setup_mux_ctrl[i])
        setup_mux_out[i] = data_s_q[i];
      else
        setup_mux_out[i] = data_s[i];
    end
  end

  always @ (posedge clk_d_q or negedge rst_d_n) begin
    if (rst_d_n == 1'b0)
      d_ff2 <= {WIDTH{1'b0}};
    else
      d_ff2 <= setup_mux_out;
  end

  always @ (posedge clk_d or negedge rst_d_n) begin
    if (rst_d_n == 1'b0) begin
      d_ff1          <= {WIDTH{1'b0}};
      setup_mux_ctrl <= {WIDTH{1'b0}};
      hold_mux_ctrl  <= {WIDTH{1'b0}};
    end
    else begin
      d_ff1          <= setup_mux_out;
    `ifdef DWC_BCM_SV
      setup_mux_ctrl <= $urandom;  //randomize mux_ctrl
      hold_mux_ctrl  <= $urandom;  //randomize mux_ctrl
    `else
      setup_mux_ctrl <= $random;  //randomize mux_ctrl
      hold_mux_ctrl  <= $random;  //randomize mux_ctrl
    `endif
    end
  end


//hold_mux_ctrl decides the clock triggering the flip-flop
always @(hold_mux_ctrl or d_ff2 or d_ff1) begin
      for (k=0;k<=WIDTH-1;k=k+1) begin
        if (hold_mux_ctrl[k])
          d_muxout[k] = d_ff2[k];
        else
          d_muxout[k] = d_ff1[k];
      end
end
end
endgenerate
// END Latency Accurate modeling }


 //Assertions
`ifdef DWC_BCM_SNPS_ASSERT_ON
`ifndef SYNTHESIS
generate if ( (((F_SYNC_TYPE & 7) & 2) == 2) && (VERIF_EN == 5) ) begin : GEN_ASSERT_FST2OR3_VE5
  sequence p_num_d_chng;
  @ (posedge clk_d) 1'b1 ##0 (data_s != d_ff1); //Number of times input data changed
  endsequence

  sequence p_num_d_chng_hmux1;
  @ (posedge clk_d) 1'b1 ##0 ((data_s != d_ff1) && (|(hold_mux_ctrl & (data_s ^ d_ff1)))); //Number of times hold_mux_ctrl was asserted when the input data changed
  endsequence

  sequence p_num_d_chng_smux1;
  @ (posedge clk_d) 1'b1 ##0 ((data_s != d_ff1) && (|(setup_mux_ctrl & (data_s ^ d_ff1)))); //Number of times setup_mux_ctrl was asserted when the input data changed
  endsequence

  sequence p_hold_vio;
  reg [WIDTH-1:0]temp_var, temp_var1;
  @ (posedge clk_d) (((data_s != d_ff1) && (|(hold_mux_ctrl & (data_s ^ d_ff1)))), temp_var = data_s, temp_var1 =(hold_mux_ctrl & (data_s ^ d_ff1))) ##1 ((data_d & temp_var1) == (temp_var & temp_var1));
          //Number of times output data was advanced due to hold violation
  endsequence

  sequence p_setup_vio;
  reg [WIDTH-1:0]temp_var, temp_var1;
  @ (posedge clk_d) (((data_s != d_ff1) && (|(setup_mux_ctrl & (data_s ^ d_ff1)))), temp_var = data_s, temp_var1 =(setup_mux_ctrl & (data_s ^ d_ff1))) ##2 ((data_d & temp_var1) != (temp_var & temp_var1));
          //Number of times output data was delayed due to setup violation
  endsequence

  cp_num_d_chng           : cover property  (p_num_d_chng);
  cp_num_d_chng_hld_mux1  : cover property  (p_num_d_chng_hmux1);
  cp_num_d_chng_set_mux1  : cover property  (p_num_d_chng_smux1);
  cp_hold_vio             : cover property  (p_hold_vio);
  cp_setup_vio            : cover property  (p_setup_vio);
 end
endgenerate
`endif // SYNTHESIS
`endif // DWC_BCM_SNPS_ASSERT_ON

  `else
  assign data_s_int = data_s;
  `endif
`endif


// spyglass disable_block Ac_conv04
// SMD: Checks all the control-bus clock domain crossings which do not follow gray encoding
// SJ: The clock domain crossing bus is between the register file and the read-mux of a RAM, which do not need a gray encoding.

generate
    if ((F_SYNC_TYPE & 7) == 0) begin : GEN_FST0
      assign data_d_int  =  data_s;
    end
    if ((F_SYNC_TYPE & 7) == 1) begin : GEN_FST1
`ifdef DWC_SYNC_1_STAGE_SRC
      wire [WIDTH-1:0] sample_meta;
      wire clk_d_n;


      DWC_pcie_ctl_bcm00_ck_inv
       U_CK_INV (.clk_in(clk_d), .clk_out(clk_d_n));
      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_META_1_N, WIDTH, clk_d_n, rst_d_n, data_s_int, sample_meta)
      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_SYNCL_1,  WIDTH,  clk_d, rst_d_n, sample_meta, data_d_int)

`else

      reg    [WIDTH-1:0]      sample_meta_n;
      reg    [WIDTH-1:0]      sample_syncl;
      wire   [WIDTH-1:0]      next_sample_syncm1;
      wire   [WIDTH-1:0]      next_sample_syncl;

// spyglass disable_block Clock_check04
// SMD: Use rising edge flipflop
// SJ: The module was intentionally implemented to use negative edge clocking flip-flops cells.
      always @ (negedge clk_d or negedge rst_d_n) begin : negedge_registers_PROC
// spyglass enable_block Clock_check04
        if (rst_d_n == 1'b0) begin
          sample_meta_n    <= {WIDTH{1'b0}};
        end else begin
// spyglass disable_block W391
// SMD: Design has a clock driving it on both edges
// SJ: This module is configured such that both edges of the same clock are used for different flip-flops.
// spyglass disable_block Reset_sync04
// SMD: Asynchronous resets that are synchronized more than once in the same clock domain
// SJ: Spyglass recognizes every multi-flop synchronizer as a reset synchronizer, hence any design with a reset that feeds more than one synchronizer gets reported as violating this rule. This rule is waivered temporarily.
          sample_meta_n    <= data_s_int;
// spyglass enable_block W391
// spyglass enable_block Reset_sync04
        end
      end


      assign next_sample_syncm1 = sample_meta_n;
      assign next_sample_syncl = next_sample_syncm1;

      always @ (posedge clk_d or negedge rst_d_n) begin : posedge_registers_PROC
        if (rst_d_n == 1'b0) begin
          sample_syncl     <= {WIDTH{1'b0}};
        end else begin
// spyglass disable_block W391
// SMD: Design has a clock driving it on both edges
// SJ: This module is configured such that both edges of the same clock are used for different flip-flops.
          sample_syncl     <= next_sample_syncl;
// spyglass enable_block W391
        end
      end


      assign data_d_int = sample_syncl;

`endif

    end
    if ((F_SYNC_TYPE & 7) == 2) begin : GEN_FST2
`ifdef DWC_SYNC_2_STAGE_SRC


      `DWC_SYNC_2_STAGE_SRC(U_SAMPLE_META_2, WIDTH, clk_d, rst_d_n, data_s_int, data_d_int)

`else
    `ifdef DWC_SYNC_1_STAGE_SRC
      wire [WIDTH-1:0] sample_meta;


      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_META_1,  WIDTH, clk_d, rst_d_n, data_s_int, sample_meta)
      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_SYNCL_1, WIDTH, clk_d, rst_d_n, sample_meta, data_d_int)

    `else

      reg    [WIDTH-1:0]      sample_meta;
      reg    [WIDTH-1:0]      sample_syncl;
      wire   [WIDTH-1:0]      next_sample_meta;
      wire   [WIDTH-1:0]      next_sample_syncm1;
      wire   [WIDTH-1:0]      next_sample_syncl;


      assign next_sample_meta      = data_s_int;


        `ifdef SYNTHESIS
      assign next_sample_syncm1 = sample_meta;
        `else
          `ifdef DW_MODEL_MISSAMPLES
      if (((F_SYNC_TYPE & 7) == 2) && (VERIF_EN == 5)) begin : GEN_NXT_SMPL_SM1_FST2_VE5
        assign next_sample_syncm1 = d_muxout;
      end else begin : GEN_NXT_SMPL_SM1_ELSE
        assign next_sample_syncm1 = sample_meta;
      end
          `else
        assign next_sample_syncm1 = sample_meta;
          `endif
        `endif
      assign next_sample_syncl  = next_sample_syncm1;
      always @ (posedge clk_d or negedge rst_d_n) begin : posedge_registers_PROC
        if (rst_d_n == 1'b0) begin

          sample_meta     <= {WIDTH{1'b0}};
          sample_syncl     <= {WIDTH{1'b0}};
        end else begin

// spyglass disable_block W391
// SMD: Design has a clock driving it on both edges
// SJ: This module is configured such that both edges of the same clock are used for different flip-flops.
// spyglass disable_block Reset_sync04
// SMD: Asynchronous resets that are synchronized more than once in the same clock domain
// SJ: Spyglass recognizes every multi-flop synchronizer as a reset synchronizer, hence any design with a reset that feeds more than one synchronizer gets reported as violating this rule. This rule is waivered temporarily.
          sample_meta     <= next_sample_meta;
// spyglass enable_block Reset_sync04
          sample_syncl     <= next_sample_syncl;
// spyglass enable_block W391
        end
      end


      assign data_d_int = sample_syncl;

    `endif

`endif

    end
    if ((F_SYNC_TYPE & 7) == 3) begin : GEN_FST3
`ifdef DWC_SYNC_3_STAGE_SRC


      `DWC_SYNC_3_STAGE_SRC(U_SAMPLE_META_3,  WIDTH, clk_d, rst_d_n, data_s_int, data_d_int)

`else
    `ifdef DWC_SYNC_2_STAGE_SRC
      wire [WIDTH-1:0] sample_syncm;


      `DWC_SYNC_2_STAGE_SRC(U_SAMPLE_META_2,   WIDTH, clk_d, rst_d_n, data_s_int, sample_syncm)

      `ifdef DWC_SYNC_1_STAGE_SRC
      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_SYNCL_1,  WIDTH, clk_d, rst_d_n, sample_syncm, data_d_int)
      `else

      reg [WIDTH-1:0] sample_syncl;
      always @ (posedge clk_d or negedge rst_d_n) begin : sync_middle_PROC
        if (rst_d_n == 1'b0) begin
          sample_syncl <= {WIDTH{1'b0}};
        end else begin
          sample_syncl <= sample_syncm;
        end
      end

      assign data_d_int = sample_syncl;
      `endif

    `else
      `ifdef DWC_SYNC_1_STAGE_SRC
      wire [WIDTH-1:0] sample_meta;
      wire [WIDTH-1:0] sample_syncm;


      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_META_1,  WIDTH, clk_d, rst_d_n, data_s_int, sample_meta)
      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_SYNCM_1, WIDTH, clk_d, rst_d_n, sample_meta, sample_syncm)
      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_SYNCL_1, WIDTH, clk_d, rst_d_n, sample_syncm, data_d_int)

      `else

      reg    [WIDTH-1:0]      sample_meta;
      reg    [WIDTH-1:0]      sample_syncm1;
      reg    [WIDTH-1:0]      sample_syncl;
      wire   [WIDTH-1:0]      next_sample_meta;
      wire   [WIDTH-1:0]      next_sample_syncm1;
      wire   [WIDTH-1:0]      next_sample_syncl;


      assign next_sample_meta      = data_s_int;


        `ifdef SYNTHESIS
      assign next_sample_syncm1 = sample_meta;
        `else
          `ifdef DW_MODEL_MISSAMPLES
      if (((F_SYNC_TYPE & 7) == 3) && (VERIF_EN == 5)) begin : GEN_NXT_SMPL_SM1_FST3_VE5
        assign next_sample_syncm1 = d_muxout;
      end else begin : GEN_NXT_SMPL_SM1_ELSE
        assign next_sample_syncm1 = sample_meta;
      end
          `else
        assign next_sample_syncm1 = sample_meta;
          `endif
        `endif
      assign next_sample_syncl  = sample_syncm1;
      always @ (posedge clk_d or negedge rst_d_n) begin : posedge_registers_PROC
        if (rst_d_n == 1'b0) begin

          sample_meta     <= {WIDTH{1'b0}};
          sample_syncm1    <= {WIDTH{1'b0}};
          sample_syncl     <= {WIDTH{1'b0}};
        end else begin

// spyglass disable_block W391
// SMD: Design has a clock driving it on both edges
// SJ: This module is configured such that both edges of the same clock are used for different flip-flops.
// spyglass disable_block Reset_sync04
// SMD: Asynchronous resets that are synchronized more than once in the same clock domain
// SJ: Spyglass recognizes every multi-flop synchronizer as a reset synchronizer, hence any design with a reset that feeds more than one synchronizer gets reported as violating this rule. This rule is waivered temporarily.
          sample_meta     <= next_sample_meta;
// spyglass enable_block Reset_sync04
          sample_syncm1    <= next_sample_syncm1;
          sample_syncl     <= next_sample_syncl;
// spyglass enable_block W391
        end
      end


      assign data_d_int = sample_syncl;

      `endif
    `endif

`endif

    end
    if ((F_SYNC_TYPE & 7) == 4) begin : GEN_FST4
`ifdef DWC_SYNC_4_STAGE_SRC


      `DWC_SYNC_4_STAGE_SRC(U_SAMPLE_META_4, WIDTH, clk_d, rst_d_n, data_s_int, data_d_int)

`else
    `ifdef DWC_SYNC_3_STAGE_SRC
      wire [WIDTH-1:0] sample_syncm;


      `DWC_SYNC_3_STAGE_SRC(U_SAMPLE_META_3,  WIDTH, clk_d, rst_d_n, data_s_int, sample_syncm)

      `ifdef DWC_SYNC_1_STAGE_SRC
      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_SYNCL_1, WIDTH, clk_d, rst_d_n, sample_syncm, data_d_int)

      `else

      reg [WIDTH-1:0] sample_syncl;
      always @ (posedge clk_d or negedge rst_d_n) begin : sync_middle_PROC
        if (rst_d_n == 1'b0) begin
          sample_syncl <= {WIDTH{1'b0}};
        end else begin
          sample_syncl <= sample_syncm;
        end
      end

      assign data_d_int = sample_syncl;
      `endif

    `else
      `ifdef DWC_SYNC_2_STAGE_SRC
      wire [WIDTH-1:0] sample_syncm;


      `DWC_SYNC_2_STAGE_SRC(U_SAMPLE_META_2, WIDTH, clk_d, rst_d_n, data_s_int, sample_syncm)
      `DWC_SYNC_2_STAGE_SRC(U_SAMPLE_SYNCL_2, WIDTH, clk_d, rst_d_n, sample_syncm, data_d_int)

      `else
        `ifdef DWC_SYNC_1_STAGE_SRC
      wire [WIDTH-1:0] sample_meta;
      wire [WIDTH-1:0] sample_syncm1;
      wire [WIDTH-1:0] sample_syncm2;


      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_META_1, WIDTH, clk_d, rst_d_n, data_s_int, sample_meta)
      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_SYNCM1_1, WIDTH, clk_d, rst_d_n, sample_meta, sample_syncm1)
      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_SYNCM2_1, WIDTH, clk_d, rst_d_n, sample_syncm1, sample_syncm2)
      `DWC_SYNC_1_STAGE_SRC(U_SAMPLE_SYNCL_1, WIDTH, clk_d, rst_d_n, sample_syncm2, data_d_int)

        `else

      reg    [WIDTH-1:0]      sample_meta;
      reg    [WIDTH-1:0]      sample_syncm1;
      reg    [WIDTH-1:0]      sample_syncm2;
      reg    [WIDTH-1:0]      sample_syncl;
      wire   [WIDTH-1:0]      next_sample_meta;
      wire   [WIDTH-1:0]      next_sample_syncm1;
      wire   [WIDTH-1:0]      next_sample_syncm2;
      wire   [WIDTH-1:0]      next_sample_syncl;


      assign next_sample_meta      = data_s_int;


      assign next_sample_syncm1 = sample_meta;
      assign next_sample_syncm2 = sample_syncm1;
      assign next_sample_syncl  = sample_syncm2;
      always @ (posedge clk_d or negedge rst_d_n) begin : posedge_registers_PROC
        if (rst_d_n == 1'b0) begin

          sample_meta     <= {WIDTH{1'b0}};
          sample_syncm1    <= {WIDTH{1'b0}};
          sample_syncm2    <= {WIDTH{1'b0}};
          sample_syncl     <= {WIDTH{1'b0}};
        end else begin

// spyglass disable_block W391
// SMD: Design has a clock driving it on both edges
// SJ: This module is configured such that both edges of the same clock are used for different flip-flops.
// spyglass disable_block Reset_sync04
// SMD: Asynchronous resets that are synchronized more than once in the same clock domain
// SJ: Spyglass recognizes every multi-flop synchronizer as a reset synchronizer, hence any design with a reset that feeds more than one synchronizer gets reported as violating this rule. This rule is waivered temporarily.
          sample_meta     <= next_sample_meta;
// spyglass enable_block Reset_sync04
          sample_syncm1    <= next_sample_syncm1;
          sample_syncm2    <= next_sample_syncm2;
          sample_syncl     <= next_sample_syncl;
// spyglass enable_block W391
        end
      end


      assign data_d_int = sample_syncl;

        `endif
      `endif
    `endif
`endif

    end
endgenerate



assign data_d = data_d_int;


// spyglass enable_block Ac_conv04

`ifndef SYNTHESIS
  `ifdef DWC_BCM_SNPS_ASSERT_ON
    localparam SVA_TYPE_BIT2 = SVA_TYPE&4'b0100;
    localparam SVA_TYPE_BIT1BIT0 = SVA_TYPE&4'b0011;

`ifdef DWC_BCM_CDC_COVERAGE_REPORT
  generate if ((SVA_TYPE&5'b10000) == 0) begin : CDC_COVERAGE_REPORT
    reg clk_d_mod;

    assign clk_d_mod = (F_SYNC_TYPE==1) ? ~clk_d : clk_d;

    genvar i;
    for (i=0; i<WIDTH; i=i+1) begin : DATA_S
      property LtoHMonitor;
        @(posedge clk_d_mod) disable iff (!rst_d_n)
          $rose(data_s[i]);
      endproperty
      COVER_LOW_TO_HIGH_TRANSITION: cover property (LtoHMonitor);

      property HtoLMonitor;
        @(posedge clk_d_mod) disable iff (!rst_d_n)
          $fell(data_s[i]);
      endproperty
      COVER_HIGH_TO_LOW_TRANSITION: cover property (HtoLMonitor);
    end
  end endgenerate
`endif

  generate
    if (SVA_TYPE_BIT1BIT0 == 0) begin : GEN_SVATP_EQ_0
    `ifdef DW_MODEL_MISSAMPLES
      DWC_pcie_ctl_bvm02
      
        U_CLK_DET (
        .clk         (clk_d        ),
        .rst_n       (rst_d_n      ),
        .clk_stopped (clk_d_stopped),
        .clk_period  (             )
      );
    `endif
    end

    if (SVA_TYPE_BIT1BIT0 == 1) begin : GEN_SVATP_EQ_1
      wire [63:0] clk_d_period;

      DWC_pcie_ctl_bvm02
      
        U_CLK_DET (
        .clk         (clk_d        ),
        .rst_n       (rst_d_n      ),
        .clk_stopped (clk_d_stopped),
        .clk_period  (clk_d_period )
      );

    `ifdef DWC_BCM21_BIT_BASIS_SVA
      genvar sva01_i;
      for (sva01_i=0;sva01_i<WIDTH;sva01_i=sva01_i+1) begin : BIT_BASIS_SVA
      DWC_pcie_ctl_sva01 #(1, (F_SYNC_TYPE & 7), VERIF_EN) P_SYNC_HS (
        .clk_d         (clk_d          ),
        .rst_d_n       (rst_d_n        ),
        .data_s        (data_s[sva01_i]),
        .clk_d_stopped (clk_d_stopped  ),
        .clk_d_period  (clk_d_period   ),
        .data_d        (data_d[sva01_i])
      );
      end
    `else
      DWC_pcie_ctl_sva01 #(WIDTH, (F_SYNC_TYPE & 7), VERIF_EN) P_SYNC_HS (
        .clk_d         (clk_d        ),
        .rst_d_n       (rst_d_n      ),
        .data_s        (data_s       ),
        .clk_d_stopped (clk_d_stopped),
        .clk_d_period  (clk_d_period ),
        .data_d        (data_d       )
      );
    `endif
    end

    if (SVA_TYPE_BIT1BIT0 == 2) begin : GEN_SVATP_EQ_2
    `ifdef DW_MODEL_MISSAMPLES
      DWC_pcie_ctl_bvm02
      
        U_CLK_DET (
        .clk         (clk_d        ),
        .rst_n       (rst_d_n      ),
        .clk_stopped (clk_d_stopped),
        .clk_period  (             )
      );
    `endif

      DWC_pcie_ctl_sva05 #(WIDTH, (F_SYNC_TYPE & 7)) P_SYNC_GC (
         .clk_d         (clk_d   ),
         .rst_d_n       (rst_d_n ),
         .init_d_n      (1'b1    ),
         .data_s        (data_s  )
      );
    end

    if (SVA_TYPE_BIT2 == 0) begin : GEN_SVATP_BIT2_EQ_0
      DWC_pcie_ctl_sva08 #(WIDTH,0) P_SYNC_EQ_RST (
        .rst_d_n       (rst_d_n      ),
        .init_d_n      (1'b1         ),
        .data_s        (data_s       ),
        .data_d        (data_d       )
      );
    end
  endgenerate
  `else
    `ifdef DW_MODEL_MISSAMPLES
  DWC_pcie_ctl_bvm02
   U_CLK_DET (
    .clk         (clk_d        ),
    .rst_n       (rst_d_n      ),
    .clk_stopped (clk_d_stopped),
    .clk_period  (             )
  );
    `endif
  `endif
`endif

// spyglass enable_block W146
endmodule
`ifdef DWC_BCM21_ENABLE_CELLDEFINE
  `ifndef SYNTHESIS
    `endcelldefine
  `endif
`endif
