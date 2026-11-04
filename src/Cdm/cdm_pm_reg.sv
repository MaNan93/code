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
// ---    $DateTime: 2023/06/26 08:32:07 $
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_pm_reg.sv#10 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the PM capability registers.
// --- Both PF and VF implementations are supported, selected via the VF_IMPL parameter.
// --- The difference between the two implementations is in the handling of the next 
// --- pointer field:
// ---  - flip-flops DBI writeable for PFs
// ---  - hardcoded value for VFs 
// --- Also, the following fields are not writeable for VFs and are instead
// --- inherited from the VF's associted PF:
// ---  - PME_Support
// ---  - D2_Support
// ---  - D1_Support
// ---  - Aux_Current
// ---  - DSI
// ---  - Version
// ---  - No_Soft_Reset
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_pm_reg (
// -- inputs ---
    core_clk,
    non_sticky_rst_n,
   sticky_rst_n,
   cdm_clk_g,
    flr_rst_n,
    lbc_cdm_data,
    lbc_cdm_dbi,
    pm_write_pulse,
    pm_reg_id,
    aux_pwr_det,
    pm_status,
    pm_pme_en,
    d0_active_detect,
    pme_support,
    pm_d2_support,
    pm_d1_support,
    pm_no_soft_rst,
    app_ltr_msg_req,
    msg_ltr_det,
   ltr_m_en_fn0,
   msgg2cdm_ltr_clr_msg_grant,
   cdmpl2cfg_ltr_rq,
   rdlh_link_up,
   upstream_port,
   cfg_disable_ltr_clr_msg,
    cxl_rcrb_enable,
// -- outputs --
    cfg_upd_pmcsr,
    cfg_pmstatus_clr,
    cfg_pmstate,
    cfg_pme_en,
    cfg_pme_cap,
    cfg_pm_no_soft_rst,
    pm_ltr_clr_msg_req,
    pm_reg_data,
    cfg_upd_pme_cap
);
parameter INST          = 0;                    // The uniquifying parameter for each port logic instance.
parameter FUNC_NUM      = 0;                    // uniquifying parameter per function
parameter VF_IMPL       = 0;                    // 0: PF impl. 1: VF impl.
parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)
parameter RCRB          = 0;                            // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space
localparam PME_SUPPORT           = VF_IMPL ? 5'b00000        : `PME_SUPPORT;
localparam D2_SUPPORT            = VF_IMPL ? 1'b0            : `D2_SUPPORT;
localparam D1_SUPPORT            = VF_IMPL ? 1'b0            : `D1_SUPPORT;
localparam AUX_CURRENT           = VF_IMPL ? 3'b000          : `AUX_CURRENT;
localparam DEV_SPEC_INIT         = VF_IMPL ? 1'b0            : `DEV_SPEC_INIT;
localparam PMC_VERSION           = VF_IMPL ? 3'b000          : `PMC_VERSION;
localparam PM_NEXT_PTR           = VF_IMPL ? `VF_PM_NEXT_PTR : (1)? `PM_NEXT_PTR : 0 ; // Next capability pointer
localparam DEFAULT_NO_SOFT_RESET = VF_IMPL ? 1'b0            : `DEFAULT_NO_SOFT_RESET;

