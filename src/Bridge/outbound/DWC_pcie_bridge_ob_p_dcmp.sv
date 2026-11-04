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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #21 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_bridge_ob_p_dcmp.sv#21 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
//  The major funcions:
//  This module converts a core TRGT1 interface to GIF interface of a master AXI
//  1. a FIFO for data and header of a memrd/wr transaction that core receive to provide
//     a non-blocking architecture between core and one AXI master. Other Master can get traffic through
//  2. This FIFO also does the clock domain crossing between AXI clock and core clk. Only core clk runs less than AXI clock is supported
//  3. GIF interface control as a master is done in this block. A memRd/Wr received by core will be translated into GIF master trnasaction
//     to output to DWC GIF master module
//  4. Pipelined request transactions and response transactions are supported as long as inorder services is maintain.
//     No AXI out of order services are supported
//  5. A FIFO for header information of a memRd is designed in the block to handle completion type of request generated to core
//     When a response
//
//  Limitations:
//  1. only dword aligned address is supported
//  2. Each read/write received by core will be within one burst of the AXI transfer
//  3. Only support core data path width and AXI data path width to be the same
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Axi/DWC_pcie_axi_xali_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"


 module DWC_pcie_bridge_ob_p_dcmp
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
   import DWC_pcie_axi_xali_pkg::*;
   (
    slv_aclk,
    slv_aresetn,
    core_clk,
    core_rst_n,

    // Configuration interface
    cfg_max_payload_size,

    cfg_tc_struc_vc_map,

    // RAS Interface
    cfg_ras_recc_ob_pdcmp_hdr_correct,
    axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse,
    axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse,
    axi_ras_recc_cnt_ob_pdcmp_hdr_addr,

    cfg_ras_recc_ob_pdcmp_data_correct,
    axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse,
    axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse,
    axi_ras_recc_cnt_ob_pdcmp_data_addr,
    axi_recc_cnt_ob_pdcmp_ras_dp_err_log,
    axi_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log,

    // Request packet interface

    pdcmp_halt,
    prf_hv,
    prf_dv,
    prf_eot,
    prf_prfx,
    prf_p_tag,
    prf_th,
    prf_ph,
    prf_st,
    prf_atu_bypass,
    prf_dst_segment,
    prf_ats,
    prf_nw,
    prf_first_wrp_split_xact,
    prf_wrp_valid,
    prf_axi_id,
    prf_cpl_stat,
    prf_byte_len,
    prf_tc,
    prf_ep,
    prf_attr,
    prf_byte_en,
    prf_fmt,
    prf_type,
    prf_addr,
    prf_data,
    prf_ep_strb,
    prf_silentDrop_strb,
    prf_silentDrop_strb_masked,
    prf_strb,
    xadm_client2_halt,
    pdcmp_addr_parerr,
    pdcmp_inq_data_parerr,
    pdcmp_inq_dt_ras_dp_err_log,
    pdcmp_ad_ras_dp_err_log,
    ras_dp_err_inj_slv_aclk,
    axi_bridge_ras_dp_err_inj_core_clk,
    pdcmp_hdr_ram_addra,
    pdcmp_hdr_ram_addrb,
    pdcmp_hdr_ram_wea,
    pdcmp_hdr_ram_enb,
    pdcmp_hdr_ram_doutb,
    pdcmp_hdr_ram_dina,

    pdcmp_data_ram_addra,
    pdcmp_data_ram_addrb,
    pdcmp_data_ram_wea,
    pdcmp_data_ram_enb,
    pdcmp_data_ram_doutb,
    pdcmp_data_ram_dina,
    pdcmp_hv,
    pdcmp_dv,
    pdcmp_eot,
    pdcmp_prfx,
    pdcmp_p_tag,
    pdcmp_th,
    pdcmp_ph,
    pdcmp_st,
    pdcmp_atu_bypass,
    pdcmp_dst_segment,
    pdcmp_ats,
    pdcmp_nw,
    pdcmp_func_num,
    pdcmp_byte_len,
    pdcmp_tc,
    pdcmp_ep,
    pdcmp_silentDrop,
    pdcmp_attr,
    pdcmp_byte_en,
    pdcmp_fmt,
    pdcmp_type,
    pdcmp_addr,
    pdcmp_data,
    pdcmp_p_rsp_valid,
    pdcmp_p_rsp_null_or_err,
    pdcmp_p_rsp_last,
    pdcmp_p_rsp_vc_num,
    pdcmp_p_rsp_id,
    pdcmp_p_rsp_cpl_stat
   );

