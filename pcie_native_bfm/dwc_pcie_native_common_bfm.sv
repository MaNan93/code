`timescale 1ns/1ps

// DWC PCIe 6.60a traditional Native interface common BFM.
// Application-side BFM: drives one XALI client and receives one RTRGT port.
// No SystemVerilog class is used. Mode-specific TLP legality/routing is outside
// this common transport layer.
interface dwc_pcie_native_common_bfm #(
  parameter int DATA_WIDTH               = 256,
  parameter int XALI_HDR_WIDTH           = 256,
  parameter int TRGT_HDR_WIDTH           = 256,
  parameter int MAX_PAYLOAD_BYTES        = 4096,
  parameter int XALI_HALT_TIMEOUT_CYCLES = 10000,
  // Match this to the generated controller's RTRGT halt pipeline.
  parameter int TRGT_HALT_LATENCY_CYCLES = 4,
  parameter int RX_QUEUE_DEPTH           = 64
) (
  input logic core_clk,
  input logic core_rst_n
);

  localparam int BYTE_LANES  = DATA_WIDTH / 8;
  localparam int DWORD_LANES = DATA_WIDTH / 32;

  // XALI: application -> controller
  logic [XALI_HDR_WIDTH-1:0] client_tlp_hdr;
  logic [DATA_WIDTH-1:0]     client_tlp_data;
  logic [7:0]                client_tlp_byte_en;  // {LBE[3:0], FBE[3:0]}
  logic [12:0]               client_tlp_byte_len;
  logic                      client_tlp_hv;
  logic                      client_tlp_dv;
  logic                      client_tlp_eot;
  logic                      client_tlp_bad_eot;
  logic                      xadm_client_halt;

  // RTRGT: controller -> application
  logic [TRGT_HDR_WIDTH-1:0] radm_trgt_hdr;
  logic [DATA_WIDTH-1:0]     radm_trgt_data;
  logic [DWORD_LANES-1:0]    radm_trgt_dwen;
  logic [12:0]               radm_trgt_byte_len;
  logic                      radm_trgt_hv;
  logic                      radm_trgt_dv;
  logic                      radm_trgt_eot;
  logic                      radm_trgt_tlp_abort;
  logic                      radm_trgt_dllp_abort;
  logic                      trgt_radm_halt;
  logic [2:0]                trgt_radm_pkt_halt; // [0] P, [1] NP, [2] CPL
  logic [2:0]                radm_grant_tlp_type;

  typedef struct {
    logic [XALI_HDR_WIDTH-1:0] hdr;
    logic [7:0]                 byte_en;
    logic [12:0]                byte_len;
    bit                         bad_eot;
    byte unsigned               payload [MAX_PAYLOAD_BYTES];
  } xali_packet_t;

  typedef struct {
    logic [TRGT_HDR_WIDTH-1:0] hdr;
    logic [12:0]               byte_len;
    bit                        tlp_abort;
    bit                        dllp_abort;
    byte unsigned              payload [MAX_PAYLOAD_BYTES];
  } trgt_packet_t;

  xali_packet_t xali_rx_queue[$];
  trgt_packet_t trgt_rx_queue[$];

  int unsigned error_count;
  int unsigned xali_packet_count;
  int unsigned trgt_packet_count;
  bit checker_enable;
  bit monitors_started;

  function automatic void protocol_error(input string text);
    error_count++;
    $error("DWC_PCIE_NATIVE_BFM: %s", text);
  endfunction

  function automatic logic [7:0] make_byte_en(
    input logic [3:0] first_dw_be,
    input logic [3:0] last_dw_be
  );
    return {last_dw_be, first_dw_be};
  endfunction

  task automatic drive_xali_idle();
    client_tlp_hdr      <= '0;
    client_tlp_data     <= '0;
    client_tlp_byte_en  <= '0;
    client_tlp_byte_len <= '0;
    client_tlp_hv       <= 1'b0;
    client_tlp_dv       <= 1'b0;
    client_tlp_eot      <= 1'b0;
    client_tlp_bad_eot  <= 1'b0;
  endtask

  task automatic init();
    drive_xali_idle();
    trgt_radm_halt     <= 1'b0;
    trgt_radm_pkt_halt <= '0;
    xali_rx_queue.delete();
    trgt_rx_queue.delete();
    error_count       = 0;
    xali_packet_count = 0;
    trgt_packet_count = 0;
    checker_enable    = 1'b1;
  endtask

  task automatic wait_reset_release();
    while (core_rst_n !== 1'b1) @(posedge core_clk);
  endtask

  // Sends a header-only or payload-bearing TLP. For a payload TLP, HV and DV
  // are asserted together on its first beat. A halted beat remains unchanged.
  task automatic send_xali(
    input logic [XALI_HDR_WIDTH-1:0] hdr,
    input byte unsigned payload[],
    input logic [3:0] first_dw_be = 4'hf,
    input logic [3:0] last_dw_be  = 4'hf,
    input bit bad_eot             = 1'b0,
    // Required for header-only reads; zero means infer from payload size.
    input int unsigned tlp_byte_len = 0
  );
    int offset;
    int lane;
    int valid_bytes;
    int wait_cycles;
    logic [DATA_WIDTH-1:0] beat;

    if (core_rst_n !== 1'b1) wait_reset_release();
    if (payload.size() > MAX_PAYLOAD_BYTES)
      $fatal(1, "XALI payload size %0d exceeds %0d",
             payload.size(), MAX_PAYLOAD_BYTES);

    if (payload.size() == 0) begin
      @(negedge core_clk);
      client_tlp_hdr      <= hdr;
      client_tlp_byte_en  <= make_byte_en(first_dw_be, last_dw_be);
      client_tlp_byte_len <= tlp_byte_len[12:0];
      client_tlp_hv       <= 1'b1;
      client_tlp_dv       <= 1'b0;
      client_tlp_eot      <= 1'b1;
      client_tlp_bad_eot  <= bad_eot;
      wait_cycles = 0;
      do begin
        @(posedge core_clk);
        wait_cycles++;
        if (wait_cycles > XALI_HALT_TIMEOUT_CYCLES)
          $fatal(1, "XALI header-only TLP timed out under halt");
      end while (xadm_client_halt !== 1'b0);
      @(negedge core_clk);
      drive_xali_idle();
      return;
    end

    offset = 0;
    while (offset < payload.size()) begin
      beat = '0;
      valid_bytes = payload.size() - offset;
      if (valid_bytes > BYTE_LANES) valid_bytes = BYTE_LANES;
      for (lane = 0; lane < valid_bytes; lane++)
        beat[lane*8 +: 8] = payload[offset+lane];

      @(negedge core_clk);
      client_tlp_hdr      <= hdr;
      client_tlp_data     <= beat;
      client_tlp_byte_en  <= make_byte_en(first_dw_be, last_dw_be);
      client_tlp_byte_len <= (tlp_byte_len == 0) ?
                             payload.size() : tlp_byte_len[12:0];
      client_tlp_hv       <= (offset == 0);
      client_tlp_dv       <= 1'b1;
      client_tlp_eot      <= (offset + valid_bytes == payload.size());
      client_tlp_bad_eot  <= bad_eot &&
                             (offset + valid_bytes == payload.size());

      wait_cycles = 0;
      do begin
        @(posedge core_clk);
        wait_cycles++;
        if (wait_cycles > XALI_HALT_TIMEOUT_CYCLES)
          $fatal(1, "XALI payload TLP timed out at byte %0d", offset);
      end while (xadm_client_halt !== 1'b0);
      offset += valid_bytes;
    end

    @(negedge core_clk);
    drive_xali_idle();
  endtask

  task automatic set_trgt_halt(input bit halt);
    @(negedge core_clk);
    trgt_radm_halt <= halt;
  endtask

  task automatic set_trgt_packet_halt(input logic [2:0] halt_mask);
    @(negedge core_clk);
    trgt_radm_pkt_halt <= halt_mask;
  endtask

  task automatic random_trgt_backpressure(
    input int unsigned cycles,
    input int unsigned halt_percent = 20
  );
    if (halt_percent > 100) $fatal(1, "halt_percent must be <= 100");
    repeat (cycles) begin
      @(negedge core_clk);
      trgt_radm_halt <= ($urandom_range(99, 0) < halt_percent);
    end
    @(negedge core_clk);
    trgt_radm_halt <= 1'b0;
  endtask

  task automatic get_xali_packet(output xali_packet_t packet);
    wait (xali_rx_queue.size() != 0);
    packet = xali_rx_queue.pop_front();
  endtask

  task automatic get_trgt_packet(output trgt_packet_t packet);
    wait (trgt_rx_queue.size() != 0);
    packet = trgt_rx_queue.pop_front();
  endtask

  task automatic run_xali_monitor();
    xali_packet_t packet;
    bit in_packet;
    int payload_count;
    int lane;
    int valid_bytes;
    bit saw_dv;

    in_packet = 0;
    payload_count = 0;
    saw_dv = 0;
    forever begin
      @(posedge core_clk);
      if (!core_rst_n) begin
        in_packet = 0;
        payload_count = 0;
        saw_dv = 0;
      end else if (!xadm_client_halt) begin
        if (client_tlp_hv) begin
          if (checker_enable && in_packet)
            protocol_error("XALI HV before the preceding EOT");
          packet.hdr      = client_tlp_hdr;
          packet.byte_en  = client_tlp_byte_en;
          packet.byte_len = client_tlp_byte_len;
          packet.bad_eot  = 1'b0;
          payload_count   = 0;
          in_packet       = 1'b1;
        end

        if (checker_enable && client_tlp_dv && !in_packet)
          protocol_error("XALI DV observed outside a TLP");

        if (client_tlp_dv && in_packet) begin
          saw_dv = 1;
          valid_bytes = packet.byte_len - payload_count;
          if (valid_bytes > BYTE_LANES) valid_bytes = BYTE_LANES;
          if (valid_bytes < 0) valid_bytes = 0;
          for (lane = 0; lane < valid_bytes; lane++) begin
            if (payload_count < MAX_PAYLOAD_BYTES)
              packet.payload[payload_count] = client_tlp_data[lane*8 +: 8];
            payload_count++;
          end
        end

        if (checker_enable && client_tlp_eot &&
            !(client_tlp_hv || client_tlp_dv))
          protocol_error("XALI EOT without HV or DV");
        if (checker_enable && client_tlp_bad_eot && !client_tlp_eot)
          protocol_error("XALI bad_eot outside the EOT cycle");

        if (client_tlp_eot && (client_tlp_hv || client_tlp_dv)) begin
          packet.bad_eot = client_tlp_bad_eot;
          if (checker_enable && saw_dv && payload_count != packet.byte_len)
            protocol_error($sformatf("XALI payload length %0d, expected %0d",
                                    payload_count, packet.byte_len));
          if (xali_rx_queue.size() >= RX_QUEUE_DEPTH)
            protocol_error("XALI monitor queue overflow");
          else
            xali_rx_queue.push_back(packet);
          xali_packet_count++;
          in_packet = 0;
        end
      end
    end
  endtask

  // RTRGT halt is pipelined, not a ready/valid handshake. After halt rises,
  // the receiver continues accepting TRGT_HALT_LATENCY_CYCLES output cycles,
  // then treats the controller output as held until halt falls.
  task automatic run_trgt_monitor();
    trgt_packet_t packet;
    bit in_packet;
    bit previous_halt;
    int halt_cycles_left;
    int payload_count;
    int lane;
    int byte_lane;
    bit accept_cycle;
    bit saw_dv;

    in_packet = 0;
    previous_halt = 0;
    halt_cycles_left = 0;
    payload_count = 0;
    saw_dv = 0;
    forever begin
      @(posedge core_clk);
      if (!core_rst_n) begin
        in_packet = 0;
        previous_halt = 0;
        halt_cycles_left = 0;
        payload_count = 0;
        saw_dv = 0;
      end else begin
        if (trgt_radm_halt && !previous_halt)
          halt_cycles_left = TRGT_HALT_LATENCY_CYCLES;

        accept_cycle = !trgt_radm_halt || (halt_cycles_left > 0);
        if (trgt_radm_halt && halt_cycles_left > 0)
          halt_cycles_left--;
        previous_halt = trgt_radm_halt;

        if (accept_cycle) begin
          if (radm_trgt_hv) begin
            if (checker_enable && in_packet)
              protocol_error("RTRGT HV before the preceding EOT");
            packet.hdr        = radm_trgt_hdr;
            packet.byte_len   = radm_trgt_byte_len;
            packet.tlp_abort  = 1'b0;
            packet.dllp_abort = 1'b0;
            payload_count     = 0;
            saw_dv            = 0;
            in_packet         = 1'b1;
          end

          if (checker_enable && radm_trgt_dv && !in_packet)
            protocol_error("RTRGT DV observed outside a TLP");

          if (radm_trgt_dv && in_packet) begin
            saw_dv = 1;
            for (lane = 0; lane < DWORD_LANES; lane++) begin
              if (radm_trgt_dwen[lane]) begin
                for (byte_lane = 0; byte_lane < 4; byte_lane++) begin
                  if (payload_count < MAX_PAYLOAD_BYTES &&
                      payload_count < packet.byte_len)
                    packet.payload[payload_count] =
                      radm_trgt_data[lane*32 + byte_lane*8 +: 8];
                  payload_count++;
                end
              end
            end
          end

          if (checker_enable && radm_trgt_eot &&
              !(radm_trgt_hv || radm_trgt_dv))
            protocol_error("RTRGT EOT without HV or DV");
          if (checker_enable &&
              (radm_trgt_tlp_abort || radm_trgt_dllp_abort) &&
              !radm_trgt_eot)
            protocol_error("RTRGT abort indication outside EOT cycle");

          if (radm_trgt_eot && (radm_trgt_hv || radm_trgt_dv)) begin
            packet.tlp_abort  = radm_trgt_tlp_abort;
            packet.dllp_abort = radm_trgt_dllp_abort;
            if (checker_enable && saw_dv &&
                payload_count < packet.byte_len &&
                !(packet.tlp_abort || packet.dllp_abort))
              protocol_error($sformatf("RTRGT payload length %0d, expected %0d",
                                      payload_count, packet.byte_len));
            if (trgt_rx_queue.size() >= RX_QUEUE_DEPTH)
              protocol_error("RTRGT monitor queue overflow");
            else
              trgt_rx_queue.push_back(packet);
            trgt_packet_count++;
            in_packet = 0;
          end
        end
      end
    end
  endtask

  // Checks application-side XALI hold behavior without relying on SVA support.
  task automatic run_xali_halt_checker();
    logic [XALI_HDR_WIDTH+DATA_WIDTH+8+13+4-1:0] previous_signals;
    logic [XALI_HDR_WIDTH+DATA_WIDTH+8+13+4-1:0] current_signals;
    bit previous_halted_valid;
    previous_halted_valid = 0;
    forever begin
      @(posedge core_clk);
      current_signals = {client_tlp_hdr, client_tlp_data,
                         client_tlp_byte_en, client_tlp_byte_len,
                         client_tlp_hv, client_tlp_dv,
                         client_tlp_eot, client_tlp_bad_eot};
      if (!core_rst_n) begin
        previous_halted_valid = 0;
      end else begin
        if (checker_enable && previous_halted_valid && xadm_client_halt &&
            current_signals !== previous_signals)
          protocol_error("XALI signals changed while halted");
        previous_halted_valid = xadm_client_halt &&
                                (client_tlp_hv || client_tlp_dv);
        previous_signals = current_signals;
      end
    end
  endtask

  task automatic start();
    if (!monitors_started) begin
      monitors_started = 1'b1;
      fork
        run_xali_monitor();
        run_trgt_monitor();
        run_xali_halt_checker();
      join_none
    end
  endtask

  initial begin
    if (DATA_WIDTH <= 0 || DATA_WIDTH % 32 != 0)
      $fatal(1, "DATA_WIDTH must be a positive multiple of 32");
    if (MAX_PAYLOAD_BYTES <= 0)
      $fatal(1, "MAX_PAYLOAD_BYTES must be positive");
    if (TRGT_HALT_LATENCY_CYCLES < 0)
      $fatal(1, "TRGT_HALT_LATENCY_CYCLES must not be negative");
    monitors_started = 1'b0;
    init();
  end

  modport dut (
    input  client_tlp_hdr, client_tlp_data, client_tlp_byte_en,
           client_tlp_byte_len, client_tlp_hv, client_tlp_dv,
           client_tlp_eot, client_tlp_bad_eot,
           trgt_radm_halt, trgt_radm_pkt_halt,
    output xadm_client_halt,
           radm_trgt_hdr, radm_trgt_data, radm_trgt_dwen,
           radm_trgt_byte_len, radm_trgt_hv, radm_trgt_dv,
           radm_trgt_eot, radm_trgt_tlp_abort, radm_trgt_dllp_abort,
           radm_grant_tlp_type
  );

endinterface
