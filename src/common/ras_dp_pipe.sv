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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/ras_dp_pipe.sv#3 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

module ras_dp_pipe
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
#(
    parameter PIPELINE_TYPE           = 2,
    parameter RESETVAL                = 0,
    parameter N_STAGES                = 1,
    parameter CAN_STALL               = 1,
    parameter RESET_STALL             = 0,
    parameter BUS_PROTECT_GEN_EN      = 0,
    parameter BUS_PROTECT_CHK_EN      = 1,
    parameter PROT_TYPE               = 1,
    parameter PROT_RANGE              = 64,
    parameter PROT_WD                 = 8,
    parameter PARITY_MODE             = 1,
    parameter PROT_CORRECT_EN         = 1,
    parameter TOTAL_WIDTH             = 64,
    parameter EXCLUDE_PROT_WIDTH      = 0,
    parameter RAS_DP_PROT_CHK_ID_BASE = 0,
    parameter ADDR_LOG_EN             = 0,
    parameter ADDR_ECC_PROT_EN        = 0,
    parameter ADDR_INDEX              = 0,
    parameter ADDR_WD                 = 18,
    parameter PIPE_RAS_DP_ERR_LOG     = 0
)

                  (
    input  logic                   clk,
    input  logic                   rst_n,

    input  logic [TOTAL_WIDTH-1:0] din,
    input  logic [PROT_WD-1:0]     din_prot,

    output logic [TOTAL_WIDTH-1:0] dout,
    output logic [PROT_WD-1:0]     dout_prot,
    
    input  logic                   en,
    input  logic                   bypass,
    input  logic                   stall,
    output logic                   stallout,
    
    input  logic                   valid_in,
    output logic                   halt_out,
    
    output logic                   valid_out,
    input  logic                   halt_in,
    input  logic                   ras_dp_err_inband_kbd_in,
    output logic                   ras_dp_err_inband_kbd_out,
    output ras_dp_err_log_t        ras_dp_err_log
    ,
    input  ras_dp_err_inj_t        ras_dp_err_inj
);

logic [PROT_WD-1                       :0] chk_to_pipe;
logic [TOTAL_WIDTH-EXCLUDE_PROT_WIDTH-1:0] protected_data_to_pipe;
logic [PROT_WD-1                       :0] chk_from_pipe;
logic [TOTAL_WIDTH-EXCLUDE_PROT_WIDTH-1:0] protected_data_from_pipe;

// Place BUS PROTECTION GENERATOR if required
generate
    if (BUS_PROTECT_GEN_EN == 1) begin : g_bus_protect_gen
        bus_protect_gen_wo_err_inj
         #(
            .PROT_TYPE         (PROT_TYPE),                      // 0=Ecc            1=Simple Parity
            .PROT_RANGE        (PROT_RANGE),                     // Number of bits to calculate parity or ECC on
            .PROT_WD           (PROT_WD),                        // chkout bus width
            .DATA_WD           (TOTAL_WIDTH-EXCLUDE_PROT_WIDTH), // data bus width
            .PARITY_MODE       (PARITY_MODE),                    // Parity mode when PROT_TYPE == 1. 0-EVEN/1-ODD
            .ADDR_ECC_PROT_EN  (ADDR_ECC_PROT_EN),
            .ADDR_INDEX        (ADDR_INDEX),
            .ADDR_WD           (ADDR_WD)   
        ) u_bus_protect_gen_wo_err_inj (
            .datain            (din[TOTAL_WIDTH-EXCLUDE_PROT_WIDTH-1:0]),
            .chkout            (chk_to_pipe),
            .dataout           (protected_data_to_pipe)
        );
    end else begin : bus_protect_gen_no_gen
        assign chk_to_pipe = din_prot;
        assign protected_data_to_pipe = din[TOTAL_WIDTH-EXCLUDE_PROT_WIDTH-1:0];
    end
endgenerate

logic [TOTAL_WIDTH+PROT_WD-1:0] data_to_pipe;
logic [TOTAL_WIDTH+PROT_WD-1:0] data_from_pipe;
logic                           ras_dp_err_inband_kbd_from_pipe;
generate
    if (EXCLUDE_PROT_WIDTH == 0) begin
        assign data_to_pipe   = {                                                      chk_to_pipe, protected_data_to_pipe  };
        assign {                                                    chk_from_pipe, protected_data_from_pipe} = data_from_pipe;
    end else begin
        assign data_to_pipe   = { din[TOTAL_WIDTH-1:TOTAL_WIDTH-EXCLUDE_PROT_WIDTH],   chk_to_pipe, protected_data_to_pipe  };
        assign {dout[TOTAL_WIDTH-1:TOTAL_WIDTH-EXCLUDE_PROT_WIDTH], chk_from_pipe, protected_data_from_pipe} = data_from_pipe;
    end
