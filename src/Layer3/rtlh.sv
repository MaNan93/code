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
// ---    $DateTime: 2023/10/20 09:21:17 $
// ---    $Revision: #21 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh.sv#21 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles receive transaction Layer. Its main functions are:
//     (1) TLP Extract and alignment from DLLP interface
//     (2) Flow Control Tracking/messaging
//     (3) TLP header snoop and malform TLP checks that are required from
//     spec.
//     (4) ECRC strip off and error check , ECRC enable `define can reduce
//     the latency and save the gates if ECRC is not desired
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Layer3/rtlh_pkg.svh"


module rtlh 
import DWC_pcie_core_pkg::RX_NQDW;          // Number of 128-bit quad-dwords received per cycle
import DWC_pcie_core_pkg::rtlh_rfc_t;       // RTLH Received FC struct
import DWC_pcie_core_pkg::rtlh_radm_datapath_t;
#(
parameter   INST        = 0,                              // The uniquifying parameter for each port logic instance.
parameter   NVC         = `CX_NVC,                        // Number of virtual channels
parameter   NW          = `CX_NW,                         // Number of 32-bit dwords handled by the datapath each clock.
parameter   NB          = `CX_NB,                         // Number of bytes per cycle.
parameter   NF          = `CX_NFUNC,                      // Number of functions
parameter   DW          = (32*NW),                        // Width of datapath in bits.
parameter   TP          = `TP,                            // Clock to Q delay (simulator insurance)
parameter   RX_NDLLP    = `CX_RX_NDLLP,                   // Max number of DLLPs received per cycle
parameter   TX_NDLLP    = `CX_TX_NDLLP,                   // Max number of DLLPs send per cycle
parameter   DATA_PAR_WD = `TRGT_DATA_PROT_WD ,               // data bus parity width
parameter   RAS_PCIE_HDR_PROT_WD  = `CX_RAS_PCIE_HDR_PROT_WD,

parameter TW = 3,               // Number of bits of tag information to use for lookup
parameter FW = 3,               // Number of bits for function ID
parameter WD = 12 + 2 + 3,      // Width of completion entry (length, attribute, Traffic Class)
parameter RX_TLP = `CX_RX_TLP,  // Number of TLPs that can be processed in a single cycle
parameter HW_W_PAR = RX_TLP*(128+RAS_PCIE_HDR_PROT_WD),
parameter DW_W_PAR = DW+DATA_PAR_WD,
parameter HCRD_WD   = `SCALED_FC_SUPPORTED ? 12 : 8,
parameter DCRD_WD   = `SCALED_FC_SUPPORTED ? 16 : 12,
parameter NXQDW       = (NW==16) ? 2*(NW / 4) : 0, // Number of 128-bit qdwords extracted in rtlh_tlp_extract
parameter QDW_PROT_WD = `CX_RAS_QDW_PROT_WD,       // qdword Protection Width in bits 
parameter QDW_W_PROT  = 128 + QDW_PROT_WD,         // Generic qdword width including parity bits
parameter NPRFX = `CX_NPRFX,    // number of TLP prefixes supported
parameter PRFX_WD = 32*NPRFX,    // width of TLP prefix support in bits
parameter RX_PRFX_PAR_WD  = `CX_RX_PRFX_PAR_WD,        // defined in DWC_pcie_func_cc_constants.v
parameter PRFX_W_PAR      = RX_TLP*(PRFX_WD + RX_PRFX_PAR_WD),
parameter DCAW         = `CX_LOGBASE2(NW/4+1)      // Number of bits needed to represent the maximum number 
                                                   // of Data CA returned from the radm (512:3, 256:2, 128 or below:1)
