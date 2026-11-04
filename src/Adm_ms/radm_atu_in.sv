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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_atu_in.sv#4 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- inbound translation unit. The address|bar from the radm is examined to
// --- determine if it matches any of the memory regions defined by the cdm
// --- inputs from the port logic register. If so the other attributes are
// --- compared to those required for the region, if enabled and the address of
// --- the TLP is modified
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_atu_in
  
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::PF_WD;
  import radm_ms_pkg::ATU_IN_REGIONS;
  import radm_ms_pkg::ATU_IN_MIN1;
  import radm_ms_pkg::DW_LEN_WD;
  import radm_ms_pkg::radm_cfg_atu_s;
  import radm_ms_pkg::radm_flt_atu_s;
  import radm_ms_pkg::radm_atu_cpipe_s;
  import radm_ms_pkg::ATU_CPIPE_PROT_WD ;
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::ATTR_WD;
  import DWC_pcie_ctl_pkg::VF_WD;
   import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ATU_UPR_LMT_WD;
  import DWC_pcie_ctl_pkg::ATU_UPR_LMT_WD_MDFD;
  import DWC_pcie_ctl_pkg::ATU_BASE_WD;
  import DWC_pcie_ctl_pkg::ATU_REG_WD;
  import DWC_pcie_ctl_pkg::ATU_REG_LWR_WD;



  
                    (
    // ------------ Inputs ---------------
    input                                     core_clk,
    input                                     radm_clk_ug,
    input                                     non_sticky_rst_n,

    // ATU inbound Region controls            

    // TLP information from RADM
    input  radm_flt_atu_s                     radm_flt_atu_in, 
    input                                     halt_in,
    input                                     radm_outq_pkt_hv,
    input  radm_cfg_atu_s                     radm_cfg_atu_in

    // Address translation outputs to RADM
      ,
      output logic [63:0]                     rtranslated_addr_in_d,
      output logic [1:0]                      rtranslated_err_in_d
    ,
    output logic                              atu_in_tlp_xlate
    ,
    input                                     radm_outq_pkt_eot,
  
    output logic [$clog2(ATU_IN_MIN1)-1:0]    atu_in_sloc_region,
    output logic                              atu_in_sloc_match,
    output logic                              atu_in_cbuf_err
    ,output ras_dp_err_log_t                  ras_dp_err_log
    ,output logic                             radm_atu_outq_pkt_hv_d
    ,input  ras_dp_err_inj_t                  ras_dp_err_inj
  );

  parameter CPIPE_EN = 0;
  parameter RAS_DP_PROT_CHK_ID_BASE  = 0;
  
  localparam CPIPE_DELAY = (CPIPE_EN) ? 1 : 0;
  localparam NF_WD       = NF > 1 ? $clog2(NF) : 1;
  localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
  localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
  localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
  localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;

