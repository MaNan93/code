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
    input logic [NL-1:0] mac_phy_rxeqeval,
    input logic [NL-1:0] mac_phy_rxeqinprogress,
    input logic [NL-1:0] mac_phy_invalid_req,
    input logic [NL-1:0] mac_phy_getlocal_pset_coef,
    input logic [NL*5-1:0] mac_phy_local_pset_index,
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
    // All state shared by the lanes is clocked by this side's selected PCLK.
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
        end else begin
            ready_meta <= clock_ready;
            ready_sync <= ready_meta;
            active_meta <= active_rate;
            active_sync <= active_meta;
            aligned_meta <= clocks_aligned;
            aligned_sync <= aligned_meta;
            reset_seen <= 1;
            powerdown_q <= mac_phy_powerdown;
            if (rate_complete) begin
                acknowledged_rate <= mac_phy_rate;
            end
            shared_delay <= (shared_delay << 1) | (!reset_seen || (mac_phy_powerdown != powerdown_q) || (rate_complete && acknowledged_rate != mac_phy_rate));
        end
    end
    assign phy_mac_pipe_config_status = '0;
    // Only lanes are replicated: clock selection and common acknowledgements are shared.
    for (genvar lane=0; lane<NL; lane=lane+1) begin : g_lane
    pcie_pipe_lane #(.ACK_CYCLES(ACK_CYCLES), .EQ_CYCLES(EQ_CYCLES)) u_lane (
        .pclk(pclk),
        .phy_rst_n(phy_rst_n),
        .mac_phy_rate(mac_phy_rate),
        .shared_status_due(shared_status_due),
        .data_enable(data_enable),
        .mac_phy_txdetectrx_loopback(mac_phy_txdetectrx_loopback[lane]),
        .mac_phy_rxstandby(mac_phy_rxstandby[lane]),
        .mac_phy_rxeqeval(mac_phy_rxeqeval[lane]),
        .mac_phy_rxeqinprogress(mac_phy_rxeqinprogress[lane]),
        .mac_phy_invalid_req(mac_phy_invalid_req[lane]),
        .mac_phy_getlocal_pset_coef(mac_phy_getlocal_pset_coef[lane]),
        .mac_phy_local_pset_index(mac_phy_local_pset_index[lane*5+:5]),
        .mac_phy_dirchange(mac_phy_dirchange[lane]),
        .mac_phy_txdeemph(mac_phy_txdeemph[lane*18+:18]),
        .phy_mac_rxelecidle(phy_mac_rxelecidle[lane]),
        .phy_mac_phystatus(phy_mac_phystatus[lane]),
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