,
parameter RAS_RTLH_COUNTERS   = `CX_RAS_RTLH_COUNTERS,
parameter ERROR_INJ_EN_WD     = `CX_RAS_ERROR_INJ_EN_WD,
parameter ERROR_INJ_MASK_WD   = `CX_RAS_ERROR_INJ_MASK_WD
)

           (
// -------------------------------- Inputs -------------------------------------
input                        core_clk,               // Core clock
input                        core_rst_n,             // Core system reset
input                        rstctl_core_flush_req,  // Request from DWC_pcie_rst_ctl module to flush pending TLPs
input                        cfg_endpoint,           // Port logic mode  1=endpoint
input                        cfg_root_compx,         // Port logic mode 1=root complex,
input                        cfg_upstream_port,      // Port logic mode (0=downstream, 1=upstream)
input   [2:0]                cfg_max_payload,        // MAX paylaod configured in CDM
input   [2:0]                cfg_max_payload_rx,     // In flit mode, The max payload -also known as "RX_MPS_limit"- has the value from the 'max_payload_size_supported' field.
input   [12:0]               cfg_fc_latency_value,   // FC update latency timer value
input                        cfg_ext_synch,          // Extended synch for N_FTS configured in CDM
input   [NVC-1:0]            cfg_vc_enable,          // VC enable map from CDM
input   [3*NVC-1:0]          cfg_vc_struc_vc_id_map, // Structure VC id to actual VC id map from CDM
input   [23:0]               cfg_vc_id_vc_struc_map, // Index by vc, returns structure VC
input   [23:0]               cfg_tc_struc_vc_map,    // Index by TC, returns VC
input   [7 :0]               cfg_tc_enable,          // TCs that are enabled
input                        cfg_fc_wdog_disable,    // disable watch dog timer in FC for some debug purpose
input   [6:0]                ras_prot_r_disable,
input   [(NVC*8)-1:0]        cfg_fc_credit_ph,       // Posted header wire to control the FC initial value for FC credit advertisement
input   [(NVC*8)-1:0]        cfg_fc_credit_nph,      // Nonposted header wire to control the FC initial value for FC credit advertisement
input   [(NVC*8)-1:0]        cfg_fc_credit_cplh,     // Completion header Wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]       cfg_fc_credit_pd,       // Posted data wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]       cfg_fc_credit_npd,      // Nonposted data wire to control the FC initial value for FC credit advertisement
input   [(NVC*12)-1:0]       cfg_fc_credit_cpld,     // Completion data wire to control the FC initial value for FC credit advertisement
input   [(2*NF)-1:0]        cfg_max_end2end_tlp_prfxs,      // the maximum number of End-End TLP Prefixes supported, DBI writeable.
input                       dpc_fatal_err_gate,      // DPC trigger gating for fatal error message
input                       dpc_nonfatal_err_gate,   // DPC trigger gating for non-fatal error message
input                        smlh_in_l1 ,            // Indicates LTSSM in L1 state
input                        smlh_flit_mode_enable,  // Flit Mode Enabled

input   [DW_W_PAR-1:0]       rdlh_rtlh_data,         // Current TLP header and data
input   [NW-1:0]             rdlh_rtlh_eot,          // When asserted, it indicates the end of a good TLP pkt
input   [NW-1:0]             rdlh_rtlh_soh,
input   [NW-1:0]             rdlh_rtlh_idl,
input   [NW-1:0]             rdlh_rtlh_pfx,
input                        rdlh_rtlh_fm_nullified, // The last TLP ending was Nullified by the Flit Marker
input                        rdlh_rtlh_fm_poisoned,  // The last TLP ending was Poisoned by the Flit Marker
input   [NW-1:0]             rdlh_rtlh_abort,        // TLP abort due to the data link layer detected error
input                        rdlh_rtlh_dv,           // TLP valid at this cycle
input   [RX_NDLLP-1:0]       rdlh_rtlh_rcvd_dllp,    // When asserted, it indicates reception of DLLP packet(s)
input                        rdlh_rtlh_rcvd_dllp_fm_opt_fc_up, // When assered, indicate that we have received a FM Optimized FC update dllp packet
input   [(32*RX_NDLLP)-1:0]  rdlh_rtlh_dllp_content, // The received DLLP packet(s)
input   [1:0]                rdlh_rtlh_link_state,   // RDLH link up FSM current state.

input   [DCAW*NVC-1:0]       radm_rtlh_ph_ca,        // Credit allocated (posted header)
input   [DCAW*NVC-1:0]       radm_rtlh_pd_ca,        // Credit allocated (posted data)
input   [DCAW*NVC-1:0]       radm_rtlh_nph_ca,       // Credit allocated (non-posted header)
input   [DCAW*NVC-1:0]       radm_rtlh_npd_ca,       // Credit allocated (non-posted data)
input   [DCAW*NVC-1:0]       radm_rtlh_cplh_ca,      // Credit allocated (completion header)
input   [DCAW*NVC-1:0]       radm_rtlh_cpld_ca,      // Credit allocated (completion data)

input                        xdlh_rtlh_fc_ack,       // When asserted, it indicates XDLH has accepted the request to XMIT a FC packet
input                        xadm_all_type_infinite, // XADM FC book keeping block indicates that remote link advertised all FC credits to infinite.
input                        pm_freeze_fc_timer,
input   [2:0]                current_data_rate,      // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4

input  [ERROR_INJ_EN_WD  -1:0]  ras_err_inj_en_array,
input  [ERROR_INJ_MASK_WD-1:0]  ras_err_inj_mask,
input                        cdm_ras_des_einj4_enable,       // Error injection 4 enable
input   [2:0]                cdm_ras_des_einj4_updfc_type,   // Error injection 4 UpdateFC type
input   [2:0]                cdm_ras_des_einj4_vcnum,        // Error injection 4 VC number
input   [12:0]               cdm_ras_des_einj4_badfc_value,  // Error injection 4 bad FC value
input                        cfg_flow_control_disable,       // Disable flow control. This disables the flow control DLLP generation.
input                        cdm_ras_des_einj2_enable,       // Error injection 2 enable
input   [1:0]                cdm_ras_des_einj2_dllp_type,    // Error injection 2 DLLP type
input                        fc_scaled_en,          // Indicates Data Link Features supported. Controls link FSM and allows expansion/reduction of credits in rtlh_fc_gen
input  [(NVC*2)-1:0]         hdr_scale_p,           // The HdrScale field contains the scaling factor for headers of the indicated type
input  [(NVC*2)-1:0]         hdr_scale_np,          // The HdrScale field contains the scaling factor for headers of the indicated type
input  [(NVC*2)-1:0]         hdr_scale_cpl,         // The HdrScale field contains the scaling factor for headers of the indicated type
input  [(NVC*2)-1:0]         data_scale_p,          // The DataScale field contains the scaling factor for payload data of the indicated type
input  [(NVC*2)-1:0]         data_scale_np,         // The DataScale field contains the scaling factor for payload data of the indicated type
input  [(NVC*2)-1:0]         data_scale_cpl,        // The DataScale field contains the scaling factor for payload data of the indicated type
// -------------------------------- Outputs ------------------------------------
output                       rtlh_rdlh_fci1_fci2,    // RTLH VC0 flow control has done init 1
output                       init_fc1_rcvd,          // Any INITFC1 has been received

output  [TX_NDLLP-1:0]       rtlh_xdlh_fc_req,       // Request to send a FCP
output                       rtlh_xdlh_fc_req_hi,    // Request to send a high-priority FCP that is higher than ACK/NACK
output                       rtlh_xdlh_fc_req_low,   // Request to send a low-priority FCP that is lower than TLP
output  [(32*TX_NDLLP)-1:0]  rtlh_xdlh_fc_data,      // Data associated with request

output  rtlh_rfc_t           rtlh_rfc,               // Received FC update: Update Transmit credit information
output  rtlh_radm_datapath_t rtlh_radm,
output  [NVC-1:0]            rtlh_fc_init_status,    // Report VC as ready for traffic
output  [NVC-1:0]            rtlh_crd_not_rtn,       // A debug feature for credit not return indication
output                       rtlh_req_link_retrain,  // Alink retrain request due to FC watch dog timer expiration
output                       rtlh_parerr,
output  [7:0]                rtfcgen_ph_diff_vc0,
output  logic                rtlh_overfl_err         // Indicates receiver overflow (credit based)
,
output  [RX_NDLLP -1:0]      rtlh_rcvd_ufc_perdllp , // Puls : Rx Update-FC DLLP Event per TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]         rtlh_rx_memwr_evt,      // Puls : Rx Memory Write TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]         rtlh_rx_defmemwr_evt,   // Puls : Rx Deferrable Memory Write TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]         rtlh_rx_memrd_evt,      // Puls : Rx Memory Read TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]         rtlh_rx_cfgwr_evt,      // Puls : Rx Config Write TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]         rtlh_rx_cfgrd_evt,      // Puls : Rx Config Read TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]         rtlh_rx_iowr_evt,       // Puls : Rx I/O Write TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]         rtlh_rx_iord_evt,       // Puls : Rx I/O Read TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]         rtlh_rx_cplwod_evt,     // Puls : Rx Completion without Data TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]         rtlh_rx_cplwd_evt,      // Puls : Rx Completion with Data TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]         rtlh_rx_msg_evt,        // Puls : Rx Message TLP for Ras D.E.S event counter
output  [RX_TLP-1:0]         rtlh_rx_atmcop_evt,     // Puls : Rx AtomicOp TLP for Ras D.E.S event counter
output  logic [RX_TLP-1:0]   rtlh_rx_tlpwprefix_evt, // Puls : Rx TLP with Prefix for Ras D.E.S event counter
output  [RX_TLP*11-1:0]      rtlh_rx_tlp_dpsize,             // Receiving TLP's data payload size[DW]
output  [(NVC*HCRD_WD)-1:0]  rtlh_fc_rcvd_ph,        // Level : Current FC Credit Received(Posted Header) for Ras D.E.S Silicon Debug
output  [(NVC*DCRD_WD)-1:0]  rtlh_fc_rcvd_pd,        // Level : Current FC Credit Received(Posted Data) for Ras D.E.S Silicon Debug
output  [(NVC*HCRD_WD)-1:0]  rtlh_fc_rcvd_nph,       // Level : Current FC Credit Received(Non-Posted Header) for Ras D.E.S Silicon Debug
output  [(NVC*DCRD_WD)-1:0]  rtlh_fc_rcvd_npd,       // Level : Current FC Credit Received(Non-Posted Data) for Ras D.E.S Silicon Debug
output  [(NVC*HCRD_WD)-1:0]  rtlh_fc_rcvd_cplh,      // Level : Current FC Credit Received(Completion Header) for Ras D.E.S Silicon Debug
output  [(NVC*DCRD_WD)-1:0]  rtlh_fc_rcvd_cpld,      // Level : Current FC Credit Received(Completion Data) for Ras D.E.S Silicon Debug
output  [(NVC*HCRD_WD)-1:0]  rtlh_fc_allctd_ph,      // Level : Current FC Credit Allocated(Posted Header) for Ras D.E.S Silicon Debug
output  [(NVC*DCRD_WD)-1:0]  rtlh_fc_allctd_pd,      // Level : Current FC Credit Allocated(Posted Data) for Ras D.E.S Silicon Debug
output  [(NVC*HCRD_WD)-1:0]  rtlh_fc_allctd_nph,     // Level : Current FC Credit Allocated(Non-Posted Header) for Ras D.E.S Silicon Debug
output  [(NVC*DCRD_WD)-1:0]  rtlh_fc_allctd_npd,     // Level : Current FC Credit Allocated(Non-Posted Data) for Ras D.E.S Silicon Debug
output  [(NVC*HCRD_WD)-1:0]  rtlh_fc_allctd_cplh,    // Level : Current FC Credit Allocated(Completion Header) for Ras D.E.S Silicon Debug
output  [(NVC*DCRD_WD)-1:0]  rtlh_fc_allctd_cpld     // Level : Current FC Credit Allocated(Completion Data) for Ras D.E.S Silicon Debug
,
output                       rtlh_einj4_fc_evt       // Error injection 4 FC event

,
output [RAS_RTLH_COUNTERS-1:0] ras_stat_rtlh_corr,
output [RAS_RTLH_COUNTERS-1:0] ras_stat_rtlh_uncorr
,
output                         ras_err_inj_done
);

// ============================================================
// Quasi-static Signals
// ============================================================
typedef struct packed {
    logic        dpc_fatal_err_gate;
    logic        dpc_nonfatal_err_gate;
    logic        cfg_upstream_port;
}
rtlh_quasi_static_s;
rtlh_quasi_static_s qs_in, qs;

assign qs_in.dpc_fatal_err_gate    = dpc_fatal_err_gate;
assign qs_in.dpc_nonfatal_err_gate = dpc_nonfatal_err_gate;
assign qs_in.cfg_upstream_port     = cfg_upstream_port;

delay_n
 
  #( .N (1), .WD ($bits(rtlh_quasi_static_s)) )
  u_rdlh_qs_pipeline (
  .clk    (core_clk),
  .rst_n  (core_rst_n),
  .clear  (1'b0),
  .din    (qs_in),
  .dout   (qs)
);

reg  flit_mode_en; // Register to reduce fanout and ease timing
always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n)  begin
        flit_mode_en <= #TP 0;
    end else begin
        flit_mode_en <= #TP smlh_flit_mode_enable;
    end
end

rtlh_pkg::rtlh_qdw_extract_t [RX_NQDW-1:0] rtqextract;
wire rtqextract_fm_nullified;
wire rtqextract_fm_poisoned;

rtlh_qdw_extract
 u_rtlh_qdw_extract(
  // --- inputs --------------------------------------
    .core_clk               (core_clk),
    .core_rst_n             (core_rst_n),
    .rtlh_tlp_soh           (rdlh_rtlh_soh),
    .rtlh_tlp_eot           (rdlh_rtlh_eot),
    .rtlh_tlp_pfx           (rdlh_rtlh_pfx),
    .rtlh_tlp_idl           (rdlh_rtlh_idl),
    .rtlh_tlp_fm_nullified  (rdlh_rtlh_fm_nullified),
    .rtlh_tlp_fm_poisoned   (rdlh_rtlh_fm_poisoned),
    .rtlh_tlp_dllp_err      (rdlh_rtlh_abort),
    .rtlh_data              (rdlh_rtlh_data),
    .rtlh_data_dv           (rdlh_rtlh_dv),
    .cfg_tc_struc_vc_map    (cfg_tc_struc_vc_map),
    .dpc_fatal_err_gate     (qs.dpc_fatal_err_gate),
    .dpc_nonfatal_err_gate  (qs.dpc_nonfatal_err_gate),
    .cfg_upstream_port      (qs.cfg_upstream_port),
    .flit_mode_en           (flit_mode_en),
  // --- outputs --------------------------------------
    .rtqextract_fm_nullified (rtqextract_fm_nullified),
    .rtqextract_fm_poisoned  (rtqextract_fm_poisoned),
    .rtqextract              (rtqextract)
);

wire    [3*RX_NQDW-1:0]  rtcheck_rtfcgen_vc;
wire    [2*RX_NQDW-1:0]  rtfcgen_fctype;
wire    [RX_NQDW-1:0]    rtfcgen_incr_enable;
wire    [9*RX_NQDW-1:0]  rtfcgen_incr_amt;
wire    [NVC-1:0]        rtlh_fc_init1_status;   // Report VC as ready for traffic
wire    [RX_NQDW-1:0]    rtfcgen_rtcheck_overfl_err;

rtlh_tlp_check_ms
 u_rtlh_tlp_check_ms(
  // --- inputs --------------------------------------
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .rstctl_core_flush_req          (rstctl_core_flush_req),
    .rtqextract                     (rtqextract),
    .rtqextract_fm_nullified        (rtqextract_fm_nullified),
    .rtqextract_fm_poisoned         (rtqextract_fm_poisoned),
    .rtfcgen_rtcheck_overfl_err     (rtfcgen_rtcheck_overfl_err),
  // --- outputs --------------------------------------
    .rtcheck_rtfcgen_vc             (rtcheck_rtfcgen_vc),
    .rtfcgen_fctype                 (rtfcgen_fctype),
    .rtfcgen_incr_enable            (rtfcgen_incr_enable),
    .rtfcgen_incr_amt               (rtfcgen_incr_amt),
    .rtlh_radm                      (rtlh_radm)
    ,
    .rtlh_rx_memwr_evt              (rtlh_rx_memwr_evt),
    .rtlh_rx_defmemwr_evt           (rtlh_rx_defmemwr_evt),
    .rtlh_rx_memrd_evt              (rtlh_rx_memrd_evt),
    .rtlh_rx_cfgwr_evt              (rtlh_rx_cfgwr_evt),
    .rtlh_rx_cfgrd_evt              (rtlh_rx_cfgrd_evt),
    .rtlh_rx_iowr_evt               (rtlh_rx_iowr_evt),
    .rtlh_rx_iord_evt               (rtlh_rx_iord_evt),
    .rtlh_rx_cplwod_evt             (rtlh_rx_cplwod_evt),
    .rtlh_rx_cplwd_evt              (rtlh_rx_cplwd_evt),
    .rtlh_rx_msg_evt                (rtlh_rx_msg_evt),
    .rtlh_rx_atmcop_evt             (rtlh_rx_atmcop_evt),
    .rtlh_rx_tlpwprefix_evt         (rtlh_rx_tlpwprefix_evt),
    .rtlh_rx_tlp_dpsize             (rtlh_rx_tlp_dpsize)
);

assign     rtlh_rdlh_fci1_fci2 = rtlh_fc_init1_status[0];

// Register output status port for receiver flow control overflow events
always @( posedge core_clk or negedge core_rst_n ) begin : rtlh_overfl_err_ms_PROC
  if ( ~core_rst_n )
    rtlh_overfl_err <= #`TP 1'b0;
  else
    rtlh_overfl_err <= #`TP |rtfcgen_rtcheck_overfl_err;
