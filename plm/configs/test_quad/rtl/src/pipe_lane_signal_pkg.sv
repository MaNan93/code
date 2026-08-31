package pipe_lane_signal_pkg;

    // mac2phy direction; signals that go through NOV are packed into one type;
    typedef struct packed {
        logic [31:0] mac_phy_txdata;
        logic [3:0] mac_phy_txdatak;
        logic mac_phy_txdatavalid;
        logic mac_phy_txstartblock;
        logic [1:0] mac_phy_txsyncheader;
        logic mac_phy_txdetectrx_loopback;
        logic mac_phy_txelecidle;
        logic mac_phy_txcompliance;
        logic [17:0] mac_phy_txdeemph;
        logic mac_phy_rxpolarity;
        logic mac_phy_rxstandby;
        logic [7:0] mac_phy_messagebus;
        logic [2:0] mac_phy_rxpresethint;
        logic [4:0] mac_phy_local_pset_index;
        logic mac_phy_getlocal_pset_coef;
        logic mac_phy_invalid_req;
        logic mac_phy_rxeqeval;
        logic [5:0] mac_phy_fs;
        logic [5:0] mac_phy_lf;
        logic mac_phy_dirchange;
        logic mac_phy_rxeqinprogress;
    } mac2phy_lane_t;

    // phy2mac direction; signals that go through NOV are packed into one type;
    typedef struct packed {
        logic [31:0] phy_mac_rxdata;
        logic [3:0] phy_mac_rxdatak;
        logic phy_mac_rxdatavalid;
        logic phy_mac_rxstartblock;
        logic [1:0] phy_mac_rxsyncheader;
        logic phy_mac_rxvalid;
        logic [2:0] phy_mac_rxstatus;
        logic phy_mac_rxelecidle;
        logic phy_mac_rxstandbystatus;
        logic [7:0] phy_mac_messagebus;
        logic phy_mac_phystatus;
        logic phy_mac_local_tx_coef_valid;
        logic [17:0] phy_mac_local_tx_pset_coef;
        logic [5:0] phy_mac_localfs;
        logic [5:0] phy_mac_locallf;
        logic [5:0] phy_mac_dirfeedback;
        logic [7:0] phy_mac_fomfeedback;
    } phy2mac_lane_t;

    // Value to present when there's no owner (the NOV handoff window).
    // pipe_lane_data_mux uses this for polarity normalization, so sel==0 naturally lands on the safe state.
    localparam mac2phy_lane_t SAFE_M2P = '{
        mac_phy_txdata: 32'd0,
        mac_phy_txdatak: 4'd0,
        mac_phy_txdatavalid: 1'b0,
        mac_phy_txstartblock: 1'b0,
        mac_phy_txsyncheader: 2'd0,
        mac_phy_txdetectrx_loopback: 1'b0,
        mac_phy_txelecidle: 1'b1,
        mac_phy_txcompliance: 1'b0,
        mac_phy_txdeemph: 18'd0,
        mac_phy_rxpolarity: 1'b0,
        mac_phy_rxstandby: 1'b0,
        mac_phy_messagebus: 8'd0,
        mac_phy_rxpresethint: 3'd0,
        mac_phy_local_pset_index: 5'd0,
        mac_phy_getlocal_pset_coef: 1'b0,
        mac_phy_invalid_req: 1'b0,
        mac_phy_rxeqeval: 1'b0,
        mac_phy_fs: 6'd0,
        mac_phy_lf: 6'd0,
        mac_phy_dirchange: 1'b0,
        mac_phy_rxeqinprogress: 1'b0
    };

    // Value to present when there's no owner (the NOV handoff window).
    // pipe_lane_data_mux uses this for polarity normalization, so sel==0 naturally lands on the safe state.
    localparam phy2mac_lane_t SAFE_P2M = '{
        phy_mac_rxdata: 32'd0,
        phy_mac_rxdatak: 4'd0,
        phy_mac_rxdatavalid: 1'b0,
        phy_mac_rxstartblock: 1'b0,
        phy_mac_rxsyncheader: 2'd0,
        phy_mac_rxvalid: 1'b0,
        phy_mac_rxstatus: 3'd0,
        phy_mac_rxelecidle: 1'b1,
        phy_mac_rxstandbystatus: 1'b1,
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: 1'b0,
        phy_mac_local_tx_coef_valid: 1'b0,
        phy_mac_local_tx_pset_coef: 18'd0,
        phy_mac_localfs: 6'd0,
        phy_mac_locallf: 6'd0,
        phy_mac_dirfeedback: 6'd0,
        phy_mac_fomfeedback: 8'd0
    };

    // One one-hot select vector per lane group that needs NOV.
    // Direct groups don't appear here -- the type itself shows they have no choice to make.
    // G0 (lane0~2): direct to CtrlA, no sel
    // G1 (lane3~5): bit0=CtrlA, bit1=CtrlB
    // G2 (lane6~8): bit0=CtrlA, bit1=CtrlC
    // G3 (lane9~11): bit0=CtrlA, bit1=CtrlB, bit2=CtrlC, bit3=CtrlD
    typedef struct packed {
        logic [1:0] g1;
        logic [1:0] g2;
        logic [3:0] g3;
    } lane_sel_t;

endpackage
