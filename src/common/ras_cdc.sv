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
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/ras_cdc.sv#4 $
// -------------------------------------------------------------------------
// ---
// ---
// ---
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

module ras_cdc
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::RAS_ERROR_FORMAT_INDEX;
import DWC_pcie_ctl_pkg::MAX_RAS_ERR_LOG_WORD_NUM;
import DWC_pcie_ctl_pkg::RAS_ERROR_LOG_WD;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
#(
    parameter F_SYNC_TYPE = 2,
    parameter R_SYNC_TYPE = 2
)
(
    // s side
    input  logic             clk_ch,
    input  logic             rst_ch_n,
    output ras_dp_err_inj_t  out_ras_dp_err_inj,
    output logic             out_ras_dp_wake_up_ch,
    input  ras_dp_err_log_t  in_ras_dp_err_log,
    
    // d side
    input  logic             clk_tr,
    input  logic             rst_tr_n,
    input  ras_dp_err_inj_t  in_ras_dp_err_inj,
    output logic             out_ras_dp_wake_up_tr,
    output ras_dp_err_log_t  out_ras_dp_err_log
);

logic                        send_s, empty_s, halt_in, done_s;
logic [3:0]                  unused_signal;

logic                        data_avail_d, err_format, output_sf_fifo_buffer_valid_out, halt_d;
logic [RAS_ERROR_LOG_WD-1:0] data_d;

ras_dp_err_log_t             input_fifo_buffer_ras_dp_err_log;
// ras_dp_err_log CDC
// input FIFO Buffer
ras_cdc_fifo

#(                                           
   .WD            (RAS_ERROR_LOG_WD),        
   .FIFO_DEPTH    (MAX_RAS_ERR_LOG_WORD_NUM) 
) u_input_fifo_buffer (                                            
   .clk       (clk_ch),                       
   .rst_n     (rst_ch_n),                     

   .in_ras_dp_err_log  (in_ras_dp_err_log),     
   .out_ras_dp_err_log (input_fifo_buffer_ras_dp_err_log),     

   .halt_in   (halt_in)                      
);                                           

assign send_s  = input_fifo_buffer_ras_dp_err_log.valid && (!empty_s);
assign halt_in = !done_s;

// CDC
DWC_pcie_ctl_bcm25
 
#(
    .WIDTH       (RAS_ERROR_LOG_WD),
    .PEND_MODE   (0),
    .ACK_DELAY   (1),
    .F_SYNC_TYPE (F_SYNC_TYPE),
    .R_SYNC_TYPE (R_SYNC_TYPE),
    .VERIF_EN    (1),
    .SEND_MODE   (0),
    .SVA_TYPE    (0),
    .RST_VAL     (0)
)
u_ras_dp_err_log_cdc
(
    .clk_s        (clk_ch),
    .rst_s_n      (rst_ch_n),
    .init_s_n     (1'b1),
    .send_s       (send_s),
    .data_s       (input_fifo_buffer_ras_dp_err_log.log),
    .empty_s      (empty_s),
    .full_s       (unused_signal[1]),
    .done_s       (done_s),

    .clk_d        (clk_tr),
    .rst_d_n      (rst_tr_n),
    .init_d_n     (1'b1),
    .data_avail_d (data_avail_d),
    .data_d       (data_d)
);

// output Store&Forward FIFO Buffer
pipe_w_hs
 
#(                                           
   .WD            (RAS_ERROR_LOG_WD),        
   .FORWARD_PIPE  (1),                       
   .BACKWARD_PIPE (1),                       
   .FIFO_DEPTH    (MAX_RAS_ERR_LOG_WORD_NUM) 
) u_output_sf_fifo_buffer (                                            
   .clk       (clk_tr),                       
   .rst_n     (rst_tr_n),                     

   .valid_in  (data_avail_d),     
   .d_in      (data_d),       
   .halt_out  (unused_signal[0]),             

   .valid_out (output_sf_fifo_buffer_valid_out),                      
   .d_out     (out_ras_dp_err_log.log),                      
   .halt_in   (halt_d)                      
);                                           


logic [$clog2(MAX_RAS_ERR_LOG_WORD_NUM)-1:0] fill_word_number, c_fill_word_number;
always_comb begin
    if (fill_word_number == 2'b00) begin
        c_fill_word_number = 2'b01;
    end else if (fill_word_number == 2'b01) begin
        if (err_format == 1'b1) begin
            c_fill_word_number = 2'b10;
        end else begin
            c_fill_word_number = 2'b00;
        end
    end else if (fill_word_number == 2'b10) begin
        c_fill_word_number = 2'b11;
    end else begin
        c_fill_word_number = 2'b00;
    end
end

always_ff@(posedge clk_tr or negedge rst_tr_n) begin
    if(!rst_tr_n)begin
        fill_word_number <= #TP 2'b00;
    end else begin
        if (data_avail_d) begin
            fill_word_number <= #TP c_fill_word_number;
        end
    end
end

always_ff@(posedge clk_tr or negedge rst_tr_n) begin
    if(!rst_tr_n)begin
        err_format <= #TP 2'b00;
    end else begin
        if (data_avail_d) begin
            if (fill_word_number == 2'b00) begin
                err_format <= #TP data_d[RAS_ERROR_FORMAT_INDEX];
            end
        end
    end
end

always_ff@(posedge clk_tr or negedge rst_tr_n) begin
    if(!rst_tr_n)begin
        halt_d <= #TP 1'b0;
    end else begin
        if (data_avail_d) begin
            if (fill_word_number == 2'b00) begin
                halt_d <= #TP 1'b1;
            end else begin
                if ((fill_word_number == 2'b01) && (!err_format)) begin
                    halt_d <= #TP 1'b0;
                end else if (fill_word_number == 2'b11) begin
                    halt_d <= #TP 1'b0;
                end
            end
        end
    end
end

assign out_ras_dp_err_log.valid = output_sf_fifo_buffer_valid_out && (!halt_d);

// ras_dp_err_inj CDC
// CDC
logic ras_dp_err_inj_ongoing_tr;
DWC_pcie_ctl_bcm25
 
#(
    .WIDTH       ($clog2(MAX_RAS_PROT_CHK_N)),
    .PEND_MODE   (1),
    .ACK_DELAY   (1),
    .F_SYNC_TYPE (F_SYNC_TYPE),
    .R_SYNC_TYPE (R_SYNC_TYPE),
    .VERIF_EN    (1),
    .SEND_MODE   (0),
    .SVA_TYPE    (0),
    .RST_VAL     (0)
)
u_ras_dp_err_inj_cdc
(
    .clk_s        (clk_tr),
    .rst_s_n      (rst_tr_n),
    .init_s_n     (1'b1),
    .send_s       (in_ras_dp_err_inj.valid),
    .data_s       (in_ras_dp_err_inj.ras_prot_chk_id),
    .empty_s      (ras_dp_err_inj_ongoing_tr),
    .full_s       (unused_signal[2]),
    .done_s       (unused_signal[3]),

    .clk_d        (clk_ch),
    .rst_d_n      (rst_ch_n),
    .init_d_n     (1'b1),
    .data_avail_d (out_ras_dp_err_inj.valid),
    .data_d       (out_ras_dp_err_inj.ras_prot_chk_id)
);

assign out_ras_dp_wake_up_ch = in_ras_dp_err_log.valid | send_s | out_ras_dp_err_inj.valid;
assign out_ras_dp_wake_up_tr = data_avail_d | output_sf_fifo_buffer_valid_out | ras_dp_err_inj_ongoing_tr | in_ras_dp_err_inj.valid;

endmodule

