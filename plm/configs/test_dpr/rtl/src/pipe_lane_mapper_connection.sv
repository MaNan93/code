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
    parameter int NL = 12,
    parameter int NC = 4,
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
    output logic [0:0] phy_mac_phy_rxstandby [0:NL-1],
    output logic [7:0] phy_mac_phy_messagebus [0:NL-1],
    output logic [2:0] phy_mac_phy_rxpresethint [0:NL-1],
    output logic [4:0] phy_mac_phy_local_pset_index [0:NL-1],
    output logic [0:0] phy_mac_phy_getlocal_pset_coef [0:NL-1],
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
    // DPR (diagnostic probe): a virtual controller with link width NL,
    // connected 1:1 to every PHY lane -- v_lane_mask[l]=1 overrides lane l.
    input logic [NL-1:0] v_lane_mask,
    input logic dpr_rst_n,
    input logic [31:0] dpr_mac_phy_txdata [0:NL-1],
    input logic [3:0] dpr_mac_phy_txdatak [0:NL-1],
    input logic [0:0] dpr_mac_phy_txdatavalid [0:NL-1],
    input logic [0:0] dpr_mac_phy_txstartblock [0:NL-1],
    input logic [1:0] dpr_mac_phy_txsyncheader [0:NL-1],
    input logic [0:0] dpr_mac_phy_txdetectrx_loopback [0:NL-1],
    input logic [0:0] dpr_mac_phy_txelecidle [0:NL-1],
    input logic [0:0] dpr_mac_phy_txcompliance [0:NL-1],
    input logic [17:0] dpr_mac_phy_txdeemph [0:NL-1],
    input logic [0:0] dpr_mac_phy_rxpolarity [0:NL-1],
    input logic [0:0] dpr_mac_phy_rxstandby [0:NL-1],
    input logic [7:0] dpr_mac_phy_messagebus [0:NL-1],
    input logic [2:0] dpr_mac_phy_rxpresethint [0:NL-1],
    input logic [4:0] dpr_mac_phy_local_pset_index [0:NL-1],
    input logic [0:0] dpr_mac_phy_getlocal_pset_coef [0:NL-1],
    input logic [0:0] dpr_mac_phy_invalid_req [0:NL-1],
    input logic [0:0] dpr_mac_phy_rxeqeval [0:NL-1],
    input logic [5:0] dpr_mac_phy_fs [0:NL-1],
    input logic [5:0] dpr_mac_phy_lf [0:NL-1],
    input logic [0:0] dpr_mac_phy_dirchange [0:NL-1],
    input logic [0:0] dpr_mac_phy_rxeqinprogress [0:NL-1],
    output logic [31:0] dpr_phy_mac_rxdata [0:NL-1],
    output logic [3:0] dpr_phy_mac_rxdatak [0:NL-1],
    output logic [0:0] dpr_phy_mac_rxdatavalid [0:NL-1],
    output logic [0:0] dpr_phy_mac_rxstartblock [0:NL-1],
    output logic [1:0] dpr_phy_mac_rxsyncheader [0:NL-1],
    output logic [0:0] dpr_phy_mac_rxvalid [0:NL-1],
    output logic [2:0] dpr_phy_mac_rxstatus [0:NL-1],
    output logic [0:0] dpr_phy_mac_rxelecidle [0:NL-1],
    output logic [0:0] dpr_phy_mac_rxstandbystatus [0:NL-1],
    output logic [7:0] dpr_phy_mac_messagebus [0:NL-1],
    output logic [0:0] dpr_phy_mac_phystatus [0:NL-1],
    output logic [0:0] dpr_phy_mac_local_tx_coef_valid [0:NL-1],
    output logic [17:0] dpr_phy_mac_local_tx_pset_coef [0:NL-1],
    output logic [5:0] dpr_phy_mac_localfs [0:NL-1],
    output logic [5:0] dpr_phy_mac_locallf [0:NL-1],
    output logic [5:0] dpr_phy_mac_dirfeedback [0:NL-1],
    output logic [7:0] dpr_phy_mac_fomfeedback [0:NL-1],
    output logic dpr_pclk,
    // Controller side. Each controller's ports are declared at its own real max_width.
    // CtrlA x12
    input logic ctrla_rst_n,
    input logic [31:0] ctrla_mac_phy_txdata [0:11],
    input logic [3:0] ctrla_mac_phy_txdatak [0:11],
    input logic [0:0] ctrla_mac_phy_txdatavalid [0:11],
    input logic [0:0] ctrla_mac_phy_txstartblock [0:11],
    input logic [1:0] ctrla_mac_phy_txsyncheader [0:11],
    input logic [0:0] ctrla_mac_phy_txdetectrx_loopback [0:11],
    input logic [0:0] ctrla_mac_phy_txelecidle [0:11],
    input logic [0:0] ctrla_mac_phy_txcompliance [0:11],
    input logic [17:0] ctrla_mac_phy_txdeemph [0:11],
    input logic [0:0] ctrla_mac_phy_rxpolarity [0:11],
    input logic [0:0] ctrla_mac_phy_rxstandby [0:11],
    input logic [7:0] ctrla_mac_phy_messagebus [0:11],
    input logic [2:0] ctrla_mac_phy_rxpresethint [0:11],
    input logic [4:0] ctrla_mac_phy_local_pset_index [0:11],
    input logic [0:0] ctrla_mac_phy_getlocal_pset_coef [0:11],
    input logic [0:0] ctrla_mac_phy_invalid_req [0:11],
    input logic [0:0] ctrla_mac_phy_rxeqeval [0:11],
    input logic [5:0] ctrla_mac_phy_fs [0:11],
    input logic [5:0] ctrla_mac_phy_lf [0:11],
    input logic [0:0] ctrla_mac_phy_dirchange [0:11],
    input logic [0:0] ctrla_mac_phy_rxeqinprogress [0:11],
    output logic [31:0] ctrla_phy_mac_rxdata [0:11],
    output logic [3:0] ctrla_phy_mac_rxdatak [0:11],
    output logic [0:0] ctrla_phy_mac_rxdatavalid [0:11],
    output logic [0:0] ctrla_phy_mac_rxstartblock [0:11],
    output logic [1:0] ctrla_phy_mac_rxsyncheader [0:11],
    output logic [0:0] ctrla_phy_mac_rxvalid [0:11],
    output logic [2:0] ctrla_phy_mac_rxstatus [0:11],
    output logic [0:0] ctrla_phy_mac_rxelecidle [0:11],
    output logic [0:0] ctrla_phy_mac_rxstandbystatus [0:11],
    output logic [7:0] ctrla_phy_mac_messagebus [0:11],
    output logic [0:0] ctrla_phy_mac_phystatus [0:11],
    output logic [0:0] ctrla_phy_mac_local_tx_coef_valid [0:11],
    output logic [17:0] ctrla_phy_mac_local_tx_pset_coef [0:11],
    output logic [5:0] ctrla_phy_mac_localfs [0:11],
    output logic [5:0] ctrla_phy_mac_locallf [0:11],
    output logic [5:0] ctrla_phy_mac_dirfeedback [0:11],
    output logic [7:0] ctrla_phy_mac_fomfeedback [0:11],
    output logic ctrla_pclk,
    // CtrlB x6
    input logic ctrlb_rst_n,
    input logic [31:0] ctrlb_mac_phy_txdata [0:5],
    input logic [3:0] ctrlb_mac_phy_txdatak [0:5],
    input logic [0:0] ctrlb_mac_phy_txdatavalid [0:5],
    input logic [0:0] ctrlb_mac_phy_txstartblock [0:5],
    input logic [1:0] ctrlb_mac_phy_txsyncheader [0:5],
    input logic [0:0] ctrlb_mac_phy_txdetectrx_loopback [0:5],
    input logic [0:0] ctrlb_mac_phy_txelecidle [0:5],
    input logic [0:0] ctrlb_mac_phy_txcompliance [0:5],
    input logic [17:0] ctrlb_mac_phy_txdeemph [0:5],
    input logic [0:0] ctrlb_mac_phy_rxpolarity [0:5],
    input logic [0:0] ctrlb_mac_phy_rxstandby [0:5],
    input logic [7:0] ctrlb_mac_phy_messagebus [0:5],
    input logic [2:0] ctrlb_mac_phy_rxpresethint [0:5],
    input logic [4:0] ctrlb_mac_phy_local_pset_index [0:5],
    input logic [0:0] ctrlb_mac_phy_getlocal_pset_coef [0:5],
    input logic [0:0] ctrlb_mac_phy_invalid_req [0:5],
    input logic [0:0] ctrlb_mac_phy_rxeqeval [0:5],
    input logic [5:0] ctrlb_mac_phy_fs [0:5],
    input logic [5:0] ctrlb_mac_phy_lf [0:5],
    input logic [0:0] ctrlb_mac_phy_dirchange [0:5],
    input logic [0:0] ctrlb_mac_phy_rxeqinprogress [0:5],
    output logic [31:0] ctrlb_phy_mac_rxdata [0:5],
    output logic [3:0] ctrlb_phy_mac_rxdatak [0:5],
    output logic [0:0] ctrlb_phy_mac_rxdatavalid [0:5],
    output logic [0:0] ctrlb_phy_mac_rxstartblock [0:5],
    output logic [1:0] ctrlb_phy_mac_rxsyncheader [0:5],
    output logic [0:0] ctrlb_phy_mac_rxvalid [0:5],
    output logic [2:0] ctrlb_phy_mac_rxstatus [0:5],
    output logic [0:0] ctrlb_phy_mac_rxelecidle [0:5],
    output logic [0:0] ctrlb_phy_mac_rxstandbystatus [0:5],
    output logic [7:0] ctrlb_phy_mac_messagebus [0:5],
    output logic [0:0] ctrlb_phy_mac_phystatus [0:5],
    output logic [0:0] ctrlb_phy_mac_local_tx_coef_valid [0:5],
    output logic [17:0] ctrlb_phy_mac_local_tx_pset_coef [0:5],
    output logic [5:0] ctrlb_phy_mac_localfs [0:5],
    output logic [5:0] ctrlb_phy_mac_locallf [0:5],
    output logic [5:0] ctrlb_phy_mac_dirfeedback [0:5],
    output logic [7:0] ctrlb_phy_mac_fomfeedback [0:5],
    output logic ctrlb_pclk,
    // CtrlC x8
    input logic ctrlc_rst_n,
    input logic [31:0] ctrlc_mac_phy_txdata [0:7],
    input logic [3:0] ctrlc_mac_phy_txdatak [0:7],
    input logic [0:0] ctrlc_mac_phy_txdatavalid [0:7],
    input logic [0:0] ctrlc_mac_phy_txstartblock [0:7],
    input logic [1:0] ctrlc_mac_phy_txsyncheader [0:7],
    input logic [0:0] ctrlc_mac_phy_txdetectrx_loopback [0:7],
    input logic [0:0] ctrlc_mac_phy_txelecidle [0:7],
    input logic [0:0] ctrlc_mac_phy_txcompliance [0:7],
    input logic [17:0] ctrlc_mac_phy_txdeemph [0:7],
    input logic [0:0] ctrlc_mac_phy_rxpolarity [0:7],
    input logic [0:0] ctrlc_mac_phy_rxstandby [0:7],
    input logic [7:0] ctrlc_mac_phy_messagebus [0:7],
    input logic [2:0] ctrlc_mac_phy_rxpresethint [0:7],
    input logic [4:0] ctrlc_mac_phy_local_pset_index [0:7],
    input logic [0:0] ctrlc_mac_phy_getlocal_pset_coef [0:7],
    input logic [0:0] ctrlc_mac_phy_invalid_req [0:7],
    input logic [0:0] ctrlc_mac_phy_rxeqeval [0:7],
    input logic [5:0] ctrlc_mac_phy_fs [0:7],
    input logic [5:0] ctrlc_mac_phy_lf [0:7],
    input logic [0:0] ctrlc_mac_phy_dirchange [0:7],
    input logic [0:0] ctrlc_mac_phy_rxeqinprogress [0:7],
    output logic [31:0] ctrlc_phy_mac_rxdata [0:7],
    output logic [3:0] ctrlc_phy_mac_rxdatak [0:7],
    output logic [0:0] ctrlc_phy_mac_rxdatavalid [0:7],
    output logic [0:0] ctrlc_phy_mac_rxstartblock [0:7],
    output logic [1:0] ctrlc_phy_mac_rxsyncheader [0:7],
    output logic [0:0] ctrlc_phy_mac_rxvalid [0:7],
    output logic [2:0] ctrlc_phy_mac_rxstatus [0:7],
    output logic [0:0] ctrlc_phy_mac_rxelecidle [0:7],
    output logic [0:0] ctrlc_phy_mac_rxstandbystatus [0:7],
    output logic [7:0] ctrlc_phy_mac_messagebus [0:7],
    output logic [0:0] ctrlc_phy_mac_phystatus [0:7],
    output logic [0:0] ctrlc_phy_mac_local_tx_coef_valid [0:7],
    output logic [17:0] ctrlc_phy_mac_local_tx_pset_coef [0:7],
    output logic [5:0] ctrlc_phy_mac_localfs [0:7],
    output logic [5:0] ctrlc_phy_mac_locallf [0:7],
    output logic [5:0] ctrlc_phy_mac_dirfeedback [0:7],
    output logic [7:0] ctrlc_phy_mac_fomfeedback [0:7],
    output logic ctrlc_pclk,
    // CtrlD x3
    input logic ctrld_rst_n,
    input logic [31:0] ctrld_mac_phy_txdata [0:2],
    input logic [3:0] ctrld_mac_phy_txdatak [0:2],
    input logic [0:0] ctrld_mac_phy_txdatavalid [0:2],
    input logic [0:0] ctrld_mac_phy_txstartblock [0:2],
    input logic [1:0] ctrld_mac_phy_txsyncheader [0:2],
    input logic [0:0] ctrld_mac_phy_txdetectrx_loopback [0:2],
    input logic [0:0] ctrld_mac_phy_txelecidle [0:2],
    input logic [0:0] ctrld_mac_phy_txcompliance [0:2],
    input logic [17:0] ctrld_mac_phy_txdeemph [0:2],
    input logic [0:0] ctrld_mac_phy_rxpolarity [0:2],
    input logic [0:0] ctrld_mac_phy_rxstandby [0:2],
    input logic [7:0] ctrld_mac_phy_messagebus [0:2],
    input logic [2:0] ctrld_mac_phy_rxpresethint [0:2],
    input logic [4:0] ctrld_mac_phy_local_pset_index [0:2],
    input logic [0:0] ctrld_mac_phy_getlocal_pset_coef [0:2],
    input logic [0:0] ctrld_mac_phy_invalid_req [0:2],
    input logic [0:0] ctrld_mac_phy_rxeqeval [0:2],
    input logic [5:0] ctrld_mac_phy_fs [0:2],
    input logic [5:0] ctrld_mac_phy_lf [0:2],
    input logic [0:0] ctrld_mac_phy_dirchange [0:2],
    input logic [0:0] ctrld_mac_phy_rxeqinprogress [0:2],
    output logic [31:0] ctrld_phy_mac_rxdata [0:2],
    output logic [3:0] ctrld_phy_mac_rxdatak [0:2],
    output logic [0:0] ctrld_phy_mac_rxdatavalid [0:2],
    output logic [0:0] ctrld_phy_mac_rxstartblock [0:2],
    output logic [1:0] ctrld_phy_mac_rxsyncheader [0:2],
    output logic [0:0] ctrld_phy_mac_rxvalid [0:2],
    output logic [2:0] ctrld_phy_mac_rxstatus [0:2],
    output logic [0:0] ctrld_phy_mac_rxelecidle [0:2],
    output logic [0:0] ctrld_phy_mac_rxstandbystatus [0:2],
    output logic [7:0] ctrld_phy_mac_messagebus [0:2],
    output logic [0:0] ctrld_phy_mac_phystatus [0:2],
    output logic [0:0] ctrld_phy_mac_local_tx_coef_valid [0:2],
    output logic [17:0] ctrld_phy_mac_local_tx_pset_coef [0:2],
    output logic [5:0] ctrld_phy_mac_localfs [0:2],
    output logic [5:0] ctrld_phy_mac_locallf [0:2],
    output logic [5:0] ctrld_phy_mac_dirfeedback [0:2],
    output logic [7:0] ctrld_phy_mac_fomfeedback [0:2],
    output logic ctrld_pclk
);

    mac2phy_lane_t [NL-1:0] w_phy_mac2phy;
    phy2mac_lane_t [NL-1:0] w_phy_phy2mac;
    mac2phy_lane_t [11:0] w_ctrla_mac2phy;
    phy2mac_lane_t [11:0] w_ctrla_phy2mac;
    mac2phy_lane_t [5:0] w_ctrlb_mac2phy;
    phy2mac_lane_t [5:0] w_ctrlb_phy2mac;
    mac2phy_lane_t [7:0] w_ctrlc_mac2phy;
    phy2mac_lane_t [7:0] w_ctrlc_phy2mac;
    mac2phy_lane_t [2:0] w_ctrld_mac2phy;
    phy2mac_lane_t [2:0] w_ctrld_phy2mac;
    mac2phy_lane_t [NL-1:0] w_dpr_mac2phy;
    phy2mac_lane_t [NL-1:0] w_dpr_phy2mac;

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
    assign phy_mac_phy_rxstandby[0] = w_phy_mac2phy[0].mac_phy_rxstandby;
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
    assign phy_mac_phy_rxstandby[1] = w_phy_mac2phy[1].mac_phy_rxstandby;
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
    assign phy_mac_phy_rxstandby[2] = w_phy_mac2phy[2].mac_phy_rxstandby;
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
    assign phy_mac_phy_rxstandby[3] = w_phy_mac2phy[3].mac_phy_rxstandby;
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
    assign phy_mac_phy_rxstandby[4] = w_phy_mac2phy[4].mac_phy_rxstandby;
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
    assign phy_mac_phy_rxstandby[5] = w_phy_mac2phy[5].mac_phy_rxstandby;
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
    assign phy_mac_phy_txdata[6] = w_phy_mac2phy[6].mac_phy_txdata;
    assign phy_mac_phy_txdatak[6] = w_phy_mac2phy[6].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[6] = w_phy_mac2phy[6].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[6] = w_phy_mac2phy[6].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[6] = w_phy_mac2phy[6].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[6] = w_phy_mac2phy[6].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[6] = w_phy_mac2phy[6].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[6] = w_phy_mac2phy[6].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[6] = w_phy_mac2phy[6].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[6] = w_phy_mac2phy[6].mac_phy_rxpolarity;
    assign phy_mac_phy_rxstandby[6] = w_phy_mac2phy[6].mac_phy_rxstandby;
    assign phy_mac_phy_messagebus[6] = w_phy_mac2phy[6].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[6] = w_phy_mac2phy[6].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[6] = w_phy_mac2phy[6].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[6] = w_phy_mac2phy[6].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[6] = w_phy_mac2phy[6].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[6] = w_phy_mac2phy[6].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[6] = w_phy_mac2phy[6].mac_phy_fs;
    assign phy_mac_phy_lf[6] = w_phy_mac2phy[6].mac_phy_lf;
    assign phy_mac_phy_dirchange[6] = w_phy_mac2phy[6].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[6] = w_phy_mac2phy[6].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[7] = w_phy_mac2phy[7].mac_phy_txdata;
    assign phy_mac_phy_txdatak[7] = w_phy_mac2phy[7].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[7] = w_phy_mac2phy[7].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[7] = w_phy_mac2phy[7].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[7] = w_phy_mac2phy[7].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[7] = w_phy_mac2phy[7].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[7] = w_phy_mac2phy[7].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[7] = w_phy_mac2phy[7].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[7] = w_phy_mac2phy[7].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[7] = w_phy_mac2phy[7].mac_phy_rxpolarity;
    assign phy_mac_phy_rxstandby[7] = w_phy_mac2phy[7].mac_phy_rxstandby;
    assign phy_mac_phy_messagebus[7] = w_phy_mac2phy[7].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[7] = w_phy_mac2phy[7].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[7] = w_phy_mac2phy[7].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[7] = w_phy_mac2phy[7].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[7] = w_phy_mac2phy[7].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[7] = w_phy_mac2phy[7].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[7] = w_phy_mac2phy[7].mac_phy_fs;
    assign phy_mac_phy_lf[7] = w_phy_mac2phy[7].mac_phy_lf;
    assign phy_mac_phy_dirchange[7] = w_phy_mac2phy[7].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[7] = w_phy_mac2phy[7].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[8] = w_phy_mac2phy[8].mac_phy_txdata;
    assign phy_mac_phy_txdatak[8] = w_phy_mac2phy[8].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[8] = w_phy_mac2phy[8].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[8] = w_phy_mac2phy[8].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[8] = w_phy_mac2phy[8].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[8] = w_phy_mac2phy[8].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[8] = w_phy_mac2phy[8].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[8] = w_phy_mac2phy[8].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[8] = w_phy_mac2phy[8].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[8] = w_phy_mac2phy[8].mac_phy_rxpolarity;
    assign phy_mac_phy_rxstandby[8] = w_phy_mac2phy[8].mac_phy_rxstandby;
    assign phy_mac_phy_messagebus[8] = w_phy_mac2phy[8].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[8] = w_phy_mac2phy[8].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[8] = w_phy_mac2phy[8].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[8] = w_phy_mac2phy[8].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[8] = w_phy_mac2phy[8].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[8] = w_phy_mac2phy[8].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[8] = w_phy_mac2phy[8].mac_phy_fs;
    assign phy_mac_phy_lf[8] = w_phy_mac2phy[8].mac_phy_lf;
    assign phy_mac_phy_dirchange[8] = w_phy_mac2phy[8].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[8] = w_phy_mac2phy[8].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[9] = w_phy_mac2phy[9].mac_phy_txdata;
    assign phy_mac_phy_txdatak[9] = w_phy_mac2phy[9].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[9] = w_phy_mac2phy[9].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[9] = w_phy_mac2phy[9].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[9] = w_phy_mac2phy[9].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[9] = w_phy_mac2phy[9].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[9] = w_phy_mac2phy[9].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[9] = w_phy_mac2phy[9].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[9] = w_phy_mac2phy[9].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[9] = w_phy_mac2phy[9].mac_phy_rxpolarity;
    assign phy_mac_phy_rxstandby[9] = w_phy_mac2phy[9].mac_phy_rxstandby;
    assign phy_mac_phy_messagebus[9] = w_phy_mac2phy[9].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[9] = w_phy_mac2phy[9].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[9] = w_phy_mac2phy[9].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[9] = w_phy_mac2phy[9].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[9] = w_phy_mac2phy[9].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[9] = w_phy_mac2phy[9].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[9] = w_phy_mac2phy[9].mac_phy_fs;
    assign phy_mac_phy_lf[9] = w_phy_mac2phy[9].mac_phy_lf;
    assign phy_mac_phy_dirchange[9] = w_phy_mac2phy[9].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[9] = w_phy_mac2phy[9].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[10] = w_phy_mac2phy[10].mac_phy_txdata;
    assign phy_mac_phy_txdatak[10] = w_phy_mac2phy[10].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[10] = w_phy_mac2phy[10].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[10] = w_phy_mac2phy[10].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[10] = w_phy_mac2phy[10].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[10] = w_phy_mac2phy[10].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[10] = w_phy_mac2phy[10].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[10] = w_phy_mac2phy[10].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[10] = w_phy_mac2phy[10].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[10] = w_phy_mac2phy[10].mac_phy_rxpolarity;
    assign phy_mac_phy_rxstandby[10] = w_phy_mac2phy[10].mac_phy_rxstandby;
    assign phy_mac_phy_messagebus[10] = w_phy_mac2phy[10].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[10] = w_phy_mac2phy[10].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[10] = w_phy_mac2phy[10].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[10] = w_phy_mac2phy[10].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[10] = w_phy_mac2phy[10].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[10] = w_phy_mac2phy[10].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[10] = w_phy_mac2phy[10].mac_phy_fs;
    assign phy_mac_phy_lf[10] = w_phy_mac2phy[10].mac_phy_lf;
    assign phy_mac_phy_dirchange[10] = w_phy_mac2phy[10].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[10] = w_phy_mac2phy[10].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[11] = w_phy_mac2phy[11].mac_phy_txdata;
    assign phy_mac_phy_txdatak[11] = w_phy_mac2phy[11].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[11] = w_phy_mac2phy[11].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[11] = w_phy_mac2phy[11].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[11] = w_phy_mac2phy[11].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[11] = w_phy_mac2phy[11].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[11] = w_phy_mac2phy[11].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[11] = w_phy_mac2phy[11].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[11] = w_phy_mac2phy[11].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[11] = w_phy_mac2phy[11].mac_phy_rxpolarity;
    assign phy_mac_phy_rxstandby[11] = w_phy_mac2phy[11].mac_phy_rxstandby;
    assign phy_mac_phy_messagebus[11] = w_phy_mac2phy[11].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[11] = w_phy_mac2phy[11].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[11] = w_phy_mac2phy[11].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[11] = w_phy_mac2phy[11].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[11] = w_phy_mac2phy[11].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[11] = w_phy_mac2phy[11].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[11] = w_phy_mac2phy[11].mac_phy_fs;
    assign phy_mac_phy_lf[11] = w_phy_mac2phy[11].mac_phy_lf;
    assign phy_mac_phy_dirchange[11] = w_phy_mac2phy[11].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[11] = w_phy_mac2phy[11].mac_phy_rxeqinprogress;
    assign w_phy_phy2mac[0] = '{phy_mac_rxdata: phy_phy_mac_rxdata[0], phy_mac_rxdatak: phy_phy_mac_rxdatak[0], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[0], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[0], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[0], phy_mac_rxvalid: phy_phy_mac_rxvalid[0], phy_mac_rxstatus: phy_phy_mac_rxstatus[0], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[0], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[0], phy_mac_messagebus: phy_phy_mac_messagebus[0], phy_mac_phystatus: phy_phy_mac_phystatus[0], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[0], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[0], phy_mac_localfs: phy_phy_mac_localfs[0], phy_mac_locallf: phy_phy_mac_locallf[0], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[0], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[0]};
    assign w_phy_phy2mac[1] = '{phy_mac_rxdata: phy_phy_mac_rxdata[1], phy_mac_rxdatak: phy_phy_mac_rxdatak[1], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[1], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[1], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[1], phy_mac_rxvalid: phy_phy_mac_rxvalid[1], phy_mac_rxstatus: phy_phy_mac_rxstatus[1], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[1], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[1], phy_mac_messagebus: phy_phy_mac_messagebus[1], phy_mac_phystatus: phy_phy_mac_phystatus[1], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[1], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[1], phy_mac_localfs: phy_phy_mac_localfs[1], phy_mac_locallf: phy_phy_mac_locallf[1], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[1], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[1]};
    assign w_phy_phy2mac[2] = '{phy_mac_rxdata: phy_phy_mac_rxdata[2], phy_mac_rxdatak: phy_phy_mac_rxdatak[2], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[2], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[2], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[2], phy_mac_rxvalid: phy_phy_mac_rxvalid[2], phy_mac_rxstatus: phy_phy_mac_rxstatus[2], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[2], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[2], phy_mac_messagebus: phy_phy_mac_messagebus[2], phy_mac_phystatus: phy_phy_mac_phystatus[2], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[2], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[2], phy_mac_localfs: phy_phy_mac_localfs[2], phy_mac_locallf: phy_phy_mac_locallf[2], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[2], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[2]};
    assign w_phy_phy2mac[3] = '{phy_mac_rxdata: phy_phy_mac_rxdata[3], phy_mac_rxdatak: phy_phy_mac_rxdatak[3], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[3], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[3], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[3], phy_mac_rxvalid: phy_phy_mac_rxvalid[3], phy_mac_rxstatus: phy_phy_mac_rxstatus[3], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[3], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[3], phy_mac_messagebus: phy_phy_mac_messagebus[3], phy_mac_phystatus: phy_phy_mac_phystatus[3], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[3], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[3], phy_mac_localfs: phy_phy_mac_localfs[3], phy_mac_locallf: phy_phy_mac_locallf[3], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[3], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[3]};
    assign w_phy_phy2mac[4] = '{phy_mac_rxdata: phy_phy_mac_rxdata[4], phy_mac_rxdatak: phy_phy_mac_rxdatak[4], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[4], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[4], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[4], phy_mac_rxvalid: phy_phy_mac_rxvalid[4], phy_mac_rxstatus: phy_phy_mac_rxstatus[4], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[4], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[4], phy_mac_messagebus: phy_phy_mac_messagebus[4], phy_mac_phystatus: phy_phy_mac_phystatus[4], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[4], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[4], phy_mac_localfs: phy_phy_mac_localfs[4], phy_mac_locallf: phy_phy_mac_locallf[4], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[4], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[4]};
    assign w_phy_phy2mac[5] = '{phy_mac_rxdata: phy_phy_mac_rxdata[5], phy_mac_rxdatak: phy_phy_mac_rxdatak[5], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[5], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[5], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[5], phy_mac_rxvalid: phy_phy_mac_rxvalid[5], phy_mac_rxstatus: phy_phy_mac_rxstatus[5], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[5], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[5], phy_mac_messagebus: phy_phy_mac_messagebus[5], phy_mac_phystatus: phy_phy_mac_phystatus[5], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[5], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[5], phy_mac_localfs: phy_phy_mac_localfs[5], phy_mac_locallf: phy_phy_mac_locallf[5], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[5], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[5]};
    assign w_phy_phy2mac[6] = '{phy_mac_rxdata: phy_phy_mac_rxdata[6], phy_mac_rxdatak: phy_phy_mac_rxdatak[6], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[6], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[6], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[6], phy_mac_rxvalid: phy_phy_mac_rxvalid[6], phy_mac_rxstatus: phy_phy_mac_rxstatus[6], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[6], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[6], phy_mac_messagebus: phy_phy_mac_messagebus[6], phy_mac_phystatus: phy_phy_mac_phystatus[6], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[6], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[6], phy_mac_localfs: phy_phy_mac_localfs[6], phy_mac_locallf: phy_phy_mac_locallf[6], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[6], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[6]};
    assign w_phy_phy2mac[7] = '{phy_mac_rxdata: phy_phy_mac_rxdata[7], phy_mac_rxdatak: phy_phy_mac_rxdatak[7], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[7], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[7], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[7], phy_mac_rxvalid: phy_phy_mac_rxvalid[7], phy_mac_rxstatus: phy_phy_mac_rxstatus[7], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[7], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[7], phy_mac_messagebus: phy_phy_mac_messagebus[7], phy_mac_phystatus: phy_phy_mac_phystatus[7], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[7], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[7], phy_mac_localfs: phy_phy_mac_localfs[7], phy_mac_locallf: phy_phy_mac_locallf[7], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[7], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[7]};
    assign w_phy_phy2mac[8] = '{phy_mac_rxdata: phy_phy_mac_rxdata[8], phy_mac_rxdatak: phy_phy_mac_rxdatak[8], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[8], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[8], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[8], phy_mac_rxvalid: phy_phy_mac_rxvalid[8], phy_mac_rxstatus: phy_phy_mac_rxstatus[8], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[8], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[8], phy_mac_messagebus: phy_phy_mac_messagebus[8], phy_mac_phystatus: phy_phy_mac_phystatus[8], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[8], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[8], phy_mac_localfs: phy_phy_mac_localfs[8], phy_mac_locallf: phy_phy_mac_locallf[8], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[8], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[8]};
    assign w_phy_phy2mac[9] = '{phy_mac_rxdata: phy_phy_mac_rxdata[9], phy_mac_rxdatak: phy_phy_mac_rxdatak[9], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[9], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[9], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[9], phy_mac_rxvalid: phy_phy_mac_rxvalid[9], phy_mac_rxstatus: phy_phy_mac_rxstatus[9], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[9], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[9], phy_mac_messagebus: phy_phy_mac_messagebus[9], phy_mac_phystatus: phy_phy_mac_phystatus[9], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[9], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[9], phy_mac_localfs: phy_phy_mac_localfs[9], phy_mac_locallf: phy_phy_mac_locallf[9], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[9], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[9]};
    assign w_phy_phy2mac[10] = '{phy_mac_rxdata: phy_phy_mac_rxdata[10], phy_mac_rxdatak: phy_phy_mac_rxdatak[10], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[10], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[10], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[10], phy_mac_rxvalid: phy_phy_mac_rxvalid[10], phy_mac_rxstatus: phy_phy_mac_rxstatus[10], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[10], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[10], phy_mac_messagebus: phy_phy_mac_messagebus[10], phy_mac_phystatus: phy_phy_mac_phystatus[10], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[10], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[10], phy_mac_localfs: phy_phy_mac_localfs[10], phy_mac_locallf: phy_phy_mac_locallf[10], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[10], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[10]};
    assign w_phy_phy2mac[11] = '{phy_mac_rxdata: phy_phy_mac_rxdata[11], phy_mac_rxdatak: phy_phy_mac_rxdatak[11], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[11], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[11], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[11], phy_mac_rxvalid: phy_phy_mac_rxvalid[11], phy_mac_rxstatus: phy_phy_mac_rxstatus[11], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[11], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[11], phy_mac_messagebus: phy_phy_mac_messagebus[11], phy_mac_phystatus: phy_phy_mac_phystatus[11], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[11], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[11], phy_mac_localfs: phy_phy_mac_localfs[11], phy_mac_locallf: phy_phy_mac_locallf[11], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[11], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[11]};

    //------------------------------------------------------------
    // CtrlA (x12)
    //------------------------------------------------------------
    assign w_ctrla_mac2phy[0] = '{mac_phy_txdata: ctrla_mac_phy_txdata[0], mac_phy_txdatak: ctrla_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrla_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrla_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrla_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrla_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrla_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrla_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrla_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrla_mac_phy_rxpolarity[0], mac_phy_rxstandby: ctrla_mac_phy_rxstandby[0], mac_phy_messagebus: ctrla_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrla_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrla_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrla_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrla_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrla_mac_phy_rxeqeval[0], mac_phy_fs: ctrla_mac_phy_fs[0], mac_phy_lf: ctrla_mac_phy_lf[0], mac_phy_dirchange: ctrla_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrla_mac_phy_rxeqinprogress[0]};
    assign w_ctrla_mac2phy[1] = '{mac_phy_txdata: ctrla_mac_phy_txdata[1], mac_phy_txdatak: ctrla_mac_phy_txdatak[1], mac_phy_txdatavalid: ctrla_mac_phy_txdatavalid[1], mac_phy_txstartblock: ctrla_mac_phy_txstartblock[1], mac_phy_txsyncheader: ctrla_mac_phy_txsyncheader[1], mac_phy_txdetectrx_loopback: ctrla_mac_phy_txdetectrx_loopback[1], mac_phy_txelecidle: ctrla_mac_phy_txelecidle[1], mac_phy_txcompliance: ctrla_mac_phy_txcompliance[1], mac_phy_txdeemph: ctrla_mac_phy_txdeemph[1], mac_phy_rxpolarity: ctrla_mac_phy_rxpolarity[1], mac_phy_rxstandby: ctrla_mac_phy_rxstandby[1], mac_phy_messagebus: ctrla_mac_phy_messagebus[1], mac_phy_rxpresethint: ctrla_mac_phy_rxpresethint[1], mac_phy_local_pset_index: ctrla_mac_phy_local_pset_index[1], mac_phy_getlocal_pset_coef: ctrla_mac_phy_getlocal_pset_coef[1], mac_phy_invalid_req: ctrla_mac_phy_invalid_req[1], mac_phy_rxeqeval: ctrla_mac_phy_rxeqeval[1], mac_phy_fs: ctrla_mac_phy_fs[1], mac_phy_lf: ctrla_mac_phy_lf[1], mac_phy_dirchange: ctrla_mac_phy_dirchange[1], mac_phy_rxeqinprogress: ctrla_mac_phy_rxeqinprogress[1]};
    assign w_ctrla_mac2phy[2] = '{mac_phy_txdata: ctrla_mac_phy_txdata[2], mac_phy_txdatak: ctrla_mac_phy_txdatak[2], mac_phy_txdatavalid: ctrla_mac_phy_txdatavalid[2], mac_phy_txstartblock: ctrla_mac_phy_txstartblock[2], mac_phy_txsyncheader: ctrla_mac_phy_txsyncheader[2], mac_phy_txdetectrx_loopback: ctrla_mac_phy_txdetectrx_loopback[2], mac_phy_txelecidle: ctrla_mac_phy_txelecidle[2], mac_phy_txcompliance: ctrla_mac_phy_txcompliance[2], mac_phy_txdeemph: ctrla_mac_phy_txdeemph[2], mac_phy_rxpolarity: ctrla_mac_phy_rxpolarity[2], mac_phy_rxstandby: ctrla_mac_phy_rxstandby[2], mac_phy_messagebus: ctrla_mac_phy_messagebus[2], mac_phy_rxpresethint: ctrla_mac_phy_rxpresethint[2], mac_phy_local_pset_index: ctrla_mac_phy_local_pset_index[2], mac_phy_getlocal_pset_coef: ctrla_mac_phy_getlocal_pset_coef[2], mac_phy_invalid_req: ctrla_mac_phy_invalid_req[2], mac_phy_rxeqeval: ctrla_mac_phy_rxeqeval[2], mac_phy_fs: ctrla_mac_phy_fs[2], mac_phy_lf: ctrla_mac_phy_lf[2], mac_phy_dirchange: ctrla_mac_phy_dirchange[2], mac_phy_rxeqinprogress: ctrla_mac_phy_rxeqinprogress[2]};
    assign w_ctrla_mac2phy[3] = '{mac_phy_txdata: ctrla_mac_phy_txdata[3], mac_phy_txdatak: ctrla_mac_phy_txdatak[3], mac_phy_txdatavalid: ctrla_mac_phy_txdatavalid[3], mac_phy_txstartblock: ctrla_mac_phy_txstartblock[3], mac_phy_txsyncheader: ctrla_mac_phy_txsyncheader[3], mac_phy_txdetectrx_loopback: ctrla_mac_phy_txdetectrx_loopback[3], mac_phy_txelecidle: ctrla_mac_phy_txelecidle[3], mac_phy_txcompliance: ctrla_mac_phy_txcompliance[3], mac_phy_txdeemph: ctrla_mac_phy_txdeemph[3], mac_phy_rxpolarity: ctrla_mac_phy_rxpolarity[3], mac_phy_rxstandby: ctrla_mac_phy_rxstandby[3], mac_phy_messagebus: ctrla_mac_phy_messagebus[3], mac_phy_rxpresethint: ctrla_mac_phy_rxpresethint[3], mac_phy_local_pset_index: ctrla_mac_phy_local_pset_index[3], mac_phy_getlocal_pset_coef: ctrla_mac_phy_getlocal_pset_coef[3], mac_phy_invalid_req: ctrla_mac_phy_invalid_req[3], mac_phy_rxeqeval: ctrla_mac_phy_rxeqeval[3], mac_phy_fs: ctrla_mac_phy_fs[3], mac_phy_lf: ctrla_mac_phy_lf[3], mac_phy_dirchange: ctrla_mac_phy_dirchange[3], mac_phy_rxeqinprogress: ctrla_mac_phy_rxeqinprogress[3]};
    assign w_ctrla_mac2phy[4] = '{mac_phy_txdata: ctrla_mac_phy_txdata[4], mac_phy_txdatak: ctrla_mac_phy_txdatak[4], mac_phy_txdatavalid: ctrla_mac_phy_txdatavalid[4], mac_phy_txstartblock: ctrla_mac_phy_txstartblock[4], mac_phy_txsyncheader: ctrla_mac_phy_txsyncheader[4], mac_phy_txdetectrx_loopback: ctrla_mac_phy_txdetectrx_loopback[4], mac_phy_txelecidle: ctrla_mac_phy_txelecidle[4], mac_phy_txcompliance: ctrla_mac_phy_txcompliance[4], mac_phy_txdeemph: ctrla_mac_phy_txdeemph[4], mac_phy_rxpolarity: ctrla_mac_phy_rxpolarity[4], mac_phy_rxstandby: ctrla_mac_phy_rxstandby[4], mac_phy_messagebus: ctrla_mac_phy_messagebus[4], mac_phy_rxpresethint: ctrla_mac_phy_rxpresethint[4], mac_phy_local_pset_index: ctrla_mac_phy_local_pset_index[4], mac_phy_getlocal_pset_coef: ctrla_mac_phy_getlocal_pset_coef[4], mac_phy_invalid_req: ctrla_mac_phy_invalid_req[4], mac_phy_rxeqeval: ctrla_mac_phy_rxeqeval[4], mac_phy_fs: ctrla_mac_phy_fs[4], mac_phy_lf: ctrla_mac_phy_lf[4], mac_phy_dirchange: ctrla_mac_phy_dirchange[4], mac_phy_rxeqinprogress: ctrla_mac_phy_rxeqinprogress[4]};
    assign w_ctrla_mac2phy[5] = '{mac_phy_txdata: ctrla_mac_phy_txdata[5], mac_phy_txdatak: ctrla_mac_phy_txdatak[5], mac_phy_txdatavalid: ctrla_mac_phy_txdatavalid[5], mac_phy_txstartblock: ctrla_mac_phy_txstartblock[5], mac_phy_txsyncheader: ctrla_mac_phy_txsyncheader[5], mac_phy_txdetectrx_loopback: ctrla_mac_phy_txdetectrx_loopback[5], mac_phy_txelecidle: ctrla_mac_phy_txelecidle[5], mac_phy_txcompliance: ctrla_mac_phy_txcompliance[5], mac_phy_txdeemph: ctrla_mac_phy_txdeemph[5], mac_phy_rxpolarity: ctrla_mac_phy_rxpolarity[5], mac_phy_rxstandby: ctrla_mac_phy_rxstandby[5], mac_phy_messagebus: ctrla_mac_phy_messagebus[5], mac_phy_rxpresethint: ctrla_mac_phy_rxpresethint[5], mac_phy_local_pset_index: ctrla_mac_phy_local_pset_index[5], mac_phy_getlocal_pset_coef: ctrla_mac_phy_getlocal_pset_coef[5], mac_phy_invalid_req: ctrla_mac_phy_invalid_req[5], mac_phy_rxeqeval: ctrla_mac_phy_rxeqeval[5], mac_phy_fs: ctrla_mac_phy_fs[5], mac_phy_lf: ctrla_mac_phy_lf[5], mac_phy_dirchange: ctrla_mac_phy_dirchange[5], mac_phy_rxeqinprogress: ctrla_mac_phy_rxeqinprogress[5]};
    assign w_ctrla_mac2phy[6] = '{mac_phy_txdata: ctrla_mac_phy_txdata[6], mac_phy_txdatak: ctrla_mac_phy_txdatak[6], mac_phy_txdatavalid: ctrla_mac_phy_txdatavalid[6], mac_phy_txstartblock: ctrla_mac_phy_txstartblock[6], mac_phy_txsyncheader: ctrla_mac_phy_txsyncheader[6], mac_phy_txdetectrx_loopback: ctrla_mac_phy_txdetectrx_loopback[6], mac_phy_txelecidle: ctrla_mac_phy_txelecidle[6], mac_phy_txcompliance: ctrla_mac_phy_txcompliance[6], mac_phy_txdeemph: ctrla_mac_phy_txdeemph[6], mac_phy_rxpolarity: ctrla_mac_phy_rxpolarity[6], mac_phy_rxstandby: ctrla_mac_phy_rxstandby[6], mac_phy_messagebus: ctrla_mac_phy_messagebus[6], mac_phy_rxpresethint: ctrla_mac_phy_rxpresethint[6], mac_phy_local_pset_index: ctrla_mac_phy_local_pset_index[6], mac_phy_getlocal_pset_coef: ctrla_mac_phy_getlocal_pset_coef[6], mac_phy_invalid_req: ctrla_mac_phy_invalid_req[6], mac_phy_rxeqeval: ctrla_mac_phy_rxeqeval[6], mac_phy_fs: ctrla_mac_phy_fs[6], mac_phy_lf: ctrla_mac_phy_lf[6], mac_phy_dirchange: ctrla_mac_phy_dirchange[6], mac_phy_rxeqinprogress: ctrla_mac_phy_rxeqinprogress[6]};
    assign w_ctrla_mac2phy[7] = '{mac_phy_txdata: ctrla_mac_phy_txdata[7], mac_phy_txdatak: ctrla_mac_phy_txdatak[7], mac_phy_txdatavalid: ctrla_mac_phy_txdatavalid[7], mac_phy_txstartblock: ctrla_mac_phy_txstartblock[7], mac_phy_txsyncheader: ctrla_mac_phy_txsyncheader[7], mac_phy_txdetectrx_loopback: ctrla_mac_phy_txdetectrx_loopback[7], mac_phy_txelecidle: ctrla_mac_phy_txelecidle[7], mac_phy_txcompliance: ctrla_mac_phy_txcompliance[7], mac_phy_txdeemph: ctrla_mac_phy_txdeemph[7], mac_phy_rxpolarity: ctrla_mac_phy_rxpolarity[7], mac_phy_rxstandby: ctrla_mac_phy_rxstandby[7], mac_phy_messagebus: ctrla_mac_phy_messagebus[7], mac_phy_rxpresethint: ctrla_mac_phy_rxpresethint[7], mac_phy_local_pset_index: ctrla_mac_phy_local_pset_index[7], mac_phy_getlocal_pset_coef: ctrla_mac_phy_getlocal_pset_coef[7], mac_phy_invalid_req: ctrla_mac_phy_invalid_req[7], mac_phy_rxeqeval: ctrla_mac_phy_rxeqeval[7], mac_phy_fs: ctrla_mac_phy_fs[7], mac_phy_lf: ctrla_mac_phy_lf[7], mac_phy_dirchange: ctrla_mac_phy_dirchange[7], mac_phy_rxeqinprogress: ctrla_mac_phy_rxeqinprogress[7]};
    assign w_ctrla_mac2phy[8] = '{mac_phy_txdata: ctrla_mac_phy_txdata[8], mac_phy_txdatak: ctrla_mac_phy_txdatak[8], mac_phy_txdatavalid: ctrla_mac_phy_txdatavalid[8], mac_phy_txstartblock: ctrla_mac_phy_txstartblock[8], mac_phy_txsyncheader: ctrla_mac_phy_txsyncheader[8], mac_phy_txdetectrx_loopback: ctrla_mac_phy_txdetectrx_loopback[8], mac_phy_txelecidle: ctrla_mac_phy_txelecidle[8], mac_phy_txcompliance: ctrla_mac_phy_txcompliance[8], mac_phy_txdeemph: ctrla_mac_phy_txdeemph[8], mac_phy_rxpolarity: ctrla_mac_phy_rxpolarity[8], mac_phy_rxstandby: ctrla_mac_phy_rxstandby[8], mac_phy_messagebus: ctrla_mac_phy_messagebus[8], mac_phy_rxpresethint: ctrla_mac_phy_rxpresethint[8], mac_phy_local_pset_index: ctrla_mac_phy_local_pset_index[8], mac_phy_getlocal_pset_coef: ctrla_mac_phy_getlocal_pset_coef[8], mac_phy_invalid_req: ctrla_mac_phy_invalid_req[8], mac_phy_rxeqeval: ctrla_mac_phy_rxeqeval[8], mac_phy_fs: ctrla_mac_phy_fs[8], mac_phy_lf: ctrla_mac_phy_lf[8], mac_phy_dirchange: ctrla_mac_phy_dirchange[8], mac_phy_rxeqinprogress: ctrla_mac_phy_rxeqinprogress[8]};
    assign w_ctrla_mac2phy[9] = '{mac_phy_txdata: ctrla_mac_phy_txdata[9], mac_phy_txdatak: ctrla_mac_phy_txdatak[9], mac_phy_txdatavalid: ctrla_mac_phy_txdatavalid[9], mac_phy_txstartblock: ctrla_mac_phy_txstartblock[9], mac_phy_txsyncheader: ctrla_mac_phy_txsyncheader[9], mac_phy_txdetectrx_loopback: ctrla_mac_phy_txdetectrx_loopback[9], mac_phy_txelecidle: ctrla_mac_phy_txelecidle[9], mac_phy_txcompliance: ctrla_mac_phy_txcompliance[9], mac_phy_txdeemph: ctrla_mac_phy_txdeemph[9], mac_phy_rxpolarity: ctrla_mac_phy_rxpolarity[9], mac_phy_rxstandby: ctrla_mac_phy_rxstandby[9], mac_phy_messagebus: ctrla_mac_phy_messagebus[9], mac_phy_rxpresethint: ctrla_mac_phy_rxpresethint[9], mac_phy_local_pset_index: ctrla_mac_phy_local_pset_index[9], mac_phy_getlocal_pset_coef: ctrla_mac_phy_getlocal_pset_coef[9], mac_phy_invalid_req: ctrla_mac_phy_invalid_req[9], mac_phy_rxeqeval: ctrla_mac_phy_rxeqeval[9], mac_phy_fs: ctrla_mac_phy_fs[9], mac_phy_lf: ctrla_mac_phy_lf[9], mac_phy_dirchange: ctrla_mac_phy_dirchange[9], mac_phy_rxeqinprogress: ctrla_mac_phy_rxeqinprogress[9]};
    assign w_ctrla_mac2phy[10] = '{mac_phy_txdata: ctrla_mac_phy_txdata[10], mac_phy_txdatak: ctrla_mac_phy_txdatak[10], mac_phy_txdatavalid: ctrla_mac_phy_txdatavalid[10], mac_phy_txstartblock: ctrla_mac_phy_txstartblock[10], mac_phy_txsyncheader: ctrla_mac_phy_txsyncheader[10], mac_phy_txdetectrx_loopback: ctrla_mac_phy_txdetectrx_loopback[10], mac_phy_txelecidle: ctrla_mac_phy_txelecidle[10], mac_phy_txcompliance: ctrla_mac_phy_txcompliance[10], mac_phy_txdeemph: ctrla_mac_phy_txdeemph[10], mac_phy_rxpolarity: ctrla_mac_phy_rxpolarity[10], mac_phy_rxstandby: ctrla_mac_phy_rxstandby[10], mac_phy_messagebus: ctrla_mac_phy_messagebus[10], mac_phy_rxpresethint: ctrla_mac_phy_rxpresethint[10], mac_phy_local_pset_index: ctrla_mac_phy_local_pset_index[10], mac_phy_getlocal_pset_coef: ctrla_mac_phy_getlocal_pset_coef[10], mac_phy_invalid_req: ctrla_mac_phy_invalid_req[10], mac_phy_rxeqeval: ctrla_mac_phy_rxeqeval[10], mac_phy_fs: ctrla_mac_phy_fs[10], mac_phy_lf: ctrla_mac_phy_lf[10], mac_phy_dirchange: ctrla_mac_phy_dirchange[10], mac_phy_rxeqinprogress: ctrla_mac_phy_rxeqinprogress[10]};
    assign w_ctrla_mac2phy[11] = '{mac_phy_txdata: ctrla_mac_phy_txdata[11], mac_phy_txdatak: ctrla_mac_phy_txdatak[11], mac_phy_txdatavalid: ctrla_mac_phy_txdatavalid[11], mac_phy_txstartblock: ctrla_mac_phy_txstartblock[11], mac_phy_txsyncheader: ctrla_mac_phy_txsyncheader[11], mac_phy_txdetectrx_loopback: ctrla_mac_phy_txdetectrx_loopback[11], mac_phy_txelecidle: ctrla_mac_phy_txelecidle[11], mac_phy_txcompliance: ctrla_mac_phy_txcompliance[11], mac_phy_txdeemph: ctrla_mac_phy_txdeemph[11], mac_phy_rxpolarity: ctrla_mac_phy_rxpolarity[11], mac_phy_rxstandby: ctrla_mac_phy_rxstandby[11], mac_phy_messagebus: ctrla_mac_phy_messagebus[11], mac_phy_rxpresethint: ctrla_mac_phy_rxpresethint[11], mac_phy_local_pset_index: ctrla_mac_phy_local_pset_index[11], mac_phy_getlocal_pset_coef: ctrla_mac_phy_getlocal_pset_coef[11], mac_phy_invalid_req: ctrla_mac_phy_invalid_req[11], mac_phy_rxeqeval: ctrla_mac_phy_rxeqeval[11], mac_phy_fs: ctrla_mac_phy_fs[11], mac_phy_lf: ctrla_mac_phy_lf[11], mac_phy_dirchange: ctrla_mac_phy_dirchange[11], mac_phy_rxeqinprogress: ctrla_mac_phy_rxeqinprogress[11]};
    assign ctrla_phy_mac_rxdata[0] = w_ctrla_phy2mac[0].phy_mac_rxdata;
    assign ctrla_phy_mac_rxdata[1] = w_ctrla_phy2mac[1].phy_mac_rxdata;
    assign ctrla_phy_mac_rxdata[2] = w_ctrla_phy2mac[2].phy_mac_rxdata;
    assign ctrla_phy_mac_rxdata[3] = w_ctrla_phy2mac[3].phy_mac_rxdata;
    assign ctrla_phy_mac_rxdata[4] = w_ctrla_phy2mac[4].phy_mac_rxdata;
    assign ctrla_phy_mac_rxdata[5] = w_ctrla_phy2mac[5].phy_mac_rxdata;
    assign ctrla_phy_mac_rxdata[6] = w_ctrla_phy2mac[6].phy_mac_rxdata;
    assign ctrla_phy_mac_rxdata[7] = w_ctrla_phy2mac[7].phy_mac_rxdata;
    assign ctrla_phy_mac_rxdata[8] = w_ctrla_phy2mac[8].phy_mac_rxdata;
    assign ctrla_phy_mac_rxdata[9] = w_ctrla_phy2mac[9].phy_mac_rxdata;
    assign ctrla_phy_mac_rxdata[10] = w_ctrla_phy2mac[10].phy_mac_rxdata;
    assign ctrla_phy_mac_rxdata[11] = w_ctrla_phy2mac[11].phy_mac_rxdata;
    assign ctrla_phy_mac_rxdatak[0] = w_ctrla_phy2mac[0].phy_mac_rxdatak;
    assign ctrla_phy_mac_rxdatak[1] = w_ctrla_phy2mac[1].phy_mac_rxdatak;
    assign ctrla_phy_mac_rxdatak[2] = w_ctrla_phy2mac[2].phy_mac_rxdatak;
    assign ctrla_phy_mac_rxdatak[3] = w_ctrla_phy2mac[3].phy_mac_rxdatak;
    assign ctrla_phy_mac_rxdatak[4] = w_ctrla_phy2mac[4].phy_mac_rxdatak;
    assign ctrla_phy_mac_rxdatak[5] = w_ctrla_phy2mac[5].phy_mac_rxdatak;
    assign ctrla_phy_mac_rxdatak[6] = w_ctrla_phy2mac[6].phy_mac_rxdatak;
    assign ctrla_phy_mac_rxdatak[7] = w_ctrla_phy2mac[7].phy_mac_rxdatak;
    assign ctrla_phy_mac_rxdatak[8] = w_ctrla_phy2mac[8].phy_mac_rxdatak;
    assign ctrla_phy_mac_rxdatak[9] = w_ctrla_phy2mac[9].phy_mac_rxdatak;
    assign ctrla_phy_mac_rxdatak[10] = w_ctrla_phy2mac[10].phy_mac_rxdatak;
    assign ctrla_phy_mac_rxdatak[11] = w_ctrla_phy2mac[11].phy_mac_rxdatak;
    assign ctrla_phy_mac_rxdatavalid[0] = w_ctrla_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrla_phy_mac_rxdatavalid[1] = w_ctrla_phy2mac[1].phy_mac_rxdatavalid;
    assign ctrla_phy_mac_rxdatavalid[2] = w_ctrla_phy2mac[2].phy_mac_rxdatavalid;
    assign ctrla_phy_mac_rxdatavalid[3] = w_ctrla_phy2mac[3].phy_mac_rxdatavalid;
    assign ctrla_phy_mac_rxdatavalid[4] = w_ctrla_phy2mac[4].phy_mac_rxdatavalid;
    assign ctrla_phy_mac_rxdatavalid[5] = w_ctrla_phy2mac[5].phy_mac_rxdatavalid;
    assign ctrla_phy_mac_rxdatavalid[6] = w_ctrla_phy2mac[6].phy_mac_rxdatavalid;
    assign ctrla_phy_mac_rxdatavalid[7] = w_ctrla_phy2mac[7].phy_mac_rxdatavalid;
    assign ctrla_phy_mac_rxdatavalid[8] = w_ctrla_phy2mac[8].phy_mac_rxdatavalid;
    assign ctrla_phy_mac_rxdatavalid[9] = w_ctrla_phy2mac[9].phy_mac_rxdatavalid;
    assign ctrla_phy_mac_rxdatavalid[10] = w_ctrla_phy2mac[10].phy_mac_rxdatavalid;
    assign ctrla_phy_mac_rxdatavalid[11] = w_ctrla_phy2mac[11].phy_mac_rxdatavalid;
    assign ctrla_phy_mac_rxstartblock[0] = w_ctrla_phy2mac[0].phy_mac_rxstartblock;
    assign ctrla_phy_mac_rxstartblock[1] = w_ctrla_phy2mac[1].phy_mac_rxstartblock;
    assign ctrla_phy_mac_rxstartblock[2] = w_ctrla_phy2mac[2].phy_mac_rxstartblock;
    assign ctrla_phy_mac_rxstartblock[3] = w_ctrla_phy2mac[3].phy_mac_rxstartblock;
    assign ctrla_phy_mac_rxstartblock[4] = w_ctrla_phy2mac[4].phy_mac_rxstartblock;
    assign ctrla_phy_mac_rxstartblock[5] = w_ctrla_phy2mac[5].phy_mac_rxstartblock;
    assign ctrla_phy_mac_rxstartblock[6] = w_ctrla_phy2mac[6].phy_mac_rxstartblock;
    assign ctrla_phy_mac_rxstartblock[7] = w_ctrla_phy2mac[7].phy_mac_rxstartblock;
    assign ctrla_phy_mac_rxstartblock[8] = w_ctrla_phy2mac[8].phy_mac_rxstartblock;
    assign ctrla_phy_mac_rxstartblock[9] = w_ctrla_phy2mac[9].phy_mac_rxstartblock;
    assign ctrla_phy_mac_rxstartblock[10] = w_ctrla_phy2mac[10].phy_mac_rxstartblock;
    assign ctrla_phy_mac_rxstartblock[11] = w_ctrla_phy2mac[11].phy_mac_rxstartblock;
    assign ctrla_phy_mac_rxsyncheader[0] = w_ctrla_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrla_phy_mac_rxsyncheader[1] = w_ctrla_phy2mac[1].phy_mac_rxsyncheader;
    assign ctrla_phy_mac_rxsyncheader[2] = w_ctrla_phy2mac[2].phy_mac_rxsyncheader;
    assign ctrla_phy_mac_rxsyncheader[3] = w_ctrla_phy2mac[3].phy_mac_rxsyncheader;
    assign ctrla_phy_mac_rxsyncheader[4] = w_ctrla_phy2mac[4].phy_mac_rxsyncheader;
    assign ctrla_phy_mac_rxsyncheader[5] = w_ctrla_phy2mac[5].phy_mac_rxsyncheader;
    assign ctrla_phy_mac_rxsyncheader[6] = w_ctrla_phy2mac[6].phy_mac_rxsyncheader;
    assign ctrla_phy_mac_rxsyncheader[7] = w_ctrla_phy2mac[7].phy_mac_rxsyncheader;
    assign ctrla_phy_mac_rxsyncheader[8] = w_ctrla_phy2mac[8].phy_mac_rxsyncheader;
    assign ctrla_phy_mac_rxsyncheader[9] = w_ctrla_phy2mac[9].phy_mac_rxsyncheader;
    assign ctrla_phy_mac_rxsyncheader[10] = w_ctrla_phy2mac[10].phy_mac_rxsyncheader;
    assign ctrla_phy_mac_rxsyncheader[11] = w_ctrla_phy2mac[11].phy_mac_rxsyncheader;
    assign ctrla_phy_mac_rxvalid[0] = w_ctrla_phy2mac[0].phy_mac_rxvalid;
    assign ctrla_phy_mac_rxvalid[1] = w_ctrla_phy2mac[1].phy_mac_rxvalid;
    assign ctrla_phy_mac_rxvalid[2] = w_ctrla_phy2mac[2].phy_mac_rxvalid;
    assign ctrla_phy_mac_rxvalid[3] = w_ctrla_phy2mac[3].phy_mac_rxvalid;
    assign ctrla_phy_mac_rxvalid[4] = w_ctrla_phy2mac[4].phy_mac_rxvalid;
    assign ctrla_phy_mac_rxvalid[5] = w_ctrla_phy2mac[5].phy_mac_rxvalid;
    assign ctrla_phy_mac_rxvalid[6] = w_ctrla_phy2mac[6].phy_mac_rxvalid;
    assign ctrla_phy_mac_rxvalid[7] = w_ctrla_phy2mac[7].phy_mac_rxvalid;
    assign ctrla_phy_mac_rxvalid[8] = w_ctrla_phy2mac[8].phy_mac_rxvalid;
    assign ctrla_phy_mac_rxvalid[9] = w_ctrla_phy2mac[9].phy_mac_rxvalid;
    assign ctrla_phy_mac_rxvalid[10] = w_ctrla_phy2mac[10].phy_mac_rxvalid;
    assign ctrla_phy_mac_rxvalid[11] = w_ctrla_phy2mac[11].phy_mac_rxvalid;
    assign ctrla_phy_mac_rxstatus[0] = w_ctrla_phy2mac[0].phy_mac_rxstatus;
    assign ctrla_phy_mac_rxstatus[1] = w_ctrla_phy2mac[1].phy_mac_rxstatus;
    assign ctrla_phy_mac_rxstatus[2] = w_ctrla_phy2mac[2].phy_mac_rxstatus;
    assign ctrla_phy_mac_rxstatus[3] = w_ctrla_phy2mac[3].phy_mac_rxstatus;
    assign ctrla_phy_mac_rxstatus[4] = w_ctrla_phy2mac[4].phy_mac_rxstatus;
    assign ctrla_phy_mac_rxstatus[5] = w_ctrla_phy2mac[5].phy_mac_rxstatus;
    assign ctrla_phy_mac_rxstatus[6] = w_ctrla_phy2mac[6].phy_mac_rxstatus;
    assign ctrla_phy_mac_rxstatus[7] = w_ctrla_phy2mac[7].phy_mac_rxstatus;
    assign ctrla_phy_mac_rxstatus[8] = w_ctrla_phy2mac[8].phy_mac_rxstatus;
    assign ctrla_phy_mac_rxstatus[9] = w_ctrla_phy2mac[9].phy_mac_rxstatus;
    assign ctrla_phy_mac_rxstatus[10] = w_ctrla_phy2mac[10].phy_mac_rxstatus;
    assign ctrla_phy_mac_rxstatus[11] = w_ctrla_phy2mac[11].phy_mac_rxstatus;
    assign ctrla_phy_mac_rxelecidle[0] = w_ctrla_phy2mac[0].phy_mac_rxelecidle;
    assign ctrla_phy_mac_rxelecidle[1] = w_ctrla_phy2mac[1].phy_mac_rxelecidle;
    assign ctrla_phy_mac_rxelecidle[2] = w_ctrla_phy2mac[2].phy_mac_rxelecidle;
    assign ctrla_phy_mac_rxelecidle[3] = w_ctrla_phy2mac[3].phy_mac_rxelecidle;
    assign ctrla_phy_mac_rxelecidle[4] = w_ctrla_phy2mac[4].phy_mac_rxelecidle;
    assign ctrla_phy_mac_rxelecidle[5] = w_ctrla_phy2mac[5].phy_mac_rxelecidle;
    assign ctrla_phy_mac_rxelecidle[6] = w_ctrla_phy2mac[6].phy_mac_rxelecidle;
    assign ctrla_phy_mac_rxelecidle[7] = w_ctrla_phy2mac[7].phy_mac_rxelecidle;
    assign ctrla_phy_mac_rxelecidle[8] = w_ctrla_phy2mac[8].phy_mac_rxelecidle;
    assign ctrla_phy_mac_rxelecidle[9] = w_ctrla_phy2mac[9].phy_mac_rxelecidle;
    assign ctrla_phy_mac_rxelecidle[10] = w_ctrla_phy2mac[10].phy_mac_rxelecidle;
    assign ctrla_phy_mac_rxelecidle[11] = w_ctrla_phy2mac[11].phy_mac_rxelecidle;
    assign ctrla_phy_mac_rxstandbystatus[0] = w_ctrla_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrla_phy_mac_rxstandbystatus[1] = w_ctrla_phy2mac[1].phy_mac_rxstandbystatus;
    assign ctrla_phy_mac_rxstandbystatus[2] = w_ctrla_phy2mac[2].phy_mac_rxstandbystatus;
    assign ctrla_phy_mac_rxstandbystatus[3] = w_ctrla_phy2mac[3].phy_mac_rxstandbystatus;
    assign ctrla_phy_mac_rxstandbystatus[4] = w_ctrla_phy2mac[4].phy_mac_rxstandbystatus;
    assign ctrla_phy_mac_rxstandbystatus[5] = w_ctrla_phy2mac[5].phy_mac_rxstandbystatus;
    assign ctrla_phy_mac_rxstandbystatus[6] = w_ctrla_phy2mac[6].phy_mac_rxstandbystatus;
    assign ctrla_phy_mac_rxstandbystatus[7] = w_ctrla_phy2mac[7].phy_mac_rxstandbystatus;
    assign ctrla_phy_mac_rxstandbystatus[8] = w_ctrla_phy2mac[8].phy_mac_rxstandbystatus;
    assign ctrla_phy_mac_rxstandbystatus[9] = w_ctrla_phy2mac[9].phy_mac_rxstandbystatus;
    assign ctrla_phy_mac_rxstandbystatus[10] = w_ctrla_phy2mac[10].phy_mac_rxstandbystatus;
    assign ctrla_phy_mac_rxstandbystatus[11] = w_ctrla_phy2mac[11].phy_mac_rxstandbystatus;
    assign ctrla_phy_mac_messagebus[0] = w_ctrla_phy2mac[0].phy_mac_messagebus;
    assign ctrla_phy_mac_messagebus[1] = w_ctrla_phy2mac[1].phy_mac_messagebus;
    assign ctrla_phy_mac_messagebus[2] = w_ctrla_phy2mac[2].phy_mac_messagebus;
    assign ctrla_phy_mac_messagebus[3] = w_ctrla_phy2mac[3].phy_mac_messagebus;
    assign ctrla_phy_mac_messagebus[4] = w_ctrla_phy2mac[4].phy_mac_messagebus;
    assign ctrla_phy_mac_messagebus[5] = w_ctrla_phy2mac[5].phy_mac_messagebus;
    assign ctrla_phy_mac_messagebus[6] = w_ctrla_phy2mac[6].phy_mac_messagebus;
    assign ctrla_phy_mac_messagebus[7] = w_ctrla_phy2mac[7].phy_mac_messagebus;
    assign ctrla_phy_mac_messagebus[8] = w_ctrla_phy2mac[8].phy_mac_messagebus;
    assign ctrla_phy_mac_messagebus[9] = w_ctrla_phy2mac[9].phy_mac_messagebus;
    assign ctrla_phy_mac_messagebus[10] = w_ctrla_phy2mac[10].phy_mac_messagebus;
    assign ctrla_phy_mac_messagebus[11] = w_ctrla_phy2mac[11].phy_mac_messagebus;
    assign ctrla_phy_mac_phystatus[0] = w_ctrla_phy2mac[0].phy_mac_phystatus;
    assign ctrla_phy_mac_phystatus[1] = w_ctrla_phy2mac[1].phy_mac_phystatus;
    assign ctrla_phy_mac_phystatus[2] = w_ctrla_phy2mac[2].phy_mac_phystatus;
    assign ctrla_phy_mac_phystatus[3] = w_ctrla_phy2mac[3].phy_mac_phystatus;
    assign ctrla_phy_mac_phystatus[4] = w_ctrla_phy2mac[4].phy_mac_phystatus;
    assign ctrla_phy_mac_phystatus[5] = w_ctrla_phy2mac[5].phy_mac_phystatus;
    assign ctrla_phy_mac_phystatus[6] = w_ctrla_phy2mac[6].phy_mac_phystatus;
    assign ctrla_phy_mac_phystatus[7] = w_ctrla_phy2mac[7].phy_mac_phystatus;
    assign ctrla_phy_mac_phystatus[8] = w_ctrla_phy2mac[8].phy_mac_phystatus;
    assign ctrla_phy_mac_phystatus[9] = w_ctrla_phy2mac[9].phy_mac_phystatus;
    assign ctrla_phy_mac_phystatus[10] = w_ctrla_phy2mac[10].phy_mac_phystatus;
    assign ctrla_phy_mac_phystatus[11] = w_ctrla_phy2mac[11].phy_mac_phystatus;
    assign ctrla_phy_mac_local_tx_coef_valid[0] = w_ctrla_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrla_phy_mac_local_tx_coef_valid[1] = w_ctrla_phy2mac[1].phy_mac_local_tx_coef_valid;
    assign ctrla_phy_mac_local_tx_coef_valid[2] = w_ctrla_phy2mac[2].phy_mac_local_tx_coef_valid;
    assign ctrla_phy_mac_local_tx_coef_valid[3] = w_ctrla_phy2mac[3].phy_mac_local_tx_coef_valid;
    assign ctrla_phy_mac_local_tx_coef_valid[4] = w_ctrla_phy2mac[4].phy_mac_local_tx_coef_valid;
    assign ctrla_phy_mac_local_tx_coef_valid[5] = w_ctrla_phy2mac[5].phy_mac_local_tx_coef_valid;
    assign ctrla_phy_mac_local_tx_coef_valid[6] = w_ctrla_phy2mac[6].phy_mac_local_tx_coef_valid;
    assign ctrla_phy_mac_local_tx_coef_valid[7] = w_ctrla_phy2mac[7].phy_mac_local_tx_coef_valid;
    assign ctrla_phy_mac_local_tx_coef_valid[8] = w_ctrla_phy2mac[8].phy_mac_local_tx_coef_valid;
    assign ctrla_phy_mac_local_tx_coef_valid[9] = w_ctrla_phy2mac[9].phy_mac_local_tx_coef_valid;
    assign ctrla_phy_mac_local_tx_coef_valid[10] = w_ctrla_phy2mac[10].phy_mac_local_tx_coef_valid;
    assign ctrla_phy_mac_local_tx_coef_valid[11] = w_ctrla_phy2mac[11].phy_mac_local_tx_coef_valid;
    assign ctrla_phy_mac_local_tx_pset_coef[0] = w_ctrla_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrla_phy_mac_local_tx_pset_coef[1] = w_ctrla_phy2mac[1].phy_mac_local_tx_pset_coef;
    assign ctrla_phy_mac_local_tx_pset_coef[2] = w_ctrla_phy2mac[2].phy_mac_local_tx_pset_coef;
    assign ctrla_phy_mac_local_tx_pset_coef[3] = w_ctrla_phy2mac[3].phy_mac_local_tx_pset_coef;
    assign ctrla_phy_mac_local_tx_pset_coef[4] = w_ctrla_phy2mac[4].phy_mac_local_tx_pset_coef;
    assign ctrla_phy_mac_local_tx_pset_coef[5] = w_ctrla_phy2mac[5].phy_mac_local_tx_pset_coef;
    assign ctrla_phy_mac_local_tx_pset_coef[6] = w_ctrla_phy2mac[6].phy_mac_local_tx_pset_coef;
    assign ctrla_phy_mac_local_tx_pset_coef[7] = w_ctrla_phy2mac[7].phy_mac_local_tx_pset_coef;
    assign ctrla_phy_mac_local_tx_pset_coef[8] = w_ctrla_phy2mac[8].phy_mac_local_tx_pset_coef;
    assign ctrla_phy_mac_local_tx_pset_coef[9] = w_ctrla_phy2mac[9].phy_mac_local_tx_pset_coef;
    assign ctrla_phy_mac_local_tx_pset_coef[10] = w_ctrla_phy2mac[10].phy_mac_local_tx_pset_coef;
    assign ctrla_phy_mac_local_tx_pset_coef[11] = w_ctrla_phy2mac[11].phy_mac_local_tx_pset_coef;
    assign ctrla_phy_mac_localfs[0] = w_ctrla_phy2mac[0].phy_mac_localfs;
    assign ctrla_phy_mac_localfs[1] = w_ctrla_phy2mac[1].phy_mac_localfs;
    assign ctrla_phy_mac_localfs[2] = w_ctrla_phy2mac[2].phy_mac_localfs;
    assign ctrla_phy_mac_localfs[3] = w_ctrla_phy2mac[3].phy_mac_localfs;
    assign ctrla_phy_mac_localfs[4] = w_ctrla_phy2mac[4].phy_mac_localfs;
    assign ctrla_phy_mac_localfs[5] = w_ctrla_phy2mac[5].phy_mac_localfs;
    assign ctrla_phy_mac_localfs[6] = w_ctrla_phy2mac[6].phy_mac_localfs;
    assign ctrla_phy_mac_localfs[7] = w_ctrla_phy2mac[7].phy_mac_localfs;
    assign ctrla_phy_mac_localfs[8] = w_ctrla_phy2mac[8].phy_mac_localfs;
    assign ctrla_phy_mac_localfs[9] = w_ctrla_phy2mac[9].phy_mac_localfs;
    assign ctrla_phy_mac_localfs[10] = w_ctrla_phy2mac[10].phy_mac_localfs;
    assign ctrla_phy_mac_localfs[11] = w_ctrla_phy2mac[11].phy_mac_localfs;
    assign ctrla_phy_mac_locallf[0] = w_ctrla_phy2mac[0].phy_mac_locallf;
    assign ctrla_phy_mac_locallf[1] = w_ctrla_phy2mac[1].phy_mac_locallf;
    assign ctrla_phy_mac_locallf[2] = w_ctrla_phy2mac[2].phy_mac_locallf;
    assign ctrla_phy_mac_locallf[3] = w_ctrla_phy2mac[3].phy_mac_locallf;
    assign ctrla_phy_mac_locallf[4] = w_ctrla_phy2mac[4].phy_mac_locallf;
    assign ctrla_phy_mac_locallf[5] = w_ctrla_phy2mac[5].phy_mac_locallf;
    assign ctrla_phy_mac_locallf[6] = w_ctrla_phy2mac[6].phy_mac_locallf;
    assign ctrla_phy_mac_locallf[7] = w_ctrla_phy2mac[7].phy_mac_locallf;
    assign ctrla_phy_mac_locallf[8] = w_ctrla_phy2mac[8].phy_mac_locallf;
    assign ctrla_phy_mac_locallf[9] = w_ctrla_phy2mac[9].phy_mac_locallf;
    assign ctrla_phy_mac_locallf[10] = w_ctrla_phy2mac[10].phy_mac_locallf;
    assign ctrla_phy_mac_locallf[11] = w_ctrla_phy2mac[11].phy_mac_locallf;
    assign ctrla_phy_mac_dirfeedback[0] = w_ctrla_phy2mac[0].phy_mac_dirfeedback;
    assign ctrla_phy_mac_dirfeedback[1] = w_ctrla_phy2mac[1].phy_mac_dirfeedback;
    assign ctrla_phy_mac_dirfeedback[2] = w_ctrla_phy2mac[2].phy_mac_dirfeedback;
    assign ctrla_phy_mac_dirfeedback[3] = w_ctrla_phy2mac[3].phy_mac_dirfeedback;
    assign ctrla_phy_mac_dirfeedback[4] = w_ctrla_phy2mac[4].phy_mac_dirfeedback;
    assign ctrla_phy_mac_dirfeedback[5] = w_ctrla_phy2mac[5].phy_mac_dirfeedback;
    assign ctrla_phy_mac_dirfeedback[6] = w_ctrla_phy2mac[6].phy_mac_dirfeedback;
    assign ctrla_phy_mac_dirfeedback[7] = w_ctrla_phy2mac[7].phy_mac_dirfeedback;
    assign ctrla_phy_mac_dirfeedback[8] = w_ctrla_phy2mac[8].phy_mac_dirfeedback;
    assign ctrla_phy_mac_dirfeedback[9] = w_ctrla_phy2mac[9].phy_mac_dirfeedback;
    assign ctrla_phy_mac_dirfeedback[10] = w_ctrla_phy2mac[10].phy_mac_dirfeedback;
    assign ctrla_phy_mac_dirfeedback[11] = w_ctrla_phy2mac[11].phy_mac_dirfeedback;
    assign ctrla_phy_mac_fomfeedback[0] = w_ctrla_phy2mac[0].phy_mac_fomfeedback;
    assign ctrla_phy_mac_fomfeedback[1] = w_ctrla_phy2mac[1].phy_mac_fomfeedback;
    assign ctrla_phy_mac_fomfeedback[2] = w_ctrla_phy2mac[2].phy_mac_fomfeedback;
    assign ctrla_phy_mac_fomfeedback[3] = w_ctrla_phy2mac[3].phy_mac_fomfeedback;
    assign ctrla_phy_mac_fomfeedback[4] = w_ctrla_phy2mac[4].phy_mac_fomfeedback;
    assign ctrla_phy_mac_fomfeedback[5] = w_ctrla_phy2mac[5].phy_mac_fomfeedback;
    assign ctrla_phy_mac_fomfeedback[6] = w_ctrla_phy2mac[6].phy_mac_fomfeedback;
    assign ctrla_phy_mac_fomfeedback[7] = w_ctrla_phy2mac[7].phy_mac_fomfeedback;
    assign ctrla_phy_mac_fomfeedback[8] = w_ctrla_phy2mac[8].phy_mac_fomfeedback;
    assign ctrla_phy_mac_fomfeedback[9] = w_ctrla_phy2mac[9].phy_mac_fomfeedback;
    assign ctrla_phy_mac_fomfeedback[10] = w_ctrla_phy2mac[10].phy_mac_fomfeedback;
    assign ctrla_phy_mac_fomfeedback[11] = w_ctrla_phy2mac[11].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // CtrlB (x6)
    //------------------------------------------------------------
    assign w_ctrlb_mac2phy[0] = '{mac_phy_txdata: ctrlb_mac_phy_txdata[0], mac_phy_txdatak: ctrlb_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrlb_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrlb_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrlb_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrlb_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrlb_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrlb_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrlb_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrlb_mac_phy_rxpolarity[0], mac_phy_rxstandby: ctrlb_mac_phy_rxstandby[0], mac_phy_messagebus: ctrlb_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrlb_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrlb_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrlb_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrlb_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrlb_mac_phy_rxeqeval[0], mac_phy_fs: ctrlb_mac_phy_fs[0], mac_phy_lf: ctrlb_mac_phy_lf[0], mac_phy_dirchange: ctrlb_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrlb_mac_phy_rxeqinprogress[0]};
    assign w_ctrlb_mac2phy[1] = '{mac_phy_txdata: ctrlb_mac_phy_txdata[1], mac_phy_txdatak: ctrlb_mac_phy_txdatak[1], mac_phy_txdatavalid: ctrlb_mac_phy_txdatavalid[1], mac_phy_txstartblock: ctrlb_mac_phy_txstartblock[1], mac_phy_txsyncheader: ctrlb_mac_phy_txsyncheader[1], mac_phy_txdetectrx_loopback: ctrlb_mac_phy_txdetectrx_loopback[1], mac_phy_txelecidle: ctrlb_mac_phy_txelecidle[1], mac_phy_txcompliance: ctrlb_mac_phy_txcompliance[1], mac_phy_txdeemph: ctrlb_mac_phy_txdeemph[1], mac_phy_rxpolarity: ctrlb_mac_phy_rxpolarity[1], mac_phy_rxstandby: ctrlb_mac_phy_rxstandby[1], mac_phy_messagebus: ctrlb_mac_phy_messagebus[1], mac_phy_rxpresethint: ctrlb_mac_phy_rxpresethint[1], mac_phy_local_pset_index: ctrlb_mac_phy_local_pset_index[1], mac_phy_getlocal_pset_coef: ctrlb_mac_phy_getlocal_pset_coef[1], mac_phy_invalid_req: ctrlb_mac_phy_invalid_req[1], mac_phy_rxeqeval: ctrlb_mac_phy_rxeqeval[1], mac_phy_fs: ctrlb_mac_phy_fs[1], mac_phy_lf: ctrlb_mac_phy_lf[1], mac_phy_dirchange: ctrlb_mac_phy_dirchange[1], mac_phy_rxeqinprogress: ctrlb_mac_phy_rxeqinprogress[1]};
    assign w_ctrlb_mac2phy[2] = '{mac_phy_txdata: ctrlb_mac_phy_txdata[2], mac_phy_txdatak: ctrlb_mac_phy_txdatak[2], mac_phy_txdatavalid: ctrlb_mac_phy_txdatavalid[2], mac_phy_txstartblock: ctrlb_mac_phy_txstartblock[2], mac_phy_txsyncheader: ctrlb_mac_phy_txsyncheader[2], mac_phy_txdetectrx_loopback: ctrlb_mac_phy_txdetectrx_loopback[2], mac_phy_txelecidle: ctrlb_mac_phy_txelecidle[2], mac_phy_txcompliance: ctrlb_mac_phy_txcompliance[2], mac_phy_txdeemph: ctrlb_mac_phy_txdeemph[2], mac_phy_rxpolarity: ctrlb_mac_phy_rxpolarity[2], mac_phy_rxstandby: ctrlb_mac_phy_rxstandby[2], mac_phy_messagebus: ctrlb_mac_phy_messagebus[2], mac_phy_rxpresethint: ctrlb_mac_phy_rxpresethint[2], mac_phy_local_pset_index: ctrlb_mac_phy_local_pset_index[2], mac_phy_getlocal_pset_coef: ctrlb_mac_phy_getlocal_pset_coef[2], mac_phy_invalid_req: ctrlb_mac_phy_invalid_req[2], mac_phy_rxeqeval: ctrlb_mac_phy_rxeqeval[2], mac_phy_fs: ctrlb_mac_phy_fs[2], mac_phy_lf: ctrlb_mac_phy_lf[2], mac_phy_dirchange: ctrlb_mac_phy_dirchange[2], mac_phy_rxeqinprogress: ctrlb_mac_phy_rxeqinprogress[2]};
    assign w_ctrlb_mac2phy[3] = '{mac_phy_txdata: ctrlb_mac_phy_txdata[3], mac_phy_txdatak: ctrlb_mac_phy_txdatak[3], mac_phy_txdatavalid: ctrlb_mac_phy_txdatavalid[3], mac_phy_txstartblock: ctrlb_mac_phy_txstartblock[3], mac_phy_txsyncheader: ctrlb_mac_phy_txsyncheader[3], mac_phy_txdetectrx_loopback: ctrlb_mac_phy_txdetectrx_loopback[3], mac_phy_txelecidle: ctrlb_mac_phy_txelecidle[3], mac_phy_txcompliance: ctrlb_mac_phy_txcompliance[3], mac_phy_txdeemph: ctrlb_mac_phy_txdeemph[3], mac_phy_rxpolarity: ctrlb_mac_phy_rxpolarity[3], mac_phy_rxstandby: ctrlb_mac_phy_rxstandby[3], mac_phy_messagebus: ctrlb_mac_phy_messagebus[3], mac_phy_rxpresethint: ctrlb_mac_phy_rxpresethint[3], mac_phy_local_pset_index: ctrlb_mac_phy_local_pset_index[3], mac_phy_getlocal_pset_coef: ctrlb_mac_phy_getlocal_pset_coef[3], mac_phy_invalid_req: ctrlb_mac_phy_invalid_req[3], mac_phy_rxeqeval: ctrlb_mac_phy_rxeqeval[3], mac_phy_fs: ctrlb_mac_phy_fs[3], mac_phy_lf: ctrlb_mac_phy_lf[3], mac_phy_dirchange: ctrlb_mac_phy_dirchange[3], mac_phy_rxeqinprogress: ctrlb_mac_phy_rxeqinprogress[3]};
    assign w_ctrlb_mac2phy[4] = '{mac_phy_txdata: ctrlb_mac_phy_txdata[4], mac_phy_txdatak: ctrlb_mac_phy_txdatak[4], mac_phy_txdatavalid: ctrlb_mac_phy_txdatavalid[4], mac_phy_txstartblock: ctrlb_mac_phy_txstartblock[4], mac_phy_txsyncheader: ctrlb_mac_phy_txsyncheader[4], mac_phy_txdetectrx_loopback: ctrlb_mac_phy_txdetectrx_loopback[4], mac_phy_txelecidle: ctrlb_mac_phy_txelecidle[4], mac_phy_txcompliance: ctrlb_mac_phy_txcompliance[4], mac_phy_txdeemph: ctrlb_mac_phy_txdeemph[4], mac_phy_rxpolarity: ctrlb_mac_phy_rxpolarity[4], mac_phy_rxstandby: ctrlb_mac_phy_rxstandby[4], mac_phy_messagebus: ctrlb_mac_phy_messagebus[4], mac_phy_rxpresethint: ctrlb_mac_phy_rxpresethint[4], mac_phy_local_pset_index: ctrlb_mac_phy_local_pset_index[4], mac_phy_getlocal_pset_coef: ctrlb_mac_phy_getlocal_pset_coef[4], mac_phy_invalid_req: ctrlb_mac_phy_invalid_req[4], mac_phy_rxeqeval: ctrlb_mac_phy_rxeqeval[4], mac_phy_fs: ctrlb_mac_phy_fs[4], mac_phy_lf: ctrlb_mac_phy_lf[4], mac_phy_dirchange: ctrlb_mac_phy_dirchange[4], mac_phy_rxeqinprogress: ctrlb_mac_phy_rxeqinprogress[4]};
    assign w_ctrlb_mac2phy[5] = '{mac_phy_txdata: ctrlb_mac_phy_txdata[5], mac_phy_txdatak: ctrlb_mac_phy_txdatak[5], mac_phy_txdatavalid: ctrlb_mac_phy_txdatavalid[5], mac_phy_txstartblock: ctrlb_mac_phy_txstartblock[5], mac_phy_txsyncheader: ctrlb_mac_phy_txsyncheader[5], mac_phy_txdetectrx_loopback: ctrlb_mac_phy_txdetectrx_loopback[5], mac_phy_txelecidle: ctrlb_mac_phy_txelecidle[5], mac_phy_txcompliance: ctrlb_mac_phy_txcompliance[5], mac_phy_txdeemph: ctrlb_mac_phy_txdeemph[5], mac_phy_rxpolarity: ctrlb_mac_phy_rxpolarity[5], mac_phy_rxstandby: ctrlb_mac_phy_rxstandby[5], mac_phy_messagebus: ctrlb_mac_phy_messagebus[5], mac_phy_rxpresethint: ctrlb_mac_phy_rxpresethint[5], mac_phy_local_pset_index: ctrlb_mac_phy_local_pset_index[5], mac_phy_getlocal_pset_coef: ctrlb_mac_phy_getlocal_pset_coef[5], mac_phy_invalid_req: ctrlb_mac_phy_invalid_req[5], mac_phy_rxeqeval: ctrlb_mac_phy_rxeqeval[5], mac_phy_fs: ctrlb_mac_phy_fs[5], mac_phy_lf: ctrlb_mac_phy_lf[5], mac_phy_dirchange: ctrlb_mac_phy_dirchange[5], mac_phy_rxeqinprogress: ctrlb_mac_phy_rxeqinprogress[5]};
    assign ctrlb_phy_mac_rxdata[0] = w_ctrlb_phy2mac[0].phy_mac_rxdata;
    assign ctrlb_phy_mac_rxdata[1] = w_ctrlb_phy2mac[1].phy_mac_rxdata;
    assign ctrlb_phy_mac_rxdata[2] = w_ctrlb_phy2mac[2].phy_mac_rxdata;
    assign ctrlb_phy_mac_rxdata[3] = w_ctrlb_phy2mac[3].phy_mac_rxdata;
    assign ctrlb_phy_mac_rxdata[4] = w_ctrlb_phy2mac[4].phy_mac_rxdata;
    assign ctrlb_phy_mac_rxdata[5] = w_ctrlb_phy2mac[5].phy_mac_rxdata;
    assign ctrlb_phy_mac_rxdatak[0] = w_ctrlb_phy2mac[0].phy_mac_rxdatak;
    assign ctrlb_phy_mac_rxdatak[1] = w_ctrlb_phy2mac[1].phy_mac_rxdatak;
    assign ctrlb_phy_mac_rxdatak[2] = w_ctrlb_phy2mac[2].phy_mac_rxdatak;
    assign ctrlb_phy_mac_rxdatak[3] = w_ctrlb_phy2mac[3].phy_mac_rxdatak;
    assign ctrlb_phy_mac_rxdatak[4] = w_ctrlb_phy2mac[4].phy_mac_rxdatak;
    assign ctrlb_phy_mac_rxdatak[5] = w_ctrlb_phy2mac[5].phy_mac_rxdatak;
    assign ctrlb_phy_mac_rxdatavalid[0] = w_ctrlb_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrlb_phy_mac_rxdatavalid[1] = w_ctrlb_phy2mac[1].phy_mac_rxdatavalid;
    assign ctrlb_phy_mac_rxdatavalid[2] = w_ctrlb_phy2mac[2].phy_mac_rxdatavalid;
    assign ctrlb_phy_mac_rxdatavalid[3] = w_ctrlb_phy2mac[3].phy_mac_rxdatavalid;
    assign ctrlb_phy_mac_rxdatavalid[4] = w_ctrlb_phy2mac[4].phy_mac_rxdatavalid;
    assign ctrlb_phy_mac_rxdatavalid[5] = w_ctrlb_phy2mac[5].phy_mac_rxdatavalid;
    assign ctrlb_phy_mac_rxstartblock[0] = w_ctrlb_phy2mac[0].phy_mac_rxstartblock;
    assign ctrlb_phy_mac_rxstartblock[1] = w_ctrlb_phy2mac[1].phy_mac_rxstartblock;
    assign ctrlb_phy_mac_rxstartblock[2] = w_ctrlb_phy2mac[2].phy_mac_rxstartblock;
    assign ctrlb_phy_mac_rxstartblock[3] = w_ctrlb_phy2mac[3].phy_mac_rxstartblock;
    assign ctrlb_phy_mac_rxstartblock[4] = w_ctrlb_phy2mac[4].phy_mac_rxstartblock;
    assign ctrlb_phy_mac_rxstartblock[5] = w_ctrlb_phy2mac[5].phy_mac_rxstartblock;
    assign ctrlb_phy_mac_rxsyncheader[0] = w_ctrlb_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrlb_phy_mac_rxsyncheader[1] = w_ctrlb_phy2mac[1].phy_mac_rxsyncheader;
    assign ctrlb_phy_mac_rxsyncheader[2] = w_ctrlb_phy2mac[2].phy_mac_rxsyncheader;
    assign ctrlb_phy_mac_rxsyncheader[3] = w_ctrlb_phy2mac[3].phy_mac_rxsyncheader;
    assign ctrlb_phy_mac_rxsyncheader[4] = w_ctrlb_phy2mac[4].phy_mac_rxsyncheader;
    assign ctrlb_phy_mac_rxsyncheader[5] = w_ctrlb_phy2mac[5].phy_mac_rxsyncheader;
    assign ctrlb_phy_mac_rxvalid[0] = w_ctrlb_phy2mac[0].phy_mac_rxvalid;
    assign ctrlb_phy_mac_rxvalid[1] = w_ctrlb_phy2mac[1].phy_mac_rxvalid;
    assign ctrlb_phy_mac_rxvalid[2] = w_ctrlb_phy2mac[2].phy_mac_rxvalid;
    assign ctrlb_phy_mac_rxvalid[3] = w_ctrlb_phy2mac[3].phy_mac_rxvalid;
    assign ctrlb_phy_mac_rxvalid[4] = w_ctrlb_phy2mac[4].phy_mac_rxvalid;
    assign ctrlb_phy_mac_rxvalid[5] = w_ctrlb_phy2mac[5].phy_mac_rxvalid;
    assign ctrlb_phy_mac_rxstatus[0] = w_ctrlb_phy2mac[0].phy_mac_rxstatus;
    assign ctrlb_phy_mac_rxstatus[1] = w_ctrlb_phy2mac[1].phy_mac_rxstatus;
    assign ctrlb_phy_mac_rxstatus[2] = w_ctrlb_phy2mac[2].phy_mac_rxstatus;
    assign ctrlb_phy_mac_rxstatus[3] = w_ctrlb_phy2mac[3].phy_mac_rxstatus;
    assign ctrlb_phy_mac_rxstatus[4] = w_ctrlb_phy2mac[4].phy_mac_rxstatus;
    assign ctrlb_phy_mac_rxstatus[5] = w_ctrlb_phy2mac[5].phy_mac_rxstatus;
    assign ctrlb_phy_mac_rxelecidle[0] = w_ctrlb_phy2mac[0].phy_mac_rxelecidle;
    assign ctrlb_phy_mac_rxelecidle[1] = w_ctrlb_phy2mac[1].phy_mac_rxelecidle;
    assign ctrlb_phy_mac_rxelecidle[2] = w_ctrlb_phy2mac[2].phy_mac_rxelecidle;
    assign ctrlb_phy_mac_rxelecidle[3] = w_ctrlb_phy2mac[3].phy_mac_rxelecidle;
    assign ctrlb_phy_mac_rxelecidle[4] = w_ctrlb_phy2mac[4].phy_mac_rxelecidle;
    assign ctrlb_phy_mac_rxelecidle[5] = w_ctrlb_phy2mac[5].phy_mac_rxelecidle;
    assign ctrlb_phy_mac_rxstandbystatus[0] = w_ctrlb_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrlb_phy_mac_rxstandbystatus[1] = w_ctrlb_phy2mac[1].phy_mac_rxstandbystatus;
    assign ctrlb_phy_mac_rxstandbystatus[2] = w_ctrlb_phy2mac[2].phy_mac_rxstandbystatus;
    assign ctrlb_phy_mac_rxstandbystatus[3] = w_ctrlb_phy2mac[3].phy_mac_rxstandbystatus;
    assign ctrlb_phy_mac_rxstandbystatus[4] = w_ctrlb_phy2mac[4].phy_mac_rxstandbystatus;
    assign ctrlb_phy_mac_rxstandbystatus[5] = w_ctrlb_phy2mac[5].phy_mac_rxstandbystatus;
    assign ctrlb_phy_mac_messagebus[0] = w_ctrlb_phy2mac[0].phy_mac_messagebus;
    assign ctrlb_phy_mac_messagebus[1] = w_ctrlb_phy2mac[1].phy_mac_messagebus;
    assign ctrlb_phy_mac_messagebus[2] = w_ctrlb_phy2mac[2].phy_mac_messagebus;
    assign ctrlb_phy_mac_messagebus[3] = w_ctrlb_phy2mac[3].phy_mac_messagebus;
    assign ctrlb_phy_mac_messagebus[4] = w_ctrlb_phy2mac[4].phy_mac_messagebus;
    assign ctrlb_phy_mac_messagebus[5] = w_ctrlb_phy2mac[5].phy_mac_messagebus;
    assign ctrlb_phy_mac_phystatus[0] = w_ctrlb_phy2mac[0].phy_mac_phystatus;
    assign ctrlb_phy_mac_phystatus[1] = w_ctrlb_phy2mac[1].phy_mac_phystatus;
    assign ctrlb_phy_mac_phystatus[2] = w_ctrlb_phy2mac[2].phy_mac_phystatus;
    assign ctrlb_phy_mac_phystatus[3] = w_ctrlb_phy2mac[3].phy_mac_phystatus;
    assign ctrlb_phy_mac_phystatus[4] = w_ctrlb_phy2mac[4].phy_mac_phystatus;
    assign ctrlb_phy_mac_phystatus[5] = w_ctrlb_phy2mac[5].phy_mac_phystatus;
    assign ctrlb_phy_mac_local_tx_coef_valid[0] = w_ctrlb_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrlb_phy_mac_local_tx_coef_valid[1] = w_ctrlb_phy2mac[1].phy_mac_local_tx_coef_valid;
    assign ctrlb_phy_mac_local_tx_coef_valid[2] = w_ctrlb_phy2mac[2].phy_mac_local_tx_coef_valid;
    assign ctrlb_phy_mac_local_tx_coef_valid[3] = w_ctrlb_phy2mac[3].phy_mac_local_tx_coef_valid;
    assign ctrlb_phy_mac_local_tx_coef_valid[4] = w_ctrlb_phy2mac[4].phy_mac_local_tx_coef_valid;
    assign ctrlb_phy_mac_local_tx_coef_valid[5] = w_ctrlb_phy2mac[5].phy_mac_local_tx_coef_valid;
    assign ctrlb_phy_mac_local_tx_pset_coef[0] = w_ctrlb_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrlb_phy_mac_local_tx_pset_coef[1] = w_ctrlb_phy2mac[1].phy_mac_local_tx_pset_coef;
    assign ctrlb_phy_mac_local_tx_pset_coef[2] = w_ctrlb_phy2mac[2].phy_mac_local_tx_pset_coef;
    assign ctrlb_phy_mac_local_tx_pset_coef[3] = w_ctrlb_phy2mac[3].phy_mac_local_tx_pset_coef;
    assign ctrlb_phy_mac_local_tx_pset_coef[4] = w_ctrlb_phy2mac[4].phy_mac_local_tx_pset_coef;
    assign ctrlb_phy_mac_local_tx_pset_coef[5] = w_ctrlb_phy2mac[5].phy_mac_local_tx_pset_coef;
    assign ctrlb_phy_mac_localfs[0] = w_ctrlb_phy2mac[0].phy_mac_localfs;
    assign ctrlb_phy_mac_localfs[1] = w_ctrlb_phy2mac[1].phy_mac_localfs;
    assign ctrlb_phy_mac_localfs[2] = w_ctrlb_phy2mac[2].phy_mac_localfs;
    assign ctrlb_phy_mac_localfs[3] = w_ctrlb_phy2mac[3].phy_mac_localfs;
    assign ctrlb_phy_mac_localfs[4] = w_ctrlb_phy2mac[4].phy_mac_localfs;
    assign ctrlb_phy_mac_localfs[5] = w_ctrlb_phy2mac[5].phy_mac_localfs;
    assign ctrlb_phy_mac_locallf[0] = w_ctrlb_phy2mac[0].phy_mac_locallf;
    assign ctrlb_phy_mac_locallf[1] = w_ctrlb_phy2mac[1].phy_mac_locallf;
    assign ctrlb_phy_mac_locallf[2] = w_ctrlb_phy2mac[2].phy_mac_locallf;
    assign ctrlb_phy_mac_locallf[3] = w_ctrlb_phy2mac[3].phy_mac_locallf;
    assign ctrlb_phy_mac_locallf[4] = w_ctrlb_phy2mac[4].phy_mac_locallf;
    assign ctrlb_phy_mac_locallf[5] = w_ctrlb_phy2mac[5].phy_mac_locallf;
    assign ctrlb_phy_mac_dirfeedback[0] = w_ctrlb_phy2mac[0].phy_mac_dirfeedback;
    assign ctrlb_phy_mac_dirfeedback[1] = w_ctrlb_phy2mac[1].phy_mac_dirfeedback;
    assign ctrlb_phy_mac_dirfeedback[2] = w_ctrlb_phy2mac[2].phy_mac_dirfeedback;
    assign ctrlb_phy_mac_dirfeedback[3] = w_ctrlb_phy2mac[3].phy_mac_dirfeedback;
    assign ctrlb_phy_mac_dirfeedback[4] = w_ctrlb_phy2mac[4].phy_mac_dirfeedback;
    assign ctrlb_phy_mac_dirfeedback[5] = w_ctrlb_phy2mac[5].phy_mac_dirfeedback;
    assign ctrlb_phy_mac_fomfeedback[0] = w_ctrlb_phy2mac[0].phy_mac_fomfeedback;
    assign ctrlb_phy_mac_fomfeedback[1] = w_ctrlb_phy2mac[1].phy_mac_fomfeedback;
    assign ctrlb_phy_mac_fomfeedback[2] = w_ctrlb_phy2mac[2].phy_mac_fomfeedback;
    assign ctrlb_phy_mac_fomfeedback[3] = w_ctrlb_phy2mac[3].phy_mac_fomfeedback;
    assign ctrlb_phy_mac_fomfeedback[4] = w_ctrlb_phy2mac[4].phy_mac_fomfeedback;
    assign ctrlb_phy_mac_fomfeedback[5] = w_ctrlb_phy2mac[5].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // CtrlC (x8)
    //------------------------------------------------------------
    assign w_ctrlc_mac2phy[0] = '{mac_phy_txdata: ctrlc_mac_phy_txdata[0], mac_phy_txdatak: ctrlc_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrlc_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrlc_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrlc_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrlc_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrlc_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrlc_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrlc_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrlc_mac_phy_rxpolarity[0], mac_phy_rxstandby: ctrlc_mac_phy_rxstandby[0], mac_phy_messagebus: ctrlc_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrlc_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrlc_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrlc_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrlc_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrlc_mac_phy_rxeqeval[0], mac_phy_fs: ctrlc_mac_phy_fs[0], mac_phy_lf: ctrlc_mac_phy_lf[0], mac_phy_dirchange: ctrlc_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrlc_mac_phy_rxeqinprogress[0]};
    assign w_ctrlc_mac2phy[1] = '{mac_phy_txdata: ctrlc_mac_phy_txdata[1], mac_phy_txdatak: ctrlc_mac_phy_txdatak[1], mac_phy_txdatavalid: ctrlc_mac_phy_txdatavalid[1], mac_phy_txstartblock: ctrlc_mac_phy_txstartblock[1], mac_phy_txsyncheader: ctrlc_mac_phy_txsyncheader[1], mac_phy_txdetectrx_loopback: ctrlc_mac_phy_txdetectrx_loopback[1], mac_phy_txelecidle: ctrlc_mac_phy_txelecidle[1], mac_phy_txcompliance: ctrlc_mac_phy_txcompliance[1], mac_phy_txdeemph: ctrlc_mac_phy_txdeemph[1], mac_phy_rxpolarity: ctrlc_mac_phy_rxpolarity[1], mac_phy_rxstandby: ctrlc_mac_phy_rxstandby[1], mac_phy_messagebus: ctrlc_mac_phy_messagebus[1], mac_phy_rxpresethint: ctrlc_mac_phy_rxpresethint[1], mac_phy_local_pset_index: ctrlc_mac_phy_local_pset_index[1], mac_phy_getlocal_pset_coef: ctrlc_mac_phy_getlocal_pset_coef[1], mac_phy_invalid_req: ctrlc_mac_phy_invalid_req[1], mac_phy_rxeqeval: ctrlc_mac_phy_rxeqeval[1], mac_phy_fs: ctrlc_mac_phy_fs[1], mac_phy_lf: ctrlc_mac_phy_lf[1], mac_phy_dirchange: ctrlc_mac_phy_dirchange[1], mac_phy_rxeqinprogress: ctrlc_mac_phy_rxeqinprogress[1]};
    assign w_ctrlc_mac2phy[2] = '{mac_phy_txdata: ctrlc_mac_phy_txdata[2], mac_phy_txdatak: ctrlc_mac_phy_txdatak[2], mac_phy_txdatavalid: ctrlc_mac_phy_txdatavalid[2], mac_phy_txstartblock: ctrlc_mac_phy_txstartblock[2], mac_phy_txsyncheader: ctrlc_mac_phy_txsyncheader[2], mac_phy_txdetectrx_loopback: ctrlc_mac_phy_txdetectrx_loopback[2], mac_phy_txelecidle: ctrlc_mac_phy_txelecidle[2], mac_phy_txcompliance: ctrlc_mac_phy_txcompliance[2], mac_phy_txdeemph: ctrlc_mac_phy_txdeemph[2], mac_phy_rxpolarity: ctrlc_mac_phy_rxpolarity[2], mac_phy_rxstandby: ctrlc_mac_phy_rxstandby[2], mac_phy_messagebus: ctrlc_mac_phy_messagebus[2], mac_phy_rxpresethint: ctrlc_mac_phy_rxpresethint[2], mac_phy_local_pset_index: ctrlc_mac_phy_local_pset_index[2], mac_phy_getlocal_pset_coef: ctrlc_mac_phy_getlocal_pset_coef[2], mac_phy_invalid_req: ctrlc_mac_phy_invalid_req[2], mac_phy_rxeqeval: ctrlc_mac_phy_rxeqeval[2], mac_phy_fs: ctrlc_mac_phy_fs[2], mac_phy_lf: ctrlc_mac_phy_lf[2], mac_phy_dirchange: ctrlc_mac_phy_dirchange[2], mac_phy_rxeqinprogress: ctrlc_mac_phy_rxeqinprogress[2]};
    assign w_ctrlc_mac2phy[3] = '{mac_phy_txdata: ctrlc_mac_phy_txdata[3], mac_phy_txdatak: ctrlc_mac_phy_txdatak[3], mac_phy_txdatavalid: ctrlc_mac_phy_txdatavalid[3], mac_phy_txstartblock: ctrlc_mac_phy_txstartblock[3], mac_phy_txsyncheader: ctrlc_mac_phy_txsyncheader[3], mac_phy_txdetectrx_loopback: ctrlc_mac_phy_txdetectrx_loopback[3], mac_phy_txelecidle: ctrlc_mac_phy_txelecidle[3], mac_phy_txcompliance: ctrlc_mac_phy_txcompliance[3], mac_phy_txdeemph: ctrlc_mac_phy_txdeemph[3], mac_phy_rxpolarity: ctrlc_mac_phy_rxpolarity[3], mac_phy_rxstandby: ctrlc_mac_phy_rxstandby[3], mac_phy_messagebus: ctrlc_mac_phy_messagebus[3], mac_phy_rxpresethint: ctrlc_mac_phy_rxpresethint[3], mac_phy_local_pset_index: ctrlc_mac_phy_local_pset_index[3], mac_phy_getlocal_pset_coef: ctrlc_mac_phy_getlocal_pset_coef[3], mac_phy_invalid_req: ctrlc_mac_phy_invalid_req[3], mac_phy_rxeqeval: ctrlc_mac_phy_rxeqeval[3], mac_phy_fs: ctrlc_mac_phy_fs[3], mac_phy_lf: ctrlc_mac_phy_lf[3], mac_phy_dirchange: ctrlc_mac_phy_dirchange[3], mac_phy_rxeqinprogress: ctrlc_mac_phy_rxeqinprogress[3]};
    assign w_ctrlc_mac2phy[4] = '{mac_phy_txdata: ctrlc_mac_phy_txdata[4], mac_phy_txdatak: ctrlc_mac_phy_txdatak[4], mac_phy_txdatavalid: ctrlc_mac_phy_txdatavalid[4], mac_phy_txstartblock: ctrlc_mac_phy_txstartblock[4], mac_phy_txsyncheader: ctrlc_mac_phy_txsyncheader[4], mac_phy_txdetectrx_loopback: ctrlc_mac_phy_txdetectrx_loopback[4], mac_phy_txelecidle: ctrlc_mac_phy_txelecidle[4], mac_phy_txcompliance: ctrlc_mac_phy_txcompliance[4], mac_phy_txdeemph: ctrlc_mac_phy_txdeemph[4], mac_phy_rxpolarity: ctrlc_mac_phy_rxpolarity[4], mac_phy_rxstandby: ctrlc_mac_phy_rxstandby[4], mac_phy_messagebus: ctrlc_mac_phy_messagebus[4], mac_phy_rxpresethint: ctrlc_mac_phy_rxpresethint[4], mac_phy_local_pset_index: ctrlc_mac_phy_local_pset_index[4], mac_phy_getlocal_pset_coef: ctrlc_mac_phy_getlocal_pset_coef[4], mac_phy_invalid_req: ctrlc_mac_phy_invalid_req[4], mac_phy_rxeqeval: ctrlc_mac_phy_rxeqeval[4], mac_phy_fs: ctrlc_mac_phy_fs[4], mac_phy_lf: ctrlc_mac_phy_lf[4], mac_phy_dirchange: ctrlc_mac_phy_dirchange[4], mac_phy_rxeqinprogress: ctrlc_mac_phy_rxeqinprogress[4]};
    assign w_ctrlc_mac2phy[5] = '{mac_phy_txdata: ctrlc_mac_phy_txdata[5], mac_phy_txdatak: ctrlc_mac_phy_txdatak[5], mac_phy_txdatavalid: ctrlc_mac_phy_txdatavalid[5], mac_phy_txstartblock: ctrlc_mac_phy_txstartblock[5], mac_phy_txsyncheader: ctrlc_mac_phy_txsyncheader[5], mac_phy_txdetectrx_loopback: ctrlc_mac_phy_txdetectrx_loopback[5], mac_phy_txelecidle: ctrlc_mac_phy_txelecidle[5], mac_phy_txcompliance: ctrlc_mac_phy_txcompliance[5], mac_phy_txdeemph: ctrlc_mac_phy_txdeemph[5], mac_phy_rxpolarity: ctrlc_mac_phy_rxpolarity[5], mac_phy_rxstandby: ctrlc_mac_phy_rxstandby[5], mac_phy_messagebus: ctrlc_mac_phy_messagebus[5], mac_phy_rxpresethint: ctrlc_mac_phy_rxpresethint[5], mac_phy_local_pset_index: ctrlc_mac_phy_local_pset_index[5], mac_phy_getlocal_pset_coef: ctrlc_mac_phy_getlocal_pset_coef[5], mac_phy_invalid_req: ctrlc_mac_phy_invalid_req[5], mac_phy_rxeqeval: ctrlc_mac_phy_rxeqeval[5], mac_phy_fs: ctrlc_mac_phy_fs[5], mac_phy_lf: ctrlc_mac_phy_lf[5], mac_phy_dirchange: ctrlc_mac_phy_dirchange[5], mac_phy_rxeqinprogress: ctrlc_mac_phy_rxeqinprogress[5]};
    assign w_ctrlc_mac2phy[6] = '{mac_phy_txdata: ctrlc_mac_phy_txdata[6], mac_phy_txdatak: ctrlc_mac_phy_txdatak[6], mac_phy_txdatavalid: ctrlc_mac_phy_txdatavalid[6], mac_phy_txstartblock: ctrlc_mac_phy_txstartblock[6], mac_phy_txsyncheader: ctrlc_mac_phy_txsyncheader[6], mac_phy_txdetectrx_loopback: ctrlc_mac_phy_txdetectrx_loopback[6], mac_phy_txelecidle: ctrlc_mac_phy_txelecidle[6], mac_phy_txcompliance: ctrlc_mac_phy_txcompliance[6], mac_phy_txdeemph: ctrlc_mac_phy_txdeemph[6], mac_phy_rxpolarity: ctrlc_mac_phy_rxpolarity[6], mac_phy_rxstandby: ctrlc_mac_phy_rxstandby[6], mac_phy_messagebus: ctrlc_mac_phy_messagebus[6], mac_phy_rxpresethint: ctrlc_mac_phy_rxpresethint[6], mac_phy_local_pset_index: ctrlc_mac_phy_local_pset_index[6], mac_phy_getlocal_pset_coef: ctrlc_mac_phy_getlocal_pset_coef[6], mac_phy_invalid_req: ctrlc_mac_phy_invalid_req[6], mac_phy_rxeqeval: ctrlc_mac_phy_rxeqeval[6], mac_phy_fs: ctrlc_mac_phy_fs[6], mac_phy_lf: ctrlc_mac_phy_lf[6], mac_phy_dirchange: ctrlc_mac_phy_dirchange[6], mac_phy_rxeqinprogress: ctrlc_mac_phy_rxeqinprogress[6]};
    assign w_ctrlc_mac2phy[7] = '{mac_phy_txdata: ctrlc_mac_phy_txdata[7], mac_phy_txdatak: ctrlc_mac_phy_txdatak[7], mac_phy_txdatavalid: ctrlc_mac_phy_txdatavalid[7], mac_phy_txstartblock: ctrlc_mac_phy_txstartblock[7], mac_phy_txsyncheader: ctrlc_mac_phy_txsyncheader[7], mac_phy_txdetectrx_loopback: ctrlc_mac_phy_txdetectrx_loopback[7], mac_phy_txelecidle: ctrlc_mac_phy_txelecidle[7], mac_phy_txcompliance: ctrlc_mac_phy_txcompliance[7], mac_phy_txdeemph: ctrlc_mac_phy_txdeemph[7], mac_phy_rxpolarity: ctrlc_mac_phy_rxpolarity[7], mac_phy_rxstandby: ctrlc_mac_phy_rxstandby[7], mac_phy_messagebus: ctrlc_mac_phy_messagebus[7], mac_phy_rxpresethint: ctrlc_mac_phy_rxpresethint[7], mac_phy_local_pset_index: ctrlc_mac_phy_local_pset_index[7], mac_phy_getlocal_pset_coef: ctrlc_mac_phy_getlocal_pset_coef[7], mac_phy_invalid_req: ctrlc_mac_phy_invalid_req[7], mac_phy_rxeqeval: ctrlc_mac_phy_rxeqeval[7], mac_phy_fs: ctrlc_mac_phy_fs[7], mac_phy_lf: ctrlc_mac_phy_lf[7], mac_phy_dirchange: ctrlc_mac_phy_dirchange[7], mac_phy_rxeqinprogress: ctrlc_mac_phy_rxeqinprogress[7]};
    assign ctrlc_phy_mac_rxdata[0] = w_ctrlc_phy2mac[0].phy_mac_rxdata;
    assign ctrlc_phy_mac_rxdata[1] = w_ctrlc_phy2mac[1].phy_mac_rxdata;
    assign ctrlc_phy_mac_rxdata[2] = w_ctrlc_phy2mac[2].phy_mac_rxdata;
    assign ctrlc_phy_mac_rxdata[3] = w_ctrlc_phy2mac[3].phy_mac_rxdata;
    assign ctrlc_phy_mac_rxdata[4] = w_ctrlc_phy2mac[4].phy_mac_rxdata;
    assign ctrlc_phy_mac_rxdata[5] = w_ctrlc_phy2mac[5].phy_mac_rxdata;
    assign ctrlc_phy_mac_rxdata[6] = w_ctrlc_phy2mac[6].phy_mac_rxdata;
    assign ctrlc_phy_mac_rxdata[7] = w_ctrlc_phy2mac[7].phy_mac_rxdata;
    assign ctrlc_phy_mac_rxdatak[0] = w_ctrlc_phy2mac[0].phy_mac_rxdatak;
    assign ctrlc_phy_mac_rxdatak[1] = w_ctrlc_phy2mac[1].phy_mac_rxdatak;
    assign ctrlc_phy_mac_rxdatak[2] = w_ctrlc_phy2mac[2].phy_mac_rxdatak;
    assign ctrlc_phy_mac_rxdatak[3] = w_ctrlc_phy2mac[3].phy_mac_rxdatak;
    assign ctrlc_phy_mac_rxdatak[4] = w_ctrlc_phy2mac[4].phy_mac_rxdatak;
    assign ctrlc_phy_mac_rxdatak[5] = w_ctrlc_phy2mac[5].phy_mac_rxdatak;
    assign ctrlc_phy_mac_rxdatak[6] = w_ctrlc_phy2mac[6].phy_mac_rxdatak;
    assign ctrlc_phy_mac_rxdatak[7] = w_ctrlc_phy2mac[7].phy_mac_rxdatak;
    assign ctrlc_phy_mac_rxdatavalid[0] = w_ctrlc_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrlc_phy_mac_rxdatavalid[1] = w_ctrlc_phy2mac[1].phy_mac_rxdatavalid;
    assign ctrlc_phy_mac_rxdatavalid[2] = w_ctrlc_phy2mac[2].phy_mac_rxdatavalid;
    assign ctrlc_phy_mac_rxdatavalid[3] = w_ctrlc_phy2mac[3].phy_mac_rxdatavalid;
    assign ctrlc_phy_mac_rxdatavalid[4] = w_ctrlc_phy2mac[4].phy_mac_rxdatavalid;
    assign ctrlc_phy_mac_rxdatavalid[5] = w_ctrlc_phy2mac[5].phy_mac_rxdatavalid;
    assign ctrlc_phy_mac_rxdatavalid[6] = w_ctrlc_phy2mac[6].phy_mac_rxdatavalid;
    assign ctrlc_phy_mac_rxdatavalid[7] = w_ctrlc_phy2mac[7].phy_mac_rxdatavalid;
    assign ctrlc_phy_mac_rxstartblock[0] = w_ctrlc_phy2mac[0].phy_mac_rxstartblock;
    assign ctrlc_phy_mac_rxstartblock[1] = w_ctrlc_phy2mac[1].phy_mac_rxstartblock;
    assign ctrlc_phy_mac_rxstartblock[2] = w_ctrlc_phy2mac[2].phy_mac_rxstartblock;
    assign ctrlc_phy_mac_rxstartblock[3] = w_ctrlc_phy2mac[3].phy_mac_rxstartblock;
    assign ctrlc_phy_mac_rxstartblock[4] = w_ctrlc_phy2mac[4].phy_mac_rxstartblock;
    assign ctrlc_phy_mac_rxstartblock[5] = w_ctrlc_phy2mac[5].phy_mac_rxstartblock;
    assign ctrlc_phy_mac_rxstartblock[6] = w_ctrlc_phy2mac[6].phy_mac_rxstartblock;
    assign ctrlc_phy_mac_rxstartblock[7] = w_ctrlc_phy2mac[7].phy_mac_rxstartblock;
    assign ctrlc_phy_mac_rxsyncheader[0] = w_ctrlc_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrlc_phy_mac_rxsyncheader[1] = w_ctrlc_phy2mac[1].phy_mac_rxsyncheader;
    assign ctrlc_phy_mac_rxsyncheader[2] = w_ctrlc_phy2mac[2].phy_mac_rxsyncheader;
    assign ctrlc_phy_mac_rxsyncheader[3] = w_ctrlc_phy2mac[3].phy_mac_rxsyncheader;
    assign ctrlc_phy_mac_rxsyncheader[4] = w_ctrlc_phy2mac[4].phy_mac_rxsyncheader;
    assign ctrlc_phy_mac_rxsyncheader[5] = w_ctrlc_phy2mac[5].phy_mac_rxsyncheader;
    assign ctrlc_phy_mac_rxsyncheader[6] = w_ctrlc_phy2mac[6].phy_mac_rxsyncheader;
    assign ctrlc_phy_mac_rxsyncheader[7] = w_ctrlc_phy2mac[7].phy_mac_rxsyncheader;
    assign ctrlc_phy_mac_rxvalid[0] = w_ctrlc_phy2mac[0].phy_mac_rxvalid;
    assign ctrlc_phy_mac_rxvalid[1] = w_ctrlc_phy2mac[1].phy_mac_rxvalid;
    assign ctrlc_phy_mac_rxvalid[2] = w_ctrlc_phy2mac[2].phy_mac_rxvalid;
    assign ctrlc_phy_mac_rxvalid[3] = w_ctrlc_phy2mac[3].phy_mac_rxvalid;
    assign ctrlc_phy_mac_rxvalid[4] = w_ctrlc_phy2mac[4].phy_mac_rxvalid;
    assign ctrlc_phy_mac_rxvalid[5] = w_ctrlc_phy2mac[5].phy_mac_rxvalid;
    assign ctrlc_phy_mac_rxvalid[6] = w_ctrlc_phy2mac[6].phy_mac_rxvalid;
    assign ctrlc_phy_mac_rxvalid[7] = w_ctrlc_phy2mac[7].phy_mac_rxvalid;
    assign ctrlc_phy_mac_rxstatus[0] = w_ctrlc_phy2mac[0].phy_mac_rxstatus;
    assign ctrlc_phy_mac_rxstatus[1] = w_ctrlc_phy2mac[1].phy_mac_rxstatus;
    assign ctrlc_phy_mac_rxstatus[2] = w_ctrlc_phy2mac[2].phy_mac_rxstatus;
    assign ctrlc_phy_mac_rxstatus[3] = w_ctrlc_phy2mac[3].phy_mac_rxstatus;
    assign ctrlc_phy_mac_rxstatus[4] = w_ctrlc_phy2mac[4].phy_mac_rxstatus;
    assign ctrlc_phy_mac_rxstatus[5] = w_ctrlc_phy2mac[5].phy_mac_rxstatus;
    assign ctrlc_phy_mac_rxstatus[6] = w_ctrlc_phy2mac[6].phy_mac_rxstatus;
    assign ctrlc_phy_mac_rxstatus[7] = w_ctrlc_phy2mac[7].phy_mac_rxstatus;
    assign ctrlc_phy_mac_rxelecidle[0] = w_ctrlc_phy2mac[0].phy_mac_rxelecidle;
    assign ctrlc_phy_mac_rxelecidle[1] = w_ctrlc_phy2mac[1].phy_mac_rxelecidle;
    assign ctrlc_phy_mac_rxelecidle[2] = w_ctrlc_phy2mac[2].phy_mac_rxelecidle;
    assign ctrlc_phy_mac_rxelecidle[3] = w_ctrlc_phy2mac[3].phy_mac_rxelecidle;
    assign ctrlc_phy_mac_rxelecidle[4] = w_ctrlc_phy2mac[4].phy_mac_rxelecidle;
    assign ctrlc_phy_mac_rxelecidle[5] = w_ctrlc_phy2mac[5].phy_mac_rxelecidle;
    assign ctrlc_phy_mac_rxelecidle[6] = w_ctrlc_phy2mac[6].phy_mac_rxelecidle;
    assign ctrlc_phy_mac_rxelecidle[7] = w_ctrlc_phy2mac[7].phy_mac_rxelecidle;
    assign ctrlc_phy_mac_rxstandbystatus[0] = w_ctrlc_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrlc_phy_mac_rxstandbystatus[1] = w_ctrlc_phy2mac[1].phy_mac_rxstandbystatus;
    assign ctrlc_phy_mac_rxstandbystatus[2] = w_ctrlc_phy2mac[2].phy_mac_rxstandbystatus;
    assign ctrlc_phy_mac_rxstandbystatus[3] = w_ctrlc_phy2mac[3].phy_mac_rxstandbystatus;
    assign ctrlc_phy_mac_rxstandbystatus[4] = w_ctrlc_phy2mac[4].phy_mac_rxstandbystatus;
    assign ctrlc_phy_mac_rxstandbystatus[5] = w_ctrlc_phy2mac[5].phy_mac_rxstandbystatus;
    assign ctrlc_phy_mac_rxstandbystatus[6] = w_ctrlc_phy2mac[6].phy_mac_rxstandbystatus;
    assign ctrlc_phy_mac_rxstandbystatus[7] = w_ctrlc_phy2mac[7].phy_mac_rxstandbystatus;
    assign ctrlc_phy_mac_messagebus[0] = w_ctrlc_phy2mac[0].phy_mac_messagebus;
    assign ctrlc_phy_mac_messagebus[1] = w_ctrlc_phy2mac[1].phy_mac_messagebus;
    assign ctrlc_phy_mac_messagebus[2] = w_ctrlc_phy2mac[2].phy_mac_messagebus;
    assign ctrlc_phy_mac_messagebus[3] = w_ctrlc_phy2mac[3].phy_mac_messagebus;
    assign ctrlc_phy_mac_messagebus[4] = w_ctrlc_phy2mac[4].phy_mac_messagebus;
    assign ctrlc_phy_mac_messagebus[5] = w_ctrlc_phy2mac[5].phy_mac_messagebus;
    assign ctrlc_phy_mac_messagebus[6] = w_ctrlc_phy2mac[6].phy_mac_messagebus;
    assign ctrlc_phy_mac_messagebus[7] = w_ctrlc_phy2mac[7].phy_mac_messagebus;
    assign ctrlc_phy_mac_phystatus[0] = w_ctrlc_phy2mac[0].phy_mac_phystatus;
    assign ctrlc_phy_mac_phystatus[1] = w_ctrlc_phy2mac[1].phy_mac_phystatus;
    assign ctrlc_phy_mac_phystatus[2] = w_ctrlc_phy2mac[2].phy_mac_phystatus;
    assign ctrlc_phy_mac_phystatus[3] = w_ctrlc_phy2mac[3].phy_mac_phystatus;
    assign ctrlc_phy_mac_phystatus[4] = w_ctrlc_phy2mac[4].phy_mac_phystatus;
    assign ctrlc_phy_mac_phystatus[5] = w_ctrlc_phy2mac[5].phy_mac_phystatus;
    assign ctrlc_phy_mac_phystatus[6] = w_ctrlc_phy2mac[6].phy_mac_phystatus;
    assign ctrlc_phy_mac_phystatus[7] = w_ctrlc_phy2mac[7].phy_mac_phystatus;
    assign ctrlc_phy_mac_local_tx_coef_valid[0] = w_ctrlc_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrlc_phy_mac_local_tx_coef_valid[1] = w_ctrlc_phy2mac[1].phy_mac_local_tx_coef_valid;
    assign ctrlc_phy_mac_local_tx_coef_valid[2] = w_ctrlc_phy2mac[2].phy_mac_local_tx_coef_valid;
    assign ctrlc_phy_mac_local_tx_coef_valid[3] = w_ctrlc_phy2mac[3].phy_mac_local_tx_coef_valid;
    assign ctrlc_phy_mac_local_tx_coef_valid[4] = w_ctrlc_phy2mac[4].phy_mac_local_tx_coef_valid;
    assign ctrlc_phy_mac_local_tx_coef_valid[5] = w_ctrlc_phy2mac[5].phy_mac_local_tx_coef_valid;
    assign ctrlc_phy_mac_local_tx_coef_valid[6] = w_ctrlc_phy2mac[6].phy_mac_local_tx_coef_valid;
    assign ctrlc_phy_mac_local_tx_coef_valid[7] = w_ctrlc_phy2mac[7].phy_mac_local_tx_coef_valid;
    assign ctrlc_phy_mac_local_tx_pset_coef[0] = w_ctrlc_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrlc_phy_mac_local_tx_pset_coef[1] = w_ctrlc_phy2mac[1].phy_mac_local_tx_pset_coef;
    assign ctrlc_phy_mac_local_tx_pset_coef[2] = w_ctrlc_phy2mac[2].phy_mac_local_tx_pset_coef;
    assign ctrlc_phy_mac_local_tx_pset_coef[3] = w_ctrlc_phy2mac[3].phy_mac_local_tx_pset_coef;
    assign ctrlc_phy_mac_local_tx_pset_coef[4] = w_ctrlc_phy2mac[4].phy_mac_local_tx_pset_coef;
    assign ctrlc_phy_mac_local_tx_pset_coef[5] = w_ctrlc_phy2mac[5].phy_mac_local_tx_pset_coef;
    assign ctrlc_phy_mac_local_tx_pset_coef[6] = w_ctrlc_phy2mac[6].phy_mac_local_tx_pset_coef;
    assign ctrlc_phy_mac_local_tx_pset_coef[7] = w_ctrlc_phy2mac[7].phy_mac_local_tx_pset_coef;
    assign ctrlc_phy_mac_localfs[0] = w_ctrlc_phy2mac[0].phy_mac_localfs;
    assign ctrlc_phy_mac_localfs[1] = w_ctrlc_phy2mac[1].phy_mac_localfs;
    assign ctrlc_phy_mac_localfs[2] = w_ctrlc_phy2mac[2].phy_mac_localfs;
    assign ctrlc_phy_mac_localfs[3] = w_ctrlc_phy2mac[3].phy_mac_localfs;
    assign ctrlc_phy_mac_localfs[4] = w_ctrlc_phy2mac[4].phy_mac_localfs;
    assign ctrlc_phy_mac_localfs[5] = w_ctrlc_phy2mac[5].phy_mac_localfs;
    assign ctrlc_phy_mac_localfs[6] = w_ctrlc_phy2mac[6].phy_mac_localfs;
    assign ctrlc_phy_mac_localfs[7] = w_ctrlc_phy2mac[7].phy_mac_localfs;
    assign ctrlc_phy_mac_locallf[0] = w_ctrlc_phy2mac[0].phy_mac_locallf;
    assign ctrlc_phy_mac_locallf[1] = w_ctrlc_phy2mac[1].phy_mac_locallf;
    assign ctrlc_phy_mac_locallf[2] = w_ctrlc_phy2mac[2].phy_mac_locallf;
    assign ctrlc_phy_mac_locallf[3] = w_ctrlc_phy2mac[3].phy_mac_locallf;
    assign ctrlc_phy_mac_locallf[4] = w_ctrlc_phy2mac[4].phy_mac_locallf;
    assign ctrlc_phy_mac_locallf[5] = w_ctrlc_phy2mac[5].phy_mac_locallf;
    assign ctrlc_phy_mac_locallf[6] = w_ctrlc_phy2mac[6].phy_mac_locallf;
    assign ctrlc_phy_mac_locallf[7] = w_ctrlc_phy2mac[7].phy_mac_locallf;
    assign ctrlc_phy_mac_dirfeedback[0] = w_ctrlc_phy2mac[0].phy_mac_dirfeedback;
    assign ctrlc_phy_mac_dirfeedback[1] = w_ctrlc_phy2mac[1].phy_mac_dirfeedback;
    assign ctrlc_phy_mac_dirfeedback[2] = w_ctrlc_phy2mac[2].phy_mac_dirfeedback;
    assign ctrlc_phy_mac_dirfeedback[3] = w_ctrlc_phy2mac[3].phy_mac_dirfeedback;
    assign ctrlc_phy_mac_dirfeedback[4] = w_ctrlc_phy2mac[4].phy_mac_dirfeedback;
    assign ctrlc_phy_mac_dirfeedback[5] = w_ctrlc_phy2mac[5].phy_mac_dirfeedback;
    assign ctrlc_phy_mac_dirfeedback[6] = w_ctrlc_phy2mac[6].phy_mac_dirfeedback;
    assign ctrlc_phy_mac_dirfeedback[7] = w_ctrlc_phy2mac[7].phy_mac_dirfeedback;
    assign ctrlc_phy_mac_fomfeedback[0] = w_ctrlc_phy2mac[0].phy_mac_fomfeedback;
    assign ctrlc_phy_mac_fomfeedback[1] = w_ctrlc_phy2mac[1].phy_mac_fomfeedback;
    assign ctrlc_phy_mac_fomfeedback[2] = w_ctrlc_phy2mac[2].phy_mac_fomfeedback;
    assign ctrlc_phy_mac_fomfeedback[3] = w_ctrlc_phy2mac[3].phy_mac_fomfeedback;
    assign ctrlc_phy_mac_fomfeedback[4] = w_ctrlc_phy2mac[4].phy_mac_fomfeedback;
    assign ctrlc_phy_mac_fomfeedback[5] = w_ctrlc_phy2mac[5].phy_mac_fomfeedback;
    assign ctrlc_phy_mac_fomfeedback[6] = w_ctrlc_phy2mac[6].phy_mac_fomfeedback;
    assign ctrlc_phy_mac_fomfeedback[7] = w_ctrlc_phy2mac[7].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // CtrlD (x3)
    //------------------------------------------------------------
    assign w_ctrld_mac2phy[0] = '{mac_phy_txdata: ctrld_mac_phy_txdata[0], mac_phy_txdatak: ctrld_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrld_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrld_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrld_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrld_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrld_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrld_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrld_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrld_mac_phy_rxpolarity[0], mac_phy_rxstandby: ctrld_mac_phy_rxstandby[0], mac_phy_messagebus: ctrld_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrld_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrld_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrld_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrld_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrld_mac_phy_rxeqeval[0], mac_phy_fs: ctrld_mac_phy_fs[0], mac_phy_lf: ctrld_mac_phy_lf[0], mac_phy_dirchange: ctrld_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrld_mac_phy_rxeqinprogress[0]};
    assign w_ctrld_mac2phy[1] = '{mac_phy_txdata: ctrld_mac_phy_txdata[1], mac_phy_txdatak: ctrld_mac_phy_txdatak[1], mac_phy_txdatavalid: ctrld_mac_phy_txdatavalid[1], mac_phy_txstartblock: ctrld_mac_phy_txstartblock[1], mac_phy_txsyncheader: ctrld_mac_phy_txsyncheader[1], mac_phy_txdetectrx_loopback: ctrld_mac_phy_txdetectrx_loopback[1], mac_phy_txelecidle: ctrld_mac_phy_txelecidle[1], mac_phy_txcompliance: ctrld_mac_phy_txcompliance[1], mac_phy_txdeemph: ctrld_mac_phy_txdeemph[1], mac_phy_rxpolarity: ctrld_mac_phy_rxpolarity[1], mac_phy_rxstandby: ctrld_mac_phy_rxstandby[1], mac_phy_messagebus: ctrld_mac_phy_messagebus[1], mac_phy_rxpresethint: ctrld_mac_phy_rxpresethint[1], mac_phy_local_pset_index: ctrld_mac_phy_local_pset_index[1], mac_phy_getlocal_pset_coef: ctrld_mac_phy_getlocal_pset_coef[1], mac_phy_invalid_req: ctrld_mac_phy_invalid_req[1], mac_phy_rxeqeval: ctrld_mac_phy_rxeqeval[1], mac_phy_fs: ctrld_mac_phy_fs[1], mac_phy_lf: ctrld_mac_phy_lf[1], mac_phy_dirchange: ctrld_mac_phy_dirchange[1], mac_phy_rxeqinprogress: ctrld_mac_phy_rxeqinprogress[1]};
    assign w_ctrld_mac2phy[2] = '{mac_phy_txdata: ctrld_mac_phy_txdata[2], mac_phy_txdatak: ctrld_mac_phy_txdatak[2], mac_phy_txdatavalid: ctrld_mac_phy_txdatavalid[2], mac_phy_txstartblock: ctrld_mac_phy_txstartblock[2], mac_phy_txsyncheader: ctrld_mac_phy_txsyncheader[2], mac_phy_txdetectrx_loopback: ctrld_mac_phy_txdetectrx_loopback[2], mac_phy_txelecidle: ctrld_mac_phy_txelecidle[2], mac_phy_txcompliance: ctrld_mac_phy_txcompliance[2], mac_phy_txdeemph: ctrld_mac_phy_txdeemph[2], mac_phy_rxpolarity: ctrld_mac_phy_rxpolarity[2], mac_phy_rxstandby: ctrld_mac_phy_rxstandby[2], mac_phy_messagebus: ctrld_mac_phy_messagebus[2], mac_phy_rxpresethint: ctrld_mac_phy_rxpresethint[2], mac_phy_local_pset_index: ctrld_mac_phy_local_pset_index[2], mac_phy_getlocal_pset_coef: ctrld_mac_phy_getlocal_pset_coef[2], mac_phy_invalid_req: ctrld_mac_phy_invalid_req[2], mac_phy_rxeqeval: ctrld_mac_phy_rxeqeval[2], mac_phy_fs: ctrld_mac_phy_fs[2], mac_phy_lf: ctrld_mac_phy_lf[2], mac_phy_dirchange: ctrld_mac_phy_dirchange[2], mac_phy_rxeqinprogress: ctrld_mac_phy_rxeqinprogress[2]};
    assign ctrld_phy_mac_rxdata[0] = w_ctrld_phy2mac[0].phy_mac_rxdata;
    assign ctrld_phy_mac_rxdata[1] = w_ctrld_phy2mac[1].phy_mac_rxdata;
    assign ctrld_phy_mac_rxdata[2] = w_ctrld_phy2mac[2].phy_mac_rxdata;
    assign ctrld_phy_mac_rxdatak[0] = w_ctrld_phy2mac[0].phy_mac_rxdatak;
    assign ctrld_phy_mac_rxdatak[1] = w_ctrld_phy2mac[1].phy_mac_rxdatak;
    assign ctrld_phy_mac_rxdatak[2] = w_ctrld_phy2mac[2].phy_mac_rxdatak;
    assign ctrld_phy_mac_rxdatavalid[0] = w_ctrld_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrld_phy_mac_rxdatavalid[1] = w_ctrld_phy2mac[1].phy_mac_rxdatavalid;
    assign ctrld_phy_mac_rxdatavalid[2] = w_ctrld_phy2mac[2].phy_mac_rxdatavalid;
    assign ctrld_phy_mac_rxstartblock[0] = w_ctrld_phy2mac[0].phy_mac_rxstartblock;
    assign ctrld_phy_mac_rxstartblock[1] = w_ctrld_phy2mac[1].phy_mac_rxstartblock;
    assign ctrld_phy_mac_rxstartblock[2] = w_ctrld_phy2mac[2].phy_mac_rxstartblock;
    assign ctrld_phy_mac_rxsyncheader[0] = w_ctrld_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrld_phy_mac_rxsyncheader[1] = w_ctrld_phy2mac[1].phy_mac_rxsyncheader;
    assign ctrld_phy_mac_rxsyncheader[2] = w_ctrld_phy2mac[2].phy_mac_rxsyncheader;
    assign ctrld_phy_mac_rxvalid[0] = w_ctrld_phy2mac[0].phy_mac_rxvalid;
    assign ctrld_phy_mac_rxvalid[1] = w_ctrld_phy2mac[1].phy_mac_rxvalid;
    assign ctrld_phy_mac_rxvalid[2] = w_ctrld_phy2mac[2].phy_mac_rxvalid;
    assign ctrld_phy_mac_rxstatus[0] = w_ctrld_phy2mac[0].phy_mac_rxstatus;
    assign ctrld_phy_mac_rxstatus[1] = w_ctrld_phy2mac[1].phy_mac_rxstatus;
    assign ctrld_phy_mac_rxstatus[2] = w_ctrld_phy2mac[2].phy_mac_rxstatus;
    assign ctrld_phy_mac_rxelecidle[0] = w_ctrld_phy2mac[0].phy_mac_rxelecidle;
    assign ctrld_phy_mac_rxelecidle[1] = w_ctrld_phy2mac[1].phy_mac_rxelecidle;
    assign ctrld_phy_mac_rxelecidle[2] = w_ctrld_phy2mac[2].phy_mac_rxelecidle;
    assign ctrld_phy_mac_rxstandbystatus[0] = w_ctrld_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrld_phy_mac_rxstandbystatus[1] = w_ctrld_phy2mac[1].phy_mac_rxstandbystatus;
    assign ctrld_phy_mac_rxstandbystatus[2] = w_ctrld_phy2mac[2].phy_mac_rxstandbystatus;
    assign ctrld_phy_mac_messagebus[0] = w_ctrld_phy2mac[0].phy_mac_messagebus;
    assign ctrld_phy_mac_messagebus[1] = w_ctrld_phy2mac[1].phy_mac_messagebus;
    assign ctrld_phy_mac_messagebus[2] = w_ctrld_phy2mac[2].phy_mac_messagebus;
    assign ctrld_phy_mac_phystatus[0] = w_ctrld_phy2mac[0].phy_mac_phystatus;
    assign ctrld_phy_mac_phystatus[1] = w_ctrld_phy2mac[1].phy_mac_phystatus;
    assign ctrld_phy_mac_phystatus[2] = w_ctrld_phy2mac[2].phy_mac_phystatus;
    assign ctrld_phy_mac_local_tx_coef_valid[0] = w_ctrld_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrld_phy_mac_local_tx_coef_valid[1] = w_ctrld_phy2mac[1].phy_mac_local_tx_coef_valid;
    assign ctrld_phy_mac_local_tx_coef_valid[2] = w_ctrld_phy2mac[2].phy_mac_local_tx_coef_valid;
    assign ctrld_phy_mac_local_tx_pset_coef[0] = w_ctrld_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrld_phy_mac_local_tx_pset_coef[1] = w_ctrld_phy2mac[1].phy_mac_local_tx_pset_coef;
    assign ctrld_phy_mac_local_tx_pset_coef[2] = w_ctrld_phy2mac[2].phy_mac_local_tx_pset_coef;
    assign ctrld_phy_mac_localfs[0] = w_ctrld_phy2mac[0].phy_mac_localfs;
    assign ctrld_phy_mac_localfs[1] = w_ctrld_phy2mac[1].phy_mac_localfs;
    assign ctrld_phy_mac_localfs[2] = w_ctrld_phy2mac[2].phy_mac_localfs;
    assign ctrld_phy_mac_locallf[0] = w_ctrld_phy2mac[0].phy_mac_locallf;
    assign ctrld_phy_mac_locallf[1] = w_ctrld_phy2mac[1].phy_mac_locallf;
    assign ctrld_phy_mac_locallf[2] = w_ctrld_phy2mac[2].phy_mac_locallf;
    assign ctrld_phy_mac_dirfeedback[0] = w_ctrld_phy2mac[0].phy_mac_dirfeedback;
    assign ctrld_phy_mac_dirfeedback[1] = w_ctrld_phy2mac[1].phy_mac_dirfeedback;
    assign ctrld_phy_mac_dirfeedback[2] = w_ctrld_phy2mac[2].phy_mac_dirfeedback;
    assign ctrld_phy_mac_fomfeedback[0] = w_ctrld_phy2mac[0].phy_mac_fomfeedback;
    assign ctrld_phy_mac_fomfeedback[1] = w_ctrld_phy2mac[1].phy_mac_fomfeedback;
    assign ctrld_phy_mac_fomfeedback[2] = w_ctrld_phy2mac[2].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // DPR (x12, one flat port per PHY lane, 1:1)
    //------------------------------------------------------------
    assign w_dpr_mac2phy[0] = '{mac_phy_txdata: dpr_mac_phy_txdata[0], mac_phy_txdatak: dpr_mac_phy_txdatak[0], mac_phy_txdatavalid: dpr_mac_phy_txdatavalid[0], mac_phy_txstartblock: dpr_mac_phy_txstartblock[0], mac_phy_txsyncheader: dpr_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: dpr_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: dpr_mac_phy_txelecidle[0], mac_phy_txcompliance: dpr_mac_phy_txcompliance[0], mac_phy_txdeemph: dpr_mac_phy_txdeemph[0], mac_phy_rxpolarity: dpr_mac_phy_rxpolarity[0], mac_phy_rxstandby: dpr_mac_phy_rxstandby[0], mac_phy_messagebus: dpr_mac_phy_messagebus[0], mac_phy_rxpresethint: dpr_mac_phy_rxpresethint[0], mac_phy_local_pset_index: dpr_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: dpr_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: dpr_mac_phy_invalid_req[0], mac_phy_rxeqeval: dpr_mac_phy_rxeqeval[0], mac_phy_fs: dpr_mac_phy_fs[0], mac_phy_lf: dpr_mac_phy_lf[0], mac_phy_dirchange: dpr_mac_phy_dirchange[0], mac_phy_rxeqinprogress: dpr_mac_phy_rxeqinprogress[0]};
    assign w_dpr_mac2phy[1] = '{mac_phy_txdata: dpr_mac_phy_txdata[1], mac_phy_txdatak: dpr_mac_phy_txdatak[1], mac_phy_txdatavalid: dpr_mac_phy_txdatavalid[1], mac_phy_txstartblock: dpr_mac_phy_txstartblock[1], mac_phy_txsyncheader: dpr_mac_phy_txsyncheader[1], mac_phy_txdetectrx_loopback: dpr_mac_phy_txdetectrx_loopback[1], mac_phy_txelecidle: dpr_mac_phy_txelecidle[1], mac_phy_txcompliance: dpr_mac_phy_txcompliance[1], mac_phy_txdeemph: dpr_mac_phy_txdeemph[1], mac_phy_rxpolarity: dpr_mac_phy_rxpolarity[1], mac_phy_rxstandby: dpr_mac_phy_rxstandby[1], mac_phy_messagebus: dpr_mac_phy_messagebus[1], mac_phy_rxpresethint: dpr_mac_phy_rxpresethint[1], mac_phy_local_pset_index: dpr_mac_phy_local_pset_index[1], mac_phy_getlocal_pset_coef: dpr_mac_phy_getlocal_pset_coef[1], mac_phy_invalid_req: dpr_mac_phy_invalid_req[1], mac_phy_rxeqeval: dpr_mac_phy_rxeqeval[1], mac_phy_fs: dpr_mac_phy_fs[1], mac_phy_lf: dpr_mac_phy_lf[1], mac_phy_dirchange: dpr_mac_phy_dirchange[1], mac_phy_rxeqinprogress: dpr_mac_phy_rxeqinprogress[1]};
    assign w_dpr_mac2phy[2] = '{mac_phy_txdata: dpr_mac_phy_txdata[2], mac_phy_txdatak: dpr_mac_phy_txdatak[2], mac_phy_txdatavalid: dpr_mac_phy_txdatavalid[2], mac_phy_txstartblock: dpr_mac_phy_txstartblock[2], mac_phy_txsyncheader: dpr_mac_phy_txsyncheader[2], mac_phy_txdetectrx_loopback: dpr_mac_phy_txdetectrx_loopback[2], mac_phy_txelecidle: dpr_mac_phy_txelecidle[2], mac_phy_txcompliance: dpr_mac_phy_txcompliance[2], mac_phy_txdeemph: dpr_mac_phy_txdeemph[2], mac_phy_rxpolarity: dpr_mac_phy_rxpolarity[2], mac_phy_rxstandby: dpr_mac_phy_rxstandby[2], mac_phy_messagebus: dpr_mac_phy_messagebus[2], mac_phy_rxpresethint: dpr_mac_phy_rxpresethint[2], mac_phy_local_pset_index: dpr_mac_phy_local_pset_index[2], mac_phy_getlocal_pset_coef: dpr_mac_phy_getlocal_pset_coef[2], mac_phy_invalid_req: dpr_mac_phy_invalid_req[2], mac_phy_rxeqeval: dpr_mac_phy_rxeqeval[2], mac_phy_fs: dpr_mac_phy_fs[2], mac_phy_lf: dpr_mac_phy_lf[2], mac_phy_dirchange: dpr_mac_phy_dirchange[2], mac_phy_rxeqinprogress: dpr_mac_phy_rxeqinprogress[2]};
    assign w_dpr_mac2phy[3] = '{mac_phy_txdata: dpr_mac_phy_txdata[3], mac_phy_txdatak: dpr_mac_phy_txdatak[3], mac_phy_txdatavalid: dpr_mac_phy_txdatavalid[3], mac_phy_txstartblock: dpr_mac_phy_txstartblock[3], mac_phy_txsyncheader: dpr_mac_phy_txsyncheader[3], mac_phy_txdetectrx_loopback: dpr_mac_phy_txdetectrx_loopback[3], mac_phy_txelecidle: dpr_mac_phy_txelecidle[3], mac_phy_txcompliance: dpr_mac_phy_txcompliance[3], mac_phy_txdeemph: dpr_mac_phy_txdeemph[3], mac_phy_rxpolarity: dpr_mac_phy_rxpolarity[3], mac_phy_rxstandby: dpr_mac_phy_rxstandby[3], mac_phy_messagebus: dpr_mac_phy_messagebus[3], mac_phy_rxpresethint: dpr_mac_phy_rxpresethint[3], mac_phy_local_pset_index: dpr_mac_phy_local_pset_index[3], mac_phy_getlocal_pset_coef: dpr_mac_phy_getlocal_pset_coef[3], mac_phy_invalid_req: dpr_mac_phy_invalid_req[3], mac_phy_rxeqeval: dpr_mac_phy_rxeqeval[3], mac_phy_fs: dpr_mac_phy_fs[3], mac_phy_lf: dpr_mac_phy_lf[3], mac_phy_dirchange: dpr_mac_phy_dirchange[3], mac_phy_rxeqinprogress: dpr_mac_phy_rxeqinprogress[3]};
    assign w_dpr_mac2phy[4] = '{mac_phy_txdata: dpr_mac_phy_txdata[4], mac_phy_txdatak: dpr_mac_phy_txdatak[4], mac_phy_txdatavalid: dpr_mac_phy_txdatavalid[4], mac_phy_txstartblock: dpr_mac_phy_txstartblock[4], mac_phy_txsyncheader: dpr_mac_phy_txsyncheader[4], mac_phy_txdetectrx_loopback: dpr_mac_phy_txdetectrx_loopback[4], mac_phy_txelecidle: dpr_mac_phy_txelecidle[4], mac_phy_txcompliance: dpr_mac_phy_txcompliance[4], mac_phy_txdeemph: dpr_mac_phy_txdeemph[4], mac_phy_rxpolarity: dpr_mac_phy_rxpolarity[4], mac_phy_rxstandby: dpr_mac_phy_rxstandby[4], mac_phy_messagebus: dpr_mac_phy_messagebus[4], mac_phy_rxpresethint: dpr_mac_phy_rxpresethint[4], mac_phy_local_pset_index: dpr_mac_phy_local_pset_index[4], mac_phy_getlocal_pset_coef: dpr_mac_phy_getlocal_pset_coef[4], mac_phy_invalid_req: dpr_mac_phy_invalid_req[4], mac_phy_rxeqeval: dpr_mac_phy_rxeqeval[4], mac_phy_fs: dpr_mac_phy_fs[4], mac_phy_lf: dpr_mac_phy_lf[4], mac_phy_dirchange: dpr_mac_phy_dirchange[4], mac_phy_rxeqinprogress: dpr_mac_phy_rxeqinprogress[4]};
    assign w_dpr_mac2phy[5] = '{mac_phy_txdata: dpr_mac_phy_txdata[5], mac_phy_txdatak: dpr_mac_phy_txdatak[5], mac_phy_txdatavalid: dpr_mac_phy_txdatavalid[5], mac_phy_txstartblock: dpr_mac_phy_txstartblock[5], mac_phy_txsyncheader: dpr_mac_phy_txsyncheader[5], mac_phy_txdetectrx_loopback: dpr_mac_phy_txdetectrx_loopback[5], mac_phy_txelecidle: dpr_mac_phy_txelecidle[5], mac_phy_txcompliance: dpr_mac_phy_txcompliance[5], mac_phy_txdeemph: dpr_mac_phy_txdeemph[5], mac_phy_rxpolarity: dpr_mac_phy_rxpolarity[5], mac_phy_rxstandby: dpr_mac_phy_rxstandby[5], mac_phy_messagebus: dpr_mac_phy_messagebus[5], mac_phy_rxpresethint: dpr_mac_phy_rxpresethint[5], mac_phy_local_pset_index: dpr_mac_phy_local_pset_index[5], mac_phy_getlocal_pset_coef: dpr_mac_phy_getlocal_pset_coef[5], mac_phy_invalid_req: dpr_mac_phy_invalid_req[5], mac_phy_rxeqeval: dpr_mac_phy_rxeqeval[5], mac_phy_fs: dpr_mac_phy_fs[5], mac_phy_lf: dpr_mac_phy_lf[5], mac_phy_dirchange: dpr_mac_phy_dirchange[5], mac_phy_rxeqinprogress: dpr_mac_phy_rxeqinprogress[5]};
    assign w_dpr_mac2phy[6] = '{mac_phy_txdata: dpr_mac_phy_txdata[6], mac_phy_txdatak: dpr_mac_phy_txdatak[6], mac_phy_txdatavalid: dpr_mac_phy_txdatavalid[6], mac_phy_txstartblock: dpr_mac_phy_txstartblock[6], mac_phy_txsyncheader: dpr_mac_phy_txsyncheader[6], mac_phy_txdetectrx_loopback: dpr_mac_phy_txdetectrx_loopback[6], mac_phy_txelecidle: dpr_mac_phy_txelecidle[6], mac_phy_txcompliance: dpr_mac_phy_txcompliance[6], mac_phy_txdeemph: dpr_mac_phy_txdeemph[6], mac_phy_rxpolarity: dpr_mac_phy_rxpolarity[6], mac_phy_rxstandby: dpr_mac_phy_rxstandby[6], mac_phy_messagebus: dpr_mac_phy_messagebus[6], mac_phy_rxpresethint: dpr_mac_phy_rxpresethint[6], mac_phy_local_pset_index: dpr_mac_phy_local_pset_index[6], mac_phy_getlocal_pset_coef: dpr_mac_phy_getlocal_pset_coef[6], mac_phy_invalid_req: dpr_mac_phy_invalid_req[6], mac_phy_rxeqeval: dpr_mac_phy_rxeqeval[6], mac_phy_fs: dpr_mac_phy_fs[6], mac_phy_lf: dpr_mac_phy_lf[6], mac_phy_dirchange: dpr_mac_phy_dirchange[6], mac_phy_rxeqinprogress: dpr_mac_phy_rxeqinprogress[6]};
    assign w_dpr_mac2phy[7] = '{mac_phy_txdata: dpr_mac_phy_txdata[7], mac_phy_txdatak: dpr_mac_phy_txdatak[7], mac_phy_txdatavalid: dpr_mac_phy_txdatavalid[7], mac_phy_txstartblock: dpr_mac_phy_txstartblock[7], mac_phy_txsyncheader: dpr_mac_phy_txsyncheader[7], mac_phy_txdetectrx_loopback: dpr_mac_phy_txdetectrx_loopback[7], mac_phy_txelecidle: dpr_mac_phy_txelecidle[7], mac_phy_txcompliance: dpr_mac_phy_txcompliance[7], mac_phy_txdeemph: dpr_mac_phy_txdeemph[7], mac_phy_rxpolarity: dpr_mac_phy_rxpolarity[7], mac_phy_rxstandby: dpr_mac_phy_rxstandby[7], mac_phy_messagebus: dpr_mac_phy_messagebus[7], mac_phy_rxpresethint: dpr_mac_phy_rxpresethint[7], mac_phy_local_pset_index: dpr_mac_phy_local_pset_index[7], mac_phy_getlocal_pset_coef: dpr_mac_phy_getlocal_pset_coef[7], mac_phy_invalid_req: dpr_mac_phy_invalid_req[7], mac_phy_rxeqeval: dpr_mac_phy_rxeqeval[7], mac_phy_fs: dpr_mac_phy_fs[7], mac_phy_lf: dpr_mac_phy_lf[7], mac_phy_dirchange: dpr_mac_phy_dirchange[7], mac_phy_rxeqinprogress: dpr_mac_phy_rxeqinprogress[7]};
    assign w_dpr_mac2phy[8] = '{mac_phy_txdata: dpr_mac_phy_txdata[8], mac_phy_txdatak: dpr_mac_phy_txdatak[8], mac_phy_txdatavalid: dpr_mac_phy_txdatavalid[8], mac_phy_txstartblock: dpr_mac_phy_txstartblock[8], mac_phy_txsyncheader: dpr_mac_phy_txsyncheader[8], mac_phy_txdetectrx_loopback: dpr_mac_phy_txdetectrx_loopback[8], mac_phy_txelecidle: dpr_mac_phy_txelecidle[8], mac_phy_txcompliance: dpr_mac_phy_txcompliance[8], mac_phy_txdeemph: dpr_mac_phy_txdeemph[8], mac_phy_rxpolarity: dpr_mac_phy_rxpolarity[8], mac_phy_rxstandby: dpr_mac_phy_rxstandby[8], mac_phy_messagebus: dpr_mac_phy_messagebus[8], mac_phy_rxpresethint: dpr_mac_phy_rxpresethint[8], mac_phy_local_pset_index: dpr_mac_phy_local_pset_index[8], mac_phy_getlocal_pset_coef: dpr_mac_phy_getlocal_pset_coef[8], mac_phy_invalid_req: dpr_mac_phy_invalid_req[8], mac_phy_rxeqeval: dpr_mac_phy_rxeqeval[8], mac_phy_fs: dpr_mac_phy_fs[8], mac_phy_lf: dpr_mac_phy_lf[8], mac_phy_dirchange: dpr_mac_phy_dirchange[8], mac_phy_rxeqinprogress: dpr_mac_phy_rxeqinprogress[8]};
    assign w_dpr_mac2phy[9] = '{mac_phy_txdata: dpr_mac_phy_txdata[9], mac_phy_txdatak: dpr_mac_phy_txdatak[9], mac_phy_txdatavalid: dpr_mac_phy_txdatavalid[9], mac_phy_txstartblock: dpr_mac_phy_txstartblock[9], mac_phy_txsyncheader: dpr_mac_phy_txsyncheader[9], mac_phy_txdetectrx_loopback: dpr_mac_phy_txdetectrx_loopback[9], mac_phy_txelecidle: dpr_mac_phy_txelecidle[9], mac_phy_txcompliance: dpr_mac_phy_txcompliance[9], mac_phy_txdeemph: dpr_mac_phy_txdeemph[9], mac_phy_rxpolarity: dpr_mac_phy_rxpolarity[9], mac_phy_rxstandby: dpr_mac_phy_rxstandby[9], mac_phy_messagebus: dpr_mac_phy_messagebus[9], mac_phy_rxpresethint: dpr_mac_phy_rxpresethint[9], mac_phy_local_pset_index: dpr_mac_phy_local_pset_index[9], mac_phy_getlocal_pset_coef: dpr_mac_phy_getlocal_pset_coef[9], mac_phy_invalid_req: dpr_mac_phy_invalid_req[9], mac_phy_rxeqeval: dpr_mac_phy_rxeqeval[9], mac_phy_fs: dpr_mac_phy_fs[9], mac_phy_lf: dpr_mac_phy_lf[9], mac_phy_dirchange: dpr_mac_phy_dirchange[9], mac_phy_rxeqinprogress: dpr_mac_phy_rxeqinprogress[9]};
    assign w_dpr_mac2phy[10] = '{mac_phy_txdata: dpr_mac_phy_txdata[10], mac_phy_txdatak: dpr_mac_phy_txdatak[10], mac_phy_txdatavalid: dpr_mac_phy_txdatavalid[10], mac_phy_txstartblock: dpr_mac_phy_txstartblock[10], mac_phy_txsyncheader: dpr_mac_phy_txsyncheader[10], mac_phy_txdetectrx_loopback: dpr_mac_phy_txdetectrx_loopback[10], mac_phy_txelecidle: dpr_mac_phy_txelecidle[10], mac_phy_txcompliance: dpr_mac_phy_txcompliance[10], mac_phy_txdeemph: dpr_mac_phy_txdeemph[10], mac_phy_rxpolarity: dpr_mac_phy_rxpolarity[10], mac_phy_rxstandby: dpr_mac_phy_rxstandby[10], mac_phy_messagebus: dpr_mac_phy_messagebus[10], mac_phy_rxpresethint: dpr_mac_phy_rxpresethint[10], mac_phy_local_pset_index: dpr_mac_phy_local_pset_index[10], mac_phy_getlocal_pset_coef: dpr_mac_phy_getlocal_pset_coef[10], mac_phy_invalid_req: dpr_mac_phy_invalid_req[10], mac_phy_rxeqeval: dpr_mac_phy_rxeqeval[10], mac_phy_fs: dpr_mac_phy_fs[10], mac_phy_lf: dpr_mac_phy_lf[10], mac_phy_dirchange: dpr_mac_phy_dirchange[10], mac_phy_rxeqinprogress: dpr_mac_phy_rxeqinprogress[10]};
    assign w_dpr_mac2phy[11] = '{mac_phy_txdata: dpr_mac_phy_txdata[11], mac_phy_txdatak: dpr_mac_phy_txdatak[11], mac_phy_txdatavalid: dpr_mac_phy_txdatavalid[11], mac_phy_txstartblock: dpr_mac_phy_txstartblock[11], mac_phy_txsyncheader: dpr_mac_phy_txsyncheader[11], mac_phy_txdetectrx_loopback: dpr_mac_phy_txdetectrx_loopback[11], mac_phy_txelecidle: dpr_mac_phy_txelecidle[11], mac_phy_txcompliance: dpr_mac_phy_txcompliance[11], mac_phy_txdeemph: dpr_mac_phy_txdeemph[11], mac_phy_rxpolarity: dpr_mac_phy_rxpolarity[11], mac_phy_rxstandby: dpr_mac_phy_rxstandby[11], mac_phy_messagebus: dpr_mac_phy_messagebus[11], mac_phy_rxpresethint: dpr_mac_phy_rxpresethint[11], mac_phy_local_pset_index: dpr_mac_phy_local_pset_index[11], mac_phy_getlocal_pset_coef: dpr_mac_phy_getlocal_pset_coef[11], mac_phy_invalid_req: dpr_mac_phy_invalid_req[11], mac_phy_rxeqeval: dpr_mac_phy_rxeqeval[11], mac_phy_fs: dpr_mac_phy_fs[11], mac_phy_lf: dpr_mac_phy_lf[11], mac_phy_dirchange: dpr_mac_phy_dirchange[11], mac_phy_rxeqinprogress: dpr_mac_phy_rxeqinprogress[11]};
    assign dpr_phy_mac_rxdata[0] = w_dpr_phy2mac[0].phy_mac_rxdata;
    assign dpr_phy_mac_rxdata[1] = w_dpr_phy2mac[1].phy_mac_rxdata;
    assign dpr_phy_mac_rxdata[2] = w_dpr_phy2mac[2].phy_mac_rxdata;
    assign dpr_phy_mac_rxdata[3] = w_dpr_phy2mac[3].phy_mac_rxdata;
    assign dpr_phy_mac_rxdata[4] = w_dpr_phy2mac[4].phy_mac_rxdata;
    assign dpr_phy_mac_rxdata[5] = w_dpr_phy2mac[5].phy_mac_rxdata;
    assign dpr_phy_mac_rxdata[6] = w_dpr_phy2mac[6].phy_mac_rxdata;
    assign dpr_phy_mac_rxdata[7] = w_dpr_phy2mac[7].phy_mac_rxdata;
    assign dpr_phy_mac_rxdata[8] = w_dpr_phy2mac[8].phy_mac_rxdata;
    assign dpr_phy_mac_rxdata[9] = w_dpr_phy2mac[9].phy_mac_rxdata;
    assign dpr_phy_mac_rxdata[10] = w_dpr_phy2mac[10].phy_mac_rxdata;
    assign dpr_phy_mac_rxdata[11] = w_dpr_phy2mac[11].phy_mac_rxdata;
    assign dpr_phy_mac_rxdatak[0] = w_dpr_phy2mac[0].phy_mac_rxdatak;
    assign dpr_phy_mac_rxdatak[1] = w_dpr_phy2mac[1].phy_mac_rxdatak;
    assign dpr_phy_mac_rxdatak[2] = w_dpr_phy2mac[2].phy_mac_rxdatak;
    assign dpr_phy_mac_rxdatak[3] = w_dpr_phy2mac[3].phy_mac_rxdatak;
    assign dpr_phy_mac_rxdatak[4] = w_dpr_phy2mac[4].phy_mac_rxdatak;
    assign dpr_phy_mac_rxdatak[5] = w_dpr_phy2mac[5].phy_mac_rxdatak;
    assign dpr_phy_mac_rxdatak[6] = w_dpr_phy2mac[6].phy_mac_rxdatak;
    assign dpr_phy_mac_rxdatak[7] = w_dpr_phy2mac[7].phy_mac_rxdatak;
    assign dpr_phy_mac_rxdatak[8] = w_dpr_phy2mac[8].phy_mac_rxdatak;
    assign dpr_phy_mac_rxdatak[9] = w_dpr_phy2mac[9].phy_mac_rxdatak;
    assign dpr_phy_mac_rxdatak[10] = w_dpr_phy2mac[10].phy_mac_rxdatak;
    assign dpr_phy_mac_rxdatak[11] = w_dpr_phy2mac[11].phy_mac_rxdatak;
    assign dpr_phy_mac_rxdatavalid[0] = w_dpr_phy2mac[0].phy_mac_rxdatavalid;
    assign dpr_phy_mac_rxdatavalid[1] = w_dpr_phy2mac[1].phy_mac_rxdatavalid;
    assign dpr_phy_mac_rxdatavalid[2] = w_dpr_phy2mac[2].phy_mac_rxdatavalid;
    assign dpr_phy_mac_rxdatavalid[3] = w_dpr_phy2mac[3].phy_mac_rxdatavalid;
    assign dpr_phy_mac_rxdatavalid[4] = w_dpr_phy2mac[4].phy_mac_rxdatavalid;
    assign dpr_phy_mac_rxdatavalid[5] = w_dpr_phy2mac[5].phy_mac_rxdatavalid;
    assign dpr_phy_mac_rxdatavalid[6] = w_dpr_phy2mac[6].phy_mac_rxdatavalid;
    assign dpr_phy_mac_rxdatavalid[7] = w_dpr_phy2mac[7].phy_mac_rxdatavalid;
    assign dpr_phy_mac_rxdatavalid[8] = w_dpr_phy2mac[8].phy_mac_rxdatavalid;
    assign dpr_phy_mac_rxdatavalid[9] = w_dpr_phy2mac[9].phy_mac_rxdatavalid;
    assign dpr_phy_mac_rxdatavalid[10] = w_dpr_phy2mac[10].phy_mac_rxdatavalid;
    assign dpr_phy_mac_rxdatavalid[11] = w_dpr_phy2mac[11].phy_mac_rxdatavalid;
    assign dpr_phy_mac_rxstartblock[0] = w_dpr_phy2mac[0].phy_mac_rxstartblock;
    assign dpr_phy_mac_rxstartblock[1] = w_dpr_phy2mac[1].phy_mac_rxstartblock;
    assign dpr_phy_mac_rxstartblock[2] = w_dpr_phy2mac[2].phy_mac_rxstartblock;
    assign dpr_phy_mac_rxstartblock[3] = w_dpr_phy2mac[3].phy_mac_rxstartblock;
    assign dpr_phy_mac_rxstartblock[4] = w_dpr_phy2mac[4].phy_mac_rxstartblock;
    assign dpr_phy_mac_rxstartblock[5] = w_dpr_phy2mac[5].phy_mac_rxstartblock;
    assign dpr_phy_mac_rxstartblock[6] = w_dpr_phy2mac[6].phy_mac_rxstartblock;
    assign dpr_phy_mac_rxstartblock[7] = w_dpr_phy2mac[7].phy_mac_rxstartblock;
    assign dpr_phy_mac_rxstartblock[8] = w_dpr_phy2mac[8].phy_mac_rxstartblock;
    assign dpr_phy_mac_rxstartblock[9] = w_dpr_phy2mac[9].phy_mac_rxstartblock;
    assign dpr_phy_mac_rxstartblock[10] = w_dpr_phy2mac[10].phy_mac_rxstartblock;
    assign dpr_phy_mac_rxstartblock[11] = w_dpr_phy2mac[11].phy_mac_rxstartblock;
    assign dpr_phy_mac_rxsyncheader[0] = w_dpr_phy2mac[0].phy_mac_rxsyncheader;
    assign dpr_phy_mac_rxsyncheader[1] = w_dpr_phy2mac[1].phy_mac_rxsyncheader;
    assign dpr_phy_mac_rxsyncheader[2] = w_dpr_phy2mac[2].phy_mac_rxsyncheader;
    assign dpr_phy_mac_rxsyncheader[3] = w_dpr_phy2mac[3].phy_mac_rxsyncheader;
    assign dpr_phy_mac_rxsyncheader[4] = w_dpr_phy2mac[4].phy_mac_rxsyncheader;
    assign dpr_phy_mac_rxsyncheader[5] = w_dpr_phy2mac[5].phy_mac_rxsyncheader;
    assign dpr_phy_mac_rxsyncheader[6] = w_dpr_phy2mac[6].phy_mac_rxsyncheader;
    assign dpr_phy_mac_rxsyncheader[7] = w_dpr_phy2mac[7].phy_mac_rxsyncheader;
    assign dpr_phy_mac_rxsyncheader[8] = w_dpr_phy2mac[8].phy_mac_rxsyncheader;
    assign dpr_phy_mac_rxsyncheader[9] = w_dpr_phy2mac[9].phy_mac_rxsyncheader;
    assign dpr_phy_mac_rxsyncheader[10] = w_dpr_phy2mac[10].phy_mac_rxsyncheader;
    assign dpr_phy_mac_rxsyncheader[11] = w_dpr_phy2mac[11].phy_mac_rxsyncheader;
    assign dpr_phy_mac_rxvalid[0] = w_dpr_phy2mac[0].phy_mac_rxvalid;
    assign dpr_phy_mac_rxvalid[1] = w_dpr_phy2mac[1].phy_mac_rxvalid;
    assign dpr_phy_mac_rxvalid[2] = w_dpr_phy2mac[2].phy_mac_rxvalid;
    assign dpr_phy_mac_rxvalid[3] = w_dpr_phy2mac[3].phy_mac_rxvalid;
    assign dpr_phy_mac_rxvalid[4] = w_dpr_phy2mac[4].phy_mac_rxvalid;
    assign dpr_phy_mac_rxvalid[5] = w_dpr_phy2mac[5].phy_mac_rxvalid;
    assign dpr_phy_mac_rxvalid[6] = w_dpr_phy2mac[6].phy_mac_rxvalid;
    assign dpr_phy_mac_rxvalid[7] = w_dpr_phy2mac[7].phy_mac_rxvalid;
    assign dpr_phy_mac_rxvalid[8] = w_dpr_phy2mac[8].phy_mac_rxvalid;
    assign dpr_phy_mac_rxvalid[9] = w_dpr_phy2mac[9].phy_mac_rxvalid;
    assign dpr_phy_mac_rxvalid[10] = w_dpr_phy2mac[10].phy_mac_rxvalid;
    assign dpr_phy_mac_rxvalid[11] = w_dpr_phy2mac[11].phy_mac_rxvalid;
    assign dpr_phy_mac_rxstatus[0] = w_dpr_phy2mac[0].phy_mac_rxstatus;
    assign dpr_phy_mac_rxstatus[1] = w_dpr_phy2mac[1].phy_mac_rxstatus;
    assign dpr_phy_mac_rxstatus[2] = w_dpr_phy2mac[2].phy_mac_rxstatus;
    assign dpr_phy_mac_rxstatus[3] = w_dpr_phy2mac[3].phy_mac_rxstatus;
    assign dpr_phy_mac_rxstatus[4] = w_dpr_phy2mac[4].phy_mac_rxstatus;
    assign dpr_phy_mac_rxstatus[5] = w_dpr_phy2mac[5].phy_mac_rxstatus;
    assign dpr_phy_mac_rxstatus[6] = w_dpr_phy2mac[6].phy_mac_rxstatus;
    assign dpr_phy_mac_rxstatus[7] = w_dpr_phy2mac[7].phy_mac_rxstatus;
    assign dpr_phy_mac_rxstatus[8] = w_dpr_phy2mac[8].phy_mac_rxstatus;
    assign dpr_phy_mac_rxstatus[9] = w_dpr_phy2mac[9].phy_mac_rxstatus;
    assign dpr_phy_mac_rxstatus[10] = w_dpr_phy2mac[10].phy_mac_rxstatus;
    assign dpr_phy_mac_rxstatus[11] = w_dpr_phy2mac[11].phy_mac_rxstatus;
    assign dpr_phy_mac_rxelecidle[0] = w_dpr_phy2mac[0].phy_mac_rxelecidle;
    assign dpr_phy_mac_rxelecidle[1] = w_dpr_phy2mac[1].phy_mac_rxelecidle;
    assign dpr_phy_mac_rxelecidle[2] = w_dpr_phy2mac[2].phy_mac_rxelecidle;
    assign dpr_phy_mac_rxelecidle[3] = w_dpr_phy2mac[3].phy_mac_rxelecidle;
    assign dpr_phy_mac_rxelecidle[4] = w_dpr_phy2mac[4].phy_mac_rxelecidle;
    assign dpr_phy_mac_rxelecidle[5] = w_dpr_phy2mac[5].phy_mac_rxelecidle;
    assign dpr_phy_mac_rxelecidle[6] = w_dpr_phy2mac[6].phy_mac_rxelecidle;
    assign dpr_phy_mac_rxelecidle[7] = w_dpr_phy2mac[7].phy_mac_rxelecidle;
    assign dpr_phy_mac_rxelecidle[8] = w_dpr_phy2mac[8].phy_mac_rxelecidle;
    assign dpr_phy_mac_rxelecidle[9] = w_dpr_phy2mac[9].phy_mac_rxelecidle;
    assign dpr_phy_mac_rxelecidle[10] = w_dpr_phy2mac[10].phy_mac_rxelecidle;
    assign dpr_phy_mac_rxelecidle[11] = w_dpr_phy2mac[11].phy_mac_rxelecidle;
    assign dpr_phy_mac_rxstandbystatus[0] = w_dpr_phy2mac[0].phy_mac_rxstandbystatus;
    assign dpr_phy_mac_rxstandbystatus[1] = w_dpr_phy2mac[1].phy_mac_rxstandbystatus;
    assign dpr_phy_mac_rxstandbystatus[2] = w_dpr_phy2mac[2].phy_mac_rxstandbystatus;
    assign dpr_phy_mac_rxstandbystatus[3] = w_dpr_phy2mac[3].phy_mac_rxstandbystatus;
    assign dpr_phy_mac_rxstandbystatus[4] = w_dpr_phy2mac[4].phy_mac_rxstandbystatus;
    assign dpr_phy_mac_rxstandbystatus[5] = w_dpr_phy2mac[5].phy_mac_rxstandbystatus;
    assign dpr_phy_mac_rxstandbystatus[6] = w_dpr_phy2mac[6].phy_mac_rxstandbystatus;
    assign dpr_phy_mac_rxstandbystatus[7] = w_dpr_phy2mac[7].phy_mac_rxstandbystatus;
    assign dpr_phy_mac_rxstandbystatus[8] = w_dpr_phy2mac[8].phy_mac_rxstandbystatus;
    assign dpr_phy_mac_rxstandbystatus[9] = w_dpr_phy2mac[9].phy_mac_rxstandbystatus;
    assign dpr_phy_mac_rxstandbystatus[10] = w_dpr_phy2mac[10].phy_mac_rxstandbystatus;
    assign dpr_phy_mac_rxstandbystatus[11] = w_dpr_phy2mac[11].phy_mac_rxstandbystatus;
    assign dpr_phy_mac_messagebus[0] = w_dpr_phy2mac[0].phy_mac_messagebus;
    assign dpr_phy_mac_messagebus[1] = w_dpr_phy2mac[1].phy_mac_messagebus;
    assign dpr_phy_mac_messagebus[2] = w_dpr_phy2mac[2].phy_mac_messagebus;
    assign dpr_phy_mac_messagebus[3] = w_dpr_phy2mac[3].phy_mac_messagebus;
    assign dpr_phy_mac_messagebus[4] = w_dpr_phy2mac[4].phy_mac_messagebus;
    assign dpr_phy_mac_messagebus[5] = w_dpr_phy2mac[5].phy_mac_messagebus;
    assign dpr_phy_mac_messagebus[6] = w_dpr_phy2mac[6].phy_mac_messagebus;
    assign dpr_phy_mac_messagebus[7] = w_dpr_phy2mac[7].phy_mac_messagebus;
    assign dpr_phy_mac_messagebus[8] = w_dpr_phy2mac[8].phy_mac_messagebus;
    assign dpr_phy_mac_messagebus[9] = w_dpr_phy2mac[9].phy_mac_messagebus;
    assign dpr_phy_mac_messagebus[10] = w_dpr_phy2mac[10].phy_mac_messagebus;
    assign dpr_phy_mac_messagebus[11] = w_dpr_phy2mac[11].phy_mac_messagebus;
    assign dpr_phy_mac_phystatus[0] = w_dpr_phy2mac[0].phy_mac_phystatus;
    assign dpr_phy_mac_phystatus[1] = w_dpr_phy2mac[1].phy_mac_phystatus;
    assign dpr_phy_mac_phystatus[2] = w_dpr_phy2mac[2].phy_mac_phystatus;
    assign dpr_phy_mac_phystatus[3] = w_dpr_phy2mac[3].phy_mac_phystatus;
    assign dpr_phy_mac_phystatus[4] = w_dpr_phy2mac[4].phy_mac_phystatus;
    assign dpr_phy_mac_phystatus[5] = w_dpr_phy2mac[5].phy_mac_phystatus;
    assign dpr_phy_mac_phystatus[6] = w_dpr_phy2mac[6].phy_mac_phystatus;
    assign dpr_phy_mac_phystatus[7] = w_dpr_phy2mac[7].phy_mac_phystatus;
    assign dpr_phy_mac_phystatus[8] = w_dpr_phy2mac[8].phy_mac_phystatus;
    assign dpr_phy_mac_phystatus[9] = w_dpr_phy2mac[9].phy_mac_phystatus;
    assign dpr_phy_mac_phystatus[10] = w_dpr_phy2mac[10].phy_mac_phystatus;
    assign dpr_phy_mac_phystatus[11] = w_dpr_phy2mac[11].phy_mac_phystatus;
    assign dpr_phy_mac_local_tx_coef_valid[0] = w_dpr_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign dpr_phy_mac_local_tx_coef_valid[1] = w_dpr_phy2mac[1].phy_mac_local_tx_coef_valid;
    assign dpr_phy_mac_local_tx_coef_valid[2] = w_dpr_phy2mac[2].phy_mac_local_tx_coef_valid;
    assign dpr_phy_mac_local_tx_coef_valid[3] = w_dpr_phy2mac[3].phy_mac_local_tx_coef_valid;
    assign dpr_phy_mac_local_tx_coef_valid[4] = w_dpr_phy2mac[4].phy_mac_local_tx_coef_valid;
    assign dpr_phy_mac_local_tx_coef_valid[5] = w_dpr_phy2mac[5].phy_mac_local_tx_coef_valid;
    assign dpr_phy_mac_local_tx_coef_valid[6] = w_dpr_phy2mac[6].phy_mac_local_tx_coef_valid;
    assign dpr_phy_mac_local_tx_coef_valid[7] = w_dpr_phy2mac[7].phy_mac_local_tx_coef_valid;
    assign dpr_phy_mac_local_tx_coef_valid[8] = w_dpr_phy2mac[8].phy_mac_local_tx_coef_valid;
    assign dpr_phy_mac_local_tx_coef_valid[9] = w_dpr_phy2mac[9].phy_mac_local_tx_coef_valid;
    assign dpr_phy_mac_local_tx_coef_valid[10] = w_dpr_phy2mac[10].phy_mac_local_tx_coef_valid;
    assign dpr_phy_mac_local_tx_coef_valid[11] = w_dpr_phy2mac[11].phy_mac_local_tx_coef_valid;
    assign dpr_phy_mac_local_tx_pset_coef[0] = w_dpr_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign dpr_phy_mac_local_tx_pset_coef[1] = w_dpr_phy2mac[1].phy_mac_local_tx_pset_coef;
    assign dpr_phy_mac_local_tx_pset_coef[2] = w_dpr_phy2mac[2].phy_mac_local_tx_pset_coef;
    assign dpr_phy_mac_local_tx_pset_coef[3] = w_dpr_phy2mac[3].phy_mac_local_tx_pset_coef;
    assign dpr_phy_mac_local_tx_pset_coef[4] = w_dpr_phy2mac[4].phy_mac_local_tx_pset_coef;
    assign dpr_phy_mac_local_tx_pset_coef[5] = w_dpr_phy2mac[5].phy_mac_local_tx_pset_coef;
    assign dpr_phy_mac_local_tx_pset_coef[6] = w_dpr_phy2mac[6].phy_mac_local_tx_pset_coef;
    assign dpr_phy_mac_local_tx_pset_coef[7] = w_dpr_phy2mac[7].phy_mac_local_tx_pset_coef;
    assign dpr_phy_mac_local_tx_pset_coef[8] = w_dpr_phy2mac[8].phy_mac_local_tx_pset_coef;
    assign dpr_phy_mac_local_tx_pset_coef[9] = w_dpr_phy2mac[9].phy_mac_local_tx_pset_coef;
    assign dpr_phy_mac_local_tx_pset_coef[10] = w_dpr_phy2mac[10].phy_mac_local_tx_pset_coef;
    assign dpr_phy_mac_local_tx_pset_coef[11] = w_dpr_phy2mac[11].phy_mac_local_tx_pset_coef;
    assign dpr_phy_mac_localfs[0] = w_dpr_phy2mac[0].phy_mac_localfs;
    assign dpr_phy_mac_localfs[1] = w_dpr_phy2mac[1].phy_mac_localfs;
    assign dpr_phy_mac_localfs[2] = w_dpr_phy2mac[2].phy_mac_localfs;
    assign dpr_phy_mac_localfs[3] = w_dpr_phy2mac[3].phy_mac_localfs;
    assign dpr_phy_mac_localfs[4] = w_dpr_phy2mac[4].phy_mac_localfs;
    assign dpr_phy_mac_localfs[5] = w_dpr_phy2mac[5].phy_mac_localfs;
    assign dpr_phy_mac_localfs[6] = w_dpr_phy2mac[6].phy_mac_localfs;
    assign dpr_phy_mac_localfs[7] = w_dpr_phy2mac[7].phy_mac_localfs;
    assign dpr_phy_mac_localfs[8] = w_dpr_phy2mac[8].phy_mac_localfs;
    assign dpr_phy_mac_localfs[9] = w_dpr_phy2mac[9].phy_mac_localfs;
    assign dpr_phy_mac_localfs[10] = w_dpr_phy2mac[10].phy_mac_localfs;
    assign dpr_phy_mac_localfs[11] = w_dpr_phy2mac[11].phy_mac_localfs;
    assign dpr_phy_mac_locallf[0] = w_dpr_phy2mac[0].phy_mac_locallf;
    assign dpr_phy_mac_locallf[1] = w_dpr_phy2mac[1].phy_mac_locallf;
    assign dpr_phy_mac_locallf[2] = w_dpr_phy2mac[2].phy_mac_locallf;
    assign dpr_phy_mac_locallf[3] = w_dpr_phy2mac[3].phy_mac_locallf;
    assign dpr_phy_mac_locallf[4] = w_dpr_phy2mac[4].phy_mac_locallf;
    assign dpr_phy_mac_locallf[5] = w_dpr_phy2mac[5].phy_mac_locallf;
    assign dpr_phy_mac_locallf[6] = w_dpr_phy2mac[6].phy_mac_locallf;
    assign dpr_phy_mac_locallf[7] = w_dpr_phy2mac[7].phy_mac_locallf;
    assign dpr_phy_mac_locallf[8] = w_dpr_phy2mac[8].phy_mac_locallf;
    assign dpr_phy_mac_locallf[9] = w_dpr_phy2mac[9].phy_mac_locallf;
    assign dpr_phy_mac_locallf[10] = w_dpr_phy2mac[10].phy_mac_locallf;
    assign dpr_phy_mac_locallf[11] = w_dpr_phy2mac[11].phy_mac_locallf;
    assign dpr_phy_mac_dirfeedback[0] = w_dpr_phy2mac[0].phy_mac_dirfeedback;
    assign dpr_phy_mac_dirfeedback[1] = w_dpr_phy2mac[1].phy_mac_dirfeedback;
    assign dpr_phy_mac_dirfeedback[2] = w_dpr_phy2mac[2].phy_mac_dirfeedback;
    assign dpr_phy_mac_dirfeedback[3] = w_dpr_phy2mac[3].phy_mac_dirfeedback;
    assign dpr_phy_mac_dirfeedback[4] = w_dpr_phy2mac[4].phy_mac_dirfeedback;
    assign dpr_phy_mac_dirfeedback[5] = w_dpr_phy2mac[5].phy_mac_dirfeedback;
    assign dpr_phy_mac_dirfeedback[6] = w_dpr_phy2mac[6].phy_mac_dirfeedback;
    assign dpr_phy_mac_dirfeedback[7] = w_dpr_phy2mac[7].phy_mac_dirfeedback;
    assign dpr_phy_mac_dirfeedback[8] = w_dpr_phy2mac[8].phy_mac_dirfeedback;
    assign dpr_phy_mac_dirfeedback[9] = w_dpr_phy2mac[9].phy_mac_dirfeedback;
    assign dpr_phy_mac_dirfeedback[10] = w_dpr_phy2mac[10].phy_mac_dirfeedback;
    assign dpr_phy_mac_dirfeedback[11] = w_dpr_phy2mac[11].phy_mac_dirfeedback;
    assign dpr_phy_mac_fomfeedback[0] = w_dpr_phy2mac[0].phy_mac_fomfeedback;
    assign dpr_phy_mac_fomfeedback[1] = w_dpr_phy2mac[1].phy_mac_fomfeedback;
    assign dpr_phy_mac_fomfeedback[2] = w_dpr_phy2mac[2].phy_mac_fomfeedback;
    assign dpr_phy_mac_fomfeedback[3] = w_dpr_phy2mac[3].phy_mac_fomfeedback;
    assign dpr_phy_mac_fomfeedback[4] = w_dpr_phy2mac[4].phy_mac_fomfeedback;
    assign dpr_phy_mac_fomfeedback[5] = w_dpr_phy2mac[5].phy_mac_fomfeedback;
    assign dpr_phy_mac_fomfeedback[6] = w_dpr_phy2mac[6].phy_mac_fomfeedback;
    assign dpr_phy_mac_fomfeedback[7] = w_dpr_phy2mac[7].phy_mac_fomfeedback;
    assign dpr_phy_mac_fomfeedback[8] = w_dpr_phy2mac[8].phy_mac_fomfeedback;
    assign dpr_phy_mac_fomfeedback[9] = w_dpr_phy2mac[9].phy_mac_fomfeedback;
    assign dpr_phy_mac_fomfeedback[10] = w_dpr_phy2mac[10].phy_mac_fomfeedback;
    assign dpr_phy_mac_fomfeedback[11] = w_dpr_phy2mac[11].phy_mac_fomfeedback;

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
        .v_lane_mask  (v_lane_mask),
        .dpr_rst_n    (dpr_rst_n),
        .dpr_mac2phy  (w_dpr_mac2phy),
        .dpr_phy2mac  (w_dpr_phy2mac),
        .dpr_pclk     (dpr_pclk),
        .ctrla_rst_n   (ctrla_rst_n),
        .ctrla_mac2phy (w_ctrla_mac2phy),
        .ctrla_phy2mac (w_ctrla_phy2mac),
        .ctrla_pclk (ctrla_pclk),
        .ctrlb_rst_n   (ctrlb_rst_n),
        .ctrlb_mac2phy (w_ctrlb_mac2phy),
        .ctrlb_phy2mac (w_ctrlb_phy2mac),
        .ctrlb_pclk (ctrlb_pclk),
        .ctrlc_rst_n   (ctrlc_rst_n),
        .ctrlc_mac2phy (w_ctrlc_mac2phy),
        .ctrlc_phy2mac (w_ctrlc_phy2mac),
        .ctrlc_pclk (ctrlc_pclk),
        .ctrld_rst_n   (ctrld_rst_n),
        .ctrld_mac2phy (w_ctrld_mac2phy),
        .ctrld_phy2mac (w_ctrld_phy2mac),
        .ctrld_pclk (ctrld_pclk)
    );

endmodule
