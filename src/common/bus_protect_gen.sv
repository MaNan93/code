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
 
 module bus_protect_gen 
import DWC_pcie_ctl_pkg::calc_ecc_wd;
import DWC_pcie_ctl_pkg::f_verify_ecc_wd;
#(
                         //---------- Parameters ----------
                         parameter PROT_TYPE            = 0  ,      // 0=Ecc            1=Simple Parity
                         parameter PROT_RANGE           = 64 ,      // Number of bits to calculate parity or ECC on
                         parameter PROT_WD              = 16 ,      // chkout bus width
                         parameter DATA_WD              = 128,      // data bus width
                         parameter PARITY_MODE          = 0,        // Parity mode when PROT_TYPE == 1. 0-EVEN/1-ODD
                         parameter FORCE_ERR_INJ_OFF    = 0         // Allows specific generators to force error injection off
                         )   
   (
    //---------- Inputs --------------
    input wire                       gen,
    input wire [DATA_WD-1 :0]        datain,
    input wire                       core_clk,
    input wire                       core_rst_n,
    input wire [DATA_WD+PROT_WD-1:0] error_inj_mask,
    input wire                       error_inj_en,
    input wire                       error_inj_data_valid,
    input wire                       error_inj_eot,
    output wire                      error_inj_done,
    //---------- Outputs --------------
    output wire [PROT_WD-1 :0]       chkout,
    output wire [DATA_WD-1 :0]       dataout
    );
   parameter TP                    = `TP;                  // Clock to Q delay (simulator insurance)
   // ----------------------------------------------------------------------------
   // --- Local Parameters
   // ----------------------------------------------------------------------------
   // determine the number of protection instances required to cover DATA_WD bits 
   // using a PROT_RANGE bit range
   localparam NUM_PROT_INST   = DATA_WD / PROT_RANGE;

   // determine the number of bits protected by the extra instance
   localparam EXTRA_BITS      = DATA_WD % PROT_RANGE;

   // if DATA_WD is not an integer multiple of PROT_RANGE there is the need for an additional
   // protection instance.  
   localparam EXTRA_PROT_INST = (EXTRA_BITS>0)? 1:0 ;

   //Wires
   wire [PROT_WD-1:0]                chkout_tmp;
   wire [DATA_WD-1:0]                dataout_tmp;

   //ERROR INJECTION
   generate
      if (FORCE_ERR_INJ_OFF == 0) begin : gen_force_err_inj_on
         reg                               error_inj_en_reg;
         wire                              error_inj_en_tmp;
   
         always @(posedge core_clk or negedge core_rst_n)
         begin: error_inj_en_reg_PROC
           if (!core_rst_n)
              error_inj_en_reg <= #TP 1'b0;
           else if (error_inj_eot | (~error_inj_en))
                 error_inj_en_reg <= #TP 1'b0;
           else if (error_inj_data_valid)
                error_inj_en_reg <= #TP 1'b1;
         end
         
         assign error_inj_en_tmp = !error_inj_en_reg && error_inj_en && error_inj_data_valid;
         assign error_inj_done   =  error_inj_en_tmp;
         

         assign chkout  = (error_inj_en_tmp==1)? chkout_tmp [PROT_WD-1:0] ^ error_inj_mask[PROT_WD-1:0]: chkout_tmp;
         assign dataout = dataout_tmp;
      end else begin : gen_force_err_inj_off
         assign chkout           = chkout_tmp;
         assign dataout          = dataout_tmp;
         assign error_inj_done   =  1'b0;
      end // else: !if(FORCE_ERR_INJ_OFF == 0)
   endgenerate


   genvar gv1,gv2;

   generate if (PROT_TYPE==1) //simple parity
     begin: Parity_gen
        for (gv2=0;gv2<NUM_PROT_INST;gv2=gv2+1) begin : GEN_PARITY_FOR
           if (PARITY_MODE) begin : GEN_PARITY_FOR_ODD
             assign chkout_tmp[gv2] = (!gen)?1'b0:!(^ datain[(PROT_RANGE*gv2)+:PROT_RANGE]); //ODD parity
           end
           else begin : GEN_PARITY_FOR_EVEN
             assign chkout_tmp[gv2] = (!gen)?1'b0:(^ datain[(PROT_RANGE*gv2)+:PROT_RANGE]); // EVEN parity
           end
        end
        assign dataout_tmp = datain;
     end
      
   else if (PROT_RANGE ==8 && NUM_PROT_INST>0)// ECC
     begin: ecc_PROT_RANGE8_gen
        localparam ECC_CHKOUT_WD_INST  = 6;
        wire [NUM_PROT_INST-1:0]                      err_detect_unc;
        wire [NUM_PROT_INST-1:0]                      err_multpl_unc;
        wire [(NUM_PROT_INST*ECC_CHKOUT_WD_INST)-1:0] syndout_unc;
        for (gv1=0;gv1<NUM_PROT_INST;gv1=gv1+1)
          begin: gen_ECC_instanves_8
             DWC_pcie_ctl_bcm46_a
              #(.WIDTH(PROT_RANGE)) 
             u_ecc    (
                       .gen         ( gen                                                     ),
                       .correct_n   ( 1'b1                                                    ),
                       .datain      ( datain[gv1*PROT_RANGE+:PROT_RANGE]                      ),
                       .chkin       ( {ECC_CHKOUT_WD_INST{1'b0}}                              ),
                       .err_detect  ( err_detect_unc[gv1]                                     ),
                       .err_multpl  ( err_multpl_unc[gv1]                                     ),
                       .dataout     ( dataout_tmp[gv1*PROT_RANGE+:PROT_RANGE]                 ),
                       .chkout      ( chkout_tmp[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]  ),
                       .fixdata     (),
                       .syndout     ( syndout_unc[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] )
                       ); 
          end 
     end
   else if (PROT_RANGE ==16 && NUM_PROT_INST>0)// ECC
     begin: ecc_PROT_RANGE16_gen
        localparam ECC_CHKOUT_WD_INST  = 6;
        wire [NUM_PROT_INST-1:0]                      err_detect_unc;
        wire [NUM_PROT_INST-1:0]                      err_multpl_unc;
        wire [(NUM_PROT_INST*ECC_CHKOUT_WD_INST)-1:0] syndout_unc;
        for (gv1=0;gv1<NUM_PROT_INST;gv1=gv1+1)
          begin: gen_ECC_instanves_16
             DWC_pcie_ctl_bcm46_a
              #(.WIDTH(PROT_RANGE)) 
             u_ecc    (
                       .gen         ( gen                                                     ),
                       .correct_n   ( 1'b1                                                    ),
                       .datain      ( datain[gv1*PROT_RANGE+:PROT_RANGE]                      ),
                       .chkin       ( {ECC_CHKOUT_WD_INST{1'b0}}                              ),
                       .err_detect  ( err_detect_unc[gv1]                                     ),
                       .err_multpl  ( err_multpl_unc[gv1]                                     ),
                       .dataout     ( dataout_tmp[gv1*PROT_RANGE+:PROT_RANGE]                 ),
                       .chkout      ( chkout_tmp[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]  ),
                       .fixdata     (),
                       .syndout     ( syndout_unc[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] )
                       ); 
          end 
     end
   else if (PROT_RANGE ==32 && NUM_PROT_INST>0)// ECC
     begin: ecc_PROT_RANGE32_gen
        localparam ECC_CHKOUT_WD_INST  = 7;
        wire [NUM_PROT_INST-1:0]                      err_detect_unc;
        wire [NUM_PROT_INST-1:0]                      err_multpl_unc;
        wire [(NUM_PROT_INST*ECC_CHKOUT_WD_INST)-1:0] syndout_unc;
        for (gv1=0;gv1<NUM_PROT_INST;gv1=gv1+1)
          begin: gen_ECC_instanves_32
             DWC_pcie_ctl_bcm46_b
              #(.WIDTH(PROT_RANGE)) 
             u_ecc    (
                       .gen         ( gen                                                     ),
                       .correct_n   ( 1'b1                                                    ),
                       .datain      ( datain[gv1*PROT_RANGE+:PROT_RANGE]                      ),
                       .chkin       ( {ECC_CHKOUT_WD_INST{1'b0}}                              ),
                       .err_detect  ( err_detect_unc[gv1]                                     ),
                       .err_multpl  ( err_multpl_unc[gv1]                                     ),
                       .dataout     ( dataout_tmp[gv1*PROT_RANGE+:PROT_RANGE]                 ),
                       .chkout      ( chkout_tmp[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]  ),
                       .fixdata     (),
                       .syndout     ( syndout_unc[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] )
                       ); 
          end 
     end
   else if (PROT_RANGE ==64 && NUM_PROT_INST>0)// ECC
     begin: ecc_PROT_RANGE64_gen
        localparam ECC_CHKOUT_WD_INST  = 8;
        wire [NUM_PROT_INST-1:0]                      err_detect_unc;
        wire [NUM_PROT_INST-1:0]                      err_multpl_unc;
        wire [(NUM_PROT_INST*ECC_CHKOUT_WD_INST)-1:0] syndout_unc;
        for (gv1=0;gv1<NUM_PROT_INST;gv1=gv1+1)
          begin: gen_ECC_instanves_64
             DWC_pcie_ctl_bcm46_c
              #(.WIDTH(PROT_RANGE)) 
             u_ecc    (
                       .gen         ( gen                                                     ),
                       .correct_n   ( 1'b1                                                    ),
                       .datain      ( datain[gv1*PROT_RANGE+:PROT_RANGE]                      ),
                       .chkin       ( {ECC_CHKOUT_WD_INST{1'b0}}                              ),
                       .err_detect  ( err_detect_unc[gv1]                                     ),
                       .err_multpl  ( err_multpl_unc[gv1]                                     ),
                       .dataout     ( dataout_tmp[gv1*PROT_RANGE+:PROT_RANGE]                 ),
                       .chkout      ( chkout_tmp[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]  ),
                       .fixdata     (),
                       .syndout     ( syndout_unc[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] )
                       ); 
          end 
     end
   else if (PROT_RANGE ==128 && NUM_PROT_INST>0)// ECC
     begin: ecc_PROT_RANGE128_gen
        localparam ECC_CHKOUT_WD_INST  = 9;
        wire [NUM_PROT_INST-1:0]                      err_detect_unc;
        wire [NUM_PROT_INST-1:0]                      err_multpl_unc;
        wire [(NUM_PROT_INST*ECC_CHKOUT_WD_INST)-1:0] syndout_unc;
        for (gv1=0;gv1<NUM_PROT_INST;gv1=gv1+1)
          begin: gen_ECC_instanves_128
             DWC_pcie_ctl_bcm46_d
              #(.WIDTH(PROT_RANGE)) 
             u_ecc    (
                       .gen         ( gen                                                     ),
                       .correct_n   ( 1'b1                                                    ),
                       .datain      ( datain[gv1*PROT_RANGE+:PROT_RANGE]                      ),
                       .chkin       ( {ECC_CHKOUT_WD_INST{1'b0}}                              ),
                       .err_detect  ( err_detect_unc[gv1]                                     ),
                       .err_multpl  ( err_multpl_unc[gv1]                                     ),
                       .dataout     ( dataout_tmp[gv1*PROT_RANGE+:PROT_RANGE]                 ),
                       .chkout      ( chkout_tmp[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]  ),
                       .fixdata     (),
                       .syndout     ( syndout_unc[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] )
                       ); 
          end
     end
   else if (NUM_PROT_INST>0)//ECC
     begin: ecc_PROT_RANGE256_gen
        localparam ECC_CHKOUT_WD_INST  = 10; 
        wire [NUM_PROT_INST-1:0]                      err_detect_unc;
        wire [NUM_PROT_INST-1:0]                      err_multpl_unc;
        wire [(NUM_PROT_INST*ECC_CHKOUT_WD_INST)-1:0] syndout_unc;
        for (gv1=0;gv1<NUM_PROT_INST;gv1=gv1+1)
          begin: gen_ECC_instanves_256
             DWC_pcie_ctl_bcm46_e
              #(.WIDTH(PROT_RANGE)) 
             u_ecc    (
                       .gen         ( gen                                                     ),
                       .correct_n   ( 1'b1                                                    ),
                       .datain      ( datain[gv1*PROT_RANGE+:PROT_RANGE]                      ),
                       .chkin       ( {ECC_CHKOUT_WD_INST{1'b0}}                              ),
                       .err_detect  ( err_detect_unc[gv1]                                     ),
                       .err_multpl  ( err_multpl_unc[gv1]                                     ),
                       .dataout     ( dataout_tmp[gv1*PROT_RANGE+:PROT_RANGE]                 ),
                       .chkout      ( chkout_tmp[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]  ),
                       .fixdata     (),
                       .syndout     ( syndout_unc[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] )
                       ); 
          end
     end
      
   endgenerate

   generate if (EXTRA_PROT_INST==1)
     begin: Prot_gen_extra_bits
        if (PROT_TYPE==1) begin : extra_bits_par_gen// Parity      
          assign chkout_tmp[NUM_PROT_INST] = (!gen)?1'b0: ((PARITY_MODE)? !(^ datain[(PROT_RANGE*NUM_PROT_INST) +: EXTRA_BITS]): (^ datain[(PROT_RANGE*NUM_PROT_INST) +: EXTRA_BITS]));
        end
        else // ECC
          begin: extra_bits_ecc_gen
             if (EXTRA_BITS > 247)
               begin: extra_bits_ecc_gen_bcm46_e
                  localparam EXTRA_CHK_WD = 10;
                  wire [EXTRA_CHK_WD-1:0] extra_syndout_unc;
                  DWC_pcie_ctl_bcm46_e
                   #(.WIDTH(EXTRA_BITS)) 
                  u_ecc (
                         .gen         ( gen                                                  ),
                         .correct_n   ( 1'b1                                                 ),
                         .datain      ( datain[NUM_PROT_INST*PROT_RANGE +: EXTRA_BITS]       ),
                         .chkin       ( {EXTRA_CHK_WD{1'b0}}                                 ),
                         .err_detect  ( extra_err_detect_unc                                 ),
                         .err_multpl  ( extra_err_multpl_unc                                 ),
                         .dataout     ( dataout_tmp[NUM_PROT_INST*PROT_RANGE +: EXTRA_BITS]  ),
                         .chkout      ( chkout_tmp[(PROT_WD-EXTRA_CHK_WD)  +: EXTRA_CHK_WD]  ), 
                         .fixdata     (),
                         .syndout     ( extra_syndout_unc                                    )
                         ); 
               end 
             else if (EXTRA_BITS > 120)
               begin: extra_bits_ecc_gen_bcm46_d
                  localparam EXTRA_CHK_WD = 9;
                  wire [EXTRA_CHK_WD-1:0] extra_syndout_unc;
                  DWC_pcie_ctl_bcm46_d
                   #(.WIDTH(EXTRA_BITS)) 
                  u_ecc (
                         .gen         ( gen                                                  ),
                         .correct_n   ( 1'b1                                                 ),
                         .datain      ( datain[NUM_PROT_INST*PROT_RANGE +: EXTRA_BITS]       ),
                         .chkin       ( {EXTRA_CHK_WD{1'b0}}                                 ),
                         .err_detect  ( extra_err_detect_unc                                 ),
                         .err_multpl  ( extra_err_multpl_unc                                 ),
                         .dataout     ( dataout_tmp[NUM_PROT_INST*PROT_RANGE +: EXTRA_BITS]  ),
                         .chkout      ( chkout_tmp[(PROT_WD-EXTRA_CHK_WD)  +: EXTRA_CHK_WD]  ), 
                         .fixdata     (),
                         .syndout     ( extra_syndout_unc                                    )
                         ); 
               end 
             else if (EXTRA_BITS > 57)
               begin: extra_bits_ecc_gen_bcm46_c
                  localparam EXTRA_CHK_WD = 8;
                  wire [EXTRA_CHK_WD-1:0] extra_syndout_unc;
                  DWC_pcie_ctl_bcm46_c
                   #(.WIDTH(EXTRA_BITS)) 
                  u_ecc (
                         .gen         ( gen                                                  ),
                         .correct_n   ( 1'b1                                                 ),
                         .datain      ( datain[NUM_PROT_INST*PROT_RANGE +: EXTRA_BITS]       ),
                         .chkin       ( {EXTRA_CHK_WD{1'b0}}                                 ),
                         .err_detect  ( extra_err_detect_unc                                 ),
                         .err_multpl  ( extra_err_multpl_unc                                 ),
                         .dataout     ( dataout_tmp[NUM_PROT_INST*PROT_RANGE +: EXTRA_BITS]  ),
                         .chkout      ( chkout_tmp[(PROT_WD-EXTRA_CHK_WD)  +: EXTRA_CHK_WD]  ), 
                         .fixdata     (),
                         .syndout     ( extra_syndout_unc                                    )
                         ); 
               end 
             else if (EXTRA_BITS > 26)
               begin: extra_bits_ecc_gen_bcm46_b
                  localparam EXTRA_CHK_WD = 7;
                  wire [EXTRA_CHK_WD-1:0] extra_syndout_unc;
                  DWC_pcie_ctl_bcm46_b
                   #(.WIDTH(EXTRA_BITS)) 
                  u_ecc (
                         .gen         ( gen                                                  ),
                         .correct_n   ( 1'b1                                                 ),
                         .datain      ( datain[NUM_PROT_INST*PROT_RANGE +: EXTRA_BITS]       ),
                         .chkin       ( {EXTRA_CHK_WD{1'b0}}                                 ),
                         .err_detect  ( extra_err_detect_unc                                 ),
                         .err_multpl  ( extra_err_multpl_unc                                 ),
                         .dataout     ( dataout_tmp[NUM_PROT_INST*PROT_RANGE +: EXTRA_BITS]  ),
                         .chkout      ( chkout_tmp[(PROT_WD-EXTRA_CHK_WD)  +: EXTRA_CHK_WD]  ), 
                         .fixdata     (),
                         .syndout     ( extra_syndout_unc                                    )
                         ); 
               end 
             else
               begin: extra_bits_ecc_gen_bcm46_a
                  localparam EXTRA_CHK_WD = 6;
                  wire [EXTRA_CHK_WD-1:0] extra_syndout_unc;
                  DWC_pcie_ctl_bcm46_a
                   #(.WIDTH(EXTRA_BITS)) 
                  u_ecc (
                         .gen         ( gen                                                  ),
                         .correct_n   ( 1'b1                                                 ),
                         .datain      ( datain[NUM_PROT_INST*PROT_RANGE +: EXTRA_BITS]       ),
                         .chkin       ( {EXTRA_CHK_WD{1'b0}}                                 ),
                         .err_detect  ( extra_err_detect_unc                                 ),
                         .err_multpl  ( extra_err_multpl_unc                                 ),
                         .dataout     ( dataout_tmp[NUM_PROT_INST*PROT_RANGE +: EXTRA_BITS]  ),
                         .chkout      ( chkout_tmp[(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD]   ),
                         .fixdata     (),
                         .syndout     ( extra_syndout_unc                                    )
                         ); 
               end
          end
     end
   endgenerate 


   //-----------------------------------------------------------------------------

`ifndef SYNTHESIS
     wire [15:0] prot_wd;
     assign prot_wd = PROT_WD;
`endif // SYNTHESIS


     //-----------------------------------------------------------------------------
     endmodule

// Revision: $Id: //dwh/pcie_iip/main/fairbanks/design/common/bus_protect_gen.sv#8 $