// -------------- Inputs ---------------
input           core_clk;                       // Core Clock
input           non_sticky_rst_n;               // Non-Sticky Reset
input           sticky_rst_n;                   // Sticky Reset
input           cdm_clk_g;                      // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
input           flr_rst_n;                      // Function Level Reset
input   [31:0]  lbc_cdm_data;                   // Write Data 
input           lbc_cdm_dbi;                    // DBI Access
input   [3:0]   pm_write_pulse;                 // Write Byte Enables
input   [1:0]   pm_reg_id;                      // PM Register ID : [0] - PMC [1] - PMCSR
input           aux_pwr_det;                    // Aux Power is detected by the device
input           pm_status;                      // PME_Status, sticky bit preserved in Power Management Controller
input           pm_pme_en;                      // PME_En, sticky bit preserved in Power Management Controller
input           d0_active_detect;               // detect write 1 to cfg_bus_master_en, cfg_io_space_en or cfg_mem_space_en
input   [4:0]   pme_support;                    // PME_Support, inherited by VFs from PF
input           pm_d2_support;                  // D2_Support, inherited by VFs from PF
input           pm_d1_support;                  // D1_Support, inherited by VFs from PF
input           pm_no_soft_rst;                 // No_Soft_Reset, inherited by VFs from PF. 
input           app_ltr_msg_req;                // LTR message request - from Application interface
input           msg_ltr_det;                    // LTR message grant   - from Message Generation (msg_gen) module
input           ltr_m_en_fn0;                   // LTR Mechanism enable, function 0.
input           msgg2cdm_ltr_clr_msg_grant;     // LTR clear message grant pulse 
input           cdmpl2cfg_ltr_rq;               // Port logic to PCIe configuration OR'ed LTR message requirement bits
input           rdlh_link_up;                   // Data link status; 0=DL_Down; 1=DL_Up
input           upstream_port;                  // Device upstream port
input           cfg_disable_ltr_clr_msg;        // Disable Autonomous LTR clear message
input           cxl_rcrb_enable;                // Indicates that the CXL 1.1 Link is up
// -------------- Outputs --------------
output          cfg_upd_pmcsr;                  // Update PMCSR sticky bits in Power Management Controller
output          cfg_pmstatus_clr;               // Clear PME_Status bit in Power Management Controller
output  [2:0]   cfg_pmstate;                    // Power state (D0uninit,D0active,D1,D2,D3)
output          cfg_pme_en;                     // PME_En value to be stored in Power Management Controller
output  [4:0]   cfg_pme_cap;                    // PME Capabilities
output          cfg_pm_no_soft_rst;             // No_Soft_Reset
output          pm_ltr_clr_msg_req;             // LTR clear message request
output  [31:0]  pm_reg_data;                    // PM register read data
output          cfg_upd_pme_cap;                // Update cfg_pme_cap register in pm_ctrl block

reg             cfg_upd_pmcsr;
reg             cfg_pmstatus_clr; 
reg     [2:0]   pmstate;
reg             cfg_pme_en;
wire    [4:0]   cfg_pme_cap;
wire            cfg_pmstate_d3hot_to_d0;       // Indicates a transition from D3hot to D0
wire [2:0]      cfg_pmstate;                   
wire            int_upd_pme_cap;
wire            app_ltr_msg_req;                // LTR message request - from Application interface
wire            msg_ltr_det;                    // LTR message grant   - from Message Generation (msg_gen) module
wire            pm_ltr_clr_msg_req;

wire    [7:0]   cfg_reg_67, cfg_reg_66, cfg_reg_65, cfg_reg_64;
wire    [7:0]   cfg_reg_71, cfg_reg_70, cfg_reg_69, cfg_reg_68;
reg             cfg_upd_pme_cap;
wire            int_upd_pme_en;
wire            int_lbc_pme_en;
wire            int_pm_pme_en;

// -----------------------------------------------------------------------------
// Power Management Capabilities (PMC) Register
// -----------------------------------------------------------------------------
// pm_reg_id        - 0
// PCIE Offset      - `CFG_PM_CAP
// length           - 4 byte
// Cfig register    - cfg_reg_64, cfg_reg_65, cfg_reg_66, cfg_reg_67
// -----------------------------------------------------------------------------
reg  [4:0]   cfg_pme_support;
reg          cfg_pm_d2_support_reg;
wire         cfg_pm_d2_support;
reg          cfg_pm_d1_support_reg;
wire         cfg_pm_d1_support;
reg  [2:0]   cfg_pm_aux_current_reg;
wire [2:0]   cfg_pm_aux_current;
reg          cfg_pm_dsi_reg;
wire         cfg_pm_dsi;
reg  [2:0]   cfg_pmc_version_reg;
wire [2:0]   cfg_pmc_version;
reg  [7:0]   cfg_pm_next_ptr;

reg cfg_pm_imm_d0_reg;
wire cfg_pm_imm_d0;

// Bit fields inherited by VF from associated PF
assign cfg_pm_d2_support  = VF_IMPL ? pm_d2_support            : cfg_pm_d2_support_reg;
assign cfg_pm_d1_support  = VF_IMPL ? pm_d1_support            : cfg_pm_d1_support_reg;
assign cfg_pm_aux_current = VF_IMPL ? 3'b000                   : cfg_pm_aux_current_reg;
assign cfg_pm_dsi         = VF_IMPL ? 1'b0                     : cfg_pm_dsi_reg;
assign cfg_pmc_version    = VF_IMPL ? 3'b000                   : cfg_pmc_version_reg;

    assign cfg_pm_imm_d0 = cfg_pm_imm_d0_reg;


