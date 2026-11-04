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
// ---    $Revision: #29 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_axi_cpl_comp_ctl.sv#29 $
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

module DWC_pcie_axi_cpl_comp_ctl
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DW_sbc_cdc_pkg::*;
  #(
  parameter                                TP = `TP                                /* Clock to Q delay (simulator insurance)                                 */
 ,parameter                                NW = `CX_NW                             /* Number of 32-bit dwords handled by the datapath each clock.            */
 ,parameter          CC_RADMX_COMPOSER_HDR_WD = `CC_RADMX_COMPOSER_HDR_WD          /* A header macro                                                         */
 ,parameter                        MAX_IN_TAG = `CX_MAX_TAG                        /* Number of MAX TAG that PKTs can come in with                           */
 ,parameter                     MAX_IN_TAG_PW = `CX_LUT_PTR_WIDTH                  /* Pointer of CX_MAX_TAG                                                  */
 ,parameter                       MAX_OUT_TAG = `CC_MAX_SLV_TAG                    /* Number of MAX TAG that PKTs go out with                                */
 ,parameter                    MAX_OUT_TAG_PW = `CC_MAX_SLV_TAG_PW                 /* Pointer of MAX_OUT_TAG                                                 */
 ,parameter                       MAX_RD_SIZE = `CC_SLV_RD_REQ_SIZE                /* MAX number of read request size                                        */
 ,parameter                    MAX_RD_SIZE_PW = `CC_SLV_RD_REQ_SIZE_PW             /* Pointer size for MAX rd size                                           */
 ,parameter                  CORE_DATA_BUS_WD = `CC_CORE_DATA_BUS_WD
 ,parameter               CORE_DATA_BUS_WD_NP = `PCIE_CORE_DATA_BUS_WD
 ,parameter                         SLV_ID_WD = `CC_SLV_BUS_ID_WIDTH + 1
 ,parameter       CC_OB_CCMP_DATA_RAM_DATA_WD = `CC_OB_CCMP_DATA_RAM_DATA_WD       /* SBUG buffer stores data and dword enable and flag of data with payload */
 ,parameter CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC = `CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC /* SBUG buffer stores data and dword enable and flag of data with payload */
 ,parameter       CC_OB_CCMP_DATA_RAM_ADDR_WD = `CC_OB_CCMP_DATA_RAM_ADDR_WD       /* COMPOSER DATAQ pointer width                                           */
 ,parameter            CC_OB_CCMP_DATA_RAM_DP = `CC_OB_CCMP_DATA_RAM_DP            /* COMPOSER DATAQ pointer depth                                           */
 ,parameter                       SBUF_SEG_DP = `CC_RADMX_COMPOSER_SEG_DP          /* COMPOSER DATAQ depth per segment                                       */
 ,parameter            DBUS_DWORD_WD_WITH_PAR = `CC_DBUS_DWORD_WD_WITH_PAR
 ,parameter                CC_AMBA_TLP_SEQ_WD = `CC_AMBA_TLP_SEQ_WD
 ,parameter                            CX_NVC = `CX_NVC
 ,parameter                       CX_NVC_LOG2 = `CX_NVC_LOG2
 ,parameter                     CC_ORDRB_NIDO = `CC_ORDRB_NIDO
 ,parameter                  CC_ORDRB_NIDO_WD = `CC_ORDRB_NIDO_WD
 ,parameter          CC_NUM_DMA_RD_CHAN_WIDTH = `CC_NUM_DMA_RD_CHAN_WIDTH
 ,parameter                 CX_RAS_PROT_RANGE = `CX_RAS_PROT_RANGE
 ,parameter                CX_RAS_PARITY_MODE = `CX_RAS_PARITY_MODE
 ,parameter             CX_RAS_RAM_PROT_RANGE = `CX_RAS_RAM_PROT_RANGE
 ,parameter type P_APPTAG_PTR_TYPE  = logic [MAX_OUT_TAG_PW -1:0]
 ,parameter type P_WIRETAG_PTR_TYPE = logic [MAX_IN_TAG_PW -1:0]
 ,parameter type P_SEGMENT_PTR_TYPE = logic [MAX_IN_TAG_PW -1:0]
 ,parameter type P_HEADER_TYPE      = logic [CC_RADMX_COMPOSER_HDR_WD -1:0]
 ,parameter type P_AXI_ID_TYPE      = logic [SLV_ID_WD -1:0]
  ) 
                                  (
  input  logic                                    clk
 ,input  logic                                    slv_aclk
 ,input  logic                                    rst_n
 ,input  logic                                    slv_aresetn

 ,input  logic                                    rcvd_pkt_hv                    /* Start of a received PKT                                        */
 ,input  logic                                    rcvd_pkt_dv                    /* Received data valid                                            */
 ,input  logic                          [NW -1:0] rcvd_pkt_dwen                  /* Received data dword enable                                     */
 ,input  logic                                    rcvd_pkt_eot                   /* End of the receiving                                           */
 ,input  logic                                    rcvd_pkt_err                   /* Received errors resulted pkt to be aborted                     */
 ,input  logic            [CORE_DATA_BUS_WD -1:0] rcvd_pkt_data                  /* Received PKT data                                              */
 ,input                             P_HEADER_TYPE rcvd_pkt_hdr                   /* Received PKT header information                                */
 ,input  logic                                    rcvd_pkt_last                  /* This indicates the last pkt for this current tag. This signal
                                                                                      is not asserted with eot only when response device does
                                                                                      split completions                                            */

 ,input  logic                                    rcvd_pkt_status_good           /* This indicates that the response is in good status, this is not..
                                                                                      an abort pkt but with non unsuccessful status                */
 ,input                        P_WIRETAG_PTR_TYPE rcvd_pkt_tag                   /* Input PKT's tag (wiretag)                                      */
 ,input                         P_APPTAG_PTR_TYPE rcvd_pkt_apptag                /* Input PKT's apptag                                             */
 ,input                  [CC_AMBA_TLP_SEQ_WD-1:0] rcvd_pkt_pseq                  /* Sequence number for last posted request before completion      */
 ,input                                           rcvd_pkt_hold_preq             /* Completion held back by previous posted request                */

 ,output logic                                    err_tag_consumed_halt
 ,input  logic                                    tag_consumed                   /* Valid signal for the following signals                         */
 ,input  logic                                    consumed_last_tag              /* indicate the begining of a tag being active                    */
 ,input  logic                                    consumed_4rd                   /* indicate a non posted read packet has been transmited          */
 ,input  logic                           [3 -1:0] consumed_rreq_dma              /* DMA Write read request type                                    */
 ,input  logic                           [3 -1:0] consumed_rreq_dma_chan         /* DMA Write channel number                                       */
 ,input  logic              [MAX_RD_SIZE_PW -1:0] consumed_tlp_byte_len          /* indicate the TLP length that is decompsed                      */
 ,input  logic                           [7 -1:0] consumed_tlp_low_addr          /* indicate the TLP low_addr that is decompsed                    */
 ,input                             P_AXI_ID_TYPE consumed_axi_id                /* Original request AXI ID                                        */
 ,input                         P_APPTAG_PTR_TYPE consumed_out_tag               /* Application generated tag                                      */
 ,input                        P_WIRETAG_PTR_TYPE consumed_in_tag                /* Tag used on the wire                                           */
 ,input  logic     [CC_RADMX_COMPOSER_HDR_WD-1:0] consumed_tlp_hdr

 ,input  logic                                    in_cycle_halt                  /* Halt in cycle by cycle of the read from the segment buffer     */

 ,input  logic                                    cpl_timeout                    /* CPL is timeout                                                 */
 ,input                             P_HEADER_TYPE cpl_timeout_hdr                /* timeout request header                                         */
 ,input                        P_WIRETAG_PTR_TYPE cpl_timeout_tag                /* timeout request wire tag                                       */
 ,input                         P_APPTAG_PTR_TYPE cpl_timeout_apptag             /* timeout request apptag                                         */

 ,input  logic                                    cfg_ras_recc_ob_ccmp_data_correct
 ,output logic                                    axi_ras_recc_corr_cnt_ob_ccmp_data_pulse
 ,output logic                                    axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse
 ,output logic [CC_OB_CCMP_DATA_RAM_ADDR_WD -1:0] axi_ras_recc_cnt_ob_ccmp_data_addr
 ,output logic                                    axi_ras_par_ob_cpl_comp_dt_pulse
 ,output ras_dp_err_log_t                         ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log
 ,output ras_dp_err_log_t                         ob_cpl_comp_dt_ras_dp_err_log
 ,input  ras_dp_err_inj_t                         axi_bridge_ras_dp_err_inj_core_clk
 ,input  ras_dp_err_inj_t                         ras_dp_err_inj_slv_aclk
 ,input  ras_dp_err_inj_t                         core_clk_ordrb_ras_dp_err_inj

 ,input  logic                                    slv_rsp_cycle_halt
 ,input  logic                                    consumed_tag_from_nprf
 ,input  logic                   [SLV_ID_WD -1:0] nprf_id
 ,input  P_APPTAG_PTR_TYPE                        nprf_tag

 ,output logic                                    cmposed_pkt_dv              /* Start of a composed completion                                 */
 ,output logic                                    cmposed_pkt_hv              /* Received composed completion data is valid                     */
 ,output logic                                    cmposed_pkt_eot             /* End of a composed completion                                   */
 ,output logic                                    cmposed_pkt_4rd             /* Completion is for a nonposted read                             */
 ,output logic                           [3 -1:0] cmposed_pkt_rreq_dma        /* DMA Write response request type                                */
 ,output logic                           [3 -1:0] cmposed_pkt_rreq_dma_chan   /* DMA Write response channel number                              */
 ,output                            P_HEADER_TYPE cmposed_pkt_hdr             /* Hdr info  of a composed completion                             */
 ,output logic              [MAX_RD_SIZE_PW -1:0] cmposed_pkt_byte_len        /* Received response dword length                                 */
 ,output logic                           [7 -1:0] cmposed_pkt_low_addr        /* Received response dword length                                 */
 ,output logic                          [NW -1:0] cmposed_pkt_dwen            /* Received data dword enable                                     */
 ,output logic            [CORE_DATA_BUS_WD -1:0] cmposed_pkt_data            /* Received data                                                  */
 ,output logic                                    cmposed_pkt_err             /* Received err, needs to be aborted, this causes a pointer rewind*/
 ,output                        P_APPTAG_PTR_TYPE cmposed_pkt_tag             /* Received TAG                                                   */

 ,output logic                                    tag_released                /* Released tag for recycle is valid                              */
 ,output                       P_WIRETAG_PTR_TYPE released_tag                /* Released tag for recycle after all responses have been received*/
 ,output logic                                    lookup_err                  /* A response with wrong tag has received                         */
 ,output logic                                    cmp_sb_init_done

 ,input  logic [CC_OB_CCMP_DATA_RAM_DATA_WD -1:0] ccmp_data_ram_doutb         /* Ram read data                                                  */
 ,output logic [CC_OB_CCMP_DATA_RAM_ADDR_WD -1:0] ccmp_data_ram_addra         /* Ram port A address (write interface)                           */
 ,output logic [CC_OB_CCMP_DATA_RAM_ADDR_WD -1:0] ccmp_data_ram_addrb         /* Ram port B address (read interface)                            */
 ,output logic [CC_OB_CCMP_DATA_RAM_DATA_WD -1:0] ccmp_data_ram_dina          /* Ram write data                                                 */
 ,output logic                                    ccmp_data_ram_enb           /* Ram port B enable (read enable)                                */
 ,output logic                                    ccmp_data_ram_wea           /* Ram Port A write enable                                        */

 ,output                        P_APPTAG_PTR_TYPE slv_lookup_apptag
 ,output logic                                    slv_pop_wiretag
 ,input                        P_SEGMENT_PTR_TYPE slv_lookup_wiretag
 ,input  logic                                    slv_lookup_wiretag_is_last

 ,output                       P_SEGMENT_PTR_TYPE rdr_lookup_wiretag
 ,output logic                                    rdr_pop_wiretag
  // ---------------------------------------------------------------------------
  // Completed posted request sequence number interface
 ,input                  [CC_AMBA_TLP_SEQ_WD-1:0] ib_last_presp_rpseq_per_vc [       CX_NVC-1:0]
 ,input                              [CX_NVC-1:0] trgt1_p_xfer_pend_per_vc
);

/* ======================================================================================================================== *
 * ---------------------- Local parameters ------------------------                                                         *
 * ======================================================================================================================== */

/*****
 * SBC configuration
 *****/
localparam                NUM_SEGMENTS = MAX_OUT_TAG                                            ;
localparam             NUM_SEGMENTS_PW = MAX_OUT_TAG_PW                                         ;
localparam                NUM_WIRETAGS = MAX_IN_TAG+1                                           ;
localparam             NUM_WIRETAGS_PW = MAX_IN_TAG_PW                                          ;
localparam                  HOLD_RADDR = 1                                                      ;
localparam     GENERATE_STARTEND_ADDRS = 1                                                      ;


/*****
 * SBC data boundaries
 *****/
localparam                      PAR_WD = CORE_DATA_BUS_WD - CORE_DATA_BUS_WD_NP                 ;
localparam              SBUF_DWEN_HIGH = CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC + PAR_WD - 1         ;
localparam               SBUF_DWEN_LOW = SBUF_DWEN_HIGH - NW + 1                                ;
localparam              SBUF_DATA_HIGH = SBUF_DWEN_LOW - 1                                      ;
localparam               SBUF_DATA_LOW = SBUF_DATA_HIGH - CORE_DATA_BUS_WD + 1                  ;
localparam                  SBUF_WC_PW = $clog2(SBUF_SEG_DP) + 1                                ;
localparam type          P_SEG_WC_TYPE = logic [SBUF_WC_PW -1:0]                                ;

/*****
 * Composer header data boundaries
 *****/

  localparam COMPOSER_HDR_CPLSGMT_HIGH = CC_RADMX_COMPOSER_HDR_WD  - 1;
  localparam COMPOSER_HDR_CPLSGMT_LOW  = COMPOSER_HDR_CPLSGMT_HIGH - 7;
  localparam COMPOSER_HDR_DSTSGMT_HIGH = COMPOSER_HDR_CPLSGMT_LOW  - 1;
  localparam COMPOSER_HDR_DSTSGMT_LOW  = COMPOSER_HDR_DSTSGMT_HIGH - 8;
  localparam COMPOSER_HDR_TLPPRFX_HIGH = 0                                                      ;
  localparam  COMPOSER_HDR_TLPPRFX_LOW = COMPOSER_HDR_DSTSGMT_LOW                               ;
  localparam   COMPOSER_HDR_TLPLN_HIGH = 0                                                      ;
  localparam    COMPOSER_HDR_TLPLN_LOW = COMPOSER_HDR_TLPPRFX_LOW                               ;
  localparam   COMPOSER_HDR_REQID_HIGH = 0                                                      ;
  localparam    COMPOSER_HDR_REQID_LOW = COMPOSER_HDR_TLPLN_LOW                                 ;
  localparam    COMPOSER_HDR_LOCK_HIGH = COMPOSER_HDR_REQID_LOW - 1                             ;
  localparam     COMPOSER_HDR_LOCK_LOW = COMPOSER_HDR_LOCK_HIGH                                 ;
  localparam  COMPOSER_HDR_TABORT_HIGH = COMPOSER_HDR_LOCK_LOW - 1                              ;
  localparam   COMPOSER_HDR_TABORT_LOW = COMPOSER_HDR_TABORT_HIGH                               ;
  localparam      COMPOSER_HDR_TD_HIGH = COMPOSER_HDR_TABORT_LOW - 1                            ;
  localparam       COMPOSER_HDR_TD_LOW = COMPOSER_HDR_TD_HIGH                                   ;
  localparam      COMPOSER_HDR_TC_HIGH = COMPOSER_HDR_TD_LOW - 1                                ;
  localparam       COMPOSER_HDR_TC_LOW = COMPOSER_HDR_TC_HIGH - 2                               ;
  localparam    COMPOSER_HDR_ATTR_HIGH = COMPOSER_HDR_TC_LOW - 1                                ;
  localparam     COMPOSER_HDR_ATTR_LOW = COMPOSER_HDR_ATTR_HIGH - `FLT_Q_ATTR_WIDTH + 1;
  localparam     COMPOSER_HDR_ATS_HIGH = COMPOSER_HDR_ATTR_LOW - 1                              ;
  localparam      COMPOSER_HDR_ATS_LOW = COMPOSER_HDR_ATS_HIGH - 1                              ;
  localparam     COMPOSER_HDR_BCM_HIGH = (`ATS_RX_ENABLE_VALUE == 1) ? COMPOSER_HDR_ATS_LOW - 1
                                                                     : COMPOSER_HDR_ATTR_LOW - 1;
  localparam      COMPOSER_HDR_BCM_LOW = COMPOSER_HDR_BCM_HIGH                                  ;
  localparam    COMPOSER_HDR_ECRC_HIGH = COMPOSER_HDR_BCM_LOW - 1                               ;
  localparam     COMPOSER_HDR_ECRC_LOW = COMPOSER_HDR_ECRC_HIGH                                 ;
  localparam      COMPOSER_HDR_EP_HIGH = COMPOSER_HDR_ECRC_LOW - 1                              ;

  localparam           ERR_REQ_FIFO_DP = `CC_AXI_CPL_COMP_ERR_REQ_FIFO_DP                       ; 
  localparam        ERR_REQ_FIFO_DP_P1 = ERR_REQ_FIFO_DP + 1                                    ;
  localparam           ERR_REQ_FIFO_AW = $clog2(ERR_REQ_FIFO_DP)                                ; 
  localparam                SYNC_DEPTH = `CX_PCIE_SYNC_DEPTH                                    ;

  localparam [8:0]       BUS_INIT_BYTE = CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000       ;
localparam                 BUS_N_BYTES = NW * 4                                                 ;
localparam [CORE_DATA_BUS_WD-1:0] BUS_INIT = {BUS_N_BYTES{BUS_INIT_BYTE}}                       ;

/*****
 * BCM65 transport delay parameters
 * For CPL timeout
 *****/
localparam integer     REG_DELAY_DENOM = 1000                                                   ;
localparam integer      REG_DELAY_TIME = `TP * REG_DELAY_DENOM                                  ;

  localparam       NUM_DATA_PAR_BLOCKS = CORE_DATA_BUS_WD_NP / CX_RAS_PROT_RANGE                ;
  localparam                 ECC_WIDTH = CC_OB_CCMP_DATA_RAM_DATA_WD
                                           - CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC                  ;
localparam             OB_CCMP_DATA_WD = CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC + PAR_WD             ;

localparam             OB_CCMP_DT_WD  =                                            CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC + PAR_WD
                                          ;

localparam type LP_SEG_PTR_2_WC_LUT_TYPE = logic [NUM_WIRETAGS -1:0] [SBUF_WC_PW -1:0];

localparam                      L_WTWD = (MAX_IN_TAG == 0) ? 1 : $clog2(MAX_IN_TAG+1)           ;

localparam         L_N_EXPLICIT_FANOUT = 5 ;

localparam  PKT_DATA_WD =                               CORE_DATA_BUS_WD;

/* ======================================================================================================================== *
 * ---------------------- Type definitions ------------------------                                                         *
 * ======================================================================================================================== */
typedef enum logic {
  E_WR_IDLE = 1'b0
 ,E_WRITING = 1'b1
} wrState_e;

typedef enum logic [1:0] {
  E_KOI = 2'b00 // Keep on idle
 ,E_ITW = 2'b01 // Idle to writing
 ,E_KOW = 2'b10 // Keep on writing
 ,E_WTI = 2'b11 // Writing to idle
} wrTransition_e;

typedef enum logic [2:0] {
  E_WR_NO_ACTION  = 3'b000
 ,E_WR_START      = 3'b001
 ,E_WR_START_KEEP = 3'b010
 ,E_WR_PUSH       = 3'b011
 ,E_WR_KEEP       = 3'b100
 ,E_WR_NOR_DROP   = 3'b101
 ,E_WR_ERR_DROP   = 3'b110
} wrqStat_e;

typedef struct packed {
  logic                            pkt_hv           ;
  logic                            pkt_dv           ;
  logic                            pkt_eot          ;
  P_HEADER_TYPE                    pkt_hdr          ;
  logic         [PKT_DATA_WD -1:0] pkt_data         ;
  logic                  [NW -1:0] pkt_dwen         ;
  logic                            pkt_4rd          ;
  logic                   [3 -1:0] pkt_rreq_dma     ;
  logic                   [3 -1:0] pkt_rreq_dma_chan;
  logic      [MAX_RD_SIZE_PW -1:0] pkt_byte_len     ;
  logic                   [7 -1:0] pkt_low_addr     ;
  logic                            pkt_err          ;
  P_APPTAG_PTR_TYPE                pkt_tag          ;
} respDataQ_s;

typedef struct packed {
  logic                            pkt_hv           ;
  logic                            pkt_dv           ;
  logic                            pkt_eot          ;
  P_HEADER_TYPE                    pkt_hdr          ;
  logic    [CORE_DATA_BUS_WD -1:0] pkt_data         ; /* <<< RAS = different pkt_data width */
  logic                  [NW -1:0] pkt_dwen         ;
  logic                            pkt_4rd          ;
  logic                   [3 -1:0] pkt_rreq_dma     ;
  logic                   [3 -1:0] pkt_rreq_dma_chan;
  logic      [MAX_RD_SIZE_PW -1:0] pkt_byte_len     ;
  logic                   [7 -1:0] pkt_low_addr     ;
  logic                            pkt_err          ;
  P_APPTAG_PTR_TYPE                pkt_tag          ;
} respDataQ_ras_s;

typedef struct packed {
  logic                            w_wen            ;
  logic     [NUM_WIRETAGS_PW -1:0] w_seg_num        ;
  logic                            w_start          ;
  logic                            w_keep           ;
  logic                            w_drop           ;
} wrDataQ_s;

typedef struct packed {
  logic koi_idle;               // Keep on idle
  logic koi_one_beat;           // Write 1 beat
  logic koi_no_beats;           // Do not write 1 beat pkt (err)
  logic itw_start_pwtag;        // Start writing
  logic kow_stay_vwtag_idle;    // Write in progress but no data in this cycle
  logic kow_stay_vwtag_active;  // Write in progress
  logic kow_pop_vwtag;          // Write in progress and at final beat of segment (write completed at vwtag)
  logic kow_start_vwtag_idle;   // Write in progress, switched to new segment but no data this cycle
  logic kow_start_vwtag_stalld; // Must ignore incoming data because no space in segmented buffer (err conditions only)
  logic kow_start_vwtag_active; // Write in progress, switched to new segment
  logic wti_err;                // Write aborted
  logic wti_keep;               // Write completed at pwtag
} wrHint_s;

typedef struct packed {
  logic                            hv;
  logic                            dv;
  logic                  [NW -1:0] dwen;
  logic                            eot;
  logic                            err;
  logic [PKT_DATA_WD -1:0]         data;
  P_HEADER_TYPE                    hdr;
  logic                            last;
  logic                            status_good;
  P_WIRETAG_PTR_TYPE               tag;
  P_APPTAG_PTR_TYPE                apptag;
  logic   [CC_AMBA_TLP_SEQ_WD-1:0] pseq;
  logic                            hold_preq;
  logic                            err_req;
} rcvdPkt_s;

typedef logic [MAX_OUT_TAG -1:0]   atagBitLUT_t;
typedef logic [NUM_WIRETAGS -1:0]  wtagBitLUT_t;

typedef P_APPTAG_PTR_TYPE          atagPtr_t;
typedef logic [NUM_WIRETAGS_PW :0] atagCount_t;

typedef struct packed {
  logic       valid;
  atagCount_t count;
} atagCount_s;

typedef struct packed {
  logic     active;
  atagPtr_t apptag;
} wtagInfo_s;


/*  ======================================================================================================================== *
 *  ---------------------- Internal signals------------------------                                                          *
 *  ======================================================================================================================== */

/*****
 * Internal RAS signals
 *****/
logic                          [ECC_WIDTH -1:0] gen_pkt_ecc                              ;
logic                          [ECC_WIDTH -1:0] gen_pkt_ecc_d                            ;
logic  [CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC -1:0] chk_delay_out_data                       ;
logic [CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC -1:0]  ss_chk_delay_out_data                    ;
logic [CC_OB_CCMP_DATA_RAM_ADDR_WD -1:0]        s_sbc_ram_addrb                          ;
logic                     [OB_CCMP_DATA_WD-1:0] s_chk_delay_out_data                     ;
logic                                           cfg_ras_recc_ob_ccmp_data_correct_n      ;
logic                                           chk_ras_recc_corr_cnt_ob_ccmp_data_pulse ;
logic                                           chk_ras_recc_ucorr_cnt_ob_ccmp_data_pulse;

/*****
 * Core clocked sbc write stimulus
 *****/
logic                                           dataq_wr_en                              ;
logic                                           dataq_wr_start                           ;
logic                                           dataq_wr_keep                            ;
logic                                           dataq_wr_drop                            ;
P_SEGMENT_PTR_TYPE                              dataq_wr_seg_num                         ;
logic  [CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC -1:0] dataq_wr_data                            ;
logic  [OB_CCMP_DT_WD-1:0]                      dataq_wr_data_s                          ;

logic                          [ECC_WIDTH -1:0] dataq_wr_ecc                             ;

logic                                           int_dataq_wr_en                          ;
logic                                           int_dataq_wr_start                       ;
logic                                           int_dataq_wr_keep                        ;
logic                                           int_dataq_wr_drop                        ;
P_SEGMENT_PTR_TYPE                              int_dataq_wr_seg_num                     ;
logic  [CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC -1:0] int_dataq_wr_data                        ;
logic  [OB_CCMP_DT_WD-1:0]                      int_dataq_wr_data_s                      ;  // DATA_NOECC + PAR_WD when !CX_AXI_OB_MULTICOMPOSER

logic                          [ECC_WIDTH -1:0] int_dataq_wr_ecc                         ;

/*****
 * AXI clocked sbc read stimulus
 *****/
logic                                           dataq_rd_en_rdr                          ;
P_APPTAG_PTR_TYPE                               dataq_rd_apptag_rdr                      ;
logic                    [NUM_WIRETAGS_PW -1:0] dataq_rd_seg_num_rdr                     ;
logic                                           dataq_rd_eot_rdr                         ;
logic                                           dataq_rd_dv_rdr                          ;
logic                                           dataq_rd_err_rdr                         ;

/*****
 * Core-side packet status tracking
 *****/
logic  [NUM_SEGMENTS -1:0]                                latchd_req_flushed             ; /* Used to flush an app request based on an error completion      */
logic  [NUM_SEGMENTS -1:0]                                latchd_req_timedout            ;
logic  [NUM_SEGMENTS -1:0][CC_RADMX_COMPOSER_HDR_WD -1:0] latchd_rcvd_pkt_hdr            ; /* Received PKT header information                                */
logic  [NUM_SEGMENTS -1:0]      [CC_AMBA_TLP_SEQ_WD -1:0] latchd_rcvd_pkt_pseq           ; /* Received posted request sequence number information            */
logic  [NUM_SEGMENTS -1:0]                                latchd_rcvd_pkt_hold_preq      ; /* Received hold status (waiting for outstanding P request)       */
logic  [NUM_SEGMENTS -1:0]                                latchd_rcvd_pkt_pseq_valid     ;

/*****
 * Core clocked write status tracking
 *****/
logic                        [MAX_OUT_TAG -1:0] cmpose_done_ary                          ;
logic                                           segment_busy                             ;
logic                                           segment_full                             ;
logic                                           composed_seg                             ;
P_APPTAG_PTR_TYPE                               composed_seg_num                         ;
logic                                           timeout_queue_halt                       ;
P_APPTAG_PTR_TYPE                               lookup_outtag_4cpl_timeout               ; /* Application TAG to identify  a timeout request                 */
P_APPTAG_PTR_TYPE                               update_tag                               ; /* Application TAG to identify one particular request             */
logic                                           update_done_ary                          ;
logic                                           lookup_last_resp_4outtag                 ;
logic                                           lookup_last_4cpl_timeout                 ;
logic                                           intag_released                           ;
logic                                           intag_released_d                         ;
P_WIRETAG_PTR_TYPE                              int_released_tag                         ; /* Released tag for recycle after all responses have been received*/

P_APPTAG_PTR_TYPE                               r_composed_atag                          ;
logic                                           r_composed_atag_vld                      ;

P_WIRETAG_PTR_TYPE                              s_composed_wtag    , r_composed_wtag_d    ;
logic                                           s_composed_wtag_vld, r_composed_wtag_vld_d;
logic                         [SBUF_WC_PW -1:0] r_composed_wtag_len_d                     ; /* ^                                                             */

P_APPTAG_PTR_TYPE                               s_hdof_atag                              ;
logic                                           s_hdof_atag_vld                          ;

LP_SEG_PTR_2_WC_LUT_TYPE                        r_wc, r_wc_w, s_wc, s_wc_w               ; /* Write-side word count tracking                                 */
wrDataQ_s                                       s_dataq_wr                               ; /* ^                                                              */
wrDataQ_s                                       r_dataq_wr                               ; /* ^                                                              */

/*****
 * Core clocked received packet data path
 *****/
logic rcvd_pkt_no_err_d;

/*****
 * Core clocked received packet parity check
 *****/
logic                   [CORE_DATA_BUS_WD -1:0] int_rcvd_pkt_data_wpar                   ;
logic                   [PKT_DATA_WD -1:0]      int_rcvd_pkt_data_wpar_s                 ;
logic                [CORE_DATA_BUS_WD_NP -1:0] int_rcvd_pkt_data                        ;
logic                   [CORE_DATA_BUS_WD -1:0] int_rcvd_pkt_mask                        ;


/*****
 * AXI clocked packet information interface from rdr to sbc
 *****/
logic  [CC_RADMX_COMPOSER_HDR_WD -1:0]                   slv_latchd_rcvd_pkt_hdr         ;
logic  [NUM_SEGMENTS-1:0]      [CC_AMBA_TLP_SEQ_WD -1:0] slv_latchd_rcvd_pkt_pseq        ;
logic  [NUM_SEGMENTS-1:0]                                slv_latchd_rcvd_pkt_hold_preq   ;
logic  [NUM_SEGMENTS-1:0]                                slv_latchd_rcvd_pkt_pseq_valid  ;
logic                     [MAX_RD_SIZE_PW -1:0] slv_lookup_resp_tlp_byte_len             ; /* Received response byte length                                  */
logic                                           slv_lookup_resp_tlp_4rd                  ;
logic                                  [3 -1:0] slv_lookup_resp_rreq_dma                 ;
logic                                  [3 -1:0] slv_lookup_resp_rreq_dma_chan            ;
P_APPTAG_PTR_TYPE                               active_lookup_outtag                     ; /* Application TAG to identify one particular request             */
logic                                           latchd_rcvd_pkt_last                     ;

/*****
 * AXI clocked packet output backpressure control path
 *****/
logic                                           s_clean_algn_in_halt                     ; /* Slave interface backpressure to u_algn                         */
logic                                           cdc_align_halt                           ; /* u_algn backpressure to u_sbc                                   */
logic                [L_N_EXPLICIT_FANOUT -1:0] cdc_sbc_stall_out                        ; /* u_sbc backpressure to u_rdr; u_rdr absorves backpressure       */

/*****
 * AXI clocked packet datapath from SBC to output
 *****/
respDataQ_s                                     s_sbc_o                                  ; /* Packed response information from sbc to ras/algn               */
respDataQ_ras_s                                 s_algn_i                                 ; /* Packed response information from sbc/ras to algn               */
respDataQ_ras_s                                 s_algn_o                                 ; /* Packed aligned response information from algn to comp toplevel */
logic                                           s_dirty_algn_pkt_hv                      ;
logic                                           s_dirty_algn_pkt_dv                      ;

/*****
 * AXI clocked read-side RAS
 *****/
logic                                           s_sbc_o_status_good                      ;
logic                          [ECC_WIDTH -1:0] s_sbc_o_data_ecc                         ;
logic        [CC_OB_CCMP_DATA_RAM_ADDR_WD -1:0] s_sbc_o_data_ram_addrb                   ;
logic                   [CORE_DATA_BUS_WD -1:0] s_early_algn_i_data                      ;
logic                                 [NW -1:0] s_early_algn_i_dwen                      ;

/*****
 * Core clocked completion timeout tracking
 *****/
P_WIRETAG_PTR_TYPE                              cpl_timeout_tag_str                      ;
P_HEADER_TYPE                                   cpl_timeout_hdr_str                      ;
logic                                           cpl_timeout_sel                          ;
P_WIRETAG_PTR_TYPE                              cpl_timeout_tag_sel                      ;
P_HEADER_TYPE                                   cpl_timeout_hdr_sel                      ;
logic                                           cpl_str_empty                            ;

logic                                           seg_wr_active, s_seg_wr_active           ;
logic                                           seg_wr_full  , s_seg_wr_full             ;
P_SEGMENT_PTR_TYPE                              r_wr_seg                                 ;
logic                                           seg_wr_allowed                           ;

wrState_e                                       wr_state                                 ;
wrHint_s                                        wr_hint                                  ;
wrTransition_e                                  wr_transition                            ;
wrqStat_e                                       wr_stat                                  ;

rcvdPkt_s                                       w_rcvd_pkt                               ;
rcvdPkt_s                                       rcvd_pkt_d                               ;
rcvdPkt_s                                       rcvd_pkt_wr                              ;

logic                                           s_new_seg                                ;
logic                                           s_rcvd_vld                               ;
logic                                           pred_timeout_halt_s                      ;
logic                                           pred_timeout_halt_r                      ;
logic                                           pred_timeout_halt                        ;

atagBitLUT_t                                    s_atag_incr,  s_atag_decr                ;
atagCount_s                  [MAX_OUT_TAG -1:0] s_atag_count, r_atag_count               ;
atagCount_s                  [MAX_OUT_TAG -1:0] wr_atag_count                            ;

wtagBitLUT_t                                    s_wtag_asgn , s_wtag_rls                 ;
wtagInfo_s                  [NUM_WIRETAGS -1:0] s_wtag_info , r_wtag_info                ;

logic                         [SBUF_WC_PW -1:0] allowed_wc_of_seg                        ;
logic                                           s_full_m1                                ;

logic                                     [2:0] consumed_cpl_stat                        ;

function automatic logic isLast ( input atagCount_s cnt );
  isLast = cnt.valid && cnt.count == 'd1;
endfunction

//  ========================================================================================================================
//  Internal design
//  ========================================================================================================================

localparam L_TAG_FIFO_DATA_WD = CC_RADMX_COMPOSER_HDR_WD
                                + MAX_IN_TAG_PW
                                + MAX_OUT_TAG_PW
                                ;

wire                      [2:0] consumed_tlp_cpl_stat;
wire                            err_tag_consumed;
wire                            err_tag_fifo_push_n;
wire                            err_tag_fifo_pop_n;
wire   [L_TAG_FIFO_DATA_WD-1:0] err_tag_fifo_data_in;
wire   [L_TAG_FIFO_DATA_WD-1:0] err_tag_fifo_data_out;
wire                            err_tag_fifo_empty;
wire                            err_tag_fifo_full;
wire                            err_tag_fifo_alm_full;
wire [CC_RADMX_COMPOSER_HDR_WD-1:0] err_pkt_hdr;
wire        [MAX_IN_TAG_PW-1:0] err_pkt_tag;
P_APPTAG_PTR_TYPE               err_pkt_apptag;

wire                            s_rcvd_pkt_hv;
wire                            s_rcvd_pkt_dv;
wire                            s_rcvd_pkt_eot;
wire                            s_rcvd_pkt_err;
wire                   [NW-1:0] s_rcvd_pkt_dwen;
wire  [CORE_DATA_BUS_WD_NP-1:0] s_rcvd_pkt_data;
wire  [PKT_DATA_WD-1:0]         s_rcvd_pkt_data_s;
wire [CC_RADMX_COMPOSER_HDR_WD-1:0] s_rcvd_pkt_hdr;
wire                            s_rcvd_pkt_last;
wire        [MAX_IN_TAG_PW-1:0] s_rcvd_pkt_tag;
P_APPTAG_PTR_TYPE               s_rcvd_pkt_apptag;
wire   [CC_AMBA_TLP_SEQ_WD-1:0] s_rcvd_pkt_pseq;
wire                            s_rcvd_pkt_hold_preq;
wire                            s_rcvd_pkt_status_good;
wire                            s_rcvd_pkt_err_req;

reg                             r_wire_cpl_in_progress;
wire                            s_wire_cpl_in_progress;

wire [CC_AMBA_TLP_SEQ_WD-1:0] last_presp_rpseq_per_vc    [       CX_NVC-1:0];

assign consumed_tlp_cpl_stat = consumed_tlp_hdr[2:0];
assign err_tag_consumed      = tag_consumed && ( consumed_tlp_cpl_stat != 3'b000 );
assign err_tag_fifo_push_n   = !(err_tag_consumed && !err_tag_fifo_full);
assign err_tag_fifo_data_in  = {consumed_tlp_hdr
                                ,consumed_in_tag
                                ,consumed_out_tag
                               };

// If we are pipelining npdcmp_req we have 1 clock cycle latency between halt and tag_consumed
// Therefore we preemptively block back-to-back errored requests when are are on an almost-full state
// There is a performance bubble on falling edge of 'full' when an errored request is halted,
//   but this is not important as errored requests are uncommon
assign err_tag_consumed_halt = (err_tag_fifo_alm_full & err_tag_consumed) | err_tag_fifo_full;

   DWC_pcie_ctl_bcm65_td
    #
     (
       .WIDTH           ( L_TAG_FIFO_DATA_WD   )
      ,.DEPTH           ( ERR_REQ_FIFO_DP      )
      ,.ADDR_WIDTH      ( ERR_REQ_FIFO_AW      )
      ,.REG_DELAY_TIME  ( REG_DELAY_TIME       )
      ,.REG_DELAY_DENOM ( REG_DELAY_DENOM      )
      ,.AF_LEVEL        ( 1                    )
      ) u_bcm65_err_req_fifo
   (
    .clk           ( clk                   )
    ,.rst_n        ( rst_n                 )
    ,.init_n       ( 1'b1                  )
    ,.push_req_n   ( err_tag_fifo_push_n   )
    ,.pop_req_n    ( err_tag_fifo_pop_n    )
    ,.diag_n       ( 1'b1                  )
    ,.data_in      ( err_tag_fifo_data_in  )
    ,.empty        ( err_tag_fifo_empty    )
    ,.almost_empty ( /* unconnected     */ )
    ,.half_full    ( /* unconnected     */ )
    ,.almost_full  ( err_tag_fifo_alm_full )
    ,.full         ( err_tag_fifo_full     )
    ,.error        ( /* unconnected     */ )
    ,.data_out     ( err_tag_fifo_data_out )
    );

assign {err_pkt_hdr
        ,err_pkt_tag
        ,err_pkt_apptag
       } = err_tag_fifo_data_out;

assign err_tag_fifo_pop_n = ~(~err_tag_fifo_empty && ~s_wire_cpl_in_progress);
assign err_req_pkt_valid  = !err_tag_fifo_pop_n;

always_ff @(posedge clk, negedge rst_n) begin : proc_seq_r_wire_cpl_in_progress
  if(!rst_n) begin
    r_wire_cpl_in_progress <= #`TP 1'b0;
  end else begin
    if(rcvd_pkt_eot)
      r_wire_cpl_in_progress <= #`TP 1'b0;
    else if(rcvd_pkt_hv)
      r_wire_cpl_in_progress <= #`TP 1'b1;
  end
end

assign s_wire_cpl_in_progress = rcvd_pkt_hv || r_wire_cpl_in_progress;

assign s_rcvd_pkt_hv          = s_wire_cpl_in_progress ? rcvd_pkt_hv          : err_req_pkt_valid;
assign s_rcvd_pkt_dv          = s_wire_cpl_in_progress ? rcvd_pkt_dv          : 1'b0;
assign s_rcvd_pkt_eot         = s_wire_cpl_in_progress ? rcvd_pkt_eot         : err_req_pkt_valid;
assign s_rcvd_pkt_err         = s_wire_cpl_in_progress ? rcvd_pkt_err         : 1'b0;
assign s_rcvd_pkt_dwen        = s_wire_cpl_in_progress ? rcvd_pkt_dwen        : '0;

assign s_rcvd_pkt_data_s      = s_wire_cpl_in_progress ? int_rcvd_pkt_data_wpar_s  : '0;


assign s_rcvd_pkt_hdr         = s_wire_cpl_in_progress ? rcvd_pkt_hdr         : err_pkt_hdr;
assign s_rcvd_pkt_last        = s_wire_cpl_in_progress ? rcvd_pkt_last        : 1'b1;
assign s_rcvd_pkt_tag         = s_wire_cpl_in_progress ? rcvd_pkt_tag         : err_pkt_tag;
assign s_rcvd_pkt_apptag      = s_wire_cpl_in_progress ? rcvd_pkt_apptag      : err_pkt_apptag;
assign s_rcvd_pkt_pseq        = s_wire_cpl_in_progress ? rcvd_pkt_pseq        : '0;
assign s_rcvd_pkt_hold_preq   = s_wire_cpl_in_progress ? rcvd_pkt_hold_preq   : 1'b0;
assign s_rcvd_pkt_status_good = s_wire_cpl_in_progress ? rcvd_pkt_status_good : 1'b1;
assign s_rcvd_pkt_err_req     = s_wire_cpl_in_progress ? 1'b0                 : err_req_pkt_valid;

assign lookup_err = 1'b0; // Wire has no fan-out

always_ff @(posedge clk, negedge rst_n) begin
  if(!rst_n) begin
    {s_hdof_atag_vld, s_hdof_atag} <= #`TP '0;
  end else begin
    {s_hdof_atag_vld, s_hdof_atag} <= #`TP {r_composed_atag_vld, r_composed_atag};
  end
end

// The completion timeout interface and the cpl/bypass interface operate
// independantly. Therefore, it is possible that a completion tieout can
// collide with a real completion. This can result in the real completion
// getting lost and replaced with the timeout.
// To prevent this, if a real completion is ready to pass out of the
// composer and we get a timeout, we will store off the timeout and service
// it after the real completion has been sent.

localparam L_TAGINFO_EN = 0 || 1 ;

P_APPTAG_PTR_TYPE s_cpl_timeout_apptag;
P_APPTAG_PTR_TYPE cpl_timeout_apptag_str;
P_APPTAG_PTR_TYPE cpl_timeout_apptag_sel;

assign s_cpl_timeout_apptag = cpl_timeout_apptag;

DWC_pcie_tagMngr
 #(
  .P_MAXTAG      ( MAX_IN_TAG     )
 ,.P_MAXTAG_LOW  ( MAX_IN_TAG     )
 ,.P_MAXTAG_VLOW ( MAX_IN_TAG     )
 ,.P_TAGWD       ( MAX_IN_TAG_PW  )
 ,.P_TAGINFO_EN  ( L_TAGINFO_EN   )
 ,.P_TAGINFO_WD  ( MAX_OUT_TAG_PW )
 ,.P_START_EMPTY ( 1              )
) u_timeout_q (
   .clk           ( clk                    )
  ,.rst_n         ( rst_n                  )

  ,.mode          ( 2'b00                  )
  ,.update_p      ( 1'b0                   )

  ,.pop_en        ( cpl_timeout_sel        )
  ,.pop_tag       ( cpl_timeout_tag_str    )
  ,.pop_tag_info  ( cpl_timeout_apptag_str )
  ,.pop_empty     ( cpl_str_empty          )

  ,.push_en       ( cpl_timeout            )
  ,.push_tag      ( cpl_timeout_tag        )
  ,.push_tag_info ( s_cpl_timeout_apptag   )
);

assign w_rcvd_pkt = rcvdPkt_s'{
  hv        : s_rcvd_pkt_hv
 ,dv        : s_rcvd_pkt_dv
 ,eot       : s_rcvd_pkt_eot
 ,err       : s_rcvd_pkt_err
 ,dwen      : s_rcvd_pkt_dwen

 ,data      : s_rcvd_pkt_data_s

 ,hdr       : s_rcvd_pkt_hdr
 ,last      : s_rcvd_pkt_last
 ,tag       : s_rcvd_pkt_tag
 ,apptag    : s_rcvd_pkt_apptag
 ,pseq      : s_rcvd_pkt_pseq
 ,hold_preq : s_rcvd_pkt_hold_preq
 ,status_good : s_rcvd_pkt_status_good
 ,err_req: s_rcvd_pkt_err_req
};

always_ff @(posedge clk, negedge rst_n) begin : rcvd_pkt_d_PROC
  if(!rst_n) begin
    rcvd_pkt_d <= #TP '0;
  end else begin
    rcvd_pkt_d <= #TP w_rcvd_pkt;
  end
end : rcvd_pkt_d_PROC


assign rcvd_pkt_wr = (`CC_COMPOSER_REGIN == 1) ? rcvd_pkt_d : w_rcvd_pkt;


assign intag_released      = (rcvd_pkt_wr.eot & !rcvd_pkt_wr.err && rcvd_pkt_wr.last);

// Logic for pred_timeout_halt to stay asserted in between w_rcvd_pkt.hv and rcvd_pkt_d.eot
always_comb begin : proc_comb_pred_timeout
  if (w_rcvd_pkt.hv || rcvd_pkt_d.hv) begin
    pred_timeout_halt_s = 1'b1;
  end else begin
    pred_timeout_halt_s = pred_timeout_halt_r;
  end
end

always_ff @(posedge clk or negedge rst_n) begin : proc_seq_pred_timeout
  if (!rst_n) begin
    pred_timeout_halt_r <= #TP 1'b0;
  end else begin
    if (rcvd_pkt_d.eot) begin
      pred_timeout_halt_r <= #TP 1'b0;
    end else begin
      pred_timeout_halt_r <= #TP pred_timeout_halt_s;
    end
  end
end

assign pred_timeout_halt = pred_timeout_halt_s || pred_timeout_halt_r;

assign timeout_queue_halt  = pred_timeout_halt || intag_released_d;

assign cpl_timeout_sel        = timeout_queue_halt ? 1'b0 : !cpl_str_empty;
assign cpl_timeout_tag_sel    =                              cpl_timeout_tag_str;
assign cpl_timeout_apptag_sel =                              cpl_timeout_apptag_str;

`ifndef SYNTHESIS
`endif // ! SYNTHESIS

// ---------------------------------------------------------------------------
// RAS Generation stage
// ---------------------------------------------------------------------------
//Calculates the RAM ECC

//  ===================================================================
//  Segment buffer write control logic
//  ===================================================================

wire wr_in_progress_tag;

reg  wr_in_progress;

always @(posedge clk or negedge rst_n)
begin: WR_STATE_CONTROL
    if (!rst_n)
    begin
        wr_in_progress      <= #TP 1'b0;
    end else if (rcvd_pkt_wr.eot) begin
        wr_in_progress      <= #TP 1'b0;
    end else if (int_dataq_wr_start) begin
        wr_in_progress      <= #TP 1'b1;
    end

end

assign wr_in_progress_tag = wr_in_progress;

// A response is composed into segment buffer queue when this segment buffer queue is not in flush state
// Flush state is caused when a response is being received with error.
// CP3:  Cover the dataq_wr_start asserted with a response being aborted at the first response, second response and last response
// CP4:  Cover the dataq_wr_start asserted with a response that already has flush status
// CP5:  Cover the dataq_wr_start asserted without a response that already has flush status
// CP6:  Cover a single dword response and multi-dwords response
// CP7:  Cover rcvd_pkt_err asserted on a multi-dwords response
// CP8:  Cover out_halt asserted with hv and eot only
// CP9:  Cover out_halt asserted with dv and eot only
// AMP3: Monitor the illegal condition on a rcvd_pkt_err asserted at the same cycle of dataq_wr_keep;

function automatic wrqStat_e getWrqStat(
  input logic hv
 ,input logic dv
 ,input logic eot
 ,input logic err
);
  wrqStat_e stat;

//assign  dataq_wr_start      = rcvd_pkt_hv_d && (rcvd_pkt_dv_d || lookup_last_resp_4outtag) && !rcvd_pkt_err_d && !segment_busy & !latchd_req_flushed[active_lookup_outtag];
//assign  dataq_wr_en         = !segment_full && (dataq_wr_start | (rcvd_pkt_dv_d & wr_in_progress_tag && !rcvd_pkt_err_d));
//assign  dataq_wr_keep       = rcvd_pkt_eot_d && !rcvd_pkt_err_d && dataq_wr_en && (rcvd_pkt_dv_d || lookup_last_resp_4outtag);

  case({hv, dv, eot, err})
    4'b0000,
    4'b0001,
    4'b0010,
    4'b0011:
      stat = E_WR_NO_ACTION;

    4'b0100:
      stat = E_WR_PUSH;
    4'b0101:
      stat = E_WR_ERR_DROP;   // Stimulus is not expected
    4'b0110:
      stat = E_WR_KEEP;
    4'b0111:
      stat = E_WR_NOR_DROP;

    4'b1000,
    4'b1001:
      stat = E_WR_ERR_DROP;   // Stimulus is not expected
    4'b1011:
      stat = E_WR_NOR_DROP;

    4'b1100:
      stat = E_WR_START;
    4'b1101:
      stat = E_WR_ERR_DROP;   // Stimulus is not expected
    4'b1010,
    4'b1110:
      stat = E_WR_START_KEEP;
    4'b1111:
      stat = E_WR_NOR_DROP;
  endcase

  getWrqStat = stat;
endfunction

assign s_rcvd_vld = rcvd_pkt_wr.hv || rcvd_pkt_wr.dv || rcvd_pkt_wr.err;
assign s_new_seg  = (s_rcvd_vld && (r_wr_seg != int_dataq_wr_seg_num)) || rcvd_pkt_wr.hv;

assign wr_stat = getWrqStat(
  .hv  (rcvd_pkt_wr.hv )
 ,.dv  (rcvd_pkt_wr.dv )
 ,.eot (rcvd_pkt_wr.eot)
 ,.err (rcvd_pkt_wr.err)
);

always_ff @(posedge clk, negedge rst_n) begin : wr_state_PROC
  if(!rst_n) begin
    wr_state <= #TP E_WR_IDLE;
  end else begin
    case(wr_transition)
      E_KOI,
      E_WTI:
        wr_state <= #TP E_WR_IDLE;
      E_ITW,
      E_KOW:
        wr_state <= #TP E_WRITING;
    endcase
  end
end : wr_state_PROC

always_ff @(posedge clk, negedge rst_n) begin : seg_wr_active_PROC
  if(!rst_n) begin
    seg_wr_active <= #TP 1'b0;
    seg_wr_full   <= #TP 1'b0;
    r_wr_seg      <= #TP '0;
  end else begin
    seg_wr_active <= #TP s_seg_wr_active;
    seg_wr_full   <= #TP s_new_seg ? (s_seg_wr_full || !seg_wr_allowed) : (s_seg_wr_full || seg_wr_full);
    r_wr_seg      <= #TP s_rcvd_vld ? int_dataq_wr_seg_num : r_wr_seg;
  end
end



assign allowed_wc_of_seg = (SBUF_WC_PW)'(SBUF_SEG_DP);

assign s_full_m1      = (s_wc_w[dataq_wr_seg_num[L_WTWD-1:0]] == (allowed_wc_of_seg - 1'b1));
assign seg_wr_allowed = s_new_seg ? (s_wc_w[dataq_wr_seg_num[L_WTWD-1:0]] < allowed_wc_of_seg) : !seg_wr_full;
assign s_seg_wr_full  = s_full_m1 && int_dataq_wr_en;
assign seg_wr_nstart  = !((!seg_wr_active) || s_new_seg);

always_comb begin : s_seg_wr_active_PROC
  case({int_dataq_wr_start, int_dataq_wr_drop, int_dataq_wr_keep})
    3'b000:
      s_seg_wr_active = s_new_seg ? 1'b0 : seg_wr_active;
    3'b001,
    3'b010,
    3'b101,
    3'b011, // <-- Stimulus is not expected
    3'b111:
      s_seg_wr_active = 1'b0;
    3'b100,
    3'b110:
      s_seg_wr_active = 1'b1;
  endcase
end : s_seg_wr_active_PROC

always_comb begin : wr_transition_PROC
  if(wr_hint.koi_idle) begin
    wr_transition = E_KOI;
  end else if(wr_hint.itw_start_pwtag) begin
    wr_transition = E_ITW;
  end else if(wr_hint.kow_stay_vwtag_idle    ||
              wr_hint.kow_stay_vwtag_active  ||
              wr_hint.kow_pop_vwtag          ||
              wr_hint.kow_start_vwtag_idle   ||
              wr_hint.kow_start_vwtag_active   ) begin
    wr_transition = E_KOW;
  end else if(wr_hint.wti_err || wr_hint.wti_keep) begin
    wr_transition = E_WTI;
  end else begin
    wr_transition = E_KOI;
  end
end : wr_transition_PROC

assign wr_hint = '{
  koi_idle               : (wr_state == E_WR_IDLE) && (wr_stat      == E_WR_NO_ACTION )
 ,koi_one_beat           : (wr_state == E_WR_IDLE) && (wr_stat      == E_WR_START_KEEP)
 ,koi_no_beats           : (wr_state == E_WR_IDLE) && (wr_stat inside {E_WR_NOR_DROP, E_WR_ERR_DROP})
 ,itw_start_pwtag        : (wr_state == E_WR_IDLE) && (wr_stat      == E_WR_START     )            // && !seg_wr_nstart

 ,kow_stay_vwtag_idle    : (wr_state == E_WRITING) && (wr_stat      == E_WR_NO_ACTION )               &&  seg_wr_nstart
 ,kow_stay_vwtag_active  : (wr_state == E_WRITING) && (wr_stat      == E_WR_PUSH      )               &&  seg_wr_nstart && !s_full_m1  // i.e. !full_m_1 : stay
 ,kow_pop_vwtag          : (wr_state == E_WRITING) && (wr_stat      == E_WR_PUSH      )               &&  seg_wr_nstart &&  s_full_m1  // i.e.  full_m_1 : pop
 ,kow_start_vwtag_idle   : (wr_state == E_WRITING) && (wr_stat      == E_WR_NO_ACTION )               && !seg_wr_nstart
 ,kow_start_vwtag_stalld : (wr_state == E_WRITING) && (wr_stat      == E_WR_PUSH      )               && !seg_wr_nstart && !seg_wr_allowed // i.e.  full : ignore data
 ,kow_start_vwtag_active : (wr_state == E_WRITING) && (wr_stat      == E_WR_PUSH      )               && !seg_wr_nstart &&  seg_wr_allowed // i.e. !full : start
 ,wti_err                : (wr_state == E_WRITING) && (wr_stat inside {E_WR_NOR_DROP, E_WR_ERR_DROP})
 ,wti_keep               : (wr_state == E_WRITING) && (wr_stat inside {E_WR_KEEP, E_WR_START_KEEP  })
};

`ifndef SYNTHESIS
`endif // SYNTHESIS

always_comb begin : dataq_wr_PROC
  int_dataq_wr_start =    wr_hint.itw_start_pwtag
                       || wr_hint.koi_one_beat
                       || wr_hint.kow_start_vwtag_active
                       ||(wr_hint.wti_keep && !seg_wr_nstart)
                       ;

  int_dataq_wr_en = (    wr_hint.itw_start_pwtag
                      || wr_hint.koi_one_beat
                      || wr_hint.kow_stay_vwtag_active
                      || wr_hint.kow_pop_vwtag
                      || wr_hint.kow_start_vwtag_active
                      || wr_hint.wti_keep
                    ) && seg_wr_allowed;

  int_dataq_wr_keep =    wr_hint.koi_one_beat
                      || wr_hint.wti_keep
                      ;

  int_dataq_wr_drop =    wr_hint.wti_err
                      || wr_hint.koi_no_beats
                      ;

  int_dataq_wr_seg_num = rcvd_pkt_wr.tag;

    int_dataq_wr_data_s = {rcvd_pkt_wr.dwen, rcvd_pkt_wr.data, rcvd_pkt_wr.status_good};

end : dataq_wr_PROC

  assign dataq_wr_start   = int_dataq_wr_start;
  assign dataq_wr_en      = int_dataq_wr_en;
  assign dataq_wr_keep    = int_dataq_wr_keep;
  assign dataq_wr_drop    = int_dataq_wr_drop;
  assign dataq_wr_seg_num = int_dataq_wr_seg_num;
  assign dataq_wr_data_s    = int_dataq_wr_data_s;

assign s_composed_wtag_vld = (cpl_timeout_sel && r_wtag_info[cpl_timeout_tag_sel[L_WTWD-1:0]].active) || intag_released;
assign s_composed_wtag     = (cpl_timeout_sel && r_wtag_info[cpl_timeout_tag_sel[L_WTWD-1:0]].active) ? cpl_timeout_tag_sel : int_released_tag;

`ifndef SYNTHESIS
`endif // SYNTHESIS

// When multicomposer is active, pipeline between int_dataq_wr and dataq_wr causes 1 cycle delay to wtag len calculation
localparam L_WTAG_DLY = 2;

delay_n
 #(
  .WD ( 1 + MAX_IN_TAG_PW )
 ,.N  ( L_WTAG_DLY        )
) u_dly_wtag (
  .clk   ( clk   )
 ,.rst_n ( rst_n )
 ,.clear ( 1'b0  )
 ,.din   ( {s_composed_wtag_vld  , s_composed_wtag  } )
 ,.dout  ( {r_composed_wtag_vld_d, r_composed_wtag_d} )
);

assign r_composed_wtag_len_d = r_wc_w[r_composed_wtag_d[L_WTWD-1:0]];

/*****
 * Write-side word count tracking processes
 *****/
pushCommand_e s_native_pushc;

/* Pdly before word count logic                                                                       */
assign  s_dataq_wr = { dataq_wr_en
                      ,dataq_wr_seg_num
                      ,dataq_wr_start
                      ,dataq_wr_keep
                      ,dataq_wr_drop
                      };

always_ff @(posedge clk, negedge rst_n) begin : R_DATAQ_WR_PROC
  if(!rst_n)
    r_dataq_wr <= #TP '0;
  else
    r_dataq_wr <= #TP s_dataq_wr;
end

/* For cleaner RTL, SBC push signals are converted to their native SBC enums                          */
always_comb begin : s_native_pushc_PROC
  if(~r_dataq_wr.w_wen)                                /* DW_sbc spec  : proper explicit drop         */
    s_native_pushc = r_dataq_wr.w_drop ? E_DROP : E_PUSH_IDLE;
  else begin
    if(r_dataq_wr.w_drop)                              /* rdbuff compat: explicit drop + packet start */
      s_native_pushc = E_DROPSTART;
    else if( r_dataq_wr.w_start && ~r_dataq_wr.w_keep) /* DW_sbc spec  : proper packet start          */
      s_native_pushc = E_START;
    else if(~r_dataq_wr.w_start &&  r_dataq_wr.w_keep) /* DW_sbc spec  : proper packet end            */
      s_native_pushc = E_KEEP;
    else if( r_dataq_wr.w_start &&  r_dataq_wr.w_keep) /* rdbuff compat: implicit drop + single push  */
      s_native_pushc = E_DROPSTARTKEEP;
    else
      s_native_pushc = E_PUSH;                         /* DW_sbc spec  : generic push                 */
  end
end : s_native_pushc_PROC

always_comb begin : S_WC_PROC
  foreach(s_wc[i]) begin
    if(r_composed_wtag_vld_d && (r_composed_wtag_d == i))
      s_wc[i] = '0;
    else begin
      if(pushUpdateCounter(s_native_pushc) && (r_dataq_wr.w_seg_num == i)) begin
        s_wc[i] = s_wc_w[i];
      end else if(s_native_pushc == E_KEEP) begin
        // If keep on target segment, keep on all segments
        s_wc[i] = r_wc_w[i];
      end else begin
        s_wc[i] = r_wc[i];
      end
    end
  end
end

always_comb begin : S_WC_W_PROC
  foreach(s_wc_w[i]) begin
    if(r_composed_wtag_vld_d && (r_composed_wtag_d == i))
      s_wc_w[i] = '0;
    else begin
      // If drop on target segment, drop on all segments
      if(s_native_pushc inside {E_DROP, E_START, E_DROPSTART, E_DROPSTARTKEEP}) begin
        s_wc_w[i] = r_wc[i];
      end

      if(r_dataq_wr.w_seg_num == i) begin
        case(s_native_pushc)
          E_KEEP,
          E_PUSH:
            s_wc_w[i] = (r_wc_w[i] + 1'b1

                         );                                      /* Working counter moves 1/2 ahead                    */
          E_DROP:
            s_wc_w[i] = r_wc[i];                                 /* Working counter resets to confirmed counter        */
          E_START        ,
          E_DROPSTART    ,
          E_DROPSTARTKEEP:
            s_wc_w[i] = (r_wc[i] + 1'b1

                         );                                      /* Working counter moves 1/2 ahead of confirmed counter */
          default:
            s_wc_w[i] = r_wc_w[i];                               /* Working counter does not change                      */
        endcase
      end else begin
        s_wc_w[i] = r_wc_w[i];
      end
    end
  end
end

always_ff @(posedge clk, negedge rst_n) begin : R_WC_PROC
  if(!rst_n) begin
    r_wc   <= #TP '0;
    r_wc_w <= #TP '0;
  end else begin
    r_wc   <= #TP s_wc  ;
    r_wc_w <= #TP s_wc_w;
  end
end


always @(rcvd_pkt_dwen)
begin

  integer i;
  integer j;

  for (i=0; i<NW; i=i+1) begin
    for (j=0; j<DBUS_DWORD_WD_WITH_PAR; j=j+1) begin
      int_rcvd_pkt_mask[i*DBUS_DWORD_WD_WITH_PAR+j] = rcvd_pkt_dwen[i];
    end
  end

end

assign int_rcvd_pkt_data_wpar = (rcvd_pkt_data & int_rcvd_pkt_mask) | (~int_rcvd_pkt_mask & {BUS_N_BYTES{BUS_INIT_BYTE}});

   wire   rcvd_pkt_data_chk_en;
   assign rcvd_pkt_data_chk_en = rcvd_pkt_dv;

     //  keep the parity
     assign int_rcvd_pkt_data_wpar_s = int_rcvd_pkt_data_wpar;


//  ===================================================================
//  Segment buffer read control logic
//  ===================================================================

// Process to store the flush state of a particular outTAG
// If a out TAg is in flush state, all remain responses returned will be dropped
assign rcvd_pkt_no_err_d = (rcvd_pkt_wr.eot && !rcvd_pkt_wr.err);

assign consumed_cpl_stat = consumed_tlp_hdr[2:0];
assign consumed_seg_err_req = tag_consumed && ( consumed_cpl_stat != 3'b000 ) && !err_tag_consumed_halt;

logic  cpl_timeout_last;
assign cpl_timeout_last = r_wtag_info[cpl_timeout_tag[L_WTWD-1:0]].active && isLast(r_atag_count[s_cpl_timeout_apptag]);

always_ff @(posedge clk, negedge rst_n) begin : latchd_req_flushed_timedout_PROC
  if(!rst_n) begin
    latchd_req_flushed  <= #TP '0;
    latchd_req_timedout <= #TP '0;
  end else begin
    foreach(latchd_req_flushed[i]) begin
      if(        ((i == active_lookup_outtag      ) && !rcvd_pkt_wr.status_good && rcvd_pkt_no_err_d) ) begin // If apptag has been flushed
        latchd_req_flushed[i]  <= #TP 1'b1;
        latchd_req_timedout[i] <= #TP latchd_req_timedout[i];
      end else if((i == s_cpl_timeout_apptag) && cpl_timeout) begin // If apptag has been timed out
        latchd_req_flushed[i]  <= #TP 1'b1;
        latchd_req_timedout[i] <= #TP 1'b1;
      end

      if(         (i == s_hdof_atag          ) && s_hdof_atag_vld                                 ) begin // If apptag has been handed off to rdr
        latchd_req_flushed[i]  <= #TP 1'b0;
        latchd_req_timedout[i] <= #TP 1'b0;
      end
    end
  end
end : latchd_req_flushed_timedout_PROC

always_ff @(posedge clk, negedge rst_n) begin : SEQ_LATCHD_RCVD_PKT_PROC

  integer i,j;

  if(!rst_n) begin
    for(i=0;i<NUM_SEGMENTS;i=i+1) begin
      latchd_rcvd_pkt_hdr[i]        <= #TP '0;
    end
  end else begin
    for(j=0;j<NUM_SEGMENTS;j=j+1) begin
      if (j == s_cpl_timeout_apptag && cpl_timeout && !latchd_req_flushed[j] && !latchd_req_timedout[j]) begin
        latchd_rcvd_pkt_hdr[j] <= #TP { cpl_timeout_hdr[CC_RADMX_COMPOSER_HDR_WD -1: COMPOSER_HDR_EP_HIGH +1],
                                        cpl_timeout_hdr[COMPOSER_HDR_EP_HIGH] || latchd_rcvd_pkt_hdr[j][COMPOSER_HDR_EP_HIGH],
                                        cpl_timeout_hdr[COMPOSER_HDR_EP_HIGH -1:0]
                                      };
      end else if( (j == active_lookup_outtag      ) && rcvd_pkt_no_err_d && !latchd_req_flushed[j] && !latchd_req_timedout[j]) begin // Apptag is being received and not timed out
        latchd_rcvd_pkt_hdr[j] <= #TP { rcvd_pkt_wr.hdr[CC_RADMX_COMPOSER_HDR_WD -1: COMPOSER_HDR_EP_HIGH +1],
                                        rcvd_pkt_wr.hdr[COMPOSER_HDR_EP_HIGH] || latchd_rcvd_pkt_hdr[j][COMPOSER_HDR_EP_HIGH],
                                        rcvd_pkt_wr.hdr[COMPOSER_HDR_EP_HIGH -1:0]
                                       };
      end

      if(          (j == s_hdof_atag          ) && s_hdof_atag_vld) begin
        latchd_rcvd_pkt_hdr[j]        <= #TP '0;
      end
    end
  end
end : SEQ_LATCHD_RCVD_PKT_PROC

logic  [NUM_SEGMENTS-1:0]      [CC_AMBA_TLP_SEQ_WD -1:0] next_latchd_rcvd_pkt_pseq        ;
logic  [NUM_SEGMENTS-1:0]                                next_latchd_rcvd_pkt_hold_preq   ;
logic                                 [NUM_SEGMENTS-1:0] next_latchd_rcvd_pkt_pseq_valid  ;

always@(*) begin: COMB_LATCHD_RCVD_PKT_PSEQ_PROC

  integer i,j;

  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_pkt_pseq;
  reg [CC_AMBA_TLP_SEQ_WD-1:0] tmp_last_pseq_per_vc;
  reg                          tmp_cpl_rlsd_per_vc;
  
  for(i=0;i<NUM_SEGMENTS;i=i+1) begin
    next_latchd_rcvd_pkt_pseq[i]       = latchd_rcvd_pkt_pseq[i];
    next_latchd_rcvd_pkt_hold_preq[i]  = latchd_rcvd_pkt_hold_preq[i];
    next_latchd_rcvd_pkt_pseq_valid[i] = latchd_rcvd_pkt_pseq_valid[i];
  end

  for(j=0;j<NUM_SEGMENTS;j=j+1) begin
    if( (j == active_lookup_outtag      ) && rcvd_pkt_no_err_d) begin 
      next_latchd_rcvd_pkt_pseq  [j]    = rcvd_pkt_wr.hold_preq ? rcvd_pkt_wr.pseq : latchd_rcvd_pkt_pseq[j];
      next_latchd_rcvd_pkt_hold_preq[j] = rcvd_pkt_wr.hold_preq || latchd_rcvd_pkt_hold_preq[j];
    end

    tmp_pkt_pseq         = next_latchd_rcvd_pkt_pseq[j];


    tmp_last_pseq_per_vc = ib_last_presp_rpseq_per_vc[0];

    tmp_cpl_rlsd_per_vc  = (((tmp_last_pseq_per_vc[(CC_AMBA_TLP_SEQ_WD-1) -: 2] == tmp_pkt_pseq[(CC_AMBA_TLP_SEQ_WD-1) -: 2]        ) && (tmp_last_pseq_per_vc >= tmp_pkt_pseq) ) ||  // if pseq and last_pseq are on the same range do a straigth comparison
                            ( tmp_last_pseq_per_vc[(CC_AMBA_TLP_SEQ_WD-1) -: 2] == tmp_pkt_pseq[(CC_AMBA_TLP_SEQ_WD-1) -: 2] + 2'b01                                            ))    // if last_pseq is one count segment above no need for further comparison
;

    if(tmp_cpl_rlsd_per_vc )
      next_latchd_rcvd_pkt_hold_preq[j] = 1'b0;

    if(          (j == s_hdof_atag          ) && s_hdof_atag_vld) begin
      next_latchd_rcvd_pkt_pseq[j]       = '0;
      next_latchd_rcvd_pkt_hold_preq[j]  = '0;
      next_latchd_rcvd_pkt_pseq_valid[j] = '0;
    end
  end
end

always_ff @(posedge clk, negedge rst_n) begin : SEQ_LATCHD_RCVD_PKT_PSEQ_PROC

  integer i,j;

  if(!rst_n) begin
    for(i=0;i<NUM_SEGMENTS;i=i+1) begin
      latchd_rcvd_pkt_pseq[i]       <= #TP '0;
      latchd_rcvd_pkt_hold_preq[i]  <= #TP '0;
      latchd_rcvd_pkt_pseq_valid[i] <= #TP '0;
    end
  end else begin
    for(j=0;j<NUM_SEGMENTS;j=j+1) begin
      latchd_rcvd_pkt_pseq[j]       <= #TP next_latchd_rcvd_pkt_pseq[j];
      latchd_rcvd_pkt_hold_preq[j]  <= #TP next_latchd_rcvd_pkt_hold_preq[j];
      latchd_rcvd_pkt_pseq_valid[j] <= #TP next_latchd_rcvd_pkt_pseq_valid[j];
    end
  end
end


generate

  genvar gi;

  for (gi=0; gi<CX_NVC; gi=gi+1) begin : gen_bcm25_presp_per_vc_array

    DWC_pcie_ctl_bcm25
     #(

     .WIDTH       ( CC_AMBA_TLP_SEQ_WD ),
     .PEND_MODE   ( 1                  ),
     .ACK_DELAY   ( 1                  ),
     .F_SYNC_TYPE ( SYNC_DEPTH         ),
     .R_SYNC_TYPE ( SYNC_DEPTH         ),
     .VERIF_EN    ( 1                  ),
     .SEND_MODE   ( 0                  ),
     .SVA_TYPE    ( 0                  ),
     .RST_VAL     ( 0                  ) 
    
      ) u_bcm25_presp_per_vc (

        .clk_s        ( clk                            )
       ,.rst_s_n      ( rst_n                          )
       ,.init_s_n     ( 1'b1                           )
       ,.send_s       ( 1'b1                           )
       ,.data_s       ( ib_last_presp_rpseq_per_vc[gi] )
       ,.empty_s      ( /* unconnected */              )
       ,.full_s       ( /* unconnected */              )
       ,.done_s       ( /* unconnected */              )

       ,.clk_d        ( slv_aclk                       )
       ,.rst_d_n      ( slv_aresetn                    )
       ,.init_d_n     ( 1'b1                           )
       ,.data_avail_d ( /* unconnected */              )
       ,.data_d       ( last_presp_rpseq_per_vc[gi]    )

        );

  end


endgenerate



always_ff @(posedge clk, negedge rst_n) begin : cmpose_done_ary_PROC
  if(!rst_n) begin
    cmpose_done_ary <= #TP '0;
  end else begin
    foreach(cmpose_done_ary[i]) begin
      if(         (i == update_tag      ) && update_done_ary) begin
        cmpose_done_ary[i] <= #TP 1'b1;
      end else if((i == s_hdof_atag) && s_hdof_atag_vld   ) begin
        cmpose_done_ary[i] <= #TP 1'b0;
      end
    end
  end
end : cmpose_done_ary_PROC

// CP10:  rcvd_pkt_good_status asserted at the first, second and last responses of a split responses within the same inTAG
// CP11:  rcvd_pkt_good_status asserted at the first, second and last responses of a split responses within the same outTAG
// CP12:  rcvd_pkt_err asserted at a inTag that is in flush state, also repeat for first, second and last response

///////////////////////////////////////////////////////////////////
// Start of change to free up the composer in chronological order
// (skipping the segments halted by resp_tag_sel_n)
///////////////////////////////////////////////////////////////////

assign composed_seg = update_done_ary || (cpl_timeout_sel & lookup_last_4cpl_timeout);
assign composed_seg_num = (cpl_timeout_sel & lookup_last_4cpl_timeout) ? lookup_outtag_4cpl_timeout : update_tag;

always_ff @(posedge clk or negedge rst_n) begin: SEQ_R_COMPOSED_SEG_PROC
  if (!rst_n) begin
    r_composed_atag_vld    <= #TP 1'b0;
    r_composed_atag        <= #TP '0;
  end else begin
    r_composed_atag_vld    <= #TP composed_seg;
    r_composed_atag        <= #TP composed_seg_num;
  end
end

DWC_pcie_axi_cpl_comp_ctl_rdr
 #(
  .P_MAX_OUT_TAG_PW  ( MAX_OUT_TAG_PW  )
 ,.P_MAX_IN_TAG_PW   ( NUM_WIRETAGS_PW )
 ,.P_MAX_IN_TAG      ( NUM_WIRETAGS    )
 ,.P_SLV_ID_WD       ( SLV_ID_WD       )
 ,.P_NUM_SEGMENTS    ( NUM_SEGMENTS    )
 ,.P_NUM_SEGMENTS_PW ( NUM_SEGMENTS_PW )
 ,.P_HDR_WD          ( CC_RADMX_COMPOSER_HDR_WD )
 ,.P_MAX_RD_SIZE_PW  ( MAX_RD_SIZE_PW  )
 ,.P_SBUF_WC_PW      ( SBUF_WC_PW      )
) u_rdr (
  .core_clk                      ( clk                           )
 ,.slv_aclk                      ( slv_aclk                      )
 ,.core_rst_n                    ( rst_n                         )
 ,.slv_aresetn                   ( slv_aresetn                   )

  /* Apptag composition interface                               */
 ,.hdof_atag_vld                 ( s_hdof_atag_vld               )
 ,.hdof_atag                     ( s_hdof_atag                   )

 /* Wiretag composition interface                               */
 ,.composed_wtag_vld             ( r_composed_wtag_vld_d         )
 ,.composed_wtag                 ( r_composed_wtag_d             )
 ,.composed_wtag_len             ( r_composed_wtag_len_d         )

 /* Last completed Posted request interface (from AXI Master)   */
 ,.last_presp_rpseq_per_vc       ( last_presp_rpseq_per_vc       )
 ,.trgt1_p_xfer_pend_per_vc      ( trgt1_p_xfer_pend_per_vc      )

  /* Core-clocked segment and request consumption event intf    */
 ,.tag_consumed                  ( tag_consumed                  )
 ,.consumed_4rd                  ( consumed_4rd                  )
 ,.consumed_tlp_byte_len         ( consumed_tlp_byte_len         )
 ,.consumed_out_tag              ( consumed_out_tag              )
 ,.consumed_rreq_dma             ( consumed_rreq_dma             )
 ,.consumed_rreq_dma_chan        ( consumed_rreq_dma_chan        )

 ,.consumed_tag_from_nprf        ( consumed_tag_from_nprf        )
 ,.nprf_id                       ( nprf_id                       )
 ,.nprf_tag                      ( nprf_tag                      )

  /* Slave-clocked halt input from SBC                          */
 ,.stall_out                     ( cdc_sbc_stall_out             )

  /* Core-clocked request status information                    */
 ,.latchd_req_flushed            ( latchd_req_flushed            )
 ,.latchd_req_timedout           ( latchd_req_timedout           )
 ,.latchd_rcvd_pkt_hdr           ( latchd_rcvd_pkt_hdr           )
 ,.latchd_rcvd_pkt_pseq          ( latchd_rcvd_pkt_pseq          )
 ,.latchd_rcvd_pkt_hold_preq     ( latchd_rcvd_pkt_hold_preq     )

  /* Slave-clocked SBC read request and info interface to SBC   */
 ,.dataq_rd_en                   ( dataq_rd_en_rdr               )
 ,.dataq_rd_apptag               ( dataq_rd_apptag_rdr           )
 ,.dataq_rd_seg_num              ( dataq_rd_seg_num_rdr          )
 ,.dataq_rd_eot                  ( dataq_rd_eot_rdr              )
 ,.dataq_rd_dv                   ( dataq_rd_dv_rdr               )
 ,.dataq_rd_err                  ( dataq_rd_err_rdr              )

  /* Slave-clocked additional composition information to SBC    */
 ,.slv_latchd_rcvd_pkt_hdr       ( slv_latchd_rcvd_pkt_hdr       )
 ,.slv_lookup_resp_tlp_byte_len  ( slv_lookup_resp_tlp_byte_len  )
 ,.slv_lookup_resp_tlp_4rd       ( slv_lookup_resp_tlp_4rd       )
 ,.slv_lookup_resp_rreq_dma      ( slv_lookup_resp_rreq_dma      )
 ,.slv_lookup_resp_rreq_dma_chan ( slv_lookup_resp_rreq_dma_chan )
 ,.slv_lookup_apptag             ( slv_lookup_apptag             )
 ,.slv_pop_wiretag               ( slv_pop_wiretag               )
 ,.slv_lookup_wiretag            ( slv_lookup_wiretag            )
 ,.slv_lookup_wiretag_is_last    ( slv_lookup_wiretag_is_last    )

 ,.rdr_lookup_wiretag            ( rdr_lookup_wiretag            )
 ,.rdr_pop_wiretag               ( rdr_pop_wiretag               )
);

DWC_pcie_axi_cpl_comp_ctl_sbc
 #(
  .HDR_WD                  ( CC_RADMX_COMPOSER_HDR_WD )
 ,.CORE_DATA_BUS_WD        ( CORE_DATA_BUS_WD        )
 ,.CORE_DATA_BUS_WD_NP     ( CORE_DATA_BUS_WD_NP     )
 ,.NW                      ( NW                      )
 ,.GENERATE_STARTEND_ADDRS ( GENERATE_STARTEND_ADDRS )
 ,.HOLD_RADDR              ( HOLD_RADDR              )
 ,.MAX_IN_TAG              ( MAX_IN_TAG              )
 ,.MAX_IN_TAG_PW           ( MAX_IN_TAG_PW           )
) u_sbc (
  .clk                            ( clk                            )
 ,.slv_aclk                       ( slv_aclk                       )
 ,.rst_n                          ( rst_n                          )
 ,.slv_aresetn                    ( slv_aresetn                    )

  /* SBC write request interface                                  */
 ,.dataq_wr_en                    ( dataq_wr_en                    )
 ,.dataq_wr_start                 ( dataq_wr_start                 )
 ,.dataq_wr_keep                  ( dataq_wr_keep                  )
 ,.dataq_wr_drop                  ( dataq_wr_drop                  )
 ,.dataq_wr_seg_num               ( dataq_wr_seg_num               )
 ,.dataq_wr_data_s                (dataq_wr_data_s                 )

  /* SBC read request interface                                   */
 ,.dataq_rd_en                    ( dataq_rd_en_rdr                )
 ,.dataq_rd_seg_num               ( dataq_rd_seg_num_rdr           )

  /* SBC configuration interface, not used by DW_sbc_cdc          */
 ,.cfg_bridge_sb_init_i_synch_int ( /* Legacy port, not used */ '0 )
 ,.dataq_depth                    ( /* Legacy port, not used */ '0 )
 ,.cmp_sb_init_done               ( cmp_sb_init_done               )
 ,.num_segs                       ( /* Legacy port, not used */ '0 )

  /* SBC segment status feedback vectors                          */
 ,.dataq_empty                    ( /* UNC, is not used         */ )
 ,.dataq_empty_p_1                ( /* UNC, DNC CDC conv w u_rdr*/ )
 ,.dataq_full_m_1                 ( /* UNC                      */ )
 ,.dataq_seg_pkt_avail            ( /* UNC, DNC CDC conv w u_rdr*/ )

  /* SBC halt output to u_rdr                                     */
 ,.sbc_halt                       ( cdc_sbc_stall_out              )

 ,.ccmp_data_ram_addra            ( ccmp_data_ram_addra            )
 ,.ccmp_data_ram_addrb            ( ccmp_data_ram_addrb            )
 ,.ccmp_data_ram_dina             ( ccmp_data_ram_dina             )
 ,.ccmp_data_ram_doutb            ( ccmp_data_ram_doutb            )
 ,.ccmp_data_ram_enb              ( ccmp_data_ram_enb              )
 ,.ccmp_data_ram_wea              ( ccmp_data_ram_wea              )

  /* Segment information input from u_rdr                         */
 ,.dataq_rd_dv                    ( dataq_rd_dv_rdr                )
 ,.dataq_rd_eot                   ( dataq_rd_eot_rdr               )
 ,.dataq_rd_err                   ( dataq_rd_err_rdr               )
 ,.dataq_rd_tag                   ( dataq_rd_apptag_rdr            )
 ,.latchd_rcvd_pkt_hdr            ( slv_latchd_rcvd_pkt_hdr        )
 ,.lookup_resp_tlp_byte_len       ( slv_lookup_resp_tlp_byte_len   )
 ,.lookup_resp_tlp_low_addr       (                             '0 )
 ,.lookup_resp_tlp_4rd            ( slv_lookup_resp_tlp_4rd        )
 ,.lookup_resp_tlp_rreq_dma       ( slv_lookup_resp_rreq_dma       )
 ,.lookup_resp_tlp_rreq_dma_chan  ( slv_lookup_resp_rreq_dma_chan  )

  /* Composed piped packet output                                 */
 ,.piped_rd_data_dv               ( s_sbc_o.pkt_dv                 )
 ,.piped_rd_data_eot              ( s_sbc_o.pkt_eot                )
 ,.piped_rd_data_err              ( s_sbc_o.pkt_err                )
 ,.piped_rd_data                  ( s_sbc_o.pkt_data               )
 ,.piped_rd_data_ram_addrb        ( s_sbc_o_data_ram_addrb         )
 ,.piped_rd_dwen                  ( s_sbc_o.pkt_dwen               )
 ,.piped_rd_status_good           ( s_sbc_o_status_good            )
 ,.piped_rd_hdr                   ( s_sbc_o.pkt_hdr                )
 ,.piped_rd_pkt_tag               ( s_sbc_o.pkt_tag                )
 ,.piped_rd_pkt_byte_len          ( s_sbc_o.pkt_byte_len           )
 ,.piped_rd_pkt_low_addr          ( s_sbc_o.pkt_low_addr           )
 ,.piped_rd_pkt_4rd               ( s_sbc_o.pkt_4rd                )
 ,.piped_rd_pkt_rreq_dma          ( s_sbc_o.pkt_rreq_dma           )
 ,.piped_rd_pkt_rreq_dma_chan     ( s_sbc_o.pkt_rreq_dma_chan      )
 ,.axi_ras_par_ob_cpl_comp_dt_pulse (axi_ras_par_ob_cpl_comp_dt_pulse  )
 ,.ob_cpl_comp_dt_ras_dp_err_log    (ob_cpl_comp_dt_ras_dp_err_log     )  // Parity Checker
 ,.ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log (ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log)  // ECC Checker
 ,.chk_ras_recc_corr_cnt_ob_ccmp_data_pulse(chk_ras_recc_corr_cnt_ob_ccmp_data_pulse)
 ,.chk_ras_recc_ucorr_cnt_ob_ccmp_data_pulse(chk_ras_recc_ucorr_cnt_ob_ccmp_data_pulse)
 ,.ras_dp_err_inj_core_clk          (axi_bridge_ras_dp_err_inj_core_clk)
 ,.ras_dp_err_inj_slv_aclk          (ras_dp_err_inj_slv_aclk           )
 ,.core_clk_ordrb_ras_dp_err_inj    (core_clk_ordrb_ras_dp_err_inj)

  /* SBC halt input from u_algn                                   */
 ,.align_halt                     ( cdc_align_halt                 )
);

assign s_sbc_o.pkt_hv = 1'b0;

// ===============================================================================================================
//        RAM ECC check
// ===============================================================================================================

assign cfg_ras_recc_ob_ccmp_data_correct_n = ~cfg_ras_recc_ob_ccmp_data_correct;


always @(posedge slv_aclk or negedge slv_aresetn) begin : SEQ_PROC_AXI_RAS_DATA_ERR_ECC
  if(!slv_aresetn) begin
    axi_ras_recc_cnt_ob_ccmp_data_addr        <= #TP {(CC_OB_CCMP_DATA_RAM_ADDR_WD){1'b0}};
    axi_ras_recc_corr_cnt_ob_ccmp_data_pulse  <= #TP 1'b0;
    axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse <= #TP 1'b0;
  end else begin
    axi_ras_recc_cnt_ob_ccmp_data_addr        <= #TP s_sbc_o_data_ram_addrb;
    // Error qualified by halting, error conditions like timeout bypasses segmented buffer so can't use the TLP's HV / DV to qualify the error pulse
    axi_ras_recc_corr_cnt_ob_ccmp_data_pulse  <= #TP chk_ras_recc_corr_cnt_ob_ccmp_data_pulse  & s_sbc_o.pkt_dv & (~(s_sbc_o.pkt_err)) & (~cdc_align_halt);
    axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse <= #TP chk_ras_recc_ucorr_cnt_ob_ccmp_data_pulse & s_sbc_o.pkt_dv & (~(s_sbc_o.pkt_err)) & (~cdc_align_halt);
  end
end

  assign s_chk_delay_out_data = {s_sbc_o.pkt_dwen, s_sbc_o.pkt_data, s_sbc_o_status_good}; // data contains parity


assign s_early_algn_i_data = s_sbc_o.pkt_dv ? s_chk_delay_out_data[SBUF_DATA_HIGH : SBUF_DATA_LOW] : BUS_INIT;
assign s_early_algn_i_dwen =                  s_chk_delay_out_data[SBUF_DWEN_HIGH : SBUF_DWEN_LOW]  ;

always @(posedge slv_aclk or negedge slv_aresetn) begin : SEQ_PROC_PIPELINE_ECC
  if(!slv_aresetn) begin
    s_algn_i <= #TP '0;
  end else begin
    if(!cdc_align_halt) begin
      s_algn_i.pkt_dv            <= #TP s_sbc_o.pkt_dv;
      s_algn_i.pkt_eot           <= #TP s_sbc_o.pkt_eot;
      s_algn_i.pkt_err           <= #TP s_sbc_o.pkt_err;
      s_algn_i.pkt_data          <= #TP s_early_algn_i_data;
      s_algn_i.pkt_dwen          <= #TP s_early_algn_i_dwen;
      s_algn_i.pkt_hdr           <= #TP s_sbc_o.pkt_hdr;
      s_algn_i.pkt_tag           <= #TP s_sbc_o.pkt_tag;
      s_algn_i.pkt_byte_len      <= #TP s_sbc_o.pkt_byte_len;
      s_algn_i.pkt_low_addr      <= #TP s_sbc_o.pkt_low_addr;
      s_algn_i.pkt_4rd           <= #TP s_sbc_o.pkt_4rd;
      s_algn_i.pkt_rreq_dma      <= #TP s_sbc_o.pkt_rreq_dma;
      s_algn_i.pkt_rreq_dma_chan <= #TP s_sbc_o.pkt_rreq_dma_chan;
    end
  end
end

DWC_pcie_axi_cpl_comp_ctl_algn
 #(
  .HDR_WD           ( CC_RADMX_COMPOSER_HDR_WD )
 ,.CORE_DATA_BUS_WD ( CORE_DATA_BUS_WD )
 ,.NW               ( NW               )
) u_algn (
  .clk                       ( slv_aclk                   )
 ,.rst_n                     ( slv_aresetn                )

  /* Packet input from SBC                               */
 ,.in_pkt_hv                 ( 1'b0        /* not used */ )
 ,.in_pkt_dv                 ( s_algn_i.pkt_dv            )
 ,.in_pkt_eot                ( s_algn_i.pkt_eot           )
 ,.in_pkt_hdr                ( s_algn_i.pkt_hdr           )
 ,.in_pkt_data               ( s_algn_i.pkt_data          )
 ,.in_pkt_dwen               ( s_algn_i.pkt_dwen          )
 ,.in_pkt_byte_len           ( s_algn_i.pkt_byte_len      )
 ,.in_pkt_low_addr           ( s_algn_i.pkt_low_addr      )
 ,.in_pkt_tag                ( s_algn_i.pkt_tag           )
 ,.in_pkt_4rd                ( s_algn_i.pkt_4rd           )
 ,.in_pkt_rreq_dma           ( s_algn_i.pkt_rreq_dma      )
 ,.in_pkt_rreq_dma_chan      ( s_algn_i.pkt_rreq_dma_chan )
 ,.in_pkt_err                ( s_algn_i.pkt_err           )

  /* Halt output to SBC                                  */
 ,.out_halt                  ( cdc_align_halt             )

  /* Aligned packet output to slave interface            */
 ,.aligned_pkt_hv            ( s_dirty_algn_pkt_hv        )
 ,.aligned_pkt_dv            ( s_dirty_algn_pkt_dv        )
 ,.aligned_pkt_eot           ( s_algn_o.pkt_eot           )
 ,.aligned_pkt_hdr           ( s_algn_o.pkt_hdr           )
 ,.aligned_pkt_data          ( s_algn_o.pkt_data          )
 ,.aligned_pkt_dwen          ( s_algn_o.pkt_dwen          )
 ,.aligned_pkt_byte_len      ( s_algn_o.pkt_byte_len      )
 ,.aligned_pkt_low_addr      ( s_algn_o.pkt_low_addr      )
 ,.aligned_pkt_tag           ( s_algn_o.pkt_tag           )
 ,.aligned_pkt_4rd           ( s_algn_o.pkt_4rd           )
 ,.aligned_pkt_rreq_dma      ( s_algn_o.pkt_rreq_dma      )
 ,.aligned_pkt_rreq_dma_chan ( s_algn_o.pkt_rreq_dma_chan )
 ,.aligned_pkt_err           ( s_algn_o.pkt_err           )

  /* Halt input from slave interface                     */
 ,.in_halt                   ( s_clean_algn_in_halt       )
);

assign s_clean_algn_in_halt = s_algn_o.pkt_err ? slv_rsp_cycle_halt && s_algn_o.pkt_eot : s_algn_o.pkt_4rd ? slv_rsp_cycle_halt  : s_algn_o.pkt_eot && slv_rsp_cycle_halt;
assign s_algn_o.pkt_hv      = s_algn_o.pkt_err ?                       s_algn_o.pkt_eot : s_algn_o.pkt_4rd ? s_dirty_algn_pkt_hv : s_algn_o.pkt_eot ;
assign s_algn_o.pkt_dv      = s_algn_o.pkt_err ?                                   1'b0 : s_algn_o.pkt_4rd ? s_dirty_algn_pkt_dv : s_algn_o.pkt_eot ;

assign cmposed_pkt_hv            = s_algn_o.pkt_hv           ;
assign cmposed_pkt_dv            = s_algn_o.pkt_dv           ;
assign cmposed_pkt_eot           = s_algn_o.pkt_eot          ;
assign cmposed_pkt_hdr           = s_algn_o.pkt_hdr          ;
assign cmposed_pkt_data          = s_algn_o.pkt_data         ;
assign cmposed_pkt_dwen          = s_algn_o.pkt_dwen         ;
assign cmposed_pkt_byte_len      = s_algn_o.pkt_byte_len     ;
assign cmposed_pkt_low_addr      = s_algn_o.pkt_low_addr     ;
assign cmposed_pkt_tag           = s_algn_o.pkt_tag          ;
assign cmposed_pkt_4rd           = s_algn_o.pkt_4rd          ;
assign cmposed_pkt_rreq_dma      = s_algn_o.pkt_rreq_dma     ;
assign cmposed_pkt_rreq_dma_chan = s_algn_o.pkt_rreq_dma_chan;
assign cmposed_pkt_err           = s_algn_o.pkt_err          ;

// Process to latch the response info from Transaction look up unit for long PKT
always @(posedge clk or negedge rst_n)
begin: UPDATE_CONTROL
    integer j;
    if (!rst_n) begin
        update_done_ary                       <= #TP 1'b0;
        update_tag                            <= #TP 0;
        intag_released_d                      <= #TP 0;
    end else begin
        update_done_ary                       <= #TP rcvd_pkt_wr.eot & !rcvd_pkt_wr.err & lookup_last_resp_4outtag;
        update_tag                            <= #TP active_lookup_outtag;
        intag_released_d                      <= #TP intag_released;
     // CP14: ensure both long and short TLP received
    end
end

// ----------------------------------------------------------------------------------
// TAG look up and management module
// Converts an input pkt's tag ID to output pkt's ID

wire   ilookup_last_resp_4outtag;
P_APPTAG_PTR_TYPE ilookup_outtag; // Application TAG to identify one particular request

assign wr_atag_count = (`CC_COMPOSER_REGIN == 0) ? r_atag_count : s_atag_count;

always_ff @(posedge clk, negedge rst_n) begin : wtagInfo_atagCount_regPROC
  if(!rst_n) begin
    r_wtag_info  <= #`TP '0;
    r_atag_count <= #`TP '0;
  end else begin
    r_wtag_info  <= #`TP s_wtag_info ;
    r_atag_count <= #`TP s_atag_count;
  end
end : wtagInfo_atagCount_regPROC

always_comb begin : wtagBitLUTs_combPROC
  foreach(s_wtag_asgn[i]) begin
    s_wtag_asgn[i] = tag_consumed && (i == consumed_in_tag);
    s_wtag_rls[i]  = (intag_released || (cpl_timeout_sel && r_wtag_info[cpl_timeout_tag_sel[L_WTWD-1:0]].active)) && (i == (cpl_timeout_sel ? cpl_timeout_tag_sel : int_released_tag));
  end
end : wtagBitLUTs_combPROC

always_comb begin : atagBitLUTs_combPROC
  foreach(s_atag_incr[i]) begin
    s_atag_incr[i] = tag_consumed && (i == consumed_out_tag);
    s_atag_decr[i] = (intag_released || (cpl_timeout_sel && r_wtag_info[cpl_timeout_tag_sel[L_WTWD-1:0]].active)) && (i == (cpl_timeout_sel ? lookup_outtag_4cpl_timeout : active_lookup_outtag));
  end
end : atagBitLUTs_combPROC

always_comb begin : s_atag_count_PROC
  foreach(s_atag_count[i]) begin
    unique case({s_atag_incr[i], s_atag_decr[i]})
      2'b00: begin
               s_atag_count[i] = r_atag_count[i];
             end
      2'b01: begin
               s_atag_count[i] = '{
                 valid : r_atag_count[i].valid ? !(r_atag_count[i].count == 'd1) : 1'b0
                ,count : r_atag_count[i].count - 1'b1
               };
             end
      2'b10: begin
               s_atag_count[i] = '{
                 valid : consumed_last_tag || r_atag_count[i].valid
                ,count : r_atag_count[i].count + 1'b1
               };
             end
      2'b11: begin
               s_atag_count[i] = '{
                 valid : consumed_last_tag || r_atag_count[i].valid
                ,count : r_atag_count[i].count
               };
             end
      default: begin
                 s_atag_count[i] = r_atag_count[i];
               end
    endcase
  end
end : s_atag_count_PROC

`ifndef SYNTHESIS
`endif // SYNTHESIS

always_comb begin : s_wtag_info_PROC
  foreach(s_wtag_info[i]) begin
    unique case({s_wtag_asgn[i], s_wtag_rls[i]})
      2'b00,
      2'b11: begin
               s_wtag_info[i] = r_wtag_info[i];
             end
      2'b01: begin
               s_wtag_info[i] = wtagInfo_s'{
                 active : 1'b0
                ,apptag : r_wtag_info[i].apptag
               };
             end
      2'b10: begin
               s_wtag_info[i] = wtagInfo_s'{
                 active : 1'b1
                ,apptag : consumed_out_tag
               };
             end
      default: begin
                 s_wtag_info[i] = r_wtag_info[i];
               end
    endcase
  end
