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
// ---    $Revision: #17 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/msg_gen.sv#17 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Module Description:
// --- Top level for internal TLP message generation
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

 
 module msg_gen  
(
// ---- inputs ---------------
    core_rst_n,
    core_clk,
    rdlh_link_up,
    pm_bus_num,
    pm_dev_num,
    cfg_pbus_num,
    cfg_pbus_dev_num,
    device_type,
    pm_xtlh_block_tlp,
    cfg_nond0_vdm_block,

    pm_asnak,
    pm_pme,
    pme_turn_off,
    pme_to_ack,

    unlock,
    idle_msg,
    obff_msg,
    cpu_active_msg,

    send_cor_err,
    send_nf_err,
    send_f_err,
    cfg_func_spec_err,

    inta_wire,
    intb_wire,
    intc_wire,
    intd_wire,
//    nhp_int,

    cfg_slot_pwr_limit_wr,
    set_slot_pwr_limit_val,
    set_slot_pwr_limit_scale,

    cfg_msi_addr,
    cfg_msi_data,
    cfg_msi_64,
    cfg_multi_msi_en,
//    hp_msi_request,
    cfg_bus_master_en,
    cfg_msix_en,
    msix_addr,
    msix_data,
    app_ltr_msg_req,
    app_ltr_msg_latency,
    app_ltr_msg_func_num,
    cdm2msgg_ltr_clr_msg_req,
    ven_msi_req,
    ven_msi_func_num,
    ven_msi_tc,
    ven_msi_vector,

    ven_msg_fmt,
    ven_msg_type,
    ven_msg_tc,
    ven_msg_td,
    ven_msg_ep,
    ven_msg_attr,
    ven_msg_len,
    ven_msg_func_num,
    ven_msg_tag,
    ven_msg_code,
    ven_msg_data,
    ven_msg_req,

    xadm_msg_halt,

    pm_dstate,
    app_req_retry_en,
    app_pf_req_retry_en,
    app_drs_ready,

    app_pf_frs_ready,

    cfg_rasdp_error_mode,
    ras_err_inj_en_array,
    ras_err_inj_mask,

    ptm_request_msg,
    ptm_res_msg,
    ptm_res_d_msg,
    ptm_master_time,
    ptm_prop_delay,
    cfg_auto_slot_pwr_lmt_dis,


// ---- outputs ---------------
    ras_err_inj_done,
    msg_gen_hv,
    msg_gen_dv,
    msg_gen_eot,
    msg_gen_hdr,
    msg_gen_data,
    app_obff_msg_grant,

    pf_frs_grant,

    app_ltr_msg_grant,
    msgg2cdm_ltr_clr_msg_grant,
    assert_inta_grt,
    assert_intb_grt,
    assert_intc_grt,
    assert_intd_grt,
    deassert_inta_grt,
    deassert_intb_grt,
    deassert_intc_grt,
    deassert_intd_grt,
    ven_msi_grant,
    ven_msg_grant,
    pme_to_ack_grt,
    pm_pme_grant,
    pme_turn_off_grt
    ,    
    pmstate_d3hot_to_d0
//    hp_msi_grant
    ,
    msg_gen_asnak_grt,
    msg_gen_unlock_grant

   , msggen_cdm_send_f_err
   , msggen_cdm_send_nf_err   

);

parameter INST          = 0;                        // The uniquifying parameter for each port logic instance.
parameter TP            = `TP;
parameter NF            = `CX_NFUNC;                // Number of functions implemented in this device
parameter MSI_NF        = `CX_MSI_NFUNC;            // Number of functions implemented for MSI
parameter PF_WD         = `CX_NFUNC_WD;             // number of bits needed to represent the pf number [0..NF-1], when this block is configured for sriov it is calculated as log2(NF), hardcoded to 3 otherwise
parameter ST_HDR        = `ST_HDR;
parameter NW            = `CX_NW;                   // Number of 32-bit dwords handled by the datapath each clock.
parameter DW            = (32*NW) + `TRGT_DATA_PROT_WD;  // Width of datapath in bits. Plus parity for the special function
parameter   HDR_PROT_WD          = 0  
                                   + `CX_RAS_PCIE_EXTENDED_HDR_PROT_WD //extended heade ecc/parity protection width
                                   ;
