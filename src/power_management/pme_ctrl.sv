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
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/power_management/pme_ctrl.sv#14 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// --- This block handles the PM message protocol handshakes and PM_PME delivery mechanism
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

 
 module pme_ctrl (
//--------------------- Inputs -----------------------
    aux_clk,
    pwr_rst_n,
    perst_n,
    pm_core_rst_done,
    switch_device,
    upstream_port,
    all_dwsp_rcvd_toack_msg,
    pm_pme_cap,
    apps_pm_xmt_turnoff,
    apps_pm_xmt_pme,
    app_ready_entr_l23,
    one_dwsp_exit_l23,
    nhp_pme_det,
    radm_pm_turnoff,
    radm_pm_to_ack,
    outband_pwrup_cmd,
    xdlh_xmt_pme_ack,
    cfg_pmstatus_clr,
    pm_pme_en,
    pl_state_active,
    pl_link_up,
    pm_prot_idle_flag,
    pm_smlh_l23_exit,
    pm_xdlh_enter_l23,

    current_data_rate,
    pme_to_ack_grt,
    pm_pme_grant,
    pme_turn_off_grt,
    aux_clk_active,
    pm_pl_aux_clk_freq,
    perst_n_posedge,
    pm_pmstate,
    pm_aslk_pmctrl,

// ------------- Outputs ----------------------------------
    software_entr_l1,
    software_entr_l23,
    pm_aspm_l0s_en,
    pm_aspm_l1_en,
    pm_xtlh_block_tlp,
    pm_radm_block_tlp,
    pm_xmt_turnoff,
    pm_xmt_to_ack,
    pm_xmt_pme,
    pm_turnoff_timeout,
    pm_req_dwsp_turnoff,
    pm_status,
    pm_pme_exit_l1
    ,
    pm_pme_resend_flag
    ,
    pm_l2_entry_flag
    ,
    pm_wake_l2_exit
);
parameter INST                  = 0;                    // The uniquifying parameter for each port logic instance.
parameter NB                    = `CX_NB;               // Number of symbols (bytes) per clock cycle
parameter NF                    = `CX_NFUNC;            // Number of functions
parameter TP                    = `TP;                  // Clock to Q delay (simulator insurance)


parameter COMMUNICATING         = 4'h0;
parameter COMM_SEND_ACK         = 4'h1;
parameter COMM_REQ_TURNOFF_DWSP = 4'h2;
parameter PME_SEND              = 4'h4;
parameter PME_SEND_ACK          = 4'h5;
parameter PME_REQ_TURNOFF_DWSP  = 4'h6;
parameter PME_SEND_STATUS_WAIT  = 4'h7;
parameter NON_COMMUNICATING     = 4'h8;
parameter LINK_REACTIVATION     = 4'h9;

parameter PME_BASE_TIMER_WD                = `CX_PME_BASE_TIMER_WD;
parameter PME_PRESCALE_TIMER_WD            = `CX_PME_PRESCALE_TIMER_WD;
parameter PME_BASE_TIMER_TIMEOUT_VALUE_INT = `CX_PME_BASE_TIMER_TIMEOUT_VALUE;
parameter PME_PRESCALE_TIMEOUT_VALUE       = `CX_PME_PRESCALE_TIMEOUT_VALUE; 
parameter PME_BASETIMER_4MS_INT            = `CX_PME_BASETIMER_4MS;

