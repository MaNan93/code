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


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

module bus_protect_chk_w_err_inj
import DWC_pcie_ctl_pkg::TP;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::RAS_ERROR_CHK_ID_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_CHK_ID_WD;
import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_WD;
import DWC_pcie_ctl_pkg::RAS_ERROR_FORMAT_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_FORMAT_WD;
import DWC_pcie_ctl_pkg::RAS_RAM_ADDR_LSB_INDEX;
import DWC_pcie_ctl_pkg::RAS_RAM_ADDR_LSB_WD;
import DWC_pcie_ctl_pkg::RAS_RAM_ADDR_MSB_INDEX;
import DWC_pcie_ctl_pkg::RAS_RAM_ADDR_MSB_WD;
import DWC_pcie_ctl_pkg::CORRECTABLE;
import DWC_pcie_ctl_pkg::UNCORRECTABLE;
import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
import DWC_pcie_ctl_pkg::MAX_RAS_ERR_LOG_WORD_NUM;
import DWC_pcie_ctl_pkg::RAS_ERROR_LOG_WD;
import DWC_pcie_ctl_pkg::MAX_SUPPORTED_WD;
import DWC_pcie_ctl_pkg::RAS_ERROR_SLICE_ID_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_PROT_RANGE_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_PROT_RANGE_WD;
import DWC_pcie_ctl_pkg::calc_ecc_wd;
import DWC_pcie_ctl_pkg::f_verify_ecc_wd;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import DWC_pcie_ctl_pkg::ERR_INJ_SUCCESSFUL;
import DWC_pcie_ctl_pkg::ERR_INJ_FAILURE;
#(
    parameter PROT_TYPE           = 0,   // 0=Ecc            1=Simple Parity
    parameter PROT_RANGE          = 64,  // Number of bits to calculate parity or ECC on
    parameter PROT_WD             = 16,  // chkout bus width
    parameter DATA_WD             = 128, // data bus width
    parameter PROT_CORRECT_EN     = 1,   // Enable the capability of correction words
    parameter PARITY_MODE         = 0,   // Parity mode when PROT_TYPE == 1. 0-EVEN/1-ODD
    parameter RAS_PROT_CHK_ID     = 0,
    parameter ADDR_LOG_EN         = 0,
    parameter ADDR_ECC_PROT_EN    = 0,
    parameter ADDR_INDEX          = 0,
    parameter ADDR_WD             = 0,
    parameter PIPE_RAS_DP_ERR_LOG = 0
)   

                                (
    input  logic                                  clk,
    input  logic                                  rst_n,
    input  logic                                  valid,
    input  logic            [PROT_WD-1:0]         chkin,
    input  logic            [DATA_WD-1:0]         datain,
    output logic            [DATA_WD-1:0]         dataout,
    output logic            [PROT_WD-1:0]         chkout,
    output logic                                  ras_dp_err_inband_kbd_out,
    output ras_dp_err_log_t                       ras_dp_err_log
    ,
    input  ras_dp_err_inj_t                       ras_dp_err_inj
);

// ----------------------------------------------------------------------------
// --- Local Parameters
// ----------------------------------------------------------------------------
// determine the number of bits protected by the extra instance
localparam EXTRA_BITS      = (DATA_WD - (ADDR_ECC_PROT_EN? ADDR_WD : 0)) % PROT_RANGE;
localparam EXTRA_PROT_INST = | EXTRA_BITS;

// get the number of  protection instances / parity bits 
localparam NUM_PROT_INST   = (DATA_WD - (ADDR_ECC_PROT_EN? ADDR_WD : 0)) / PROT_RANGE;

localparam ECC_CHK_WD       = calc_ecc_wd(PROT_RANGE+((ADDR_ECC_PROT_EN == 1)? ADDR_WD : 0));
localparam EXTRA_ECC_CHK_WD = calc_ecc_wd(EXTRA_BITS+((ADDR_ECC_PROT_EN == 1)? ADDR_WD : 0));

// RAS_ERROR_PROT_RANGE gives the width of the syndrome and slice id, that is:
// 00 => parity, no syndrome, slice id width arbitrarily set to MAX_SUPPORTED_WD/PROT_RANGE bits
// 01 => ecc32,  7-bits
// 10 => ecc64,  8-bits
// 11 => ecc128, 9-bits
localparam RAS_ERROR_SLICE_ID_WD    = ((NUM_PROT_INST+EXTRA_PROT_INST) == 1)? 1 : $clog2(NUM_PROT_INST+EXTRA_PROT_INST);
localparam RAS_ERROR_SYNDROME_INDEX = RAS_ERROR_SLICE_ID_INDEX + $clog2(MAX_SUPPORTED_WD/PROT_RANGE);
localparam RAS_ERROR_SYNDROME_WD    = ECC_CHK_WD;

