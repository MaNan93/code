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
// ---    $Revision: #13 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_axi_cpl_comp_ctl_sbc.sv#13 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// This module is designed to compose all responses that are belonged to the same request.
// A request can be split into several request based on the address boundary requirement,
// max payload of a transfer, etc. Each splited request can have several responses associated
// with because of PCIe split response feature. Therefore, a request can have multiple responses.
//
// The module is used in both transmit and receive directions of AXI bridge.
// Transmit Direction: When an AXI master issue a read request and its burst size is larger than
// PCIe MTU, then the AXI request will be split into few requests before these requests are transmited
// onto PCIe wire. A DWC_pcie_axi_cpl_comp_ctl will be placed to compose all responses received from PCIe wire.

// Receive Direction: When PCIe port recieved a read request and its burst size is larger than AXI MTU,
// then the request will be split into few AXI master transfers. An DWC_pcie_axi_cpl_comp_ctl will be placed to compose
// all responses received from AXI slave's responses.

// Composer are optional for both transmit and recieve direction. This is depended on customer's configuration.

//  The major features:
//  1. Using segment buffer to store all completion received according to application request ID (not the completion ID)
//     The number of segment = the number of max master read requests allowed in AXI system
//  2. All requests are served in order by allowing only the responses being read out of segment buffer i
//     for a request with a particular ID
//  2. A sub module trn_id_trn.v is loaded in this module to support ID and its attributes lookup.
//  3. trn_id_lut.v identifes whther or not all completions returned and provide some information that are associated to
//     a particular request. The infor involves length, read or write type.
//  4. Read of the segment buffer can be back-pressured when receiver of this completion data is not ready
//  5. Completions that are not expected will be dropped and an error will be reported.
//  6. Arbitration of the composed completion to be read is performed in this block. When it is not halted, the highest request ID gets to go first.
//     Once the arbitration decision has been made, it is required for reciver of the completion to take a full completion that is composed
//     Otherwise, the composed completion of higher priority channel can be blocked. This is designed for out of order services
//  7. If error happened during the recomposing of the completion, then the error status is notified to receiver of the completion
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "common/DW_sbc_cdc/DW_sbc_cdc_pkg.svh"

`include "DWC_pcie_ctl_pkg.svh"

 module DWC_pcie_axi_cpl_comp_ctl_sbc
 import DW_sbc_cdc_pkg::*;

  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::UNCORRECTABLE;
  import DWC_pcie_ctl_pkg::CORRECTABLE;
  import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_INDEX;
  import DWC_pcie_ctl_pkg::RAS_ERROR_TYPE_WD;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;

 (

    clk,
    slv_aclk,
    rst_n,
    slv_aresetn,

    dataq_wr_en,
    dataq_wr_start,
    dataq_wr_keep,
    dataq_wr_drop,
    dataq_wr_seg_num,
    dataq_wr_data_s,

    dataq_rd_en,
    dataq_rd_seg_num,

    cfg_bridge_sb_init_i_synch_int,
    dataq_depth,
    cmp_sb_init_done,
    num_segs,

    dataq_empty,
    dataq_empty_p_1,
    dataq_full_m_1,
    dataq_seg_pkt_avail,

    sbc_halt,

    ccmp_data_ram_addra,
    ccmp_data_ram_addrb,
    ccmp_data_ram_dina,
    ccmp_data_ram_doutb,
    ccmp_data_ram_enb,
    ccmp_data_ram_wea,

    dataq_rd_dv,
    dataq_rd_eot,
    dataq_rd_err,
    dataq_rd_tag,
    latchd_rcvd_pkt_hdr,
    lookup_resp_tlp_byte_len,
    lookup_resp_tlp_low_addr,
    lookup_resp_tlp_4rd,
    lookup_resp_tlp_rreq_dma,
    lookup_resp_tlp_rreq_dma_chan,

    piped_rd_data_dv,
    piped_rd_data_eot,
    piped_rd_data_err,
    piped_rd_data,
    piped_rd_data_ram_addrb,
    piped_rd_dwen,
    piped_rd_status_good,
    piped_rd_hdr,
    piped_rd_pkt_tag,
    piped_rd_pkt_byte_len,
    piped_rd_pkt_low_addr,
    piped_rd_pkt_4rd,
    piped_rd_pkt_rreq_dma,
    piped_rd_pkt_rreq_dma_chan,

    ras_dp_err_inj_core_clk,
    ras_dp_err_inj_slv_aclk,
    core_clk_ordrb_ras_dp_err_inj,
    axi_ras_par_ob_cpl_comp_dt_pulse,
    ob_cpl_comp_dt_ras_dp_err_log,
    ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log,
    chk_ras_recc_corr_cnt_ob_ccmp_data_pulse,
    chk_ras_recc_ucorr_cnt_ob_ccmp_data_pulse,

    align_halt

);

parameter SYNC_DEPTH                        = `CX_PCIE_SYNC_DEPTH;

parameter HDR_WD                            = `RADM_P_HWD;                 // a header macro
parameter MAX_OUT_TAG_PW                    = `CC_MAX_SLV_TAG_PW;          // pointer of MAX_OUT_TAG
parameter MAX_OUT_TAG                       = `CC_MAX_SLV_TAG;             // Number of MAX TAG that PKTs go out with
parameter MAX_IN_TAG_PW                     = `CX_LUT_PTR_WIDTH;           // Pointer of CX_MAX_TAG
parameter MAX_IN_TAG                        = `CX_MAX_TAG +1;              // Number of MAX TAG that PKTs can come in with
parameter MAX_RD_SIZE                       = `CC_SLV_RD_REQ_SIZE;         // MAX number of read request size
parameter MAX_RD_SIZE_PW                    = `CC_SLV_RD_REQ_SIZE_PW;      // pointer size for MAX rd size
parameter CC_OB_CCMP_DATA_RAM_DATA_WD       = `CC_OB_CCMP_DATA_RAM_DATA_WD; // SBUG buffer stores data and dword enable and flag of data with payload
parameter CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC = `CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC; // SBUG buffer stores data and dword enable and flag of data with payload
parameter CC_OB_CCMP_DATA_RAM_ADDR_WD       = `CC_OB_CCMP_DATA_RAM_ADDR_WD; // COMPOSER DATAQ pointer width
parameter CC_OB_CCMP_DATA_RAM_DP            = `CC_OB_CCMP_DATA_RAM_DP;      // COMPOSER DATAQ pointer depth
parameter CC_RADMX_COMPOSER_SEG_DP          = `CC_RADMX_COMPOSER_SEG_DP;
parameter HOLD_RADDR                        = 1;

