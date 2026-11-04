
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
// Description : DWC_pcie_ctl_bcm55_c.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 7f9ebbf2
//
////////////////////////////////////////////////////////////////////////////////

//
// ABSTRACT:  Arbiter with continuous round-robin scheme
//
// MODIFIED:
  module DWC_pcie_ctl_bcm55_c (
    clk,
    rst_n,
    init_n,
    enable,
    request,
    mask,
    granted,
    grant,
    grant_index
);

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

  parameter integer N           = 4; // RANGE 2 to 32
  parameter integer OUTPUT_MODE = 1; // RANGE 0 or 1
  parameter integer INDEX_WIDTH = 2; // RANGE 1 to 5

  localparam [INDEX_WIDTH-1:0] INDX_SIZED_ONE = 1;
  localparam [N-2 : 0] INIT_TOKN = {N-1{1'b0}};

  input                clk;     // clock input
  input                rst_n;   // active low async reset
  input                init_n;  // active low sync  reset
  input                enable;  // active high register enable
  input  [N-1: 0]      request; // client request bus
  input  [N-1: 0]      mask;    // client mask bus

  output                    granted; // arbiter granted status flag
  output [N-1: 0]           grant;   // one-hot granted client bus
  output [INDEX_WIDTH-1: 0] grant_index; //index of current granted client

  reg  [N-2: 0]             token_cs;
  wire [N-1: 0]             token_cs_exp;
  reg  [N-2: 0]             token_ns;
  reg  [N-1: 0]             grant_ns;
  reg                       granted_r;
  reg  [INDEX_WIDTH-1: 0]   grant_indxn;

  wire [N-1: 0]             masked_req;
  wire                      any_val_req;

  assign token_cs_exp = {token_cs, ~(|token_cs)};
  assign masked_req = request & (~mask) & {N{enable}};
  assign any_val_req = |masked_req;


generate
 if (OUTPUT_MODE == 1) begin : GEN_SEQ_OM_EQ_1

  reg  [N-1: 0]             grant_cs;
  reg  [INDEX_WIDTH-1: 0]   grant_indxr;

  always@(posedge clk or negedge rst_n) begin : reg_om1_PROC
    if(rst_n == 1'b0) begin
      token_cs    <= INIT_TOKN;
      grant_cs    <= {N{1'b0}};
      grant_indxr <= {INDEX_WIDTH{1'b0}};
      granted_r   <= 1'b0;
    end else if (init_n == 1'b0) begin
      token_cs    <= INIT_TOKN;
      grant_cs    <= {N{1'b0}};
      grant_indxr <= {INDEX_WIDTH{1'b0}};
      granted_r   <= 1'b0;
    end else begin // not busy
      if ((enable & (granted_r | any_val_req)) == 1'b1) begin
        token_cs    <= token_ns;
        grant_cs    <= grant_ns;
        grant_indxr <= grant_indxn;
        granted_r   <= any_val_req;
      end
    end
  end

  assign granted     = granted_r;
  assign grant       = grant_cs;
  assign grant_index = grant_indxr;

 end else begin : GEN_SEQ_OM_NE_1
  always@(posedge clk or negedge rst_n) begin : reg_om0_PROC
    if(rst_n == 1'b0) begin
      token_cs    <= INIT_TOKN;
      granted_r   <= 1'b0;
    end else if (init_n == 1'b0) begin
      token_cs    <= INIT_TOKN;
      granted_r   <= 1'b0;
    end else begin // not busy
      if ((enable & (granted_r | any_val_req)) == 1'b1) begin
        token_cs    <= token_ns;
        granted_r   <= any_val_req;
      end
    end
  end

  assign granted     = any_val_req;
  assign grant       = grant_ns;
  assign grant_index = grant_indxn;

 end
endgenerate

// spyglass disable_block W415a
// SMD: Signal may be multiply assigned (beside initialization) in the same scope
// SJ: The design checked and verified that not any one of a single bit of the bus is assigned more than once beside initialization or the multiple assignments are intentional.
  always@ (*) begin : next_state_PROC
    integer                    count;
    reg                        grant_ro;
    reg [N-1:0]                temp_msk;

    // presets of next state variables in case there is no valid request
    grant_ro          = 1'b0;
    grant_ns          = {N{1'b0}};
    token_ns          = token_cs;
    temp_msk          = token_cs_exp;

    if(any_val_req) begin
      for(count = 0 ; count < N; count = count + 1) begin : PROC_srch4nxt
// leda B_3450 off
// LMD: If statement should have else
// LJ: The variable(s) set in the 'if' clause have previously been completely set to a default value, an else clause accompanying the 'if' clause is not needed.  So, disabling leda for this rule.
        if (grant_ro == 1'b0) begin
// leda B_3450 on
          if ((masked_req & temp_msk) != {N{1'b0}}) begin
            grant_ns = temp_msk;
            token_ns = temp_msk[N-2:0];
            grant_ro = 1'b1;
          end else begin
            temp_msk = {temp_msk[N-2:0],temp_msk[N-1]};
          end
        end
      end
    end
  end


  always @ (*) begin : mk_grant_indx_PROC
    integer i;
    reg [INDEX_WIDTH-1:0] tmp_indx;

    grant_indxn = {INDEX_WIDTH{1'b0}};
    tmp_indx = {INDEX_WIDTH{1'b0}};

    for (i=0 ; i < N ; i=i+1) begin
// leda B_3450 off
// LMD: If statement should have else
// LJ: The variable(s) set in the 'if' clause have previously been completely set to a default value, an else clause accompanying the 'if' clause is not needed.  So, disabling leda for this rule.
      if (grant_ns[i] == 1'b1) begin
// leda B_3450 on
        grant_indxn = grant_indxn | tmp_indx;
      end
// leda W484 off
// LMD: Possible loss of carry/borrow in addition/subtraction
// LJ: When a calculation is done with the operands sized to a bit length that accomodates any possible addition/subtration result, there is no need to have an extra MSB on the LHS of the expression. The MSB can be discarded without causing any loss of information.
      tmp_indx = tmp_indx + INDX_SIZED_ONE;
// leda W484 on
    end
  end
// spyglass enable_block W415a
// spyglass enable_block W146
endmodule