endgenerate

// Place the required pipeline module
generate
    if (PIPELINE_TYPE == 0) begin : delay_n_gen
        // PIPELINE_TYPE == 0 => delay_n is placed
        delay_n
         #(
            .N(N_STAGES),
            .WD(TOTAL_WIDTH+PROT_WD+1+1),
            .RESETVAL(RESETVAL)
        ) u_delay_n (
            .clk     (clk                                                          ),
            .rst_n   (rst_n                                                        ),
            .clear   (1'b0                                                         ),
            .din     ({ras_dp_err_inband_kbd_in,        valid_in,  data_to_pipe  } ),
            .dout    ({ras_dp_err_inband_kbd_from_pipe, valid_out, data_from_pipe}));
        assign stallout = 1'b0;
        assign halt_out = 1'b0;
    end else if (PIPELINE_TYPE == 1) begin : delay_1_w_stalling_gen
        // PIPELINE_TYPE == 1 => delay_1_w_stalling is placed
        delay_1_w_stalling
         #(
            .DELAY_EN(1),
            .WD(TOTAL_WIDTH+PROT_WD+1+1),
            .CAN_STALL(CAN_STALL),
            .RESETVAL(RESETVAL),
            .RESET_STALL(RESET_STALL)
        ) u_delay_1_w_stalling (
            .clk     (clk                                                          ),
            .rst_n   (rst_n                                                        ),
            .clear   (1'b0                                                         ),
            .stall   (stall                                                        ),
            .din     ({ras_dp_err_inband_kbd_in,        valid_in,  data_to_pipe  } ),
            .stallout(stallout                                                     ),
            .dout    ({ras_dp_err_inband_kbd_from_pipe, valid_out, data_from_pipe}));
        assign halt_out = 1'b0;
    end else if (PIPELINE_TYPE == 2) begin : delay_n_w_stalling_gen
        // PIPELINE_TYPE == 2 => delay_n_w_stalling is placed
        delay_n_w_stalling
         #(
            .N(N_STAGES),
            .WD(TOTAL_WIDTH+PROT_WD+1+1),
            .CAN_STALL(CAN_STALL),
            .RESETVAL(RESETVAL)
        ) u_delay_n_w_stalling (
            .clk     (clk                                                          ),
            .rst_n   (rst_n                                                        ),
            .stall   (stall                                                        ),
            .clear   (1'b0                                                         ),
            .din     ({ras_dp_err_inband_kbd_in,        valid_in,  data_to_pipe }  ),
            .stallout(stallout                                                     ),
            .dout    ({ras_dp_err_inband_kbd_from_pipe, valid_out, data_from_pipe}));
        assign halt_out = 1'b0;
    end else if (PIPELINE_TYPE == 3) begin : delay_n_w_enable_gen
        // PIPELINE_TYPE == 3 => delay_n_w_enable is placed
        delay_n_w_enable
         #(
            .N(N_STAGES),
            .WD(TOTAL_WIDTH+PROT_WD+1+1),
            .RESETVAL(RESETVAL)
        ) u_delay_n_w_enable (
            .clk     (clk                                                          ),
            .rst_n   (rst_n                                                        ),
            .clear   (1'b0                                                         ),
            .en      (en                                                           ),
            .din     ({ras_dp_err_inband_kbd_in,        valid_in,  data_to_pipe }  ),
            .dout    ({ras_dp_err_inband_kbd_from_pipe, valid_out, data_from_pipe}));
        assign stallout = 1'b0;
        assign halt_out = 1'b0;
    end else if (PIPELINE_TYPE == 4) begin : delay_n_w_enable_autoreset_gen
        // PIPELINE_TYPE == 4 => delay_n_w_enable_autoreset is placed
        delay_n_w_enable_autoreset
         #(
            .N(N_STAGES),
            .WD(TOTAL_WIDTH+PROT_WD+1+1),
            .RESETVAL(RESETVAL)
        ) u_delay_n_w_enable_autoreset (
            .clk     (clk                                                          ),
            .rst_n   (rst_n                                                        ),
            .clear   (1'b0                                                         ),
            .en      (en                                                           ),
            .din     ({ras_dp_err_inband_kbd_in,        valid_in,  data_to_pipe  } ),
            .dout    ({ras_dp_err_inband_kbd_from_pipe, valid_out, data_from_pipe}));
        assign stallout = 1'b0;
        assign halt_out = 1'b0;
    end else if (PIPELINE_TYPE == 5) begin : delay_n_w_stalling_bp_gen
        // PIPELINE_TYPE == 5 => delay_n_w_stalling_bp is placed
        delay_n_w_stalling_bp #(
            .N(N_STAGES),
            .WD(TOTAL_WIDTH+PROT_WD+1+1),
            .CAN_STALL(CAN_STALL),
            .RESETVAL(RESETVAL)
        ) u_delay_n_w_stalling_bp (
            .clk     (clk                                                          ),
            .rst_n   (rst_n                                                        ),
            .clear   (1'b0                                                         ),
            .stall   (stall                                                        ),
            .bypass  (bypass                                                       ),
            .din     ({ras_dp_err_inband_kbd_in,        valid_in,  data_to_pipe  } ),
            .stallout(stallout                                                     ),
            .dout    ({ras_dp_err_inband_kbd_from_pipe, valid_out, data_from_pipe}));
        assign halt_out = 1'b0;
    end else if (PIPELINE_TYPE == 6) begin : pipe_w_hs_gen
        // PIPELINE_TYPE == 6 => pipe_w_hs is placed
        pipe_w_hs
         #(
            .WD            (TOTAL_WIDTH+PROT_WD+1),
            .FORWARD_PIPE  (N_STAGES),
            .BACKWARD_PIPE (CAN_STALL)
        ) u_pipe_w_hs (
            .clk       (clk                                               ),
            .rst_n     (rst_n                                             ),
            .valid_in  (valid_in                                          ),
            .halt_out  (halt_out                                          ),
            .d_in      ({ras_dp_err_inband_kbd_in,        data_to_pipe  } ),
            .valid_out (valid_out                                         ),
            .halt_in   (halt_in                                           ),
            .d_out     ({ras_dp_err_inband_kbd_from_pipe, data_from_pipe}));
        assign stallout = 1'b0;
    end
