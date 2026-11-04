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
// ---    $Revision: #19 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_dpc_reg.sv#19 $
// -------------------------------------------------------------------------
// --- Module Description:
// --------------------------------------------------------------------------------------------
// --- This module contains the Downstream Port Containment Extended Capability (DPC) registers.
// --- This module is instantiated for downstream ports only (RP or Switch downstream)
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

 
 module cdm_dpc_reg
 import DWC_pcie_ctl_pkg::ERROR_TLP_WD;
#(
    parameter INST          = 0,                                   // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM      = 0,                                   // uniquifying parameter per function
    parameter NDPC          = 17,                                  // Max possible number of registers in DPC Extended Capability Structure (17 which includes all RP PIO)
    parameter TP            = `TP,                                 // Clock to Q delay (simulator insurance)
    parameter DPC_PRFX_LOG_SIZE = `CX_MAX_DPC_RPPIO_PRFXS_VALUE,   // Prefix log in DWs.
    parameter DPC_PRFX_LOG_WD   = 32*DPC_PRFX_LOG_SIZE,            // Prefix log width in bits.
    parameter FX_TLP        = `CX_FX_TLP                           // Number of TLPs that can be processed in a single cycle after the formation block
    , parameter RCRB          = 0                                   // This parameter is used to distinguish between the RCIEP ecfg space and the RCRB ecfg space
)
(
    // -------------- Inputs ---------------
    input                             core_clk,                    // Core Clock
    input                             non_sticky_rst_n,            // Non-Sticky Reset
    input                             sticky_rst_n,                // Sticky Reset (that is, asserted for cold reset only)
    input                             cdm_clk_g,
    input  [31:0]                     lbc_cdm_data,                // Write Data
    input                             lbc_cdm_dbi,                 // DBI Access
    input                             lbc_cdm_dbi2,                // DBI Access, CS2
    input  [3:0]                      dpc_write_pulse,             // Write Byte Enables
    input  [NDPC-1:0]                 dpc_reg_id,                  // DPC Register ID
    input                             dbi_ro_wr_en,                // used to make RW registers look like RO for compliance
    input                             int_dpc_triggered,           // DPC trigger. A low to high transition indicates that DPC has been triggered and by definition the Port is in DPC. 
    input  [1:0]                      int_dpc_trig_reason,         // Indicates why DPC has been triggered
    input  [1:0]                      int_dpc_trig_reason_extn,    // Indicates why DPC has been triggered
    input  [15:0]                     dpc_err_src_id,              // DPC Error Source ID.
    input                             cfg_int_disable,             // Interrupt Disable field of Command Register.
    input                             cfg_msi_en,                  // Interrupt Disable field of Command Register.
    input                             cfg_msix_en,                 // Interrupt Disable field of Command Register.

    // -------------- Outputs --------------
    output reg  [4:0]                 cfg_dpc_int_msg_num,                  // DPC Interrupt Message Number
    output                            cfg_dpc_rp_ext_dpc,                   // DPC Root Port Extensions for DPC
    output                            cfg_dpc_poison_tlp_egr_blk_support,   // DPC Poisoned TLP Egress Blocking Supported
    output                            cfg_dpc_sw_trig_support,              // DPC Software Triggering Supported
    output      [3:0]                 cfg_dpc_rp_pio_log_size,              // DPC RP PIO Log Size
    output                            cfg_dpc_dl_active_err_cor_support,    // DPC DL_Active ERR_COR Signaling Supported
    output reg  [1:0]                 cfg_dpc_trig_en,                      // DPC Trigger Enable
    output reg                        cfg_dpc_cpl_cntrl,                    // DPC Completion Control
    output reg                        cfg_dpc_int_en,                       // DPC Interrupt Enable
    output reg                        cfg_dpc_err_cor_en,                   // DPC ERR_COR Enable
    output reg                        cfg_dpc_poison_tlp_egr_block_en,      // Poisoned TLP Egress Blocking Enable
    output reg                        cfg_dpc_sw_trigger,                   // DPC Software Trigger
    output reg                        cfg_dpc_dl_active_err_cor_en,         // DL_Active ERR_COR Enable
    output reg                        cfg_dpc_trig_status,                  // DPC Trigger Status
    output                            dpc_triggered_detect,                 // 1 clock cycle pulse when DPC is triggered.
    output                            dpc_int,                              // DPC Interrupt Status for INTx signalling
    output reg                        dpc_msi,                              // DPC Interrupt pulse for MSI signalling
    output reg [31:0]                 dpc_reg_data                          // DPC Register Read Data
);

// ------------------- PARAMETERS -------------------------------------
localparam IMPSPEC_LOG_SIZE       = 1;                                      // ImpSpec log in DWs
localparam CX_DPC_RP_PIO_LOG_SIZE = DPC_PRFX_LOG_SIZE;
localparam LOG_SIZE               = 0; // Total log size in DWs
localparam MEM_TYPE               = 0;
localparam IO_TYPE                = 1;
localparam CFG_TYPE               = 2;

                                                                   

// -------------- Internal Signals --------------
wire    [3:0]        int_write_pulse;                                // Internal Write Pulse
wire    [NDPC-1:0]   int_reg_id;                                     // Internal Register ID

wire    [7:0]        dpc_reg_03, dpc_reg_02, dpc_reg_01, dpc_reg_00;
wire    [7:0]        dpc_reg_07, dpc_reg_06, dpc_reg_05, dpc_reg_04;
wire    [7:0]        dpc_reg_11, dpc_reg_10, dpc_reg_09, dpc_reg_08;
wire    [7:0]        dpc_reg_15, dpc_reg_14, dpc_reg_13, dpc_reg_12;
wire    [7:0]        dpc_reg_19, dpc_reg_18, dpc_reg_17, dpc_reg_16;
wire    [7:0]        dpc_reg_23, dpc_reg_22, dpc_reg_21, dpc_reg_20;
wire    [7:0]        dpc_reg_27, dpc_reg_26, dpc_reg_25, dpc_reg_24;
wire    [7:0]        dpc_reg_33, dpc_reg_32, dpc_reg_31, dpc_reg_30, dpc_reg_29, dpc_reg_28;
wire    [7:0]        dpc_reg_45, dpc_reg_44, dpc_reg_43, dpc_reg_42, dpc_reg_41, dpc_reg_40, dpc_reg_39, dpc_reg_38, dpc_reg_37, dpc_reg_36, dpc_reg_35, dpc_reg_34;
wire    [7:0]        dpc_reg_57, dpc_reg_56, dpc_reg_55, dpc_reg_54, dpc_reg_53, dpc_reg_52, dpc_reg_51, dpc_reg_50, dpc_reg_49, dpc_reg_48, dpc_reg_47, dpc_reg_46;
wire    [7:0]        dpc_reg_67, dpc_reg_66, dpc_reg_65, dpc_reg_64, dpc_reg_63, dpc_reg_62, dpc_reg_61, dpc_reg_60, dpc_reg_59, dpc_reg_58;
// eDPC flit mode
wire    [7:0]        dpc_reg_71, dpc_reg_70, dpc_reg_69, dpc_reg_68;
wire    [7:0]        dpc_reg_75, dpc_reg_74, dpc_reg_73, dpc_reg_72;
wire    [7:0]        dpc_reg_79, dpc_reg_78, dpc_reg_77, dpc_reg_76;
wire    [7:0]        dpc_reg_83, dpc_reg_82, dpc_reg_81, dpc_reg_80;
wire    [7:0]        dpc_reg_87, dpc_reg_86, dpc_reg_85, dpc_reg_84;
wire    [7:0]        dpc_reg_91, dpc_reg_90, dpc_reg_89, dpc_reg_88; 

reg     [15:0]       cfg_dpc_id;                                     // Capability ID
reg     [3:0]        cfg_dpc_ver;                                    // Capability Version
reg     [11:0]       cfg_dpc_next_ptr;                               // Next Capability Offset

reg     [1:0]        cfg_dpc_trig_reason;
reg                  cfg_dpc_int_status;
reg     [1:0]        cfg_dpc_trig_reason_extn;
reg     [15:0]       cfg_dpc_error_source_id;


wire       int_dpc_trig_detect;        // Single clock cycle pulse indicating DPC trigger event has occurred.
reg        int_dpc_triggered_d;                // 1 clock cycle delayed int_dpc_triggered.
wire       read_rp_busy;
wire [4:0] read_fe_pointer;
wire       int_dpc_trig_en;            // assert trigger enable only when cfg_dpc_trig_en = 01 or 10.

// Assignment for INTx signalling
//DPC Interrupt Status for INTx signalling.
// If the Port is enabled for level-triggered interrupt signaling using INTx messages, dpc_int is asserted whenever and as long as the following conditions are satisfied:
//The value of the Interrupt Disable bit in the Command register is 0b.
//The value of the DPC Interrupt Enable bit is 1b.
//The value of the DPC Interrupt Status bit is 1b.
assign dpc_int = cfg_dpc_int_status & ~cfg_int_disable & ~(cfg_msi_en | cfg_msix_en);


// Assignment for MSI signalling
// DPC Interrupt pulse for MSI signalling.
// If the Port is enabled for edge-triggered interrupt signaling using MSI or MSI-X, dpc_msi is asserted every time the logical AND of 
// the following conditions transitions from FALSE to TRUE:
// MSI or MSIX is enabled. (The Base Spec requires the associated vector to be unmasked. However, when the MSI-X table is 
// implemented externally the core will does not know if the vector is masked or not because the MSI-X Table including the 
// vector masks is stored off in memory space in the application.)
// The value of the DPC Interrupt Enable bit is 1b.
// The value of the DPC Interrupt Status bit is 1b.

wire dpc_msi_src;
reg dpc_msi_src_d;

assign dpc_msi_src = (cfg_msi_en | cfg_msix_en) & cfg_dpc_int_status & cfg_dpc_int_en;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (!non_sticky_rst_n) begin
        dpc_msi_src_d    <= #TP 1'b0;
        dpc_msi          <= #TP 1'b0;
    end else begin
        // MSI - pulse signal
        dpc_msi_src_d  <= #TP dpc_msi_src;
        dpc_msi        <= #TP (dpc_msi_src & ~dpc_msi_src_d);
    end
end

// -----------------------------------------------------------------------------

// DBI access signals
wire   int_lbc_cdm_dbi = lbc_cdm_dbi & ~lbc_cdm_dbi2;

// Extract write_pulse and reg_id for active function
assign int_write_pulse = dpc_write_pulse;
assign int_reg_id      = dpc_reg_id;

// ---------- Detect DPC trigger  ----------------------------------------------

// Low to high edge trigger detection of int_dpc_triggered

always @( posedge core_clk or negedge sticky_rst_n ) begin : dpc_trig_d_PROC
    if ( !sticky_rst_n ) begin
        int_dpc_triggered_d <= #TP 0;
    end else begin
        int_dpc_triggered_d <= #TP int_dpc_triggered;
    end
end
assign int_dpc_trig_detect = int_dpc_triggered & ~int_dpc_triggered_d;
//Assign output port.
assign dpc_triggered_detect = int_dpc_trig_detect; // 1 clock cycle pulse when DPC is triggered.

// -----------------------------------------------------------------------------
// DPC Extended Capability Header Register
// -----------------------------------------------------------------------------
// dpc_reg_id       - 0
// PCIE Offset      - `DPC_PTR
// length           - 4 byte
// Cfig register    - dpc_reg_03, dpc_reg_02, dpc_reg_01, dpc_reg_00
// RW via DBI.
// -----------------------------------------------------------------------------

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : cap_hdr_PROC
    if ( !sticky_rst_n ) begin
        cfg_dpc_id[15:0]       <= #TP `PCIE_DPC_ECAP_ID;
        cfg_dpc_ver[3:0]       <= #TP `PCIE_DPC_ECAP_VER;
        cfg_dpc_next_ptr[11:0] <= #TP `DM_RP_DPC_NEXT_PTR;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        // Read-Only registers, but writable through DBI
        cfg_dpc_id[7:0]        <= #TP (int_reg_id[0] & int_write_pulse[0] & int_lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[7:0] : cfg_dpc_id[7:0];
        cfg_dpc_id[15:8]       <= #TP (int_reg_id[0] & int_write_pulse[1] & int_lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[15:8] : cfg_dpc_id[15:8];
        cfg_dpc_ver[3:0]       <= #TP (int_reg_id[0] & int_write_pulse[2] & int_lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[19:16] : cfg_dpc_ver[3:0];
        cfg_dpc_next_ptr[3:0]  <= #TP (int_reg_id[0] & int_write_pulse[2] & int_lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[23:20]
                                    : cfg_dpc_next_ptr[3:0];
        cfg_dpc_next_ptr[11:4] <= #TP (int_reg_id[0] & int_write_pulse[3] & int_lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[31:24]
                                    : cfg_dpc_next_ptr[11:4];
    end
