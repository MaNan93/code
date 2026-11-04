
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
// Description : DWC_pcie_ctl_bcm55.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 024fedab
//
////////////////////////////////////////////////////////////////////////////////

//
// ABSTRACT:  Arbiter with round-robin priority scheme
//
// MODIFIED:
  module DWC_pcie_ctl_bcm55 (
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
  parameter integer INDEX_MODE = 0;

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

  reg                       grant_ro;
  reg  [N-2: 0]             token_cs;
  wire [N-1: 0]             token_cs_exp;
  reg  [N-2: 0]             token_ns;
  reg  [N-1: 0]             grant_cs;
  reg  [N-1: 0]             grant_ns;
  reg                       granted_r;
  reg  [INDEX_WIDTH-1: 0]   grant_indxr; // count memory
  reg  [INDEX_WIDTH-1: 0]   grant_indxn; // count memory

  wire [N-1: 0]             masked_req;

  assign token_cs_exp = {token_cs, ~(|token_cs)};
  assign masked_req = request & (~mask);


  always@(posedge clk or negedge rst_n) begin : REQUEST_STATE_SEQ_PROC
    if(rst_n == 1'b0) begin
      token_cs    <= INIT_TOKN;
// spyglass disable_block W528
// SMD: A signal or variable is set but never read
// SJ: Based on component configuration, this(these) signal(s) or parts of it will not be used to compute the final result.
      grant_cs    <= {N{1'b0}};
      grant_indxr <= {INDEX_WIDTH{1'b0}};
// spyglass enable_block W528
      granted_r   <= 1'b0;
    end else if (init_n == 1'b0) begin
      token_cs    <= INIT_TOKN;
      grant_cs    <= {N{1'b0}};
      grant_indxr <= {INDEX_WIDTH{1'b0}};
      granted_r   <= 1'b0;
    end else begin // not busy
      token_cs    <= token_ns;
      grant_cs    <= grant_ns;
      grant_indxr <= grant_indxn;
      granted_r   <= grant_ro;
    end
  end

// spyglass disable_block W415a
// SMD: Signal may be multiply assigned (beside initialization) in the same scope
// SJ: The design checked and verified that not any one of a single bit of the bus is assigned more than once beside initialization or the multiple assignments are intentional.
  always@(masked_req or token_cs_exp or granted_r or enable) begin : masked_req_STATE_COMB_PROC
    integer                    count;
    reg [N-1:0]                temp_msk;
    reg                        req_ro;

    grant_ro          = 1'b0;
    grant_ns          = {N{1'b0}};
    token_ns          = INIT_TOKN;
    req_ro            = |masked_req;
    temp_msk          = token_cs_exp;

    if(enable) begin
      if((masked_req & token_cs_exp) != {N{1'b0}})begin  //grant owned by token owner
        grant_ns           = token_cs_exp;
        token_ns           = token_cs_exp[N-1:1];
        grant_ro           = 1'b1;
      end else if(req_ro) begin // req not the token owner, search for next
        for(count = 0 ; count < N; count = count + 1) begin : PROC_srch4nxt
          temp_msk = {temp_msk[0],temp_msk[N-1:1]};
          if ((masked_req & temp_msk) != {N{1'b0}}) begin
            grant_ns = temp_msk;
            token_ns = temp_msk[N-1:1];
            grant_ro = 1'b1;
          end
        end
      // all masked_reqers go to zero while last grant active
      end else if(granted_r == 1'b1 & req_ro == 1'b0)begin
        token_ns    = token_cs_exp[N-2:0];
        grant_ns    = {N{1'b0}};
      end else begin // all masked_reqers go to zero....
        token_ns    = token_cs_exp[N-1:1];
        grant_ns    = {N{1'b0}};
      end
    end else begin // not enabled
      grant_ns    = {N{1'b0}};
      token_ns    = INIT_TOKN;
    end
  end


generate
  if (INDEX_MODE < 2) begin : GEN_IM_EQ_0
    always @ (grant_ns) begin : mk_grant_indx_ns_im0_im1_PROC
      integer i;
      reg [INDEX_WIDTH-1:0] tmp_indx;

      grant_indxn = {INDEX_WIDTH{1'b0}};
      tmp_indx = INDX_SIZED_ONE;

      for (i=0 ; i < N ; i=i+1) begin
        if (grant_ns[i] == 1'b1) begin
          grant_indxn = grant_indxn | tmp_indx;
        end
        tmp_indx = tmp_indx + INDX_SIZED_ONE;
      end
    end
  end else begin : GEN_IM_GT_1
    always @ (grant_ns) begin : mk_grant_indx_ns_im2_PROC
      integer i;
      reg [INDEX_WIDTH-1:0] tmp_indx;

      grant_indxn = {INDEX_WIDTH{1'b0}};
      tmp_indx = {INDEX_WIDTH{1'b0}};

      for (i=0 ; i < N ; i=i+1) begin
        if (grant_ns[i] == 1'b1) begin
          grant_indxn = grant_indxn | tmp_indx;
        end
        tmp_indx = tmp_indx + INDX_SIZED_ONE;
      end
    end
  end
endgenerate
// spyglass enable_block W415a

generate
  if (OUTPUT_MODE == 1) begin : GEN_OM_EQ_1
    assign granted     = granted_r;
    assign grant       = grant_cs;
    assign grant_index = grant_indxr;
  end else begin : GEN_OM_NE_1
    assign granted     = grant_ro;
    assign grant       = grant_ns;
    assign grant_index = grant_indxn;
  end
endgenerate
// spyglass enable_block W146
endmodule
