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
// ---   $DateTime: 2023/09/27 02:27:25 $
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Plh/rplh_crc.sv#5 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Implements the CRC generation over the TLP and DLP bytes of the Flit
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"

module rplh_crc
  import cx_pl_pkg::P_FLIT_WD;
  import cx_pl_pkg::P_COEF7;
  import cx_pl_pkg::P_COEF6;
  import cx_pl_pkg::P_COEF5;
  import cx_pl_pkg::P_COEF4;
  import cx_pl_pkg::P_COEF3;
  import cx_pl_pkg::P_COEF2;
  import cx_pl_pkg::P_COEF1;
  import cx_pl_pkg::P_COEF0;
  import cx_pl_pkg::P_PROT_TYPE;
  import cx_pl_pkg::P_PROT_RANGE;
  import cx_pl_pkg::P_FLIT_PROT_WD;
  import cx_pl_pkg::P_PARITY_MODE;
#(
  parameter   TP = `TP,
  parameter   P_DIN_WD         = P_FLIT_WD - (6*8),                       // Flit width less the FEC
  parameter   P_DOUT_WD        = P_FLIT_WD - (14 * 8),                    // Flit width less the FEC and CRC
  parameter   P_DOUT_WD_W_PROT = P_DOUT_WD +  P_FLIT_PROT_WD          // Flit width less the FEC and CRC with protection bits
) 
                 (
  // Inputs
  input                                      core_clk,
  input                                      core_rst_n,
  input [P_DIN_WD - 1 : 0]                   data_in,                     // Data in
  input                                      data_valid,                  // Data valid 
  input                                      data_invalid,                // Data invalid (FEC error)
  // Outputs
  output  logic [P_DOUT_WD_W_PROT - 1 : 0]   rplh_crc_data_out,           // Data out
  output  logic                              rplh_crc_data_valid,         // Data valid
  output  logic                              rplh_crc_data_invalid,       // CRC Data invalid
  output  logic                              rplh_fec_data_invalid        // FEC Data invalid
);

localparam REGOUT_EN = 1;

// Logic Declarations
logic [7 : 0]             s_crc_in_7;
logic [7 : 0]             s_crc_in_6;
logic [7 : 0]             s_crc_in_5;
logic [7 : 0]             s_crc_in_4;
logic [7 : 0]             s_crc_in_3;
logic [7 : 0]             s_crc_in_2;
logic [7 : 0]             s_crc_in_1;
logic [7 : 0]             s_crc_in_0;
logic                     s_crc_check7_error;
logic                     s_crc_check6_error;
logic                     s_crc_check5_error;
logic                     s_crc_check4_error;
logic                     s_crc_check3_error;
logic                     s_crc_check2_error;
logic                     s_crc_check1_error;
logic                     s_crc_check0_error;
logic                     s_crc_data_invalid;
logic                     s_crc_data_valid;
logic [P_DOUT_WD - 1 : 0] s_crc_data_out;

// Route the received CRC bytes to the CRC checkers
always_comb begin : rx_crc_PROC
  s_crc_in_7 = 8'h00;
  s_crc_in_6 = 8'h00;
  s_crc_in_5 = 8'h00;
  s_crc_in_4 = 8'h00;
  s_crc_in_3 = 8'h00;
  s_crc_in_2 = 8'h00;
  s_crc_in_1 = 8'h00;
  s_crc_in_0 = 8'h00;
  if(data_valid && !data_invalid) begin
    s_crc_in_7 = data_in[P_DIN_WD - 1 -: 8];
    s_crc_in_6 = data_in[P_DIN_WD - 1 - (1 * 8) -: 8];
    s_crc_in_5 = data_in[P_DIN_WD - 1 - (2 * 8) -: 8];
    s_crc_in_4 = data_in[P_DIN_WD - 1 - (3 * 8) -: 8];
    s_crc_in_3 = data_in[P_DIN_WD - 1 - (4 * 8) -: 8];
    s_crc_in_2 = data_in[P_DIN_WD - 1 - (5 * 8) -: 8];
    s_crc_in_1 = data_in[P_DIN_WD - 1 - (6 * 8) -: 8];
    s_crc_in_0 = data_in[P_DIN_WD - 1 - (7 * 8) -: 8];
  end
end : rx_crc_PROC

assign s_crc_data_invalid = (s_crc_check7_error || s_crc_check6_error || s_crc_check5_error || s_crc_check4_error ||
                      s_crc_check3_error || s_crc_check2_error || s_crc_check1_error || s_crc_check0_error);


assign s_crc_data_valid = !s_crc_data_invalid;
assign s_crc_data_out = data_in[P_DOUT_WD - 1 : 0];

ras_dp_pipe
 #(
                .PIPELINE_TYPE           (3                          ),  // delay_n_w_en
                .RESETVAL                (0                          ),
                .N_STAGES                (REGOUT_EN                  ),  
                .CAN_STALL               (0                          ),  
                .RESET_STALL             (0                          ),
                .BUS_PROTECT_GEN_EN      (1                          ),  // generate protection
                .BUS_PROTECT_CHK_EN      (0                          ),  // nothing to check
                .PROT_TYPE               (P_PROT_TYPE                ),  // take the protection type and range globally 
                .PROT_RANGE              (P_PROT_RANGE               ),
                .PROT_WD                 (P_FLIT_PROT_WD             ),  // protect the whole data signal
                .PARITY_MODE             (P_PARITY_MODE              ),  // take the parity globally
                .PROT_CORRECT_EN         (`CX_RAS_CORRECTION_EN      ),  // take the ability of error correction globally 
                .TOTAL_WIDTH             (P_DOUT_WD                  ),  // the whole width
                .EXCLUDE_PROT_WIDTH      (0                          ),  // don't exclude any part of the datapath
                .RAS_DP_PROT_CHK_ID_BASE (0                          )   // Set ID to 0 
              ) u_rasdp_delay_rplh_crc (
                .clk                      (core_clk                                       ),
                .rst_n                    (core_rst_n                                     ),
                .en                       (data_valid                                     ),
                .din                      (s_crc_data_out                                 ),
                .din_prot                 ('0                                             ),
                .dout                     (rplh_crc_data_out[P_DOUT_WD-1:0]               ),
                .dout_prot                (rplh_crc_data_out[P_DOUT_WD_W_PROT-1:P_DOUT_WD]),
                .bypass                   ('0                                             ),
                .stall                    ('0                                             ),
                .valid_in                 ('0                                             ),
                .halt_in                  ('0                                             ),
                .ras_dp_err_inband_kbd_in ('0                                             ),
                .ras_dp_err_inj           ('0                                             ),
                .stallout                 (), // unused
                .halt_out                 (), // unused
                .valid_out                (), // unused
                .ras_dp_err_inband_kbd_out(), // unused
                .ras_dp_err_log           ()  // unused
              );

wire out_crc_data_invalid;
wire out_fec_data_invalid;
assign out_crc_data_invalid = data_valid & s_crc_data_invalid;
assign out_fec_data_invalid = data_valid & data_invalid;

delay_n

#(REGOUT_EN, 3) u_delay_rplh_crc_en (
    .clk    (core_clk                                     ),
    .rst_n  (core_rst_n                                   ),
    .clear  (1'b0                                         ),
    .din    ({data_valid,          out_crc_data_invalid,  out_fec_data_invalid}  ),
    .dout   ({rplh_crc_data_valid, rplh_crc_data_invalid, rplh_fec_data_invalid} )
);

// Instantiate the CRC Checkers 
rplh_crc_check
 #(
  .P_COEF       (P_COEF7)
) u_crc_check7 (
  // Inputs
  .data_in    (s_crc_data_out),
  .crc_in     (s_crc_in_7),
  // Outputs
  .crc_error  (s_crc_check7_error)
);
rplh_crc_check
 #(
  .P_COEF       (P_COEF6)
) u_crc_check6 (
  // Inputs
  .data_in    (s_crc_data_out),
  .crc_in     (s_crc_in_6),
  // Outputs
  .crc_error  (s_crc_check6_error)
);
rplh_crc_check
 #(
  .P_COEF       (P_COEF5)
) u_crc_check5 (
  // Inputs
  .data_in    (s_crc_data_out),
  .crc_in     (s_crc_in_5),
  // Outputs
  .crc_error  (s_crc_check5_error)
);
rplh_crc_check
 #(
  .P_COEF       (P_COEF4)
) u_crc_check4 (
  // Inputs
  .data_in    (s_crc_data_out),
  .crc_in     (s_crc_in_4),
  // Outputs
  .crc_error  (s_crc_check4_error)
);
rplh_crc_check
 #(
  .P_COEF       (P_COEF3)
) u_crc_check3 (
  // Inputs
  .data_in    (s_crc_data_out),
  .crc_in     (s_crc_in_3),
  // Outputs
  .crc_error  (s_crc_check3_error)
);
rplh_crc_check
 #(
  .P_COEF       (P_COEF2)
) u_crc_check2 (
  // Inputs
  .data_in    (s_crc_data_out),
  .crc_in     (s_crc_in_2),
  // Outputs
  .crc_error  (s_crc_check2_error)
);
rplh_crc_check
 #(
  .P_COEF       (P_COEF1)
) u_crc_check1 (
  // Inputs
  .data_in    (s_crc_data_out),
  .crc_in     (s_crc_in_1),
  // Outputs
  .crc_error  (s_crc_check1_error)
);
rplh_crc_check
 #(
  .P_COEF       (P_COEF0)
) u_crc_check0 (
  // Inputs
  .data_in    (s_crc_data_out),
  .crc_in     (s_crc_in_0),
  // Outputs
  .crc_error  (s_crc_check0_error)
);


endmodule
