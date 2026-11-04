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
// --- RCS information:
// ---   $DateTime: 2023/10/24 16:15:36 $
// ---   $Revision: #7 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_crc.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Implements the CRC generation over the TLP and DLP bytes of the Flit
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module xplh_crc
  import cx_pl_pkg::tx_flit_struct;
  import cx_pl_pkg::P_FLIT_DW_CNT_WD;
  import cx_pl_pkg::P_FLIT_DW_CNT;
  import cx_pl_pkg::P_DW;
  import cx_pl_pkg::P_COEF0;
  import cx_pl_pkg::P_COEF1;
  import cx_pl_pkg::P_COEF2;
  import cx_pl_pkg::P_COEF3;
  import cx_pl_pkg::P_COEF4;
  import cx_pl_pkg::P_COEF5;
  import cx_pl_pkg::P_COEF6;
  import cx_pl_pkg::P_COEF7;
  import cx_pl_pkg::P_PROT_TYPE;
  import cx_pl_pkg::P_PROT_RANGE;
  import cx_pl_pkg::P_PARITY_MODE;
  import cx_pl_pkg::P_PROT_CORRECT_EN;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::UNCORRECTABLE;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter TP = `TP
  ,
  parameter RAS_DP_PROT_CHK_ID_BASE = 0
) 
                 (
  // Inputs
  input                       core_clk,
  input                       core_rst_n,
  input                       clear,                // Synchronous reset
  input                       cxl_mode_enable,
  input tx_flit_struct        flit_in,              // Input Flit
  input                       halt_in,              // Halt in
  input                       cmd_ack,              // Upper layer command acknowledge
  // Outputs
  output  logic               xplh_crc_halt,          // Back-pressure from CRC
  output  tx_flit_struct      xplh_crc_flit,          // Output Flit
  output  logic               xplh_crc_cmd_ack        // Command Acknowledge
  ,
  output                      xplh_rasdp_error        // XPLH RASDP Error driven from the last checker
  ,
  output  ras_dp_err_log_t    xplh_crc_ras_dp_err_log // RASDP Error Logging
  ,
  input   ras_dp_err_inj_t    ras_dp_err_inj          // RASDP Error Injection
);

// Local Parameters
localparam P_N_CRC_GEN = 8;
localparam P_CRC_WD = 8 * P_N_CRC_GEN;
localparam P_CRC_PIPE_WD = $bits(flit_in);

// Logic Declarations
logic [P_FLIT_DW_CNT_WD - 1 : 0] r_dw_cnt;
logic [7 : 0]               s_crc7;
logic [7 : 0]               s_crc6;
logic [7 : 0]               s_crc5;
logic [7 : 0]               s_crc4;
logic [7 : 0]               s_crc3;
logic [7 : 0]               s_crc2;
logic [7 : 0]               s_crc1;
logic [7 : 0]               s_crc0;
logic [7 : 0]               r_crc7;
logic [7 : 0]               r_crc6;
logic [7 : 0]               r_crc5;
logic [7 : 0]               r_crc4;
logic [7 : 0]               r_crc3;
logic [7 : 0]               r_crc2;
logic [7 : 0]               r_crc1;
logic [7 : 0]               r_crc0;
logic [P_CRC_WD - 1 : 0]    s_crc_result;
logic [7 : 0]               s_crc7_accum;
logic [7 : 0]               s_crc6_accum;
logic [7 : 0]               s_crc5_accum;
logic [7 : 0]               s_crc4_accum;
logic [7 : 0]               s_crc3_accum;
logic [7 : 0]               s_crc2_accum;
logic [7 : 0]               s_crc1_accum;
logic [7 : 0]               s_crc0_accum;
logic                       s_en_dw_cnt;
logic                       r_en_dw_cnt;
tx_flit_struct              int_crc_flit;

always_comb begin : dw_cnt_en_PROC
  if(clear)
    s_en_dw_cnt = 1'b0;
  else if(flit_in.sof && !halt_in)
    s_en_dw_cnt = 1'b1;
  else if(flit_in.eof[1] && !halt_in)
    s_en_dw_cnt = 1'b0;
  else
    s_en_dw_cnt = r_en_dw_cnt;
end : dw_cnt_en_PROC

// Count the number of Data Path Chunks per Flit 
always_ff @(posedge core_clk or negedge core_rst_n) begin : dw_cnt_PROC
  if(!core_rst_n) begin
    r_dw_cnt <= #TP {P_FLIT_DW_CNT_WD{1'b0}};
    r_en_dw_cnt <= #TP 1'b0;
  end else begin
    r_en_dw_cnt <= #TP s_en_dw_cnt;
    if(clear)
      r_dw_cnt  <= #TP '0;
    else if(!halt_in && (s_en_dw_cnt || r_en_dw_cnt)) begin
      if(r_dw_cnt == P_FLIT_DW_CNT - 1)
        r_dw_cnt <= #TP {P_FLIT_DW_CNT_WD{1'b0}};
      else
        r_dw_cnt <= #TP r_dw_cnt + 1'b1;
    end
  end
end : dw_cnt_PROC

// Instantiate the CRC Generators
xplh_crc_gen
 #(
  .P_COEF       (P_COEF7)
) u_crc_gen7 (
  // Inputs
  .dw_cnt   (r_dw_cnt),
  .data_in  (flit_in.data),
  // Outputs
  .crc_out  (s_crc7)
);
xplh_crc_gen
 #(
  .P_COEF       (P_COEF6)
) u_crc_gen6 (
  // Inputs
  .dw_cnt   (r_dw_cnt),
  .data_in  (flit_in.data),
  // Outputs
  .crc_out  (s_crc6)
);
xplh_crc_gen
 #(
  .P_COEF       (P_COEF5)
) u_crc_gen5 (
  // Inputs
  .dw_cnt   (r_dw_cnt),
  .data_in  (flit_in.data),
  // Outputs
  .crc_out  (s_crc5)
);
xplh_crc_gen
 #(
  .P_COEF       (P_COEF4)
) u_crc_gen4 (
  // Inputs
  .dw_cnt   (r_dw_cnt),
  .data_in  (flit_in.data),
  // Outputs
  .crc_out  (s_crc4)
);
xplh_crc_gen
 #(
  .P_COEF       (P_COEF3)
) u_crc_gen3 (
  // Inputs
  .dw_cnt   (r_dw_cnt),
  .data_in  (flit_in.data),
  // Outputs
  .crc_out  (s_crc3)
);
xplh_crc_gen
 #(
  .P_COEF       (P_COEF2)
) u_crc_gen2 (
  // Inputs
  .dw_cnt   (r_dw_cnt),
  .data_in  (flit_in.data),
  // Outputs
  .crc_out  (s_crc2)
);
xplh_crc_gen
 #(
  .P_COEF       (P_COEF1)
) u_crc_gen1 (
  // Inputs
  .dw_cnt   (r_dw_cnt),
  .data_in  (flit_in.data),
  // Outputs
  .crc_out  (s_crc1)
);
xplh_crc_gen
 #(
  .P_COEF       (P_COEF0)
) u_crc_gen0 (
  // Inputs
  .dw_cnt   (r_dw_cnt),
  .data_in  (flit_in.data),
  // Outputs
  .crc_out  (s_crc0)
);

always_ff @(posedge core_clk or negedge core_rst_n) begin : crc_out_PROC
  if(!core_rst_n) begin
    r_crc7  <= #TP 8'h00;
    r_crc6  <= #TP 8'h00;
    r_crc5  <= #TP 8'h00;
    r_crc4  <= #TP 8'h00;
    r_crc3  <= #TP 8'h00;
    r_crc2  <= #TP 8'h00;
    r_crc1  <= #TP 8'h00;
    r_crc0  <= #TP 8'h00;
  end else begin
    if(clear) begin
      r_crc7  <= #TP 8'h00;
      r_crc6  <= #TP 8'h00;
      r_crc5  <= #TP 8'h00;
      r_crc4  <= #TP 8'h00;
      r_crc3  <= #TP 8'h00;
      r_crc2  <= #TP 8'h00;
      r_crc1  <= #TP 8'h00;
      r_crc0  <= #TP 8'h00;
    end else if(!halt_in) begin
      // Clear the accumulation at the end of Flit
      if(flit_in.eof[1]) begin
        r_crc7  <= #TP 8'h00;
        r_crc6  <= #TP 8'h00;
        r_crc5  <= #TP 8'h00;
        r_crc4  <= #TP 8'h00;
        r_crc3  <= #TP 8'h00;
        r_crc2  <= #TP 8'h00;
        r_crc1  <= #TP 8'h00;
        r_crc0  <= #TP 8'h00;
      end else begin
        r_crc7  <= #TP s_crc7_accum;
        r_crc6  <= #TP s_crc6_accum;
        r_crc5  <= #TP s_crc5_accum;
        r_crc4  <= #TP s_crc4_accum;
        r_crc3  <= #TP s_crc3_accum;
        r_crc2  <= #TP s_crc2_accum;
        r_crc1  <= #TP s_crc1_accum;
        r_crc0  <= #TP s_crc0_accum;
      end
    end
  end
end : crc_out_PROC

// Accumulate the CRC from the previous cycle
assign s_crc7_accum = (s_crc7 ^ r_crc7);
assign s_crc6_accum = (s_crc6 ^ r_crc6);
assign s_crc5_accum = (s_crc5 ^ r_crc5);
assign s_crc4_accum = (s_crc4 ^ r_crc4);
assign s_crc3_accum = (s_crc3 ^ r_crc3);
assign s_crc2_accum = (s_crc2 ^ r_crc2);
assign s_crc1_accum = (s_crc1 ^ r_crc1);
assign s_crc0_accum = (s_crc0 ^ r_crc0);

// Calculate the CRC result
assign s_crc_result = {s_crc7_accum, s_crc6_accum, s_crc5_accum, s_crc4_accum,
                       s_crc3_accum, s_crc2_accum, s_crc1_accum, s_crc0_accum};

localparam P_FLIT_PROT_WD = $bits(flit_in.flit_prot);
localparam P_FLIT_DATA_WD = $bits(flit_in.data);
logic int_ras_dp_err_inband_kbd;
logic int_inj_err_r;
logic [P_CRC_WD - 1 : 0] s_crc_corrupt;
`ifdef SNPS_TB_INTERFACE
DwDutRasDpXplhIf u_DwDutRasDpXplhIf(.clk(core_clk), .rst_n(core_rst_n));
initial uvm_pkg::uvm_config_db #(virtual DwDutRasDpXplhIf)::set(uvm_pkg::uvm_root::get(),{"*"},"DwDutRasDpXplhIf", u_DwDutRasDpXplhIf);
`endif

// RAS DP Checker 
ras_dp_pipe
 #(
  .PIPELINE_TYPE           (0),
  .N_STAGES                (0),
  .CAN_STALL               (0),
  .BUS_PROTECT_GEN_EN      (0),
  .BUS_PROTECT_CHK_EN      (1),
  .PROT_TYPE               (P_PROT_TYPE),
  .PROT_RANGE              (P_PROT_RANGE),
  .PROT_WD                 (P_FLIT_PROT_WD),
  .PARITY_MODE             (P_PARITY_MODE),
  .PROT_CORRECT_EN         (P_PROT_CORRECT_EN),
  .TOTAL_WIDTH             (P_FLIT_DATA_WD),
  .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE)
) u_xplh_crc_check (
  .clk                        (core_clk),
  .rst_n                      (core_rst_n),
  .en                         (1'b1),
  .bypass                     (1'b0),
  .stall                      (1'b0),
  .stallout                   (),
  .valid_in                   (flit_in.data_valid),
  .din                        (flit_in.data),
  .din_prot                   (flit_in.flit_prot),
  .halt_out                   (),
  
  .valid_out                  (),
  .dout                       (),
  .dout_prot                  (),
  .halt_in                    (1'b0),
  .ras_dp_err_inband_kbd_in   (flit_in.ras_dp_err_inband_kbd),
  .ras_dp_err_inband_kbd_out  (int_ras_dp_err_inband_kbd),
  .ras_dp_err_log             (xplh_crc_ras_dp_err_log)
  ,
  .ras_dp_err_inj             (ras_dp_err_inj)
);

assign xplh_rasdp_error = int_ras_dp_err_inband_kbd;

// If RASDP Error Occurs Corrupt the CRC
always_ff @(posedge core_clk or negedge core_rst_n) begin : inj_err_PROC
  if(!core_rst_n)
    int_inj_err_r   <= #TP '0;
  else begin
    if(clear)
      int_inj_err_r <= #TP '0;
    else if(int_ras_dp_err_inband_kbd)
      int_inj_err_r <= #TP '1;
    else
      int_inj_err_r <= #TP int_inj_err_r;
  end
end : inj_err_PROC

always_comb begin : corrupt_crc_PROC
  s_crc_corrupt = s_crc_result;
  `ifdef SNPS_TB_INTERFACE
    u_DwDutRasDpXplhIf.corrupted_crc = 1'b0;
  `endif
  if(int_inj_err_r ||(int_ras_dp_err_inband_kbd)) begin
    s_crc_corrupt = ~s_crc_result;
    `ifdef SNPS_TB_INTERFACE
      u_DwDutRasDpXplhIf.corrupted_crc = 1'b1;
    `endif
  end
end : corrupt_crc_PROC

// Insert the CRC code into the end of the flit
always_comb begin : crc_ins_PROC
  int_crc_flit = flit_in;
  if(flit_in.eof[1])
      // crc placeholder markers used during cxl viral condition for CRC corruption to trigger a retry at remote partner
      int_crc_flit.data = {{6{8'h00}}, cxl_mode_enable? (flit_in.data[P_DW - (8 * 14) +: (8*8)] ^ s_crc_corrupt) : s_crc_corrupt , flit_in.data[P_DW - (8 * 14) - 1 : 0]};
end : crc_ins_PROC


delay_n_w_stalling
  #(
  .N          (1),
  .WD         (P_CRC_PIPE_WD),
  .CAN_STALL  (0)
) u_crc_pipe (
  .clk      (core_clk),
  .rst_n    (core_rst_n),
  .clear    (clear),
  .stall    (halt_in),
  .din      (int_crc_flit),
  .dout     (xplh_crc_flit),
  .stallout ()
);

assign xplh_crc_halt = halt_in;

// No halting applied to the command acknowledge
delay_n
  #(
  .N  (1),
  .WD (1)
) u_cmd_ack_pipe (
  .clk      (core_clk),
  .rst_n    (core_rst_n),
  .clear    (1'b0),
  .din      (cmd_ack),
  .dout     (xplh_crc_cmd_ack)
);


endmodule
