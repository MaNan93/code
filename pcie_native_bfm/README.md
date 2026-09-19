# DWC PCIe Traditional Native Interface BFM

Common, mode-independent transport BFM for the Synopsys DWC PCIe Controller
6.60a traditional XALI/RTRGT interface. It intentionally contains no
SystemVerilog class.

## Scope

- Drives one XALI client with correct `hv/dv/eot/halt` behavior.
- Receives and reconstructs one RTRGT stream; `dv` gaps are legal.
- Supports header-only and payload-bearing TLPs.
- Models RTRGT global-halt propagation with a configurable pipeline latency.
- Supports P/NP/CPL packet halt (`[0]`, `[1]`, `[2]`).
- Checks basic transfer framing, payload length, abort timing, queue overflow,
  and XALI stability while halted.

It does not yet check RP/EP/DM/SW-specific legal TLP types, routing, requester
tracking, Completion matching, or Switch port pairing.

## Integration

The generated controller configuration determines the exact split header
signals. This BFM therefore exposes opaque packed `client_tlp_hdr` and
`radm_trgt_hdr` buses. A thin testbench wrapper should map the generated DWC
header fields to these buses consistently.

```systemverilog
dwc_pcie_native_common_bfm #(
  .DATA_WIDTH               (256),
  .XALI_HDR_WIDTH           (256),
  .TRGT_HDR_WIDTH           (256),
  .TRGT_HALT_LATENCY_CYCLES (4)
) native_bfm (
  .core_clk   (core_clk),
  .core_rst_n (core_rst_n)
);

initial begin
  byte unsigned payload[];
  native_bfm.start();
  native_bfm.wait_reset_release();

  payload = new[64];
  foreach (payload[i]) payload[i] = i;
  native_bfm.send_xali(xali_header, payload, 4'hf, 4'hf, 1'b0);
end
```

For a header-only read, pass the requested byte count through the final
`tlp_byte_len` argument; `dv` remains low even though `byte_len` is non-zero:

```systemverilog
payload = new[0];
native_bfm.send_xali(mrd_header, payload, 4'hf, 4'hf, 1'b0, 512);
```

`TRGT_HALT_LATENCY_CYCLES` must match the instantiated controller. RTRGT halt
is not an AXI-style ready signal: output can continue for the configured number
of pipeline cycles after `trgt_radm_halt` is asserted.

`client_tlp_byte_en[7:0]` carries `{last_dw_be, first_dw_be}` and is not a
payload byte-valid mask. `radm_trgt_dwen` is one enable bit per DWORD.
