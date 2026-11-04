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
// The main function is:
// - in case of error correc the datain data and signalise by flag errors
// ----------------------------------------------------------------------------


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module bus_protect_chk #(
//---------- Parameters ----------
    parameter PROT_TYPE            = 0  ,      // 0=Ecc            1=Simple Parity
    parameter PROT_RANGE           = 64 ,      // Number of bits to calculate parity or ECC on
    parameter PROT_WD              = 16 ,      // chkout bus width
    parameter DATA_WD              = 128,      // data bus width
    parameter PROT_CORRECT_EN      = 1  ,      // Enable the capability of correction words
    parameter PARITY_MODE          = 0         // Parity mode when PROT_TYPE == 1. 0-EVEN/1-ODD 
   )   
   (
//---------- Inputs --------------
    input  wire               correct_n ,
    input  wire [PROT_WD-1:0] chkin     ,
    input  wire [DATA_WD-1:0] datain    ,
//---------- Outputs --------------
    output wire               err_detect,
    output wire               err_multpl,
    output wire [DATA_WD-1:0] dataout   ,
    output wire [PROT_WD-1:0] chkout    ,
    output wire [PROT_WD-1:0] syndout
);

// ----------------------------------------------------------------------------
// --- Local Parameters
// ----------------------------------------------------------------------------
// determine the number of bits protected by the extra instance
localparam EXTRA_BITS      = DATA_WD % PROT_RANGE;

// if DATA_WD is not an integer multiple of PROT_RANGE there is the need for an additional
// protection instance.  
//localparam EXTRA_PROT_INST = ((DATA_WD % PROT_RANGE) > 0)? 1 : 0; 
localparam EXTRA_PROT_INST = | EXTRA_BITS;

// get the number of  protection instances / parity bits 
localparam NUM_PROT_INST   = DATA_WD/PROT_RANGE;


genvar gv1,gv2;
  
generate if (PROT_TYPE==1) //simple parity
 begin: gen_par_prot
   wire [PROT_WD-1:0] chk_tmp;
    for (gv2=0;gv2<NUM_PROT_INST;gv2=gv2+1) begin : GEN_PAR_PROT_FOR
       if (PARITY_MODE) begin : GEN_PAR_PROT_FOR_ODD
          assign chk_tmp[gv2] = !(^ datain[(PROT_RANGE*gv2)+:PROT_RANGE]); //ODD parity
        end
        else begin : GEN_PAR_PROT_FOR_EVEN
          assign chk_tmp[gv2] = (^ datain[(PROT_RANGE*gv2)+:PROT_RANGE]); //EVEN parity
        end
       end
    // calculate parity for the extra bits if they exist
     if (EXTRA_PROT_INST) begin: GEN_EXTRA_PAR_PROT
       assign chk_tmp[NUM_PROT_INST] = (PARITY_MODE)? !(^datain[(PROT_RANGE*NUM_PROT_INST)+:EXTRA_BITS]): ^datain[(PROT_RANGE*NUM_PROT_INST)+:EXTRA_BITS];
     end

  assign err_multpl = (chk_tmp==chkin?1'b0:1'b1); 
  assign dataout    = datain;
  assign chkout     = chkin ;
  assign syndout    = chkin^chk_tmp ;
  assign err_detect = 1'b0  ;
 end
