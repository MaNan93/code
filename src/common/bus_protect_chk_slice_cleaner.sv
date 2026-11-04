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
// --- This module takes care of flipping the bits going to a checker for error
// injection. An outer loop takes care of single bit injection, while an inner
// loop takes care of double bit injection.
// ----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

module bus_protect_chk_slice_cleaner
#(
    parameter PROT_TYPE   = 0,
    parameter PARITY_MODE = 0,
    parameter PROT_WD     = 16,
    parameter DATA_WD     = 128
)   

                                    (
    input  logic               valid,
    input  logic [PROT_WD-1:0] chkin,  
    input  logic [DATA_WD-1:0] datain, 
    output logic [PROT_WD-1:0] chkout, 
    output logic [DATA_WD-1:0] dataout
);

generate
if (PROT_TYPE == 1) begin : g_slice_cleaner_parity
    // calculate parity
    if (PARITY_MODE) begin : g_gen_odd_parity_prot
        assign chkout = valid? chkin : !(^ {(DATA_WD){1'b0}}); //ODD parity
    end else begin : GEN_EVEN_PARITY_PROT
        assign chkout = valid? chkin :  (^ {(DATA_WD){1'b0}}); //EVEN parity
    end
    assign dataout = valid? datain : {(DATA_WD){1'b0}};
end else begin : g_slice_cleaner_ecc
    logic [PROT_WD-1:0] chk;
    assign dataout = valid? datain : {(DATA_WD){1'b0}};
    assign chkout  = valid? chkin : chk;
    if (DATA_WD <= 26) begin: g_ecc_data_wd16_chk_cleaner          
        DWC_pcie_ctl_bcm46_a
         #(
            .WIDTH(DATA_WD)
        ) u_ecc (
            .gen        (1'b1             ),
            .correct_n  (1'b1             ),
            .datain     ({(DATA_WD){1'b0}}),
            .chkin      ('0               ),
            .err_detect (                 ),
            .err_multpl (                 ),
            .dataout    (                 ),
            .fixdata    (                 ),
            .chkout     (chk              ),
            .syndout    (                 ));
    end else if (DATA_WD <= 57) begin: g_ecc_data_wd32_chk_cleaner
        DWC_pcie_ctl_bcm46_b
         #(
            .WIDTH(DATA_WD)
        ) u_ecc (
            .gen        (1'b1             ),
            .correct_n  (1'b1             ),
            .datain     ({(DATA_WD){1'b0}}),
            .chkin      ('0               ),
            .err_detect (                 ),
            .err_multpl (                 ),
            .dataout    (                 ),
            .fixdata    (                 ),
            .chkout     (chk              ),
            .syndout    (                 ));
    end else if (DATA_WD <= 120) begin: g_ecc_data_wd64_chk_cleaner
        DWC_pcie_ctl_bcm46_c
         #(
            .WIDTH(DATA_WD)
        ) u_ecc (
            .gen        (1'b1             ),
            .correct_n  (1'b1             ),
            .datain     ({(DATA_WD){1'b0}}),
            .chkin      ('0               ),
            .err_detect (                 ),
            .err_multpl (                 ),
            .dataout    (                 ),
            .fixdata    (                 ),
            .chkout     (chk              ),
            .syndout    (                 ));
    end else if (DATA_WD <= 247) begin: g_ecc_data_wd128_chk_cleaner
        DWC_pcie_ctl_bcm46_d
         #(
            .WIDTH(DATA_WD)
        ) u_ecc (
            .gen        (1'b1             ),
            .correct_n  (1'b1             ),
            .datain     ({(DATA_WD){1'b0}}),
            .chkin      ('0               ),
            .err_detect (                 ),
            .err_multpl (                 ),
            .dataout    (                 ),
            .fixdata    (                 ),
            .chkout     (chk              ),
            .syndout    (                 ));
    end else begin: g_ecc_data_wd1256_chk_cleaner
        DWC_pcie_ctl_bcm46_e
         #(
            .WIDTH(DATA_WD)
        ) u_ecc (
            .gen        (1'b1             ),
            .correct_n  (1'b1             ),
            .datain     ({(DATA_WD){1'b0}}),
            .chkin      ('0               ),
            .err_detect (                 ),
            .err_multpl (                 ),
            .dataout    (                 ),
            .fixdata    (                 ),
            .chkout     (chk              ),
            .syndout    (                 ));
    end
end
endgenerate

endmodule

// Revision: $Id: //dwh/pcie_iip/main/fairbanks/design/common/bus_protect_chk_slice_cleaner.sv#3 $
