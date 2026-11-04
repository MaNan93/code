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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_bridge_ob_np_dcmp_inq.sv#12 $
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

 module DWC_pcie_bridge_ob_np_dcmp_inq
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 (

    slv_aclk,
    slv_aresetn,

    // Configuration interface
    cfg_max_rd_req_size,

    // Request packet interface
    inq_pkt_halt,
    req_pkt_hv,
    req_pkt_dv,
    req_pkt_eot,
    req_pkt_bad_eot,
    req_pkt_tlp_prfx,
    req_pkt_th,
    req_pkt_ph,
    req_pkt_st,
    req_pkt_atu_bypass,
    req_pkt_dst_segment,
    req_pkt_ats,
    req_pkt_nw,
    req_pkt_first_wrp_split_xact,
    req_pkt_wrp_valid,
    req_pkt_snp,
    req_pkt_cpl_stat,
    req_pkt_byte_len,
    req_pkt_in_tag,
    req_pkt_axi_id,
    req_pkt_tc,
    req_pkt_ep,
    req_pkt_attr,
    req_pkt_byte_en,
    req_pkt_fmt,
    req_pkt_type,
    req_pkt_addr,
    req_pkt_data,

    fifo_pkt_halt,
    inq_pkt_hv,
    inq_pkt_dv,
    inq_pkt_eot,
    inq_pkt_bad_eot,
    inq_pkt_tlp_prfx,
    inq_pkt_th,
    inq_pkt_ph,
    inq_pkt_st,
    inq_pkt_atu_bypass,
    inq_pkt_dst_segment,
    inq_pkt_ats,
    inq_pkt_nw,
    inq_pkt_first_wrp_split_xact,
    inq_pkt_wrp_valid,
    inq_pkt_last_tlp,
    inq_pkt_dcmp_rd,
    inq_pkt_serial_req,
    inq_pkt_req_byte_len,
    inq_pkt_cpl_stat,
    inq_pkt_byte_len,
    inq_pkt_in_tag,
    inq_pkt_axi_id,
    inq_pkt_tc,
    inq_pkt_ep,
    inq_pkt_attr,
    inq_pkt_byte_en,
    inq_pkt_fmt,
    inq_pkt_type,
    inq_pkt_addr,
    inq_pkt_data

    // Address parity error detection
   ,dcmp_addr_parerr
   ,npdcmp_ad_ras_dp_err_log
   ,ras_dp_err_inj_slv_aclk
   );

