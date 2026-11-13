module pcie_pipe_pclk_switch(
    input logic pclk_62p5,
    input logic pclk_125,
    input logic pclk_250,
    input logic pclk_500,
    input logic pclk_1000,
    input logic phy_rst_n,
    input logic [2:0] rate_request,
    output logic pclk,
    output logic [2:0] active_rate,
    output logic clock_ready
);
    // Close all gates before selecting a new source.
    // Rate 0-4: 62.5/125/250/500/1000 MHz.
    wire [4:0] clock_source = {pclk_1000, pclk_500, pclk_250, pclk_125, pclk_62p5};
    logic [2:0] rate_meta, rate_sync, rate_previous;
    logic [4:0] gate_request, gate_enable, enable_meta, enable_sync;
    logic [2:0] target_rate;
    localparam [1:0] RUN = 0, WAIT_OFF = 1, WAIT_ON = 2;
    logic [1:0] switch_state;
    wire rates_agree = (rate_sync <= 3'd4);
    wire rates_stable = (rate_sync == rate_previous);
    assign clock_ready = phy_rst_n && (switch_state == RUN) && (enable_sync == gate_request);
    assign pclk = |(clock_source & gate_enable);

    pcie_pipe_clock_gate #(
        .RESET_ENABLE(1)
    ) u_gate_pclk_62p5 (
        .clk(pclk_62p5),
        .phy_rst_n(phy_rst_n),
        .request(gate_request[0]),
        .gate_enable(gate_enable[0])
    );
    pcie_pipe_clock_gate #(
        .RESET_ENABLE(0)
    ) u_gate_pclk_125 (
        .clk(pclk_125),
        .phy_rst_n(phy_rst_n),
        .request(gate_request[1]),
        .gate_enable(gate_enable[1])
    );
    pcie_pipe_clock_gate #(
        .RESET_ENABLE(0)
    ) u_gate_pclk_250 (
        .clk(pclk_250),
        .phy_rst_n(phy_rst_n),
        .request(gate_request[2]),
        .gate_enable(gate_enable[2])
    );
    pcie_pipe_clock_gate #(
        .RESET_ENABLE(0)
    ) u_gate_pclk_500 (
        .clk(pclk_500),
        .phy_rst_n(phy_rst_n),
        .request(gate_request[3]),
        .gate_enable(gate_enable[3])
    );
    pcie_pipe_clock_gate #(
        .RESET_ENABLE(0)
    ) u_gate_pclk_1000 (
        .clk(pclk_1000),
        .phy_rst_n(phy_rst_n),
        .request(gate_request[4]),
        .gate_enable(gate_enable[4])
    );
    always @(posedge pclk_62p5 or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            rate_meta <= '0;
            rate_sync <= '0;
            rate_previous <= '0;
            enable_meta <= 5'b00001;
            enable_sync <= 5'b00001;
            gate_request <= 5'b00001;
            target_rate <= 0;
            active_rate <= 0;
            switch_state <= RUN;
        end else begin
            rate_meta <= rate_request;
            rate_sync <= rate_meta;
            rate_previous <= rate_sync;
            enable_meta <= gate_enable;
            enable_sync <= enable_meta;
            case (switch_state)
                RUN: if (rates_agree && rates_stable && rate_sync != active_rate) begin
                    target_rate <= rate_sync;
                    gate_request <= '0;
                    switch_state <= WAIT_OFF;
                end
                WAIT_OFF: if (enable_sync == 0) begin
                    gate_request <= 5'b00001 << target_rate;
                    switch_state <= WAIT_ON;
                end
                WAIT_ON: if (enable_sync == gate_request) begin
                    active_rate <= target_rate;
                    switch_state <= RUN;
                end
                default: begin
                    gate_request <= '0;
                    switch_state <= WAIT_OFF;
                end
            endcase
        end
    end

endmodule
