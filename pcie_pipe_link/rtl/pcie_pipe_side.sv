module pcie_pipe_side #(
    parameter integer NL = 4,
    parameter integer ACK_CYCLES = 8,
    parameter integer EQ_CYCLES = 8
)(
    input logic pclk_62p5,
    input logic pclk_125,
    input logic pclk_250,
    input logic pclk_500,
    input logic pclk_1000,
    input logic clocks_aligned,
    output logic pclk,
    output logic [2:0] active_rate,
    output logic clock_ready,
    output logic phy_ref_clk_req_n,
    input logic [NL-1:0] mac_phy_rxeqeval,
    input logic [NL-1:0] mac_phy_rxeqinprogress,
    input logic [NL-1:0] mac_phy_invalid_req,
    input logic [NL-1:0] mac_phy_getlocal_pset_coef,
    input logic [NL*6-1:0] mac_phy_local_pset_index,
    input logic [NL-1:0] mac_phy_dirchange,
    input logic [NL*18-1:0] mac_phy_txdeemph,
    input logic phy_rst_n,
    input logic [NL*32-1:0] mac_phy_txdata,
    input logic [NL*4-1:0] mac_phy_txdatak,
    input logic [NL-1:0] mac_phy_txelecidle,
    input logic [NL-1:0] mac_phy_txdatavalid,
    input logic [NL-1:0] mac_phy_txstartblock,
    input logic [NL*2-1:0] mac_phy_txsyncheader,
    input logic [NL-1:0] mac_phy_rxstandby,
    input logic [NL-1:0] mac_phy_txdetectrx_loopback,
    input logic [3:0] mac_phy_powerdown,
    input logic mac_phy_asyncpowerchangeack,
    input logic [2:0] mac_phy_rate,
    output logic [NL-1:0] phy_mac_rxelecidle,
    output logic [NL-1:0] phy_mac_phystatus,
    output logic [NL*32-1:0] phy_mac_rxdata,
    output logic [NL*4-1:0] phy_mac_rxdatak,
    output logic [NL-1:0] phy_mac_rxvalid,
    output logic [NL*3-1:0] phy_mac_rxstatus,
    output logic [NL-1:0] phy_mac_rxstandbystatus,
    output logic [NL-1:0] phy_mac_rxdatavalid,
    output logic [NL-1:0] phy_mac_rxstartblock,
    output logic [NL*2-1:0] phy_mac_rxsyncheader,
    output logic [NL*6-1:0] phy_mac_localfs,
    output logic [NL*6-1:0] phy_mac_locallf,
    output logic [NL*6-1:0] phy_mac_dirfeedback,
    output logic [NL*8-1:0] phy_mac_fomfeedback,
    output logic [NL*18-1:0] phy_mac_local_tx_pset_coef,
    output logic [NL-1:0] phy_mac_local_tx_coef_valid,
    output logic [NL*8-1:0] phy_mac_messagebus,
    output logic [31:0] phy_mac_pipe_config_status,
    input logic [NL*32-1:0] peer_mac_phy_txdata,
    input logic [NL*4-1:0] peer_mac_phy_txdatak,
    input logic [NL-1:0] peer_mac_phy_txelecidle,
    input logic [NL-1:0] peer_mac_phy_txdatavalid,
    input logic [NL-1:0] peer_mac_phy_txstartblock,
    input logic [NL*2-1:0] peer_mac_phy_txsyncheader
);
    logic ready_meta, ready_sync;
    logic [2:0] active_meta, active_sync, acknowledged_rate;
    logic aligned_meta, aligned_sync;
    logic reset_seen;
    logic [3:0] powerdown_q;
    logic [ACK_CYCLES-1:0] shared_delay;
    logic shared_status_due, data_enable, rate_complete;
    logic [NL-1:0] lane_phystatus;
    logic [NL-1:0] shared_ack, cpm_ack_seen;
    logic [ACK_CYCLES-1:0] cpm_delay;
    logic cpm_armed;
    logic [3:0] power_meta, power_sync, lowpower_value;
    logic async_ack_meta, async_ack_sync;
    localparam integer LP_COUNT_W = (ACK_CYCLES > 1) ? $clog2(ACK_CYCLES) : 1;
    localparam [2:0] LP_IDLE = 0, LP_WAIT = 1, LP_STATUS = 2, LP_ACK_LOW = 3, LP_DONE = 4;
    logic [2:0] lowpower_state;
    logic [LP_COUNT_W-1:0] lowpower_count;
    logic lowpower_requested;
    logic clock_released;
    logic cpm_entry_toggle;
    logic cpm_entry_meta, cpm_entry_sync, cpm_entry_seen;
    logic cpm_entry_due;
    assign cpm_entry_due = cpm_entry_sync != cpm_entry_seen && mac_phy_powerdown == 4'd4;
    assign lowpower_requested = mac_phy_powerdown == 4'd5 || mac_phy_powerdown == 4'd6;
    // Low-power handshake uses the always-on 62.5 MHz clock.
    always @(posedge pclk_62p5 or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            power_meta <= 0;
            power_sync <= 0;
            lowpower_value <= 0;
            async_ack_meta <= 0;
            async_ack_sync <= 0;
            lowpower_state <= LP_IDLE;
            lowpower_count <= 0;
            clock_released <= 0;
            cpm_entry_toggle <= 0;
        end else begin
            power_meta <= mac_phy_powerdown;
            power_sync <= power_meta;
            async_ack_meta <= mac_phy_asyncpowerchangeack;
            async_ack_sync <= async_ack_meta;
            if (mac_phy_powerdown < 4'd4 || mac_phy_powerdown > 4'd6) begin
                clock_released <= 0;
            end else if ((&cpm_ack_seen) ||
                         (lowpower_state == LP_ACK_LOW && !async_ack_sync)) begin
                clock_released <= 1;
            end
            if (power_sync != lowpower_value) begin
                lowpower_value <= power_sync;
                if (power_sync == 4'd4) begin
                    cpm_entry_toggle <= ~cpm_entry_toggle;
                end
                lowpower_count <= LP_COUNT_W'(ACK_CYCLES-1);
                lowpower_state <= (power_sync == 4'd5 || power_sync == 4'd6) ? LP_WAIT : LP_IDLE;
            end else begin
                case (lowpower_state)
                    LP_WAIT: if (lowpower_count == 0 && !async_ack_sync) begin
                        lowpower_state <= LP_STATUS;
                    end else if (lowpower_count != 0) begin
                        lowpower_count <= lowpower_count - 1'b1;
                    end
                    LP_STATUS: if (async_ack_sync) begin
                        lowpower_state <= LP_ACK_LOW;
                    end
                    LP_ACK_LOW: if (!async_ack_sync) begin
                        lowpower_state <= LP_DONE;
                    end
                    default: begin end
                endcase
            end
        end
    end
    assign phy_mac_phystatus = lowpower_requested ?
        {NL{phy_rst_n && mac_phy_powerdown == lowpower_value && lowpower_state == LP_STATUS}} :
        lane_phystatus;
    // Request the clock on wake, even with PCLK stopped.
    assign phy_ref_clk_req_n = phy_rst_n &&
        mac_phy_powerdown >= 4'd4 && mac_phy_powerdown <= 4'd6 &&
        ((&cpm_ack_seen) || clock_released);
    assign rate_complete = ready_sync && active_sync == mac_phy_rate;
    assign shared_status_due = shared_delay[ACK_CYCLES-1];
    assign data_enable = aligned_sync && clocks_aligned;
    pcie_pipe_pclk_switch u_clock_switch (
        .pclk_62p5(pclk_62p5),
        .pclk_125(pclk_125),
        .pclk_250(pclk_250),
        .pclk_500(pclk_500),
        .pclk_1000(pclk_1000),
        .phy_rst_n(phy_rst_n),
        .rate_request(mac_phy_rate),
        .pclk(pclk),
        .active_rate(active_rate),
        .clock_ready(clock_ready)
    );
    // Shared acknowledgements use local PCLK.
    always @(posedge pclk or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            ready_meta <= 0;
            ready_sync <= 0;
            active_meta <= 0;
            active_sync <= 0;
            acknowledged_rate <= 0;
            aligned_meta <= 0;
            aligned_sync <= 0;
            reset_seen <= 0;
            powerdown_q <= 0;
            shared_delay <= 0;
            cpm_delay <= '0;
            cpm_armed <= 0;
            cpm_ack_seen <= '0;
            cpm_entry_meta <= 0;
            cpm_entry_sync <= 0;
            cpm_entry_seen <= 0;
        end else begin
            ready_meta <= clock_ready;
            ready_sync <= ready_meta;
            active_meta <= active_rate;
            active_sync <= active_meta;
            aligned_meta <= clocks_aligned;
            aligned_sync <= aligned_meta;
            reset_seen <= 1;
            powerdown_q <= mac_phy_powerdown;
            cpm_entry_meta <= cpm_entry_toggle;
            cpm_entry_sync <= cpm_entry_meta;
            cpm_entry_seen <= cpm_entry_sync;
            cpm_delay <= (cpm_delay << 1) | cpm_entry_due;
            if (mac_phy_powerdown < 4'd4 || mac_phy_powerdown > 4'd6) begin
                cpm_armed <= 0;
                cpm_ack_seen <= '0;
            end else if (mac_phy_powerdown != 4'd4) begin
                cpm_armed <= 0;
            end else if (cpm_entry_due) begin
                cpm_armed <= 0;
                cpm_ack_seen <= '0;
            end else begin
                if (cpm_delay[ACK_CYCLES-1]) begin
                    cpm_armed <= 1;
                end
                if (cpm_armed) begin
                    cpm_ack_seen <= cpm_ack_seen | shared_ack;
                end
            end
            if (rate_complete) begin
                acknowledged_rate <= mac_phy_rate;
            end
            shared_delay <= (shared_delay << 1) | (!reset_seen ||
                (mac_phy_powerdown != powerdown_q && mac_phy_powerdown != 4'd4) ||
                cpm_entry_due || (rate_complete && acknowledged_rate != mac_phy_rate));
        end
    end
    assign phy_mac_pipe_config_status = '0;
    // Per-lane logic.
    for (genvar lane=0; lane<NL; lane=lane+1) begin : g_lane
    pcie_pipe_lane #(
        .ACK_CYCLES(ACK_CYCLES),
        .EQ_CYCLES(EQ_CYCLES)
    ) u_lane (
        .pclk(pclk),
        .phy_rst_n(phy_rst_n),
        .mac_phy_rate(mac_phy_rate),
        .shared_status_due(shared_status_due),
        .shared_ack(shared_ack[lane]),
        .data_enable(data_enable),
        .mac_phy_txdetectrx_loopback(mac_phy_txdetectrx_loopback[lane]),
        .mac_phy_rxstandby(mac_phy_rxstandby[lane]),
        .mac_phy_rxeqeval(mac_phy_rxeqeval[lane]),
        .mac_phy_rxeqinprogress(mac_phy_rxeqinprogress[lane]),
        .mac_phy_invalid_req(mac_phy_invalid_req[lane]),
        .mac_phy_getlocal_pset_coef(mac_phy_getlocal_pset_coef[lane]),
        .mac_phy_local_pset_index(mac_phy_local_pset_index[lane*6+:6]),
        .mac_phy_dirchange(mac_phy_dirchange[lane]),
        .mac_phy_txdeemph(mac_phy_txdeemph[lane*18+:18]),
        .phy_mac_rxelecidle(phy_mac_rxelecidle[lane]),
        .phy_mac_phystatus(lane_phystatus[lane]),
        .phy_mac_rxdata(phy_mac_rxdata[lane*32+:32]),
        .phy_mac_rxdatak(phy_mac_rxdatak[lane*4+:4]),
        .phy_mac_rxvalid(phy_mac_rxvalid[lane]),
        .phy_mac_rxstatus(phy_mac_rxstatus[lane*3+:3]),
        .phy_mac_rxstandbystatus(phy_mac_rxstandbystatus[lane]),
        .phy_mac_rxdatavalid(phy_mac_rxdatavalid[lane]),
        .phy_mac_rxstartblock(phy_mac_rxstartblock[lane]),
        .phy_mac_rxsyncheader(phy_mac_rxsyncheader[lane*2+:2]),
        .phy_mac_localfs(phy_mac_localfs[lane*6+:6]),
        .phy_mac_locallf(phy_mac_locallf[lane*6+:6]),
        .phy_mac_dirfeedback(phy_mac_dirfeedback[lane*6+:6]),
        .phy_mac_fomfeedback(phy_mac_fomfeedback[lane*8+:8]),
        .phy_mac_local_tx_pset_coef(phy_mac_local_tx_pset_coef[lane*18+:18]),
        .phy_mac_local_tx_coef_valid(phy_mac_local_tx_coef_valid[lane]),
        .phy_mac_messagebus(phy_mac_messagebus[lane*8+:8]),
        .peer_mac_phy_txdata(peer_mac_phy_txdata[lane*32+:32]),
        .peer_mac_phy_txdatak(peer_mac_phy_txdatak[lane*4+:4]),
        .peer_mac_phy_txelecidle(peer_mac_phy_txelecidle[lane]),
        .peer_mac_phy_txdatavalid(peer_mac_phy_txdatavalid[lane]),
        .peer_mac_phy_txstartblock(peer_mac_phy_txstartblock[lane]),
        .peer_mac_phy_txsyncheader(peer_mac_phy_txsyncheader[lane*2+:2])
    );
    end

endmodule
