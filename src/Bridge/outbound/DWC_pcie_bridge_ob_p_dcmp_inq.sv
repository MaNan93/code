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
// ---    $Revision: #20 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_bridge_ob_p_dcmp_inq.sv#20 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// This module contains the state machine that controls the writing into the
// queue for the decomposer.
// It also decomposes a TLP into multiple TLPs under the following conditions:
// 1. When a MemRd request is bigger than the max read request size
// 2. When a MemWr or CplD is bigger than the max payload size
// 3. When a MemRd or MemWr crosses 4k address boundary
//    *** The boundary address is a parameter that can be modified
//    *** There's an added requirement that boundary address >= max payload size
//    *** And: boundary address >= max read request size
// 4. When a completion needs to be split, it would be split at RCB boundary
//    The enforcement of this rule is automatic by how the TLPs are split.
//
// The TLP is split along max payload size (for MemWr & Cpld) boundaries or
// along max read request size (for MemRd) boundaries.  Since integer multiples
// of the max payload/read request size is 4K, the 4K address boundary rule
// is automatically satisfied when a TLP is split because of the first 2 reasons.
// If a TLP is not bigger than max payload size or max read request size, then
// a check must be done to ensure it doesn't cross 4k address boundary.  The
// TLP will be split at the 4k address boundary if it does cross it.
// Again, since RCB boundary is either 64byte or 128byte, this rule is
// is automatically satisfiied when a CplD needs to be split.
// *NOTE* The above description changes as the parameter PAGE_BOUNDARY_BIT change
// *NOTE* please see below for description of this parameter.
// *NOTE* As long as assumption #4 is satisfied, description is still valid.
//
// Furthermore, it also does some other functions:
// 1. When bus master enable is 0, no read or write request can be sent out
// 2. When there are no available tags available, no request can go out
//
// Assumptions:
// 1. Application would send full completions and not split ones or if they
//    already split it, it would be split to less than max payload size.
// 2. Global address align enable is always set ------ NOT TRUE ANYMORE
// 3. Only support input core datawidth.
// 4. PAGE_BOUNDARY_BIT >= log2(max payload size) + 1
//When Global address align = 0:
// 5. Input byte_len is actual byte + low addr offset
//When Global address align = 1:
// 5. Input byte_len is actual byte length
// 6. Input address is either, this module will NOT look at [1:0].
//
// This inQ manager manages both the header and data queue.  When enough data
// is received to send a TLP, a header is written at the same time as the last
// data entry.  This will signal the outQ manager to start reading out of the
// queue.
//
// Parameter guide:
// NO_SWAP_TAG - By default, this parameter is 0 which means that the new TLP
//              going out will use the tag provided by the tag manager.
//              When this parameter is set to 1, the incoming tag will be used
//              as the outgoing tag.
// PKT_LEN_MOD - By default, this parameter is set to 1 which means that the
//              incoming packet header's length field can change during EOT
//              and this new value is the actual length of the packet.  This is
//              required for interfacing with applications that are running in
//              bus cycle mode, so it wouldn't know the actual length of the
//              packet until at the end of the packet.
//              When this parameter is set to 0, the valid TLP length is during
//              _hv at the beginning of the packet.  Don't update during EOT
//              because the value might change to something that's not correct.
// PAGE_BOUNDARY_BIT - By default, this parameter is set to 13 which means that
//              this module will split TLP that crosses 4K address boundary.
//              Valid range for this parameter is 8 (128byte) to 13 (4Kbyte).
//
//
//  The major funcions:
//  This module converts a core TRGT1 interface to GIF interface of a master AMBA
//  1. a FIFO for data and header of a memrd/wr transaction that core receive to provide
//     a non-blocking architecture between core and one AMBA master. Other Master can get traffic through
//  2. This FIFO also does the clock domain crossing between AMBA clock and core clk.
//     Only core clk runs less than AMBA clock is supported
//  3. GIF interface control as a master is done in this block. A memRd/Wr received
//     by core will be translated into GIF master trnasaction to output to DWC GIF master module
//  4. Pipelined request transactions and response transactions are supported as long
//     as inorder services is maintain.  No AMBA out of order services are supported
//  5. A FIFO for header information of a memRd is designed in the block to handle
//     completion type of request generated to core
//
//  Limitations:
//  1. only dword aligned address is supported
//  2. Each read/write received by core will be within one burst of the AMBA transfer
//  3. Only support core data path width and AMBA data path width to be the same
//     --- UPDATED: Now supports different datapath width size
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

 module DWC_pcie_bridge_ob_p_dcmp_inq
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 (

    slv_aclk,
    slv_aresetn,

    // Configuration interface
    cfg_max_payload_size,

    // Request packet interface
    inq_pkt_halt,
    req_pkt_hv,
    req_pkt_dv,
    req_pkt_eot,
    req_pkt_prfx,
    req_pkt_p_tag,
    req_pkt_th,
    req_pkt_ph,
    req_pkt_st,
    req_pkt_atu_bypass,
    req_pkt_dst_segment,
    req_pkt_ats,
    req_pkt_nw,
    req_pkt_first_wrp_split_xact,
    req_pkt_wrp_valid,
    req_pkt_axi_id,
    req_pkt_cpl_stat,
    req_pkt_byte_len,
    req_pkt_tc,
    req_pkt_ep,
    req_pkt_attr,
    req_pkt_byte_en,
    req_pkt_fmt,
    req_pkt_type,
    req_pkt_addr,
    req_pkt_data,
    req_pkt_ep_strb,
    req_pkt_silentDrop_strb,
    req_pkt_silentDrop_strb_masked,
    req_pkt_strb,
    pdcmp_addr_parerr,
    ras_dp_err_inj_slv_aclk,
    pdcmp_ad_ras_dp_err_log,
    fifo_pkt_halt,
    inq_pkt_hv,
    inq_pkt_dv,
    inq_pkt_eot,
    inq_pkt_null,
    inq_pkt_prfx,
    inq_pkt_p_tag,
    inq_pkt_th,
    inq_pkt_ph,
    inq_pkt_st,
    inq_pkt_atu_bypass,
    inq_pkt_dst_segment,
    inq_pkt_ats,
    inq_pkt_nw,
    inq_pkt_last_tlp,
    inq_pkt_axi_id,
    inq_pkt_cpl_stat,
    inq_pkt_byte_len,
    inq_pkt_tc,
    inq_pkt_ep,
    inq_pkt_silentDrop,
    inq_pkt_attr,
    inq_pkt_byte_en,
    inq_pkt_fmt,
    inq_pkt_type,
    inq_pkt_addr,
    inq_pkt_strb,
    inq_pkt_data


   );




