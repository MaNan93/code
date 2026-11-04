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
// ---    $Revision: #20 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_wreq.sv#20 $
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"


 module DWC_pcie_axi_slv_wreq
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::RAS_DP_PROT_CHK_ID_BASE_AXI_BRIDGE;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 #(
  // -------------------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter SLV_BUS_ID_WIDTH                = 4,
  parameter SLV_BUS_ADDR_WIDTH              = 32,
  parameter SLAVE_BUS_ADDR_WIDTH            = 32, // addr without parity
  parameter CX_RAS_PROT_RANGE                = `CX_RAS_PROT_RANGE,
  parameter CX_RAS_PARITY_MODE               = `CX_RAS_PARITY_MODE,
  parameter CX_TAG_SIZE                     = `CX_TAG_SIZE,
  parameter SLV_BURST_LEN_PW                = 2,
  parameter SLV_BUS_DATA_WIDTH              = 32,
  parameter SLAVE_BUS_DATA_WIDTH            = `SLAVE_BUS_DATA_WIDTH,
  parameter SLV_BUS_WSTRB_WIDTH             = 4,
  parameter SLV_BUS_WSTRB_PW                = 2,
  parameter SLV_BUS_WREQ_NPWSTRB_WIDTH      = `CC_SLV_BUS_WREQ_NPWSTRB_WIDTH,  // Write Strobes bus width for Non-Posted writes interface
  parameter SLV_BUS_WREQ_NPDATA_WIDTH       = `CC_SLV_BUS_WREQ_NPDATA_WIDTH, // Data bus width for Non-Posted writes interface
  parameter AXI_LOCK_WIDTH                  = 1,
  parameter SLV_MISC_INFO_WD                = 12,
  parameter MISC_INFO_TPH_WD                = 11,
  parameter TX_TLP_PREFIX_WD                = 32,
  parameter NFUNC_WD                        = 4,
  parameter ATU_OUT_MIN1                    = 2,
  parameter ATU_OUT_REGIONS                 = 2,
  parameter ATU_BASE_WD                     = 32,
  parameter ATU_REG_WD                      = 16,
  parameter ATU_UPR_LMT_WD                  = 8,
  parameter DC_CPL_STATUS_WD                = `DC_CPL_STATUS_WD,
  parameter CC_SLV_MAX_BYTES_PW             = `CC_SLV_MAX_BYTES_PW,
  // -------------------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // -------------------------------------------------------------------------------------
  parameter TP                              = `TP
  )
  
                               (
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  input                                  slv_aclk,
  input                                  slv_aresetn,
  input                                  cfg_dmwr_req_en,
  // -------------------------------------------------------------------------------------
  // ATU interface
  // -------------------------------------------------------------------------------------
  input [(ATU_BASE_WD*ATU_OUT_MIN1)-1:0] atu_reg_out_upr_base,
  input [ATU_OUT_MIN1-1:0]               atu_reg_out_en,
  input [(5*ATU_OUT_MIN1)-1:0]           atu_reg_out_type,
  input [(ATU_REG_WD*ATU_OUT_MIN1)-1:0]  atu_reg_out_base,
  input [(ATU_REG_WD*ATU_OUT_MIN1)-1:0]  atu_reg_out_limit,
  input [ATU_UPR_LMT_WD*ATU_OUT_MIN1-1:0] atu_reg_out_uppr_limit,
  input [ATU_OUT_MIN1-1:0]               atu_reg_out_incr_rgn_size,    // Maximum region size control bit
  input [ATU_OUT_MIN1-1:0]               atu_reg_out_invert,
  input [(NFUNC_WD*ATU_OUT_MIN1)-1:0]    atu_reg_out_func_num,
  input [ATU_OUT_MIN1-1:0]               atu_reg_out_func_bypass,
  input [ATU_OUT_MIN1-1:0]               atu_reg_out_snp,
  // -------------------------------------------------------------------------------------
  // Slave Write Address Channel
  input                                  awvalid,
  input [SLV_BUS_ID_WIDTH-1:0]           awid,
  input [SLV_BUS_ADDR_WIDTH-1:0]         awaddr,
  input [SLV_BURST_LEN_PW-1:0]           awlen,
  input [2:0]                            awsize,
  input [1:0]                            awburst,
  input [5:0]                            awatop,
  input [4:0]                            awmisc_info_type,
  input                                  awmisc_info_snp,
  input                                  awmisc_info_ep,
  input                                  awmisc_info_ns,
  input                                  awmisc_info_ro,
  input [2:0]                            awmisc_info_tc,
  input [7:0]                            awmisc_info_msg_code,
  input                                  awmisc_info_db,
  input [NFUNC_WD-1:0]                   awmisc_info_func_num,
  input                                  awmisc_info_nw,
  input [1:0]                            awmisc_info_ats,
  input [TX_TLP_PREFIX_WD-1:0]           awmisc_info_tlpprfx,
  input [CX_TAG_SIZE-1:0]                awmisc_info_p_tag,
  input [MISC_INFO_TPH_WD-1:0]           awmisc_info_tph,
  input                                  awmisc_info_atu_bypass,
  input [8:0]                            awmisc_info_dst_segment,
  input                                  awmisc_info_ido,
  output wire                            awready,
// -------------------------------------------------------------------------------------
// Slave Write Data Channel
  input                                  wvalid,
  input [SLV_BUS_ID_WIDTH-1:0]           wid,
  input [SLV_BUS_DATA_WIDTH-1:0]         wdata,
  input [SLV_BUS_WSTRB_WIDTH-1:0]        wstrb,
  input                                  wlast,
  input                                  wmisc_info_ep,
  input                                  wmisc_info_silentDrop,
  output wire                            wready,
  // -------------------------------------------------------------------------------------
  // Write Request Info Interface
  output wire                            swrq_wr_valid_hl,
  output wire [SLV_BUS_ID_WIDTH-1:0]     swrq_wr_id,
  output wire                            swrq_wr_p,
  output wire                            swrq_wr_np,
  output wire                            swrq_wr_np_atomic,
  output wire                            swrq_wr_last_null_writes,
// -------------------------------------------------------------------------------------
// Slave Posted Request Interface
  output wire                            swrq_p_valid,
  output wire [SLV_BUS_ADDR_WIDTH-1:0]   swrq_p_addr,
  output wire [2:0]                      swrq_p_size,
  output wire [SLV_BURST_LEN_PW-1:0]     swrq_p_len,
  output wire                            swrq_p_last,
  output wire [SLV_BUS_WSTRB_WIDTH-1:0]  swrq_p_strb,
  output wire [SLV_BUS_WSTRB_WIDTH-1:0]  swrq_p_ep_strb,
  output wire [SLV_BUS_WSTRB_WIDTH-1:0]  swrq_p_silentDrop_strb,
  output wire [SLV_BUS_WSTRB_WIDTH-1:0]  swrq_p_silentDrop_strb_masked,
  output wire [SLV_BUS_DATA_WIDTH-1:0]   swrq_p_data,
  output wire [7:0]                      swrq_p_msg_code,
  output wire [4:0]                      swrq_p_type,
  output wire [2:0]                      swrq_p_tc,
  output wire                            swrq_p_ep,
  output wire                            swrq_p_ro,
  output wire                            swrq_p_ns,
  output wire                            swrq_p_ido,
  output wire                            swrq_p_first_wrp_split_xact,
  output wire                            swrq_p_wrp_valid,
  output wire                            swrq_p_nw,
  output wire [1:0]                      swrq_p_ats,
  output wire [NFUNC_WD-1:0]             swrq_p_func_num,
  output wire [MISC_INFO_TPH_WD-1:0]     swrq_p_tph,
  output wire [TX_TLP_PREFIX_WD-1:0]     swrq_p_tlpprfx,
  output wire [CX_TAG_SIZE-1:0]          swrq_p_tag,
  output wire                            swrq_p_atu_bypass,
  output wire [8:0]                      swrq_p_dst_segment,
  output wire [SLV_BUS_ID_WIDTH-1:0]     swrq_p_id,
  output logic [DC_CPL_STATUS_WD-1:0]    swrq_p_cpl_stat,
  input                                  prf_ready,
  // -------------------------------------------------------------------------------------
  // Non-Posted Write Request Interface
  output wire                            swrq_npw_valid,
  output wire [SLV_BUS_ADDR_WIDTH-1:0]   swrq_npw_addr,
  output wire [2:0]                      swrq_npw_size,
  output wire [SLV_BURST_LEN_PW-1:0]     swrq_npw_len,
  output wire                            swrq_npw_last,
  output wire [SLV_BUS_WREQ_NPWSTRB_WIDTH-1:0] swrq_npw_strb,
  output wire [SLV_BUS_WREQ_NPDATA_WIDTH-1:0]  swrq_npw_data,
  output wire [4:0]                      swrq_npw_type,
  output wire                            swrq_npw_snp,
  output wire [2:0]                      swrq_npw_tc,
  output wire                            swrq_npw_ep,
  output wire                            swrq_npw_atomic_load_be,
  output wire                            swrq_npw_atomic_cas_wrap,
  output wire                            swrq_npw_ns,
  output wire                            swrq_npw_ro,
  output wire                            swrq_npw_nw,
  output wire [1:0]                      swrq_npw_ats,
  output wire [MISC_INFO_TPH_WD-1:0]     swrq_npw_tph,
  output wire                            swrq_npw_first_wrp_split_xact,
  output wire                            swrq_npw_wrp_valid,
  output wire                            swrq_npw_db,
  output wire                            swrq_npw_db_vldrq,
  output wire [NFUNC_WD-1:0]             swrq_npw_func_num,
  output wire [TX_TLP_PREFIX_WD-1:0]     swrq_npw_tlpprfx,
  output wire                            swrq_npw_atu_bypass,
  output wire [8:0]                      swrq_npw_dst_segment,
  output                                 swrq_npw_ido,
  output wire [2:0]                      swrq_npw_cpl_stat,
  // -------------------------------------------------------------------------------------
  // Parity error interface
  output wire                            swrq_addr_parerr,
  output wire                            swrq_data_parerr,
    input  ras_dp_err_inj_t                    ras_dp_err_inj_slv_aclk,
  output ras_dp_err_log_t                swrq_dt_ras_dp_err_log,
  output ras_dp_err_log_t                swrq_ad_ras_dp_err_log,
  output wire                            swrq_ras_par_swwrap_dt_pulse,
  output wire                            swrq_ras_par_swwrap_ad_pulse,
  output ras_dp_err_log_t                swrq_swwrap_dt_ras_dp_err_log,
  output ras_dp_err_log_t                swrq_swwrap_ad_ras_dp_err_log,
  // -------------------------------------------------------------------------------------
  output wire [SLV_BUS_ID_WIDTH-1:0]     swrq_npw_id,
  input                                  srrq_npw_ready
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam CFG0_TYPE = `CFG0_TYPE;
  localparam CFG1_TYPE = `CFG1_TYPE;
  localparam IO_TYPE   = `IO_TYPE;
  localparam MEM_TYPE  = `MEM_TYPE;
  localparam MEM_TYPE_LOCKED = `MEM_TYPE_LOCKED;
  localparam DMWR_TYPE = `DMWR_TYPE;
  localparam ATOP_FETCH_ADD = `ATOP_FETCH_ADD;
  localparam ATOP_SWAP = `ATOP_SWAP;
  localparam ATOP_CAS  = `ATOP_CAS;

  // AW Channel Interface width
  // {valid, id, addr, len, size, burst, type, snp, ep, ns, ro, tc, msg_code
  //  db, db_ecam ,pf, nw, ats, vfunc, vfunc act, prfx,ln, itag, tph, atu_byp, ido,
  //  atomic, idunq, cpl_stat }
  localparam AW_INTF_WIDTH = {
               1
               + SLV_BUS_ID_WIDTH
               + SLV_BUS_ADDR_WIDTH
               + SLV_BURST_LEN_PW
               + 3
               + 2
               + 5
               + 4
               + 3
               + 8
               + 1
               + NFUNC_WD
               + 3
               + TX_TLP_PREFIX_WD
               + CX_TAG_SIZE
               + MISC_INFO_TPH_WD
               + 1
               + 9
               + 1
               + 2
               + 3
               };

  // W Channel Interface width
  // { valid, id, data, strb, last, ep, silentDrop }
  localparam W_INTF_WIDTH = { 1
                            + SLV_BUS_ID_WIDTH
                            + SLV_BUS_DATA_WIDTH
                            + SLV_BUS_WSTRB_WIDTH
                            + 1
                            + 1
                            + 1
                            };

  // Packed Write Misc Info
  // {id,type,snp,ep,ns,ro,tc,msg_code,db,db_ecam,func_num,nw,ats,vfunc_num,vfunc_active,
  // tlp_prfx,tlp_ln, itag, tph,atu_bypass, dst_segment, ido, atomic_load_be}
  localparam WR_MISC_INFO_WD = { SLV_BUS_ID_WIDTH
                               + 20
                               + 2
                               + NFUNC_WD
                               + 3
                               + TX_TLP_PREFIX_WD
                               + CX_TAG_SIZE
                               + MISC_INFO_TPH_WD
                               + 1
                               + 9
                               + 1
                               + 2
                               + 3
                               };

  // Posted control
  // {valid, len, size, addr, data, strb, ep_strb, last, lastReq}
  localparam WR_P_CTL_WD = { 1
                           + SLV_BURST_LEN_PW
                           + 3
                           + SLV_BUS_ADDR_WIDTH
                           + SLV_BUS_DATA_WIDTH
                           + SLV_BUS_WSTRB_WIDTH
                           + SLV_BUS_WSTRB_WIDTH
                           + SLV_BUS_WSTRB_WIDTH
                           + SLV_BUS_WSTRB_WIDTH
                           + 1
                           };

  // Posted info
  // {id,type,ep,ns,ro,tc,msg_code,func_num,nw,ats,vfunc_num,vfunc_active,
  // tlp_prfx,ln, itag, tph,atu_bypass,ido, first_wrp_split_xact,nse}
  localparam WR_P_INFO_WD = { WR_MISC_INFO_WD - 1
                            - 2 // Data bus flag removed
                            + 2
                            - 2
                            };


  localparam WR_P_INTF_WD = { WR_P_CTL_WD + WR_P_INFO_WD};

  // Non-Posted control
  // {valid, len, size, addr, data, strb, last}
  localparam WR_NP_CTL_WD = { 1
                            + SLV_BURST_LEN_PW
                            + 3
                            + SLV_BUS_ADDR_WIDTH
                            + SLV_BUS_WREQ_NPDATA_WIDTH
                            + SLV_BUS_WREQ_NPWSTRB_WIDTH
                            + 1
                            };

  // Non-Posted info
  // {id,type,snp,ep,tc,db,ecam_db,awecam_enum_err,func_num,vfunc_num,vfunc_active,tlp_prfx,ln,tph,atu_bypass,dst_segment,ido,idunq,nse,cpl_stat}
  localparam WR_NP_INFO_WD = { SLV_BUS_ID_WIDTH
                             + 10
                             + 2
                             + 2
                             + 3
                             + MISC_INFO_TPH_WD
                             + 2
                             + 2
                             + NFUNC_WD
                             + TX_TLP_PREFIX_WD
                             + 1
                             + 9
                             + 1
                             };

  localparam WR_NP_INTF_WD = { WR_NP_CTL_WD + WR_NP_INFO_WD};

    localparam [8:0] BUS_INIT_BYTE = CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;


    // Number of parity address blocks per 32/64 bit address
    localparam NUM_ADDR_PAR_BLOCKS  = SLAVE_BUS_ADDR_WIDTH/CX_RAS_PROT_RANGE;
    // Number of parity data blocks for a single dword
    localparam NUM_DATA_PAR_BLOCKS  = SLAVE_BUS_DATA_WIDTH/CX_RAS_PROT_RANGE;
    localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N);

  localparam NP_NUM_PARITY_BYTES = SLV_BUS_WREQ_NPWSTRB_WIDTH;  // Number of Non Posted parity bytes



  // -------------------------------------------------------------------------------------
  // Internal Wires
  // -------------------------------------------------------------------------------------
  // pdly1
  wire [AW_INTF_WIDTH-1:0]                 s_aw_intf;
  wire [2:0]                               awmisc_info_cpl_stat;
  wire                                     pdly1_halt;
  wire [AW_INTF_WIDTH-1:0]                 pdly1_aw_intf;
  wire                                     s_wif_aw_halt;

  // Pipeline delayed AW channel
  wire                                     pdly1_awvalid;
  wire [SLV_BUS_ID_WIDTH-1:0]              pdly1_awid;
  wire [SLV_BUS_ADDR_WIDTH-1:0]            pdly1_awaddr;
  wire [SLV_BURST_LEN_PW-1:0]              pdly1_awlen;
  wire [2:0]                               pdly1_awsize;
  wire [1:0]                               pdly1_awburst;
  wire [4:0]                               pdly1_awmisc_info_type;

  wire                                     pdly1_awmisc_info_snp;
  wire                                     pdly1_awmisc_info_ep;
  wire                                     pdly1_awmisc_info_ns;
  wire                                     pdly1_awmisc_info_ro;
  wire [2:0]                               pdly1_awmisc_info_tc;
  wire [7:0]                               pdly1_awmisc_info_msg_code;
  wire                                     pdly1_awmisc_info_db;
  wire [NFUNC_WD-1:0]                      pdly1_awmisc_info_func_num;
  wire                                     pdly1_awmisc_info_nw;
  wire [1:0]                               pdly1_awmisc_info_ats;
  wire [TX_TLP_PREFIX_WD-1:0]              pdly1_awmisc_info_tlpprfx;
  wire [2:0]                               pdly1_awmisc_info_cpl_stat;
  wire [CX_TAG_SIZE-1:0]                   pdly1_awmisc_info_p_tag;
  wire [MISC_INFO_TPH_WD-1:0]              pdly1_awmisc_info_tph;
  wire                                     pdly1_awmisc_info_atu_bypass;
  wire [8:0]                               pdly1_awmisc_info_dst_segment;
  wire                                     pdly1_awmisc_info_ido;
  wire                                     pdly1_awatop_atomic_load_be;
  wire                                     pdly1_awburst_atomic_cas_wrap;
  wire                                     wif_awready;

  // pdly2
  wire [W_INTF_WIDTH-1:0]                  s_w_intf;
  wire                                     pdly2_halt;
  wire [W_INTF_WIDTH-1:0]                  pdly2_w_intf;
  wire                                     s_wif_w_halt;

  // Pipeline delayed W channel
  wire                                     pdly2_wvalid;
  wire [SLV_BUS_ID_WIDTH-1:0]              pdly2_wid;
  wire [SLV_BUS_DATA_WIDTH-1:0]            pdly2_wdata;
  wire [SLV_BUS_WSTRB_WIDTH-1:0]           pdly2_wstrb;
  wire                                     pdly2_wlast;
  wire                                     pdly2_wmisc_info_ep;
  wire                                     pdly2_wmisc_info_silentDrop;
  wire                                     wif_wready;

  // wif ->
  wire                                     wif_valid;
  wire [SLV_BUS_ID_WIDTH-1:0]              wif_id;
  wire [SLV_BUS_ADDR_WIDTH-1:0]            wif_addr;
  wire [SLV_BURST_LEN_PW -1:0]             wif_len;
  wire [2:0]                               wif_size;
  wire [1:0]                               wif_burst;
  wire                                     wif_last;
  wire [SLV_BUS_WSTRB_WIDTH-1:0]           wif_strb;
  wire [WR_MISC_INFO_WD-1:0]               wif_info;
  wire [SLV_BUS_WSTRB_WIDTH-1:0]           wif_wep_strb;
  wire [SLV_BUS_WSTRB_WIDTH-1:0]           wif_wsilentDrop_strb;
  wire [SLV_BUS_WSTRB_WIDTH-1:0]           wif_wsilentDrop_strb_masked;
  wire [SLV_BUS_DATA_WIDTH-1:0]            wif_data;
  wire [SLV_MISC_INFO_WD-1:0]              wif_misc_info;
  wire [TX_TLP_PREFIX_WD-1:0]              wif_tlp_prfx;
  wire [MISC_INFO_TPH_WD-1:0]              wif_tph;
  wire                                     wif_atu_bypass;
  wire [8:0]                               wif_dst_segment;
  wire [SLV_BUS_ADDR_WIDTH-1:0]            wwrp_addr;
  wire [SLV_BURST_LEN_PW-1:0]              wwrp_len;
  wire                                     wwrp_last;
  wire                                     wwrp_first_wrp_split_xact;
  wire                                     wwrp_valid;
  // lnull ->
  wire                                     lnull_valid, s_lnull_valid;
  reg                                      r_lnull_valid;
  wire [SLV_BUS_ID_WIDTH-1:0]              lnull_id, s_lnull_id;
  reg  [SLV_BUS_ID_WIDTH-1:0]              r_lnull_id;
  wire [SLV_BUS_ADDR_WIDTH-1:0]            lnull_addr, s_lnull_addr;
  reg  [SLV_BUS_ADDR_WIDTH-1:0]            r_lnull_addr;
  wire [SLAVE_BUS_ADDR_WIDTH-1:0]          lnull_addr_wo_par;
  wire [SLV_BURST_LEN_PW-1:0]              lnull_len, s_lnull_len;
  reg  [SLV_BURST_LEN_PW-1:0]              r_lnull_len;
  wire [2:0]                               lnull_size, s_lnull_size;
  reg  [2:0]                               r_lnull_size;
  wire [WR_MISC_INFO_WD-1:0]               lnull_info;
  wire                                     lnull_first_wrp_split_xact, s_lnull_first_wrp_split_xact;
  reg                                      r_lnull_first_wrp_split_xact;
  wire                                     lnull_wrp_valid, s_lnull_wrp_valid;
  reg                                      r_lnull_wrp_valid;
  wire [4:0]                               lnull_type;
  wire                                     lnull_snp;
  wire                                     lnull_ep, s_lnull_ep;
  reg                                      r_lnull_ep;
  wire                                     lnull_ns, s_lnull_ns;
  reg                                      r_lnull_ns;
  wire                                     lnull_ro, s_lnull_ro;
  reg                                      r_lnull_ro;
  wire [2:0]                               lnull_tc, s_lnull_tc;
  reg  [2:0]                               r_lnull_tc;
  wire [7:0]                               lnull_msg_code, s_lnull_msg_code;
  reg  [7:0]                               r_lnull_msg_code;
  wire                                     lnull_db, s_lnull_db;
  reg                                      r_lnull_db;
  wire                                     lnull_db_vldrq, s_lnull_db_vldrq;
  reg                                      r_lnull_db_vldrq;
  wire [NFUNC_WD-1:0]                      lnull_func_num;
  wire                                     lnull_nw, s_lnull_nw;
  reg                                      r_lnull_nw;
  wire [1:0]                               lnull_ats, s_lnull_ats;
  reg  [1:0]                               r_lnull_ats;
  wire [TX_TLP_PREFIX_WD-1:0]              lnull_tlpprfx, s_lnull_tlpprfx;
  reg  [TX_TLP_PREFIX_WD-1:0]              r_lnull_tlpprfx;
  wire [2:0]                               lnull_cpl_stat, s_lnull_cpl_stat;
  reg  [2:0]                               r_lnull_cpl_stat;
  wire [CX_TAG_SIZE-1:0]                   lnull_awmisc_info_p_tag, s_lnull_awmisc_info_p_tag;
  reg  [CX_TAG_SIZE-1:0]                   r_lnull_awmisc_info_p_tag;
  wire [MISC_INFO_TPH_WD-1:0]              lnull_tph, s_lnull_tph;
  reg  [MISC_INFO_TPH_WD-1:0]              r_lnull_tph;
  wire                                     lnull_atu_bypass, s_lnull_atu_bypass;
  reg                                      r_lnull_atu_bypass;
  wire [8:0]                               lnull_dst_segment, s_lnull_dst_segment;
  reg  [8:0]                               r_lnull_dst_segment;
  wire                                     lnull_ido, s_lnull_ido;
  reg                                      r_lnull_ido;
  wire                                     lnull_atomic_load_be, s_lnull_atomic_load_be;
  wire                                     lnull_atomic_cas_wrap, s_lnull_atomic_cas_wrap;
  reg                                      r_lnull_atomic_load_be;
  reg                                      r_lnull_atomic_cas_wrap;

  wire                                     dwalgn_ready;
  wire                                     dwalgn_valid, dwalgn_last;
  wire [SLV_BUS_WSTRB_WIDTH-1:0]           dwalgn_strb, s_dwalgn_strb;
  reg  [SLV_BUS_WSTRB_WIDTH-1:0]           r_dwalgn_strb;
  wire [SLV_BUS_WSTRB_WIDTH-1:0]           dwalgn_ep_strb, s_dwalgn_ep_strb;
  wire [SLV_BUS_WSTRB_WIDTH-1:0]           dwalgn_silentDrop_strb, s_dwalgn_silentDrop_strb;
  wire [SLV_BUS_WSTRB_WIDTH-1:0]           dwalgn_silentDrop_strb_masked, s_dwalgn_silentDrop_strb_masked;
  reg  [SLV_BUS_WSTRB_WIDTH-1:0]           r_dwalgn_ep_strb;
  reg  [SLV_BUS_WSTRB_WIDTH-1:0]           r_dwalgn_silentDrop_strb;
  reg  [SLV_BUS_WSTRB_WIDTH-1:0]           r_dwalgn_silentDrop_strb_masked;
  wire [SLV_BUS_DATA_WIDTH-1:0]            dwalgn_data, s_dwalgn_data;
  reg  [SLV_BUS_DATA_WIDTH-1:0]            r_dwalgn_data;

  // atu ->
  wire [4:0]                               s_type, s_s_type;
  reg  [4:0]                               r_s_type;
  wire [NFUNC_WD-1:0]                      s_func_num, s_s_func_num;
  reg  [NFUNC_WD-1:0]                      r_s_func_num;
  wire                                     s_snp, s_s_snp;
  reg                                      r_s_snp;

  wire                                     tnull_valid, s_tnull_valid;
  reg                                      r_tnull_valid;
  wire                                     tnull_last, s_tnull_last;
  reg                                      r_tnull_last;
  wire                                     tnull_last_null_writes, s_tnull_last_null_writes;
  reg                                      r_tnull_last_null_writes;

  // Demux ->
  wire                                     s_ready, s_dmx_ready, dmx_ready;
  wire [WR_NP_CTL_WD-1:0]                  s_np_ctl;
  wire [WR_NP_INFO_WD-1:0]                 s_np_info;
  wire [WR_P_CTL_WD-1:0]                   s_p_ctl;
  wire [WR_P_INFO_WD-1:0]                  s_p_info;
  wire [WR_NP_INTF_WD-1:0]                 s_np_intf;
  wire [WR_P_INTF_WD-1:0]                  s_p_intf;
  wire                                     s_np_wr;
  wire [WR_NP_CTL_WD-1:0]                  s_dmx_np_ctl;
  wire [WR_P_CTL_WD-1:0]                   s_dmx_p_ctl;
  wire [WR_NP_INFO_WD-1:0]                 s_dmx_np_info;
  wire [WR_P_INFO_WD-1:0]                  s_dmx_p_info;
  wire [WR_NP_INTF_WD-1:0]                 dmx_np_intf;
  wire [WR_P_INTF_WD-1:0]                  dmx_p_intf;

  // Parity error
  wire                                     lnull_addr_parerr;
  ras_dp_err_log_t                         addr_ad_ras_dp_err_log;
  wire                                     wwrp_addr_parerr;
  ras_dp_err_log_t                         wwrp_ad_ras_dp_err_log;

  wire [SLV_BUS_DATA_WIDTH-1:0]            i_swrq_p_data;
  wire [2:0]                               s_swrq_p_cpl_stat;
  wire [SLV_BUS_WREQ_NPDATA_WIDTH-1:0]     i_swrq_npw_data;

  wire                                     awatop_atomic_load_be;
  wire                                     awburst_atomic_cas_wrap;

  wire                                     s_swrq_npr_ur;

  wire                                     s_swrq_npw_valid;
  wire [SLV_BURST_LEN_PW-1:0]              s_swrq_npw_len;
  wire                                     s_srrq_npw_ready;

  // Req Splitter
  logic                                    reqSplitter_valid;
  logic [SLV_BUS_ADDR_WIDTH-1:0]           reqSplitter_addr;
  logic [2:0]                              reqSplitter_size;
  logic [SLV_BURST_LEN_PW -1:0]            reqSplitter_len;
  logic                                    reqSplitter_last;
  logic [SLV_BUS_DATA_WIDTH-1:0]           reqSplitter_data;
  logic [SLV_BUS_WSTRB_WIDTH-1:0]          reqSplitter_strb;
  logic [WR_MISC_INFO_WD-1:0]              reqSplitter_info;
  logic [SLV_BUS_WSTRB_WIDTH-1:0]          reqSplitter_wep_strb;
  logic [SLV_BUS_WSTRB_WIDTH-1:0]          reqSplitter_wsilentDrop_strb;
  logic [SLV_BUS_WSTRB_WIDTH-1:0]          reqSplitter_wsilentDrop_strb_masked;
  // Parity error
  logic                                    reqSplitter_first_wrp_split_xact;
  logic                                    reqSplitter_wrp_valid;
  logic                                    reqSplitter_ready;

  // -------------------------------------------------------------------------------------
  // Internal design
  // -------------------------------------------------------------------------------------

  // Endianess of an Atomic Load request
  assign awatop_atomic_load_be   = (awatop == `AXI_ATOP_LOAD_BE) ? 1'b1 : 1'b0;

  // Atomic CAS WRAP
  assign awburst_atomic_cas_wrap = (awatop == `AXI_ATOP_CAS) && (awburst == `WRAP);

  // -------------------------------------------------------------------------------------
  // Enhanced Configuration Address Mapping (ECAM)
  // -------------------------------------------------------------------------------------
  assign awmisc_info_cpl_stat = `SU_CPL_STATUS;

  // -------------------------------------------------------------------------------------
  // Instantiate pipeline stages
  // Write address channel
  // Pack
  assign s_aw_intf = {
    awvalid
  , awid
  , awaddr
  , awlen
  , awsize
  , awburst
  , awmisc_info_type
  , awmisc_info_snp
  , awmisc_info_ep
  , awmisc_info_ns
  , awmisc_info_ro
  , awmisc_info_tc
  , awmisc_info_msg_code
  , awmisc_info_db
  , awmisc_info_func_num
  , awmisc_info_nw
  , awmisc_info_ats
  , awmisc_info_tlpprfx
  , awmisc_info_p_tag
  , awmisc_info_tph
  , awmisc_info_atu_bypass
  , awmisc_info_dst_segment
  , awmisc_info_ido
  , awmisc_info_cpl_stat
  , awatop_atomic_load_be
  , awburst_atomic_cas_wrap
  };

  assign awready = !pdly1_halt;

  // Insert pipeline delay
  delay_1_w_stalling
  
  #(.DELAY_EN                              (1)
   ,.WD                                    (AW_INTF_WIDTH)
   ,.CAN_STALL                             (1)
   ,.RESET_STALL                           (1)
  )
  u_pdly1
  (
    .clk        (slv_aclk),
    .rst_n      (slv_aresetn),
    .clear      (1'b0),
    .din        (s_aw_intf),
    .stallout   (pdly1_halt),
    .dout       (pdly1_aw_intf),
    .stall      (s_wif_aw_halt)
  );

  // Halt pipeline
  assign s_wif_aw_halt = pdly1_awvalid && !wif_awready;

  // Unpack interface signals
  assign { pdly1_awvalid
         , pdly1_awid
         , pdly1_awaddr
         , pdly1_awlen
         , pdly1_awsize
         , pdly1_awburst
         , pdly1_awmisc_info_type
         , pdly1_awmisc_info_snp
         , pdly1_awmisc_info_ep
         , pdly1_awmisc_info_ns
         , pdly1_awmisc_info_ro
         , pdly1_awmisc_info_tc
         , pdly1_awmisc_info_msg_code
         , pdly1_awmisc_info_db
         , pdly1_awmisc_info_func_num
         , pdly1_awmisc_info_nw
         , pdly1_awmisc_info_ats
         , pdly1_awmisc_info_tlpprfx
         , pdly1_awmisc_info_p_tag
         , pdly1_awmisc_info_tph
         , pdly1_awmisc_info_atu_bypass
         , pdly1_awmisc_info_dst_segment
         , pdly1_awmisc_info_ido
         , pdly1_awmisc_info_cpl_stat
         , pdly1_awatop_atomic_load_be
         , pdly1_awburst_atomic_cas_wrap
         } = pdly1_aw_intf;

  // -------------------------------------------------------------------------------------
  // Write data channel
  // Pack
  assign s_w_intf = {
    wvalid
  , wid
  , wdata
  , wstrb
  , wlast
  , wmisc_info_ep
  , wmisc_info_silentDrop
  };

  assign wready = !pdly2_halt;

  // Insert pipeline delay
  delay_1_w_stalling
  
  #(.DELAY_EN                              (1)
   ,.WD                                    (W_INTF_WIDTH)
   ,.CAN_STALL                             (1)
   ,.RESET_STALL                           (1)
  )
  u_pdly2
  (
    .clk        (slv_aclk),
    .rst_n      (slv_aresetn),
    .clear      (1'b0),
    .din        (s_w_intf),
    .stallout   (pdly2_halt),
    .dout       (pdly2_w_intf),
    .stall      (s_wif_w_halt)
  );

  // Halt pipeline
  assign s_wif_w_halt = pdly2_wvalid && !wif_wready;

  // Unpack
  assign { pdly2_wvalid
         , pdly2_wid
         , pdly2_wdata
         , pdly2_wstrb
         , pdly2_wlast
         , pdly2_wmisc_info_ep
         , pdly2_wmisc_info_silentDrop
         } = pdly2_w_intf;

  // -------------------------------------------------------------------------------------
  // Align control and data channels
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_slv_wreq_if
  
  #(.SLV_BUS_ID_WIDTH                     (SLV_BUS_ID_WIDTH)
   ,.SLV_BUS_ADDR_WIDTH                   (SLV_BUS_ADDR_WIDTH)
   ,.SLV_BURST_LEN_PW                     (SLV_BURST_LEN_PW)
   ,.SLV_BUS_DATA_WIDTH                   (SLV_BUS_DATA_WIDTH)
   ,.SLV_BUS_WSTRB_WIDTH                  (SLV_BUS_WSTRB_WIDTH)
   ,.NFUNC_WD                             (NFUNC_WD)
   ,.MISC_INFO_TPH_WD                     (MISC_INFO_TPH_WD)
   ,.TX_TLP_PREFIX_WD                     (TX_TLP_PREFIX_WD)
   ,.WR_MISC_INFO_WD                      (WR_MISC_INFO_WD)
   )
   u_wif
   (.slv_aclk                           (slv_aclk)
   ,.slv_aresetn                        (slv_aresetn)
  // -------------------------------------------------------------------------------------
  // Write Address Channel
   ,.awvalid                            (pdly1_awvalid)
   ,.awid                               (pdly1_awid)
   ,.awaddr                             (pdly1_awaddr)
   ,.awlen                              (pdly1_awlen)
   ,.awsize                             (pdly1_awsize)
   ,.awburst                            (pdly1_awburst)
   ,.awmisc_info_type                   (pdly1_awmisc_info_type)
   ,.awmisc_info_snp                    (pdly1_awmisc_info_snp)
   ,.awmisc_info_ep                     (pdly1_awmisc_info_ep)
   ,.awmisc_info_ns                     (pdly1_awmisc_info_ns)
   ,.awmisc_info_ro                     (pdly1_awmisc_info_ro)
   ,.awmisc_info_tc                     (pdly1_awmisc_info_tc)
   ,.awmisc_info_msg_code               (pdly1_awmisc_info_msg_code)
   ,.awmisc_info_db                     (pdly1_awmisc_info_db)
   ,.awmisc_info_func_num               (pdly1_awmisc_info_func_num)
   ,.awmisc_info_nw                     (pdly1_awmisc_info_nw)
   ,.awmisc_info_ats                    (pdly1_awmisc_info_ats)
   ,.awmisc_info_tlpprfx                (pdly1_awmisc_info_tlpprfx)
   ,.awmisc_info_p_tag                  (pdly1_awmisc_info_p_tag)
   ,.awmisc_info_tph                    (pdly1_awmisc_info_tph)
   ,.awmisc_info_atu_bypass             (pdly1_awmisc_info_atu_bypass)
   ,.awmisc_info_dst_segment            (pdly1_awmisc_info_dst_segment)
   ,.awmisc_info_ido                    (pdly1_awmisc_info_ido)
   ,.awmisc_info_cpl_stat               (pdly1_awmisc_info_cpl_stat)
   ,.awatop_atomic_load_be              (pdly1_awatop_atomic_load_be)
   ,.awburst_atomic_cas_wrap            (pdly1_awburst_atomic_cas_wrap)
   ,.awready                            (wif_awready)
  // -------------------------------------------------------------------------------------
  // Write Data Channel
   ,.wvalid                             (pdly2_wvalid)
   ,.wdata                              (pdly2_wdata)
   ,.wstrb                              (pdly2_wstrb)
   ,.wlast                              (pdly2_wlast)
   ,.wmisc_info_ep                      (pdly2_wmisc_info_ep)
   ,.wmisc_info_silentDrop              (pdly2_wmisc_info_silentDrop)
   ,.wready                             (wif_wready)
  // -------------------------------------------------------------------------------------
  // Channel aligned write interface
   ,.wif_valid                          (wif_valid)
   ,.wif_addr                           (wif_addr)
   ,.wif_size                           (wif_size)
   ,.wif_len                            (wif_len)
   ,.wif_burst                          (wif_burst)
   ,.wif_last                           (wif_last)
   ,.wif_data                           (wif_data)
   ,.wif_strb                           (wif_strb)
   ,.wif_info                           (wif_info)
   ,.wif_wep_strb                       (wif_wep_strb)
   ,.wif_wsilentDrop_strb               (wif_wsilentDrop_strb)
   ,.wif_wsilentDrop_strb_masked        (wif_wsilentDrop_strb_masked)
   ,.dwalgn_ready                       (reqSplitter_ready) //dwalgn_ready)
   );

  // -------------------------------------------------------------------------------------
  // Wrap split
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_slv_wreq_wrp
  
  #(.SLV_BUS_ADDR_WIDTH                    (SLV_BUS_ADDR_WIDTH)
   ,.SLAVE_BUS_ADDR_WIDTH                  (SLAVE_BUS_ADDR_WIDTH)
   ,.CX_RAS_PROT_RANGE                     (CX_RAS_PROT_RANGE)
   ,.SLV_BUS_ID_WIDTH                      (SLV_BUS_ID_WIDTH)
   ,.SLV_BURST_LEN_PW                      (SLV_BURST_LEN_PW)
  )
  u_wwrp
  (.slv_aclk                               (slv_aclk)
  ,.slv_aresetn                            (slv_aresetn)
  // AXI Write interface
  ,.wif_valid                              (wif_valid)
  ,.wif_addr                               (wif_addr)
  ,.wif_len                                (wif_len)
  ,.wif_size                               (wif_size)
  ,.wif_burst                              (wif_burst)
  ,.wif_last                               (wif_last)
  ,.wwrp_addr_parerr                       (wwrp_addr_parerr)
  ,.wwrp_ad_ras_dp_err_log                 (wwrp_ad_ras_dp_err_log)
  ,.ras_dp_err_inj_slv_aclk                (ras_dp_err_inj_slv_aclk)
  // Wrap burst interface
  ,.wwrp_addr                              (wwrp_addr)
  ,.wwrp_len                               (wwrp_len)
  ,.wwrp_last                              (wwrp_last)
  ,.wwrp_first_wrp_split_xact              (wwrp_first_wrp_split_xact)
  ,.wwrp_valid                             (wwrp_valid)
  ,.dwalgn_ready                           (reqSplitter_ready) //dwalgn_ready)
  );

  always_comb begin
    reqSplitter_addr = wwrp_addr;
    reqSplitter_len = wwrp_len;
    reqSplitter_last = wwrp_last;
    reqSplitter_valid = wif_valid;
    reqSplitter_size = wif_size;
    reqSplitter_data = wif_data;
    reqSplitter_strb = wif_strb;
    reqSplitter_info = wif_info;
    reqSplitter_wep_strb = wif_wep_strb;
    reqSplitter_wsilentDrop_strb = wif_wsilentDrop_strb;
    reqSplitter_wsilentDrop_strb_masked = wif_wsilentDrop_strb_masked;
    reqSplitter_first_wrp_split_xact = wwrp_first_wrp_split_xact;
    reqSplitter_wrp_valid = wwrp_valid;
    reqSplitter_ready = dwalgn_ready;
  end

  // -------------------------------------------------------------------------------------
  // Leading Null Control
  // Strip leading null beats, calculate aligned address, strip/check/add parity
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_slv_wreq_lnull
  
  #(.SLV_BUS_ADDR_WIDTH                (SLV_BUS_ADDR_WIDTH)
   ,.SLV_BUS_ID_WIDTH                  (SLV_BUS_ID_WIDTH)
   ,.SLAVE_BUS_ADDR_WIDTH              (SLAVE_BUS_ADDR_WIDTH)
   ,.SLV_BURST_LEN_PW                  (SLV_BURST_LEN_PW)
   ,.CX_RAS_PROT_RANGE                 (CX_RAS_PROT_RANGE)
   ,.SLV_BUS_WSTRB_WIDTH               (SLV_BUS_WSTRB_WIDTH)
   ,.SLV_BUS_WSTRB_PW                  (SLV_BUS_WSTRB_PW)
   ,.WR_MISC_INFO_WD                   (WR_MISC_INFO_WD)
   )
   u_lnull
   (.slv_aclk                          (slv_aclk)
   ,.slv_aresetn                       (slv_aresetn)
   // Aligned write interface
   ,.wif_valid                         (reqSplitter_valid) //wif_valid)
   ,.wif_size                          (reqSplitter_size) //wif_size)
//`ifdef CC_SLV_WRAP_ENABLE
//   ,.wif_addr                          (wwrp_addr)
//   ,.wif_len                           (wwrp_len)
//   ,.wif_last                          (wwrp_last)
//`else
   ,.wif_addr                          (reqSplitter_addr) //wif_addr)
   ,.wif_len                           (reqSplitter_len) //wif_len)
   ,.wif_last                          (reqSplitter_last) //wif_last)
//`endif
   ,.wif_strb                          (reqSplitter_strb) //wif_strb)
   ,.wif_info                          (reqSplitter_info) //wif_info)
   ,.wwrp_first_wrp_split_xact         (reqSplitter_first_wrp_split_xact) //wwrp_first_wrp_split_xact)
   ,.wwrp_valid                        (reqSplitter_wrp_valid) //wwrp_valid)
   // Parity error interface
   ,.lnull_addr_parerr                 (lnull_addr_parerr)
   ,.addr_ad_ras_dp_err_log            (addr_ad_ras_dp_err_log)
   ,.ras_dp_err_inj_slv_aclk           (ras_dp_err_inj_slv_aclk)
   // Leading null write interface
   ,.lnull_valid                       (lnull_valid) // to u_dwalgn
   ,.lnull_addr                        (lnull_addr)
   ,.lnull_addr_wo_par                 (lnull_addr_wo_par)
   ,.lnull_len                         (lnull_len)
   ,.lnull_size                        (lnull_size)
   ,.lnull_info                        (lnull_info)
   ,.lnull_first_wrp_split_xact        (lnull_first_wrp_split_xact)
   ,.lnull_wrp_valid                   (lnull_wrp_valid)
   ,.dwalgn_ready                      (dwalgn_ready)
   );

  assign swrq_addr_parerr = lnull_addr_parerr;
    assign swrq_ad_ras_dp_err_log = addr_ad_ras_dp_err_log;
  assign swrq_ras_par_swwrap_ad_pulse = wwrp_addr_parerr;
  assign swrq_swwrap_ad_ras_dp_err_log = wwrp_ad_ras_dp_err_log;

   wire                                    wif_data_chk_en;
   assign wif_data_chk_en = wif_valid & reqSplitter_ready ; //dwalgn_ready;

  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                              ),
    .RESETVAL                  (0                              ),
    .N_STAGES                  (0                              ),
    .CAN_STALL                 (0                              ),
    .RESET_STALL               (0                              ),
    .BUS_PROTECT_GEN_EN        (0                              ),
    .BUS_PROTECT_CHK_EN        (1                              ),
    .PROT_TYPE                 (1                              ),
    .PROT_RANGE                (CX_RAS_PROT_RANGE              ),
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS            ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE             ),
    .PROT_CORRECT_EN           (0                              ),
    .TOTAL_WIDTH               (SLAVE_BUS_DATA_WIDTH           ),
    .EXCLUDE_PROT_WIDTH        (0                              ),
    .RAS_DP_PROT_CHK_ID_BASE   (`SWRQ_SRWRAP_DT_RAS_ID         )
  ) u_wif_data_chk (
    .clk                       ( slv_aclk                      ),
    .rst_n                     ( slv_aresetn                   ),
    .din                       ( fn_data_wo_par (wif_data)     ),
    .din_prot                  ( fn_prot_chkin_dt(wif_data)    ),
    .dout                      ( /* Not Connected */           ),
    .dout_prot                 ( /* Not Connected */           ),
    .en                        (1'b1                           ),
    .bypass                    (1'b0                           ),
    .stall                     (1'b0                           ),
    .stallout                  ( /* Not Connected */           ),
    .valid_in                  ( wif_data_chk_en               ),
    .halt_out                  ( /* Not Connected */           ),
    .valid_out                 ( /* Not Connected */           ),
    .halt_in                   (1'b0                           ),
    .ras_dp_err_inband_kbd_in  (1'b0                           ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */           ),
    .ras_dp_err_log            ( swrq_swwrap_dt_ras_dp_err_log )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk)
    );

   assign swrq_ras_par_swwrap_dt_pulse = swrq_swwrap_dt_ras_dp_err_log.valid;
// Detectecting parity on the data

   wire                                    dalgn_data_chk_en;
   assign dalgn_data_chk_en = s_tnull_valid & dmx_ready;
   ras_dp_pipe
    #(
    .PIPELINE_TYPE             (0                              ),
    .RESETVAL                  (0                              ),
    .N_STAGES                  (0                              ),
    .CAN_STALL                 (0                              ),
    .RESET_STALL               (0                              ),
    .BUS_PROTECT_GEN_EN        (0                              ),
    .BUS_PROTECT_CHK_EN        (1                              ),
    .PROT_TYPE                 (1                              ),
    .PROT_RANGE                (CX_RAS_PROT_RANGE              ),
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS            ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE             ),
    .PROT_CORRECT_EN           (0                              ),
    .TOTAL_WIDTH               (SLAVE_BUS_DATA_WIDTH           ),
    .EXCLUDE_PROT_WIDTH        (0                              ),
    .RAS_DP_PROT_CHK_ID_BASE   (`SWRQ_DT_RAS_ID                )
  ) u_data_chk (
    .clk                       ( slv_aclk                      ),
    .rst_n                     ( slv_aresetn                   ),
    .din                       ( fn_data_wo_par (s_dwalgn_data)),
    .din_prot                  (fn_prot_chkin_dt(s_dwalgn_data)),
    .dout                      ( /* Not Connected */           ),
    .dout_prot                 ( /* Not Connected */           ),
    .en                        (1'b1                           ),
    .bypass                    (1'b0                           ),
    .stall                     (1'b0                           ),
    .stallout                  ( /* Not Connected */           ),
    .valid_in                  ( dalgn_data_chk_en             ),
    .halt_out                  ( /* Not Connected */           ),
    .valid_out                 ( /* Not Connected */           ),
    .halt_in                   (1'b0                           ),
    .ras_dp_err_inband_kbd_in  (1'b0                           ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */           ),
    .ras_dp_err_log            ( swrq_dt_ras_dp_err_log        )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk)
    );

   assign swrq_data_parerr = swrq_dt_ras_dp_err_log.valid;

  // Unpack write misc info
  assign { lnull_id
         , lnull_type
         , lnull_snp
         , lnull_ep
         , lnull_ns
         , lnull_ro
         , lnull_tc
         , lnull_msg_code
         , lnull_db
         , lnull_db_vldrq
         , lnull_func_num
         , lnull_nw
         , lnull_ats
         , lnull_tlpprfx
         , lnull_awmisc_info_p_tag
         , lnull_tph
         , lnull_atu_bypass
         , lnull_dst_segment
         , lnull_ido
         , lnull_cpl_stat
         , lnull_atomic_load_be
         , lnull_atomic_cas_wrap
        } = lnull_info;

  // -------------------------------------------------------------------------------------
  // Write data width alignment
  // -------------------------------------------------------------------------------------
  DWC_pcie_bridge_dalign
  
  #(SLV_BUS_DATA_WIDTH
   ,SLV_BUS_WSTRB_WIDTH
   ,SLV_BUS_WSTRB_PW
   )
   u_dwalgn
   (
   .clk                             (slv_aclk),
   .rst_n                           (slv_aresetn),
   .init_n                          (1'b1),
  // AXI write interface
   .data_vld_in                     (lnull_valid),
   .data_size_in                    (reqSplitter_size), //wif_size),
//`ifdef CC_SLV_WRAP_ENABLE
//   .data_last_in                    (wwrp_last),
//`else
   .data_last_in                    (reqSplitter_last), //wif_last),
//`endif
   .data_strb_in                    (reqSplitter_strb), //wif_strb),
   .data_in                         (reqSplitter_data), //wif_data),
   .data_rdy_out                    (dwalgn_ready),
   .data_wep_strb_in                (reqSplitter_wep_strb), //wif_wep_strb),
   .data_wsilentDrop_strb_in        (reqSplitter_wsilentDrop_strb), //wif_wsilentDrop_strb),
   .data_wsilentDrop_strb_in_masked (reqSplitter_wsilentDrop_strb_masked), //wif_wsilentDrop_strb_masked),
  // Data width aligned data interface
   .data_vld_out                    (dwalgn_valid),
   .data_last_out                   (dwalgn_last),
   .data_strb_out                   (dwalgn_strb),
   .data_out                        (dwalgn_data),
   .data_wep_strb_out               (dwalgn_ep_strb),
   .data_wsilentDrop_strb_out       (dwalgn_silentDrop_strb),
   .data_wsilentDrop_strb_out_masked(dwalgn_silentDrop_strb_masked),
   .data_rdy_in                     (s_ready)
   );

  // Generate internal ready signal
  assign s_ready = s_dmx_ready || !dwalgn_valid;

  // -------------------------------------------------------------------------------------
  // Instantiate ATU translation logic
  // Translate type and function number
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_slv_atu
  
  #(.ATU_OUT_REGIONS                  (ATU_OUT_REGIONS)
   ,.ATU_BASE_WD                      (ATU_BASE_WD)
   ,.ATU_REG_WD                       (ATU_REG_WD)
   ,.ATU_OUT_MIN1                     (ATU_OUT_MIN1)
   ,.ATU_UPR_LMT_WD                   (ATU_UPR_LMT_WD)
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
  ,.atu_write                        (1'b1)
  ,.atu_bypass                       (lnull_atu_bypass)
  ,.type_info                        (lnull_type)
  ,.func_num                         (lnull_func_num)
  ,.snp                              (lnull_snp)
  ,.addr                             (lnull_addr_wo_par)
  // Translation interface
  ,.satu_type                        (s_type)
  ,.satu_func_num                    (s_func_num)
  ,.satu_snp                         (s_snp)
  );

  // -------------------------------------------------------------------------------------
  // Instantiate traling null control block
  // Trailing null defined as a packed data width aligned beat which is not the last
  // beat but contains trailing null bytes.
  // Terminate transter early when first trailing null detected
  // Actually number of bytes transfered and calculated by formation layer
  // and sent to the decomposer on the last beat.
  // -------------------------------------------------------------------------------------
  DWC_pcie_axi_slv_wreq_tnull
  
 #(.SLV_BUS_WSTRB_WIDTH               (SLV_BUS_WSTRB_WIDTH)
  )
  u_tnull
  (.slv_aclk                          (slv_aclk)
  ,.slv_aresetn                       (slv_aresetn)
  // Data width Aligned write interface
  ,.dwalgn_valid                      (dwalgn_valid)
  ,.dwalgn_last                       (dwalgn_last)
  ,.dwalgn_strb                       (dwalgn_strb)
  ,.lnull_size                        (lnull_size)
  // Trailing null control interface
  ,.tnull_valid                       (tnull_valid)
  ,.tnull_last                        (tnull_last)
  ,.tnull_last_null_writes            (tnull_last_null_writes)
  ,.ready                             (s_dmx_ready)
  );


// -------------------------------------------------------------------------------------
// Retime control/data/info signals (ATU SLV PIPELINE)
// -------------------------------------------------------------------------------------
always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_wr_ch_intf_dly
  if (!slv_aresetn) begin
    r_tnull_valid                   <= # TP 1'b0;
    r_lnull_len                     <= # TP {SLV_BURST_LEN_PW{1'b0}};
    r_lnull_size                    <= # TP 3'b0;
    r_lnull_addr                    <= # TP {SLV_BUS_ADDR_WIDTH{1'b0}};
    r_dwalgn_data                   <= # TP {SLV_BUS_DATA_WIDTH{1'b0}};
    r_dwalgn_strb                   <= # TP {SLV_BUS_WSTRB_WIDTH{1'b0}};
    r_dwalgn_ep_strb                <= # TP {SLV_BUS_WSTRB_WIDTH{1'b0}};
    r_dwalgn_silentDrop_strb        <= # TP {SLV_BUS_WSTRB_WIDTH{1'b0}};
    r_dwalgn_silentDrop_strb_masked <= # TP {SLV_BUS_WSTRB_WIDTH{1'b0}};
    r_tnull_last                    <= # TP 1'b0;
    r_tnull_last_null_writes        <= # TP 1'b0;
    r_lnull_first_wrp_split_xact    <= # TP 1'b0;
    r_lnull_wrp_valid               <= # TP 1'b0;
    r_lnull_id                      <= # TP {SLV_BUS_ID_WIDTH{1'b0}};
    r_s_type                        <= # TP 5'b0;
    r_s_snp                         <= # TP 1'b0;
    r_lnull_ep                      <= # TP 1'b0;
    r_lnull_ns                      <= # TP 1'b0;
    r_lnull_ro                      <= # TP 1'b0;
    r_lnull_tc                      <= # TP 3'b0;
    r_lnull_msg_code                <= # TP 8'b0;
    r_lnull_db                      <= # TP 1'b0;
    r_lnull_db_vldrq                <= # TP 1'b0;
    r_s_func_num                    <= # TP {NFUNC_WD{1'b0}};
    r_lnull_nw                      <= # TP 1'b0;
    r_lnull_ats                     <= # TP 2'b0;
    r_lnull_tlpprfx                 <= # TP {TX_TLP_PREFIX_WD{1'b0}};
    r_lnull_awmisc_info_p_tag       <= # TP {CX_TAG_SIZE{1'b0}};
    r_lnull_tph                     <= # TP {MISC_INFO_TPH_WD{1'b0}};
    r_lnull_atu_bypass              <= # TP 1'b0;
    r_lnull_dst_segment             <= # TP 9'h000;
    r_lnull_ido                     <= # TP 1'b0;
    r_lnull_atomic_load_be          <= # TP 1'b0;
    r_lnull_atomic_cas_wrap         <= # TP 1'b0;

    r_lnull_cpl_stat                <= # TP 3'b0;
  end else if (s_dmx_ready) begin
    r_tnull_valid                   <= # TP tnull_valid;
    r_lnull_len                     <= # TP lnull_len;
    r_lnull_size                    <= # TP lnull_size;
    r_lnull_addr                    <= # TP lnull_addr;
    r_dwalgn_data                   <= # TP dwalgn_data;
    r_dwalgn_strb                   <= # TP dwalgn_strb;
    r_dwalgn_ep_strb                <= # TP dwalgn_ep_strb;
    r_dwalgn_silentDrop_strb        <= # TP dwalgn_silentDrop_strb;
    r_dwalgn_silentDrop_strb_masked <= # TP dwalgn_silentDrop_strb_masked;
    r_tnull_last                    <= # TP tnull_last;
    r_tnull_last_null_writes        <= # TP tnull_last_null_writes;
    r_lnull_first_wrp_split_xact    <= # TP lnull_first_wrp_split_xact;
    r_lnull_wrp_valid               <= # TP lnull_wrp_valid;
    r_lnull_id                      <= # TP lnull_id;
    r_s_type                        <= # TP s_type;
    r_s_snp                         <= # TP s_snp;
    r_lnull_ep                      <= # TP lnull_ep;
    r_lnull_ns                      <= # TP lnull_ns;
    r_lnull_ro                      <= # TP lnull_ro;
    r_lnull_tc                      <= # TP lnull_tc;
    r_lnull_msg_code                <= # TP lnull_msg_code;
    r_lnull_db                      <= # TP lnull_db;
    r_lnull_db_vldrq                <= # TP lnull_db_vldrq;
    r_s_func_num                    <= # TP s_func_num;
    r_lnull_nw                      <= # TP lnull_nw;
    r_lnull_ats                     <= # TP lnull_ats;
    r_lnull_tlpprfx                 <= # TP lnull_tlpprfx;
    r_lnull_awmisc_info_p_tag       <= # TP lnull_awmisc_info_p_tag;
    r_lnull_tph                     <= # TP lnull_tph;
    r_lnull_atu_bypass              <= # TP lnull_atu_bypass;
    r_lnull_dst_segment             <= # TP lnull_dst_segment;
    r_lnull_ido                     <= # TP lnull_ido;
    r_lnull_atomic_load_be          <= # TP lnull_atomic_load_be;
    r_lnull_atomic_cas_wrap         <= # TP lnull_atomic_cas_wrap;
    r_lnull_cpl_stat                <= # TP lnull_cpl_stat;
  end // if(s_dmx_ready)
end // always

assign s_dmx_ready                     = !r_tnull_valid || dmx_ready;
assign s_tnull_valid                   = r_tnull_valid;
assign s_lnull_len                     = r_lnull_len;
assign s_lnull_size                    = r_lnull_size;
assign s_lnull_addr                    = r_lnull_addr;
assign s_dwalgn_data                   = r_dwalgn_data;
assign s_dwalgn_strb                   = r_dwalgn_strb;
assign s_dwalgn_ep_strb                = r_dwalgn_ep_strb;
assign s_dwalgn_silentDrop_strb        = r_dwalgn_silentDrop_strb;
assign s_dwalgn_silentDrop_strb_masked = r_dwalgn_silentDrop_strb_masked;
assign s_tnull_last                    = r_tnull_last;
assign s_tnull_last_null_writes        = r_tnull_last_null_writes;
assign s_lnull_first_wrp_split_xact    = r_lnull_first_wrp_split_xact;
assign s_lnull_wrp_valid               = r_lnull_wrp_valid;
assign s_lnull_id                      = r_lnull_id;
assign s_s_type                        = r_s_type;
assign s_s_snp                         = r_s_snp;
assign s_lnull_ep                      = r_lnull_ep;
assign s_lnull_ns                      = r_lnull_ns;
assign s_lnull_ro                      = r_lnull_ro;
assign s_lnull_tc                      = r_lnull_tc;
assign s_lnull_msg_code                = r_lnull_msg_code;
assign s_lnull_db                      = r_lnull_db;
assign s_lnull_db_vldrq                = r_lnull_db_vldrq;
assign s_s_func_num                    = r_s_func_num;
assign s_lnull_nw                      = r_lnull_nw;
assign s_lnull_ats                     = r_lnull_ats;
assign s_lnull_tlpprfx                 = r_lnull_tlpprfx;
assign s_lnull_awmisc_info_p_tag       = r_lnull_awmisc_info_p_tag;
assign s_lnull_tph                     = r_lnull_tph;
assign s_lnull_atu_bypass              = r_lnull_atu_bypass;
assign s_lnull_dst_segment             = r_lnull_dst_segment;
assign s_lnull_ido                     = r_lnull_ido;
 assign s_lnull_atomic_load_be          = r_lnull_atomic_load_be;
 assign s_lnull_atomic_cas_wrap         = r_lnull_atomic_cas_wrap;
assign s_lnull_cpl_stat                = r_lnull_cpl_stat;



  // -------------------------------------------------------------------------------------
  // Demux posted and non-posted writes
  // -------------------------------------------------------------------------------------
  // Pack non-posted control and data
  assign s_np_ctl = { s_tnull_valid
                    , s_lnull_len
                    , s_lnull_size
                    , s_lnull_addr
                    , s_dwalgn_data[SLV_BUS_WREQ_NPDATA_WIDTH-1:0]
                    , s_dwalgn_strb[SLV_BUS_WREQ_NPWSTRB_WIDTH-1:0]
                    , s_tnull_last
                    };

  // Pack Non-Posted info
  // tc must be 0; th & ido are not applicable; ats must be 0; ns,ro must be 0
  // {id,type,snp,ep,tc,db,db_vldrq,ecam_db,func_num,vfunc_num,vfunc_active,tlp_prfx,tph,atu_bypass,dst_segment,nse}
  assign s_np_info = { s_lnull_id , s_s_type , s_s_snp, (s_lnull_ep || (|s_dwalgn_ep_strb[SLV_BUS_WREQ_NPWSTRB_WIDTH-1:0])), s_lnull_tc
                     , s_lnull_atomic_load_be
                     , s_lnull_atomic_cas_wrap
                     , s_lnull_ns
                     , s_lnull_ro
                     , s_lnull_nw
                     , s_lnull_ats
                     , s_lnull_tph
                     , s_lnull_first_wrp_split_xact
                     , s_lnull_wrp_valid
                     , s_lnull_db
                     , s_lnull_db_vldrq
                     , s_s_func_num
                     , s_lnull_tlpprfx
                     , s_lnull_atu_bypass
                     , s_lnull_dst_segment
                     , s_lnull_ido
                     };

  // -------------------------------------------------------------------------------------
  // Pack non-posted control and data
  assign s_p_ctl = { s_tnull_valid
                   , s_lnull_len
                   , s_lnull_size
                   , s_lnull_addr
                   , s_dwalgn_data
                   , s_dwalgn_strb
                   , s_dwalgn_ep_strb
                   , s_dwalgn_silentDrop_strb
                   , s_dwalgn_silentDrop_strb_masked
                   , s_tnull_last
                   };

  // Pack posted info
  // {id,type,ep,ns,ro,tc,msg_code,func_num,nw,ats,vfunc_num,vfunc_active,
  // tlp_prfx,tlp_ln, itag, tph,atu_bypass,dst_segment,ido,nse}
  assign s_p_info = { s_lnull_id , s_s_type , s_lnull_ep , s_lnull_ns , s_lnull_ro , s_lnull_tc
                    , s_lnull_msg_code , s_s_func_num
                    , s_lnull_nw , s_lnull_ats
                    , s_lnull_tlpprfx
                    , s_lnull_awmisc_info_p_tag
                    , s_lnull_tph
                    , s_lnull_atu_bypass
                    , s_lnull_dst_segment
                    , s_lnull_ido
                    , s_lnull_cpl_stat
                    , s_lnull_first_wrp_split_xact
                    , s_lnull_wrp_valid
                    };

  // Build control/data and info buses
  assign s_np_intf = { s_np_ctl, s_np_info };
  assign s_p_intf  = { s_p_ctl, s_p_info };

  // -------------------------------------------------------------------------------------
  // Detect non-posted write transfer
  assign s_np_wr =    (s_s_type==IO_TYPE)
                   || (s_s_type==CFG0_TYPE)
                   || (s_s_type==CFG1_TYPE)
                   || (s_s_type==DMWR_TYPE)
                   || s_lnull_db
                   || (s_s_type==ATOP_FETCH_ADD)
                   || (s_s_type==ATOP_SWAP)
                   || (s_s_type==ATOP_CAS)
                   ;

  // -------------------------------------------------------------------------------------
  // Instantiate interface demux block
  DWC_pcie_bridge_intf_demux
  
  #(.INTF_WD_A                             (WR_NP_INTF_WD)
   ,.INTF_WD_B                             (WR_P_INTF_WD)
  )
  u_dmx
  (
  // Serial interface
  .intf_a                                  (s_np_intf)
  ,.intf_b                                 (s_p_intf)
  ,.dmx_ready                              (dmx_ready)
  // Interface A (Non-Posted request)
  ,.sel_a                                  (s_np_wr)
  ,.dmx_intf_a                             (dmx_np_intf)
  ,.ready_a                                (s_srrq_npw_ready)
  // Interface B (Posted request)
  ,.dmx_intf_b                             (dmx_p_intf)
  ,.ready_b                                (prf_ready)
  );

  // Extract write control/data, info
  assign {s_dmx_np_ctl, s_dmx_np_info } = dmx_np_intf;
  assign {s_dmx_p_ctl, s_dmx_p_info }   = dmx_p_intf;

  // -------------------------------------------------------------------------------------
  // Non-Posted Write interface
  assign { s_swrq_npw_valid , s_swrq_npw_len , swrq_npw_size , swrq_npw_addr, i_swrq_npw_data
         , swrq_npw_strb , swrq_npw_last
         } = s_dmx_np_ctl;

  assign swrq_npw_data = swrq_npw_valid ? i_swrq_npw_data : {NP_NUM_PARITY_BYTES{BUS_INIT_BYTE}};

  assign { swrq_npw_id , swrq_npw_type , swrq_npw_snp, swrq_npw_ep , swrq_npw_tc
         , swrq_npw_atomic_load_be
         , swrq_npw_atomic_cas_wrap
         , swrq_npw_ns
         , swrq_npw_ro
         , swrq_npw_nw
         , swrq_npw_ats
         , swrq_npw_tph
         , swrq_npw_first_wrp_split_xact
         , swrq_npw_wrp_valid
         , swrq_npw_db
         , swrq_npw_db_vldrq
         , swrq_npw_func_num
         , swrq_npw_tlpprfx
         , swrq_npw_atu_bypass
         , swrq_npw_dst_segment
         , swrq_npw_ido
         } = s_dmx_np_info;

  wire [CC_SLV_MAX_BYTES_PW-1:0] cfg_dmwr_max_len;

  generate
  if(CC_SLV_MAX_BYTES_PW < 7) begin : gen_cfg_dmwr_max_len
    assign cfg_dmwr_max_len  = ( 1 << (CC_SLV_MAX_BYTES_PW-1) );
  end else if (CC_SLV_MAX_BYTES_PW == 7) begin
    assign cfg_dmwr_max_len  = 64;
  end else begin
    assign cfg_dmwr_max_len  = (`CX_DEF_MEM_WR_LEN_SUPP == 0) ? 64 : 128;
  end
  endgenerate

  // Detect invalid requests and reduce request to 1 beat when that happens
  assign s_swrq_npr_ur     = (swrq_npw_type == DMWR_TYPE) && ~cfg_dmwr_req_en ;

  assign swrq_npw_cpl_stat = !s_swrq_npr_ur ? `SU_CPL_STATUS   : `UR_CPL_STATUS ;
  assign swrq_npw_len      = !s_swrq_npr_ur ? s_swrq_npw_len   : 0 ;
  assign swrq_npw_valid    = !s_swrq_npr_ur ? s_swrq_npw_valid : s_swrq_npw_valid &&  swrq_npw_last;
  assign s_srrq_npw_ready  = !s_swrq_npr_ur ? srrq_npw_ready   :   srrq_npw_ready || !swrq_npw_last;


  // -------------------------------------------------------------------------------------
  // Posted Write interface
  assign { swrq_p_valid , swrq_p_len , swrq_p_size , swrq_p_addr, i_swrq_p_data
         , swrq_p_strb , swrq_p_ep_strb , swrq_p_silentDrop_strb , swrq_p_silentDrop_strb_masked , swrq_p_last
         } = s_dmx_p_ctl;

   assign swrq_p_data = swrq_p_valid ? i_swrq_p_data : {(SLAVE_BUS_DATA_WIDTH/8){BUS_INIT_BYTE}};

  assign { swrq_p_id , swrq_p_type , swrq_p_ep , swrq_p_ns , swrq_p_ro , swrq_p_tc
         , swrq_p_msg_code , swrq_p_func_num
         , swrq_p_nw , swrq_p_ats
         , swrq_p_tlpprfx
         , swrq_p_tag
         , swrq_p_tph
         , swrq_p_atu_bypass
         , swrq_p_dst_segment
         , swrq_p_ido
         , s_swrq_p_cpl_stat
         , swrq_p_first_wrp_split_xact
         , swrq_p_wrp_valid
         } = s_dmx_p_info;








always_comb
begin
       swrq_p_cpl_stat = s_swrq_p_cpl_stat ;
end  

  // -------------------------------------------------------------------------------------
  // Write Request Info Interface
  // -------------------------------------------------------------------------------------
  assign swrq_wr_valid_hl         = s_tnull_last && 
                                    !(swrq_p_first_wrp_split_xact && swrq_p_valid) &&
                                    !(swrq_npw_first_wrp_split_xact && swrq_npw_valid) &&
                                    dmx_ready;

  assign swrq_wr_id               = s_lnull_id;
  assign swrq_wr_p                = swrq_p_valid;


  assign swrq_wr_np               = swrq_npw_valid && !swrq_wr_np_atomic; // Wire or DB (SHARED_DBI) requests
  assign swrq_wr_np_atomic        = swrq_npw_valid && ((swrq_npw_type==`ATOP_FETCH_ADD) || (swrq_npw_type==`ATOP_SWAP) || (swrq_npw_type==`ATOP_CAS));

  assign swrq_wr_last_null_writes = s_tnull_last_null_writes/* && ((swrq_p_valid && s_tnull_lastReq) || !swrq_p_valid)*/;

 // -------------------------------------------------------------------------------------
 // Functions
 // -------------------------------------------------------------------------------------
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
  function automatic [NUM_ADDR_PAR_BLOCKS-1:0] fn_prot_chkin_ad;
    input [SLV_BUS_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_ad[i] = s_addr_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction

  function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_dt;
    input [SLV_BUS_DATA_WIDTH-1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_dt[i] = s_data_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction

  function automatic [SLV_BUS_DATA_WIDTH-NUM_DATA_PAR_BLOCKS-1:0] fn_data_wo_par;
    input [SLV_BUS_DATA_WIDTH-1:0] s_data_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_data_wo_par[i*CX_RAS_PROT_RANGE +j] = s_data_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction




`ifndef SYNTHESIS
`endif
endmodule
