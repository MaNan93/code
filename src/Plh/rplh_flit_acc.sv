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
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_flit_acc.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description: 
//       -Accumulate Half/Full Flits from Different DW
//       -Instantiate Error Injection Module on the Full Flit
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module rplh_flit_acc

  import cx_pl_pkg::P_FLIT_WD;
  import cx_pl_pkg::P_TX_SEQNUM_WD;
  import DWC_pcie_core_pkg::flit_err_inj_interface_struct;
  import DWC_pcie_core_pkg::curr_inj_err_type_e;
  import DWC_pcie_core_pkg::flit_type_inj_e;
  import DWC_pcie_core_pkg::inj_sts_e;
#(
parameter   NL           = `CX_NL,                             // Max number of lanes supported
parameter   NB           = `CX_NB,                             // Number of symbols (bytes) per clock cycle
parameter   AW           = `CX_ANB_WD,                         // Width of the active number of bytes
parameter   NW           = `CX_PL_NW,                          // Number of 32-bit dwords handled by the datapath each clock.
parameter   DW           = (32*NW),                            // Width of datapath in bits.
parameter   QDW          = (NW<4)? 1 : NW/4,                   // Number of 128-bit q-dwords handled by the datapath each clock.
parameter   TP           = `TP                                 // Clock to Q delay (simulator insurance)    
)

                      (
// ---- inputs ---------------
input                                   core_clk,
input                                   core_rst_n,
input [5                  :0]           smlh_link_mode,
input [AW-1               :0]           active_nb,
input                                   search_for_tokens,               // enable token processing while in a data stream
input                                   rxdata_dv,                       // data is valid this cycle
input [(NL*NB*8)-1        :0]           rxdata,                          // Incoming data from rmlh
input [2                  :0]           current_data_rate,               // Current Data Rate
input [P_TX_SEQNUM_WD-1   :0]           implicit_rx_flit_seq_num,        // Implicit Flit Sequence Number of received Flits
input                                   implicit_rx_flit_seq_num_valid,  // Implicit Flit Sequence Number of received Flits Valid
input                                   cxl_mode_enable,                 // CXL Mode is enabled
input flit_err_inj_interface_struct     cdm_plh_flit_err_inj_interface,  // Flit Error Injection interface struct
// ---- outputs ---------------
output                                  rxdata_o_vld,                    // Input data valid gated by search for tokens
output                                  rplh_acc_flit_nxt_vld,           // Combinational version of accumulated flit is valid
output  [P_FLIT_WD-1      :0]           rplh_acc_flit_nxt,               // Combinational version of accumulated flit
output  [P_FLIT_WD-1      :0]           rplh_acc_flit                    // Registered version of accumulated flit
,
output  logic [1          :0]           rplh_cdm_flit_err_inj_status     // Flit Error Injection Status

);
// Internal signals
logic [3        :0] valid_bytes; // Number of valid bytes when lower than 16
                                 // In case of 16 or more bytes (i.e. 1 or more qDWs of data) valid_bytes value is '0' 
logic [15*8-1   :0] latched_rxdata;      // Latched Received Data (up to 15 bytes)
logic [NL*NB*8-1:0] rxdata_qdw;
logic               rxdata_qdw_dv;    
logic [3        :0] bytes_cnt;   // Received Data Bytes Counter 
logic [3        :0] active_qdw;                  
always @(*) begin : valid_bytes_comb_PROC
    case( {active_nb[3:0], smlh_link_mode[3:0]} )
        8'b1000_0001 /* 8sx1 */ : valid_bytes = 4'b1000;

        8'b0100_0010 /* 4sx2 */ : valid_bytes = 4'b1000;
        8'b0100_0001 /* 4sx1 */ : valid_bytes = 4'b0100;

        8'b0010_0100 /* 2sx4 */ : valid_bytes = 4'b1000;
        8'b0010_0010 /* 2sx2 */ : valid_bytes = 4'b0100;
        8'b0010_0001 /* 2sx1 */ : valid_bytes = 4'b0010;

        8'b0001_1000 /* 1sx8 */ : valid_bytes = 4'b1000;
        8'b0001_0100 /* 1sx4 */ : valid_bytes = 4'b0100;
        8'b0001_0010 /* 1sx2 */ : valid_bytes = 4'b0010;
        8'b0001_0001 /* 1sx1 */ : valid_bytes = 4'b0001;

        default    /* higher */ : valid_bytes = 4'b0000;
    endcase
end

always @(posedge core_clk or negedge core_rst_n) begin : latched_rxdata_proc
    if (!core_rst_n) begin
        latched_rxdata <= #TP 120'h0;
    end
    else if (!search_for_tokens) begin
        latched_rxdata <= #TP 120'h0;
    end
    else if (rxdata_dv) begin
        if(valid_bytes[0])       // 1 Byte
            latched_rxdata <= #TP { rxdata[0 +: 1*8], latched_rxdata[8*1 +: 14*8]};
        else if(valid_bytes[1])  // 2 Bytes
            latched_rxdata <= #TP { rxdata[0 +: 2*8], latched_rxdata[8*2 +: 13*8]};
        else if(valid_bytes[2])  // 4 Bytes
            latched_rxdata <= #TP { rxdata[0 +: 4*8], latched_rxdata[8*4 +: 11*8]};
        else if(valid_bytes[3])  // 8 Bytes
            latched_rxdata <= #TP { rxdata[0 +: 8*8], latched_rxdata[8*8 +:  7*8]};
        else
            latched_rxdata <= #TP 120'h0;
    end
end

always @(posedge core_clk or negedge core_rst_n) begin : bytes_cnt_proc
    if (!core_rst_n)
        bytes_cnt <= #TP 0;
    else if (!search_for_tokens)
        bytes_cnt <= #TP 0;
    else if (rxdata_dv)
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        bytes_cnt <= #TP bytes_cnt + valid_bytes;
// spyglass enable_block W164a
end

assign rxdata_qdw[16*8-1:0] = (valid_bytes[0]) ? {rxdata[0 +:  1*8], latched_rxdata[15*8-1 -: 15*8]} :
                              (valid_bytes[1]) ? {rxdata[0 +:  2*8], latched_rxdata[15*8-1 -: 14*8]} :
                              (valid_bytes[2]) ? {rxdata[0 +:  4*8], latched_rxdata[15*8-1 -: 12*8]} :
                              (valid_bytes[3]) ? {rxdata[0 +:  8*8], latched_rxdata[15*8-1 -:  8*8]} :
                                                  rxdata[0 +: 16*8];
assign rxdata_qdw[NL*NB*8-1:16*8] =  rxdata[NL*NB*8-1:16*8];

assign rxdata_qdw_dv = valid_bytes[0] ? (rxdata_dv && bytes_cnt == 4'b1111) :
                       valid_bytes[1] ? (rxdata_dv && bytes_cnt == 4'b1110) :
                       valid_bytes[2] ? (rxdata_dv && bytes_cnt == 4'b1100) :
                       valid_bytes[3] ? (rxdata_dv && bytes_cnt == 4'b1000) :
                                         rxdata_dv;



always @(*) begin : active_qdw_comb_PROC
    case( {{6-AW{1'b0}},active_nb, smlh_link_mode[4:0]}  )
        // 1024b 8 qdw (32dw) datapath
        11'b001000_10000 /*  8sx16 */  : active_qdw = 4'h8;
        11'b010000_01000 /* 16sx8  */  : active_qdw = 4'h8;

        //  512b 4 qdw (16dw) datapath
        11'b000100_10000 /*  4sx16 */  : active_qdw = 4'h4;
        11'b001000_01000 /*  8sx8  */  : active_qdw = 4'h4;
        11'b010000_00100 /* 16sx4  */  : active_qdw = 4'h4;

        //  256b 2 qdw (8dw) datapath
        11'b000010_10000 /*  2sx16 */  : active_qdw = 4'h2;
        11'b000100_01000 /*  4sx8  */  : active_qdw = 4'h2;
        11'b001000_00100 /*  8sx4  */  : active_qdw = 4'h2;
        11'b010000_00010 /* 16sx2  */  : active_qdw = 4'h2;

        //  128b 1 qdw (4dw) datapath
        default                        : active_qdw = 4'h1;

    endcase
end

// Accumulate the data so that the full Flit is available for correction
localparam P_DW_CNT = 16;
localparam P_DW_CNT_WD = $clog2(P_DW_CNT);
logic [P_FLIT_WD - 1   :0]       flit_s;
logic [P_FLIT_WD - 1   :0]       flit_r;
logic [P_DW_CNT_WD - 1 :0]       dw_cnt_r;
logic                            data_valid_s;
logic [P_FLIT_WD - 1   :0]       flit_s_mux;
logic [P_DW_CNT_WD     :0]       dw_cnt_nxt;
// Count the number of Data Path Chunks per Flit 
always_ff @(posedge core_clk or negedge core_rst_n) begin : dw_cnt_PROC
  if(!core_rst_n)
    dw_cnt_r <= #TP {P_DW_CNT_WD{1'b0}};
  else begin
    if(~search_for_tokens) begin
        dw_cnt_r <= #TP {P_DW_CNT_WD{1'b0}};
    end else begin
      if(rxdata_qdw_dv)
        dw_cnt_r <= #TP dw_cnt_nxt[P_DW_CNT_WD-1:0];
    end
  end
end : dw_cnt_PROC
assign dw_cnt_nxt = {1'b0, dw_cnt_r} + {1'b0, active_qdw};

always_ff @(posedge core_clk or negedge core_rst_n) begin : flit_PROC
  if(!core_rst_n) begin
    flit_r   <= #TP {P_FLIT_WD{1'b0}};
  end else begin
    if(rxdata_qdw_dv) begin
      flit_r   <= #TP flit_s_mux;
    end
  end
end : flit_PROC

// Accumulate the full flit for the correction
always_comb begin : flit_accum_PROC
  unique case (dw_cnt_r)
      0   : flit_s = { {(16-QDW-0)*128{1'b0}}, rxdata_qdw,        { 0*128{1'b0}} };
      1   : flit_s = { {(16-QDW-1)*128{1'b0}}, rxdata_qdw,        flit_r[(1*128) - 1 : 0] }; 
      2   : flit_s = { {(16-QDW-2)*128{1'b0}}, rxdata_qdw,        flit_r[(2*128) - 1 : 0] }; 
      3   : flit_s = { {(16-QDW-3)*128{1'b0}}, rxdata_qdw,        flit_r[(3*128) - 1 : 0] }; 
      4   : flit_s = { {(16-QDW-4)*128{1'b0}}, rxdata_qdw,        flit_r[(4*128) - 1 : 0] }; 
      5   : flit_s = { {(16-QDW-5)*128{1'b0}}, rxdata_qdw,        flit_r[(5*128) - 1 : 0] }; 
      6   : flit_s = { {(16-QDW-6)*128{1'b0}}, rxdata_qdw,        flit_r[(6*128) - 1 : 0] }; 
      7   : flit_s = { {(16-QDW-7)*128{1'b0}}, rxdata_qdw,        flit_r[(7*128) - 1 : 0] }; 
      8   : flit_s = { {(16-QDW-8)*128{1'b0}}, rxdata_qdw,        flit_r[(8*128) - 1 : 0] }; 
      9   : flit_s = {          {6*128{1'b0}}, rxdata_qdw[127:0], flit_r[(9*128) - 1 : 0] }; 
      10  : flit_s = {          {4*128{1'b0}}, rxdata_qdw[255:0], flit_r[(10*128) - 1 : 0] }; 
      11  : flit_s = {          {4*128{1'b0}}, rxdata_qdw[127:0], flit_r[(11*128) - 1 : 0] }; 
      12  : flit_s = {                         rxdata_qdw[511:0], flit_r[(12*128) - 1 : 0] }; 
      13  : flit_s = {          {2*128{1'b0}}, rxdata_qdw[127:0], flit_r[(13*128) - 1 : 0] }; 
      14  : flit_s = {                         rxdata_qdw[255:0], flit_r[(14*128) - 1 : 0] }; 
      15  : flit_s = {                         rxdata_qdw[127:0], flit_r[(15*128) - 1 : 0] }; 
      default : flit_s = {P_FLIT_WD{1'b0}};
  endcase
end : flit_accum_PROC

localparam P_FEC_PIPE_STAGES = 1;  // Additional register stage for FPGA configs
logic [P_FLIT_WD - 1   :0]       err_inj_flit;
inj_sts_e                        err_inj_sts_e;
logic  [1              :0]       err_inj_sts;
logic  [1              :0]       int_err_inj_sts;

// RX Flit Error Injection
rplh_fec_err_inj
 u_rplh_fec_err_inj (
  .core_clk                        (core_clk),
  .core_rst_n                      (core_rst_n),
  .current_data_rate               (current_data_rate),
  .flit_in                         (flit_s),
  .flit_valid                      (rplh_acc_flit_nxt_vld),
  .implicit_rx_flit_seq_num        (implicit_rx_flit_seq_num),
  .implicit_rx_flit_seq_num_valid  (implicit_rx_flit_seq_num_valid),
  .cxl_mode_enable                 (cxl_mode_enable),
  // Inputs from CDM
  .err_inj_en                      (cdm_plh_flit_err_inj_interface.cfg_flit_err_inj_en),
  .err_inj_rx_en                   (cdm_plh_flit_err_inj_interface.cfg_inj_err_rx_flit_ind),
  .err_inj_num                     (cdm_plh_flit_err_inj_interface.cfg_inj_err_num),
  .err_inj_data_rate               (cdm_plh_flit_err_inj_interface.cfg_flit_err_inj_en_data_rate),
  .err_inj_flit_type               (flit_type_inj_e'(cdm_plh_flit_err_inj_interface.cfg_flit_type_inj)),
  .err_inj_cons_error              (cdm_plh_flit_err_inj_interface.cfg_consec_err_inj),
  .err_inj_spacing                 (cdm_plh_flit_err_inj_interface.cfg_inj_err_spacing),
  .err_inj_error_type              (curr_inj_err_type_e'(cdm_plh_flit_err_inj_interface.cfg_curr_inj_err_type)),
  .err_inj_error_offst             (cdm_plh_flit_err_inj_interface.cfg_flit_err_off),
  .err_inj_error_mag               (cdm_plh_flit_err_inj_interface.cfg_err_mag),
  // Outputs
  .err_inj_flit                    (err_inj_flit),
  .err_inj_sts                     (err_inj_sts_e)
);

assign flit_s_mux = err_inj_flit;
assign err_inj_sts = inj_sts_e'(err_inj_sts_e);

// Added a pipeline stage before decoder module to be synthesis friendly
delay_n

#(1, $bits(err_inj_sts)) u_int_err_inj_sts_pipe (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .din    (err_inj_sts),
    .dout   (int_err_inj_sts)
);

delay_n

#(P_FEC_PIPE_STAGES, $bits(int_err_inj_sts)) u_err_inj_pipe_out (
    .clk    (core_clk),
    .rst_n  (core_rst_n),
    .clear  (1'b0),
    .din    (int_err_inj_sts),
    .dout   (rplh_cdm_flit_err_inj_status)
);


// Data Valid must be gated by search for tokens since search for tokens can de-assert during the data stream
// It is not expected that this filter on data valid is necessary if data valid was behaving correctly.
assign data_valid_s           = rxdata_qdw_dv & search_for_tokens;
// Enable FEC check on last valid data of the Flit
assign rplh_acc_flit_nxt_vld  = (dw_cnt_nxt == P_DW_CNT) && (data_valid_s);
assign rplh_acc_flit          = flit_r;
assign rplh_acc_flit_nxt      = flit_s_mux;
assign rxdata_o_vld           = data_valid_s;


endmodule
