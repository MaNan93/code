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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe_tx.sv#11 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture transmitter side top module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"

module serdes_pipe_tx

  import serdes_pipe_pkg::*;
(
  // ------------ inputs ----------------
  input logic                        clk,
  input logic                        rst_n,
  input logic                        encdec_8b10b,
  input logic [RATE_WD-1:0]          pipe_rate,
  input logic [WIDTH_WD-1:0]         pipe_width,
  input logic                        sync_hdr_bypass_en,
  input logic [ORIG_DATA_WD-1:0]     orig_pipe_txdata,
  input logic [PHY_NB-1:0]           orig_pipe_txdatak,
  input logic                        orig_pipe_txelecidle,
  input logic                        orig_pipe_txcompliance,
  input logic                        orig_pipe_txdetectrx,
  input logic                        orig_pipe_loopback_slave,
  input logic                        orig_pipe_txdatavalid,
  input logic                        orig_pipe_txstartblock,
  input logic [1:0]                  orig_pipe_txsyncheader,
  input logic [SERDES_DATA_WD-1:0]   loopback_rxdata,
  input logic                        loopback_rxdatavalid,
  input logic [PHY_RXSB_WD-1:0]      loopback_rxstartblock,
  input logic [PHY_RXSH_WD-1:0]      loopback_rxsyncheader,
  // ------------ outputs ----------------
  output logic                       serdes_pipe_txdatavalid,
  output logic [SERDES_DATA_WD-1:0]  serdes_pipe_txdata,
  output logic [PHY_TXEI_WD-1:0]     serdes_pipe_txelecidle,
  output logic                       serdes_pipe_txdetectrx
);


// --------------------------------------------------------------------------------
//  Common internal signal 
// --------------------------------------------------------------------------------

  logic [PHY_SYM_WD-1:0]  symbol_width;
  logic [PHY_RAW_WD-1:0]  raw_width;

  assign symbol_width = get_symbol_width(pipe_width);
  assign raw_width = $bits(raw_width)'(get_raw_width(pipe_width, 1'h0));

