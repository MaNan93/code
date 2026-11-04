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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_fc_gen.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module performs the FC-based link initilization and flow control
// --- updates.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/pcie_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

 
 module rtlh_fc_gen (
    core_clk,
    core_rst_n,
    cfg_upstream_port,
    cfg_max_payload,
    cfg_struc_vc_id,
    cfg_vc_id,
    cfg_vc_enable,
    cfg_fc_credit_ph,
    cfg_fc_credit_nph,
    cfg_fc_credit_cplh,
    cfg_fc_credit_pd,
    cfg_fc_credit_npd,
    cfg_fc_credit_cpld,
    pm_freeze_fc_timer,
    smlh_in_l1,
    cfg_fc_latency_value,
    rtfcarb_ack,
    rtlh_fc_init_status,
    rdlh_rtlh_link_state,
    radm_rtlh_ph_ca,
    radm_rtlh_pd_ca,
    radm_rtlh_nph_ca,
    radm_rtlh_npd_ca,
    radm_rtlh_cplh_ca,
    radm_rtlh_cpld_ca,
    rtcheck_rtfcgen_vc,
    rtcheck_rtfcgen_fctype,
    rtcheck_rtfcgen_incr_enable,
    rtcheck_rtfcgen_incr_amt,
    fc_update_timer_expired,
    current_data_rate,
    flit_mode_en,
    cdm_ras_des_einj4_enable,
    cdm_ras_des_einj4_updfc_type,
    cdm_ras_des_einj4_vcnum,
    cdm_ras_des_einj4_badfc_value,
    fc_scaled_en,
    hdr_scale_p,
    hdr_scale_np,
    hdr_scale_cpl,
    data_scale_p,
    data_scale_np,
    data_scale_cpl,
    // Outputs
    rtfcgen_fc_req,
    rtfcgen_fc_req_hi,
    rtfcgen_fc_data,
    rtlh_crd_not_rtn,
    rtfcgen_rtcheck_overfl_err,
    rtfcgen_ph_diff
    ,
    rtlh_fc_rcvd_ph,
    rtlh_fc_rcvd_pd,
    rtlh_fc_rcvd_nph,
    rtlh_fc_rcvd_npd,
    rtlh_fc_rcvd_cplh,
    rtlh_fc_rcvd_cpld,
    rtlh_fc_allctd_ph,
    rtlh_fc_allctd_pd,
    rtlh_fc_allctd_nph,
    rtlh_fc_allctd_npd,
    rtlh_fc_allctd_cplh,
    rtlh_fc_allctd_cpld
    ,
    rtlh_einj4_fc_evt
);

parameter INST      = 0;                                // The uniquifying parameter for each port logic instance.
parameter NL        = `CX_NL;                           // Max number of lanes supported
parameter NB        = `CX_NB;                           // Number of symbols (bytes) per clock cycle
parameter NW        = `CX_NW;                           // Number of 32-bit dwords handled by the datapath each clock.
parameter DW        = (32*NW);                          // Width of datapath in bits.
parameter NVC       = `CX_NVC;                          // Number of Virtual channels.
parameter RX_NDLLP  = `CX_RX_NDLLP;                     // Max number of DLLPs received per cycle
parameter TP        = `TP;                              // Clock to Q delay (simulator insurance)

localparam RX_TLP     = 0 
                        + DWC_pcie_core_pkg::RX_NQDW 
                        ;
localparam DCAW     = `CX_LOGBASE2(NW/4+1);             // Number of bits needed to represent the maximum number of Data CA
                                                        // returned from the radm (512:3, 256:2, 128 or below:1)
localparam HCRD_WD  = `SCALED_FC_SUPPORTED ? 12 : 8;
localparam DCRD_WD  = `SCALED_FC_SUPPORTED ? 16 : 12;

//
// -------------------------------- Inputs -------------------------------------
input                   core_clk;                       // Core clock
input                   core_rst_n;                     // Core system reset
input                   cfg_upstream_port;              // Indicate that this is an upstream port of a downstream device
input   [2:0]           cfg_max_payload;
input   [2:0]           cfg_vc_id;
input   [2:0]           cfg_struc_vc_id;
input   [0:0]           cfg_vc_enable;                  // When asserted, indicates that this VC is currently enabled
input   [7:0]           cfg_fc_credit_ph;               // Posted header wire to control the FC initial value for FC credit advertisement
input   [7:0]           cfg_fc_credit_nph;              // Nonposted header wire to control the FC initial value for FC credit advertisement
input   [7:0]           cfg_fc_credit_cplh;             // Completion header Wire to control the FC initial value for FC credit advertisement
input   [11:0]          cfg_fc_credit_pd;               // Posted data wire to control the FC initial value for FC credit advertisement
input   [11:0]          cfg_fc_credit_npd;              // Nonposted data wire to control the FC initial value for FC credit advertisement
input   [11:0]          cfg_fc_credit_cpld;             // Completion data wire to control the FC initial value for FC credit advertisement
input                   pm_freeze_fc_timer;             // power module request to freeze the central FC 8us timer which is sharec between arbiter and gen block
input                   smlh_in_l1;                     // LTSSM is in L1 state
input   [12:0]          cfg_fc_latency_value;           // Latency guideline from spec, based on current operating max payload

input                   rtfcarb_ack;                    // When asserted, it indicates our fc_data has been transmitted

input  [DCAW-1:0]       radm_rtlh_ph_ca;                // Credit allocated (posted header)
input  [DCAW-1:0]       radm_rtlh_pd_ca;                // Credit allocated (posted data)
input  [DCAW-1:0]       radm_rtlh_nph_ca;               // Credit allocated (non-posted header)
input  [DCAW-1:0]       radm_rtlh_npd_ca;               // Credit allocated (non-posted data)
input  [DCAW-1:0]       radm_rtlh_cplh_ca;              // Credit allocated (completion header)
input  [DCAW-1:0]       radm_rtlh_cpld_ca;              // Credit allocated (completion data)

input   [3*RX_TLP-1:0]  rtcheck_rtfcgen_vc;             // What STURCTURE VC did the packet belong to
input   [2*RX_TLP-1:0]  rtcheck_rtfcgen_fctype;         // What type of packet (posted, nonposted, completion)
input   [RX_TLP-1:0]    rtcheck_rtfcgen_incr_enable;    // Count headers going to application
input   [9*RX_TLP-1:0]  rtcheck_rtfcgen_incr_amt;       // Count payload going to application

input   [1:0]           rdlh_rtlh_link_state;
input                   rtlh_fc_init_status;            // Set for each VC at completion of FCINIT1 and FCINIT2
input                   fc_update_timer_expired;        // a update of 30 us timer from fc_arb
input   [2:0]           current_data_rate;              // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4
input                   flit_mode_en;
input                   cdm_ras_des_einj4_enable;       // Error injection 4 enable
input   [2:0]           cdm_ras_des_einj4_updfc_type;   // Error injection 4 UpdateFC type
input   [2:0]           cdm_ras_des_einj4_vcnum;        // Error injection 4 VC number
input   [12:0]          cdm_ras_des_einj4_badfc_value;  // Error injection 4 bad FC value
input                   fc_scaled_en;           // Indicates Data Link Features supported. Controls link FSM and allows expansion/reduction of credits in rtlh_fc_gen
input  [1:0]            hdr_scale_p;            // The HdrScale field contains the scaling factor for headers of the indicated type
input  [1:0]            hdr_scale_np;           // The DataScale field contains the scaling factor for payload data of the indicated type
input  [1:0]            hdr_scale_cpl;          // The HdrScale field contains the scaling factor for headers of the indicated type
input  [1:0]            data_scale_p;           // The DataScale field contains the scaling factor for payload data of the indicated type
input  [1:0]            data_scale_np;          // The HdrScale field contains the scaling factor for headers of the indicated type
input  [1:0]            data_scale_cpl;         // The DataScale field contains the scaling factor for payload data of the indicated type

// -------------------------------- Outputs ------------------------------------
output                  rtfcgen_fc_req;
output                  rtfcgen_fc_req_hi;
output  [31:0]          rtfcgen_fc_data;
output                  rtlh_crd_not_rtn;

output  [RX_TLP-1:0]    rtfcgen_rtcheck_overfl_err;
output  [HCRD_WD-1:0]   rtfcgen_ph_diff;

output  [HCRD_WD-1:0] rtlh_fc_rcvd_ph;        // Level : Current FC Credit Received(Posted Header) for Ras D.E.S Silicon Debug
output  [DCRD_WD-1:0] rtlh_fc_rcvd_pd;        // Level : Current FC Credit Received(Posted Data) for Ras D.E.S Silicon Debug
output  [HCRD_WD-1:0] rtlh_fc_rcvd_nph;       // Level : Current FC Credit Received(Non-Posted Header) for Ras D.E.S Silicon Debug
output  [DCRD_WD-1:0] rtlh_fc_rcvd_npd;       // Level : Current FC Credit Received(Non-Posted Data) for Ras D.E.S Silicon Debug
output  [HCRD_WD-1:0] rtlh_fc_rcvd_cplh;      // Level : Current FC Credit Received(Completion Header) for Ras D.E.S Silicon Debug
output  [DCRD_WD-1:0] rtlh_fc_rcvd_cpld;      // Level : Current FC Credit Received(Completion Data) for Ras D.E.S Silicon Debug
output  [HCRD_WD-1:0] rtlh_fc_allctd_ph;      // Level : Current FC Credit Allocated(Posted Header) for Ras D.E.S Silicon Debug
output  [DCRD_WD-1:0] rtlh_fc_allctd_pd;      // Level : Current FC Credit Allocated(Posted Data) for Ras D.E.S Silicon Debug
output  [HCRD_WD-1:0] rtlh_fc_allctd_nph;     // Level : Current FC Credit Allocated(Non-Posted Header) for Ras D.E.S Silicon Debug
output  [DCRD_WD-1:0] rtlh_fc_allctd_npd;     // Level : Current FC Credit Allocated(Non-Posted Data) for Ras D.E.S Silicon Debug
output  [HCRD_WD-1:0] rtlh_fc_allctd_cplh;    // Level : Current FC Credit Allocated(Completion Header) for Ras D.E.S Silicon Debug;
output  [DCRD_WD-1:0] rtlh_fc_allctd_cpld;    // Level : Current FC Credit Allocated(Completion Data) for Ras D.E.S Silicon Debug;
output                  rtlh_einj4_fc_evt;          // Error injection 4 FC event

// Output registers
reg                     rtfcgen_fc_req;
reg                     rtfcgen_fc_req_hi;
reg                     rtfcgen_fc_p_req_hi;
reg                     rtfcgen_fc_np_req_hi;
reg                     rtfcgen_fc_cpl_req_hi;
reg     [31:0]          rtfcgen_fc_data;
reg                     p_timeout_30us;
reg                     np_timeout_30us;
reg                     cpl_timeout_30us;
reg                     recovery_from_exhaustion_p;
reg                     recovery_from_exhaustion_np;
reg                     recovery_from_exhaustion_cpl;
reg                     recovery_from_insufficiency_p;
reg                     recovery_from_insufficiency_cpl;
reg                     total_cr_consumed_p;
reg                     total_cr_consumed_np;
reg                     total_cr_consumed_cpl;

wire                    non_infinite_ph;
wire                    non_infinite_nph;
wire                    non_infinite_cplh;
wire                    non_infinite_p;
wire                    non_infinite_np;
wire                    non_infinite_cpl;
wire  [HCRD_WD-1:0]   rtlh_fc_rcvd_ph;
wire  [DCRD_WD-1:0]   rtlh_fc_rcvd_pd;
wire  [HCRD_WD-1:0]   rtlh_fc_rcvd_nph;
wire  [DCRD_WD-1:0]   rtlh_fc_rcvd_npd;
wire  [HCRD_WD-1:0]   rtlh_fc_rcvd_cplh;
wire  [DCRD_WD-1:0]   rtlh_fc_rcvd_cpld;
wire  [HCRD_WD-1:0]   rtlh_fc_allctd_ph;
wire  [DCRD_WD-1:0]   rtlh_fc_allctd_pd;
wire  [HCRD_WD-1:0]   rtlh_fc_allctd_nph;
wire  [DCRD_WD-1:0]   rtlh_fc_allctd_npd;
wire  [HCRD_WD-1:0]   rtlh_fc_allctd_cplh;
wire  [DCRD_WD-1:0]   rtlh_fc_allctd_cpld;
wire                    einj4_ph_en;
wire                    einj4_nh_en;
wire                    einj4_ch_en;
wire                    einj4_pd_en;
wire                    einj4_nd_en;
wire                    einj4_cd_en;
wire                    p_req_evt;
wire                    n_req_evt;
wire                    c_req_evt;


//allowing one extra clk cycle before link up when DL feature enabled
reg dl_feature_state_d;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        dl_feature_state_d     <= #TP 0;
    end else begin
        dl_feature_state_d     <= #TP rdlh_rtlh_link_state == `S_DL_FEATURE;
    end

