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
// --- This module
//  The main function is generate parity or ECC check bits
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
 
module bus_protect_gen_wo_err_inj
import DWC_pcie_ctl_pkg::calc_ecc_wd;
import DWC_pcie_ctl_pkg::f_verify_ecc_wd;
#(
    //---------- Parameters ----------
    parameter PROT_TYPE        = 0,   // 0=Ecc            1=Simple Parity
    parameter PROT_RANGE       = 64,  // Number of bits to calculate parity or ECC on
    parameter PROT_WD          = 16,  // chkout bus width
    parameter DATA_WD          = 128, // data bus width
    parameter PARITY_MODE      = 0,   // Parity mode when PROT_TYPE == 1. 0-EVEN/1-ODD
    parameter ADDR_ECC_PROT_EN = 0,
    parameter ADDR_INDEX       = 0, 
    parameter ADDR_WD          = 0 
)   
(
    input  logic [DATA_WD-1 :0] datain,
    output logic [PROT_WD-1 :0] chkout,
    output logic [DATA_WD-1 :0] dataout
);

// ----------------------------------------------------------------------------
// --- Local Parameters
// ----------------------------------------------------------------------------
// determine the number of protection instances required to cover DATA_WD bits 
// using a PROT_RANGE bit range
localparam NUM_PROT_INST   = (DATA_WD - (ADDR_ECC_PROT_EN? ADDR_WD : 0)) / PROT_RANGE;

// determine the number of bits protected by the extra instance
localparam EXTRA_BITS      = (DATA_WD - (ADDR_ECC_PROT_EN? ADDR_WD : 0)) % PROT_RANGE;

// if DATA_WD is not an integer multiple of PROT_RANGE there is the need for an additional
// protection instance.  
localparam EXTRA_PROT_INST = (EXTRA_BITS > 0)? 1:0 ;

genvar slice_inst;
generate
if (PROT_TYPE==1) begin : g_parity_gen
    if (NUM_PROT_INST > 0) begin : g_par_gen_num_prot_inst_gt0                                  
       for (slice_inst = 0; slice_inst < NUM_PROT_INST; slice_inst++) begin : g_par_gen_instances
           bus_protect_gen_slice
            #(
               .PROT_TYPE   (PROT_TYPE  ),  
               .PROT_WD     (1          ), 
               .DATA_WD     (PROT_RANGE ),
               .PARITY_MODE (PARITY_MODE)
           ) u_parity_gen_slice (
               .datain      (datain[(PROT_RANGE*slice_inst)+:PROT_RANGE] ),
               .chkout      (chkout[slice_inst]                          ),
               .dataout     (dataout[(PROT_RANGE*slice_inst)+:PROT_RANGE])
           );
       end    
    end
    if (EXTRA_PROT_INST) begin: g_par_gen_extra_instance
        bus_protect_gen_slice
         #(
            .PROT_TYPE   (PROT_TYPE  ),  
            .PROT_WD     (1          ), 
            .DATA_WD     (EXTRA_BITS ),
            .PARITY_MODE (PARITY_MODE)
        ) u_parity_gen_slice (
            .datain      (datain[(PROT_RANGE*NUM_PROT_INST)+:EXTRA_BITS] ),
            .chkout      (chkout[NUM_PROT_INST]                          ),
            .dataout     (dataout[(PROT_RANGE*NUM_PROT_INST)+:EXTRA_BITS])
        );
    end