ras_dp_err_log_t [NUM_PROT_INST+EXTRA_PROT_INST-1:0] ras_dp_err_log_array;
ras_dp_err_log_t                                     c_ras_dp_err_log;

localparam ERR_INJ_INDEX_WIDTH       = PROT_RANGE + (ADDR_ECC_PROT_EN? ADDR_WD : 0) + (PROT_TYPE? 1 : calc_ecc_wd(PROT_RANGE + (ADDR_ECC_PROT_EN? ADDR_WD : 0)));
localparam ERR_INJ_INDEX_WIDTH_EXTRA = EXTRA_BITS + (ADDR_ECC_PROT_EN? ADDR_WD : 0) + (PROT_TYPE? 1 : calc_ecc_wd(EXTRA_BITS + (ADDR_ECC_PROT_EN? ADDR_WD : 0)));
localparam ECC_WD                    = calc_ecc_wd(PROT_RANGE + (ADDR_ECC_PROT_EN? ADDR_WD : 0));
logic                                           err_inj_ongoing;
logic                                           err_inj_last;
logic                                           err_inj_double;
logic [ERR_INJ_INDEX_WIDTH-1:0]                 err_inj_bit_index_0_oh;
logic [ERR_INJ_INDEX_WIDTH-1:0]                 err_inj_bit_index_1_oh;
logic [NUM_PROT_INST+EXTRA_PROT_INST-1:0]       err_inj_failure_array;
logic                                           err_inj_failure;
logic                                           err_inj_extra_inst_in_range;

localparam FIXDATA_WD = (NUM_PROT_INST*(PROT_RANGE+(ADDR_ECC_PROT_EN? ADDR_WD : 0))) + EXTRA_BITS+(ADDR_ECC_PROT_EN? ADDR_WD : 0);
logic [FIXDATA_WD-1:0] fixdata;

assign err_inj_failure = |err_inj_failure_array;

bus_protect_chk_err_inj_ctrl
 #(
    .PROT_TYPE                 (PROT_TYPE),
    .RAS_PROT_CHK_ID           (RAS_PROT_CHK_ID),
    .ERR_INJ_INDEX_WIDTH       (ERR_INJ_INDEX_WIDTH),
    .ERR_INJ_INDEX_WIDTH_EXTRA (ERR_INJ_INDEX_WIDTH_EXTRA)
) u_bus_protect_chk_err_inj_ctrl (
    .clk                         (clk),
    .rst_n                       (rst_n),
    .ras_dp_err_inj              (ras_dp_err_inj),
    .err_inj_ongoing             (err_inj_ongoing),
    .err_inj_last                (err_inj_last),
    .err_inj_failure             (err_inj_failure),
    .err_inj_double              (err_inj_double),
    .err_inj_bit_index_0_oh      (err_inj_bit_index_0_oh),
    .err_inj_bit_index_1_oh      (err_inj_bit_index_1_oh),
    .err_inj_extra_inst_in_range (err_inj_extra_inst_in_range)
);

`ifdef SNPS_RAS_REPORT
initial
    begin
        $display("RAS DP Checker Report Generation: %m,%d,%d,%d", RAS_PROT_CHK_ID, ADDR_ECC_PROT_EN, ADDR_LOG_EN);
    end
`endif // SNPS_RAS_REPORT

logic [PROT_WD-1:0] i_chkin;
`ifndef SYNTHESIS
//VCS coverage off
`ifdef SNPS_TB_INTERFACE
logic [PROT_WD-1:0] prot_fault_inj_mask;
logic               error_inj_fault_en;

// Create interface instance for the testbench and insert into the config_db
DwDutRasDpIf u_DwDutRasDpIf(.clk(clk), .rst_n(rst_n));
string intf_id = $sformatf("DwDutRasDpIf_%0d", RAS_PROT_CHK_ID);
initial uvm_pkg::uvm_config_db #(virtual DwDutRasDpIf)::set(uvm_pkg::uvm_root::get(),{"*"},intf_id,u_DwDutRasDpIf);

logic mask_fault_inj;
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        mask_fault_inj <= #TP 1'b0;
    end else begin
        if (u_DwDutRasDpIf.unc_fault_inj_cmd[1]) begin
            if (valid && (!err_inj_ongoing)) begin
                mask_fault_inj <= #TP 1'b1;
            end
        end else if (u_DwDutRasDpIf.unc_fault_inj_cmd[0]) begin
            mask_fault_inj <= #TP 1'b1;
        end else begin
            mask_fault_inj <= #TP 1'b0;
        end
    end
