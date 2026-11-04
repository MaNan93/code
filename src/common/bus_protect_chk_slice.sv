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


// --- Module Description:
// ----------------------------------------------------------------------------
// --- This module takes care of checking (and optionally correcting) the
// integrity of incoming data and ECC. It also takes care of logging errors and
// inject errors.
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

module bus_protect_chk_slice
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import DWC_pcie_ctl_pkg::ERR_INJ_FAILURE;
import DWC_pcie_ctl_pkg::ERR_INJ_SUCCESSFUL;
import DWC_pcie_ctl_pkg::UNCORRECTABLE;
import DWC_pcie_ctl_pkg::CORRECTABLE;
import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_WD;
#(
    parameter PROT_TYPE                = 0,   // 0=Ecc            1=Simple Parity              
    parameter PROT_WD                  = 16,  // chkout bus width                              
    parameter DATA_WD                  = 128, // data bus width                                
    parameter PARITY_MODE              = 0,   // Parity mode when PROT_TYPE == 1. 0-EVEN/1-ODD 
    parameter PROT_CORRECT_EN          = 1,   // Enable the capability of correction words     
    parameter RAS_ERROR_SYNDROME_INDEX = 8
    ,
    parameter ERR_INJ_INDEX_WIDTH  = 72
)   

                            (
    input  logic                           valid,
    input  logic [PROT_WD-1:0]             chkin,
    input  logic [DATA_WD-1:0]             datain,
    output logic [PROT_WD-1:0]             chkout,
    output logic [DATA_WD-1:0]             dataout,
    output logic [DATA_WD-1:0]             fixdata,
    input  logic                           err_inj_ongoing,
    input  logic                           err_inj_last,
    input  logic                           err_inj_double,
    input  logic [ERR_INJ_INDEX_WIDTH-1:0] err_inj_bit_index_0_oh,
    input  logic [ERR_INJ_INDEX_WIDTH-1:0] err_inj_bit_index_1_oh,
    output logic                           err_inj_failure,
    input  logic                           err_inj_extra_inst_in_range,
    `ifndef SYNTHESIS
    `ifdef SNPS_TB_INTERFACE
    input  logic                           error_inj_fault_en,
    `endif // SNPS_TB_INTERFACE                       
    `endif // SYNTHESIS                               
    output ras_dp_err_log_t                ras_dp_err_log
);

logic correct_n_wire;
assign correct_n_wire = PROT_CORRECT_EN? 1'b0 : 1'b1;

logic [DATA_WD-1:0] data_from_cleaner, data_to_checker, data_from_checker;
logic [PROT_WD-1:0] chk_from_cleaner,  chk_to_checker,  chk_from_checker;

bus_protect_chk_slice_cleaner
 #(
    .PROT_TYPE           (PROT_TYPE),
    .PARITY_MODE         (PARITY_MODE),
    .PROT_WD             (PROT_WD),
    .DATA_WD             (DATA_WD)
) bus_protect_chk_slice_cleaner (
    .valid               (valid),
    .chkin               (chkin),
    .datain              (datain),
    .chkout              (chk_from_cleaner),
    .dataout             (data_from_cleaner));

logic [DATA_WD-1:0] corrupted_data;
logic [PROT_WD-1:0] corrupted_chk;

bus_protect_chk_err_inj
 #(
    .PROT_TYPE              (PROT_TYPE),
    .PROT_WD                (PROT_WD),
    .DATA_WD                (DATA_WD),
    .ERR_INJ_INDEX_WIDTH    (ERR_INJ_INDEX_WIDTH)
) u_bus_protect_chk_err_inj (
    .err_inj_bit_index_0_oh (err_inj_bit_index_0_oh),
    .err_inj_bit_index_1_oh (err_inj_bit_index_1_oh),
    .chkin                  (chk_from_cleaner),
    .datain                 (data_from_cleaner),
    .chkout                 (corrupted_chk),
    .dataout                (corrupted_data)
    `ifndef SYNTHESIS
    `ifdef SNPS_TB_INTERFACE
    ,
    .error_inj_fault_en     (error_inj_fault_en)
    `endif // SNPS_TB_INTERFACE                       
    `endif // SYNTHESIS                               

);

assign data_to_checker = err_inj_ongoing? corrupted_data : data_from_cleaner;
assign chk_to_checker  = err_inj_ongoing? corrupted_chk  : chk_from_cleaner;

logic               err_detect;
logic               err_multpl;
logic [PROT_WD-1:0] syndrome;

generate
if (PROT_TYPE == 1) begin : g_checker_parity
    // calculate parity
    logic calculated_chk;
    if (PARITY_MODE) begin : g_odd_parity_prot
        assign calculated_chk = !(^ data_to_checker); //ODD parity
    end else begin : GEN_EVEN_PARITY_PROT
        assign calculated_chk =  (^ data_to_checker); //EVEN parity
    end

    // compare calculated to transported parity
    assign err_detect = (calculated_chk ^ chk_to_checker);
    assign err_multpl = err_detect;
    
    assign data_from_checker = data_to_checker;
    assign chk_from_checker  = chk_to_checker;
    
    assign fixdata = '0;
