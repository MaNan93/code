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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_outq_mgr_ms.sv#4 $
// -------------------------------------------------------------------------
//
//
//
//
//--------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/pcie_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_outq_mgr_ms
    import pcie_pkg::E_P;
    import pcie_pkg::E_NP;
    import pcie_pkg::E_CPL;
    import DWC_pcie_ctl_pkg::TP;
    import DWC_pcie_ctl_pkg::NVC;
    import radm_ms_pkg::radm_form_s;
    import radm_ms_pkg::radm_outq_tlp_s;
    import radm_ms_pkg::PKT_ORD_WD;
    import radm_ms_pkg::N_TRGT1_INTF;
    import radm_ms_pkg::radm_crd_restore_s;
    import radm_ms_pkg::trgt_grnt_top_s;
#(
    parameter DATA_PROT_WD   = `TRGT_DATA_PROT_WD,
    parameter FORMQ_RD_PORTS = `CX_RADM_FORMQ_N_READ_PORT_VC
)(
    input                                                            core_clk,
    input                                                            core_rst_n,
    input                                                            radm_idle,

    input  radm_form_s [2:0][FORMQ_RD_PORTS-1:0]                     rxq_tlp,                  // FormationQ TLP interface
    output             [2:0]                                         outqmgr_form_halt,        // Halt signals - back pressure to Formation Queues

    input  radm_crd_restore_s [NVC-1:0]                              pktadj_crdmgr_crd_restore_p,
    input  radm_crd_restore_s [NVC-1:0]                              pktadj_crdmgr_crd_restore_np,
    input  radm_crd_restore_s [NVC-1:0]                              pktadj_crdmgr_crd_restore_cpl,

    input  trgt_grnt_top_s                                           trgt_grnt_trgt1_top,

    output radm_outq_tlp_s [2:0]                                     outq_tlp,                 // OutQ manager to Filter interface

    output logic    [2:0]                                            outqmgr_filt_formq_not_empty
);

localparam  NFC = 2 ;
localparam  P0  = 0; // Port 0 - this will become an actual index when MultiPort will be supported
localparam  VC0 = 0; // VC 0 - this will become an actual index when MultiVC will be supported

/////////////////////////////////////////////////////
// local wires and regs

logic  [NFC-1:0][N_TRGT1_INTF-1:0]                                 vcarb_crdmgr_tlp_grant;

logic  [NFC-1:0][FORMQ_RD_PORTS-1:0]                               crdmgr_vcarb_req;
logic  [NFC-1:0]                                                   vcarb_formq_halt;
logic  [NFC-1:0][N_TRGT1_INTF-1:0]                                 hdr_fifo_rd_grnt;
logic  [NFC-1:0][N_TRGT1_INTF-1:0]                                 data_fifo_rd_grnt;
logic  [2:0]                                                       ide_halt;

assign ide_halt = 3'b000 ;

// This signal constantly indicates how many P have been read already.
// It is valid not only on hv but always, to account for the case when
// a P requires some cycles to be read from the RADM Queue, but a NP/CPL
// (that has been received later) is already at the output of this module
logic [PKT_ORD_WD-1:0] p_pkt_num, p_pkt_num_r;
assign p_pkt_num = (rxq_tlp[E_P][P0].tlp.hdr.hv && !vcarb_formq_halt[E_P]) ? rxq_tlp[E_P][P0].tlp.hdr.p_pkt_num : p_pkt_num_r;
always_ff @(posedge core_clk or negedge core_rst_n)begin
  if(!core_rst_n)begin
    p_pkt_num_r <= #TP '0;
  end else begin
    p_pkt_num_r <= #TP !outqmgr_form_halt[E_P] ? p_pkt_num : p_pkt_num_r;
  end
end

// Map TLP input struct into output struct
// Fields hdr_data_length and q_not_empty are not propagated thought the TLP struct 
radm_outq_tlp_s [2:0] mapd_tlp; 
always_comb begin
  for (int fc = E_P; fc <= E_CPL; fc++) begin 
    mapd_tlp[fc].tlp                  = rxq_tlp[fc][P0].tlp;
    mapd_tlp[fc].ecrc_data            = rxq_tlp[fc][P0].mac_data[31:0];
    mapd_tlp[fc].ecrc_enable          = rxq_tlp[fc][P0].mac_size == 3'b001;
  end
end

// Mask valid signals and eot when halt is enabled
radm_outq_tlp_s [2:0] mskd_tlp;
always_comb begin
  mskd_tlp = mapd_tlp;
  mskd_tlp[E_P].tlp.hdr.p_pkt_num  = p_pkt_num; // keep P pkt_num stable until the next P
  for (int fc = E_P; fc < NFC; fc++) begin 
    // For halted P, NP, and CPL (if CPLs are not in bypass) mask valid and eot
    mskd_tlp[fc].tlp.hdr.hv           = mapd_tlp[fc].tlp.hdr.hv  & ~vcarb_formq_halt[fc];
    mskd_tlp[fc].tlp.data.dv          = mapd_tlp[fc].tlp.data.dv & ~vcarb_formq_halt[fc];
    mskd_tlp[fc].tlp.ctl.eot          = mapd_tlp[fc].tlp.ctl.eot & ~vcarb_formq_halt[fc];
  end
end