wire tmp_link_down;
assign tmp_link_down = (rdlh_rtlh_link_state == `S_DL_INACTIVE) 
                        || (rdlh_rtlh_link_state == `S_DL_FEATURE) || dl_feature_state_d
;



//expand the credit advertisement value for scaled flow control
wire [HCRD_WD-1:0]   exp_cfg_fc_credit_ph;
wire [HCRD_WD-1:0]   exp_cfg_fc_credit_nph;
wire [HCRD_WD-1:0]   exp_cfg_fc_credit_cplh;
wire [DCRD_WD-1:0]   exp_cfg_fc_credit_pd;
wire [DCRD_WD-1:0]   exp_cfg_fc_credit_npd;
wire [DCRD_WD-1:0]   exp_cfg_fc_credit_cpld;

wire [11:0] hdr_fc_max = 12'h7f;    // max allowable header credits for non-scaling
wire [15:0] data_fc_max =  16'h7ff; // max allowable data credits for non-scaling


// expand from 8 bit to 12 bit for header
// if link partner does not support FC Scaling then reduce credits available to max allowable for non-scaling
assign exp_cfg_fc_credit_ph =   (fc_scaled_en && hdr_scale_p == 2'b11) ? {cfg_fc_credit_ph, 4'b0} : 
                                (fc_scaled_en && hdr_scale_p == 2'b10) ? {2'b0, cfg_fc_credit_ph, 2'b0} : 
                                (fc_scaled_en && (hdr_scale_p == 2'b01 || hdr_scale_p == 2'b00)) ? {4'b0, cfg_fc_credit_ph} :
                                (!fc_scaled_en && hdr_scale_p > 2'b01) ? hdr_fc_max : {4'b0, cfg_fc_credit_ph};
                                
assign exp_cfg_fc_credit_nph =  (fc_scaled_en && hdr_scale_np == 2'b11) ? {cfg_fc_credit_nph, 4'b0} :
                                (fc_scaled_en && hdr_scale_np == 2'b10) ? {2'b0, cfg_fc_credit_nph, 2'b0} :
                                (fc_scaled_en && (hdr_scale_np == 2'b01 || hdr_scale_np == 2'b00)) ? {4'b0, cfg_fc_credit_nph} :
                                (!fc_scaled_en && hdr_scale_np > 2'b01) ? hdr_fc_max : {4'b0, cfg_fc_credit_nph};
                                
assign exp_cfg_fc_credit_cplh = (fc_scaled_en && hdr_scale_cpl == 2'b11) ? {cfg_fc_credit_cplh, 4'b0} :
                                (fc_scaled_en && hdr_scale_cpl == 2'b10) ? {2'b0, cfg_fc_credit_cplh, 2'b0} :
                                (fc_scaled_en && (hdr_scale_cpl == 2'b01 || hdr_scale_cpl == 2'b00)) ? {4'b0, cfg_fc_credit_cplh} :
                                (!fc_scaled_en && hdr_scale_cpl > 2'b01) ? hdr_fc_max : {4'b0, cfg_fc_credit_cplh};
//expand from 12 bit to 16 bit for data
assign exp_cfg_fc_credit_pd =   (fc_scaled_en && data_scale_p == 2'b11) ? {cfg_fc_credit_pd, 4'b0} : 
                                (fc_scaled_en && data_scale_p == 2'b10) ? {2'b0, cfg_fc_credit_pd, 2'b0} :
                                (fc_scaled_en && (data_scale_p == 2'b01 || data_scale_p == 2'b00)) ? {4'b0, cfg_fc_credit_pd} : 
                                (!fc_scaled_en && data_scale_p > 2'b01) ? data_fc_max : {4'b0, cfg_fc_credit_pd};
                                
assign exp_cfg_fc_credit_npd =  (fc_scaled_en && data_scale_np == 2'b11) ? {cfg_fc_credit_npd, 4'b0} :
                                (fc_scaled_en && data_scale_np == 2'b10) ? {2'b0, cfg_fc_credit_npd, 2'b0} :
                                (fc_scaled_en && (data_scale_np == 2'b01 || data_scale_np == 2'b00)) ? {4'b0, cfg_fc_credit_npd} : 
                                (!fc_scaled_en && data_scale_np > 2'b01) ? data_fc_max : {4'b0, cfg_fc_credit_npd};
                                
assign exp_cfg_fc_credit_cpld = (fc_scaled_en && data_scale_cpl == 2'b11) ? {cfg_fc_credit_cpld, 4'b0} : 
                                (fc_scaled_en && data_scale_cpl == 2'b10) ? {2'b0, cfg_fc_credit_cpld, 2'b0} :
                                (fc_scaled_en && (data_scale_cpl == 2'b01 || data_scale_cpl == 2'b00)) ? {4'b0, cfg_fc_credit_cpld} : 
                                (!fc_scaled_en && data_scale_cpl > 2'b01) ? data_fc_max : {4'b0, cfg_fc_credit_cpld};

assign non_infinite_ph   = (cfg_fc_credit_ph   != 0);
assign non_infinite_nph  = (cfg_fc_credit_nph  != 0);
assign non_infinite_cplh = (cfg_fc_credit_cplh != 0);
assign non_infinite_p    = (cfg_fc_credit_pd   != 0);
assign non_infinite_np   = (cfg_fc_credit_npd  != 0);
assign non_infinite_cpl  = (cfg_fc_credit_cpld != 0);

wire                    int_fcupdt_req;
wire                    p_fcupdt_req;
wire                    np_fcupdt_req;
wire                    cpl_fcupdt_req;
// we do not create low priority request any more. All requests of update
// are high priority
reg                     clked_radm_ca_p;
reg                     clked_radm_ca_np;
reg                     clked_radm_ca_cpl;

// FC tracking registers
reg     [DCRD_WD-1:0]   rtfcgen_ca_pd_org;             // Payload(data) credits accumulated (posted, non-posted, completion)
reg     [DCRD_WD-1:0]   rtfcgen_ca_npd_org;
reg     [DCRD_WD-1:0]   rtfcgen_ca_cpld_org;
reg     [HCRD_WD-1:0]   rtfcgen_ca_ph_org;             // Header credits accumulated (posted, non-posted, completion)
reg     [HCRD_WD-1:0]   rtfcgen_ca_nph_org;
reg     [HCRD_WD-1:0]   rtfcgen_ca_cplh_org;

wire    [DCRD_WD-1:0]   rtfcgen_ca_pd;                 // Payload(data) credits accumulated (posted, non-posted, completion)
wire    [DCRD_WD-1:0]   rtfcgen_ca_npd;
wire    [DCRD_WD-1:0]   rtfcgen_ca_cpld;
wire    [HCRD_WD-1:0]   rtfcgen_ca_ph;                 // Header credits accumulated (posted, non-posted, completion)
wire    [HCRD_WD-1:0]   rtfcgen_ca_nph;
wire    [HCRD_WD-1:0]   rtfcgen_ca_cplh;

reg     [DCRD_WD-1:0]   rtfcgen_cr_pd;             // Payload(data) credits received (posted, non-posted, completion)
reg     [DCRD_WD-1:0]   rtfcgen_cr_npd;
reg     [DCRD_WD-1:0]   rtfcgen_cr_cpld;
reg     [HCRD_WD-1:0]   rtfcgen_cr_ph;             // Header credits received (posted, non-posted, completion)
reg     [HCRD_WD-1:0]   rtfcgen_cr_nph;
reg     [HCRD_WD-1:0]   rtfcgen_cr_cplh;

wire    [DCRD_WD-1:0]  rtfcgen_pd_diff;
wire    [DCRD_WD-1:0]  rtfcgen_npd_diff;
wire    [DCRD_WD-1:0]  rtfcgen_cpld_diff;
wire    [HCRD_WD-1:0]  rtfcgen_ph_diff;
wire    [HCRD_WD-1:0]  rtfcgen_nph_diff;
wire    [HCRD_WD-1:0]  rtfcgen_cplh_diff;

// Flags that latency timer expired, time to send FC Update
reg                     send_latency_p;
reg                     send_latency_np;
reg                     send_latency_cpl;

// Following logic implements the Update FC Transmission Latency guidelines
// 2.6.1.2.
reg need_update_p;
reg need_update_np;
reg need_update_cpl;

wire fcupdt_done_p;
wire fcupdt_done_np;
wire fcupdt_done_cpl;


 assign einj4_ph_en = cdm_ras_des_einj4_enable & (cfg_struc_vc_id==cdm_ras_des_einj4_vcnum) & (cdm_ras_des_einj4_updfc_type==3'b000);
 assign einj4_nh_en = cdm_ras_des_einj4_enable & (cfg_struc_vc_id==cdm_ras_des_einj4_vcnum) & (cdm_ras_des_einj4_updfc_type==3'b001);
 assign einj4_ch_en = cdm_ras_des_einj4_enable & (cfg_struc_vc_id==cdm_ras_des_einj4_vcnum) & (cdm_ras_des_einj4_updfc_type==3'b010);
 assign einj4_pd_en = cdm_ras_des_einj4_enable & (cfg_struc_vc_id==cdm_ras_des_einj4_vcnum) & (cdm_ras_des_einj4_updfc_type==3'b100);
 assign einj4_nd_en = cdm_ras_des_einj4_enable & (cfg_struc_vc_id==cdm_ras_des_einj4_vcnum) & (cdm_ras_des_einj4_updfc_type==3'b101);
 assign einj4_cd_en = cdm_ras_des_einj4_enable & (cfg_struc_vc_id==cdm_ras_des_einj4_vcnum) & (cdm_ras_des_einj4_updfc_type==3'b110);


//reduce down the flow control data based on the scale factor
wire [11:0] red_rtfcgen_ca_pd;
wire [11:0] red_rtfcgen_ca_npd;
wire [11:0] red_rtfcgen_ca_cpld;
wire [7:0]  red_rtfcgen_ca_ph;
wire [7:0]  red_rtfcgen_ca_nph;
wire [7:0]  red_rtfcgen_ca_cplh;

//reduce from 12 bit to 8 bit for header
assign red_rtfcgen_ca_ph   = (fc_scaled_en && hdr_scale_p    == 2'b11)? rtfcgen_ca_ph  [11:4] : (fc_scaled_en && hdr_scale_p    == 2'b10)? rtfcgen_ca_ph  [9:2]  : (flit_mode_en)? {rtfcgen_ca_ph   [7:2],2'b0} : rtfcgen_ca_ph  [7:0];
assign red_rtfcgen_ca_nph  = (fc_scaled_en && hdr_scale_np   == 2'b11)? rtfcgen_ca_nph [11:4] : (fc_scaled_en && hdr_scale_np   == 2'b10)? rtfcgen_ca_nph [9:2]  : (flit_mode_en)? {rtfcgen_ca_nph  [7:2],2'b0} : rtfcgen_ca_nph [7:0];
assign red_rtfcgen_ca_cplh = (fc_scaled_en && hdr_scale_cpl  == 2'b11)? rtfcgen_ca_cplh[11:4] : (fc_scaled_en && hdr_scale_cpl  == 2'b10)? rtfcgen_ca_cplh[9:2]  : (flit_mode_en)? {rtfcgen_ca_cplh [7:2],2'b0} : rtfcgen_ca_cplh[7:0];
//reduce from 16 bit to 11 bit for data
assign red_rtfcgen_ca_pd   = (fc_scaled_en && data_scale_p   == 2'b11)? rtfcgen_ca_pd  [15:4] : (fc_scaled_en && data_scale_p   == 2'b10)? rtfcgen_ca_pd  [13:2] : (flit_mode_en)? {rtfcgen_ca_pd  [11:2],2'b0} : rtfcgen_ca_pd  [11:0];
assign red_rtfcgen_ca_npd  = (fc_scaled_en && data_scale_np  == 2'b11)? rtfcgen_ca_npd [15:4] : (fc_scaled_en && data_scale_np  == 2'b10)? rtfcgen_ca_npd [13:2] : (flit_mode_en)? {rtfcgen_ca_npd [11:2],2'b0} : rtfcgen_ca_npd [11:0];
assign red_rtfcgen_ca_cpld = (fc_scaled_en && data_scale_cpl == 2'b11)? rtfcgen_ca_cpld[15:4] : (fc_scaled_en && data_scale_cpl == 2'b10)? rtfcgen_ca_cpld[13:2] : (flit_mode_en)? {rtfcgen_ca_cpld[11:2],2'b0} : rtfcgen_ca_cpld[11:0];

//The scaling values need to change to zero if the link partner does not support scaling.
wire [1:0] int_hdr_scale_p, int_hdr_scale_np, int_hdr_scale_cpl;
wire [1:0] int_data_scale_p, int_data_scale_np, int_data_scale_cpl;

assign int_hdr_scale_p    = ((rdlh_rtlh_link_state == `S_DL_ACTIVE) && !fc_scaled_en) ? 2'b00 : hdr_scale_p;
assign int_hdr_scale_np   = ((rdlh_rtlh_link_state == `S_DL_ACTIVE) && !fc_scaled_en) ? 2'b00 : hdr_scale_np;
assign int_hdr_scale_cpl  = ((rdlh_rtlh_link_state == `S_DL_ACTIVE) && !fc_scaled_en) ? 2'b00 : hdr_scale_cpl;
assign int_data_scale_p   = ((rdlh_rtlh_link_state == `S_DL_ACTIVE) && !fc_scaled_en) ? 2'b00 : data_scale_p;
assign int_data_scale_np  = ((rdlh_rtlh_link_state == `S_DL_ACTIVE) && !fc_scaled_en) ? 2'b00 : data_scale_np;
assign int_data_scale_cpl = ((rdlh_rtlh_link_state == `S_DL_ACTIVE) && !fc_scaled_en) ? 2'b00 : data_scale_cpl;


wire    [31:0]          fcu_p_data;
assign fcu_p_data   = (flit_mode_en)? {red_rtfcgen_ca_pd[7:0], red_rtfcgen_ca_ph[1:0], int_data_scale_p, red_rtfcgen_ca_pd[11:8], int_hdr_scale_p, red_rtfcgen_ca_ph[7:2], `UPDFC_P_SHRD, cfg_vc_id}:
                                      {red_rtfcgen_ca_pd[7:0], red_rtfcgen_ca_ph[1:0], int_data_scale_p, red_rtfcgen_ca_pd[11:8], int_hdr_scale_p, red_rtfcgen_ca_ph[7:2], `UPDFC_P,      cfg_vc_id};
wire    [31:0]          fcu_np_data;
assign fcu_np_data  = (flit_mode_en)? {red_rtfcgen_ca_npd[7:0], red_rtfcgen_ca_nph[1:0], int_data_scale_np, red_rtfcgen_ca_npd[11:8], int_hdr_scale_np, red_rtfcgen_ca_nph[7:2], `UPDFC_NP_SHRD, cfg_vc_id}:
                                      {red_rtfcgen_ca_npd[7:0], red_rtfcgen_ca_nph[1:0], int_data_scale_np, red_rtfcgen_ca_npd[11:8], int_hdr_scale_np, red_rtfcgen_ca_nph[7:2], `UPDFC_NP,      cfg_vc_id};
wire    [31:0]          fcu_cpl_data;
assign fcu_cpl_data = (flit_mode_en)? {red_rtfcgen_ca_cpld[7:0], red_rtfcgen_ca_cplh[1:0], int_data_scale_cpl, red_rtfcgen_ca_cpld[11:8], int_hdr_scale_cpl, red_rtfcgen_ca_cplh[7:2], `UPDFC_CPL_SHRD, cfg_vc_id}:
                                      {red_rtfcgen_ca_cpld[7:0], red_rtfcgen_ca_cplh[1:0], int_data_scale_cpl, red_rtfcgen_ca_cpld[11:8], int_hdr_scale_cpl, red_rtfcgen_ca_cplh[7:2], `UPDFC_CPL,      cfg_vc_id};

// -----------------------------------------------------------------------------
//
//  FC Control Generator State machine
//
// -----------------------------------------------------------------------------


// for debug purpose
reg pd_crd_not_rtn;
reg ph_crd_not_rtn;
reg npd_crd_not_rtn;
reg nph_crd_not_rtn;
reg cpld_crd_not_rtn;
reg cplh_crd_not_rtn;

wire rtlh_crd_not_rtn;
assign rtlh_crd_not_rtn = (pd_crd_not_rtn | ph_crd_not_rtn
                        | npd_crd_not_rtn | nph_crd_not_rtn
                        | cpld_crd_not_rtn | cplh_crd_not_rtn);


      always @(posedge core_clk or negedge core_rst_n)
          if(!core_rst_n)
              ph_crd_not_rtn  <= #TP 0;
          else if (rtfcgen_ca_ph > rtfcgen_cr_ph)
              ph_crd_not_rtn  <= #TP ((rtfcgen_ca_ph - rtfcgen_cr_ph) != exp_cfg_fc_credit_ph) & non_infinite_ph;
          else
              ph_crd_not_rtn  <= #TP ((rtfcgen_cr_ph - rtfcgen_ca_ph) 
 != 13'h1000

              - exp_cfg_fc_credit_ph) & non_infinite_ph;

      always @(posedge core_clk or negedge core_rst_n)
          if(!core_rst_n)
              pd_crd_not_rtn  <= #TP 0;
          else if (rtfcgen_ca_pd > rtfcgen_cr_pd)
              pd_crd_not_rtn  <= #TP ((rtfcgen_ca_pd - rtfcgen_cr_pd) != exp_cfg_fc_credit_pd) & non_infinite_p;
          else
              pd_crd_not_rtn  <= #TP ((rtfcgen_cr_pd - rtfcgen_ca_pd)
 != 17'h10000

              - exp_cfg_fc_credit_pd) &  non_infinite_p;

      always @(posedge core_clk or negedge core_rst_n)
          if(!core_rst_n)
              nph_crd_not_rtn <= #TP 0;
          else if (rtfcgen_ca_nph > rtfcgen_cr_nph)
              nph_crd_not_rtn <= #TP ((rtfcgen_ca_nph - rtfcgen_cr_nph) != exp_cfg_fc_credit_nph) & non_infinite_nph;
          else
              nph_crd_not_rtn <= #TP ((rtfcgen_cr_nph - rtfcgen_ca_nph)
 != 13'h1000

              - exp_cfg_fc_credit_nph) & non_infinite_nph;

      always @(posedge core_clk or negedge core_rst_n)
          if(!core_rst_n)
              npd_crd_not_rtn <= #TP 0;
          else if (rtfcgen_ca_npd > rtfcgen_cr_npd)
              npd_crd_not_rtn <= #TP ((rtfcgen_ca_npd - rtfcgen_cr_npd) != exp_cfg_fc_credit_npd) & non_infinite_np;
          else
              npd_crd_not_rtn <= #TP ((rtfcgen_cr_npd - rtfcgen_ca_npd)
 != 17'h10000

              - exp_cfg_fc_credit_npd) & non_infinite_np;

      always @(posedge core_clk or negedge core_rst_n)
          if(!core_rst_n)
              cplh_crd_not_rtn    <= #TP 0;
          else if (rtfcgen_ca_cplh > rtfcgen_cr_cplh)
              cplh_crd_not_rtn    <= #TP ((rtfcgen_ca_cplh - rtfcgen_cr_cplh) != exp_cfg_fc_credit_cplh) & non_infinite_cplh;
          else
              cplh_crd_not_rtn    <= #TP ((rtfcgen_cr_cplh - rtfcgen_ca_cplh) 
 != 13'h1000

              - exp_cfg_fc_credit_cplh) & non_infinite_cplh;

      always @(posedge core_clk or negedge core_rst_n)
          if(!core_rst_n)
              cpld_crd_not_rtn    <= #TP 0;
          else if (rtfcgen_ca_cpld > rtfcgen_cr_cpld)
              cpld_crd_not_rtn    <= #TP ((rtfcgen_ca_cpld - rtfcgen_cr_cpld) != exp_cfg_fc_credit_cpld) & non_infinite_cpl;
          else
              cpld_crd_not_rtn    <= #TP ((rtfcgen_cr_cpld - rtfcgen_ca_cpld) 
 != 17'h10000

              - exp_cfg_fc_credit_cpld) & non_infinite_cpl;


// assign the request to hi if there is a timeout.  The timeout update
// has to go out and should not be blocked by another VC init.
always @(*) begin : p_np_cpl_priority
    rtfcgen_fc_p_req_hi   = 0;
    rtfcgen_fc_np_req_hi  = 0;
    rtfcgen_fc_cpl_req_hi = 0;
        if (p_fcupdt_req) begin
           rtfcgen_fc_p_req_hi   = p_timeout_30us || recovery_from_exhaustion_p || recovery_from_insufficiency_p;
        end if (np_fcupdt_req) begin
           rtfcgen_fc_np_req_hi   = np_timeout_30us || recovery_from_exhaustion_np;
        end if (cpl_fcupdt_req) begin
           rtfcgen_fc_cpl_req_hi   = cpl_timeout_30us || recovery_from_exhaustion_cpl || recovery_from_insufficiency_cpl;
        end
end


reg priority_p; // toggles priority between P and NP

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        priority_p    <= #TP 0;
    end else if (rtfcarb_ack) begin
        priority_p    <= #TP ~priority_p;
    end

// P and NP alternate priority dependent on Non-Posted FC update request signal
// CPL has lowest priority
// high priority escalation supersedes any low priority
// if all high priority, then P and NP alternate priority
// CPL has lowest high priority
assign fcupdt_done_p   = !rtfcgen_fc_req &&  ((p_fcupdt_req && (!np_fcupdt_req || priority_p) && !rtfcgen_fc_np_req_hi) || rtfcgen_fc_p_req_hi) // P Low Priority
                            && (rtfcgen_fc_p_req_hi || !rtfcgen_fc_cpl_req_hi) && (priority_p || !rtfcgen_fc_np_req_hi);                        // P High Priority
assign fcupdt_done_np  = !rtfcgen_fc_req && ((np_fcupdt_req && (!p_fcupdt_req || !priority_p) && !rtfcgen_fc_p_req_hi) || rtfcgen_fc_np_req_hi) // NP Low Priority
                            && (rtfcgen_fc_np_req_hi || !rtfcgen_fc_cpl_req_hi) && !(priority_p && rtfcgen_fc_p_req_hi);                        // NP High Priority
assign fcupdt_done_cpl = !rtfcgen_fc_req && (cpl_fcupdt_req && (rtfcgen_fc_cpl_req_hi || (!send_latency_p && !send_latency_np)))                // CPL Low Priority
                            && !rtfcgen_fc_p_req_hi && !rtfcgen_fc_np_req_hi;                                                                   // CPL High Priority


always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        rtfcgen_fc_req      <= #TP 0;
        rtfcgen_fc_data     <= #TP 0;
        rtfcgen_fc_req_hi   <= #TP 0;
    end else if (tmp_link_down | !cfg_vc_enable) begin // Ensures FC output requests are reset when Link down or VC is disabled
        rtfcgen_fc_req      <= #TP 0;
        rtfcgen_fc_data     <= #TP 0;
        rtfcgen_fc_req_hi   <= #TP 0;
    end else begin
        if (!rtfcgen_fc_req)
           rtfcgen_fc_req      <= #TP int_fcupdt_req;
        else if (rtfcarb_ack)
           rtfcgen_fc_req      <= #TP 1'b0;

        if (fcupdt_done_p) begin
           rtfcgen_fc_data     <= #TP fcu_p_data;
        end else if (fcupdt_done_np) begin
           rtfcgen_fc_data     <= #TP fcu_np_data;
        end else if (fcupdt_done_cpl) begin
           rtfcgen_fc_data     <= #TP fcu_cpl_data;
        end

        if (p_fcupdt_req) begin
           rtfcgen_fc_req_hi   <= #TP p_timeout_30us || recovery_from_exhaustion_p || recovery_from_insufficiency_p;
        end else if (np_fcupdt_req) begin
           rtfcgen_fc_req_hi   <= #TP np_timeout_30us || recovery_from_exhaustion_np;
        end else if (cpl_fcupdt_req) begin
           rtfcgen_fc_req_hi   <= #TP cpl_timeout_30us || recovery_from_exhaustion_cpl || recovery_from_insufficiency_cpl;
        end else begin
           rtfcgen_fc_req_hi   <= #TP 0;
        end
    end

 assign p_req_evt = !tmp_link_down && fcupdt_done_p;
 assign n_req_evt = !tmp_link_down && fcupdt_done_np;
 assign c_req_evt = !tmp_link_down && fcupdt_done_cpl;
 assign rtlh_einj4_fc_evt = ( (einj4_ph_en|einj4_pd_en) & p_req_evt )
                          | ( (einj4_nh_en|einj4_nd_en) & n_req_evt )
                          | ( (einj4_ch_en|einj4_cd_en) & c_req_evt )
                          ;


// Handle credit initializing/incrementing
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        rtfcgen_ca_pd_org   <= #TP 0;
        rtfcgen_ca_npd_org  <= #TP 0;
        rtfcgen_ca_cpld_org <= #TP 0;
        rtfcgen_ca_ph_org   <= #TP 0;
        rtfcgen_ca_nph_org  <= #TP 0;
        rtfcgen_ca_cplh_org <= #TP 0;
// Ensure FC Credit is reset when Link down or VC is disabled
    end else if (tmp_link_down | !cfg_vc_enable) begin
        rtfcgen_ca_ph_org   <= #TP exp_cfg_fc_credit_ph;
        rtfcgen_ca_nph_org  <= #TP exp_cfg_fc_credit_nph;
        rtfcgen_ca_cplh_org <= #TP exp_cfg_fc_credit_cplh;
        rtfcgen_ca_pd_org   <= #TP exp_cfg_fc_credit_pd;
        rtfcgen_ca_npd_org  <= #TP exp_cfg_fc_credit_npd;
        rtfcgen_ca_cpld_org <= #TP exp_cfg_fc_credit_cpld;
    end else begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. rtfcgen_ca_* counters are intended to
// wrap without preseveration of carry/borrow
        rtfcgen_ca_ph_org   <= #TP rtfcgen_ca_ph_org   + (non_infinite_ph ? radm_rtlh_ph_ca : 0);
        rtfcgen_ca_nph_org  <= #TP rtfcgen_ca_nph_org  + (non_infinite_nph ? radm_rtlh_nph_ca : 0);
        rtfcgen_ca_cplh_org <= #TP rtfcgen_ca_cplh_org + (non_infinite_cplh ? radm_rtlh_cplh_ca : 0);
        rtfcgen_ca_pd_org   <= #TP rtfcgen_ca_pd_org   + (non_infinite_p ? radm_rtlh_pd_ca : 0);
        rtfcgen_ca_npd_org  <= #TP rtfcgen_ca_npd_org  + (non_infinite_np ? radm_rtlh_npd_ca  : 0);
        rtfcgen_ca_cpld_org <= #TP rtfcgen_ca_cpld_org + (non_infinite_cpl ? radm_rtlh_cpld_ca : 0);
// spyglass enable_block W164a
    end

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. rtfcgen_ca_* counters are intended to
// wrap without preseveration of carry/borrow
 assign rtfcgen_ca_pd   = einj4_pd_en ? rtfcgen_ca_pd_org   + cdm_ras_des_einj4_badfc_value[11:0] : rtfcgen_ca_pd_org;
 assign rtfcgen_ca_npd  = einj4_nd_en ? rtfcgen_ca_npd_org  + cdm_ras_des_einj4_badfc_value[11:0] : rtfcgen_ca_npd_org;
 assign rtfcgen_ca_cpld = einj4_cd_en ? rtfcgen_ca_cpld_org + cdm_ras_des_einj4_badfc_value[11:0] : rtfcgen_ca_cpld_org;
 assign rtfcgen_ca_ph   = einj4_ph_en ? rtfcgen_ca_ph_org   + cdm_ras_des_einj4_badfc_value[7:0] : rtfcgen_ca_ph_org;
 assign rtfcgen_ca_nph  = einj4_nh_en ? rtfcgen_ca_nph_org  + cdm_ras_des_einj4_badfc_value[7:0] : rtfcgen_ca_nph_org;
 assign rtfcgen_ca_cplh = einj4_ch_en ? rtfcgen_ca_cplh_org + cdm_ras_des_einj4_badfc_value[7:0] : rtfcgen_ca_cplh_org;
 // spyglass enable_block W164a

// latch the ca increment assertion to qualify the fc generate condition
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        clked_radm_ca_p     <= #TP 0;
        clked_radm_ca_np    <= #TP 0;
        clked_radm_ca_cpl   <= #TP 0;
    end else begin
        clked_radm_ca_p     <= #TP |radm_rtlh_pd_ca || (|radm_rtlh_ph_ca);
        clked_radm_ca_np    <= #TP |radm_rtlh_npd_ca || (|radm_rtlh_nph_ca);
        clked_radm_ca_cpl   <= #TP |radm_rtlh_cpld_ca || (|radm_rtlh_cplh_ca);
    end

//-----------------------------------------------------------------------------

typedef enum logic [1:0] {
    P   = 2'b00, // Posted
    NP  = 2'b01, // Non-Posted
    CPL = 2'b10  // Completion
} type_t;

typedef struct packed {
    reg     [3:0]   cr_h; // 4 bits to accomodate maximum 8 increments in 1024b cores
    reg     [9:0]   cr_d; // 10 bits to accomodate a MPS increment (9bits) + maximum 7 further Data credits in 1024b cores
} incr_t;

typedef struct packed {
    reg     [HCRD_WD-1:0]   cr_h;
    reg     [DCRD_WD-1:0]   cr_d;
    reg                     cr_ok;
} incr_chkd_t;

// Precalculate all the possible combinations of increments.
// This logic does not consider if it is a real increment for the current FC/VC.
localparam NCOMB = 1<<RX_TLP; // Number of possible combinations 2^TX_TLP.
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: cr_d 10 bits are sufficient to accomodate a MPS increment (9bits) + maximum 7 further Data credits in 1024b cores
incr_t [NCOMB-1:0] i_raw_incr;
always @(*) begin : tmp_credits
    for ( int i=0; i<NCOMB; i++) begin
        i_raw_incr[i].cr_h  = 0;
        i_raw_incr[i].cr_d  = 0;
        for ( int j=0; j<RX_TLP; j++) begin
            if (|(i&(1<<j))) begin
                i_raw_incr[i].cr_h = i_raw_incr[i].cr_h + 4'b1;
                i_raw_incr[i].cr_d = i_raw_incr[i].cr_d + {1'b0, rtcheck_rtfcgen_incr_amt[9*j +: 9]};
            end
        end
    end
end
// spyglass enable_block W164a

// Map valid increments (rtcheck_rtfcgen_incr_enable) for the current VC (rtcheck_rtfcgen_vc) 
// into a per FC type increment enable vector (depending on rtcheck_rtfcgen_fctype)
reg [RX_TLP-1:0] i_raw_p_incr_en;
reg [RX_TLP-1:0] i_raw_np_incr_en;
reg [RX_TLP-1:0] i_raw_cpl_incr_en;
always @(*) begin : tmp_increment_enabled
    for (int i=0; i<RX_TLP; i++) begin
        i_raw_p_incr_en[i]   = rtcheck_rtfcgen_incr_enable[i] & rtcheck_rtfcgen_fctype[2*i +: 2] == P   & rtcheck_rtfcgen_vc[3*i +: 3] == cfg_struc_vc_id;
        i_raw_np_incr_en[i]  = rtcheck_rtfcgen_incr_enable[i] & rtcheck_rtfcgen_fctype[2*i +: 2] == NP  & rtcheck_rtfcgen_vc[3*i +: 3] == cfg_struc_vc_id;
        i_raw_cpl_incr_en[i] = rtcheck_rtfcgen_incr_enable[i] & rtcheck_rtfcgen_fctype[2*i +: 2] == CPL & rtcheck_rtfcgen_vc[3*i +: 3] == cfg_struc_vc_id;
    end
end

// Simplified Credit Calculation
// The following logic checks if credits are available for all the TLPs of the same FC/VC ending in the current cycle.
// As a result, same VC/FC TLPs are all accepted/discarded according to their cumulative amount of credit reqired availability.

import pcie_pkg::E_P;
import pcie_pkg::E_NP;
import pcie_pkg::E_CPL;

incr_t            raw_p_incr,    raw_np_incr,    raw_cpl_incr;
wire [RX_TLP-1:0] raw_p_incr_en, raw_np_incr_en, raw_cpl_incr_en;

assign raw_p_incr      = i_raw_incr[i_raw_p_incr_en];
assign raw_np_incr     = i_raw_incr[i_raw_np_incr_en];
assign raw_cpl_incr    = i_raw_incr[i_raw_cpl_incr_en];
assign raw_p_incr_en   = i_raw_p_incr_en;
assign raw_np_incr_en  = i_raw_np_incr_en;
assign raw_cpl_incr_en = i_raw_cpl_incr_en;

// Figure out if the increment would be legal credit-wise (i.e. enought credits).
// And calculate what would be the next rtfcgen_cr_*
incr_chkd_t [2:0] raw_incr_chkd;
assign raw_incr_chkd[P  ] = check_incr(raw_p_incr.cr_h,   raw_p_incr.cr_d,   rtfcgen_cr_ph,   rtfcgen_cr_pd,   rtfcgen_ph_diff,   rtfcgen_pd_diff,   !non_infinite_ph,   !non_infinite_p);
assign raw_incr_chkd[NP ] = check_incr(raw_np_incr.cr_h,  raw_np_incr.cr_d,  rtfcgen_cr_nph,  rtfcgen_cr_npd,  rtfcgen_nph_diff,  rtfcgen_npd_diff,  !non_infinite_nph,  !non_infinite_np);
assign raw_incr_chkd[CPL] = check_incr(raw_cpl_incr.cr_h, raw_cpl_incr.cr_d, rtfcgen_cr_cplh, rtfcgen_cr_cpld, rtfcgen_cplh_diff, rtfcgen_cpld_diff, !non_infinite_cplh, !non_infinite_cpl);

// Accept all or none increments for same FC/VC type according to their cumulative credits availability. 
reg [RX_TLP-1:0] curr_p_incr;
reg [RX_TLP-1:0] curr_np_incr;
reg [RX_TLP-1:0] curr_cpl_incr;
assign curr_p_incr   = raw_p_incr_en   & {RX_TLP{raw_incr_chkd[P  ].cr_ok}};
assign curr_np_incr  = raw_np_incr_en  & {RX_TLP{raw_incr_chkd[NP ].cr_ok}};
assign curr_cpl_incr = raw_cpl_incr_en & {RX_TLP{raw_incr_chkd[CPL].cr_ok}};

// Update next credit counters if increments are allowed
wire [DCRD_WD-1:0] next_cr_pd;             // Payload(data) credits received (posted, non-posted, completion)
wire [DCRD_WD-1:0] next_cr_npd;
wire [DCRD_WD-1:0] next_cr_cpld;
wire [HCRD_WD-1:0] next_cr_ph;             // Header credits received (posted, non-posted, completion)
wire [HCRD_WD-1:0] next_cr_nph;
wire [HCRD_WD-1:0] next_cr_cplh;
assign next_cr_ph   = (raw_incr_chkd[P  ].cr_ok)? raw_incr_chkd[P  ].cr_h : rtfcgen_cr_ph  ;
assign next_cr_pd   = (raw_incr_chkd[P  ].cr_ok)? raw_incr_chkd[P  ].cr_d : rtfcgen_cr_pd  ;
assign next_cr_nph  = (raw_incr_chkd[NP ].cr_ok)? raw_incr_chkd[NP ].cr_h : rtfcgen_cr_nph ;
assign next_cr_npd  = (raw_incr_chkd[NP ].cr_ok)? raw_incr_chkd[NP ].cr_d : rtfcgen_cr_npd ;
assign next_cr_cplh = (raw_incr_chkd[CPL].cr_ok)? raw_incr_chkd[CPL].cr_h : rtfcgen_cr_cplh;
assign next_cr_cpld = (raw_incr_chkd[CPL].cr_ok)? raw_incr_chkd[CPL].cr_d : rtfcgen_cr_cpld;


// When an increment is not allowed because of credit insufficiency, flag an overflow error
wire [RX_TLP-1:0] incr_p_err;
wire [RX_TLP-1:0] incr_np_err;
wire [RX_TLP-1:0] incr_cpl_err;
wire [RX_TLP-1:0] overfl_err;
assign incr_p_err   = raw_p_incr_en   & ~curr_p_incr;
assign incr_np_err  = raw_np_incr_en  & ~curr_np_incr;
assign incr_cpl_err = raw_cpl_incr_en & ~curr_cpl_incr;
assign overfl_err = incr_p_err | incr_np_err | incr_cpl_err;

// Figure out if the increment would be legal credit-wise (i.e. enought credits).
// And calculate what would be the next rtfcgen_cr_*
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. data_credits are intended to
// wrap without preseveration of carry/borrow
function automatic incr_chkd_t check_incr;
    input logic [3:0]         raw_incr_cr_h; // Passing raw_incr.cr_h/cr_d separately instead of passing
    input logic [9:0]         raw_incr_cr_d; //   the struct to workaround spyglass limitation
    input logic [HCRD_WD-1:0] rtfcgen_cr_h;
    input logic [DCRD_WD-1:0] rtfcgen_cr_d;
    input logic [HCRD_WD-1:0] rtfcgen_h_diff;
    input logic [DCRD_WD-1:0] rtfcgen_d_diff;
    input logic               infinite_h;
    input logic               infinite_d;
begin
    check_incr.cr_h  = rtfcgen_cr_h + raw_incr_cr_h;
    check_incr.cr_d  = rtfcgen_cr_d + raw_incr_cr_d;
    check_incr.cr_ok = (infinite_h || rtfcgen_h_diff >= {{HCRD_WD-4 {1'b0}}, raw_incr_cr_h} ) &&
                       (infinite_d || rtfcgen_d_diff >= {{DCRD_WD-10{1'b0}}, raw_incr_cr_d} ) ;
end
endfunction
// spyglass enable_block W164a

//-----------------------------------------------------------------------------

// Update credits received -- each time header and data is given to the RADM
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        rtfcgen_cr_pd   <= #TP 0;
        rtfcgen_cr_npd  <= #TP 0;
        rtfcgen_cr_cpld <= #TP 0;
        rtfcgen_cr_ph   <= #TP 0;
        rtfcgen_cr_nph  <= #TP 0;
        rtfcgen_cr_cplh <= #TP 0;
    end else if(tmp_link_down | !cfg_vc_enable) begin
        rtfcgen_cr_pd   <= #TP 0;
        rtfcgen_cr_npd  <= #TP 0;
        rtfcgen_cr_cpld <= #TP 0;
        rtfcgen_cr_ph   <= #TP 0;
        rtfcgen_cr_nph  <= #TP 0;
        rtfcgen_cr_cplh <= #TP 0;
    end else begin
        // Posted
        rtfcgen_cr_ph   <= #TP next_cr_ph;
        rtfcgen_cr_pd   <= #TP next_cr_pd;
            // Non-Posted
        rtfcgen_cr_nph  <= #TP next_cr_nph;
        rtfcgen_cr_npd  <= #TP next_cr_npd;
        // Completion
        rtfcgen_cr_cplh <= #TP next_cr_cplh;
        rtfcgen_cr_cpld <= #TP next_cr_cpld;
    end


// When it is not reqular time out, it will require priority high
assign p_fcupdt_req     = ((non_infinite_p | non_infinite_ph)
                            & (p_timeout_30us | recovery_from_exhaustion_p
                                 | recovery_from_insufficiency_p | send_latency_p));

assign np_fcupdt_req    = ((non_infinite_np | non_infinite_nph)
                            & (np_timeout_30us | recovery_from_exhaustion_np
                                 | send_latency_np));

assign cpl_fcupdt_req   = ((non_infinite_cpl | non_infinite_cplh)
                            & (cpl_timeout_30us | recovery_from_exhaustion_cpl
                                | recovery_from_insufficiency_cpl | send_latency_cpl));

// transmission

assign int_fcupdt_req   = p_fcupdt_req | np_fcupdt_req | cpl_fcupdt_req;


reg [DCRD_WD-1:0]  int_max_plyd_cr;

always @(cfg_max_payload)
    case (cfg_max_payload)
    3'b000: // 128bytes
        int_max_plyd_cr = 'h008;
    3'b001: // 256bytes
        int_max_plyd_cr = 'h010;
    3'b010: // 512bytes
        int_max_plyd_cr = 'h020;
    3'b011: // 1024bytes
        int_max_plyd_cr = 'h040;
    3'b100: // 2048bytes
        int_max_plyd_cr = 'h080;
    3'b101: // 4096bytes
        int_max_plyd_cr = 'h100;
    default:
        int_max_plyd_cr = 'h010;
    endcase

// Determine when to update credits
// conditions that determines an update
// 1. timer expired 30us after we have sent the last 3 FC packet for P,NP and CPL FC update.
//    this timer runs independently from any necessary update of FC packet
//    This is designed to save 3 timers needed to do individual timeout
//    The penalty for this is that we have a bit more freqently FC update than minimum specified.
// 2. when NPH, NPD, PH, CPLH credits are consumed completely
// 3. when one or more of NPH, NPD, PH and CPLH credits are returned
// 3. when PD, CPLD can not receive the Max payload pkt and a credit has been made available.

wire    [1:0]   rtfcgen_fc_data_type;
wire    [11:0]  rtfcgen_fc_data_dc;
wire    [7:0]   rtfcgen_fc_data_hc;
wire            rtfcgen_fc_sent_p;
wire            rtfcgen_fc_sent_np;
wire            rtfcgen_fc_sent_cpl;

reg     [DCRD_WD-1:0]  rtfcgen_ca_advert_pd;
reg     [DCRD_WD-1:0]  rtfcgen_ca_advert_npd;
reg     [DCRD_WD-1:0]  rtfcgen_ca_advert_cpld;
reg     [HCRD_WD-1:0]  rtfcgen_ca_advert_ph;
reg     [HCRD_WD-1:0]  rtfcgen_ca_advert_nph;
reg     [HCRD_WD-1:0]  rtfcgen_ca_advert_cplh;

wire    [DCRD_WD-1:0]  rtfcgen_pd_diff_int;
wire    [DCRD_WD-1:0]  rtfcgen_npd_diff_int;
wire    [DCRD_WD-1:0]  rtfcgen_cpld_diff_int;
wire    [HCRD_WD-1:0]  rtfcgen_ph_diff_int;
wire    [HCRD_WD-1:0]  rtfcgen_nph_diff_int;
wire    [HCRD_WD-1:0]  rtfcgen_cplh_diff_int;

assign rtfcgen_fc_data_type    = rtfcgen_fc_data[5:4];
assign rtfcgen_fc_data_dc      = {rtfcgen_fc_data[19:16], rtfcgen_fc_data[31:24]};
assign rtfcgen_fc_data_hc      = {rtfcgen_fc_data[13: 8], rtfcgen_fc_data[23:22]};

assign rtfcgen_fc_sent_p       = (rtfcarb_ack & (rtfcgen_fc_data_type == 2'b0));
assign rtfcgen_fc_sent_np      = (rtfcarb_ack & (rtfcgen_fc_data_type == 2'b01));
assign rtfcgen_fc_sent_cpl     = (rtfcarb_ack & (rtfcgen_fc_data_type == 2'b10));

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Timer counters are intended to
// wrap without preseveration of carry/borrow
assign rtfcgen_pd_diff_int     = (rtfcgen_ca_advert_pd   - rtfcgen_cr_pd);
assign rtfcgen_npd_diff_int    = (rtfcgen_ca_advert_npd  - rtfcgen_cr_npd);
assign rtfcgen_cpld_diff_int   = (rtfcgen_ca_advert_cpld - rtfcgen_cr_cpld);
                            
assign rtfcgen_ph_diff_int     = (rtfcgen_ca_advert_ph   - rtfcgen_cr_ph);
assign rtfcgen_nph_diff_int    = (rtfcgen_ca_advert_nph  - rtfcgen_cr_nph);
assign rtfcgen_cplh_diff_int   = (rtfcgen_ca_advert_cplh - rtfcgen_cr_cplh);
//need to account for FC updates after modulo field size rollover
assign rtfcgen_pd_diff   = (fc_scaled_en && data_scale_p == 2'b11) ? rtfcgen_pd_diff_int : (fc_scaled_en && data_scale_p == 2'b10) ? {2'b0, rtfcgen_pd_diff_int[13:0]} : {4'b0, rtfcgen_pd_diff_int[11:0]};
assign rtfcgen_npd_diff  = (fc_scaled_en && data_scale_np == 2'b11) ? rtfcgen_npd_diff_int : (fc_scaled_en && data_scale_np == 2'b10) ? {2'b0, rtfcgen_npd_diff_int[13:0]} : {4'b0, rtfcgen_npd_diff_int[11:0]};
assign rtfcgen_cpld_diff = (fc_scaled_en && data_scale_cpl == 2'b11) ? rtfcgen_cpld_diff_int : (fc_scaled_en && data_scale_cpl == 2'b10) ? {2'b0, rtfcgen_cpld_diff_int[13:0]} : {4'b0, rtfcgen_cpld_diff_int[11:0]};

assign rtfcgen_ph_diff   = (fc_scaled_en && hdr_scale_p == 2'b11) ? rtfcgen_ph_diff_int : (fc_scaled_en && hdr_scale_p == 2'b10) ? {2'b0, rtfcgen_ph_diff_int[9:0]} : {4'b0, rtfcgen_ph_diff_int[7:0]};
assign rtfcgen_nph_diff  = (fc_scaled_en && hdr_scale_np == 2'b11) ? rtfcgen_nph_diff_int : (fc_scaled_en && hdr_scale_np == 2'b10) ? {2'b0, rtfcgen_nph_diff_int[9:0]} : {4'b0, rtfcgen_nph_diff_int[7:0]};
assign rtfcgen_cplh_diff = (fc_scaled_en && hdr_scale_cpl == 2'b11) ? rtfcgen_cplh_diff_int : (fc_scaled_en && hdr_scale_cpl == 2'b10) ? {2'b0, rtfcgen_cplh_diff_int[9:0]} : {4'b0, rtfcgen_cplh_diff_int[7:0]};
// spyglass enable_block W164a
assign rtfcgen_rtcheck_overfl_err = overfl_err;

//
// FC timeout processes for 3 types
//
// credit of payload data is 16bytes per credit. therefore maxplyd required {cfg_max_payload,4'b0} credits.
// set condition has priority over clear condition
//
// Spec.1.1 required that all FC packet being sent when a L1 exit has happened.
reg smlh_in_l1_r;
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        smlh_in_l1_r  <= #TP 0;
    else
        smlh_in_l1_r  <= #TP smlh_in_l1;

wire ltssm_l1_exit;
assign ltssm_l1_exit = smlh_in_l1_r & (!smlh_in_l1);

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        p_timeout_30us  <= #TP 1'b0;
    else if ((fc_update_timer_expired | ltssm_l1_exit) & rtlh_fc_init_status)
        p_timeout_30us  <= #TP  1'b1;
    else if ((rtfcarb_ack & (rtfcgen_fc_data_type == 2'b00)) | !cfg_vc_enable)
        p_timeout_30us  <= #TP  1'b0;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        np_timeout_30us <= #TP 1'b0;
    else if ((fc_update_timer_expired | ltssm_l1_exit) & rtlh_fc_init_status)
        np_timeout_30us <= #TP 1'b1;
    else if ((rtfcarb_ack & (rtfcgen_fc_data_type == 2'b01)) | !cfg_vc_enable)
        np_timeout_30us <= #TP 1'b0;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        cpl_timeout_30us    <= #TP 1'b0;
    else if ((fc_update_timer_expired | ltssm_l1_exit) & rtlh_fc_init_status)
        cpl_timeout_30us    <= #TP 1'b1;
    else if ((rtfcarb_ack & (rtfcgen_fc_data_type == 2'b10)) | !cfg_vc_enable)
        cpl_timeout_30us    <= #TP 1'b0;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        total_cr_consumed_p     <= #TP 0;
        total_cr_consumed_np    <= #TP 0;
        total_cr_consumed_cpl   <= #TP 0;
    end else begin

        //
        // For non-infinite NPH, NPD, PH, and CPLH types, an UpdateFC FCP must be scheduled for
        // transmission each time the following sequence of events occurs:
        //       o  a) all advertised FC units for a particular type of credit are consumed by TLPs received, or
        //          b) the NPD credit drops below 2 and the Receiver supports AtomicOp routing capability or
        //          128b CAS Completer capability
        //       o  one or more units of that type are made available by TLPs processed
        //
        if (`CX_ATOMIC_ROUTING_EN || `CX_ATOMIC_128_CAS_EN)
          total_cr_consumed_np    <= #TP ((rtfcgen_nph_diff == 0) || (rtfcgen_npd_diff < 2));
        else
          total_cr_consumed_np    <= #TP ((rtfcgen_nph_diff == 0) || (rtfcgen_npd_diff == 0));
        total_cr_consumed_p     <= #TP (rtfcgen_ph_diff == 0);
        total_cr_consumed_cpl   <= #TP (rtfcgen_cplh_diff == 0);
    end

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        recovery_from_exhaustion_p      <= #TP 0;
    else if (clked_radm_ca_p )
        recovery_from_exhaustion_p      <= #TP  total_cr_consumed_p ;
    else if (fcupdt_done_p)
        recovery_from_exhaustion_p      <= #TP 0;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        recovery_from_exhaustion_np     <= #TP 0;
    else if (clked_radm_ca_np )
        recovery_from_exhaustion_np     <= #TP  total_cr_consumed_np ;
    else if (fcupdt_done_np)
        recovery_from_exhaustion_np     <= #TP 0;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        recovery_from_exhaustion_cpl    <= #TP 0;
    else if (clked_radm_ca_cpl )
        recovery_from_exhaustion_cpl    <= #TP total_cr_consumed_cpl ;
    else if (fcupdt_done_cpl)
        recovery_from_exhaustion_cpl    <= #TP 0;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        recovery_from_insufficiency_p   <= #TP 0;
    else if (clked_radm_ca_p)
        recovery_from_insufficiency_p   <= #TP (rtfcgen_pd_diff < int_max_plyd_cr);
    else if (fcupdt_done_p)
        recovery_from_insufficiency_p   <= #TP 0;

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n)
        recovery_from_insufficiency_cpl <= #TP 0;
    else if (clked_radm_ca_cpl)
        recovery_from_insufficiency_cpl <= #TP (rtfcgen_cpld_diff < int_max_plyd_cr);
    else if (fcupdt_done_cpl)
        recovery_from_insufficiency_cpl <= #TP 0;

// Capture the updates as we send them
always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        rtfcgen_ca_advert_pd    <= #TP `RADMQ_PDCRD;
        rtfcgen_ca_advert_ph    <= #TP `RADMQ_PHCRD;
    end else if (tmp_link_down | !cfg_vc_enable) begin
        rtfcgen_ca_advert_ph   <= #TP exp_cfg_fc_credit_ph;
        rtfcgen_ca_advert_pd   <= #TP exp_cfg_fc_credit_pd;
    end else if (rtfcgen_fc_sent_p) begin
        rtfcgen_ca_advert_ph    <= #TP (fc_scaled_en && hdr_scale_p == 2'b11) ? {rtfcgen_fc_data_hc, 4'b0} : (fc_scaled_en && hdr_scale_p == 2'b10) ? {2'b0, rtfcgen_fc_data_hc, 2'b0} : {4'b0, rtfcgen_fc_data_hc};
        rtfcgen_ca_advert_pd    <= #TP (fc_scaled_en && data_scale_p == 2'b11) ? {rtfcgen_fc_data_dc, 4'b0} : (fc_scaled_en && data_scale_p == 2'b10) ? {2'b0, rtfcgen_fc_data_dc, 2'b0} : {4'b0, rtfcgen_fc_data_dc};
    end

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        rtfcgen_ca_advert_npd   <= #TP `RADMQ_NPDCRD;
        rtfcgen_ca_advert_nph   <= #TP `RADMQ_NPHCRD;
    end else if (tmp_link_down | !cfg_vc_enable) begin
        rtfcgen_ca_advert_nph   <= #TP exp_cfg_fc_credit_nph;
        rtfcgen_ca_advert_npd   <= #TP exp_cfg_fc_credit_npd;
    end else if (rtfcgen_fc_sent_np) begin
        rtfcgen_ca_advert_nph   <= #TP (fc_scaled_en && hdr_scale_np == 2'b11) ? {rtfcgen_fc_data_hc, 4'b0} : (fc_scaled_en && hdr_scale_np == 2'b10) ? {2'b0, rtfcgen_fc_data_hc, 2'b0} : {4'b0, rtfcgen_fc_data_hc};
        rtfcgen_ca_advert_npd   <= #TP (fc_scaled_en && data_scale_np == 2'b11) ? {rtfcgen_fc_data_dc, 4'b0} : (fc_scaled_en && data_scale_np == 2'b10) ? {2'b0, rtfcgen_fc_data_dc, 2'b0} : {4'b0, rtfcgen_fc_data_dc};
    end

always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        rtfcgen_ca_advert_cpld  <= #TP `RADMQ_CPLDCRD;
        rtfcgen_ca_advert_cplh  <= #TP `RADMQ_CPLHCRD;
    end else if (tmp_link_down | !cfg_vc_enable) begin
        rtfcgen_ca_advert_cplh   <= #TP exp_cfg_fc_credit_cplh;
        rtfcgen_ca_advert_cpld   <= #TP exp_cfg_fc_credit_cpld;
    end else if (rtfcgen_fc_sent_cpl) begin
        rtfcgen_ca_advert_cplh   <= #TP (fc_scaled_en && hdr_scale_cpl == 2'b11) ? {rtfcgen_fc_data_hc, 4'b0} : (fc_scaled_en && hdr_scale_cpl == 2'b10) ? {2'b0, rtfcgen_fc_data_hc, 2'b0} : {4'b0, rtfcgen_fc_data_hc};
        rtfcgen_ca_advert_cpld   <= #TP (fc_scaled_en && data_scale_cpl == 2'b11) ? {rtfcgen_fc_data_dc, 4'b0} : (fc_scaled_en && data_scale_cpl == 2'b10) ? {2'b0, rtfcgen_fc_data_dc, 2'b0} : {4'b0, rtfcgen_fc_data_dc};
    end


// Credits are being returned by the application this cycle
wire   returning_p;
wire   returning_np;
wire   returning_cpl;
wire   or_need_update ;

assign returning_p     = |radm_rtlh_pd_ca   || (|radm_rtlh_ph_ca);
assign returning_np    = |radm_rtlh_npd_ca  || (|radm_rtlh_nph_ca);
assign returning_cpl   = |radm_rtlh_cpld_ca || (|radm_rtlh_cplh_ca);
assign or_need_update  = need_update_p | need_update_np | need_update_cpl;

// Change symbol timer to common module
wire       timer2;
DWC_pcie_symbol_timer
 u_gen_timer2
(
     .core_clk          (core_clk)
    ,.core_rst_n        (core_rst_n)
    ,.current_data_rate (current_data_rate)
    ,.cnt_up_en         (timer2)      // timer count-up
);


reg [12:0]  updatefc_latency_timer;
wire        fc_latency_timer_expired;

assign fc_latency_timer_expired = (updatefc_latency_timer < NB);

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        updatefc_latency_timer  <= #TP 0;
    else if (fc_latency_timer_expired | (!rtlh_fc_init_status) | !or_need_update)
        updatefc_latency_timer  <= #TP cfg_fc_latency_value;
    else if (!(pm_freeze_fc_timer | !or_need_update)) begin
        updatefc_latency_timer  <= #TP  updatefc_latency_timer - (timer2 ? NB : 0);
    end

// Set flags as latency timer expires
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        send_latency_p  <= #TP 0;
    else if (fc_latency_timer_expired & need_update_p)
        send_latency_p  <= #TP 1'b1;
    else if (fcupdt_done_p)
        send_latency_p  <= #TP 1'b0;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        send_latency_np <= #TP 0;
    else if (fc_latency_timer_expired & need_update_np)
        send_latency_np <= #TP 1'b1;
    else if (fcupdt_done_np)
        send_latency_np <= #TP 1'b0;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        send_latency_cpl    <= #TP 0;
    else if (fc_latency_timer_expired & need_update_cpl)
        send_latency_cpl    <= #TP 1'b1;
    else if (fcupdt_done_cpl)
        send_latency_cpl    <= #TP 1'b0;

// Keep track of any returned credits that have not yet been advertised
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        need_update_p   <= #TP 0;
    else if (returning_p)
        need_update_p   <= #TP 1'b1;
    else if (fcupdt_done_p)
        need_update_p   <= #TP 1'b0;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        need_update_np  <= #TP 0;
    else if (returning_np)
        need_update_np  <= #TP 1'b1;
    else if (fcupdt_done_np)
        need_update_np  <= #TP 1'b0;

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        need_update_cpl <= #TP 0;
    else if (returning_cpl)
        need_update_cpl <= #TP 1'b1;
    else if (fcupdt_done_cpl)
        need_update_cpl <= #TP 1'b0;


assign rtlh_fc_rcvd_ph      = non_infinite_ph   ? rtfcgen_cr_ph          : {HCRD_WD{1'h0}};
assign rtlh_fc_rcvd_pd      = non_infinite_p    ? rtfcgen_cr_pd          : {DCRD_WD{1'h0}};
assign rtlh_fc_rcvd_nph     = non_infinite_nph  ? rtfcgen_cr_nph         : {HCRD_WD{1'h0}};
assign rtlh_fc_rcvd_npd     = non_infinite_np   ? rtfcgen_cr_npd         : {DCRD_WD{1'h0}};
assign rtlh_fc_rcvd_cplh    = non_infinite_cplh ? rtfcgen_cr_cplh        : {HCRD_WD{1'h0}};
assign rtlh_fc_rcvd_cpld    = non_infinite_cpl  ? rtfcgen_cr_cpld        : {DCRD_WD{1'h0}};
assign rtlh_fc_allctd_ph    = non_infinite_ph   ? rtfcgen_ca_advert_ph   : {HCRD_WD{1'h0}};
assign rtlh_fc_allctd_pd    = non_infinite_p    ? rtfcgen_ca_advert_pd   : {DCRD_WD{1'h0}};
assign rtlh_fc_allctd_nph   = non_infinite_nph  ? rtfcgen_ca_advert_nph  : {HCRD_WD{1'h0}};
assign rtlh_fc_allctd_npd   = non_infinite_np   ? rtfcgen_ca_advert_npd  : {DCRD_WD{1'h0}};
assign rtlh_fc_allctd_cplh  = non_infinite_cplh ? rtfcgen_ca_advert_cplh : {HCRD_WD{1'h0}};
assign rtlh_fc_allctd_cpld  = non_infinite_cpl  ? rtfcgen_ca_advert_cpld : {DCRD_WD{1'h0}};


endmodule
