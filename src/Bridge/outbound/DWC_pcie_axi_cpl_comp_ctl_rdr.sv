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
// ---    $DateTime: 2024/01/19 09:25:58 $ 
// ---    $Revision: #15 $ 
// ---    $Author: neira $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_axi_cpl_comp_ctl_rdr.sv#15 $ 
// -------------------------------------------------------------------------

/******
 * Module description:
 * From the core-clocked segment composition status, provides SBC read stimulus at AXI clock.
 *
 * In essence, the SBC read stimulus which were previously generated at core-clock, and the cpl data
 * then passed through a CDC FIFO to AXI clock, are now generated directly at AXI clock.
 *
 * If the freq of AXI is higher than core, this module removes the bottleneck caused by the slow core
 * reading from the SBC, and allows AXI to read directly from the SBC. This provides a significant
 * performance gain on long reads and out-of-order cpl reads.
 *****/
`include "include/DWC_pcie_ctl_all_defs.svh"

module DWC_pcie_axi_cpl_comp_ctl_rdr
  #(
    parameter TP                       = `TP
   ,parameter P_MAX_OUT_TAG_PW         = `CC_MAX_SLV_TAG_PW
   ,parameter P_MAX_IN_TAG             = (`CX_MAX_TAG + 1)
   ,parameter P_MAX_IN_TAG_PW          = `CX_LUT_PTR_WIDTH
   ,parameter P_SLV_ID_WD              = (`CC_SLV_BUS_ID_WIDTH + 1)
   ,parameter P_NUM_SEGMENTS           = `CC_MAX_SLV_TAG
   ,parameter P_NUM_SEGMENTS_PW        = `CC_MAX_SLV_TAG_PW
   ,parameter P_HDR_WD                 = `CC_RADMX_COMPOSER_HDR_WD
   ,parameter P_MAX_RD_SIZE_PW         = `CC_SLV_RD_REQ_SIZE_PW
   ,parameter P_SBUF_WC_PW             = ($clog2(`CC_RADMX_COMPOSER_SEG_DP) + 1)
   ,parameter P_AMBA_TLP_SEQ_WD        = `CC_AMBA_TLP_SEQ_WD
   ,parameter P_NVC                    = `CX_NVC
   ,parameter P_NVC_LOG2               = `CX_NVC_LOG2
   ,parameter P_ORDRB_NIDO             = `CC_ORDRB_NIDO
   ,parameter P_ORDRB_NIDO_WD          = `CC_ORDRB_NIDO_WD
   ,parameter P_N_EXPLICIT_FANOUT      = 5
  ) (
    input  logic                                          core_clk
   ,input  logic                                          slv_aclk
   ,input  logic                                          core_rst_n
   ,input  logic                                          slv_aresetn

    /*****
     * Segment composition status interface
     *****/
   ,input  logic                                          hdof_atag_vld                 /* cpl_comp has finished composing a segment */
   ,input  logic [P_MAX_OUT_TAG_PW  -1:0]                 hdof_atag                     /* ^ ID of composed segment                  */


   ,input  logic                                          composed_wtag_vld
   ,input  logic [P_MAX_IN_TAG_PW   -1:0]                 composed_wtag
   ,input  logic [P_SBUF_WC_PW      -1:0]                 composed_wtag_len

    /*****
     * Last completed Posted request interface (from AXI Master)
     *****/
   ,input  logic [P_AMBA_TLP_SEQ_WD-1:0]                  last_presp_rpseq_per_vc [P_NVC-1:0]

    /*****
     * Tag consumption interface
     *****/
   ,input  logic                                          tag_consumed                  /* core_clk tag consumed at npdcmp           */
   ,input  logic                                          consumed_4rd                  /* core_clk tag consumed is for read         */
   ,input  logic [P_MAX_RD_SIZE_PW  -1:0]                 consumed_tlp_byte_len
   ,input  logic [P_MAX_OUT_TAG_PW  -1:0]                 consumed_out_tag              /* core_clk apptag consumed                  */
   ,input  logic [                3 -1:0]                 consumed_rreq_dma             /* core_clk DMA request type                 */
   ,input  logic [                3 -1:0]                 consumed_rreq_dma_chan        /* core_clk DMA channel                      */

   ,input  logic                                          consumed_tag_from_nprf        /* slv_aclk tag consumed at npdcmp           */
   ,input  logic [P_SLV_ID_WD       -1:0]                 nprf_id                       /* slv_aclk tag consumed AXI id              */
   ,input  logic [P_MAX_OUT_TAG_PW  -1:0]                 nprf_tag                      /* slv_aclk tag consumed app tag             */

    /*****
     * SBC backpressure interface
     *****/
   ,input  logic [P_N_EXPLICIT_FANOUT -1:0]               stall_out                     /* slv_aclk backpressure from SBC rd side    */

    /*****
     * Segment composition and tag status
     *****/
   ,input  logic [P_NUM_SEGMENTS    -1:0]                          latchd_req_flushed        /* core_clk apptag flush status                                            */
   ,input  logic [P_NUM_SEGMENTS    -1:0]                          latchd_req_timedout       /* core_clk apptag timeout status                                          */
   ,input  logic [P_NUM_SEGMENTS    -1:0]          [P_HDR_WD -1:0] latchd_rcvd_pkt_hdr       /* core_clk apptag packet header                                           */
   ,input  logic [P_NUM_SEGMENTS    -1:0] [P_AMBA_TLP_SEQ_WD -1:0] latchd_rcvd_pkt_pseq      /* core_clk received posted request sequence number information            */
   ,input  logic [P_NUM_SEGMENTS    -1:0]                          latchd_rcvd_pkt_hold_preq /* core_clk received hold status (waiting for outstanding P request)       */
   ,input        [P_NVC            -1:0]                           trgt1_p_xfer_pend_per_vc  /* core_clk pendinng P requests in RADM or AXI bridge per VC               */

    /*****
     * Response data read interface
     *****/
   ,output logic                                          dataq_rd_en                   /* slv_aclk SBC read enable                  */
   ,output logic [P_MAX_OUT_TAG_PW  -1:0]                 dataq_rd_apptag
   ,output logic [P_MAX_IN_TAG_PW   -1:0]                 dataq_rd_seg_num              /* slv_aclk SBC read apptag                  */
   ,output logic                                          dataq_rd_eot                  /* slv_aclk SBC read last element flag       */
   ,output logic                                          dataq_rd_dv                   /* slv_aclk SBC read expecting data          */
   ,output logic                                          dataq_rd_err                  /* slv_aclk SBC read is for flush/timeout    */

    /*****
     * Response reconstruction interface
     *****/
   ,output logic [P_HDR_WD -1:0]                          slv_latchd_rcvd_pkt_hdr       /* slv_aclk response packet header           */
   ,output logic [P_MAX_RD_SIZE_PW  -1:0]                 slv_lookup_resp_tlp_byte_len  /* slv_aclk response packet byte length      */
   ,output logic                                          slv_lookup_resp_tlp_4rd       /* slv_aclk response packet is for read      */
   ,output logic [                3 -1:0]                 slv_lookup_resp_rreq_dma      /* slv_aclk response packet DMA request type */
   ,output logic [                3 -1:0]                 slv_lookup_resp_rreq_dma_chan /* slv_aclk response packet DMA channel      */

   ,output logic [P_MAX_OUT_TAG_PW  -1:0]                 slv_lookup_apptag             /* slv_aclk read translation apptag out      */
   ,output logic                                          slv_pop_wiretag               /* slv_aclk read translation wtag pop out    */
   ,input  logic [P_MAX_IN_TAG_PW   -1:0]                 slv_lookup_wiretag            /* slv_aclk read translation wiretag in      */
   ,input  logic                                          slv_lookup_wiretag_is_last    /* slv_aclk read translation wiretag is last */

   ,output logic [P_MAX_IN_TAG_PW   -1:0]                 rdr_lookup_wiretag
   ,output logic                                          rdr_pop_wiretag
  );

  // With explicit fanout (CX_EXPLICIT_FANOUT) we take 5 stall_out inputs for internal comb logic distribution
  localparam L_SEQ_N_EFAN        = 3; // 3 out of the 5 internal explicit fanout paths are routed to u_seq
  localparam L_N_EXPLICIT_FANOUT = L_SEQ_N_EFAN + 2 ; // Internally always use explicit fanout wiring widths

  localparam integer REG_DELAY_DENOM = 1000                 ;
  localparam integer REG_DELAY_TIME  = `TP * REG_DELAY_DENOM;

  /* Parameters for internal CDC FIFO c2a                                                                       */
  localparam LP_C2A_DP     = P_NUM_SEGMENTS      ; /* Pending requests will never exceed the number of segments */
  localparam LP_C2A_DP_P1  = LP_C2A_DP + 1       ;
  localparam LP_C2A_AW     = $clog2(LP_C2A_DP)   ; /* Pointer width                                             */
  localparam LP_C2A_RAM_DP = (LP_C2A_DP == (1 << LP_C2A_AW)) ? LP_C2A_DP : (LP_C2A_DP|1)+1;
  localparam LP_C2A_SY_F   = `CX_PCIE_SYNC_DEPTH ;
  localparam LP_C2A_SY_R   = `CX_PCIE_SYNC_DEPTH ;
  localparam LP_C2A_CW     = $clog2(LP_C2A_DP_P1); /* Counter width                                             */

  // Mis-sampling delay for quasi static signals
  localparam CC_MIS_SAMPLING_DELAY = 3;

  // Cut extraneous 'composed_tag' MSBs for array indexing
  localparam L_CTWD = (P_MAX_IN_TAG == 1) ? 1 : $clog2(P_MAX_IN_TAG);

  /* Definitions                                                                                                */
  typedef enum logic [1:0] {
    E_RD_KOI = 2'b00,
    E_RD_ITL = 2'b01,
    E_RD_KOL = 2'b10,
    E_RD_LTI = 2'b11
  } rdTransition_e;

  typedef enum logic {
    E_RD_IDLE = 1'b0,
    E_RD_LONG = 1'b1
  } rdState_e;

  typedef enum logic [2:0] {
    E_NO_BEATS_W_NXT   = 3'b000,
    E_NO_BEATS_WO_NXT  = 3'b001,
    E_ONE_BEAT_W_NXT   = 3'b010,
    E_ONE_BEAT_WO_NXT  = 3'b011,
    E_MUL_BEATS_W_NXT  = 3'b100,
    E_MUL_BEATS_WO_NXT = 3'b101,
    E_INVALID          = 3'b110
  } dataqStat_e;

  typedef struct packed {
    // KOI: Keep on Idle
    logic koi_true_idle;
    logic koi_err_no_beats;
    logic koi_err_one_beat;
    logic koi_nor_one_beat;

    // ITL: Idle to Long
    logic itl_err_mul_beats;
    logic itl_nor_mul_beats;

    // KOL: Keep on Long
    logic kol_keep_wt;
    logic kol_pop_wt;

    // LTI: Long to Idle
    logic lti_last_wt_nor;
    logic lti_last_wt_err;
  } rdTransitionHint_s;

  typedef struct packed {
    logic                          latchd_req_flushed       ; /*** Segment information LUT structure           ***/
    logic                          latchd_req_timedout      ; /* This information is handed off to read side     */
    logic [         P_HDR_WD -1:0] latchd_rcvd_pkt_hdr      ; /* Upon segment consumption or composition         */
    logic [P_AMBA_TLP_SEQ_WD -1:0] latchd_rcvd_pkt_pseq     ; /* core_clk received posted request sequence number information            */
    logic                          latchd_rcvd_pkt_hold_preq; /* core_clk received hold status (waiting for outstanding P request)       */
    logic                          lookup_resp_tlp_4rd      ; /*                                                 */
    logic [P_MAX_RD_SIZE_PW  -1:0] lookup_resp_tlp_byte_len ; /*                                                 */
    logic [                3 -1:0] lookup_resp_rreq_dma     ; /*                                                 */
    logic [                3 -1:0] lookup_resp_rreq_dma_chan; /*                                                 */
  } segInfo_s;

 typedef struct packed {
    logic                                en;
    logic                                dv;
    logic                                eot;
    logic                                err;
    logic [$bits(dataq_rd_apptag)  -1:0] apptag;
    logic [$bits(dataq_rd_seg_num) -1:0] seg_num;
  } dataqRd_t;

  typedef union packed {
    logic [L_N_EXPLICIT_FANOUT -1:0] as_bus;
    struct packed {
      logic                                w_rdr; // Fanout directed at u_rdr internal
      logic                                w_ts;  // Fanout directed at u_npdcmp.u_ts
      logic [L_SEQ_N_EFAN -1:0]            w_seq; // Fanout directed at u_seq
    } as_struct;
  } explicitFanout_u;

  dataqRd_t i_dataq_rd, s_dataq_rd;

  /* input -> u_seq sync                                                                                        */
  logic                         composed_seg_atseq     ;  /* slv_aclk segment composed pulse                    */
  logic [P_MAX_OUT_TAG_PW -1:0] composed_seg_num_atseq ;  /* slv_aclk segment composed apptag                   */
  logic [L_SEQ_N_EFAN     -1:0] consumed_seg_atseq     ;  /* slv_aclk segment read started                      */
  logic [L_SEQ_N_EFAN     -1:0] consumed_seg_atslv     ;

  logic                         s_c2a_full             ;
  logic                         s_c2a_empty            ;
  logic                         s_c2a_push_req_n       ;
  logic                         s_c2a_pop_req_n        ;
  logic                         w_c2a_wen              ;
  logic [LP_C2A_AW        -1:0] w_c2a_wr_addr          ;
  logic [LP_C2A_AW        -1:0] w_c2a_rd_addr          ;
  logic [P_MAX_OUT_TAG_PW -1:0] s_c2a_rd_data          ;
  logic [P_MAX_OUT_TAG_PW -1:0] s_c2a_rd_data_d        ;
  logic                         s_c2a_pop_req_d        ;
  logic                         s_rs_ready             ;

  /* u_seq -> slv rd sync                                                                                       */
  logic                         active_tag_valid_atseq ;
  logic                         active_tag_valid_atslv ;

  logic [P_MAX_OUT_TAG_PW -1:0] active_tag_atslv       ;
  logic [P_MAX_OUT_TAG_PW -1:0] active_tag_atseq       ;
  logic [P_MAX_OUT_TAG_PW -1:0] r_active_tag_atslv     ;
  logic [P_MAX_OUT_TAG_PW -1:0] s_rd_tag_atslv         ;

  logic [P_SBUF_WC_PW     -1:0] r_active_len_atslv     ;
  logic [P_SBUF_WC_PW     -1:0] s_pending_len_atslv    ;

  logic                         dataq_seg_pkt_avail    ;
  logic                         dataq_empty_p_1        ;

  /* apptag status                                                                                              */
segInfo_s [P_NUM_SEGMENTS -1:0] segInfo_dp             ;
segInfo_s [P_NUM_SEGMENTS -1:0] segInfo_dp_qst         ;
 logic [P_MAX_IN_TAG -1:0] [P_SBUF_WC_PW -1:0] r_wc    ;
 logic [P_MAX_IN_TAG -1:0] [P_SBUF_WC_PW -1:0] r_wc_qst;

  /* rd logic                                                                                                   */
  explicitFanout_u              halt_rd                ; /* Slave has backpressured packet output               */
  logic                         r_slv_pop_wiretag      ;

  rdTransitionHint_s            rd_hint                ;
  rdTransition_e                rd_transition          ;
  dataqStat_e                   dataq_stat             ;
  rdState_e                     rd_state               ;
  logic                         dataq_err_on_atag      ;


  /*****
  * C2A: Core to AXI (run u_seq at AXI clock)
  * Place a CDC FIFO at the u_seq input interface
  * The interface works at event semantics triggered on the flag:
  *  composed_seg
  *
  * CDC FIFO depth: NUM_SEGS (never fills due to matching the number of
  *                           outstanding requests                     )
  *
  * CDC FIFO push : Whenever a segment is composed at core_clk
  * CDC FIFO pop  : Whenever the sequencer is able to read composition data
  *
  *****/

  assign s_c2a_push_req_n = !( (!s_c2a_full ) && hdof_atag_vld );
  assign s_c2a_pop_req_n  = !( (!s_c2a_empty) && s_rs_ready    );

  DWC_pcie_ctl_bcm87
   #(
    .DEPTH           ( LP_C2A_DP       )
   ,.ADDR_WIDTH      ( LP_C2A_AW       )
   ,.PUSH_SYNC       ( LP_C2A_SY_R     )
   ,.POP_SYNC        ( LP_C2A_SY_F     )
   ,.COUNT_WIDTH     ( LP_C2A_CW       )
   ,.REG_DELAY_DENOM ( REG_DELAY_DENOM )
   ,.REG_DELAY_TIME  ( REG_DELAY_TIME  )
  ) u_c2a (
    .clk_push        ( core_clk         )
   ,.rst_push_n      ( core_rst_n       )
   ,.init_push_n     ( 1'b1             )
   ,.push_req_n      ( s_c2a_push_req_n )
// SMD: Output port to an instance is not connected
// SJ:  These BCM ports are not used.
// spyglass disable_block W287b
   ,.push_empty      ( /*     NC     */ )
   ,.push_ae         ( /*     NC     */ )
   ,.push_hf         ( /*     NC     */ )
   ,.push_af         ( /*     NC     */ )
// spyglass enable_block W287b
// SMD: Variable is set but not read
// SJ: This variable is used under SVAs, which are not analysed by sg-lint
// spyglass disable_block W528
   ,.push_full       ( s_c2a_full       )
// spyglass enable_block W528
// SMD: Output port to an instance is not connected
// SJ:  These BCM ports are not used.
// spyglass disable_block W287b
   ,.push_error      ( /*     NC     */ )
   ,.push_word_count ( /*     NC     */ )
// spyglass enable_block W287b

   ,.we_n            ( w_c2a_wen        )
   ,.wr_addr         ( w_c2a_wr_addr    )

   ,.clk_pop         ( slv_aclk         )
   ,.rst_pop_n       ( slv_aresetn      )
   ,.init_pop_n      ( 1'b1             )
   ,.pop_req_n       ( s_c2a_pop_req_n  )
   ,.pop_empty       ( s_c2a_empty      )
// SMD: Output port to an instance is not connected
// SJ:  These BCM ports are not used.
// spyglass disable_block W287b
   ,.pop_ae          ( /*     NC     */ )
   ,.pop_hf          ( /*     NC     */ )
   ,.pop_af          ( /*     NC     */ )
   ,.pop_full        ( /*     NC     */ )
   ,.pop_error       ( /*     NC     */ )
   ,.pop_word_count  ( /*     NC     */ )
// spyglass enable_block W287b
   ,.rd_addr         ( w_c2a_rd_addr    )
  );

  DWC_pcie_mem_dff
   #(
    .WIDTH      ( P_MAX_OUT_TAG_PW )
   ,.DEPTH      ( LP_C2A_RAM_DP    )
   ,.ADDR_WIDTH ( LP_C2A_AW        )
   ) u_c2a_mem (
    .clk     ( core_clk               )
   ,.rst_n   ( core_rst_n             )
   ,.wr_n    ( w_c2a_wen              )
   ,.wr_data ( hdof_atag              )
   ,.rd_addr ( w_c2a_rd_addr          )
   ,.rd_n    ( s_c2a_pop_req_n        )
   ,.wr_addr ( w_c2a_wr_addr          )
   ,.rd_data ( s_c2a_rd_data          )
  );

  // Register the data out from RAM Flip-Flop-Based
  // This improve the fanout from point of view of DC constraints
  DWC_pcie_axi_rs
  
    #(
      .P_FEED_READY (1'b1            )
     ,.CHAN_WD      (P_MAX_OUT_TAG_PW)
     ) u_rd_data_rs (
        .clk            (slv_aclk             )
       ,.rstn           (slv_aresetn          )
       ,.clrn           (1'b1                 )
       ,.vld_from_src   (!s_c2a_empty         )
       ,.chanl_from_src (s_c2a_rd_data        )
       ,.rdy_from_dest  (1'b1                 )
       ,.vld_to_dest    (s_c2a_pop_req_d      )
       ,.chanl_to_dest  (s_c2a_rd_data_d      )
       ,.rdy_to_src     (s_rs_ready           )
     );

  /*****
   * Calculate which segment to consume next
   *****/
  assign composed_seg_atseq     = s_c2a_pop_req_d;
  assign composed_seg_num_atseq = s_c2a_rd_data_d;

  logic [P_AMBA_TLP_SEQ_WD -1:0] composed_seg_pseq_atseq;
  logic                          composed_seg_hold_preq_atseq;

  segInfo_s segInfo_dp_qst_composed_seg_num_atseq;

// segInfo_dp_qst is a FF array on a different clock domain
// when reading from such a structure a NAND mux must be used

  DWC_pcie_ctl_cdc_mux
  
   #(
     .WIDTH      ( $bits(segInfo_s) ),
     .DEPTH      ( P_NUM_SEGMENTS   ),
     .ADDR_WIDTH ( P_MAX_OUT_TAG_PW )
    )  u_mux0 (
     .mem_ary (  segInfo_dp_qst                        ),
     .rd_addr (  composed_seg_num_atseq                ),
     .rd_n    ( !composed_seg_atseq                    ),
     .rd_data (  segInfo_dp_qst_composed_seg_num_atseq )
  );

  assign composed_seg_pseq_atseq      = segInfo_dp_qst_composed_seg_num_atseq.latchd_rcvd_pkt_pseq;
  assign composed_seg_hold_preq_atseq = segInfo_dp_qst_composed_seg_num_atseq.latchd_rcvd_pkt_hold_preq;

  wire [P_NVC-1:0] trgt1_p_xfer_pend_per_vc_c2s;

  DWC_pcie_src_reg_sync
  
  #(
   .WIDTH       (P_NVC              ),
   .F_SYNC_TYPE (`CX_PCIE_SYNC_DEPTH),
   .VERIF_EN    (1                  )
  )
  u_bcm21_trgt1_p_xfer_pend_per_vc_c2s
  (
  .clk_s        (core_clk                    ),
  .rst_s_n      (core_rst_n                  ),
  .clk_d        (slv_aclk                    ),
  .rst_d_n      (slv_aresetn                 ),
  .data_s       (trgt1_p_xfer_pend_per_vc    ),
  .data_d       (trgt1_p_xfer_pend_per_vc_c2s)
  );



  DWC_pcie_axi_cpl_comp_ctl_seq
  
  u_seq (
    .clk                       ( slv_aclk                     )
   ,.rst_n                     ( slv_aresetn                  )
   ,.composed_seg              ( composed_seg_atseq           )
   ,.composed_seg_num          ( composed_seg_num_atseq       )
   ,.composed_seg_pseq         ( composed_seg_pseq_atseq      )
   ,.composed_seg_hold_preq    ( composed_seg_hold_preq_atseq )

   ,.consumed_seg              ( consumed_seg_atseq           )
   ,.last_tag_consumed         ( consumed_tag_from_nprf       )
   ,.consumed_axi_id           ( nprf_id                      )
   ,.consumed_out_tag          ( nprf_tag                     )

   ,.active_tag                ( active_tag_atseq             )
   ,.active_tag_valid          ( active_tag_valid_atseq       )
   ,.last_presp_rpseq_per_vc   ( last_presp_rpseq_per_vc      )
   ,.trgt1_p_xfer_pend_per_vc  ( trgt1_p_xfer_pend_per_vc_c2s )
  );

