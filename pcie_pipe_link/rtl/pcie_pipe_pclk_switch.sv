module pcie_pipe_pclk_switch #(
    parameter logic [2:0] MAX_RATE = 3'd5
) (
    input  logic       pclk_62p5,
    input  logic       pclk_125,
    input  logic       pclk_250,
    input  logic       pclk_500,
    input  logic       pclk_1000,
    input  logic       phy_rst_n,
    input  logic       clk_en,
    input  logic [2:0] rate_req,
    output logic       pclk,
    output logic [2:0] active_rate,
    output logic       clock_ready,
    output logic       clk_gated
);
    typedef enum logic [2:0] {
        ST_RUN           = 3'd0,
        ST_WAIT_OFF      = 3'd1,
        ST_WAIT_ON       = 3'd2,
        ST_WAIT_GATE_OFF = 3'd3,
        ST_GATED         = 3'd4
    } state_t;

    state_t      state;
    logic [2:0]  target_rate;
    logic [4:0]  gate_request;
    logic [4:0]  gate_enable;
    logic [4:0]  gated_clk;

    logic [2:0]  rate_meta;
    logic [2:0]  rate_sync;
    logic        clk_en_meta;
    logic        clk_en_sync;
    logic [4:0]  enable_meta;
    logic [4:0]  enable_sync;

    // Gen1(0)->62.5, Gen2(1)->125, Gen3(2)->250, Gen4(3)->500, Gen5(4)&Gen6-8s(5)->1000.
    function automatic logic [2:0] rate_to_clk_idx(input logic [2:0] rate);
        return (rate >= 3'd4) ? 3'd4 : rate;
    endfunction

    function automatic logic [4:0] clk_mask(input logic [2:0] rate);
        return 5'b00001 << rate_to_clk_idx(rate);
    endfunction

    pcie_pipe_clock_gate #(.RESET_ENABLE(1'b1)) u_gate_62p5 (
        .clk(pclk_62p5), .phy_rst_n(phy_rst_n), .request(gate_request[0]),
        .gate_enable(gate_enable[0]), .gclk(gated_clk[0])
    );
    pcie_pipe_clock_gate #(.RESET_ENABLE(1'b0)) u_gate_125 (
        .clk(pclk_125), .phy_rst_n(phy_rst_n), .request(gate_request[1]),
        .gate_enable(gate_enable[1]), .gclk(gated_clk[1])
    );
    pcie_pipe_clock_gate #(.RESET_ENABLE(1'b0)) u_gate_250 (
        .clk(pclk_250), .phy_rst_n(phy_rst_n), .request(gate_request[2]),
        .gate_enable(gate_enable[2]), .gclk(gated_clk[2])
    );
    pcie_pipe_clock_gate #(.RESET_ENABLE(1'b0)) u_gate_500 (
        .clk(pclk_500), .phy_rst_n(phy_rst_n), .request(gate_request[3]),
        .gate_enable(gate_enable[3]), .gclk(gated_clk[3])
    );
    pcie_pipe_clock_gate #(.RESET_ENABLE(1'b0)) u_gate_1000 (
        .clk(pclk_1000), .phy_rst_n(phy_rst_n), .request(gate_request[4]),
        .gate_enable(gate_enable[4]), .gclk(gated_clk[4])
    );

    assign pclk = |gated_clk;

    logic rate_valid;
    assign rate_valid = (rate_meta == rate_sync) && (rate_sync <= MAX_RATE);

    always_ff @(posedge pclk_1000 or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            rate_meta    <= 3'd0;
            rate_sync    <= 3'd0;
            clk_en_meta  <= 1'b1;
            clk_en_sync  <= 1'b1;
            enable_meta  <= 5'b00001;
            enable_sync  <= 5'b00001;
            state        <= ST_RUN;
            active_rate  <= 3'd0;
            target_rate  <= 3'd0;
            gate_request <= 5'b00001;
        end else begin
            rate_meta   <= rate_req;
            rate_sync   <= rate_meta;
            clk_en_meta <= clk_en;
            clk_en_sync <= clk_en_meta;
            enable_meta <= gate_enable;
            enable_sync <= enable_meta;

            case (state)
                ST_RUN: begin
                    if (!clk_en_sync) begin
                        gate_request <= 5'b00000;
                        state        <= ST_WAIT_GATE_OFF;
                    end else if (rate_valid && (rate_sync != active_rate)) begin
                        if (rate_to_clk_idx(rate_sync) == rate_to_clk_idx(active_rate)) begin
                            // Gen5(4) <-> Gen6(5) share 1000 MHz pclk_1000; update without stopping clock.
                            active_rate <= rate_sync;
                            target_rate <= rate_sync;
                        end else begin
                            target_rate  <= rate_sync;
                            gate_request <= 5'b00000;
                            state        <= ST_WAIT_OFF;
                        end
                    end
                end

                ST_WAIT_OFF: begin
                    if (enable_sync == 5'b00000) begin
                        gate_request <= clk_mask(target_rate);
                        state        <= ST_WAIT_ON;
                    end
                end

                ST_WAIT_ON: begin
                    if ((enable_sync == gate_request) && (gate_request != 5'b00000)) begin
                        active_rate <= target_rate;
                        state       <= ST_RUN;
                    end
                end

                ST_WAIT_GATE_OFF: begin
                    if (enable_sync == 5'b00000) begin
                        state <= ST_GATED;
                    end
                end

                ST_GATED: begin
                    if (clk_en_sync) begin
                        if (rate_valid) begin
                            target_rate  <= rate_sync;
                            gate_request <= clk_mask(rate_sync);
                        end else begin
                            target_rate  <= active_rate;
                            gate_request <= clk_mask(active_rate);
                        end
                        state <= ST_WAIT_ON;
                    end
                end

                default: begin
                    state        <= ST_WAIT_OFF;
                    gate_request <= 5'b00000;
                end
            endcase
        end
    end

    assign clk_gated = (state == ST_GATED);
    assign clock_ready = (state == ST_RUN) && clk_en_sync && rate_valid &&
                         (rate_sync == active_rate) &&
                         ((enable_sync & clk_mask(active_rate)) != 5'b00000);
endmodule
