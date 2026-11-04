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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/PTM/ptm_req_res.sv#9 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the Precision Time Measurement Extended Capability (PTM) registers. 
// --- This module is instantiated for each function across all functions.
// -----------------------------------------------------------------------------


// Combined Requester and Responder selected by upstream port input


`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module ptm_req_res  
#(
    parameter INST                  = 0,                                // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM              = 0                                 // uniquifying parameter per function 
    ,parameter PTM_REQ_VALUE        = `CX_PTM_REQUESTER_VALUE
    ,parameter WF = 16
    ,parameter NPTMVSEC    = 26
    ,parameter NPTMREQVSEC = 26
    ,parameter NPTMRESVSEC = 19 
   )

                     (
  input                                   aux_clk, 
  input                                   non_sticky_rst_n,
  input                                   sticky_rst_n,

  input                                   lbc_cdm_dbi,
  input [3:0]                             write_pulse,
  input [NPTMVSEC-1:0]                    reg_id,                   //26 registers in requester but only 19 in responder
  input [31:0]                            lbc_cdm_data,
  input                                   dbi_ro_wr_en,

  input                                   ptm_external_master_strobe,                                     
  input [63:0]                            ptm_external_master_time,

  input                                   upstream_port,

  input                                   rdlh_link_up,
  input                                   cfg_ptm_enabled,                  //PTM Enable from PTM Header
  input                                   cfg_ptm_responder_capable,
  input                                   cfg_ptm_root_select,          //SW which is not root must update its local context no more than every 10ms
  input                                   pm_sel_aux_clk,

  input [2:0]                             current_data_rate,          // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4, 4-gen5, 5-gen6
  input [2:0]                             mac_phy_rate,               // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4, 4-gen5, 5-gen6
  input [5:0]                             cfg_neg_link_width,         // Active Link Width
  input                                   flit_mode_link,             // Indicates the link has come up in flit mode
  input [3:0]                             smlh_autoneg_link_sp,       // negotiated link speed
  input                                   smlh_in_l0,

  input                                   ptm_manual_update_pulse,      //top level input to trigger a single update
  input                                   ptm_auto_update_signal,       //top level input to indicate automatic updates every 10ms
  input                                   pm_linkst_in_l0,              //input from pm_active_ctrl indicating PM state in L0
  input                                   pm_linkst_in_l0s,             //input from pm_active_ctrl indicating PM state in L0s
  input                                   xdlh_retry_req,
  input                                   xdlh_ptm_sot,                 //layer 2 detection of start of any message to stamp pending time
  input                                   xdlh_ptm_multi_cycle,             //layer 2 recognition of PTM message to store as time stamp
  input                                   xdlh_ptm_response,                 //layer 2 recognition of PTM message to store as time stamp
  input                                   xdlh_ptm_request,                 //layer 2 recognition of PTM message to store as time stamp
  input                                   xdlh_rbuf_replaying,
  input                                   rdlh_ptm_sot,                 //layer 2 detection of start of any message to stamp pending time
  input                                   rdlh_ptm_multi_cycle,             //layer 2 recognition of PTM message to store as time stamp
  input                                   rdlh_ptm_response,                 //layer 2 recognition of PTM message to store as time stamp
  input                                   rdlh_ptm_request,                 //layer 2 recognition of PTM message to store as time stamp
  input                                   rdlh_duplicate_tlp,
 
  input                                   radm_ptm_req_msg,
  input                                   radm_ptm_res_msg,       //radm filter detects ptm response message
  input                                   radm_ptm_res_d_msg,     //radm filter detects ptm response D message
  input [63:0]                            radm_ptm_master_time,   // Master Time from response D message
  input [31:0]                            radm_ptm_prop_delay,    // Propagation Delay from response D message



  output                                  ptm_request_msg,        // to msg_gen to output ptm request message
  output                                  ptm_res_msg,        // to msg_gen to output ptm res_msg
  output                                  ptm_res_d_msg,      // to msg_gen to output ptm res_d_msg
  output [63:0]                           ptm_master_time,        // to msg_gen to output ptm master_time
  output [31:0]                           ptm_prop_delay,         // to msg_gen to output ptm prop_delay
           
  output [31:0]                           ptm_reg_data,           //DBI output data
  output                                  ptm_context_valid,      //PTM local clock is valid
  output logic                            ptm_responder_rdy_to_validate, //PTM Responder ready to validate

  output                                  ptm_clock_updated,      //pulse to indicate that the requesters clock was updated
  output signed [63:0]                    ptm_clock_correction,   //amount by which the requester clock was corrected to match the PTM Root clock
  output                                  ptm_trigger_allowed,    // when system is not in the middle of an update a manual request may be made
  output                                  ptm_updating,           //PTM Update is in progress
  output                                  ptm_req_response_timeout,     //Pulse indicating PTM Request sent but no response after 100us
  output                                  ptm_req_dup_rx,               //Pulse indicating Duplicate TLP received during PTM update process or response received during wait for next update
  output                                  ptm_req_replay_tx,            //Pulse indicating Replay TLP sent during PTM update process or Request sent during wait for next update

  output [63:0]                           ptm_local_clk            //PTM local clock
);

  localparam TP = `TP;

  // Standard PCIe Core Base Period [(1/2**WF) ns]
  localparam T_CLK_1000_MHZ = 'd1<<WF;  // 1 ns

  // CCIX-ESM Mode Core Base Periods [(1/2**WF) ns]
  // 20 GT/s rates
  localparam T_CLK_2500_MHZ = 26215;   // 0.4000091553 ns
  // 25 GT/s rates
  localparam T_CLK_3125_MHZ = 20972;   // 0.3200073242 ns

  wire [31:0]                             ptm_res_reg_data;
  wire [31:0]                             ptm_req_reg_data;
  wire [NPTMREQVSEC-1:0]                  req_reg_id;
  wire [63:0]                             ptm_adjust_value;

  wire                                    ptm_req_context_valid;
  wire                                    ptm_res_context_valid;
  wire                                    ptm_gen_req_msg;
  wire                                    ptm_gen_res_msg;
  wire                                    ptm_gen_res_d_msg;

  wire [7+WF:0]                           ptm_nom_clock_period;
  wire [7+WF:0]                           ptm_scaled_clock_period_req;
  wire                                    ptm_scaled_clock_period_req_en;
  wire [7+WF:0]                           ptm_scaled_clock_period_res;
  wire                                    ptm_scaled_clock_period_res_en;
  wire [7+WF:0]                           ptm_clock_period;
  reg  [2:0]                              previous_mac_phy_rate;

  wire                                    current_data_rate_updated; // pulsed when ptm_clock_period changes
  wire                                    mac_phy_rate_changed;     // pulsed when mac_phy_rate_changes
  reg                                     ptm_clock_period_change; // set when mac_phy_rate changes; cleared when ptm_clock_period_changes
                             
  reg  [3:0]                              ptm_previous_link_speed;
  wire                                    ptm_link_speed_change;

  wire [63:0]                             ptm_res_master_time;              
  wire [31:0]                             ptm_res_prop_delay;

  wire                                    ptm_update_local_clk;
  wire                                    ptm_calc_result; //reassign ptm_update_local_clk, for testbench compatibility
  wire [63:0]                             local_clk;
  wire [WF-1:0]                           local_clk_frac;

  wire [2:0] ptm_latency_sel;
  wire mac_phy_ts_reqstr_req;
  wire mac_phy_ts_res_req;


  assign ptm_calc_result = ptm_update_local_clk;

  always@(posedge aux_clk or negedge non_sticky_rst_n)      //track link speed 
  begin
    if(!non_sticky_rst_n) 
      ptm_previous_link_speed <= #TP 4'b0;
    else
      ptm_previous_link_speed <= #TP smlh_autoneg_link_sp;
  end


  assign ptm_link_speed_change = (ptm_previous_link_speed != smlh_autoneg_link_sp);         //pulse on link speed change


  always@(posedge aux_clk or negedge non_sticky_rst_n)        //track mac_phy_rate
  begin
    if(!non_sticky_rst_n) begin
      previous_mac_phy_rate <= #TP 0;
    end
    else begin
      previous_mac_phy_rate <= #TP mac_phy_rate;
    end
  end

  always@(posedge aux_clk or negedge non_sticky_rst_n)      // register ptm_responder_rdy_to_validate output
  begin
    if(!non_sticky_rst_n)
      ptm_responder_rdy_to_validate <= #TP 1'b0; 
    else
      ptm_responder_rdy_to_validate <= #TP upstream_port ? 1'b0 : (ptm_res_context_valid | smlh_in_l0);
  end

  assign mac_phy_rate_changed = (previous_mac_phy_rate != mac_phy_rate);             //pulse on mac_phy_rate change
  assign current_data_rate_updated = (current_data_rate == mac_phy_rate);         //current_data_rate changed to new mac_phy_rate

  always@(posedge aux_clk or negedge non_sticky_rst_n)      //indicate PTM clock change is ongoing 
  begin
    if(!non_sticky_rst_n) 
      ptm_clock_period_change <= #TP 1'b0;
    else
      ptm_clock_period_change <= #TP mac_phy_rate_changed ? 1'b1 : current_data_rate_updated ? 1'b0 : ptm_clock_period_change;
  end

  assign ptm_reg_data[31:0]     = upstream_port ? ptm_req_reg_data[31:0]    : (reg_id > {NPTMRESVSEC{1'b1}}) ? 32'b0: ptm_res_reg_data[31:0];
  //assign req_reg_id             = upstream_port ? reg_id[NPTMREQVSEC-1:0]   : {7'b0, reg_id[NPTMRESVSEC-1:0]};
  assign ptm_context_valid      = upstream_port ? ptm_req_context_valid     : ptm_res_context_valid;
  assign ptm_request_msg        = upstream_port ? ptm_gen_req_msg           : 1'b0;       
  assign ptm_res_msg            = upstream_port ? 1'b0                      : ptm_gen_res_msg;       
  assign ptm_res_d_msg          = upstream_port ? 1'b0                      : ptm_gen_res_d_msg;
  assign ptm_master_time[63:0]  = upstream_port ? 64'b0                     : ptm_res_master_time[63:0];
  assign ptm_prop_delay[31:0]   = upstream_port ? 32'b0                     : ptm_res_prop_delay[31:0];

  assign ptm_local_clk[63:0] = local_clk[63:0];

  assign ptm_nom_clock_period = 
    (current_data_rate== `GEN1_RATE) ?  `CX_MAC_GEN1_CLK_PERIOD_PS * T_CLK_1000_MHZ / 1000:
    (current_data_rate== `GEN2_RATE) ?  `CX_MAC_GEN2_CLK_PERIOD_PS * T_CLK_1000_MHZ / 1000:
    (current_data_rate== `GEN3_RATE) ?  `CX_MAC_GEN3_CLK_PERIOD_PS * T_CLK_1000_MHZ / 1000:
    (current_data_rate== `GEN4_RATE) ?  `CX_MAC_GEN4_CLK_PERIOD_PS * T_CLK_1000_MHZ / 1000:
    (current_data_rate== `GEN5_RATE) ?  `CX_MAC_GEN5_CLK_PERIOD_PS * T_CLK_1000_MHZ / 1000:
    (current_data_rate== `GEN6_RATE) ?  `CX_MAC_GEN6_CLK_PERIOD_PS * T_CLK_1000_MHZ / 1000:
    T_CLK_1000_MHZ;

// PTM clock period selection
//
     assign ptm_clock_period = 
     (upstream_port && ptm_scaled_clock_period_req_en) ? ptm_scaled_clock_period_req :
     (!upstream_port && ptm_scaled_clock_period_res_en) ? ptm_scaled_clock_period_res :
      ptm_nom_clock_period;

// Select the PTM Tx and Rx latency viewport register to be used for timestamp adjustment,
// based on esm_current_rate and current_data_rate
  assign ptm_latency_sel = 
    (current_data_rate== `GEN1_RATE) ?  3'd0: // 2.5 Gt/s
    (current_data_rate== `GEN2_RATE) ?  3'd1: //   5 Gt/s
    (current_data_rate== `GEN3_RATE) ?  3'd2: //   8 Gt/s
    (current_data_rate== `GEN4_RATE) ?  3'd3: //  16 Gt/s
    (current_data_rate== `GEN5_RATE) ?  3'd4: //  32 Gt/s
    (current_data_rate== `GEN6_RATE) ?  3'd5: //  64 Gt/s
    3'd0;                                     // 2.5 Gt/s

  // Need to create latency adjustment so we can track the latency
  // between the End-of-Flit (EOF) and the PTM marker bit in the Flit
  // As the link narrows the distance between EOF and PTM-bit grows.
  // The trackers in PLH always trigger on EOF. This adjustment give
  // accurate time for the PTM-bit on the serial pins for all speeds
  // and link widths.
  //
  // The PTM bit in the Flit marker is 17 bytes from the EOF
  // Depending on how many bytes the link is moving per cycle, we need
  // to account for latency adjustment.

  // Bytes per cycle per lane (Sness)
  wire [7:0] active_nb;
  assign active_nb =
    (current_data_rate== `GEN1_RATE) ? `CX_NB_GEN1 :
 (current_data_rate== `GEN2_RATE) ? `CX_NB_GEN2 :
 (current_data_rate== `GEN3_RATE) ? `CX_NB_GEN3 :
 (current_data_rate== `GEN4_RATE) ? `CX_NB_GEN4 :
 (current_data_rate== `GEN5_RATE) ? `CX_NB_GEN5 :
 (current_data_rate== `GEN6_RATE) ? `CX_NB_GEN6 :
    `CX_NB;

  // Bytes per cycle on active lanes
  logic [7:0] bytes_per_cycle;
  always@(posedge aux_clk or negedge non_sticky_rst_n)
  begin
    if(!non_sticky_rst_n) 
      bytes_per_cycle <= #TP 7'd0;
    else if(cfg_neg_link_width == 16)
      bytes_per_cycle <= #TP active_nb << 4;
    else if(cfg_neg_link_width == 8)
      bytes_per_cycle <= #TP active_nb << 3;
    else if(cfg_neg_link_width == 4)
      bytes_per_cycle <= #TP active_nb << 2;
    else if(cfg_neg_link_width == 2)
      bytes_per_cycle <= #TP active_nb << 1;
    else
      bytes_per_cycle <= #TP active_nb;
  end


  logic flit_mode_link_r;
  logic [7+WF:0] ptm_clock_period_r_shft_dt;
  always@(posedge aux_clk or negedge non_sticky_rst_n)
  begin
    if(!non_sticky_rst_n) begin
      flit_mode_link_r <= #TP 1'b0;
      ptm_clock_period_r_shft_dt <= #TP 'd0;
    end else begin
      flit_mode_link_r <= #TP flit_mode_link;
      ptm_clock_period_r_shft_dt <= #TP $bits(ptm_clock_period_r_shft_dt)'( ptm_clock_period );
    end
  end

  // Latency, in clock cycles, between flit EOF and the PTM bit in the flit
  logic [11:0] ptm_eof_latency;
  always@(posedge aux_clk or negedge non_sticky_rst_n)
  begin
    if(!non_sticky_rst_n)
      ptm_eof_latency <= #TP 'd0;
    else if(!flit_mode_link_r)
      ptm_eof_latency <= #TP 'd0;
    else if(bytes_per_cycle==2)
      ptm_eof_latency <= #TP {1'b0, ptm_clock_period_r_shft_dt[7+WF:WF], 3'b0}; // multiply by 8
    else if(bytes_per_cycle==4)
      ptm_eof_latency <= #TP {2'b0, ptm_clock_period_r_shft_dt[7+WF:WF], 2'b0}; // multiply by 4
    else if(bytes_per_cycle==8)
      ptm_eof_latency <= #TP {3'b0, ptm_clock_period_r_shft_dt[7+WF:WF], 1'b0}; // multiply by 2
    else if(bytes_per_cycle==16)
      ptm_eof_latency <= #TP {4'b0, ptm_clock_period_r_shft_dt[7+WF:WF]};
    else
      ptm_eof_latency <= #TP 'd0;
  end