// Input grant has trgt interface based structure.
// Credit manager block needs input per FC. So remapping of the information.
always_comb begin : trgt1_grant_convert_PROC
  for(int fc=0; fc<NFC; fc++)
    for(int trgt1=0;trgt1<N_TRGT1_INTF;trgt1++) begin
        hdr_fifo_rd_grnt[fc][trgt1]  = trgt_grnt_trgt1_top.trgt_grnt_trgt1_top[trgt1].trgt_grnt_trgt1[fc].hdr_fifo_rd;
        data_fifo_rd_grnt[fc][trgt1] = trgt_grnt_trgt1_top.trgt_grnt_trgt1_top[trgt1].trgt_grnt_trgt1[fc].data_fifo_rd;
    end
end

generate
  for (genvar fc= 0; fc< NFC; fc++) begin : g_vc_arb_credit_mgr_inst
    always_comb begin
      vcarb_formq_halt[fc]                 = ~crdmgr_vcarb_req[fc];
      vcarb_crdmgr_tlp_grant[fc]           = rxq_tlp[fc][P0].tlp.hdr.hv && crdmgr_vcarb_req[fc] && !ide_halt[fc];
    end
  end
endgenerate

// credit manager block instance for P FC
radm_credit_mgr
 u_radm_credit_mgr_p
(
  .core_clk                       (core_clk                            ),
  .core_rst_n                     (core_rst_n                          ),
  .radm_idle                      (radm_idle                           ),
  .rxq_tlp                        (rxq_tlp[E_P]                        ),
  .vcarb_crdmgr_tlp_grant         (vcarb_crdmgr_tlp_grant[E_P]         ),
  .vcarb_crdmgr_vc_grant          ('0                                  ),
  .vcarb_crdmgr_rdport_grant      ('0                                  ),
  .hdr_fifo_rd                    (hdr_fifo_rd_grnt[E_P]               ),
  .data_fifo_rd                   (data_fifo_rd_grnt[E_P]              ),
  .crdmgr_vcarb_req               (crdmgr_vcarb_req[E_P]               ),
  .pktadj_crdmgr_crd_restore      (pktadj_crdmgr_crd_restore_p[VC0]    )
);

// credit manager block instance for NP FC
radm_credit_mgr
 #(.IS_NP(1'b1)) u_radm_credit_mgr_np
(
  .core_clk                       (core_clk                            ),
  .core_rst_n                     (core_rst_n                          ),
  .radm_idle                      (radm_idle                           ),
  .rxq_tlp                        (rxq_tlp[E_NP]                       ),
  .vcarb_crdmgr_tlp_grant         (vcarb_crdmgr_tlp_grant[E_NP]        ),
  .vcarb_crdmgr_vc_grant          ('0                                  ),
  .vcarb_crdmgr_rdport_grant      ('0                                  ),
  .hdr_fifo_rd                    (hdr_fifo_rd_grnt[E_NP]              ),
  .data_fifo_rd                   (data_fifo_rd_grnt[E_NP]             ),
  .crdmgr_vcarb_req               (crdmgr_vcarb_req[E_NP]              ),
  .pktadj_crdmgr_crd_restore      (pktadj_crdmgr_crd_restore_np[VC0]   )
);


always@(posedge core_clk or negedge core_rst_n) begin
  if(~core_rst_n) begin
    outqmgr_filt_formq_not_empty <= #TP '0;
  end else begin
    if(!ide_halt[E_P]) begin
      outqmgr_filt_formq_not_empty[E_P]   <= #TP rxq_tlp[E_P][P0].q_not_empty;
    end
    if(!ide_halt[E_NP]) begin
      outqmgr_filt_formq_not_empty[E_NP]  <= #TP rxq_tlp[E_NP][P0].q_not_empty;
    end
    if(!ide_halt[E_CPL]) begin
      outqmgr_filt_formq_not_empty[E_CPL] <= #TP rxq_tlp[E_CPL][P0].q_not_empty;
    end
  end
end

delay_n_w_enable

#(1, $size(radm_outq_tlp_s)) u_delay_p (
  .clk   (core_clk),
  .rst_n (core_rst_n),
  .clear (1'b0),
  .en    (!ide_halt[E_P]),
  .din   (mskd_tlp[E_P]),
  .dout  (outq_tlp[E_P])
);

delay_n_w_enable

#(1, $size(radm_outq_tlp_s)) u_delay_np (
  .clk   (core_clk),
  .rst_n (core_rst_n),
  .clear (1'b0),
  .en    (!ide_halt[E_NP]),
  .din   (mskd_tlp[E_NP]),
  .dout  (outq_tlp[E_NP])
);

delay_n_w_enable

#(1, $size(radm_outq_tlp_s)) u_delay_cpl (
  .clk   (core_clk),
  .rst_n (core_rst_n),
  .clear (1'b0),
  .en    (!ide_halt[E_CPL]),
  .din   (mapd_tlp[E_CPL]),
  .dout  (outq_tlp[E_CPL])
);

assign outqmgr_form_halt[E_P]   = vcarb_formq_halt[E_P  ] | ide_halt[E_P  ];
assign outqmgr_form_halt[E_NP]  = vcarb_formq_halt[E_NP ] | ide_halt[E_NP ];
assign outqmgr_form_halt[E_CPL] = 1'b0                    | ide_halt[E_CPL];

endmodule