parameter CORE_DATA_BUS_WD                  = `CC_CORE_DATA_BUS_WD;
parameter CORE_DATA_BUS_WD_NP               = `PCIE_CORE_DATA_BUS_WD;
parameter NW                                = `CX_NW; // Number of 32-bit dwords handled by the datapath each clock.
parameter DBUS_DWORD_WD_WITH_PAR            = `CC_DBUS_DWORD_WD_WITH_PAR;
parameter TP                                = `TP;                                     // Clock to Q delay (simulator insurance)

// FOR completion compose queue
parameter PAR_WD                            = CORE_DATA_BUS_WD - CORE_DATA_BUS_WD_NP;
parameter OB_CCMP_DATA_WD                   =  NW
                                               + CORE_DATA_BUS_WD
                                               + 1
                                              ;

parameter SBUF_DWEN_HIGH                    =                                                OB_CCMP_DATA_WD - 1
                                                ;

parameter SBUF_DWEN_LOW                     = SBUF_DWEN_HIGH - NW +1;
parameter SBUF_DATA_HIGH                    = SBUF_DWEN_LOW - 1;
parameter SBUF_DATA_LOW                     = SBUF_DATA_HIGH
                                                - CORE_DATA_BUS_WD
                                               + 1 ;
parameter SBUF_PYLD_HIGH                    = SBUF_DATA_LOW - 1;
parameter SBUF_PYLD_LOW                     = SBUF_PYLD_HIGH ;

parameter NUM_SEGMENTS                      = MAX_OUT_TAG ;
parameter NUM_SEGMENTS_PW                   = MAX_OUT_TAG_PW ;
parameter NUM_WIRETAGS                      = MAX_IN_TAG ;
parameter NUM_WIRETAGS_PW                   = MAX_IN_TAG_PW ;

parameter GENERATE_STARTEND_ADDRS           = 1;
parameter DEBUG_WRITES                      = 0;

parameter CC_OB_CCMP_DATA_RAM_RD_LATENCY    = `CC_OB_CCMP_DATA_RAM_RD_LATENCY ;
parameter CC_OB_CCMP_DATA_RAM_REGIN         = `CC_OB_CCMP_DATA_RAM_REGIN ;
parameter DELAY_DATA_WD                     =                                                OB_CCMP_DATA_WD +1 +1 +1;
parameter DELAY_HDR_WD                      = MAX_OUT_TAG_PW + HDR_WD + MAX_RD_SIZE_PW + 7 +1
                                              +3 +3
                                              ;

parameter DELAY_WD                          = DELAY_DATA_WD + DELAY_HDR_WD;

parameter DMA_ENABLE_VALUE                  = `CC_DMA_ENABLE_VALUE;

parameter SLV_ID_WD                         = `CC_SLV_BUS_ID_WIDTH+1;
parameter CX_RAS_RAM_PROT_RANGE             = `CX_RAS_RAM_PROT_RANGE;
parameter CX_RAS_PROT_RANGE                 = `CX_RAS_PROT_RANGE;
parameter CX_RAS_PARITY_MODE                = `CX_RAS_PARITY_MODE;


localparam  RD_DATA_WD =                               CORE_DATA_BUS_WD;

