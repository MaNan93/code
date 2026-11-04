//
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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_tph_ctrl.sv#3 $
// -------------------------------------------------------------------------
// Description:
//---------------------------------------------------------------------------------------    

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_tph_ctrl
  #(
  ) 
                      (

    // Input/Output Declaration
         input  [1:0] flt_q_fmt_in,
         input  [4:0] flt_q_type_in,
         input flt_q_th_in,
         input  [1:0] flt_q_ph_in,
         input flit_mode,
         input [64-1:0] flt_q_addr_in,
         input [7:0] flt_q_tag
   ,
         input [7:0] flt_q_ohc_b_st_lb,
         input [3:0] flt_q_last_be_in,
         input [3:0] flt_q_first_be_in,
         input [1:0] flt_q_ats_in,
         input [9:0] flt_q_dw_len_in,
         output logic [64-1:0] flt_q_addr_tph,
         output logic [1:0]    flt_q_ph_tph,
         output logic [7:0]    flt_q_st,
         output logic [3:0]    flt_q_first_be_tph,
         output logic [3:0]    flt_q_last_be_tph
  );

logic [6:0] trgt1_fmt_type;
logic       trgt1_tph_memrd;
logic       trgt1_tph_memwr;
logic       trgt1_tph_atomic;
logic       trgt1_tph_defmemwr;


assign trgt1_fmt_type = {flt_q_fmt_in,flt_q_type_in};

assign trgt1_tph_memrd = flt_q_th_in && ((trgt1_fmt_type == `MRD32) ||
                                           (trgt1_fmt_type == `MRD64) ||
                                           (trgt1_fmt_type == `MRDLK32) ||
                                           (trgt1_fmt_type == `MRDLK64));
 
assign trgt1_tph_memwr = flt_q_th_in && ((trgt1_fmt_type == `MWR32) ||
                                           (trgt1_fmt_type == `MWR64));

assign trgt1_tph_atomic = flt_q_th_in && ((trgt1_fmt_type == `FETCHADD32) ||
                                            (trgt1_fmt_type == `FETCHADD64) ||
                                            (trgt1_fmt_type == `SWAP32)     ||
                                            (trgt1_fmt_type == `SWAP64)     ||
                                            (trgt1_fmt_type == `CAS32)      ||
                                            (trgt1_fmt_type == `CAS64));

 assign trgt1_tph_defmemwr         =  flt_q_th_in && ((trgt1_fmt_type == `DMWR32)  || (trgt1_fmt_type == `DMWR64));

                                   
//assign radm_trgt1_th_i              = radm_trgt1_hdr[`RADM_PQ_TH_RANGE];
assign flt_q_ph_tph              = flt_q_th_in ? flt_q_ph_in : 2'b00;
// Steering tags carried in the tag field for a MemWr and in the Byte
// Enable field for a MemRd.
// Assign zero if the TLP does not have the TH bit set.

always_comb begin : STEERING_TAG

     flt_q_st  = 'd0;

      if (flit_mode)
        flt_q_st = flt_q_ohc_b_st_lb ; // No need to consider specific TLP type. RADM forwards the received ST field at application 
      else
        flt_q_st = trgt1_tph_memwr ? flt_q_tag[7:0] : ((trgt1_tph_atomic | trgt1_tph_memrd | trgt1_tph_defmemwr) ? {flt_q_last_be_in,flt_q_first_be_in} : 'd0);
end //STEERING_TAG


// Assign the radm_trgt1_first_be and radm_trgt1_last_be assumed values
// according to the TPH ECN spec. TLP's of length 1 DWORD should have a
// FBE of 1111 and a LBE of 0000. TLP's of length greater than 1 DWORD
// should have a FBE of 1111 and a LBE of 1111
always_comb begin : STEERING_BE
      flt_q_first_be_tph =  'd0;
      flt_q_last_be_tph  =  'd0;

    if (flit_mode)
    begin
      flt_q_first_be_tph =  flt_q_first_be_in;
      flt_q_last_be_tph  =  flt_q_last_be_in;
    end
    else
    begin
     flt_q_first_be_tph = trgt1_tph_atomic ? 4'h0 : 
                             (trgt1_tph_memrd | trgt1_tph_defmemwr) ? 4'hF : 
                             flt_q_first_be_in;
     flt_q_last_be_tph  = trgt1_tph_atomic ? 4'h0 : 
                             (trgt1_tph_memrd | trgt1_tph_defmemwr)  ? ((flt_q_dw_len_in != 1) ? 4'hF : 4'h0) :
                             flt_q_last_be_in;
    end
end // STEERING_BE


assign flt_q_addr_tph[64-1:0] = flt_q_th_in ? {flt_q_addr_in[64-1:2],2'b00} :
 (flit_mode && (|flt_q_ats_in)) ? {flt_q_addr_in[64-1:2],2'b00} :
                                               (flt_q_ats_in == 2'b01) ? {flt_q_addr_in[64-1:1],1'b0} :
                                               flt_q_addr_in[64-1:0];


endmodule
