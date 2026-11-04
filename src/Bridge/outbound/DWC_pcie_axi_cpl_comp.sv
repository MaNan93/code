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

//------------------------------------------------------------------------------
// RCS information:
//   $DateTime: 2023/07/11 03:21:42 $
//   $Revision: #17 $
//   $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_axi_cpl_comp.sv#17 $
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Module Description:
//------------------------------------------------------------------------------
// The main funcions are:
//
// Outbound Completion Composer
//
//------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

 module DWC_pcie_axi_cpl_comp
import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
  // ---------------------------------------------------------------------------
  // Parameters modified by an instantiation parameter assignment
  // ---------------------------------------------------------------------------
  parameter SLV_BUS_ID_WIDTH                    = 5,
  parameter CX_TAG_SIZE                         = `CX_TAG_SIZE,
  parameter MAX_SLV_TAG_PW                      = 5,
  parameter MAX_WIRE_TAG                        = 32,
  parameter MAX_WIRE_TAG_PW                     = 5,
  parameter SLV_MAX_RD_SIZE_PW                  = 5,
  parameter NFUNC_WD                            = 3,
  parameter NW                                  = 1,
  parameter CORE_DATA_BUS_WD                    = 32,
  parameter DC_INBD_HEADER_CPL_WD               = 100,
  parameter PF_WD_MIN3                          = 3,
  parameter NPRSPF_TLP_DATA_WIDTH               = 32,
  parameter NPRSPF_TLP_DATA_WIDTH_NP            = 32,
  parameter NPRSPF_TLP_NUM_DWORDS               = 4,
  parameter CC_RADMX_COMPOSER_HDR_WD            = `CC_RADMX_COMPOSER_HDR_WD,
  parameter CC_AMBA_TLP_SEQ_WD                  = `CC_AMBA_TLP_SEQ_WD,
  parameter CC_OB_CCMP_DATA_RAM_ADDR_WD         = `CC_OB_CCMP_DATA_RAM_ADDR_WD,
  parameter CC_OB_CCMP_DATA_RAM_DATA_WD         = `CC_OB_CCMP_DATA_RAM_DATA_WD,
  parameter CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC   = `CC_OB_CCMP_DATA_RAM_DATA_WD_NOECC,
  parameter FLT_Q_ATTR_WIDTH                    = `FLT_Q_ATTR_WIDTH,
  parameter SYNC_DEPTH                          = 2,
  parameter CX_RAS_RAM_PROT_RANGE               = `CX_RAS_RAM_PROT_RANGE,
  parameter CX_RAS_PARITY_MODE                  = `CX_RAS_PARITY_MODE,
  parameter CX_RAS_PROT_RANGE                   = `CX_RAS_PROT_RANGE,
  parameter CX_NVC                              = `CX_NVC,
  parameter CX_NVC_LOG2                         = `CX_NVC_LOG2,
  parameter CC_ORDRB_NIDO                       = `CC_ORDRB_NIDO,
  parameter CC_ORDRB_NIDO_WD                    = `CC_ORDRB_NIDO_WD,
  parameter CC_NUM_DMA_RD_CHAN_WIDTH            = `CC_NUM_DMA_RD_CHAN_WIDTH,
  // ---------------------------------------------------------------------------
  // Parameters not modified by an instantiation parameter assignment
  // ---------------------------------------------------------------------------
  parameter TP                      = `TP
  )
  
                             (
  // ---------------------------------------------------------------------------
  // Clocks and resets
   input                                     core_clk    //The primary clock wire to the CXEP core
  ,input                                     core_rst_n  //When asserted resets the CXEP core except for PMC module
  ,input                                     slv_aclk    //Slave Application interface clock
  ,input                                     slv_aresetn //Slave Application clock related reset
  // ---------------------------------------------------------------------------
  // Configuration signals
  // ---------------------------------------------------------------------------
  // RAS signals
  ,input                                           cfg_ras_recc_ob_ccmp_data_correct
  ,output wire                                     axi_ras_recc_corr_cnt_ob_ccmp_data_pulse
  ,output wire                                     axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse
  ,output wire [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0]   axi_ras_recc_cnt_ob_ccmp_data_addr
  ,output wire                                     axi_ras_par_ob_cpl_comp_dt_pulse
  ,output ras_dp_err_log_t                         ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log
  ,output ras_dp_err_log_t                         ob_cpl_comp_dt_ras_dp_err_log
  ,input  ras_dp_err_inj_t                         axi_bridge_ras_dp_err_inj_core_clk
  ,input  ras_dp_err_inj_t                         ras_dp_err_inj_slv_aclk
  ,input  ras_dp_err_inj_t                         core_clk_ordrb_ras_dp_err_inj
  // ---------------------------------------------------------------------------
  // Inbound router interface
  ,input         [DC_INBD_HEADER_CPL_WD-1:0] ibrtr_inbd_header_cpl
  ,input              [CORE_DATA_BUS_WD-1:0] ibrtr_inbd_data_cpl
  ,input            [CC_AMBA_TLP_SEQ_WD-1:0] ibrtr_inbd_header_cpl_pseq
  ,input                                     ibrtr_inbd_header_cpl_pass_p
  ,input                        [CX_NVC-1:0] trgt1_p_xfer_pend_per_vc
  // ---------------------------------------------------------------------------
  // Completion Timeout interface
  ,input                                     radm_cpl_timeout      //Timeout CPL
  ,input                   [CX_TAG_SIZE-1:0] radm_cpl_timeout_tag  //Timeout CPL TAG
  ,input                               [2:0] radm_cpl_timeout_tc   //Timeout CPL TC
  ,input                               [1:0] radm_cpl_timeout_attr //Timeout CPL ATTR
  ,input                    [PF_WD_MIN3-1:0] radm_timeout_func_num //Timeout CPL Function ID
  // ---------------------------------------------------------------------------
  // Outbound Non Posted Decomposer request interface
  ,output                                    cpl_cmp_err_req_halt
  ,input                                     npdcmp_req_tag_consumed //Valid signal for the following signals
  ,input                               [2:0] npdcmp_req_cpl_stat
  ,input                [MAX_SLV_TAG_PW-1:0] npdcmp_req_app_tag      //Application generated tag
  ,input               [MAX_WIRE_TAG_PW-1:0] npdcmp_req_wire_tag     //Tag used on the wire
  ,input                                     npdcmp_req_last_tlp     //Last TLP of one application packet
  ,input                                     npdcmp_req_4rd          //Non posted TLP for read designed for cfg or IO write/read
  ,input            [SLV_MAX_RD_SIZE_PW-1:0] npdcmp_req_byte_len     //TLP request length
  ,input                [SLV_BUS_ID_WIDTH:0] npdcmp_req_axi_id
  ,input                      [NFUNC_WD-1:0] npdcmp_req_func_num
  ,input                               [2:0] npdcmp_req_tc
  // ---------------------------------------------------------------------------
  // Completion Composer interface
  ,output wire                               cmp_cpl_hv
  ,output wire                               cmp_cpl_dv
  ,output wire                               cmp_cpl_eot
  ,output wire   [NPRSPF_TLP_DATA_WIDTH-1:0] cmp_cpl_data
  ,output wire      [SLV_MAX_RD_SIZE_PW-1:0] cmp_cpl_byte_len
  ,output wire          [MAX_SLV_TAG_PW-1:0] cmp_cpl_tag
  ,output wire                               cmp_cpl_to
  ,output wire                               cmp_cpl_ido
  ,output wire                               cmp_cpl_ro
  ,output wire                               cmp_cpl_ns
  ,output wire                         [2:0] cmp_cpl_tc
  ,output wire                         [2:0] cmp_cpl_func_num
  ,output wire                         [2:0] cmp_cpl_status
  ,output wire                               cmp_cpl_ep
  ,output wire                         [7:0] cmp_cpl_cpl_segment
  ,output wire                         [8:0] cmp_cpl_dst_segment
  ,input                                     slv_rsp_cycle_halt //halt from slave gasket to compose FIFO/QUEUE output
  ,input                                     consumed_tag_from_nprf
  ,input              [SLV_BUS_ID_WIDTH  :0] nprf_id
  ,input                [MAX_SLV_TAG_PW-1:0] nprf_tag
  // ---------------------------------------------------------------------------
  // Segmented Buffer RAM interface
  ,input       [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0] ccmp_data_ram_doutb //RAM read data
  ,output wire [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0] ccmp_data_ram_addra //RAM port A address (write interface)
  ,output wire [CC_OB_CCMP_DATA_RAM_ADDR_WD-1:0] ccmp_data_ram_addrb //RAM port B address (read interface)
  ,output wire [CC_OB_CCMP_DATA_RAM_DATA_WD-1:0] ccmp_data_ram_dina  //RAM write data
  ,output wire                                   ccmp_data_ram_enb   //RAM port B enable (read enable)
  ,output wire                                   ccmp_data_ram_wea   //RAM Port A write enable
  ,output wire                                   cmp_lookup_err   //RADMX response composer TAG lookup error
  ,output wire                                   cmp_tag_released //The associated app_TAG can be reused now for a completion that is received
  ,output wire             [MAX_WIRE_TAG_PW-1:0] cmp_tag_num      //Released app_TAG number
  ,output wire                                   cmp_sb_init_done

  ,output wire              [MAX_SLV_TAG_PW-1:0] slv_lookup_apptag
  ,output wire                                   slv_pop_wiretag
  ,input                   [MAX_WIRE_TAG_PW-1:0] slv_lookup_wiretag
  ,input                                         slv_lookup_wiretag_is_last

  ,output                  [MAX_WIRE_TAG_PW-1:0] rdr_lookup_wiretag
  ,output wire                                   rdr_pop_wiretag
  // ---------------------------------------------------------------------------
  // Completed posted request sequence number interface
  ,input                  [CC_AMBA_TLP_SEQ_WD-1:0] ib_last_presp_rpseq_per_vc [       CX_NVC-1:0]
  ,input                        [MAX_WIRE_TAG:0] s_wtag_active_lut
  );


  // ---------------------------------------------------------------------------
  // Local parameters declaration
  // ---------------------------------------------------------------------------
  // Number of parity data blocks for a single dword
  localparam NUM_DATA_PAR_BLOCKS       = NPRSPF_TLP_DATA_WIDTH_NP/CX_RAS_PROT_RANGE;
  localparam COMPOSER_HDR_CPLSGMT_HIGH = CC_RADMX_COMPOSER_HDR_WD  - 1;
  localparam COMPOSER_HDR_CPLSGMT_LOW  = COMPOSER_HDR_CPLSGMT_HIGH - 7;
  localparam COMPOSER_HDR_DSTSGMT_HIGH = COMPOSER_HDR_CPLSGMT_LOW  - 1;
  localparam COMPOSER_HDR_DSTSGMT_LOW  = COMPOSER_HDR_DSTSGMT_HIGH - 8;
  localparam COMPOSER_HDR_TLPPRFX_HIGH = 0;
  localparam COMPOSER_HDR_TLPPRFX_LOW  = COMPOSER_HDR_DSTSGMT_LOW;
  localparam COMPOSER_HDR_TLPLN_HIGH   = 0;
  localparam COMPOSER_HDR_TLPLN_LOW    = COMPOSER_HDR_TLPPRFX_LOW;
  localparam COMPOSER_HDR_REQID_HIGH   = 0;
  localparam COMPOSER_HDR_REQID_LOW    = COMPOSER_HDR_TLPLN_LOW;
  localparam COMPOSER_HDR_LOCK_HIGH    = COMPOSER_HDR_REQID_LOW - 1;
  localparam COMPOSER_HDR_LOCK_LOW     = COMPOSER_HDR_LOCK_HIGH;
  localparam COMPOSER_HDR_TABORT_HIGH  = COMPOSER_HDR_LOCK_LOW - 1;
  localparam COMPOSER_HDR_TABORT_LOW   = COMPOSER_HDR_TABORT_HIGH;
  localparam COMPOSER_HDR_TD_HIGH      = COMPOSER_HDR_TABORT_LOW - 1;
  localparam COMPOSER_HDR_TD_LOW       = COMPOSER_HDR_TD_HIGH;
  localparam COMPOSER_HDR_TC_HIGH      = COMPOSER_HDR_TD_LOW - 1;
  localparam COMPOSER_HDR_TC_LOW       = COMPOSER_HDR_TC_HIGH - 2;
  localparam COMPOSER_HDR_ATTR_HIGH    = COMPOSER_HDR_TC_LOW - 1;
  localparam COMPOSER_HDR_ATTR_LOW     = COMPOSER_HDR_ATTR_HIGH - FLT_Q_ATTR_WIDTH + 1;
  localparam COMPOSER_HDR_ATS_HIGH     = COMPOSER_HDR_ATTR_LOW - 1;
  localparam COMPOSER_HDR_ATS_LOW      = COMPOSER_HDR_ATS_HIGH - 1;
  localparam COMPOSER_HDR_BCM_HIGH     = (`ATS_RX_ENABLE_VALUE == 1) ? COMPOSER_HDR_ATS_LOW - 1 : COMPOSER_HDR_ATTR_LOW - 1;
  localparam COMPOSER_HDR_BCM_LOW      = COMPOSER_HDR_BCM_HIGH;
  localparam COMPOSER_HDR_ECRC_HIGH    = COMPOSER_HDR_BCM_LOW - 1;
  localparam COMPOSER_HDR_ECRC_LOW     = COMPOSER_HDR_ECRC_HIGH;
  localparam COMPOSER_HDR_EP_HIGH      = COMPOSER_HDR_ECRC_LOW - 1;
  localparam COMPOSER_HDR_EP_LOW       = COMPOSER_HDR_EP_HIGH;
  localparam COMPOSER_HDR_CSTATUS_HIGH = COMPOSER_HDR_EP_LOW - 1;
  localparam COMPOSER_HDR_CSTATUS_LOW  = COMPOSER_HDR_CSTATUS_HIGH - 2;
  localparam PARITY_BIT                = CX_RAS_PARITY_MODE ? 1'b1 : 1'b0;
  // Strip extraneous 0 MSBs from array indexing
  localparam L_WTWD                    = (MAX_WIRE_TAG == 0) ? 1 : $clog2(MAX_WIRE_TAG+1);

  // ---------------------------------------------------------------------------
  // Wires declaration
  // ---------------------------------------------------------------------------
  wire                             s_rcvd_cpl_hv         ;
  wire                             s_rcvd_cpl_dv         ;
  wire                             s_rcvd_cpl_eot        ;
  wire      [CORE_DATA_BUS_WD-1:0] s_rcvd_cpl_data       ;
  wire                    [NW-1:0] s_rcvd_cpl_dwen       ;
  wire                             s_rcvd_cpl_dllp_abort ;
  wire                             s_rcvd_cpl_tlp_abort  ;
  wire                             s_rcvd_cpl_last       ;
  wire                       [2:0] s_rcvd_cpl_status     ;
  wire                       [2:0] s_rcvd_cpl_tc         ;
  wire      [FLT_Q_ATTR_WIDTH-1:0] s_rcvd_cpl_attr       ;
  wire       [MAX_WIRE_TAG_PW-1:0] s_rcvd_cpl_tag        ;
  wire                      [15:0] s_rcvd_cpl_cplid      ;
  wire                             s_rcvd_cpl_td         ;
  wire                             s_rcvd_cpl_ep         ;
  wire                             s_rcvd_cpl_bcm        ;
  wire                             s_rcvd_cpl_lock       ;
  wire                             s_rcvd_cpl_wo_data    ;
  wire                             s_rcvd_cpl_err        ;
  wire    [CC_AMBA_TLP_SEQ_WD-1:0] s_rcvd_cpl_pseq       ;
  wire                             s_rcvd_cpl_hold       ;
  wire                       [2:0] s_header_cpl_vc_num   ;
  wire                       [7:0] s_rcvd_cpl_cpl_segment;
  wire                       [8:0] s_rcvd_cpl_dst_segment;
  wire [CC_RADMX_COMPOSER_HDR_WD-1:0] s_cpl_hdr             ;
  wire [CC_RADMX_COMPOSER_HDR_WD-1:0] s_cpl_timeout_hdr     ;
  wire                             s_cmpsr_dv            ; // Start of a composed completion
  wire                             s_cmpsr_hv            ; // Received composed completion data is valid
  wire                             s_cmpsr_eot           ; // End of a composed completion
  wire [NPRSPF_TLP_NUM_DWORDS-1:0] s_cmpsr_dwen          ; // Received data dword enable
  wire    [SLV_MAX_RD_SIZE_PW-1:0] s_cmpsr_byte_len      ; // Received response byte length
  wire                             s_cmpsr_4rd           ;
  wire [NPRSPF_TLP_DATA_WIDTH-1:0] s_cmpsr_data          ; // Received data
  wire                             s_cmpsr_err           ; // Received err, needs to be aborted, this causes a pointer rewind
  wire        [MAX_SLV_TAG_PW-1:0] s_cmpsr_tag           ;
  wire                             s_cpl_status_good     ;
  wire [CC_RADMX_COMPOSER_HDR_WD-1:0] s_cmpsr_hdr           ;
  wire                             s_out_rsp_cycle_halt  ;
  wire                             s_cpl_dv              ;
  wire [NPRSPF_TLP_DATA_WIDTH-1:0] s_cpl_data            ;
  wire                             s_cpl_eot             ;
  wire [NPRSPF_TLP_NUM_DWORDS-1:0] s_cpl_dwen            ;
  wire                             s_cpl_hv              ;
  wire [CC_RADMX_COMPOSER_HDR_WD-1:0] s_cmpsr_pkt_hdr       ;
  wire                             s_cmpsr_pkt_hv        ; // Indicates a start of response
  wire                             s_cmpsr_pkt_dv        ; // Receiving with data valid
  wire                             s_cmpsr_pkt_eot       ; // Indicate an end of response
  wire [NPRSPF_TLP_NUM_DWORDS-1:0] s_cmpsr_pkt_dwen      ; // Receiving with data dword enable
  wire [NPRSPF_TLP_DATA_WIDTH-1:0] s_cmpsr_pkt_data      ; // Receiving data
  wire                             s_cmpsr_pkt_4rd       ; // Receiving response for non-posted read
  wire        [MAX_SLV_TAG_PW-1:0] s_cmpsr_pkt_tag       ; // Received TAG
  wire    [SLV_MAX_RD_SIZE_PW-1:0] s_cmpsr_pkt_byte_len  ; // Received TLP byte len
  wire                             s_cmpsr_pkt_lock      ; // Received lock
  reg             [MAX_WIRE_TAG:0] r_ep_vec              ; // MAX_WIRE_TAG is 2^n - 1
  wire                             s_ep                  ;

  wire [CC_RADMX_COMPOSER_HDR_WD-1:0] npdcmp_hdr            ;

  // ---------------------------------------------------------------------------
  // Design
  // ---------------------------------------------------------------------------
  // Extract completion fields from inbound router
  assign s_rcvd_cpl_hv          = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_HV_HIGH          : `INBD_HDR_CPL_RANGE_HV_LOW];
  assign s_rcvd_cpl_dv          = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_DV_HIGH          : `INBD_HDR_CPL_RANGE_DV_LOW];
  assign s_rcvd_cpl_eot         = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_EOT_HIGH         : `INBD_HDR_CPL_RANGE_EOT_LOW];
  assign s_rcvd_cpl_data        = ibrtr_inbd_data_cpl;
  logic [NW-1:0] s_rcvd_cpl_dwen_aux;
  assign s_rcvd_cpl_dwen_aux    = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_DWEN_HIGH        : `INBD_HDR_CPL_RANGE_DWEN_LOW];
  assign s_rcvd_cpl_dwen        = s_rcvd_cpl_eot ? s_rcvd_cpl_dwen_aux : '1;
  assign s_rcvd_cpl_dllp_abort  = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_DLLP_ABORT_HIGH  : `INBD_HDR_CPL_RANGE_DLLP_ABORT_LOW];
  assign s_rcvd_cpl_tlp_abort   = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_TLP_ABORT_HIGH   : `INBD_HDR_CPL_RANGE_TLP_ABORT_LOW];
  assign s_rcvd_cpl_last        = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_LAST_HIGH        : `INBD_HDR_CPL_RANGE_LAST_LOW];
  assign s_rcvd_cpl_status      = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_CPL_STATUS_HIGH  : `INBD_HDR_CPL_RANGE_CPL_STATUS_LOW];
  assign s_rcvd_cpl_tc          = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_TC_HIGH          : `INBD_HDR_CPL_RANGE_TC_LOW];
  assign s_rcvd_cpl_attr        = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_ATTR_HIGH        : `INBD_HDR_CPL_RANGE_ATTR_LOW];


  assign s_rcvd_cpl_tag         = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_TAG_HIGH         : `INBD_HDR_CPL_RANGE_TAG_LOW];
  assign s_rcvd_cpl_cplid       = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_CPLID_HIGH       : `INBD_HDR_CPL_RANGE_CPLID_LOW];
  assign s_rcvd_cpl_td          = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_TD_HIGH          : `INBD_HDR_CPL_RANGE_TD_LOW];
  assign s_rcvd_cpl_ep          = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_POISONED_HIGH    : `INBD_HDR_CPL_RANGE_POISONED_LOW];
  assign s_rcvd_cpl_bcm         = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_BCM_HIGH         : `INBD_HDR_CPL_RANGE_BCM_LOW];
  assign s_rcvd_cpl_lock        = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_CPL_LOCK_HIGH    : `INBD_HDR_CPL_RANGE_CPL_LOCK_LOW];
  assign s_rcvd_cpl_wo_data     = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_CPL_WO_DATA_HIGH : `INBD_HDR_CPL_RANGE_CPL_WO_DATA_LOW];
  assign s_rcvd_cpl_dst_segment = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_DST_SEGMENT_HIGH : `INBD_HDR_CPL_RANGE_DST_SEGMENT_LOW];
  assign s_rcvd_cpl_cpl_segment = ibrtr_inbd_header_cpl[`INBD_HDR_CPL_RANGE_CPL_SEGMENT_HIGH : `INBD_HDR_CPL_RANGE_CPL_SEGMENT_LOW];
  assign s_rcvd_cpl_pseq        = ibrtr_inbd_header_cpl_pseq;
  assign s_header_cpl_vc_num    = 3'b000;
  assign s_rcvd_cpl_hold        =!ibrtr_inbd_header_cpl_pass_p;

  // ---------------------------------------------------------------------------
  // Genertate 1 beat error response valid UR/CA completions
  // Flush split completions already pushed to the data segment
  // Treat poisoned data as good data, EP flag set on sideband bus
  // ---------------------------------------------------------------------------
  assign s_cpl_status_good = (s_rcvd_cpl_status == `SU_CPL_STATUS);

  // Accumulate EP error over multiple split completions
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_ep
    integer i;

    if (!core_rst_n) begin
      r_ep_vec <= # TP {(MAX_WIRE_TAG+1){1'b0}}; // MAX_WIRE_TAG is 2^n - 1
    end else begin
      for (i=0; i<(MAX_WIRE_TAG+1); i=i+1) begin // MAX_WIRE_TAG is 2^n - 1
        if (i == s_rcvd_cpl_tag) begin
          if (s_rcvd_cpl_eot && !s_rcvd_cpl_tlp_abort && !s_rcvd_cpl_dllp_abort) begin
            if (s_rcvd_cpl_last) begin
              r_ep_vec[i] <= # TP 1'b0;
            end else begin
              r_ep_vec[i] <= # TP r_ep_vec[i] || s_rcvd_cpl_ep;
            end
          end
        end
      end
    end
  end
  assign s_ep = s_rcvd_cpl_ep || r_ep_vec[s_rcvd_cpl_tag[L_WTWD-1:0]];

  assign s_cpl_hdr         = {
                              s_rcvd_cpl_cpl_segment,
                              s_rcvd_cpl_dst_segment,
                              s_rcvd_cpl_lock,
                              s_rcvd_cpl_tlp_abort,
                              s_rcvd_cpl_td,
                              s_rcvd_cpl_tc,
                              s_rcvd_cpl_attr,
                              2'b00,
                              s_rcvd_cpl_bcm,
                              1'b0, // CPL ECRC ERR - Ignore ECRC error, pass completion to AMBA slave
                              s_ep,
                              s_rcvd_cpl_status
                             };

  assign s_cpl_timeout_hdr = {
                              8'h00,
                              9'h000,
                              1'b0,
                              1'b1,
                              1'b0,
                              radm_cpl_timeout_tc,
                              {1'b0,radm_cpl_timeout_attr},


                              2'b00,
                              1'b0,
                              1'b0,
                              1'b0,
                              3'h0
                             };// Time out as a completion timeout which replace the tlp_abort bit location

wire [2:0] s_npdcmp_req_func_num;

generate
  if (NFUNC_WD<3) begin : gen_3bit_wide_npdcmp_req_func_num
    assign s_npdcmp_req_func_num = {{(3-NFUNC_WD){1'b0}},npdcmp_req_func_num};
  end else begin
    assign s_npdcmp_req_func_num = npdcmp_req_func_num[2:0];
  end
endgenerate

assign npdcmp_hdr          = {
                                 8'h00, // TBD: replace this with segment info from core
                                 9'h000,
                                 1'b0,
                                 1'b0,
                                 1'b0,
                                 npdcmp_req_tc,
                                 3'b000,
                                 2'b00,
                                 1'b0,
                                 1'b0,
                                 1'b0,
                                 npdcmp_req_cpl_stat
                              };

  assign s_cpl_hv   = s_rcvd_cpl_hv;
  assign s_cpl_dv   = s_rcvd_cpl_dv;
  assign s_cpl_eot  = s_rcvd_cpl_eot;
  assign s_cpl_dwen = s_rcvd_cpl_dwen;
  assign s_cpl_data = s_rcvd_cpl_data;

  typedef struct packed {
    logic [NPRSPF_TLP_DATA_WIDTH -1:0] data;
    logic [NPRSPF_TLP_NUM_DWORDS -1:0] dwen;
    logic                              dv;
    logic                              hv;
    logic                              eot;
    logic                              err;
    logic [CC_RADMX_COMPOSER_HDR_WD -1:0] hdr;
    logic                              last;
    logic       [MAX_WIRE_TAG_PW -1:0] tag;
    logic        [MAX_SLV_TAG_PW -1:0] apptag;
    logic                              status_good;
    logic     [CC_AMBA_TLP_SEQ_WD-1:0] pseq;
    logic                              hold_preq;
  } cplCmpInPkt_t;

  typedef struct packed {
    logic                                 v;
    logic       [SLV_BUS_ID_WIDTH+1 -1:0] axi_id;
    logic          [MAX_SLV_TAG_PW  -1:0] app_tag;
    logic          [MAX_WIRE_TAG_PW -1:0] wire_tag;
    logic                                 last_tlp;
    logic                                 for_rd;
    logic       [SLV_MAX_RD_SIZE_PW -1:0] byte_len;
    logic [CC_RADMX_COMPOSER_HDR_WD -1:0] hdr;
  } npdcmpReq_t;

  typedef struct packed {
    logic                                 v;
    logic          [MAX_WIRE_TAG_PW -1:0] tag;
    logic [CC_RADMX_COMPOSER_HDR_WD -1:0] hdr;
    logic           [MAX_SLV_TAG_PW -1:0] apptag;
  } timeoutIf_t;

  cplCmpInPkt_t i_cpl, w_cpl;
  npdcmpReq_t   i_npdcmp_req, w_npdcmp_req;
  timeoutIf_t   i_timeout, w_timeout;

  // Filtering logic for incoming Unexpected CPL
  logic r_filtering_status, s_filtering_en_n;

  // Latch the filtering status between hv and eot
  always_ff @(posedge core_clk, negedge core_rst_n) begin : r_filtering_status_PROC
    if(!core_rst_n) begin
      r_filtering_status <= #`TP 1'b0;
    end else begin
      r_filtering_status <= #`TP s_cpl_hv ? !s_wtag_active_lut[s_rcvd_cpl_tag[L_WTWD-1:0]] || (s_rcvd_cpl_tag > MAX_WIRE_TAG) : r_filtering_status;
    end
  end : r_filtering_status_PROC

  // Negated filtering flag, 0 - filter, 1 - do not filter
  assign s_filtering_en_n = s_cpl_hv ? s_wtag_active_lut[s_rcvd_cpl_tag[L_WTWD-1:0]] && (s_rcvd_cpl_tag <= MAX_WIRE_TAG) : !r_filtering_status;

  // No latching on timeout filtering, it's single clock cycle
  logic  s_tout;
  assign s_tout = radm_cpl_timeout && s_wtag_active_lut[radm_cpl_timeout_tag[L_WTWD-1:0]];

  // Reduce fan-in cones for u_ctl.ilookup* by resolving apptag early
  logic [MAX_WIRE_TAG+1 -1:0] [MAX_SLV_TAG_PW -1:0] r_wiretag2apptag_lut,
                                                    s_wiretag2apptag_lut;

  always_ff @(posedge core_clk, negedge core_rst_n)
    if(!core_rst_n) r_wiretag2apptag_lut <= #`TP '0;
    else            r_wiretag2apptag_lut <= #`TP s_wiretag2apptag_lut;

  always_comb foreach(s_wiretag2apptag_lut[i]) s_wiretag2apptag_lut[i] = (npdcmp_req_tag_consumed & (i == npdcmp_req_wire_tag)) ? npdcmp_req_app_tag : r_wiretag2apptag_lut[i];

  assign i_cpl = '{
    data        : s_cpl_data
   ,dwen        :              s_filtering_en_n ? s_cpl_dwen : '0
   ,dv          : s_cpl_dv  && s_filtering_en_n
   ,hv          : s_cpl_hv  && s_filtering_en_n
   ,eot         : s_cpl_eot && s_filtering_en_n
   ,err         : s_rcvd_cpl_err
   ,hdr         : s_cpl_hdr
   ,last        : s_rcvd_cpl_last
   ,tag         : s_rcvd_cpl_tag
   ,apptag      : '0 // Calculated in next pipeline
   ,status_good : s_cpl_status_good
   ,pseq        : s_rcvd_cpl_pseq
   ,hold_preq   : s_rcvd_cpl_hold
  };

  assign i_npdcmp_req = '{
    v        : npdcmp_req_tag_consumed
   ,axi_id   : npdcmp_req_axi_id
   ,app_tag  : npdcmp_req_app_tag
   ,wire_tag : npdcmp_req_wire_tag
   ,last_tlp : npdcmp_req_last_tlp
   ,for_rd   : npdcmp_req_4rd
   ,byte_len : npdcmp_req_byte_len
   ,hdr      : npdcmp_hdr
  };

  assign i_timeout = '{
    v   : s_tout
   ,tag : radm_cpl_timeout_tag[MAX_WIRE_TAG_PW-1:0]
   ,hdr : s_cpl_timeout_hdr
   ,apptag: '0 // Calculated in the next pipeline
  };

  // Pdly1 before cpl_comp_ctl
  cplCmpInPkt_t r_cpl
                ,rr_cpl
                ,sr_cpl;

  npdcmpReq_t r_npdcmp_req;

  timeoutIf_t r_timeout
              ,rr_timeout
              ,sr_timeout;

  always_comb begin : sr_cpl_cproc
    sr_cpl = r_cpl;
    sr_cpl.apptag = r_wiretag2apptag_lut[r_cpl.tag[L_WTWD-1:0]];
  end

  always_comb begin : sr_timeout_cproc
    sr_timeout = r_timeout;
    sr_timeout.apptag = r_wiretag2apptag_lut[r_timeout.tag[L_WTWD-1:0]];
  end

  always_ff @(posedge core_clk, negedge core_rst_n) begin : r_cpl_PROC
    if(!core_rst_n) begin
      r_cpl         <= #`TP '0;
      rr_cpl        <= #`TP '0;
      r_npdcmp_req  <= #`TP '0;
      r_timeout     <= #`TP '0;
      rr_timeout    <= #`TP '0;
    end else begin
      r_cpl         <= #`TP i_cpl;
      rr_cpl        <= #`TP sr_cpl;
      r_npdcmp_req  <= #`TP i_npdcmp_req;
      r_timeout     <= #`TP i_timeout;
      rr_timeout    <= #`TP sr_timeout;
    end
  end : r_cpl_PROC

  assign w_cpl        = rr_cpl;
  assign w_npdcmp_req = r_npdcmp_req;
  assign w_timeout    = rr_timeout;

  // ---------------------------------------------------------------------------
  // Composer
  // ---------------------------------------------------------------------------
  assign s_rcvd_cpl_err = s_rcvd_cpl_dllp_abort | s_rcvd_cpl_tlp_abort;
  DWC_pcie_axi_cpl_comp_ctl
  
  #(.CC_RADMX_COMPOSER_HDR_WD(CC_RADMX_COMPOSER_HDR_WD)
   ,.MAX_IN_TAG              (MAX_WIRE_TAG            )
   ,.MAX_IN_TAG_PW           (MAX_WIRE_TAG_PW         )
   ,.CORE_DATA_BUS_WD        (NPRSPF_TLP_DATA_WIDTH   )
   ,.CORE_DATA_BUS_WD_NP     (NPRSPF_TLP_DATA_WIDTH_NP)
   ,.NW                      (NPRSPF_TLP_NUM_DWORDS   )
  )
  u_ctl
  (.clk                           (core_clk                                 )
  ,.slv_aclk                      (slv_aclk                                 )
  ,.rst_n                         (core_rst_n                               )
  ,.slv_aresetn                   (slv_aresetn                              )
  ,.rcvd_pkt_data                 (w_cpl.data                               ) /* core_clk      */
  ,.rcvd_pkt_dwen                 (w_cpl.dwen                               ) /* ^             */
  ,.rcvd_pkt_dv                   (w_cpl.dv                                 ) /* ^             */
  ,.rcvd_pkt_hv                   (w_cpl.hv                                 ) /* ^             */
  ,.rcvd_pkt_eot                  (w_cpl.eot                                ) /* ^             */
  ,.rcvd_pkt_err                  (w_cpl.err                                ) /* ^             */
  ,.rcvd_pkt_hdr                  (w_cpl.hdr                                ) /* ^             */
  ,.rcvd_pkt_last                 (w_cpl.last                               ) /* ^             */
  ,.rcvd_pkt_tag                  (w_cpl.tag                                ) /* ^             */
  ,.rcvd_pkt_apptag               (w_cpl.apptag                             ) /* ^             */
  ,.rcvd_pkt_status_good          (w_cpl.status_good                        ) /* ^             */
  ,.rcvd_pkt_pseq                 (w_cpl.pseq                               ) /* ^             */
  ,.rcvd_pkt_hold_preq            (w_cpl.hold_preq                          ) /* ^             */
  ,.err_tag_consumed_halt         (cpl_cmp_err_req_halt                     ) /* ^             */
  ,.tag_consumed                  (w_npdcmp_req.v                           ) /* ^             */
  ,.consumed_axi_id               (w_npdcmp_req.axi_id                      ) /* ^             */
  ,.consumed_out_tag              (w_npdcmp_req.app_tag                     ) /* ^             */
  ,.consumed_in_tag               (w_npdcmp_req.wire_tag                    ) /* ^             */
  ,.consumed_last_tag             (w_npdcmp_req.last_tlp                    ) /* ^             */
  ,.consumed_4rd                  (w_npdcmp_req.for_rd                      ) /* ^             */
  ,.consumed_tlp_byte_len         (w_npdcmp_req.byte_len                    ) /* ^             */
  ,.consumed_tlp_low_addr         (7'h0                                     ) /* ^             */
  ,.consumed_tlp_hdr              (w_npdcmp_req.hdr                         ) /* ^             */
  ,.consumed_rreq_dma             (3'h0                                     ) /* ^             */
  ,.consumed_rreq_dma_chan        (3'h0                                     ) /* ^             */
  ,.in_cycle_halt                 (1'b0 /* This only backpressure wr side */) /* ^             */
  ,.cpl_timeout                   (w_timeout.v                              ) /* ^             */
  ,.cpl_timeout_hdr               (w_timeout.hdr                            ) /* ^             */
  ,.cpl_timeout_tag               (w_timeout.tag                            ) /* ^             */
  ,.cpl_timeout_apptag            (w_timeout.apptag                         ) /* ^             */
  ,.cfg_ras_recc_ob_ccmp_data_correct        (cfg_ras_recc_ob_ccmp_data_correct        ) /*qstt*/
  ,.axi_ras_recc_corr_cnt_ob_ccmp_data_pulse (axi_ras_recc_corr_cnt_ob_ccmp_data_pulse ) /*slv */
  ,.axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse(axi_ras_recc_ucorr_cnt_ob_ccmp_data_pulse) /*slv */
  ,.axi_ras_recc_cnt_ob_ccmp_data_addr       (axi_ras_recc_cnt_ob_ccmp_data_addr       ) /*slv */
  ,.axi_ras_par_ob_cpl_comp_dt_pulse         (axi_ras_par_ob_cpl_comp_dt_pulse         ) /*core*/
  ,.ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log   (ob_recc_cnt_ob_ccmp_dt_ras_dp_pipe_log   )
  ,.ob_cpl_comp_dt_ras_dp_err_log            (ob_cpl_comp_dt_ras_dp_err_log            ) /*slv*/
  ,.axi_bridge_ras_dp_err_inj_core_clk       (axi_bridge_ras_dp_err_inj_core_clk)
  ,.ras_dp_err_inj_slv_aclk                  (ras_dp_err_inj_slv_aclk)
  ,.core_clk_ordrb_ras_dp_err_inj            (core_clk_ordrb_ras_dp_err_inj)
  ,.slv_rsp_cycle_halt            (slv_rsp_cycle_halt                       ) /* slv_aclk      */
  ,.ccmp_data_ram_addra           (ccmp_data_ram_addra                      ) /* core_clk      */
  ,.ccmp_data_ram_addrb           (ccmp_data_ram_addrb                      ) /* slv_aclk      */
  ,.ccmp_data_ram_dina            (ccmp_data_ram_dina                       ) /* core_clk      */
  ,.ccmp_data_ram_doutb           (ccmp_data_ram_doutb                      ) /* slv_aclk      */
  ,.ccmp_data_ram_enb             (ccmp_data_ram_enb                        ) /* ^             */
  ,.ccmp_data_ram_wea             (ccmp_data_ram_wea                        ) /* core_clk      */
  ,.cmposed_pkt_data              (s_cmpsr_data                             ) /* slv_aclk      */
  ,.cmposed_pkt_hdr               (s_cmpsr_hdr                              ) /* ^             */
  ,.cmposed_pkt_dwen              (s_cmpsr_dwen                             ) /* ^             */
  ,.cmposed_pkt_byte_len          (s_cmpsr_byte_len                         ) /* ^             */
  ,.cmposed_pkt_low_addr          (/*UNCONNECTED*/                          ) /* ^             */
  ,.cmposed_pkt_dv                (s_cmpsr_dv                               ) /* ^             */
  ,.cmposed_pkt_hv                (s_cmpsr_hv                               ) /* ^             */
  ,.cmposed_pkt_eot               (s_cmpsr_eot                              ) /* ^             */
  ,.cmposed_pkt_tag               (s_cmpsr_tag                              ) /* ^             */
  ,.cmposed_pkt_4rd               (s_cmpsr_4rd                              ) /* ^             */
  ,.cmposed_pkt_rreq_dma          (/*UNCONNECTED*/                          ) /* ^             */
  ,.cmposed_pkt_rreq_dma_chan     (/*UNCONNECTED*/                          ) /* ^             */
  ,.cmposed_pkt_err               (s_cmpsr_err                              ) /* ^             */
  ,.tag_released                  (cmp_tag_released                         ) /* ^             */
  ,.consumed_tag_from_nprf        (consumed_tag_from_nprf                   ) /* ^             */
  ,.nprf_id                       (nprf_id                                  ) /* ^             */
  ,.nprf_tag                      (nprf_tag                                 ) /* ^             */
  ,.released_tag                  (cmp_tag_num                              ) /* core_clk      */
  ,.lookup_err                    (cmp_lookup_err                           ) /* ^             */
  ,.cmp_sb_init_done              (cmp_sb_init_done                         ) /* qstatic       */

  ,.slv_lookup_apptag             (slv_lookup_apptag                        ) /* slv_aclk      */
  ,.slv_pop_wiretag               (slv_pop_wiretag                          ) /* ^             */
  ,.slv_lookup_wiretag            (slv_lookup_wiretag                       ) /* ^             */
  ,.slv_lookup_wiretag_is_last    (slv_lookup_wiretag_is_last               ) /* ^             */
  ,.rdr_lookup_wiretag            ( rdr_lookup_wiretag                      ) /* ^             */
  ,.rdr_pop_wiretag               ( rdr_pop_wiretag                         ) /* ^             */
  ,.ib_last_presp_rpseq_per_vc    ( ib_last_presp_rpseq_per_vc              ) /* core_clk      */
  ,.trgt1_p_xfer_pend_per_vc      ( trgt1_p_xfer_pend_per_vc                ) /* core_clk      */
  );

  /******
   * cpl_comp_ctl has been modified to output packet data at slave clock
   * Therefore the CDC FIFO has been removed
   ******/
  assign s_cmpsr_pkt_dv       = s_cmpsr_dv;
  assign s_cmpsr_pkt_hv       = s_cmpsr_hv;
  assign s_cmpsr_pkt_eot      = s_cmpsr_eot;
  assign s_cmpsr_pkt_tag      = s_cmpsr_tag;
  assign s_cmpsr_pkt_4rd      = s_cmpsr_4rd;
  assign s_cmpsr_pkt_data     = s_cmpsr_data;
  assign s_cmpsr_pkt_lock     = s_cmpsr_hdr[COMPOSER_HDR_LOCK_HIGH:COMPOSER_HDR_LOCK_LOW];
  assign s_cmpsr_pkt_dwen     = s_cmpsr_dwen;
  assign s_cmpsr_pkt_hdr      = s_cmpsr_hdr;
  assign s_cmpsr_pkt_byte_len = s_cmpsr_byte_len;
  assign s_out_rsp_cycle_halt = slv_rsp_cycle_halt;

  // ---------------------------------------------------------------------------
  // Output based on internal composition
  // ---------------------------------------------------------------------------
  assign cmp_cpl_hv       = s_cmpsr_pkt_hv;
  assign cmp_cpl_dv       = s_cmpsr_pkt_dv;
  assign cmp_cpl_eot      = s_cmpsr_pkt_eot;
  assign cmp_cpl_data     = s_cmpsr_pkt_data;
  assign cmp_cpl_byte_len = s_cmpsr_pkt_byte_len;
  assign cmp_cpl_tag      = s_cmpsr_pkt_tag;
  assign cmp_cpl_to       = s_cmpsr_pkt_hdr[COMPOSER_HDR_TABORT_HIGH:COMPOSER_HDR_TABORT_LOW];
  assign cmp_cpl_ido      = s_cmpsr_pkt_hdr[COMPOSER_HDR_ATTR_HIGH];
  assign cmp_cpl_ro       = s_cmpsr_pkt_hdr[COMPOSER_HDR_ATTR_LOW+1];
  assign cmp_cpl_ns       = s_cmpsr_pkt_hdr[COMPOSER_HDR_ATTR_LOW];
  assign cmp_cpl_tc       = s_cmpsr_pkt_hdr[COMPOSER_HDR_TC_HIGH:COMPOSER_HDR_TC_LOW];
  assign cmp_cpl_func_num = 3'h0;
  assign cmp_cpl_status   = s_cmpsr_pkt_hdr[COMPOSER_HDR_CSTATUS_HIGH:COMPOSER_HDR_CSTATUS_LOW];
  assign cmp_cpl_ep       = s_cmpsr_pkt_hdr[COMPOSER_HDR_EP_HIGH:COMPOSER_HDR_EP_LOW];
  assign cmp_cpl_cpl_segment =  s_cmpsr_pkt_hdr[COMPOSER_HDR_CPLSGMT_HIGH:COMPOSER_HDR_CPLSGMT_LOW];
  assign cmp_cpl_dst_segment =  s_cmpsr_pkt_hdr[COMPOSER_HDR_DSTSGMT_HIGH:COMPOSER_HDR_DSTSGMT_LOW];


  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  // Data without parity
  function automatic logic [NPRSPF_TLP_DATA_WIDTH_NP-1:0] fn_data_wo_par;
    input [NPRSPF_TLP_DATA_WIDTH-1:0] s_data_w_par;
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
  function automatic logic [NPRSPF_TLP_DATA_WIDTH-1:0] fn_data_w_par;
    input [NPRSPF_TLP_DATA_WIDTH_NP-1:0] s_data_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_data_for_par;

    begin
    fn_data_w_par  = {NPRSPF_TLP_DATA_WIDTH{1'b0}};
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

  // Mask data acording to valid d-word enable
  function automatic logic [NPRSPF_TLP_DATA_WIDTH-1:0] fn_mask_data;
     input [NPRSPF_TLP_DATA_WIDTH-1:0] in_data;
     input [NPRSPF_TLP_NUM_DWORDS-1:0] in_dwen;

     integer i,j,k;
     reg [NPRSPF_TLP_DATA_WIDTH-1:0] out_data;

     begin
        for (i=0; i<NPRSPF_TLP_NUM_DWORDS; i=i+1) begin
      // Data
           for (j=0; j<36; j=j+1) begin
              out_data[i*36+j] = in_dwen[i] & in_data[i*36+j];
           end

      // Parity bit: 4 bits per DWord
           for (k=1; k<=4; k=k+1) begin
              out_data[(i*36)+(k*9)-1] = in_dwen[i] ? in_data[(i*36)+(k*9)-1] : PARITY_BIT;
           end
        end
        fn_mask_data = out_data;
     end
  endfunction


`ifndef SYNTHESIS
`endif // SYNTHESIS

endmodule