//  ========================================================================================================================
//  ---------------------- Local parameters ------------------------
//  ========================================================================================================================

  localparam [8:0] BUS_INIT_BYTE = CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;
  localparam BYTE_WD_W_PAR = 9;
  localparam BUS_N_BYTES = NW * 4;

  localparam [CORE_DATA_BUS_WD-1:0] BUS_INIT = {BUS_N_BYTES{BUS_INIT_BYTE}};

  localparam LP_OB_RAM_REGIN = 0 + 1;

  // If using multicomposer, SBC does not regin or regout
  localparam LP_SBC_RAM_REGIN  = LP_OB_RAM_REGIN;
  localparam LP_SBC_RAM_REGOUT = 1;

  // BCM65 transport delay parameters
  localparam integer REG_DELAY_DENOM = 1000;
  localparam integer REG_DELAY_TIME  = `TP * REG_DELAY_DENOM;

  localparam NUM_DATA_PAR_BLOCKS_S = CORE_DATA_BUS_WD_NP/CX_RAS_PROT_RANGE;
  localparam ECC_WIDTH = CC_OB_CCMP_DATA_RAM_DATA_WD - CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC;
  localparam OB_CCMP_DATA_ECC_WD = OB_CCMP_DATA_WD
                                      ;

  localparam LATENCY_PIPE_WIDTH = DELAY_WD
                                  + CC_OB_CCMP_DATA_RAM_ADDR_WD
                                  ;

  localparam OB_CCMP_ALGN_RAM_WD =   1
                                   //+ 1
                                   + 1
                                   + 1
                                   + MAX_OUT_TAG_PW
                                   + HDR_WD
                                   + MAX_RD_SIZE_PW
                                   + 7
                                   + 1
                                   + 3
                                   + 3
                                   ;

  localparam L_N_EXPLICIT_FANOUT = 5;


input                                                    clk;
input                                                    slv_aclk;
input                                                    rst_n;
input                                                    slv_aresetn;

input                                                    dataq_wr_en;
input                                                    dataq_wr_start;
input                                                    dataq_wr_keep;
input                                                    dataq_wr_drop;
input  [NUM_WIRETAGS_PW -1:0]                            dataq_wr_seg_num;
input  [OB_CCMP_DATA_WD-1:0]                             dataq_wr_data_s;


input                                                    dataq_rd_en;
input  [NUM_WIRETAGS_PW -1:0]                            dataq_rd_seg_num;

input                                                    cfg_bridge_sb_init_i_synch_int;
input  [(CC_OB_CCMP_DATA_RAM_ADDR_WD*NUM_SEGMENTS) -1:0] dataq_depth;

output                                                   cmp_sb_init_done;

input  [NUM_SEGMENTS_PW :0]                              num_segs;

output [NUM_WIRETAGS    :0]                              dataq_empty;
output [NUM_WIRETAGS    :0]                              dataq_empty_p_1;
output [NUM_WIRETAGS    :0]                              dataq_full_m_1;
output [NUM_WIRETAGS    :0]                              dataq_seg_pkt_avail;

output [L_N_EXPLICIT_FANOUT -1:0]                        sbc_halt;


// RAM interface
input  [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]                 ccmp_data_ram_doutb;
output [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]                 ccmp_data_ram_addra;
output [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]                 ccmp_data_ram_addrb;
output [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]                 ccmp_data_ram_dina;
output                                                   ccmp_data_ram_enb;
output                                                   ccmp_data_ram_wea;

input                                                    dataq_rd_dv;
input                                                    dataq_rd_eot;
input                                                    dataq_rd_err;
input  [MAX_OUT_TAG_PW -1:0]                             dataq_rd_tag;
input  [HDR_WD -1:0]                                     latchd_rcvd_pkt_hdr;
input  [MAX_RD_SIZE_PW -1:0]                             lookup_resp_tlp_byte_len;
input  [6:0]                                             lookup_resp_tlp_low_addr;
input                                                    lookup_resp_tlp_4rd;
input  [2:0]                                             lookup_resp_tlp_rreq_dma;
input  [2:0]                                             lookup_resp_tlp_rreq_dma_chan;

output                                                   piped_rd_data_dv;
output                                                   piped_rd_data_eot;
output                                                   piped_rd_data_err;
output [RD_DATA_WD -1 :0]                                piped_rd_data;
output [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]                 piped_rd_data_ram_addrb;
output [NW -1 :0]                                        piped_rd_dwen;
output                                                   piped_rd_status_good;
output [HDR_WD -1:0]                                     piped_rd_hdr;
output [MAX_OUT_TAG_PW -1:0]                             piped_rd_pkt_tag;
output [MAX_RD_SIZE_PW -1:0]                             piped_rd_pkt_byte_len;
output [6:0]                                             piped_rd_pkt_low_addr;
output                                                   piped_rd_pkt_4rd;
output [2:0]                                             piped_rd_pkt_rreq_dma;
output [2:0]                                             piped_rd_pkt_rreq_dma_chan;

input                                                    align_halt;

input ras_dp_err_inj_t                                   ras_dp_err_inj_core_clk;
input ras_dp_err_inj_t                                   ras_dp_err_inj_slv_aclk;
input ras_dp_err_inj_t                                   core_clk_ordrb_ras_dp_err_inj;
output                                                   axi_ras_par_ob_cpl_comp_dt_pulse;
output ras_dp_err_log_t                                  ob_cpl_comp_dt_ras_dp_err_log;
output ras_dp_err_log_t                                  ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log;
output                                                   chk_ras_recc_corr_cnt_ob_ccmp_data_pulse;
output                                                   chk_ras_recc_ucorr_cnt_ob_ccmp_data_pulse;


reg    [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]                 ccmp_data_ram_addrb;
reg                                                      ccmp_data_ram_enb_n;
reg    [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]                 ccmp_data_ram_addra;
reg    [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]                 ccmp_data_ram_dina;
reg                                                      ccmp_data_ram_wea_n;



//  ========================================================================================================================
//  ---------------------- Internal signal declarations ------------------------
//  ========================================================================================================================

wire   [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]                 ccmp_data_ram_doutb;
wire                                                     ccmp_data_ram_enb;
wire                                                     ccmp_data_ram_wea;


wire   [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]                 ss_ccmp_data_ram_doutb;
wire   [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]                 s_ccmp_data_ram_doutb;
wire   [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]                 s_ccmp_data_ram_addra;
wire   [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]                 s_ccmp_data_ram_addrb;
wire   [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]                 s_ccmp_data_ram_dina;
wire                                                     s_ccmp_data_ram_enb_n;
wire                                                     s_ccmp_data_ram_wea_n;

wire [NW-1:0]                                            rcvd_pkt_wr_dwen;
wire [CORE_DATA_BUS_WD-1:0]                              rcvd_pkt_wr_data;
wire [CORE_DATA_BUS_WD-1:0]                              rcvd_pkt_wr_data_t;
logic [CORE_DATA_BUS_WD-1:0]                             int_rcvd_pkt_wr_mask,int_rcvd_pkt_mask;
wire  [CORE_DATA_BUS_WD_NP-1:0]                          ss_ccmp_data_ram_dina_t;
wire                                                     rcvd_pkt_wr_status_good;

logic  [OB_CCMP_DATA_ECC_WD-1:0]                         ss_ccmp_data_ram_dina_out;
logic  [OB_CCMP_DATA_WD-1:0]                             r_ccmp_data_ram_doutb_out;
logic  [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]                 r_ccmp_data_ram_doutb_t;
logic  [OB_CCMP_DATA_ECC_WD-1:0]                         s_ccmp_data_ram_doutb_out;
wire   [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]                 ss_ccmp_data_ram_doutb_out;

wire   [ECC_WIDTH -1:0]                                  eccg_out;
wire   [ECC_WIDTH-1:0]                                   eccg_rd;
ras_dp_err_log_t                                         s_ob_cpl_comp_dt_ras_dp_err_log;

wire   [OB_CCMP_DATA_WD-1:0]                             dataq_rd_data_wp;
wire [OB_CCMP_DATA_WD-1:0]                               ss_ccmp_data_ram_doutb_t;


wire   [CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC-1:0]           dataq_rd_data;
wire   [ECC_WIDTH-1:0]                                   dataq_rd_ecc;

wire   [HDR_WD-1:0]                                      dataq_rd_hdr;
// Delay output signals
wire                                                     s_dly_ccmp_data_ram_enb;
wire   [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]                 s_dly_ccmp_data_ram_addrb;
wire                                                     s_dly_dataq_rd_dv;
wire                                                     s_dly_dataq_rd_eot;
wire                                                     s_dly_dataq_rd_err;
wire   [MAX_OUT_TAG_PW -1:0]                             s_dly_dataq_rd_tag;
wire   [HDR_WD-1:0]                                      s_dly_dataq_rd_hdr;
wire   [MAX_RD_SIZE_PW -1:0]                             s_dly_lookup_resp_tlp_byte_len;
wire   [6:0]                                             s_dly_lookup_resp_tlp_low_addr;
wire                                                     s_dly_lookup_resp_tlp_4rd;
wire   [2:0]                                             s_dly_lookup_resp_tlp_rreq_dma;
wire   [2:0]                                             s_dly_lookup_resp_tlp_rreq_dma_chan;

wire    [DELAY_DATA_WD -1 :0]                            s_pipe_in_data;
wire    [DELAY_DATA_WD -1 :0]                            s_pipe_out_data;
wire    [DELAY_HDR_WD -1 :0]                             s_pipe_in_hdr;
wire    [DELAY_HDR_WD -1 :0]                             s_pipe_out_hdr;
wire    [OB_CCMP_DATA_WD-1:0]                            piped_dataq_rd_data;

reg                                                      r_dataq_rd_err;


always @(posedge slv_aclk or negedge slv_aresetn) begin
  if (!slv_aresetn) begin
    r_dataq_rd_err       <= #TP 0;
  end else if (!sbc_halt[0]) begin
    r_dataq_rd_err       <= #TP dataq_rd_eot ? 1'b0 : (dataq_rd_err ? 1'b1 : r_dataq_rd_err);
  end
end

logic [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0] r_ccmp_data_ram_doutb;

localparam L_SEGS = MAX_IN_TAG + 1;
localparam L_SEG_W = MAX_IN_TAG_PW ;

logic                        s_dataq_rd_en;
logic [NUM_WIRETAGS_PW-1 :0] s_dataq_rd_seg_num;

always_ff @(posedge slv_aclk, negedge slv_aresetn) begin : s_dataq_rd_inpipe_PROC
  if(!slv_aresetn) begin
    s_dataq_rd_en      <= #`TP '0;
    s_dataq_rd_seg_num <= #`TP '0;
  end else begin
    s_dataq_rd_en      <= #`TP dataq_rd_en;
    s_dataq_rd_seg_num <= #`TP dataq_rd_seg_num;
  end
