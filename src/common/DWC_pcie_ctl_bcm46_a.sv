
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
// Description : DWC_pcie_ctl_bcm46_a.v Verilog module for DWC_pcie_ctl
//
// DesignWare IP ID: 8db18065
//
////////////////////////////////////////////////////////////////////////////////

module DWC_pcie_ctl_bcm46_a(
                gen,
                correct_n,
                datain,
                chkin,
                fixdata,
                err_detect,
                err_multpl,
                dataout,
                chkout,
                syndout);

// spyglass disable_block W146
// SMD: Explicit named association is recommended in instance references
// SJ: Current release uses ordered list for parameters, the design is checked and verified without errors

parameter integer WIDTH = 16;

input                   gen;            // Active high check-bit generate control input port
input                   correct_n;      // Active low bit correction control input port
input  [WIDTH-1:0]      datain;         // Data input port (for write, read & scrub)
input  [5:0]            chkin;          // Check bit input port (for read)
output [WIDTH-1:0]      fixdata;        // Data fixed flag port (one-hot)
output                  err_detect;     // Active high error detect output
output                  err_multpl;     // Active high multiple bit error detect output
output [WIDTH-1:0]      dataout;        // Data output port (for read & scrub)
output [5:0]            chkout;         // Check bit output port (for write & scrub)
output [5:0]            syndout;        // Error syndrome output port (for error logging)

