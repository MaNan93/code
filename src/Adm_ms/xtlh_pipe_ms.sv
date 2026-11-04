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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xtlh_pipe_ms.sv#4 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module xtlh_pipe_ms
import DWC_pcie_core_pkg::xtlh_pkt_t;
import DWC_pcie_core_pkg::ADM_PRFX_HDR_DATA_NW;
import DWC_pcie_core_pkg::ADM_PRFX_HDR_DATA_PROT_WD;
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
    
    input  xtlh_pkt_t       [N-1:0] in_pkt,
    output logic            [N-1:0] out_halt,
    
    output xtlh_pkt_t       [N-1:0] out_pkt,
    input  logic            [N-1:0] in_halt
    ,
    output ras_dp_err_log_t [N-1:0] ras_dp_err_log
    ,
    input  ras_dp_err_inj_t         ras_dp_err_inj
);

xtlh_pkt_t [N-1:0] in_pkt_to_pipe;

localparam TOTAL_WIDTH = $bits(in_pkt_to_pipe[0]) - ADM_PRFX_HDR_DATA_PROT_WD - 1;

localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;

localparam PIPELINE_TYPE = 6; // 2 = delay_n_w_stalling, 6 = pipe_w_hs 

generate
    if ((BUS_PROTECT_GEN_EN == 1) || (BUS_PROTECT_CHK_EN == 1)) begin : g_dwen_clear
        always_comb begin
            for(int i = 0; i < N; i++)begin
                in_pkt_to_pipe[i] = in_pkt[i];
                // data DWs whose dwen is not set are driven to a constant value to avoid don't care data making a subsequent bus checker fail
                for(int dw = 0; dw < ADM_PRFX_HDR_DATA_NW; dw++)begin
                    in_pkt_to_pipe[i].data[dw] = (in_pkt_to_pipe[i].dwen[dw])? in_pkt_to_pipe[i].data[dw] : 32'h0;
                end
            end
        end
    end
endgenerate

localparam EXCLUDE_PROT_WIDTH = TOTAL_WIDTH - $bits(in_pkt_to_pipe[0].data);

logic      [N-1:0][TOTAL_WIDTH-1:0]  in_pkt_vector;
logic      [N-1:0][TOTAL_WIDTH-1:0]  out_pkt_vector;
logic      [$clog2(TOTAL_WIDTH)-1:0] IN_OFFSET;
logic      [$clog2(TOTAL_WIDTH)-1:0] OUT_OFFSET;

logic [N-1:0] valid_out;

always_comb begin
    for (int i = 0; i < N; i++) begin : g_ifs
        IN_OFFSET=0;
        // fill the vector to ras_dp_pipe with fields to be protected
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].data)]            = in_pkt_to_pipe[i].data;            IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].data);
        // fill the remaining part of vector to ras_dp_pipe with fields not to be protected
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].sot)]             = in_pkt_to_pipe[i].sot;             IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].sot);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].soh)]             = in_pkt_to_pipe[i].soh;             IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].soh);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].sod)]             = in_pkt_to_pipe[i].sod;             IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].sod);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].dv)]              = in_pkt_to_pipe[i].dv;              IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].dv);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].eot)]             = in_pkt_to_pipe[i].eot;             IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].eot);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].badeot)]          = in_pkt_to_pipe[i].badeot;          IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].badeot);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].pme_to_ack)]      = in_pkt_to_pipe[i].pme_to_ack;      IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].pme_to_ack);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].dwen)]            = in_pkt_to_pipe[i].dwen;            IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].dwen);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].seqnum)]          = in_pkt_to_pipe[i].seqnum;          IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].seqnum);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].ep)]              = in_pkt_to_pipe[i].ep;              IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].ep);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].dcrdt)]           = in_pkt_to_pipe[i].dcrdt;           IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].dcrdt);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].is_from_msg_gen)] = in_pkt_to_pipe[i].is_from_msg_gen; IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].is_from_msg_gen);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].is_from_lbc)]     = in_pkt_to_pipe[i].is_from_lbc;     IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].is_from_lbc);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].is_from_dma)]     = in_pkt_to_pipe[i].is_from_dma;     IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].is_from_dma);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].td)]              = in_pkt_to_pipe[i].td;              IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].td);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].ptm)]             = in_pkt_to_pipe[i].ptm;             IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].ptm);
        in_pkt_vector[i][IN_OFFSET+:$bits(in_pkt_to_pipe[0].vc)]              = in_pkt_to_pipe[i].vc;              IN_OFFSET = IN_OFFSET + $bits(in_pkt_to_pipe[0].vc);
    end
end

logic [N-1:0]                                ras_dp_err_inband_kbd_out;
logic [N-1:0][ADM_PRFX_HDR_DATA_PROT_WD-1:0] out_tlp_prot;           

