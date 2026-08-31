`timescale 1ns/1ps
//=============================================================================
// tb_pipe_lane_mapper -- self-checking functional simulation, driven by this config set's lane_mapping.csv.
//
// Checks:
//   1. Steady-state data routing matches lane_mapping.csv exactly
//   2. Unmapped controller ports read back SAFE_P2M
//   3. Group sel vectors are always one-hot0 (break-before-make)
//   4. During the BBM handoff window (sel all-zero), phy lanes present the safe state (txelecidle=1)
//   5. phy_rst_n follows the current owner's ctrl_rst_n
//=============================================================================
import pipe_lane_signal_pkg::*;

module tb_pipe_lane_mapper;

    localparam int NM  = 4;
    localparam int NL = 16;
    localparam int NC   = 4;

    //------------------------------------------------------------ clocks
    // Different period + phase offset per lane, to exercise asynchronous CDC.
    localparam int unsigned PERIOD_NS [0:15] = '{
        3,
        5,
        7,
        9,
        11,
        13,
        15,
        3,
        5,
        7,
        9,
        11,
        13,
        15,
        3,
        5
    };

    logic [NL-1:0] phy_pclk_out;

    for (genvar l = 0; l < NL; l++) begin : g_clk
        initial begin
            phy_pclk_out[l] = 1'b0;
            #(l * 0.7);
            forever #(PERIOD_NS[l] / 2.0) phy_pclk_out[l] = ~phy_pclk_out[l];
        end
    end

    //------------------------------------------------------------ DUT IO
    logic [NL-1:0]      phy_phystatus_stim = '0;
    logic                       test_en = 1'b0;
    logic [NC-1:0]        ctrl_rst_n = '0;
    logic [$clog2(NM)-1:0] mode = '0;

    logic [NC-1:0]        ctrl_pclk;
    logic [NL-1:0]      phy_pclk_in;
    logic [NL-1:0]      phy_rst_n;

    mac2phy_lane_t [NL-1:0] phy_mac2phy;
    phy2mac_lane_t [NL-1:0] phy_phy2mac;

    mac2phy_lane_t [15:0] ctrl0_mac2phy;
    phy2mac_lane_t [15:0] ctrl0_phy2mac;
    mac2phy_lane_t [15:0] ctrl1_mac2phy;
    phy2mac_lane_t [15:0] ctrl1_phy2mac;
    mac2phy_lane_t [15:0] ctrl2_mac2phy;
    phy2mac_lane_t [15:0] ctrl2_phy2mac;
    mac2phy_lane_t [15:0] ctrl3_mac2phy;
    phy2mac_lane_t [15:0] ctrl3_phy2mac;

    pipe_lane_mapper_top #(
        .NM  (NM),
        .NL (NL),
        .NC   (NC)
    ) dut (
        .phy_pclk_out   (phy_pclk_out),
        .test_en        (test_en),
        .ctrl_rst_n     (ctrl_rst_n),
        .mode           (mode),
        .ctrl_pclk      (ctrl_pclk),
        .phy_pclk_in    (phy_pclk_in),
        .phy_rst_n      (phy_rst_n),
        .phy_mac2phy    (phy_mac2phy),
        .phy_phy2mac    (phy_phy2mac),
        .ctrl0_mac2phy (ctrl0_mac2phy),
        .ctrl0_phy2mac (ctrl0_phy2mac),
        .ctrl1_mac2phy (ctrl1_mac2phy),
        .ctrl1_phy2mac (ctrl1_phy2mac),
        .ctrl2_mac2phy (ctrl2_mac2phy),
        .ctrl2_phy2mac (ctrl2_phy2mac),
        .ctrl3_mac2phy (ctrl3_mac2phy),
        .ctrl3_phy2mac (ctrl3_phy2mac)
    );

    //------------------------------------------------------------ stimulus patterns
    function automatic mac2phy_lane_t make_m2p(input int cid, input int port);
        mac2phy_lane_t v;
        v = SAFE_M2P;
        v.mac_phy_txdata      = {4'(cid), 20'h0, 8'(port)};
        v.mac_phy_txdatak     = 4'(port);
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
        for (int p = 0; p < 16; p++) ctrl0_mac2phy[p] = make_m2p(0, p);
        for (int p = 0; p < 16; p++) ctrl1_mac2phy[p] = make_m2p(1, p);
        for (int p = 0; p < 16; p++) ctrl2_mac2phy[p] = make_m2p(2, p);
        for (int p = 0; p < 16; p++) ctrl3_mac2phy[p] = make_m2p(3, p);
        for (int l = 0; l < NL; l++) begin
            phy_phy2mac[l] = make_p2m(l);
            phy_phy2mac[l].phy_mac_phystatus = phy_phystatus_stim[l];
        end
    end

    //------------------------------------------------------------ expected mapping (from lane_mapping.csv)
    function automatic int owner_of(input int m, input int l);
        case (m)
            0: case (l)
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
                12: return 0;
                13: return 0;
                14: return 0;
                15: return 0;
                default: return -1;
            endcase
            1: case (l)
                0: return 0;
                1: return 0;
                2: return 0;
                3: return 0;
                4: return 0;
                5: return 0;
                6: return 0;
                7: return 0;
                8: return 2;
                9: return 2;
                10: return 2;
                11: return 2;
                12: return 2;
                13: return 2;
                14: return 2;
                15: return 2;
                default: return -1;
            endcase
            2: case (l)
                0: return 0;
                1: return 0;
                2: return 0;
                3: return 0;
                4: return 0;
                5: return 0;
                6: return 0;
                7: return 0;
                8: return 2;
                9: return 2;
                10: return 2;
                11: return 2;
                12: return 3;
                13: return 3;
                14: return 3;
                15: return 3;
                default: return -1;
            endcase
            3: case (l)
                0: return 0;
                1: return 0;
                2: return 0;
                3: return 0;
                4: return 1;
                5: return 1;
                6: return 1;
                7: return 1;
                8: return 2;
                9: return 2;
                10: return 2;
                11: return 2;
                12: return 3;
                13: return 3;
                14: return 3;
                15: return 3;
                default: return -1;
            endcase
            default: return -1;
        endcase
    endfunction

    function automatic int port_of(input int m, input int l);
        case (m)
            0: case (l)
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
                12: return 12;
                13: return 13;
                14: return 14;
                15: return 15;
                default: return -1;
            endcase
            1: case (l)
                0: return 0;
                1: return 1;
                2: return 2;
                3: return 3;
                4: return 4;
                5: return 5;
                6: return 6;
                7: return 7;
                8: return 0;
                9: return 1;
                10: return 2;
                11: return 3;
                12: return 4;
                13: return 5;
                14: return 6;
                15: return 7;
                default: return -1;
            endcase
            2: case (l)
                0: return 0;
                1: return 1;
                2: return 2;
                3: return 3;
                4: return 4;
                5: return 5;
                6: return 6;
                7: return 7;
                8: return 0;
                9: return 1;
                10: return 2;
                11: return 3;
                12: return 0;
                13: return 1;
                14: return 2;
                15: return 3;
                default: return -1;
            endcase
            3: case (l)
                0: return 0;
                1: return 1;
                2: return 2;
                3: return 3;
                4: return 0;
                5: return 1;
                6: return 2;
                7: return 3;
                8: return 0;
                9: return 1;
                10: return 2;
                11: return 3;
                12: return 0;
                13: return 1;
                14: return 2;
                15: return 3;
                default: return -1;
            endcase
            default: return -1;
        endcase
    endfunction

    //------------------------------------------------------------ BBM one-hot / safe-state monitor
    int unsigned err_count = 0;

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

    localparam int G1_LANES[4] = '{4, 5, 6, 7};
    localparam int G2_LANES[4] = '{8, 9, 10, 11};
    localparam int G3_LANES[4] = '{12, 13, 14, 15};

    phy2mac_lane_t exp_safe_p2m_ctrl0;
    assign exp_safe_p2m_ctrl0 = '{
        phy_mac_rxelecidle: 1'b1,
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[0].phy_mac_phystatus,
        default: '0
    };
    phy2mac_lane_t exp_safe_p2m_ctrl1;
    assign exp_safe_p2m_ctrl1 = '{
        phy_mac_rxelecidle: 1'b1,
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[4].phy_mac_phystatus,
        default: '0
    };
    phy2mac_lane_t exp_safe_p2m_ctrl2;
    assign exp_safe_p2m_ctrl2 = '{
        phy_mac_rxelecidle: 1'b1,
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[8].phy_mac_phystatus,
        default: '0
    };
    phy2mac_lane_t exp_safe_p2m_ctrl3;
    assign exp_safe_p2m_ctrl3 = '{
        phy_mac_rxelecidle: 1'b1,
        phy_mac_messagebus: 8'd80,
        phy_mac_phystatus: phy_phy2mac[12].phy_mac_phystatus,
        default: '0
    };

    always @(dut.sel_tgt) begin
        chk($onehot0(dut.sel_tgt.g1), "sel_tgt.g1 not one-hot0 (>1 branch enabled)");
        chk($onehot0(dut.sel_tgt.g2), "sel_tgt.g2 not one-hot0 (>1 branch enabled)");
        chk($onehot0(dut.sel_tgt.g3), "sel_tgt.g3 not one-hot0 (>1 branch enabled)");

        if (dut.sel_tgt.g1 == '0) begin
            foreach (G1_LANES[i])
                chk_m2p(phy_mac2phy[G1_LANES[i]], SAFE_M2P,
                    $sformatf("G1 lane%0d: sel==0 BBM gap", G1_LANES[i]));
            chk_p2m(ctrl0_phy2mac[4], exp_safe_p2m_ctrl0,
                "G1 Ctrl0[4]: sel==0 BBM gap");
            chk_p2m(ctrl0_phy2mac[5], exp_safe_p2m_ctrl0,
                "G1 Ctrl0[5]: sel==0 BBM gap");
            chk_p2m(ctrl0_phy2mac[6], exp_safe_p2m_ctrl0,
                "G1 Ctrl0[6]: sel==0 BBM gap");
            chk_p2m(ctrl0_phy2mac[7], exp_safe_p2m_ctrl0,
                "G1 Ctrl0[7]: sel==0 BBM gap");
            chk_p2m(ctrl1_phy2mac[0], exp_safe_p2m_ctrl1,
                "G1 Ctrl1[0]: sel==0 BBM gap");
            chk_p2m(ctrl1_phy2mac[1], exp_safe_p2m_ctrl1,
                "G1 Ctrl1[1]: sel==0 BBM gap");
            chk_p2m(ctrl1_phy2mac[2], exp_safe_p2m_ctrl1,
                "G1 Ctrl1[2]: sel==0 BBM gap");
            chk_p2m(ctrl1_phy2mac[3], exp_safe_p2m_ctrl1,
                "G1 Ctrl1[3]: sel==0 BBM gap");
        end
        if (dut.sel_tgt.g2 == '0) begin
            foreach (G2_LANES[i])
                chk_m2p(phy_mac2phy[G2_LANES[i]], SAFE_M2P,
                    $sformatf("G2 lane%0d: sel==0 BBM gap", G2_LANES[i]));
            chk_p2m(ctrl0_phy2mac[8], exp_safe_p2m_ctrl0,
                "G2 Ctrl0[8]: sel==0 BBM gap");
            chk_p2m(ctrl0_phy2mac[9], exp_safe_p2m_ctrl0,
                "G2 Ctrl0[9]: sel==0 BBM gap");
            chk_p2m(ctrl0_phy2mac[10], exp_safe_p2m_ctrl0,
                "G2 Ctrl0[10]: sel==0 BBM gap");
            chk_p2m(ctrl0_phy2mac[11], exp_safe_p2m_ctrl0,
                "G2 Ctrl0[11]: sel==0 BBM gap");
            chk_p2m(ctrl2_phy2mac[0], exp_safe_p2m_ctrl2,
                "G2 Ctrl2[0]: sel==0 BBM gap");
            chk_p2m(ctrl2_phy2mac[1], exp_safe_p2m_ctrl2,
                "G2 Ctrl2[1]: sel==0 BBM gap");
            chk_p2m(ctrl2_phy2mac[2], exp_safe_p2m_ctrl2,
                "G2 Ctrl2[2]: sel==0 BBM gap");
            chk_p2m(ctrl2_phy2mac[3], exp_safe_p2m_ctrl2,
                "G2 Ctrl2[3]: sel==0 BBM gap");
        end
        if (dut.sel_tgt.g3 == '0) begin
            foreach (G3_LANES[i])
                chk_m2p(phy_mac2phy[G3_LANES[i]], SAFE_M2P,
                    $sformatf("G3 lane%0d: sel==0 BBM gap", G3_LANES[i]));
            chk_p2m(ctrl0_phy2mac[12], exp_safe_p2m_ctrl0,
                "G3 Ctrl0[12]: sel==0 BBM gap");
            chk_p2m(ctrl0_phy2mac[13], exp_safe_p2m_ctrl0,
                "G3 Ctrl0[13]: sel==0 BBM gap");
            chk_p2m(ctrl0_phy2mac[14], exp_safe_p2m_ctrl0,
                "G3 Ctrl0[14]: sel==0 BBM gap");
            chk_p2m(ctrl0_phy2mac[15], exp_safe_p2m_ctrl0,
                "G3 Ctrl0[15]: sel==0 BBM gap");
            chk_p2m(ctrl2_phy2mac[4], exp_safe_p2m_ctrl2,
                "G3 Ctrl2[4]: sel==0 BBM gap");
            chk_p2m(ctrl2_phy2mac[5], exp_safe_p2m_ctrl2,
                "G3 Ctrl2[5]: sel==0 BBM gap");
            chk_p2m(ctrl2_phy2mac[6], exp_safe_p2m_ctrl2,
                "G3 Ctrl2[6]: sel==0 BBM gap");
            chk_p2m(ctrl2_phy2mac[7], exp_safe_p2m_ctrl2,
                "G3 Ctrl2[7]: sel==0 BBM gap");
            chk_p2m(ctrl3_phy2mac[0], exp_safe_p2m_ctrl3,
                "G3 Ctrl3[0]: sel==0 BBM gap");
            chk_p2m(ctrl3_phy2mac[1], exp_safe_p2m_ctrl3,
                "G3 Ctrl3[1]: sel==0 BBM gap");
            chk_p2m(ctrl3_phy2mac[2], exp_safe_p2m_ctrl3,
                "G3 Ctrl3[2]: sel==0 BBM gap");
            chk_p2m(ctrl3_phy2mac[3], exp_safe_p2m_ctrl3,
                "G3 Ctrl3[3]: sel==0 BBM gap");
        end
    end

    //------------------------------------------------------------ steady-state data-routing check
    task automatic check_mode(input int m);
        mac2phy_lane_t exp_m2p;
        phy2mac_lane_t exp_p2m;
        int cid, port;

        for (int l = 0; l < NL; l++) begin
            cid  = owner_of(m, l);
            port = port_of(m, l);
            exp_m2p = make_m2p(cid, port);
            chk_m2p(phy_mac2phy[l], exp_m2p,
                $sformatf("mode%0d lane%0d: expected ctrl%0d port%0d", m, l, cid, port));

            chk(phy_rst_n[l] == ctrl_rst_n[cid],
                $sformatf("mode%0d lane%0d: phy_rst_n=%0b does not follow owner ctrl%0d",
                          m, l, phy_rst_n[l], cid));
        end

        for (int c = 0; c < NC; c++) begin
            int max_w = 16;
            int real_max_w;
            case (c)
                0: real_max_w = 16;
                1: real_max_w = 4;
                2: real_max_w = 8;
                3: real_max_w = 4;
                default: real_max_w = 0;
            endcase
            for (int p = 0; p < max_w; p++) begin
                int src_lane;
                phy2mac_lane_t got;
                src_lane = -1;
                for (int l = 0; l < NL; l++)
                    if (owner_of(m, l) == c && port_of(m, l) == p) src_lane = l;

                case (c)
                    0: got = ctrl0_phy2mac[p];
                    1: got = ctrl1_phy2mac[p];
                    2: got = ctrl2_phy2mac[p];
                    3: got = ctrl3_phy2mac[p];
                endcase

                if (src_lane == -1) begin
                    phy2mac_lane_t exp_tie;
                    int active_base;
                    if (p >= real_max_w) begin
                        exp_tie = '0;  // fake lane, port padding only
                    end else begin
                        exp_tie = SAFE_P2M;
                        active_base = -1;
                        for (int l = 0; l < NL; l++) begin
                            if (owner_of(m, l) == c && active_base == -1) active_base = l;
                        end
                        if (active_base != -1) begin
                            exp_tie.phy_mac_rxdata = 32'd0;
                            exp_tie.phy_mac_rxdatak = 4'd0;
                            exp_tie.phy_mac_rxdatavalid = 1'b0;
                            exp_tie.phy_mac_rxstartblock = 1'b0;
                            exp_tie.phy_mac_rxsyncheader = 2'd0;
                            exp_tie.phy_mac_rxvalid = 1'b0;
                            exp_tie.phy_mac_rxstatus = 3'd0;
                            exp_tie.phy_mac_rxelecidle = 1'b1;
                            exp_tie.phy_mac_rxstandbystatus = 1'b0;
                            exp_tie.phy_mac_messagebus = 8'd80;
                            exp_tie.phy_mac_phystatus = phy_phy2mac[active_base].phy_mac_phystatus;
                            exp_tie.phy_mac_local_tx_coef_valid = 1'b0;
                            exp_tie.phy_mac_local_tx_pset_coef = 18'd0;
                            exp_tie.phy_mac_localfs = 6'd0;
                            exp_tie.phy_mac_locallf = 6'd0;
                            exp_tie.phy_mac_dirfeedback = 6'd0;
                            exp_tie.phy_mac_fomfeedback = 8'd0;
                        end else begin
                            exp_tie.phy_mac_rxdata = 32'd0;
                            exp_tie.phy_mac_rxdatak = 4'd0;
                            exp_tie.phy_mac_rxdatavalid = 1'b0;
                            exp_tie.phy_mac_rxstartblock = 1'b0;
                            exp_tie.phy_mac_rxsyncheader = 2'd0;
                            exp_tie.phy_mac_rxvalid = 1'b0;
                            exp_tie.phy_mac_rxstatus = 3'd0;
                            exp_tie.phy_mac_rxelecidle = 1'b1;
                            exp_tie.phy_mac_rxstandbystatus = 1'b0;
                            exp_tie.phy_mac_messagebus = 8'd80;
                            exp_tie.phy_mac_phystatus = '0;
                            exp_tie.phy_mac_local_tx_coef_valid = 1'b0;
                            exp_tie.phy_mac_local_tx_pset_coef = 18'd0;
                            exp_tie.phy_mac_localfs = 6'd0;
                            exp_tie.phy_mac_locallf = 6'd0;
                            exp_tie.phy_mac_dirfeedback = 6'd0;
                            exp_tie.phy_mac_fomfeedback = 8'd0;
                        end
                    end
                    chk_p2m(got, exp_tie,
                        $sformatf("mode%0d ctrl%0d[%0d]: unmapped tie-off", m, c, p));
                end else begin
                    exp_p2m = make_p2m(src_lane);
                    exp_p2m.phy_mac_phystatus = phy_phystatus_stim[src_lane];
                    chk_p2m(got, exp_p2m,
                        $sformatf("mode%0d ctrl%0d[%0d]: expected lane%0d data", m, c, p, src_lane));
                end
            end
        end

        $display("%0t: mode%0d checked (%0d cumulative errors)", $time, m, err_count);
    endtask

    //------------------------------------------------------------ sequencing
    localparam realtime SETTLE = 300;

    initial begin
`ifdef DUMP_FSDB
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_pipe_lane_mapper, "+all");
`else
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_pipe_lane_mapper);
`endif

        ctrl_rst_n = '0;
        mode = '0;
        #100;
        ctrl_rst_n = '1;
        #SETTLE;

        check_mode(0);
        // toggle physical lane 0's phystatus and dynamically verify it's followed correctly
        phy_phystatus_stim[0] = 1'b1; #20;
        check_mode(0);
        phy_phystatus_stim[0] = 1'b0; #20;
        check_mode(0);
        mode = 1; #SETTLE;
        check_mode(1);
        // toggle physical lane 0's phystatus and dynamically verify it's followed correctly
        phy_phystatus_stim[0] = 1'b1; #20;
        check_mode(1);
        phy_phystatus_stim[0] = 1'b0; #20;
        check_mode(1);
        mode = 2; #SETTLE;
        check_mode(2);
        // toggle physical lane 0's phystatus and dynamically verify it's followed correctly
        phy_phystatus_stim[0] = 1'b1; #20;
        check_mode(2);
        phy_phystatus_stim[0] = 1'b0; #20;
        check_mode(2);
        mode = 3; #SETTLE;
        check_mode(3);
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
        for (int l = 0; l < NL; l++) begin
            bit expect_low;
            expect_low = (owner_of(3, l) == 0);
            chk(phy_rst_n[l] == (expect_low ? 1'b0 : 1'b1),
                $sformatf("mode3 lane%0d: ctrl_rst_n[0]=0 pulse, expected phy_rst_n=%0b", l, expect_low ? 1'b0 : 1'b1));
        end
        $display("%0t: ctrl_rst_n[0] pulse checked (%0d cumulative errors)", $time, err_count);
        ctrl_rst_n[0] = 1'b1; #SETTLE;
        check_mode(3);
        ctrl_rst_n[1] = 1'b0; #SETTLE;
        for (int l = 0; l < NL; l++) begin
            bit expect_low;
            expect_low = (owner_of(3, l) == 1);
            chk(phy_rst_n[l] == (expect_low ? 1'b0 : 1'b1),
                $sformatf("mode3 lane%0d: ctrl_rst_n[1]=0 pulse, expected phy_rst_n=%0b", l, expect_low ? 1'b0 : 1'b1));
        end
        $display("%0t: ctrl_rst_n[1] pulse checked (%0d cumulative errors)", $time, err_count);
        ctrl_rst_n[1] = 1'b1; #SETTLE;
        check_mode(3);
        ctrl_rst_n[2] = 1'b0; #SETTLE;
        for (int l = 0; l < NL; l++) begin
            bit expect_low;
            expect_low = (owner_of(3, l) == 2);
            chk(phy_rst_n[l] == (expect_low ? 1'b0 : 1'b1),
                $sformatf("mode3 lane%0d: ctrl_rst_n[2]=0 pulse, expected phy_rst_n=%0b", l, expect_low ? 1'b0 : 1'b1));
        end
        $display("%0t: ctrl_rst_n[2] pulse checked (%0d cumulative errors)", $time, err_count);
        ctrl_rst_n[2] = 1'b1; #SETTLE;
        check_mode(3);
        ctrl_rst_n[3] = 1'b0; #SETTLE;
        for (int l = 0; l < NL; l++) begin
            bit expect_low;
            expect_low = (owner_of(3, l) == 3);
            chk(phy_rst_n[l] == (expect_low ? 1'b0 : 1'b1),
                $sformatf("mode3 lane%0d: ctrl_rst_n[3]=0 pulse, expected phy_rst_n=%0b", l, expect_low ? 1'b0 : 1'b1));
        end
        $display("%0t: ctrl_rst_n[3] pulse checked (%0d cumulative errors)", $time, err_count);
        ctrl_rst_n[3] = 1'b1; #SETTLE;
        check_mode(3);

        if (err_count == 0) $display("TB_RESULT: PASS");
        else                 $display("TB_RESULT: FAIL (%0d errors)", err_count);
        $finish;
    end

    initial begin
        #20000;
        $error("TB_RESULT: FAIL (timeout, simulation did not finish)");
        $finish;
    end

endmodule
