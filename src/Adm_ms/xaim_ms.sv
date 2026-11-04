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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xaim_ms.sv#6 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// XAIM module contains 3 sub modules.
//
// XAIM_HDR_FORM: Form PCIE tlp header received from the XALI.
//
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/xaim_ms_pkg.svh"                 
`include "products/pcie_pkg.svh"

module xaim_ms
import DWC_pcie_ctl_pkg::xali_pkt_t;
import DWC_pcie_ctl_pkg::NF;
import DWC_pcie_ctl_pkg::BUSNUM_WD;
import DWC_pcie_ctl_pkg::DEVNUM_WD;
import DWC_pcie_core_pkg::ADM_DATA_W_PROT_WD;
import DWC_pcie_core_pkg::LBC_MSG_HDR_W_PROT_WD;
import DWC_pcie_core_pkg::*;
import DWC_pcie_ctl_pkg::*;
import xaim_ms_pkg::*;
import pcie_pkg::*;
#(
  parameter ATU_OUT_MIN1 = `CX_ATU_NUM_OUTBOUND_REGIONS > 0 ? `CX_ATU_NUM_OUTBOUND_REGIONS : 1 
)
              (
    // ----------- Inputs -----------
    input                    core_clk,
//  `ifdef CX_L1_PG_ENABLE
//    input ret_core_clk,
//  `endif // CX_L1_PG_ENABLE
    input                    core_rst_n,
//`ifdef CX_L1_PG_ENABLE
//    input ret_core_rst_n,
//`endif // CX_L1_PG_ENABLE
    
    input rstctl_core_flush_req,
    input [2:0]              cfg_max_payload_size,//to delete, will be used in ccix ---- NC
//    input cfg_vc_enable,
//    input cfg_vc_struc_vc_id_map,
//    input cfg_tc_struc_vc_map,
//    input cfg_lpvc_wrr_weight,
//    input cfg_lpvc_wrr_phase,
//    input cfg_lpvc,
//    input cfg_tc_vc_map,
//`ifdef CX_RASDP_EN
//    input ras_prot_t_disable,
//`endif
    input [BUSNUM_WD -1:0]   cfg_pbus_num,
    input [DEVNUM_WD-1:0]    cfg_pbus_dev_num,
input  [7:0]         cfg_2ndbus_num,           // configured secondary bus number
    input [NF-1:0]           cfg_ecrc_gen_en,
    input [31:0]             cfg_trgt_cpl_lut_delete_entry,
    input [(3*NF)-1:0]       cfg_max_rd_req_size,

    input [6:0]              ras_prot_t_disable,
input                    cdm_ras_des_einj6_enable,
input [31:0]             cdm_ras_des_einj6_cmp_point_h0,
input [31:0]               cdm_ras_des_einj6_cmp_point_h1,  // Error Injection 6 header compare point byte4-7
input [31:0]               cdm_ras_des_einj6_cmp_point_h2,  // Error Injection 6 header compare point byte8-11
input [31:0]               cdm_ras_des_einj6_cmp_point_h3,  // Error Injection 6 header compare point byte12-15
input [31:0]               cdm_ras_des_einj6_cmp_value_h0,  // Error Injection 6 header compare value byte0-3
input [31:0]               cdm_ras_des_einj6_cmp_value_h1,  // Error Injection 6 header compare value byte4-7
input [31:0]               cdm_ras_des_einj6_cmp_value_h2,  // Error Injection 6 header compare value byte8-11
input [31:0]               cdm_ras_des_einj6_cmp_value_h3,  // Error Injection 6 header compare value byte12-15
input [31:0]               cdm_ras_des_einj6_chg_point_h0,  // Error Injection 6 header change point byte0-3
input [31:0]               cdm_ras_des_einj6_chg_point_h1,  // Error Injection 6 header change point byte4-7
input [31:0]               cdm_ras_des_einj6_chg_point_h2,  // Error Injection 6 header change point byte8-11
input [31:0]               cdm_ras_des_einj6_chg_point_h3,  // Error Injection 6 header change point byte12-15
input [31:0]               cdm_ras_des_einj6_chg_value_h0,  // Error Injection 6 header change value byte0-3
input [31:0]               cdm_ras_des_einj6_chg_value_h1,  // Error Injection 6 header change value byte4-7
input [31:0]               cdm_ras_des_einj6_chg_value_h2,  // Error Injection 6 header change value byte8-11
input [31:0]               cdm_ras_des_einj6_chg_value_h3,  // Error Injection 6 header change value byte12-15
input [7:0]                cdm_ras_des_einj6_count,         // Error Injection 6 count
input                      cdm_ras_des_einj6_invt_cont,     // Error Injection 6 inversion control
input [2:0]                cdm_ras_des_einj6_pkt_type,      // Error Injection 6 packet type