// Optionally break the timing path between completion composer and slave linked list tracker
// Adds 1 cycle of latency between sequencer and reader
//
//    1. Input side                                              2. Output side
// A. active_tag_atseq            ----- ( slice         ) -----> active_tag_atslv
// B. active_tag_valid_atseq      ----- ( slice         ) -----> active_tag_valid_atslv
// C. consumed_seg_atseq         <----- ( predict logic ) -----  consumed_seg_atslv
// D. slv_lookup_apptag          <----- ( predict logic ) -----  rdr_lookup_apptag
// E. slv_lookup_wiretag          ----- ( slice         ) -----> rdr_lookup_wiretag
// F. slv_lookup_wiretag_is_last  ----- ( slice         ) -----> rdr_lookup_wiretag_is_last
// G. slv_pop_wiretag            <----- ( predict logic ) -----  rdr_pop_wiretag
//
logic                         rdr_lookup_wiretag_is_last;
logic [P_MAX_OUT_TAG_PW -1:0] rdr_lookup_apptag;

  typedef struct packed{
    logic                                                       last;
    logic                               [P_MAX_IN_TAG_PW  -1:0] wiretag;
    logic                                                       atag_vld;
    logic                               [P_MAX_OUT_TAG_PW -1:0] atag;
  } rs_t;

  typedef enum logic {
    E_SLICE_IDLE    = 1'b0
   ,E_SLICE_ONGOING = 1'b1
  } sliceState_e;

  logic s_vld_from_src;
  rs_t  s_chanl_from_src;
  logic s_rdy_from_dest;
  logic s_vld_to_dest;
  rs_t  s_chanl_to_dest;
  logic s_rdy_to_src;

  logic s_pop_wtag;
  logic s_pop_last;
  logic s_pop_seq;

  logic pull_from_src;

  sliceState_e s_slice_state, r_slice_state;

  DWC_pcie_axi_rs
   #(
    .P_FEED_READY ( 1'b0        )
   ,.CHAN_WD      ( $bits(rs_t) )
  ) u_lookup_rs (
    .clk            ( slv_aclk         )
   ,.rstn           ( slv_aresetn      )
   ,.clrn           ( 1'b1             )
   ,.vld_from_src   ( s_vld_from_src   )
   ,.chanl_from_src ( s_chanl_from_src )
   ,.rdy_from_dest  ( s_rdy_from_dest  )
   ,.vld_to_dest    ( s_vld_to_dest    )
   ,.chanl_to_dest  ( s_chanl_to_dest  )
   ,.rdy_to_src     ( s_rdy_to_src     )
  );

  always_comb begin
    case (r_slice_state)
      E_SLICE_IDLE    : s_slice_state = (!slv_lookup_wiretag_is_last && !halt_rd.as_struct.w_rdr && active_tag_valid_atseq && s_rdy_to_src) ? E_SLICE_ONGOING : E_SLICE_IDLE   ;
      E_SLICE_ONGOING : s_slice_state = ( slv_lookup_wiretag_is_last && slv_pop_wiretag                                                  ) ? E_SLICE_IDLE    : E_SLICE_ONGOING;
    endcase
  end

  always_ff @(posedge slv_aclk, negedge slv_aresetn) begin
    if(!slv_aresetn) begin
      r_slice_state <= #TP E_SLICE_IDLE;
    end else begin
      r_slice_state <= #TP s_slice_state;
    end
  end

  assign s_pop_seq  =  (r_slice_state == E_SLICE_IDLE   ) && active_tag_valid_atseq && s_rdy_to_src;

  assign s_pop_last = ((r_slice_state == E_SLICE_IDLE   ) && active_tag_valid_atseq && !halt_rd.as_struct.w_rdr && slv_lookup_wiretag_is_last && s_rdy_to_src) ||
                      ((r_slice_state == E_SLICE_ONGOING) && slv_pop_wiretag        &&                            slv_lookup_wiretag_is_last && s_rdy_to_src)   ;

  assign s_pop_wtag = (s_pop_seq && !halt_rd.as_struct.w_ts) ||
                      ((r_slice_state == E_SLICE_ONGOING) && s_rdy_to_src);

  assign s_vld_from_src = (s_pop_seq && !halt_rd.as_struct.w_rdr) || (r_slice_state == E_SLICE_ONGOING);

  assign slv_lookup_apptag = (s_pop_seq && !halt_rd.as_struct.w_ts) ? active_tag_atseq : rdr_lookup_apptag;
  assign slv_pop_wiretag   = s_pop_wtag;

  assign s_chanl_from_src = '{
    last        : slv_lookup_wiretag_is_last
   ,wiretag     : slv_lookup_wiretag
   ,atag_vld    : active_tag_valid_atseq && s_pop_seq && !halt_rd.as_struct.w_rdr
   ,atag        : active_tag_atseq
  };

  assign s_rdy_from_dest = rdr_pop_wiretag;

  assign consumed_seg_atseq = {L_SEQ_N_EFAN{s_pop_seq}} & ~halt_rd.as_struct.w_seq;

  assign rdr_lookup_wiretag_is_last = s_chanl_to_dest.last;
  assign rdr_lookup_wiretag         = s_chanl_to_dest.wiretag;
  assign active_tag_valid_atslv     = s_chanl_to_dest.atag_vld;
  assign active_tag_atslv           = s_chanl_to_dest.atag;


  /*****
   * Seg composition status sync LUT
   *****/
  always_ff @(posedge core_clk, negedge core_rst_n) begin : SEG_INFO_WR_PROC
    if(!core_rst_n)
      segInfo_dp <= #TP '0;
    else begin
      // SMD:Signal may be multiply assigned (beside initialization) in the same scope
      // SJ: It's a Spyglass bug related to SystemVerilog code. The signal reported is an array of structures and each field is independent.
      // spyglass disable_block W415a
      /* Information to store after segment composition status is known */
      if(hdof_atag_vld) begin
        segInfo_dp[hdof_atag].latchd_req_flushed               <= #TP latchd_req_flushed       [hdof_atag];
        segInfo_dp[hdof_atag].latchd_req_timedout              <= #TP latchd_req_timedout      [hdof_atag];
        segInfo_dp[hdof_atag].latchd_rcvd_pkt_hdr              <= #TP latchd_rcvd_pkt_hdr      [hdof_atag];
        segInfo_dp[hdof_atag].latchd_rcvd_pkt_pseq             <= #TP latchd_rcvd_pkt_pseq     [hdof_atag];
        segInfo_dp[hdof_atag].latchd_rcvd_pkt_hold_preq        <= #TP latchd_rcvd_pkt_hold_preq[hdof_atag];
      end

      /* Information to store after a new tag has been consumed         */
      if(tag_consumed) begin
        segInfo_dp[consumed_out_tag].lookup_resp_tlp_4rd       <= #TP consumed_4rd          ;
        segInfo_dp[consumed_out_tag].lookup_resp_tlp_byte_len  <= #TP consumed_tlp_byte_len ;
        segInfo_dp[consumed_out_tag].lookup_resp_rreq_dma      <= #TP consumed_rreq_dma     ;
        segInfo_dp[consumed_out_tag].lookup_resp_rreq_dma_chan <= #TP consumed_rreq_dma_chan;
      end
      // spyglass enable_block W415a
    end
  end

  // BCM36_NHS for quasi static signals
  localparam L_BCM36_WD = $bits(segInfo_dp) + $bits(r_wc);

  DWC_pcie_ctl_bcm36_nhs
   #(
    .WIDTH      ( L_BCM36_WD            ),
    .DATA_DELAY ( CC_MIS_SAMPLING_DELAY )
  ) u_bcm36_nhs_segInfo_dp_qst (
  `ifndef SYNTHESIS
    .clk_d   ( slv_aclk    ),
    .rst_d_n ( slv_aresetn ),
  `endif // SYNTHESIS
    .data_s  ( {segInfo_dp    , r_wc    } ),
    .data_d  ( {segInfo_dp_qst, r_wc_qst} )
  );

  always_ff @(posedge core_clk, negedge core_rst_n) begin : R_WC_PROC
    if(!core_rst_n) begin
      r_wc <= #TP '0;
    end else begin
      if(composed_wtag_vld) begin
        r_wc[composed_wtag[L_CTWD-1:0]] <= #TP composed_wtag_len;
      end
    end
  end : R_WC_PROC

  segInfo_s segInfo_dp_qst_rd_tag_atslv;
  wire s_rd_in_progress;
  
  assign s_rd_in_progress = active_tag_valid_atslv || (rd_state == E_RD_LONG);

