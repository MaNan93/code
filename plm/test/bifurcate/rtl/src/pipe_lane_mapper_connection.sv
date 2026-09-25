// PIPE lane mapper connection wrapper.
//
// Pure struct<->flat bridge around pipe_lane_mapper: every pipe_signals.csv
// row becomes its own flat port here instead of a packed-struct field, for
// integration with flows/IP that don't want SV struct ports. A MAC-to-PHY
// signal_type=shared collapses a controller's own lanes to one scalar input; perlane
// (the default) stays an unpacked array of max_width. The PHY side is always
// per-lane -- which controller owns a PHY lane still varies by mode, so even a
// "shared" signal still needs its own value per PHY lane there.
import pipe_lane_signal_pkg::*;

module pipe_lane_mapper_connection #(
    parameter int NL = 16,
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
    // Controller side. Each controller's ports are declared at its own real max_width.
    // CtrlX16 x16
    input logic ctrlx16_rst_n,
    input logic [31:0] ctrlx16_mac_phy_txdata [0:15],
    input logic [3:0] ctrlx16_mac_phy_txdatak [0:15],
    input logic [0:0] ctrlx16_mac_phy_txdatavalid [0:15],
    input logic [0:0] ctrlx16_mac_phy_txstartblock [0:15],
    input logic [1:0] ctrlx16_mac_phy_txsyncheader [0:15],
    input logic [0:0] ctrlx16_mac_phy_txdetectrx_loopback [0:15],
    input logic [0:0] ctrlx16_mac_phy_txelecidle [0:15],
    input logic [0:0] ctrlx16_mac_phy_txcompliance [0:15],
    input logic [17:0] ctrlx16_mac_phy_txdeemph [0:15],
    input logic [0:0] ctrlx16_mac_phy_rxpolarity [0:15],
    input logic [0:0] ctrlx16_mac_phy_rxstandby [0:15],
    input logic [7:0] ctrlx16_mac_phy_messagebus [0:15],
    input logic [2:0] ctrlx16_mac_phy_rxpresethint [0:15],
    input logic [4:0] ctrlx16_mac_phy_local_pset_index [0:15],
    input logic [0:0] ctrlx16_mac_phy_getlocal_pset_coef [0:15],
    input logic [0:0] ctrlx16_mac_phy_invalid_req [0:15],
    input logic [0:0] ctrlx16_mac_phy_rxeqeval [0:15],
    input logic [5:0] ctrlx16_mac_phy_fs [0:15],
    input logic [5:0] ctrlx16_mac_phy_lf [0:15],
    input logic [0:0] ctrlx16_mac_phy_dirchange [0:15],
    input logic [0:0] ctrlx16_mac_phy_rxeqinprogress [0:15],
    output logic [31:0] ctrlx16_phy_mac_rxdata [0:15],
    output logic [3:0] ctrlx16_phy_mac_rxdatak [0:15],
    output logic [0:0] ctrlx16_phy_mac_rxdatavalid [0:15],
    output logic [0:0] ctrlx16_phy_mac_rxstartblock [0:15],
    output logic [1:0] ctrlx16_phy_mac_rxsyncheader [0:15],
    output logic [0:0] ctrlx16_phy_mac_rxvalid [0:15],
    output logic [2:0] ctrlx16_phy_mac_rxstatus [0:15],
    output logic [0:0] ctrlx16_phy_mac_rxelecidle [0:15],
    output logic [0:0] ctrlx16_phy_mac_rxstandbystatus [0:15],
    output logic [7:0] ctrlx16_phy_mac_messagebus [0:15],
    output logic [0:0] ctrlx16_phy_mac_phystatus [0:15],
    output logic [0:0] ctrlx16_phy_mac_local_tx_coef_valid [0:15],
    output logic [17:0] ctrlx16_phy_mac_local_tx_pset_coef [0:15],
    output logic [5:0] ctrlx16_phy_mac_localfs [0:15],
    output logic [5:0] ctrlx16_phy_mac_locallf [0:15],
    output logic [5:0] ctrlx16_phy_mac_dirfeedback [0:15],
    output logic [7:0] ctrlx16_phy_mac_fomfeedback [0:15],
    output logic ctrlx16_pclk,
    // CtrlX8asdfadssssss x8
    input logic ctrlx8asdfadssssss_rst_n,
    input logic [31:0] ctrlx8asdfadssssss_mac_phy_txdata [0:7],
    input logic [3:0] ctrlx8asdfadssssss_mac_phy_txdatak [0:7],
    input logic [0:0] ctrlx8asdfadssssss_mac_phy_txdatavalid [0:7],
    input logic [0:0] ctrlx8asdfadssssss_mac_phy_txstartblock [0:7],
    input logic [1:0] ctrlx8asdfadssssss_mac_phy_txsyncheader [0:7],
    input logic [0:0] ctrlx8asdfadssssss_mac_phy_txdetectrx_loopback [0:7],
    input logic [0:0] ctrlx8asdfadssssss_mac_phy_txelecidle [0:7],
    input logic [0:0] ctrlx8asdfadssssss_mac_phy_txcompliance [0:7],
    input logic [17:0] ctrlx8asdfadssssss_mac_phy_txdeemph [0:7],
    input logic [0:0] ctrlx8asdfadssssss_mac_phy_rxpolarity [0:7],
    input logic [0:0] ctrlx8asdfadssssss_mac_phy_rxstandby [0:7],
    input logic [7:0] ctrlx8asdfadssssss_mac_phy_messagebus [0:7],
    input logic [2:0] ctrlx8asdfadssssss_mac_phy_rxpresethint [0:7],
    input logic [4:0] ctrlx8asdfadssssss_mac_phy_local_pset_index [0:7],
    input logic [0:0] ctrlx8asdfadssssss_mac_phy_getlocal_pset_coef [0:7],
    input logic [0:0] ctrlx8asdfadssssss_mac_phy_invalid_req [0:7],
    input logic [0:0] ctrlx8asdfadssssss_mac_phy_rxeqeval [0:7],
    input logic [5:0] ctrlx8asdfadssssss_mac_phy_fs [0:7],
    input logic [5:0] ctrlx8asdfadssssss_mac_phy_lf [0:7],
    input logic [0:0] ctrlx8asdfadssssss_mac_phy_dirchange [0:7],
    input logic [0:0] ctrlx8asdfadssssss_mac_phy_rxeqinprogress [0:7],
    output logic [31:0] ctrlx8asdfadssssss_phy_mac_rxdata [0:7],
    output logic [3:0] ctrlx8asdfadssssss_phy_mac_rxdatak [0:7],
    output logic [0:0] ctrlx8asdfadssssss_phy_mac_rxdatavalid [0:7],
    output logic [0:0] ctrlx8asdfadssssss_phy_mac_rxstartblock [0:7],
    output logic [1:0] ctrlx8asdfadssssss_phy_mac_rxsyncheader [0:7],
    output logic [0:0] ctrlx8asdfadssssss_phy_mac_rxvalid [0:7],
    output logic [2:0] ctrlx8asdfadssssss_phy_mac_rxstatus [0:7],
    output logic [0:0] ctrlx8asdfadssssss_phy_mac_rxelecidle [0:7],
    output logic [0:0] ctrlx8asdfadssssss_phy_mac_rxstandbystatus [0:7],
    output logic [7:0] ctrlx8asdfadssssss_phy_mac_messagebus [0:7],
    output logic [0:0] ctrlx8asdfadssssss_phy_mac_phystatus [0:7],
    output logic [0:0] ctrlx8asdfadssssss_phy_mac_local_tx_coef_valid [0:7],
    output logic [17:0] ctrlx8asdfadssssss_phy_mac_local_tx_pset_coef [0:7],
    output logic [5:0] ctrlx8asdfadssssss_phy_mac_localfs [0:7],
    output logic [5:0] ctrlx8asdfadssssss_phy_mac_locallf [0:7],
    output logic [5:0] ctrlx8asdfadssssss_phy_mac_dirfeedback [0:7],
    output logic [7:0] ctrlx8asdfadssssss_phy_mac_fomfeedback [0:7],
    output logic ctrlx8asdfadssssss_pclk,
    // CtrlX4a x4
    input logic ctrlx4a_rst_n,
    input logic [31:0] ctrlx4a_mac_phy_txdata [0:3],
    input logic [3:0] ctrlx4a_mac_phy_txdatak [0:3],
    input logic [0:0] ctrlx4a_mac_phy_txdatavalid [0:3],
    input logic [0:0] ctrlx4a_mac_phy_txstartblock [0:3],
    input logic [1:0] ctrlx4a_mac_phy_txsyncheader [0:3],
    input logic [0:0] ctrlx4a_mac_phy_txdetectrx_loopback [0:3],
    input logic [0:0] ctrlx4a_mac_phy_txelecidle [0:3],
    input logic [0:0] ctrlx4a_mac_phy_txcompliance [0:3],
    input logic [17:0] ctrlx4a_mac_phy_txdeemph [0:3],
    input logic [0:0] ctrlx4a_mac_phy_rxpolarity [0:3],
    input logic [0:0] ctrlx4a_mac_phy_rxstandby [0:3],
    input logic [7:0] ctrlx4a_mac_phy_messagebus [0:3],
    input logic [2:0] ctrlx4a_mac_phy_rxpresethint [0:3],
    input logic [4:0] ctrlx4a_mac_phy_local_pset_index [0:3],
    input logic [0:0] ctrlx4a_mac_phy_getlocal_pset_coef [0:3],
    input logic [0:0] ctrlx4a_mac_phy_invalid_req [0:3],
    input logic [0:0] ctrlx4a_mac_phy_rxeqeval [0:3],
    input logic [5:0] ctrlx4a_mac_phy_fs [0:3],
    input logic [5:0] ctrlx4a_mac_phy_lf [0:3],
    input logic [0:0] ctrlx4a_mac_phy_dirchange [0:3],
    input logic [0:0] ctrlx4a_mac_phy_rxeqinprogress [0:3],
    output logic [31:0] ctrlx4a_phy_mac_rxdata [0:3],
    output logic [3:0] ctrlx4a_phy_mac_rxdatak [0:3],
    output logic [0:0] ctrlx4a_phy_mac_rxdatavalid [0:3],
    output logic [0:0] ctrlx4a_phy_mac_rxstartblock [0:3],
    output logic [1:0] ctrlx4a_phy_mac_rxsyncheader [0:3],
    output logic [0:0] ctrlx4a_phy_mac_rxvalid [0:3],
    output logic [2:0] ctrlx4a_phy_mac_rxstatus [0:3],
    output logic [0:0] ctrlx4a_phy_mac_rxelecidle [0:3],
    output logic [0:0] ctrlx4a_phy_mac_rxstandbystatus [0:3],
    output logic [7:0] ctrlx4a_phy_mac_messagebus [0:3],
    output logic [0:0] ctrlx4a_phy_mac_phystatus [0:3],
    output logic [0:0] ctrlx4a_phy_mac_local_tx_coef_valid [0:3],
    output logic [17:0] ctrlx4a_phy_mac_local_tx_pset_coef [0:3],
    output logic [5:0] ctrlx4a_phy_mac_localfs [0:3],
    output logic [5:0] ctrlx4a_phy_mac_locallf [0:3],
    output logic [5:0] ctrlx4a_phy_mac_dirfeedback [0:3],
    output logic [7:0] ctrlx4a_phy_mac_fomfeedback [0:3],
    output logic ctrlx4a_pclk,
    // CtrlX4b x4
    input logic ctrlx4b_rst_n,
    input logic [31:0] ctrlx4b_mac_phy_txdata [0:3],
    input logic [3:0] ctrlx4b_mac_phy_txdatak [0:3],
    input logic [0:0] ctrlx4b_mac_phy_txdatavalid [0:3],
    input logic [0:0] ctrlx4b_mac_phy_txstartblock [0:3],
    input logic [1:0] ctrlx4b_mac_phy_txsyncheader [0:3],
    input logic [0:0] ctrlx4b_mac_phy_txdetectrx_loopback [0:3],
    input logic [0:0] ctrlx4b_mac_phy_txelecidle [0:3],
    input logic [0:0] ctrlx4b_mac_phy_txcompliance [0:3],
    input logic [17:0] ctrlx4b_mac_phy_txdeemph [0:3],
    input logic [0:0] ctrlx4b_mac_phy_rxpolarity [0:3],
    input logic [0:0] ctrlx4b_mac_phy_rxstandby [0:3],
    input logic [7:0] ctrlx4b_mac_phy_messagebus [0:3],
    input logic [2:0] ctrlx4b_mac_phy_rxpresethint [0:3],
    input logic [4:0] ctrlx4b_mac_phy_local_pset_index [0:3],
    input logic [0:0] ctrlx4b_mac_phy_getlocal_pset_coef [0:3],
    input logic [0:0] ctrlx4b_mac_phy_invalid_req [0:3],
    input logic [0:0] ctrlx4b_mac_phy_rxeqeval [0:3],
    input logic [5:0] ctrlx4b_mac_phy_fs [0:3],
    input logic [5:0] ctrlx4b_mac_phy_lf [0:3],
    input logic [0:0] ctrlx4b_mac_phy_dirchange [0:3],
    input logic [0:0] ctrlx4b_mac_phy_rxeqinprogress [0:3],
    output logic [31:0] ctrlx4b_phy_mac_rxdata [0:3],
    output logic [3:0] ctrlx4b_phy_mac_rxdatak [0:3],
    output logic [0:0] ctrlx4b_phy_mac_rxdatavalid [0:3],
    output logic [0:0] ctrlx4b_phy_mac_rxstartblock [0:3],
    output logic [1:0] ctrlx4b_phy_mac_rxsyncheader [0:3],
    output logic [0:0] ctrlx4b_phy_mac_rxvalid [0:3],
    output logic [2:0] ctrlx4b_phy_mac_rxstatus [0:3],
    output logic [0:0] ctrlx4b_phy_mac_rxelecidle [0:3],
    output logic [0:0] ctrlx4b_phy_mac_rxstandbystatus [0:3],
    output logic [7:0] ctrlx4b_phy_mac_messagebus [0:3],
    output logic [0:0] ctrlx4b_phy_mac_phystatus [0:3],
    output logic [0:0] ctrlx4b_phy_mac_local_tx_coef_valid [0:3],
    output logic [17:0] ctrlx4b_phy_mac_local_tx_pset_coef [0:3],
    output logic [5:0] ctrlx4b_phy_mac_localfs [0:3],
    output logic [5:0] ctrlx4b_phy_mac_locallf [0:3],
    output logic [5:0] ctrlx4b_phy_mac_dirfeedback [0:3],
    output logic [7:0] ctrlx4b_phy_mac_fomfeedback [0:3],
    output logic ctrlx4b_pclk
);

    mac2phy_lane_t [NL-1:0] w_phy_mac2phy;
    phy2mac_lane_t [NL-1:0] w_phy_phy2mac;
    mac2phy_lane_t [15:0] w_ctrlx16_mac2phy;
    phy2mac_lane_t [15:0] w_ctrlx16_phy2mac;
    mac2phy_lane_t [7:0] w_ctrlx8asdfadssssss_mac2phy;
    phy2mac_lane_t [7:0] w_ctrlx8asdfadssssss_phy2mac;
    mac2phy_lane_t [3:0] w_ctrlx4a_mac2phy;
    phy2mac_lane_t [3:0] w_ctrlx4a_phy2mac;
    mac2phy_lane_t [3:0] w_ctrlx4b_mac2phy;
    phy2mac_lane_t [3:0] w_ctrlx4b_phy2mac;

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
    assign phy_mac_phy_txdata[12] = w_phy_mac2phy[12].mac_phy_txdata;
    assign phy_mac_phy_txdatak[12] = w_phy_mac2phy[12].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[12] = w_phy_mac2phy[12].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[12] = w_phy_mac2phy[12].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[12] = w_phy_mac2phy[12].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[12] = w_phy_mac2phy[12].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[12] = w_phy_mac2phy[12].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[12] = w_phy_mac2phy[12].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[12] = w_phy_mac2phy[12].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[12] = w_phy_mac2phy[12].mac_phy_rxpolarity;
    assign phy_mac_phy_rxstandby[12] = w_phy_mac2phy[12].mac_phy_rxstandby;
    assign phy_mac_phy_messagebus[12] = w_phy_mac2phy[12].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[12] = w_phy_mac2phy[12].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[12] = w_phy_mac2phy[12].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[12] = w_phy_mac2phy[12].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[12] = w_phy_mac2phy[12].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[12] = w_phy_mac2phy[12].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[12] = w_phy_mac2phy[12].mac_phy_fs;
    assign phy_mac_phy_lf[12] = w_phy_mac2phy[12].mac_phy_lf;
    assign phy_mac_phy_dirchange[12] = w_phy_mac2phy[12].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[12] = w_phy_mac2phy[12].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[13] = w_phy_mac2phy[13].mac_phy_txdata;
    assign phy_mac_phy_txdatak[13] = w_phy_mac2phy[13].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[13] = w_phy_mac2phy[13].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[13] = w_phy_mac2phy[13].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[13] = w_phy_mac2phy[13].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[13] = w_phy_mac2phy[13].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[13] = w_phy_mac2phy[13].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[13] = w_phy_mac2phy[13].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[13] = w_phy_mac2phy[13].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[13] = w_phy_mac2phy[13].mac_phy_rxpolarity;
    assign phy_mac_phy_rxstandby[13] = w_phy_mac2phy[13].mac_phy_rxstandby;
    assign phy_mac_phy_messagebus[13] = w_phy_mac2phy[13].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[13] = w_phy_mac2phy[13].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[13] = w_phy_mac2phy[13].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[13] = w_phy_mac2phy[13].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[13] = w_phy_mac2phy[13].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[13] = w_phy_mac2phy[13].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[13] = w_phy_mac2phy[13].mac_phy_fs;
    assign phy_mac_phy_lf[13] = w_phy_mac2phy[13].mac_phy_lf;
    assign phy_mac_phy_dirchange[13] = w_phy_mac2phy[13].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[13] = w_phy_mac2phy[13].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[14] = w_phy_mac2phy[14].mac_phy_txdata;
    assign phy_mac_phy_txdatak[14] = w_phy_mac2phy[14].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[14] = w_phy_mac2phy[14].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[14] = w_phy_mac2phy[14].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[14] = w_phy_mac2phy[14].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[14] = w_phy_mac2phy[14].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[14] = w_phy_mac2phy[14].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[14] = w_phy_mac2phy[14].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[14] = w_phy_mac2phy[14].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[14] = w_phy_mac2phy[14].mac_phy_rxpolarity;
    assign phy_mac_phy_rxstandby[14] = w_phy_mac2phy[14].mac_phy_rxstandby;
    assign phy_mac_phy_messagebus[14] = w_phy_mac2phy[14].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[14] = w_phy_mac2phy[14].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[14] = w_phy_mac2phy[14].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[14] = w_phy_mac2phy[14].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[14] = w_phy_mac2phy[14].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[14] = w_phy_mac2phy[14].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[14] = w_phy_mac2phy[14].mac_phy_fs;
    assign phy_mac_phy_lf[14] = w_phy_mac2phy[14].mac_phy_lf;
    assign phy_mac_phy_dirchange[14] = w_phy_mac2phy[14].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[14] = w_phy_mac2phy[14].mac_phy_rxeqinprogress;
    assign phy_mac_phy_txdata[15] = w_phy_mac2phy[15].mac_phy_txdata;
    assign phy_mac_phy_txdatak[15] = w_phy_mac2phy[15].mac_phy_txdatak;
    assign phy_mac_phy_txdatavalid[15] = w_phy_mac2phy[15].mac_phy_txdatavalid;
    assign phy_mac_phy_txstartblock[15] = w_phy_mac2phy[15].mac_phy_txstartblock;
    assign phy_mac_phy_txsyncheader[15] = w_phy_mac2phy[15].mac_phy_txsyncheader;
    assign phy_mac_phy_txdetectrx_loopback[15] = w_phy_mac2phy[15].mac_phy_txdetectrx_loopback;
    assign phy_mac_phy_txelecidle[15] = w_phy_mac2phy[15].mac_phy_txelecidle;
    assign phy_mac_phy_txcompliance[15] = w_phy_mac2phy[15].mac_phy_txcompliance;
    assign phy_mac_phy_txdeemph[15] = w_phy_mac2phy[15].mac_phy_txdeemph;
    assign phy_mac_phy_rxpolarity[15] = w_phy_mac2phy[15].mac_phy_rxpolarity;
    assign phy_mac_phy_rxstandby[15] = w_phy_mac2phy[15].mac_phy_rxstandby;
    assign phy_mac_phy_messagebus[15] = w_phy_mac2phy[15].mac_phy_messagebus;
    assign phy_mac_phy_rxpresethint[15] = w_phy_mac2phy[15].mac_phy_rxpresethint;
    assign phy_mac_phy_local_pset_index[15] = w_phy_mac2phy[15].mac_phy_local_pset_index;
    assign phy_mac_phy_getlocal_pset_coef[15] = w_phy_mac2phy[15].mac_phy_getlocal_pset_coef;
    assign phy_mac_phy_invalid_req[15] = w_phy_mac2phy[15].mac_phy_invalid_req;
    assign phy_mac_phy_rxeqeval[15] = w_phy_mac2phy[15].mac_phy_rxeqeval;
    assign phy_mac_phy_fs[15] = w_phy_mac2phy[15].mac_phy_fs;
    assign phy_mac_phy_lf[15] = w_phy_mac2phy[15].mac_phy_lf;
    assign phy_mac_phy_dirchange[15] = w_phy_mac2phy[15].mac_phy_dirchange;
    assign phy_mac_phy_rxeqinprogress[15] = w_phy_mac2phy[15].mac_phy_rxeqinprogress;
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
    assign w_phy_phy2mac[12] = '{phy_mac_rxdata: phy_phy_mac_rxdata[12], phy_mac_rxdatak: phy_phy_mac_rxdatak[12], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[12], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[12], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[12], phy_mac_rxvalid: phy_phy_mac_rxvalid[12], phy_mac_rxstatus: phy_phy_mac_rxstatus[12], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[12], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[12], phy_mac_messagebus: phy_phy_mac_messagebus[12], phy_mac_phystatus: phy_phy_mac_phystatus[12], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[12], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[12], phy_mac_localfs: phy_phy_mac_localfs[12], phy_mac_locallf: phy_phy_mac_locallf[12], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[12], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[12]};
    assign w_phy_phy2mac[13] = '{phy_mac_rxdata: phy_phy_mac_rxdata[13], phy_mac_rxdatak: phy_phy_mac_rxdatak[13], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[13], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[13], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[13], phy_mac_rxvalid: phy_phy_mac_rxvalid[13], phy_mac_rxstatus: phy_phy_mac_rxstatus[13], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[13], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[13], phy_mac_messagebus: phy_phy_mac_messagebus[13], phy_mac_phystatus: phy_phy_mac_phystatus[13], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[13], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[13], phy_mac_localfs: phy_phy_mac_localfs[13], phy_mac_locallf: phy_phy_mac_locallf[13], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[13], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[13]};
    assign w_phy_phy2mac[14] = '{phy_mac_rxdata: phy_phy_mac_rxdata[14], phy_mac_rxdatak: phy_phy_mac_rxdatak[14], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[14], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[14], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[14], phy_mac_rxvalid: phy_phy_mac_rxvalid[14], phy_mac_rxstatus: phy_phy_mac_rxstatus[14], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[14], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[14], phy_mac_messagebus: phy_phy_mac_messagebus[14], phy_mac_phystatus: phy_phy_mac_phystatus[14], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[14], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[14], phy_mac_localfs: phy_phy_mac_localfs[14], phy_mac_locallf: phy_phy_mac_locallf[14], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[14], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[14]};
    assign w_phy_phy2mac[15] = '{phy_mac_rxdata: phy_phy_mac_rxdata[15], phy_mac_rxdatak: phy_phy_mac_rxdatak[15], phy_mac_rxdatavalid: phy_phy_mac_rxdatavalid[15], phy_mac_rxstartblock: phy_phy_mac_rxstartblock[15], phy_mac_rxsyncheader: phy_phy_mac_rxsyncheader[15], phy_mac_rxvalid: phy_phy_mac_rxvalid[15], phy_mac_rxstatus: phy_phy_mac_rxstatus[15], phy_mac_rxelecidle: phy_phy_mac_rxelecidle[15], phy_mac_rxstandbystatus: phy_phy_mac_rxstandbystatus[15], phy_mac_messagebus: phy_phy_mac_messagebus[15], phy_mac_phystatus: phy_phy_mac_phystatus[15], phy_mac_local_tx_coef_valid: phy_phy_mac_local_tx_coef_valid[15], phy_mac_local_tx_pset_coef: phy_phy_mac_local_tx_pset_coef[15], phy_mac_localfs: phy_phy_mac_localfs[15], phy_mac_locallf: phy_phy_mac_locallf[15], phy_mac_dirfeedback: phy_phy_mac_dirfeedback[15], phy_mac_fomfeedback: phy_phy_mac_fomfeedback[15]};

    //------------------------------------------------------------
    // CtrlX16 (x16)
    //------------------------------------------------------------
    assign w_ctrlx16_mac2phy[0] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[0], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[0], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[0], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[0], mac_phy_fs: ctrlx16_mac_phy_fs[0], mac_phy_lf: ctrlx16_mac_phy_lf[0], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[0]};
    assign w_ctrlx16_mac2phy[1] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[1], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[1], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[1], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[1], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[1], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[1], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[1], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[1], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[1], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[1], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[1], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[1], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[1], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[1], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[1], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[1], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[1], mac_phy_fs: ctrlx16_mac_phy_fs[1], mac_phy_lf: ctrlx16_mac_phy_lf[1], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[1], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[1]};
    assign w_ctrlx16_mac2phy[2] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[2], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[2], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[2], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[2], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[2], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[2], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[2], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[2], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[2], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[2], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[2], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[2], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[2], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[2], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[2], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[2], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[2], mac_phy_fs: ctrlx16_mac_phy_fs[2], mac_phy_lf: ctrlx16_mac_phy_lf[2], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[2], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[2]};
    assign w_ctrlx16_mac2phy[3] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[3], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[3], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[3], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[3], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[3], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[3], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[3], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[3], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[3], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[3], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[3], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[3], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[3], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[3], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[3], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[3], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[3], mac_phy_fs: ctrlx16_mac_phy_fs[3], mac_phy_lf: ctrlx16_mac_phy_lf[3], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[3], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[3]};
    assign w_ctrlx16_mac2phy[4] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[4], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[4], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[4], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[4], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[4], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[4], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[4], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[4], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[4], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[4], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[4], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[4], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[4], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[4], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[4], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[4], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[4], mac_phy_fs: ctrlx16_mac_phy_fs[4], mac_phy_lf: ctrlx16_mac_phy_lf[4], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[4], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[4]};
    assign w_ctrlx16_mac2phy[5] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[5], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[5], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[5], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[5], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[5], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[5], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[5], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[5], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[5], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[5], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[5], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[5], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[5], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[5], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[5], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[5], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[5], mac_phy_fs: ctrlx16_mac_phy_fs[5], mac_phy_lf: ctrlx16_mac_phy_lf[5], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[5], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[5]};
    assign w_ctrlx16_mac2phy[6] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[6], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[6], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[6], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[6], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[6], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[6], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[6], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[6], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[6], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[6], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[6], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[6], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[6], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[6], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[6], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[6], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[6], mac_phy_fs: ctrlx16_mac_phy_fs[6], mac_phy_lf: ctrlx16_mac_phy_lf[6], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[6], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[6]};
    assign w_ctrlx16_mac2phy[7] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[7], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[7], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[7], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[7], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[7], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[7], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[7], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[7], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[7], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[7], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[7], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[7], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[7], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[7], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[7], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[7], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[7], mac_phy_fs: ctrlx16_mac_phy_fs[7], mac_phy_lf: ctrlx16_mac_phy_lf[7], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[7], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[7]};
    assign w_ctrlx16_mac2phy[8] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[8], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[8], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[8], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[8], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[8], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[8], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[8], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[8], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[8], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[8], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[8], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[8], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[8], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[8], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[8], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[8], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[8], mac_phy_fs: ctrlx16_mac_phy_fs[8], mac_phy_lf: ctrlx16_mac_phy_lf[8], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[8], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[8]};
    assign w_ctrlx16_mac2phy[9] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[9], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[9], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[9], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[9], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[9], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[9], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[9], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[9], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[9], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[9], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[9], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[9], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[9], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[9], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[9], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[9], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[9], mac_phy_fs: ctrlx16_mac_phy_fs[9], mac_phy_lf: ctrlx16_mac_phy_lf[9], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[9], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[9]};
    assign w_ctrlx16_mac2phy[10] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[10], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[10], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[10], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[10], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[10], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[10], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[10], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[10], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[10], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[10], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[10], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[10], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[10], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[10], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[10], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[10], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[10], mac_phy_fs: ctrlx16_mac_phy_fs[10], mac_phy_lf: ctrlx16_mac_phy_lf[10], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[10], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[10]};
    assign w_ctrlx16_mac2phy[11] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[11], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[11], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[11], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[11], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[11], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[11], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[11], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[11], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[11], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[11], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[11], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[11], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[11], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[11], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[11], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[11], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[11], mac_phy_fs: ctrlx16_mac_phy_fs[11], mac_phy_lf: ctrlx16_mac_phy_lf[11], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[11], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[11]};
    assign w_ctrlx16_mac2phy[12] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[12], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[12], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[12], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[12], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[12], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[12], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[12], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[12], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[12], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[12], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[12], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[12], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[12], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[12], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[12], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[12], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[12], mac_phy_fs: ctrlx16_mac_phy_fs[12], mac_phy_lf: ctrlx16_mac_phy_lf[12], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[12], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[12]};
    assign w_ctrlx16_mac2phy[13] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[13], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[13], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[13], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[13], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[13], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[13], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[13], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[13], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[13], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[13], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[13], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[13], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[13], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[13], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[13], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[13], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[13], mac_phy_fs: ctrlx16_mac_phy_fs[13], mac_phy_lf: ctrlx16_mac_phy_lf[13], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[13], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[13]};
    assign w_ctrlx16_mac2phy[14] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[14], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[14], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[14], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[14], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[14], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[14], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[14], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[14], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[14], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[14], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[14], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[14], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[14], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[14], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[14], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[14], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[14], mac_phy_fs: ctrlx16_mac_phy_fs[14], mac_phy_lf: ctrlx16_mac_phy_lf[14], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[14], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[14]};
    assign w_ctrlx16_mac2phy[15] = '{mac_phy_txdata: ctrlx16_mac_phy_txdata[15], mac_phy_txdatak: ctrlx16_mac_phy_txdatak[15], mac_phy_txdatavalid: ctrlx16_mac_phy_txdatavalid[15], mac_phy_txstartblock: ctrlx16_mac_phy_txstartblock[15], mac_phy_txsyncheader: ctrlx16_mac_phy_txsyncheader[15], mac_phy_txdetectrx_loopback: ctrlx16_mac_phy_txdetectrx_loopback[15], mac_phy_txelecidle: ctrlx16_mac_phy_txelecidle[15], mac_phy_txcompliance: ctrlx16_mac_phy_txcompliance[15], mac_phy_txdeemph: ctrlx16_mac_phy_txdeemph[15], mac_phy_rxpolarity: ctrlx16_mac_phy_rxpolarity[15], mac_phy_rxstandby: ctrlx16_mac_phy_rxstandby[15], mac_phy_messagebus: ctrlx16_mac_phy_messagebus[15], mac_phy_rxpresethint: ctrlx16_mac_phy_rxpresethint[15], mac_phy_local_pset_index: ctrlx16_mac_phy_local_pset_index[15], mac_phy_getlocal_pset_coef: ctrlx16_mac_phy_getlocal_pset_coef[15], mac_phy_invalid_req: ctrlx16_mac_phy_invalid_req[15], mac_phy_rxeqeval: ctrlx16_mac_phy_rxeqeval[15], mac_phy_fs: ctrlx16_mac_phy_fs[15], mac_phy_lf: ctrlx16_mac_phy_lf[15], mac_phy_dirchange: ctrlx16_mac_phy_dirchange[15], mac_phy_rxeqinprogress: ctrlx16_mac_phy_rxeqinprogress[15]};
    assign ctrlx16_phy_mac_rxdata[0] = w_ctrlx16_phy2mac[0].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[1] = w_ctrlx16_phy2mac[1].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[2] = w_ctrlx16_phy2mac[2].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[3] = w_ctrlx16_phy2mac[3].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[4] = w_ctrlx16_phy2mac[4].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[5] = w_ctrlx16_phy2mac[5].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[6] = w_ctrlx16_phy2mac[6].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[7] = w_ctrlx16_phy2mac[7].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[8] = w_ctrlx16_phy2mac[8].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[9] = w_ctrlx16_phy2mac[9].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[10] = w_ctrlx16_phy2mac[10].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[11] = w_ctrlx16_phy2mac[11].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[12] = w_ctrlx16_phy2mac[12].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[13] = w_ctrlx16_phy2mac[13].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[14] = w_ctrlx16_phy2mac[14].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdata[15] = w_ctrlx16_phy2mac[15].phy_mac_rxdata;
    assign ctrlx16_phy_mac_rxdatak[0] = w_ctrlx16_phy2mac[0].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[1] = w_ctrlx16_phy2mac[1].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[2] = w_ctrlx16_phy2mac[2].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[3] = w_ctrlx16_phy2mac[3].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[4] = w_ctrlx16_phy2mac[4].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[5] = w_ctrlx16_phy2mac[5].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[6] = w_ctrlx16_phy2mac[6].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[7] = w_ctrlx16_phy2mac[7].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[8] = w_ctrlx16_phy2mac[8].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[9] = w_ctrlx16_phy2mac[9].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[10] = w_ctrlx16_phy2mac[10].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[11] = w_ctrlx16_phy2mac[11].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[12] = w_ctrlx16_phy2mac[12].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[13] = w_ctrlx16_phy2mac[13].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[14] = w_ctrlx16_phy2mac[14].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatak[15] = w_ctrlx16_phy2mac[15].phy_mac_rxdatak;
    assign ctrlx16_phy_mac_rxdatavalid[0] = w_ctrlx16_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[1] = w_ctrlx16_phy2mac[1].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[2] = w_ctrlx16_phy2mac[2].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[3] = w_ctrlx16_phy2mac[3].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[4] = w_ctrlx16_phy2mac[4].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[5] = w_ctrlx16_phy2mac[5].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[6] = w_ctrlx16_phy2mac[6].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[7] = w_ctrlx16_phy2mac[7].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[8] = w_ctrlx16_phy2mac[8].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[9] = w_ctrlx16_phy2mac[9].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[10] = w_ctrlx16_phy2mac[10].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[11] = w_ctrlx16_phy2mac[11].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[12] = w_ctrlx16_phy2mac[12].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[13] = w_ctrlx16_phy2mac[13].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[14] = w_ctrlx16_phy2mac[14].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxdatavalid[15] = w_ctrlx16_phy2mac[15].phy_mac_rxdatavalid;
    assign ctrlx16_phy_mac_rxstartblock[0] = w_ctrlx16_phy2mac[0].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[1] = w_ctrlx16_phy2mac[1].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[2] = w_ctrlx16_phy2mac[2].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[3] = w_ctrlx16_phy2mac[3].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[4] = w_ctrlx16_phy2mac[4].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[5] = w_ctrlx16_phy2mac[5].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[6] = w_ctrlx16_phy2mac[6].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[7] = w_ctrlx16_phy2mac[7].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[8] = w_ctrlx16_phy2mac[8].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[9] = w_ctrlx16_phy2mac[9].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[10] = w_ctrlx16_phy2mac[10].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[11] = w_ctrlx16_phy2mac[11].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[12] = w_ctrlx16_phy2mac[12].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[13] = w_ctrlx16_phy2mac[13].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[14] = w_ctrlx16_phy2mac[14].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxstartblock[15] = w_ctrlx16_phy2mac[15].phy_mac_rxstartblock;
    assign ctrlx16_phy_mac_rxsyncheader[0] = w_ctrlx16_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[1] = w_ctrlx16_phy2mac[1].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[2] = w_ctrlx16_phy2mac[2].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[3] = w_ctrlx16_phy2mac[3].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[4] = w_ctrlx16_phy2mac[4].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[5] = w_ctrlx16_phy2mac[5].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[6] = w_ctrlx16_phy2mac[6].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[7] = w_ctrlx16_phy2mac[7].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[8] = w_ctrlx16_phy2mac[8].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[9] = w_ctrlx16_phy2mac[9].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[10] = w_ctrlx16_phy2mac[10].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[11] = w_ctrlx16_phy2mac[11].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[12] = w_ctrlx16_phy2mac[12].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[13] = w_ctrlx16_phy2mac[13].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[14] = w_ctrlx16_phy2mac[14].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxsyncheader[15] = w_ctrlx16_phy2mac[15].phy_mac_rxsyncheader;
    assign ctrlx16_phy_mac_rxvalid[0] = w_ctrlx16_phy2mac[0].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[1] = w_ctrlx16_phy2mac[1].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[2] = w_ctrlx16_phy2mac[2].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[3] = w_ctrlx16_phy2mac[3].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[4] = w_ctrlx16_phy2mac[4].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[5] = w_ctrlx16_phy2mac[5].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[6] = w_ctrlx16_phy2mac[6].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[7] = w_ctrlx16_phy2mac[7].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[8] = w_ctrlx16_phy2mac[8].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[9] = w_ctrlx16_phy2mac[9].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[10] = w_ctrlx16_phy2mac[10].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[11] = w_ctrlx16_phy2mac[11].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[12] = w_ctrlx16_phy2mac[12].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[13] = w_ctrlx16_phy2mac[13].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[14] = w_ctrlx16_phy2mac[14].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxvalid[15] = w_ctrlx16_phy2mac[15].phy_mac_rxvalid;
    assign ctrlx16_phy_mac_rxstatus[0] = w_ctrlx16_phy2mac[0].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[1] = w_ctrlx16_phy2mac[1].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[2] = w_ctrlx16_phy2mac[2].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[3] = w_ctrlx16_phy2mac[3].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[4] = w_ctrlx16_phy2mac[4].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[5] = w_ctrlx16_phy2mac[5].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[6] = w_ctrlx16_phy2mac[6].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[7] = w_ctrlx16_phy2mac[7].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[8] = w_ctrlx16_phy2mac[8].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[9] = w_ctrlx16_phy2mac[9].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[10] = w_ctrlx16_phy2mac[10].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[11] = w_ctrlx16_phy2mac[11].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[12] = w_ctrlx16_phy2mac[12].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[13] = w_ctrlx16_phy2mac[13].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[14] = w_ctrlx16_phy2mac[14].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxstatus[15] = w_ctrlx16_phy2mac[15].phy_mac_rxstatus;
    assign ctrlx16_phy_mac_rxelecidle[0] = w_ctrlx16_phy2mac[0].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[1] = w_ctrlx16_phy2mac[1].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[2] = w_ctrlx16_phy2mac[2].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[3] = w_ctrlx16_phy2mac[3].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[4] = w_ctrlx16_phy2mac[4].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[5] = w_ctrlx16_phy2mac[5].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[6] = w_ctrlx16_phy2mac[6].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[7] = w_ctrlx16_phy2mac[7].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[8] = w_ctrlx16_phy2mac[8].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[9] = w_ctrlx16_phy2mac[9].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[10] = w_ctrlx16_phy2mac[10].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[11] = w_ctrlx16_phy2mac[11].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[12] = w_ctrlx16_phy2mac[12].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[13] = w_ctrlx16_phy2mac[13].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[14] = w_ctrlx16_phy2mac[14].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxelecidle[15] = w_ctrlx16_phy2mac[15].phy_mac_rxelecidle;
    assign ctrlx16_phy_mac_rxstandbystatus[0] = w_ctrlx16_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[1] = w_ctrlx16_phy2mac[1].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[2] = w_ctrlx16_phy2mac[2].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[3] = w_ctrlx16_phy2mac[3].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[4] = w_ctrlx16_phy2mac[4].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[5] = w_ctrlx16_phy2mac[5].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[6] = w_ctrlx16_phy2mac[6].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[7] = w_ctrlx16_phy2mac[7].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[8] = w_ctrlx16_phy2mac[8].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[9] = w_ctrlx16_phy2mac[9].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[10] = w_ctrlx16_phy2mac[10].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[11] = w_ctrlx16_phy2mac[11].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[12] = w_ctrlx16_phy2mac[12].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[13] = w_ctrlx16_phy2mac[13].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[14] = w_ctrlx16_phy2mac[14].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_rxstandbystatus[15] = w_ctrlx16_phy2mac[15].phy_mac_rxstandbystatus;
    assign ctrlx16_phy_mac_messagebus[0] = w_ctrlx16_phy2mac[0].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[1] = w_ctrlx16_phy2mac[1].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[2] = w_ctrlx16_phy2mac[2].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[3] = w_ctrlx16_phy2mac[3].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[4] = w_ctrlx16_phy2mac[4].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[5] = w_ctrlx16_phy2mac[5].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[6] = w_ctrlx16_phy2mac[6].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[7] = w_ctrlx16_phy2mac[7].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[8] = w_ctrlx16_phy2mac[8].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[9] = w_ctrlx16_phy2mac[9].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[10] = w_ctrlx16_phy2mac[10].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[11] = w_ctrlx16_phy2mac[11].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[12] = w_ctrlx16_phy2mac[12].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[13] = w_ctrlx16_phy2mac[13].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[14] = w_ctrlx16_phy2mac[14].phy_mac_messagebus;
    assign ctrlx16_phy_mac_messagebus[15] = w_ctrlx16_phy2mac[15].phy_mac_messagebus;
    assign ctrlx16_phy_mac_phystatus[0] = w_ctrlx16_phy2mac[0].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[1] = w_ctrlx16_phy2mac[1].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[2] = w_ctrlx16_phy2mac[2].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[3] = w_ctrlx16_phy2mac[3].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[4] = w_ctrlx16_phy2mac[4].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[5] = w_ctrlx16_phy2mac[5].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[6] = w_ctrlx16_phy2mac[6].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[7] = w_ctrlx16_phy2mac[7].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[8] = w_ctrlx16_phy2mac[8].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[9] = w_ctrlx16_phy2mac[9].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[10] = w_ctrlx16_phy2mac[10].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[11] = w_ctrlx16_phy2mac[11].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[12] = w_ctrlx16_phy2mac[12].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[13] = w_ctrlx16_phy2mac[13].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[14] = w_ctrlx16_phy2mac[14].phy_mac_phystatus;
    assign ctrlx16_phy_mac_phystatus[15] = w_ctrlx16_phy2mac[15].phy_mac_phystatus;
    assign ctrlx16_phy_mac_local_tx_coef_valid[0] = w_ctrlx16_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[1] = w_ctrlx16_phy2mac[1].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[2] = w_ctrlx16_phy2mac[2].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[3] = w_ctrlx16_phy2mac[3].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[4] = w_ctrlx16_phy2mac[4].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[5] = w_ctrlx16_phy2mac[5].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[6] = w_ctrlx16_phy2mac[6].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[7] = w_ctrlx16_phy2mac[7].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[8] = w_ctrlx16_phy2mac[8].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[9] = w_ctrlx16_phy2mac[9].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[10] = w_ctrlx16_phy2mac[10].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[11] = w_ctrlx16_phy2mac[11].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[12] = w_ctrlx16_phy2mac[12].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[13] = w_ctrlx16_phy2mac[13].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[14] = w_ctrlx16_phy2mac[14].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_coef_valid[15] = w_ctrlx16_phy2mac[15].phy_mac_local_tx_coef_valid;
    assign ctrlx16_phy_mac_local_tx_pset_coef[0] = w_ctrlx16_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[1] = w_ctrlx16_phy2mac[1].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[2] = w_ctrlx16_phy2mac[2].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[3] = w_ctrlx16_phy2mac[3].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[4] = w_ctrlx16_phy2mac[4].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[5] = w_ctrlx16_phy2mac[5].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[6] = w_ctrlx16_phy2mac[6].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[7] = w_ctrlx16_phy2mac[7].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[8] = w_ctrlx16_phy2mac[8].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[9] = w_ctrlx16_phy2mac[9].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[10] = w_ctrlx16_phy2mac[10].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[11] = w_ctrlx16_phy2mac[11].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[12] = w_ctrlx16_phy2mac[12].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[13] = w_ctrlx16_phy2mac[13].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[14] = w_ctrlx16_phy2mac[14].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_local_tx_pset_coef[15] = w_ctrlx16_phy2mac[15].phy_mac_local_tx_pset_coef;
    assign ctrlx16_phy_mac_localfs[0] = w_ctrlx16_phy2mac[0].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[1] = w_ctrlx16_phy2mac[1].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[2] = w_ctrlx16_phy2mac[2].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[3] = w_ctrlx16_phy2mac[3].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[4] = w_ctrlx16_phy2mac[4].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[5] = w_ctrlx16_phy2mac[5].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[6] = w_ctrlx16_phy2mac[6].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[7] = w_ctrlx16_phy2mac[7].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[8] = w_ctrlx16_phy2mac[8].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[9] = w_ctrlx16_phy2mac[9].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[10] = w_ctrlx16_phy2mac[10].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[11] = w_ctrlx16_phy2mac[11].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[12] = w_ctrlx16_phy2mac[12].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[13] = w_ctrlx16_phy2mac[13].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[14] = w_ctrlx16_phy2mac[14].phy_mac_localfs;
    assign ctrlx16_phy_mac_localfs[15] = w_ctrlx16_phy2mac[15].phy_mac_localfs;
    assign ctrlx16_phy_mac_locallf[0] = w_ctrlx16_phy2mac[0].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[1] = w_ctrlx16_phy2mac[1].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[2] = w_ctrlx16_phy2mac[2].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[3] = w_ctrlx16_phy2mac[3].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[4] = w_ctrlx16_phy2mac[4].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[5] = w_ctrlx16_phy2mac[5].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[6] = w_ctrlx16_phy2mac[6].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[7] = w_ctrlx16_phy2mac[7].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[8] = w_ctrlx16_phy2mac[8].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[9] = w_ctrlx16_phy2mac[9].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[10] = w_ctrlx16_phy2mac[10].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[11] = w_ctrlx16_phy2mac[11].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[12] = w_ctrlx16_phy2mac[12].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[13] = w_ctrlx16_phy2mac[13].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[14] = w_ctrlx16_phy2mac[14].phy_mac_locallf;
    assign ctrlx16_phy_mac_locallf[15] = w_ctrlx16_phy2mac[15].phy_mac_locallf;
    assign ctrlx16_phy_mac_dirfeedback[0] = w_ctrlx16_phy2mac[0].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[1] = w_ctrlx16_phy2mac[1].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[2] = w_ctrlx16_phy2mac[2].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[3] = w_ctrlx16_phy2mac[3].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[4] = w_ctrlx16_phy2mac[4].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[5] = w_ctrlx16_phy2mac[5].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[6] = w_ctrlx16_phy2mac[6].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[7] = w_ctrlx16_phy2mac[7].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[8] = w_ctrlx16_phy2mac[8].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[9] = w_ctrlx16_phy2mac[9].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[10] = w_ctrlx16_phy2mac[10].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[11] = w_ctrlx16_phy2mac[11].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[12] = w_ctrlx16_phy2mac[12].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[13] = w_ctrlx16_phy2mac[13].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[14] = w_ctrlx16_phy2mac[14].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_dirfeedback[15] = w_ctrlx16_phy2mac[15].phy_mac_dirfeedback;
    assign ctrlx16_phy_mac_fomfeedback[0] = w_ctrlx16_phy2mac[0].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[1] = w_ctrlx16_phy2mac[1].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[2] = w_ctrlx16_phy2mac[2].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[3] = w_ctrlx16_phy2mac[3].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[4] = w_ctrlx16_phy2mac[4].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[5] = w_ctrlx16_phy2mac[5].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[6] = w_ctrlx16_phy2mac[6].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[7] = w_ctrlx16_phy2mac[7].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[8] = w_ctrlx16_phy2mac[8].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[9] = w_ctrlx16_phy2mac[9].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[10] = w_ctrlx16_phy2mac[10].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[11] = w_ctrlx16_phy2mac[11].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[12] = w_ctrlx16_phy2mac[12].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[13] = w_ctrlx16_phy2mac[13].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[14] = w_ctrlx16_phy2mac[14].phy_mac_fomfeedback;
    assign ctrlx16_phy_mac_fomfeedback[15] = w_ctrlx16_phy2mac[15].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // CtrlX8asdfadssssss (x8)
    //------------------------------------------------------------
    assign w_ctrlx8asdfadssssss_mac2phy[0] = '{mac_phy_txdata: ctrlx8asdfadssssss_mac_phy_txdata[0], mac_phy_txdatak: ctrlx8asdfadssssss_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrlx8asdfadssssss_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrlx8asdfadssssss_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrlx8asdfadssssss_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrlx8asdfadssssss_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrlx8asdfadssssss_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrlx8asdfadssssss_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrlx8asdfadssssss_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrlx8asdfadssssss_mac_phy_rxpolarity[0], mac_phy_rxstandby: ctrlx8asdfadssssss_mac_phy_rxstandby[0], mac_phy_messagebus: ctrlx8asdfadssssss_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrlx8asdfadssssss_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrlx8asdfadssssss_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrlx8asdfadssssss_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrlx8asdfadssssss_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrlx8asdfadssssss_mac_phy_rxeqeval[0], mac_phy_fs: ctrlx8asdfadssssss_mac_phy_fs[0], mac_phy_lf: ctrlx8asdfadssssss_mac_phy_lf[0], mac_phy_dirchange: ctrlx8asdfadssssss_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrlx8asdfadssssss_mac_phy_rxeqinprogress[0]};
    assign w_ctrlx8asdfadssssss_mac2phy[1] = '{mac_phy_txdata: ctrlx8asdfadssssss_mac_phy_txdata[1], mac_phy_txdatak: ctrlx8asdfadssssss_mac_phy_txdatak[1], mac_phy_txdatavalid: ctrlx8asdfadssssss_mac_phy_txdatavalid[1], mac_phy_txstartblock: ctrlx8asdfadssssss_mac_phy_txstartblock[1], mac_phy_txsyncheader: ctrlx8asdfadssssss_mac_phy_txsyncheader[1], mac_phy_txdetectrx_loopback: ctrlx8asdfadssssss_mac_phy_txdetectrx_loopback[1], mac_phy_txelecidle: ctrlx8asdfadssssss_mac_phy_txelecidle[1], mac_phy_txcompliance: ctrlx8asdfadssssss_mac_phy_txcompliance[1], mac_phy_txdeemph: ctrlx8asdfadssssss_mac_phy_txdeemph[1], mac_phy_rxpolarity: ctrlx8asdfadssssss_mac_phy_rxpolarity[1], mac_phy_rxstandby: ctrlx8asdfadssssss_mac_phy_rxstandby[1], mac_phy_messagebus: ctrlx8asdfadssssss_mac_phy_messagebus[1], mac_phy_rxpresethint: ctrlx8asdfadssssss_mac_phy_rxpresethint[1], mac_phy_local_pset_index: ctrlx8asdfadssssss_mac_phy_local_pset_index[1], mac_phy_getlocal_pset_coef: ctrlx8asdfadssssss_mac_phy_getlocal_pset_coef[1], mac_phy_invalid_req: ctrlx8asdfadssssss_mac_phy_invalid_req[1], mac_phy_rxeqeval: ctrlx8asdfadssssss_mac_phy_rxeqeval[1], mac_phy_fs: ctrlx8asdfadssssss_mac_phy_fs[1], mac_phy_lf: ctrlx8asdfadssssss_mac_phy_lf[1], mac_phy_dirchange: ctrlx8asdfadssssss_mac_phy_dirchange[1], mac_phy_rxeqinprogress: ctrlx8asdfadssssss_mac_phy_rxeqinprogress[1]};
    assign w_ctrlx8asdfadssssss_mac2phy[2] = '{mac_phy_txdata: ctrlx8asdfadssssss_mac_phy_txdata[2], mac_phy_txdatak: ctrlx8asdfadssssss_mac_phy_txdatak[2], mac_phy_txdatavalid: ctrlx8asdfadssssss_mac_phy_txdatavalid[2], mac_phy_txstartblock: ctrlx8asdfadssssss_mac_phy_txstartblock[2], mac_phy_txsyncheader: ctrlx8asdfadssssss_mac_phy_txsyncheader[2], mac_phy_txdetectrx_loopback: ctrlx8asdfadssssss_mac_phy_txdetectrx_loopback[2], mac_phy_txelecidle: ctrlx8asdfadssssss_mac_phy_txelecidle[2], mac_phy_txcompliance: ctrlx8asdfadssssss_mac_phy_txcompliance[2], mac_phy_txdeemph: ctrlx8asdfadssssss_mac_phy_txdeemph[2], mac_phy_rxpolarity: ctrlx8asdfadssssss_mac_phy_rxpolarity[2], mac_phy_rxstandby: ctrlx8asdfadssssss_mac_phy_rxstandby[2], mac_phy_messagebus: ctrlx8asdfadssssss_mac_phy_messagebus[2], mac_phy_rxpresethint: ctrlx8asdfadssssss_mac_phy_rxpresethint[2], mac_phy_local_pset_index: ctrlx8asdfadssssss_mac_phy_local_pset_index[2], mac_phy_getlocal_pset_coef: ctrlx8asdfadssssss_mac_phy_getlocal_pset_coef[2], mac_phy_invalid_req: ctrlx8asdfadssssss_mac_phy_invalid_req[2], mac_phy_rxeqeval: ctrlx8asdfadssssss_mac_phy_rxeqeval[2], mac_phy_fs: ctrlx8asdfadssssss_mac_phy_fs[2], mac_phy_lf: ctrlx8asdfadssssss_mac_phy_lf[2], mac_phy_dirchange: ctrlx8asdfadssssss_mac_phy_dirchange[2], mac_phy_rxeqinprogress: ctrlx8asdfadssssss_mac_phy_rxeqinprogress[2]};
    assign w_ctrlx8asdfadssssss_mac2phy[3] = '{mac_phy_txdata: ctrlx8asdfadssssss_mac_phy_txdata[3], mac_phy_txdatak: ctrlx8asdfadssssss_mac_phy_txdatak[3], mac_phy_txdatavalid: ctrlx8asdfadssssss_mac_phy_txdatavalid[3], mac_phy_txstartblock: ctrlx8asdfadssssss_mac_phy_txstartblock[3], mac_phy_txsyncheader: ctrlx8asdfadssssss_mac_phy_txsyncheader[3], mac_phy_txdetectrx_loopback: ctrlx8asdfadssssss_mac_phy_txdetectrx_loopback[3], mac_phy_txelecidle: ctrlx8asdfadssssss_mac_phy_txelecidle[3], mac_phy_txcompliance: ctrlx8asdfadssssss_mac_phy_txcompliance[3], mac_phy_txdeemph: ctrlx8asdfadssssss_mac_phy_txdeemph[3], mac_phy_rxpolarity: ctrlx8asdfadssssss_mac_phy_rxpolarity[3], mac_phy_rxstandby: ctrlx8asdfadssssss_mac_phy_rxstandby[3], mac_phy_messagebus: ctrlx8asdfadssssss_mac_phy_messagebus[3], mac_phy_rxpresethint: ctrlx8asdfadssssss_mac_phy_rxpresethint[3], mac_phy_local_pset_index: ctrlx8asdfadssssss_mac_phy_local_pset_index[3], mac_phy_getlocal_pset_coef: ctrlx8asdfadssssss_mac_phy_getlocal_pset_coef[3], mac_phy_invalid_req: ctrlx8asdfadssssss_mac_phy_invalid_req[3], mac_phy_rxeqeval: ctrlx8asdfadssssss_mac_phy_rxeqeval[3], mac_phy_fs: ctrlx8asdfadssssss_mac_phy_fs[3], mac_phy_lf: ctrlx8asdfadssssss_mac_phy_lf[3], mac_phy_dirchange: ctrlx8asdfadssssss_mac_phy_dirchange[3], mac_phy_rxeqinprogress: ctrlx8asdfadssssss_mac_phy_rxeqinprogress[3]};
    assign w_ctrlx8asdfadssssss_mac2phy[4] = '{mac_phy_txdata: ctrlx8asdfadssssss_mac_phy_txdata[4], mac_phy_txdatak: ctrlx8asdfadssssss_mac_phy_txdatak[4], mac_phy_txdatavalid: ctrlx8asdfadssssss_mac_phy_txdatavalid[4], mac_phy_txstartblock: ctrlx8asdfadssssss_mac_phy_txstartblock[4], mac_phy_txsyncheader: ctrlx8asdfadssssss_mac_phy_txsyncheader[4], mac_phy_txdetectrx_loopback: ctrlx8asdfadssssss_mac_phy_txdetectrx_loopback[4], mac_phy_txelecidle: ctrlx8asdfadssssss_mac_phy_txelecidle[4], mac_phy_txcompliance: ctrlx8asdfadssssss_mac_phy_txcompliance[4], mac_phy_txdeemph: ctrlx8asdfadssssss_mac_phy_txdeemph[4], mac_phy_rxpolarity: ctrlx8asdfadssssss_mac_phy_rxpolarity[4], mac_phy_rxstandby: ctrlx8asdfadssssss_mac_phy_rxstandby[4], mac_phy_messagebus: ctrlx8asdfadssssss_mac_phy_messagebus[4], mac_phy_rxpresethint: ctrlx8asdfadssssss_mac_phy_rxpresethint[4], mac_phy_local_pset_index: ctrlx8asdfadssssss_mac_phy_local_pset_index[4], mac_phy_getlocal_pset_coef: ctrlx8asdfadssssss_mac_phy_getlocal_pset_coef[4], mac_phy_invalid_req: ctrlx8asdfadssssss_mac_phy_invalid_req[4], mac_phy_rxeqeval: ctrlx8asdfadssssss_mac_phy_rxeqeval[4], mac_phy_fs: ctrlx8asdfadssssss_mac_phy_fs[4], mac_phy_lf: ctrlx8asdfadssssss_mac_phy_lf[4], mac_phy_dirchange: ctrlx8asdfadssssss_mac_phy_dirchange[4], mac_phy_rxeqinprogress: ctrlx8asdfadssssss_mac_phy_rxeqinprogress[4]};
    assign w_ctrlx8asdfadssssss_mac2phy[5] = '{mac_phy_txdata: ctrlx8asdfadssssss_mac_phy_txdata[5], mac_phy_txdatak: ctrlx8asdfadssssss_mac_phy_txdatak[5], mac_phy_txdatavalid: ctrlx8asdfadssssss_mac_phy_txdatavalid[5], mac_phy_txstartblock: ctrlx8asdfadssssss_mac_phy_txstartblock[5], mac_phy_txsyncheader: ctrlx8asdfadssssss_mac_phy_txsyncheader[5], mac_phy_txdetectrx_loopback: ctrlx8asdfadssssss_mac_phy_txdetectrx_loopback[5], mac_phy_txelecidle: ctrlx8asdfadssssss_mac_phy_txelecidle[5], mac_phy_txcompliance: ctrlx8asdfadssssss_mac_phy_txcompliance[5], mac_phy_txdeemph: ctrlx8asdfadssssss_mac_phy_txdeemph[5], mac_phy_rxpolarity: ctrlx8asdfadssssss_mac_phy_rxpolarity[5], mac_phy_rxstandby: ctrlx8asdfadssssss_mac_phy_rxstandby[5], mac_phy_messagebus: ctrlx8asdfadssssss_mac_phy_messagebus[5], mac_phy_rxpresethint: ctrlx8asdfadssssss_mac_phy_rxpresethint[5], mac_phy_local_pset_index: ctrlx8asdfadssssss_mac_phy_local_pset_index[5], mac_phy_getlocal_pset_coef: ctrlx8asdfadssssss_mac_phy_getlocal_pset_coef[5], mac_phy_invalid_req: ctrlx8asdfadssssss_mac_phy_invalid_req[5], mac_phy_rxeqeval: ctrlx8asdfadssssss_mac_phy_rxeqeval[5], mac_phy_fs: ctrlx8asdfadssssss_mac_phy_fs[5], mac_phy_lf: ctrlx8asdfadssssss_mac_phy_lf[5], mac_phy_dirchange: ctrlx8asdfadssssss_mac_phy_dirchange[5], mac_phy_rxeqinprogress: ctrlx8asdfadssssss_mac_phy_rxeqinprogress[5]};
    assign w_ctrlx8asdfadssssss_mac2phy[6] = '{mac_phy_txdata: ctrlx8asdfadssssss_mac_phy_txdata[6], mac_phy_txdatak: ctrlx8asdfadssssss_mac_phy_txdatak[6], mac_phy_txdatavalid: ctrlx8asdfadssssss_mac_phy_txdatavalid[6], mac_phy_txstartblock: ctrlx8asdfadssssss_mac_phy_txstartblock[6], mac_phy_txsyncheader: ctrlx8asdfadssssss_mac_phy_txsyncheader[6], mac_phy_txdetectrx_loopback: ctrlx8asdfadssssss_mac_phy_txdetectrx_loopback[6], mac_phy_txelecidle: ctrlx8asdfadssssss_mac_phy_txelecidle[6], mac_phy_txcompliance: ctrlx8asdfadssssss_mac_phy_txcompliance[6], mac_phy_txdeemph: ctrlx8asdfadssssss_mac_phy_txdeemph[6], mac_phy_rxpolarity: ctrlx8asdfadssssss_mac_phy_rxpolarity[6], mac_phy_rxstandby: ctrlx8asdfadssssss_mac_phy_rxstandby[6], mac_phy_messagebus: ctrlx8asdfadssssss_mac_phy_messagebus[6], mac_phy_rxpresethint: ctrlx8asdfadssssss_mac_phy_rxpresethint[6], mac_phy_local_pset_index: ctrlx8asdfadssssss_mac_phy_local_pset_index[6], mac_phy_getlocal_pset_coef: ctrlx8asdfadssssss_mac_phy_getlocal_pset_coef[6], mac_phy_invalid_req: ctrlx8asdfadssssss_mac_phy_invalid_req[6], mac_phy_rxeqeval: ctrlx8asdfadssssss_mac_phy_rxeqeval[6], mac_phy_fs: ctrlx8asdfadssssss_mac_phy_fs[6], mac_phy_lf: ctrlx8asdfadssssss_mac_phy_lf[6], mac_phy_dirchange: ctrlx8asdfadssssss_mac_phy_dirchange[6], mac_phy_rxeqinprogress: ctrlx8asdfadssssss_mac_phy_rxeqinprogress[6]};
    assign w_ctrlx8asdfadssssss_mac2phy[7] = '{mac_phy_txdata: ctrlx8asdfadssssss_mac_phy_txdata[7], mac_phy_txdatak: ctrlx8asdfadssssss_mac_phy_txdatak[7], mac_phy_txdatavalid: ctrlx8asdfadssssss_mac_phy_txdatavalid[7], mac_phy_txstartblock: ctrlx8asdfadssssss_mac_phy_txstartblock[7], mac_phy_txsyncheader: ctrlx8asdfadssssss_mac_phy_txsyncheader[7], mac_phy_txdetectrx_loopback: ctrlx8asdfadssssss_mac_phy_txdetectrx_loopback[7], mac_phy_txelecidle: ctrlx8asdfadssssss_mac_phy_txelecidle[7], mac_phy_txcompliance: ctrlx8asdfadssssss_mac_phy_txcompliance[7], mac_phy_txdeemph: ctrlx8asdfadssssss_mac_phy_txdeemph[7], mac_phy_rxpolarity: ctrlx8asdfadssssss_mac_phy_rxpolarity[7], mac_phy_rxstandby: ctrlx8asdfadssssss_mac_phy_rxstandby[7], mac_phy_messagebus: ctrlx8asdfadssssss_mac_phy_messagebus[7], mac_phy_rxpresethint: ctrlx8asdfadssssss_mac_phy_rxpresethint[7], mac_phy_local_pset_index: ctrlx8asdfadssssss_mac_phy_local_pset_index[7], mac_phy_getlocal_pset_coef: ctrlx8asdfadssssss_mac_phy_getlocal_pset_coef[7], mac_phy_invalid_req: ctrlx8asdfadssssss_mac_phy_invalid_req[7], mac_phy_rxeqeval: ctrlx8asdfadssssss_mac_phy_rxeqeval[7], mac_phy_fs: ctrlx8asdfadssssss_mac_phy_fs[7], mac_phy_lf: ctrlx8asdfadssssss_mac_phy_lf[7], mac_phy_dirchange: ctrlx8asdfadssssss_mac_phy_dirchange[7], mac_phy_rxeqinprogress: ctrlx8asdfadssssss_mac_phy_rxeqinprogress[7]};
    assign ctrlx8asdfadssssss_phy_mac_rxdata[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_rxdata;
    assign ctrlx8asdfadssssss_phy_mac_rxdata[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_rxdata;
    assign ctrlx8asdfadssssss_phy_mac_rxdata[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_rxdata;
    assign ctrlx8asdfadssssss_phy_mac_rxdata[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_rxdata;
    assign ctrlx8asdfadssssss_phy_mac_rxdata[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_rxdata;
    assign ctrlx8asdfadssssss_phy_mac_rxdata[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_rxdata;
    assign ctrlx8asdfadssssss_phy_mac_rxdata[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_rxdata;
    assign ctrlx8asdfadssssss_phy_mac_rxdata[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_rxdata;
    assign ctrlx8asdfadssssss_phy_mac_rxdatak[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_rxdatak;
    assign ctrlx8asdfadssssss_phy_mac_rxdatak[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_rxdatak;
    assign ctrlx8asdfadssssss_phy_mac_rxdatak[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_rxdatak;
    assign ctrlx8asdfadssssss_phy_mac_rxdatak[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_rxdatak;
    assign ctrlx8asdfadssssss_phy_mac_rxdatak[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_rxdatak;
    assign ctrlx8asdfadssssss_phy_mac_rxdatak[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_rxdatak;
    assign ctrlx8asdfadssssss_phy_mac_rxdatak[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_rxdatak;
    assign ctrlx8asdfadssssss_phy_mac_rxdatak[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_rxdatak;
    assign ctrlx8asdfadssssss_phy_mac_rxdatavalid[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrlx8asdfadssssss_phy_mac_rxdatavalid[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_rxdatavalid;
    assign ctrlx8asdfadssssss_phy_mac_rxdatavalid[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_rxdatavalid;
    assign ctrlx8asdfadssssss_phy_mac_rxdatavalid[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_rxdatavalid;
    assign ctrlx8asdfadssssss_phy_mac_rxdatavalid[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_rxdatavalid;
    assign ctrlx8asdfadssssss_phy_mac_rxdatavalid[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_rxdatavalid;
    assign ctrlx8asdfadssssss_phy_mac_rxdatavalid[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_rxdatavalid;
    assign ctrlx8asdfadssssss_phy_mac_rxdatavalid[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_rxdatavalid;
    assign ctrlx8asdfadssssss_phy_mac_rxstartblock[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_rxstartblock;
    assign ctrlx8asdfadssssss_phy_mac_rxstartblock[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_rxstartblock;
    assign ctrlx8asdfadssssss_phy_mac_rxstartblock[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_rxstartblock;
    assign ctrlx8asdfadssssss_phy_mac_rxstartblock[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_rxstartblock;
    assign ctrlx8asdfadssssss_phy_mac_rxstartblock[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_rxstartblock;
    assign ctrlx8asdfadssssss_phy_mac_rxstartblock[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_rxstartblock;
    assign ctrlx8asdfadssssss_phy_mac_rxstartblock[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_rxstartblock;
    assign ctrlx8asdfadssssss_phy_mac_rxstartblock[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_rxstartblock;
    assign ctrlx8asdfadssssss_phy_mac_rxsyncheader[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrlx8asdfadssssss_phy_mac_rxsyncheader[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_rxsyncheader;
    assign ctrlx8asdfadssssss_phy_mac_rxsyncheader[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_rxsyncheader;
    assign ctrlx8asdfadssssss_phy_mac_rxsyncheader[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_rxsyncheader;
    assign ctrlx8asdfadssssss_phy_mac_rxsyncheader[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_rxsyncheader;
    assign ctrlx8asdfadssssss_phy_mac_rxsyncheader[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_rxsyncheader;
    assign ctrlx8asdfadssssss_phy_mac_rxsyncheader[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_rxsyncheader;
    assign ctrlx8asdfadssssss_phy_mac_rxsyncheader[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_rxsyncheader;
    assign ctrlx8asdfadssssss_phy_mac_rxvalid[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_rxvalid;
    assign ctrlx8asdfadssssss_phy_mac_rxvalid[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_rxvalid;
    assign ctrlx8asdfadssssss_phy_mac_rxvalid[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_rxvalid;
    assign ctrlx8asdfadssssss_phy_mac_rxvalid[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_rxvalid;
    assign ctrlx8asdfadssssss_phy_mac_rxvalid[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_rxvalid;
    assign ctrlx8asdfadssssss_phy_mac_rxvalid[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_rxvalid;
    assign ctrlx8asdfadssssss_phy_mac_rxvalid[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_rxvalid;
    assign ctrlx8asdfadssssss_phy_mac_rxvalid[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_rxvalid;
    assign ctrlx8asdfadssssss_phy_mac_rxstatus[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_rxstatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstatus[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_rxstatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstatus[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_rxstatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstatus[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_rxstatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstatus[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_rxstatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstatus[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_rxstatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstatus[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_rxstatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstatus[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_rxstatus;
    assign ctrlx8asdfadssssss_phy_mac_rxelecidle[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_rxelecidle;
    assign ctrlx8asdfadssssss_phy_mac_rxelecidle[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_rxelecidle;
    assign ctrlx8asdfadssssss_phy_mac_rxelecidle[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_rxelecidle;
    assign ctrlx8asdfadssssss_phy_mac_rxelecidle[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_rxelecidle;
    assign ctrlx8asdfadssssss_phy_mac_rxelecidle[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_rxelecidle;
    assign ctrlx8asdfadssssss_phy_mac_rxelecidle[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_rxelecidle;
    assign ctrlx8asdfadssssss_phy_mac_rxelecidle[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_rxelecidle;
    assign ctrlx8asdfadssssss_phy_mac_rxelecidle[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_rxelecidle;
    assign ctrlx8asdfadssssss_phy_mac_rxstandbystatus[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstandbystatus[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_rxstandbystatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstandbystatus[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_rxstandbystatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstandbystatus[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_rxstandbystatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstandbystatus[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_rxstandbystatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstandbystatus[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_rxstandbystatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstandbystatus[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_rxstandbystatus;
    assign ctrlx8asdfadssssss_phy_mac_rxstandbystatus[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_rxstandbystatus;
    assign ctrlx8asdfadssssss_phy_mac_messagebus[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_messagebus;
    assign ctrlx8asdfadssssss_phy_mac_messagebus[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_messagebus;
    assign ctrlx8asdfadssssss_phy_mac_messagebus[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_messagebus;
    assign ctrlx8asdfadssssss_phy_mac_messagebus[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_messagebus;
    assign ctrlx8asdfadssssss_phy_mac_messagebus[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_messagebus;
    assign ctrlx8asdfadssssss_phy_mac_messagebus[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_messagebus;
    assign ctrlx8asdfadssssss_phy_mac_messagebus[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_messagebus;
    assign ctrlx8asdfadssssss_phy_mac_messagebus[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_messagebus;
    assign ctrlx8asdfadssssss_phy_mac_phystatus[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_phystatus;
    assign ctrlx8asdfadssssss_phy_mac_phystatus[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_phystatus;
    assign ctrlx8asdfadssssss_phy_mac_phystatus[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_phystatus;
    assign ctrlx8asdfadssssss_phy_mac_phystatus[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_phystatus;
    assign ctrlx8asdfadssssss_phy_mac_phystatus[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_phystatus;
    assign ctrlx8asdfadssssss_phy_mac_phystatus[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_phystatus;
    assign ctrlx8asdfadssssss_phy_mac_phystatus[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_phystatus;
    assign ctrlx8asdfadssssss_phy_mac_phystatus[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_phystatus;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_coef_valid[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_coef_valid[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_local_tx_coef_valid;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_coef_valid[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_local_tx_coef_valid;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_coef_valid[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_local_tx_coef_valid;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_coef_valid[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_local_tx_coef_valid;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_coef_valid[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_local_tx_coef_valid;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_coef_valid[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_local_tx_coef_valid;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_coef_valid[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_local_tx_coef_valid;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_pset_coef[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_pset_coef[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_local_tx_pset_coef;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_pset_coef[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_local_tx_pset_coef;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_pset_coef[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_local_tx_pset_coef;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_pset_coef[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_local_tx_pset_coef;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_pset_coef[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_local_tx_pset_coef;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_pset_coef[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_local_tx_pset_coef;
    assign ctrlx8asdfadssssss_phy_mac_local_tx_pset_coef[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_local_tx_pset_coef;
    assign ctrlx8asdfadssssss_phy_mac_localfs[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_localfs;
    assign ctrlx8asdfadssssss_phy_mac_localfs[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_localfs;
    assign ctrlx8asdfadssssss_phy_mac_localfs[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_localfs;
    assign ctrlx8asdfadssssss_phy_mac_localfs[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_localfs;
    assign ctrlx8asdfadssssss_phy_mac_localfs[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_localfs;
    assign ctrlx8asdfadssssss_phy_mac_localfs[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_localfs;
    assign ctrlx8asdfadssssss_phy_mac_localfs[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_localfs;
    assign ctrlx8asdfadssssss_phy_mac_localfs[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_localfs;
    assign ctrlx8asdfadssssss_phy_mac_locallf[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_locallf;
    assign ctrlx8asdfadssssss_phy_mac_locallf[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_locallf;
    assign ctrlx8asdfadssssss_phy_mac_locallf[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_locallf;
    assign ctrlx8asdfadssssss_phy_mac_locallf[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_locallf;
    assign ctrlx8asdfadssssss_phy_mac_locallf[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_locallf;
    assign ctrlx8asdfadssssss_phy_mac_locallf[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_locallf;
    assign ctrlx8asdfadssssss_phy_mac_locallf[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_locallf;
    assign ctrlx8asdfadssssss_phy_mac_locallf[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_locallf;
    assign ctrlx8asdfadssssss_phy_mac_dirfeedback[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_dirfeedback;
    assign ctrlx8asdfadssssss_phy_mac_dirfeedback[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_dirfeedback;
    assign ctrlx8asdfadssssss_phy_mac_dirfeedback[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_dirfeedback;
    assign ctrlx8asdfadssssss_phy_mac_dirfeedback[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_dirfeedback;
    assign ctrlx8asdfadssssss_phy_mac_dirfeedback[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_dirfeedback;
    assign ctrlx8asdfadssssss_phy_mac_dirfeedback[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_dirfeedback;
    assign ctrlx8asdfadssssss_phy_mac_dirfeedback[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_dirfeedback;
    assign ctrlx8asdfadssssss_phy_mac_dirfeedback[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_dirfeedback;
    assign ctrlx8asdfadssssss_phy_mac_fomfeedback[0] = w_ctrlx8asdfadssssss_phy2mac[0].phy_mac_fomfeedback;
    assign ctrlx8asdfadssssss_phy_mac_fomfeedback[1] = w_ctrlx8asdfadssssss_phy2mac[1].phy_mac_fomfeedback;
    assign ctrlx8asdfadssssss_phy_mac_fomfeedback[2] = w_ctrlx8asdfadssssss_phy2mac[2].phy_mac_fomfeedback;
    assign ctrlx8asdfadssssss_phy_mac_fomfeedback[3] = w_ctrlx8asdfadssssss_phy2mac[3].phy_mac_fomfeedback;
    assign ctrlx8asdfadssssss_phy_mac_fomfeedback[4] = w_ctrlx8asdfadssssss_phy2mac[4].phy_mac_fomfeedback;
    assign ctrlx8asdfadssssss_phy_mac_fomfeedback[5] = w_ctrlx8asdfadssssss_phy2mac[5].phy_mac_fomfeedback;
    assign ctrlx8asdfadssssss_phy_mac_fomfeedback[6] = w_ctrlx8asdfadssssss_phy2mac[6].phy_mac_fomfeedback;
    assign ctrlx8asdfadssssss_phy_mac_fomfeedback[7] = w_ctrlx8asdfadssssss_phy2mac[7].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // CtrlX4a (x4)
    //------------------------------------------------------------
    assign w_ctrlx4a_mac2phy[0] = '{mac_phy_txdata: ctrlx4a_mac_phy_txdata[0], mac_phy_txdatak: ctrlx4a_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrlx4a_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrlx4a_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrlx4a_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrlx4a_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrlx4a_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrlx4a_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrlx4a_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrlx4a_mac_phy_rxpolarity[0], mac_phy_rxstandby: ctrlx4a_mac_phy_rxstandby[0], mac_phy_messagebus: ctrlx4a_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrlx4a_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrlx4a_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrlx4a_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrlx4a_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrlx4a_mac_phy_rxeqeval[0], mac_phy_fs: ctrlx4a_mac_phy_fs[0], mac_phy_lf: ctrlx4a_mac_phy_lf[0], mac_phy_dirchange: ctrlx4a_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrlx4a_mac_phy_rxeqinprogress[0]};
    assign w_ctrlx4a_mac2phy[1] = '{mac_phy_txdata: ctrlx4a_mac_phy_txdata[1], mac_phy_txdatak: ctrlx4a_mac_phy_txdatak[1], mac_phy_txdatavalid: ctrlx4a_mac_phy_txdatavalid[1], mac_phy_txstartblock: ctrlx4a_mac_phy_txstartblock[1], mac_phy_txsyncheader: ctrlx4a_mac_phy_txsyncheader[1], mac_phy_txdetectrx_loopback: ctrlx4a_mac_phy_txdetectrx_loopback[1], mac_phy_txelecidle: ctrlx4a_mac_phy_txelecidle[1], mac_phy_txcompliance: ctrlx4a_mac_phy_txcompliance[1], mac_phy_txdeemph: ctrlx4a_mac_phy_txdeemph[1], mac_phy_rxpolarity: ctrlx4a_mac_phy_rxpolarity[1], mac_phy_rxstandby: ctrlx4a_mac_phy_rxstandby[1], mac_phy_messagebus: ctrlx4a_mac_phy_messagebus[1], mac_phy_rxpresethint: ctrlx4a_mac_phy_rxpresethint[1], mac_phy_local_pset_index: ctrlx4a_mac_phy_local_pset_index[1], mac_phy_getlocal_pset_coef: ctrlx4a_mac_phy_getlocal_pset_coef[1], mac_phy_invalid_req: ctrlx4a_mac_phy_invalid_req[1], mac_phy_rxeqeval: ctrlx4a_mac_phy_rxeqeval[1], mac_phy_fs: ctrlx4a_mac_phy_fs[1], mac_phy_lf: ctrlx4a_mac_phy_lf[1], mac_phy_dirchange: ctrlx4a_mac_phy_dirchange[1], mac_phy_rxeqinprogress: ctrlx4a_mac_phy_rxeqinprogress[1]};
    assign w_ctrlx4a_mac2phy[2] = '{mac_phy_txdata: ctrlx4a_mac_phy_txdata[2], mac_phy_txdatak: ctrlx4a_mac_phy_txdatak[2], mac_phy_txdatavalid: ctrlx4a_mac_phy_txdatavalid[2], mac_phy_txstartblock: ctrlx4a_mac_phy_txstartblock[2], mac_phy_txsyncheader: ctrlx4a_mac_phy_txsyncheader[2], mac_phy_txdetectrx_loopback: ctrlx4a_mac_phy_txdetectrx_loopback[2], mac_phy_txelecidle: ctrlx4a_mac_phy_txelecidle[2], mac_phy_txcompliance: ctrlx4a_mac_phy_txcompliance[2], mac_phy_txdeemph: ctrlx4a_mac_phy_txdeemph[2], mac_phy_rxpolarity: ctrlx4a_mac_phy_rxpolarity[2], mac_phy_rxstandby: ctrlx4a_mac_phy_rxstandby[2], mac_phy_messagebus: ctrlx4a_mac_phy_messagebus[2], mac_phy_rxpresethint: ctrlx4a_mac_phy_rxpresethint[2], mac_phy_local_pset_index: ctrlx4a_mac_phy_local_pset_index[2], mac_phy_getlocal_pset_coef: ctrlx4a_mac_phy_getlocal_pset_coef[2], mac_phy_invalid_req: ctrlx4a_mac_phy_invalid_req[2], mac_phy_rxeqeval: ctrlx4a_mac_phy_rxeqeval[2], mac_phy_fs: ctrlx4a_mac_phy_fs[2], mac_phy_lf: ctrlx4a_mac_phy_lf[2], mac_phy_dirchange: ctrlx4a_mac_phy_dirchange[2], mac_phy_rxeqinprogress: ctrlx4a_mac_phy_rxeqinprogress[2]};
    assign w_ctrlx4a_mac2phy[3] = '{mac_phy_txdata: ctrlx4a_mac_phy_txdata[3], mac_phy_txdatak: ctrlx4a_mac_phy_txdatak[3], mac_phy_txdatavalid: ctrlx4a_mac_phy_txdatavalid[3], mac_phy_txstartblock: ctrlx4a_mac_phy_txstartblock[3], mac_phy_txsyncheader: ctrlx4a_mac_phy_txsyncheader[3], mac_phy_txdetectrx_loopback: ctrlx4a_mac_phy_txdetectrx_loopback[3], mac_phy_txelecidle: ctrlx4a_mac_phy_txelecidle[3], mac_phy_txcompliance: ctrlx4a_mac_phy_txcompliance[3], mac_phy_txdeemph: ctrlx4a_mac_phy_txdeemph[3], mac_phy_rxpolarity: ctrlx4a_mac_phy_rxpolarity[3], mac_phy_rxstandby: ctrlx4a_mac_phy_rxstandby[3], mac_phy_messagebus: ctrlx4a_mac_phy_messagebus[3], mac_phy_rxpresethint: ctrlx4a_mac_phy_rxpresethint[3], mac_phy_local_pset_index: ctrlx4a_mac_phy_local_pset_index[3], mac_phy_getlocal_pset_coef: ctrlx4a_mac_phy_getlocal_pset_coef[3], mac_phy_invalid_req: ctrlx4a_mac_phy_invalid_req[3], mac_phy_rxeqeval: ctrlx4a_mac_phy_rxeqeval[3], mac_phy_fs: ctrlx4a_mac_phy_fs[3], mac_phy_lf: ctrlx4a_mac_phy_lf[3], mac_phy_dirchange: ctrlx4a_mac_phy_dirchange[3], mac_phy_rxeqinprogress: ctrlx4a_mac_phy_rxeqinprogress[3]};
    assign ctrlx4a_phy_mac_rxdata[0] = w_ctrlx4a_phy2mac[0].phy_mac_rxdata;
    assign ctrlx4a_phy_mac_rxdata[1] = w_ctrlx4a_phy2mac[1].phy_mac_rxdata;
    assign ctrlx4a_phy_mac_rxdata[2] = w_ctrlx4a_phy2mac[2].phy_mac_rxdata;
    assign ctrlx4a_phy_mac_rxdata[3] = w_ctrlx4a_phy2mac[3].phy_mac_rxdata;
    assign ctrlx4a_phy_mac_rxdatak[0] = w_ctrlx4a_phy2mac[0].phy_mac_rxdatak;
    assign ctrlx4a_phy_mac_rxdatak[1] = w_ctrlx4a_phy2mac[1].phy_mac_rxdatak;
    assign ctrlx4a_phy_mac_rxdatak[2] = w_ctrlx4a_phy2mac[2].phy_mac_rxdatak;
    assign ctrlx4a_phy_mac_rxdatak[3] = w_ctrlx4a_phy2mac[3].phy_mac_rxdatak;
    assign ctrlx4a_phy_mac_rxdatavalid[0] = w_ctrlx4a_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrlx4a_phy_mac_rxdatavalid[1] = w_ctrlx4a_phy2mac[1].phy_mac_rxdatavalid;
    assign ctrlx4a_phy_mac_rxdatavalid[2] = w_ctrlx4a_phy2mac[2].phy_mac_rxdatavalid;
    assign ctrlx4a_phy_mac_rxdatavalid[3] = w_ctrlx4a_phy2mac[3].phy_mac_rxdatavalid;
    assign ctrlx4a_phy_mac_rxstartblock[0] = w_ctrlx4a_phy2mac[0].phy_mac_rxstartblock;
    assign ctrlx4a_phy_mac_rxstartblock[1] = w_ctrlx4a_phy2mac[1].phy_mac_rxstartblock;
    assign ctrlx4a_phy_mac_rxstartblock[2] = w_ctrlx4a_phy2mac[2].phy_mac_rxstartblock;
    assign ctrlx4a_phy_mac_rxstartblock[3] = w_ctrlx4a_phy2mac[3].phy_mac_rxstartblock;
    assign ctrlx4a_phy_mac_rxsyncheader[0] = w_ctrlx4a_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrlx4a_phy_mac_rxsyncheader[1] = w_ctrlx4a_phy2mac[1].phy_mac_rxsyncheader;
    assign ctrlx4a_phy_mac_rxsyncheader[2] = w_ctrlx4a_phy2mac[2].phy_mac_rxsyncheader;
    assign ctrlx4a_phy_mac_rxsyncheader[3] = w_ctrlx4a_phy2mac[3].phy_mac_rxsyncheader;
    assign ctrlx4a_phy_mac_rxvalid[0] = w_ctrlx4a_phy2mac[0].phy_mac_rxvalid;
    assign ctrlx4a_phy_mac_rxvalid[1] = w_ctrlx4a_phy2mac[1].phy_mac_rxvalid;
    assign ctrlx4a_phy_mac_rxvalid[2] = w_ctrlx4a_phy2mac[2].phy_mac_rxvalid;
    assign ctrlx4a_phy_mac_rxvalid[3] = w_ctrlx4a_phy2mac[3].phy_mac_rxvalid;
    assign ctrlx4a_phy_mac_rxstatus[0] = w_ctrlx4a_phy2mac[0].phy_mac_rxstatus;
    assign ctrlx4a_phy_mac_rxstatus[1] = w_ctrlx4a_phy2mac[1].phy_mac_rxstatus;
    assign ctrlx4a_phy_mac_rxstatus[2] = w_ctrlx4a_phy2mac[2].phy_mac_rxstatus;
    assign ctrlx4a_phy_mac_rxstatus[3] = w_ctrlx4a_phy2mac[3].phy_mac_rxstatus;
    assign ctrlx4a_phy_mac_rxelecidle[0] = w_ctrlx4a_phy2mac[0].phy_mac_rxelecidle;
    assign ctrlx4a_phy_mac_rxelecidle[1] = w_ctrlx4a_phy2mac[1].phy_mac_rxelecidle;
    assign ctrlx4a_phy_mac_rxelecidle[2] = w_ctrlx4a_phy2mac[2].phy_mac_rxelecidle;
    assign ctrlx4a_phy_mac_rxelecidle[3] = w_ctrlx4a_phy2mac[3].phy_mac_rxelecidle;
    assign ctrlx4a_phy_mac_rxstandbystatus[0] = w_ctrlx4a_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrlx4a_phy_mac_rxstandbystatus[1] = w_ctrlx4a_phy2mac[1].phy_mac_rxstandbystatus;
    assign ctrlx4a_phy_mac_rxstandbystatus[2] = w_ctrlx4a_phy2mac[2].phy_mac_rxstandbystatus;
    assign ctrlx4a_phy_mac_rxstandbystatus[3] = w_ctrlx4a_phy2mac[3].phy_mac_rxstandbystatus;
    assign ctrlx4a_phy_mac_messagebus[0] = w_ctrlx4a_phy2mac[0].phy_mac_messagebus;
    assign ctrlx4a_phy_mac_messagebus[1] = w_ctrlx4a_phy2mac[1].phy_mac_messagebus;
    assign ctrlx4a_phy_mac_messagebus[2] = w_ctrlx4a_phy2mac[2].phy_mac_messagebus;
    assign ctrlx4a_phy_mac_messagebus[3] = w_ctrlx4a_phy2mac[3].phy_mac_messagebus;
    assign ctrlx4a_phy_mac_phystatus[0] = w_ctrlx4a_phy2mac[0].phy_mac_phystatus;
    assign ctrlx4a_phy_mac_phystatus[1] = w_ctrlx4a_phy2mac[1].phy_mac_phystatus;
    assign ctrlx4a_phy_mac_phystatus[2] = w_ctrlx4a_phy2mac[2].phy_mac_phystatus;
    assign ctrlx4a_phy_mac_phystatus[3] = w_ctrlx4a_phy2mac[3].phy_mac_phystatus;
    assign ctrlx4a_phy_mac_local_tx_coef_valid[0] = w_ctrlx4a_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrlx4a_phy_mac_local_tx_coef_valid[1] = w_ctrlx4a_phy2mac[1].phy_mac_local_tx_coef_valid;
    assign ctrlx4a_phy_mac_local_tx_coef_valid[2] = w_ctrlx4a_phy2mac[2].phy_mac_local_tx_coef_valid;
    assign ctrlx4a_phy_mac_local_tx_coef_valid[3] = w_ctrlx4a_phy2mac[3].phy_mac_local_tx_coef_valid;
    assign ctrlx4a_phy_mac_local_tx_pset_coef[0] = w_ctrlx4a_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrlx4a_phy_mac_local_tx_pset_coef[1] = w_ctrlx4a_phy2mac[1].phy_mac_local_tx_pset_coef;
    assign ctrlx4a_phy_mac_local_tx_pset_coef[2] = w_ctrlx4a_phy2mac[2].phy_mac_local_tx_pset_coef;
    assign ctrlx4a_phy_mac_local_tx_pset_coef[3] = w_ctrlx4a_phy2mac[3].phy_mac_local_tx_pset_coef;
    assign ctrlx4a_phy_mac_localfs[0] = w_ctrlx4a_phy2mac[0].phy_mac_localfs;
    assign ctrlx4a_phy_mac_localfs[1] = w_ctrlx4a_phy2mac[1].phy_mac_localfs;
    assign ctrlx4a_phy_mac_localfs[2] = w_ctrlx4a_phy2mac[2].phy_mac_localfs;
    assign ctrlx4a_phy_mac_localfs[3] = w_ctrlx4a_phy2mac[3].phy_mac_localfs;
    assign ctrlx4a_phy_mac_locallf[0] = w_ctrlx4a_phy2mac[0].phy_mac_locallf;
    assign ctrlx4a_phy_mac_locallf[1] = w_ctrlx4a_phy2mac[1].phy_mac_locallf;
    assign ctrlx4a_phy_mac_locallf[2] = w_ctrlx4a_phy2mac[2].phy_mac_locallf;
    assign ctrlx4a_phy_mac_locallf[3] = w_ctrlx4a_phy2mac[3].phy_mac_locallf;
    assign ctrlx4a_phy_mac_dirfeedback[0] = w_ctrlx4a_phy2mac[0].phy_mac_dirfeedback;
    assign ctrlx4a_phy_mac_dirfeedback[1] = w_ctrlx4a_phy2mac[1].phy_mac_dirfeedback;
    assign ctrlx4a_phy_mac_dirfeedback[2] = w_ctrlx4a_phy2mac[2].phy_mac_dirfeedback;
    assign ctrlx4a_phy_mac_dirfeedback[3] = w_ctrlx4a_phy2mac[3].phy_mac_dirfeedback;
    assign ctrlx4a_phy_mac_fomfeedback[0] = w_ctrlx4a_phy2mac[0].phy_mac_fomfeedback;
    assign ctrlx4a_phy_mac_fomfeedback[1] = w_ctrlx4a_phy2mac[1].phy_mac_fomfeedback;
    assign ctrlx4a_phy_mac_fomfeedback[2] = w_ctrlx4a_phy2mac[2].phy_mac_fomfeedback;
    assign ctrlx4a_phy_mac_fomfeedback[3] = w_ctrlx4a_phy2mac[3].phy_mac_fomfeedback;

    //------------------------------------------------------------
    // CtrlX4b (x4)
    //------------------------------------------------------------
    assign w_ctrlx4b_mac2phy[0] = '{mac_phy_txdata: ctrlx4b_mac_phy_txdata[0], mac_phy_txdatak: ctrlx4b_mac_phy_txdatak[0], mac_phy_txdatavalid: ctrlx4b_mac_phy_txdatavalid[0], mac_phy_txstartblock: ctrlx4b_mac_phy_txstartblock[0], mac_phy_txsyncheader: ctrlx4b_mac_phy_txsyncheader[0], mac_phy_txdetectrx_loopback: ctrlx4b_mac_phy_txdetectrx_loopback[0], mac_phy_txelecidle: ctrlx4b_mac_phy_txelecidle[0], mac_phy_txcompliance: ctrlx4b_mac_phy_txcompliance[0], mac_phy_txdeemph: ctrlx4b_mac_phy_txdeemph[0], mac_phy_rxpolarity: ctrlx4b_mac_phy_rxpolarity[0], mac_phy_rxstandby: ctrlx4b_mac_phy_rxstandby[0], mac_phy_messagebus: ctrlx4b_mac_phy_messagebus[0], mac_phy_rxpresethint: ctrlx4b_mac_phy_rxpresethint[0], mac_phy_local_pset_index: ctrlx4b_mac_phy_local_pset_index[0], mac_phy_getlocal_pset_coef: ctrlx4b_mac_phy_getlocal_pset_coef[0], mac_phy_invalid_req: ctrlx4b_mac_phy_invalid_req[0], mac_phy_rxeqeval: ctrlx4b_mac_phy_rxeqeval[0], mac_phy_fs: ctrlx4b_mac_phy_fs[0], mac_phy_lf: ctrlx4b_mac_phy_lf[0], mac_phy_dirchange: ctrlx4b_mac_phy_dirchange[0], mac_phy_rxeqinprogress: ctrlx4b_mac_phy_rxeqinprogress[0]};
    assign w_ctrlx4b_mac2phy[1] = '{mac_phy_txdata: ctrlx4b_mac_phy_txdata[1], mac_phy_txdatak: ctrlx4b_mac_phy_txdatak[1], mac_phy_txdatavalid: ctrlx4b_mac_phy_txdatavalid[1], mac_phy_txstartblock: ctrlx4b_mac_phy_txstartblock[1], mac_phy_txsyncheader: ctrlx4b_mac_phy_txsyncheader[1], mac_phy_txdetectrx_loopback: ctrlx4b_mac_phy_txdetectrx_loopback[1], mac_phy_txelecidle: ctrlx4b_mac_phy_txelecidle[1], mac_phy_txcompliance: ctrlx4b_mac_phy_txcompliance[1], mac_phy_txdeemph: ctrlx4b_mac_phy_txdeemph[1], mac_phy_rxpolarity: ctrlx4b_mac_phy_rxpolarity[1], mac_phy_rxstandby: ctrlx4b_mac_phy_rxstandby[1], mac_phy_messagebus: ctrlx4b_mac_phy_messagebus[1], mac_phy_rxpresethint: ctrlx4b_mac_phy_rxpresethint[1], mac_phy_local_pset_index: ctrlx4b_mac_phy_local_pset_index[1], mac_phy_getlocal_pset_coef: ctrlx4b_mac_phy_getlocal_pset_coef[1], mac_phy_invalid_req: ctrlx4b_mac_phy_invalid_req[1], mac_phy_rxeqeval: ctrlx4b_mac_phy_rxeqeval[1], mac_phy_fs: ctrlx4b_mac_phy_fs[1], mac_phy_lf: ctrlx4b_mac_phy_lf[1], mac_phy_dirchange: ctrlx4b_mac_phy_dirchange[1], mac_phy_rxeqinprogress: ctrlx4b_mac_phy_rxeqinprogress[1]};
    assign w_ctrlx4b_mac2phy[2] = '{mac_phy_txdata: ctrlx4b_mac_phy_txdata[2], mac_phy_txdatak: ctrlx4b_mac_phy_txdatak[2], mac_phy_txdatavalid: ctrlx4b_mac_phy_txdatavalid[2], mac_phy_txstartblock: ctrlx4b_mac_phy_txstartblock[2], mac_phy_txsyncheader: ctrlx4b_mac_phy_txsyncheader[2], mac_phy_txdetectrx_loopback: ctrlx4b_mac_phy_txdetectrx_loopback[2], mac_phy_txelecidle: ctrlx4b_mac_phy_txelecidle[2], mac_phy_txcompliance: ctrlx4b_mac_phy_txcompliance[2], mac_phy_txdeemph: ctrlx4b_mac_phy_txdeemph[2], mac_phy_rxpolarity: ctrlx4b_mac_phy_rxpolarity[2], mac_phy_rxstandby: ctrlx4b_mac_phy_rxstandby[2], mac_phy_messagebus: ctrlx4b_mac_phy_messagebus[2], mac_phy_rxpresethint: ctrlx4b_mac_phy_rxpresethint[2], mac_phy_local_pset_index: ctrlx4b_mac_phy_local_pset_index[2], mac_phy_getlocal_pset_coef: ctrlx4b_mac_phy_getlocal_pset_coef[2], mac_phy_invalid_req: ctrlx4b_mac_phy_invalid_req[2], mac_phy_rxeqeval: ctrlx4b_mac_phy_rxeqeval[2], mac_phy_fs: ctrlx4b_mac_phy_fs[2], mac_phy_lf: ctrlx4b_mac_phy_lf[2], mac_phy_dirchange: ctrlx4b_mac_phy_dirchange[2], mac_phy_rxeqinprogress: ctrlx4b_mac_phy_rxeqinprogress[2]};
    assign w_ctrlx4b_mac2phy[3] = '{mac_phy_txdata: ctrlx4b_mac_phy_txdata[3], mac_phy_txdatak: ctrlx4b_mac_phy_txdatak[3], mac_phy_txdatavalid: ctrlx4b_mac_phy_txdatavalid[3], mac_phy_txstartblock: ctrlx4b_mac_phy_txstartblock[3], mac_phy_txsyncheader: ctrlx4b_mac_phy_txsyncheader[3], mac_phy_txdetectrx_loopback: ctrlx4b_mac_phy_txdetectrx_loopback[3], mac_phy_txelecidle: ctrlx4b_mac_phy_txelecidle[3], mac_phy_txcompliance: ctrlx4b_mac_phy_txcompliance[3], mac_phy_txdeemph: ctrlx4b_mac_phy_txdeemph[3], mac_phy_rxpolarity: ctrlx4b_mac_phy_rxpolarity[3], mac_phy_rxstandby: ctrlx4b_mac_phy_rxstandby[3], mac_phy_messagebus: ctrlx4b_mac_phy_messagebus[3], mac_phy_rxpresethint: ctrlx4b_mac_phy_rxpresethint[3], mac_phy_local_pset_index: ctrlx4b_mac_phy_local_pset_index[3], mac_phy_getlocal_pset_coef: ctrlx4b_mac_phy_getlocal_pset_coef[3], mac_phy_invalid_req: ctrlx4b_mac_phy_invalid_req[3], mac_phy_rxeqeval: ctrlx4b_mac_phy_rxeqeval[3], mac_phy_fs: ctrlx4b_mac_phy_fs[3], mac_phy_lf: ctrlx4b_mac_phy_lf[3], mac_phy_dirchange: ctrlx4b_mac_phy_dirchange[3], mac_phy_rxeqinprogress: ctrlx4b_mac_phy_rxeqinprogress[3]};
    assign ctrlx4b_phy_mac_rxdata[0] = w_ctrlx4b_phy2mac[0].phy_mac_rxdata;
    assign ctrlx4b_phy_mac_rxdata[1] = w_ctrlx4b_phy2mac[1].phy_mac_rxdata;
    assign ctrlx4b_phy_mac_rxdata[2] = w_ctrlx4b_phy2mac[2].phy_mac_rxdata;
    assign ctrlx4b_phy_mac_rxdata[3] = w_ctrlx4b_phy2mac[3].phy_mac_rxdata;
    assign ctrlx4b_phy_mac_rxdatak[0] = w_ctrlx4b_phy2mac[0].phy_mac_rxdatak;
    assign ctrlx4b_phy_mac_rxdatak[1] = w_ctrlx4b_phy2mac[1].phy_mac_rxdatak;
    assign ctrlx4b_phy_mac_rxdatak[2] = w_ctrlx4b_phy2mac[2].phy_mac_rxdatak;
    assign ctrlx4b_phy_mac_rxdatak[3] = w_ctrlx4b_phy2mac[3].phy_mac_rxdatak;
    assign ctrlx4b_phy_mac_rxdatavalid[0] = w_ctrlx4b_phy2mac[0].phy_mac_rxdatavalid;
    assign ctrlx4b_phy_mac_rxdatavalid[1] = w_ctrlx4b_phy2mac[1].phy_mac_rxdatavalid;
    assign ctrlx4b_phy_mac_rxdatavalid[2] = w_ctrlx4b_phy2mac[2].phy_mac_rxdatavalid;
    assign ctrlx4b_phy_mac_rxdatavalid[3] = w_ctrlx4b_phy2mac[3].phy_mac_rxdatavalid;
    assign ctrlx4b_phy_mac_rxstartblock[0] = w_ctrlx4b_phy2mac[0].phy_mac_rxstartblock;
    assign ctrlx4b_phy_mac_rxstartblock[1] = w_ctrlx4b_phy2mac[1].phy_mac_rxstartblock;
    assign ctrlx4b_phy_mac_rxstartblock[2] = w_ctrlx4b_phy2mac[2].phy_mac_rxstartblock;
    assign ctrlx4b_phy_mac_rxstartblock[3] = w_ctrlx4b_phy2mac[3].phy_mac_rxstartblock;
    assign ctrlx4b_phy_mac_rxsyncheader[0] = w_ctrlx4b_phy2mac[0].phy_mac_rxsyncheader;
    assign ctrlx4b_phy_mac_rxsyncheader[1] = w_ctrlx4b_phy2mac[1].phy_mac_rxsyncheader;
    assign ctrlx4b_phy_mac_rxsyncheader[2] = w_ctrlx4b_phy2mac[2].phy_mac_rxsyncheader;
    assign ctrlx4b_phy_mac_rxsyncheader[3] = w_ctrlx4b_phy2mac[3].phy_mac_rxsyncheader;
    assign ctrlx4b_phy_mac_rxvalid[0] = w_ctrlx4b_phy2mac[0].phy_mac_rxvalid;
    assign ctrlx4b_phy_mac_rxvalid[1] = w_ctrlx4b_phy2mac[1].phy_mac_rxvalid;
    assign ctrlx4b_phy_mac_rxvalid[2] = w_ctrlx4b_phy2mac[2].phy_mac_rxvalid;
    assign ctrlx4b_phy_mac_rxvalid[3] = w_ctrlx4b_phy2mac[3].phy_mac_rxvalid;
    assign ctrlx4b_phy_mac_rxstatus[0] = w_ctrlx4b_phy2mac[0].phy_mac_rxstatus;
    assign ctrlx4b_phy_mac_rxstatus[1] = w_ctrlx4b_phy2mac[1].phy_mac_rxstatus;
    assign ctrlx4b_phy_mac_rxstatus[2] = w_ctrlx4b_phy2mac[2].phy_mac_rxstatus;
    assign ctrlx4b_phy_mac_rxstatus[3] = w_ctrlx4b_phy2mac[3].phy_mac_rxstatus;
    assign ctrlx4b_phy_mac_rxelecidle[0] = w_ctrlx4b_phy2mac[0].phy_mac_rxelecidle;
    assign ctrlx4b_phy_mac_rxelecidle[1] = w_ctrlx4b_phy2mac[1].phy_mac_rxelecidle;
    assign ctrlx4b_phy_mac_rxelecidle[2] = w_ctrlx4b_phy2mac[2].phy_mac_rxelecidle;
    assign ctrlx4b_phy_mac_rxelecidle[3] = w_ctrlx4b_phy2mac[3].phy_mac_rxelecidle;
    assign ctrlx4b_phy_mac_rxstandbystatus[0] = w_ctrlx4b_phy2mac[0].phy_mac_rxstandbystatus;
    assign ctrlx4b_phy_mac_rxstandbystatus[1] = w_ctrlx4b_phy2mac[1].phy_mac_rxstandbystatus;
    assign ctrlx4b_phy_mac_rxstandbystatus[2] = w_ctrlx4b_phy2mac[2].phy_mac_rxstandbystatus;
    assign ctrlx4b_phy_mac_rxstandbystatus[3] = w_ctrlx4b_phy2mac[3].phy_mac_rxstandbystatus;
    assign ctrlx4b_phy_mac_messagebus[0] = w_ctrlx4b_phy2mac[0].phy_mac_messagebus;
    assign ctrlx4b_phy_mac_messagebus[1] = w_ctrlx4b_phy2mac[1].phy_mac_messagebus;
    assign ctrlx4b_phy_mac_messagebus[2] = w_ctrlx4b_phy2mac[2].phy_mac_messagebus;
    assign ctrlx4b_phy_mac_messagebus[3] = w_ctrlx4b_phy2mac[3].phy_mac_messagebus;
    assign ctrlx4b_phy_mac_phystatus[0] = w_ctrlx4b_phy2mac[0].phy_mac_phystatus;
    assign ctrlx4b_phy_mac_phystatus[1] = w_ctrlx4b_phy2mac[1].phy_mac_phystatus;
    assign ctrlx4b_phy_mac_phystatus[2] = w_ctrlx4b_phy2mac[2].phy_mac_phystatus;
    assign ctrlx4b_phy_mac_phystatus[3] = w_ctrlx4b_phy2mac[3].phy_mac_phystatus;
    assign ctrlx4b_phy_mac_local_tx_coef_valid[0] = w_ctrlx4b_phy2mac[0].phy_mac_local_tx_coef_valid;
    assign ctrlx4b_phy_mac_local_tx_coef_valid[1] = w_ctrlx4b_phy2mac[1].phy_mac_local_tx_coef_valid;
    assign ctrlx4b_phy_mac_local_tx_coef_valid[2] = w_ctrlx4b_phy2mac[2].phy_mac_local_tx_coef_valid;
    assign ctrlx4b_phy_mac_local_tx_coef_valid[3] = w_ctrlx4b_phy2mac[3].phy_mac_local_tx_coef_valid;
    assign ctrlx4b_phy_mac_local_tx_pset_coef[0] = w_ctrlx4b_phy2mac[0].phy_mac_local_tx_pset_coef;
    assign ctrlx4b_phy_mac_local_tx_pset_coef[1] = w_ctrlx4b_phy2mac[1].phy_mac_local_tx_pset_coef;
    assign ctrlx4b_phy_mac_local_tx_pset_coef[2] = w_ctrlx4b_phy2mac[2].phy_mac_local_tx_pset_coef;
    assign ctrlx4b_phy_mac_local_tx_pset_coef[3] = w_ctrlx4b_phy2mac[3].phy_mac_local_tx_pset_coef;
    assign ctrlx4b_phy_mac_localfs[0] = w_ctrlx4b_phy2mac[0].phy_mac_localfs;
    assign ctrlx4b_phy_mac_localfs[1] = w_ctrlx4b_phy2mac[1].phy_mac_localfs;
    assign ctrlx4b_phy_mac_localfs[2] = w_ctrlx4b_phy2mac[2].phy_mac_localfs;
    assign ctrlx4b_phy_mac_localfs[3] = w_ctrlx4b_phy2mac[3].phy_mac_localfs;
    assign ctrlx4b_phy_mac_locallf[0] = w_ctrlx4b_phy2mac[0].phy_mac_locallf;
    assign ctrlx4b_phy_mac_locallf[1] = w_ctrlx4b_phy2mac[1].phy_mac_locallf;
    assign ctrlx4b_phy_mac_locallf[2] = w_ctrlx4b_phy2mac[2].phy_mac_locallf;
    assign ctrlx4b_phy_mac_locallf[3] = w_ctrlx4b_phy2mac[3].phy_mac_locallf;
    assign ctrlx4b_phy_mac_dirfeedback[0] = w_ctrlx4b_phy2mac[0].phy_mac_dirfeedback;
    assign ctrlx4b_phy_mac_dirfeedback[1] = w_ctrlx4b_phy2mac[1].phy_mac_dirfeedback;
    assign ctrlx4b_phy_mac_dirfeedback[2] = w_ctrlx4b_phy2mac[2].phy_mac_dirfeedback;
    assign ctrlx4b_phy_mac_dirfeedback[3] = w_ctrlx4b_phy2mac[3].phy_mac_dirfeedback;
    assign ctrlx4b_phy_mac_fomfeedback[0] = w_ctrlx4b_phy2mac[0].phy_mac_fomfeedback;
    assign ctrlx4b_phy_mac_fomfeedback[1] = w_ctrlx4b_phy2mac[1].phy_mac_fomfeedback;
    assign ctrlx4b_phy_mac_fomfeedback[2] = w_ctrlx4b_phy2mac[2].phy_mac_fomfeedback;
    assign ctrlx4b_phy_mac_fomfeedback[3] = w_ctrlx4b_phy2mac[3].phy_mac_fomfeedback;

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
        .ctrlx16_rst_n   (ctrlx16_rst_n),
        .ctrlx16_mac2phy (w_ctrlx16_mac2phy),
        .ctrlx16_phy2mac (w_ctrlx16_phy2mac),
        .ctrlx16_pclk (ctrlx16_pclk),
        .ctrlx8asdfadssssss_rst_n   (ctrlx8asdfadssssss_rst_n),
        .ctrlx8asdfadssssss_mac2phy (w_ctrlx8asdfadssssss_mac2phy),
        .ctrlx8asdfadssssss_phy2mac (w_ctrlx8asdfadssssss_phy2mac),
        .ctrlx8asdfadssssss_pclk (ctrlx8asdfadssssss_pclk),
        .ctrlx4a_rst_n   (ctrlx4a_rst_n),
        .ctrlx4a_mac2phy (w_ctrlx4a_mac2phy),
        .ctrlx4a_phy2mac (w_ctrlx4a_phy2mac),
        .ctrlx4a_pclk (ctrlx4a_pclk),
        .ctrlx4b_rst_n   (ctrlx4b_rst_n),
        .ctrlx4b_mac2phy (w_ctrlx4b_mac2phy),
        .ctrlx4b_phy2mac (w_ctrlx4b_phy2mac),
        .ctrlx4b_pclk (ctrlx4b_pclk)
    );

endmodule