output [$clog2(N_XALI_IF+2)-1:0] xaim_einj6_tlp_evt,

//`ifdef CX_RASDP_EN
//output [RAS_XADM_COUNTERS-1:0] ras_stat_xaim_corr,
//output [RAS_XADM_COUNTERS-1:0] ras_stat_xaim_uncorr,
//`ifdef CX_RAS_ERROR_INJ_EN
//input  [255:0] ras_err_inj_en_array,
//input  [2399:0] ras_err_inj_mask,
//output                         ras_err_inj_done,
//`endif // CX_RAS_ERROR_INJ_EN
//`endif // CX_RASDP_EN

output ras_dp_err_log_t                   ras_dp_err_log,
input  ras_dp_err_inj_t                   ras_dp_err_inj,

input                                           cfg_client_p_block_new_tlp,
input                                           cfg_client_np_block_new_tlp,
input                                           cfg_client_cpl_block_new_tlp,
input                                           pm_xtlh_block_tlp,
input                                           pm_block_all_tlp,

// ATU outbound Region controls
input     [5*ATU_OUT_MIN1-1:0]                  atu_reg_out_type,
input     [3*ATU_OUT_MIN1-1:0]                  atu_reg_out_tc,
input     [ATTR_WD*ATU_OUT_MIN1-1:0]            atu_reg_out_attr,
input     [2*ATU_OUT_MIN1-1:0]                  atu_reg_out_at,
input     [PF_WD*ATU_OUT_MIN1-1:0]              atu_reg_out_func_num,
input     [ATU_OUT_MIN1-1:0]                    atu_reg_out_func_bypass,
input     [ATU_OUT_MIN1-1:0]                    atu_reg_out_dma_bypass,
input     [ATU_OUT_MIN1-1:0]                    atu_reg_out_inhibit_payload,
input     [ATU_OUT_MIN1-1:0]                    atu_reg_out_hdr_substitute_en,
input     [ATU_OUT_MIN1-1:0]                    atu_reg_out_tag_substitute_en,
input     [TAG_SIZE*ATU_OUT_MIN1-1:0]           atu_reg_out_tag,
input     [8*ATU_OUT_MIN1-1:0]                  atu_reg_out_msg_code,
input     [ATU_OUT_MIN1-1:0]                    atu_reg_out_th,
input     [2*ATU_OUT_MIN1-1:0]                  atu_reg_out_ph,
input     [8*ATU_OUT_MIN1-1:0]                  atu_reg_out_st,
// Mode Settings
input     [ATU_OUT_MIN1-1:0]                    atu_reg_out_shift,
input     [ATU_OUT_MIN1-1:0]                    atu_reg_out_invert,
// Region Enable
input     [ATU_OUT_MIN1-1:0]                    atu_reg_out_en,
// Base, Limit and Target Registers
input     [ATU_REG_WD*ATU_OUT_MIN1-1:0]         atu_reg_out_base,
input     [ATU_BASE_WD*ATU_OUT_MIN1-1:0]        atu_reg_out_upr_base,
input     [ATU_REG_WD*ATU_OUT_MIN1-1:0]         atu_reg_out_limit,
input     [ATU_UPR_LMT_WD*ATU_OUT_MIN1-1:0]     atu_reg_out_uppr_limit,
input     [ATU_REG_WD*ATU_OUT_MIN1-1:0]         atu_reg_out_lwr_trgt,
input     [ATU_BASE_WD*ATU_OUT_MIN1-1:0]        atu_reg_out_upr_trgt, 
input     [ATU_REG_LWR_WD*ATU_OUT_MIN1-1:0]     atu_reg_out_lwr_trgt_lwr,
input     [ATU_OUT_MIN1-1:0]                    atu_reg_out_incr_rgn_size,    // Maximum region size control bit
input     [ATU_OUT_MIN1-1:0]                    atu_reg_out_hdr_flds_bypass,  // TLP Header fields bypass control bit