// segInfo_dp_qst is a FF array on a different clock domain
// when reading from such a structure a NAND mux must be used

  DWC_pcie_ctl_cdc_mux
  
   #(
     .WIDTH      ( $bits(segInfo_s) ),
     .DEPTH      ( P_NUM_SEGMENTS   ),
     .ADDR_WIDTH ( P_MAX_OUT_TAG_PW )
    )  u_mux1 (
     .mem_ary (  segInfo_dp_qst              ),
     .rd_addr (  s_rd_tag_atslv              ),
     .rd_n    ( !s_rd_in_progress            ),
     .rd_data (  segInfo_dp_qst_rd_tag_atslv )
  );

  always_comb begin : SEG_INFO_TO_OUTPUT_PROC

    /* Assign resp interface to current read segment */
    slv_latchd_rcvd_pkt_hdr       = segInfo_dp_qst_rd_tag_atslv.latchd_rcvd_pkt_hdr      ;
    slv_lookup_resp_tlp_4rd       = segInfo_dp_qst_rd_tag_atslv.lookup_resp_tlp_4rd      ;
    slv_lookup_resp_tlp_byte_len  = segInfo_dp_qst_rd_tag_atslv.lookup_resp_tlp_byte_len ;
    slv_lookup_resp_rreq_dma      = segInfo_dp_qst_rd_tag_atslv.lookup_resp_rreq_dma     ;
    slv_lookup_resp_rreq_dma_chan = segInfo_dp_qst_rd_tag_atslv.lookup_resp_rreq_dma_chan;
  end : SEG_INFO_TO_OUTPUT_PROC

  assign rdr_lookup_apptag = s_rd_tag_atslv;

  /*****
   * Every time we start reading a new segment, register the new read tag
   *****/
  always_ff @(posedge slv_aclk, negedge slv_aresetn) begin : SEQ_R_ACTIVE_TAG_PROC
    if(!slv_aresetn) begin
      r_active_tag_atslv <= #TP 1'b0;
    end else if (consumed_seg_atslv[1]) begin
      r_active_tag_atslv <= #TP active_tag_atslv;
    end
  end

  always_ff @(posedge slv_aclk, negedge slv_aresetn) begin : R_SLV_POP_WIRETAG
    if(!slv_aresetn) begin
      r_slv_pop_wiretag <= #TP 1'b0;
    end else begin
      r_slv_pop_wiretag <= #TP rdr_pop_wiretag;
    end
  end

  logic [P_SBUF_WC_PW -1:0] r_wc_qst_dataq_rd_seg_num;

