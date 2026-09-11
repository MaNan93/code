`timescale 1ns/1ps
//=============================================================================
// tb_pipe_lane_mapper -- self-checking functional simulation, driven by this config set's lane_mapping.csv.
//
// Checks:
//   1. Steady-state data routing matches lane_mapping.csv exactly
//   2. Unmapped controller ports read back SAFE_P2M
//   3. Group sel vectors are always one-hot0 (non-overlap)
//   4. During the NOV handoff window (sel all-zero), phy lanes present the safe state (txelecidle=1)
//   5. phy_rst_n follows the current owner's ctrl_rst_n
//=============================================================================
import pipe_lane_signal_pkg::*;

module tb_pipe_lane_mapper;

    localparam int NL = 12;
    localparam int NC   = 4;

    //------------------------------------------------------------ clocks
    // Different period + phase offset per lane, to exercise asynchronous CDC.
    localparam int unsigned PERIOD_NS [0:11] = '{
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
        11
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
    logic [1:0] mode = '0;

    logic [NL-1:0]      phy_pclk_in;
    logic [NL-1:0]      phy_rst_n;

    mac2phy_lane_t [NL-1:0] phy_mac2phy;
    phy2mac_lane_t [NL-1:0] phy_phy2mac;

    mac2phy_lane_t [11:0] ctrla_mac2phy;
    phy2mac_lane_t [11:0] ctrla_phy2mac;
    logic ctrla_pclk;   // CtrlA's own derived working clock, DUT output
    mac2phy_lane_t [5:0] ctrlb_mac2phy;
    phy2mac_lane_t [5:0] ctrlb_phy2mac;
    logic ctrlb_pclk;   // CtrlB's own derived working clock, DUT output
    mac2phy_lane_t [7:0] ctrlc_mac2phy;
    phy2mac_lane_t [7:0] ctrlc_phy2mac;
    logic ctrlc_pclk;   // CtrlC's own derived working clock, DUT output
    mac2phy_lane_t [2:0] ctrld_mac2phy;
    phy2mac_lane_t [2:0] ctrld_phy2mac;
    logic ctrld_pclk;   // CtrlD's own derived working clock, DUT output

    // DPR (diagnostic probe): idle by default -- v_lane_mask all-zero means
    // it never actually overrides any lane, regardless of dpr_rst_n/dpr_mac2phy.
    logic [NL-1:0] v_lane_mask = '0;
    logic dpr_rst_n = 1'b1;
    mac2phy_lane_t [NL-1:0] dpr_mac2phy = '0;
    phy2mac_lane_t [NL-1:0] dpr_phy2mac;
    logic dpr_pclk;   // DPR's own derived working clock, DUT output

    pipe_lane_mapper #(
        .NL (NL),
        .NC (NC)
    ) dut (
        .phy_pclk_out   (phy_pclk_out),
        .test_en        (test_en),
        .mode           (mode),
        .phy_pclk_in    (phy_pclk_in),
        .phy_rst_n      (phy_rst_n),
        .phy_mac2phy    (phy_mac2phy),
        .phy_phy2mac    (phy_phy2mac),
        .v_lane_mask    (v_lane_mask),
        .dpr_rst_n      (dpr_rst_n),
        .dpr_mac2phy    (dpr_mac2phy),
        .dpr_phy2mac    (dpr_phy2mac),
        .dpr_pclk       (dpr_pclk),
        .ctrla_rst_n   (ctrl_rst_n[0]),
        .ctrla_mac2phy (ctrla_mac2phy),
        .ctrla_phy2mac (ctrla_phy2mac),
        .ctrla_pclk    (ctrla_pclk),
        .ctrlb_rst_n   (ctrl_rst_n[1]),
        .ctrlb_mac2phy (ctrlb_mac2phy),
        .ctrlb_phy2mac (ctrlb_phy2mac),
        .ctrlb_pclk    (ctrlb_pclk),
        .ctrlc_rst_n   (ctrl_rst_n[2]),
        .ctrlc_mac2phy (ctrlc_mac2phy),
        .ctrlc_phy2mac (ctrlc_phy2mac),
        .ctrlc_pclk    (ctrlc_pclk),
        .ctrld_rst_n   (ctrl_rst_n[3]),
        .ctrld_mac2phy (ctrld_mac2phy),
        .ctrld_phy2mac (ctrld_phy2mac),
        .ctrld_pclk    (ctrld_pclk)
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
        for (int p = 0; p < 12; p++) ctrla_mac2phy[p] = make_m2p(0, p);
        for (int p = 0; p < 6; p++) ctrlb_mac2phy[p] = make_m2p(1, p);
        for (int p = 0; p < 8; p++) ctrlc_mac2phy[p] = make_m2p(2, p);
        for (int p = 0; p < 3; p++) ctrld_mac2phy[p] = make_m2p(3, p);
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
                default: return -1;
            endcase
            1: case (l)
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
            2: case (l)
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
            3: case (l)
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
                default: return -1;
            endcase
            1: case (l)
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
            2: case (l)
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
            3: case (l)
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

    function automatic int ctrl_pclk_src_lane(input int m, input int cid);
        for (int l = 0; l < NL; l++)
            if (owner_of(m, l) == cid) return l;
        return -1;
    endfunction

    //------------------------------------------------------------ NOV one-hot / safe-state monitor
    int unsigned err_count = 0;
    int unsigned err_clock = 0, err_reset = 0, err_m2p = 0, err_p2m = 0, err_tie_off = 0, err_safe_state = 0, err_dpr = 0;

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

    phy2mac_lane_t exp_safe_p2m_ctrla;
    assign exp_safe_p2m_ctrla = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[0].phy_mac_phystatus,
        default: '0
    };
    phy2mac_lane_t exp_safe_p2m_ctrlb;
    assign exp_safe_p2m_ctrlb = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[3].phy_mac_phystatus,
        default: '0
    };
    phy2mac_lane_t exp_safe_p2m_ctrlc;
    assign exp_safe_p2m_ctrlc = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[6].phy_mac_phystatus,
        default: '0
    };
    phy2mac_lane_t exp_safe_p2m_ctrld;
    assign exp_safe_p2m_ctrld = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: phy_phy2mac[9].phy_mac_phystatus,
        default: '0
    };

    phy2mac_lane_t exp_dpr_tie;
    assign exp_dpr_tie = '{
        phy_mac_messagebus: 8'h50,
        phy_mac_phystatus: '0,
        default: '0
    };

    always @(dut.sel_tgt) begin
        if ($time == 0) begin
            // skip: DUT hasn't come out of its startup X state yet
        end else begin
            lane_sel_t sel_snap;
            int unsigned err_before;
            sel_snap = dut.sel_tgt;
            #1;
            err_before = err_count;
            chk($onehot0(sel_snap.g1), "sel_tgt.g1 not one-hot0 (>1 branch enabled)");
            chk($onehot0(sel_snap.g2), "sel_tgt.g2 not one-hot0 (>1 branch enabled)");
            chk($onehot0(sel_snap.g3), "sel_tgt.g3 not one-hot0 (>1 branch enabled)");

            if (sel_snap.g1 == '0 && dut.sel_tgt.g1 == '0) begin
                foreach (G1_LANES[i])
                    chk_m2p(phy_mac2phy[G1_LANES[i]], SAFE_M2P,
                        $sformatf("G1 lane%0d: sel==0 NOV gap", G1_LANES[i]));
                chk_p2m(ctrla_phy2mac[3], exp_safe_p2m_ctrla,
                    "G1 CtrlA[3]: sel==0 NOV gap");
                chk_p2m(ctrla_phy2mac[4], exp_safe_p2m_ctrla,
                    "G1 CtrlA[4]: sel==0 NOV gap");
                chk_p2m(ctrla_phy2mac[5], exp_safe_p2m_ctrla,
                    "G1 CtrlA[5]: sel==0 NOV gap");
                chk_p2m(ctrlb_phy2mac[0], exp_safe_p2m_ctrlb,
                    "G1 CtrlB[0]: sel==0 NOV gap");
                chk_p2m(ctrlb_phy2mac[1], exp_safe_p2m_ctrlb,
                    "G1 CtrlB[1]: sel==0 NOV gap");
                chk_p2m(ctrlb_phy2mac[2], exp_safe_p2m_ctrlb,
                    "G1 CtrlB[2]: sel==0 NOV gap");
            end
            if (sel_snap.g2 == '0 && dut.sel_tgt.g2 == '0) begin
                foreach (G2_LANES[i])
                    chk_m2p(phy_mac2phy[G2_LANES[i]], SAFE_M2P,
                        $sformatf("G2 lane%0d: sel==0 NOV gap", G2_LANES[i]));
                chk_p2m(ctrla_phy2mac[6], exp_safe_p2m_ctrla,
                    "G2 CtrlA[6]: sel==0 NOV gap");
                chk_p2m(ctrla_phy2mac[7], exp_safe_p2m_ctrla,
                    "G2 CtrlA[7]: sel==0 NOV gap");
                chk_p2m(ctrla_phy2mac[8], exp_safe_p2m_ctrla,
                    "G2 CtrlA[8]: sel==0 NOV gap");
                chk_p2m(ctrlc_phy2mac[0], exp_safe_p2m_ctrlc,
                    "G2 CtrlC[0]: sel==0 NOV gap");
                chk_p2m(ctrlc_phy2mac[1], exp_safe_p2m_ctrlc,
                    "G2 CtrlC[1]: sel==0 NOV gap");
                chk_p2m(ctrlc_phy2mac[2], exp_safe_p2m_ctrlc,
                    "G2 CtrlC[2]: sel==0 NOV gap");
            end
            if (sel_snap.g3 == '0 && dut.sel_tgt.g3 == '0) begin
                foreach (G3_LANES[i])
                    chk_m2p(phy_mac2phy[G3_LANES[i]], SAFE_M2P,
                        $sformatf("G3 lane%0d: sel==0 NOV gap", G3_LANES[i]));
                chk_p2m(ctrla_phy2mac[9], exp_safe_p2m_ctrla,
                    "G3 CtrlA[9]: sel==0 NOV gap");
                chk_p2m(ctrla_phy2mac[10], exp_safe_p2m_ctrla,
                    "G3 CtrlA[10]: sel==0 NOV gap");
                chk_p2m(ctrla_phy2mac[11], exp_safe_p2m_ctrla,
                    "G3 CtrlA[11]: sel==0 NOV gap");
                chk_p2m(ctrlb_phy2mac[3], exp_safe_p2m_ctrlb,
                    "G3 CtrlB[3]: sel==0 NOV gap");
                chk_p2m(ctrlb_phy2mac[4], exp_safe_p2m_ctrlb,
                    "G3 CtrlB[4]: sel==0 NOV gap");
                chk_p2m(ctrlb_phy2mac[5], exp_safe_p2m_ctrlb,
                    "G3 CtrlB[5]: sel==0 NOV gap");
                chk_p2m(ctrlc_phy2mac[3], exp_safe_p2m_ctrlc,
                    "G3 CtrlC[3]: sel==0 NOV gap");
                chk_p2m(ctrlc_phy2mac[4], exp_safe_p2m_ctrlc,
                    "G3 CtrlC[4]: sel==0 NOV gap");
                chk_p2m(ctrlc_phy2mac[5], exp_safe_p2m_ctrlc,
                    "G3 CtrlC[5]: sel==0 NOV gap");
                chk_p2m(ctrld_phy2mac[0], exp_safe_p2m_ctrld,
                    "G3 CtrlD[0]: sel==0 NOV gap");
                chk_p2m(ctrld_phy2mac[1], exp_safe_p2m_ctrld,
                    "G3 CtrlD[1]: sel==0 NOV gap");
                chk_p2m(ctrld_phy2mac[2], exp_safe_p2m_ctrld,
                    "G3 CtrlD[2]: sel==0 NOV gap");
            end
            err_safe_state += (err_count - err_before);
        end
    end

    //------------------------------------------------------------ steady-state data-routing check
    task automatic check_mode(input int m);
        mac2phy_lane_t exp_m2p;
        phy2mac_lane_t exp_p2m;
        int cid, port;
        int unsigned err_before;

        for (int l = 0; l < NL; l++) begin
            cid  = owner_of(m, l);
            port = port_of(m, l);
            exp_m2p = make_m2p(cid, port);
            err_before = err_count;
            chk_m2p(phy_mac2phy[l], exp_m2p,
                $sformatf("mode%0d lane%0d: expected ctrl%0d port%0d", m, l, cid, port));
            err_m2p += (err_count - err_before);

            err_before = err_count;
            chk(phy_rst_n[l] == ctrl_rst_n[cid],
                $sformatf("mode%0d lane%0d: phy_rst_n=%0b does not follow owner ctrl%0d",
                          m, l, phy_rst_n[l], cid));
            err_reset += (err_count - err_before);

            begin
                int src_lane;
                src_lane = ctrl_pclk_src_lane(m, cid);
                if (src_lane != -1)
                    begin
                        time t0;
                        real got_ns, exp_ns;
                        int unsigned err_before;
                        exp_ns = PERIOD_NS[src_lane];
                        @(posedge phy_pclk_in[l]); t0 = $time;
                        @(posedge phy_pclk_in[l]); got_ns = $time - t0;
                        err_before = err_count;
                        chk((got_ns > exp_ns * 0.8) && (got_ns < exp_ns * 1.2),
                            $sformatf("%s: measured period %0.2fns, expected ~%0.2fns", $sformatf("mode%0d lane%0d phy_pclk_in", m, l), got_ns, exp_ns));
                        err_clock += (err_count - err_before);
                    end
            end
        end

        for (int c = 0; c < NC; c++) begin
            int src_lane;
            src_lane = ctrl_pclk_src_lane(m, c);
            if (src_lane != -1) begin
                case (c)
                    0: begin
                        begin
                            time t0;
                            real got_ns, exp_ns;
                            int unsigned err_before;
                            exp_ns = PERIOD_NS[src_lane];
                            @(posedge ctrla_pclk); t0 = $time;
                            @(posedge ctrla_pclk); got_ns = $time - t0;
                            err_before = err_count;
                            chk((got_ns > exp_ns * 0.8) && (got_ns < exp_ns * 1.2),
                                $sformatf("%s: measured period %0.2fns, expected ~%0.2fns", $sformatf("mode%0d ctrla_pclk", m), got_ns, exp_ns));
                            err_clock += (err_count - err_before);
                        end
                    end
                    1: begin
                        begin
                            time t0;
                            real got_ns, exp_ns;
                            int unsigned err_before;
                            exp_ns = PERIOD_NS[src_lane];
                            @(posedge ctrlb_pclk); t0 = $time;
                            @(posedge ctrlb_pclk); got_ns = $time - t0;
                            err_before = err_count;
                            chk((got_ns > exp_ns * 0.8) && (got_ns < exp_ns * 1.2),
                                $sformatf("%s: measured period %0.2fns, expected ~%0.2fns", $sformatf("mode%0d ctrlb_pclk", m), got_ns, exp_ns));
                            err_clock += (err_count - err_before);
                        end
                    end
                    2: begin
                        begin
                            time t0;
                            real got_ns, exp_ns;
                            int unsigned err_before;
                            exp_ns = PERIOD_NS[src_lane];
                            @(posedge ctrlc_pclk); t0 = $time;
                            @(posedge ctrlc_pclk); got_ns = $time - t0;
                            err_before = err_count;
                            chk((got_ns > exp_ns * 0.8) && (got_ns < exp_ns * 1.2),
                                $sformatf("%s: measured period %0.2fns, expected ~%0.2fns", $sformatf("mode%0d ctrlc_pclk", m), got_ns, exp_ns));
                            err_clock += (err_count - err_before);
                        end
                    end
                    3: begin
                        begin
                            time t0;
                            real got_ns, exp_ns;
                            int unsigned err_before;
                            exp_ns = PERIOD_NS[src_lane];
                            @(posedge ctrld_pclk); t0 = $time;
                            @(posedge ctrld_pclk); got_ns = $time - t0;
                            err_before = err_count;
                            chk((got_ns > exp_ns * 0.8) && (got_ns < exp_ns * 1.2),
                                $sformatf("%s: measured period %0.2fns, expected ~%0.2fns", $sformatf("mode%0d ctrld_pclk", m), got_ns, exp_ns));
                            err_clock += (err_count - err_before);
                        end
                    end
                endcase
            end
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
                for (int l = 0; l < NL; l++)
                    if (owner_of(m, l) == c && port_of(m, l) == p) src_lane = l;

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
                    for (int l = 0; l < NL; l++) begin
                        if (owner_of(m, l) == c && active_base == -1) active_base = l;
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

    //------------------------------------------------------------ dpr test: DPR claims/releases a lane per group
    task automatic check_dpr();
        int test_lanes[4] = '{0, 3, 6, 9};
        foreach (test_lanes[k]) begin
            automatic int l = test_lanes[k];
            automatic int oid = owner_of(mode, l);
            automatic int op = port_of(mode, l);
            automatic int unsigned err_before;
            v_lane_mask = '0;
            v_lane_mask[l] = 1'b1;
            #SETTLE;
            err_before = err_count;
            case (oid)
                0: chk_p2m(ctrla_phy2mac[op], exp_safe_p2m_ctrla,
                    $sformatf("dpr claimed lane%0d: real owner CtrlA[%0d] should read SAFE_P2M", l, op));
                1: chk_p2m(ctrlb_phy2mac[op], exp_safe_p2m_ctrlb,
                    $sformatf("dpr claimed lane%0d: real owner CtrlB[%0d] should read SAFE_P2M", l, op));
                2: chk_p2m(ctrlc_phy2mac[op], exp_safe_p2m_ctrlc,
                    $sformatf("dpr claimed lane%0d: real owner CtrlC[%0d] should read SAFE_P2M", l, op));
                3: chk_p2m(ctrld_phy2mac[op], exp_safe_p2m_ctrld,
                    $sformatf("dpr claimed lane%0d: real owner CtrlD[%0d] should read SAFE_P2M", l, op));
                default: ;
            endcase
            chk(dpr_phy2mac[l] == phy_phy2mac[l],
                $sformatf("dpr claimed lane%0d: dpr_phy2mac should mirror live phy_phy2mac", l));
            $display("%0t: dpr claimed lane%0d (%0d cumulative errors)", $time, l, err_count);
            v_lane_mask = '0;
            #SETTLE;
            chk(dpr_phy2mac[l] == exp_dpr_tie,
                $sformatf("dpr released lane%0d: dpr_phy2mac should revert to tie", l));
            $display("%0t: dpr released lane%0d (%0d cumulative errors)", $time, l, err_count);
            err_dpr += (err_count - err_before);
        end
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
        begin
            int unsigned err_before;
            err_before = err_count;
            for (int l = 0; l < NL; l++) begin
                bit expect_low;
                expect_low = (owner_of(3, l) == 0);
                chk(phy_rst_n[l] == (expect_low ? 1'b0 : 1'b1),
                    $sformatf("mode3 lane%0d: ctrl_rst_n[0]=0 pulse, expected phy_rst_n=%0b", l, expect_low ? 1'b0 : 1'b1));
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
            for (int l = 0; l < NL; l++) begin
                bit expect_low;
                expect_low = (owner_of(3, l) == 1);
                chk(phy_rst_n[l] == (expect_low ? 1'b0 : 1'b1),
                    $sformatf("mode3 lane%0d: ctrl_rst_n[1]=0 pulse, expected phy_rst_n=%0b", l, expect_low ? 1'b0 : 1'b1));
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
            for (int l = 0; l < NL; l++) begin
                bit expect_low;
                expect_low = (owner_of(3, l) == 2);
                chk(phy_rst_n[l] == (expect_low ? 1'b0 : 1'b1),
                    $sformatf("mode3 lane%0d: ctrl_rst_n[2]=0 pulse, expected phy_rst_n=%0b", l, expect_low ? 1'b0 : 1'b1));
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
            for (int l = 0; l < NL; l++) begin
                bit expect_low;
                expect_low = (owner_of(3, l) == 3);
                chk(phy_rst_n[l] == (expect_low ? 1'b0 : 1'b1),
                    $sformatf("mode3 lane%0d: ctrl_rst_n[3]=0 pulse, expected phy_rst_n=%0b", l, expect_low ? 1'b0 : 1'b1));
            end
            err_reset += (err_count - err_before);
        end
        $display("%0t: ctrl_rst_n[3] pulse checked (%0d cumulative errors)", $time, err_count);
        ctrl_rst_n[3] = 1'b1; #SETTLE;
        check_mode(3);

        // dpr test, in mode3
        check_dpr();

        $display("=== test case summary ===");
        $display("  clock     : %s (%0d errors)", err_clock == 0 ? "PASS" : "FAIL", err_clock);
        $display("  reset     : %s (%0d errors)", err_reset == 0 ? "PASS" : "FAIL", err_reset);
        $display("  m2p       : %s (%0d errors)", err_m2p == 0 ? "PASS" : "FAIL", err_m2p);
        $display("  p2m       : %s (%0d errors)", err_p2m == 0 ? "PASS" : "FAIL", err_p2m);
        $display("  tie_off   : %s (%0d errors)", err_tie_off == 0 ? "PASS" : "FAIL", err_tie_off);
        $display("  safe_state: %s (%0d errors)", err_safe_state == 0 ? "PASS" : "FAIL", err_safe_state);
        $display("  dpr       : %s (%0d errors)", err_dpr == 0 ? "PASS" : "FAIL", err_dpr);
        if (err_count == 0) $display("TB_RESULT: PASS");
        else                 $display("TB_RESULT: FAIL (%0d errors)", err_count);
        $finish;
    end

    initial begin
        #142000;
        $error("TB_RESULT: FAIL (timeout, simulation did not finish)");
        $finish;
    end

endmodule