end : s_dataq_rd_inpipe_PROC

logic                                          s_dataq_wr_en;
logic                                          s_dataq_wr_start;
logic                                          s_dataq_wr_keep;
logic                                          s_dataq_wr_drop;
logic                   [NUM_WIRETAGS_PW -1:0] s_dataq_wr_seg_num;
logic [CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC -1:0] s_dataq_wr_data;
logic [OB_CCMP_DATA_WD-1:0]                   s_dataq_wr_data_s;

logic                         [ECC_WIDTH-1 :0] s_dataq_wr_ecc;

always_ff @(posedge clk, negedge rst_n) begin : s_dataq_wr_inpipe_PROC
  if(!rst_n) begin
    s_dataq_wr_en      <= #`TP '0;
    s_dataq_wr_start   <= #`TP '0;
    s_dataq_wr_keep    <= #`TP '0;
    s_dataq_wr_drop    <= #`TP '0;
    s_dataq_wr_seg_num <= #`TP '0;
    s_dataq_wr_data_s  <= #`TP '0;
  end else begin
    s_dataq_wr_en      <= #`TP dataq_wr_en;
    s_dataq_wr_start   <= #`TP dataq_wr_start;
    s_dataq_wr_keep    <= #`TP dataq_wr_keep;
    s_dataq_wr_drop    <= #`TP dataq_wr_drop;
    s_dataq_wr_seg_num <= #`TP dataq_wr_seg_num;
    s_dataq_wr_data_s  <= #`TP dataq_wr_data_s;

  end
end : s_dataq_wr_inpipe_PROC