wire   [5:0]            chkout_int;
wire   [5:0]            syndout_int;
wire   [5:0]            fixchk;
wire   [26:0]           syndec;
reg    [31:0]           dat_in;
wire   [WIDTH-1:0]      fixdata;


  assign chkout_int[0] = dat_in[1] ^ dat_in[11] ^ dat_in[14] ^ dat_in[16] ^
                          dat_in[17] ^ dat_in[18] ^ dat_in[2] ^ dat_in[20] ^
                          dat_in[21] ^ dat_in[23] ^ dat_in[25] ^ dat_in[3] ^
                          dat_in[5] ^ dat_in[8] ^ dat_in[9];

  assign chkout_int[1] = dat_in[0] ^ dat_in[1] ^ dat_in[10] ^ dat_in[12] ^
                          dat_in[16] ^ dat_in[18] ^ dat_in[19] ^ dat_in[2] ^
                          dat_in[21] ^ dat_in[23] ^ dat_in[24] ^ dat_in[25] ^
                          dat_in[4] ^ dat_in[6] ^ dat_in[8];

  assign chkout_int[2] = ~dat_in[0] ^ dat_in[10] ^ dat_in[13] ^ dat_in[15] ^
                          dat_in[16] ^ dat_in[17] ^ dat_in[18] ^ dat_in[19] ^
                          dat_in[20] ^ dat_in[23] ^ dat_in[25] ^ dat_in[3] ^
                          dat_in[4] ^ dat_in[7] ^ dat_in[9];

  assign chkout_int[3] = ~dat_in[0] ^ dat_in[1] ^ dat_in[11] ^ dat_in[12] ^
                          dat_in[13] ^ dat_in[16] ^ dat_in[17] ^ dat_in[19] ^
                          dat_in[20] ^ dat_in[21] ^ dat_in[22] ^ dat_in[25] ^
                          dat_in[5] ^ dat_in[6] ^ dat_in[7];

  assign chkout_int[4] = dat_in[14] ^ dat_in[15] ^ dat_in[16] ^ dat_in[19] ^
                          dat_in[2] ^ dat_in[20] ^ dat_in[21] ^ dat_in[22] ^
                          dat_in[23] ^ dat_in[24] ^ dat_in[3] ^ dat_in[4] ^
                          dat_in[5] ^ dat_in[6] ^ dat_in[7];

  assign chkout_int[5] = dat_in[10] ^ dat_in[11] ^ dat_in[12] ^ dat_in[13] ^
                          dat_in[14] ^ dat_in[15] ^ dat_in[19] ^ dat_in[20] ^
                          dat_in[21] ^ dat_in[22] ^ dat_in[23] ^ dat_in[24] ^
                          dat_in[25] ^ dat_in[8] ^ dat_in[9];

  assign syndec[22] = (syndout_int == 6'b111000)? 1'b1 : 1'b0;
  assign syndec[13] = (syndout_int == 6'b101100)? 1'b1 : 1'b0;
  assign syndec[18] = (syndout_int == 6'b000111)? 1'b1 : 1'b0;
  assign syndec[9] = (syndout_int == 6'b100101)? 1'b1 : 1'b0;
  assign syndec[7] = (syndout_int == 6'b011100)? 1'b1 : 1'b0;
  assign syndec[1] = (syndout_int == 6'b001011)? 1'b1 : 1'b0;
  assign syndec[26] = 1'b0;
  assign fixchk[5] = (syndout_int == 6'b100000)? 1'b1 : 1'b0;
  assign syndec[19] = (syndout_int == 6'b111110)? 1'b1 : 1'b0;
  assign syndec[8] = (syndout_int == 6'b100011)? 1'b1 : 1'b0;
  assign syndec[11] = (syndout_int == 6'b101001)? 1'b1 : 1'b0;
  assign syndec[4] = (syndout_int == 6'b010110)? 1'b1 : 1'b0;
  assign fixchk[0] = (syndout_int == 6'b000001)? 1'b1 : 1'b0;
  assign syndec[3] = (syndout_int == 6'b010101)? 1'b1 : 1'b0;
  assign syndec[16] = (syndout_int == 6'b011111)? 1'b1 : 1'b0;
  assign fixchk[3] = (syndout_int == 6'b001000)? 1'b1 : 1'b0;
  assign syndec[25] = (syndout_int == 6'b101111)? 1'b1 : 1'b0;
  assign fixchk[1] = (syndout_int == 6'b000010)? 1'b1 : 1'b0;
  assign syndec[2] = (syndout_int == 6'b010011)? 1'b1 : 1'b0;
  assign syndec[6] = (syndout_int == 6'b011010)? 1'b1 : 1'b0;
  assign syndec[23] = (syndout_int == 6'b110111)? 1'b1 : 1'b0;
  assign syndec[5] = (syndout_int == 6'b011001)? 1'b1 : 1'b0;
  assign syndec[24] = (syndout_int == 6'b110010)? 1'b1 : 1'b0;
  assign syndec[21] = (syndout_int == 6'b111011)? 1'b1 : 1'b0;
  assign syndec[14] = (syndout_int == 6'b110001)? 1'b1 : 1'b0;
  assign fixchk[2] = (syndout_int == 6'b000100)? 1'b1 : 1'b0;
  assign syndec[12] = (syndout_int == 6'b101010)? 1'b1 : 1'b0;
  assign syndec[20] = (syndout_int == 6'b111101)? 1'b1 : 1'b0;
  assign syndec[17] = (syndout_int == 6'b001101)? 1'b1 : 1'b0;
  assign syndec[15] = (syndout_int == 6'b110100)? 1'b1 : 1'b0;
  assign fixchk[4] = (syndout_int == 6'b010000)? 1'b1 : 1'b0;
  assign syndec[10] = (syndout_int == 6'b100110)? 1'b1 : 1'b0;
  assign syndec[0] = (syndout_int == 6'b001110)? 1'b1 : 1'b0;

  always @ (datain) begin : td_PROC

    integer i;

    for (i=0 ; i <= 31 ; i=i+1) begin
      if (i < WIDTH)
        dat_in[i] = datain[i];
      else
        dat_in[i] = 1'b0;
    end
  end

  assign syndout_int = chkout_int ^ chkin;

  assign err_detect = ~gen & ( |syndout_int );

  assign err_multpl = err_detect & ( ~(^syndout_int) || (|syndec[26:WIDTH]) );

  assign fixdata = syndec[WIDTH-1:0];

  assign chkout = (gen == 1'b1)? chkout_int : (correct_n == 1'b0)? chkin ^ fixchk : chkin;

  assign dataout = ((gen == 1'b0) && (correct_n == 1'b0))? datain ^ fixdata : datain;

  assign syndout = syndout_int;

// spyglass enable_block W146
endmodule