// Parameters depending on decomposer usage (inbound vs outbound, posted vs non-posted)
// ---------------------------------------------------------------------------------------------------------------------
parameter  TP                            = `TP;

localparam CC_SLV_BUS_ADDR_WIDTH         = `CC_SLV_BUS_ADDR_WIDTH;
localparam SLAVE_BUS_ADDR_WIDTH          = `SLAVE_BUS_ADDR_WIDTH;
localparam CC_SLV_BUS_ID_WIDTH           = `CC_SLV_BUS_ID_WIDTH;
localparam CC_SLV_RD_REQ_SIZE_PW         = `CC_SLV_RD_REQ_SIZE_PW;
localparam CC_CORE_DATA_BUS_WD           = `CC_CORE_DATA_BUS_WD;
localparam CC_CORE_ADDR_BUS_WD           = `CC_CORE_ADDR_BUS_WD;
localparam CC_PRF_TLP_DATA_WIDTH         = `CC_PRF_TLP_DATA_WIDTH;
localparam CC_PRF_TLP_DATA_WIDTH_NP      = `CC_PRF_TLP_DATA_WIDTH_NP;
localparam CC_PRF_TLP_NUM_WSTRBS         = `CC_PRF_TLP_NUM_WSTRBS;
localparam CC_MAX_SLV_TAG_PW             = `CC_MAX_SLV_TAG_PW;
localparam CX_LUT_PTR_WIDTH              = `CX_LUT_PTR_WIDTH ;
localparam CX_MAX_TAG                    = `CX_MAX_TAG;
localparam CX_TAG_SIZE                   = `CX_TAG_SIZE;
localparam CX_NFUNC                      = `CX_NFUNC;
localparam CX_NFUNC_WD                   = `CX_NFUNC_WD;
localparam CX_NVFUNC_WD                  = `CX_NVFUNC_WD;
localparam DC_CPL_STATUS_WD              = `DC_CPL_STATUS_WD;
localparam CC_SLV_MTU_PW                 = `CC_SLV_MTU_PW;
localparam SYNC_DEPTH                    = `CX_PCIE_SYNC_DEPTH;
localparam FIFO_BYTE_LEN_WD              = `CC_SLV_MTU_PW < (`CX_MAX_MTU_PW+1) ? `CC_SLV_MTU_PW : `CX_MAX_MTU_PW+1;
localparam PAGE_BOUNDARY_BIT             = 13; // power of 2 of address boundary uncrossable + 1.
localparam DCMP_PREFIX_WD                = (32*`CX_NPRFX)+ `CX_PRFX_PAR_WD;
localparam ADDR_PAR_WD                   = `CX_ADDR_PAR_WD;

localparam CC_OB_PDCMP_HDR_RAM_DP        = `CC_OB_PDCMP_HDR_RAM_DP;
localparam CC_OB_PDCMP_HDR_RAM_ADDR_WD   = `CC_OB_PDCMP_HDR_RAM_ADDR_WD;
localparam CC_OB_PDCMP_HDR_RAM_DATA_WD   = `CC_OB_PDCMP_HDR_RAM_DATA_WD;
localparam CC_OB_PDCMP_HDR_RAM_DATA_WD_NOECC   = `CC_OB_PDCMP_HDR_RAM_DATA_WD_NOECC;
localparam CC_OB_PDCMP_HDR_RAM_PTR_WD    = `CC_OB_PDCMP_HDR_RAM_PTR_WD;
localparam CC_OB_PDCMP_DATA_RAM_DP       = `CC_OB_PDCMP_DATA_RAM_DP;
localparam CC_OB_PDCMP_DATA_RAM_ADDR_WD  = `CC_OB_PDCMP_DATA_RAM_ADDR_WD;
localparam CC_OB_PDCMP_DATA_RAM_DATA_WD  = `CC_OB_PDCMP_DATA_RAM_DATA_WD;
localparam CC_OB_PDCMP_DATA_RAM_DATA_WD_NOECC  = `CC_OB_PDCMP_DATA_RAM_DATA_WD_NOECC;
localparam CC_OB_PDCMP_DATA_RAM_PTR_WD   = `CC_OB_PDCMP_DATA_RAM_PTR_WD;
localparam CC_OB_PDCMP_RAM_RD_LATENCY    = `CC_OB_PDCMP_RAM_RD_LATENCY;

localparam ATTR_WD                       = 3;

localparam POSTED_WR_RESP_INTF           = `CC_SLV_BUS_ID_WIDTH+3 ;
localparam C2APRSP_FIFO_DEPTH            = `CC_SLV_NUM_OUTSTND_WR_REQ;
localparam C2APRSP_FIFO_ADDR_WD          = `CC_SLV_NUM_OUTSTND_WR_REQ_LOG2;
localparam C2APRSP_PUSH_AF_LVL           = 1; // one from full
localparam C2APRSP_POP_AE_LVL            = 1; // one from empty
localparam C2APRSP_RST_MODE              = 0; // Include memory reset
localparam C2APRSP_PUSH_AE_LVL           = 1;
localparam C2APRSP_POP_AF_LVL            = 1;
localparam C2APRSP_PUSH_SYNC             = SYNC_DEPTH;
localparam C2APRSP_POP_SYNC              = SYNC_DEPTH;
localparam C2APRSP_HOLD_RD_ADDR          = 0;
// Sticky error flag
localparam C2APRSP_ERR_MODE              = 1'b0;


localparam CX_RAS_RAM_PROT_RANGE         = `CX_RAS_RAM_PROT_RANGE;
localparam CX_RAS_PROT_RANGE             = `CX_RAS_PROT_RANGE;
localparam CX_RAS_PARITY_MODE            = `CX_RAS_PARITY_MODE;
// Number of parity address blocks per 32/64 bit address
localparam NUM_ADDR_PAR_BLOCKS           = SLAVE_BUS_ADDR_WIDTH/CX_RAS_PROT_RANGE;
// Number of parity data blocks
localparam NUM_DATA_PAR_BLOCKS           = CC_PRF_TLP_DATA_WIDTH_NP/CX_RAS_PROT_RANGE;
localparam BITS_PER_STRB                 = 9;
localparam RAS_DP_ERR_LOG_WD             = $clog2(MAX_RAS_PROT_CHK_N);

   localparam [8:0] BUS_INIT_BYTE = CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;


// Port declaration
// ---------------------------------------------------------------------------------------------------------------------
input  wire                                  slv_aclk;                      // Inbound and outbound direction
input  wire                                  slv_aresetn;                   // Inbound and outbound direction
input  wire                                  core_clk;                      // Outbound direction only
input  wire                                  core_rst_n;                    // Outbound direction only

// Configuration interface
input  wire [(3*CX_NFUNC)-1:0]               cfg_max_payload_size;
input  vc_map_s                              cfg_tc_struc_vc_map;

input                                        cfg_ras_recc_ob_pdcmp_hdr_correct;
output wire                                  axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse;
output wire                                  axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse;
output wire [CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]axi_ras_recc_cnt_ob_pdcmp_hdr_addr;

input                                        cfg_ras_recc_ob_pdcmp_data_correct;
output wire                                  axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse;
output wire                                  axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse;
output wire [CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0]axi_ras_recc_cnt_ob_pdcmp_data_addr;
output ras_dp_err_log_t                      axi_recc_cnt_ob_pdcmp_ras_dp_err_log;
output ras_dp_err_log_t                      axi_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log;

// Request packet interface
output wire                                  pdcmp_halt;
input  wire                                  prf_hv;
input  wire                                  prf_dv;
input  wire                                  prf_eot;
input  wire [DCMP_PREFIX_WD-1:0]             prf_prfx;
input  wire [CX_TAG_SIZE-1:0]                prf_p_tag;
input  wire                                  prf_th;
input  wire [1:0]                            prf_ph;
input  wire [7:0]                            prf_st;
input  wire                                  prf_atu_bypass;
input  wire [8:0]                            prf_dst_segment;
input  wire [1:0]                            prf_ats;
input  wire                                  prf_nw;
input  wire                                  prf_first_wrp_split_xact;
input  wire                                  prf_wrp_valid;
input  wire [CC_SLV_BUS_ID_WIDTH-1:0]        prf_axi_id;
input  wire [DC_CPL_STATUS_WD -1:0]          prf_cpl_stat;
input  wire [CC_SLV_MTU_PW-1:0]              prf_byte_len;
input  wire [2:0]                            prf_tc;
input  wire                                  prf_ep;
input  wire [ATTR_WD-1:0]                    prf_attr;
input  wire [7:0]                            prf_byte_en;
input  wire [1:0]                            prf_fmt;
input  wire [4:0]                            prf_type;
input  wire [CC_SLV_BUS_ADDR_WIDTH-1:0]      prf_addr;
input  wire [CC_PRF_TLP_DATA_WIDTH-1:0]      prf_data;
input  wire [CC_PRF_TLP_NUM_WSTRBS -1:0]     prf_ep_strb;
input  wire [CC_PRF_TLP_NUM_WSTRBS -1:0]     prf_silentDrop_strb;
input  wire [CC_PRF_TLP_NUM_WSTRBS -1:0]     prf_silentDrop_strb_masked;
input  wire [CC_PRF_TLP_NUM_WSTRBS -1:0]     prf_strb;

input  wire                                  xadm_client2_halt;
output wire                                  pdcmp_addr_parerr;
output wire                                  pdcmp_inq_data_parerr;
output ras_dp_err_log_t                      pdcmp_ad_ras_dp_err_log;
output ras_dp_err_log_t                      pdcmp_inq_dt_ras_dp_err_log;
input  ras_dp_err_inj_t                      ras_dp_err_inj_slv_aclk;
input  ras_dp_err_inj_t                      axi_bridge_ras_dp_err_inj_core_clk;
output wire                                  pdcmp_hv;
output wire                                  pdcmp_dv;
output wire                                  pdcmp_eot;
output wire [DCMP_PREFIX_WD-1:0]             pdcmp_prfx;
output wire [CX_TAG_SIZE-1:0]                pdcmp_p_tag;
output wire                                  pdcmp_th;
output wire [1:0]                            pdcmp_ph;
output wire [7:0]                            pdcmp_st;
output wire                                  pdcmp_atu_bypass;
output wire [8:0]                            pdcmp_dst_segment;
output wire [1:0]                            pdcmp_ats;
output wire                                  pdcmp_nw;
output wire [CX_NFUNC_WD-1:0]                pdcmp_func_num;
output wire [12:0]                           pdcmp_byte_len;
output wire [2:0]                            pdcmp_tc;
output wire                                  pdcmp_ep;
output wire                                  pdcmp_silentDrop;
output wire [ATTR_WD-1:0]                    pdcmp_attr;
output wire [7:0]                            pdcmp_byte_en;
output wire [1:0]                            pdcmp_fmt;
output wire [4:0]                            pdcmp_type;
output wire [63+ADDR_PAR_WD:0]               pdcmp_addr;
output wire [CC_CORE_DATA_BUS_WD-1:0]        pdcmp_data;

output wire [CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]  pdcmp_hdr_ram_addra;           // Outbound direction only
output wire [CC_OB_PDCMP_HDR_RAM_ADDR_WD-1:0]  pdcmp_hdr_ram_addrb;           // Outbound direction only
output wire                                    pdcmp_hdr_ram_wea;             // Outbound direction only
output wire                                    pdcmp_hdr_ram_enb;             // Outbound direction only
input  wire [CC_OB_PDCMP_HDR_RAM_DATA_WD-1:0]  pdcmp_hdr_ram_doutb;           // Outbound direction only
output wire [CC_OB_PDCMP_HDR_RAM_DATA_WD-1:0]  pdcmp_hdr_ram_dina;            // Outbound direction only

output wire [CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0] pdcmp_data_ram_addra;          // Outbound direction only
output wire [CC_OB_PDCMP_DATA_RAM_ADDR_WD-1:0] pdcmp_data_ram_addrb;          // Outbound direction only
output wire                                    pdcmp_data_ram_wea;            // Outbound direction only
output wire                                    pdcmp_data_ram_enb;            // Outbound direction only
input  wire [CC_OB_PDCMP_DATA_RAM_DATA_WD-1:0] pdcmp_data_ram_doutb;          // Outbound direction only
output wire [CC_OB_PDCMP_DATA_RAM_DATA_WD-1:0] pdcmp_data_ram_dina;           // Outbound direction only

output wire                                    pdcmp_p_rsp_valid;
output wire [CC_SLV_BUS_ID_WIDTH-1:0]          pdcmp_p_rsp_id;
output wire [DC_CPL_STATUS_WD-1:0]             pdcmp_p_rsp_cpl_stat;
output wire                                    pdcmp_p_rsp_null_or_err;
output wire                                    pdcmp_p_rsp_last;
output wire [2:0]                              pdcmp_p_rsp_vc_num;

// In queue output wire declaration
// ---------------------------------------------------------------------------------------------------------------------
wire                                         inq_pkt_hv;
wire                                         inq_pkt_dv;
wire                                         inq_pkt_eot;
wire                                         inq_pkt_null;
wire [DCMP_PREFIX_WD-1:0]                    inq_pkt_prfx;
wire [CX_TAG_SIZE-1:0]                       inq_pkt_p_tag;
wire                                         inq_pkt_th;
wire [1:0]                                   inq_pkt_ph;
wire [7:0]                                   inq_pkt_st;
wire                                         inq_pkt_atu_bypass;
wire [8:0]                                   inq_pkt_dst_segment;
wire [1:0]                                   inq_pkt_ats;
wire                                         inq_pkt_nw;
wire                                         inq_pkt_last_tlp;
wire [CC_SLV_BUS_ID_WIDTH-1:0]               inq_pkt_axi_id;
wire [DC_CPL_STATUS_WD -1:0]                 inq_pkt_cpl_stat;
wire [FIFO_BYTE_LEN_WD-1:0]                  inq_pkt_byte_len;
wire [2:0]                                   inq_pkt_tc;
wire                                         inq_pkt_ep;
wire                                         inq_pkt_silentDrop;
wire [ATTR_WD-1:0]                           inq_pkt_attr;
wire [7:0]                                   inq_pkt_byte_en;
wire [1:0]                                   inq_pkt_fmt;
wire [4:0]                                   inq_pkt_type;
wire [CC_SLV_BUS_ADDR_WIDTH-1:0]             inq_pkt_addr;
wire [SLAVE_BUS_ADDR_WIDTH-1:0]              s_inq_pkt_addr;
wire [CC_PRF_TLP_DATA_WIDTH-1:0]             inq_pkt_data;
wire [CC_PRF_TLP_NUM_WSTRBS-1:0]             inq_pkt_strb;
wire [CC_PRF_TLP_DATA_WIDTH-1:0]             s_inq_pkt_data_strb;
wire [CC_PRF_TLP_DATA_WIDTH_NP-1:0]          s_inq_pkt_data;


// Header fifo output wire declaration
// ---------------------------------------------------------------------------------------------------------------------
wire                                         hf_pkt_halt;
wire                                         hf_pkt_valid;
wire [DCMP_PREFIX_WD-1:0]                    hf_pkt_prfx;
wire [CX_TAG_SIZE-1:0]                       hf_pkt_p_tag;
wire                                         hf_pkt_th;
wire [1:0]                                   hf_pkt_ph;
wire [7:0]                                   hf_pkt_st;
wire                                         hf_pkt_atu_bypass;
wire [8:0]                                   hf_pkt_dst_segment;
wire [1:0]                                   hf_pkt_ats;
wire                                         hf_pkt_nw;
wire                                         hf_pkt_null;
wire                                         hf_pkt_last_tlp;
wire [CC_SLV_BUS_ID_WIDTH-1:0]               hf_pkt_axi_id;
wire                                         hf_pkt_cpl_stat_0b;
wire [DC_CPL_STATUS_WD -1:0]                 hf_pkt_cpl_stat;
wire [FIFO_BYTE_LEN_WD-1:0]                  hf_pkt_byte_len;

wire [2:0]                                   hf_pkt_tc;
wire                                         hf_pkt_ep;
wire                                         hf_pkt_silentDrop;
wire [ATTR_WD-1:0]                           hf_pkt_attr;
wire [7:0]                                   hf_pkt_byte_en;
wire [1:0]                                   hf_pkt_fmt;
wire [4:0]                                   hf_pkt_type;
wire [SLAVE_BUS_ADDR_WIDTH-1:0]              hf_pkt_addr;
wire [CC_SLV_BUS_ADDR_WIDTH-1:0]             s_hf_pkt_addr;

// Data fifo output wire declaration
// ---------------------------------------------------------------------------------------------------------------------
wire                                         df_pkt_halt;
wire                                         df_pkt_valid;
wire [CC_PRF_TLP_DATA_WIDTH_NP-1:0]          df_pkt_data;
wire [CC_PRF_TLP_DATA_WIDTH-1:0]             s_df_pkt_data;

// Halt signal generated from fifos
// ---------------------------------------------------------------------------------------------------------------------
wire                                         fifo_pkt_halt;

wire                                         outq_hf_ready;
wire                                         outq_df_ready;

wire                                         outq_hv;
wire                                         outq_dv;
wire                                         outq_eot;
wire        [DCMP_PREFIX_WD-1:0]             outq_prfx;
wire [CX_TAG_SIZE-1:0]                       outq_p_tag;
wire                                         outq_th;
wire        [1:0]                            outq_ph;
wire        [7:0]                            outq_st;
wire                                         outq_atu_bypass;
wire        [8:0]                            outq_dst_segment;
wire        [1:0]                            outq_ats;
wire                                         outq_nw;
wire        [CX_NFUNC_WD-1:0]                outq_func_num;
wire        [DC_CPL_STATUS_WD -1:0]          outq_cpl_stat;
wire        [12:0]                           outq_byte_len;
wire        [2:0]                            outq_tc;
wire                                         outq_ep;
wire                                         outq_silentDrop;
wire        [ATTR_WD-1:0]                    outq_attr;
wire        [7:0]                            outq_byte_en;
wire        [1:0]                            outq_fmt;
wire        [4:0]                            outq_type;
wire        [CC_SLV_BUS_ADDR_WIDTH-1:0]      outq_addr;
wire        [CC_PRF_TLP_DATA_WIDTH-1:0]      outq_data;
wire                                         dcnvtr_halt;
wire                                         dwnstrm_halt;

wire                                         outq_p_rsp_valid;
wire        [CC_SLV_BUS_ID_WIDTH-1:0]        outq_p_rsp_id;
wire        [DC_CPL_STATUS_WD-1:0]           outq_p_rsp_cpl_stat;
wire                                         outq_p_rsp_null_or_err;
wire                                         outq_p_rsp_last;
wire        [2:0]                            outq_p_rsp_vc_num;

wire                                         s_c2aprsp_push_req_n;
wire [POSTED_WR_RESP_INTF-1:0]               s_c2aprsp_push_data;
wire                                         c2aprsp_push_af_nc;
wire                                         c2aprsp_push_full_nc;
wire                                         c2aprsp_pop_empty;
wire [POSTED_WR_RESP_INTF-1:0]               c2aprsp_pop_data;

wire [CC_SLV_BUS_ADDR_WIDTH-1:0]             s_pdcmp_addr;


// Input queue instantiation
// ---------------------------------------------------------------------------------------------------------------------
DWC_pcie_bridge_ob_p_dcmp_inq

   u_inq
   (
    .slv_aclk                   ( slv_aclk                      ),
    .slv_aresetn                ( slv_aresetn                   ),

    // Configuration interface
    .cfg_max_payload_size       ( cfg_max_payload_size          ),

    // Request packet interface
    .inq_pkt_halt               ( pdcmp_halt                    ),
    .req_pkt_hv                 ( prf_hv                        ),
    .req_pkt_dv                 ( prf_dv                        ),
    .req_pkt_eot                ( prf_eot                       ),
    .req_pkt_prfx               ( prf_prfx                      ),
    .req_pkt_p_tag              ( prf_p_tag                     ),
    .req_pkt_th                 ( prf_th                        ),
    .req_pkt_ph                 ( prf_ph                        ),
    .req_pkt_st                 ( prf_st                        ),
    .req_pkt_atu_bypass         ( prf_atu_bypass                ),
    .req_pkt_dst_segment        ( prf_dst_segment               ),
    .req_pkt_ats                ( prf_ats                       ),
    .req_pkt_nw                 ( prf_nw                        ),
    .req_pkt_first_wrp_split_xact ( prf_first_wrp_split_xact    ),
    .req_pkt_wrp_valid            ( prf_wrp_valid               ),
    .req_pkt_axi_id             ( prf_axi_id                    ),
    .req_pkt_cpl_stat           ( prf_cpl_stat                  ),
    .req_pkt_byte_len           ( prf_byte_len                  ),
    .req_pkt_tc                 ( prf_tc                        ),
    .req_pkt_ep                 ( prf_ep                        ),
    .req_pkt_attr               ( prf_attr                      ),
    .req_pkt_byte_en            ( prf_byte_en                   ),
    .req_pkt_fmt                ( prf_fmt                       ),
    .req_pkt_type               ( prf_type                      ),
    .req_pkt_addr               ( prf_addr                      ),
    .req_pkt_data               ( prf_data                      ),
    .req_pkt_ep_strb            ( prf_ep_strb                   ),
    .req_pkt_silentDrop_strb    ( prf_silentDrop_strb           ),
    .req_pkt_silentDrop_strb_masked( prf_silentDrop_strb_masked    ),
    .req_pkt_strb               ( prf_strb                      ),
    .pdcmp_addr_parerr          ( pdcmp_addr_parerr             ),
    .pdcmp_ad_ras_dp_err_log    (pdcmp_ad_ras_dp_err_log        ),
    .ras_dp_err_inj_slv_aclk    (ras_dp_err_inj_slv_aclk        ),
    .fifo_pkt_halt              ( fifo_pkt_halt                 ),
    .inq_pkt_hv                 ( inq_pkt_hv                    ),
    .inq_pkt_dv                 ( inq_pkt_dv                    ),
    .inq_pkt_eot                ( inq_pkt_eot                   ),
    .inq_pkt_null               ( inq_pkt_null                  ),
    .inq_pkt_prfx               ( inq_pkt_prfx                  ),
    .inq_pkt_p_tag              ( inq_pkt_p_tag                 ),
    .inq_pkt_th                 ( inq_pkt_th                    ),
    .inq_pkt_ph                 ( inq_pkt_ph                    ),
    .inq_pkt_st                 ( inq_pkt_st                    ),
    .inq_pkt_atu_bypass         ( inq_pkt_atu_bypass            ),
    .inq_pkt_dst_segment        ( inq_pkt_dst_segment           ),
    .inq_pkt_ats                ( inq_pkt_ats                   ),
    .inq_pkt_nw                 ( inq_pkt_nw                    ),
    .inq_pkt_last_tlp           ( inq_pkt_last_tlp              ),
    .inq_pkt_axi_id             ( inq_pkt_axi_id                ),
    .inq_pkt_cpl_stat           ( inq_pkt_cpl_stat              ),
    .inq_pkt_byte_len           ( inq_pkt_byte_len              ),
    .inq_pkt_tc                 ( inq_pkt_tc                    ),
    .inq_pkt_ep                 ( inq_pkt_ep                    ),
    .inq_pkt_silentDrop         ( inq_pkt_silentDrop            ),
    .inq_pkt_attr               ( inq_pkt_attr                  ),
    .inq_pkt_byte_en            ( inq_pkt_byte_en               ),
    .inq_pkt_fmt                ( inq_pkt_fmt                   ),
    .inq_pkt_type               ( inq_pkt_type                  ),
    .inq_pkt_addr               ( inq_pkt_addr                  ),
    .inq_pkt_strb               ( inq_pkt_strb                  ),
    .inq_pkt_data               ( inq_pkt_data                  )


   );



  // Parity bits of inq_pkt_addr are added in u_inq instance. Thus, no parity
  // checker is needed at this point. However to keep the code modular the
  // parity addition code in u_inq was kept in the module even the parity removal
  // looks redundant here. Synthesis tool should remove parity bits of inq_pkt_addr.
  assign s_inq_pkt_addr = fn_addr_wo_par(inq_pkt_addr);

// Header fifo instantiation
// ---------------------------------------------------------------------------------------------------------------------
DWC_pcie_bridge_async_fifo_ram_latency

  #(
    .DATA_WIDTH                 ( CC_OB_PDCMP_HDR_RAM_DATA_WD_NOECC   ),
    .ECC_WIDTH                  ( CC_OB_PDCMP_HDR_RAM_DATA_WD - CC_OB_PDCMP_HDR_RAM_DATA_WD_NOECC),
    .CX_RAS_RAM_PROT_RANGE      ( CX_RAS_RAM_PROT_RANGE         ),
    .DEPTH                      ( CC_OB_PDCMP_HDR_RAM_DP        ),
    .RAM_ADDR_WIDTH             ( CC_OB_PDCMP_HDR_RAM_ADDR_WD   ),
    .COUNT_WIDTH                ( CC_OB_PDCMP_HDR_RAM_PTR_WD    ),
    .PUSH_SYNC                  ( SYNC_DEPTH                    ),
    .POP_SYNC                   ( SYNC_DEPTH                    ),
    .RAS_DP_ID                  (`OB_PDCMP_HDR_RAS_ID           ),
    .RAM_RD_LATENCY             ( CC_OB_PDCMP_RAM_RD_LATENCY    )
   )
   u_hf
   (
    .clk_push                   ( slv_aclk                      ),
    .rst_push_n                 ( slv_aresetn                   ),
    .push_req_n                 ( !inq_pkt_hv || fifo_pkt_halt  ),
    .push_data                  ( {
                                   inq_pkt_prfx,
                                   inq_pkt_p_tag,
                                   inq_pkt_th,
                                   inq_pkt_ph,
                                   inq_pkt_st,
                                   inq_pkt_atu_bypass,
                                   inq_pkt_dst_segment,
                                   inq_pkt_ats,
                                   inq_pkt_nw,
                                   inq_pkt_null,
                                   inq_pkt_last_tlp,
                                   inq_pkt_axi_id,
                                   inq_pkt_cpl_stat[0], // to avoid RAM bits tied to a fix value because UR is the only error response, use only bit 0 of cpl_stat
                                   inq_pkt_byte_len,
                                   inq_pkt_tc,
                                   inq_pkt_ep,
                                   inq_pkt_silentDrop,
                                   inq_pkt_attr,
                                   inq_pkt_byte_en,
                                   inq_pkt_fmt,
                                   inq_pkt_type,
                                   s_inq_pkt_addr
                                                              } ),
    .clk_pop                    ( core_clk                      ),
    .rst_pop_n                  ( core_rst_n                    ),
    .cfg_ras_correct            (cfg_ras_recc_ob_pdcmp_hdr_correct        ),
    .ras_recc_corr_cnt_pulse    (axi_ras_recc_corr_cnt_ob_pdcmp_hdr_pulse ),
    .ras_recc_ucorr_cnt_pulse   (axi_ras_recc_ucorr_cnt_ob_pdcmp_hdr_pulse),
    .ras_recc_cnt_addr          (axi_ras_recc_cnt_ob_pdcmp_hdr_addr       ),
    .recc_cnt_ras_dp_err_log    (axi_recc_cnt_ob_pdcmp_hdr_ras_dp_err_log ),
    .ras_dp_err_inj             (axi_bridge_ras_dp_err_inj_core_clk),
    .ready                      ( outq_hf_ready                 ),
    .asfifo_wen                 ( pdcmp_hdr_ram_wea             ),
    .asfifo_waddr               ( pdcmp_hdr_ram_addra           ),
    .asfifo_wdata               ( pdcmp_hdr_ram_dina            ),
    .asfifo_raddr               ( pdcmp_hdr_ram_addrb           ),
    .asfifo_ren                 ( pdcmp_hdr_ram_enb             ),
    .rdata                      ( pdcmp_hdr_ram_doutb           ),
    .asfifo_f                   ( /*UNCONNECTED*/               ),
    .asfifo_af                  ( hf_pkt_halt                   ),
    .asfifo_pop_data            ( {
                                   hf_pkt_prfx,
                                   hf_pkt_p_tag,
                                   hf_pkt_th,
                                   hf_pkt_ph,
                                   hf_pkt_st,
                                   hf_pkt_atu_bypass,
                                   hf_pkt_dst_segment,
                                   hf_pkt_ats,
                                   hf_pkt_nw,
                                   hf_pkt_null,
                                   hf_pkt_last_tlp,
                                   hf_pkt_axi_id,
                                   hf_pkt_cpl_stat_0b,
                                   hf_pkt_byte_len,
                                   hf_pkt_tc,
                                   hf_pkt_ep,
                                   hf_pkt_silentDrop,
                                   hf_pkt_attr,
                                   hf_pkt_byte_en,
                                   hf_pkt_fmt,
                                   hf_pkt_type,
                                   hf_pkt_addr
                                                              } ),
    .asfifo_pop_valid           ( hf_pkt_valid                  ),
    .asfifo_e                   (                               )
   );

assign hf_pkt_cpl_stat = {2'b00,hf_pkt_cpl_stat_0b};

  // generate parity bits and interleave them after RAM pop
  assign s_hf_pkt_addr = fn_addr_w_par(hf_pkt_addr);

   wire   inq_pkt_chk_en;
   assign inq_pkt_chk_en = inq_pkt_dv & !fifo_pkt_halt;


 // Mask data for the sake of parity check. inq_pkt_data come from up convert
 // block that may contain invalid/corrupted data from previous transfers.
 assign s_inq_pkt_data_strb = fn_data_strobed(inq_pkt_data,inq_pkt_strb);

  ras_dp_pipe
   #(
   .PIPELINE_TYPE             (0                                     ),
   .RESETVAL                  (0                                     ),
   .N_STAGES                  (0                                     ),
   .CAN_STALL                 (0                                     ),
   .RESET_STALL               (0                                     ),
   .BUS_PROTECT_GEN_EN        (0                                     ),
   .BUS_PROTECT_CHK_EN        (1                                     ),
   .PROT_TYPE                 (1                                     ), // 0: Parity
   .PROT_RANGE                (CX_RAS_PROT_RANGE                     ),
   .PROT_WD                   (NUM_DATA_PAR_BLOCKS                   ),
   .PARITY_MODE               (CX_RAS_PARITY_MODE                    ),
   .PROT_CORRECT_EN           (0                                     ),
   .TOTAL_WIDTH               (CC_PRF_TLP_DATA_WIDTH_NP              ),
   .EXCLUDE_PROT_WIDTH        (0                                     ),
   .RAS_DP_PROT_CHK_ID_BASE   (`PDCMP_INQ_DT_RAS_ID                  )
 ) u_data_chk (
   .clk                       ( slv_aclk                             ),
   .rst_n                     ( slv_aresetn                          ),
   .din                       ( fn_data_wo_par  (s_inq_pkt_data_strb)),
   .din_prot                  ( fn_prot_chkin_dt(s_inq_pkt_data_strb)),
   .dout                      (                                      ),
   .dout_prot                 (                                      ),
   .en                        (1'b1                                  ),
   .bypass                    (1'b0                                  ),
   .stall                     (1'b0                                  ),
   .stallout                  (                                      ),
   .valid_in                  ( inq_pkt_dv                           ),
   .halt_out                  (                                      ),
   .valid_out                 (                                      ),
   .halt_in                   (1'b0                                  ),
   .ras_dp_err_inband_kbd_in  (1'b0                                  ),
   .ras_dp_err_inband_kbd_out (                                      ),
   .ras_dp_err_log            ( pdcmp_inq_dt_ras_dp_err_log          )
     ,
     .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk      )
   );

 assign pdcmp_inq_data_parerr = pdcmp_inq_dt_ras_dp_err_log.valid;
  // strip out parity bits before push it into the RAM
  assign s_inq_pkt_data = fn_data_wo_par(inq_pkt_data);

// Data fifo instantiation
// ---------------------------------------------------------------------------------------------------------------------
DWC_pcie_bridge_async_fifo_ram_latency

  #(
    .DATA_WIDTH                 ( CC_OB_PDCMP_DATA_RAM_DATA_WD_NOECC  ),
    .ECC_WIDTH                  (CC_OB_PDCMP_DATA_RAM_DATA_WD - CC_OB_PDCMP_DATA_RAM_DATA_WD_NOECC),
    .CX_RAS_RAM_PROT_RANGE      (CX_RAS_RAM_PROT_RANGE),
    .DEPTH                      ( CC_OB_PDCMP_DATA_RAM_DP       ),
    .RAM_ADDR_WIDTH             ( CC_OB_PDCMP_DATA_RAM_ADDR_WD  ),
    .COUNT_WIDTH                ( CC_OB_PDCMP_DATA_RAM_PTR_WD   ),
    .PUSH_SYNC                  ( SYNC_DEPTH                    ),
    .POP_SYNC                   ( SYNC_DEPTH                    ),
    .RAS_DP_ID                  (`OB_PDCMP_RAS_ID               ),
    .RAM_RD_LATENCY             ( CC_OB_PDCMP_RAM_RD_LATENCY    )
   )
   u_df
   (
    .clk_push                   ( slv_aclk                      ),
    .rst_push_n                 ( slv_aresetn                   ),
    .push_req_n                 ( !inq_pkt_dv || fifo_pkt_halt  ),
    .push_data                  ( s_inq_pkt_data                ),
    .clk_pop                    ( core_clk                      ),
    .rst_pop_n                  ( core_rst_n                    ),
    .cfg_ras_correct            (cfg_ras_recc_ob_pdcmp_data_correct        ),
    .ras_recc_corr_cnt_pulse    (axi_ras_recc_corr_cnt_ob_pdcmp_data_pulse ),
    .ras_recc_ucorr_cnt_pulse   (axi_ras_recc_ucorr_cnt_ob_pdcmp_data_pulse),
    .ras_recc_cnt_addr          (axi_ras_recc_cnt_ob_pdcmp_data_addr       ),
    .recc_cnt_ras_dp_err_log    (axi_recc_cnt_ob_pdcmp_ras_dp_err_log      ),
    .ras_dp_err_inj             (axi_bridge_ras_dp_err_inj_core_clk),
    .ready                      ( outq_df_ready                 ),
    .asfifo_wen                 ( pdcmp_data_ram_wea            ),
    .asfifo_waddr               ( pdcmp_data_ram_addra          ),
    .asfifo_wdata               ( pdcmp_data_ram_dina           ),
    .asfifo_raddr               ( pdcmp_data_ram_addrb          ),
    .asfifo_ren                 ( pdcmp_data_ram_enb            ),
    .rdata                      ( pdcmp_data_ram_doutb          ),
    .asfifo_f                   ( df_pkt_halt                   ),
    .asfifo_af                  ( /*UNCONNECTED*/               ),
    .asfifo_pop_data            ( df_pkt_data                   ),
    .asfifo_pop_valid           ( df_pkt_valid                  ),
    .asfifo_e                   (                               )
   );


  // generate parity bits and interleave them after RAM pop
  assign s_df_pkt_data = fn_data_w_par(df_pkt_data);

assign fifo_pkt_halt = df_pkt_halt || hf_pkt_halt;


// Output queue instantiation
// ---------------------------------------------------------------------------------------------------------------------
DWC_pcie_bridge_ob_p_dcmp_outq

   u_outq
   (
    .core_clk                   ( core_clk                      ),
    .core_rst_n                 ( core_rst_n                    ),
    .cfg_tc_struc_vc_map        ( cfg_tc_struc_vc_map           ),
    .hf_pkt_prfx                ( hf_pkt_prfx                   ),
    .hf_pkt_p_tag               ( hf_pkt_p_tag                  ),
    .hf_pkt_th                  ( hf_pkt_th                     ),
    .hf_pkt_ph                  ( hf_pkt_ph                     ),
    .hf_pkt_st                  ( hf_pkt_st                     ),
    .hf_pkt_atu_bypass          ( hf_pkt_atu_bypass             ),
    .hf_pkt_dst_segment         ( hf_pkt_dst_segment            ),
    .hf_pkt_ats                 ( hf_pkt_ats                    ),
    .hf_pkt_nw                  ( hf_pkt_nw                     ),
    .hf_pkt_null                ( hf_pkt_null                   ),
    .hf_pkt_last_tlp            ( hf_pkt_last_tlp               ),
    .hf_pkt_axi_id              ( hf_pkt_axi_id                 ),
    .hf_pkt_cpl_stat            ( hf_pkt_cpl_stat               ),
    .hf_pkt_byte_len            ( hf_pkt_byte_len               ),
    .hf_pkt_tc                  ( hf_pkt_tc                     ),
    .hf_pkt_ep                  ( hf_pkt_ep                     ),
    .hf_pkt_silentDrop          ( hf_pkt_silentDrop             ),
    .hf_pkt_attr                ( hf_pkt_attr                   ),
    .hf_pkt_byte_en             ( hf_pkt_byte_en                ),
    .hf_pkt_fmt                 ( hf_pkt_fmt                    ),
    .hf_pkt_type                ( hf_pkt_type                   ),
    .hf_pkt_addr                ( s_hf_pkt_addr                 ),
    .df_pkt_data                ( s_df_pkt_data                 ),

    .outq_hf_ready              ( outq_hf_ready                 ),
    .outq_df_ready              ( outq_df_ready                 ),
    .hf_pkt_valid               ( hf_pkt_valid                  ),
    .df_pkt_valid               ( df_pkt_valid                  ),
    .dwnstrm_halt               ( dwnstrm_halt                  ),

    .outq_pkt_hv                ( outq_hv                       ),
    .outq_pkt_dv                ( outq_dv                       ),
    .outq_pkt_eot               ( outq_eot                      ),
    .outq_pkt_prfx              ( outq_prfx                     ),
    .outq_pkt_p_tag             ( outq_p_tag                    ),
    .outq_pkt_th                ( outq_th                       ),
    .outq_pkt_ph                ( outq_ph                       ),
    .outq_pkt_st                ( outq_st                       ),
    .outq_pkt_atu_bypass        ( outq_atu_bypass               ),
    .outq_pkt_dst_segment       ( outq_dst_segment              ),
    .outq_pkt_ats               ( outq_ats                      ),
    .outq_pkt_nw                ( outq_nw                       ),
    .outq_pkt_func_num          ( outq_func_num                 ),
    .outq_pkt_cpl_stat          ( outq_cpl_stat                 ),
    .outq_pkt_byte_len          ( outq_byte_len                 ),
    .outq_pkt_tc                ( outq_tc                       ),
    .outq_pkt_ep                ( outq_ep                       ),
    .outq_pkt_silentDrop        ( outq_silentDrop               ),
    .outq_pkt_attr              ( outq_attr                     ),
    .outq_pkt_byte_en           ( outq_byte_en                  ),
    .outq_pkt_fmt               ( outq_fmt                      ),
    .outq_pkt_type              ( outq_type                     ),
    .outq_pkt_addr              ( outq_addr                     ),
    .outq_pkt_data              ( outq_data                     ),
    .outq_pkt_p_rsp_valid       ( outq_p_rsp_valid              ),
     .outq_pkt_p_rsp_null_or_err( outq_p_rsp_null_or_err        ),
     .outq_pkt_p_rsp_last       ( outq_p_rsp_last               ),
     .outq_pkt_p_rsp_vc_num     ( outq_p_rsp_vc_num             ),
    .outq_pkt_p_rsp_id          ( outq_p_rsp_id                 ),
    .outq_pkt_p_rsp_cpl_stat    ( outq_p_rsp_cpl_stat           )
    );



  assign dwnstrm_halt   = xadm_client2_halt;

  assign pdcmp_hv     = outq_hv;
  assign pdcmp_dv     = outq_dv;
  assign pdcmp_eot    = outq_eot;
  assign pdcmp_data   = outq_data;


  assign pdcmp_prfx = outq_prfx;
  assign pdcmp_p_tag= outq_p_tag;
  assign pdcmp_th   = outq_th;
  assign pdcmp_ph   = outq_ph;
  assign pdcmp_st   = outq_st;
  assign pdcmp_atu_bypass =  outq_atu_bypass;
  assign pdcmp_dst_segment = outq_dst_segment;
  assign pdcmp_ats        = outq_ats;
  assign pdcmp_nw         = outq_nw;
  assign pdcmp_func_num     = outq_func_num;
  assign pdcmp_byte_len     = outq_byte_len;
  assign pdcmp_tc           = outq_tc;
  assign pdcmp_ep           = outq_ep;
  assign pdcmp_silentDrop   = outq_silentDrop;
  assign pdcmp_attr         = outq_attr;
  assign pdcmp_byte_en      = outq_byte_en ;
  assign pdcmp_fmt          = outq_fmt;
  assign pdcmp_type         = outq_type;
  assign pdcmp_addr = outq_addr;


// -------------------------------------------------------------------------------------
// Posted TLP write Response interface
// -------------------------------------------------------------------------------------
  assign pdcmp_p_rsp_valid    = outq_p_rsp_valid && pdcmp_hv && (!xadm_client2_halt);
  assign pdcmp_p_rsp_id       = outq_p_rsp_id;
  assign pdcmp_p_rsp_cpl_stat = outq_p_rsp_cpl_stat;
  assign pdcmp_p_rsp_null_or_err = outq_p_rsp_null_or_err;
  assign pdcmp_p_rsp_last     = outq_p_rsp_last;
  assign pdcmp_p_rsp_vc_num   = outq_p_rsp_vc_num;


  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  // Address without parity
  function automatic [SLAVE_BUS_ADDR_WIDTH-1:0] fn_addr_wo_par;
    input [CC_SLV_BUS_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i;
    reg [NUM_ADDR_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE:0]   i_addr_w_par;
    reg [NUM_ADDR_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE-1:0] i_addr_wo_par;
    begin
      i_addr_w_par = s_addr_w_par;
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1)  begin // iterate thru parity block size
        i_addr_wo_par[i] = i_addr_w_par[i][CX_RAS_PROT_RANGE-1:0];
      end
      fn_addr_wo_par = i_addr_wo_par;
    end
  endfunction

// Data without parity
  function automatic [CC_PRF_TLP_DATA_WIDTH_NP-1:0] fn_data_wo_par;
    input [CC_PRF_TLP_DATA_WIDTH-1:0] s_data_w_par;
    integer i;
    reg [NUM_DATA_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE:0]   i_data_w_par;
    reg [NUM_DATA_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE-1:0] i_data_wo_par;
    begin
      i_data_w_par = s_data_w_par;
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
        i_data_wo_par[i] = i_data_w_par[i][CX_RAS_PROT_RANGE-1:0];
      end
      fn_data_wo_par = i_data_wo_par;
    end
  endfunction

  // Data with parity
  function automatic [CC_PRF_TLP_DATA_WIDTH-1:0] fn_data_w_par;
    input [CC_PRF_TLP_DATA_WIDTH_NP-1:0] s_data_wo_par;

    integer i;
    reg [NUM_DATA_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE-1:0] i_data_wo_par;
    reg [NUM_DATA_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE:0]   i_data_w_par;
    reg parity_bit;

    begin
      i_data_wo_par = s_data_wo_par;
      for (i=0; i<(NUM_DATA_PAR_BLOCKS); i=i+1) begin
        parity_bit = CX_RAS_PARITY_MODE ? ~(^(i_data_wo_par[i])) : ^(i_data_wo_par[i]);
        i_data_w_par[i] = {parity_bit,i_data_wo_par[i]};
      end
      fn_data_w_par = i_data_w_par;
    end
  endfunction

  // Address with parity
  function automatic [CC_SLV_BUS_ADDR_WIDTH-1:0] fn_addr_w_par;
    input [SLAVE_BUS_ADDR_WIDTH-1:0] s_addr_wo_par;

    integer i;
    reg [NUM_ADDR_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE-1:0] i_addr_wo_par;
    reg [NUM_ADDR_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE:0]   i_addr_w_par;
    reg parity_bit;

    begin
      i_addr_wo_par = s_addr_wo_par;
      for (i=0; i<(NUM_ADDR_PAR_BLOCKS); i=i+1) begin
        parity_bit = CX_RAS_PARITY_MODE ? ~(^(i_addr_wo_par[i])) : ^(i_addr_wo_par[i]);
        i_addr_w_par[i] = {parity_bit,i_addr_wo_par[i]};
      end
      fn_addr_w_par = i_addr_w_par;
    end
  endfunction

 function automatic [CC_PRF_TLP_DATA_WIDTH-1:0] fn_data_strobed;
   input [CC_PRF_TLP_DATA_WIDTH-1:0] pkt_data;
   input [CC_PRF_TLP_NUM_WSTRBS-1:0] pkt_strb;

   integer i;
   reg [CC_PRF_TLP_NUM_WSTRBS-1:0][BITS_PER_STRB-1:0] i_pkt_data;
   reg [CC_PRF_TLP_NUM_WSTRBS-1:0][BITS_PER_STRB-1:0] i_data_strobed;

   begin

     i_pkt_data     = pkt_data;
     i_data_strobed = {NUM_DATA_PAR_BLOCKS{BUS_INIT_BYTE}};

     for (i=0; i<(CC_PRF_TLP_NUM_WSTRBS); i=i+1) begin
       if(pkt_strb[i]==1) begin
         i_data_strobed[i] = i_pkt_data[i];
       end
     end

     fn_data_strobed = i_data_strobed;

   end
 endfunction

 function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_dt;
    input [CC_PRF_TLP_DATA_WIDTH-1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_dt[i] = s_data_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction


`ifndef SYNTHESIS
   //--------------------------------------------------------------------
   // RAS.DP Testbench guides for error injection
   //--------------------------------------------------------------------

  `define OB_PDCMP_HDR_RAM_AD_PTR 0
  `define OB_PDCMP_HDR_RAM_AD_PTRW `SLAVE_BUS_ADDR_WIDTH
  `define OB_PDCMP_DATA_RAM_DT_PTR 0
  `define OB_PDCMP_DATA_RAM_DT_PTRW `CC_PRF_TLP_DATA_WIDTH_NP

`endif //  `ifndef SYNTHESIS

endmodule

