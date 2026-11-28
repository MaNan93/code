module pcie_pipe_lane #(
    parameter int DATA_WD    = 80,
    parameter int TXEI_WD    = 4,
    parameter int FIFO_DEPTH = 8
) (
    input  logic               dsp_pclk,
    input  logic               dsp_rx_clk,
    input  logic               dsp_phy_rst_n,
    input  logic               usp_pclk,
    input  logic               usp_rx_clk,
    input  logic               usp_phy_rst_n,
    input  logic               clocks_aligned,

    input  logic [3:0]         dsp_powerdown,
    input  logic               dsp_rxpolarity,
    input  logic [TXEI_WD-1:0] dsp_txelecidle,
    input  logic               dsp_txdatavalid,
    input  logic [DATA_WD-1:0] dsp_txdata,
    input  logic               dsp_turnoff_lane,

    input  logic [3:0]         usp_powerdown,
    input  logic               usp_rxpolarity,
    input  logic [TXEI_WD-1:0] usp_txelecidle,
    input  logic               usp_txdatavalid,
    input  logic [DATA_WD-1:0] usp_txdata,
    input  logic               usp_turnoff_lane,

    output logic [DATA_WD-1:0] dsp_rxdata,
    output logic               dsp_rxvalid,
    output logic               dsp_rxelecidle,

    output logic [DATA_WD-1:0] usp_rxdata,
    output logic               usp_rxvalid,
    output logic               usp_rxelecidle
);
    localparam logic [3:0] PD_P0 = 4'd0;

    // One shared directional helper via two symmetric blocks
    // --- DSP TX -> USP RX ---
    logic               d2u_fifo_rst_n;
    logic               d2u_tx_idle;
    logic               d2u_wr_en;
    logic               d2u_wr_full;
    logic               d2u_rd_empty;
    logic [DATA_WD-1:0] d2u_fifo_rdata;
    logic               d2u_tx_idle_meta, d2u_tx_idle_sync;
    logic               d2u_pol_meta, d2u_pol_sync;

    assign d2u_tx_idle    = (&dsp_txelecidle) || (dsp_powerdown != PD_P0) || dsp_turnoff_lane;
    assign d2u_fifo_rst_n = dsp_phy_rst_n && usp_phy_rst_n && clocks_aligned;
    assign d2u_wr_en      = d2u_fifo_rst_n && !d2u_tx_idle && dsp_txdatavalid;

    pcie_pipe_cdc_fifo #(.WIDTH(DATA_WD), .DEPTH(FIFO_DEPTH)) u_fifo_d2u (
        .wr_clk  (dsp_pclk),
        .wr_rst_n(d2u_fifo_rst_n),
        .wr_en   (d2u_wr_en),
        .wr_data (dsp_txdata),
        .wr_full (d2u_wr_full),
        .rd_clk  (usp_rx_clk),
        .rd_rst_n(d2u_fifo_rst_n),
        .rd_en   (!d2u_rd_empty),
        .rd_data (d2u_fifo_rdata),
        .rd_empty(d2u_rd_empty)
    );

    always_ff @(posedge usp_rx_clk or negedge d2u_fifo_rst_n) begin
        if (!d2u_fifo_rst_n) begin
            d2u_tx_idle_meta <= 1'b1;
            d2u_tx_idle_sync <= 1'b1;
            d2u_pol_meta     <= 1'b0;
            d2u_pol_sync     <= 1'b0;
            usp_rxdata       <= '0;
            usp_rxvalid      <= 1'b0;
            usp_rxelecidle   <= 1'b1;
        end else begin
            d2u_tx_idle_meta <= d2u_tx_idle;
            d2u_tx_idle_sync <= d2u_tx_idle_meta;
            d2u_pol_meta     <= usp_rxpolarity;
            d2u_pol_sync     <= d2u_pol_meta;

            if (!d2u_rd_empty) begin
                usp_rxdata     <= d2u_pol_sync ? ~d2u_fifo_rdata : d2u_fifo_rdata;
                usp_rxvalid    <= 1'b1;
                usp_rxelecidle <= 1'b0;
            end else begin
                usp_rxdata     <= '0;
                usp_rxvalid    <= 1'b0;
                usp_rxelecidle <= d2u_tx_idle_sync || (usp_powerdown != PD_P0) || usp_turnoff_lane;
            end
        end
    end

    // --- USP TX -> DSP RX ---
    logic               u2d_fifo_rst_n;
    logic               u2d_tx_idle;
    logic               u2d_wr_en;
    logic               u2d_wr_full;
    logic               u2d_rd_empty;
    logic [DATA_WD-1:0] u2d_fifo_rdata;
    logic               u2d_tx_idle_meta, u2d_tx_idle_sync;
    logic               u2d_pol_meta, u2d_pol_sync;

    assign u2d_tx_idle    = (&usp_txelecidle) || (usp_powerdown != PD_P0) || usp_turnoff_lane;
    assign u2d_fifo_rst_n = dsp_phy_rst_n && usp_phy_rst_n && clocks_aligned;
    assign u2d_wr_en      = u2d_fifo_rst_n && !u2d_tx_idle && usp_txdatavalid;

    pcie_pipe_cdc_fifo #(.WIDTH(DATA_WD), .DEPTH(FIFO_DEPTH)) u_fifo_u2d (
        .wr_clk  (usp_pclk),
        .wr_rst_n(u2d_fifo_rst_n),
        .wr_en   (u2d_wr_en),
        .wr_data (usp_txdata),
        .wr_full (u2d_wr_full),
        .rd_clk  (dsp_rx_clk),
        .rd_rst_n(u2d_fifo_rst_n),
        .rd_en   (!u2d_rd_empty),
        .rd_data (u2d_fifo_rdata),
        .rd_empty(u2d_rd_empty)
    );

    always_ff @(posedge dsp_rx_clk or negedge u2d_fifo_rst_n) begin
        if (!u2d_fifo_rst_n) begin
            u2d_tx_idle_meta <= 1'b1;
            u2d_tx_idle_sync <= 1'b1;
            u2d_pol_meta     <= 1'b0;
            u2d_pol_sync     <= 1'b0;
            dsp_rxdata       <= '0;
            dsp_rxvalid      <= 1'b0;
            dsp_rxelecidle   <= 1'b1;
        end else begin
            u2d_tx_idle_meta <= u2d_tx_idle;
            u2d_tx_idle_sync <= u2d_tx_idle_meta;
            u2d_pol_meta     <= dsp_rxpolarity;
            u2d_pol_sync     <= u2d_pol_meta;

            if (!u2d_rd_empty) begin
                dsp_rxdata     <= u2d_pol_sync ? ~u2d_fifo_rdata : u2d_fifo_rdata;
                dsp_rxvalid    <= 1'b1;
                dsp_rxelecidle <= 1'b0;
            end else begin
                dsp_rxdata     <= '0;
                dsp_rxvalid    <= 1'b0;
                dsp_rxelecidle <= u2d_tx_idle_sync || (dsp_powerdown != PD_P0) || dsp_turnoff_lane;
            end
        end
    end
endmodule