end else begin : g_checker_ecc
    if (DATA_WD <= 26) begin: g_ecc_data_wd_up_to_26
        DWC_pcie_ctl_bcm46_a
         #(
            .WIDTH(DATA_WD)
        ) u_ecc (
            .gen        (1'b0             ),
            .correct_n  (correct_n_wire   ),
            .datain     (data_to_checker  ),
            .chkin      (chk_to_checker   ),
            .err_detect (err_detect       ),
            .err_multpl (err_multpl       ),
            .dataout    (data_from_checker),
            .fixdata    (fixdata          ),
            .chkout     (chk_from_checker ),
            .syndout    (syndrome         )
        );
    end else if (DATA_WD <= 57) begin: g_ecc_data_wd_up_to_57
        DWC_pcie_ctl_bcm46_b
         #(
            .WIDTH(DATA_WD)
        ) u_ecc (
            .gen        (1'b0             ),
            .correct_n  (correct_n_wire   ),
            .datain     (data_to_checker  ),
            .chkin      (chk_to_checker   ),
            .err_detect (err_detect       ),
            .err_multpl (err_multpl       ),
            .dataout    (data_from_checker),
            .fixdata    (fixdata          ),
            .chkout     (chk_from_checker ),
            .syndout    (syndrome         )
        );
    end else if (DATA_WD <= 120) begin: g_ecc_data_wd_up_to_120
        DWC_pcie_ctl_bcm46_c
         #(
            .WIDTH(DATA_WD)
        ) u_ecc (
            .gen        (1'b0             ),
            .correct_n  (correct_n_wire   ),
            .datain     (data_to_checker  ),
            .chkin      (chk_to_checker   ),
            .err_detect (err_detect       ),
            .err_multpl (err_multpl       ),
            .dataout    (data_from_checker),
            .fixdata    (fixdata          ),
            .chkout     (chk_from_checker ),
            .syndout    (syndrome         ));
    end else if (DATA_WD <= 247) begin: g_ecc_data_wd_up_to_247
        DWC_pcie_ctl_bcm46_d
         #(
            .WIDTH(DATA_WD)
        ) u_ecc (
            .gen        (1'b0             ),
            .correct_n  (correct_n_wire   ),
            .datain     (data_to_checker  ),
            .chkin      (chk_to_checker   ),
            .err_detect (err_detect       ),
            .err_multpl (err_multpl       ),
            .dataout    (data_from_checker),
            .fixdata    (fixdata          ),
            .chkout     (chk_from_checker ),
            .syndout    (syndrome         )
        );
    end else begin: g_ecc_data_wd_up_to_502
        DWC_pcie_ctl_bcm46_e
         #(
            .WIDTH(DATA_WD)
        ) u_ecc (
            .gen        (1'b0             ),
            .correct_n  (correct_n_wire   ),
            .datain     (data_to_checker  ),
            .chkin      (chk_to_checker   ),
            .err_detect (err_detect       ),
            .err_multpl (err_multpl       ),
            .dataout    (data_from_checker),
            .fixdata    (fixdata          ),
            .chkout     (chk_from_checker ),
            .syndout    (syndrome         )
        );
    end
end
endgenerate

assign dataout = err_inj_ongoing? data_from_cleaner : data_from_checker;
assign chkout  = err_inj_ongoing? chk_from_cleaner  : chk_from_checker;

generate
if (PROT_TYPE == 0) begin : g_err_inj_fail_detect_ecc
    // error injection failure detector
    always_comb begin
        err_inj_failure = '0;
        if (err_inj_ongoing && err_inj_extra_inst_in_range) begin
            if (err_inj_double) begin
                if ((data_from_cleaner == data_from_checker) && (chk_from_cleaner == chk_from_checker)) begin
                    err_inj_failure = 1'b1;
                end
                if ((!err_detect) || (!err_multpl)) begin
                    err_inj_failure = 1'b1;
                end
            end else begin
                if ((data_from_cleaner == data_from_checker) && (chk_from_cleaner == chk_from_checker) && (PROT_CORRECT_EN == 0)) begin
                    err_inj_failure = 1'b1;
                end
                if ((!err_detect) || (err_multpl)) begin
                    err_inj_failure = 1'b1;
                end
            end
        end
    end
end else begin : g_err_inj_fail_detect_parity
    // error injection failure detector
    always_comb begin
        err_inj_failure = '0;
        if (err_inj_ongoing && err_inj_extra_inst_in_range) begin
            if ((data_from_cleaner == data_from_checker) && (chk_from_cleaner == chk_from_checker)) begin
                err_inj_failure = 1'b1;
            end
            if (!err_detect) begin
                err_inj_failure = 1'b1;
            end
        end
    end
end
endgenerate

// error logging
always_comb begin
    ras_dp_err_log.valid = err_detect;
    ras_dp_err_log.log   = '0;
    if (err_detect) begin
        if (err_multpl) begin
            ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] = UNCORRECTABLE;
        end else begin
            if (PROT_CORRECT_EN == 1) begin
                ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] = CORRECTABLE;
            end else begin
                ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] = UNCORRECTABLE;
            end
        end
        if (PROT_TYPE == 0) begin
            ras_dp_err_log.log[RAS_ERROR_SYNDROME_INDEX +: PROT_WD] = syndrome;
        end
    end
end

endmodule

// Revision: $Id: //dwh/pcie_iip/main/fairbanks/design/common/bus_protect_chk_slice.sv#3 $
