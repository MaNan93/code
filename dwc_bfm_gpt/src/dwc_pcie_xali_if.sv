//======================================================================
// dwc_pcie_xali_if.sv
//   Transmit client interface (XALI0 / XALI1 / XALI2, or one FC-XALI
//   channel of the MultiStream architecture).
//
//   Direction convention: all "tlp_*" are APPLICATION -> CONTROLLER,
//   xadm_halt is CONTROLLER -> APPLICATION.
//
//   Port naming when you hook it up to the generated RTL:
//       tlp_hv        -> client0_tlp_hv        / client_vc0_p0_tlp_hv
//       xadm_halt     -> xadm_client0_halt     / xadm_client_vc0_p0_halt
//       ...
//======================================================================
`include "dwc_pcie_bfm_defines.svh"

interface dwc_pcie_xali_if (input logic clk, input logic rst_n);
  import dwc_pcie_cfg_pkg::*;

  // ---- application -> controller ------------------------------------
  logic                  tlp_hv;
  logic                  tlp_dv;
  logic                  tlp_eot;
  logic                  tlp_bad_eot;
  logic [DW-1:0]         tlp_data;

  logic [4:0]            tlp_type;
  logic [2:0]            tlp_fmt;
  logic [63:0]           tlp_addr;
  logic [7:0]            tlp_byte_en;
  logic [12:0]           tlp_byte_len;
  logic [2:0]            tlp_tc;
  logic [2:0]            tlp_attr;
  logic                  tlp_td;
  logic                  tlp_ep;
  logic [1:0]            tlp_at;
  logic [9:0]            tlp_tid;
  logic [15:0]           remote_req_id;
  logic [4:0]            tlp_func_num;
  logic [7:0]            tlp_vfunc_num;
  logic                  tlp_vfunc_active;
  logic [2:0]            cpl_status;
  logic [12:0]           cpl_byte_cnt;
  logic [PRFX_W-1:0]     tlp_prfx;
  logic [LUT_ID_W-1:0]   cpl_lookup_id;
  logic                  addr_align_en;
  logic [2:0]            tlp_order_seqnum;
  logic [1:0]            tlp_segment;
  logic [1:0]            tlp_dst_segment;

  // ---- controller -> application ------------------------------------
  logic                  xadm_halt;      // xadm_clienti_halt, active high

  //--------------------------------------------------------------------
  // Clocking blocks
  //--------------------------------------------------------------------
  clocking mcb @(posedge clk);            // application (BFM) side
    default input #1step output #0;
    output tlp_hv, tlp_dv, tlp_eot, tlp_bad_eot, tlp_data,
           tlp_type, tlp_fmt, tlp_addr, tlp_byte_en, tlp_byte_len,
           tlp_tc, tlp_attr, tlp_td, tlp_ep, tlp_at, tlp_tid,
           remote_req_id, tlp_func_num, tlp_vfunc_num, tlp_vfunc_active,
           cpl_status, cpl_byte_cnt, tlp_prfx, cpl_lookup_id,
           addr_align_en, tlp_order_seqnum, tlp_segment, tlp_dst_segment;
    input  xadm_halt;
  endclocking

  clocking pcb @(posedge clk);            // passive monitor
    default input #1step;
    input tlp_hv, tlp_dv, tlp_eot, tlp_bad_eot, tlp_data,
          tlp_type, tlp_fmt, tlp_addr, tlp_byte_en, tlp_byte_len,
          tlp_tc, tlp_attr, tlp_td, tlp_ep, tlp_at, tlp_tid,
          remote_req_id, tlp_func_num, tlp_vfunc_num, tlp_vfunc_active,
          cpl_status, cpl_byte_cnt, tlp_prfx, cpl_lookup_id,
          addr_align_en, tlp_order_seqnum, tlp_segment, tlp_dst_segment,
          xadm_halt;
  endclocking

  clocking ccb @(posedge clk);            // controller (XADM) side -- TB stub
    default input #1step output #0;
    output xadm_halt;
    input  tlp_hv, tlp_dv, tlp_eot, tlp_bad_eot, tlp_data,
           tlp_type, tlp_fmt, tlp_addr, tlp_byte_en, tlp_byte_len,
           tlp_tc, tlp_attr, tlp_td, tlp_ep, tlp_at, tlp_tid,
           remote_req_id, tlp_func_num, tlp_vfunc_num, tlp_vfunc_active,
           cpl_status, cpl_byte_cnt, tlp_prfx, cpl_lookup_id,
           addr_align_en, tlp_order_seqnum, tlp_segment, tlp_dst_segment;
  endclocking

  modport bfm (clocking mcb, input clk, input rst_n);
  modport mon (clocking pcb, input clk, input rst_n);
  modport ctrl(clocking ccb, input clk, input rst_n);

  //====================================================================
  // Protocol checker  (DM Databook 6.60a, section 4.1.1)
  //====================================================================
`ifndef DWC_BFM_NO_SVA

  // "in_pkt" = a TLP with payload has started (hv accepted) and has not
  // reached eot yet.  A beat is accepted only on a non-halted cycle.
  logic in_pkt;
  wire  accept = !xadm_halt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)          in_pkt <= 1'b0;
    else if (accept) begin
      if (tlp_eot && (tlp_hv || tlp_dv)) in_pkt <= 1'b0;
      else if (tlp_hv)                   in_pkt <= 1'b1;
    end
  end

  wire [$bits(dwc_xali_hdr_t)-1:0] hdr_flat =
    {tlp_type, tlp_fmt, tlp_addr, tlp_byte_en, tlp_byte_len, tlp_tc,
     tlp_attr, tlp_td, tlp_ep, tlp_at, tlp_tid, remote_req_id,
     tlp_func_num, tlp_vfunc_num, tlp_vfunc_active, cpl_status,
     cpl_byte_cnt, tlp_prfx, cpl_lookup_id, addr_align_en,
     tlp_order_seqnum, tlp_segment, tlp_dst_segment};

  default clocking pcb;
  default disable iff (!rst_n);

  // R1: eot is only legal on the last dv cycle, or on hv when there is
  //     no payload.
  a_eot_qualified: assert property (tlp_eot |-> (tlp_dv || tlp_hv))
    else $error("XALI: tlp_eot asserted without tlp_dv/tlp_hv");

  // R2: bad_eot must be asserted on the same cycle as eot.
  a_bad_eot_with_eot: assert property (tlp_bad_eot |-> tlp_eot)
    else $error("XALI: tlp_bad_eot without tlp_eot");

  // R3: while halted the application must hold header + data + controls.
  a_hold_on_halt: assert property (
      (xadm_halt && (tlp_hv || tlp_dv)) |=>
      $stable({tlp_hv, tlp_dv, tlp_eot, tlp_bad_eot, tlp_data, hdr_flat}))
    else $error("XALI: outputs changed while xadm_halt was asserted");

  // R4: no bubbles inside a TLP -- once started, dv must stay asserted
  //     until eot ("must continue to stream data unless the controller
  //     halts the client interface").
  if (HDR_CYC == 1) begin : g_no_bubble
    a_no_bubble: assert property (@(posedge clk) disable iff (!rst_n)
        in_pkt |-> tlp_dv)
      else $error("XALI: bubble inside a TLP (dv de-asserted before eot)");
    // R5: hv is a single cycle at the head of the TLP.
    a_hv_is_head: assert property (@(posedge clk) disable iff (!rst_n)
        in_pkt |-> !tlp_hv)
      else $error("XALI: tlp_hv re-asserted in the middle of a TLP");
  end

  // R6: a TLP with payload must present hv and dv on the same cycle.
  a_hv_dv_first_beat: assert property ((tlp_hv && !tlp_eot) |-> tlp_dv)
    else $error("XALI: header cycle of a multi-beat TLP without tlp_dv");

  // R7: data must not appear outside a packet.
  a_dv_inside_pkt: assert property ((tlp_dv && !in_pkt) |-> tlp_hv)
    else $error("XALI: tlp_dv outside of a TLP");

  // R8: Completions must not use address alignment (Databook 4.1.3 note).
  a_cpl_no_align: assert property (
      (tlp_hv && (tlp_type inside {DWC_TLP_CPL, DWC_TLP_CPLD,
                                   DWC_TLP_CPLLK, DWC_TLP_CPLDLK}))
      |-> !addr_align_en)
    else $error("XALI: addr_align_en asserted for a Completion");

  // R9: ECRC (TD=1) and address alignment are mutually exclusive (4.1.3.4).
  a_ecrc_no_align: assert property ((tlp_hv && tlp_td) |-> !addr_align_en)
    else $error("XALI: addr_align_en asserted for a TLP carrying ECRC");

  // R10: with alignment off the address must be DWORD aligned (4.1.3.1).
  a_align_off_dw: assert property (
      (tlp_hv && !addr_align_en &&
       tlp_type inside {DWC_TLP_MEM, DWC_TLP_MEMLK, DWC_TLP_IO})
      |-> (tlp_addr[1:0] == 2'b00))
    else $error("XALI: addr_align_en=0 requires a DWORD-aligned tlp_addr");

`endif // DWC_BFM_NO_SVA

endinterface : dwc_pcie_xali_if