// r_wc_qst is a FF array on a different clock domain
// when reading from such a structure a NAND mux must be used

  DWC_pcie_ctl_cdc_mux
  
   #(
     .WIDTH      ( P_SBUF_WC_PW    ),
     .DEPTH      ( P_MAX_IN_TAG    ),
     .ADDR_WIDTH ( L_CTWD          )
    )  u_mux2 (
     .mem_ary (  r_wc_qst                       ),
     .rd_addr (  i_dataq_rd.seg_num[L_CTWD-1:0] ),
     .rd_n    ( !s_rd_in_progress               ),
     .rd_data (  r_wc_qst_dataq_rd_seg_num      )
  );

  always_ff @(posedge slv_aclk, negedge slv_aresetn) begin : SEQ_R_ACTIVE_LEN_PROC
    if(!slv_aresetn)
      r_active_len_atslv <= #TP '0;
    else begin
      /* On read start of new segment, latch the pending length */
      if(consumed_seg_atslv[2] || r_slv_pop_wiretag) begin
        r_active_len_atslv <= #TP i_dataq_rd.en ? (r_wc_qst_dataq_rd_seg_num - 1'b1) : r_wc_qst_dataq_rd_seg_num;
       /* During active read, decrease pending length on pop */
      end else if(rd_state == E_RD_LONG && i_dataq_rd.en) begin
        r_active_len_atslv <= #TP (r_active_len_atslv - 1'b1);
      end
    end
  end

  assign s_pending_len_atslv = (rd_state == E_RD_IDLE || r_slv_pop_wiretag) ? r_wc_qst_dataq_rd_seg_num : r_active_len_atslv;
  assign dataq_seg_pkt_avail = rdr_lookup_wiretag_is_last ? (|s_pending_len_atslv) : 1'b1;
  assign dataq_empty_p_1     = (s_pending_len_atslv == 'd1);

  assign s_rd_tag_atslv = (rd_state == E_RD_IDLE) ? active_tag_atslv : r_active_tag_atslv;

  assign dataq_err_on_atag = (segInfo_dp_qst_rd_tag_atslv.latchd_req_flushed || segInfo_dp_qst_rd_tag_atslv.latchd_req_timedout);

  always_ff @(posedge slv_aclk, negedge slv_aresetn) begin : RD_STATE_PROC
    if(!slv_aresetn)
      rd_state <= #TP E_RD_IDLE;
    else begin
      case(rd_transition)
        E_RD_KOI,
        E_RD_LTI:
          rd_state <= #TP halt_rd.as_struct.w_rdr ? rd_state : E_RD_IDLE;
        E_RD_KOL,
        E_RD_ITL:
          rd_state <= #TP halt_rd.as_struct.w_rdr ? rd_state : E_RD_LONG;
      endcase
    end
  end : RD_STATE_PROC

  always_comb begin : RD_TRANSITION_PROC
    if(rd_hint.koi_true_idle || rd_hint.koi_err_no_beats || rd_hint.koi_err_one_beat || rd_hint.koi_nor_one_beat)
      rd_transition = E_RD_KOI;
    else if(rd_hint.itl_err_mul_beats || rd_hint.itl_nor_mul_beats)
      rd_transition = E_RD_ITL;
    else if(rd_hint.kol_keep_wt || rd_hint.kol_pop_wt)
      rd_transition = E_RD_KOL;
    else if(rd_hint.lti_last_wt_nor || rd_hint.lti_last_wt_err)
      rd_transition = E_RD_LTI;
    else
      rd_transition = (rd_state == E_RD_IDLE) ? E_RD_KOI : E_RD_KOL;
  end : RD_TRANSITION_PROC

  always_comb begin : DATAQ_STAT_PROC
    unique case({dataq_seg_pkt_avail, dataq_empty_p_1, rdr_lookup_wiretag_is_last})
      3'b000:
        dataq_stat = E_NO_BEATS_W_NXT;
      3'b001:
        dataq_stat = E_NO_BEATS_WO_NXT;
      3'b010,
      3'b011:
        dataq_stat = E_INVALID;
      3'b100:
        dataq_stat = (s_pending_len_atslv == '0) ? E_NO_BEATS_W_NXT : E_MUL_BEATS_W_NXT;
      3'b101:
        dataq_stat = E_MUL_BEATS_WO_NXT;
      3'b110:
        dataq_stat = E_ONE_BEAT_W_NXT;
      3'b111:
        dataq_stat = E_ONE_BEAT_WO_NXT;
    endcase
  end : DATAQ_STAT_PROC

  always_comb begin : RD_TRANSITION_HINTS_PROC
    rd_hint.koi_true_idle     = (rd_state == E_RD_IDLE) && (!active_tag_valid_atslv);
    rd_hint.koi_err_no_beats  = (rd_state == E_RD_IDLE) &&   active_tag_valid_atslv  && (dataq_stat == E_NO_BEATS_WO_NXT)                                                               &&  dataq_err_on_atag;
    rd_hint.koi_err_one_beat  = (rd_state == E_RD_IDLE) &&   active_tag_valid_atslv  && (dataq_stat == E_ONE_BEAT_WO_NXT)                                                               &&  dataq_err_on_atag;
    rd_hint.koi_nor_one_beat  = (rd_state == E_RD_IDLE) &&   active_tag_valid_atslv  && (dataq_stat == E_ONE_BEAT_WO_NXT)                                                               && !dataq_err_on_atag;

    rd_hint.itl_err_mul_beats = (rd_state == E_RD_IDLE) &&   active_tag_valid_atslv  && (dataq_stat inside {E_NO_BEATS_W_NXT, E_ONE_BEAT_W_NXT, E_MUL_BEATS_W_NXT, E_MUL_BEATS_WO_NXT}) &&  dataq_err_on_atag;
    rd_hint.itl_nor_mul_beats = (rd_state == E_RD_IDLE) &&   active_tag_valid_atslv  && (dataq_stat inside {E_NO_BEATS_W_NXT, E_ONE_BEAT_W_NXT, E_MUL_BEATS_W_NXT, E_MUL_BEATS_WO_NXT}) && !dataq_err_on_atag;

    rd_hint.kol_keep_wt       = (rd_state == E_RD_LONG) &&                              (dataq_stat inside {E_MUL_BEATS_W_NXT, E_MUL_BEATS_WO_NXT});
    rd_hint.kol_pop_wt        = (rd_state == E_RD_LONG) &&                              (dataq_stat inside {E_NO_BEATS_W_NXT, E_ONE_BEAT_W_NXT});

    rd_hint.lti_last_wt_nor   = (rd_state == E_RD_LONG) &&                              (dataq_stat == E_ONE_BEAT_WO_NXT);
    rd_hint.lti_last_wt_err   = (rd_state == E_RD_LONG) &&                              (dataq_stat == E_NO_BEATS_WO_NXT);
  end : RD_TRANSITION_HINTS_PROC

  always_comb begin : DATAQ_RD_PROC
    i_dataq_rd.en  = ( rd_hint.koi_err_one_beat  ||
                       rd_hint.koi_nor_one_beat  ||
                       rd_hint.itl_err_mul_beats ||
                       rd_hint.itl_nor_mul_beats ||
                       rd_hint.kol_keep_wt       ||
                       rd_hint.kol_pop_wt        ||
                       rd_hint.lti_last_wt_nor
                      ) && !(dataq_stat inside {
                           E_NO_BEATS_W_NXT,
                           E_NO_BEATS_WO_NXT
                      }) && !halt_rd.as_struct.w_rdr;

    i_dataq_rd.dv  = ( i_dataq_rd.en             ||
                       rd_hint.koi_err_no_beats  ||
                       rd_hint.itl_err_mul_beats || // E_NO_BEATS_W_NXT
                       rd_hint.kol_pop_wt        || // E_NO_BEATS_W_NXT
                       rd_hint.lti_last_wt_err
                     ) && !halt_rd.as_struct.w_rdr;

    i_dataq_rd.eot = ( rd_hint.koi_err_no_beats ||
                       rd_hint.koi_err_one_beat ||
                       rd_hint.koi_nor_one_beat ||
                       rd_hint.lti_last_wt_nor  ||
                       rd_hint.lti_last_wt_err
                     );

    i_dataq_rd.err = ( rd_hint.koi_err_no_beats  ||
                       rd_hint.koi_err_one_beat  ||
                       rd_hint.itl_err_mul_beats
                     );

    i_dataq_rd.apptag  = rdr_lookup_apptag;
    i_dataq_rd.seg_num = rdr_lookup_wiretag;
  end : DATAQ_RD_PROC

  assign halt_rd.as_bus = stall_out;
  assign s_dataq_rd    = i_dataq_rd;

  assign dataq_rd_en      = s_dataq_rd.en && !halt_rd.as_struct.w_rdr;
  assign dataq_rd_dv      = s_dataq_rd.dv && !halt_rd.as_struct.w_rdr;
  assign dataq_rd_eot     = s_dataq_rd.eot;
  assign dataq_rd_err     = s_dataq_rd.err;
  assign dataq_rd_apptag  = s_dataq_rd.apptag;
  assign dataq_rd_seg_num = s_dataq_rd.seg_num;

  assign rdr_pop_wiretag    = ( rd_hint.koi_err_no_beats ||
                                rd_hint.koi_err_one_beat ||
                                rd_hint.koi_nor_one_beat ||
                                rd_hint.kol_pop_wt       ||
                                rd_hint.lti_last_wt_nor  ||
                                rd_hint.lti_last_wt_err  ||
                                (dataq_stat inside {
                                  E_NO_BEATS_W_NXT,
                                  E_ONE_BEAT_W_NXT
                                } && !rd_hint.koi_true_idle
                                )
                              ) && !halt_rd.as_struct.w_ts;

  assign consumed_seg_atslv = {L_SEQ_N_EFAN{
                                (rd_hint.koi_err_no_beats  ||
                                 rd_hint.koi_err_one_beat  ||
                                 rd_hint.koi_nor_one_beat  ||
                                 rd_hint.itl_err_mul_beats ||
                                 rd_hint.itl_nor_mul_beats
                                )}} & ~halt_rd.as_struct.w_seq;

`ifndef SYNTHESIS
`endif

endmodule : DWC_pcie_axi_cpl_comp_ctl_rdr

