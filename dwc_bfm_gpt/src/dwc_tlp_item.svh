//======================================================================
// dwc_tlp_item.svh -- transaction object shared by the XALI and TRGT1
// sides of the BFM.  Payload is held as a byte queue so that the
// address-alignment modes of Databook 4.1.3 can be modelled exactly.
//======================================================================
class dwc_tlp_item;

  //---- header ---------------------------------------------------------
  dwc_tlp_type_e     tlp_type       = DWC_TLP_MEM;
  bit [2:0]          fmt            = 3'b000;
  bit [63:0]         addr           = '0;
  bit [7:0]          byte_en        = 8'h0f;   // {LBE,FBE}, align-off only
  bit [12:0]         byte_len       = 13'd4;
  bit [2:0]          tc             = '0;
  bit [2:0]          attr           = '0;
  bit                td             = 1'b0;
  bit                ep             = 1'b0;
  bit [1:0]          at             = '0;
  bit [9:0]          tag            = '0;
  bit [15:0]         req_id         = '0;      // remote_req_id on XALI
  bit [4:0]          func_num       = '0;
  bit [7:0]          vfunc_num      = '0;
  bit                vfunc_active   = 1'b0;
  bit [2:0]          cpl_status     = '0;
  bit [12:0]         cpl_byte_cnt   = '0;
  bit [6:0]          cpl_lower_addr = '0;      // TRGT1 only
  bit [PRFX_W-1:0]   prfx           = '0;
  bit [1:0]          segment        = '0;
  bit [1:0]          dst_segment    = '0;
  bit [2:0]          order_seqnum   = '0;

  //---- XALI-only controls --------------------------------------------
  bit                addr_align_en  = 1'b0;    // clienti_addr_align_en
  bit                use_cpl_lut    = 1'b0;    // drive cpl_lookup_id instead of
                                               // req_id/byte_cnt/attr/addr/tid/tc
  bit [LUT_ID_W-1:0] cpl_lookup_id  = '0;
  bit                inject_bad_eot = 1'b0;    // abort the TLP on its last beat
  int unsigned       gap_before     = 0;       // idle cycles before the header

  //---- TRGT1-only status ---------------------------------------------
  bit                tlp_abort      = 1'b0;
  bit                dllp_abort     = 1'b0;
  bit                ecrc_err       = 1'b0;
  bit [LUT_ID_W-1:0] lookup_id      = '0;
  bit [15:0]         pkt_order_no   = '0;
  bit [63:0]         hdr_uppr_bytes = '0;
  bit                hdr_uppr_valid = 1'b0;

  //---- payload --------------------------------------------------------
  // payload[0] is the FIRST ENABLED BYTE of the request (the byte living at
  // `addr`), independent of the alignment mode.  wire_bytes() takes care of
  // up-shifting it when addr_align_en == 0.
  byte unsigned      payload[$];

  //---- bookkeeping ----------------------------------------------------
  int unsigned       beats_observed = 0;
  time               t_start, t_end;

  //====================================================================
  function new();
  endfunction

  function bit has_payload();
    return (payload.size() != 0);
  endfunction

  function dwc_fc_e fc();
    return dwc_fc_of(tlp_type, fmt[1]);   // fmt[1]==1 -> "with data"
  endfunction

  //--------------------------------------------------------------------
  // Byte stream actually presented on clienti_tlp_data.
  //   align ON  : first enabled byte sits on data[7:0]         (4.1.3.2)
  //   align OFF : the application up-shifts by addr[1:0] and pads the
  //               tail up to a DWORD boundary                  (4.1.3.1)
  //--------------------------------------------------------------------
  function void wire_bytes(ref byte unsigned s[$]);
    int unsigned lead;
    int unsigned tail;
    s.delete();
    if (addr_align_en) begin
      foreach (payload[i]) s.push_back(payload[i]);
    end
    else begin
      lead = addr[1:0];
      repeat (lead) s.push_back(8'h00);
      foreach (payload[i]) s.push_back(payload[i]);
      tail = (4 - (s.size() % 4)) % 4;
      repeat (tail) s.push_back(8'h00);
    end
  endfunction

  // Value the application must drive on clienti_tlp_byte_len.
  //   align ON  : the true byte length
  //   align OFF : rounded up to the next DWORD boundary, bits[1:0] == 0
  function bit [12:0] wire_byte_len();
    int unsigned n;
    if (addr_align_en) return byte_len;
    n = addr[1:0] + byte_len;
    return 13'(((n + 3) / 4) * 4);
  endfunction

  // Number of beats the TLP occupies on a DW-bit datapath.
  function int unsigned n_beats();
    byte unsigned s[$];
    if (!has_payload()) return 0;
    wire_bytes(s);
    return (s.size() + NBYTES - 1) / NBYTES;
  endfunction

  // FBE/LBE the application must drive when alignment is off.
  function bit [7:0] calc_byte_en();
    int unsigned first;
    int unsigned last;
    int unsigned ndw;
    bit [3:0] fbe;
    bit [3:0] lbe;
    if (byte_len == 0) return 8'h00;            // e.g. Msg without payload
    first = addr[1:0];
    ndw   = (first + byte_len + 3) / 4;
    fbe   = 4'hf << first;
    if (ndw == 1) begin
      fbe = fbe & (4'hf >> (4 - (first + byte_len)));
      lbe = 4'h0;
    end
    else begin
      last = (first + byte_len) % 4;
      lbe  = (last == 0) ? 4'hf : (4'hf >> (4 - last));
    end
    return {lbe, fbe};
  endfunction

  function string convert2string();
    return $sformatf({"type=%s fmt=%0h addr=0x%016h len=%0d be=0x%02h ",
                      "tag=%0d rid=0x%04h attr=%0h tc=%0d td=%0b ep=%0b ",
                      "align=%0b lut_id=%0d bytes=%0d%s%s%s"},
                     tlp_type.name(), fmt, addr, byte_len, byte_en, tag,
                     req_id, attr, tc, td, ep, addr_align_en, cpl_lookup_id,
                     payload.size(),
                     tlp_abort  ? " TLP_ABORT"  : "",
                     dllp_abort ? " DLLP_ABORT" : "",
                     ecrc_err   ? " ECRC_ERR"   : "");
  endfunction

  function dwc_tlp_item clone();
    dwc_tlp_item c = new();
    c.tlp_type = tlp_type;  c.fmt = fmt;  c.addr = addr;
    c.byte_en = byte_en;    c.byte_len = byte_len;
    c.tc = tc;  c.attr = attr;  c.td = td;  c.ep = ep;  c.at = at;
    c.tag = tag;  c.req_id = req_id;  c.func_num = func_num;
    c.vfunc_num = vfunc_num;  c.vfunc_active = vfunc_active;
    c.cpl_status = cpl_status;  c.cpl_byte_cnt = cpl_byte_cnt;
    c.cpl_lower_addr = cpl_lower_addr;  c.prfx = prfx;
    c.segment = segment;  c.dst_segment = dst_segment;
    c.order_seqnum = order_seqnum;  c.addr_align_en = addr_align_en;
    c.use_cpl_lut = use_cpl_lut;  c.cpl_lookup_id = cpl_lookup_id;
    c.inject_bad_eot = inject_bad_eot;  c.gap_before = gap_before;
    c.tlp_abort = tlp_abort;  c.dllp_abort = dllp_abort;
    c.ecrc_err = ecrc_err;  c.lookup_id = lookup_id;
    c.pkt_order_no = pkt_order_no;  c.hdr_uppr_bytes = hdr_uppr_bytes;
    c.hdr_uppr_valid = hdr_uppr_valid;
    c.payload = payload;
    return c;
  endfunction

  // Field-by-field compare, used by the loop-back scoreboard.
  function bit compare(dwc_tlp_item rhs, ref string diff);
    diff = "";
    if (tlp_type !== rhs.tlp_type) diff = {diff, $sformatf("type %s/%s ", tlp_type.name(), rhs.tlp_type.name())};
    if (fmt      !== rhs.fmt     ) diff = {diff, $sformatf("fmt %0h/%0h ", fmt, rhs.fmt)};
    if (addr     !== rhs.addr    ) diff = {diff, $sformatf("addr %0h/%0h ", addr, rhs.addr)};
    if (byte_len !== rhs.byte_len) diff = {diff, $sformatf("len %0d/%0d ", byte_len, rhs.byte_len)};
    if (tag      !== rhs.tag     ) diff = {diff, $sformatf("tag %0d/%0d ", tag, rhs.tag)};
    if (payload.size() !== rhs.payload.size())
      diff = {diff, $sformatf("nbytes %0d/%0d ", payload.size(), rhs.payload.size())};
    else
      foreach (payload[i])
        if (payload[i] !== rhs.payload[i])
          diff = {diff, $sformatf("data[%0d] %02h/%02h ", i, payload[i], rhs.payload[i])};
    return (diff == "");
  endfunction

  //--------------------------------------------------------------------
  // Convenience constructors
  //--------------------------------------------------------------------
  static function dwc_tlp_item mrd(bit [63:0] a, int unsigned len,
                                   bit [9:0] tg = 0, bit align_on = 0);
    dwc_tlp_item it = new();
    it.tlp_type = DWC_TLP_MEM;
    it.fmt      = (a[63:32] != 0) ? 3'b001 : 3'b000;   // 4DW/3DW, no data
    it.addr     = a;
    it.byte_len = 13'(len);
    it.tag      = tg;
    it.addr_align_en = align_on;
    it.byte_en  = align_on ? 8'h00 : it.calc_byte_en();
    return it;
  endfunction

  static function dwc_tlp_item mwr(bit [63:0] a, byte unsigned d[$],
                                   bit align_on = 0);
    dwc_tlp_item it = new();
    it.tlp_type = DWC_TLP_MEM;
    it.fmt      = (a[63:32] != 0) ? 3'b011 : 3'b010;   // 4DW/3DW, with data
    it.addr     = a;
    it.payload  = d;
    it.byte_len = 13'(d.size());
    it.addr_align_en = align_on;
    it.byte_en  = align_on ? 8'h00 : it.calc_byte_en();
    return it;
  endfunction

  // Completion built from a received TRGT1 request through the Target
  // Completion LUT (Databook 4.1.4): only the lookup id + payload needed.
  static function dwc_tlp_item cpld_via_lut(bit [LUT_ID_W-1:0] id,
                                            byte unsigned d[$]);
    dwc_tlp_item it = new();
    it.tlp_type      = DWC_TLP_CPLD;
    it.fmt           = 3'b010;
    it.payload       = d;
    it.byte_len      = 13'(d.size());
    it.addr_align_en = 1'b0;          // never for Completions
    it.use_cpl_lut   = 1'b1;
    it.cpl_lookup_id = id;
    it.byte_en       = it.calc_byte_en();
    return it;
  endfunction

endclass : dwc_tlp_item