end : s_wtag_info_PROC

`ifndef SYNTHESIS
`endif // ! SYNTHESIS

assign ilookup_last_resp_4outtag  = r_wtag_info[w_rcvd_pkt.tag[L_WTWD-1:0]].active && isLast(wr_atag_count[w_rcvd_pkt.apptag]);
assign lookup_last_4cpl_timeout   = r_wtag_info[cpl_timeout_tag_sel[L_WTWD-1:0]].active && isLast(r_atag_count[cpl_timeout_apptag_sel]);
assign ilookup_outtag             = w_rcvd_pkt.apptag;
assign lookup_outtag_4cpl_timeout = cpl_timeout_apptag_sel;

assign  int_released_tag  = rcvd_pkt_wr.tag;

// When one full response has been composed, then we will halt the core's response queue from select the same tag again
wire   int_segment_busy;
assign  int_segment_busy            = cmpose_done_ary[ilookup_outtag] ;
reg    ilookup_last_resp_4outtag_d;
reg    int_segment_busy_d;
P_APPTAG_PTR_TYPE ilookup_outtag_d;          // Application TAG to identify one particular request

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n) begin
        ilookup_outtag_d   <= #TP 0;
        ilookup_last_resp_4outtag_d   <= #TP 0;
        int_segment_busy_d   <= #TP 0;
    end else begin
        ilookup_outtag_d   <= #TP ilookup_outtag;
        ilookup_last_resp_4outtag_d   <= #TP ilookup_last_resp_4outtag;
        int_segment_busy_d   <= #TP int_segment_busy;
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        latchd_rcvd_pkt_last   <= #TP 0;
    else if (rcvd_pkt_wr.hv)
        latchd_rcvd_pkt_last   <= #TP rcvd_pkt_wr.last;