input     [N_TRGT_NP_IF-1:0]                    radm_trgt1_hv,
input     [N_TRGT_NP_IF-1:0]                    radm_trgt1_eot,
input     [N_TRGT_NP_IF-1:0]                    radm_trgt1_tlp_abort,
input     [N_TRGT_NP_IF-1:0]                    radm_trgt1_dllp_abort,
input     [N_TRGT_NP_IF-1:0]              [1:0] radm_trgt1_fmt,
input     [N_TRGT_NP_IF-1:0]              [4:0] radm_trgt1_type,
input     [N_TRGT_NP_IF-1:0]              [9:0] radm_trgt1_dw_len,
input     [N_TRGT_NP_IF-1:0]              [6:0] radm_trgt1_addr,
input     [N_TRGT_NP_IF-1:0]                    radm_trgt1_cpl_last,
input     [N_TRGT_NP_IF-1:0]              [2:0] radm_trgt1_cpl_status,
input     [N_TRGT_NP_IF-1:0]             [11:0] radm_trgt1_byte_cnt,
input     [N_TRGT_NP_IF-1:0]              [2:0] radm_trgt1_tc,
input     [N_TRGT_NP_IF-1:0]     [TAG_SIZE-1:0] radm_trgt1_tag,
input     [N_TRGT_NP_IF-1:0]                    trgt1_radm_halt,

input     [N_TRGT_NP_IF-1:0]                    radm_cpl_timeout,
input     [N_TRGT_NP_IF-1:0]             [11:0] radm_timeout_cpl_byte_len,
input     [N_TRGT_NP_IF-1:0]              [2:0] radm_timeout_cpl_tc,
input     [N_TRGT_NP_IF-1:0]     [TAG_SIZE-1:0] radm_timeout_cpl_tag,

