//======================================================================
// dwc_xali_monitor.svh
//   Passive reconstruction of the TLPs the application pushed into the
//   XADM.  Mirror image of the driver: a cycle counts only when
//   xadm_clienti_halt == 0.
//======================================================================
class dwc_xali_monitor;

  virtual dwc_pcie_xali_if   vif;
  string                     name;
  mailbox #(dwc_tlp_item)    out_mb;

  int unsigned               n_seen  = 0;
  int unsigned               n_abort = 0;
  bit                        verbose = 0;

  protected dwc_tlp_item     cur;
  protected byte unsigned    raw[$];

  function new(virtual dwc_pcie_xali_if vif, string name = "xali_mon");
    this.vif    = vif;
    this.name   = name;
    this.out_mb = new();
  endfunction

  task automatic run();
    bit [63:0]    a;
    bit [12:0]    n;
    byte unsigned pl[$];

    forever begin
      @(vif.pcb);

      if (!vif.rst_n) begin
        cur = null;
        raw.delete();
        continue;
      end

      // Halted cycles are re-presentations of the previous beat.
      if (vif.pcb.xadm_halt) continue;

      if (vif.pcb.tlp_hv) begin
        cur = new();
        cur.t_start       = $time;
        cur.tlp_type      = dwc_tlp_type_e'(vif.pcb.tlp_type);
        cur.fmt           = vif.pcb.tlp_fmt;
        cur.byte_en       = vif.pcb.tlp_byte_en;
        cur.tc            = vif.pcb.tlp_tc;
        cur.attr          = vif.pcb.tlp_attr;
        cur.td            = vif.pcb.tlp_td;
        cur.ep            = vif.pcb.tlp_ep;
        cur.at            = vif.pcb.tlp_at;
        cur.tag           = vif.pcb.tlp_tid;
        cur.req_id        = vif.pcb.remote_req_id;
        cur.func_num      = vif.pcb.tlp_func_num;
        cur.vfunc_num     = vif.pcb.tlp_vfunc_num;
        cur.vfunc_active  = vif.pcb.tlp_vfunc_active;
        cur.cpl_status    = vif.pcb.cpl_status;
        cur.cpl_byte_cnt  = vif.pcb.cpl_byte_cnt;
        cur.prfx          = vif.pcb.tlp_prfx;
        cur.cpl_lookup_id = vif.pcb.cpl_lookup_id;
        cur.addr_align_en = vif.pcb.addr_align_en;
        cur.order_seqnum  = vif.pcb.tlp_order_seqnum;
        cur.segment       = vif.pcb.tlp_segment;
        cur.dst_segment   = vif.pcb.tlp_dst_segment;
        cur.addr          = vif.pcb.tlp_addr;     // fixed up at eot
        cur.byte_len      = vif.pcb.tlp_byte_len; // ditto
        raw.delete();
      end

      if (cur == null) continue;

      if (vif.pcb.tlp_dv) begin
        dwc_bfm_util::beat_to_bytes(vif.pcb.tlp_data, raw);
        cur.beats_observed++;
      end

      if (vif.pcb.tlp_eot) begin
        dwc_bfm_util::unpack_payload(raw, cur.addr_align_en, cur.addr,
                                     cur.byte_len, cur.byte_en, pl, a, n);
        cur.payload        = pl;
        cur.addr           = a;
        cur.byte_len       = n;
        cur.inject_bad_eot = vif.pcb.tlp_bad_eot;
        cur.t_end          = $time;
        n_seen++;
        if (cur.inject_bad_eot) n_abort++;
        if (verbose)
          $display("[%0t] %s OBSERVED %s", $time, name, cur.convert2string());
        void'(out_mb.try_put(cur));
        cur = null;
        raw.delete();
      end
    end
  endtask

endclass : dwc_xali_monitor
