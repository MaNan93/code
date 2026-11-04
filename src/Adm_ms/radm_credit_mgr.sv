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
// --   RCS information:
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_credit_mgr.sv#3 $
// -------------------------------------------------------------------------
// - generating the request for TLPs based on the available buffer credits.
// - Subtracting the credits from counter based on the granted TLP information.
// - Adding back the credits to the counter based on the read operation on fifo.
//
//--------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_credit_mgr
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::NVC;
  import DWC_pcie_ctl_pkg::NVC_WD;
  import DWC_pcie_ctl_pkg::NW;
  import radm_ms_pkg::RADM_CRD_WD;
  import radm_ms_pkg::N_TRGT1_INTF;
  import radm_ms_pkg::H_FIFO_DEPTH; 
  import radm_ms_pkg::H_ADDR_WIDTH; 
  import radm_ms_pkg::D_P_FIFO_DEPTH;
  import radm_ms_pkg::D_P_ADDR_WIDTH;
  import radm_ms_pkg::D_NP_FIFO_DEPTH;
  import radm_ms_pkg::D_NP_ADDR_WIDTH;
  import radm_ms_pkg::radm_crd_restore_s; 
  import radm_ms_pkg::radm_form_s;
#(
  parameter IS_NP          = 1'b0,        // Set to 1 in case of NP Flow Control. This is to use `CX_MAX_MTU_NP instead of `CX_MAX_MTU
  parameter IS_CPL         = 1'b0,
  parameter FORMQ_RD_PORTS = `CX_RADM_FORMQ_N_READ_PORT_VC
)(
  input                                                     core_clk,                     // gated core clock
  input                                                     core_rst_n,                   // core reset n
  input                                                     radm_idle,

  input   radm_form_s [NVC-1:0][FORMQ_RD_PORTS-1:0]         rxq_tlp,                      // FormationQ TLP interface
  output  logic  [NVC-1:0][FORMQ_RD_PORTS-1:0]              crdmgr_vcarb_req,             // request signal going to vc arbiter based on the current bufer status availability.  
 
  input   [N_TRGT1_INTF-1:0]                                vcarb_crdmgr_tlp_grant,       // valid tlp transmit per trgt interfaces 
  input   [N_TRGT1_INTF-1:0][NVC_WD-1:0]                    vcarb_crdmgr_vc_grant,        // tlp vc and interface selection for each fc per trgt interfaces. 
  input   [N_TRGT1_INTF-1:0]                                vcarb_crdmgr_rdport_grant,    // tlp vc and interface selection for each fc per trgt interfaces. 
  input   [N_TRGT1_INTF-1:0]                                hdr_fifo_rd,                  // header buffer read
  input   [N_TRGT1_INTF-1:0]                                data_fifo_rd,                 // data buffer read

  input   radm_crd_restore_s                                pktadj_crdmgr_crd_restore

  );

  // Local parameters
  localparam D_FIFO_DEPTH     = (IS_CPL == 1'b1) ? `CX_RADM_TRGT_FIFO_CPL_DATA_DP         : (IS_NP == 1'b0) ? D_P_FIFO_DEPTH : D_NP_FIFO_DEPTH; // Data fifo depth.
  localparam D_ADDR_WIDTH     = (IS_CPL == 1'b1) ? $clog2(`CX_RADM_TRGT_FIFO_CPL_DATA_DP) : (IS_NP == 1'b0) ? D_P_ADDR_WIDTH : D_NP_ADDR_WIDTH; // Adress width for data fifo.
  localparam HDR_BUF_CRDT_WD  = H_ADDR_WIDTH + 1;
  localparam DATA_BUF_CRDT_WD = D_ADDR_WIDTH + 1;
  localparam DATA_PKT_CRDTS   = DATA_BUF_CRDT_WD >=11 ? 11 : DATA_BUF_CRDT_WD;   

  // local wires and registers
  wire    [N_TRGT1_INTF-1:0][RADM_CRD_WD-1:0]               crd_required;                 // Amount of RADM credits required for the new TLP starting.
  wire    [N_TRGT1_INTF-1:0][DATA_BUF_CRDT_WD-1:0]          crd_required_adj;             // Same as previous but adjusted to match buffer's width.
  logic   [N_TRGT1_INTF-1:0][DATA_BUF_CRDT_WD-1:0]          data_buf_credits;             // data buffer credits
  logic   [N_TRGT1_INTF-1:0][HDR_BUF_CRDT_WD-1:0]           hdr_buf_credits;              // header buffer credit
  logic   [NVC-1:0][FORMQ_RD_PORTS-1:0]                     crdmgr_vcarb_req_r;   

  ////////////////////////////////////////////////////
  // Credit management for buffer within a filters
  //
  ////////////////////////////////////////////////////
  // Selection of tlp packet length based on VC and interface selection from vc arbiter module.
  generate
    for (genvar i = 0; i < N_TRGT1_INTF; i++) begin : data_length_int
      assign crd_required[i] = radm_ms_pkg::calc_radm_crd(rxq_tlp[vcarb_crdmgr_vc_grant[i]][vcarb_crdmgr_rdport_grant[i]].hdr_data_length,IS_NP);
      if (DATA_BUF_CRDT_WD>=RADM_CRD_WD) begin : extend_crd_required
          assign crd_required_adj[i] = {{DATA_BUF_CRDT_WD-RADM_CRD_WD{1'b0}}, crd_required[i]};
      end else begin : truncate_crd_required
          // crd_required witdh is sized to accomodate CX_MAX_MTU but NP data length is much smaller
          // adsence of data loss is also proved by the assertion below
          assign crd_required_adj[i] = crd_required[i][DATA_BUF_CRDT_WD-1:0];
      end
    end
  endgenerate
  // radm header storage counter
  generate
    for (genvar i = 0; i < N_TRGT1_INTF; i++) begin : hdr_credit_count_PROC
      always@(posedge core_clk or negedge core_rst_n) begin
        if(~core_rst_n) begin
          hdr_buf_credits[i] <=#TP H_FIFO_DEPTH; 
        end else begin
          case({hdr_fifo_rd[i],vcarb_crdmgr_tlp_grant[i]})
            2'b01   : hdr_buf_credits[i] <= #TP hdr_buf_credits[i] - 1'b1;
            2'b10   : hdr_buf_credits[i] <= #TP hdr_buf_credits[i] + 1'b1;
            default : hdr_buf_credits[i] <= #TP hdr_buf_credits[i];
          endcase
        end
      end
    end
  endgenerate
  // radm data storage counter
  generate
    for (genvar i = 0; i < N_TRGT1_INTF; i++) begin : data_credit_count_PROC
      always@(posedge core_clk or negedge core_rst_n) begin
        if(~core_rst_n) begin
          data_buf_credits[i] <= #TP D_FIFO_DEPTH; 
         end else begin
        // spyglass disable_block W164a
        // SMD: LHS width is less than the RHS width in assignment.
        // SJ: Right side value should not exeed more than max value. It can happen in some error from next stage processing unit only.
        //     In this case assertion gets fired. 
          case({pktadj_crdmgr_crd_restore.valid,data_fifo_rd[i],vcarb_crdmgr_tlp_grant[i]})
            3'b001  : data_buf_credits[i] <= #TP data_buf_credits[i]                                                      - crd_required_adj[i];
            3'b010  : data_buf_credits[i] <= #TP data_buf_credits[i]                                    + data_fifo_rd[i]                      ;
            3'b011  : data_buf_credits[i] <= #TP data_buf_credits[i]                                    + data_fifo_rd[i] - crd_required_adj[i];
            3'b100  : data_buf_credits[i] <= #TP data_buf_credits[i] + pktadj_crdmgr_crd_restore.amount                                        ;
            3'b101  : data_buf_credits[i] <= #TP data_buf_credits[i] + pktadj_crdmgr_crd_restore.amount                   - crd_required_adj[i];
            3'b110  : data_buf_credits[i] <= #TP data_buf_credits[i] + pktadj_crdmgr_crd_restore.amount + data_fifo_rd[i]                      ;
            3'b111  : data_buf_credits[i] <= #TP data_buf_credits[i] + pktadj_crdmgr_crd_restore.amount + data_fifo_rd[i] - crd_required_adj[i];
            default : data_buf_credits[i] <= #TP data_buf_credits[i];
          endcase
        // spyglass enable_block W164a
        end
      end
    end
  endgenerate

  // Request signal for each vc and read ports
  always_comb begin : formq_halting_PROC
    for(int i=0;i<NVC;i++)
      for(int j=0;j<FORMQ_RD_PORTS;j++)
        crdmgr_vcarb_req[i][j] =  (rxq_tlp[i][j].tlp.hdr.hv)? (hdr_buf_credits[j] > 0) && (data_buf_credits[j]>=crd_required_adj[j]) : crdmgr_vcarb_req_r[i][j] ;
  end
  // latching the request information going to vcarbiter.
  always@(posedge core_clk or negedge core_rst_n) begin
        if(~core_rst_n) begin
          crdmgr_vcarb_req_r <= #TP '1;
        end else begin
          crdmgr_vcarb_req_r <= #TP crdmgr_vcarb_req; 
        end
  end   

 
`ifndef SYNTHESIS
//VCS coverage off
//VCS coverage on
`endif // SYNTHESIS

endmodule