input [`CX_REMOTE_LUT_PTR_WIDTH-1:0]            cfg_remote_max_bridge_tag,
input                                     [2:0] current_data_rate,
input                                    [23:0] cfg_tc_struc_vc_map,
input     [N_TRGT_NP_IF-1:0]              [8:0] radm_trgt1_np_0_reqtr_sgmt,
input     [N_TRGT_NP_IF-1:0]                    radm_trgt1_ecrc_err,
input     [N_TRGT_NP_IF-1:0]      [ATTR_WD-1:0] radm_trgt1_attr,
input     [N_TRGT_NP_IF-1:0]             [15:0] radm_trgt1_reqid,
input     [N_TRGT_NP_IF-1:0]              [3:0] radm_trgt1_first_be,
input     [N_TRGT_NP_IF-1:0]              [3:0] radm_trgt1_last_be,
input     [N_TRGT_NP_IF-1:0]        [PF_WD-1:0] radm_trgt1_func_num,
input     [N_TRGT_NP_IF-1:0]        [3*NVC-1:0] radm_grant_tlp_type,
output    [N_TRGT_NP_IF-1:0]        [3*NVC-1:0] trgt_lut_trgt1_radm_pkt_halt,
input     [N_TRGT_NP_IF-1:0]                    radm_trgt1_dma_grant,
input     [N_TRGT_NP_IF-1:0]                    radm_trgt1_dma_cpl_rlsd,
output    [N_TRGT_NP_IF-1:0]                    trgt_lut_dma_pkt_halt,
input     [N_TRGT_NP_IF-1:0]              [1:0] radm_trgt1_at,
input                                           cfg_rcb_128,
output    [N_TRGT_NP_IF-1:0]  [LOOKUPID_WD-1:0] trgt_lookup_id,
output    [N_TRGT_NP_IF-1:0]                    trgt_lookup_empty,
output    [N_TRGT_NP_IF-1:0]                    trgt_cpl_lut_empty,
output    [N_TRGT_NP_IF-1:0]        [PF_WD-1:0] trgt_timeout_cpl_func_num,
output    [N_TRGT_NP_IF-1:0]                    trgt_cpl_timeout,
output    [N_TRGT_NP_IF-1:0]              [2:0] trgt_timeout_cpl_tc,
output    [N_TRGT_NP_IF-1:0]              [1:0] trgt_timeout_cpl_attr,
output    [N_TRGT_NP_IF-1:0]             [11:0] trgt_timeout_cpl_len,
output    [N_TRGT_NP_IF-1:0]  [LOOKUPID_WD-1:0] trgt_timeout_lookup_id,


  // Indicates to the received ompletion is the last one
  output [N_TRGT_NP_IF-1:0]           [NVC-1:0] radm_trgt1_cpl_lookup_id_rlsd,
  output [N_TRGT_NP_IF-1:0]                     radm_trgt1_lookup_id_consmd,





// from CDM MSG GEN
input                      msg_gen_hv,                  // CDM generated MSG Header Valid
input                      msg_gen_dv,                  // CDM generated MSG Data valid
input                      msg_gen_eot,                 // CDM generated MSG EOT
input [ADM_DATA_W_PROT_WD-1:0]             msg_gen_data,                // CDM generated MSG data
input [LBC_MSG_HDR_W_PROT_WD-1:0] msg_gen_hdr,             // CDM generated MSG hdr (with protection is RAS is used)
// from LBC
input                      lbc_cpl_hv,                  // RADM generated CPL Header Valid
input                      lbc_cpl_dv,                  // RADM generated CPL request with valid data
input [ADM_DATA_W_PROT_WD-1:0]             lbc_cpl_data,                // RADM generated CPL data
input [LBC_MSG_HDR_W_PROT_WD-1:0] lbc_cpl_hdr,             // RADM generated CPL hdr (with address protection if RAS is used)
input                      lbc_cpl_eot,                 // RADM generated CPL eot

//`ifdef CX_ATOMIC_ENABLE
//    input cfg_atomic_req_en,
//`endif // CX_ATOMIC_ENABLE
//`ifdef ATOMIC_ROUTING_SUP
//    input cfg_atomic_egress_block,
//`endif // ATOMIC_ROUTING_SUP
//`ifdef CX_DEF_MEM_WR_ENABLE
//    input cfg_dmwr_req_en,
//  `ifdef CX_DEF_MEM_WR_ROUTING_SUP
//    input cfg_dmwr_req_egress_block,
//  `endif // CX_DEF_MEM_WR_ROUTING_SUP
//`endif // CX_DEF_MEM_WR_ENABLE
    input [3:0]              device_type,                  //Device type - RC, EP, SW or DM.
    input [N_XALI_IF-1:0]    xadm_xaim_xali_halt,
    input                    xadm_xaim_msg_halt,                // XADM halts CDM MSG generation
    input                    xadm_xaim_cpl_halt,                // XADM halts LBC CPL generation
    input xali_pkt_t [N_XALI_IF-1:0]  xali_xaim_pkt,                  //Device type - RC, EP, SW or DM.
    input                    flit_mode,  
    input [8:0]              cfg_segment_id,
    input [2:0]              cfg_optional_ohc,

    output xadm_pkt_t [N_XALI_IF-1:0]xaim_xadm_xali_pkt,
    output xadm_pkt_t xaim_xadm_msg_pkt,
    output xadm_pkt_t xaim_xadm_lbc_pkt,
    output [N_XALI_IF-1:0] xaim_xali_halt,
    output xaim_msg_halt,
    output xaim_cpl_halt,
    output logic xaim_pm_pkt_pending
);
//localparam TAG_SIZE    = `CX_TAG_SIZE;
//localparam LOOKUPID_WD = `CX_REMOTE_LOOKUPID_WD;

localparam HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8;
localparam DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12;