// Parameters depending on decomposer usage (inbound vs outbound, posted vs non-posted)
// ---------------------------------------------------------------------------------------------------------------------
parameter  TP                            = `TP;
// FSM state definition
// ---------------------------------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------

localparam S_READY                           = 6'b00_0000;
localparam S_WR_NODCMP                       = 6'b00_0001;
localparam S_WR_DCMP_FIRST_TLP_INTMD_BEAT    = 6'b01_0010;
localparam S_WR_DCMP_FIRST_TLP_LAST_BEAT     = 6'b10_0010;
localparam S_WR_DCMP_INTMD_TLP_FIRST_BEAT    = 6'b00_0110;
localparam S_WR_DCMP_INTMD_TLP_INTMD_BEAT    = 6'b01_0110;
localparam S_WR_DCMP_INTMD_TLP_LAST_BEAT     = 6'b10_0110;
localparam S_WR_DCMP_LAST_TLP_FIRST_BEAT     = 6'b00_1010;
localparam S_WR_DCMP_LAST_TLP_INTMD_BEAT     = 6'b01_1010;
localparam S_WR_DCMP_LAST_TLP_LAST_BEAT      = 6'b10_1010;
localparam S_WR_DCMP_LAST_TLP_SINGLE_BEAT    = 6'b11_1010;
localparam S_WR_DCMP_LAST_TLP_EXTRA_BEAT     = 6'b10_1110;
localparam S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT   = 6'b11_1110;

// Parameters set by coreConsultant
// ---------------------------------------------------------------------------------------------------------------------


localparam CC_SLV_BUS_ADDR_WIDTH             = `CC_SLV_BUS_ADDR_WIDTH;
localparam CC_PRF_TLP_DATA_WIDTH             = `CC_PRF_TLP_DATA_WIDTH;
localparam CC_PRF_TLP_DATA_WIDTH_NP          = `CC_PRF_TLP_DATA_WIDTH_NP;
localparam CC_PRF_TLP_NUM_WSTRBS             = `CC_PRF_TLP_NUM_WSTRBS;
localparam CC_SLV_BUS_ID_WIDTH               = `CC_SLV_BUS_ID_WIDTH;
localparam CC_SLV_RD_REQ_SIZE_PW             = `CC_SLV_RD_REQ_SIZE_PW;
localparam CC_CORE_DATA_BUS_WD               = `CC_CORE_DATA_BUS_WD;
localparam CC_CORE_ADDR_BUS_WD               = `CC_CORE_ADDR_BUS_WD;
localparam CC_DBUS_DWORD_WD_WITH_PAR         = `CC_DBUS_DWORD_WD_WITH_PAR;
localparam CC_MAX_SLV_TAG_PW                 = `CC_MAX_SLV_TAG_PW;
localparam CX_LUT_PTR_WIDTH                  = `CX_LUT_PTR_WIDTH ;
localparam CX_TAG_SIZE                       = `CX_TAG_SIZE;
localparam CX_NFUNC                          = `CX_NFUNC;
localparam CX_NFUNC_WD                       = `CX_NFUNC_WD;
localparam CX_NFUNC_LOG2                     = `CX_NFUNC > 1 ? $clog2(CX_NFUNC) : 1;
localparam CX_NVFUNC_WD                      = `CX_NVFUNC_WD;
localparam DC_CPL_STATUS_WD                  = `DC_CPL_STATUS_WD;
localparam CC_SLV_MTU_PW                     = `CC_SLV_MTU_PW;
localparam FIFO_BYTE_LEN_WD                  = `CC_SLV_MTU_PW < (`CX_MAX_MTU_PW+1) ? `CC_SLV_MTU_PW : `CX_MAX_MTU_PW+1;
localparam PAGE_BOUNDARY_BIT                 = 13;                           // power of 2 of address boundary uncrossable + 1.
localparam ADDR_WD_WO_PAR                    = (CC_SLV_BUS_ADDR_WIDTH >=64) ? 64:32;
localparam ADDR_PAR_WIDTH                    = CC_SLV_BUS_ADDR_WIDTH - ADDR_WD_WO_PAR;
localparam NW                                = CC_PRF_TLP_DATA_WIDTH/CC_DBUS_DWORD_WD_WITH_PAR; // Number of DWORDs in data bus
localparam MTU_LESS_NW                       = (`CC_SLV_MTU/4 < NW) ? 1 : 0;
localparam STRBS_PER_DWORD                   = 4;
localparam DCMP_PREFIX_WD                    = (32*`CX_NPRFX)+ `CX_PRFX_PAR_WD;
localparam CX_RAS_PROT_RANGE                 = `CX_RAS_PROT_RANGE;
localparam CX_RAS_PARITY_MODE                = `CX_RAS_PARITY_MODE;
localparam NUM_DATA_PAR_BLOCKS               = ADDR_WD_WO_PAR / `CX_RAS_PROT_RANGE;

localparam CC_OB_PDCMP_HDR_RAM_DP        = 60;
localparam CC_OB_PDCMP_HDR_RAM_ADDR_WD   = 8;
localparam CC_OB_PDCMP_HDR_RAM_DATA_WD   = 512;
localparam CC_OB_PDCMP_HDR_RAM_PTR_WD    = 9;
localparam CC_OB_PDCMP_DATA_RAM_DP       = 60;
localparam CC_OB_PDCMP_DATA_RAM_ADDR_WD  = 8;
localparam CC_OB_PDCMP_DATA_RAM_DATA_WD  = 512;
localparam CC_OB_PDCMP_DATA_RAM_PTR_WD   = 9;
localparam ATTR_WD                           = 3;

input  wire                                  slv_aclk;
input  wire                                  slv_aresetn;

// Configuration interface
// ---------------------------------------------------------------------------------------------------------------------
input  wire [(3*CX_NFUNC)-1:0]               cfg_max_payload_size;

// Request packet interface
output wire                                  inq_pkt_halt;
input  wire                                  req_pkt_hv;
input  wire                                  req_pkt_dv;
input  wire                                  req_pkt_eot;
input  wire [DCMP_PREFIX_WD-1:0]             req_pkt_prfx;
input  wire [CX_TAG_SIZE-1:0]                req_pkt_p_tag;
input  wire                                  req_pkt_th;
input  wire [1:0]                            req_pkt_ph;
input  wire [7:0]                            req_pkt_st;
input  wire                                  req_pkt_atu_bypass;
input  wire [8:0]                            req_pkt_dst_segment;
input  wire [1:0]                            req_pkt_ats;
input  wire                                  req_pkt_nw;
input  wire                                  req_pkt_first_wrp_split_xact;
input  wire                                  req_pkt_wrp_valid;
input  wire [CC_SLV_BUS_ID_WIDTH-1:0]        req_pkt_axi_id;
input  wire [DC_CPL_STATUS_WD-1:0]           req_pkt_cpl_stat;
input  wire [CC_SLV_MTU_PW-1:0]              req_pkt_byte_len;
input  wire [2:0]                            req_pkt_tc;
input  wire                                  req_pkt_ep;
input  wire [ATTR_WD-1:0]                    req_pkt_attr;
input  wire [7:0]                            req_pkt_byte_en;
input  wire [1:0]                            req_pkt_fmt;
input  wire [4:0]                            req_pkt_type;
input  wire [CC_SLV_BUS_ADDR_WIDTH-1:0]      req_pkt_addr;
input  wire [CC_PRF_TLP_DATA_WIDTH-1:0]      req_pkt_data;
input wire [CC_PRF_TLP_NUM_WSTRBS-1:0]       req_pkt_ep_strb;
input wire [CC_PRF_TLP_NUM_WSTRBS-1:0]       req_pkt_silentDrop_strb;
input wire [CC_PRF_TLP_NUM_WSTRBS-1:0]       req_pkt_silentDrop_strb_masked;
input wire [CC_PRF_TLP_NUM_WSTRBS-1:0]       req_pkt_strb;
output wire                                  pdcmp_addr_parerr;
input ras_dp_err_inj_t                       ras_dp_err_inj_slv_aclk;
output ras_dp_err_log_t                      pdcmp_ad_ras_dp_err_log;
input  wire                                  fifo_pkt_halt;
output wire                                  inq_pkt_hv;
output wire                                  inq_pkt_dv;
output wire                                  inq_pkt_eot;
output wire                                  inq_pkt_null;
output wire [DCMP_PREFIX_WD-1:0]             inq_pkt_prfx;
output wire [CX_TAG_SIZE-1:0]                inq_pkt_p_tag;
output wire                                  inq_pkt_th;
output wire [1:0]                            inq_pkt_ph;
output wire [7:0]                            inq_pkt_st;
output wire                                  inq_pkt_atu_bypass;
output wire [8:0]                            inq_pkt_dst_segment;
output wire [1:0]                            inq_pkt_ats;
output wire                                  inq_pkt_nw;
output wire                                  inq_pkt_last_tlp;
output wire [CC_SLV_BUS_ID_WIDTH-1:0]        inq_pkt_axi_id;
output  wire [DC_CPL_STATUS_WD-1:0]          inq_pkt_cpl_stat;
output wire [FIFO_BYTE_LEN_WD-1:0]           inq_pkt_byte_len;
output wire [2:0]                            inq_pkt_tc;
output wire                                  inq_pkt_ep;
output wire                                  inq_pkt_silentDrop;
output wire [ATTR_WD-1:0]                    inq_pkt_attr;
output wire [7:0]                            inq_pkt_byte_en;
output wire [1:0]                            inq_pkt_fmt;
output wire [4:0]                            inq_pkt_type;
output wire [CC_SLV_BUS_ADDR_WIDTH-1:0]      inq_pkt_addr;
output wire [CC_PRF_TLP_DATA_WIDTH-1:0]      inq_pkt_data;
output wire [CC_PRF_TLP_NUM_WSTRBS-1:0]      inq_pkt_strb;

reg    [10:0]                                s_max_payload_dw_len;       // Max payload size for current function
wire   [10:0]                                s_max_payload_dw_len_addr_mask;

reg    [ADDR_PAR_WIDTH -1:0]                 s_calc_req_addr_par;
reg    [ADDR_PAR_WIDTH -1:0]                 s_calc_inq_addr_par;
reg    [ADDR_WD_WO_PAR -1:0]                 s_req_pkt_addr_nopar_int;
reg    [ADDR_PAR_WIDTH -1:0]                 s_req_pkt_addr_parity;
wire   [ADDR_WD_WO_PAR-1:0]                  req_pkt_addr_nopar;
reg    [5:0]                                 state;
reg    [5:0]                                 next_state;
reg  [DCMP_PREFIX_WD-1:0]                    r_latched_pkt_prfx;
reg  [CX_TAG_SIZE-1:0]                       r_latched_pkt_p_tag;
reg                                          r_latched_pkt_th;
reg  [1:0]                                   r_latched_pkt_ph;
reg  [7:0]                                   r_latched_pkt_st;
reg                                          r_latched_pkt_atu_bypass;
reg  [8:0]                                   r_latched_pkt_dst_segment;
reg  [1:0]                                   r_latched_pkt_ats;
reg                                          r_latched_pkt_nw;
reg                                          r_latched_pkt_first_wrp_split_xact;
reg                                          r_latched_pkt_wrp_valid;
reg  [CC_SLV_BUS_ID_WIDTH-1:0]               r_latched_pkt_axi_id;
reg  [DC_CPL_STATUS_WD-1:0]                  r_latched_pkt_cpl_stat;
reg  [CC_SLV_MTU_PW-1:0]                     r_latched_pkt_byte_len;
reg  [2:0]                                   r_latched_pkt_tc;
reg                                          r_latched_pkt_ep;
reg  [ATTR_WD-1:0]                           r_latched_pkt_attr;
reg  [7:0]                                   r_latched_pkt_byte_en;
reg  [1:0]                                   r_latched_pkt_fmt;
reg  [4:0]                                   r_latched_pkt_type;
reg  [ADDR_WD_WO_PAR-1:0]                    r_latched_pkt_addr_nopar;
reg  [CC_PRF_TLP_DATA_WIDTH-1:0]             r_latched_pkt_data;

wire                                         s_latch_req_pkt;
wire                                         s_latch_req_pkt_byte_len;

wire [DCMP_PREFIX_WD-1:0]                    s_pkt_prfx;
wire [CX_TAG_SIZE-1:0]                       s_pkt_p_tag;
wire                                         s_pkt_th;
wire [1:0]                                   s_pkt_ph;
wire [7:0]                                   s_pkt_st;
wire                                         s_pkt_atu_bypass;
wire [8:0]                                   s_pkt_dst_segment;
wire [1:0]                                   s_pkt_ats;
wire                                         s_pkt_nw;
wire                                         s_pkt_first_wrp_split_xact;
wire                                         s_pkt_wrp_valid;
wire                                         s_wrap_null_wr;
wire                                         s_first_tlp_w_data;
wire                                         w_first_tlp_w_data;
reg                                          r_first_tlp_w_data;
wire [CC_SLV_BUS_ID_WIDTH-1:0]               s_pkt_axi_id;
wire [DC_CPL_STATUS_WD-1:0]                  s_pkt_cpl_stat;
wire [CC_SLV_MTU_PW-1:0]                     s_pkt_byte_len;
wire [2:0]                                   s_pkt_tc;
wire                                         s_pkt_ep;
wire [ATTR_WD-1:0]                           s_pkt_attr;
wire [7:0]                                   s_pkt_byte_en;
wire [1:0]                                   s_pkt_fmt;
wire [4:0]                                   s_pkt_type;
wire [ADDR_WD_WO_PAR-1:0]                    s_pkt_addr_nopar;
wire [CC_PRF_TLP_DATA_WIDTH-1:0]             s_pkt_data;

wire [6:0]                                   s_pkt_fmt_type;
wire                                         s_pkt_msg;

wire [CC_SLV_MTU_PW-3:0]                     s_pkt_dw_len;

wire   [CX_NFUNC_LOG2-1:0]                   s_pkt_func_num_max_payload;

wire   [CC_SLV_MTU_PW -3 :0]                 s_pkt_remaining_dw_len;
reg    [CC_SLV_MTU_PW -3 :0]                 r_pkt_sent_dw_len;
wire   [CC_SLV_MTU_PW -3 :0]                 s_pkt_sent_dw_len;
wire                                         s_pkt_exceeds_max_payload;
wire   [10:0]                                s_pkt_dw_to_next_max_payload;
wire                                         s_pkt_halt;

wire   [FIFO_BYTE_LEN_WD-3 :0]               s_tlp_dw_len;
wire   [FIFO_BYTE_LEN_WD-3 :0]               s_tlp_sent_dw_len;
reg    [FIFO_BYTE_LEN_WD-3 :0]               r_tlp_sent_dw_len;
wire   [FIFO_BYTE_LEN_WD-3 :0]               s_tlp_remaining_dw_len;

wire   [FIFO_BYTE_LEN_WD-3 :0]               s_tlp_beat_dw_len;

wire   [ADDR_WD_WO_PAR-1:0]                  s_tlp_addr_nopar;

wire                                         s_tlp_first_beat;
wire                                         s_tlp_last_beat;
wire                                         s_decomposition_required;
wire                                         s_pkt_first_tlp;
wire                                         s_pkt_last_tlp;

reg    [CC_PRF_TLP_DATA_WIDTH-1:0]           r_pkt_data;
wire   [2*CC_PRF_TLP_DATA_WIDTH-1:0]         s_pkt_data_mux;
wire   [3:0]                                 s_pkt_data_shift;
wire   [3:0]                                 s_pkt_data_sel;
reg    [3:0]                                 r_pkt_data_sel;

reg    [CC_PRF_TLP_NUM_WSTRBS-1:0]           r_pkt_ep_strb;
reg    [2*CC_PRF_TLP_NUM_WSTRBS-1:0]         s_pkt_ep_strb_mux;
wire   [CC_PRF_TLP_NUM_WSTRBS-1:0]           s_inq_pkt_ep_strb;

reg    [CC_PRF_TLP_NUM_WSTRBS-1:0]           r_pkt_silentDrop_strb;
reg    [2*CC_PRF_TLP_NUM_WSTRBS-1:0]         s_pkt_silentDrop_strb_mux;
wire   [CC_PRF_TLP_NUM_WSTRBS-1:0]           s_inq_pkt_silentDrop_strb;

reg    [CC_PRF_TLP_NUM_WSTRBS-1:0]           r_pkt_silentDropMasked_strb;
reg    [2*CC_PRF_TLP_NUM_WSTRBS-1:0]         s_pkt_silentDropMasked_strb_mux;
wire   [CC_PRF_TLP_NUM_WSTRBS-1:0]           s_inq_pkt_silentDropMasked_strb;

reg    [CC_PRF_TLP_NUM_WSTRBS-1:0]           r_pkt_strb;
reg    [2*CC_PRF_TLP_NUM_WSTRBS-1:0]         s_pkt_strb_mux;

wire                                         w_inq_pkt_ep_strb;
reg                                          r_inq_pkt_ep_strb;
wire                                         s_pkt_ep_strb;
wire                                         s_pkt_no_data;

wire                                         w_inq_pkt_silentDrop_strb;
reg                                          r_inq_pkt_silentDrop_strb;
wire                                         s_pkt_silentDrop_strb;

// cfg_max_payload_size decoding for outbound posted write decomposition
// ---------------------------------------------------------------------------------------------------------------------
assign s_pkt_func_num_max_payload = {CX_NFUNC_WD{1'b0}};


always @(*)
  begin: S_MAX_PAYLOAD_DW_LEN_COMB_PROC
    case (get_cfg_setting(cfg_max_payload_size, s_pkt_func_num_max_payload))
      3'b000 : s_max_payload_dw_len   = 11'h020; //  128B (  32 DW)
      3'b001 : s_max_payload_dw_len   = 11'h040; //  256B (  64 DW)
      3'b010 : s_max_payload_dw_len   = 11'h080; //  512B ( 128 DW)
      3'b011 : s_max_payload_dw_len   = 11'h100; // 1024B ( 256 DW)
      3'b100 : s_max_payload_dw_len   = 11'h200; // 2048B ( 512 DW)
      3'b101 : s_max_payload_dw_len   = 11'h400; // 4096B (1024 DW)
      default: s_max_payload_dw_len   = 11'h020; //  128B (  32 DW)
    endcase
  end

assign s_max_payload_dw_len_addr_mask      = s_max_payload_dw_len-11'h001;

// Detecting address parity errors and removing parity bits from address to allow it to be used in internal calculations
// ---------------------------------------------------------------------------------------------------------------------
always @( * )
begin: ADDR_STRIP_OFF_PAR_COMB_PROC
integer i,j;
    s_req_pkt_addr_nopar_int = 0;
    s_req_pkt_addr_parity    = 0;
    for (i=0; i<ADDR_PAR_WIDTH; i=i+1) begin
        for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
            s_req_pkt_addr_nopar_int[i*CX_RAS_PROT_RANGE + j] = req_pkt_addr[i*CX_RAS_PROT_RANGE +j +i];
        end
        s_req_pkt_addr_parity[i] =  req_pkt_addr[(i+1)*CX_RAS_PROT_RANGE +i];
    end
end

assign req_pkt_addr_nopar = s_req_pkt_addr_nopar_int;


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
    .TOTAL_WIDTH               (ADDR_WD_WO_PAR                 ),
    .EXCLUDE_PROT_WIDTH        (0                              ),
    .RAS_DP_PROT_CHK_ID_BASE   (`PDCMP_ADDR_RAS_DP_ID          )
  ) u_addr_chk (
    .clk                       ( slv_aclk                      ),
    .rst_n                     ( slv_aresetn                   ),
    .din                       ( req_pkt_addr_nopar            ),
    .din_prot                  ( s_req_pkt_addr_parity         ),
    .dout                      ( /* Not Connected */           ),
    .dout_prot                 ( /* Not Connected */           ),
    .en                        (1'b1                           ),
    .bypass                    (1'b0                           ),
    .stall                     (1'b0                           ),
    .stallout                  ( /* Not Connected */           ),
    .valid_in                  ( req_pkt_hv                    ),
    .halt_out                  ( /* Not Connected */           ),
    .valid_out                 ( /* Not Connected */           ),
    .halt_in                   (1'b0                           ),
    .ras_dp_err_inband_kbd_in  (1'b0                           ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */           ),
    .ras_dp_err_log            ( pdcmp_ad_ras_dp_err_log       )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk        )
    );

   assign pdcmp_addr_parerr = pdcmp_ad_ras_dp_err_log.valid;

assign s_pkt_halt = fifo_pkt_halt || state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT || state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT;
// latch request when accepted
// ---------------------------------------------------------------------------------------------------------------------
assign s_latch_req_pkt          =     (state == S_READY) && req_pkt_hv && !s_pkt_halt;


// The packet length of outbound posted packets can be adjusted at eot due to the presence of null write strobes
// ---------------------------------------------------------------------------------------------------------------------

assign s_latch_req_pkt_byte_len = ( ( (state == S_READY) && req_pkt_hv ) || req_pkt_eot ) && !s_pkt_halt;

always@(posedge slv_aclk or negedge slv_aresetn)
  begin: R_LATCHED_PKT_SEQ_PROC
    if(!slv_aresetn) begin
        r_latched_pkt_prfx                 <= #TP {DCMP_PREFIX_WD{1'b0}};
        r_latched_pkt_p_tag                <= #TP {CX_TAG_SIZE{1'b0}};
        r_latched_pkt_th                   <= #TP 1'b0;
        r_latched_pkt_ph                   <= #TP 2'h0;
        r_latched_pkt_st                   <= #TP 8'h00;
        r_latched_pkt_atu_bypass           <= #TP 1'b0;
        r_latched_pkt_dst_segment          <= #TP 9'h000;
        r_latched_pkt_ats                  <= #TP 2'h0;
        r_latched_pkt_nw                   <= #TP 1'b0;
        r_latched_pkt_first_wrp_split_xact <= #TP 1'b0;
        r_latched_pkt_wrp_valid            <= #TP 1'b0;
        r_latched_pkt_axi_id               <= #TP {CC_SLV_BUS_ID_WIDTH{1'b0}};
        r_latched_pkt_cpl_stat             <= #TP {DC_CPL_STATUS_WD{1'b0}};
        r_latched_pkt_tc                   <= #TP 3'h0;
        r_latched_pkt_ep                   <= #TP 1'b0;
        r_latched_pkt_attr                 <= #TP {ATTR_WD{1'b0}};
        r_latched_pkt_fmt                  <= #TP 2'h0;
        r_latched_pkt_type                 <= #TP 5'h00;
        r_latched_pkt_addr_nopar           <= #TP {CC_SLV_BUS_ADDR_WIDTH{1'b0}};
      end else if (s_latch_req_pkt) begin
        r_latched_pkt_prfx                 <= #TP req_pkt_prfx;
        r_latched_pkt_p_tag                <= #TP req_pkt_p_tag;
        r_latched_pkt_th                   <= #TP req_pkt_th;
        r_latched_pkt_ph                   <= #TP req_pkt_ph;
        r_latched_pkt_st                   <= #TP req_pkt_st;
        r_latched_pkt_atu_bypass           <= #TP req_pkt_atu_bypass;
        r_latched_pkt_dst_segment          <= #TP req_pkt_dst_segment;
        r_latched_pkt_ats                  <= #TP req_pkt_ats;
        r_latched_pkt_nw                   <= #TP req_pkt_nw;
        r_latched_pkt_first_wrp_split_xact <= #TP req_pkt_first_wrp_split_xact;
        r_latched_pkt_wrp_valid            <= #TP req_pkt_wrp_valid;
        r_latched_pkt_axi_id               <= #TP req_pkt_axi_id;
        r_latched_pkt_cpl_stat             <= #TP req_pkt_cpl_stat;
        r_latched_pkt_tc                   <= #TP req_pkt_tc;
        r_latched_pkt_ep                   <= #TP req_pkt_ep;
        r_latched_pkt_attr                 <= #TP req_pkt_attr;
        r_latched_pkt_fmt                  <= #TP req_pkt_fmt;
        r_latched_pkt_type                 <= #TP req_pkt_type;
        r_latched_pkt_addr_nopar           <= #TP req_pkt_addr_nopar;
      end
  end


always@(posedge slv_aclk or negedge slv_aresetn)
  begin: R_LATCHED_PKT_BYTE_LEN_SEQ_PROC
    if(!slv_aresetn) begin
        r_latched_pkt_byte_len             <= #TP {CC_SLV_MTU_PW{1'b0}};
        r_latched_pkt_byte_en              <= #TP 8'h00;
      end else if (s_latch_req_pkt_byte_len) begin
        r_latched_pkt_byte_len             <= #TP req_pkt_byte_len;
        r_latched_pkt_byte_en              <= #TP req_pkt_byte_en;
      end
  end

assign s_pkt_byte_len             = s_latch_req_pkt_byte_len ? req_pkt_byte_len             : r_latched_pkt_byte_len;
assign s_pkt_byte_en              = s_latch_req_pkt_byte_len ? req_pkt_byte_en              : r_latched_pkt_byte_en;
assign s_pkt_prfx                 = s_latch_req_pkt          ? req_pkt_prfx                 : r_latched_pkt_prfx;
assign s_pkt_p_tag                = s_latch_req_pkt          ? req_pkt_p_tag                : r_latched_pkt_p_tag;
assign s_pkt_th                   = s_latch_req_pkt          ? req_pkt_th                   : r_latched_pkt_th;
assign s_pkt_ph                   = s_latch_req_pkt          ? req_pkt_ph                   : r_latched_pkt_ph;
assign s_pkt_st                   = s_latch_req_pkt          ? req_pkt_st                   : r_latched_pkt_st;
assign s_pkt_atu_bypass           = s_latch_req_pkt          ? req_pkt_atu_bypass           : r_latched_pkt_atu_bypass;
assign s_pkt_dst_segment          = s_latch_req_pkt          ? req_pkt_dst_segment          : r_latched_pkt_dst_segment;
assign s_pkt_ats                  = s_latch_req_pkt          ? req_pkt_ats                  : r_latched_pkt_ats;
assign s_pkt_nw                   = s_latch_req_pkt          ? req_pkt_nw                   : r_latched_pkt_nw;
assign s_pkt_first_wrp_split_xact = s_latch_req_pkt          ? req_pkt_first_wrp_split_xact : r_latched_pkt_first_wrp_split_xact;
assign s_pkt_wrp_valid            = s_latch_req_pkt          ? req_pkt_wrp_valid            : r_latched_pkt_wrp_valid;
assign s_pkt_axi_id               = s_latch_req_pkt          ? req_pkt_axi_id               : r_latched_pkt_axi_id;
assign s_pkt_cpl_stat             = s_latch_req_pkt          ? req_pkt_cpl_stat             : r_latched_pkt_cpl_stat;
assign s_pkt_tc                   = s_latch_req_pkt          ? req_pkt_tc                   : r_latched_pkt_tc;
assign s_pkt_ep                   = s_latch_req_pkt          ? req_pkt_ep                   : r_latched_pkt_ep;
assign s_pkt_attr                 = s_latch_req_pkt          ? req_pkt_attr                 : r_latched_pkt_attr;
assign s_pkt_fmt                  = s_latch_req_pkt          ? req_pkt_fmt                  : r_latched_pkt_fmt;
assign s_pkt_type                 = s_latch_req_pkt          ? req_pkt_type                 : r_latched_pkt_type;
assign s_pkt_addr_nopar           = s_latch_req_pkt          ? req_pkt_addr_nopar           : r_latched_pkt_addr_nopar;

assign s_pkt_dw_len               = s_pkt_byte_len[CC_SLV_MTU_PW-1:2];

assign s_pkt_fmt_type             = {s_pkt_fmt,s_pkt_type};

assign s_pkt_msg                  =  (s_pkt_fmt_type[6:3] == `MSG_4    ) ||
                                     (s_pkt_fmt_type[6:3] == `MSGD_4   ) ||
                                     (s_pkt_fmt_type[6:3] == `MSG_AS_4 ) ||
                                     (s_pkt_fmt_type[6:3] == `MSGD_AS_4);

always@(posedge slv_aclk or negedge slv_aresetn)
  begin: OB_P_R_PKT_SENT_DW_LEN_SEQ_PROC
    if (!slv_aresetn) begin
      r_pkt_sent_dw_len <= #TP 0;
    end else begin
      if (!s_pkt_halt) begin
        if(state == S_READY) begin
          if (s_tlp_last_beat && inq_pkt_dv) begin
            r_pkt_sent_dw_len <= #TP {{(CC_SLV_MTU_PW-FIFO_BYTE_LEN_WD){1'b0}},s_tlp_dw_len};
    end else begin
            r_pkt_sent_dw_len <= #TP 0;
    end
        end else begin
          if (s_tlp_last_beat && inq_pkt_dv) begin
            // spyglass disable_block W164a
            // SMD: Identifies assignments in which the LHS width is less than the RHS width
            // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
            r_pkt_sent_dw_len <= #TP r_pkt_sent_dw_len + {{(CC_SLV_MTU_PW-FIFO_BYTE_LEN_WD){1'b0}},s_tlp_dw_len};
            // spyglass enable_block W164a
          end
        end
      end
    end
  end
assign s_pkt_sent_dw_len             = ( state == S_READY ) ? 0 : r_pkt_sent_dw_len;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_pkt_remaining_dw_len        = s_pkt_dw_len - s_pkt_sent_dw_len;
// spyglass enable_block W164a

// s_pkt_exceeds_max_payload             : request exceeds maximum payload size
// s_pkt_dw_to_next_max_payload          : number of bytes to next maximum payload boundary
// ---------------------------------------------------------------------------------------------------------------------
assign s_pkt_exceeds_max_payload     = (state == S_READY) ? ({{(13-CC_SLV_MTU_PW){1'b0}},s_pkt_dw_len} > s_max_payload_dw_len) : ({{(13-CC_SLV_MTU_PW){1'b0}},s_pkt_remaining_dw_len} > s_max_payload_dw_len);
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_pkt_dw_to_next_max_payload  = s_max_payload_dw_len - (s_tlp_addr_nopar[12:2] & s_max_payload_dw_len_addr_mask);
// spyglass enable_block W164a

// s_decomposition_required
// ---------------------------------------------------------------------------------------------------------------------
assign s_decomposition_required      = s_pkt_msg? 1'b0 : s_pkt_exceeds_max_payload;

assign s_pkt_first_tlp               =   (state == S_READY) || (state == S_WR_NODCMP) || (state == S_WR_DCMP_FIRST_TLP_INTMD_BEAT) || (state == S_WR_DCMP_FIRST_TLP_LAST_BEAT);
assign s_pkt_last_tlp                = (((state == S_READY) || (state == S_WR_NODCMP)) && !s_decomposition_required ) || (req_pkt_eot && (!req_pkt_dv || (s_pkt_dw_len - (r_pkt_sent_dw_len + {{(CC_SLV_MTU_PW-FIFO_BYTE_LEN_WD){1'b0}},s_tlp_dw_len}) == 0))) ||
                                         (state == S_WR_DCMP_LAST_TLP_FIRST_BEAT) ||
                                         (state == S_WR_DCMP_LAST_TLP_INTMD_BEAT) ||
                                         (state == S_WR_DCMP_LAST_TLP_LAST_BEAT) ||
                                         (state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT) ||
                                         (state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT) ||
                                         (state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT);
assign s_tlp_first_beat              =  ((state == S_READY ) && req_pkt_hv ) || (state == S_WR_DCMP_INTMD_TLP_FIRST_BEAT) || (state == S_WR_DCMP_LAST_TLP_FIRST_BEAT) || (state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT);
assign s_tlp_last_beat               = (((state == S_READY) || (state == S_WR_NODCMP)) && req_pkt_eot) ||
                                        (req_pkt_eot && (s_tlp_remaining_dw_len <= NW )) ||
                                        ((state == S_READY) && (s_tlp_dw_len <= NW)) ||
                                         (state == S_WR_DCMP_FIRST_TLP_LAST_BEAT) ||

                                         (state == S_WR_DCMP_INTMD_TLP_LAST_BEAT) ||
                                         (state == S_WR_DCMP_LAST_TLP_LAST_BEAT) ||
                                         (state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT) ||
                                         (state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT) ||
                                         (state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT);

assign s_tlp_dw_len                  = s_decomposition_required ? s_pkt_dw_to_next_max_payload[FIFO_BYTE_LEN_WD-3:0] : s_pkt_remaining_dw_len[FIFO_BYTE_LEN_WD-3:0];

assign s_tlp_sent_dw_len             = s_tlp_first_beat ? 0 : r_tlp_sent_dw_len ;
generate
if (MTU_LESS_NW) begin : S_TLP_BEAT_DW_LEN_GEN_MTU_LT_NW
assign s_tlp_beat_dw_len             = s_tlp_remaining_dw_len;
end else begin : S_TLP_BEAT_DW_LEN_GEN_MTU_EQ_OR_GT_NW
assign s_tlp_beat_dw_len             = s_tlp_last_beat  ? s_tlp_remaining_dw_len : NW ;
end
endgenerate


always@(posedge slv_aclk or negedge slv_aresetn)
  begin: R_TLP_SENT_DW_LEN_SEQ_PROC
    if (!slv_aresetn) begin
      r_tlp_sent_dw_len <= #TP 0;
    end else begin
      if ( !s_pkt_halt && req_pkt_dv ) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
        r_tlp_sent_dw_len <= #TP s_tlp_sent_dw_len + s_tlp_beat_dw_len;
// spyglass enable_block W164a
      end
    end
  end

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_tlp_remaining_dw_len = s_tlp_dw_len - s_tlp_sent_dw_len;
// spyglass enable_block W164a

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_tlp_addr_nopar = s_pkt_msg ? s_pkt_addr_nopar : {s_pkt_addr_nopar[ADDR_WD_WO_PAR-1:2],2'b00} + {{(ADDR_WD_WO_PAR-CC_SLV_MTU_PW){1'b0}},s_pkt_sent_dw_len,2'b00};
// spyglass enable_block W164a

always@(posedge slv_aclk or negedge slv_aresetn)
  begin: R_PKT_DATA_SEQ_PROC
    if (!slv_aresetn) begin
      r_pkt_data <= #TP 0;
      r_pkt_ep_strb <= #TP 0;
      r_pkt_silentDrop_strb <= #TP 0;
      r_pkt_silentDropMasked_strb <= #TP 0;
      r_pkt_strb <= #TP 0;
    end else begin
      if(req_pkt_dv && !inq_pkt_halt) begin
        r_pkt_data <= #TP req_pkt_data;
        r_pkt_ep_strb <= #TP req_pkt_ep_strb;
        r_pkt_silentDrop_strb <= #TP req_pkt_silentDrop_strb;
        r_pkt_silentDropMasked_strb <= #TP req_pkt_silentDrop_strb_masked;
        r_pkt_strb <= #TP req_pkt_strb;
      end
    end
  end

generate
if (NW == 16) begin : S_PKT_DATA_SHIFT_GEN_NW_16
assign s_pkt_data_shift =           s_pkt_dw_to_next_max_payload[3:0];
end else if (NW == 8) begin : S_PKT_DATA_SHIFT_GEN_NW_8
assign s_pkt_data_shift =   {  1'b0,s_pkt_dw_to_next_max_payload[2:0]};
end else if (NW == 4) begin : S_PKT_DATA_SHIFT_GEN_NW_4
assign s_pkt_data_shift =   { 2'b00,s_pkt_dw_to_next_max_payload[1:0]};
end else if (NW == 2) begin : S_PKT_DATA_SHIFT_GEN_NW_2
assign s_pkt_data_shift =   {3'b000,s_pkt_dw_to_next_max_payload[0]};
end else begin : S_PKT_DATA_SHIFT_GEN_NW_1
assign s_pkt_data_shift = 4'b0000;
end

always@(posedge slv_aclk or negedge slv_aresetn)
  begin: R_PKT_DATA_SEL_SEQ_PROC
    if (!slv_aresetn) begin
      r_pkt_data_sel <= #TP 4'b0000;
    end else begin
      if (!fifo_pkt_halt && inq_pkt_eot) begin
        if (s_pkt_last_tlp && s_tlp_last_beat)begin
          r_pkt_data_sel <= #TP 4'b0000;
        end else if ( s_pkt_first_tlp && s_tlp_last_beat) begin
          r_pkt_data_sel <= #TP s_pkt_data_shift;
        end
      end
    end
  end

assign s_pkt_data_sel = s_pkt_first_tlp ? 3'b000 : r_pkt_data_sel;

if (NW > 1) begin : S_PKT_DATA_MUX_GEN_NW_GT_1
assign s_pkt_data_mux = {req_pkt_data,r_pkt_data};
assign s_pkt_ep_strb_mux = {req_pkt_ep_strb,r_pkt_ep_strb};
assign s_pkt_silentDrop_strb_mux = {req_pkt_silentDrop_strb,r_pkt_silentDrop_strb};
assign s_pkt_silentDropMasked_strb_mux = {req_pkt_silentDrop_strb_masked,r_pkt_silentDropMasked_strb};
assign s_pkt_strb_mux = {req_pkt_strb,r_pkt_strb};
end else begin : S_PKT_DATA_MUX_GEN_NW_LT_OR_EQ_1
assign s_pkt_data_mux = { {CC_PRF_TLP_DATA_WIDTH{1'b0}} , req_pkt_data};
assign s_pkt_ep_strb_mux = { {CC_PRF_TLP_NUM_WSTRBS{1'b0}} , req_pkt_ep_strb};
assign s_pkt_silentDrop_strb_mux = { {CC_PRF_TLP_NUM_WSTRBS{1'b0}} , req_pkt_silentDrop_strb};
assign s_pkt_silentDropMasked_strb_mux = { {CC_PRF_TLP_NUM_WSTRBS{1'b0}} , req_pkt_silentDrop_strb_masked};
assign s_pkt_strb_mux = { {CC_PRF_TLP_NUM_WSTRBS{1'b0}} , req_pkt_strb};
end

if (NW == 16) begin : INQ_PKT_DATA_GEN_NW_16
assign inq_pkt_data     =  (s_pkt_data_sel == 4'b0000) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+16))-1:CC_DBUS_DWORD_WD_WITH_PAR*16] :
                           (s_pkt_data_sel == 4'b0001) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+1 ))-1:CC_DBUS_DWORD_WD_WITH_PAR*1 ] :
                           (s_pkt_data_sel == 4'b0010) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+2 ))-1:CC_DBUS_DWORD_WD_WITH_PAR*2 ] :
                           (s_pkt_data_sel == 4'b0011) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+3 ))-1:CC_DBUS_DWORD_WD_WITH_PAR*3 ] :
                           (s_pkt_data_sel == 4'b0100) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+4 ))-1:CC_DBUS_DWORD_WD_WITH_PAR*4 ] :
                           (s_pkt_data_sel == 4'b0101) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+5 ))-1:CC_DBUS_DWORD_WD_WITH_PAR*5 ] :
                           (s_pkt_data_sel == 4'b0110) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+6 ))-1:CC_DBUS_DWORD_WD_WITH_PAR*6 ] :
                           (s_pkt_data_sel == 4'b0111) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+7 ))-1:CC_DBUS_DWORD_WD_WITH_PAR*7 ] :
                           (s_pkt_data_sel == 4'b1000) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+8 ))-1:CC_DBUS_DWORD_WD_WITH_PAR*8 ] :
                           (s_pkt_data_sel == 4'b1001) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+9 ))-1:CC_DBUS_DWORD_WD_WITH_PAR*9 ] :
                           (s_pkt_data_sel == 4'b1010) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+10))-1:CC_DBUS_DWORD_WD_WITH_PAR*10] :
                           (s_pkt_data_sel == 4'b1011) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+11))-1:CC_DBUS_DWORD_WD_WITH_PAR*11] :
                           (s_pkt_data_sel == 4'b1100) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+12))-1:CC_DBUS_DWORD_WD_WITH_PAR*12] :
                           (s_pkt_data_sel == 4'b1101) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+13))-1:CC_DBUS_DWORD_WD_WITH_PAR*13] :
                           (s_pkt_data_sel == 4'b1110) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+14))-1:CC_DBUS_DWORD_WD_WITH_PAR*14] :
                           (s_pkt_data_sel == 4'b1111) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+15))-1:CC_DBUS_DWORD_WD_WITH_PAR*15] :
                                                         s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+16))-1:CC_DBUS_DWORD_WD_WITH_PAR*16];

assign s_inq_pkt_ep_strb = (s_pkt_data_sel == 4'b0000) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+16))-1:STRBS_PER_DWORD*16] :
                           (s_pkt_data_sel == 4'b0001) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+1 ))-1:STRBS_PER_DWORD*1 ] :
                           (s_pkt_data_sel == 4'b0010) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+2 ))-1:STRBS_PER_DWORD*2 ] :
                           (s_pkt_data_sel == 4'b0011) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+3 ))-1:STRBS_PER_DWORD*3 ] :
                           (s_pkt_data_sel == 4'b0100) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+4 ))-1:STRBS_PER_DWORD*4 ] :
                           (s_pkt_data_sel == 4'b0101) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+5 ))-1:STRBS_PER_DWORD*5 ] :
                           (s_pkt_data_sel == 4'b0110) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+6 ))-1:STRBS_PER_DWORD*6 ] :
                           (s_pkt_data_sel == 4'b0111) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+7 ))-1:STRBS_PER_DWORD*7 ] :
                           (s_pkt_data_sel == 4'b1000) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+8 ))-1:STRBS_PER_DWORD*8 ] :
                           (s_pkt_data_sel == 4'b1001) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+9 ))-1:STRBS_PER_DWORD*9 ] :
                           (s_pkt_data_sel == 4'b1010) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+10))-1:STRBS_PER_DWORD*10] :
                           (s_pkt_data_sel == 4'b1011) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+11))-1:STRBS_PER_DWORD*11] :
                           (s_pkt_data_sel == 4'b1100) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+12))-1:STRBS_PER_DWORD*12] :
                           (s_pkt_data_sel == 4'b1101) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+13))-1:STRBS_PER_DWORD*13] :
                           (s_pkt_data_sel == 4'b1110) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+14))-1:STRBS_PER_DWORD*14] :
                           (s_pkt_data_sel == 4'b1111) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+15))-1:STRBS_PER_DWORD*15] :
                                                         s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+16))-1:STRBS_PER_DWORD*16];

assign s_inq_pkt_silentDrop_strb = (s_pkt_data_sel == 4'b0000) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+16))-1:STRBS_PER_DWORD*16] :
                                   (s_pkt_data_sel == 4'b0001) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+1 ))-1:STRBS_PER_DWORD*1 ] :
                                   (s_pkt_data_sel == 4'b0010) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+2 ))-1:STRBS_PER_DWORD*2 ] :
                                   (s_pkt_data_sel == 4'b0011) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+3 ))-1:STRBS_PER_DWORD*3 ] :
                                   (s_pkt_data_sel == 4'b0100) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+4 ))-1:STRBS_PER_DWORD*4 ] :
                                   (s_pkt_data_sel == 4'b0101) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+5 ))-1:STRBS_PER_DWORD*5 ] :
                                   (s_pkt_data_sel == 4'b0110) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+6 ))-1:STRBS_PER_DWORD*6 ] :
                                   (s_pkt_data_sel == 4'b0111) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+7 ))-1:STRBS_PER_DWORD*7 ] :
                                   (s_pkt_data_sel == 4'b1000) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+8 ))-1:STRBS_PER_DWORD*8 ] :
                                   (s_pkt_data_sel == 4'b1001) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+9 ))-1:STRBS_PER_DWORD*9 ] :
                                   (s_pkt_data_sel == 4'b1010) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+10))-1:STRBS_PER_DWORD*10] :
                                   (s_pkt_data_sel == 4'b1011) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+11))-1:STRBS_PER_DWORD*11] :
                                   (s_pkt_data_sel == 4'b1100) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+12))-1:STRBS_PER_DWORD*12] :
                                   (s_pkt_data_sel == 4'b1101) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+13))-1:STRBS_PER_DWORD*13] :
                                   (s_pkt_data_sel == 4'b1110) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+14))-1:STRBS_PER_DWORD*14] :
                                   (s_pkt_data_sel == 4'b1111) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+15))-1:STRBS_PER_DWORD*15] :
                                                                 s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+16))-1:STRBS_PER_DWORD*16];

assign s_inq_pkt_silentDropMasked_strb = (s_pkt_data_sel == 4'b0000) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+16))-1:STRBS_PER_DWORD*16] :
                                         (s_pkt_data_sel == 4'b0001) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+1 ))-1:STRBS_PER_DWORD*1 ] :
                                         (s_pkt_data_sel == 4'b0010) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+2 ))-1:STRBS_PER_DWORD*2 ] :
                                         (s_pkt_data_sel == 4'b0011) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+3 ))-1:STRBS_PER_DWORD*3 ] :
                                         (s_pkt_data_sel == 4'b0100) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+4 ))-1:STRBS_PER_DWORD*4 ] :
                                         (s_pkt_data_sel == 4'b0101) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+5 ))-1:STRBS_PER_DWORD*5 ] :
                                         (s_pkt_data_sel == 4'b0110) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+6 ))-1:STRBS_PER_DWORD*6 ] :
                                         (s_pkt_data_sel == 4'b0111) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+7 ))-1:STRBS_PER_DWORD*7 ] :
                                         (s_pkt_data_sel == 4'b1000) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+8 ))-1:STRBS_PER_DWORD*8 ] :
                                         (s_pkt_data_sel == 4'b1001) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+9 ))-1:STRBS_PER_DWORD*9 ] :
                                         (s_pkt_data_sel == 4'b1010) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+10))-1:STRBS_PER_DWORD*10] :
                                         (s_pkt_data_sel == 4'b1011) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+11))-1:STRBS_PER_DWORD*11] :
                                         (s_pkt_data_sel == 4'b1100) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+12))-1:STRBS_PER_DWORD*12] :
                                         (s_pkt_data_sel == 4'b1101) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+13))-1:STRBS_PER_DWORD*13] :
                                         (s_pkt_data_sel == 4'b1110) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+14))-1:STRBS_PER_DWORD*14] :
                                         (s_pkt_data_sel == 4'b1111) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+15))-1:STRBS_PER_DWORD*15] :
                                                                       s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+16))-1:STRBS_PER_DWORD*16];

assign inq_pkt_strb     =  (s_pkt_data_sel == 4'b0000) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+16))-1:STRBS_PER_DWORD*16] :
                           (s_pkt_data_sel == 4'b0001) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+1 ))-1:STRBS_PER_DWORD*1 ] :
                           (s_pkt_data_sel == 4'b0010) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+2 ))-1:STRBS_PER_DWORD*2 ] :
                           (s_pkt_data_sel == 4'b0011) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+3 ))-1:STRBS_PER_DWORD*3 ] :
                           (s_pkt_data_sel == 4'b0100) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+4 ))-1:STRBS_PER_DWORD*4 ] :
                           (s_pkt_data_sel == 4'b0101) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+5 ))-1:STRBS_PER_DWORD*5 ] :
                           (s_pkt_data_sel == 4'b0110) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+6 ))-1:STRBS_PER_DWORD*6 ] :
                           (s_pkt_data_sel == 4'b0111) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+7 ))-1:STRBS_PER_DWORD*7 ] :
                           (s_pkt_data_sel == 4'b1000) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+8 ))-1:STRBS_PER_DWORD*8 ] :
                           (s_pkt_data_sel == 4'b1001) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+9 ))-1:STRBS_PER_DWORD*9 ] :
                           (s_pkt_data_sel == 4'b1010) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+10))-1:STRBS_PER_DWORD*10] :
                           (s_pkt_data_sel == 4'b1011) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+11))-1:STRBS_PER_DWORD*11] :
                           (s_pkt_data_sel == 4'b1100) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+12))-1:STRBS_PER_DWORD*12] :
                           (s_pkt_data_sel == 4'b1101) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+13))-1:STRBS_PER_DWORD*13] :
                           (s_pkt_data_sel == 4'b1110) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+14))-1:STRBS_PER_DWORD*14] :
                           (s_pkt_data_sel == 4'b1111) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+15))-1:STRBS_PER_DWORD*15] :
                                                         s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+16))-1:STRBS_PER_DWORD*16];

end else if (NW == 8) begin : INQ_PKT_DATA_GEN_NW_8
assign inq_pkt_data     =  (s_pkt_data_sel == 3'b000) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+8))-1:CC_DBUS_DWORD_WD_WITH_PAR*8] :
                           (s_pkt_data_sel == 3'b001) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+1))-1:CC_DBUS_DWORD_WD_WITH_PAR*1] :
                           (s_pkt_data_sel == 3'b010) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+2))-1:CC_DBUS_DWORD_WD_WITH_PAR*2] :
                           (s_pkt_data_sel == 3'b011) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+3))-1:CC_DBUS_DWORD_WD_WITH_PAR*3] :
                           (s_pkt_data_sel == 3'b100) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+4))-1:CC_DBUS_DWORD_WD_WITH_PAR*4] :
                           (s_pkt_data_sel == 3'b101) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+5))-1:CC_DBUS_DWORD_WD_WITH_PAR*5] :
                           (s_pkt_data_sel == 3'b110) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+6))-1:CC_DBUS_DWORD_WD_WITH_PAR*6] :
                           (s_pkt_data_sel == 3'b111) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+7))-1:CC_DBUS_DWORD_WD_WITH_PAR*7] :
                                                        s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+8))-1:CC_DBUS_DWORD_WD_WITH_PAR*8];

assign s_inq_pkt_ep_strb = (s_pkt_data_sel == 3'b000) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+8))-1:STRBS_PER_DWORD*8] :
                           (s_pkt_data_sel == 3'b001) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+1))-1:STRBS_PER_DWORD*1] :
                           (s_pkt_data_sel == 3'b010) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2] :
                           (s_pkt_data_sel == 3'b011) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+3))-1:STRBS_PER_DWORD*3] :
                           (s_pkt_data_sel == 3'b100) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+4))-1:STRBS_PER_DWORD*4] :
                           (s_pkt_data_sel == 3'b101) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+5))-1:STRBS_PER_DWORD*5] :
                           (s_pkt_data_sel == 3'b110) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+6))-1:STRBS_PER_DWORD*6] :
                           (s_pkt_data_sel == 3'b111) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+7))-1:STRBS_PER_DWORD*7] :
                                                        s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+8))-1:STRBS_PER_DWORD*8];

assign s_inq_pkt_silentDrop_strb = (s_pkt_data_sel == 3'b000) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+8))-1:STRBS_PER_DWORD*8] :
                                   (s_pkt_data_sel == 3'b001) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+1))-1:STRBS_PER_DWORD*1] :
                                   (s_pkt_data_sel == 3'b010) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2] :
                                   (s_pkt_data_sel == 3'b011) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+3))-1:STRBS_PER_DWORD*3] :
                                   (s_pkt_data_sel == 3'b100) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+4))-1:STRBS_PER_DWORD*4] :
                                   (s_pkt_data_sel == 3'b101) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+5))-1:STRBS_PER_DWORD*5] :
                                   (s_pkt_data_sel == 3'b110) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+6))-1:STRBS_PER_DWORD*6] :
                                   (s_pkt_data_sel == 3'b111) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+7))-1:STRBS_PER_DWORD*7] :
                                                                s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+8))-1:STRBS_PER_DWORD*8];

assign s_inq_pkt_silentDropMasked_strb = (s_pkt_data_sel == 3'b000) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+8))-1:STRBS_PER_DWORD*8] :
                                         (s_pkt_data_sel == 3'b001) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+1))-1:STRBS_PER_DWORD*1] :
                                         (s_pkt_data_sel == 3'b010) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2] :
                                         (s_pkt_data_sel == 3'b011) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+3))-1:STRBS_PER_DWORD*3] :
                                         (s_pkt_data_sel == 3'b100) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+4))-1:STRBS_PER_DWORD*4] :
                                         (s_pkt_data_sel == 3'b101) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+5))-1:STRBS_PER_DWORD*5] :
                                         (s_pkt_data_sel == 3'b110) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+6))-1:STRBS_PER_DWORD*6] :
                                         (s_pkt_data_sel == 3'b111) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+7))-1:STRBS_PER_DWORD*7] :
                                                                      s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+8))-1:STRBS_PER_DWORD*8];

assign inq_pkt_strb     =  (s_pkt_data_sel == 3'b000) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+8))-1:STRBS_PER_DWORD*8] :
                           (s_pkt_data_sel == 3'b001) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+1))-1:STRBS_PER_DWORD*1] :
                           (s_pkt_data_sel == 3'b010) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2] :
                           (s_pkt_data_sel == 3'b011) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+3))-1:STRBS_PER_DWORD*3] :
                           (s_pkt_data_sel == 3'b100) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+4))-1:STRBS_PER_DWORD*4] :
                           (s_pkt_data_sel == 3'b101) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+5))-1:STRBS_PER_DWORD*5] :
                           (s_pkt_data_sel == 3'b110) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+6))-1:STRBS_PER_DWORD*6] :
                           (s_pkt_data_sel == 3'b111) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+7))-1:STRBS_PER_DWORD*7] :
                                                        s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+8))-1:STRBS_PER_DWORD*8];
end else if (NW == 4) begin : INQ_PKT_DATA_GEN_NW_4
assign inq_pkt_data     =  (s_pkt_data_sel == 3'b000) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+4))-1:CC_DBUS_DWORD_WD_WITH_PAR*4] :
                           (s_pkt_data_sel == 3'b001) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+1))-1:CC_DBUS_DWORD_WD_WITH_PAR*1] :
                           (s_pkt_data_sel == 3'b010) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+2))-1:CC_DBUS_DWORD_WD_WITH_PAR*2] :
                           (s_pkt_data_sel == 3'b011) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+3))-1:CC_DBUS_DWORD_WD_WITH_PAR*3] :
                                                        s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+4))-1:CC_DBUS_DWORD_WD_WITH_PAR*4];

assign s_inq_pkt_ep_strb = (s_pkt_data_sel == 3'b000) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+4))-1:STRBS_PER_DWORD*4] :
                           (s_pkt_data_sel == 3'b001) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+1))-1:STRBS_PER_DWORD*1] :
                           (s_pkt_data_sel == 3'b010) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2] :
                           (s_pkt_data_sel == 3'b011) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+3))-1:STRBS_PER_DWORD*3] :
                                                        s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+4))-1:STRBS_PER_DWORD*4];

assign s_inq_pkt_silentDrop_strb = (s_pkt_data_sel == 3'b000) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+4))-1:STRBS_PER_DWORD*4] :
                                   (s_pkt_data_sel == 3'b001) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+1))-1:STRBS_PER_DWORD*1] :
                                   (s_pkt_data_sel == 3'b010) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2] :
                                   (s_pkt_data_sel == 3'b011) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+3))-1:STRBS_PER_DWORD*3] :
                                                                s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+4))-1:STRBS_PER_DWORD*4];

assign s_inq_pkt_silentDropMasked_strb = (s_pkt_data_sel == 3'b000) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+4))-1:STRBS_PER_DWORD*4] :
                                         (s_pkt_data_sel == 3'b001) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+1))-1:STRBS_PER_DWORD*1] :
                                         (s_pkt_data_sel == 3'b010) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2] :
                                         (s_pkt_data_sel == 3'b011) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+3))-1:STRBS_PER_DWORD*3] :
                                                                      s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+4))-1:STRBS_PER_DWORD*4];

assign inq_pkt_strb     =  (s_pkt_data_sel == 3'b000) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+4))-1:STRBS_PER_DWORD*4] :
                           (s_pkt_data_sel == 3'b001) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+1))-1:STRBS_PER_DWORD*1] :
                           (s_pkt_data_sel == 3'b010) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2] :
                           (s_pkt_data_sel == 3'b011) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+3))-1:STRBS_PER_DWORD*3] :
                                                        s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+4))-1:STRBS_PER_DWORD*4];
end else if (NW == 2) begin : INQ_PKT_DATA_GEN_NW_2
assign inq_pkt_data     =  (s_pkt_data_sel == 3'b000) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+2))-1:CC_DBUS_DWORD_WD_WITH_PAR*2] :
                           (s_pkt_data_sel == 3'b001) ? s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+1))-1:CC_DBUS_DWORD_WD_WITH_PAR*1] :
                                                        s_pkt_data_mux[(CC_DBUS_DWORD_WD_WITH_PAR*(NW+2))-1:CC_DBUS_DWORD_WD_WITH_PAR*2];

assign s_inq_pkt_ep_strb = (s_pkt_data_sel == 3'b000) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2] :
                           (s_pkt_data_sel == 3'b001) ? s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+1))-1:STRBS_PER_DWORD*1] :
                                                        s_pkt_ep_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2];

assign s_inq_pkt_silentDrop_strb = (s_pkt_data_sel == 3'b000) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2] :
                                   (s_pkt_data_sel == 3'b001) ? s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+1))-1:STRBS_PER_DWORD*1] :
                                                                s_pkt_silentDrop_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2];

assign s_inq_pkt_silentDropMasked_strb = (s_pkt_data_sel == 3'b000) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2] :
                                         (s_pkt_data_sel == 3'b001) ? s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+1))-1:STRBS_PER_DWORD*1] :
                                                                      s_pkt_silentDropMasked_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2];

assign inq_pkt_strb     =  (s_pkt_data_sel == 3'b000) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2] :
                           (s_pkt_data_sel == 3'b001) ? s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+1))-1:STRBS_PER_DWORD*1] :
                                                        s_pkt_strb_mux[(STRBS_PER_DWORD*(NW+2))-1:STRBS_PER_DWORD*2];
end else begin : INQ_PKT_DATA_GEN_NW_1
assign inq_pkt_data      =   req_pkt_data;
assign s_inq_pkt_ep_strb =   req_pkt_ep_strb;
assign s_inq_pkt_silentDrop_strb =   req_pkt_silentDrop_strb;
assign s_inq_pkt_silentDropMasked_strb =   req_pkt_silentDrop_strb_masked;
assign inq_pkt_strb     =   req_pkt_strb;
end
endgenerate

assign w_inq_pkt_ep_strb = fn_margingBitsValids(s_inq_pkt_ep_strb, (state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT) ? s_tlp_dw_len : s_tlp_remaining_dw_len);
assign w_inq_pkt_silentDrop_strb = (inq_pkt_hv && !fifo_pkt_halt && (inq_pkt_byte_en[3:0] == 4'd0) && !s_pkt_msg) ? |(s_inq_pkt_silentDrop_strb & (({{CC_PRF_TLP_NUM_WSTRBS-1{1'b0}}, 1'b1} << {s_tlp_beat_dw_len, 2'b00})-'d1)) :
                                                                                                                    fn_margingBitsValids(s_inq_pkt_silentDropMasked_strb, (state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT) ? s_tlp_dw_len : s_tlp_remaining_dw_len);

assign s_pkt_ep_strb = (inq_pkt_dv && w_inq_pkt_ep_strb && !fifo_pkt_halt) || r_inq_pkt_ep_strb;

always @(posedge slv_aclk or negedge slv_aresetn) begin : s_wpoison_sticky_PROC
  if (!slv_aresetn) begin
    r_inq_pkt_ep_strb <= # TP 1'b0;
  end else if(inq_pkt_hv && !fifo_pkt_halt)begin
    r_inq_pkt_ep_strb <= # TP 1'b0;
  end else begin
    r_inq_pkt_ep_strb <= # TP s_pkt_ep_strb;
  end
end

assign s_pkt_silentDrop_strb = (inq_pkt_dv && w_inq_pkt_silentDrop_strb && !fifo_pkt_halt) || r_inq_pkt_silentDrop_strb;

always @(posedge slv_aclk or negedge slv_aresetn) begin : s_wsilentDrop_sticky_PROC
  if (!slv_aresetn) begin
    r_inq_pkt_silentDrop_strb <= # TP 1'b0;
  end else if(inq_pkt_hv && !fifo_pkt_halt)begin
    r_inq_pkt_silentDrop_strb <= # TP 1'b0;
  end else begin
    r_inq_pkt_silentDrop_strb <= # TP s_pkt_silentDrop_strb;
  end
end

// FSM sequential process
// ---------------------------------------------------------------------------------------------------------------------
always@(posedge slv_aclk or negedge slv_aresetn)
  begin: STATE_SEQ_PROC
    if (!slv_aresetn) begin
      state <= #TP S_READY;
    end else begin
      state <= #TP next_state;
    end
  end
// FSM combinational process
// ---------------------------------------------------------------------------------------------------------------------


always@(*)
  begin: IB_WR_STATE_COMB_PROC
    next_state = state;
    if (!fifo_pkt_halt) begin
      case(state)
        S_READY :
            if (req_pkt_hv) begin
              if (s_decomposition_required)begin                                                         // if decomposition is required
                if(s_pkt_dw_to_next_max_payload <= NW)begin                                        //   and the number of DW to the decomposition boundary (master MTU) is less than the data bus width (meaning the first TLP is only 1 beat long)
                  if(({{13-CC_SLV_MTU_PW{1'b0}}, s_pkt_dw_len} - s_pkt_dw_to_next_max_payload) <= s_max_payload_dw_len) begin  //     and the lenght of the second decomposed TLP is less than master MTU (meaning there are only 2 decomposed TLPs)
                    if(({{13-CC_SLV_MTU_PW{1'b0}}, s_pkt_dw_len} - s_pkt_dw_to_next_max_payload) <= NW) begin
                      if(req_pkt_eot) begin
                        next_state = S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT;
                      end else begin
                        next_state = S_WR_DCMP_LAST_TLP_SINGLE_BEAT;
                      end
                    end else begin
                      next_state = S_WR_DCMP_LAST_TLP_FIRST_BEAT;                                        //       then the next beat is the first beat of the last TLP
                    end
                  end else begin
                    next_state = S_WR_DCMP_INTMD_TLP_FIRST_BEAT;
                  end
                end else begin
                  if(s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) <= NW) begin
                    next_state = S_WR_DCMP_FIRST_TLP_LAST_BEAT;
                  end else begin
                    next_state = S_WR_DCMP_FIRST_TLP_INTMD_BEAT;
                  end
                end
              end else if (!req_pkt_eot) begin
                next_state = S_WR_NODCMP;
              end else begin
                next_state = S_READY;
              end
            end
        S_WR_NODCMP :
            if (req_pkt_eot) begin
              next_state = S_READY;
            end else begin
              next_state = S_WR_NODCMP;
            end
        S_WR_DCMP_FIRST_TLP_INTMD_BEAT :
            if(req_pkt_eot) begin                                                                                                                     // if an eot is received at this stage it means trailing null writes; because this is the first TLP and we're not at the end yet there's no chance of misaligned data so
              next_state = S_READY;                                                                                                                   //   return to S_READY state to start processing a new PKT
            end else if(req_pkt_dv) begin                                                                                                             // else if data is received
              if(s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) <= NW) begin                                                                  //   check how much data is left to be sent after this beat; if less than the size of the data bus then
                next_state = S_WR_DCMP_FIRST_TLP_LAST_BEAT;                                                                                           //     go to S_WR_DCMP_FIRST_TLP_LAST_BEAT to issue the last beat of the current TLP
              end else begin                                                                                                                          //   else (there's more than one beat left in this TLP)
                next_state = S_WR_DCMP_FIRST_TLP_INTMD_BEAT;                                                                                          //     stay on S_WR_DCMP_FIRST_TLP_INTMD_BEAT and continue processing the current TLP
              end
            end
        S_WR_DCMP_FIRST_TLP_LAST_BEAT :
            if(req_pkt_eot) begin                                                                                                                     // if an eot is received at this stage it means trailing null writes; this is the first TLP but because we're at the end there's a chance of misaligned data so
        if(req_pkt_dv) begin                                                                                                                    //   if data is also received
                if(s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) > 0) begin                                                                  //     check if there is any data left to be sent after this beat; if there is
                  next_state = S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT;                                                                                       //       go to S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT state to send an extra TLP with the remaining data
                end else begin                                                                                                                        //     else (no data left to send)
                  next_state = S_READY;                                                                                                               //       return to S_READY state to start processing a new PKT
                end
              end else begin                                                                                                                          //   else (no data is received) there's no chance of misaligned data so
                next_state = S_READY;                                                                                                                 //     return to S_READY state to start processing a new PKT
              end
            end else if(req_pkt_dv) begin                                                                                                             // else (no eot received) if data is received
              if({{13-CC_SLV_MTU_PW{1'b0}}, s_pkt_dw_len} - ({{13-CC_SLV_MTU_PW{1'b0}}, r_pkt_sent_dw_len} + {{(CC_SLV_MTU_PW-FIFO_BYTE_LEN_WD){1'b0}},s_tlp_dw_len}) <= s_max_payload_dw_len) begin          //   check if the amount of data left in the packet after this TLP is less than max payload; if it is then
                if((s_pkt_dw_len - (r_pkt_sent_dw_len + {{(CC_SLV_MTU_PW-FIFO_BYTE_LEN_WD){1'b0}},s_tlp_dw_len})) <= NW) begin                        //     check if the amount of data left in the packet is smaller than the data bus; if it is then
                  next_state = S_WR_DCMP_LAST_TLP_SINGLE_BEAT;                                                                                        //       go to S_WR_DCMP_LAST_TLP_SINGLE_BEAT to issue a final TLP with only one beat
                end else begin                                                                                                                        //     else (data left in TLP is greater than the data bus) then
                  next_state = S_WR_DCMP_LAST_TLP_FIRST_BEAT;                                                                                         //       go to S_WR_DCMP_LAST_TLP_FIRST_BEAT to issue the first beat of the last TLP
                end
              end else begin                                                                                                                          //   else (data left in packet is greater than max payload) then
                next_state = S_WR_DCMP_INTMD_TLP_FIRST_BEAT;                                                                                          //     go to S_WR_DCMP_INTMD_TLP_FIRST_BEAT to issue the first beat of intermediate TLP
              end
            end
        S_WR_DCMP_INTMD_TLP_FIRST_BEAT:
            if(req_pkt_eot) begin                                                                                                                     // if an eot is received at this stage it means trailing null writes; this is an intermediate TLP so there's a chance of misaligned data so
              if(s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) > 0) begin                                                                    //   check if there is any data left to be sent after this beat; if there is
                next_state = S_WR_DCMP_LAST_TLP_EXTRA_BEAT;                                                                                           //     go to S_WR_DCMP_LAST_TLP_EXTRA_BEAT state to send an extra beat with the remaining data
              end else begin                                                                                                                          //   else (no data left to send)
                next_state = S_READY;                                                                                                                 //     return to S_READY state to start processing a new PKT
              end
            end else if(req_pkt_dv) begin                                                                                                             // else (no eot received) if data is received
              if(s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) <= NW) begin                                                                  //   check if the amount of data left in the TLP is smaller than the data bus; if it is then
                next_state = S_WR_DCMP_INTMD_TLP_LAST_BEAT;                                                                                           //     go to S_WR_DCMP_INTMD_TLP_LAST_BEAT to send the last beat of the current TLP
              end else begin                                                                                                                          //   else (data left in TLP is greater than the data bus) then
                next_state = S_WR_DCMP_INTMD_TLP_INTMD_BEAT;                                                                                          //     go to S_WR_DCMP_INTMD_TLP_INTMD_BEAT and keep processing the current TLP
              end
            end
        S_WR_DCMP_INTMD_TLP_INTMD_BEAT:
            if(req_pkt_eot) begin                                                                                                                     // if an eot is received at this stage it means trailing null writes; this is an intermediate TLP so there's a chance of misaligned data so
              if(s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) > 0) begin                                                                    //   check if there is any data left to be sent after this beat; if there is
                next_state = S_WR_DCMP_LAST_TLP_EXTRA_BEAT;                                                                                           //     go to S_WR_DCMP_LAST_TLP_EXTRA_BEAT state to send an extra beat with the remaining data
              end else begin                                                                                                                          //   else (no data left to send)
                next_state = S_READY;                                                                                                                 //     return to S_READY state to start processing a new PKT
              end
            end else if(req_pkt_dv) begin                                                                                                             // else (no eot received) if data is received
              if(s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) <= NW) begin                                                                  //   check if the amount of data left in the TLP is smaller than the data bus; if it is then
                next_state = S_WR_DCMP_INTMD_TLP_LAST_BEAT;                                                                                           //     go to S_WR_DCMP_INTMD_TLP_LAST_BEAT to send the last beat of the current TLP
              end else begin                                                                                                                          //   else (data left in TLP is greater than the data bus) then
                next_state = S_WR_DCMP_INTMD_TLP_INTMD_BEAT;                                                                                          //     go to S_WR_DCMP_INTMD_TLP_INTMD_BEAT and keep processing the current TLP
              end
            end
        S_WR_DCMP_INTMD_TLP_LAST_BEAT:
            if(req_pkt_eot) begin                                                                                                                     // if an eot is received at this stage it means trailing null writes; this is an intermediate TLP so there's a chance of misaligned data so
              if(s_pkt_dw_len - (r_pkt_sent_dw_len + {{(CC_SLV_MTU_PW-FIFO_BYTE_LEN_WD){1'b0}},s_tlp_dw_len}) > 0) begin                              //   check if there is any data left after this TLP; if there is then
                next_state = S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT;                                                                                         //     send an extra TLP with a single beat
              end else if(s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) > 0) begin                                                           //   else (no more data after this TLP) check if there is any data left to be sent after this beat; if there is
                next_state = S_WR_DCMP_LAST_TLP_EXTRA_BEAT;                                                                                           //     go to S_WR_DCMP_LAST_TLP_EXTRA_BEAT state to send an extra beat with the remaining data
              end else begin                                                                                                                          //   else (no data left to send)
                next_state = S_READY;                                                                                                                 //     return to S_READY state to start processing a new packet
              end
            end else if(req_pkt_dv) begin                                                                                                             // else (no eot received)
              if({{13-CC_SLV_MTU_PW{1'b0}}, s_pkt_dw_len} - ({{13-CC_SLV_MTU_PW{1'b0}}, r_pkt_sent_dw_len} + {{(CC_SLV_MTU_PW-FIFO_BYTE_LEN_WD){1'b0}},s_tlp_dw_len}) <= s_max_payload_dw_len) begin          //   check if the amount of data left in the packet after this TLP is less than max payload; if it is then
                if((s_pkt_dw_len - (r_pkt_sent_dw_len + {{(CC_SLV_MTU_PW-FIFO_BYTE_LEN_WD){1'b0}},s_tlp_dw_len})) <= NW) begin                        //     check if the amount of data left in the packet is smaller than the data bus; if it is then
                  next_state = S_WR_DCMP_LAST_TLP_SINGLE_BEAT;                                                                                        //       go to S_WR_DCMP_LAST_TLP_SINGLE_BEAT to issue a final TLP with only one beat
                end else begin                                                                                                                        //     else (data left in TLP is greater than the data bus) then
                  next_state = S_WR_DCMP_LAST_TLP_FIRST_BEAT;                                                                                         //       go to S_WR_DCMP_LAST_TLP_FIRST_BEAT to issue the first beat of the last TLP
                end
              end else begin                                                                                                                          //   else (data left in packet is greater than max payload) then
                next_state = S_WR_DCMP_INTMD_TLP_FIRST_BEAT;                                                                                          //     go to S_WR_DCMP_INTMD_TLP_FIRST_BEAT to issue the first beat of intermediate TLP
              end
            end
        S_WR_DCMP_LAST_TLP_FIRST_BEAT:
            if(req_pkt_eot) begin                                                                                                                     // if an eot is received at this stage it means trailing null writes; this is an intermediate TLP so there's a chance of misaligned data so
              if(s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) > 0) begin                                                                    //   check if there is any data left to be sent after this beat; if there is
                next_state = S_WR_DCMP_LAST_TLP_EXTRA_BEAT;                                                                                           //     go to S_WR_DCMP_LAST_TLP_EXTRA_BEAT state to send an extra beat with the remaining data
              end else begin                                                                                                                          //   else (no data left to send)
                next_state = S_READY;                                                                                                                 //     return to S_READY state to start processing a new PKT
              end
            end else if(req_pkt_dv) begin                                                                                                             // else (no eot received) if data is received
              if(s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) <= NW) begin                                                                  //   check if the amount of data left in the TLP is smaller than the data bus; if it is then
                next_state = S_WR_DCMP_LAST_TLP_LAST_BEAT;                                                                                            //     go to S_WR_DCMP_LAST_TLP_LAST_BEAT to send the last beat of the current TLP
              end else begin                                                                                                                          //   else (data left in TLP is greater than the data bus) then
                next_state = S_WR_DCMP_LAST_TLP_INTMD_BEAT;                                                                                           //     go to S_WR_DCMP_LAST_TLP_INTMD_BEAT and keep processing the current TLP
              end
            end
        S_WR_DCMP_LAST_TLP_INTMD_BEAT:
            if(req_pkt_eot) begin                                                                                                                     // if an eot is received at this stage it means trailing null writes; this is an intermediate TLP so there's a chance of misaligned data so
              if(s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) > 0) begin                                                                    //   check if there is any data left to be sent after this beat; if there is
                next_state = S_WR_DCMP_LAST_TLP_EXTRA_BEAT;                                                                                           //     go to S_WR_DCMP_LAST_TLP_EXTRA_BEAT state to send an extra beat with the remaining data
              end else begin                                                                                                                          //   else (no data left to send)
                next_state = S_READY;                                                                                                                 //     return to S_READY state to start processing a new PKT
              end
            end else if(req_pkt_dv) begin
              if(s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) <= NW) begin                                                                  //   check if the amount of data left in the TLP is smaller than the data bus; if it is then
                next_state = S_WR_DCMP_LAST_TLP_LAST_BEAT;                                                                                            //     go to S_WR_DCMP_LAST_TLP_LAST_BEAT to send the last beat of the current TLP
              end else begin                                                                                                                          //   else (data left in TLP is greater than the data bus) then
                next_state = S_WR_DCMP_LAST_TLP_INTMD_BEAT;                                                                                           //     go to S_WR_DCMP_LAST_TLP_INTMD_BEAT and keep processing the current TLP
              end
            end
        S_WR_DCMP_LAST_TLP_LAST_BEAT:
            if(req_pkt_dv || req_pkt_eot) begin
              next_state = S_READY;
            end
        S_WR_DCMP_LAST_TLP_SINGLE_BEAT:
            if(req_pkt_dv || req_pkt_eot) begin
              next_state = S_READY;
            end
        S_WR_DCMP_LAST_TLP_EXTRA_BEAT:
              next_state = S_READY;
        S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT:
              next_state = S_READY;
        default:
              next_state = state;
      endcase
    end else begin
      next_state = state;
    end
  end
//--------------------------------------------------------------------------------------------------------------------

// inq_pkt_halt
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_halt = s_pkt_halt;
// inq_pkt_hv
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_hv =
 ( state == S_READY                          ) && ( req_pkt_eot || ( req_pkt_dv && ( s_tlp_dw_len <= NW ) ) ) ||
 ( state == S_WR_NODCMP                      ) &&   req_pkt_eot ||
 ( state == S_WR_DCMP_FIRST_TLP_INTMD_BEAT   ) && ( req_pkt_eot && (s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) == 0) ) ||
 ( state == S_WR_DCMP_FIRST_TLP_LAST_BEAT    ) && ( req_pkt_dv || ( req_pkt_eot && !req_pkt_dv && (s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) == 0) ) ) ||
 ( state == S_WR_DCMP_INTMD_TLP_FIRST_BEAT   ) && ( req_pkt_eot && (s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) == 0) ) ||
 ( state == S_WR_DCMP_INTMD_TLP_INTMD_BEAT   ) && ( req_pkt_eot && (s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) == 0) ) ||
 ( state == S_WR_DCMP_INTMD_TLP_LAST_BEAT    ) && ( req_pkt_dv || ( req_pkt_eot && !req_pkt_dv && (s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) == 0) ) ) ||
 ( state == S_WR_DCMP_LAST_TLP_FIRST_BEAT    ) && ( req_pkt_eot && (s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) == 0) ) ||
 ( state == S_WR_DCMP_LAST_TLP_INTMD_BEAT    ) && ( req_pkt_eot && (s_tlp_dw_len - (s_tlp_sent_dw_len + s_tlp_beat_dw_len) == 0) ) ||
 ( state == S_WR_DCMP_LAST_TLP_LAST_BEAT     ) && ( req_pkt_eot || req_pkt_dv ) ||
 ( state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT   ) && ( req_pkt_eot || req_pkt_dv ) ||
 ( state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT    ) ||
 ( state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT  );


// inq_pkt_dv
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_dv   = (
 ( state == S_READY                          ) &&   req_pkt_dv ||
 ( state == S_WR_NODCMP                      ) &&   req_pkt_dv ||
 ( state == S_WR_DCMP_FIRST_TLP_INTMD_BEAT   ) && ( req_pkt_dv || ( req_pkt_eot && (s_tlp_beat_dw_len > 0 ) ) ) ||
 ( state == S_WR_DCMP_FIRST_TLP_LAST_BEAT    ) && ( req_pkt_dv || ( req_pkt_eot && (s_tlp_beat_dw_len > 0 ) ) ) ||
 ( state == S_WR_DCMP_INTMD_TLP_FIRST_BEAT   ) && ( req_pkt_dv || ( req_pkt_eot && (s_tlp_beat_dw_len > 0 ) ) ) ||
 ( state == S_WR_DCMP_INTMD_TLP_INTMD_BEAT   ) && ( req_pkt_dv || ( req_pkt_eot && (s_tlp_beat_dw_len > 0 ) ) ) ||
 ( state == S_WR_DCMP_INTMD_TLP_LAST_BEAT    ) && ( req_pkt_dv || ( req_pkt_eot && (s_tlp_beat_dw_len > 0 ) ) ) ||
 ( state == S_WR_DCMP_LAST_TLP_FIRST_BEAT    ) && ( req_pkt_dv || ( req_pkt_eot && (s_tlp_beat_dw_len > 0 ) ) ) ||
 ( state == S_WR_DCMP_LAST_TLP_INTMD_BEAT    ) && ( req_pkt_dv || ( req_pkt_eot && (s_tlp_beat_dw_len > 0 ) ) ) ||
 ( state == S_WR_DCMP_LAST_TLP_LAST_BEAT     ) && ( req_pkt_dv || ( req_pkt_eot && (s_tlp_beat_dw_len > 0 ) ) ) ||
 ( state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT   ) && ( req_pkt_dv || ( req_pkt_eot && (s_tlp_beat_dw_len > 0 ) ) ) ||
 ( state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT    ) ||
 ( state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT  ) )
 && !s_wrap_null_wr
 ;

// inq_pkt_eot
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_eot = inq_pkt_hv;


// inq_pkt_byte_len
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_byte_len = {s_tlp_dw_len,2'b00};


// inq_pkt_addr
// ---------------------------------------------------------------------------------------------------------------------

// Adding parity bits to output address
// ---------------------------------------------------------------------------------------------------------------------
always @( * )
begin : OUT_ADDR_PAR_CAL
integer i;
    s_calc_inq_addr_par = 0;
    for (i=0; i<ADDR_PAR_WIDTH; i=i+1) begin
        s_calc_inq_addr_par[i] = CX_RAS_PARITY_MODE ? ~(^Vecget_addr(s_tlp_addr_nopar, i)) : ^Vecget_addr(s_tlp_addr_nopar, i);
    end
end

assign inq_pkt_addr = add_addr_par(s_tlp_addr_nopar, s_calc_inq_addr_par);


// inq_pkt_byte_en
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_byte_en[3:0] = s_pkt_msg                                                ? s_pkt_byte_en[3:0] :
                              (inq_pkt_byte_len == {CC_SLV_MTU_PW{1'b0}})              ? 4'b0000 :
                              s_pkt_first_tlp                                          ? s_pkt_byte_en[3:0] :
                              (inq_pkt_byte_len == {{(CC_SLV_MTU_PW-3){1'b0}},3'b100}) ? s_pkt_byte_en[7:4] :
                                                                       4'b1111;
assign inq_pkt_byte_en[7:4] = s_pkt_msg                                                ? s_pkt_byte_en[7:4] :
                              (inq_pkt_byte_len <= {{(CC_SLV_MTU_PW-3){1'b0}},3'b100}) ? 4'b0000 :
                              s_decomposition_required                                 ? 4'b1111 :
                                                                       s_pkt_byte_en[7:4];


// inq_pkt_last_tlp
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_last_tlp = s_pkt_last_tlp && !s_pkt_first_wrp_split_xact;

// inq_pkt_null
// ---------------------------------------------------------------------------------------------------------------------
assign w_first_tlp_w_data = (inq_pkt_byte_en != 8'h00) && !s_pkt_msg && s_pkt_first_wrp_split_xact && s_pkt_wrp_valid;

always@(posedge slv_aclk or negedge slv_aresetn) begin : s_first_tlp_with_data_sticky_PROC
    if (!slv_aresetn) begin
      r_first_tlp_w_data <= #TP 1'b0;
    end else if(w_first_tlp_w_data) begin
      r_first_tlp_w_data <= #TP 1'b1;
    end else if(inq_pkt_hv && inq_pkt_last_tlp) begin
      r_first_tlp_w_data <= #TP 1'b0;
    end else begin
      r_first_tlp_w_data <= #TP s_first_tlp_w_data;
    end
  end

assign s_first_tlp_w_data = r_first_tlp_w_data || w_first_tlp_w_data;

assign s_wrap_null_wr       = inq_pkt_hv && (inq_pkt_byte_en == 8'h00) && !s_pkt_msg && s_pkt_wrp_valid && (s_pkt_first_wrp_split_xact || (!s_pkt_first_wrp_split_xact && s_first_tlp_w_data));

assign inq_pkt_null         = inq_pkt_eot && inq_pkt_hv && (inq_pkt_byte_len == 8'h00) && !s_pkt_msg || s_wrap_null_wr;

assign s_pkt_no_data        = (
                              ((inq_pkt_byte_len == {{FIFO_BYTE_LEN_WD-3{1'd0}}, 3'h4}) && (inq_pkt_byte_en == 8'h00) && (inq_pkt_fmt[1] == 1'b1) && (inq_pkt_type[4:0] == 5'h00)) ||
                              ((inq_pkt_fmt == 2'b01) && (inq_pkt_type[4] == 1'b1)) ||
                              ((inq_pkt_fmt == 2'b00) && (inq_pkt_type[4:1] == 4'b0010))
                              );

// inq_pkt_*
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_prfx         = s_pkt_prfx;
assign inq_pkt_p_tag        = s_pkt_p_tag;
assign inq_pkt_th           = s_pkt_th;
assign inq_pkt_ph           = s_pkt_ph;
assign inq_pkt_st           = s_pkt_st;
assign inq_pkt_atu_bypass   = s_pkt_atu_bypass;
assign inq_pkt_dst_segment  = s_pkt_dst_segment;
assign inq_pkt_ats          = s_pkt_ats;
assign inq_pkt_nw           = s_pkt_nw;
assign inq_pkt_axi_id       = s_pkt_axi_id;
assign inq_pkt_cpl_stat     = s_pkt_cpl_stat;
assign inq_pkt_tc           = s_pkt_tc;
assign inq_pkt_ep           = s_pkt_ep_strb || (s_pkt_ep && !s_pkt_no_data);
assign inq_pkt_silentDrop   = s_pkt_silentDrop_strb;
assign inq_pkt_attr         = s_pkt_attr;
assign inq_pkt_fmt          = s_pkt_fmt;
assign inq_pkt_type         = s_pkt_type;



// Auxiliary functions
// ---------------------------------------------------------------------------------------------------------------------
function automatic fn_margingBitsValids;
  input [CC_PRF_TLP_NUM_WSTRBS-1:0] bitsValids_strb;
  input [FIFO_BYTE_LEN_WD-3:0] dw_len;
  integer i;
  logic bitsValids;
  begin
    bitsValids = 0;
    if({dw_len,2'd0} >= CC_PRF_TLP_NUM_WSTRBS) begin
      bitsValids = | bitsValids_strb;
    end else begin
      for (i=0; i<CC_PRF_TLP_NUM_WSTRBS; i=i+1)  begin
        if(i < {dw_len,2'd0}) begin
          bitsValids = bitsValids | bitsValids_strb[i];
        end
      end
    end
    fn_margingBitsValids = bitsValids;
  end
endfunction

function automatic [2:0] get_cfg_setting;

input [CX_NFUNC-1:0][2:0] cfg_bus;
input [CX_NFUNC_LOG2-1:0] func_num;

begin
    get_cfg_setting = 0;
    if(func_num < CX_NFUNC) begin
        // func_num can select indices out of the range of cfg_bus when NF is
        // not a power of 2. But the < NF check protects agains this stimulus
        get_cfg_setting = cfg_bus[func_num];
    end
end
endfunction // get_cfg_setting
function automatic [CC_SLV_BUS_ADDR_WIDTH-1 :0] add_addr_par;
input [ADDR_WD_WO_PAR -1 : 0]   in_addr;
input [ADDR_PAR_WIDTH -1:0]   in_par;
integer i, j;
begin
    add_addr_par ={CC_SLV_BUS_ADDR_WIDTH{1'b0}};
    for (i=0; i<ADDR_PAR_WIDTH; i=i+1) begin
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
        add_addr_par[i*CX_RAS_PROT_RANGE +j+i] = in_addr[i*CX_RAS_PROT_RANGE +j];
       end
        add_addr_par[(i+1)*CX_RAS_PROT_RANGE + i] = in_par[i];
    end
end
endfunction // add_addr_par

function automatic [CX_RAS_PROT_RANGE -1:0] Vecget_addr;
input [ADDR_WD_WO_PAR -1:0]   vector;
input integer      index;

integer i;
begin
    Vecget_addr = 0;
    for (i=CX_RAS_PROT_RANGE -1; i>=0; i=i-1) begin
        Vecget_addr[i] = vector[index*CX_RAS_PROT_RANGE +i];
    end
end
endfunction // Vecget_addr


`ifndef SYNTHESIS
//VCS coverage off
wire    [32*8-1:0]         STATE;
assign  STATE   =  (state == S_READY                         ) ? "READY"  :
                   (state == S_WR_NODCMP                     ) ? "WR_NODCMP" :
                   (state == S_WR_DCMP_FIRST_TLP_INTMD_BEAT  ) ? "WR_DCMP_FIRST_TLP_INTMD_BEAT" :
                   (state == S_WR_DCMP_FIRST_TLP_LAST_BEAT   ) ? "WR_DCMP_FIRST_TLP_LAST_BEAT"  :
                   (state == S_WR_DCMP_INTMD_TLP_FIRST_BEAT  ) ? "WR_DCMP_INTMD_TLP_FIRST_BEAT" :
                   (state == S_WR_DCMP_INTMD_TLP_INTMD_BEAT  ) ? "WR_DCMP_INTMD_TLP_INTMD_BEAT" :
                   (state == S_WR_DCMP_INTMD_TLP_LAST_BEAT   ) ? "WR_DCMP_INTMD_TLP_LAST_BEAT"  :
                   (state == S_WR_DCMP_LAST_TLP_FIRST_BEAT   ) ? "WR_DCMP_LAST_TLP_FIRST_BEAT"  :
                   (state == S_WR_DCMP_LAST_TLP_INTMD_BEAT   ) ? "WR_DCMP_LAST_TLP_INTMD_BEAT"  :
                   (state == S_WR_DCMP_LAST_TLP_LAST_BEAT    ) ? "WR_DCMP_LAST_TLP_LAST_BEAT"   :
                   (state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT  ) ? "WR_DCMP_LAST_TLP_SINGLE_BEAT" :
                   (state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT   ) ? "WR_DCMP_LAST_TLP_EXTRA_BEAT"  :
                   (state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT ) ? "WR_DCMP_EXTRA_TLP_SINGLE_BEAT":
                                                              "";

//VCS coverage on
`endif // SYNTHESIS

endmodule

