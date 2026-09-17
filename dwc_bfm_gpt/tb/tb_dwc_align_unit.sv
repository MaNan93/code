//======================================================================
// tb_dwc_align_unit.sv
//   Unit test for the transmit address-alignment logic of Databook 4.1.3.
//   No interfaces, no clocks -- pure round-trip of:
//
//       payload --wire_bytes()--> data bus --unpack_payload()--> payload
//
//   for every combination of byte offset, length and alignment mode.
//   Runnable with Verilator (--binary) as well as any SV simulator.
//======================================================================
`timescale 1ns/1ps

module tb_dwc_align_unit;

  import dwc_pcie_cfg_pkg::*;
  import dwc_pcie_core_pkg::*;

  int unsigned n_run  = 0;
  int unsigned n_fail = 0;

  //--------------------------------------------------------------------
  task automatic check_one(bit [63:0] a, int unsigned len, bit align_on);
    dwc_tlp_item  it;
    byte unsigned d[$];
    byte unsigned s[$];
    byte unsigned back[$];
    bit [63:0]    a_back;
    bit [12:0]    n_back;
    bit [63:0]    wire_addr;
    bit [7:0]     be;
    bit           ok;

    d.delete();
    for (int unsigned i = 0; i < len; i++) d.push_back(8'(i + 1));

    it = dwc_tlp_item::mwr(a, d, align_on);
    it.wire_bytes(s);

    // What the driver actually puts on the bus (see dwc_xali_driver).
    wire_addr = align_on ? it.addr : {it.addr[63:2], 2'b00};
    be        = align_on ? 8'h00   : it.calc_byte_en();

    dwc_bfm_util::unpack_payload(s, align_on, wire_addr, it.wire_byte_len(),
                                 be, back, a_back, n_back);

    n_run++;
    ok = 1;

    if (a_back !== a) begin
      ok = 0;
      $display("FAIL addr: a=0x%0h len=%0d align=%0b -> got 0x%0h",
               a, len, align_on, a_back);
    end
    if (n_back !== 13'(len)) begin
      ok = 0;
      $display("FAIL len : a=0x%0h len=%0d align=%0b -> got %0d",
               a, len, align_on, n_back);
    end
    if (back.size() !== len) begin
      ok = 0;
      $display("FAIL size: a=0x%0h len=%0d align=%0b -> got %0d bytes",
               a, len, align_on, back.size());
    end
    else begin
      foreach (d[i])
        if (back[i] !== d[i]) begin
          ok = 0;
          $display("FAIL data: a=0x%0h len=%0d align=%0b byte[%0d] %02h != %02h",
                   a, len, align_on, i, back[i], d[i]);
          break;
        end
    end

    // Alignment-off framing rules from 4.1.3.1.
    if (!align_on) begin
      if (wire_addr[1:0] !== 2'b00) begin
        ok = 0;
        $display("FAIL rule: addr not DWORD aligned with align_en=0 (a=0x%0h)", a);
      end
      if (it.wire_byte_len() % 4 !== 0) begin
        ok = 0;
        $display("FAIL rule: byte_len not DWORD rounded (a=0x%0h len=%0d -> %0d)",
                 a, len, it.wire_byte_len());
      end
      if ((s.size() % 4) !== 0) begin
        ok = 0;
        $display("FAIL rule: wire payload not DWORD framed (a=0x%0h len=%0d)", a, len);
      end
    end
    else begin
      if (it.wire_byte_len() !== 13'(len)) begin
        ok = 0;
        $display("FAIL rule: align_en=1 byte_len must be exact (a=0x%0h len=%0d)",
                 a, len);
      end
    end

    if (!ok) n_fail++;
  endtask

  //--------------------------------------------------------------------
  // Spot-check the FBE/LBE generator against the examples in Figure 4-5:
  // four 3-byte writes at 0x80000000..0x80000003 => 0x07, 0x0e, 0x1c, 0x38
  //--------------------------------------------------------------------
  task automatic check_fig_4_5();
    dwc_tlp_item  it;
    byte unsigned d[$];
    bit [7:0]     exp_be [4];
    bit [12:0]    exp_len[4];

    exp_be  = '{8'h07, 8'h0e, 8'h1c, 8'h38};
    exp_len = '{13'd4, 13'd4, 13'd8, 13'd8};

    d.delete();
    for (int unsigned i = 0; i < 3; i++) d.push_back(8'(i));

    for (int unsigned k = 0; k < 4; k++) begin
      it = dwc_tlp_item::mwr(64'h8000_0000 + k, d, 1'b0);
      n_run++;
      if (it.calc_byte_en() !== exp_be[k]) begin
        n_fail++;
        $display("FAIL fig4-5 byte_en[%0d]: got 0x%02h expected 0x%02h",
                 k, it.calc_byte_en(), exp_be[k]);
      end
      if (it.wire_byte_len() !== exp_len[k]) begin
        n_fail++;
        $display("FAIL fig4-5 byte_len[%0d]: got %0d expected %0d",
                 k, it.wire_byte_len(), exp_len[k]);
      end
    end
  endtask

  //--------------------------------------------------------------------
  initial begin
    $display("=== alignment unit test, DW=%0d (%0d bytes/beat) ===", DW, NBYTES);

    check_fig_4_5();

    for (int unsigned off = 0; off < 4; off++)
      for (int unsigned len = 1; len <= 2*NBYTES + 5; len++) begin
        check_one(64'h8000_0000 + off, len, 1'b0);   // alignment off
        check_one(64'h8000_0000 + off, len, 1'b1);   // alignment on
      end

    // 64-bit addresses / higher offsets
    for (int unsigned off = 0; off < 4; off++)
      for (int unsigned len = 1; len <= 9; len++) begin
        check_one(64'h1234_5678_9000_0000 + off, len, 1'b0);
        check_one(64'h1234_5678_9000_0000 + off, len, 1'b1);
      end

    $display("=== %0d checks, %0d failures ===", n_run, n_fail);
    if (n_fail == 0) $display("*** ALIGN UNIT TEST PASSED ***");
    else             $display("*** ALIGN UNIT TEST FAILED ***");
    $finish;
  end

endmodule