end // rtlh_overfl_err_PROC

// lbc needs ph credits from VC0
wire   [NVC*HCRD_WD-1:0]    rtfcgen_ph_diff;
assign rtfcgen_ph_diff_vc0 = rtfcgen_ph_diff[7:0];

assign ras_stat_rtlh_corr = 0;   // www. Future enhancement: not supported yet
assign ras_stat_rtlh_uncorr = 0; // www. Future enhancement: not supported yet
assign ras_err_inj_done = 0;     // www. Future enhancement: not supported yet

assign rtlh_parerr = 0;          // www. Future enhancement: not supported yet


rtlh_fc

#(INST) u_rtlh_fc(
    .core_clk                       (core_clk),
    .core_rst_n                     (core_rst_n),
    .cfg_max_payload                (cfg_max_payload_rx),
    .cfg_upstream_port              (cfg_upstream_port),
    .cfg_fc_latency_value           (cfg_fc_latency_value),
    .cfg_ext_synch                  (cfg_ext_synch),
    .cfg_vc_enable                  (cfg_vc_enable),
    .cfg_vc_struc_vc_id_map         (cfg_vc_struc_vc_id_map),
    .cfg_vc_id_vc_struc_map         (cfg_vc_id_vc_struc_map),
    .cfg_fc_wdog_disable            (cfg_fc_wdog_disable),
    .cfg_fc_credit_ph               (cfg_fc_credit_ph),
    .cfg_fc_credit_nph              (cfg_fc_credit_nph),
    .cfg_fc_credit_cplh             (cfg_fc_credit_cplh),
    .cfg_fc_credit_pd               (cfg_fc_credit_pd),
    .cfg_fc_credit_npd              (cfg_fc_credit_npd),
    .cfg_fc_credit_cpld             (cfg_fc_credit_cpld),
    .smlh_in_l1                     (smlh_in_l1    ),
    .rdlh_rtlh_rcvd_dllp            (rdlh_rtlh_rcvd_dllp),
    .rdlh_rtlh_rcvd_dllp_fm_opt_fc_up(rdlh_rtlh_rcvd_dllp_fm_opt_fc_up),
    .rdlh_rtlh_dllp_content         (rdlh_rtlh_dllp_content),
    .rdlh_rtlh_link_state           (rdlh_rtlh_link_state),
    .xdlh_rtlh_fc_ack               (xdlh_rtlh_fc_ack),
    .radm_rtlh_ph_ca                (radm_rtlh_ph_ca),
    .radm_rtlh_pd_ca                (radm_rtlh_pd_ca),
    .radm_rtlh_nph_ca               (radm_rtlh_nph_ca),
    .radm_rtlh_npd_ca               (radm_rtlh_npd_ca),
    .radm_rtlh_cplh_ca              (radm_rtlh_cplh_ca),
    .radm_rtlh_cpld_ca              (radm_rtlh_cpld_ca),
    .rtcheck_rtfcgen_vc             (rtcheck_rtfcgen_vc),
    .rtcheck_rtfcgen_fctype         (rtfcgen_fctype),
    .rtcheck_rtfcgen_incr_enable    (rtfcgen_incr_enable),
    .rtcheck_rtfcgen_incr_amt       (rtfcgen_incr_amt),
    .pm_freeze_fc_timer             (pm_freeze_fc_timer),
    .xadm_all_type_infinite         (xadm_all_type_infinite),
    .current_data_rate              (current_data_rate),
    .fc_scaled_en                   (fc_scaled_en),
    .hdr_scale_p                    (hdr_scale_p),
    .hdr_scale_np                   (hdr_scale_np),
    .hdr_scale_cpl                  (hdr_scale_cpl),
    .data_scale_p                   (data_scale_p),
    .data_scale_np                  (data_scale_np),
    .data_scale_cpl                 (data_scale_cpl),
    .cdm_ras_des_einj4_enable       (cdm_ras_des_einj4_enable),
    .cdm_ras_des_einj4_updfc_type   (cdm_ras_des_einj4_updfc_type),
    .cdm_ras_des_einj4_vcnum        (cdm_ras_des_einj4_vcnum),
    .cdm_ras_des_einj4_badfc_value  (cdm_ras_des_einj4_badfc_value),
    .cfg_flow_control_disable           (cfg_flow_control_disable),
    .cdm_ras_des_einj2_enable           (cdm_ras_des_einj2_enable),
    .cdm_ras_des_einj2_dllp_type        (cdm_ras_des_einj2_dllp_type),
    .flit_mode_en                   (flit_mode_en),
    .rtlh_fc_init_status            (rtlh_fc_init_status),
    .rtlh_fc_init1_status           (rtlh_fc_init1_status),
    .rtlh_xdlh_fc_req               (rtlh_xdlh_fc_req),
    .rtlh_xdlh_fc_req_hi            (rtlh_xdlh_fc_req_hi),
    .rtlh_xdlh_fc_req_low           (rtlh_xdlh_fc_req_low),
    .rtlh_xdlh_fc_data              (rtlh_xdlh_fc_data),
    .rtlh_rfc                       (rtlh_rfc),
    .rtlh_crd_not_rtn               (rtlh_crd_not_rtn),
    .rtlh_req_link_retrain          (rtlh_req_link_retrain),
    .rtfcgen_rtcheck_overfl_err     (rtfcgen_rtcheck_overfl_err),
    .rtfcgen_ph_diff                (rtfcgen_ph_diff)
    ,
    .init_fc1_rcvd                  (init_fc1_rcvd)
    ,
    .rtlh_rcvd_ufc_perdllp          (rtlh_rcvd_ufc_perdllp),
    .rtlh_fc_rcvd_ph                (rtlh_fc_rcvd_ph),
    .rtlh_fc_rcvd_pd                (rtlh_fc_rcvd_pd),
    .rtlh_fc_rcvd_nph               (rtlh_fc_rcvd_nph),
    .rtlh_fc_rcvd_npd               (rtlh_fc_rcvd_npd),
    .rtlh_fc_rcvd_cplh              (rtlh_fc_rcvd_cplh),
    .rtlh_fc_rcvd_cpld              (rtlh_fc_rcvd_cpld),
    .rtlh_fc_allctd_ph              (rtlh_fc_allctd_ph),
    .rtlh_fc_allctd_pd              (rtlh_fc_allctd_pd),
    .rtlh_fc_allctd_nph             (rtlh_fc_allctd_nph),
    .rtlh_fc_allctd_npd             (rtlh_fc_allctd_npd),
    .rtlh_fc_allctd_cplh            (rtlh_fc_allctd_cplh),
    .rtlh_fc_allctd_cpld            (rtlh_fc_allctd_cpld)
    ,
    .rtlh_einj4_fc_evt              (rtlh_einj4_fc_evt)
);


endmodule
