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

// --------------------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_clk_ctrl.sv#7 $
// --------------------------------------------------------------------------------------
// --- Module description: AXI Clock Gating Control
// --- Gathers Transfer pending indicators and generates clock gating control for
// --- 1. mstr_aclk
// --- 2. slv_aclk
// --------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_axi_clk_ctrl
 #(
   parameter SYNC_DEPTH                             = 2,
   parameter CORE_RASDP_WAKEUP_WD                   = 6,

   parameter TP                                     = `TP
 )
 (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  // -------------------------------------------------------------------------------------
  input                                              mstr_aclk_ug,                        // ungated mstr_aclk
  input                                              mstr_aresetn,                        // mstr resetn
  input                                              slv_aclk,                            // gated slv_aclk
  input                                              slv_aclk_ug,                         // ungated slv_aclk
  input                                              slv_aresetn,                         // slave resetn
  // -------------------------------------------------------------------------------------
  // Clock gating control interface
  // -------------------------------------------------------------------------------------
  input                                              cfg_axi_clk_gating_en,               // Active high clock gating enable 
  output wire                                        sync_mstr_aclk_gating_en,
  output wire                                        sync_slv_aclk_gating_en,
  // -------------------------------------------------------------------------------------
  // Master-(core/dma) interface busy signals
  // -------------------------------------------------------------------------------------
  input                                              brdg_mstr_xfer_pending,
  input                                              edma_xfer_pending,                   // indicates DMA is busy
  // -------------------------------------------------------------------------------------
  // Slave interface busy signals
  // -------------------------------------------------------------------------------------
  input                                              app_xfer_pending,
  input                                              slv_xfer_pending,
  input                                              slvdb_xfer_pending,
  input                                              slv_awvalid,
  input                                              slv_wvalid,
  input                                              slv_arvalid,
  // -------------------------------------------------------------------------------------
  // Clock gating controls
  // -------------------------------------------------------------------------------------
  output                                             mstr_aclk_active,
  output                                             slv_aclk_active,
  input                                              aux_clk_g,                            // Aux clock
  input                                              core_rst_n                          // core reset_n
  ,input logic                                       ras_err_inj_wake_up
  ,input logic [CORE_RASDP_WAKEUP_WD-1:0]            core_ras_dp_wake_up
  ,input logic [1:0]                                 mstr_ras_dp_wake_up
  ,input logic [1:0]                                 slv_ras_dp_wake_up
 );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam S_MSTR_CLK_GATED = 1'b0;
  localparam S_MSTR_CLK_RELEASED = 1'b1;

  localparam S_SLV_CLK_GATED = 1'b0;
  localparam S_SLV_CLK_RELEASED = 1'b1;

  // -------------------------------------------------------------------------------------
  // Regs/Wires
  // -------------------------------------------------------------------------------------

  reg  mstr_clk_state;
  reg  mstr_clk_nxtstate;

  wire radm_xfer_pending;
  wire mstr_radm_xfer_pending;
  wire mstr_edma_xfer_pending;
  wire mstr_ras_err_inj_wake_up;

  reg  slv_clk_state;
  reg  slv_clk_nxtstate;
  wire slv_app_xfer_pending;
  wire slv_ras_err_inj_wake_up;


  wire mstr_busy;
  wire slv_busy;
  wire dbi_busy;

  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  logic ras_core_wake_up;
  assign ras_core_wake_up = ras_err_inj_wake_up | (|core_ras_dp_wake_up);

  // -------------------------------------------------------------------------------------
  // Synchronise AXI clock gating enable to master/slave/dbi clocks
  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // Register input signals on original clock to avoid feedback logic on the synchronizer
  // inputs
  // This is a mandatory requirement in Synopsys CDC Checklist (SNPS_MARCH_3)
  // -------------------------------------------------------------------------------------
  logic cfg_axi_clk_gating_en_sync0_r;
  always @(posedge aux_clk_g or negedge core_rst_n) begin : proc_seq_cfg_axi_clk_gating_en_sync0_r
    if (!core_rst_n) begin
      cfg_axi_clk_gating_en_sync0_r <= # TP 1'b1;
    end else begin
      cfg_axi_clk_gating_en_sync0_r <= # TP cfg_axi_clk_gating_en;
    end
  end

  DWC_pcie_ctl_bcm41
  
  #(
   .WIDTH                            (1),
    .RST_VAL     (1         ),
    .F_SYNC_TYPE (SYNC_DEPTH)
  ) u_sync0 (
  .clk_d                             (mstr_aclk_ug),
  .rst_d_n                           (mstr_aresetn),
    .data_s     (cfg_axi_clk_gating_en_sync0_r),
  .data_d                            (sync_mstr_aclk_gating_en)
  );

  assign radm_xfer_pending = brdg_mstr_xfer_pending;

  // -------------------------------------------------------------------------------------
  // Synchronise native core transfer pending signals 
  // -------------------------------------------------------------------------------------
  DWC_pcie_src_reg_sync
  
  #(
   .WIDTH                            (1),
   .F_SYNC_TYPE                      (SYNC_DEPTH),
   .VERIF_EN                         (1)
  )
  u_c2m_radm_xfer_pending
  (
  .clk_s                             (aux_clk_g),
  .rst_s_n                           (core_rst_n),
  .clk_d                             (mstr_aclk_ug),
  .rst_d_n                           (mstr_aresetn),
  .data_s                            (radm_xfer_pending),
  .data_d                            (mstr_radm_xfer_pending)
  );

  DWC_pcie_src_reg_sync
  
  #(
   .WIDTH                            (1),
   .F_SYNC_TYPE                      (SYNC_DEPTH),
   .VERIF_EN                         (1)
  )
  u_c2m_edma_xfer_pending
  (
  .clk_s                             (aux_clk_g),
  .rst_s_n                           (core_rst_n),
  .clk_d                             (mstr_aclk_ug),
  .rst_d_n                           (mstr_aresetn),
  .data_s                            (edma_xfer_pending),
  .data_d                            (mstr_edma_xfer_pending)
  );

  // -------------------------------------------------------------------------------------
  // Synchronise native core RAS error injection signal
  // -------------------------------------------------------------------------------------
  DWC_pcie_src_reg_sync
  
  #(
   .WIDTH                            (1),
   .F_SYNC_TYPE                      (SYNC_DEPTH),
   .VERIF_EN                         (1)
  )
  u_c2m_ras_err_inj_wake_up
  (
  .clk_s                             (aux_clk_g),
  .rst_s_n                           (core_rst_n),
  .clk_d                             (mstr_aclk_ug),
  .rst_d_n                           (mstr_aresetn),
  .data_s                            (ras_core_wake_up),
  .data_d                            (mstr_ras_err_inj_wake_up)
  );




  // -------------------------------------------------------------------------------------
  // mstr_aclk gating FSM (run on mstr_aclk_ug)
  // -------------------------------------------------------------------------------------
  assign mstr_busy = !sync_mstr_aclk_gating_en // disable clock gating, master always busy 
                     || mstr_radm_xfer_pending // Received Posted/Non-Posted Write
                     || mstr_edma_xfer_pending // DMA is busy
                     || mstr_ras_err_inj_wake_up || (|mstr_ras_dp_wake_up)
                     ;
  // FSM
  always@(*)
    begin:mstr_aclk_gating_combinational
        mstr_clk_nxtstate = mstr_clk_state;
        case(mstr_clk_state)
          S_MSTR_CLK_RELEASED: if (mstr_busy == 1'b0) begin mstr_clk_nxtstate = S_MSTR_CLK_GATED; end
          S_MSTR_CLK_GATED   : if (mstr_busy == 1'b1) begin mstr_clk_nxtstate = S_MSTR_CLK_RELEASED; end
          default          : mstr_clk_nxtstate = mstr_clk_state;
        endcase
      end

  always@(posedge mstr_aclk_ug or negedge mstr_aresetn)
    begin:mstr_aclk_gating_sequential
        if (!mstr_aresetn) begin
          mstr_clk_state <= #TP S_MSTR_CLK_GATED;
        end else begin
          mstr_clk_state <= #TP mstr_clk_nxtstate;
        end
      end

 // Outputs
 // mstr_aclk_active gates the mstr_aclk when mstr is idle. 
 // mstr_aclk is gated the very next cycle after mstr_aclk_active transitions from 1 -> 0
 // , provided mstr_aclk_active sampled at the negative edge in the clk gating cell
 // mstr_aclk would be back after 1 clock cycle approx after mstr_aclk_active is released
  assign  mstr_aclk_active = mstr_clk_state || mstr_clk_nxtstate;


  // -------------------------------------------------------------------------------------
  // Synchronise the clock gating enable register 
  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // Register input signals on original clock to avoid feedback logic on the synchronizer
  // inputs
  // This is a mandatory requirement in Synopsys CDC Checklist (SNPS_MARCH_3)
  // -------------------------------------------------------------------------------------
  logic cfg_axi_clk_gating_en_sync1_r;
  always @(posedge aux_clk_g or negedge core_rst_n) begin : proc_seq_cfg_axi_clk_gating_en_sync1_r
    if (!core_rst_n) begin
      cfg_axi_clk_gating_en_sync1_r <= # TP 1'b1;
    end else begin
      cfg_axi_clk_gating_en_sync1_r <= # TP cfg_axi_clk_gating_en;
    end
  end

  DWC_pcie_ctl_bcm41
  
  #(
   .WIDTH                            (1),
    .RST_VAL     (1         ),
    .F_SYNC_TYPE (SYNC_DEPTH)
  ) u_sync1 (
  .clk_d                             (slv_aclk_ug),
  .rst_d_n                           (slv_aresetn),
  .data_s     (cfg_axi_clk_gating_en_sync1_r),
  .data_d                            (sync_slv_aclk_gating_en)
  );

  // -------------------------------------------------------------------------------------
  // Synchronise application transfer pending
  // -------------------------------------------------------------------------------------
  DWC_pcie_src_reg_sync
  
  #(
   .WIDTH                            (1),
   .F_SYNC_TYPE                      (SYNC_DEPTH),
   .VERIF_EN                         (1)
  )
  u_c2s_app_xfer_pending
  (
  .clk_s                             (aux_clk_g),
  .rst_s_n                           (core_rst_n),
  .clk_d                             (slv_aclk_ug),
  .rst_d_n                           (slv_aresetn),
  .data_s                            (app_xfer_pending),
  .data_d                            (slv_app_xfer_pending)
  );


  // -------------------------------------------------------------------------------------
  // Synchronise RAS error injection signal
  // -------------------------------------------------------------------------------------
  DWC_pcie_src_reg_sync
  
  #(
   .WIDTH                            (1),
   .F_SYNC_TYPE                      (SYNC_DEPTH),
   .VERIF_EN                         (1)
  )
  u_c2s_ras_err_inj_wake_up
  (
  .clk_s                             (aux_clk_g),
  .rst_s_n                           (core_rst_n),
  .clk_d                             (slv_aclk_ug),
  .rst_d_n                           (slv_aresetn),
  .data_s                            (ras_core_wake_up),
  .data_d                            (slv_ras_err_inj_wake_up)
  );

  // -------------------------------------------------------------------------------------
  // slv_aclk gating FSM (run on slv_aclk_ug)
  // -------------------------------------------------------------------------------------
  assign slv_busy = !sync_slv_aclk_gating_en      // Disable clock gating, slave always busy 
                    || slv_xfer_pending           // AXI slave pending, wire traffic
                    || slvdb_xfer_pending         // AXI slave pending, DBI traffic
                    || slv_app_xfer_pending       // Application clock enable
                    || slv_awvalid || slv_wvalid  // AXI Slave Write Ch Valid
                    || slv_arvalid                // AXI Slave Read Ch Valid 
                    || slv_ras_err_inj_wake_up || (|slv_ras_dp_wake_up)
                    ;              

  always@(*)
    begin:slv_aclk_gating_combinational
        slv_clk_nxtstate = slv_clk_state;
        case(slv_clk_state)
          S_SLV_CLK_RELEASED: if (slv_busy == 1'b0) begin slv_clk_nxtstate = S_SLV_CLK_GATED; end
          S_SLV_CLK_GATED   : if (slv_busy == 1'b1) begin slv_clk_nxtstate = S_SLV_CLK_RELEASED; end
          default           : slv_clk_nxtstate = slv_clk_state;
        endcase
      end

  always@(posedge slv_aclk_ug or negedge slv_aresetn)
    begin:slv_aclk_gating_sequential
        if (!slv_aresetn) begin
          slv_clk_state <= #TP S_SLV_CLK_GATED;
        end else begin
          slv_clk_state <= #TP slv_clk_nxtstate;
        end
      end

 // Outputs
 // slv_aclk_active gates the slv_aclk when slv is idle. 
 // slv_aclk is gated the very next cycle after slv_aclk_active transitions from 1 -> 0
 // , provided slv_aclk_active sampled at the negative edge in the clk gating cell
 // slv_aclk would be back after 1 clock cycle approx after slv_aclk_active is released
  assign  slv_aclk_active = (slv_clk_state) || slv_clk_nxtstate;



`ifndef SYNTHESIS

`endif // SYNTHESIS

endmodule
