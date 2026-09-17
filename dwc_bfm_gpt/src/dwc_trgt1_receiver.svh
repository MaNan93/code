//======================================================================
// dwc_trgt1_receiver.svh
//   Application-side receiver for one TRGT1 (receive request) interface.
//
//   CRITICAL DIFFERENCE FROM AXI  (Databook 4.6.1 + note under Fig 4-14):
//   trgt1_radm_halt is a *request to pause*, not a ready.  After the
//   application asserts halt, radm_trgt1_dv stays high for a further,
//   pipeline-dependent number of cycles and those beats carry real data.
//   Therefore this receiver consumes a beat on EVERY cycle where dv == 1
//   and never gates acceptance on halt.  `max_inflight_after_halt` tracks
//   how deep that tail actually got, so you can size the application FIFO.
//======================================================================
class dwc_trgt1_receiver;

  virtual dwc_pcie_trgt1_if  vif;
  string                     name;
  mailbox #(dwc_tlp_item)    out_mb;

  //---- back-pressure knobs -------------------------------------------
  int unsigned               halt_pct      = 0;   // % of cycles halt is raised
  int unsigned               halt_min_len  = 1;
  int unsigned               halt_max_len  = 4;
  bit                        use_dwen      = 1;   // honour dwen on last beat

  //---- statistics -----------------------------------------------------
  int unsigned               n_seen        = 0;
  int unsigned               n_tlp_abort   = 0;
  int unsigned               n_dllp_abort  = 0;
  int unsigned               n_ecrc_err    = 0;
  int unsigned               max_inflight_after_halt = 0;
  bit                        verbose       = 0;

  protected dwc_tlp_item     cur;
  protected byte unsigned    raw[$];
  protected int unsigned     tail_beats;

  function new(virtual dwc_pcie_trgt1_if vif, string name = "trgt1_rx");
    this.vif    = vif;
    this.name   = name;
    this.out_mb = new();
  endfunction

  //--------------------------------------------------------------------
  // Monitor / consumer thread.
  //--------------------------------------------------------------------
  task automatic run_rx();
    bit [63:0]    a;
    bit [12:0]    n;
    byte unsigned pl[$];

    forever begin
      @(vif.scb);

      if (!vif.rst_n) begin
        cur = null;
        raw.delete();
        tail_beats = 0;
        continue;
      end

      if (vif.scb.hv) begin
        cur = new();
        cur.t_start        = $time;
        cur.tlp_type       = dwc_tlp_type_e'(vif.scb.tlp_type);
        cur.fmt            = vif.scb.tlp_fmt;
        cur.addr           = vif.scb.addr;
        cur.byte_en        = vif.scb.byte_en;
        cur.byte_len       = vif.scb.byte_len;
        cur.tc             = vif.scb.tlp_tc;
        cur.attr           = vif.scb.tlp_attr;
        cur.td             = vif.scb.tlp_td;
        cur.at             = vif.scb.tlp_at;
        cur.tag            = vif.scb.tlp_tid;
        cur.req_id         = vif.scb.req_id;
        cur.func_num       = vif.scb.func_num;
        cur.vfunc_num      = vif.scb.vfunc_num;
        cur.vfunc_active   = vif.scb.vfunc_active;
        cur.cpl_status     = vif.scb.cpl_status;
        cur.cpl_byte_cnt   = vif.scb.cpl_byte_cnt;
        cur.cpl_lower_addr = vif.scb.cpl_lower_addr;
        cur.prfx           = vif.scb.tlp_prfx;
        cur.ep             = vif.scb.ep;
        cur.lookup_id      = vif.scb.lookup_id;       // valid with hv (4.1.4)
        cur.pkt_order_no   = vif.scb.pkt_order_no;
        cur.hdr_uppr_bytes = vif.scb.hdr_uppr_bytes;
        cur.hdr_uppr_valid = vif.scb.hdr_uppr_bytes_valid;
        cur.dst_segment    = vif.scb.dest_sgmt;
        cur.segment        = vif.scb.reqtr_sgmt;
        cur.addr_align_en  = 1'b0;    // RADM always presents DWORD framing
        raw.delete();
      end

      if (cur == null) continue;

      // Consume on dv, independent of halt (see header comment).
      if (vif.scb.dv) begin
        if (vif.halt) begin
          tail_beats++;
          if (tail_beats > max_inflight_after_halt)
            max_inflight_after_halt = tail_beats;
        end
        // dwen is not trustworthy on the eot beat of a dllp_abort TLP
        // (Databook L.1 attention box) -- fall back to a full beat there.
        if (use_dwen && vif.scb.eot && !vif.scb.dllp_abort)
          dwc_bfm_util::beat_to_bytes_dwen(vif.scb.data, vif.scb.dwen, raw);
        else
          dwc_bfm_util::beat_to_bytes(vif.scb.data, raw);
        cur.beats_observed++;
      end

      if (!vif.halt) tail_beats = 0;

      if (vif.scb.eot) begin
        dwc_bfm_util::unpack_payload(raw, 1'b0, cur.addr, cur.byte_len,
                                     cur.byte_en, pl, a, n);
        cur.payload    = pl;
        cur.addr       = a;
        cur.byte_len   = n;
        cur.tlp_abort  = vif.scb.tlp_abort;
        cur.dllp_abort = vif.scb.dllp_abort;
        cur.ecrc_err   = vif.scb.ecrc_err;
        cur.ep         = vif.scb.ep;          // poisoned is valid with eot
        cur.t_end      = $time;
        n_seen++;
        if (cur.tlp_abort)  n_tlp_abort++;
        if (cur.dllp_abort) n_dllp_abort++;
        if (cur.ecrc_err)   n_ecrc_err++;
        if (verbose)
          $display("[%0t] %s RECEIVED %s", $time, name, cur.convert2string());
        void'(out_mb.try_put(cur));
        cur = null;
        raw.delete();
      end
    end
  endtask

  //--------------------------------------------------------------------
  // trgt1_radm_halt generator.
  //--------------------------------------------------------------------
  task automatic run_halt();
    int unsigned len;
    vif.scb.halt <= 1'b0;
    forever begin
      @(vif.scb);
      if (!vif.rst_n) begin
        vif.scb.halt <= 1'b0;
        continue;
      end
      if (halt_pct != 0 && (({$random} % 100) < halt_pct)) begin
        len = halt_min_len + ({$random} % (halt_max_len - halt_min_len + 1));
        vif.scb.halt <= 1'b1;
        repeat (len) @(vif.scb);
        vif.scb.halt <= 1'b0;
      end
    end
  endtask

  task automatic run();
    fork
      run_rx();
      run_halt();
    join
  endtask

  function void report();
    $display("%s: %0d TLPs (tlp_abort=%0d dllp_abort=%0d ecrc_err=%0d), max %0d beats arrived after halt",
             name, n_seen, n_tlp_abort, n_dllp_abort, n_ecrc_err,
             max_inflight_after_halt);
  endfunction

endclass : dwc_trgt1_receiver
