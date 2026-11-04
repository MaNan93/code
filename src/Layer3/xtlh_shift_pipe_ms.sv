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
// ---    $DateTime: 2022/05/05 01:39:57 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_shift_pipe_ms.sv#1 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"

module xtlh_shift_pipe_ms
import xtlh_ms_pkg::flit_shift_struct;
import cx_pl_pkg::replay_cmd_t;
import cx_pl_pkg::REPLAY_00;
import cx_pl_pkg::ACK;
import cx_pl_pkg::NAK_10;
import cx_pl_pkg::NAK_11;
import cx_pl_pkg::P_DW;
import xtlh_ms_pkg::P_SHIFT_NW;
import cx_pl_pkg::DATA_PAR_WD;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
#(
    parameter N                       = 2,
    parameter PIPE                    = 1,
    parameter CAN_STALL               = 1
    ,
    // Bus protection generator inclusion
    parameter BUS_PROTECT_GEN_EN      = 1,
    // Bus protection checker inclusion
    parameter BUS_PROTECT_CHK_EN      = 1,
    parameter RAS_DP_PROT_CHK_ID_BASE = 0
)

                         (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    en,
    
    input  flit_shift_struct   [N-1:0] in_pkt,
    output logic               [N-1:0] out_halt,
    
    output flit_shift_struct   [N-1:0] out_pkt,
    input  logic               [N-1:0] in_halt
    ,
    output ras_dp_err_log_t    [N-1:0] ras_dp_err_log
    ,
    input  ras_dp_err_inj_t         ras_dp_err_inj
);

flit_shift_struct [N-1:0] in_pkt_to_pipe;

localparam TOTAL_WIDTH = $bits(in_pkt_to_pipe[0]) - DATA_PAR_WD - 1;

localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;

localparam PIPELINE_TYPE = 3; // 3 = delay_n_w_enable, 6 = pipe_w_hs 

generate
    if ((BUS_PROTECT_GEN_EN == 1) || (BUS_PROTECT_CHK_EN == 1)) begin : g_dwen_clear
        always_comb begin
            for(int i = 0; i < N; i++)begin
                in_pkt_to_pipe[i] = in_pkt[i];
            end
        end
    end
endgenerate

localparam EXCLUDE_PROT_WIDTH = TOTAL_WIDTH - $bits(in_pkt_to_pipe[0].data)+ (32 *P_SHIFT_NW)-P_DW;

logic      [N-1:0][TOTAL_WIDTH-1:0]  in_pkt_vector;
logic      [N-1:0][TOTAL_WIDTH-1:0]  out_pkt_vector;
logic      [$clog2(TOTAL_WIDTH)-1:0] IN_OFFSET;
logic      [$clog2(TOTAL_WIDTH)-1:0] OUT_OFFSET;

logic [N-1:0] valid_out;
logic [N-1:0] valid_in;

always_comb begin
    for (int i = 0; i < N; i++) begin : g_ifs
        IN_OFFSET=0;
        // fill the vector to ras_dp_pipe with fields to be protected
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].data)]            = in_pkt_to_pipe[i].data;            IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].data);
        // fill the remaining part of vector to ras_dp_pipe with fields not to be protected
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].data_valid)]      = in_pkt_to_pipe[i].data_valid;      IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].data_valid);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].sot)]             = in_pkt_to_pipe[i].sot;             IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].sot);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].eot)]             = in_pkt_to_pipe[i].eot;             IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].eot);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].flit_marker)]          = in_pkt_to_pipe[i].flit_marker;          IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].flit_marker);
    end
end