// Struct Defines
xali_xaim_cfg_t                       xali_xaim_cfg;
cdm_xaim_cfg_t                        cdm_xaim_cfg;
xaim_xali_cfg_t                       xaim_xali_cfg ;
cdm_atu_out_cfg_t                     cdm_atu_out_cfg;
msg_lbc_xaim_pkt_t                    msg_xaim_pkt;
msg_lbc_xaim_pkt_t                    lbc_xaim_pkt;
logic              [N_TRGT_NP_IF-1:0] radm_xaim_halt;
//`ifdef TRGT_CPL_LUT_EN
radm_xaim_pkt_t    [N_TRGT_NP_IF-1:0] radm_xaim_pkt;
xaim_radm_pkt_t    [N_TRGT_NP_IF-1:0] xaim_radm_pkt;
xaim_xali_pkt_t    [N_TRGT_NP_IF-1:0] xaim_xali_pkt;
pmctrl_xaim_pkt_t                     pmctrl_xaim_pkt;
xaim_pmctrl_pkt_t                     xaim_pmctrl_pkt;


////////////////////////////////////////////
// PM Control Assigns
////////////////////////////////////////////
assign xaim_pm_pkt_pending = xaim_pmctrl_pkt.pkt_pending;
assign pmctrl_xaim_pkt.xtlh_block_tlp = pm_xtlh_block_tlp;
assign pmctrl_xaim_pkt.block_all_tlp  = pm_block_all_tlp;

assign pmctrl_xaim_pkt.current_data_rate = current_data_rate ;
//assign pmctrl_xaim_pkt.temp              = '0;

////////////////////////////////////////////
// RAS Assigns
////////////////////////////////////////////
assign ras_stat_xaim_corr = '0;
assign ras_stat_xaim_uncorr = '0;
assign ras_err_inj_done     = '0;

////////////////////////////////////////////
// Application Assigns
////////////////////////////////////////////
assign xali_xaim_cfg.device_type              = device_type;
assign xaim_xali_cfg.cfg_remote_max_bridge_tag = cfg_remote_max_bridge_tag ;
////////////////////////////////////////////
// CDM xaim Assigns
////////////////////////////////////////////
logic flit_mode_d;

always_ff @ (posedge core_clk or negedge core_rst_n )
  if ( ~core_rst_n )
    flit_mode_d <= '0;
  else
    if ( ~rstctl_core_flush_req )
      flit_mode_d <= flit_mode;




assign cdm_xaim_cfg.cfg_pbus_num        = cfg_pbus_num;
assign cdm_xaim_cfg.cfg_pbus_dev_num    = cfg_pbus_dev_num;
assign cdm_xaim_cfg.cfg_2ndbus_num      = cfg_2ndbus_num;
assign cdm_xaim_cfg.cfg_ecrc_gen_en     = cfg_ecrc_gen_en;
assign cdm_xaim_cfg.cfg_max_rd_req_size = cfg_max_rd_req_size;
assign cdm_xaim_cfg.cfg_trgt_cpl_lut_delete_entry = cfg_trgt_cpl_lut_delete_entry;
assign cdm_xaim_cfg.mode                = mode_e'(flit_mode_d);


assign cdm_xaim_cfg.cfg_segment_id           = cfg_segment_id;
assign cdm_xaim_cfg.cfg_optional_ohc_ctrl   = cfg_optional_ohc;
assign cdm_xaim_cfg.cfg_client_p_block_new_tlp = cfg_client_p_block_new_tlp;
assign cdm_xaim_cfg.cfg_client_np_block_new_tlp = cfg_client_np_block_new_tlp;
assign cdm_xaim_cfg.cfg_client_cpl_block_new_tlp = cfg_client_cpl_block_new_tlp;
assign cdm_xaim_cfg.cfg_rcb_128               = cfg_rcb_128;
assign cdm_xaim_cfg.cfg_tc_struc_vc_map       = cfg_tc_struc_vc_map;