end

assign segment_busy             = (`CC_COMPOSER_REGIN == 0) ? int_segment_busy : int_segment_busy_d;
assign active_lookup_outtag     = (`CC_COMPOSER_REGIN == 0) ? ilookup_outtag : ilookup_outtag_d;
assign lookup_last_resp_4outtag = (`CC_COMPOSER_REGIN == 0) ? (ilookup_last_resp_4outtag & rcvd_pkt_wr.last) : (ilookup_last_resp_4outtag_d & rcvd_pkt_wr.last) ;

assign tag_released             = (cpl_timeout_sel && r_wtag_info[cpl_timeout_tag_sel[L_WTWD-1:0]].active) | intag_released ;
assign released_tag             = (cpl_timeout_sel && r_wtag_info[cpl_timeout_tag_sel[L_WTWD-1:0]].active) ? cpl_timeout_tag_sel : int_released_tag;

// -------------------- function declarations ---------------------------------
  // Data without parity
  function automatic logic [CORE_DATA_BUS_WD_NP-1:0] fn_data_wo_par;
    input [CORE_DATA_BUS_WD-1:0] s_data_w_par;
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
  function automatic logic [CORE_DATA_BUS_WD-1:0] fn_data_w_par;
    input [CORE_DATA_BUS_WD_NP-1:0] s_data_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_data_for_par;

    begin
    fn_data_w_par  = {CORE_DATA_BUS_WD{1'b0}};
    s_data_for_par = {CX_RAS_PROT_RANGE{1'b0}};

      for (i=0; i<(NUM_DATA_PAR_BLOCKS); i=i+1) begin
        for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
          s_data_for_par[j]=s_data_wo_par[i*CX_RAS_PROT_RANGE +j];
          fn_data_w_par[i*CX_RAS_PROT_RANGE +j+i] = s_data_wo_par[i*CX_RAS_PROT_RANGE +j];
        end
        fn_data_w_par[(i+1)*CX_RAS_PROT_RANGE +i] = (CX_RAS_PARITY_MODE == '0) ? ^s_data_for_par : ~(^s_data_for_par);
      end
    end
  endfunction

  function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_dt;
    input [CORE_DATA_BUS_WD-1:0] s_data_w_par;
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

  `define OB_CCMP_DATA_RAM_DT_PTR 1
  `define OB_CCMP_DATA_RAM_DT_PTRW `PCIE_CORE_DATA_BUS_WD

`endif
endmodule : DWC_pcie_axi_cpl_comp_ctl