generate
    for (genvar i = 0; i < N; i++)begin : g_pipe_rasdp
        if (PIPELINE_TYPE == 2) begin : g_delay_n_w_stalling
            logic [N-1:0] halt_out_unused;
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
                .PROT_WD                 (ADM_PRFX_HDR_DATA_PROT_WD),
                .PARITY_MODE             (PARITY_MODE),
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),
                .TOTAL_WIDTH             (TOTAL_WIDTH),
                .EXCLUDE_PROT_WIDTH      (EXCLUDE_PROT_WIDTH),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+i)
            ) u_ras_dp_pipe (
                .clk                           (clk                       ),
                .rst_n                         (rst_n                     ),
                .en                            (1'b1                      ),
                .bypass                        (1'b0                      ),
                .stall                         (in_halt[i]                ),
                .stallout                      (out_halt[i]               ),
                
                .valid_in                      (in_pkt_to_pipe[i].dv      ),
                .din                           (in_pkt_vector[i]          ),
                .din_prot                      (in_pkt_to_pipe[i].tlp_prot),
                .halt_out                      (halt_out_unused[i]        ),

                .valid_out                     (valid_out[i]              ),
                .dout                          (out_pkt_vector[i]         ),
                .dout_prot                     (out_tlp_prot[i]           ),
                .halt_in                       (1'b0                      )
                ,
                .ras_dp_err_inband_kbd_in      (in_pkt_to_pipe[i].ras_dp_err_inband_kbd),
                .ras_dp_err_inband_kbd_out     (ras_dp_err_inband_kbd_out[i]           ),
                .ras_dp_err_log                (ras_dp_err_log[i])
                ,
                .ras_dp_err_inj                (ras_dp_err_inj)
                );
        end else if (PIPELINE_TYPE == 6) begin : g_pipe_w_hs
            logic [N-1:0] stallout_unused;
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
                .PROT_WD                 (ADM_PRFX_HDR_DATA_PROT_WD),
                .PARITY_MODE             (PARITY_MODE),
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),
                .TOTAL_WIDTH             (TOTAL_WIDTH),
                .EXCLUDE_PROT_WIDTH      (EXCLUDE_PROT_WIDTH),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+i)
            ) u_ras_dp_pipe (
                .clk                       (clk                       ),
                .rst_n                     (rst_n                     ),
                .en                        (1'b1                      ),
                .bypass                    (1'b0                      ),
                .stall                     (1'b0                      ),
                .stallout                  (stallout_unused[i]        ),
                
                .valid_in                  (in_pkt_to_pipe[i].dv      ),
                .din                       (in_pkt_vector[i]          ),
                .din_prot                  (in_pkt_to_pipe[i].tlp_prot),
                .halt_out                  (out_halt[i]               ),
                
                .valid_out                 (valid_out[i]              ),
                .dout                      (out_pkt_vector[i]         ),
                .dout_prot                 (out_tlp_prot[i]           ),
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
        out_pkt[i].data                  = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].data)];                                          OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].data);
        // fill the remaining part with fields not to be protected
        out_pkt[i].sot                   = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].sot)] && valid_out[i];                           OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].sot);
        out_pkt[i].soh                   = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].soh)];                                           OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].soh);
        out_pkt[i].sod                   = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].sod)];                                           OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].sod);
        out_pkt[i].dv                    = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].dv)] && valid_out[i];                            OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].dv);
        out_pkt[i].eot                   = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].eot)] && valid_out[i];                           OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].eot);
        out_pkt[i].badeot                = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].badeot)] && valid_out[i];                        OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].badeot);
        out_pkt[i].pme_to_ack            = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].pme_to_ack)];                                    OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].pme_to_ack);
        out_pkt[i].dwen                  = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].dwen)] & {(ADM_PRFX_HDR_DATA_NW){valid_out[i]}}; OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].dwen);
        out_pkt[i].seqnum                = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].seqnum)];                                        OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].seqnum);
        out_pkt[i].ep                    = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].ep)];                                            OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].ep);
        out_pkt[i].dcrdt                 = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].dcrdt)];                                         OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].dcrdt);
        out_pkt[i].is_from_msg_gen       = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].is_from_msg_gen)];                               OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].is_from_msg_gen);
        out_pkt[i].is_from_lbc           = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].is_from_lbc)];                                   OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].is_from_lbc);
        out_pkt[i].is_from_dma           = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].is_from_dma)];                                   OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].is_from_dma);
        out_pkt[i].td                    = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].td)];                                            OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].td);
        out_pkt[i].ptm                   = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].ptm)];                                           OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].ptm);
        out_pkt[i].vc                    = out_pkt_vector[i][OUT_OFFSET+:$bits(out_pkt[0].vc)];                                            OUT_OFFSET = OUT_OFFSET + $bits(out_pkt[0].vc);
        out_pkt[i].ras_dp_err_inband_kbd = ras_dp_err_inband_kbd_out[i];
        out_pkt[i].tlp_prot              = out_tlp_prot[i];
    end
end

endmodule