assign cdm_xaim_cfg.einj6_enable               = cdm_ras_des_einj6_enable;
assign cdm_xaim_cfg.einj6_cmp_point_h0         = cdm_ras_des_einj6_cmp_point_h0;
assign cdm_xaim_cfg.einj6_cmp_point_h1         = cdm_ras_des_einj6_cmp_point_h1;
assign cdm_xaim_cfg.einj6_cmp_point_h2         = cdm_ras_des_einj6_cmp_point_h2;
assign cdm_xaim_cfg.einj6_cmp_point_h3         = cdm_ras_des_einj6_cmp_point_h3;
assign cdm_xaim_cfg.einj6_cmp_value_h0         = cdm_ras_des_einj6_cmp_value_h0;
assign cdm_xaim_cfg.einj6_cmp_value_h1         = cdm_ras_des_einj6_cmp_value_h1;
assign cdm_xaim_cfg.einj6_cmp_value_h2         = cdm_ras_des_einj6_cmp_value_h2;
assign cdm_xaim_cfg.einj6_cmp_value_h3         = cdm_ras_des_einj6_cmp_value_h3;
assign cdm_xaim_cfg.einj6_chg_point_h0         = cdm_ras_des_einj6_chg_point_h0;
assign cdm_xaim_cfg.einj6_chg_point_h1         = cdm_ras_des_einj6_chg_point_h1;
assign cdm_xaim_cfg.einj6_chg_point_h2         = cdm_ras_des_einj6_chg_point_h2;
assign cdm_xaim_cfg.einj6_chg_point_h3         = cdm_ras_des_einj6_chg_point_h3;
assign cdm_xaim_cfg.einj6_chg_value_h0         = cdm_ras_des_einj6_chg_value_h0;
assign cdm_xaim_cfg.einj6_chg_value_h1         = cdm_ras_des_einj6_chg_value_h1;
assign cdm_xaim_cfg.einj6_chg_value_h2         = cdm_ras_des_einj6_chg_value_h2;
assign cdm_xaim_cfg.einj6_chg_value_h3         = cdm_ras_des_einj6_chg_value_h3;
assign cdm_xaim_cfg.einj6_count                = cdm_ras_des_einj6_count;
assign cdm_xaim_cfg.einj6_invt_cont            = cdm_ras_des_einj6_invt_cont;
assign cdm_xaim_cfg.einj6_pkt_type             = cdm_ras_des_einj6_pkt_type;
////////////////////////////////////////////
// CDM ATU Out Assigns
////////////////////////////////////////////
assign cdm_atu_out_cfg.tlp_type         = atu_reg_out_type;
assign cdm_atu_out_cfg.tc               = atu_reg_out_tc;
assign cdm_atu_out_cfg.td               = '0;
assign cdm_atu_out_cfg.attr             = atu_reg_out_attr;
assign cdm_atu_out_cfg.at               = atu_reg_out_at;
assign cdm_atu_out_cfg.func_num         = atu_reg_out_func_num;
assign cdm_atu_out_cfg.func_bypass      = atu_reg_out_func_bypass;
assign cdm_atu_out_cfg.snp              = '0;
assign cdm_atu_out_cfg.dma_bypass       = atu_reg_out_dma_bypass;
assign cdm_atu_out_cfg.inhibit_pyld     = atu_reg_out_inhibit_payload;
assign cdm_atu_out_cfg.hdr_substitute_en = atu_reg_out_hdr_substitute_en;
assign cdm_atu_out_cfg.tag_substitute_en = atu_reg_out_tag_substitute_en;
assign cdm_atu_out_cfg.tag               = atu_reg_out_tag;
assign cdm_atu_out_cfg.msg_code          = atu_reg_out_msg_code;
assign cdm_atu_out_cfg.th                = atu_reg_out_th;
assign cdm_atu_out_cfg.ph                = atu_reg_out_ph;
assign cdm_atu_out_cfg.st                = atu_reg_out_st;
assign cdm_atu_out_cfg.shift             = atu_reg_out_shift;
assign cdm_atu_out_cfg.invert            = atu_reg_out_invert;
assign cdm_atu_out_cfg.en                = atu_reg_out_en;
assign cdm_atu_out_cfg.base              = atu_reg_out_base;
assign cdm_atu_out_cfg.upr_base          = atu_reg_out_upr_base;
assign cdm_atu_out_cfg.limit             = atu_reg_out_limit;
assign cdm_atu_out_cfg.uppr_limit        = atu_reg_out_uppr_limit;
assign cdm_atu_out_cfg.lwr_trgt          = atu_reg_out_lwr_trgt;
assign cdm_atu_out_cfg.upr_trgt          = atu_reg_out_upr_trgt;
assign cdm_atu_out_cfg.lwr_trgt_lwr      = atu_reg_out_lwr_trgt_lwr;
assign cdm_atu_out_cfg.incr_rgn_size     = atu_reg_out_incr_rgn_size;
assign cdm_atu_out_cfg.hdr_flds_bypass   = atu_reg_out_hdr_flds_bypass;

