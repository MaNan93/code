//======================================================================
// dwc_trgt1_pkt_halt_tracker.sv
//   The "Non-Posted TLP Tracker" the Databook tells you to build
//   (section 4.6.3, Figure 4-15/4-16).
//
//   Why it exists: trgt1_radm_halt is a *global* stop.  If a Non-Posted
//   TLP that the application cannot accept reaches the output pipe, it
//   blocks every following packet -- including Posted ones -- which can
//   deadlock.  trgt1_radm_pkt_halt[2:0] instead stops a TLP type inside
//   the receive queue, before it is unloaded.
//
//   Rules encoded here:
//     * radm_grant_tlp_type[2:0] is a clocked *pulse*: one TLP of that
//       type has just been dequeued and is in the 3-4 cycle output pipe.
//     * trgt1_radm_pkt_halt[2:0] is a *level* and must be driven
//       COMBINATORIALLY from the counters, otherwise extra TLPs get
//       dequeued before the halt is seen.
//     * There is a minimum of one clock from de-assertion of
//       pkt_halt[t] to the next grant pulse for that type.
//
//   Synthesizable -- lint it with your normal flow.
//======================================================================
`default_nettype none

module dwc_trgt1_pkt_halt_tracker #(
  parameter int unsigned P_DEPTH   = 8,   // app buffer slots, Posted
  parameter int unsigned NP_DEPTH  = 8,   // app buffer slots, Non-Posted
  parameter int unsigned CPL_DEPTH = 8,   // app buffer slots, Completion
  parameter int unsigned MARGIN    = 3    // >= output pipe depth (3-4)
) (
  input  wire        clk,
  input  wire        rst_n,

  // from the controller
  input  wire [2:0]  grant_tlp_type,      // radm_grant_tlp_type, pulse
  input  wire        hv,                  // radm_trgt1_hv
  input  wire [2:0]  hv_fc_onehot,        // FC of the TLP on hv: 0=P 1=NP 2=CPL

  // from the application: one pulse per TLP retired out of its buffer
  input  wire [2:0]  pop,

  // to the controller
  output wire [2:0]  pkt_halt,            // trgt1_radm_pkt_halt, combinational

  output wire [2:0]  overflow             // sticky error, for assertions/debug
);

  localparam int unsigned CW = 8;

  // Slots that exist per FC.
  function automatic [CW-1:0] depth_of(input int unsigned t);
    case (t)
      0:       depth_of = CW'(P_DEPTH);
      1:       depth_of = CW'(NP_DEPTH);
      default: depth_of = CW'(CPL_DEPTH);
    endcase
  endfunction

  logic [CW-1:0] inflight [3];   // granted, not yet delivered on hv
  logic [CW-1:0] occupancy[3];   // delivered, not yet retired by the app
  logic [2:0]    ovf_q;

  genvar t;
  generate
    for (t = 0; t < 3; t++) begin : g_fc
      wire grant_e = grant_tlp_type[t];
      wire hv_e    = hv & hv_fc_onehot[t];
      wire pop_e   = pop[t];

      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          inflight[t]  <= '0;
          occupancy[t] <= '0;
          ovf_q[t]     <= 1'b0;
        end
        else begin
          // grant -> in the output pipe; hv -> arrived in the app buffer
          case ({grant_e, hv_e})
            2'b10:   inflight[t] <= inflight[t] + 1'b1;
            2'b01:   inflight[t] <= inflight[t] - 1'b1;
            default: inflight[t] <= inflight[t];
          endcase

          case ({hv_e, pop_e})
            2'b10:   occupancy[t] <= occupancy[t] + 1'b1;
            2'b01:   occupancy[t] <= occupancy[t] - 1'b1;
            default: occupancy[t] <= occupancy[t];
          endcase

          if (hv_e && (occupancy[t] >= depth_of(t)))     ovf_q[t] <= 1'b1;
          if (hv_e && (inflight[t] == '0) && !grant_e)   ovf_q[t] <= 1'b1;
        end
      end

      // Combinational: stop unloading this type once the buffer plus the
      // TLPs already in flight would not fit.
      assign pkt_halt[t] =
        ((occupancy[t] + inflight[t] + CW'(MARGIN)) >= depth_of(t));
    end
  endgenerate

  assign overflow = ovf_q;

endmodule

`default_nettype wire