end

assign {dpc_reg_01, dpc_reg_00}      = cfg_dpc_id;
assign dpc_reg_02[3:0]               = cfg_dpc_ver;
assign {dpc_reg_03, dpc_reg_02[7:4]} = cfg_dpc_next_ptr;

// -----------------------------------------------------------------------------
// DPC Capability Register
// -----------------------------------------------------------------------------
// dpc_reg_id       - 1
// PCIE Offset      - `DPC_PTR + 04h
// length           - 2 byte
// Cfig register    - dpc_reg_05, dpc_reg_04
// RW via DBI.
// -----------------------------------------------------------------------------

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : capabilities_PROC
    if ( !sticky_rst_n ) begin
        cfg_dpc_int_msg_num                <= #TP `DPC_CAP_INT_MSG_NUM;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_dpc_int_msg_num                <= #TP (int_reg_id[1] & int_write_pulse[0] & int_lbc_cdm_dbi & dbi_ro_wr_en) ? lbc_cdm_data[4:0] : cfg_dpc_int_msg_num;
    end
end //always

// Root Port Extensions capability is hardwired.
assign cfg_dpc_rp_ext_dpc = `CX_DPC_RP_PIO_EXTNS_VALUE;
assign cfg_dpc_poison_tlp_egr_blk_support = `CX_DPC_POISON_TLP_EGR_BLK_VALUE;
assign cfg_dpc_sw_trig_support            = `CX_DPC_SW_TRIG_VALUE;
assign cfg_dpc_rp_pio_log_size            = LOG_SIZE;
assign cfg_dpc_dl_active_err_cor_support  = `CX_DPC_DL_ACTIVE_ERR_COR_VALUE;