////////////////////////////////////////////
// RADM XAIM Assigns
////////////////////////////////////////////
assign radm_xaim_pkt[0].hv               = radm_trgt1_hv[0];
assign radm_xaim_pkt[0].eot              = radm_trgt1_eot[0]; 
assign radm_xaim_pkt[0].tlp_abort        = radm_trgt1_tlp_abort[0];
assign radm_xaim_pkt[0].dllp_abort       = radm_trgt1_dllp_abort[0];
assign radm_xaim_pkt[0].fmt              = radm_trgt1_fmt[0];
assign radm_xaim_pkt[0].tlp_type         = radm_trgt1_type[0];
assign radm_xaim_pkt[0].dw_len           = radm_trgt1_dw_len[0];
assign radm_xaim_pkt[0].addr             = radm_trgt1_addr[0];
assign radm_xaim_pkt[0].cpl_last         = radm_trgt1_cpl_last[0];
assign radm_xaim_pkt[0].cpl_status       = radm_trgt1_cpl_status[0];
assign radm_xaim_pkt[0].byte_cnt         = radm_trgt1_byte_cnt[0];
assign radm_xaim_pkt[0].tc               = radm_trgt1_tc[0];
assign radm_xaim_pkt[0].tag              = radm_trgt1_tag[0];
assign radm_xaim_pkt[0].cpl_timeout      = radm_cpl_timeout[0];
assign radm_xaim_pkt[0].timeout_cpl_byte_len = radm_timeout_cpl_byte_len[0];
assign radm_xaim_pkt[0].timeout_cpl_tc   = radm_timeout_cpl_tc[0];
assign radm_xaim_pkt[0].timeout_cpl_tag  = radm_timeout_cpl_tag[0];
assign radm_xaim_halt[0]                 = trgt1_radm_halt;
assign radm_xaim_pkt[0].req_segment      = radm_trgt1_np_0_reqtr_sgmt[0] ;
assign radm_xaim_pkt[0].ecrc_err         = radm_trgt1_ecrc_err[0];
assign radm_xaim_pkt[0].attr             = radm_trgt1_attr[0];
assign radm_xaim_pkt[0].reqid            = radm_trgt1_reqid[0];
assign radm_xaim_pkt[0].first_be         = radm_trgt1_first_be[0];
assign radm_xaim_pkt[0].last_be          = radm_trgt1_last_be[0];
assign radm_xaim_pkt[0].func_num         = radm_trgt1_func_num[0];
assign radm_xaim_pkt[0].at               = radm_trgt1_at[0];

assign trgt_lookup_id[0]     = xaim_xali_pkt[0].trgt_lookup_id;
assign trgt_lookup_empty[0]  = xaim_xali_pkt[0].trgt_lookup_empty;
assign trgt_cpl_lut_empty[0] = xaim_xali_pkt[0].trgt_cpl_lut_empty;
assign trgt_timeout_cpl_func_num[0] = xaim_xali_pkt[0].trgt_timeout_cpl_func_num;
assign trgt_cpl_timeout[0]   = xaim_xali_pkt[0].trgt_cpl_timeout;
assign trgt_timeout_cpl_tc[0]          = xaim_xali_pkt[0].trgt_timeout_cpl_tc;
assign trgt_timeout_cpl_attr[0]        = xaim_xali_pkt[0].trgt_timeout_cpl_attr;
assign trgt_timeout_cpl_len[0]         = xaim_xali_pkt[0].trgt_timeout_cpl_len;
assign trgt_timeout_lookup_id[0]       = xaim_xali_pkt[0].trgt_timeout_lookup_id;


