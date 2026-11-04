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
// ---    $Revision: #26 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_rreq.sv#26 $
// -------------------------------------------------------------------------

//---------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

`include "DWC_pcie_ctl_pkg.svh"

 module DWC_pcie_axi_slv_rreq
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_AXI_BRIDGE;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 #(
  parameter SLV_BUS_ID_WIDTH                 = 5,
  parameter SLV_BUS_ADDR_WIDTH               = 36,
  parameter SLAVE_BUS_ADDR_WIDTH             = 32,
  parameter SLV_BURST_LEN_PW                 = 4,
  parameter SLV_BUS_NPWSTRB_WIDTH            = 4,  // Write Strobes bus width for Non-Posted writes interface
  parameter SLV_BUS_NPDATA_WIDTH             = 32, // Data bus width for Non-Posted writes interface after up conversion
  parameter SLV_BUS_NPDATA_WIDTH_NP          = 32, // Data bus width, without parity, for Non-Posted writes interface after up conversion
  parameter SLV_BUS_WREQ_NPWSTRB_WIDTH       = `CC_SLV_BUS_WREQ_NPWSTRB_WIDTH,   // Write Strobes bus width for Non-Posted writes interface
  parameter SLV_BUS_WREQ_NPDATA_WIDTH        = `CC_SLV_BUS_WREQ_NPDATA_WIDTH,    // Data bus width for Non-Posted writes interface
  parameter SLV_BUS_WREQ_NPDATA_WIDTH_NP     = `CC_SLV_BUS_WREQ_NPDATA_WIDTH_NP, // Data bus width, without parity, for Non-Posted writes interface
  parameter NFUNC_WD                         = 1,
  parameter TX_TLP_PREFIX_WD                 = 32,
  parameter MISC_INFO_TPH_WD                 = 11,
  parameter ATU_OUT_REGIONS                  = 2,
  parameter ATU_BASE_WD                      = 32,
  parameter ATU_REG_WD                       = 16,
  parameter ATU_UPR_LMT_WD                   = 8,
  parameter ATU_OUT_MIN1                     = 2,
  parameter SLV_BUS_STRB_PW                  = 2,
  parameter DBI_SLV_BUS_ADDR_WIDTH           = 32,
  parameter SLV_NPW_SAB_RAM_DATA_WD          = `CC_SLV_NPW_SAB_RAM_DATA_WD,
  parameter SLV_NPW_SAB_RAM_DATA_WD_NOECC    = `CC_SLV_NPW_SAB_RAM_DATA_WD_NOECC,
  parameter SLV_NPW_SAB_RAM_DP               = `CC_SLV_NPW_SAB_RAM_DP,
  parameter SLV_NPW_SAB_RAM_ADDR_WD          = `CC_SLV_NPW_SAB_RAM_ADDR_WD,
  parameter SLV_NPW_SAB_RAM_RD_LATENCY       = `CC_SLV_NPW_SAB_RAM_RD_LATENCY,
  parameter CX_RAS_RAM_PROT_RANGE            = `CX_RAS_RAM_PROT_RANGE,
  parameter CX_RAS_PROT_RANGE                = `CX_RAS_PROT_RANGE,
  parameter CX_RAS_PARITY_MODE               = `CX_RAS_PARITY_MODE,
  parameter CC_SLV_MAX_BYTES_PW              = `CC_SLV_MAX_BYTES_PW,

  parameter TP                               = `TP
 )
 
                               (
  input                                     slv_aclk,
  input                                     slv_aclk_ug,
  input                                     slv_aresetn,
  // -------------------------------------------------------------------------------------
  // Flush control
  input                                     flshctl_sif_flush_req,
  // -------------------------------------------------------------------------------------
  // ATU interface
  input [(ATU_BASE_WD*ATU_OUT_MIN1)-1:0]    atu_reg_out_upr_base,
  input [ATU_OUT_MIN1-1:0]                  atu_reg_out_en,
  input [5*ATU_OUT_MIN1-1:0]                atu_reg_out_type,
  input [(ATU_REG_WD*ATU_OUT_MIN1)-1:0]     atu_reg_out_base,
  input [(ATU_REG_WD*ATU_OUT_MIN1)-1:0]     atu_reg_out_limit,
  input [ATU_UPR_LMT_WD*ATU_OUT_MIN1-1:0]   atu_reg_out_uppr_limit,
  input [ATU_OUT_MIN1-1:0]                  atu_reg_out_incr_rgn_size,    // Maximum region size control bit
  input [ATU_OUT_MIN1-1:0]                  atu_reg_out_invert,
  input [(NFUNC_WD*ATU_OUT_MIN1)-1:0]       atu_reg_out_func_num,
  input [ATU_OUT_MIN1-1:0]                  atu_reg_out_func_bypass,
  input [ATU_OUT_MIN1-1:0]                  atu_reg_out_snp,
  // -------------------------------------------------------------------------------------
  // AXI Read request interface
  input                                     arvalid,
  input [SLV_BUS_ADDR_WIDTH-1:0]            araddr,
  input [SLV_BUS_ID_WIDTH-1:0]              arid,
  input [SLV_BURST_LEN_PW -1:0]             arlen,
  input [2:0]                               arsize,
  input [1:0]                               arburst,
  input [4:0]                               armisc_info_type,
  input                                     armisc_info_snp,
  input                                     armisc_info_ns,
  input                                     armisc_info_ro,
  input [2:0]                               armisc_info_tc,
  input                                     armisc_info_db,
  input [NFUNC_WD-1:0]                      armisc_info_func_num,
  input                                     armisc_info_nw,
  input [1:0]                               armisc_info_ats,
  input [TX_TLP_PREFIX_WD-1:0]              armisc_info_tlpprfx,
  input [MISC_INFO_TPH_WD-1:0]              armisc_info_tph,
  input                                     armisc_info_atu_bypass,
  input [8:0]                               armisc_info_dst_segment,
  input                                     armisc_info_ido,
  output wire                               srrq_np_arready,
  // -------------------------------------------------------------------------------------
  // Non-Posted Write Request Interface
  input                                     swrq_npw_valid,
  input [SLV_BUS_ID_WIDTH-1:0]              swrq_npw_id,
  input [SLV_BUS_ADDR_WIDTH-1:0]            swrq_npw_addr,
  input [2:0]                               swrq_npw_size,
  input [SLV_BURST_LEN_PW-1:0]              swrq_npw_len,
  input                                     swrq_npw_last,
  input [SLV_BUS_WREQ_NPWSTRB_WIDTH-1:0]    swrq_npw_strb,
  input [SLV_BUS_WREQ_NPDATA_WIDTH-1:0]     swrq_npw_data,
  input [4:0]                               swrq_npw_type,
  input                                     swrq_npw_snp,
  input [2:0]                               swrq_npw_tc,
  input                                     swrq_npw_ep,
  input                                     swrq_npw_atomic_load_be,
  input                                     swrq_npw_atomic_cas_wrap,
  input                                     swrq_npw_ns,
  input                                     swrq_npw_ro,
  input                                     swrq_npw_nw,
  input [1:0]                               swrq_npw_ats,
  input [MISC_INFO_TPH_WD-1:0]              swrq_npw_tph,
  input                                     swrq_npw_first_wrp_split_xact,
  input                                     swrq_npw_wrp_valid,
  input                                     swrq_npw_db,
  input                                     swrq_npw_db_vldrq,
  input [NFUNC_WD-1:0]                      swrq_npw_func_num,
  input [TX_TLP_PREFIX_WD-1:0]              swrq_npw_tlpprfx,
  input                                     swrq_npw_atu_bypass,
  input [8:0]                               swrq_npw_dst_segment,
  input                                     swrq_npw_ido,
  input [2:0]                               swrq_npw_cpl_stat,
  output wire                               srrq_npw_ready,
  // -------------------------------------------------------------------------------------
  // AXI Tag Manager interface
  output wire                               srrq_np_tag_consumed,
  input                                     tag_fifo_full,
  // -------------------------------------------------------------------------------------
  // Non-Posted Request interface
  output wire                               srrq_np_rd,
  output wire                               srrq_np_wr,
  output wire                               srrq_np_atomic,
  output wire                               srrq_np_dmwr,
  output                                    srrq_np_first_wrp_split_xact,
  output                                    srrq_np_wrp_valid,
  output wire [SLV_BUS_ADDR_WIDTH-1:0]      srrq_np_addr,
  output wire [SLV_BUS_STRB_PW-1:0]         srrq_np_addr_low,
  output wire                               srrq_np_ven_id_rd,
  output wire [SLV_BUS_ID_WIDTH-1:0]        srrq_np_id,
  output wire [SLV_BURST_LEN_PW-1:0]        srrq_np_len,
  output wire [2:0]                         srrq_np_size,
  output wire [1:0]                         srrq_np_burst,
  output wire [3:0]                         srrq_np_wrap_beat_offset,
  output wire                               srrq_np_last,
  output wire [SLV_BUS_NPWSTRB_WIDTH-1:0]   srrq_np_strb,
  output wire [SLV_BUS_NPDATA_WIDTH-1:0]    srrq_np_data,
  output wire [4:0]                         srrq_np_type,
  output wire                               srrq_np_snp,
  output wire                               srrq_np_ns,
  output wire                               srrq_np_ro,
  output wire [2:0]                         srrq_np_tc,
  output wire                               srrq_np_ep,
  output wire [NFUNC_WD-1:0]                srrq_np_func_num,
  output wire                               srrq_np_nw,
  output wire [1:0]                         srrq_np_ats,
  output wire [TX_TLP_PREFIX_WD-1:0]        srrq_np_tlpprfx,
  output wire [MISC_INFO_TPH_WD-1:0]        srrq_np_tph,
  output wire                               srrq_np_atu_bypass,
  output wire [8:0]                         srrq_np_dst_segment,
  output logic [2:0]                        srrq_np_cpl_stat,
  output wire                               srrq_np_ido,
  input                                     nprf_ready,
  // -------------------------------------------------------------------------------------
  // Data Bus Non-Posted Request Interface
  output wire                               srrq_db_rd,
  output wire                               srrq_db_wr,
  output wire                               srrq_db_vldrq,
  output wire [DBI_SLV_BUS_ADDR_WIDTH-1:0]  srrq_db_addr,
  output wire [3:0]                         srrq_db_strb,
  output wire [SLV_BURST_LEN_PW-1:0]        srrq_db_len,
  output wire [31:0]                        srrq_db_data,
  input                                     dbi_ready,
  input                                     atm_dbi_req_halt, // tag manager allows only one oustanding DBI request
  // -------------------------------------------------------------------------------------
  // Slave Non-Posted Write Set-Aside RAM
  output wire [SLV_NPW_SAB_RAM_ADDR_WD-1:0] srrq_npw_sab_addra,
  output wire                               srrq_npw_sab_wea,
  output wire [SLV_NPW_SAB_RAM_DATA_WD-1:0] srrq_npw_sab_dina,
  output wire [SLV_NPW_SAB_RAM_ADDR_WD-1:0] srrq_npw_sab_addrb,
  output wire                               srrq_npw_sab_enb,
  input [SLV_NPW_SAB_RAM_DATA_WD-1:0]       ram_npw_sab_doutb,
  input                                     cfg_ras_recc_npw_sab_correct,
  output wire                               srrp_ras_recc_corr_cnt_npw_sab_pulse,
  output wire                               srrp_ras_recc_ucorr_cnt_npw_sab_pulse,
  output wire [SLV_NPW_SAB_RAM_ADDR_WD-1:0] srrp_ras_recc_cnt_npw_sab_addr,
  output wire                               srrp_ras_par_srwrap_ad_pulse,
  output ras_dp_err_log_t                   srrp_srwrap_ad_ras_dp_err_log,
  output wire                               swrq_ras_par_npw_dt_pulse,
  output wire                               swrq_ras_par_npw_ad_pulse,
  output ras_dp_err_log_t                   swrq_npw_dt_ras_dp_err_log,
  output ras_dp_err_log_t                   swrq_npw_ad_ras_dp_err_log,
  output ras_dp_err_log_t                   srrp_recc_npw_sab_ras_dp_err_log,
    input  ras_dp_err_inj_t                    ras_dp_err_inj_slv_aclk,
  // -------------------------------------------------------------------------------------
  // Low power interface
  input                                     csysreq,
  output wire                               csysack,
  output wire                               cactive
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  // Burst encoding
  localparam WRAP = `WRAP;
  localparam INCR = `INCR;

  localparam CFG0_TYPE = `CFG0_TYPE;
  localparam CFG1_TYPE = `CFG1_TYPE;
  localparam MEM_TYPE  = `MEM_TYPE;
  localparam MEM_TYPE_LOCKED = `MEM_TYPE_LOCKED;
  localparam IO_TYPE   = `IO_TYPE;
  // Number of parity address blocks per 32/64 bit address
  localparam NUM_ADDR_PAR_BLOCKS  = SLAVE_BUS_ADDR_WIDTH/CX_RAS_PROT_RANGE;
  // Number of parity data blocks for a single dword
  localparam NUM_DATA_PAR_BLOCKS  = SLV_BUS_NPDATA_WIDTH_NP/CX_RAS_PROT_RANGE;
  localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N);

  localparam SLV_NPW_CTL_WD                  = `CC_SLV_NPW_CTL_WD;
  localparam SLV_NPW_CTL_ADDR_WD             = SLV_NPW_CTL_WD + SLV_BUS_ADDR_WIDTH ;
  localparam SLV_NPW_CTL_ADDR_WSTRB_WD       = SLV_NPW_CTL_WD + SLV_BUS_ADDR_WIDTH + SLV_BUS_NPWSTRB_WIDTH;
  localparam SLV_NPW_CTL_ADDR_NOPAR_WSTRB_WD = SLV_NPW_CTL_WD + SLAVE_BUS_ADDR_WIDTH + SLV_BUS_NPWSTRB_WIDTH
                                               ;

  // Address parity bits width
  // localparam SLV_BUS_ADDR_PAR_WD = SLV_BUS_ADDR_WIDTH - SLAVE_BUS_ADDR_WIDTH;

  // Non-Posted Write control data
  // {addr,wid,len,size,last,strb,type,snp,tc,ep,db,func_num,vfunc_num,vfunc_act,tlpprfx,atu_byp}
  localparam SLV_BUS_NPCTL_WIDTH_NP = SLV_NPW_SAB_RAM_DATA_WD_NOECC-SLV_BUS_NPDATA_WIDTH_NP;

  // control bus width with parity bits on address bus incuded
  // localparam SLV_BUS_NPCTL_WIDTH = SLV_NPW_CTL_WD+SLV_BUS_ADDR_WIDTH;

  // Non-posted read interface info
  // {valid, addr, rid, len, size, burst, type, snp, ns, ro, tc, np/db, ecam_db, func_num,
  //  nw, ats, vfunc_num, vfunc_act, prfx, tph, atu_byp, ido, idunq, cpl_stat}
  localparam AR_CH_INTF_WD = { 1
                             + SLV_BUS_ADDR_WIDTH
                             + SLV_BUS_ID_WIDTH
                             + SLV_BURST_LEN_PW
                             + 16
                             + 2
                             + NFUNC_WD
                             + 3
                             + TX_TLP_PREFIX_WD
                             + MISC_INFO_TPH_WD
                             + 1
                             + 9
                             + 1
                             + 3                    // cpl_stat
                             };

  // Common write/read info signals
  // {addr, id, len, size, type, snp, tc, np/db, ecam_db, func_num, vfunc_num, vfunc_act,
  // prfx, atu_byp, dst_segment, idunq, cpl_stat}
  localparam MUX_INFO_WD = { SLV_BUS_ID_WIDTH       // id
                           + SLV_BUS_ADDR_WIDTH     // addr
                           + SLV_BURST_LEN_PW       // len
                           + 3 + 5 + 1 + 3
                           + 2
                           + NFUNC_WD
                           + TX_TLP_PREFIX_WD       // tlpprfx

                           + 1                      // atu_bypass
                           + 9                      // dst_segment
                           + 3                      // cpl_stat
                           };

  localparam VENDOR_ID_ADDR = 12'h0;
  localparam MAX_SIZE       = `SLAVE_BUS_DATA_WIDTH ==  32 ? 3'b010 :
                              `SLAVE_BUS_DATA_WIDTH ==  64 ? 3'b011 :
                              `SLAVE_BUS_DATA_WIDTH == 128 ? 3'b100 :
                              `SLAVE_BUS_DATA_WIDTH == 256 ? 3'b101 :
                              `SLAVE_BUS_DATA_WIDTH == 512 ? 3'b110 :
                                                             3'b111;


  localparam SLV_BUS_NPCTL_LEN_HIGH  = SLV_NPW_CTL_ADDR_WD - SLV_BUS_ADDR_WIDTH - SLV_BUS_ID_WIDTH - 1;
  localparam SLV_BUS_NPCTL_LEN_LOW   = SLV_BUS_NPCTL_LEN_HIGH - SLV_BURST_LEN_PW + 1;
  localparam SLV_BUS_NPCTL_SIZE_HIGH = SLV_BUS_NPCTL_LEN_LOW - 1;
  localparam SLV_BUS_NPCTL_SIZE_LOW  = SLV_BUS_NPCTL_SIZE_HIGH - 2;
  localparam SLV_BUS_NPCTL_CPLSTAT_HIGH = 3;
  localparam SLV_BUS_NPCTL_CPLSTAT_LOW  = SLV_BUS_NPCTL_CPLSTAT_HIGH - 2;

  // -------------------------------------------------------------------------------------
  // Wire/Reg
  // -------------------------------------------------------------------------------------
  // AR Channel pipe delay
  wire [AR_CH_INTF_WD-1:0]                 s_ar_ch_intf;
  wire [2:0]                               armisc_info_cpl_stat;
  wire                                     pdly1_halt;
  wire [AR_CH_INTF_WD-1:0]                 pdly1_ar_ch_intf;

  wire                                     s_pdly1_valid;
  wire [SLV_BUS_ADDR_WIDTH-1:0]            pdly1_np_addr;
  wire [SLV_BUS_ID_WIDTH-1:0]              pdly1_np_id;
  wire [SLV_BURST_LEN_PW-1:0]              pdly1_np_len;
  wire [2:0]                               pdly1_np_size;
  wire [1:0]                               pdly1_np_burst;
  wire                                     pdly1_np_ro;
  wire                                     pdly1_np_ns;
  wire                                     pdly1_np_nw;
  wire [1:0]                               pdly1_np_ats;
  wire [4:0]                               s_pdly1_type;
  wire                                     s_pdly1_np_snp;
  wire [2:0]                               pdly1_np_tc;
  wire                                     pdly1_np_db;
  wire                                     pdly1_np_db_vldrq;
  wire [NFUNC_WD-1:0]                      s_pdly1_func_num;
  wire [TX_TLP_PREFIX_WD-1:0]              pdly1_np_tlpprfx;
  wire [MISC_INFO_TPH_WD-1:0]              pdly1_np_tph;
  wire                                     pdly1_np_atu_bypass;
  wire [8:0]                               pdly1_np_dst_segment;
  wire                                     pdly1_np_ido;
  wire [2:0]                               pdly1_np_cpl_stat;
  wire                                     s_npr_halt;
  wire                                     s_npw_ready;

  wire                                     s_npr_valid;
  wire                                     s_npw_valid;

  wire [SLAVE_BUS_ADDR_WIDTH-1:0]          s_pdly1_np_addr_wo_par;
  wire [4:0]                               s_np_type;
  wire [NFUNC_WD-1:0]                      s_np_func_num;
  wire                                     s_np_snp;
  wire [SLAVE_BUS_ADDR_WIDTH-1:0]          s_wrap_bndry_wo_par;

  wire [SLV_NPW_CTL_ADDR_WD-1:0]             swrq_npw_ctl;
  wire [SLV_NPW_CTL_ADDR_WD-1:0]             s_swrq_npw_ctl            , ss_swrq_npw_ctl;
  wire                                       s_swrq_npw_last           , ss_swrq_npw_last;
  wire [SLV_BUS_NPWSTRB_WIDTH-1:0]           s_swrq_npw_strb           , ss_swrq_npw_strb;
  wire [SLV_NPW_CTL_ADDR_NOPAR_WSTRB_WD-3:0] ss_swrq_npw_ctl_wo_par    ;
  wire [SLV_NPW_CTL_ADDR_NOPAR_WSTRB_WD-1:0] s_swrq_npw_ctl_wo_par     ;
  wire [SLV_BUS_NPDATA_WIDTH-1:0]            s_swrq_npw_data           , ss_swrq_npw_data;
  wire [SLV_BUS_NPDATA_WIDTH_NP-1:0]         s_swrq_npw_data_wo_par    , ss_swrq_npw_data_wo_par;
  wire [SLV_BUS_ADDR_WIDTH-1:0]              s_swrq_npw_addr           , ss_swrq_npw_addr;
  wire [SLAVE_BUS_ADDR_WIDTH-1:0]            s_swrq_npw_addr_wo_par    , ss_swrq_npw_addr_wo_par;
  wire                                       s_swrq_npw_valid          , ss_swrq_npw_valid;
  wire [2:0]                                 s_swrq_npw_cpl_stat       , ss_swrq_npw_cpl_stat;
  wire                                       s_swrq_npw_ep             , ss_swrq_npw_ep;
  wire [2:0]                                 s_swrq_npw_size;
  wire [SLV_BURST_LEN_PW-1:0]                s_swrq_npw_len;
  wire                                       s_swrq_npw_atomic_load_be , ss_swrq_npw_atomic_load_be;
  wire                                       s_swrq_npw_atomic_cas_wrap, ss_swrq_npw_atomic_cas_wrap;
  wire [SLV_BUS_NPDATA_WIDTH-1:0]            s_swrq_npw_data_swap;

  // Set-aside buffer
  wire                                     s_npw_push_n, ss_npw_push_n;
  wire [SLV_NPW_SAB_RAM_DATA_WD_NOECC-1:0] ss_npw_push_data;
  wire                                     sfifo_f, s_sfifo_f;
  wire                                     npwb_pop_valid;
  wire [SLV_NPW_SAB_RAM_DATA_WD_NOECC-1:0] npwb_pop_data;

  // Unpacked set-aside buffer interface signals
  wire [SLV_BUS_ADDR_WIDTH-1:0]            npwb_npw_addr;
  wire [SLAVE_BUS_ADDR_WIDTH-1:0]          npwb_npw_addr_i;
  wire [SLV_BUS_NPDATA_WIDTH-1:0]          npwb_np_data;
  wire [SLV_BUS_NPDATA_WIDTH_NP-1:0]       npwb_np_data_i;

  wire                                      npwb_npw_last;
  wire [SLV_BUS_NPWSTRB_WIDTH-1:0]          npwb_np_strb;
  wire [SLV_BUS_ID_WIDTH-1:0]               npwb_npw_id;
  wire [SLV_BURST_LEN_PW-1:0]               npwb_npw_len;
  wire [2:0]                                npwb_npw_size;
  wire [4:0]                                npwb_npw_type;
  wire                                      npwb_npw_snp;
  wire [2:0]                                npwb_npw_tc;
  wire                                      npwb_npw_ep;
  wire                                      npwb_npw_ns;
  wire                                      npwb_npw_ro;
  wire                                      npwb_npw_nw;
  wire [1:0]                                npwb_npw_ats;
  wire [MISC_INFO_TPH_WD-1:0]               npwb_npw_tph;
  wire                                      npwb_npw_ido;
  wire                                      npwb_npw_first_wrp_split_xact;
  wire                                      npwb_npw_wrp_valid;
  wire                                      npwb_npw_db;
  wire                                      npwb_npw_db_vldrq;
  wire [NFUNC_WD-1:0]                       npwb_npw_func_num;
  wire [TX_TLP_PREFIX_WD-1:0]               npwb_npw_tlpprfx;
  wire                                      npwb_npw_atu_bypass;
  wire [8:0]                                npwb_npw_dst_segment;
  wire [2:0]                                npwb_npw_cpl_stat;
  wire                                      npwb_npw_cpl_stat_0b;
  wire [SLV_BUS_ADDR_WIDTH-1:0]             s_npw_addr;

  // Mux interfaces
  wire [MUX_INFO_WD-1:0]                    s_npw_mux_info;
  wire [MUX_INFO_WD-1:0]                    s_npr_mux_info;
  wire                                      npmux_ready_b;
  wire                                      npmux_ready_a;
  wire [MUX_INFO_WD-1:0]                    npmux_intf;
  wire                                      s_ready;

  wire                                      npmux_np_db;
  wire                                      npmux_np_db_vldrq;
  wire                                      npmux_np_rd;
  wire                                      npmux_np_wr;
  wire                                      npmux_np_atomic;
  wire                                      npmux_np_dmwr;

  wire [SLV_BUS_ADDR_WIDTH-1:0]             npmux_np_addr;
  wire [4:0]                                npmux_np_type;
  wire [SLV_BUS_ADDR_WIDTH-1:0]             s_npmux_np_addr;

  wire                                      s_npmux_np_rd_io_cfg;

  wire [SLV_BUS_ADDR_WIDTH-1:0]             ss_npmux_np_addr;
  wire [2:0]                                npmux_np_cpl_stat;
  // vendor id
  wire                                      s_cfg_rd_type;
  wire [SLV_BUS_ADDR_WIDTH-1:0]             s_npmux_addr_wo_par;

  wire                                      pm;
  reg                                       r_flshctl_sif_flush_req;
  // Invalid DBI request indication
  wire                                      armisc_info_db_vldrq;
  wire [SLV_BUS_ADDR_WIDTH-1:0]             s_araddr;

  // -------------------------------------------------------------------------------------
  // DESIGN
  // -------------------------------------------------------------------------------------
  // This register is required to ensure that slv_arready does not glitch to 1 when reset is asserted
  always@(posedge slv_aclk_ug or negedge slv_aresetn) begin: proc_seq_r_flshctl_sif_flush_req
    if(!slv_aresetn)
      r_flshctl_sif_flush_req <= #TP 1'b1;
    else
      r_flshctl_sif_flush_req <= #TP flshctl_sif_flush_req;
  end
   assign pm = CX_RAS_PARITY_MODE;
  // DBI requests longer than 1 beat or wider than 4 bytes are invalid
  assign armisc_info_db_vldrq = armisc_info_db ? (arlen == {SLV_BURST_LEN_PW{1'b0}}) && (arsize <= 3'b010) : 1'b0;
  // DBI requests longer than 1 beat or wider than 4 bytes are invalid
  assign s_araddr = ((armisc_info_db && !armisc_info_db_vldrq) ? {araddr[SLV_BUS_ADDR_WIDTH-1:9],pm,8'h00} : araddr);

// ---------------------------------------------------------------------------------------
// Enhanced Configuration Access Mechanism (ECAM)
// ---------------------------------------------------------------------------------------
  assign armisc_info_cpl_stat = `SU_CPL_STATUS;

 // -------------------------------------------------------------------------------------
  // Insert AR Channel pipe delay
  // -------------------------------------------------------------------------------------
  // Pack AR channel signals
  // When the request is an invalid DBI one need to fake size and address to prevent
  // aligner in response processing logic from introducing extra beats
  assign s_ar_ch_intf = {
  arvalid  && !r_flshctl_sif_flush_req
  , s_araddr
  , arid
  , arlen
  , (armisc_info_db && !armisc_info_db_vldrq) ? MAX_SIZE : arsize

  , arburst
  , armisc_info_type
  , armisc_info_snp
  , armisc_info_ns
  , armisc_info_ro
  , armisc_info_tc
  , armisc_info_db
  , armisc_info_db_vldrq

  , armisc_info_func_num
  , armisc_info_nw
  , armisc_info_ats
  , armisc_info_tlpprfx
  , armisc_info_tph
  , armisc_info_atu_bypass
  , armisc_info_dst_segment
  , armisc_info_ido
  , armisc_info_cpl_stat
  };

  // Stall request

  assign srrq_np_arready = !pdly1_halt  && !r_flshctl_sif_flush_req;

  // Instantiate pipe delay block
  delay_1_w_stalling
  
  #(.DELAY_EN                              (1)
   ,.WD                                    (AR_CH_INTF_WD)
   ,.CAN_STALL                             (1)
   ,.RESET_STALL                           (1'b1)
  )
  u_pdly1
  (
    .clk        (slv_aclk),
    .rst_n      (slv_aresetn),
    .din        (s_ar_ch_intf),
    .stallout   (pdly1_halt),
    .clear      (1'b0),

    .dout       (pdly1_ar_ch_intf),
    .stall      (s_npr_halt)
  );

  // Unpack non-posted read control/info
  // {valid, addr, rid, size, len, burst, type, snp, ns, ro, tc, np, func_num,
  //  nw, ats, vfunc_num, vfunc_act, prfx, tph, atu_byp, ido}
  // { ns, ro, nw, ats, tph, ido } wired directly to the top level
  assign {
    s_pdly1_valid
  , pdly1_np_addr
  , pdly1_np_id
  , pdly1_np_len
  , pdly1_np_size
  , pdly1_np_burst
  , s_pdly1_type
  , s_pdly1_np_snp
  , pdly1_np_ns
  , pdly1_np_ro
  , pdly1_np_tc
  , pdly1_np_db
  , pdly1_np_db_vldrq
  , s_pdly1_func_num
  , pdly1_np_nw
  , pdly1_np_ats
  , pdly1_np_tlpprfx
  , pdly1_np_tph
  , pdly1_np_atu_bypass
  , pdly1_np_dst_segment
  , pdly1_np_ido
 , pdly1_np_cpl_stat
  } =  pdly1_ar_ch_intf;

  // Halt pipeline
  assign s_npr_halt = s_pdly1_valid && (tag_fifo_full || !npmux_ready_b);

  // Mask the valid when the pipeline is internally halted
  assign s_npr_valid = s_pdly1_valid && !tag_fifo_full;

  // Extract start address
  assign s_pdly1_np_addr_wo_par = fn_addr_wo_par(pdly1_np_addr);

   wire   npaddr_chk_en, s_srrp_ras_par_srwrap_ad_pulse;
   assign npaddr_chk_en  = s_pdly1_valid & !s_npr_halt;
  ras_dp_err_log_t s_srrp_srwrap_ad_ras_dp_err_log;

  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                               ),
    .RESETVAL                  (0                               ),
    .N_STAGES                  (0                               ),
    .CAN_STALL                 (0                               ),
    .RESET_STALL               (0                               ),
    .BUS_PROTECT_GEN_EN        (0                               ),
    .BUS_PROTECT_CHK_EN        (1                               ),
    .PROT_TYPE                 (1                               ),
    .PROT_RANGE                (CX_RAS_PROT_RANGE               ),
    .PROT_WD                   (NUM_ADDR_PAR_BLOCKS             ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE              ),
    .PROT_CORRECT_EN           (0                               ),
    .TOTAL_WIDTH               (SLAVE_BUS_ADDR_WIDTH            ),
    .EXCLUDE_PROT_WIDTH        (0                               ),
    .RAS_DP_PROT_CHK_ID_BASE   (`SRRP_SRWRAP_AD_RAS_ID          )
  ) u_npaddr_chk (
    .clk                       ( slv_aclk                       ),
    .rst_n                     ( slv_aresetn                    ),
    .din                       ( fn_addr_wo_par(pdly1_np_addr)  ),
    .din_prot                  ( fn_prot_chkin_ad(pdly1_np_addr)),
    .dout                      ( /* Not Connected */            ),
    .dout_prot                 ( /* Not Connected */            ),
    .en                        (1'b1                            ),
    .bypass                    (1'b0                            ),
    .stall                     (1'b0                            ),
    .stallout                  ( /* Not Connected */            ),
    .valid_in                  ( npaddr_chk_en                  ),
    .halt_out                  ( /* Not Connected */            ),
    .valid_out                 ( /* Not Connected */            ),
    .halt_in                   (1'b0                            ),
    .ras_dp_err_inband_kbd_in  (1'b0                            ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */            ),
    .ras_dp_err_log            (s_srrp_srwrap_ad_ras_dp_err_log  )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk)
    );
   assign s_srrp_ras_par_srwrap_ad_pulse   = s_srrp_srwrap_ad_ras_dp_err_log.valid;

   assign srrp_ras_par_srwrap_ad_pulse  = s_srrp_ras_par_srwrap_ad_pulse;
   assign srrp_srwrap_ad_ras_dp_err_log = s_srrp_srwrap_ad_ras_dp_err_log;


  // -------------------------------------------------------------------------------------
  // Assign Non-Posted Request interface outputs
  // -------------------------------------------------------------------------------------
  // Translate type and function number

  // Instantiate ATU translation logic
  DWC_pcie_axi_slv_atu
  
  #(.ATU_OUT_REGIONS                  (ATU_OUT_REGIONS)
   ,.ATU_BASE_WD                      (ATU_BASE_WD)
   ,.ATU_REG_WD                       (ATU_REG_WD)
   ,.ATU_UPR_LMT_WD                   (ATU_UPR_LMT_WD)
   ,.ATU_OUT_MIN1                     (ATU_OUT_MIN1)
   ,.SLAVE_BUS_ADDR_WIDTH             (SLAVE_BUS_ADDR_WIDTH)
   ,.NFUNC_WD                         (NFUNC_WD)
  )
  u_satu
  (
  // ATU configuration interface
  .atu_reg_out_upr_base              (atu_reg_out_upr_base)
  ,.atu_reg_out_en                   (atu_reg_out_en)
  ,.atu_reg_out_type                 (atu_reg_out_type)
  ,.atu_reg_out_base                 (atu_reg_out_base)
  ,.atu_reg_out_limit                (atu_reg_out_limit)
  ,.atu_reg_out_uppr_limit           (atu_reg_out_uppr_limit)
  ,.atu_reg_out_incr_rgn_size        (atu_reg_out_incr_rgn_size)
  ,.atu_reg_out_invert               (atu_reg_out_invert)
  ,.atu_reg_out_func_num             (atu_reg_out_func_num)
  ,.atu_reg_out_func_bypass          (atu_reg_out_func_bypass)
  ,.atu_reg_out_snp                  (atu_reg_out_snp)
  // ATU control interface
  ,.atu_write                        (1'b0)
  ,.atu_bypass                       (srrq_np_atu_bypass)
  ,.type_info                        (s_pdly1_type)
  ,.func_num                         (s_pdly1_func_num)
  ,.snp                              (s_pdly1_np_snp)
  ,.addr                             (s_pdly1_np_addr_wo_par)
  // Translation interface
  ,.satu_type                        (s_np_type)
  ,.satu_func_num                    (s_np_func_num)
  ,.satu_snp                         (s_np_snp)
  );

  // -------------------------------------------------------------------------------------
  // Non-Posted Write interface control signals to the set-aside buffer
  // {addr,wid,len,size,last,strb,type,snp,tc,ep,db,func_num,vfunc_num,vfunc_act, tlpprfx, atu_byp, nse}
  //
  assign swrq_npw_ctl = {    swrq_npw_addr
                           , swrq_npw_id
                           , swrq_npw_len
                           , swrq_npw_size
                           , swrq_npw_last
                           , swrq_npw_type
                           , swrq_npw_snp
                           , swrq_npw_tc
                           , swrq_npw_ns
                           , swrq_npw_ro
                           , swrq_npw_nw
                           , swrq_npw_ats
                           , swrq_npw_tph
                           , swrq_npw_ido
                           , swrq_npw_first_wrp_split_xact
                           , swrq_npw_wrp_valid
                           , swrq_npw_db
                           , swrq_npw_db_vldrq
                           , swrq_npw_func_num
                           , swrq_npw_tlpprfx
                           , swrq_npw_atu_bypass
                           , swrq_npw_dst_segment
                           , swrq_npw_cpl_stat
                           , swrq_npw_ep
                           };



  localparam SLV_BUS_UPCONV_RATIO         = SLV_BUS_NPDATA_WIDTH_NP/SLV_BUS_WREQ_NPDATA_WIDTH_NP;
  localparam SLV_BUS_UPCONV_NPWSTRB_WIDTH = SLV_BUS_WREQ_NPWSTRB_WIDTH*SLV_BUS_UPCONV_RATIO;

  wire [SLV_NPW_CTL_ADDR_WD-1:0]          upcnvtr_npw_ctl;
  wire [SLV_BUS_NPDATA_WIDTH-1:0]         upcnvtr_npw_data;
  wire                                    upcnvtr_npw_valid;
  wire                                    upcnvtr_npw_ep;
  wire                                    upcnvtr_npw_last;
  wire [SLV_BUS_UPCONV_NPWSTRB_WIDTH-1:0] upcnvtr_npw_strb;
  wire                                    upcnvtr_npw_atomic_load_be;
  wire                                    upcnvtr_npw_atomic_cas_wrap;

  DWC_pcie_axi_slv_upcnvrt
  
    #(
      .PW                            (SLV_NPW_CTL_ADDR_WD
                                     + 2
                                     )
     ,.IR                            (SLV_BUS_WREQ_NPWSTRB_WIDTH)
     ,.DW                            (SLV_BUS_WREQ_NPDATA_WIDTH)
     ,.OW                            (SLV_BUS_NPDATA_WIDTH)
     ,.NW                            (SLV_BUS_UPCONV_RATIO)
    )
    u_upcnvtr
    (  .clk                          (slv_aclk),
       .rst_n                        (slv_aresetn),
       .init_n                       (1'b1),

       .data_vld_in                  (swrq_npw_valid),

       .params_in                    ({
                                         swrq_npw_ctl
                                        , swrq_npw_atomic_load_be
                                        , swrq_npw_atomic_cas_wrap
                                      }),
       .data_last_in                 (swrq_npw_last),
       .data_strb_in                 (swrq_npw_strb),
       .data_ep_in                   (swrq_npw_ep),
       .data_in                      (swrq_npw_data),

       .data_vld_out                 (upcnvtr_npw_valid),
       .params_out                   ({
                                         upcnvtr_npw_ctl
                                        , upcnvtr_npw_atomic_load_be
                                        , upcnvtr_npw_atomic_cas_wrap
                                      }),
       .data_last_out                (upcnvtr_npw_last),
       .data_strb_out                (upcnvtr_npw_strb),
       .data_ep_out                  (upcnvtr_npw_ep),
       .data_out                     (upcnvtr_npw_data),
       .stall_in                     (s_sfifo_f)
    );

  assign s_npw_push_n               = !upcnvtr_npw_valid;
  assign s_swrq_npw_data            = upcnvtr_npw_data;
  assign s_swrq_npw_valid           = upcnvtr_npw_valid;
  assign s_swrq_npw_ctl             = upcnvtr_npw_ctl;
  assign s_swrq_npw_last            = upcnvtr_npw_last;
  assign s_swrq_npw_ep              = upcnvtr_npw_ep;
  assign s_swrq_npw_strb            = upcnvtr_npw_strb;
  assign s_swrq_npw_atomic_load_be  = upcnvtr_npw_atomic_load_be;
  assign s_swrq_npw_atomic_cas_wrap = upcnvtr_npw_atomic_cas_wrap;



  assign s_swrq_npw_addr     = s_swrq_npw_ctl[SLV_NPW_CTL_ADDR_WD-1    -:SLV_BUS_ADDR_WIDTH       ];
  assign s_swrq_npw_cpl_stat = s_swrq_npw_ctl[SLV_BUS_NPCTL_CPLSTAT_HIGH:SLV_BUS_NPCTL_CPLSTAT_LOW];


  assign s_swrq_npw_len      = s_swrq_npw_ctl[SLV_BUS_NPCTL_LEN_HIGH    :SLV_BUS_NPCTL_LEN_LOW    ];
  assign s_swrq_npw_size     = s_swrq_npw_ctl[SLV_BUS_NPCTL_SIZE_HIGH   :SLV_BUS_NPCTL_SIZE_LOW   ];

  // Swap data for atomic CAS with unaligned address
  assign s_swrq_npw_data_swap = s_swrq_npw_atomic_cas_wrap ? fn_atomic_cas_data_swap(s_swrq_npw_data, s_swrq_npw_size, s_swrq_npw_len) :
                               (s_swrq_npw_atomic_load_be  ? fn_atomic_data_be_to_le(s_swrq_npw_data, s_swrq_npw_size, s_swrq_npw_len) : s_swrq_npw_data);


  reg r_swrq_npw_first_beat;

  reg  [SLV_BUS_NPDATA_WIDTH-1:0]            r_swrq_npw_data_swap;
  reg  [SLV_BUS_NPWSTRB_WIDTH-1:0]           r_swrq_npw_strb;


  reg  r_swrq_npw_error;
  wire s_swrq_npw_error;

  always@(posedge slv_aclk_ug or negedge slv_aresetn) begin: proc_seq_r_swrq_npw_first_beat
    if(!slv_aresetn)
      r_swrq_npw_first_beat <= #TP 1'b1;
    else begin
      if(!s_sfifo_f) begin
        if(s_swrq_npw_last)
          r_swrq_npw_first_beat <= #TP 1'b1;
        else if (s_swrq_npw_valid)
          r_swrq_npw_first_beat <= #TP 1'b0;
      end
    end
  end

  // if any beat other than the first has valid write strobes then the request is larger than allowed
  always@(posedge slv_aclk_ug or negedge slv_aresetn) begin: proc_seq_r_swrq_npw_error
    if(!slv_aresetn)
      r_swrq_npw_error <= #TP 1'b0;
    else begin
      if(!s_sfifo_f) begin
        if(s_swrq_npw_last && !s_sfifo_f)
          r_swrq_npw_error <= #TP 1'b0;
        else if (!r_swrq_npw_first_beat && |s_swrq_npw_strb)
          r_swrq_npw_error <= #TP 1'b1;
      end
    end
  end

  // save the data and strobes from the first beat
  always@(posedge slv_aclk_ug or negedge slv_aresetn) begin: proc_seq_r_swrq_npw_data_strb
    if(!slv_aresetn) begin
      r_swrq_npw_data_swap <= #TP {SLV_BUS_NPDATA_WIDTH{1'b0}};
      r_swrq_npw_strb      <= #TP {SLV_BUS_NPWSTRB_WIDTH{1'b0}};
    end else begin
      if(r_swrq_npw_first_beat && !s_sfifo_f) begin
        r_swrq_npw_data_swap <= #TP s_swrq_npw_data_swap;
        r_swrq_npw_strb      <= #TP s_swrq_npw_strb;
      end
    end
  end


  assign s_swrq_npw_error            = (!r_swrq_npw_first_beat && |s_swrq_npw_strb) || r_swrq_npw_error;

  assign ss_swrq_npw_valid           =                                              s_swrq_npw_last;
  assign ss_swrq_npw_data            = !s_swrq_npw_error ? (r_swrq_npw_first_beat ? s_swrq_npw_data_swap                       : r_swrq_npw_data_swap                      ) : s_swrq_npw_data_swap;
  assign ss_swrq_npw_strb            = !s_swrq_npw_error ? (r_swrq_npw_first_beat ? s_swrq_npw_strb[SLV_BUS_NPWSTRB_WIDTH-1:0] : r_swrq_npw_strb[SLV_BUS_NPWSTRB_WIDTH-1:0]) : {(SLV_BUS_NPWSTRB_WIDTH){1'b0}};
  assign ss_swrq_npw_cpl_stat        = !s_swrq_npw_error ?                          s_swrq_npw_cpl_stat                                                                      : `UR_CPL_STATUS;
  assign ss_swrq_npw_ctl             =                                              s_swrq_npw_ctl;
  assign ss_swrq_npw_last            =                                              s_swrq_npw_last;
  assign ss_swrq_npw_ep              =                                              s_swrq_npw_ep;
  assign ss_swrq_npw_addr            =                                              s_swrq_npw_addr;
  assign ss_swrq_npw_atomic_load_be  =                                              s_swrq_npw_atomic_load_be;
  assign ss_swrq_npw_atomic_cas_wrap =                                              s_swrq_npw_atomic_cas_wrap;

  assign ss_npw_push_n               = !ss_swrq_npw_valid || sfifo_f;

  assign s_sfifo_f                   =  ss_swrq_npw_valid && sfifo_f;



   wire   swrq_npw_chk_en;
   assign swrq_npw_chk_en  = ss_swrq_npw_valid & srrq_npw_ready;
   wire   s_swrq_ras_par_npw_ad_pulse;

  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                                 ),
    .RESETVAL                  (0                                 ),
    .N_STAGES                  (0                                 ),
    .CAN_STALL                 (0                                 ),
    .RESET_STALL               (0                                 ),
    .BUS_PROTECT_GEN_EN        (0                                 ),
    .BUS_PROTECT_CHK_EN        (1                                 ),
    .PROT_TYPE                 (1                                 ),
    .PROT_RANGE                (CX_RAS_PROT_RANGE                 ),
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS               ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE                ),
    .PROT_CORRECT_EN           (0                                 ),
    .TOTAL_WIDTH               (SLV_BUS_NPDATA_WIDTH_NP           ),
    .EXCLUDE_PROT_WIDTH        (0                                 ),
    .RAS_DP_PROT_CHK_ID_BASE   (`SWRQ_NPW_DT_RAS_ID               )
  ) u_swrq_npw_data_chk (
    .clk                       ( slv_aclk                         ),
    .rst_n                     ( slv_aresetn                      ),
    .din                       ( fn_data_wo_par (ss_swrq_npw_data)),
    .din_prot                  ( fn_prot_chkin_d(ss_swrq_npw_data)),
    .dout                      ( /* Not Connected */              ),
    .dout_prot                 ( /* Not Connected */              ),
    .en                        (1'b1                              ),
    .bypass                    (1'b0                              ),
    .stall                     (1'b0                              ),
    .stallout                  ( /* Not Connected */              ),
    .valid_in                  ( swrq_npw_chk_en                  ),
    .halt_out                  ( /* Not Connected */              ),
    .valid_out                 ( /* Not Connected */              ),
    .halt_in                   (1'b0                              ),
    .ras_dp_err_inband_kbd_in  (1'b0                              ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */              ),
    .ras_dp_err_log            ( swrq_npw_dt_ras_dp_err_log       )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk  )
    );

  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                                  ),
    .RESETVAL                  (0                                  ),
    .N_STAGES                  (0                                  ),
    .CAN_STALL                 (0                                  ),
    .RESET_STALL               (0                                  ),
    .BUS_PROTECT_GEN_EN        (0                                  ),
    .BUS_PROTECT_CHK_EN        (1                                  ),
    .PROT_TYPE                 (1                                  ),
    .PROT_RANGE                (CX_RAS_PROT_RANGE                  ),
    .PROT_WD                   (NUM_ADDR_PAR_BLOCKS                ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE                 ),
    .PROT_CORRECT_EN           (0                                  ),
    .TOTAL_WIDTH               (SLAVE_BUS_ADDR_WIDTH               ),
    .EXCLUDE_PROT_WIDTH        (0                                  ),
    .RAS_DP_PROT_CHK_ID_BASE   (`SWRQ_NPW_AD_RAS_ID                )
  ) u_swrq_npw_addr_chk (
    .clk                       ( slv_aclk                          ),
    .rst_n                     ( slv_aresetn                       ),
    .din                       ( fn_addr_wo_par  (ss_swrq_npw_addr)),
    .din_prot                  ( fn_prot_chkin_ad(ss_swrq_npw_addr)),
    .dout                      ( /* Not Connected */               ),
    .dout_prot                 ( /* Not Connected */               ),
    .en                        (1'b1                               ),
    .bypass                    (1'b0                               ),
    .stall                     (1'b0                               ),
    .stallout                  ( /* Not Connected */               ),
    .valid_in                  ( swrq_npw_chk_en                   ),
    .halt_out                  ( /* Not Connected */               ),
    .valid_out                 ( /* Not Connected */               ),
    .halt_in                   (1'b0                               ),
    .ras_dp_err_inband_kbd_in  (1'b0                               ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */               ),
    .ras_dp_err_log            ( swrq_npw_ad_ras_dp_err_log        )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk   )
    );

  assign swrq_ras_par_npw_dt_pulse   = swrq_npw_dt_ras_dp_err_log.valid;
  assign swrq_ras_par_npw_ad_pulse   = swrq_npw_ad_ras_dp_err_log.valid;

  // strip out parity bits before push it into the RAM
  assign ss_swrq_npw_data_wo_par = fn_data_wo_par(ss_swrq_npw_data);
  assign ss_swrq_npw_addr_wo_par = fn_addr_wo_par(ss_swrq_npw_addr);
  // Without RME_PAS_EN - UR is the only error condition in use so to avoid RAM bits set to a fixed value cpl_stat is reduced to 1 bit
  assign ss_swrq_npw_ctl_wo_par  = {ss_swrq_npw_strb,ss_swrq_npw_addr_wo_par,ss_swrq_npw_ctl[SLV_NPW_CTL_WD-1:4],ss_swrq_npw_cpl_stat [0] ,ss_swrq_npw_ep};

  assign ss_npw_push_data = {ss_swrq_npw_ctl_wo_par, ss_swrq_npw_data_wo_par};

  // Instantiate Non-Posted write set-aside buffer
  DWC_pcie_bridge_sync_fifo_ram_latency
  
  #(
   .DATA_WIDTH                    ( SLV_NPW_SAB_RAM_DATA_WD_NOECC         )
  ,.ECC_WIDTH                     ( SLV_NPW_SAB_RAM_DATA_WD-SLV_NPW_SAB_RAM_DATA_WD_NOECC )
  ,.CX_RAS_RAM_PROT_RANGE         ( CX_RAS_RAM_PROT_RANGE                 )
  ,.RAM_DEPTH                     ( SLV_NPW_SAB_RAM_DP                    )
  ,.RAM_ADDR_WIDTH                ( SLV_NPW_SAB_RAM_ADDR_WD               )
  ,.AF_LVL                        ( {SLV_NPW_SAB_RAM_ADDR_WD{1'b1}}       )
  ,.RAS_DP_ID                     (`SRRP_RECC_NPW_SAB_RAS_ID              )
  ,.RAM_RD_LATENCY                ( SLV_NPW_SAB_RAM_RD_LATENCY            )
  )
  u_npwb
  (
   .clk                           ( slv_aclk                              )
  ,.rst_n                         ( slv_aresetn                           )
  ,.cfg_ras_correct               ( cfg_ras_recc_npw_sab_correct          )
  ,.ras_recc_corr_cnt_pulse       ( srrp_ras_recc_corr_cnt_npw_sab_pulse  )
  ,.ras_recc_ucorr_cnt_pulse      ( srrp_ras_recc_ucorr_cnt_npw_sab_pulse )
  ,.ras_recc_cnt_addr             ( srrp_ras_recc_cnt_npw_sab_addr        )
  ,.recc_syn_fifo_ras_dp_err_log  ( srrp_recc_npw_sab_ras_dp_err_log      )
  ,.ras_dp_err_inj                (ras_dp_err_inj_slv_aclk)
  // ------------------------------ ----------------------------------------------
  // External RAM interface
  ,.sfifo_wen                     ( srrq_npw_sab_wea                      )
  ,.sfifo_waddr                   ( srrq_npw_sab_addra                    )
  ,.sfifo_wdata                   ( srrq_npw_sab_dina                     )
  ,.sfifo_raddr                   ( srrq_npw_sab_addrb                    )
  ,.sfifo_ren                     ( srrq_npw_sab_enb                      )
  ,.rdata                         ( ram_npw_sab_doutb                     )
  // ------------------------------ ----------------------------------------------
  // Push interface
  ,.push_req_n                    ( ss_npw_push_n                         )
  ,.push_data                     ( ss_npw_push_data                      )
  ,.sfifo_f                       ( sfifo_f                               )
  ,.sfifo_af                      (                                       )
  // ------------------------------ ----------------------------------------------
  // Pop interface
  ,.sfifo_e                       (                                       )
  ,.sfifo_pop_valid               ( npwb_pop_valid                        )
  ,.sfifo_pop_data                ( npwb_pop_data                         )
  ,.ready                         ( s_npw_ready                           )
  );

  assign srrq_npw_ready = !s_sfifo_f;

  // Unpack the set-aside buffer interface
  // data, strb and ep wired directly to the top level
  assign { npwb_np_strb
         , npwb_npw_addr_i
         , npwb_npw_id
         , npwb_npw_len
         , npwb_npw_size
         , npwb_npw_last
         , npwb_npw_type
         , npwb_npw_snp
         , npwb_npw_tc
         , npwb_npw_ns
         , npwb_npw_ro
         , npwb_npw_nw
         , npwb_npw_ats
         , npwb_npw_tph
         , npwb_npw_ido
         , npwb_npw_first_wrp_split_xact
         , npwb_npw_wrp_valid
         , npwb_npw_db
         , npwb_npw_db_vldrq
         , npwb_npw_func_num
         , npwb_npw_tlpprfx
         , npwb_npw_atu_bypass
         , npwb_npw_dst_segment
         , npwb_npw_cpl_stat_0b
         , npwb_npw_ep
         , npwb_np_data_i
         } = npwb_pop_data;

  // Bringing cpl_stat back to 3 bit format after reading from RAM
  assign npwb_npw_cpl_stat = {2'b00,npwb_npw_cpl_stat_0b};

  // generate parity bits and interleave them after RAM pop
 assign npwb_np_data = fn_data_w_par(npwb_np_data_i);
 assign npwb_npw_addr = fn_addr_w_par(npwb_npw_addr_i);

  // Halt pop from buffer when np tags consumed or back pressure applied
  assign s_npw_ready = !(npwb_pop_valid && !(npmux_ready_a && !tag_fifo_full));

  // Mask the valid when the buffer is internally halted
  assign s_npw_valid = npwb_pop_valid && !tag_fifo_full;

  // ------------------------------------------------------------------------------------
  // Pack common mux info signals
  // Non-posted read
  assign s_npr_mux_info = { pdly1_np_addr, pdly1_np_id, pdly1_np_len, pdly1_np_size
                          , s_np_type, s_np_snp, pdly1_np_tc
                          , pdly1_np_db
                          , pdly1_np_db_vldrq
                          , s_np_func_num
                          , pdly1_np_tlpprfx
                          , pdly1_np_atu_bypass
                          , pdly1_np_dst_segment
                          , pdly1_np_cpl_stat
                          };

  // Non-posted write
  // {addr, id, len, size, type, tc, np/db, func_num, vfunc_num,vfunc_act, prfx, atu_byp}
  assign s_npw_mux_info = { npwb_npw_addr, npwb_npw_id, npwb_npw_len, npwb_npw_size
                          , npwb_npw_type , npwb_npw_snp, npwb_npw_tc
                          , npwb_npw_db
                          , npwb_npw_db_vldrq
                          , npwb_npw_func_num
                          , npwb_npw_tlpprfx
                          , npwb_npw_atu_bypass
                          , npwb_npw_dst_segment
                          , npwb_npw_cpl_stat
                          };

  // Instantiate np mux
  DWC_pcie_bridge_intf_mux
  
 #(.INTF_WD                                (MUX_INFO_WD)
  ,.MULTI_BEAT                             (0) // npw writes with trailing nulls not permitted
  )
  u_npmux
  (.clk                                    (slv_aclk)
  ,.rst_n                                  (slv_aresetn)
  // -------------------------------------------------------------------------------------
  // Interface A (Non-posted write)
  ,.valid_a                                (s_npw_valid)
  ,.last_a                                 (npwb_npw_last)
  ,.intf_a                                 (s_npw_mux_info)
  ,.ready_a                                (npmux_ready_a)
  // -------------------------------------------------------------------------------------
  // Interface B (Non-posted read)
  ,.valid_b                                (s_npr_valid)
  ,.last_b                                 (s_npr_valid)
  ,.intf_b                                 (s_npr_mux_info)
  ,.ready_b                                (npmux_ready_b)
  // -------------------------------------------------------------------------------------
  // Muxed Interface (Non-posted request)
  ,.mux_valid_a                            (npmux_np_wr)
  ,.mux_valid_b                            (npmux_np_rd)
  ,.mux_last                               (srrq_np_last)
  ,.mux_intf                               (npmux_intf)
  ,.ready                                  (s_ready)
  );

  // -------------------------------------------------------------------------------------
  // AXI tag manager control
  assign srrq_np_tag_consumed = (npmux_np_wr || npmux_np_rd) && s_ready;

  // -------------------------------------------------------------------------------------
  // Assign outputs
  // Common output signals
  assign { npmux_np_addr, srrq_np_id, srrq_np_len, srrq_np_size
         , npmux_np_type, srrq_np_snp, srrq_np_tc
         , npmux_np_db
         , npmux_np_db_vldrq
         , srrq_np_func_num
         , srrq_np_tlpprfx
         , srrq_np_atu_bypass
         , srrq_np_dst_segment
         , npmux_np_cpl_stat
        } = npmux_intf;

  // Decode IO & Cfg reads
  assign s_npmux_np_rd_io_cfg = npmux_np_rd && (
                                 (npmux_np_type==`CFG0_TYPE) ||
                                 (npmux_np_type==`CFG1_TYPE) ||
                                 (npmux_np_type==`IO_TYPE)
                                );


  // Non-posted write data applicable to Cfg/IO/DB and Atomic requests only
  assign srrq_np_data = npmux_np_wr ? npwb_np_data : {NUM_DATA_PAR_BLOCKS{pm, 8'd0}};
  assign srrq_np_strb = npmux_np_wr ? npwb_np_strb : 4'b0;

  // Non-posted read burst type applicable to Mem read requests only
  assign srrq_np_burst = npmux_np_wr ? INCR : pdly1_np_burst;

  assign srrq_np_type = npmux_np_type;

  // EP applicable to non-posted writes only
  assign srrq_np_ep = npmux_np_wr ? npwb_npw_ep : 1'b0;

  // For IO/Cfg requests RO, NS, and AT must be 0.
  // TH and IDO are reserved.
  // dnolan: TC must be 0, currently driven from misc info to facilitate
  // SATB error handling

   assign npmux_np_atomic = &npmux_np_type[3:2] & ~npmux_np_type[4];
   assign srrq_np_atomic  = npmux_np_wr && npmux_np_atomic;
   assign npmux_np_dmwr   = npmux_np_type == `DMWR_TYPE;
   assign srrq_np_dmwr    = npmux_np_wr && npmux_np_dmwr;
   assign srrq_np_first_wrp_split_xact = npwb_npw_first_wrp_split_xact && npmux_np_wr;
   assign srrq_np_wrp_valid            = npwb_npw_wrp_valid && npmux_np_wr;

  assign srrq_np_ro  =   (npmux_np_wr || s_npmux_np_rd_io_cfg) ?
                         (npmux_np_atomic)                     ? npwb_npw_ro :
                         (npmux_np_dmwr)                       ? npwb_npw_ro :
                                                                 1'b0        :
                                                                 pdly1_np_ro ;
  assign srrq_np_ns  =   (npmux_np_wr || s_npmux_np_rd_io_cfg) ?
                         (npmux_np_atomic)                     ? npwb_npw_ns :
                         (npmux_np_dmwr)                       ? npwb_npw_ns :
                                                                 1'b0        :
                                                                 pdly1_np_ns ;

  assign srrq_np_nw  =   (npmux_np_wr || s_npmux_np_rd_io_cfg) ?
                         (npmux_np_atomic)                     ? npwb_npw_nw :
                         (npmux_np_dmwr)                       ? npwb_npw_nw :
                                                                 1'b0        :
                                                                 pdly1_np_nw;
  assign srrq_np_ats =   (npmux_np_wr || s_npmux_np_rd_io_cfg) ?
                         (npmux_np_atomic)                     ? npwb_npw_ats :
                         (npmux_np_dmwr)                       ? npwb_npw_ats :
                                                                 2'b00        :
                                                                 pdly1_np_ats ;
  assign srrq_np_ido =   (npmux_np_wr || s_npmux_np_rd_io_cfg) ?
                         (npmux_np_dmwr)                       ? npwb_npw_ido :
                                                                 1'b0         :
                                                                 pdly1_np_ido ;
  assign srrq_np_tph =   (npmux_np_wr || s_npmux_np_rd_io_cfg) ?
                         (npmux_np_atomic)                     ?  npwb_npw_tph :
                         (npmux_np_dmwr)                       ?  npwb_npw_tph :
                                                                  {MISC_INFO_TPH_WD{1'b0}} :
                                                                  pdly1_np_tph ;

  // Extract start address
  assign s_npmux_np_addr = {{SLV_BUS_ADDR_WIDTH-SLAVE_BUS_ADDR_WIDTH{1'b0}}, fn_addr_wo_par(npmux_np_addr)};

  // -------------------------------------------------------------------------------------
  // Support wrap memory reads to prefetchable memory.
  // Re-align the starting address to the wrap boundary
  // Push the following info to the LUT
  // - number of beats from wrap boundary to starting address
  // - AXI aligner info:
  //       - wrap boundary low address bits
  //       - len
  //       - size
  // ------------------------------------------------------------------------------------
  // Beat offset from wrap boundary
  wire [SLV_BUS_ADDR_WIDTH-1:0] s_npmux_np_addr_adj;
  assign s_npmux_np_addr_adj = s_npmux_np_addr >> srrq_np_size;
  generate if (SLV_BURST_LEN_PW >= 4) begin : SLV_BURST_LEN_PW_IS_BIGGER_OR_EQUAL_THAN_4
    assign srrq_np_wrap_beat_offset = (srrq_np_burst==WRAP) ?
                                     s_npmux_np_addr_adj[3:0] & srrq_np_len[3:0] : {4{1'b0}};
  end else begin : SLV_BURST_LEN_PW_IS_SMALLER_THAN_4
    assign srrq_np_wrap_beat_offset = (srrq_np_burst==WRAP) ?
                                      s_npmux_np_addr_adj[3:0] & {{4-SLV_BURST_LEN_PW{1'b0}}, srrq_np_len} : {4{1'b0}};
  end
  endgenerate
  // Wrap boundary
  assign s_wrap_bndry_wo_par = s_npmux_np_addr[SLAVE_BUS_ADDR_WIDTH-1:0] & (~({{SLAVE_BUS_ADDR_WIDTH-SLV_BURST_LEN_PW{1'b0}}, srrq_np_len} << srrq_np_size));
  // Data width address offset from wrap boundary
  assign srrq_np_addr_low = (srrq_np_burst==WRAP) ?
                             s_wrap_bndry_wo_par[SLV_BUS_STRB_PW-1:0] :
                             s_npmux_np_addr[SLV_BUS_STRB_PW-1:0];
  // Address
  assign ss_npmux_np_addr = (srrq_np_burst==WRAP) ?
                         fn_addr_w_par(s_wrap_bndry_wo_par) :
                         npmux_np_addr;


  // -------------------------------------------------------------------------------------
  // If Cfg/IO Read and 64 bit slave address then the upper 32 address bits are normally
  // zero. However if the ATU is enabled we need to pass the all 64 bits to enable
  // the PCIe core to match the slave address and perform the translation.
  // The Bridge passes the raw address to the Client interface for all IO & Cfg Reads.
  assign srrq_np_addr = ss_npmux_np_addr;

  // The data bus interface does not support parity.
  // If ARI is enabled the slave address must be 64 bits (dnolan: add check expression)
  // The required number of DB address bits is 33 for ARI configs.
  // DB accesses are dword aligned, i.e. address bits [1:0] are all zeros.
  // Byte writes enabled using the write strobes.
  // The MSB is used by the DB interface block to route DB accesses to the ELBI or
  // CDM interface (1:ELBI, 0: CDM)

  assign srrq_db_addr = s_npmux_np_addr[DBI_SLV_BUS_ADDR_WIDTH-1:0];

  // The DB data width is fixed at 32-bits, no parity
  assign srrq_db_data = fn_db_data_wo_par(srrq_np_data[35:0]);

  // Data strobe
  assign srrq_db_strb = srrq_np_strb[3:0];
  assign srrq_db_len  = srrq_np_len;

  logic                s_npmux_np_db;
  assign s_npmux_np_db = npmux_np_db;

  // NP/DB shared mux interface signals
  assign srrq_np_wr    = npmux_np_wr && !s_npmux_np_db;
  assign srrq_np_rd    = npmux_np_rd && !s_npmux_np_db;
  assign srrq_db_wr    = npmux_np_wr && s_npmux_np_db && !atm_dbi_req_halt;
  assign srrq_db_rd    = npmux_np_rd && s_npmux_np_db && !atm_dbi_req_halt;
  assign srrq_db_vldrq = npmux_np_db_vldrq && !atm_dbi_req_halt;
  assign s_ready       = s_npmux_np_db ? dbi_ready && !atm_dbi_req_halt: nprf_ready;




  // -------------------------------------------------------------------------------------
  // Some software systems depend on reading all 1's in the read data associated with
  // a CfgRd to a non-existent device. The bridge synthesizes this value when the UR
  // completion status is returned is response to a CfgRd to the vendor ID register.
  //
  // Detect the vendor ID register read and mark the request in the AXI tag LUT.
  // When the completion returns the LUT is searched to recover the request info and
  // to generate the AXI response. By default OKAY with all FF's is returned.
  // and the UR completion status is sent on the sideband bus.
  // If the port logic register bit cfg_err_resp_mode[2], is set to 1, then SLVERR/DECERR
  // is returned. Config accesses are dword aligned with a size of 4 bytes.
  assign s_cfg_rd_type = (npmux_np_type==CFG0_TYPE) || (npmux_np_type==CFG1_TYPE);

  // Extract start address
  assign s_npmux_addr_wo_par = {{SLV_BUS_ADDR_WIDTH-SLAVE_BUS_ADDR_WIDTH{1'b0}}, fn_addr_wo_par(npmux_np_addr)};

  assign srrq_np_ven_id_rd = srrq_np_rd && s_cfg_rd_type &&
                             (s_npmux_addr_wo_par[11:0]==VENDOR_ID_ADDR) &&
                             (srrq_np_size!=1'b0) ;



always_comb
begin
     srrq_np_cpl_stat        = npmux_np_cpl_stat;
end

  // -------------------------------------------------------------------------------------
  // Low power
  assign csysack = 1'b1;
  assign cactive = 1'b1;

  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  function automatic [NUM_ADDR_PAR_BLOCKS-1:0] fn_prot_chkin_ad;
    input [SLV_BUS_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_ad[i] = s_addr_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction

  function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_d;
    input [SLV_BUS_NPDATA_WIDTH_NP-1+NUM_DATA_PAR_BLOCKS:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_d[i] = s_data_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction
  // Address without parity
  function automatic [SLAVE_BUS_ADDR_WIDTH-1:0] fn_addr_wo_par;
    input [SLV_BUS_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_addr_wo_par[i*CX_RAS_PROT_RANGE +j] = s_addr_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction

  // Data without parity
  function automatic [31:0] fn_db_data_wo_par;
    input [35:0] s_data_w_par;
    integer i,j;
    begin
      for (i=0; i<4; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_db_data_wo_par[i*CX_RAS_PROT_RANGE +j] = s_data_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction

  // Wr Req Data without parity
  function automatic [SLV_BUS_NPDATA_WIDTH_NP-1:0] fn_data_wo_par;
    input [SLV_BUS_NPDATA_WIDTH_NP-1+NUM_DATA_PAR_BLOCKS:0] s_data_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_data_wo_par[i*CX_RAS_PROT_RANGE +j] = s_data_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction

  // Data with parity
  function automatic [SLV_BUS_NPDATA_WIDTH_NP-1+NUM_DATA_PAR_BLOCKS:0] fn_data_w_par;
    input [SLV_BUS_NPDATA_WIDTH_NP-1:0] s_data_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_data_for_par;

    begin
    fn_data_w_par  = {(SLV_BUS_NPDATA_WIDTH_NP+NUM_DATA_PAR_BLOCKS){1'b0}};
    s_data_for_par = {CX_RAS_PROT_RANGE{1'b0}};

      for (i=0; i<(NUM_DATA_PAR_BLOCKS); i=i+1) begin
        for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
          s_data_for_par[j]=s_data_wo_par[i*CX_RAS_PROT_RANGE +j];
          fn_data_w_par[i*CX_RAS_PROT_RANGE +j+i] = s_data_wo_par[i*CX_RAS_PROT_RANGE +j];
        end
        fn_data_w_par[(i+1)*CX_RAS_PROT_RANGE +i] = CX_RAS_PARITY_MODE ? ~(^s_data_for_par) : ^s_data_for_par;
      end
    end
  endfunction


  // Address with parity
  function automatic [SLV_BUS_ADDR_WIDTH-1:0] fn_addr_w_par;
    input [SLAVE_BUS_ADDR_WIDTH-1:0] s_addr_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_addr_for_par;

    begin
    fn_addr_w_par  = 0;
    s_addr_for_par = 0;

      for (i=0; i<(NUM_ADDR_PAR_BLOCKS); i=i+1) begin
         for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
     s_addr_for_par[j]=s_addr_wo_par[i*CX_RAS_PROT_RANGE +j];
     fn_addr_w_par[i*CX_RAS_PROT_RANGE +j+i] = s_addr_wo_par[i*CX_RAS_PROT_RANGE +j];
         end
          fn_addr_w_par[(i+1)*CX_RAS_PROT_RANGE +i] = CX_RAS_PARITY_MODE ? ~(^s_addr_for_par) : ^s_addr_for_par;
      end
    end
  endfunction


  // Swap data for Atomic WRAP requests
  function automatic [SLV_BUS_NPDATA_WIDTH-1:0] fn_atomic_cas_data_swap;
    input [SLV_BUS_NPDATA_WIDTH-1:0] s_data;
    input [2:0]                      s_size;
    input [SLV_BURST_LEN_PW-1:0]     s_len;
    begin

      reg [CC_SLV_MAX_BYTES_PW-1:0] s_req_total_bytes;

      s_req_total_bytes = CC_SLV_MAX_BYTES_PW'((s_len+1) << s_size);

      fn_atomic_cas_data_swap = s_data;

      case (s_req_total_bytes)
        'd8 : fn_atomic_cas_data_swap[ 71:0] = {s_data[ 35:0] , s_data[ 71: 36]};
        'd16: fn_atomic_cas_data_swap[143:0] = {s_data[ 71:0] , s_data[143: 72]};
        'd32: fn_atomic_cas_data_swap[287:0] = {s_data[143:0] , s_data[287:144]};
        default:
          fn_atomic_cas_data_swap = s_data;
      endcase

    end
  endfunction

  // Transforms data from Big-Endian format into Little-Endian format
  function automatic [SLV_BUS_NPDATA_WIDTH-1:0] fn_atomic_data_be_to_le;
    input [SLV_BUS_NPDATA_WIDTH-1:0] s_data;
    input [2:0]                      s_size;
    input [SLV_BURST_LEN_PW-1:0]     s_len;
    begin

      reg [CC_SLV_MAX_BYTES_PW-1:0] s_req_total_bytes;

      s_req_total_bytes = CC_SLV_MAX_BYTES_PW'((s_len+1) << s_size);

      fn_atomic_data_be_to_le = s_data;

      case (s_req_total_bytes)
        'd4 : fn_atomic_data_be_to_le[35:0] = {s_data[8:0] , s_data[17:9], s_data[26:18] , s_data[35:27]};
        'd8 : fn_atomic_data_be_to_le[71:0] = {s_data[8:0] , s_data[17:9], s_data[26:18] , s_data[35:27], s_data[44:36] , s_data[53:45], s_data[62:54] , s_data[71:63]};
        default:
          fn_atomic_data_be_to_le = s_data;
      endcase

    end
  endfunction



`ifndef SYNTHESIS

   //--------------------------------------------------------------------
   // RAS.DP Testbench guides for error injection
   //--------------------------------------------------------------------

   // see amba_defs.vh for macros starting with DC_
  `define SLV_NPW_SAB_RAM_DT_PTR 0

  `define SLV_NPW_SAB_RAM_DT_PTRW `CC_SLV_BUS_WREQ_NPDATA_WIDTH_NP

  `define SLV_NPW_SAB_RAM_AD_PTR `CC_SLV_NPW_SAB_RAM_DATA_WD_NOECC - `SLAVE_BUS_ADDR_WIDTH

  `define SLV_NPW_SAB_RAM_AD_PTRW `SLAVE_BUS_ADDR_WIDTH


`endif //  `ifndef SYNTHESIS


endmodule