parameter BUSNUM_WD     = `CX_BUSNUM_WD;            // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter DEVNUM_WD     = `CX_DEVNUM_WD;            // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter ERROR_INJ_EN_WD    = `CX_RAS_ERROR_INJ_EN_WD;
parameter ERROR_INJ_MASK_WD  = `CX_RAS_ERROR_INJ_MASK_WD;

localparam ATTR_WD = `SF_HDR_TLP_ATTR;

localparam TAG_SIZE = `CX_TAG_SIZE;

input                   core_rst_n;
input                   core_clk;
input                   rdlh_link_up;               // Layer 2 link up
input   [BUSNUM_WD -1:0] pm_bus_num;
input   [DEVNUM_WD -1:0] pm_dev_num;
input   [BUSNUM_WD -1:0] cfg_pbus_num;
input   [DEVNUM_WD -1:0] cfg_pbus_dev_num;

input   [3:0]           device_type;                // Device type
input                   pm_xtlh_block_tlp;          // Block MSG & MSI.
input                   cfg_nond0_vdm_block;        // Block VDM.
// Power Management Message
input                   pm_asnak;                   // PM Active State NAK (downstream)
input   [NF-1:0]        pm_pme;                     // PM PME (upstream)
input                   pme_turn_off;               // PM Turn Off (broadcast downstream)
input   [NF-1:0]        pme_to_ack;                 // PM Turn Off ACK (upstream)
// Unlock Message (downstream)
input                   unlock;                     // Only for RC
// OBFF Messages, only for RC and SW downstream
input                   obff_msg;
input                   idle_msg;
input                   cpu_active_msg;
// Error report Message (upstream)
input   [NF-1:0]        send_cor_err;               // Correctable Error
input   [NF-1:0]        send_nf_err;                // Uncorrectable Non-Fatal Error
input   [NF-1:0]        send_f_err;                 // Uncorrectable Fatal Error
input   [(3*NF)-1:0]     cfg_func_spec_err;
// Interrupt Message
input                   inta_wire;                  // INTA
input                   intb_wire;                  // INTB
input                   intc_wire;                  // INTC
input                   intd_wire;                  // INTD
//input   [NF-1:0]        nhp_int;                    // from native hot plug logic - create an interrupt
// Slot Power Limit Message (downstream)
input                   cfg_slot_pwr_limit_wr;      // On a configuration write to the Slot Capabilities register of Downstream port
input   [7:0]           set_slot_pwr_limit_val;     // Slot Power Limit Value
input   [1:0]           set_slot_pwr_limit_scale;   // Slot Power Limit Scale

// Message Signaled Interrupt (MSI)
input   [(64*MSI_NF)-1:0]   cfg_msi_addr;               // MSI address
input   [(32*MSI_NF)-1:0]   cfg_msi_data;               // MSI data
input   [MSI_NF-1:0]        cfg_msi_64;                 // MSI is enabled for 64 bit addressing
input   [(3*MSI_NF)-1:0]    cfg_multi_msi_en;           // Multiple MSI Message
//input   [NF-1:0]        hp_msi_request;             // from native hot plug logic - create an MSI
input   [NF-1:0]        cfg_bus_master_en;          // Bus master enabled
// MSI-X
input   [NF-1:0]        cfg_msix_en;                // MSI-X enable
input   [63:0]          msix_addr;                  // MSI-X address
input   [31:0]          msix_data;                  // MSI-X data
    // From app

// SII: LTR Message Interface
input                   app_ltr_msg_req;            // LTR message request
input   [31:0]          app_ltr_msg_latency;        // LTR message latency
input   [PF_WD-1:0]     app_ltr_msg_func_num;       // LTR function number
input                   cdm2msgg_ltr_clr_msg_req;   // Internal LTR clear message request 

input                   ven_msi_req;                // MSI request
input   [PF_WD-1:0]     ven_msi_func_num;           // MSI Function number
input   [2:0]           ven_msi_tc;                 // MSI TC
input   [4:0]           ven_msi_vector;             // MSI vector

// Vendor Specified message
input   [1:0]           ven_msg_fmt;                // Vendor MSG fmt
input   [4:0]           ven_msg_type;               // Vendor MSG type
input   [2:0]           ven_msg_tc;                 // Vendor MSG traffic class
input                   ven_msg_td;                 // Vendor MSG TLP digest
input                   ven_msg_ep;                 // Vendor MSG EP bit
input   [ATTR_WD-1:0]   ven_msg_attr;               // Vendor MSG attribute
input   [9:0]           ven_msg_len;                // Vendor MSG length
input   [PF_WD-1:0]     ven_msg_func_num;           // Vendor MSG function number
input   [TAG_SIZE-1:0]  ven_msg_tag;                // Vendor MSG tag
input   [7:0]           ven_msg_code;               // Vendor MSG code
input   [63:0]          ven_msg_data;               // Vendor MSG data
input                   ven_msg_req;                // Vendor MSG xmt request

input                   xadm_msg_halt;              // TLP msg advance from XADM
input  [(3*NF)-1:0]     pm_dstate;         // PF Power Management D-state 

input                   app_req_retry_en;       // signal reused in the case of Readiness Notification on DRS, active low for DRS
input   [NF-1:0]        app_pf_req_retry_en;    // Allow application to enable LBC to return request retry status, per PF Function
input                   app_drs_ready;          // signal reused in the case of Readiness Notification on DRS, active low for DRS

input  [NF-1:0]         app_pf_frs_ready;      // Provides a capability to defer FRS messaging, initiated by Physical Functions when inactive.                                                    
input                   cfg_rasdp_error_mode;
input [ERROR_INJ_EN_WD  -1:0] ras_err_inj_en_array;
input [ERROR_INJ_MASK_WD-1:0] ras_err_inj_mask;

output                  ras_err_inj_done;

input                  ptm_request_msg;         // Request of a PTM  message
input                  ptm_res_msg;             // PTM  message response
input                  ptm_res_d_msg;           // PTM  message responseD
input   [63:0]         ptm_master_time;
input   [31:0]         ptm_prop_delay;

input   [NF-1:0]       cfg_auto_slot_pwr_lmt_dis; // Auto Slot Power Limit Disable field of Slot Control Register; hardwired to 0 if DPC is not configured.



output logic                 msg_gen_hv;                 // TLP msg start of transaction
output logic                 msg_gen_dv;                 // TLP msg data valid
output logic                 msg_gen_eot;                // TLP msg end of transaction
output logic [DW-1:0]        msg_gen_data;               // TLP msg data
output logic [ST_HDR+HDR_PROT_WD-1:0]msg_gen_hdr;        // MSG header including protection code if RAS is used
output                  app_obff_msg_grant;         // OBFF message grant

output  [NF-1:0]        pf_frs_grant;               // Provides a capability to acknowledge the granting of a FRS messaging request, for a Physical Function.                                                

output [NF-1:0]         pmstate_d3hot_to_d0;
wire [NF-1:0]         pmstate_d3hot_to_d0;
output                  msg_gen_asnak_grt;
wire                    msg_gen_asnak_grt;
output                  msg_gen_unlock_grant;
wire                    msg_gen_unlock_grant;

// SII: LTR Message Interface
output                  app_ltr_msg_grant;          // LTR message grant
output                  msgg2cdm_ltr_clr_msg_grant; // LTR clear message grant                  
output              assert_inta_grt;
output              assert_intb_grt;
output              assert_intc_grt;
output              assert_intd_grt;
output              deassert_inta_grt;
output              deassert_intb_grt;
output              deassert_intc_grt;
output              deassert_intd_grt;
output                  ven_msi_grant;              // MSI grant
output                  ven_msg_grant;              // App grant
output                  pme_to_ack_grt;             // PME_TO_ACK grant
output  [NF-1:0]    pm_pme_grant;                   // PM PME grant
output              pme_turn_off_grt;               // PM Turn Off grant
//output  [NF-1:0]        hp_msi_grant;               // Native hot plug grant

output  [NF-1:0]        msggen_cdm_send_f_err;
output  [NF-1:0]        msggen_cdm_send_nf_err;

// Internal wires
wire    [7:0]           msg_code;                   // Internal MSG code
wire    [1:0]           msg_fmt;                    // Internal MSG fmt
wire    [4:0]           msg_type;                   // Internal MSG type
wire    [15:0]          msg_req_id;                 // Internal MSG req id
wire    [3:0]           msg_obff_code;
wire                    msg_xmt_grant;
wire                    msg_xmt_request;
wire    [PF_WD-1:0]     msi_func_num;
wire    [2:0]           msi_tc;
wire    [4:0]           msi_vector;
wire                    msi_xmt_grant;
wire                    msi_xmt_request;

wire                    int_ven_msi_req;            // MSI request
wire    [PF_WD-1:0]     int_ven_msi_func_num;       // MSI Function number
wire    [2:0]           int_ven_msi_tc;             // MSI TC
wire    [4:0]           int_ven_msi_vector;         // MSI vector
wire    [15:0]          msg_rn_vendorID;
wire    [7:0]           msg_rn_subType;
wire    [3:0]           msg_rn_reason;


wire    [63:0]          msg_ptm_master_time;
wire    [31:0]          msg_ptm_data;
wire    [9:0]           msg_ptm_len;
wire                    msg_is_ptm;
wire                    msg_ptm_responseD;


logic                  msg_gen_hv_int;                 // TLP msg start of transaction
logic                  msg_gen_dv_int;                 // TLP msg data valid
logic                  msg_gen_eot_int;                // TLP msg end of transaction
logic  [DW-1:0]        msg_gen_data_int;               // TLP msg data
logic  [ST_HDR+HDR_PROT_WD-1:0]msg_gen_hdr_int;        // MSG header including protection code if RAS is used
logic                  xadm_msg_halt_int;

logic [(3*NF)-1:0]    cfg_multi_msi_en_int;
logic [(64*NF)-1:0]   cfg_msi_addr_int;
logic [(32*NF)-1:0]   cfg_msi_data_int;
logic [NF-1:0]        cfg_msi_64_int;

generate
if (MSI_NF == 1 && NF > 1) begin
  assign cfg_msi_64_int              = { {( 1*(NF-1)){1'b0}},      cfg_msi_64} ;
  assign cfg_msi_data_int            = { {(32*(NF-1)){1'b0}},    cfg_msi_data} ;
  assign cfg_msi_addr_int            = { {(64*(NF-1)){1'b0}},    cfg_msi_addr} ;// MSI address
  assign cfg_multi_msi_en_int        = { {( 3*(NF-1)){1'b0}},cfg_multi_msi_en} ;
end else begin
  assign cfg_msi_64_int              = cfg_msi_64;
  assign cfg_msi_data_int            = cfg_msi_data;
  assign cfg_msi_addr_int            = cfg_msi_addr;
  assign cfg_multi_msi_en_int        = cfg_multi_msi_en;
end
endgenerate

parameter VEN_MSI_REGIN     = `CX_VEN_MSI_REGIN;
parameter DATAPATH_WIDTH    = (1 + PF_WD +              // req, func_num
                               3 + 5);                  // tc, vector
