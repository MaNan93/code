//======================================================================
// dwc_bfm_util.svh -- helpers shared by the XALI and TRGT1 monitors.
//======================================================================
class dwc_bfm_util;

  // Lowest / highest set bit of a 4-bit byte-enable nibble.
  static function int lsb4(bit [3:0] v);
    for (int i = 0; i < 4; i++) if (v[i]) return i;
    return -1;
  endfunction

  static function int msb4(bit [3:0] v);
    for (int i = 3; i >= 0; i--) if (v[i]) return i;
    return -1;
  endfunction

  //--------------------------------------------------------------------
  // Turn the raw bytes seen on the data bus back into "payload starting
  // at the first enabled byte", plus the true byte address / byte length.
  //
  //   align_en = 1 : the bus already starts at the first enabled byte and
  //                  wire_len is the true length          (Databook 4.1.3.2)
  //   align_en = 0 : the bus is DWORD framed; FBE/LBE tell us where the
  //                  real bytes are                       (Databook 4.1.3.1)
  //--------------------------------------------------------------------
  static function void unpack_payload(
      input  byte unsigned s[$],
      input  bit           align_en,
      input  bit [63:0]    wire_addr,
      input  bit [12:0]    wire_len,
      input  bit [7:0]     byte_en,
      output byte unsigned payload[$],
      output bit [63:0]    true_addr,
      output bit [12:0]    true_len);

    int f;
    int l;
    int unsigned ndw;
    int unsigned start_i;
    int unsigned end_i;

    payload.delete();

    if (align_en) begin
      true_addr = wire_addr;
      true_len  = wire_len;
      for (int unsigned i = 0; i < wire_len && i < s.size(); i++)
        payload.push_back(s[i]);
      return;
    end

    f   = lsb4(byte_en[3:0]);
    ndw = wire_len / 4;

    if (f < 0 || ndw == 0) begin          // no enabled bytes (e.g. Msg)
      true_addr = wire_addr;
      true_len  = 13'd0;
      return;
    end

    if (ndw == 1) begin
      l     = msb4(byte_en[3:0]);
      end_i = l;
    end
    else begin
      l = msb4(byte_en[7:4]);
      if (l < 0) l = 3;                   // defensive: LBE must be non-zero
      end_i = (ndw - 1) * 4 + l;
    end

    start_i   = f;
    true_addr = wire_addr + f;
    true_len  = 13'(end_i - start_i + 1);
    for (int unsigned i = start_i; i <= end_i && i < s.size(); i++)
      payload.push_back(s[i]);
  endfunction

  // Split one data-bus beat into bytes, little-endian (byte k -> [8k+7:8k]).
  static function void beat_to_bytes(input bit [DW-1:0] d,
                                     ref byte unsigned s[$]);
    for (int unsigned k = 0; k < NBYTES; k++)
      s.push_back(d[8*k +: 8]);
  endfunction

  // Same, but honouring radm_trgt1_dwen on the final beat.
  static function void beat_to_bytes_dwen(input bit [DW-1:0] d,
                                          input bit [NDW-1:0] dwen,
                                          ref byte unsigned s[$]);
    for (int unsigned w = 0; w < NDW; w++)
      if (dwen[w])
        for (int unsigned k = 0; k < 4; k++)
          s.push_back(d[32*w + 8*k +: 8]);
  endfunction

endclass : dwc_bfm_util