localparam VF_PME_SUPPORT = 5'b00000;
localparam PL_AUX_CLK_FREQ_WD = `CX_PL_AUX_CLK_FREQ_WD;

// ------------- Inputs ----------------------------------
input                   aux_clk;
input                   pwr_rst_n;
input                   perst_n;
input                   pm_core_rst_done;               // Indication from pm_rst_control that core_rst_n has been de-asserted
input                   upstream_port;
input                   switch_device;                  // CDM configure reg is programmed current port as switch device

input                   all_dwsp_rcvd_toack_msg;        // all downstream receivd TOACK PM message
input                   apps_pm_xmt_turnoff;            // Application asserts transmission request for a power turnoff message
input   [NF-1:0]        apps_pm_xmt_pme;                // Application asserts transmission request for PM xmt PME message
input                   app_ready_entr_l23;             // Indicate that application is ready to enter L23 when device has being programmed to D3
input                   one_dwsp_exit_l23;              // One of the downstream port exits L23
input   [NF-1:0]        nhp_pme_det;                    // hot plug PME event detected
input   [NF-1:0]        outband_pwrup_cmd;              // Application (outband) request a wake up (WOL signal)
input                   xdlh_xmt_pme_ack;               // XDLH layer acknowledged the requests generated from this module for transmission of PM DLLPs
input                   radm_pm_turnoff;                // RADM recieved PM turn off message
input                   radm_pm_to_ack;                 // RADM recieved PM to ACK message
input   [(5*NF)-1:0]    pm_pme_cap;                    // Configured PME capability
input   [NF-1:0]        cfg_pmstatus_clr;               // CDM send PME status clear command
input   [NF-1:0]        pm_pme_en;                      // CDM PME enable field

input                   pl_state_active;                // SPIF: pl_state_sts is in ACTIVE or ACTIVE_L0S_PMNAK on PCIe/CXL.io SPIF interface; Non-SPIF: ltssm in S_L0 or S_L0S
input                   pl_link_up;                     // SPIF: pl_link_up on PCIe/CXL.io SPIF interface; Non-SPIF: smlh_link_up
input                   pm_prot_idle_flag;              // Protocol FSM: Indicates that the Protocol FSM is in idle state
input                   pm_xdlh_enter_l23;              // indicates that the master state machine has requested to enter L23
input                   pm_smlh_l23_exit;               // pm_active_ctrl.v output to request LTSSM exit from L23
input   [2:0]           current_data_rate;              // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4

input                   pme_to_ack_grt;                 // PME Turnoff Ack request has been granted
input   [NF-1:0]        pm_pme_grant;                   // PM PME grant
input                   pme_turn_off_grt;
input                   aux_clk_active;
input [PL_AUX_CLK_FREQ_WD-1:0] pm_pl_aux_clk_freq;
input                   perst_n_posedge;
input  [((3*NF)-1):0]   pm_pmstate;                     // CDM Interface: PM D-state (shadowed)
input  [(2*NF)-1:0]     pm_aslk_pmctrl;                 // CDM Interface: Active state link pm control (shadowed)

// ------------- Outputs ----------------------------------
output                  software_entr_l1;               // Instructs PM Protocol FSM to go into L1
output                  software_entr_l23;              // Instructs PM Protocol FSM to go into L23
output                  pm_aspm_l0s_en;                 // Indicates to the PM Protocol FSM that L0s ASPM is enabled
output                  pm_aspm_l1_en;                  // Indicates to the PM Protocol FSM that L1 ASPM is enabled
output logic                    pm_xtlh_block_tlp;      // Instructs XTLH to block any new TLPs
output logic [NF-1:0]           pm_radm_block_tlp;      // Instructs RADM receive filter to reject TLPs other than CFG/MSG
output                  pm_req_dwsp_turnoff;            // Request downstream port to send turnoff message
output                  pm_xmt_turnoff;                 // Request this port to send turnoff message
output  [NF-1:0]        pm_xmt_to_ack;                  // Request this port to transmit TOACK message
output  [NF-1:0]        pm_xmt_pme;                     // Request this port to transmit PME message
output                  pm_turnoff_timeout;             // Turnoff message has timeout without received TO ACK (for RC and downstream port switch only)
output  [NF-1:0]        pm_status;                      // PM Status reg (registered under AUX power)
output                  pm_pme_exit_l1;                 // pme requests pm_active to exit L1
output                  pm_pme_resend_flag;
output                  pm_l2_entry_flag;               // L2 entry negotiation has been initiated this flag will be used to insure L2/L3 entry negotiation
                                                        // starts before any further L0S/L1 entry is initiated
output                  pm_wake_l2_exit;                // L2 exit wakeup request from PME Controller
// ------------- IO declarations ----------------------------------
wire                    pm_l2_entry_flag;
reg     [NF-1:0]        pm_xmt_to_ack;
reg                     pm_xmt_turnoff;
reg     [NF-1:0]        pm_status;
reg     [NF-1:0]        int_pm_status;

reg                     pm_req_dwsp_turnoff;
reg                     link_reactivate;
reg                     int_pme_nego_done;
reg                     pm_turnoff_timer_en;

// ------------- Internal signal declarations ----------------------------------
reg     [3:0]           state;
reg     [NF-1:0]        pme_timer_timeout;
reg     [NF-1:0]        int_pme_cap_vec;
wire                    pm_turnoff_timeout;
wire                    pm_turnoff_timeout_int;
reg                     done_rst;
wire                    in_idle_linkup;
wire                    aux_clk_en_1us;
logic                   perst_n_posedge_r;
// -----------------------------------------------------------------------------
wire    [31:0]          PME_BASETIMER_4MS ;
wire    [31:0]          PME_BASE_TIMER_TIMEOUT_VALUE ;


// ----------------------------------------------------------------------------
// Wake up event.
// ----------------------------------------------------------------------------
// There are two conditions that we may want to generated beacon on our transmitter
// 1. when PME state controls to reactivate the link
// 2. when any downstream port of switch device has exit from L23.
assign pm_wake_l2_exit = link_reactivate || (one_dwsp_exit_l23 && upstream_port && switch_device);

// ----------------------------------------------------------------------------
// Condition to enter L1
// ----------------------------------------------------------------------------
parameter PM_D0_UINI    = 3'b100;
parameter PM_D0_ACT     = 3'b000;
parameter PM_D1         = 3'b001;
parameter PM_D2         = 3'b010;
parameter PM_D3         = 3'b011;

logic [NF-1:0]        pm_dstate_d0_uninit;
logic [NF-1:0]        pm_dstate_d0_act;
logic [NF-1:0]        pm_dstate_d0;                   // PM_DSTATE of D0 unified for all functions
logic [NF-1:0]        pm_dstate_d1;                   // PM_DSTATE of D1 unified for all functions
logic [NF-1:0]        pm_dstate_d2;                   // PM_DSTATE of D2 unified for all functions
logic [NF-1:0]        pm_dstate_d3;                   // PM_DSTATE of D3 unified for all functions

logic [2:0]      tmp_vec1;

assign pm_dstate_d0 = pm_dstate_d0_uninit | pm_dstate_d0_act;

always @(pm_pmstate) begin : PM_DSTATE_2

    integer i,j;

    for (i=0; i<NF; i=i+1) begin
        for (j=0; j<3; j=j+1)
            tmp_vec1[j]  = pm_pmstate[(3*i)+j];

        if (tmp_vec1 == PM_D0_UINI)
            pm_dstate_d0_uninit[i] = 1'b1;
        else
            pm_dstate_d0_uninit[i] = 1'b0;

        if (tmp_vec1 == PM_D0_ACT)
            pm_dstate_d0_act[i] = 1'b1;
        else
            pm_dstate_d0_act[i] = 1'b0;

        if (tmp_vec1 == PM_D1)
            pm_dstate_d1[i] = 1'b1;
        else
            pm_dstate_d1[i] = 1'b0;

        if (tmp_vec1 == PM_D2)
            pm_dstate_d2[i] = 1'b1;
        else
            pm_dstate_d2[i] = 1'b0;

        if (tmp_vec1 == PM_D3)
            pm_dstate_d3[i] = 1'b1;
        else
            pm_dstate_d3[i] = 1'b0;
    end
end // PM_DSTATE_2


// when power management D1 or deeper state is programmed
assign software_entr_l1  = upstream_port && (&(pm_dstate_d1 | pm_dstate_d2 | pm_dstate_d3));

// ----------------------------------------------------------------------------
// Condition to enter L23
// ----------------------------------------------------------------------------
assign software_entr_l23 = int_pme_nego_done && app_ready_entr_l23;

// ----------------------------------------------------------------------------
// Enabling ASPM for L0s and L1
// ----------------------------------------------------------------------------
// power D state determines the link permission of entering into L0s, L1,
// L2 and L3 state. Below signals are the enable signals used to enable the
// link state enter. The condition of entering l-state is determined as
// following:
// 1. According to spec. table 5-2 of section 5.3.2:
//      D0   -----    L0, L0s and L1
//      D1   -----    L1
//      D2   -----    L1
//      D3hot-----    L1, L2/3 ready
//      D3code ---    L2, L3
// 2. When ASPM control (i.e cfg_aslk_pmctrl) is programmed:
//      00   -----    Non ASPM enter L0s or L1
//      01   -----    L0s by ASPM
//      10   -----    L1 by ASPM
//      11   -----    L0s and L1 by ASPM
reg [NF-1:0]   l0s_aspm_en_vec;
reg [NF-1:0]   l1_aspm_en_vec;

always @(pm_aslk_pmctrl or pm_dstate_d0_act or pm_dstate_d1 or pm_dstate_d2 or pm_dstate_d3) begin : L0S_ASPM

    integer i;
    reg [NF-1:0] l0s_pf_en_vec;

    for (i=0; i<NF; i=i+1) l0s_pf_en_vec[i] = pm_aslk_pmctrl[(i*2)];

    for (i =0; i < NF; i=i+1) begin
        // only the function has D0 state has effect on l0s enable
        // when all function's Dstate is programmed to active, and all functions ASPM l0s is enabled, then the l0s is enabled
        l0s_aspm_en_vec[i] = (pm_dstate_d0_act[i] & l0s_pf_en_vec[i]) | ((pm_dstate_d1[i] | pm_dstate_d2[i] | pm_dstate_d3[i]) & (|l0s_pf_en_vec));
    end
end

always @(pm_aslk_pmctrl or pm_dstate_d0_act or pm_dstate_d1 or pm_dstate_d2 or pm_dstate_d3) begin : L1_ASPM

    integer i;
    reg [NF-1:0] l1_pf_en_vec;

    for (i=0; i<NF; i=i+1) l1_pf_en_vec[i] = pm_aslk_pmctrl[(i*2)+1];

    for (i =0; i < NF; i=i+1) begin
        l1_aspm_en_vec[i] = (pm_dstate_d0_act[i] & l1_pf_en_vec[i]) | ((pm_dstate_d1[i] | pm_dstate_d2[i] | pm_dstate_d3[i]) & (|l1_pf_en_vec));
    end
end

assign pm_aspm_l0s_en = upstream_port ? (&l0s_aspm_en_vec) : l0s_aspm_en_vec[0];          // when all functions that has aspm l0s enable, then it can go into l0s state

assign pm_aspm_l1_en  = upstream_port ? (&l1_aspm_en_vec) : l1_aspm_en_vec[0];           // when all L1 is enabled by all funcations, then it can go into L1 state

// ----------------------------------------------------------------------------
// D-states and Virtual Functions
// ----------------------------------------------------------------------------

always @(posedge aux_clk or negedge pwr_rst_n) begin
    if (!pwr_rst_n) begin
        pm_xtlh_block_tlp       <= #TP '0;
        pm_radm_block_tlp       <= #TP '0;
    end else begin
        pm_xtlh_block_tlp       <=  #TP ((&(pm_dstate_d1 | pm_dstate_d2 | pm_dstate_d3)) & upstream_port);
    
        // This signal instruct the receive filter to reject TLPs other than CFG/MSG
        // Reject during D1, D2 or D3hot state. (D3cold doesn't matter since no power anyways)
        pm_radm_block_tlp       <= #TP (pm_dstate_d1 | pm_dstate_d2 | pm_dstate_d3) & {NF{upstream_port}};
    end
end
// ----------------------------------------------------------------------------


assign  PME_BASETIMER_4MS            =   PME_BASETIMER_4MS_INT ;
assign  PME_BASE_TIMER_TIMEOUT_VALUE =   PME_BASE_TIMER_TIMEOUT_VALUE_INT ;

reg     [NF-1:0]    nhp_pme_det_d;
always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if (!pwr_rst_n)
        nhp_pme_det_d   <= #TP 0;
    else
        nhp_pme_det_d   <= #TP nhp_pme_det;
end

reg  pl_state_active_d;
wire smlh_enter_l0_pulse;

assign smlh_enter_l0_pulse = (pl_state_active && !pl_state_active_d);

always @(posedge aux_clk or negedge pwr_rst_n) begin : pl_state_active_d_PROC
    if ( ~pwr_rst_n ) begin
        pl_state_active_d <= #TP 0;
    end else begin
        pl_state_active_d <= #TP pl_state_active;
    end
end //always


// possible power management events that trigger a PME:
// 1. apps_pm_xmt_pme is triggered by application who wants to get out of L1
// 2. nhp_pme_det is triggered by native hot plug event - only when device is in D1, D2 or D3hot
// 3. outband_pwrup_cmd is triggered by application's WOL event

wire [NF-1:0] int_nhp_pme_det;
assign int_nhp_pme_det = (~nhp_pme_det_d & nhp_pme_det) & {NF{(pm_dstate_d1 | pm_dstate_d2 | pm_dstate_d3 | (state == NON_COMMUNICATING))}};  


reg [NF-1:0] pm_event_req_wo_en;
wire [NF-1:0] wakeup_event;
wire          pm_pme_exit_l1;
wire [NF-1:0] pm_event_req;
// 2 pm_event_req are required since PME_Status gets updated regardless PME is enabled or not.
assign wakeup_event = (apps_pm_xmt_pme  | int_nhp_pme_det | outband_pwrup_cmd) & int_pme_cap_vec;

assign pm_pme_exit_l1 =     (|pm_xmt_pme) 
                         || ((apps_pm_xmt_turnoff || pm_turnoff_timer_en) && !upstream_port)   // if we need to transmit a turn off message we need to restore the clock if unavailable - RC wants to go to L2, it sends PME VDM message
                         || (upstream_port && switch_device && all_dwsp_rcvd_toack_msg)        // when UP SP and all downstream ports have acknowledged turnoff
                         ;

assign pm_event_req = pm_status & pm_pme_en;

// when device is programmed to enable the power management message event
// generation, according to spec, the capability of PME of each D state will allow to issue pme
// event message.
//
always @(pm_dstate_d0 or pm_dstate_d1 or pm_dstate_d2 or pm_dstate_d3 or pm_pme_cap)
begin : update_pme_cap_vec

    integer i;

    for (i=0; i<NF; i=i+1)
         int_pme_cap_vec[i] = (pm_dstate_d0[i] & pm_pme_cap[5*i])     | // D0 
                              (pm_dstate_d1[i] & pm_pme_cap[(5*i)+1]) | // D1
                              (pm_dstate_d2[i] & pm_pme_cap[(5*i)+2]) | // D2
                              (pm_dstate_d3[i] & pm_pme_cap[(5*i)+3]) | // D3hot
                              (pm_dstate_d3[i] & pm_pme_cap[(5*i)+4]) ; // D3cold
end




wire int_radm_pm_turnoff;
wire int_radm_pm_turnoff_hs_inprogress;

assign int_radm_pm_turnoff = radm_pm_turnoff;
assign int_radm_pm_turnoff_hs_inprogress = radm_pm_turnoff;




//-------------------------------------------------------------------------------
// Beneath are the processes that shadows with CDM register bits to preserve
// the value during power down when AUX power is supplied
// When this port logic is used in a device that allows PME from D3 cold,
// Then the status and enable bit should be reserved under aux power at D3
// cold. Such that software can read it back after wakeing up from D3 cold.
// Those bits are shadow of the registers in CDM
// RC device will not have to wait for an event to be sent and its status
//-------------------------------------------------------------------------------

always @(posedge aux_clk or negedge pwr_rst_n)
begin : update_pm_status

    integer i;

    if (!pwr_rst_n) begin
        pm_status       <= #TP '0;
        int_pm_status   <= #TP '0;
    end
    else begin
        for (i=0; i<NF; i=i+1) begin
            if (cfg_pmstatus_clr[i]) begin         // function 0 is the one that generates PME, therefore, it should be clear on func0
            // when fuction do not support D3 cold to PME then status set to 0
            // when assert, it is independent from PME_EN bit and it is
            // determined by device wanting to issue a PME to wake up
            // Note: writing 0 to this bit has not effect
            // disable of PME from D3cold should not block the pm_status signal as it may be enabled in D1/D2
                pm_status[i]    <= #TP 1'b0;
                int_pm_status[i]<= #TP 1'b0;
            end
            else begin
                // This PME Status is the one going to Config space register
                // Updated regardless of PME Enable
                if (pm_event_req_wo_en[i])
                  pm_status[i]    <= #TP 1'b1;

                // This PME Status is used internally when sending PME is enabled
                if ((state == PME_SEND) && pm_event_req[i] && !int_radm_pm_turnoff_hs_inprogress)
                  int_pm_status[i]<= #TP 1'b1;
            end
        end
    end
end


always @(posedge aux_clk or negedge pwr_rst_n)
begin : core_rst_is_done
    if (!pwr_rst_n) begin
        done_rst    <= #TP 1'b0;
    end
    else begin
        done_rst    <= #TP int_radm_pm_turnoff_hs_inprogress ? 1'b0 : pm_core_rst_done ? 1'b1 : done_rst;
    end
end

// Need to make sure that we move to PME_SEND state after link is up.
// Since pl_link_up is powered by main power, need to know that the PM
// current state is in IDLE, core_rst_n has happened
// and we see pl_link_up goes up to ensure we're using the pl_link_up when
// it's powered my main power.
assign in_idle_linkup = pm_prot_idle_flag && done_rst && pl_link_up;


// Latch the wakeup event and only clear when we link back up after low power state
always @(posedge aux_clk or negedge pwr_rst_n)
begin : latch_wakeup_event
    integer i;

    if (!pwr_rst_n)
        pm_event_req_wo_en  <= #TP 0;
    else begin
        for (i=0; i<NF; i=i+1)
            pm_event_req_wo_en[i]   <= #TP wakeup_event[i] ? 1'b1 : (in_idle_linkup || pm_pme_grant[i]) ? 1'b0 : pm_event_req_wo_en[i];
    end
end


// delay perst_n_posedge to 1 clock cycle
always_ff @(posedge aux_clk or negedge pwr_rst_n) begin
  if(!pwr_rst_n) begin
    perst_n_posedge_r <= #TP 1'b0;
  end else begin
    perst_n_posedge_r <= #TP perst_n_posedge;
  end
end

always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if (!pwr_rst_n)
        state                           <= #TP COMMUNICATING;
    else
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Disable this check on legacy code. 
        case(state)
// spyglass enable_block STARC05-2.11.3.1
        COMMUNICATING:
            if (int_radm_pm_turnoff & switch_device)
                state                   <= #TP COMM_REQ_TURNOFF_DWSP;
            else if (int_radm_pm_turnoff)
                state                   <= #TP COMM_SEND_ACK;
            else if (|pm_event_req)
                state                   <= #TP PME_SEND;
            else
                state                   <= #TP COMMUNICATING;

        PME_SEND:
            //This is a PME send state of 1.0a spec. page 241.
            //If we received any pm turn off, we need to send PME ACK and
            //go into power down state
            if (int_radm_pm_turnoff & switch_device)
                state                   <= #TP PME_REQ_TURNOFF_DWSP;
            else if (int_radm_pm_turnoff)
                state                   <= #TP PME_SEND_ACK;
            else if (!int_radm_pm_turnoff_hs_inprogress)
                state                   <= #TP PME_SEND_STATUS_WAIT;
            else
                state                   <= #TP PME_SEND;


        PME_SEND_STATUS_WAIT:
            //THis is a PME send state of 1.0a spec. page 241.
            if (int_radm_pm_turnoff & switch_device)
                state                   <= #TP PME_REQ_TURNOFF_DWSP;
            else if (int_radm_pm_turnoff)
                state                   <= #TP PME_SEND_ACK;
            else if (|pme_timer_timeout)
                state                   <= #TP PME_SEND;
            // when software turn off the status of PME bit
            else if (~(|int_pm_status))
                state                   <= #TP COMMUNICATING;
            else
                state                   <= #TP PME_SEND_STATUS_WAIT;

        COMM_REQ_TURNOFF_DWSP:
            // This port request a PME turnoff message being transmitted to
            // all downstream port
            // ccx_line_begin: ;"Redundant code for non switch configurations"
            if (all_dwsp_rcvd_toack_msg)
                state                   <= #TP COMM_SEND_ACK;
            // ccx_line_end

        COMM_SEND_ACK:
            // This port request a PME TO ACK message being transmitted
            // from communication state
            if (xdlh_xmt_pme_ack || !perst_n)
                state                   <= #TP NON_COMMUNICATING;

        PME_SEND_ACK:
            // This port request a PME TO ACK message being transmitted
            // from PME SENT state
            if (xdlh_xmt_pme_ack || !perst_n)
                state                   <= #TP LINK_REACTIVATION;

        PME_REQ_TURNOFF_DWSP:
            // This port request a PME TURN OFF message being transmitted
            // to all downstream ports
            if (all_dwsp_rcvd_toack_msg)
            // ccx_line_begin: ;"Redundant code for non switch configurations"
                state                   <= #TP PME_SEND_ACK;
            // ccx_line_end


        NON_COMMUNICATING:
            if (|pm_event_req)
                state                   <= #TP LINK_REACTIVATION;
            else if ( pm_smlh_l23_exit || (!int_pme_nego_done && smlh_enter_l0_pulse) || perst_n_posedge_r)
            //after sending PME_To_Ack, PME enters L2 (NON_COMMUNICATING) state. But Core may not enter L2 state but the other states.
            //In this case, need enter_l0 signal (smlh_enter_l0_pulse) to wake up PME L2 (NON_COMMUNICATING) state if pme negotiation done is cleared.
            //Do not move out NON_COMMUNICATING if LTSSM L0 is caused by L0s.
                state                   <= #TP COMMUNICATING;

        LINK_REACTIVATION:
            if (in_idle_linkup)
                state                   <= #TP PME_SEND;

        default: state                  <= #TP COMMUNICATING;
        endcase
end

// Request to transmit a PM_PME message if PME_SEND state is entered and PME_Status it set to 1.
// Clear the request if the message gen grants the request.
reg                 int_pme_send_r;
wire  [NF - 1 : 0]  int_pm_req_pme;

always @(posedge aux_clk or negedge pwr_rst_n) begin : int_pme_send_PROC
  if (!pwr_rst_n)
    int_pme_send_r <= #TP 1'b0;
  else
    int_pme_send_r <= #TP (state == PME_SEND);
end : int_pme_send_PROC

assign int_pm_req_pme = {NF{int_pme_send_r}} & int_pm_status; 

pm_flag
 #(
  .INST (INST)
) u_pm_xmt_pme[NF - 1 : 0] (
  // Inputs
  .clk    (aux_clk),
  .rst_n  (pwr_rst_n),
  .clear  (pm_pme_grant),
  .set    (int_pm_req_pme),
  // Outputs
  .flag_r (pm_xmt_pme)
);


always @(posedge aux_clk or negedge pwr_rst_n)
begin : update_pm_xmt

    integer i;

    if (!pwr_rst_n) begin
        pm_xmt_turnoff          <= #TP 0;
        pm_req_dwsp_turnoff     <= #TP 0;
        pm_xmt_to_ack           <= #TP 0;
        link_reactivate         <= #TP 1'b0;
    end else begin

        // a power management of turnoff should be issued under following
        // conditions:
        // 1. when this is a rc port and app required to send pm turnoff
        // 2. wehn this is a downstream port of a switch and upstream
        // received power management turn off message
        if (apps_pm_xmt_turnoff)
          pm_xmt_turnoff              <= #TP 1'b1;
        else if (pme_turn_off_grt | !perst_n)
          pm_xmt_turnoff              <= #TP 1'b0;

        // notify the downstream port to issue a broadcast turnoff
        // message

        pm_req_dwsp_turnoff         <= #TP (state == PME_REQ_TURNOFF_DWSP) | (state == COMM_REQ_TURNOFF_DWSP);


//RC device will not send ACK since it is not allowed to receive turnoff

        // send ack message when request of turnoff has been received
        // Only need to send from one function
        for (i=0; i<NF; i=i+1) begin
            if (i == 0) begin
                if (((state == COMMUNICATING) | (state == PME_SEND) | (state == PME_SEND_STATUS_WAIT)) & !switch_device & int_radm_pm_turnoff)    
                    pm_xmt_to_ack[i]    <= #TP 1'b1;
                // ccx_line_begin: ;"Redundant code for non switch configurations"
                else if (  ((state == PME_REQ_TURNOFF_DWSP) & all_dwsp_rcvd_toack_msg)
                         | ((state == COMM_REQ_TURNOFF_DWSP) & all_dwsp_rcvd_toack_msg))    // transition states
                    pm_xmt_to_ack[i]    <= #TP 1'b1;
                // ccx_line_end
                else if(pme_to_ack_grt == 1 || !perst_n)
                    pm_xmt_to_ack[i]    <= #TP 1'b0;
            end else begin
                pm_xmt_to_ack[i]    <= #TP 1'b0;
            end
        end

        link_reactivate             <= #TP (state == LINK_REACTIVATION);
    end
end

// Get the nego done cycle as fast as we can to guide master state of
// pm_active_ctrl to go into L23 transition
always @(posedge aux_clk or negedge pwr_rst_n)
begin : PME_NEGO_STATUS
    if (!pwr_rst_n)
        int_pme_nego_done           <= #TP 1'b0;
    // Reset int_pme_nego_done is perst_n is asserted before L2 entry completed
    // or if the link goes down during L2 negotiation
    else if (!perst_n || !pl_link_up)
        int_pme_nego_done           <= #TP 1'b0;
    else if (int_pme_nego_done & pm_xdlh_enter_l23)
        int_pme_nego_done           <= #TP 1'b0;
    else if (((state == COMM_SEND_ACK) | (state == PME_SEND_ACK)) & xdlh_xmt_pme_ack)
        int_pme_nego_done           <= #TP 1'b1;
end

// Create a flag to indicate L2 entry process has started.
// The flag is set when PME_TO_ACK message is sent in response to PME_Turn_OFF message.
// The flag is cleared when PM_Enter_L23 DLLP is sent or PHY is reset
wire int_clear_l2_entry_flag;
assign int_clear_l2_entry_flag = pm_xdlh_enter_l23 || !perst_n;
pm_flag
 #(
  .INST (INST)
) u_l2_entry_flag (
  // Inputs
  .clk    (aux_clk),
  .rst_n  (pwr_rst_n),
  .clear  (int_clear_l2_entry_flag),
  .set    (|pm_xmt_to_ack),
  // Outputs
  .flag_r (pm_l2_entry_flag)
);

// enable pm turn off timer
always @(posedge aux_clk or negedge pwr_rst_n)
begin : PM_TURN_OFF_TIMER_ENABLE
    if (!pwr_rst_n)
        pm_turnoff_timer_en           <= #TP 0;
    else if (!perst_n)
        pm_turnoff_timer_en           <= #TP 0;     
    else if (apps_pm_xmt_turnoff)
        pm_turnoff_timer_en           <= #TP 1'b1;
    else if (pm_turnoff_timeout | radm_pm_to_ack)
        pm_turnoff_timer_en           <= #TP 0;
end

reg     [PME_BASE_TIMER_WD-1 :0]    pme_base_timer;
wire    [PME_BASE_TIMER_WD-1 :0]    int_pme_base_timer_incr;
reg     [PME_PRESCALE_TIMER_WD-1:0] pme_prescale_timer [NF -1:0];
integer                             j;
wire                                pme_base_timer_timeout;

wire timer2;
DWC_pcie_tim_gen
 #(
    .CLEAR_CNTR_TO_1 (0)
) u_gen_timer2
(
     .clk               (aux_clk)
    ,.rst_n             (pwr_rst_n)
    ,.current_data_rate (current_data_rate)
    ,.clr_cntr          (1'b0)        // clear cycle counter(not used in this timer)
    
    ,.cnt_up_en         (timer2)  // timer count-up 
);

always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if (!pwr_rst_n) begin
        pme_base_timer  <= #TP 0;
    end else if ((pme_base_timer_timeout & upstream_port) | ((radm_pm_to_ack | pm_turnoff_timeout) & !upstream_port)) begin
        pme_base_timer  <= #TP 0;
    end else if (|int_pm_status | pm_turnoff_timer_en) begin
        pme_base_timer  <= #TP aux_clk_active ? (pme_base_timer + (aux_clk_en_1us ? int_pme_base_timer_incr : 1'b0)) : (pme_base_timer + (timer2 ? 1'b1 : 1'b0));
    end
end

assign int_pme_base_timer_incr = ({PME_BASE_TIMER_WD{1'b1}} - pme_base_timer) >= 63 ? 63 : ({PME_BASE_TIMER_WD{1'b1}} - pme_base_timer);

// PM turn off timer is designed for 1-10 ms
assign pm_turnoff_timeout_int   = pme_base_timer[PME_BASETIMER_4MS_INT] ; // for 4-8ms

assign pm_turnoff_timeout     = upstream_port ? 1'b0 : pm_turnoff_timeout_int ; // for 4-8ms

wire   [PME_BASE_TIMER_WD-1 :0]        pme_base_timer_value_wire;
assign pme_base_timer_value_wire = PME_BASE_TIMER_TIMEOUT_VALUE[(PME_BASE_TIMER_WD - 1) : 0];
wire   [PME_PRESCALE_TIMER_WD-1 :0]    prescale_timer_value_wire;

assign prescale_timer_value_wire = PME_PRESCALE_TIMEOUT_VALUE;

assign pme_base_timer_timeout = (pme_base_timer >= pme_base_timer_value_wire) & upstream_port; 

always @(posedge aux_clk or negedge pwr_rst_n)
begin
    if (!pwr_rst_n) begin
        for (j=0; j<NF; j=j+1)
            pme_prescale_timer[j]       <= #TP 0;
    end
    else if (state == PME_SEND) begin
        for (j=0; j<NF; j=j+1)
            if (int_pm_status[j])
                pme_prescale_timer[j]   <= #TP 0;
    end
    else if (pme_base_timer_timeout) begin
        for (j=0; j<NF; j=j+1)
            if (int_pm_status[j])
                pme_prescale_timer[j]   <= #TP pme_prescale_timer[j] + 1;  
    end
end

always @(posedge aux_clk or negedge pwr_rst_n)
    if (!pwr_rst_n)
        pme_timer_timeout           <= #TP 0;
    else
        if (state == PME_SEND) begin
            for (j=0; j<NF; j=j+1)
                if (int_pm_status[j]) begin
                    pme_timer_timeout[j]    <= #TP 0;
                end
        end
        else begin
            for (j=0; j<NF; j=j+1)
                pme_timer_timeout[j]    <= #TP (pme_prescale_timer[j] == prescale_timer_value_wire);
        end

reg pm_pme_resend_flag;

always @(posedge aux_clk or negedge pwr_rst_n)
    if (!pwr_rst_n)
        pm_pme_resend_flag <= #TP 0;
    else if(state== PME_SEND_STATUS_WAIT) begin
        if (int_radm_pm_turnoff_hs_inprogress)
            pm_pme_resend_flag <= #TP 0;
        else if (|pme_timer_timeout)
            pm_pme_resend_flag <= #TP 1;
    end else begin
        pm_pme_resend_flag <= #TP 0;
    end

pm_active_ctrl_aux_timer
 u_pm_active_ctrl_aux_timer (
// ---- inputs ---------------
    .aux_clk                     (aux_clk),
    .pwr_rst_n                   (pwr_rst_n),
    .aux_clk_freq                (pm_pl_aux_clk_freq),
    // Switch to timer that runs on core_clk_ug to keep 1us duration
    .timer2                      (timer2),
    .aux_clk_active              (aux_clk_active),

// ---- outputs ---------------
    .en_1us                      (aux_clk_en_1us)
);

`ifndef SYNTHESIS
//VCS coverage off
wire    [13*8:0]         STATE;

assign  STATE   =  (state == COMMUNICATING        ) ? "COMMUNICATING" :
                   (state == COMM_SEND_ACK        ) ? "COMM_SEND_ACK" :
                   (state == COMM_REQ_TURNOFF_DWSP) ? "COMM_REQ_TOFF" :
                   (state == PME_SEND             ) ? "PME_SEND" :
                   (state == PME_SEND_ACK         ) ? "PME_SEND_ACK" :
                   (state == PME_REQ_TURNOFF_DWSP ) ? "PME_REQ_TOFF" :
                   (state == PME_SEND_STATUS_WAIT ) ? "PME_SEND_WAIT" :
                   (state == NON_COMMUNICATING    ) ? "NON_COMM" :
                   (state == LINK_REACTIVATION    ) ? "LINK_REACTV" : "BGS";
//VCS coverage on
`endif // SNPS_ASSERT_ON

endmodule
