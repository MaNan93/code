//======================================================================
// dwc_pcie_trgt1_if.sv
//   Receive request interface (TRGT1 / RTRGT1, or one FC-TRGT1 channel
//   of the MultiStream architecture).
//
//   Direction convention: all "radm_*" are CONTROLLER -> APPLICATION,
//   "halt" / "pkt_halt" are APPLICATION -> CONTROLLER.
//
//   Port naming when you hook it up to the generated RTL:
//       hv         -> radm_trgt1_hv          / radm_trgt1_p_0_hv
//       halt       -> trgt1_radm_halt        / trgt1_radm_intf_p_0_halt
//       pkt_halt   -> trgt1_radm_pkt_halt[2:0]   (legacy arch only)
//       grant_type -> radm_grant_tlp_type[2:0]   (legacy arch only)
//
//   !! IMPORTANT TIMING NOTE (DM Databook 4.6.1 + note under Fig 4-14)
//   !! "halt" is NOT an AXI-style ready.  After the application asserts
//   !! halt, radm_trgt1_dv stays high for a further, pipeline-dependent
//   !! number of cycles and those beats are REAL DATA.  The application
//   !! must therefore consume a beat on EVERY cycle where dv==1, and must
//   !! own enough buffering to absorb HALT_LATENCY extra beats.
//======================================================================
`include "dwc_pcie_bfm_defines.svh"

interface dwc_pcie_trgt1_if (input logic clk, input logic rst_n);
  import dwc_pcie_cfg_pkg::*;

  // ---- controller -> application ------------------------------------
  logic                  hv;
  logic                  dv;
  logic                  eot;
  logic [DW-1:0]         data;
  logic [NDW-1:0]        dwen;            // per-DWORD enables (last beat)

  logic                  tlp_abort;       // malformed / UR-CA, credit must be returned
  logic                  dllp_abort;      // LCRC / nullified, credit need not be returned
  logic                  ecrc_err;        // ECRC mismatch (ECRC_ERR_PASS_THROUGH=1)
  logic                  ep;              // Poisoned (EP) bit

  logic [4:0]            tlp_type;
  logic [2:0]            tlp_fmt;
  logic [63:0]           addr;
  logic [7:0]            byte_en;
  logic [12:0]           byte_len;
  logic [2:0]            tlp_tc;
  logic [2:0]            tlp_attr;
  logic                  tlp_td;
  logic [1:0]            tlp_at;
  logic [9:0]            tlp_tid;
  logic [15:0]           req_id;
  logic [4:0]            func_num;
  logic [7:0]            vfunc_num;
  logic                  vfunc_active;
  logic [2:0]            cpl_status;
  logic [12:0]           cpl_byte_cnt;
  logic [6:0]            cpl_lower_addr;
  logic [PRFX_W-1:0]     tlp_prfx;
  logic [63:0]           hdr_uppr_bytes;       // Msg hdr bytes 8..15 (iATU)
  logic                  hdr_uppr_bytes_valid;
  logic [LUT_ID_W-1:0]   lookup_id;            // trgt_lookup_id, valid with hv
  logic [15:0]           pkt_order_no;         // MultiStream ordering info
  logic [1:0]            dest_sgmt;            // Flit mode
  logic [1:0]            reqtr_sgmt;           // Flit mode

  logic [2:0]            grant_tlp_type;       // pulse, [0]=P [1]=NP [2]=CPL

  // ---- application -> controller ------------------------------------
  logic                  halt;                 // global / per-FC interface halt
  logic [2:0]            pkt_halt;             // combinational, per TLP type

  //--------------------------------------------------------------------
  // Clocking blocks
  //--------------------------------------------------------------------
  clocking scb @(posedge clk);            // application (BFM) side
    default input #1step output #0;
    input  hv, dv, eot, data, dwen, tlp_abort, dllp_abort, ecrc_err, ep,
           tlp_type, tlp_fmt, addr, byte_en, byte_len, tlp_tc, tlp_attr,
           tlp_td, tlp_at, tlp_tid, req_id, func_num, vfunc_num,
           vfunc_active, cpl_status, cpl_byte_cnt, cpl_lower_addr,
           tlp_prfx, hdr_uppr_bytes, hdr_uppr_bytes_valid, lookup_id,
           pkt_order_no, dest_sgmt, reqtr_sgmt, grant_tlp_type;
    output halt;
  endclocking

  clocking pcb @(posedge clk);            // passive monitor
    default input #1step;
    input  hv, dv, eot, data, dwen, tlp_abort, dllp_abort, ecrc_err, ep,
           tlp_type, tlp_fmt, addr, byte_en, byte_len, tlp_tc, tlp_attr,
           tlp_td, tlp_at, tlp_tid, req_id, func_num, vfunc_num,
           vfunc_active, cpl_status, cpl_byte_cnt, cpl_lower_addr,
           tlp_prfx, hdr_uppr_bytes, hdr_uppr_bytes_valid, lookup_id,
           pkt_order_no, dest_sgmt, reqtr_sgmt, grant_tlp_type,
           halt, pkt_halt;
  endclocking

  clocking ccb @(posedge clk);            // controller (RADM) side -- TB stub
    default input #1step output #0;
    output hv, dv, eot, data, dwen, tlp_abort, dllp_abort, ecrc_err, ep,
           tlp_type, tlp_fmt, addr, byte_en, byte_len, tlp_tc, tlp_attr,
           tlp_td, tlp_at, tlp_tid, req_id, func_num, vfunc_num,
           vfunc_active, cpl_status, cpl_byte_cnt, cpl_lower_addr,
           tlp_prfx, hdr_uppr_bytes, hdr_uppr_bytes_valid, lookup_id,
           pkt_order_no, dest_sgmt, reqtr_sgmt, grant_tlp_type;
    input  halt, pkt_halt;
  endclocking

  modport bfm (clocking scb, output pkt_halt, input clk, input rst_n);
  modport mon (clocking pcb, input clk, input rst_n);
  modport ctrl(clocking ccb, input clk, input rst_n);

  //====================================================================
  // Protocol checker  (DM Databook 6.60a, sections 4.6.1 / 4.6.3)
  //====================================================================
`ifndef DWC_BFM_NO_SVA

  logic rx_in_pkt;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)                       rx_in_pkt <= 1'b0;
    else if (eot && (hv || dv))       rx_in_pkt <= 1'b0;
    else if (hv && !eot)              rx_in_pkt <= 1'b1;
  end

  default clocking pcb;
  default disable iff (!rst_n);

  // R1: hv marks the head of a packet only.
  a_hv_is_head: assert property (rx_in_pkt |-> !hv)
    else $error("TRGT1: radm_trgt1_hv asserted inside a packet");

  // R2: eot must coincide with a valid cycle.
  a_eot_qualified: assert property (eot |-> (hv || dv))
    else $error("TRGT1: radm_trgt1_eot without hv/dv");

  // R3: data only inside a packet.
  a_dv_inside_pkt: assert property ((dv && !rx_in_pkt) |-> hv)
    else $error("TRGT1: radm_trgt1_dv outside a packet");

  // R4: error flags are qualified by eot.
  a_abort_with_eot: assert property ((tlp_abort || dllp_abort) |-> eot)
    else $error("TRGT1: abort flag asserted outside eot");

  // R5: once dv has actually stopped under halt, the bus must hold.
  a_hold_when_parked: assert property (
      (halt && rx_in_pkt && !dv) |=> ($stable(data) || !halt))
    else $error("TRGT1: data changed while the interface was parked on halt");

  // R6: Figure 4-16 -- minimum one clock from de-assertion of
  //     pkt_halt[i] to the corresponding grant pulse.
  genvar gi;
  for (gi = 0; gi < 3; gi++) begin : g_grant
    a_grant_delay: assert property (@(posedge clk) disable iff (!rst_n)
        $fell(pkt_halt[gi]) |-> !grant_tlp_type[gi])
      else $error("TRGT1: grant_tlp_type[%0d] in the same cycle pkt_halt fell", gi);
  end

`endif // DWC_BFM_NO_SVA

endinterface : dwc_pcie_trgt1_if
