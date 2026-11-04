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
// ---    $DateTime: 2024/01/24 06:45:16 $
// ---    $Revision: #67 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/axi_bridge.sv#67 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Axi/DWC_pcie_axi_mstr_pkg.svh"
`include "Axi/DWC_pcie_axi_slv_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Axi/DWC_pcie_axi_xali_pkg.svh"
`include "Axi/DWC_pcie_axi_bridge_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"


`include "Axi/svif/DWC_pcie_axi_slv_ar_if.svh"
`include "Axi/svif/DWC_pcie_axi_slv_aw_if.svh"
`include "Axi/svif/DWC_pcie_axi_slv_w_if.svh"
`include "Axi/svif/DWC_pcie_axi_slv_r_if.svh"
`include "Axi/svif/DWC_pcie_axi_slv_b_if.svh"

`include "Axi/svif/DWC_pcie_axi_mstr_ar_if.svh"
`include "Axi/svif/DWC_pcie_axi_mstr_aw_if.svh"
`include "Axi/svif/DWC_pcie_axi_mstr_w_if.svh"
`include "Axi/svif/DWC_pcie_axi_mstr_r_if.svh"
`include "Axi/svif/DWC_pcie_axi_mstr_b_if.svh"


module axi_bridge
import DWC_pcie_axi_mstr_pkg::*;
import DWC_pcie_axi_slv_pkg::*;
import DWC_pcie_axi_xali_pkg::*;
import DWC_pcie_ctl_pkg::N_XADM_P_IF;
import DWC_pcie_ctl_pkg::xali_pkt_t;
import DWC_pcie_ctl_pkg::TAG_SIZE;
import DWC_pcie_ctl_pkg::PRFX_W_PAR;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
import DWC_pcie_ctl_pkg::RAS_ERROR_LOG_WD;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import DWC_pcie_ctl_pkg::ATU_OUT_NREGIONS_MIN1;

import DWC_pcie_axi_bridge_pkg::TX_TLP_PREFIX_WD;
import DWC_pcie_axi_bridge_pkg::PRFX_WIDTH;
import DWC_pcie_axi_bridge_pkg::TPH_ST_WD;
import DWC_pcie_axi_bridge_pkg::TPH_PH_WD;
import DWC_pcie_axi_bridge_pkg::TPH_TH_WD;
import DWC_pcie_axi_bridge_pkg::MISC_INFO_TPH_WD;
import DWC_pcie_axi_bridge_pkg::HDR_UPPR_BYTES_WD;


   
                 (
    // -------------------------------------------------------------------------------------
    // Clocks and resets
    // -------------------------------------------------------------------------------------
    input                                                 aux_clk,
    input                                                 aux_clk_g,
    input                                                 cfg_axi_clk_gating_en,
    input [4:0]                                           cfg_pbus_dev_num,  // Device number
    input [7:0]                                           cfg_pbus_num,      // Primary bus number
    input [7:0]                                           cfg_subbus_num,    // Configured Subordinate Bus Number
    input [7:0]                                           cfg_2ndbus_num,    // Secondary bus number
    // AXI master write request
    input                                                 mstr_aclk_g,  // gated clock for master interface. gated with en_mstr_aclk_g (for internal modules or signals, mstr_aclk_g = mstr_aclk)
    input                                                 mstr_aresetn, // reset for master clock domain
    input                                                 mstr_aclk,    // ungated clock for master interface                          (for internal modules or signals, mstr_aclk = mstr_aclk_ug)
    output wire                                           en_mstr_aclk_g, // gating signal for mstr_aclk_g                             (for internal modules or signals, en_mstr_aclk_g = mstr_aclk_active)
    output wire                                           mstr_rasdp_err_mode, //Core RASDP mode synchronized with mstr_aclk_g
    output [`CC_MSTR_BUS_ID_WIDTH -1:0]                   mstr_awid,
    output                                                mstr_awvalid,
    output [`MASTER_BUS_ADDR_WIDTH -1:0]                  mstr_awaddr,
    output [`CC_MSTR_AW_USER_WIDTH-1:0]                   mstr_awuser,
    output [`CC_MSTR_BURST_LEN_PW -1:0]                   mstr_awlen,



//ccx_tgl: ; mstr_awsize[0]; ; Uses Full Size method for executing Narrow Inbound Writes at AXI Master Interface.







    output [2:0]                                          mstr_awsize,
    //ccx_tgl: ; mstr_awburst; ; Only INCR transactions are supported
    output [1:0]                                          mstr_awburst,
    //ccx_tgl: ; mstr_awlock; ; Locked transactions not supported
    output [`CC_AXI_LOCK_WIDTH-1:0]                       mstr_awlock,
    output [3:0]                                          mstr_awcache,
    //ccx_tgl: ; mstr_awprot; ; Transactions protection not supported
    output [2:0]                                          mstr_awprot,

//ccx_tgl: ; mstr_awmisc_info[13:11]; ; The number of functions is controled by the CX_NFUNC parameter.


    //ccx_tgl: ; mstr_awmisc_info[22]; ; No completions on AW-Channel
    output [`MSTR_MISC_INFO_PW -1:0]                      mstr_awmisc_info,
    output wire                                           mstr_awmisc_info_last_dcmp_tlp, // last TLP of the inbound write request
    output wire [63:0]                                    mstr_awmisc_info_hdr_34dw, // 3rd and 4th DWs of header of PCIe Msg/MsgD
    output                                                mstr_awmisc_info_nw,
    //ccx_tgl: ; mstr_awmisc_info_cxlsrc; ; This signal is tied to zero for DTI Version 1.
    output                                                mstr_awmisc_info_cxlsrc,
    output [1:0]                                          mstr_awmisc_info_ats,
    output                                                mstr_awmisc_info_ep,
    output [`CC_NUM_DMA_RD_CHAN_WIDTH+`DC_DMA_TYPE_WIDTH-1:0] mstr_awmisc_info_dma,
    output [PRFX_WIDTH-1:0]                               mstr_awmisc_info_tlpprfx,
    output [MISC_INFO_TPH_WD-1:0]                         mstr_awmisc_info_tph,
    output                                                mstr_awmisc_info_ido,
    output                                          [8:0] mstr_awmisc_info_dst_segment,
    output                                          [8:0] mstr_awmisc_info_req_segment,
    //ccx_tgl: ; mstr_awqos; ; No AXI QoS supported
    output [3:0]                                          mstr_awqos,
    output [1:0]                                          mstr_awbar,
    output [1:0]                                          mstr_awdomain,
    output[`CC_AXIJ_DMWR_VALUE *2+2:0]                    mstr_awsnoop,
    output [5:0]                                          mstr_awatop,
    input                                                 mstr_awready,

    // AXI master write data
    output                                                mstr_wvalid,
    output                                                mstr_wlast,
    output [`MASTER_BUS_DATA_WIDTH-1:0]                   mstr_wdata,
    output [`CC_MSTR_W_USER_WIDTH-1:0]                    mstr_wuser,
    output [`CC_MSTR_BUS_WSTRB_WIDTH -1:0]                mstr_wstrb,
    input                                                 mstr_wready,

    // AXI master write response
    input [`CC_MSTR_BUS_ID_WIDTH -1:0]                    mstr_bid,
    input                                                 mstr_bvalid,
    
    input [`CC_AXIJ_DMWR_VALUE+1:0]                       mstr_bresp,
    input [`DC_CPL_STATUS_WD-1:0]                         mstr_bmisc_info_cpl_stat,
    //ccx_tgl: ; mstr_bready; ; Missing stimulus, refer JIRA P80001562-415476.
    output                                                mstr_bready,

    // AXI master read request
    output [`CC_MSTR_BUS_ID_WIDTH -1:0]                   mstr_arid,
    output                                                mstr_arvalid,
    output [`MASTER_BUS_ADDR_WIDTH-1:0]                   mstr_araddr,
    output [`CC_MSTR_AR_USER_WIDTH-1:0]                   mstr_aruser,

//ccx_tgl: ; mstr_arlen[8:3]; ; The maximum burst length of an AXI transfer at the master interface is 3


    output [`CC_MSTR_BURST_LEN_PW -1:0]                   mstr_arlen,




//ccx_tgl: ; mstr_arsize[0]; ; Uses Approximate Full Size method for executing Narrow Inbound Reads at AXI Master Interface.







    output [2:0]                                          mstr_arsize,
    output [1:0]                                          mstr_arburst,
    output [`CC_AXI_LOCK_WIDTH-1:0]                       mstr_arlock,
    output [3:0]                                          mstr_arcache,
    output [2:0]                                          mstr_arprot,
    //ccx_tgl: ; mstr_armisc_info[5:0]; ; Reserved field
    //ccx_tgl: ; mstr_armisc_info[23]; ; No Message Request types (Writes) on AR-Channel
    //ccx_tgl: ; mstr_armisc_info[22]; ; No completions on AR-Channel


//ccx_tgl: ; mstr_armisc_info[13:11]; ; The number of functions is controled by the CX_NFUNC parameter.


    output [`MSTR_MISC_INFO_PW -1 :0]                     mstr_armisc_info,
    output wire                                           mstr_armisc_info_last_dcmp_tlp, // last TLP of the inbound read request
    output                                                mstr_armisc_info_nw,
    //ccx_tgl: ; mstr_armisc_info_cxlsrc; ; This signal is tied to zero for DTI Version 1.
    output                                                mstr_armisc_info_cxlsrc,
    output [1:0]                                          mstr_armisc_info_ats,
    output [`CC_NUM_DMA_MAX_CHAN_WIDTH+`DC_DMA_TYPE_WIDTH-1:0] mstr_armisc_info_dma,
    output [PRFX_WIDTH-1:0]                               mstr_armisc_info_tlpprfx,
    output [MISC_INFO_TPH_WD-1:0]                         mstr_armisc_info_tph,
    output                                                mstr_armisc_info_ido,
    output                                                mstr_armisc_info_zeroread,
    output                                          [8:0] mstr_armisc_info_dst_segment,
    output                                          [8:0] mstr_armisc_info_req_segment,
    //ccx_tgl: ; mstr_arqos; ; No AXI QoS supported
    output [3:0]                                          mstr_arqos,
    output [1:0]                                          mstr_arbar,
    output [1:0]                                          mstr_ardomain,
    output [3:0]                                          mstr_arsnoop,
    input                                                 mstr_arready,

    // AXI master read response & read data

//ccx_tgl: ; mstr_rid[9]; ; TB can be improved to be covered

    input [`CC_MSTR_BUS_ID_WIDTH -1:0]                    mstr_rid,
    input                                                 mstr_rvalid,
    input                                                 mstr_rlast,
    input [`MASTER_BUS_DATA_WIDTH-1:0]                    mstr_rdata,
    input [`CC_MSTR_R_USER_WIDTH-1:0]                     mstr_ruser,
    input [1:0]                                           mstr_rresp,
    //ccx_tgl: ; mstr_rmisc_info_cpl_stat[1]; ; Only SC, CA and UR in cpl_stat are supported. Bridge don't support cfg_retry.
    input [`DC_CPL_STATUS_WD-1:0]                         mstr_rmisc_info_cpl_stat,
    input [`MSTR_RESP_MISC_INFO_PW -1:0]                  mstr_rmisc_info,
    output                                                mstr_rready,

    // AXI master low power
    //ccx_tgl: ; mstr_csysack; ; AXI Low Power Interface not used
    //ccx_tgl: ; mstr_cactive; ; AXI Low Power Interface not used
    input                                                 mstr_csysreq,
    output                                                mstr_csysack,
    output                                                mstr_cactive,



    // ***************************************************
    // AXI slave interface

    input                                                 slv_aclk_g, // Gated clock_for slave interface. Gated with en_slv_aclk_g (for internal modules or signals, slv_aclk_g = slv_aclk)
    input                                                 slv_aresetn, // reset for slave clock domain
    input                                                 slv_aclk,                                                              // for internal modules or signals, slv_aclk = slv_aclk_ug
    output                                                en_slv_aclk_g,                                                         // for internal modules or signals, en_slv_aclk_g = slv_aclk_active)
    output wire                                           slv_rasdp_err_mode, // Core RASDP mode synchronized with slv_aclk_g

    input                                                 slv_csysreq,
    // AXI slave Write address channel
    input [`CC_SLV_BUS_ID_WIDTH -1:0]                     slv_awid,
    input [`SLAVE_BUS_ADDR_WIDTH -1:0]                    slv_awaddr,
    input [`CC_SLV_AW_USER_WIDTH-1:0]                     slv_awuser,
    input [`CC_SLV_INT_BURST_LEN_PW -1:0]                 slv_awlen,
    input [2:0]                                           slv_awsize,
    input [1:0]                                           slv_awburst,
    input [`CC_AXI_LOCK_WIDTH-1:0]                        slv_awlock,
    input [3:0]                                           slv_awcache,
    input [2:0]                                           slv_awprot,
    input                                                 slv_awvalid,

//ccx_tgl: ; slv_awmisc_info[24:22]; ; Function numbering of the TLP. 


    input [`SLV_MISC_INFO_PW -1:0]                        slv_awmisc_info,
    input [63:0]                                          slv_awmisc_info_hdr_34dw,
    input                                                 slv_awmisc_info_nw,
    input [1:0]                                           slv_awmisc_info_ats,
    input [PRFX_WIDTH-1:0]                                slv_awmisc_info_tlpprfx,
    input [`CX_TAG_SIZE-1:0]                              slv_awmisc_info_p_tag,
    input [MISC_INFO_TPH_WD-1:0]                          slv_awmisc_info_tph,
    input                                                 slv_awmisc_info_atu_bypass,
    input                                                 slv_awmisc_info_ido,
    input [8:0]                                           slv_awmisc_info_dst_segment,
    output                                                slv_awready,
    input [3:0]                                           slv_awqos,
    //ccx_tgl: ; slv_awbar[1:0]; ; Not supported. The AXI bridge subordinate does not implement ACE; it ignores the value of the DOMAIN, BAR and SNOOP fields
    input [1:0]                                           slv_awbar,
    input [1:0]                                           slv_awdomain,
    //ccx_tgl: ; slv_awsnoop[3:0]; ; Not supported. The AXI bridge subordinate does not implement ACE; it ignores the value of the DOMAIN, BAR and SNOOP fields
    input [`CC_AXIJ_DMWR_VALUE *2+2:0]                    slv_awsnoop,
    //ccx_tgl: ; slv_awatop[2:1]; ; Not supported, we only support AtomicSwap, AtomicCompare and AtomicStore (Operation -> ADD)
    input [5:0]                                           slv_awatop,

    // AXI slave Write data channel
    input [`SLAVE_BUS_DATA_WIDTH-1:0]                     slv_wdata,
    input [`CC_SLV_W_USER_WIDTH-1:0]                      slv_wuser,
    input [`CC_SLV_BUS_WSTRB_WIDTH -1:0]                  slv_wstrb,
    input                                                 slv_wlast,
    input                                                 slv_wvalid,
    input                                                 slv_wmisc_info_ep,
    input                                                 slv_wmisc_info_silentDrop,
    output                                                slv_wready,

    // AXI slave Write response channel
    output [`CC_SLV_BUS_ID_WIDTH-1:0]                     slv_bid,
    output [`CC_AXIJ_DMWR_VALUE+1:0]                      slv_bresp,
    output                                                slv_bvalid,
    output [`SLV_RESP_MISC_INFO_PW-1:0]                   slv_bmisc_info,
    output [8:0]                                          slv_bmisc_info_dst_segment,
    output [7:0]                                          slv_bmisc_info_cpl_segment,
    input                                                 slv_bready,

    // AXI slave Read address channel
    input [`CC_SLV_BUS_ID_WIDTH -1:0]                     slv_arid,
    input [`SLAVE_BUS_ADDR_WIDTH -1:0]                    slv_araddr,
    input [`CC_SLV_AR_USER_WIDTH-1:0]                     slv_aruser,
    input [`CC_SLV_INT_BURST_LEN_PW -1:0]                 slv_arlen,
    input [2:0]                                           slv_arsize,
    input [1:0]                                           slv_arburst,
    input [`CC_AXI_LOCK_WIDTH-1:0]                        slv_arlock,
    input [3:0]                                           slv_arcache,
    input [2:0]                                           slv_arprot,

//ccx_tgl: ; slv_armisc_info[24:22]; ; Function numbering of the TLP. 


    input [`SLV_MISC_INFO_PW -1:0]                        slv_armisc_info,
    input                                                 slv_armisc_info_nw,
    input [1:0]                                           slv_armisc_info_ats,
    input [PRFX_WIDTH-1:0]                                slv_armisc_info_tlpprfx,
    input [MISC_INFO_TPH_WD-1:0]                          slv_armisc_info_tph,
    input                                                 slv_armisc_info_atu_bypass,
    input                                                 slv_armisc_info_ido,
    input [8:0]                                           slv_armisc_info_dst_segment,
    input                                                 slv_arvalid,
    output                                                slv_arready,
    input [3:0]                                           slv_arqos,
    //ccx_tgl: ; slv_arbar[1:0]; ; Not supported. The AXI bridge subordinate does not implement ACE; it ignores the value of the DOMAIN, BAR and SNOOP fields.
    input [1:0]                                           slv_arbar,
    input [1:0]                                           slv_ardomain,
    //ccx_tgl: ; slv_arsnoop[3:0]; ; Not supported. The AXI bridge subordinate does not implement ACE; it ignores the value of the DOMAIN, BAR and SNOOP fields.
    input [3:0]                                           slv_arsnoop,

    // AXI slave Read data channel
    output [`CC_SLV_BUS_ID_WIDTH -1:0]                    slv_rid,
    output [`SLAVE_BUS_DATA_WIDTH-1:0]                    slv_rdata,
    output [`CC_SLV_R_USER_WIDTH-1:0]                     slv_ruser,
    output [1:0]                                          slv_rresp,
    output                                                slv_rlast,
    output                                                slv_rvalid,
    output [`SLV_RESP_MISC_INFO_PW -1:0]                  slv_rmisc_info,
    output                                                slv_rmisc_info_ido,
    output [8:0]                                          slv_rmisc_info_dst_segment,
    output [7:0]                                          slv_rmisc_info_cpl_segment,
    input                                                 slv_rready,

    // AXI slave Low-power Channel
    output                                                slv_csysack,
    output                                                slv_cactive,


    // ***************************************************
    // AXI DBI slave interface
    // AXI DBI slave Write address channel


    // ***************************************************
    // Misc IOs
    input                                                 core_clk,
    input                                                 core_rst_n,
    input [5:0]                                           cfg_slv_resp_err_map,
    // from CDM

//ccx_tgl: ; cfg_max_rd_req_size[2]; ; The configured read request size cannot be greater than the CC_SLV_RD_REQ_SIZE parameter

    input [(3*`CX_NFUNC)-1:0]                             cfg_max_rd_req_size, // Maximum read request size
    input                                                 cfg_ext_tag_en,
    input                                                 cfg_10b_tag_en,
    input                                                 cfg_dmwr_req_en, // When asserted allows Deferrable Memory Write requests to be issued using the AXI slave
    input                                                 cfg_memtype_value,
    input [`FLT_Q_ADDR_WIDTH-3:0]                         cfg_memtype_boundary,

//ccx_tgl: ; cfg_max_payload_size[2]; ; The configured maximum payload size cannot be greater than the CX_MAX_MTU parameter

    input [(3*`CX_NFUNC)-1:0]                             cfg_max_payload_size, // Maximum MTU size
    input [4:0]                                           cfg_err_resp_mode,
    input                                                 cfg_ax_snp_en,
    input [3:0]                                           cfg_mstr_arcache_mode, // qs
    input [3:0]                                           cfg_mstr_awcache_mode, // qs
    input [3:0]                                           cfg_mstr_arcache_value, // qs
    input [3:0]                                           cfg_mstr_awcache_value, //qs
    input [31:0]                                          cfg_aximstr_msg_addr_high, //qs
    input [31:0]                                          cfg_aximstr_msg_addr_low, //qs
    input [1:0]                                           cfg_mstr_ardomain_mode,
    input [1:0]                                           cfg_mstr_awdomain_mode,
    input [1:0]                                           cfg_mstr_ardomain_value,
    input [1:0]                                           cfg_mstr_awdomain_value,
    

//ccx_tgl: ; cfg_ax_mstr_np_pass_p[7:1]; ; Only 1 Virtual Functions supported 


    input [7:0]                                           cfg_ax_mstr_np_pass_p,
    input [1:0]                                           cfg_ax_mstr_ordr_p_event_sel,
    input                                                 cfg_ax_mstr_zeroread_fw, //When asserted forwards IB zero length reads into the Master
    input [7:0]                                           cfg_ax_ib_cpl_pass_p,
    input cdmIbrPIdMngCtrl_s                              cfg_ib_p_id_mng_ctrl,
    input [23:0]                                          cfg_tc_struc_vc_map,
    input [`N_XADM_P_IF-1:0]                               xali_posted_tlp_sent,
    input [`CX_ATU_BASE_WIDTH*ATU_OUT_NREGIONS_MIN1-1:0]  atu_reg_out_upr_base,
    input [ATU_OUT_NREGIONS_MIN1-1:0]                     atu_reg_out_en,

//ccx_tgl: ; atu_reg_out_type[3]; ; Bit 3 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[8]; ; Bit 8 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[13]; ; Bit 13 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[18]; ; Bit 18 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[23]; ; Bit 23 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[28]; ; Bit 28 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[33]; ; Bit 33 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[38]; ; Bit 38 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[43]; ; Bit 43 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[48]; ; Bit 48 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[53]; ; Bit 53 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[58]; ; Bit 58 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[63]; ; Bit 63 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[68]; ; Bit 68 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[73]; ; Bit 73 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 
//ccx_tgl: ; atu_reg_out_type[78]; ; Bit 78 (Posted) is always 0. Completions and AtomicOp are not subject of ATU processing. 


    input [5*ATU_OUT_NREGIONS_MIN1-1:0]                            atu_reg_out_type,
    input [`CX_ATU_REGION_WIDTH*ATU_OUT_NREGIONS_MIN1-1:0]         atu_reg_out_base,
    input [`CX_ATU_REGION_WIDTH*ATU_OUT_NREGIONS_MIN1-1:0]         atu_reg_out_limit,
    input [`CX_ATU_MAX_REGION_SIZE*ATU_OUT_NREGIONS_MIN1-1:0]      atu_reg_out_uppr_limit,
    input [ATU_OUT_NREGIONS_MIN1-1:0]                              atu_reg_out_incr_rgn_size, // Maximum region size control bit
    input [ATU_OUT_NREGIONS_MIN1-1:0]                              atu_reg_out_invert,

//ccx_tgl: ; atu_reg_out_func_num; ; When the Number of Functions is equals to 1 this signal won't toggle.

    input [`CX_NFUNC_WD*ATU_OUT_NREGIONS_MIN1-1:0]                 atu_reg_out_func_num,
    input [ATU_OUT_NREGIONS_MIN1-1:0]                              atu_reg_out_func_bypass,
    input [ATU_OUT_NREGIONS_MIN1-1:0]                              atu_reg_out_snp,

    // ***************************************************
    // RAS.DP IO
    // ***************************************************
    input                                                 cfg_rasdp_err_mode,
    input                                                 cfg_rasdp_err_mode_en,

    output ras_dp_err_log_t                               axi_bridge_out_ras_dp_err_log,
    input  ras_dp_err_inj_t                               axi_bridge_in_ras_dp_err_inj,
    input  logic                                          axi_bridge_in_ras_dp_err_inj_wake_up,
    // RAS ECC RAM interface
    input                                                 cfg_ras_recc_npw_sab_correct,
    output wire                                           axi_ras_recc_corr_cnt_npw_sab_pulse,
    //ccx_tgl: ; axi_ras_recc_corr_cnt_npw_sab_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
    output wire [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]         axi_ras_recc_corr_cnt_npw_sab_addr,
    //ccx_tgl: ; axi_ras_recc_ucorr_cnt_npw_sab_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    output wire                                           axi_ras_recc_ucorr_cnt_npw_sab_pulse,
    //ccx_tgl: ; axi_ras_recc_ucorr_cnt_npw_sab_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
    output wire [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]         axi_ras_recc_ucorr_cnt_npw_sab_addr,
    input                                                 cfg_ras_recc_ob_npdcmp_correct,
    //ccx_tgl: ; axi_ras_recc_corr_cnt_ob_npdcmp_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    output wire                                           axi_ras_recc_corr_cnt_ob_npdcmp_pulse,
    output wire [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]           axi_ras_recc_corr_cnt_ob_npdcmp_addr,
    //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    output wire                                           axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse,
    output wire [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]           axi_ras_recc_ucorr_cnt_ob_npdcmp_addr,
    input                                                 cfg_ras_recc_ob_pdcmp_hdr_correct,
    output wire                                           axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse,
    output wire [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]        axi_ras_recc_corr_cnt_ob_pdcmp_hdr_addr,
    
    //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    output wire                                           axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse,
    output wire [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]        axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_addr,

    input                                                 cfg_ras_recc_ob_pdcmp_data_correct,
    output wire                                           axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse,
    output wire [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]       axi_ras_recc_corr_cnt_ob_pdcmp_data_addr,
    //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    output wire                                           axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse,
    output wire [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]       axi_ras_recc_ucorr_cnt_ob_pdcmp_data_addr,

    input                                                 cfg_ras_recc_ob_ccmp_data_correct,
    output wire                                           axi_ras_recc_corr_cnt_ob_ccmp_data_pulse,
    //ccx_tgl: ; axi_ras_recc_corr_cnt_ob_ccmp_data_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
    output wire [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]        axi_ras_recc_corr_cnt_ob_ccmp_data_addr,
    output wire                                           axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse,
    //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
    output wire [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]        axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr,

    //ccx_tgl: ; cfg_ras_recc_ib_sch_p_hdr_correct; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    input                                                 cfg_ras_recc_ib_sch_p_hdr_correct,
    output wire                                           axi_ras_recc_corr_cnt_ib_sch_p_hdr_pulse,
    output wire [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]  axi_ras_recc_corr_cnt_ib_sch_p_hdr_addr,
    //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    output wire                                           axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse,
    output wire [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]  axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_addr,
    //ccx_tgl: ; cfg_ras_recc_ib_sch_p_data_correct; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    input                                                 cfg_ras_recc_ib_sch_p_data_correct,
    output wire                                           axi_ras_recc_corr_cnt_ib_sch_p_data_pulse,
    output wire [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0] axi_ras_recc_corr_cnt_ib_sch_p_data_addr,
    output wire                                           axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse,
    output wire [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0] axi_ras_recc_ucorr_cnt_ib_sch_p_data_addr,
    //ccx_tgl: ; cfg_ras_recc_ib_sch_np_hdr_correct; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    input                                                 cfg_ras_recc_ib_sch_np_hdr_correct,
    output wire                                           axi_ras_recc_corr_cnt_ib_sch_np_hdr_pulse,
    output wire [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0] axi_ras_recc_corr_cnt_ib_sch_np_hdr_addr,
    //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    output wire                                           axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse,
    output wire [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0] axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_addr,
    //ccx_tgl: ; cfg_ras_recc_ib_sch_np_data_correct; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    input                                                 cfg_ras_recc_ib_sch_np_data_correct,
    output wire                                           axi_ras_recc_corr_cnt_ib_sch_np_data_pulse,
    //ccx_tgl: ; axi_ras_recc_corr_cnt_ib_sch_np_data_addr; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    output wire [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]axi_ras_recc_corr_cnt_ib_sch_np_data_addr,
    //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    output wire                                           axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse,
    //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    output wire [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr,
    //ccx_tgl: ; cfg_ras_recc_ib_rreq_c2a_cdc_correct; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    input                                                 cfg_ras_recc_ib_rreq_c2a_cdc_correct,
    output wire                                           axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse,
    //ccx_tgl: ; axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
    output wire [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]       axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr,
    output wire                                           axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse,
    //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
    output wire [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]       axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr,

    //ccx_tgl: ; cfg_ras_recc_ib_wreq_c2a_cdc_correct; ; For Gen6 configs this signals should not be present. Refer JIRA P80001562-464098.
    input                                                 cfg_ras_recc_ib_wreq_c2a_cdc_correct,
    output wire                                           axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse,
    //ccx_tgl: ; axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
    output wire [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]       axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr,
    output wire                                           axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse,
    //ccx_tgl: ; axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr; ; Randomization of access issue, will be covered by running the regression multiple times.
    output wire [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]       axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr,


    input                                                 cfg_ras_recc_ib_mcpl_a2c_cdc_correct,
    output wire                                           axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse,
    output wire [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]         axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_addr,
    output wire                                           axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse,
    output wire [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]         axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_addr,



    input                                                 cfg_ras_recc_ib_mcpl_sb_correct,
    output wire                                           axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse,
    output wire [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]     axi_ras_recc_corr_cnt_ib_mcpl_sb_addr,
    output wire                                           axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse,
    output wire [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]     axi_ras_recc_ucorr_cnt_ib_mcpl_sb_addr,


    //RAS Parity interface
    output wire                                           axi_ras_par_rtrgt_p_ad_pulse,
    output wire                                           axi_ras_par_rtrgt_p_dt_pulse,
    output wire                                           axi_ras_par_rtrgt_np_ad_pulse,
    output wire                                           axi_ras_par_rtrgt_np_dt_pulse,
    output wire                                           axi_ras_par_rtrgt_cpl_ad_pulse,
    output wire                                           axi_ras_par_rtrgt_cpl_dt_pulse,
    output wire                                           axi_ras_par_ib_mcpl_dt_pulse,




    output wire                                           axi_ras_par_ibwr_dcmp_dt_pulse,
    output wire                                           axi_ras_par_ibwr_dcmp_ad_pulse,
    output wire                                           axi_ras_par_ibrd_dcmp_ad_pulse,

    //ccx_tgl: ; axi_slv_sisb_uncorr_pulse; ; Missing stimulus, refer JIRA P80001562-408415.
    output                                                axi_slv_sisb_uncorr_pulse,
    //ccx_tgl: ; axi_mstr_misb_uncorr_pulse; ; Missing stimulus, refer JIRA P80001562-408415.
    output                                                axi_mstr_misb_uncorr_pulse,

    output wire                                           axi_ras_par_ib_sch_p_ad_pulse,
    output wire                                           axi_ras_par_ib_sch_p_dt_pulse,
    output wire                                           axi_ras_par_ib_sch_np_ad_pulse,
    output wire                                           axi_ras_par_ib_sch_np_dt_pulse,
    output wire                                           axi_ras_par_ib_mcpl_a2c_dt_pulse,
    output wire                                           axi_ras_par_ib_mcpl_sb_dt_pulse,

    output wire                                           axi_ras_par_ibwq_mrf_dt_pulse,
    output wire                                           axi_ras_par_ibwq_mrf_ad_pulse,
    output wire                                           axi_ras_par_ibrd_mrf_ad_pulse,

    output wire                                           axi_ras_par_npqdec_ad_pulse,

    output wire                                           axi_ras_par_pqdec_ad_pulse,
    output wire                                           axi_ras_par_swwrap_dt_pulse,
    output wire                                           axi_ras_par_swwrap_ad_pulse,
    output wire                                           axi_ras_par_srwrap_ad_pulse,
    //ccx_tgl: ; axi_ras_par_swrq_npw_dt_pulse; ; Missing stimulus, refer JIRA P80001562-408415.
    output wire                                           axi_ras_par_swrq_npw_dt_pulse,
    output wire                                           axi_ras_par_swrq_npw_ad_pulse,

    output wire                                           axi_ras_par_slnull_dt_pulse,
    output wire                                           axi_ras_par_slnull_ad_pulse,

    output wire                                           axi_ras_par_c2_ad_pulse,
    output wire                                           axi_ras_par_c2_dt_pulse,
    output wire                                           axi_ras_par_c1_ad_pulse,
    output wire                                           axi_ras_par_c1_dt_pulse,

    output wire                                           axi_ras_par_ob_np_dcmp_inq_dt_pulse,
    output wire                                           axi_ras_par_ob_p_dcmp_inq_dt_pulse,
    output wire                                           axi_ras_par_ob_cpl_comp_dt_pulse,



  // -------------------------------------------------------------------------------------
  // DMA RD Engine LL back-pressure signal
  // -------------------------------------------------------------------------------------
    input [`CC_NUM_DMA_RD_CHAN-1:0]                        dma_mcb_rdll_halt,
    input [`CC_NUM_DMA_WR_CHAN-1:0]                        dma_mcb_wrll_halt,

    output xali_pkt_t[`N_XALI_IF-1:0]                      xali_xaim_pkt,
    input logic[`N_XALI_IF-1:0]                            xaim_xali_halt,
    // -------------------------------------------------------------------------------------
    // RADM interfaces
    input                                                 radm_cpl_timeout, // CPL is timeout
    input [2:0]                                           radm_timeout_cpl_tc, // Timeout CPL tc
    input [1:0]                                           radm_timeout_cpl_attr, // Timeout CPL attributes

//ccx_tgl: ; radm_timeout_cpl_tag[13:9]; ; The CX_MAX_TAG controls the maximum number of tags.

    input [`CX_TAG_SIZE-1:0]                              radm_timeout_cpl_tag, // Timeout CPL tag
    input [`CX_NFUNC_WD-1:0]                              radm_timeout_func_num, // Timeout cpl function id

    input [`CX_REMOTE_LOOKUPID_WD-1:0]             trgt_lookup_id,

    input                                          radm_trgt1_p_0_pending,

    input [`TRGT_DATA_WD-1:0]                      radm_trgt1_p_0_data,
    input [`CX_RASDP_TRGT1_P_HDR_PROT_WD-1:0]      radm_trgt1_p_0_hdr_prot,
    input [PRFX_W_PAR-1:0]                         radm_trgt1_p_0_prfx,
    input [`CX_NW-1:0]                             radm_trgt1_p_0_dwen,
    input                                          radm_trgt1_p_0_dv,
    input                                          radm_trgt1_p_0_hv,
    input                                          radm_trgt1_p_0_eot,
    input                                          radm_trgt1_p_0_dllp_abort,
    input                                          radm_trgt1_p_0_tlp_abort,
    input                                          radm_trgt1_p_0_ecrc_err,
    input [1:0]                                    radm_trgt1_p_0_fmt,
    //ccx_tgl: ; radm_trgt1_p_0_type[3]; ; No completions for TRGT1.
    input [4:0]                                    radm_trgt1_p_0_type,
    input [2:0]                                    radm_trgt1_p_0_tc,
    input [`FLT_Q_ATTR_WIDTH-1:0]                  radm_trgt1_p_0_attr,
    input [15:0]                                   radm_trgt1_p_0_reqid,
    input [`CX_TAG_SIZE-1:0]                       radm_trgt1_p_0_tag,
    input [`CX_NFUNC_WD-1:0]                       radm_trgt1_p_0_func_num,
    input                                          radm_trgt1_p_0_td,
    input [2:0]                                    radm_trgt1_p_0_cpl_status,
    input                                          radm_trgt1_p_0_poisoned,
    input [9:0]                                    radm_trgt1_p_0_dw_len,
    input [3:0]                                    radm_trgt1_p_0_first_be,
    input [`CX_NVC_LOG2-1:0]                       radm_trgt1_p_0_vc_num,
    input [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_p_0_addr,
    input [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_p_0_hdr_uppr_bytes,
    input                                          radm_trgt1_p_0_rom_in_range,
    input                                          radm_trgt1_p_0_io_req_in_range,
    input [2:0]                                    radm_trgt1_p_0_in_membar_range,
    input [3:0]                                    radm_trgt1_p_0_last_be,
    input [1:0]                                    radm_trgt1_p_0_ats,
    input                                          radm_trgt1_p_0_nw,
    input                                          radm_trgt1_p_0_th,
    input [1:0]                                    radm_trgt1_p_0_ph,
    input [7:0]                                    radm_trgt1_p_0_st,
    input                                          radm_trgt1_p_0_hdr_uppr_bytes_valid,
    input [`DC_DMA_TYPE_WIDTH-1:0]                 radm_trgt1_p_0_req_dma,
    input [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]         radm_trgt1_p_0_req_dma_channel,
    input                                          radm_trgt1_p_0_req_dma_mem_type,
    input [8:0]                                    radm_trgt1_p_0_reqtr_sgmt,
    input [8:0]                                    radm_trgt1_p_0_dest_sgmt,
    input [`CC_AMBA_TLP_SEQ_WD-1:0]                radm_trgt1_p_0_pkt_order_no,
    input [`TRGT_DATA_WD-1:0]                      radm_trgt1_np_0_data,
    input [`CX_RASDP_TRGT1_NP_HDR_PROT_WD-1:0]     radm_trgt1_np_0_hdr_prot,
    input [PRFX_W_PAR-1:0]                         radm_trgt1_np_0_prfx,
    input [`CX_NW-1:0]                             radm_trgt1_np_0_dwen,
    input                                          radm_trgt1_np_0_dv,
    input                                          radm_trgt1_np_0_hv,
    input                                          radm_trgt1_np_0_eot,
    input                                          radm_trgt1_np_0_dllp_abort,
    input                                          radm_trgt1_np_0_tlp_abort,
    input                                          radm_trgt1_np_0_ecrc_err,
    input [1:0]                                    radm_trgt1_np_0_fmt,
    input [4:0]                                    radm_trgt1_np_0_type,
    input [2:0]                                    radm_trgt1_np_0_tc,
    input [`FLT_Q_ATTR_WIDTH-1:0]                  radm_trgt1_np_0_attr,
    input [15:0]                                   radm_trgt1_np_0_reqid,
    input [`CX_TAG_SIZE-1:0]                       radm_trgt1_np_0_tag,
    input [`CX_NFUNC_WD-1:0]                       radm_trgt1_np_0_func_num,
    input [2:0]                                    radm_trgt1_np_0_cpl_status,
    input                                          radm_trgt1_np_0_td,
    input                                          radm_trgt1_np_0_poisoned,
    input [9:0]                                    radm_trgt1_np_0_dw_len,
    input [3:0]                                    radm_trgt1_np_0_first_be,
    input [`CX_NVC_LOG2-1:0]                       radm_trgt1_np_0_vc_num,

    input [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_np_0_addr,
    input [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_np_0_hdr_uppr_bytes,

    input                                          radm_trgt1_np_0_rom_in_range,
    input                                          radm_trgt1_np_0_io_req_in_range,
    input [2:0]                                    radm_trgt1_np_0_in_membar_range,
    input [3:0]                                    radm_trgt1_np_0_last_be,
    input [1:0]                                    radm_trgt1_np_0_ats,
    input                                          radm_trgt1_np_0_nw,
    //ccx_tgl: ; radm_trgt1_np_0_cxlsrc; ; This signal is tied to zero for DTI Version 1.
    input                                          radm_trgt1_np_0_cxlsrc,
    input                                          radm_trgt1_np_0_th,
    input [1:0]                                    radm_trgt1_np_0_ph,
    input [7:0]                                    radm_trgt1_np_0_st,
    input [`DC_DMA_TYPE_WIDTH-1:0]                 radm_trgt1_np_0_req_dma,
    input [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]         radm_trgt1_np_0_req_dma_channel,
    input                                          radm_trgt1_np_0_req_dma_mem_type,

    input [8:0]                                    radm_trgt1_np_0_reqtr_sgmt,
    input [8:0]                                    radm_trgt1_np_0_dest_sgmt,
    input [`CC_AMBA_TLP_SEQ_WD-1:0]                radm_trgt1_np_0_pkt_order_no,

    input [`TRGT_DATA_WD-1:0]                      radm_trgt1_cpl_0_data,
    input [`CX_RASDP_TRGT1_CPL_HDR_PROT_WD-1:0]    radm_trgt1_cpl_0_hdr_prot,
    input [PRFX_W_PAR-1:0]                         radm_trgt1_cpl_0_prfx,
    input [`CX_NW-1:0]                             radm_trgt1_cpl_0_dwen,
    input                                          radm_trgt1_cpl_0_dv,
    input                                          radm_trgt1_cpl_0_hv,
    input                                          radm_trgt1_cpl_0_eot,
    input                                          radm_trgt1_cpl_0_dllp_abort,
    input                                          radm_trgt1_cpl_0_tlp_abort,
    input                                          radm_trgt1_cpl_0_ecrc_err,
//ccx_tgl: ; radm_trgt1_cpl_0_fmt[0]; ; Unreachable due Completion type, because all completions are 3DW.
    input [1:0]                                    radm_trgt1_cpl_0_fmt,
    //ccx_tgl: ; radm_trgt1_cpl_0_type[4:1]; ; For Completions, this bits are always 0.
    input [4:0]                                    radm_trgt1_cpl_0_type,
    input [2:0]                                    radm_trgt1_cpl_0_tc,
    input [`FLT_Q_ATTR_WIDTH-1:0]                  radm_trgt1_cpl_0_attr,
    input [15:0]                                   radm_trgt1_cpl_0_reqid,
    input [`CX_TAG_SIZE-1:0]                       radm_trgt1_cpl_0_tag,
    input [`CX_NFUNC_WD-1:0]                       radm_trgt1_cpl_0_func_num,
    input [2:0]                                    radm_trgt1_cpl_0_cpl_status,
    input                                          radm_trgt1_cpl_0_td,
    input                                          radm_trgt1_cpl_0_poisoned,
    input [9:0]                                    radm_trgt1_cpl_0_dw_len,
    //ccx_tgl: ; radm_trgt1_cpl_0_bcm; ; The Byte Count Modified bit is not applicable for an endpoint device.
    input                                          radm_trgt1_cpl_0_bcm,

//ccx_tgl: ; radm_trgt1_cpl_0_byte_cnt[11:10]; ; The largest packet payload that the device supports is 9.

    input [11:0]                                   radm_trgt1_cpl_0_byte_cnt,
    input [15:0]                                   radm_trgt1_cpl_0_cmpltr_id,
    input                                          radm_trgt1_cpl_0_last,
    input [`CX_NVC_LOG2-1:0]                       radm_trgt1_cpl_0_vc_num,

    input [`FLT_Q_ADDR_WIDTH-1:0]                  radm_trgt1_cpl_0_addr,

    input [8:0]                                    radm_trgt1_cpl_0_dest_sgmt,
    input [7:0]                                    radm_trgt1_cpl_0_cpl_sgmt,
    input [`CC_AMBA_TLP_SEQ_WD-1:0]                radm_trgt1_cpl_0_pkt_order_no,

    output wire                                    trgt1_radm_intf_cpl_0_halt,
    output wire                                    trgt1_radm_intf_p_0_halt,
    output wire                                    trgt1_radm_intf_np_0_halt,

    // -------------------------------------------------------------------------------------
    // Inbound Posted Write Response
    // -------------------------------------------------------------------------------------


//ccx_tgl: ; trgt1_radm_pkt_halt[0]; ; Bit 0 (Posted) is always 0
//ccx_tgl: ; trgt1_radm_pkt_halt[2]; ; Bit 2 (CPLs) should only be included if the CPL Queue Mode is not in Bypass mode and Segmented Buffer is used for the Receive Queues

    output [(`CX_NVC*3)-1:0]                              trgt1_radm_pkt_halt, // halt from application to radm
    output                                                d_trgt1_radm_dma_pkt_halt, // halt from application to DMA

    // -------------------------------------------------------------------------------------
    // DB Interface
    input                                                 dbi_ack, // When asserted, indicates that the read/write operation
    // is completed.
    input [31:0]                                          dbi_dout, // Register read back data bus
    
    //ccx_tgl: ; dbi_addr[1:0]; ; The DBI address must be a DWORD address (*addr[1:0] =2b00)


//ccx_tgl: ; dbi_addr[18:16]; ; This bits depend on the number of functions, when the No. of funtions is 1 this bits wont toggle. 


    output [31:0]                                         dbi_addr, // address in DBI interface
    output [31:0]                                         dbi_din, // input data in DBI interface
    output                                                dbi_cs, // Chip select to program configuration space registers
    output                                                dbi_cs2, // Chip select2 input for DBI bus.  Used for changing
    // BAR mask/size in CDM.
    output [3:0]                                          dbi_wr, // Byte write enable
    // 4'b0000: read
    // 4'b1111: write the entire DW
    output [2:0]                                          dbi_bar_num, // BAR number of the DBI access
    //ccx_tgl: ; dbi_func_num; ; When the CX_NFUNC parameter equals 1 this signal won't toggle.


//ccx_tgl: ; dbi_func_num[3:1]; ; The number of functions is controled by the CX_NFUNC parameter.

    output [`CX_NFUNC_WD-1:0]                             dbi_func_num, // Function number of the DBI access
    output                                                dbi_rom_access, // ROM BAR of the DBI access
    output                                                dbi_io_access, // IO BAR of the DBI access

    // -------------------------------------------------------------------------------------
    // RAM interface for application that has RAM outside
    output [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]                ob_npdcmp_ram_addra,
    output                                                ob_npdcmp_ram_wea,
    //ccx_tgl: ; ob_npdcmp_ram_dina; ; Randomization of access to the RAM.
    output [`CC_OB_NPDCMP_RAM_DATA_WD-1:0]                ob_npdcmp_ram_dina,
    output [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]                ob_npdcmp_ram_addrb,
    output                                                ob_npdcmp_ram_enb,
    input [`CC_OB_NPDCMP_RAM_DATA_WD-1:0]                 ob_npdcmp_ram_doutb,
    output [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]             ob_pdcmp_hdr_ram_addra,
    output                                                ob_pdcmp_hdr_ram_wea,
    //ccx_tgl: ; ob_pdcmp_hdr_ram_dina; ; Randomization of access to the RAM.
    output [`CC_OB_PDCMP_HDR_RAM_DATA_WD-1:0]             ob_pdcmp_hdr_ram_dina,
    output [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]             ob_pdcmp_hdr_ram_addrb,
    output                                                ob_pdcmp_hdr_ram_enb,
    input [`CC_OB_PDCMP_HDR_RAM_DATA_WD-1:0]              ob_pdcmp_hdr_ram_doutb,

    output [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]            ob_pdcmp_data_ram_addra,
    output                                                ob_pdcmp_data_ram_wea,
    output [`CC_OB_PDCMP_DATA_RAM_DATA_WD-1:0]            ob_pdcmp_data_ram_dina,
    output [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]            ob_pdcmp_data_ram_addrb,
    output                                                ob_pdcmp_data_ram_enb,
    input [`CC_OB_PDCMP_DATA_RAM_DATA_WD-1:0]             ob_pdcmp_data_ram_doutb,

    // Slave Non-Posted Write Set-Aside RAM
    output [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]              slv_npw_sab_ram_addra,
    output                                                slv_npw_sab_ram_wea,
    //ccx_tgl: ; slv_npw_sab_ram_dina; ; Randomization of access to the RAM.
    output [`CC_SLV_NPW_SAB_RAM_DATA_WD-1:0]              slv_npw_sab_ram_dina,
    output [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]              slv_npw_sab_ram_addrb,
    output                                                slv_npw_sab_ram_enb,
    input [`CC_SLV_NPW_SAB_RAM_DATA_WD-1:0]               slv_npw_sab_ram_doutb,



    output [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]            ib_rreq_c2a_cdc_ram_addra,
    output [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]            ib_rreq_c2a_cdc_ram_addrb,
    output                                                ib_rreq_c2a_cdc_ram_wea,
    output                                                ib_rreq_c2a_cdc_ram_enb,
    input [`CC_IB_RD_REQ_CDC_RAM_DATA_WD-1:0]             ib_rreq_c2a_cdc_ram_doutb,
    //ccx_tgl: ; ib_rreq_c2a_cdc_ram_dina; ; Randomization of access to the RAM.
    output [`CC_IB_RD_REQ_CDC_RAM_DATA_WD-1:0]            ib_rreq_c2a_cdc_ram_dina,

    output [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]            ib_wreq_c2a_cdc_ram_addra,
    output [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]            ib_wreq_c2a_cdc_ram_addrb,
    output                                                ib_wreq_c2a_cdc_ram_wea,
    output                                                ib_wreq_c2a_cdc_ram_enb,
    input [`CC_IB_WR_REQ_CDC_RAM_DATA_WD-1:0]             ib_wreq_c2a_cdc_ram_doutb,
    //ccx_tgl: ; ib_wreq_c2a_cdc_ram_dina; ; Randomization of access to the RAM.
    output [`CC_IB_WR_REQ_CDC_RAM_DATA_WD-1:0]            ib_wreq_c2a_cdc_ram_dina,
    output                                                ib_scheduler_p_hdr_ram_wea,
    output [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]       ib_scheduler_p_hdr_ram_addra,
    //ccx_tgl: ; ib_scheduler_p_hdr_ram_dina; ; Randomization of access to the RAM.
    output [`CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD-1:0]       ib_scheduler_p_hdr_ram_dina,
    output [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]       ib_scheduler_p_hdr_ram_addrb,
    output                                                ib_scheduler_p_hdr_ram_enb,
    input  [`CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD-1:0]       ib_scheduler_p_hdr_ram_doutb,

    output                                                ib_scheduler_p_data_ram_wea,
    output [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]      ib_scheduler_p_data_ram_addra,
    output [`CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD-1:0]      ib_scheduler_p_data_ram_dina,
    output [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]      ib_scheduler_p_data_ram_addrb,
    output                                                ib_scheduler_p_data_ram_enb,
    input  [`CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD-1:0]      ib_scheduler_p_data_ram_doutb,

    output                                                ib_scheduler_np_hdr_ram_wea,
    output [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]      ib_scheduler_np_hdr_ram_addra,
    //ccx_tgl: ; ib_scheduler_np_hdr_ram_dina; ; Randomization of access to the RAM.
    output [`CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD-1:0]      ib_scheduler_np_hdr_ram_dina,
    output [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]      ib_scheduler_np_hdr_ram_addrb,
    output                                                ib_scheduler_np_hdr_ram_enb,
    input  [`CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD-1:0]      ib_scheduler_np_hdr_ram_doutb,

    output                                                ib_scheduler_np_data_ram_wea,
    output [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]     ib_scheduler_np_data_ram_addra,
    output [`CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD-1:0]     ib_scheduler_np_data_ram_dina,
    output [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]     ib_scheduler_np_data_ram_addrb,
    output                                                ib_scheduler_np_data_ram_enb,
    input  [`CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD-1:0]     ib_scheduler_np_data_ram_doutb,

    input [`CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]              ob_ccmp_data_ram_doutb, // Ram read data
    output [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]             ob_ccmp_data_ram_addra, // Ram port A address (write interface)
    output [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]             ob_ccmp_data_ram_addrb, // Ram port B address (read interface)
    //ccx_tgl: ; ob_ccmp_data_ram_dina; ; Randomization of access to the RAM.
    output [`CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]             ob_ccmp_data_ram_dina, // Ram write data
    output                                                ob_ccmp_data_ram_enb, // Ram port B enable (read enable)
    output                                                ob_ccmp_data_ram_wea, // Ram Port A write enable

    // Master completion buffer segment buffer RAM outputs
    output [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]          ib_mcpl_sb_ram_addra,
    output                                                ib_mcpl_sb_ram_wea,
    //ccx_tgl: ; ib_mcpl_sb_ram_dina; ; Randomization of access to the RAM.
    output [`CC_IB_MCPL_SEG_BUF_RAM_DATA_WD-1:0]          ib_mcpl_sb_ram_dina,
    output [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]          ib_mcpl_sb_ram_addrb,
    output                                                ib_mcpl_sb_ram_enb,
    input [`CC_IB_MCPL_SEG_BUF_RAM_DATA_WD-1:0]           ib_mcpl_sb_ram_doutb,
    // Master completion buffer AMBA to PCIe core clock domain crossing FIFO RAM outputs
    output [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]              ib_mcpl_a2c_cdc_ram_addra,
    output                                                ib_mcpl_a2c_cdc_ram_wea,
    //ccx_tgl: ; ib_mcpl_a2c_cdc_ram_dina[33]; ; Randomization of access to the RAM.
    //ccx_tgl: ; ib_mcpl_a2c_cdc_ram_dina[38]; ; Randomization of access to the RAM.
    output [`CC_IB_MCPL_CDC_RAM_DATA_WD-1:0]              ib_mcpl_a2c_cdc_ram_dina,
    output [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]              ib_mcpl_a2c_cdc_ram_addrb,
    output                                                ib_mcpl_a2c_cdc_ram_enb,
    input [`CC_IB_MCPL_CDC_RAM_DATA_WD-1:0]               ib_mcpl_a2c_cdc_ram_doutb,

    // -------------------------------------------------------------------------------------
    // DMA interface
    output                                                d_trgt1_wreq_cmplt_dma, // eDMA memory write request complete pulse
    output [`CC_NUM_DMA_RD_CHAN_WIDTH-1:0]                d_trgt1_wreq_cmplt_dma_channel, // eDMA memory write request complete channel number
    output                                                d_trgt1_wreq_err_dma, // eDMA memory write request error status. Valid when d_trgt1_wreq_cmplt_dma asserted.


    output                                                brdg_slv_xfer_pending,
    input                                                 app_xfer_pending,
    input                                                 brdg_mstr_xfer_pending,
    output                                                brdg_trgt1_p_xfer_done,
    input                                                 edma_xfer_pending,
    output                                                brdg_dbi_xfer_pending,
    // -------------------------------------------------------------------------------------
    // Outbound flush req/ack interface
    // -------------------------------------------------------------------------------------

    input                                                 rstctl_slv_flush_req,
    input                                                 rstctl_mstr_flush_req,
    output                                                brdg_slv_flush_ack
   // Completions Status during DPC
   ,input                                                 core_in_dpc_i
   ,input                                                 cfg_dpc_cpl_cntrl_i
); // axi_bridge

// -------------------------------------------------------------------------------------
localparam PF_WD_MIN3                = `CX_NFUNC_WD > 3 ? `CX_NFUNC_WD : 3;
localparam TLP_PREFIX_WD         = (32*`CX_NPRFX);

localparam CORE_DATA_PAR_WD          = `CC_CORE_DATA_BUS_WD - `PCIE_CORE_DATA_BUS_WD;
localparam CORE_ADDR_PAR_WD          = `CC_CORE_ADDR_BUS_WD - `FLT_Q_ADDR_WIDTH;

localparam CC_MRF_C2A_FIFO_HOLD_RD_ADDR = 1;

localparam MAX_WIRE_8BIT_TAG          = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_8BIT_TAG_HIGH        :  `CX_MAX_TAG;
localparam MAX_WIRE_8BIT_TAG_PW       = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_8BIT_TAG_HIGH_WIDTH  :  `CX_LUT_PTR_WIDTH;
localparam MAX_WIRE_10BIT_TAG     = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_10BIT_TAG_HIGH       :  `CX_MAX_TAG;
localparam MAX_WIRE_10BIT_TAG_PW  = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_10BIT_TAG_HIGH_WIDTH :  10;
localparam MAX_WIRE_TAG           = MAX_WIRE_10BIT_TAG;
localparam MAX_WIRE_TAG_PW        = MAX_WIRE_10BIT_TAG_PW;


// Mis-sampling delay for quasi static signals
localparam CC_MIS_SAMPLING_DELAY     = 3;
// -------------------------------------------------------------------------------------


    wire [`DC_DMA_TYPE_WIDTH-1:0]                       client0_tlp_dma;          assign xali_xaim_pkt[2].hdr.tlp_dma          = client0_tlp_dma;
    wire [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]               client0_tlp_dma_channel;  assign xali_xaim_pkt[2].hdr.tlp_dma_channel  = client0_tlp_dma_channel;
    wire                                                client0_tlp_prv_dma;
    wire [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]                client0_tlp_prv_dma_chan;
    wire [`DC_DMA_TYPE_WIDTH-1:0]                        client1_tlp_dma;          assign xali_xaim_pkt[1].hdr.tlp_dma          = client1_tlp_dma;
    wire [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]                client1_tlp_dma_channel;  assign xali_xaim_pkt[1].hdr.tlp_dma_channel  = client1_tlp_dma_channel;
    wire [`DC_DMA_TYPE_WIDTH-1:0]                        client2_tlp_dma;          assign xali_xaim_pkt[0].hdr.tlp_dma          = client2_tlp_dma;
    wire [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]                client2_tlp_dma_channel;  assign xali_xaim_pkt[0].hdr.tlp_dma_channel  = client2_tlp_dma_channel;
                                                                                  assign xali_xaim_pkt[0].is_dma               = |client2_tlp_dma;
                                                                                  assign xali_xaim_pkt[1].is_dma               = |client1_tlp_dma;
                                                                                  assign xali_xaim_pkt[2].is_dma               = |client0_tlp_dma;
    // -------------------------------------------------------------------------------------
    // Client 0
    wire                                                client0_addr_align_en;    assign xali_xaim_pkt[2].hdr.addr_align_en    = client0_addr_align_en;
    wire [`CX_NFUNC_WD-1:0]                             client0_tlp_func_num;     assign xali_xaim_pkt[2].hdr.tlp_func_num     = client0_tlp_func_num;
    wire [15:0]                                         client0_cpl_cmpltr_id;    assign xali_xaim_pkt[2].hdr.remote_req_id    = client0_cpl_cmpltr_id;
    wire [`DC_CPL_STATUS_WD-1:0]                        client0_cpl_status;       assign xali_xaim_pkt[2].hdr.cpl_status       = client0_cpl_status;
    wire                                                client0_cpl_bcm;          assign xali_xaim_pkt[2].hdr.cpl_bcm          = client0_cpl_bcm;
    wire [11:0]                                         client0_cpl_byte_cnt;     assign xali_xaim_pkt[2].hdr.cpl_byte_cnt     = client0_cpl_byte_cnt;
    wire                                                client0_cpl_last;         assign xali_xaim_pkt[2].hdr.cpl_last         = client0_cpl_last;
    wire                                                client0_tlp_dv;           assign xali_xaim_pkt[2].hdr.tlp_dv           = client0_tlp_dv;
    wire                                                client0_tlp_eot;          assign xali_xaim_pkt[2].hdr.tlp_eot          = client0_tlp_eot;
    wire                                                client0_tlp_bad_eot;      assign xali_xaim_pkt[2].hdr.tlp_bad_eot      = client0_tlp_bad_eot;
    wire                                                client0_tlp_hv;           assign xali_xaim_pkt[2].hdr.tlp_hv           = client0_tlp_hv;
    wire [1:0]                                          client0_tlp_fmt;          assign xali_xaim_pkt[2].hdr.tlp_fmt          = client0_tlp_fmt;
    wire [4:0]                                          client0_tlp_type;         assign xali_xaim_pkt[2].hdr.tlp_type         = client0_tlp_type;
    wire                                                client0_tlp_td;           assign xali_xaim_pkt[2].hdr.tlp_td           = client0_tlp_td;
    wire                                                client0_tlp_ep;           assign xali_xaim_pkt[2].hdr.tlp_ep           = client0_tlp_ep;
    wire [`FLT_Q_ATTR_WIDTH-1:0]                        client0_tlp_attr;         assign xali_xaim_pkt[2].hdr.tlp_attr         = client0_tlp_attr;
    wire [1:0]                                          client0_tlp_ats;          assign xali_xaim_pkt[2].hdr.tlp_ats          = client0_tlp_ats;
    wire                                                client0_tlp_nw;           assign xali_xaim_pkt[2].hdr.tlp_nw           = client0_tlp_nw;
    wire [`CX_TAG_SIZE-1:0]                             client0_tlp_tid;          assign xali_xaim_pkt[2].hdr.tlp_tid          = client0_tlp_tid;
    wire [12:0]                                         client0_tlp_byte_len;     assign xali_xaim_pkt[2].hdr.tlp_byte_len     = client0_tlp_byte_len;
    wire [63:0]                                         client0_tlp_addr;         assign xali_xaim_pkt[2].hdr.tlp_addr         = client0_tlp_addr;
    wire [`DC_CPL_BYTE_EN_WD-1:0]                       client0_tlp_byte_en;      assign xali_xaim_pkt[2].hdr.tlp_byte_en      = client0_tlp_byte_en;
    wire [`DC_TC_WD-1:0]                                client0_tlp_tc;           assign xali_xaim_pkt[2].hdr.tlp_tc           = client0_tlp_tc;
    wire [`CC_CORE_DATA_BUS_WD -1:0]                    client0_tlp_data;
                                                                                  assign {xali_xaim_pkt[2].data_prot,xali_xaim_pkt[2].data} = client0_tlp_data;
    wire [`CX_REMOTE_LOOKUPID_WD-1:0]                   client0_cpl_lookup_id;    assign xali_xaim_pkt[2].hdr.cpl_lookup_id    = client0_cpl_lookup_id;
    wire [TX_TLP_PREFIX_WD-1:0]                         client0_tlp_prfx;
                                                                                  assign xali_xaim_pkt[2].prfx                 = '0;
                                                                                  assign xali_xaim_pkt[2].prfx_prot            = (`CX_RAS_PARITY_MODE) ? {(`CX_PRFX_PAR_WD){1'b1}} : {(`CX_PRFX_PAR_WD){1'b0}} ;
    wire                                                client0_tlp_atu_bypass;   assign xali_xaim_pkt[2].hdr.tlp_atu_bypass   = client0_tlp_atu_bypass;
    wire [`CLIENT_HDR_PROT_WD-1:0]                      client0_hdr_prot;         assign xali_xaim_pkt[2].hdr_prot             = client0_hdr_prot;
    wire                                                client0_tlp_th;           assign xali_xaim_pkt[2].hdr.tlp_th           = client0_tlp_th;
    wire [1:0]                                          client0_tlp_ph;           assign xali_xaim_pkt[2].hdr.tlp_ph           = client0_tlp_ph;
    wire [7:0]                                          client0_tlp_st;           assign xali_xaim_pkt[2].hdr.tlp_st           = client0_tlp_st;
                                                                                  assign xali_xaim_pkt[2].hdr.tlp_segment      = '0;
    wire [8:0]                                          client0_tlp_dst_segment;  assign xali_xaim_pkt[2].hdr.tlp_dst_segment  = '0;
                                                                                  assign xali_xaim_pkt[2].order_seqnum         = '0;
    wire                                                xadm_client0_halt;        assign xadm_client0_halt                     = xaim_xali_halt[2];
    // -------------------------------------------------------------------------------------
    // Client 1 Interface
    wire [`CX_REMOTE_LOOKUPID_WD-1:0]                   client1_cpl_lookup_id;    assign xali_xaim_pkt[1].hdr.cpl_lookup_id    = client1_cpl_lookup_id;
    wire                                                client1_addr_align_en;    assign xali_xaim_pkt[1].hdr.addr_align_en    = client1_addr_align_en;
    wire [7:0]                                          client1_tlp_byte_en;      assign xali_xaim_pkt[1].hdr.tlp_byte_en      = client1_tlp_byte_en;
                                                                                  assign xali_xaim_pkt[1].hdr.remote_req_id    = '0;
    wire [`DC_CPL_STATUS_WD-1:0]                        client1_cpl_status;       assign xali_xaim_pkt[1].hdr.cpl_status       = client1_cpl_status;
    wire                                                client1_cpl_bcm;          assign xali_xaim_pkt[1].hdr.cpl_bcm          = client1_cpl_bcm;
    wire [11:0]                                         client1_cpl_byte_cnt;     assign xali_xaim_pkt[1].hdr.cpl_byte_cnt     = client1_cpl_byte_cnt;
                                                                                  assign xali_xaim_pkt[1].hdr.cpl_last         = '0;
    wire                                                client1_tlp_dv;           assign xali_xaim_pkt[1].hdr.tlp_dv           = client1_tlp_dv;
    wire                                                client1_tlp_eot;          assign xali_xaim_pkt[1].hdr.tlp_eot          = client1_tlp_eot;
    wire                                                client1_tlp_bad_eot;      assign xali_xaim_pkt[1].hdr.tlp_bad_eot      = client1_tlp_bad_eot;
    wire                                                client1_tlp_hv;           assign xali_xaim_pkt[1].hdr.tlp_hv           = client1_tlp_hv;
    wire [1:0]                                          client1_tlp_fmt;          assign xali_xaim_pkt[1].hdr.tlp_fmt          = client1_tlp_fmt;
    wire [4:0]                                          client1_tlp_type;         assign xali_xaim_pkt[1].hdr.tlp_type         = client1_tlp_type;
    wire [2:0]                                          client1_tlp_tc;           assign xali_xaim_pkt[1].hdr.tlp_tc           = client1_tlp_tc;
    wire                                                client1_tlp_td;           assign xali_xaim_pkt[1].hdr.tlp_td           = client1_tlp_td;
    wire                                                client1_tlp_ep;           assign xali_xaim_pkt[1].hdr.tlp_ep           = client1_tlp_ep;
    wire [`FLT_Q_ATTR_WIDTH-1:0]                        client1_tlp_attr;         assign xali_xaim_pkt[1].hdr.tlp_attr         = client1_tlp_attr;
    wire [12:0]                                         client1_tlp_byte_len;     assign xali_xaim_pkt[1].hdr.tlp_byte_len     = client1_tlp_byte_len;
    wire [`CX_TAG_SIZE-1:0]                             client1_tlp_tid;          assign xali_xaim_pkt[1].hdr.tlp_tid          = client1_tlp_tid;
    wire [63:0]                                         client1_tlp_addr;         assign xali_xaim_pkt[1].hdr.tlp_addr         = client1_tlp_addr;
    wire [`CC_CORE_DATA_BUS_WD-1:0]                     client1_tlp_data;
                                                                                  assign {xali_xaim_pkt[1].data_prot,xali_xaim_pkt[1].data} = client1_tlp_data;
    wire [15:0]                                         client1_cpl_cmpltr_id;
    wire [`CX_NFUNC_WD-1:0]                             client1_tlp_func_num;     assign xali_xaim_pkt[1].hdr.tlp_func_num     = client1_tlp_func_num;
    wire [1:0]                                          client1_tlp_ats;          assign xali_xaim_pkt[1].hdr.tlp_ats          = client1_tlp_ats;
    wire                                                client1_tlp_nw;           assign xali_xaim_pkt[1].hdr.tlp_nw           = client1_tlp_nw;
    wire                                                client1_tlp_th;           assign xali_xaim_pkt[1].hdr.tlp_th           = client1_tlp_th;
    wire [1:0]                                          client1_tlp_ph;           assign xali_xaim_pkt[1].hdr.tlp_ph           = client1_tlp_ph;
    wire [7:0]                                          client1_tlp_st;           assign xali_xaim_pkt[1].hdr.tlp_st           = client1_tlp_st;
    wire [TX_TLP_PREFIX_WD-1:0]                         client1_tlp_prfx;
                                                                                  assign {xali_xaim_pkt[1].prfx_prot,xali_xaim_pkt[1].prfx} = client1_tlp_prfx;
    wire                                                client1_tlp_atu_bypass;   assign xali_xaim_pkt[1].hdr.tlp_atu_bypass   = client1_tlp_atu_bypass;
    wire [`CLIENT_HDR_PROT_WD-1:0]                      client1_hdr_prot;         assign xali_xaim_pkt[1].hdr_prot             = client1_hdr_prot;
                                                                                  assign xali_xaim_pkt[1].hdr.tlp_segment      = '0;
    wire [8:0]                                          client1_tlp_dst_segment;  assign xali_xaim_pkt[1].hdr.tlp_dst_segment  = client1_tlp_dst_segment;
                                                                                  assign xali_xaim_pkt[1].order_seqnum         = '0;
    wire                                                xadm_client1_halt;        assign xadm_client1_halt                     = xaim_xali_halt[1];
   // -------------------------------------------------------------------------------------
    // Client2 Interface
    wire [`CX_REMOTE_LOOKUPID_WD-1:0]                   client2_cpl_lookup_id;    assign xali_xaim_pkt[0].hdr.cpl_lookup_id    = client2_cpl_lookup_id;
    wire                                                client2_addr_align_en;    assign xali_xaim_pkt[0].hdr.addr_align_en    = client2_addr_align_en;
    wire [7:0]                                          client2_tlp_byte_en;      assign xali_xaim_pkt[0].hdr.tlp_byte_en      = client2_tlp_byte_en;
    wire [15:0]                                         client2_remote_req_id;    assign xali_xaim_pkt[0].hdr.remote_req_id    = client2_remote_req_id;
    wire [`DC_CPL_STATUS_WD-1:0]                        client2_cpl_status;       assign xali_xaim_pkt[0].hdr.cpl_status       = client2_cpl_status;
    wire                                                client2_cpl_bcm;          assign xali_xaim_pkt[0].hdr.cpl_bcm          = client2_cpl_bcm;
    wire [11:0]                                         client2_cpl_byte_cnt;     assign xali_xaim_pkt[0].hdr.cpl_byte_cnt     = client2_cpl_byte_cnt;
                                                                                  assign xali_xaim_pkt[0].hdr.cpl_last         = '0;
    wire                                                client2_tlp_dv;           assign xali_xaim_pkt[0].hdr.tlp_dv           = client2_tlp_dv;
    wire                                                client2_tlp_eot;          assign xali_xaim_pkt[0].hdr.tlp_eot          = client2_tlp_eot;
    wire                                                client2_tlp_bad_eot;      assign xali_xaim_pkt[0].hdr.tlp_bad_eot      = client2_tlp_bad_eot;
    wire                                                client2_tlp_hv;           assign xali_xaim_pkt[0].hdr.tlp_hv           = client2_tlp_hv;
    wire [1:0]                                          client2_tlp_fmt;          assign xali_xaim_pkt[0].hdr.tlp_fmt          = client2_tlp_fmt;
    wire [4:0]                                          client2_tlp_type;         assign xali_xaim_pkt[0].hdr.tlp_type         = client2_tlp_type;
    wire [2:0]                                          client2_tlp_tc;           assign xali_xaim_pkt[0].hdr.tlp_tc           = client2_tlp_tc;
    wire                                                client2_tlp_td;           assign xali_xaim_pkt[0].hdr.tlp_td           = client2_tlp_td;
    wire                                                client2_tlp_ep;           assign xali_xaim_pkt[0].hdr.tlp_ep           = client2_tlp_ep;
    wire [`FLT_Q_ATTR_WIDTH-1:0]                        client2_tlp_attr;         assign xali_xaim_pkt[0].hdr.tlp_attr         = client2_tlp_attr;
    wire [12:0]                                         client2_tlp_byte_len;     assign xali_xaim_pkt[0].hdr.tlp_byte_len     = client2_tlp_byte_len;
    wire [`CX_TAG_SIZE-1:0]                             client2_tlp_tid;          assign xali_xaim_pkt[0].hdr.tlp_tid          = client2_tlp_tid;
    wire [63:0]                                         client2_tlp_addr;         assign xali_xaim_pkt[0].hdr.tlp_addr         = client2_tlp_addr;
    wire [`CC_CORE_DATA_BUS_WD-1:0]                     client2_tlp_data;
                                                                                  assign {xali_xaim_pkt[0].data_prot,xali_xaim_pkt[0].data} = client2_tlp_data;
    wire [`CX_NFUNC_WD-1:0]                             client2_tlp_func_num;     assign xali_xaim_pkt[0].hdr.tlp_func_num     = client2_tlp_func_num;
    wire [1:0]                                          client2_tlp_ats;          assign xali_xaim_pkt[0].hdr.tlp_ats          = client2_tlp_ats;
    wire                                                client2_tlp_nw;           assign xali_xaim_pkt[0].hdr.tlp_nw           = client2_tlp_nw;
    wire                                                client2_tlp_th;           assign xali_xaim_pkt[0].hdr.tlp_th           = client2_tlp_th;
    wire [1:0]                                          client2_tlp_ph;           assign xali_xaim_pkt[0].hdr.tlp_ph           = client2_tlp_ph;
    wire [7:0]                                          client2_tlp_st;           assign xali_xaim_pkt[0].hdr.tlp_st           = client2_tlp_st;
    wire [TX_TLP_PREFIX_WD-1:0]                         client2_tlp_prfx;
                                                                                  assign {xali_xaim_pkt[0].prfx_prot,xali_xaim_pkt[0].prfx} = client2_tlp_prfx;
    wire                                                client2_tlp_atu_bypass;   assign xali_xaim_pkt[0].hdr.tlp_atu_bypass   = client2_tlp_atu_bypass;
    wire [`CLIENT_HDR_PROT_WD-1:0]                      client2_hdr_prot;         assign xali_xaim_pkt[0].hdr_prot             = client2_hdr_prot;
                                                                                  assign xali_xaim_pkt[0].hdr.tlp_segment      = '0;
    wire [8:0]                                          client2_tlp_dst_segment;  assign xali_xaim_pkt[0].hdr.tlp_dst_segment  = client2_tlp_dst_segment;
                                                                                  assign xali_xaim_pkt[0].order_seqnum         = '0;
    wire                                                xadm_client2_halt;        assign xadm_client2_halt                     = xaim_xali_halt[0];

genvar gi;
generate
  for(gi=3;gi<`N_XALI_IF;gi=gi+1) begin
    assign xali_xaim_pkt[gi] = '0;
  end
endgenerate



// -------------------------------------------------------------------------------------
// Internal wires
// -------------------------------------------------------------------------------------

 `ifndef UTB_NATIVE_AXI
   wire [`DC_INBD_HEADER_PNP_1STG_WD-1:0] inbd_header_pnp_wr, s_inbd_header_pnp_wr;
   wire [HDR_UPPR_BYTES_WD-1:0]         inbd_header_pnp_wr_uppr_bytes;
   wire [`FLT_Q_ADDR_WIDTH-1:0]         s_inbd_header_pnp_wr_uppr_bytes;

   logic [`CC_CORE_DATA_BUS_WD-1:0]     inbd_data_pnp_wr;
   wire                                 inbd_halt_pnp_wr;
   wire [`DC_INBD_HEADER_PNP_1STG_WD-1:0] inbd_header_pnp_rd;
   wire                                 inbd_halt_pnp_rd;
   wire [`DC_INBD_HEADER_CPL_WD-1:0]    inbd_header_cpl;
   wire [`CC_AMBA_TLP_SEQ_WD-1:0]       inbd_header_cpl_pseq;
   wire                                 inbd_header_cpl_pass_p;
   wire [`CC_CORE_DATA_BUS_WD-1:0]      inbd_data_cpl;
   wire                                 inbd_halt_cpl;

   wire [`CX_NVC-1:0]                   trgt1_p_xfer_pend_per_vc;


wire                                    sync_mstr_aclk_gating_en;
// GENERIC Master INTERFACE
wire                                    wrq_saccept;
wire                                    wrq_svalid;
wire                                    wrq_slast;
wire    [(`CC_MSTR_BUS_DATA_WIDTH)-1:0] wrq_sdata;
wire    [(`MSTR_RESP_MISC_INFO_WD)-1:0] wrq_smisc_info;
wire    [`DC_INBD_MISCINFO_WD-1:0]      wrq_mmisc_info;
wire                                    wrq_mmem_type;
wire    [2:0]                           wrq_sresp;
wire    [(`CC_MSTR_BUS_ADDR_WIDTH)-1:0] wrq_maddr;
wire                                    wrq_mwrite;
wire    [`CC_MSTR_MTU_PW -1:0]          wrq_mlen;
wire    [(`CC_MSTR_BUS_DATA_WIDTH)-1:0] wrq_mdata;
wire    [(`CC_MSTR_BUS_WSTRB_WIDTH)-1:0]wrq_mbe;
wire    [`CC_MSTR_BE_CTRL_WIDTH-1:0]    wrq_mbe_ctrl;
wire    [`CC_MAX_MSTR_TAG_PW-1:0]       wrq_mid;
wire                                    wrq_last;

wire                                    rdq_saccept;
wire                                    rdq_svalid;
wire                                    rdq_slast;
wire    [(`CC_MSTR_BUS_DATA_WIDTH)-1:0] rdq_sdata;
wire    [(`MSTR_RESP_MISC_INFO_WD)-1:0] rdq_smisc_info;
wire    [`DC_INBD_MISCINFO_WD-1:0]      rdq_mmisc_info;
wire    [(`CC_MSTR_BUS_ADDR_WIDTH)-1:0] rdq_maddr;
wire                                    rdq_mread;
wire    [`CC_MSTR_MTU_PW -1:0]          rdq_mlen;
wire    [(`CC_MSTR_BUS_DATA_WIDTH)-1:0] rdq_mdata;
wire    [(`CC_MSTR_BUS_WSTRB_WIDTH)-1:0]rdq_mbe;
wire    [`CC_MSTR_BE_CTRL_WIDTH-1:0]    rdq_mbe_ctrl;
wire    [`CC_MAX_MSTR_TAG_PW-1:0]       rdq_mid;
wire                                    rdq_last;


  // -------------------------------------------------------------------------------------
  // Inbound decomposer PCIe NP request info interface
  // -------------------------------------------------------------------------------------
  wire                                 reqmcb_hdr_np_valid;
  wire [`CC_MAX_MSTR_TAG_PW -1:0]      reqmcb_hdr_lookupid;
  wire [`CC_MAX_MSTR_TAG_PW-1:0]       reqmcb_hdr_mstrid;
  wire                                 reqmcb_hdr_last;
  wire                                 reqmcb_hdr_ncbe;
  wire [`DC_DMA_TYPE_WIDTH-1:0]         reqmcb_hdr_dma_type;
  wire [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0] reqmcb_hdr_dma_chan;
  wire [`CX_REMOTE_RD_REQ_SIZE_PW -1:0]     reqmcb_hdr_dw_len_bytes;
  wire [`DC_MCB_MAX_CPL_NUM_BYTES_WD-2:0]   reqmcb_hdr_low_addr;
  wire [`CX_NFUNC_WD-1:0]                   reqmcb_hdr_func;

   wire                                     ibmrf_reqmcb_np_valid;
   wire [`CC_MAX_MSTR_TAG_PW-1:0]           ibmrf_reqmcb_mstrid;
   wire                                     ibmrf_reqmcb_last;


   // -------------------------------------------------------------------------------------
   // Posted Response bus
   // -------------------------------------------------------------------------------------
   wire                                       ibreq_presp_cmplt        ;
   wire [`CC_AMBA_TLP_SEQ_WD-1:0]             ibreq_presp_rpseq        ;
   wire [`CC_NUM_DMA_RD_CHAN_WIDTH-1:0]       ibreq_presp_dma_chan_num ;
   wire                                       ibreq_presp_dma_err      ;
   wire [1:0]                                 ibreq_presp_type         ;
   wire                                       ibreq_cfg_cmplt          ;
   wire [1:0]                                 ibreq_cfg_type           ;

  wire                                        sif_xfer_pending         ;
  wire                                        sif_xfer_pending_db      ;
  wire                                        w_brdg_slv_xfer_pending  ;
  wire                                        w_brdg_slv_flush_ack     ;

  ras_dp_err_inj_t                            axi_bridge_ras_dp_err_inj_core_clk;
  ras_dp_err_inj_t                            ras_dp_err_inj_slv_aclk;
  ras_dp_err_inj_t                            ras_dp_err_inj_mstr_aclk;
  ras_dp_err_inj_t                            core_clk_ordrb_ras_dp_err_inj;
  ras_dp_err_inj_t                            core_clk_high_freq_ras_dp_err_inj;
  ras_dp_err_inj_t                            core_clk_hp_mstr_ras_dp_err_inj;

  wire                                        rasdp_mstr_rasdp_err_mode;
  wire                                        rasdp_slv_rasdp_err_mode;
   wire [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]   ibreq_ras_recc_cnt_ib_rreq_c2a_cdc_addr;
   wire                                       ibreq_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse;
   wire                                       ibreq_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse;
   ras_dp_err_log_t                           rdq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log;
   ras_dp_err_log_t                           wrq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log;


   wire [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]   ibreq_ras_recc_cnt_ib_wreq_c2a_cdc_addr;
   wire                                       ibreq_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse;
   wire                                       ibreq_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse;

   wire [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]     mcb_ras_recc_cnt_ib_mcpl_a2c_cdc_addr;
   wire                                       mcb_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse;
   wire                                       mcb_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse;
   ras_dp_err_log_t                           mcb_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log;
   ras_dp_err_log_t                           mcb_ib_mcpl_a2c_dt_ras_dp_err_log;  // mstr_aclk_g ifndef CC_HIGH_FREQUENCY_AXI_MASTER


   wire [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]  ibreq_ras_recc_cnt_ib_sch_p_hdr_addr;
   wire                                           ibreq_ras_recc_corr_cnt_ib_sch_p_hdr_pulse;
   wire                                           ibreq_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse;
   wire [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0] ibreq_ras_recc_cnt_ib_sch_p_data_addr;
   wire                                           ibreq_ras_recc_corr_cnt_ib_sch_p_data_pulse;
   wire                                           ibreq_ras_recc_ucorr_cnt_ib_sch_p_data_pulse;
   wire [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0] ibreq_ras_recc_cnt_ib_sch_np_hdr_addr;
   wire                                           ibreq_ras_recc_corr_cnt_ib_sch_np_hdr_pulse;
   wire                                           ibreq_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse;
   wire [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]ibreq_ras_recc_cnt_ib_sch_np_data_addr;
   wire                                           ibreq_ras_recc_corr_cnt_ib_sch_np_data_pulse;
   wire                                           ibreq_ras_recc_ucorr_cnt_ib_sch_np_data_pulse;

   wire [`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0] mcb_ras_recc_cnt_ib_mcpl_sb_addr;
   wire                                       mcb_ras_recc_corr_cnt_ib_mcpl_sb_pulse;
   wire                                       mcb_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse;
   ras_dp_err_log_t                           axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log;
   ras_dp_err_log_t                           mcb_ib_mcpl_sb_dt_ras_dp_err_log;


   wire [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]     sif_ras_recc_cnt_npw_sab_addr;
   wire                                       sif_ras_recc_corr_cnt_npw_sab_pulse;
   wire                                       sif_ras_recc_ucorr_cnt_npw_sab_pulse;

   ras_dp_err_log_t                           sif_recc_npw_sab_ras_dp_err_log;
   wire [`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]    ob_ras_recc_cnt_ob_ccmp_data_addr;
   wire                                       ob_ras_recc_corr_cnt_ob_ccmp_data_pulse;
   wire                                       ob_ras_recc_ucorr_cnt_ob_ccmp_data_pulse;
   wire [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]       ob_ras_recc_cnt_ob_npdcmp_addr;
   wire                                       ob_ras_recc_corr_cnt_ob_npdcmp_pulse;
   wire                                       ob_ras_recc_ucorr_cnt_ob_npdcmp_pulse;
   ras_dp_err_log_t                           ob_recc_cnt_ob_npdcmp_ras_dp_err_log;
   wire [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]    ob_ras_recc_cnt_ob_pdcmp_hdr_addr;
   wire                                       ob_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse;
   wire                                       ob_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse;

   wire [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]   ob_ras_recc_cnt_ob_pdcmp_data_addr;
   wire                                       ob_ras_recc_corr_cnt_ob_pdcmp_data_pulse;
   wire                                       ob_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse;
   ras_dp_err_log_t                           ob_recc_cnt_ob_pdcmp_ras_dp_err_log;
   ras_dp_err_log_t                           ob_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log;

   wire                                       mcb_ras_par_ib_mcpl_a2c_dt_pulse;


   wire                                       ob_ras_par_ob_np_dcmp_inq_dt_pulse;
   ras_dp_err_log_t                           ob_npdcmp_inq_dt_ras_dp_err_log;

   wire                                       ob_ras_par_ob_p_dcmp_inq_dt_pulse;
   ras_dp_err_log_t                           ob_pdcmp_inq_dt_ras_dp_err_log;
   ras_dp_err_log_t                           ob_pdcmp_ad_ras_dp_err_log;

   wire                                       axigm_ras_par_ibr_rmstr_ad_pulse;
   wire                                       axigm_ras_par_ibr_wmstr_ad_pulse;
   wire                                       axigm_ras_par_ibr_wmstr_dt_pulse;
   ras_dp_err_log_t                           axigm_ibr_rmstr_ad_ras_dp_err_log;
   ras_dp_err_log_t                           axigm_ibr_wmstr_ad_ras_dp_err_log;
   ras_dp_err_log_t                           axigm_ibr_wmstr_dt_ras_dp_err_log;


   wire                                       sif_ras_par_rslv_dt_pulse;

   wire                                       sif_ras_par_slnull_ad_pulse;
   wire                                       sif_ras_par_slnull_dt_pulse;
   ras_dp_err_log_t                           sif_swrq_dt_ras_dp_err_log;
   ras_dp_err_log_t                           sif_swrq_ad_ras_dp_err_log;
   ras_dp_err_log_t                           sif_srsp_rslv_dt_ras_dp_err_log;

   wire                                       sif_ras_par_swwrap_ad_pulse;
   wire                                       sif_ras_par_swwrap_dt_pulse;
   wire                                       sif_ras_par_srwrap_ad_pulse;
   ras_dp_err_log_t                           sif_swrq_swwrap_dt_ras_dp_err_log;
   ras_dp_err_log_t                           sif_swrq_swwrap_ad_ras_dp_err_log;
   ras_dp_err_log_t                           sif_srrp_srwrap_ad_ras_dp_err_log;
   wire                                       sif_ras_par_swrq_npw_dt_pulse;
   wire                                       sif_ras_par_swrq_npw_ad_pulse;

   ras_dp_err_log_t                           sif_swrq_npw_dt_ras_dp_err_log;
   ras_dp_err_log_t                           sif_swrq_npw_ad_ras_dp_err_log;
   wire                                       ob_ras_par_npqdec_ad_pulse;
   wire                                       ob_ras_par_pqdec_ad_pulse;
   ras_dp_err_log_t                           ob_npdcmp_ad_ras_dp_err_log;

   wire                                       axi_ras_par_ob_np_dcmp_inq_dt_pulse_g;
   wire                                       axi_ras_par_ob_p_dcmp_inq_dt_pulse_g;

   wire                                       axi_ras_par_ob_cpl_comp_dt_pulse_g;
   ras_dp_err_log_t                           axi_ob_recc_cnt_ob_ccmp_dt_ras_dp_log;
   ras_dp_err_log_t                           axi_ob_cpl_comp_dt_ras_dp_err_log_g;


   wire                                       axi_ras_recc_ucorr_cnt_npw_sab_pulse_g;
   wire                                       axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse_g;
   wire                                       axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse_g;
   wire                                       axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse_g;
   wire                                       axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse_g;
   wire                                       axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse_g;
   wire                                       axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse_g;
   wire                                       axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse_g;
   wire                                       axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse_g;
   wire                                       axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse_g;
   wire                                       axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse_g;
   wire                                       axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse_g;
   wire                                           axi_ras_par_ib_sch_p_ad_pulse_g;
   wire                                           axi_ras_par_ib_sch_p_dt_pulse_g;
   wire                                           axi_ras_par_ib_sch_np_ad_pulse_g;
   wire                                           axi_ras_par_ib_sch_np_dt_pulse_g;
   wire                                       axi_ras_par_ib_mcpl_a2c_dt_pulse_g;
   wire                                       mcb_ras_par_ib_mcpl_sb_dt_pulse;
   wire                                       axi_ras_par_ib_mcpl_sb_dt_pulse_g;


   wire                                       axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse_g;
   wire                                       axi_ras_par_ib_mcpl_dt_pulse_g;
   wire                                       axi_ras_par_ibwr_dcmp_dt_pulse_g;
   wire                                       axi_ras_par_ibwr_dcmp_ad_pulse_g;
   wire                                       axi_ras_par_ibrd_dcmp_ad_pulse_g;
   ras_dp_err_log_t                           axi_ibrd_dcmp_ad_ras_dp_err_log_g; // core_clk
   ras_dp_err_log_t                           axi_ibwr_dcmp_ad_ras_dp_err_log_g; // core_clk
   ras_dp_err_log_t                           axi_trgt1_dt_ras_dp_err_log_g;
   ras_dp_err_log_t                           axi_ib_mcpl_dt_ras_dp_err_log_g;   // core_clk
   wire                                       axi_ras_par_ibwq_mrf_dt_pulse_g;
   wire                                       axi_ras_par_ibwq_mrf_ad_pulse_g;
   wire                                       axi_ras_par_ibrd_mrf_ad_pulse_g;
   ras_dp_err_log_t                           axi_mstr_req_rd_ad_ras_dp_err_log_g;
   ras_dp_err_log_t                           axi_mstr_req_wr_ad_ras_dp_err_log_g;
   ras_dp_err_log_t                           axi_mstr_req_dt_ras_dp_err_log_g;
   wire                                       axi_ras_par_ibr_rmstr_ad_pulse_g;
   wire                                       axi_ras_par_ibr_wmstr_ad_pulse_g;
   wire                                       axi_ras_par_ibr_wmstr_dt_pulse_g;
   wire                                       axi_ras_par_npqdec_ad_pulse_g;
   wire                                       axi_ras_par_pqdec_ad_pulse_g;

   wire                                       axi_ras_par_swwrap_dt_pulse_g;
   wire                                       axi_ras_par_swwrap_ad_pulse_g;
   wire                                       axi_ras_par_srwrap_ad_pulse_g;
   wire                                       axi_ras_par_swrq_npw_dt_pulse_g;
   wire                                       axi_ras_par_swrq_npw_ad_pulse_g;

   wire                                       axi_ras_par_slnull_dt_pulse_g;
   wire                                       axi_ras_par_slnull_ad_pulse_g;
   wire                                       axi_ras_par_c2_ad_pulse_g;
   wire                                       axi_ras_par_c2_dt_pulse_g;
   wire                                       axi_ras_par_c1_ad_pulse_g;
   wire                                       axi_ras_par_c1_dt_pulse_g;
  ras_dp_err_log_t                            axi_c1_dt_ras_dp_err_log_g;   // core_clk
  ras_dp_err_log_t                            axi_c2_dt_ras_dp_err_log_g;   // core_clk
  ras_dp_err_log_t                            axi_c1_ad_ras_dp_err_log_g;   // core_clk
  ras_dp_err_log_t                            axi_c2_ad_ras_dp_err_log_g;   // core_clk
   wire                                       axi_ras_par_rtrgt_p_ad_pulse_g;
   wire                                       axi_ras_par_rtrgt_p_dt_pulse_g;
   wire                                       axi_ras_par_rtrgt_np_ad_pulse_g;
   wire                                       axi_ras_par_rtrgt_np_dt_pulse_g;
   wire                                       axi_ras_par_rtrgt_cpl_ad_pulse_g;
   wire                                       axi_ras_par_rtrgt_cpl_dt_pulse_g;
  ras_dp_err_log_t                            axi_rtrgt_p_ad_ras_dp_err_log;
  ras_dp_err_log_t                            axi_rtrgt_p_dt_ras_dp_err_log;
  ras_dp_err_log_t                            axi_rtrgt_np_ad_ras_dp_err_log;
  ras_dp_err_log_t                            axi_rtrgt_np_dt_ras_dp_err_log;
  ras_dp_err_log_t                            axi_rtrgt_cpl_ad_ras_dp_err_log;
  ras_dp_err_log_t                            axi_rtrgt_cpl_dt_ras_dp_err_log;
  ras_dp_err_log_t                            axi_ib_sch_p_ad_ras_dp_err_log;
  ras_dp_err_log_t                            axi_ib_sch_p_dt_ras_dp_err_log;
  ras_dp_err_log_t                            sch_p_data_recc_corr_cnt_ras_dp_err_log;
  ras_dp_err_log_t                            sch_p_hdr_recc_corr_cnt_ras_dp_err_log;
  ras_dp_err_log_t                            axi_ib_sch_np_ad_ras_dp_err_log;
  ras_dp_err_log_t                            axi_ib_sch_np_dt_ras_dp_err_log;
  ras_dp_err_log_t                            sch_np_data_recc_corr_cnt_ras_dp_err_log;
  ras_dp_err_log_t                            sch_np_hdr_recc_corr_cnt_ras_dp_err_log;
   ras_dp_err_log_t                           axi_rbyp_ad_ras_dp_err_log_g;
   ras_dp_err_log_t                           axi_rbyp_dt_ras_dp_err_log_g;



   wire [`CC_MSTR_BUS_ADDR_WIDTH-1:0]         axigm_awaddr;
   wire [`CC_MSTR_BUS_ADDR_WIDTH-1:0]         axigm_araddr;

   wire [`CC_MSTR_BUS_DATA_WIDTH-1:0]         axigm_wdata;
   wire [`CC_MSTR_BUS_DATA_WIDTH-1:0]         prmrd_rdata;


   wire [`CC_SLV_BUS_DATA_WIDTH-1:0]          sif_rdata;

   wire [`SLAVE_BUS_ADDR_WIDTH + `CC_SLV_BUS_ADDRP_WIDTH -1:0] slv_awaddr_tmp;


  // ---------------------------------------------------------------------------
  // BCM36 for Quasi Static signals
  // ---------------------------------------------------------------------------
  wire [5:0]                                  cfg_slv_resp_err_map_a2s;
  wire [4:0]                                  cfg_err_resp_mode_a2s;


  cdmIbrPIdMngCtrl_s                          cfg_ibr_p_id_mng_ctrl_a2m;
  cdmIbPIdMngCtrl_s                           cfg_ib_p_id_mng_ctrl_a2m;

  wire                                    dtim_mstr_rasdp_err_mode;
  wire                                    dtim_slv_rasdp_err_mode;

  reg                 [`CC_AMBA_TLP_SEQ_WD-1:0] ib_last_presp_rpseq_per_vc [`CX_NVC-1:0];

  logic                                                s_client0_addr_align_en;
  logic [`CX_NFUNC_WD-1:0]                             s_client0_tlp_func_num;
  logic [15:0]                                         s_client0_cpl_cmpltr_id;
  logic [`DC_CPL_STATUS_WD-1:0]                        s_client0_cpl_status;
  logic                                                s_client0_cpl_bcm;
  logic [11:0]                                         s_client0_cpl_byte_cnt;
  logic                                                s_client0_tlp_dv;
  logic                                                s_client0_tlp_eot;
  logic                                                s_client0_tlp_bad_eot;
  logic                                                s_client0_cpl_last;
  logic                                                s_client0_tlp_hv;
  logic [1:0]                                          s_client0_tlp_fmt;
  logic [4:0]                                          s_client0_tlp_type;
  logic                                                s_client0_tlp_td;
  logic                                                s_client0_tlp_ep;
  logic [`FLT_Q_ATTR_WIDTH-1:0]                        s_client0_tlp_attr;
  logic [1:0]                                          s_client0_tlp_ats;
  logic                                                s_client0_tlp_nw;
  logic [`CX_TAG_SIZE-1:0]                             s_client0_tlp_tid;
  logic [12:0]                                         s_client0_tlp_byte_len;
  logic [63+`CX_ADDR_PAR_WD:0]                         s_client0_tlp_addr;
  logic [`DC_CPL_BYTE_EN_WD-1:0]                       s_client0_tlp_byte_en;
  logic [`DC_TC_WD-1:0]                                s_client0_tlp_tc;
  logic [`CC_CORE_DATA_BUS_WD -1:0]                    s_client0_tlp_data;
  logic                                                s_xadm_client0_halt;
  logic [`CX_REMOTE_LOOKUPID_WD-1:0]                   s_client0_cpl_lookup_id;
  logic                                                s_client0_tlp_atu_bypass;
  logic [`DC_DMA_TYPE_WIDTH-1:0]                       s_client0_tlp_dma;
  logic [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]               s_client0_tlp_dma_channel;
  logic                                                s_client0_tlp_prv_dma;
  logic [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]               s_client0_tlp_prv_dma_chan;
  logic [`DC_DMA_TYPE_WIDTH-1:0]                       s_client1_tlp_dma;
  logic [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]               s_client1_tlp_dma_channel;
  logic [`DC_DMA_TYPE_WIDTH-1:0]                       s_client2_tlp_dma;
  logic [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]               s_client2_tlp_dma_channel;
  logic [(`CX_AXI_NVC_XALI_EXPANSION*`CLIENT_HDR_PROT_WD)-1:0] s_client0_hdr_prot;
  logic                                                s_client0_tlp_th;
  logic      [1:0]                                     s_client0_tlp_ph;
  logic      [7:0]                                     s_client0_tlp_st;
  logic [8:0]                                          s_client0_tlp_dst_segment;

  logic                                                s_client1_addr_align_en;
  logic [`CX_NFUNC_WD-1:0]                             s_client1_tlp_func_num;
  logic [15:0]                                         s_client1_cpl_cmpltr_id;
  logic [`DC_CPL_STATUS_WD-1:0]                        s_client1_cpl_status;
  logic                                                s_client1_cpl_bcm;
  logic [11:0]                                         s_client1_cpl_byte_cnt;
  logic                                                s_client1_tlp_dv;
  logic                                                s_client1_tlp_eot;
  logic                                                s_client1_tlp_bad_eot;
  logic                                                s_client1_tlp_hv;
  logic [1:0]                                          s_client1_tlp_fmt;
  logic [4:0]                                          s_client1_tlp_type;
  logic                                                s_client1_tlp_td;
  logic                                                s_client1_tlp_ep;
  logic [`FLT_Q_ATTR_WIDTH-1:0]                        s_client1_tlp_attr;
  logic                                                s_client1_tlp_nw;
  logic [1:0]                                          s_client1_tlp_ats;
  logic [8:0]                                          s_client1_tlp_dst_segment;
  logic [`CX_TAG_SIZE-1:0]                             s_client1_tlp_tid;
  logic [12:0]                                         s_client1_tlp_byte_len;
  logic [63+`CX_ADDR_PAR_WD:0]                         s_client1_tlp_addr;
  logic [7:0]                                          s_client1_tlp_byte_en;
  logic [2:0]                                          s_client1_tlp_tc;
  logic [`CC_CORE_DATA_BUS_WD -1:0]                    s_client1_tlp_data;
  logic                                                s_xadm_client1_halt;
  logic [`CX_REMOTE_LOOKUPID_WD-1:0]                   s_client1_cpl_lookup_id;
  logic [TX_TLP_PREFIX_WD-1:0]                         s_client1_tlp_prfx;
  logic                                                s_client1_tlp_th;
  logic [1:0]                                          s_client1_tlp_ph;
  logic [7:0]                                          s_client1_tlp_st;
  logic                                                s_client1_tlp_atu_bypass;
  logic [(`CX_AXI_NVC_XALI_EXPANSION*`CLIENT_HDR_PROT_WD)-1:0] s_client1_hdr_prot;
  logic [(`CX_AXI_NVC_XALI_EXPANSION*`CX_ADDR_PAR_WD)-1:0]    s_client1_tlp_addr_par;
  logic [`CX_REMOTE_LOOKUPID_WD-1:0]                   s_client2_cpl_lookup_id;
  logic                                                s_client2_addr_align_en;
  logic [7:0]                                          s_client2_tlp_byte_en;
  logic [15:0]                                         s_client2_remote_req_id;
  logic [`DC_CPL_STATUS_WD-1:0]                        s_client2_cpl_status;
  logic                                                s_client2_cpl_bcm;
  logic [11:0]                                         s_client2_cpl_byte_cnt;
  logic                                                s_client2_tlp_dv;
  logic                                                s_client2_tlp_eot;
  logic                                                s_client2_tlp_bad_eot;
  logic                                                s_client2_tlp_hv;
  logic [1:0]                                          s_client2_tlp_fmt;
  logic [4:0]                                          s_client2_tlp_type;
  logic [2:0]                                          s_client2_tlp_tc;
  logic                                                s_client2_tlp_td;
  logic                                                s_client2_tlp_ep;
  logic [`FLT_Q_ATTR_WIDTH-1:0]                        s_client2_tlp_attr;
  logic [12:0]                                         s_client2_tlp_byte_len;
  logic [`CX_TAG_SIZE-1:0]                             s_client2_tlp_tid;
  logic [63+`CX_ADDR_PAR_WD:0]                         s_client2_tlp_addr;
  logic [`CC_CORE_DATA_BUS_WD-1:0]                     s_client2_tlp_data;
  logic [`CX_NFUNC_WD-1:0]                             s_client2_tlp_func_num;
  logic [8:0]                                          s_client2_tlp_dst_segment;
  logic [1:0]                                          s_client2_tlp_ats;
  logic                                                s_client2_tlp_nw;
  logic                                                s_client2_tlp_th;
  logic [1:0]                                          s_client2_tlp_ph;
  logic [7:0]                                          s_client2_tlp_st;
  logic [TX_TLP_PREFIX_WD-1:0]                         s_client2_tlp_prfx;
  logic                                                s_client2_tlp_atu_bypass;
 logic                                                  s_xadm_client2_halt;
  logic [(`CX_AXI_NVC_XALI_EXPANSION*`CLIENT_HDR_PROT_WD)-1:0] s_client2_hdr_prot;
  logic [(`CX_AXI_NVC_XALI_EXPANSION*`CX_ADDR_PAR_WD)-1:0]    s_client2_tlp_addr_par;
  logic                                                s_client2_tlp_silentDrop;



  // -------------------------------------------------------------------------------------
  // AXI Slave Auxiliary Interface
pkg_axi_slv_aw_s          slv_aw_s;
pkg_axi_slv_ar_s          slv_ar_s;
pkg_axi_slv_w_s           slv_w_s ;
pkg_axi_slv_r_s           slv_r_s ;
pkg_axi_slv_b_s           slv_b_s ;

pkg_axi_slv_aw_s          slv_aw_i;
pkg_axi_slv_ar_s          slv_ar_i;
pkg_axi_slv_w_s           slv_w_i ;
pkg_axi_slv_r_s           slv_r_o ;
pkg_axi_slv_b_s           slv_b_o ;


pkg_axi_slv_armisc_info_s slv_armisc_info_aux;

  // -------------------------------------------------------------------------------------
  // AXI Master Auxiliary Interface
pkg_axi_mstr_aw_s         mstr_aw_s;
pkg_axi_mstr_ar_s         mstr_ar_s;
pkg_axi_mstr_w_s          mstr_w_s ;
pkg_axi_mstr_r_s          mstr_r_s ;
pkg_axi_mstr_b_s          mstr_b_s ;

pkg_axi_mstr_aw_s         mstr_aw_o;
pkg_axi_mstr_ar_s         mstr_ar_o;
pkg_axi_mstr_w_s          mstr_w_o ;
pkg_axi_mstr_r_s          mstr_r_i ;
pkg_axi_mstr_b_s          mstr_b_i ;




  // -------------------------------------------------------------------------------------
  // AXI Error Status Auxiliary Interface
logic                              mstr_misb_err_sts      ;
logic                              mstrh_misb_err_sts     ;
ras_dp_err_log_t                   mstr_misb_ras_dp_err_log     ;
ras_dp_err_log_t                   axi_sisb_aw_ad_ras_dp_err_log;
ras_dp_err_log_t                   axi_sisb_ar_ad_ras_dp_err_log;
ras_dp_err_log_t                   axi_sisb_w_dt_ras_dp_err_log ;
pkg_axi_slv_par_sts                slv_sisb_err_sts       ;
logic [`CC_MSTR_BUS_ADDR_WIDTH-1:0]mstr_awaddr_s          ;
logic [`CC_MSTR_BUS_ADDR_WIDTH-1:0]mstr_araddr_s          ;
logic [`CC_MSTR_BUS_DATA_WIDTH-1:0]mstr_wdata_s           ;
logic [`CC_MSTR_BUS_DATA_WIDTH-1:0]mstr_rdata_s           ;
logic [`CC_MSTR_BUS_ADDR_WIDTH-1:0]mstrh_awaddr_s         ;
logic [`CC_MSTR_BUS_ADDR_WIDTH-1:0]mstrh_araddr_s         ;
logic [`CC_MSTR_BUS_DATA_WIDTH-1:0]mstrh_wdata_s          ;
logic [`CC_MSTR_BUS_DATA_WIDTH-1:0]mstrh_rdata_s          ;
logic [`CC_SLV_BUS_ADDR_WIDTH-1:0] slv_awaddr_s           ;
logic [`CC_SLV_BUS_ADDR_WIDTH-1:0] slv_araddr_s           ;
logic [`CC_SLV_BUS_DATA_WIDTH-1:0] slv_wdata_s            ;
logic [`CC_SLV_BUS_DATA_WIDTH-1:0] slv_rdata_s            ;
logic [`CC_DBI_SLV_BUS_ADDR_WIDTH-1:0] dbi_awaddr_s       ;
logic [`CC_DBI_SLV_BUS_ADDR_WIDTH-1:0] dbi_araddr_s       ;
logic [`CC_DBI_SLV_BUS_DATA_WIDTH-1:0] dbi_wdata_s        ;
logic [`CC_DBI_SLV_BUS_DATA_WIDTH-1:0] dbi_rdata_s        ;
logic                              mstr_awready_s         ;
logic                              mstr_arready_s         ;
logic                              mstr_wready_s          ;
logic                              mstr_rready_s          ;
logic                              mstr_bready_s          ;
logic                              mstrh_awready_s        ;
logic                              mstrh_arready_s        ;
logic                              mstrh_wready_s         ;
logic                              mstrh_rready_s         ;
logic                              mstrh_bready_s         ;
logic                              slv_awready_s          ;
logic                              slv_arready_s          ;
logic                              slv_wready_s           ;
logic                              slv_rready_s           ;
logic                              slv_bready_s           ;
logic                              dbi_awready_s          ;
logic                              dbi_arready_s          ;
logic                              dbi_wready_s           ;
logic                              dbi_rready_s           ;
logic                              dbi_bready_s           ;

  // -------------------------------------------------------------------------------------
  // AXI TLP Prefixing Parity Auxiliary Signals
logic [`CX_PRFX_PAR_WD -1:0] mstr_awmisc_info_tlpprfx_par ;
logic [`CX_PRFX_PAR_WD -1:0] mstr_armisc_info_tlpprfx_par ;
logic [`CX_PRFX_PAR_WD -1:0] mstrh_awmisc_info_tlpprfx_par;
logic [`CX_PRFX_PAR_WD -1:0] mstrh_armisc_info_tlpprfx_par;
logic [`CX_PRFX_PAR_WD -1:0] slv_awmisc_info_tlpprfx_par  ;
logic [`CX_PRFX_PAR_WD -1:0] slv_armisc_info_tlpprfx_par  ;

   kIbrRpseqn_u s_ibr_rpseqn;
   kIbRpseqn_u  s_ib_rpseqn;

  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  typedef struct packed {
    logic                                    s_dummy_signal; // Avoid completely empty struct definition
    logic    [`CX_ATU_BASE_WIDTH*ATU_OUT_NREGIONS_MIN1 -1:0] atu_reg_out_upr_base;
    logic                [ATU_OUT_NREGIONS_MIN1 -1:0] atu_reg_out_en;
    logic              [5*ATU_OUT_NREGIONS_MIN1 -1:0] atu_reg_out_type;
    logic     [`CX_ATU_REGION_WIDTH*ATU_OUT_NREGIONS_MIN1 -1:0] atu_reg_out_base;
    logic     [`CX_ATU_REGION_WIDTH*ATU_OUT_NREGIONS_MIN1 -1:0] atu_reg_out_limit;
    logic [`CX_ATU_MAX_REGION_SIZE*ATU_OUT_NREGIONS_MIN1 -1:0] atu_reg_out_uppr_limit;
    logic                [ATU_OUT_NREGIONS_MIN1 -1:0] atu_reg_out_incr_rgn_size;
    logic                [ATU_OUT_NREGIONS_MIN1 -1:0] atu_reg_out_invert;
    logic   [`CX_NFUNC_WD*ATU_OUT_NREGIONS_MIN1 -1:0] atu_reg_out_func_num;
    logic                [ATU_OUT_NREGIONS_MIN1 -1:0] atu_reg_out_func_bypass;
    logic                [ATU_OUT_NREGIONS_MIN1 -1:0] atu_reg_out_snp;
    logic                 [3*`CX_NFUNC -1:0] cfg_max_rd_req_size;
    logic                 [3*`CX_NFUNC -1:0] cfg_max_payload_size;
    logic                                    cfg_rasdp_err_mode_en;
    logic                                    cfg_ras_recc_npw_sab_correct;
    logic                                    cfg_ras_recc_ob_ccmp_data_correct;
    logic                                    cfg_dmwr_req_en;
  } quasiSlv_s;

  typedef struct packed {
    logic          [4 -1:0] cfg_mstr_arcache_mode;
    logic          [4 -1:0] cfg_mstr_awcache_mode;
    logic          [4 -1:0] cfg_mstr_arcache_value;
    logic          [4 -1:0] cfg_mstr_awcache_value;
    logic         [32 -1:0] cfg_aximstr_msg_addr_high;
    logic         [32 -1:0] cfg_aximstr_msg_addr_low;
    logic          [2 -1:0] cfg_mstr_ardomain_mode;
    logic          [2 -1:0] cfg_mstr_awdomain_mode;
    logic          [2 -1:0] cfg_mstr_ardomain_value;
    logic          [2 -1:0] cfg_mstr_awdomain_value;
    logic                   cfg_rasdp_err_mode_en;
    logic                   cfg_ras_recc_ib_rreq_c2a_cdc_correct;
    logic                   cfg_ras_recc_ib_wreq_c2a_cdc_correct;
    logic [3*`CX_NFUNC -1:0] cfg_max_payload_size;
    logic                   cfg_ax_mstr_zeroread_fw;
  } quasiMstr_s;


  axi_xali_exp_client0_s   exp_client0_s;
  axi_xali_exp_client1_s   exp_client1_s;
  axi_xali_exp_client2_s   exp_client2_s;

  axi_xali_client0_s       axi_client0_s;
  axi_xali_client1_s       axi_client1_s;
  axi_xali_client2_s       axi_client2_s;

  quasiSlv_s  qslv_s , qslv_d ;
  quasiMstr_s qmstr_s, qmstr_d;

  assign qslv_s = '{
    default                           : '0
   ,atu_reg_out_upr_base              : atu_reg_out_upr_base
   ,atu_reg_out_en                    : atu_reg_out_en
   ,atu_reg_out_type                  : atu_reg_out_type
   ,atu_reg_out_base                  : atu_reg_out_base
   ,atu_reg_out_limit                 : atu_reg_out_limit
   ,atu_reg_out_uppr_limit            : atu_reg_out_uppr_limit
   ,atu_reg_out_incr_rgn_size         : atu_reg_out_incr_rgn_size
   ,atu_reg_out_invert                : atu_reg_out_invert
   ,atu_reg_out_func_num              : atu_reg_out_func_num
   ,atu_reg_out_func_bypass           : atu_reg_out_func_bypass
   ,atu_reg_out_snp                   : atu_reg_out_snp
   ,cfg_max_rd_req_size               : cfg_max_rd_req_size
   ,cfg_max_payload_size              : cfg_max_payload_size
   ,cfg_rasdp_err_mode_en             : cfg_rasdp_err_mode_en
   ,cfg_ras_recc_npw_sab_correct      : cfg_ras_recc_npw_sab_correct
   ,cfg_ras_recc_ob_ccmp_data_correct : cfg_ras_recc_ob_ccmp_data_correct
   ,cfg_dmwr_req_en                   : cfg_dmwr_req_en
  };

  assign qmstr_s = '{
    cfg_mstr_arcache_mode                 : cfg_mstr_arcache_mode
   ,cfg_mstr_awcache_mode                 : cfg_mstr_awcache_mode
   ,cfg_mstr_arcache_value                : cfg_mstr_arcache_value
   ,cfg_mstr_awcache_value                : cfg_mstr_awcache_value
   ,cfg_aximstr_msg_addr_high             : cfg_aximstr_msg_addr_high
   ,cfg_aximstr_msg_addr_low              : cfg_aximstr_msg_addr_low
   ,cfg_mstr_ardomain_mode                : cfg_mstr_ardomain_mode
   ,cfg_mstr_awdomain_mode                : cfg_mstr_awdomain_mode
   ,cfg_mstr_ardomain_value               : cfg_mstr_ardomain_value
   ,cfg_mstr_awdomain_value               : cfg_mstr_awdomain_value
   ,cfg_rasdp_err_mode_en                 : cfg_rasdp_err_mode_en
   ,cfg_ras_recc_ib_rreq_c2a_cdc_correct  : cfg_ras_recc_ib_rreq_c2a_cdc_correct
   ,cfg_ras_recc_ib_wreq_c2a_cdc_correct  : cfg_ras_recc_ib_wreq_c2a_cdc_correct
   ,cfg_max_payload_size                  : cfg_max_payload_size
   ,cfg_ax_mstr_zeroread_fw               : cfg_ax_mstr_zeroread_fw
  };


  DWC_pcie_ctl_bcm36_nhs
   #(
    .WIDTH      ( $bits(quasiSlv_s)     ),
    .DATA_DELAY ( CC_MIS_SAMPLING_DELAY )
  ) u_bcm36_nhs_slv (
  `ifndef SYNTHESIS
    .clk_d   ( slv_aclk    ),
    .rst_d_n ( slv_aresetn ),
  `endif // SYNTHESIS
    .data_s  ( qslv_s      ),
    .data_d  ( qslv_d      )
  );

  DWC_pcie_ctl_bcm36_nhs
   #(
    .WIDTH      ( $bits(quasiMstr_s)    ),
    .DATA_DELAY ( CC_MIS_SAMPLING_DELAY )
  ) u_bcm36_nhs_mstr (
  `ifndef SYNTHESIS
    .clk_d   ( mstr_aclk    ),
    .rst_d_n ( mstr_aresetn ),
  `endif // SYNTHESIS
    .data_s  ( qmstr_s      ),
    .data_d  ( qmstr_d      )
  );



  DWC_pcie_src_reg_sync
   #(
    .WIDTH       ( $bits(cdmIbrPIdMngCtrl_s) )
   ,.F_SYNC_TYPE ( `CX_PCIE_SYNC_DEPTH       )
   ,.VERIF_EN    ( 1                         )
  ) u_bcm21_cfg_ib_p_id_mng_ctrl (
    .clk_s    ( aux_clk_g                 )
   ,.rst_s_n  ( core_rst_n                )
   ,.clk_d    ( mstr_aclk_g               )
   ,.rst_d_n  ( mstr_aresetn              )
   ,.data_s   ( cfg_ib_p_id_mng_ctrl      )
   ,.data_d   ( cfg_ibr_p_id_mng_ctrl_a2m )
  );

  assign cfg_ib_p_id_mng_ctrl_a2m  = f_kIbPIdMngCtrl_toIb(cfg_ibr_p_id_mng_ctrl_a2m);

  DWC_pcie_src_reg_sync
  
  #(
   .WIDTH       (5         ),
   .F_SYNC_TYPE (`CX_PCIE_SYNC_DEPTH),
   .VERIF_EN    (1         )
  )
  u_bcm21_cfg_err_resp_mode_a2s
  (
  .clk_s        (aux_clk_g            ),
  .rst_s_n      (core_rst_n           ),
  .clk_d        (slv_aclk_g           ),
  .rst_d_n      (slv_aresetn          ),
  .data_s       (cfg_err_resp_mode    ),
  .data_d       (cfg_err_resp_mode_a2s)
  );

 DWC_pcie_src_reg_sync
 
  #(
   .WIDTH       (6         ),
   .F_SYNC_TYPE (`CX_PCIE_SYNC_DEPTH),
   .VERIF_EN    (1         )
  )
  u_bcm21_cfg_slv_resp_err_map_a2s
  (
  .clk_s        (aux_clk_g               ),
  .rst_s_n      (core_rst_n              ),
  .clk_d        (slv_aclk_g              ),
  .rst_d_n      (slv_aresetn             ),
  .data_s       (cfg_slv_resp_err_map    ),
  .data_d       (cfg_slv_resp_err_map_a2s)
  );


logic cfg_10b_tag_en_c2s;
DWC_pcie_src_reg_sync

  #(
   .WIDTH       (1         ),
   .F_SYNC_TYPE (`CX_PCIE_SYNC_DEPTH),
   .VERIF_EN    (1         )
  )
  u_bcm21_cfg_10b_tag_en_c2s
  (
  .clk_s        (aux_clk           ),
  .rst_s_n      (core_rst_n        ),
  .clk_d        (slv_aclk          ),
  .rst_d_n      (slv_aresetn       ),
  .data_s       (cfg_10b_tag_en    ),
  .data_d       (cfg_10b_tag_en_c2s)
  );
  
  logic r_cfg_10b_tag_en;
  always@(posedge core_clk or negedge core_rst_n) begin: SEQ_10B_TAG_REQ_PROC
    if(!core_rst_n)begin
      r_cfg_10b_tag_en <= #`TP '0;
    end else begin
      r_cfg_10b_tag_en <= #`TP cfg_10b_tag_en;
    end
  end


logic cfg_ext_tag_en_c2s;
DWC_pcie_src_reg_sync

  #(
   .WIDTH       (1         ),
   .F_SYNC_TYPE (`CX_PCIE_SYNC_DEPTH),
   .VERIF_EN    (1         )
  )
  u_bcm21_cfg_ext_tag_en_c2s
  (
  .clk_s        (aux_clk           ),
  .rst_s_n      (core_rst_n        ),
  .clk_d        (slv_aclk          ),
  .rst_d_n      (slv_aresetn       ),
  .data_s       (cfg_ext_tag_en    ),
  .data_d       (cfg_ext_tag_en_c2s)
  );




  logic cdc_core_in_dpc;
  logic qst_cfg_dpc_cpl_cntrl;

  DWC_pcie_src_reg_sync
   #(
    .WIDTH       (1                  ),
    .F_SYNC_TYPE (`CX_PCIE_SYNC_DEPTH),
    .VERIF_EN    (1                  )
  ) u_bcm21_core_in_dpc_i (
    .clk_s       (aux_clk_g          ),
    .rst_s_n     (core_rst_n         ),
    .clk_d       (slv_aclk           ),
    .rst_d_n     (slv_aresetn        ),
    .data_s      (core_in_dpc_i      ),
    .data_d      (cdc_core_in_dpc    )
  );

  DWC_pcie_ctl_bcm36_nhs
   #(
    .WIDTH      (1                      ),
    .DATA_DELAY (CC_MIS_SAMPLING_DELAY  )
  ) u_bcm36_nhs_cfg_dpc_cpl_cntrl_i (
  `ifndef SYNTHESIS
    .clk_d      (slv_aclk               ),
    .rst_d_n    (slv_aresetn            ),
  `endif // SYNTHESIS
    .data_s     (cfg_dpc_cpl_cntrl_i    ),
    .data_d     (qst_cfg_dpc_cpl_cntrl  )
  );

  // ---------------------------------------------------------------------------
  // Instantiate AXIclk controller
  // ---------------------------------------------------------------------------

   localparam CORE_RASDP_WAKEUP_WD   =   6
                                      ;
  
  logic [CORE_RASDP_WAKEUP_WD-1:0] core_ras_dp_wake_up;
  logic [1:0] mstr_ras_dp_wake_up;
  logic [1:0] slv_ras_dp_wake_up;

DWC_pcie_axi_clk_ctrl

  #(
    .SYNC_DEPTH                             (`CX_PCIE_SYNC_DEPTH),
    .CORE_RASDP_WAKEUP_WD                   (CORE_RASDP_WAKEUP_WD)
)
  u_axi_clk_ctrl
  (
  .mstr_aclk_ug                             (mstr_aclk),
  .mstr_aresetn                             (mstr_aresetn),
  .slv_aclk                                 (slv_aclk_g),
  .slv_aclk_ug                              (slv_aclk),
  .slv_aresetn                              (slv_aresetn),
  .cfg_axi_clk_gating_en                    (cfg_axi_clk_gating_en),
  .sync_mstr_aclk_gating_en                 (sync_mstr_aclk_gating_en),
  .sync_slv_aclk_gating_en                  (),
  .brdg_mstr_xfer_pending                   (brdg_mstr_xfer_pending),
  .edma_xfer_pending                        (edma_xfer_pending),
  .app_xfer_pending                         (app_xfer_pending),
  .slv_xfer_pending                         (sif_xfer_pending),
  .slvdb_xfer_pending                       (sif_xfer_pending_db),
  .slv_awvalid                              (slv_awvalid),
  .slv_wvalid                               (slv_wvalid),
  .slv_arvalid                              (slv_arvalid),
  .mstr_aclk_active                         (en_mstr_aclk_g),
  .slv_aclk_active                          (en_slv_aclk_g),
  .aux_clk_g                                (aux_clk_g),
  .core_rst_n                               (core_rst_n)
  ,.ras_err_inj_wake_up                     (axi_bridge_in_ras_dp_err_inj_wake_up)
  ,.core_ras_dp_wake_up                     (core_ras_dp_wake_up)
  ,.mstr_ras_dp_wake_up                     (mstr_ras_dp_wake_up)
  ,.slv_ras_dp_wake_up                      (slv_ras_dp_wake_up)
  );

  // ---------------------------------------------------------------------------
  // Inbound Data Path
  // ---------------------------------------------------------------------------

   //---------------------------------------------------------------------------

   wire                                       ibc0_tlp_addr_align_en;
   wire [`CX_NFUNC_WD-1:0]                    ibc0_tlp_func_num;
   wire [15:0]                                ibc0_cpl_cmpltr_id;
   wire [`DC_CPL_STATUS_WD-1:0]               ibc0_cpl_status;
   wire                                       ibc0_cpl_bcm;
   wire [11:0]                                ibc0_cpl_byte_cnt;
   wire                                       ibc0_tlp_dv;
   wire                                       ibc0_tlp_eot;
   wire                                       ibc0_tlp_bad_eot;
   wire                                       ibc0_cpl_last;
   wire                                       ibc0_tlp_hv;
   wire [1:0]                                 ibc0_tlp_fmt;
   wire [4:0]                                 ibc0_tlp_type;
   wire                                       ibc0_tlp_td;
   wire                                       ibc0_tlp_ep;
   wire [`FLT_Q_ATTR_WIDTH-1:0]               ibc0_tlp_attr;
   wire [1:0]                                 ibc0_tlp_ats;
   wire [`CX_TAG_SIZE-1:0]                    ibc0_tlp_tid;
   wire [12:0]                                ibc0_tlp_byte_len;
   wire [(`DC_CPL_ADDR_WD+`CX_ADDR_PAR_WD)-1:0]ibc0_tlp_addr;
   wire [`DC_CPL_BYTE_EN_WD-1:0]              ibc0_tlp_byte_en;
   wire [`DC_TC_WD-1:0]                       ibc0_tlp_tc;
   wire [`CC_CORE_DATA_BUS_WD -1:0]           ibc0_tlp_data;
   wire                                       xadm_ibc0_halt;
   wire [`CX_REMOTE_LOOKUPID_WD-1:0]          ibc0_cpl_lookup_id;
   wire                                       ibc0_tlp_atu_bypass;
   wire [`DC_DMA_TYPE_WIDTH-1:0]              ibc0_tlp_dma;
   wire [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]      ibc0_tlp_dma_channel;
   wire                                       ibc0_tlp_prv_dma;
   wire [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]      ibc0_tlp_prv_dma_chan;



//---------------------------------------------------------------------------
  // Map additional misc_info bits to internal misc_info bus
  wire [`MSTR_RESP_MISC_INFO_WD-1:0] int_mstr_rmisc_info;
  assign int_mstr_rmisc_info = {mstr_rmisc_info,2'd0};

  assign brdg_trgt1_p_xfer_done = ibreq_presp_cmplt && !ibreq_presp_type[0];

  // ---------------------------------------------------------------------------
  // Instantiate Inbound Router
  // ---------------------------------------------------------------------------
  assign inbd_halt_cpl = 1'b0;


  assign trgt1_radm_pkt_halt    = '0;
  assign d_trgt1_radm_dma_pkt_halt = '0;


  DWC_pcie_bridge_ib_scheduler
  
  #(
    .DC_INBD_HEADER_PNP_WD           (`DC_INBD_HEADER_PNP_WD       ),
    .DC_INBD_HEADER_PNP_1STG_WD      (`DC_INBD_HEADER_PNP_1STG_WD  ),
    .DC_INBD_HEADER_PNP_1STG_WD_NP   (`DC_INBD_HEADER_PNP_1STG_WD_NP),
    .CC_MSTR_BUS_DATA_WIDTH          (`CC_MSTR_BUS_DATA_WIDTH      ),
    .DC_INBD_HEADER_CPL_WD           (`DC_INBD_HEADER_CPL_WD       ),
    .CC_SLV_BUS_DATA_WIDTH           (`CC_SLV_BUS_DATA_WIDTH       ),
    .CORE_DATA_BUS_WD                (`CC_CORE_DATA_BUS_WD         ),
    .NW                              (`CX_NW                       ),
    .PF_WD                           (`CX_NFUNC_WD                 ),
    .CORE_ADDR_BUS_WD                (`CC_CORE_ADDR_BUS_WD         ),
    .FLT_Q_ADDR_WIDTH                (`FLT_Q_ADDR_WIDTH            ),
    .DC_DMA_TYPE_WIDTH               (`DC_DMA_TYPE_WIDTH           ),
    .CC_NUM_DMA_RD_CHAN_WIDTH        (`CC_NUM_DMA_RD_CHAN_WIDTH    ),
    .CC_NUM_DMA_MAX_CHAN_WIDTH       (`CC_NUM_DMA_MAX_CHAN_WIDTH   ),
    .DC_DMA_REQ_BYPASS               (`DC_DMA_REQ_BYPASS           ),
    .DC_DMA_REQ_BYPASS_CPL           (`DC_DMA_REQ_BYPASS_CPL       ),
    .CC_IB_SCHEDULER_P_HDR_RAM_DP         (`CC_IB_SCHEDULER_P_HDR_RAM_DP      ),
    .CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD    (`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD ),
    .CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD    (`CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD ),
    .CC_IB_SCHEDULER_P_DATA_RAM_DP        (`CC_IB_SCHEDULER_P_DATA_RAM_DP     ),
    .CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD   (`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD),
    .CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD   (`CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD),
    .CC_IB_SCHEDULER_NP_HDR_RAM_DP        (`CC_IB_SCHEDULER_NP_HDR_RAM_DP     ),
    .CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD   (`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD),
    .CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD   (`CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD),
    .CC_IB_SCHEDULER_NP_DATA_RAM_DP       (`CC_IB_SCHEDULER_NP_DATA_RAM_DP    ),
    .CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD  (`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD),
    .CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD  (`CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD),

    .MAX_WIRE_TAG_PW                 (MAX_WIRE_TAG_PW              ),
    .MAX_WIRE_TAG                    (MAX_WIRE_TAG                 ),
    .RX_TLP_PREFIX_WD                (`FLT_Q_PRFX_WIDTH            ),
    .TPH_ST_WD                       (TPH_ST_WD                    ),
    .TPH_PH_WD                       (TPH_PH_WD                    ),
    .TPH_TH_WD                       (TPH_TH_WD                    ),
    .VF_WD                           (`CX_NVFUNC_WD                ),

    .CC_AMBA_TLP_SEQ_WD              (`CC_AMBA_TLP_SEQ_WD          ),
    .CX_NVC_LOG2                     (`CX_NVC_LOG2                 ),
    .CX_NVC                          (`CX_NVC                      ),
    .CC_P_REQ_MAX_LOG2               (`CC_P_REQ_MAX_LOG2           ),
    .CC_MAX_MSTR_TAG_PW              (`CC_MAX_MSTR_TAG_PW          ),
    .CX_REMOTE_MAX_TAGS_WD           (`CC_MAX_MSTR_TAG_PW          ),
    .FLT_Q_ATTR_WIDTH                (`FLT_Q_ATTR_WIDTH            )
    )
    u_ib_scheduler
    (
     .clk                            (core_clk                      )
    ,.rstn                           (core_rst_n                    )
    ,.cfg_ax_mstr_np_pass_p          (cfg_ax_mstr_np_pass_p         )
    ,.cfg_ax_mstr_ro_p_en            (cfg_ib_p_id_mng_ctrl          )
    ,.cfg_10b_tag_en                 (r_cfg_10b_tag_en              )
    ,.cfg_memtype_boundary           (cfg_memtype_boundary          )
    ,.cfg_memtype_value              (cfg_memtype_value             )
    ,.inbd_header_pnp_wr             (inbd_header_pnp_wr            )
    ,.inbd_header_pnp_wr_uppr_bytes  (s_inbd_header_pnp_wr_uppr_bytes)
    ,.inbd_data_pnp_wr               (inbd_data_pnp_wr              )
    ,.inbd_halt_pnp_wr               (inbd_halt_pnp_wr              )
    ,.inbd_header_pnp_rd             (inbd_header_pnp_rd            )
    ,.inbd_halt_pnp_rd               (inbd_halt_pnp_rd              )
    // -------------------------------------------------------------------------
    // Completion interface
    ,.inbd_header_cpl                (inbd_header_cpl               )
    ,.inbd_header_cpl_pseq           (inbd_header_cpl_pseq          )
    ,.inbd_data_cpl                  (inbd_data_cpl                 )
    ,.inbd_halt_cpl                  (inbd_halt_cpl                 )
    ,.trgt_lookup_id                      (trgt_lookup_id                     )

    ,.radm_trgt1_p_0_pending              (radm_trgt1_p_0_pending             )

    ,.radm_trgt1_p_0_data                 (radm_trgt1_p_0_data                )
    ,.radm_trgt1_p_0_hdr_prot             (radm_trgt1_p_0_hdr_prot            )
    ,.radm_trgt1_p_0_prfx                 (radm_trgt1_p_0_prfx                )
    ,.radm_trgt1_p_0_dwen                 (radm_trgt1_p_0_dwen                )
    ,.radm_trgt1_p_0_dv                   (radm_trgt1_p_0_dv                  )
    ,.radm_trgt1_p_0_hv                   (radm_trgt1_p_0_hv                  )
    ,.radm_trgt1_p_0_eot                  (radm_trgt1_p_0_eot                 )
    ,.radm_trgt1_p_0_dllp_abort           (radm_trgt1_p_0_dllp_abort          )
    ,.radm_trgt1_p_0_tlp_abort            (radm_trgt1_p_0_tlp_abort           )
    ,.radm_trgt1_p_0_ecrc_err             (radm_trgt1_p_0_ecrc_err            )
    ,.radm_trgt1_p_0_fmt                  (radm_trgt1_p_0_fmt                 )
    ,.radm_trgt1_p_0_type                 (radm_trgt1_p_0_type                )
    ,.radm_trgt1_p_0_tc                   (radm_trgt1_p_0_tc                  )
    ,.radm_trgt1_p_0_attr                 (radm_trgt1_p_0_attr                )
    ,.radm_trgt1_p_0_reqid                (radm_trgt1_p_0_reqid               )
    ,.radm_trgt1_p_0_tag                  (radm_trgt1_p_0_tag                 )
    ,.radm_trgt1_p_0_func_num             (radm_trgt1_p_0_func_num            )
    ,.radm_trgt1_p_0_td                   (radm_trgt1_p_0_td                  )
    ,.radm_trgt1_p_0_cpl_status           (radm_trgt1_p_0_cpl_status          )
    ,.radm_trgt1_p_0_poisoned             (radm_trgt1_p_0_poisoned            )
    ,.radm_trgt1_p_0_dw_len               (radm_trgt1_p_0_dw_len              )
    ,.radm_trgt1_p_0_first_be             (radm_trgt1_p_0_first_be            )
    ,.radm_trgt1_p_0_vc_num               (radm_trgt1_p_0_vc_num              )
    ,.radm_trgt1_p_0_addr                 (radm_trgt1_p_0_addr                )
    ,.radm_trgt1_p_0_hdr_uppr_bytes       (radm_trgt1_p_0_hdr_uppr_bytes      )
    ,.radm_trgt1_p_0_rom_in_range         (radm_trgt1_p_0_rom_in_range        )
    ,.radm_trgt1_p_0_io_req_in_range      (radm_trgt1_p_0_io_req_in_range     )
    ,.radm_trgt1_p_0_in_membar_range      (radm_trgt1_p_0_in_membar_range     )
    ,.radm_trgt1_p_0_last_be              (radm_trgt1_p_0_last_be             )
    ,.radm_trgt1_p_0_ats                  (radm_trgt1_p_0_ats                 )
    ,.radm_trgt1_p_0_nw                   (radm_trgt1_p_0_nw                  )
    ,.radm_trgt1_p_0_th                   (radm_trgt1_p_0_th                  )
    ,.radm_trgt1_p_0_ph                   (radm_trgt1_p_0_ph                  )
    ,.radm_trgt1_p_0_st                   (radm_trgt1_p_0_st                  )
    ,.radm_trgt1_p_0_hdr_uppr_bytes_valid (radm_trgt1_p_0_hdr_uppr_bytes_valid)
    ,.radm_trgt1_p_0_req_dma              (radm_trgt1_p_0_req_dma             )
    ,.radm_trgt1_p_0_req_dma_channel      (radm_trgt1_p_0_req_dma_channel     )
    ,.radm_trgt1_p_0_req_dma_mem_type     (radm_trgt1_p_0_req_dma_mem_type    )
    ,.radm_trgt1_p_0_reqtr_sgmt           (radm_trgt1_p_0_reqtr_sgmt          )
    ,.radm_trgt1_p_0_dest_sgmt            (radm_trgt1_p_0_dest_sgmt           )
    ,.radm_trgt1_p_0_pkt_order_no         (radm_trgt1_p_0_pkt_order_no        )
    ,.radm_trgt1_np_0_data                (radm_trgt1_np_0_data               )
    ,.radm_trgt1_np_0_hdr_prot            (radm_trgt1_np_0_hdr_prot           )
    ,.radm_trgt1_np_0_prfx                (radm_trgt1_np_0_prfx               )
    ,.radm_trgt1_np_0_dwen                (radm_trgt1_np_0_dwen               )
    ,.radm_trgt1_np_0_dv                  (radm_trgt1_np_0_dv                 )
    ,.radm_trgt1_np_0_hv                  (radm_trgt1_np_0_hv                 )
    ,.radm_trgt1_np_0_eot                 (radm_trgt1_np_0_eot                )
    ,.radm_trgt1_np_0_dllp_abort          (radm_trgt1_np_0_dllp_abort         )
    ,.radm_trgt1_np_0_tlp_abort           (radm_trgt1_np_0_tlp_abort          )
    ,.radm_trgt1_np_0_ecrc_err            (radm_trgt1_np_0_ecrc_err           )
    ,.radm_trgt1_np_0_fmt                 (radm_trgt1_np_0_fmt                )
    ,.radm_trgt1_np_0_type                (radm_trgt1_np_0_type               )
    ,.radm_trgt1_np_0_tc                  (radm_trgt1_np_0_tc                 )
    ,.radm_trgt1_np_0_attr                (radm_trgt1_np_0_attr               )
    ,.radm_trgt1_np_0_reqid               (radm_trgt1_np_0_reqid              )
    ,.radm_trgt1_np_0_tag                 (radm_trgt1_np_0_tag                )
    ,.radm_trgt1_np_0_func_num            (radm_trgt1_np_0_func_num           )
    ,.radm_trgt1_np_0_cpl_status          (radm_trgt1_np_0_cpl_status         )
    ,.radm_trgt1_np_0_td                  (radm_trgt1_np_0_td                 )
    ,.radm_trgt1_np_0_poisoned            (radm_trgt1_np_0_poisoned           )
    ,.radm_trgt1_np_0_dw_len              (radm_trgt1_np_0_dw_len             )
    ,.radm_trgt1_np_0_first_be            (radm_trgt1_np_0_first_be           )
    ,.radm_trgt1_np_0_vc_num              (radm_trgt1_np_0_vc_num             )

    ,.radm_trgt1_np_0_addr                (radm_trgt1_np_0_addr               )
    ,.radm_trgt1_np_0_hdr_uppr_bytes      (radm_trgt1_np_0_hdr_uppr_bytes     )

    ,.radm_trgt1_np_0_rom_in_range        (radm_trgt1_np_0_rom_in_range       )
    ,.radm_trgt1_np_0_io_req_in_range     (radm_trgt1_np_0_io_req_in_range    )
    ,.radm_trgt1_np_0_in_membar_range     (radm_trgt1_np_0_in_membar_range    )
    ,.radm_trgt1_np_0_last_be             (radm_trgt1_np_0_last_be            )
    ,.radm_trgt1_np_0_ats                 (radm_trgt1_np_0_ats                )
    ,.radm_trgt1_np_0_nw                  (radm_trgt1_np_0_nw                 )
    ,.radm_trgt1_np_0_cxlsrc              (radm_trgt1_np_0_cxlsrc             )
    ,.radm_trgt1_np_0_th                  (radm_trgt1_np_0_th                 )
    ,.radm_trgt1_np_0_ph                  (radm_trgt1_np_0_ph                 )
    ,.radm_trgt1_np_0_st                  (radm_trgt1_np_0_st                 )
    ,.radm_trgt1_np_0_req_dma             (radm_trgt1_np_0_req_dma            )
    ,.radm_trgt1_np_0_req_dma_channel     (radm_trgt1_np_0_req_dma_channel    )
    ,.radm_trgt1_np_0_req_dma_mem_type    (radm_trgt1_np_0_req_dma_mem_type   )

    ,.radm_trgt1_np_0_reqtr_sgmt          (radm_trgt1_np_0_reqtr_sgmt         )
    ,.radm_trgt1_np_0_dest_sgmt           (radm_trgt1_np_0_dest_sgmt          )
    ,.radm_trgt1_np_0_pkt_order_no        (radm_trgt1_np_0_pkt_order_no       )

    ,.radm_trgt1_cpl_0_data               (radm_trgt1_cpl_0_data              )
    ,.radm_trgt1_cpl_0_hdr_prot           (radm_trgt1_cpl_0_hdr_prot          )
    ,.radm_trgt1_cpl_0_prfx               (radm_trgt1_cpl_0_prfx              )
    ,.radm_trgt1_cpl_0_dwen               (radm_trgt1_cpl_0_dwen              )
    ,.radm_trgt1_cpl_0_dv                 (radm_trgt1_cpl_0_dv                )
    ,.radm_trgt1_cpl_0_hv                 (radm_trgt1_cpl_0_hv                )
    ,.radm_trgt1_cpl_0_eot                (radm_trgt1_cpl_0_eot               )
    ,.radm_trgt1_cpl_0_dllp_abort         (radm_trgt1_cpl_0_dllp_abort        )
    ,.radm_trgt1_cpl_0_tlp_abort          (radm_trgt1_cpl_0_tlp_abort         )
    ,.radm_trgt1_cpl_0_ecrc_err           (radm_trgt1_cpl_0_ecrc_err          )
    ,.radm_trgt1_cpl_0_fmt                (radm_trgt1_cpl_0_fmt               )
    ,.radm_trgt1_cpl_0_type               (radm_trgt1_cpl_0_type              )
    ,.radm_trgt1_cpl_0_tc                 (radm_trgt1_cpl_0_tc                )
    ,.radm_trgt1_cpl_0_attr               (radm_trgt1_cpl_0_attr              )
    ,.radm_trgt1_cpl_0_reqid              (radm_trgt1_cpl_0_reqid             )
    ,.radm_trgt1_cpl_0_tag                (radm_trgt1_cpl_0_tag               )
    ,.radm_trgt1_cpl_0_func_num           (radm_trgt1_cpl_0_func_num          )
    ,.radm_trgt1_cpl_0_cpl_status         (radm_trgt1_cpl_0_cpl_status        )
    ,.radm_trgt1_cpl_0_td                 (radm_trgt1_cpl_0_td                )
    ,.radm_trgt1_cpl_0_poisoned           (radm_trgt1_cpl_0_poisoned          )
    ,.radm_trgt1_cpl_0_dw_len             (radm_trgt1_cpl_0_dw_len            )
    ,.radm_trgt1_cpl_0_bcm                (radm_trgt1_cpl_0_bcm               )
    ,.radm_trgt1_cpl_0_byte_cnt           (radm_trgt1_cpl_0_byte_cnt          )
    ,.radm_trgt1_cpl_0_cmpltr_id          (radm_trgt1_cpl_0_cmpltr_id         )
    ,.radm_trgt1_cpl_0_last               (radm_trgt1_cpl_0_last              )
    ,.radm_trgt1_cpl_0_vc_num             (radm_trgt1_cpl_0_vc_num            )

    ,.radm_trgt1_cpl_0_addr               (radm_trgt1_cpl_0_addr              )

    ,.radm_trgt1_cpl_0_dest_sgmt          (radm_trgt1_cpl_0_dest_sgmt         )
    ,.radm_trgt1_cpl_0_cpl_sgmt           (radm_trgt1_cpl_0_cpl_sgmt          )
    ,.radm_trgt1_cpl_0_pkt_order_no       (radm_trgt1_cpl_0_pkt_order_no      )

    ,.trgt1_radm_intf_cpl_0_halt          (trgt1_radm_intf_cpl_0_halt         )
    ,.trgt1_radm_intf_p_0_halt            (trgt1_radm_intf_p_0_halt           )
    ,.trgt1_radm_intf_np_0_halt           (trgt1_radm_intf_np_0_halt          )

    ,.d_trgt1_wreq_cmplt_dma              (d_trgt1_wreq_cmplt_dma             )
    ,.d_trgt1_wreq_cmplt_dma_channel      (d_trgt1_wreq_cmplt_dma_channel     )
    ,.d_trgt1_wreq_err_dma                (d_trgt1_wreq_err_dma               )


    ,.cfg_sch_p_hdr_ras_recc_correct       ( cfg_ras_recc_ib_sch_p_hdr_correct             )
    ,.sch_p_hdr_ras_recc_corr_cnt_pulse    ( ibreq_ras_recc_corr_cnt_ib_sch_p_hdr_pulse    )
    ,.sch_p_hdr_ras_recc_ucorr_cnt_pulse   ( ibreq_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse   )
    ,.sch_p_hdr_ras_recc_cnt_addr          ( ibreq_ras_recc_cnt_ib_sch_p_hdr_addr          )
    ,.axi_ras_par_ib_sch_p_ad_pulse        ( axi_ras_par_ib_sch_p_ad_pulse_g               )
    ,.cfg_sch_p_data_ras_recc_correct      ( cfg_ras_recc_ib_sch_p_data_correct            )
    ,.sch_p_data_ras_recc_corr_cnt_pulse   ( ibreq_ras_recc_corr_cnt_ib_sch_p_data_pulse   )
    ,.sch_p_data_ras_recc_ucorr_cnt_pulse  ( ibreq_ras_recc_ucorr_cnt_ib_sch_p_data_pulse  )
    ,.sch_p_data_ras_recc_cnt_addr         ( ibreq_ras_recc_cnt_ib_sch_p_data_addr         )
    ,.axi_ras_par_ib_sch_p_dt_pulse        ( axi_ras_par_ib_sch_p_dt_pulse_g               )
    ,.cfg_sch_np_hdr_ras_recc_correct      ( cfg_ras_recc_ib_sch_np_hdr_correct            )
    ,.sch_np_hdr_ras_recc_corr_cnt_pulse   ( ibreq_ras_recc_corr_cnt_ib_sch_np_hdr_pulse   )
    ,.sch_np_hdr_ras_recc_ucorr_cnt_pulse  ( ibreq_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse  )
    ,.sch_np_hdr_ras_recc_cnt_addr         ( ibreq_ras_recc_cnt_ib_sch_np_hdr_addr         )
    ,.axi_ras_par_ib_sch_np_ad_pulse       ( axi_ras_par_ib_sch_np_ad_pulse_g              )
    ,.cfg_sch_np_data_ras_recc_correct     ( cfg_ras_recc_ib_sch_np_data_correct           )
    ,.sch_np_data_ras_recc_corr_cnt_pulse  ( ibreq_ras_recc_corr_cnt_ib_sch_np_data_pulse  )
    ,.sch_np_data_ras_recc_ucorr_cnt_pulse ( ibreq_ras_recc_ucorr_cnt_ib_sch_np_data_pulse )
    ,.sch_np_data_ras_recc_cnt_addr        ( ibreq_ras_recc_cnt_ib_sch_np_data_addr        )
    ,.axi_ras_par_ib_sch_np_dt_pulse       ( axi_ras_par_ib_sch_np_dt_pulse_g              )
    ,.axi_ras_par_rtrgt_p_ad_pulse        ( axi_ras_par_rtrgt_p_ad_pulse_g             )
    ,.axi_ras_par_rtrgt_p_dt_pulse        ( axi_ras_par_rtrgt_p_dt_pulse_g             )
    ,.axi_ras_par_rtrgt_np_ad_pulse       ( axi_ras_par_rtrgt_np_ad_pulse_g            )
    ,.axi_ras_par_rtrgt_np_dt_pulse       ( axi_ras_par_rtrgt_np_dt_pulse_g            )
    ,.axi_ras_par_rtrgt_cpl_ad_pulse      ( axi_ras_par_rtrgt_cpl_ad_pulse_g           )
    ,.axi_ras_par_rtrgt_cpl_dt_pulse      ( axi_ras_par_rtrgt_cpl_dt_pulse_g           )
    ,.axi_rtrgt_p_ad_ras_dp_err_log          (axi_rtrgt_p_ad_ras_dp_err_log            )
    ,.axi_rtrgt_p_dt_ras_dp_err_log          (axi_rtrgt_p_dt_ras_dp_err_log            )
    ,.axi_rtrgt_np_ad_ras_dp_err_log         (axi_rtrgt_np_ad_ras_dp_err_log           )
    ,.axi_rtrgt_np_dt_ras_dp_err_log         (axi_rtrgt_np_dt_ras_dp_err_log           )
    ,.axi_rtrgt_cpl_ad_ras_dp_err_log        (axi_rtrgt_cpl_ad_ras_dp_err_log          )
    ,.axi_rtrgt_cpl_dt_ras_dp_err_log        (axi_rtrgt_cpl_dt_ras_dp_err_log          )
    ,.axi_ib_sch_p_ad_ras_dp_err_log         (axi_ib_sch_p_ad_ras_dp_err_log           )
    ,.axi_ib_sch_p_dt_ras_dp_err_log         (axi_ib_sch_p_dt_ras_dp_err_log           )
    ,.sch_p_data_recc_corr_cnt_ras_dp_err_log(sch_p_data_recc_corr_cnt_ras_dp_err_log  )
    ,.sch_p_hdr_recc_corr_cnt_ras_dp_err_log (sch_p_hdr_recc_corr_cnt_ras_dp_err_log   )

    ,.axi_ib_sch_np_ad_ras_dp_err_log          (axi_ib_sch_np_ad_ras_dp_err_log        )
    ,.axi_ib_sch_np_dt_ras_dp_err_log          (axi_ib_sch_np_dt_ras_dp_err_log        )
    ,.sch_np_data_recc_corr_cnt_ras_dp_err_log(sch_np_data_recc_corr_cnt_ras_dp_err_log)
    ,.sch_np_hdr_recc_corr_cnt_ras_dp_err_log  (sch_np_hdr_recc_corr_cnt_ras_dp_err_log)
    ,.core_clk_ordrb_ras_dp_err_inj            (core_clk_ordrb_ras_dp_err_inj          )
    ,.ib_scheduler_p_hdr_ram_wea         ( ib_scheduler_p_hdr_ram_wea                  )
    ,.ib_scheduler_p_hdr_ram_addra       ( ib_scheduler_p_hdr_ram_addra                )
    ,.ib_scheduler_p_hdr_ram_dina        ( ib_scheduler_p_hdr_ram_dina                 )
    ,.ib_scheduler_p_hdr_ram_addrb       ( ib_scheduler_p_hdr_ram_addrb                )
    ,.ib_scheduler_p_hdr_ram_enb         ( ib_scheduler_p_hdr_ram_enb                  )
    ,.ib_scheduler_p_hdr_ram_doutb       ( ib_scheduler_p_hdr_ram_doutb                )
    ,.ib_scheduler_p_data_ram_wea        ( ib_scheduler_p_data_ram_wea                 )
    ,.ib_scheduler_p_data_ram_addra      ( ib_scheduler_p_data_ram_addra               )
    ,.ib_scheduler_p_data_ram_dina       ( ib_scheduler_p_data_ram_dina                )
    ,.ib_scheduler_p_data_ram_addrb      ( ib_scheduler_p_data_ram_addrb               )
    ,.ib_scheduler_p_data_ram_enb        ( ib_scheduler_p_data_ram_enb                 )
    ,.ib_scheduler_p_data_ram_doutb      ( ib_scheduler_p_data_ram_doutb               )
    ,.ib_scheduler_np_hdr_ram_wea        ( ib_scheduler_np_hdr_ram_wea                 )
    ,.ib_scheduler_np_hdr_ram_addra      ( ib_scheduler_np_hdr_ram_addra               )
    ,.ib_scheduler_np_hdr_ram_dina       ( ib_scheduler_np_hdr_ram_dina                )
    ,.ib_scheduler_np_hdr_ram_addrb      ( ib_scheduler_np_hdr_ram_addrb               )
    ,.ib_scheduler_np_hdr_ram_enb        ( ib_scheduler_np_hdr_ram_enb                 )
    ,.ib_scheduler_np_hdr_ram_doutb      ( ib_scheduler_np_hdr_ram_doutb               )
    ,.ib_scheduler_np_data_ram_wea       ( ib_scheduler_np_data_ram_wea                )
    ,.ib_scheduler_np_data_ram_addra     ( ib_scheduler_np_data_ram_addra              )
    ,.ib_scheduler_np_data_ram_dina      ( ib_scheduler_np_data_ram_dina               )
    ,.ib_scheduler_np_data_ram_addrb     ( ib_scheduler_np_data_ram_addrb              )
    ,.ib_scheduler_np_data_ram_enb       ( ib_scheduler_np_data_ram_enb                )
    ,.ib_scheduler_np_data_ram_doutb     ( ib_scheduler_np_data_ram_doutb              )
    ,.ibreq_presp_rpseq                  ( s_ib_rpseqn.s_struct.vc                     )
    ,.ibreq_presp_cmplt                  ( ibreq_presp_cmplt                           )
    ,.ibreq_presp_dma_chan_num           ( ibreq_presp_dma_chan_num                    )
    ,.ibreq_presp_dma_err                ( ibreq_presp_dma_err                         )
    ,.ibreq_presp_type                   ( ibreq_presp_type                            )
    ,.ibreq_cfg_rpseq                    ( s_ibr_rpseqn.s_struct.vc                    )
    ,.trgt1_p_xfer_pend_per_vc           ( trgt1_p_xfer_pend_per_vc                    )
    );

  assign inbd_header_pnp_wr_uppr_bytes = {{(HDR_UPPR_BYTES_WD-`FLT_Q_ADDR_WIDTH){1'b0}},s_inbd_header_pnp_wr_uppr_bytes};



assign axi_ras_par_rbyp_ad_pulse_g = 1'b0;
assign axi_ras_par_rbyp_dt_pulse_g = 1'b0;
assign axi_rbyp_ad_ras_dp_err_log_g = ({{RAS_ERROR_LOG_WD{1'b0}},1'b0});
assign axi_rbyp_dt_ras_dp_err_log_g = ({{RAS_ERROR_LOG_WD{1'b0}},1'b0});


  assign s_inbd_header_pnp_wr  = f_kInjectPostedID(inbd_header_pnp_wr);

// The logic below is to allow the AW address bus to take the address from the CDM register in case the transaction is a Msg/ MsgD
// Mux in DWC_pcie_axi_gm
   wire [`MASTER_BUS_ADDR_WIDTH-1:0]             msg_addr_mstr;
  generate
  if(`MASTER_BUS_ADDR_WIDTH == 32) begin : gen_msg_addr_mstr
    assign msg_addr_mstr  = qmstr_d.cfg_aximstr_msg_addr_low;
  end else begin
    assign msg_addr_mstr  = {qmstr_d.cfg_aximstr_msg_addr_high,qmstr_d.cfg_aximstr_msg_addr_low};
  end
  endgenerate
   // Generating parity for the msg address from CDM
   wire [ (`CC_MSTR_BUS_ADDR_WIDTH - `MASTER_BUS_ADDR_WIDTH) -1:0] msg_addrp_mstr;




  // IB -> use IB stream only
  assign s_ibr_rpseqn = s_ib_rpseqn;

DWC_pcie_axi_mstr_ar_if mstr_ar ();
DWC_pcie_axi_mstr_aw_if mstr_aw ();
DWC_pcie_axi_mstr_w_if  mstr_w  ();
DWC_pcie_axi_mstr_r_if  mstr_r  ();
DWC_pcie_axi_mstr_b_if  mstr_b  ();

DWC_pcie_axi_mstr_ar_if ib_mstr_ar ();
DWC_pcie_axi_mstr_aw_if ib_mstr_aw ();
DWC_pcie_axi_mstr_w_if  ib_mstr_w  ();
DWC_pcie_axi_mstr_r_if  ib_mstr_r  ();
DWC_pcie_axi_mstr_b_if  ib_mstr_b  ();


   DWC_pcie_bridge_ib
   
     #(
       // -------------------------------------------------------------------------------------
       // Master
       .MAX_MSTR_TAG_PW               (`CC_MAX_MSTR_TAG_PW)
       ,.MSTR_BE_CTRL_WD              (`CC_MSTR_BE_CTRL_WIDTH)
       ,.MSTR_MTU_PW                  (`CC_MSTR_MTU_PW)
       ,.MSTR_DATA_WD                 (`CC_MSTR_BUS_DATA_WIDTH)
       ,.MSTR_DATAP_WD                (`CC_MSTR_BUS_DATAP_WIDTH)
       ,.MSTR_ADDR_WD                 (`CC_MSTR_BUS_ADDR_WIDTH)
       ,.MSTR_ADDR_WD_NP              (`MASTER_BUS_ADDR_WIDTH)
       ,.MSTR_BUS_ADDRP_WIDTH         (`CC_MSTR_BUS_ADDRP_WIDTH)
       ,.MSTR_LOCK_WD                 (`CC_AXI_LOCK_WIDTH)
       ,.MSTR_WSTRB_WD                (`CC_MSTR_BUS_WSTRB_WIDTH)
       ,.MSTR_ID_WD                   (`CC_MSTR_BUS_ID_WIDTH_NP)
       ,.MSTR_BURST_LEN_PW            (`CC_MSTR_BURST_LEN_PW)
       ,.MSTR_MISC_INFO_PW            (`MSTR_MISC_INFO_PW)
       ,.MSTR_RESP_MISC_INFO_PW       (`MSTR_RESP_MISC_INFO_PW)
       ,.MSTR_MISC_INFO_WD            (`MSTR_MISC_INFO_WD)
       ,.MSTR_RESP_MISC_INFO_WD       (`MSTR_RESP_MISC_INFO_WD)
       ,.CORE_DATA_BUS_WD             (`CC_CORE_DATA_BUS_WD)
       ,.CORE_DATA_BUS_WSTRB_WD       (`CC_CORE_DATA_BUS_WSTRB_WD)

       ,.MSTR_RSP_BYTE_WD             (`CC_MSTR_RSP_BYTE_WD)
       ,.MSTR_RSP_DATA_WD             (`CC_MSTR_RSP_DATA_WD)
       ,.MSTR_BUS_WSTRB_WIDTH         (`CC_MSTR_BUS_WSTRB_WIDTH)
       ,.MSTR_NW                      (`CC_MSTR_NW)
       ,.MASTER_BUS_DATA_SIZE_ENC     (`CC_MASTER_BUS_DATA_SIZE_ENC)
       ,.CX_REMOTE_MAX_TAG            (`CX_REMOTE_MAX_TAG)
       ,.CX_REMOTE_MAX_TAGS           (`CX_REMOTE_MAX_TAGS)

       ,.MAX_MSTR_TAGS                (`CC_MAX_MSTR_TAGS)

       ,.MSTR_MAX_SPLIT_PACK_PW       (`CC_MSTR_MAX_SPLIT_PACK_PW)

       // Generic Master
       ,.AXI_AWPROT_0                 (`GMX_AXI_AWPROT_0)
       ,.AXI_AWPROT_1                 (`GMX_AXI_AWPROT_1)
       ,.AXI_AWPROT_2                 (`GMX_AXI_AWPROT_2)
       ,.AXI_ARPROT_0                 (`GMX_AXI_ARPROT_0)
       ,.AXI_ARPROT_1                 (`GMX_AXI_ARPROT_1)
       ,.AXI_ARPROT_2                 (`GMX_AXI_ARPROT_2)

       ,.CC_WR_CH_NP_RSP_QUEUE_DP     (`CC_WR_CH_NP_RSP_QUEUE_DP)
       ,.CC_WR_CH_NP_RSP_QUEUE_DP_LOG2(`CC_WR_CH_NP_RSP_QUEUE_DP_LOG2)

       //---------------------
       ,.PF_WD                        (`CX_NFUNC_WD)
       ,.VF_WD                        (`CX_NVFUNC_WD)

       ,.TPH_ST_WD                    (TPH_ST_WD)
       ,.TPH_PH_WD                    (TPH_PH_WD)
       ,.TPH_TH_WD                    (TPH_TH_WD)
       ,.MISC_INFO_TPH_WD             (MISC_INFO_TPH_WD)
       //----------------------
       ,.DC_INBD_HEADER_PNP_1STG_WD   (`DC_INBD_HEADER_PNP_1STG_WD)
       ,.DC_INBD_HEADER_PNP_1STG_WD_NP(`DC_INBD_HEADER_PNP_1STG_WD_NP)
       ,.DC_INBD_HEADER_PNP_WD        (`DC_INBD_HEADER_PNP_WD)
       ,.DC_INBD_MISCINFO_WD          (`DC_INBD_MISCINFO_WD)
       ,.CX_RAS_RAM_PROT_RANGE        (`CX_RAS_RAM_PROT_RANGE)
       ,.CC_MRF_C2A_FIFO_SYNC_REGS    (`CX_PCIE_SYNC_DEPTH)
       ,.CC_MRF_A2C_FIFO_SYNC_REGS    (`CX_PCIE_SYNC_DEPTH)
       ,.CC_MRF_C2A_FIFO_HOLD_RD_ADDR (CC_MRF_C2A_FIFO_HOLD_RD_ADDR)
       ,.CC_MSTR_NUM_CONV_WD          (`CC_MSTR_NUM_CONV_WD)
       ,.CX_NW                        (`CX_NW)
       ,.CC_AMBA_TLP_SEQ_WD           (`CC_AMBA_TLP_SEQ_WD)
       ,.CX_NFUNC                     (`CX_NFUNC)
       ,.RADMX_TRGT1_REQ_HDR_WD       (`CC_RADMX_TRGT1_REQ_HDR_WD)
       ,.CX_NFUNC_WD                  (`CX_NFUNC_WD)
       ,.REMOTE_MAX_RD_SIZE_PW        (`CX_REMOTE_RD_REQ_SIZE_PW)
       ,.CX_REMOTE_MAX_TAGS_WD        (`CC_MAX_MSTR_TAG_PW)
       ,.DC_DMA_TYPE_WIDTH            (`DC_DMA_TYPE_WIDTH)
       ,.CC_NUM_DMA_WR_CHAN           (`CC_NUM_DMA_WR_CHAN)
       ,.CC_NUM_DMA_WR_CHAN_WIDTH     (`CC_NUM_DMA_WR_CHAN_WIDTH)
       ,.CC_NUM_DMA_RD_CHAN_WIDTH     (`CC_NUM_DMA_RD_CHAN_WIDTH)
       ,.CC_NUM_DMA_MAX_CHAN_WIDTH    (`CC_NUM_DMA_MAX_CHAN_WIDTH)
       ,.CX_NVC_LOG2                  (`CX_NVC_LOG2)
       ,.RX_TLP_PREFIX_WD             (`FLT_Q_PRFX_WIDTH)
       ,.NW_PRFX                      (`CX_NPRFX)
       ,.PRFX_PAR_WD                  (`CX_PRFX_PAR_WD)
       ,.TX_TLP_PREFIX_WD             (TX_TLP_PREFIX_WD)
       ,.ADDR_PAR_WD                  (`CX_ADDR_PAR_WD)

       ,.CX_TAG_SIZE                  (`CX_TAG_SIZE)
       ,.P_N_PRESP_STREAMS            (K_N_IB_PRESP_STREAMS)
       ,.P_N_PRESP_STREAMS_WD         (K_N_IB_PRESP_STREAMS_WD)
       ,.P_N_PRESP_STREAMS_W_RO_WD    (K_N_IB_PRESP_STREAMS_W_RO_WD)
       ,.P_NP_PASS_P_WD               (K_N_IB_PRESP_STREAMS)
       ,.P_CFG_IB_P_ID_MNG_CTRL_TYPE  (cdmIbPIdMngCtrl_s)

       // -------------------------------------------------------------------------------------
       // Master completion buffer
       ,.MSTR_CPL_DATA_SEG_DP             (`CC_MSTR_CPL_DATA_SEG_DP)
       ,.MSTR_CPL_SEG_DATA_WD             (`CC_MSTR_CPL_SEG_DATA_WD)
       ,.MSTR_CPL_SEG_DATA_WD_NP          (`CC_MSTR_CPL_SEG_DATA_WD_NP)
       ,.MSTR_CPL_SEG_DATA_NUM_DWORDS     (`CC_MSTR_CPL_SEG_DATA_NUM_DWORDS)
       ,.MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2(`CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2)
       ,.MSTR_CPL_SEG_DATA_NUM_BYTES      (`CC_MSTR_CPL_SEG_DATA_NUM_BYTES)
       ,.MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 (`CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2)
       ,.MSTR_CPL_SEG_DATA_SIZE_ENC       (`CC_MSTR_CPL_SEG_DATA_SIZE_ENC)
       ,.MSTR_CPL_DATA_WD                 (`CC_MSTR_CPL_DATA_WD)
       ,.PCIE_CORE_NUM_BYTES              (`CC_PCIE_CORE_NUM_BYTES)
       ,.MSTR_RSP_INTF_WD                 (`CC_MSTR_RSP_INTF_WD)
       ,.MSTR_RSP_INTF_WD_NP              (`CC_MSTR_RSP_INTF_WD_NP)
       // -------------------------------------------------------------------------------------
       // External RAMs
       // Master read/write request CDC FIFO RAMs
       ,.CC_IB_RD_REQ_CDC_RAM_DP             (`CC_IB_RD_REQ_CDC_RAM_DP)
       ,.CC_IB_WR_REQ_CDC_RAM_DP             (`CC_IB_WR_REQ_CDC_RAM_DP)
       ,.CC_IB_RD_REQ_CDC_RAM_ADDR_WD        (`CC_IB_RD_REQ_CDC_RAM_ADDR_WD)
       ,.CC_IB_RD_REQ_CDC_RAM_ADDRP_WD       (`CC_IB_RD_REQ_CDC_RAM_ADDRP_WD)
       ,.CC_IB_WR_REQ_CDC_RAM_ADDR_WD        (`CC_IB_WR_REQ_CDC_RAM_ADDR_WD)
       ,.CC_IB_WR_REQ_CDC_RAM_ADDRP_WD       (`CC_IB_WR_REQ_CDC_RAM_ADDRP_WD)
       ,.CC_IB_WR_REQ_CDC_RAM_DATA_WD        (`CC_IB_WR_REQ_CDC_RAM_DATA_WD)
       ,.CC_IB_WR_REQ_CDC_RAM_DATA_WD_NOECC  (`CC_IB_WR_REQ_CDC_RAM_DATA_WD_NOECC)
       ,.CC_IB_RD_REQ_CDC_RAM_DATA_WD        (`CC_IB_RD_REQ_CDC_RAM_DATA_WD)
       ,.CC_IB_RD_REQ_CDC_RAM_DATA_WD_NOECC  (`CC_IB_RD_REQ_CDC_RAM_DATA_WD_NOECC)
       // Master request Order FIFO RAM
       ,.CC_IB_RD_REQ_ORDR_RAM_ADDR_WD       (`CC_IB_RD_REQ_ORDR_RAM_ADDR_WD)
       ,.CC_IB_RD_REQ_ORDR_RAM_ADDRP_WD      (`CC_IB_RD_REQ_ORDR_RAM_ADDRP_WD)
       ,.CC_IB_RD_REQ_ORDR_RAM_DATA_WD       (`CC_IB_RD_REQ_ORDR_RAM_DATA_WD)
       // Master Completion Buffer
       ,.CC_IB_MCPL_SEG_BUF_RAM_DATA_WD      (`CC_IB_MCPL_SEG_BUF_RAM_DATA_WD)
       ,.CC_IB_MCPL_SEG_BUF_RAM_DP           (`CC_IB_MCPL_SEG_BUF_RAM_DP)
       ,.CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD      (`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD)
       ,.CC_IB_MCPL_SEG_BUF_RAM_ADDRP_WD     (`CC_IB_MCPL_SEG_BUF_RAM_ADDRP_WD)
       ,.CC_IB_MCPL_CDC_RAM_ADDR_WD          (`CC_IB_MCPL_CDC_RAM_ADDR_WD)
       ,.CC_IB_MCPL_CDC_RAM_ADDRP_WD         (`CC_IB_MCPL_CDC_RAM_ADDRP_WD)
       ,.CC_IB_MCPL_CDC_RAM_DATA_WD          (`CC_IB_MCPL_CDC_RAM_DATA_WD)
       ,.CC_IB_MCPL_CDC_RAM_DP               (`CC_IB_MCPL_CDC_RAM_DP)
       ,.CC_MSTR_CPL_C2A_FIFO_DEPTH          (`CC_MSTR_CPL_C2A_FIFO_DEPTH)
       ,.CC_MSTR_CPL_C2A_FIFO_WD             (`CC_MSTR_CPL_C2A_FIFO_WD)
       ,.CC_MSTR_CPL_QUEUE_DP                (`CC_MSTR_CPL_QUEUE_DP)
       ,.CC_MSTR_CPL_QUEUE_DP_LOG2           (`CC_MSTR_CPL_QUEUE_DP_LOG2)
       //-----------------

       )
   u_ib (
          .core_clk(core_clk)
         ,.core_rstn(core_rst_n)
         ,.mstr_aclk(mstr_aclk_g)
         ,.mstr_arstn(mstr_aresetn)

         // -------------------------------------------------------------------------------------
         // Flush interface
         // -------------------------------------------------------------------------------------
         ,.rstctl_mstr_flush_req(rstctl_mstr_flush_req)

         // -------------------------------------------------------------------------------------
         // Configuration interface
         // -------------------------------------------------------------------------------------
         ,.cfg_max_payload_size(cfg_max_payload_size)

         ,.cfg_mstr_arcache_mode(qmstr_d.cfg_mstr_arcache_mode)
         ,.cfg_mstr_awcache_mode(qmstr_d.cfg_mstr_awcache_mode)
         ,.cfg_mstr_arcache_value(qmstr_d.cfg_mstr_arcache_value)
         ,.cfg_mstr_awcache_value(qmstr_d.cfg_mstr_awcache_value)
         ,.cfg_mstr_ardomain_mode(qmstr_d.cfg_mstr_ardomain_mode)
         ,.cfg_mstr_awdomain_mode(qmstr_d.cfg_mstr_awdomain_mode)
         ,.cfg_mstr_ardomain_value(qmstr_d.cfg_mstr_ardomain_value)
         ,.cfg_mstr_awdomain_value(qmstr_d.cfg_mstr_awdomain_value)
         ,.cfg_ax_mstr_zeroread_fw(qmstr_d.cfg_ax_mstr_zeroread_fw)
         ,.cfg_aximstr_msg_addr_high_d1(qmstr_d.cfg_aximstr_msg_addr_high)
         ,.cfg_aximstr_msg_addr_low_d1(qmstr_d.cfg_aximstr_msg_addr_low)


         ,.cfg_ib_p_id_mng_ctrl(cfg_ib_p_id_mng_ctrl_a2m)

         ,.msg_addr(msg_addr_mstr)
         ,.msg_addrp(msg_addrp_mstr)
         // -------------------------------------------------------------------------------------
         // RAS
         // -------------------------------------------------------------------------------------

         ,.cfg_rdq_mrf_ras_recc_correct(qmstr_d.cfg_ras_recc_ib_rreq_c2a_cdc_correct)
         ,.rdq_mrf_ras_recc_corr_cnt_pulse(ibreq_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse)
         ,.rdq_mrf_ras_recc_ucorr_cnt_pulse(ibreq_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse)
         ,.rdq_mrf_ras_recc_cnt_addr(ibreq_ras_recc_cnt_ib_rreq_c2a_cdc_addr)
         ,.cfg_wrq_mrf_ras_recc_correct(qmstr_d.cfg_ras_recc_ib_wreq_c2a_cdc_correct)
         ,.wrq_mrf_ras_recc_corr_cnt_pulse(ibreq_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse)
         ,.wrq_mrf_ras_recc_ucorr_cnt_pulse(ibreq_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse)
         ,.wrq_mrf_ras_recc_cnt_addr(ibreq_ras_recc_cnt_ib_wreq_c2a_cdc_addr)
         ,.rdq_mrf_recc_cnt_ras_dp_err_log (rdq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log)
         ,.wrq_mrf_recc_cnt_ras_dp_err_log (wrq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log)
         ,.axi_bridge_ras_dp_err_inj_core_clk (axi_bridge_ras_dp_err_inj_core_clk)
         ,.core_clk_hp_mstr_ras_dp_err_inj    (core_clk_hp_mstr_ras_dp_err_inj   )  // u_ib.u_mcb
         ,.ras_dp_err_inj_mstr_aclk           (ras_dp_err_inj_mstr_aclk)
         ,.cfg_ras_recc_ib_mcpl_a2c_cdc_correct(cfg_ras_recc_ib_mcpl_a2c_cdc_correct)
         ,.mcb_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse(mcb_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse)
         ,.mcb_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse(mcb_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse)
         ,.mcb_ras_recc_cnt_ib_mcpl_a2c_cdc_addr(mcb_ras_recc_cnt_ib_mcpl_a2c_cdc_addr)
         ,.mcb_ras_par_ib_mcpl_a2c_dt_pulse(mcb_ras_par_ib_mcpl_a2c_dt_pulse)
         ,.mcb_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log(mcb_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log)
         ,.mcb_ib_mcpl_a2c_dt_ras_dp_err_log(mcb_ib_mcpl_a2c_dt_ras_dp_err_log)
         ,.cfg_ras_recc_ib_mcpl_sb_correct(cfg_ras_recc_ib_mcpl_sb_correct)
         ,.mcb_ras_recc_corr_cnt_ib_mcpl_sb_pulse(mcb_ras_recc_corr_cnt_ib_mcpl_sb_pulse)
         ,.mcb_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse(mcb_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse)
         ,.mcb_ras_recc_cnt_ib_mcpl_sb_addr(mcb_ras_recc_cnt_ib_mcpl_sb_addr)
         ,.mcb_ras_par_ib_mcpl_sb_dt_pulse(mcb_ras_par_ib_mcpl_sb_dt_pulse)
         ,.axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log (axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log)
         ,.mcb_ib_mcpl_sb_dt_ras_dp_err_log       (mcb_ib_mcpl_sb_dt_ras_dp_err_log)

         ,.axi_ras_par_ibr_rmstr_ad_pulse(axigm_ras_par_ibr_rmstr_ad_pulse)
         ,.axi_ras_par_ibr_wmstr_ad_pulse(axigm_ras_par_ibr_wmstr_ad_pulse)
         ,.axi_ras_par_ibr_wmstr_dt_pulse(axigm_ras_par_ibr_wmstr_dt_pulse)
         ,.axi_ibr_rmstr_ad_ras_dp_err_log(axigm_ibr_rmstr_ad_ras_dp_err_log)
         ,.axi_ibr_wmstr_ad_ras_dp_err_log(axigm_ibr_wmstr_ad_ras_dp_err_log)
         ,.axi_ibr_wmstr_dt_ras_dp_err_log(axigm_ibr_wmstr_dt_ras_dp_err_log)





         ,.inbd_header_pnp_wr(s_inbd_header_pnp_wr)
         ,.radm_trgt1_hdr_uppr_bytes(inbd_header_pnp_wr_uppr_bytes)
         ,.inbd_data_pnp_wr(inbd_data_pnp_wr)
         ,.inbd_halt_pnp_wr(inbd_halt_pnp_wr)

         ,.inbd_header_pnp_rd(inbd_header_pnp_rd)
         ,.inbd_halt_pnp_rd(inbd_halt_pnp_rd)

         //2pRAM interface
         ,.ib_rreq_c2a_cdc_ram_addra(ib_rreq_c2a_cdc_ram_addra)
         ,.ib_rreq_c2a_cdc_ram_addrb(ib_rreq_c2a_cdc_ram_addrb)
         ,.ib_rreq_c2a_cdc_ram_wea(ib_rreq_c2a_cdc_ram_wea)
         ,.ib_rreq_c2a_cdc_ram_enb(ib_rreq_c2a_cdc_ram_enb)
         ,.ib_rreq_c2a_cdc_ram_doutb(ib_rreq_c2a_cdc_ram_doutb)
         ,.ib_rreq_c2a_cdc_ram_dina(ib_rreq_c2a_cdc_ram_dina)
         ,.ib_wreq_c2a_cdc_ram_addra(ib_wreq_c2a_cdc_ram_addra)
         ,.ib_wreq_c2a_cdc_ram_addrb(ib_wreq_c2a_cdc_ram_addrb)
         ,.ib_wreq_c2a_cdc_ram_wea(ib_wreq_c2a_cdc_ram_wea)
         ,.ib_wreq_c2a_cdc_ram_enb(ib_wreq_c2a_cdc_ram_enb)
         ,.ib_wreq_c2a_cdc_ram_doutb(ib_wreq_c2a_cdc_ram_doutb)
         ,.ib_wreq_c2a_cdc_ram_dina(ib_wreq_c2a_cdc_ram_dina)

         // Master completion buffer segment buffer RAM outputs
         ,.ib_mcpl_sb_ram_addra(ib_mcpl_sb_ram_addra)
         ,.ib_mcpl_sb_ram_wea(ib_mcpl_sb_ram_wea)
         ,.ib_mcpl_sb_ram_dina(ib_mcpl_sb_ram_dina)
         ,.ib_mcpl_sb_ram_addrb(ib_mcpl_sb_ram_addrb)
         ,.ib_mcpl_sb_ram_enb(ib_mcpl_sb_ram_enb)
         ,.ib_mcpl_sb_ram_doutb(ib_mcpl_sb_ram_doutb)
         // Master completion buffer AMBA to PCIe core clock domain crossing FIFO RAM outputs
         ,.ib_mcpl_a2c_cdc_ram_addra(ib_mcpl_a2c_cdc_ram_addra)
         ,.ib_mcpl_a2c_cdc_ram_wea(ib_mcpl_a2c_cdc_ram_wea)
         ,.ib_mcpl_a2c_cdc_ram_dina(ib_mcpl_a2c_cdc_ram_dina)
         ,.ib_mcpl_a2c_cdc_ram_addrb(ib_mcpl_a2c_cdc_ram_addrb)
         ,.ib_mcpl_a2c_cdc_ram_enb(ib_mcpl_a2c_cdc_ram_enb)
         ,.ib_mcpl_a2c_cdc_ram_doutb(ib_mcpl_a2c_cdc_ram_doutb)
         ,.axi_ras_par_ibrd_dcmp_ad_pulse_g(axi_ras_par_ibrd_dcmp_ad_pulse_g)
         ,.axi_ras_par_ibwr_dcmp_ad_pulse_g(axi_ras_par_ibwr_dcmp_ad_pulse_g)
         ,.axi_ras_par_ibwr_dcmp_dt_pulse_g(axi_ras_par_ibwr_dcmp_dt_pulse_g)
         ,.axi_ibrd_dcmp_ad_ras_dp_err_log_g(axi_ibrd_dcmp_ad_ras_dp_err_log_g)
         ,.axi_ibwr_dcmp_ad_ras_dp_err_log_g(axi_ibwr_dcmp_ad_ras_dp_err_log_g)
         ,.axi_trgt1_dt_ras_dp_err_log_g(axi_trgt1_dt_ras_dp_err_log_g)
         ,.axi_ras_par_ibrd_mrf_ad_pulse_g(axi_ras_par_ibrd_mrf_ad_pulse_g)
         ,.axi_ras_par_ibwq_mrf_ad_pulse_g(axi_ras_par_ibwq_mrf_ad_pulse_g)
         ,.axi_ras_par_ibwq_mrf_dt_pulse_g(axi_ras_par_ibwq_mrf_dt_pulse_g)
         ,.axi_mstr_req_rd_ad_ras_dp_err_log_g(axi_mstr_req_rd_ad_ras_dp_err_log_g)
         ,.axi_mstr_req_wr_ad_ras_dp_err_log_g(axi_mstr_req_wr_ad_ras_dp_err_log_g)
         ,.axi_mstr_req_dt_ras_dp_err_log_g(axi_mstr_req_dt_ras_dp_err_log_g)


         ,.dma_mcb_rdll_halt(dma_mcb_rdll_halt)
         ,.dma_mcb_wrll_halt(dma_mcb_wrll_halt)
         // -------------------------------------------------------------------------------------
         // Client interface
         // -------------------------------------------------------------------------------------
         ,.ibc0_tlp_hv(ibc0_tlp_hv)
         ,.ibc0_tlp_fmt(ibc0_tlp_fmt)
         ,.ibc0_tlp_type(ibc0_tlp_type)
         ,.ibc0_tlp_func_num(ibc0_tlp_func_num)
         ,.ibc0_cpl_status(ibc0_cpl_status)
         ,.ibc0_tlp_ep(ibc0_tlp_ep)
         ,.ibc0_tlp_byte_len(ibc0_tlp_byte_len)
         ,.ibc0_cpl_lookup_id(ibc0_cpl_lookup_id)
         ,.ibc0_tlp_dma_channel(ibc0_tlp_dma_channel)
         ,.ibc0_tlp_dma(ibc0_tlp_dma)
         ,.ibc0_tlp_prv_dma(ibc0_tlp_prv_dma)
         ,.ibc0_tlp_prv_dma_chan(ibc0_tlp_prv_dma_chan)
         ,.ibc0_tlp_dv(ibc0_tlp_dv)
         ,.ibc0_tlp_data(ibc0_tlp_data)
         ,.ibc0_tlp_eot(ibc0_tlp_eot)
         ,.ibc0_tlp_bad_eot(ibc0_tlp_bad_eot)
         ,.ibc0_cpl_last(ibc0_cpl_last)
         ,.ibc0_addr_align_en(ibc0_tlp_addr_align_en)
         ,.ibc0_cpl_bcm(ibc0_cpl_bcm)
         ,.ibc0_tlp_td(ibc0_tlp_td)
         ,.ibc0_tlp_attr(ibc0_tlp_attr)
         ,.ibc0_cpl_byte_cnt(ibc0_cpl_byte_cnt)
         ,.ibc0_tlp_ats(ibc0_tlp_ats)
         ,.ibc0_tlp_atu_bypass(ibc0_tlp_atu_bypass)
         ,.ibc0_tlp_tc(ibc0_tlp_tc)

         ,.ibc0_tlp_tid(ibc0_tlp_tid)
         ,.ibc0_tlp_addr(ibc0_tlp_addr)
         ,.ibc0_tlp_byte_en(ibc0_tlp_byte_en)
         ,.ibc0_cpl_cmpltr_id(ibc0_cpl_cmpltr_id)
         ,.xadm_ibc0_halt(xadm_ibc0_halt)

         //---------------------------------
         // Posted response interface
         //---------------------------------
         ,.ibreq_presp_cmplt        (ibreq_presp_cmplt       )
         ,.ibreq_presp_rpseq        (ibreq_presp_rpseq       )
         ,.ibreq_presp_dma_chan_num (ibreq_presp_dma_chan_num)
         ,.ibreq_presp_dma_err      (ibreq_presp_dma_err     )
         ,.ibreq_presp_type         (ibreq_presp_type        )
         ,.ibreq_cfg_rpseq          (s_ib_rpseqn             )


         ,.mstr_ar                  (mstr_ar.mstr_mp         )
         ,.mstr_aw                  (mstr_aw.mstr_mp         )
         ,.mstr_w                   (mstr_w.mstr_mp          )
         ,.mstr_r                   (mstr_r.mstr_mp          )
         ,.mstr_b                   (mstr_b.mstr_mp          )

         // AXI low power
         ,.csysreq(mstr_csysreq)
         ,.csysack(mstr_csysack)
         ,.cactive(mstr_cactive)


         );

   assign s_client0_tlp_hv           = ibc0_tlp_hv;
   assign s_client0_tlp_dv           = ibc0_tlp_dv;
   assign s_client0_tlp_eot          = ibc0_tlp_eot;
   assign s_client0_tlp_bad_eot      = ibc0_tlp_bad_eot;
   assign s_client0_cpl_last         = ibc0_cpl_last;
   assign s_client0_tlp_ats          = ibc0_tlp_ats;

   assign s_client0_tlp_atu_bypass   = ibc0_tlp_atu_bypass;
   assign s_client0_tlp_dma          = ibc0_tlp_dma;
   assign s_client0_tlp_dma_channel  = ibc0_tlp_dma_channel;
   assign s_client0_tlp_prv_dma      = ibc0_tlp_prv_dma;
   assign s_client0_tlp_prv_dma_chan = ibc0_tlp_prv_dma_chan;
   assign s_client0_addr_align_en    = ibc0_tlp_addr_align_en;
   assign s_client0_tlp_func_num     = ibc0_tlp_func_num;
   assign s_client0_cpl_cmpltr_id    = ibc0_cpl_cmpltr_id;
   assign s_client0_cpl_status       = ibc0_cpl_status;
   assign s_client0_cpl_bcm          = ibc0_cpl_bcm;
   assign s_client0_cpl_byte_cnt     = ibc0_cpl_byte_cnt;
   assign s_client0_tlp_fmt          = ibc0_tlp_fmt;
   assign s_client0_tlp_type         = ibc0_tlp_type;
   assign s_client0_tlp_td           = ibc0_tlp_td;
   assign s_client0_tlp_ep           = ibc0_tlp_ep;
   assign s_client0_tlp_attr         = ibc0_tlp_attr;
   assign s_client0_tlp_tid          = ibc0_tlp_tid;
   assign s_client0_tlp_byte_len     = ibc0_tlp_byte_len;
   assign s_client0_tlp_addr         = ibc0_tlp_addr;
   assign s_client0_tlp_byte_en      = ibc0_tlp_byte_en;
   assign s_client0_tlp_tc           = ibc0_tlp_tc;
   assign s_client0_tlp_data         = ibc0_tlp_data;
   assign s_client0_cpl_lookup_id    = ibc0_cpl_lookup_id;
   assign xadm_ibc0_halt             = s_xadm_client0_halt;

// Save the sequence number of the last completed P request for each VC
always@(posedge core_clk or negedge core_rst_n) begin : SEQ_IB_LAST_PRESP_RPSEQ_PER_VC_PROC

  integer i,j;

  if(!core_rst_n)begin
    for(i=0;i<`CX_NVC;i=i+1)begin
      ib_last_presp_rpseq_per_vc[i] <= #`TP '0;
    end
  end else begin
    for(j=0;j<`CX_NVC;j=j+1)begin
        if(ibreq_presp_cmplt && !ibreq_presp_type[0])
          ib_last_presp_rpseq_per_vc[j] <= #`TP ibreq_presp_rpseq;
    end
  end
end


  // ---------------------------------------------------------------------------
  // Outbound Data Path
  // ---------------------------------------------------------------------------
  // Slave Non-Posted Request Interface
  wire                                     sif_np_rd;
  wire                                     sif_np_wr;
  wire                                     sif_np_atomic;
  wire                                     sif_np_dmwr;
  wire                                     sif_np_first_wrp_split_xact;
  wire                                     sif_np_wrp_valid;
  wire [`CC_MAX_SLV_TAG_PW-1:0]            sif_np_tag;
  wire [`CC_SLV_BUS_ADDR_WIDTH-1:0]        sif_np_addr;
  wire [`CC_SLV_BUS_ID_WIDTH -1:0]         sif_np_id;
  wire [`CC_SLV_INT_BURST_LEN_PW -1:0]     sif_np_len;
  wire [2:0]                               sif_np_size;
  wire [1:0]                               sif_np_burst;
  wire                                     sif_np_last;
  wire [`CC_SLV_BUS_NPWSTRB_WIDTH-1:0]     sif_np_strb;
  wire [`CC_SLV_BUS_NPDATA_WIDTH-1:0]      sif_np_data;
  wire [4:0]                               sif_np_type;
  wire                                     sif_np_snp;
  wire                                     sif_np_ns;
  wire                                     sif_np_ro;
  wire [2:0]                               sif_np_tc;
  wire                                     sif_np_ep;
  wire [`CX_NFUNC_WD-1:0]                  sif_np_func_num;
  wire                                     sif_np_nw;
  wire [1:0]                               sif_np_ats;
  wire [TX_TLP_PREFIX_WD-1:0]              sif_np_tlpprfx;
  wire [MISC_INFO_TPH_WD-1:0]              sif_np_tph;
  wire                                     sif_np_atu_bypass;
  wire                                     sif_np_ido;
  wire [8:0]                               sif_np_dst_segment;
  wire [`DC_CPL_STATUS_WD-1:0]             sif_np_cpl_stat;
  // Slave Posted Request Interface
  wire                                     sif_p_valid;
  wire [`CC_SLV_BUS_ID_WIDTH-1:0]          sif_p_id;
  wire [`CC_SLV_BUS_ADDR_WIDTH-1:0]        sif_p_addr;
  wire [2:0]                               sif_p_size;
  wire [`CC_SLV_INT_BURST_LEN_PW-1:0]      sif_p_len;
  wire                                     sif_p_last;
  wire [`CC_SLV_BUS_WSTRB_WIDTH-1:0]       sif_p_strb;
  wire [`CC_SLV_BUS_WSTRB_WIDTH-1:0]       sif_p_ep_strb;
  wire [`CC_SLV_BUS_WSTRB_WIDTH-1:0]       sif_p_silentDrop_strb;
  wire [`CC_SLV_BUS_WSTRB_WIDTH-1:0]       sif_p_silentDrop_strb_masked;
  wire [`CC_SLV_BUS_DATA_WIDTH-1:0]        sif_p_data;
  wire [7:0]                               sif_p_msg_code;
  wire [4:0]                               sif_p_type;
  wire [2:0]                               sif_p_tc;
  wire                                     sif_p_ep, sif_p_ro, sif_p_ns;
  wire                                     sif_p_first_wrp_split_xact;
  wire                                     sif_p_wrp_valid;
  wire                                     sif_p_nw;
  wire [1:0]                               sif_p_ats;
  wire [`CX_NFUNC_WD-1:0]                  sif_p_func_num;
  wire [MISC_INFO_TPH_WD-1:0]              sif_p_tph;
  wire [TX_TLP_PREFIX_WD-1:0]              sif_p_tlpprfx;
  wire [`CX_TAG_SIZE-1:0]                  sif_p_tag;
  wire                                     sif_p_atu_bypass;
  wire                                     sif_p_ido;
  wire [8:0]                               sif_p_dst_segment;
  wire [`DC_CPL_STATUS_WD-1:0]             sif_p_cpl_stat;
  wire                                     prf_p_ready;
  // Posted Response Interface
  wire                                     pdcmp_p_rsp_valid;
  wire [`CC_SLV_BUS_ID_WIDTH-1:0]          pdcmp_p_rsp_id;
  wire [`DC_CPL_STATUS_WD-1:0]             pdcmp_p_rsp_cpl_stat;
  wire                                     pdcmp_p_rsp_null_or_err;
  wire                                     pdcmp_p_rsp_last;
  wire [2:0]                               pdcmp_p_rsp_vc_num;
  wire                                     mstream_p_rsp_valid;
  wire [`CC_SLV_BUS_ID_WIDTH-1:0]          mstream_p_rsp_id;
  wire [`DC_CPL_STATUS_WD-1:0]             mstream_p_rsp_cpl_stat;
  // Non Posted Atomic Response Interface
  wire                                     npdcmp_np_atomic_rsp_valid;
  wire [`CC_SLV_BUS_ID_WIDTH-1:0]          npdcmp_np_atomic_rsp_id;

  wire                                     nprf_ready;


  wire                                     sif_db_rd;
  wire                                     sif_db_wr;
  wire                                     sif_db_vldrq;
  wire [`CC_MAX_SLV_TAG_PW-1:0]            sif_db_tag;
  wire [`CC_DBI_SLV_BUS_ADDR_WIDTH-1:0]    sif_db_addr;
  wire [3:0]                               sif_db_strb;
  wire [`CC_SLV_INT_BURST_LEN_PW -1:0]     sif_db_len;
  wire [2:0]                               sif_db_size;
  wire [31:0]                              sif_db_data;
  wire                                     dbi_ready;
  // Data Bus Non-Posted Response Interface
  wire                                     dbi_valid;
  wire                                     dbi_last;
  wire [`CC_MAX_SLV_TAG_PW-1:0]            dbi_tag;
  wire [(`RESP_ERRBUS_WD)-1:0]  dbi_resp;
  wire [31:0]                              dbi_data;
  wire                                     sif_db_ready;
  // Slave Completion Interface
  wire                                     nprspf_valid;
  wire                                     nprspf_last;
  wire [`CC_SLV_BUS_DATA_WIDTH-1:0]        nprspf_data;
  wire [`CC_MAX_SLV_TAG_PW-1:0]            nprspf_tag;
  wire                                     nprspf_to;
  wire                                     nprspf_ido;
  wire                                     nprspf_ro;
  wire                                     nprspf_ns;
  wire [2:0]                               nprspf_tc;
  wire [2:0]                               nprspf_func_num;
  wire [2:0]                               nprspf_status;
  wire                                     nprspf_ep;
  wire [7:0]                               nprspf_cpl_segment;
  wire [8:0]                               nprspf_dst_segment;
  wire                                     sif_np_ready;

  wire                                     flshctl_sif_flush_req;
  wire                                     sif_flush_ack;
  // ---------------------------------------------------------------------------
  // Instantiate AXI Slave
  // ---------------------------------------------------------------------------


  wire [4:0]                            awmisc_info_type_int;
  //
  // Translate atomic operation and DMWr requests into the PCIe. Other NP specific Writes (CfgWr and IoWR) are
  // meant to be set directlty on awmis_cinfo since there is no mapping
  //
  // AXI Fetch ADD => 0x10e000
  // AXI SWAP      => 0x110000
  // AXI Compare   => 0x110001
  //
  // PCIe Fetch ADD => 0x01100
  // PCIe SWAP      => 0x01101
  // PCIe Compare   => 0x01110
  // PCIe DMWr      => 0x11011
  //
  assign awmisc_info_type_int =  (slv_aw_s.atop == `AXI_ATOP_LOAD_LE) ? `ATOP_FETCH_ADD :
                                ((slv_aw_s.atop == `AXI_ATOP_LOAD_BE) ? `ATOP_FETCH_ADD :
                                ((slv_aw_s.atop == `AXI_ATOP_SWAP)    ? `ATOP_SWAP      :
                                ((slv_aw_s.atop == `AXI_ATOP_CAS)     ? `ATOP_CAS       :
                                  slv_aw_s.misc_info[4:0])));


  wire                                 awmisc_info_atu_bypass_int;
  assign awmisc_info_atu_bypass_int = (|slv_aw_s.atop) ? 1'b1 : slv_aw_s.misc_info_s.atu_bypass;

  // address of a write request is replaced by the miscinfos awmisc_info_hdr_34dw for Msg and MsgD type transactions
   // Generating parity for the msg address from CDM
   logic [`CC_SLV_BUS_ADDR_WIDTH-1:0] msg_addr_w_par_slv;
   logic [`SLAVE_BUS_ADDR_WIDTH-1 :0] msg_addr_slv_int;

   assign msg_addr_slv_int = slv_aw_s.misc_info_s.hdr_34dw[`SLAVE_BUS_ADDR_WIDTH-1:0];

  assign slv_awaddr_tmp = ((awmisc_info_type_int[4:3] == 2'b10) && (slv_aw_s.misc_info[21] == 1'b0)) ? msg_addr_w_par_slv : slv_awaddr_s;


`endif // !UTB_NATIVE_AXI



DWC_pcie_axi_slv_ar_if slv_ar ();
DWC_pcie_axi_slv_aw_if slv_aw ();
DWC_pcie_axi_slv_w_if  slv_w  ();
DWC_pcie_axi_slv_r_if  slv_r  ();
DWC_pcie_axi_slv_b_if  slv_b  ();

DWC_pcie_axi_slv_ar_if s_slv_ar ();
DWC_pcie_axi_slv_aw_if s_slv_aw ();
DWC_pcie_axi_slv_w_if  s_slv_w  ();
DWC_pcie_axi_slv_r_if  s_slv_r  ();
DWC_pcie_axi_slv_b_if  s_slv_b  ();
/*
DWC_pcie_axi_dpram_if #(.RAM_ADDR_WD(`CC_SLV_CDC_AR_RAM_ADDR_WD), `ifdef CX_RAS_EN .RAM_ADDR_WD(1), `endif .RAM_DATA_WD(`CC_SLV_CDC_AR_RAM_DATA_WD)) slv_cdc_ar_ram ();
DWC_pcie_axi_dpram_if #(.RAM_ADDR_WD(`CC_SLV_CDC_AW_RAM_ADDR_WD), `ifdef CX_RAS_EN .RAM_ADDR_WD(1), `endif .RAM_DATA_WD(`CC_SLV_CDC_AW_RAM_DATA_WD)) slv_cdc_aw_ram ();
DWC_pcie_axi_dpram_if #(.RAM_ADDR_WD(`CC_SLV_CDC_W_RAM_ADDR_WD ), `ifdef CX_RAS_EN .RAM_ADDR_WD(1), `endif .RAM_DATA_WD(`CC_SLV_CDC_W_RAM_DATA_WD )) slv_cdc_w_ram  ();
DWC_pcie_axi_dpram_if #(.RAM_ADDR_WD(`CC_SLV_CDC_R_RAM_ADDR_WD ), `ifdef CX_RAS_EN .RAM_ADDR_WD(1), `endif .RAM_DATA_WD(`CC_SLV_CDC_R_RAM_DATA_WD )) slv_cdc_r_ram  ();
DWC_pcie_axi_dpram_if #(.RAM_ADDR_WD(`CC_SLV_CDC_B_RAM_ADDR_WD ), `ifdef CX_RAS_EN .RAM_ADDR_WD(1), `endif .RAM_DATA_WD(`CC_SLV_CDC_B_RAM_DATA_WD )) slv_cdc_b_ram  ();
*/

assign slv_ar.valid                  = slv_ar_s.valid;
assign slv_ar.addr                   = slv_araddr_s;
assign slv_ar.id                     = slv_ar_s.id;
assign slv_ar.len                    = slv_ar_s.len;
assign slv_ar.size                   = slv_ar_s.size;
assign slv_ar.burst                  = slv_ar_s.burst;
assign slv_ar.misc_info_type         = slv_ar_s.misc_info[4:0];
assign slv_ar.misc_info_snp          = slv_ar_s.misc_info[5];
assign slv_ar.misc_info_ns           = slv_ar_s.misc_info[8];
assign slv_ar.misc_info_ro           = slv_ar_s.misc_info[9];
assign slv_ar.misc_info_tc           = slv_ar_s.misc_info[12:10];
// XMERGE requirement gate valid signal
assign slv_ar.misc_info_db           = slv_ar_s.misc_info[21]&&slv_ar_s.valid;
assign slv_ar.misc_info_func_num     = 3'h0;
assign slv_ar.misc_info_nw           = slv_ar_s.misc_info_s.nw;
assign slv_ar.misc_info_ats          = slv_ar_s.misc_info_s.ats;
assign slv_ar.misc_info_tlpprfx      = { slv_armisc_info_tlpprfx_par, slv_ar_s.misc_info_s.tlpprfx};
assign slv_ar.misc_info_tph          = slv_ar_s.misc_info_s.tph;
assign slv_ar.misc_info_atu_bypass   = slv_ar_s.misc_info_s.atu_bypass;
assign slv_ar.misc_info_ido          = slv_ar_s.misc_info_s.ido;
assign slv_ar.misc_info_dst_segment  = slv_ar_s.misc_info_s.dst_segment;
assign slv_arready_s                 = slv_ar.ready;


assign slv_aw.valid                  = slv_aw_s.valid;
assign slv_aw.addr                   = slv_awaddr_tmp;
assign slv_aw.id                     = slv_aw_s.id;
assign slv_aw.len                    = slv_aw_s.len;
assign slv_aw.size                   = slv_aw_s.size;
assign slv_aw.burst                  = slv_aw_s.burst;
assign slv_aw.atop                   = slv_aw_s.atop;
assign slv_aw.misc_info_type         = awmisc_info_type_int;
assign slv_aw.misc_info_snp          = slv_aw_s.misc_info[5];
assign slv_aw.misc_info_ep           = slv_aw_s.misc_info[6];
assign slv_aw.misc_info_ns           = slv_aw_s.misc_info[8];
assign slv_aw.misc_info_ro           = slv_aw_s.misc_info[9];
assign slv_aw.misc_info_tc           = slv_aw_s.misc_info[12:10];
assign slv_aw.misc_info_msg_code     = slv_aw_s.misc_info[20:13];
assign slv_aw.misc_info_db           = slv_aw_s.misc_info[21];
assign slv_aw.misc_info_func_num     = 3'h0;
assign slv_aw.misc_info_nw           = slv_aw_s.misc_info_s.nw;
assign slv_aw.misc_info_ats          = slv_aw_s.misc_info_s.ats;
assign slv_aw.misc_info_tlpprfx      = { slv_awmisc_info_tlpprfx_par, slv_aw_s.misc_info_s.tlpprfx};
assign slv_aw.misc_info_p_tag        = slv_aw_s.misc_info_s.p_tag;
assign slv_aw.misc_info_tph          = slv_aw_s.misc_info_s.tph;
assign slv_aw.misc_info_atu_bypass   = awmisc_info_atu_bypass_int;
assign slv_aw.misc_info_ido          = slv_aw_s.misc_info_s.ido;
assign slv_aw.misc_info_dst_segment  = slv_aw_s.misc_info_s.dst_segment;
assign slv_awready_s                 = slv_aw.ready;


assign slv_w.valid                   = slv_w_s.valid;
assign slv_w.data                    = slv_wdata_s;
assign slv_w.strb                    = slv_w_s.strb;
assign slv_w.last                    = slv_w_s.last;
assign slv_w.misc_info_ep            = slv_w_s.misc_info_s.ep;
assign slv_w.misc_info_silentDrop    = slv_w_s.misc_info_s.silentDrop;
assign slv_wready_s                  = slv_w.ready;


assign slv_r_s.valid                 = slv_r.valid;
assign slv_r_s.id                    = slv_r.id;
assign slv_r_s.misc_info[0]          = slv_r.timeout;
assign slv_r_s.misc_info[1]          = slv_r.ep;
assign slv_r_s.misc_info[4:2]        = slv_r.tc;
assign slv_r_s.misc_info[5]          = slv_r.ns;
assign slv_r_s.misc_info[6]          = slv_r.ro;
assign slv_r_s.misc_info[9:7]        = slv_r.status;
assign slv_r_s.misc_info[10]         = slv_r.cpl;
assign slv_r_s.misc_info_s.ido       = slv_r.ido;
assign slv_r_s.misc_info_s.cpl_segment = slv_r.cpl_segment;
assign slv_r_s.misc_info_s.dst_segment = slv_r.dst_segment;
assign slv_r_s.resp                  = slv_r.resp;
assign slv_rdata_s                   = slv_r.data;
assign slv_r_s.last                  = slv_r.last;
assign slv_r.ready                   = slv_rready_s;



assign slv_b_s.valid                 = slv_b.valid;
assign slv_b_s.id                    = slv_b.id;
assign slv_b_s.resp                  = slv_b.resp;
assign slv_b_s.misc_info[0]          = slv_b.timeout;
assign slv_b_s.misc_info[1]          = slv_b.ep;
assign slv_b_s.misc_info[4:2]        = slv_b.tc;
assign slv_b_s.misc_info[5]          = slv_b.ns;
assign slv_b_s.misc_info[6]          = slv_b.ro;
assign slv_b_s.misc_info[9:7]        = slv_b.status;
assign slv_b_s.misc_info[10]         = slv_b.cpl;
assign slv_b_s.misc_info_s.cpl_segment = slv_b.cpl_segment;
assign slv_b_s.misc_info_s.dst_segment = slv_b.dst_segment;
assign slv_b.ready                   = slv_bready_s;

  DWC_pcie_axi_slv_if
  

    u_slv_if (
      .slv_aclk                    ( slv_aclk_g                  )
     ,.slv_aclk_ug                 ( slv_aclk                    )
     ,.slv_aresetn                 ( slv_aresetn                 )
     ,.core_clk                    ( core_clk                    )
     ,.core_rst_n                  ( core_rst_n                  )

     ,.i_slv_ar                    ( slv_ar.slv_mp               )
     ,.i_slv_aw                    ( slv_aw.slv_mp               )
     ,.i_slv_w                     ( slv_w.slv_mp                )
     ,.i_slv_r                     ( slv_r.slv_mp                )
     ,.i_slv_b                     ( slv_b.slv_mp                )

     ,.o_slv_ar                    ( s_slv_ar.mstr_mp            )
     ,.o_slv_aw                    ( s_slv_aw.mstr_mp            )
     ,.o_slv_w                     ( s_slv_w.mstr_mp             )
     ,.o_slv_r                     ( s_slv_r.mstr_mp             )
     ,.o_slv_b                     ( s_slv_b.mstr_mp             )
   );


  DWC_pcie_axi_slv
  
  #(
    .SLV_BUS_ID_WIDTH               (`CC_SLV_BUS_ID_WIDTH       ),
    .SLV_BURST_LEN_PW               (`CC_SLV_INT_BURST_LEN_PW   ),
    .SLV_BUS_ADDR_WIDTH             (`CC_SLV_BUS_ADDR_WIDTH     ),
    .SLAVE_BUS_ADDR_WIDTH           (`SLAVE_BUS_ADDR_WIDTH      ),
    .SLV_BUS_DATA_WIDTH             (`CC_SLV_BUS_DATA_WIDTH     ),
    .SLV_BUS_NPDATA_WIDTH           (`CC_SLV_BUS_NPDATA_WIDTH   ),
    .SLV_BUS_NPDATA_WIDTH_NP        (`CC_SLV_BUS_NPDATA_WIDTH_NP),
    .SLV_BUS_WREQ_NPDATA_WIDTH      (`CC_SLV_BUS_WREQ_NPDATA_WIDTH),
    .SLV_BUS_WREQ_NPDATA_WIDTH_NP   (`CC_SLV_BUS_WREQ_NPDATA_WIDTH_NP),
    .SLV_BUS_WSTRB_WIDTH            (`CC_SLV_BUS_WSTRB_WIDTH    ),
    .SLV_BUS_NPWSTRB_WIDTH          (`CC_SLV_BUS_NPWSTRB_WIDTH  ),
    .SLV_BUS_WREQ_NPWSTRB_WIDTH     (`CC_SLV_BUS_WREQ_NPWSTRB_WIDTH),
    .SLV_BUS_WSTRB_PW               (`CC_SLV_BUS_WSTRB_PW       ),
    .SLV_MISC_INFO_WD               (`SLV_MISC_INFO_WD          ),
    .NFUNC_WD                       (`CX_NFUNC_WD               ),
    .TX_TLP_PREFIX_WD               (TX_TLP_PREFIX_WD           ),
    .MISC_INFO_TPH_WD               (MISC_INFO_TPH_WD           ),
    .ATU_OUT_REGIONS                (`CX_ATU_NUM_OUTBOUND_REGIONS),
    .ATU_BASE_WD                    (`CX_ATU_BASE_WIDTH         ),
    .ATU_REG_WD                     (`CX_ATU_REGION_WIDTH       ),
    .ATU_UPR_LMT_WD                 (`CX_ATU_MAX_REGION_SIZE    ),
    .ATU_OUT_MIN1                   (ATU_OUT_NREGIONS_MIN1      ),
    .MAX_SLV_TAG                    (`CC_MAX_SLV_TAG            ),
    .MAX_SLV_TAG_PW                 (`CC_MAX_SLV_TAG_PW         ),
    .SLV_NUM_OUTSTND_WR_REQ         (`CC_SLV_NUM_OUTSTND_WR_REQ ),
    .SLV_NUM_OUTSTND_WR_REQ_LOG2    (`CC_SLV_NUM_OUTSTND_WR_REQ_LOG2),
    .DBI_SLV_BUS_ADDR_WIDTH         (`CC_DBI_SLV_BUS_ADDR_WIDTH ),
    .SLV_NPW_SAB_RAM_DATA_WD        (`CC_SLV_NPW_SAB_RAM_DATA_WD),
    .SLV_NPW_SAB_RAM_DATA_WD_NOECC  (`CC_SLV_NPW_SAB_RAM_DATA_WD_NOECC),
    .SLV_NPW_SAB_RAM_DP             (`CC_SLV_NPW_SAB_RAM_DP     ),
    .SLV_NPW_SAB_RAM_ADDR_WD        (`CC_SLV_NPW_SAB_RAM_ADDR_WD),
    .SLV_WRP_RSP_ROB_FIFO_DP         (`CC_SLV_WRP_RSP_ROB_FIFO_DP),
    .SLV_WRP_RSP_ROB_FIFO_ADDR_WD    (`CC_SLV_WRP_RSP_ROB_FIFO_ADDR_WD),
    .AXI_LOCK_WIDTH                 (`CC_AXI_LOCK_WIDTH           )
    )
    u_sif
    (
`ifndef UTB_NATIVE_AXI
     .slv_aclk                     (slv_aclk_g                                    )
    ,.slv_aclk_ug                  (slv_aclk                                      )
    ,.slv_aresetn                  (slv_aresetn                                   )
    // -------------------------------------------------------------------------
    // Error response configuration interface
    ,.cfg_err_resp_mode            (cfg_err_resp_mode_a2s                         )
    ,.cfg_err_resp_map             (cfg_slv_resp_err_map_a2s                      )
    ,.cfg_dmwr_req_en              (qslv_d.cfg_dmwr_req_en                        )
    // ------------------------------------------------------------------------
    // Enhanced Configuration Access Mechanism (ECAM)
    // -------------------------------------------------------------------------
    // Flush request
    ,.flshctl_sif_flush_req        (flshctl_sif_flush_req                         )
    ,.sif_flush_ack                (sif_flush_ack                                 )
    // -------------------------------------------------------------------------
    // ATU control interface
    ,.atu_reg_out_upr_base         (qslv_d.atu_reg_out_upr_base                   )
    ,.atu_reg_out_en               (qslv_d.atu_reg_out_en                         )
    ,.atu_reg_out_type             (qslv_d.atu_reg_out_type                       )
    ,.atu_reg_out_base             (qslv_d.atu_reg_out_base                       )
    ,.atu_reg_out_limit            (qslv_d.atu_reg_out_limit                      )
    ,.atu_reg_out_uppr_limit       (qslv_d.atu_reg_out_uppr_limit                 )
    ,.atu_reg_out_incr_rgn_size    (qslv_d.atu_reg_out_incr_rgn_size              )
    ,.atu_reg_out_invert           (qslv_d.atu_reg_out_invert                     )
    ,.atu_reg_out_func_num         (qslv_d.atu_reg_out_func_num                   )
    ,.atu_reg_out_func_bypass      (qslv_d.atu_reg_out_func_bypass                )
    ,.atu_reg_out_snp              (qslv_d.atu_reg_out_snp                        )

    ,.axi_ras_par_rslv_dt_pulse    (sif_ras_par_rslv_dt_pulse                     )
    ,.axi_srsp_rslv_dt_ras_dp_err_log (sif_srsp_rslv_dt_ras_dp_err_log            )
    // -------------------------------------------------------------------------
    // AXI Interfaces
    ,.slv_ar                       (s_slv_ar.slv_mp                               )
    ,.slv_r                        (s_slv_r.slv_mp                                )
    ,.slv_aw                       (s_slv_aw.slv_mp                               )
    ,.slv_w                        (s_slv_w.slv_mp                                )
    ,.slv_b                        (s_slv_b.slv_mp                                )
    // -------------------------------------------------------------------------
    // Client Non-Posted Request Interface
    ,.sif_np_rd                    (sif_np_rd                                     )
    ,.sif_np_wr                    (sif_np_wr                                     )
    ,.sif_np_atomic                (sif_np_atomic                                 )
    ,.sif_np_dmwr                  (sif_np_dmwr                                   )
    ,.sif_np_first_wrp_split_xact  (sif_np_first_wrp_split_xact                   )
    ,.sif_np_wrp_valid             (sif_np_wrp_valid                              )
    ,.sif_np_tag                   (sif_np_tag                                    )
    ,.sif_np_addr                  (sif_np_addr                                   )
    ,.sif_np_id                    (sif_np_id                                     )
    ,.sif_np_len                   (sif_np_len                                    )
    ,.sif_np_size                  (sif_np_size                                   )
    ,.sif_np_burst                 (sif_np_burst                                  )
    ,.sif_np_last                  (sif_np_last                                   )
    ,.sif_np_strb                  (sif_np_strb                                   )
    ,.sif_np_data                  (sif_np_data                                   )
    ,.sif_np_type                  (sif_np_type                                   )
    ,.sif_np_snp                   (sif_np_snp                                    )
    ,.sif_np_ns                    (sif_np_ns                                     )
    ,.sif_np_ro                    (sif_np_ro                                     )
    ,.sif_np_tc                    (sif_np_tc                                     )
    ,.sif_np_ep                    (sif_np_ep                                     )
    ,.sif_np_func_num              (sif_np_func_num                               )
    ,.sif_np_nw                    (sif_np_nw                                     )
    ,.sif_np_ats                   (sif_np_ats                                    )
    ,.sif_np_tlpprfx               (sif_np_tlpprfx                                )
    ,.sif_np_tph                   (sif_np_tph                                    )
    ,.sif_np_atu_bypass            (sif_np_atu_bypass                             )
    ,.sif_np_ido                   (sif_np_ido                                    )
    ,.sif_np_dst_segment           (sif_np_dst_segment                            )
    ,.sif_np_cpl_stat              (sif_np_cpl_stat                               )
    ,.nprf_ready                   (nprf_ready                                    )
    // -------------------------------------------------------------------------
    // Data Bus Non-Posted Request Interface
    ,.sif_db_rd                    (sif_db_rd                                     )
    ,.sif_db_wr                    (sif_db_wr                                     )
    ,.sif_db_vldrq                 (sif_db_vldrq                                  )
    ,.sif_db_tag                   (sif_db_tag                                    )
    ,.sif_db_addr                  (sif_db_addr                                   )
    ,.sif_db_strb                  (sif_db_strb                                   )
    ,.sif_db_len                   (sif_db_len                                    )
    ,.sif_db_data                  (sif_db_data                                   )
    ,.dbi_ready                    (dbi_ready                                     )
    // -------------------------------------------------------------------------
    // Slave Completion Interface
    ,.nprspf_valid                 (nprspf_valid                                  )
    ,.nprspf_last                  (nprspf_last                                   )
    ,.nprspf_data                  (nprspf_data                                   )
    ,.nprspf_tag                   (nprspf_tag                                    )
    ,.nprspf_to                    (nprspf_to                                     )
    ,.nprspf_ido                   (nprspf_ido                                    )
    ,.nprspf_ro                    (nprspf_ro                                     )
    ,.nprspf_ns                    (nprspf_ns                                     )
    ,.nprspf_tc                    (nprspf_tc                                     )
    ,.nprspf_cpl                   (1'b1                                          )
    ,.nprspf_status                (nprspf_status                                 )
    ,.nprspf_ep                    (nprspf_ep                                     )
    ,.nprspf_cpl_segment           (nprspf_cpl_segment                            )
    ,.nprspf_dst_segment           (nprspf_dst_segment                            )
    ,.nprspf_resp                  ( 2'h0 )
    ,.sif_np_ready                 (sif_np_ready                                  )
    // -------------------------------------------------------------------------
    // Data bus  Non-Posted Response Interface
    ,.dbi_valid                    (dbi_valid                                     )
    ,.dbi_last                     (dbi_last                                      )
    ,.dbi_tag                      (dbi_tag                                       )
    ,.dbi_resp                     (dbi_resp[(`RESP_ERRBUS_WD)-1:1])
    ,.dbi_data                     (dbi_data                                      )
    ,.sif_db_ready                 (sif_db_ready                                  )
    // --------------------------  -----------------------------------------------
    // Posted Request Interface
    ,.sif_p_valid                  (sif_p_valid                                   )
    ,.sif_p_id                     (sif_p_id                                      )
    ,.sif_p_addr                   (sif_p_addr                                    )
    ,.sif_p_size                   (sif_p_size                                    )
    ,.sif_p_len                    (sif_p_len                                     )
    ,.sif_p_last                   (sif_p_last                                    )
    ,.sif_p_strb                   (sif_p_strb                                    )
    ,.sif_p_ep_strb                (sif_p_ep_strb                                 )
    ,.sif_p_silentDrop_strb        (sif_p_silentDrop_strb                         )
    ,.sif_p_silentDrop_strb_masked (sif_p_silentDrop_strb_masked                  )
    ,.sif_p_data                   (sif_p_data                                    )
    ,.sif_p_msg_code               (sif_p_msg_code                                )
    ,.sif_p_type                   (sif_p_type                                    )
    ,.sif_p_tc                     (sif_p_tc                                      )
    ,.sif_p_ep                     (sif_p_ep                                      )
    ,.sif_p_ro                     (sif_p_ro                                      )
    ,.sif_p_ns                     (sif_p_ns                                      )
    ,.sif_p_first_wrp_split_xact   (sif_p_first_wrp_split_xact                    )
    ,.sif_p_wrp_valid              (sif_p_wrp_valid                               )
    ,.sif_p_nw                     (sif_p_nw                                      )
    ,.sif_p_ats                    (sif_p_ats                                     )
    ,.sif_p_func_num               (sif_p_func_num                                )
    ,.sif_p_tph                    (sif_p_tph                                     )
    ,.sif_p_tlpprfx                (sif_p_tlpprfx                                 )
    ,.sif_p_tag                    (sif_p_tag                                     )
    ,.sif_p_atu_bypass             (sif_p_atu_bypass                              )
     ,.sif_p_ido                   (sif_p_ido                                     )
     ,.sif_p_dst_segment           (sif_p_dst_segment                             )
     ,.sif_p_cpl_stat              (sif_p_cpl_stat                                )
    ,.prf_ready                    (prf_p_ready                                   )
    // -------------------------------------------------------------------------
    // Posted Response Interface
    ,.pdcmp_p_rsp_valid_hl         (mstream_p_rsp_valid                           )
    ,.pdcmp_p_rsp_id               (mstream_p_rsp_id                              )
    ,.pdcmp_p_rsp_cpl_stat         (mstream_p_rsp_cpl_stat                        )

    // -------------------------------------------------------------------------
    // Non Posted Atomic Response Interface
    ,.npdcmp_np_atomic_rsp_valid_hl (npdcmp_np_atomic_rsp_valid                   )
    ,.npdcmp_np_atomic_rsp_id      (npdcmp_np_atomic_rsp_id                       )
    // -------------------------------------------------------------------------
    // Low power interface
    ,.csysreq                      (slv_csysreq                                   )
    ,.sif_csysack                  (slv_csysack                                   )
    ,.sif_cactive                  (slv_cactive                                   )
    // -------------------------------------------------------------------------
    // Parity Error Interface
    ,.sif_addr_parerr              (sif_ras_par_slnull_ad_pulse                  )
    ,.sif_data_parerr              (sif_ras_par_slnull_dt_pulse                  )
    ,.ras_dp_err_inj_slv_aclk      (ras_dp_err_inj_slv_aclk)
    ,.sif_swrq_dt_ras_dp_err_log   (sif_swrq_dt_ras_dp_err_log                   )
    ,.sif_swrq_ad_ras_dp_err_log   (sif_swrq_ad_ras_dp_err_log                   )
    ,.sif_ras_par_swwrap_ad_pulse  (sif_ras_par_swwrap_ad_pulse                  )
    ,.sif_ras_par_swwrap_dt_pulse  (sif_ras_par_swwrap_dt_pulse                  )
    ,.sif_swrq_swwrap_dt_ras_dp_err_log (sif_swrq_swwrap_dt_ras_dp_err_log       )
    ,.sif_swrq_swwrap_ad_ras_dp_err_log (sif_swrq_swwrap_ad_ras_dp_err_log       )
    ,.sif_srrp_srwrap_ad_ras_dp_err_log (sif_srrp_srwrap_ad_ras_dp_err_log       )
    // -------------------------------------------------------------------------
    // Slave Non-Posted Write Set-Aside RAM
    ,.sif_npw_sab_ram_addra        (slv_npw_sab_ram_addra                         )
    ,.sif_npw_sab_ram_wea          (slv_npw_sab_ram_wea                           )
    ,.sif_npw_sab_ram_dina         (slv_npw_sab_ram_dina                          )
    ,.sif_npw_sab_ram_addrb        (slv_npw_sab_ram_addrb                         )
    ,.sif_npw_sab_ram_enb          (slv_npw_sab_ram_enb                           )
    ,.sif_npw_sab_ram_doutb        (slv_npw_sab_ram_doutb                         )
    ,.cfg_ras_recc_npw_sab_correct        (qslv_d.cfg_ras_recc_npw_sab_correct    )
    ,.sif_ras_recc_corr_cnt_npw_sab_pulse (sif_ras_recc_corr_cnt_npw_sab_pulse  )
    ,.sif_ras_recc_ucorr_cnt_npw_sab_pulse(sif_ras_recc_ucorr_cnt_npw_sab_pulse )
    ,.sif_ras_recc_cnt_npw_sab_addr       (sif_ras_recc_cnt_npw_sab_addr        ) //This generates the correctable and uncorrectable version
    ,.sif_ras_par_srwrap_ad_pulse  (sif_ras_par_srwrap_ad_pulse                 )
    ,.sif_ras_par_swrq_npw_dt_pulse(sif_ras_par_swrq_npw_dt_pulse               )
    ,.sif_ras_par_swrq_npw_ad_pulse(sif_ras_par_swrq_npw_ad_pulse               )
    ,.sif_recc_npw_sab_ras_dp_err_log(sif_recc_npw_sab_ras_dp_err_log           )
    ,.sif_swrq_npw_dt_ras_dp_err_log (sif_swrq_npw_dt_ras_dp_err_log            )
    ,.sif_swrq_npw_ad_ras_dp_err_log (sif_swrq_npw_ad_ras_dp_err_log            )

    // -------------------------------------------------------------------------
    // Power Down Interface
    // -------------------------------------------------------------------------
    // Activity Tracking Interface
    ,.sif_xfer_pending           (sif_xfer_pending)
    ,.sif_xfer_pending_db        (sif_xfer_pending_db)
    // Completions Status during DPC
    ,.cdc_core_in_dpc_i                 (cdc_core_in_dpc      )
    ,.qst_cfg_dpc_cpl_cntrl_i           (qst_cfg_dpc_cpl_cntrl)

`endif // !UTB_NATIVE_AXI
    );




  // ---------------------------------------------------------------------------
  // Instantiate Outbound
  // ---------------------------------------------------------------------------
`ifndef SYNTHESIS
`endif // SYNTHESIS


// Temporary signal assignment to drive new inputs while wiring is not cnomplete
assign inbd_header_cpl_pass_p = inbd_header_cpl[`INBD_HDR_CPL_RANGE_ATTR_LOW+1] || cfg_ax_ib_cpl_pass_p[0];

reg [(3*`CX_NFUNC)-1:0] r_cfg_max_payload_size;
reg [(3*`CX_NFUNC)-1:0] r_cfg_max_rd_req_size;
always@(posedge slv_aclk_g or negedge slv_aresetn)begin: SEQ_R_CDM_OUT_REG_SLV_ACLK_PROC
  if(!slv_aresetn)begin
    r_cfg_max_payload_size <= #`TP '0;
    r_cfg_max_rd_req_size  <= #`TP '0;
  end else begin
    r_cfg_max_payload_size <= #`TP qslv_d.cfg_max_payload_size;
    r_cfg_max_rd_req_size  <= #`TP qslv_d.cfg_max_rd_req_size;
  end
end



  DWC_pcie_axi_ob
  
  #(
    .SLV_BUS_ADDR_WIDTH                  (`CC_SLV_BUS_ADDR_WIDTH     ),
    .SLAVE_BUS_ADDR_WIDTH                (`SLAVE_BUS_ADDR_WIDTH      ),
    .ADDR_PAR_WD                         (`CX_ADDR_PAR_WD            ),
    .SLV_BUS_DATA_WIDTH                  (`CC_SLV_BUS_DATA_WIDTH     ),
    .SLV_BUS_NPDATA_WIDTH                (`CC_SLV_BUS_NPDATA_WIDTH   ),
    .SLV_BUS_ID_WIDTH                    (`CC_SLV_BUS_ID_WIDTH       ),
    .SLV_MAX_RD_SIZE_PW                  (`CC_SLV_RD_REQ_SIZE_PW     ),
    .SLV_BURST_LEN_PW                    (`CC_SLV_INT_BURST_LEN_PW   ),
    .SLV_BUS_WSTRB_WIDTH                 (`CC_SLV_BUS_WSTRB_WIDTH    ),
    .SLV_MTU_PW                          (`CC_SLV_MTU_PW             ),
    .SLV_CONV_FAC_WIDTH                  (`CC_SLV_CONV_FAC_WIDTH     ),
    .SLV_MISC_INFO_WD                    (`SLV_MISC_INFO_WD          ),
    .SLV_NUM_OUTSTD_WR_RESP              (`CC_SLV_NUM_OUTSTND_WR_REQ ),
    .SLV_NUM_OUTSTD_WR_RESP_LOG2         (`CC_SLV_NUM_OUTSTND_WR_REQ_LOG2),
    .NFUNC                               (`CX_NFUNC                  ),
    .NFUNC_WD                            (`CX_NFUNC_WD               ),
    .PF_WD_MIN3                          (PF_WD_MIN3                 ),
    .MISC_INFO_TPH_WD                    (MISC_INFO_TPH_WD           ),
    .TX_TLP_PREFIX_WD                    (TX_TLP_PREFIX_WD           ),
    .MAX_SLV_TAG_PW                      (`CC_MAX_SLV_TAG_PW         ),
    .MAX_WIRE_TAG                        (MAX_WIRE_TAG               ),
    .MAX_WIRE_TAG_PW                     (MAX_WIRE_TAG_PW            ),
    .CORE_ADDR_BUS_WD                    (`CC_CORE_ADDR_BUS_WD       ),
    .FLT_Q_ATTR_WIDTH                    (`FLT_Q_ATTR_WIDTH          ),
    .CORE_DATA_BUS_WD                    (`CC_CORE_DATA_BUS_WD       ),
    .DC_INBD_HEADER_CPL_WD               (`DC_INBD_HEADER_CPL_WD     ),
    .NW                                  (`CX_NW                     ),
    .NPRSPF_TLP_DATA_WIDTH               (`CC_NPRSPF_TLP_DATA_WIDTH  ),
    .NPRSPF_TLP_DATA_WIDTH_NP            (`CC_NPRSPF_TLP_DATA_WIDTH_NP),
    .NPRSPF_TLP_NUM_DWORDS               (`CC_NPRSPF_TLP_NUM_DWORDS  ),
    .NPRSPF_TLP_NUM_STRBS                (`CC_NPRSPF_TLP_NUM_STRBS   ),
    .CX_RAS_RAM_PROT_RANGE               (`CX_RAS_RAM_PROT_RANGE     ),
    .COMPOSER_HDR_WD                     (`CC_RADMX_COMPOSER_HDR_WD  ),
    .CC_OB_CCMP_DATA_RAM_DATA_WD         (`CC_OB_CCMP_DATA_RAM_DATA_WD),
    .CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC   (`CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC ),
    .CC_OB_CCMP_DATA_RAM_ADDR_WD         (`CC_OB_CCMP_DATA_RAM_ADDR_WD ),
    .PRF_TLP_DATA_WIDTH                  (`CC_PRF_TLP_DATA_WIDTH     ),
    .PRF_TLP_NUM_WSTRBS                  (`CC_PRF_TLP_NUM_WSTRBS     ),
    .PRF_TLP_NUM_WSTRBS_GT_4             (`CC_PRF_TLP_NUM_WSTRBS_GT_4),
    .PRF_TLP_NUM_DWORDS                  (`CC_PRF_TLP_NUM_DWORDS     ),
    .PRF_HDRQ_WD                         (`CC_PRF_HDRQ_WD            ),
    .OB_NPDCMP_RAM_DP                    (`CC_OB_NPDCMP_RAM_DP       ),
    .OB_NPDCMP_RAM_DATA_WD               (`CC_OB_NPDCMP_RAM_DATA_WD  ),
    .OB_NPDCMP_RAM_ADDR_WD               (`CC_OB_NPDCMP_RAM_ADDR_WD  ),
    .OB_NPDCMP_RAM_PTR_WD                (`CC_OB_NPDCMP_RAM_PTR_WD   ),
    .OB_PDCMP_HDR_RAM_DP                 (`CC_OB_PDCMP_HDR_RAM_DP    ),
    .OB_PDCMP_HDR_RAM_DATA_WD            (`CC_OB_PDCMP_HDR_RAM_DATA_WD),
    .OB_PDCMP_HDR_RAM_ADDR_WD            (`CC_OB_PDCMP_HDR_RAM_ADDR_WD),
    .OB_PDCMP_HDR_RAM_PTR_WD             (`CC_OB_PDCMP_HDR_RAM_PTR_WD),
    .OB_PDCMP_DATA_RAM_DP                (`CC_OB_PDCMP_DATA_RAM_DP   ),
    .OB_PDCMP_DATA_RAM_DATA_WD           (`CC_OB_PDCMP_DATA_RAM_DATA_WD),
    .OB_PDCMP_DATA_RAM_ADDR_WD           (`CC_OB_PDCMP_DATA_RAM_ADDR_WD),
    .OB_PDCMP_DATA_RAM_PTR_WD            (`CC_OB_PDCMP_DATA_RAM_PTR_WD),
    .SYNC_DEPTH                          (`CX_PCIE_SYNC_DEPTH        )
    )
    u_ob
    (

`ifndef UTB_NATIVE_AXI
     .slv_aclk                     (slv_aclk_g                  )
    ,.slv_aresetn                  (slv_aresetn                 )
    ,.core_clk                     (core_clk                    )
    ,.aux_clk_g                    (aux_clk_g                   )
    ,.core_rst_n                   (core_rst_n                  )
    // -------------------------------------------------------------------------
    // Configuration
    ,.cfg_ext_tag_en               (cfg_ext_tag_en_c2s               )
    ,.cfg_10b_tag_en               (cfg_10b_tag_en_c2s               )
    ,.cfg_10b_tag_en_cclk          (r_cfg_10b_tag_en                 )
    ,.cfg_max_rd_req_size          (r_cfg_max_rd_req_size            )
    ,.cfg_max_payload_size         (r_cfg_max_payload_size           )
    ,.cfg_ax_snp_en                (cfg_ax_snp_en               )
    ,.cfg_tc_struc_vc_map          (cfg_tc_struc_vc_map              )
    ,.cfg_ras_recc_ob_ccmp_data_correct        (qslv_d.cfg_ras_recc_ob_ccmp_data_correct)
    ,.axi_ras_recc_corr_cnt_ob_ccmp_data_pulse (ob_ras_recc_corr_cnt_ob_ccmp_data_pulse)
    ,.axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse   (ob_ras_recc_ucorr_cnt_ob_ccmp_data_pulse)
    ,.axi_ras_recc_cnt_ob_ccmp_data_addr       (ob_ras_recc_cnt_ob_ccmp_data_addr)      //This generates the correctable and uncorrectable version
    ,.axi_ras_par_ob_cpl_comp_dt_pulse         (axi_ras_par_ob_cpl_comp_dt_pulse_g)
    ,.ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log     (axi_ob_recc_cnt_ob_ccmp_dt_ras_dp_log)
    ,.ob_cpl_comp_dt_ras_dp_err_log              (axi_ob_cpl_comp_dt_ras_dp_err_log_g)
    ,.cfg_ras_recc_ob_npdcmp_correct             (cfg_ras_recc_ob_npdcmp_correct        )
    ,.axi_ras_recc_corr_cnt_ob_npdcmp_pulse      (ob_ras_recc_corr_cnt_ob_npdcmp_pulse )
    ,.axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse     (ob_ras_recc_ucorr_cnt_ob_npdcmp_pulse)
    ,.axi_ras_recc_cnt_ob_npdcmp_addr            (ob_ras_recc_cnt_ob_npdcmp_addr       ) //This generates the correctable and uncorrectable version
    ,.axi_recc_cnt_ob_npdcmp_ras_dp_err_log      (ob_recc_cnt_ob_npdcmp_ras_dp_err_log )

    ,.cfg_ras_recc_ob_pdcmp_hdr_correct          (cfg_ras_recc_ob_pdcmp_hdr_correct        )
    ,.axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse   (ob_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse )
    ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse  (ob_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse)
    ,.axi_ras_recc_cnt_ob_pdcmp_hdr_addr         (ob_ras_recc_cnt_ob_pdcmp_hdr_addr       ) //This generates the correctable and uncorrectable version

    ,.cfg_ras_recc_ob_pdcmp_data_correct         (cfg_ras_recc_ob_pdcmp_data_correct       )
    ,.axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse  (ob_ras_recc_corr_cnt_ob_pdcmp_data_pulse )
    ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse (ob_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse)
    ,.axi_ras_recc_cnt_ob_pdcmp_data_addr        (ob_ras_recc_cnt_ob_pdcmp_data_addr       )  //This generates the correctable and uncorrectable version
      ,.axi_recc_cnt_ob_pdcmp_ras_dp_err_log     (ob_recc_cnt_ob_pdcmp_ras_dp_err_log      )
      ,.axi_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log (ob_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log  )
    // -------------------------------------------------------------------------
    // Slave Non-Posted Request interface
    ,.sif_np_rd                    (sif_np_rd                   )
    ,.sif_np_wr                    (sif_np_wr                   )
    ,.sif_np_atomic                (sif_np_atomic               )
    ,.sif_np_dmwr                  (sif_np_dmwr                 )
    ,.sif_np_first_wrp_split_xact  (sif_np_first_wrp_split_xact )
    ,.sif_np_wrp_valid             (sif_np_wrp_valid            )
    ,.sif_np_tag                   (sif_np_tag                  )
    ,.sif_np_addr                  (sif_np_addr                 )
    ,.sif_np_id                    (sif_np_id                   )
    ,.sif_np_len                   (sif_np_len                  )
    ,.sif_np_size                  (sif_np_size                 )
    ,.sif_np_burst                 (sif_np_burst                )
    ,.sif_np_strb                  (sif_np_strb                 )
    ,.sif_np_data                  (sif_np_data                 )
    ,.sif_np_type                  (sif_np_type                 )
    ,.sif_np_snp                   (sif_np_snp                  )
    ,.sif_np_ns                    (sif_np_ns                   )
    ,.sif_np_ro                    (sif_np_ro                   )
    ,.sif_np_tc                    (sif_np_tc                   )
    ,.sif_np_ep                    (sif_np_ep                   )
    ,.sif_np_func_num              (sif_np_func_num             )
    ,.sif_np_nw                    (sif_np_nw                   )
    ,.sif_np_ats                   (sif_np_ats                  )
    ,.sif_np_tlpprfx               (sif_np_tlpprfx              )
    ,.sif_np_tph                   (sif_np_tph                  )
    ,.sif_np_atu_bypass            (sif_np_atu_bypass           )
    ,.sif_np_ido                   (sif_np_ido                  )
    ,.sif_np_dst_segment           (sif_np_dst_segment          )
    ,.sif_np_cpl_stat              (sif_np_cpl_stat             )
    ,.nprf_ready                   (nprf_ready                  )
    // -------------------------------------------------------------------------------------
    // TLP Non-Posted Interface
    ,.client1_tlp_hv               (s_client1_tlp_hv              )
    ,.client1_tlp_dv               (s_client1_tlp_dv              )
    ,.client1_tlp_eot              (s_client1_tlp_eot             )
    ,.client1_tlp_byte_en          (s_client1_tlp_byte_en         )
    ,.client1_tlp_fmt              (s_client1_tlp_fmt             )
    ,.client1_tlp_type             (s_client1_tlp_type            )
    ,.client1_tlp_tc               (s_client1_tlp_tc              )
    ,.client1_tlp_ep               (s_client1_tlp_ep              )
    ,.client1_tlp_attr             (s_client1_tlp_attr            )
    ,.client1_tlp_byte_len         (s_client1_tlp_byte_len        )
    ,.client1_tlp_tid              (s_client1_tlp_tid             )
    ,.client1_tlp_addr             (s_client1_tlp_addr            )
    ,.client1_tlp_data             (s_client1_tlp_data            )
    ,.client1_tlp_func_num         (s_client1_tlp_func_num        )
    ,.client1_tlp_nw               (s_client1_tlp_nw              )
    ,.client1_tlp_ats              (s_client1_tlp_ats             )
    ,.client1_tlp_th               (s_client1_tlp_th              )
    ,.client1_tlp_ph               (s_client1_tlp_ph              )
    ,.client1_tlp_st               (s_client1_tlp_st              )
    ,.client1_tlp_prfx             (s_client1_tlp_prfx            )
    ,.client1_tlp_atu_bypass       (s_client1_tlp_atu_bypass      )
    ,.client1_tlp_dst_segment      (s_client1_tlp_dst_segment     )
    ,.xadm_client1_halt            (s_xadm_client1_halt           )

  // ---------------------------------------------------------------------------
  // Inbound Router interface
    ,.ibrtr_inbd_header_cpl        (inbd_header_cpl             )
    ,.ibrtr_inbd_header_cpl_pseq   (inbd_header_cpl_pseq        )
    ,.ibrtr_inbd_header_cpl_pass_p (inbd_header_cpl_pass_p      )
    ,.ibrtr_inbd_data_cpl          (inbd_data_cpl               )
    ,.trgt1_p_xfer_pend_per_vc     (trgt1_p_xfer_pend_per_vc    )
    // -------------------------------------------------------------------------
    // Completion Timeout Interface
    ,.radm_cpl_timeout             (radm_cpl_timeout            )
    ,.radm_timeout_cpl_tc          (radm_timeout_cpl_tc         )
    ,.radm_timeout_cpl_attr        (radm_timeout_cpl_attr       )
    ,.radm_timeout_cpl_tag         (radm_timeout_cpl_tag        )
    ,.radm_timeout_func_num        (radm_timeout_func_num       )
    // -------------------------------------------------------------------------
    // Slave Completion Interface
    ,.nprspf_valid                 (nprspf_valid                )
    ,.nprspf_last                  (nprspf_last                 )
    ,.nprspf_data                  (nprspf_data                 )
    ,.nprspf_tag                   (nprspf_tag                  )
    ,.nprspf_to                    (nprspf_to                   )
    ,.nprspf_ido                   (nprspf_ido                  )
    ,.nprspf_ro                    (nprspf_ro                   )
    ,.nprspf_ns                    (nprspf_ns                   )
    ,.nprspf_tc                    (nprspf_tc                   )
    ,.nprspf_func_num              (nprspf_func_num             )
    ,.nprspf_status                (nprspf_status               )
    ,.nprspf_ep                    (nprspf_ep                   )
    ,.nprspf_cpl_segment           (nprspf_cpl_segment          )
    ,.nprspf_dst_segment           (nprspf_dst_segment          )
    ,.sif_np_ready                 (sif_np_ready                )
    // -------------------------------------------------------------------------
    // Slave Posted Interface
    ,.sif_p_valid                  (sif_p_valid                 )
    ,.sif_p_addr                   (sif_p_addr                  )
    ,.sif_p_id                     (sif_p_id                    )
    ,.sif_p_size                   (sif_p_size                  )
    ,.sif_p_len                    (sif_p_len                   )
    ,.sif_p_last                   (sif_p_last                  )
    ,.sif_p_strb                   (sif_p_strb                  )
    ,.sif_p_ep_strb                (sif_p_ep_strb               )
    ,.sif_p_silentDrop_strb        (sif_p_silentDrop_strb       )
    ,.sif_p_silentDrop_strb_masked (sif_p_silentDrop_strb_masked)
    ,.sif_p_data                   (sif_p_data                  )
    ,.sif_p_msg_code               (sif_p_msg_code              )
    ,.sif_p_type                   (sif_p_type                  )
    ,.sif_p_tc                     (sif_p_tc                    )
    ,.sif_p_ep                     (sif_p_ep                    )
    ,.sif_p_ro                     (sif_p_ro                    )
    ,.sif_p_ns                     (sif_p_ns                    )
    ,.sif_p_first_wrp_split_xact   (sif_p_first_wrp_split_xact  )
    ,.sif_p_wrp_valid              (sif_p_wrp_valid             )
    ,.sif_p_nw                     (sif_p_nw                    )
    ,.sif_p_ats                    (sif_p_ats                   )
    ,.sif_p_func_num               (sif_p_func_num              )
    ,.sif_p_tph                    (sif_p_tph                   )
    ,.sif_p_prfx                   (sif_p_tlpprfx               )
    ,.sif_p_tag                    (sif_p_tag                   )
    ,.sif_p_atu_bypass             (sif_p_atu_bypass            )
    ,.sif_p_ido                    (sif_p_ido                   )
    ,.sif_p_dst_segment            (sif_p_dst_segment           )
    ,.sif_p_cpl_stat               (sif_p_cpl_stat              )
    ,.prf_p_ready                  (prf_p_ready                 )
    // -------------------------------------------------------------------------
    // TLP Posted Interface
    ,.client2_tlp_hv               (s_client2_tlp_hv            )
    ,.client2_tlp_dv               (s_client2_tlp_dv            )
    ,.client2_tlp_eot              (s_client2_tlp_eot           )
    ,.client2_tlp_byte_en          (s_client2_tlp_byte_en         )
    ,.client2_tlp_fmt              (s_client2_tlp_fmt             )
    ,.client2_tlp_type             (s_client2_tlp_type            )
    ,.client2_tlp_tc               (s_client2_tlp_tc              )
    ,.client2_tlp_ep               (s_client2_tlp_ep              )
    ,.client2_tlp_silentDrop       (s_client2_tlp_silentDrop      )
    ,.client2_tlp_attr             (s_client2_tlp_attr            )
    ,.client2_tlp_byte_len         (s_client2_tlp_byte_len        )
    ,.client2_tlp_addr             (s_client2_tlp_addr            )
    ,.client2_tlp_data             (s_client2_tlp_data            )
    ,.client2_tlp_func_num         (s_client2_tlp_func_num        )
    ,.client2_tlp_ats              (s_client2_tlp_ats             )
    ,.client2_tlp_nw               (s_client2_tlp_nw              )
    ,.client2_tlp_prfx             (s_client2_tlp_prfx            )
    ,.client2_p_tag                (s_client2_tlp_tid             )
    ,.client2_tlp_th               (s_client2_tlp_th              )
    ,.client2_tlp_ph               (s_client2_tlp_ph              )
    ,.client2_tlp_st               (s_client2_tlp_st              )
    ,.client2_tlp_atu_bypass       (s_client2_tlp_atu_bypass      )
    ,.client2_tlp_dst_segment      (s_client2_tlp_dst_segment     )
    ,.xadm_client2_halt            (s_xadm_client2_halt         )
    // -------------------------------------------------------------------------
    // Posted Response Interface
    ,.pdcmp_p_rsp_valid            (pdcmp_p_rsp_valid           )
    ,.pdcmp_p_rsp_id               (pdcmp_p_rsp_id              )
    ,.pdcmp_p_rsp_cpl_stat         (pdcmp_p_rsp_cpl_stat        )
    ,.pdcmp_p_rsp_null_or_err      (pdcmp_p_rsp_null_or_err     )
    ,.pdcmp_p_rsp_last             (pdcmp_p_rsp_last            )
    ,.pdcmp_p_rsp_vc_num           (pdcmp_p_rsp_vc_num          )
    // -------------------------------------------------------------------------
    // Non Posted Atomic Response Interface
    ,.npdcmp_np_atomic_rsp_valid   (npdcmp_np_atomic_rsp_valid  )
    ,.npdcmp_np_atomic_rsp_id      (npdcmp_np_atomic_rsp_id     )
    // -------------------------------------------------------------------------
    // External RAM Interface
    ,.npdcmp_ram_addra             (ob_npdcmp_ram_addra         )
    ,.npdcmp_ram_wea               (ob_npdcmp_ram_wea           )
    ,.npdcmp_ram_dina              (ob_npdcmp_ram_dina          )
    ,.npdcmp_ram_addrb             (ob_npdcmp_ram_addrb         )
    ,.npdcmp_ram_enb               (ob_npdcmp_ram_enb           )
    ,.npdcmp_ram_doutb             (ob_npdcmp_ram_doutb         )
    ,.pdcmp_hdr_ram_addra          (ob_pdcmp_hdr_ram_addra      )
    ,.pdcmp_hdr_ram_wea            (ob_pdcmp_hdr_ram_wea        )
    ,.pdcmp_hdr_ram_dina           (ob_pdcmp_hdr_ram_dina       )
    ,.pdcmp_hdr_ram_addrb          (ob_pdcmp_hdr_ram_addrb      )
    ,.pdcmp_hdr_ram_enb            (ob_pdcmp_hdr_ram_enb        )
    ,.pdcmp_hdr_ram_doutb          (ob_pdcmp_hdr_ram_doutb      )

    ,.pdcmp_data_ram_addra         (ob_pdcmp_data_ram_addra     )
    ,.pdcmp_data_ram_wea           (ob_pdcmp_data_ram_wea       )
    ,.pdcmp_data_ram_dina          (ob_pdcmp_data_ram_dina      )
    ,.pdcmp_data_ram_addrb         (ob_pdcmp_data_ram_addrb     )
    ,.pdcmp_data_ram_enb           (ob_pdcmp_data_ram_enb       )
    ,.pdcmp_data_ram_doutb         (ob_pdcmp_data_ram_doutb     )

    ,.ccmp_data_ram_addra          (ob_ccmp_data_ram_addra      )
    ,.ccmp_data_ram_wea            (ob_ccmp_data_ram_wea        )
    ,.ccmp_data_ram_dina           (ob_ccmp_data_ram_dina       )
    ,.ccmp_data_ram_addrb          (ob_ccmp_data_ram_addrb      )
    ,.ccmp_data_ram_enb            (ob_ccmp_data_ram_enb        )
    ,.ccmp_data_ram_doutb          (ob_ccmp_data_ram_doutb      )
    // -------------------------------------------------------------------------
    // Parity Error Interface
    ,.client1_addr_parerr          (ob_ras_par_npqdec_ad_pulse)
    ,.client2_addr_parerr          (ob_ras_par_pqdec_ad_pulse)
    ,.npdcmp_ad_ras_dp_err_log     (ob_npdcmp_ad_ras_dp_err_log)
    ,.npdcmp_inq_data_parerr       (ob_ras_par_ob_np_dcmp_inq_dt_pulse)
    ,.npdcmp_inq_dt_ras_dp_err_log (ob_npdcmp_inq_dt_ras_dp_err_log)
    ,.pdcmp_inq_data_parerr        (ob_ras_par_ob_p_dcmp_inq_dt_pulse)
    ,.pdcmp_ad_ras_dp_err_log      (ob_pdcmp_ad_ras_dp_err_log      )
    ,.pdcmp_inq_dt_ras_dp_err_log  (ob_pdcmp_inq_dt_ras_dp_err_log  )
    ,.ras_dp_err_inj_slv_aclk            (ras_dp_err_inj_slv_aclk)
    ,.axi_bridge_ras_dp_err_inj_core_clk (axi_bridge_ras_dp_err_inj_core_clk)
    ,.core_clk_ordrb_ras_dp_err_inj      (core_clk_ordrb_ras_dp_err_inj)
    ,.core_clk_high_freq_ras_dp_err_inj  (core_clk_high_freq_ras_dp_err_inj)
    ,.core_clk_hp_mstr_ras_dp_err_inj    (core_clk_hp_mstr_ras_dp_err_inj)
    ,.ib_last_presp_rpseq_per_vc   (ib_last_presp_rpseq_per_vc  )
    // -------------------------------------------------------------------------
    // CPL Composition Error
    ,.radmx_cmposer_lookup_err     ()
    `endif //!UTB_NATIVE_AXI
    );


`ifndef UTB_NATIVE_AXI

// Internal Slave to DB Interface
  wire [`CC_DBI_SLV_ID_WD-1:0]             dbi_mid;
  wire                                     dbi_mread;
  wire                                     dbi_mwrite;
  wire                                     dbi_mvldrq;
  wire                                     dbi_saccept;

  wire                                     dbi_svalid;
  wire                                     dbi_slast;

  wire [(`RESP_ERRBUS_WD)-1:0] dbi_sresp;

  wire [`CC_DBISLV_INT_BURST_LEN_PW-1:0]   dbi_slen;
  wire [2:0]                               dbi_ssize;
  wire [`CC_DBI_SLV_BUS_DATA_WIDTH-1:0]    dbi_sdata;
  wire [`CC_MAX_SLV_TAG_PW-1:0]            dbi_stag;
  wire [`CC_SLV_BUS_ID_WIDTH-1:0]          dbi_sid;
  wire                                     dbi_mready;


  // ---------------------------------------------------------------------------
  // Instantiate Data Bus interface
  // ---------------------------------------------------------------------------
  DWC_pcie_axi_dbi
  
  #(
    .MAX_SLV_TAG_PW         (`CC_MAX_SLV_TAG_PW    ),
    .DBI_SLV_BUS_ADDR_WIDTH (`CC_DBI_SLV_BUS_ADDR_WIDTH),
    .VALID_DBI_ADDR_WD      (`VALID_DBI_ADDR_WD    ),
    .EXTRA_DBI_ADDR_BIT     (`EXTRA_DBI_ADDR_BIT   ),
    .NFUNC_WD               (`CX_NFUNC_WD          ),
    .NVFUNC_WD              (`CX_NVFUNC_WD         ),
    .SYNC_DEPTH             (`CX_PCIE_SYNC_DEPTH   ),
    .RESP_ERRBUS_WD         (`RESP_ERRBUS_WD)
    )
    u_dbi
    (
     .dbi_clk          (slv_aclk_g      )
    ,.dbi_rst_n        (slv_aresetn     )
    ,.aux_clk_g        (aux_clk_g       )
    ,.core_rst_n       (core_rst_n      )
    // -------------------------------------------------------------------------
    // Slave Data Bus Request Interface
    ,.dbsif_rd         (sif_db_rd       )
    ,.dbsif_wr         (sif_db_wr       )
    ,.dbsif_vldrq      (sif_db_vldrq    )
    ,.dbsif_tag        (sif_db_tag      )
    ,.dbsif_addr       (sif_db_addr     )
    ,.dbsif_strb       (sif_db_strb     )
    ,.dbsif_len        (sif_db_len      )
    ,.dbsif_data       (sif_db_data     )
    ,.dbi_ready        (dbi_ready       )
    //--------------------------------------------------------------------------
    // Slave Data Bus Response Interface
    ,.dbi_valid        (dbi_valid       )
    ,.dbi_last         (dbi_last        )
    ,.dbi_tag          (dbi_tag         )
    ,.dbi_resp         (dbi_resp        )
    ,.dbi_data         (dbi_data        )
    ,.sif_db_ready     (sif_db_ready    )
    //--------------------------------------------------------------------------
    // Data bus bi-directional interface
    // DBI request
    ,.dbi_cs           (dbi_cs          )
    ,.dbi_cs2          (dbi_cs2         )
    ,.dbi_addr         (dbi_addr        )
    ,.dbi_din          (dbi_din         )
    ,.dbi_wr           (dbi_wr          )
    ,.dbi_bar_num      (dbi_bar_num     )
    ,.dbi_func_num     (dbi_func_num    )
    ,.dbi_rom_access   (dbi_rom_access  )
    ,.dbi_io_access    (dbi_io_access   )
    // -------------------------------------------------------------------------
    // DBI response
    ,.dbi_ack          (dbi_ack         )
    ,.dbi_dout         (dbi_dout        )
  );




  // ---------------------------------------------------------------------------
  // Instantiate AXI Slave Flush Control Logic
  // ---------------------------------------------------------------------------
  DWC_pcie_axi_flush_ctl
  
  #(.SYNC_DEPTH                            (`CX_PCIE_SYNC_DEPTH)
  )
  u_flshctl
  (
  .core_rst_n                             (core_rst_n)
  ,.core_clk                                (core_clk)
  ,.slv_aclk_ug                            (slv_aclk)
  ,.slv_aresetn                            (slv_aresetn)
  // -------------------------------------------------------------------------
  // Flush Request/Acknowledge interface
  ,.rstctl_mstr_flush_req                  (rstctl_mstr_flush_req)
  ,.rstctl_slv_flush_req                   (rstctl_slv_flush_req)
  ,.flshctl_slv_flush_ack                  (w_brdg_slv_flush_ack)
  ,.flshctl_sif_flush_req                  (flshctl_sif_flush_req)
  // -------------------------------------------------------------------------
  // Slave Transfer Flush Ack interface
  ,.sif_flush_ack                          (sif_flush_ack)
  );

  assign brdg_slv_flush_ack = w_brdg_slv_flush_ack && !s_client1_tlp_dv && !s_client2_tlp_dv;


// ------------------------------------------------------------------------
// Tie-off signals
// ------------------------------------------------------------------------
// Non-Posted Client TLP Interface
assign s_client1_cpl_lookup_id = {`CX_REMOTE_LOOKUPID_WD{1'b0}};
assign s_client1_addr_align_en = '0;
assign s_client1_cpl_cmpltr_id = '0;
assign s_client1_cpl_status = '0;
assign s_client1_cpl_bcm = '0;
assign s_client1_cpl_byte_cnt = '0;
assign s_client1_tlp_bad_eot = '0;
assign s_client1_tlp_td = '0;

// Posted Client TLP interface
assign s_client2_cpl_lookup_id = {`CX_REMOTE_LOOKUPID_WD{1'b0}};
assign s_client2_addr_align_en = '0;
assign s_client2_remote_req_id = '0;
assign s_client2_cpl_status = '0;
assign s_client2_cpl_bcm = '0;
assign s_client2_cpl_byte_cnt = '0;
assign s_client2_tlp_bad_eot = '0;
assign s_client2_tlp_td = '0;

assign s_client1_tlp_dma          = '0;
assign s_client1_tlp_dma_channel  = '0;
assign s_client2_tlp_dma          = '0;
assign s_client2_tlp_dma_channel  = '0;
assign s_client0_tlp_nw           = '0;
assign s_client0_tlp_th           = '0;
assign s_client0_tlp_ph           = '0;
assign s_client0_tlp_st           = '0;

logic  axi_client0_halt;
logic  axi_client1_halt;
logic  axi_client2_halt;

assign s_xadm_client0_halt = axi_client0_halt;
assign s_xadm_client1_halt = axi_client1_halt;

assign s_xadm_client2_halt = axi_client2_halt;


assign axi_client0_s = '{
                          tlp_hv             : s_client0_tlp_hv
                        , tlp_dv             : s_client0_tlp_dv
                        , tlp_eot            : s_client0_tlp_eot
                        , tlp_bad_eot        : s_client0_tlp_bad_eot
                        , tlp_fmt            : s_client0_tlp_fmt
                        , tlp_type           : s_client0_tlp_type
                        , tlp_td             : s_client0_tlp_td
                        , tlp_ep             : s_client0_tlp_ep
                        , tlp_attr           : s_client0_tlp_attr
                        , addr_align_en      : s_client0_addr_align_en
                        , tlp_func_num       : s_client0_tlp_func_num
                        , cpl_cmpltr_id      : s_client0_cpl_cmpltr_id
                        , cpl_status         : s_client0_cpl_status
                        , cpl_bcm            : s_client0_cpl_bcm
                        , cpl_byte_cnt       : s_client0_cpl_byte_cnt
                        , cpl_last           : s_client0_cpl_last
                        , tlp_ats            : s_client0_tlp_ats
                        , tlp_nw             : s_client0_tlp_nw
                        , tlp_tid            : s_client0_tlp_tid
                        , tlp_byte_len       : s_client0_tlp_byte_len
                        , tlp_addr           : s_client0_tlp_addr
                        , tlp_byte_en        : s_client0_tlp_byte_en
                        , tlp_tc             : s_client0_tlp_tc
                        , tlp_data           : s_client0_tlp_data
                        , cpl_lookup_id      : s_client0_cpl_lookup_id
                        , tlp_atu_bypass     : s_client0_tlp_atu_bypass
                        , tlp_dma            : s_client0_tlp_dma
                        , tlp_dma_channel    : s_client0_tlp_dma_channel
                        , tlp_prv_dma        : s_client0_tlp_prv_dma
                        , tlp_prv_dma_chan   : s_client0_tlp_prv_dma_chan
                        , tlp_th             : s_client0_tlp_th
                        , tlp_ph             : s_client0_tlp_ph
                        , tlp_st             : s_client0_tlp_st
                        , tlp_dst_segment    : '0
                        , tlp_order_seqnum   : '0
                       };


assign axi_client1_s = '{
                          tlp_hv            : s_client1_tlp_hv
                        , tlp_dv            : s_client1_tlp_dv
                        , tlp_eot           : s_client1_tlp_eot
                        , tlp_fmt           : s_client1_tlp_fmt
                        , tlp_type          : s_client1_tlp_type
                        , tlp_td            : s_client1_tlp_td
                        , tlp_ep            : s_client1_tlp_ep
                        , tlp_attr          : s_client1_tlp_attr
                        , tlp_bad_eot       : s_client1_tlp_bad_eot
                        , addr_align_en     : s_client1_addr_align_en
                        , tlp_func_num      : s_client1_tlp_func_num
                        , cpl_cmpltr_id     : s_client1_cpl_cmpltr_id
                        , cpl_status        : s_client1_cpl_status
                        , cpl_bcm           : s_client1_cpl_bcm
                        , cpl_byte_cnt      : s_client1_cpl_byte_cnt
                        , tlp_ats           : s_client1_tlp_ats
                        , tlp_nw            : s_client1_tlp_nw
                        , tlp_tid           : s_client1_tlp_tid
                        , tlp_byte_len      : s_client1_tlp_byte_len
                        , tlp_addr          : s_client1_tlp_addr
                        , tlp_byte_en       : s_client1_tlp_byte_en
                        , tlp_tc            : s_client1_tlp_tc
                        , tlp_data          : s_client1_tlp_data
                        , cpl_lookup_id     : s_client1_cpl_lookup_id
                        , tlp_prfx          : s_client1_tlp_prfx
                        , tlp_atu_bypass    : s_client1_tlp_atu_bypass
                        , tlp_dma           : s_client1_tlp_dma
                        , tlp_dma_channel   : s_client1_tlp_dma_channel
                        , tlp_th            : s_client1_tlp_th
                        , tlp_ph            : s_client1_tlp_ph
                        , tlp_st            : s_client1_tlp_st
                        , tlp_dst_segment   : s_client1_tlp_dst_segment
                        , tlp_order_seqnum  : '0
                       };


assign axi_client2_s = '{
                          tlp_hv           : s_client2_tlp_hv && !s_client2_tlp_silentDrop
                        , tlp_dv           : s_client2_tlp_dv && !s_client2_tlp_silentDrop
                        , tlp_eot          : s_client2_tlp_eot && !s_client2_tlp_silentDrop
                        , tlp_fmt          : s_client2_tlp_fmt
                        , tlp_type         : s_client2_tlp_type
                        , tlp_tc           : s_client2_tlp_tc
                        , tlp_td           : s_client2_tlp_td
                        , tlp_ep           : s_client2_tlp_ep
                        , tlp_attr         : s_client2_tlp_attr
                        , tlp_bad_eot      : s_client2_tlp_bad_eot
                        , addr_align_en    : s_client2_addr_align_en
                        , tlp_func_num     : s_client2_tlp_func_num
                        , remote_req_id    : s_client2_remote_req_id
                        , cpl_status       : s_client2_cpl_status
                        , cpl_bcm          : s_client2_cpl_bcm
                        , cpl_byte_cnt     : s_client2_cpl_byte_cnt
                        , tlp_ats          : s_client2_tlp_ats
                        , tlp_nw           : s_client2_tlp_nw
                        , tlp_tid          : s_client2_tlp_tid
                        , tlp_byte_len     : s_client2_tlp_byte_len
                        , tlp_addr         : s_client2_tlp_addr
                        , tlp_byte_en      : s_client2_tlp_byte_en
                        , tlp_data         : s_client2_tlp_data
                        , cpl_lookup_id    : s_client2_cpl_lookup_id
                        , tlp_prfx         : s_client2_tlp_prfx
                        , tlp_atu_bypass   : s_client2_tlp_atu_bypass
                        , tlp_dma           : s_client2_tlp_dma
                        , tlp_dma_channel   : s_client2_tlp_dma_channel
                        , tlp_th           : s_client2_tlp_th
                        , tlp_ph           : s_client2_tlp_ph
                        , tlp_st           : s_client2_tlp_st
                        , tlp_dst_segment  : s_client2_tlp_dst_segment
                        , tlp_order_seqnum : '0
                      };


  DWC_pcie_axi_mstream
   #(
    .NVC                      (`CX_NVC)
  ) u_mstream (
    .core_clk                 (core_clk                 ),
    .core_rst_n               (core_rst_n               ),
    .slv_aclk                 (slv_aclk_g               ),
    .slv_aresetn              (slv_aresetn              ),
    .axi_client0_s            (axi_client0_s            ),
    .axi_client1_s            (axi_client1_s            ),
    .axi_client2_s            (axi_client2_s            ),
    .exp_client0_s            (exp_client0_s            ),
    .exp_client1_s            (exp_client1_s            ),
    .exp_client2_s            (exp_client2_s            ),
    .xadm_client0_halt        (xadm_client0_halt        ),
    .xadm_client1_halt        (xadm_client1_halt        ),
    .xadm_client2_halt        (xadm_client2_halt        ),
    .cfg_tc_struc_vc_map      (cfg_tc_struc_vc_map      ),
    .xali_posted_tlp_sent     (xali_posted_tlp_sent     ),
    .axi_client0_halt         (axi_client0_halt         ),
    .axi_client1_halt         (axi_client1_halt         ),
    .axi_client2_halt         (axi_client2_halt         ),

    // Responses Interface
    .pdcmp_p_rsp_valid        (pdcmp_p_rsp_valid        ),
    .pdcmp_p_rsp_null_or_err  (pdcmp_p_rsp_null_or_err  ),
    .pdcmp_p_rsp_last         (pdcmp_p_rsp_last         ),
    .pdcmp_p_rsp_vc_num       (pdcmp_p_rsp_vc_num       ),
    .pdcmp_p_rsp_id           (pdcmp_p_rsp_id           ),
    .pdcmp_p_rsp_cpl_stat     (pdcmp_p_rsp_cpl_stat     ),
    .mstream_p_rsp_valid      (mstream_p_rsp_valid      ),
    .mstream_p_rsp_id         (mstream_p_rsp_id         ),
    .mstream_p_rsp_cpl_stat   (mstream_p_rsp_cpl_stat   )
  );


  // -------------------------------------------------------
  // XALI 0 Expanded Outputs assignment
  // -------------------------------------------------------
  assign client0_tlp_hv = exp_client0_s.tlp_hv;
  assign client0_tlp_dv = exp_client0_s.tlp_dv;
  assign client0_tlp_eot = exp_client0_s.tlp_eot;
  assign client0_tlp_bad_eot = exp_client0_s.tlp_bad_eot;
  assign client0_tlp_fmt = exp_client0_s.tlp_fmt;
  assign client0_tlp_type = exp_client0_s.tlp_type;
  assign client0_tlp_td = exp_client0_s.tlp_td;
  assign client0_tlp_ep = exp_client0_s.tlp_ep;
  assign client0_tlp_attr = exp_client0_s.tlp_attr;
  assign client0_addr_align_en = exp_client0_s.addr_align_en;
  assign client0_tlp_func_num = exp_client0_s.tlp_func_num;
  assign client0_cpl_cmpltr_id = exp_client0_s.cpl_cmpltr_id;
  assign client0_cpl_status = exp_client0_s.cpl_status;
  assign client0_cpl_bcm = exp_client0_s.cpl_bcm;
  assign client0_cpl_byte_cnt = exp_client0_s.cpl_byte_cnt;
  assign client0_cpl_last = exp_client0_s.cpl_last;
  assign client0_tlp_ats = exp_client0_s.tlp_ats;
  assign client0_tlp_nw = exp_client0_s.tlp_nw;
  assign client0_tlp_tid = exp_client0_s.tlp_tid;
  assign client0_tlp_byte_len = exp_client0_s.tlp_byte_len;
  assign client0_tlp_addr = exp_client0_s.tlp_addr;
  assign client0_tlp_data = exp_client0_s.tlp_data;
  assign client0_tlp_byte_en = exp_client0_s.tlp_byte_en;
  assign client0_tlp_tc = exp_client0_s.tlp_tc;
  assign client0_cpl_lookup_id = exp_client0_s.cpl_lookup_id;
  assign client0_tlp_atu_bypass = exp_client0_s.tlp_atu_bypass;
  assign client0_tlp_dma = exp_client0_s.tlp_dma;
  assign client0_tlp_dma_channel = exp_client0_s.tlp_dma_channel;
  assign client0_tlp_prv_dma = exp_client0_s.tlp_prv_dma;
  assign client0_tlp_prv_dma_chan = exp_client0_s.tlp_prv_dma_chan;
  assign client0_tlp_th = exp_client0_s.tlp_th;
  assign client0_tlp_ph = exp_client0_s.tlp_ph;
  assign client0_tlp_st = exp_client0_s.tlp_st;
  assign client0_hdr_prot = s_client0_hdr_prot;
  assign client0_tlp_dst_segment = exp_client0_s.tlp_dst_segment;

   // -------------------------------------------------------
   // XALI 1 Expanded Outputs assignment
   // -------------------------------------------------------
   assign client1_tlp_hv = exp_client1_s.tlp_hv;
   assign client1_tlp_dv = exp_client1_s.tlp_dv;
   assign client1_tlp_eot = exp_client1_s.tlp_eot;
   assign client1_tlp_fmt = exp_client1_s.tlp_fmt;
   assign client1_tlp_type = exp_client1_s.tlp_type;
   assign client1_tlp_td = exp_client1_s.tlp_td;
   assign client1_tlp_ep = exp_client1_s.tlp_ep;
   assign client1_tlp_attr = exp_client1_s.tlp_attr;
   assign client1_tlp_bad_eot = exp_client1_s.tlp_bad_eot;
   assign client1_addr_align_en = exp_client1_s.addr_align_en;
   assign client1_tlp_func_num = exp_client1_s.tlp_func_num;
   assign client1_cpl_cmpltr_id = exp_client1_s.cpl_cmpltr_id;
   assign client1_cpl_status = exp_client1_s.cpl_status;
   assign client1_cpl_bcm = exp_client1_s.cpl_bcm;
   assign client1_cpl_byte_cnt = exp_client1_s.cpl_byte_cnt;
   assign client1_tlp_ats = exp_client1_s.tlp_ats;
   assign client1_tlp_nw = exp_client1_s.tlp_nw;
   assign client1_tlp_tid = exp_client1_s.tlp_tid;
   assign client1_tlp_byte_len = exp_client1_s.tlp_byte_len;
   assign client1_tlp_addr = exp_client1_s.tlp_addr;
   assign client1_tlp_data = exp_client1_s.tlp_data;
   assign client1_tlp_byte_en = exp_client1_s.tlp_byte_en;
   assign client1_tlp_tc = exp_client1_s.tlp_tc;
   assign client1_cpl_lookup_id = exp_client1_s.cpl_lookup_id;
   assign client1_tlp_prfx = exp_client1_s.tlp_prfx;
   assign client1_tlp_atu_bypass = exp_client1_s.tlp_atu_bypass;
   assign client1_tlp_dma = exp_client1_s.tlp_dma;
   assign client1_tlp_dma_channel = exp_client1_s.tlp_dma_channel;
   assign client1_tlp_th = exp_client1_s.tlp_th;
   assign client1_tlp_ph = exp_client1_s.tlp_ph;
   assign client1_tlp_st = exp_client1_s.tlp_st;
   assign client1_hdr_prot = s_client1_hdr_prot;
   assign s_client1_tlp_addr_par = exp_client1_s.tlp_addr_par;
  assign client1_tlp_dst_segment = exp_client1_s.tlp_dst_segment;

   // -------------------------------------------------------
   // XALI 2 Expanded Outputs assignment
   // -------------------------------------------------------
   assign client2_tlp_hv = exp_client2_s.tlp_hv;
   assign client2_tlp_dv = exp_client2_s.tlp_dv;
   assign client2_tlp_eot = exp_client2_s.tlp_eot;
   assign client2_tlp_fmt = exp_client2_s.tlp_fmt;
   assign client2_tlp_type = exp_client2_s.tlp_type;
   assign client2_tlp_tc = exp_client2_s.tlp_tc;
   assign client2_tlp_td = exp_client2_s.tlp_td;
   assign client2_tlp_ep = exp_client2_s.tlp_ep;
   assign client2_tlp_attr = exp_client2_s.tlp_attr;
   assign client2_tlp_bad_eot = exp_client2_s.tlp_bad_eot;
   assign client2_addr_align_en = exp_client2_s.addr_align_en;
   assign client2_tlp_func_num = exp_client2_s.tlp_func_num;
   assign client2_remote_req_id = exp_client2_s.remote_req_id;
   assign client2_cpl_status = exp_client2_s.cpl_status;
   assign client2_cpl_bcm = exp_client2_s.cpl_bcm;
   assign client2_cpl_byte_cnt = exp_client2_s.cpl_byte_cnt;
   assign client2_tlp_ats = exp_client2_s.tlp_ats;
   assign client2_tlp_nw = exp_client2_s.tlp_nw;
   assign client2_tlp_tid = exp_client2_s.tlp_tid;
   assign client2_tlp_byte_len = exp_client2_s.tlp_byte_len;
   assign client2_tlp_addr = exp_client2_s.tlp_addr;
   assign client2_tlp_data = exp_client2_s.tlp_data;
   assign client2_tlp_byte_en = exp_client2_s.tlp_byte_en;
   assign client2_cpl_lookup_id = exp_client2_s.cpl_lookup_id;
   assign client2_tlp_prfx = exp_client2_s.tlp_prfx;
   assign client2_tlp_atu_bypass = exp_client2_s.tlp_atu_bypass;
   assign client2_tlp_dma = exp_client2_s.tlp_dma;
   assign client2_tlp_dma_channel = exp_client2_s.tlp_dma_channel;
   assign client2_tlp_th = exp_client2_s.tlp_th;
   assign client2_tlp_ph = exp_client2_s.tlp_ph;
   assign client2_tlp_st = exp_client2_s.tlp_st;
   assign client2_hdr_prot = s_client2_hdr_prot;
   assign s_client2_tlp_addr_par = exp_client2_s.tlp_addr_par;
  assign client2_tlp_dst_segment = exp_client2_s.tlp_dst_segment;

  // ---------------------------------------------------------------------------
  // Instantiate AXI Wakeup Control Logic
  // ---------------------------------------------------------------------------
  DWC_pcie_axi_wakeup_ctl
  
  #(
   .SYNC_DEPTH                             (`CX_PCIE_SYNC_DEPTH)
  )
  u_wkctl
  (
  .aux_clk                                 (aux_clk)
  ,.core_rst_n                             (core_rst_n)
  ,.mstr_aclk_ug                           (mstr_aclk)
  ,.mstr_aresetn                           (mstr_aresetn)
  ,.slv_aclk_ug                            (slv_aclk)
  ,.slv_aresetn                            (slv_aresetn)
  // -------------------------------------------------------------------------
  // Slave Transfer Pending Info interface
  ,.sif_xfer_pending                       (sif_xfer_pending)
  ,.sif_xfer_pending_db                    (sif_xfer_pending_db)
  // -------------------------------------------------------------------------
  ,.wkctl_slv_xfer_pending                 (w_brdg_slv_xfer_pending)

  ,.wkctl_slv_xfer_pending_db              (brdg_dbi_xfer_pending)
  );

  reg r_brdg_slv_xfer_pending;
  always @(posedge aux_clk or negedge core_rst_n) begin : proc_reg_brdg_slv_xfer_pending
    if (!core_rst_n) begin
      r_brdg_slv_xfer_pending <= # `TP 1'b0;
    end else begin
      r_brdg_slv_xfer_pending <= # `TP w_brdg_slv_xfer_pending || s_client1_tlp_dv || s_client2_tlp_dv
                                       // Allow for single stage pipeline stage in u_mstream
                                       || client1_tlp_dv || client2_tlp_dv
                                       ;
    end
  end
  assign brdg_slv_xfer_pending = r_brdg_slv_xfer_pending;


  // -------------------------------------------------------------------------
   DWC_pcie_bridge_rasdp
   
     #(
       .CX_RAS_PROT_RANGE               (`CX_RAS_PROT_RANGE              ),
       .MSTR_ADDR_WD                    (`CC_MSTR_BUS_ADDR_WIDTH         ),
       .MSTR_ADDR_WD_NP                 (`MASTER_BUS_ADDR_WIDTH          ),
       .MSTR_BUS_ADDRP_WIDTH            (`CC_MSTR_BUS_ADDRP_WIDTH        ),
       .MSTR_DATA_WD                    (`CC_MSTR_BUS_DATA_WIDTH         ),
       .MSTR_DATA_WD_NP                 (`MASTER_BUS_DATA_WIDTH          ),
       .MSTR_DATAP_WD                   (`CC_MSTR_BUS_DATAP_WIDTH        ),
       .CORE_DATA_BUS_WD                (`CC_CORE_DATA_BUS_WD            ),
       .PCIE_CORE_DATA_BUS_WD           (`PCIE_CORE_DATA_BUS_WD          ),
       .CLIENT_HDR_PROT_WD              (`CLIENT_HDR_PROT_WD             ),
       .CLIENT_HDR_WD                   (`CLIENT_HDR_WD                  ),
       .SLV_BUS_DATA_WIDTH_NP           (`SLAVE_BUS_DATA_WIDTH           ),
       .SLV_BUS_DATA_WIDTH              (`CC_SLV_BUS_DATA_WIDTH          ),
       .SLV_BUS_DATAP_WIDTH             (`CC_SLV_BUS_DATAP_WIDTH         ),
       .SLV_BUS_WSTRB_WIDTH             (`CC_SLV_BUS_WSTRB_WIDTH         ),
       .SLAVE_BUS_ADDR_WIDTH            (`SLAVE_BUS_ADDR_WIDTH           ),
       .SLV_BUS_ADDRP_WIDTH             (`CC_SLV_BUS_ADDRP_WIDTH         ),
       .SLV_BUS_ADDR_WIDTH              (`CC_SLV_BUS_ADDR_WIDTH          ),
       .ADDR_PAR_WD                     (`CX_ADDR_PAR_WD                 ),
       .SLV_NPW_SAB_RAM_ADDR_WD         (`CC_SLV_NPW_SAB_RAM_ADDR_WD     ),
       .OB_NPDCMP_RAM_ADDR_WD           (`CC_OB_NPDCMP_RAM_ADDR_WD       ),
       .OB_PDCMP_HDR_RAM_ADDR_WD        (`CC_OB_PDCMP_HDR_RAM_ADDR_WD    ),
       .OB_PDCMP_DATA_RAM_ADDR_WD       (`CC_OB_PDCMP_DATA_RAM_ADDR_WD   ),
       .CC_OB_CCMP_DATA_RAM_ADDR_WD     (`CC_OB_CCMP_DATA_RAM_ADDR_WD    ),
       .CC_IB_RD_REQ_ORDR_RAM_ADDR_WD   (`CC_IB_RD_REQ_ORDR_RAM_ADDR_WD  ),
       .CC_IB_RD_REQ_CDC_RAM_ADDR_WD    (`CC_IB_RD_REQ_CDC_RAM_ADDR_WD   ),
       .CC_IB_WR_REQ_CDC_RAM_ADDR_WD    (`CC_IB_WR_REQ_CDC_RAM_ADDR_WD   ),
       .CC_IB_MCPL_CDC_RAM_ADDR_WD      (`CC_IB_MCPL_CDC_RAM_ADDR_WD     ),
       .CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD  (`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD ),
       .OB_NPDCMP_RAM_ADDRP_WD          (`CC_OB_NPDCMP_RAM_ADDRP_WD      ),
       .OB_PDCMP_HDR_RAM_ADDRP_WD       (`CC_OB_PDCMP_HDR_RAM_ADDRP_WD   ),
       .OB_PDCMP_DATA_RAM_ADDRP_WD      (`CC_OB_PDCMP_DATA_RAM_ADDRP_WD  ),
       .SLV_NPW_SAB_RAM_ADDRP_WD        (`CC_SLV_NPW_SAB_RAM_ADDRP_WD    ),
       .CC_OB_CCMP_DATA_RAM_ADDRP_WD    (`CC_OB_CCMP_DATA_RAM_ADDRP_WD   ),
       .CC_IB_RD_REQ_CDC_RAM_ADDRP_WD   (`CC_IB_RD_REQ_CDC_RAM_ADDRP_WD  ),
       .CC_IB_WR_REQ_CDC_RAM_ADDRP_WD   (`CC_IB_WR_REQ_CDC_RAM_ADDRP_WD  ),
       .CC_IB_MCPL_CDC_RAM_ADDRP_WD     (`CC_IB_MCPL_CDC_RAM_ADDRP_WD    ),
       .CC_IB_RD_REQ_ORDR_RAM_ADDRP_WD  (`CC_IB_RD_REQ_ORDR_RAM_ADDRP_WD ),
       .CC_IB_MCPL_SEG_BUF_RAM_ADDRP_WD (`CC_IB_MCPL_SEG_BUF_RAM_ADDRP_WD)
       ) u_rasdp
       (
         .core_clk(aux_clk_g)
        ,.core_rst_n(core_rst_n)
        ,.mstr_aclk(mstr_aclk_g)
        ,.mstr_aclk_ug(mstr_aclk)
        ,.mstr_aresetn(mstr_aresetn)
        ,.slv_aclk(slv_aclk_g)
        ,.slv_aclk_ug(slv_aclk)
        ,.slv_aresetn(slv_aresetn)
        ,.cfg_rasdp_err_mode(cfg_rasdp_err_mode)
        ,.axi_bridge_ras_dp_err_inj_core_clk (axi_bridge_ras_dp_err_inj_core_clk)
        ,.core_clk_hp_mstr_ras_dp_err_inj    (core_clk_hp_mstr_ras_dp_err_inj   )
        ,.cfg_rasdp_err_mode_en_d(qslv_d.cfg_rasdp_err_mode_en)
        ,.cfg_rasdp_err_mode_en_d1(qmstr_d.cfg_rasdp_err_mode_en)
        ,.mstr_rasdp_err_mode(rasdp_mstr_rasdp_err_mode)
        ,.slv_rasdp_err_mode(rasdp_slv_rasdp_err_mode)
        ,.msg_addr_int(msg_addr_mstr)
        ,.msg_par(msg_addrp_mstr)

        ,.axigm_ras_par_ibr_rmstr_ad_pulse(axigm_ras_par_ibr_rmstr_ad_pulse)

        ,.axigm_ras_par_ibr_wmstr_ad_pulse(axigm_ras_par_ibr_wmstr_ad_pulse)

        ,.axigm_ras_par_ibr_wmstr_dt_pulse(axigm_ras_par_ibr_wmstr_dt_pulse)


        ,.client0_tlp_dv(client0_tlp_dv)
        ,.xadm_client0_halt(xadm_client0_halt)
        ,.client0_tlp_data(client0_tlp_data)
        ,.axi_ras_par_ib_mcpl_dt_pulse(axi_ras_par_ib_mcpl_dt_pulse_g)
        ,.axi_ib_mcpl_dt_ras_dp_err_log (axi_ib_mcpl_dt_ras_dp_err_log_g)


        ,.slv_if_ras_err_sts               (slv_sisb_err_sts)
        ,.axi_ras_slv_if_uncorr_pulse      (axi_slv_sisb_uncorr_pulse)
        ,.mstr_if_ras_err_sts              (mstr_misb_err_sts)
        ,.axi_ras_mstr_if_uncorr_pulse     (axi_mstr_misb_uncorr_pulse)

        ,.client0_hdr(
                      {
                         {`CX_AXI_NVC_XALI_EXPANSION{1'b0}},
                         {`CX_AXI_NVC_XALI_EXPANSION{8'd0}},
                         {`CX_AXI_NVC_XALI_EXPANSION{2'd0}},
                         client0_tlp_func_num
                         , client0_tlp_attr
                         , client0_tlp_ats
                         , client0_tlp_nw
                         , client0_addr_align_en
                         , client0_tlp_byte_en
                         , client0_cpl_cmpltr_id
                         , client0_cpl_status
                         , client0_cpl_bcm
                         , client0_cpl_byte_cnt
                         , client0_tlp_tid
                         , client0_tlp_byte_len
                         , client0_tlp_ep
                         , client0_tlp_td
                         , client0_tlp_tc
                         , client0_tlp_type
                         , client0_tlp_fmt
                         , client0_tlp_addr
                         }
                      )
        ,.client0_hdr_prot(s_client0_hdr_prot)
        ,.msg_addr_slv_int(msg_addr_slv_int)
        ,.msg_addr_w_par_slv(msg_addr_w_par_slv)

        ,.sif_ras_par_rslv_dt_pulse(sif_ras_par_rslv_dt_pulse)

        ,.sif_ras_par_slnull_ad_pulse(sif_ras_par_slnull_ad_pulse)
        ,.axi_ras_par_slnull_ad_pulse(axi_ras_par_slnull_ad_pulse_g)

        ,.sif_ras_par_slnull_dt_pulse(sif_ras_par_slnull_dt_pulse)
        ,.axi_ras_par_slnull_dt_pulse(axi_ras_par_slnull_dt_pulse_g)

        ,.ob_ras_par_npqdec_ad_pulse(ob_ras_par_npqdec_ad_pulse)
        ,.axi_ras_par_npqdec_ad_pulse(axi_ras_par_npqdec_ad_pulse_g)

        ,.ob_ras_par_pqdec_ad_pulse(ob_ras_par_pqdec_ad_pulse)
        ,.axi_ras_par_pqdec_ad_pulse(axi_ras_par_pqdec_ad_pulse_g)

        ,.client1_tlp_hv(client1_tlp_hv)
        ,.client1_tlp_data(client1_tlp_data)
        ,.client1_hdr(
                      {
                       client1_tlp_th,
                       client1_tlp_st,
                       client1_tlp_ph,
                       client1_tlp_func_num
                       , client1_tlp_attr
                       , client1_tlp_ats
                       , client1_tlp_nw
                       , client1_addr_align_en
                       , client1_tlp_byte_en
                       , client1_cpl_cmpltr_id
                       , client1_cpl_status
                       , client1_cpl_bcm
                       , client1_cpl_byte_cnt
                       , client1_tlp_tid
                       , client1_tlp_byte_len
                       , client1_tlp_ep
                       , client1_tlp_td
                       , client1_tlp_tc
                       , client1_tlp_type
                       , client1_tlp_fmt
                       , client1_tlp_addr
                       }
                      )
        ,.client1_hdr_prot(s_client1_hdr_prot)
        ,.client1_tlp_dv(client1_tlp_dv)
        ,.xadm_client1_halt(xadm_client1_halt)

        ,.axi_ras_par_c1_dt_pulse(axi_ras_par_c1_dt_pulse_g)
        ,.axi_c1_dt_ras_dp_err_log (axi_c1_dt_ras_dp_err_log_g)

        ,.client2_tlp_hv(client2_tlp_hv)
        ,.client2_tlp_data(client2_tlp_data)
        ,.client2_hdr(
                      {
                         client2_tlp_th,
                         client2_tlp_st,
                         client2_tlp_ph,
                         client2_tlp_func_num
                         , client2_tlp_attr
                         , client2_tlp_ats
                         , client2_tlp_nw
                         , client2_addr_align_en
                         , client2_tlp_byte_en
                         , client2_remote_req_id
                         , client2_cpl_status
                         , client2_cpl_bcm
                         , client2_cpl_byte_cnt
                         , client2_tlp_tid
                         , client2_tlp_byte_len
                         , client2_tlp_ep
                         , client2_tlp_td
                         , client2_tlp_tc
                         , client2_tlp_type
                         , client2_tlp_fmt
                         , client2_tlp_addr
                         }
                      )
        ,.client2_hdr_prot(s_client2_hdr_prot)
        ,.client2_tlp_dv(client2_tlp_dv)
        ,.xadm_client2_halt(xadm_client2_halt)

        ,.axi_ras_par_c2_dt_pulse(axi_ras_par_c2_dt_pulse_g)
        ,.axi_c2_dt_ras_dp_err_log(axi_c2_dt_ras_dp_err_log_g)
        ,.client1_tlp_addr(client1_tlp_addr)
        ,.client1_tlp_addr_par(s_client1_tlp_addr_par)
        ,.axi_ras_par_c1_ad_pulse(axi_ras_par_c1_ad_pulse_g)
        ,.axi_c1_ad_ras_dp_err_log(axi_c1_ad_ras_dp_err_log_g)

        ,.client2_tlp_addr(client2_tlp_addr)
        ,.client2_tlp_addr_par(s_client2_tlp_addr_par)
        ,.axi_ras_par_c2_ad_pulse(axi_ras_par_c2_ad_pulse_g)
        ,.axi_c2_ad_ras_dp_err_log(axi_c2_ad_ras_dp_err_log_g)

        ,.sif_ras_recc_ucorr_cnt_npw_sab_pulse(sif_ras_recc_ucorr_cnt_npw_sab_pulse)
        ,.sif_ras_recc_cnt_npw_sab_addr(sif_ras_recc_cnt_npw_sab_addr)
        ,.axi_ras_recc_ucorr_cnt_npw_sab_pulse(axi_ras_recc_ucorr_cnt_npw_sab_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_npw_sab_addr(axi_ras_recc_ucorr_cnt_npw_sab_addr)

        ,.sif_ras_recc_corr_cnt_npw_sab_pulse(sif_ras_recc_corr_cnt_npw_sab_pulse)
        ,.axi_ras_recc_corr_cnt_npw_sab_pulse(axi_ras_recc_corr_cnt_npw_sab_pulse)
        ,.axi_ras_recc_corr_cnt_npw_sab_addr(axi_ras_recc_corr_cnt_npw_sab_addr)


        ,.sif_ras_par_swwrap_dt_pulse(sif_ras_par_swwrap_dt_pulse)
        ,.sif_ras_par_swwrap_ad_pulse(sif_ras_par_swwrap_ad_pulse)
        ,.sif_ras_par_srwrap_ad_pulse(sif_ras_par_srwrap_ad_pulse)
        ,.axi_ras_par_swwrap_dt_pulse(axi_ras_par_swwrap_dt_pulse_g)
        ,.axi_ras_par_swwrap_ad_pulse(axi_ras_par_swwrap_ad_pulse_g)
        ,.axi_ras_par_srwrap_ad_pulse(axi_ras_par_srwrap_ad_pulse_g)

        ,.sif_ras_par_swrq_npw_dt_pulse(sif_ras_par_swrq_npw_dt_pulse)
        ,.sif_ras_par_swrq_npw_ad_pulse(sif_ras_par_swrq_npw_ad_pulse)
        ,.axi_ras_par_swrq_npw_dt_pulse(axi_ras_par_swrq_npw_dt_pulse_g)
        ,.axi_ras_par_swrq_npw_ad_pulse(axi_ras_par_swrq_npw_ad_pulse_g)

        ,.ob_ras_par_ob_np_dcmp_inq_dt_pulse(ob_ras_par_ob_np_dcmp_inq_dt_pulse)
        ,.axi_ras_par_ob_np_dcmp_inq_dt_pulse(axi_ras_par_ob_np_dcmp_inq_dt_pulse_g)

        ,.ob_ras_par_ob_p_dcmp_inq_dt_pulse(ob_ras_par_ob_p_dcmp_inq_dt_pulse)
        ,.axi_ras_par_ob_p_dcmp_inq_dt_pulse(axi_ras_par_ob_p_dcmp_inq_dt_pulse_g)


        ,.ob_ras_recc_ucorr_cnt_ob_npdcmp_pulse(ob_ras_recc_ucorr_cnt_ob_npdcmp_pulse)
        ,.ob_ras_recc_cnt_ob_npdcmp_addr(ob_ras_recc_cnt_ob_npdcmp_addr)
        ,.axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse(axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_ob_npdcmp_addr(axi_ras_recc_ucorr_cnt_ob_npdcmp_addr)

        ,.ob_ras_recc_corr_cnt_ob_npdcmp_pulse(ob_ras_recc_corr_cnt_ob_npdcmp_pulse)
        ,.axi_ras_recc_corr_cnt_ob_npdcmp_pulse(axi_ras_recc_corr_cnt_ob_npdcmp_pulse)
        ,.axi_ras_recc_corr_cnt_ob_npdcmp_addr(axi_ras_recc_corr_cnt_ob_npdcmp_addr)

        ,.ob_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse(ob_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse)
        ,.ob_ras_recc_cnt_ob_pdcmp_hdr_addr(ob_ras_recc_cnt_ob_pdcmp_hdr_addr)
        ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse(axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_addr(axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_addr)

        ,.ob_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse(ob_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse)
        ,.axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse(axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse)
        ,.axi_ras_recc_corr_cnt_ob_pdcmp_hdr_addr(axi_ras_recc_corr_cnt_ob_pdcmp_hdr_addr)

        ,.ob_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse(ob_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse)
        ,.ob_ras_recc_cnt_ob_pdcmp_data_addr(ob_ras_recc_cnt_ob_pdcmp_data_addr)
        ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse(axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_ob_pdcmp_data_addr(axi_ras_recc_ucorr_cnt_ob_pdcmp_data_addr)

        ,.ob_ras_recc_corr_cnt_ob_pdcmp_data_pulse(ob_ras_recc_corr_cnt_ob_pdcmp_data_pulse)
        ,.axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse(axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse)
        ,.axi_ras_recc_corr_cnt_ob_pdcmp_data_addr(axi_ras_recc_corr_cnt_ob_pdcmp_data_addr)

        ,.ob_ras_recc_ucorr_cnt_ob_ccmp_data_pulse(ob_ras_recc_ucorr_cnt_ob_ccmp_data_pulse)
        ,.ob_ras_recc_cnt_ob_ccmp_data_addr(ob_ras_recc_cnt_ob_ccmp_data_addr)
        ,.axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse(axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr(axi_ras_recc_ucorr_cnt_ob_ccmp_data_addr)

        ,.ob_ras_recc_corr_cnt_ob_ccmp_data_pulse(ob_ras_recc_corr_cnt_ob_ccmp_data_pulse)
        ,.axi_ras_recc_corr_cnt_ob_ccmp_data_pulse(axi_ras_recc_corr_cnt_ob_ccmp_data_pulse)
        ,.axi_ras_recc_corr_cnt_ob_ccmp_data_addr(axi_ras_recc_corr_cnt_ob_ccmp_data_addr)

        ,.ibreq_ras_recc_corr_cnt_ib_sch_p_hdr_pulse(ibreq_ras_recc_corr_cnt_ib_sch_p_hdr_pulse)
        ,.axi_ras_recc_corr_cnt_ib_sch_p_hdr_pulse(axi_ras_recc_corr_cnt_ib_sch_p_hdr_pulse)
        ,.axi_ras_recc_corr_cnt_ib_sch_p_hdr_addr(axi_ras_recc_corr_cnt_ib_sch_p_hdr_addr)
        ,.ibreq_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse(ibreq_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse)
        ,.ibreq_ras_recc_cnt_ib_sch_p_hdr_addr(ibreq_ras_recc_cnt_ib_sch_p_hdr_addr)
        ,.axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse(axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_addr(axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_addr)

        ,.ibreq_ras_recc_corr_cnt_ib_sch_p_data_pulse(ibreq_ras_recc_corr_cnt_ib_sch_p_data_pulse)
        ,.axi_ras_recc_corr_cnt_ib_sch_p_data_pulse(axi_ras_recc_corr_cnt_ib_sch_p_data_pulse)
        ,.axi_ras_recc_corr_cnt_ib_sch_p_data_addr(axi_ras_recc_corr_cnt_ib_sch_p_data_addr)
        ,.ibreq_ras_recc_ucorr_cnt_ib_sch_p_data_pulse(ibreq_ras_recc_ucorr_cnt_ib_sch_p_data_pulse)
        ,.ibreq_ras_recc_cnt_ib_sch_p_data_addr(ibreq_ras_recc_cnt_ib_sch_p_data_addr)
        ,.axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse(axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_ib_sch_p_data_addr(axi_ras_recc_ucorr_cnt_ib_sch_p_data_addr)

        ,.ibreq_ras_recc_corr_cnt_ib_sch_np_hdr_pulse(ibreq_ras_recc_corr_cnt_ib_sch_np_hdr_pulse)
        ,.axi_ras_recc_corr_cnt_ib_sch_np_hdr_pulse(axi_ras_recc_corr_cnt_ib_sch_np_hdr_pulse)
        ,.axi_ras_recc_corr_cnt_ib_sch_np_hdr_addr(axi_ras_recc_corr_cnt_ib_sch_np_hdr_addr)
        ,.ibreq_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse(ibreq_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse)
        ,.ibreq_ras_recc_cnt_ib_sch_np_hdr_addr(ibreq_ras_recc_cnt_ib_sch_np_hdr_addr)
        ,.axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse(axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_addr(axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_addr)

        ,.ibreq_ras_recc_corr_cnt_ib_sch_np_data_pulse(ibreq_ras_recc_corr_cnt_ib_sch_np_data_pulse)
        ,.axi_ras_recc_corr_cnt_ib_sch_np_data_pulse(axi_ras_recc_corr_cnt_ib_sch_np_data_pulse)
        ,.axi_ras_recc_corr_cnt_ib_sch_np_data_addr(axi_ras_recc_corr_cnt_ib_sch_np_data_addr)
        ,.ibreq_ras_recc_ucorr_cnt_ib_sch_np_data_pulse(ibreq_ras_recc_ucorr_cnt_ib_sch_np_data_pulse)
        ,.ibreq_ras_recc_cnt_ib_sch_np_data_addr(ibreq_ras_recc_cnt_ib_sch_np_data_addr)
        ,.axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse(axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr(axi_ras_recc_ucorr_cnt_ib_sch_np_data_addr)
        ,.ibreq_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse(ibreq_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse)
        ,.ibreq_ras_recc_cnt_ib_rreq_c2a_cdc_addr(ibreq_ras_recc_cnt_ib_rreq_c2a_cdc_addr)
        ,.axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse(axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr(axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_addr)

        ,.ibreq_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse(ibreq_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse)
        ,.axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse(axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_pulse)
        ,.axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr(axi_ras_recc_corr_cnt_ib_rreq_c2a_cdc_addr)


        ,.ibreq_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse(ibreq_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse)
        ,.ibreq_ras_recc_cnt_ib_wreq_c2a_cdc_addr(ibreq_ras_recc_cnt_ib_wreq_c2a_cdc_addr)
        ,.axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse(axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr(axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_addr)

        ,.ibreq_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse(ibreq_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse)
        ,.axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse(axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_pulse)
        ,.axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr(axi_ras_recc_corr_cnt_ib_wreq_c2a_cdc_addr)

        ,.mcb_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse(mcb_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse)
        ,.mcb_ras_recc_cnt_ib_mcpl_a2c_cdc_addr(mcb_ras_recc_cnt_ib_mcpl_a2c_cdc_addr)
        ,.axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse(axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_addr(axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_addr)

        ,.mcb_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse(mcb_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse)
        ,.axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse(axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse)
        ,.axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_addr(axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_addr)


        ,.mcb_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse(mcb_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse)
        ,.mcb_ras_recc_cnt_ib_mcpl_sb_addr(mcb_ras_recc_cnt_ib_mcpl_sb_addr)
        ,.axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse(axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse_g)
        ,.axi_ras_recc_ucorr_cnt_ib_mcpl_sb_addr(axi_ras_recc_ucorr_cnt_ib_mcpl_sb_addr)

        ,.mcb_ras_recc_corr_cnt_ib_mcpl_sb_pulse(mcb_ras_recc_corr_cnt_ib_mcpl_sb_pulse)
        ,.axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse(axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse)
        ,.axi_ras_recc_corr_cnt_ib_mcpl_sb_addr(axi_ras_recc_corr_cnt_ib_mcpl_sb_addr)



        ,.mcb_ras_par_ib_mcpl_a2c_dt_pulse(mcb_ras_par_ib_mcpl_a2c_dt_pulse)
        ,.axi_ras_par_ib_mcpl_a2c_dt_pulse(axi_ras_par_ib_mcpl_a2c_dt_pulse_g)





        );

  assign rasdp_dtim_prot_err_inj_mask_intf = '0;

  assign axi_ras_par_ib_mcpl_sb_dt_pulse_g = mcb_ras_par_ib_mcpl_sb_dt_pulse;

   // This avoids RAS.DP counters error polution
   assign {
           axi_ras_recc_ucorr_cnt_npw_sab_pulse,
           axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse,
           axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse,
           axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse,
           axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse,
           axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse,
           axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse,
           axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse,
           axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse,
           axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse,
           axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse,
           axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse,
           axi_ras_par_ib_mcpl_a2c_dt_pulse,
           axi_ras_par_ib_sch_p_ad_pulse,
           axi_ras_par_ib_sch_p_dt_pulse,
           axi_ras_par_ib_sch_np_ad_pulse,
           axi_ras_par_ib_sch_np_dt_pulse,
           axi_ras_par_ib_mcpl_sb_dt_pulse,

           axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse,
           axi_ras_par_ib_mcpl_dt_pulse,
           axi_ras_par_ibwr_dcmp_dt_pulse,
           axi_ras_par_ibwr_dcmp_ad_pulse,
           axi_ras_par_ibrd_dcmp_ad_pulse,
           axi_ras_par_ibwq_mrf_dt_pulse,
           axi_ras_par_ibwq_mrf_ad_pulse,
           axi_ras_par_ibrd_mrf_ad_pulse,
           axi_ras_par_npqdec_ad_pulse,
           axi_ras_par_pqdec_ad_pulse,
           axi_ras_par_swwrap_dt_pulse,
           axi_ras_par_swwrap_ad_pulse,
           axi_ras_par_srwrap_ad_pulse,
           axi_ras_par_swrq_npw_dt_pulse,
           axi_ras_par_swrq_npw_ad_pulse,
           axi_ras_par_slnull_dt_pulse,
           axi_ras_par_slnull_ad_pulse,
           axi_ras_par_ob_np_dcmp_inq_dt_pulse,
           axi_ras_par_ob_p_dcmp_inq_dt_pulse,
           axi_ras_par_ob_cpl_comp_dt_pulse,

           axi_ras_par_c2_ad_pulse,
           axi_ras_par_c2_dt_pulse,
           axi_ras_par_c1_ad_pulse,
           axi_ras_par_c1_dt_pulse
          ,axi_ras_par_rtrgt_p_ad_pulse,
           axi_ras_par_rtrgt_p_dt_pulse,
           axi_ras_par_rtrgt_np_ad_pulse,
           axi_ras_par_rtrgt_np_dt_pulse,
           axi_ras_par_rtrgt_cpl_ad_pulse,
           axi_ras_par_rtrgt_cpl_dt_pulse
           } = {
                axi_ras_recc_ucorr_cnt_npw_sab_pulse_g,
                axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse_g,
                axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse_g,
                axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse_g,
                axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse_g,
                axi_ras_recc_ucorr_cnt_ib_sch_p_hdr_pulse_g,
                axi_ras_recc_ucorr_cnt_ib_sch_p_data_pulse_g,
                axi_ras_recc_ucorr_cnt_ib_sch_np_hdr_pulse_g,
                axi_ras_recc_ucorr_cnt_ib_sch_np_data_pulse_g,
                axi_ras_recc_ucorr_cnt_ib_rreq_c2a_cdc_pulse_g,
                axi_ras_recc_ucorr_cnt_ib_wreq_c2a_cdc_pulse_g,
                axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse_g,
                axi_ras_par_ib_mcpl_a2c_dt_pulse_g,
                axi_ras_par_ib_sch_p_ad_pulse_g,
                axi_ras_par_ib_sch_p_dt_pulse_g,
                axi_ras_par_ib_sch_np_ad_pulse_g,
                axi_ras_par_ib_sch_np_dt_pulse_g,
                axi_ras_par_ib_mcpl_sb_dt_pulse_g,
                axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse_g,
                axi_ras_par_ib_mcpl_dt_pulse_g,
                axi_ras_par_ibwr_dcmp_dt_pulse_g,
                axi_ras_par_ibwr_dcmp_ad_pulse_g,
                axi_ras_par_ibrd_dcmp_ad_pulse_g,
                axi_ras_par_ibwq_mrf_dt_pulse_g,
                axi_ras_par_ibwq_mrf_ad_pulse_g,
                axi_ras_par_ibrd_mrf_ad_pulse_g,
   // Parity in this might have to be changed - (axi_ras_par_npqdec_ad_pulse_g & !axi_ras_slv_if_err_sts.parity.arpyld0 & !axi_ras_slv_if_err_sts.ecc.corr.arpyld0 & !axi_ras_slv_if_err_sts.ecc.uncorr.arpyld0),
               (axi_ras_par_npqdec_ad_pulse_g & !axi_slv_sisb_uncorr_pulse ),
                axi_ras_par_pqdec_ad_pulse_g,
                axi_ras_par_swwrap_dt_pulse_g,
                axi_ras_par_swwrap_ad_pulse_g,
                axi_ras_par_srwrap_ad_pulse_g,
                axi_ras_par_swrq_npw_dt_pulse_g,
                axi_ras_par_swrq_npw_ad_pulse_g,
                axi_ras_par_slnull_dt_pulse_g,
                axi_ras_par_slnull_ad_pulse_g,
                axi_ras_par_ob_np_dcmp_inq_dt_pulse_g,
                axi_ras_par_ob_p_dcmp_inq_dt_pulse_g,
                axi_ras_par_ob_cpl_comp_dt_pulse_g,

                axi_ras_par_c2_ad_pulse_g,
                axi_ras_par_c2_dt_pulse_g,
                axi_ras_par_c1_ad_pulse_g,
                axi_ras_par_c1_dt_pulse_g
               ,axi_ras_par_rtrgt_p_ad_pulse_g,
                axi_ras_par_rtrgt_p_dt_pulse_g,
                axi_ras_par_rtrgt_np_ad_pulse_g,
                axi_ras_par_rtrgt_np_dt_pulse_g,
                axi_ras_par_rtrgt_cpl_ad_pulse_g,
                axi_ras_par_rtrgt_cpl_dt_pulse_g
                } & {
                     18
                     + 6
                     + 3
                     + 6
                     + 8
                     + 5
                     + 2
                     {~cfg_rasdp_err_mode}};

   function automatic [`CC_CORE_DATA_BUS_WD -1:0] swap_data_par;
      input [`CC_CORE_DATA_BUS_WD -1:0]    in_data;
      integer                              i,j;
      reg [`CC_CORE_DATA_BUS_WD -1:0]      i_swap_data_par;
      begin
         i_swap_data_par = {`CC_CORE_DATA_BUS_WD{1'b0}};
         for (i=0; i<(`CC_CORE_DATA_BUS_WD-`PCIE_CORE_DATA_BUS_WD); i=i+1) begin
            for (j=0; j<`CX_RAS_PROT_RANGE; j=j+1) begin
               i_swap_data_par[i*`CX_RAS_PROT_RANGE +j] = in_data[i*`CX_RAS_PROT_RANGE +j +i];
            end
            i_swap_data_par[`CC_CORE_DATA_BUS_WD - (`CC_CORE_DATA_BUS_WD-`PCIE_CORE_DATA_BUS_WD) +i] = in_data[(i+1)*`CX_RAS_PROT_RANGE +i];
         end
         swap_data_par = i_swap_data_par;
      end
   endfunction

   function automatic [63:0] swap_addr_par;
      input [63 + `CX_ADDR_PAR_WD:0]   in_addr;
      integer                          i,j;
      reg [63 + `CX_ADDR_PAR_WD:0]     i_swap_addr_par;
      begin
         i_swap_addr_par = {63 + `CX_ADDR_PAR_WD{1'b0}};
         for (i=0; i<`CX_ADDR_PAR_WD; i=i+1) begin
            for (j=0; j<`CX_RAS_PROT_RANGE; j=j+1) begin
               i_swap_addr_par[i*`CX_RAS_PROT_RANGE +j] = in_addr[i*`CX_RAS_PROT_RANGE +j +i];
            end
            i_swap_addr_par[64 + i] = in_addr[(i+1)*`CX_RAS_PROT_RANGE +i];
         end
         swap_addr_par = i_swap_addr_par[63:0];
      end
   endfunction

   function automatic [`CX_ADDR_PAR_WD-1:0] swap_addr_par_only;
     input [63 + `CX_ADDR_PAR_WD:0]   in_addr;
     integer                          i,j;
     reg [63 + `CX_ADDR_PAR_WD:0]     i_swap_addr_par;
     begin
       i_swap_addr_par = {63 + `CX_ADDR_PAR_WD{1'b0}};
       for (i=0; i<`CX_ADDR_PAR_WD; i=i+1) begin
          for (j=0; j<`CX_RAS_PROT_RANGE; j=j+1) begin
             i_swap_addr_par[i*`CX_RAS_PROT_RANGE +j] = in_addr[i*`CX_RAS_PROT_RANGE +j +i];
          end
          i_swap_addr_par[64 + i] = in_addr[(i+1)*`CX_RAS_PROT_RANGE +i];
       end
       swap_addr_par_only = i_swap_addr_par[63 + `CX_ADDR_PAR_WD:64];
     end
   endfunction

  // ---- Gen6 Rasdp / error manager and RAS CDC
  // -----------------------------------------------------------------------------------------
   localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N);
  
    DWC_pcie_bridge_rasdp_pipe
    
    #(
      .CORE_RASDP_WAKEUP_WD                                (CORE_RASDP_WAKEUP_WD)
     )
    u_rasdp_pipe (
      .core_clk                                            (aux_clk_g    )
      ,.core_rst_n                                         (core_rst_n   )
      ,.core_ras_dp_wake_up                                (core_ras_dp_wake_up)
      ,.mstr_aclk                                          (mstr_aclk_g  )
      ,.mstr_aclk_ug                                       (mstr_aclk    )
      ,.mstr_aresetn                                       (mstr_aresetn )
      ,.mstr_ras_dp_wake_up                                (mstr_ras_dp_wake_up)
      ,.slv_aclk                                           (slv_aclk_g   )
      ,.slv_aclk_ug                                        (slv_aclk     )
      ,.slv_aresetn                                        (slv_aresetn  )
      ,.slv_ras_dp_wake_up                                 (slv_ras_dp_wake_up)
      ,.sif_swrq_swwrap_dt_ras_dp_err_log                  (sif_swrq_swwrap_dt_ras_dp_err_log)
      ,.sif_swrq_swwrap_ad_ras_dp_err_log                  (sif_swrq_swwrap_ad_ras_dp_err_log)
      ,.sif_srrp_srwrap_ad_ras_dp_err_log                  (sif_srrp_srwrap_ad_ras_dp_err_log)
      ,.sif_swrq_dt_ras_dp_err_log                         (sif_swrq_dt_ras_dp_err_log       )
      ,.sif_swrq_ad_ras_dp_err_log                         (sif_swrq_ad_ras_dp_err_log       )
      ,.sif_srsp_rslv_dt_ras_dp_err_log                    (sif_srsp_rslv_dt_ras_dp_err_log  )
      ,.sif_swrq_npw_dt_ras_dp_err_log                     (sif_swrq_npw_dt_ras_dp_err_log   )
      ,.sif_swrq_npw_ad_ras_dp_err_log                     (sif_swrq_npw_ad_ras_dp_err_log   )
      ,.sif_recc_npw_sab_ras_dp_err_log                    (sif_recc_npw_sab_ras_dp_err_log  )
      ,.ob_npdcmp_inq_dt_ras_dp_err_log                    (ob_npdcmp_inq_dt_ras_dp_err_log          )
      ,.ob_recc_cnt_ob_npdcmp_ras_dp_err_log               (ob_recc_cnt_ob_npdcmp_ras_dp_err_log     )
      ,.axi_ob_recc_cnt_ob_ccmp_dt_ras_dp_log              (axi_ob_recc_cnt_ob_ccmp_dt_ras_dp_log    )
      ,.axi_ob_cpl_comp_dt_ras_dp_err_log_g                (axi_ob_cpl_comp_dt_ras_dp_err_log_g      )
      ,.ob_recc_cnt_ob_pdcmp_ras_dp_err_log                (ob_recc_cnt_ob_pdcmp_ras_dp_err_log      )
      ,.ob_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log            (ob_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log  )
      ,.ob_pdcmp_inq_dt_ras_dp_err_log                     (ob_pdcmp_inq_dt_ras_dp_err_log           )
      ,.ob_pdcmp_ad_ras_dp_err_log                         (ob_pdcmp_ad_ras_dp_err_log               )
      ,.ob_npdcmp_ad_ras_dp_err_log                        (ob_npdcmp_ad_ras_dp_err_log              )
      ,.mcb_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log        (mcb_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log     )
      ,.mcb_ib_mcpl_a2c_dt_ras_dp_err_log                  (mcb_ib_mcpl_a2c_dt_ras_dp_err_log  )
      ,.axigm_ibr_rmstr_ad_ras_dp_err_log                  (axigm_ibr_rmstr_ad_ras_dp_err_log  )
      ,.axigm_ibr_wmstr_ad_ras_dp_err_log                  (axigm_ibr_wmstr_ad_ras_dp_err_log  )
      ,.axigm_ibr_wmstr_dt_ras_dp_err_log                  (axigm_ibr_wmstr_dt_ras_dp_err_log  )
      ,.axi_rtrgt_p_ad_ras_dp_err_log                      (axi_rtrgt_p_ad_ras_dp_err_log           )
      ,.axi_rtrgt_p_dt_ras_dp_err_log                      (axi_rtrgt_p_dt_ras_dp_err_log           )
      ,.axi_rtrgt_np_ad_ras_dp_err_log                     (axi_rtrgt_np_ad_ras_dp_err_log          )
      ,.axi_rtrgt_np_dt_ras_dp_err_log                     (axi_rtrgt_np_dt_ras_dp_err_log          )
      ,.axi_rtrgt_cpl_ad_ras_dp_err_log                    (axi_rtrgt_cpl_ad_ras_dp_err_log         )
      ,.axi_rtrgt_cpl_dt_ras_dp_err_log                    (axi_rtrgt_cpl_dt_ras_dp_err_log         )
      ,.axi_ib_sch_p_ad_ras_dp_err_log                     (axi_ib_sch_p_ad_ras_dp_err_log          )
      ,.axi_ib_sch_p_dt_ras_dp_err_log                     (axi_ib_sch_p_dt_ras_dp_err_log          )

      ,.axi_rbyp_ad_ras_dp_err_log_g                       (axi_rbyp_ad_ras_dp_err_log_g            )
      ,.axi_rbyp_dt_ras_dp_err_log_g                       (axi_rbyp_dt_ras_dp_err_log_g            )

      ,.sch_p_data_recc_corr_cnt_ras_dp_err_log            (sch_p_data_recc_corr_cnt_ras_dp_err_log )
      ,.sch_p_hdr_recc_corr_cnt_ras_dp_err_log             (sch_p_hdr_recc_corr_cnt_ras_dp_err_log  )

      ,.axi_ib_sch_np_ad_ras_dp_err_log                    (axi_ib_sch_np_ad_ras_dp_err_log         )
      ,.axi_ib_sch_np_dt_ras_dp_err_log                    (axi_ib_sch_np_dt_ras_dp_err_log         )
      ,.sch_np_data_recc_corr_cnt_ras_dp_err_log           (sch_np_data_recc_corr_cnt_ras_dp_err_log)
      ,.sch_np_hdr_recc_corr_cnt_ras_dp_err_log            (sch_np_hdr_recc_corr_cnt_ras_dp_err_log )

      ,.axi_trgt1_dt_ras_dp_err_log_g                      (axi_trgt1_dt_ras_dp_err_log_g     )
      ,.rdq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log    (rdq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log)
      ,.wrq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log    (wrq_mrf_recc_cnt_ib_rreq_c2a_cdc_ras_dp_err_log)
      ,.axi_mstr_req_rd_ad_ras_dp_err_log_g                (axi_mstr_req_rd_ad_ras_dp_err_log_g            )
      ,.axi_mstr_req_wr_ad_ras_dp_err_log_g                (axi_mstr_req_wr_ad_ras_dp_err_log_g            )
      ,.axi_mstr_req_dt_ras_dp_err_log_g                   (axi_mstr_req_dt_ras_dp_err_log_g               )
      ,.axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log             (axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log         )
      ,.mcb_ib_mcpl_sb_dt_ras_dp_err_log                   (mcb_ib_mcpl_sb_dt_ras_dp_err_log               )
      ,.axi_ibrd_dcmp_ad_ras_dp_err_log                    (axi_ibrd_dcmp_ad_ras_dp_err_log_g       )
      ,.axi_ibwr_dcmp_ad_ras_dp_err_log                    (axi_ibwr_dcmp_ad_ras_dp_err_log_g       )
      ,.mstr_misb_ras_dp_err_log                           (mstr_misb_ras_dp_err_log                )
      ,.axi_sisb_aw_ad_ras_dp_err_log                      (axi_sisb_aw_ad_ras_dp_err_log           )
      ,.axi_sisb_ar_ad_ras_dp_err_log                      (axi_sisb_ar_ad_ras_dp_err_log           )
      ,.axi_sisb_w_dt_ras_dp_err_log                       (axi_sisb_w_dt_ras_dp_err_log            )

      ,.core_clk_ras_dp_err_inj_from_cdm                   (axi_bridge_in_ras_dp_err_inj            )
      ,.axi_c1_dt_ras_dp_err_log_g                         (axi_c1_dt_ras_dp_err_log_g              ) // core_clk u_rasdp
      ,.axi_c2_dt_ras_dp_err_log_g                         (axi_c2_dt_ras_dp_err_log_g              ) // core_clk u_rasdp
      ,.axi_c1_ad_ras_dp_err_log_g                         (axi_c1_ad_ras_dp_err_log_g              ) // core_clk u_rasdp
      ,.axi_c2_ad_ras_dp_err_log_g                         (axi_c2_ad_ras_dp_err_log_g              ) // core_clk u_rasdp
      ,.axi_ib_mcpl_dt_ras_dp_err_log_g                    (axi_ib_mcpl_dt_ras_dp_err_log_g         ) // core_clk u_rasdp
      ,.core_clk_ras_dp_err_log_to_cdm                     ( axi_bridge_out_ras_dp_err_log          )
      ,.core_clk_ras_dp_err_inj                            ( axi_bridge_ras_dp_err_inj_core_clk     )
      ,.ras_dp_err_inj_slv_aclk                            ( ras_dp_err_inj_slv_aclk                )
      ,.ras_dp_err_inj_mstr_aclk                           ( ras_dp_err_inj_mstr_aclk               )
      ,.core_clk_ordrb_ras_dp_err_inj                      ( core_clk_ordrb_ras_dp_err_inj          )
      ,.core_clk_high_freq_ras_dp_err_inj                  ( core_clk_high_freq_ras_dp_err_inj      )
      ,.core_clk_hp_mstr_ras_dp_err_inj                    ( core_clk_hp_mstr_ras_dp_err_inj        )
    );




assign mstr_aw_s.id                        = mstr_aw.id;
assign mstr_aw_s.valid                     = mstr_aw.valid;
assign mstr_aw_s.len                       = mstr_aw.len;
assign mstr_aw_s.size                      = mstr_aw.size;
assign mstr_aw_s.burst                     = mstr_aw.burst;
assign mstr_aw_s.lock                      = mstr_aw.lock;
assign mstr_aw_s.cache                     = mstr_aw.cache;
assign mstr_aw_s.prot                      = mstr_aw.prot;
assign mstr_aw_s.misc_info                 = mstr_aw.misc_info;
assign mstr_aw_s.misc_info_s.last_dcmp_tlp = mstr_aw.misc_info_last_dcmp_tlp;
assign mstr_aw_s.misc_info_s.hdr_34dw      = mstr_aw.misc_info_hdr_34dw;
assign mstr_aw_s.misc_info_s.nw            = mstr_aw.misc_info_nw;
assign mstr_aw_s.misc_info_s.cxlsrc        = mstr_aw.misc_info_cxlsrc;
assign mstr_aw_s.misc_info_s.ats           = mstr_aw.misc_info_ats;
assign mstr_aw_s.misc_info_s.ep            = mstr_aw.misc_info_ep;
assign mstr_aw_s.misc_info_s.dma           = mstr_aw.misc_info_dma;
assign mstr_aw_s.misc_info_s.tlpprfx       = mstr_aw.misc_info_tlpprfx[TLP_PREFIX_WD-1:0];
assign mstr_aw_s.misc_info_s.tph           = mstr_aw.misc_info_tph;
assign mstr_aw_s.misc_info_s.ido           = mstr_aw.misc_info_ido;
assign mstr_aw_s.misc_info_s.dst_segment   = mstr_aw.misc_info_dst_segment;
assign mstr_aw_s.misc_info_s.req_segment   = mstr_aw.misc_info_req_segment;
assign mstr_aw_s.qos                       = mstr_aw.qos;
assign mstr_aw_s.bar                       = mstr_aw.bar;
assign mstr_aw_s.domain                    = mstr_aw.domain;
assign mstr_aw_s.snoop                     = mstr_aw.snoop;
assign mstr_aw_s.atop                      = mstr_aw.atop;
assign mstr_awaddr_s                       = mstr_aw.addr;
assign mstr_aw.ready                       = mstr_awready_s;

assign mstr_ar_s.id                        = mstr_ar.id;
assign mstr_ar_s.valid                     = mstr_ar.valid;
assign mstr_ar_s.len                       = mstr_ar.len;
assign mstr_ar_s.size                      = mstr_ar.size;
assign mstr_ar_s.burst                     = mstr_ar.burst;
assign mstr_ar_s.lock                      = mstr_ar.lock;
assign mstr_ar_s.cache                     = mstr_ar.cache;
assign mstr_ar_s.prot                      = mstr_ar.prot;
assign mstr_ar_s.misc_info                 = mstr_ar.misc_info;
assign mstr_ar_s.misc_info_s.last_dcmp_tlp = mstr_ar.misc_info_last_dcmp_tlp;
assign mstr_ar_s.misc_info_s.nw            = mstr_ar.misc_info_nw;
assign mstr_ar_s.misc_info_s.cxlsrc        = mstr_ar.misc_info_cxlsrc;
assign mstr_ar_s.misc_info_s.ats           = mstr_ar.misc_info_ats;
assign mstr_ar_s.misc_info_s.dma           = mstr_ar.misc_info_dma;
assign mstr_ar_s.misc_info_s.tlpprfx       = mstr_ar.misc_info_tlpprfx[TLP_PREFIX_WD-1:0];
assign mstr_ar_s.misc_info_s.tph           = mstr_ar.misc_info_tph;
assign mstr_ar_s.misc_info_s.ido           = mstr_ar.misc_info_ido;
assign mstr_ar_s.misc_info_s.zeroread      = mstr_ar.misc_info_zeroread;
assign mstr_ar_s.misc_info_s.dst_segment   = mstr_ar.misc_info_dst_segment;
assign mstr_ar_s.misc_info_s.req_segment   = mstr_ar.misc_info_req_segment;
assign mstr_ar_s.qos                       = mstr_ar.qos;
assign mstr_ar_s.bar                       = mstr_ar.bar;
assign mstr_ar_s.domain                    = mstr_ar.domain;
assign mstr_ar_s.snoop                     = mstr_ar.snoop;
assign mstr_araddr_s                       = mstr_ar.addr;
assign mstr_ar.ready                       = mstr_arready_s;

assign mstr_w_s.valid                      = mstr_w.valid;
assign mstr_w_s.last                       = mstr_w.last;
assign mstr_w_s.strb                       = mstr_w.strb;
assign mstr_wdata_s                        = mstr_w.data;
assign mstr_w.ready                        = mstr_wready_s;

assign mstr_r.id                           = mstr_r_s.id;
assign mstr_r.valid                        = mstr_r_s.valid;
assign mstr_r.last                         = mstr_r_s.last;
assign mstr_r.resp                         = mstr_r_s.resp;
assign mstr_r.misc_info                    = mstr_r_s.misc_info;
assign mstr_r.misc_info_cpl_stat           = mstr_r_s.misc_info_s.cpl_stat;
assign mstr_r.data                         = mstr_rdata_s;
assign mstr_rready_s                       = mstr_r.ready;

assign mstr_b.id                           = mstr_b_s.id;
assign mstr_b.valid                        = mstr_b_s.valid;
assign mstr_b.resp                         = mstr_b_s.resp;
assign mstr_b.misc_info_cpl_stat           = mstr_b_s.misc_info_s.cpl_stat;
assign mstr_bready_s                       = mstr_b.ready;

DWC_pcie_axi_misb

  #(.HP_MSTR            (1'b0             ))
 u_axi_misb_wrapper     (
  .mstr_aclk            (mstr_aclk_g      ),
  .mstr_arstn           (mstr_aresetn     ),
 // AW Channel
  .in_aw                (mstr_aw_s        ),
  .in_awaddr            (mstr_awaddr_s    ),
  .in_awready           (mstr_awready     ),
  .out_aw               (mstr_aw_o        ),
  .out_awaddr           (mstr_awaddr      ),
  .out_awready          (mstr_awready_s   ),
 // AR Channel
  .in_ar                (mstr_ar_s        ),
  .in_araddr            (mstr_araddr_s    ),
  .in_arready           (mstr_arready     ),
  .out_ar               (mstr_ar_o        ),
  .out_araddr           (mstr_araddr      ),
  .out_arready          (mstr_arready_s   ),
 // W Channel
  .in_w                 (mstr_w_s         ),
  .in_wdata             (mstr_wdata_s     ),
  .in_wready            (mstr_wready      ),
  .out_w                (mstr_w_o         ),
  .out_wdata            (mstr_wdata       ),
  .out_wready           (mstr_wready_s    ),
 // R Channel
  .in_r                 (mstr_r_i         ),
  .in_rdata             (mstr_rdata       ),
  .in_rready            (mstr_rready_s    ),
  .out_r                (mstr_r_s         ),
  .out_rdata            (mstr_rdata_s     ),
  .out_rready           (mstr_rready      ),
 // B Channel
  .in_b                 (mstr_b_i         ),
  .in_bready            (mstr_bready_s    ),
  .out_b                (mstr_b_s         ),
  .out_bready           (mstr_bready      )
 ,
 // Parity Signals
  .out_awuser           (mstr_awuser      ),
  .out_aruser           (mstr_aruser      ),
  .out_wuser            (mstr_wuser       ),
  .in_ruser             (mstr_ruser       ),
  .in_aw_prfx_par       (mstr_aw.misc_info_tlpprfx[TLP_PREFIX_WD+:`CX_PRFX_PAR_WD] ),
  .in_ar_prfx_par       (mstr_ar.misc_info_tlpprfx[TLP_PREFIX_WD+:`CX_PRFX_PAR_WD] ),
  .out_aw_prfx_par      (mstr_awmisc_info_tlpprfx[TLP_PREFIX_WD+:`CX_PRFX_PAR_WD] ),
  .out_ar_prfx_par      (mstr_armisc_info_tlpprfx[TLP_PREFIX_WD+:`CX_PRFX_PAR_WD] ),
  .err_sts              (mstr_misb_err_sts      )
  ,.err_sts_ras_dp_err_log (mstr_misb_ras_dp_err_log)

  ,.ras_dp_err_inj_mstr_aclk (ras_dp_err_inj_mstr_aclk)
  );
assign mstr_awid = mstr_aw_o.id;
assign mstr_awvalid = mstr_aw_o.valid;
assign mstr_awlen = mstr_aw_o.len;
assign mstr_awsize = mstr_aw_o.size;
assign mstr_awburst = mstr_aw_o.burst;
assign mstr_awlock = mstr_aw_o.lock;
assign mstr_awcache = mstr_aw_o.cache;
assign mstr_awprot = mstr_aw_o.prot;
assign mstr_awmisc_info = mstr_aw_o.misc_info;
assign mstr_awmisc_info_last_dcmp_tlp = mstr_aw_o.misc_info_s.last_dcmp_tlp;
assign mstr_awmisc_info_hdr_34dw = mstr_aw_o.misc_info_s.hdr_34dw;
assign mstr_awmisc_info_nw = mstr_aw_o.misc_info_s.nw;
assign mstr_awmisc_info_cxlsrc = mstr_aw_o.misc_info_s.cxlsrc;
assign mstr_awmisc_info_ats = mstr_aw_o.misc_info_s.ats;
assign mstr_awmisc_info_ep = mstr_aw_o.misc_info_s.ep;
assign mstr_awmisc_info_dma = mstr_aw_o.misc_info_s.dma;
assign mstr_awmisc_info_tlpprfx[0+:TLP_PREFIX_WD] = mstr_aw_o.misc_info_s.tlpprfx;
assign mstr_awmisc_info_tph = mstr_aw_o.misc_info_s.tph;
assign mstr_awmisc_info_ido = mstr_aw_o.misc_info_s.ido;
assign mstr_awmisc_info_dst_segment = mstr_aw_o.misc_info_s.dst_segment;
assign mstr_awmisc_info_req_segment = mstr_aw_o.misc_info_s.req_segment;
assign mstr_awqos = mstr_aw_o.qos;
assign mstr_awbar = mstr_aw_o.bar;
assign mstr_awdomain = mstr_aw_o.domain;
assign mstr_awsnoop = mstr_aw_o.snoop;
assign mstr_awatop = mstr_aw_o.atop;
assign mstr_arid = mstr_ar_o.id;
assign mstr_arvalid = mstr_ar_o.valid;
assign mstr_arlen = mstr_ar_o.len;
assign mstr_arsize = mstr_ar_o.size;
assign mstr_arburst = mstr_ar_o.burst;
assign mstr_arlock = mstr_ar_o.lock;
assign mstr_arcache = mstr_ar_o.cache;
assign mstr_arprot = mstr_ar_o.prot;
assign mstr_armisc_info = mstr_ar_o.misc_info;
assign mstr_armisc_info_last_dcmp_tlp = mstr_ar_o.misc_info_s.last_dcmp_tlp;
assign mstr_armisc_info_nw = mstr_ar_o.misc_info_s.nw;
assign mstr_armisc_info_cxlsrc = mstr_ar_o.misc_info_s.cxlsrc;
assign mstr_armisc_info_ats = mstr_ar_o.misc_info_s.ats;
assign mstr_armisc_info_dma = mstr_ar_o.misc_info_s.dma;
assign mstr_armisc_info_tlpprfx[0+:TLP_PREFIX_WD] = mstr_ar_o.misc_info_s.tlpprfx;
assign mstr_armisc_info_tph = mstr_ar_o.misc_info_s.tph;
assign mstr_armisc_info_ido = mstr_ar_o.misc_info_s.ido;
assign mstr_armisc_info_zeroread = mstr_ar_o.misc_info_s.zeroread;
assign mstr_armisc_info_dst_segment = mstr_ar_o.misc_info_s.dst_segment;
assign mstr_armisc_info_req_segment = mstr_ar_o.misc_info_s.req_segment;
assign mstr_arqos = mstr_ar_o.qos;
assign mstr_arbar = mstr_ar_o.bar;
assign mstr_ardomain = mstr_ar_o.domain;
assign mstr_arsnoop = mstr_ar_o.snoop;
 assign mstr_wvalid = mstr_w_o.valid;
 assign mstr_wlast = mstr_w_o.last;
 assign mstr_wstrb = mstr_w_o.strb;
 assign mstr_r_i = '{
                         id          : mstr_rid,
                         valid       : mstr_rvalid,
                         last        : mstr_rlast,
                         resp        : mstr_rresp,
                         misc_info   : mstr_rmisc_info,
                         misc_info_s : '{
                                      cpl_stat : mstr_rmisc_info_cpl_stat
                         }
 };
 assign mstr_b_i = '{
                         id          : mstr_bid,
                         valid       : mstr_bvalid,
                         resp        : mstr_bresp,
                         misc_info_s : '{
                                      cpl_stat : mstr_bmisc_info_cpl_stat
                         }
 };

DWC_pcie_axi_sisb

#(
  .slave_aw (pkg_axi_slv_aw_s),
  .slave_ar (pkg_axi_slv_ar_s),
  .slave_w  (pkg_axi_slv_w_s ),
  .slave_r  (pkg_axi_slv_r_s ),
  .slave_b  (pkg_axi_slv_b_s )
) u_axi_sisb_wrapper (
   .slv_aclk              (slv_aclk_g      )
  ,.slv_arstn             (slv_aresetn     )
 // AW Channel
  ,.in_aw                 (slv_aw_i        )
  ,.in_awaddr             (slv_awaddr      )
  ,.in_awready            (slv_awready_s   )
  ,.out_aw                (slv_aw_s        )
  ,.out_awaddr            (slv_awaddr_s    )
  ,.out_awready           (slv_awready     )
 // AR Channel
  ,.in_ar                 (slv_ar_i        )
  ,.in_araddr             (slv_araddr      )
  ,.in_arready            (slv_arready_s   )
  ,.out_ar                (slv_ar_s        )
  ,.out_araddr            (slv_araddr_s    )
  ,.out_arready           (slv_arready     )
 // W Channel
  ,.in_w                  (slv_w_i         )
  ,.in_wdata              (slv_wdata       )
  ,.in_wready             (slv_wready_s    )
  ,.out_w                 (slv_w_s         )
  ,.out_wdata             (slv_wdata_s     )
  ,.out_wready            (slv_wready      )
 // R Channel
  ,.in_r                  (slv_r_s         )
  ,.in_rdata              (slv_rdata_s     )
  ,.in_rready             (slv_rready      )
  ,.out_r                 (slv_r_o         )
  ,.out_rdata             (slv_rdata       )
  ,.out_rready            (slv_rready_s    )
 // B Channel
  ,.in_b                  (slv_b_s         )
  ,.in_bready             (slv_bready      )
  ,.out_b                 (slv_b_o         )
  ,.out_bready            (slv_bready_s    )

 // Parity Signals
  ,.in_awuser             (slv_awuser      )
  ,.in_aruser             (slv_aruser      )
  ,.in_wuser              (slv_wuser       )
  ,.out_ruser             (slv_ruser       )
  ,.out_aw_prfx_par       (slv_awmisc_info_tlpprfx_par )
  ,.out_ar_prfx_par       (slv_armisc_info_tlpprfx_par )
  ,.in_aw_prfx_par        (slv_awmisc_info_tlpprfx[TLP_PREFIX_WD+:`CX_PRFX_PAR_WD] )
  ,.in_ar_prfx_par        (slv_armisc_info_tlpprfx[TLP_PREFIX_WD+:`CX_PRFX_PAR_WD] )
  ,.err_sts               (slv_sisb_err_sts      )
  ,.axi_sisb_aw_ad_ras_dp_err_log(axi_sisb_aw_ad_ras_dp_err_log)
  ,.axi_sisb_ar_ad_ras_dp_err_log(axi_sisb_ar_ad_ras_dp_err_log)
  ,.axi_sisb_w_dt_ras_dp_err_log (axi_sisb_w_dt_ras_dp_err_log)
  ,.ras_dp_err_inj_slv_aclk (ras_dp_err_inj_slv_aclk)
  );
assign slv_aw_i = '{
                          id          : slv_awid,
                          valid       : slv_awvalid,
                          len         : slv_awlen,
                          size        : slv_awsize,
                          burst       : slv_awburst,
                          lock        : slv_awlock,
                          cache       : slv_awcache,
                          prot        : slv_awprot,
                          misc_info   : slv_awmisc_info,
                          misc_info_s : '{
                                       hdr_34dw     : slv_awmisc_info_hdr_34dw
                                      ,nw           : slv_awmisc_info_nw
                                      ,ats          : slv_awmisc_info_ats
                                      ,tlpprfx      : slv_awmisc_info_tlpprfx[0+:TLP_PREFIX_WD]
                                      ,p_tag        : slv_awmisc_info_p_tag
                                      ,tph          : slv_awmisc_info_tph
                                      ,atu_bypass   : slv_awmisc_info_atu_bypass
                                      ,ido          : slv_awmisc_info_ido
                                      ,dst_segment  : slv_awmisc_info_dst_segment
                          }
                         ,qos         : slv_awqos
                         ,bar         : slv_awbar
                         ,domain      : slv_awdomain
                         ,snoop       : slv_awsnoop
                         ,atop        : slv_awatop
};
assign slv_ar_i = '{
                          id          : slv_arid,
                          valid       : slv_arvalid,
                          len         : slv_arlen,
                          size        : slv_arsize,
                          burst       : slv_arburst,
                          lock        : slv_arlock,
                          cache       : slv_arcache,
                          prot        : slv_arprot,
                          misc_info   : slv_armisc_info
                          ,misc_info_s : slv_armisc_info_aux
                         ,qos         : slv_arqos
                         ,bar         : slv_arbar
                         ,domain      : slv_ardomain
                         ,snoop       : slv_arsnoop
};
assign slv_armisc_info_aux.nw = slv_armisc_info_nw;
assign slv_armisc_info_aux.ats = slv_armisc_info_ats;
assign slv_armisc_info_aux.tlpprfx = slv_armisc_info_tlpprfx[0+:TLP_PREFIX_WD];
assign slv_armisc_info_aux.tph = slv_armisc_info_tph;
assign slv_armisc_info_aux.atu_bypass = slv_armisc_info_atu_bypass;
assign slv_armisc_info_aux.ido = slv_armisc_info_ido;
assign slv_armisc_info_aux.dst_segment = slv_armisc_info_dst_segment;
assign slv_w_i = '{
                          valid       : slv_wvalid,
                          last        : slv_wlast,
                          strb        : slv_wstrb,
                          misc_info_s : '{
                                       ep         : slv_wmisc_info_ep,
                                       silentDrop : slv_wmisc_info_silentDrop
                          }
};
assign slv_rid        = slv_r_o.id        ;
assign slv_rvalid     = slv_r_o.valid     ;
assign slv_rlast      = slv_r_o.last      ;
assign slv_rresp      = slv_r_o.resp      ;
assign slv_rmisc_info = slv_r_o.misc_info ;
assign slv_rmisc_info_ido = slv_r_o.misc_info_s.ido;
assign slv_rmisc_info_dst_segment = slv_r_o.misc_info_s.dst_segment;
assign slv_rmisc_info_cpl_segment = slv_r_o.misc_info_s.cpl_segment;
 assign slv_bid        = slv_b_o.id        ;
 assign slv_bvalid     = slv_b_o.valid     ;
 assign slv_bresp      = slv_b_o.resp      ;
 assign slv_bmisc_info = slv_b_o.misc_info ;
assign slv_bmisc_info_dst_segment = slv_b_o.misc_info_s.dst_segment;
assign slv_bmisc_info_cpl_segment = slv_b_o.misc_info_s.cpl_segment;




  assign mstr_rasdp_err_mode = rasdp_mstr_rasdp_err_mode;
  assign slv_rasdp_err_mode  = rasdp_slv_rasdp_err_mode;


  //--------------------------------------------------------------------
  // DTIM RAS Error Reporting and Injection
  //--------------------------------------------------------------------



`ifndef SYNTHESIS
`endif //  `ifndef SYNTHESIS

`endif // !UTB_NATIVE_AXI

endmodule
