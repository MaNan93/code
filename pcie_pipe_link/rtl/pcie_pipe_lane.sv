module pcie_pipe_lane #(
    parameter integer ACK_CYCLES = 8,
    parameter integer EQ_CYCLES = 8
)(
    input logic pclk,
    input logic phy_rst_n,
    input logic [2:0] mac_phy_rate,
    input logic shared_status_due,
    output logic shared_ack,
    input logic data_enable,
    input logic mac_phy_txdetectrx_loopback,
    input logic mac_phy_rxstandby,
    input logic mac_phy_rxeqeval,
    input logic mac_phy_rxeqinprogress,
    input logic mac_phy_invalid_req,
    input logic mac_phy_getlocal_pset_coef,
    input logic [5:0] mac_phy_local_pset_index,
    input logic mac_phy_dirchange,
    input logic [17:0] mac_phy_txdeemph,
    output logic phy_mac_rxelecidle,
    output logic phy_mac_phystatus,
    output logic [31:0] phy_mac_rxdata,
    output logic [3:0] phy_mac_rxdatak,
    output logic phy_mac_rxvalid,
    output logic [2:0] phy_mac_rxstatus,
    output logic phy_mac_rxstandbystatus,
    output logic phy_mac_rxdatavalid,
    output logic phy_mac_rxstartblock,
    output logic [1:0] phy_mac_rxsyncheader,
    output logic [5:0] phy_mac_localfs,
    output logic [5:0] phy_mac_locallf,
    output logic [5:0] phy_mac_dirfeedback,
    output logic [7:0] phy_mac_fomfeedback,
    output logic [17:0] phy_mac_local_tx_pset_coef,
    output logic phy_mac_local_tx_coef_valid,
    output logic [7:0] phy_mac_messagebus,
    input logic [31:0] peer_mac_phy_txdata,
    input logic [3:0] peer_mac_phy_txdatak,
    input logic peer_mac_phy_txelecidle,
    input logic peer_mac_phy_txdatavalid,
    input logic peer_mac_phy_txstartblock,
    input logic [1:0] peer_mac_phy_txsyncheader
);
    logic eq_due;
    pcie_pipe_eq_lane #(
        .EQ_CYCLES(EQ_CYCLES)
    ) u_eq (
        .pclk(pclk),
        .phy_rst_n(phy_rst_n),
        .mac_phy_rate(mac_phy_rate),
        .eq_due(eq_due),
        .mac_phy_rxeqeval(mac_phy_rxeqeval),
        .mac_phy_rxeqinprogress(mac_phy_rxeqinprogress),
        .mac_phy_invalid_req(mac_phy_invalid_req),
        .mac_phy_getlocal_pset_coef(mac_phy_getlocal_pset_coef),
        .mac_phy_local_pset_index(mac_phy_local_pset_index),
        .mac_phy_dirchange(mac_phy_dirchange),
        .mac_phy_txdeemph(mac_phy_txdeemph),
        .phy_mac_localfs(phy_mac_localfs),
        .phy_mac_locallf(phy_mac_locallf),
        .phy_mac_dirfeedback(phy_mac_dirfeedback),
        .phy_mac_fomfeedback(phy_mac_fomfeedback),
        .phy_mac_local_tx_pset_coef(phy_mac_local_tx_pset_coef),
        .phy_mac_local_tx_coef_valid(phy_mac_local_tx_coef_valid)
    );
    pcie_pipe_status_lane #(
        .ACK_CYCLES(ACK_CYCLES)
    ) u_status (
        .pclk(pclk),
        .phy_rst_n(phy_rst_n),
        .shared_status_due(shared_status_due),
        .shared_ack(shared_ack),
        .eq_due(eq_due),
        .mac_phy_txdetectrx_loopback(mac_phy_txdetectrx_loopback),
        .phy_mac_phystatus(phy_mac_phystatus),
        .phy_mac_rxstatus(phy_mac_rxstatus)
    );
    assign phy_mac_rxdata = data_enable ? peer_mac_phy_txdata : '0;
    assign phy_mac_rxdatak = data_enable ? peer_mac_phy_txdatak : '0;
    assign phy_mac_rxvalid = data_enable ? ~peer_mac_phy_txelecidle : '0;
    assign phy_mac_rxdatavalid = data_enable ? peer_mac_phy_txdatavalid : '0;
    assign phy_mac_rxstartblock = data_enable ? peer_mac_phy_txstartblock : '0;
    assign phy_mac_rxsyncheader = data_enable ? peer_mac_phy_txsyncheader : '0;
    assign phy_mac_rxelecidle = data_enable ? peer_mac_phy_txelecidle : 1'b1;
    assign phy_mac_rxstandbystatus = mac_phy_rxstandby;
    assign phy_mac_messagebus = '0;

endmodule
