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
// ---    $Revision: #22 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_bridge_ob_np_dcmp.sv#22 $
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

`include "DWC_pcie_ctl_pkg.svh"

 module DWC_pcie_bridge_ob_np_dcmp
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_AXI_BRIDGE;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 (

    slv_aclk,
    slv_aresetn,
    core_clk,
    core_rst_n,
    cfg_ras_recc_ob_npdcmp_correct,
    axi_ras_recc_corr_cnt_ob_npdcmp_pulse,
    axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse,
    axi_ras_recc_cnt_ob_npdcmp_addr,
    axi_recc_cnt_ob_npdcmp_ras_dp_err_log,
    // Configuration interface
    cfg_ext_tag_en,
    cfg_10b_tag_en,
    cfg_max_rd_req_size,
    cfg_ax_snp_en,

    // Request packet interface
    npdcmp_halt,
    nprf_hv,
    nprf_dv,
    nprf_eot,
    nprf_bad_eot,
    nprf_tlp_prfx,
    nprf_th,
    nprf_ph,
    nprf_st,
    nprf_atu_bypass,
    nprf_dst_segment,
    nprf_ats,
    nprf_nw,
    nprf_first_wrp_split_xact,
    nprf_wrp_valid,
    nprf_snp,
    nprf_tag,
    nprf_id,
    nprf_cpl_stat,
    nprf_byte_len,
    nprf_tc,
    nprf_ep,
    nprf_attr,
    nprf_be,
    nprf_fmt,
    nprf_type,
    nprf_addr,
    nprf_data,

  // Completion interface
    ibrtr_inbd_hv,
    ibrtr_inbd_tag,
    ibrtr_inbd_last,
    ibrtr_inbd_dllp_abort,
    ibrtr_inbd_tlp_abort,
    ibrtr_inbd_eot,
  // Timeout interface
    radm_cpl_timeout,
    radm_timeout_cpl_tag,

    client1_halt,
    npdcmp_hv,
    npdcmp_dv,
    npdcmp_eot,
    npdcmp_tlp_prfx,
    npdcmp_th,
    npdcmp_ph,
    npdcmp_st,
    npdcmp_atu_bypass,
    npdcmp_dst_segment,
    npdcmp_ats,
    npdcmp_nw,
    npdcmp_func_num,
    npdcmp_last_tlp,
    npdcmp_4rd,
    npdcmp_req_byte_len,
    npdcmp_out_tag,
    npdcmp_in_tag,
    npdcmp_axi_id,
    npdcmp_byte_len,
    npdcmp_tc,
    npdcmp_ep,
    npdcmp_attr,
    npdcmp_byte_en,
    npdcmp_fmt,
    npdcmp_type,
    npdcmp_addr,
    npdcmp_data,
    npdcmp_cpl_stat,
   // Non Posted Atomic Response Interface
   npdcmp_np_atomic_rsp_valid,
   npdcmp_np_atomic_rsp_id,
    npdcmp_ram_addra,
    npdcmp_ram_addrb,
    npdcmp_ram_wea,
    npdcmp_ram_enb,
    npdcmp_ram_doutb,
    npdcmp_ram_dina,

    npdcmp_addr_parerr,
    npdcmp_inq_data_parerr,
    npdcmp_inq_dt_ras_dp_err_log,
    npdcmp_ad_ras_dp_err_log,
    ras_dp_err_inj_slv_aclk,
    axi_bridge_ras_dp_err_inj_core_clk,

    slv_lookup_apptag,
    slv_pop_wiretag,
    slv_lookup_wiretag,
    slv_lookup_wiretag_is_last,

    rdr_lookup_wiretag,
    rdr_pop_wiretag,

    rls_tag,
    rls_tag_num,
    cmp_sb_init_done,

    s_wtag_active_lut
   );

parameter  TP                                = `TP;

localparam CC_SLV_BUS_ADDR_WIDTH             = `CC_SLV_BUS_ADDR_WIDTH;
localparam SLAVE_BUS_ADDR_WIDTH              = `SLAVE_BUS_ADDR_WIDTH;

localparam SLV_BUS_NPDATA_WIDTH              = `CC_SLV_BUS_NPDATA_WIDTH;
localparam SLV_BUS_NPDATA_WIDTH_NP           = `CC_SLV_BUS_NPDATA_WIDTH_NP;

localparam CC_SLV_BUS_ID_WIDTH               = `CC_SLV_BUS_ID_WIDTH;
localparam CC_SLV_RD_REQ_SIZE_PW             = `CC_SLV_RD_REQ_SIZE_PW;
localparam CC_CORE_DATA_BUS_WD               = `CC_CORE_DATA_BUS_WD;
localparam CC_CORE_ADDR_BUS_WD               = 72;
localparam PCIE_CORE_DATA_BUS_WD             = `PCIE_CORE_DATA_BUS_WD;
localparam CX_TAG_SIZE                       = `CX_TAG_SIZE;
localparam CC_MAX_SLV_TAG_PW                 = `CC_MAX_SLV_TAG_PW;

// Tag management parameters
localparam MAX_WIRE_5BIT_TAG                 = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_5BIT_TAG_HIGH        : (`CX_MAX_TAG        > 31   ? 31   : `CX_MAX_TAG      );
localparam MAX_WIRE_5BIT_TAG_PW              = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_5BIT_TAG_HIGH_WIDTH  : (`CX_LUT_PTR_WIDTH  > 5    ? 5    : `CX_LUT_PTR_WIDTH);
localparam MAX_WIRE_8BIT_TAG                 = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_8BIT_TAG_HIGH        : (`CX_MAX_TAG        > 255  ? 255  : `CX_MAX_TAG      );
localparam MAX_WIRE_8BIT_TAG_PW              = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_8BIT_TAG_HIGH_WIDTH  : (`CX_LUT_PTR_WIDTH  > 8    ? 8    : `CX_LUT_PTR_WIDTH);
localparam MAX_WIRE_10BIT_TAG                = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_10BIT_TAG_HIGH       :  `CX_MAX_TAG;
localparam MAX_WIRE_10BIT_TAG_PW             = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_10BIT_TAG_HIGH_WIDTH :  10;
localparam MAX_WIRE_TAG_PW                   = MAX_WIRE_10BIT_TAG_PW;
localparam MAX_WIRE_TAG                      = MAX_WIRE_10BIT_TAG;

localparam CX_NFUNC                          = `CX_NFUNC;
localparam CX_NFUNC_WD                       = `CX_NFUNC_WD;
localparam CX_NVFUNC_WD                      = `CX_NVFUNC_WD;
localparam DC_CPL_STATUS_WD                  = `DC_CPL_STATUS_WD;
localparam CC_SLV_MTU_PW                     = `CC_SLV_MTU_PW;
localparam FIFO_BYTE_LEN_WD                  = `CC_SLV_MTU_PW < (`CC_SLV_RD_REQ_SIZE_PW+1) ? `CC_SLV_MTU_PW : `CC_SLV_RD_REQ_SIZE_PW;
localparam SYNC_DEPTH                        = `CX_PCIE_SYNC_DEPTH;
localparam DCMP_PREFIX_WD                    = (32*`CX_NPRFX)+ `CX_PRFX_PAR_WD;
localparam CC_OB_NPDCMP_RAM_DP               = `CC_OB_NPDCMP_RAM_DP;
localparam CC_OB_NPDCMP_RAM_ADDR_WD          = `CC_OB_NPDCMP_RAM_ADDR_WD;
localparam CC_OB_NPDCMP_RAM_DATA_WD          = `CC_OB_NPDCMP_RAM_DATA_WD;
localparam CC_OB_NPDCMP_RAM_DATA_WD_NOECC    = `CC_OB_NPDCMP_RAM_DATA_WD_NOECC;
localparam CC_OB_NPDCMP_RAM_PTR_WD           = `CC_OB_NPDCMP_RAM_PTR_WD;
localparam ADDR_PAR_WD                       = `CX_ADDR_PAR_WD;
localparam CC_OB_NPDCMP_RAM_RD_LATENCY       = `CC_OB_NPDCMP_RAM_RD_LATENCY;
localparam ATTR_WD                           = 3;