delay_n_w_stalling

#(VEN_MSI_REGIN, DATAPATH_WIDTH, 1) u_ven_msi_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .stall      (ven_msi_grant),                        // Stall input when grant asserted           
    .clear      (ven_msi_grant),                        // Clear pipeline when grant asserted
    .din        ({ven_msi_req, ven_msi_func_num,
                  ven_msi_tc, ven_msi_vector}),
    .stallout   (),
    .dout      ({int_ven_msi_req, int_ven_msi_func_num,
                 int_ven_msi_tc, int_ven_msi_vector}) 
);
//
// MSG generation for everything other than MSI & Vendor MSG
//
msg_arbitration

 #(INST) u_msg_arbitration(
// ---- inputs ---------------
    .core_rst_n                 (core_rst_n),
    .core_clk                   (core_clk),
    .rdlh_link_up               (rdlh_link_up),
    .cfg_pbus_num               (cfg_pbus_num),
    .cfg_pbus_dev_num           (cfg_pbus_dev_num),
    .pm_bus_num                 (pm_bus_num),
    .pm_dev_num                 (pm_dev_num),
    .device_type                (device_type),
    .pm_xtlh_block_tlp          (pm_xtlh_block_tlp),

    .pm_asnak                   (pm_asnak),
    .pm_pme                     (pm_pme),
    .pme_turn_off               (pme_turn_off),
    .pme_to_ack                 (pme_to_ack),