parameter TP                                 = `TP;

//
// ---------------------------------------------------------------------------------------------------------------------
localparam CC_SLV_BUS_ADDR_WIDTH             = `CC_SLV_BUS_ADDR_WIDTH;
localparam CC_SLV_BUS_DATA_WIDTH             = `CC_SLV_BUS_DATA_WIDTH;
localparam SLV_BUS_NPDATA_WIDTH              = `CC_SLV_BUS_NPDATA_WIDTH;
localparam SLV_BUS_NPDATA_WIDTH_NP           = `CC_SLV_BUS_NPDATA_WIDTH_NP;
localparam CC_SLV_BUS_ID_WIDTH               = `CC_SLV_BUS_ID_WIDTH;
localparam CC_SLV_RD_REQ_SIZE_PW             = `CC_SLV_RD_REQ_SIZE_PW  ;
localparam CC_CORE_DATA_BUS_WD               = `CC_CORE_DATA_BUS_WD;
localparam CC_CORE_ADDR_BUS_WD               = `CC_CORE_ADDR_BUS_WD;
localparam CC_MAX_SLV_TAG_PW                 = `CC_MAX_SLV_TAG_PW;
localparam CX_LUT_PTR_WIDTH                  = `CX_LUT_PTR_WIDTH ;
localparam CX_MAX_TAG                        = `CX_MAX_TAG;
localparam CX_NFUNC                          = `CX_NFUNC;
localparam CX_NFUNC_WD                       = `CX_NFUNC_WD;
localparam CX_NFUNC_LOG2                     = `CX_NFUNC > 1 ? $clog2(CX_NFUNC) : 1;
localparam CX_NVFUNC_WD                      = `CX_NVFUNC_WD;
localparam DC_CPL_STATUS_WD                  = `DC_CPL_STATUS_WD;
localparam CC_SLV_MTU_PW                     = `CC_SLV_MTU_PW;
localparam FIFO_BYTE_LEN_WD                  = `CC_SLV_MTU_PW < (`CC_SLV_RD_REQ_SIZE_PW+1) ? `CC_SLV_MTU_PW : `CC_SLV_RD_REQ_SIZE_PW;
localparam CX_RAS_PROT_RANGE                 = `CX_RAS_PROT_RANGE;
localparam ADDR_WD_WO_PAR                    = (`CC_SLV_BUS_ADDR_WIDTH >=64) ? 64:32;
localparam ADDR_PAR_WIDTH                    = `CC_SLV_BUS_ADDR_WIDTH - ADDR_WD_WO_PAR;
localparam NUM_DATA_PAR_BLOCKS               = ADDR_WD_WO_PAR / `CX_RAS_PROT_RANGE;
localparam DCMP_PREFIX_WD                    = (32*`CX_NPRFX)+ `CX_PRFX_PAR_WD;
localparam ATTR_WD                           = 3;
localparam CX_RAS_PARITY_MODE                = `CX_RAS_PARITY_MODE;

// FSM state definition
// ---------------------------------------------------------------------------------------------------------------------
localparam S_READY                           = 1'b0;
localparam S_RD_DCMP                         = 1'b1;


input  wire                                  slv_aclk;
input  wire                                  slv_aresetn;

// Configuration interface
// ---------------------------------------------------------------------------------------------------------------------
input  wire [(3*CX_NFUNC)-1:0]               cfg_max_rd_req_size;

// Request packet interface
output wire                                  inq_pkt_halt;
input  wire                                  req_pkt_hv;
input  wire                                  req_pkt_dv;
input  wire                                  req_pkt_eot;
input  wire                                  req_pkt_bad_eot;
input  wire [DCMP_PREFIX_WD-1:0]             req_pkt_tlp_prfx;
input  wire                                  req_pkt_th;
input  wire [1:0]                            req_pkt_ph;
input  wire [7:0]                            req_pkt_st;
input  wire                                  req_pkt_atu_bypass;
input  wire [8:0]                            req_pkt_dst_segment;
input  wire [1:0]                            req_pkt_ats;
input  wire                                  req_pkt_nw;
input  wire                                  req_pkt_first_wrp_split_xact;
input  wire                                  req_pkt_wrp_valid;
input  wire                                  req_pkt_snp;
input  wire [DC_CPL_STATUS_WD-1:0]           req_pkt_cpl_stat;
input  wire [CC_SLV_MTU_PW-1:0]              req_pkt_byte_len;
input  wire [CC_MAX_SLV_TAG_PW-1:0]          req_pkt_in_tag;
input  wire [CC_SLV_BUS_ID_WIDTH:0]          req_pkt_axi_id;
input  wire [2:0]                            req_pkt_tc;
input  wire                                  req_pkt_ep;
input  wire [ATTR_WD-1:0]                    req_pkt_attr;
input  wire [7:0]                            req_pkt_byte_en;
input  wire [1:0]                            req_pkt_fmt;
input  wire [4:0]                            req_pkt_type;

input  wire [CC_SLV_BUS_ADDR_WIDTH-1:0]      req_pkt_addr;
input  wire [SLV_BUS_NPDATA_WIDTH-1:0]       req_pkt_data;

input  wire                                  fifo_pkt_halt;
output wire                                  inq_pkt_hv;
output wire                                  inq_pkt_dv;
output wire                                  inq_pkt_eot;
output wire                                  inq_pkt_bad_eot;
output wire [DCMP_PREFIX_WD-1:0]             inq_pkt_tlp_prfx;
output wire                                  inq_pkt_th;
output wire [1:0]                            inq_pkt_ph;
output wire [7:0]                            inq_pkt_st;
output wire                                  inq_pkt_atu_bypass;
output wire [8:0]                            inq_pkt_dst_segment;
output wire [1:0]                            inq_pkt_ats;
output wire                                  inq_pkt_nw;
output wire                                  inq_pkt_first_wrp_split_xact;
output wire                                  inq_pkt_wrp_valid;
output wire                                  inq_pkt_last_tlp;
output wire                                  inq_pkt_dcmp_rd;
output wire                                  inq_pkt_serial_req;
output wire [CC_SLV_MTU_PW-1:0]              inq_pkt_req_byte_len;
output wire [DC_CPL_STATUS_WD-1:0]           inq_pkt_cpl_stat;
output wire [FIFO_BYTE_LEN_WD-1:0]           inq_pkt_byte_len;
output wire [CC_MAX_SLV_TAG_PW-1:0]          inq_pkt_in_tag;
output wire [CC_SLV_BUS_ID_WIDTH:0]          inq_pkt_axi_id;
output wire [2:0]                            inq_pkt_tc;
output wire                                  inq_pkt_ep;
output wire [ATTR_WD-1:0]                    inq_pkt_attr;
output wire [7:0]                            inq_pkt_byte_en;
output wire [1:0]                            inq_pkt_fmt;
output wire [4:0]                            inq_pkt_type;
output wire [CC_SLV_BUS_ADDR_WIDTH-1:0]      inq_pkt_addr;
output wire [SLV_BUS_NPDATA_WIDTH-1:0]       inq_pkt_data;
output wire                                  dcmp_addr_parerr;
output ras_dp_err_log_t                      npdcmp_ad_ras_dp_err_log;
input ras_dp_err_inj_t                       ras_dp_err_inj_slv_aclk;


reg                                          r_req_pkt_rd;              
reg         [DCMP_PREFIX_WD-1:0]             r_req_pkt_tlp_prfx;
reg                                          r_req_pkt_th;
reg         [1:0]                            r_req_pkt_ph;
reg         [7:0]                            r_req_pkt_st;
reg                                          r_req_pkt_atu_bypass;
reg         [8:0]                            r_req_pkt_dst_segment;
reg         [1:0]                            r_req_pkt_ats;
reg                                          r_req_pkt_nw;
reg                                          r_req_pkt_first_wrp_split_xact;
reg                                          r_req_pkt_wrp_valid;
reg                                          r_req_pkt_snp;
reg         [DC_CPL_STATUS_WD-1:0]           r_req_pkt_cpl_stat;
reg         [CC_SLV_MTU_PW-1:0]              r_req_pkt_byte_len;
reg         [CC_MAX_SLV_TAG_PW-1:0]          r_req_pkt_in_tag;
reg         [CC_SLV_BUS_ID_WIDTH:0]          r_req_pkt_axi_id;
reg         [2:0]                            r_req_pkt_tc;
reg                                          r_req_pkt_ep;
reg         [ATTR_WD-1:0]                    r_req_pkt_attr;
reg         [7:0]                            r_req_pkt_byte_en;
reg         [1:0]                            r_req_pkt_fmt;
reg         [4:0]                            r_req_pkt_type;

reg         [CC_SLV_BUS_ADDR_WIDTH-1:0]      r_req_pkt_addr;


wire                                         s_req_pkt_rd;              
wire        [DCMP_PREFIX_WD-1:0]             s_req_pkt_tlp_prfx;
wire                                         s_req_pkt_th;
wire        [1:0]                            s_req_pkt_ph;
wire        [7:0]                            s_req_pkt_st;
wire                                         s_req_pkt_atu_bypass;
wire        [8:0]                            s_req_pkt_dst_segment;
wire        [1:0]                            s_req_pkt_ats;
wire                                         s_req_pkt_nw;
reg                                          s_req_pkt_first_wrp_split_xact;
reg                                          s_req_pkt_wrp_valid;
wire                                         s_req_pkt_snp;
wire        [DC_CPL_STATUS_WD-1:0]           s_req_pkt_cpl_stat;
wire        [CC_SLV_MTU_PW-1:0]              s_req_pkt_byte_len;
wire        [CC_MAX_SLV_TAG_PW-1:0]          s_req_pkt_in_tag;
wire        [CC_SLV_BUS_ID_WIDTH:0]          s_req_pkt_axi_id;
wire        [2:0]                            s_req_pkt_tc;
wire                                         s_req_pkt_ep;
wire        [ATTR_WD-1:0]                    s_req_pkt_attr;
wire        [7:0]                            s_req_pkt_byte_en;
wire        [1:0]                            s_req_pkt_fmt;
wire        [4:0]                            s_req_pkt_type;

wire        [CC_SLV_BUS_ADDR_WIDTH-1:0]      s_req_pkt_addr;
wire        [SLV_BUS_NPDATA_WIDTH-1:0]       s_req_pkt_data;


wire        [6:0]                            s_req_pkt_fmt_type;
wire        [CC_SLV_MTU_PW-3 :0]             s_req_pkt_dw_len;

reg         [10:0]                           int_s_max_rd_req_dw_len;        // Max read req size for current function
reg         [10:0]                           s_max_rd_req_dw_len;        // Max read req size for current function
wire        [10:0]                           s_max_rd_req_dw_len_addr_mask;

reg         [ADDR_PAR_WIDTH-1:0]             s_calc_req_addr_par;
reg         [ADDR_PAR_WIDTH-1:0]             s_calc_inq_addr_par;
reg         [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE-1:0] s_req_pkt_addr_nopar_int;
reg         [ADDR_PAR_WIDTH-1:0]             s_req_pkt_addr_parity;
wire        [ADDR_WD_WO_PAR-1:0]             s_req_pkt_addr_nopar;

reg                                          state;
reg                                          next_state;


wire        [CC_SLV_MTU_PW -3 :0]            s_pkt_remaining_dw_len;
reg         [CC_SLV_MTU_PW -3 :0]            r_pkt_sent_dw_len;
wire        [CC_SLV_MTU_PW -3 :0]            s_pkt_sent_dw_len;

wire                                         s_pkt_exceeds_max_rd_req;
wire        [10:0]                           s_pkt_dw_to_next_max_rd_req;

wire        [FIFO_BYTE_LEN_WD-3 :0]          s_tlp_dw_len;

wire        [ADDR_WD_WO_PAR-1:0]             s_tlp_addr_nopar;
wire        [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE-1:0] s_tlp_addr_nopar_int;

wire                                         s_decomposition_required;
wire                                         s_pkt_first_tlp;
wire                                         s_pkt_last_tlp;

// Register header fields for use in decomposed read requests
// ---------------------------------------------------------------------------------------------------------------------
always@(posedge slv_aclk or negedge slv_aresetn)
  begin: R_REQ_PKT_SEQ_PROC
    if (!slv_aresetn) begin
      r_req_pkt_rd                   <= #TP 1'b0;
      r_req_pkt_tlp_prfx             <= #TP {DCMP_PREFIX_WD{1'b0}};
      r_req_pkt_th                   <= #TP 1'h0;
      r_req_pkt_ph                   <= #TP 2'h0;
      r_req_pkt_st                   <= #TP 8'h00;
      r_req_pkt_atu_bypass           <= #TP 1'h0;
      r_req_pkt_dst_segment          <= #TP 9'h000;
      r_req_pkt_ats                  <= #TP 2'h0;
      r_req_pkt_nw                   <= #TP 1'h0;
      r_req_pkt_first_wrp_split_xact <= #TP 1'h0;
      r_req_pkt_wrp_valid            <= #TP 1'h0;
      r_req_pkt_snp                  <= #TP 1'h0;
      r_req_pkt_cpl_stat             <= #TP {DC_CPL_STATUS_WD{1'b0}};
      r_req_pkt_byte_len             <= #TP {CC_SLV_MTU_PW{1'b0}};
      r_req_pkt_in_tag               <= #TP {CC_MAX_SLV_TAG_PW{1'b0}};
      r_req_pkt_axi_id               <= #TP {(CC_SLV_BUS_ID_WIDTH+1){1'b0}};
      r_req_pkt_tc                   <= #TP 3'h0;
      r_req_pkt_ep                   <= #TP 1'h0;
      r_req_pkt_attr                 <= #TP {ATTR_WD{1'b0}};
      r_req_pkt_byte_en              <= #TP 8'h00;
      r_req_pkt_fmt                  <= #TP 2'h0;
      r_req_pkt_type                 <= #TP 5'h00;
      r_req_pkt_addr                 <= #TP {CC_SLV_BUS_ADDR_WIDTH{1'b0}};
    end else begin
      if (state == S_READY) begin
        r_req_pkt_rd                   <= #TP ~req_pkt_dv;
        r_req_pkt_tlp_prfx             <= #TP req_pkt_tlp_prfx;
        r_req_pkt_th                   <= #TP req_pkt_th;
        r_req_pkt_ph                   <= #TP req_pkt_ph;
        r_req_pkt_st                   <= #TP req_pkt_st;
        r_req_pkt_atu_bypass           <= #TP req_pkt_atu_bypass;
        r_req_pkt_dst_segment          <= #TP req_pkt_dst_segment;
        r_req_pkt_ats                  <= #TP req_pkt_ats;
        r_req_pkt_nw                   <= #TP req_pkt_nw;
        r_req_pkt_first_wrp_split_xact <= #TP req_pkt_first_wrp_split_xact;
        r_req_pkt_wrp_valid            <= #TP req_pkt_wrp_valid;
        r_req_pkt_snp                  <= #TP req_pkt_snp;
        r_req_pkt_cpl_stat             <= #TP req_pkt_cpl_stat;
        r_req_pkt_byte_len             <= #TP req_pkt_byte_len;
        r_req_pkt_in_tag               <= #TP req_pkt_in_tag;
        r_req_pkt_axi_id               <= #TP req_pkt_axi_id;
        r_req_pkt_tc                   <= #TP req_pkt_tc;
        r_req_pkt_ep                   <= #TP req_pkt_ep;
        r_req_pkt_attr                 <= #TP req_pkt_attr;
        r_req_pkt_byte_en              <= #TP req_pkt_byte_en;
        r_req_pkt_fmt                  <= #TP req_pkt_fmt;
        r_req_pkt_type                 <= #TP req_pkt_type;
        r_req_pkt_addr                 <= #TP req_pkt_addr;
      end
    end
  end


// Selecting between input and registered header fields
// On the first TLP the input header fields are used;
// On subsequent TLPs for decomposer read requests the registered values of the header fields are used
// ---------------------------------------------------------------------------------------------------------------------
assign s_req_pkt_rd                   = (state == S_READY) ? ~req_pkt_dv                  : r_req_pkt_rd;
assign s_req_pkt_tlp_prfx             = (state == S_READY) ? req_pkt_tlp_prfx             : r_req_pkt_tlp_prfx;
assign s_req_pkt_th                   = (state == S_READY) ? req_pkt_th                   : r_req_pkt_th;
assign s_req_pkt_ph                   = (state == S_READY) ? req_pkt_ph                   : r_req_pkt_ph;
assign s_req_pkt_st                   = (state == S_READY) ? req_pkt_st                   : r_req_pkt_st;
assign s_req_pkt_atu_bypass           = (state == S_READY) ? req_pkt_atu_bypass           : r_req_pkt_atu_bypass;
assign s_req_pkt_dst_segment          = (state == S_READY) ? req_pkt_dst_segment          : r_req_pkt_dst_segment;
assign s_req_pkt_ats                  = (state == S_READY) ? req_pkt_ats                  : r_req_pkt_ats;
assign s_req_pkt_nw                   = (state == S_READY) ? req_pkt_nw                   : r_req_pkt_nw;
assign s_req_pkt_first_wrp_split_xact = (state == S_READY) ? req_pkt_first_wrp_split_xact : r_req_pkt_first_wrp_split_xact;
assign s_req_pkt_wrp_valid            = (state == S_READY) ? req_pkt_wrp_valid            : r_req_pkt_wrp_valid;
assign s_req_pkt_snp                  = (state == S_READY) ? req_pkt_snp                  : r_req_pkt_snp;
assign s_req_pkt_cpl_stat             = (state == S_READY) ? req_pkt_cpl_stat             : r_req_pkt_cpl_stat;
assign s_req_pkt_byte_len             = (state == S_READY) ? req_pkt_byte_len             : r_req_pkt_byte_len;
assign s_req_pkt_in_tag               = (state == S_READY) ? req_pkt_in_tag               : r_req_pkt_in_tag;
assign s_req_pkt_axi_id               = (state == S_READY) ? req_pkt_axi_id               : r_req_pkt_axi_id;
assign s_req_pkt_tc                   = (state == S_READY) ? req_pkt_tc                   : r_req_pkt_tc;
assign s_req_pkt_ep                   = (state == S_READY) ? req_pkt_ep                   : r_req_pkt_ep;
assign s_req_pkt_attr                 = (state == S_READY) ? req_pkt_attr                 : r_req_pkt_attr;
assign s_req_pkt_byte_en              = (state == S_READY) ? req_pkt_byte_en              : r_req_pkt_byte_en;
assign s_req_pkt_fmt                  = (state == S_READY) ? req_pkt_fmt                  : r_req_pkt_fmt;
assign s_req_pkt_type                 = (state == S_READY) ? req_pkt_type                 : r_req_pkt_type;
assign s_req_pkt_addr                 = (state == S_READY) ? req_pkt_addr                 : r_req_pkt_addr;

assign s_req_pkt_data                 = req_pkt_data;


// Auxiliary signals derived from original request header
// ---------------------------------------------------------------------------------------------------------------------
assign s_req_pkt_fmt_type  = {s_req_pkt_fmt, s_req_pkt_type};
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_req_pkt_dw_len    =  s_req_pkt_byte_len[CC_SLV_MTU_PW-1:2] + {{(CC_SLV_MTU_PW-3){1'b0}},|s_req_pkt_byte_len[1:0]};
// spyglass enable_block W164a


// cfg_max_rd_req_size decoding decoding for outbound non-posted read decomposition
// ---------------------------------------------------------------------------------------------------------------------
always @( * )
  begin: S_MAX_RD_REQ_DW_LEN_COMB_PROC
    case (cfg_max_rd_req_size)
      3'b000 : int_s_max_rd_req_dw_len    = 11'h020; //  128B (  32 DW)
      3'b001 : int_s_max_rd_req_dw_len    = 11'h040; //  256B (  64 DW)
      3'b010 : int_s_max_rd_req_dw_len    = 11'h080; //  512B ( 128 DW)
      3'b011 : int_s_max_rd_req_dw_len    = 11'h100; // 1024B ( 256 DW)
      3'b100 : int_s_max_rd_req_dw_len    = 11'h200; // 2048B ( 512 DW)
      3'b101 : int_s_max_rd_req_dw_len    = 11'h400; // 4096B (1024 DW)
      default: int_s_max_rd_req_dw_len    = 11'h020; //  128B (  32 DW)
    endcase
  end

localparam L_MAX_SEG_DW_LEN = `CC_RADMX_COMPOSER_MAX_SEG_BYTE_LEN/4;

assign s_max_rd_req_dw_len = (int_s_max_rd_req_dw_len < L_MAX_SEG_DW_LEN) ? int_s_max_rd_req_dw_len : L_MAX_SEG_DW_LEN;

assign s_max_rd_req_dw_len_addr_mask      = s_max_rd_req_dw_len-11'h001;


// Detecting address parity errors and removing parity bits from address to allow it to be used in internal calculations
// ---------------------------------------------------------------------------------------------------------------------
always @( * )
begin: ADDR_STRIP_OFF_PAR_COMB_PROC
integer i;
reg [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE:0] i_req_pkt_addr;

    i_req_pkt_addr = s_req_pkt_addr;
    s_req_pkt_addr_nopar_int = 0;
    s_req_pkt_addr_parity    = 0;
    for (i=0; i<ADDR_PAR_WIDTH; i=i+1) begin
      s_req_pkt_addr_nopar_int[i] = i_req_pkt_addr[i][CX_RAS_PROT_RANGE-1:0];
      s_req_pkt_addr_parity[i]    = i_req_pkt_addr[i][CX_RAS_PROT_RANGE];
    end
end

assign s_req_pkt_addr_nopar = s_req_pkt_addr_nopar_int;

// Calculating parity for input address bus
always @( * )
begin: S_CALC_REQ_ADDR_PAR_COMB_PROC
integer i;
    s_calc_req_addr_par = 0;
    for (i=0; i<ADDR_PAR_WIDTH; i=i+1) begin
        s_calc_req_addr_par[i] = CX_RAS_PARITY_MODE ? ~(^(s_req_pkt_addr_nopar_int[i])) : ^(s_req_pkt_addr_nopar_int[i]);
    end
end


  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                              ),
    .RESETVAL                  (0                              ),
    .N_STAGES                  (0                              ),
    .CAN_STALL                 (0                              ),
    .RESET_STALL               (0                              ),
    .BUS_PROTECT_GEN_EN        (0                              ),
    .BUS_PROTECT_CHK_EN        (1                              ),
    .PROT_TYPE                 (1                              ),  // parity
    .PROT_RANGE                (CX_RAS_PROT_RANGE              ),
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS            ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE             ),
    .PROT_CORRECT_EN           (0                              ),
    .TOTAL_WIDTH               (ADDR_WD_WO_PAR                 ),
    .EXCLUDE_PROT_WIDTH        (0                              ),
    .RAS_DP_PROT_CHK_ID_BASE   (`NPDCMP_ADDR_RAS_DP_ID         )
  ) u_addr_chk (
    .clk                       ( slv_aclk                      ),
    .rst_n                     ( slv_aresetn                   ),
    .din                       ( s_req_pkt_addr_nopar          ),
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
    .ras_dp_err_log            ( npdcmp_ad_ras_dp_err_log      )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk        )
    );

   assign dcmp_addr_parerr = npdcmp_ad_ras_dp_err_log.valid;


assign inq_pkt_data = s_req_pkt_data;

always@(posedge slv_aclk or negedge slv_aresetn)
  begin: OB_NP_R_PKT_SENT_DW_LEN_SEQ_PROC
    if (!slv_aresetn) begin
      r_pkt_sent_dw_len <= #TP 0;
    end else begin
      if (!fifo_pkt_halt) begin
        if(state == S_READY) begin
          if (inq_pkt_hv) begin
            r_pkt_sent_dw_len <= #TP {{(CC_SLV_MTU_PW-FIFO_BYTE_LEN_WD){1'b0}},s_tlp_dw_len};
          end else begin
            r_pkt_sent_dw_len <= #TP 0;
          end
        end else begin
          if (state == S_RD_DCMP) begin
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

assign s_pkt_sent_dw_len                  = ( state == S_READY ) ? 0 : r_pkt_sent_dw_len;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_pkt_remaining_dw_len             = s_req_pkt_dw_len - s_pkt_sent_dw_len;
// spyglass enable_block W164a

// s_pkt_exceeds_max_rd_req              : request exceeds maximum read request size
// s_pkt_dw_to_next_max_rd_req           : number of dwords to next maximum read request boundary
// ---------------------------------------------------------------------------------------------------------------------
assign s_pkt_exceeds_max_rd_req              = (state == S_READY) ? ({{13-CC_SLV_MTU_PW{1'b0}}, s_req_pkt_dw_len} > s_max_rd_req_dw_len) : ({{13-CC_SLV_MTU_PW{1'b0}}, s_pkt_remaining_dw_len} > s_max_rd_req_dw_len);
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_pkt_dw_to_next_max_rd_req           = s_max_rd_req_dw_len - (s_tlp_addr_nopar[12:2] & s_max_rd_req_dw_len_addr_mask);
// spyglass enable_block W164a

assign s_decomposition_required              = s_pkt_exceeds_max_rd_req && s_req_pkt_rd;
assign s_pkt_first_tlp                       = (state == S_READY);
assign s_pkt_last_tlp                        = !s_decomposition_required;
assign s_tlp_dw_len                          = s_decomposition_required ? s_pkt_dw_to_next_max_rd_req[FIFO_BYTE_LEN_WD-3:0] : s_pkt_remaining_dw_len[FIFO_BYTE_LEN_WD-3:0];

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_tlp_addr_nopar = {s_req_pkt_addr_nopar[ADDR_WD_WO_PAR-1:2],2'b00} + {{(ADDR_WD_WO_PAR-CC_SLV_MTU_PW){1'b0}},s_pkt_sent_dw_len,2'b00};
// spyglass enable_block W164a


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
  begin: OB_NP_STATE_COMB_PROC
    if (!fifo_pkt_halt) begin
      case(state)
        S_READY :
       if (req_pkt_hv && !req_pkt_dv) begin
         if (s_decomposition_required) begin
                next_state = S_RD_DCMP;
              end else begin
                next_state = S_READY;
              end
            end else begin
              next_state = S_READY;
            end
        S_RD_DCMP:
       if (s_decomposition_required) begin
              next_state = S_RD_DCMP;
       end else begin
              next_state = S_READY;
            end
      endcase
    end else begin
      next_state = state;
    end
  end

// inq_pkt_halt
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_halt                 = ( state == S_READY   ) ? fifo_pkt_halt : 1'b1;

// inq_pkt_hv
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_hv                   = ( state == S_READY   ) ? req_pkt_hv :
                                      ( state == S_RD_DCMP ) ? 1'b1 :
                                                               1'b0;

// inq_pkt_dv
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_dv                   = ( state == S_READY   ) ? req_pkt_dv :
                                                               1'b0;

// inq_pkt_eot
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_eot                  = ( state == S_READY   ) ? req_pkt_eot :
                                      ( state == S_RD_DCMP ) ? 1'b1 :
                                                           1'b0;

// inq_pkt_bad_eot
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_bad_eot              = 1'b0;


// inq_pkt_cpl_stat
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_cpl_stat             = s_req_pkt_cpl_stat;

// inq_pkt_byte_len
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_byte_len             = {s_tlp_dw_len,2'b00};

// inq_pkt_addr
// ---------------------------------------------------------------------------------------------------------------------
// Adding parity bits to output address
// ---------------------------------------------------------------------------------------------------------------------

assign s_tlp_addr_nopar_int         = s_tlp_addr_nopar;

always @( * )
begin : OUT_ADDR_PAR_CAL
integer i;
    s_calc_inq_addr_par = 0;
    for (i=0; i<ADDR_PAR_WIDTH; i=i+1) begin
        s_calc_inq_addr_par[i] = CX_RAS_PARITY_MODE ? ~(^(s_tlp_addr_nopar_int[i])) : ^(s_tlp_addr_nopar_int[i]);
    end
end

assign inq_pkt_addr                 = add_addr_par(s_tlp_addr_nopar, s_calc_inq_addr_par);


// inq_pkt_byte_en
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_byte_en[3:0]         =  s_pkt_first_tlp                                         ? s_req_pkt_byte_en[3:0] :
                                      (inq_pkt_byte_len == {{(CC_SLV_MTU_PW-3){1'b0}},3'b100}) ? s_req_pkt_byte_en[7:4] :
                                                                                             4'b1111;
assign inq_pkt_byte_en[7:4]         = (inq_pkt_byte_len <= {{(CC_SLV_MTU_PW-3){1'b0}},3'b100}) ? 4'b0000 :
                                       s_decomposition_required                                ? 4'b1111 :
                                                                                             s_req_pkt_byte_en[7:4];

// inq_pkt_last_tlp
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_last_tlp             = s_pkt_last_tlp;

// inq_pkt_serial_req
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_serial_req           = s_req_pkt_snp;

// inq_pkt_dcmp_rd
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_dcmp_rd              = s_decomposition_required;

// inq_pkt_*
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_tlp_prfx             = s_req_pkt_tlp_prfx;
assign inq_pkt_th                   = s_req_pkt_th;
assign inq_pkt_ph                   = s_req_pkt_ph;
assign inq_pkt_st                   = s_req_pkt_st;
assign inq_pkt_atu_bypass           = s_req_pkt_atu_bypass;
assign inq_pkt_dst_segment          = s_req_pkt_dst_segment;
assign inq_pkt_ats                  = s_req_pkt_ats;
assign inq_pkt_nw                   = s_req_pkt_nw;
assign inq_pkt_first_wrp_split_xact = s_req_pkt_first_wrp_split_xact;
assign inq_pkt_wrp_valid            = s_req_pkt_wrp_valid;
assign inq_pkt_in_tag               = s_req_pkt_in_tag;
assign inq_pkt_axi_id               = s_req_pkt_axi_id;
assign inq_pkt_req_byte_len         = s_req_pkt_byte_len;
assign inq_pkt_tc                   = s_req_pkt_tc;
assign inq_pkt_ep                   = s_req_pkt_ep && ((inq_pkt_byte_en != 8'h00) || ({s_req_pkt_fmt,s_req_pkt_type} inside {`FETCHADD32, `FETCHADD64, `SWAP32, `SWAP64, `CAS32, `CAS64}));
assign inq_pkt_attr                 = s_req_pkt_attr;
assign inq_pkt_fmt                  = s_req_pkt_fmt;
assign inq_pkt_type                 = s_req_pkt_type;



// Auxiliary functions
// ---------------------------------------------------------------------------------------------------------------------


function automatic [CC_SLV_BUS_ADDR_WIDTH-1 :0] add_addr_par;
input [ADDR_WD_WO_PAR-1 : 0]   in_addr;
input [ADDR_PAR_WIDTH-1:0]   in_par;
integer i;
reg [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE-1:0] i_in_addr;
reg [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE:0] i_add_addr_par;
begin
    i_in_addr = in_addr;
    i_add_addr_par ={CC_SLV_BUS_ADDR_WIDTH{1'b0}};
    for (i=0; i<ADDR_PAR_WIDTH; i=i+1) begin
      i_add_addr_par[i] = {in_par[i],i_in_addr[i]};
    end
    add_addr_par = i_add_addr_par;
end
endfunction // add_addr_par


`ifndef SYNTHESIS
// VCS coverage off
wire    [32*8-1:0]         STATE;

assign  STATE   =  (state == S_READY                         ) ? "READY"  :
                   (state == S_RD_DCMP                       ) ? "RD_DCMP" :
                                                       "";
// VCS coverage on
`endif // SYNTHESIS

endmodule

