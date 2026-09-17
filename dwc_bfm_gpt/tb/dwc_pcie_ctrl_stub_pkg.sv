//======================================================================
// dwc_pcie_ctrl_stub_pkg.sv
//   Testbench-only model of the *controller* end of XALI / TRGT1.
//   It exists so the application BFM can be exercised (and its
//   assertions fired) without the real DWC_pcie RTL.
//
//   The interesting part is the TRGT1 halt model: the stub keeps
//   streaming for HALT_LATENCY cycles after trgt1_radm_halt goes high
//   before it finally drops radm_trgt1_dv -- exactly the behaviour the
//   Databook warns about under Figure 4-14.
//======================================================================
package dwc_pcie_ctrl_stub_pkg;

  import dwc_pcie_cfg_pkg::*;
  import dwc_pcie_core_pkg::*;
  import dwc_pcie_bfm_pkg::*;

  //====================================================================
  // XADM side of XALI: just a random halt generator.
  //====================================================================
  class dwc_xali_ctrl_stub;
    virtual dwc_pcie_xali_if vif;
    string                   name;
    int unsigned             halt_pct     = 30;
    int unsigned             halt_min_len = 1;
    int unsigned             halt_max_len = 5;

    function new(virtual dwc_pcie_xali_if vif, string name = "xali_ctrl");
      this.vif  = vif;
      this.name = name;
    endfunction

    task automatic run();
      int unsigned len;
      // Databook 4.1.1: "when idle, the transmit client interface
      // maintains xadm_clienti_halt = 1 by default".
      vif.ccb.xadm_halt <= 1'b1;
      @(vif.ccb);
      forever begin
        vif.ccb.xadm_halt <= 1'b0;
        @(vif.ccb);
        if (halt_pct != 0 && (({$random} % 100) < halt_pct)) begin
          len = halt_min_len + ({$random} % (halt_max_len - halt_min_len + 1));
          vif.ccb.xadm_halt <= 1'b1;
          repeat (len) @(vif.ccb);
        end
      end
    endtask
  endclass

  //====================================================================
  // RADM side of TRGT1: TLP generator with a pipelined halt response.
  //====================================================================
  class dwc_trgt1_ctrl_stub;
    virtual dwc_pcie_trgt1_if vif;
    string                    name;
    int unsigned              halt_latency = 3;   // cycles of dv after halt
    int unsigned              gap_pct      = 20;  // idle between TLPs
    bit                       cut_through  = 0;   // allow dv gaps inside a TLP
    int unsigned              n_sent       = 0;

    mailbox #(dwc_tlp_item)   req_mb;
    mailbox #(dwc_tlp_item)   done_mb;

    function new(virtual dwc_pcie_trgt1_if vif, string name = "trgt1_ctrl");
      this.vif     = vif;
      this.name    = name;
      this.req_mb  = new();
      this.done_mb = new();
    endfunction

    function void send(dwc_tlp_item it);
      void'(req_mb.try_put(it));
    endfunction

    protected task automatic idle_cycle();
      vif.ccb.hv  <= 1'b0;
      vif.ccb.dv  <= 1'b0;
      vif.ccb.eot <= 1'b0;
      vif.ccb.tlp_abort  <= 1'b0;
      vif.ccb.dllp_abort <= 1'b0;
      vif.ccb.ecrc_err   <= 1'b0;
      vif.ccb.grant_tlp_type <= 3'b000;
      @(vif.ccb);
    endtask

    // Hold the bus without advancing (halt has taken effect).
    protected task automatic park_cycle();
      vif.ccb.hv  <= 1'b0;
      vif.ccb.dv  <= 1'b0;
      vif.ccb.eot <= 1'b0;
      @(vif.ccb);
    endtask

    protected task automatic drive_tlp(dwc_tlp_item it);
      byte unsigned s[$];
      int unsigned  nb;
      int unsigned  halt_run = 0;
      int unsigned  i;
      bit [NDW-1:0] last_dwen;
      int unsigned  rem;

      it.wire_bytes(s);
      nb = it.has_payload() ? ((s.size() + NBYTES - 1) / NBYTES) : 0;

      rem = s.size() - (nb > 0 ? (nb - 1) * NBYTES : 0);
      last_dwen = '0;
      for (int unsigned w = 0; w < NDW; w++)
        if (w * 4 < rem) last_dwen[w] = 1'b1;

      // Grant pulse: the order controller dequeued this TLP from the
      // receive queue (Databook 4.6.3).  Must not happen in the same
      // cycle pkt_halt falls -- the BFM's assertion checks that.
      while (vif.ccb.pkt_halt[it.fc()]) @(vif.ccb);
      vif.ccb.grant_tlp_type <= (3'b001 << it.fc());
      @(vif.ccb);
      vif.ccb.grant_tlp_type <= 3'b000;

      // Header signals are held for the whole TLP.
      vif.ccb.tlp_type       <= it.tlp_type;
      vif.ccb.tlp_fmt        <= it.fmt;
      vif.ccb.addr           <= {it.addr[63:2], 2'b00};
      vif.ccb.byte_en        <= it.calc_byte_en();
      vif.ccb.byte_len       <= it.wire_byte_len();
      vif.ccb.tlp_tc         <= it.tc;
      vif.ccb.tlp_attr       <= it.attr;
      vif.ccb.tlp_td         <= it.td;
      vif.ccb.tlp_at         <= it.at;
      vif.ccb.tlp_tid        <= it.tag;
      vif.ccb.req_id         <= it.req_id;
      vif.ccb.func_num       <= it.func_num;
      vif.ccb.vfunc_num      <= it.vfunc_num;
      vif.ccb.vfunc_active   <= it.vfunc_active;
      vif.ccb.cpl_status     <= it.cpl_status;
      vif.ccb.cpl_byte_cnt   <= it.cpl_byte_cnt;
      vif.ccb.cpl_lower_addr <= it.cpl_lower_addr;
      vif.ccb.tlp_prfx       <= it.prfx;
      vif.ccb.lookup_id      <= it.lookup_id;
      vif.ccb.pkt_order_no   <= it.pkt_order_no;
      vif.ccb.dest_sgmt      <= it.dst_segment;
      vif.ccb.reqtr_sgmt     <= it.segment;
      vif.ccb.hdr_uppr_bytes <= it.hdr_uppr_bytes;
      vif.ccb.hdr_uppr_bytes_valid <= it.hdr_uppr_valid;
      vif.ccb.ep             <= it.ep;

      if (nb == 0) begin
        vif.ccb.hv  <= 1'b1;
        vif.ccb.dv  <= 1'b0;
        vif.ccb.eot <= 1'b1;
        vif.ccb.dwen <= '0;
        vif.ccb.tlp_abort  <= it.tlp_abort;
        vif.ccb.dllp_abort <= it.dllp_abort;
        vif.ccb.ecrc_err   <= it.ecrc_err;
        @(vif.ccb);
        vif.ccb.hv  <= 1'b0;
        vif.ccb.eot <= 1'b0;
        vif.ccb.tlp_abort  <= 1'b0;
        vif.ccb.dllp_abort <= 1'b0;
        vif.ccb.ecrc_err   <= 1'b0;
        n_sent++;
        void'(done_mb.try_put(it));
        return;
      end

      i = 0;
      while (i < nb) begin
        // Cut-through mode may open gaps inside the TLP (Figure 4-12).
        if (cut_through && i > 0 && (({$random} % 100) < 15)) begin
          vif.ccb.hv  <= 1'b0;
          vif.ccb.dv  <= 1'b0;
          vif.ccb.eot <= 1'b0;
          @(vif.ccb);
          continue;
        end

        vif.ccb.hv   <= (i == 0);
        vif.ccb.dv   <= 1'b1;
        vif.ccb.eot  <= (i == nb - 1);
        vif.ccb.dwen <= (i == nb - 1) ? last_dwen : '1;
        for (int unsigned k = 0; k < NBYTES; k++) begin
          int unsigned idx = i * NBYTES + k;
          vif.ccb.data[8*k +: 8] <= (idx < s.size()) ? s[idx] : 8'h00;
        end
        vif.ccb.tlp_abort  <= (i == nb - 1) ? it.tlp_abort  : 1'b0;
        vif.ccb.dllp_abort <= (i == nb - 1) ? it.dllp_abort : 1'b0;
        vif.ccb.ecrc_err   <= (i == nb - 1) ? it.ecrc_err   : 1'b0;

        @(vif.ccb);
        i++;

        // Halt takes `halt_latency` cycles to stop the datapath; until
        // then beats keep going out and the application must absorb them.
        if (vif.ccb.halt) halt_run++;
        else              halt_run = 0;

        while (halt_run > halt_latency && i < nb) begin
          park_cycle();
          if (vif.ccb.halt) halt_run++;
          else              halt_run = 0;
        end
      end

      vif.ccb.hv  <= 1'b0;
      vif.ccb.dv  <= 1'b0;
      vif.ccb.eot <= 1'b0;
      vif.ccb.tlp_abort  <= 1'b0;
      vif.ccb.dllp_abort <= 1'b0;
      vif.ccb.ecrc_err   <= 1'b0;
      n_sent++;
      void'(done_mb.try_put(it));
    endtask

    task automatic run();
      dwc_tlp_item it;
      vif.ccb.hv <= 1'b0;
      vif.ccb.dv <= 1'b0;
      vif.ccb.eot <= 1'b0;
      vif.ccb.grant_tlp_type <= 3'b000;
      @(vif.ccb);
      forever begin
        if (req_mb.try_get(it)) begin
          drive_tlp(it);
          if (gap_pct != 0 && (({$random} % 100) < gap_pct))
            repeat (1 + ({$random} % 3)) idle_cycle();
        end
        else idle_cycle();
      end
    endtask
  endclass

endpackage : dwc_pcie_ctrl_stub_pkg