//    .nhp_int                    (nhp_int),

    .send_cor_err               (send_cor_err),
    .send_nf_err                (send_nf_err),
    .send_f_err                 (send_f_err),
    .cfg_func_spec_err          (cfg_func_spec_err),
    .cfg_bus_master_en          (cfg_bus_master_en),

    .unlock                     (unlock),
    .idle_msg                   (idle_msg),
    .obff_msg                   (obff_msg),
    .cpu_active_msg             (cpu_active_msg),

    .inta_wire                  (inta_wire),
    .intb_wire                  (intb_wire),
    .intc_wire                  (intc_wire),
    .intd_wire                  (intd_wire),

    .cfg_slot_pwr_limit_wr      (cfg_slot_pwr_limit_wr),
    .cfg_auto_slot_pwr_lmt_dis  (cfg_auto_slot_pwr_lmt_dis), 

//    .hp_msi_request             (hp_msi_request),
    .ven_msi_req                (int_ven_msi_req),
    .ven_msi_func_num           (int_ven_msi_func_num),
    .ven_msi_tc                 (int_ven_msi_tc),
    .ven_msi_vector             (int_ven_msi_vector),

    .msg_xmt_grant              (msg_xmt_grant),
    .msi_xmt_grant              (msi_xmt_grant),
    .pm_dstate                  (pm_dstate),

    .app_req_retry_en           (app_req_retry_en),
    .app_pf_req_retry_en        (app_pf_req_retry_en),
    .app_drs_ready              (app_drs_ready),
    .app_pf_frs_ready           (app_pf_frs_ready),
    
    .ptm_request_msg            (ptm_request_msg),
    .ptm_res_msg                (ptm_res_msg),
    .ptm_res_d_msg              (ptm_res_d_msg),
    .ptm_master_time            (ptm_master_time),
    .ptm_prop_delay             (ptm_prop_delay),
    

