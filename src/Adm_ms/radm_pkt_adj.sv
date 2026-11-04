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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #1 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_pkt_adj.sv#1 $
// -------------------------------------------------------------------------
// Description:
//   This module reinforce the packet pushed into the radm_trgt_pkt_store module
//   matches the exact amount of credits accounted in the radm_credit_mgr module.
//   If the actual TLP lenght is greater than expected, the packet is trimmed.
//   If the actual TLP length is lower than expected, exceeding credits returned to the radm_credit_mgr module.
//---------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/pcie_pkg.svh"

module radm_pkt_adj
    import DWC_pcie_ctl_pkg::TP;
    import DWC_pcie_ctl_pkg::NW;
    import pcie_pkg::E_P;
    import pcie_pkg::E_NP;
    import pcie_pkg::E_CPL;
    import pcie_pkg::fc_type_e;
    import radm_ms_pkg::RADM_CRD_WD;
    import radm_ms_pkg::calc_radm_crd;
    import radm_ms_pkg::calc_tlp_data_len;
    import radm_ms_pkg::flt_data_o_s;
    import radm_ms_pkg::flt_p_hdr_o_s;
    import radm_ms_pkg::flt_np_hdr_o_s;
    import radm_ms_pkg::flt_cpl_hdr_o_s;
    import radm_ms_pkg::radm_crd_restore_s;
#(
    parameter IS_NP  = 1'b0,
    type      H_TYPE = flt_p_hdr_o_s
)
                       (
    input                      core_clk,
    input                      core_rst_n,

    input  flt_data_o_s        flt_pktadj_data,
    input  H_TYPE              flt_pktadj_hdr,
    input                      flit_mode,

    output flt_data_o_s        pktadj_q_data,
    output H_TYPE              pktadj_q_hdr,

    output radm_crd_restore_s  pktadj_crdmgr_crd_restore
);

// Extract some useful signals from Header/ Data inputs
wire hv;
assign hv = flt_pktadj_hdr.flt_q_hv;

wire dv;
assign dv = flt_pktadj_data.flt_q_dv;

wire eot;
assign eot = flt_pktadj_data.flt_q_eot;

wire dllp_abort;
assign dllp_abort = flt_pktadj_data.flt_q_dllp_abort;

wire tlp_abort;
assign tlp_abort = flt_pktadj_data.flt_q_tlp_abort;

wire [7:0] fmt_type;
assign fmt_type = {flt_pktadj_hdr.flt_q_hdr.flt_q_fmt2,flt_pktadj_hdr.flt_q_hdr.flt_q_fmt, flt_pktadj_hdr.flt_q_hdr.flt_q_type[4:0]}; 

wire [9:0] len; // len field extracted from TLP header
assign len = flt_pktadj_hdr.flt_q_hdr.flt_q_dw_len;

wire [RADM_CRD_WD-1:0] crd_required; // Amount of RADM credits required for the new TLP starting.
assign crd_required = calc_radm_crd(calc_tlp_data_len(fmt_type, len, flit_mode), IS_NP); 

// Credits are initialized on hv and decreased by 1 down to 0 every cycle inputs are valid
wire [RADM_CRD_WD-1:0] crd_curr;
reg  [RADM_CRD_WD-1:0] crd_prev;
wire [RADM_CRD_WD-1:0] crd_next;
assign crd_curr = (hv)? crd_required : crd_prev;
assign crd_next = (dv & crd_curr>0)? crd_curr - 1'b1 : crd_curr;
always @(posedge core_clk or negedge core_rst_n) begin  
    if(!core_rst_n) begin
        crd_prev <= #TP 0;
    end else if (hv|dv) begin
        crd_prev <= #TP crd_next;
    end
end

wire start_trimming;
assign start_trimming = (hv | dv) && crd_curr==1 && !eot;

typedef enum logic [1:0] {
    S_IDLE    = 2'b00,
    S_TRIM    = 2'b01,
    S_END     = 2'b10
} trim_state_e;

trim_state_e trim_state, trim_state_r;

always_comb begin : trim_state_PROC
    trim_state = trim_state_r;
    case(trim_state_r)
        S_IDLE:
            if (start_trimming) 
                trim_state = S_TRIM;
        S_TRIM:
            if (eot) 
                trim_state = S_END;
        S_END:
            if (start_trimming) 
                trim_state = S_TRIM;
            else
                trim_state = S_IDLE;
        default:
            trim_state = S_IDLE;
    endcase
end

// FSM state register
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        trim_state_r  <= #TP S_IDLE;
    else 
        trim_state_r  <= #TP trim_state;

// Latch inputs in case we are required to trim the current TLP
flt_data_o_s flt_adj_data_r;
H_TYPE       flt_adj_hdr_r;
always @(posedge core_clk or negedge core_rst_n) begin  
    if(!core_rst_n) begin
        flt_adj_data_r <= #TP 0;
        flt_adj_hdr_r  <= #TP 0;
    end else if (start_trimming) begin
        flt_adj_data_r <= #TP flt_pktadj_data;
        flt_adj_hdr_r  <= #TP flt_pktadj_hdr;
    end
end

always_comb begin : pkt_store_outputs_PROC
    pktadj_q_hdr  = flt_pktadj_hdr;
    pktadj_q_data = flt_pktadj_data;
    case(trim_state)
        S_TRIM : begin
            pktadj_q_hdr.flt_q_hv  = 1'b0;
            pktadj_q_data.flt_q_dv = 1'b0;
        end
        S_END : begin
            pktadj_q_hdr  = flt_adj_hdr_r;                        // Use latched header
            pktadj_q_data.flt_q_data = flt_adj_data_r.flt_q_data; // Use lacthed data/dwen but keep all the other fields 
            pktadj_q_data.flt_q_dwen = flt_adj_data_r.flt_q_dwen; // (which are EOT-aligned signals) from the current inputs 
        end
        default: begin
            // Do Nothing
        end
      endcase

end

// Restore Credits in case the TLP is shorter than expected
always @(posedge core_clk or negedge core_rst_n) begin  
    if(!core_rst_n) begin
        pktadj_crdmgr_crd_restore.valid  <= #TP 0;
        pktadj_crdmgr_crd_restore.amount <= #TP 0;
    end else if (eot && crd_next>1'b0) begin
        pktadj_crdmgr_crd_restore.valid  <= #TP 1'b1;
        pktadj_crdmgr_crd_restore.amount <= #TP crd_next;
    end else begin
        pktadj_crdmgr_crd_restore.valid  <= #TP 0;
        pktadj_crdmgr_crd_restore.amount <= #TP 0;
    end
end

 
`ifndef SYNTHESIS
//VCS coverage off
//VCS coverage on
`endif // SYNTHESIS

endmodule