endgenerate

// Place BUS PROTECTION CHECKER if required
generate
    if (BUS_PROTECT_CHK_EN == 1) begin : g_bus_protect_chk
        logic ras_dp_err_inband_kbd_from_chk;

        bus_protect_chk_w_err_inj
         #(
            .PROT_TYPE                 (PROT_TYPE),                      // 0=Ecc            1=Simple Parity
            .PROT_RANGE                (PROT_RANGE),                     // Number of bits to calculate parity or ECC on
            .PROT_WD                   (PROT_WD),                        // chkout bus width
            .DATA_WD                   (TOTAL_WIDTH-EXCLUDE_PROT_WIDTH), // data bus width
            .PROT_CORRECT_EN           (PROT_CORRECT_EN),                // Enable the capability of correction words
            .PARITY_MODE               (PARITY_MODE),                    // Parity mode when PROT_TYPE == 1. 0-EVEN/1-ODD
            .RAS_PROT_CHK_ID           (RAS_DP_PROT_CHK_ID_BASE),
            .ADDR_ECC_PROT_EN          (ADDR_ECC_PROT_EN),
            .ADDR_LOG_EN               (ADDR_LOG_EN),
            .ADDR_INDEX                (ADDR_INDEX),
            .ADDR_WD                   (ADDR_WD),
            .PIPE_RAS_DP_ERR_LOG       (PIPE_RAS_DP_ERR_LOG)
        ) u_bus_protect_chk_w_err_inj (
            .valid                     (valid_out),
            .chkin                     (chk_from_pipe),
            .datain                    (protected_data_from_pipe),
            .dataout                   (dout[TOTAL_WIDTH-EXCLUDE_PROT_WIDTH-1:0]),
            .chkout                    (dout_prot),
            .ras_dp_err_inband_kbd_out (ras_dp_err_inband_kbd_from_chk),
            .ras_dp_err_log            (ras_dp_err_log)
            ,
            .clk                       (clk),
            .rst_n                     (rst_n),
            .ras_dp_err_inj            (ras_dp_err_inj)
            );
        
        assign ras_dp_err_inband_kbd_out = ras_dp_err_inband_kbd_from_pipe | ras_dp_err_inband_kbd_from_chk;
    end else begin : bus_protect_chk_no_gen
        assign dout_prot                                = chk_from_pipe;
        assign dout[TOTAL_WIDTH-EXCLUDE_PROT_WIDTH-1:0] = protected_data_from_pipe;
        assign ras_dp_err_inband_kbd_out                = ras_dp_err_inband_kbd_from_pipe;
        assign ras_dp_err_log                           = '0;
    end
endgenerate

endmodule