// ---- outputs ---------------
    .msg_code                   (msg_code),
    .msg_fmt                    (msg_fmt),
    .msg_type                   (msg_type),
    .msg_req_id                 (msg_req_id),
    .msg_obff_code              (msg_obff_code),
    .app_obff_msg_grant         (app_obff_msg_grant),
    .pf_frs_grant               (pf_frs_grant),

    .msg_rn_vendorID            (msg_rn_vendorID),
    .msg_rn_subType             (msg_rn_subType),
    .msg_rn_reason              (msg_rn_reason),
    .msg_ptm_master_time        (msg_ptm_master_time),
    .msg_ptm_data               (msg_ptm_data),
    .msg_ptm_len                (msg_ptm_len),
    .msg_is_ptm                 (msg_is_ptm),
    .msg_ptm_responseD          (msg_ptm_responseD),
    .msg_xmt_request            (msg_xmt_request),

    .msi_func_num               (msi_func_num),
    .msi_tc                     (msi_tc),
    .msi_vector                 (msi_vector),
    .msi_xmt_request            (msi_xmt_request),
    .assert_inta_grt            (assert_inta_grt),
    .assert_intb_grt            (assert_intb_grt),
    .assert_intc_grt            (assert_intc_grt),
    .assert_intd_grt            (assert_intd_grt),
    .deassert_inta_grt          (deassert_inta_grt),
    .deassert_intb_grt          (deassert_intb_grt),
    .deassert_intc_grt          (deassert_intc_grt),
    .deassert_intd_grt          (deassert_intd_grt),
    .ven_msi_grant              (ven_msi_grant),
    .pme_to_ack_grt             (pme_to_ack_grt),
    .pm_pme_grant               (pm_pme_grant),
    .pme_turn_off_grt           (pme_turn_off_grt)


  ,
  .pmstate_d3hot_to_d0        (pmstate_d3hot_to_d0)      //out of msg_arbitration
  ,
  .pm_asnak_grt                 (msg_gen_asnak_grt),
  .unlock_grt                   (msg_gen_unlock_grant),
  .msggen_cdm_send_f_err        (msggen_cdm_send_f_err),
  .msggen_cdm_send_nf_err       (msggen_cdm_send_nf_err)
);


//
// Form Message TLP
//
msg_formation

