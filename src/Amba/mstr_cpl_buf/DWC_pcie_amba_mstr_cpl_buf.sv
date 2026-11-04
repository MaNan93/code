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
// ---    $Revision: #28 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Amba/mstr_cpl_buf/DWC_pcie_amba_mstr_cpl_buf.sv#28 $
// -------------------------------------------------------------------------
// Module Description:
//
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

 module DWC_pcie_amba_mstr_cpl_buf
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
import DWC_pcie_ctl_pkg::UNCORRECTABLE;
import DWC_pcie_ctl_pkg::CORRECTABLE;
import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_INDEX;
import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_WD;
import DWC_pcie_ctl_pkg::RAS_ERROR_LOG_WD;
import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  // AXI enabled
  parameter AXI_ENABLED                      = 1,
  parameter CX_RAS_RAM_PROT_RANGE            = `CX_RAS_RAM_PROT_RANGE,
  // Max number of master request ID's
  parameter CC_MAX_MSTR_TAGS                 = 4,
  // log2(CC_MAX_MSTR_TAGS)
  parameter CC_MAX_MSTR_TAG_PW               = 2,
  // Master response byte width with and without parity bit
  parameter CC_MSTR_RSP_BYTE_WD              = 8,
  // Number of bytes per master data beat expressed as 2^CC_MASTER_BUS_DATA_SIZE_ENC
  parameter CC_MASTER_BUS_DATA_SIZE_ENC      = 3,
  // Master data width with or without parity expressed in bits
  parameter CC_MSTR_RSP_DATA_WD              = 64,
  // Number of bytes per master data beat
  parameter CC_MSTR_BUS_WSTRB_WIDTH          = 8,

  // Max number of outstanding PCIe inbound requests
  parameter CX_REMOTE_MAX_TAGS               = 8,
  // log2(CX_REMOTE_MAX_TAGS)
  parameter CX_REMOTE_MAX_TAGS_WD            = 3,
  parameter NSEGMENTS                        = `CX_REMOTE_MAX_TAGS,
  parameter NSEGMENTS_WD                     = `CX_REMOTE_MAX_TAGS_WD,
  // log2(Inbound decomposition ratio)
  parameter CC_MSTR_MAX_SPLIT_PACK_PW        = 2,
  // Number of physical functions
  parameter CX_NFUNC                         = 8,
  // log2(CX_NFUNC)
  parameter CX_NFUNC_WD                      = 3,
  parameter DC_DMA_TYPE_WIDTH                = `DC_DMA_TYPE_WIDTH,
  parameter CC_NUM_DMA_RD_CHAN               = `CC_NUM_DMA_RD_CHAN,
  parameter CC_NUM_DMA_WR_CHAN               = `CC_NUM_DMA_WR_CHAN,
  parameter CC_NUM_DMA_RD_CHAN_WIDTH         = `CC_NUM_DMA_RD_CHAN_WIDTH,
  parameter CC_NUM_DMA_WR_CHAN_WIDTH         = `CC_NUM_DMA_WR_CHAN_WIDTH,
  parameter CC_NUM_DMA_MAX_CHAN_WIDTH        = `CC_NUM_DMA_MAX_CHAN_WIDTH,
  // Number of RAM entries per data segment
  parameter CC_MSTR_CPL_DATA_SEG_DP          = 10,
  parameter CC_MSTR_CPL_SEG_DATA_WD          = 128,
  // Width of segment data with and without parity
  parameter CC_MSTR_CPL_SEG_DATA_WD_NP       = 128,
  // log2(CC_MSTR_CPL_SEG_BUF_DP)
  parameter CC_MSTR_CPL_SEG_BUF_ADDR_WD      = 7,
  // Width of RAM entry expressed in bits
  parameter CC_MSTR_CPL_SEG_BUF_DATA_WD       = `CC_MSTR_CPL_SEG_BUF_DATA_WD,
  parameter CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC = `CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC,
  // Master Completion Buffer Read Latency
  parameter CC_MSTR_CPL_SEG_BUF_RAM_RD_LATENCY= `CC_MSTR_CPL_SEG_BUF_RAM_RD_LATENCY,
  // Registers the Master Completion Buffer RAM Write Control and Data and
  // Read Control Interface signals.
  parameter CC_MSTR_CPL_CTL_RAM_REGIN         = `CC_MSTR_CPL_CTL_RAM_REGIN,
  // Number of DWORD's per segment data beat
  parameter CC_MSTR_CPL_SEG_DATA_NUM_DWORDS  = 4,
  // log2(CC_MSTR_CPL_SEG_DATA_NUM_DWORDS)
  parameter CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2 = 2,
  // Number of bytes per segment data beat
  parameter CC_MSTR_CPL_SEG_DATA_NUM_BYTES   = 16,
  // log2(CC_MSTR_CPL_SEG_DATA_NUM_BYTES)
  parameter CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 = 4,
  // Number of bytes per segment data beat expressed as 2^CC_MSTR_CPL_SEG_DATA_SIZE_ENC
  parameter CC_MSTR_CPL_SEG_DATA_SIZE_ENC    = 4,
  // PCIe core data bus width with and without parity
  parameter CC_MSTR_CPL_DATA_WD              = 128,
  // Number of parity bits used for Client Address bus
  parameter CX_ADDR_PAR_WD                   = 2,
  // Master response interface signal data width
  // {svalid, sid, sbyte_en, sdata, sresp, np_not_p, wr_not_rd, ep, bad_eot, slast, last_pkt}
  parameter CC_MSTR_RSP_INTF_WD              = `CC_MSTR_RSP_INTF_WD,
  parameter CC_MSTR_RSP_INTF_WD_NP           = `CC_MSTR_RSP_INTF_WD_NP,
  // AMBA to Core Clock Crossing FIFO depth
  parameter CC_MCB_A2C_FIFO_DEPTH            = 8,
  // AMBA to Core Clock Crossing FIFO address width
  parameter CC_MCB_A2C_FIFO_ADDR_WD          = 3,
  // AMBA to Core Clock Crossing FIFO data width
  parameter CC_MCB_A2C_FIFO_DATA_WD          = `CC_IB_MCPL_CDC_RAM_DATA_WD, //CC_MSTR_RSP_INTF_WD,
  // AMBA to Core Clock Crossing FIFO read latency
  parameter CC_MCB_A2C_FIFO_RD_LATENCY    = 1,
  // Master completion queue depth
  parameter CC_MSTR_CPL_QUEUE_DP             = 8,
  // log2(CC_MSTR_CPL_QUEUE_DP)
  parameter CC_MSTR_CPL_QUEUE_DP_LOG2        = 3,
  // Master completion  PCIe to AMBA clock CDC
  parameter CC_MSTR_CPL_C2A_FIFO_DEPTH       = 26,
  //log2 CC_MSTR_CPL_C2A_FIFO_DEPTH
  parameter CC_MSTR_CPL_C2A_FIFO_WD          = 5,
  parameter DC_MCB_MAX_CPL_NUM_DWORDS_WD       = `DC_MCB_MAX_CPL_NUM_DWORDS_WD,

  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                               = `TP

 )
 
                                  (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  input                                              core_clk,
  input                                              core_rst_n,
  input                                              mstr_aclk,
  input                                              mstr_aresetn,
  // -------------------------------------------------------------------------------------
  // Configuration inputs
  // -------------------------------------------------------------------------------------
  input [(3*CX_NFUNC)-1:0]                           cfg_max_payload_size,
  // -------------------------------------------------------------------------------------
  // RAS signals
  // -------------------------------------------------------------------------------------
  input                                              cfg_ras_recc_ib_mcpl_a2c_cdc_correct,
  output wire                                        axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse,
  output wire                                        axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse,
  output wire [CC_MCB_A2C_FIFO_ADDR_WD-1:0]          axi_ras_recc_cnt_ib_mcpl_a2c_cdc_addr,
  output                                             axi_ras_par_ib_mcpl_a2c_dt_pulse,
  output ras_dp_err_log_t                            axi_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log,
  output ras_dp_err_log_t                            axi_ib_mcpl_a2c_dt_ras_dp_err_log,
  input  ras_dp_err_inj_t                            axi_bridge_ras_dp_err_inj_core_clk,
  input  ras_dp_err_inj_t                            core_clk_hp_mstr_ras_dp_err_inj,
  input  ras_dp_err_inj_t                            ras_dp_err_inj_mstr_aclk,
  input                                              cfg_ras_recc_ib_mcpl_sb_correct,
  output wire                                        axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse,
  output wire                                        axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse,
  output wire [CC_MSTR_CPL_SEG_BUF_ADDR_WD-1:0]      axi_ras_recc_cnt_ib_mcpl_sb_addr,
  output wire                                        axi_ras_par_ib_mcpl_sb_dt_pulse,
  output ras_dp_err_log_t                            axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log,
  output ras_dp_err_log_t                            axi_ib_mcpl_sb_dt_ras_dp_err_log,

  // -------------------------------------------------------------------------------------
  // Flush interface
  // -------------------------------------------------------------------------------------
  input                                              rstctl_mstr_flush_req,
  // -------------------------------------------------------------------------------------
  // Master request information interface (core clock)
  // -------------------------------------------------------------------------------------
  input                                              radmx_mreq_np_valid,
  input [CX_REMOTE_MAX_TAGS_WD-1:0]                  radmx_ireq_np_lookup_id,
  input [CX_NFUNC_WD-1:0]                            radmx_ireq_np_func,
  input                                              radmx_ireq_np_ncbe,
  input [`DC_MCB_MAX_CPL_NUM_BYTES_WD-2:0]           radmx_ireq_np_4kb_start_addr,
  input [`DC_MCB_MAX_CPL_NUM_BYTES_WD-1:0]           radmx_ireq_np_dw_len_bytes,
  input [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]              radmx_ireq_np_dma_chan,
  input [DC_DMA_TYPE_WIDTH-1:0]                      radmx_ireq_np_dma_type,
  input [CC_MAX_MSTR_TAG_PW-1:0]                     radmx_mreq_np_id,
  input                                              radmx_mreq_np_last,
  // -------------------------------------------------------------------------------------
  // Master request information interface (AMBA  clock, only required in AXI)
  // -------------------------------------------------------------------------------------
  input                                              mrf_mreq_np_valid,
  input [CC_MAX_MSTR_TAG_PW-1:0]                     mrf_mreq_np_id,
  input                                              mrf_mreq_np_last,
  input                                              mrf_mreq_np_atomic,
  // -------------------------------------------------------------------------------------
  // Recycle master request ID interface
  // -------------------------------------------------------------------------------------
  // mcb_mreq_id_valid: Indicates recycled master request ID is valid.
  // mcb_mreq_id: Recycled master request ID.
  // -------------------------------------------------------------------------------------
  // Master response interface
  // -------------------------------------------------------------------------------------
  input                                              svalid,
  input [CC_MAX_MSTR_TAG_PW-1:0]                     sid,
  input                                              sresp_wr_not_rd,
  input                                              sresp_np_not_p,
  input [`DC_SRESP_WD-1:0]                           sresp,
  input [`DC_CPL_STATUS_WD-1:0]                      smisc_info_cpl_stat,
  input                                              smisc_info_bad_eot,
  input                                              smisc_info_ep,
  input [`DC_TC_WD-1:0]                              smisc_info_tc,
  input [CC_MSTR_BUS_WSTRB_WIDTH-1:0]                sbyte_en,
  input [CC_MSTR_RSP_DATA_WD-1:0]                    sdata,
  input                                              slast,
  output                                             mcb_ready,
  // -------------------------------------------------------------------------------------
  // Master response segment buffer RAM interface
  // -------------------------------------------------------------------------------------
  // Write interface
  output wire                                        mcb_sb_wen,
  output wire [CC_MSTR_CPL_SEG_BUF_ADDR_WD-1:0]      mcb_sb_waddr,
  output wire [CC_MSTR_CPL_SEG_BUF_DATA_WD-1:0]      mcb_sb_wdata,
  // Read interface
  output wire                                        mcb_sb_ren,
  output wire [CC_MSTR_CPL_SEG_BUF_ADDR_WD-1:0]      mcb_sb_raddr,
  input       [CC_MSTR_CPL_SEG_BUF_DATA_WD-1:0]      sb_rdata,
  // -------------------------------------------------------------------------------------
  // External master response AMBA to Core clock crossing RAM interface
  // -------------------------------------------------------------------------------------
  // Write interface
  output wire                                        mcb_a2c_wen,
  output wire [CC_MCB_A2C_FIFO_ADDR_WD-1:0]          mcb_a2c_waddr,
  output wire [CC_MCB_A2C_FIFO_DATA_WD-1:0]          mcb_a2c_wdata,
  // Read interface
  output wire [CC_MCB_A2C_FIFO_ADDR_WD-1:0]          mcb_a2c_raddr,
  output wire                                        mcb_a2c_ren,
  input [CC_MCB_A2C_FIFO_DATA_WD-1:0]                a2c_rdata,

  // -------------------------------------------------------------------------------------
  // DMA RD Engine LL back-pressure signal
  // -------------------------------------------------------------------------------------
  input [CC_NUM_DMA_RD_CHAN-1:0]                     dma_mcb_rdll_halt,
  input [CC_NUM_DMA_WR_CHAN-1:0 ]                    dma_mcb_wrll_halt,
  // -------------------------------------------------------------------------------------
  // Client interface
  // -------------------------------------------------------------------------------------
  output wire                                        mcb_hv,
  output wire [`DC_FMT_WD-1:0]                       mcb_fmt,
  output wire [`DC_TYPE_WD-1:0]                      mcb_type,
  output wire [CX_NFUNC_WD-1:0]                      mcb_func,
  output wire [`DC_CPL_STATUS_WD-1:0]                mcb_status,
  output wire                                        mcb_ep,
  output wire [`DC_MCB_MAX_CPL_NUM_BYTES_WD-1:0]     mcb_dw_len_bytes,
  output wire [CX_REMOTE_MAX_TAGS_WD-1:0]            mcb_ireq_np_lookup_id,
  output wire [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]        mcb_dma_chan,
  output wire [DC_DMA_TYPE_WIDTH-1:0]                mcb_dma_type,
  output logic                                       mcb_prv_dma,
  output logic [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]       mcb_prv_dma_chan,
  output wire                                        mcb_dv,
  output wire [CC_MSTR_CPL_DATA_WD-1:0]              mcb_data,
  output wire                                        mcb_eot,
  output wire                                        mcb_last,
  output wire                                        mcb_bad_eot,
  output wire                                        mcb_addr_align_en,
  output wire                                        mcb_bcm,
  output wire                                        mcb_td,
  output wire [`FLT_Q_ATTR_WIDTH-1:0]                mcb_attr,
  output wire [`DC_CPL_BYTE_CNT_WD-1:0]              mcb_byte_cnt,
  output wire [`DC_CPL_AT_WD-1:0]                    mcb_ats,
  output wire [`DC_TC_WD-1:0]                        mcb_tc,

  output wire [`CX_TAG_SIZE-1:0]                     mcb_tid,
  output wire [(`DC_CPL_ADDR_WD+CX_ADDR_PAR_WD)-1:0] mcb_addr,
  output wire [`DC_CPL_BYTE_EN_WD-1:0]               mcb_byte_en,
  output wire [`DC_CPL_CMPLTR_ID_WD-1:0]             mcb_cmpltr_id,
  output wire                                        mcb_addr_parerr,
  input                                              halt
 );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------

  localparam L_MCBWR_DATANP_WD              = `CX_MCBWR_DATANP_WD;
  localparam L_MCBWR_DATAWP_WD              = `CX_MCBWR_DATAWP_WD;
  localparam L_MCBWR_DATANP_NUM_BYTES       = `CX_MCBWR_DATANP_NUM_BYTES;
  localparam L_MCBWR_DATANP_NUM_BYTES_LOG2  = `CX_MCBWR_DATANP_NUM_BYTES_LOG2;
  localparam L_MCBWR_DATANP_NUM_DWORDS      = `CX_MCBWR_DATANP_NUM_DWORDS;
  localparam L_MCBWR_DATANP_NUM_DWORDS_LOG2 = `CX_MCBWR_DATANP_NUM_DWORDS_LOG2;

  localparam DC_SRESP_WD                      = `DC_SRESP_WD;
  localparam MSTR_RESP_INTF_SVALID_MSB        = CC_MSTR_RSP_INTF_WD-1;
  localparam MSTR_RESP_INTF_SID_MSB           = MSTR_RESP_INTF_SVALID_MSB-1;
  localparam MSTR_RESP_INTF_SBYTE_EN_MSB      = MSTR_RESP_INTF_SID_MSB-CC_MAX_MSTR_TAG_PW;
  localparam MSTR_RESP_INTF_SDATA_MSB         = MSTR_RESP_INTF_SBYTE_EN_MSB-
                                                L_MCBWR_DATANP_NUM_BYTES;
  localparam MSTR_RESP_INTF_SRESP_MSB         = MSTR_RESP_INTF_SDATA_MSB-
                                                L_MCBWR_DATAWP_WD;
  localparam MSTR_RESP_INTF_CPL_STAT          = MSTR_RESP_INTF_SRESP_MSB-`DC_SRESP_WD;
  localparam MSTR_RESP_INTF_NP_NOT_P_MSB      = MSTR_RESP_INTF_CPL_STAT-`DC_CPL_STATUS_WD;
  localparam MSTR_RESP_INTF_WR_NOT_RD_MSB     = MSTR_RESP_INTF_NP_NOT_P_MSB-1;
  localparam MSTR_RESP_INTF_EP_MSB            = MSTR_RESP_INTF_WR_NOT_RD_MSB-1;
  localparam MSTR_RESP_INTF_TC_MSB            = MSTR_RESP_INTF_EP_MSB-1;
  localparam MSTR_RESP_INTF_BAD_EOT_MSB       = MSTR_RESP_INTF_TC_MSB-`DC_TC_WD;

  localparam MSTR_RESP_INTF_TLP_PREFIX_MSB            = 0;
   localparam MSTR_RESP_INTF_TLP_LN_MSB               = 0;
       localparam MSTR_RESP_INTF_TLP_CID_MSB            = 0 ;
       localparam MSTR_RESP_INTF_TLP_DST_SEGMENT_MSB  = 0;
       localparam MSTR_RESP_INTF_SLAST_MSB            = MSTR_RESP_INTF_BAD_EOT_MSB-1 ;

  localparam MSTR_RESP_INTF_LAST_PKT_MSB      = MSTR_RESP_INTF_SLAST_MSB-1;
  localparam MSTR_RESP_INTF_ATOP_ID_MSB       = MSTR_RESP_INTF_LAST_PKT_MSB-CC_MAX_MSTR_TAGS;
  localparam MSTR_RESP_INTF_ATOP_ALL_RSP_MSB  = MSTR_RESP_INTF_ATOP_ID_MSB-1;




  localparam NP_REQ_ACTIVE_IDS_VEC            = CC_MAX_MSTR_TAG_PW*
                                                CX_REMOTE_MAX_TAGS;
  localparam NP_REQ_START_LOW_ADDR_VEC        = CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2*
                                                CX_REMOTE_MAX_TAGS;

  // {radmx_mreq_np_valid, id, last}
  localparam RADMX_MREQ_NP_INTF               = (1 +
                                                 CC_MAX_MSTR_TAG_PW +
                                                 1);

  localparam RADMX_MREQ_NP_INTF_VALID_MSB     = RADMX_MREQ_NP_INTF-1;
  localparam RADMX_MREQ_NP_INTF_ID_MSB        = RADMX_MREQ_NP_INTF_VALID_MSB-1;
  localparam RADMX_MREQ_NP_INTF_LAST_MSB      = RADMX_MREQ_NP_INTF_ID_MSB-
                                                CC_MAX_MSTR_TAG_PW;

  // PCIe to AMBA core clock crossing FIFO parameters
  // Synchronizes MCB request interface from core to amba clock
  // This interface does not back-pressures, so must be sized
  // for the worst scenario that matches 2xINBOUND CDC + 1x2 tap delays + 2x1uc + 2
  // Add 2 additional locations to ensure FIFO never overflows.
  localparam C2A_FIFO_DEPTH                   = CC_MSTR_CPL_C2A_FIFO_DEPTH;
  localparam C2A_FIFO_ADDR_WD                 = CC_MSTR_CPL_C2A_FIFO_WD;
  localparam C2A_PUSH_AE_LVL                  = 1;
  localparam C2A_PUSH_AF_LVL                  = 1; // one from full
  localparam C2A_POP_AE_LVL                   = 1; // one from empty
  localparam C2A_POP_AF_LVL                   = 1;
  localparam C2A_ERR_MODE                     = 1'b0; // sticky flag
  localparam C2A_PUSH_SYNC                    = `CX_PCIE_SYNC_DEPTH;
  localparam C2A_POP_SYNC                     = `CX_PCIE_SYNC_DEPTH;
  localparam C2A_HOLD_RD_ADDR                 = 1;
  // Exclude memory reset
  localparam C2A_RST_MODE                     = 1;

  // PCIe core to AMBA clock crossing FIFO parameters
  localparam A2C_PUSH_AE_LVL                  = 1;
  localparam A2C_PUSH_AF_LVL                  = 1; // one from full
  localparam A2C_POP_AE_LVL                   = 1; // one from empty
  localparam A2C_POP_AF_LVL                   = 1;
  localparam A2C_ERR_MODE                     = 1'b0; // sticky flag
  localparam A2C_PUSH_SYNC                    = `CX_PCIE_SYNC_DEPTH;
  localparam A2C_POP_SYNC                     = `CX_PCIE_SYNC_DEPTH;
  // Holding the read address is only possible with the almost full flag.
  // If the full flag is used the push interface will clobber the held read data.
  localparam A2C_HOLD_RD_ADDR                 = 1;
  // Exclude memory reset
  localparam A2C_RST_MODE                     = 1;

  // Pipleined MCF Interface Width
  // {mcf_wr_seg_num, mcf_ep, mcf_tc, mcf_status, mcf_dw_en,
  // mcf_data, mcf_error, mcf_bad_eot, mcf_tlp_prefix, mcf_tlp_ln, mcf_cid, mcf_cid_en
  // mcf_last_pkt_beat, mcf_atop_wr_rsp, mcf_atop_cpl_queue, mcf.sseg
  // mcf.chunkv, mcf.chunknum, mcf.chunkstrb }
  localparam MCF_INTF_WD = CX_REMOTE_MAX_TAGS_WD
                           + 1 + `DC_CPL_STATUS_WD + L_MCBWR_DATANP_NUM_DWORDS
                           + L_MCBWR_DATAWP_WD + 1 + 1
                           + `DC_TC_WD
                           + 1
                           + 2
                           ;

  // Segment buffer parameters
  localparam MSTR_CPL_SEG_BUF_INIT_SEG_SIZES  = CC_MSTR_CPL_SEG_BUF_ADDR_WD*
                                                CX_REMOTE_MAX_TAGS;

  // 1: Generate RAM start and end addresses from data segment size info
  localparam GEN_STARTEND_ADDRS               = 1'b1;
  // 1: Hold the read address until the next pop access
  // 0: Increment the read address after the pop access
  localparam HOLD_RADDR                       = 1'b1;
  // DesignWare RAM's: Memory read data retimed to clkb, i.e. data retimed to core clock
  localparam SB_RDSYNC                        = 1'b1;

  localparam DC_CPL_STATUS_WD                 = `DC_CPL_STATUS_WD;
  localparam DC_TC_WD                         = `DC_TC_WD;
  // {hv, dw_len_bytes, lookup_id, fmt, type, status, ep, dma_type, dma_chan, func}
  localparam MCCTL_HDR_INFO_WD                = {1
                                                + `DC_MCB_MAX_CPL_NUM_BYTES_WD
                                                + CX_REMOTE_MAX_TAGS_WD
                                                + `DC_FMT_WD
                                                + `DC_TYPE_WD
                                                + `DC_CPL_STATUS_WD
                                                + 1
                                                + `DC_TC_WD
                                                + 1
                                                + DC_DMA_TYPE_WIDTH
                                                + CC_NUM_DMA_MAX_CHAN_WIDTH
                                                + CX_NFUNC_WD
                                                };

  localparam MCCTL_HDR_INFO_HV_MSB            = MCCTL_HDR_INFO_WD-1;
  localparam MCCTL_HDR_INFO_DW_LEN_BYTES_MSB  = MCCTL_HDR_INFO_HV_MSB-1;

  localparam ECC_WIDTH                        = CC_MSTR_CPL_SEG_BUF_DATA_WD -
                                                CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC;
  localparam CX_RAS_PARITY_MODE               = `CX_RAS_PARITY_MODE;
  localparam CX_PRFX_PAR_WD                   = `CX_PRFX_PAR_WD;
  // Number of parity data blocks for a single dword
  localparam CX_RAS_PROT_RANGE                = `CX_RAS_PROT_RANGE;
  localparam NUM_DATA_PAR_BLOCKS_RD           = CC_MSTR_CPL_SEG_DATA_WD_NP/CX_RAS_PROT_RANGE;
  localparam NUM_DATA_PAR_BLOCKS_WR           = L_MCBWR_DATANP_WD / CX_RAS_PROT_RANGE;
  localparam NUM_DATA_PAR_BLOCKS_S            = CC_MSTR_CPL_SEG_DATA_WD_NP/CX_RAS_PROT_RANGE;
  localparam NW                                   = `CX_NW;                 // Number of 32-bit dwords handled by the datapath each clock.
  localparam PAR_WD                               = CC_MSTR_CPL_SEG_DATA_WD_NP/CX_RAS_PROT_RANGE;
  localparam CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC_WP = CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC + PAR_WD;
  localparam RAS_ERROR_INJ_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N) + 1;

  localparam MSTR_RSP_INTF_DATA_LOW   = `DC_SRESP_WD +
                                        `DC_CPL_STATUS_WD +
                                        `DC_TC_WD +
                                         4 +
                                         1 +
                                         2 +
                                         CC_MAX_MSTR_TAGS
                                         ;
  localparam MSTR_RSP_INTF_DATA_HIGH = CC_MSTR_RSP_INTF_WD_NP - (MSTR_RSP_INTF_DATA_LOW + CC_MSTR_CPL_SEG_DATA_WD_NP);

    // Latency from scheduled RAM read (u_mcctl pop) to the presentation of aligned
    // RAM read data and control signals
   localparam CC_MSTR_CPL_SEG_BUF_LATENCY = CC_MSTR_CPL_SEG_BUF_RAM_RD_LATENCY
                                            + CC_MSTR_CPL_CTL_RAM_REGIN
                                            + 1 // Registered RAM read data
                                            ;

   localparam [8:0] BUS_INIT_BYTE = CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;
   localparam BYTE_WD_W_PAR = 9;

  // {dv, hdr_info, data, bad_eot, eot}
  localparam CLIENT_CPL_INTF_WD               = (1 +
                                                 MCCTL_HDR_INFO_WD +
                                                 CC_MSTR_CPL_SEG_DATA_WD +
                                                 2);

  // {dv, hdr_info, seg data, bad_eot, eot, dwen}
  localparam CPL_INTF_WD                      = CLIENT_CPL_INTF_WD
                                                + CC_MSTR_CPL_SEG_DATA_NUM_DWORDS
                                                ;
  // {dv, hdr_info, core data, bad_eot, eot}
  localparam MCB_CPL_INTF_WD                  = (1 +
                                                 MCCTL_HDR_INFO_WD +
                                                 CC_MSTR_CPL_DATA_WD +
                                                 2);
  localparam RAM_RAS_ID        = `IB_MCPL_2AC_CDC_RAS_ID;
  localparam SB_RAS_ID         = `AXI_IB_MCPL_SB_RAS_ID;
  localparam IB_DT_RAS_ID      = `IB_MCPL_A2C_DT_RAS_ID;
  localparam IB_SB_DT_RAS_ID   = `IB_MCPL_SB_DT_RAS_ID;


  // -------------------------------------------------------------------------------------
  // Internal wires
  // -------------------------------------------------------------------------------------

  // Selected master response interface, s* or s_mruc_*
  wire [CC_MSTR_RSP_INTF_WD_NP-1:0]                  s_mstr_rsp_intf;
  wire                                               s_mstr_rsp_svalid;
  wire                                               s_mstr_rsp_svalid_n;
  wire [CC_MAX_MSTR_TAG_PW-1:0]                      s_mstr_rsp_sid;
  wire [L_MCBWR_DATANP_NUM_BYTES-1:0]                s_mstr_rsp_sbyte_en;
  wire [L_MCBWR_DATAWP_WD-1:0]                       s_mstr_rsp_sdata;
  wire [CC_MSTR_CPL_SEG_DATA_WD_NP-1:0]              s_mstr_rsp_sdata_wo_par;
  wire                                               s_mstr_rsp_bad_eot;
  wire                                               s_mstr_rsp_ep;
  wire [`DC_TC_WD-1:0]                               s_mstr_rsp_tc;
  wire                                               s_mstr_rsp_np_not_p;
  wire                                               s_mstr_rsp_wr_not_rd;
  wire [`DC_SRESP_WD-1:0]                            s_mstr_rsp_sresp;
  wire [`DC_CPL_STATUS_WD-1:0]                       s_mstr_smisc_info_cpl_stat;
  wire                                               s_mstr_rsp_slast;
  logic                                              s_mstr_rsp_atomic_id;
  logic                                              s_mstr_rsp_atomic_all_rsp;
  logic                                              mrtrk_atomic_id;
  logic                                              mrtrk_atomic_all_rsp;
  logic                                              s_mrtrk_atomic_id;
  logic                                              s_mrtrk_atomic_all_rsp;
  logic                                              s_atop_err_decrease;
  wire [CC_MAX_MSTR_TAGS-1:0]                        s_mstr_rsp_last_pkt;
  wire [CC_MAX_MSTR_TAGS-1:0]                        mrtrk_last_pkt;
  wire [CC_MAX_MSTR_TAGS-1:0]                        s_mrtrk_last_pkt;

  wire                                               s_mstr_rsp_ready;

  // Master response pipe delay interface
  wire [CC_MSTR_RSP_INTF_WD-1:0]                     mrdly_interface_bus;
  wire                                               mrdly_halt;

  // Master request info PCIe to AMBA clock sync interface
  wire [RADMX_MREQ_NP_INTF-1:0]                      radmx_mreq_np_intf;
  wire                                               radmx_mreq_np_valid_n;
  wire                                               c2a_push_af_nc;
  wire                                               c2a_push_full_nc;
  wire                                               c2a_pop_empty;

  wire [RADMX_MREQ_NP_INTF-1:0]                      c2a_pop_data;

  wire                                               s_radmx_mreq_np_valid;

  wire [CC_MAX_MSTR_TAG_PW-1:0]                      s_radmx_mreq_np_id;

  wire                                               s_radmx_mreq_np_last;

  // Master response AMBA to PCIe core clock sync interface
  wire                                               a2c_push_f;
  wire                                               a2c_pop_empty;
  wire                                               a2c_pop_data_valid;
  wire [CC_MSTR_RSP_INTF_WD_NP-1:0]                  a2c_pop_data;
  wire [CC_MSTR_RSP_INTF_WD-1:0]                     s_a2c_pop_data;
  wire [CC_MSTR_RSP_INTF_WD-1:0]                     a2c_pop_intf;
  wire                                               a2c_pop_ready;

  // Selected master response interface, a2c_* or mrdly_*
  wire [CC_MSTR_RSP_INTF_WD-1:0]                     ss_mstr_rsp_intf;
  wire                                               ss_mstr_rsp_svalid;
  wire [CC_MAX_MSTR_TAG_PW-1:0]                      ss_mstr_rsp_sid;
  wire [L_MCBWR_DATANP_NUM_BYTES-1:0]                ss_mstr_rsp_sbyte_en;
  wire [L_MCBWR_DATAWP_WD-1:0]                       ss_mstr_rsp_sdata;
  wire [`DC_SRESP_WD-1:0]                            ss_mstr_rsp_sresp;
  wire [`DC_CPL_STATUS_WD-1:0]                       ss_mstr_smisc_info_cpl_stat;
  wire                                               ss_mstr_rsp_np_not_p;
  wire                                               ss_mstr_rsp_wr_not_rd;
  wire                                               ss_mstr_rsp_ep;
  wire [`DC_TC_WD-1:0]                               ss_mstr_rsp_tc;
  wire                                               ss_mstr_rsp_bad_eot;
  wire                                               ss_mstr_rsp_slast;
  wire [CC_MAX_MSTR_TAGS-1:0]                        ss_mstr_rsp_last_pkt;
  logic                                              ss_mstr_rsp_atomic_id;
  logic                                              ss_mstr_rsp_atomic_all_rsp;
  wire                                               ss_mstr_rsp_ready;
  wire                                               ss_mstr_rsp_halt;

  // Master completion formation interface
  wire                                               mcf_hv_nc;
  wire                                               mcf_dv;
  wire [CX_REMOTE_MAX_TAGS_WD-1:0]                   mcf_wr_seg_num;
  wire                                               mcf_ep;
  wire [`DC_TC_WD-1:0]                               mcf_tc;
  wire [`DC_CPL_STATUS_WD-1:0]                       mcf_status;
  wire [L_MCBWR_DATANP_NUM_DWORDS-1:0]               mcf_dw_en;
  wire [L_MCBWR_DATAWP_WD-1:0]                       mcf_data;
  wire                                               mcf_error;
  wire                                               mcf_bad_eot;
  wire                                               mcf_last_pkt_beat;
  wire                                               mcf_eot;
  logic                                              mcf_atop_wr_rsp;
  logic                                              mcf_atop_cpl_queue;

  // Master completion interface halt, u_pdlymcf to u_mcf
  wire                                               pdlymcf_halt;
  // Pipelined master completion interface, pdlymcf*
  wire                                               pdlymcf_dv;
  wire [CX_REMOTE_MAX_TAGS_WD-1:0]                   pdlymcf_wr_seg_num;
  wire                                               pdlymcf_ep;
  wire [`DC_TC_WD-1:0]                               pdlymcf_tc;
  wire [`DC_CPL_STATUS_WD-1:0]                       pdlymcf_status;
  wire [L_MCBWR_DATANP_NUM_DWORDS-1:0]               pdlymcf_dw_en;
  wire [L_MCBWR_DATAWP_WD-1:0]                       pdlymcf_data;
  wire                                               pdlymcf_error;
  wire                                               pdlymcf_bad_eot;
  wire                                               pdlymcf_last_pkt_beat;
  wire                                               pdlymcf_eot;
  logic                                              pdlymcf_atop_wr_rsp;
  logic                                              pdlymcf_atop_cpl_queue;
  //wire [CX_REMOTE_MAX_TAGS-1:0]                      mcctl_halt;
  wire                                               mcctl_halt;

  wire [ECC_WIDTH-1:0]                               mcf_ecc;
  wire [ECC_WIDTH-1:0]                               mcf_ras_ecc;
  wire [CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC_WP-1:0]    s_mcf_sb_push_data_ras_i;
  logic [CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC_WP-1:0]   ss_mcf_sb_push_data_ras_i;
  reg [CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC_WP-1:0]     r_mcf_sb_push_data_ras_i;
  wire [L_MCBWR_DATANP_WD-1:0]                       s_pdlymcf_data;

  wire [CC_MSTR_CPL_SEG_BUF_DATA_WD-1:0]             s_mcf_sb_push_data_i;
  reg [CC_MSTR_CPL_SEG_BUF_DATA_WD-1:0]              r_mcf_sb_push_data_i;

  // Segment buffer initialisition interface
  wire                                               mcctl_sb_init_i;
  wire [MSTR_CPL_SEG_BUF_INIT_SEG_SIZES-1:0]         mcctl_sb_init_seg_sizes_i;
  wire [CX_REMOTE_MAX_TAGS_WD:0]                     mcctl_sb_init_num_segs_i;
  wire                                               sbc_sb_init_done_o;

  // Segment buffer push interface
  wire                                               mcctl_sb_push_start_i;
  wire                                               mcctl_sb_push_i;
  wire [CX_REMOTE_MAX_TAGS_WD-1:0]                   mcctl_sb_push_seg_i;
  wire                                               mcctl_sb_push_keep_i;
  wire                                               mcctl_sb_push_drop_i;
  wire                                               mcctl_sb_reset_push_ptr;
  wire [CX_REMOTE_MAX_TAGS_WD-1:0]                   mcctl_sb_reset_push_seg_i;
  wire                                               cfg_ras_recc_ib_mcpl_sb_correct_n;
  wire                                               chk_ras_recc_corr_cnt_ib_mcpl_sb_pulse;
  wire                                               chk_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse;
  wire [CX_REMOTE_MAX_TAGS-1:0]                      sbc_sb_full_o;
  wire [CX_REMOTE_MAX_TAGS-1:0]                      sbc_sb_full_m_1_o;
  wire [CX_REMOTE_MAX_TAGS-1:0]                      sbc_sb_full_m_2_o;

  // Segment buffer pop interface
  wire                                               mcctl_sb_pop_i;
  wire                                               mcctl_sb_pop_look_i;
  wire                                               mcctl_sb_ram_rd_en;
  wire                                               mcctl_sb_reset_pop_ptr;
  wire [CC_MSTR_CPL_SEG_BUF_DATA_WD-1:0]             sbc_sb_pop_data_o;
  wire [CC_MSTR_CPL_SEG_BUF_DATA_WD-1:0]             s_sbc_sb_pop_data_o;
  wire [CX_REMOTE_MAX_TAGS_WD-1:0]                   mcctl_sb_pop_seg_i;
  wire [CX_REMOTE_MAX_TAGS_WD-1:0]                   mcctl_sb_reset_pop_seg_i;
  wire [CX_REMOTE_MAX_TAGS-1:0]                      sbc_sb_empty_o;
  wire [CX_REMOTE_MAX_TAGS-1:0]                      sbc_sb_empty_p_1_o;
  wire [CX_REMOTE_MAX_TAGS-1:0]                      sbc_sb_seg_pkt_avail_o_nc;
  // SBC QoR - pipeline RD and WR
  logic                                              s_mcctl_sb_pop_i;
  logic [CX_REMOTE_MAX_TAGS_WD-1:0]                  s_mcctl_sb_pop_seg_i;
  logic                                              s_mcctl_sb_ram_rd_en;
  logic                                              s_mcctl_sb_push_start_i;
  logic                                              s_mcctl_sb_push_i;
  logic [CX_REMOTE_MAX_TAGS_WD-1:0]                  s_mcctl_sb_push_seg_i;
  logic                                              s_mcctl_sb_push_keep_i;
  logic                                              s_mcctl_sb_push_drop_i;
  logic [CC_MSTR_CPL_SEG_BUF_DATA_WD-1:0]            ss_mcf_sb_push_data_i;

  // Segment buffer misc
  wire                                               srst_n;
  wire [(CX_REMOTE_MAX_TAGS*
         CC_MSTR_CPL_SEG_BUF_ADDR_WD)-1:0]           sb_seg_start_i;
  wire [(CX_REMOTE_MAX_TAGS*
         CC_MSTR_CPL_SEG_BUF_ADDR_WD)-1:0]           sb_seg_end_i;

  // Segment buffer RAM interface
  wire                                               sbc_sb_wen_n_o;
  wire [CC_MSTR_CPL_SEG_BUF_ADDR_WD-1:0]             sbc_sb_waddr_o;
  wire [CC_MSTR_CPL_SEG_BUF_DATA_WD-1:0]             sbc_sb_wdata_o;
  wire [CC_MSTR_CPL_SEG_BUF_ADDR_WD-1:0]             sbc_sb_raddr_o;
  wire                                               sbc_sb_ren_n_o_nc;
  wire [CC_MSTR_CPL_SEG_BUF_DATA_WD-1:0]             sb_rdata_i;

  wire [CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC_WP-1:0]    sbc_sb_wdata_ras_o;  // DATA_NOECC + PAR
  wire [CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC-1:0]       s_sbc_sb_wdata_o;
  wire [CC_MSTR_CPL_SEG_BUF_DATA_WD-1:0]             ss_sbc_sb_wdata_o;

  // Control completion interface
  wire                                               mcctl_hv;
  wire [CX_REMOTE_MAX_TAGS_WD-1:0]                   mcctl_ireq_np_lookup_id;
  wire [`DC_MCB_MAX_CPL_NUM_BYTES_WD-1:0]            mcctl_dw_len_bytes;
  wire [`DC_FMT_WD-1:0]                              mcctl_fmt;
  wire [`DC_TYPE_WD-1:0]                             mcctl_type;
  wire [`DC_CPL_STATUS_WD-1:0]                       mcctl_status;
  wire                                               mcctl_ep;
  wire [`DC_TC_WD-1:0]                               mcctl_tc;
  wire [CX_NFUNC_WD-1:0]                             mcctl_func;
  wire [DC_DMA_TYPE_WIDTH-1:0]                       mcctl_dma_type;
  wire [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]               mcctl_dma_chan;
  wire                                               mcctl_dv;
  wire                                               mcctl_eot;

  wire                                               mcctl_last;
  wire [ECC_WIDTH-1:0]                               s_sbc_ecc;
  wire [CC_MSTR_CPL_SEG_DATA_WD_NP-1:0]              s_sbc_data;
  wire [CC_MSTR_CPL_SEG_DATA_WD-1:0]                 ss_sbc_data;
  wire [CC_MSTR_CPL_SEG_DATA_WD_NP-1:0]              s_sbc_data_ras_dp_pipe;
  wire [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]         s_sbc_dw_en_ras_dp_pipe;
  wire                                               s_sbc_bad_eot_ras_dp_pipe;

  wire                                               s_sbc_bad_eot;
  wire [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]         s_sbc_dw_en;
  wire [CPL_INTF_WD-1:0]                             s_cpl_intf;

  wire                                               s_client_cpl_hv;
  wire                                               s_client_cpl_dv;
  wire                                               s_client_cpl_eot;
  wire [MCCTL_HDR_INFO_WD-1:0]                       s_client_cpl_hdr_info;
  wire [CC_MSTR_CPL_SEG_DATA_WD-1:0]                 s_client_cpl_data;
  wire [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]         s_client_cpl_dw_en;
  wire [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]         chk_client_cpl_dw_en;
  wire                                               s_client_cpl_bad_eot;
  wire                                               s_client_cpl_bad_eot_g;
  wire                                               s_client_cpl_halt;
  wire [ECC_WIDTH -1 :0]                             s_client_ecc;
  wire                                               s_algn_sb_pop_i;
  wire [CC_MSTR_CPL_SEG_BUF_ADDR_WD-1:0]             s_algn_sbc_sb_raddr_o;
  wire [CC_MSTR_CPL_SEG_BUF_ADDR_WD-1:0]             ss_sbc_sb_raddr_o;

  // Selected completion interface, mcctl_* or dwa_*
  wire                                               ss_client_cpl_dv;
  wire [MCCTL_HDR_INFO_WD-1:0]                       ss_client_cpl_hdr_info;
  wire [CC_MSTR_CPL_SEG_DATA_WD-1:0]                 ss_client_cpl_data;
  wire                                               ss_client_cpl_bad_eot;
  wire                                               ss_client_cpl_eot;
  wire                                               ss_client_cpl_halt;

  // DWORD aligned client completion interface
  wire                                               dwa_dv;
  wire [MCCTL_HDR_INFO_WD-1:0]                       dwa_hdr_info;
  wire [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0]         dwa_rdw_en_nc;
  wire [CC_MSTR_CPL_SEG_DATA_WD-1:0]                 dwa_data;
  wire                                               dwa_bad_eot;
  wire                                               dwa_eot;
  wire                                               dwa_halt;

  // Selected completion interface, ss_client_cpl_* or ccdwn*
  wire                                               sss_client_cpl_dv;
  wire [MCCTL_HDR_INFO_WD-1:0]                       sss_client_cpl_hdr_info;
  wire [CC_MSTR_CPL_DATA_WD-1:0]                     sss_client_cpl_data;
  wire                                               sss_client_cpl_bad_eot;
  wire                                               sss_client_cpl_eot;


  wire [MCB_CPL_INTF_WD-1:0]                         sss_client_cpl_intf;
  wire [MCB_CPL_INTF_WD-1:0]                         ssss_client_cpl_intf;


  // Down converted client completion interface
  wire                                               ccdwn_dv;
  wire [MCCTL_HDR_INFO_WD-1:0]                       ccdwn_hdr_info;
  wire                                               ccdwn_eot;
  wire [CC_MSTR_CPL_DATA_WD-1:0]                     ccdwn_data;
  wire                                               ccdwn_bad_eot;
  wire                                               ccdwn_halt;

  // Client completion pipeline delay interface 1
  wire [CPL_INTF_WD-1:0]                             dly1_interface_bus;
  wire                                               dly1_halt;
  // Client completion pipeline delay interface 2
  wire                                               s_mcb_interface_bus_valid;
  wire [MCB_CPL_INTF_WD-1:0]                         ccdly2_interface_bus;
  wire                                               ccdly2_halt;
  wire                                               s_cpl_halt;

  logic                                              mcbwr_clk;
  logic                                              mcbwr_rst_n;
  logic                                              mcbwr_req_np_valid;
  logic [CC_MAX_MSTR_TAG_PW -1:0]                    mcbwr_req_np_id;
  logic                                              mcbwr_req_np_ncbe;
  logic [`DC_MCB_MAX_CPL_NUM_BYTES_WD -2:0]          mcbwr_req_np_4kb_start_addr;
  logic                                              mcbwr_mstr_flush_req;

  // -------------------------------------------------------------------------------------
  // DMA CPL RORDR <-> MCB CTRL interfaces
  // -------------------------------------------------------------------------------------
  logic                                    cpl_q_dma_wr_valid         ;
  logic [CX_REMOTE_MAX_TAGS_WD-1:0]        cpl_q_dma_wr_seg_num       ;
  logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] cpl_q_dma_wr_beat_len      ;
  logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] cpl_q_dma_wr_dw_len        ;
  logic [DC_CPL_STATUS_WD-1:0]             cpl_q_dma_wr_status        ;
  logic                                    cpl_q_dma_wr_ep            ;
  logic [DC_TC_WD-1:0]                     cpl_q_dma_wr_tc            ;
  logic                                    cpl_q_dma_wr_last_pkt_beat ;
  logic                                    cpl_q_dma_rd_ready         ;
  logic                                    cpl_q_dma_rd_valid         ;
  logic [CC_NUM_DMA_MAX_CHAN_WIDTH-1:0]    cpl_q_dma_rd_dma_chan      ;
  logic [DC_DMA_TYPE_WIDTH-1:0]            cpl_q_dma_rd_dma_type      ;
  logic [CX_REMOTE_MAX_TAGS_WD-1:0]        cpl_q_dma_rd_seg_num       ;
  logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] cpl_q_dma_rd_beat_len      ;
  logic [DC_MCB_MAX_CPL_NUM_DWORDS_WD-1:0] cpl_q_dma_rd_dw_len        ;
  logic [DC_CPL_STATUS_WD-1:0]             cpl_q_dma_rd_status        ;
  logic                                    cpl_q_dma_rd_ep            ;
  logic [DC_TC_WD-1:0]                     cpl_q_dma_rd_tc            ;
  logic                                    cpl_q_dma_rd_last_pkt_beat ;
  // -------------------------------------------------------------------------------------
  // Internal design
  // -------------------------------------------------------------------------------------


  typedef struct packed {
    logic svalid;
    logic [CC_MAX_MSTR_TAG_PW -1:0] sid;
    logic [CC_MSTR_BUS_WSTRB_WIDTH -1:0] sbyte_en;
    logic [CC_MSTR_RSP_DATA_WD -1:0] sdata;
    logic smisc_info_bad_eot;
    logic smisc_info_ep;
    logic [`DC_TC_WD-1:0] smisc_info_tc;
    logic sresp_np_not_p;
    logic sresp_wr_not_rd;
    logic [`DC_SRESP_WD -1:0] sresp;
    logic [`DC_CPL_STATUS_WD -1:0] smisc_info_cpl_stat;
    logic slast;
  } inBus_t;

  typedef struct packed {
    logic [CC_MAX_MSTR_TAGS -1:0] mrtrk_last_pkt;
    logic mrtrk_atomic_id;
    logic mrtrk_atomic_all_rsp;
  } mtrkBus_t;

  typedef struct packed {
    logic     valid;
    inBus_t   sin;
    mtrkBus_t mtrk;
    logic     rdy;
  } inputBus_t;

  inputBus_t s_inBus_i, s_inBus_o;
  logic w_inBus_i_rdy;



  assign s_inBus_i = inputBus_t'{
    default: '0
   ,valid: svalid
   ,sin: inBus_t'{
      svalid: svalid
     ,sid: sid
     ,sbyte_en: sbyte_en
     ,sdata: sdata
     ,smisc_info_bad_eot: smisc_info_bad_eot
     ,smisc_info_ep: smisc_info_ep
     ,smisc_info_tc: smisc_info_tc
     ,sresp_np_not_p: sresp_np_not_p
     ,sresp_wr_not_rd: sresp_wr_not_rd
     ,sresp: sresp
     ,smisc_info_cpl_stat: smisc_info_cpl_stat
     ,slast: slast
    }
   ,rdy: w_inBus_i_rdy
  };

  assign mcb_ready = s_inBus_i.rdy;

  assign s_inBus_o.valid = s_inBus_i.valid;
  assign s_inBus_o.sin   = s_inBus_i.sin;
  assign w_inBus_i_rdy   = s_inBus_o.rdy;

  assign s_inBus_o.rdy = s_mstr_rsp_ready;


  assign s_mstr_rsp_svalid          = s_inBus_o.valid;
  assign s_mstr_rsp_svalid_n        = ~s_inBus_o.valid;
  assign s_mstr_rsp_sid             = s_inBus_o.sin.sid;
  assign s_mstr_rsp_sbyte_en        = s_inBus_o.sin.sbyte_en;
  assign s_mstr_rsp_sdata           = s_inBus_o.sin.sdata;
  assign s_mstr_rsp_bad_eot         = s_inBus_o.sin.smisc_info_bad_eot;
  assign s_mstr_rsp_ep              = s_inBus_o.sin.smisc_info_ep;
  assign s_mstr_rsp_tc              = s_inBus_o.sin.smisc_info_tc;
  assign s_mstr_rsp_np_not_p        = s_inBus_o.sin.sresp_np_not_p;
  assign s_mstr_rsp_wr_not_rd       = s_inBus_o.sin.sresp_wr_not_rd;
  assign s_mstr_rsp_sresp           = s_inBus_o.sin.sresp;
  assign s_mstr_smisc_info_cpl_stat = s_inBus_o.sin.smisc_info_cpl_stat;
  assign s_mstr_rsp_slast           = s_inBus_o.sin.slast;
  assign s_mstr_rsp_last_pkt        = s_inBus_o.mtrk.mrtrk_last_pkt;
  assign s_mstr_rsp_atomic_id       = s_inBus_o.mtrk.mrtrk_atomic_id;
  assign s_mstr_rsp_atomic_all_rsp  = s_inBus_o.mtrk.mrtrk_atomic_all_rsp;


   assign s_radmx_mreq_np_valid = mrf_mreq_np_valid;
   assign s_radmx_mreq_np_id    = mrf_mreq_np_id;
   assign s_radmx_mreq_np_last  = mrf_mreq_np_last;

  assign s_atop_err_decrease = mcf_error;
  // -------------------------------------------------------------------------------------
  // Master Response ID Tracker block
  // -------------------------------------------------------------------------------------
  DWC_pcie_amba_mstr_rsp_tracker
  
  #(
  .CC_MAX_MSTR_TAGS                  (CC_MAX_MSTR_TAGS)
  ,.CC_MAX_MSTR_TAG_PW               (CC_MAX_MSTR_TAG_PW)
  ,.CC_MSTR_MAX_SPLIT_PACK_PW        (CC_MSTR_MAX_SPLIT_PACK_PW)
  )
  u_mrtrk
  (
  // Clocks and resets
  .mstr_aclk                          (mstr_aclk)
  ,.mstr_aresetn                      (mstr_aresetn)
  // PCIe non-posted request info
  ,.radmx_mreq_np_valid               (s_radmx_mreq_np_valid)
  ,.radmx_mreq_np_id                  (s_radmx_mreq_np_id)
  ,.radmx_mreq_np_last                (s_radmx_mreq_np_last)
  ,.radmx_mreq_np_atomic              (mrf_mreq_np_atomic)
  // Master response interface control
  ,.svalid                            (s_inBus_o.valid)
  ,.sid                               (s_inBus_o.sin.sid)
  ,.sresp_np_not_p                    (s_inBus_o.sin.sresp_np_not_p)
  ,.slast                             (s_inBus_o.sin.slast)
  ,.ready                             (s_inBus_o.rdy)
  ,.atop_err_decrease                 (s_atop_err_decrease)
  ,.mrtrk_atomic_id                   (s_inBus_o.mtrk.mrtrk_atomic_id)
  ,.mrtrk_atomic_all_rsp              (s_inBus_o.mtrk.mrtrk_atomic_all_rsp)
  // Master response tracker interface
  ,.mrtrk_last_pkt                    (s_inBus_o.mtrk.mrtrk_last_pkt)
  );


   wire   mstr_rsp_data_chk_en;
   assign mstr_rsp_data_chk_en = s_mstr_rsp_svalid & s_mstr_rsp_ready;
    ras_dp_pipe
     #(
    .PIPELINE_TYPE             (0                                     ), // 0: delay_n
    .RESETVAL                  (0                                     ),
    .N_STAGES                  (0                                     ),
    .CAN_STALL                 (0                                     ),
    .RESET_STALL               (0                                     ),
    .BUS_PROTECT_GEN_EN        (0                                     ),  // 0: Bus Protection Generator is not present
    .BUS_PROTECT_CHK_EN        (1                                     ),  // 1: Bus Protection Checker is present (ECC/Parity)
    .PROT_TYPE                 (1                                     ),  // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                (CX_RAS_PROT_RANGE                     ), // Number of bits to calculate parity/ECC on
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS_WR                ), // we need one more bit because of the address
    .PARITY_MODE               (CX_RAS_PARITY_MODE                    ),
    .PROT_CORRECT_EN           (0                                     ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH               (L_MCBWR_DATANP_WD                     ),
    .EXCLUDE_PROT_WIDTH        (0                                     ),
    .RAS_DP_PROT_CHK_ID_BASE   (IB_DT_RAS_ID                          )
  ) u_mstr_rsp_data_chk (
    .clk                       ( mstr_aclk                            ),
    .rst_n                     ( mstr_aresetn                         ),
    .din                       ( fn_data_wo_par_wr(s_mstr_rsp_sdata)  ),
    .din_prot                  ( fn_prot_chkin_d (s_mstr_rsp_sdata)   ),
    .dout                      ( /* Not Connected */                  ), //Data is corrected
    .dout_prot                 ( /* Not Connected */                  ),
    .en                        (1'b1                                  ),
    .bypass                    (1'b0                                  ),
    .stall                     (1'b0                                  ),
    .stallout                  ( /* Not Connected */                  ),
    .valid_in                  ( mstr_rsp_data_chk_en                 ),
    .halt_out                  ( /* Not Connected */                  ),
    .valid_out                 ( /* Not Connected */                  ),
    .halt_in                   (1'b0                                  ),
    .ras_dp_err_inband_kbd_in  (1'b0                                  ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */                  ),
    .ras_dp_err_log            ( axi_ib_mcpl_a2c_dt_ras_dp_err_log    )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_mstr_aclk              )
    );

    assign axi_ras_par_ib_mcpl_a2c_dt_pulse = axi_ib_mcpl_a2c_dt_ras_dp_err_log.valid;


  assign s_mstr_rsp_sdata_wo_par = fn_data_wo_par_wr(s_mstr_rsp_sdata);

  // Concatenate master response interface signals
  // Master response interface signals are gated with
  // s_mstr_rsp_svalid to avoid xmerge violations
  assign s_mstr_rsp_intf = !s_mstr_rsp_svalid ? 'h0 : {
                            s_mstr_rsp_svalid,
                            s_mstr_rsp_sid,
                            s_mstr_rsp_sbyte_en,
                            s_mstr_rsp_sdata_wo_par,
                            s_mstr_rsp_sresp,
                            s_mstr_smisc_info_cpl_stat,
                            s_mstr_rsp_np_not_p,
                            s_mstr_rsp_wr_not_rd,
                            s_mstr_rsp_ep,
                            s_mstr_rsp_tc,
                            s_mstr_rsp_bad_eot,
                            s_mstr_rsp_slast,
                            s_mstr_rsp_last_pkt
                            ,s_mstr_rsp_atomic_id
                            ,s_mstr_rsp_atomic_all_rsp
                           };

  // -------------------------------------------------------------------------------------
  // AMBA to PCIe Clock Crossing FIFO Control block (optional)
  // -------------------------------------------------------------------------------------

  DWC_pcie_bridge_async_fifo_ram_latency
  
  #(
  .DATA_WIDTH                        (CC_MSTR_RSP_INTF_WD_NP)
  ,.ECC_WIDTH                        (CC_MCB_A2C_FIFO_DATA_WD - CC_MSTR_RSP_INTF_WD_NP)
  ,.CX_RAS_RAM_PROT_RANGE            (CX_RAS_RAM_PROT_RANGE)
  ,.RAM_RD_LATENCY                   (CC_MCB_A2C_FIFO_RD_LATENCY)
  ,.DEPTH                            (CC_MCB_A2C_FIFO_DEPTH)
  ,.RAM_ADDR_WIDTH                   (CC_MCB_A2C_FIFO_ADDR_WD)
  ,.COUNT_WIDTH                      (CC_MCB_A2C_FIFO_ADDR_WD+1)
  ,.PUSH_AE_LVL                      (A2C_PUSH_AE_LVL)
  ,.PUSH_AF_LVL                      (A2C_PUSH_AF_LVL)
  ,.POP_AE_LVL                       (A2C_POP_AE_LVL)
  ,.POP_AF_LVL                       (A2C_POP_AF_LVL)
  ,.ERR_MODE                         (A2C_ERR_MODE)
  ,.PUSH_SYNC                        (A2C_PUSH_SYNC)
  ,.POP_SYNC                         (A2C_POP_SYNC)
  ,.HOLD_RD_ADDR                     (A2C_HOLD_RD_ADDR)
  ,.RAS_DP_ID                        (RAM_RAS_ID)
  )
  u_a2c
  (
  .clk_push                           (mstr_aclk)
  ,.rst_push_n                        (mstr_aresetn)
  ,.clk_pop                           (core_clk)
  ,.rst_pop_n                         (core_rst_n)
  ,.cfg_ras_correct                   (cfg_ras_recc_ib_mcpl_a2c_cdc_correct)
  ,.ras_recc_corr_cnt_pulse           ( axi_ras_recc_corr_cnt_ib_mcpl_a2c_cdc_pulse)
  ,.ras_recc_ucorr_cnt_pulse          ( axi_ras_recc_ucorr_cnt_ib_mcpl_a2c_cdc_pulse)
  ,.ras_recc_cnt_addr                 (axi_ras_recc_cnt_ib_mcpl_a2c_cdc_addr)
  ,.recc_cnt_ras_dp_err_log           ( axi_recc_cnt_ib_mcpl_2ac_cdc_ras_dp_err_log)
  ,.ras_dp_err_inj                    (axi_bridge_ras_dp_err_inj_core_clk)
  // External FIFO RAM interface
  ,.asfifo_wen                        (mcb_a2c_wen)
  ,.asfifo_waddr                      (mcb_a2c_waddr)
  ,.asfifo_wdata                      (mcb_a2c_wdata)
  ,.asfifo_raddr                      (mcb_a2c_raddr)
  ,.asfifo_ren                        (mcb_a2c_ren)
  ,.rdata                             (a2c_rdata)
  // Master response push interface
  ,.push_req_n                        (s_mstr_rsp_svalid_n)
  ,.push_data                         (s_mstr_rsp_intf)
  ,.asfifo_f                          (a2c_push_f)
  ,.asfifo_af                         (/*UNCONNECTED*/)
  // Master response pop interface
  ,.asfifo_e                          (a2c_pop_empty)
  ,.asfifo_pop_valid                  (a2c_pop_data_valid)
  ,.asfifo_pop_data                   (a2c_pop_data)
  ,.ready                             (a2c_pop_ready)
  );
   assign a2c_pop_ready = ~mrdly_halt;

  // -------------------------------------------------------------------------------------
  // Master response pipeline delay
  // -------------------------------------------------------------------------------------
  struct packed {
    logic [MSTR_RSP_INTF_DATA_HIGH:1] high;
    logic [CC_MSTR_CPL_SEG_DATA_WD_NP:1] mid ;
    logic [MSTR_RSP_INTF_DATA_LOW:1] low ;
  } a2c_pop_data_sliced;
  assign a2c_pop_data_sliced = a2c_pop_data;
  assign s_a2c_pop_data = {a2c_pop_data_sliced.high,fn_data_w_par_wr(a2c_pop_data_sliced.mid),a2c_pop_data_sliced.low};


  assign a2c_pop_intf = {a2c_pop_data_valid, s_a2c_pop_data[CC_MSTR_RSP_INTF_WD-2:0]};

  DWC_pcie_amba_pdly
  
  #(
  .INTERFACE_DW                      (CC_MSTR_RSP_INTF_WD)
  )
  u_mrdly
  (
  // Clocks and resets
  .clk                               (core_clk)
  ,.rst_n                            (core_rst_n)
  // Master response interface bus
  ,.interface_bus                    (a2c_pop_intf)
  ,.pdly_halt                        (mrdly_halt)
  // Pipelined master response interface bus
  ,.interface_bus_valid              (ss_mstr_rsp_svalid)
  ,.pdly_interface_bus               (mrdly_interface_bus)
  ,.halt                             (ss_mstr_rsp_halt)
  );

  assign s_mstr_rsp_ready      = ~a2c_push_f;
  assign ss_mstr_rsp_intf      = mrdly_interface_bus;
  assign ss_mstr_rsp_svalid    = ss_mstr_rsp_intf[MSTR_RESP_INTF_SVALID_MSB];


  // Extract synchronised or delayed master response interface signals
  assign ss_mstr_rsp_sid             = ss_mstr_rsp_intf[MSTR_RESP_INTF_SID_MSB -:
                                                  CC_MAX_MSTR_TAG_PW];
  assign ss_mstr_rsp_sbyte_en        = ss_mstr_rsp_intf[MSTR_RESP_INTF_SBYTE_EN_MSB -:
                                                  L_MCBWR_DATANP_NUM_BYTES];
  assign ss_mstr_rsp_sdata           = ss_mstr_rsp_intf[MSTR_RESP_INTF_SDATA_MSB -:
                                                  L_MCBWR_DATAWP_WD];
  assign ss_mstr_rsp_sresp           = ss_mstr_rsp_intf[MSTR_RESP_INTF_SRESP_MSB -:
                                                 `DC_SRESP_WD];
  assign ss_mstr_smisc_info_cpl_stat = ss_mstr_rsp_intf[ MSTR_RESP_INTF_CPL_STAT: MSTR_RESP_INTF_CPL_STAT-2];

  assign ss_mstr_rsp_np_not_p        = ss_mstr_rsp_intf[MSTR_RESP_INTF_NP_NOT_P_MSB];
  assign ss_mstr_rsp_wr_not_rd       = ss_mstr_rsp_intf[MSTR_RESP_INTF_WR_NOT_RD_MSB];
  assign ss_mstr_rsp_ep              = ss_mstr_rsp_intf[MSTR_RESP_INTF_EP_MSB];
  assign ss_mstr_rsp_tc              = ss_mstr_rsp_intf[MSTR_RESP_INTF_TC_MSB -: DC_TC_WD];
  assign ss_mstr_rsp_bad_eot         = ss_mstr_rsp_intf[MSTR_RESP_INTF_BAD_EOT_MSB];
  assign ss_mstr_rsp_slast           = ss_mstr_rsp_intf[MSTR_RESP_INTF_SLAST_MSB];
  assign ss_mstr_rsp_last_pkt        = ss_mstr_rsp_intf[MSTR_RESP_INTF_LAST_PKT_MSB -: CC_MAX_MSTR_TAGS];
  assign ss_mstr_rsp_atomic_id       = ss_mstr_rsp_intf[MSTR_RESP_INTF_ATOP_ID_MSB];
  assign ss_mstr_rsp_atomic_all_rsp  = ss_mstr_rsp_intf[MSTR_RESP_INTF_ATOP_ALL_RSP_MSB];

  // u_mcf at core_clk
  assign mcbwr_clk                   = core_clk;
  assign mcbwr_rst_n                 = core_rst_n;

  assign mcbwr_req_np_valid          = radmx_mreq_np_valid;
  assign mcbwr_req_np_id             = radmx_mreq_np_id;
  assign mcbwr_req_np_ncbe           = radmx_ireq_np_ncbe;
  assign mcbwr_req_np_4kb_start_addr = radmx_ireq_np_4kb_start_addr;

  assign mcbwr_mstr_flush_req        = rstctl_mstr_flush_req;

  // -------------------------------------------------------------------------------------
  // Master Completion Formation block
  // -------------------------------------------------------------------------------------
  DWC_pcie_amba_mstr_cpl_formation
  
  #(
   .AXI_ENABLED                         (AXI_ENABLED)
  ,.CC_MAX_MSTR_TAGS                    (CC_MAX_MSTR_TAGS)
  ,.CC_MAX_MSTR_TAG_PW                  (CC_MAX_MSTR_TAG_PW)
  ,.CX_REMOTE_MAX_TAGS                  (CX_REMOTE_MAX_TAGS)
  ,.CX_REMOTE_MAX_TAGS_WD               (CX_REMOTE_MAX_TAGS_WD)
  ,.CC_MSTR_CPL_SEG_DATA_WD             (L_MCBWR_DATAWP_WD)
  ,.CC_MSTR_CPL_SEG_DATA_NUM_DWORDS     (L_MCBWR_DATANP_NUM_DWORDS)
  ,.CC_MSTR_CPL_SEG_DATA_NUM_BYTES      (L_MCBWR_DATANP_NUM_BYTES)
  //,.CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 (L_MCBWR_DATANP_NUM_BYTES_LOG2)
  ,.CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2 (CC_MSTR_CPL_SEG_DATA_NUM_BYTES_LOG2)
  ,.CC_MSTR_RSP_DATA_WD                 (CC_MSTR_RSP_DATA_WD)
  ,.CC_MSTR_CPL_DATA_WD                 (CC_MSTR_CPL_DATA_WD)
  ,.NP_REQ_ACTIVE_IDS_VEC               (NP_REQ_ACTIVE_IDS_VEC)
  ,.NP_REQ_START_LOW_ADDR_VEC           (NP_REQ_START_LOW_ADDR_VEC)
  )
  u_mcf
  (
  // Clocks and resets
  .core_clk                           (mcbwr_clk)
  ,.core_rst_n                        (mcbwr_rst_n)
  // Flush interface
  ,.rstctl_mstr_flush_req             (mcbwr_mstr_flush_req)
  // Master non-posted request info interface
  ,.radmx_mreq_np_valid               (mcbwr_req_np_valid)
  ,.radmx_mreq_np_id                  (mcbwr_req_np_id)
  ,.radmx_ireq_np_ncbe                (mcbwr_req_np_ncbe)
  ,.radmx_ireq_np_lookup_id           (mcbwr_req_np_id)
  ,.radmx_ireq_np_4kb_start_addr      (mcbwr_req_np_4kb_start_addr)
  // Master response interface
  ,.svalid                            (ss_mstr_rsp_svalid)
  ,.sid                               (ss_mstr_rsp_sid)
  ,.sbyte_en                          (ss_mstr_rsp_sbyte_en)
  ,.sdata                             (ss_mstr_rsp_sdata)
  ,.smisc_info_bad_eot                (ss_mstr_rsp_bad_eot)
  ,.smisc_info_ep                     (ss_mstr_rsp_ep)
  ,.smisc_info_tc                     (ss_mstr_rsp_tc)
  ,.sresp_np_not_p                    (ss_mstr_rsp_np_not_p)
  ,.sresp_wr_not_rd                   (ss_mstr_rsp_wr_not_rd)
  ,.sresp_status                      (ss_mstr_rsp_sresp)
  ,.smisc_info_cpl_stat               (ss_mstr_smisc_info_cpl_stat)
  ,.slast                             (ss_mstr_rsp_slast)
  ,.mcf_ready                         (ss_mstr_rsp_ready)
  // Master response tracker interface
  ,.mrtrk_last_pkt                    (ss_mstr_rsp_last_pkt)
  ,.mrtrk_atomic_id                   (ss_mstr_rsp_atomic_id)
  ,.mrtrk_atomic_all_rsp              (ss_mstr_rsp_atomic_all_rsp)
  // Master completion interface
  ,.mcf_hv                            (mcf_hv_nc)
  ,.mcf_dv                            (mcf_dv)
  ,.mcf_wr_seg_num                    (mcf_wr_seg_num)
  ,.mcf_ep                            (mcf_ep)
  ,.mcf_tc                            (mcf_tc)
  ,.mcf_status                        (mcf_status)
  ,.mcf_dw_en                         (mcf_dw_en)
  ,.mcf_data                          (mcf_data)
  ,.mcf_error                         (mcf_error)
  ,.mcf_bad_eot                       (mcf_bad_eot)
  ,.mcf_last_pkt_beat                 (mcf_last_pkt_beat)
  ,.mcf_eot                           (mcf_eot)
  ,.mcf_atop_wr_rsp                   (mcf_atop_wr_rsp)
  ,.mcf_atop_cpl_queue                (mcf_atop_cpl_queue)
  ,.mcctl_halt                        (pdlymcf_halt)
  );

  // -------------------------------------------------------------------------------------
  // Halt master response
  assign ss_mstr_rsp_halt = ~ss_mstr_rsp_ready;

  // -------------------------------------------------------------------------------------
  // Pipeline formatted master completion
  // {mcf_wr_seg_num, mcf_ep, mcf_tc, mcf_status, mcf_dw_en,
  // mcf_data, mcf_error, mcf_bad_eot, mcf_tlp_prefix, mcf_tlp_ln,
  // mcf_last_pkt_beat, mcf_atop_wr_rsp, mcf_atop_cpl_queue}
  // -------------------------------------------------------------------------------------
  wire [MCF_INTF_WD+1-1:0] s_mcf_intf, pdlymcf_intf;

  assign s_mcf_intf = { mcf_wr_seg_num
                      , mcf_ep
                      , mcf_tc
                      , mcf_status
                      , mcf_dw_en
                      , mcf_data
                      , mcf_error
                      , mcf_bad_eot
                      , mcf_last_pkt_beat
                      , mcf_eot
                      , mcf_atop_wr_rsp
                      , mcf_atop_cpl_queue
                      };

  // Instantiate pipe delay
  DWC_pcie_amba_pdly
  
  #(
  .INTERFACE_DW                      (MCF_INTF_WD+2)
  )
  u_pdlymcf
  (
  .clk                               (mcbwr_clk)
  ,.rst_n                            (mcbwr_rst_n)
  ,.interface_bus                    ({mcf_dv, s_mcf_intf})
  ,.pdly_halt                        (pdlymcf_halt)
  ,.interface_bus_valid              (pdlymcf_dv)
  ,.pdly_interface_bus               ({pdlymcf_dv, pdlymcf_intf})
  ,.halt                             (mcctl_halt)
  );

  assign { pdlymcf_wr_seg_num
         , pdlymcf_ep
         , pdlymcf_tc
         , pdlymcf_status
         , pdlymcf_dw_en
         , pdlymcf_data
         , pdlymcf_error
         , pdlymcf_bad_eot
         , pdlymcf_last_pkt_beat
         , pdlymcf_eot
         , pdlymcf_atop_wr_rsp
         , pdlymcf_atop_cpl_queue
         } = pdlymcf_intf;

  // -------------------------------------------------------------------------------------
  // Master Completion Control block
  // -------------------------------------------------------------------------------------
  DWC_pcie_amba_mstr_cpl_ctl
  
  #(
   .CX_REMOTE_MAX_TAGS                   (CX_REMOTE_MAX_TAGS                  )
  ,.CX_REMOTE_MAX_TAGS_WD                (CX_REMOTE_MAX_TAGS_WD               )
  ,.NSEGMENTS                            (NSEGMENTS                           )
  ,.NSEGMENTS_WD                         (NSEGMENTS_WD                        )
  ,.CX_NFUNC                             (CX_NFUNC                            )
  ,.CX_NFUNC_WD                          (CX_NFUNC_WD                         )
  ,.DC_DMA_TYPE_WIDTH                    (DC_DMA_TYPE_WIDTH                   )
  ,.CC_NUM_DMA_RD_CHAN                   (CC_NUM_DMA_RD_CHAN                  )
  ,.CC_NUM_DMA_WR_CHAN                   (CC_NUM_DMA_WR_CHAN                  )
  ,.CC_NUM_DMA_RD_CHAN_WIDTH             (CC_NUM_DMA_RD_CHAN_WIDTH            )
  ,.CC_NUM_DMA_WR_CHAN_WIDTH             (CC_NUM_DMA_WR_CHAN_WIDTH            )
  ,.CC_NUM_DMA_MAX_CHAN_WIDTH            (CC_NUM_DMA_MAX_CHAN_WIDTH           )
  ,.CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2 (CC_MSTR_CPL_SEG_DATA_NUM_DWORDS_LOG2)
  ,.CC_MSTR_CPL_DATA_SEG_DP              (CC_MSTR_CPL_DATA_SEG_DP             )
  ,.CC_MSTR_CPL_SEG_BUF_ADDR_WD          (CC_MSTR_CPL_SEG_BUF_ADDR_WD         )
  ,.CC_MSTR_CPL_SEG_DATA_NUM_DWORDS      (CC_MSTR_CPL_SEG_DATA_NUM_DWORDS     )
  ,.MSTR_CPL_SEG_BUF_INIT_SEG_SIZES      (MSTR_CPL_SEG_BUF_INIT_SEG_SIZES     )
  ,.CC_MSTR_CPL_QUEUE_DP                 (CC_MSTR_CPL_QUEUE_DP                )
  ,.CC_MSTR_CPL_QUEUE_DP_LOG2            (CC_MSTR_CPL_QUEUE_DP_LOG2           )
  ,.MSTR_CPL_CTRL_DELAY                  (CC_MSTR_CPL_SEG_BUF_LATENCY-1       )
  )
  u_mcctl
  (
  // Clocks and resets
  .core_clk                           (core_clk)
  ,.core_rst_n                        (core_rst_n)
  ,.mstr_aclk                         (mstr_aclk)
  ,.mstr_aresetn                      (mstr_aresetn)
  // Configuration
  ,.cfg_max_payload_size              (cfg_max_payload_size)
  // PCIe non-posted request info
  ,.radmx_mreq_np_valid               (radmx_mreq_np_valid)
  ,.radmx_ireq_np_lookup_id           (radmx_ireq_np_lookup_id)
  ,.radmx_ireq_np_4kb_start_addr      (radmx_ireq_np_4kb_start_addr)
  ,.radmx_ireq_np_dw_len_bytes        (radmx_ireq_np_dw_len_bytes)
  ,.radmx_ireq_np_func                (radmx_ireq_np_func)
  ,.radmx_ireq_np_ncbe                (radmx_ireq_np_ncbe)
  ,.radmx_mreq_np_last                (radmx_mreq_np_last)
  ,.radmx_ireq_np_dma_type            (radmx_ireq_np_dma_type)
  // SBC initialisation
  ,.mcctl_sb_init_i                   (mcctl_sb_init_i)
  ,.mcctl_sb_init_num_segs_i          (mcctl_sb_init_num_segs_i)
  ,.mcctl_sb_init_seg_sizes_i         (mcctl_sb_init_seg_sizes_i)
  // SBC push interface
  ,.mcctl_sb_reset_push_ptr           (mcctl_sb_reset_push_ptr)
  ,.mcctl_sb_reset_push_seg_i         (mcctl_sb_reset_push_seg_i)
  ,.mcctl_sb_push_start_i             (mcctl_sb_push_start_i)
  ,.mcctl_sb_push_i                   (mcctl_sb_push_i)
  ,.mcctl_sb_push_seg_i               (mcctl_sb_push_seg_i)
  ,.mcctl_sb_push_keep_i              (mcctl_sb_push_keep_i)
  ,.mcctl_sb_push_drop_i              (mcctl_sb_push_drop_i)
  ,.sbc_sb_full_m_1_o                 (sbc_sb_full_m_1_o)
  // SBC pop interface
  ,.mcctl_sb_reset_pop_ptr            (mcctl_sb_reset_pop_ptr)
  ,.mcctl_sb_reset_pop_seg_i          (mcctl_sb_reset_pop_seg_i)
  ,.mcctl_sb_pop_i                    (mcctl_sb_pop_i)
  ,.mcctl_sb_pop_seg_i                (mcctl_sb_pop_seg_i)
  ,.mcctl_sb_pop_look_i               (mcctl_sb_pop_look_i)
  ,.mcctl_sb_ram_rd_en                (mcctl_sb_ram_rd_en)
  ,.sbc_sb_pop_dw_en                  (s_sbc_dw_en)
  ,.sbc_sb_empty_o                    (sbc_sb_empty_o)
  ,.sbc_sb_empty_p_1_o                (sbc_sb_empty_p_1_o)
  ,.sbc_sb_init_done_o                (sbc_sb_init_done_o)
  // Pipelined master completion interface
  ,.mcf_dv                            (pdlymcf_dv)
  ,.mcf_wr_seg_num                    (pdlymcf_wr_seg_num)
  ,.mcf_ep                            (pdlymcf_ep)
  ,.mcf_tc                            (pdlymcf_tc)
  ,.mcf_status                        (pdlymcf_status)
  ,.mcf_error                         (pdlymcf_error)
  ,.mcf_last_pkt_beat                 (pdlymcf_last_pkt_beat)
  ,.mcf_atop_wr_rsp                   (pdlymcf_atop_wr_rsp)
  ,.mcf_atop_cpl_queue                (pdlymcf_atop_cpl_queue)
  ,.mcctl_halt                        (mcctl_halt)
  // Client completion interface
  ,.mcctl_hv                          (mcctl_hv)
  ,.mcctl_fmt                         (mcctl_fmt)
  ,.mcctl_type                        (mcctl_type)
  ,.mcctl_dv                          (mcctl_dv)
  ,.mcctl_eot                         (mcctl_eot)
  ,.mcctl_last                        (mcctl_last)
  ,.mcctl_ireq_np_lookup_id           (mcctl_ireq_np_lookup_id)
  ,.mcctl_dw_len_bytes                (mcctl_dw_len_bytes)
  ,.mcctl_func                        (mcctl_func)
  ,.mcctl_ep                          (mcctl_ep)
  ,.mcctl_tc                          (mcctl_tc)
  ,.mcctl_status                      (mcctl_status)
  ,.mcctl_dma_type                    (mcctl_dma_type)
  ,.mcctl_dma_chan                    (mcctl_dma_chan)
  ,.halt                              (s_cpl_halt)
  ,.cpl_q_dma_wr_valid                (cpl_q_dma_wr_valid        )
  ,.cpl_q_dma_wr_seg_num              (cpl_q_dma_wr_seg_num      )
  ,.cpl_q_dma_wr_beat_len             (cpl_q_dma_wr_beat_len     )
  ,.cpl_q_dma_wr_dw_len               (cpl_q_dma_wr_dw_len       )
  ,.cpl_q_dma_wr_status               (cpl_q_dma_wr_status       )
  ,.cpl_q_dma_wr_ep                   (cpl_q_dma_wr_ep           )
  ,.cpl_q_dma_wr_last_pkt_beat        (cpl_q_dma_wr_last_pkt_beat)
  ,.cpl_q_dma_rd_ready                (cpl_q_dma_rd_ready        )
  ,.cpl_q_dma_rd_valid                (cpl_q_dma_rd_valid        )
  ,.cpl_q_dma_rd_dma_chan             (cpl_q_dma_rd_dma_chan     )
  ,.cpl_q_dma_rd_dma_type             (cpl_q_dma_rd_dma_type     )
  ,.cpl_q_dma_rd_seg_num              (cpl_q_dma_rd_seg_num      )
  ,.cpl_q_dma_rd_beat_len             (cpl_q_dma_rd_beat_len     )
  ,.cpl_q_dma_rd_dw_len               (cpl_q_dma_rd_dw_len       )
  ,.cpl_q_dma_rd_status               (cpl_q_dma_rd_status       )
  ,.cpl_q_dma_rd_ep                   (cpl_q_dma_rd_ep           )
  ,.cpl_q_dma_rd_tc                   (cpl_q_dma_rd_tc           )
  ,.cpl_q_dma_rd_last_pkt_beat        (cpl_q_dma_rd_last_pkt_beat)
  );

  DWC_pcie_amba_mstr_cpl_dma_rordr
   #(
     .CX_REMOTE_MAX_TAGS           (CX_REMOTE_MAX_TAGS          )
    ,.CX_REMOTE_MAX_TAGS_WD        (CX_REMOTE_MAX_TAGS_WD       )
    ,.DC_MCB_MAX_CPL_NUM_DWORDS_WD (DC_MCB_MAX_CPL_NUM_DWORDS_WD)
    ,.DC_CPL_STATUS_WD             (DC_CPL_STATUS_WD            )
    ,.DC_DMA_TYPE_WIDTH            (DC_DMA_TYPE_WIDTH           )
    ,.CC_NUM_DMA_RD_CHAN           (CC_NUM_DMA_RD_CHAN          )
    ,.CC_NUM_DMA_WR_CHAN           (CC_NUM_DMA_WR_CHAN          )
    ,.CC_NUM_DMA_RD_CHAN_WIDTH     (CC_NUM_DMA_RD_CHAN_WIDTH    )
    ,.CC_NUM_DMA_WR_CHAN_WIDTH     (CC_NUM_DMA_WR_CHAN_WIDTH    )
    ,.CC_NUM_DMA_MAX_CHAN_WIDTH    (CC_NUM_DMA_MAX_CHAN_WIDTH   )
  ) u_dmarordr(
     .core_clk                (core_clk                  )
    ,.core_rst_n              (core_rst_n                )
    ,.radmx_mreq_np_valid     (radmx_mreq_np_valid       )
    ,.radmx_mreq_np_last      (radmx_mreq_np_last        )
    ,.radmx_ireq_np_lookup_id (radmx_ireq_np_lookup_id   )
    ,.radmx_ireq_np_dma_chan  (radmx_ireq_np_dma_chan    )
    ,.radmx_ireq_np_dma_type  (radmx_ireq_np_dma_type    )
    ,.dma_mcb_rdll_halt       (dma_mcb_rdll_halt         )
    ,.dma_mcb_wrll_halt       (dma_mcb_wrll_halt         )
    ,.cpl_q_wr_valid          (cpl_q_dma_wr_valid        )
    ,.cpl_q_wr_seg_num        (cpl_q_dma_wr_seg_num      )
    ,.cpl_q_wr_beat_len       (cpl_q_dma_wr_beat_len     )
    ,.cpl_q_wr_dw_len         (cpl_q_dma_wr_dw_len       )
    ,.cpl_q_wr_status         (cpl_q_dma_wr_status       )
    ,.cpl_q_wr_ep             (cpl_q_dma_wr_ep           )
    ,.cpl_q_wr_last_pkt_beat  (cpl_q_dma_wr_last_pkt_beat)
    ,.cpl_q_rd_ready          (cpl_q_dma_rd_ready        )
    ,.cpl_q_rd_valid          (cpl_q_dma_rd_valid        )
    ,.cpl_q_rd_dma_chan       (cpl_q_dma_rd_dma_chan     )
    ,.cpl_q_rd_dma_type       (cpl_q_dma_rd_dma_type     )
    ,.cpl_q_rd_seg_num        (cpl_q_dma_rd_seg_num      )
    ,.cpl_q_rd_beat_len       (cpl_q_dma_rd_beat_len     )
    ,.cpl_q_rd_dw_len         (cpl_q_dma_rd_dw_len       )
    ,.cpl_q_rd_status         (cpl_q_dma_rd_status       )
    ,.cpl_q_rd_ep             (cpl_q_dma_rd_ep           )
    ,.cpl_q_rd_last_pkt_beat  (cpl_q_dma_rd_last_pkt_beat)
    );

  // Temporarily tying this signal to 0
  assign cpl_q_dma_rd_tc = '0;


  // -------------------------------------------------------------------------------------
  // Segment Buffer Control block
  // -------------------------------------------------------------------------------------
  assign srst_n = 1'b1;
  assign sb_seg_start_i = {CX_REMOTE_MAX_TAGS*CC_MSTR_CPL_SEG_BUF_ADDR_WD{1'b0}};
  assign sb_seg_end_i = {CX_REMOTE_MAX_TAGS*CC_MSTR_CPL_SEG_BUF_ADDR_WD{1'b0}};

 // -------------------------------------------------------------------------------------

   wire   mcf_data_chk_en;
   assign mcf_data_chk_en = pdlymcf_dv && !mcctl_halt;


   // Strip parity bits before calculating ECC
   assign s_pdlymcf_data = fn_data_wo_par_wr(pdlymcf_data);
   // -------------------------------------------------------------------------------------
   // Does the ECC calculation
   // -------------------------------------------------------------------------------------


  assign s_mcf_sb_push_data_ras_i = {pdlymcf_data, pdlymcf_dw_en, pdlymcf_bad_eot};

  wire unconn_sb_par_chk_val_o;

  assign s_mcctl_sb_pop_i        = mcctl_sb_pop_i;
  assign s_mcctl_sb_pop_seg_i    = mcctl_sb_pop_seg_i;
  assign s_mcctl_sb_ram_rd_en    = mcctl_sb_ram_rd_en;

  assign s_mcctl_sb_push_start_i = mcctl_sb_push_start_i;
  assign s_mcctl_sb_push_i       = mcctl_sb_push_i;
  assign s_mcctl_sb_push_seg_i   = mcctl_sb_push_seg_i;
  assign s_mcctl_sb_push_keep_i  = mcctl_sb_push_keep_i;
  assign s_mcctl_sb_push_drop_i  = mcctl_sb_push_drop_i;
  assign ss_mcf_sb_push_data_ras_i = s_mcf_sb_push_data_ras_i;


  DW_sbc
  
  #(
  .SEGS                              (CX_REMOTE_MAX_TAGS)
  ,.SEG_W                            (CX_REMOTE_MAX_TAGS_WD)
  ,.RAM_W                            (CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC_WP)
  ,.RAM_WEC                          (CC_MSTR_CPL_SEG_BUF_DATA_WD)
  ,.RAM_AW                           (CC_MSTR_CPL_SEG_BUF_ADDR_WD)
  ,.GEN_STARTEND_ADDRS               (GEN_STARTEND_ADDRS)
  ,.HOLD_RADDR                       (HOLD_RADDR)
  ,.NHQ                              (1)
  )
  u_sbc
  (
   // Clocks and resets
  .clk                             (core_clk)
  ,.rst_n                          (core_rst_n)
  ,.srst_n                         (srst_n)
  // Initialisation
  ,.sb_init_i                      (mcctl_sb_init_i)
  ,.sb_init_num_segs_i             (mcctl_sb_init_num_segs_i)
  ,.sb_init_seg_sizes_i            (mcctl_sb_init_seg_sizes_i)
  ,.sb_init_done_o                 (sbc_sb_init_done_o)
  // Push interface
  ,.sb_push_start_i                (s_mcctl_sb_push_start_i)
  ,.sb_push_i                      (s_mcctl_sb_push_i)
  ,.sb_push_seg_i                  (s_mcctl_sb_push_seg_i)
   ,.sb_push_data_i                (ss_mcf_sb_push_data_ras_i)
  ,.sb_push_keep_i                 (s_mcctl_sb_push_keep_i)
  ,.sb_push_drop_i                 (s_mcctl_sb_push_drop_i)
  ,.sb_reset_push_ptr              (mcctl_sb_reset_push_ptr)
  ,.sb_reset_push_seg_i            (mcctl_sb_reset_push_seg_i)
  ,.sb_full_o                      (sbc_sb_full_o)
  ,.sb_full_m_1_o                  (sbc_sb_full_m_1_o)
  ,.sb_full_m_2_o                  (sbc_sb_full_m_2_o)
  // Pop interface
  ,.sb_pop_i                       (s_mcctl_sb_pop_i)
  ,.sb_pop_look_i                  (mcctl_sb_pop_look_i)
  ,.sb_pop_seg_i                   (s_mcctl_sb_pop_seg_i)
  ,.sb_pop_data_o                  (sbc_sb_pop_data_o)
  ,.sb_seg_pkt_avail_o             (sbc_sb_seg_pkt_avail_o_nc)
  ,.sb_reset_pop_ptr               (mcctl_sb_reset_pop_ptr)
  ,.sb_reset_pop_seg_i             (mcctl_sb_reset_pop_seg_i)
  ,.sb_empty_o                     (sbc_sb_empty_o)
  ,.sb_empty_p_1_o                 (sbc_sb_empty_p_1_o)
  // Segment start and end address interface, not used
  ,.sb_seg_start_i                 (sb_seg_start_i)
  ,.sb_seg_end_i                   (sb_seg_end_i)
  // RAM interface
  ,.sb_wen_n_o                     (sbc_sb_wen_n_o)
  ,.sb_waddr_o                     (sbc_sb_waddr_o)
  ,.sb_wdata_o                     (sbc_sb_wdata_ras_o)

  ,.sb_raddr_o                     (sbc_sb_raddr_o)
  ,.sb_ren_n_o                     (sbc_sb_ren_n_o_nc) // Tied to zero internal to SBC
  ,.sb_rdata_i                     (sb_rdata_i)
  ,.sb_par_chk_val_o               (unconn_sb_par_chk_val_o)
  );

  //-------------------------------------------------------------------------------------
  // Register RAM Write Control and Data and RAM Read Control Signals
  //-------------------------------------------------------------------------------------
  localparam SB_RAM_CTL_INTF_WD = 1 + CC_MSTR_CPL_SEG_BUF_ADDR_WD + CC_MSTR_CPL_SEG_BUF_DATA_WD
                                  + CC_MSTR_CPL_SEG_BUF_ADDR_WD + 1;

  wire                                               sbc_sb_wen_o;
  wire                                               sbcdly_sb_wen_o;
  wire [CC_MSTR_CPL_SEG_BUF_ADDR_WD-1:0]             sbcdly_sb_waddr_o;
  wire [CC_MSTR_CPL_SEG_BUF_DATA_WD-1:0]             sbcdly_sb_wdata_o;
  wire [CC_MSTR_CPL_SEG_BUF_ADDR_WD-1:0]             sbcdly_sb_raddr_o;
  wire                                               sbcdly_sb_ram_rd_en;
  wire [SB_RAM_CTL_INTF_WD-1:0]                      sbc_sb_ctl_intf, sbcdly_sb_ctl_intf;

  assign sbc_sb_wen_o = ~sbc_sb_wen_n_o;


    // Check the parity before adding the ECC

  wire [CC_MSTR_CPL_SEG_DATA_WD-1:0]       sbc_sb_wdata;                 // 576
  wire [L_MCBWR_DATANP_NUM_DWORDS-1:0]     sbcsb_dw_en;
  wire                                     sbc_sb_bad_eot;

  // Serializing the sbc_sb_wdata_ras_o to remove the parity from the data
  assign {sbc_sb_wdata,
          sbcsb_dw_en,
          sbc_sb_bad_eot} = sbc_sb_wdata_ras_o;

    ras_dp_pipe
     #(
     .PIPELINE_TYPE             (0                                 ),  // 0: delay_n
     .RESETVAL                  (0                                 ),
     .N_STAGES                  (0                                 ),
     .CAN_STALL                 (0                                 ),
     .RESET_STALL               (0                                 ),
     .BUS_PROTECT_GEN_EN        (0                                 ),  // 0: Bus Protection Generator is not present
     .BUS_PROTECT_CHK_EN        (1                                 ),  // 1: Bus Protection Checker is present (ECC/Parity)
     .PROT_TYPE                 (1                                 ),  // 0=Ecc, 1=Simple Parity
     .PROT_RANGE                (CX_RAS_PROT_RANGE                 ),  // Number of bits to calculate parity/ECC on
     .PROT_WD                   (NUM_DATA_PAR_BLOCKS_S             ),
     .PARITY_MODE               (CX_RAS_PARITY_MODE                ),
     .PROT_CORRECT_EN           (0                                 ),  // 0: no correction on single-errors, 1: correction on single-errors
     .TOTAL_WIDTH               (CC_MSTR_CPL_SEG_DATA_WD_NP        ),
     .EXCLUDE_PROT_WIDTH        (0                                 ),
     .RAS_DP_PROT_CHK_ID_BASE   (IB_SB_DT_RAS_ID                   )
   ) u_mcf_data_chk (
     .clk                       ( core_clk                           ),
     .rst_n                     ( core_rst_n                         ),
     .din                       ( fn_data_wo_par(sbc_sb_wdata)       ),
     .din_prot                  ( fn_prot_chkin_dr(sbc_sb_wdata)     ),
     .dout                      ( /* NC */                           ),
     .dout_prot                 ( /* NC */                           ),
     .en                        ( 1'b1                               ),
     .bypass                    ( 1'b0                               ),
     .stall                     ( 1'b0                               ),
     .stallout                  ( /* Not Connected */                ),
     .valid_in                  ( sbc_sb_wen_o                       ),
     .halt_out                  ( /* Not Connected */                ),
     .valid_out                 ( /* Not Connected */                ),
     .halt_in                   (1'b0                                ),
     .ras_dp_err_inband_kbd_in  (1'b0                                ),
     .ras_dp_err_inband_kbd_out ( /* Not Connected */                ),
     .ras_dp_err_log            ( axi_ib_mcpl_sb_dt_ras_dp_err_log   )
       ,
       .ras_dp_err_inj          ( core_clk_hp_mstr_ras_dp_err_inj    )
     );

    assign axi_ras_par_ib_mcpl_sb_dt_pulse = axi_ib_mcpl_sb_dt_ras_dp_err_log.valid;

   // Removing the pairty before generating the ECC
    assign s_sbc_sb_wdata_o = {fn_data_wo_par(sbc_sb_wdata),
                               sbcsb_dw_en,
                               sbc_sb_bad_eot};

    ras_dp_pipe
     #(
     .PIPELINE_TYPE             (0                                    ),  // 0: delay_n
     .RESETVAL                  (0                                    ),
     .N_STAGES                  (0                                    ),
     .CAN_STALL                 (0                                    ),
     .RESET_STALL               (0                                    ),
     .BUS_PROTECT_GEN_EN        (1                                    ),  // 0: Bus Protection Generator is not present
     .BUS_PROTECT_CHK_EN        (0                                    ),  // 1: Bus Protection Checker is present (ECC/Parity)
     .PROT_TYPE                 (0                                    ),  // 0=Ecc, 1=Simple Parity
     .PROT_RANGE                (CX_RAS_RAM_PROT_RANGE                ),  // Number of bits to calculate parity/ECC on
     .PROT_WD                   (ECC_WIDTH                            ),
     .PARITY_MODE               (CX_RAS_PARITY_MODE                   ),
     .PROT_CORRECT_EN           (0                                    ),  // 0: no correction on single-errors, 1: correction on single-errors
     .TOTAL_WIDTH               (CC_MSTR_CPL_SEG_BUF_ADDR_WD + CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC), // RAM_ADDR_WIDTH + DATA_WIDTH
     .EXCLUDE_PROT_WIDTH        (0                                    ),
     .RAS_DP_PROT_CHK_ID_BASE   ( /* NC */                            ),
     .ADDR_LOG_EN               (1                                    ),
     .ADDR_ECC_PROT_EN          (1                                    ),
     .ADDR_INDEX                (CC_MSTR_CPL_SEG_BUF_DATA_WD_NOECC    ),
     .ADDR_WD                   (CC_MSTR_CPL_SEG_BUF_ADDR_WD          )
   ) u_eccg (
     .clk                       ( core_clk                            ),
     .rst_n                     ( core_rst_n                          ),
     .din                       ( {sbc_sb_waddr_o, s_sbc_sb_wdata_o}  ),  // Addr + Data
     .din_prot                  ( {ECC_WIDTH{1'b0}}                   ),
     .dout                      ( /* NC */                            ),
     .dout_prot                 ( mcf_ras_ecc                         ),
     .en                        ( 1'b1                                ),
     .bypass                    ( 1'b0                                ),
     .stall                     ( 1'b0                                ),
     .stallout                  ( /* Not Connected */                 ),
     .valid_in                  ( sbc_sb_wen_o                        ),
     .halt_out                  ( /* Not Connected */                 ),
     .valid_out                 ( /* Not Connected */                 ),
     .halt_in                   (1'b0                                 ),
     .ras_dp_err_inband_kbd_in  (1'b0                                 ),
     .ras_dp_err_inband_kbd_out ( /* Not Connected */                 ),
     .ras_dp_err_log            ( /* Not Connected */                 )
       ,
       .ras_dp_err_inj          ({(RAS_ERROR_INJ_LOG_WD){1'b0}}       )
     );

   assign ss_sbc_sb_wdata_o = {mcf_ras_ecc, s_sbc_sb_wdata_o} ;

  assign sbc_sb_ctl_intf = { sbc_sb_wen_o
                           , sbc_sb_waddr_o
                           , ss_sbc_sb_wdata_o
                           , sbc_sb_raddr_o
                           , s_mcctl_sb_ram_rd_en
                           };

  delay_n
  
  #(
  .WD           (SB_RAM_CTL_INTF_WD)
  ,.N           (CC_MSTR_CPL_CTL_RAM_REGIN)
  )
  u_sbcdly
  (
  .clk          (core_clk)
  ,.rst_n       (core_rst_n)
  ,.clear       (1'b0)
  ,.din         (sbc_sb_ctl_intf)
  ,.dout        (sbcdly_sb_ctl_intf)
  );

  assign { sbcdly_sb_wen_o
         , sbcdly_sb_waddr_o
         , sbcdly_sb_wdata_o
         , sbcdly_sb_raddr_o
         , sbcdly_sb_ram_rd_en
         } = sbcdly_sb_ctl_intf;

  // -------------------------------------------------------------------------------------
  // External Segment Buffer RAM interface
  // -------------------------------------------------------------------------------------
  // Write interface
  assign mcb_sb_wen    = sbcdly_sb_wen_o;
  assign mcb_sb_waddr  = sbcdly_sb_waddr_o;
  assign mcb_sb_wdata  = sbcdly_sb_wdata_o;
  // Read interface
  assign mcb_sb_ren    = sbcdly_sb_ram_rd_en;
  assign mcb_sb_raddr  = sbcdly_sb_raddr_o;
  assign sb_rdata_i    = sb_rdata;

  // -------------------------------------------------------------------------------------
  // Align RAM read address to RAM read data. Read address used to log
  // location of bit error.
  // {RAM read address, read data valid}
  // -------------------------------------------------------------------------------------

  delay_n
  
  #(
   .WD         (CC_MSTR_CPL_SEG_BUF_ADDR_WD+1),
   .N          (CC_MSTR_CPL_SEG_BUF_LATENCY)
   )
   u_algn_addr(
     .clk      (core_clk),
     .rst_n    (core_rst_n),
     .clear    (1'b0),
     .din      ({sbc_sb_raddr_o, s_mcctl_sb_pop_i}),
     .dout     ({s_algn_sbc_sb_raddr_o, s_algn_sb_pop_i})
   );

  // -------------------------------------------------------------------------------------
  // Register RAM read data
  // -------------------------------------------------------------------------------------

  delay_n
  
  #(
   .WD(CC_MSTR_CPL_SEG_BUF_DATA_WD),
   .N(1)
  )
  u_sb_pipe
  (
  .clk          (core_clk),
  .rst_n        (core_rst_n),
  .clear        (1'b0),
  .din          (sbc_sb_pop_data_o),
  .dout         (s_sbc_sb_pop_data_o)
  );

   wire [ECC_WIDTH-1:0]                       s_pop_sbc_ecc;
   wire [CC_MSTR_CPL_SEG_DATA_WD_NP-1:0]      s_pop_sbc_data;
   wire [CC_MSTR_CPL_SEG_DATA_NUM_DWORDS-1:0] s_pop_sbc_dw_en;
   wire                                       s_pop_sbc_bad_eot;
   wire [CC_MSTR_CPL_SEG_BUF_ADDR_WD-1:0]     s_pop_sbc_addr, s_sbc_addr_ras_dp_pipe;

   // Extract RAM data
   assign {s_pop_sbc_ecc,
           s_pop_sbc_data,
           s_pop_sbc_dw_en,
           s_pop_sbc_bad_eot} = s_sbc_sb_pop_data_o;

   // ---------------------------------------------------------------------------
   // RAS ECC checking
   // ---------------------------------------------------------------------------
   assign cfg_ras_recc_ib_mcpl_sb_correct_n       = ~cfg_ras_recc_ib_mcpl_sb_correct;
   assign axi_ras_recc_cnt_ib_mcpl_sb_addr        = s_algn_sbc_sb_raddr_o;
    ras_dp_pipe
     #(
    .PIPELINE_TYPE             (0                                     ), // 0: delay_n
    .RESETVAL                  (0                                     ),
    .N_STAGES                  (0                                     ),
    .CAN_STALL                 (0                                     ),
    .RESET_STALL               (0                                     ),
    .BUS_PROTECT_GEN_EN        (0                                     ),  // 0: Bus Protection Generator is not present
    .BUS_PROTECT_CHK_EN        (1                                     ),  // 1: Bus Protection Checker is present (ECC/Parity)
    .PROT_TYPE                 (0                                     ),  // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                (CX_RAS_RAM_PROT_RANGE                 ), // Number of bits to calculate parity/ECC on
    .PROT_WD                   (ECC_WIDTH                             ), // we need one more bit because of the address
    .PARITY_MODE               (CX_RAS_PARITY_MODE                    ),
    .PROT_CORRECT_EN           (1                                     ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH               (CC_MSTR_CPL_SEG_BUF_ADDR_WD +
                                CC_MSTR_CPL_SEG_DATA_WD_NP +
                                CC_MSTR_CPL_SEG_DATA_NUM_DWORDS+1     ),
    .EXCLUDE_PROT_WIDTH        (0                                     ),
    .RAS_DP_PROT_CHK_ID_BASE   (SB_RAS_ID                             ),
    .ADDR_LOG_EN               (1                                    ),
    .ADDR_ECC_PROT_EN          (1                                    ),
    .ADDR_INDEX                (CC_MSTR_CPL_SEG_DATA_WD_NP +
                                CC_MSTR_CPL_SEG_DATA_NUM_DWORDS+1     ),
    .ADDR_WD                   (CC_MSTR_CPL_SEG_BUF_ADDR_WD           )
  ) u_echk (
    .clk                       ( core_clk                             ),
    .rst_n                     ( core_rst_n                           ),
    .din                       ({s_algn_sbc_sb_raddr_o,
                                 s_pop_sbc_data,
                                 s_pop_sbc_dw_en,
                                 s_pop_sbc_bad_eot
                                 }                                    ),
    .din_prot                  ( s_pop_sbc_ecc                        ),
    .dout                      ({s_sbc_addr_ras_dp_pipe,
                                 s_sbc_data_ras_dp_pipe,
                                 s_sbc_dw_en_ras_dp_pipe,
                                 s_sbc_bad_eot_ras_dp_pipe
                                 }                                    ), //Data is corrected
    .dout_prot                 ( /* Not Connected */                  ),
    .en                        (1'b1                                  ),
    .bypass                    (1'b0                                  ),
    .stall                     (1'b0                                  ),
    .stallout                  ( /* Not Connected */                  ),
    .valid_in                  ( s_algn_sb_pop_i                      ),
    .halt_out                  ( /* Not Connected */                  ),
    .valid_out                 ( /* Not Connected */                  ),
    .halt_in                   (1'b0                                  ),
    .ras_dp_err_inband_kbd_in  (1'b0                                  ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */                  ),
    .ras_dp_err_log            (axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log)
      ,
      .ras_dp_err_inj          (core_clk_hp_mstr_ras_dp_err_inj       )
    );

  // Extract and detect Error type (correctable) from ras_dp_pipe.log
  assign axi_ras_recc_corr_cnt_ib_mcpl_sb_pulse   = (axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == CORRECTABLE) && s_algn_sb_pop_i;

  // Extract and detect Error type (Uncorrectable) from ras_dp_pipe.log
  assign axi_ras_recc_ucorr_cnt_ib_mcpl_sb_pulse = (axi_recc_cnt_ib_mcpl_sb_ras_dp_err_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == UNCORRECTABLE) && s_algn_sb_pop_i;

  assign {s_sbc_data, s_sbc_dw_en, s_sbc_bad_eot} =  { s_sbc_data_ras_dp_pipe, s_sbc_dw_en_ras_dp_pipe, s_sbc_bad_eot_ras_dp_pipe};


      // Add parity bits after ECC check
      assign ss_sbc_data = fn_data_w_par_rd(s_sbc_data);

  // -------------------------------------------------------------------------------------
  // Build completion control interface
   assign s_cpl_intf = {  mcctl_dv
                          , mcctl_hv
                          , mcctl_dw_len_bytes
                          , mcctl_ireq_np_lookup_id
                          , mcctl_fmt
                          , mcctl_type
                          , mcctl_status
                          , mcctl_ep
                          , mcctl_tc
                          , mcctl_func
                          , mcctl_dma_type
                          , mcctl_dma_chan
                          , mcctl_last
                          , ss_sbc_data
                          , s_sbc_bad_eot
                          , mcctl_eot
                          , s_sbc_dw_en
                          };

  // -------------------------------------------------------------------------------------
  // Add latency buffer to absorb in-flight RAM read completions when
  // completions are stalled by the native core.
  // Depth of storage FIFO equates to the round trip delay (measured in cycles)
  // from assertion of the pop (mcctl_sb_pop_i) to the presentation of the RAM read data
  // at ram_latency_pipe module.
 // -------------------------------------------------------------------------------------
   ram_latency_pipe
   
   #(
    .PIPE_WIDTH          (CPL_INTF_WD),
    .PIPE_INPUT_REG      (1),
    .PIPE_LATENCY        (CC_MSTR_CPL_SEG_BUF_LATENCY),
    .PIPE_EXTRA_STORAGE  (1)
   )
   u_rrlb // RAM Read Latency Buffer
   (
     .core_clk              (core_clk),
     .core_rst_n            (core_rst_n),
     // Aligned RAM completion data and control interface
     .pipe_in_data_valid    (mcctl_sb_pop_i), // SBC pop signal
     .halt_out              (dly1_halt), // Stop reading from the RAM
     .pipe_in_data          (s_cpl_intf),
     // Completion data and control interface
     .pipe_out_data_valid   ( /* UNCONNECTED */ ),
     .pipe_out_data         (dly1_interface_bus),
     .halt_in               (s_client_cpl_halt)
   );

  assign s_cpl_halt  = dly1_halt;

  assign {
          s_client_cpl_dv
          ,s_client_cpl_hdr_info
          ,s_client_cpl_data
          ,s_client_cpl_bad_eot
          ,s_client_cpl_eot
          ,s_client_cpl_dw_en
          } = dly1_interface_bus;

  assign s_client_cpl_hv = s_client_cpl_hdr_info[MCCTL_HDR_INFO_WD-1];

   // BAD EOT needs to qualified with EOT
   assign s_client_cpl_bad_eot_g   = s_client_cpl_bad_eot & s_client_cpl_eot;

  // -------------------------------------------------------------------------------------
  // Client Completion Data Word Alignment block (optional)
  // -------------------------------------------------------------------------------------
  DWC_pcie_amba_client_cpl_dword_algn
  
  #(
   .HDR_INFO_WD                      (MCCTL_HDR_INFO_WD)
   ,.CC_MSTR_CPL_SEG_DATA_WD         (CC_MSTR_CPL_SEG_DATA_WD)
   ,.CC_MSTR_CPL_SEG_DATA_NUM_DWORDS (CC_MSTR_CPL_SEG_DATA_NUM_DWORDS)
   ,.CC_MSTR_CPL_SEG_DATA_SIZE_ENC   (CC_MSTR_CPL_SEG_DATA_SIZE_ENC)
  )
  u_dwa
  (
  .core_clk                           (core_clk)
  ,.core_rst_n                        (core_rst_n)
  // Buffered client completion interface
  ,.mcctl_hv                          (s_client_cpl_hv)
  ,.mcctl_dv                          (s_client_cpl_dv)
  ,.mcctl_eot                         (s_client_cpl_eot)
  ,.mcctl_hdr_info                    (s_client_cpl_hdr_info)
  ,.sbc_rdata                         (s_client_cpl_data)
  ,.sbc_rdw_en                        (s_client_cpl_dw_en)
  ,.sbc_bad_eot                       (s_client_cpl_bad_eot_g)
  ,.dwa_halt                          (dwa_halt)
  // DWORD aligned client completion interface
  ,.dwa_dv                            (dwa_dv)
  ,.dwa_hdr_info                      (dwa_hdr_info)
  ,.dwa_rdw_en                        (dwa_rdw_en_nc)
  ,.dwa_data                          (dwa_data)
  ,.dwa_bad_eot                       (dwa_bad_eot)
  ,.dwa_eot                           (dwa_eot)
  ,.halt                              (ss_client_cpl_halt)
  );

  assign ss_client_cpl_dv       = dwa_dv;
  assign ss_client_cpl_hdr_info = dwa_hdr_info;
  assign ss_client_cpl_data     = dwa_data;
  assign ss_client_cpl_bad_eot  = dwa_bad_eot;
  assign ss_client_cpl_eot      = dwa_eot;
  assign s_client_cpl_halt      = dwa_halt;

  assign sss_client_cpl_dv       = ss_client_cpl_dv;
  assign sss_client_cpl_hdr_info = ss_client_cpl_hdr_info;
  assign sss_client_cpl_data     = ss_client_cpl_data;
  assign sss_client_cpl_bad_eot  = ss_client_cpl_bad_eot;
  assign sss_client_cpl_eot      = ss_client_cpl_eot;

  assign ss_client_cpl_halt      = ccdly2_halt;

  assign sss_client_cpl_intf = {sss_client_cpl_dv,
                                sss_client_cpl_hdr_info,
                                sss_client_cpl_data,
                                sss_client_cpl_bad_eot,
                                sss_client_cpl_eot
                               };

  // -------------------------------------------------------------------------------------
  // Client Completion Pipe Delay block
  // -------------------------------------------------------------------------------------
  localparam L_CCPDLY_DEPTH = 1;

  logic [L_CCPDLY_DEPTH-1:0] [MCB_CPL_INTF_WD-1:0] s_ccpdly_interface_bus       ;
  logic [L_CCPDLY_DEPTH-1:0]                       s_ccpdly_pdly_halt           ;
  logic [L_CCPDLY_DEPTH-1:0]                       s_ccpdly_interface_bus_valid ;
  logic [L_CCPDLY_DEPTH-1:0] [MCB_CPL_INTF_WD-1:0] s_ccpdly_pdly_interface_bus  ;
  logic [L_CCPDLY_DEPTH-1:0]                       s_ccpdly_halt                ;
  logic s_filter_active;
  logic s_halt;

  DWC_pcie_amba_pdly
   #(
   .INTERFACE_DW                      (MCB_CPL_INTF_WD             )
  ) u_ccpdly[L_CCPDLY_DEPTH](
   .clk                               (core_clk                    )
  ,.rst_n                             (core_rst_n                  )
  ,.interface_bus                     (s_ccpdly_interface_bus      )
  ,.pdly_halt                         (s_ccpdly_pdly_halt          )
  ,.interface_bus_valid               (s_ccpdly_interface_bus_valid)
  ,.pdly_interface_bus                (s_ccpdly_pdly_interface_bus )
  ,.halt                              (s_ccpdly_halt               )
  );

  assign {ccdly2_interface_bus, s_ccpdly_interface_bus} = {s_ccpdly_pdly_interface_bus, sss_client_cpl_intf};
  assign {s_ccpdly_halt       , ccdly2_halt           } = {s_halt                     , s_ccpdly_pdly_halt };

  always_comb begin : s_dmapdly_interface_bus_valid_PROC
    s_ccpdly_interface_bus_valid = '0;
    foreach (s_ccpdly_interface_bus_valid[i]) begin
      s_ccpdly_interface_bus_valid[i] = s_ccpdly_pdly_interface_bus[i][MCB_CPL_INTF_WD-1] | s_ccpdly_pdly_interface_bus[i][MCB_CPL_INTF_WD-2];
    end
  end

  assign mcb_prv_dma = '0;
  assign mcb_prv_dma_chan = '0;

  assign s_filter_active = 1'b0;
  assign s_halt = halt;

  logic s_mcb_hv;
  logic s_mcb_dv;
  logic s_mcb_eot;

  // -------------------------------------------------------------------------------------
  // Assign outputs
  // -------------------------------------------------------------------------------------
  // {dv, hv, dw_len_bytes, lookup_id, fmt, type, status, ep, tc, prfx, func, dma_type, dma_chan, data, bad_eot, eot }
  assign { s_mcb_dv
         , s_mcb_hv
         , mcb_dw_len_bytes
         , mcb_ireq_np_lookup_id
         , mcb_fmt
         , mcb_type
         , mcb_status
         , mcb_ep
         , mcb_tc
         , mcb_func
         , mcb_dma_type
         , mcb_dma_chan
         , mcb_last
         , mcb_data
         , mcb_bad_eot
         , s_mcb_eot
         } = ccdly2_interface_bus;

  assign mcb_hv  = s_mcb_hv  & !s_filter_active;
  assign mcb_dv  = s_mcb_dv  & !s_filter_active;
  assign mcb_eot = s_mcb_eot & !s_filter_active;

  // When the bridge is instantiated the address alignment features is disabled.
  // (GLOB_ADDR_ALIGN_EN=0). Default output to logic zero.
  assign mcb_addr_align_en     = 1'b0;
  // Set to logic zero for PCIe completers
  assign mcb_bcm               = 1'b0;
  // AT bits set to zero for completion TLP's
  assign mcb_ats               = {`DC_CPL_AT_WD{1'b0}};
  // ECRC appended by the core when bridge instantiated. Set to logic 0 to
  // indicate bridge completion contains raw data only.
  assign mcb_td                = 1'b0;
  // The attributes to be used in the completion header is populated from the PCIe
  // core TRGT_CPL_LUT.
  assign mcb_attr              = {`FLT_Q_ATTR_WIDTH{1'b0}};
  // The byte count to be used in the completion header is calculated by the PCIe
  // core when the TRGT_CPL_LUT is instantiated.
  assign mcb_byte_cnt          = {`DC_CPL_BYTE_CNT_WD{1'b0}};
  // The tag to be used in the completion header is populated from the PCIe
  // core TRGT_CPL_LUT.
  assign mcb_tid               = {`CX_TAG_SIZE{1'b0}};
  // The low address to be used in the completion header is populated from the PCIe
  // core TRGT_CPL_LUT.
  assign mcb_addr              = {`DC_CPL_ADDR_WD+CX_ADDR_PAR_WD{1'b0}};
  // The first/last byte enables to be used in the completion header is populated from the
  // PCIe core TRGT_CPL_LUT.
  assign mcb_byte_en           =  {`DC_CPL_BYTE_EN_WD{1'b0}};
  // The requester ID to inserted in the completion header is inserted by the PCCIE core.
  assign mcb_cmpltr_id         =  {`DC_CPL_CMPLTR_ID_WD{1'b0}};
  // Address parity is not supported in the master completion data path.
  assign mcb_addr_parerr       = 1'b0;


  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  typedef logic [CX_RAS_PROT_RANGE-1:0] data_np_t;
  typedef struct packed {
    logic     parity;
    data_np_t data  ;
  } data_wp_s;

  function automatic data_np_t [NUM_DATA_PAR_BLOCKS_WR-1:0] fn_data_wo_par_wr(data_wp_s [NUM_DATA_PAR_BLOCKS_WR-1:0] data_wp);
    fn_data_wo_par_wr = '0;
    foreach (data_wp[i]) begin
      fn_data_wo_par_wr[i] = data_wp[i].data;
    end
    return fn_data_wo_par_wr;
  endfunction

  // Data without parity
  function automatic logic [CC_MSTR_CPL_SEG_DATA_WD_NP-1:0] fn_data_wo_par;
    input [CC_MSTR_CPL_SEG_DATA_WD-1:0] s_data_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS_S; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_data_wo_par[i*CX_RAS_PROT_RANGE +j] = s_data_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end

    end
  endfunction

  function automatic [NUM_DATA_PAR_BLOCKS_S-1:0] fn_prot_chkin_dr;
    input [CC_MSTR_CPL_SEG_DATA_WD-1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS_S; i=i+1) begin
        fn_prot_chkin_dr[i] = s_data_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end

    end
  endfunction


  function automatic data_np_t [NUM_DATA_PAR_BLOCKS_RD-1:0] fn_data_wo_par_rd(data_wp_s [NUM_DATA_PAR_BLOCKS_RD-1:0] data_wp);
    fn_data_wo_par_rd = '0;
    foreach (data_wp[i]) begin
      fn_data_wo_par_rd[i] = data_wp[i].data;
    end
    return fn_data_wo_par_rd;
  endfunction

  function automatic data_wp_s [NUM_DATA_PAR_BLOCKS_WR-1:0] fn_data_w_par_wr(data_np_t [NUM_DATA_PAR_BLOCKS_WR-1:0] data_wp);
    fn_data_w_par_wr = '0;
    foreach (data_wp[i]) begin
      fn_data_w_par_wr[i].data = data_wp[i];
      fn_data_w_par_wr[i].parity = (CX_RAS_PARITY_MODE == '0) ? ^data_wp[i] : ~(^data_wp[i]);
    end
    return fn_data_w_par_wr;
  endfunction

  function automatic data_wp_s [NUM_DATA_PAR_BLOCKS_RD-1:0] fn_data_w_par_rd(data_np_t [NUM_DATA_PAR_BLOCKS_RD-1:0] data_wp);
    fn_data_w_par_rd = '0;
    foreach (data_wp[i]) begin
      fn_data_w_par_rd[i].data = data_wp[i];
      fn_data_w_par_rd[i].parity = (CX_RAS_PARITY_MODE == '0) ? ^data_wp[i] : ~(^data_wp[i]);
    end
    return fn_data_w_par_rd;
  endfunction

    function automatic [NUM_DATA_PAR_BLOCKS_WR-1:0] fn_prot_chkin_d;
    input [L_MCBWR_DATAWP_WD-1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS_WR; i=i+1) begin
        fn_prot_chkin_d[i] = s_data_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction




 `ifndef SYNTHESIS
`endif //  `ifndef SYNTHESIS


endmodule
