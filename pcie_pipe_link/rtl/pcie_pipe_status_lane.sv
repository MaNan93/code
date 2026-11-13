module pcie_pipe_status_lane #(
    parameter integer ACK_CYCLES = 8
)(
    input logic pclk,
    input logic phy_rst_n,
    input logic shared_status_due,
    input logic eq_due,
    input logic mac_phy_txdetectrx_loopback,
    output logic phy_mac_phystatus,
    output logic shared_ack,
    output logic [2:0] phy_mac_rxstatus
);
    logic detect_q;
    logic [ACK_CYCLES-1:0] detect_delay;
    logic general_pending, eq_pending;
    logic general_due;
    logic shared_pending;
    assign general_due = shared_status_due | detect_delay[ACK_CYCLES-1];
    assign phy_mac_rxstatus = mac_phy_txdetectrx_loopback ? 3'b011 : 3'b000;
    always @(posedge pclk or negedge phy_rst_n) begin
        if (!phy_rst_n) begin
            detect_q <= 0;
            detect_delay <= 0;
            general_pending <= 0;
            eq_pending <= 0;
            phy_mac_phystatus <= 0;
            shared_ack <= 0;
            shared_pending <= 0;
        end else begin
            detect_q <= mac_phy_txdetectrx_loopback;
            detect_delay <= (detect_delay << 1) | (mac_phy_txdetectrx_loopback & ~detect_q);
            phy_mac_phystatus <= 0;
            shared_ack <= 0;
            shared_pending <= shared_pending | shared_status_due;
            general_pending <= general_pending | general_due;
            eq_pending <= eq_pending | eq_due;
            // Leave a low cycle between completion pulses.
            if (!phy_mac_phystatus) begin
                if (eq_pending || eq_due) begin
                    phy_mac_phystatus <= 1;
                    eq_pending <= 0;
                end else if (general_pending || general_due) begin
                    phy_mac_phystatus <= 1;
                    shared_ack <= shared_pending | shared_status_due;
                    shared_pending <= 0;
                    general_pending <= 0;
                end
            end
        end
    end
endmodule