localparam NON_POSTED_WR_RESP_INTF        = `CC_SLV_BUS_ID_WIDTH;
localparam C2ANPRSP_FIFO_DEPTH            = `CC_SLV_NUM_OUTSTND_WR_REQ;
localparam C2ANPRSP_FIFO_ADDR_WD          = `CC_SLV_NUM_OUTSTND_WR_REQ_LOG2;
localparam C2ANPRSP_PUSH_AF_LVL           = 1; // one from full
localparam C2ANPRSP_POP_AE_LVL            = 1; // one from empty
localparam C2ANPRSP_RST_MODE              = 0; // Include memory reset
localparam C2ANPRSP_PUSH_AE_LVL           = 1;
localparam C2ANPRSP_POP_AF_LVL            = 1;
localparam C2ANPRSP_PUSH_SYNC             = SYNC_DEPTH;
localparam C2ANPRSP_POP_SYNC              = SYNC_DEPTH;
localparam C2ANPRSP_HOLD_RD_ADDR          = 0;
// Sticky error flag
localparam C2ANPRSP_ERR_MODE              = 1'b0;

localparam CX_RAS_RAM_PROT_RANGE             = `CX_RAS_RAM_PROT_RANGE;
localparam CX_RAS_PROT_RANGE                 = `CX_RAS_PROT_RANGE;
localparam CX_RAS_PARITY_MODE                = `CX_RAS_PARITY_MODE;
// Number of parity address blocks per 32/64 bit address
localparam NUM_ADDR_PAR_BLOCKS               = SLAVE_BUS_ADDR_WIDTH/CX_RAS_PROT_RANGE;
// Number of parity data blocks for a single dword
localparam NUM_DATA_PAR_BLOCKS               = SLV_BUS_NPDATA_WIDTH_NP/CX_RAS_PROT_RANGE;
localparam RAS_DP_ERR_LOG_WD                 = $clog2(MAX_RAS_PROT_CHK_N);