else
 begin: gen_ecc_prot
    wire [NUM_PROT_INST+EXTRA_PROT_INST-1:0] err_detect_tmp;
    wire [NUM_PROT_INST+EXTRA_PROT_INST-1:0] err_multpl_tmp;
    wire   correct_n_wire;
    if (PROT_CORRECT_EN) begin : GEN_ERR_CORRECT_EN
        assign correct_n_wire = correct_n;
        assign err_detect = (|err_detect_tmp) && (~err_multpl);
        assign err_multpl = |err_multpl_tmp;
      end
    else
      begin : GEN_ERR_NOCORRECT_EN
        assign correct_n_wire = 1'b1;
        assign err_detect = 1'b0;
        assign err_multpl = (|err_multpl_tmp) || (|err_detect_tmp);   
      end
   if (NUM_PROT_INST >0)
   begin: no_prot_inst 
    case (PROT_RANGE)    
      8: begin: ecc_PROT_RANGE8_chk
         localparam ECC_CHKOUT_WD_INST  = 6; 
         for (gv1=0;gv1<NUM_PROT_INST;gv1=gv1+1)
           begin: gen_ECC_instanves_8
             DWC_pcie_ctl_bcm46_a
              #(.WIDTH(PROT_RANGE)) 
             u_ecc    (
                   .gen         ( 1'b0                                                ),
                   .correct_n   ( correct_n_wire                                      ),
                   .datain      ( datain[gv1*PROT_RANGE+:PROT_RANGE]                  ),
                   .chkin       ( chkin [gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]  ),
                   .err_detect  ( err_detect_tmp[gv1]                                 ),
                   .err_multpl  ( err_multpl_tmp[gv1]                                 ),
                   .dataout     ( dataout[gv1*PROT_RANGE+:PROT_RANGE]                 ),
                   .chkout      ( chkout [gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] ),
                   .fixdata     (),
                   .syndout     ( syndout[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] ) 
                      ); 
           end 
      end
      16: begin: ecc_PROT_RANGE16_chk
          localparam ECC_CHKOUT_WD_INST  = 6; 
          for (gv1=0;gv1<NUM_PROT_INST;gv1=gv1+1)
            begin: gen_ECC_instanves_16
             DWC_pcie_ctl_bcm46_a
              #(.WIDTH(PROT_RANGE)) 
             u_ecc    (
                   .gen         ( 1'b0                                                    ),
                   .correct_n   ( correct_n_wire                                          ),
                   .datain      ( datain[gv1*PROT_RANGE+:PROT_RANGE]                      ),
                   .chkin       ( chkin [gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]      ),
                   .err_detect  ( err_detect_tmp[gv1]                                     ),
                   .err_multpl  ( err_multpl_tmp[gv1]                                     ),
                   .dataout     ( dataout[gv1*PROT_RANGE+:PROT_RANGE]                     ),
                   .chkout      ( chkout [gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]     ),
                   .fixdata     (),
                   .syndout     ( syndout[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] )
                      ); 
            end
      end
      32: begin: ecc_PROT_RANGE32_chk
          localparam ECC_CHKOUT_WD_INST  = 7; 
          for (gv1=0;gv1<NUM_PROT_INST;gv1=gv1+1)
            begin: gen_ECC_instanves_32
             DWC_pcie_ctl_bcm46_b
              #(.WIDTH(PROT_RANGE)) 
             u_ecc    (
                   .gen         ( 1'b0                                                    ),
                   .correct_n   ( correct_n_wire                                          ),
                   .datain      ( datain[gv1*PROT_RANGE+:PROT_RANGE]                      ),
                   .chkin       ( chkin [gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]      ),
                   .err_detect  ( err_detect_tmp[gv1]                                     ),
                   .err_multpl  ( err_multpl_tmp[gv1]                                     ),
                   .dataout     ( dataout[gv1*PROT_RANGE+:PROT_RANGE]                     ),
                   .chkout      ( chkout [gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]     ),
                   .fixdata     (),
                   .syndout     ( syndout[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] )
                      ); 
            end 
      end
      64: begin: ecc_PROT_RANGE64_chk
          localparam ECC_CHKOUT_WD_INST  = 8; 
          for (gv1=0;gv1<NUM_PROT_INST;gv1=gv1+1)
            begin: gen_ECC_instanves_64
             DWC_pcie_ctl_bcm46_c
              #(.WIDTH(PROT_RANGE)) 
             u_ecc    (
                   .gen         ( 1'b0                                                    ),
                   .correct_n   ( correct_n_wire                                          ),
                   .datain      ( datain[gv1*PROT_RANGE+:PROT_RANGE]                      ),
                   .chkin       ( chkin [gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]      ),
                   .err_detect  ( err_detect_tmp[gv1]                                     ),
                   .err_multpl  ( err_multpl_tmp[gv1]                                     ),
                   .dataout     ( dataout[gv1*PROT_RANGE+:PROT_RANGE]                     ),
                   .chkout      ( chkout [gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]     ),
                   .fixdata     (),
                   .syndout     ( syndout[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] )
                      ); 
            end 
      end
      128: begin: ecc_PROT_RANGE128_chk
           localparam ECC_CHKOUT_WD_INST  = 9; 
           for (gv1=0;gv1<NUM_PROT_INST;gv1=gv1+1)
             begin: gen_ECC_instanves_128
              DWC_pcie_ctl_bcm46_d
               #(.WIDTH(PROT_RANGE)) 
              u_ecc    (
                   .gen         ( 1'b0                                                    ),
                   .correct_n   ( correct_n_wire                                          ),
                   .datain      ( datain[gv1*PROT_RANGE+:PROT_RANGE]                      ),
                   .chkin       ( chkin [gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]      ),
                   .err_detect  ( err_detect_tmp[gv1]                                     ),
                   .err_multpl  ( err_multpl_tmp[gv1]                                     ),
                   .dataout     ( dataout[gv1*PROT_RANGE+:PROT_RANGE]                     ),
                   .chkout      ( chkout [gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]     ),
                   .fixdata     (),
                   .syndout     ( syndout[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] )
                      ); 
            end
      end 
      default: begin: ecc_PROT_RANGE1256_chk
           localparam ECC_CHKOUT_WD_INST  = 10; 
           for (gv1=0;gv1<NUM_PROT_INST;gv1=gv1+1)
             begin: gen_ECC_instanves_256
              DWC_pcie_ctl_bcm46_e
               #(.WIDTH(PROT_RANGE)) 
              u_ecc    (
                   .gen         ( 1'b0                                                    ),
                   .correct_n   ( correct_n_wire                                          ),
                   .datain      ( datain[gv1*PROT_RANGE+:PROT_RANGE]                      ),
                   .chkin       ( chkin [gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]      ),
                   .err_detect  ( err_detect_tmp[gv1]                                     ),
                   .err_multpl  ( err_multpl_tmp[gv1]                                     ),
                   .dataout     ( dataout[gv1*PROT_RANGE+:PROT_RANGE]                     ),
                   .chkout      ( chkout [gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST]     ),
                   .fixdata     (),
                   .syndout     ( syndout[gv1*ECC_CHKOUT_WD_INST+:ECC_CHKOUT_WD_INST] )
                      ); 
            end 
      end
    endcase
    end
    // extra instance of ECC checker, if required
    if (EXTRA_PROT_INST)
    begin: gen_ecc_extra
      if (EXTRA_BITS > 247)
      begin: gen_ecc_extra_bcm46_e
        localparam EXTRA_CHK_WD=10;
        DWC_pcie_ctl_bcm46_e
         #(.WIDTH(EXTRA_BITS)) 
          u_ecc    (
                .gen         ( 1'b0                                            ),
                .correct_n   ( correct_n_wire                                  ),
                .datain      ( datain[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]    ),
                .chkin       ( chkin [(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD]  ), 
                .err_detect  ( err_detect_tmp[NUM_PROT_INST]                   ),
                .err_multpl  ( err_multpl_tmp[NUM_PROT_INST]                   ),
                .dataout     ( dataout[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]   ),
                .chkout      ( chkout [(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD] ),
                .fixdata     (),
                .syndout     ( syndout[(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD] )
                   );                    
      end
      else if (EXTRA_BITS > 120)
      begin: gen_ecc_extra_bcm46_d
        localparam EXTRA_CHK_WD=9;
        DWC_pcie_ctl_bcm46_d
         #(.WIDTH(EXTRA_BITS)) 
          u_ecc    (
                .gen         ( 1'b0                                            ),
                .correct_n   ( correct_n_wire                                  ),
                .datain      ( datain[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]    ),
                .chkin       ( chkin [(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD]  ), 
                .err_detect  ( err_detect_tmp[NUM_PROT_INST]                   ),
                .err_multpl  ( err_multpl_tmp[NUM_PROT_INST]                   ),
                .dataout     ( dataout[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]   ),
                .chkout      ( chkout [(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD] ),
                .fixdata     (),
                .syndout     ( syndout[(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD] )
                   );                    
      end
      else if (EXTRA_BITS > 57)
      begin: gen_ecc_extra_bcm46_c
        localparam EXTRA_CHK_WD=8;
        DWC_pcie_ctl_bcm46_c
         #(.WIDTH(EXTRA_BITS)) 
          u_ecc    (
                .gen         ( 1'b0                                            ),
                .correct_n   ( correct_n_wire                                  ),
                .datain      ( datain[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]    ),
                .chkin       ( chkin [(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD]  ), 
                .err_detect  ( err_detect_tmp[NUM_PROT_INST]                   ),
                .err_multpl  ( err_multpl_tmp[NUM_PROT_INST]                   ),
                .dataout     ( dataout[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]   ),
                .chkout      ( chkout [(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD] ),
                .fixdata     (),
                .syndout     ( syndout[(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD] )
                   );                    
      end
      else if (EXTRA_BITS > 26)
      begin: gen_ecc_extra_bcm46_b
        localparam EXTRA_CHK_WD=7;
        DWC_pcie_ctl_bcm46_b
         #(.WIDTH(EXTRA_BITS)) 
          u_ecc    (
                .gen         ( 1'b0                                            ),
                .correct_n   ( correct_n_wire                                  ),
                .datain      ( datain[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]    ),
                .chkin       ( chkin [(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD]  ), 
                .err_detect  ( err_detect_tmp[NUM_PROT_INST]                   ),
                .err_multpl  ( err_multpl_tmp[NUM_PROT_INST]                   ),
                .dataout     ( dataout[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]   ),
                .chkout      ( chkout [(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD] ),
                .fixdata     (),
                .syndout     ( syndout[(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD] )
                   );                    
      end
      else
      begin: gen_ecc_extra_bcm46_a
        localparam EXTRA_CHK_WD=6;
        DWC_pcie_ctl_bcm46_a
         #(.WIDTH(EXTRA_BITS)) 
          u_ecc    (
                .gen         ( 1'b0                                            ),
                .correct_n   ( correct_n_wire                                  ),
                .datain      ( datain[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]    ),
                .chkin       ( chkin [(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD]  ), 
                .err_detect  ( err_detect_tmp[NUM_PROT_INST]                   ),
                .err_multpl  ( err_multpl_tmp[NUM_PROT_INST]                   ),
                .dataout     ( dataout[NUM_PROT_INST*PROT_RANGE+:EXTRA_BITS]   ),
                .chkout      ( chkout [(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD] ),
                .fixdata     (),
                .syndout     ( syndout[(PROT_WD-EXTRA_CHK_WD) +: EXTRA_CHK_WD] )
                   );                    
      end
    end

 end 
endgenerate


//-----------------------------------------------------------------------------


`ifndef SYNTHESIS
  initial
  begin
    if ($time == 0) begin $display("Check_Block path %m"); end
  end
`endif // SYNTHESIS


//-----------------------------------------------------------------------------
endmodule

// Revision: $Id: //dwh/pcie_iip/main/fairbanks/design/common/bus_protect_chk.sv#8 $
