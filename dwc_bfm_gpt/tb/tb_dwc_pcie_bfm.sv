//======================================================================
// tb_dwc_pcie_bfm.sv -- self-check testbench for the XALI / TRGT1 BFM.
//
//   Test 1: application transmits random TLPs on XALI while the XADM stub
//           halts randomly.  The passive monitor must reconstruct every
//           TLP bit-exactly (covers both address-alignment modes).
//   Test 2: the RADM stub injects inbound MWr/MRd on TRGT1 while the
//           application halts randomly.  The receiver must absorb the
//           post-halt tail, and the target completer must answer every
//           Non-Posted request through the Target Completion LUT.
//======================================================================
`timescale 1ns/1ps

module tb_dwc_pcie_bfm;

  import dwc_pcie_cfg_pkg::*;
  import dwc_pcie_core_pkg::*;
  import dwc_pcie_bfm_pkg::*;
  import dwc_pcie_ctrl_stub_pkg::*;

  localparam int N_TX_TLP = 40;
  localparam int N_RX_TLP = 24;

  logic clk = 0;
  logic rst_n = 0;
  always #2.5 clk = ~clk;              // 200 MHz

  dwc_pcie_xali_if  xali (.clk(clk), .rst_n(rst_n));
  dwc_pcie_trgt1_if trgt1(.clk(clk), .rst_n(rst_n));

  //--------------------------------------------------------------------
  // Non-Posted TLP tracker driving trgt1_radm_pkt_halt.
  //--------------------------------------------------------------------
  dwc_fc_e   t1_fc;
  logic [2:0] hv_fc_onehot;
  logic [2:0] pop_pipe [0:7];
  logic [2:0] pkt_halt_w;
  logic [2:0] tracker_ovf;

  always_comb begin
    t1_fc        = dwc_fc_of(dwc_tlp_type_e'(trgt1.tlp_type), trgt1.tlp_fmt[1]);
    hv_fc_onehot = 3'b001 << t1_fc;
  end

  // The application retires a buffered TLP 8 cycles after it arrives.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 8; i++) pop_pipe[i] <= '0;
    end
    else begin
      pop_pipe[0] <= trgt1.hv ? hv_fc_onehot : 3'b000;
      for (int i = 1; i < 8; i++) pop_pipe[i] <= pop_pipe[i-1];
    end
  end

  dwc_trgt1_pkt_halt_tracker #(
    .P_DEPTH(8), .NP_DEPTH(8), .CPL_DEPTH(8), .MARGIN(3)
  ) u_tracker (
    .clk            (clk),
    .rst_n          (rst_n),
    .grant_tlp_type (trgt1.grant_tlp_type),
    .hv             (trgt1.hv),
    .hv_fc_onehot   (hv_fc_onehot),
    .pop            (pop_pipe[7]),
    .pkt_halt       (pkt_halt_w),
    .overflow       (tracker_ovf)
  );

  assign trgt1.pkt_halt = pkt_halt_w;

  //--------------------------------------------------------------------
  // BFM instances
  //--------------------------------------------------------------------
  dwc_xali_driver      tx_drv;
  dwc_xali_monitor     tx_mon;
  dwc_trgt1_receiver   rx;
  dwc_app_completer    completer;
  dwc_xali_ctrl_stub   xadm_stub;
  dwc_trgt1_ctrl_stub  radm_stub;

  int unsigned n_cmp_ok   = 0;
  int unsigned n_cmp_fail = 0;

  //--------------------------------------------------------------------
  task automatic scoreboard(int unsigned n);
    dwc_tlp_item exp;
    dwc_tlp_item got;
    string       diff;
    repeat (n) begin
      tx_drv.done_mb.get(exp);
      tx_mon.out_mb.get(got);
      if (exp.compare(got, diff)) n_cmp_ok++;
      else begin
        n_cmp_fail++;
        $display("[%0t] XALI MISMATCH: %s", $time, diff);
        $display("          sent: %s", exp.convert2string());
        $display("      observed: %s", got.convert2string());
      end
    end
  endtask

  //--------------------------------------------------------------------
  function automatic dwc_tlp_item rand_tx_tlp();
    dwc_tlp_item  it;
    byte unsigned d[$];
    int unsigned  len;
    bit [63:0]    a;
    bit           align_on;
    bit           is_wr;

    len      = 1 + ({$random} % 64);
    a        = 64'h0000_0000_8000_0000 + ({$random} % 256);
    align_on = ({$random} % 2);
    is_wr    = ({$random} % 2);

    if (is_wr) begin
      d.delete();
      for (int unsigned i = 0; i < len; i++) d.push_back(8'({$random}));
      it = dwc_tlp_item::mwr(a, d, align_on);
    end
    else begin
      it = dwc_tlp_item::mrd(a, len, 10'({$random}), align_on);
    end
    it.gap_before = ({$random} % 3);
    return it;
  endfunction

  function automatic dwc_tlp_item rand_rx_tlp(int unsigned idx);
    dwc_tlp_item  it;
    byte unsigned d[$];
    int unsigned  len;
    bit [63:0]    a;

    len = 1 + ({$random} % 32);
    a   = 64'h0000_0000_9000_0000 + ({$random} % 128);

    if (idx % 2 == 0) begin                       // inbound MWr (Posted)
      d.delete();
      for (int unsigned i = 0; i < len; i++) d.push_back(8'({$random}));
      it = dwc_tlp_item::mwr(a, d, 1'b0);
    end
    else begin                                    // inbound MRd (Non-Posted)
      it = dwc_tlp_item::mrd(a, len, 10'(idx), 1'b0);
    end
    it.req_id    = 16'h0100 + 16'(idx);
    it.lookup_id = LUT_ID_W'(idx);                // trgt_lookup_id
    return it;
  endfunction

  //--------------------------------------------------------------------
  initial begin
    tx_drv    = new(xali,  "xali0_drv");
    tx_mon    = new(xali,  "xali0_mon");
    rx        = new(trgt1, "trgt1_rx");
    completer = new(rx, tx_drv, "app_completer");
    xadm_stub = new(xali,  "xadm_stub");
    radm_stub = new(trgt1, "radm_stub");

    rx.halt_pct        = 25;
    rx.halt_max_len    = 6;
    radm_stub.halt_latency = 3;
    radm_stub.cut_through  = 1;
    completer.cpl_latency  = 3;

    fork
      tx_drv.run();
      tx_mon.run();
      rx.run();
      completer.run();
      xadm_stub.run();
      radm_stub.run();
    join_none

    repeat (10) @(posedge clk);
    rst_n = 1;
    repeat (5) @(posedge clk);

    //---- Test 1 : outbound ------------------------------------------
    $display("\n=== Test 1: %0d outbound TLPs on XALI0 ===", N_TX_TLP);
    fork
      begin
        for (int i = 0; i < N_TX_TLP; i++) begin
          tx_drv.send(rand_tx_tlp());
          if (i % 7 == 0) repeat (2) @(posedge clk);
        end
      end
      scoreboard(N_TX_TLP);
    join

    //---- Test 2 : inbound + auto-completion --------------------------
    $display("\n=== Test 2: %0d inbound TLPs on TRGT1 ===", N_RX_TLP);
    for (int i = 0; i < N_RX_TLP; i++)
      radm_stub.send(rand_rx_tlp(i));

    // Half of them are Non-Posted, each produces one Completion on XALI.
    scoreboard(N_RX_TLP / 2);

    repeat (200) @(posedge clk);

    //---- Report ------------------------------------------------------
    $display("\n================ REPORT ================");
    $display("XALI  driver sent      : %0d", tx_drv.n_sent);
    $display("XALI  monitor observed : %0d", tx_mon.n_seen);
    rx.report();
    completer.report();
    $display("scoreboard ok=%0d fail=%0d", n_cmp_ok, n_cmp_fail);
    if (|tracker_ovf)
      $display("ERROR: pkt_halt tracker overflow = %b", tracker_ovf);
    $display("========================================");

    if (n_cmp_fail == 0 && tracker_ovf == 3'b000 &&
        rx.n_seen == N_RX_TLP && completer.n_completed == N_RX_TLP/2)
      $display("*** TEST PASSED ***");
    else
      $display("*** TEST FAILED ***");
    $finish;
  end

  initial begin
    #500_000;
    $display("*** TIMEOUT ***");
    $finish;
  end

endmodule