assign dpc_reg_04 = {cfg_dpc_sw_trig_support, cfg_dpc_poison_tlp_egr_blk_support, cfg_dpc_rp_ext_dpc, cfg_dpc_int_msg_num};
assign dpc_reg_05 = {3'h0, cfg_dpc_dl_active_err_cor_support, cfg_dpc_rp_pio_log_size};

// -----------------------------------------------------------------------------
// DPC Control Register
// -----------------------------------------------------------------------------
// dpc_reg_id       - 1
// PCIE Offset      - `DPC_PTR + 06h
// length           - 2 byte
// Cfig register    - dpc_reg_07, dpc_reg_06
// RW via DBI.
// -----------------------------------------------------------------------------

always @( posedge cdm_clk_g or negedge sticky_rst_n ) begin : control_PROC
    if ( !sticky_rst_n ) begin
        cfg_dpc_trig_en                    <= #TP 0;
        cfg_dpc_cpl_cntrl                  <= #TP 0;
        cfg_dpc_int_en                     <= #TP 0;
        cfg_dpc_err_cor_en                 <= #TP 0;
        cfg_dpc_poison_tlp_egr_block_en    <= #TP 0;
        cfg_dpc_sw_trigger                 <= #TP 0;
        cfg_dpc_dl_active_err_cor_en       <= #TP 0;
    end else begin
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        cfg_dpc_trig_en                    <= #TP (int_reg_id[1] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[17:16] : cfg_dpc_trig_en;
        cfg_dpc_cpl_cntrl                  <= #TP (int_reg_id[1] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[18]    : cfg_dpc_cpl_cntrl;
        cfg_dpc_int_en                     <= #TP (int_reg_id[1] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[19]    : cfg_dpc_int_en;
        cfg_dpc_err_cor_en                 <= #TP (int_reg_id[1] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[20]    : cfg_dpc_err_cor_en;
        cfg_dpc_poison_tlp_egr_block_en    <= #TP !cfg_dpc_poison_tlp_egr_blk_support ? 0 : (int_reg_id[1] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[21] : cfg_dpc_poison_tlp_egr_block_en;
        // DPC Software Trigger is only asserted for 1 clock cycle and only if core is not already in DPC and update of Trigger Enable field allows DPC to be triggered:
        cfg_dpc_sw_trigger                 <= #TP !cfg_dpc_sw_trig_support | cfg_dpc_trig_status ? 0 : (int_reg_id[1] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[22] & (lbc_cdm_data[17] ^ lbc_cdm_data[16]) : 1'b0;
        cfg_dpc_dl_active_err_cor_en       <= #TP !cfg_dpc_dl_active_err_cor_support  ? 0 : (int_reg_id[1] & int_write_pulse[2] & int_lbc_cdm_dbi) ? lbc_cdm_data[23] : cfg_dpc_dl_active_err_cor_en;
    end
end //always

// DPC Software Trigger bit always returns 0 when read (Base Spec)
assign dpc_reg_06 = {cfg_dpc_dl_active_err_cor_en, 1'b0, cfg_dpc_poison_tlp_egr_block_en, cfg_dpc_err_cor_en, cfg_dpc_int_en, cfg_dpc_cpl_cntrl, cfg_dpc_trig_en};
assign dpc_reg_07 = 0;


// -----------------------------------------------------------------------------
// DPC Status Register
// -----------------------------------------------------------------------------
// dpc_reg_id       - 2
// PCIE Offset      - `DPC_PTR + 08h
// length           - 2 byte
// Cfig register    - dpc_reg_13, dpc_reg_12
// Read Only or Write 1 to clear via DBI.
// -----------------------------------------------------------------------------

always @( posedge core_clk or negedge sticky_rst_n ) begin : status_PROC
    if ( !sticky_rst_n ) begin
        cfg_dpc_trig_status                <= #TP 0;
        cfg_dpc_trig_reason                <= #TP 0;
        cfg_dpc_int_status                 <= #TP 0;
        cfg_dpc_trig_reason_extn           <= #TP 0;
    end else begin
        // Trigger Status. Wire clears with write 1.
        cfg_dpc_trig_status                <= #TP int_dpc_trig_detect                                                      ? 1'b1                :                        // RW1CS
                                                  (int_reg_id[2] & int_write_pulse[0] & int_lbc_cdm_dbi & lbc_cdm_data[0]) ? 0                   : cfg_dpc_trig_status;
        // Trigger Reason.
        cfg_dpc_trig_reason                <= #TP int_dpc_triggered                                                        ? int_dpc_trig_reason : cfg_dpc_trig_reason;
        // Interrupt Status. Set when DPC is triggered while interrupt enable is true, Wire clears with write 1.
        cfg_dpc_int_status                 <= #TP int_dpc_trig_detect & cfg_dpc_int_en                                     ? 1'b1                :                        // RW1CS
                                                  (int_reg_id[2] & int_write_pulse[0] & int_lbc_cdm_dbi & lbc_cdm_data[3]) ? 0                   : cfg_dpc_int_status;
        // Trigger Reason Extension.
        cfg_dpc_trig_reason_extn           <= #TP int_dpc_triggered                                                        ? int_dpc_trig_reason_extn : cfg_dpc_trig_reason_extn;
    end
end


assign read_rp_busy    = 1'b0;
assign read_fe_pointer = 5'b00000;


assign dpc_reg_08 = {1'b0, cfg_dpc_trig_reason_extn, read_rp_busy, cfg_dpc_int_status, cfg_dpc_trig_reason, cfg_dpc_trig_status};
assign dpc_reg_09 = {3'h0, read_fe_pointer};


// -----------------------------------------------------------------------------
// DPC Error Source ID Register
// -----------------------------------------------------------------------------
// dpc_reg_id       - 2
// PCIE Offset      - `DPC_PTR + 0Ah
// length           - 2 byte
// Cfig register    - dpc_reg_11, dpc_reg_10
// ROS from the Wire. RW via DBI (for Requestor ID of the received Message).
// -----------------------------------------------------------------------------

always @( posedge core_clk or negedge sticky_rst_n ) begin : error_source_id_PROC
    if ( !sticky_rst_n ) begin
        cfg_dpc_error_source_id            <= #TP 0;
    end else if (dpc_triggered_detect && ((int_dpc_trig_reason==2'b01) || (int_dpc_trig_reason==2'b10))) begin // ERR_FATAL or ERR_NONFATAL received
        cfg_dpc_error_source_id            <= #TP dpc_err_src_id;
    end
end

assign dpc_reg_10 = {cfg_dpc_error_source_id[7:0]};
assign dpc_reg_11 = {cfg_dpc_error_source_id[15:8]};


assign dpc_reg_12 = 0;
assign dpc_reg_13 = 0;
assign dpc_reg_14 = 0;
assign dpc_reg_15 = 0;
assign dpc_reg_16 = 0;
assign dpc_reg_17 = 0;
assign dpc_reg_18 = 0;
assign dpc_reg_19 = 0;
assign dpc_reg_20 = 0;
assign dpc_reg_21 = 0;
assign dpc_reg_22 = 0;
assign dpc_reg_23 = 0;
assign dpc_reg_24 = 0;
assign dpc_reg_25 = 0;
assign dpc_reg_26 = 0;
assign dpc_reg_27 = 0;
assign dpc_reg_28 = 0;
assign dpc_reg_29 = 0;
assign dpc_reg_30 = 0;
assign dpc_reg_31 = 0;
assign {dpc_reg_35, dpc_reg_34, dpc_reg_33, dpc_reg_32} = 0;
assign {dpc_reg_39, dpc_reg_38, dpc_reg_37, dpc_reg_36} = 0;
assign {dpc_reg_43, dpc_reg_42, dpc_reg_41, dpc_reg_40} = 0;
assign {dpc_reg_47, dpc_reg_46, dpc_reg_45, dpc_reg_44} = 0;
assign {dpc_reg_51, dpc_reg_50, dpc_reg_49, dpc_reg_48} = 0;
assign {dpc_reg_55, dpc_reg_54, dpc_reg_53, dpc_reg_52} = 0;
assign {dpc_reg_59, dpc_reg_58, dpc_reg_57, dpc_reg_56} = 0;
assign {dpc_reg_63, dpc_reg_62, dpc_reg_61, dpc_reg_60} = 0;
assign {dpc_reg_67, dpc_reg_66, dpc_reg_65, dpc_reg_64} = 0;
// eDPC extra hdr log flit mode
assign {dpc_reg_71, dpc_reg_70, dpc_reg_69, dpc_reg_68} = 0;
assign {dpc_reg_75, dpc_reg_74, dpc_reg_73, dpc_reg_72} = 0;
assign {dpc_reg_79, dpc_reg_78, dpc_reg_77, dpc_reg_76} = 0;
assign {dpc_reg_83, dpc_reg_82, dpc_reg_81, dpc_reg_80} = 0;
assign {dpc_reg_87, dpc_reg_86, dpc_reg_85, dpc_reg_84} = 0;
assign {dpc_reg_91, dpc_reg_90, dpc_reg_89, dpc_reg_88} = 0;


// -----------------------------------------------------------------------------



// =============================================================================
// Register Read Operation
// =============================================================================

always @( * ) begin : read_data_PROC
    dpc_reg_data = 0;

    if (int_reg_id[0])   begin
        dpc_reg_data = {dpc_reg_03, dpc_reg_02, dpc_reg_01, dpc_reg_00};  // read Header register
    end else if (int_reg_id[1])   begin
        dpc_reg_data = {dpc_reg_07, dpc_reg_06, dpc_reg_05, dpc_reg_04};  // read Capability and Control register
    end else if (int_reg_id[2])   begin
        dpc_reg_data = {dpc_reg_11, dpc_reg_10, dpc_reg_09, dpc_reg_08};  // read Status and Error Source ID register
    end else if (int_reg_id[3])   begin
        dpc_reg_data = {dpc_reg_15, dpc_reg_14, dpc_reg_13, dpc_reg_12};  // read RP PIO Status register
    end else if (int_reg_id[4])   begin
        dpc_reg_data = {dpc_reg_19, dpc_reg_18, dpc_reg_17, dpc_reg_16};  // read RP PIO Mask register
    end else if (int_reg_id[5])   begin
        dpc_reg_data = {dpc_reg_23, dpc_reg_22, dpc_reg_21, dpc_reg_20};  // read RP PIO Severity register
    end else if (int_reg_id[6])   begin
        dpc_reg_data = {dpc_reg_27, dpc_reg_26, dpc_reg_25, dpc_reg_24};  // read RP PIO SysError register
    end else if (int_reg_id[7])   begin
        dpc_reg_data = {dpc_reg_31, dpc_reg_30, dpc_reg_29, dpc_reg_28};  // read RP PIO Exception register
    end else if (int_reg_id[8])   begin
        dpc_reg_data = {dpc_reg_35, dpc_reg_34, dpc_reg_33, dpc_reg_32};  // read RP PIO header log 1st DW register
    end else if (int_reg_id[9])   begin
        dpc_reg_data = {dpc_reg_39, dpc_reg_38, dpc_reg_37, dpc_reg_36};  // read RP PIO header log 2nd DW register
    end else if (int_reg_id[10])   begin
        dpc_reg_data = {dpc_reg_43, dpc_reg_42, dpc_reg_41, dpc_reg_40};  // read RP PIO header log 3rd DW register
    end else if (int_reg_id[11])   begin
        dpc_reg_data = {dpc_reg_47, dpc_reg_46, dpc_reg_45, dpc_reg_44};  // read RP PIO header log 4th DW register
    end else if (int_reg_id[12])   begin
        dpc_reg_data = {dpc_reg_51, dpc_reg_50, dpc_reg_49, dpc_reg_48};  // read RP PIO ImpSpec register
    end else if (int_reg_id[13])   begin
        dpc_reg_data = {dpc_reg_55, dpc_reg_54, dpc_reg_53, dpc_reg_52};  // read RP PIO Prefix log, 1st prefix register
    end else if (int_reg_id[14])   begin
        dpc_reg_data = {dpc_reg_59, dpc_reg_58, dpc_reg_57, dpc_reg_56};  // read RP PIO Prefix log, 2nd prefix register
    end else if (int_reg_id[15])   begin
        dpc_reg_data = {dpc_reg_63, dpc_reg_62, dpc_reg_61, dpc_reg_60};  // read RP PIO Prefix log, 3rd prefix register
    end else if (int_reg_id[16])   begin
        dpc_reg_data = {dpc_reg_67, dpc_reg_66, dpc_reg_65, dpc_reg_64};  // read RP PIO Prefix log, 4th prefix register
    end else begin
    end
end //always read_data_PROC



endmodule //cdm_dpc_reg
