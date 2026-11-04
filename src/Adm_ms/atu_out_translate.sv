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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/atu_out_translate.sv#4 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Outbound translation unit. The address from the xadm is examined to
// --- determine if it matches any of the memory regions defined by the cdm
// --- inputs from the port logic register. If so the header of the TLP is
// --- formed from the cdm inputs
// -----------------------------------------------------------------------------
`include "DWC_pcie_ctl_pkg.svh"
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/pcie_pkg.svh"
//import DWC_pcie_core_pkg::cdm_atu_out_cfg_t;
//import DWC_pcie_core_pkg::atu_out_totranslate_t;
//import DWC_pcie_core_pkg::atu_out_translated_t;
//import DWC_pcie_ctl_pkg::BUSNUM_WD;
//import DWC_pcie_ctl_pkg::DEVNUM_WD;
//import DWC_pcie_ctl_pkg::ATU_OUT_NREGIONS;
//import DWC_pcie_ctl_pkg::ATU_OUT_NREGIONS_MIN1;
//import DWC_pcie_ctl_pkg::NF;
//import DWC_pcie_ctl_pkg::PF_WD;
//import DWC_pcie_ctl_pkg::ATTR_WD;
module atu_out_translate
import DWC_pcie_core_pkg::*;
import DWC_pcie_ctl_pkg::*;
import pcie_pkg::*;

                        (
    input  logic                 clk,
    input  logic                 rst_n,
    input  mode_e                mode,
    input  cdm_atu_out_cfg_t     cdm_atu_out_cfg,

    input  atu_pkt_t             atu_pkt,
    input  tlp_hdr_pkt_s         i_tlp_hdr_pkt,
    output tlp_hdr_pkt_s         o_tlp_hdr_pkt,

    output logic                 inhibit_pyld,
    output logic                 enable
);


tlp_hdr_pkt_s p_tlp_hdr_pkt;


generate if(ATU_OUT_NREGIONS==0)begin : g_0_regions
    assign p_tlp_hdr_pkt  = i_tlp_hdr_pkt;
    assign inhibit_pyld   = '0;
    //assign msg_code     = '0; // WHat is msg_code here?
    assign enable         = 1'b0;
end else begin : g_regions
    
    //atu_out_translated_t [ATU_OUT_NREGIONS_MIN1-1:0] c;
    wire ari_enable = 1'b0;
    wire is_dm      = 1'b0 || 1'b1;
    
    always_comb begin
        p_tlp_hdr_pkt  = i_tlp_hdr_pkt;
        o_tlp_hdr_pkt  = p_tlp_hdr_pkt;
        enable         = 1'b0;
        inhibit_pyld   = '0;
        //msg_code     = '0;
        for(int i = ATU_OUT_NREGIONS_MIN1-1; i >= 0; i--)begin
            if(atu_pkt.match[i])begin
                enable                             = 1'b1;
                inhibit_pyld                       = cdm_atu_out_cfg.inhibit_pyld[i];

                p_tlp_hdr_pkt.tlp_type             = cdm_atu_out_cfg.tlp_type[i];
                p_tlp_hdr_pkt.tlp_type[0]          = (i_tlp_hdr_pkt.tlp_fmt[1] && cdm_atu_out_cfg.tlp_type[i]==5'b00001) ? 1'b0 : p_tlp_hdr_pkt.tlp_type[0];             
                p_tlp_hdr_pkt.tlp_msg_code         = cdm_atu_out_cfg.msg_code[i];
                p_tlp_hdr_pkt.tlp_tc               = (cdm_atu_out_cfg.hdr_flds_bypass[i]) ? i_tlp_hdr_pkt.tlp_tc : cdm_atu_out_cfg.tc[i];
                p_tlp_hdr_pkt.tlp_attr[0+:ATTR_WD] = (cdm_atu_out_cfg.hdr_flds_bypass[i]) ? i_tlp_hdr_pkt.tlp_attr[0+:ATTR_WD] : cdm_atu_out_cfg.attr[i][0+:ATTR_WD];
                p_tlp_hdr_pkt.tlp_at               = (cdm_atu_out_cfg.hdr_flds_bypass[i]) ? i_tlp_hdr_pkt.tlp_at : cdm_atu_out_cfg.at[i];
                p_tlp_hdr_pkt.tlp_th               = (cdm_atu_out_cfg.hdr_flds_bypass[i]) ? i_tlp_hdr_pkt.tlp_th : cdm_atu_out_cfg.th[i];
                p_tlp_hdr_pkt.tlp_ph               = (cdm_atu_out_cfg.hdr_flds_bypass[i]) ? i_tlp_hdr_pkt.tlp_ph : cdm_atu_out_cfg.ph[i];
                p_tlp_hdr_pkt.tlp_st               = (cdm_atu_out_cfg.hdr_flds_bypass[i]) ? i_tlp_hdr_pkt.tlp_st : {8'h00, cdm_atu_out_cfg.st[i]};
                p_tlp_hdr_pkt.tlp_tag              = { i_tlp_hdr_pkt.tlp_tag[13:10], i_tlp_hdr_pkt.tlp_tag[9:8], (cdm_atu_out_cfg.tag_substitute_en[i] ? cdm_atu_out_cfg.tag[i][7:0] : i_tlp_hdr_pkt.tlp_tag[7:0])};
                
                p_tlp_hdr_pkt.tlp_fn[PF_WD-1:0]    = (cdm_atu_out_cfg.func_bypass[i]) ? i_tlp_hdr_pkt.tlp_fn[PF_WD-1:0] : cdm_atu_out_cfg.func_num[i];

                if(cdm_atu_out_cfg.incr_rgn_size[i] && !cdm_atu_out_cfg.hdr_substitute_en[i])begin
                    p_tlp_hdr_pkt.tlp_addr[32+ATU_UPR_LMT_WD_MDFD +: 32-ATU_UPR_LMT_WD_MDFD] = cdm_atu_out_cfg.upr_trgt[i][ATU_UPR_LMT_WD_MDFD +: 32-ATU_UPR_LMT_WD_MDFD];
                    {p_tlp_hdr_pkt.tlp_addr[32+:ATU_UPR_LMT_WD], p_tlp_hdr_pkt.tlp_addr[31-:ATU_REG_WD]}     = atu_pkt.offset_plus_lwr_trgt_for_incr_rgn_size[i];
                end else
                begin
                    p_tlp_hdr_pkt.tlp_addr[32 +: 32]       = cdm_atu_out_cfg.upr_trgt[i];
                    p_tlp_hdr_pkt.tlp_addr[31-:ATU_REG_WD] = cdm_atu_out_cfg.hdr_substitute_en[i] ? cdm_atu_out_cfg.lwr_trgt[i] : atu_pkt.offset_plus_lwr_trgt[i];
                end
                
                p_tlp_hdr_pkt.tlp_addr[0 +: 32-ATU_REG_WD] = cdm_atu_out_cfg.hdr_substitute_en[i] ? cdm_atu_out_cfg.lwr_trgt_lwr[i] : atu_pkt.offset[i][0+:32-ATU_REG_WD];
                
                // Shift mode. This is mostly useful for configuration transactions and matches the PCIe enhanced configuration mechanism from section 7.2.2 of the PCIe base spec.
                // Bits 27:12 of the incoming address are shifted to 31:16 to form the Bus/Device/Function number in the outgoing CFG TLP.
                // This overrides any other address translation, unless ATU_REG_WD is > 20 and the memory region is < 4k in size(the upper 32 bits
                // can still be translated but this is not useful for Cfg transactions)
                p_tlp_hdr_pkt.tlp_addr[31:12] = (cdm_atu_out_cfg.shift[i]) ? {i_tlp_hdr_pkt.tlp_addr[27:12],4'b0000} : p_tlp_hdr_pkt.tlp_addr[31:12];

                // Re-Formating the TLP FMT/TYPE if necessary
                o_tlp_hdr_pkt = p_tlp_hdr_pkt;
                o_tlp_hdr_pkt.tlp_fmt = f_fmt_convert(mode, p_tlp_hdr_pkt, inhibit_pyld);
            end // match[i]
        end
    end
    
end endgenerate

function automatic logic [1:0] f_fmt_convert (
  input mode_e        mode,
  input tlp_hdr_pkt_s tlp_hdr_pkt,
  input logic         inhibit_pyld
);
  // Param Defines
  localparam MRD32      = `MRD32;
  localparam FMMRD32    = `FLIT_MRD32;
  localparam MRDLK32    = `MRDLK32;
  localparam MWR32      = `MWR32;
  localparam DMWR32     = `DMWR32;
  localparam FETCHADD32 = `FETCHADD32;
  localparam SWAP32     = `SWAP32;
  localparam CAS32      = `CAS32;
  localparam MRD64      = `MRD64;
  localparam MRDLK64    = `MRDLK64;
  localparam MWR64      = `MWR64;
  localparam DMWR64     = `DMWR64;
  localparam FETCHADD64 = `FETCHADD64;
  localparam SWAP64     = `SWAP64;
  localparam CAS64      = `CAS64;
  localparam MSG_4      = `MSG_4;
  localparam MSGD_4     = `MSGD_4;
  localparam MSG_AS_4   = `MSG_AS_4;
  localparam MSGD_AS_4  = `MSGD_AS_4;

  // Logic Defines
  logic addr_present;
  logic addr_64;
  logic fmt_4dw;
  logic fmt_payload;

  // Assign Input to Output
  //f_fmt_convert = tlp_hdr_pkt;
 
  // Determine Address Type 
  addr_present  = |tlp_hdr_pkt.tlp_addr;
  addr_64       = |tlp_hdr_pkt.tlp_addr[63:32];
  fmt_4dw       = 0; // Default to 0
  fmt_payload   = inhibit_pyld ? 1'b0 : tlp_hdr_pkt.tlp_fmt[1];


  // Predict Type 32 bit Addresses
  if (tlp_hdr_pkt.tlp_type      == MRD32[4:0]      & addr_64 ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type      == MRDLK32[4:0]    & addr_64 ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type      == MWR32[4:0]      & addr_64 ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type      == DMWR32[4:0]     & addr_64 ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type      == FETCHADD32[4:0] & addr_64 ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type      == SWAP32[4:0]     & addr_64 ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type      == CAS32[4:0]      & addr_64 ) fmt_4dw = 1'b1;
  // Predict Type 64 bit Addresses
  if (tlp_hdr_pkt.tlp_type      == MRD64[4:0]      & addr_64 ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type      == MRDLK64[4:0]    & addr_64 ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type      == MWR64[4:0]      & addr_64 ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type      == DMWR64[4:0]     & addr_64 ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type      == FETCHADD64[4:0] & addr_64 ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type      == SWAP64[4:0]     & addr_64 ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type      == CAS64[4:0]      & addr_64 ) fmt_4dw = 1'b1;
  // Predict Type Messages
  if (tlp_hdr_pkt.tlp_type[4:3] == MSG_4[1:0]                ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type[4:3] == MSGD_4[1:0]               ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type[4:3] == MSG_AS_4[1:0]             ) fmt_4dw = 1'b1;
  if (tlp_hdr_pkt.tlp_type[4:3] == MSGD_AS_4[1:0]            ) fmt_4dw = 1'b1;

  f_fmt_convert = {fmt_payload, fmt_4dw};
endfunction // f_fmt_convert

endmodule