// Determine Power States from which function is capable of generating PM_PME Messages
assign cfg_pme_cap  = VF_IMPL ? {1'b0, pme_support[3:0]}                  // Inherited from PF, except VFs do not support D3cold
                              : {cfg_pme_support[4] & aux_pwr_det,        // D3cold - only supported if Aux Power detected
                                 cfg_pme_support[3],                      // D3hot
                                 cfg_pme_support[2] & cfg_pm_d2_support,  // D2
                                 cfg_pme_support[1] & cfg_pm_d1_support,  // D1
                                 cfg_pme_support[0]};                     // D0

// Power Management Capabilities (PMC) Register
assign {cfg_reg_67, cfg_reg_66} = {cfg_pme_cap,         // [15:11] PME Support 
                                   cfg_pm_d2_support,   // [10]    D2 Support
                                   cfg_pm_d1_support,   // [9]     D1 Support
                                   cfg_pm_aux_current,  // [8:6]   AUX Current
                                   cfg_pm_dsi,          // [5]     Device Specific Initialization
                                   cfg_pm_imm_d0,       // [4]     Immediate Readiness on return to D0
                                   1'b0,                // [3]     PME Clock - Not required for PCIe, hardwired to 0
                                   cfg_pmc_version};    // [2:0]   Version
assign cfg_reg_65 = cfg_pm_next_ptr;                    // Next Capability Pointer
assign cfg_reg_64 = 8'h01;                              // PM Capability ID - 0x01

assign int_upd_pme_cap = (lbc_cdm_dbi & pm_write_pulse[3] & pm_reg_id[0]);

reg pm_next_ptr_wr_updated;
always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : cap_cxl_next_ptr_PROC
    if(!sticky_rst_n) begin
        cfg_pm_next_ptr             <= #TP PM_NEXT_PTR;
        pm_next_ptr_wr_updated      <= #TP 1'b0;
    end
    else begin
        if (lbc_cdm_dbi & pm_write_pulse[1] & pm_reg_id[0] & VF_IMPL==0) begin
           pm_next_ptr_wr_updated      <= #TP 1'b1;
           cfg_pm_next_ptr             <= #TP  lbc_cdm_data[15:8];
        end
        else if (!pm_next_ptr_wr_updated) begin
           cfg_pm_next_ptr             <= #TP (cxl_rcrb_enable) ? (|RCRB ? `RCRB_PM_NEXT_PTR : (VF_IMPL == 0) ? `CXL_PM_NEXT_PTR : PM_NEXT_PTR) : PM_NEXT_PTR;
           pm_next_ptr_wr_updated      <= #TP  pm_next_ptr_wr_updated;
        end
    end
end

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin : pmc_PROC
    if(!sticky_rst_n) begin
        cfg_upd_pme_cap             <= #TP 1'b0; 
        cfg_pme_support             <= #TP PME_SUPPORT;
        cfg_pm_d2_support_reg       <= #TP D2_SUPPORT;
        cfg_pm_d1_support_reg       <= #TP D1_SUPPORT;
        cfg_pm_aux_current_reg      <= #TP AUX_CURRENT;
        cfg_pm_dsi_reg              <= #TP DEV_SPEC_INIT;
        cfg_pmc_version_reg         <= #TP PMC_VERSION;
        cfg_pm_imm_d0_reg           <= #TP `CX_RN_IMM_D0_VALUE;
    end
    else begin
        cfg_upd_pme_cap             <= #TP int_upd_pme_cap;
        cfg_pme_support             <= #TP (int_upd_pme_cap & VF_IMPL==0) ? lbc_cdm_data[31:27] : cfg_pme_support;
        cfg_pm_d2_support_reg       <= #TP (lbc_cdm_dbi & pm_write_pulse[3] & pm_reg_id[0] & VF_IMPL==0) ? lbc_cdm_data[26]    : cfg_pm_d2_support_reg;
        cfg_pm_d1_support_reg       <= #TP (lbc_cdm_dbi & pm_write_pulse[3] & pm_reg_id[0] & VF_IMPL==0) ? lbc_cdm_data[25]    : cfg_pm_d1_support_reg;
        cfg_pm_aux_current_reg[2]   <= #TP (lbc_cdm_dbi & pm_write_pulse[3] & pm_reg_id[0] & VF_IMPL==0) ? lbc_cdm_data[24]    : cfg_pm_aux_current_reg[2];
        cfg_pm_aux_current_reg[1:0] <= #TP (lbc_cdm_dbi & pm_write_pulse[2] & pm_reg_id[0] & VF_IMPL==0) ? lbc_cdm_data[23:22] : cfg_pm_aux_current_reg[1:0];
        cfg_pm_dsi_reg              <= #TP (lbc_cdm_dbi & pm_write_pulse[2] & pm_reg_id[0] & VF_IMPL==0) ? lbc_cdm_data[21]    : cfg_pm_dsi_reg;
        cfg_pm_imm_d0_reg           <= #TP (lbc_cdm_dbi & pm_write_pulse[2] & pm_reg_id[0] & VF_IMPL==0) ? lbc_cdm_data[20]    : cfg_pm_imm_d0_reg;
         cfg_pmc_version_reg        <= #TP (lbc_cdm_dbi & pm_write_pulse[2] & pm_reg_id[0] & VF_IMPL==0) ? lbc_cdm_data[18:16] : cfg_pmc_version_reg;
    end
end

// -----------------------------------------------------------------------------
// Power Management Control/Status Register (PMCSR)
// -----------------------------------------------------------------------------
// pm_reg_id        - 1
// PCIE Offset      - `CFG_PM_CAP + 04h
// length           - 4 byte
// Cfig register    - cfg_reg_68, cfg_reg_69, cfg_reg_70, cfg_reg_71
// -----------------------------------------------------------------------------
reg  cfg_pm_no_soft_rst_reg;
wire cfg_pm_no_soft_rst;

// Bit fields inherited by VF from associated PF
assign cfg_pm_no_soft_rst = VF_IMPL ? pm_no_soft_rst : cfg_pm_no_soft_rst_reg;

// Power Management Control/Status Register (PMCSR)
assign cfg_reg_71               =  8'b0;               // [31:24] Data        - Not supported by core, hardwire to 0
assign cfg_reg_70               = {1'b0,               // [23]    Bus Power/Clock Control Enable - Not required for PCIe, hardwire to 0
                                   1'b0,               // [22]    B2/B3 Support - Not required for PCIe, hardwire to 0
                                   6'b0};              // [21:16] Reserved
assign {cfg_reg_69, cfg_reg_68} = {pm_status,          // [15]    PME Status
                                   2'b0,               // [14:13] Data Scale  - Not supported by core, hardwire to 0 
                                   4'b0,               // [12:9]  Data Select - Not supported by core, hardwire to 0
                                   pm_pme_en,          // [8]     PME Enable
                                   4'b0,               // [7:4]   Reserved
                                   cfg_pm_no_soft_rst, // [3]     No_Soft_Reset
                                   1'b0,               // [2]     Reserved
                                   pmstate[1:0]};  // [1:0]   Power State

// cfg_pmstatus_clr is used to clear PME_status register in Power Management Controller
// when "1" is written to this bit field (RW1CS)
always @(posedge core_clk or negedge non_sticky_rst_n)
begin : pm_status_clr_PROC
    if(!non_sticky_rst_n) begin
        cfg_pmstatus_clr    <= #TP 0;
    end
    else begin
        cfg_pmstatus_clr    <= #TP pm_write_pulse[1] & pm_reg_id[1] & lbc_cdm_data[15];
    end
end

// A function enters the D0active state whenever any single or combination of
// the function's Memory  Space Enable, I/O Space Enable, or Bus Master Enable
// bits have been enabled by system software" (1.0a spec, sec 5.3.1.1)
reg         d0_active_detect_d;
reg [1:0]   int_pmstate;
wire        cfg_upd_pm;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin : space_enable_PROC
    if(!non_sticky_rst_n) begin
        d0_active_detect_d<= #TP 0;
    end
    else begin
        d0_active_detect_d<= #TP d0_active_detect;
    end
end

// Detect rising edge of d0_active_detect(or write 1 to cfg_bus_master_en,
// cfg_io_space_en or cfg_mem_space_en), causing dstate to be updated
assign cfg_upd_pm = (~d0_active_detect_d & d0_active_detect);

// write update of CDM register
assign int_upd_pme_en = (pm_write_pulse[1] & pm_reg_id[1]);
// update with value from LBC or hold value from pm_ctrl
assign int_lbc_pme_en = int_upd_pme_en ? lbc_cdm_data[8] :pm_pme_en;
// hold the value in the register or update with value from pm_ctrl
assign int_pm_pme_en = cfg_upd_pmcsr ? cfg_pme_en : int_lbc_pme_en;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin : pmcsr_PROC
    if(!non_sticky_rst_n) begin
        cfg_upd_pmcsr           <= #TP 0;
        int_pmstate             <= #TP 0;
        cfg_pme_en              <= #TP 0;
    end else begin
        // Power State bits
        int_pmstate[1:0]        <= #TP (pm_write_pulse[0] & pm_reg_id[1]) ? lbc_cdm_data[1:0] : int_pmstate[1:0];

        // PME Enable bit
        cfg_pme_en              <= #TP int_pm_pme_en; 

        // Update sticky bits in Power Management Controller when there is a write to this register or the space enable signals get set.
        cfg_upd_pmcsr           <= #TP ((pm_write_pulse[0] | pm_write_pulse[1]) & pm_reg_id[1]) | cfg_upd_pm;
    end
end 

always @(posedge cdm_clk_g or negedge sticky_rst_n)
begin 
    if(!sticky_rst_n) begin
        cfg_pm_no_soft_rst_reg  <= #TP DEFAULT_NO_SOFT_RESET;
    end else begin
        // No soft reset
        cfg_pm_no_soft_rst_reg  <= #TP (lbc_cdm_dbi && pm_write_pulse[0] && pm_reg_id[1] && VF_IMPL == 0) ? lbc_cdm_data[3] : cfg_pm_no_soft_rst_reg;
    end
end // block: pmcsr_PROC

wire        cfg_pf_hidden;
assign      cfg_pf_hidden = 1'b0;

// Detect a transition from D3hot to D0
assign cfg_pmstate_d3hot_to_d0 = (cfg_upd_pmcsr && (pmstate == 3'b011) && (int_pmstate[1:0] == 2'b00));

// pmstate[2:0]: Power State.  D0uninit = 100, D0active = 000, D1 = 001, D2 = 010, D3 = 011.
always @(posedge core_clk or negedge non_sticky_rst_n)
begin: pmstate_PROC
    if (!non_sticky_rst_n)
        pmstate   <= #TP 3'b100; // D0uninit
    else begin : PM_DSTATE_UPDATE
        // When the function has been hidden, go to D0uninit to ensure no
        // undesirable PM behavior while configured as an ARI device;
        // go to D3 to ensure no undesirable PM behavior while configured
        // as a non-ARI device.
        if (cfg_pf_hidden)
          pmstate <= #TP 3'b011;
    
        // When moving from D3hot to D0 state, state will return to D0uninit
        // unless NoSoftReset bit is set, then it goes to D0active
        else if (cfg_pmstate_d3hot_to_d0)
            pmstate <= #TP cfg_pm_no_soft_rst ? 3'b000 : 3'b100;
        else if (cfg_upd_pmcsr) begin
            pmstate <= #TP {1'b0, int_pmstate[1:0]};
        end
    end // PM_DSTATE_UPDATE
end


// =============================================================================
// Instantiate LTR message control block
// =============================================================================
  generate
     if (VF_IMPL==0 && FUNC_NUM==0) begin : gen_ltr_ctrl
       cdm_ltr_ctrl
        #(.INST(INST))
       u_cdm_ltr_ctrl
       (
         // Inputs
         .core_clk                     (core_clk)
         ,.non_sticky_rst_n            (non_sticky_rst_n)
         ,.upstream_port               (upstream_port)
         ,.ltr_m_en_fn0                (ltr_m_en_fn0)
         ,.cfg_upd_pmcsr               (cfg_upd_pmcsr)
         ,.int_pmstate                 (int_pmstate)
         ,.pmstate                     (pmstate)
         ,.cdmpl2cfg_ltr_rq            (cdmpl2cfg_ltr_rq)
         ,.rdlh_link_up                (rdlh_link_up)
         ,.msgg2cdm_ltr_clr_msg_grant  (msgg2cdm_ltr_clr_msg_grant)
         ,.app_ltr_msg_req             (app_ltr_msg_req)
         ,.msg_ltr_det                 (msg_ltr_det)
         ,.cfg_disable_ltr_clr_msg     (cfg_disable_ltr_clr_msg)         
         // Outputs
         ,.ltrctrl_ltr_clr_msg_req     (pm_ltr_clr_msg_req)
         ,.ltrctrl_pmstate             (cfg_pmstate)
       );
     end else begin : gen_ltr_ctrl_no_vf
       assign pm_ltr_clr_msg_req = 0;
       assign cfg_pmstate = pmstate;
     end
  endgenerate

// =============================================================================
// CFG Register Read Operation
// =============================================================================

reg  [31:0]  pm_reg_data;                   // Read data back from core
always @(*)
begin : read_data_PROC
    unique case (1'b1)
        pm_reg_id[0] : pm_reg_data = {cfg_reg_67, cfg_reg_66, cfg_reg_65, cfg_reg_64};
        pm_reg_id[1] : pm_reg_data = {cfg_reg_71, cfg_reg_70, cfg_reg_69, cfg_reg_68};
        default      : pm_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end

endmodule // cdm_vf pm_reg