ptm_requester
 # (.NPTMREQVSEC(NPTMREQVSEC)) 
u_ptm_requester
(
  .aux_clk                      (aux_clk),   
  .non_sticky_rst_n             (non_sticky_rst_n),
  .sticky_rst_n                 (sticky_rst_n),

  .lbc_cdm_dbi                  (lbc_cdm_dbi && upstream_port),
  .lbc_cdm_data                 (lbc_cdm_data),
  .dbi_ro_wr_en                 (dbi_ro_wr_en),
  .write_pulse                  (upstream_port ? write_pulse[3:0] : 4'b0),
  .reg_id                       (reg_id[NPTMREQVSEC-1:0]),       //requester has 26 registers

  .phy_link_up                  (rdlh_link_up),
  .smlh_in_l0                   (smlh_in_l0),
  .cfg_ptm_enabled              (cfg_ptm_enabled && upstream_port),              //from PTM Capability header (not PTM VSEC)
  .cfg_ptm_root_select          (cfg_ptm_root_select),
  .pm_sel_aux_clk               (pm_sel_aux_clk),

  .ptm_latency_sel              (ptm_latency_sel),       //latency select

  .ptm_nom_clock_period         (ptm_nom_clock_period),          // Nominal PTM clock period to VSEC register
  .ptm_clock_period             (ptm_clock_period),
  .ptm_clock_period_change      (ptm_clock_period_change),
  .ptm_link_speed_change        (ptm_link_speed_change),
  .ptm_eof_latency              (ptm_eof_latency),
  .flit_mode_link               (flit_mode_link_r),

  .ptm_manual_update_pulse      (ptm_manual_update_pulse),      //top level input
  .ptm_auto_update_signal       (ptm_auto_update_signal),       //top level input
  .pm_linkst_in_l0              (pm_linkst_in_l0),              //from pm_active_ctrl indicating PM state in L0
  .pm_linkst_in_l0s             (pm_linkst_in_l0s),             //from pm_active_ctrl indicating PM state in L0s
 
  .xdlh_rbuf_replaying          (xdlh_rbuf_replaying),
  .xdlh_ptm_sot                 (xdlh_ptm_sot),                 //layer 2
  .xdlh_ptm_multi_cycle         (xdlh_ptm_multi_cycle),
  .xdlh_ptm_request             (xdlh_ptm_request),
  .rdlh_ptm_sot                 (rdlh_ptm_sot),                 //layer 2
  .rdlh_ptm_multi_cycle         (rdlh_ptm_multi_cycle),
  .rdlh_ptm_response            (rdlh_ptm_response),
  .rdlh_duplicate_tlp           (rdlh_duplicate_tlp),

  .radm_ptm_res_msg             (radm_ptm_res_msg),
  .radm_ptm_res_d_msg           (radm_ptm_res_d_msg),
  .radm_ptm_master_time         (radm_ptm_master_time),              //input from RADM
  .radm_ptm_prop_delay          (radm_ptm_prop_delay),               //input from RADM
    
  .ptm_local_clk                (ptm_local_clk),  


  // outputs

  .ptm_scaled_clock_period      (ptm_scaled_clock_period_req),   // Scaled PTM clock period from VSEC register
  .ptm_scaled_clock_period_en   (ptm_scaled_clock_period_req_en), // Enable Scaled PTM clock period from VSEC register
  .ptm_gen_req_msg              (ptm_gen_req_msg),               // to msg_gen
 
  .ptm_context_valid            (ptm_req_context_valid),            //top level output
  .ptm_clock_updated            (ptm_clock_updated),
  .ptm_clock_correction         (ptm_clock_correction),

  .ptm_update_local_clk         (ptm_update_local_clk),
  .ptm_requester_adjust_value   (ptm_adjust_value),
  .ptm_reg_data                 (ptm_req_reg_data),

  .ptm_trigger_allowed          (ptm_trigger_allowed),          // top level output
  .ptm_updating                 (ptm_updating),                 // to pm_ctrl block AND top level output
  .ptm_req_response_timeout     (ptm_req_response_timeout),     // top level output
  .ptm_req_dup_rx               (ptm_req_dup_rx),               // top level output
  .ptm_req_replay_tx            (ptm_req_replay_tx)              // top level output
   
);  //ptm_requester




ptm_responder
 #(.NPTMRESVSEC(NPTMRESVSEC))
u_ptm_responder
  (
  .non_sticky_rst_n             (non_sticky_rst_n),
  .aux_clk                      (aux_clk),       
  .sticky_rst_n                 (sticky_rst_n),

  .lbc_cdm_dbi                  (lbc_cdm_dbi),
  .lbc_cdm_data                 (lbc_cdm_data),
  .dbi_ro_wr_en                 (dbi_ro_wr_en),
  .write_pulse                  (!upstream_port ? write_pulse : 4'b0),
  .reg_id                       (reg_id[NPTMRESVSEC-1:0]),                 //responder only has 19 registers

  .cfg_ptm_enabled              (cfg_ptm_enabled),              //from PTM Capability header (not PTM VSEC)
  .cfg_ptm_responder_capable    (cfg_ptm_responder_capable),
  .phy_link_up                  (rdlh_link_up),
  .pm_sel_aux_clk               (pm_sel_aux_clk),
  .ptm_nom_clock_period         (ptm_nom_clock_period),          // Nominal PTM clock period to VSEC register
  .ptm_clock_period             (ptm_clock_period),                            
  .ptm_clock_period_change      (ptm_clock_period_change),
 
  .pm_linkst_in_l0              (pm_linkst_in_l0),              //from pm_active_ctrl indicating PM state in L0
  .pm_linkst_in_l0s             (pm_linkst_in_l0s),             //from pm_active_ctrl indicating PM state in L0s

  .ptm_eof_latency              (ptm_eof_latency),
  .flit_mode_link               (flit_mode_link_r),

  .ptm_latency_sel              (ptm_latency_sel),               //latency select
  
  .rdlh_duplicate_tlp           (rdlh_duplicate_tlp),
  .rdlh_ptm_sot                 (rdlh_ptm_sot),                 //layer 2
  .rdlh_ptm_multi_cycle         (rdlh_ptm_multi_cycle),
  .rdlh_ptm_request             (rdlh_ptm_request),
  .xdlh_ptm_sot                 (xdlh_ptm_sot),                 //layer 2
  .xdlh_ptm_multi_cycle         (xdlh_ptm_multi_cycle),
  .xdlh_ptm_response            (xdlh_ptm_response),
  .xdlh_retry_req               (xdlh_retry_req),

  .radm_ptm_req_msg             (radm_ptm_req_msg),

  .ptm_local_clk                (ptm_local_clk),


  .ptm_responder_rdy_to_validate (ptm_responder_rdy_to_validate),
  .ptm_external_master_strobe    (ptm_external_master_strobe),


  // outputs
  
  .ptm_scaled_clock_period      (ptm_scaled_clock_period_res),     // Scaled PTM clock period from VSEC register
  .ptm_scaled_clock_period_en   (ptm_scaled_clock_period_res_en), // Enable Scaled PTM clock period from VSEC register
  .ptm_gen_res_msg              (ptm_gen_res_msg),
  .ptm_gen_res_d_msg            (ptm_gen_res_d_msg),
  .ptm_master_time              (ptm_res_master_time),              
  .ptm_prop_delay               (ptm_res_prop_delay),               
  .ptm_status_context_valid     (ptm_res_context_valid),
  .ptm_reg_data                 (ptm_res_reg_data)

);



ptm_clock

#(
  .NV(21)
)
u_ptm_clock
(
  .non_sticky_rst_n             (non_sticky_rst_n),
  .aux_clk                      (aux_clk),

  .ptm_local_clk_enable         (1'b1),
  
  .lbc_cdm_dbi                  (lbc_cdm_dbi),
  .lbc_cdm_data                 (lbc_cdm_data),

  .ptm_external_master_strobe   (ptm_external_master_strobe),                                     
  .ptm_external_master_time     (ptm_external_master_time),

  .ptm_local_clk_write_pulse    (write_pulse),
  .ptm_local_clk_reg_id         (reg_id[5:4]),

  .ptm_clock_period             (ptm_clock_period),

  .ptm_update_local_clk         (ptm_update_local_clk),
  .ptm_local_adjust_value       (ptm_adjust_value),                


  // Outputs

  .local_clk                    (local_clk),           //this is the PTM local clock in nanoseconds
  .local_clk_frac               (local_clk_frac)       //this is the fractional part of the local clock
);

endmodule //ptm_req_res 
