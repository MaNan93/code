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
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/bus_protect_gen_slice.sv#1 $
// -------------------------------------------------------------------------
// ---
// --- This module
//  The main function is generate parity or ECC check bits
// ---
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
 
module bus_protect_gen_slice
#(
    //---------- Parameters ----------
    parameter PROT_TYPE   = 0,   // 0=Ecc            1=Simple Parity
    parameter PROT_WD     = 16,  // chkout bus width
    parameter DATA_WD     = 128, // data bus width
    parameter PARITY_MODE = 0
)   
(
    input  logic [DATA_WD-1 :0] datain,
    output logic [PROT_WD-1 :0] chkout,
    output logic [DATA_WD-1 :0] dataout
);

generate
if (PROT_TYPE==1) begin : g_parity_gen
    if (PARITY_MODE) begin : GEN_ODD_PARITY
        assign chkout = !(^ datain); //ODD parity
    end else begin : GEN_EVEN_PARITY
        assign chkout =  (^ datain); // EVEN parity
    end
    assign dataout = datain;
end else begin : g_ecc_gen
    logic                  err_detect_unc;
    logic                  err_multpl_unc;
    logic [DATA_WD-1:0] fixdata_unc;
    logic [PROT_WD-1:0]    syndout_unc;
    if (DATA_WD <= 26) begin : g_ecc_prot_range_up_to_26
        DWC_pcie_ctl_bcm46_a
         #(
            .WIDTH       (DATA_WD                )
        ) u_ecc (
            .gen         (1'b1                      ),
            .correct_n   (1'b0                      ),
            .datain      (datain                    ),
            .chkin       ('0                        ),
            .err_detect  (err_detect_unc            ),
            .err_multpl  (err_multpl_unc            ),
            .dataout     (dataout                   ),
            .fixdata     (fixdata_unc               ),
            .chkout      (chkout                    ),
            .syndout     (syndout_unc               )
        ); 
    end else if (DATA_WD <= 57) begin : g_ecc_prot_range_up_to_57
        DWC_pcie_ctl_bcm46_b
         #(
            .WIDTH       (DATA_WD                )
        ) u_ecc (
            .gen         (1'b1                      ),
            .correct_n   (1'b0                      ),
            .datain      (datain                    ),
            .chkin       ('0                        ),
            .err_detect  (err_detect_unc            ),
            .err_multpl  (err_multpl_unc            ),
            .dataout     (dataout                   ),
            .fixdata     (fixdata_unc               ),
            .chkout      (chkout                    ),
            .syndout     (syndout_unc               )
        ); 
    end else if (DATA_WD <= 120) begin : g_ecc_prot_range_up_to_120
        DWC_pcie_ctl_bcm46_c
         #(
            .WIDTH       (DATA_WD                )
        ) u_ecc (
            .gen         (1'b1                      ),
            .correct_n   (1'b0                      ),
            .datain      (datain                    ),
            .chkin       ('0                        ),
            .err_detect  (err_detect_unc            ),
            .err_multpl  (err_multpl_unc            ),
            .dataout     (dataout                   ),
            .fixdata     (fixdata_unc               ),
            .chkout      (chkout                    ),
            .syndout     (syndout_unc               )
        ); 
    end else if (DATA_WD <= 247) begin : g_ecc_prot_range_up_to_247
        DWC_pcie_ctl_bcm46_d
         #(
            .WIDTH       (DATA_WD                )
        ) u_ecc (
            .gen         (1'b1                      ),
            .correct_n   (1'b0                      ),
            .datain      (datain                    ),
            .chkin       ('0                        ),
            .err_detect  (err_detect_unc            ),
            .err_multpl  (err_multpl_unc            ),
            .dataout     (dataout                   ),
            .fixdata     (fixdata_unc               ),
            .chkout      (chkout                    ),
            .syndout     (syndout_unc               )
        ); 
    end else begin: g_ecc_prot_range_up_to_502
        DWC_pcie_ctl_bcm46_e
         #(
            .WIDTH       (DATA_WD                )
        ) u_ecc (
            .gen         (1'b1                      ),
            .correct_n   (1'b0                      ),
            .datain      (datain                    ),
            .chkin       ('0                        ),
            .err_detect  (err_detect_unc            ),
            .err_multpl  (err_multpl_unc            ),
            .dataout     (dataout                   ),
            .fixdata     (fixdata_unc               ),
            .chkout      (chkout                    ),
            .syndout     (syndout_unc               )
        ); 
    end
end
endgenerate

endmodule