end

always_comb begin
    u_DwDutRasDpIf.fault_inj_done = 1'b0;
    prot_fault_inj_mask           = '0;
    error_inj_fault_en            = 1'b0;
    if (u_DwDutRasDpIf.unc_fault_inj_cmd[1]) begin
        if (valid && (!mask_fault_inj) && (!err_inj_ongoing)) begin
            u_DwDutRasDpIf.fault_inj_done = 1'b1;
            prot_fault_inj_mask           = u_DwDutRasDpIf.prot_fault_inj_mask_rand[PROT_WD-1:0];
        end
    end else if (u_DwDutRasDpIf.unc_fault_inj_cmd[0]) begin
        if ((!mask_fault_inj) && err_inj_ongoing) begin
            error_inj_fault_en            = 1'b1;
            u_DwDutRasDpIf.fault_inj_done = 1'b1;
        end
    end
end

generate
    if (ADDR_LOG_EN == 1) begin : g_log_addr_gen
        assign u_DwDutRasDpIf.logAddr = {{(32-ADDR_WD){1'b0}}, datain[ADDR_INDEX +: ADDR_WD]};
    end else begin : g_no_log_addr_gen
        assign u_DwDutRasDpIf.logAddr = '0;
    end
endgenerate

logic [15:0] syndrome;
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        u_DwDutRasDpIf.syndrome <= #TP 1'b0;
    end else begin
        if (valid && u_DwDutRasDpIf.unc_fault_inj_cmd[1] && (!mask_fault_inj)) begin
            u_DwDutRasDpIf.syndrome <= #TP syndrome;
        end
    end
end

initial
    begin
        u_DwDutRasDpIf.set_prot_width(PROT_WD);
        u_DwDutRasDpIf.set_prot_type(PROT_TYPE);
        if (PROT_TYPE == 1) begin
            u_DwDutRasDpIf.set_prot_slice_width(1);
        end else begin
            if (ADDR_ECC_PROT_EN == 1) begin
                u_DwDutRasDpIf.set_prot_slice_width(calc_ecc_wd(PROT_RANGE+ADDR_WD));
            end else begin
                u_DwDutRasDpIf.set_prot_slice_width(calc_ecc_wd(PROT_RANGE));
            end
        end
    end

// signals from bus_protect_chk_w_err_inj to DwDutRasDpChecker
assign u_DwDutRasDpIf.err_inj_ongoing = err_inj_ongoing;
assign u_DwDutRasDpIf.err_inj_last    = err_inj_last;
assign u_DwDutRasDpIf.err_inj_failure = err_inj_failure;

assign i_chkin = prot_fault_inj_mask ^ chkin;
`else // SNPS_TB_INTERFACE
assign i_chkin = chkin;
`endif // SNPS_TB_INTERFACE
//VCS coverage on
`else // SYNTHESIS
assign i_chkin = chkin;
`endif // SYNTHESIS

genvar slice_inst;
generate
if (PROT_TYPE == 1) begin: g_par_prot //simple parity
    // calculate parity for all the slices
    for (slice_inst = 0; slice_inst < NUM_PROT_INST; slice_inst++) begin : g_parity_chk_instances
        bus_protect_chk_slice
         #(
            .PROT_TYPE                (PROT_TYPE),
            .PROT_WD                  (1),          
            .DATA_WD                  (PROT_RANGE),     
            .PARITY_MODE              (PARITY_MODE),
            .PROT_CORRECT_EN          (PROT_CORRECT_EN),
            .RAS_ERROR_SYNDROME_INDEX (RAS_ERROR_SYNDROME_INDEX)
            ,
            .ERR_INJ_INDEX_WIDTH    (ERR_INJ_INDEX_WIDTH)
        ) u_parity_chk_slice (
            .valid                  (valid                                     ),
            .chkin                  (i_chkin[slice_inst]                       ),
            .datain                 (datain[slice_inst*PROT_RANGE+:PROT_RANGE] ),
            .chkout                 (chkout[slice_inst]                        ),
            .dataout                (dataout[slice_inst*PROT_RANGE+:PROT_RANGE]),
            .fixdata                (fixdata[slice_inst*PROT_RANGE+:PROT_RANGE]),
            .err_inj_ongoing            (err_inj_ongoing                      ),
            .err_inj_last               (err_inj_last                         ),
            .err_inj_double             (err_inj_double                       ),
            .err_inj_bit_index_0_oh     (err_inj_bit_index_0_oh               ),
            .err_inj_bit_index_1_oh     (err_inj_bit_index_1_oh               ),
            .err_inj_failure            (err_inj_failure_array[slice_inst]    ),
            .err_inj_extra_inst_in_range(1'b1                                 ),
            `ifndef SYNTHESIS
            //VCS coverage off
            `ifdef SNPS_TB_INTERFACE
            .error_inj_fault_en         (error_inj_fault_en                   ),
            `endif // SNPS_TB_INTERFACE                       
            //VCS coverage on
            `endif // SYNTHESIS                               
            .ras_dp_err_log             (ras_dp_err_log_array[slice_inst]     )
        );
    end
    // calculate parity for the extra slice if there
    if (EXTRA_PROT_INST) begin : g_parity_chk_extra_instances
        bus_protect_chk_slice
         #(
            .PROT_TYPE                (PROT_TYPE),
            .PROT_WD                  (1),          
            .DATA_WD                  (EXTRA_BITS),     
            .PARITY_MODE              (PARITY_MODE),
            .PROT_CORRECT_EN          (PROT_CORRECT_EN),
            .RAS_ERROR_SYNDROME_INDEX (RAS_ERROR_SYNDROME_INDEX)
            ,
            .ERR_INJ_INDEX_WIDTH    (EXTRA_BITS+1)
        ) u_parity_chk_extra_slice (
            .valid                  (valid),
            .chkin                  (i_chkin[NUM_PROT_INST]                       ),
            .datain                 (datain[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS] ),
            .chkout                 (chkout[NUM_PROT_INST]                        ),
            .dataout                (dataout[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]),
            .fixdata                (fixdata[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]),
            .err_inj_ongoing            (err_inj_ongoing                              ),
            .err_inj_last               (err_inj_last                                 ),
            .err_inj_double             (err_inj_double                               ),
            .err_inj_bit_index_0_oh     (err_inj_bit_index_0_oh[EXTRA_BITS:0]         ),
            .err_inj_bit_index_1_oh     (err_inj_bit_index_1_oh[EXTRA_BITS:0]         ),
            .err_inj_failure            (err_inj_failure_array[NUM_PROT_INST]         ),
            .err_inj_extra_inst_in_range(err_inj_extra_inst_in_range                  ),
            `ifndef SYNTHESIS
            //VCS coverage off
            `ifdef SNPS_TB_INTERFACE
            .error_inj_fault_en         (error_inj_fault_en                           ),
            `endif // SNPS_TB_INTERFACE                       
            //VCS coverage on
            `endif // SYNTHESIS                               
            .ras_dp_err_log             (ras_dp_err_log_array[NUM_PROT_INST]          )
        );
    end
end else begin: g_ecc_prot
    if (ADDR_ECC_PROT_EN == 1) begin : g_ecc_chk_w_addr
        logic [(NUM_PROT_INST + EXTRA_PROT_INST)*ADDR_WD-1:0] unused_addrout;
        assign dataout[ADDR_INDEX +: ADDR_WD] = datain[ADDR_INDEX +: ADDR_WD];
        if (NUM_PROT_INST > 0) begin: g_ecc_chk_instance 
            for (slice_inst = 0; slice_inst < NUM_PROT_INST; slice_inst++) begin : g_ecc_chk_instances
                bus_protect_chk_slice
                 #(
                    .PROT_TYPE                (PROT_TYPE),
                    .PROT_WD                  (ECC_CHK_WD),      
                    .DATA_WD                  (PROT_RANGE+ADDR_WD),    
                    .PARITY_MODE              (PARITY_MODE),
                    .PROT_CORRECT_EN          (PROT_CORRECT_EN),
                    .RAS_ERROR_SYNDROME_INDEX (RAS_ERROR_SYNDROME_INDEX)
                    ,
                    .ERR_INJ_INDEX_WIDTH    (ERR_INJ_INDEX_WIDTH)
                ) u_ecc_chk_slice (
                    .valid                  (valid                                                                                      ),
                    .chkin                  (i_chkin[slice_inst*ECC_CHK_WD+:ECC_CHK_WD]                                                 ),
                    .datain                 ({datain[ADDR_INDEX +: ADDR_WD], datain[slice_inst*PROT_RANGE+:PROT_RANGE]}                 ),
                    .chkout                 (chkout [slice_inst*ECC_CHK_WD+:ECC_CHK_WD]                                                 ),
                    .dataout                ({unused_addrout[ADDR_WD*slice_inst +: ADDR_WD], dataout[slice_inst*PROT_RANGE+:PROT_RANGE]}),
                    .fixdata                (fixdata[slice_inst*(PROT_RANGE+ADDR_WD)+:(PROT_RANGE+ADDR_WD)]                             ),
                    .err_inj_ongoing            (err_inj_ongoing                      ),
                    .err_inj_last               (err_inj_last                         ),
                    .err_inj_double             (err_inj_double                       ),
                    .err_inj_bit_index_0_oh     (err_inj_bit_index_0_oh               ),
                    .err_inj_bit_index_1_oh     (err_inj_bit_index_1_oh               ),
                    .err_inj_failure            (err_inj_failure_array[slice_inst]    ),
                    .err_inj_extra_inst_in_range(1'b1                                 ),
                    `ifndef SYNTHESIS
                    //VCS coverage off
                    `ifdef SNPS_TB_INTERFACE
                    .error_inj_fault_en         (error_inj_fault_en                   ),
                    //VCS coverage on
                    `endif // SNPS_TB_INTERFACE                      
                    `endif // SYNTHESIS                              
                    .ras_dp_err_log             (ras_dp_err_log_array[slice_inst]     )
                ); 
            end
        end
        // extra instance of ECC checker, if required
        if (EXTRA_PROT_INST) begin : g_ecc_chk_extra_instance
            bus_protect_chk_slice
             #(
                .PROT_TYPE                (PROT_TYPE),          
                .PROT_WD                  (EXTRA_ECC_CHK_WD),    
                .DATA_WD                  (EXTRA_BITS+ADDR_WD),    
                .PARITY_MODE              (PARITY_MODE),        
                .PROT_CORRECT_EN          (PROT_CORRECT_EN),    
                .RAS_ERROR_SYNDROME_INDEX (RAS_ERROR_SYNDROME_INDEX)
                ,
                .ERR_INJ_INDEX_WIDTH    (EXTRA_BITS+ADDR_WD+EXTRA_ECC_CHK_WD)
            ) u_ecc_chk_extra_slice (
                .valid                  (valid                                                                                            ),
                .chkin                  (i_chkin[NUM_PROT_INST*ECC_CHK_WD +: EXTRA_ECC_CHK_WD]                                            ),
                .datain                 ({datain[ADDR_INDEX +: ADDR_WD], datain[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]}                    ),
                .chkout                 (chkout [NUM_PROT_INST*ECC_CHK_WD +: EXTRA_ECC_CHK_WD]                                            ),
                .dataout                ({unused_addrout[ADDR_WD*NUM_PROT_INST +: ADDR_WD], dataout[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]}),
                .fixdata                (fixdata[NUM_PROT_INST*(PROT_RANGE+ADDR_WD)+:(EXTRA_BITS+ADDR_WD)]                                ),
                .err_inj_ongoing            (err_inj_ongoing                                                ),
                .err_inj_last               (err_inj_last                                                   ),
                .err_inj_double             (err_inj_double                                                 ),
                .err_inj_bit_index_0_oh     (err_inj_bit_index_0_oh[EXTRA_BITS+EXTRA_ECC_CHK_WD+ADDR_WD-1:0]),
                .err_inj_bit_index_1_oh     (err_inj_bit_index_1_oh[EXTRA_BITS+EXTRA_ECC_CHK_WD+ADDR_WD-1:0]),
                .err_inj_failure            (err_inj_failure_array[NUM_PROT_INST]                           ),
                .err_inj_extra_inst_in_range(err_inj_extra_inst_in_range                                    ),
                `ifndef SYNTHESIS
                //VCS coverage off
                `ifdef SNPS_TB_INTERFACE
                .error_inj_fault_en         (error_inj_fault_en                                             ),
                `endif // SNPS_TB_INTERFACE                      
                //VCS coverage on
                `endif // SYNTHESIS                              
                .ras_dp_err_log             (ras_dp_err_log_array[NUM_PROT_INST]                            )
            );
        end
    end else begin : g_ecc_chk_wo_addr
        if (NUM_PROT_INST > 0) begin: g_ecc_chk_instance 
            for (slice_inst = 0; slice_inst < NUM_PROT_INST; slice_inst++) begin : g_ecc_chk_instances
                bus_protect_chk_slice
                 #(
                    .PROT_TYPE                (PROT_TYPE),
                    .PROT_WD                  (ECC_CHK_WD),     
                    .DATA_WD                  (PROT_RANGE),     
                    .PARITY_MODE              (PARITY_MODE),
                    .PROT_CORRECT_EN          (PROT_CORRECT_EN),
                    .RAS_ERROR_SYNDROME_INDEX (RAS_ERROR_SYNDROME_INDEX)
                    ,
                    .ERR_INJ_INDEX_WIDTH    (ERR_INJ_INDEX_WIDTH)
                ) u_ecc_chk_slice (
                    .valid                  (valid                                     ),
                    .chkin                  (i_chkin[slice_inst*ECC_CHK_WD+:ECC_CHK_WD]),
                    .datain                 (datain[slice_inst*PROT_RANGE+:PROT_RANGE] ),
                    .chkout                 (chkout [slice_inst*ECC_CHK_WD+:ECC_CHK_WD]),
                    .dataout                (dataout[slice_inst*PROT_RANGE+:PROT_RANGE]),
                    .fixdata                (fixdata[slice_inst*PROT_RANGE+:PROT_RANGE]),
                    .err_inj_ongoing            (err_inj_ongoing                  ),
                    .err_inj_last               (err_inj_last                     ),
                    .err_inj_double             (err_inj_double                   ),
                    .err_inj_bit_index_0_oh     (err_inj_bit_index_0_oh           ),
                    .err_inj_bit_index_1_oh     (err_inj_bit_index_1_oh           ),
                    .err_inj_failure            (err_inj_failure_array[slice_inst]),
                    .err_inj_extra_inst_in_range(1'b1                             ),
                    `ifndef SYNTHESIS
                    //VCS coverage off
                    `ifdef SNPS_TB_INTERFACE
                    .error_inj_fault_en         (error_inj_fault_en               ),
                    `endif // SNPS_TB_INTERFACE                      
                    //VCS coverage on
                    `endif // SYNTHESIS                              
                    .ras_dp_err_log             (ras_dp_err_log_array[slice_inst] )
                );
            end 
        end
        // extra instance of ECC checker, if required
        if (EXTRA_PROT_INST) begin : g_ecc_chk_extra_instance
            bus_protect_chk_slice
             #(
                .PROT_TYPE                (PROT_TYPE),
                .PROT_WD                  (EXTRA_ECC_CHK_WD),    
                .DATA_WD                  (EXTRA_BITS),      
                .PARITY_MODE              (PARITY_MODE),
                .PROT_CORRECT_EN          (PROT_CORRECT_EN),
                .RAS_ERROR_SYNDROME_INDEX (RAS_ERROR_SYNDROME_INDEX)
                ,
                .ERR_INJ_INDEX_WIDTH    (EXTRA_BITS+EXTRA_ECC_CHK_WD)
            ) u_ecc_chk_extra_slice (
                .valid                  (valid                                                ),
                .chkin                  (i_chkin[NUM_PROT_INST*ECC_CHK_WD +: EXTRA_ECC_CHK_WD]),
                .datain                 (datain[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]         ),
                .chkout                 (chkout[NUM_PROT_INST*ECC_CHK_WD +: EXTRA_ECC_CHK_WD] ),
                .dataout                (dataout[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]        ),
                .fixdata                (fixdata[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]        ),
                .err_inj_ongoing            (err_inj_ongoing                                        ),
                .err_inj_last               (err_inj_last                                           ),
                .err_inj_double             (err_inj_double                                         ),
                .err_inj_bit_index_0_oh     (err_inj_bit_index_0_oh[EXTRA_BITS+EXTRA_ECC_CHK_WD-1:0]),
                .err_inj_bit_index_1_oh     (err_inj_bit_index_1_oh[EXTRA_BITS+EXTRA_ECC_CHK_WD-1:0]),
                .err_inj_failure            (err_inj_failure_array[NUM_PROT_INST]                   ),
                .err_inj_extra_inst_in_range(err_inj_extra_inst_in_range                            ),
                `ifndef SYNTHESIS
                //VCS coverage off
                `ifdef SNPS_TB_INTERFACE
                .error_inj_fault_en         (error_inj_fault_en                                     ),
                `endif // SNPS_TB_INTERFACE                      
                //VCS coverage on
                `endif // SYNTHESIS                              
                .ras_dp_err_log             (ras_dp_err_log_array[NUM_PROT_INST]                    )
            );
        end
    end
