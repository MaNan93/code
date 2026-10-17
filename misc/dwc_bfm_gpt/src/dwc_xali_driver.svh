//======================================================================
// dwc_xali_driver.svh
//   Application-side driver for one XALI (transmit client) interface.
//
//   The whole DWC transmit handshake collapses into one rule:
//
//       a cycle is CONSUMED by the controller iff  xadm_clienti_halt == 0
//
//   so the driver is a "beat pump": it flattens each TLP into a queue of
//   per-cycle beats and pops exactly one beat per non-halted cycle, while
//   holding every output stable on halted cycles (Databook 4.1.1).
//   Because the queue is refilled before the next clock edge, consecutive
//   TLPs go out back-to-back with no bubble, matching Figure 4-1 / 4-3.
//======================================================================
class dwc_xali_driver;

  virtual dwc_pcie_xali_if      vif;
  string                        name;

  mailbox #(dwc_tlp_item)       req_mb;    // TLPs to send
  mailbox #(dwc_tlp_item)       done_mb;   // TLPs whose eot was accepted

  // Inter-TLP idle injection (never inside a TLP -- bubbles are illegal).
  int unsigned                  min_gap = 0;
  int unsigned                  max_gap = 0;

  int unsigned                  n_sent  = 0;
  bit                           verbose = 0;

  protected dwc_xali_beat_t     beat_q[$];
  protected dwc_tlp_item        item_of_last_beat[$];  // 1:1 with eot beats

  //====================================================================
  function new(virtual dwc_pcie_xali_if vif, string name = "xali_drv");
    this.vif     = vif;
    this.name    = name;
    this.req_mb  = new();
    this.done_mb = new();
  endfunction

  //--------------------------------------------------------------------
  function void send(dwc_tlp_item it);
    void'(req_mb.try_put(it));
  endfunction

  //--------------------------------------------------------------------
  protected function dwc_xali_hdr_t pack_hdr(dwc_tlp_item it);
    dwc_xali_hdr_t h;
    h = '0;
    h.tlp_type         = it.tlp_type;
    h.tlp_fmt          = it.fmt;
    // Alignment off => the address presented to the controller must be
    // DWORD aligned; the byte offset is carried by FBE (Databook 4.1.3.1).
    h.tlp_addr         = it.addr_align_en ? it.addr : {it.addr[63:2], 2'b00};
    h.tlp_byte_en      = it.addr_align_en ? 8'h00   : it.calc_byte_en();
    h.tlp_byte_len     = it.wire_byte_len();
    h.tlp_tc           = it.tc;
    h.tlp_attr         = it.attr;
    h.tlp_td           = it.td;
    h.tlp_ep           = it.ep;
    h.tlp_at           = it.at;
    h.tlp_tid          = it.tag;
    h.remote_req_id    = it.req_id;
    h.tlp_func_num     = it.func_num;
    h.tlp_vfunc_num    = it.vfunc_num;
    h.tlp_vfunc_active = it.vfunc_active;
    h.cpl_status       = it.cpl_status;
    h.cpl_byte_cnt     = it.cpl_byte_cnt;
    h.tlp_prfx         = it.prfx;
    h.cpl_lookup_id    = it.cpl_lookup_id;
    h.addr_align_en    = it.addr_align_en;
    h.tlp_order_seqnum = it.order_seqnum;
    h.tlp_segment      = it.segment;
    h.tlp_dst_segment  = it.dst_segment;

    // Target Completion LUT (Databook 4.1.4): with TRGT_CPL_LUT_EN the
    // application supplies only the lookup id -- these fields are filled
    // in by the controller, so leave them at zero to prove it works.
    if (it.use_cpl_lut) begin
      h.remote_req_id = '0;
      h.cpl_byte_cnt  = '0;
      h.tlp_attr      = '0;
      h.tlp_addr      = '0;
      h.tlp_tid       = '0;
      h.tlp_tc        = '0;
    end
    return h;
  endfunction

  //--------------------------------------------------------------------
  protected function void flatten(dwc_tlp_item it);
    byte unsigned    s[$];
    int unsigned     nb;
    int unsigned     gap;
    dwc_xali_hdr_t   h;
    dwc_xali_beat_t  b;

    h = pack_hdr(it);
    it.wire_bytes(s);
    nb = it.has_payload() ? ((s.size() + NBYTES - 1) / NBYTES) : 0;

    gap = it.gap_before;
    if (gap == 0 && max_gap > 0)
      gap = min_gap + ({$random} % (max_gap - min_gap + 1));
    repeat (gap) begin
      b = '{default: '0};
      b.idle = 1'b1;
      beat_q.push_back(b);
      item_of_last_beat.push_back(null);
    end

    if (nb == 0) begin
      // No payload (MRd, Msg, Cpl w/o data): dv must NEVER be asserted and
      // eot rides on the header cycle.
      b         = '{default: '0};
      b.hv      = 1'b1;
      b.dv      = 1'b0;
      b.eot     = 1'b1;
      b.bad_eot = it.inject_bad_eot;
      b.hdr     = h;
      beat_q.push_back(b);
      item_of_last_beat.push_back(it);
    end
    else begin
      for (int unsigned i = 0; i < nb; i++) begin
        b         = '{default: '0};
        b.hv      = (i == 0);                 // hv & dv together on beat 0
        b.dv      = 1'b1;
        b.eot     = (i == nb - 1);
        b.bad_eot = (i == nb - 1) && it.inject_bad_eot;
        b.hdr     = h;                        // header stable for whole TLP
        for (int unsigned k = 0; k < NBYTES; k++) begin
          int unsigned idx = i * NBYTES + k;
          b.data[8*k +: 8] = (idx < s.size()) ? s[idx] : 8'h00;
        end
        beat_q.push_back(b);
        item_of_last_beat.push_back((i == nb - 1) ? it : null);
      end
    end
  endfunction

  //--------------------------------------------------------------------
  protected task drive_beat(dwc_xali_beat_t b);
    vif.mcb.tlp_hv           <= b.idle ? 1'b0 : b.hv;
    vif.mcb.tlp_dv           <= b.idle ? 1'b0 : b.dv;
    vif.mcb.tlp_eot          <= b.idle ? 1'b0 : b.eot;
    vif.mcb.tlp_bad_eot      <= b.idle ? 1'b0 : b.bad_eot;
    vif.mcb.tlp_data         <= b.data;
    vif.mcb.tlp_type         <= b.hdr.tlp_type;
    vif.mcb.tlp_fmt          <= b.hdr.tlp_fmt;
    vif.mcb.tlp_addr         <= b.hdr.tlp_addr;
    vif.mcb.tlp_byte_en      <= b.hdr.tlp_byte_en;
    vif.mcb.tlp_byte_len     <= b.hdr.tlp_byte_len;
    vif.mcb.tlp_tc           <= b.hdr.tlp_tc;
    vif.mcb.tlp_attr         <= b.hdr.tlp_attr;
    vif.mcb.tlp_td           <= b.hdr.tlp_td;
    vif.mcb.tlp_ep           <= b.hdr.tlp_ep;
    vif.mcb.tlp_at           <= b.hdr.tlp_at;
    vif.mcb.tlp_tid          <= b.hdr.tlp_tid;
    vif.mcb.remote_req_id    <= b.hdr.remote_req_id;
    vif.mcb.tlp_func_num     <= b.hdr.tlp_func_num;
    vif.mcb.tlp_vfunc_num    <= b.hdr.tlp_vfunc_num;
    vif.mcb.tlp_vfunc_active <= b.hdr.tlp_vfunc_active;
    vif.mcb.cpl_status       <= b.hdr.cpl_status;
    vif.mcb.cpl_byte_cnt     <= b.hdr.cpl_byte_cnt;
    vif.mcb.tlp_prfx         <= b.hdr.tlp_prfx;
    vif.mcb.cpl_lookup_id    <= b.hdr.cpl_lookup_id;
    vif.mcb.addr_align_en    <= b.hdr.addr_align_en;
    vif.mcb.tlp_order_seqnum <= b.hdr.tlp_order_seqnum;
    vif.mcb.tlp_segment      <= b.hdr.tlp_segment;
    vif.mcb.tlp_dst_segment  <= b.hdr.tlp_dst_segment;
  endtask

  protected task drive_idle();
    dwc_xali_beat_t b;
    b      = '{default: '0};
    b.idle = 1'b1;
    drive_beat(b);
  endtask

  //--------------------------------------------------------------------
  task automatic run();
    dwc_tlp_item     it;
    dwc_xali_beat_t  b;
    dwc_tlp_item     tail;

    drive_idle();
    @(vif.mcb);

    forever begin
      if (!vif.rst_n) begin
        beat_q.delete();
        item_of_last_beat.delete();
        drive_idle();
        @(vif.mcb);
        continue;
      end

      // Top the beat queue up *before* the edge so back-to-back TLPs
      // leave no bubble on the bus.
      while (beat_q.size() < 2 && req_mb.try_get(it))
        flatten(it);

      if (beat_q.size() == 0) begin
        drive_idle();
        @(vif.mcb);
        continue;
      end

      b = beat_q[0];
      drive_beat(b);
      @(vif.mcb);

      // xadm_halt sampled at this edge qualifies the cycle we just drove.
      if (b.idle || !vif.mcb.xadm_halt) begin
        void'(beat_q.pop_front());
        tail = item_of_last_beat.pop_front();
        if (tail != null) begin
          tail.t_end = $time;
          n_sent++;
          void'(done_mb.try_put(tail));
          if (verbose)
            $display("[%0t] %s SENT %s", $time, name, tail.convert2string());
        end
      end
    end
  endtask

endclass : dwc_xali_driver
