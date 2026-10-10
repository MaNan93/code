`timescale 1ns/1ps
//=============================================================================
// tb_pipe_lane_mapper -- self-checking functional simulation, driven by this config set's lane_mapping.csv.
//
// Checks:
//   1. Steady-state data routing matches lane_mapping.csv exactly
//   2. Unmapped controller lanes read back SAFE_P2M
//   3. Group sel vectors are always one-hot0 (non-overlap)
//   4. During the NOV handoff window (sel all-zero), phy lanes present the safe state (txelecidle=1)
//   5. phy_rst_n follows the current owner's ctrl_rst_n
//   6. Independent phy_perst_n follows the current owner's ctrl_perst_n
//=============================================================================
import pipe_lane_signal_pkg::*;

module tb_pipe_lane_mapper;

    localparam int NL = 12;
    localparam int NC   = 4;

    //------------------------------------------------------------ clocks
    // Different period + phase offset per controller (its own reference
    // clock) and per lane (rx_clk), to exercise asynchronous CDC.
    localparam int unsigned CTRL_PERIOD_NS [0:3] = '{
        3,
        5,
        7,
        9
    };
    localparam int unsigned LANE_PERIOD_NS [0:11] = '{
        5,
        7,
        9,
        11,
        13,
        15,
        17,
        5,
        7,
        9,
        11,
        13
    };

    logic [NC-1:0] ctrl_ref_clk;
    logic [NL-1:0] rx_clk;

    logic ctrl_ref_clk_src_0 = 1'b0;
    initial begin
        forever #1.5 ctrl_ref_clk_src_0 = ~ctrl_ref_clk_src_0;
    end
    assign ctrl_ref_clk[0] = ctrl_ref_clk_src_0;
    logic ctrl_ref_clk_src_1 = 1'b0;
    initial begin
        #0.7;
        forever #2.5 ctrl_ref_clk_src_1 = ~ctrl_ref_clk_src_1;
    end
    assign ctrl_ref_clk[1] = ctrl_ref_clk_src_1;
    logic ctrl_ref_clk_src_2 = 1'b0;
    initial begin
        #1.4;
        forever #3.5 ctrl_ref_clk_src_2 = ~ctrl_ref_clk_src_2;
    end
    assign ctrl_ref_clk[2] = ctrl_ref_clk_src_2;
    logic ctrl_ref_clk_src_3 = 1'b0;
    initial begin
        #2.1;
        forever #4.5 ctrl_ref_clk_src_3 = ~ctrl_ref_clk_src_3;
    end
    assign ctrl_ref_clk[3] = ctrl_ref_clk_src_3;

    logic rx_clk_src_0 = 1'b0;
    initial begin
        #0.3;
        forever #2.5 rx_clk_src_0 = ~rx_clk_src_0;
    end
    assign rx_clk[0] = rx_clk_src_0;
    logic rx_clk_src_1 = 1'b0;
    initial begin
        #1.2;
        forever #3.5 rx_clk_src_1 = ~rx_clk_src_1;
    end
    assign rx_clk[1] = rx_clk_src_1;
    logic rx_clk_src_2 = 1'b0;
    initial begin
        #2.1;
        forever #4.5 rx_clk_src_2 = ~rx_clk_src_2;
    end
    assign rx_clk[2] = rx_clk_src_2;
    logic rx_clk_src_3 = 1'b0;
    initial begin
        #3;
        forever #5.5 rx_clk_src_3 = ~rx_clk_src_3;
    end
    assign rx_clk[3] = rx_clk_src_3;
    logic rx_clk_src_4 = 1'b0;
    initial begin
        #3.9;
        forever #6.5 rx_clk_src_4 = ~rx_clk_src_4;
    end
    assign rx_clk[4] = rx_clk_src_4;
    logic rx_clk_src_5 = 1'b0;
    initial begin
        #4.8;
        forever #7.5 rx_clk_src_5 = ~rx_clk_src_5;
    end
    assign rx_clk[5] = rx_clk_src_5;
    logic rx_clk_src_6 = 1'b0;
    initial begin
        #5.7;
        forever #8.5 rx_clk_src_6 = ~rx_clk_src_6;
    end
    assign rx_clk[6] = rx_clk_src_6;
    logic rx_clk_src_7 = 1'b0;
    initial begin
        #6.6;
        forever #2.5 rx_clk_src_7 = ~rx_clk_src_7;
    end
    assign rx_clk[7] = rx_clk_src_7;
    logic rx_clk_src_8 = 1'b0;
    initial begin
        #7.5;
        forever #3.5 rx_clk_src_8 = ~rx_clk_src_8;
    end
    assign rx_clk[8] = rx_clk_src_8;
    logic rx_clk_src_9 = 1'b0;
    initial begin
        #8.4;
        forever #4.5 rx_clk_src_9 = ~rx_clk_src_9;
    end
    assign rx_clk[9] = rx_clk_src_9;
    logic rx_clk_src_10 = 1'b0;
    initial begin
        #9.3;
        forever #5.5 rx_clk_src_10 = ~rx_clk_src_10;
    end
    assign rx_clk[10] = rx_clk_src_10;
    logic rx_clk_src_11 = 1'b0;
    initial begin
        #10.2;
        forever #6.5 rx_clk_src_11 = ~rx_clk_src_11;
    end
    assign rx_clk[11] = rx_clk_src_11;

    logic [11:0] ctrla_pclk;
    logic [11:0] ctrla_rx_clk;
    assign ctrla_pclk = {12{ctrl_ref_clk[0]}};  // no division modeled -- every ctrl lane gets the same undivided clock
    logic [5:0] ctrlb_pclk;
    logic [5:0] ctrlb_rx_clk;
    assign ctrlb_pclk = {6{ctrl_ref_clk[1]}};  // no division modeled -- every ctrl lane gets the same undivided clock
    logic [7:0] ctrlc_pclk;
    logic [7:0] ctrlc_rx_clk;
    assign ctrlc_pclk = {8{ctrl_ref_clk[2]}};  // no division modeled -- every ctrl lane gets the same undivided clock
    logic [2:0] ctrld_pclk;
    logic [2:0] ctrld_rx_clk;
    assign ctrld_pclk = {3{ctrl_ref_clk[3]}};  // no division modeled -- every ctrl lane gets the same undivided clock

    //------------------------------------------------------------ DUT IO
    logic [NL-1:0]      phy_phystatus_stim = '0;
    logic [NC-1:0]        ctrl_rst_n = '0;
    logic [NC-1:0]        ctrl_perst_n = '0;
    logic [1:0] mode = '0;

    logic [NL-1:0]      phy_pclk;
    logic [NL-1:0]      phy_rst_n;
    logic [NL-1:0]      phy_perst_n;

    mac2phy_lane_t [NL-1:0] phy_mac2phy;
    phy2mac_lane_t [NL-1:0] phy_phy2mac;

    mac2phy_lane_t [11:0] ctrla_mac2phy;
    phy2mac_lane_t [11:0] ctrla_phy2mac;
    mac2phy_lane_t [5:0] ctrlb_mac2phy;
    phy2mac_lane_t [5:0] ctrlb_phy2mac;
    mac2phy_lane_t [7:0] ctrlc_mac2phy;
    phy2mac_lane_t [7:0] ctrlc_phy2mac;
    mac2phy_lane_t [2:0] ctrld_mac2phy;
    phy2mac_lane_t [2:0] ctrld_phy2mac;

    pipe_lane_mapper #(
        .NL (NL),
        .NC (NC)
    ) dut (
        .mode           (mode),
        .rx_clk         (rx_clk),
        .phy_pclk       (phy_pclk),
        .phy_rst_n      (phy_rst_n),
        .phy_perst_n    (phy_perst_n),
        .phy_mac2phy    (phy_mac2phy),
        .phy_phy2mac    (phy_phy2mac),
        .ctrla_rst_n   (ctrl_rst_n[0]),
        .ctrla_perst_n (ctrl_perst_n[0]),
        .ctrla_mac2phy (ctrla_mac2phy),
        .ctrla_phy2mac (ctrla_phy2mac),
        .ctrla_pclk    (ctrla_pclk),
        .ctrla_rx_clk  (ctrla_rx_clk),
        .ctrlb_rst_n   (ctrl_rst_n[1]),
        .ctrlb_perst_n (ctrl_perst_n[1]),
        .ctrlb_mac2phy (ctrlb_mac2phy),
        .ctrlb_phy2mac (ctrlb_phy2mac),
        .ctrlb_pclk    (ctrlb_pclk),
        .ctrlb_rx_clk  (ctrlb_rx_clk),
        .ctrlc_rst_n   (ctrl_rst_n[2]),
        .ctrlc_perst_n (ctrl_perst_n[2]),
        .ctrlc_mac2phy (ctrlc_mac2phy),
        .ctrlc_phy2mac (ctrlc_phy2mac),
        .ctrlc_pclk    (ctrlc_pclk),
        .ctrlc_rx_clk  (ctrlc_rx_clk),
        .ctrld_rst_n   (ctrl_rst_n[3]),
        .ctrld_perst_n (ctrl_perst_n[3]),
        .ctrld_mac2phy (ctrld_mac2phy),
        .ctrld_phy2mac (ctrld_phy2mac),
        .ctrld_pclk    (ctrld_pclk),
        .ctrld_rx_clk  (ctrld_rx_clk)
    );

    //------------------------------------------------------------ stimulus patterns
    function automatic mac2phy_lane_t make_m2p(input int cid, input int ctrl_lane);
        mac2phy_lane_t v;
        v = SAFE_M2P;
        v.mac_phy_txdata      = {4'(cid), 20'h0, 8'(ctrl_lane)};
        v.mac_phy_txdatak     = 4'(ctrl_lane);
        v.mac_phy_txdatavalid = 1'b1;
        v.mac_phy_txelecidle  = 1'b0;   // non-idle (may differ from the signal's safe state)
        v.mac_phy_rxstandby   = 1'b0;   // non-idle (may differ from the signal's safe state)
        return v;
    endfunction

    function automatic phy2mac_lane_t make_p2m(input int lane);
        phy2mac_lane_t v;
        v = SAFE_P2M;
        v.phy_mac_rxdata      = {8'hA5, 16'h0, 8'(lane)};
        v.phy_mac_rxdatak     = 4'(lane);
        v.phy_mac_rxdatavalid = 1'b1;
        v.phy_mac_rxelecidle      = 1'b0;  // non-idle (may differ from the signal's safe state)
        v.phy_mac_rxstandbystatus = 1'b0;  // non-idle (may differ from the signal's safe state)
        return v;
    endfunction

    always_comb begin
        for (int p = 0; p < 12; p++) ctrla_mac2phy[p] = make_m2p(0, p);
        for (int p = 0; p < 6; p++) ctrlb_mac2phy[p] = make_m2p(1, p);
        for (int p = 0; p < 8; p++) ctrlc_mac2phy[p] = make_m2p(2, p);
        for (int p = 0; p < 3; p++) ctrld_mac2phy[p] = make_m2p(3, p);
        for (int lane_idx = 0; lane_idx < NL; lane_idx++) begin
            phy_phy2mac[lane_idx] = make_p2m(lane_idx);
            phy_phy2mac[lane_idx].phy_mac_phystatus = phy_phystatus_stim[lane_idx];
        end
    end

    //------------------------------------------------------------ expected mapping (from lane_mapping.csv)
    function automatic int owner_of(input int m, input int lane_idx);
        case (m)
            0: case (lane_idx)
                0: return 0;
                1: return 0;
                2: return 0;
                3: return 0;
                4: return 0;
                5: return 0;
                6: return 0;
                7: return 0;
                8: return 0;
                9: return 0;
                10: return 0;
                11: return 0;
                default: return -1;
            endcase
            1: case (lane_idx)
                0: return 0;
                1: return 0;
                2: return 0;
                3: return 1;
                4: return 1;
                5: return 1;
                6: return 0;
                7: return 0;
                8: return 0;
                9: return 1;
                10: return 1;
                11: return 1;
                default: return -1;
            endcase
            2: case (lane_idx)
                0: return 0;
                1: return 0;
                2: return 0;
                3: return 0;
                4: return 0;
                5: return 0;
                6: return 2;
                7: return 2;
                8: return 2;
                9: return 2;
                10: return 2;
                11: return 2;
                default: return -1;
            endcase
            3: case (lane_idx)
                0: return 0;
                1: return 0;
                2: return 0;
                3: return 1;
                4: return 1;
                5: return 1;
                6: return 2;
                7: return 2;
                8: return 2;
                9: return 3;
                10: return 3;
                11: return 3;
                default: return -1;
            endcase
            default: return -1;
        endcase
    endfunction

    function automatic int ctrl_lane_of(input int m, input int lane_idx);
        case (m)
            0: case (lane_idx)
                0: return 0;
                1: return 1;
                2: return 2;
                3: return 3;
                4: return 4;
                5: return 5;
                6: return 6;
                7: return 7;
                8: return 8;
                9: return 9;
                10: return 10;
                11: return 11;
                default: return -1;
            endcase
            1: case (lane_idx)
                0: return 0;
                1: return 1;
                2: return 2;
                3: return 0;
                4: return 1;
                5: return 2;
                6: return 6;
                7: return 7;
                8: return 8;
                9: return 3;
                10: return 4;
                11: return 5;
                default: return -1;
            endcase
            2: case (lane_idx)
                0: return 0;
                1: return 1;
                2: return 2;
                3: return 3;
                4: return 4;
                5: return 5;
                6: return 0;
                7: return 1;
                8: return 2;
                9: return 3;
                10: return 4;
                11: return 5;
                default: return -1;
            endcase
            3: case (lane_idx)
                0: return 0;
                1: return 1;
                2: return 2;
                3: return 0;
                4: return 1;
                5: return 2;
                6: return 0;
                7: return 1;
                8: return 2;
                9: return 0;
                10: return 1;
                11: return 2;
                default: return -1;
            endcase
            default: return -1;
        endcase
    endfunction

    //------------------------------------------------------------ NOV one-hot / safe-state monitor
    int unsigned err_count = 0;
    int unsigned err_clock = 0, err_reset = 0, err_perst = 0, err_m2p = 0, err_p2m = 0, err_tie_off = 0, err_safe_state = 0;

    task automatic chk(input bit ok, input string msg);
        if (!ok) begin
            err_count++;
            $error("%0t: %s", $time, msg);
        end
    endtask

    task automatic chk_m2p(input mac2phy_lane_t got, input mac2phy_lane_t exp, input string ctx);
        chk(got.mac_phy_txdata == exp.mac_phy_txdata,
            $sformatf("%s: mac_phy_txdata mismatch, got=%0h expected=%0h", ctx, got.mac_phy_txdata, exp.mac_phy_txdata));
        chk(got.mac_phy_txdatak == exp.mac_phy_txdatak,
            $sformatf("%s: mac_phy_txdatak mismatch, got=%0h expected=%0h", ctx, got.mac_phy_txdatak, exp.mac_phy_txdatak));
        chk(got.mac_phy_txdatavalid == exp.mac_phy_txdatavalid,
            $sformatf("%s: mac_phy_txdatavalid mismatch, got=%0h expected=%0h", ctx, got.mac_phy_txdatavalid, exp.mac_phy_txdatavalid));
        chk(got.mac_phy_txstartblock == exp.mac_phy_txstartblock,
            $sformatf("%s: mac_phy_txstartblock mismatch, got=%0h expected=%0h", ctx, got.mac_phy_txstartblock, exp.mac_phy_txstartblock));
        chk(got.mac_phy_txsyncheader == exp.mac_phy_txsyncheader,
            $sformatf("%s: mac_phy_txsyncheader mismatch, got=%0h expected=%0h", ctx, got.mac_phy_txsyncheader, exp.mac_phy_txsyncheader));
        chk(got.mac_phy_txdetectrx_loopback == exp.mac_phy_txdetectrx_loopback,
            $sformatf("%s: mac_phy_txdetectrx_loopback mismatch, got=%0h expected=%0h", ctx, got.mac_phy_txdetectrx_loopback, exp.mac_phy_txdetectrx_loopback));
        chk(got.mac_phy_txelecidle == exp.mac_phy_txelecidle,
            $sformatf("%s: mac_phy_txelecidle mismatch, got=%0h expected=%0h", ctx, got.mac_phy_txelecidle, exp.mac_phy_txelecidle));
        chk(got.mac_phy_txcompliance == exp.mac_phy_txcompliance,
            $sformatf("%s: mac_phy_txcompliance mismatch, got=%0h expected=%0h", ctx, got.mac_phy_txcompliance, exp.mac_phy_txcompliance));
        chk(got.mac_phy_txdeemph == exp.mac_phy_txdeemph,
            $sformatf("%s: mac_phy_txdeemph mismatch, got=%0h expected=%0h", ctx, got.mac_phy_txdeemph, exp.mac_phy_txdeemph));
        chk(got.mac_phy_rxpolarity == exp.mac_phy_rxpolarity,
            $sformatf("%s: mac_phy_rxpolarity mismatch, got=%0h expected=%0h", ctx, got.mac_phy_rxpolarity, exp.mac_phy_rxpolarity));
        chk(got.mac_phy_rxstandby == exp.mac_phy_rxstandby,
            $sformatf("%s: mac_phy_rxstandby mismatch, got=%0h expected=%0h", ctx, got.mac_phy_rxstandby, exp.mac_phy_rxstandby));
        chk(got.mac_phy_messagebus == exp.mac_phy_messagebus,
            $sformatf("%s: mac_phy_messagebus mismatch, got=%0h expected=%0h", ctx, got.mac_phy_messagebus, exp.mac_phy_messagebus));
        chk(got.mac_phy_rxpresethint == exp.mac_phy_rxpresethint,
            $sformatf("%s: mac_phy_rxpresethint mismatch, got=%0h expected=%0h", ctx, got.mac_phy_rxpresethint, exp.mac_phy_rxpresethint));
        chk(got.mac_phy_local_pset_index == exp.mac_phy_local_pset_index,
            $sformatf("%s: mac_phy_local_pset_index mismatch, got=%0h expected=%0h", ctx, got.mac_phy_local_pset_index, exp.mac_phy_local_pset_index));
        chk(got.mac_phy_getlocal_pset_coef == exp.mac_phy_getlocal_pset_coef,
            $sformatf("%s: mac_phy_getlocal_pset_coef mismatch, got=%0h expected=%0h", ctx, got.mac_phy_getlocal_pset_coef, exp.mac_phy_getlocal_pset_coef));
        chk(got.mac_phy_invalid_req == exp.mac_phy_invalid_req,
            $sformatf("%s: mac_phy_invalid_req mismatch, got=%0h expected=%0h", ctx, got.mac_phy_invalid_req, exp.mac_phy_invalid_req));
        chk(got.mac_phy_rxeqeval == exp.mac_phy_rxeqeval,
            $sformatf("%s: mac_phy_rxeqeval mismatch, got=%0h expected=%0h", ctx, got.mac_phy_rxeqeval, exp.mac_phy_rxeqeval));
        chk(got.mac_phy_fs == exp.mac_phy_fs,
            $sformatf("%s: mac_phy_fs mismatch, got=%0h expected=%0h", ctx, got.mac_phy_fs, exp.mac_phy_fs));
        chk(got.mac_phy_lf == exp.mac_phy_lf,
            $sformatf("%s: mac_phy_lf mismatch, got=%0h expected=%0h", ctx, got.mac_phy_lf, exp.mac_phy_lf));
        chk(got.mac_phy_dirchange == exp.mac_phy_dirchange,
            $sformatf("%s: mac_phy_dirchange mismatch, got=%0h expected=%0h", ctx, got.mac_phy_dirchange, exp.mac_phy_dirchange));
        chk(got.mac_phy_rxeqinprogress == exp.mac_phy_rxeqinprogress,
            $sformatf("%s: mac_phy_rxeqinprogress mismatch, got=%0h expected=%0h", ctx, got.mac_phy_rxeqinprogress, exp.mac_phy_rxeqinprogress));
    endtask

    task automatic chk_p2m(input phy2mac_lane_t got, input phy2mac_lane_t exp, input string ctx);
        chk(got.phy_mac_rxdata == exp.phy_mac_rxdata,
            $sformatf("%s: phy_mac_rxdata mismatch, got=%0h expected=%0h", ctx, got.phy_mac_rxdata, exp.phy_mac_rxdata));
        chk(got.phy_mac_rxdatak == exp.phy_mac_rxdatak,
            $sformatf("%s: phy_mac_rxdatak mismatch, got=%0h expected=%0h", ctx, got.phy_mac_rxdatak, exp.phy_mac_rxdatak));
        chk(got.phy_mac_rxdatavalid == exp.phy_mac_rxdatavalid,
            $sformatf("%s: phy_mac_rxdatavalid mismatch, got=%0h expected=%0h", ctx, got.phy_mac_rxdatavalid, exp.phy_mac_rxdatavalid));
        chk(got.phy_mac_rxstartblock == exp.phy_mac_rxstartblock,
            $sformatf("%s: phy_mac_rxstartblock mismatch, got=%0h expected=%0h", ctx, got.phy_mac_rxstartblock, exp.phy_mac_rxstartblock));
        chk(got.phy_mac_rxsyncheader == exp.phy_mac_rxsyncheader,
            $sformatf("%s: phy_mac_rxsyncheader mismatch, got=%0h expected=%0h", ctx, got.phy_mac_rxsyncheader, exp.phy_mac_rxsyncheader));
        chk(got.phy_mac_rxvalid == exp.phy_mac_rxvalid,
            $sformatf("%s: phy_mac_rxvalid mismatch, got=%0h expected=%0h", ctx, got.phy_mac_rxvalid, exp.phy_mac_rxvalid));
        chk(got.phy_mac_rxstatus == exp.phy_mac_rxstatus,
            $sformatf("%s: phy_mac_rxstatus mismatch, got=%0h expected=%0h", ctx, got.phy_mac_rxstatus, exp.phy_mac_rxstatus));
        chk(got.phy_mac_rxelecidle == exp.phy_mac_rxelecidle,
            $sformatf("%s: phy_mac_rxelecidle mismatch, got=%0h expected=%0h", ctx, got.phy_mac_rxelecidle, exp.phy_mac_rxelecidle));
        chk(got.phy_mac_rxstandbystatus == exp.phy_mac_rxstandbystatus,
            $sformatf("%s: phy_mac_rxstandbystatus mismatch, got=%0h expected=%0h", ctx, got.phy_mac_rxstandbystatus, exp.phy_mac_rxstandbystatus));
        chk(got.phy_mac_messagebus == exp.phy_mac_messagebus,
            $sformatf("%s: phy_mac_messagebus mismatch, got=%0h expected=%0h", ctx, got.phy_mac_messagebus, exp.phy_mac_messagebus));
        chk(got.phy_mac_phystatus == exp.phy_mac_phystatus,
            $sformatf("%s: phy_mac_phystatus mismatch, got=%0h expected=%0h", ctx, got.phy_mac_phystatus, exp.phy_mac_phystatus));
        chk(got.phy_mac_local_tx_coef_valid == exp.phy_mac_local_tx_coef_valid,
            $sformatf("%s: phy_mac_local_tx_coef_valid mismatch, got=%0h expected=%0h", ctx, got.phy_mac_local_tx_coef_valid, exp.phy_mac_local_tx_coef_valid));
        chk(got.phy_mac_local_tx_pset_coef == exp.phy_mac_local_tx_pset_coef,
            $sformatf("%s: phy_mac_local_tx_pset_coef mismatch, got=%0h expected=%0h", ctx, got.phy_mac_local_tx_pset_coef, exp.phy_mac_local_tx_pset_coef));
        chk(got.phy_mac_localfs == exp.phy_mac_localfs,
            $sformatf("%s: phy_mac_localfs mismatch, got=%0h expected=%0h", ctx, got.phy_mac_localfs, exp.phy_mac_localfs));
        chk(got.phy_mac_locallf == exp.phy_mac_locallf,
            $sformatf("%s: phy_mac_locallf mismatch, got=%0h expected=%0h", ctx, got.phy_mac_locallf, exp.phy_mac_locallf));
        chk(got.phy_mac_dirfeedback == exp.phy_mac_dirfeedback,
            $sformatf("%s: phy_mac_dirfeedback mismatch, got=%0h expected=%0h", ctx, got.phy_mac_dirfeedback, exp.phy_mac_dirfeedback));
        chk(got.phy_mac_fomfeedback == exp.phy_mac_fomfeedback,
            $sformatf("%s: phy_mac_fomfeedback mismatch, got=%0h expected=%0h", ctx, got.phy_mac_fomfeedback, exp.phy_mac_fomfeedback));
    endtask

    localparam int G1_LANES[3] = '{3, 4, 5};
    localparam int G2_LANES[3] = '{6, 7, 8};
    localparam int G3_LANES[3] = '{9, 10, 11};

    phy2mac_lane_t exp_safe_p2m;
    assign exp_safe_p2m = '{
        phy_mac_rxelecidle: 1'b1,
        phy_mac_rxstandbystatus: 1'b1,
        phy_mac_messagebus: 8'h50,
        default: '0
    };

    //------------------------------------------------------------
    // NOV monitor: one per BBM lane (each lane's seltgt is its own
    // independent sync result, not shared across the group).
    //------------------------------------------------------------
    always @(dut.seltgt_g1_l3) begin
        if ($time == 0) begin
            // skip: DUT hasn't come out of its startup X state yet
        end else begin
            logic [1:0] sel_snap;
            int unsigned err_before;
            sel_snap = dut.seltgt_g1_l3;
            #1;
            err_before = err_count;
            chk($onehot0(sel_snap), "seltgt_g1_l3 not one-hot0 (>1 branch enabled)");

            if (sel_snap == '0 && dut.seltgt_g1_l3 == '0) begin
                chk_m2p(phy_mac2phy[3], SAFE_M2P,
                    "G1 lane3: sel==0 NOV gap");
                if (dut.seltgt_g1_l3 == '0) begin
                    chk_p2m(ctrla_phy2mac[3], exp_safe_p2m,
                        "G1 CtrlA[3]: not owner");
                    chk_p2m(ctrlb_phy2mac[0], exp_safe_p2m,
                        "G1 CtrlB[0]: not owner");
                end
            end
            err_safe_state += (err_count - err_before);
        end
    end

    always @(dut.seltgt_g1_l4) begin
        if ($time == 0) begin
            // skip: DUT hasn't come out of its startup X state yet
        end else begin
            logic [1:0] sel_snap;
            int unsigned err_before;
            sel_snap = dut.seltgt_g1_l4;
            #1;
            err_before = err_count;
            chk($onehot0(sel_snap), "seltgt_g1_l4 not one-hot0 (>1 branch enabled)");

            if (sel_snap == '0 && dut.seltgt_g1_l4 == '0) begin
                chk_m2p(phy_mac2phy[4], SAFE_M2P,
                    "G1 lane4: sel==0 NOV gap");
                if (dut.seltgt_g1_l4 == '0) begin
                    chk_p2m(ctrla_phy2mac[4], exp_safe_p2m,
                        "G1 CtrlA[4]: not owner");
                    chk_p2m(ctrlb_phy2mac[1], exp_safe_p2m,
                        "G1 CtrlB[1]: not owner");
                end
            end
            err_safe_state += (err_count - err_before);
        end
    end

    always @(dut.seltgt_g1_l5) begin
        if ($time == 0) begin
            // skip: DUT hasn't come out of its startup X state yet
        end else begin
            logic [1:0] sel_snap;
            int unsigned err_before;
            sel_snap = dut.seltgt_g1_l5;
            #1;
            err_before = err_count;
            chk($onehot0(sel_snap), "seltgt_g1_l5 not one-hot0 (>1 branch enabled)");

            if (sel_snap == '0 && dut.seltgt_g1_l5 == '0) begin
                chk_m2p(phy_mac2phy[5], SAFE_M2P,
                    "G1 lane5: sel==0 NOV gap");
                if (dut.seltgt_g1_l5 == '0) begin
                    chk_p2m(ctrla_phy2mac[5], exp_safe_p2m,
                        "G1 CtrlA[5]: not owner");
                    chk_p2m(ctrlb_phy2mac[2], exp_safe_p2m,
                        "G1 CtrlB[2]: not owner");
                end
            end
            err_safe_state += (err_count - err_before);
        end
    end

    always @(dut.seltgt_g2_l6) begin
        if ($time == 0) begin
            // skip: DUT hasn't come out of its startup X state yet
        end else begin
            logic [1:0] sel_snap;
            int unsigned err_before;
            sel_snap = dut.seltgt_g2_l6;
            #1;
            err_before = err_count;
            chk($onehot0(sel_snap), "seltgt_g2_l6 not one-hot0 (>1 branch enabled)");

            if (sel_snap == '0 && dut.seltgt_g2_l6 == '0) begin
                chk_m2p(phy_mac2phy[6], SAFE_M2P,
                    "G2 lane6: sel==0 NOV gap");
                if (dut.seltgt_g2_l6 == '0) begin
                    chk_p2m(ctrla_phy2mac[6], exp_safe_p2m,
                        "G2 CtrlA[6]: not owner");
                    chk_p2m(ctrlc_phy2mac[0], exp_safe_p2m,
                        "G2 CtrlC[0]: not owner");
                end
            end
            err_safe_state += (err_count - err_before);
        end
    end

    always @(dut.seltgt_g2_l7) begin
        if ($time == 0) begin
            // skip: DUT hasn't come out of its startup X state yet
        end else begin
            logic [1:0] sel_snap;
            int unsigned err_before;
            sel_snap = dut.seltgt_g2_l7;
            #1;
            err_before = err_count;
            chk($onehot0(sel_snap), "seltgt_g2_l7 not one-hot0 (>1 branch enabled)");

            if (sel_snap == '0 && dut.seltgt_g2_l7 == '0) begin
                chk_m2p(phy_mac2phy[7], SAFE_M2P,
                    "G2 lane7: sel==0 NOV gap");
                if (dut.seltgt_g2_l7 == '0) begin
                    chk_p2m(ctrla_phy2mac[7], exp_safe_p2m,
                        "G2 CtrlA[7]: not owner");
                    chk_p2m(ctrlc_phy2mac[1], exp_safe_p2m,
                        "G2 CtrlC[1]: not owner");
                end
            end
            err_safe_state += (err_count - err_before);
        end
    end

    always @(dut.seltgt_g2_l8) begin
        if ($time == 0) begin
            // skip: DUT hasn't come out of its startup X state yet
        end else begin
            logic [1:0] sel_snap;
            int unsigned err_before;
            sel_snap = dut.seltgt_g2_l8;
            #1;
            err_before = err_count;
            chk($onehot0(sel_snap), "seltgt_g2_l8 not one-hot0 (>1 branch enabled)");

            if (sel_snap == '0 && dut.seltgt_g2_l8 == '0) begin
                chk_m2p(phy_mac2phy[8], SAFE_M2P,
                    "G2 lane8: sel==0 NOV gap");
                if (dut.seltgt_g2_l8 == '0) begin
                    chk_p2m(ctrla_phy2mac[8], exp_safe_p2m,
                        "G2 CtrlA[8]: not owner");
                    chk_p2m(ctrlc_phy2mac[2], exp_safe_p2m,
                        "G2 CtrlC[2]: not owner");
                end
            end
            err_safe_state += (err_count - err_before);
        end
    end

    always @(dut.seltgt_g3_l9) begin
        if ($time == 0) begin
            // skip: DUT hasn't come out of its startup X state yet
        end else begin
            logic [3:0] sel_snap;
            int unsigned err_before;
            sel_snap = dut.seltgt_g3_l9;
            #1;
            err_before = err_count;
            chk($onehot0(sel_snap), "seltgt_g3_l9 not one-hot0 (>1 branch enabled)");

            if (sel_snap == '0 && dut.seltgt_g3_l9 == '0) begin
                chk_m2p(phy_mac2phy[9], SAFE_M2P,
                    "G3 lane9: sel==0 NOV gap");
                if (dut.seltgt_g3_l9 == '0) begin
                    chk_p2m(ctrla_phy2mac[9], exp_safe_p2m,
                        "G3 CtrlA[9]: not owner");
                    chk_p2m(ctrlb_phy2mac[3], exp_safe_p2m,
                        "G3 CtrlB[3]: not owner");
                    chk_p2m(ctrlc_phy2mac[3], exp_safe_p2m,
                        "G3 CtrlC[3]: not owner");
                    chk_p2m(ctrld_phy2mac[0], exp_safe_p2m,
                        "G3 CtrlD[0]: not owner");
                end
            end
            err_safe_state += (err_count - err_before);
        end
    end

    always @(dut.seltgt_g3_l10) begin
        if ($time == 0) begin
            // skip: DUT hasn't come out of its startup X state yet
        end else begin
            logic [3:0] sel_snap;
            int unsigned err_before;
            sel_snap = dut.seltgt_g3_l10;
            #1;
            err_before = err_count;
            chk($onehot0(sel_snap), "seltgt_g3_l10 not one-hot0 (>1 branch enabled)");

            if (sel_snap == '0 && dut.seltgt_g3_l10 == '0) begin
                chk_m2p(phy_mac2phy[10], SAFE_M2P,
                    "G3 lane10: sel==0 NOV gap");
                if (dut.seltgt_g3_l10 == '0) begin
                    chk_p2m(ctrla_phy2mac[10], exp_safe_p2m,
                        "G3 CtrlA[10]: not owner");
                    chk_p2m(ctrlb_phy2mac[4], exp_safe_p2m,
                        "G3 CtrlB[4]: not owner");
                    chk_p2m(ctrlc_phy2mac[4], exp_safe_p2m,
                        "G3 CtrlC[4]: not owner");
                    chk_p2m(ctrld_phy2mac[1], exp_safe_p2m,
                        "G3 CtrlD[1]: not owner");
                end
            end
            err_safe_state += (err_count - err_before);
        end
    end

    always @(dut.seltgt_g3_l11) begin
        if ($time == 0) begin
            // skip: DUT hasn't come out of its startup X state yet
        end else begin
            logic [3:0] sel_snap;
            int unsigned err_before;
            sel_snap = dut.seltgt_g3_l11;
            #1;
            err_before = err_count;
            chk($onehot0(sel_snap), "seltgt_g3_l11 not one-hot0 (>1 branch enabled)");

            if (sel_snap == '0 && dut.seltgt_g3_l11 == '0) begin
                chk_m2p(phy_mac2phy[11], SAFE_M2P,
                    "G3 lane11: sel==0 NOV gap");
                if (dut.seltgt_g3_l11 == '0) begin
                    chk_p2m(ctrla_phy2mac[11], exp_safe_p2m,
                        "G3 CtrlA[11]: not owner");
                    chk_p2m(ctrlb_phy2mac[5], exp_safe_p2m,
                        "G3 CtrlB[5]: not owner");
                    chk_p2m(ctrlc_phy2mac[5], exp_safe_p2m,
                        "G3 CtrlC[5]: not owner");
                    chk_p2m(ctrld_phy2mac[2], exp_safe_p2m,
                        "G3 CtrlD[2]: not owner");
                end
            end
            err_safe_state += (err_count - err_before);
        end
    end



    //------------------------------------------------------------ steady-state data-routing check
    task automatic check_mode(input int m);
        mac2phy_lane_t exp_m2p;
        phy2mac_lane_t exp_p2m;
        int cid, ctrl_lane;
        int unsigned err_before;

        for (int lane_idx = 0; lane_idx < NL; lane_idx++) begin
            cid  = owner_of(m, lane_idx);
            ctrl_lane = ctrl_lane_of(m, lane_idx);
            exp_m2p = make_m2p(cid, ctrl_lane);
            err_before = err_count;
            chk_m2p(phy_mac2phy[lane_idx], exp_m2p,
                $sformatf("mode%0d lane%0d: expected ctrl%0d lane%0d", m, lane_idx, cid, ctrl_lane));
            err_m2p += (err_count - err_before);

            err_before = err_count;
            chk(phy_rst_n[lane_idx] == ctrl_rst_n[cid],
                $sformatf("mode%0d lane%0d: phy_rst_n=%0b does not follow owner ctrl%0d",
                          m, lane_idx, phy_rst_n[lane_idx], cid));
            err_reset += (err_count - err_before);
            err_before = err_count;
            chk(phy_perst_n[lane_idx] == ctrl_perst_n[cid],
                $sformatf("mode%0d lane%0d: perst_n does not follow owner ctrl%0d", m, lane_idx, cid));
            err_perst += (err_count - err_before);

            begin
                time t0;
                real got_ns, exp_ns;
                int unsigned err_before;
                exp_ns = CTRL_PERIOD_NS[cid];
                @(posedge phy_pclk[lane_idx]); t0 = $time;
                @(posedge phy_pclk[lane_idx]); got_ns = $time - t0;
                err_before = err_count;
                chk((got_ns > exp_ns * 0.8) && (got_ns < exp_ns * 1.2),
                    $sformatf("%s: measured period %0.2fns, expected ~%0.2fns", $sformatf("mode%0d lane%0d phy_pclk", m, lane_idx), got_ns, exp_ns));
                err_clock += (err_count - err_before);
            end
        end

        for (int lane_idx = 0; lane_idx < NL; lane_idx++) begin
            int cid, ctrl_lane;
            cid  = owner_of(m, lane_idx);
            ctrl_lane = ctrl_lane_of(m, lane_idx);
            case (cid)
                0: begin
                    begin
                        time t0;
                        real got_ns, exp_ns;
                        int unsigned err_before;
                        exp_ns = LANE_PERIOD_NS[lane_idx];
                        @(posedge ctrla_rx_clk[ctrl_lane]); t0 = $time;
                        @(posedge ctrla_rx_clk[ctrl_lane]); got_ns = $time - t0;
                        err_before = err_count;
                        chk((got_ns > exp_ns * 0.8) && (got_ns < exp_ns * 1.2),
                            $sformatf("%s: measured period %0.2fns, expected ~%0.2fns", $sformatf("mode%0d ctrla_rx_clk[%0d]", m, ctrl_lane), got_ns, exp_ns));
                        err_clock += (err_count - err_before);
                    end
                end
                1: begin
                    begin
                        time t0;
                        real got_ns, exp_ns;
                        int unsigned err_before;
                        exp_ns = LANE_PERIOD_NS[lane_idx];
                        @(posedge ctrlb_rx_clk[ctrl_lane]); t0 = $time;
                        @(posedge ctrlb_rx_clk[ctrl_lane]); got_ns = $time - t0;
                        err_before = err_count;
                        chk((got_ns > exp_ns * 0.8) && (got_ns < exp_ns * 1.2),
                            $sformatf("%s: measured period %0.2fns, expected ~%0.2fns", $sformatf("mode%0d ctrlb_rx_clk[%0d]", m, ctrl_lane), got_ns, exp_ns));
                        err_clock += (err_count - err_before);
                    end
                end
                2: begin
                    begin
                        time t0;
                        real got_ns, exp_ns;
                        int unsigned err_before;
                        exp_ns = LANE_PERIOD_NS[lane_idx];
                        @(posedge ctrlc_rx_clk[ctrl_lane]); t0 = $time;
                        @(posedge ctrlc_rx_clk[ctrl_lane]); got_ns = $time - t0;
                        err_before = err_count;
                        chk((got_ns > exp_ns * 0.8) && (got_ns < exp_ns * 1.2),
                            $sformatf("%s: measured period %0.2fns, expected ~%0.2fns", $sformatf("mode%0d ctrlc_rx_clk[%0d]", m, ctrl_lane), got_ns, exp_ns));
                        err_clock += (err_count - err_before);
                    end
                end
                3: begin
                    begin
                        time t0;
                        real got_ns, exp_ns;
                        int unsigned err_before;
                        exp_ns = LANE_PERIOD_NS[lane_idx];
                        @(posedge ctrld_rx_clk[ctrl_lane]); t0 = $time;
                        @(posedge ctrld_rx_clk[ctrl_lane]); got_ns = $time - t0;
                        err_before = err_count;
                        chk((got_ns > exp_ns * 0.8) && (got_ns < exp_ns * 1.2),
                            $sformatf("%s: measured period %0.2fns, expected ~%0.2fns", $sformatf("mode%0d ctrld_rx_clk[%0d]", m, ctrl_lane), got_ns, exp_ns));
                        err_clock += (err_count - err_before);
                    end
                end
            endcase
        end

        for (int c = 0; c < NC; c++) begin
            int max_w;
            case (c)
                0: max_w = 12;
                1: max_w = 6;
                2: max_w = 8;
                3: max_w = 3;
                default: max_w = 0;
            endcase
            for (int p = 0; p < max_w; p++) begin
                int src_lane;
                phy2mac_lane_t got;
                src_lane = -1;
                for (int lane_idx = 0; lane_idx < NL; lane_idx++)
                    if (owner_of(m, lane_idx) == c && ctrl_lane_of(m, lane_idx) == p) src_lane = lane_idx;

                case (c)
                    0: got = ctrla_phy2mac[p];
                    1: got = ctrlb_phy2mac[p];
                    2: got = ctrlc_phy2mac[p];
                    3: got = ctrld_phy2mac[p];
                endcase

                if (src_lane == -1) begin
                    phy2mac_lane_t exp_tie;
                    int active_base;
                    exp_tie = SAFE_P2M;
                    active_base = -1;
                    for (int lane_idx = 0; lane_idx < NL; lane_idx++) begin
                        if (owner_of(m, lane_idx) == c && active_base == -1) active_base = lane_idx;
                    end
                    if (active_base != -1) begin
                        exp_tie.phy_mac_rxdata = 32'h00000000;
                        exp_tie.phy_mac_rxdatak = 4'h0;
                        exp_tie.phy_mac_rxdatavalid = 1'b0;
                        exp_tie.phy_mac_rxstartblock = 1'b0;
                        exp_tie.phy_mac_rxsyncheader = 2'h0;
                        exp_tie.phy_mac_rxvalid = 1'b0;
                        exp_tie.phy_mac_rxstatus = 3'h0;
                        exp_tie.phy_mac_rxelecidle = 1'b0;
                        exp_tie.phy_mac_rxstandbystatus = 1'b0;
                        exp_tie.phy_mac_messagebus = 8'h50;
                        exp_tie.phy_mac_phystatus = phy_phy2mac[active_base].phy_mac_phystatus;
                        exp_tie.phy_mac_local_tx_coef_valid = 1'b0;
                        exp_tie.phy_mac_local_tx_pset_coef = 18'h00000;
                        exp_tie.phy_mac_localfs = 6'h00;
                        exp_tie.phy_mac_locallf = 6'h00;
                        exp_tie.phy_mac_dirfeedback = 6'h00;
                        exp_tie.phy_mac_fomfeedback = 8'h00;
                    end else begin
                        exp_tie.phy_mac_rxdata = 32'h00000000;
                        exp_tie.phy_mac_rxdatak = 4'h0;
                        exp_tie.phy_mac_rxdatavalid = 1'b0;
                        exp_tie.phy_mac_rxstartblock = 1'b0;
                        exp_tie.phy_mac_rxsyncheader = 2'h0;
                        exp_tie.phy_mac_rxvalid = 1'b0;
                        exp_tie.phy_mac_rxstatus = 3'h0;
                        exp_tie.phy_mac_rxelecidle = 1'b0;
                        exp_tie.phy_mac_rxstandbystatus = 1'b0;
                        exp_tie.phy_mac_messagebus = 8'h50;
                        exp_tie.phy_mac_phystatus = '0;
                        exp_tie.phy_mac_local_tx_coef_valid = 1'b0;
                        exp_tie.phy_mac_local_tx_pset_coef = 18'h00000;
                        exp_tie.phy_mac_localfs = 6'h00;
                        exp_tie.phy_mac_locallf = 6'h00;
                        exp_tie.phy_mac_dirfeedback = 6'h00;
                        exp_tie.phy_mac_fomfeedback = 8'h00;
                    end
                    err_before = err_count;
                    chk_p2m(got, exp_tie,
                        $sformatf("mode%0d ctrl%0d[%0d]: unmapped tie-off", m, c, p));
                    err_tie_off += (err_count - err_before);
                end else begin
                    exp_p2m = make_p2m(src_lane);
                    exp_p2m.phy_mac_phystatus = phy_phystatus_stim[src_lane];
                    err_before = err_count;
                    chk_p2m(got, exp_p2m,
                        $sformatf("mode%0d ctrl%0d[%0d]: expected lane%0d data", m, c, p, src_lane));
                    err_p2m += (err_count - err_before);
                end
            end
        end

        $display("%0t: mode%0d checked (%0d cumulative errors)", $time, m, err_count);
    endtask

    task automatic check_perst(input int m);
        int unsigned err_before;
        err_before = err_count;
        for (int c = 0; c < NC; c++) begin
            ctrl_perst_n[c] = 1'b0; #1;
            for (int lane_idx = 0; lane_idx < NL; lane_idx++) begin
                chk(phy_perst_n[lane_idx] == (owner_of(m, lane_idx) == c ? 1'b0 : 1'b1),
                    $sformatf("mode%0d lane%0d: ctrl%0d perst_n pulse routing", m, lane_idx, c));
                chk(phy_rst_n[lane_idx] == ctrl_rst_n[owner_of(m, lane_idx)], "perst_n must not change rst_n");
            end
            ctrl_perst_n[c] = 1'b1; #1;
            chk(phy_perst_n == '1, "perst_n release must reach all owner lanes");
        end
        err_perst += (err_count - err_before);
    endtask

    //------------------------------------------------------------ sequencing
    localparam realtime SETTLE = 2000;

    initial begin
`ifdef DUMP_FSDB
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_pipe_lane_mapper, "+all");
`else
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_pipe_lane_mapper);
`endif

        ctrl_rst_n = '0;
        ctrl_perst_n = '0;
        mode = '0;
        #100;
        ctrl_rst_n = '1;
        ctrl_perst_n = '1;
        #SETTLE;

        check_mode(0);
        check_perst(0);
        // toggle physical lane 0's phystatus and dynamically verify it's followed correctly
        phy_phystatus_stim[0] = 1'b1; #20;
        check_mode(0);
        phy_phystatus_stim[0] = 1'b0; #20;
        check_mode(0);
        mode = 1; #SETTLE;
        check_mode(1);
        check_perst(1);
        // toggle physical lane 0's phystatus and dynamically verify it's followed correctly
        phy_phystatus_stim[0] = 1'b1; #20;
        check_mode(1);
        phy_phystatus_stim[0] = 1'b0; #20;
        check_mode(1);
        mode = 2; #SETTLE;
        check_mode(2);
        check_perst(2);
        // toggle physical lane 0's phystatus and dynamically verify it's followed correctly
        phy_phystatus_stim[0] = 1'b1; #20;
        check_mode(2);
        phy_phystatus_stim[0] = 1'b0; #20;
        check_mode(2);
        mode = 3; #SETTLE;
        check_mode(3);
        check_perst(3);
        // toggle physical lane 0's phystatus and dynamically verify it's followed correctly
        phy_phystatus_stim[0] = 1'b1; #20;
        check_mode(3);
        phy_phystatus_stim[0] = 1'b0; #20;
        check_mode(3);

        // non-adjacent jump
        mode = 0; #SETTLE; check_mode(0);
        mode = 3; #SETTLE; check_mode(3);

        // reset pulse checks in mode3
        // pulse each controller: its owner lanes' phy_rst_n should follow low, non-owner lanes stay high.
        ctrl_rst_n[0] = 1'b0; #SETTLE;
        begin
            int unsigned err_before;
            err_before = err_count;
            for (int lane_idx = 0; lane_idx < NL; lane_idx++) begin
                bit expect_low;
                expect_low = (owner_of(3, lane_idx) == 0);
                chk(phy_rst_n[lane_idx] == (expect_low ? 1'b0 : 1'b1),
                    $sformatf("mode3 lane%0d: ctrl_rst_n[0]=0 pulse, expected phy_rst_n=%0b", lane_idx, expect_low ? 1'b0 : 1'b1));
                chk(phy_perst_n[lane_idx] == ctrl_perst_n[owner_of(mode, lane_idx)], "rst_n must not change perst_n");
            end
            err_reset += (err_count - err_before);
        end
        $display("%0t: ctrl_rst_n[0] pulse checked (%0d cumulative errors)", $time, err_count);
        ctrl_rst_n[0] = 1'b1; #SETTLE;
        check_mode(3);
        ctrl_rst_n[1] = 1'b0; #SETTLE;
        begin
            int unsigned err_before;
            err_before = err_count;
            for (int lane_idx = 0; lane_idx < NL; lane_idx++) begin
                bit expect_low;
                expect_low = (owner_of(3, lane_idx) == 1);
                chk(phy_rst_n[lane_idx] == (expect_low ? 1'b0 : 1'b1),
                    $sformatf("mode3 lane%0d: ctrl_rst_n[1]=0 pulse, expected phy_rst_n=%0b", lane_idx, expect_low ? 1'b0 : 1'b1));
                chk(phy_perst_n[lane_idx] == ctrl_perst_n[owner_of(mode, lane_idx)], "rst_n must not change perst_n");
            end
            err_reset += (err_count - err_before);
        end
        $display("%0t: ctrl_rst_n[1] pulse checked (%0d cumulative errors)", $time, err_count);
        ctrl_rst_n[1] = 1'b1; #SETTLE;
        check_mode(3);
        ctrl_rst_n[2] = 1'b0; #SETTLE;
        begin
            int unsigned err_before;
            err_before = err_count;
            for (int lane_idx = 0; lane_idx < NL; lane_idx++) begin
                bit expect_low;
                expect_low = (owner_of(3, lane_idx) == 2);
                chk(phy_rst_n[lane_idx] == (expect_low ? 1'b0 : 1'b1),
                    $sformatf("mode3 lane%0d: ctrl_rst_n[2]=0 pulse, expected phy_rst_n=%0b", lane_idx, expect_low ? 1'b0 : 1'b1));
                chk(phy_perst_n[lane_idx] == ctrl_perst_n[owner_of(mode, lane_idx)], "rst_n must not change perst_n");
            end
            err_reset += (err_count - err_before);
        end
        $display("%0t: ctrl_rst_n[2] pulse checked (%0d cumulative errors)", $time, err_count);
        ctrl_rst_n[2] = 1'b1; #SETTLE;
        check_mode(3);
        ctrl_rst_n[3] = 1'b0; #SETTLE;
        begin
            int unsigned err_before;
            err_before = err_count;
            for (int lane_idx = 0; lane_idx < NL; lane_idx++) begin
                bit expect_low;
                expect_low = (owner_of(3, lane_idx) == 3);
                chk(phy_rst_n[lane_idx] == (expect_low ? 1'b0 : 1'b1),
                    $sformatf("mode3 lane%0d: ctrl_rst_n[3]=0 pulse, expected phy_rst_n=%0b", lane_idx, expect_low ? 1'b0 : 1'b1));
                chk(phy_perst_n[lane_idx] == ctrl_perst_n[owner_of(mode, lane_idx)], "rst_n must not change perst_n");
            end
            err_reset += (err_count - err_before);
        end
        $display("%0t: ctrl_rst_n[3] pulse checked (%0d cumulative errors)", $time, err_count);
        ctrl_rst_n[3] = 1'b1; #SETTLE;
        check_mode(3);

        $display("=== test case summary ===");
        $display("  clock     : %s (%0d errors)", err_clock == 0 ? "PASS" : "FAIL", err_clock);
        $display("  reset     : %s (%0d errors)", err_reset == 0 ? "PASS" : "FAIL", err_reset);
        $display("  perst     : %s (%0d errors)", err_perst == 0 ? "PASS" : "FAIL", err_perst);
        $display("  m2p       : %s (%0d errors)", err_m2p == 0 ? "PASS" : "FAIL", err_m2p);
        $display("  p2m       : %s (%0d errors)", err_p2m == 0 ? "PASS" : "FAIL", err_p2m);
        $display("  tie_off   : %s (%0d errors)", err_tie_off == 0 ? "PASS" : "FAIL", err_tie_off);
        $display("  safe_state: %s (%0d errors)", err_safe_state == 0 ? "PASS" : "FAIL", err_safe_state);
        if (err_count == 0) $display("TB_RESULT: PASS");
        else                 $display("TB_RESULT: FAIL (%0d errors)", err_count);
        $finish;
    end

    initial begin
        #94000;
        $error("TB_RESULT: FAIL (timeout, simulation did not finish)");
        $finish;
    end

endmodule