logic [N-1:0]                                ras_dp_err_inband_kbd_out;
logic [N-1:0][DATA_PAR_WD-1:0]               out_flit_prot;           
logic [N-1:0]                                stallout_unused;
generate
    for (genvar i = 0; i < N; i++)begin : g_pipe_rasdp
        assign valid_in[i] = (|in_pkt_to_pipe[i].data_valid);
        if (PIPELINE_TYPE == 3) begin : g_delay_n_w_enable
        ras_dp_pipe
         #(
            .PIPELINE_TYPE           (PIPELINE_TYPE),
            .RESETVAL                (0),
            .N_STAGES                (PIPE),
            .CAN_STALL               (CAN_STALL),
            .RESET_STALL             (0),
            .BUS_PROTECT_GEN_EN      (BUS_PROTECT_GEN_EN),
            .BUS_PROTECT_CHK_EN      (BUS_PROTECT_CHK_EN),
            .PROT_TYPE               (PROT_TYPE),
            .PROT_RANGE              (PROT_RANGE),
            .PROT_WD                 (DATA_PAR_WD),
            .PARITY_MODE             (PARITY_MODE),
            .PROT_CORRECT_EN         (PROT_CORRECT_EN),
            .TOTAL_WIDTH             (TOTAL_WIDTH),
            .EXCLUDE_PROT_WIDTH      (EXCLUDE_PROT_WIDTH),
            .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+i)
        ) u_ras_dp_pipe (
            .clk                           (clk                       ),
            .rst_n                         (rst_n                     ),
            .en                            (en                        ),
            .bypass                        (1'b0                      ),
            .stall                         (1'b0                      ),
            .stallout                      (stallout_unused[i]        ),

            .valid_in                      (valid_in[i]               ),
            .din                           (in_pkt_vector[i]          ),
            .din_prot                      (in_pkt_to_pipe[i].flit_prot),
            .halt_out                      (out_halt[i]               ),

            .valid_out                     (valid_out[i]              ),
            .dout                          (out_pkt_vector[i]         ),
            .dout_prot                     (out_flit_prot[i]          ),
            .halt_in                       (in_halt[i]                )
            ,
            .ras_dp_err_inband_kbd_in      (in_pkt_to_pipe[i].ras_dp_err_inband_kbd),
            .ras_dp_err_inband_kbd_out     (ras_dp_err_inband_kbd_out[i]           ),
            .ras_dp_err_log                (ras_dp_err_log[i])
            ,
            .ras_dp_err_inj                (ras_dp_err_inj)
            );
        end else if (PIPELINE_TYPE == 6) begin : g_pipe_w_hs
            ras_dp_pipe
             #(
                .PIPELINE_TYPE           (PIPELINE_TYPE),
                .RESETVAL                (0),
                .N_STAGES                (PIPE),
                .CAN_STALL               (CAN_STALL),
                .RESET_STALL             (0),
                .BUS_PROTECT_GEN_EN      (BUS_PROTECT_GEN_EN),
                .BUS_PROTECT_CHK_EN      (BUS_PROTECT_CHK_EN),
                .PROT_TYPE               (PROT_TYPE),
                .PROT_RANGE              (PROT_RANGE),
                .PROT_WD                 (DATA_PAR_WD),
                .PARITY_MODE             (PARITY_MODE),
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),
                .TOTAL_WIDTH             (TOTAL_WIDTH),
                .EXCLUDE_PROT_WIDTH      (EXCLUDE_PROT_WIDTH),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+i)
            ) u_ras_dp_pipe (
                .clk                       (clk                       ),
                .rst_n                     (rst_n                     ),
                .en                        (en                        ),
                .bypass                    (1'b0                      ),
                .stall                     (1'b0                      ),
                .stallout                  (stallout_unused[i]        ),
                
                .valid_in                  (valid_in[i]               ),
                .din                       (in_pkt_vector[i]          ),
                .din_prot                  (in_pkt_to_pipe[i].flit_prot),
                .halt_out                  (out_halt[i]               ),
                
                .valid_out                 (valid_out[i]              ),
                .dout                      (out_pkt_vector[i]         ),
                .dout_prot                 (out_flit_prot[i]          ),
                .halt_in                   (in_halt[i]                )
                ,
                .ras_dp_err_inband_kbd_in  (in_pkt_to_pipe[i].ras_dp_err_inband_kbd),
                .ras_dp_err_inband_kbd_out (ras_dp_err_inband_kbd_out[i]           ),
                .ras_dp_err_log            (ras_dp_err_log[i])
                ,
                .ras_dp_err_inj            (ras_dp_err_inj)
                );
        end
    end
endgenerate

always_comb begin
    for (int i = 0; i < N; i++)begin : g_ifs
        OUT_OFFSET=0;
        // fill from the ras_dp_pipe vector with fields to be protected
        out_pkt[i].data            = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].data)];                OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].data);
        // fill the remaining part with fields not to be protected
        out_pkt[i].data_valid      = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].data_valid)]  & {(P_SHIFT_NW){valid_out[i]}} ;                OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].data_valid);
        out_pkt[i].sot             = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].sot)]  & {(P_SHIFT_NW){valid_out[i]}} ;                OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].sot);
        out_pkt[i].eot             = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].eot)] ;                OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].eot);
        out_pkt[i].flit_marker     = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].flit_marker)];          OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].flit_marker);
          out_pkt[i].ras_dp_err_inband_kbd = ras_dp_err_inband_kbd_out[i];
          out_pkt[i].flit_prot              = out_flit_prot[i];
    end
end

endmodule