assign radm_trgt1_cpl_lookup_id_rlsd[0]   = xaim_radm_pkt[0].cpl_lookup_id_rlsd;
assign radm_trgt1_lookup_id_consmd        = xaim_xali_pkt[0].radm_trgt1_lookup_id_consmd ;

assign radm_xaim_pkt[0].radm_grant_tlp_type = radm_grant_tlp_type[0];
assign trgt_lut_trgt1_radm_pkt_halt[0] = xaim_radm_pkt[0].trgt_lut_trgt1_radm_pkt_halt ;
assign xali_xaim_cfg.radm_trgt1_dma_grant = radm_trgt1_dma_grant;
assign xali_xaim_cfg.radm_trgt1_dma_cpl_rlsd = radm_trgt1_dma_cpl_rlsd;
assign trgt_lut_dma_pkt_halt[0]        = xaim_xali_pkt[0].trgt_lut_dma_pkt_halt;





////////////////////////////////////////////
// MSG GEN Assigns
////////////////////////////////////////////
assign msg_xaim_pkt.hv              = msg_gen_hv;
assign msg_xaim_pkt.dv              = msg_gen_dv;
assign msg_xaim_pkt.eot             = msg_gen_eot;
assign msg_xaim_pkt.data            = msg_gen_data;
assign msg_xaim_pkt.hdr             = msg_gen_hdr;
assign msg_xaim_pkt.prfx[PRFX_WO_PAR-1:0] = '0;
assign msg_xaim_pkt.prfx[PRFX_W_PAR-1:PRFX_WO_PAR] = `CX_RAS_ALL_PRFX_0S_PROT_CODE;



////////////////////////////////////////////
// LBC CPL Assigns
////////////////////////////////////////////
assign lbc_xaim_pkt.hv              = lbc_cpl_hv;
assign lbc_xaim_pkt.dv              = lbc_cpl_dv;
assign lbc_xaim_pkt.eot             = lbc_cpl_eot;
assign lbc_xaim_pkt.data            = lbc_cpl_data;
assign lbc_xaim_pkt.hdr             = lbc_cpl_hdr;
assign lbc_xaim_pkt.prfx[PRFX_WO_PAR-1:0] = '0;
assign lbc_xaim_pkt.prfx[PRFX_W_PAR-1:PRFX_WO_PAR] = `CX_RAS_ALL_PRFX_0S_PROT_CODE;
////////////////////////////////////////////
// CXPL Assigns
////////////////////////////////////////////
////////////////////////////////////////////
// XAIM Instance
////////////////////////////////////////////
xaim_ms_new
 u_xaim_ms_new (
  // Clocks/Resets
  .core_clk,
  .core_rst_n,
  // Configuration Structs
  .xali_xaim_cfg,
  .cdm_xaim_cfg,
  .cdm_atu_out_cfg,
  // TLP Packet Interfaces from Application/CDM/LBC/RADM
  .xali_xaim_pkt,
  .xaim_xali_halt,
  .msg_xaim_pkt,
  .xaim_msg_halt,
  .lbc_xaim_pkt,
  .xaim_lbc_halt        ( xaim_cpl_halt ),
  .xaim_xali_cfg,
  .radm_xaim_pkt,
  .radm_xaim_halt,
  .xaim_radm_pkt,
  .xaim_xali_pkt,

  .ras_dp_err_log,
  .ras_dp_err_inj,

  .xaim_einj6_tlp_evt,

  .rstctl_core_flush_req,
  .xaim_pmctrl_pkt, 
  .pmctrl_xaim_pkt ( pmctrl_xaim_pkt ), 

  // TLP Packet Interfaces to XADM
  .xaim_xadm_xali_pkt,
  .xadm_xaim_xali_halt,
  .xaim_xadm_msg_pkt,
  .xadm_xaim_msg_halt,
  .xaim_xadm_lbc_pkt,
  .xadm_xaim_lbc_halt  ( xadm_xaim_cpl_halt )
);


endmodule