localparam [8:0] APPEND_BYTE                 = `CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;

localparam NUM_ADDR_APPEND_BYTE              = ( 64 - SLAVE_BUS_ADDR_WIDTH ) / 8;
localparam NUM_DATA_APPEND_BYTE              = ( PCIE_CORE_DATA_BUS_WD <= SLV_BUS_NPDATA_WIDTH_NP ) ? 0 : ( PCIE_CORE_DATA_BUS_WD - SLV_BUS_NPDATA_WIDTH_NP ) / 8;

// Port declaration
// ---------------------------------------------------------------------------------------------------------------------
input  wire                                  slv_aclk;
input  wire                                  slv_aresetn;
input  wire                                  core_clk;
input  wire                                  core_rst_n;
input                                        cfg_ras_recc_ob_npdcmp_correct;
output wire                                  axi_ras_recc_corr_cnt_ob_npdcmp_pulse;
output wire                                  axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse;
output wire [CC_OB_NPDCMP_RAM_ADDR_WD-1:0]   axi_ras_recc_cnt_ob_npdcmp_addr;
output wire                                  npdcmp_inq_data_parerr;
output ras_dp_err_log_t                      axi_recc_cnt_ob_npdcmp_ras_dp_err_log;
output ras_dp_err_log_t                      npdcmp_inq_dt_ras_dp_err_log;
input  ras_dp_err_inj_t                      ras_dp_err_inj_slv_aclk;
input  ras_dp_err_inj_t                      axi_bridge_ras_dp_err_inj_core_clk;
    // Configuration interface
input  wire                                  cfg_ext_tag_en;
input  wire                                  cfg_10b_tag_en;
input  wire [(3*CX_NFUNC) -1:0]              cfg_max_rd_req_size;
input  wire                                  cfg_ax_snp_en;

    // Request packet interface
output wire                                  npdcmp_halt;
input  wire                                  nprf_hv;
input  wire                                  nprf_dv;
input  wire                                  nprf_eot;
input  wire                                  nprf_bad_eot;
input  wire [DCMP_PREFIX_WD-1:0]             nprf_tlp_prfx;
input  wire                                  nprf_th;
input  wire [1:0]                            nprf_ph;
input  wire [7:0]                            nprf_st;
input  wire                                  nprf_atu_bypass;
input  wire [8:0]                            nprf_dst_segment;
input  wire [1:0]                            nprf_ats;
input  wire                                  nprf_nw;
input wire                                   nprf_first_wrp_split_xact;
input wire                                   nprf_wrp_valid;
input  wire                                  nprf_snp;
input  wire [CC_MAX_SLV_TAG_PW-1:0]          nprf_tag;
input  wire [CC_SLV_BUS_ID_WIDTH:0]          nprf_id;
input  wire [DC_CPL_STATUS_WD-1:0]           nprf_cpl_stat;
input  wire [CC_SLV_MTU_PW-1:0]              nprf_byte_len;
input  wire [2:0]                            nprf_tc;
input  wire                                  nprf_ep;
input  wire [ATTR_WD-1:0]                    nprf_attr;
input  wire [7:0]                            nprf_be;
input  wire [1:0]                            nprf_fmt;
input  wire [4:0]                            nprf_type;
input  wire [CC_SLV_BUS_ADDR_WIDTH-1:0]      nprf_addr;
input  wire [SLV_BUS_NPDATA_WIDTH-1:0]       nprf_data;
input  wire                                  ibrtr_inbd_hv;
input  wire [MAX_WIRE_TAG_PW-1:0]            ibrtr_inbd_tag;
input  wire                                  ibrtr_inbd_last;
input  wire                                  ibrtr_inbd_dllp_abort;
input  wire                                  ibrtr_inbd_tlp_abort;
input  wire                                  ibrtr_inbd_eot;
input  wire                                  radm_cpl_timeout;
input  wire [CX_TAG_SIZE-1:0]                radm_timeout_cpl_tag;
input  wire                                  client1_halt;
output wire                                  npdcmp_hv;
output wire                                  npdcmp_dv;
output wire                                  npdcmp_eot;
output wire [DCMP_PREFIX_WD-1:0]             npdcmp_tlp_prfx;
output wire                                  npdcmp_th;
output wire [1:0]                            npdcmp_ph;
output wire [7:0]                            npdcmp_st;
output wire                                  npdcmp_atu_bypass;
output wire [8:0]                            npdcmp_dst_segment;
output wire [1:0]                            npdcmp_ats;
output wire                                  npdcmp_nw;
output wire [CX_NFUNC_WD-1:0]                npdcmp_func_num;
output wire                                  npdcmp_last_tlp;
output wire                                  npdcmp_4rd;
output wire [CC_SLV_MTU_PW-1:0]              npdcmp_req_byte_len;
output wire [MAX_WIRE_TAG_PW-1:0]            npdcmp_out_tag;
output wire [CC_MAX_SLV_TAG_PW-1:0]          npdcmp_in_tag;
output wire [CC_SLV_BUS_ID_WIDTH:0]          npdcmp_axi_id;
output wire [12:0]                           npdcmp_byte_len;
output wire [2:0]                            npdcmp_tc;
output wire                                  npdcmp_ep;
output wire [ATTR_WD-1:0]                    npdcmp_attr;
output wire [7:0]                            npdcmp_byte_en;
output wire [1:0]                            npdcmp_fmt;
output wire [4:0]                            npdcmp_type;
output wire [CC_CORE_DATA_BUS_WD-1:0]        npdcmp_data;
output wire [63+ADDR_PAR_WD:0]               npdcmp_addr;
output wire [DC_CPL_STATUS_WD-1:0]           npdcmp_cpl_stat;
// Non Posted Atomic Response Interface
output wire                                  npdcmp_np_atomic_rsp_valid;
output wire [CC_SLV_BUS_ID_WIDTH-1:0]        npdcmp_np_atomic_rsp_id;
output wire [CC_OB_NPDCMP_RAM_ADDR_WD-1:0]   npdcmp_ram_addra;
output wire [CC_OB_NPDCMP_RAM_ADDR_WD-1:0]   npdcmp_ram_addrb;
output wire                                  npdcmp_ram_wea;
output wire                                  npdcmp_ram_enb;
input  wire [CC_OB_NPDCMP_RAM_DATA_WD-1:0]   npdcmp_ram_doutb;
output wire [CC_OB_NPDCMP_RAM_DATA_WD-1:0]   npdcmp_ram_dina;
output wire                                  npdcmp_addr_parerr;
output ras_dp_err_log_t                      npdcmp_ad_ras_dp_err_log;

input  wire [CC_MAX_SLV_TAG_PW-1:0]          slv_lookup_apptag;
input  wire                                  slv_pop_wiretag;
output wire [MAX_WIRE_TAG_PW-1:0]            slv_lookup_wiretag;
output wire                                  slv_lookup_wiretag_is_last;

input  wire [MAX_WIRE_TAG_PW-1:0]            rdr_lookup_wiretag;
input  wire                                  rdr_pop_wiretag;

input  wire                                  rls_tag;
input  wire [MAX_WIRE_TAG_PW-1:0]            rls_tag_num;
input  wire                                  cmp_sb_init_done;
output wire [MAX_WIRE_TAG:0]                 s_wtag_active_lut;

// In queue output wire declaration
// ---------------------------------------------------------------------------------------------------------------------
wire                                         inq_pkt_hv;
wire                                         inq_pkt_dv;
wire                                         inq_pkt_eot;
wire                                         inq_pkt_bad_eot;
wire        [DCMP_PREFIX_WD-1:0]             inq_pkt_tlp_prfx;
wire                                         inq_pkt_th;
wire        [1:0]                            inq_pkt_ph;
wire        [7:0]                            inq_pkt_st;
wire                                         inq_pkt_atu_bypass;
wire        [8:0]                            inq_pkt_dst_segment;
wire        [1:0]                            inq_pkt_ats;
wire                                         inq_pkt_nw;
wire                                         inq_pkt_first_wrp_split_xact;
wire                                         inq_pkt_wrp_valid;
wire                                         inq_pkt_last_tlp;
wire                                         inq_pkt_dcmp_rd;
wire                                         inq_pkt_serial_req;
wire        [CC_SLV_MTU_PW-1:0]              inq_pkt_req_byte_len;
wire        [DC_CPL_STATUS_WD-1:0]           inq_pkt_cpl_stat;
wire        [FIFO_BYTE_LEN_WD-1:0]           inq_pkt_byte_len;
wire        [CC_MAX_SLV_TAG_PW-1:0]          inq_pkt_in_tag;
wire        [CC_SLV_BUS_ID_WIDTH:0]          inq_pkt_axi_id;
wire        [2:0]                            inq_pkt_tc;
wire                                         inq_pkt_ep;
wire        [ATTR_WD-1:0]                    inq_pkt_attr;
wire        [7:0]                            inq_pkt_byte_en;
wire        [1:0]                            inq_pkt_fmt;
wire        [4:0]                            inq_pkt_type;
wire        [CC_SLV_BUS_ADDR_WIDTH-1:0]      inq_pkt_addr;
wire        [SLAVE_BUS_ADDR_WIDTH-1:0]       s_inq_pkt_addr;
wire        [SLV_BUS_NPDATA_WIDTH-1:0]       inq_pkt_data;
wire        [SLV_BUS_NPDATA_WIDTH_NP-1:0]    s_inq_pkt_data;

// Tag queue output wire declarations
// ---------------------------------------------------------------------------------------------------------------------
wire                                         tagq_pkt_hv;
wire                                         tagq_pkt_dv;
wire                                         tagq_pkt_eot;
wire                                         tagq_pkt_bad_eot;
wire        [DCMP_PREFIX_WD-1:0]             tagq_pkt_tlp_prfx;
wire                                         tagq_pkt_th;
wire        [1:0]                            tagq_pkt_ph;
wire        [7:0]                            tagq_pkt_st;
wire                                         tagq_pkt_atu_bypass;
wire        [8:0]                            tagq_pkt_dst_segment;
wire        [1:0]                            tagq_pkt_ats;
wire                                         tagq_pkt_nw;
wire                                         tagq_pkt_last_tlp;
wire                                         tagq_pkt_dcmp_rd;
wire                                         tagq_pkt_serial_req;
wire        [CC_SLV_MTU_PW-1:0]              tagq_pkt_req_byte_len;
wire        [FIFO_BYTE_LEN_WD-1:0]           tagq_pkt_byte_len;
wire        [CC_MAX_SLV_TAG_PW-1:0]          tagq_pkt_in_tag;
wire        [MAX_WIRE_TAG_PW-1:0]            tagq_pkt_out_tag;
wire        [CC_SLV_BUS_ID_WIDTH:0]          tagq_pkt_axi_id;
wire        [2:0]                            tagq_pkt_tc;
wire                                         tagq_pkt_ep;
wire        [ATTR_WD-1:0]                    tagq_pkt_attr;
wire        [7:0]                            tagq_pkt_byte_en;
wire        [1:0]                            tagq_pkt_fmt;
wire        [4:0]                            tagq_pkt_type;
wire        [SLAVE_BUS_ADDR_WIDTH -1:0]      tagq_pkt_addr;
wire        [SLV_BUS_NPDATA_WIDTH_NP-1:0]    tagq_pkt_data;

wire                          slv_wt_assigned_valid   ;
wire [CC_MAX_SLV_TAG_PW -1:0] slv_wt_assigned_apptag  ;

wire                          core_wt_assigned_valid  ;
wire [CC_MAX_SLV_TAG_PW -1:0] core_wt_assigned_apptag ;
wire [MAX_WIRE_TAG_PW   -1:0] core_wt_assigned_wiretag;


// Header and data fifo output wire declaration
// ---------------------------------------------------------------------------------------------------------------------
wire        [DCMP_PREFIX_WD-1:0]             hdf_pkt_tlp_prfx;
wire                                         hdf_pkt_th;
wire        [1:0]                            hdf_pkt_ph;
wire        [7:0]                            hdf_pkt_st;
wire                                         hdf_pkt_atu_bypass;
wire        [8:0]                            hdf_pkt_dst_segment;
wire        [1:0]                            hdf_pkt_ats;
wire                                         hdf_pkt_nw;
wire                                         hdf_pkt_first_wrp_split_xact;
wire                                         hdf_pkt_wrp_valid;
wire                                         hdf_pkt_last_tlp;
wire                                         hdf_pkt_dcmp_rd;
wire                                         hdf_pkt_serial_req;
wire        [CC_SLV_MTU_PW-1:0]              hdf_pkt_req_byte_len;
wire                                         hdf_pkt_cpl_stat_0b;
wire        [DC_CPL_STATUS_WD-1:0]           hdf_pkt_cpl_stat;
wire        [FIFO_BYTE_LEN_WD-1:0]           hdf_pkt_byte_len;
wire        [CC_MAX_SLV_TAG_PW-1:0]          hdf_pkt_in_tag;
wire        [MAX_WIRE_TAG_PW-1:0]            hdf_pkt_out_tag;
wire        [CC_SLV_BUS_ID_WIDTH:0]          hdf_pkt_axi_id;
wire        [2:0]                            hdf_pkt_tc;
wire                                         hdf_pkt_ep;
wire        [ATTR_WD-1:0]                    hdf_pkt_attr;
wire        [7:0]                            hdf_pkt_byte_en;
wire        [1:0]                            hdf_pkt_fmt;
wire        [4:0]                            hdf_pkt_type;
wire        [SLAVE_BUS_ADDR_WIDTH-1:0]       hdf_pkt_addr;
wire        [SLV_BUS_NPDATA_WIDTH_NP-1:0]    hdf_pkt_data;
wire        [CC_SLV_BUS_ADDR_WIDTH-1:0]      s_hdf_pkt_addr;
wire        [SLV_BUS_NPDATA_WIDTH-1:0]       s_hdf_pkt_data;
wire                                         hdf_pkt_valid;

// Halt signal generated from header and data FIFO
// ---------------------------------------------------------------------------------------------------------------------
wire                                         hdf_pkt_halt;

wire                                         outq_ready;
wire                                         srlzr_use_tag;

// Out queue output wire declaration
// ---------------------------------------------------------------------------------------------------------------------
wire                                         outq_pkt_hv;
wire                                         outq_pkt_dv;
wire                                         outq_pkt_eot;
wire        [DCMP_PREFIX_WD-1:0]             outq_pkt_tlp_prfx;
wire                                         outq_pkt_th;
wire        [1:0]                            outq_pkt_ph;
wire        [7:0]                            outq_pkt_st;
wire                                         outq_pkt_atu_bypass;
wire        [8:0]                            outq_pkt_dst_segment;
wire        [1:0]                            outq_pkt_ats;
wire                                         outq_pkt_nw;
wire        [CX_NFUNC_WD-1:0]                outq_pkt_func_num;
wire                                         outq_pkt_first_wrp_split_xact;
wire                                         outq_pkt_wrp_valid;
wire                                         outq_pkt_last_tlp;
wire                                         outq_pkt_4rd;
wire                                         outq_pkt_dcmp_rd;
wire                                         outq_pkt_serial_req;
wire        [CC_SLV_MTU_PW-1:0]              outq_pkt_req_byte_len;
wire        [MAX_WIRE_TAG_PW-1:0]            srlzr_out_tag;
wire        [CC_MAX_SLV_TAG_PW-1:0]          outq_pkt_in_tag;
wire        [MAX_WIRE_TAG_PW-1:0]            outq_pkt_out_tag;
wire        [CC_SLV_BUS_ID_WIDTH:0]          outq_pkt_axi_id;
wire        [12:0]                           outq_pkt_byte_len;
wire        [2:0]                            outq_pkt_tc;
wire                                         outq_pkt_ep;
wire        [ATTR_WD-1:0]                    outq_pkt_attr;
wire        [7:0]                            outq_pkt_byte_en;
wire        [1:0]                            outq_pkt_fmt;
wire        [4:0]                            outq_pkt_type;
wire        [SLV_BUS_NPDATA_WIDTH-1:0]       outq_pkt_data;
wire        [CC_SLV_BUS_ADDR_WIDTH-1:0]      outq_pkt_addr;
wire        [DC_CPL_STATUS_WD-1:0]           outq_pkt_cpl_stat;

wire                                         s_outq_pkt_hv;
wire                                         s_outq_pkt_dv;
wire                                         s_outq_pkt_eot;
wire        [63+ADDR_PAR_WD:0]               s_outq_pkt_addr;
wire        [CC_CORE_DATA_BUS_WD-1:0]        s_outq_pkt_data;


// Decomposed Non Posted TLP down converter
// -------------------------------------------------------------------------------------
wire                                        downcnvtr_pkt_hv;
wire                                        downcnvtr_pkt_dv;
wire                                        downcnvtr_pkt_eot;
wire        [CC_CORE_DATA_BUS_WD-1:0]       downcnvtr_pkt_data;

// Serializer output signal declaration
// ---------------------------------------------------------------------------------------------------------------------
wire                                         srlzr_halt;
wire                                         srlzr_hv;
wire                                         srlzr_dv;
wire                                         srlzr_eot;

// Tag manager signals
// ---------------------------------------------------------------------------------------------------------------------
wire        [MAX_WIRE_TAG_PW -1:0]           tm_next_tag;
wire                                         tm_next_tag_vld;

// Unconnected wire declaration
// ---------------------------------------------------------------------------------------------------------------------
wire                                         unconn_outq_pkt_bad_eot;


wire                                         outq_np_atomic_rsp_valid;
wire [CC_SLV_BUS_ID_WIDTH-1:0]               outq_np_atomic_rsp_id;
wire                                         s_c2anprsp_push_req_n;
wire [CC_SLV_BUS_ID_WIDTH-1:0]               s_c2anprsp_push_data;
wire                                         c2anprsp_push_af_nc;
wire                                         c2anprsp_push_full_nc;
wire                                         c2anprsp_pop_empty;
wire [CC_SLV_BUS_ID_WIDTH-1:0]               c2anprsp_pop_data;

wire                                         dwnstrm_pkt_halt;

// Input queue instantiation
// ---------------------------------------------------------------------------------------------------------------------
logic halt_to_inq;
logic halt_from_ts;

DWC_pcie_bridge_ob_np_dcmp_inq

   u_inq
   (
    .slv_aclk                   ( slv_aclk                      ),
    .slv_aresetn                ( slv_aresetn                   ),

    // Configuration interface
    .cfg_max_rd_req_size        ( cfg_max_rd_req_size           ),
    // Request packet interface
    .inq_pkt_halt               ( npdcmp_halt                   ),
    .req_pkt_hv                 ( nprf_hv                       ),
    .req_pkt_dv                 ( nprf_dv                       ),
    .req_pkt_eot                ( nprf_eot                      ),
    .req_pkt_bad_eot            ( nprf_bad_eot                  ),
    .req_pkt_tlp_prfx           ( nprf_tlp_prfx                 ),
    .req_pkt_th                 ( nprf_th                       ),
    .req_pkt_ph                 ( nprf_ph                       ),
    .req_pkt_st                 ( nprf_st                       ),
    .req_pkt_atu_bypass         ( nprf_atu_bypass               ),
    .req_pkt_dst_segment        ( nprf_dst_segment              ),
    .req_pkt_ats                ( nprf_ats                      ),
    .req_pkt_nw                 ( nprf_nw                       ),
    .req_pkt_first_wrp_split_xact ( nprf_first_wrp_split_xact     ),
    .req_pkt_wrp_valid            ( nprf_wrp_valid                ),
    .req_pkt_snp                ( nprf_snp                      ),
    .req_pkt_in_tag             ( nprf_tag                      ),
    .req_pkt_axi_id             ( nprf_id                       ),
    .req_pkt_cpl_stat           ( nprf_cpl_stat                 ),
    .req_pkt_byte_len           ( nprf_byte_len                 ),
    .req_pkt_tc                 ( nprf_tc                       ),
    .req_pkt_ep                 ( nprf_ep                       ),
    .req_pkt_attr               ( nprf_attr                     ),
    .req_pkt_byte_en            ( nprf_be                       ),
    .req_pkt_fmt                ( nprf_fmt                      ),
    .req_pkt_type               ( nprf_type                     ),
    .req_pkt_addr               ( nprf_addr                     ),
    .req_pkt_data               ( nprf_data                     ),

    .fifo_pkt_halt              ( halt_to_inq                   ),
    .inq_pkt_hv                 ( inq_pkt_hv                    ),
    .inq_pkt_dv                 ( inq_pkt_dv                    ),
    .inq_pkt_eot                ( inq_pkt_eot                   ),
    .inq_pkt_bad_eot            ( inq_pkt_bad_eot               ),
    .inq_pkt_tlp_prfx           ( inq_pkt_tlp_prfx              ),
    .inq_pkt_th                 ( inq_pkt_th                    ),
    .inq_pkt_ph                 ( inq_pkt_ph                    ),
    .inq_pkt_st                 ( inq_pkt_st                    ),
    .inq_pkt_atu_bypass         ( inq_pkt_atu_bypass            ),
    .inq_pkt_dst_segment        ( inq_pkt_dst_segment           ),
    .inq_pkt_ats                ( inq_pkt_ats                   ),
    .inq_pkt_nw                 ( inq_pkt_nw                    ),
    .inq_pkt_first_wrp_split_xact ( inq_pkt_first_wrp_split_xact ),
    .inq_pkt_wrp_valid            ( inq_pkt_wrp_valid            ),
    .inq_pkt_last_tlp           ( inq_pkt_last_tlp              ),
    .inq_pkt_dcmp_rd            ( inq_pkt_dcmp_rd               ),
    .inq_pkt_serial_req         ( inq_pkt_serial_req            ),
    .inq_pkt_req_byte_len       ( inq_pkt_req_byte_len          ),
    .inq_pkt_in_tag             ( inq_pkt_in_tag                ),
    .inq_pkt_axi_id             ( inq_pkt_axi_id                ),
    .inq_pkt_cpl_stat           ( inq_pkt_cpl_stat              ),
    .inq_pkt_byte_len           ( inq_pkt_byte_len              ),
    .inq_pkt_tc                 ( inq_pkt_tc                    ),
    .inq_pkt_ep                 ( inq_pkt_ep                    ),
    .inq_pkt_attr               ( inq_pkt_attr                  ),
    .inq_pkt_byte_en            ( inq_pkt_byte_en               ),
    .inq_pkt_fmt                ( inq_pkt_fmt                   ),
    .inq_pkt_type               ( inq_pkt_type                  ),
    .inq_pkt_addr               ( inq_pkt_addr                  ),
    .inq_pkt_data               ( inq_pkt_data                  )

   ,.dcmp_addr_parerr           ( npdcmp_addr_parerr            )
   ,.npdcmp_ad_ras_dp_err_log   ( npdcmp_ad_ras_dp_err_log      )
   ,.ras_dp_err_inj_slv_aclk    ( ras_dp_err_inj_slv_aclk       )

   );


   wire   inq_pkt_chk_en;
   assign inq_pkt_chk_en = inq_pkt_dv & !halt_to_inq;

   ras_dp_pipe
    #(
    .PIPELINE_TYPE             (0                              ),
    .RESETVAL                  (0                              ),
    .N_STAGES                  (0                              ),
    .CAN_STALL                 (0                              ),
    .RESET_STALL               (0                              ),
    .BUS_PROTECT_GEN_EN        (0                              ),
    .BUS_PROTECT_CHK_EN        (1                              ),
    .PROT_TYPE                 (1                              ), // 1: simple parity
    .PROT_RANGE                (CX_RAS_PROT_RANGE              ),
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS            ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE             ),
    .PROT_CORRECT_EN           (0                              ),
    .TOTAL_WIDTH               (SLV_BUS_NPDATA_WIDTH_NP        ),
    .EXCLUDE_PROT_WIDTH        (0                              ),
    .RAS_DP_PROT_CHK_ID_BASE   (`NPDCMP_INQ_DT_RAS_ID          )
  ) u_data_chk (
    .clk                       ( slv_aclk                      ),
    .rst_n                     ( slv_aresetn                   ),
    .din                       ( fn_data_wo_par (inq_pkt_data) ),
    .din_prot                  ( fn_prot_chkin_dt(inq_pkt_data)),
    .dout                      ( /* Not Connected */           ),
    .dout_prot                 ( /* Not Connected */           ),
    .en                        (1'b1                           ),
    .bypass                    (1'b0                           ),
    .stall                     (1'b0                           ),
    .stallout                  ( /* Not Connected */           ),
    .valid_in                  ( inq_pkt_dv                    ),
    .halt_out                  ( /* Not Connected */           ),
    .valid_out                 ( /* Not Connected */           ),
    .halt_in                   (1'b0                           ),
    .ras_dp_err_inband_kbd_in  (1'b0                           ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */           ),
    .ras_dp_err_log            ( npdcmp_inq_dt_ras_dp_err_log  )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk)
    );

  assign npdcmp_inq_data_parerr = npdcmp_inq_dt_ras_dp_err_log.valid;



  // strip out parity bits before push it into the RAM
  assign s_inq_pkt_data = fn_data_wo_par(inq_pkt_data);

  // Parity bits of inq_pkt_addr are added in u_inq instance. Thus, no parity
  // checker is needed at this point. However to keep the code modular the
  // parity addition code in u_inq was kept in the module even the parity removal
  // looks redundant here. Synthesis tool should remove parity bits of inq_pkt_addr.
  assign s_inq_pkt_addr = fn_addr_wo_par(inq_pkt_addr);

localparam SLAVE_BUS_NPDATA_WIDTH_NP = 32;
localparam CC_MAX_SLV_TAG = `CC_MAX_SLV_TAG;

// Hook into REQUEST BUS: inq -> ts -> hdf
typedef struct packed {
  logic                                hv;
  logic                                dv;
  logic                                eot;
  logic                                bad_eot;
  logic          [DCMP_PREFIX_WD -1:0] tlp_prfx;
  logic                                th;
  logic                       [2 -1:0] ph;
  logic                       [8 -1:0] st;
  logic                                atu_bypass;
  logic                       [9 -1:0] dst_segment;
  logic                       [2 -1:0] ats;
  logic                                nw;
  logic                                    first_wrp_split_xact;
  logic                                    wrp_valid;
  logic                                last_tlp;
  logic                                dcmp_rd;
  logic                                serial_req;
  logic           [CC_SLV_MTU_PW -1:0] req_byte_len;
  logic        [FIFO_BYTE_LEN_WD -1:0] byte_len;
  logic       [CC_MAX_SLV_TAG_PW -1:0] in_tag;
  logic   [CC_SLV_BUS_ID_WIDTH+1 -1:0] axi_id;
                                        // to avoid RAM bits tied to a fix value because UR is the only error response in use
  logic                                cpl_stat; // limit cpl_stat to 1 bit
  logic                       [3 -1:0] tc;
  logic                                ep;
  logic                 [ATTR_WD -1:0] attr;
  logic                       [8 -1:0] byte_en;
  logic                       [2 -1:0] fmt;
  logic                       [5 -1:0] pkt_type;
  logic    [SLAVE_BUS_ADDR_WIDTH -1:0] addr;
  logic [SLV_BUS_NPDATA_WIDTH_NP -1:0] data;
} iq2tqPkt_s;

typedef struct packed {
  logic [MAX_WIRE_TAG_PW -1:0] pkt_out_tag;
//  logic                        pkt_out_tag_only;
  iq2tqPkt_s                   iq2tq;
} ts2hdfPkt_s;

iq2tqPkt_s  w_inq_pkt, i_inq_pkt;
ts2hdfPkt_s ts_pkt;
ts2hdfPkt_s hdf_pkt;

assign i_inq_pkt = iq2tqPkt_s'{
  hv                  : inq_pkt_hv,
  dv                  : inq_pkt_dv,
  eot                 : inq_pkt_eot,
  bad_eot             : inq_pkt_bad_eot,
  tlp_prfx            : inq_pkt_tlp_prfx,
  th                  : inq_pkt_th,
  ph                  : inq_pkt_ph,
  st                  : inq_pkt_st,
  atu_bypass          : inq_pkt_atu_bypass,
  dst_segment         : inq_pkt_dst_segment,
  ats                 : inq_pkt_ats,
  nw                  : inq_pkt_nw,
  first_wrp_split_xact: inq_pkt_first_wrp_split_xact,
  wrp_valid           : inq_pkt_wrp_valid,
  last_tlp            : inq_pkt_last_tlp,
  dcmp_rd             : inq_pkt_dcmp_rd,
  serial_req          : inq_pkt_serial_req,
  req_byte_len        : inq_pkt_req_byte_len,
  byte_len            : inq_pkt_byte_len,
  in_tag              : inq_pkt_in_tag,
  axi_id              : inq_pkt_axi_id,
    // to avoid RAM bits tied to a fix value because UR is the only error response in use
  cpl_stat            : inq_pkt_cpl_stat[0], // limit cpl_stat to 1 bit
  tc                  : inq_pkt_tc,
  ep                  : inq_pkt_ep,
  attr                : inq_pkt_attr,
  byte_en             : inq_pkt_byte_en,
  fmt                 : inq_pkt_fmt,
  pkt_type            : inq_pkt_type,
  addr                : s_inq_pkt_addr,
  data                : s_inq_pkt_data
};

logic      valid_to_ts;
logic      rdy_to_inq;
iq2tqPkt_s r_inq_pkt;

assign halt_to_inq = ~rdy_to_inq;

DWC_pcie_axi_rs
 #(
  .P_FEED_READY ( 1                 )
 ,.CHAN_WD      ( $bits(iq2tqPkt_s) )
) u_inq_ts_rs (
  .clk            ( slv_aclk       )
 ,.rstn           ( slv_aresetn    )
 ,.clrn           ( 1'b1           )

 ,.vld_from_src   ( i_inq_pkt.hv | i_inq_pkt.dv | i_inq_pkt.eot )
 ,.chanl_from_src ( i_inq_pkt      )
 ,.rdy_to_src     ( rdy_to_inq     )

 ,.vld_to_dest    ( valid_to_ts    )
 ,.chanl_to_dest  ( r_inq_pkt      )
 ,.rdy_from_dest  ( ~halt_from_ts  )
);

always_comb begin : w_inq_pkt_cproc
  w_inq_pkt      = r_inq_pkt;
  w_inq_pkt.hv  &= valid_to_ts;
  w_inq_pkt.dv  &= valid_to_ts;
  w_inq_pkt.eot &= valid_to_ts;
end

DWC_pcie_bridge_ob_np_dcmp_ts
 #(
  .P_PKT_IN_TYPE     ( iq2tqPkt_s        )
 ,.P_PKT_OUT_TYPE    ( ts2hdfPkt_s       )
 ,.CC_MAX_SLV_TAG    ( CC_MAX_SLV_TAG    )
 ,.CC_MAX_SLV_TAG_PW ( CC_MAX_SLV_TAG_PW )
 ,.MAX_WIRE_TAG      ( MAX_WIRE_TAG      )
 ,.MAX_WIRE_TAG_PW   ( MAX_WIRE_TAG_PW   )
 ,.FIFO_BYTE_LEN_WD  ( FIFO_BYTE_LEN_WD  )
) u_ts (
  .slv_aclk                   ( slv_aclk                   )
 ,.slv_aresetn                ( slv_aresetn                )

 ,.cfg_ext_tag_en             ( cfg_ext_tag_en             )

 ,.cfg_10b_tag_en             ( cfg_10b_tag_en             )

 ,.inq_pkt                    ( w_inq_pkt                  )
 ,.inq_pkt_halt               ( halt_from_ts               )

 ,.ts_pkt                     ( ts_pkt                     )
 ,.tagq_pkt_halt              ( hdf_pkt_halt               )

 ,.slv_wt_assigned_valid      ( slv_wt_assigned_valid      )
 ,.slv_wt_assigned_apptag     ( slv_wt_assigned_apptag     )
 ,.slv_lookup_apptag          ( slv_lookup_apptag          )
 ,.slv_pop_wiretag            ( slv_pop_wiretag            )
 ,.slv_lookup_wiretag         ( slv_lookup_wiretag         )
 ,.slv_lookup_wiretag_is_last ( slv_lookup_wiretag_is_last )

 ,.rdr_lookup_wiretag         ( rdr_lookup_wiretag         )
 ,.rdr_pop_wiretag            ( rdr_pop_wiretag            )
);


localparam L_ECC_WIDTH = CC_OB_NPDCMP_RAM_DATA_WD - CC_OB_NPDCMP_RAM_DATA_WD_NOECC;

// Strip hv, dv, eot, bad_eot
localparam L_FIFO_STRIP = 4;
localparam L_FIFO_WD = $bits(ts_pkt) - L_FIFO_STRIP;

localparam UPPER_1 = $bits(hdf_pkt) - 1;
localparam LOWER_1 = UPPER_1 /*- 1*/ - MAX_WIRE_TAG_PW + 1;

localparam UPPER_2 = LOWER_1 - L_FIFO_STRIP - 1;
localparam LOWER_2 = 0;

logic [L_FIFO_WD -1:0] l_push_data;
logic [L_FIFO_WD -1:0] l_pop_data;

assign l_push_data = {ts_pkt[UPPER_1:LOWER_1], ts_pkt[UPPER_2:LOWER_2]};

DWC_pcie_bridge_async_fifo_ram_latency
 #(
    .DATA_WIDTH            ( L_FIFO_WD                      ),
    .ECC_WIDTH             ( L_ECC_WIDTH                    ),
    .CX_RAS_RAM_PROT_RANGE ( CX_RAS_RAM_PROT_RANGE          ),
    .DEPTH                 ( CC_OB_NPDCMP_RAM_DP            ),
    .RAM_ADDR_WIDTH        ( CC_OB_NPDCMP_RAM_ADDR_WD       ),
    .COUNT_WIDTH           ( CC_OB_NPDCMP_RAM_PTR_WD        ),
    .PUSH_SYNC             ( SYNC_DEPTH                     ),
    .POP_SYNC              ( SYNC_DEPTH                     ),
    .RAS_DP_ID             (`OB_NPDCMP_RAS_DP_ID            ),
    .RAM_RD_LATENCY        ( CC_OB_NPDCMP_RAM_RD_LATENCY    )
) u_hdf (
    .clk_push              ( slv_aclk                       ),
    .rst_push_n            ( slv_aresetn                    ),
    .push_req_n            ( !slv_wt_assigned_valid         ),
    .push_data             ( l_push_data                    ),
    .clk_pop               ( core_clk                       ),
    .rst_pop_n             ( core_rst_n                     ),
    .cfg_ras_correct          ( cfg_ras_recc_ob_npdcmp_correct         ),
    .ras_recc_corr_cnt_pulse  ( axi_ras_recc_corr_cnt_ob_npdcmp_pulse  ),
    .ras_recc_ucorr_cnt_pulse ( axi_ras_recc_ucorr_cnt_ob_npdcmp_pulse ),
    .ras_recc_cnt_addr        ( axi_ras_recc_cnt_ob_npdcmp_addr        ),
    .recc_cnt_ras_dp_err_log  (axi_recc_cnt_ob_npdcmp_ras_dp_err_log   ),
    .ras_dp_err_inj             (axi_bridge_ras_dp_err_inj_core_clk),
    .ready                 ( outq_ready                     ),
    .asfifo_wen            ( npdcmp_ram_wea                 ),
    .asfifo_waddr          ( npdcmp_ram_addra               ),
    .asfifo_wdata          ( npdcmp_ram_dina                ),
    .asfifo_raddr          ( npdcmp_ram_addrb               ),
    .asfifo_ren            ( npdcmp_ram_enb                 ),
    .rdata                 ( npdcmp_ram_doutb               ),
    .asfifo_f              ( hdf_pkt_halt                   ),
    .asfifo_af             ( /*UNCONNECTED*/                ),
    .asfifo_pop_data       ( l_pop_data                     ),
    .asfifo_pop_valid      ( hdf_pkt_valid                  ),
    .asfifo_e              (                                )
   );

assign hdf_pkt[UPPER_1:LOWER_1] = l_pop_data[UPPER_1 - L_FIFO_STRIP : LOWER_1 - L_FIFO_STRIP];
assign hdf_pkt[LOWER_1 -1 : UPPER_2 + 1] = '0;
assign hdf_pkt[UPPER_2:LOWER_2] = l_pop_data[UPPER_2:LOWER_2];

assign hdf_pkt_out_tag              = hdf_pkt.pkt_out_tag;
//assign hdf_pkt_out_tag_only       = hdf_pkt.pkt_out_tag_only;
assign hdf_pkt_tlp_prfx             = hdf_pkt.iq2tq.tlp_prfx;
assign hdf_pkt_th                   = hdf_pkt.iq2tq.th;
assign hdf_pkt_ph                   = hdf_pkt.iq2tq.ph;
assign hdf_pkt_st                   = hdf_pkt.iq2tq.st;
assign hdf_pkt_atu_bypass           = hdf_pkt.iq2tq.atu_bypass;
assign hdf_pkt_dst_segment          = hdf_pkt.iq2tq.dst_segment;
assign hdf_pkt_ats                  = hdf_pkt.iq2tq.ats;
assign hdf_pkt_nw                   = hdf_pkt.iq2tq.nw;
assign hdf_pkt_first_wrp_split_xact = hdf_pkt.iq2tq.first_wrp_split_xact;
assign hdf_pkt_wrp_valid            = hdf_pkt.iq2tq.wrp_valid;
assign hdf_pkt_last_tlp             = hdf_pkt.iq2tq.last_tlp;
assign hdf_pkt_dcmp_rd              = hdf_pkt.iq2tq.dcmp_rd;
assign hdf_pkt_serial_req           = hdf_pkt.iq2tq.serial_req;
assign hdf_pkt_req_byte_len         = hdf_pkt.iq2tq.req_byte_len;
assign hdf_pkt_byte_len             = hdf_pkt.iq2tq.byte_len;
assign hdf_pkt_in_tag               = hdf_pkt.iq2tq.in_tag;
assign hdf_pkt_axi_id               = hdf_pkt.iq2tq.axi_id;
assign hdf_pkt_cpl_stat_0b          = hdf_pkt.iq2tq.cpl_stat;
assign hdf_pkt_cpl_stat             = {2'b00,hdf_pkt_cpl_stat_0b}; // expanding cpl_stat back to 3 bits after RAM output
assign hdf_pkt_tc                   = hdf_pkt.iq2tq.tc;
assign hdf_pkt_ep                   = hdf_pkt.iq2tq.ep;
assign hdf_pkt_attr                 = hdf_pkt.iq2tq.attr;
assign hdf_pkt_byte_en              = hdf_pkt.iq2tq.byte_en;
assign hdf_pkt_fmt                  = hdf_pkt.iq2tq.fmt;
assign hdf_pkt_type                 = hdf_pkt.iq2tq.pkt_type;
assign hdf_pkt_addr                 = hdf_pkt.iq2tq.addr;
assign hdf_pkt_data                 = hdf_pkt.iq2tq.data;


  // generate parity bits and interleave them after RAM pop
  assign s_hdf_pkt_data = fn_data_w_par(hdf_pkt_data);
  assign s_hdf_pkt_addr = fn_addr_w_par(hdf_pkt_addr);

// Output queue instantiation
// ---------------------------------------------------------------------------------------------------------------------
DWC_pcie_bridge_ob_np_dcmp_outq

   u_outq
   (
    .core_clk                     ( core_clk                      ),
    .core_rst_n                   ( core_rst_n                    ),
    .hdf_pkt_tlp_prfx             ( hdf_pkt_tlp_prfx              ),
    .hdf_pkt_th                   ( hdf_pkt_th                    ),
    .hdf_pkt_ph                   ( hdf_pkt_ph                    ),
    .hdf_pkt_st                   ( hdf_pkt_st                    ),
    .hdf_pkt_atu_bypass           ( hdf_pkt_atu_bypass            ),
    .hdf_pkt_dst_segment          ( hdf_pkt_dst_segment           ),
    .hdf_pkt_ats                   ( hdf_pkt_ats                   ),
    .hdf_pkt_nw                    ( hdf_pkt_nw                    ),
    .hdf_pkt_first_wrp_split_xact  ( hdf_pkt_first_wrp_split_xact ),
    .hdf_pkt_wrp_valid             ( hdf_pkt_wrp_valid            ),
    .hdf_pkt_last_tlp              ( hdf_pkt_last_tlp              ),
    .hdf_pkt_dcmp_rd               ( hdf_pkt_dcmp_rd               ),
    .hdf_pkt_serial_req            ( hdf_pkt_serial_req            ),
    .hdf_pkt_req_byte_len          ( hdf_pkt_req_byte_len          ),
    .hdf_pkt_in_tag                ( hdf_pkt_in_tag                ),
    .hdf_pkt_out_tag               ( hdf_pkt_out_tag               ),
    .hdf_pkt_axi_id                ( hdf_pkt_axi_id                ),
    .hdf_pkt_byte_len              ( hdf_pkt_byte_len              ),
    .hdf_pkt_tc                    ( hdf_pkt_tc                    ),
    .hdf_pkt_ep                    ( hdf_pkt_ep                    ),
    .hdf_pkt_attr                  ( hdf_pkt_attr                  ),
    .hdf_pkt_byte_en               ( hdf_pkt_byte_en               ),
    .hdf_pkt_fmt                   ( hdf_pkt_fmt                   ),
    .hdf_pkt_type                  ( hdf_pkt_type                  ),
    .hdf_pkt_addr                  ( s_hdf_pkt_addr                ),
    .hdf_pkt_data                  ( s_hdf_pkt_data                ),
    .hdf_pkt_cpl_stat              ( hdf_pkt_cpl_stat              ),
    .hdf_pkt_valid                 ( hdf_pkt_valid                 ),
    .outq_ready                    ( outq_ready                    ),
    .dwnstrm_pkt_halt              ( dwnstrm_pkt_halt              ),
    .outq_pkt_hv                   ( outq_pkt_hv                   ),
    .outq_pkt_dv                   ( outq_pkt_dv                   ),
    .outq_pkt_eot                  ( outq_pkt_eot                  ),
    .outq_pkt_bad_eot              ( unconn_outq_pkt_bad_eot       ),
    .outq_pkt_tlp_prfx             ( outq_pkt_tlp_prfx             ),
    .outq_pkt_th                   ( outq_pkt_th                   ),
    .outq_pkt_ph                   ( outq_pkt_ph                   ),
    .outq_pkt_st                   ( outq_pkt_st                   ),
    .outq_pkt_atu_bypass           ( outq_pkt_atu_bypass           ),
    .outq_pkt_dst_segment          ( outq_pkt_dst_segment          ),
    .outq_pkt_ats                  ( outq_pkt_ats                  ),
    .outq_pkt_nw                   ( outq_pkt_nw                   ),
    .outq_pkt_func_num             ( outq_pkt_func_num             ),
    .outq_pkt_first_wrp_split_xact ( outq_pkt_first_wrp_split_xact ),
    .outq_pkt_wrp_valid            ( outq_pkt_wrp_valid            ),
    .outq_pkt_last_tlp             ( outq_pkt_last_tlp             ),
    .outq_pkt_4rd                  ( outq_pkt_4rd                  ),
    .outq_pkt_dcmp_rd              ( outq_pkt_dcmp_rd              ),
    .outq_pkt_serial_req           ( outq_pkt_serial_req           ),
    .outq_pkt_req_byte_len         ( outq_pkt_req_byte_len         ),
    .outq_pkt_out_tag              ( outq_pkt_out_tag              ),
    .outq_pkt_in_tag               ( outq_pkt_in_tag               ),
    .outq_pkt_axi_id               ( outq_pkt_axi_id               ),
    .outq_pkt_cpl_stat             ( outq_pkt_cpl_stat             ),
    .outq_pkt_byte_len             ( outq_pkt_byte_len             ),
    .outq_pkt_tc                   ( outq_pkt_tc                   ),
    .outq_pkt_ep                   ( outq_pkt_ep                   ),
    .outq_pkt_attr                 ( outq_pkt_attr                 ),
    .outq_pkt_byte_en              ( outq_pkt_byte_en              ),
    .outq_pkt_fmt                  ( outq_pkt_fmt                  ),
    .outq_pkt_type                 ( outq_pkt_type                 ),
    .outq_pkt_addr                 ( outq_pkt_addr                 ),
    .outq_pkt_data                 ( outq_pkt_data                 ),
    .outq_pkt_np_atomic_rsp_valid  ( outq_np_atomic_rsp_valid      ),
    .outq_pkt_np_atomic_rsp_id     ( outq_np_atomic_rsp_id         ),
    .cmp_sb_init_done              ( cmp_sb_init_done              )
   );


   assign s_outq_pkt_addr   = {{NUM_ADDR_APPEND_BYTE{APPEND_BYTE}},outq_pkt_addr};
// -------------------------------------------------------------------------------------
// Instantiate decomposed Non Posted TLP down converter
// -------------------------------------------------------------------------------------

  wire outq_pkt_np_rd_req, outq_pkt_hv_gated, outq_pkt_dv_gated, outq_pkt_eot_gated;

  assign outq_pkt_np_rd_req = outq_pkt_hv && !outq_pkt_dv && outq_pkt_eot;

  assign outq_pkt_hv_gated = outq_pkt_hv && !outq_pkt_np_rd_req;
  assign outq_pkt_dv_gated = outq_pkt_dv && !outq_pkt_np_rd_req;
  assign outq_pkt_eot_gated = outq_pkt_eot && !outq_pkt_np_rd_req;

  DWC_pcie_bridge_ob_dcmp_dncnvrt
  
  #(
   .IW                       (SLV_BUS_NPDATA_WIDTH)
  ,.OW                       (CC_CORE_DATA_BUS_WD)
  ,.DOWN_CONVERSION_RATIO_WD ($clog2(SLV_BUS_NPDATA_WIDTH/CC_CORE_DATA_BUS_WD))
  ,.PKT_LEN_WD               (13)
  )
  u_dncnvrt
  (
  .clk                        (core_clk)
  ,.rst_n                     (core_rst_n)
  ,.outq_pkt_hv               (outq_pkt_hv_gated)
  ,.outq_pkt_dv               (outq_pkt_dv_gated)
  ,.outq_pkt_eot              (outq_pkt_eot_gated)
  ,.data_byte_len             (outq_pkt_byte_len)
  ,.data_in                   (outq_pkt_data)
  ,.halt_out                  (dcnvtr_halt)

  ,.hv_out                    (downcnvtr_pkt_hv)
  ,.dv_out                    (downcnvtr_pkt_dv)
  ,.eot_out                   (downcnvtr_pkt_eot)
  ,.data_out                  (downcnvtr_pkt_data)
  ,.halt_in                   (srlzr_halt)
  );

  assign s_outq_pkt_hv     = outq_pkt_np_rd_req ? outq_pkt_hv                            : downcnvtr_pkt_hv;
  assign s_outq_pkt_dv     = outq_pkt_np_rd_req ? outq_pkt_dv                            : downcnvtr_pkt_dv;
  assign s_outq_pkt_eot    = outq_pkt_np_rd_req ? outq_pkt_eot                           : downcnvtr_pkt_eot;
  assign s_outq_pkt_data   = outq_pkt_np_rd_req ? outq_pkt_data[CC_CORE_DATA_BUS_WD-1:0] : downcnvtr_pkt_data;
  assign dwnstrm_pkt_halt  = outq_pkt_np_rd_req ? srlzr_halt                             : dcnvtr_halt;


// Serializer instantiation
// ---------------------------------------------------------------------------------------------------------------------
DWC_pcie_bridge_ob_np_dcmp_srlzr

   u_srlzr
   (
    .core_clk                   ( core_clk                      ),
    .core_rst_n                 ( core_rst_n                    ),
    .cfg_ax_snp_en              ( cfg_ax_snp_en                 ),
  // Outbound Non Posted Decomposer request interface
    .outq_pkt_hv                ( s_outq_pkt_hv                 ),
    .outq_pkt_dv                ( s_outq_pkt_dv                 ),
    .outq_pkt_eot               ( s_outq_pkt_eot                ),
    .outq_pkt_dcmp_rd           ( outq_pkt_dcmp_rd              ),
    .outq_pkt_first_wrp_split_xact ( outq_pkt_first_wrp_split_xact ),
    .outq_pkt_wrp_valid            ( outq_pkt_wrp_valid            ),
    .outq_pkt_serial_req        ( outq_pkt_serial_req           ),
    .outq_pkt_out_tag           ( outq_pkt_out_tag              ),
    .outq_pkt_axi_id            ( outq_pkt_axi_id               ),
    .outq_pkt_cpl_stat          ( outq_pkt_cpl_stat             ),
    .client1_halt               ( client1_halt                  ),
    .tm_next_tag                ( '0                            ),
    .tm_next_tag_vld            ( 1'b1                          ),
    .srlzr_out_tag              ( /* NC */                      ),
    .srlzr_use_tag              ( /* NC */                      ),
  // Completion interface
    .ibrtr_inbd_hv              ( ibrtr_inbd_hv                 ),
    .ibrtr_inbd_tag             ( ibrtr_inbd_tag                ),
    .ibrtr_inbd_last            ( ibrtr_inbd_last               ),
    .ibrtr_inbd_dllp_abort      ( ibrtr_inbd_dllp_abort         ),
    .ibrtr_inbd_tlp_abort       ( ibrtr_inbd_tlp_abort          ),
    .ibrtr_inbd_eot             ( ibrtr_inbd_eot                ),
  // Timeout interface
    .radm_cpl_timeout           ( radm_cpl_timeout              ),
    .radm_timeout_cpl_tag       ( radm_timeout_cpl_tag          ),
  // Halt for decomposer out queue FSM
    .srlzr_halt                 ( srlzr_halt                    ),
    .srlzr_hv                   ( srlzr_hv                      ),
    .srlzr_dv                   ( srlzr_dv                      ),
    .srlzr_eot                  ( srlzr_eot                     ),

    .s_wtag_active_lut          ( s_wtag_active_lut             )
   );


assign npdcmp_hv           = srlzr_hv              ;
assign npdcmp_dv           = srlzr_dv              ;
assign npdcmp_eot          = srlzr_eot             ;
assign npdcmp_tlp_prfx     = outq_pkt_tlp_prfx     ;
assign npdcmp_th           = outq_pkt_th           ;
assign npdcmp_ph           = outq_pkt_ph           ;
assign npdcmp_st           = outq_pkt_st           ;
assign npdcmp_atu_bypass   = outq_pkt_atu_bypass   ;
assign npdcmp_dst_segment  = outq_pkt_dst_segment  ;
assign npdcmp_ats          = outq_pkt_ats          ;
assign npdcmp_nw           = outq_pkt_nw           ;
assign npdcmp_func_num     = outq_pkt_func_num     ;
assign npdcmp_last_tlp     = outq_pkt_last_tlp     ;
assign npdcmp_4rd          = outq_pkt_4rd          ;
assign npdcmp_req_byte_len = outq_pkt_req_byte_len ;
assign npdcmp_out_tag      = outq_pkt_out_tag      ;
assign npdcmp_in_tag       = outq_pkt_in_tag       ;
assign npdcmp_axi_id       = outq_pkt_axi_id       ;
assign npdcmp_byte_len     = outq_pkt_byte_len     ;
assign npdcmp_tc           = outq_pkt_tc           ;
assign npdcmp_ep           = outq_pkt_ep           ;
assign npdcmp_attr         = outq_pkt_attr         ;
assign npdcmp_byte_en      = outq_pkt_byte_en      ;
assign npdcmp_fmt          = outq_pkt_fmt          ;
assign npdcmp_type         = outq_pkt_type         ;
assign npdcmp_data         = s_outq_pkt_data       ;
assign npdcmp_addr         = s_outq_pkt_addr       ;
assign npdcmp_cpl_stat     = outq_pkt_cpl_stat     ;

// -------------------------------------------------------------------------------------
// Non Posted Atomic TLP write Response interface
// -------------------------------------------------------------------------------------

  // Push ID to CDC FIFO
  assign s_c2anprsp_push_req_n = !outq_np_atomic_rsp_valid;
  assign s_c2anprsp_push_data  =  outq_np_atomic_rsp_id;

  // Instantiate FIFO controller + flip-flop based memory
  // By design the FIFO never overflows
  DWC_pcie_amba_cdc_fifo_dff
  
  #(.WIDTH                             (NON_POSTED_WR_RESP_INTF)
   ,.DEPTH                             (C2ANPRSP_FIFO_DEPTH)
   ,.ADDR_WIDTH                        (C2ANPRSP_FIFO_ADDR_WD)
   ,.COUNT_WIDTH                       (C2ANPRSP_FIFO_ADDR_WD+1)
   ,.PUSH_AE_LVL                       (C2ANPRSP_PUSH_AE_LVL)
   ,.PUSH_AF_LVL                       (C2ANPRSP_PUSH_AF_LVL)
   ,.POP_AE_LVL                        (C2ANPRSP_POP_AE_LVL)
   ,.POP_AF_LVL                        (C2ANPRSP_POP_AF_LVL)
   ,.ERR_MODE                          (C2ANPRSP_ERR_MODE)
   ,.PUSH_SYNC                         (C2ANPRSP_PUSH_SYNC)
   ,.POP_SYNC                          (C2ANPRSP_POP_SYNC)
   ,.RST_MODE                          (C2ANPRSP_RST_MODE)
   ,.HOLD_RD_ADDR                      (C2ANPRSP_HOLD_RD_ADDR)
  )
  u_c2anprsp
  (.clk_push                          (core_clk)
  ,.rst_push_n                        (core_rst_n)
  ,.clk_pop                           (slv_aclk)
  ,.rst_pop_n                         (slv_aresetn)
  // Master NP request info push interface
  ,.push_req_n                        (s_c2anprsp_push_req_n)
  ,.push_data                         (s_c2anprsp_push_data)
  ,.push_af                           (c2anprsp_push_af_nc)
  ,.push_full                         (c2anprsp_push_full_nc)
  ,.push_word_count                   (/*UNCONNECTED*/)
  // Master NP request info pop interface
  ,.pop_req_n                         (c2anprsp_pop_empty)
  ,.pop_empty                         (c2anprsp_pop_empty)
  ,.pop_data                          (c2anprsp_pop_data)
  ,.halt                              (1'b0)
  );

  assign npdcmp_np_atomic_rsp_valid = !c2anprsp_pop_empty;
  assign npdcmp_np_atomic_rsp_id    =  c2anprsp_pop_data;


  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  // Address without parity
  function automatic logic [SLAVE_BUS_ADDR_WIDTH-1:0] fn_addr_wo_par;
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
  function automatic logic [SLV_BUS_NPDATA_WIDTH_NP-1:0] fn_data_wo_par;
    input [SLV_BUS_NPDATA_WIDTH-1:0] s_data_w_par;
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
  function automatic logic [SLV_BUS_NPDATA_WIDTH-1:0] fn_data_w_par;
    input [SLV_BUS_NPDATA_WIDTH_NP-1:0] s_data_wo_par;

    integer i;
    reg [NUM_DATA_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE-1:0] i_data_wo_par;
    reg [NUM_DATA_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE:0]   i_data_w_par;
    reg parity_bit;

    begin
      i_data_wo_par = s_data_wo_par;
      for (i=0; i<(NUM_DATA_PAR_BLOCKS); i=i+1) begin
        parity_bit = (CX_RAS_PARITY_MODE == 0) ? ^(i_data_wo_par[i]) : ~(^(i_data_wo_par[i]));
        i_data_w_par[i] = {parity_bit,i_data_wo_par[i]};
      end
      fn_data_w_par = i_data_w_par;
    end
  endfunction

  // Address with parity
  function automatic logic [CC_SLV_BUS_ADDR_WIDTH-1:0] fn_addr_w_par;
    input [SLAVE_BUS_ADDR_WIDTH-1:0] s_addr_wo_par;

    integer i;
    reg [NUM_ADDR_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE-1:0] i_addr_wo_par;
    reg [NUM_ADDR_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE:0]   i_addr_w_par;
    reg parity_bit;

    begin
      i_addr_wo_par = s_addr_wo_par;
      for (i=0; i<(NUM_ADDR_PAR_BLOCKS); i=i+1) begin
        parity_bit = (CX_RAS_PARITY_MODE == 0) ? ^(i_addr_wo_par[i]) : ~(^(i_addr_wo_par[i]));
        i_addr_w_par[i] = {parity_bit,i_addr_wo_par[i]};
      end
      fn_addr_w_par = i_addr_w_par;
    end
  endfunction

  function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_dt;
    input [SLV_BUS_NPDATA_WIDTH-1:0] s_data_w_par;
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
  `define OB_NPDCMP_RAM_DT_PTR 0
  `define OB_NPDCMP_RAM_DT_PTRW 32

  `define OB_NPDCMP_RAM_AD_PTR 32
  `define OB_NPDCMP_RAM_AD_PTRW `SLAVE_BUS_ADDR_WIDTH

`endif

endmodule

