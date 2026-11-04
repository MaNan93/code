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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/xplh_retryram_if.sv#5 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// XPLH RETRY RAM Interface 
//
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Plh/xplh_pkg.svh"

module xplh_retryram_if
  import  cx_pl_pkg::rbuf_struct;
  import  cx_pl_pkg::P_RBUF_WD;
  import  cx_pl_pkg::P_RBUF_PW;
  import  cx_pl_pkg::P_RBUF_CTRL_WD;
  import  cx_pl_pkg::tx_flit_struct;
  import  cx_pl_pkg::P_DW;
  import  cx_pl_pkg::DATA_PAR_WD;
  import  cx_pl_pkg::P_NW;
  import  cx_pl_pkg::P_RBUF_PROT_WD;
  import  cx_pl_pkg::P_PARITY_MODE;
  import  cx_pl_pkg::P_PROT_TYPE;
  import  cx_pl_pkg::P_PROT_RANGE;
  import  cx_pl_pkg::P_PROT_CORRECT_EN;
  import  cx_pl_pkg::P_RAS_RAM_PROT_RANGE;
  import  cx_pl_pkg::P_RAS_RAM_PROT_TYPE;
  import  cx_pl_pkg::P_RAS_RAM_PARITY_MODE;
  import  DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import  DWC_pcie_ctl_pkg::calc_ecc_wd;
  import  DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
  parameter RAS_DP_PROT_CHK_ID_BASE = 0
) (
  input                           core_clk,                   // Core clock
  input                           core_rst_n,                 // Core Reset
  input   tx_flit_struct          flit_in,                    // Input Flit
  input   rbuf_struct             retryram_if_in,             // Input RAM interface before Pipeline
  input   [P_RBUF_WD - 1 : 0]     retrybuf_rdata,             // Data Read from Retry Buffer
  input   logic [P_RBUF_PW-1:0]   rbuf_raddr_to_checker,      // Delayed Read address to checker
  output  logic [P_DW - 1 : 0]    xplh_retryram_if_rdata,     // Data Read from Retry Buffer after ECC Check
  output  rbuf_struct             xplh_retryram_if_out,       // Output RAM interface
  output  tx_flit_struct          xplh_retryram_if_flit_out   // Output Flit
  ,
  output  logic                   xplh_retryram_if_rdata_err, // Retry ram read data uncorrectable error
  input                           retrybuf_rdata_valid,       // Data from retry buffer is valid
  output  ras_dp_err_log_t  [1:0] xplh_retryram_if_err_log    // RASDP Error Log
  ,
  input  ras_dp_err_inj_t         ras_dp_err_inj
);

// -------------------------------------------------------------------------------------
// Parity Check on Incoming Data 
// -------------------------------------------------------------------------------------

