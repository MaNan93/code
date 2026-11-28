module pcie_pipe_status_lane #(
    parameter int ACK_CYCLES = 8,
    parameter int TXEI_WD    = 4
) (
    input  logic               pclk,
    input  logic               phy_rst_n,
    input  logic [2:0]         rate,
    input  logic [2:0]         active_rate,
    input  logic               clock_ready,
    input  logic [3:0]         powerdown,
    input  logic               asyncpowerchangeack,
    input  logic [TXEI_WD-1:0] txelecidle,
    input  logic               txdetectrx_loopback,
    input  logic               rxstandby,
    input  logic               peer_present,
    output logic               phystatus_ctrl,
    output logic [2:0]         rxstatus_ctrl,
    output logic               rxstandbystatus
);
    localparam int CNT_W = (ACK_CYCLES > 1) ? $clog2(ACK_CYCLES + 1) : 2;
    localparam logic [3:0] PD_P0 = 4'd0;
    localparam logic [3:0] PD_P1 = 4'd2;

    logic               reset_seen;
    logic [3:0]         prev_powerdown;
    logic [2:0]         prev_rate;
    logic               pd_pending;
    logic               rate_pending;
    logic               detect_pending;
    logic               txdetectrx_d;
    logic [CNT_W-1:0]   pd_cnt;
    logic [CNT_W-1:0]   rate_cnt;
    logic [CNT_W-1:0]   detect_cnt;
    logic               tx_all_idle;
    logic               unused_async_ack;

    assign tx_all_idle      = &txelecidle;
    assign unused_async_ack = asyncpowerchangeack;

    always_ff @(posedge pclk or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            reset_seen      <= 1'b0;
            prev_powerdown  <= PD_P1;
            prev_rate       <= 3'd0;
            pd_pending      <= 1'b0;
            rate_pending    <= 1'b0;
            detect_pending  <= 1'b0;
            txdetectrx_d    <= 1'b0;
            pd_cnt          <= '0;
            rate_cnt        <= '0;
            detect_cnt      <= '0;
            phystatus_ctrl  <= 1'b1;
            rxstatus_ctrl   <= 3'b000;
            rxstandbystatus <= 1'b0;
        end else begin
            phystatus_ctrl  <= 1'b0;
            rxstatus_ctrl   <= 3'b000;
            rxstandbystatus <= rxstandby;
            txdetectrx_d    <= txdetectrx_loopback;

            // Deassert reset-time phystatus cleanly on the first valid clock after reset release.
            if (!reset_seen) begin
                reset_seen     <= 1'b1;
                prev_powerdown <= powerdown;
                prev_rate      <= rate;
            end else begin
                if (powerdown != prev_powerdown) begin
                    prev_powerdown <= powerdown;
                    pd_pending     <= 1'b1;
                    pd_cnt         <= (ACK_CYCLES > 1) ? CNT_W'(ACK_CYCLES - 1) : '0;
                end else if (pd_pending) begin
                    if (pd_cnt == '0) begin
                        pd_pending     <= 1'b0;
                        phystatus_ctrl <= 1'b1;
                    end else begin
                        pd_cnt <= pd_cnt - CNT_W'(1);
                    end
                end

                if (rate != prev_rate) begin
                    prev_rate    <= rate;
                    rate_pending <= 1'b1;
                    rate_cnt     <= (ACK_CYCLES > 1) ? CNT_W'(ACK_CYCLES - 1) : '0;
                end else if (rate_pending) begin
                    if (clock_ready && (active_rate == rate)) begin
                        if (rate_cnt == '0) begin
                            rate_pending   <= 1'b0;
                            phystatus_ctrl <= 1'b1;
                        end else begin
                            rate_cnt <= rate_cnt - CNT_W'(1);
                        end
                    end
                end

                if (txdetectrx_loopback && !txdetectrx_d && (powerdown == PD_P1) && tx_all_idle) begin
                    detect_pending <= 1'b1;
                    detect_cnt     <= (ACK_CYCLES > 1) ? CNT_W'(ACK_CYCLES - 1) : '0;
                end else if (detect_pending) begin
                    if (!txdetectrx_loopback) begin
                        detect_pending <= 1'b0;
                    end else if (detect_cnt == '0) begin
                        detect_pending <= 1'b0;
                        phystatus_ctrl <= 1'b1;
                        rxstatus_ctrl  <= peer_present ? 3'b011 : 3'b000;
                    end else begin
                        detect_cnt <= detect_cnt - CNT_W'(1);
                    end
                end

                // Unused check clarity
                if (powerdown == PD_P0) begin
                    detect_pending <= 1'b0;
                end
            end
        end
    end
endmodule
