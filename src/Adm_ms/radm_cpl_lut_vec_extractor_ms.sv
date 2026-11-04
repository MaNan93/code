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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_cpl_lut_vec_extractor_ms.sv#3 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Selects the data input for the next stage TLP check module.
// --- Attributes(Function Num, Traffic class ....) remaining same within split CPL TLP are passing directly from NP TLP storage module to NP TLP check module.
// --- Attributes( Byte count, address bits ) changing with split CPL TLP have a mux selection within a module. Because of the pipeline stages between NP TLP storage
//     and CPL TLP check module, module selects the updated value from local register to manage the byte counts properly for back to back split CPL TLPs.
//     
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_cpl_lut_vec_extractor_ms
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::TAG_SIZE;
  import radm_ms_pkg::CPL_ENTRY_WIDTH;
  import radm_ms_pkg::CPL_LUT_PTR_WD;
  // ## CPL_LUT2 ##
  import radm_ms_pkg::CPL_ENTRY_WIDTH2;        
  import radm_ms_pkg::HW;
  import radm_ms_pkg::RADM_HDR_PROT_WD;
#(
    parameter FORMQ_RD_PORTS = `CX_RADM_FORMQ_N_READ_PORT_VC
)(
  // ---- inputs ---------------
  input                                   core_clk,                        // Core clock
  input   [3:0]                           tag_bits_13_to_10,               // tag bit input for bit 13 down to 10.             
  input                                   filt_lut_hv,                     // tlp header valid
  input [HW+RADM_HDR_PROT_WD-1:0]         filt_lut_hdr,                    // tlp header data 
  input [CPL_ENTRY_WIDTH-1:0]             cpl_lut_vec,                     // lut vector input for basic info       
  input [CPL_ENTRY_WIDTH2-1:0]            cpl_lut2_vec,                    // lut vector input for byte count information. 
  input                                   update_lut_content_pipe,         // flopped version of the lut content update request. 
  input [CPL_LUT_PTR_WD-1:0]              update_lut_addr_pipe,            // flopped version of the lut content update address. 
  input [CPL_ENTRY_WIDTH2-1:0]            update_lut_byte_cnt_pipe,        // flopped version of the lut byte count value.
  input                                   update_lut_content_pipe_reg,     // double flopped version of the lut content update request. 
  input [CPL_LUT_PTR_WD-1:0]              update_lut_addr_pipe_reg,        // double flopped version of the lut content update address. 
  input [CPL_ENTRY_WIDTH2-1:0]            update_lut_byte_cnt_pipe_reg,    // double flopped version of the lut byte count value.
  input                                   cpl_last_pipe,                   // flopped version of cpl last
  input                                   cpl_last_pipe_reg,               // double flopped version of cpl last

  // ---- outputs ---------------
  output                                  cpl_14bit_tag,                   // tag is 14 bit tag
  output  [CPL_LUT_PTR_WD-1:0]            lut_addr,                        // lut address
  output  [CPL_ENTRY_WIDTH-1:0]           lut_vec,                         // lut vec output 
  output logic [CPL_ENTRY_WIDTH2-1:0]     lut_vec2                         // lut vec2 output
  ,output   logic                         going_to_clear_valid             // going to clear valid indication for pipe line stages. 
  );
  /////////////////////////////////////////////////////////////
  // Local logics and registers
  //
  /////////////////////////////////////////////////////////////
  logic   [TAG_SIZE-1:0]                  rcvd_cpl_tlp_tag;
  
  //////////////////////////////////
  //  TAG extraction 
  //////////////////////////////////
  assign rcvd_cpl_tlp_tag         = {tag_bits_13_to_10,filt_lut_hdr[15], filt_lut_hdr[11], filt_lut_hdr[87:80]};
  logic rcvd_cpl_14bit_tag;
  // tag size is 14bit but we do not enable 14bit requester capability while LUT size is less than 1K. Only 10/8 bit requester capabilities are enabled.
  assign rcvd_cpl_14bit_tag       = |rcvd_cpl_tlp_tag[13:8];
  assign cpl_14bit_tag            = rcvd_cpl_14bit_tag;

  //////////////////////////////////
  // ### Extract LUT Address ###
  //////////////////////////////////
  logic [TAG_SIZE-1:0] rcvd_cpl_tlp_tag_mapped;
  // tag size is 14bit but we do not enable 14bit requester capability while LUT size is less than 1K. Only 10/8 bit requester capabilities are enabled.
  assign rcvd_cpl_tlp_tag_mapped[7:0]  = rcvd_cpl_tlp_tag[7:0];
  assign rcvd_cpl_tlp_tag_mapped[13:8] = rcvd_cpl_14bit_tag ? (rcvd_cpl_tlp_tag[13:8]-6'h01) : 6'h00;
  assign lut_addr                      = rcvd_cpl_tlp_tag_mapped [CPL_LUT_PTR_WD -1:0];

  ///////////////////////////////////////////////////////
  //   ### LUT_VEC extraction ###
  //////////////////////////////////////////////////////
  assign  lut_vec              = cpl_lut_vec;

  always_comb begin : lut_valid_PROC
    going_to_clear_valid = '0;
    // asignment from flops in can lut update in progress   
    if(update_lut_content_pipe && (lut_addr == update_lut_addr_pipe)) begin
      going_to_clear_valid = cpl_last_pipe;
    end
    else
    if(update_lut_content_pipe_reg  && (lut_addr == update_lut_addr_pipe_reg)) begin
      going_to_clear_valid = cpl_last_pipe_reg;
    end
  end // always

  always_comb begin : lut_vec2_assign_PROC
    //default assignment from lut.
    lut_vec2 = cpl_lut2_vec;   
    // asignment from flops in can lut update in progress   
    if(update_lut_content_pipe && (lut_addr == update_lut_addr_pipe)) begin
      lut_vec2 = update_lut_byte_cnt_pipe;
    end
    else
    if(update_lut_content_pipe_reg  && (lut_addr == update_lut_addr_pipe_reg)) begin
      lut_vec2 = update_lut_byte_cnt_pipe_reg;
    end
  end // always


endmodule