// ----------------------------------- Signal declaration -----------------------------------
  logic    [63:0]                       int_translated_addr_in_d;
  logic    [1:0]                        int_translated_err_in_d;    // 00 -- SC,
                                                                    // 01 -- UR,
                                                                    // 10 -- CA.
                                                                    // 11 -- Undef
  logic                                 int_tlp_xlate;              // Asserted when translation occurs while atu_reg_in_single_addr_loc_en is active.
  logic [ATU_IN_MIN1-1:0][63:0]         trgt_addr_v;

  // Internal TLP information from RADM
  logic  [63:0]                         int_addr_out;
  logic  [63:0]                         int_addr_out_d;
  logic  [4:0]                          int_type_out;
  logic  [2:0]                          int_bar_out;
  logic                                 int_rombar_out;
  logic  [2:0]                          int_tc_out;
  logic                                 int_td_out;
  logic  [ATTR_WD-1:0]                  int_attr_out;
  logic  [DW_LEN_WD-1:0]                int_dw_len_out;
    logic  [1:0]                        int_at_out;
  logic  [7:0]                          int_func_out;
  logic  [7:0]                          int_msgcode_out;
    logic                               int_th_out;
    logic  [1:0]                        int_ph_out;
    logic  [7:0]                        int_st_out;
    logic  [ATU_IN_MIN1-1:0]            r_sloc_match;
    logic  [ATU_IN_MIN1-1:0]            r_sloc_match_d;
    logic  [ATU_IN_MIN1-1:0]            int_sloc_match;
    logic  [(64*ATU_IN_MIN1)-1:0]       cbuf_start_addr;
    logic  [(64*ATU_IN_MIN1)-1:0]       cbuf_end_addr;
    logic  [(65*ATU_IN_MIN1)-1:0]       cbuf_addr;
    logic  [(64*ATU_IN_MIN1)-1:0]       int_cbuf_addr;
    logic  [(64*ATU_IN_MIN1)-1:0]       r_cbuf_addr;
    logic  [ATU_IN_MIN1-1:0]            cbuf_enabled;
    logic  [ATU_IN_MIN1-1:0]            r_cbuf_enabled, r_cbuf_enabled_d;
    logic  [ATU_IN_MIN1-1:0]            cbuf_enabled_restart;
    logic  [ATU_IN_MIN1-1:0]            int_cbuf_err;
    logic  [ATU_IN_MIN1-1:0]            r_cbuf_err_d;
    logic  [ATU_IN_MIN1-1:0]            r_cbuf_err;
    logic  [(64*ATU_IN_MIN1)-1:0]       cbuf_window_size;
    logic  [ATU_IN_MIN1-1:0]            cbuf_max_addr_reached;
    logic  [(16*ATU_IN_MIN1)-1:0]       cbuf_increment;
    logic  [(13*ATU_IN_MIN1)-1:0]       received_vdm_payload_size;
    logic  [ATU_IN_MIN1-1:0]            decode_sloc_match;
    logic  [ATU_IN_MIN1-1:0]            decode_cbuf_err;
    logic                               int_eot;
    logic                               int_eot_d;
    // greater than the programmed Circular Buffer Increment size (CBUF_INCR) for Single Location Address translation

  logic [ATU_REG_LWR_WD-1:0]            lwr_zeros;                  // width of read only register bits e.g. LWR_TARGET_HW.
  logic [ATU_REG_LWR_WD-1:0]            lwr_ones;                   // width of read only register bits e.g. LIMIT_HW
  assign lwr_zeros                  = 0;                                             // read only register bits are always 0.
  assign lwr_ones                   = {ATU_REG_LWR_WD{1'b1}};                         // read only register bits are always 0.

  always_comb begin
    int_addr_out          =  radm_flt_atu_in.r_addr_out;
    int_type_out          =  radm_flt_atu_in.r_type_out;
    int_bar_out           =  radm_flt_atu_in.r_bar_out;
    int_rombar_out        =  radm_flt_atu_in.r_rombar_out;
    int_tc_out            =  radm_flt_atu_in.r_tc_out;
    int_td_out            =  radm_flt_atu_in.r_td_out;
    int_attr_out          =  radm_flt_atu_in.r_attr_out;
    int_dw_len_out        =  radm_flt_atu_in.r_dw_len_out;
      int_at_out          =  radm_flt_atu_in.r_at_out;
    int_func_out          =  radm_flt_atu_in.r_func_out;
    int_msgcode_out       =  radm_flt_atu_in.r_msgcode_out;
      int_th_out          =  radm_flt_atu_in.r_th_out;
      int_ph_out          =  radm_flt_atu_in.r_ph_out;
      int_st_out          =  radm_flt_atu_in.r_st_out;
    int_eot               = radm_outq_pkt_eot & ~halt_in;
  end

  // For BAR match mode we need to get the offset address by using the BAR mask
  // Select the BAR mask based on the active function and active BAR
  // Mask the upper bits of the input address so they can be replaced later with
  // the target address from the matching region
  logic [63:0]                  atu_bar_mask;
  logic [63:0]                  cfg_bar0_mask_sel;
  logic [31:0]                  cfg_bar1_mask_sel;
  logic [63:0]                  cfg_bar2_mask_sel;
  logic [31:0]                  cfg_bar3_mask_sel;
  logic [63:0]                  cfg_bar4_mask_sel;
  logic [31:0]                  cfg_bar5_mask_sel;
  logic [31:0]                  cfg_rom_mask_sel;
  logic [63:0]                  int_addr_masked;
  logic [63:0]                  atu_bar_mask_d;

  logic [NF-1:0][63:0]          cfg_bar0_mask_packed_arr;
  logic [NF-1:0][31:0]          cfg_bar1_mask_packed_arr;
  logic [NF-1:0][63:0]          cfg_bar2_mask_packed_arr;
  logic [NF-1:0][31:0]          cfg_bar3_mask_packed_arr;
  logic [NF-1:0][63:0]          cfg_bar4_mask_packed_arr;
  logic [NF-1:0][31:0]          cfg_bar5_mask_packed_arr;
  logic [NF-1:0][31:0]          cfg_rom_mask_packed_arr;

  always_comb begin  
    for (int j = 0; j < NF; j = j + 1) begin
      cfg_bar0_mask_packed_arr[j] = radm_cfg_atu_in.cfg_bar0_mask[64*j +: 64];
      cfg_bar1_mask_packed_arr[j] = radm_cfg_atu_in.cfg_bar1_mask[32*j +: 32];
      cfg_bar2_mask_packed_arr[j] = radm_cfg_atu_in.cfg_bar2_mask[64*j +: 64];
      cfg_bar3_mask_packed_arr[j] = radm_cfg_atu_in.cfg_bar3_mask[32*j +: 32];
      cfg_bar4_mask_packed_arr[j] = radm_cfg_atu_in.cfg_bar4_mask[64*j +: 64];
      cfg_bar5_mask_packed_arr[j] = radm_cfg_atu_in.cfg_bar5_mask[32*j +: 32];
      cfg_rom_mask_packed_arr[j]  = radm_cfg_atu_in.cfg_rom_mask[32*j +: 32];
    end
  end

  always_comb begin : bar_mask_select
    cfg_bar0_mask_sel             = 0;
    cfg_bar1_mask_sel             = 0;
    cfg_bar2_mask_sel             = 0;
    cfg_bar3_mask_sel             = 0;
    cfg_bar4_mask_sel             = 0;
    cfg_bar5_mask_sel             = 0;
    cfg_rom_mask_sel              = 0;
    atu_bar_mask                  = 0;
    // Select the active function for each BAR
    if(int_func_out < NF) begin
      cfg_bar0_mask_sel           = cfg_bar0_mask_packed_arr[int_func_out[NF_WD-1:0]];
      cfg_bar1_mask_sel           = cfg_bar1_mask_packed_arr[int_func_out[NF_WD-1:0]];
      cfg_bar2_mask_sel           = cfg_bar2_mask_packed_arr[int_func_out[NF_WD-1:0]];
      cfg_bar3_mask_sel           = cfg_bar3_mask_packed_arr[int_func_out[NF_WD-1:0]];
      cfg_bar4_mask_sel           = cfg_bar4_mask_packed_arr[int_func_out[NF_WD-1:0]];
      cfg_bar5_mask_sel           = cfg_bar5_mask_packed_arr[int_func_out[NF_WD-1:0]];
      cfg_rom_mask_sel            =  cfg_rom_mask_packed_arr[int_func_out[NF_WD-1:0]];
    end
    casez({int_rombar_out, int_bar_out})
      4'b1??? : atu_bar_mask[31:0] = cfg_rom_mask_sel;
      4'b0000 : atu_bar_mask       = cfg_bar0_mask_sel;
      4'b0001 : atu_bar_mask[31:0] = cfg_bar1_mask_sel;
      4'b0010 : atu_bar_mask       = cfg_bar2_mask_sel;
      4'b0011 : atu_bar_mask[31:0] = cfg_bar3_mask_sel;
      4'b0100 : atu_bar_mask       = cfg_bar4_mask_sel;
      4'b0101 : atu_bar_mask[31:0] = cfg_bar5_mask_sel;
      default : atu_bar_mask       = cfg_bar0_mask_sel;
    endcase
    int_addr_masked                = int_addr_out_d & atu_bar_mask_d;
  end


  // Expand atu_reg_in_func_num to width of int_func_out (8 bits)
  logic [ATU_IN_MIN1-1:0][1:0]                  int_translated_err_in_d_v;
  logic [ATU_IN_MIN1-1:0][1:0]                  int_translated_err_in;
  logic [ATU_IN_MIN1-1:0][63:0]                 int_translated_addr_in_d_v;

  logic [ATU_IN_MIN1-1:0][7:0]                  atu_reg_in_func_num_exp_v;
  logic [ATU_IN_MIN1-1:0]                       atu_upper_match_v;
  logic [ATU_IN_MIN1-1:0]                       type_match_v;
  logic [ATU_IN_MIN1-1:0]                       msg_type_match_v;
  logic [ATU_IN_MIN1-1:0]                       msg_match_v;
  logic [ATU_IN_MIN1-1:0]                       tc_match_v;
  logic [ATU_IN_MIN1-1:0]                       attr_match_v;
    logic [ATU_IN_MIN1-1:0]                     at_match_v;
  logic [ATU_IN_MIN1-1:0]                       func_match_v;
  logic [ATU_IN_MIN1-1:0]                       msgcode_match_v;
    logic [ATU_IN_MIN1-1:0]                     th_match_v;
    logic [ATU_IN_MIN1-1:0]                     ph_match_v;
    logic [ATU_IN_MIN1-1:0]                     st_match_v;
  logic [ATU_IN_MIN1-1:0]                       atu_reg_match_v;
  logic [ATU_IN_MIN1-1:0]                       addr_match_v;
  logic [ATU_IN_MIN1-1:0]                       td_match_v;
  //
  logic [ATU_IN_MIN1-1:0][31+ATU_UPR_LMT_WD:0]  addr_m_offset;
  logic [ATU_IN_MIN1-1:0][31+ATU_UPR_LMT_WD:0]  addr_m_offset_d;
  logic [ATU_IN_MIN1-1:0][63:0]                 sriov_m_trgt_addr;
  logic [ATU_IN_MIN1-1:0][63:0]                 bar_m_trgt_addr;
  logic [ATU_IN_MIN1-1:0][63:0]                 addr_m_trgt_addr;
  logic [ATU_IN_MIN1-1:0][63:0]                 bar_m_trgt_mask;
  logic [ATU_IN_MIN1-1:0]                       bar_m_mode_en;
  logic [ATU_IN_MIN1-1:0]                       sriov_m_mode_en;
  logic [ATU_IN_MIN1-1:0]                       atu_reg_match_d;
  logic                                         int_tlp_xlate_d;

  // Only generate if there is at least 1 region, be nice to linters.
  generate if(ATU_IN_REGIONS > 0) begin : gen_atu

    always_comb begin : output_decode_proc
      int_translated_err_in_d       = 0;
      int_translated_addr_in_d      = int_addr_out_d;
      atu_in_tlp_xlate              = int_tlp_xlate_d;
      for(int i = ATU_IN_REGIONS-1; i >=0; i = i - 1) begin
        if(atu_reg_match_d[i])begin
          int_translated_err_in_d   = int_translated_err_in_d_v[i];
          int_translated_addr_in_d  = int_translated_addr_in_d_v[i];
        end
      end
    end

    always_comb begin : region_match_priority_decode_proc

        int_translated_err_in     = 0;
        int_cbuf_err              = 0;
        received_vdm_payload_size = 0;
      
      // Loop down so region 0 will have highest priority
      for(int i = ATU_IN_REGIONS-1; i >=0; i = i - 1) begin
        atu_reg_in_func_num_exp_v[i] = (8)'(radm_cfg_atu_in.atu_reg_in_func_num[PF_WD*i +: PF_WD]);
        addr_match_v[i]              = 0;

        // In BAR match mode only compare lower 48 bits of MSG header
        // Useful as bits[47:32] of vendor defined message are the vendor
        // ID, bits[63:48] are routing ID for ID routed vendor messages
        // so we want to ignore routing ID but check vendor ID.
        if(radm_cfg_atu_in.atu_reg_in_bar_match[i] && radm_cfg_atu_in.atu_reg_in_type[5*i+3 +: 2] == 2'b10)
          atu_upper_match_v[i]    = int_addr_out[47:32] ==
                                    radm_cfg_atu_in.atu_reg_in_upr_base[ATU_BASE_WD*i +: 16];
          else if(radm_cfg_atu_in.atu_reg_in_incr_rgn_size[i])                              // Increased region size
            atu_upper_match_v[i]  = (ATU_UPR_LMT_WD==32) ? 1'b1 : int_addr_out[32+ATU_UPR_LMT_WD_MDFD +: 32-ATU_UPR_LMT_WD_MDFD] ==
                                                            radm_cfg_atu_in.atu_reg_in_upr_base[(ATU_BASE_WD*i)+ATU_UPR_LMT_WD_MDFD +: ATU_BASE_WD-ATU_UPR_LMT_WD_MDFD];
        else                                                          // 4 GB max region size
          atu_upper_match_v[i]    = int_addr_out[32 +: ATU_BASE_WD] ==
                                    radm_cfg_atu_in.atu_reg_in_upr_base[ATU_BASE_WD*i +: ATU_BASE_WD];

        if(radm_cfg_atu_in.atu_reg_in_bar_match[i] && radm_cfg_atu_in.atu_reg_in_type[5*i+3 +: 2] != 2'b10) begin
          // In BAR match mode any CFG0 will match, useful as any received
          // cfg0 should be processed regardless of Bus number.
          if(radm_cfg_atu_in.atu_reg_in_type[5*i +: 5] == 5'b00100) begin
            addr_match_v[i]       = radm_cfg_atu_in.atu_reg_in_en[i];
          end else begin
            if(radm_cfg_atu_in.atu_reg_in_bar_num[3*i +: 3] == 3'h6)
              addr_match_v[i]     = radm_cfg_atu_in.atu_reg_in_en[i] && radm_cfg_atu_in.atu_reg_in_invert[i] ^
                                    int_rombar_out;
            else
              addr_match_v[i]     = radm_cfg_atu_in.atu_reg_in_en[i] && radm_cfg_atu_in.atu_reg_in_invert[i] ^
                                    radm_cfg_atu_in.atu_reg_in_bar_num[3*i +: 3] == int_bar_out;
          end
          // Compare address to base and limit to find out if we are in the
          // range. Invert bit changes to check that we are outside the range
        end else if(radm_cfg_atu_in.atu_reg_in_incr_rgn_size[i]) begin                    // Increased region size
          addr_match_v[i] = radm_cfg_atu_in.atu_reg_in_en[i] && radm_cfg_atu_in.atu_reg_in_invert[i] ^
                            (atu_upper_match_v[i] && int_addr_out[31+ATU_UPR_LMT_WD -: ATU_REG_WD+ATU_UPR_LMT_WD] >=
                            {radm_cfg_atu_in.atu_reg_in_upr_base[ATU_BASE_WD*i +: ATU_UPR_LMT_WD], radm_cfg_atu_in.atu_reg_in_base[ATU_REG_WD*i +: ATU_REG_WD]} &&
                            int_addr_out[31+ATU_UPR_LMT_WD -: ATU_REG_WD+ATU_UPR_LMT_WD] <=
                            {radm_cfg_atu_in.atu_reg_in_uppr_limit[ATU_UPR_LMT_WD*i +: ATU_UPR_LMT_WD], radm_cfg_atu_in.atu_reg_in_limit[ATU_REG_WD*i +: ATU_REG_WD]});
        end else begin                                                // 4 GB max region size
          addr_match_v[i] = radm_cfg_atu_in.atu_reg_in_en[i] && radm_cfg_atu_in.atu_reg_in_invert[i] ^
                            (atu_upper_match_v[i] && int_addr_out[31 -: ATU_REG_WD] >=
                            radm_cfg_atu_in.atu_reg_in_base[ATU_REG_WD*i +: ATU_REG_WD] &&
                            int_addr_out[31 -: ATU_REG_WD] <=
                            radm_cfg_atu_in.atu_reg_in_limit[ATU_REG_WD*i +: ATU_REG_WD]);
        end
        // Type matching. Match when the type from the RADM is the same as
        // the type defined for the region. In fuzzy match mode match any
        // type of message or any type of config as appropriate
        type_match_v[i] = radm_cfg_atu_in.atu_reg_in_fuzzy[i] ?
                          radm_cfg_atu_in.atu_reg_in_type[5*i+1 +: 4] == 4'b0000 && // Memory
                          int_type_out[4:1] == 4'b0000 ||
                          radm_cfg_atu_in.atu_reg_in_type[5*i+1 +: 4] == 4'b0010 && // CFG
                          int_type_out[4:1] == 4'b0010 ||
                          radm_cfg_atu_in.atu_reg_in_type[5*i+2 +: 3] == 3'b011  && // Atomic
                          int_type_out[4:2] == 3'b011  ||
                          radm_cfg_atu_in.atu_reg_in_type[5*i+3 +: 2] == 2'b10 && // MSG
                          int_type_out[4:3] == 2'b10 :
                          radm_cfg_atu_in.atu_reg_in_type[5*i +: 5] == int_type_out;
        msg_type_match_v[i] = radm_cfg_atu_in.atu_reg_in_fuzzy[i] ?  radm_cfg_atu_in.atu_reg_in_type[5*i+3 +: 2] == 2'b10 && int_type_out[4:3] == 2'b10 :                     // Match any Msg
                                                                     (radm_cfg_atu_in.atu_reg_in_type[5*i+3 +: 2] == 2'b10) && (int_type_out[4:3] == 2'b10) && (radm_cfg_atu_in.atu_reg_in_type[5*i +: 3] == int_type_out[2:0]);  // Match Msg with specified routing mechanism
        msg_match_v[i] = (radm_cfg_atu_in.atu_reg_in_single_addr_loc_en[i] && radm_cfg_atu_in.atu_reg_in_msg_type_match_mode[i]) ? msg_type_match_v[i] : 1'b0;

        // Other attributes always match when disabled, equivalent to making
        // them a don't care
        tc_match_v[i]   = radm_cfg_atu_in.atu_reg_in_tc_match_en[i] ?
                          radm_cfg_atu_in.atu_reg_in_tc[3*i +: 3] == int_tc_out : 1'b1;
        td_match_v[i]   = radm_cfg_atu_in.atu_reg_in_td_match_en[i] ?
                          radm_cfg_atu_in.atu_reg_in_td[i] == int_td_out : 1'b1;
        attr_match_v[i] = radm_cfg_atu_in.atu_reg_in_attr_match_en[i] ?
                          radm_cfg_atu_in.atu_reg_in_attr[ATTR_WD*i +: ATTR_WD] == int_attr_out : 1'b1;
          at_match_v[i] = radm_cfg_atu_in.atu_reg_in_at_match_en[i] ?
                          radm_cfg_atu_in.atu_reg_in_at[2*i +: 2] == int_at_out : 1'b1;
        if(radm_cfg_atu_in.atu_reg_in_type[5*i+1 +: 4] == 4'b0010)// CFG function matching
          // checks against the RID in
          // the header, not the BAR and
          // function matching logic
          func_match_v[i] = radm_cfg_atu_in.atu_reg_in_func_match_en[i] ?
                            atu_reg_in_func_num_exp_v[i][2:0] == int_addr_out[18:16] :
                            1'b1;
        else begin
          func_match_v[i]   = 0;
          if (radm_cfg_atu_in.atu_reg_in_func_match_en[i] == 0) begin
            func_match_v[i] = 1;
          end
          else if(atu_reg_in_func_num_exp_v[i] == int_func_out) begin
            func_match_v[i] = 1;
          end
        end

        // MSG code field is overloaded with ST field. check only applies if the type is MSG
        msgcode_match_v[i] = (radm_cfg_atu_in.atu_reg_in_type[5*i+3 +: 2] == 2'b10 && radm_cfg_atu_in.atu_reg_in_msgcode_match_en[i]) ?
                             radm_cfg_atu_in.atu_reg_in_msg_code[8*i +: 8] == int_msgcode_out : 1'b1;
          // TPH matches are specific to Mem and Atomic transactions(lock not supported)
          th_match_v[i] = ((radm_cfg_atu_in.atu_reg_in_type[5*i +: 5] == 5'b0 || radm_cfg_atu_in.atu_reg_in_type[5*i+2 +: 3] == 3'b011) && radm_cfg_atu_in.atu_reg_in_th_match_en[i]) ?
                          radm_cfg_atu_in.atu_reg_in_th[i] == int_th_out : 1'b1;
          ph_match_v[i] = ((radm_cfg_atu_in.atu_reg_in_type[5*i +: 5] == 5'b0 || radm_cfg_atu_in.atu_reg_in_type[5*i+2 +: 3] == 3'b011) && radm_cfg_atu_in.atu_reg_in_ph_match_en[i]) ?
                          radm_cfg_atu_in.atu_reg_in_ph[2*i +: 2] == int_ph_out : 1'b1;
          // ST Match overloads msgcode match. Only applies if the type is MEM or Atomic
          st_match_v[i] = ((radm_cfg_atu_in.atu_reg_in_type[5*i +: 5] == 5'b0 || radm_cfg_atu_in.atu_reg_in_type[5*i+2 +: 3] == 3'b011) && radm_cfg_atu_in.atu_reg_in_st_match_en[i]) ?
                          radm_cfg_atu_in.atu_reg_in_st[8*i +: 8] == int_st_out : 1'b1;
        // To have a match everything must match here.
        // addr_match is not relevant if msg_match is true;
        atu_reg_match_v[i] = (addr_match_v[i] || msg_match_v[i]) && type_match_v[i] && tc_match_v[i] && td_match_v[i] &&
                             attr_match_v[i] && at_match_v[i] && func_match_v[i]
 && msgcode_match_v[i]
                                 && th_match_v[i] && ph_match_v[i] && st_match_v[i]
                              ;

         // -------- Circular Buffer for single target address location feature ------------------------------------------------------------------------------
         received_vdm_payload_size[13*i +: 13] = (4*int_dw_len_out) + 4'h8; // VDM payload size is length field in bytes + upper 8 bytes of header.

         if (cbuf_enabled[i])  begin
           if (atu_reg_match_v[i])  begin
             int_cbuf_err[i] = {3'h0, received_vdm_payload_size[13*i +: 13]} > cbuf_increment[16*i +: 16] ? 1'b1 : 1'b0;
           end
         end else begin
           int_cbuf_err[i] = 1'b0;
         end //if (cbuf_enabled[i])...

         // -----------------------------------------------------------------------------------------------------------------------------------------------

       // Response Code
       int_translated_err_in[i] = radm_cfg_atu_in.atu_reg_in_rsp_code[2*i +: 2];
       // Address Translation

      end  //for(i = ATU_IN_REGIONS-1....
    end  //region_match_priority_decode
    
    always_comb begin : match_mode_detect_proc
      for(int i = ATU_IN_REGIONS-1; i >=0; i = i - 1) begin
        bar_m_mode_en[i]   = radm_cfg_atu_in.atu_reg_in_bar_match[i] && (radm_cfg_atu_in.atu_reg_in_type[i*5+3 +: 2] != 2'b10);
        sriov_m_mode_en[i] = 1'b0;
      end
    end
   
    always_comb begin : sloc_match_proc
      int_sloc_match = 0;
      int_tlp_xlate  = 0;
      for(int i = ATU_IN_REGIONS-1; i >=0; i = i - 1) begin
        if (radm_cfg_atu_in.atu_reg_in_single_addr_loc_en[i]) begin
          int_tlp_xlate = (!atu_reg_match_v[i]) ? int_tlp_xlate : 1'b1;
            int_sloc_match[i] = (!sriov_m_mode_en[i]) & atu_reg_match_v[i];
        end
      end
    end

    always_comb begin : trgt_addr_decode_proc
      for(int i = ATU_IN_REGIONS-1; i >=0; i = i - 1) begin
        casez({sriov_m_mode_en[i],bar_m_mode_en[i]})
          2'b1?   : trgt_addr_v[i] = sriov_m_trgt_addr[i];
          2'b01   : trgt_addr_v[i] = bar_m_trgt_addr[i];
          default : trgt_addr_v[i] = addr_m_trgt_addr[i];
        endcase
        int_translated_addr_in_d_v[i] = trgt_addr_v[i];
        if((!radm_cfg_atu_in.atu_reg_in_single_addr_loc_en[i]) & radm_cfg_atu_in.atu_reg_in_shift[i])
         int_translated_addr_in_d_v[i][27:12] = int_addr_out_d[31:16];
      end
    end

    // one clk cycle delay added if CPIPE_DELAY is enabled, else 0 delay
    localparam CPIPE_WIDTH = (1 + (ATU_IN_MIN1) + (2*ATU_IN_MIN1) + $bits(int_translated_err_in_d_v) + $bits(int_addr_out));

    delay_n_w_enable
    
      #(.N(CPIPE_DELAY), .WD(CPIPE_WIDTH)) 
      u_cpipe_delay (
        .clk        (core_clk),
        .rst_n      (non_sticky_rst_n),
        .clear      (1'b0),
        .en         (radm_outq_pkt_hv),
        .din        ({int_tlp_xlate, atu_reg_match_v, 
                      r_sloc_match, r_cbuf_err,
                      int_addr_out, int_translated_err_in}),
        .dout       ({int_tlp_xlate_d, atu_reg_match_d, 
                      r_sloc_match_d, r_cbuf_err_d,
                      int_addr_out_d, int_translated_err_in_d_v})
    );

    delay_n
    
      #(.N(1), .WD(1)) 
      u_eot_delay (
        .clk        (core_clk),
        .rst_n      (non_sticky_rst_n),
        .clear      (1'b0),
        .din        (int_eot),
        .dout       (int_eot_d)
    );


      assign sriov_m_trgt_addr   = 0;

      delay_n_w_enable
      
      #(.N(CPIPE_DELAY), .WD($bits(atu_bar_mask))) 
      u_bar_addr_mask_delay (
        .clk        (core_clk),
        .rst_n      (non_sticky_rst_n),
        .clear      (1'b0),
        .en         (radm_outq_pkt_hv),
        .din        (atu_bar_mask),
        .dout       (atu_bar_mask_d)
    );  
      
  always_comb begin : bar_match_addr_proc
    bar_m_trgt_mask    = 0;
    for(int i = ATU_IN_REGIONS-1; i >=0; i = i - 1) begin
      if((!radm_cfg_atu_in.atu_reg_in_single_addr_loc_en[i]) && (radm_cfg_atu_in.atu_reg_in_type[i*5 +: 5] == 5'b00100)) begin
        // CFG0 BAR Match Mode. Save the lower 12 bits(register
        // number field) and take the rest of the translation
        // directly from the target address
        bar_m_trgt_mask[i][32 +: ATU_BASE_WD] =
          radm_cfg_atu_in.atu_reg_in_upr_trgt[ATU_BASE_WD*i +: ATU_BASE_WD];
        bar_m_trgt_mask[i][31 -: ATU_REG_WD] =
          radm_cfg_atu_in.atu_reg_in_lwr_trgt[ATU_REG_WD*i +: ATU_REG_WD];
        bar_m_trgt_addr[i] = bar_m_trgt_mask[i] | {52'b0,int_addr_out_d[11:0]};
      end else begin
        // BAR Match Mode. Get the BAR mask and apply it to the
        // target address. target address supplies the translated
        // address above the mask int_addr_masked, generated above
        // supplies the address below the mask
        bar_m_trgt_mask[i][32 +: ATU_BASE_WD] =
          radm_cfg_atu_in.atu_reg_in_upr_trgt[ATU_BASE_WD*i +: ATU_BASE_WD] &
          ~atu_bar_mask_d[32 +: ATU_BASE_WD];
        bar_m_trgt_mask[i][31 -: ATU_REG_WD] =
          radm_cfg_atu_in.atu_reg_in_lwr_trgt[ATU_REG_WD*i +: ATU_REG_WD] &
          ~atu_bar_mask_d[31 -: ATU_REG_WD];
        if(radm_cfg_atu_in.atu_reg_in_single_addr_loc_en[i]) begin 
            bar_m_trgt_addr[i]     = r_cbuf_addr[64*i +: 64]; 
        end else begin
          bar_m_trgt_addr[i] = (bar_m_trgt_mask[i] | int_addr_masked);
        end
      end
    end
  end
  
      delay_n_w_enable
      
      #(.N(0), .WD($bits(addr_m_offset))) 
      u_addr_offset_delay (
        .clk        (core_clk),
        .rst_n      (non_sticky_rst_n),
        .clear      (1'b0),
        .en         (radm_outq_pkt_hv),
        .din        (addr_m_offset),
        .dout       (addr_m_offset_d)
    );  
  
    // Address(RC) Match mode
    // get offset within region.
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ: This logic is subtracting unsigned partial address offsets. There is no borrow to be
    // considered. An overflow in the calculation here is intended to truncate.
    always_comb begin
      addr_m_offset       = 0;
      for(int i = ATU_IN_REGIONS-1; i >=0; i = i - 1) begin
          if(radm_cfg_atu_in.atu_reg_in_incr_rgn_size[i]) begin                        // Increased region size
            addr_m_offset[i][31+ATU_UPR_LMT_WD -: ATU_REG_WD+ATU_UPR_LMT_WD] = int_addr_out_d[31+ ATU_UPR_LMT_WD -: ATU_REG_WD+ ATU_UPR_LMT_WD] -
            {radm_cfg_atu_in.atu_reg_in_upr_base[32*i +: ATU_UPR_LMT_WD], radm_cfg_atu_in.atu_reg_in_base[ATU_REG_WD*i +: ATU_REG_WD]};
          end else begin
        addr_m_offset[i][31 -: ATU_REG_WD] = int_addr_out_d[31 -: ATU_REG_WD] -
        radm_cfg_atu_in.atu_reg_in_base[ATU_REG_WD*i +: ATU_REG_WD];
          end
        // spyglass enable_block W164a

        addr_m_offset[i][0 +: 32-ATU_REG_WD] = int_addr_out_d[0 +: 32-ATU_REG_WD];

        if(radm_cfg_atu_in.atu_reg_in_single_addr_loc_en[i]) begin      // translate to a single address locaton only
            addr_m_trgt_addr[i]       = r_cbuf_addr[64*i +: 64];
        end else begin
          // Get target address. Lower bits are discarded to be replaced
          // by the offset within the region The upper target address is
          // never part is taken directly The middle bits are the
          // offset. Bits below 32-ATU_REG_WD are always 0
            if(radm_cfg_atu_in.atu_reg_in_incr_rgn_size[i]) begin                        // Increased region size
              addr_m_trgt_addr[i][32+ATU_UPR_LMT_WD_MDFD +: ATU_BASE_WD-ATU_UPR_LMT_WD_MDFD] = 
                radm_cfg_atu_in.atu_reg_in_upr_trgt[(ATU_BASE_WD*i)+ATU_UPR_LMT_WD_MDFD +: ATU_BASE_WD-ATU_UPR_LMT_WD_MDFD];
              // spyglass disable_block W164a
              // SMD: Identifies assignments in which the LHS width is less than the RHS width
              // SJ: This logic is adding unsigned partial address offsets. There is no carry to be
              // considered. An overflow in the calculation here is intended to truncate.
              {addr_m_trgt_addr[i][32 +: ATU_UPR_LMT_WD],addr_m_trgt_addr[i][31 -: ATU_REG_WD]}  = 
                  {radm_cfg_atu_in.atu_reg_in_upr_trgt[ATU_BASE_WD*i +: ATU_UPR_LMT_WD], radm_cfg_atu_in.atu_reg_in_lwr_trgt[ATU_REG_WD*i +: ATU_REG_WD]} + 
                  {addr_m_offset_d[i][32 +: ATU_UPR_LMT_WD],addr_m_offset_d[i][31 -: ATU_REG_WD]};
              // spyglass enable_block W164a
            end else begin
          addr_m_trgt_addr[i][32 +: ATU_BASE_WD] = radm_cfg_atu_in.atu_reg_in_upr_trgt[ATU_BASE_WD*i +: ATU_BASE_WD];
          // spyglass disable_block W164a
          // SMD: Identifies assignments in which the LHS width is less than the RHS width
          // SJ: This logic is adding unsigned partial address offsets. There is no carry to be
          // considered. An overflow in the calculation here is intended to truncate.
          addr_m_trgt_addr[i][31 -: ATU_REG_WD] =
            radm_cfg_atu_in.atu_reg_in_lwr_trgt[ATU_REG_WD*i +: ATU_REG_WD] +
            addr_m_offset_d[i][31 -: ATU_REG_WD];
          // spyglass enable_block W164a
            end
          addr_m_trgt_addr[i][0 +: 32-ATU_REG_WD] = addr_m_offset_d[i][0 +: 32-ATU_REG_WD];
        end
       end
    end

    end else begin : gen_no_atu_in // ATU_IN_REGIONS <= 0
    always_comb begin
      int_translated_addr_in_d    = int_addr_out;
      int_translated_err_in_d     = 0;
      int_tlp_xlate               = 0;
        int_sloc_match            = 0;
        int_cbuf_err              = 0;
    end
  end
  endgenerate  //gen_atu

  always_comb begin
      rtranslated_addr_in_d = int_translated_addr_in_d;
      rtranslated_err_in_d  = int_translated_err_in_d;
      r_sloc_match        = decode_sloc_match;
      r_cbuf_err          = decode_cbuf_err & decode_sloc_match;
  end

    // -------- Circular Buffer for single target address location feature ------------------------------------------------------------------------------
    always_comb begin
      integer i;
      int_cbuf_addr = 0;
      cbuf_enabled = 0;
      for(i = ATU_IN_REGIONS-1; i >=0; i = i - 1) begin
        cbuf_increment[16*i +: 16]  = decode_cbuf_incr(radm_cfg_atu_in.atu_reg_in_cbuf_incr[4*i +: 4]);
        cbuf_enabled[i]             = |radm_cfg_atu_in.atu_reg_in_cbuf_incr[4*i +: 4] ? 1'b1 : 1'b0;
        cbuf_enabled_restart[i]     = r_cbuf_enabled[i] & ~r_cbuf_enabled_d[i];
        cbuf_end_addr[64*i +: 64]   = {radm_cfg_atu_in.atu_reg_in_upr_trgt[ATU_BASE_WD*i +: ATU_BASE_WD], radm_cfg_atu_in.atu_reg_in_limit[ATU_REG_WD*i +: ATU_REG_WD], lwr_ones};

        if(radm_cfg_atu_in.atu_reg_in_bar_match[i]) begin
          cbuf_start_addr[64*i +: 64] = {radm_cfg_atu_in.atu_reg_in_upr_trgt[ATU_BASE_WD*i +: ATU_BASE_WD], radm_cfg_atu_in.atu_reg_in_lwr_trgt[ATU_REG_WD*i +: ATU_REG_WD], lwr_zeros} & ~atu_bar_mask; 
        end else begin
          cbuf_start_addr[64*i +: 64] = {radm_cfg_atu_in.atu_reg_in_upr_trgt[ATU_BASE_WD*i +: ATU_BASE_WD], radm_cfg_atu_in.atu_reg_in_lwr_trgt[ATU_REG_WD*i +: ATU_REG_WD], lwr_zeros}; 
        end
        // spyglass disable_block W164a
        // SMD: Identifies assignments in which the LHS width is less than the RHS width
        // SJ: Subtraction occurs in this logic only if LHS is greater than RHS - hence, the results can only be positive and no overflow can occur.
        cbuf_window_size[64*i +: 64] =  (cbuf_end_addr[64*i +: 64] > cbuf_start_addr[64*i +: 64]) ? 
                                        (cbuf_end_addr[64*i +: 64] - cbuf_start_addr[64*i +: 64]) : 0;
        // spyglass enable_block W164a
        cbuf_max_addr_reached[i]     = (cbuf_end_addr[64*i +: 64] - r_cbuf_addr[64*i +: 64]) < {48'h0, cbuf_increment[16*i +: 16]} ? 1'b1 : 1'b0;

        if (radm_cfg_atu_in.atu_reg_in_cbuf_restart[i] || cbuf_enabled_restart[i])  begin
          // The circular buffer address pointer is restarted if CBUF_INCR is reprogrammed.
          cbuf_addr[65*i +: 65] = {1'b0, cbuf_start_addr[64*i +: 64]};
        end else if (r_sloc_match_d[i] && cbuf_max_addr_reached[i] && int_eot_d)  begin
          cbuf_addr[65*i +: 65] = {1'b0, cbuf_start_addr[64*i +: 64]};
        end else if (r_sloc_match_d[i] && int_eot_d)  begin
          cbuf_addr[65*i +: 65] = {1'b0, r_cbuf_addr[64*i +: 64]} + {49'h0, cbuf_increment[16*i +: 16]};
        end else begin
          cbuf_addr[65*i +: 65] = {1'b0, r_cbuf_addr[64*i +: 64]};
        end

        int_cbuf_addr[64*i +: 64] = cbuf_enabled[i] ? cbuf_addr[65*i +: 64] : cbuf_start_addr[64*i +: 64];


      end //for(i = ATU_IN_REGIONS-1; i >=0; i = i - 1) begin
    end //always_comb


    always_ff @(posedge radm_clk_ug or negedge non_sticky_rst_n)
      if(!non_sticky_rst_n) begin
        r_cbuf_addr       <= #`TP 0;
        r_cbuf_enabled    <= #`TP 0;
        r_cbuf_enabled_d  <= #`TP 0;
      end else begin
        r_cbuf_addr       <= #`TP int_cbuf_addr;
        r_cbuf_enabled    <= #`TP cbuf_enabled;
        r_cbuf_enabled_d  <= #`TP r_cbuf_enabled;
      end
     
    // Outputs atu_in_sloc_match and atu_in_cbuf_err are not single clock period pulses. These are valid from SoT to EoT
    assign atu_in_sloc_region = onehot_to_bin(r_sloc_match_d);
    assign atu_in_sloc_match  = (|r_sloc_match_d);
    assign atu_in_cbuf_err    = (|r_cbuf_err_d);

    // Decode atu_reg_in_cbuf_incr
    function automatic [15:0] decode_cbuf_incr;
    input [3:0] incr;
    begin
      case  (incr)
        4'b0001 : decode_cbuf_incr = 16'h0004;
        4'b0010 : decode_cbuf_incr = 16'h0008;
        4'b0011 : decode_cbuf_incr = 16'h0010;
        4'b0100 : decode_cbuf_incr = 16'h0020;
        4'b0101 : decode_cbuf_incr = 16'h0040;
        4'b0110 : decode_cbuf_incr = 16'h0080;
        4'b0111 : decode_cbuf_incr = 16'h0100;
        4'b1000 : decode_cbuf_incr = 16'h0200;
        4'b1001 : decode_cbuf_incr = 16'h0400;
        4'b1010 : decode_cbuf_incr = 16'h0800;
        4'b1011 : decode_cbuf_incr = 16'h1000;
        4'b1100 : decode_cbuf_incr = 16'h2000;
        default : decode_cbuf_incr = 16'h0000;
      endcase
    end
    endfunction

    // Pririty decode int_sloc_match; lowest matched region only is signalled.
    always_comb begin
      integer j;
      decode_cbuf_err = 0;
      for(j = ATU_IN_REGIONS-1; j >=0; j = j - 1) begin
        if (int_cbuf_err[j]) begin
          decode_cbuf_err     = 0;
          decode_cbuf_err[j]  = 1'b1;
        end
      end
    end

    always_comb begin
      integer k;
      decode_sloc_match = 0;
      for(k = ATU_IN_REGIONS-1; k >=0; k = k - 1) begin
        if (int_sloc_match[k]) begin
          decode_sloc_match     = 0;
          decode_sloc_match[k]  = 1'b1;
        end
      end
    end

// convert one-hot to binary
function automatic [$clog2(ATU_IN_MIN1)-1:0] onehot_to_bin(input [ATU_IN_MIN1-1:0] onehot_data);
  integer i;
  logic [31:0] intermediate_bits;
  begin
    onehot_to_bin    = 0;
    intermediate_bits = 0;
    if(ATU_IN_MIN1>1) begin
      for (i=0; i<ATU_IN_MIN1; i=i+1) begin
        if (onehot_data[i]) begin
          intermediate_bits = i;
        end
      end
      onehot_to_bin = intermediate_bits[$clog2(ATU_IN_MIN1)-1:0];
    end
  end
endfunction


generate if (CPIPE_EN) begin : g_cpipe_gen_chk_en
  radm_atu_cpipe_s                                  radm_atu_cpipe_data;
  radm_atu_cpipe_s                                  radm_atu_cpipe_data_d;
  logic                                             radm_outq_pkt_hv_d;
  logic [ATU_CPIPE_PROT_WD-1:0]  radm_atu_cpipe_prot;
  logic [ATU_CPIPE_PROT_WD-1:0]  radm_atu_cpipe_prot_d;

  assign radm_atu_cpipe_data = { int_tlp_xlate, atu_reg_match_v,
                                 r_sloc_match, r_cbuf_err,
                                 int_addr_out, int_translated_err_in,
                                 atu_bar_mask };

  assign radm_atu_cpipe_data_d = { int_tlp_xlate_d, atu_reg_match_d,
                                   r_sloc_match_d, r_cbuf_err_d,
                                   int_addr_out_d, int_translated_err_in_d_v,
                                   atu_bar_mask_d };

  delay_n
   #(.N(CPIPE_DELAY), .WD(1)) 
    u_hv_delay ( .clk (core_clk), .rst_n (non_sticky_rst_n), .clear (1'b0), .din (radm_outq_pkt_hv), .dout (radm_outq_pkt_hv_d) );
assign radm_atu_outq_pkt_hv_d = radm_outq_pkt_hv_d;
  delay_n_w_enable
  
  #(.N(CPIPE_DELAY), .WD(ATU_CPIPE_PROT_WD))
  u_cpipe_prot_delay (
      .clk        (core_clk),
      .rst_n      (non_sticky_rst_n),
      .clear      (1'b0),
      .en         (radm_outq_pkt_hv),
      .din        (radm_atu_cpipe_prot),
      .dout       (radm_atu_cpipe_prot_d)
  );  

  // DPP Gen for ATU CPIPE 
  ras_dp_pipe
  
     #(
        .PIPELINE_TYPE           (0),                  // No pipeline only checker instance
        .RESETVAL                (0),                  
        .N_STAGES                (0),                  
        .CAN_STALL               (0),                  
        .RESET_STALL             (0),                  
        .BUS_PROTECT_GEN_EN      (1),                   
        .BUS_PROTECT_CHK_EN      (0),                  
        .PROT_TYPE               (PROT_TYPE),      
        .PROT_RANGE              (PROT_RANGE),     
        .PROT_WD                 (ATU_CPIPE_PROT_WD),
        .PARITY_MODE             (PARITY_MODE),    
        .PROT_CORRECT_EN         (PROT_CORRECT_EN),
        .TOTAL_WIDTH             ($bits(radm_atu_cpipe_s)),             
        .EXCLUDE_PROT_WIDTH      (0),
        .RAS_DP_PROT_CHK_ID_BASE (0)
    ) u_ras_dp_atu_cpipe_gen (
        .clk                      (core_clk           ),
        .rst_n                    (non_sticky_rst_n   ),
        .en                       (1'b1               ),
        .bypass                   (1'b0               ),
        .stall                    (1'b0               ),
        .stallout                 (                   ),
        
        .valid_in                 (radm_outq_pkt_hv   ),
        .din                      (radm_atu_cpipe_data),
        .din_prot                 ('0                 ),
        .halt_out                 (                   ),
        
        .valid_out                (                   ),
        .dout                     (                   ),
        .dout_prot                (radm_atu_cpipe_prot),
        .halt_in                  (1'b0               ),
        .ras_dp_err_inband_kbd_in (1'b0               ),
        .ras_dp_err_inband_kbd_out(                   ),
        .ras_dp_err_log           (                   )
        ,.ras_dp_err_inj          (ras_dp_err_inj     )
    );

  // DPP checker for ATU CPIPE 
  ras_dp_pipe
   #(
      .PIPELINE_TYPE           (0),                       // No pipeline only checker instance
      .RESETVAL                (0),                       // Reset value set to 0
      .N_STAGES                (0),                       // No pipeline delay from module
      .CAN_STALL               (0),                       // No stalling
      .RESET_STALL             (0),                       // Stall reset value set to 0.
      .BUS_PROTECT_GEN_EN      (0),                       // generater disabled
      .BUS_PROTECT_CHK_EN      (1),                       // Checker enabled
      .PROT_TYPE               (PROT_TYPE),               
      .PROT_RANGE              (PROT_RANGE),    
      .PROT_WD                 (ATU_CPIPE_PROT_WD),
      .PARITY_MODE             (PARITY_MODE),             
      .PROT_CORRECT_EN         (PROT_CORRECT_EN),         
      .TOTAL_WIDTH             ($bits(radm_atu_cpipe_s)),                      // Total width  
      .EXCLUDE_PROT_WIDTH      (0),
      .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE),
      .PIPE_RAS_DP_ERR_LOG     (1)
  ) u_ras_dp_atu_cpipe_chk (
      .clk                      (core_clk           ),
      .rst_n                    (non_sticky_rst_n   ),
      .en                       (1'b1               ),
      .bypass                   (1'b0               ),
      .stall                    (1'b0               ),
      .stallout                 (                   ),
      
      .valid_in                 (radm_outq_pkt_hv_d ),
      .din                      (radm_atu_cpipe_data_d),
      .din_prot                 (radm_atu_cpipe_prot_d),
      .halt_out                 (                   ),
      
      .valid_out                (                   ),
      .dout                     (                   ),
      .dout_prot                (                   ),
      .halt_in                  (1'b0               ),
      .ras_dp_err_inband_kbd_in (1'b0               ),
      .ras_dp_err_inband_kbd_out(                   ),
      .ras_dp_err_log           (ras_dp_err_log     )
      ,.ras_dp_err_inj          (ras_dp_err_inj     )
      );
  end else begin : g_cpipe_gen_chk_disable
    assign ras_dp_err_log = 'd0;
  end
  endgenerate


endmodule

