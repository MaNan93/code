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
// ---  RCS information: ARCT generated file. Do not manually edit. (generator -> process_rtl.sh)
// ---    $DateTime: 2024/01/26 07:05:22 $
// ---    $Revision: #220 $
// ---    $Id: //dwh/pcie_iip/main/DWC_pcie/DWC_pcie_ctl/src/DWC_pcie_ctl.sv#220 $
// -------------------------------------------------------------------------

//==============================================================================
// Start License Usage
//==============================================================================
// Key Used   : DWC-PCIE                      (IP access)
// Key NotUsed: DWC-PCIE-G2-STND-N-SRC        (Add-on feature access: DWC PCIe 2.0 Standard License)
// Key NotUsed: DWC-PCIE-G2-PLUS-N-SRC        (Add-on feature access: DWC PCIe 2.0 Plus License)
// Key NotUsed: DWC-PCIE-G2-PREM-N-SRC        (Add-on feature access: DWC PCIe 2.0 Premium License)
// Key NotUsed: DWC-PCIE-G2-STND-A-SRC        (Add-on feature access: DWC PCIe 2.0 Standard AMBA License)
// Key NotUsed: DWC-PCIE-G2-PLUS-A-SRC        (Add-on feature access: DWC PCIe 2.0 Plus AMBA License)
// Key NotUsed: DWC-PCIE-G2-PREM-A-SRC        (Add-on feature access: DWC PCIe 2.0 Premium AMBA License)
// Key NotUsed: DWC-PCIE-G3-STND-N-SRC        (Add-on feature access: DWC PCIe 3.0 Standard License)
// Key NotUsed: DWC-PCIE-G3-PLUS-N-SRC        (Add-on feature access: DWC PCIe 3.0 Plus License)
// Key NotUsed: DWC-PCIE-G3-PREM-N-SRC        (Add-on feature access: DWC PCIe 3.0 Premium License)
// Key NotUsed: DWC-PCIE-G3-STND-A-SRC        (Add-on feature access: DWC PCIe 3.0 Standard AMBA License)
// Key NotUsed: DWC-PCIE-G3-PLUS-A-SRC        (Add-on feature access: DWC PCIe 3.0 Plus AMBA License)
// Key NotUsed: DWC-PCIE-G3-PREM-A-SRC        (Add-on feature access: DWC PCIe 3.0 Premium AMBA License)
// Key NotUsed: DWC-PCIE-G4-STND-N-SRC        (Add-on feature access: DWC PCIe 4.0 Standard License)
// Key NotUsed: DWC-PCIE-G4-PLUS-N-SRC        (Add-on feature access: DWC PCIe 4.0 Plus License)
// Key NotUsed: DWC-PCIE-G4-PREM-N-SRC        (Add-on feature access: DWC PCIe 4.0 Premium License)
// Key NotUsed: DWC-PCIE-G4-STND-A-SRC        (Add-on feature access: DWC PCIe 4.0 Standard AMBA License)
// Key NotUsed: DWC-PCIE-G4-PLUS-A-SRC        (Add-on feature access: DWC PCIe 4.0 Plus AMBA License)
// Key NotUsed: DWC-PCIE-G4-PREM-A-SRC        (Add-on feature access: DWC PCIe 4.0 Premium AMBA License)
// Key NotUsed: DWC-PCIE-G5-STND-N-SRC        (Add-on feature access: DWC PCIe 5.0 Standard License)
// Key NotUsed: DWC-PCIE-G5-PLUS-N-SRC        (Add-on feature access: DWC PCIe 5.0 Plus License)
// Key NotUsed: DWC-PCIE-G5-PREM-N-SRC        (Add-on feature access: DWC PCIe 5.0 Premium License)
// Key NotUsed: DWC-PCIE-G5-STND-A-SRC        (Add-on feature access: DWC PCIe 5.0 Standard AMBA License)
// Key NotUsed: DWC-PCIE-G5-PLUS-A-SRC        (Add-on feature access: DWC PCIe 5.0 Plus AMBA License)
// Key NotUsed: DWC-PCIE-G5-PREM-A-SRC        (Add-on feature access: DWC PCIe 5.0 Premium AMBA License)
// Key NotUsed: DWC-PCIE-G6-PREM-N-SRC        (Add-on feature access: DWC PCIe 6.0 Premium License)
// Key NotUsed: DWC-PCIE-G6-PREM-A-SRC        (Add-on feature access: DWC PCIe 6.0 Premium AMBA License)
// Key NotUsed: DWC-PCIE-G2-PREM-N-V2-SRC     (Add-on feature access: DWC PCIe 2.0 Premium II License)
// Key NotUsed: DWC-PCIE-G2-STND-A-V2-SRC     (Add-on feature access: DWC PCIe 2.0 Standard AMBA II License)
// Key NotUsed: DWC-PCIE-G2-PLUS-A-V2-SRC     (Add-on feature access: DWC PCIe 2.0 Plus AMBA II License)
// Key NotUsed: DWC-PCIE-G2-PREM-A-V2-SRC     (Add-on feature access: DWC PCIe 2.0 Premium AMBA II License)
// Key NotUsed: DWC-PCIE-G3-PREM-N-V2-SRC     (Add-on feature access: DWC PCIe 3.0 Premium II License)
// Key NotUsed: DWC-PCIE-G3-STND-A-V2-SRC     (Add-on feature access: DWC PCIe 3.0 Standard AMBA II License)
// Key NotUsed: DWC-PCIE-G3-PLUS-A-V2-SRC     (Add-on feature access: DWC PCIe 3.0 Plus AMBA II License)
// Key NotUsed: DWC-PCIE-G3-PREM-A-V2-SRC     (Add-on feature access: DWC PCIe 3.0 Premium AMBA II License)
// Key NotUsed: DWC-PCIE-G4-PREM-N-V2-SRC     (Add-on feature access: DWC PCIe 4.0 Premium II License)
// Key NotUsed: DWC-PCIE-G4-STND-A-V2-SRC     (Add-on feature access: DWC PCIe 4.0 Standard AMBA II License)
// Key NotUsed: DWC-PCIE-G4-PLUS-A-V2-SRC     (Add-on feature access: DWC PCIe 4.0 Plus AMBA II License)
// Key NotUsed: DWC-PCIE-G4-PREM-A-V2-SRC     (Add-on feature access: DWC PCIe 4.0 Premium AMBA II License)
// Key NotUsed: DWC-PCIE-G5-PREM-N-V2-SRC     (Add-on feature access: DWC PCIe 5.0 Premium II License)
// Key NotUsed: DWC-PCIE-G5-STND-A-V2-SRC     (Add-on feature access: DWC PCIe 5.0 Standard AMBA II License)
// Key NotUsed: DWC-PCIE-G5-PLUS-A-V2-SRC     (Add-on feature access: DWC PCIe 5.0 Plus AMBA II License)
// Key NotUsed: DWC-PCIE-G5-PREM-A-V2-SRC     (Add-on feature access: DWC PCIe 5.0 Premium AMBA II License)
// Key NotUsed: DWC-AP-PCIE-G2-PREM-N-SRC     (Add-on feature access: DWC AP PCIe 2.0 Premium License)
// Key NotUsed: DWC-AP-PCIE-G2-PREM-A-SRC     (Add-on feature access: DWC AP PCIe 2.0 Premium AMBA License)
// Key NotUsed: DWC-AP-PCIE-G3-PREM-N-SRC     (Add-on feature access: DWC AP PCIe 3.0 Premium License)
// Key NotUsed: DWC-AP-PCIE-G3-PREM-A-SRC     (Add-on feature access: DWC AP PCIe 3.0 Premium AMBA License)
// Key NotUsed: DWC-AP-PCIE-G4-PREM-N-SRC     (Add-on feature access: DWC AP PCIe 4.0 Premium License)
// Key NotUsed: DWC-AP-PCIE-G4-PREM-A-SRC     (Add-on feature access: DWC AP PCIe 4.0 Premium AMBA License)
// Key NotUsed: DWC-AP-PCIE-G5-PREM-N-SRC     (Add-on feature access: DWC AP PCIe 5.0 Premium License)
// Key NotUsed: DWC-AP-PCIE-G5-PREM-A-SRC     (Add-on feature access: DWC AP PCIe 5.0 Premium AMBA License)
// Key NotUsed: DWC-AP-PCIE-G2-PREM-N-V2-SRC  (Add-on feature access: DWC AP PCIe 2.0 Premium II License)
// Key NotUsed: DWC-AP-PCIE-G2-PREM-A-V2-SRC  (Add-on feature access: DWC AP PCIe 2.0 Premium AMBA II License)
// Key NotUsed: DWC-AP-PCIE-G3-PREM-N-V2-SRC  (Add-on feature access: DWC AP PCIe 3.0 Premium II License)
// Key NotUsed: DWC-AP-PCIE-G3-PREM-A-V2-SRC  (Add-on feature access: DWC AP PCIe 3.0 Premium AMBA II License)
// Key NotUsed: DWC-AP-PCIE-G4-PREM-N-V2-SRC  (Add-on feature access: DWC AP PCIe 4.0 Premium II License)
// Key NotUsed: DWC-AP-PCIE-G4-PREM-A-V2-SRC  (Add-on feature access: DWC AP PCIe 4.0 Premium AMBA II License)
// Key NotUsed: DWC-AP-PCIE-G5-PREM-N-V2-SRC  (Add-on feature access: DWC AP PCIe 5.0 Premium II License)
// Key NotUsed: DWC-AP-PCIE-G5-PREM-A-V2-SRC  (Add-on feature access: DWC AP PCIe 5.0 Premium AMBA II License)
// Key NotUsed: DWC-AC-PCIE-G2-PREM-N-SRC     (Add-on feature access: DWC AC PCIe 2.0 Premium License)
// Key NotUsed: DWC-AC-PCIE-G2-PREM-A-SRC     (Add-on feature access: DWC AC PCIe 2.0 Premium AMBA License)
// Key NotUsed: DWC-AC-PCIE-G3-PREM-N-SRC     (Add-on feature access: DWC AC PCIe 3.0 Premium License)
// Key NotUsed: DWC-AC-PCIE-G3-PREM-A-SRC     (Add-on feature access: DWC AC PCIe 3.0 Premium AMBA License)
// Key NotUsed: DWC-AC-PCIE-G4-PREM-N-SRC     (Add-on feature access: DWC AC PCIe 4.0 Premium License)
// Key NotUsed: DWC-AC-PCIE-G4-PREM-A-SRC     (Add-on feature access: DWC AC PCIe 4.0 Premium AMBA License)
// Key NotUsed: DWC-AC-PCIE-G5-PREM-N-SRC     (Add-on feature access: DWC AC PCIe 5.0 Premium License)
// Key NotUsed: DWC-AC-PCIE-G5-PREM-A-SRC     (Add-on feature access: DWC AC PCIe 5.0 Premium AMBA License)
// Key NotUsed: DWC-CCIX-G25-PREM-N-V2-SRC    (Add-on feature access: DWC CCIX Premium 25G II License)
// Key NotUsed: DWC-CCIX-G25-PREM-A-V2-SRC    (Add-on feature access: DWC CCIX Premium 25G AMBA II License)
// Key NotUsed: DWC-CCIX-G32-PREM-N-V2-SRC    (Add-on feature access: DWC CCIX Premium 32G II License)
// Key NotUsed: DWC-CCIX-G32-PREM-A-V2-SRC    (Add-on feature access: DWC CCIX Premium 32G AMBA II License)
// Key NotUsed: DWC-USB4-PCIE-PREM-N-SRC      (Add-on feature access: DWC USB4 PCIe Premium License)
// Key NotUsed: DWC-USB4-PCIE-PREM-A-SRC      (Add-on feature access: DWC USB4 PCIe Premium AMBA License)
// Key NotUsed: DWC-PCIE-EEP-PREM-N-SRC       (Add-on feature access: DWC EEP PCIe Premium License)
// Key NotUsed: DWC-PCIE-EEP-PREM-A-SRC       (Add-on feature access: DWC EEP PCIe Premium AMBA License)
// Key NotUsed: DWC-PCIE-G4-PREM-A-HPC-SRC    (Add-on feature access: DWC PCIe 4.0 Premium AMBA HPC License)
// Key NotUsed: DWC-PCIE-G5-PREM-A-HPC-SRC    (Add-on feature access: DWC PCIe 5.0 Premium AMBA HPC License)
// Key NotUsed: DWC-PCIE-G6-PREM-A-HPC-SRC    (Add-on feature access: DWC PCIe 6.0 Premium AMBA HPC License)
// Key NotUsed: DWC-CXL-20-PREM-N-SRC         (Add-on feature access: DWC CXL 2.0 Premium License)
// Key NotUsed: DWC-CXL-20-PREM-A-SRC         (Add-on feature access: DWC CXL 2.0 Premium AMBA License)
// Key NotUsed: DWC-CXL-30-PREM-N-SRC         (Add-on feature access: DWC CXL 3.0 Premium License)
// Key Used   : DWC-CXL-30-PREM-A-SRC         (Add-on feature access: DWC CXL 3.0 Premium AMBA License)
// Key NotUsed: DWC-CXL-20-PREM-A-HPC-SRC     (Add-on feature access: DWC CXL 2.0 Premium AMBA HPC License)
// Key NotUsed: DWC-CXL-30-PREM-A-HPC-SRC     (Add-on feature access: DWC CXL 3.0 Premium AMBA HPC License)
// Key NotUsed: DWC-PCIE-G5-PREM-A-HPC-V2-SRC (Add-on feature access: DWC PCIe 5.0 Premium AMBA HPC II License)
// Key NotUsed: DWC-PCIE-G6-PREM-A-HPC-V2-SRC (Add-on feature access: DWC PCIe 6.0 Premium AMBA HPC II License)
// Key NotUsed: DWC-CXL-20-PREM-A-HPC-V2-SRC  (Add-on feature access: DWC CXL 2.0 Premium AMBA HPC II License)
// Key NotUsed: DWC-CXL-30-PREM-A-HPC-V2-SRC  (Add-on feature access: DWC CXL 3.0 Premium AMBA HPC II License)
// Key NotUsed: DWC-PCIE-G4-SECURITY          (Add-on feature access: DWC PCIE 4.0 Security Interface Add-On License)
// Key NotUsed: DWC-PCIE-G5-SECURITY          (Add-on feature access: DWC PCIE 5.0 Security Interface Add-On License)
// Key NotUsed: DWC-PCIE-G6-SECURITY          (Add-on feature access: DWC PCIE 6.0 Security Interface Add-On License)
// Key NotUsed: DWC-CXL-20-SECURITY           (Add-on feature access: DWC CXL 2.0 Security Interface Add-On License)
// Key NotUsed: DWC-CXL-30-SECURITY           (Add-on feature access: DWC CXL 3.0 Security Interface Add-On License)
// Key NotUsed: DWC-PCIE-SW-FLOWTHROUGH       (Add-on feature access: DWC Encrypted Packet Flowthough Add-On License)
// Key NotUsed: DWC_UCIe_CXL3                 (Add-on feature access: DWC UCIe CTRL CXL3 Add-On License)
// Key NotUsed: DWC-UCIe-CXL3-HPC-SRC         (Add-on feature access: DWC UCIe CTRL CXL3 HPC Add-On License)
//==============================================================================
// End License Usage
//==============================================================================

//==============================================================================
// Start Prime Profile Usage
//==============================================================================
// Tag        : DWC_PCIE_PP_GEN6_05
// Label      : EA Release - Not for Tapeout
// Description: Gen6 RC/DM 
// EarlyAccess: No
//==============================================================================
// End Prime Profile Usage
//==============================================================================
// -----------------------------------------------------------------------------
// --- Module description:  This is for top-level dual mode/end device/root complex/switch application.
// --- Top level modules:
// --- * radm_dm        : Rcvd ADM for dual-mode application
// --- * radm_ep        : Rcvd ADM for end-point application
// --- * radm_rc        : Rcvd ADM for root application
// --- * radm_sw        : Rcvd ADM for switch application
// --- * xadm           : Txmt ADM
// --- * cx_pl          : Basic PCI Express Functionality: Layer1, Layer2 and Layer3
// --- * cdm            : Type 0 CDM
// --- * lbc            : Local bus controller
// --- * pm_ctrl        : Power management running at Aux clock
// --- * msg_gen        : Message TLP Generation
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

`include "DWC_pcie_ctl_pkg.svh"
`include "Cdm/cdm_pkg.svh"
`include "power_management/DWC_pcie_pm_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Spif/pkg/spif_pkg.svh"

module DWC_pcie_ctl
import cdm_pkg::ltim_ordrb_msigic_error_s;
import cdm_pkg::app_error_s;
import DWC_pcie_ctl_pkg::xali_pkt_t;
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
import DWC_pcie_core_pkg::pm_cdm_state_trans_track_t;
import DWC_pcie_pm_pkg::usp_link_fsm_state_e;
import DWC_pcie_pm_pkg::dsp_link_fsm_state_e;
import DWC_pcie_core_pkg::ltssm_state_e;
  #(

// module parameter port list
    parameter INST = 0
    )

                   (
  // list of port declarations

    output                           ras_error_tracer_pending,
    output                           ras_dp_unc_err,
    output                           ras_dp_cor_err,
    output                           ras_ram_unc_err,
    output                           ras_ram_cor_err,

    input                           test_clk_en,
    input                           test_rst_en,

    // Master interfaces of AXI
    output  [`CC_MSTR_BUS_ID_WIDTH-1:0]        mstr_awid,
    output                           mstr_awvalid,


    output  [`MASTER_BUS_ADDR_WIDTH -1:0]      mstr_awaddr,
    output  [`CC_MSTR_AW_USER_WIDTH -1:0]     mstr_awuser,
    output  [`CC_MSTR_BURST_LEN_PW -1:0] mstr_awlen,
    output  [2:0]                    mstr_awsize,
    output  [1:0]                    mstr_awburst,
    output  [`CC_AXI_LOCK_WIDTH-1:0]       mstr_awlock,
    output  [3:0]                    mstr_awcache,
    output  [2:0]                    mstr_awprot,
    input                            mstr_awready,
    output  [`MSTR_MISC_INFO_PW -1:0] mstr_awmisc_info,
    output                           mstr_awmisc_info_last_dcmp_tlp,
    output  [63:0]                   mstr_awmisc_info_hdr_34dw,
    output  [`CX_AXI_PRFX_WIDTH-1:0]         mstr_awmisc_info_tlpprfx,
    output  [10:0]                   mstr_awmisc_info_tph,
    output [`CC_NUM_DMA_RD_CHAN_WIDTH+`DC_DMA_TYPE_WIDTH-1:0] mstr_awmisc_info_dma,
    output                           mstr_awmisc_info_nw,
    output                           mstr_awmisc_info_cxlsrc,
    output  [1:0]                    mstr_awmisc_info_ats,
    output                           mstr_awmisc_info_ep,
    output                           mstr_awmisc_info_ido,
    
    
    output [8:0]                      mstr_awmisc_info_dst_segment,
    output [8:0]                      mstr_awmisc_info_req_segment,
    output  [3:0]                    mstr_awqos,
    output  [1:0]                    mstr_awbar,
    output  [1:0]                    mstr_awdomain,
    output  [`CC_AXIJ_DMWR_VALUE *2+2:0]  mstr_awsnoop,
    output  [5:0]                    mstr_awatop,
    input                            mstr_wready,
    output  [`MASTER_BUS_DATA_WIDTH -1:0]      mstr_wdata,
    output  [`CC_MSTR_W_USER_WIDTH -1:0]     mstr_wuser,
    output  [`CC_MSTR_BUS_WSTRB_WIDTH -1:0]     mstr_wstrb,
    output                           mstr_wlast,
    output                           mstr_wvalid,



    output                           mstr_bready,
    input   [`CC_MSTR_BUS_ID_WIDTH-1:0]        mstr_bid,
    input                            mstr_bvalid,
    input   [`CC_AXIJ_DMWR_VALUE+1:0]  mstr_bresp,



    input   [2:0]                    mstr_bmisc_info_cpl_stat,



    output  [`CC_MSTR_BUS_ID_WIDTH-1:0]        mstr_arid,
    output                           mstr_arvalid,


    output  [`MASTER_BUS_ADDR_WIDTH -1:0]      mstr_araddr,
    output  [`CC_MSTR_AR_USER_WIDTH -1:0]     mstr_aruser,
    output  [`CC_MSTR_BURST_LEN_PW -1:0] mstr_arlen,
    output  [2:0]                    mstr_arsize,
    output  [1:0]                    mstr_arburst,
    output  [`CC_AXI_LOCK_WIDTH-1:0]       mstr_arlock,
    output  [3:0]                    mstr_arcache,
    output  [2:0]                    mstr_arprot,
    output                           mstr_rready,
    output  [`MSTR_MISC_INFO_PW -1:0] mstr_armisc_info,
    output               mstr_armisc_info_last_dcmp_tlp,
    output  [`CX_AXI_PRFX_WIDTH-1:0]         mstr_armisc_info_tlpprfx,
    output  [10:0]                   mstr_armisc_info_tph,
    output  [`CC_NUM_DMA_MAX_CHAN_WIDTH+`DC_DMA_TYPE_WIDTH-1:0] mstr_armisc_info_dma,
    output                           mstr_armisc_info_nw,
    output                           mstr_armisc_info_cxlsrc,
    output  [1:0]                    mstr_armisc_info_ats,
    output                           mstr_armisc_info_ido,
    output                           mstr_armisc_info_zeroread,
    output [8:0]                      mstr_armisc_info_dst_segment,
    output [8:0]                      mstr_armisc_info_req_segment,
    input                            mstr_arready,
    output  [3:0]                    mstr_arqos,
    output  [1:0]                    mstr_arbar,
    output  [1:0]                    mstr_ardomain,
    output  [3:0]                    mstr_arsnoop,
    input   [`CC_MSTR_BUS_ID_WIDTH-1:0]        mstr_rid,
    input                            mstr_rvalid,
    input                            mstr_rlast,
    input   [`MASTER_BUS_DATA_WIDTH -1:0]      mstr_rdata,
    input   [`CC_MSTR_R_USER_WIDTH -1:0]     mstr_ruser,
    input   [1:0]                    mstr_rresp,
    input   [`MSTR_RESP_MISC_INFO_PW -1:0] mstr_rmisc_info,



    input   [2:0]                    mstr_rmisc_info_cpl_stat,

 
    output                           mstr_csysack,
    output                           mstr_cactive,
    input                            mstr_csysreq,
    output                           mstr_aclk_g,
    input                            mstr_aclk,
    output                           mstr_aresetn,
    output                           mstr_rasdp_err_mode,

    input   [`CC_SLV_BUS_ID_WIDTH -1:0] slv_awid,
    input   [`SLAVE_BUS_ADDR_WIDTH -1:0] slv_awaddr,
    input   [`CC_SLV_AW_USER_WIDTH -1:0] slv_awuser,
    input   [`CC_SLV_BURST_LEN_PW -1:0]  slv_awlen,
    input   [2:0]                    slv_awsize,
    input   [1:0]                    slv_awburst,
    input   [`CC_AXI_LOCK_WIDTH-1:0]        slv_awlock,
    input   [3:0]                    slv_awcache,
    input   [2:0]                    slv_awprot,
    input                            slv_awvalid,
    output                           slv_awready,
    input   [3:0]                    slv_awqos,
    input   [1:0]                    slv_awbar,
    input   [1:0]                    slv_awdomain,
    input   [`CC_AXIJ_DMWR_VALUE *2+2:0]  slv_awsnoop,
    input   [5:0]                    slv_awatop,
    
    input   [`SLV_MISC_INFO_PW -1:0]  slv_awmisc_info,
    input   [63:0]                   slv_awmisc_info_hdr_34dw,
    input   [`CX_AXI_PRFX_WIDTH-1:0]            slv_awmisc_info_tlpprfx,
    input   [`CX_TAG_SIZE-1:0]           slv_awmisc_info_p_tag,
    input   [10:0]                   slv_awmisc_info_tph,
    input                            slv_awmisc_info_atu_bypass,
    input                            slv_awmisc_info_nw,
    input   [1:0]                    slv_awmisc_info_ats,
    input                            slv_awmisc_info_ido,
    input [8:0]                      slv_awmisc_info_dst_segment,
    output                           slv_wready,
    input   [`SLAVE_BUS_DATA_WIDTH -1:0]       slv_wdata,
    input   [`CC_SLV_W_USER_WIDTH -1:0]      slv_wuser,
    input   [`CC_SLV_BUS_WSTRB_WIDTH -1:0]      slv_wstrb,
    input                            slv_wlast,
    input                            slv_wvalid,
    input                            slv_wmisc_info_ep,
    input                            slv_wmisc_info_silentDrop,


    output  [`CC_SLV_BUS_ID_WIDTH -1:0]         slv_bid,
    output  [`CC_AXIJ_DMWR_VALUE+1:0] slv_bresp,
    output                           slv_bvalid,
    

    input                            slv_bready,
    output  [`SLV_RESP_MISC_INFO_PW -1:0]  slv_bmisc_info,
    output  [7:0]                     slv_bmisc_info_cpl_segment,
    output  [8:0]                     slv_bmisc_info_dst_segment,
    input   [`CC_SLV_BUS_ID_WIDTH -1:0]         slv_arid,
    input   [`SLAVE_BUS_ADDR_WIDTH -1:0]       slv_araddr,
    input   [`CC_SLV_AR_USER_WIDTH -1:0]      slv_aruser,
    input   [`CC_SLV_BURST_LEN_PW -1:0]  slv_arlen,
    input   [2:0]                    slv_arsize,
    input   [1:0]                    slv_arburst,
    input   [`CC_AXI_LOCK_WIDTH-1:0]        slv_arlock,
    input   [3:0]                    slv_arcache,
    input   [2:0]                    slv_arprot,
    input                            slv_arvalid,
    input   [`SLV_MISC_INFO_PW -1:0]  slv_armisc_info,
    input   [`CX_AXI_PRFX_WIDTH-1:0]            slv_armisc_info_tlpprfx,
    input   [10:0]                   slv_armisc_info_tph,
    input                            slv_armisc_info_atu_bypass,
    input                            slv_armisc_info_nw,
    input   [1:0]                    slv_armisc_info_ats,
    input                            slv_armisc_info_ido,
    input [8:0]                      slv_armisc_info_dst_segment,


    input                            slv_rready,
    output  [`CC_SLV_BUS_ID_WIDTH -1:0]         slv_rid,
    output  [`SLAVE_BUS_DATA_WIDTH -1:0]       slv_rdata,
    output  [`CC_SLV_R_USER_WIDTH -1:0]      slv_ruser,
    output  [1:0]                    slv_rresp,
    output                           slv_rlast,
    output                           slv_rvalid,
   

    output  [`SLV_RESP_MISC_INFO_PW -1:0]  slv_rmisc_info,
    output                           slv_rmisc_info_ido,
    output  [7:0]                     slv_rmisc_info_cpl_segment,
    output  [8:0]                     slv_rmisc_info_dst_segment,
    output                           slv_arready,
    input   [3:0]                    slv_arqos,
    input   [1:0]                    slv_arbar,
    input   [1:0]                    slv_ardomain,
    input   [3:0]                    slv_arsnoop,

    input                            slv_csysreq,
    output                           slv_csysack,
    output                           slv_cactive,

    output                           slv_aclk_g,
    input                            slv_aclk,
    output                           slv_aresetn,
    output                           slv_rasdp_err_mode,



    output                      cfg_pcie_cap_flit_mode_stat,

    input [8:0]              app_segment_id,

    output [8:0]             cfg_segment_id,

    output                              radm_cpl_timeout,
    output  [`CX_NFUNC_WD-1:0]                 radm_timeout_func_num,
    output  [2:0]                       radm_timeout_cpl_tc,
    output  [1:0]                       radm_timeout_cpl_attr,
    output  [11:0]                      radm_timeout_cpl_len,
    output  [`CX_TAG_SIZE-1:0]              radm_timeout_cpl_tag,




    // ELBI interface
    input                               ext_lbc_override_en,

    // ELBI interface
    input   [`CX_NFUNC-1:0]                    ext_lbc_ack,
    input   [(`CX_LBC_NW*32*`CX_NFUNC)-1:0]    ext_lbc_din,
    output  [`CX_LBC_EXT_AW-1:0]            lbc_ext_addr,
    output  [`CX_LBC_NW*32-1:0]         lbc_ext_dout,
    output  [`CX_NFUNC-1:0]                    lbc_ext_valid,
    output  [`CX_NFUNC-1:0]                    lbc_ext_cs,
    output  [(4*`CX_LBC_NW)-1:0]        lbc_ext_wr,
    output  [(4*`CX_LBC_NW)-1:0]        lbc_ext_rd,
    output                              lbc_ext_dbi_access,
    output                              lbc_ext_cxl_mbar0_access,
    output                              lbc_ext_rom_access,
    output                              lbc_ext_io_access,
    output  [2:0]                       lbc_ext_bar_num,
    // MSI interface
    input                               ven_msi_req,
    input   [`CX_NFUNC_WD-1:0]          ven_msi_func_num,
    input   [2:0]                       ven_msi_tc,
    input   [4:0]                       ven_msi_vector,
    output                              ven_msi_grant,
    output  [`CX_MSI_NFUNC-1:0]                    cfg_msi_en,
    output  [(64*`CX_MSI_NFUNC)-1:0]               cfg_msi_addr,
    output  [(32*`CX_MSI_NFUNC)-1:0]               cfg_msi_data,
    output  [`CX_MSI_NFUNC-1:0]                    cfg_msi_64,
    output  [(3*`CX_MSI_NFUNC)-1:0]                cfg_multi_msi_en,
    output  [`CX_MSI_NFUNC-1:0]                    cfg_msi_ext_data_en,

    // MSI-X interface

    // VPD interface


    // FLR interface

    output [(2*`CX_NFUNC)-1:0]                 cfg_tph_req_en,
    output [(3*`CX_NFUNC)-1:0]                 cfg_pf_tph_st_mode,
    output [`CX_NFUNC-1:0]                 cfg_pf_pasid_en,

    output [`CX_NFUNC-1:0]                 cfg_pf_pasid_execute_perm_en,

    output [`CX_NFUNC-1:0]                 cfg_pf_pasid_priv_mode_en,
    output [`CX_NFUNC-1:0]                     cfg_atomic_req_en,
    output [`CX_NFUNC-1:0]                     cfg_atomic_egress_block,
    output  [1:0]                       cfg_obff_en,
    output                              app_obff_msg_grant,

    output                              cfg_ltr_m_en,
    output [(32*`CX_NFUNC)-1:0]                cfg_ltr_max_latency,
    output                              cfg_disable_ltr_clr_msg,
    // Power Budgeting Capabilities interface
    input   [31:0]                      cfg_pwr_budget_data_reg,
    input   [`CX_NFUNC_WD-1:0]                 cfg_pwr_budget_func_num,
    output  [7:0]                       cfg_pwr_budget_data_sel_reg,
    output  [`CX_PB_NFUNC-1:0]                 cfg_pwr_budget_sel,
    // ARI
    output  [`CX_NFUNC-1:0]                    cfg_ari_fwd_en,
    // VMI interface
    input   [1:0]                       ven_msg_fmt,
    input   [4:0]                       ven_msg_type,
    input   [2:0]                       ven_msg_tc,
    input                               ven_msg_td,
    input                               ven_msg_ep,
    input   [`FLT_Q_ATTR_WIDTH-1:0]     ven_msg_attr,
    input   [9:0]                       ven_msg_len,
    input   [`CX_NFUNC_WD-1:0]          ven_msg_func_num,
    input   [`CX_TAG_SIZE-1:0]              ven_msg_tag,
    input   [7:0]                       ven_msg_code,
    input   [63:0]                      ven_msg_data,
    input                               ven_msg_req,
    output                              ven_msg_grant,

    // SII interface
    input                               rx_lane_flip_en,
    input                               tx_lane_flip_en,


    input   [`CX_NFUNC-1:0]                    sys_int,
    input   [`CX_NFUNC-1:0]                    outband_pwrup_cmd,
    input   [`CX_NFUNC-1:0]                    apps_pm_xmt_pme,
    input                               sys_aux_pwr_det,
    input   [`CX_NFUNC-1:0]                    sys_atten_button_pressed,
    input   [`CX_NFUNC-1:0]                    sys_pre_det_state,
    input   [`CX_NFUNC-1:0]                    sys_mrl_sensor_state,
    input   [`CX_NFUNC-1:0]                    sys_pwr_fault_det,
    input   [`CX_NFUNC-1:0]                    sys_mrl_sensor_chged,
    input   [`CX_NFUNC-1:0]                    sys_pre_det_chged,
    input   [`CX_NFUNC-1:0]                    sys_cmd_cpled_int,
    input   [`CX_NFUNC-1:0]                    sys_eml_interlock_engaged,
    output  [(2*`CX_NFUNC)-1:0]                cfg_pwr_ind,
    output  [(2*`CX_NFUNC)-1:0]                cfg_atten_ind,
    output  [`CX_NFUNC-1:0]                    cfg_pwr_ctrler_ctrl,
    input                               apps_pm_xmt_turnoff,
    input                               app_unlock_msg,
    input                               app_obff_idle_msg_req,
    input                               app_obff_obff_msg_req,
    input                               app_obff_cpu_active_msg_req,
    output                              pm_xtlh_block_tlp,
    output  [(64*`CX_NFUNC)-1:0]               cfg_bar0_start,
    output  [(32*`CX_NFUNC)-1:0]               cfg_bar1_start,
    output  [(64*`CX_NFUNC)-1:0]               cfg_bar0_limit,
    output  [(32*`CX_NFUNC)-1:0]               cfg_bar1_limit,
    output  [(64*`CX_NFUNC)-1:0]               cfg_bar2_start,
    output  [(64*`CX_NFUNC)-1:0]               cfg_bar2_limit,
    output  [(32*`CX_NFUNC)-1:0]               cfg_bar3_start,
    output  [(32*`CX_NFUNC)-1:0]               cfg_bar3_limit,
    output  [(64*`CX_NFUNC)-1:0]               cfg_bar4_start,
    output  [(64*`CX_NFUNC)-1:0]               cfg_bar4_limit,
    output  [(32*`CX_NFUNC)-1:0]               cfg_bar5_start,
    output  [(32*`CX_NFUNC)-1:0]               cfg_bar5_limit,
    output  [(32*`CX_NFUNC)-1:0]               cfg_exp_rom_start,
    output  [(32*`CX_NFUNC)-1:0]               cfg_exp_rom_limit,
    output  [`CX_NFUNC-1:0]                    cfg_bus_master_en,
    output  [`CX_NFUNC-1:0]                    cfg_mem_space_en,
    output  [(3*`CX_NFUNC)-1:0]                cfg_max_rd_req_size,
    output  [(3*`CX_NFUNC)-1:0]                cfg_max_payload_size,
    output  [`CX_NFUNC-1:0]                    cfg_ext_tag_en,
    output  [`CX_NFUNC-1:0]                    cfg_rcb,
    output  [`CX_NFUNC -1 :0]                  cfg_pm_no_soft_rst,
    output                                    cfg_aer_rc_err_int,
    output                                    cfg_aer_rc_err_msi,
    output  [4:0]                               cfg_aer_int_msg_num,
    output                                     cfg_sys_err_rc,
    output                                    cfg_pme_int,
    output                                    cfg_pme_msi,
    output                                    cfg_crs_sw_vis_en,
    output  [(`CX_NFUNC*5)-1:0]                cfg_pcie_cap_int_msg_num,
    output                              rdlh_link_up,
    output  [2:0]                       pm_curnt_state,
    output  [5:0]                       smlh_ltssm_state,
    output                              smlh_ltssm_state_rcvry_eq,
    output                              smlh_link_up,
    output                              smlh_req_rst_not,
    output                              link_req_rst_not,
    output                              brdg_slv_xfer_pending,
    output                              brdg_dbi_xfer_pending,
    output                              edma_xfer_pending,
    output                              radm_xfer_pending,
    output  [`CX_RADM_NFC_TRGT_INTF-1:0] radm_vendor_msg,
    output  [`CX_RADM_NFC_TRGT_INTF-1:0] radm_vendor_msg_type,
    output                              radm_msg_ltr,
    output  [(`CX_RADM_NFC_TRGT_INTF*64)-1:0] radm_msg_payload,

    output                              radm_slot_pwr_limit,

    output  [31:0]                      radm_slot_pwr_payload,

    output                              radm_msg_unlock,
    output                              radm_msg_idle,
    output                              radm_msg_obff,
    output                              radm_msg_cpu_active,
    output  [(`CX_RADM_NFC_TRGT_INTF*16)-1:0] radm_msg_req_id,
    output                              radm_inta_asserted,
    output                              radm_intb_asserted,
    output                              radm_intc_asserted,
    output                              radm_intd_asserted,
    output                              radm_inta_deasserted,
    output                              radm_intb_deasserted,
    output                              radm_intc_deasserted,
    output                              radm_intd_deasserted,
    output                              radm_correctable_err,
    output                              radm_nonfatal_err,
    output                              radm_fatal_err,
    output                              radm_pm_pme,
    output                              radm_pm_to_ack,
    output                              radm_pm_turnoff,
    output  [`CX_RX_NDLLP-1:0]              rtlh_rfc_upd,
    output  [(32*`CX_RX_NDLLP)-1:0]         rtlh_rfc_data,
    output rtlh_fc_overflow_err,
    output                              wake,
    output                              local_ref_clk_req_n,
    output  [`CX_NFUNC-1:0]                    cfg_eml_control,
    output  [`CX_NFUNC-1:0]                    hp_pme,
    output  [`CX_NFUNC-1:0]                    hp_int,
    output  [`CX_NFUNC-1:0]                    hp_msi,
    input                               app_sris_mode,
    input                               app_ltssm_enable,
    output                              cxl_ltssm_enable,

    output  [8 : 0]  smlh_cxl_enabled,

    output  [3:0]                       vlsm_mc_state,

    output  [3:0]                       vlsm_io_state,

    output cxl_s2m_data_pis,

    output cxl_m2s_data_pis,

    output cxl_h2d_data_pis,

    output cxl_d2h_data_pis,

    input                              vlsm_io_tx_pm_nak,

    input                              vlsm_mc_tx_pm_nak,

    output                             vlsm_io_rx_pm_nak,

    output                             vlsm_mc_rx_pm_nak,

    output                             vlsm_io_rx_pm_req,

    output                             vlsm_mc_rx_pm_req,


    output                             vlsm_io_pm_timeout,

    output                             vlsm_mc_pm_timeout,
    input                               cxl_viral_request,

    output                              cxl_viral_status,

    output                              cxl_viral_enable,

    output  [`CX_BUSNUM_WD-1:0]             cfg_pbus_num,
    output  [`CX_DEVNUM_WD-1:0]             cfg_pbus_dev_num,
    output  [(3*`CX_NFUNC)-1:0]                pm_dstate,
    output  [`CX_NFUNC-1:0]                    pm_pme_en,
    output                              pm_linkst_in_l0s,
    output                              pm_linkst_in_l1,
    output                              pm_linkst_in_l2,
    output                              pm_linkst_in_l23rdy,
    output                              pm_linkst_l2_exit,
    output  [2:0]                       pm_l1sub_state,
    output  [`CX_NFUNC-1:0]                    pm_status,
    output  [`CX_NFUNC-1:0]                    aux_pm_en,
    output                              cfg_link_auto_bw_int,
    output                              cfg_link_auto_bw_msi,
    output                              cfg_bw_mgt_int,
    output                              cfg_bw_mgt_msi,
    output                      cfg_flit_log_trg_evnt_msi,
    output                      cfg_flit_latency_msi,
    output                      cfg_sts_1_ltssm_latency_msi,
    output                              cfg_link_eq_req_int,
    output                              usp_eq_redo_executed_int,
    input                               app_ltr_msg_req,
    output                              app_ltr_msg_grant,
    input   [31:0]                      app_ltr_msg_latency,
    input   [`CX_NFUNC_WD-1:0]                 app_ltr_msg_func_num,
    output  [31:0]                      app_ltr_latency,
    output  [`CX_NVC-1:0]                   radm_q_not_empty,
    output  [`CX_NVC-1:0]                   radm_qoverflow,


    output                              trgt_cpl_timeout,
    output  [`CX_NFUNC_WD-1:0]                 trgt_timeout_cpl_func_num,
    output  [2:0]                       trgt_timeout_cpl_tc,
    output  [1:0]                       trgt_timeout_cpl_attr,
    output  [11:0]                      trgt_timeout_cpl_len,
    output  [`CX_REMOTE_LOOKUPID_WD-1:0]           trgt_timeout_lookup_id,
    output  [`CX_REMOTE_LOOKUPID_WD-1:0]           trgt_lookup_id,
    output                              trgt_lookup_empty,

    input                               app_hdr_valid,
    input   [`CX_APP_HDR_LOG_WIDTH-1:0]        app_hdr_log,
    input                               app_hdr_flitmode,
    input   [`CX_APP_HDR_LOG_SZ_WIDTH-1:0]     app_hdr_log_size,
    input   [`CX_ERR_BUS_WD-1:0]            app_err_bus,
    input                               app_err_advisory,
    input                               app_poisoned_tlp_type,
    input   [`CX_NFUNC_WD-1:0]                 app_err_func_num,

// START OF PIPE INTERFACE -----------------------------------------------------
    output  [(`CX_PHY_PDOWN_WD - 1) : 0]                       mac_phy_powerdown,
    input   [`CX_NL-1:0]                    phy_mac_rxelecidle,
    input   [`CX_NL-1:0]                    phy_mac_phystatus,
    input                               pipe_msgbus_rst_n,
    input   [(`CX_PIPE_DATA_WD - 1):0]     phy_mac_rxdata,
    input   [`CX_NL-1:0]                    phy_mac_rxvalid,
    input   [(`CX_NL*3)-1:0]                phy_mac_rxstatus,
    input   [`CX_NL-1:0]                    phy_mac_rxstandbystatus,
    input   [31:0]                      phy_cfg_status,
    input  [(`CX_NL - 1):0]                 pipe_rx_clk,
    input  [(`CX_NL - 1):0]                 pipe_rx_rst_n,
    output  [(`CX_PIPE_DATA_WD - 1):0]     mac_phy_txdata,
    output  [`CX_NL-1:0]                    mac_phy_txdatavalid,

    output  [`CX_NL-1:0]                    mac_phy_txdetectrx_loopback,
    output  [`CX_NL*`CX_PHY_TXEI_WD-1:0]       mac_phy_txelecidle,
    output  [`CX_PHY_WIDTH_WD-1:0]           mac_phy_width,
    output                             mac_phy_serdes_arch,
    output  [`CX_PHY_WIDTH_WD-1:0]           mac_phy_rxwidth,
    output  [`CX_NL-1:0]                    serdes_pipe_rxready,
    output  [`CX_NL-1:0]                    serdes_pipe_turnoff_lanes,
    output                              mac_phy_sris_enable,
    output                              mac_phy_commonclock_enable,
    output  [`PCLK_RATE_WD-1:0]                       mac_phy_pclk_rate,
    output  [`CX_NL-1:0]                    mac_phy_rxstandby,

    output  [`CX_PHY_RATE_WD-1:0]            mac_phy_rate,
    output                              cfg_hw_auto_sp_dis,

    output  [2:0]                       pm_current_data_rate,
    input   [`CX_NL-1:0]                    phy_mac_pclkchangeok,
    output   [`CX_NL-1:0]                   mac_phy_pclkchangeack,
    output                              mac_phy_maxpclkreq_n,
    input                               phy_mac_maxpclkack_n,

    output  [`CX_NL*8-1:0]                  mac_phy_messagebus,
    input   [`CX_NL*8-1:0]                  phy_mac_messagebus,
    input                   clkreq_in_n,
    output                  pm_linkst_in_l1sub,
    output                  cfg_l1sub_en,
    output                  mac_phy_rxelecidle_disable,
    output                  mac_phy_txcommonmode_disable,
    output                  mac_phy_asyncpowerchangeack,
    output  [31:0]                      cfg_phy_control,
// END OF PIPE INTERFACE -------------------------------------------------------



    input                               app_margining_ready,
    input                               app_margining_software_ready,
    // clk_and_reset interface
    input                               core_clk,
    input                               core_clk_ug,
    input                               aux_clk,
    input                               aux_clk_g,
    output                              en_aux_clk_g,
    input                               radm_clk_g,
    output                              en_radm_clk_g,
    output                              radm_idle,
    input                               pwr_rst_n,
    input                               sticky_rst_n,
    input                               non_sticky_rst_n,
    input                               core_rst_n,
    input               perst_n,
    input               app_clk_req_n,
    input               phy_clk_req_n,
    output              pm_req_sticky_rst,
    output              pm_req_core_rst,
    output              pm_req_non_sticky_rst,
    output              pm_sel_aux_clk,
    output              pm_en_core_clk,
    output              pm_req_phy_rst,
    output              pm_req_phy_perst,
    output              upstream_port,
    output [6:0]        pm_div_max_pclk_ratio,


    output                             pm_aspm_l1_enter_ready,

    input                               app_req_entr_l1,


    input                               app_ready_entr_l23,


    input                               app_req_exit_l1,
    input                               app_xfer_pending,
    input                               app_init_rst,

    input   [3:0]                       device_type,
    input                               app_req_retry_en,
    input  [`CX_NFUNC-1:0]                       app_pf_req_retry_en,


    // DBI Read-only Write Disable
    input                              app_dbi_ro_wr_disable,

    input                               app_drs_ready,
    output [`CX_NFUNC-1:0]                     cfg_drs_msi,
    output [`CX_NFUNC-1:0]                     cfg_up_drs_to_frs,


    input  [`CX_NFUNC-1:0]                     app_pf_frs_ready,
    output [`CX_NFUNC-1:0]                      pf_frs_grant,
    output                                     frsq_msi,

    output [4:0]                              frsq_int_msg_num,
    output                              training_rst_n,

   // RAM moved out of the TOP


    // Retry buffer external RAM interface
    output  [`RBUF_PW -1:0]              xdlh_retryram_raddr,
    // Retry buffer external RAM interface
    output  [`RBUF_PW -1:0]              xdlh_retryram_waddr,
    output  [`RBUF_WIDTH-1:0]           xdlh_retryram_data,
    output                              xdlh_retryram_we,
    output                              xdlh_retryram_en,
    input   [`RBUF_WIDTH-1:0]           retryram_xdlh_data,

    // Retry SOT buffer
    output  [`SOTBUF_L2DEPTH -1:0]            xdlh_retrysotram_waddr,
    output  [`SOTBUF_L2DEPTH -1:0]            xdlh_retrysotram_raddr,
    output  [`SOTBUF_WIDTH -1:0]            xdlh_retrysotram_data,
    output                              xdlh_retrysotram_we,
    output                              xdlh_retrysotram_en,
    input   [`SOTBUF_WIDTH -1:0]            retrysotram_xdlh_data,

    output rplh_flit_unrecognized_flit,
    output rplh_flit_ecc_corr_err,
    output rplh_flit_ecc_uncorr_err,
    output rplh_flit_crc_uncorr_err,

    // For the effort of bring RAM outside of the hiarch.
    // Beneath are grouped outputs and input  s just for RAM


    // VC0 P Radm Formation Queue external RAM interface
    // ---- outputs to formation queue ram ---------------
    output  [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_P-1:0]            radm_formqram_addra_vc0_p,
    output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_ena_vc0_p,
    output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_wea_vc0_p,
    output  [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_P-1:0]            radm_formqram_dina_vc0_p,
    output  [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_P-1:0]            radm_formqram_addrb_vc0_p,
    output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_enb_vc0_p,

    // ---- inputs from formation queue ram ---------------
    input   [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_P-1:0]            formqram_radm_doutb_vc0_p,


    // VC0 NP Radm Formation Queue external RAM interface
    // ---- outputs to formation queue ram ---------------
    output  [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_NP-1:0]            radm_formqram_addra_vc0_np,
    output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_ena_vc0_np,
    output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_wea_vc0_np,
    output  [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_NP-1:0]            radm_formqram_dina_vc0_np,
    output  [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_NP-1:0]            radm_formqram_addrb_vc0_np,
    output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_enb_vc0_np,

    // ---- inputs from formation queue ram ---------------
    input   [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_NP-1:0]            formqram_radm_doutb_vc0_np,


    // VC0 CPL Radm Formation Queue external RAM interface
    // ---- outputs to formation queue ram ---------------
    output  [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_CPL-1:0]            radm_formqram_addra_vc0_cpl,
    output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_ena_vc0_cpl,
    output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_wea_vc0_cpl,
    output  [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_CPL-1:0]            radm_formqram_dina_vc0_cpl,
    output  [`CX_RADM_FORMQ_NQW*`RAM_PW_VC0_CPL-1:0]            radm_formqram_addrb_vc0_cpl,
    output  [`CX_RADM_FORMQ_NQW-1:0]                   radm_formqram_enb_vc0_cpl,

    // ---- inputs from formation queue ram ---------------
    input   [`CX_RADM_FORMQ_NQW*`RAM_WD_VC0_CPL-1:0]            formqram_radm_doutb_vc0_cpl,


    output    [`CX_RADM_RAS_DES_ERR_INFO_WD-1:0] radm_ras_des_err_info_0,



  // eDMA RAM interface signals
    output         [`CC_IF_RDCTRL_LL_RAM_PW-1:0] edma_rd_eng_ll_addra_ram,
    output         [`CC_IF_RDCTRL_LL_RAM_PW-1:0] edma_rd_eng_ll_addrb_ram,
    output         [`CC_IF_RDCTRL_LL_RAM_WD-1:0] edma_rd_eng_ll_dout_ram,
    output                                       edma_rd_eng_ll_we_ram,
    output                                       edma_rd_eng_ll_re_ram,
    input          [`CC_IF_RDCTRL_LL_RAM_WD-1:0] edma_rd_eng_ll_din_ram,
    output         [`CC_IF_WRCTRL_LL_RAM_PW-1:0] edma_wr_eng_ll_addra_ram,
    output         [`CC_IF_WRCTRL_LL_RAM_PW-1:0] edma_wr_eng_ll_addrb_ram,
    output         [`CC_IF_WRCTRL_LL_RAM_WD-1:0] edma_wr_eng_ll_dout_ram,
    output                                       edma_wr_eng_ll_we_ram,
    output                                       edma_wr_eng_ll_re_ram,
    input          [`CC_IF_WRCTRL_LL_RAM_WD-1:0] edma_wr_eng_ll_din_ram,
    output [`CC_IF_RDCTX_LLQ_OVERLAY_RAM_PW-1:0] edma_rd_eng_ovrl_addra_ram,
    output [`CC_IF_RDCTX_LLQ_OVERLAY_RAM_PW-1:0] edma_rd_eng_ovrl_addrb_ram,
    output [`CC_IF_RDCTX_LLQ_OVERLAY_RAM_WD-1:0] edma_rd_eng_ovrl_dout_ram,
    output                                       edma_rd_eng_ovrl_we_ram,
    output                                       edma_rd_eng_ovrl_re_ram,
    input  [`CC_IF_RDCTX_LLQ_OVERLAY_RAM_WD-1:0] edma_rd_eng_ovrl_din_ram,
    output [`CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW-1:0] edma_wr_eng_ovrl_addra_ram,
    output [`CC_IF_WRCTX_LLQ_OVERLAY_RAM_PW-1:0] edma_wr_eng_ovrl_addrb_ram,
    output [`CC_IF_WRCTX_LLQ_OVERLAY_RAM_WD-1:0] edma_wr_eng_ovrl_dout_ram,
    output                                       edma_wr_eng_ovrl_we_ram,
    output                                       edma_wr_eng_ovrl_re_ram,
    input  [`CC_IF_WRCTX_LLQ_OVERLAY_RAM_WD-1:0] edma_wr_eng_ovrl_din_ram,
    output         [`CC_IF_RD_CTXC2W_RAM_PW-1:0] edma_rd_eng_c2w_lut_addra_ram,
    output         [`CC_IF_RD_CTXC2W_RAM_PW-1:0] edma_rd_eng_c2w_lut_addrb_ram,
    output         [`CC_IF_RD_CTXC2W_RAM_WD-1:0] edma_rd_eng_c2w_lut_dout_ram,
    output                                       edma_rd_eng_c2w_lut_we_ram,
    output                                       edma_rd_eng_c2w_lut_re_ram,
    input          [`CC_IF_RD_CTXC2W_RAM_WD-1:0] edma_rd_eng_c2w_lut_din_ram,
    output         [`CC_IF_WR_CTXC2W_RAM_PW-1:0] edma_wr_eng_c2w_lut_addra_ram,
    output         [`CC_IF_WR_CTXC2W_RAM_PW-1:0] edma_wr_eng_c2w_lut_addrb_ram,
    output         [`CC_IF_WR_CTXC2W_RAM_WD-1:0] edma_wr_eng_c2w_lut_dout_ram,
    output                                       edma_wr_eng_c2w_lut_we_ram,
    output                                       edma_wr_eng_c2w_lut_re_ram,
    input          [`CC_IF_WR_CTXC2W_RAM_WD-1:0] edma_wr_eng_c2w_lut_din_ram,
    output        [`CC_IF_RD_CTXSTSH_RAM_PW-1:0] edma_rd_eng_stsh_lut_addra_ram,
    output        [`CC_IF_RD_CTXSTSH_RAM_PW-1:0] edma_rd_eng_stsh_lut_addrb_ram,
    output        [`CC_IF_RD_CTXSTSH_RAM_WD-1:0] edma_rd_eng_stsh_lut_dout_ram,
    output                                       edma_rd_eng_stsh_lut_we_ram,
    output                                       edma_rd_eng_stsh_lut_re_ram,
    input         [`CC_IF_RD_CTXSTSH_RAM_WD-1:0] edma_rd_eng_stsh_lut_din_ram,
    output        [`CC_IF_WR_CTXSTSH_RAM_PW-1:0] edma_wr_eng_stsh_lut_addra_ram,
    output        [`CC_IF_WR_CTXSTSH_RAM_PW-1:0] edma_wr_eng_stsh_lut_addrb_ram,
    output        [`CC_IF_WR_CTXSTSH_RAM_WD-1:0] edma_wr_eng_stsh_lut_dout_ram,
    output                                       edma_wr_eng_stsh_lut_we_ram,
    output                                       edma_wr_eng_stsh_lut_re_ram,
    input         [`CC_IF_WR_CTXSTSH_RAM_WD-1:0] edma_wr_eng_stsh_lut_din_ram,
    output            [`CC_IF_RD_MSI_RAM_PW-1:0] edma_rd_eng_msi_addra_ram,
    output            [`CC_IF_RD_MSI_RAM_PW-1:0] edma_rd_eng_msi_addrb_ram,
    output            [`CC_IF_RD_MSI_RAM_WD-1:0] edma_rd_eng_msi_dout_ram,
    output                                       edma_rd_eng_msi_we_ram,
    output                                       edma_rd_eng_msi_re_ram,
    input             [`CC_IF_RD_MSI_RAM_WD-1:0] edma_rd_eng_msi_din_ram,
    output            [`CC_IF_WR_MSI_RAM_PW-1:0] edma_wr_eng_msi_addra_ram,
    output            [`CC_IF_WR_MSI_RAM_PW-1:0] edma_wr_eng_msi_addrb_ram,
    output            [`CC_IF_WR_MSI_RAM_WD-1:0] edma_wr_eng_msi_dout_ram,
    output                                       edma_wr_eng_msi_we_ram,
    output                                       edma_wr_eng_msi_re_ram,
    input             [`CC_IF_WR_MSI_RAM_WD-1:0] edma_wr_eng_msi_din_ram,
    input                                        edma_rd_eng_hard_stop_req,
    input        [`CC_NUM_DMA_RD_CHAN_WIDTH-1:0] edma_rd_eng_hard_stop_channel,
    output                                       edma_rd_eng_hard_stop_ack,  
    input                                        edma_wr_eng_hard_stop_req,
    input        [`CC_NUM_DMA_WR_CHAN_WIDTH-1:0] edma_wr_eng_hard_stop_channel,
    output                                       edma_wr_eng_hard_stop_ack,
    //eDMA Read buffer RAM interface
    input  [`CX_DMA_RBUF_NSLICES*`CX_DMA_RBUF_SLICE_WD-1:0]    ram2edmarbuff_din,
    output [`CX_DMA_RBUF_NSLICES*`CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]  edmarbuff2ram_addra,
    output [`CX_DMA_RBUF_NSLICES*`CC_DMA_SEG_BUF_NW_ADDR_WIDTH-1:0]  edmarbuff2ram_addrb,
    output [`CX_DMA_RBUF_NSLICES*`CX_DMA_RBUF_SLICE_WD-1:0]     edmarbuff2ram_dout,
    output [`CX_DMA_RBUF_NSLICES-1:0]                            edmarbuff2ram_re,
    output [`CX_DMA_RBUF_NSLICES-1:0]                            edmarbuff2ram_we,

    output [`CX_RAS_DES_EC_RAM_ADDR_WIDTH-1:0]  cdm_ras_des_ec_ram_addra,
    output [`CX_RAS_DES_EC_RAM_ADDR_WIDTH-1:0]  cdm_ras_des_ec_ram_addrb,
    output [`CX_RAS_DES_EC_RAM_DATA_WIDTH-1:0]  cdm_ras_des_ec_ram_datain,
    output                                 cdm_ras_des_ec_ram_wea,
    output                                 cdm_ras_des_ec_ram_ena,
    output                                 cdm_ras_des_ec_ram_enb,
    input  [`CX_RAS_DES_EC_RAM_DATA_WIDTH-1:0]  cdm_ras_des_ec_ram_dataout,
    output [`CX_RAS_DES_TBA_RAM_ADDR_WIDTH-1:0] cdm_ras_des_tba_ram_addra,
    output [`CX_RAS_DES_TBA_RAM_ADDR_WIDTH-1:0] cdm_ras_des_tba_ram_addrb,
    output [`CX_RAS_DES_TBA_RAM_DATA_WIDTH-1:0] cdm_ras_des_tba_ram_datain,
    output                                 cdm_ras_des_tba_ram_wea,
    output                                 cdm_ras_des_tba_ram_ena,
    output                                 cdm_ras_des_tba_ram_enb,
    input  [`CX_RAS_DES_TBA_RAM_DATA_WIDTH-1:0] cdm_ras_des_tba_ram_dataout,


    output  [`CX_NFUNC-1:0]                    cfg_reg_serren,
    output  [`CX_NFUNC-1:0]                    cfg_cor_err_rpt_en,
    output  [`CX_NFUNC-1:0]                    cfg_nf_err_rpt_en,
    output  [`CX_NFUNC-1:0]                    cfg_f_err_rpt_en,

    input   [1:0]  cdm_ras_des_einj0_req,
    output  [1:0]  cdm_ras_des_einj0_ack,
    output  [`CX_RAS_DES_EC_INFO_CMN_BW-1:0]     cdm_ras_des_ec_info_common,
    output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l0,
    output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l1,
    output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l2,
    output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l3,
    output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l4,
    output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l5,
    output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l6,
    output  [`CX_RAS_DES_EC_INFO_PLN_BW-1:0]     cdm_ras_des_ec_info_l7,
    input                               app_ras_des_sd_hold_ltssm,
    output  [`CX_RAS_DES_SD_INFO_CMN_BW-1:0]     cdm_ras_des_sd_info_common,
    output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l0,
    output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l1,
    output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l2,
    output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l3,
    output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l4,
    output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l5,
    output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l6,
    output  [`CX_RAS_DES_SD_INFO_PLN_BW-1:0]     cdm_ras_des_sd_info_l7,
    output   [`CX_RAS_DES_SD_INFO_PVC_BW-1:0]    cdm_ras_des_sd_info_v0,
    output   [`CX_RAS_DES_TBA_INFO_CMN_BW-1:0]   cdm_ras_des_tba_info_common,
    input    [1:0]                      app_ras_des_tba_ctrl,


    output [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]      ib_rreq_c2a_cdc_ram_addra,
    output [`CC_IB_RD_REQ_CDC_RAM_ADDR_WD-1:0]      ib_rreq_c2a_cdc_ram_addrb,
    output                                         ib_rreq_c2a_cdc_ram_wea,
    output                                         ib_rreq_c2a_cdc_ram_enb,
    output [`CC_IB_RD_REQ_CDC_RAM_DATA_WD-1:0]      ib_rreq_c2a_cdc_ram_dina,
    input [`CC_IB_RD_REQ_CDC_RAM_DATA_WD-1:0]       ib_rreq_c2a_cdc_ram_doutb,
    output [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]      ib_wreq_c2a_cdc_ram_addra,
    output [`CC_IB_WR_REQ_CDC_RAM_ADDR_WD-1:0]      ib_wreq_c2a_cdc_ram_addrb,
    output                                         ib_wreq_c2a_cdc_ram_wea,
    output                                         ib_wreq_c2a_cdc_ram_enb,
    output [`CC_IB_WR_REQ_CDC_RAM_DATA_WD-1:0]      ib_wreq_c2a_cdc_ram_dina,
    input [`CC_IB_WR_REQ_CDC_RAM_DATA_WD-1:0]       ib_wreq_c2a_cdc_ram_doutb,
    output [`CC_MSTR_CPL_SEG_N_SLICES*`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]   ib_mcpl_sb_ram_addra,
    output [`CC_MSTR_CPL_SEG_N_SLICES*`CC_IB_MCPL_SEG_BUF_RAM_ADDR_WD-1:0]   ib_mcpl_sb_ram_addrb,
    output [`CC_MSTR_CPL_SEG_N_SLICES*`CC_MSTR_CPL_SEG_BUF_SLICE_WD-1:0]   ib_mcpl_sb_ram_dina,
    input [`CC_MSTR_CPL_SEG_N_SLICES*`CC_MSTR_CPL_SEG_BUF_SLICE_WD-1:0]   ib_mcpl_sb_ram_doutb,
    output [`CC_MSTR_CPL_SEG_N_SLICES-1:0]                                        ib_mcpl_sb_ram_enb,
    output [`CC_MSTR_CPL_SEG_N_SLICES-1:0]                                        ib_mcpl_sb_ram_wea,
    output [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]     ib_mcpl_a2c_cdc_ram_addra,
    output [`CC_IB_MCPL_CDC_RAM_ADDR_WD-1:0]     ib_mcpl_a2c_cdc_ram_addrb,
    output                                      ib_mcpl_a2c_cdc_ram_wea,
    output                                      ib_mcpl_a2c_cdc_ram_enb,
    input  [`CC_IB_MCPL_CDC_RAM_DATA_WD-1:0]     ib_mcpl_a2c_cdc_ram_doutb,
    output [`CC_IB_MCPL_CDC_RAM_DATA_WD-1:0]     ib_mcpl_a2c_cdc_ram_dina,
    output [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]      slv_npw_sab_ram_addra,
    output                                    slv_npw_sab_ram_wea,
    output [`CC_SLV_NPW_SAB_RAM_DATA_WD-1:0]      slv_npw_sab_ram_dina,
    output [`CC_SLV_NPW_SAB_RAM_ADDR_WD-1:0]      slv_npw_sab_ram_addrb,
    output                                    slv_npw_sab_ram_enb,
    input  [`CC_SLV_NPW_SAB_RAM_DATA_WD-1:0]      slv_npw_sab_ram_doutb,
    output [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]        ob_npdcmp_ram_addra,
    output                                    ob_npdcmp_ram_wea,
    output [`CC_OB_NPDCMP_RAM_DATA_WD-1:0]        ob_npdcmp_ram_dina,
    output [`CC_OB_NPDCMP_RAM_ADDR_WD-1:0]        ob_npdcmp_ram_addrb,
    output                                    ob_npdcmp_ram_enb,
    input  [`CC_OB_NPDCMP_RAM_DATA_WD-1:0]        ob_npdcmp_ram_doutb,
    output [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]     ob_pdcmp_hdr_ram_addra,
    output                                    ob_pdcmp_hdr_ram_wea,
    output [`CC_OB_PDCMP_HDR_RAM_DATA_WD-1:0]     ob_pdcmp_hdr_ram_dina,
    output [`CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]     ob_pdcmp_hdr_ram_addrb,
    output                                    ob_pdcmp_hdr_ram_enb,
    input  [`CC_OB_PDCMP_HDR_RAM_DATA_WD-1:0]     ob_pdcmp_hdr_ram_doutb,
    output [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]    ob_pdcmp_data_ram_addra,
    output                                    ob_pdcmp_data_ram_wea,
    output [`CC_OB_PDCMP_DATA_RAM_DATA_WD-1:0]    ob_pdcmp_data_ram_dina,
    output [`CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]    ob_pdcmp_data_ram_addrb,
    output                                    ob_pdcmp_data_ram_enb,
    input  [`CC_OB_PDCMP_DATA_RAM_DATA_WD-1:0]    ob_pdcmp_data_ram_doutb,
    output [`CC_OB_CCMP_NSLICES*`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]  ob_ccmp_data_ram_addra,
    output [`CC_OB_CCMP_NSLICES-1:0]                           ob_ccmp_data_ram_wea,
    output [`CC_OB_CCMP_NSLICES*`CC_OB_CCMP_SLICE_WD-1:0]       ob_ccmp_data_ram_dina,
    output [`CC_OB_CCMP_NSLICES*`CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]  ob_ccmp_data_ram_addrb,
    output [`CC_OB_CCMP_NSLICES-1:0]                           ob_ccmp_data_ram_enb,
    input  [`CC_OB_CCMP_NSLICES*`CC_OB_CCMP_SLICE_WD-1:0]       ob_ccmp_data_ram_doutb,
    output [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]   ib_scheduler_p_hdr_ram_addra,
    output [`CC_IB_SCHEDULER_P_HDR_RAM_ADDR_WD-1:0]  ib_scheduler_p_hdr_ram_addrb,
    output [`CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD-1:0]   ib_scheduler_p_hdr_ram_dina,
    input  [`CC_IB_SCHEDULER_P_HDR_RAM_DATA_WD-1:0]   ib_scheduler_p_hdr_ram_doutb,
    output                                            ib_scheduler_p_hdr_ram_enb,
    output                                            ib_scheduler_p_hdr_ram_wea,
    output [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]   ib_scheduler_p_data_ram_addra,
    output [`CC_IB_SCHEDULER_P_DATA_RAM_ADDR_WD-1:0]  ib_scheduler_p_data_ram_addrb,
    output [`CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD-1:0]   ib_scheduler_p_data_ram_dina,
    input  [`CC_IB_SCHEDULER_P_DATA_RAM_DATA_WD-1:0]   ib_scheduler_p_data_ram_doutb,
    output                                            ib_scheduler_p_data_ram_enb,
    output                                            ib_scheduler_p_data_ram_wea,
    output [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]   ib_scheduler_np_hdr_ram_addra,
    output [`CC_IB_SCHEDULER_NP_HDR_RAM_ADDR_WD-1:0]  ib_scheduler_np_hdr_ram_addrb,
    output [`CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD-1:0]   ib_scheduler_np_hdr_ram_dina,
    input  [`CC_IB_SCHEDULER_NP_HDR_RAM_DATA_WD-1:0]   ib_scheduler_np_hdr_ram_doutb,
    output                                            ib_scheduler_np_hdr_ram_enb,
    output                                            ib_scheduler_np_hdr_ram_wea,
    output [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]   ib_scheduler_np_data_ram_addra,
    output [`CC_IB_SCHEDULER_NP_DATA_RAM_ADDR_WD-1:0]  ib_scheduler_np_data_ram_addrb,
    output [`CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD-1:0]   ib_scheduler_np_data_ram_dina,
    input  [`CC_IB_SCHEDULER_NP_DATA_RAM_DATA_WD-1:0]   ib_scheduler_np_data_ram_doutb,
    output                                            ib_scheduler_np_data_ram_enb,
    output                                            ib_scheduler_np_data_ram_wea,




  
    input [`CX_NFUNC-1:0]               exp_rom_validation_status_strobe,
    input [`CX_NFUNC*3-1:0]               exp_rom_validation_status,
    input [`CX_NFUNC-1:0]               exp_rom_validation_details_strobe,
    input [`CX_NFUNC*4-1:0]               exp_rom_validation_details,
    output  [63:0]                      cxpl_debug_info,
    output  [`CX_INFO_EI_WD-1:0]        cxpl_debug_info_ei
    ,output         [`CX_NL-1:0]                 mac_phy_dirchange
    ,output [(`CC_NUM_DMA_RD_CHAN+`CC_NUM_DMA_WR_CHAN-1):0] edma_int
    ,
    output                              assert_inta_grt,
    output                              assert_intb_grt,
    output                              assert_intc_grt,
    output                              assert_intd_grt,
    output                              deassert_inta_grt,
    output                              deassert_intb_grt,
    output                              deassert_intc_grt,
    output                              deassert_intd_grt,
    output  [(8*`CX_NFUNC)-1:0]                cfg_int_pin
   ,
    output  [7:0]                              cfg_2ndbus_num,
    output  [7:0]                              cfg_subbus_num,
    output                              cfg_2nd_reset
    ,
    input                   app_clk_pm_en
    ,
    output [`CX_NFUNC-1:0]     cfg_end2end_tlp_pfx_blck
    ,input                   aux_clk_active

    ,output [`CX_NFUNC-1:0]                  cfg_ido_req_en
    ,output [`CX_NFUNC-1:0]                  cfg_ido_cpl_en

    ,output  [`CX_NFUNC-1:0]                    cfg_send_cor_err
    ,output  [`CX_NFUNC-1:0]                    cfg_send_nf_err
    ,output  [`CX_NFUNC-1:0]                    cfg_send_f_err


    ,output  [`CX_NFUNC-1:0]                    cfg_int_disable
    ,output  [`CX_NFUNC-1:0]        cfg_no_snoop_en
    ,output  [`CX_NFUNC-1:0]        cfg_relax_order_en

    ,output                              ptm_context_valid
    ,output                              ptm_responder_rdy_to_validate
    ,output [63:0]                       ptm_local_clock



    ,input                             ptm_external_master_strobe
    ,input [63:0]                      ptm_external_master_time

    ,input                               ptm_auto_update_signal
    ,input                               ptm_manual_update_pulse

    ,output                              ptm_trigger_allowed
    ,output                              ptm_updating
    ,output                              ptm_clock_updated
    ,output [63:0]                       ptm_clock_correction
    ,output                              ptm_req_response_timeout
    ,output                              ptm_req_dup_rx
    ,output                              ptm_req_replay_tx



    ,output   [(5*`CX_NFUNC)-1:0]   cfg_ats_stu
    ,output   [`CX_NFUNC-1:0]       cfg_ats_cache_en

    ,output                  cfg_acs_validation_en
    ,output                  cfg_acs_at_blocking_en
    ,output   [`CX_NFUNC-1:0]       cfg_acs_p2p_req_redirect_en
    ,output   [`CX_NFUNC-1:0]       cfg_acs_p2p_compl_redirect_en
    ,output                  cfg_acs_up_forward_en
    ,output   [`CX_NFUNC-1:0]       cfg_acs_p2p_egress_ctrl_en
    ,output   [`CX_NFUNC-1:0]       cfg_acs_p2p_direct_transl_en
    ,output   [(`ACS_CTRL_VEC_WD*`CX_NFUNC)-1:0]  cfg_acs_egress_ctrl_vec


    ,output   [`CX_NFUNC-1:0]   surprise_down_err

    ,input    [`CX_NFUNC-1:0]       prs_res_failure
    ,input    [`CX_NFUNC-1:0]       prs_uprgi
    ,input    [`CX_NFUNC-1:0]       prs_stopped
    ,output   [`CX_NFUNC-1:0]       cfg_prs_enable
    ,output   [`CX_NFUNC-1:0]       cfg_prs_reset
    ,output   [`CX_NFUNC-1:0]       cfg_prs_stopped
    ,output   [`CX_NFUNC-1:0]       cfg_prs_uprgi
    ,output   [`CX_NFUNC-1:0]       cfg_prs_response_failure
    ,output   [(32*`CX_NFUNC)-1:0]  cfg_prs_outstanding_allocation



    ,output   [`CX_NFUNC-1:0]                cfg_br_ctrl_serren

,output [`CX_NFUNC-1:0] cfg_hp_slot_ctrl_access
,output [`CX_NFUNC-1:0] cfg_dll_state_chged_en
,output [`CX_NFUNC-1:0] cfg_cmd_cpled_int_en
,output [`CX_NFUNC-1:0] cfg_hp_int_en
,output [`CX_NFUNC-1:0] cfg_pre_det_chged_en
,output [`CX_NFUNC-1:0] cfg_mrl_sensor_chged_en
,output [`CX_NFUNC-1:0] cfg_pwr_fault_det_en
,output [`CX_NFUNC-1:0] cfg_atten_button_pressed_en



    ,input                                  app_hold_phy_rst
    ,input                                  app_l1sub_disable
    ,output                     pm_l1_entry_started
    ,
    output                            core_in_dpc,
    output      [4:0]                 cfg_dpc_int_msg_num,
    output      [1:0]                 cfg_dpc_trig_en,
    output                            cfg_dpc_cpl_cntrl,
    output                            cfg_dpc_int_en,
    output                            dpc_int,
    output                            dpc_msi,
    output                            cfg_dpc_err_cor_en,
    output                            cfg_dpc_sw_trigger,
    output                            cfg_dpc_poison_tlp_egr_block_en,
    output                            cfg_dpc_dl_active_err_cor_en
    ,

    input      [4:0]                 app_dev_num,

    input      [7:0]                 app_bus_num
    ,

    output                           cfg_uncor_internal_err_sts,
    output                           cfg_rcvr_overflow_err_sts,
    output                           cfg_fc_protocol_err_sts,
    output                           cfg_mlf_tlp_err_sts,
    output                           cfg_surprise_down_er_sts,
    output                           cfg_dl_protocol_err_sts,
    output                           cfg_ecrc_err_sts,
    output                           cfg_corrected_internal_err_sts,
    output                           cfg_replay_number_rollover_err_sts,
    output                           cfg_replay_timer_timeout_err_sts,
    output                           cfg_bad_dllp_err_sts,
    output                           cfg_bad_tlp_err_sts,
    output                           cfg_rcvr_err_sts,
    output [`CX_NFUNC-1:0]                              cfg_advisory_nf_sts,
    output [`CX_NFUNC-1:0]                              cfg_hdr_log_overflow_sts

    // -------------------------------------------------------------------------------------
    // CXL Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,
    input                               cxl_clk,

    input                               cxl_rst_n

// spyglass disable_block Topology_02
// SMD: Direct connection from input port to output port
// SJ: RAM-based FIFO is implemented to buffer data on Data Message Channels which propagates data to RAM data inputs
    ,
    // -------------------------------------------------------------------------------------
    // CXL Protocol Master RX Cache Link initialization Interface
    // -------------------------------------------------------------------------------------
    output                                                  cxl_cache_mst_req,

    input                                                   cxl_cache_mst_ack,

    // -------------------------------------------------------------------------------------
    // CXL Protocol Slave TX Cache Link initialization Interface
    // -------------------------------------------------------------------------------------
    input                                                   cxl_cache_slv_req,

    input                                                   cxl_cache_app_pending, 

    output                                                  cxl_cache_slv_ack

    ,
    // -------------------------------------------------------------------------------------
    // CXL.Cache Host Master (Root Complex RX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    input [`CX_CXL_CACHE_H2D_REQ_IFNUM-1:0]                 cxl_mst_h2d_req_crd,

    input [`CX_CXL_CACHE_H2D_RESP_IFNUM-1:0]                cxl_mst_h2d_rsp_crd,

    input [`CX_CXL_CACHE_H2D_DATA_IFNUM-1:0]                cxl_mst_h2d_data_crd,

    output [(`CX_CXL_CACHE_H2D_REQ_IFNUM*`CX_CXL_CACHE_H2D_REQ_SIZE)-1:0]    cxl_mst_h2d_req,

    output [(`CX_CXL_CACHE_H2D_RESP_IFNUM*`CX_CXL_CACHE_H2D_RESP_SIZE)-1:0]  cxl_mst_h2d_rsp,

    output [(`CX_CXL_CACHE_H2D_DATA_IFNUM*`CX_CXL_CACHE_H2D_DATA_SIZE)-1:0]  cxl_mst_h2d_data,

    output [(`CX_CXL_CACHE_H2D_REQ_IFNUM*`CX_CXL_CACHE_H2D_REQ_CHK_SIZE)-1:0]  cxl_mst_h2d_req_chk,

    output [(`CX_CXL_CACHE_H2D_RESP_IFNUM*`CX_CXL_CACHE_H2D_RESP_CHK_SIZE)-1:0]  cxl_mst_h2d_rsp_chk,

    output [(`CX_CXL_CACHE_H2D_DATA_IFNUM*`CX_CXL_CACHE_H2D_DATA_CHK_SIZE)-1:0]  cxl_mst_h2d_data_chk,


    // -------------------------------------------------------------------------------------
    // CXL.Cache Device Slave (Endpoint TX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    output [`CX_CXL_CACHE_D2H_REQ_IFNUM-1:0]                cxl_slv_d2h_req_crd,

    output [`CX_CXL_CACHE_D2H_RESP_IFNUM-1:0]               cxl_slv_d2h_rsp_crd,

    output [`CX_CXL_CACHE_D2H_DATA_IFNUM-1:0]               cxl_slv_d2h_data_crd,

    input [(`CX_CXL_CACHE_D2H_REQ_IFNUM*`CX_CXL_CACHE_D2H_REQ_SIZE)-1:0]  cxl_slv_d2h_req,

    input [(`CX_CXL_CACHE_D2H_RESP_IFNUM*`CX_CXL_CACHE_D2H_RESP_SIZE)-1:0]  cxl_slv_d2h_rsp,

    input [(`CX_CXL_CACHE_D2H_DATA_IFNUM*`CX_CXL_CACHE_D2H_DATA_SIZE)-1:0]  cxl_slv_d2h_data

    ,
    input [(`CX_CXL_CACHE_D2H_REQ_IFNUM*`CX_CXL_CACHE_D2H_REQ_CHK_SIZE)-1:0]  cxl_slv_d2h_req_chk,

    input [(`CX_CXL_CACHE_D2H_RESP_IFNUM*`CX_CXL_CACHE_D2H_RESP_CHK_SIZE)-1:0]  cxl_slv_d2h_rsp_chk,

    input [(`CX_CXL_CACHE_D2H_DATA_IFNUM*`CX_CXL_CACHE_D2H_DATA_CHK_SIZE)-1:0]  cxl_slv_d2h_data_chk

    ,
    // -------------------------------------------------------------------------------------
    // CXL.Cache Host Slave (Root Complex TX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    output [`CX_CXL_CACHE_H2D_REQ_IFNUM-1:0]                 cxl_slv_h2d_req_crd,

    output [`CX_CXL_CACHE_H2D_RESP_IFNUM-1:0]                cxl_slv_h2d_rsp_crd,

    output [`CX_CXL_CACHE_H2D_DATA_IFNUM-1:0]                cxl_slv_h2d_data_crd,

    input [(`CX_CXL_CACHE_H2D_REQ_IFNUM*`CX_CXL_CACHE_H2D_REQ_SIZE)-1:0]  cxl_slv_h2d_req,

    input [(`CX_CXL_CACHE_H2D_RESP_IFNUM*`CX_CXL_CACHE_H2D_RESP_SIZE)-1:0]  cxl_slv_h2d_rsp,

    input [(`CX_CXL_CACHE_H2D_DATA_IFNUM*`CX_CXL_CACHE_H2D_DATA_SIZE)-1:0]  cxl_slv_h2d_data,

    input [(`CX_CXL_CACHE_H2D_REQ_IFNUM*`CX_CXL_CACHE_H2D_REQ_CHK_SIZE)-1:0]  cxl_slv_h2d_req_chk,

    input [(`CX_CXL_CACHE_H2D_RESP_IFNUM*`CX_CXL_CACHE_H2D_RESP_CHK_SIZE)-1:0]  cxl_slv_h2d_rsp_chk,

    input [(`CX_CXL_CACHE_H2D_DATA_IFNUM*`CX_CXL_CACHE_H2D_DATA_CHK_SIZE)-1:0]  cxl_slv_h2d_data_chk,

    // -------------------------------------------------------------------------------------
    // CXL.Cache Device Master (Endpoint RX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    input [`CX_CXL_CACHE_D2H_REQ_IFNUM-1:0]                                          cxl_mst_d2h_req_crd,

    input [`CX_CXL_CACHE_D2H_RESP_IFNUM-1:0]                                         cxl_mst_d2h_rsp_crd,

    input [`CX_CXL_CACHE_D2H_DATA_IFNUM-1:0]                                         cxl_mst_d2h_data_crd,

    output [(`CX_CXL_CACHE_D2H_REQ_IFNUM*`CX_CXL_CACHE_D2H_REQ_SIZE)-1:0]        cxl_mst_d2h_req,

    output [(`CX_CXL_CACHE_D2H_RESP_IFNUM*`CX_CXL_CACHE_D2H_RESP_SIZE)-1:0]      cxl_mst_d2h_rsp,

    output [(`CX_CXL_CACHE_D2H_DATA_IFNUM*`CX_CXL_CACHE_D2H_DATA_SIZE)-1:0]      cxl_mst_d2h_data

    ,
    output [(`CX_CXL_CACHE_D2H_REQ_IFNUM*`CX_CXL_CACHE_D2H_REQ_CHK_SIZE)-1:0]    cxl_mst_d2h_req_chk,

    output [(`CX_CXL_CACHE_D2H_RESP_IFNUM*`CX_CXL_CACHE_D2H_RESP_CHK_SIZE)-1:0]  cxl_mst_d2h_rsp_chk,

    output [(`CX_CXL_CACHE_D2H_DATA_IFNUM*`CX_CXL_CACHE_D2H_DATA_CHK_SIZE)-1:0]  cxl_mst_d2h_data_chk

    ,
    // -------------------------------------------------------------------------------------
    // CXL Protocol Master RX Mem Link initialization Interface
    // -------------------------------------------------------------------------------------
    output                                                  cxl_mem_mst_req,

    input                                                   cxl_mem_mst_ack,

    // -------------------------------------------------------------------------------------
    // CXL Protocol Slave TX Mem Link initialization Interface
    // -------------------------------------------------------------------------------------
    input                                                   cxl_mem_slv_req,

    input                                                   cxl_mem_app_pending,

    output                                                  cxl_mem_slv_ack

    ,
    // -------------------------------------------------------------------------------------
    // CXL.Mem Host Master (Root Complex RX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    input [`CX_CXL_MEM_M2S_NDR_IFNUM-1:0]                   cxl_mst_m2s_req_crd,

    input [`CX_CXL_MEM_M2S_DATA_IFNUM-1:0]                 cxl_mst_m2s_rwd_crd,

    output [(`CX_CXL_MEM_M2S_NDR_IFNUM*`CX_CXL_MEM_M2S_NDR_SIZE)-1:0]  cxl_mst_m2s_req,

    output [(`CX_CXL_MEM_M2S_DATA_IFNUM*`CX_CXL_MEM_M2S_DATA_SIZE)-1:0]  cxl_mst_m2s_rwd,

    output [(`CX_CXL_MEM_M2S_NDR_IFNUM*`CX_CXL_MEM_M2S_NDR_CHK_SIZE)-1:0]  cxl_mst_m2s_req_chk,

    output [(`CX_CXL_MEM_M2S_DATA_IFNUM*`CX_CXL_MEM_M2S_DATA_CHK_SIZE)-1:0]  cxl_mst_m2s_rwd_chk,


    // -------------------------------------------------------------------------------------
    // CXL.Mem Device Slave (Endpoint TX) Message Channel Interface
    // -------------------------------------------------------------------------------------

    output [`CX_CXL_MEM_S2M_NDR_IFNUM-1:0]                  cxl_slv_s2m_ndr_crd,

    output [`CX_CXL_MEM_S2M_DATA_IFNUM-1:0]                 cxl_slv_s2m_drc_crd,

    input [(`CX_CXL_MEM_S2M_NDR_IFNUM*`CX_CXL_MEM_S2M_NDR_SIZE)-1:0]  cxl_slv_s2m_ndr,

    input [(`CX_CXL_MEM_S2M_DATA_IFNUM*`CX_CXL_MEM_S2M_DATA_SIZE)-1:0]  cxl_slv_s2m_drc

    ,
    input [(`CX_CXL_MEM_S2M_NDR_IFNUM*`CX_CXL_MEM_S2M_NDR_CHK_SIZE)-1:0]  cxl_slv_s2m_ndr_chk,

    input [(`CX_CXL_MEM_S2M_DATA_IFNUM*`CX_CXL_MEM_S2M_DATA_CHK_SIZE)-1:0]  cxl_slv_s2m_drc_chk

    ,
    // -------------------------------------------------------------------------------------
    // CXL.Mem Host Slave (Root Complex TX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    output [`CX_CXL_MEM_M2S_NDR_IFNUM-1:0]                   cxl_slv_m2s_req_crd,

    output [`CX_CXL_MEM_M2S_DATA_IFNUM-1:0]                  cxl_slv_m2s_rwd_crd,

    input [(`CX_CXL_MEM_M2S_NDR_IFNUM*`CX_CXL_MEM_M2S_NDR_SIZE)-1:0]  cxl_slv_m2s_req,

    input [(`CX_CXL_MEM_M2S_DATA_IFNUM*`CX_CXL_MEM_M2S_DATA_SIZE)-1:0]  cxl_slv_m2s_rwd,

    input [(`CX_CXL_MEM_M2S_NDR_IFNUM*`CX_CXL_MEM_M2S_NDR_CHK_SIZE)-1:0]  cxl_slv_m2s_req_chk,

    input [(`CX_CXL_MEM_M2S_DATA_IFNUM*`CX_CXL_MEM_M2S_DATA_CHK_SIZE)-1:0]  cxl_slv_m2s_rwd_chk,

    // -------------------------------------------------------------------------------------
    // CXL.Mem Device Master (Endpoint RX) Message Channel Interface
    // -------------------------------------------------------------------------------------

    input [`CX_CXL_MEM_S2M_NDR_IFNUM-1:0]                                      cxl_mst_s2m_ndr_crd,

    input [`CX_CXL_MEM_S2M_DATA_IFNUM-1:0]                                     cxl_mst_s2m_drc_crd,

    output [(`CX_CXL_MEM_S2M_NDR_IFNUM*`CX_CXL_MEM_S2M_NDR_SIZE)-1:0]      cxl_mst_s2m_ndr,

    output [(`CX_CXL_MEM_S2M_DATA_IFNUM*`CX_CXL_MEM_S2M_DATA_SIZE)-1:0]    cxl_mst_s2m_drc

    ,
    output [(`CX_CXL_MEM_S2M_NDR_IFNUM*`CX_CXL_MEM_S2M_NDR_CHK_SIZE)-1:0]  cxl_mst_s2m_ndr_chk,

    output [(`CX_CXL_MEM_S2M_DATA_IFNUM*`CX_CXL_MEM_S2M_DATA_CHK_SIZE)-1:0]  cxl_mst_s2m_drc_chk
// spyglass enable_block Topology_02
    ,
    output [(`CX_CXL_MEM_M2S_BI_RSP_IFNUM*`CX_CXL_MEM_M2S_BI_RSP_SIZE)-1:0]  cxl_mst_m2s_bi_rsp,

    input [`CX_CXL_MEM_M2S_BI_RSP_IFNUM-1:0]                                     cxl_mst_m2s_bi_rsp_crd,

    output [(`CX_CXL_MEM_M2S_BI_RSP_IFNUM*`CX_CXL_MEM_M2S_BI_RSP_CHK_SIZE)-1:0]  cxl_mst_m2s_bi_rsp_chk,

    input [(`CX_CXL_MEM_S2M_BI_SNP_IFNUM*`CX_CXL_MEM_S2M_BI_SNP_SIZE)-1:0]  cxl_slv_s2m_bi_snp,

    output [`CX_CXL_MEM_S2M_BI_SNP_IFNUM-1:0]  cxl_slv_s2m_bi_snp_crd

    ,
    input [(`CX_CXL_MEM_S2M_BI_SNP_IFNUM*`CX_CXL_MEM_S2M_BI_SNP_CHK_SIZE)-1:0]  cxl_slv_s2m_bi_snp_chk

    ,
    input [(`CX_CXL_MEM_M2S_BI_RSP_IFNUM*`CX_CXL_MEM_M2S_BI_RSP_SIZE)-1:0]     cxl_slv_m2s_bi_rsp,

    output [`CX_CXL_MEM_M2S_BI_RSP_IFNUM-1:0]                                      cxl_slv_m2s_bi_rsp_crd,

    input [(`CX_CXL_MEM_M2S_BI_RSP_IFNUM*`CX_CXL_MEM_M2S_BI_RSP_CHK_SIZE)-1:0]  cxl_slv_m2s_bi_rsp_chk,

    output [(`CX_CXL_MEM_S2M_BI_SNP_IFNUM*`CX_CXL_MEM_S2M_BI_SNP_SIZE)-1:0]     cxl_mst_s2m_bi_snp,

    input [`CX_CXL_MEM_S2M_BI_SNP_IFNUM-1:0]                                       cxl_mst_s2m_bi_snp_crd

    ,
    output [(`CX_CXL_MEM_S2M_BI_SNP_IFNUM*`CX_CXL_MEM_S2M_BI_SNP_CHK_SIZE)-1:0]  cxl_mst_s2m_bi_snp_chk
    // -------------------------------------------------------------------------------------
    // CXL Controller RAS Statistics Interface Signals
    // -------------------------------------------------------------------------------------
    ,
    input [1:0]                                                  cxl_ras_stat_rx_corr,

    input [7:0]                                                  cxl_ras_stat_rx_uncorr,

    input [`CX_CXL_RAS_HDR_LOG_SIZE-1:0]                         cxl_ras_stat_rx_hdr_log
    // -------------------------------------------------------------------------------------
    // Control Signals from the CXL Flex Bus Device DVSEC
    // -------------------------------------------------------------------------------------
    ,
    output [`CX_CXL_NLD_PLUS_1-1:0]                                     cfg_cxl_dev_mem_enable,
    output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                cfg_cxl_dev_range1_mem_size_high,
    output [`CX_CXL_NLD_PLUS_1-1:0]                                     cfg_cxl_dev_range1_mem_info_valid,
    output [`CX_CXL_NLD_PLUS_1-1:0]                                     cfg_cxl_dev_range1_mem_active,
    output [(`CX_CXL_NLD_PLUS_1*5)-1:0]                                 cfg_cxl_dev_range1_desired_interleave,
    output [(`CX_CXL_NLD_PLUS_1*4)-1:0]                                 cfg_cxl_dev_range1_mem_size_low,
    output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                cfg_cxl_dev_range1_mem_base_high,
    output [(`CX_CXL_NLD_PLUS_1*4)-1:0]                                 cfg_cxl_dev_range1_mem_base_low,
    output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                cfg_cxl_dev_range2_mem_size_high,
    output [`CX_CXL_NLD_PLUS_1-1:0]                                     cfg_cxl_dev_range2_mem_info_valid,
    output [`CX_CXL_NLD_PLUS_1-1:0]                                     cfg_cxl_dev_range2_mem_active,
    output [(`CX_CXL_NLD_PLUS_1*5)-1:0]                                 cfg_cxl_dev_range2_desired_interleave,
    output [(`CX_CXL_NLD_PLUS_1*4)-1:0]                                 cfg_cxl_dev_range2_mem_size_low,
    output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                cfg_cxl_dev_range2_mem_base_high,
    output [(`CX_CXL_NLD_PLUS_1*4)-1:0]                                 cfg_cxl_dev_range2_mem_base_low
    ,
    output                                                              cfg_cxl_dev_cache_enable,
    output [4:0]                                                        cfg_cxl_dev_cache_sf_coverage,
    output [2:0]                                                        cfg_cxl_dev_cache_sf_granularity,
    output                                                              cfg_cxl_dev_cache_clean_eviction


    // -------------------------------------------------------------------------------------
    // CXL 2.0 Device DVSEC control signals
    // -------------------------------------------------------------------------------------
    ,
    output                              cfg_cxl_dev_disable_caching,
    output                              cfg_cxl_dev_initiate_cache_wr_invld,
    input                               cxl_dev_cache_invalid,
    input                               cxl_dev_cache_wr_invld_cmpl
    ,
    output [`CX_CXL_NLD_PLUS_1-1:0]     cfg_cxl_dev_post_cold_rst_volatile_hdm_default,
    output [`CX_CXL_NLD_PLUS_1-1:0]     cfg_cxl_dev_post_warm_rst_volatile_hdm_default,
    output [`CX_CXL_NLD_PLUS_1-1:0]     cfg_cxl_dev_post_hot_rst_volatile_hdm_default,
    output [`CX_CXL_NLD_PLUS_1-1:0]     cfg_cxl_dev_post_hot_rst_volatile_hdm_desired,
    input [`CX_CXL_NLD_PLUS_1-1:0]     cxl_volatile_hdm_error
    ,
    input                               cxl_pm_init_cmpl


    // -------------------------------------------------------------------------------------
    // CXL Error Status Signals
    // -------------------------------------------------------------------------------------
    ,
    output [6:0]                                                        cfg_cxl_mbar0_corr_err,
    output [16:0]                                                       cfg_cxl_mbar0_uncorr_err,
    output [31:0]                                                       cfg_cxl_pl_reg_fatal_err

    // -------------------------------------------------------------------------------------
    // Signals from the CXL 2.0 Extension DVSEC Register
    // -------------------------------------------------------------------------------------
    ,
    output [3:0]                                                         cfg_cxl_2_0_ext_port_ctl_ovr,
    output [7:0]                                                         cfg_cxl_2_0_ext_alt_bus_base,
    output [7:0]                                                         cfg_cxl_2_0_ext_alt_bus_limit,
    output [11:0]                                                        cfg_cxl_2_0_ext_alt_mem_base,
    output [11:0]                                                        cfg_cxl_2_0_ext_alt_mem_limit,
    output [11:0]                                                        cfg_cxl_2_0_ext_alt_pref_mem_base,
    output [11:0]                                                        cfg_cxl_2_0_ext_alt_pref_mem_limit,
    output [31:0]                                                        cfg_cxl_2_0_ext_alt_pref_mem_base_high,
    output [31:0]                                                        cfg_cxl_2_0_ext_alt_pref_mem_limit_high,
    output                                                               cfg_cxl_2_0_ext_rcrb_en,
    output [18:0]                                                        cfg_cxl_2_0_ext_rcrb_base_addr_low,
    output [31:0]                                                        cfg_cxl_2_0_ext_rcrb_base_addr_high
    // -------------------------------------------------------------------------------------
    // Signals from the CXL Register Locator DVSEC Register
    // -------------------------------------------------------------------------------------
    ,
    output [(`CX_CXL_NLD_PLUS_1*3)-1:0]                                  cfg_cxl_reg_locator_reg1_bir,
    output [(`CX_CXL_NLD_PLUS_1*8)-1:0]                                  cfg_cxl_reg_locator_reg1_blk_identifier,
    output [(`CX_CXL_NLD_PLUS_1*16)-1:0]                                 cfg_cxl_reg_locator_reg1_blk_offset_low,
    output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                 cfg_cxl_reg_locator_reg1_blk_offset_high,
    output [(`CX_CXL_NLD_PLUS_1*3)-1:0]                                  cfg_cxl_reg_locator_reg2_bir,
    output [(`CX_CXL_NLD_PLUS_1*8)-1:0]                                  cfg_cxl_reg_locator_reg2_blk_identifier,
    output [(`CX_CXL_NLD_PLUS_1*16)-1:0]                                 cfg_cxl_reg_locator_reg2_blk_offset_low,
    output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                 cfg_cxl_reg_locator_reg2_blk_offset_high,
    output [(`CX_CXL_NLD_PLUS_1*3)-1:0]                                  cfg_cxl_reg_locator_reg3_bir,
    output [(`CX_CXL_NLD_PLUS_1*8)-1:0]                                  cfg_cxl_reg_locator_reg3_blk_identifier,
    output [(`CX_CXL_NLD_PLUS_1*16)-1:0]                                 cfg_cxl_reg_locator_reg3_blk_offset_low,
    output [(`CX_CXL_NLD_PLUS_1*32)-1:0]                                 cfg_cxl_reg_locator_reg3_blk_offset_high
    // -------------------------------------------------------------------------------------
    // Signals from the CXL Port GPF DVSEC Register
    // -------------------------------------------------------------------------------------
    ,
    output [3:0]                                                          cfg_cxl_gpf_port_p1_timeout_base,
    output [3:0]                                                          cfg_cxl_gpf_port_p1_timeout_scale,
    output [3:0]                                                          cfg_cxl_gpf_port_p2_timeout_base,
    output [3:0]                                                          cfg_cxl_gpf_port_p2_timeout_scale

    ,
    // -------------------------------------------------------------------------------------
    // CXL Retry Buffer RAM Interface
    // -------------------------------------------------------------------------------------
    output [(`CX_CXL_RBUF_RAM_ADDRW - 1) : 0]   cxl_rbuf_ram_addr  ,

    output                           cxl_rbuf_ram_addr_par  ,

    output                           cxl_rbuf_ram_en    ,

    output                           cxl_rbuf_ram_we   ,

    output [(`CX_CXL_RBUF_RAM_DATAW - 1) : 0]  cxl_rbuf_ram_wdata ,

    input  [(`CX_CXL_RBUF_RAM_DATAW - 1) : 0]  cxl_rbuf_ram_rdata

    ,
    output [`CX_CXL_MST_HD_REQ_RESP_RAM_NUM-1:0]              cxl_mst_hreq_drsp_ram_we         ,

    output [(`CX_CXL_MST_HD_REQ_RESP_RAM_NUM*`CX_CXL_MST_HREQ_DRESP_RAM_ADDRW)-1 : 0]               cxl_mst_hreq_drsp_ram_wr_addr    ,

    output [`CX_CXL_MST_HD_REQ_RESP_RAM_NUM-1:0]             cxl_mst_hreq_drsp_ram_wr_addr_par ,

    output [(`CX_CXL_MST_HD_REQ_RESP_RAM_NUM*`CX_CXL_MST_HREQ_DRESP_RAM_DATAW)-1 : 0]               cxl_mst_hreq_drsp_ram_wdata      ,

    output [(`CX_CXL_MST_HD_REQ_RESP_RAM_NUM*`CX_CXL_MST_HREQ_DRESP_RAM_ADDRW)-1 : 0]               cxl_mst_hreq_drsp_ram_rd_addr    ,

    output [`CX_CXL_MST_HD_REQ_RESP_RAM_NUM-1:0]         cxl_mst_hreq_drsp_ram_rd_addr_par ,

    output [`CX_CXL_MST_HD_REQ_RESP_RAM_NUM-1:0]         cxl_mst_hreq_drsp_ram_rd         ,

    input [(`CX_CXL_MST_HD_REQ_RESP_RAM_NUM*`CX_CXL_MST_HREQ_DRESP_RAM_DATAW)-1 : 0]              cxl_mst_hreq_drsp_ram_rdata      ,

    output [`CX_CXL_MST_HD_RESP_REQ_RAM_NUM-1:0]                            cxl_mst_hrsp_dreq_ram_we         ,

    output [(`CX_CXL_MST_HD_RESP_REQ_RAM_NUM*`CX_CXL_MST_HRESP_DREQ_RAM_ADDRW)-1 : 0]    cxl_mst_hrsp_dreq_ram_wr_addr    ,

    output [`CX_CXL_MST_HD_RESP_REQ_RAM_NUM-1:0]                           cxl_mst_hrsp_dreq_ram_wr_addr_par ,

    output [(`CX_CXL_MST_HD_RESP_REQ_RAM_NUM*`CX_CXL_MST_HRESP_DREQ_RAM_DATAW)-1 : 0]               cxl_mst_hrsp_dreq_ram_wdata      ,

    output [(`CX_CXL_MST_HD_RESP_REQ_RAM_NUM*`CX_CXL_MST_HRESP_DREQ_RAM_ADDRW)-1 : 0]               cxl_mst_hrsp_dreq_ram_rd_addr    ,

    output [`CX_CXL_MST_HD_RESP_REQ_RAM_NUM-1:0]                       cxl_mst_hrsp_dreq_ram_rd_addr_par ,

    output [`CX_CXL_MST_HD_RESP_REQ_RAM_NUM-1:0]                      cxl_mst_hrsp_dreq_ram_rd         ,

    input [(`CX_CXL_MST_HD_RESP_REQ_RAM_NUM*`CX_CXL_MST_HRESP_DREQ_RAM_DATAW)-1 : 0]               cxl_mst_hrsp_dreq_ram_rdata      ,

    output [`CX_CXL_MST_HD_DDATA_RAM_NUM-1:0]                                          cxl_mst_hd_data_ram_we         ,

    output [(`CX_CXL_MST_HD_DDATA_RAM_NUM*`CX_CXL_MST_HD_DATA_RAM_ADDRW-1) : 0]               cxl_mst_hd_data_ram_wr_addr    ,

    output  [`CX_CXL_MST_HD_DDATA_RAM_NUM-1:0]                                          cxl_mst_hd_data_ram_wr_addr_par ,

    output [(`CX_CXL_MST_HD_DDATA_RAM_NUM*`CX_CXL_MST_HD_DATA_RAM_DATAW)-1 : 0]               cxl_mst_hd_data_ram_wdata      ,

    output [(`CX_CXL_MST_HD_DDATA_RAM_NUM*`CX_CXL_MST_HD_DATA_RAM_ADDRW)-1 : 0]               cxl_mst_hd_data_ram_rd_addr    ,

    output  [`CX_CXL_MST_HD_DDATA_RAM_NUM-1:0]                                          cxl_mst_hd_data_ram_rd_addr_par ,

    output  [`CX_CXL_MST_HD_DDATA_RAM_NUM-1:0]                                         cxl_mst_hd_data_ram_rd         ,

    input  [(`CX_CXL_MST_HD_DDATA_RAM_NUM*`CX_CXL_MST_HD_DATA_RAM_DATAW)-1 : 0]               cxl_mst_hd_data_ram_rdata


    ,
    output [`CX_CXL_MST_MS_NDR_RAM_NUM-1:0]                                           cxl_mst_ms_ndr_ram_we         ,

    output [(`CX_CXL_MST_MS_NDR_RAM_NUM*`CX_CXL_MST_MS_NDR_RAM_ADDRW)-1 : 0]         cxl_mst_ms_ndr_ram_wr_addr    ,

    output [`CX_CXL_MST_MS_NDR_RAM_NUM-1:0]                                          cxl_mst_ms_ndr_ram_wr_addr_par ,

    output [(`CX_CXL_MST_MS_NDR_RAM_NUM*`CX_CXL_MST_MS_NDR_RAM_DATAW)-1 : 0]          cxl_mst_ms_ndr_ram_wdata      ,

    output [(`CX_CXL_MST_MS_NDR_RAM_NUM*`CX_CXL_MST_MS_NDR_RAM_ADDRW)-1 : 0]         cxl_mst_ms_ndr_ram_rd_addr    ,

    output [`CX_CXL_MST_MS_NDR_RAM_NUM-1:0]                                          cxl_mst_ms_ndr_ram_rd_addr_par ,

    output [`CX_CXL_MST_MS_NDR_RAM_NUM-1:0]                                          cxl_mst_ms_ndr_ram_rd         ,

    input  [(`CX_CXL_MST_MS_NDR_RAM_NUM*`CX_CXL_MST_MS_NDR_RAM_DATAW)-1 : 0]           cxl_mst_ms_ndr_ram_rdata      ,

    output [`CX_CXL_MST_MS_DDATA_RAM_NUM-1:0]                                          cxl_mst_ms_data_ram_we         ,

    output [(`CX_CXL_MST_MS_DDATA_RAM_NUM*`CX_CXL_MST_MS_DATA_RAM_ADDRW)-1 : 0]          cxl_mst_ms_data_ram_wr_addr    ,

    output  [`CX_CXL_MST_MS_DDATA_RAM_NUM-1 :0]                                         cxl_mst_ms_data_ram_wr_addr_par ,

    output [(`CX_CXL_MST_MS_DDATA_RAM_NUM*`CX_CXL_MST_MS_DATA_RAM_DATAW)-1 : 0]         cxl_mst_ms_data_ram_wdata      ,

    output [(`CX_CXL_MST_MS_DDATA_RAM_NUM*`CX_CXL_MST_MS_DATA_RAM_ADDRW)-1 : 0]        cxl_mst_ms_data_ram_rd_addr    ,

    output [`CX_CXL_MST_MS_DDATA_RAM_NUM-1:0]                                          cxl_mst_ms_data_ram_rd_addr_par ,

    output [`CX_CXL_MST_MS_DDATA_RAM_NUM-1:0]                                          cxl_mst_ms_data_ram_rd         ,

    input  [(`CX_CXL_MST_MS_DDATA_RAM_NUM*`CX_CXL_MST_MS_DATA_RAM_DATAW)-1 : 0]       cxl_mst_ms_data_ram_rdata

// spyglass disable_block Topology_02
// SMD: Direct connection from input port to output port
// SJ: RAM-based FIFO is implemented to buffer data on Data Message Channels which propagates data to RAM data inputs
    ,
    output [`CX_CXL_MST_MS_BI_RAM_NUM-1:0]                                          cxl_mst_ms_bi_ram_we        ,

    output [(`CX_CXL_MST_MS_BI_RAM_NUM * `CX_CXL_MST_MS_BI_RAM_ADDRW)-1 : 0]         cxl_mst_ms_bi_ram_wr_addr    ,

    output [`CX_CXL_MST_MS_BI_RAM_NUM-1:0]                                          cxl_mst_ms_bi_ram_wr_addr_par ,

    output [(`CX_CXL_MST_MS_BI_RAM_NUM * `CX_CXL_MST_MS_BI_RAM_DATAW)-1 : 0]          cxl_mst_ms_bi_ram_wdata      ,

    output [(`CX_CXL_MST_MS_BI_RAM_NUM * `CX_CXL_MST_MS_BI_RAM_ADDRW)-1 : 0]         cxl_mst_ms_bi_ram_rd_addr    ,

    output [`CX_CXL_MST_MS_BI_RAM_NUM-1:0]                                          cxl_mst_ms_bi_ram_rd_addr_par ,

    output [`CX_CXL_MST_MS_BI_RAM_NUM-1:0]                                          cxl_mst_ms_bi_ram_rd         ,

    input [(`CX_CXL_MST_MS_BI_RAM_NUM * `CX_CXL_MST_MS_BI_RAM_DATAW)-1 : 0]         cxl_mst_ms_bi_ram_rdata

// spyglass enable_block Topology_02



    , output [5:0]                      cfg_neg_link_width


    ,output                             l0p_dynamic_rejected

    ,output                             cfg_l0p_dynamic_en 


//////////////////////////////////////////////////SPIF interface for CXL.cachemem/ARBMUX
//////////////////////////////////////////////////SPIF interface for PCIe/CXL.io
);
// ------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------
// Interface Signal Descriptions
// ------------------------------------------------------------------------------------------
wire                                      pm_hold_exit_l1;
wire                                      pm_link_exit_l1;
wire                                      pm_link_exit_l23;
wire                                      pm_pl_wake_ack;                 // PM Controller Wakeup Acknowledge
wire                                      pm_pl_clk_req;                  // PM Controller Clock Request
wire                                      pm_pl_phyinl1;                  // PM Controller PHY in L1
wire                                      pm_pl_phyinl2;                  // PM Controller PHY in L2
wire                                      cfg_pm_clk_pm_en;
wire                                      software_entr_l1;
wire                                      software_entr_l23;
wire                                      pm_aspm_l0s_en;                 // PME Controller indicates to the PM Protocol FSM that L0s ASPM is enabled
wire                                      pm_aspm_l1_en;                  // PME Controller indicates to the PM Protocol FSM that L1 ASPM is enabled
wire  [`CX_NFUNC-1:0]                     pm_radm_block_tlp;              // Instructs RADM receive filter to reject TLPs other than CFG/MSG
wire                                      int_pm_linkst_in_l0s;
wire                                      pm_linkst_in_l0;
usp_link_fsm_state_e                      pm_usp_link_state;              // PM Link connections with PM CTRL
dsp_link_fsm_state_e                      pm_dsp_link_state;              // PM Link connections with PM CTRL
usp_link_fsm_state_e                      shadow_pm_usp_link_state;       // PM CTRL connections with CDM
dsp_link_fsm_state_e                      shadow_pm_dsp_link_state;       // PM CTRL connections with CDM
wire                                      pm_wake_req_exit_l0s;
wire                                      pm_l2_entry_flag;
wire                                      pm_wake_any_if_pending;
wire                                      lp_pcie_l1_exit;              // SPIF: Request to PCIe/CXL.io Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
wire                                      lp_pcie_clk_ack;              // SPIF: PCIe/CXL.io Link Layer acknowledges LogPHY request to remove the clock gating
wire                                      lp_pcie_wake_req;             // SPIF: PCIe/CXL.io Link Layer requests LogPHY to remove the clock gating
wire                                      pl_pcie_wake_ack;             // SPIF: LogPHY acknowledges lp_wake_req to PCIe/CXL.io Link Layer
wire                                      pl_pcie_clk_req;              // SPIF: LogPHY requests PCIe/CXL.io Link Layer to remove the clock gating
wire                                      pl_pcie_phyinl1;              // SPIF: LogPHY indication on PCIe/CXL.io SPIF interface that PHY is in L1 state
wire                                      pl_pcie_phyinl2;              // SPIF: LogPHY indication on PCIe/CXL.io SPIF interface that PHY is in L2 state
wire                                      pl_pcie_state_l1;             // SPIF: pl_state_sts is in IDLE_L1_1 on PCIe/CXL.io SPIF interface
wire                                      pl_pcie_state_l2;             // SPIF: pl_state_sts is in L2 on PCIe/CXL.io SPIF interface
wire                                      pl_pcie_state_active;         // SPIF: pl_state_sts is in ACTIVE or ACTIVE_L0S_PMNAK on PCIe/CXL.io SPIF interface
wire                                      pl_pcie_link_up;              // SPIF: pl_link_up on PCIe/CXL.io SPIF interface
wire                                      lp_cxl_l1_exit;               // SPIF: Request to CXL.cachemem Link Layer to change requested from IDLE_L1_1 to ACTIVE and initiate L1 exit
wire                                      lp_cxl_clk_ack;               // SPIF: CXL.cachemem Link Layer acknowledges LogPHY request to remove the clock gating
wire                                      lp_cxl_wake_req;              // SPIF: CXL.cachemem Link Layer requests LogPHY to remove the clock gating
wire                                      pl_cxl_wake_ack;              // SPIF: LogPHY acknowledges lp_wake_req to CXL.cachemem Link Layer
wire                                      pl_cxl_clk_req;               // SPIF: LogPHY requests CXL.cachemem Link Layer to remove the clock gating
wire                                      pl_cxl_phyinl1;               // SPIF: LogPHY indication on CXL.cachemem SPIF interface that PHY is in L1 state
wire                                      pl_cxl_phyinl2;               // SPIF: LogPHY indication on CXL.cachemem SPIF interface that PHY is in L2 state
wire                                      pl_cxl_state_l1;              // SPIF: pl_state_sts is in IDLE_L1_1 on CXL.cachemem SPIF interface
wire                                      pl_cxl_state_l2;              // SPIF: pl_state_sts is in L2 on CXL.cachemem SPIF interface
wire                                      pl_cxl_mode_enable;           // SPIF: SPLH Configuration - CXL Mode Enable bit
wire                                      pm_xdlh_enter_l23;
wire                                      int_pm_l1_entry_started;
wire                                      pm_l1_in_progress;
wire                                      int_pm_aspm_l1_enter_ready;
wire                                      latch_as_entr_l1;
wire                                      pm_prot_idle_flag;
wire                                      lp_sdb_l1sub_aspm;
wire                                      lp_sdb_l1sub_pcipm;

logic   cfg_comm_clk_config;


wire  [4:0]                        cdm_pm_state_trans_tracker;
wire  pm_cdm_state_trans_track_t   pm_cdm_state_trans_tracking;
wire                               smlh_pm_state_trans1_flag;
wire                               smlh_pm_state_trans2_flag;
wire [9:0]                         cfg_flit_perf_interr_vec;


wire                               pm_pclkack_timeout;


ras_dp_err_inj_t ras_dp_err_inj;


wire cfg_rasdp_error_mode;          // indication that core is in RAS DP error mode
ras_dp_err_log_t axi_bridge_ras_dp_err_log;
logic            axi_bridge_in_ras_dp_err_inj_wake_up;
ras_dp_err_log_t hdma_ras_dp_err_log;
ras_dp_err_inj_t hdma_ras_dp_err_inj;

wire                             radm_trgt1_dv;
wire                             radm_trgt1_hv;
wire                             radm_trgt1_eot;
wire                             radm_trgt1_tlp_abort;
wire                             radm_trgt1_dllp_abort;
wire                             radm_trgt1_ecrc_err;
wire [`TRGT_DATA_WD-1:0]         radm_trgt1_data;
wire [`CX_RASDP_TRGT1_HDR_PROT_WD-1:0]radm_trgt1_hdr_prot;
wire [`CX_NW -1:0]               radm_trgt1_dwen;
wire [1:0]                       radm_trgt1_fmt;
wire [4:0]                       radm_trgt1_type;
wire [2:0]                       radm_trgt1_tc;
wire [`FLT_Q_ATTR_WIDTH-1:0]     radm_trgt1_attr;
wire [15:0]                      radm_trgt1_reqid;
wire [`CX_TAG_SIZE-1:0]          radm_trgt1_tag;
wire [`CX_NFUNC_WD-1:0]          radm_trgt1_func_num;
wire                             radm_trgt1_td;
wire                             radm_trgt1_poisoned;
wire [9:0]                       radm_trgt1_dw_len;
wire [3:0]                       radm_trgt1_first_be;
wire [3:0]                       radm_trgt1_last_be;
wire [`FLT_Q_ADDR_WIDTH -1:0]    radm_trgt1_addr;
wire [`FLT_Q_ADDR_WIDTH -1:0]    radm_trgt1_hdr_uppr_bytes;
wire                             radm_trgt1_rom_in_range;
wire [2:0]                       radm_trgt1_in_membar_range;
wire                             radm_trgt1_io_req_in_range;
wire [2:0]                       radm_trgt1_cpl_status;
wire [1:0]                       radm_trgt1_ats;
wire                             radm_trgt1_nw;
wire                             radm_trgt1_cxlsrc;
wire [`CX_PRFX_W_PAR-1:0]        radm_trgt1_tlp_prfx;
wire                             radm_trgt1_th;
wire [1:0]                       radm_trgt1_ph;
wire [7:0]                       radm_trgt1_st;
wire [(`CX_NVC*3)-1:0]           bridge_trgt1_radm_pkt_halt;

wire                             radm_trgt1_bcm;
wire                             radm_trgt1_cpl_last;
wire [11:0]                      radm_trgt1_byte_cnt;
wire [15:0]                      radm_trgt1_cmpltr_id;


wire    [31:0]                      slv_dbi_addr;                   // address in DBI interface
wire    [31:0]                      slv_dbi_din;                    // wire  data in DBI interface
wire                                slv_dbi_cs;                     // Chip select to program configuration space registers
wire                                slv_dbi_cs2;                    // Chip select2 wire  for DBI bus. Used for changing
wire    [3:0]                       slv_dbi_wr;                     // Byte write enable
wire    [`CX_NFUNC_WD-1:0]          slv_dbi_func_num;               // Function number of the DBI access
wire    [2:0]                       slv_dbi_bar_num;                // BAR number of the DBI access
wire                                slv_dbi_rom_access;             // ROM BAR of the DBI access
wire                                slv_dbi_io_access;              // IO BAR of the DBI access
wire                                slv_lbc_dbi_ack;                // When asserted, indicates that the read/write operation
                                                                    // is completed.
wire    [31:0]                      slv_lbc_dbi_dout;               // Register read back data bus


wire                                radm_trgt1_hdr_uppr_bytes_valid_i;

wire                               cfg_acs_validation_cap;
wire                               cfg_acs_at_blocking_cap;
wire                               cfg_acs_up_forward_cap;

wire [8:0]                            ras_prot_r_disable;
wire [6:0]                            ras_prot_t_disable;



wire                                pm_aux_clk;
wire [`CX_NVC_XALI_EXPANSION-1:0]   pm_xadm_client0_tlp_hv;
wire [`CX_NVC_XALI_EXPANSION-1:0]   pm_xadm_client1_tlp_hv;
wire [`CX_NVC_XALI_EXPANSION-1:0]   pm_xadm_client2_tlp_hv;

wire                                pm_aux_clk_active;

wire [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_th;
wire [(`CX_NVC_XALI_EXPANSION*2)-1:0]      client0_tlp_ph;
wire [(`CX_NVC_XALI_EXPANSION*8)-1:0]      client0_tlp_st;

wire [`CX_NVC_XALI_EXPANSION-1:0]          client0_addr_align_en;
wire [(`CX_NVC_XALI_EXPANSION*8)-1:0]      client0_tlp_byte_en;
wire [(`CX_NVC_XALI_EXPANSION*16)-1:0]     client0_remote_req_id;
wire [(`CX_NVC_XALI_EXPANSION*12)-1:0]     client0_cpl_byte_cnt;
wire [(`CX_NVC_XALI_EXPANSION*3)-1:0]      client0_tlp_tc;
wire [(`CX_NVC_XALI_EXPANSION*`FLT_Q_ATTR_WIDTH)-1:0]client0_tlp_attr;
wire [(`CX_NVC_XALI_EXPANSION*2)-1:0]      client0_tlp_ats;
wire [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_nw;
// The NW bit is not supported in the AMBA bridge for completions
//assign client0_tlp_nw = {`CX_NVC_XALI_EXPANSION{1'b0}};
wire [(`CX_NVC_XALI_EXPANSION*`CX_PRFX_DW)-1:0]client0_tlp_prfx;
wire [(`CX_NVC_XALI_EXPANSION*3)-1:0]      client0_cpl_status;
wire [`CX_NVC_XALI_EXPANSION-1:0]          client0_cpl_bcm;
wire [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_dv;
wire [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_eot;
wire [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_bad_eot;
wire [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_hv;
wire [(`CX_NVC_XALI_EXPANSION*2)-1:0]      client0_tlp_fmt;
wire [(`CX_NVC_XALI_EXPANSION*5)-1:0]      client0_tlp_type;
wire [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_td;
wire [`CX_NVC_XALI_EXPANSION-1:0]          client0_tlp_ep;
wire [(`CX_NVC_XALI_EXPANSION*13)-1:0]     client0_tlp_byte_len;
wire [(`CX_NVC_XALI_EXPANSION*`CLIENT_HDR_PROT_WD)-1:0] client0_hdr_prot;
// LMD: Undriven net Range
// LJ: The function swap_addr_par is assigned to a signal client0_tlp_addr where the result come through two "for" statement intercalated
// leda NTL_CON12 off
wire [(`CX_NVC_XALI_EXPANSION*64)-1:0]    client0_tlp_addr;
// leda NTL_CON12 on
wire [(`CX_NVC_XALI_EXPANSION*`CX_TAG_SIZE)-1:0]client0_tlp_tid;
// LMD: Undriven net Range
// LJ: The function swap_data_par is assigned to a signal client0_tlp_data where the result come through two "for" statement intercalated
// leda NTL_CON12 off
wire [(`CX_NVC_XALI_EXPANSION*`TRGT_DATA_WD)-1:0]client0_tlp_data;
// leda NTL_CON12 on
wire [(`CX_NVC_XALI_EXPANSION*`CX_NFUNC_WD)-1:0] client0_tlp_func_num;
  // Client0 DMA Wr Eng only
wire  [(`CX_NVC_XALI_EXPANSION*`DC_DMA_TYPE_WIDTH)-1:0]         client0_tlp_dma;
wire  [(`CX_NVC_XALI_EXPANSION*`CC_NUM_DMA_MAX_CHAN_WIDTH)-1:0] client0_tlp_dma_channel;
wire [(`CX_NVC_XALI_EXPANSION*`CX_REMOTE_LOOKUPID_WD)-1:0]client0_cpl_lookup_id;
wire [`CX_NVC_XALI_EXPANSION-1:0]          xadm_client0_halt;

// XALI1 interface
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client1_addr_align_en;
wire [(`CX_NVC_XALI_EXPANSION*8)-1:0]                       client1_tlp_byte_en;
wire [(`CX_NVC_XALI_EXPANSION*16)-1:0]                      client1_remote_req_id;
wire [(`CX_NVC_XALI_EXPANSION*3)-1:0]                       client1_cpl_status;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client1_cpl_bcm;
wire [(`CX_NVC_XALI_EXPANSION*12)-1:0]                      client1_cpl_byte_cnt;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client1_tlp_dv;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client1_tlp_eot;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client1_tlp_bad_eot;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client1_tlp_hv;
wire [(`CX_NVC_XALI_EXPANSION*2)-1:0]                       client1_tlp_fmt;
wire [(`CX_NVC_XALI_EXPANSION*5)-1:0]                       client1_tlp_type;
wire [(`CX_NVC_XALI_EXPANSION*3)-1:0]                       client1_tlp_tc;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client1_tlp_td;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client1_tlp_ep;
wire [(`CX_NVC_XALI_EXPANSION*`FLT_Q_ATTR_WIDTH)-1:0]       client1_tlp_attr;
wire [(`CX_NVC_XALI_EXPANSION*2)-1:0]                       client1_tlp_ats;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client1_tlp_nw;
wire [(`CX_NVC_XALI_EXPANSION*`CX_PRFX_DW)-1:0]             client1_tlp_prfx;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client1_tlp_th;
wire [(`CX_NVC_XALI_EXPANSION*2)-1:0]                       client1_tlp_ph;
wire [(`CX_NVC_XALI_EXPANSION*8)-1:0]                       client1_tlp_st;

wire [(`CX_NVC_XALI_EXPANSION*13)-1:0]                      client1_tlp_byte_len;
wire [(`CX_NVC_XALI_EXPANSION*`CX_TAG_SIZE)-1:0]            client1_tlp_tid;
wire [(`CX_NVC_XALI_EXPANSION*`CLIENT_HDR_PROT_WD)-1:0]      client1_hdr_prot;
// LMD: Undriven net Range
// LJ: The function swap_addr_par is assigned to a signal client1_tlp_addr where the result come through two "for" statement intercalated
// leda NTL_CON12 off
wire [(`CX_NVC_XALI_EXPANSION*64)-1:0]                      client1_tlp_addr;
// leda NTL_CON12 on
// LMD: Undriven net Range
// LJ: The function swap_data_par is assigned to a signal client1_tlp_data where the result come through two "for" statement intercalated
// leda NTL_CON12 off
wire [(`CX_NVC_XALI_EXPANSION*`TRGT_DATA_WD)-1:0]           client1_tlp_data;
// leda NTL_CON12 on
wire [(`CX_NVC_XALI_EXPANSION*`CX_NFUNC_WD)-1:0]            client1_tlp_func_num;
   // Client 1 DMA Rd Eng only with HDMA, DMA Rd Eng req and Both Eng MSI with eDMA
wire  [(`CX_NVC_XALI_EXPANSION*`DC_DMA_TYPE_WIDTH)-1:0]         client1_tlp_dma;
wire  [(`CX_NVC_XALI_EXPANSION*`CC_NUM_DMA_MAX_CHAN_WIDTH)-1:0] client1_tlp_dma_channel;
wire [(`CX_NVC_XALI_EXPANSION*`CX_REMOTE_LOOKUPID_WD)-1:0]  client1_cpl_lookup_id;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           xadm_client1_halt;
// XALI2 interface
wire [(`CX_NVC_XALI_EXPANSION*`CX_REMOTE_LOOKUPID_WD)-1:0]  client2_cpl_lookup_id;
  // Client 2 not used by DMA, only here for interface completeness
wire  [(`CX_NVC_XALI_EXPANSION*`DC_DMA_TYPE_WIDTH)-1:0]         client2_tlp_dma;
wire  [(`CX_NVC_XALI_EXPANSION*`CC_NUM_DMA_MAX_CHAN_WIDTH)-1:0] client2_tlp_dma_channel;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client2_addr_align_en;
wire [(`CX_NVC_XALI_EXPANSION*8)-1:0]                       client2_tlp_byte_en;
wire [(`CX_NVC_XALI_EXPANSION*16)-1:0]                      client2_remote_req_id;
wire [(`CX_NVC_XALI_EXPANSION*3)-1:0]                       client2_cpl_status;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client2_cpl_bcm;
wire [(`CX_NVC_XALI_EXPANSION*12)-1:0]                      client2_cpl_byte_cnt;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client2_tlp_dv;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client2_tlp_eot;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client2_tlp_bad_eot;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client2_tlp_hv;
wire [(`CX_NVC_XALI_EXPANSION*2)-1:0]                       client2_tlp_fmt;
wire [(`CX_NVC_XALI_EXPANSION*5)-1:0]                       client2_tlp_type;
wire [(`CX_NVC_XALI_EXPANSION*3)-1:0]                       client2_tlp_tc;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client2_tlp_td;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client2_tlp_ep;
wire [(`CX_NVC_XALI_EXPANSION*`FLT_Q_ATTR_WIDTH)-1:0]       client2_tlp_attr;
wire [(`CX_NVC_XALI_EXPANSION*13)-1:0]                      client2_tlp_byte_len;
wire [(`CX_NVC_XALI_EXPANSION*`CX_TAG_SIZE)-1:0]            client2_tlp_tid;
wire [(`CX_NVC_XALI_EXPANSION*`CLIENT_HDR_PROT_WD)-1:0]      client2_hdr_prot;
// LMD: Undriven net Range
// LJ: The function swap_addr_par is assigned to a signal client2_tlp_addr where the result come through two "for" statement intercalated
// leda NTL_CON12 off
wire [(`CX_NVC_XALI_EXPANSION*64)-1:0]                      client2_tlp_addr;
// leda NTL_CON12 on
// LMD: Undriven net Range
// LJ: The function swap_data_par is assigned to a signal client2_tlp_data where the result come through two "for" statement intercalated
// leda NTL_CON12 off
wire [(`CX_NVC_XALI_EXPANSION*`TRGT_DATA_WD)-1:0]           client2_tlp_data;
// leda NTL_CON12 on
wire [(`CX_NVC_XALI_EXPANSION*`CX_NFUNC_WD)-1:0]            client2_tlp_func_num;
wire [(`CX_NVC_XALI_EXPANSION*2)-1:0]                       client2_tlp_ats;
wire [`CX_NVC_XALI_EXPANSION-1:0]                           client2_tlp_nw;
wire    [`CX_NVC_XALI_EXPANSION-1:0]                        client2_tlp_th;
wire    [(`CX_NVC_XALI_EXPANSION*2)-1:0]                    client2_tlp_ph;
wire    [(`CX_NVC_XALI_EXPANSION*8)-1:0]                    client2_tlp_st;
wire [(`CX_NVC_XALI_EXPANSION*`CX_PRFX_DW)-1:0]             client2_tlp_prfx;
wire   [`CX_NVC_XALI_EXPANSION-1:0]                         client2_tlp_atu_bypass;
wire   [`CX_NVC_XALI_EXPANSION-1:0]                         xadm_client2_halt;
wire   [`CX_RASDP_BYPASS_HDR_PROT_WD_O_BASE:0] radm_bypass_hdr_prot_i;
wire   [`CX_NHQ*`CX_RASDP_BYPASS_HDR_PROT_WD-1:0] radm_bypass_hdr_prot;

// ------------------------------------------------------------------------------------------
// Internal Signal declaration
// ------------------------------------------------------------------------------------------

wire   [`TRGT_DATA_WD -1:0]        client0_tlp_data_i                 ;
wire   [`CX_NFUNC_WD-1:0]          client0_tlp_func_num_i             ;
wire                               client0_addr_align_en_i            ;
wire   [7:0]                       client0_tlp_byte_en_i              ;
wire   [2:0]                       client0_cpl_status_i               ;
wire                               client0_cpl_bcm_i                  ;
wire   [15:0]                      client0_remote_req_id_i            ;
wire   [11:0]                      client0_cpl_byte_cnt_i             ;
wire   [2:0]                       client0_tlp_tc_i                   ;
wire   [`FLT_Q_ATTR_WIDTH-1:0]     client0_tlp_attr_i                 ;
wire                               client0_tlp_dv_i                   ;
wire                               client0_tlp_eot_i                  ;
wire                               client0_tlp_bad_eot_i              ;
wire                               client0_tlp_hv_i                   ;
wire   [1:0]                       client0_tlp_fmt_i                  ;
wire   [4:0]                       client0_tlp_type_i                 ;
wire                               client0_tlp_td_i                   ;
wire                               client0_tlp_ep_i                   ;
wire   [12:0]                      client0_tlp_byte_len_i             ;
wire   [`CX_TAG_SIZE-1:0]          client0_tlp_tid_i                  ;
wire   [63:0]                      client0_tlp_addr_i                 ;
wire   [15:0]                      client0_req_id_i                   ;

wire                               client1_addr_align_en_i            ;
wire   [7:0]                       client1_tlp_byte_en_i              ;
wire   [2:0]                       client1_cpl_status_i               ;
wire                               client1_cpl_bcm_i                  ;
wire   [15:0]                      client1_remote_req_id_i            ;
wire   [11:0]                      client1_cpl_byte_cnt_i             ;
wire   [2:0]                       client1_tlp_tc_i                   ;
wire   [`FLT_Q_ATTR_WIDTH-1:0]     client1_tlp_attr_i                 ;
wire                               client1_tlp_dv_i                   ;
wire                               client1_tlp_eot_i                  ;
wire                               client1_tlp_bad_eot_i              ;
wire                               client1_tlp_hv_i                   ;
wire   [1:0]                       client1_tlp_fmt_i                  ;
wire   [4:0]                       client1_tlp_type_i                 ;
wire                               client1_tlp_td_i                   ;
wire                               client1_tlp_ep_i                   ;
wire   [12:0]                      client1_tlp_byte_len_i             ;
wire   [`CX_TAG_SIZE-1:0]          client1_tlp_tid_i                  ;
wire   [63:0]                      client1_tlp_addr_i                 ;
wire   [15:0]                      client1_req_id_i                   ;
wire   [`TRGT_DATA_WD -1:0]        client1_tlp_data_i                 ;
wire   [`CX_NFUNC_WD-1:0]          client1_tlp_func_num_i             ;
// Client2 XADM interconnect signals
wire                               client2_addr_align_en_i            ;
wire   [7:0]                       client2_tlp_byte_en_i              ;
wire   [2:0]                       client2_cpl_status_i               ;
wire                               client2_cpl_bcm_i                  ;
wire   [15:0]                      client2_remote_req_id_i            ;
wire   [11:0]                      client2_cpl_byte_cnt_i             ;
wire   [2:0]                       client2_tlp_tc_i                   ;
wire   [`FLT_Q_ATTR_WIDTH-1:0]     client2_tlp_attr_i                 ;
wire                               client2_tlp_dv_i                   ;
wire                               client2_tlp_eot_i                  ;
wire                               client2_tlp_bad_eot_i              ;
wire                               client2_tlp_hv_i                   ;
wire   [1:0]                       client2_tlp_fmt_i                  ;
wire   [4:0]                       client2_tlp_type_i                 ;
wire                               client2_tlp_td_i                   ;
wire                               client2_tlp_ep_i                   ;
wire   [12:0]                      client2_tlp_byte_len_i             ;
wire   [`CX_TAG_SIZE-1:0]          client2_tlp_tid_i                  ;
wire   [63:0]                      client2_tlp_addr_i                 ;
wire   [15:0]                      client2_req_id_i                   ;
wire   [`TRGT_DATA_WD -1:0]        client2_tlp_data_i                 ;
wire   [`CX_NFUNC_WD-1:0]          client2_tlp_func_num_i             ;

// START_IO:XALI0 Descriptions

wire   [1:0]                       client0_tlp_ats_i                  ;
wire                             client0_tlp_th_i;
wire [1:0]                       client0_tlp_ph_i;
wire [7:0]                       client0_tlp_st_i;
wire   [`CX_PRFX_DW-1:0]           client0_tlp_prfx_i                 ;
wire                               xadm_client0_halt_i                ;
wire [7:0]                         unconn_client0_non_dma_cpl_rmpd_lkup_id   ;
wire [`CX_REMOTE_LOOKUPID_WD-1:0]  client0_cpl_lookup_id_i            ;
wire [`CX_REMOTE_LOOKUPID_WD-1:0]  trgt_lookup_id_i                   ;

  // Client0 DMA Wr Eng only
wire  [`DC_DMA_TYPE_WIDTH-1:0]        client0_tlp_dma_i               ;
wire  [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0] client0_tlp_dma_channel_i      ;
wire  [`CX_NVC_XALI_EXPANSION-1:0]           client0_tlp_atu_bypass             ;
wire                               client0_tlp_atu_bypass_i           ;
// END_IO:XALI0 Descriptions

// START_IO:XALI1 Descriptions


wire   [1:0]                       client1_tlp_ats_i                  ;
wire                               client1_tlp_nw_i                   ;
wire  [`CX_PRFX_DW-1:0]            client1_tlp_prfx_i                 ;

wire                               client1_tlp_th_i                   ;
wire  [1:0]                        client1_tlp_ph_i                   ;
wire  [7:0]                        client1_tlp_st_i                   ;
wire                               xadm_client1_halt_i                ;
wire [`CX_REMOTE_LOOKUPID_WD-1:0]  client1_cpl_lookup_id_i            ;

   // Client 1 DMA Rd Eng only with HDMA, DMA Rd Eng req and Both Eng MSI with eDMA
wire  [`DC_DMA_TYPE_WIDTH-1:0]         client1_tlp_dma_i              ;
wire  [`CC_NUM_DMA_MAX_CHAN_WIDTH-1:0] client1_tlp_dma_channel_i      ;
wire  [`CX_NVC_XALI_EXPANSION-1:0] client1_tlp_atu_bypass             ;
wire                               client1_tlp_atu_bypass_i           ;
// END_IO:XALI1 Descriptions

// Client2 XADM interconnect signals
wire   [1:0]                       client2_tlp_ats_i                  ;
wire                               client2_tlp_nw_i                   ;
wire                               client2_tlp_th_i                   ;
wire [1:0]                         client2_tlp_ph_i                   ;
wire [7:0]                         client2_tlp_st_i                   ;
wire [`CX_REMOTE_LOOKUPID_WD-1:0]  client2_cpl_lookup_id_i            ;
wire                               client2_tlp_atu_bypass_i           ;
wire                               xadm_client2_halt_i                ;

//--------------------------------
//     TRGT1 Interface
//--------------------------------
wire [`TRGT_HDR_WD-1:0]           radm_trgt1_hdr_i                      ;
wire                              trgt1_radm_halt_i                     ;
wire                              radm_trgt1_hv_i                       ;
wire                              radm_trgt1_dv_i                       ;
wire                              radm_trgt1_eot_i                      ;
wire                              radm_trgt1_tlp_abort_i                ;
wire                              radm_trgt1_dllp_abort_i               ;
wire                              radm_trgt1_ecrc_err_i                 ;
wire  [`CX_PRFX_W_PAR-1:0]        radm_trgt1_tlp_prfx_i                 ;
wire                              radm_trgt1_th_i                       ;
wire [1:0]                        radm_trgt1_ph_i                       ;
wire [7:0]                        radm_trgt1_st_i                       ;
wire  [`TRGT_DATA_WD-1:0]         radm_trgt1_data_i                     ;
wire  [`CX_NW-1:0]                radm_trgt1_dwen_i                     ;
wire  [1:0]                       radm_trgt1_fmt_i                      ;
wire  [4:0]                       radm_trgt1_type_i                     ;
wire  [2:0]                       radm_trgt1_tc_i                       ;
wire  [`FLT_Q_ATTR_WIDTH-1:0]     radm_trgt1_attr_i                     ;
wire  [15:0]                      radm_trgt1_reqid_i                    ;
wire  [`CX_TAG_SIZE-1:0]          radm_trgt1_tag_i                      ;
wire  [`CX_NFUNC_WD-1:0]          radm_trgt1_func_num_i                 ;
wire [`CX_RASDP_TRGT1_HDR_PROT_WD-1:0] radm_trgt1_hdr_prot_i                ;
wire                              radm_trgt1_td_i                       ;
wire                              radm_trgt1_poisoned_i                 ;
wire  [9:0]                       radm_trgt1_dw_len_i                   ;
wire  [3:0]                       radm_trgt1_first_be_i                 ;
wire  [3:0]                       radm_trgt1_last_be_i                  ;
wire  [`FLT_Q_ADDR_WIDTH -1:0]    radm_trgt1_addr_i                     ;
wire [`FLT_Q_ADDR_WIDTH -1:0]     radm_trgt1_hdr_uppr_bytes_i;
wire [63:0]                       s_radm_trgt1_hdr_uppr_bytes;
wire  [`FLT_Q_ADDR_WIDTH -1:0]    radm_trgt1_addr_out_i                 ;
wire                              radm_trgt1_io_req_in_range_i          ;
wire                              radm_trgt1_rom_in_range_i             ;
wire  [2:0]                       radm_trgt1_in_membar_range_i          ;
wire  [2:0]                       radm_trgt1_cpl_status_i               ;
wire [1:0]                        radm_trgt1_ats_i                      ;
wire                              radm_trgt1_nw_i                       ;
wire                              radm_trgt1_cxlsrc_i                   ;
wire                              radm_trgt1_bcm_i                      ;
wire                              radm_trgt1_cpl_last_i                 ;
wire [11:0]                       radm_trgt1_byte_cnt_i                 ;
wire [15:0]                       radm_trgt1_cmpltr_id_i                ;
wire [`CC_P_XFER_DONE_WD-1:0]     brdg_trgt1_p_xfer_done                ;

wire                               trgt_cpl_lut_empty;


wire                                radm_cpl_timeout_i                  ;
wire                                radm_cpl_timeout_cdm_i              ;
wire    [`CX_NFUNC_WD-1:0]          radm_timeout_func_num_i             ;
wire    [2:0]                       radm_timeout_cpl_tc_i               ;
wire    [1:0]                       radm_timeout_cpl_attr_i             ;
wire    [11:0]                      radm_timeout_cpl_len_i              ;
wire    [`CX_TAG_SIZE-1:0]          radm_timeout_cpl_tag_i              ;
wire                                    brdg_mstr_xfer_pending           ;
wire                                    brdg_slv_flush_ack               ;
wire  [`CX_NVC_XALI_EXPANSION-1:0]      brdg_client0_tlp_hv              ;
wire  [`CX_NVC_XALI_EXPANSION-1:0]      brdg_client1_tlp_hv              ;
wire  [`CX_NVC_XALI_EXPANSION-1:0]      brdg_client2_tlp_hv              ;
wire                                    rstctl_slv_flush_req             ;
wire                                    rstctl_mstr_flush_req            ;
wire                                    rstctl_flush_done                ;


wire                               edma_client0_tlp_hv_i;
wire                               edma_client1_tlp_hv_i;

wire    [`CX_NVC-1:0]                   radm_pend_cpl_so                 ;
wire    [`CX_NVC-1:0]                   radm_q_cpl_not_empty             ;

wire    [2:0]                       current_data_rate;          // 0=running at gen1 speeds, 1=running at gen2 speeds

wire    [2:0]                       pm_current_data_rate_others;    // reg pm_current_data_rate using core_clk to resolve massive fan-out issues
wire    [2:0]                       int_pm_current_data_rate;


// RASDP error mode indication from cdm registers
wire cfg_rasdp_error_mode_i;
// RASDP error mode enable
wire cfg_rasdp_error_mode_en;
// RASDP error mode indication to application
assign cfg_rasdp_error_mode  = cfg_rasdp_error_mode_i; // drive the output directly from the register since the bypass interface is registered
wire                                pm_block_all_tlp;
wire [5:0]                          cfg_link_capable;
// declaration for multi-func purpose
//  output signals of cdm

wire     [15:0]                     cfg_err_resp;


wire [15:0]                                cfg_order_rule_ctrl;
wire [1:0]                                 cfg_ax_mstr_ordr_p_event_sel;
wire                                       cfg_ax_snp_en;
wire                                       cfg_axi_rchunk_disable;
wire [`CX_NVC-1:0]                         cfg_ib_p_id_mng_ctrl;
wire     [3:0]                                  cfg_mstr_arcache_mode;
wire     [3:0]                                  cfg_mstr_awcache_mode;
wire     [3:0]                                  cfg_mstr_arcache_value;
wire     [3:0]                                  cfg_mstr_awcache_value;
wire     [31:0]                                 cfg_aximstr_msg_addr_high;
wire     [31:0]                                 cfg_aximstr_msg_addr_low;
wire     [1:0]                                  cfg_mstr_ardomain_mode;
wire     [1:0]                                  cfg_mstr_awdomain_mode;
wire     [1:0]                                  cfg_mstr_ardomain_value;
wire     [1:0]                                  cfg_mstr_awdomain_value;
wire                                            cfg_ax_mstr_zeroread_fw;
wire                                            cfg_axi_clk_gating_en;
wire                                            cfg_memtype_value;
wire     [`FLT_Q_ADDR_WIDTH-3:0]                cfg_memtype_boundary;

// ATU outbound Region controls
wire      [5*`CX_ATU_OUT_NREGIONS_MIN1-1:0]              atu_reg_out_type;
wire      [`CX_NFUNC_WD*`CX_ATU_OUT_NREGIONS_MIN1-1:0]   atu_reg_out_func_num;
wire      [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                atu_reg_out_func_bypass;
wire      [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                atu_reg_out_snp;
// Mode Settings
wire      [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                atu_reg_out_invert;
// Region Enable
wire      [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                atu_reg_out_en;
// Base, Limit and Target Registers
wire      [`CX_ATU_REGION_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]atu_reg_out_base;
wire      [`CX_ATU_BASE_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]  atu_reg_out_upr_base;
wire      [`CX_ATU_REGION_WIDTH*`CX_ATU_OUT_NREGIONS_MIN1-1:0]atu_reg_out_limit;
wire      [`CX_ATU_MAX_REGION_SIZE*`CX_ATU_OUT_NREGIONS_MIN1-1:0]atu_reg_out_uppr_limit;
wire      [`CX_ATU_OUT_NREGIONS_MIN1-1:0]                     atu_reg_out_incr_rgn_size;    // Maximum region size control bit


//DMA interface wires

//CDM-CRGB interface
wire    [`CC_CRGB_DATA_WIDTH - 1:0]     crgb_cdm_rdata;
wire                                    crgb_cdm_cs;
wire                                    crgb_cdm_ack;
wire    [`CC_CRGB_ADDR_WIDTH - 1:0]     crgb_cdm_addr;
wire    [`CC_CRGB_DATA_WIDTH - 1:0]     crgb_cdm_wdata;
wire    [`CC_CRGB_BE_WIDTH - 1:0]       crgb_cdm_wr;
wire                                    crgb_cdm_source;
// Indicates to the received ompletion is the last one
wire  [`CX_NVC-1:0]                     radm_trgt1_cpl_lookup_id_rlsd;
// Indicates non-posted TLP
wire                                    radm_trgt1_lookup_id_consmd;

wire    [31:0]                      cfg_trgt_cpl_lut_delete_entry;  // trgt_cpl_lut delete one entry


wire int_trgt1_radm_halt;

wire int_radm_trgt1_mem_type;

wire trgt_lut_dma_pkt_halt;
wire radm_trgt1_dma_cpl_rlsd;

wire [`CX_PL_AUX_CLK_FREQ_WD-1:0]          cfg_pl_aux_clk_freq;

wire  [`CX_NFUNC-1:0]        cfg_dmwr_req_en;            // Deferrable Memory Write (DMWr) Requester Enable




xali_pkt_t[`N_XALI_IF-1:0] xali_xaim_pkt;
logic[`N_XALI_IF-1:0]      xaim_xali_halt;

    ///////////////////////////////////////////////////////
    // trgt1 p interfaces
    //
  wire [`TRGT_DATA_WD-1:0]      radm_trgt1_p_0_data;
  wire [`CX_RASDP_TRGT1_P_HDR_PROT_WD-1:0] radm_trgt1_p_0_hdr_prot;
  wire [`CX_PRFX_W_PAR-1:0]    radm_trgt1_p_0_prfx;
  wire [`CX_NW-1:0]            radm_trgt1_p_0_dwen;
  wire                         radm_trgt1_p_0_dv;
  wire                         radm_trgt1_p_0_hv;
  wire                         radm_trgt1_p_0_eot;
  wire                         radm_trgt1_p_0_tlp_abort;
  wire                         radm_trgt1_p_0_dllp_abort;
  wire                         radm_trgt1_p_0_ecrc_err;
  wire [1:0]                   radm_trgt1_p_0_fmt;
  wire [4:0]                   radm_trgt1_p_0_type;
  wire [2:0]                   radm_trgt1_p_0_tc;
  wire [`FLT_Q_ATTR_WIDTH-1:0] radm_trgt1_p_0_attr;
  wire [15:0]                  radm_trgt1_p_0_reqid;
  wire [`CX_TAG_SIZE-1:0]      radm_trgt1_p_0_tag;
  wire [`CX_NFUNC_WD-1:0]      radm_trgt1_p_0_func_num;
  wire                         radm_trgt1_p_0_td;
  wire [2:0]                   radm_trgt1_p_0_cpl_status;
  wire                         radm_trgt1_p_0_poisoned;
  wire [9:0]                   radm_trgt1_p_0_dw_len;
  wire [3:0]                   radm_trgt1_p_0_first_be;
  wire [`CX_NVC_LOG2-1:0]      radm_trgt1_p_0_vc_num;
  wire [`FLT_Q_ADDR_WIDTH-1:0] radm_trgt1_p_0_addr;
  wire [`FLT_Q_ADDR_WIDTH-1:0] radm_trgt1_p_0_hdr_uppr_bytes;
  wire                         radm_trgt1_p_0_rom_in_range;
  wire                         radm_trgt1_p_0_io_req_in_range;
  wire [2:0]                   radm_trgt1_p_0_in_membar_range;
  wire [3:0]                   radm_trgt1_p_0_last_be;
  wire [1:0]                   radm_trgt1_p_0_ats;
  wire                         radm_trgt1_p_0_nw;
  wire                         radm_trgt1_p_0_th;
  wire [1:0]                   radm_trgt1_p_0_ph;
  wire [7:0]                   radm_trgt1_p_0_st;
  wire                         radm_trgt1_p_0_hdr_uppr_bytes_valid;
  wire [8:0]                   radm_trgt1_p_0_dest_sgmt;
  wire [8:0]                   radm_trgt1_p_0_reqtr_sgmt;
  wire [`CX_RADM_PKT_ORD_WD-1:0]radm_trgt1_p_0_pkt_order_no;
  wire [`CX_ATU_IN_NREGIONS_MIN1-1:0]radm_trgt1_p_0_atu_sloc_match;
  wire [`CX_ATU_IN_NREGIONS_MIN1-1:0]radm_trgt1_p_0_atu_cbuf_err;
  wire                         radm_trgt1_p_0_pending;
  wire                         trgt1_radm_intf_p_0_halt;
    ////////////////////////////////////////////
    // trgt1 np interfaces
    //
  wire [`TRGT_DATA_WD-1:0]      radm_trgt1_np_0_data;
  wire [`CX_RASDP_TRGT1_NP_HDR_PROT_WD-1:0] radm_trgt1_np_0_hdr_prot;
  wire [`CX_PRFX_W_PAR-1:0]    radm_trgt1_np_0_prfx;
  wire [`CX_NW-1:0]            radm_trgt1_np_0_dwen;
  wire                         radm_trgt1_np_0_dv;
  wire                         radm_trgt1_np_0_hv;
  wire                         radm_trgt1_np_0_eot;
  wire                         radm_trgt1_np_0_dllp_abort;
  wire                         radm_trgt1_np_0_tlp_abort;
  wire                         radm_trgt1_np_0_ecrc_err;
  wire [1:0]                   radm_trgt1_np_0_fmt;
  wire [4:0]                   radm_trgt1_np_0_type;
  wire [2:0]                   radm_trgt1_np_0_tc;
  wire [`FLT_Q_ATTR_WIDTH-1:0] radm_trgt1_np_0_attr;
  wire [15:0]                  radm_trgt1_np_0_reqid;
  wire [`CX_TAG_SIZE-1:0]      radm_trgt1_np_0_tag;
  wire [`CX_NFUNC_WD-1:0]      radm_trgt1_np_0_func_num;
  wire [2:0]                   radm_trgt1_np_0_cpl_status;
  wire                         radm_trgt1_np_0_td;
  wire                         radm_trgt1_np_0_poisoned;
  wire [9:0]                   radm_trgt1_np_0_dw_len;
  wire [3:0]                   radm_trgt1_np_0_first_be;
  wire [`CX_NVC_LOG2-1:0]      radm_trgt1_np_0_vc_num;
  wire [`FLT_Q_ADDR_WIDTH-1:0] radm_trgt1_np_0_addr;
  wire [`FLT_Q_ADDR_WIDTH-1:0] radm_trgt1_np_0_hdr_uppr_bytes;
  wire                         radm_trgt1_np_0_rom_in_range;
  wire                         radm_trgt1_np_0_io_req_in_range;
  wire [2:0]                   radm_trgt1_np_0_in_membar_range;
  wire [3:0]                   radm_trgt1_np_0_last_be;
  wire [1:0]                   radm_trgt1_np_0_ats;
  wire                         radm_trgt1_np_0_nw;
  wire                         radm_trgt1_np_0_cxlsrc;
  wire                         radm_trgt1_np_0_th;
  wire [1:0]                   radm_trgt1_np_0_ph;
  wire [7:0]                   radm_trgt1_np_0_st;
  wire                         radm_trgt1_np_0_hdr_uppr_bytes_valid;
  wire [8:0]                   radm_trgt1_np_0_reqtr_sgmt;
  wire [8:0]                   radm_trgt1_np_0_dest_sgmt;
  wire [`CX_RADM_PKT_ORD_WD-1:0]radm_trgt1_np_0_pkt_order_no;
  wire [`CX_ATU_IN_NREGIONS_MIN1-1:0]radm_trgt1_np_0_atu_sloc_match;
  wire [`CX_ATU_IN_NREGIONS_MIN1-1:0]radm_trgt1_np_0_atu_cbuf_err;
  wire                         trgt1_radm_intf_np_0_halt;
    //////////////////////////////////////////
    // trgt1 CPL interface
    //
  wire [`TRGT_DATA_WD-1:0]      radm_trgt1_cpl_0_data;
  wire [`CX_RASDP_TRGT1_CPL_HDR_PROT_WD-1:0] radm_trgt1_cpl_0_hdr_prot;
  wire [`CX_PRFX_W_PAR-1:0]    radm_trgt1_cpl_0_prfx;
  wire [`CX_NW-1:0]            radm_trgt1_cpl_0_dwen;
  wire                         radm_trgt1_cpl_0_dv;
  wire                         radm_trgt1_cpl_0_hv;
  wire                         radm_trgt1_cpl_0_eot;
  wire                         radm_trgt1_cpl_0_dllp_abort;
  wire                         radm_trgt1_cpl_0_tlp_abort;
  wire                         radm_trgt1_cpl_0_ecrc_err;
  wire [1:0]                   radm_trgt1_cpl_0_fmt;
  wire [4:0]                   radm_trgt1_cpl_0_type;
  wire [2:0]                   radm_trgt1_cpl_0_tc;
  wire [`FLT_Q_ATTR_WIDTH-1:0] radm_trgt1_cpl_0_attr;
  wire [15:0]                  radm_trgt1_cpl_0_reqid;
  wire [`CX_TAG_SIZE-1:0]      radm_trgt1_cpl_0_tag;
  wire [`CX_NFUNC_WD-1:0]      radm_trgt1_cpl_0_func_num;
  wire [2:0]                   radm_trgt1_cpl_0_status;
  wire                         radm_trgt1_cpl_0_td;
  wire                         radm_trgt1_cpl_0_poisoned;
  wire [9:0]                   radm_trgt1_cpl_0_dw_len;
  wire                         radm_trgt1_cpl_0_bcm;
  wire [11:0]                  radm_trgt1_cpl_0_byte_cnt;
  wire [15:0]                  radm_trgt1_cpl_0_cmpltr_id;
  wire                         radm_trgt1_cpl_0_last;
  wire [`CX_NVC_LOG2-1:0]      radm_trgt1_cpl_0_vc_num;
  wire [`FLT_Q_CPL_LOWER_ADDR_WIDTH-1:0] radm_trgt1_cpl_0_addr;
  wire [8:0]                   radm_trgt1_cpl_0_dest_sgmt;
  wire [7:0]                   radm_trgt1_cpl_0_cpl_sgmt;
  wire [`CX_RADM_PKT_ORD_WD -1 :0]radm_trgt1_cpl_0_p_pkt_order_no;
  wire                         trgt1_radm_intf_cpl_0_halt;


logic [`N_XADM_P_IF-1:0]    xali_posted_tlp_sent;

wire [`CX_NFUNC-1:0] cfg_10b_tag_req_en;



// ----------------------------------------------------------------------





  // Completions Status during DPC
  logic  core_in_dpc_i                            ;
  logic  cfg_dpc_cpl_cntrl_i                      ;
  assign core_in_dpc         = core_in_dpc_i      ;
  assign cfg_dpc_cpl_cntrl   = cfg_dpc_cpl_cntrl_i;



   //--------------------------------------
   // APP LAYER INSTANCE
   //--------------------------------------
DWC_pcie_app_layer

#(
   .INST (INST)
)
  u_DWC_pcie_app_layer (
    .core_clk                       (core_clk),

    .core_rst_n                     (core_rst_n),
    .device_type                    ( device_type                     ),
    .aux_clk_g                      (aux_clk_g),
    .test_clk_en                    (test_clk_en),
    .test_rst_en                    (test_rst_en),
    .aux_clk                        (pm_aux_clk),
    .cfg_axi_clk_gating_en          (cfg_axi_clk_gating_en),
    .mstr_aclk_g                    (mstr_aclk_g),
    .mstr_aresetn                   (mstr_aresetn),
    .mstr_aclk                      (mstr_aclk),
    .mstr_rasdp_err_mode            (mstr_rasdp_err_mode),
    .mstr_awid                      (mstr_awid),
    .mstr_awvalid                   (mstr_awvalid),
    .mstr_awaddr                    (mstr_awaddr),
    .mstr_awuser                    (mstr_awuser),
    .mstr_awlen                     (mstr_awlen),
    .mstr_awsize                    (mstr_awsize),
    .mstr_awburst                   (mstr_awburst),
    .mstr_awlock                    (mstr_awlock),
    .mstr_awcache                   (mstr_awcache),
    .mstr_awprot                    (mstr_awprot),
    .mstr_awready                   (mstr_awready),
    .mstr_awmisc_info               (mstr_awmisc_info),
    .mstr_awmisc_info_last_dcmp_tlp (mstr_awmisc_info_last_dcmp_tlp),
    .mstr_awmisc_info_hdr_34dw      (mstr_awmisc_info_hdr_34dw),
    .mstr_awmisc_info_tlpprfx       (mstr_awmisc_info_tlpprfx),
    .mstr_awmisc_info_tph           (mstr_awmisc_info_tph),
    .mstr_awmisc_info_ido           (mstr_awmisc_info_ido),
    .mstr_awmisc_info_dst_segment   (mstr_awmisc_info_dst_segment),
    .mstr_awmisc_info_req_segment   (mstr_awmisc_info_req_segment),
     .mstr_awmisc_info_dma          (mstr_awmisc_info_dma),
    .mstr_awmisc_info_nw            (mstr_awmisc_info_nw),
    .mstr_awmisc_info_cxlsrc        (mstr_awmisc_info_cxlsrc),
    .mstr_awmisc_info_ats           (mstr_awmisc_info_ats),
    .mstr_awmisc_info_ep            (mstr_awmisc_info_ep),
    .mstr_awqos                     (mstr_awqos),
    .mstr_awbar                     (mstr_awbar),
    .mstr_awdomain                  (mstr_awdomain),
    .mstr_awsnoop                   (mstr_awsnoop),
    .mstr_awatop                    (mstr_awatop),
    .mstr_wready                    (mstr_wready),
    .mstr_wdata                     (mstr_wdata),
    .mstr_wuser                     (mstr_wuser),
    .mstr_wstrb                     (mstr_wstrb),
    .mstr_wlast                     (mstr_wlast),
    .mstr_wvalid                    (mstr_wvalid),
    .mstr_bready                    (mstr_bready),
    .mstr_bid                       (mstr_bid),
    .mstr_bvalid                    (mstr_bvalid),
    .mstr_bresp                     (mstr_bresp),
    .mstr_bmisc_info_cpl_stat       (mstr_bmisc_info_cpl_stat),
    .mstr_arid                      (mstr_arid),
    .mstr_arvalid                   (mstr_arvalid),
    .mstr_araddr                    (mstr_araddr),
    .mstr_aruser                    (mstr_aruser),
    .mstr_arlen                     (mstr_arlen),
    .mstr_arsize                    (mstr_arsize),
    .mstr_arburst                   (mstr_arburst),
    .mstr_arlock                    (mstr_arlock),
    .mstr_arcache                   (mstr_arcache),
    .mstr_arprot                    (mstr_arprot),
    .mstr_armisc_info               (mstr_armisc_info),
    .mstr_armisc_info_last_dcmp_tlp (mstr_armisc_info_last_dcmp_tlp),
    .mstr_armisc_info_tlpprfx       (mstr_armisc_info_tlpprfx),
    .mstr_armisc_info_tph           (mstr_armisc_info_tph),
    .mstr_armisc_info_ido           (mstr_armisc_info_ido),
    .mstr_armisc_info_zeroread      (mstr_armisc_info_zeroread),
    .mstr_armisc_info_dma           (mstr_armisc_info_dma),
    .mstr_armisc_info_nw            (mstr_armisc_info_nw),
    .mstr_armisc_info_cxlsrc        (mstr_armisc_info_cxlsrc),
    .mstr_armisc_info_ats           (mstr_armisc_info_ats),
    .mstr_armisc_info_dst_segment   (mstr_armisc_info_dst_segment),
    .mstr_armisc_info_req_segment   (mstr_armisc_info_req_segment),
    .mstr_arready                   (mstr_arready),
    .mstr_arqos                     (mstr_arqos),
    .mstr_arbar                     (mstr_arbar),
    .mstr_ardomain                  (mstr_ardomain),
    .mstr_arsnoop                   (mstr_arsnoop),


    .mstr_rready                    (mstr_rready),
    .mstr_rid                       (mstr_rid),
    .mstr_rvalid                    (mstr_rvalid),
    .mstr_rlast                     (mstr_rlast),
    .mstr_rdata                     (mstr_rdata),
    .mstr_ruser                     (mstr_ruser),
    .mstr_rresp                     (mstr_rresp),
    .mstr_rmisc_info                (mstr_rmisc_info),
    .mstr_rmisc_info_cpl_stat       (mstr_rmisc_info_cpl_stat),
    .mstr_csysack                   (mstr_csysack),
    .mstr_cactive                   (mstr_cactive),
    .mstr_csysreq                   (mstr_csysreq),
    // Slave interfaces of AXI
    .slv_aclk_g                     (slv_aclk_g),
    .slv_aresetn                    (slv_aresetn),
    .slv_aclk                       (slv_aclk),
    .slv_rasdp_err_mode             (slv_rasdp_err_mode),
    .slv_awid                       (slv_awid),
    .slv_awaddr                     (slv_awaddr),
    .slv_awuser                     (slv_awuser),
    .slv_awlen                      (slv_awlen),
    .slv_awsize                     (slv_awsize),
    .slv_awburst                    (slv_awburst),
    .slv_awlock                     (slv_awlock),
    .slv_awcache                    (slv_awcache),
    .slv_awprot                     (slv_awprot),
    .slv_awvalid                    (slv_awvalid),
    .slv_awready                    (slv_awready),
    .slv_awqos                      (slv_awqos),
    .slv_awbar                      (slv_awbar),
    .slv_awdomain                   (slv_awdomain),
    .slv_awsnoop                    (slv_awsnoop),
    .slv_awatop                     (slv_awatop),
    .slv_awmisc_info                (slv_awmisc_info),
    .slv_awmisc_info_hdr_34dw       (slv_awmisc_info_hdr_34dw),
    .slv_awmisc_info_tlpprfx        (slv_awmisc_info_tlpprfx),
    .slv_awmisc_info_p_tag          (slv_awmisc_info_p_tag),
    .slv_awmisc_info_tph            (slv_awmisc_info_tph),
    .slv_awmisc_info_atu_bypass     (slv_awmisc_info_atu_bypass),
    .slv_awmisc_info_ido            (slv_awmisc_info_ido),
    .slv_awmisc_info_dst_segment    (slv_awmisc_info_dst_segment),
    .slv_awmisc_info_nw             (slv_awmisc_info_nw),
    .slv_awmisc_info_ats            (slv_awmisc_info_ats),

    .slv_wdata                      (slv_wdata),
    .slv_wuser                      (slv_wuser),
    .slv_wstrb                      (slv_wstrb),
    .slv_wlast                      (slv_wlast),
    .slv_wvalid                     (slv_wvalid),
    .slv_wready                     (slv_wready),
    .slv_wmisc_info_ep              (slv_wmisc_info_ep),
    .slv_wmisc_info_silentDrop      (slv_wmisc_info_silentDrop),
    .slv_bid                        (slv_bid),
    .slv_bresp                      (slv_bresp),
    .slv_bvalid                     (slv_bvalid),
    .slv_bready                     (slv_bready),
    .slv_bmisc_info                 (slv_bmisc_info),
    .slv_bmisc_info_cpl_segment     (slv_bmisc_info_cpl_segment),
    .slv_bmisc_info_dst_segment     (slv_bmisc_info_dst_segment),
    .slv_arid                       (slv_arid),
    .slv_araddr                     (slv_araddr),
    .slv_aruser                     (slv_aruser),
    .slv_arlen                      (slv_arlen),
    .slv_arsize                     (slv_arsize),
    .slv_arburst                    (slv_arburst),
    .slv_arlock                     (slv_arlock),
    .slv_arcache                    (slv_arcache),
    .slv_arprot                     (slv_arprot),
    .slv_armisc_info                (slv_armisc_info),
    .slv_armisc_info_tlpprfx        (slv_armisc_info_tlpprfx),
    .slv_armisc_info_tph            (slv_armisc_info_tph),
    .slv_armisc_info_atu_bypass     (slv_armisc_info_atu_bypass),
    .slv_armisc_info_ido            (slv_armisc_info_ido),
    .slv_armisc_info_dst_segment    (slv_armisc_info_dst_segment),
    .slv_armisc_info_nw             (slv_armisc_info_nw),
    .slv_armisc_info_ats            (slv_armisc_info_ats),
    .slv_arvalid                    (slv_arvalid),
    .slv_arready                    (slv_arready),
    .slv_arqos                      (slv_arqos),
    .slv_arbar                      (slv_arbar),
    .slv_ardomain                   (slv_ardomain),
    .slv_arsnoop                    (slv_arsnoop),

    .slv_rid                        (slv_rid),
    .slv_rdata                      (slv_rdata),
    .slv_ruser                      (slv_ruser),
    .slv_rresp                      (slv_rresp),
    .slv_rlast                      (slv_rlast),
    .slv_rvalid                     (slv_rvalid),
    .slv_rmisc_info                 (slv_rmisc_info),
    .slv_rmisc_info_ido             (slv_rmisc_info_ido),
    .slv_rmisc_info_cpl_segment     (slv_rmisc_info_cpl_segment),
    .slv_rmisc_info_dst_segment     (slv_rmisc_info_dst_segment),
    .slv_rready                     (slv_rready),

    .slv_csysreq                    (slv_csysreq),
    .slv_csysack                    (slv_csysack),
    .slv_cactive                    (slv_cactive),
    .cfg_pbus_dev_num               (cfg_pbus_dev_num),
    .cfg_pbus_num                   (cfg_pbus_num),
    .cfg_subbus_num                 (cfg_subbus_num),
    .cfg_2ndbus_num                 (cfg_2ndbus_num),
    .rstctl_mstr_flush_req          (rstctl_mstr_flush_req),
    .rstctl_slv_flush_req           (rstctl_slv_flush_req),
    .brdg_slv_flush_ack             (brdg_slv_flush_ack),
    .brdg_slv_xfer_pending          (brdg_slv_xfer_pending),
    .brdg_mstr_xfer_pending         (brdg_mstr_xfer_pending),
    .app_xfer_pending               (app_xfer_pending),
    .trgt_cpl_lut_empty             (trgt_cpl_lut_empty),
    .brdg_dbi_xfer_pending          (brdg_dbi_xfer_pending),

    .radm_cpl_timeout               (radm_cpl_timeout),
    .radm_timeout_cpl_tc            (radm_timeout_cpl_tc),
    .radm_timeout_cpl_attr          (radm_timeout_cpl_attr),
    .radm_timeout_cpl_tag           (radm_timeout_cpl_tag),
    .radm_timeout_func_num          (radm_timeout_func_num),
    .trgt_lookup_id                       ( trgt_lookup_id                      ),
    .radm_trgt1_p_0_pending               ( radm_trgt1_p_0_pending              ),
    .radm_trgt1_p_0_data                  ( radm_trgt1_p_0_data                 ),
    .radm_trgt1_p_0_hdr_prot              ( radm_trgt1_p_0_hdr_prot             ),
    .radm_trgt1_p_0_prfx                  ( radm_trgt1_p_0_prfx                 ),
    .radm_trgt1_p_0_dwen                  ( radm_trgt1_p_0_dwen                 ),
    .radm_trgt1_p_0_dv                    ( radm_trgt1_p_0_dv                   ),
    .radm_trgt1_p_0_hv                    ( radm_trgt1_p_0_hv                   ),
    .radm_trgt1_p_0_eot                   ( radm_trgt1_p_0_eot                  ),
    .radm_trgt1_p_0_dllp_abort            ( radm_trgt1_p_0_dllp_abort           ),
    .radm_trgt1_p_0_tlp_abort             ( radm_trgt1_p_0_tlp_abort            ),
    .radm_trgt1_p_0_ecrc_err              ( radm_trgt1_p_0_ecrc_err             ),
    .radm_trgt1_p_0_fmt                   ( radm_trgt1_p_0_fmt                  ),
    .radm_trgt1_p_0_type                  ( radm_trgt1_p_0_type                 ),
    .radm_trgt1_p_0_tc                    ( radm_trgt1_p_0_tc                   ),
    .radm_trgt1_p_0_attr                  ( radm_trgt1_p_0_attr                 ),
    .radm_trgt1_p_0_reqid                 ( radm_trgt1_p_0_reqid                ),
    .radm_trgt1_p_0_tag                   ( radm_trgt1_p_0_tag                  ),
    .radm_trgt1_p_0_func_num              ( radm_trgt1_p_0_func_num             ),
    .radm_trgt1_p_0_td                    ( radm_trgt1_p_0_td                   ),
    .radm_trgt1_p_0_cpl_status            ( radm_trgt1_p_0_cpl_status           ),
    .radm_trgt1_p_0_poisoned              ( radm_trgt1_p_0_poisoned             ),
    .radm_trgt1_p_0_dw_len                ( radm_trgt1_p_0_dw_len               ),
    .radm_trgt1_p_0_first_be              ( radm_trgt1_p_0_first_be             ),
    .radm_trgt1_p_0_vc_num                ( radm_trgt1_p_0_vc_num               ),
    .radm_trgt1_p_0_addr                  ( radm_trgt1_p_0_addr                 ),
    .radm_trgt1_p_0_hdr_uppr_bytes        ( radm_trgt1_p_0_hdr_uppr_bytes       ),
    .radm_trgt1_p_0_rom_in_range          ( radm_trgt1_p_0_rom_in_range         ),
    .radm_trgt1_p_0_io_req_in_range       ( radm_trgt1_p_0_io_req_in_range      ),
    .radm_trgt1_p_0_in_membar_range       ( radm_trgt1_p_0_in_membar_range      ),
    .radm_trgt1_p_0_last_be               ( radm_trgt1_p_0_last_be              ),
    .radm_trgt1_p_0_ats                   ( radm_trgt1_p_0_ats                  ),
    .radm_trgt1_p_0_nw                    ( radm_trgt1_p_0_nw                   ),
    .radm_trgt1_p_0_th                    ( radm_trgt1_p_0_th                   ),
    .radm_trgt1_p_0_ph                    ( radm_trgt1_p_0_ph                   ),
    .radm_trgt1_p_0_st                    ( radm_trgt1_p_0_st                   ),
    .radm_trgt1_p_0_hdr_uppr_bytes_valid  ( radm_trgt1_p_0_hdr_uppr_bytes_valid ),
    .radm_trgt1_p_0_reqtr_sgmt            ( radm_trgt1_p_0_reqtr_sgmt           ),
    .radm_trgt1_p_0_dest_sgmt             ( radm_trgt1_p_0_dest_sgmt            ),
    .radm_trgt1_p_0_pkt_order_no          ( radm_trgt1_p_0_pkt_order_no         ),
    .trgt1_radm_intf_p_0_halt             ( trgt1_radm_intf_p_0_halt            ),

    .radm_trgt1_np_0_data                 ( radm_trgt1_np_0_data                ),
    .radm_trgt1_np_0_hdr_prot             ( radm_trgt1_np_0_hdr_prot            ),
    .radm_trgt1_np_0_prfx                 ( radm_trgt1_np_0_prfx                ),
    .radm_trgt1_np_0_dwen                 ( radm_trgt1_np_0_dwen                ),
    .radm_trgt1_np_0_dv                   ( radm_trgt1_np_0_dv                  ),
    .radm_trgt1_np_0_hv                   ( radm_trgt1_np_0_hv                  ),
    .radm_trgt1_np_0_eot                  ( radm_trgt1_np_0_eot                 ),
    .radm_trgt1_np_0_dllp_abort           ( radm_trgt1_np_0_dllp_abort          ),
    .radm_trgt1_np_0_tlp_abort            ( radm_trgt1_np_0_tlp_abort           ),
    .radm_trgt1_np_0_ecrc_err             ( radm_trgt1_np_0_ecrc_err            ),
    .radm_trgt1_np_0_fmt                  ( radm_trgt1_np_0_fmt                 ),
    .radm_trgt1_np_0_type                 ( radm_trgt1_np_0_type                ),
    .radm_trgt1_np_0_tc                   ( radm_trgt1_np_0_tc                  ),
    .radm_trgt1_np_0_attr                 ( radm_trgt1_np_0_attr                ),
    .radm_trgt1_np_0_reqid                ( radm_trgt1_np_0_reqid               ),
    .radm_trgt1_np_0_tag                  ( radm_trgt1_np_0_tag                 ),
    .radm_trgt1_np_0_func_num             ( radm_trgt1_np_0_func_num            ),
    .radm_trgt1_np_0_cpl_status           ( radm_trgt1_np_0_cpl_status          ),
    .radm_trgt1_np_0_td                   ( radm_trgt1_np_0_td                  ),
    .radm_trgt1_np_0_poisoned             ( radm_trgt1_np_0_poisoned            ),
    .radm_trgt1_np_0_dw_len               ( radm_trgt1_np_0_dw_len              ),
    .radm_trgt1_np_0_first_be             ( radm_trgt1_np_0_first_be            ),
    .radm_trgt1_np_0_vc_num               ( radm_trgt1_np_0_vc_num              ),

    .radm_trgt1_np_0_addr                 ( radm_trgt1_np_0_addr                ),
    .radm_trgt1_np_0_hdr_uppr_bytes       ( radm_trgt1_np_0_hdr_uppr_bytes      ),

    .radm_trgt1_np_0_rom_in_range         ( radm_trgt1_np_0_rom_in_range        ),
    .radm_trgt1_np_0_io_req_in_range      ( radm_trgt1_np_0_io_req_in_range     ),
    .radm_trgt1_np_0_in_membar_range      ( radm_trgt1_np_0_in_membar_range     ),
    .radm_trgt1_np_0_last_be              ( radm_trgt1_np_0_last_be             ),
    .radm_trgt1_np_0_ats                  ( radm_trgt1_np_0_ats                 ),
    .radm_trgt1_np_0_nw                   ( radm_trgt1_np_0_nw                  ),
    .radm_trgt1_np_0_cxlsrc               ( radm_trgt1_np_0_cxlsrc              ),
    .radm_trgt1_np_0_th                   ( radm_trgt1_np_0_th                  ),
    .radm_trgt1_np_0_ph                   ( radm_trgt1_np_0_ph                  ),
    .radm_trgt1_np_0_st                   ( radm_trgt1_np_0_st                  ),

    .radm_trgt1_np_0_reqtr_sgmt           ( radm_trgt1_np_0_reqtr_sgmt          ),
    .radm_trgt1_np_0_dest_sgmt            ( radm_trgt1_np_0_dest_sgmt           ),
    .radm_trgt1_np_0_pkt_order_no         ( radm_trgt1_np_0_pkt_order_no        ),
    .trgt1_radm_intf_np_0_halt            ( trgt1_radm_intf_np_0_halt           ),

    .radm_trgt1_cpl_0_data                ( radm_trgt1_cpl_0_data               ),
    .radm_trgt1_cpl_0_hdr_prot            ( radm_trgt1_cpl_0_hdr_prot           ),
    .radm_trgt1_cpl_0_prfx                ( radm_trgt1_cpl_0_prfx               ),
    .radm_trgt1_cpl_0_dwen                ( radm_trgt1_cpl_0_dwen               ),
    .radm_trgt1_cpl_0_dv                  ( radm_trgt1_cpl_0_dv                 ),
    .radm_trgt1_cpl_0_hv                  ( radm_trgt1_cpl_0_hv                 ),
    .radm_trgt1_cpl_0_eot                 ( radm_trgt1_cpl_0_eot                ),
    .radm_trgt1_cpl_0_dllp_abort          ( radm_trgt1_cpl_0_dllp_abort         ),
    .radm_trgt1_cpl_0_tlp_abort           ( radm_trgt1_cpl_0_tlp_abort          ),
    .radm_trgt1_cpl_0_ecrc_err            ( radm_trgt1_cpl_0_ecrc_err           ),
    .radm_trgt1_cpl_0_fmt                 ( radm_trgt1_cpl_0_fmt                ),
    .radm_trgt1_cpl_0_type                ( radm_trgt1_cpl_0_type               ),
    .radm_trgt1_cpl_0_tc                  ( radm_trgt1_cpl_0_tc                 ),
    .radm_trgt1_cpl_0_attr                ( radm_trgt1_cpl_0_attr               ),
    .radm_trgt1_cpl_0_reqid               ( radm_trgt1_cpl_0_reqid              ),
    .radm_trgt1_cpl_0_tag                 ( radm_trgt1_cpl_0_tag                ),
    .radm_trgt1_cpl_0_func_num            ( radm_trgt1_cpl_0_func_num           ),
    .radm_trgt1_cpl_0_cpl_status          ( radm_trgt1_cpl_0_status             ),
    .radm_trgt1_cpl_0_td                  ( radm_trgt1_cpl_0_td                 ),
    .radm_trgt1_cpl_0_poisoned            ( radm_trgt1_cpl_0_poisoned           ),
    .radm_trgt1_cpl_0_dw_len              ( radm_trgt1_cpl_0_dw_len             ),
    .radm_trgt1_cpl_0_bcm                 ( radm_trgt1_cpl_0_bcm                ),
    .radm_trgt1_cpl_0_byte_cnt            ( radm_trgt1_cpl_0_byte_cnt           ),
    .radm_trgt1_cpl_0_cmpltr_id           ( radm_trgt1_cpl_0_cmpltr_id          ),
    .radm_trgt1_cpl_0_last                ( radm_trgt1_cpl_0_last               ),
    .radm_trgt1_cpl_0_vc_num              ( radm_trgt1_cpl_0_vc_num             ),
    .radm_trgt1_cpl_0_addr                ( radm_trgt1_cpl_0_addr               ),
    .radm_trgt1_cpl_0_dest_sgmt           ( radm_trgt1_cpl_0_dest_sgmt          ),
    .radm_trgt1_cpl_0_cpl_sgmt            ( radm_trgt1_cpl_0_cpl_sgmt           ),
    .radm_trgt1_cpl_0_pkt_order_no        ( radm_trgt1_cpl_0_p_pkt_order_no     ),
    .trgt1_radm_intf_cpl_0_halt           ( trgt1_radm_intf_cpl_0_halt          ),

    .xali_xaim_pkt  (xali_xaim_pkt),
    .xaim_xali_halt (xaim_xali_halt),
    // DBI interface
    .dbi_addr                       (slv_dbi_addr),
    .dbi_din                        (slv_dbi_din),
    .dbi_cs                         (slv_dbi_cs),
    .dbi_cs2                        (slv_dbi_cs2),
    .dbi_wr                         (slv_dbi_wr),
    .dbi_func_num                   (slv_dbi_func_num),
    .dbi_bar_num                    (slv_dbi_bar_num),
    .dbi_io_access                  (slv_dbi_io_access),
    .dbi_rom_access                 (slv_dbi_rom_access),
    .dbi_ack                        (slv_lbc_dbi_ack),
    .dbi_dout                       (slv_lbc_dbi_dout),
  // External RAM Interfaces
  // Inbound
  // Inbound Scheduler Posted Request Header RAM
    .ib_scheduler_p_hdr_ram_addra         (ib_scheduler_p_hdr_ram_addra       ),
    .ib_scheduler_p_hdr_ram_wea           (ib_scheduler_p_hdr_ram_wea         ),
    .ib_scheduler_p_hdr_ram_dina          (ib_scheduler_p_hdr_ram_dina        ),
    .ib_scheduler_p_hdr_ram_addrb         (ib_scheduler_p_hdr_ram_addrb       ),
    .ib_scheduler_p_hdr_ram_enb           (ib_scheduler_p_hdr_ram_enb         ),
    .ib_scheduler_p_hdr_ram_doutb         (ib_scheduler_p_hdr_ram_doutb       ),
  // Inbound Scheduler Posted Request Data RAM
    .ib_scheduler_p_data_ram_addra        (ib_scheduler_p_data_ram_addra      ),
    .ib_scheduler_p_data_ram_wea          (ib_scheduler_p_data_ram_wea        ),
    .ib_scheduler_p_data_ram_dina         (ib_scheduler_p_data_ram_dina       ),
    .ib_scheduler_p_data_ram_addrb        (ib_scheduler_p_data_ram_addrb      ),
    .ib_scheduler_p_data_ram_enb          (ib_scheduler_p_data_ram_enb        ),
    .ib_scheduler_p_data_ram_doutb        (ib_scheduler_p_data_ram_doutb      ),
  // Inbound Scheduler Non-Posted Request Header RAM
    .ib_scheduler_np_hdr_ram_addra        (ib_scheduler_np_hdr_ram_addra      ),
    .ib_scheduler_np_hdr_ram_wea          (ib_scheduler_np_hdr_ram_wea        ),
    .ib_scheduler_np_hdr_ram_dina         (ib_scheduler_np_hdr_ram_dina       ),
    .ib_scheduler_np_hdr_ram_addrb        (ib_scheduler_np_hdr_ram_addrb      ),
    .ib_scheduler_np_hdr_ram_enb          (ib_scheduler_np_hdr_ram_enb        ),
    .ib_scheduler_np_hdr_ram_doutb        (ib_scheduler_np_hdr_ram_doutb      ),
  // Inbound Scheduler Non-Posted Request Data RAM
    .ib_scheduler_np_data_ram_addra       (ib_scheduler_np_data_ram_addra     ),
    .ib_scheduler_np_data_ram_wea         (ib_scheduler_np_data_ram_wea       ),
    .ib_scheduler_np_data_ram_dina        (ib_scheduler_np_data_ram_dina      ),
    .ib_scheduler_np_data_ram_addrb       (ib_scheduler_np_data_ram_addrb     ),
    .ib_scheduler_np_data_ram_enb         (ib_scheduler_np_data_ram_enb       ),
    .ib_scheduler_np_data_ram_doutb       (ib_scheduler_np_data_ram_doutb     ),
    // Inbound Read Request Clock Domain Crossing FIFO RAM
    .ib_rreq_c2a_cdc_ram_addra      (ib_rreq_c2a_cdc_ram_addra),
    .ib_rreq_c2a_cdc_ram_wea        (ib_rreq_c2a_cdc_ram_wea),
    .ib_rreq_c2a_cdc_ram_dina       (ib_rreq_c2a_cdc_ram_dina),
    .ib_rreq_c2a_cdc_ram_addrb      (ib_rreq_c2a_cdc_ram_addrb),
    .ib_rreq_c2a_cdc_ram_enb        (ib_rreq_c2a_cdc_ram_enb),
    .ib_rreq_c2a_cdc_ram_doutb      (ib_rreq_c2a_cdc_ram_doutb),
    // Inbound Write Request Clock Domain Crossing FIFO RAM
    .ib_wreq_c2a_cdc_ram_addra      (ib_wreq_c2a_cdc_ram_addra),
    .ib_wreq_c2a_cdc_ram_wea        (ib_wreq_c2a_cdc_ram_wea),
    .ib_wreq_c2a_cdc_ram_dina       (ib_wreq_c2a_cdc_ram_dina),
    .ib_wreq_c2a_cdc_ram_addrb      (ib_wreq_c2a_cdc_ram_addrb),
    .ib_wreq_c2a_cdc_ram_enb        (ib_wreq_c2a_cdc_ram_enb),
    .ib_wreq_c2a_cdc_ram_doutb      (ib_wreq_c2a_cdc_ram_doutb),

    // Inbound Master Completion Clock Domain Crossing FIFO RAM
    .ib_mcpl_a2c_cdc_ram_addra      (ib_mcpl_a2c_cdc_ram_addra),
    .ib_mcpl_a2c_cdc_ram_wea        (ib_mcpl_a2c_cdc_ram_wea),
    .ib_mcpl_a2c_cdc_ram_dina       (ib_mcpl_a2c_cdc_ram_dina),
    .ib_mcpl_a2c_cdc_ram_addrb      (ib_mcpl_a2c_cdc_ram_addrb),
    .ib_mcpl_a2c_cdc_ram_enb        (ib_mcpl_a2c_cdc_ram_enb),
    .ib_mcpl_a2c_cdc_ram_doutb      (ib_mcpl_a2c_cdc_ram_doutb),
    // // Inbound Master Completion Data Segment FIFO RAM
    .ib_mcpl_sb_ram_addra           (ib_mcpl_sb_ram_addra),
    .ib_mcpl_sb_ram_wea             (ib_mcpl_sb_ram_wea),
    .ib_mcpl_sb_ram_dina            (ib_mcpl_sb_ram_dina),
    .ib_mcpl_sb_ram_addrb           (ib_mcpl_sb_ram_addrb),
    .ib_mcpl_sb_ram_enb             (ib_mcpl_sb_ram_enb),
    .ib_mcpl_sb_ram_doutb           (ib_mcpl_sb_ram_doutb),
   // Outbound
   // Slave Non-Posted Write Set-Aside RAM // To do : change names
  .slv_npw_sab_ram_addra            (slv_npw_sab_ram_addra),
  .slv_npw_sab_ram_wea              (slv_npw_sab_ram_wea),
  .slv_npw_sab_ram_dina             (slv_npw_sab_ram_dina),
  .slv_npw_sab_ram_addrb            (slv_npw_sab_ram_addrb),
  .slv_npw_sab_ram_enb              (slv_npw_sab_ram_enb),
  .slv_npw_sab_ram_doutb            (slv_npw_sab_ram_doutb),
  // Outbound Non-Posted TLP Decomposer Header/Data FIFO RAM
  .ob_npdcmp_ram_addra              (ob_npdcmp_ram_addra),
  .ob_npdcmp_ram_wea                (ob_npdcmp_ram_wea),
  .ob_npdcmp_ram_dina               (ob_npdcmp_ram_dina),
  .ob_npdcmp_ram_addrb              (ob_npdcmp_ram_addrb),
  .ob_npdcmp_ram_enb                (ob_npdcmp_ram_enb),
  .ob_npdcmp_ram_doutb              (ob_npdcmp_ram_doutb),
  // Outbound Posted TLP Decomposer Header FIFO RAM
  .ob_pdcmp_hdr_ram_addra           (ob_pdcmp_hdr_ram_addra),
  .ob_pdcmp_hdr_ram_wea             (ob_pdcmp_hdr_ram_wea),
  .ob_pdcmp_hdr_ram_dina            (ob_pdcmp_hdr_ram_dina),
  .ob_pdcmp_hdr_ram_addrb           (ob_pdcmp_hdr_ram_addrb),
  .ob_pdcmp_hdr_ram_enb             (ob_pdcmp_hdr_ram_enb),
  .ob_pdcmp_hdr_ram_doutb           (ob_pdcmp_hdr_ram_doutb),
  // Outbound Posted TLP Decomposer Data FIFO RAM
  .ob_pdcmp_data_ram_addra          (ob_pdcmp_data_ram_addra),
  .ob_pdcmp_data_ram_wea            (ob_pdcmp_data_ram_wea),
  .ob_pdcmp_data_ram_dina           (ob_pdcmp_data_ram_dina),
  .ob_pdcmp_data_ram_addrb          (ob_pdcmp_data_ram_addrb),
  .ob_pdcmp_data_ram_enb            (ob_pdcmp_data_ram_enb),
  .ob_pdcmp_data_ram_doutb          (ob_pdcmp_data_ram_doutb),
  // Outbound Composer Segmented Buffer RAM
  .ob_ccmp_data_ram_addra          (ob_ccmp_data_ram_addra),
  .ob_ccmp_data_ram_wea            (ob_ccmp_data_ram_wea),
  .ob_ccmp_data_ram_dina           (ob_ccmp_data_ram_dina),
  .ob_ccmp_data_ram_addrb          (ob_ccmp_data_ram_addrb),
  .ob_ccmp_data_ram_enb            (ob_ccmp_data_ram_enb),
  .ob_ccmp_data_ram_doutb          (ob_ccmp_data_ram_doutb),
    .edma_rd_eng_ll_addra_ram            (edma_rd_eng_ll_addra_ram),
    .edma_rd_eng_ll_addrb_ram            (edma_rd_eng_ll_addrb_ram),
    .edma_rd_eng_ll_dout_ram             (edma_rd_eng_ll_dout_ram),
    .edma_rd_eng_ll_we_ram               (edma_rd_eng_ll_we_ram),
    .edma_rd_eng_ll_re_ram               (edma_rd_eng_ll_re_ram),
    .edma_rd_eng_ll_din_ram              (edma_rd_eng_ll_din_ram),
    .edma_wr_eng_ll_addra_ram            (edma_wr_eng_ll_addra_ram),
    .edma_wr_eng_ll_addrb_ram            (edma_wr_eng_ll_addrb_ram),
    .edma_wr_eng_ll_dout_ram             (edma_wr_eng_ll_dout_ram),
    .edma_wr_eng_ll_we_ram               (edma_wr_eng_ll_we_ram),
    .edma_wr_eng_ll_re_ram               (edma_wr_eng_ll_re_ram),
    .edma_wr_eng_ll_din_ram              (edma_wr_eng_ll_din_ram),
    .edma_rd_eng_ovrl_addra_ram          (edma_rd_eng_ovrl_addra_ram),
    .edma_rd_eng_ovrl_addrb_ram          (edma_rd_eng_ovrl_addrb_ram),
    .edma_rd_eng_ovrl_dout_ram           (edma_rd_eng_ovrl_dout_ram),
    .edma_rd_eng_ovrl_we_ram             (edma_rd_eng_ovrl_we_ram),
    .edma_rd_eng_ovrl_re_ram             (edma_rd_eng_ovrl_re_ram),
    .edma_rd_eng_ovrl_din_ram            (edma_rd_eng_ovrl_din_ram),
    .edma_wr_eng_ovrl_addra_ram          (edma_wr_eng_ovrl_addra_ram),
    .edma_wr_eng_ovrl_addrb_ram          (edma_wr_eng_ovrl_addrb_ram),
    .edma_wr_eng_ovrl_dout_ram           (edma_wr_eng_ovrl_dout_ram),
    .edma_wr_eng_ovrl_we_ram             (edma_wr_eng_ovrl_we_ram),
    .edma_wr_eng_ovrl_re_ram             (edma_wr_eng_ovrl_re_ram),
    .edma_wr_eng_ovrl_din_ram            (edma_wr_eng_ovrl_din_ram),
    .edma_rd_eng_c2w_lut_addra_ram       (edma_rd_eng_c2w_lut_addra_ram),
    .edma_rd_eng_c2w_lut_addrb_ram       (edma_rd_eng_c2w_lut_addrb_ram),
    .edma_rd_eng_c2w_lut_dout_ram        (edma_rd_eng_c2w_lut_dout_ram),
    .edma_rd_eng_c2w_lut_we_ram          (edma_rd_eng_c2w_lut_we_ram),
    .edma_rd_eng_c2w_lut_re_ram          (edma_rd_eng_c2w_lut_re_ram),
    .edma_rd_eng_c2w_lut_din_ram         (edma_rd_eng_c2w_lut_din_ram),
    .edma_wr_eng_c2w_lut_addra_ram       (edma_wr_eng_c2w_lut_addra_ram),
    .edma_wr_eng_c2w_lut_addrb_ram       (edma_wr_eng_c2w_lut_addrb_ram),
    .edma_wr_eng_c2w_lut_dout_ram        (edma_wr_eng_c2w_lut_dout_ram),
    .edma_wr_eng_c2w_lut_we_ram          (edma_wr_eng_c2w_lut_we_ram),
    .edma_wr_eng_c2w_lut_re_ram          (edma_wr_eng_c2w_lut_re_ram),
    .edma_wr_eng_c2w_lut_din_ram         (edma_wr_eng_c2w_lut_din_ram),
    .edma_rd_eng_stsh_lut_addra_ram      (edma_rd_eng_stsh_lut_addra_ram),
    .edma_rd_eng_stsh_lut_addrb_ram      (edma_rd_eng_stsh_lut_addrb_ram),
    .edma_rd_eng_stsh_lut_dout_ram       (edma_rd_eng_stsh_lut_dout_ram),
    .edma_rd_eng_stsh_lut_we_ram         (edma_rd_eng_stsh_lut_we_ram),
    .edma_rd_eng_stsh_lut_re_ram         (edma_rd_eng_stsh_lut_re_ram),
    .edma_rd_eng_stsh_lut_din_ram        (edma_rd_eng_stsh_lut_din_ram),
    .edma_wr_eng_stsh_lut_addra_ram      (edma_wr_eng_stsh_lut_addra_ram),
    .edma_wr_eng_stsh_lut_addrb_ram      (edma_wr_eng_stsh_lut_addrb_ram),
    .edma_wr_eng_stsh_lut_dout_ram       (edma_wr_eng_stsh_lut_dout_ram),
    .edma_wr_eng_stsh_lut_we_ram         (edma_wr_eng_stsh_lut_we_ram),
    .edma_wr_eng_stsh_lut_re_ram         (edma_wr_eng_stsh_lut_re_ram),
    .edma_wr_eng_stsh_lut_din_ram        (edma_wr_eng_stsh_lut_din_ram),
    .edma_rd_eng_msi_addra_ram           (edma_rd_eng_msi_addra_ram),
    .edma_rd_eng_msi_addrb_ram           (edma_rd_eng_msi_addrb_ram),
    .edma_rd_eng_msi_dout_ram            (edma_rd_eng_msi_dout_ram),
    .edma_rd_eng_msi_we_ram              (edma_rd_eng_msi_we_ram),
    .edma_rd_eng_msi_re_ram              (edma_rd_eng_msi_re_ram),
    .edma_rd_eng_msi_din_ram             (edma_rd_eng_msi_din_ram),
    .edma_wr_eng_msi_addra_ram           (edma_wr_eng_msi_addra_ram),
    .edma_wr_eng_msi_addrb_ram           (edma_wr_eng_msi_addrb_ram),
    .edma_wr_eng_msi_dout_ram            (edma_wr_eng_msi_dout_ram),
    .edma_wr_eng_msi_we_ram              (edma_wr_eng_msi_we_ram),
    .edma_wr_eng_msi_re_ram              (edma_wr_eng_msi_re_ram),
    .edma_wr_eng_msi_din_ram             (edma_wr_eng_msi_din_ram),
    .edma_rd_eng_hard_stop_req           (edma_rd_eng_hard_stop_req),
    .edma_rd_eng_hard_stop_channel       (edma_rd_eng_hard_stop_channel),
    .edma_rd_eng_hard_stop_ack           (edma_rd_eng_hard_stop_ack),
    .edma_wr_eng_hard_stop_req           (edma_wr_eng_hard_stop_req),
    .edma_wr_eng_hard_stop_channel       (edma_wr_eng_hard_stop_channel),
    .edma_wr_eng_hard_stop_ack           (edma_wr_eng_hard_stop_ack),    
    //DMA read buffer interface
    .edmarbuff2ram_addra            (edmarbuff2ram_addra),
    .edmarbuff2ram_we               (edmarbuff2ram_we),
    .edmarbuff2ram_dout             (edmarbuff2ram_dout),
    .edmarbuff2ram_addrb            (edmarbuff2ram_addrb),
    .edmarbuff2ram_re               (edmarbuff2ram_re),
    .ram2edmarbuff_din              (ram2edmarbuff_din),
    //DMA interface signals
    //cdm crgb inputs
    .crgb_cdm_cs                     (crgb_cdm_cs),
    .crgb_cdm_addr                   (crgb_cdm_addr),
    .crgb_cdm_wdata                  (crgb_cdm_wdata),
    .crgb_cdm_wr                     (crgb_cdm_wr),
    .crgb_cdm_source                 (crgb_cdm_source),  
    //cdm crgb output
    .crgb_cdm_rdata                  (crgb_cdm_rdata),
    .crgb_cdm_ack                    (crgb_cdm_ack),
     //DMA Local Interrupt
    .edma_int                        (edma_int),
     // DMA Read/Write Channel transfer pending
    .edma_xfer_pending               (edma_xfer_pending),
    .radm_trgt1_cpl_lookup_id_rlsd   (radm_trgt1_cpl_lookup_id_rlsd),
    // Indicates non-posted TLP
    .radm_trgt1_lookup_id_consmd    (radm_trgt1_lookup_id_consmd),
    .cfg_err_resp                   (cfg_err_resp),
     .cfg_order_rule_ctrl           (cfg_order_rule_ctrl),
    .cfg_ax_mstr_ordr_p_event_sel   (cfg_ax_mstr_ordr_p_event_sel),
    .cfg_ax_snp_en                  (cfg_ax_snp_en),
    .cfg_ib_p_id_mng_ctrl           (cfg_ib_p_id_mng_ctrl),
    .cfg_tc_struc_vc_map            (24'd0),
    .xali_posted_tlp_sent           (xali_posted_tlp_sent),
    .cfg_mstr_arcache_mode          (cfg_mstr_arcache_mode),
    .cfg_mstr_awcache_mode          (cfg_mstr_awcache_mode),
    .cfg_mstr_arcache_value         (cfg_mstr_arcache_value),
    .cfg_mstr_awcache_value         (cfg_mstr_awcache_value),
    .cfg_aximstr_msg_addr_high      (cfg_aximstr_msg_addr_high),
    .cfg_aximstr_msg_addr_low       (cfg_aximstr_msg_addr_low),
    .cfg_mstr_ardomain_mode         (cfg_mstr_ardomain_mode),
    .cfg_mstr_awdomain_mode         (cfg_mstr_awdomain_mode),
    .cfg_mstr_ardomain_value        (cfg_mstr_ardomain_value),
    .cfg_mstr_awdomain_value        (cfg_mstr_awdomain_value),
    .cfg_ax_mstr_zeroread_fw        (cfg_ax_mstr_zeroread_fw),
    .atu_reg_out_upr_base           (atu_reg_out_upr_base),
    .atu_reg_out_en                 (atu_reg_out_en),
    .atu_reg_out_type               (atu_reg_out_type),
    .atu_reg_out_base               (atu_reg_out_base),
    .atu_reg_out_limit              (atu_reg_out_limit),
    .atu_reg_out_uppr_limit         (atu_reg_out_uppr_limit),
    .atu_reg_out_incr_rgn_size      (atu_reg_out_incr_rgn_size),
    .atu_reg_out_invert             (atu_reg_out_invert),
    .atu_reg_out_func_num           (atu_reg_out_func_num),
    .atu_reg_out_func_bypass        (atu_reg_out_func_bypass),
    .atu_reg_out_snp                (atu_reg_out_snp),
    .cfg_rasdp_err_mode                            (cfg_rasdp_error_mode_i),
    .ras_prot_r_disable                            (ras_prot_r_disable),
    .ras_prot_t_disable                            (ras_prot_t_disable),
    .axi_bridge_out_ras_dp_err_log                 (axi_bridge_ras_dp_err_log),
    .axi_bridge_in_ras_dp_err_inj                  (ras_dp_err_inj),
    .axi_bridge_in_ras_dp_err_inj_wake_up          (axi_bridge_in_ras_dp_err_inj_wake_up),
    .hdma_ras_dp_err_log                           (hdma_ras_dp_err_log),
    .hdma_ras_dp_err_inj                           (hdma_ras_dp_err_inj),
    .cfg_rasdp_err_mode_en                         (cfg_rasdp_error_mode_en),
    .cfg_memtype_value              (cfg_memtype_value),
    .cfg_memtype_boundary           (cfg_memtype_boundary),
    .cfg_ext_tag_en                 (cfg_ext_tag_en),
    .cfg_10b_tag_en                 (cfg_10b_tag_req_en),
    .cfg_dmwr_req_en                (cfg_dmwr_req_en),
    .cfg_max_rd_req_size            (cfg_max_rd_req_size),
    .cfg_max_payload_size           (cfg_max_payload_size)


    // Completions Status during DPC
    ,.core_in_dpc_i                (core_in_dpc_i      )
    ,.cfg_dpc_cpl_cntrl_i          (cfg_dpc_cpl_cntrl_i)

); // app_layer instance

assign radm_xfer_pending = brdg_mstr_xfer_pending; // in gen5 IB requests are tracked in the RADM and radm_xfer_pending is a debug output; in gen6 tracking is done in the AXI bridge but debug port is preserved


  wire [`CX_NL-1:0]                 mac_phy_rxpolarity;
  wire [`CX_PHY_TXDEEMPH_WD-1:0]       mac_phy_txdeemph;
  wire [`CX_NL-1:0]                 mac_phy_rxeqeval;


wire                                cfg_aspm_l1_timer_enable;
wire    [(`CX_NFUNC - 1) : 0]       cfg_upd_aslk_pmctrl;
wire    [`CX_NFUNC-1:0]             cfg_upd_pme_cap;
wire                                rstctl_ltssm_enable;
wire                                rstctl_core_flush_req;

wire                                pre_upstream_port;
wire                                xdlh_xmt_pme_ack;
wire                                xdlh_not_expecting_ack;
wire                                smlh_in_l0;
wire                                smlh_in_l1;
wire                                smlh_in_l23;
wire                                smlh_link_in_training;
ltssm_state_e                       smlh_ltssm_state_int;
wire [(2*`CX_NFUNC)-1:0]            cfg_aslk_pmctrl;
wire [`CX_NFUNC-1:0]                cfg_upd_pmcsr;
wire [`CX_NFUNC-1:0]                cfg_upd_aux_pm_en;
wire [`CX_NFUNC-1:0]                cfg_pmstatus_clr;
wire [(3*`CX_NFUNC)-1:0]            cfg_pmstate;
wire [`CX_NFUNC-1:0]                cfg_pme_en;
wire [`CX_NFUNC-1:0]                cfg_aux_pm_en;
wire [`CX_NFUNC-1:0]                cfg_upd_req_id;
wire                                int_cfg_upd_req_id;
wire    [7:0]                       int_cfg_pbus_num;
wire    [4:0]                       int_cfg_pbus_dev_num;
wire                                cfg_clk_pm_en;
wire                                int_radm_pm_to_ack;
wire [(5*`CX_NFUNC)-1:0]            cfg_pme_cap;

wire [`CX_NL-1:0]                   rmlh_descrambled_even_parity;
wire [`CX_NL-1:0]                   xmlh_scramble_even_parity;
wire [1:0]                          pipe_aux_sync_p1_ack;
wire [1:0]                          pipe_aux_sync_block;
wire [`CX_L1SUB_CONTROL_WD-1:0]     cfg_l1sub_control;
wire [`CX_PL_L1SUB_CONTROL_WD-1:0]  cfg_pl_l1sub_control;
wire                                cfg_pl_l1_exit_mode;
wire                                cfg_pl_l1_clk_sel;
wire                                cfg_p2nobeacon_enable;
wire [31:0]                         cfg_utility;
wire [31:0]                         pm_cfg_utility;
wire                                cfg_pipe_optional_pclkchange_hs;
wire [17:0]                         cfg_phy_rst_timer;
wire [5:0]                          cfg_pma_phy_rst_delay_timer;
wire                                cfg_phy_perst_on_warm_reset;
wire                                cfg_pl_gen3_zrxdc_noncompl;
wire                                pme_to_ack_grt;
wire                                lbc_active;
wire [`CX_NFUNC-1:0]                pm_pme_grant;
wire                                pme_turn_off_grt;
wire                                pm_io_handler_app_sris_mode;
wire                                xmlh_sris_enable;
wire [`CX_NL-1:0]                      pre_serdes_pipe_turnoff_lanes;
wire [(`CX_PHY_PDOWN_WD - 1) :0]       pre_mac_phy_powerdown;
wire [`CX_NL*`CX_PHY_TXEI_WD-1:0]      int_mac_phy_txelecidle;
wire [(`CX_PIPE_DATA_WD - 1):0]        pre_mac_phy_txdata;
wire [`CX_NL-1:0]                      pre_mac_phy_txdetectrx_loopback;
wire [`CX_NL-1:0]                      mac_phy_txcompliance;
wire [`CX_NL-1:0]                      glue_mac_phy_txcompliance;
wire [`CX_NL-1:0]                      pre_mac_phy_rxpolarity;
wire [`CX_NL-1:0]                      tmp_mac_phy_rxpolarity;
wire [(`CX_PHY_WIDTH_WD -1):0]         pre_mac_phy_width;
wire                                   pre_mac_phy_serdes_arch;
wire [(`CX_PHY_WIDTH_WD -1):0]         pre_mac_phy_rxwidth;
wire [`CX_NL-1:0]                      pre_serdes_pipe_rxready;
wire [`PCLK_RATE_WD-1:0]               pre_mac_phy_pclk_rate;
wire [`CX_NL-1:0]                      pre_mac_phy_rxstandby;
wire [`CX_PHY_RATE_WD-1:0]             pre_mac_phy_rate;
wire [`CX_PHY_TXDEEMPH_WD-1:0]         pre_mac_phy_txdeemph;
wire [`CX_NL-1:0]                      pre_mac_phy_txdatavalid;
wire [`CX_NL-1:0]                      pre_mac_phy_rxeqeval;
wire [`CX_NL-1:0]                      pre_mac_phy_dirchange;
wire [`CX_NL*`CX_TX_COEF_WD-1:0]       pre_mac_phy_smlh_coef_rtx;
wire [`CX_NL*8-1:0]                pre_mac_phy_mbus;
wire [`CX_NL-1:0]                  sqlchd_rxelecidle;
wire [31:0]                        pre_cfg_phy_control;
wire [`CX_L2NL-1:0]                smlh_lane_flip_ctrl;
wire                               cfg_link_retrain;
wire                               cfg_lpbk_en;
wire                               cfg_plreg_reset;
wire [(2*`CX_PHY_PDOWN_WD) - 1 : 0]pm_powerdown_status;
wire                               cfg_force_powerdown;
wire                               cfg_directed_speed_change;      // config bit to start speed change
wire [`CX_PL_MULTILANE_CONTROL_WD-1:0] cfg_pl_multilane_control;
wire                               msg_gen_unlock_grant;
wire                               pm_ltssm_enable;
wire [`CX_NL-1:0]                  pm_rmlh_descrambled_even_parity;
wire [`CX_NL-1:0]                  pm_xmlh_scramble_even_parity;
wire                               pm_smlh_l23_exit;
wire                               pm_xmt_turnoff;
wire [`CX_NFUNC-1:0]               pm_xmt_to_ack;
wire [`CX_NFUNC-1:0]               pm_xmt_pme;
wire                               pm_turnoff_timeout;
wire [`CX_BUSNUM_WD -1:0]          pm_bus_num;
wire [`CX_DEVNUM_WD -1:0]          pm_dev_num;
wire [(`CX_PHY_PDOWN_WD - 1) : 0]  pm_int_phy_powerdown;
wire                               pm_current_powerdown_p1;
wire                               pm_current_powerdown_p0;
wire                               pm_smlh_l1_2_latched; // 1: L1_SUB entered L1_2 substate
wire                               pm_smlh_l1_n_latched; // 1: L1_SUB entered L1_n substate
wire                               pm_in_l11;      // Level: L1.1 Entry for Ras D.E.S event counter
wire                               pm_in_l12;      // Level: L1.2 Entry for Ras D.E.S event counter
wire                               pm_in_l1_short; // Level: L1 short duration for Ras D.E.S event counter
wire                               pm_in_l1_cpm;   // Level: L1 Clock PM (L1 with REFCLK removal/PLL Off) for Ras D.E.S event counter
wire                               pm_in_l1_abort; // Level: L1.2 abort for Ras D.E.S event counter
wire                               pm_pme_resend_flag;  // Level : PME Re-Send flag
wire                               pm_block_phystatus;
wire [1:0]                         pm_en_pulse_det;
wire                               pm_sys_aux_pwr_det;
wire [`CX_NFUNC-1:0]               pm_pme_en_split;
wire [`CX_NFUNC-1:0]               pm_aux_pm_en_split;
wire                               pm_init_rst;
wire                               pm_unlock_msg_req;
wire [`CX_L2NL - 1 : 0]            pm_rx_lane_flip_en;
wire [`CX_L2NL - 1 : 0]            pm_tx_lane_flip_en;
wire [`CX_L2NL - 1 : 0]            pm_rx_pol_lane_flip_ctrl;
wire                              pm_smlh_link_retrain;
wire                              msg_gen_hv;
wire                              lbc_cpl_hv;

wire [`CX_NL-1:0]                 latched_rxdetected;        // Level : PIPE: Detect Lane for Ras D.E.S Silicon Debug
wire [`CX_NL-1:0]                 pm_latched_rxdetected;

wire pm_cxl_cache_slv_req;  // Synchronized CXL.cache Slave Init request to vLSM
wire pm_cxl_mem_slv_req;    // Synchronized CXL.mem Slave Init request to vLSM




DWC_pcie_native_core

#(
    .INST (INST)
 ) 
 u_DWC_pcie_native_core (
     .core_clk (core_clk)
    ,.xali_xaim_pkt  (xali_xaim_pkt)
    ,.xaim_xali_halt (xaim_xali_halt)
    ,.app_segment_id (app_segment_id)
    ,.cfg_segment_id (cfg_segment_id)
    ,.xali_posted_tlp_sent (xali_posted_tlp_sent)
    ,.radm_cpl_timeout       (radm_cpl_timeout     )
    ,.radm_timeout_func_num  (radm_timeout_func_num)
    ,.radm_timeout_cpl_tc    (radm_timeout_cpl_tc  )
    ,.radm_timeout_cpl_attr  (radm_timeout_cpl_attr)
    ,.radm_timeout_cpl_len   (radm_timeout_cpl_len)
    ,.radm_timeout_cpl_tag   (radm_timeout_cpl_tag)
    ,.cfg_10b_tag_req_en    (cfg_10b_tag_req_en  )
    ,.app_dbi_ro_wr_disable          (app_dbi_ro_wr_disable)
    ,.ext_lbc_override_en      (ext_lbc_override_en     )


    ,.ext_lbc_ack              (ext_lbc_ack             )
    ,.ext_lbc_din              (ext_lbc_din             )
    ,.lbc_ext_addr             (lbc_ext_addr            )
    ,.lbc_ext_dout             (lbc_ext_dout            )
    ,.lbc_ext_valid            (lbc_ext_valid           )
    ,.lbc_ext_cs               (lbc_ext_cs              )
    ,.lbc_ext_wr               (lbc_ext_wr              )
    ,.lbc_ext_rd               (lbc_ext_rd              )
    ,.lbc_ext_dbi_access       (lbc_ext_dbi_access      )
    ,.lbc_ext_cxl_mbar0_access (lbc_ext_cxl_mbar0_access)
    ,.lbc_ext_rom_access       (lbc_ext_rom_access      )
    ,.lbc_ext_io_access        (lbc_ext_io_access       )
    ,.lbc_ext_bar_num          (lbc_ext_bar_num         )
//HH EDIT: `ifdef CC_AXI_MSE_FILTER_EN
//HH EDIT:     ,.cfg_axi_s_mse_filter_en  (cfg_axi_s_mse_filter_en )
//HH EDIT: `endif //CC_AXI_MSE_FILTER_EN
//HH EDIT: `ifdef CC_AXI_ADDR_RANGE_FILTER_EN
//HH EDIT:     ,.cfg_axi_s_addr_rang_filter_en (cfg_axi_s_addr_rang_filter_en)
//HH EDIT: `endif //CC_AXI_ADDR_RANGE_FILTER_EN
    ,.ven_msi_req       (ven_msi_req     )
    ,.ven_msi_func_num  (ven_msi_func_num)
    ,.ven_msi_tc      (ven_msi_tc    )
    ,.ven_msi_vector  (ven_msi_vector)
    ,.ven_msi_grant   (ven_msi_grant )
    ,.cfg_msi_en      (cfg_msi_en    )
    ,.cfg_msi_addr         (cfg_msi_addr       )
    ,.cfg_msi_data         (cfg_msi_data       )
    ,.cfg_msi_64           (cfg_msi_64         )
    ,.cfg_multi_msi_en     (cfg_multi_msi_en   )
    ,.cfg_msi_ext_data_en  (cfg_msi_ext_data_en)

    ,.cfg_tph_req_en      (cfg_tph_req_en    )
    ,.cfg_pf_tph_st_mode  (cfg_pf_tph_st_mode)
    ,.cfg_pf_pasid_en               (cfg_pf_pasid_en             )
    ,.cfg_pf_pasid_execute_perm_en  (cfg_pf_pasid_execute_perm_en)
    ,.cfg_pf_pasid_priv_mode_en     (cfg_pf_pasid_priv_mode_en   )
    ,.cfg_atomic_req_en  (cfg_atomic_req_en )
    ,.cfg_atomic_egress_block  (cfg_atomic_egress_block )
    ,.cfg_dmwr_req_en                (cfg_dmwr_req_en)
    ,.cfg_obff_en         (cfg_obff_en       )
    ,.app_obff_msg_grant  (app_obff_msg_grant)
    ,.cfg_ltr_m_en        (cfg_ltr_m_en      )
    ,.cfg_ltr_max_latency (cfg_ltr_max_latency)
    ,.cfg_disable_ltr_clr_msg (cfg_disable_ltr_clr_msg)
    ,.cfg_pwr_budget_data_reg      (cfg_pwr_budget_data_reg    )
    ,.cfg_pwr_budget_func_num      (cfg_pwr_budget_func_num    )
    ,.cfg_pwr_budget_data_sel_reg  (cfg_pwr_budget_data_sel_reg)
    ,.cfg_pwr_budget_sel           (cfg_pwr_budget_sel         )
    ,.cfg_ari_fwd_en               (cfg_ari_fwd_en             )
    ,.ven_msg_fmt       (ven_msg_fmt     )
    ,.ven_msg_type      (ven_msg_type    )
    ,.ven_msg_tc        (ven_msg_tc      )
    ,.ven_msg_td        (ven_msg_td      )
    ,.ven_msg_ep        (ven_msg_ep      )
    ,.ven_msg_attr      (ven_msg_attr    )
    ,.ven_msg_len       (ven_msg_len     )
    ,.ven_msg_func_num  (ven_msg_func_num)
    ,.ven_msg_tag    (ven_msg_tag  )
    ,.ven_msg_code   (ven_msg_code )
    ,.ven_msg_data   (ven_msg_data )
    ,.ven_msg_req    (ven_msg_req  )
    ,.ven_msg_grant  (ven_msg_grant)
    ,.tx_lane_flip_en (tx_lane_flip_en)
    ,.pm_hold_exit_l1             (pm_hold_exit_l1                )
    ,.pm_link_exit_l1             (pm_link_exit_l1                )
    ,.pm_link_exit_l23            (pm_link_exit_l23               )
    ,.pm_pl_wake_ack              (pm_pl_wake_ack                 )
    ,.pm_pl_clk_req               (pm_pl_clk_req                  )
    ,.pm_pl_phyinl1               (pm_pl_phyinl1                  )
    ,.pm_pl_phyinl2               (pm_pl_phyinl2                  )
    ,.cfg_pm_clk_pm_en            (cfg_pm_clk_pm_en               )
    ,.software_entr_l1            (software_entr_l1               )
    ,.software_entr_l23           (software_entr_l23              )
    ,.pm_aspm_l0s_en              (pm_aspm_l0s_en                 )
    ,.pm_aspm_l1_en               (pm_aspm_l1_en                  )
    ,.pm_xtlh_block_tlp           (pm_xtlh_block_tlp              )
    ,.pm_radm_block_tlp           (pm_radm_block_tlp              )
    ,.pm_linkst_in_l0s_o          (int_pm_linkst_in_l0s           )
    ,.pm_linkst_in_l0s            (pm_linkst_in_l0s               )
    ,.pm_linkst_in_l0             (pm_linkst_in_l0                )
    ,.pm_usp_link_state           (pm_usp_link_state              )
    ,.pm_dsp_link_state           (pm_dsp_link_state              )
    ,.shadow_pm_usp_link_state    (shadow_pm_usp_link_state       )
    ,.shadow_pm_dsp_link_state    (shadow_pm_dsp_link_state       )
    ,.pm_wake_req_exit_l0s        (pm_wake_req_exit_l0s           )
    ,.pm_l2_entry_flag            (pm_l2_entry_flag               )
    ,.app_req_entr_l1             (app_req_entr_l1                )
    ,.pm_wake_any_if_pending      (pm_wake_any_if_pending         )
    ,.app_xfer_pending            (app_xfer_pending               )
    ,.lp_pcie_l1_exit             (lp_pcie_l1_exit                )
    ,.lp_pcie_clk_ack             (lp_pcie_clk_ack                )
    ,.lp_pcie_wake_req            (lp_pcie_wake_req               )
    ,.pl_pcie_wake_ack            (pl_pcie_wake_ack               )
    ,.pl_pcie_clk_req             (pl_pcie_clk_req                )
    ,.pl_pcie_phyinl1             (pl_pcie_phyinl1                )
    ,.pl_pcie_phyinl2             (pl_pcie_phyinl2                )
    ,.pl_pcie_state_l1            (pl_pcie_state_l1               )
    ,.pl_pcie_state_l2            (pl_pcie_state_l2               )
    ,.pl_pcie_state_active        (pl_pcie_state_active           )
    ,.pl_pcie_link_up             (pl_pcie_link_up                )
    ,.lp_cxl_l1_exit              (lp_cxl_l1_exit                 )
    ,.lp_cxl_clk_ack              (lp_cxl_clk_ack                 )
    ,.lp_cxl_wake_req             (lp_cxl_wake_req                )
    ,.pl_cxl_wake_ack             (pl_cxl_wake_ack                )
    ,.pl_cxl_clk_req              (pl_cxl_clk_req                 )
    ,.pl_cxl_phyinl1              (pl_cxl_phyinl1                 )
    ,.pl_cxl_phyinl2              (pl_cxl_phyinl2                 )
    ,.pl_cxl_state_l1             (pl_cxl_state_l1                )
    ,.pl_cxl_state_l2             (pl_cxl_state_l2                )
    ,.pl_cxl_mode_enable          (pl_cxl_mode_enable             )
    ,.pm_xdlh_enter_l23           (pm_xdlh_enter_l23              )
    ,.pm_l1_entry_started         (int_pm_l1_entry_started        )
    ,.pm_l1_in_progress           (pm_l1_in_progress              )
    ,.pm_aspm_l1_enter_ready      (int_pm_aspm_l1_enter_ready     )
    ,.latch_as_entr_l1            (latch_as_entr_l1               )
    ,.pm_prot_idle_flag           (pm_prot_idle_flag              )
    ,.lp_sdb_l1sub_aspm           (lp_sdb_l1sub_aspm              )
    ,.lp_sdb_l1sub_pcipm          (lp_sdb_l1sub_pcipm             )
    ,.sys_int            (sys_int       )
    ,.sys_aux_pwr_det  (sys_aux_pwr_det )
    ,.sys_atten_button_pressed   (sys_atten_button_pressed )
    ,.sys_pre_det_state          (sys_pre_det_state        )
    ,.sys_mrl_sensor_state       (sys_mrl_sensor_state     )
    ,.sys_pwr_fault_det          (sys_pwr_fault_det        )
    ,.sys_mrl_sensor_chged       (sys_mrl_sensor_chged     )
    ,.sys_pre_det_chged          (sys_pre_det_chged        )
    ,.sys_cmd_cpled_int          (sys_cmd_cpled_int        )
    ,.sys_eml_interlock_engaged  (sys_eml_interlock_engaged)
    ,.cfg_pwr_ind                (cfg_pwr_ind              )
    ,.cfg_atten_ind              (cfg_atten_ind            )
    ,.cfg_pwr_ctrler_ctrl        (cfg_pwr_ctrler_ctrl      )
    ,.app_unlock_msg             (app_unlock_msg           )
    ,.app_obff_idle_msg_req        (app_obff_idle_msg_req      )
    ,.app_obff_obff_msg_req        (app_obff_obff_msg_req      )
    ,.app_obff_cpu_active_msg_req  (app_obff_cpu_active_msg_req)
    ,.pm_block_all_tlp   (pm_block_all_tlp)
    ,.cfg_bar0_start  (cfg_bar0_start)
    ,.cfg_bar1_start  (cfg_bar1_start)
    ,.cfg_bar0_limit  (cfg_bar0_limit)
    ,.cfg_bar1_limit  (cfg_bar1_limit)
    ,.cfg_bar2_start  (cfg_bar2_start)
    ,.cfg_bar2_limit  (cfg_bar2_limit)
    ,.cfg_bar3_start  (cfg_bar3_start)
    ,.cfg_bar3_limit  (cfg_bar3_limit)
    ,.cfg_bar4_start  (cfg_bar4_start)
    ,.cfg_bar4_limit  (cfg_bar4_limit)
    ,.cfg_bar5_start  (cfg_bar5_start)
    ,.cfg_bar5_limit  (cfg_bar5_limit)
    ,.cfg_exp_rom_start    (cfg_exp_rom_start  )
    ,.cfg_exp_rom_limit    (cfg_exp_rom_limit  )
    ,.cfg_bus_master_en    (cfg_bus_master_en  )
    ,.cfg_mem_space_en     (cfg_mem_space_en   )
    ,.cfg_max_rd_req_size  (cfg_max_rd_req_size)
    ,.cfg_max_payload_size (cfg_max_payload_size)
    ,.cfg_memtype_value    (cfg_memtype_value)
    ,.cfg_memtype_boundary (cfg_memtype_boundary)
    ,.cfg_ext_tag_en       (cfg_ext_tag_en)
    ,.cfg_rcb              (cfg_rcb             )
    ,.cfg_pm_no_soft_rst   (cfg_pm_no_soft_rst  )
    ,.cfg_aer_rc_err_int   (cfg_aer_rc_err_int )
    ,.cfg_aer_rc_err_msi   (cfg_aer_rc_err_msi )
    ,.cfg_aer_int_msg_num  (cfg_aer_int_msg_num)
    ,.cfg_sys_err_rc       (cfg_sys_err_rc     )
    ,.cfg_pme_int          (cfg_pme_int        )
    ,.cfg_pme_msi          (cfg_pme_msi        )
    ,.cfg_crs_sw_vis_en    (cfg_crs_sw_vis_en        )
    ,.cfg_pcie_cap_int_msg_num  (cfg_pcie_cap_int_msg_num)
    ,.rdlh_link_up      (rdlh_link_up    )
    ,.smlh_ltssm_state  (smlh_ltssm_state)
    ,.cfg_flit_log_trg_evnt_msi(cfg_flit_log_trg_evnt_msi)
    ,.cdm_pm_state_trans_tracker(cdm_pm_state_trans_tracker)
    ,.pm_cdm_state_trans_tracking(pm_cdm_state_trans_tracking)
    ,.smlh_pm_state_trans1_flag(smlh_pm_state_trans1_flag)
    ,.smlh_pm_state_trans2_flag(smlh_pm_state_trans2_flag)
    ,.cfg_flit_latency_msi(cfg_flit_latency_msi)
    ,.cfg_flit_perf_interr_vec(cfg_flit_perf_interr_vec)
    ,.cfg_sts_1_ltssm_latency_msi(cfg_sts_1_ltssm_latency_msi)
    ,.smlh_ltssm_state_rcvry_eq (smlh_ltssm_state_rcvry_eq)
    ,.smlh_link_up      (smlh_link_up    )
    ,.smlh_req_rst_not  (smlh_req_rst_not)
    ,.link_req_rst_not  (link_req_rst_not)
    ,.brdg_slv_xfer_pending  (brdg_slv_xfer_pending)
    ,.brdg_dbi_xfer_pending  (brdg_dbi_xfer_pending)
    ,.brdg_mstr_xfer_pending  (brdg_mstr_xfer_pending)
    ,.radm_vendor_msg      (radm_vendor_msg)
    ,.radm_vendor_msg_type (radm_vendor_msg_type)
    ,.radm_msg_ltr  (radm_msg_ltr)
    ,.radm_msg_payload  (radm_msg_payload)
    ,.radm_msg_unlock   (radm_msg_unlock)
    ,.radm_msg_idle        (radm_msg_idle      )
    ,.radm_msg_obff        (radm_msg_obff      )
    ,.radm_msg_cpu_active  (radm_msg_cpu_active)
    ,.radm_msg_req_id      (radm_msg_req_id    )
    ,.radm_inta_asserted    (radm_inta_asserted  )
    ,.radm_intb_asserted    (radm_intb_asserted  )
    ,.radm_intc_asserted    (radm_intc_asserted  )
    ,.radm_intd_asserted    (radm_intd_asserted  )
    ,.radm_inta_deasserted  (radm_inta_deasserted)
    ,.radm_intb_deasserted  (radm_intb_deasserted)
    ,.radm_intc_deasserted  (radm_intc_deasserted)
    ,.radm_intd_deasserted  (radm_intd_deasserted)
    ,.radm_correctable_err  (radm_correctable_err)
    ,.radm_nonfatal_err     (radm_nonfatal_err   )
    ,.radm_fatal_err        (radm_fatal_err      )
    ,.radm_pm_pme           (radm_pm_pme         )
    ,.radm_pm_to_ack        (radm_pm_to_ack      )
    ,.radm_pm_turnoff  (radm_pm_turnoff  )
    ,.rtlh_rfc_upd   (rtlh_rfc_upd )
    ,.rtlh_rfc_data  (rtlh_rfc_data)
    ,.cfg_eml_control  (cfg_eml_control)
    ,.hp_pme           (hp_pme         )
    ,.hp_int           (hp_int         )
    ,.hp_msi           (hp_msi         )
    ,.pm_io_handler_app_sris_mode (pm_io_handler_app_sris_mode  )
    ,.cfg_comm_clk_config    (cfg_comm_clk_config)
    ,.app_ltssm_enable  (app_ltssm_enable)
    ,.cfg_pbus_num      (cfg_pbus_num    )
    ,.cfg_pbus_dev_num  (cfg_pbus_dev_num)

    ,.pm_dstate         (pm_dstate       )
    ,.pm_status     (pm_status     )
    ,.cfg_link_dis          (cfg_link_dis)
    ,.cfg_link_auto_bw_int  (cfg_link_auto_bw_int)
    ,.cfg_link_auto_bw_msi  (cfg_link_auto_bw_msi)
    ,.cfg_bw_mgt_int        (cfg_bw_mgt_int      )
    ,.cfg_bw_mgt_msi        (cfg_bw_mgt_msi      )
    ,.cfg_link_eq_req_int  (cfg_link_eq_req_int)
    ,.usp_eq_redo_executed_int (usp_eq_redo_executed_int)
    ,.app_ltr_msg_req       (app_ltr_msg_req     )
    ,.app_ltr_msg_grant     (app_ltr_msg_grant   )
    ,.app_ltr_msg_latency   (app_ltr_msg_latency )
    ,.app_ltr_msg_func_num  (app_ltr_msg_func_num)
    ,.app_ltr_latency       (app_ltr_latency     )
    ,.radm_q_not_empty  (radm_q_not_empty)
    ,.radm_qoverflow    (radm_qoverflow  )
    ,.rtlh_fc_overflow_err (rtlh_fc_overflow_err)
    ,.trgt_cpl_timeout           (trgt_cpl_timeout         )
    ,.trgt_timeout_cpl_func_num  (trgt_timeout_cpl_func_num)
    ,.trgt_timeout_cpl_tc     (trgt_timeout_cpl_tc   )
    ,.trgt_timeout_cpl_attr   (trgt_timeout_cpl_attr )
    ,.trgt_timeout_cpl_len    (trgt_timeout_cpl_len  )
    ,.trgt_timeout_lookup_id  (trgt_timeout_lookup_id)
    ,.trgt_lookup_id          (trgt_lookup_id        )
    ,.trgt_lookup_empty       (trgt_lookup_empty     )
    ,.app_hdr_valid  (app_hdr_valid)
    ,.app_hdr_log    (app_hdr_log  )
    ,.app_hdr_flitmode (app_hdr_flitmode)
    ,.app_hdr_log_size (app_hdr_log_size)
    ,.app_err_bus       (app_err_bus     )
    ,.app_err_advisory  (app_err_advisory)
    ,.app_poisoned_tlp_type (app_poisoned_tlp_type)
    ,.app_err_func_num  (app_err_func_num)
    ,.mac_phy_powerdown   (mac_phy_powerdown )
    ,.mac_phy_txelecidle  (mac_phy_txelecidle)
    ,.phy_mac_phystatus   (phy_mac_phystatus )
    ,.pm_current_data_rate  (pm_current_data_rate)
    ,.pipe_rx_clk         (pipe_rx_clk       )
    ,.pipe_rx_rst_n       (pipe_rx_rst_n     )
    ,.phy_mac_rxdata            (phy_mac_rxdata           )
    ,.phy_mac_rxvalid           (phy_mac_rxvalid      )
    ,.phy_mac_rxstatus          (phy_mac_rxstatus       )
    ,.phy_mac_rxstandbystatus   (phy_mac_rxstandbystatus  )
    ,.phy_cfg_status            (phy_cfg_status           )
    ,.mac_phy_txdetectrx_loopback  (mac_phy_txdetectrx_loopback)
    ,.mac_phy_txcompliance         (mac_phy_txcompliance       )
    ,.mac_phy_rxpolarity           (mac_phy_rxpolarity         )
    ,.mac_phy_width                (mac_phy_width              )
    ,.mac_phy_rate        (mac_phy_rate      )
    ,.mac_phy_txdeemph    (mac_phy_txdeemph  )
    ,.cfg_hw_auto_sp_dis  (cfg_hw_auto_sp_dis)
    ,.phy_mac_messagebus  (phy_mac_messagebus)
    ,.pipe_msgbus_rst_n     (pipe_msgbus_rst_n   )
    ,.app_margining_ready            (app_margining_ready)
    ,.app_margining_software_ready   (app_margining_software_ready)
    ,.pre_cfg_phy_control  (pre_cfg_phy_control)
    ,.core_clk_ug (core_clk_ug)
    ,.aux_clk_g             (aux_clk_g            )
    ,.radm_clk_g            (radm_clk_g           )
    ,.en_radm_clk_g         (en_radm_clk_g        )
    ,.radm_idle             (radm_idle            )
    ,.pwr_rst_n             (pwr_rst_n            )
    ,.sticky_rst_n          (sticky_rst_n         )
    ,.non_sticky_rst_n      (non_sticky_rst_n     )
    ,.core_rst_n            (core_rst_n           )
    ,.pm_sel_aux_clk        (pm_sel_aux_clk       )
    ,.device_type            (device_type         )
    ,.app_req_retry_en      (app_req_retry_en    )
    ,.app_pf_req_retry_en   (app_pf_req_retry_en )
    ,.app_drs_ready         (app_drs_ready       )
    ,.cfg_drs_msi           (cfg_drs_msi         )
    ,.cfg_up_drs_to_frs     (cfg_up_drs_to_frs   )
    ,.app_pf_frs_ready      (app_pf_frs_ready    )
    ,.pf_frs_grant          (pf_frs_grant        )
    ,.frsq_msi          (frsq_msi        )
    ,.frsq_int_msg_num  (frsq_int_msg_num)
    ,.training_rst_n  (training_rst_n )
    ,.xdlh_retryram_raddr           (xdlh_retryram_raddr        )
    ,.xdlh_retryram_waddr           (xdlh_retryram_waddr        )
    ,.xdlh_retryram_data            (xdlh_retryram_data         )
    ,.xdlh_retryram_we              (xdlh_retryram_we           )
    ,.xdlh_retryram_en              (xdlh_retryram_en           )
    ,.retryram_xdlh_data            (retryram_xdlh_data         )
    ,.xdlh_retrysotram_waddr        (xdlh_retrysotram_waddr     )
    ,.xdlh_retrysotram_raddr        (xdlh_retrysotram_raddr     )
    ,.xdlh_retrysotram_data         (xdlh_retrysotram_data      )
    ,.xdlh_retrysotram_we           (xdlh_retrysotram_we        )
    ,.xdlh_retrysotram_en           (xdlh_retrysotram_en        )
    ,.retrysotram_xdlh_data         (retrysotram_xdlh_data      )
    ,.radm_formqram_addra_vc0_p            (radm_formqram_addra_vc0_p)
    ,.radm_formqram_ena_vc0_p              (radm_formqram_ena_vc0_p)
    ,.radm_formqram_wea_vc0_p              (radm_formqram_wea_vc0_p)
    ,.radm_formqram_dina_vc0_p             (radm_formqram_dina_vc0_p)
    ,.radm_formqram_addrb_vc0_p            (radm_formqram_addrb_vc0_p)
    ,.radm_formqram_enb_vc0_p              (radm_formqram_enb_vc0_p)
    ,.formqram_radm_doutb_vc0_p            (formqram_radm_doutb_vc0_p)
    ,.radm_formqram_addra_vc0_np           (radm_formqram_addra_vc0_np )
    ,.radm_formqram_ena_vc0_np             (radm_formqram_ena_vc0_np   )
    ,.radm_formqram_wea_vc0_np             (radm_formqram_wea_vc0_np   )
    ,.radm_formqram_dina_vc0_np            (radm_formqram_dina_vc0_np  )
    ,.radm_formqram_addrb_vc0_np           (radm_formqram_addrb_vc0_np )
    ,.radm_formqram_enb_vc0_np             (radm_formqram_enb_vc0_np   )
    ,.formqram_radm_doutb_vc0_np           (formqram_radm_doutb_vc0_np )
    ,.radm_formqram_addra_vc0_cpl          (radm_formqram_addra_vc0_cpl )
    ,.radm_formqram_ena_vc0_cpl            (radm_formqram_ena_vc0_cpl   )
    ,.radm_formqram_wea_vc0_cpl            (radm_formqram_wea_vc0_cpl   )
    ,.radm_formqram_dina_vc0_cpl           (radm_formqram_dina_vc0_cpl  )
    ,.radm_formqram_addrb_vc0_cpl          (radm_formqram_addrb_vc0_cpl )
    ,.radm_formqram_enb_vc0_cpl            (radm_formqram_enb_vc0_cpl   )
    ,.formqram_radm_doutb_vc0_cpl          (formqram_radm_doutb_vc0_cpl )
    ,.radm_ras_des_err_info_0                       (radm_ras_des_err_info_0)  
    ,.cdm_ras_des_ec_ram_addra    (cdm_ras_des_ec_ram_addra  )
    ,.cdm_ras_des_ec_ram_addrb    (cdm_ras_des_ec_ram_addrb  )
    ,.cdm_ras_des_ec_ram_datain   (cdm_ras_des_ec_ram_datain )
    ,.cdm_ras_des_ec_ram_wea      (cdm_ras_des_ec_ram_wea    )
    ,.cdm_ras_des_ec_ram_ena      (cdm_ras_des_ec_ram_ena    )
    ,.cdm_ras_des_ec_ram_enb      (cdm_ras_des_ec_ram_enb    )
    ,.cdm_ras_des_ec_ram_dataout  (cdm_ras_des_ec_ram_dataout)
    ,.cdm_ras_des_tba_ram_addra    (cdm_ras_des_tba_ram_addra  )
    ,.cdm_ras_des_tba_ram_addrb    (cdm_ras_des_tba_ram_addrb  )
    ,.cdm_ras_des_tba_ram_datain   (cdm_ras_des_tba_ram_datain )
    ,.cdm_ras_des_tba_ram_wea      (cdm_ras_des_tba_ram_wea    )
    ,.cdm_ras_des_tba_ram_ena      (cdm_ras_des_tba_ram_ena    )
    ,.cdm_ras_des_tba_ram_enb      (cdm_ras_des_tba_ram_enb    )
    ,.cdm_ras_des_tba_ram_dataout  (cdm_ras_des_tba_ram_dataout)
    ,.cfg_reg_serren              (cfg_reg_serren       )
    ,.cfg_cor_err_rpt_en          (cfg_cor_err_rpt_en   )
    ,.cfg_nf_err_rpt_en           (cfg_nf_err_rpt_en    )
    ,.cfg_f_err_rpt_en            (cfg_f_err_rpt_en     )
    ,.cdm_ras_des_einj0_req   (cdm_ras_des_einj0_req)
    ,.cdm_ras_des_einj0_ack   (cdm_ras_des_einj0_ack)
    ,.cdm_ras_des_ec_info_common  (cdm_ras_des_ec_info_common)
    ,.cdm_ras_des_ec_info_l0      (cdm_ras_des_ec_info_l0    )
    ,.cdm_ras_des_ec_info_l1  (cdm_ras_des_ec_info_l1)
    ,.cdm_ras_des_ec_info_l2  (cdm_ras_des_ec_info_l2)
    ,.cdm_ras_des_ec_info_l3  (cdm_ras_des_ec_info_l3)
    ,.cdm_ras_des_ec_info_l4  (cdm_ras_des_ec_info_l4)
    ,.cdm_ras_des_ec_info_l5  (cdm_ras_des_ec_info_l5)
    ,.cdm_ras_des_ec_info_l6  (cdm_ras_des_ec_info_l6)
    ,.cdm_ras_des_ec_info_l7  (cdm_ras_des_ec_info_l7)
    ,.app_ras_des_sd_hold_ltssm   (app_ras_des_sd_hold_ltssm )
    ,.cdm_ras_des_sd_info_common  (cdm_ras_des_sd_info_common)
    ,.cdm_ras_des_sd_info_l0      (cdm_ras_des_sd_info_l0    )
    ,.cdm_ras_des_sd_info_l1      (cdm_ras_des_sd_info_l1    )
    ,.cdm_ras_des_sd_info_l2  (cdm_ras_des_sd_info_l2)
    ,.cdm_ras_des_sd_info_l3  (cdm_ras_des_sd_info_l3)
    ,.cdm_ras_des_sd_info_l4  (cdm_ras_des_sd_info_l4)
    ,.cdm_ras_des_sd_info_l5  (cdm_ras_des_sd_info_l5)
    ,.cdm_ras_des_sd_info_l6  (cdm_ras_des_sd_info_l6)
    ,.cdm_ras_des_sd_info_l7  (cdm_ras_des_sd_info_l7)
    ,.cdm_ras_des_sd_info_v0  (cdm_ras_des_sd_info_v0)
    ,.cdm_ras_des_tba_info_common  (cdm_ras_des_tba_info_common)
    ,.app_ras_des_tba_ctrl         (app_ras_des_tba_ctrl       )
    ,.exp_rom_validation_status_strobe  (exp_rom_validation_status_strobe )
    ,.exp_rom_validation_status         (exp_rom_validation_status        )
    ,.exp_rom_validation_details_strobe (exp_rom_validation_details_strobe)
    ,.exp_rom_validation_details        (exp_rom_validation_details       )
    ,.cxpl_debug_info        (cxpl_debug_info      )
    ,.cxpl_debug_info_ei     (cxpl_debug_info_ei   )
    ,.mac_phy_rxeqeval             (mac_phy_rxeqeval           )
    ,.assert_inta_grt    (assert_inta_grt  )
    ,.assert_intb_grt    (assert_intb_grt  )
    ,.assert_intc_grt    (assert_intc_grt  )
    ,.assert_intd_grt    (assert_intd_grt  )
    ,.deassert_inta_grt  (deassert_inta_grt)
    ,.deassert_intb_grt  (deassert_intb_grt)
    ,.deassert_intc_grt  (deassert_intc_grt)
    ,.deassert_intd_grt  (deassert_intd_grt)
    ,.cfg_int_pin        (cfg_int_pin      )

    ,.cfg_2ndbus_num  (cfg_2ndbus_num)
    ,.cfg_subbus_num  (cfg_subbus_num)
   ,.cfg_2nd_reset   (cfg_2nd_reset )
    ,.cfg_l1sub_en      (cfg_l1sub_en     )
    ,.app_clk_pm_en (app_clk_pm_en)
    ,.cfg_end2end_tlp_pfx_blck (cfg_end2end_tlp_pfx_blck)
    ,.aux_clk_active  (aux_clk_active)
    ,.cfg_ido_req_en (cfg_ido_req_en)
    ,.cfg_ido_cpl_en (cfg_ido_cpl_en)
    ,.cfg_send_cor_err   (cfg_send_cor_err  )
    ,.cfg_send_nf_err    (cfg_send_nf_err   )
    ,.cfg_send_f_err     (cfg_send_f_err    )
    ,.cfg_int_disable    (cfg_int_disable   )
    ,.cfg_no_snoop_en    (cfg_no_snoop_en   )
    ,.cfg_relax_order_en (cfg_relax_order_en)
    ,.ptm_context_valid (ptm_context_valid)
    ,.ptm_responder_rdy_to_validate (ptm_responder_rdy_to_validate)
    ,.ptm_local_clock   (ptm_local_clock  )
    ,.ptm_external_master_strobe      (ptm_external_master_strobe     )
    ,.ptm_external_master_time        (ptm_external_master_time       )
    ,.ptm_auto_update_signal  (ptm_auto_update_signal )
    ,.ptm_manual_update_pulse (ptm_manual_update_pulse)
    ,.ptm_clock_updated        (ptm_clock_updated   )
    ,.ptm_clock_correction     (ptm_clock_correction)
    ,.ptm_trigger_allowed      (ptm_trigger_allowed)
    ,.ptm_updating             (ptm_updating)
    ,.ptm_req_response_timeout (ptm_req_response_timeout)
    ,.ptm_req_dup_rx           (ptm_req_dup_rx)
    ,.ptm_req_replay_tx        (ptm_req_replay_tx)
    ,.cfg_ats_stu      (cfg_ats_stu     )
    ,.cfg_ats_cache_en (cfg_ats_cache_en)
    ,.surprise_down_err (surprise_down_err)
    ,.prs_res_failure                (prs_res_failure               )
    ,.prs_uprgi                      (prs_uprgi                     )
    ,.prs_stopped                    (prs_stopped                   )
    ,.cfg_prs_enable                 (cfg_prs_enable                )
    ,.cfg_prs_reset                  (cfg_prs_reset                 )
    ,.cfg_prs_stopped                (cfg_prs_stopped               )
    ,.cfg_prs_uprgi                  (cfg_prs_uprgi                 )
    ,.cfg_prs_response_failure       (cfg_prs_response_failure      )
    ,.cfg_prs_outstanding_allocation (cfg_prs_outstanding_allocation)
    ,.cfg_br_ctrl_serren    (cfg_br_ctrl_serren)
    ,.slv_dbi_addr   (slv_dbi_addr)
    ,.slv_dbi_din    (slv_dbi_din )
    ,.slv_dbi_cs     (slv_dbi_cs  )
    ,.slv_dbi_cs2    (slv_dbi_cs2 )
    ,.slv_dbi_wr     (slv_dbi_wr  )
    ,.slv_dbi_func_num (slv_dbi_func_num)
    ,.slv_dbi_bar_num    (slv_dbi_bar_num   )
    ,.slv_dbi_rom_access (slv_dbi_rom_access)
    ,.slv_dbi_io_access  (slv_dbi_io_access )
    ,.slv_lbc_dbi_ack  (slv_lbc_dbi_ack )
    ,.slv_lbc_dbi_dout (slv_lbc_dbi_dout)
    ,.ras_prot_r_disable (ras_prot_r_disable)
    ,.ras_prot_t_disable (ras_prot_t_disable)
    ,.pm_aux_clk          (pm_aux_clk         )
    ,.pm_aux_clk_active (pm_aux_clk_active)
    ,.trgt_lookup_id_i        (trgt_lookup_id_i       )

    ,.cfg_rasdp_error_mode_i    (cfg_rasdp_error_mode_i  )
    ,.ras_error_tracer_pending  (ras_error_tracer_pending)
    ,.ras_dp_unc_err            (ras_dp_unc_err)
    ,.ras_dp_cor_err            (ras_dp_cor_err)
    ,.ras_ram_unc_err           (ras_ram_unc_err)
    ,.ras_ram_cor_err           (ras_ram_cor_err)
    ,.axi_bridge_ras_dp_err_log (axi_bridge_ras_dp_err_log)
    ,.out_ras_dp_err_inj        (ras_dp_err_inj)
    ,.axi_bridge_in_ras_dp_err_inj_wake_up (axi_bridge_in_ras_dp_err_inj_wake_up)
    ,.hdma_ras_dp_err_log       (hdma_ras_dp_err_log)
    ,.hdma_ras_dp_err_inj       (hdma_ras_dp_err_inj)
    ,.cfg_rasdp_error_mode_en   (cfg_rasdp_error_mode_en )
    ,.cfg_err_resp       (cfg_err_resp     )
//HH: EDIT: `ifdef CC_AXI_ADDR_RANGE_FILTER_EN
//HH: EDIT:     ,.cfg_axi_s_addr_rang_filter_en (cfg_axi_s_addr_rang_filter_en)
//HH: EDIT:     ,.cfg_mem_base                  (cfg_mem_base            )
//HH: EDIT:     ,.cfg_mem_limit                 (cfg_mem_limit           )
//HH: EDIT:     ,.cfg_pref_mem_base             (cfg_pref_mem_base       )
//HH: EDIT:     ,.cfg_pref_mem_limit            (cfg_pref_mem_limit      )
//HH: EDIT: `endif //CC_AXI_ADDR_RANGE_FILTER_EN

    ,.cfg_order_rule_ctrl          (cfg_order_rule_ctrl       )
    ,.cfg_ax_mstr_ordr_p_event_sel (cfg_ax_mstr_ordr_p_event_sel)
    ,.cfg_ax_snp_en                (cfg_ax_snp_en               )
    ,.cfg_ib_p_id_mng_ctrl         (cfg_ib_p_id_mng_ctrl)
    ,.cfg_mstr_arcache_mode     (cfg_mstr_arcache_mode    )
    ,.cfg_mstr_awcache_mode     (cfg_mstr_awcache_mode    )
    ,.cfg_mstr_arcache_value    (cfg_mstr_arcache_value   )
    ,.cfg_mstr_awcache_value    (cfg_mstr_awcache_value   )
    ,.cfg_aximstr_msg_addr_high (cfg_aximstr_msg_addr_high)
    ,.cfg_aximstr_msg_addr_low  (cfg_aximstr_msg_addr_low )
    ,.cfg_mstr_ardomain_mode   (cfg_mstr_ardomain_mode )
    ,.cfg_mstr_awdomain_mode   (cfg_mstr_awdomain_mode )
    ,.cfg_mstr_ardomain_value  (cfg_mstr_ardomain_value)
    ,.cfg_mstr_awdomain_value  (cfg_mstr_awdomain_value)
    ,.cfg_ax_mstr_zeroread_fw  (cfg_ax_mstr_zeroread_fw)
    ,.cfg_axi_clk_gating_en    (cfg_axi_clk_gating_en)
    ,.int_radm_trgt1_mem_type  (int_radm_trgt1_mem_type)
    ,.atu_reg_out_type         (atu_reg_out_type       )
    ,.atu_reg_out_func_num     (atu_reg_out_func_num   )
    ,.atu_reg_out_func_bypass  (atu_reg_out_func_bypass)
    ,.atu_reg_out_snp          (atu_reg_out_snp        )
    ,.atu_reg_out_en        (atu_reg_out_en      )
    ,.atu_reg_out_base      (atu_reg_out_base    )
    ,.atu_reg_out_upr_base  (atu_reg_out_upr_base)
    ,.atu_reg_out_limit     (atu_reg_out_limit   )
    ,.atu_reg_out_uppr_limit (atu_reg_out_uppr_limit)
    ,.atu_reg_out_incr_rgn_size (atu_reg_out_incr_rgn_size)
    ,.crgb_cdm_rdata (crgb_cdm_rdata)
    ,.crgb_cdm_cs     (crgb_cdm_cs    )
    ,.crgb_cdm_ack    (crgb_cdm_ack   )
    ,.crgb_cdm_addr   (crgb_cdm_addr  )
    ,.crgb_cdm_wdata  (crgb_cdm_wdata )
    ,.crgb_cdm_wr     (crgb_cdm_wr    )
    ,.crgb_cdm_source (crgb_cdm_source)
    ,.radm_trgt1_cpl_lookup_id_rlsd (radm_trgt1_cpl_lookup_id_rlsd)
    ,.radm_trgt1_lookup_id_consmd (radm_trgt1_lookup_id_consmd)
    ,.brdg_slv_flush_ack    (brdg_slv_flush_ack)
    ,.rstctl_slv_flush_req         (rstctl_slv_flush_req )
    ,.rstctl_mstr_flush_req        (rstctl_mstr_flush_req)
    ,.rstctl_flush_done            (rstctl_flush_done)
    ,.pm_current_data_rate_others  (pm_current_data_rate_others)
    ,.atu_reg_out_invert       (atu_reg_out_invert)
    ,.cfg_hp_slot_ctrl_access        (cfg_hp_slot_ctrl_access)
    ,.cfg_dll_state_chged_en         (cfg_dll_state_chged_en)
    ,.cfg_cmd_cpled_int_en           (cfg_cmd_cpled_int_en)
    ,.cfg_pre_det_chged_en           (cfg_pre_det_chged_en)
    ,.cfg_mrl_sensor_chged_en        (cfg_mrl_sensor_chged_en)
    ,.cfg_pwr_fault_det_en           (cfg_pwr_fault_det_en)
    ,.cfg_atten_button_pressed_en    (cfg_atten_button_pressed_en)
    ,.cfg_hp_int_en                  (cfg_hp_int_en)
    ,.cfg_acs_validation_en          (cfg_acs_validation_en        )
    ,.cfg_acs_at_blocking_en         (cfg_acs_at_blocking_en       )
    ,.cfg_acs_p2p_req_redirect_en    (cfg_acs_p2p_req_redirect_en  )
    ,.cfg_acs_p2p_compl_redirect_en  (cfg_acs_p2p_compl_redirect_en)
    ,.cfg_acs_up_forward_en          (cfg_acs_up_forward_en        )
    ,.cfg_acs_p2p_egress_ctrl_en     (cfg_acs_p2p_egress_ctrl_en   )
    ,.cfg_acs_p2p_direct_transl_en   (cfg_acs_p2p_direct_transl_en )
    ,.cfg_acs_egress_ctrl_vec        (cfg_acs_egress_ctrl_vec      )
    ,.cfg_aspm_l1_timer_enable       (cfg_aspm_l1_timer_enable)
    ,.cfg_upd_aslk_pmctrl            (cfg_upd_aslk_pmctrl)
    ,.cfg_upd_pme_cap                (cfg_upd_pme_cap)
    ,.rstctl_ltssm_enable            (rstctl_ltssm_enable)
    ,.rstctl_core_flush_req          (rstctl_core_flush_req)
    ,.upstream_port                  (pre_upstream_port)
    ,.xdlh_xmt_pme_ack               (xdlh_xmt_pme_ack)
    ,.xdlh_not_expecting_ack         (xdlh_not_expecting_ack)
    ,.smlh_in_l0                     (smlh_in_l0)
    ,.smlh_in_l1                     (smlh_in_l1)
    ,.smlh_in_l23                    (smlh_in_l23)
    ,.smlh_link_in_training          (smlh_link_in_training)
    ,.smlh_ltssm_state_int           (smlh_ltssm_state_int)
    ,.cfg_aslk_pmctrl                (cfg_aslk_pmctrl)
    ,.cfg_upd_pmcsr                  (cfg_upd_pmcsr)
    ,.cfg_upd_aux_pm_en              (cfg_upd_aux_pm_en)
    ,.cfg_pmstatus_clr               (cfg_pmstatus_clr)
    ,.cfg_pmstate                    (cfg_pmstate)
    ,.cfg_pme_en                     (cfg_pme_en)
    ,.cfg_aux_pm_en                  (cfg_aux_pm_en)
    ,.cfg_clk_pm_en                  (cfg_clk_pm_en)
    ,.int_radm_pm_to_ack             (int_radm_pm_to_ack)
    ,.cfg_pme_cap                    (cfg_pme_cap)
    ,.rmlh_descrambled_even_parity   (rmlh_descrambled_even_parity)
    ,.xmlh_scramble_even_parity      (xmlh_scramble_even_parity)
    ,.pipe_aux_sync_p1_ack           (pipe_aux_sync_p1_ack)
    ,.pipe_aux_sync_block            (pipe_aux_sync_block)
    ,.cfg_l1sub_control              (cfg_l1sub_control)
    ,.cfg_pl_l1sub_control           (cfg_pl_l1sub_control)
    ,.cfg_pl_l1_exit_mode            (cfg_pl_l1_exit_mode)
    ,.cfg_pl_l1_clk_sel              (cfg_pl_l1_clk_sel)
    ,.cfg_p2nobeacon_enable          (cfg_p2nobeacon_enable)
    ,.cfg_utility                    (cfg_utility)
    ,.pm_cfg_utility                 (pm_cfg_utility)
    ,.cfg_pipe_optional_pclkchange_hs(cfg_pipe_optional_pclkchange_hs)
    ,.cfg_phy_perst_on_warm_reset    (cfg_phy_perst_on_warm_reset)
    ,.cfg_phy_rst_timer              (cfg_phy_rst_timer)
    ,.cfg_pma_phy_rst_delay_timer    (cfg_pma_phy_rst_delay_timer)
    ,.cfg_pl_aux_clk_freq            (cfg_pl_aux_clk_freq)
    ,.cfg_pl_gen3_zrxdc_noncompl     (cfg_pl_gen3_zrxdc_noncompl)
    ,.pme_to_ack_grt                 (pme_to_ack_grt)
    ,.lbc_active                     (lbc_active)
    ,.pm_pme_grant                   (pm_pme_grant)
    ,.pme_turn_off_grt               (pme_turn_off_grt)
    ,.xmlh_sris_enable               (xmlh_sris_enable)
    ,.pre_serdes_pipe_turnoff_lanes  (pre_serdes_pipe_turnoff_lanes)
    ,.pre_mac_phy_powerdown          (pre_mac_phy_powerdown)
    ,.int_mac_phy_txelecidle         (int_mac_phy_txelecidle)
    ,.pre_mac_phy_txdata             (pre_mac_phy_txdata)
    ,.pre_mac_phy_txdetectrx_loopback  (pre_mac_phy_txdetectrx_loopback)
    ,.glue_mac_phy_txcompliance      (glue_mac_phy_txcompliance)
    ,.pre_mac_phy_rxpolarity         (pre_mac_phy_rxpolarity)
    ,.tmp_mac_phy_rxpolarity         (tmp_mac_phy_rxpolarity)
    ,.pre_mac_phy_width              (pre_mac_phy_width)
    ,.pre_mac_phy_serdes_arch        (pre_mac_phy_serdes_arch)
    ,.pre_mac_phy_rxwidth            (pre_mac_phy_rxwidth)
    ,.pre_serdes_pipe_rxready        (pre_serdes_pipe_rxready)
    ,.pre_mac_phy_pclk_rate          (pre_mac_phy_pclk_rate)
    ,.pre_mac_phy_rxstandby          (pre_mac_phy_rxstandby)
    ,.pre_mac_phy_rate               (pre_mac_phy_rate)
    ,.pre_mac_phy_txdeemph           (pre_mac_phy_txdeemph)
    ,.pre_mac_phy_txdatavalid        (pre_mac_phy_txdatavalid)
    ,.pre_mac_phy_rxeqeval           (pre_mac_phy_rxeqeval)
    ,.pre_mac_phy_dirchange          (pre_mac_phy_dirchange)
    ,.pre_mac_phy_smlh_coef_rtx      (pre_mac_phy_smlh_coef_rtx)
    ,.pre_mac_phy_mbus               (pre_mac_phy_mbus)
    ,.sqlchd_rxelecidle              (sqlchd_rxelecidle)
    ,.int_cfg_pbus_num               (int_cfg_pbus_num)
    ,.int_cfg_pbus_dev_num           (int_cfg_pbus_dev_num)
    ,.smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl)
    ,.cfg_link_retrain               (cfg_link_retrain)
    ,.cfg_lpbk_en                    (cfg_lpbk_en)
    ,.cfg_plreg_reset                (cfg_plreg_reset)
    ,.cfg_directed_speed_change      (cfg_directed_speed_change)
    ,.cfg_pl_multilane_control       (cfg_pl_multilane_control)
    ,.msg_gen_unlock_grant           (msg_gen_unlock_grant)
    ,.edma_xfer_pending              (edma_xfer_pending)
    ,.pm_ltssm_enable                (pm_ltssm_enable)
    ,.int_pm_current_data_rate       (int_pm_current_data_rate)
    ,.pm_rmlh_descrambled_even_parity (pm_rmlh_descrambled_even_parity)
    ,.pm_xmlh_scramble_even_parity   (pm_xmlh_scramble_even_parity)
    ,.pm_smlh_l23_exit               (pm_smlh_l23_exit)
    ,.pm_xmt_turnoff                 (pm_xmt_turnoff)
    ,.pm_xmt_to_ack                  (pm_xmt_to_ack)
    ,.pm_xmt_pme                     (pm_xmt_pme)
    ,.pm_turnoff_timeout             (pm_turnoff_timeout)
    ,.pm_bus_num                     (pm_bus_num)
    ,.pm_dev_num                     (pm_dev_num)
    ,.pm_int_phy_powerdown           (pm_int_phy_powerdown)
    ,.pm_current_powerdown_p1        (pm_current_powerdown_p1)
    ,.pm_current_powerdown_p0        (pm_current_powerdown_p0)
    ,.pm_smlh_l1_2_latched           (pm_smlh_l1_2_latched)
    ,.pm_smlh_l1_n_latched           (pm_smlh_l1_n_latched)
    ,.pm_l1sub_state                 (pm_l1sub_state)
    ,.pm_in_l11                      (pm_in_l11)
    ,.pm_in_l12                      (pm_in_l12)
    ,.pm_in_l1_short                 (pm_in_l1_short)
    ,.pm_in_l1_cpm                   (pm_in_l1_cpm)
    ,.pm_in_l1_abort                 (pm_in_l1_abort)
    ,.pm_pme_resend_flag             (pm_pme_resend_flag)
    ,.pm_block_phystatus             (pm_block_phystatus)
    ,.pm_en_pulse_det                (pm_en_pulse_det)
    ,.pm_sys_aux_pwr_det             (pm_sys_aux_pwr_det)
    ,.pm_pme_en_split                (pm_pme_en_split)
    ,.pm_aux_pm_en_split             (pm_aux_pm_en_split)
    ,.pm_init_rst                    (pm_init_rst)
    ,.pm_unlock_msg_req              (pm_unlock_msg_req)
    ,.pm_rx_lane_flip_en             (pm_rx_lane_flip_en)
    ,.pm_tx_lane_flip_en             (pm_tx_lane_flip_en)
    ,.pm_rx_pol_lane_flip_ctrl       (pm_rx_pol_lane_flip_ctrl)
    ,.pm_smlh_link_retrain           (pm_smlh_link_retrain)
    ,.trgt_cpl_lut_empty             (trgt_cpl_lut_empty)
    ,.core_in_dpc                        (core_in_dpc_i)
    ,.cfg_dpc_int_msg_num                (cfg_dpc_int_msg_num)
    ,.cfg_dpc_trig_en                    (cfg_dpc_trig_en)
    ,.cfg_dpc_cpl_cntrl                  (cfg_dpc_cpl_cntrl_i)
    ,.cfg_dpc_int_en                     (cfg_dpc_int_en)
    ,.dpc_int                            (dpc_int)
    ,.dpc_msi                            (dpc_msi)
    ,.cfg_dpc_err_cor_en                 (cfg_dpc_err_cor_en)
    ,.cfg_dpc_poison_tlp_egr_block_en    (cfg_dpc_poison_tlp_egr_block_en)
    ,.cfg_dpc_sw_trigger                 (cfg_dpc_sw_trigger)
    ,.cfg_dpc_dl_active_err_cor_en       (cfg_dpc_dl_active_err_cor_en)
    ,.app_dev_num                    (app_dev_num)
    ,.app_bus_num                    (app_bus_num)
    ,.msg_gen_hv                     (msg_gen_hv)
    ,.lbc_cpl_hv                     (lbc_cpl_hv)
    ,.latched_rxdetected           (latched_rxdetected)
    ,.pm_latched_rxdetected        (pm_latched_rxdetected)
    ,.pm_powerdown_status          (pm_powerdown_status)
    ,.cfg_force_powerdown          (cfg_force_powerdown)
    ,.cfg_uncor_internal_err_sts         (cfg_uncor_internal_err_sts        )
    ,.cfg_rcvr_overflow_err_sts          (cfg_rcvr_overflow_err_sts         )
    ,.cfg_fc_protocol_err_sts            (cfg_fc_protocol_err_sts           )
    ,.cfg_mlf_tlp_err_sts                (cfg_mlf_tlp_err_sts               )
    ,.cfg_surprise_down_er_sts           (cfg_surprise_down_er_sts          )
    ,.cfg_dl_protocol_err_sts            (cfg_dl_protocol_err_sts           )
    ,.cfg_ecrc_err_sts                   (cfg_ecrc_err_sts                  )
    ,.cfg_corrected_internal_err_sts     (cfg_corrected_internal_err_sts    )
    ,.cfg_replay_number_rollover_err_sts (cfg_replay_number_rollover_err_sts)
    ,.cfg_replay_timer_timeout_err_sts   (cfg_replay_timer_timeout_err_sts  )
    ,.cfg_bad_dllp_err_sts               (cfg_bad_dllp_err_sts              )
    ,.cfg_bad_tlp_err_sts                (cfg_bad_tlp_err_sts               )
    ,.cfg_rcvr_err_sts                   (cfg_rcvr_err_sts                  )
    ,.cfg_link_capable                   (cfg_link_capable                  )
    ,.cfg_advisory_nf_sts                (cfg_advisory_nf_sts               )
    ,.cfg_hdr_log_overflow_sts           (cfg_hdr_log_overflow_sts          )
    ,.rplh_flit_unrecognized_flit        (rplh_flit_unrecognized_flit      )
    ,.rplh_flit_ecc_corr_err             (rplh_flit_ecc_corr_err           )
    ,.rplh_flit_ecc_uncorr_err           (rplh_flit_ecc_uncorr_err         )
    ,.rplh_flit_crc_uncorr_err           (rplh_flit_crc_uncorr_err         )

  ,.cfg_pcie_cap_flit_mode_stat           (cfg_pcie_cap_flit_mode_stat)

    ,.cfg_neg_link_width            (cfg_neg_link_width       )
    ,.l0p_dynamic_rejected          (l0p_dynamic_rejected     )
    ,.cfg_l0p_dynamic_en            (cfg_l0p_dynamic_en       )
    ,.radm_slot_pwr_payload         (radm_slot_pwr_payload)
    ,.radm_slot_pwr_limit           (radm_slot_pwr_limit)

    ,.cxl_ltssm_enable  (cxl_ltssm_enable)
    ,.smlh_cxl_enabled  (smlh_cxl_enabled)
    ,.vlsm_mc_state  (vlsm_mc_state)
    ,.vlsm_io_state  (vlsm_io_state)
    ,.cxl_s2m_data_pis  (cxl_s2m_data_pis)
    ,.cxl_m2s_data_pis  (cxl_m2s_data_pis)
    ,.cxl_h2d_data_pis  (cxl_h2d_data_pis)
    ,.cxl_d2h_data_pis  (cxl_d2h_data_pis)
    ,.vlsm_io_tx_pm_nak ( vlsm_io_tx_pm_nak)
    ,.vlsm_mc_tx_pm_nak  ( vlsm_mc_tx_pm_nak)
    ,.vlsm_io_rx_pm_nak  ( vlsm_io_rx_pm_nak)
    ,.vlsm_mc_rx_pm_nak  ( vlsm_mc_rx_pm_nak)
    ,.vlsm_io_rx_pm_req  ( vlsm_io_rx_pm_req)
    ,.vlsm_mc_rx_pm_req  ( vlsm_mc_rx_pm_req)
    ,.vlsm_io_pm_timeout  ( vlsm_io_pm_timeout)
    ,.vlsm_mc_pm_timeout  ( vlsm_mc_pm_timeout)
    ,.cxl_viral_request  (cxl_viral_request)
    ,.cxl_viral_status  (cxl_viral_status)
    ,.cxl_viral_enable  (cxl_viral_enable)
    // trgt1 p interfaces

    ,.radm_trgt1_p_0_data  (radm_trgt1_p_0_data)
    ,.radm_trgt1_p_0_pending  (radm_trgt1_p_0_pending)
    ,.radm_trgt1_p_0_hdr_prot  (radm_trgt1_p_0_hdr_prot)
    ,.radm_trgt1_p_0_prfx  (radm_trgt1_p_0_prfx)
    ,.radm_trgt1_p_0_dwen  (radm_trgt1_p_0_dwen)
    ,.radm_trgt1_p_0_dv  (radm_trgt1_p_0_dv)
    ,.radm_trgt1_p_0_hv  (radm_trgt1_p_0_hv)
    ,.radm_trgt1_p_0_eot  (radm_trgt1_p_0_eot)
    ,.radm_trgt1_p_0_tlp_abort  (radm_trgt1_p_0_tlp_abort)
    ,.radm_trgt1_p_0_dllp_abort  (radm_trgt1_p_0_dllp_abort)
    ,.radm_trgt1_p_0_ecrc_err  (radm_trgt1_p_0_ecrc_err)
    ,.radm_trgt1_p_0_fmt  (radm_trgt1_p_0_fmt)
    ,.radm_trgt1_p_0_type  (radm_trgt1_p_0_type)
    ,.radm_trgt1_p_0_tc  (radm_trgt1_p_0_tc)
    ,.radm_trgt1_p_0_attr  (radm_trgt1_p_0_attr)
    ,.radm_trgt1_p_0_reqid  (radm_trgt1_p_0_reqid)
    ,.radm_trgt1_p_0_tag  (radm_trgt1_p_0_tag)
    ,.radm_trgt1_p_0_func_num  (radm_trgt1_p_0_func_num)
    ,.radm_trgt1_p_0_cpl_status  (radm_trgt1_p_0_cpl_status)
    ,.radm_trgt1_p_0_td  (radm_trgt1_p_0_td)
    ,.radm_trgt1_p_0_poisoned  (radm_trgt1_p_0_poisoned)
    ,.radm_trgt1_p_0_dw_len  (radm_trgt1_p_0_dw_len)
    ,.radm_trgt1_p_0_first_be  (radm_trgt1_p_0_first_be)
    ,.radm_trgt1_p_0_vc_num  (radm_trgt1_p_0_vc_num)
    ,.radm_trgt1_p_0_addr  (radm_trgt1_p_0_addr)
    ,.radm_trgt1_p_0_hdr_uppr_bytes  (radm_trgt1_p_0_hdr_uppr_bytes)
    ,.radm_trgt1_p_0_rom_in_range  (radm_trgt1_p_0_rom_in_range)
    ,.radm_trgt1_p_0_io_req_in_range  (radm_trgt1_p_0_io_req_in_range)
    ,.radm_trgt1_p_0_in_membar_range  (radm_trgt1_p_0_in_membar_range)
    ,.radm_trgt1_p_0_last_be  (radm_trgt1_p_0_last_be)
    ,.radm_trgt1_p_0_ats  (radm_trgt1_p_0_ats)
    ,.radm_trgt1_p_0_nw  (radm_trgt1_p_0_nw)
    ,.radm_trgt1_p_0_th  (radm_trgt1_p_0_th)
    ,.radm_trgt1_p_0_ph  (radm_trgt1_p_0_ph)
    ,.radm_trgt1_p_0_st  (radm_trgt1_p_0_st)
    ,.radm_trgt1_p_0_hdr_uppr_bytes_valid  (radm_trgt1_p_0_hdr_uppr_bytes_valid)
    ,.radm_trgt1_p_0_dest_sgmt  (radm_trgt1_p_0_dest_sgmt)
    ,.radm_trgt1_p_0_reqtr_sgmt  (radm_trgt1_p_0_reqtr_sgmt)
    ,.radm_trgt1_p_0_pkt_order_no  (radm_trgt1_p_0_pkt_order_no)
    ,.radm_trgt1_p_0_atu_sloc_match  (radm_trgt1_p_0_atu_sloc_match)
    ,.radm_trgt1_p_0_atu_cbuf_err  (radm_trgt1_p_0_atu_cbuf_err)
    // trgt1 np interfaces
    ,.radm_trgt1_np_0_data  (radm_trgt1_np_0_data)
    ,.radm_trgt1_np_0_hdr_prot  (radm_trgt1_np_0_hdr_prot)
    ,.radm_trgt1_np_0_prfx  (radm_trgt1_np_0_prfx)
    ,.radm_trgt1_np_0_dwen  (radm_trgt1_np_0_dwen)
    ,.radm_trgt1_np_0_dv  (radm_trgt1_np_0_dv)
    ,.radm_trgt1_np_0_hv  (radm_trgt1_np_0_hv)
    ,.radm_trgt1_np_0_eot  (radm_trgt1_np_0_eot)
    ,.radm_trgt1_np_0_dllp_abort  (radm_trgt1_np_0_dllp_abort)
    ,.radm_trgt1_np_0_tlp_abort  (radm_trgt1_np_0_tlp_abort)
    ,.radm_trgt1_np_0_ecrc_err  (radm_trgt1_np_0_ecrc_err)
    ,.radm_trgt1_np_0_fmt  (radm_trgt1_np_0_fmt)
    ,.radm_trgt1_np_0_type  (radm_trgt1_np_0_type)
    ,.radm_trgt1_np_0_tc  (radm_trgt1_np_0_tc)
    ,.radm_trgt1_np_0_attr  (radm_trgt1_np_0_attr)
    ,.radm_trgt1_np_0_reqid  (radm_trgt1_np_0_reqid)
    ,.radm_trgt1_np_0_tag  (radm_trgt1_np_0_tag)
    ,.radm_trgt1_np_0_func_num  (radm_trgt1_np_0_func_num)
    ,.radm_trgt1_np_0_cpl_status  (radm_trgt1_np_0_cpl_status)
    ,.radm_trgt1_np_0_td  (radm_trgt1_np_0_td)
    ,.radm_trgt1_np_0_poisoned  (radm_trgt1_np_0_poisoned)
    ,.radm_trgt1_np_0_dw_len  (radm_trgt1_np_0_dw_len)
    ,.radm_trgt1_np_0_first_be  (radm_trgt1_np_0_first_be)
    ,.radm_trgt1_np_0_vc_num  (radm_trgt1_np_0_vc_num)
    ,.radm_trgt1_np_0_addr  (radm_trgt1_np_0_addr)
    ,.radm_trgt1_np_0_hdr_uppr_bytes  (radm_trgt1_np_0_hdr_uppr_bytes)
    ,.radm_trgt1_np_0_rom_in_range  (radm_trgt1_np_0_rom_in_range)
    ,.radm_trgt1_np_0_io_req_in_range  (radm_trgt1_np_0_io_req_in_range)
    ,.radm_trgt1_np_0_in_membar_range  (radm_trgt1_np_0_in_membar_range)
    ,.radm_trgt1_np_0_last_be  (radm_trgt1_np_0_last_be)
    ,.radm_trgt1_np_0_ats  (radm_trgt1_np_0_ats)
    ,.radm_trgt1_np_0_nw  (radm_trgt1_np_0_nw)
    ,.radm_trgt1_np_0_cxlsrc  (radm_trgt1_np_0_cxlsrc)
    ,.radm_trgt1_np_0_th  (radm_trgt1_np_0_th)
    ,.radm_trgt1_np_0_ph  (radm_trgt1_np_0_ph)
    ,.radm_trgt1_np_0_st  (radm_trgt1_np_0_st)
    ,.radm_trgt1_np_0_hdr_uppr_bytes_valid  (radm_trgt1_np_0_hdr_uppr_bytes_valid)
    ,.radm_trgt1_np_0_reqtr_sgmt  (radm_trgt1_np_0_reqtr_sgmt)
    ,.radm_trgt1_np_0_dest_sgmt  (radm_trgt1_np_0_dest_sgmt)
    ,.radm_trgt1_np_0_pkt_order_no  (radm_trgt1_np_0_pkt_order_no)
    ,.radm_trgt1_np_0_atu_sloc_match  (radm_trgt1_np_0_atu_sloc_match)
    ,.radm_trgt1_np_0_atu_cbuf_err  (radm_trgt1_np_0_atu_cbuf_err)
    // trgt1 CPL interface
    ,.radm_trgt1_cpl_0_data  (radm_trgt1_cpl_0_data)
    ,.radm_trgt1_cpl_0_hdr_prot  (radm_trgt1_cpl_0_hdr_prot)
    ,.radm_trgt1_cpl_0_prfx  (radm_trgt1_cpl_0_prfx)
    ,.radm_trgt1_cpl_0_dwen  (radm_trgt1_cpl_0_dwen)
    ,.radm_trgt1_cpl_0_dv  (radm_trgt1_cpl_0_dv)
    ,.radm_trgt1_cpl_0_hv  (radm_trgt1_cpl_0_hv)
    ,.radm_trgt1_cpl_0_eot  (radm_trgt1_cpl_0_eot)
    ,.radm_trgt1_cpl_0_dllp_abort  (radm_trgt1_cpl_0_dllp_abort)
    ,.radm_trgt1_cpl_0_tlp_abort  (radm_trgt1_cpl_0_tlp_abort)
    ,.radm_trgt1_cpl_0_ecrc_err  (radm_trgt1_cpl_0_ecrc_err)
    ,.radm_trgt1_cpl_0_fmt  (radm_trgt1_cpl_0_fmt)
    ,.radm_trgt1_cpl_0_type  (radm_trgt1_cpl_0_type)
    ,.radm_trgt1_cpl_0_tc  (radm_trgt1_cpl_0_tc)
    ,.radm_trgt1_cpl_0_attr  (radm_trgt1_cpl_0_attr)
    ,.radm_trgt1_cpl_0_reqid  (radm_trgt1_cpl_0_reqid)
    ,.radm_trgt1_cpl_0_tag  (radm_trgt1_cpl_0_tag)
    ,.radm_trgt1_cpl_0_func_num  (radm_trgt1_cpl_0_func_num)
    ,.radm_trgt1_cpl_0_status  (radm_trgt1_cpl_0_status)
    ,.radm_trgt1_cpl_0_td  (radm_trgt1_cpl_0_td)
    ,.radm_trgt1_cpl_0_poisoned  (radm_trgt1_cpl_0_poisoned)
    ,.radm_trgt1_cpl_0_dw_len  (radm_trgt1_cpl_0_dw_len)
    ,.radm_trgt1_cpl_0_bcm  (radm_trgt1_cpl_0_bcm)
    ,.radm_trgt1_cpl_0_byte_cnt  (radm_trgt1_cpl_0_byte_cnt)
    ,.radm_trgt1_cpl_0_cmpltr_id  (radm_trgt1_cpl_0_cmpltr_id)
    ,.radm_trgt1_cpl_0_last  (radm_trgt1_cpl_0_last)
    ,.radm_trgt1_cpl_0_vc_num  (radm_trgt1_cpl_0_vc_num)
    ,.radm_trgt1_cpl_0_addr  (radm_trgt1_cpl_0_addr)
    ,.radm_trgt1_cpl_0_dest_sgmt  (radm_trgt1_cpl_0_dest_sgmt)
    ,.radm_trgt1_cpl_0_cpl_sgmt  (radm_trgt1_cpl_0_cpl_sgmt)
    ,.radm_trgt1_cpl_0_p_pkt_order_no  (radm_trgt1_cpl_0_p_pkt_order_no)

    ,.trgt1_radm_intf_p_0_halt                      (trgt1_radm_intf_p_0_halt  )
    ,.trgt1_radm_intf_np_0_halt                     (trgt1_radm_intf_np_0_halt )
    ,.trgt1_radm_intf_cpl_0_halt                    (trgt1_radm_intf_cpl_0_halt )
    // -------------------------------------------------------------------------------------
    // CXL Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_clk  (cxl_clk)
    ,.cxl_rst_n  (cxl_rst_n)
// spyglass disable_block Topology_02
// SMD: Direct connection from input port to output port
// SJ: RAM-based FIFO is implemented to buffer data on Data Message Channels which propagates data to RAM data inputs
    // -------------------------------------------------------------------------------------
    // CXL Protocol Master RX Cache Link initialization Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_cache_mst_req  (cxl_cache_mst_req)
    ,.cxl_cache_mst_ack  (cxl_cache_mst_ack)
    // -------------------------------------------------------------------------------------
    // CXL Protocol Slave TX Cache Link initialization Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_cache_slv_req  (cxl_cache_slv_req)
    ,.cxl_cache_slv_ack  (cxl_cache_slv_ack)
    ,.cxl_cache_app_pending (cxl_cache_app_pending)
    // -------------------------------------------------------------------------------------
    // CXL.Cache Host Master (Root Complex RX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_mst_h2d_req_crd  (cxl_mst_h2d_req_crd)
    ,.cxl_mst_h2d_rsp_crd  (cxl_mst_h2d_rsp_crd)
    ,.cxl_mst_h2d_data_crd  (cxl_mst_h2d_data_crd)
    ,.cxl_mst_h2d_req  (cxl_mst_h2d_req)
    ,.cxl_mst_h2d_rsp  (cxl_mst_h2d_rsp)
    ,.cxl_mst_h2d_data  (cxl_mst_h2d_data)
    ,.cxl_mst_h2d_req_chk  (cxl_mst_h2d_req_chk)
    ,.cxl_mst_h2d_rsp_chk  (cxl_mst_h2d_rsp_chk)
    ,.cxl_mst_h2d_data_chk  (cxl_mst_h2d_data_chk)
    // -------------------------------------------------------------------------------------
    // CXL.Cache Device Slave (Endpoint TX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_slv_d2h_req_crd  (cxl_slv_d2h_req_crd)
    ,.cxl_slv_d2h_rsp_crd  (cxl_slv_d2h_rsp_crd)
    ,.cxl_slv_d2h_data_crd  (cxl_slv_d2h_data_crd)
    ,.cxl_slv_d2h_req  (cxl_slv_d2h_req)
    ,.cxl_slv_d2h_rsp  (cxl_slv_d2h_rsp)
    ,.cxl_slv_d2h_data  (cxl_slv_d2h_data)
    ,.cxl_slv_d2h_req_chk  (cxl_slv_d2h_req_chk)
    ,.cxl_slv_d2h_rsp_chk  (cxl_slv_d2h_rsp_chk)
    ,.cxl_slv_d2h_data_chk  (cxl_slv_d2h_data_chk)
    // -------------------------------------------------------------------------------------
    // CXL.Cache Host Slave (Root Complex TX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_slv_h2d_req_crd  (cxl_slv_h2d_req_crd)
    ,.cxl_slv_h2d_rsp_crd  (cxl_slv_h2d_rsp_crd)
    ,.cxl_slv_h2d_data_crd  (cxl_slv_h2d_data_crd)
    ,.cxl_slv_h2d_req  (cxl_slv_h2d_req)
    ,.cxl_slv_h2d_rsp  (cxl_slv_h2d_rsp)
    ,.cxl_slv_h2d_data  (cxl_slv_h2d_data)
    ,.cxl_slv_h2d_req_chk  (cxl_slv_h2d_req_chk)
    ,.cxl_slv_h2d_rsp_chk  (cxl_slv_h2d_rsp_chk)
    ,.cxl_slv_h2d_data_chk  (cxl_slv_h2d_data_chk)
    // -------------------------------------------------------------------------------------
    // CXL.Cache Device Master (Endpoint RX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_mst_d2h_req_crd  (cxl_mst_d2h_req_crd)
    ,.cxl_mst_d2h_rsp_crd  (cxl_mst_d2h_rsp_crd)
    ,.cxl_mst_d2h_data_crd  (cxl_mst_d2h_data_crd)
    ,.cxl_mst_d2h_req  (cxl_mst_d2h_req)
    ,.cxl_mst_d2h_rsp  (cxl_mst_d2h_rsp)
    ,.cxl_mst_d2h_data  (cxl_mst_d2h_data)
    ,.cxl_mst_d2h_req_chk  (cxl_mst_d2h_req_chk)
    ,.cxl_mst_d2h_rsp_chk  (cxl_mst_d2h_rsp_chk)
    ,.cxl_mst_d2h_data_chk  (cxl_mst_d2h_data_chk)
    // -------------------------------------------------------------------------------------
    // CXL Protocol Master RX Mem Link initialization Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_mem_mst_req  (cxl_mem_mst_req)
    ,.cxl_mem_mst_ack  (cxl_mem_mst_ack)
    // -------------------------------------------------------------------------------------
    // CXL Protocol Slave TX Mem Link initialization Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_mem_slv_req  (cxl_mem_slv_req)
    ,.cxl_mem_slv_ack  (cxl_mem_slv_ack)
    ,.cxl_mem_app_pending  (cxl_mem_app_pending)
    // -------------------------------------------------------------------------------------
    // CXL.Mem Host Master (Root Complex RX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_mst_m2s_req_crd  (cxl_mst_m2s_req_crd)
    ,.cxl_mst_m2s_rwd_crd  (cxl_mst_m2s_rwd_crd)
    ,.cxl_mst_m2s_req  (cxl_mst_m2s_req)
    ,.cxl_mst_m2s_rwd  (cxl_mst_m2s_rwd)
    ,.cxl_mst_m2s_req_chk  (cxl_mst_m2s_req_chk)
    ,.cxl_mst_m2s_rwd_chk  (cxl_mst_m2s_rwd_chk)
    // -------------------------------------------------------------------------------------
    // CXL.Mem Device Slave (Endpoint TX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_slv_s2m_ndr_crd  (cxl_slv_s2m_ndr_crd)
    ,.cxl_slv_s2m_drc_crd  (cxl_slv_s2m_drc_crd)
    ,.cxl_slv_s2m_ndr  (cxl_slv_s2m_ndr)
    ,.cxl_slv_s2m_drc  (cxl_slv_s2m_drc)
    ,.cxl_slv_s2m_ndr_chk  (cxl_slv_s2m_ndr_chk)
    ,.cxl_slv_s2m_drc_chk  (cxl_slv_s2m_drc_chk)
    // -------------------------------------------------------------------------------------
    // CXL.Mem Host Slave (Root Complex TX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_slv_m2s_req_crd  (cxl_slv_m2s_req_crd)
    ,.cxl_slv_m2s_rwd_crd  (cxl_slv_m2s_rwd_crd)
    ,.cxl_slv_m2s_req  (cxl_slv_m2s_req)
    ,.cxl_slv_m2s_rwd  (cxl_slv_m2s_rwd)
    ,.cxl_slv_m2s_req_chk  (cxl_slv_m2s_req_chk)
    ,.cxl_slv_m2s_rwd_chk  (cxl_slv_m2s_rwd_chk)
    // -------------------------------------------------------------------------------------
    // CXL.Mem Device Master (Endpoint RX) Message Channel Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_mst_s2m_ndr_crd  (cxl_mst_s2m_ndr_crd)
    ,.cxl_mst_s2m_drc_crd  (cxl_mst_s2m_drc_crd)
    ,.cxl_mst_s2m_ndr  (cxl_mst_s2m_ndr)
    ,.cxl_mst_s2m_drc  (cxl_mst_s2m_drc)
    ,.cxl_mst_s2m_ndr_chk  (cxl_mst_s2m_ndr_chk)
    ,.cxl_mst_s2m_drc_chk  (cxl_mst_s2m_drc_chk)
// spyglass enable_block Topology_02
    ,.cxl_mst_m2s_bi_rsp  (cxl_mst_m2s_bi_rsp)
    ,.cxl_mst_m2s_bi_rsp_crd  (cxl_mst_m2s_bi_rsp_crd)
    ,.cxl_mst_m2s_bi_rsp_chk  (cxl_mst_m2s_bi_rsp_chk)
    ,.cxl_slv_s2m_bi_snp  (cxl_slv_s2m_bi_snp)
    ,.cxl_slv_s2m_bi_snp_crd  (cxl_slv_s2m_bi_snp_crd)
    ,.cxl_slv_s2m_bi_snp_chk  (cxl_slv_s2m_bi_snp_chk)
    ,.cxl_slv_m2s_bi_rsp  (cxl_slv_m2s_bi_rsp)
    ,.cxl_slv_m2s_bi_rsp_crd  (cxl_slv_m2s_bi_rsp_crd)
    ,.cxl_slv_m2s_bi_rsp_chk  (cxl_slv_m2s_bi_rsp_chk)
    ,.cxl_mst_s2m_bi_snp  (cxl_mst_s2m_bi_snp)
    ,.cxl_mst_s2m_bi_snp_crd  (cxl_mst_s2m_bi_snp_crd)
    ,.cxl_mst_s2m_bi_snp_chk  (cxl_mst_s2m_bi_snp_chk)
    // -------------------------------------------------------------------------------------
    // CXL Controller RAS Statistics Interface Signals
    // -------------------------------------------------------------------------------------
    ,.cxl_ras_stat_rx_corr  (cxl_ras_stat_rx_corr)
    ,.cxl_ras_stat_rx_uncorr  (cxl_ras_stat_rx_uncorr)
    ,.cxl_ras_stat_rx_hdr_log  (cxl_ras_stat_rx_hdr_log)
    // -------------------------------------------------------------------------------------
    // Control Signals from the CXL Flex Bus Device DVSEC
    // -------------------------------------------------------------------------------------
    ,.cfg_cxl_dev_mem_enable  (cfg_cxl_dev_mem_enable)
    ,.cfg_cxl_dev_range1_mem_size_high  (cfg_cxl_dev_range1_mem_size_high)
    ,.cfg_cxl_dev_range1_mem_info_valid  (cfg_cxl_dev_range1_mem_info_valid)
    ,.cfg_cxl_dev_range1_mem_active  (cfg_cxl_dev_range1_mem_active)
    ,.cfg_cxl_dev_range1_desired_interleave  (cfg_cxl_dev_range1_desired_interleave)
    ,.cfg_cxl_dev_range1_mem_size_low  (cfg_cxl_dev_range1_mem_size_low)
    ,.cfg_cxl_dev_range1_mem_base_high  (cfg_cxl_dev_range1_mem_base_high)
    ,.cfg_cxl_dev_range1_mem_base_low  (cfg_cxl_dev_range1_mem_base_low)
    ,.cfg_cxl_dev_range2_mem_size_high  (cfg_cxl_dev_range2_mem_size_high)
    ,.cfg_cxl_dev_range2_mem_info_valid  (cfg_cxl_dev_range2_mem_info_valid)
    ,.cfg_cxl_dev_range2_mem_active  (cfg_cxl_dev_range2_mem_active)
    ,.cfg_cxl_dev_range2_desired_interleave  (cfg_cxl_dev_range2_desired_interleave)
    ,.cfg_cxl_dev_range2_mem_size_low  (cfg_cxl_dev_range2_mem_size_low)
    ,.cfg_cxl_dev_range2_mem_base_high  (cfg_cxl_dev_range2_mem_base_high)
    ,.cfg_cxl_dev_range2_mem_base_low  (cfg_cxl_dev_range2_mem_base_low)
    ,.cfg_cxl_dev_cache_enable  (cfg_cxl_dev_cache_enable)
    ,.cfg_cxl_dev_cache_sf_coverage  (cfg_cxl_dev_cache_sf_coverage)
    ,.cfg_cxl_dev_cache_sf_granularity  (cfg_cxl_dev_cache_sf_granularity)
    ,.cfg_cxl_dev_cache_clean_eviction  (cfg_cxl_dev_cache_clean_eviction)
    // -------------------------------------------------------------------------------------
    // CXL 2.0 Device DVSEC control signals
    // -------------------------------------------------------------------------------------
    ,.cfg_cxl_dev_disable_caching  (cfg_cxl_dev_disable_caching)
    ,.cfg_cxl_dev_initiate_cache_wr_invld  (cfg_cxl_dev_initiate_cache_wr_invld)
    ,.cxl_dev_cache_invalid  (cxl_dev_cache_invalid)
    ,.cxl_dev_cache_wr_invld_cmpl  (cxl_dev_cache_wr_invld_cmpl)
    ,.cfg_cxl_dev_post_cold_rst_volatile_hdm_default  (cfg_cxl_dev_post_cold_rst_volatile_hdm_default)
    ,.cfg_cxl_dev_post_warm_rst_volatile_hdm_default  (cfg_cxl_dev_post_warm_rst_volatile_hdm_default)
    ,.cfg_cxl_dev_post_hot_rst_volatile_hdm_default  (cfg_cxl_dev_post_hot_rst_volatile_hdm_default)
    ,.cfg_cxl_dev_post_hot_rst_volatile_hdm_desired  (cfg_cxl_dev_post_hot_rst_volatile_hdm_desired)
    ,.cxl_volatile_hdm_error  (cxl_volatile_hdm_error)
    ,.cxl_pm_init_cmpl  (cxl_pm_init_cmpl)
    // -------------------------------------------------------------------------------------
    // CXL Error Status Signals
    // -------------------------------------------------------------------------------------
    ,.cfg_cxl_mbar0_corr_err  (cfg_cxl_mbar0_corr_err)
    ,.cfg_cxl_mbar0_uncorr_err  (cfg_cxl_mbar0_uncorr_err)
    ,.cfg_cxl_pl_reg_fatal_err  (cfg_cxl_pl_reg_fatal_err)
    // -------------------------------------------------------------------------------------
    // Signals from the CXL 2.0 Extension DVSEC Register
    // -------------------------------------------------------------------------------------
    ,.cfg_cxl_2_0_ext_port_ctl_ovr  (cfg_cxl_2_0_ext_port_ctl_ovr)
    ,.cfg_cxl_2_0_ext_alt_bus_base  (cfg_cxl_2_0_ext_alt_bus_base)
    ,.cfg_cxl_2_0_ext_alt_bus_limit  (cfg_cxl_2_0_ext_alt_bus_limit)
    ,.cfg_cxl_2_0_ext_alt_mem_base  (cfg_cxl_2_0_ext_alt_mem_base)
    ,.cfg_cxl_2_0_ext_alt_mem_limit  (cfg_cxl_2_0_ext_alt_mem_limit)
    ,.cfg_cxl_2_0_ext_alt_pref_mem_base  (cfg_cxl_2_0_ext_alt_pref_mem_base)
    ,.cfg_cxl_2_0_ext_alt_pref_mem_limit  (cfg_cxl_2_0_ext_alt_pref_mem_limit)
    ,.cfg_cxl_2_0_ext_alt_pref_mem_base_high  (cfg_cxl_2_0_ext_alt_pref_mem_base_high)
    ,.cfg_cxl_2_0_ext_alt_pref_mem_limit_high  (cfg_cxl_2_0_ext_alt_pref_mem_limit_high)
    ,.cfg_cxl_2_0_ext_rcrb_en  (cfg_cxl_2_0_ext_rcrb_en)
    ,.cfg_cxl_2_0_ext_rcrb_base_addr_low  (cfg_cxl_2_0_ext_rcrb_base_addr_low)
    ,.cfg_cxl_2_0_ext_rcrb_base_addr_high  (cfg_cxl_2_0_ext_rcrb_base_addr_high)
    // -------------------------------------------------------------------------------------
    // Signals from the CXL 2.0 Register Locator DVSEC Register
    // -------------------------------------------------------------------------------------
    ,.cfg_cxl_reg_locator_reg1_bir  (cfg_cxl_reg_locator_reg1_bir)
    ,.cfg_cxl_reg_locator_reg1_blk_identifier  (cfg_cxl_reg_locator_reg1_blk_identifier)
    ,.cfg_cxl_reg_locator_reg1_blk_offset_low  (cfg_cxl_reg_locator_reg1_blk_offset_low)
    ,.cfg_cxl_reg_locator_reg1_blk_offset_high  (cfg_cxl_reg_locator_reg1_blk_offset_high)
    ,.cfg_cxl_reg_locator_reg2_bir  (cfg_cxl_reg_locator_reg2_bir)
    ,.cfg_cxl_reg_locator_reg2_blk_identifier  (cfg_cxl_reg_locator_reg2_blk_identifier)
    ,.cfg_cxl_reg_locator_reg2_blk_offset_low  (cfg_cxl_reg_locator_reg2_blk_offset_low)
    ,.cfg_cxl_reg_locator_reg2_blk_offset_high  (cfg_cxl_reg_locator_reg2_blk_offset_high)
    ,.cfg_cxl_reg_locator_reg3_bir  (cfg_cxl_reg_locator_reg3_bir)
    ,.cfg_cxl_reg_locator_reg3_blk_identifier  (cfg_cxl_reg_locator_reg3_blk_identifier)
    ,.cfg_cxl_reg_locator_reg3_blk_offset_low  (cfg_cxl_reg_locator_reg3_blk_offset_low)
    ,.cfg_cxl_reg_locator_reg3_blk_offset_high  (cfg_cxl_reg_locator_reg3_blk_offset_high)
    // -------------------------------------------------------------------------------------
    // Signals from the CXL Port GPF DVSEC Register
    // -------------------------------------------------------------------------------------
    ,.cfg_cxl_gpf_port_p1_timeout_base  (cfg_cxl_gpf_port_p1_timeout_base)
    ,.cfg_cxl_gpf_port_p1_timeout_scale  (cfg_cxl_gpf_port_p1_timeout_scale)
    ,.cfg_cxl_gpf_port_p2_timeout_base  (cfg_cxl_gpf_port_p2_timeout_base)
    ,.cfg_cxl_gpf_port_p2_timeout_scale  (cfg_cxl_gpf_port_p2_timeout_scale)
    // -------------------------------------------------------------------------------------
    // CXL Retry Buffer RAM Interface
    // -------------------------------------------------------------------------------------
    ,.cxl_rbuf_ram_addr     (cxl_rbuf_ram_addr)
    ,.cxl_rbuf_ram_addr_par (cxl_rbuf_ram_addr_par)
    ,.cxl_rbuf_ram_en       (cxl_rbuf_ram_en)
    ,.cxl_rbuf_ram_we       (cxl_rbuf_ram_we)
    ,.cxl_rbuf_ram_wdata    (cxl_rbuf_ram_wdata)
    ,.cxl_rbuf_ram_rdata    (cxl_rbuf_ram_rdata)
    ,.cxl_mst_hreq_drsp_ram_we  (cxl_mst_hreq_drsp_ram_we)
    ,.cxl_mst_hreq_drsp_ram_wr_addr  (cxl_mst_hreq_drsp_ram_wr_addr)
    ,.cxl_mst_hreq_drsp_ram_wr_addr_par  (cxl_mst_hreq_drsp_ram_wr_addr_par)
    ,.cxl_mst_hreq_drsp_ram_wdata  (cxl_mst_hreq_drsp_ram_wdata)
    ,.cxl_mst_hreq_drsp_ram_rd_addr  (cxl_mst_hreq_drsp_ram_rd_addr)
    ,.cxl_mst_hreq_drsp_ram_rd_addr_par  (cxl_mst_hreq_drsp_ram_rd_addr_par)
    ,.cxl_mst_hreq_drsp_ram_rd  (cxl_mst_hreq_drsp_ram_rd)
    ,.cxl_mst_hreq_drsp_ram_rdata  (cxl_mst_hreq_drsp_ram_rdata)
    ,.cxl_mst_hrsp_dreq_ram_we  (cxl_mst_hrsp_dreq_ram_we)
    ,.cxl_mst_hrsp_dreq_ram_wr_addr  (cxl_mst_hrsp_dreq_ram_wr_addr)
    ,.cxl_mst_hrsp_dreq_ram_wr_addr_par  (cxl_mst_hrsp_dreq_ram_wr_addr_par)
    ,.cxl_mst_hrsp_dreq_ram_wdata  (cxl_mst_hrsp_dreq_ram_wdata)
    ,.cxl_mst_hrsp_dreq_ram_rd_addr  (cxl_mst_hrsp_dreq_ram_rd_addr)
    ,.cxl_mst_hrsp_dreq_ram_rd_addr_par  (cxl_mst_hrsp_dreq_ram_rd_addr_par)
    ,.cxl_mst_hrsp_dreq_ram_rd  (cxl_mst_hrsp_dreq_ram_rd)
    ,.cxl_mst_hrsp_dreq_ram_rdata  (cxl_mst_hrsp_dreq_ram_rdata)
    ,.cxl_mst_hd_data_ram_we  (cxl_mst_hd_data_ram_we)
    ,.cxl_mst_hd_data_ram_wr_addr  (cxl_mst_hd_data_ram_wr_addr)
    ,.cxl_mst_hd_data_ram_wr_addr_par  (cxl_mst_hd_data_ram_wr_addr_par)
    ,.cxl_mst_hd_data_ram_wdata  (cxl_mst_hd_data_ram_wdata)
    ,.cxl_mst_hd_data_ram_rd_addr  (cxl_mst_hd_data_ram_rd_addr)
    ,.cxl_mst_hd_data_ram_rd_addr_par  (cxl_mst_hd_data_ram_rd_addr_par)
    ,.cxl_mst_hd_data_ram_rd  (cxl_mst_hd_data_ram_rd)
    ,.cxl_mst_hd_data_ram_rdata  (cxl_mst_hd_data_ram_rdata)
    ,.cxl_mst_ms_ndr_ram_we  (cxl_mst_ms_ndr_ram_we)
    ,.cxl_mst_ms_ndr_ram_wr_addr  (cxl_mst_ms_ndr_ram_wr_addr)
    ,.cxl_mst_ms_ndr_ram_wr_addr_par  (cxl_mst_ms_ndr_ram_wr_addr_par)
    ,.cxl_mst_ms_ndr_ram_wdata  (cxl_mst_ms_ndr_ram_wdata)
    ,.cxl_mst_ms_ndr_ram_rd_addr  (cxl_mst_ms_ndr_ram_rd_addr)
    ,.cxl_mst_ms_ndr_ram_rd_addr_par  (cxl_mst_ms_ndr_ram_rd_addr_par)
    ,.cxl_mst_ms_ndr_ram_rd  (cxl_mst_ms_ndr_ram_rd)
    ,.cxl_mst_ms_ndr_ram_rdata  (cxl_mst_ms_ndr_ram_rdata)
    ,.cxl_mst_ms_data_ram_we  (cxl_mst_ms_data_ram_we)
    ,.cxl_mst_ms_data_ram_wr_addr  (cxl_mst_ms_data_ram_wr_addr)
    ,.cxl_mst_ms_data_ram_wr_addr_par  (cxl_mst_ms_data_ram_wr_addr_par)
    ,.cxl_mst_ms_data_ram_wdata  (cxl_mst_ms_data_ram_wdata)
    ,.cxl_mst_ms_data_ram_rd_addr  (cxl_mst_ms_data_ram_rd_addr)
    ,.cxl_mst_ms_data_ram_rd_addr_par  (cxl_mst_ms_data_ram_rd_addr_par)
    ,.cxl_mst_ms_data_ram_rd  (cxl_mst_ms_data_ram_rd)
    ,.cxl_mst_ms_data_ram_rdata  (cxl_mst_ms_data_ram_rdata)
// spyglass disable_block Topology_02
// SMD: Direct connection from input port to output port
// SJ: RAM-based FIFO is implemented to buffer data on Data Message Channels which propagates data to RAM data inputs
    ,.cxl_mst_ms_bi_ram_we  (cxl_mst_ms_bi_ram_we)
    ,.cxl_mst_ms_bi_ram_wr_addr  (cxl_mst_ms_bi_ram_wr_addr)
    ,.cxl_mst_ms_bi_ram_wr_addr_par  (cxl_mst_ms_bi_ram_wr_addr_par)
    ,.cxl_mst_ms_bi_ram_wdata  (cxl_mst_ms_bi_ram_wdata)
    ,.cxl_mst_ms_bi_ram_rd_addr  (cxl_mst_ms_bi_ram_rd_addr)
    ,.cxl_mst_ms_bi_ram_rd_addr_par  (cxl_mst_ms_bi_ram_rd_addr_par)
    ,.cxl_mst_ms_bi_ram_rd  (cxl_mst_ms_bi_ram_rd)
    ,.cxl_mst_ms_bi_ram_rdata  (cxl_mst_ms_bi_ram_rdata)
// spyglass enable_block Topology_02
    ,.int_cfg_upd_req_id  (int_cfg_upd_req_id)
    ,.current_data_rate  (current_data_rate)          // 0=running at gen1 speeds, 1=running at gen2 speed, 2-gen3, 3-gen4,...
    ,.pm_pclkack_timeout             (pm_pclkack_timeout)
 ////SPIF interface for CXL.cachemem/ARBMUX//////////
 ////SPIF interface for PCIe/CXL.io//////////

);

wire [`CX_NL*`CX_TX_COEF_WD-1:0] mac_phy_smlh_coef_rtx;

pm_ctrl

#(  .INST           (INST)
) u_pm_ctrl(
    .pm_hold_exit_l1                 (pm_hold_exit_l1                ),
    .pm_link_exit_l1                 (pm_link_exit_l1                ),
    .pm_link_exit_l23                (pm_link_exit_l23               ),
    .pm_pl_wake_ack                  (pm_pl_wake_ack                 ),
    .pm_pl_clk_req                   (pm_pl_clk_req                  ),
    .pm_pl_phyinl1                   (pm_pl_phyinl1                  ),
    .pm_pl_phyinl2                   (pm_pl_phyinl2                  ),
    .pm_clk_pm_en                    (cfg_pm_clk_pm_en               ),
    .software_entr_l1                (software_entr_l1               ),
    .software_entr_l23               (software_entr_l23              ),
    .pm_aspm_l0s_en                  (pm_aspm_l0s_en                 ),
    .pm_aspm_l1_en                   (pm_aspm_l1_en                  ),
    .pm_xtlh_block_tlp               (pm_xtlh_block_tlp              ),
    .pm_radm_block_tlp               (pm_radm_block_tlp              ),
    .pm_linkst_in_l0s                (int_pm_linkst_in_l0s           ),
    .pm_usp_link_state               (pm_usp_link_state              ),
    .pm_dsp_link_state               (pm_dsp_link_state              ),
    .shadow_pm_usp_link_state        (shadow_pm_usp_link_state       ),
    .shadow_pm_dsp_link_state        (shadow_pm_dsp_link_state       ),
    .pm_wake_req_exit_l0s            (pm_wake_req_exit_l0s           ),
    .pm_l2_entry_flag                (pm_l2_entry_flag               ),
    .pm_wake_any_if_pending          (pm_wake_any_if_pending         ),
    .lp_pcie_l1_exit                 (lp_pcie_l1_exit                ),
    .lp_pcie_clk_ack                 (lp_pcie_clk_ack                ),
    .lp_pcie_wake_req                (lp_pcie_wake_req               ),
    .pl_pcie_wake_ack                (pl_pcie_wake_ack               ),
    .pl_pcie_clk_req                 (pl_pcie_clk_req                ),
    .pl_pcie_phyinl1                 (pl_pcie_phyinl1                ),
    .pl_pcie_phyinl2                 (pl_pcie_phyinl2                ),
    .pl_pcie_state_l1                (pl_pcie_state_l1               ),
    .pl_pcie_state_l2                (pl_pcie_state_l2               ),
    .pl_pcie_state_active            (pl_pcie_state_active           ),
    .pl_pcie_link_up                 (pl_pcie_link_up                ),
    .lp_cxl_l1_exit                  (lp_cxl_l1_exit                 ),
    .lp_cxl_clk_ack                  (lp_cxl_clk_ack                 ),
    .lp_cxl_wake_req                 (lp_cxl_wake_req                ),
    .pl_cxl_wake_ack                 (pl_cxl_wake_ack                ),
    .pl_cxl_clk_req                  (pl_cxl_clk_req                 ),
    .pl_cxl_phyinl1                  (pl_cxl_phyinl1                 ),
    .pl_cxl_phyinl2                  (pl_cxl_phyinl2                 ),
    .pl_cxl_state_l1                 (pl_cxl_state_l1                ),
    .pl_cxl_state_l2                 (pl_cxl_state_l2                ),
    .pl_cxl_mode_enable              (pl_cxl_mode_enable             ),
    .pm_xdlh_enter_l23               (pm_xdlh_enter_l23              ),
    .pm_l1_entry_started             (int_pm_l1_entry_started        ),
    .pm_l1_in_progress               (pm_l1_in_progress              ),
    .pm_aspm_l1_enter_ready          (int_pm_aspm_l1_enter_ready     ),
    .latch_as_entr_l1                (latch_as_entr_l1               ),
    .pm_prot_idle_flag               (pm_prot_idle_flag              ),
    .lp_sdb_l1sub_aspm               (lp_sdb_l1sub_aspm              ),
    .lp_sdb_l1sub_pcipm              (lp_sdb_l1sub_pcipm             ),

    //    ----------------- Inputs ----------------------
    .core_rst_n                     (core_rst_n),
    .cfg_aspm_l1_timer_enable       (cfg_aspm_l1_timer_enable),
    .cfg_upd_aslk_pmctrl            (cfg_upd_aslk_pmctrl),
    .cfg_upd_pme_cap                (cfg_upd_pme_cap),
    .aux_clk                        (aux_clk),
    .pwr_rst_n                      (pwr_rst_n),
    .link_req_rst_not               (link_req_rst_not),
    .app_clk_req_n                  (app_clk_req_n),
    .phy_clk_req_n                  (phy_clk_req_n),
    .app_hold_phy_rst               (app_hold_phy_rst),
// Connect the pipe_clk to the clock which is launching Phystatus
    .pipe_clk                       (core_clk_ug),
    .radm_idle                      (radm_idle),
    .rstctl_ltssm_enable            (rstctl_ltssm_enable),
    .trgt_cpl_lut_empty             (trgt_cpl_lut_empty),
    .upstream_port                  (pre_upstream_port),
    .switch_device                  (1'b0),
    .xdlh_xmt_pme_ack               (xdlh_xmt_pme_ack),
    .one_dwsp_exit_l1               (1'b0),
    .one_dwsp_exit_l23              (1'b0),
    .app_ready_entr_l23             (app_ready_entr_l23),
    .app_req_exit_l1                (app_req_exit_l1),
    .xdlh_not_expecting_ack         (xdlh_not_expecting_ack),
    .smlh_link_up                   (smlh_link_up),
    .smlh_in_l0                     (smlh_in_l0),
    .smlh_in_l1                     (smlh_in_l1),
    .smlh_in_l23                    (smlh_in_l23),
    .smlh_link_in_training          (smlh_link_in_training),
    .smlh_ltssm_state               (smlh_ltssm_state_int),
    .sys_aux_pwr_det                (sys_aux_pwr_det),
    .cfg_aslk_pmctrl                (cfg_aslk_pmctrl),
    .all_dwsp_rcvd_toack_msg        (1'b0),
    .outband_pwrup_cmd              (outband_pwrup_cmd),
    .cfg_upd_pmcsr                  (cfg_upd_pmcsr),
    .cfg_upd_aux_pm_en              (cfg_upd_aux_pm_en),
    .cfg_pmstatus_clr               (cfg_pmstatus_clr),
    .cfg_pmstate                    (cfg_pmstate),
    .cfg_pme_en                     (cfg_pme_en),
    .cfg_aux_pm_en                  (cfg_aux_pm_en),
    .cfg_upd_req_id                 (int_cfg_upd_req_id),
    .cfg_pbus_dev_num               (int_cfg_pbus_dev_num),
    .cfg_pbus_num                   (int_cfg_pbus_num),
    .cfg_clk_pm_en                  (cfg_clk_pm_en),
    .radm_pm_turnoff                (radm_pm_turnoff),
    .radm_pm_to_ack                 (int_radm_pm_to_ack),
    .apps_pm_xmt_turnoff            (apps_pm_xmt_turnoff),
    .apps_pm_xmt_pme                (apps_pm_xmt_pme),              // Only for upstream port
    .cfg_pme_cap                    (cfg_pme_cap),
    .current_data_rate              (current_data_rate),
    .rmlh_descrambled_even_parity   (rmlh_descrambled_even_parity),
    .xmlh_scramble_even_parity      (xmlh_scramble_even_parity),
    .aux_clk_active                 (aux_clk_active),
    .phy_mac_phystatus              (phy_mac_phystatus),
    .phy_mac_rxstatus               (phy_mac_rxstatus),
    .aux_sync_p1_ack                (pipe_aux_sync_p1_ack),
    .phystatus_pc_busy              (pipe_aux_sync_block),
    .cfg_l1sub_control              (cfg_l1sub_control),
    .cfg_pl_l1sub_control           (cfg_pl_l1sub_control),
    .cfg_pl_l1_exit_mode            (cfg_pl_l1_exit_mode),
    .clkreq_in_n                    (clkreq_in_n),
    .cfg_pl_l1_clk_sel              (cfg_pl_l1_clk_sel),
    .cfg_p2nobeacon_enable          (cfg_p2nobeacon_enable),
    .cfg_utility                    (cfg_utility),
    .pm_cfg_utility                 (pm_cfg_utility),
    .cfg_pipe_optional_pclkchange_hs(cfg_pipe_optional_pclkchange_hs),
    .cfg_phy_perst_on_warm_reset    (cfg_phy_perst_on_warm_reset),
    .cfg_phy_rst_timer              (cfg_phy_rst_timer),
    .cfg_pma_phy_rst_delay_timer    (cfg_pma_phy_rst_delay_timer),
    .cfg_pl_aux_clk_freq            (cfg_pl_aux_clk_freq),
    .cfg_pl_gen3_zrxdc_noncompl     (cfg_pl_gen3_zrxdc_noncompl),
    .pme_to_ack_grt                 (pme_to_ack_grt),
    .lbc_active                     (lbc_active),
    .pm_pme_grant                   (pm_pme_grant),
    .pme_turn_off_grt               (pme_turn_off_grt),
    .perst_n                        (perst_n),
    .app_xfer_pending                  (app_xfer_pending),
    .slv_awvalid                    (slv_awvalid),
    .slv_arvalid                    (slv_arvalid),
    .slv_wvalid                     (slv_wvalid),
    .brdg_dbi_xfer_pending          (brdg_dbi_xfer_pending),
    .brdg_slv_xfer_pending          (brdg_slv_xfer_pending),

    .brdg_mstr_xfer_pending         (brdg_mstr_xfer_pending),

  .xali_xaim_pkt                (xali_xaim_pkt),  // Connect to XALI directly if no AMBA bridge
    .msg_gen_hv                     (msg_gen_hv),
    .lbc_cpl_hv                     (lbc_cpl_hv),

    .app_obff_idle_msg_req          (app_obff_idle_msg_req),
    .app_obff_obff_msg_req          (app_obff_obff_msg_req),
    .app_obff_cpu_active_msg_req    (app_obff_cpu_active_msg_req),

    .cxl_cache_slv_req              (cxl_cache_slv_req),
    .pm_cxl_cache_slv_req           (pm_cxl_cache_slv_req),
    .cxl_mem_slv_req                (cxl_mem_slv_req),
    .pm_cxl_mem_slv_req             (pm_cxl_mem_slv_req),
    .ptm_updating                   (ptm_updating),
    .cfg_link_capable               (cfg_link_capable),
    .mac_phy_powerdown              (pre_mac_phy_powerdown),
    .mac_phy_txelecidle             (int_mac_phy_txelecidle),
    // PHY interface signals
    .app_sris_mode                  (app_sris_mode),
    .xmlh_sris_enable               (xmlh_sris_enable),
    .phy_mac_rxelecidle             (phy_mac_rxelecidle),
    .mac_phy_txdata                 (pre_mac_phy_txdata),
    .mac_phy_txdetectrx_loopback    (pre_mac_phy_txdetectrx_loopback),
    .mac_phy_txcompliance           (glue_mac_phy_txcompliance),
    .mac_phy_rxpolarity             (pre_mac_phy_rxpolarity),
    .ltssm_rxpolarity               (tmp_mac_phy_rxpolarity),
    .mac_phy_width                  (pre_mac_phy_width),
    .mac_phy_serdes_arch            (pre_mac_phy_serdes_arch),
    .mac_phy_rxwidth                (pre_mac_phy_rxwidth),
    .serdes_pipe_rxready            (pre_serdes_pipe_rxready),
    .serdes_pipe_turnoff_lanes      (pre_serdes_pipe_turnoff_lanes),
    .mac_phy_pclk_rate              (pre_mac_phy_pclk_rate),
    .mac_phy_rxstandby              (pre_mac_phy_rxstandby),
    .mac_phy_rate                   (pre_mac_phy_rate),
    .mac_phy_txdeemph               (pre_mac_phy_txdeemph),
    .mac_phy_txdatavalid            (pre_mac_phy_txdatavalid),
    .mac_phy_rxeqeval               (pre_mac_phy_rxeqeval),
    .mac_phy_dirchange              (pre_mac_phy_dirchange),
    .mac_phy_smlh_coef_rtx          (pre_mac_phy_smlh_coef_rtx),
    .mac_phy_mbus                   (pre_mac_phy_mbus),
    .cfg_phy_control                (pre_cfg_phy_control),
    .cfg_comm_clk_config            (cfg_comm_clk_config),

    .rx_lane_flip_en                (rx_lane_flip_en),
    .tx_lane_flip_en                (tx_lane_flip_en),
    .smlh_lane_flip_ctrl            (smlh_lane_flip_ctrl),

    .cfg_link_dis                   (cfg_link_dis),
    .cfg_link_retrain               (cfg_link_retrain),
    .cfg_lpbk_en                    (cfg_lpbk_en),
    .cfg_2nd_reset                  (cfg_2nd_reset),
    .cfg_plreg_reset                (cfg_plreg_reset),
    .app_init_rst                   (app_init_rst),
    .cfg_directed_speed_change      (cfg_directed_speed_change),
    .cfg_directed_width_change      (cfg_pl_multilane_control[6]),
    .ven_msg_req                    (ven_msg_req),
    .ven_msi_req                    (ven_msi_req),
    .app_ltr_msg_req                (app_ltr_msg_req),
    .app_unlock_msg                 (app_unlock_msg),
    .msg_gen_unlock_grant           (msg_gen_unlock_grant),
    .edma_xfer_pending              (edma_xfer_pending),
    .app_l1sub_disable              (app_l1sub_disable),
    .latched_rxdetected             (latched_rxdetected),
    .cdm_pm_state_trans_tracker(cdm_pm_state_trans_tracker),
    .pm_cdm_state_trans_tracking(pm_cdm_state_trans_tracking),
    .smlh_pm_state_trans1_flag(smlh_pm_state_trans1_flag),
    .smlh_pm_state_trans2_flag(smlh_pm_state_trans2_flag),
    // ----------------- Outputs -----------------------
    .pm_en_aux_clk_g                (en_aux_clk_g),
    .pm_ltssm_enable                (pm_ltssm_enable),
    .pm_current_data_rate           (int_pm_current_data_rate),
    .pm_rmlh_descrambled_even_parity (pm_rmlh_descrambled_even_parity),
    .pm_xmlh_scramble_even_parity    (pm_xmlh_scramble_even_parity),
    .wake                           (wake),
    .local_ref_clk_req_n            (local_ref_clk_req_n),
    .pm_smlh_l23_exit               (pm_smlh_l23_exit),
    .pm_req_dwsp_turnoff            (),
    .pm_xmt_turnoff                 (pm_xmt_turnoff),               // N/A for endpoint
    .pm_xmt_to_ack                  (pm_xmt_to_ack),
    .pm_xmt_pme                     (pm_xmt_pme),
    .pm_turnoff_timeout             (pm_turnoff_timeout),
    .pm_linkst_in_l1                (pm_linkst_in_l1),
    .pm_linkst_in_l2                (pm_linkst_in_l2),
    .pm_linkst_in_l23rdy            (pm_linkst_in_l23rdy),
    .pm_linkst_l2_exit              (pm_linkst_l2_exit),
    .pm_linkst_in_l3                (),
    .shadow_pm_linkst_in_l0s        (pm_linkst_in_l0s),
    .shadow_pm_linkst_in_l0         (pm_linkst_in_l0),
    .pm_pme_en                      (pm_pme_en),
    .pm_status                      (pm_status),
    .pm_aux_pm_en                   (aux_pm_en),
    .pm_bus_num                     (pm_bus_num),
    .pm_dev_num                     (pm_dev_num),
    .pm_int_phy_powerdown           (pm_int_phy_powerdown),
    .pm_current_powerdown_p1        (pm_current_powerdown_p1),
    .pm_current_powerdown_p0        (pm_current_powerdown_p0),
    .pm_curnt_state                 (pm_curnt_state),
    .pm_req_sticky_rst              (pm_req_sticky_rst),
    .pm_req_core_rst                  (pm_req_core_rst),
    .pm_req_non_sticky_rst          (pm_req_non_sticky_rst),
    .pm_upstream_port               (upstream_port),    
    .pm_sel_aux_clk                 (pm_sel_aux_clk),
    .pm_en_core_clk                 (pm_en_core_clk),
    .pm_req_phy_rst                 (pm_req_phy_rst),
    .pm_req_phy_perst               (pm_req_phy_perst),
    .pm_linkst_in_l1sub             (pm_linkst_in_l1sub),
    .pm_smlh_l1_2_latched           (pm_smlh_l1_2_latched),
    .pm_smlh_l1_n_latched           (pm_smlh_l1_n_latched),
    .pm_in_l11                      (pm_in_l11),
    .pm_in_l12                      (pm_in_l12),
    .pm_in_l1_short                 (pm_in_l1_short),
    .pm_in_l1_cpm                   (pm_in_l1_cpm),
    .pm_in_l1_abort                 (pm_in_l1_abort),
    .pm_pme_resend_flag             (pm_pme_resend_flag),
    .pm_block_phystatus                 (pm_block_phystatus),
    .gasket_en_pulse_det                (pm_en_pulse_det),
    .phy_if_cfg_phy_control             (cfg_phy_control),
    .phy_if_cpcie_powerdown             (mac_phy_powerdown),
    .phy_if_cpcie_txelecidle            (mac_phy_txelecidle),
    .phy_if_cpcie_asyncpowerchangeack   (mac_phy_asyncpowerchangeack),
    .phy_if_cpcie_rxelecidle_disable    (mac_phy_rxelecidle_disable),
    .phy_if_cpcie_txcommonmode_disable  (mac_phy_txcommonmode_disable),
    .pm_l1sub_state                     (pm_l1sub_state),
    .pm_io_handler_app_sris_mode        (pm_io_handler_app_sris_mode),
    .pm_io_handler_sris_enable          (mac_phy_sris_enable),
    .phy_if_cpcie_txdata                (mac_phy_txdata),
    .phy_if_cpcie_txdetectrx_loopback   (mac_phy_txdetectrx_loopback),
    .phy_if_cpcie_txcompliance          (mac_phy_txcompliance),
    .phy_if_cpcie_rxpolarity            (mac_phy_rxpolarity),
    .phy_if_cpcie_width                 (mac_phy_width),
    .phy_if_cpcie_serdes_arch           (mac_phy_serdes_arch),
    .phy_if_cpcie_rxwidth               (mac_phy_rxwidth),
    .pm_serdes_pipe_rxready             (serdes_pipe_rxready),
    .pm_serdes_pipe_turnoff_lanes       (serdes_pipe_turnoff_lanes),
    .phy_if_cpcie_pclk_rate             (mac_phy_pclk_rate),
    .phy_if_cpcie_rxstandby             (mac_phy_rxstandby),
    .phy_if_cpcie_txdatavalid           (mac_phy_txdatavalid),
    .phy_if_cpcie_rate                  (mac_phy_rate),
    .phy_if_cpcie_txdeemph              (mac_phy_txdeemph),
    .phy_if_cpcie_rxeqeval              (mac_phy_rxeqeval),
    .phy_if_cpcie_dirchange             (mac_phy_dirchange),
    .phy_if_cpcie_smlh_coef_rtx         (mac_phy_smlh_coef_rtx),
    .phy_if_cfg_comm_clk_config         (mac_phy_commonclock_enable),
    .phy_if_cpcie_mbus                  (mac_phy_messagebus),
    .sqlchd_rxelecidle                  (sqlchd_rxelecidle),
    .pm_pmstate                         (pm_dstate),
    .pm_aux_clk_ft                      (pm_aux_clk),
    .pm_sys_aux_pwr_det_ft              (pm_sys_aux_pwr_det),
    .pm_aux_clk_active_ft               (pm_aux_clk_active),

    .pm_xadm_client0_tlp_hv             (pm_xadm_client0_tlp_hv)
    ,
    .pm_xadm_client1_tlp_hv             (pm_xadm_client1_tlp_hv)
    ,
    .pm_xadm_client2_tlp_hv             (pm_xadm_client2_tlp_hv)

    ,
    .pm_pme_en_split                    (pm_pme_en_split),
    .pm_aux_pm_en_split                 (pm_aux_pm_en_split),
    .pm_init_rst                        (pm_init_rst),
    .pm_unlock_msg_req                  (pm_unlock_msg_req)
    ,
    .pm_rx_lane_flip_ctrl               (pm_rx_lane_flip_en),
    .pm_tx_lane_flip_ctrl               (pm_tx_lane_flip_en),
    .pm_rx_pol_lane_flip_ctrl           (pm_rx_pol_lane_flip_ctrl)
    ,
    .pm_smlh_link_retrain               (pm_smlh_link_retrain)
    ,
    .shadow_pm_l1_entry_started         (pm_l1_entry_started)
    ,.pm_latched_rxdetected             (pm_latched_rxdetected)
    ,
    .pm_powerdown_status                (pm_powerdown_status),
    .cfg_force_powerdown                (cfg_force_powerdown)
    ,
    .phy_mac_pclkchangeok               (phy_mac_pclkchangeok),
    .mac_phy_pclkchangeack              (mac_phy_pclkchangeack),
    .pm_div_max_pclk_ratio              (pm_div_max_pclk_ratio)
    ,.mac_phy_maxpclkreq_n               (mac_phy_maxpclkreq_n),
    .phy_mac_maxpclkack_n               (phy_mac_maxpclkack_n)
    ,.pm_pclkack_timeout                (pm_pclkack_timeout)
    ,.shadow_pm_aspm_l1_enter_ready     (pm_aspm_l1_enter_ready)
);

endmodule