ras_dp_pipe
 #(
  .PIPELINE_TYPE           (0),               // No pipeline only checker instance
  .N_STAGES                (0),               // No pipeline delay from module
  .CAN_STALL               (0),               // No stalling
  .BUS_PROTECT_GEN_EN      (0),               // No generator
  .BUS_PROTECT_CHK_EN      (1),               // Checker enabled
  .PROT_TYPE               (P_PROT_TYPE),     // Parity check enabled
  .PROT_RANGE              (P_PROT_RANGE),
  .PROT_WD                 (DATA_PAR_WD),
  .PARITY_MODE             (P_PARITY_MODE),
  .PROT_CORRECT_EN         (P_PROT_CORRECT_EN), // No correction
  .TOTAL_WIDTH             (P_DW),  
  .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE)
) u_xdlh_xplh_data_chk (
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
  
  .valid_out                  (xplh_retryram_if_flit_out.data_valid),
  .dout                       (xplh_retryram_if_flit_out.data),
  .dout_prot                  (),
  .halt_in                    (1'b0),
  .ras_dp_err_inband_kbd_in   (flit_in.ras_dp_err_inband_kbd),
  .ras_dp_err_inband_kbd_out  (xplh_retryram_if_flit_out.ras_dp_err_inband_kbd),
  .ras_dp_err_log             (xplh_retryram_if_err_log[0])
  ,
  .ras_dp_err_inj             (ras_dp_err_inj)
);

assign xplh_retryram_if_flit_out.flit_prot = '0;
assign xplh_retryram_if_flit_out.sof = flit_in.sof;
assign xplh_retryram_if_flit_out.eof = flit_in.eof;
assign xplh_retryram_if_flit_out.enf = flit_in.enf;
assign xplh_retryram_if_flit_out.retry_flit = flit_in.retry_flit;
assign xplh_retryram_if_flit_out.expl_flit = flit_in.expl_flit;
assign xplh_retryram_if_flit_out.tlp_dv = flit_in.tlp_dv;
assign xplh_retryram_if_flit_out.flit_type_s = flit_in.flit_type_s;

// -------------------------------------------------------------------------------------
// ECC Generation on write data to the RAM
// -------------------------------------------------------------------------------------
localparam P_RBUF_WDATA_WD = ((P_NW>16)? 0 : `CX_RBUF_CTRL_WD) + P_DW;
localparam XPLH_RETRY_RAM_PROT_WD = (P_DW / P_RAS_RAM_PROT_RANGE) * calc_ecc_wd(P_RAS_RAM_PROT_RANGE);

// ECC on RAM Write Address+Data
logic            unused_u_rbuf_wr_data_prot_halt_out;
logic            unused_u_rbuf_wr_data_prot_stall_out;
logic            unused_u_rbuf_wr_data_prot_valid_out;
logic            unused_u_rbuf_wr_data_prot_ras_dp_err_inband_kbd_out;
ras_dp_err_log_t unused_u_rbuf_wr_data_prot_ras_dp_err_log;

ras_dp_pipe
 #(
  .PIPELINE_TYPE           (3),
  .RESETVAL                (0),
  .N_STAGES                (1),
  .CAN_STALL               (0),
  .RESET_STALL             (0),
  .BUS_PROTECT_GEN_EN      (1),
  .BUS_PROTECT_CHK_EN      (0),
  .PROT_TYPE               (P_RAS_RAM_PROT_TYPE),
  .PROT_RANGE              (P_RAS_RAM_PROT_RANGE),
  .PROT_WD                 (XPLH_RETRY_RAM_PROT_WD),
  .PARITY_MODE             (P_RAS_RAM_PARITY_MODE),
  .PROT_CORRECT_EN         (P_PROT_CORRECT_EN),
  .TOTAL_WIDTH             (P_DW + P_RBUF_PW),
  .EXCLUDE_PROT_WIDTH      (0),
  .RAS_DP_PROT_CHK_ID_BASE (0),
  .ADDR_ECC_PROT_EN        (1),
  .ADDR_LOG_EN             (1),
  .ADDR_INDEX              (P_DW),
  .ADDR_WD                 (P_RBUF_PW)
) u_rbuf_wr_data_prot (
  .clk                        (core_clk),
  .rst_n                      (core_rst_n),
  .en                         (retryram_if_in.retryram_we),
  .bypass                     (1'b0),
  .stall                      (1'b0),
  .stallout                   (unused_u_rbuf_wr_data_prot_stall_out),
  .valid_in                   (1'b1),
  .din                        ({retryram_if_in.retryram_waddr,             retryram_if_in.retryram_data[P_DW - 1 : 0]}),
  .din_prot                   ('0),
  .halt_out                   (unused_u_rbuf_wr_data_prot_halt_out),
  
  .valid_out                  (unused_u_rbuf_wr_data_prot_valid_out),
  .dout                       ({xplh_retryram_if_out.retryram_waddr, xplh_retryram_if_out.retryram_data[P_DW - 1 : 0]}),
  .dout_prot                  (                                      xplh_retryram_if_out.retryram_data[P_RBUF_WDATA_WD +: XPLH_RETRY_RAM_PROT_WD]),
  .halt_in                    (1'b0),
  .ras_dp_err_inband_kbd_in   (1'b0),
  .ras_dp_err_inband_kbd_out  (unused_u_rbuf_wr_data_prot_ras_dp_err_inband_kbd_out),
  .ras_dp_err_log             (unused_u_rbuf_wr_data_prot_ras_dp_err_log)
  ,
  .ras_dp_err_inj             (ras_dp_err_inj)
);

generate
if (P_NW<=16) begin : g_drive_0_on_unused_bits
    // The additional width which may be needed to include address in the ecc calculation is compensated by removing the control bits from the calculation (they're always zero)
    // As a consequence control bits are zeroed again after the ecc generator and so is the ecc on control bits
    assign xplh_retryram_if_out.retryram_data[P_DW +: `CX_RBUF_CTRL_WD] = '0;
    assign xplh_retryram_if_out.retryram_data[(P_RBUF_WDATA_WD + XPLH_RETRY_RAM_PROT_WD) +: calc_ecc_wd(`CX_RBUF_CTRL_WD+P_RBUF_PW)] = '0;
end
endgenerate

// ECC Check on Data Read from Retry Buffer FIFO
logic                 unused_u_rbuf_rd_data_check_stall_out;
logic                 unused_u_rbuf_rd_data_check_halt_out;
logic                 unused_u_rbuf_rd_data_check_valid_out;
logic [P_RBUF_PW-1:0] unused_u_rbuf_rd_data_check_retryram_raddr;

ras_dp_pipe
 #(
  .PIPELINE_TYPE           (0),
  .RESETVAL                (0),
  .N_STAGES                (0),
  .CAN_STALL               (0),
  .RESET_STALL             (0),
  .BUS_PROTECT_GEN_EN      (0),
  .BUS_PROTECT_CHK_EN      (1),
  .PROT_TYPE               (P_RAS_RAM_PROT_TYPE),
  .PROT_RANGE              (P_RAS_RAM_PROT_RANGE),
  .PROT_WD                 (XPLH_RETRY_RAM_PROT_WD),
  .PARITY_MODE             (P_RAS_RAM_PARITY_MODE),
  .PROT_CORRECT_EN         (1),
  .TOTAL_WIDTH             (P_DW + P_RBUF_PW),
  .EXCLUDE_PROT_WIDTH      (0),
  .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+1),
  .ADDR_ECC_PROT_EN        (1),
  .ADDR_LOG_EN             (1),
  .ADDR_INDEX              (P_DW),
  .ADDR_WD                 (P_RBUF_PW)
) u_rbuf_rd_data_check (
  .clk                        (core_clk),
  .rst_n                      (core_rst_n),
  .en                         (1'b1),
  .bypass                     (1'b0),
  .stall                      (1'b0),
  .stallout                   (unused_u_rbuf_rd_data_check_stall_out),
  .valid_in                   (retrybuf_rdata_valid),
  .din                        ({rbuf_raddr_to_checker, retrybuf_rdata[P_DW-1:0]}),
  .din_prot                   (retrybuf_rdata[P_RBUF_WDATA_WD +: XPLH_RETRY_RAM_PROT_WD]),
  .halt_out                   (unused_u_rbuf_rd_data_check_halt_out),
  
  .valid_out                  (unused_u_rbuf_rd_data_check_valid_out),
  .dout                       ({unused_u_rbuf_rd_data_check_retryram_raddr, xplh_retryram_if_rdata}),
  .dout_prot                  (),
  .halt_in                    (1'b0),
  .ras_dp_err_inband_kbd_in   (1'b0),
  .ras_dp_err_inband_kbd_out  (xplh_retryram_if_rdata_err),
  .ras_dp_err_log             (xplh_retryram_if_err_log[1])
  ,
  .ras_dp_err_inj             (ras_dp_err_inj)
);

// Read address is pipelined
delay_n_w_enable
 #(
  .N  (1),
  .WD (P_RBUF_PW)
) delay_n_w_enable_raddr (
  .clk   (core_clk),
  .rst_n (core_rst_n),
  .clear (1'b0),
  .en    (retryram_if_in.retryram_en),
  .din   (retryram_if_in.retryram_raddr),
  .dout  (xplh_retryram_if_out.retryram_raddr) 
);


// Pipeline the Write Enable and Read Enable 
delay_n

#(1, 2) u_rbuf_en_pipe (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .din    ({retryram_if_in.retryram_we, retryram_if_in.retryram_en}),
  .dout   ({xplh_retryram_if_out.retryram_we, xplh_retryram_if_out.retryram_en})
);

endmodule
