# DWC PCIe Traditional Native Interface BFM

Common, mode-independent transport BFM for the Synopsys DWC PCIe Controller
5.40a through 6.60a traditional XALI0/RTRGT1 interface. It intentionally
contains no SystemVerilog class.

## Scope

- Drives one XALI client with correct `hv/dv/eot/halt` behavior.
- Receives and reconstructs one RTRGT stream; `dv` gaps are legal.
- Supports header-only and payload-bearing TLPs.
- Implements the section 4.1.3 address-alignment rules for the default XALI
  send path.
- Uses separate driver and monitor clocking blocks to avoid DUT/BFM races.
- Models RTRGT global-halt propagation with a configurable pipeline latency.
- Supports P/NP/CPL packet halt (`[0]`, `[1]`, `[2]`).
- Checks basic transfer framing, payload length, abort timing, queue overflow,
  XALI no-bubble behavior, XALI stability while halted, and RTRGT stability
  after its configured halt drain window.

It does not yet check RP/EP/DM/SW-specific legal TLP types, routing, requester
tracking, Completion matching, or Switch port pairing.

## Integration

The interface uses the traditional DWC signal names and separate header fields,
including `client0_tlp_fmt/type/...` and `radm_trgt1_fmt/type/...`. Optional
ports that are not common to both versions are deliberately excluded: prefix,
RAS protection, ATU bypass, VF-specific fields, TPH/steering, Flit segment,
token and MultiStream ports.

```systemverilog
dwc_pcie_native_common_bfm #(
  .DATA_WIDTH               (256),
  .TAG_WIDTH                     (10),
  .ATTR_WIDTH                    (3),
  .FUNC_NUM_WIDTH                (3),
  .BFM_TRGT_HALT_LATENCY_CYCLES (4)
) native_bfm (
  .core_clk   (core_clk),
  .core_rst_n (core_rst_n)
);

initial begin
  byte unsigned payload[];
  native_bfm.xali_header_t xali_header;
  native_bfm.start();
  native_bfm.wait_reset_release();

  payload = new[64];
  foreach (payload[i]) payload[i] = i;
  xali_header.addr          = 64'h8000_0001;
  xali_header.byte_len      = payload.size(); // logical byte length
  xali_header.addr_align_en = 1'b0;
  native_bfm.send_xali(xali_header, payload, 1'b0);
end
```

The default `send_xali()` path accepts a logical byte address and payload:

- With `addr_align_en=1`, it drives `byte_en=0`, preserves the byte address,
  and uses the logical byte length.
- With `addr_align_en=0`, it rounds `byte_len` up to a DWORD boundary, aligns
  `addr[1:0]` to zero, calculates FBE/LBE, shifts payload bytes by the original
  address offset, and inserts leading/trailing padding.

For Message TLPs or deliberately preformatted/error-injection traffic, pass
`raw_format=1` as the fourth argument. In that mode the BFM drives the header
and payload exactly as supplied.

The address-alignment-off formatting matches the Databook Figure 4-5 cases for
a three-byte write:

| Logical address low bits | Driven address low bits | Driven byte_len | byte_en |
|---:|---:|---:|---:|
| `00` | `00` | 4 | `8'h07` |
| `01` | `00` | 4 | `8'h0e` |
| `10` | `00` | 8 | `8'h1c` |
| `11` | `00` | 8 | `8'h38` |

For a header-only read, put the requested/aligned byte count in
`xali_header.byte_len`; `dv` remains low even though `byte_len` is non-zero:

```systemverilog
payload = new[0];
mrd_header.byte_len = 512;
native_bfm.send_xali(mrd_header, payload, 1'b0);
```

`BFM_TRGT_HALT_LATENCY_CYCLES` must be at least the DUT's maximum output-pipe
drain latency. RTRGT halt is not an AXI-style ready signal. The checker reports
an error if RTRGT outputs continue changing beyond this window and attempts to
capture the unexpected advancing beat instead of silently dropping it.

`client0_tlp_byte_en[7:0]` carries `{last_dw_be, first_dw_be}` and is not a
payload byte-valid mask. `radm_trgt1_dwen` is a contiguous LSB mask locating
the final valid DWORD of the data beat. RTRGT length is
`radm_trgt1_dw_len[9:0]`; zero encodes 1024 DWORDs.

## RTRGT receive example

`get_trgt_packet()` blocks until the monitor has reconstructed one complete
TLP. The monitor accepts legal `dv` gaps and uses `radm_trgt_dwen` to collect
only enabled DWORDs.

```systemverilog
initial begin : receive_rtrgt_packets
  native_bfm.trgt_packet_t rx_packet;

  native_bfm.start();
  native_bfm.wait_reset_release();

  forever begin
    native_bfm.get_trgt_packet(rx_packet);

    $display("RTRGT: dw_len=%0d tlp_abort=%0b dllp_abort=%0b payload_valid=%0b",
             rx_packet.header.dw_len,
             rx_packet.tlp_abort,
             rx_packet.dllp_abort,
             rx_packet.payload_valid);

    for (int i = 0; i < rx_packet.payload_size; i++)
      $display("  payload[%0d] = %02x", i, rx_packet.payload[i]);
  end
end
```

The header is available in `rx_packet.header`. When `dllp_abort=1`, the EOT
cycle `dwen` is not consumed and `payload_valid=0`, because the Databook states
that `dwen` is unreliable for that cycle.

## RTRGT backpressure examples

Global halt is pipelined. Space must remain in the application receive buffer
for the output cycles already in flight:

```systemverilog
initial begin
  native_bfm.wait_reset_release();

  native_bfm.set_trgt_halt(1'b1);
  repeat (20) @(posedge core_clk);
  native_bfm.set_trgt_halt(1'b0);
end
```

Packet halt controls queue dequeue by traffic class. The mask is
`{CPL, NP, P}`; it is an early packet-level throttle rather than a per-beat
ready signal:

```systemverilog
initial begin
  native_bfm.wait_reset_release();

  native_bfm.set_trgt_packet_halt(3'b010); // halt NP only
  repeat (50) @(posedge core_clk);
  native_bfm.set_trgt_packet_halt(3'b000);
end
```

Randomized global backpressure is also available:

```systemverilog
initial begin
  native_bfm.wait_reset_release();
  native_bfm.random_trgt_backpressure(1000, 20); // 1000 cycles, 20% halt
end
```