#(INST) u_msg_formation(
// ---- inputs ---------------
    .core_rst_n                 (core_rst_n),
    .core_clk                   (core_clk),
    .cfg_pbus_num               (cfg_pbus_num),
    .cfg_pbus_dev_num           (cfg_pbus_dev_num),
    .device_type                (device_type),
    .pm_xtlh_block_tlp          (pm_xtlh_block_tlp),
    .cfg_nond0_vdm_block        (cfg_nond0_vdm_block),

    .msg_code                   (msg_code),
    .msg_fmt                    (msg_fmt),
    .msg_type                   (msg_type),
    .msg_req_id                 (msg_req_id),
    .msg_obff_code              (msg_obff_code),
    .msg_xmt_request            (msg_xmt_request),

    .set_slot_pwr_limit_val     (set_slot_pwr_limit_val),
    .set_slot_pwr_limit_scale   (set_slot_pwr_limit_scale),

    .cfg_msi_addr               (cfg_msi_addr_int),
    .cfg_msi_data               (cfg_msi_data_int),
    .cfg_msi_64                 (cfg_msi_64_int),
    .cfg_multi_msi_en           (cfg_multi_msi_en_int),

    .msi_req                    (msi_xmt_request),
    .msi_func_num               (msi_func_num),
    .msi_tc                     (msi_tc),
    .msi_vector                 (msi_vector),
    .cfg_msix_en                (cfg_msix_en),
    .msix_addr                  (msix_addr),
    .msix_data                  (msix_data),
    .app_ltr_msg_req            (app_ltr_msg_req),
    .app_ltr_msg_latency        (app_ltr_msg_latency),
    .app_ltr_msg_func_num       (app_ltr_msg_func_num),
    .cdm2msgg_ltr_clr_msg_req   (cdm2msgg_ltr_clr_msg_req),
    .ven_msg_fmt                (ven_msg_fmt),
    .ven_msg_type               (ven_msg_type),
    .ven_msg_tc                 (ven_msg_tc),
    .ven_msg_td                 (ven_msg_td),
    .ven_msg_ep                 (ven_msg_ep),
    .ven_msg_attr               (ven_msg_attr),
    .ven_msg_len                (ven_msg_len),
    .ven_msg_func_num           (ven_msg_func_num),
    .ven_msg_tag                (ven_msg_tag),
    .ven_msg_code               (ven_msg_code),
    .ven_msg_data               (ven_msg_data),
    .ven_msg_req                (ven_msg_req),

    .xadm_msg_halt              (xadm_msg_halt_int),
    .msg_rn_vendorID            (msg_rn_vendorID),
    .msg_rn_subType             (msg_rn_subType),
    .msg_rn_reason              (msg_rn_reason),

    .cfg_rasdp_error_mode       (cfg_rasdp_error_mode),
    .ras_err_inj_en_array       (ras_err_inj_en_array),
    .ras_err_inj_mask           (ras_err_inj_mask),
    .msg_ptm_master_time        (msg_ptm_master_time),
    .msg_ptm_data               (msg_ptm_data),
    .msg_ptm_len                (msg_ptm_len),
    .msg_is_ptm                 (msg_is_ptm),
    .msg_ptm_responseD          (msg_ptm_responseD),
// ---- outputs ---------------
    .ras_err_inj_done           (ras_err_inj_done),
    .msg_gen_dv                 (msg_gen_dv_int),
    .msg_gen_hv                 (msg_gen_hv_int),
    .msg_gen_hdr                (msg_gen_hdr_int),
    .msg_gen_eot                (msg_gen_eot_int),
    .msg_gen_data               (msg_gen_data_int),
    .msg_xmt_grant              (msg_xmt_grant),
    .app_ltr_msg_grant          (app_ltr_msg_grant),
    .msgf_ltr_clr_msg_grant     (msgg2cdm_ltr_clr_msg_grant),

    .msi_grant                  (msi_xmt_grant),
    .ven_msg_grant              (ven_msg_grant)

);



assign msg_gen_hv        = msg_gen_hv_int;
assign msg_gen_dv        = msg_gen_dv_int;
assign msg_gen_hdr       = msg_gen_hdr_int;
assign msg_gen_data      = msg_gen_data_int;
assign msg_gen_eot       = msg_gen_eot_int;
assign xadm_msg_halt_int = xadm_msg_halt;



endmodule