DW_sbc_cdc_compat
 #(
   .SEGS               (L_SEGS                        )
  ,.SEG_W              (L_SEG_W                       )
  ,.RAM_W              (OB_CCMP_DATA_WD               )  // DATA_NOECC + PAR
  ,.RAM_AW             (CC_OB_CCMP_DATA_RAM_ADDR_WD   )
  ,.HOLD_RADDR         (HOLD_RADDR                    )
  ,.P_SEG_DP           (CC_RADMX_COMPOSER_SEG_DP      )
  ,.P_RAM_LATENCY      (CC_OB_CCMP_DATA_RAM_RD_LATENCY)
  ,.P_CDC_ARCH         (E_LEAVE_UNCONNECTED           )
  ,.P_RAM_REGOUT       (LP_SBC_RAM_REGIN              )
  ,.P_RAM_REGIN        (LP_SBC_RAM_REGOUT             )
  ,.P_SVA_MAY_POP_EMPTY(E_TRUE                        )
  ,.P_PUSH2POP_SYNC_DP (SYNC_DEPTH                    )
  ,.P_POP2PUSH_SYNC_DP (SYNC_DEPTH                    )
) u_data_DW_sbc (
    .clk_push           (clk                         ),
    .clk_pop            (slv_aclk                    ),
    .push_rst_n         (rst_n                       ),
    .pop_rst_n          (slv_aresetn                 ),
    .sb_push_i          (s_dataq_wr_en               ),
    .sb_push_start_i    (s_dataq_wr_start            ),
    .sb_push_keep_i     (s_dataq_wr_keep             ),
    .sb_push_drop_i     (s_dataq_wr_drop             ),
    .sb_push_seg_i      (s_dataq_wr_seg_num          ),
    .sb_push_data_i     (s_dataq_wr_data_s           ),  // DATA_NOECC + PAR
    .sb_reset_push_ptr  (1'b0                        ),
    .sb_reset_push_seg_i(  '0                        ),
    .sb_pop_i           (s_dataq_rd_en               ),
    .sb_pop_seg_i       (s_dataq_rd_seg_num          ),
    .sb_pop_look_i      (1'b0                        ),
   .sb_pop_data_o      (r_ccmp_data_ram_doutb_out    ),  // DATA_NOECC + PAR
    .sb_reset_pop_ptr   (1'b0                        ),
    .sb_reset_pop_seg_i (  '0                        ),
    .sb_init_i          (  '0                        ),
    .sb_init_seg_sizes_i(  '0                        ),
    .sb_init_done_o     (cmp_sb_init_done            ),
    .sb_init_num_segs_i (  '0                        ),
    .sb_seg_start_i     (  '0                        ),
    .sb_seg_end_i       (  '0                        ),
    .sb_empty_o         (dataq_empty                 ),
    .sb_empty_p_1_o     (dataq_empty_p_1             ),
    .sb_full_o          (                            ),
    .sb_full_m_1_o      (dataq_full_m_1              ),
    .sb_full_m_2_o      (                            ),
    .sb_seg_pkt_avail_o (dataq_seg_pkt_avail         ),
    .sb_waddr_o         (s_ccmp_data_ram_addra       ),
    .sb_wen_n_o         (s_ccmp_data_ram_wea_n       ),
    .sb_wdata_o         (ss_ccmp_data_ram_dina_out   ),
    .sb_raddr_o         (s_ccmp_data_ram_addrb       ),
    .sb_ren_n_o         (s_ccmp_data_ram_enb_n       ),
    .sb_par_chk_val_o   (                            ),
    .sb_rdata_i         (s_ccmp_data_ram_doutb_out   )
);


  // Serializing the ss_ccmp_data_ram_dina_out and remove parity from the data
  assign {rcvd_pkt_wr_dwen,rcvd_pkt_wr_data,rcvd_pkt_wr_status_good} = ss_ccmp_data_ram_dina_out;

  wire ccmp_dt_ram_en;
  assign ccmp_dt_ram_en = !s_ccmp_data_ram_wea_n;


always @(rcvd_pkt_wr_dwen)
begin

  integer i;
  integer j;

  for (i=0; i<NW; i=i+1) begin
    for (j=0; j<DBUS_DWORD_WD_WITH_PAR; j=j+1) begin
      int_rcvd_pkt_wr_mask[i*DBUS_DWORD_WD_WITH_PAR+j] = rcvd_pkt_wr_dwen[i];
    end
  end

end


assign rcvd_pkt_wr_data_t = (rcvd_pkt_wr_data & int_rcvd_pkt_wr_mask) | (~int_rcvd_pkt_wr_mask & {BUS_N_BYTES{BUS_INIT_BYTE}});

assign ss_ccmp_data_ram_dina_t = fn_data_wo_par(rcvd_pkt_wr_data_t);


   // Parity Checker
   ras_dp_pipe
   
   #(
    .PIPELINE_TYPE             (0                                        ),
    .RESETVAL                  (0                                        ),
    .N_STAGES                  (0                                        ),
    .CAN_STALL                 (0                                        ),
    .RESET_STALL               (0                                        ),
    .BUS_PROTECT_GEN_EN        (0                                        ),
    .BUS_PROTECT_CHK_EN        (1                                        ),
    .PROT_TYPE                 (1                                        ), // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                (CX_RAS_PROT_RANGE                        ),
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS_S                    ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE                       ),
    .PROT_CORRECT_EN           (0                                        ),
    .TOTAL_WIDTH               (CORE_DATA_BUS_WD_NP                      ),
    .EXCLUDE_PROT_WIDTH        (0                                        ),
    .RAS_DP_PROT_CHK_ID_BASE   (`OB_CPL_COMP_DT_RAS_ID                   )
  ) u_data_chk (
    .clk                       ( clk                                     ),
    .rst_n                     ( rst_n                                   ),
    .din                       ( ss_ccmp_data_ram_dina_t                 ),
    .din_prot                  ( fn_prot_chkin_dt(rcvd_pkt_wr_data_t)    ),
    .dout                      (  /* Not connected */                    ),
    .dout_prot                 (  /* Not connected */                    ),
    .en                        (1'b1                                     ),
    .bypass                    (1'b0                                     ),
    .stall                     (1'b0                                     ),
    .stallout                  (  /* Not connected */                    ),
    .valid_in                  ( ccmp_dt_ram_en                          ),
    .halt_out                  (  /* Not connected */                    ),
    .valid_out                 (  /* Not connected */                    ),
    .halt_in                   (1'b0                                     ),
    .ras_dp_err_inband_kbd_in  (1'b0                                     ),
    .ras_dp_err_inband_kbd_out (  /* Not connected */                    ),
    .ras_dp_err_log            ( s_ob_cpl_comp_dt_ras_dp_err_log         )
      ,
      .ras_dp_err_inj          (core_clk_ordrb_ras_dp_err_inj             )
    );

   assign axi_ras_par_ob_cpl_comp_dt_pulse = s_ob_cpl_comp_dt_ras_dp_err_log.valid;
   assign ob_cpl_comp_dt_ras_dp_err_log = s_ob_cpl_comp_dt_ras_dp_err_log;

  // ECC Generator
  ras_dp_pipe
   #(
     .PIPELINE_TYPE             (0                                    ), // 0: delay_n
     .RESETVAL                  (0                                    ),
     .N_STAGES                  (0                                    ),
     .CAN_STALL                 (0                                    ),
     .RESET_STALL               (0                                    ),
     .BUS_PROTECT_GEN_EN        (1                                    ),  // 0: Bus Protection Generator is not present
     .BUS_PROTECT_CHK_EN        (0                                    ),  // 1: Bus Protection Checker is present (ECC/Parity)
     .PROT_TYPE                 (0                                    ),  // 0=Ecc, 1=Simple Parity
     .PROT_RANGE                (CX_RAS_RAM_PROT_RANGE                ), // Number of bits to calculate parity/ECC on
     .PROT_WD                   (ECC_WIDTH                            ),
     .PARITY_MODE               (CX_RAS_PARITY_MODE                   ),
     .PROT_CORRECT_EN           (0                                    ), // 0: no correction on single-errors, 1: correction on single-errors
     .TOTAL_WIDTH               (CC_OB_CCMP_DATA_RAM_ADDR_WD + CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC), // RAM_ADDR_WIDTH + DATA_WIDTH
     .EXCLUDE_PROT_WIDTH        (0                                    ),
     .RAS_DP_PROT_CHK_ID_BASE   ( /* NC */                            ),
     .ADDR_ECC_PROT_EN          (1                                    ),
     .ADDR_LOG_EN               (1                                    ),
     .ADDR_INDEX                (CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC    ),
     .ADDR_WD                   (CC_OB_CCMP_DATA_RAM_ADDR_WD          )
   ) u_eccg (
     .clk                       ( clk                                 ),
     .rst_n                     ( rst_n                               ),
     .din                       ( { s_ccmp_data_ram_addra,
                                    {rcvd_pkt_wr_dwen,
                                    ss_ccmp_data_ram_dina_t,
                                    rcvd_pkt_wr_status_good}}         ),
     .din_prot                  ( {ECC_WIDTH{1'b0}}                   ),
     .dout                      ( /* NC */                            ),
     .dout_prot                 ( eccg_out                            ),
     .en                        ( 1'b1                                ),
     .bypass                    ( 1'b0                                ),
     .stall                     ( 1'b0                                ),
     .stallout                  ( /* Not Connected */                 ),
     .valid_in                  ( !s_ccmp_data_ram_wea_n              ),
     .halt_out                  ( /* Not Connected */                 ),
     .valid_out                 ( /* Not Connected */                 ),
     .halt_in                   (1'b0                                 ),
     .ras_dp_err_inband_kbd_in  (1'b0                                 ),
     .ras_dp_err_inband_kbd_out ( /* Not Connected */                 ),
     .ras_dp_err_log            ( /* Not Connected */                 )
       ,
       .ras_dp_err_inj          (ras_dp_err_inj_core_clk               )
     );


assign ccmp_data_ram_enb_n   = s_ccmp_data_ram_enb_n;
assign ccmp_data_ram_addrb   = s_ccmp_data_ram_addrb;
assign ccmp_data_ram_wea_n   = s_ccmp_data_ram_wea_n;
assign ccmp_data_ram_addra   = s_ccmp_data_ram_addra;
assign ccmp_data_ram_dina  = {eccg_out, {rcvd_pkt_wr_dwen, ss_ccmp_data_ram_dina_t, rcvd_pkt_wr_status_good}};
assign s_ccmp_data_ram_doutb = ccmp_data_ram_doutb;

assign ccmp_data_ram_wea = !ccmp_data_ram_wea_n;
assign ccmp_data_ram_enb = !ccmp_data_ram_enb_n;

wire s_ccmp_data_ram_enb;

delay_n
 #(
  .WD    (                               1)
 ,.N     (CC_OB_CCMP_DATA_RAM_RD_LATENCY+1
         )
) u_dly1_enb (
  .clk       (slv_aclk              )
 ,.rst_n     (slv_aresetn           )
 ,.clear     (                  1'b0)
 ,.din       (~s_ccmp_data_ram_enb_n)
 ,.dout      (s_ccmp_data_ram_enb   )
);


// Read data from RAM contains ECC and data (include extra bits)
logic [CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC-1:0]                                s_ccmp_data_ram_doutb_out_t,ss_chk_delay_out_data_t,ss_chk_delay_out_data;
wire  [NW-1:0]                                                               rcvd_pkt_rd_dwen;
wire  [CORE_DATA_BUS_WD_NP-1:0]                                              rcvd_pkt_rd_data;
wire  [CORE_DATA_BUS_WD-1:0]                                                 rcvd_pkt_rd_data_t;
wire  [CORE_DATA_BUS_WD-1:0]                                                 rcvd_pkt_rd_data_wpar;
wire  [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]                                      s_dly_ccmp_data_ram_addrb_chk, dly_ccmp_data_ram_addrb_out;
wire  [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0]                                      ccmp_data_ram_doutb_dly;

wire                                                                         rcvd_pkt_rd_status_good;
wire                                                                         s_ccmp_data_ram_enb_chk;

// Add a delay after reading from the RAM
delay_n
 #(
  .WD    (CC_OB_CCMP_DATA_RAM_DATA_WD )
 ,.N     (                           1)
) u_dly_data_ram_doutb (
  .clk       (slv_aclk                )
 ,.rst_n     (slv_aresetn             )
 ,.clear     (1'b0                    )
 ,.din       (ccmp_data_ram_doutb     )
 ,.dout      (ccmp_data_ram_doutb_dly )
);

// Read DATA from the RAM which includes the ECC and extract only the data to add parity on it
assign {eccg_rd,s_ccmp_data_ram_doutb_out_t} = ccmp_data_ram_doutb_dly;

delay_n
 #(
  .WD    (                                 1 )
 ,.N     (CC_OB_CCMP_DATA_RAM_RD_LATENCY + 1 )
) u_dly_echk_enb (
  .clk       (slv_aclk                )
 ,.rst_n     (slv_aresetn             )
 ,.clear     (1'b0                    )
 ,.din       (~s_ccmp_data_ram_enb_n  )
 ,.dout      (s_ccmp_data_ram_enb_chk )
);

delay_n
 #(
  .WD ( CC_OB_CCMP_DATA_RAM_ADDR_WD        )
 ,.N  ( CC_OB_CCMP_DATA_RAM_RD_LATENCY + 1 )
) u_dly_echk_ccmp_data_ram_addrb (
  .clk   ( slv_aclk                  )
 ,.rst_n ( slv_aresetn               )
 ,.clear ( 1'b0                      )
 ,.din   ( s_ccmp_data_ram_addrb     )
 ,.dout  ( s_dly_ccmp_data_ram_addrb_chk )
);

// Check the ECC
  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                                        ), // 0: delay_n
    .RESETVAL                  (0                                        ),
    .N_STAGES                  (0                                        ),
    .CAN_STALL                 (0                                        ),
    .RESET_STALL               (0                                        ),
    .BUS_PROTECT_GEN_EN        (0                                        ), // 0: Bus Protection Generator is not present
    .BUS_PROTECT_CHK_EN        (1                                        ), // 1: Bus Protection Checker is present (ECC/Parity)
    .PROT_TYPE                 (0                                        ), // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                (CX_RAS_RAM_PROT_RANGE                    ), // Number of bits to calculate parity/ECC on
    .PROT_WD                   (ECC_WIDTH                                ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE                       ),
    .PROT_CORRECT_EN           (1                                        ), // 0: no correction on single-errors, 1: correction on single-errors
    .TOTAL_WIDTH               (CC_OB_CCMP_DATA_RAM_ADDR_WD + CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC ),
    .EXCLUDE_PROT_WIDTH        (0                                        ),
    .RAS_DP_PROT_CHK_ID_BASE   (`OB_CCMP_DT_RAS_ID                       ),
    .ADDR_ECC_PROT_EN          (1                                        ),
    .ADDR_LOG_EN               (1                                        ),
    .ADDR_INDEX                (CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC        ),
    .ADDR_WD                   (CC_OB_CCMP_DATA_RAM_ADDR_WD              )
  ) u_echk (
    .clk                       ( slv_aclk                                ),
    .rst_n                     ( slv_aresetn                             ),
    .din                       ( {s_dly_ccmp_data_ram_addrb_chk,                // Using the delayed address to be align with the read data
                                 s_ccmp_data_ram_doutb_out_t}            ),
    .din_prot                  ( eccg_rd                                 ),
    .dout                      ( {dly_ccmp_data_ram_addrb_out,
                                  ss_chk_delay_out_data_t}               ), //Data is corrected
    .dout_prot                 ( /* Not Connected */                     ),
    .en                        (1'b1                                     ),
    .bypass                    (1'b0                                     ),
    .stall                     (1'b0                                     ),
    .stallout                  ( /* Not Connected */                     ),
    .valid_in                  ( s_ccmp_data_ram_enb_chk                 ),
    .halt_out                  ( /* Not Connected */                     ),
    .valid_out                 ( /* Not Connected */                     ),
    .halt_in                   (1'b0                                     ),
    .ras_dp_err_inband_kbd_in  (1'b0                                     ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */                     ),
    .ras_dp_err_log            (ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log   )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk                  )
    );

// Extract and detect Error type (correctable) from ras_dp_pipe.log
assign chk_ras_recc_corr_cnt_ob_ccmp_data_pulse  = (ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == CORRECTABLE) &&
                                                    s_ccmp_data_ram_enb_chk && ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log.valid;

// Extract and detect Error type (Uncorrectable) from ras_dp_pipe.log
assign chk_ras_recc_ucorr_cnt_ob_ccmp_data_pulse = (ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log.log[RAS_ERROR_TYPE_INDEX +: RAS_ERROR_TYPE_WD] == UNCORRECTABLE) &&
                                                   s_ccmp_data_ram_enb_chk && ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log.valid;

// Bypass the ECC checker when it is not valid, to avoid inserting 0 in data
//assign ss_chk_delay_out_data = s_ccmp_data_ram_enb_chk ? ss_chk_delay_out_data_t : s_ccmp_data_ram_doutb_out_t;
assign ss_chk_delay_out_data = ss_chk_delay_out_data_t;

// Extract the data bus
assign rcvd_pkt_rd_dwen = ss_chk_delay_out_data[CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC-1:CORE_DATA_BUS_WD_NP+1];
assign rcvd_pkt_rd_data = ss_chk_delay_out_data[1+:CORE_DATA_BUS_WD_NP];
assign rcvd_pkt_rd_status_good = ss_chk_delay_out_data[0];

// Add parity to the DATA
assign rcvd_pkt_rd_data_wpar =   fn_data_w_par(rcvd_pkt_rd_data);

always @(rcvd_pkt_rd_dwen)
begin

  integer i;
  integer j;

  for (i=0; i<NW; i=i+1) begin
    for (j=0; j<DBUS_DWORD_WD_WITH_PAR; j=j+1) begin
      int_rcvd_pkt_mask[i*DBUS_DWORD_WD_WITH_PAR+j] = rcvd_pkt_rd_dwen[i];
    end
  end

end

assign rcvd_pkt_rd_data_t = (rcvd_pkt_rd_data_wpar & int_rcvd_pkt_mask) | (~int_rcvd_pkt_mask & {BUS_N_BYTES{BUS_INIT_BYTE}});

// DATA with parity and no ECC READ from the RAM
assign s_ccmp_data_ram_doutb_out  = {rcvd_pkt_rd_dwen,rcvd_pkt_rd_data_t, rcvd_pkt_rd_status_good};



  // now the dataq_rd_data would be with parity protection
  assign dataq_rd_data_wp =ss_ccmp_data_ram_doutb_t;



  assign ss_ccmp_data_ram_doutb_t  = r_ccmp_data_ram_doutb_out;

wire [OB_CCMP_ALGN_RAM_WD-1:0] s_dly_in;
wire [OB_CCMP_ALGN_RAM_WD-1:0] s_dly_out;

assign s_dly_in = {
           dataq_rd_dv
          ,dataq_rd_eot
          ,dataq_rd_err || r_dataq_rd_err
          ,dataq_rd_tag
          ,latchd_rcvd_pkt_hdr
          ,lookup_resp_tlp_byte_len
          ,lookup_resp_tlp_low_addr
          ,lookup_resp_tlp_4rd
          ,lookup_resp_tlp_rreq_dma
          ,lookup_resp_tlp_rreq_dma_chan
         };


localparam L_DLY1_N = CC_OB_CCMP_DATA_RAM_RD_LATENCY + CC_OB_CCMP_DATA_RAM_REGIN + 1
                        + 1
                        + 1
                      ;

delay_n
 #(
  .WD ( OB_CCMP_ALGN_RAM_WD )
 ,.N  ( L_DLY1_N            )
) u_dly1 (
  .clk   ( slv_aclk    )
 ,.rst_n ( slv_aresetn )
 ,.clear ( 1'b0        )
 ,.din   ( s_dly_in    )
 ,.dout  ( s_dly_out   )
);

delay_n
 #(
  .WD ( CC_OB_CCMP_DATA_RAM_ADDR_WD        )
 ,.N  ( CC_OB_CCMP_DATA_RAM_RD_LATENCY + 1
)
) u_dly_ccmp_data_ram_addrb (
  .clk   ( slv_aclk                  )
 ,.rst_n ( slv_aresetn               )
 ,.clear ( 1'b0                      )
 ,.din   ( s_ccmp_data_ram_addrb     )
 ,.dout  ( s_dly_ccmp_data_ram_addrb )
);

assign {
         s_dly_dataq_rd_dv
        ,s_dly_dataq_rd_eot
        ,s_dly_dataq_rd_err
        ,s_dly_dataq_rd_tag
        ,s_dly_dataq_rd_hdr
        ,s_dly_lookup_resp_tlp_byte_len
        ,s_dly_lookup_resp_tlp_low_addr
        ,s_dly_lookup_resp_tlp_4rd
        ,s_dly_lookup_resp_tlp_rreq_dma
        ,s_dly_lookup_resp_tlp_rreq_dma_chan
       } = s_dly_out;

wire    [DELAY_WD -1:0]                   s_pipe_in;
wire    [DELAY_WD -1:0]                   s_pipe_out;
wire    [ECC_WIDTH -1:0]                  s_pipe_ecc;
wire    [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0] s_pipe_ccmp_data_ram_addrb;
wire  stall_in;


assign s_pipe_in_hdr  = {s_dly_dataq_rd_hdr, s_dly_dataq_rd_tag, s_dly_lookup_resp_tlp_byte_len, s_dly_lookup_resp_tlp_low_addr, s_dly_lookup_resp_tlp_4rd
                       , s_dly_lookup_resp_tlp_rreq_dma, s_dly_lookup_resp_tlp_rreq_dma_chan
                       };
assign s_pipe_in_data = {dataq_rd_data_wp, s_dly_dataq_rd_err, s_dly_dataq_rd_eot, s_dly_dataq_rd_dv}; // Data is protected with Parity

assign s_pipe_in = {s_pipe_in_hdr, s_pipe_in_data};

ram_latency_pipe
 #(
   .PIPE_WIDTH        (LATENCY_PIPE_WIDTH )
  ,.PIPE_INPUT_REG    (                  0)
  ,.PIPE_LATENCY      (L_DLY1_N           )
  ,.PIPE_EXTRA_STORAGE(                  1)
  ,.HALT_FANOUT       (L_N_EXPLICIT_FANOUT)
) u_pdly1_ltcy (
  /* ------ Inputs ------ */
   .core_clk           (slv_aclk         )
  ,.core_rst_n         (slv_aresetn      )

  ,.halt_in            (align_halt       )
  ,.pipe_in_data_valid (dataq_rd_dv      )
  ,.pipe_in_data       ({s_dly_ccmp_data_ram_addrb, s_pipe_in})

  /* ------ Outputs ------ */
  ,.halt_out           (sbc_halt         )
  ,.pipe_out_data_valid(/* UNCONNECTED */)
  ,.pipe_out_data      ({s_pipe_ccmp_data_ram_addrb, s_pipe_out})
);

assign {s_pipe_out_hdr, s_pipe_out_data} = s_pipe_out;

assign piped_dataq_rd_data = s_pipe_out_data[DELAY_DATA_WD -1:3];


assign  piped_rd_data_dv            = s_pipe_out_data[0];
assign  piped_rd_data_eot           = s_pipe_out_data[1];
assign  piped_rd_data_err           = s_pipe_out_data[2];
assign  piped_rd_data_ram_addrb     = s_pipe_ccmp_data_ram_addrb;
assign  piped_rd_hdr                = s_pipe_out_hdr[DELAY_HDR_WD -1 : DELAY_HDR_WD - HDR_WD]  ;
assign  piped_rd_pkt_tag            = s_pipe_out_hdr[DELAY_HDR_WD - HDR_WD -1 : DELAY_HDR_WD - HDR_WD - MAX_OUT_TAG_PW]  ;
assign  piped_rd_pkt_byte_len       = s_pipe_out_hdr[DELAY_HDR_WD - HDR_WD - MAX_OUT_TAG_PW -1 : DELAY_HDR_WD - HDR_WD - MAX_OUT_TAG_PW - MAX_RD_SIZE_PW]  ;
assign  piped_rd_pkt_low_addr       = s_pipe_out_hdr[DELAY_HDR_WD - HDR_WD - MAX_OUT_TAG_PW  - MAX_RD_SIZE_PW -1 : DELAY_HDR_WD - HDR_WD - MAX_OUT_TAG_PW - MAX_RD_SIZE_PW -7]  ;
assign piped_rd_pkt_4rd             = s_pipe_out_hdr[DELAY_HDR_WD - HDR_WD - MAX_OUT_TAG_PW  - MAX_RD_SIZE_PW -7 -1 : (DMA_ENABLE_VALUE) ? 6 : 0];
assign  piped_rd_pkt_rreq_dma       = s_pipe_out_hdr[DELAY_HDR_WD - HDR_WD - MAX_OUT_TAG_PW  - MAX_RD_SIZE_PW -7 -1 -1 : 3];
assign  piped_rd_pkt_rreq_dma_chan  = s_pipe_out_hdr[DELAY_HDR_WD - HDR_WD - MAX_OUT_TAG_PW  - MAX_RD_SIZE_PW -7 -1 -1 -3 : 0];

assign  piped_rd_dwen               = piped_dataq_rd_data[SBUF_DWEN_HIGH : SBUF_DWEN_LOW]  ;
assign  piped_rd_data               = piped_rd_data_dv ? piped_dataq_rd_data[SBUF_DATA_HIGH: SBUF_DATA_LOW] : BUS_INIT;
assign  piped_rd_status_good        = piped_dataq_rd_data[0];

// -------------------- function declarations ---------------------------------
  // Data without parity
  function automatic logic [CORE_DATA_BUS_WD_NP-1:0] fn_data_wo_par;
    input [CORE_DATA_BUS_WD-1:0] s_data_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS_S; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_data_wo_par[i *CX_RAS_PROT_RANGE +j] = s_data_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction

  function automatic [NUM_DATA_PAR_BLOCKS_S-1:0] fn_prot_chkin_dt;
    input [CORE_DATA_BUS_WD-1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS_S; i=i+1) begin
        fn_prot_chkin_dt[i] = s_data_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction


  // Data with parity
  function automatic logic [CORE_DATA_BUS_WD-1:0] fn_data_w_par;
    input [CORE_DATA_BUS_WD_NP-1:0] s_data_wo_par;

    integer i;
    reg [NUM_DATA_PAR_BLOCKS_S-1:0][CX_RAS_PROT_RANGE-1:0] i_data_wo_par;
    reg [NUM_DATA_PAR_BLOCKS_S-1:0][CX_RAS_PROT_RANGE:0]   i_data_w_par;
    //reg [CX_RAS_PROT_RANGE-1:0] myparity;
    reg parity_bit;

    begin
      i_data_wo_par = s_data_wo_par;
      for (i=0; i<(NUM_DATA_PAR_BLOCKS_S); i=i+1) begin
         parity_bit = CX_RAS_PARITY_MODE ? !(^(i_data_wo_par[i])) : ^(i_data_wo_par[i]);
        i_data_w_par[i] = {parity_bit,i_data_wo_par[i]};
        //myparity[i] =parity_bit;  // only for debug
      end
      fn_data_w_par = i_data_w_par;
      //$display("Parity is : 0x%8h, data = 0x%8h",myparity,i_data_w_par);
    end
  endfunction


endmodule

