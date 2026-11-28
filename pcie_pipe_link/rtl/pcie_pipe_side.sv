module pcie_pipe_side #(
    parameter int NL             = 4,
    parameter int DATA_WD        = 80,
    parameter int TXEI_WD        = 4,
    parameter int DIRFEEDBACK_WD = 12,
    parameter int FOMFEEDBACK_WD = 8,
    parameter int TX_COEF_WD     = 18,
    parameter int TX_PSET_WD     = 6,
    parameter int FS_LF_WD       = 6,
    parameter int RX_PSET_WD     = 3,
    parameter int PCLK_RATE_WD   = 5,
    parameter logic [2:0] MAX_RATE = 3'd5,
    parameter int ACK_CYCLES     = 8,
    parameter int EQ_CYCLES      = 8
) (
    input  logic                        pclk_62p5,
    input  logic                        pclk_125,
    input  logic                        pclk_250,
    input  logic                        pclk_500,
    input  logic                        pclk_1000,

    // Per-lane clocks & resets
    input  logic [NL-1:0]               phy_rst_n,
    input  logic [NL-1:0]               pclk,
    input  logic [NL-1:0]               mac_phy_maxpclkreq_n,
    input  logic [NL*3-1:0]             peer_active_rate,
    input  logic [NL-1:0]               peer_phy_rst_n,

    output logic [NL-1:0]               max_pclk,
    output logic [NL-1:0]               rx_clk,
    output logic [NL-1:0]               phy_mac_maxpclkack_n,
    output logic [NL-1:0]               phy_ref_clk_req_n,
    output logic [NL*3-1:0]             active_rate,
    output logic [NL-1:0]               clock_ready,

    // Per-lane PIPE controls
    input  logic [NL*3-1:0]             mac_phy_rate,
    input  logic [NL*4-1:0]             mac_phy_powerdown,
    input  logic [NL-1:0]               mac_phy_asyncpowerchangeack,
    input  logic [NL*PCLK_RATE_WD-1:0]  mac_phy_pclk_rate,
    input  logic [NL-1:0]               mac_phy_serdes_arch,
    input  logic [NL*2-1:0]             mac_phy_width,
    input  logic [NL*2-1:0]             mac_phy_rxwidth,
    input  logic [NL*TXEI_WD-1:0]       mac_phy_txelecidle,
    input  logic [NL-1:0]               mac_phy_txdetectrx_loopback,
    input  logic [NL-1:0]               mac_phy_rxstandby,
    input  logic [NL-1:0]               serdes_pipe_rxready,
    input  logic [NL-1:0]               serdes_pipe_turnoff_lanes,

    // Per-lane EQ (sideband + PIPE 5.1/6.0 MessageBus)
    input  logic [NL-1:0]               mac_phy_rxeqeval,
    input  logic [NL-1:0]               mac_phy_rxeqinprogress,
    input  logic [NL-1:0]               mac_phy_invalid_req,
    input  logic [NL-1:0]               mac_phy_getlocal_pset_coef,
    input  logic [NL*TX_PSET_WD-1:0]    mac_phy_local_pset_index,
    input  logic [NL-1:0]               mac_phy_dirchange,
    input  logic [NL*TX_COEF_WD-1:0]    mac_phy_txdeemph,
    input  logic [NL*FS_LF_WD-1:0]      mac_phy_fs,
    input  logic [NL*FS_LF_WD-1:0]      mac_phy_lf,
    input  logic [NL*RX_PSET_WD-1:0]    mac_phy_rxpresethint,
    input  logic [NL*3-1:0]             mac_phy_txmargin,
    input  logic [NL-1:0]               mac_phy_txswing,
    input  logic [NL*8-1:0]             mac_phy_messagebus,
    input  logic [NL*32-1:0]            mac_phy_pipe_config_control,

    output logic [NL-1:0]               phy_mac_rxstandbystatus,
    output logic [NL-1:0]               phy_mac_phystatus,
    output logic [NL*FS_LF_WD-1:0]      phy_mac_localfs,
    output logic [NL*FS_LF_WD-1:0]      phy_mac_locallf,
    output logic [NL*DIRFEEDBACK_WD-1:0] phy_mac_dirfeedback,
    output logic [NL*FOMFEEDBACK_WD-1:0] phy_mac_fomfeedback,
    output logic [NL*TX_COEF_WD-1:0]    phy_mac_local_tx_pset_coef,
    output logic [NL-1:0]               phy_mac_local_tx_coef_valid,
    output logic [NL*8-1:0]             phy_mac_messagebus,
    output logic [NL*32-1:0]            phy_mac_pipe_config_status,

    // Combined lane RX status from link + local control events
    input  logic [NL*3-1:0]             lane_rxstatus_in,
    output logic [NL*3-1:0]             phy_mac_rxstatus
);
    logic [NL*PCLK_RATE_WD-1:0] unused_pclk_rate;
    logic [NL-1:0]              unused_serdes_arch, unused_rxready, unused_turnoff, unused_txswing;
    logic [NL*2-1:0]            unused_w, unused_rw;
    logic [NL*3-1:0]            unused_margin;
    logic [NL*32-1:0]           unused_cfg;

    assign unused_pclk_rate   = mac_phy_pclk_rate;
    assign unused_serdes_arch = mac_phy_serdes_arch;
    assign unused_rxready     = serdes_pipe_rxready;
    assign unused_turnoff     = serdes_pipe_turnoff_lanes;
    assign unused_w           = mac_phy_width;
    assign unused_rw          = mac_phy_rxwidth;
    assign unused_margin      = mac_phy_txmargin;
    assign unused_txswing     = mac_phy_txswing;
    assign unused_cfg         = mac_phy_pipe_config_control;

    assign phy_mac_pipe_config_status = '0;

    for (genvar i = 0; i < NL; i++) begin : g_lane
        logic       lane_maxpclk_gated;
        logic       lane_phystatus_ctrl;
        logic       lane_phystatus_eq;
        logic [2:0] lane_rxstatus_ctrl;
        logic [2:0] lane_rx_rate_sel;
        logic       unused_rxclk_ready;
        logic       unused_rxclk_gated;
        logic [2:0] unused_rx_active_rate;

        // MessageBus-decoded per-lane signals
        logic                      msg_rxeqeval;
        logic                      msg_rxeqinprogress;
        logic                      msg_invalid_req;
        logic                      msg_getlocal_pset_coef;
        logic [TX_PSET_WD-1:0]     msg_local_pset_index;
        logic [FS_LF_WD-1:0]       msg_fs, msg_lf;
        logic [TX_COEF_WD-1:0]     msg_txdeemph;
        logic [2:0]                msg_txmargin;
        logic                      msg_txswing;
        logic                      msg_rxpolarity;
        logic                      msg_eq_active;
        logic                      unused_msg_misc;
        assign unused_msg_misc = (^msg_txmargin) ^ msg_txswing ^ msg_rxpolarity;

        assign phy_mac_maxpclkack_n[i] = lane_maxpclk_gated;
        assign phy_ref_clk_req_n[i]    = lane_maxpclk_gated;

        // Per-lane Dynamic MAXPCLK switch (pclk_as_phy_input mode)
        pcie_pipe_pclk_switch #(.MAX_RATE(MAX_RATE)) u_max_pclk_switch (
            .pclk_62p5  (pclk_62p5),
            .pclk_125   (pclk_125),
            .pclk_250   (pclk_250),
            .pclk_500   (pclk_500),
            .pclk_1000  (pclk_1000),
            .phy_rst_n  (phy_rst_n[i]),
            .clk_en     (!mac_phy_maxpclkreq_n[i]),
            .rate_req   (mac_phy_rate[i*3 +: 3]),
            .pclk       (max_pclk[i]),
            .active_rate(active_rate[i*3 +: 3]),
            .clock_ready(clock_ready[i]),
            .clk_gated  (lane_maxpclk_gated)
        );

        // Recovered RX clock follows peer active rate while peer is out of reset
        assign lane_rx_rate_sel = peer_phy_rst_n[i] ? peer_active_rate[i*3 +: 3] :
                                                      mac_phy_rate[i*3 +: 3];

        pcie_pipe_pclk_switch #(.MAX_RATE(MAX_RATE)) u_rx_clk_switch (
            .pclk_62p5  (pclk_62p5),
            .pclk_125   (pclk_125),
            .pclk_250   (pclk_250),
            .pclk_500   (pclk_500),
            .pclk_1000  (pclk_1000),
            .phy_rst_n  (phy_rst_n[i]),
            .clk_en     (1'b1),
            .rate_req   (lane_rx_rate_sel),
            .pclk       (rx_clk[i]),
            .active_rate(unused_rx_active_rate),
            .clock_ready(unused_rxclk_ready),
            .clk_gated  (unused_rxclk_gated)
        );

        pcie_pipe_status_lane #(
            .ACK_CYCLES(ACK_CYCLES),
            .TXEI_WD   (TXEI_WD)
        ) u_status_lane (
            .pclk               (pclk[i]),
            .phy_rst_n          (phy_rst_n[i]),
            .rate               (mac_phy_rate[i*3 +: 3]),
            .active_rate        (active_rate[i*3 +: 3]),
            .clock_ready        (clock_ready[i]),
            .powerdown          (mac_phy_powerdown[i*4 +: 4]),
            .asyncpowerchangeack(mac_phy_asyncpowerchangeack[i]),
            .txelecidle         (mac_phy_txelecidle[i*TXEI_WD +: TXEI_WD]),
            .txdetectrx_loopback(mac_phy_txdetectrx_loopback[i]),
            .rxstandby          (mac_phy_rxstandby[i]),
            .peer_present       (peer_phy_rst_n[i]),
            .phystatus_ctrl     (lane_phystatus_ctrl),
            .rxstatus_ctrl      (lane_rxstatus_ctrl),
            .rxstandbystatus    (phy_mac_rxstandbystatus[i])
        );

        pcie_pipe_eq_lane #(
            .FS_LF_WD      (FS_LF_WD),
            .DIRFEEDBACK_WD(DIRFEEDBACK_WD),
            .FOMFEEDBACK_WD(FOMFEEDBACK_WD),
            .TX_COEF_WD    (TX_COEF_WD),
            .TX_PSET_WD    (TX_PSET_WD),
            .RX_PSET_WD    (RX_PSET_WD),
            .EQ_CYCLES     (EQ_CYCLES)
        ) u_eq_lane (
            .pclk               (pclk[i]),
            .phy_rst_n          (phy_rst_n[i]),
            .rate               (mac_phy_rate[i*3 +: 3]),
            .rxeqeval           (mac_phy_rxeqeval[i] | msg_rxeqeval),
            .rxeqinprogress     (mac_phy_rxeqinprogress[i] | msg_rxeqinprogress),
            .invalid_req        (mac_phy_invalid_req[i] | msg_invalid_req),
            .getlocal_pset_coef (mac_phy_getlocal_pset_coef[i] | msg_getlocal_pset_coef),
            .local_pset_index   (msg_getlocal_pset_coef ? msg_local_pset_index :
                                                          mac_phy_local_pset_index[i*TX_PSET_WD +: TX_PSET_WD]),
            .dirchange          (mac_phy_dirchange[i]),
            .txdeemph           (mac_phy_txdeemph[i*TX_COEF_WD +: TX_COEF_WD] | msg_txdeemph),
            .fs                 (mac_phy_fs[i*FS_LF_WD +: FS_LF_WD] | msg_fs),
            .lf                 (mac_phy_lf[i*FS_LF_WD +: FS_LF_WD] | msg_lf),
            .rxpresethint       (mac_phy_rxpresethint[i*RX_PSET_WD +: RX_PSET_WD]),
            .localfs            (phy_mac_localfs[i*FS_LF_WD +: FS_LF_WD]),
            .locallf            (phy_mac_locallf[i*FS_LF_WD +: FS_LF_WD]),
            .dirfeedback        (phy_mac_dirfeedback[i*DIRFEEDBACK_WD +: DIRFEEDBACK_WD]),
            .fomfeedback        (phy_mac_fomfeedback[i*FOMFEEDBACK_WD +: FOMFEEDBACK_WD]),
            .local_tx_pset_coef (phy_mac_local_tx_pset_coef[i*TX_COEF_WD +: TX_COEF_WD]),
            .local_tx_coef_valid(phy_mac_local_tx_coef_valid[i]),
            .phystatus_eq       (lane_phystatus_eq)
        );

        pcie_pipe_msgbus_lane #(
            .FS_LF_WD      (FS_LF_WD),
            .DIRFEEDBACK_WD(DIRFEEDBACK_WD),
            .FOMFEEDBACK_WD(FOMFEEDBACK_WD),
            .TX_COEF_WD    (TX_COEF_WD),
            .TX_PSET_WD    (TX_PSET_WD)
        ) u_msgbus_lane (
            .pclk                  (pclk[i]),
            .phy_rst_n             (phy_rst_n[i]),
            .clock_ready           (clock_ready[i]),
            .rate                  (mac_phy_rate[i*3 +: 3]),
            .mac_phy_messagebus    (mac_phy_messagebus[i*8 +: 8]),
            .phy_mac_messagebus    (phy_mac_messagebus[i*8 +: 8]),
            .msg_rxeqeval          (msg_rxeqeval),
            .msg_rxeqinprogress    (msg_rxeqinprogress),
            .msg_invalid_req       (msg_invalid_req),
            .msg_getlocal_pset_coef(msg_getlocal_pset_coef),
            .msg_local_pset_index  (msg_local_pset_index),
            .msg_fs                (msg_fs),
            .msg_lf                (msg_lf),
            .msg_txdeemph          (msg_txdeemph),
            .msg_txmargin          (msg_txmargin),
            .msg_txswing           (msg_txswing),
            .msg_rxpolarity        (msg_rxpolarity),
            .msg_eq_active         (msg_eq_active),
            .localfs               (phy_mac_localfs[i*FS_LF_WD +: FS_LF_WD]),
            .locallf               (phy_mac_locallf[i*FS_LF_WD +: FS_LF_WD]),
            .eq_local_tx_coef_valid(phy_mac_local_tx_coef_valid[i]),
            .eq_local_tx_pset_coef (phy_mac_local_tx_pset_coef[i*TX_COEF_WD +: TX_COEF_WD]),
            .eq_eval_done          (lane_phystatus_eq),
            .eq_dirfeedback        (phy_mac_dirfeedback[i*DIRFEEDBACK_WD +: DIRFEEDBACK_WD]),
            .eq_fomfeedback        (phy_mac_fomfeedback[i*FOMFEEDBACK_WD +: FOMFEEDBACK_WD])
        );

        assign phy_mac_phystatus[i]       = lane_phystatus_ctrl | (msg_eq_active ? 1'b0 : lane_phystatus_eq);
        assign phy_mac_rxstatus[i*3 +: 3] = (lane_rxstatus_ctrl != 3'b000) ? lane_rxstatus_ctrl :
                                                                             lane_rxstatus_in[i*3 +: 3];
    end
endmodule
