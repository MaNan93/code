// PIPE lane mapper connection wrapper.
//
// Pure struct<->flat bridge around pipe_lane_mapper: every pipe_signals.csv
// row becomes its own flat port here instead of a packed-struct field, for
// integration with flows/IP that don't want SV struct ports. signal_type=shared
// collapses a controller's own max_width lanes to one scalar port; perlane
// (the default) stays an unpacked array of max_width. The PHY side is always
// per-lane -- which controller owns a PHY lane still varies by mode, so even a
// "shared" signal still needs its own value per PHY lane there.
import pipe_lane_signal_pkg::*;

module pipe_lane_mapper_connection #(
    parameter int NL = 6,
    parameter int NC = 6,
    parameter bit SEL_SYNC = 1'b1
) (
    input logic [NL-1:0] phy_pclk_out,
    input logic test_en,
    input logic [1:0] mode,
    output logic [NL-1:0] phy_pclk_in,
    output logic [NL-1:0] phy_rst_n,
    // PHY-side PIPE data, flattened -- always per-lane regardless of signal_type
    output logic [31:0] phy_mac_phy_txdata [0:NL-1],
    output logic [3:0] phy_mac_phy_txdatak [0:NL-1],
    output logic [0:0] phy_mac_phy_txdatavalid [0:NL-1],
    output logic [0:0] phy_mac_phy_txstartblock [0:NL-1],
    output logic [1:0] phy_mac_phy_txsyncheader [0:NL-1],
    output logic [0:0] phy_mac_phy_txdetectrx_loopback [0:NL-1],
    output logic [0:0] phy_mac_phy_txelecidle [0:NL-1],
    output logic [0:0] phy_mac_phy_txcompliance [0:NL-1],
    output logic [17:0] phy_mac_phy_txdeemph [0:NL-1],
    output logic [0:0] phy_mac_phy_rxpolarity [0:NL-1],
    output logic [7:0] phy_mac_phy_messagebus [0:NL-1],
    output logic [2:0] phy_mac_phy_rxpresethint [0:NL-1],
    output logic [4:0] phy_mac_phy_local_pset_index [0:NL-1],
    output logic [17:0] phy_mac_phy_getlocal_pset_coef [0:NL-1],
    output logic [0:0] phy_mac_phy_invalid_req [0:NL-1],
    output logic [0:0] phy_mac_phy_rxeqeval [0:NL-1],
    output logic [5:0] phy_mac_phy_fs [0:NL-1],
    output logic [5:0] phy_mac_phy_lf [0:NL-1],
    output logic [0:0] phy_mac_phy_dirchange [0:NL-1],
    output logic [0:0] phy_mac_phy_rxeqinprogress [0:NL-1],
    input logic [31:0] phy_phy_mac_rxdata [0:NL-1],
    input logic [3:0] phy_phy_mac_rxdatak [0:NL-1],
    input logic [0:0] phy_phy_mac_rxdatavalid [0:NL-1],
    input logic [0:0] phy_phy_mac_rxstartblock [0:NL-1],
    input logic [1:0] phy_phy_mac_rxsyncheader [0:NL-1],
    input logic [0:0] phy_phy_mac_rxvalid [0:NL-1],
    input logic [2:0] phy_phy_mac_rxstatus [0:NL-1],
    input logic [0:0] phy_phy_mac_rxelecidle [0:NL-1],
    input logic [0:0] phy_phy_mac_rxstandbystatus [0:NL-1],
    input logic [7:0] phy_phy_mac_messagebus [0:NL-1],
    input logic [0:0] phy_phy_mac_phystatus [0:NL-1],
    input logic [0:0] phy_phy_mac_local_tx_coef_valid [0:NL-1],
    input logic [17:0] phy_phy_mac_local_tx_pset_coef [0:NL-1],
    input logic [5:0] phy_phy_mac_localfs [0:NL-1],
    input logic [5:0] phy_phy_mac_locallf [0:NL-1],
    input logic [5:0] phy_phy_mac_dirfeedback [0:NL-1],
    input logic [7:0] phy_phy_mac_fomfeedback [0:NL-1],
    // Controller side. Each controller's ports are declared at its own real max_width.
    // CtrlAlpha x3
    input logic ctrlalpha_rst_n,
    input logic [31:0] ctrlalpha_mac_phy_txdata [0:2],
    input logic [3:0] ctrlalpha_mac_phy_txdatak [0:2],
    input logic [0:0] ctrlalpha_mac_phy_txdatavalid [0:2],
    input logic [0:0] ctrlalpha_mac_phy_txstartblock [0:2],
    input logic [1:0] ctrlalpha_mac_phy_txsyncheader [0:2],
    input logic [0:0] ctrlalpha_mac_phy_txdetectrx_loopback [0:2],
    input logic [0:0] ctrlalpha_mac_phy_txelecidle [0:2],
    input logic [0:0] ctrlalpha_mac_phy_txcompliance [0:2],
    input logic [17:0] ctrlalpha_mac_phy_txdeemph [0:2],
    input logic [0:0] ctrlalpha_mac_phy_rxpolarity [0:2],
    input logic [7:0] ctrlalpha_mac_phy_messagebus [0:2],
    input logic [2:0] ctrlalpha_mac_phy_rxpresethint [0:2],
    input logic [4:0] ctrlalpha_mac_phy_local_pset_index [0:2],
    input logic [17:0] ctrlalpha_mac_phy_getlocal_pset_coef [0:2],
    input logic [0:0] ctrlalpha_mac_phy_invalid_req [0:2],
    input logic [0:0] ctrlalpha_mac_phy_rxeqeval [0:2],
    input logic [5:0] ctrlalpha_mac_phy_fs [0:2],
    input logic [5:0] ctrlalpha_mac_phy_lf [0:2],
    input logic [0:0] ctrlalpha_mac_phy_dirchange [0:2],
    input logic [0:0] ctrlalpha_mac_phy_rxeqinprogress [0:2],
    output logic [31:0] ctrlalpha_phy_mac_rxdata [0:2],
    output logic [3:0] ctrlalpha_phy_mac_rxdatak [0:2],
    output logic [0:0] ctrlalpha_phy_mac_rxdatavalid [0:2],
    output logic [0:0] ctrlalpha_phy_mac_rxstartblock [0:2],
    output logic [1:0] ctrlalpha_phy_mac_rxsyncheader [0:2],
    output logic [0:0] ctrlalpha_phy_mac_rxvalid [0:2],
    output logic [2:0] ctrlalpha_phy_mac_rxstatus [0:2],
    output logic [0:0] ctrlalpha_phy_mac_rxelecidle [0:2],
    output logic [0:0] ctrlalpha_phy_mac_rxstandbystatus [0:2],
    output logic [7:0] ctrlalpha_phy_mac_messagebus [0:2],
    // phy_mac_phystatus: shared across CtrlAlpha's own lanes
    output logic [0:0] ctrlalpha_phy_mac_phystatus,
    output logic [0:0] ctrlalpha_phy_mac_local_tx_coef_valid [0:2],
    output logic [17:0] ctrlalpha_phy_mac_local_tx_pset_coef [0:2],
    output logic [5:0] ctrlalpha_phy_mac_localfs [0:2],
    output logic [5:0] ctrlalpha_phy_mac_locallf [0:2],
    output logic [5:0] ctrlalpha_phy_mac_dirfeedback [0:2],
    output logic [7:0] ctrlalpha_phy_mac_fomfeedback [0:2],
    output logic ctrlalpha_pclk,
    // CtrlBeta x2
    input logic ctrlbeta_rst_n,
    input logic [31:0] ctrlbeta_mac_phy_txdata [0:1],
    input logic [3:0] ctrlbeta_mac_phy_txdatak [0:1],
    input logic [0:0] ctrlbeta_mac_phy_txdatavalid [0:1],
    input logic [0:0] ctrlbeta_mac_phy_txstartblock [0:1],
    input logic [1:0] ctrlbeta_mac_phy_txsyncheader [0:1],
    input logic [0:0] ctrlbeta_mac_phy_txdetectrx_loopback [0:1],
    input logic [0:0] ctrlbeta_mac_phy_txelecidle [0:1],
    input logic [0:0] ctrlbeta_mac_phy_txcompliance [0:1],
    input logic [17:0] ctrlbeta_mac_phy_txdeemph [0:1],
    input logic [0:0] ctrlbeta_mac_phy_rxpolarity [0:1],
    input logic [7:0] ctrlbeta_mac_phy_messagebus [0:1],
    input logic [2:0] ctrlbeta_mac_phy_rxpresethint [0:1],
    input logic [4:0] ctrlbeta_mac_phy_local_pset_index [0:1],
    input logic [17:0] ctrlbeta_mac_phy_getlocal_pset_coef [0:1],
    input logic [0:0] ctrlbeta_mac_phy_invalid_req [0:1],
    input logic [0:0] ctrlbeta_mac_phy_rxeqeval [0:1],
    input logic [5:0] ctrlbeta_mac_phy_fs [0:1],
    input logic [5:0] ctrlbeta_mac_phy_lf [0:1],
    input logic [0:0] ctrlbeta_mac_phy_dirchange [0:1],
    input logic [0:0] ctrlbeta_mac_phy_rxeqinprogress [0:1],
    output logic [31:0] ctrlbeta_phy_mac_rxdata [0:1],
    output logic [3:0] ctrlbeta_phy_mac_rxdatak [0:1],
    output logic [0:0] ctrlbeta_phy_mac_rxdatavalid [0:1],
    output logic [0:0] ctrlbeta_phy_mac_rxstartblock [0:1],
    output logic [1:0] ctrlbeta_phy_mac_rxsyncheader [0:1],
    output logic [0:0] ctrlbeta_phy_mac_rxvalid [0:1],
    output logic [2:0] ctrlbeta_phy_mac_rxstatus [0:1],
    output logic [0:0] ctrlbeta_phy_mac_rxelecidle [0:1],
    output logic [0:0] ctrlbeta_phy_mac_rxstandbystatus [0:1],
    output logic [7:0] ctrlbeta_phy_mac_messagebus [0:1],
    // phy_mac_phystatus: shared across CtrlBeta's own lanes
    output logic [0:0] ctrlbeta_phy_mac_phystatus,
    output logic [0:0] ctrlbeta_phy_mac_local_tx_coef_valid [0:1],
    output logic [17:0] ctrlbeta_phy_mac_local_tx_pset_coef [0:1],
    output logic [5:0] ctrlbeta_phy_mac_localfs [0:1],
    output logic [5:0] ctrlbeta_phy_mac_locallf [0:1],
    output logic [5:0] ctrlbeta_phy_mac_dirfeedback [0:1],
    output logic [7:0] ctrlbeta_phy_mac_fomfeedback [0:1],
    output logic ctrlbeta_pclk,
    // CtrlGamma x1
    input logic ctrlgamma_rst_n,
    input logic [31:0] ctrlgamma_mac_phy_txdata [0:0],
    input logic [3:0] ctrlgamma_mac_phy_txdatak [0:0],
    input logic [0:0] ctrlgamma_mac_phy_txdatavalid [0:0],
    input logic [0:0] ctrlgamma_mac_phy_txstartblock [0:0],
    input logic [1:0] ctrlgamma_mac_phy_txsyncheader [0:0],
    input logic [0:0] ctrlgamma_mac_phy_txdetectrx_loopback [0:0],
    input logic [0:0] ctrlgamma_mac_phy_txelecidle [0:0],
    input logic [0:0] ctrlgamma_mac_phy_txcompliance [0:0],
    input logic [17:0] ctrlgamma_mac_phy_txdeemph [0:0],
    input logic [0:0] ctrlgamma_mac_phy_rxpolarity [0:0],
    input logic [7:0] ctrlgamma_mac_phy_messagebus [0:0],
    input logic [2:0] ctrlgamma_mac_phy_rxpresethint [0:0],
    input logic [4:0] ctrlgamma_mac_phy_local_pset_index [0:0],
    input logic [17:0] ctrlgamma_mac_phy_getlocal_pset_coef [0:0],
    input logic [0:0] ctrlgamma_mac_phy_invalid_req [0:0],
    input logic [0:0] ctrlgamma_mac_phy_rxeqeval [0:0],
    input logic [5:0] ctrlgamma_mac_phy_fs [0:0],
    input logic [5:0] ctrlgamma_mac_phy_lf [0:0],
    input logic [0:0] ctrlgamma_mac_phy_dirchange [0:0],
    input logic [0:0] ctrlgamma_mac_phy_rxeqinprogress [0:0],
    output logic [31:0] ctrlgamma_phy_mac_rxdata [0:0],
    output logic [3:0] ctrlgamma_phy_mac_rxdatak [0:0],
    output logic [0:0] ctrlgamma_phy_mac_rxdatavalid [0:0],
    output logic [0:0] ctrlgamma_phy_mac_rxstartblock [0:0],
    output logic [1:0] ctrlgamma_phy_mac_rxsyncheader [0:0],
    output logic [0:0] ctrlgamma_phy_mac_rxvalid [0:0],
    output logic [2:0] ctrlgamma_phy_mac_rxstatus [0:0],
    output logic [0:0] ctrlgamma_phy_mac_rxelecidle [0:0],
    output logic [0:0] ctrlgamma_phy_mac_rxstandbystatus [0:0],
    output logic [7:0] ctrlgamma_phy_mac_messagebus [0:0],
    // phy_mac_phystatus: shared across CtrlGamma's own lanes
    output logic [0:0] ctrlgamma_phy_mac_phystatus,
    output logic [0:0] ctrlgamma_phy_mac_local_tx_coef_valid [0:0],
    output logic [17:0] ctrlgamma_phy_mac_local_tx_pset_coef [0:0],
    output logic [5:0] ctrlgamma_phy_mac_localfs [0:0],
    output logic [5:0] ctrlgamma_phy_mac_locallf [0:0],
    output logic [5:0] ctrlgamma_phy_mac_dirfeedback [0:0],
    output logic [7:0] ctrlgamma_phy_mac_fomfeedback [0:0],
    output logic ctrlgamma_pclk,
    // CtrlDelta x1
    input logic ctrldelta_rst_n,
    input logic [31:0] ctrldelta_mac_phy_txdata [0:0],
    input logic [3:0] ctrldelta_mac_phy_txdatak [0:0],
    input logic [0:0] ctrldelta_mac_phy_txdatavalid [0:0],
    input logic [0:0] ctrldelta_mac_phy_txstartblock [0:0],
    input logic [1:0] ctrldelta_mac_phy_txsyncheader [0:0],
    input logic [0:0] ctrldelta_mac_phy_txdetectrx_loopback [0:0],
    input logic [0:0] ctrldelta_mac_phy_txelecidle [0:0],
    input logic [0:0] ctrldelta_mac_phy_txcompliance [0:0],
    input logic [17:0] ctrldelta_mac_phy_txdeemph [0:0],
    input logic [0:0] ctrldelta_mac_phy_rxpolarity [0:0],
    input logic [7:0] ctrldelta_mac_phy_messagebus [0:0],
    input logic [2:0] ctrldelta_mac_phy_rxpresethint [0:0],
    input logic [4:0] ctrldelta_mac_phy_local_pset_index [0:0],
    input logic [17:0] ctrldelta_mac_phy_getlocal_pset_coef [0:0],
    input logic [0:0] ctrldelta_mac_phy_invalid_req [0:0],
    input logic [0:0] ctrldelta_mac_phy_rxeqeval [0:0],
    input logic [5:0] ctrldelta_mac_phy_fs [0:0],
    input logic [5:0] ctrldelta_mac_phy_lf [0:0],
    input logic [0:0] ctrldelta_mac_phy_dirchange [0:0],
    input logic [0:0] ctrldelta_mac_phy_rxeqinprogress [0:0],
    output logic [31:0] ctrldelta_phy_mac_rxdata [0:0],
    output logic [3:0] ctrldelta_phy_mac_rxdatak [0:0],
    output logic [0:0] ctrldelta_phy_mac_rxdatavalid [0:0],
    output logic [0:0] ctrldelta_phy_mac_rxstartblock [0:0],
    output logic [1:0] ctrldelta_phy_mac_rxsyncheader [0:0],
    output logic [0:0] ctrldelta_phy_mac_rxvalid [0:0],
    output logic [2:0] ctrldelta_phy_mac_rxstatus [0:0],
    output logic [0:0] ctrldelta_phy_mac_rxelecidle [0:0],
    output logic [0:0] ctrldelta_phy_mac_rxstandbystatus [0:0],
    output logic [7:0] ctrldelta_phy_mac_messagebus [0:0],
    // phy_mac_phystatus: shared across CtrlDelta's own lanes
    output logic [0:0] ctrldelta_phy_mac_phystatus,
    output logic [0:0] ctrldelta_phy_mac_local_tx_coef_valid [0:0],
    output logic [17:0] ctrldelta_phy_mac_local_tx_pset_coef [0:0],
    output logic [5:0] ctrldelta_phy_mac_localfs [0:0],
    output logic [5:0] ctrldelta_phy_mac_locallf [0:0],
    output logic [5:0] ctrldelta_phy_mac_dirfeedback [0:0],
    output logic [7:0] ctrldelta_phy_mac_fomfeedback [0:0],
    output logic ctrldelta_pclk,
    // CtrlEpsilon x1
    input logic ctrlepsilon_rst_n,
    input logic [31:0] ctrlepsilon_mac_phy_txdata [0:0],
    input logic [3:0] ctrlepsilon_mac_phy_txdatak [0:0],
    input logic [0:0] ctrlepsilon_mac_phy_txdatavalid [0:0],
    input logic [0:0] ctrlepsilon_mac_phy_txstartblock [0:0],
    input logic [1:0] ctrlepsilon_mac_phy_txsyncheader [0:0],
    input logic [0:0] ctrlepsilon_mac_phy_txdetectrx_loopback [0:0],
    input logic [0:0] ctrlepsilon_mac_phy_txelecidle [0:0],
    input logic [0:0] ctrlepsilon_mac_phy_txcompliance [0:0],
    input logic [17:0] ctrlepsilon_mac_phy_txdeemph [0:0],
    input logic [0:0] ctrlepsilon_mac_phy_rxpolarity [0:0],
    input logic [7:0] ctrlepsilon_mac_phy_messagebus [0:0],
    input logic [2:0] ctrlepsilon_mac_phy_rxpresethint [0:0],
    input logic [4:0] ctrlepsilon_mac_phy_local_pset_index [0:0],
    input logic [17:0] ctrlepsilon_mac_phy_getlocal_pset_coef [0:0],
    input logic [0:0] ctrlepsilon_mac_phy_invalid_req [0:0],
    input logic [0:0] ctrlepsilon_mac_phy_rxeqeval [0:0],
    input logic [5:0] ctrlepsilon_mac_phy_fs [0:0],
    input logic [5:0] ctrlepsilon_mac_phy_lf [0:0],
    input logic [0:0] ctrlepsilon_mac_phy_dirchange [0:0],
    input logic [0:0] ctrlepsilon_mac_phy_rxeqinprogress [0:0],
    output logic [31:0] ctrlepsilon_phy_mac_rxdata [0:0],
    output logic [3:0] ctrlepsilon_phy_mac_rxdatak [0:0],
    output logic [0:0] ctrlepsilon_phy_mac_rxdatavalid [0:0],
    output logic [0:0] ctrlepsilon_phy_mac_rxstartblock [0:0],
    output logic [1:0] ctrlepsilon_phy_mac_rxsyncheader [0:0],
    output logic [0:0] ctrlepsilon_phy_mac_rxvalid [0:0],
    output logic [2:0] ctrlepsilon_phy_mac_rxstatus [0:0],
    output logic [0:0] ctrlepsilon_phy_mac_rxelecidle [0:0],
    output logic [0:0] ctrlepsilon_phy_mac_rxstandbystatus [0:0],
    output logic [7:0] ctrlepsilon_phy_mac_messagebus [0:0],
    // phy_mac_phystatus: shared across CtrlEpsilon's own lanes
    output logic [0:0] ctrlepsilon_phy_mac_phystatus,
    output logic [0:0] ctrlepsilon_phy_mac_local_tx_coef_valid [0:0],
    output logic [17:0] ctrlepsilon_phy_mac_local_tx_pset_coef [0:0],
    output logic [5:0] ctrlepsilon_phy_mac_localfs [0:0],
    output logic [5:0] ctrlepsilon_phy_mac_locallf [0:0],
    output logic [5:0] ctrlepsilon_phy_mac_dirfeedback [0:0],
    output logic [7:0] ctrlepsilon_phy_mac_fomfeedback [0:0],
    output logic ctrlepsilon_pclk,
    // CtrlZeta x1
    input logic ctrlzeta_rst_n,
    input logic [31:0] ctrlzeta_mac_phy_txdata [0:0],
    input logic [3:0] ctrlzeta_mac_phy_txdatak [0:0],
    input logic [0:0] ctrlzeta_mac_phy_txdatavalid [0:0],
    input logic [0:0] ctrlzeta_mac_phy_txstartblock [0:0],
    input logic [1:0] ctrlzeta_mac_phy_txsyncheader [0:0],
    input logic [0:0] ctrlzeta_mac_phy_txdetectrx_loopback [0:0],
    input logic [0:0] ctrlzeta_mac_phy_txelecidle [0:0],
    input logic [0:0] ctrlzeta_mac_phy_txcompliance [0:0],
    input logic [17:0] ctrlzeta_mac_phy_txdeemph [0:0],
    input logic [0:0] ctrlzeta_mac_phy_rxpolarity [0:0],
    input logic [7:0] ctrlzeta_mac_phy_messagebus [0:0],
    input logic [2:0] ctrlzeta_mac_phy_rxpresethint [0:0],
    input logic [4:0] ctrlzeta_mac_phy_local_pset_index [0:0],
    input logic [17:0] ctrlzeta_mac_phy_getlocal_pset_coef [0:0],
    input logic [0:0] ctrlzeta_mac_phy_invalid_req [0:0],
    input logic [0:0] ctrlzeta_mac_phy_rxeqeval [0:0],
    input logic [5:0] ctrlzeta_mac_phy_fs [0:0],
    input logic [5:0] ctrlzeta_mac_phy_lf [0:0],
    input logic [0:0] ctrlzeta_mac_phy_dirchange [0:0],
    input logic [0:0] ctrlzeta_mac_phy_rxeqinprogress [0:0],
    output logic [31:0] ctrlzeta_phy_mac_rxdata [0:0],
    output logic [3:0] ctrlzeta_phy_mac_rxdatak [0:0],
    output logic [0:0] ctrlzeta_phy_mac_rxdatavalid [0:0],
    output logic [0:0] ctrlzeta_phy_mac_rxstartblock [0:0],
    output logic [1:0] ctrlzeta_phy_mac_rxsyncheader [0:0],
    output logic [0:0] ctrlzeta_phy_mac_rxvalid [0:0],
    output logic [2:0] ctrlzeta_phy_mac_rxstatus [0:0],
    output logic [0:0] ctrlzeta_phy_mac_rxelecidle [0:0],
    output logic [0:0] ctrlzeta_phy_mac_rxstandbystatus [0:0],
    output logic [7:0] ctrlzeta_phy_mac_messagebus [0:0],
    // phy_mac_phystatus: shared across CtrlZeta's own lanes
    output logic [0:0] ctrlzeta_phy_mac_phystatus,
    output logic [0:0] ctrlzeta_phy_mac_local_tx_coef_valid [0:0],
    output logic [17:0] ctrlzeta_phy_mac_local_tx_pset_coef [0:0],
    output logic [5:0] ctrlzeta_phy_mac_localfs [0:0],
    output logic [5:0] ctrlzeta_phy_mac_locallf [0:0],
    output logic [5:0] ctrlzeta_phy_mac_dirfeedback [0:0],
    output logic [7:0] ctrlzeta_phy_mac_fomfeedback [0:0],
    output logic ctrlzeta_pclk
);

    mac2phy_lane_t [NL-1:0] w_phy_mac2phy;
    phy2mac_lane_t [NL-1:0] w_phy_phy2mac;
    mac2phy_lane_t [2:0] w_ctrlalpha_mac2phy;
    phy2mac_lane_t [2:0] w_ctrlalpha_phy2mac;
    mac2phy_lane_t [1:0] w_ctrlbeta_mac2phy;
    phy2mac_lane_t [1:0] w_ctrlbeta_phy2mac;
    mac2phy_lane_t [0:0] w_ctrlgamma_mac2phy;
    phy2mac_lane_t [0:0] w_ctrlgamma_phy2mac;
    mac2phy_lane_t [0:0] w_ctrldelta_mac2phy;
    phy2mac_lane_t [0:0] w_ctrldelta_phy2mac;
    mac2phy_lane_t [0:0] w_ctrlepsilon_mac2phy;
    phy2mac_lane_t [0:0] w_ctrlepsilon_phy2mac;
    mac2phy_lane_t [0:0] w_ctrlzeta_mac2phy;
    phy2mac_lane_t [0:0] w_ctrlzeta_phy2mac;

    //------------------------------------------------------------
    // PHY side (always per-lane)
    //------------------------------------------------------------
    assign phy_mac_phy_txdata[0] = w_phy_mac2phy[0].mac_phy_txdata;
    assign phy_mac_phy_txdatak[0] = w_phy_mac2phy[0].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[0] = w_phy_mac2phy[0].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[0] = w_phy_mac2phy[0].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[0] = w_phy_mac2phy[0].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[0] = w_phy_mac2phy[0].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[0] = w_phy_mac2phy[0].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[0] = w_phy_mac2phy[0].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[0] = w_phy_mac2phy[0].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[0] = w_phy_mac2phy[0].mac_phy_rxpolarity;
    assign phy_mac_phy_messagebus[0] = w_phy_mac2phy[0].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[0] = w_phy_mac2phy[0].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[0] = w_phy_mac2phy[0].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[0] = w_phy_mac2phy[0].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[0] = w_phy_mac2phy[0].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[0] = w_phy_mac2phy[0].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[0] = w_phy_mac2phy[0].mac_phy_fs;
    assign phy_mac_phy_lf[0] = w_phy_mac2phy[0].mac_phy_lf;
    assign phy_mac_phy_dirchange[0] = w_phy_mac2phy[0].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[0] = w_phy_mac2phy[0].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[1] = w_phy_mac2phy[1].mac_phy_txdata;
    assign phy_mac_phy_txdatak[1] = w_phy_mac2phy[1].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[1] = w_phy_mac2phy[1].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[1] = w_phy_mac2phy[1].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[1] = w_phy_mac2phy[1].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[1] = w_phy_mac2phy[1].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[1] = w_phy_mac2phy[1].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[1] = w_phy_mac2phy[1].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[1] = w_phy_mac2phy[1].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[1] = w_phy_mac2phy[1].mac_phy_rxpolarity;
    assign phy_mac_phy_messagebus[1] = w_phy_mac2phy[1].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[1] = w_phy_mac2phy[1].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[1] = w_phy_mac2phy[1].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[1] = w_phy_mac2phy[1].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[1] = w_phy_mac2phy[1].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[1] = w_phy_mac2phy[1].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[1] = w_phy_mac2phy[1].mac_phy_fs;
    assign phy_mac_phy_lf[1] = w_phy_mac2phy[1].mac_phy_lf;
    assign phy_mac_phy_dirchange[1] = w_phy_mac2phy[1].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[1] = w_phy_mac2phy[1].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[2] = w_phy_mac2phy[2].mac_phy_txdata;
    assign phy_mac_phy_txdatak[2] = w_phy_mac2phy[2].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[2] = w_phy_mac2phy[2].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[2] = w_phy_mac2phy[2].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[2] = w_phy_mac2phy[2].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[2] = w_phy_mac2phy[2].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[2] = w_phy_mac2phy[2].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[2] = w_phy_mac2phy[2].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[2] = w_phy_mac2phy[2].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[2] = w_phy_mac2phy[2].mac_phy_rxpolarity;
    assign phy_mac_phy_messagebus[2] = w_phy_mac2phy[2].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[2] = w_phy_mac2phy[2].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[2] = w_phy_mac2phy[2].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[2] = w_phy_mac2phy[2].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[2] = w_phy_mac2phy[2].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[2] = w_phy_mac2phy[2].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[2] = w_phy_mac2phy[2].mac_phy_fs;
    assign phy_mac_phy_lf[2] = w_phy_mac2phy[2].mac_phy_lf;
    assign phy_mac_phy_dirchange[2] = w_phy_mac2phy[2].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[2] = w_phy_mac2phy[2].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[3] = w_phy_mac2phy[3].mac_phy_txdata;
    assign phy_mac_phy_txdatak[3] = w_phy_mac2phy[3].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[3] = w_phy_mac2phy[3].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[3] = w_phy_mac2phy[3].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[3] = w_phy_mac2phy[3].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[3] = w_phy_mac2phy[3].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[3] = w_phy_mac2phy[3].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[3] = w_phy_mac2phy[3].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[3] = w_phy_mac2phy[3].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[3] = w_phy_mac2phy[3].mac_phy_rxpolarity;
    assign phy_mac_phy_messagebus[3] = w_phy_mac2phy[3].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[3] = w_phy_mac2phy[3].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[3] = w_phy_mac2phy[3].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[3] = w_phy_mac2phy[3].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[3] = w_phy_mac2phy[3].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[3] = w_phy_mac2phy[3].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[3] = w_phy_mac2phy[3].mac_phy_fs;
    assign phy_mac_phy_lf[3] = w_phy_mac2phy[3].mac_phy_lf;
    assign phy_mac_phy_dirchange[3] = w_phy_mac2phy[3].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[3] = w_phy_mac2phy[3].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[4] = w_phy_mac2phy[4].mac_phy_txdata;
    assign phy_mac_phy_txdatak[4] = w_phy_mac2phy[4].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[4] = w_phy_mac2phy[4].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[4] = w_phy_mac2phy[4].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[4] = w_phy_mac2phy[4].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[4] = w_phy_mac2phy[4].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[4] = w_phy_mac2phy[4].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[4] = w_phy_mac2phy[4].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[4] = w_phy_mac2phy[4].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[4] = w_phy_mac2phy[4].mac_phy_rxpolarity;
    assign phy_mac_phy_messagebus[4] = w_phy_mac2phy[4].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[4] = w_phy_mac2phy[4].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[4] = w_phy_mac2phy[4].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[4] = w_phy_mac2phy[4].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[4] = w_phy_mac2phy[4].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[4] = w_phy_mac2phy[4].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[4] = w_phy_mac2phy[4].mac_phy_fs;
    assign phy_mac_phy_lf[4] = w_phy_mac2phy[4].mac_phy_lf;
    assign phy_mac_phy_dirchange[4] = w_phy_mac2phy[4].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[4] = w_phy_mac2phy[4].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[5] = w_phy_mac2phy[5].mac_phy_txdata;
    assign phy_mac_phy_txdatak[5] = w_phy_mac2phy[5].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[5] = w_phy_mac2phy[5].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[5] = w_phy_mac2phy[5].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[5] = w_phy_mac2phy[5].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[5] = w_phy_mac2phy[5].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[5] = w_phy_mac2phy[5].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[5] = w_phy_mac2phy[5].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[5] = w_phy_mac2phy[5].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[5] = w_phy_mac2phy[5].mac_phy_rxpolarity;
    assign phy_mac_phy_messagebus[5] = w_phy_mac2phy[5].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[5] = w_phy_mac2phy[5].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[5] = w_phy_mac2phy[5].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[5] = w_phy_mac2phy[5].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[5] = w_phy_mac2phy[5].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[5] = w_phy_mac2phy[5].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[5] = w_phy_mac2phy[5].mac_phy_fs;
    assign phy_mac_phy_lf[5] = w_phy_mac2phy[5].mac_phy_lf;
    assign phy_mac_phy_dirchange[5] = w_phy_mac2phy[5].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[5] = w_phy_mac2phy[5].mac_phy_rxeqinprogress;
    assign w_phy_phy2mac[0] = '{phy_mac_rxdata: phy_phy_mac_rxdata[0], phy_mac_rxdatak: phy_phy_mac_rxdatak[0], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[0], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[0], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[0], phy_mac_rxvalid: phy_phy_mac_rxvalid[0], phy_mac_rxstatus: phy_phy_mac_rxstatus[0], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[0], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[0], phy_mac_messagebus: phy_phy_mac_messagebus[0], phy_mac_phystatus: phy_phy_mac_phystatus[0], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[0], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[0], phy_mac_localfs: phy_phy_mac_localfs[0], phy_mac_locallf: phy_phy_mac_locallf[0], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[0], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[0]};
    assign w_phy_phy2mac[1] = '{phy_mac_rxdata: phy_phy_mac_rxdata[1], phy_mac_rxdatak: phy_phy_mac_rxdatak[1], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[1], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[1], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[1], phy_mac_rxvalid: phy_phy_mac_rxvalid[1], phy_mac_rxstatus: phy_phy_mac_rxstatus[1], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[1], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[1], phy_mac_messagebus: phy_phy_mac_messagebus[1], phy_mac_phystatus: phy_phy_mac_phystatus[1], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[1], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[1], phy_mac_localfs: phy_phy_mac_localfs[1], phy_mac_locallf: phy_phy_mac_locallf[1], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[1], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[1]};
    assign w_phy_phy2mac[2] = '{phy_mac_rxdata: phy_phy_mac_rxdata[2], phy_mac_rxdatak: phy_phy_mac_rxdatak[2], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[2], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[2], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[2], phy_mac_rxvalid: phy_phy_mac_rxvalid[2], phy_mac_rxstatus: phy_phy_mac_rxstatus[2], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[2], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[2], phy_mac_messagebus: phy_phy_mac_messagebus[2], phy_mac_phystatus: phy_phy_mac_phystatus[2], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[2], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[2], phy_mac_localfs: phy_phy_mac_localfs[2], phy_mac_locallf: phy_phy_mac_locallf[2], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[2], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[2]};
    assign w_phy_phy2mac[3] = '{phy_mac_rxdata: phy_phy_mac_rxdata[3], phy_mac_rxdatak: phy_phy_mac_rxdatak[3], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[3], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[3], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[3], phy_mac_rxvalid: phy_phy_mac_rxvalid[3], phy_mac_rxstatus: phy_phy_mac_rxstatus[3], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[3], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[3], phy_mac_messagebus: phy_phy_mac_messagebus[3], phy_mac_phystatus: phy_phy_mac_phystatus[3], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[3], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[3], phy_mac_localfs: phy_phy_mac_localfs[3], phy_mac_locallf: phy_phy_mac_locallf[3], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[3], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[3]};
    assign w_phy_phy2mac[4] = '{phy_mac_rxdata: phy_phy_mac_rxdata[4], phy_mac_rxdatak: phy_phy_mac_rxdatak[4], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[4], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[4], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[4], phy_mac_rxvalid: phy_phy_mac_rxvalid[4], phy_mac_rxstatus: phy_phy_mac_rxstatus[4], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[4], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[4], phy_mac_messagebus: phy_phy_mac_messagebus[4], phy_mac_phystatus: phy_phy_mac_phystatus[4], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[4], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[4], phy_mac_localfs: phy_phy_mac_localfs[4], phy_mac_locallf: phy_phy_mac_locallf[4], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[4], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[4]};
    assign w_phy_phy2mac[5] = '{phy_mac_rxdata: phy_phy_mac_rxdata[5], phy_mac_rxdatak: phy_phy_mac_rxdatak[5], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[5], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[5], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[5], phy_mac_rxvalid: phy_phy_mac_rxvalid[5], phy_mac_rxstatus: phy_phy_mac_rxstatus[5], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[5], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[5], phy_mac_messagebus: phy_phy_mac_messagebus[5], phy_mac_phystatus: phy_phy_mac_phystatus[5], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[5], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[5], phy_mac_localfs: phy_phy_mac_localfs[5], phy_mac_locallf: phy_phy_mac_locallf[5], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[5], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[5]};

    //------------------------------------------------------------
    // CtrlAlpha (x3)
    //------------------------------------------------------------
    assign w_ctrlalpha_mac2phy[0] = '{mac_phy_txdata: ctrlalpha_mac_phy_txdata[0], mac_phy_txdatak: ctrlalpha_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrlalpha_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrlalpha_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrlalpha_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrlalpha_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrlalpha_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrlalpha_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrlalpha_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrlalpha_mac_phy_rxpolarity[0], mac_phy_messagebus: ctrlalpha_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrlalpha_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrlalpha_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrlalpha_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrlalpha_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrlalpha_mac_phy_rxeqeval[0], mac_phy_fs: ctrlalpha_mac_phy_fs[0], mac_phy_lf: ctrlalpha_mac_phy_lf[0], mac_phy_dirchange: ctrlalpha_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrlalpha_mac_phy_rxeqinprogress[0]};
    assign w_ctrlalpha_mac2phy[1] = '{mac_phy_txdata: ctrlalpha_mac_phy_txdata[1], mac_phy_txdatak: ctrlalpha_mac_phy_txdatak[1], mac_phy_txdatavalid: ctrlalpha_mac_phy_txdatavalid[1], mac_phy_txstartblock: ctrlalpha_mac_phy_txstartblock[1], mac_phy_txsyncheader: ctrlalpha_mac_phy_txsyncheader[1], mac_phy_txdetectrx_loopback: ctrlalpha_mac_phy_txdetectrx_loopback[1], mac_phy_txelecidle: ctrlalpha_mac_phy_txelecidle[1], mac_phy_txcompliance: ctrlalpha_mac_phy_txcompliance[1], mac_phy_txdeemph: ctrlalpha_mac_phy_txdeemph[1], mac_phy_rxpolarity: ctrlalpha_mac_phy_rxpolarity[1], mac_phy_messagebus: ctrlalpha_mac_phy_messagebus[1], mac_phy_rxpresethint: ctrlalpha_mac_phy_rxpresethint[1], mac_phy_local_pset_index: ctrlalpha_mac_phy_local_pset_index[1], mac_phy_getlocal_pset_coef: ctrlalpha_mac_phy_getlocal_pset_coef[1], mac_phy_invalid_req: ctrlalpha_mac_phy_invalid_req[1], mac_phy_rxeqeval: ctrlalpha_mac_phy_rxeqeval[1], mac_phy_fs: ctrlalpha_mac_phy_fs[1], mac_phy_lf: ctrlalpha_mac_phy_lf[1], mac_phy_dirchange: ctrlalpha_mac_phy_dirchange[1], mac_phy_rxeqinprogress: ctrlalpha_mac_phy_rxeqinprogress[1]};
    assign w_ctrlalpha_mac2phy[2] = '{mac_phy_txdata: ctrlalpha_mac_phy_txdata[2], mac_phy_txdatak: ctrlalpha_mac_phy_txdatak[2], mac_phy_txdatavalid: ctrlalpha_mac_phy_txdatavalid[2], mac_phy_txstartblock: ctrlalpha_mac_phy_txstartblock[2], mac_phy_txsyncheader: ctrlalpha_mac_phy_txsyncheader[2], mac_phy_txdetectrx_loopback: ctrlalpha_mac_phy_txdetectrx_loopback[2], mac_phy_txelecidle: ctrlalpha_mac_phy_txelecidle[2], mac_phy_txcompliance: ctrlalpha_mac_phy_txcompliance[2], mac_phy_txdeemph: ctrlalpha_mac_phy_txdeemph[2], mac_phy_rxpolarity: ctrlalpha_mac_phy_rxpolarity[2], mac_phy_messagebus: ctrlalpha_mac_phy_messagebus[2], mac_phy_rxpresethint: ctrlalpha_mac_phy_rxpresethint[2], mac_phy_local_pset_index: ctrlalpha_mac_phy_local_pset_index[2], mac_phy_getlocal_pset_coef: ctrlalpha_mac_phy_getlocal_pset_coef[2], mac_phy_invalid_req: ctrlalpha_mac_phy_invalid_req[2], mac_phy_rxeqeval: ctrlalpha_mac_phy_rxeqeval[2], mac_phy_fs: ctrlalpha_mac_phy_fs[2], mac_phy_lf: ctrlalpha_mac_phy_lf[2], mac_phy_dirchange: ctrlalpha_mac_phy_dirchange[2], mac_phy_rxeqinprogress: ctrlalpha_mac_phy_rxeqinprogress[2]};
    assign ctrlalpha_phy_mac_rxdata[0] = w_ctrlalpha_phy2mac[0].phy_mac_rxdata;
    assign ctrlalpha_phy_mac_rxdata[1] = w_ctrlalpha_phy2mac[1].phy_mac_rxdata;
    assign ctrlalpha_phy_mac_rxdata[2] = w_ctrlalpha_phy2mac[2].phy_mac_rxdata;
    assign ctrlalpha_phy_mac_rxdatak[0] = w_ctrlalpha_phy2mac[0].phy_mac_rxdatak;
    assign ctrlalpha_phy_mac_rxdatak[1] = w_ctrlalpha_phy2mac[1].phy_mac_rxdatak;
    assign ctrlalpha_phy_mac_rxdatak[2] = w_ctrlalpha_phy2mac[2].phy_mac_rxdatak;
    assign ctrlalpha_phy_mac_rxdatavalid[0] = w_ctrlalpha_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrlalpha_phy_mac_rxdatavalid[1] = w_ctrlalpha_phy2mac[1].phy_mac_rxdatavalid;
    assign ctrlalpha_phy_mac_rxdatavalid[2] = w_ctrlalpha_phy2mac[2].phy_mac_rxdatavalid;
    assign ctrlalpha_phy_mac_rxstartblock[0] = w_ctrlalpha_phy2mac[0].phy_mac_rxstartblock;
    assign ctrlalpha_phy_mac_rxstartblock[1] = w_ctrlalpha_phy2mac[1].phy_mac_rxstartblock;
    assign ctrlalpha_phy_mac_rxstartblock[2] = w_ctrlalpha_phy2mac[2].phy_mac_rxstartblock;
    assign ctrlalpha_phy_mac_rxsyncheader[0] = w_ctrlalpha_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrlalpha_phy_mac_rxsyncheader[1] = w_ctrlalpha_phy2mac[1].phy_mac_rxsyncheader;
    assign ctrlalpha_phy_mac_rxsyncheader[2] = w_ctrlalpha_phy2mac[2].phy_mac_rxsyncheader;
    assign ctrlalpha_phy_mac_rxvalid[0] = w_ctrlalpha_phy2mac[0].phy_mac_rxvalid;
    assign ctrlalpha_phy_mac_rxvalid[1] = w_ctrlalpha_phy2mac[1].phy_mac_rxvalid;
    assign ctrlalpha_phy_mac_rxvalid[2] = w_ctrlalpha_phy2mac[2].phy_mac_rxvalid;
    assign ctrlalpha_phy_mac_rxstatus[0] = w_ctrlalpha_phy2mac[0].phy_mac_rxstatus;
    assign ctrlalpha_phy_mac_rxstatus[1] = w_ctrlalpha_phy2mac[1].phy_mac_rxstatus;
    assign ctrlalpha_phy_mac_rxstatus[2] = w_ctrlalpha_phy2mac[2].phy_mac_rxstatus;
    assign ctrlalpha_phy_mac_rxelecidle[0] = w_ctrlalpha_phy2mac[0].phy_mac_rxelecidle;
    assign ctrlalpha_phy_mac_rxelecidle[1] = w_ctrlalpha_phy2mac[1].phy_mac_rxelecidle;
    assign ctrlalpha_phy_mac_rxelecidle[2] = w_ctrlalpha_phy2mac[2].phy_mac_rxelecidle;
    assign ctrlalpha_phy_mac_rxstandbystatus[0] = w_ctrlalpha_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrlalpha_phy_mac_rxstandbystatus[1] = w_ctrlalpha_phy2mac[1].phy_mac_rxstandbystatus;
    assign ctrlalpha_phy_mac_rxstandbystatus[2] = w_ctrlalpha_phy2mac[2].phy_mac_rxstandbystatus;
    assign ctrlalpha_phy_mac_messagebus[0] = w_ctrlalpha_phy2mac[0].phy_mac_messagebus;
    assign ctrlalpha_phy_mac_messagebus[1] = w_ctrlalpha_phy2mac[1].phy_mac_messagebus;
    assign ctrlalpha_phy_mac_messagebus[2] = w_ctrlalpha_phy2mac[2].phy_mac_messagebus;
    assign ctrlalpha_phy_mac_phystatus = w_ctrlalpha_phy2mac[0].phy_mac_phystatus;
    assign ctrlalpha_phy_mac_local_tx_coef_valid[0] = w_ctrlalpha_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrlalpha_phy_mac_local_tx_coef_valid[1] = w_ctrlalpha_phy2mac[1].phy_mac_local_tx_coef_valid;
    assign ctrlalpha_phy_mac_local_tx_coef_valid[2] = w_ctrlalpha_phy2mac[2].phy_mac_local_tx_coef_valid;
    assign ctrlalpha_phy_mac_local_tx_pset_coef[0] = w_ctrlalpha_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrlalpha_phy_mac_local_tx_pset_coef[1] = w_ctrlalpha_phy2mac[1].phy_mac_local_tx_pset_coef;
    assign ctrlalpha_phy_mac_local_tx_pset_coef[2] = w_ctrlalpha_phy2mac[2].phy_mac_local_tx_pset_coef;
    assign ctrlalpha_phy_mac_localfs[0] = w_ctrlalpha_phy2mac[0].phy_mac_localfs;
    assign ctrlalpha_phy_mac_localfs[1] = w_ctrlalpha_phy2mac[1].phy_mac_localfs;
    assign ctrlalpha_phy_mac_localfs[2] = w_ctrlalpha_phy2mac[2].phy_mac_localfs;
    assign ctrlalpha_phy_mac_locallf[0] = w_ctrlalpha_phy2mac[0].phy_mac_locallf;
    assign ctrlalpha_phy_mac_locallf[1] = w_ctrlalpha_phy2mac[1].phy_mac_locallf;
    assign ctrlalpha_phy_mac_locallf[2] = w_ctrlalpha_phy2mac[2].phy_mac_locallf;
    assign ctrlalpha_phy_mac_dirfeedback[0] = w_ctrlalpha_phy2mac[0].phy_mac_dirfeedback;
    assign ctrlalpha_phy_mac_dirfeedback[1] = w_ctrlalpha_phy2mac[1].phy_mac_dirfeedback;
    assign ctrlalpha_phy_mac_dirfeedback[2] = w_ctrlalpha_phy2mac[2].phy_mac_dirfeedback;
    assign ctrlalpha_phy_mac_fomfeedback[0] = w_ctrlalpha_phy2mac[0].phy_mac_fomfeedback;
    assign ctrlalpha_phy_mac_fomfeedback[1] = w_ctrlalpha_phy2mac[1].phy_mac_fomfeedback;
    assign ctrlalpha_phy_mac_fomfeedback[2] = w_ctrlalpha_phy2mac[2].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // CtrlBeta (x2)
    //------------------------------------------------------------
    assign w_ctrlbeta_mac2phy[0] = '{mac_phy_txdata: ctrlbeta_mac_phy_txdata[0], mac_phy_txdatak: ctrlbeta_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrlbeta_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrlbeta_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrlbeta_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrlbeta_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrlbeta_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrlbeta_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrlbeta_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrlbeta_mac_phy_rxpolarity[0], mac_phy_messagebus: ctrlbeta_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrlbeta_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrlbeta_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrlbeta_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrlbeta_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrlbeta_mac_phy_rxeqeval[0], mac_phy_fs: ctrlbeta_mac_phy_fs[0], mac_phy_lf: ctrlbeta_mac_phy_lf[0], mac_phy_dirchange: ctrlbeta_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrlbeta_mac_phy_rxeqinprogress[0]};
    assign w_ctrlbeta_mac2phy[1] = '{mac_phy_txdata: ctrlbeta_mac_phy_txdata[1], mac_phy_txdatak: ctrlbeta_mac_phy_txdatak[1], mac_phy_txdatavalid: ctrlbeta_mac_phy_txdatavalid[1], mac_phy_txstartblock: ctrlbeta_mac_phy_txstartblock[1], mac_phy_txsyncheader: ctrlbeta_mac_phy_txsyncheader[1], mac_phy_txdetectrx_loopback: ctrlbeta_mac_phy_txdetectrx_loopback[1], mac_phy_txelecidle: ctrlbeta_mac_phy_txelecidle[1], mac_phy_txcompliance: ctrlbeta_mac_phy_txcompliance[1], mac_phy_txdeemph: ctrlbeta_mac_phy_txdeemph[1], mac_phy_rxpolarity: ctrlbeta_mac_phy_rxpolarity[1], mac_phy_messagebus: ctrlbeta_mac_phy_messagebus[1], mac_phy_rxpresethint: ctrlbeta_mac_phy_rxpresethint[1], mac_phy_local_pset_index: ctrlbeta_mac_phy_local_pset_index[1], mac_phy_getlocal_pset_coef: ctrlbeta_mac_phy_getlocal_pset_coef[1], mac_phy_invalid_req: ctrlbeta_mac_phy_invalid_req[1], mac_phy_rxeqeval: ctrlbeta_mac_phy_rxeqeval[1], mac_phy_fs: ctrlbeta_mac_phy_fs[1], mac_phy_lf: ctrlbeta_mac_phy_lf[1], mac_phy_dirchange: ctrlbeta_mac_phy_dirchange[1], mac_phy_rxeqinprogress: ctrlbeta_mac_phy_rxeqinprogress[1]};
    assign ctrlbeta_phy_mac_rxdata[0] = w_ctrlbeta_phy2mac[0].phy_mac_rxdata;
    assign ctrlbeta_phy_mac_rxdata[1] = w_ctrlbeta_phy2mac[1].phy_mac_rxdata;
    assign ctrlbeta_phy_mac_rxdatak[0] = w_ctrlbeta_phy2mac[0].phy_mac_rxdatak;
    assign ctrlbeta_phy_mac_rxdatak[1] = w_ctrlbeta_phy2mac[1].phy_mac_rxdatak;
    assign ctrlbeta_phy_mac_rxdatavalid[0] = w_ctrlbeta_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrlbeta_phy_mac_rxdatavalid[1] = w_ctrlbeta_phy2mac[1].phy_mac_rxdatavalid;
    assign ctrlbeta_phy_mac_rxstartblock[0] = w_ctrlbeta_phy2mac[0].phy_mac_rxstartblock;
    assign ctrlbeta_phy_mac_rxstartblock[1] = w_ctrlbeta_phy2mac[1].phy_mac_rxstartblock;
    assign ctrlbeta_phy_mac_rxsyncheader[0] = w_ctrlbeta_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrlbeta_phy_mac_rxsyncheader[1] = w_ctrlbeta_phy2mac[1].phy_mac_rxsyncheader;
    assign ctrlbeta_phy_mac_rxvalid[0] = w_ctrlbeta_phy2mac[0].phy_mac_rxvalid;
    assign ctrlbeta_phy_mac_rxvalid[1] = w_ctrlbeta_phy2mac[1].phy_mac_rxvalid;
    assign ctrlbeta_phy_mac_rxstatus[0] = w_ctrlbeta_phy2mac[0].phy_mac_rxstatus;
    assign ctrlbeta_phy_mac_rxstatus[1] = w_ctrlbeta_phy2mac[1].phy_mac_rxstatus;
    assign ctrlbeta_phy_mac_rxelecidle[0] = w_ctrlbeta_phy2mac[0].phy_mac_rxelecidle;
    assign ctrlbeta_phy_mac_rxelecidle[1] = w_ctrlbeta_phy2mac[1].phy_mac_rxelecidle;
    assign ctrlbeta_phy_mac_rxstandbystatus[0] = w_ctrlbeta_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrlbeta_phy_mac_rxstandbystatus[1] = w_ctrlbeta_phy2mac[1].phy_mac_rxstandbystatus;
    assign ctrlbeta_phy_mac_messagebus[0] = w_ctrlbeta_phy2mac[0].phy_mac_messagebus;
    assign ctrlbeta_phy_mac_messagebus[1] = w_ctrlbeta_phy2mac[1].phy_mac_messagebus;
    assign ctrlbeta_phy_mac_phystatus = w_ctrlbeta_phy2mac[0].phy_mac_phystatus;
    assign ctrlbeta_phy_mac_local_tx_coef_valid[0] = w_ctrlbeta_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrlbeta_phy_mac_local_tx_coef_valid[1] = w_ctrlbeta_phy2mac[1].phy_mac_local_tx_coef_valid;
    assign ctrlbeta_phy_mac_local_tx_pset_coef[0] = w_ctrlbeta_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrlbeta_phy_mac_local_tx_pset_coef[1] = w_ctrlbeta_phy2mac[1].phy_mac_local_tx_pset_coef;
    assign ctrlbeta_phy_mac_localfs[0] = w_ctrlbeta_phy2mac[0].phy_mac_localfs;
    assign ctrlbeta_phy_mac_localfs[1] = w_ctrlbeta_phy2mac[1].phy_mac_localfs;
    assign ctrlbeta_phy_mac_locallf[0] = w_ctrlbeta_phy2mac[0].phy_mac_locallf;
    assign ctrlbeta_phy_mac_locallf[1] = w_ctrlbeta_phy2mac[1].phy_mac_locallf;
    assign ctrlbeta_phy_mac_dirfeedback[0] = w_ctrlbeta_phy2mac[0].phy_mac_dirfeedback;
    assign ctrlbeta_phy_mac_dirfeedback[1] = w_ctrlbeta_phy2mac[1].phy_mac_dirfeedback;
    assign ctrlbeta_phy_mac_fomfeedback[0] = w_ctrlbeta_phy2mac[0].phy_mac_fomfeedback;
    assign ctrlbeta_phy_mac_fomfeedback[1] = w_ctrlbeta_phy2mac[1].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // CtrlGamma (x1)
    //------------------------------------------------------------
    assign w_ctrlgamma_mac2phy[0] = '{mac_phy_txdata: ctrlgamma_mac_phy_txdata[0], mac_phy_txdatak: ctrlgamma_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrlgamma_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrlgamma_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrlgamma_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrlgamma_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrlgamma_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrlgamma_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrlgamma_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrlgamma_mac_phy_rxpolarity[0], mac_phy_messagebus: ctrlgamma_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrlgamma_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrlgamma_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrlgamma_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrlgamma_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrlgamma_mac_phy_rxeqeval[0], mac_phy_fs: ctrlgamma_mac_phy_fs[0], mac_phy_lf: ctrlgamma_mac_phy_lf[0], mac_phy_dirchange: ctrlgamma_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrlgamma_mac_phy_rxeqinprogress[0]};
    assign ctrlgamma_phy_mac_rxdata[0] = w_ctrlgamma_phy2mac[0].phy_mac_rxdata;
    assign ctrlgamma_phy_mac_rxdatak[0] = w_ctrlgamma_phy2mac[0].phy_mac_rxdatak;
    assign ctrlgamma_phy_mac_rxdatavalid[0] = w_ctrlgamma_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrlgamma_phy_mac_rxstartblock[0] = w_ctrlgamma_phy2mac[0].phy_mac_rxstartblock;
    assign ctrlgamma_phy_mac_rxsyncheader[0] = w_ctrlgamma_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrlgamma_phy_mac_rxvalid[0] = w_ctrlgamma_phy2mac[0].phy_mac_rxvalid;
    assign ctrlgamma_phy_mac_rxstatus[0] = w_ctrlgamma_phy2mac[0].phy_mac_rxstatus;
    assign ctrlgamma_phy_mac_rxelecidle[0] = w_ctrlgamma_phy2mac[0].phy_mac_rxelecidle;
    assign ctrlgamma_phy_mac_rxstandbystatus[0] = w_ctrlgamma_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrlgamma_phy_mac_messagebus[0] = w_ctrlgamma_phy2mac[0].phy_mac_messagebus;
    assign ctrlgamma_phy_mac_phystatus = w_ctrlgamma_phy2mac[0].phy_mac_phystatus;
    assign ctrlgamma_phy_mac_local_tx_coef_valid[0] = w_ctrlgamma_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrlgamma_phy_mac_local_tx_pset_coef[0] = w_ctrlgamma_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrlgamma_phy_mac_localfs[0] = w_ctrlgamma_phy2mac[0].phy_mac_localfs;
    assign ctrlgamma_phy_mac_locallf[0] = w_ctrlgamma_phy2mac[0].phy_mac_locallf;
    assign ctrlgamma_phy_mac_dirfeedback[0] = w_ctrlgamma_phy2mac[0].phy_mac_dirfeedback;
    assign ctrlgamma_phy_mac_fomfeedback[0] = w_ctrlgamma_phy2mac[0].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // CtrlDelta (x1)
    //------------------------------------------------------------
    assign w_ctrldelta_mac2phy[0] = '{mac_phy_txdata: ctrldelta_mac_phy_txdata[0], mac_phy_txdatak: ctrldelta_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrldelta_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrldelta_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrldelta_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrldelta_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrldelta_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrldelta_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrldelta_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrldelta_mac_phy_rxpolarity[0], mac_phy_messagebus: ctrldelta_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrldelta_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrldelta_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrldelta_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrldelta_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrldelta_mac_phy_rxeqeval[0], mac_phy_fs: ctrldelta_mac_phy_fs[0], mac_phy_lf: ctrldelta_mac_phy_lf[0], mac_phy_dirchange: ctrldelta_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrldelta_mac_phy_rxeqinprogress[0]};
    assign ctrldelta_phy_mac_rxdata[0] = w_ctrldelta_phy2mac[0].phy_mac_rxdata;
    assign ctrldelta_phy_mac_rxdatak[0] = w_ctrldelta_phy2mac[0].phy_mac_rxdatak;
    assign ctrldelta_phy_mac_rxdatavalid[0] = w_ctrldelta_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrldelta_phy_mac_rxstartblock[0] = w_ctrldelta_phy2mac[0].phy_mac_rxstartblock;
    assign ctrldelta_phy_mac_rxsyncheader[0] = w_ctrldelta_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrldelta_phy_mac_rxvalid[0] = w_ctrldelta_phy2mac[0].phy_mac_rxvalid;
    assign ctrldelta_phy_mac_rxstatus[0] = w_ctrldelta_phy2mac[0].phy_mac_rxstatus;
    assign ctrldelta_phy_mac_rxelecidle[0] = w_ctrldelta_phy2mac[0].phy_mac_rxelecidle;
    assign ctrldelta_phy_mac_rxstandbystatus[0] = w_ctrldelta_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrldelta_phy_mac_messagebus[0] = w_ctrldelta_phy2mac[0].phy_mac_messagebus;
    assign ctrldelta_phy_mac_phystatus = w_ctrldelta_phy2mac[0].phy_mac_phystatus;
    assign ctrldelta_phy_mac_local_tx_coef_valid[0] = w_ctrldelta_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrldelta_phy_mac_local_tx_pset_coef[0] = w_ctrldelta_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrldelta_phy_mac_localfs[0] = w_ctrldelta_phy2mac[0].phy_mac_localfs;
    assign ctrldelta_phy_mac_locallf[0] = w_ctrldelta_phy2mac[0].phy_mac_locallf;
    assign ctrldelta_phy_mac_dirfeedback[0] = w_ctrldelta_phy2mac[0].phy_mac_dirfeedback;
    assign ctrldelta_phy_mac_fomfeedback[0] = w_ctrldelta_phy2mac[0].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // CtrlEpsilon (x1)
    //------------------------------------------------------------
    assign w_ctrlepsilon_mac2phy[0] = '{mac_phy_txdata: ctrlepsilon_mac_phy_txdata[0], mac_phy_txdatak: ctrlepsilon_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrlepsilon_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrlepsilon_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrlepsilon_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrlepsilon_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrlepsilon_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrlepsilon_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrlepsilon_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrlepsilon_mac_phy_rxpolarity[0], mac_phy_messagebus: ctrlepsilon_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrlepsilon_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrlepsilon_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrlepsilon_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrlepsilon_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrlepsilon_mac_phy_rxeqeval[0], mac_phy_fs: ctrlepsilon_mac_phy_fs[0], mac_phy_lf: ctrlepsilon_mac_phy_lf[0], mac_phy_dirchange: ctrlepsilon_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrlepsilon_mac_phy_rxeqinprogress[0]};
    assign ctrlepsilon_phy_mac_rxdata[0] = w_ctrlepsilon_phy2mac[0].phy_mac_rxdata;
    assign ctrlepsilon_phy_mac_rxdatak[0] = w_ctrlepsilon_phy2mac[0].phy_mac_rxdatak;
    assign ctrlepsilon_phy_mac_rxdatavalid[0] = w_ctrlepsilon_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrlepsilon_phy_mac_rxstartblock[0] = w_ctrlepsilon_phy2mac[0].phy_mac_rxstartblock;
    assign ctrlepsilon_phy_mac_rxsyncheader[0] = w_ctrlepsilon_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrlepsilon_phy_mac_rxvalid[0] = w_ctrlepsilon_phy2mac[0].phy_mac_rxvalid;
    assign ctrlepsilon_phy_mac_rxstatus[0] = w_ctrlepsilon_phy2mac[0].phy_mac_rxstatus;
    assign ctrlepsilon_phy_mac_rxelecidle[0] = w_ctrlepsilon_phy2mac[0].phy_mac_rxelecidle;
    assign ctrlepsilon_phy_mac_rxstandbystatus[0] = w_ctrlepsilon_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrlepsilon_phy_mac_messagebus[0] = w_ctrlepsilon_phy2mac[0].phy_mac_messagebus;
    assign ctrlepsilon_phy_mac_phystatus = w_ctrlepsilon_phy2mac[0].phy_mac_phystatus;
    assign ctrlepsilon_phy_mac_local_tx_coef_valid[0] = w_ctrlepsilon_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrlepsilon_phy_mac_local_tx_pset_coef[0] = w_ctrlepsilon_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrlepsilon_phy_mac_localfs[0] = w_ctrlepsilon_phy2mac[0].phy_mac_localfs;
    assign ctrlepsilon_phy_mac_locallf[0] = w_ctrlepsilon_phy2mac[0].phy_mac_locallf;
    assign ctrlepsilon_phy_mac_dirfeedback[0] = w_ctrlepsilon_phy2mac[0].phy_mac_dirfeedback;
    assign ctrlepsilon_phy_mac_fomfeedback[0] = w_ctrlepsilon_phy2mac[0].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // CtrlZeta (x1)
    //------------------------------------------------------------
    assign w_ctrlzeta_mac2phy[0] = '{mac_phy_txdata: ctrlzeta_mac_phy_txdata[0], mac_phy_txdatak: ctrlzeta_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrlzeta_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrlzeta_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrlzeta_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrlzeta_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrlzeta_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrlzeta_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrlzeta_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrlzeta_mac_phy_rxpolarity[0], mac_phy_messagebus: ctrlzeta_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrlzeta_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrlzeta_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrlzeta_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrlzeta_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrlzeta_mac_phy_rxeqeval[0], mac_phy_fs: ctrlzeta_mac_phy_fs[0], mac_phy_lf: ctrlzeta_mac_phy_lf[0], mac_phy_dirchange: ctrlzeta_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrlzeta_mac_phy_rxeqinprogress[0]};
    assign ctrlzeta_phy_mac_rxdata[0] = w_ctrlzeta_phy2mac[0].phy_mac_rxdata;
    assign ctrlzeta_phy_mac_rxdatak[0] = w_ctrlzeta_phy2mac[0].phy_mac_rxdatak;
    assign ctrlzeta_phy_mac_rxdatavalid[0] = w_ctrlzeta_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrlzeta_phy_mac_rxstartblock[0] = w_ctrlzeta_phy2mac[0].phy_mac_rxstartblock;
    assign ctrlzeta_phy_mac_rxsyncheader[0] = w_ctrlzeta_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrlzeta_phy_mac_rxvalid[0] = w_ctrlzeta_phy2mac[0].phy_mac_rxvalid;
    assign ctrlzeta_phy_mac_rxstatus[0] = w_ctrlzeta_phy2mac[0].phy_mac_rxstatus;
    assign ctrlzeta_phy_mac_rxelecidle[0] = w_ctrlzeta_phy2mac[0].phy_mac_rxelecidle;
    assign ctrlzeta_phy_mac_rxstandbystatus[0] = w_ctrlzeta_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrlzeta_phy_mac_messagebus[0] = w_ctrlzeta_phy2mac[0].phy_mac_messagebus;
    assign ctrlzeta_phy_mac_phystatus = w_ctrlzeta_phy2mac[0].phy_mac_phystatus;
    assign ctrlzeta_phy_mac_local_tx_coef_valid[0] = w_ctrlzeta_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrlzeta_phy_mac_local_tx_pset_coef[0] = w_ctrlzeta_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrlzeta_phy_mac_localfs[0] = w_ctrlzeta_phy2mac[0].phy_mac_localfs;
    assign ctrlzeta_phy_mac_locallf[0] = w_ctrlzeta_phy2mac[0].phy_mac_locallf;
    assign ctrlzeta_phy_mac_dirfeedback[0] = w_ctrlzeta_phy2mac[0].phy_mac_dirfeedback;
    assign ctrlzeta_phy_mac_fomfeedback[0] = w_ctrlzeta_phy2mac[0].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // Real DUT
    //------------------------------------------------------------
    pipe_lane_mapper #(
        .NL (NL),
        .NC (NC),
        .SEL_SYNC (SEL_SYNC)
    ) u_pipe_lane_mapper (
        .phy_pclk_out (phy_pclk_out),
        .test_en      (test_en),
        .mode         (mode),
        .phy_pclk_in  (phy_pclk_in),
        .phy_rst_n    (phy_rst_n),
        .phy_mac2phy  (w_phy_mac2phy),
        .phy_phy2mac  (w_phy_phy2mac),
        .ctrlalpha_rst_n   (ctrlalpha_rst_n),
        .ctrlalpha_mac2phy (w_ctrlalpha_mac2phy),
        .ctrlalpha_phy2mac (w_ctrlalpha_phy2mac),
        .ctrlalpha_pclk (ctrlalpha_pclk),
        .ctrlbeta_rst_n   (ctrlbeta_rst_n),
        .ctrlbeta_mac2phy (w_ctrlbeta_mac2phy),
        .ctrlbeta_phy2mac (w_ctrlbeta_phy2mac),
        .ctrlbeta_pclk (ctrlbeta_pclk),
        .ctrlgamma_rst_n   (ctrlgamma_rst_n),
        .ctrlgamma_mac2phy (w_ctrlgamma_mac2phy),
        .ctrlgamma_phy2mac (w_ctrlgamma_phy2mac),
        .ctrlgamma_pclk (ctrlgamma_pclk),
        .ctrldelta_rst_n   (ctrldelta_rst_n),
        .ctrldelta_mac2phy (w_ctrldelta_mac2phy),
        .ctrldelta_phy2mac (w_ctrldelta_phy2mac),
        .ctrldelta_pclk (ctrldelta_pclk),
        .ctrlepsilon_rst_n   (ctrlepsilon_rst_n),
        .ctrlepsilon_mac2phy (w_ctrlepsilon_mac2phy),
        .ctrlepsilon_phy2mac (w_ctrlepsilon_phy2mac),
        .ctrlepsilon_pclk (ctrlepsilon_pclk),
        .ctrlzeta_rst_n   (ctrlzeta_rst_n),
        .ctrlzeta_mac2phy (w_ctrlzeta_mac2phy),
        .ctrlzeta_phy2mac (w_ctrlzeta_phy2mac),
        .ctrlzeta_pclk (ctrlzeta_pclk)
    );

endmodule