// --------------------------------------------------------------------------------
//  Original PIPE registered input
// --------------------------------------------------------------------------------

  logic [ORIG_DATA_WD-1:0] regin_txdata;
  logic [PHY_NB-1:0]       regin_txdatak;
  logic                    regin_txelecidle;
  logic                    regin_txcompliance;
  logic                    regin_loopback_slave;
  logic                    regin_txdatavalid;
  logic                    regin_txstartblock;
  logic [1:0]              regin_txsyncheader;

  struct packed {
    logic [ORIG_DATA_WD-1:0] txdata;
    logic [PHY_NB-1:0]       txdatak;
    logic                    txcompliance;
    logic                    loopback_slave;
    logic                    txdatavalid;
    logic                    txstartblock;
    logic [1:0]              txsyncheader;
    } orig_pipe_sdata_in, orig_pipe_sdata_out;

  always_comb begin: orig_pipe_sdata_in_PROC
    orig_pipe_sdata_in = '0;
    orig_pipe_sdata_in.txdata = orig_pipe_txdata;
    orig_pipe_sdata_in.txdatak = orig_pipe_txdatak;
    orig_pipe_sdata_in.txcompliance = orig_pipe_txcompliance;
    orig_pipe_sdata_in.loopback_slave = orig_pipe_loopback_slave;
    orig_pipe_sdata_in.txdatavalid = orig_pipe_txdatavalid;
    orig_pipe_sdata_in.txstartblock = orig_pipe_txstartblock;
    orig_pipe_sdata_in.txsyncheader = orig_pipe_txsyncheader;
  end

  always_comb begin: regin_txdata_PROC
    regin_txdata = orig_pipe_sdata_out.txdata;
    regin_txdatak = orig_pipe_sdata_out.txdatak;
    regin_txcompliance = orig_pipe_sdata_out.txcompliance;
    regin_loopback_slave = orig_pipe_sdata_out.loopback_slave;
    regin_txdatavalid = orig_pipe_sdata_out.txdatavalid;
    regin_txstartblock = orig_pipe_sdata_out.txstartblock;
    regin_txsyncheader = orig_pipe_sdata_out.txsyncheader;
  end

  delay_n
   #(
    .N(1),
    .WD($bits(orig_pipe_sdata_in)),
    .RESETVAL('0)
  ) u_delay_n_orig_pipe (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .clear(1'h0),
    .din(orig_pipe_sdata_in),
    // ------------- output ----------------
    .dout(orig_pipe_sdata_out)
  );

  delay_n
   #(
    .N(1),
    .WD(1),
    .RESETVAL('1)
  ) u_delay_n_orig_pipe_txelecidle (
    // ------------- input -----------------
    .clk(clk),
    .rst_n(rst_n),
    .clear(1'h0),
    .din(orig_pipe_txelecidle),
    // ------------- output ----------------
    .dout(regin_txelecidle)
  );

// --------------------------------------------------------------------------------
//  Generate loopback enable
// --------------------------------------------------------------------------------

  logic loopback_en;
  logic loopback_en_sticky;
  logic loopback_slave;
  logic loopback_rxdatavalid_is_low;
  logic loopback_rxdatavalid_is_low_d;
  logic loopback_rxdatavalid_assert;

  assign loopback_slave = regin_loopback_slave && !regin_txelecidle;
  assign loopback_rxdatavalid_is_low = !loopback_rxdatavalid && loopback_slave;
  assign loopback_rxdatavalid_assert = loopback_rxdatavalid && loopback_rxdatavalid_is_low_d;

  always_ff @(posedge clk or negedge rst_n) begin: loopback_rxdatavalid_is_low_d_PROC
    if (!rst_n) begin
      loopback_rxdatavalid_is_low_d <= #`TP 1'b0;
    end
    else begin
      loopback_rxdatavalid_is_low_d <= #`TP loopback_rxdatavalid_is_low;
    end
  end: loopback_rxdatavalid_is_low_d_PROC

  always_ff @(posedge clk or negedge rst_n) begin: loopback_en_sticky_PROC
    if (!rst_n) begin
      loopback_en_sticky <= #`TP 1'b0;
    end
    else if(loopback_slave) begin
      if(loopback_rxdatavalid_assert) begin
        loopback_en_sticky <= #`TP 1'b1;
      end
    end
    else begin
      loopback_en_sticky <= #`TP 1'b0;
    end
  end: loopback_en_sticky_PROC

  assign loopback_en = (encdec_8b10b) ? loopback_slave
                     : (pipe_rate == `GEN6_RATE)? loopback_slave && loopback_rxdatavalid 
                                      : loopback_slave && (loopback_rxdatavalid_assert || loopback_en_sticky);

// --------------------------------------------------------------------------------
//  8b/10b encoding
// --------------------------------------------------------------------------------

  logic [SERDES_DATA_WD-1:0]  serdes_pipe_8b10b_txdata;
  logic [SERDES_DATA_WD-1:0]  enc_8b10b_data;

  serdes_pipe_tx_8b10b_encode
    u_serdes_pipe_tx_8b10b_encode (
// ------------ inputs ----------------
    .clk(clk),
    .rst_n(rst_n),
    .encdec_8b10b(encdec_8b10b),
    .symbol_width(symbol_width),
    .loopback_en(loopback_en),
    .txdata(regin_txdata),
    .txdatak (regin_txdatak),
    .txelecidle(regin_txelecidle),
    .txcompliance(regin_txcompliance),
// ------------ outputs ----------------
    .enc_data(enc_8b10b_data)
  );


  always_comb begin: serdes_pipe_8b10b_txdata_PROC
    serdes_pipe_8b10b_txdata = enc_8b10b_data;
    if(loopback_en) begin
      serdes_pipe_8b10b_txdata = loopback_rxdata;
    end
  end: serdes_pipe_8b10b_txdata_PROC
  
// --------------------------------------------------------------------------------
//  128b/130b encoding
// --------------------------------------------------------------------------------

  logic [SERDES_DATA_WD-1:0] serdes_pipe_128b130b_txdata;
  logic [PHY_TXEI_WD-1:0]    serdes_pipe_128b130b_txelecidle;
  logic                      pre_serdes_pipe_txdatavalid;
  logic [ORIG_DATA_WD-1:0]   enc_128b130b_data;
  logic [ORIG_DATA_WD-1:0]   loopback_rxdata_align;
  logic [ORIG_DATA_WD-1:0]   muxed_data;
  logic                      muxed_datavalid;
  logic [PHY_RXSB_WD-1:0]    muxed_startblock;
  logic [PHY_RXSH_WD-1:0]    muxed_syncheader;

  always_comb begin: loopback_rxdata_align_PROC
    loopback_rxdata_align = '0;
    for(int i = 0; i < PHY_NB; i++) begin
      loopback_rxdata_align[i*SYM_WD+:SYM_WD] = loopback_rxdata[i*SYM_10B_WD+:SYM_WD];
    end
  end: loopback_rxdata_align_PROC

  assign muxed_data       = (loopback_en) ? loopback_rxdata_align : regin_txdata;
  assign muxed_datavalid  = (loopback_en) ? loopback_rxdatavalid  : regin_txdatavalid;
  assign muxed_startblock = (loopback_en) ? loopback_rxstartblock : $bits(muxed_startblock)'(regin_txstartblock);
  assign muxed_syncheader = (loopback_en) ? loopback_rxsyncheader : $bits(muxed_syncheader)'(regin_txsyncheader);

  serdes_pipe_tx_128b130b_encode
    u_serdes_pipe_tx_128b130b_encode (
// ------------ inputs ----------------
    .clk(clk),
    .rst_n(rst_n),
    .encdec_8b10b(encdec_8b10b),
    .loopback_en(loopback_en),
    .symbol_width(symbol_width),
    .raw_width(raw_width),
    .data_in(muxed_data),
    .datavalid(muxed_datavalid),
    .startblock(muxed_startblock),
    .syncheader(muxed_syncheader),
    .elecidle_in(regin_txelecidle),
    .rd_datavalid(pre_serdes_pipe_txdatavalid),
// ------------ outputs ----------------
    .enc_data(enc_128b130b_data),
    .elecidle_out(serdes_pipe_128b130b_txelecidle)
  );

  always_comb begin: serdes_pipe_128b130b_txdata_PROC
    serdes_pipe_128b130b_txdata = '0;
    for(int i = 0; i < PHY_NB; i++) begin
      serdes_pipe_128b130b_txdata[i*SYM_10B_WD +:SYM_WD] = enc_128b130b_data[i*SYM_WD +:SYM_WD];
    end
  end: serdes_pipe_128b130b_txdata_PROC
// --------------------------------------------------------------------------------
//  Muxed txdata and txelecidle
// --------------------------------------------------------------------------------

  logic [SERDES_DATA_WD-1:0] pre_serdes_pipe_txdata;
  logic [PHY_TXEI_WD-1:0]    pre_serdes_pipe_txelecidle;

  logic [SERDES_DATA_WD-1:0] orig_pipe_txdata_align;

  always_comb begin: orig_pipe_txdata_align_PROC
    orig_pipe_txdata_align = '0;
    for(int i = 0; i < PHY_NB; i++) begin
      orig_pipe_txdata_align[i*SYM_10B_WD +:SYM_WD] = orig_pipe_txdata[i*SYM_WD +:SYM_WD];
    end
  end: orig_pipe_txdata_align_PROC

  // --- 1b1b encoding ---
  logic [SERDES_DATA_WD-1:0] serdes_pipe_1b1b_txdata;
  
  always_comb begin
    serdes_pipe_1b1b_txdata   = orig_pipe_txdata_align ;
    if(loopback_en) begin
      serdes_pipe_1b1b_txdata = loopback_rxdata;
    end
  end

  always_comb begin: pre_serdes_pipe_txdata_PROC
    pre_serdes_pipe_txdata = serdes_pipe_8b10b_txdata;
    if(sync_hdr_bypass_en) begin
      pre_serdes_pipe_txdata = orig_pipe_txdata_align;
    end else
    if(pipe_rate == `GEN6_RATE) begin
      pre_serdes_pipe_txdata = serdes_pipe_1b1b_txdata;
    end else
    if(!encdec_8b10b) begin
      pre_serdes_pipe_txdata = serdes_pipe_128b130b_txdata;
    end
  end: pre_serdes_pipe_txdata_PROC

  always_comb begin: pre_serdes_pipe_txelecidle_PROC
    pre_serdes_pipe_txelecidle = {(PHY_TXEI_WD){regin_txelecidle}};
    if(sync_hdr_bypass_en) begin
      pre_serdes_pipe_txelecidle = {(PHY_TXEI_WD){orig_pipe_txelecidle}};
    end else
    if(pipe_rate == `GEN6_RATE) begin
      pre_serdes_pipe_txelecidle = {(PHY_TXEI_WD){orig_pipe_txelecidle}};
    end else
    if(!encdec_8b10b) begin
      pre_serdes_pipe_txelecidle = serdes_pipe_128b130b_txelecidle;
    end
  end: pre_serdes_pipe_txelecidle_PROC


  always_comb begin: pre_serdes_pipe_txdatavalid_PROC
    pre_serdes_pipe_txdatavalid = 1'h1;
  end: pre_serdes_pipe_txdatavalid_PROC
  
// --------------------------------------------------------------------------------
//  Module output
// --------------------------------------------------------------------------------
  struct packed {
    logic [SERDES_DATA_WD-1:0] data;
    logic                      detectrx;
  }  pre_serdes_pipe_tx_sdata, serdes_pipe_tx_sdata;

  localparam int  SERDES_PIPE_TX_BUS_WD = $bits(pre_serdes_pipe_tx_sdata);

  always_comb begin: pre_serdes_pipe_tx_sdata_PROC
    pre_serdes_pipe_tx_sdata.data = pre_serdes_pipe_txdata;
    pre_serdes_pipe_tx_sdata.detectrx = orig_pipe_txdetectrx;
  end: pre_serdes_pipe_tx_sdata_PROC

  always_comb begin: serdes_pipe_tx_sdata_PROC
    serdes_pipe_txdata = serdes_pipe_tx_sdata.data;
    serdes_pipe_txdetectrx = serdes_pipe_tx_sdata.detectrx;
  end: serdes_pipe_tx_sdata_PROC

  assign serdes_pipe_txdatavalid = pre_serdes_pipe_txdatavalid;

delay_n
#(
    .N(1),
    .WD(SERDES_PIPE_TX_BUS_WD),
    .RESETVAL({SERDES_PIPE_TX_BUS_WD{1'b0}})
) u_serdes_pipe_tx_pipeline (
    .clk        (clk),
    .rst_n      (rst_n),
    .clear      (1'b0),
    .din        (pre_serdes_pipe_tx_sdata),
    .dout       (serdes_pipe_tx_sdata)
);

delay_n
#(
    .N(1),
    .WD(PHY_TXEI_WD),
    .RESETVAL({PHY_TXEI_WD{1'b1}})
) u_serdes_pipe_txelecidle_pipeline (
    .clk        (clk),
    .rst_n      (rst_n),
    .clear      (1'b0),
    .din        (pre_serdes_pipe_txelecidle),
    .dout       (serdes_pipe_txelecidle)
);


endmodule: serdes_pipe_tx