end else begin : g_ecc_gen
    if (ADDR_ECC_PROT_EN == 1) begin : g_ecc_gen_w_addr
        logic [(NUM_PROT_INST + EXTRA_PROT_INST)*ADDR_WD-1:0] unused_addrout;
        assign dataout[ADDR_INDEX +: ADDR_WD] = datain[ADDR_INDEX +: ADDR_WD];
        localparam int ECC_GEN_WD = calc_ecc_wd(PROT_RANGE+ADDR_WD);                                       
        if (NUM_PROT_INST>0) begin : g_ecc_gen_num_prot_inst_gt0
            for (slice_inst = 0; slice_inst < NUM_PROT_INST; slice_inst++) begin : g_ecc_gen_instances
                bus_protect_gen_slice
                 #(                                                                           
                    .PROT_TYPE   (PROT_TYPE         ),                                                                      
                    .PROT_WD     (ECC_GEN_WD        ),                                                                     
                    .DATA_WD     (PROT_RANGE+ADDR_WD),                                                                     
                    .PARITY_MODE (PARITY_MODE       )                                                                     
                ) u_ecc_gen_slice (                                                                                
                    .datain      ({                datain[ADDR_INDEX +: ADDR_WD], datain[(PROT_RANGE*slice_inst) +: PROT_RANGE]} ), 
                    .chkout      (chkout[ECC_GEN_WD*slice_inst +: ECC_GEN_WD]                                                    ),                          
                    .dataout     ({unused_addrout[ADDR_WD*slice_inst +: ADDR_WD], dataout[(PROT_RANGE*slice_inst) +: PROT_RANGE]})                         
                );                                                                                                 
            end            
        end            
        if (EXTRA_PROT_INST>0) begin : g_ecc_gen_extra_prot_inst
            localparam int ECC_GEN_WD_EXTRA = calc_ecc_wd(EXTRA_BITS+ADDR_WD);                                       
            bus_protect_gen_slice
             #(                                                                           
                .PROT_TYPE   (PROT_TYPE         ),                                                                      
                .PROT_WD     (ECC_GEN_WD_EXTRA  ),                                                                     
                .DATA_WD     (EXTRA_BITS+ADDR_WD),                                                                     
                .PARITY_MODE (PARITY_MODE       )                                                                     
            ) u_ecc_gen_slice (                                                                                
                .datain      ({                datain[ADDR_INDEX +: ADDR_WD], datain[(PROT_RANGE*NUM_PROT_INST) +: EXTRA_BITS]}    ), 
                .chkout      (chkout[ECC_GEN_WD*NUM_PROT_INST +: ECC_GEN_WD_EXTRA]                                                 ),                          
                .dataout     ({unused_addrout[ADDR_WD*NUM_PROT_INST +: ADDR_WD], dataout[(PROT_RANGE*NUM_PROT_INST) +: EXTRA_BITS]})                         
            );                                                                                                 
        end
    end else begin : g_ecc_gen_wo_addr
        localparam int ECC_GEN_WD = calc_ecc_wd(PROT_RANGE);                                       
        if (NUM_PROT_INST>0) begin : g_ecc_gen_num_prot_inst_gt0
            for (slice_inst = 0; slice_inst < NUM_PROT_INST; slice_inst++) begin : g_ecc_gen_instances
                bus_protect_gen_slice
                 #(                                                                           
                    .PROT_TYPE   (PROT_TYPE  ),                                                                      
                    .PROT_WD     (ECC_GEN_WD ),                                                                     
                    .DATA_WD     (PROT_RANGE ),                                                                     
                    .PARITY_MODE (PARITY_MODE)                                                                     
                ) u_ecc_gen_slice (                                                                                
                    .datain      (datain[(PROT_RANGE*slice_inst) +: PROT_RANGE] ), 
                    .chkout      (chkout[ECC_GEN_WD*slice_inst +: ECC_GEN_WD]   ),                          
                    .dataout     (dataout[(PROT_RANGE*slice_inst) +: PROT_RANGE])                         
                );                                                                                                 
            end            
        end            
        if (EXTRA_PROT_INST>0) begin : g_ecc_gen_extra_prot_inst
            localparam int ECC_GEN_WD_EXTRA = calc_ecc_wd(EXTRA_BITS);                                       
            bus_protect_gen_slice
             #(                                                                           
                .PROT_TYPE   (PROT_TYPE         ),                                                                      
                .PROT_WD     (ECC_GEN_WD_EXTRA  ),                                                                     
                .DATA_WD     (EXTRA_BITS        ),                                                                     
                .PARITY_MODE (PARITY_MODE       )                                                                     
            ) u_ecc_gen_slice (                                                                                
                .datain      (datain[(PROT_RANGE*NUM_PROT_INST) +: EXTRA_BITS]      ), 
                .chkout      (chkout[ECC_GEN_WD*NUM_PROT_INST   +: ECC_GEN_WD_EXTRA]),                          
                .dataout     (dataout[(PROT_RANGE*NUM_PROT_INST) +: EXTRA_BITS]     )                         
            );                                                                                                 
        end
    end
end
endgenerate 


//-----------------------------------------------------------------------------
endmodule

// Revision: $Id: //dwh/pcie_iip/main/fairbanks/design/common/bus_protect_gen_wo_err_inj.sv#3 $