end 
endgenerate

// ras dp err log packet word counter
logic [$clog2(MAX_RAS_ERR_LOG_WORD_NUM)-1:0] word_number, c_word_number;
    
always_comb begin
    c_word_number = 2'b00;
    if (word_number == 2'b00) begin
        c_word_number = 2'b01;
    end else if (word_number == 2'b01) begin
        if ((ADDR_LOG_EN == 1) && (ras_dp_err_log.log[RAS_ERROR_FORMAT_INDEX +: RAS_ERROR_FORMAT_WD])) begin
            c_word_number = 2'b10;
        end else begin
            c_word_number = 2'b00;
        end
    end else if (word_number == 2'b10) begin
        c_word_number = 2'b11;
    end else if (word_number == 2'b11) begin
        c_word_number = 2'b00;
    end
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        word_number <= #TP 2'b00;
    end else begin
        if (c_ras_dp_err_log.valid) begin
            word_number <= #TP c_word_number;
        end
    end
end

logic [NUM_PROT_INST+EXTRA_PROT_INST-1:0] addr_uncorr_error_array;
logic [2*RAS_ERROR_LOG_WD-1:0]            log_addr;
logic                                     at_least_one_uncorr, at_least_one_corr;
logic [RAS_ERROR_SLICE_ID_WD-1:0]         uncorr_slice_index,  corr_slice_index;

generate
    if ((ADDR_ECC_PROT_EN == 1) && (PROT_TYPE == 0)) begin : g_fixaddr
        if (NUM_PROT_INST > 0) begin : g_addr_uncorr_error_array
            for (slice_inst = 0; slice_inst < NUM_PROT_INST; slice_inst++) begin : g_slice_addr_uncorr
                assign addr_uncorr_error_array[slice_inst] = |fixdata[(slice_inst*(PROT_RANGE+ADDR_WD))+PROT_RANGE +: ADDR_WD];
            end 
        end

        if (EXTRA_PROT_INST) begin : g_addr_uncorr_error_array_extra
            assign addr_uncorr_error_array[NUM_PROT_INST] = |fixdata[(NUM_PROT_INST*(PROT_RANGE+ADDR_WD))+EXTRA_BITS +: ADDR_WD];
        end
    end else begin : g_no_fixaddr
        assign addr_uncorr_error_array = '0;
    end

    if (ADDR_LOG_EN == 1) begin : g_logaddr
        always_ff@(posedge clk or negedge rst_n) begin
            if(!rst_n)begin
                log_addr <= #TP '0;
            end else begin
                if (word_number == 2'b00) begin
                    if (at_least_one_uncorr || at_least_one_corr) begin
                        log_addr <= #TP {{(2*RAS_ERROR_LOG_WD-ADDR_WD){1'b0}}, datain[ADDR_INDEX +: ADDR_WD]};
                    end
                end
            end
        end
    end else begin : g_no_logaddr
        assign log_addr = '0;
    end
endgenerate


always_comb begin
    c_ras_dp_err_log    = '0;
    at_least_one_uncorr = '0;
    at_least_one_corr   = '0;
    uncorr_slice_index  = 0;
    corr_slice_index    = 0;
    `ifndef SYNTHESIS
    //VCS coverage off
    `ifdef SNPS_TB_INTERFACE
    syndrome = '0;
    `endif // SNPS_TB_INTERFACE
    //VCS coverage on
    `endif // SYNTHESIS
    if (word_number == 'd0) begin
        if (err_inj_ongoing) begin
            // while injecting errors
            c_ras_dp_err_log.valid = err_inj_failure | err_inj_last;
            if (err_inj_failure) begin
                c_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] = ERR_INJ_FAILURE;
            end else begin
                c_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] = ERR_INJ_SUCCESSFUL;
            end
        end else begin
            // while in mission mode
            for (int slice = 0; slice < (NUM_PROT_INST+EXTRA_PROT_INST); slice++) begin
                // valid is set if any slice sets it
                c_ras_dp_err_log.valid |= ras_dp_err_log_array[slice].valid;
                if ((ras_dp_err_log_array[slice].valid && (ras_dp_err_log_array[slice].log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == UNCORRECTABLE)) || ( addr_uncorr_error_array[slice])) begin
                    at_least_one_uncorr |= 1'b1;
                    uncorr_slice_index = slice;
                end
                if ((ras_dp_err_log_array[slice].valid && (ras_dp_err_log_array[slice].log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] ==   CORRECTABLE)) && (!addr_uncorr_error_array[slice])) begin
                    at_least_one_corr |= 1'b1;
                    corr_slice_index = slice;
                end
            end
            if (at_least_one_uncorr) begin
                c_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] = UNCORRECTABLE;
                if (PROT_TYPE == 0) begin
                    c_ras_dp_err_log.log[RAS_ERROR_SYNDROME_INDEX +: RAS_ERROR_SYNDROME_WD] = ras_dp_err_log_array[uncorr_slice_index].log[RAS_ERROR_SYNDROME_INDEX +: RAS_ERROR_SYNDROME_WD];
                    `ifndef SYNTHESIS
                    //VCS coverage off
                    `ifdef SNPS_TB_INTERFACE
                    syndrome[0 +: RAS_ERROR_SYNDROME_WD] = ras_dp_err_log_array[uncorr_slice_index].log[RAS_ERROR_SYNDROME_INDEX +: RAS_ERROR_SYNDROME_WD];
                    `endif // SNPS_TB_INTERFACE
                    //VCS coverage on
                    `endif // SYNTHESIS
                end
                c_ras_dp_err_log.log[RAS_ERROR_SLICE_ID_INDEX +: RAS_ERROR_SLICE_ID_WD] = uncorr_slice_index;
            end else begin
                c_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] = CORRECTABLE;
                if (PROT_TYPE == 0) begin
                    c_ras_dp_err_log.log[RAS_ERROR_SYNDROME_INDEX +: RAS_ERROR_SYNDROME_WD] = ras_dp_err_log_array[corr_slice_index].log[RAS_ERROR_SYNDROME_INDEX +: RAS_ERROR_SYNDROME_WD];
                    `ifndef SYNTHESIS
                    //VCS coverage off
                    `ifdef SNPS_TB_INTERFACE
                    syndrome[0 +: RAS_ERROR_SYNDROME_WD] = ras_dp_err_log_array[corr_slice_index].log[RAS_ERROR_SYNDROME_INDEX +: RAS_ERROR_SYNDROME_WD];
                    `endif // SNPS_TB_INTERFACE
                    //VCS coverage on
                    `endif // SYNTHESIS
                end
                c_ras_dp_err_log.log[RAS_ERROR_SLICE_ID_INDEX +: RAS_ERROR_SLICE_ID_WD] = corr_slice_index;
            end
            c_ras_dp_err_log.log[RAS_ERROR_FORMAT_INDEX +: RAS_ERROR_FORMAT_WD] = ADDR_LOG_EN;
        end
    end else if (word_number == 'd1) begin
        c_ras_dp_err_log.valid                                                      = 1'b1;
        c_ras_dp_err_log.log[RAS_ERROR_CHK_ID_INDEX     +: RAS_ERROR_CHK_ID_WD]     = RAS_PROT_CHK_ID;
        // RAS_ERROR_PROT_RANGE gives the width of the syndrome, that is:
        // 00 => parity, no syndrome
        // 01 => ecc32,  7-bits
        // 10 => ecc64,  8-bits
        // 11 => ecc128, 9-bits
        c_ras_dp_err_log.log[RAS_ERROR_PROT_RANGE_INDEX +: RAS_ERROR_PROT_RANGE_WD] = (PROT_TYPE == 1)? 0 : ($clog2(PROT_RANGE)-4);
    end else if (word_number == 'd2) begin
        c_ras_dp_err_log.valid                                                      = 1'b1;
        c_ras_dp_err_log.log[RAS_RAM_ADDR_LSB_INDEX     +: RAS_RAM_ADDR_LSB_WD]     = log_addr[               0 +: RAS_ERROR_LOG_WD];
    end else begin
        c_ras_dp_err_log.valid                                                      = 1'b1;
        c_ras_dp_err_log.log[RAS_RAM_ADDR_MSB_INDEX     +: RAS_RAM_ADDR_MSB_WD]     = log_addr[RAS_ERROR_LOG_WD +: RAS_ERROR_LOG_WD];
    end
end

assign ras_dp_err_inband_kbd_out = c_ras_dp_err_log.valid && (word_number == 'd0) && (c_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == UNCORRECTABLE);

generate
if ((PROT_TYPE == 1) && (PIPE_RAS_DP_ERR_LOG == 0) && (NUM_PROT_INST <= 32)) begin : g_output_stage_no_pipe
    assign ras_dp_err_log = c_ras_dp_err_log;
end else begin : g_output_stage_pipe
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            ras_dp_err_log <= #TP '0;
        end else begin
            if (c_ras_dp_err_log.valid) begin
                ras_dp_err_log <= #TP c_ras_dp_err_log;
            end else begin
                ras_dp_err_log <= #TP '0;
            end 
        end
    end
end
endgenerate



`ifndef SYNTHESIS
//VCS coverage off
//VCS coverage on
`endif // SYNTHESIS


//-----------------------------------------------------------------------------
endmodule

// Revision: $Id: //dwh/pcie_iip/main/fairbanks/design/common/bus_protect_chk_w_err_inj.sv#6 $
